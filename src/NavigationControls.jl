module NavigationControls

using Unicode: graphemes
using ..RichContent: RichSpan, RichLine
using ..Accessibility: SemanticRect,
                       SemanticState,
                       SemanticNode,
                       SemanticTree,
                       GroupRole,
                       ListRole,
                       ListItemRole,
                       StatusRole,
                       ButtonRole,
                       ActivateSemanticAction,
                       IncrementSemanticAction,
                       DecrementSemanticAction,
                       DismissSemanticAction

export ComponentRect,
       SplitOrientation,
       HorizontalSplit,
       VerticalSplit,
       SplitPaneState,
       set_split_fraction!,
       resize_split!,
       split_pane_regions,
       ResizeHandleState,
       begin_resize!,
       update_resize!,
       finish_resize!,
       cancel_resize!,
       DrawerEdge,
       LeftDrawer,
       RightDrawer,
       TopDrawer,
       BottomDrawer,
       DrawerState,
       open_drawer!,
       close_drawer!,
       toggle_drawer!,
       drawer_rect,
       PopoverPlacement,
       AbovePopover,
       BelowPopover,
       LeftPopover,
       RightPopover,
       PopoverResult,
       place_popover,
       TooltipState,
       begin_tooltip_hover!,
       leave_tooltip!,
       tick_tooltip!,
       dismiss_tooltip!,
       CarouselState,
       next_carousel!,
       previous_carousel!,
       set_carousel_index!,
       carousel_item,
       carousel_window,
       TimelineStatus,
       TimelinePending,
       TimelineActive,
       TimelineComplete,
       TimelineFailed,
       TimelineItem,
       TimelineState,
       move_timeline_focus!,
       render_timeline,
       timeline_semantic_tree,
       SkeletonState,
       tick_skeleton!,
       render_skeleton,
       EmptyState,
       render_empty_state,
       navigation_control_semantic_node

struct ComponentRect
    row::Int
    column::Int
    width::Int
    height::Int

    function ComponentRect(row::Integer, column::Integer, width::Integer, height::Integer)
        row > 0 || throw(ArgumentError("component row must be positive"))
        column > 0 || throw(ArgumentError("component column must be positive"))
        width >= 0 || throw(ArgumentError("component width cannot be negative"))
        height >= 0 || throw(ArgumentError("component height cannot be negative"))
        new(Int(row), Int(column), Int(width), Int(height))
    end
end

@enum SplitOrientation begin
    HorizontalSplit
    VerticalSplit
end

mutable struct SplitPaneState
    fraction::Float64
    minimum_first::Int
    minimum_second::Int
    orientation::SplitOrientation
    disabled::Bool

    function SplitPaneState(;
        fraction::Real=0.5,
        minimum_first::Integer=0,
        minimum_second::Integer=0,
        orientation::SplitOrientation=HorizontalSplit,
        disabled::Bool=false,
    )
        isfinite(fraction) || throw(ArgumentError("split fraction must be finite"))
        minimum_first >= 0 || throw(ArgumentError("first pane minimum cannot be negative"))
        minimum_second >= 0 || throw(ArgumentError("second pane minimum cannot be negative"))
        new(clamp(Float64(fraction), 0, 1), Int(minimum_first), Int(minimum_second), orientation, disabled)
    end
end

function set_split_fraction!(state::SplitPaneState, fraction::Real)
    state.disabled && return state
    isfinite(fraction) || throw(ArgumentError("split fraction must be finite"))
    state.fraction = clamp(Float64(fraction), 0, 1)
    return state
end

function resize_split!(state::SplitPaneState, delta::Real, total::Integer)
    total > 0 || return state
    return set_split_fraction!(state, state.fraction + Float64(delta) / total)
end

