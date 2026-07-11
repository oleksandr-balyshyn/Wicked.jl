module AdvancedControls

export ControlOrientation,
       HorizontalControl,
       VerticalControl,
       SliderState,
       set_slider!,
       increment_slider!,
       decrement_slider!,
       slider_fraction,
       render_slider,
       RangeSliderState,
       RangeSliderHandle,
       LowerRangeHandle,
       UpperRangeHandle,
       set_range_slider!,
       move_range_slider!,
       switch_range_handle!,
       render_range_slider,
       ScrollbarState,
       ScrollbarMetrics,
       set_scrollbar_offset!,
       scroll_scrollbar!,
       scrollbar_metrics,
       render_scrollbar,
       BreadcrumbItem,
       BreadcrumbState,
       move_breadcrumb_focus!,
       activate_breadcrumb!,
       render_breadcrumbs,
       CollapsibleState,
       toggle_collapsible!,
       expand_collapsible!,
       collapse_collapsible!,
       AccordionState,
       toggle_accordion!,
       expand_accordion!,
       collapse_accordion!,
       PaginationState,
       page_count,
       page_range,
       set_page!,
       next_page!,
       previous_page!,
       set_page_size!,
       render_pagination,
       StepStatus,
       PendingStep,
       ActiveStep,
       CompletedStep,
       FailedStep,
       SkippedStep,
       StepItem,
       StepperState,
       next_step!,
       previous_step!,
       complete_step!,
       fail_step!,
       skip_step!,
       render_stepper,
       DialogButtonRole,
       DefaultDialogButton,
       CancelDialogButton,
       DestructiveDialogButton,
       AuxiliaryDialogButton,
       DialogButton,
       DialogState,
       open_dialog!,
       close_dialog!,
       move_dialog_focus!,
       activate_dialog_button!,
       ModalEntry,
       ModalStack,
       push_modal!,
       pop_modal!,
       dismiss_modal!,
       top_modal,
       has_modal

@enum ControlOrientation begin
    HorizontalControl
    VerticalControl
end

mutable struct SliderState
    minimum::Float64
    maximum::Float64
    value::Float64
    step::Float64
    orientation::ControlOrientation
    disabled::Bool

    function SliderState(
        minimum::Real=0,
        maximum::Real=100;
        value::Real=minimum,
        step::Real=1,
        orientation::ControlOrientation=HorizontalControl,
        disabled::Bool=false,
    )
        isfinite(minimum) && isfinite(maximum) || throw(ArgumentError("slider bounds must be finite"))
        minimum < maximum || throw(ArgumentError("slider minimum must be below maximum"))
        isfinite(step) && step > 0 || throw(ArgumentError("slider step must be finite and positive"))
        result = new(Float64(minimum), Float64(maximum), Float64(value), Float64(step), orientation, false)
        set_slider!(result, value)
        result.disabled = disabled
        return result
    end
end

function _snap(minimum::Float64, maximum::Float64, step::Float64, value::Real)
    isfinite(value) || throw(ArgumentError("control value must be finite"))
    clamped = clamp(Float64(value), minimum, maximum)
    steps = round((clamped - minimum) / step)
    return clamp(muladd(steps, step, minimum), minimum, maximum)
end

function set_slider!(state::SliderState, value::Real)
    state.disabled && return state
    state.value = _snap(state.minimum, state.maximum, state.step, value)
    return state
end

increment_slider!(state::SliderState, steps::Integer=1) =
    set_slider!(state, state.value + Float64(steps) * state.step)

decrement_slider!(state::SliderState, steps::Integer=1) =
    increment_slider!(state, -steps)

slider_fraction(state::SliderState) =
    (state.value - state.minimum) / (state.maximum - state.minimum)

function render_slider(state::SliderState, length::Integer; filled::Char='=', empty::Char='-', thumb::Char='#')
    length > 0 || return ""
    size = Int(length)
    position = clamp(round(Int, slider_fraction(state) * (size - 1)), 0, size - 1)
    output = fill(empty, size)
    for index in 1:position
        output[index] = filled
    end
    output[position + 1] = thumb
    return String(output)
