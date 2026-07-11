module Toolkit

using ..Core
using ..Events
using ..Interaction
using ..Layout
using ..Runtime
using ..Styles
using ..Widgets
import ..Core: render!
import ..Runtime: app_view, initialize, subscriptions, update!

"""Return the default externally managed state for an immediate-mode widget."""
state_for(widget) = nothing
state_for(::Button) = ButtonState()
state_for(::Checkbox) = CheckboxState()
state_for(::List) = ListState()
state_for(::Menu) = MenuState()
state_for(::MultiSelect) = MultiSelectState()
state_for(::RadioGroup) = RadioGroupState()
state_for(::ScrollView) = ScrollState()
state_for(::Select) = SelectState()
state_for(::Table) = TableState()
state_for(::Tabs) = TabsState()
state_for(::TextArea) = TextAreaState()
state_for(::TextInput) = TextInputState()
state_for(::Toggle) = ToggleState()
state_for(::Tree) = TreeState()
state_for(::Spinner) = SpinnerState()
state_for(::CommandPalette) = CommandPaletteState()
state_for(::LogView) = LogState()

"""A cheap declarative description of one widget or layout container."""
struct Element{W,S,H,M,U}
    key::Any
    id::Any
    widget::W
    children::Vector{Element}
    layout::Any
    state_factory::S
    on_event::H
    on_mount::M
    on_unmount::U
    focusable::Bool
    disabled::Bool
    hidden::Bool
    tab_index::Int
    classes::Set{Symbol}
    style_role::Union{Nothing,Symbol}
    style_patch::StylePatch
    semantics::Any
end

function Element(
    widget;
    key=nothing,
    id=nothing,
    children=(),
    layout=nothing,
    state_factory=() -> state_for(widget),
    on_event=(event, state) -> nothing,
    on_mount=state -> nothing,
    on_unmount=state -> nothing,
    focusable::Bool=false,
    disabled::Bool=false,
    hidden::Bool=false,
    tab_index::Integer=0,
    classes=Symbol[],
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
    semantics=nothing,
)
    resolved_children = Element[]
    for child in children
        child isa Element || throw(ArgumentError("element children must be Element values"))
        push!(resolved_children, child)
    end
    Element(
        key,
        id,
        widget,
        resolved_children,
        layout,
        state_factory,
        on_event,
        on_mount,
        on_unmount,
        focusable,
        disabled,
        hidden,
        Int(tab_index),
        Set{Symbol}(Symbol(value) for value in classes),
        style_role,
        style_patch,
        semantics,
    )
end

"""Wrap an immediate-mode widget in a declarative element."""
leaf(widget; kwargs...) = Element(widget; kwargs...)

function row(
    children...;
    key=nothing,
    id=nothing,
    constraints=nothing,
    margin::Margin=Margin(0),
    gap::Integer=0,
    alignment::FlexAlignment=StartFlex,
    kwargs...,
)
    resolved = isnothing(constraints) ? [Fill(1) for _ in children] : Constraint[constraints...]
    length(resolved) == length(children) ||
        throw(DimensionMismatch("row constraints must match child count"))
    Element(
        nothing;
        key,
        id,
        children,
        layout=FlexLayout(HorizontalLayout, resolved; margin, gap, alignment),
        kwargs...,
    )
end

function column(
    children...;
    key=nothing,
    id=nothing,
    constraints=nothing,
    margin::Margin=Margin(0),
    gap::Integer=0,
    alignment::FlexAlignment=StartFlex,
    kwargs...,
)
    resolved = isnothing(constraints) ? [Fill(1) for _ in children] : Constraint[constraints...]
    length(resolved) == length(children) ||
        throw(DimensionMismatch("column constraints must match child count"))
    Element(
        nothing;
        key,
        id,
        children,
        layout=FlexLayout(VerticalLayout, resolved; margin, gap, alignment),
        kwargs...,
    )
end

stack(children...; kwargs...) = Element(nothing; children, layout=:stack, kwargs...)

function grid(
    children...;
    rows,
    columns,
    margin::Margin=Margin(0),
    row_gap::Integer=0,
    column_gap::Integer=0,
    kwargs...,
)
    Element(
        nothing;
        children,
        layout=GridLayout(rows, columns; margin, row_gap, column_gap),
        kwargs...,
    )
