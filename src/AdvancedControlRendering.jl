module AdvancedControlRendering

using ..RichAdapters: KeyChord
using ..RichContent: RichSpan, RichLine
using ..AdvancedControls: SliderState,
                          RangeSliderState,
                          ScrollbarState,
                          HorizontalControl,
                          BreadcrumbState,
                          CollapsibleState,
                          AccordionState,
                          PaginationState,
                          StepperState,
                          DialogState,
                          ModalStack,
                          increment_slider!,
                          decrement_slider!,
                          move_range_slider!,
                          switch_range_handle!,
                          scroll_scrollbar!,
                          move_breadcrumb_focus!,
                          activate_breadcrumb!,
                          toggle_collapsible!,
                          toggle_accordion!,
                          next_page!,
                          previous_page!,
                          next_step!,
                          previous_step!,
                          complete_step!,
                          move_dialog_focus!,
                          activate_dialog_button!,
                          dismiss_modal!,
                          render_slider,
                          render_range_slider,
                          render_scrollbar,
                          render_breadcrumbs,
                          render_pagination,
                          page_count,
                          render_stepper,
                          slider_fraction,
                          set_slider!,
                          set_range_slider!,
                          set_scrollbar_offset!,
                          set_page!,
                          expand_collapsible!,
                          collapse_collapsible!
import ..DataEntryRendering: control_value,
                             set_control_value!,
                             control_valid,
                             control_error
using ..Accessibility: SemanticRect,
                       SemanticState,
                       SemanticNode,
                       SemanticTree,
                       GroupRole,
                       SliderRole,
                       ScrollbarRole,
                       LinkRole,
                       ButtonRole,
                       ListRole,
                       ListItemRole,
                       DialogRole,
                       IncrementSemanticAction,
                       DecrementSemanticAction,
                       SetValueSemanticAction,
                       ActivateSemanticAction,
                       ExpandSemanticAction,
                       CollapseSemanticAction,
                       DismissSemanticAction

export AdvancedControlAction,
       ControlPrevious,
       ControlNext,
       ControlPagePrevious,
       ControlPageNext,
       ControlActivate,
       ControlToggle,
       ControlSwitch,
       ControlCancel,
       AdvancedControlBindings,
       bind_advanced_control_key!,
       unbind_advanced_control_key!,
       default_advanced_control_bindings,
       advanced_control_action_for_key,
       AdvancedControlActionResult,
       handle_advanced_control_key!,
       render_slider_control,
       render_range_slider_control,
       render_scrollbar_control,
       render_breadcrumb_control,
       render_collapsible_control,
       render_accordion_control,
       render_pagination_control,
       render_stepper_control,
       render_dialog_control,
       slider_semantic_node,
       range_slider_semantic_node,
       scrollbar_semantic_node,
       breadcrumb_semantic_tree,
       collapsible_semantic_node,
       accordion_semantic_tree,
       pagination_semantic_node,
       stepper_semantic_tree,
       dialog_semantic_tree

@enum AdvancedControlAction begin
    ControlPrevious
    ControlNext
    ControlPagePrevious
    ControlPageNext
    ControlActivate
    ControlToggle
    ControlSwitch
    ControlCancel
end

mutable struct AdvancedControlBindings
    actions::Dict{KeyChord,AdvancedControlAction}
end

AdvancedControlBindings() = AdvancedControlBindings(Dict{KeyChord,AdvancedControlAction}())

function bind_advanced_control_key!(
    bindings::AdvancedControlBindings,
    chord::KeyChord,
    action::AdvancedControlAction,
)
    bindings.actions[chord] = action
    return bindings
end

function bind_advanced_control_key!(
    bindings::AdvancedControlBindings,
    key,
    action::AdvancedControlAction;
    modifiers...,
)
    return bind_advanced_control_key!(bindings, KeyChord(key; modifiers...), action)
end

function unbind_advanced_control_key!(bindings::AdvancedControlBindings, chord::KeyChord)
    pop!(bindings.actions, chord, nothing)
    return bindings
