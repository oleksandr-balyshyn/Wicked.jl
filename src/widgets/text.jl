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

struct LineGrapheme
    span_index::Int
    first::Int
    last::Int
    width::Int
end

function _line_graphemes(line::Line, policy::AbstractWidthPolicy)
    values = LineGrapheme[]
    sizehint!(values, sum(span -> length(span.content), line.spans; init=0))
    for (span_index, span) in pairs(line.spans), grapheme in Unicode.graphemes(span.content)
        width = grapheme_width(policy, grapheme)
        width == 0 && continue
        indices = parentindices(grapheme)[1]
        push!(values, LineGrapheme(span_index, first(indices), last(indices), width))
    end
    values
end

@inline function _line_grapheme_content(line::Line, value::LineGrapheme)
    SubString(line.spans[value.span_index].content, value.first, value.last)
end

function _line_from_graphemes(
    source::Line,
    values::AbstractVector{LineGrapheme},
    alignment::HorizontalAlignment,
)
    spans = Span[]
    index = firstindex(values)
    final_index = lastindex(values)
    while index <= final_index
        first_value = values[index]
        span = source.spans[first_value.span_index]
        last_value = first_value
        index += 1
        while index <= final_index
            value = values[index]
            value.span_index == first_value.span_index || break
            value.first == nextind(span.content, last_value.last) || break
            last_value = value
            index += 1
        end
        push!(
            spans,
            Span(
                SubString(span.content, first_value.first, last_value.last);
                style=span.style,
            ),
        )
    end
    Line(spans; alignment)
end

@inline _line_grapheme_isspace(line::Line, value::LineGrapheme) =
    all(isspace, _line_grapheme_content(line, value))

function _wrap_line(
    line::Line,
    width::Int,
    mode::WrapMode,
    policy::AbstractWidthPolicy,
    trim::Bool,
)
    width <= 0 && return Line[]
    mode == NoWrap && return [line]
    values = _line_graphemes(line, policy)
    lines = Line[]
    current = LineGrapheme[]
    sizehint!(current, min(length(values), max(1, width)))
    current_width = 0
    first_value = if mode == WordWrap && trim
        something(findfirst(value -> !_line_grapheme_isspace(line, value), values), length(values) + 1)
    else
        firstindex(values)
    end
    for value in @view(values[first_value:end])
        if current_width + value.width > width && !isempty(current)
            if mode == WordWrap
                boundary = findlast(item -> _line_grapheme_isspace(line, item), current)
                if !isnothing(boundary)
                    push!(lines, _line_from_graphemes(line, @view(current[1:(boundary - 1)]), line.alignment))
                    deleteat!(current, 1:boundary)
                    current_width = sum(item -> item.width, current; init=0)
                else
                    push!(lines, _line_from_graphemes(line, current, line.alignment))
                    empty!(current)
                    current_width = 0
                end
            else
                push!(lines, _line_from_graphemes(line, current, line.alignment))
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
        push!(lines, _line_from_graphemes(line, current, line.alignment))
    lines
end

function _wrapped_lines(
    text::Text,
    width::Int,
    mode::WrapMode,
    policy::AbstractWidthPolicy,
    trim::Bool=false,
)
    lines = Line[]
    for line in text.lines
        append!(lines, _wrap_line(line, width, mode, policy, trim))
    end
    lines
end

"""A single-line text widget with optional truncation."""
struct Label{P<:AbstractWidthPolicy}
    line::Line
    ellipsis::String
    width_policy::P
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
    content_width = sum(
        span -> text_width(span.content, label.width_policy),
        label.line.spans;
        init=0,
    )
    if content_width <= area.width
        draw_line!(
            buffer,
            area.row,
            intersection(buffer.area, area),
            label.line;
            width_policy=label.width_policy,
            content_width,
        )
        return buffer
    end
    values = _truncate(
        _graphemes(label.line, label.width_policy),
        area.width,
        label.ellipsis,
        label.width_policy,
    )
    line = _line_from_graphemes(values, label.line.alignment)
    draw_line!(buffer, area.row, intersection(buffer.area, area), line; width_policy=label.width_policy)
    buffer
end

measure(label::Label, available::Rect) =
    Size(min(1, available.height), min(text_width(join(span.content for span in label.line.spans), label.width_policy), available.width))

"""Multi-line rich text with wrapping and explicit scroll offsets."""
struct Paragraph{P<:AbstractWidthPolicy}
    text::Text
    wrap::WrapMode
    vertical_scroll::Int
    horizontal_scroll::Int
    width_policy::P
    trim::Bool
end

function Paragraph(
    content::Union{AbstractString,Line,Text};
    style::Style=Style(),
    alignment::HorizontalAlignment=LeftAlign,
    wrap::WrapMode=WordWrap,
    vertical_scroll::Integer=0,
    horizontal_scroll::Integer=0,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
    trim::Bool=false,
)
    vertical_scroll >= 0 || throw(ArgumentError("vertical scroll must be non-negative"))
    horizontal_scroll >= 0 || throw(ArgumentError("horizontal scroll must be non-negative"))
    text = content isa Text ? content :
           content isa Line ? Text([content]) : Text(content; style, alignment)
    Paragraph(text, wrap, Int(vertical_scroll), Int(horizontal_scroll), width_policy, trim)