end

struct CenteredLayout
    size::Size
end

centered(child; height::Integer, width::Integer, kwargs...) =
    Element(nothing; children=(child,), layout=CenteredLayout(Size(height, width)), kwargs...)

struct ElementSignature
    kind::Symbol
    widget_type::Any
end

function _signature(element::Element)
    kind = element.layout isa FlexLayout ? :flex :
           element.layout isa GridLayout ? :grid :
           element.layout isa CenteredLayout ? :centered :
           element.layout == :stack ? :stack : :leaf
    ElementSignature(kind, typeof(element.widget))
end

"""Stable, parent-linked identity for one retained declarative element."""
mutable struct ElementPath
    parent::Union{Nothing,ElementPath}
    component::Tuple{Symbol,Any}
    depth::Int
    children::Dict{Tuple{Symbol,Any},ElementPath}
end

ElementPath(parent::Union{Nothing,ElementPath}, component::Tuple{Symbol,Any}) =
    ElementPath(
        parent,
        component,
        parent === nothing ? 1 : parent.depth + 1,
        Dict{Tuple{Symbol,Any},ElementPath}(),
    )

Base.:(==)(left::ElementPath, right::ElementPath) = left === right
Base.isequal(left::ElementPath, right::ElementPath) = left === right
Base.hash(path::ElementPath, seed::UInt) = hash(objectid(path), seed)

function element_path_components(path::ElementPath)
    components = Tuple{Symbol,Any}[]
    current = path
    while true
        push!(components, current.component)
        current.parent === nothing && break
        current = current.parent
    end
    reverse!(components)
    return components
end

mutable struct ElementInstance
    signature::ElementSignature
    state::Any
    element::Any
    area::Rect
    parent::Union{Nothing,ElementPath}
    mounted::Bool
    hidden::Bool
end

"""Persistent state retained across declarative element descriptions."""
mutable struct ToolkitState
    instances::Dict{ElementPath,ElementInstance}
    ids::Dict{Any,ElementPath}
    focus_targets::Dict{Any,ElementPath}
    paint_order::Vector{ElementPath}
    seen::Set{ElementPath}
    roots::Dict{Tuple{Symbol,Any},ElementPath}
    focus::FocusRegistry
    styles::StyleEngine
end

ToolkitState(; styles::StyleEngine=StyleEngine()) = ToolkitState(
    Dict{ElementPath,ElementInstance}(),
    Dict{Any,ElementPath}(),
    Dict{Any,ElementPath}(),
    ElementPath[],
    Set{ElementPath}(),
    Dict{Tuple{Symbol,Any},ElementPath}(),
    FocusRegistry(),
    styles,
)

"""A declarative root plus the persistent state required to render and dispatch it."""
mutable struct ToolkitTree
    root::Element
    state::ToolkitState
end

ToolkitTree(root::Element; styles::StyleEngine=StyleEngine()) =
    ToolkitTree(root, ToolkitState(; styles))

function _path!(
    state::ToolkitState,
    parent::Union{Nothing,ElementPath},
    element::Element,
    index::Int,
)
    component = convert(
        Tuple{Symbol,Any},
        isnothing(element.key) ? (:position, index) : (:key, element.key),
    )
    children = parent === nothing ? state.roots : parent.children
    return get!(children, component) do
        ElementPath(parent, component)
    end
end

function _mount_instance(element::Element, area::Rect, parent, hidden::Bool)
    state = element.state_factory()
    instance = ElementInstance(_signature(element), state, element, area, parent, true, hidden)
    element.on_mount(state)
    instance
end

function _unmount!(instance::ElementInstance)
    instance.mounted || return
    try
        instance.element.on_unmount(instance.state)
    finally
        instance.mounted = false
    end
    nothing
end

function _instance!(
    state::ToolkitState,
    path::ElementPath,
    element::Element,
    area::Rect,
    parent,
    hidden::Bool,
)
    signature = _signature(element)
    if haskey(state.instances, path)
        instance = state.instances[path]
        if instance.signature != signature
            delete!(state.instances, path)
            _unmount!(instance)
            instance = _mount_instance(element, area, parent, hidden)
            state.instances[path] = instance
        else
            instance.element = element
            instance.area = area
            instance.parent = parent
            instance.hidden = hidden
        end
    else
        state.instances[path] = _mount_instance(element, area, parent, hidden)
    end
    push!(state.seen, path)
    push!(state.paint_order, path)
    state.instances[path]