end

@enum RangeSliderHandle begin
    LowerRangeHandle
    UpperRangeHandle
end

mutable struct RangeSliderState
    minimum::Float64
    maximum::Float64
    lower::Float64
    upper::Float64
    step::Float64
    active::RangeSliderHandle
    allow_crossing::Bool
    disabled::Bool

    function RangeSliderState(
        minimum::Real=0,
        maximum::Real=100;
        lower::Real=minimum,
        upper::Real=maximum,
        step::Real=1,
        active::RangeSliderHandle=LowerRangeHandle,
        allow_crossing::Bool=false,
        disabled::Bool=false,
    )
        isfinite(minimum) && isfinite(maximum) || throw(ArgumentError("range slider bounds must be finite"))
        minimum < maximum || throw(ArgumentError("range slider minimum must be below maximum"))
        isfinite(step) && step > 0 || throw(ArgumentError("range slider step must be finite and positive"))
        state = new(
            Float64(minimum),
            Float64(maximum),
            Float64(lower),
            Float64(upper),
            Float64(step),
            active,
            allow_crossing,
            false,
        )
        set_range_slider!(state, lower, upper)
        state.disabled = disabled
        return state
    end
end

function set_range_slider!(state::RangeSliderState, lower::Real, upper::Real)
    state.disabled && return state
    next_lower = _snap(state.minimum, state.maximum, state.step, lower)
    next_upper = _snap(state.minimum, state.maximum, state.step, upper)
    if !state.allow_crossing && next_lower > next_upper
        throw(ArgumentError("range slider lower value exceeds upper value"))
    end
    state.lower = next_lower
    state.upper = next_upper
    return state
end

function move_range_slider!(state::RangeSliderState, steps::Integer)
    state.disabled && return state
    delta = Float64(steps) * state.step
    if state.active == LowerRangeHandle
        value = _snap(state.minimum, state.maximum, state.step, state.lower + delta)
        state.lower = state.allow_crossing ? value : min(value, state.upper)
    else
        value = _snap(state.minimum, state.maximum, state.step, state.upper + delta)
        state.upper = state.allow_crossing ? value : max(value, state.lower)
    end
    return state
end

switch_range_handle!(state::RangeSliderState) =
    (state.active = state.active == LowerRangeHandle ? UpperRangeHandle : LowerRangeHandle; state)

function render_range_slider(state::RangeSliderState, length::Integer; range::Char='=', empty::Char='-', lower::Char='[', upper::Char=']')
    length > 0 || return ""
    size = Int(length)
    denominator = state.maximum - state.minimum
    lower_position = clamp(round(Int, (state.lower - state.minimum) / denominator * (size - 1)), 0, size - 1)
    upper_position = clamp(round(Int, (state.upper - state.minimum) / denominator * (size - 1)), 0, size - 1)
    output = fill(empty, size)
    first_position, stop_position = minmax(lower_position, upper_position)
    for index in (first_position + 1):(stop_position + 1)
        output[index] = range
    end
    output[lower_position + 1] = lower
    output[upper_position + 1] = upper
    return String(output)
end

mutable struct ScrollbarState
    content_length::Int
    viewport_length::Int
    offset::Int
    minimum_thumb::Int
    orientation::ControlOrientation

    function ScrollbarState(
        content_length::Integer,
        viewport_length::Integer;
        offset::Integer=0,
        minimum_thumb::Integer=1,
        orientation::ControlOrientation=VerticalControl,
    )
        content_length >= 0 || throw(ArgumentError("scrollbar content length cannot be negative"))
        viewport_length >= 0 || throw(ArgumentError("scrollbar viewport length cannot be negative"))
        minimum_thumb > 0 || throw(ArgumentError("minimum scrollbar thumb must be positive"))
        state = new(Int(content_length), Int(viewport_length), 0, Int(minimum_thumb), orientation)
        set_scrollbar_offset!(state, offset)
        return state
    end
end

_maximum_offset(state::ScrollbarState) = max(0, state.content_length - state.viewport_length)

