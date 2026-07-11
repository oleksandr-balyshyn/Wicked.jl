module RichWidgets

using Unicode: graphemes
using ..RichContent: MarkdownDocument,
                     RichDocument,
                     RichLine,
                     RenderedLink,
                     LinkTarget,
                     SyntaxRegistry,
                     default_syntax_registry,
                     parse_markdown,
                     render_markdown,
                     plain_text,
                     link_by_id

export TextPoint,
       TextSelection,
       LinkActivation,
       MarkdownViewport,
       MarkdownAction,
       ScrollLineUp,
       ScrollLineDown,
       ScrollPageUp,
       ScrollPageDown,
       ScrollHome,
       ScrollEnd,
       FocusNextLink,
       FocusPreviousLink,
       ActivateFocusedLink,
       MarkdownView,
       set_markdown!,
       reflow_markdown!,
       markdown_line_count,
       markdown_max_scroll,
       scroll_markdown_to!,
       scroll_markdown_by!,
       markdown_page_up!,
       markdown_page_down!,
       markdown_home!,
       markdown_end!,
       focus_next_link!,
       focus_previous_link!,
       focus_link!,
       ensure_focused_link_visible!,
       hit_test_link,
       activate_link,
       activate_focused_link,
       select_markdown_text!,
       clear_markdown_selection!,
       markdown_selected_text,
       markdown_viewport,
       handle_markdown_action!

struct TextPoint
    line::Int
    column::Int

    function TextPoint(line::Integer, column::Integer)
        line > 0 || throw(ArgumentError("text line must be positive"))
        column > 0 || throw(ArgumentError("text column must be positive"))
        new(Int(line), Int(column))
    end
end

struct TextSelection
    anchor::TextPoint
    head::TextPoint
end

struct LinkActivation
    link::Union{Nothing,RenderedLink}
    allowed::Bool
    reason::Symbol
end

struct MarkdownViewport
    lines::Vector{RichLine}
    first_line::Int
    total_lines::Int
    focused_link::Union{Nothing,Int}
    selection::Union{Nothing,TextSelection}
end

@enum MarkdownAction begin
    ScrollLineUp
    ScrollLineDown
    ScrollPageUp
    ScrollPageDown
    ScrollHome
    ScrollEnd
    FocusNextLink
    FocusPreviousLink
    ActivateFocusedLink
end

"""
Stateful Markdown component with cached parsing, reflow, navigation, and links.

The view is deliberately event-protocol independent. Backends and declarative
components map their key or mouse events to `MarkdownAction` values and consume
the returned `LinkActivation` when activation is requested.
"""
mutable struct MarkdownView
    source::String
    parsed::MarkdownDocument
    rendered::RichDocument
    registry::SyntaxRegistry
    width::Int
    scroll::Int
    focused_link::Union{Nothing,Int}
    selection::Union{Nothing,TextSelection}
end

function MarkdownView(
    source::AbstractString="";
    width::Integer=80,
    registry::SyntaxRegistry=default_syntax_registry(),
)
    width > 0 || throw(ArgumentError("MarkdownView width must be positive"))
    value = String(source)
    parsed = parse_markdown(value)
    rendered = render_markdown(parsed; width=width, registry=registry)
    return MarkdownView(value, parsed, rendered, registry, Int(width), 0, nothing, nothing)
end

line_count(view::MarkdownView) = length(view.rendered.lines)

function max_scroll(view::MarkdownView, viewport_height::Integer)
    viewport_height >= 0 || throw(ArgumentError("viewport height cannot be negative"))
    return max(0, line_count(view) - Int(viewport_height))
end

function _normalize!(view::MarkdownView, viewport_height::Integer=0)
    view.scroll = clamp(view.scroll, 0, max_scroll(view, viewport_height))
    if view.focused_link !== nothing && link_by_id(view.rendered, view.focused_link) === nothing
        view.focused_link = nothing
    end
    return view
end

function set_markdown!(view::MarkdownView, source::AbstractString)
    view.source = String(source)
    view.parsed = parse_markdown(view.source)
    view.rendered = render_markdown(view.parsed; width=view.width, registry=view.registry)
    view.scroll = 0
    view.focused_link = nothing
    view.selection = nothing
    return view
end

function reflow!(view::MarkdownView, width::Integer; viewport_height::Integer=0)
    width > 0 || throw(ArgumentError("MarkdownView width must be positive"))
    viewport_height >= 0 || throw(ArgumentError("viewport height cannot be negative"))
    width == view.width && return _normalize!(view, viewport_height)
    old_count = max(1, line_count(view))
    relative_position = view.scroll / old_count
    view.width = Int(width)
    view.rendered = render_markdown(view.parsed; width=view.width, registry=view.registry)
    view.scroll = round(Int, relative_position * max(1, line_count(view)))
    view.selection = nothing
    return _normalize!(view, viewport_height)
