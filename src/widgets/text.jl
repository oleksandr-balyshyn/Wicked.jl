@enum WrapMode::UInt8 begin
    NoWrap
    CharacterWrap
    WordWrap
end

struct StyledGrapheme
    content::String
    style::Style
    width::Int
end

function _graphemes(line::Line, policy::AbstractWidthPolicy)
    values = StyledGrapheme[]
    for span in line.spans, grapheme in Unicode.graphemes(span.content)
        push!(values, StyledGrapheme(String(grapheme), span.style, grapheme_width(policy, grapheme)))
    end
    values
end

function _line_from_graphemes(values::AbstractVector{StyledGrapheme}, alignment::HorizontalAlignment)
    spans = Span[]
    for value in values
        value.width == 0 && continue
        if !isempty(spans) && spans[end].style == value.style
            previous = spans[end]
            spans[end] = Span(previous.content * value.content; style=previous.style)
        else
            push!(spans, Span(value.content; style=value.style))
        end
    end
    Line(spans; alignment)
end

function _wrap_graphemes(values::Vector{StyledGrapheme}, width::Int, mode::WrapMode, alignment)
    width <= 0 && return Line[]
    mode == NoWrap && return [_line_from_graphemes(values, alignment)]
    lines = Line[]
    current = StyledGrapheme[]
    current_width = 0
    for value in values
        value.width == 0 && continue
        if current_width + value.width > width && !isempty(current)
            if mode == WordWrap
                boundary = findlast(item -> all(isspace, item.content), current)
                if !isnothing(boundary)
                    push!(lines, _line_from_graphemes(current[1:(boundary - 1)], alignment))
                    current = boundary < length(current) ? current[(boundary + 1):end] : StyledGrapheme[]
                    current_width = sum(item -> item.width, current; init=0)
                else
                    push!(lines, _line_from_graphemes(current, alignment))
                    empty!(current)
                    current_width = 0
                end
            else
                push!(lines, _line_from_graphemes(current, alignment))
                empty!(current)
                current_width = 0
            end
        end
        value.width <= width && begin
            push!(current, value)
            current_width += value.width
        end
    end
    (!isempty(current) || isempty(lines)) &&
        push!(lines, _line_from_graphemes(current, alignment))
    lines
end

function _wrapped_lines(text::Text, width::Int, mode::WrapMode, policy::AbstractWidthPolicy)
    lines = Line[]
    for line in text.lines
        append!(lines, _wrap_graphemes(_graphemes(line, policy), width, mode, line.alignment))
    end
    lines
end

"""A single-line text widget with optional truncation."""
struct Label
    line::Line
    ellipsis::String
    width_policy::AbstractWidthPolicy
end

function Label(
    content::Union{AbstractString,Line};
    style::Style=Style(),
    alignment::HorizontalAlignment=LeftAlign,
    ellipsis::AbstractString="…",
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
)
    line = content isa Line ? content : Line(content; style, alignment)
    Label(line, String(ellipsis), width_policy)
end

function _truncate(values::Vector{StyledGrapheme}, width::Int, ellipsis::String, policy)
    sum(value -> value.width, values; init=0) <= width && return values
    ellipsis_width = text_width(ellipsis, policy)
    ellipsis_width > width && return StyledGrapheme[]
    result = StyledGrapheme[]
    used = 0
    for value in values
        used + value.width + ellipsis_width > width && break
        push!(result, value)
        used += value.width
    end
    style = isempty(result) ? Style() : result[end].style
    push!(result, StyledGrapheme(ellipsis, style, ellipsis_width))
    result
end

function render!(buffer::Buffer, label::Label, area::Rect)
    isempty(area) && return buffer
    values = _truncate(_graphemes(label.line, label.width_policy), area.width, label.ellipsis, label.width_policy)
    line = _line_from_graphemes(values, label.line.alignment)
    draw_line!(buffer, area.row, intersection(buffer.area, area), line; width_policy=label.width_policy)
    buffer
end

measure(label::Label, available::Rect) =
    Size(min(1, available.height), min(text_width(join(span.content for span in label.line.spans), label.width_policy), available.width))

"""Multi-line rich text with wrapping and explicit scroll offsets."""
struct Paragraph
    text::Text
    wrap::WrapMode
    vertical_scroll::Int
    width_policy::AbstractWidthPolicy
end

function Paragraph(
    content::Union{AbstractString,Line,Text};
    style::Style=Style(),
    alignment::HorizontalAlignment=LeftAlign,
    wrap::WrapMode=WordWrap,
    vertical_scroll::Integer=0,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
)
    vertical_scroll >= 0 || throw(ArgumentError("vertical scroll must be non-negative"))
    text = content isa Text ? content :
           content isa Line ? Text([content]) : Text(content; style, alignment)
    Paragraph(text, wrap, Int(vertical_scroll), width_policy)