end

function _draw_scrolled_line!(
    buffer::Buffer,
    row::Int,
    area::Rect,
    line::Line,
    horizontal_scroll::Int,
    policy::AbstractWidthPolicy,
)
    horizontal_scroll == 0 &&
        return draw_line!(buffer, row, area, line; width_policy=policy)

    content_width = sum(span -> text_width(span.content, policy), line.spans; init=0)
    alignment_offset = if line.alignment == CenterAlign
        max(0, (area.width - content_width) ÷ 2)
    elseif line.alignment == RightAlign
        max(0, area.width - content_width)
    else
        0
    end

    if horizontal_scroll < alignment_offset
        leading = alignment_offset - horizontal_scroll
        visible = area.width - leading
        visible <= 0 && return Position(row, area.column)
        target = Rect(area.row, area.column + leading, area.height, visible)
        return draw_line!(
            buffer,
            row,
            target,
            Line(line.spans, LeftAlign);
            width_policy=policy,
            content_width,
        )
    end

    content_scroll = horizontal_scroll - alignment_offset
    content_scroll == 0 && return draw_line!(
        buffer,
        row,
        area,
        Line(line.spans, LeftAlign);
        width_policy=policy,
        content_width,
    )

    values = _line_graphemes(line, policy)
    index = firstindex(values)
    consumed = 0
    leading = 0
    while index <= lastindex(values)
        value = values[index]
        next_consumed = consumed + value.width
        if next_consumed <= content_scroll
            consumed = next_consumed
            index += 1
            continue
        end
        if consumed < content_scroll
            leading = next_consumed - content_scroll
            index += 1
        end
        break
    end
    index > lastindex(values) && return Position(row, area.column)

    available = area.width - leading
    available <= 0 && return Position(row, area.column)
    final_index = index - 1
    visible_width = 0
    while final_index < lastindex(values)
        candidate = values[final_index + 1]
        visible_width + candidate.width <= available || break
        visible_width += candidate.width
        final_index += 1
    end
    final_index < index && return Position(row, area.column)

    visible_line = _line_from_graphemes(
        line,
        @view(values[index:final_index]),
        LeftAlign,
    )
    target = Rect(area.row, area.column + leading, area.height, available)
    draw_line!(
        buffer,
        row,
        target,
        visible_line;
        width_policy=policy,
        content_width=visible_width,
    )
end

