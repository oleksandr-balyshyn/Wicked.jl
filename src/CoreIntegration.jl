module CoreIntegration

import ..Core as WickedCore
import ..Widgets as WickedWidgets
import ..Toolkit as WickedToolkit
using ..RichContent: RichSpan, RichLine
using ..RichSurfaces: RichSurface, RichSurfaceCell
using ..RichWidgets: MarkdownView, MarkdownViewport, markdown_viewport

export CoreAdapterError,
       RoleStyleResolver,
       resolve_role_style,
       CoreTextAdapter,
       rich_span_to_core,
       rich_line_to_core,
       rich_lines_to_core_text,
       markdown_core_text,
       CoreBufferAdapter,
       blit_rich_to_core!,
       render_rich_frame!,
       ToolkitElementAdapter,
       rich_paragraph_widget,
       rich_toolkit_element,
       MarkdownToolkitComponent,
       markdown_paragraph_widget,
       markdown_toolkit_element

struct CoreAdapterError <: Exception
    operation::Symbol
    message::String
    attempts::Vector{String}
end

function Base.showerror(io::IO, error::CoreAdapterError)
    print(io, "Wicked Core adapter ", error.operation, " failed: ", error.message)
    isempty(error.attempts) || print(io, "\nTried: ", join(error.attempts, ", "))
end

struct RoleStyleResolver{S}
    roles::Dict{Symbol,S}
    fallback::S
    focused_role::Symbol
    selected_role::Symbol
end

function RoleStyleResolver(
    roles::AbstractDict{Symbol,S},
    fallback::S;
    focused_role::Symbol=:focused,
    selected_role::Symbol=:selected,
) where {S}
    return RoleStyleResolver{S}(
        Dict{Symbol,S}(roles),
        fallback,
        focused_role,
        selected_role,
    )
end

RoleStyleResolver(fallback::S; kwargs...) where {S} =
    RoleStyleResolver(Dict{Symbol,S}(), fallback; kwargs...)

function resolve_role_style(
    resolver::RoleStyleResolver,
    role::Symbol;
    focused::Bool=false,
    selected::Bool=false,
)
    selected && haskey(resolver.roles, resolver.selected_role) &&
        return resolver.roles[resolver.selected_role]
    focused && haskey(resolver.roles, resolver.focused_role) &&
        return resolver.roles[resolver.focused_role]
    return get(resolver.roles, role, resolver.fallback)
end

resolve_role_style(resolver, role::Symbol; focused::Bool=false, selected::Bool=false) =
    try
        resolver(role; focused=focused, selected=selected)
    catch error
        if error isa MethodError && error.f === Core.kwcall && applicable(resolver, role)
            resolver(role)
        else
            rethrow()
        end
    end

function _attempt(operation::Symbol, candidates)
    attempts = String[]
    for (description, candidate) in candidates
        push!(attempts, description)
        try
            return candidate()
        catch error
            error isa MethodError || rethrow()
        end
    end
    throw(CoreAdapterError(operation, "no compatible public constructor or method was found", attempts))
end

function _default_core_style()
    isdefined(WickedCore, :Style) ||
        throw(CoreAdapterError(:style, "Core.Style is not available", String[]))
    constructor = getfield(WickedCore, :Style)
    return _attempt(:style, [("Style()", () -> constructor())])
end

function _default_span_factory(text::String, style)
    isdefined(WickedCore, :Span) ||
        throw(CoreAdapterError(:span, "Core.Span is not available", String[]))
    constructor = getfield(WickedCore, :Span)
    return _attempt(
        :span,
        [
            ("Span(text, style)", () -> constructor(text, style)),
            ("Span(text; style=style)", () -> constructor(text; style=style)),
            ("Span(text)", () -> constructor(text)),
        ],
    )
end

function _default_line_factory(spans)
    isdefined(WickedCore, :Line) ||
        throw(CoreAdapterError(:line, "Core.Line is not available", String[]))
    constructor = getfield(WickedCore, :Line)
    span_type = isdefined(WickedCore, :Span) ? getfield(WickedCore, :Span) : Any
    return _attempt(
        :line,
        [
            ("Line(Vector{Span}(spans))", () -> constructor(Vector{span_type}(spans))),
            ("Line(spans)", () -> constructor(spans)),
            ("Line(tuple(spans...))", () -> constructor(tuple(spans...))),
        ],
    )
end