function split_pane_regions(
    state::SplitPaneState,
    area::ComponentRect;
    handle_size::Integer=1,
)
    handle_size >= 0 || throw(ArgumentError("split handle size cannot be negative"))
    available = (state.orientation == HorizontalSplit ? area.width : area.height) - Int(handle_size)
    available = max(0, available)
    first_size = clamp(round(Int, available * state.fraction), state.minimum_first, max(state.minimum_first, available - state.minimum_second))
    first_size = clamp(first_size, 0, available)
    second_size = available - first_size
    if state.orientation == HorizontalSplit
        first = ComponentRect(area.row, area.column, first_size, area.height)
        handle = ComponentRect(area.row, area.column + first_size, Int(handle_size), area.height)
        second = ComponentRect(area.row, area.column + first_size + Int(handle_size), second_size, area.height)
    else
        first = ComponentRect(area.row, area.column, area.width, first_size)
        handle = ComponentRect(area.row + first_size, area.column, area.width, Int(handle_size))
        second = ComponentRect(area.row + first_size + Int(handle_size), area.column, area.width, second_size)
    end
    return first, handle, second
end

mutable struct ResizeHandleState
    active::Bool
    pointer_start::Int
    value_start::Float64
end

ResizeHandleState() = ResizeHandleState(false, 0, 0)

function begin_resize!(handle::ResizeHandleState, pointer::Integer, state::SplitPaneState)
    state.disabled && return false
    handle.active = true
    handle.pointer_start = Int(pointer)
    handle.value_start = state.fraction
    return true
end

function update_resize!(
    handle::ResizeHandleState,
    state::SplitPaneState,
    pointer::Integer,
    total::Integer,
)
    handle.active || return false
    total > 0 || return false
    delta = big(pointer) - handle.pointer_start
    set_split_fraction!(state, handle.value_start + Float64(delta / total))
    return true
end

finish_resize!(handle::ResizeHandleState) = (handle.active = false; handle)

function cancel_resize!(handle::ResizeHandleState, state::SplitPaneState)
    handle.active && (state.fraction = handle.value_start)
    handle.active = false
    return state
end

@enum DrawerEdge begin
    LeftDrawer
    RightDrawer
    TopDrawer
    BottomDrawer
end

mutable struct DrawerState
    open::Bool
    edge::DrawerEdge
    size::Int
    modal::Bool
    dismissible::Bool

    function DrawerState(;
        open::Bool=false,
        edge::DrawerEdge=LeftDrawer,
        size::Integer=30,
        modal::Bool=false,
        dismissible::Bool=true,
    )
        size >= 0 || throw(ArgumentError("drawer size cannot be negative"))
        new(open, edge, Int(size), modal, dismissible)
    end
end

open_drawer!(state::DrawerState) = (state.open = true; state)
close_drawer!(state::DrawerState) = (state.open = false; state)
toggle_drawer!(state::DrawerState) = (state.open = !state.open; state)

function drawer_rect(state::DrawerState, viewport::ComponentRect)
    state.open || return ComponentRect(viewport.row, viewport.column, 0, 0)
    if state.edge == LeftDrawer
        return ComponentRect(viewport.row, viewport.column, min(state.size, viewport.width), viewport.height)
    elseif state.edge == RightDrawer
        width = min(state.size, viewport.width)
        return ComponentRect(viewport.row, viewport.column + viewport.width - width, width, viewport.height)
    elseif state.edge == TopDrawer
        return ComponentRect(viewport.row, viewport.column, viewport.width, min(state.size, viewport.height))
    else
        height = min(state.size, viewport.height)
        return ComponentRect(viewport.row + viewport.height - height, viewport.column, viewport.width, height)
    end
end

@enum PopoverPlacement begin
    AbovePopover
    BelowPopover
    LeftPopover
    RightPopover
end

struct PopoverResult
    rect::ComponentRect
    placement::PopoverPlacement
    clipped::Bool
end

function _candidate_popover(
    anchor::ComponentRect,
    width::Int,
    height::Int,
    placement::PopoverPlacement,
    gap::Int,
)
    row = placement == AbovePopover ? anchor.row - height - gap :
          placement == BelowPopover ? anchor.row + anchor.height + gap :
          anchor.row + div(anchor.height - height, 2)
    column = placement == LeftPopover ? anchor.column - width - gap :
             placement == RightPopover ? anchor.column + anchor.width + gap :
             anchor.column + div(anchor.width - width, 2)
    return row, column