end

function _register_identity!(state::ToolkitState, path::ElementPath, instance::ElementInstance)
    element = instance.element
    if !isnothing(element.id)
        haskey(state.ids, element.id) && throw(ArgumentError("duplicate element ID: $(element.id)"))
        state.ids[element.id] = path
    end
    if element.focusable
        target = isnothing(element.id) ? path : element.id
        state.focus_targets[target] = path
        register_focus!(
            state.focus,
            target,
            instance.area;
            tab_index=element.tab_index,
            disabled=element.disabled,
            hidden=instance.hidden,
        )
    end
    nothing
end

function _set_focus_state!(instance::ElementInstance, focused_value::Bool)
    state = instance.state
    if !isnothing(state) && ismutabletype(typeof(state)) && hasproperty(state, :focused)
        current = getproperty(state, :focused)
        current isa Bool && setproperty!(state, :focused, focused_value)
    end
    nothing
end

function _render_widget!(frame::Frame, instance::ElementInstance)
    element = instance.element
    isnothing(element.widget) && return
    if isnothing(instance.state)
        render!(frame, element.widget, instance.area)
    else
        render!(frame, element.widget, instance.area, instance.state)
    end
end

function _pseudo_states(toolkit::ToolkitState, path::ElementPath, instance::ElementInstance)
    element = instance.element
    values = Set{Symbol}()
    element.disabled && push!(values, :disabled)
    element.hidden && push!(values, :hidden)
    target = isnothing(element.id) ? path : element.id
    focused(toolkit.focus) == target && push!(values, :focus)
    state = instance.state
    if !isnothing(state)
        hasproperty(state, :checked) && getproperty(state, :checked) && push!(values, :checked)
        hasproperty(state, :selected) && !isnothing(getproperty(state, :selected)) && push!(values, :selected)
        hasproperty(state, :open) && getproperty(state, :open) && push!(values, :open)
        hasproperty(state, :focused) && getproperty(state, :focused) && push!(values, :focus)
    end
    values
end

function _ancestor_classes(toolkit::ToolkitState, parent::Union{Nothing,ElementPath})
    values = Set{Symbol}()
    current = parent
    while !isnothing(current)
        instance = toolkit.instances[current]
        union!(values, instance.element.classes)
        current = instance.parent
    end
    values
end

function _apply_element_style!(
    frame::Frame,
    toolkit::ToolkitState,
    path::ElementPath,
    instance::ElementInstance,
)
    element = instance.element
    isnothing(element.style_role) &&
        isempty(element.style_patch) &&
        all(stylesheet -> isempty(stylesheet.rules), toolkit.styles.stylesheets) &&
        return
    context = StyleContext(
        isnothing(element.widget) ? nothing : typeof(element.widget),
        element.id,
        element.classes,
        _pseudo_states(toolkit, path, instance),
        _ancestor_classes(toolkit, instance.parent),
    )
    apply_style!(
        frame.buffer,
        instance.area,
        toolkit.styles,
        context;
        role=element.style_role,
        inline=element.style_patch,
    )
end

function _child_areas(element::Element, area::Rect)
    count = length(element.children)
    count == 0 && return Rect[]
    if element.layout isa FlexLayout
        resolve(element.layout, area)
    elseif element.layout isa GridLayout
        cells = resolve(element.layout, area)
        [cells[row, column] for row in axes(cells, 1) for column in axes(cells, 2)][1:min(count, length(cells))]
    elseif element.layout isa CenteredLayout
        Rect[center(area, element.layout.size)]
    else
        fill(area, count)
    end
end

function _validate_sibling_keys(children)
    keys = Set{Any}()
    for child in children
        isnothing(child.key) && continue
        child.key in keys && throw(ArgumentError("duplicate sibling element key: $(child.key)"))
        push!(keys, child.key)
    end
    nothing
end

function _validate_tree!(element::Element, ids::Set{Any})
    if !isnothing(element.id)
        element.id in ids && throw(ArgumentError("duplicate element ID: $(element.id)"))
        push!(ids, element.id)
    end
    _validate_sibling_keys(element.children)
    for child in element.children
        child isa Element || throw(ArgumentError("element children must be Element values"))
        _validate_tree!(child, ids)
    end
    return element
