"""Stable application-shell widgets composed from layout, overlays, diagnostics, and tracing primitives."""

_drawer_edge(edge::Symbol) = edge == :left ? LeftDrawer : edge == :right ? RightDrawer :
    edge == :top ? TopDrawer : edge == :bottom ? BottomDrawer :
    throw(ArgumentError("drawer edge must be :left, :right, :top, or :bottom"))

struct Drawer{W}
    child::W
    edge::Symbol
    size::Int
    modal::Bool
    dismissible::Bool
    block::Union{Nothing,Block}
end

function Drawer(
    child;
    edge::Symbol=:left,
    size::Integer=30,
    modal::Bool=false,
    dismissible::Bool=true,
    block::Union{Nothing,Block}=Block(),
)
    size >= 0 || throw(ArgumentError("drawer size cannot be negative"))
    _drawer_edge(edge)
    return Drawer(child, edge, Int(size), modal, dismissible, block)
end

state_for(widget::Drawer) = DrawerState(; edge=_drawer_edge(widget.edge), size=widget.size, modal=widget.modal, dismissible=widget.dismissible)

function _drawer_area(state::DrawerState, area::Rect)
    region = drawer_rect(state, ComponentRect(area.row, area.column, area.width, area.height))
    return Rect(region.row, region.column, region.height, region.width)
end

function render!(buffer::Buffer, widget::Drawer, area::Rect, state::DrawerState)
    state.open || return buffer
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    if state.modal
        for row in active.row:(active.row + active.height - 1), column in active.column:(active.column + active.width - 1)
            buffer[row, column] = Cell(" "; style=Style(modifiers=DIM))
        end
    end
    target = intersection(buffer.area, _drawer_area(state, active))
    isempty(target) && return buffer
    if widget.block !== nothing
        render!(buffer, widget.block, target)
        target = intersection(buffer.area, inner(widget.block, target))
    end
    isempty(target) || render!(buffer, widget.child, target)
    return buffer
end
render!(buffer::Buffer, widget::Drawer, area::Rect) = render!(buffer, widget, area, state_for(widget))

function handle!(state::DrawerState, widget::Drawer, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :escape && state.open && state.dismissible
        close_drawer!(state)
        return true
    elseif event.key.code in (:enter, :character) && (event.key.code == :enter || event.text == " ")
        toggle_drawer!(state)
        return true
    end
    return false
end

function handle!(state::DrawerState, widget::Drawer, event::MouseEvent, area::Rect)
    event.action == MousePress && event.button == LeftMouseButton || return false
    state.open && state.modal && state.dismissible || return false
    contains(_drawer_area(state, area), event.position) && return false
    close_drawer!(state)
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::Drawer, state::DrawerState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Drawer",
        state=Accessibility.SemanticState(focusable=true, expanded=state.open),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ActivateSemanticAction],
        metadata=Dict(:edge => widget.edge, :modal => widget.modal, :dismissible => widget.dismissible),
    )
end

mutable struct PopoverState
    open::Bool
    last_placement::Union{Nothing,PopoverResult}
end
PopoverState(; open::Bool=false) = PopoverState(open, nothing)

_popover_placement(placement::Symbol) = placement == :above ? AbovePopover : placement == :below ? BelowPopover :
    placement == :left ? LeftPopover : placement == :right ? RightPopover :
    throw(ArgumentError("popover placement must be :above, :below, :left, or :right"))

struct Popover{W}
    child::W
    anchor::Rect
    width::Int
    height::Int
    preferred::Symbol
    gap::Int
    margin::Int
    dismissible::Bool
    block::Union{Nothing,Block}
end

function Popover(
    child,
    anchor::Rect;
    width::Integer=40,
    height::Integer=8,
    preferred::Symbol=:below,
    gap::Integer=1,
    margin::Integer=0,
    dismissible::Bool=true,
    block::Union{Nothing,Block}=Block(),
)
    width >= 0 || throw(ArgumentError("popover width cannot be negative"))
    height >= 0 || throw(ArgumentError("popover height cannot be negative"))
    gap >= 0 || throw(ArgumentError("popover gap cannot be negative"))
    margin >= 0 || throw(ArgumentError("popover margin cannot be negative"))
    _popover_placement(preferred)
    return Popover(child, anchor, Int(width), Int(height), preferred, Int(gap), Int(margin), dismissible, block)
end

state_for(::Popover) = PopoverState()

function _popover_area(widget::Popover, area::Rect)
    viewport = ComponentRect(area.row, area.column, area.width, area.height)
    anchor = ComponentRect(widget.anchor.row, widget.anchor.column, widget.anchor.width, widget.anchor.height)
    result = place_popover(anchor, widget.width, widget.height, viewport;
        preferred=_popover_placement(widget.preferred), gap=widget.gap, margin=widget.margin)
    return result, Rect(result.rect.row, result.rect.column, result.rect.height, result.rect.width)
end

function render!(buffer::Buffer, widget::Popover, area::Rect, state::PopoverState)
    state.open || return buffer
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    placement, target = _popover_area(widget, active)
    state.last_placement = placement
    target = intersection(buffer.area, target)
    isempty(target) && return buffer
    if widget.block !== nothing
        render!(buffer, widget.block, target)
        target = intersection(buffer.area, inner(widget.block, target))
    end
    isempty(target) || render!(buffer, widget.child, target)
    return buffer
end
render!(buffer::Buffer, widget::Popover, area::Rect) = render!(buffer, widget, area, state_for(widget))

