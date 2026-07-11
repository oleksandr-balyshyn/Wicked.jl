module VirtualInput

using ..RichAdapters: KeyChord
using ..Virtualization: ReadySlot,
                        VirtualListState,
                        VirtualListWindow,
                        VirtualTableWindow,
                        scroll_virtual_list!,
                        move_virtual_cursor!,
                        ensure_virtual_cursor_visible!
using ..VirtualTrees: VirtualTreeState, VirtualTreeWindow, toggle_virtual_tree!
using ..VirtualRendering: VirtualAction,
                          VirtualCursorUp,
                          VirtualCursorDown,
                          VirtualPageUp,
                          VirtualPageDown,
                          VirtualHome,
                          VirtualEnd,
                          VirtualToggleSelection,
                          VirtualActivate,
                          VirtualExpand,
                          VirtualCollapse,
                          VirtualActionResult,
                          virtual_list_slot_at,
                          virtual_tree_row_at,
                          handle_virtual_list_action!,
                          handle_virtual_tree_action!

export VirtualBindings,
       bind_virtual_key!,
       unbind_virtual_key!,
       default_virtual_bindings,
       virtual_action_for_key,
       handle_virtual_key!,
       VirtualPointerKind,
       VirtualPointerHover,
       VirtualPointerPress,
       VirtualPointerDoublePress,
       VirtualPointerLeave,
       VirtualPointerEvent,
       VirtualPointerOptions,
       VirtualPointerResult,
       handle_virtual_pointer!

mutable struct VirtualBindings
    actions::Dict{KeyChord,VirtualAction}
end

VirtualBindings() = VirtualBindings(Dict{KeyChord,VirtualAction}())

function bind_virtual_key!(bindings::VirtualBindings, chord::KeyChord, action::VirtualAction)
    bindings.actions[chord] = action
    return bindings
end

function bind_virtual_key!(bindings::VirtualBindings, key, action::VirtualAction; modifiers...)
    return bind_virtual_key!(bindings, KeyChord(key; modifiers...), action)
end

function unbind_virtual_key!(bindings::VirtualBindings, chord::KeyChord)
    pop!(bindings.actions, chord, nothing)
    return bindings
end

function default_virtual_bindings(; vim::Bool=false)
    bindings = VirtualBindings()
    bind_virtual_key!(bindings, :up, VirtualCursorUp)
    bind_virtual_key!(bindings, :down, VirtualCursorDown)
    bind_virtual_key!(bindings, :pageup, VirtualPageUp)
    bind_virtual_key!(bindings, :pagedown, VirtualPageDown)
    bind_virtual_key!(bindings, :home, VirtualHome)
    bind_virtual_key!(bindings, :end, VirtualEnd)
    bind_virtual_key!(bindings, :space, VirtualToggleSelection)
    bind_virtual_key!(bindings, :enter, VirtualActivate)
    bind_virtual_key!(bindings, :right, VirtualExpand)
    bind_virtual_key!(bindings, :left, VirtualCollapse)
    if vim
        bind_virtual_key!(bindings, :k, VirtualCursorUp)
        bind_virtual_key!(bindings, :j, VirtualCursorDown)
        bind_virtual_key!(bindings, :g, VirtualHome)
        bind_virtual_key!(bindings, :g, VirtualEnd; shift=true)
        bind_virtual_key!(bindings, :l, VirtualExpand)
        bind_virtual_key!(bindings, :h, VirtualCollapse)
    end
    return bindings
end