end

function _fits(row, column, width, height, viewport::ComponentRect, margin::Int)
    return row >= viewport.row + margin && column >= viewport.column + margin &&
           row + height <= viewport.row + viewport.height - margin &&
           column + width <= viewport.column + viewport.width - margin
end

function place_popover(
    anchor::ComponentRect,
    width::Integer,
    height::Integer,
    viewport::ComponentRect;
    preferred::PopoverPlacement=BelowPopover,
    gap::Integer=1,
    margin::Integer=0,
)
    width >= 0 || throw(ArgumentError("popover width cannot be negative"))
    height >= 0 || throw(ArgumentError("popover height cannot be negative"))
    gap >= 0 || throw(ArgumentError("popover gap cannot be negative"))
    margin >= 0 || throw(ArgumentError("popover margin cannot be negative"))
    (big(margin) * 2 <= viewport.width && big(margin) * 2 <= viewport.height) ||
        throw(ArgumentError("popover margin exceeds the viewport"))
    opposite = Dict(AbovePopover => BelowPopover, BelowPopover => AbovePopover, LeftPopover => RightPopover, RightPopover => LeftPopover)
    placements = PopoverPlacement[preferred, opposite[preferred]]
    append!(placements, (placement for placement in instances(PopoverPlacement) if !(placement in placements)))
    target_width = min(Int(width), max(0, viewport.width - 2Int(margin)))
    target_height = min(Int(height), max(0, viewport.height - 2Int(margin)))
    for placement in placements
        row, column = _candidate_popover(anchor, target_width, target_height, placement, Int(gap))
        _fits(row, column, target_width, target_height, viewport, Int(margin)) &&
            return PopoverResult(ComponentRect(row, column, target_width, target_height), placement, false)
    end
    row, column = _candidate_popover(anchor, target_width, target_height, preferred, Int(gap))
    maximum_row = max(viewport.row + Int(margin), viewport.row + viewport.height - Int(margin) - target_height)
    maximum_column = max(viewport.column + Int(margin), viewport.column + viewport.width - Int(margin) - target_width)
    row = clamp(row, viewport.row + Int(margin), maximum_row)
    column = clamp(column, viewport.column + Int(margin), maximum_column)
    return PopoverResult(ComponentRect(row, column, target_width, target_height), preferred, true)
end

mutable struct TooltipState
    target::Any
    content::Any
    hovering::Bool
    visible::Bool
    entered_ns::UInt64
    delay_ns::UInt64
    suppressed::Bool

    function TooltipState(; delay_ms::Integer=500)
        delay_ms >= 0 || throw(ArgumentError("tooltip delay cannot be negative"))
        delay = big(delay_ms) * 1_000_000
        delay <= typemax(UInt64) || throw(ArgumentError("tooltip delay is too large"))
        new(nothing, nothing, false, false, 0, UInt64(delay), false)
    end
end

function begin_tooltip_hover!(state::TooltipState, target, content; now_ns::Integer=time_ns())
    0 <= now_ns <= typemax(UInt64) || throw(ArgumentError("tooltip timestamp must fit UInt64"))
    state.target = target
    state.content = content
    state.hovering = true
    state.visible = state.delay_ns == 0
    state.suppressed = false
    state.entered_ns = UInt64(now_ns)
    return state
end

leave_tooltip!(state::TooltipState) =
    (state.hovering = false; state.visible = false; state.suppressed = false; state.target = nothing; state.content = nothing; state)

function tick_tooltip!(state::TooltipState; now_ns::Integer=time_ns())
    state.hovering || return false
    state.suppressed && return false
    timestamp = UInt64(now_ns)
    elapsed = timestamp < state.entered_ns ? UInt64(0) : timestamp - state.entered_ns
    changed = !state.visible && elapsed >= state.delay_ns
    changed && (state.visible = true)
    return changed