function set_scrollbar_offset!(state::ScrollbarState, offset::Integer)
    state.offset = Int(clamp(big(offset), big(0), big(_maximum_offset(state))))
    return state
end

scroll_scrollbar!(state::ScrollbarState, delta::Integer) =
    set_scrollbar_offset!(state, big(state.offset) + big(delta))

struct ScrollbarMetrics
    thumb_start::Int
    thumb_length::Int
    track_length::Int
end

function scrollbar_metrics(state::ScrollbarState, track_length::Integer)
    track_length >= 0 || throw(ArgumentError("scrollbar track length cannot be negative"))
    track = Int(track_length)
    track == 0 && return ScrollbarMetrics(0, 0, 0)
    if state.content_length <= state.viewport_length || state.content_length == 0
        return ScrollbarMetrics(0, track, track)
    end
    thumb = clamp(
        round(Int, BigFloat(track) * state.viewport_length / state.content_length),
        min(state.minimum_thumb, track),
        track,
    )
    travel = track - thumb
    position = round(Int, BigFloat(travel) * state.offset / _maximum_offset(state))
    return ScrollbarMetrics(position, thumb, track)
end

function render_scrollbar(state::ScrollbarState, track_length::Integer; track::Char='.', thumb::Char='#')
    metrics = scrollbar_metrics(state, track_length)
    output = fill(track, metrics.track_length)
    for index in (metrics.thumb_start + 1):(metrics.thumb_start + metrics.thumb_length)
        output[index] = thumb
    end
    return String(output)
end

struct BreadcrumbItem{T}
    label::String
    value::T
    disabled::Bool
end

BreadcrumbItem(label::AbstractString, value; disabled::Bool=false) =
    BreadcrumbItem{typeof(value)}(String(label), value, disabled)

mutable struct BreadcrumbState{T}
    items::Vector{BreadcrumbItem{T}}
    focused::Union{Nothing,Int}
    active::Union{Nothing,Int}

    function BreadcrumbState(items::AbstractVector{BreadcrumbItem{T}}) where {T}
        values = Vector{BreadcrumbItem{T}}(items)
        focused = findfirst(item -> !item.disabled, values)
        new{T}(values, focused, isempty(values) ? nothing : length(values))
    end
end

function move_breadcrumb_focus!(state::BreadcrumbState, delta::Integer; wrap::Bool=true)
    enabled = Int[index for (index, item) in enumerate(state.items) if !item.disabled]
    isempty(enabled) && (state.focused = nothing; return state)
    position = state.focused === nothing ? nothing : findfirst(==(state.focused), enabled)
    if position === nothing
        state.focused = delta < 0 ? last(enabled) : first(enabled)
    else
        target = position + Int(delta)
        state.focused = wrap ? enabled[mod1(target, length(enabled))] : enabled[clamp(target, 1, length(enabled))]
    end
    return state
end

function activate_breadcrumb!(state::BreadcrumbState)
    state.focused === nothing && return nothing
    item = state.items[state.focused]
    item.disabled && return nothing
    state.active = state.focused
    return item.value
end

function render_breadcrumbs(state::BreadcrumbState; separator::AbstractString=" / ")
    parts = String[]
    for (index, item) in enumerate(state.items)
        label = index == state.focused ? "[$(item.label)]" : item.label
        item.disabled && (label = "($label)")
        push!(parts, label)
    end
    return join(parts, separator)
end

mutable struct CollapsibleState
    expanded::Bool
    disabled::Bool
end

CollapsibleState(; expanded::Bool=false, disabled::Bool=false) =
    CollapsibleState(expanded, disabled)

toggle_collapsible!(state::CollapsibleState) =
    (state.disabled || (state.expanded = !state.expanded); state)
expand_collapsible!(state::CollapsibleState) =
    (state.disabled || (state.expanded = true); state)
collapse_collapsible!(state::CollapsibleState) =
    (state.disabled || (state.expanded = false); state)

mutable struct AccordionState{K}
    expanded::Set{K}
    multiple::Bool