end

_validate_tree!(element::Element) = _validate_tree!(element, Set{Any}())

function _render_element!(
    frame::Frame,
    state::ToolkitState,
    element::Element,
    area::Rect,
    parent::Union{Nothing,ElementPath},
    index::Int,
    ancestor_hidden::Bool=false,
)
    hidden = ancestor_hidden || element.hidden
    path = _path!(state, parent, element, index)
    instance = _instance!(state, path, element, area, parent, hidden)
    _register_identity!(state, path, instance)
    target = isnothing(element.id) ? path : element.id
    _set_focus_state!(instance, !hidden && element.focusable && focused(state.focus) == target)
    if !hidden
        _render_widget!(frame, instance)
        _apply_element_style!(frame, state, path, instance)
    end
    for (child_index, child_area, child) in
        zip(eachindex(element.children), _child_areas(element, area), element.children)
        _render_element!(frame, state, child, child_area, path, child_index, hidden)
    end
    nothing
end

function _prune!(state::ToolkitState)
    removed = ElementPath[path for path in keys(state.instances) if !(path in state.seen)]
    sort!(removed; by=path -> path.depth, rev=true)
    for path in removed
        instance = pop!(state.instances, path)
        try
            _unmount!(instance)
        finally
            siblings = path.parent === nothing ? state.roots : path.parent.children
            get(siblings, path.component, nothing) === path && delete!(siblings, path.component)
            empty!(path.children)
        end
    end
    nothing
end

"""Reconcile and render a complete declarative element tree."""
function render_toolkit!(frame::Frame, tree::ToolkitTree, area::Rect=frame.area)
    state = tree.state
    _validate_tree!(tree.root)
    empty!(state.ids)
    empty!(state.focus_targets)
    empty!(state.paint_order)
    empty!(state.seen)
    begin_focus_frame!(state.focus)
    _render_element!(frame, state, tree.root, area, nothing, 1)
    _prune!(state)
    focused_target = focused(state.focus)
    focused_path = isnothing(focused_target) ? nothing : get(state.focus_targets, focused_target, nothing)
    focused_invalid = !isnothing(focused_path) && begin
        instance = state.instances[focused_path]
        instance.hidden || instance.element.disabled
    end
    if !isnothing(focused_target) && (isnothing(focused_path) || focused_invalid)
        focus_next!(state.focus)
    elseif isnothing(focused_target)
        focus_next!(state.focus)
    end
    frame.buffer
end

render!(frame::Frame, tree::ToolkitTree, area::Rect) = render_toolkit!(frame, tree, area)
render!(buffer::Buffer, tree::ToolkitTree, area::Rect) =
    render_toolkit!(Frame(buffer), tree, area)

@enum EventPhase::UInt8 begin
    TargetPhase
    BubblePhase
end

struct RoutedEvent{E<:AbstractEvent}
    event::E
    target::Any
    current::Any
    phase::EventPhase
end

struct EventResponse
    consumed::Bool
    stop_propagation::Bool
    redraw::Bool
    message::Any
    focus::Any
end

EventResponse(;
    consumed::Bool=false,
    stop_propagation::Bool=false,
    redraw::Bool=consumed,
    message=nothing,
    focus=nothing,
) = EventResponse(consumed, stop_propagation, redraw, message, focus)

struct DispatchResult
    consumed::Bool
    redraw::Bool
    messages::Vector{Any}
end

function _normalize_response(value)
    value isa EventResponse && return value
    value isa Bool && return EventResponse(consumed=value)
    isnothing(value) && return EventResponse()
    EventResponse(consumed=true, message=value)
end

function _target_path(state::ToolkitState, event::AbstractEvent)
    if event isa MouseEvent
        for path in Iterators.reverse(state.paint_order)
            instance = state.instances[path]
            element = instance.element
            if contains(instance.area, event.position) &&
               (element.focusable || !isnothing(element.widget))
                return path
            end
        end
    else
        target = focused(state.focus)
        !isnothing(target) && haskey(state.focus_targets, target) &&
            return state.focus_targets[target]
    end
    isempty(state.paint_order) ? nothing : first(state.paint_order)
end