end

function scroll_to!(view::MarkdownView, line_offset::Integer; viewport_height::Integer=0)
    view.scroll = clamp(Int(line_offset), 0, max_scroll(view, viewport_height))
    return view
end

scroll_by!(view::MarkdownView, delta::Integer; viewport_height::Integer=0) =
    scroll_to!(view, view.scroll + Int(delta); viewport_height=viewport_height)

page_up!(view::MarkdownView, viewport_height::Integer) =
    scroll_by!(view, -max(1, Int(viewport_height) - 1); viewport_height=viewport_height)

page_down!(view::MarkdownView, viewport_height::Integer) =
    scroll_by!(view, max(1, Int(viewport_height) - 1); viewport_height=viewport_height)

scroll_home!(view::MarkdownView; viewport_height::Integer=0) =
    scroll_to!(view, 0; viewport_height=viewport_height)

scroll_end!(view::MarkdownView, viewport_height::Integer) =
    scroll_to!(view, max_scroll(view, viewport_height); viewport_height=viewport_height)

function _ordered_link_ids(view::MarkdownView)
    ids = Int[]
    seen = Set{Int}()
    for line in view.rendered.lines, span in line.spans
        id = span.link_id
        if id !== nothing && !(id in seen)
            push!(ids, id)
            push!(seen, id)
        end
    end
    return ids
end

function focus_link!(view::MarkdownView, id::Union{Nothing,Integer})
    if id === nothing
        view.focused_link = nothing
    else
        link_by_id(view.rendered, id) === nothing && throw(ArgumentError("unknown Markdown link id: $id"))
        view.focused_link = Int(id)
    end
    return view
end

function focus_next_link!(view::MarkdownView; wrap::Bool=true)
    ids = _ordered_link_ids(view)
    isempty(ids) && return focus_link!(view, nothing)
    current = view.focused_link === nothing ? nothing : findfirst(==(view.focused_link), ids)
    if current === nothing
        view.focused_link = first(ids)
    elseif current < length(ids)
        view.focused_link = ids[current + 1]
    elseif wrap
        view.focused_link = first(ids)
    end
    return view
end

function focus_previous_link!(view::MarkdownView; wrap::Bool=true)
    ids = _ordered_link_ids(view)
    isempty(ids) && return focus_link!(view, nothing)
    current = view.focused_link === nothing ? nothing : findfirst(==(view.focused_link), ids)
    if current === nothing
        view.focused_link = last(ids)
    elseif current > 1
        view.focused_link = ids[current - 1]
    elseif wrap
        view.focused_link = last(ids)
    end
    return view
end

function _link_line(view::MarkdownView, id::Int)
    return findfirst(line -> any(span -> span.link_id == id, line.spans), view.rendered.lines)
end

function ensure_focused_link_visible!(view::MarkdownView, viewport_height::Integer)
    viewport_height > 0 || return view
    view.focused_link === nothing && return view
    line = _link_line(view, view.focused_link)
    line === nothing && return view
    zero_based = line - 1
    if zero_based < view.scroll
        view.scroll = zero_based
    elseif zero_based >= view.scroll + viewport_height
        view.scroll = zero_based - Int(viewport_height) + 1
    end
    return _normalize!(view, viewport_height)
end

function hit_test_link(view::MarkdownView, viewport_row::Integer, cell_column::Integer)
    viewport_row > 0 || return nothing
    cell_column > 0 || return nothing
    document_line = view.scroll + Int(viewport_row)
    1 <= document_line <= line_count(view) || return nothing
    cursor = 1
    for span in view.rendered.lines[document_line].spans
        span_width = textwidth(span.text)
        if cursor <= cell_column < cursor + span_width
            return span.link_id
        end
        cursor += span_width
    end
    return nothing
end

function activate_link(view::MarkdownView, id::Integer; allow_unsafe::Bool=false)
    link = link_by_id(view.rendered, id)
    link === nothing && return LinkActivation(nothing, false, :not_found)
    link.target.safe && return LinkActivation(link, true, :safe)
    allow_unsafe && return LinkActivation(link, true, :explicitly_allowed)
    return LinkActivation(link, false, :unsafe_destination)
end

function activate_focused_link(view::MarkdownView; allow_unsafe::Bool=false)
    view.focused_link === nothing && return LinkActivation(nothing, false, :no_focus)
    return activate_link(view, view.focused_link; allow_unsafe=allow_unsafe)
end

function _clamp_point(view::MarkdownView, point::TextPoint)
    isempty(view.rendered.lines) && return TextPoint(1, 1)
    line = clamp(point.line, 1, line_count(view))
    value = plain_text(view.rendered.lines[line])
    column = clamp(point.column, 1, length(value) + 1)
    return TextPoint(line, column)