function _default_text_factory(lines)
    isdefined(WickedCore, :Text) ||
        throw(CoreAdapterError(:text, "Core.Text is not available", String[]))
    constructor = getfield(WickedCore, :Text)
    line_type = isdefined(WickedCore, :Line) ? getfield(WickedCore, :Line) : Any
    return _attempt(
        :text,
        [
            ("Text(Vector{Line}(lines))", () -> constructor(Vector{line_type}(lines))),
            ("Text(lines)", () -> constructor(lines)),
            ("Text(tuple(lines...))", () -> constructor(tuple(lines...))),
        ],
    )
end

struct CoreTextAdapter{R,S,L,T}
    styles::R
    span_factory::S
    line_factory::L
    text_factory::T
end

function CoreTextAdapter(;
    styles=RoleStyleResolver(_default_core_style()),
    span_factory=_default_span_factory,
    line_factory=_default_line_factory,
    text_factory=_default_text_factory,
)
    return CoreTextAdapter{typeof(styles),typeof(span_factory),typeof(line_factory),typeof(text_factory)}(
        styles,
        span_factory,
        line_factory,
        text_factory,
    )
end

function rich_span_to_core(
    adapter::CoreTextAdapter,
    span::RichSpan;
    focused_link::Union{Nothing,Integer}=nothing,
    selected::Bool=false,
)
    focused = focused_link !== nothing && span.link_id == focused_link
    style = resolve_role_style(adapter.styles, span.role; focused=focused, selected=selected)
    return adapter.span_factory(span.text, style)
end

function rich_line_to_core(
    adapter::CoreTextAdapter,
    line::RichLine;
    focused_link::Union{Nothing,Integer}=nothing,
    selected::Bool=false,
)
    spans = Any[
        rich_span_to_core(adapter, span; focused_link=focused_link, selected=selected)
        for span in line.spans
    ]
    return adapter.line_factory(spans)
end

function rich_lines_to_core_text(
    adapter::CoreTextAdapter,
    lines::AbstractVector{RichLine};
    focused_link::Union{Nothing,Integer}=nothing,
)
    converted = Any[
        rich_line_to_core(adapter, line; focused_link=focused_link) for line in lines
    ]
    return adapter.text_factory(converted)
end

function markdown_core_text(
    adapter::CoreTextAdapter,
    view::MarkdownView,
    height::Integer,
)
    viewport = markdown_viewport(view, height)
    return rich_lines_to_core_text(
        adapter,
        viewport.lines;
        focused_link=viewport.focused_link,
    )
end

function _construct_core_cell(cell::RichSurfaceCell, style)
    isdefined(WickedCore, :Cell) ||
        throw(CoreAdapterError(:cell, "Core.Cell is not available", String[]))
    constructor = getfield(WickedCore, :Cell)
    text = cell.continuation ? "" : cell.grapheme
    character = length(text) == 1 ? first(text) : nothing
    candidates = Tuple{String,Function}[
        ("Cell(text, style, continuation)", () -> constructor(text, style, cell.continuation)),
        ("Cell(text, style)", () -> constructor(text, style)),
        ("Cell(text)", () -> constructor(text)),
    ]
    if character !== nothing
        append!(
            candidates,
            [
                ("Cell(char, style, continuation)", () -> constructor(character, style, cell.continuation)),
                ("Cell(char, style)", () -> constructor(character, style)),
                ("Cell(char)", () -> constructor(character)),
            ],
        )
    end
    return _attempt(:cell, candidates)
end

function _default_buffer_writer(buffer, x::Int, y::Int, cell::RichSurfaceCell, style)
    core_cell = _construct_core_cell(cell, style)
    attempts = Tuple{String,Function}[]
    for name in (:set_cell!, :put_cell!, :set!)
        isdefined(WickedCore, name) || continue
        writer = getfield(WickedCore, name)
        push!(attempts, ("$name(buffer, x, y, cell)", () -> writer(buffer, x, y, core_cell)))
        if isdefined(WickedCore, :Position)
            position = getfield(WickedCore, :Position)
            push!(attempts, ("$name(buffer, Position(x, y), cell)", () -> writer(buffer, position(x, y), core_cell)))
        end
    end
    return _attempt(:buffer_write, attempts)
end

struct CoreBufferAdapter{R,W}
    styles::R
    writer::W
    coordinate_base::Int
end

function CoreBufferAdapter(;
    styles=RoleStyleResolver(_default_core_style()),
    writer=_default_buffer_writer,
    coordinate_base::Integer=0,
)
    coordinate_base in (0, 1) || throw(ArgumentError("Core buffer coordinate base must be 0 or 1"))
    return CoreBufferAdapter{typeof(styles),typeof(writer)}(styles, writer, Int(coordinate_base))