function render!(buffer::Buffer, paragraph::Paragraph, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    lines = _wrapped_lines(
        paragraph.text,
        area.width,
        paragraph.wrap,
        paragraph.width_policy,
        paragraph.trim,
    )
    first_line = min(length(lines) + 1, paragraph.vertical_scroll + 1)
    for (offset, line_index) in enumerate(first_line:length(lines))
        offset > active.height && break
        row = active.row + offset - 1
        _draw_scrolled_line!(
            buffer,
            row,
            active,
            lines[line_index],
            paragraph.horizontal_scroll,
            paragraph.width_policy,
        )
    end
    buffer
end

function measure(paragraph::Paragraph, available::Rect)
    lines = _wrapped_lines(
        paragraph.text,
        available.width,
        paragraph.wrap,
        paragraph.width_policy,
        paragraph.trim,
    )
    width = isempty(lines) ? 0 : maximum(
        line -> sum(span -> text_width(span.content, paragraph.width_policy), line.spans; init=0),
        lines,
    )
    Size(min(length(lines), available.height), min(width, available.width))
end

"""
    Static(content; style=Style(), alignment=LeftAlign, wrap=WordWrap)

Textual-style static display widget backed by `Paragraph`.

`Static` is a stable compatibility surface for read-only text content. It keeps
the same immediate rendering contract as `Paragraph` while using the vocabulary
common in Textual applications.
"""
struct Static{P<:Paragraph}
    paragraph::P
end

function Static(
    content::Union{AbstractString,Line,Text};
    style::Style=Style(),
    alignment::HorizontalAlignment=LeftAlign,
    wrap::WrapMode=WordWrap,
    vertical_scroll::Integer=0,
    horizontal_scroll::Integer=0,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
    trim::Bool=false,
)
    Static(Paragraph(content; style, alignment, wrap, vertical_scroll, horizontal_scroll, width_policy, trim))
end

render!(buffer::Buffer, widget::Static, area::Rect) =
    render!(buffer, widget.paragraph, area)

measure(widget::Static, available::Rect) =
    measure(widget.paragraph, available)

"""
    TextView(content; style=Style(), alignment=LeftAlign, wrap=WordWrap)

Generic read-only text view backed by `Paragraph`.

`TextView` is a stable compatibility surface for applications that name
read-only multi-line text displays as views. It keeps the same immediate
rendering and measuring contract as `Paragraph`.
"""
struct TextView{P<:Paragraph}
    paragraph::P
end

function TextView(
    content::Union{AbstractString,Line,Text};
    style::Style=Style(),
    alignment::HorizontalAlignment=LeftAlign,
    wrap::WrapMode=WordWrap,
    vertical_scroll::Integer=0,
    horizontal_scroll::Integer=0,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
    trim::Bool=false,
)
    TextView(Paragraph(content; style, alignment, wrap, vertical_scroll, horizontal_scroll, width_policy, trim))
end

render!(buffer::Buffer, widget::TextView, area::Rect) =
    render!(buffer, widget.paragraph, area)

measure(widget::TextView, available::Rect) =
    measure(widget.paragraph, available)

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
    Heading(content; level=1, style=Style(), alignment=LeftAlign, wrap=WordWrap)

Level-aware heading text backed by paragraph rendering.

`Heading` is a stable stateless widget with paragraph semantics and heading
appropriate styling:

- level 1 and 2 headings are bold and underlined
- other levels are bold
- content accepts `String`, `Line`, or `Text`
"""
struct Heading{P<:Paragraph}
    paragraph::P
    level::Int
end

function Heading(
    content::Union{AbstractString,Line,Text};
    level::Integer=1,
    style::Style=Style(),
    alignment::HorizontalAlignment=LeftAlign,
    wrap::WrapMode=WordWrap,
    vertical_scroll::Integer=0,
    horizontal_scroll::Integer=0,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
    trim::Bool=false,
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

    paragraph = Paragraph(
        text;
        wrap=wrap,
        vertical_scroll=vertical_scroll,
        horizontal_scroll=horizontal_scroll,
        width_policy=width_policy,
        trim=trim,
    )
    Heading(paragraph, Int(level))
end

render!(buffer::Buffer, widget::Heading, area::Rect) =
    render!(buffer, widget.paragraph, area)

measure(widget::Heading, available::Rect) =
    measure(widget.paragraph, available)

"""Default style contribution for a parsed markdown role."""
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

function _markup_roles(rendered)
    hasfield(typeof(rendered), :lines) || throw(ArgumentError("markup renderer returned unsupported result"))
    block_roles = Symbol[]
    inline_roles = Symbol[]
    for rich_line in rendered.lines
        push!(block_roles, rich_line.role)
        for span in rich_line.spans
            push!(inline_roles, span.role == :text ? rich_line.role : span.role)
        end
    end
    unique!(block_roles)
    unique!(inline_roles)
    return Tuple(block_roles), Tuple(inline_roles)
end

function _build_markup_document(
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
    text = _markup_text(rendered, alignment, style; role_styles=role_styles)
    block_roles, inline_roles = _markup_roles(rendered)
    return text, block_roles, inline_roles
end

"""
    MarkupText(content; style=Style(), alignment=LeftAlign, wrap=WordWrap)

Markdown-aware text with semantic role styling in a paragraph wrapper.

`MarkupText` is a stable stateless widget. Construction is intentionally
declarative and side-effect free: it parses markdown into semantic spans and
stores a `Paragraph` using `alignment`, wrapping, and scroll settings.
"""
struct MarkupText{P<:Paragraph}
    paragraph::P
    block_roles::Tuple{Vararg{Symbol}}
    inline_roles::Tuple{Vararg{Symbol}}
end

MarkupText(paragraph::Paragraph) = MarkupText(paragraph, (), ())

function MarkupText(
    content::AbstractString;
    style::Style=Style(),
    alignment::HorizontalAlignment=LeftAlign,
    wrap::WrapMode=WordWrap,
    vertical_scroll::Integer=0,
    horizontal_scroll::Integer=0,
    width::Integer=4096,
    registry=nothing,
    role_styles::Union{Nothing,AbstractDict{Symbol,Style}}=nothing,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
    trim::Bool=false,
)
    vertical_scroll >= 0 || throw(ArgumentError("vertical scroll must be non-negative"))
    role_styles === nothing && (role_styles = Dict{Symbol,Style}())
    text, block_roles, inline_roles = _build_markup_document(
        content;
        width=width,
        registry=registry,
        alignment=alignment,
        style=style,
        role_styles=role_styles,
    )
    paragraph = Paragraph(
        text;
        wrap=wrap,
        vertical_scroll=vertical_scroll,
        horizontal_scroll=horizontal_scroll,
        width_policy=width_policy,
        trim=trim,
    )
    MarkupText(paragraph, block_roles, inline_roles)
end

render!(buffer::Buffer, widget::MarkupText, area::Rect) =
    render!(buffer, widget.paragraph, area)

measure(widget::MarkupText, available::Rect) =
    measure(widget.paragraph, available)

"""Return true when a `MarkupText` contains a parsed block role."""
has_block_role(widget::MarkupText, role::Symbol) =
    role in widget.block_roles

"""Return true when a `MarkupText` contains a parsed inline role."""
has_inline_role(widget::MarkupText, role::Symbol) =
    role in widget.inline_roles