function _activation_message(instance::ElementInstance, event::AbstractEvent)
    widget = instance.element.widget
    state = instance.state
    isnothing(widget) && return nothing
    activated = (event isa KeyEvent &&
        (event.key.code == :enter || (event.key.code == :character && event.text == " "))) ||
        (event isa MouseEvent && event.action == MouseRelease)
    activated && applicable(activate, widget, state) ? activate(widget, state) : nothing
end

function _builtin!(instance::ElementInstance, event::AbstractEvent)
    widget = instance.element.widget
    state = instance.state
    isnothing(widget) && return EventResponse()
    handled = if !isnothing(state) && applicable(handle!, state, widget, event, instance.area)
        handle!(state, widget, event, instance.area)
    elseif !isnothing(state) && applicable(handle!, state, widget, event)
        handle!(state, widget, event)
    else
        false
    end
    message = _activation_message(instance, event)
    EventResponse(
        consumed=handled || !isnothing(message),
        redraw=handled,
        message=message,
    )
end

abstract type ToolkitApp <: WickedApp end

"""Initialize the domain model of a declarative toolkit application."""
initialize_model(::ToolkitApp) = nothing

"""Update a toolkit application's domain model."""
toolkit_update!(::ToolkitApp, model, message) = NoCommand()

"""Build the declarative element root for a toolkit application."""
function toolkit_view end

"""Return ongoing subscriptions for a toolkit domain model."""
toolkit_subscriptions(::ToolkitApp, model) = ()

@enum ScreenMode::UInt8 begin
    ReplaceScreen
    OverlayScreen
end

"""A lazily built screen or overlay with stable identity."""
struct Screen{K,F}
    id::K
    build::F
    mode::ScreenMode
end

Screen(id, build::F; mode::ScreenMode=ReplaceScreen) where {F} =
    Screen{typeof(id),F}(id, build, mode)

mutable struct ScreenStack
    screens::Vector{Screen}
end

ScreenStack() = ScreenStack(Screen[])

function push_screen!(stack::ScreenStack, screen::Screen)
    any(existing -> existing.id == screen.id, stack.screens) &&
        throw(ArgumentError("screen ID is already present: $(screen.id)"))
    push!(stack.screens, screen)
    stack
end

function pop_screen!(stack::ScreenStack)
    isempty(stack.screens) ? nothing : pop!(stack.screens)
end

function replace_screen!(stack::ScreenStack, screen::Screen)
    !isempty(stack.screens) && pop!(stack.screens)
    push!(stack.screens, screen)
    stack
end

current_screen(stack::ScreenStack) = isempty(stack.screens) ? nothing : last(stack.screens)

struct PushScreen{S<:Screen}
    screen::S
end

struct PopScreen end

struct ReplaceWithScreen{S<:Screen}
    screen::S
end

"""Runtime-owned domain, retained element tree, and navigation state."""
mutable struct ToolkitModel{M}
    model::M
    tree::ToolkitTree
    screens::ScreenStack
end

function _screen_root(app::ToolkitApp, model::ToolkitModel)
    root = toolkit_view(app, model.model)
    for screen in model.screens.screens
        screen_element = screen.build(app, model.model)
        root = screen.mode == ReplaceScreen ? screen_element : stack(root, screen_element)
    end
    root
end

function initialize(app::ToolkitApp)
    domain = initialize_model(app)
    tree = ToolkitTree(toolkit_view(app, domain))
    ToolkitModel(domain, tree, ScreenStack())
end

function app_view(app::ToolkitApp, model::ToolkitModel)
    model.tree.root = _screen_root(app, model)
    model.tree
end

subscriptions(app::ToolkitApp, model::ToolkitModel) =
    toolkit_subscriptions(app, model.model)

function _toolkit_command(result, model::ToolkitModel)
    if result isa UpdateResult
        model.model = result.model
        UpdateResult(model; command=result.command, redraw=result.redraw)
    elseif result isa AbstractCommand
        result
    elseif isnothing(result)
        NoCommand()
    else
        throw(ArgumentError("toolkit_update! must return nothing, AbstractCommand, or UpdateResult"))
    end
end

function _dispatch_commands(result::DispatchResult)
    commands = AbstractCommand[MessageCommand(message) for message in result.messages]
    result.redraw && push!(commands, FrameCommand())
    isempty(commands) ? NoCommand() : length(commands) == 1 ? first(commands) : BatchCommand(commands)