end

dismiss_tooltip!(state::TooltipState) = (state.visible = false; state.suppressed = true; state)

mutable struct CarouselState{T}
    items::Vector{T}
    index::Union{Nothing,Int}
    looping::Bool

    function CarouselState(items::AbstractVector{T}; index::Integer=1, looping::Bool=true) where {T}
        values = Vector{T}(items)
        current = isempty(values) ? nothing : clamp(Int(index), 1, length(values))
        new{T}(values, current, looping)
    end
end

function set_carousel_index!(state::CarouselState, index::Integer)
    isempty(state.items) && (state.index = nothing; return state)
    state.index = state.looping ? mod1(Int(mod(big(index) - 1, length(state.items))) + 1, length(state.items)) :
                  Int(clamp(big(index), big(1), big(length(state.items))))
    return state
end

next_carousel!(state::CarouselState) = set_carousel_index!(state, something(state.index, 0) + 1)
previous_carousel!(state::CarouselState) = set_carousel_index!(state, something(state.index, 2) - 1)
carousel_item(state::CarouselState) = state.index === nothing ? nothing : state.items[state.index]

function carousel_window(state::CarouselState, count::Integer)
    count >= 0 || throw(ArgumentError("carousel window count cannot be negative"))
    state.index === nothing && return eltype(state.items)[]
    result = eltype(state.items)[]
    for offset in 0:(Int(count) - 1)
        index = state.index + offset
        if state.looping
            index = mod1(index, length(state.items))
        elseif index > length(state.items)
            break
        end
        push!(result, state.items[index])
    end
    return result
end

@enum TimelineStatus begin
    TimelinePending
    TimelineActive
    TimelineComplete
    TimelineFailed
end

struct TimelineItem{T}
    title::String
    detail::Union{Nothing,String}
    value::T
    status::TimelineStatus
end

function TimelineItem(
    title::AbstractString,
    value;
    detail::Union{Nothing,AbstractString}=nothing,
    status::TimelineStatus=TimelinePending,
)
    return TimelineItem{typeof(value)}(
        String(title),
        detail === nothing ? nothing : String(detail),
        value,
        status,
    )
end

mutable struct TimelineState{T}
    items::Vector{TimelineItem{T}}
    focused::Union{Nothing,Int}
end

TimelineState(items::AbstractVector{TimelineItem{T}}) where {T} =
    TimelineState{T}(Vector{TimelineItem{T}}(items), isempty(items) ? nothing : 1)

function move_timeline_focus!(state::TimelineState, delta::Integer; wrap::Bool=false)
    isempty(state.items) && (state.focused = nothing; return state)
    current = something(state.focused, 1)
    target = big(current) + big(delta)
    state.focused = wrap ? mod1(Int(mod(target - 1, length(state.items))) + 1, length(state.items)) :
                    Int(clamp(target, big(1), big(length(state.items))))
    return state
end

function render_timeline(state::TimelineState; width::Integer=80)
    width > 0 || throw(ArgumentError("timeline width must be positive"))
    markers = Dict(
        TimelinePending => "o",
        TimelineActive => ">",
        TimelineComplete => "x",
        TimelineFailed => "!",
    )
    lines = RichLine[]
    for (index, item) in enumerate(state.items)
        focus = state.focused == index ? ">" : " "
        detail = item.detail === nothing ? "" : " - $(item.detail)"
        text = "$focus $(markers[item.status]) $(item.title)$detail"
        if textwidth(text) > width
            output = IOBuffer()
            used = 0
            for grapheme in graphemes(text)
                grapheme_width = max(1, textwidth(grapheme))
                used + grapheme_width > Int(width) - 1 && break
                print(output, grapheme)
                used += grapheme_width
            end
            print(output, '~')
            text = String(take!(output))
        end
        role = state.focused == index ? :timeline_focused : Symbol("timeline_", lowercase(string(item.status)))
        push!(lines, RichLine(RichSpan[RichSpan(text, role, nothing)], role, nothing))
    end
    return lines
