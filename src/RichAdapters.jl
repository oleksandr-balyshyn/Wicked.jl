module RichAdapters

using ..RichContent: RichDocument, RichLine, RichSpan
using ..RichWidgets: MarkdownView,
                     MarkdownViewport,
                     MarkdownAction,
                     LinkActivation,
                     ScrollLineUp,
                     ScrollLineDown,
                     ScrollPageUp,
                     ScrollPageDown,
                     ScrollHome,
                     ScrollEnd,
                     FocusNextLink,
                     FocusPreviousLink,
                     ActivateFocusedLink,
                     focus_link!,
                     hit_test_link,
                     activate_link,
                     handle_markdown_action!

export KeyChord,
       MarkdownBindings,
       bind_markdown_key!,
       unbind_markdown_key!,
       default_markdown_bindings,
       action_for_key,
       MarkdownInputResult,
       handle_markdown_key!,
       MarkdownPointerKind,
       PointerHover,
       PointerPress,
       PointerLeave,
       MarkdownPointerEvent,
       handle_markdown_pointer!,
       RichStyleMap,
       StyledRichSpan,
       StyledRichLine,
       style_rich_line,
       style_markdown_viewport,
       semantic_roles

struct KeyChord
    key::Symbol
    control::Bool
    alt::Bool
    shift::Bool
end

function _normalize_key(key)
    value = lowercase(strip(string(key)))
    aliases = Dict(
        "pgup" => "pageup",
        "page_up" => "pageup",
        "pgdn" => "pagedown",
        "page_down" => "pagedown",
        "return" => "enter",
        "esc" => "escape",
    )
    return Symbol(get(aliases, value, value))
end

KeyChord(key; control::Bool=false, alt::Bool=false, shift::Bool=false) =
    KeyChord(_normalize_key(key), control, alt, shift)

mutable struct MarkdownBindings
    actions::Dict{KeyChord,MarkdownAction}
end

MarkdownBindings() = MarkdownBindings(Dict{KeyChord,MarkdownAction}())

function bind_markdown_key!(bindings::MarkdownBindings, chord::KeyChord, action::MarkdownAction)
    bindings.actions[chord] = action
    return bindings
end

function bind_markdown_key!(bindings::MarkdownBindings, key, action::MarkdownAction; modifiers...)
    return bind_markdown_key!(bindings, KeyChord(key; modifiers...), action)
end

function unbind_markdown_key!(bindings::MarkdownBindings, chord::KeyChord)
    pop!(bindings.actions, chord, nothing)
    return bindings
end

function default_markdown_bindings(; vim::Bool=false)
    bindings = MarkdownBindings()
    bind_markdown_key!(bindings, :up, ScrollLineUp)
    bind_markdown_key!(bindings, :down, ScrollLineDown)
    bind_markdown_key!(bindings, :pageup, ScrollPageUp)
    bind_markdown_key!(bindings, :pagedown, ScrollPageDown)
    bind_markdown_key!(bindings, :home, ScrollHome)
    bind_markdown_key!(bindings, :end, ScrollEnd)
    bind_markdown_key!(bindings, :tab, FocusNextLink)
    bind_markdown_key!(bindings, :tab, FocusPreviousLink; shift=true)
    bind_markdown_key!(bindings, :enter, ActivateFocusedLink)
    if vim
        bind_markdown_key!(bindings, :k, ScrollLineUp)
        bind_markdown_key!(bindings, :j, ScrollLineDown)
        bind_markdown_key!(bindings, :g, ScrollHome)
        bind_markdown_key!(bindings, :g, ScrollEnd; shift=true)
    end
    return bindings
end

function action_for_key(
    bindings::MarkdownBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    return get(bindings.actions, KeyChord(key; control=control, alt=alt, shift=shift), nothing)
end

struct MarkdownInputResult
    consumed::Bool
    action::Union{Nothing,MarkdownAction}
    activation::Union{Nothing,LinkActivation}
end

function handle_markdown_key!(
    view::MarkdownView,
    bindings::MarkdownBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
    viewport_height::Integer,
    allow_unsafe::Bool=false,
)
    action = action_for_key(bindings, key; control=control, alt=alt, shift=shift)
    action === nothing && return MarkdownInputResult(false, nothing, nothing)
    result = handle_markdown_action!(
        view,
        action;
        viewport_height=viewport_height,
        allow_unsafe=allow_unsafe,
    )
    activation = result isa LinkActivation ? result : nothing
    return MarkdownInputResult(true, action, activation)
end

@enum MarkdownPointerKind begin
    PointerHover
    PointerPress
    PointerLeave
end

struct MarkdownPointerEvent
    kind::MarkdownPointerKind
    row::Int
    column::Int

    function MarkdownPointerEvent(kind::MarkdownPointerKind, row::Integer, column::Integer)
        row >= 0 || throw(ArgumentError("pointer row cannot be negative"))
        column >= 0 || throw(ArgumentError("pointer column cannot be negative"))
        new(kind, Int(row), Int(column))
    end
end

function handle_markdown_pointer!(
    view::MarkdownView,
    event::MarkdownPointerEvent;
    allow_unsafe::Bool=false,
)
    if isequal(event.kind, PointerLeave)
        focus_link!(view, nothing)
        return MarkdownInputResult(true, nothing, nothing)
    end
    id = hit_test_link(view, event.row, event.column)
    focus_link!(view, id)
    if isequal(event.kind, PointerPress)
        if !isnothing(id)
            activation = activate_link(view, id; allow_unsafe=allow_unsafe)
            return MarkdownInputResult(true, ActivateFocusedLink, activation)
        end
        return MarkdownInputResult(false, nothing, nothing)
    end
    return isnothing(id) ? MarkdownInputResult(false, nothing, nothing) :
           MarkdownInputResult(true, nothing, nothing)
end

"""Semantic role-to-style mapping independent of the concrete style type."""
struct RichStyleMap{S}
    roles::Dict{Symbol,S}
    fallback::S
end

function RichStyleMap(roles::AbstractDict{Symbol,S}, fallback::S) where {S}
    return RichStyleMap{S}(Dict{Symbol,S}(roles), fallback)
end

RichStyleMap(fallback::S) where {S} = RichStyleMap{S}(Dict{Symbol,S}(), fallback)

struct StyledRichSpan{S}
    text::String
    style::S
    role::Symbol
    link_id::Union{Nothing,Int}
    focused::Bool
end

struct StyledRichLine{S}
    spans::Vector{StyledRichSpan{S}}
    role::Symbol
end

function style_rich_line(
    line::RichLine,
    styles::RichStyleMap{S};
    focused_link::Union{Nothing,Integer}=nothing,
) where {S}
    result = StyledRichSpan{S}[]
    for span in line.spans
        focused = focused_link !== nothing && span.link_id == focused_link
        role = focused ? :link_focused : span.role
        style = get(styles.roles, role, get(styles.roles, span.role, styles.fallback))
        push!(result, StyledRichSpan{S}(span.text, style, role, span.link_id, focused))
    end
    return StyledRichLine{S}(result, line.role)
end

function style_markdown_viewport(viewport::MarkdownViewport, styles::RichStyleMap{S}) where {S}
    return StyledRichLine{S}[
        style_rich_line(line, styles; focused_link=viewport.focused_link) for line in viewport.lines
    ]
end

function semantic_roles(document::RichDocument)
    roles = Set{Symbol}()
    for line in document.lines
        push!(roles, line.role)
        for span in line.spans
            push!(roles, span.role)
        end
    end
    return roles
end

end