end

function update!(app::ToolkitApp, model::ToolkitModel, message)
    if message isa PushScreen
        push_screen!(model.screens, message.screen)
        return FrameCommand()
    elseif message isa PopScreen
        pop_screen!(model.screens)
        return FrameCommand()
    elseif message isa ReplaceWithScreen
        replace_screen!(model.screens, message.screen)
        return FrameCommand()
    elseif message isa AbstractEvent
        dispatched = dispatch!(model.tree, message)
        dispatch_command = _dispatch_commands(dispatched)
        if dispatched.consumed
            return dispatch_command
        end
        domain_command = _toolkit_command(toolkit_update!(app, model.model, message), model)
        if domain_command isa UpdateResult
            combined = domain_command.command isa NoCommand ? dispatch_command :
                       dispatch_command isa NoCommand ? domain_command.command :
                       BatchCommand(dispatch_command, domain_command.command)
            return UpdateResult(model; command=combined, redraw=domain_command.redraw || dispatched.redraw)
        end
        domain_command isa NoCommand ? dispatch_command :
        dispatch_command isa NoCommand ? domain_command : BatchCommand(dispatch_command, domain_command)
    else
        _toolkit_command(toolkit_update!(app, model.model, message), model)
    end
end

function _apply_response!(
    toolkit::ToolkitState,
    response::EventResponse,
    messages::Vector{Any},
)
    !isnothing(response.message) && push!(messages, response.message)
    !isnothing(response.focus) && focus!(toolkit.focus, response.focus)
    nothing
end

"""Route an event to its target and then through ancestor elements."""
function dispatch!(tree::ToolkitTree, event::AbstractEvent)
    state = tree.state
    path = _target_path(state, event)
    isnothing(path) && return DispatchResult(false, false, Any[])
    instance = state.instances[path]
    focus_target = isnothing(instance.element.id) ? path : instance.element.id
    event isa MouseEvent && event.action == MousePress && instance.element.focusable &&
        focus!(state.focus, focus_target)
    messages = Any[]
    builtin = _builtin!(instance, event)
    _apply_response!(state, builtin, messages)
    consumed = builtin.consumed
    redraw = builtin.redraw
    current_path = path
    phase = TargetPhase
    while !isnothing(current_path)
        current = state.instances[current_path]
        current_target = isnothing(current.element.id) ? current_path : current.element.id
        routed = RoutedEvent(event, focus_target, current_target, phase)
        response = _normalize_response(current.element.on_event(routed, current.state))
        _apply_response!(state, response, messages)
        consumed |= response.consumed
        redraw |= response.redraw
        response.stop_propagation && break
        current_path = current.parent
        phase = BubblePhase
    end
    if !consumed && event isa KeyEvent
        if event.key.code == :tab
            redraw |= focus_next!(state.focus)
        elseif event.key.code == :backtab
            redraw |= focus_previous!(state.focus)
        end
    end
    DispatchResult(consumed, redraw, messages)
end

"""Return a retained element instance by application ID."""
function element_instance(tree::ToolkitTree, id)
    path = get(tree.state.ids, id, nothing)
    isnothing(path) ? nothing : tree.state.instances[path]
end

"""Return retained local state by application ID."""
function element_state(tree::ToolkitTree, id)
    instance = element_instance(tree, id)
    isnothing(instance) ? nothing : instance.state
end

export BubblePhase,
       DispatchResult,
       Element,
       ElementPath,
       ElementInstance,
       EventPhase,
       EventResponse,
       RoutedEvent,
       TargetPhase,
       ToolkitState,
       ToolkitTree,
       ToolkitApp,
       ToolkitModel,
       Screen,
       ScreenMode,
       ScreenStack,
       OverlayScreen,
       PopScreen,
       PushScreen,
       ReplaceScreen,
       ReplaceWithScreen,
       centered,
       column,
       dispatch!,
       element_instance,
       element_path_components,
       element_state,
       grid,
       leaf,
       render_toolkit!,
       current_screen,
       initialize_model,
       pop_screen!,
       push_screen!,
       replace_screen!,
       row,
       stack,
       state_for,
       toolkit_subscriptions,
       toolkit_update!,
       toolkit_view

end