end

function timeline_semantic_tree(state::TimelineState; id="timeline", label="Timeline")
    children = SemanticNode[
        SemanticNode(
            "$(id)/$index",
            ListItemRole;
            label=item.title,
            description=item.detail,
            state=SemanticState(focusable=true, focused=state.focused == index, value=string(item.status)),
            actions=[ActivateSemanticAction],
        ) for (index, item) in enumerate(state.items)
    ]
    return SemanticTree(SemanticNode(id, ListRole; label=label, children=children))
end

mutable struct SkeletonState
    phase::Int
    period::Int
end

function SkeletonState(; period::Integer=12)
    period > 0 || throw(ArgumentError("skeleton period must be positive"))
    return SkeletonState(0, Int(period))
end

function tick_skeleton!(state::SkeletonState, steps::Integer=1)
    state.phase = Int(mod(big(state.phase) + big(steps), state.period))
    return state
end

function render_skeleton(
    state::SkeletonState,
    width::Integer,
    height::Integer;
    base::Char='-',
    highlight::Char='=',
    highlight_width::Integer=4,
)
    width >= 0 || throw(ArgumentError("skeleton width cannot be negative"))
    height >= 0 || throw(ArgumentError("skeleton height cannot be negative"))
    highlight_width >= 0 || throw(ArgumentError("skeleton highlight width cannot be negative"))
    lines = RichLine[]
    for row in 1:Int(height)
        output = fill(base, Int(width))
        start = mod(state.phase + row - 2, max(1, Int(width) + state.period)) + 1
        for column in start:min(Int(width), start + Int(highlight_width) - 1)
            output[column] = highlight
        end
        push!(lines, RichLine(RichSpan[RichSpan(String(output), :skeleton, nothing)], :skeleton, nothing))
    end
    return lines
end

struct EmptyState
    title::String
    message::Union{Nothing,String}
    action_label::Union{Nothing,String}
end

EmptyState(
    title::AbstractString;
    message::Union{Nothing,AbstractString}=nothing,
    action_label::Union{Nothing,AbstractString}=nothing,
) = EmptyState(
    String(title),
    message === nothing ? nothing : String(message),
    action_label === nothing ? nothing : String(action_label),
)

function render_empty_state(state::EmptyState)
    lines = RichLine[RichLine(RichSpan[RichSpan(state.title, :empty_title, nothing)], :empty_title, nothing)]
    state.message === nothing || push!(lines, RichLine(RichSpan[RichSpan(state.message, :empty_message, nothing)], :empty_message, nothing))
    state.action_label === nothing || push!(lines, RichLine(RichSpan[RichSpan("[ $(state.action_label) ]", :empty_action, nothing)], :empty_action, nothing))
    return lines
end

function navigation_control_semantic_node(state::SplitPaneState, id; label="Split pane", bounds=nothing)
    return SemanticNode(
        id,
        GroupRole;
        label=label,
        bounds=bounds,
        state=SemanticState(enabled=!state.disabled, focusable=!state.disabled, value_now=state.fraction, value_min=0, value_max=1),
        actions=state.disabled ? [] : [IncrementSemanticAction, DecrementSemanticAction],
    )
end

function navigation_control_semantic_node(state::DrawerState, id; label="Drawer", bounds=nothing)
    return SemanticNode(
        id,
        GroupRole;
        label=label,
        bounds=bounds,
        state=SemanticState(hidden=!state.open, expanded=state.open),
        actions=state.dismissible ? [DismissSemanticAction] : [],
    )
end

function navigation_control_semantic_node(state::EmptyState, id; label=state.title, bounds=nothing)
    children = state.action_label === nothing ? SemanticNode[] :
        SemanticNode[SemanticNode("$(id)/action", ButtonRole; label=state.action_label, actions=[ActivateSemanticAction])]
    return SemanticNode(id, StatusRole; label=label, description=state.message, bounds=bounds, children=children)
end

end