function virtual_action_for_key(
    bindings::VirtualBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    return get(
        bindings.actions,
        KeyChord(key; control=control, alt=alt, shift=shift),
        nothing,
    )
end

function _unhandled_result(::Type{K}, action::VirtualAction=VirtualActivate) where {K}
    return VirtualActionResult{K}(false, action, nothing)
end

function handle_virtual_key!(
    state::VirtualListState{K},
    window::VirtualListWindow{T,K},
    bindings::VirtualBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
) where {T,K}
    action = virtual_action_for_key(bindings, key; control=control, alt=alt, shift=shift)
    action === nothing && return _unhandled_result(K)
    return handle_virtual_list_action!(state, window, action)
end

function handle_virtual_key!(
    state::VirtualTreeState{K},
    window::VirtualTreeWindow{T,K},
    bindings::VirtualBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
    page_size::Integer=10,
) where {T,K}
    action = virtual_action_for_key(bindings, key; control=control, alt=alt, shift=shift)
    action === nothing && return _unhandled_result(K)
    return handle_virtual_tree_action!(state, window, action; page_size=page_size)
end

function _table_row_for_cursor(window::VirtualTableWindow, cursor)
    cursor === nothing && return nothing
    for row in window.rows
        row.index == cursor && return row
    end
    return nothing
end

function _handle_virtual_table_action!(
    state::VirtualListState{K},
    window::VirtualTableWindow{K},
    action::VirtualAction,
) where {K}
    total = window.total_length
    page = max(1, state.viewport.viewport_size - 1)
    if action == VirtualCursorUp
        move_virtual_cursor!(state, -1; total_length=total)
    elseif action == VirtualCursorDown
        move_virtual_cursor!(state, 1; total_length=total)
    elseif action == VirtualPageUp
        move_virtual_cursor!(state, -page; total_length=total)
    elseif action == VirtualPageDown
        move_virtual_cursor!(state, page; total_length=total)
    elseif action == VirtualHome
        state.cursor = total == 0 ? nothing : 1
    elseif action == VirtualEnd
        total === nothing && return _unhandled_result(K, action)
        state.cursor = total == 0 ? nothing : total
    elseif action == VirtualToggleSelection
        row = _table_row_for_cursor(window, state.cursor)
        if row === nothing || row.key === nothing
            return _unhandled_result(K, action)
        end
        key = row.key::K
        if key in state.selected
            delete!(state.selected, key)
        else
            state.multiple || empty!(state.selected)
            push!(state.selected, key)
        end
        state.anchor = row.index
    elseif action == VirtualActivate
        row = _table_row_for_cursor(window, state.cursor)
        key = row === nothing ? nothing : row.key
        return VirtualActionResult{K}(key !== nothing, action, key)
    else
        return _unhandled_result(K, action)
    end
    ensure_virtual_cursor_visible!(state; total_length=total)
    row = _table_row_for_cursor(window, state.cursor)
    return VirtualActionResult{K}(true, action, row === nothing ? nothing : row.key)
end

function handle_virtual_key!(
    state::VirtualListState{K},
    window::VirtualTableWindow{K},
    bindings::VirtualBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
) where {K}
    action = virtual_action_for_key(bindings, key; control=control, alt=alt, shift=shift)
    action === nothing && return _unhandled_result(K)
    return _handle_virtual_table_action!(state, window, action)
end

@enum VirtualPointerKind begin
    VirtualPointerHover
    VirtualPointerPress
    VirtualPointerDoublePress
    VirtualPointerLeave
end

struct VirtualPointerEvent
    kind::VirtualPointerKind
    row::Int
    column::Int
    control::Bool
    shift::Bool

    function VirtualPointerEvent(
        kind::VirtualPointerKind,
        row::Integer,
        column::Integer;
        control::Bool=false,
        shift::Bool=false,
    )
        row >= 0 || throw(ArgumentError("virtual pointer row cannot be negative"))
        column >= 0 || throw(ArgumentError("virtual pointer column cannot be negative"))
        new(kind, Int(row), Int(column), control, shift)
    end
end

struct VirtualPointerOptions
    focus_on_hover::Bool
    select_on_press::Bool
    toggle_with_control::Bool
    activate_on_double_press::Bool
end

VirtualPointerOptions(;
    focus_on_hover::Bool=true,
    select_on_press::Bool=true,
    toggle_with_control::Bool=true,
    activate_on_double_press::Bool=true,
) = VirtualPointerOptions(
    focus_on_hover,
    select_on_press,
    toggle_with_control,
    activate_on_double_press,
)

struct VirtualPointerResult{K}
    consumed::Bool
    key::Union{Nothing,K}
    activated::Bool
end

function _select_key!(state::VirtualListState{K}, key::K, index::Int, toggle::Bool) where {K}
    if toggle && key in state.selected
        delete!(state.selected, key)
    else
        state.multiple || empty!(state.selected)
        push!(state.selected, key)
    end
    state.cursor = index
    state.anchor = index
    return state
end

function handle_virtual_pointer!(
    state::VirtualListState{K},
    window::VirtualListWindow{T,K},
    event::VirtualPointerEvent;
    options::VirtualPointerOptions=VirtualPointerOptions(),
) where {T,K}
    event.kind == VirtualPointerLeave && return VirtualPointerResult{K}(false, nothing, false)
    slot = virtual_list_slot_at(window, event.row)
    if slot === nothing || slot.kind != ReadySlot
        return VirtualPointerResult{K}(false, nothing, false)
    end
    key = slot.key::K
    if event.kind == VirtualPointerHover
        options.focus_on_hover && (state.cursor = slot.index)
    elseif event.kind == VirtualPointerPress
        options.select_on_press && _select_key!(state, key, slot.index, options.toggle_with_control && event.control)
    elseif event.kind == VirtualPointerDoublePress
        state.cursor = slot.index
        return VirtualPointerResult{K}(true, key, options.activate_on_double_press)
    end
    return VirtualPointerResult{K}(true, key, false)
end

function _table_row_at(window::VirtualTableWindow, viewport_row::Int, header_rows::Int)
    viewport_row > header_rows || return nothing
    index = window.first_visible + viewport_row - header_rows - 1
    for row in window.rows
        row.index == index && return row
    end
    return nothing
end

function handle_virtual_pointer!(
    state::VirtualListState{K},
    window::VirtualTableWindow{K},
    event::VirtualPointerEvent;
    options::VirtualPointerOptions=VirtualPointerOptions(),
    header_rows::Integer=1,
) where {K}
    event.kind == VirtualPointerLeave && return VirtualPointerResult{K}(false, nothing, false)
    row = _table_row_at(window, event.row, Int(header_rows))
    if row === nothing || row.kind != ReadySlot || row.key === nothing
        return VirtualPointerResult{K}(false, nothing, false)
    end
    key = row.key::K
    if event.kind == VirtualPointerHover
        options.focus_on_hover && (state.cursor = row.index)
    elseif event.kind == VirtualPointerPress
        options.select_on_press && _select_key!(state, key, row.index, options.toggle_with_control && event.control)
    elseif event.kind == VirtualPointerDoublePress
        state.cursor = row.index
        return VirtualPointerResult{K}(true, key, options.activate_on_double_press)
    end
    return VirtualPointerResult{K}(true, key, false)
end

function handle_virtual_pointer!(
    state::VirtualTreeState{K},
    window::VirtualTreeWindow{T,K},
    event::VirtualPointerEvent;
    options::VirtualPointerOptions=VirtualPointerOptions(),
    first_row::Integer=1,
) where {T,K}
    event.kind == VirtualPointerLeave && return VirtualPointerResult{K}(false, nothing, false)
    row = virtual_tree_row_at(window, event.row; first_row=first_row)
    row === nothing && return VirtualPointerResult{K}(false, nothing, false)
    key = row.key
    if event.kind == VirtualPointerHover
        options.focus_on_hover && (state.cursor = key)
    elseif event.kind == VirtualPointerPress
        state.cursor = key
        if options.select_on_press
            if options.toggle_with_control && event.control && key in state.selected
                delete!(state.selected, key)
            else
                state.multiple || empty!(state.selected)
                push!(state.selected, key)
            end
        end
    elseif event.kind == VirtualPointerDoublePress
        state.cursor = key
        row.expandable && toggle_virtual_tree!(state, key)
        return VirtualPointerResult{K}(true, key, options.activate_on_double_press)
    end
    return VirtualPointerResult{K}(true, key, false)
end

end