end

function blit_rich_to_core!(
    adapter::CoreBufferAdapter,
    buffer,
    surface::RichSurface;
    row::Integer=1,
    column::Integer=1,
)
    for source_row in 1:surface.height, source_column in 1:surface.width
        cell = surface.cells[source_row, source_column]
        style = resolve_role_style(
            adapter.styles,
            cell.role;
            focused=cell.role == :link_focused,
            selected=cell.selected,
        )
        x = Int(column) + source_column - 2 + adapter.coordinate_base
        y = Int(row) + source_row - 2 + adapter.coordinate_base
        adapter.writer(buffer, x, y, cell, style)
    end
    return buffer
end

function _frame_buffer(frame)
    hasproperty(frame, :buffer) && return getproperty(frame, :buffer)
    isdefined(WickedCore, :buffer) && applicable(getfield(WickedCore, :buffer), frame) &&
        return getfield(WickedCore, :buffer)(frame)
    throw(CoreAdapterError(:frame, "frame does not expose a buffer", ["frame.buffer", "Core.buffer(frame)"]))
end

function render_rich_frame!(
    adapter::CoreBufferAdapter,
    frame,
    surface::RichSurface;
    kwargs...,
)
    blit_rich_to_core!(adapter, _frame_buffer(frame), surface; kwargs...)
    return frame
end

function _default_paragraph_factory(text)
    isdefined(WickedWidgets, :Paragraph) ||
        throw(CoreAdapterError(:paragraph, "Widgets.Paragraph is not available", String[]))
    constructor = getfield(WickedWidgets, :Paragraph)
    return _attempt(
        :paragraph,
        [
            ("Paragraph(text)", () -> constructor(text)),
            ("Paragraph(text; wrap=true)", () -> constructor(text; wrap=true)),
        ],
    )
end

function _default_element_factory(widget; key=nothing, id=nothing, classes=String[], focusable=false)
    isdefined(WickedToolkit, :leaf) ||
        throw(CoreAdapterError(:element, "Toolkit.leaf is not available", String[]))
    factory = getfield(WickedToolkit, :leaf)
    candidates = Tuple{String,Function}[
        (
            "leaf(widget; key, id, classes, focusable)",
            () -> factory(widget; key=key, id=id, classes=classes, focusable=focusable),
        ),
        ("leaf(widget; key, id)", () -> factory(widget; key=key, id=id)),
        ("leaf(widget)", () -> factory(widget)),
    ]
    return _attempt(:element, candidates)
end

struct ToolkitElementAdapter{T,P,E}
    text::T
    paragraph_factory::P
    element_factory::E
end

function ToolkitElementAdapter(;
    text::CoreTextAdapter=CoreTextAdapter(),
    paragraph_factory=_default_paragraph_factory,
    element_factory=_default_element_factory,
)
    return ToolkitElementAdapter{typeof(text),typeof(paragraph_factory),typeof(element_factory)}(
        text,
        paragraph_factory,
        element_factory,
    )
end

function rich_paragraph_widget(adapter::ToolkitElementAdapter, lines::AbstractVector{RichLine}; kwargs...)
    text = rich_lines_to_core_text(adapter.text, lines; kwargs...)
    return adapter.paragraph_factory(text)
end

function rich_toolkit_element(
    adapter::ToolkitElementAdapter,
    lines::AbstractVector{RichLine};
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=false,
    focused_link=nothing,
)
    widget = rich_paragraph_widget(adapter, lines; focused_link=focused_link)
    return adapter.element_factory(
        widget;
        key=key,
        id=id,
        classes=classes,
        focusable=focusable,
    )
end

struct MarkdownToolkitComponent{A}
    view::MarkdownView
    adapter::A
end

MarkdownToolkitComponent(
    view::MarkdownView;
    adapter::ToolkitElementAdapter=ToolkitElementAdapter(),
) = MarkdownToolkitComponent{typeof(adapter)}(view, adapter)

function markdown_paragraph_widget(
    component::MarkdownToolkitComponent,
    height::Integer,
)
    viewport = markdown_viewport(component.view, height)
    return rich_paragraph_widget(
        component.adapter,
        viewport.lines;
        focused_link=viewport.focused_link,
    )
end

function markdown_toolkit_element(
    component::MarkdownToolkitComponent,
    height::Integer;
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    viewport = markdown_viewport(component.view, height)
    return rich_toolkit_element(
        component.adapter,
        viewport.lines;
        key=key,
        id=id,
        classes=classes,
        focusable=focusable,
        focused_link=viewport.focused_link,
    )
end

end