end

function select_text!(view::MarkdownView, anchor::TextPoint, head::TextPoint)
    view.selection = TextSelection(_clamp_point(view, anchor), _clamp_point(view, head))
    return view
end

clear_selection!(view::MarkdownView) = (view.selection = nothing; view)

function _ordered(selection::TextSelection)
    anchor_key = (selection.anchor.line, selection.anchor.column)
    head_key = (selection.head.line, selection.head.column)
    return anchor_key <= head_key ? (selection.anchor, selection.head) : (selection.head, selection.anchor)
end

function _character_slice(value::String, first_column::Int, stop_column::Int)
    first_column >= stop_column && return ""
    characters = collect(value)
    first_index = clamp(first_column, 1, length(characters) + 1)
    stop_index = clamp(stop_column - 1, 0, length(characters))
    first_index > stop_index && return ""
    return join(@view characters[first_index:stop_index])
end

function selected_text(view::MarkdownView)
    view.selection === nothing && return ""
    isempty(view.rendered.lines) && return ""
    first_point, stop_point = _ordered(view.selection)
    selected = String[]
    for line_index in first_point.line:stop_point.line
        value = plain_text(view.rendered.lines[line_index])
        first_column = line_index == first_point.line ? first_point.column : 1
        stop_column = line_index == stop_point.line ? stop_point.column : length(value) + 1
        push!(selected, _character_slice(value, first_column, stop_column))
    end
    return join(selected, '\n')
end

function viewport(view::MarkdownView, height::Integer)
    height >= 0 || throw(ArgumentError("viewport height cannot be negative"))
    _normalize!(view, height)
    if height == 0 || isempty(view.rendered.lines)
        lines = RichLine[]
    else
        first_line = view.scroll + 1
        last_line = min(line_count(view), view.scroll + Int(height))
        lines = copy(@view view.rendered.lines[first_line:last_line])
    end
    return MarkdownViewport(lines, view.scroll + 1, line_count(view), view.focused_link, view.selection)
end

function handle_action!(
    view::MarkdownView,
    action::MarkdownAction;
    viewport_height::Integer,
    allow_unsafe::Bool=false,
)
    if action == ScrollLineUp
        scroll_by!(view, -1; viewport_height=viewport_height)
    elseif action == ScrollLineDown
        scroll_by!(view, 1; viewport_height=viewport_height)
    elseif action == ScrollPageUp
        page_up!(view, viewport_height)
    elseif action == ScrollPageDown
        page_down!(view, viewport_height)
    elseif action == ScrollHome
        scroll_home!(view; viewport_height=viewport_height)
    elseif action == ScrollEnd
        scroll_end!(view, viewport_height)
    elseif action == FocusNextLink
        focus_next_link!(view)
        ensure_focused_link_visible!(view, viewport_height)
    elseif action == FocusPreviousLink
        focus_previous_link!(view)
        ensure_focused_link_visible!(view, viewport_height)
    elseif action == ActivateFocusedLink
        return activate_focused_link(view; allow_unsafe=allow_unsafe)
    end
    return nothing
end

# Root-level names are intentionally Markdown-specific. Wicked already exposes
# scrolling and editing generics whose ownership must remain unambiguous.
reflow_markdown!(view::MarkdownView, width::Integer; kwargs...) =
    reflow!(view, width; kwargs...)
markdown_line_count(view::MarkdownView) = line_count(view)
markdown_max_scroll(view::MarkdownView, height::Integer) = max_scroll(view, height)
scroll_markdown_to!(view::MarkdownView, offset::Integer; kwargs...) =
    scroll_to!(view, offset; kwargs...)
scroll_markdown_by!(view::MarkdownView, delta::Integer; kwargs...) =
    scroll_by!(view, delta; kwargs...)
markdown_page_up!(view::MarkdownView, height::Integer) = page_up!(view, height)
markdown_page_down!(view::MarkdownView, height::Integer) = page_down!(view, height)
markdown_home!(view::MarkdownView; kwargs...) = scroll_home!(view; kwargs...)
markdown_end!(view::MarkdownView, height::Integer) = scroll_end!(view, height)
select_markdown_text!(view::MarkdownView, anchor::TextPoint, head::TextPoint) =
    select_text!(view, anchor, head)
clear_markdown_selection!(view::MarkdownView) = clear_selection!(view)
markdown_selected_text(view::MarkdownView) = selected_text(view)
markdown_viewport(view::MarkdownView, height::Integer) = viewport(view, height)
handle_markdown_action!(view::MarkdownView, action::MarkdownAction; kwargs...) =
    handle_action!(view, action; kwargs...)

end