end

function default_advanced_control_bindings()
    bindings = AdvancedControlBindings()
    bind_advanced_control_key!(bindings, :left, ControlPrevious)
    bind_advanced_control_key!(bindings, :up, ControlPrevious)
    bind_advanced_control_key!(bindings, :right, ControlNext)
    bind_advanced_control_key!(bindings, :down, ControlNext)
    bind_advanced_control_key!(bindings, :pageup, ControlPagePrevious)
    bind_advanced_control_key!(bindings, :pagedown, ControlPageNext)
    bind_advanced_control_key!(bindings, :enter, ControlActivate)
    bind_advanced_control_key!(bindings, :space, ControlToggle)
    bind_advanced_control_key!(bindings, :tab, ControlSwitch)
    bind_advanced_control_key!(bindings, :escape, ControlCancel)
    return bindings
end

function advanced_control_action_for_key(
    bindings::AdvancedControlBindings,
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

struct AdvancedControlActionResult
    consumed::Bool
    action::Union{Nothing,AdvancedControlAction}
    value::Any
end

_unhandled_control() = AdvancedControlActionResult(false, nothing, nothing)

_control_page_steps(state::SliderState) =
    max(1, round(Int, (state.maximum - state.minimum) / (10 * state.step)))
_control_page_steps(state::RangeSliderState) =
    max(1, round(Int, (state.maximum - state.minimum) / (10 * state.step)))

function _control_action(bindings, key, control, alt, shift)
    return advanced_control_action_for_key(bindings, key; control=control, alt=alt, shift=shift)
end

function handle_advanced_control_key!(
    state::SliderState,
    bindings::AdvancedControlBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    state.disabled && return _unhandled_control()
    if key == :home
        set_slider!(state, state.minimum)
        return AdvancedControlActionResult(true, nothing, state.value)
    elseif key == :end
        set_slider!(state, state.maximum)
        return AdvancedControlActionResult(true, nothing, state.value)
    end
    action = _control_action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_control()
    amount = shift ? 10 : 1
    if action == ControlPrevious
        decrement_slider!(state, amount)
    elseif action == ControlNext
        increment_slider!(state, amount)
    elseif action == ControlPagePrevious
        decrement_slider!(state, _control_page_steps(state) * amount)
    elseif action == ControlPageNext
        increment_slider!(state, _control_page_steps(state) * amount)
    else
        return AdvancedControlActionResult(false, action, state.value)
    end
    return AdvancedControlActionResult(true, action, state.value)
end

function handle_advanced_control_key!(
    state::RangeSliderState,
    bindings::AdvancedControlBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    state.disabled && return _unhandled_control()
    if key == :home
        if state.active == LowerRangeHandle
            state.lower = state.minimum
        else
            state.upper = state.allow_crossing ? state.minimum : state.lower
        end
        return AdvancedControlActionResult(true, nothing, (state.lower, state.upper))
    elseif key == :end
        if state.active == LowerRangeHandle
            state.lower = state.allow_crossing ? state.maximum : state.upper
        else
            state.upper = state.maximum
        end
        return AdvancedControlActionResult(true, nothing, (state.lower, state.upper))
    end
    action = _control_action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_control()
    amount = shift ? 10 : 1
    if action == ControlPrevious
        move_range_slider!(state, -amount)
    elseif action == ControlNext
        move_range_slider!(state, amount)
    elseif action == ControlPagePrevious
        move_range_slider!(state, -_control_page_steps(state) * amount)
    elseif action == ControlPageNext
        move_range_slider!(state, _control_page_steps(state) * amount)
    elseif action == ControlSwitch
        switch_range_handle!(state)
    else
        return AdvancedControlActionResult(false, action, (state.lower, state.upper))
    end
    return AdvancedControlActionResult(true, action, (state.lower, state.upper))
end

function handle_advanced_control_key!(
    state::ScrollbarState,
    bindings::AdvancedControlBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _control_action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_control()
    delta = action == ControlPrevious ? -1 : action == ControlNext ? 1 :
            action == ControlPagePrevious ? -state.viewport_length :
            action == ControlPageNext ? state.viewport_length : 0
    delta == 0 && return AdvancedControlActionResult(false, action, state.offset)
    scroll_scrollbar!(state, delta)
    return AdvancedControlActionResult(true, action, state.offset)
end

function handle_advanced_control_key!(
    state::BreadcrumbState,
    bindings::AdvancedControlBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _control_action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_control()
    if action == ControlPrevious
        move_breadcrumb_focus!(state, -1)
    elseif action == ControlNext
        move_breadcrumb_focus!(state, 1)
    elseif action == ControlActivate
        return AdvancedControlActionResult(true, action, activate_breadcrumb!(state))
    else
        return AdvancedControlActionResult(false, action, nothing)
    end
    return AdvancedControlActionResult(true, action, nothing)
end

function handle_advanced_control_key!(
    state::CollapsibleState,
    bindings::AdvancedControlBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _control_action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_control()
    action in (ControlActivate, ControlToggle) ||
        return AdvancedControlActionResult(false, action, state.expanded)
    toggle_collapsible!(state)
    return AdvancedControlActionResult(true, action, state.expanded)
end

function handle_advanced_control_key!(
    state::PaginationState,
    bindings::AdvancedControlBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _control_action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_control()
    if action in (ControlPrevious, ControlPagePrevious)
        previous_page!(state)
    elseif action in (ControlNext, ControlPageNext)
        next_page!(state)
    else
        return AdvancedControlActionResult(false, action, state.page)
    end
    return AdvancedControlActionResult(true, action, state.page)
end

function handle_advanced_control_key!(
    state::StepperState,
    bindings::AdvancedControlBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _control_action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_control()
    if action == ControlPrevious
        previous_step!(state)
    elseif action == ControlNext
        next_step!(state)
    elseif action == ControlActivate
        complete_step!(state)
    else
        return AdvancedControlActionResult(false, action, state.current)
    end
    return AdvancedControlActionResult(true, action, state.current)
end

function handle_advanced_control_key!(
    state::DialogState,
    bindings::AdvancedControlBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _control_action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_control()
    if action == ControlPrevious
        move_dialog_focus!(state, -1)
    elseif action in (ControlNext, ControlSwitch)
        move_dialog_focus!(state, 1)
    elseif action == ControlActivate
        return AdvancedControlActionResult(true, action, activate_dialog_button!(state))
    elseif action == ControlCancel
        state.open = false
    else
        return AdvancedControlActionResult(false, action, nothing)
    end
    return AdvancedControlActionResult(true, action, nothing)
end

function handle_advanced_control_key!(
    state::ModalStack,
    bindings::AdvancedControlBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _control_action(bindings, key, control, alt, shift)
    action == ControlCancel || return AdvancedControlActionResult(false, action, nothing)
    return AdvancedControlActionResult(true, action, dismiss_modal!(state))
end

_control_line(text, role) = RichLine(RichSpan[RichSpan(String(text), role, nothing)], role, nothing)

render_slider_control(state::SliderState; length::Integer=20) =
    _control_line(render_slider(state, length), state.disabled ? :slider_disabled : :slider)

render_range_slider_control(state::RangeSliderState; length::Integer=20) =
    _control_line(render_range_slider(state, length), state.disabled ? :range_slider_disabled : :range_slider)

function render_scrollbar_control(state::ScrollbarState; length::Integer=20)
    value = render_scrollbar(state, length)
    return state.orientation == HorizontalControl ? RichLine[_control_line(value, :scrollbar)] :
        RichLine[_control_line(string(character), :scrollbar) for character in value]
end

render_breadcrumb_control(state::BreadcrumbState; separator::AbstractString=" / ") =
    _control_line(render_breadcrumbs(state; separator=separator), :breadcrumbs)

function render_collapsible_control(
    state::CollapsibleState,
    title::AbstractString;
    collapsed_marker::AbstractString="+",
    expanded_marker::AbstractString="-",
)
    marker = state.expanded ? expanded_marker : collapsed_marker
    return _control_line("[$marker] $title", state.disabled ? :collapsible_disabled : :collapsible)
end

function render_accordion_control(state::AccordionState, items; marker_open="-", marker_closed="+")
    return RichLine[
        _control_line("[$(key in state.expanded ? marker_open : marker_closed)] $(label)", key in state.expanded ? :accordion_expanded : :accordion_collapsed)
        for (key, label) in items
    ]
end

render_pagination_control(state::PaginationState) =
    _control_line(render_pagination(state), :pagination)

render_stepper_control(state::StepperState; separator::AbstractString=" -> ") =
    _control_line(render_stepper(state; separator=separator), :stepper)

function render_dialog_control(
    state::DialogState;
    title::AbstractString="",
    message::AbstractString="",
)
    state.open || return RichLine[]
    lines = RichLine[]
    isempty(title) || push!(lines, _control_line(title, :dialog_title))
    isempty(message) || push!(lines, _control_line(message, :dialog_message))
    buttons = join((
        index == state.focused ? "[$(button.label)]" : " $(button.label) "
        for (index, button) in enumerate(state.buttons)
    ), " ")
    push!(lines, _control_line(buttons, :dialog_buttons))
    return lines
end

control_value(state::SliderState) = state.value
control_value(state::RangeSliderState) = (state.lower, state.upper)
control_value(state::ScrollbarState) = state.offset
control_value(state::BreadcrumbState) = state.active === nothing ? nothing : state.items[state.active].value
control_value(state::CollapsibleState) = state.expanded
control_value(state::AccordionState) = copy(state.expanded)
control_value(state::PaginationState) = state.page
control_value(state::StepperState) = (state.current, copy(state.statuses))
control_value(state::DialogState) = state.result

set_control_value!(state::SliderState, value::Real) = set_slider!(state, value)
set_control_value!(state::RangeSliderState, value::Tuple{<:Real,<:Real}) = set_range_slider!(state, value...)
set_control_value!(state::ScrollbarState, value::Integer) = set_scrollbar_offset!(state, value)
set_control_value!(state::CollapsibleState, value::Bool) = value ? expand_collapsible!(state) : collapse_collapsible!(state)
set_control_value!(state::PaginationState, value::Integer) = set_page!(state, value)

control_valid(::Union{SliderState,RangeSliderState,ScrollbarState,BreadcrumbState,CollapsibleState,AccordionState,PaginationState,StepperState,DialogState}) = true
control_error(::Union{SliderState,RangeSliderState,ScrollbarState,BreadcrumbState,CollapsibleState,AccordionState,PaginationState,StepperState,DialogState}) = nothing

function slider_semantic_node(state::SliderState, id; label::AbstractString="", bounds=nothing)
    return SemanticNode(
        id,
        SliderRole;
        label=label,
        bounds=bounds,
        state=SemanticState(
            enabled=!state.disabled,
            focusable=!state.disabled,
            value_now=state.value,
            value_min=state.minimum,
            value_max=state.maximum,
        ),
        actions=state.disabled ? [] : [SetValueSemanticAction, IncrementSemanticAction, DecrementSemanticAction],
    )
end

function range_slider_semantic_node(state::RangeSliderState, id; label::AbstractString="", bounds=nothing)
    actions = state.disabled ? [] : [SetValueSemanticAction, IncrementSemanticAction, DecrementSemanticAction]
    children = SemanticNode[
        SemanticNode("$(id)/lower", SliderRole; label="Lower", state=SemanticState(enabled=!state.disabled, focusable=!state.disabled, value_now=state.lower, value_min=state.minimum, value_max=state.maximum), actions=actions),
        SemanticNode("$(id)/upper", SliderRole; label="Upper", state=SemanticState(enabled=!state.disabled, focusable=!state.disabled, value_now=state.upper, value_min=state.minimum, value_max=state.maximum), actions=actions),
    ]
    return SemanticNode(id, GroupRole; label=label, bounds=bounds, state=SemanticState(enabled=!state.disabled), children=children)
end

function scrollbar_semantic_node(state::ScrollbarState, id; label::AbstractString="", bounds=nothing)
    return SemanticNode(
        id,
        ScrollbarRole;
        label=label,
        bounds=bounds,
        state=SemanticState(
            focusable=true,
            value_now=state.offset,
            value_min=0,
            value_max=max(0, state.content_length - state.viewport_length),
        ),
        actions=[SetValueSemanticAction, IncrementSemanticAction, DecrementSemanticAction],
    )
end

function breadcrumb_semantic_tree(state::BreadcrumbState; id="breadcrumbs", label="Breadcrumbs")
    children = SemanticNode[
        SemanticNode(
            "$(id)/$index",
            LinkRole;
            label=item.label,
            state=SemanticState(enabled=!item.disabled, focusable=!item.disabled, focused=state.focused == index),
            actions=item.disabled ? [] : [ActivateSemanticAction],
        ) for (index, item) in enumerate(state.items)
    ]
    return SemanticTree(SemanticNode(id, GroupRole; label=label, children=children))
end

function collapsible_semantic_node(state::CollapsibleState, id; label::AbstractString="", bounds=nothing)
    return SemanticNode(
        id,
        ButtonRole;
        label=label,
        bounds=bounds,
        state=SemanticState(enabled=!state.disabled, focusable=!state.disabled, expanded=state.expanded),
        actions=state.disabled ? [] : [ActivateSemanticAction, state.expanded ? CollapseSemanticAction : ExpandSemanticAction],
    )
end

function accordion_semantic_tree(
    state::AccordionState,
    items;
    id="accordion",
    label::AbstractString="Accordion",
)
    children = SemanticNode[]
    for (index, (key, item_label)) in enumerate(items)
        expanded = key in state.expanded
        push!(children, SemanticNode(
            "$(id)/$index",
            ButtonRole;
            label=string(item_label),
            state=SemanticState(focusable=true, expanded=expanded),
            actions=[ActivateSemanticAction, expanded ? CollapseSemanticAction : ExpandSemanticAction],
            metadata=Dict(:key => key),
        ))
    end
    return SemanticTree(SemanticNode(id, GroupRole; label=label, children=children))
end

function pagination_semantic_node(state::PaginationState, id; label::AbstractString="Pagination", bounds=nothing)
    return SemanticNode(
        id,
        GroupRole;
        label=label,
        bounds=bounds,
        state=SemanticState(value="$(state.page)/$(page_count(state))", value_now=state.page, value_min=1, value_max=page_count(state)),
        actions=[IncrementSemanticAction, DecrementSemanticAction, SetValueSemanticAction],
    )
end

function stepper_semantic_tree(state::StepperState; id="stepper", label="Progress")
    children = SemanticNode[
        SemanticNode("$(id)/$index", ListItemRole; label=step.label, state=SemanticState(selected=state.current == index, value=string(state.statuses[index])))
        for (index, step) in enumerate(state.steps)
    ]
    return SemanticTree(SemanticNode(id, ListRole; label=label, children=children))
end

function dialog_semantic_tree(state::DialogState; id="dialog", label="Dialog")
    children = SemanticNode[
        SemanticNode(
            "$(id)/$index",
            ButtonRole;
            label=button.label,
            state=SemanticState(enabled=!button.disabled, focusable=!button.disabled, focused=state.focused == index),
            actions=button.disabled ? [] : [ActivateSemanticAction],
        ) for (index, button) in enumerate(state.buttons)
    ]
    return SemanticTree(SemanticNode(
        id,
        DialogRole;
        label=label,
        state=SemanticState(hidden=!state.open),
        actions=[DismissSemanticAction],
        children=children,
    ))
end

end