end

AccordionState{K}(; expanded=K[], multiple::Bool=false) where {K} =
    AccordionState{K}(Set{K}(expanded), multiple)

function expand_accordion!(state::AccordionState{K}, key::K) where {K}
    state.multiple || empty!(state.expanded)
    push!(state.expanded, key)
    return state
end

collapse_accordion!(state::AccordionState{K}, key::K) where {K} =
    (delete!(state.expanded, key); state)

function toggle_accordion!(state::AccordionState{K}, key::K) where {K}
    key in state.expanded ? collapse_accordion!(state, key) : expand_accordion!(state, key)
end

mutable struct PaginationState
    total_items::Int
    page_size::Int
    page::Int

    function PaginationState(total_items::Integer; page_size::Integer=20, page::Integer=1)
        total_items >= 0 || throw(ArgumentError("pagination total cannot be negative"))
        page_size > 0 || throw(ArgumentError("pagination page size must be positive"))
        state = new(Int(total_items), Int(page_size), 1)
        set_page!(state, page)
        return state
    end
end

page_count(state::PaginationState) = max(1, cld(state.total_items, state.page_size))

function page_range(state::PaginationState)
    state.total_items == 0 && return 1:0
    first_item = (state.page - 1) * state.page_size + 1
    return first_item:min(state.total_items, first_item + state.page_size - 1)
end

set_page!(state::PaginationState, page::Integer) =
    (state.page = Int(clamp(big(page), big(1), big(page_count(state)))); state)
next_page!(state::PaginationState) = set_page!(state, state.page + 1)
previous_page!(state::PaginationState) = set_page!(state, state.page - 1)

function set_page_size!(state::PaginationState, page_size::Integer; preserve_item::Bool=true)
    page_size > 0 || throw(ArgumentError("pagination page size must be positive"))
    first_item = isempty(page_range(state)) ? 1 : first(page_range(state))
    state.page_size = Int(page_size)
    state.page = preserve_item ? div(first_item - 1, state.page_size) + 1 : 1
    return set_page!(state, state.page)
end

render_pagination(state::PaginationState) =
    "page $(state.page)/$(page_count(state)) items $(isempty(page_range(state)) ? 0 : first(page_range(state)))-$(isempty(page_range(state)) ? 0 : last(page_range(state)))/$(state.total_items)"

@enum StepStatus begin
    PendingStep
    ActiveStep
    CompletedStep
    FailedStep
    SkippedStep
end

struct StepItem{T}
    label::String
    value::T
end

StepItem(label::AbstractString, value) = StepItem{typeof(value)}(String(label), value)
StepItem(pair::Pair{T, S}) where {T,S} = StepItem(string(first(pair)), last(pair))

mutable struct StepperState{T}
    steps::Vector{StepItem{T}}
    statuses::Vector{StepStatus}
    current::Union{Nothing,Int}

    function StepperState(steps::AbstractVector{StepItem{T}}) where {T}
        values = Vector{StepItem{T}}(steps)
        statuses = fill(PendingStep, length(values))
        current = isempty(values) ? nothing : 1
        current === nothing || (statuses[current] = ActiveStep)
        new{T}(values, statuses, current)
    end
end

StepperState(steps::AbstractVector{<:AbstractString}) =
    StepperState([StepItem(label, i) for (i, label) in enumerate(steps)])

StepperState(steps::AbstractVector{<:Pair}) =
    StepperState([StepItem(step) for step in steps])

function _activate_step!(state::StepperState, index::Int)
    isempty(state.steps) && (state.current = nothing; return state)
    state.current !== nothing && state.statuses[state.current] == ActiveStep &&
        (state.statuses[state.current] = PendingStep)
    state.current = clamp(index, 1, length(state.steps))
    state.statuses[state.current] = ActiveStep
    return state
end

function next_step!(state::StepperState)
    state.current === nothing && return state
    state.current >= length(state.steps) && return state
    state.statuses[state.current] = CompletedStep
    state.current += 1
    state.statuses[state.current] = ActiveStep
    return state