function handle!(state::PopoverState, widget::Popover, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :escape && state.open && widget.dismissible
        state.open = false
        return true
    elseif event.key.code in (:enter, :character) && (event.key.code == :enter || event.text == " ")
        state.open = !state.open
        return true
    end
    return false
end

function handle!(state::PopoverState, widget::Popover, event::MouseEvent, area::Rect)
    event.action == MousePress && event.button == LeftMouseButton || return false
    state.open && widget.dismissible || return false
    _, target = _popover_area(widget, area)
    contains(target, event.position) && return false
    state.open = false
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::Popover, state::PopoverState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Popover",
        state=Accessibility.SemanticState(focusable=true, expanded=state.open),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ActivateSemanticAction],
        metadata=Dict(:preferred => widget.preferred, :dismissible => widget.dismissible),
    )
end

struct Inspector{H<:DiagnosticsHub}
    hub::H
    width::Int
    height::Int
    visible::Bool
    block::Union{Nothing,Block}
end

function Inspector(hub::DiagnosticsHub; width::Integer=80, height::Integer=24, visible::Bool=false, block::Union{Nothing,Block}=Block())
    width > 0 || throw(ArgumentError("inspector width must be positive"))
    height >= 0 || throw(ArgumentError("inspector height cannot be negative"))
    return Inspector(hub, Int(width), Int(height), visible, block)
end

const InspectorState = DeveloperInspector
state_for(widget::Inspector) = InspectorState(; visible=widget.visible)
measure(widget::Inspector, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function _shell_area(buffer::Buffer, widget, area::Rect, block)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return active
    block === nothing && return active
    render!(buffer, block, active)
    return intersection(buffer.area, inner(block, active))
end

function render!(buffer::Buffer, widget::Inspector, area::Rect, state::InspectorState)
    active = _shell_area(buffer, widget, area, widget.block)
    isempty(active) && return buffer
    snapshot = capture_inspector(widget.hub)
    for (offset, line) in enumerate(inspector_lines(state, snapshot; width=active.width, height=active.height))
        draw_text!(buffer, active.row + offset - 1, active.column, line; clip=active)
    end
    return buffer
end
render!(buffer::Buffer, widget::Inspector, area::Rect) = render!(buffer, widget, area, state_for(widget))

function handle!(state::InspectorState, ::Inspector, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :escape && state.visible
        state.visible = false
    elseif event.key.code in (:tab, :right)
        next_panel!(state)
    elseif event.key.code in (:backtab, :left)
        previous_panel!(state)
    elseif event.key.code == :up
        move_selection!(state, -1)
    elseif event.key.code == :down
        move_selection!(state, 1)
    else
        return false
    end
    return true
end

function SemanticToolkit.widget_semantic_descriptor(::Inspector, state::InspectorState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Developer inspector",
        state=Accessibility.SemanticState(focusable=true, expanded=state.visible),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:panel => state.panel, :selected => state.selected),
    )
end

mutable struct DevConsoleState
    offset::Int
    visible::Bool
end
DevConsoleState(; visible::Bool=false) = DevConsoleState(0, visible)

struct DevConsole{H<:DiagnosticsHub}
    hub::H
    width::Int
    height::Int
    visible::Bool
    block::Union{Nothing,Block}
end

function DevConsole(hub::DiagnosticsHub; width::Integer=100, height::Integer=16, visible::Bool=false, block::Union{Nothing,Block}=Block())
    width > 0 || throw(ArgumentError("developer console width must be positive"))
    height >= 0 || throw(ArgumentError("developer console height cannot be negative"))
    return DevConsole(hub, Int(width), Int(height), visible, block)
end

state_for(widget::DevConsole) = DevConsoleState(; visible=widget.visible)
measure(widget::DevConsole, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function dev_console_lines(widget::DevConsole)
    return String["#$(entry.sequence) $(entry.category).$(entry.name) [$(entry.phase)]" for entry in trace_events(widget.hub.traces)]
end

function render!(buffer::Buffer, widget::DevConsole, area::Rect, state::DevConsoleState)
    state.visible || return buffer
    active = _shell_area(buffer, widget, area, widget.block)
    isempty(active) && return buffer
    lines = dev_console_lines(widget)
    state.offset = clamp(state.offset, 0, max(0, length(lines) - active.height))
    for (offset, line) in enumerate(lines[(state.offset + 1):min(length(lines), state.offset + active.height)])
        draw_text!(buffer, active.row + offset - 1, active.column, line; clip=active)
    end
    return buffer
end
render!(buffer::Buffer, widget::DevConsole, area::Rect) = render!(buffer, widget, area, state_for(widget))

function handle!(state::DevConsoleState, widget::DevConsole, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :escape && state.visible
        state.visible = false
    elseif event.key.code in (:enter, :character) && (event.key.code == :enter || event.text == "`")
        state.visible = !state.visible
    elseif event.key.code == :up
        state.offset = max(0, state.offset - 1)
    elseif event.key.code == :down
        state.offset = min(max(0, length(dev_console_lines(widget)) - widget.height), state.offset + 1)
    elseif event.key.code in (:page_up, :pageup)
        state.offset = max(0, state.offset - max(1, widget.height))
    elseif event.key.code in (:page_down, :pagedown)
        state.offset = min(max(0, length(dev_console_lines(widget)) - widget.height), state.offset + max(1, widget.height))
    else
        return false
    end
    return true
end

function SemanticToolkit.widget_semantic_descriptor(::DevConsole, state::DevConsoleState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Developer console",
        state=Accessibility.SemanticState(focusable=true, expanded=state.visible),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ActivateSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:offset => state.offset),
    )
end