end

function render!(buffer::Buffer, paragraph::Paragraph, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    lines = _wrapped_lines(paragraph.text, area.width, paragraph.wrap, paragraph.width_policy)
    first_line = min(length(lines) + 1, paragraph.vertical_scroll + 1)
    for (offset, line_index) in enumerate(first_line:length(lines))
        offset > active.height && break
        row = active.row + offset - 1
        draw_line!(buffer, row, active, lines[line_index]; width_policy=paragraph.width_policy)
    end
    buffer
end

function measure(paragraph::Paragraph, available::Rect)
    lines = _wrapped_lines(paragraph.text, available.width, paragraph.wrap, paragraph.width_policy)
    width = isempty(lines) ? 0 : maximum(
        line -> sum(span -> text_width(span.content, paragraph.width_policy), line.spans; init=0),
        lines,
    )
    Size(min(length(lines), available.height), min(width, available.width))
end

"""Apply emphasis styling to heading-like content while preserving per-span styling."""
@inline function _compose_style(base::Style, overlay::Style)
    Style(
        foreground=(overlay.foreground.kind == DefaultColorKind) ? base.foreground : overlay.foreground,
        background=(overlay.background.kind == DefaultColorKind) ? base.background : overlay.background,
        underline_color=(overlay.underline_color.kind == DefaultColorKind) ? base.underline_color : overlay.underline_color,
        modifiers=base.modifiers | overlay.modifiers,
        hyperlink=isnothing(overlay.hyperlink) ? base.hyperlink : overlay.hyperlink,
    )
end

@inline function _heading_style(heading_style::Style)
    modifiers = heading_style.modifiers | BOLD
    _compose_style(heading_style, Style(modifiers=modifiers))
end

@inline function _underline_heading_style(heading_style::Style)
    modifiers = heading_style.modifiers | BOLD | UNDERLINE
    _compose_style(heading_style, Style(modifiers=modifiers))
end

@inline function _merge_heading_style(base::Style, heading_style::Style)
    _compose_style(base, heading_style)
end

function _styled_line(line::Line, heading_style::Style, alignment::HorizontalAlignment)
    spans = Span[Span(span.content, _merge_heading_style(span.style, heading_style)) for span in line.spans]
    Line(spans; alignment)
end

function _heading_text(
    content::AbstractString;
    alignment::HorizontalAlignment,
    level::Integer,
    style::Style,
)
    paragraph_style = level <= 2 ? _underline_heading_style(style) : _heading_style(style)
    Text(content; style=paragraph_style, alignment=alignment)
end

function _heading_text(
    content::Line;
    alignment::HorizontalAlignment,
    level::Integer,
    style::Style,
)
    paragraph_style = level <= 2 ? _underline_heading_style(style) : _heading_style(style)
    Text(Line[_styled_line(content, paragraph_style, alignment)])
end

function _heading_text(
    content::Text;
    level::Integer,
    style::Style,
)
    paragraph_style = level <= 2 ? _underline_heading_style(style) : _heading_style(style)
    Text(Line[_styled_line(line, paragraph_style, line.alignment) for line in content.lines])
end

"""
Create a heading-style widget with level-aware emphasis and paragraph semantics.

`Heading` is a convenience constructor that returns a `Paragraph` with heading
appropriate styling:

- level 1 and 2 headings are bold and underlined
- other levels are bold
- content accepts `String`, `Line`, or `Text`
"""
function Heading(
    content::Union{AbstractString,Line,Text};
    level::Integer=1,
    style::Style=Style(),
    alignment::HorizontalAlignment=LeftAlign,
    wrap::WrapMode=WordWrap,
    vertical_scroll::Integer=0,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
)
    1 <= level <= 6 || throw(ArgumentError("heading level must be between 1 and 6"))
    vertical_scroll >= 0 || throw(ArgumentError("vertical scroll must be non-negative"))

    text = if content isa Text
        _heading_text(content; level, style)
    elseif content isa Line
        _heading_text(content; alignment, level, style)
    else
        _heading_text(String(content); alignment, level, style)
    end

    Paragraph(
        text;
        wrap=wrap,
        vertical_scroll=vertical_scroll,
        width_policy=width_policy,
    )
end

"""
Create a markdown-style text widget from a Markdown string.

`MarkupText` is a convenience constructor that parses markdown and returns a
`Paragraph` with semantic role-based styling. It uses `role_styles` to override or
augment defaults for any markdown role token.
"""
function _markup_default_style(role::Symbol)
    if role in (:emphasis, :quote)
        Style(modifiers=ITALIC)
    elseif role == :strong
        Style(modifiers=BOLD)
    elseif role == :strikethrough
        Style(modifiers=STRIKETHROUGH)
    elseif role == :inline_code
        Style(modifiers=DIM)
    elseif role == :code_block
        Style(modifiers=DIM)
    elseif role in (:list_marker, :list_item_marker)
        Style(modifiers=BOLD)
    elseif role == :link
        Style(modifiers=UNDERLINE)
    elseif role == :invalid_link
        Style(foreground=AnsiColor(1), modifiers=UNDERLINE)
    elseif role == :image
        Style(modifiers=UNDERLINE)
    elseif role == :table_border
        Style(modifiers=DIM)
    elseif role == :table_header
        Style(modifiers=BOLD)
    elseif role in (:table_cell, :table_row)
        Style()
    elseif role == :thematic_break
        Style(modifiers=DIM)
    elseif role == :paragraph
        Style()
    elseif startswith(String(role), "heading_")
        level = tryparse(Int, String(role)[9:end])
        if level === nothing
            Style()
        elseif level <= 2
            Style(modifiers=BOLD | UNDERLINE)
        else
            Style(modifiers=BOLD)
        end
    else
        Style()
    end
end

function _normalize_markup_role(role::Symbol)
    value = String(role)
    if endswith(value, "_marker")
        return Symbol(value[1:end-7]), true
    end
    return role, false
end

function _markup_span_style(
    role::Symbol,
    alignment_style::Style,
    role_styles::AbstractDict{Symbol,Style},
)
    normalized, is_marker = _normalize_markup_role(role)
    span_style = _compose_style(alignment_style, _markup_default_style(normalized))
    haskey(role_styles, normalized) && (span_style = _compose_style(span_style, role_styles[normalized]))
    if is_marker
        span_style = _compose_style(span_style, Style(modifiers=BOLD))
    end
    haskey(role_styles, role) && (span_style = _compose_style(span_style, role_styles[role]))
    return span_style
end

function _markup_text(
    rendered,
    alignment::HorizontalAlignment,
    style::Style;
    role_styles::AbstractDict{Symbol,Style}=Dict{Symbol,Style}(),
)
    hasfield(typeof(rendered), :lines) || throw(ArgumentError("markup renderer returned unsupported result"))
    lines = Line[]
    for rich_line in rendered.lines
        if isempty(rich_line.spans)
            push!(lines, Line("", style; alignment))
            continue
        end
        spans = Span[
            Span(
                String(span.text),
                _markup_span_style(
                    span.role == :text ? rich_line.role : span.role,
                    style,
                    role_styles,
                ),
            ) for span in rich_line.spans
        ]
        push!(lines, Line(spans; alignment))
    end
    Text(lines)
end

function _build_markup_lines(
    source::AbstractString;
    width::Integer=4096,
    registry=nothing,
    alignment::HorizontalAlignment=LeftAlign,
    style::Style=Style(),
    role_styles::AbstractDict{Symbol,Style}=Dict{Symbol,Style}(),
)
    width > 0 || throw(ArgumentError("render width must be positive"))
    if registry === nothing
        registry = default_syntax_registry()
    end
    rendered = render_markdown(source; width=width, registry=registry)
    _markup_text(rendered, alignment, style; role_styles=role_styles)
end

"""
Create markdown-aware text with semantic role styling in a paragraph wrapper.

The function is intentionally declarative and side-effect free: it parses markdown
into semantic spans and composes a `Paragraph` using `alignment`, wrapping, and
scroll settings.
"""
function MarkupText(
    content::AbstractString;
    style::Style=Style(),
    alignment::HorizontalAlignment=LeftAlign,
    wrap::WrapMode=WordWrap,
    vertical_scroll::Integer=0,
    width::Integer=4096,
    registry=nothing,
    role_styles::Union{Nothing,AbstractDict{Symbol,Style}}=nothing,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
)
    vertical_scroll >= 0 || throw(ArgumentError("vertical scroll must be non-negative"))
    role_styles === nothing && (role_styles = Dict{Symbol,Style}())
    text = _build_markup_lines(
        content;
        width=width,
        registry=registry,
        alignment=alignment,
        style=style,
        role_styles=role_styles,
    )
    Paragraph(
        text;
        wrap=wrap,
        vertical_scroll=vertical_scroll,
        width_policy=width_policy,
    )
end