end

previous_step!(state::StepperState) =
    state.current === nothing ? state : _activate_step!(state, state.current - 1)

function complete_step!(state::StepperState)
    state.current === nothing && return state
    state.statuses[state.current] = CompletedStep
    state.current < length(state.steps) ? _activate_step!(state, state.current + 1) : (state.current = nothing; state)
end

function fail_step!(state::StepperState)
    state.current === nothing || (state.statuses[state.current] = FailedStep)
    return state
end

function skip_step!(state::StepperState)
    state.current === nothing && return state
    state.statuses[state.current] = SkippedStep
    state.current < length(state.steps) ? _activate_step!(state, state.current + 1) : (state.current = nothing; state)
end

function render_stepper(state::StepperState; separator::AbstractString=" -> ")
    markers = Dict(
        PendingStep => " ",
        ActiveStep => ">",
        CompletedStep => "x",
        FailedStep => "!",
        SkippedStep => "-",
    )
    return join(("[$(markers[state.statuses[index]])] $(step.label)" for (index, step) in enumerate(state.steps)), separator)
end

@enum DialogButtonRole begin
    DefaultDialogButton
    CancelDialogButton
    DestructiveDialogButton
    AuxiliaryDialogButton
end

struct DialogButton{T}
    label::String
    value::T
    role::DialogButtonRole
    disabled::Bool
end

DialogButton(
    label::AbstractString,
    value;
    role::DialogButtonRole=DefaultDialogButton,
    disabled::Bool=false,
) = DialogButton{typeof(value)}(String(label), value, role, disabled)

mutable struct DialogState{T}
    buttons::Vector{DialogButton{T}}
    open::Bool
    focused::Union{Nothing,Int}
    result::Union{Nothing,T}
end

function DialogState(buttons::AbstractVector{DialogButton{T}}; open::Bool=false) where {T}
    values = Vector{DialogButton{T}}(buttons)
    focused = findfirst(button -> !button.disabled, values)
    return DialogState{T}(values, open, focused, nothing)
end

open_dialog!(state::DialogState) = (state.open = true; state.result = nothing; state)
close_dialog!(state::DialogState) = (state.open = false; state)

function move_dialog_focus!(state::DialogState, delta::Integer; wrap::Bool=true)
    enabled = Int[index for (index, button) in enumerate(state.buttons) if !button.disabled]
    isempty(enabled) && (state.focused = nothing; return state)
    position = state.focused === nothing ? nothing : findfirst(==(state.focused), enabled)
    target = position === nothing ? (delta < 0 ? length(enabled) : 1) : position + Int(delta)
    state.focused = enabled[wrap ? mod1(target, length(enabled)) : clamp(target, 1, length(enabled))]
    return state
end

function activate_dialog_button!(state::DialogState)
    state.open || return nothing
    state.focused === nothing && return nothing
    button = state.buttons[state.focused]
    button.disabled && return nothing
    state.result = button.value
    state.open = false
    return button.value
end

struct ModalEntry{T}
    id::String
    content::T
    dismissible::Bool
end

ModalEntry(id, content; dismissible::Bool=true) =
    ModalEntry{typeof(content)}(string(id), content, dismissible)

mutable struct ModalStack
    entries::Vector{ModalEntry}
end

ModalStack() = ModalStack(ModalEntry[])
has_modal(stack::ModalStack) = !isempty(stack.entries)
top_modal(stack::ModalStack) = isempty(stack.entries) ? nothing : last(stack.entries)

function push_modal!(stack::ModalStack, entry::ModalEntry)
    any(existing -> existing.id == entry.id, stack.entries) &&
        throw(ArgumentError("duplicate modal id: $(entry.id)"))
    push!(stack.entries, entry)
    return stack
end

pop_modal!(stack::ModalStack) = isempty(stack.entries) ? nothing : pop!(stack.entries)

function dismiss_modal!(stack::ModalStack)
    entry = top_modal(stack)
    entry === nothing && return nothing
    entry.dismissible || return nothing
    return pop!(stack.entries)
end

end
