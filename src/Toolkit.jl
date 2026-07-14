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
state_for(::PushButton) = PushButtonState()
state_for(::CheckBox) = CheckBoxState()
state_for(::Checkbox) = CheckboxState()
state_for(::List) = ListState()
state_for(::ListView) = ListViewState()
state_for(::OptionList) = OptionListState()
state_for(::Menu) = MenuState()
state_for(::CheckBoxList) = CheckBoxListState()
state_for(::MultiSelect) = MultiSelectState()
state_for(::SelectionList) = SelectionListState()
state_for(::RadioBoxList) = RadioBoxListState()
state_for(::RadioGroup) = RadioGroupState()
state_for(::RadioSet) = RadioSetState()
state_for(::ScrollView) = ScrollState()
state_for(::Scrollbar) = ScrollState()
state_for(::Select) = SelectState()
state_for(::Table) = TableState()
state_for(::Tabs) = TabsState()
state_for(::TextArea) = TextAreaState()
state_for(::Textarea) = TextAreaState()
state_for(::Input) = InputState()
state_for(::TextBox) = TextBoxState()
state_for(::TextField) = TextFieldState()
state_for(::PasswordInput) = TextInputState()
state_for(::SearchInput) = TextInputState()
state_for(::PasswordField) = PasswordFieldState()
state_for(::TextInput) = TextInputState()
state_for(::NumberInput) = NumberInputState()
state_for(::Switch) = SwitchState()
state_for(::Toggle) = ToggleState()
state_for(::Tree) = TreeState()
state_for(::TreeView) = TreeViewState()
state_for(widget::Calendar) = CalendarState(widget)
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

"""Construct a horizontal container using `row` semantics.

`hstack` is a convenience alias for migration from frameworks with explicit
horizontal-stack terminology (for example Textual and TuiKit-style APIs).
"""
hstack(children...; kwargs...) = row(children...; kwargs...)

"""Construct a horizontal container using `row` semantics using `hbox` naming.

`hbox` is a lightweight compatibility alias for Ratatui/JS-style horizontal box
layout helpers.
"""
hbox(children...; kwargs...) = row(children...; kwargs...)

"""Construct a horizontal container using `row` semantics with a UI-framework-neutral name."""
horizontal(children...; kwargs...) = row(children...; kwargs...)

"""Construct a two-axis horizontal split container using `row` semantics.

`hsplit` is a migration alias for split-style layout APIs that use fixed
directional composition (for example textual split panes and Ratatui-style rows).
"""
hsplit(children...; kwargs...) = row(children...; kwargs...)

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

"""Construct a vertical container using `column` semantics.

`vstack` is a compatibility alias for migration from retained-widget frameworks.
"""
vstack(children...; kwargs...) = column(children...; kwargs...)

"""Construct a vertical container using `column` semantics using `vbox` naming."""
vbox(children...; kwargs...) = column(children...; kwargs...)

"""Construct a vertical container using `column` semantics with a UI-framework-neutral name."""
vertical(children...; kwargs...) = column(children...; kwargs...)

"""Construct a two-axis vertical split container using `column` semantics.

`vsplit` is a migration alias for split-style layout APIs that use stacked
children (for example docked stacks and tabular side-by-side transitions).
"""
vsplit(children...; kwargs...) = column(children...; kwargs...)

stack(children...; kwargs...) = Element(nothing; children, layout=:stack, kwargs...)
"""Construct an overlay stack using `stack` semantics.

`zstack` is a compatibility alias for retained-toolkit style absolute overlay
composition where later children are layered above earlier children.
"""
zstack(children...; kwargs...) = stack(children...; kwargs...)

"""Construct an overlay stack using `zstack` semantics.

This alias is useful for ports from frameworks that use an explicit `overlay` name
for layered composition.
"""
overlay(children...; kwargs...) = zstack(children...; kwargs...)

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

"""Browser-style history for registered screen route IDs."""
mutable struct ScreenHistory
    entries::Vector{Any}
    index::Int
end

ScreenHistory() = ScreenHistory(Any[], 0)

"""Display and search metadata for one registered screen route."""
struct ScreenRouteMetadata
    title::String
    description::String
    group::String
    keywords::Tuple{Vararg{String}}
end

function _screen_route_keyword_values(keywords)
    keywords === nothing && return ()
    keywords isa AbstractString && return (keywords,)
    keywords isa Symbol && return (keywords,)
    return keywords
end

function _screen_route_keyword_tuple(keywords)
    output = String[]
    for keyword in _screen_route_keyword_values(keywords)
        text = string(keyword)
        isempty(text) || text in output || push!(output, text)
    end
    return Tuple(output)
end

ScreenRouteMetadata(title, description, keywords) =
    ScreenRouteMetadata(string(title), string(description), "", _screen_route_keyword_tuple(keywords))

ScreenRouteMetadata(; title="", description="", group="", keywords=()) =
    ScreenRouteMetadata(string(title), string(description), string(group), _screen_route_keyword_tuple(keywords))

function _screen_route_metadata(screen::Screen; title=nothing, description=nothing, group=nothing, keywords=())
    route_group = isnothing(group) ? "" : string(group)
    return ScreenRouteMetadata(
        title=isnothing(title) ? string(screen.id) : string(title),
        description=isnothing(description) ? string(screen.mode) : string(description),
        group=route_group,
        keywords=_screen_route_keyword_tuple((screen.id, screen.mode, route_group, _screen_route_keyword_values(keywords)...)),
    )
end

mutable struct ScreenRegistry
    screens::Dict{Any,Screen}
    order::Vector{Any}
    metadata::Dict{Any,ScreenRouteMetadata}
    enabled::Dict{Any,Bool}
    disabled_reasons::Dict{Any,String}
end

ScreenRegistry() = ScreenRegistry(Dict{Any,Screen}(), Any[], Dict{Any,ScreenRouteMetadata}(), Dict{Any,Bool}(), Dict{Any,String}())
ScreenRegistry(screens::Dict{Any,Screen}, order::Vector{Any}) =
    ScreenRegistry(screens, order, Dict{Any,ScreenRouteMetadata}(), Dict{Any,Bool}(), Dict{Any,String}())
ScreenRegistry(screens::Dict{Any,Screen}, order::Vector{Any}, metadata::Dict{Any,ScreenRouteMetadata}) =
    ScreenRegistry(screens, order, metadata, Dict{Any,Bool}(), Dict{Any,String}())
ScreenRegistry(screens::Dict{Any,Screen}, order::Vector{Any}, metadata::Dict{Any,ScreenRouteMetadata}, enabled::Dict{Any,Bool}) =
    ScreenRegistry(screens, order, metadata, enabled, Dict{Any,String}())

function ScreenRegistry(screens::Screen...)
    registry = ScreenRegistry()
    for screen in screens
        register_screen!(registry, screen)
    end
    return registry
end

function register_screen!(
    registry::ScreenRegistry,
    screen::Screen;
    replace::Bool=false,
    title=nothing,
    description=nothing,
    group=nothing,
    keywords=(),
    enabled::Bool=true,
    disabled_reason::AbstractString="",
)
    exists = haskey(registry.screens, screen.id)
    exists && !replace && throw(ArgumentError("screen ID is already registered: $(screen.id)"))
    registry.screens[screen.id] = screen
    registry.metadata[screen.id] = _screen_route_metadata(screen; title, description, group, keywords)
    registry.enabled[screen.id] = Bool(enabled)
    isempty(disabled_reason) ? delete!(registry.disabled_reasons, screen.id) :
        (registry.disabled_reasons[screen.id] = String(disabled_reason))
    exists || push!(registry.order, screen.id)
    return registry
end

function unregister_screen!(registry::ScreenRegistry, id)
    screen = get(registry.screens, id, nothing)
    screen === nothing && return nothing
    delete!(registry.screens, id)
    delete!(registry.metadata, id)
    delete!(registry.enabled, id)
    delete!(registry.disabled_reasons, id)
    filter!(registered_id -> registered_id != id, registry.order)
    return screen
end

registered_screen(registry::ScreenRegistry, id) =
    get(registry.screens, id, nothing)

function _required_registered_screen(registry::ScreenRegistry, id)
    screen = registered_screen(registry, id)
    screen === nothing && throw(ArgumentError("screen ID is not registered: $id"))
    return screen
end

has_registered_screen(registry::ScreenRegistry, id) =
    haskey(registry.screens, id)

function screen_route_enabled(registry::ScreenRegistry, id)
    _required_registered_screen(registry, id)
    return get(registry.enabled, id, true)
end

function screen_route_disabled_reason(registry::ScreenRegistry, id)
    _required_registered_screen(registry, id)
    return get(registry.disabled_reasons, id, "")
end

function set_screen_route_disabled_reason!(registry::ScreenRegistry, id, reason::AbstractString)
    _required_registered_screen(registry, id)
    isempty(reason) ? delete!(registry.disabled_reasons, id) : (registry.disabled_reasons[id] = String(reason))
    return registry
end

clear_screen_route_disabled_reason!(registry::ScreenRegistry, id) =
    set_screen_route_disabled_reason!(registry, id, "")

function set_screen_route_enabled!(registry::ScreenRegistry, id, enabled::Bool; reason::AbstractString="")
    _required_registered_screen(registry, id)
    registry.enabled[id] = Bool(enabled)
    if enabled
        isempty(reason) ? delete!(registry.disabled_reasons, id) : (registry.disabled_reasons[id] = String(reason))
    elseif !isempty(reason)
        registry.disabled_reasons[id] = String(reason)
    end
    return registry
end

enable_screen_route!(registry::ScreenRegistry, id) =
    set_screen_route_enabled!(registry, id, true)

disable_screen_route!(registry::ScreenRegistry, id; reason::AbstractString="") =
    set_screen_route_enabled!(registry, id, false; reason)

function screen_route_metadata(registry::ScreenRegistry, id)
    screen = _required_registered_screen(registry, id)
    return get!(registry.metadata, id) do
        _screen_route_metadata(screen)
    end
end

screen_route_title(registry::ScreenRegistry, id) =
    screen_route_metadata(registry, id).title

screen_route_description(registry::ScreenRegistry, id) =
    screen_route_metadata(registry, id).description

screen_route_group(registry::ScreenRegistry, id) =
    screen_route_metadata(registry, id).group

screen_route_keywords(registry::ScreenRegistry, id) =
    screen_route_metadata(registry, id).keywords

function set_screen_route_metadata!(
    registry::ScreenRegistry,
    id;
    title=nothing,
    description=nothing,
    group=nothing,
    keywords=nothing,
)
    current = screen_route_metadata(registry, id)
    registry.metadata[id] = ScreenRouteMetadata(
        title=isnothing(title) ? current.title : string(title),
        description=isnothing(description) ? current.description : string(description),
        group=isnothing(group) ? current.group : string(group),
        keywords=isnothing(keywords) ? current.keywords : _screen_route_keyword_tuple(keywords),
    )
    return registry
end

screen_registry_count(registry::ScreenRegistry) =
    length(registry.screens)

screen_registry_empty(registry::ScreenRegistry) =
    isempty(registry.screens)

screen_registry_ids(registry::ScreenRegistry) =
    Any[id for id in registry.order if haskey(registry.screens, id)]

screen_registry_screens(registry::ScreenRegistry) =
    Screen[registry.screens[id] for id in screen_registry_ids(registry)]

screen_registry_modes(registry::ScreenRegistry) =
    ScreenMode[registry.screens[id].mode for id in screen_registry_ids(registry)]

function screen_registry_groups(registry::ScreenRegistry)
    groups = String[]
    for id in screen_registry_ids(registry)
        group = screen_route_group(registry, id)
        isempty(group) || group in groups || push!(groups, group)
    end
    return groups
end

screen_registry_records(registry::ScreenRegistry) = [
    (
        index=index,
        id=screen.id,
        title=screen_route_title(registry, screen.id),
        description=screen_route_description(registry, screen.id),
        group=screen_route_group(registry, screen.id),
        mode=screen.mode,
        enabled=screen_route_enabled(registry, screen.id),
        disabled_reason=screen_route_disabled_reason(registry, screen.id),
        keywords=join(screen_route_keywords(registry, screen.id), ","),
    )
    for (index, screen) in enumerate(screen_registry_screens(registry))
]

screen_registry_summary(registry::ScreenRegistry) = (
    count=screen_registry_count(registry),
    replace_count=count(screen -> screen.mode == ReplaceScreen, values(registry.screens)),
    overlay_count=count(screen -> screen.mode == OverlayScreen, values(registry.screens)),
    enabled_count=count(id -> screen_route_enabled(registry, id), screen_registry_ids(registry)),
    disabled_count=count(id -> !screen_route_enabled(registry, id), screen_registry_ids(registry)),
    group_count=length(screen_registry_groups(registry)),
    groups=Tuple(screen_registry_groups(registry)),
)

function screen_registry_group_records(registry::ScreenRegistry)
    records = screen_registry_records(registry)
    return [
        let group_records = [record for record in records if record.group == group]
            (
                index=index,
                group=group,
                count=length(group_records),
                enabled_count=count(record -> record.enabled, group_records),
                disabled_count=count(record -> !record.enabled, group_records),
                route_ids=join((string(record.id) for record in group_records), ","),
            )
        end
        for (index, group) in enumerate(screen_registry_groups(registry))
    ]
end

function screen_registry_group_summary(registry::ScreenRegistry)
    records = screen_registry_group_records(registry)
    return (
        count=length(records),
        route_count=sum(record.count for record in records),
        enabled_count=sum(record.enabled_count for record in records),
        disabled_count=sum(record.disabled_count for record in records),
        groups=Tuple(record.group for record in records),
    )
end

_screen_table_escape(value) =
    replace(replace(string(value), "|" => "\\|"), "\n" => " ")

_screen_tsv_escape(value) =
    replace(replace(string(value), "\t" => " "), "\n" => " ")

_screen_json_string(value) =
    "\"" * replace(string(value), "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t") * "\""

function _screen_records_markdown(records; columns)
    output = String[
        "| $(join(("`$(column)`" for column in columns), " | ")) |",
        "| $(join(fill("---", length(columns)), " | ")) |",
    ]
    for record in records
        push!(output, "| $(join((_screen_table_escape(getproperty(record, column)) for column in columns), " | ")) |")
    end
    return join(output, "\n")
end

function _screen_records_text(records; columns)
    return join(
        (
            join(("$(column)=$(getproperty(record, column))" for column in columns), " ")
            for record in records
        ),
        "\n",
    )
end

function _screen_records_tsv(records; columns, header::Bool=true)
    output = header ? String[join((String(column) for column in columns), "\t")] : String[]
    for record in records
        push!(output, join((_screen_tsv_escape(getproperty(record, column)) for column in columns), "\t"))
    end
    return join(output, "\n")
end

function _screen_records_json(records; columns)
    output = String[
        "{",
        "  \"schema_version\": 1,",
        "  \"count\": $(length(records)),",
        "  \"records\": [",
    ]
    for (index, record) in enumerate(records)
        fields = join(("\"$(column)\": $(_screen_json_string(getproperty(record, column)))" for column in columns), ", ")
        suffix = index == length(records) ? "" : ","
        push!(output, "    {$fields}$suffix")
    end
    push!(output, "  ]")
    push!(output, "}")
    return join(output, "\n")
end

const _SCREEN_REGISTRY_RECORD_COLUMNS = (:index, :id, :title, :description, :group, :mode, :enabled, :disabled_reason, :keywords)
const _SCREEN_REGISTRY_GROUP_RECORD_COLUMNS = (:index, :group, :count, :enabled_count, :disabled_count, :route_ids)

screen_registry_markdown(registry::ScreenRegistry) =
    _screen_records_markdown(screen_registry_records(registry); columns=_SCREEN_REGISTRY_RECORD_COLUMNS)

screen_registry_tsv(registry::ScreenRegistry; header::Bool=true) =
    _screen_records_tsv(screen_registry_records(registry); columns=_SCREEN_REGISTRY_RECORD_COLUMNS, header)

screen_registry_json(registry::ScreenRegistry) =
    _screen_records_json(screen_registry_records(registry); columns=_SCREEN_REGISTRY_RECORD_COLUMNS)

screen_registry_text(registry::ScreenRegistry) =
    _screen_records_text(screen_registry_records(registry); columns=_SCREEN_REGISTRY_RECORD_COLUMNS)

function screen_registry_summary_text(registry::ScreenRegistry)
    summary = screen_registry_summary(registry)
    groups = isempty(summary.groups) ? "" : join(summary.groups, ",")
    return "screens=$(summary.count) replace=$(summary.replace_count) overlay=$(summary.overlay_count) enabled=$(summary.enabled_count) disabled=$(summary.disabled_count) groups=$(summary.group_count) group_names=$groups"
end

screen_registry_group_markdown(registry::ScreenRegistry) =
    _screen_records_markdown(screen_registry_group_records(registry); columns=_SCREEN_REGISTRY_GROUP_RECORD_COLUMNS)

screen_registry_group_tsv(registry::ScreenRegistry; header::Bool=true) =
    _screen_records_tsv(screen_registry_group_records(registry); columns=_SCREEN_REGISTRY_GROUP_RECORD_COLUMNS, header)

screen_registry_group_json(registry::ScreenRegistry) =
    _screen_records_json(screen_registry_group_records(registry); columns=_SCREEN_REGISTRY_GROUP_RECORD_COLUMNS)

screen_registry_group_text(registry::ScreenRegistry) =
    _screen_records_text(screen_registry_group_records(registry); columns=_SCREEN_REGISTRY_GROUP_RECORD_COLUMNS)

function screen_registry_group_summary_text(registry::ScreenRegistry)
    summary = screen_registry_group_summary(registry)
    groups = isempty(summary.groups) ? "" : join(summary.groups, ",")
    return "groups=$(summary.count) routes=$(summary.route_count) enabled=$(summary.enabled_count) disabled=$(summary.disabled_count) group_names=$groups"
end

function screen_registry_filter_records(registry::ScreenRegistry; mode=nothing, group=nothing, enabled=nothing)
    return [
        record for record in screen_registry_records(registry)
        if (mode === nothing || record.mode == mode) &&
           (group === nothing || record.group == string(group)) &&
           (enabled === nothing || record.enabled == Bool(enabled))
    ]
end

screen_registry_filter_count(registry::ScreenRegistry; mode=nothing, group=nothing, enabled=nothing) =
    length(screen_registry_filter_records(registry; mode=mode, group=group, enabled=enabled))

function search_screen_registry_records(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing)
    needle = lowercase(string(query))
    return [
        record for record in screen_registry_filter_records(registry; mode=mode, group=group, enabled=enabled)
        if occursin(needle, lowercase(string(record.id))) ||
           occursin(needle, lowercase(string(record.title))) ||
           occursin(needle, lowercase(string(record.description))) ||
           occursin(needle, lowercase(string(record.group))) ||
           occursin(needle, lowercase(string(record.mode))) ||
           occursin(needle, lowercase(string(record.enabled))) ||
           occursin(needle, lowercase(string(record.disabled_reason))) ||
           occursin(needle, lowercase(string(record.keywords)))
    ]
end

search_screen_registry_count(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing) =
    length(search_screen_registry_records(registry, query; mode=mode, group=group, enabled=enabled))

search_screen_registry_markdown(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing) =
    _screen_records_markdown(search_screen_registry_records(registry, query; mode=mode, group=group, enabled=enabled); columns=_SCREEN_REGISTRY_RECORD_COLUMNS)

search_screen_registry_tsv(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing, header::Bool=true) =
    _screen_records_tsv(search_screen_registry_records(registry, query; mode=mode, group=group, enabled=enabled); columns=_SCREEN_REGISTRY_RECORD_COLUMNS, header)

search_screen_registry_json(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing) =
    _screen_records_json(search_screen_registry_records(registry, query; mode=mode, group=group, enabled=enabled); columns=_SCREEN_REGISTRY_RECORD_COLUMNS)

function _screen_route_item_description(record)
    if record.enabled || isempty(record.disabled_reason)
        return string(record.description)
    end
    description = isempty(record.description) ? "Unavailable" : string(record.description)
    return string(description, " (disabled: ", record.disabled_reason, ")")
end

function screen_registry_command_items(registry::ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false)
    return CommandItem[
        let metadata = screen_route_metadata(registry, record.id)
            CommandItem(
                record.id,
                metadata.title,
                replace ? ReplaceWithRegisteredScreen(registry, record.id) : PushRegisteredScreen(registry, record.id);
                description=_screen_route_item_description(record),
                keywords=collect(metadata.keywords),
                disabled=!record.enabled,
            )
        end
        for record in screen_registry_filter_records(registry; mode=mode, group=group, enabled=enabled)
    ]
end

screen_registry_command_palette(registry::ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false, kwargs...) =
    CommandPalette(screen_registry_command_items(registry; mode=mode, group=group, enabled=enabled, replace=replace); kwargs...)

function screen_registry_command_palette_session(
    registry::ScreenRegistry;
    query::AbstractString="",
    open::Bool=true,
    mode=nothing,
    group=nothing,
    enabled=nothing,
    replace::Bool=false,
    kwargs...,
)
    palette = screen_registry_command_palette(registry; mode=mode, group=group, enabled=enabled, replace=replace, kwargs...)
    state = CommandPaletteState(open=open)
    isempty(query) || set_command_palette_query!(state, palette, query; record=false)
    return (palette=palette, state=state)
end

function search_screen_registry_command_items(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false)
    return CommandItem[
        let metadata = screen_route_metadata(registry, record.id)
            CommandItem(
                record.id,
                metadata.title,
                replace ? ReplaceWithRegisteredScreen(registry, record.id) : PushRegisteredScreen(registry, record.id);
                description=_screen_route_item_description(record),
                keywords=collect(metadata.keywords),
                disabled=!record.enabled,
            )
        end
        for record in search_screen_registry_records(registry, query; mode=mode, group=group, enabled=enabled)
    ]
end

search_screen_registry_command_palette(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false, kwargs...) =
    CommandPalette(search_screen_registry_command_items(registry, query; mode=mode, group=group, enabled=enabled, replace=replace); kwargs...)

function search_screen_registry_command_palette_session(
    registry::ScreenRegistry,
    query;
    mode=nothing,
    group=nothing,
    enabled=nothing,
    palette_query::AbstractString="",
    open::Bool=true,
    replace::Bool=false,
    kwargs...,
)
    palette = search_screen_registry_command_palette(registry, query; mode=mode, group=group, enabled=enabled, replace=replace, kwargs...)
    state = CommandPaletteState(open=open)
    isempty(palette_query) || set_command_palette_query!(state, palette, palette_query; record=false)
    return (palette=palette, state=state)
end

function screen_registry_menu_items(registry::ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false)
    return MenuItem[
        MenuItem(
            record.id,
            screen_route_title(registry, record.id),
            replace ? ReplaceWithRegisteredScreen(registry, record.id) : PushRegisteredScreen(registry, record.id);
            disabled=!record.enabled,
        )
        for record in screen_registry_filter_records(registry; mode=mode, group=group, enabled=enabled)
    ]
end

screen_registry_menu(registry::ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false, kwargs...) =
    Menu(screen_registry_menu_items(registry; mode=mode, group=group, enabled=enabled, replace=replace); kwargs...)

screen_registry_menu_session(registry::ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false, kwargs...) =
    (menu=screen_registry_menu(registry; mode=mode, group=group, enabled=enabled, replace=replace, kwargs...), state=MenuState())

function search_screen_registry_menu_items(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false)
    return MenuItem[
        MenuItem(
            record.id,
            screen_route_title(registry, record.id),
            replace ? ReplaceWithRegisteredScreen(registry, record.id) : PushRegisteredScreen(registry, record.id);
            disabled=!record.enabled,
        )
        for record in search_screen_registry_records(registry, query; mode=mode, group=group, enabled=enabled)
    ]
end

search_screen_registry_menu(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false, kwargs...) =
    Menu(search_screen_registry_menu_items(registry, query; mode=mode, group=group, enabled=enabled, replace=replace); kwargs...)

search_screen_registry_menu_session(registry::ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false, kwargs...) =
    (menu=search_screen_registry_menu(registry, query; mode=mode, group=group, enabled=enabled, replace=replace, kwargs...), state=MenuState())

function _required_enabled_registered_screen(registry::ScreenRegistry, id)
    screen = _required_registered_screen(registry, id)
    if !screen_route_enabled(registry, id)
        reason = screen_route_disabled_reason(registry, id)
        message = isempty(reason) ? "screen route is disabled: $id" : "screen route is disabled: $id ($reason)"
        throw(ArgumentError(message))
    end
    return screen
end

push_registered_screen!(stack::ScreenStack, registry::ScreenRegistry, id) =
    push_screen!(stack, _required_enabled_registered_screen(registry, id))

replace_registered_screen!(stack::ScreenStack, registry::ScreenRegistry, id) =
    replace_screen!(stack, _required_enabled_registered_screen(registry, id))

function screen_history_count(history::ScreenHistory)
    return length(history.entries)
end

screen_history_empty(history::ScreenHistory) =
    isempty(history.entries)

function current_screen_history_id(history::ScreenHistory)
    1 <= history.index <= length(history.entries) || return nothing
    return history.entries[history.index]
end

can_go_back(history::ScreenHistory) =
    history.index > 1

can_go_forward(history::ScreenHistory) =
    1 <= history.index < length(history.entries)

function push_screen_history!(history::ScreenHistory, id)
    current = current_screen_history_id(history)
    isequal(current, id) && return history
    history.index < length(history.entries) && deleteat!(history.entries, (history.index + 1):length(history.entries))
    push!(history.entries, id)
    history.index = length(history.entries)
    return history
end

function replace_screen_history!(history::ScreenHistory, id)
    if history.index == 0
        return push_screen_history!(history, id)
    end
    history.entries[history.index] = id
    history.index < length(history.entries) && deleteat!(history.entries, (history.index + 1):length(history.entries))
    return history
end

function back_screen_history!(history::ScreenHistory)
    can_go_back(history) || return nothing
    history.index -= 1
    return current_screen_history_id(history)
end

function forward_screen_history!(history::ScreenHistory)
    can_go_forward(history) || return nothing
    history.index += 1
    return current_screen_history_id(history)
end

function clear_screen_history!(history::ScreenHistory)
    removed = Any[history.entries...]
    empty!(history.entries)
    history.index = 0
    return removed
end

function screen_history_records(history::ScreenHistory)
    return [
        (
            index=index,
            id=id,
            current=index == history.index,
        )
        for (index, id) in enumerate(history.entries)
    ]
end

screen_history_summary(history::ScreenHistory) = (
    count=screen_history_count(history),
    current_id=current_screen_history_id(history),
    can_go_back=can_go_back(history),
    can_go_forward=can_go_forward(history),
)

screen_history_markdown(history::ScreenHistory) =
    _screen_records_markdown(screen_history_records(history); columns=(:index, :id, :current))

screen_history_tsv(history::ScreenHistory; header::Bool=true) =
    _screen_records_tsv(screen_history_records(history); columns=(:index, :id, :current), header)

screen_history_json(history::ScreenHistory) =
    _screen_records_json(screen_history_records(history); columns=(:index, :id, :current))

function screen_history_command_items(
    history::ScreenHistory,
    registry::ScreenRegistry;
    replace::Bool=true,
    back_title::AbstractString="Back",
    forward_title::AbstractString="Forward",
)
    return CommandItem[
        CommandItem(
            :screen_history_back,
            back_title,
            BackRegisteredScreen(registry; replace=replace);
            description="Navigate to the previous registered screen",
            keywords=["history", "previous", "back"],
            disabled=!can_go_back(history),
        ),
        CommandItem(
            :screen_history_forward,
            forward_title,
            ForwardRegisteredScreen(registry; replace=replace);
            description="Navigate to the next registered screen",
            keywords=["history", "next", "forward"],
            disabled=!can_go_forward(history),
        ),
    ]
end

screen_history_command_palette(history::ScreenHistory, registry::ScreenRegistry; replace::Bool=true, kwargs...) =
    CommandPalette(screen_history_command_items(history, registry; replace=replace); kwargs...)

function screen_history_command_palette_session(
    history::ScreenHistory,
    registry::ScreenRegistry;
    query::AbstractString="",
    open::Bool=true,
    replace::Bool=true,
    kwargs...,
)
    palette = screen_history_command_palette(history, registry; replace=replace, kwargs...)
    state = CommandPaletteState(open=open)
    isempty(query) || set_command_palette_query!(state, palette, query; record=false)
    return (palette=palette, state=state)
end

function screen_history_menu_items(
    history::ScreenHistory,
    registry::ScreenRegistry;
    replace::Bool=true,
    back_label::AbstractString="Back",
    forward_label::AbstractString="Forward",
)
    return MenuItem[
        MenuItem(
            :screen_history_back,
            back_label,
            BackRegisteredScreen(registry; replace=replace);
            disabled=!can_go_back(history),
        ),
        MenuItem(
            :screen_history_forward,
            forward_label,
            ForwardRegisteredScreen(registry; replace=replace);
            disabled=!can_go_forward(history),
        ),
    ]
end

screen_history_menu(history::ScreenHistory, registry::ScreenRegistry; replace::Bool=true, kwargs...) =
    Menu(screen_history_menu_items(history, registry; replace=replace); kwargs...)

screen_history_menu_session(history::ScreenHistory, registry::ScreenRegistry; replace::Bool=true, kwargs...) =
    (menu=screen_history_menu(history, registry; replace=replace, kwargs...), state=MenuState())

function screen_registry_binding_map(
    registry::ScreenRegistry,
    shortcuts;
    replace=nothing,
    modifiers=NONE,
    include_disabled::Bool=false,
    priority::Integer=0,
)
    map = Interaction.BindingMap()
    for shortcut in shortcuts
        id = first(shortcut)
        key = Symbol(last(shortcut))
        include_disabled || screen_route_enabled(registry, id) || continue
        metadata = screen_route_metadata(registry, id)
        reason = screen_route_disabled_reason(registry, id)
        description = screen_route_enabled(registry, id) || isempty(reason) ?
            metadata.title : string(metadata.title, " (disabled: ", reason, ")")
        Interaction.bind!(
            map,
            Interaction.Binding(
                key,
                NavigateRegisteredScreen(registry, id; replace=replace);
                modifiers,
                description,
                priority,
            ),
        )
    end
    return map
end

screen_registry_binding_layer(
    registry::ScreenRegistry,
    shortcuts;
    name::Symbol=:screen_routes,
    active::Bool=true,
    kwargs...,
) = Interaction.BindingLayer(name, screen_registry_binding_map(registry, shortcuts; kwargs...); active=active)

function screen_history_binding_map(
    history::ScreenHistory,
    registry::ScreenRegistry;
    back_key::Symbol=:left,
    forward_key::Symbol=:right,
    modifiers=ALT,
    replace::Bool=true,
    include_unavailable::Bool=false,
    priority::Integer=0,
)
    map = Interaction.BindingMap()
    if include_unavailable || can_go_back(history)
        Interaction.bind!(
            map,
            Interaction.Binding(
                back_key,
                BackRegisteredScreen(registry; replace=replace);
                modifiers,
                description="Back",
                priority,
            ),
        )
    end
    if include_unavailable || can_go_forward(history)
        Interaction.bind!(
            map,
            Interaction.Binding(
                forward_key,
                ForwardRegisteredScreen(registry; replace=replace);
                modifiers,
                description="Forward",
                priority,
            ),
        )
    end
    return map
end

screen_history_binding_layer(
    history::ScreenHistory,
    registry::ScreenRegistry;
    name::Symbol=:screen_history,
    active::Bool=true,
    kwargs...,
) = Interaction.BindingLayer(name, screen_history_binding_map(history, registry; kwargs...); active=active)

function _navigation_should_replace(screen::Screen, replace)
    return isnothing(replace) ? screen.mode == ReplaceScreen : Bool(replace)
end

function _replace_screen_stack!(stack::ScreenStack, screen::Screen)
    clear_screens!(stack)
    push_screen!(stack, screen)
    return stack
end

function navigate_registered_screen!(
    stack::ScreenStack,
    history::ScreenHistory,
    registry::ScreenRegistry,
    id;
    replace=nothing,
    record_history::Bool=true,
)
    screen = _required_enabled_registered_screen(registry, id)
    record_history && push_screen_history!(history, id)
    _navigation_should_replace(screen, replace) ? _replace_screen_stack!(stack, screen) : push_screen!(stack, screen)
    return stack
end

function back_registered_screen!(stack::ScreenStack, history::ScreenHistory, registry::ScreenRegistry; replace::Bool=true)
    id = back_screen_history!(history)
    id === nothing && return nothing
    screen = _required_enabled_registered_screen(registry, id)
    replace ? _replace_screen_stack!(stack, screen) : push_screen!(stack, screen)
    return screen
end

function forward_registered_screen!(stack::ScreenStack, history::ScreenHistory, registry::ScreenRegistry; replace::Bool=true)
    id = forward_screen_history!(history)
    id === nothing && return nothing
    screen = _required_enabled_registered_screen(registry, id)
    replace ? _replace_screen_stack!(stack, screen) : push_screen!(stack, screen)
    return screen
end

function push_screen!(stack::ScreenStack, screen::Screen)
    any(existing -> existing.id == screen.id, stack.screens) &&
        throw(ArgumentError("screen ID is already present: $(screen.id)"))
    push!(stack.screens, screen)
    stack
end

function pop_screen!(stack::ScreenStack)
    isempty(stack.screens) ? nothing : pop!(stack.screens)
end

function remove_screen!(stack::ScreenStack, id)
    index = findfirst(screen -> screen.id == id, stack.screens)
    index === nothing && return nothing
    screen = stack.screens[index]
    deleteat!(stack.screens, index)
    return screen
end

function replace_screen!(stack::ScreenStack, screen::Screen)
    !isempty(stack.screens) && pop!(stack.screens)
    push!(stack.screens, screen)
    stack
end

function clear_screens!(stack::ScreenStack)
    removed = Screen[stack.screens...]
    empty!(stack.screens)
    return removed
end

function clear_overlay_screens!(stack::ScreenStack)
    removed = Screen[]
    kept = Screen[]
    for screen in stack.screens
        if screen.mode == OverlayScreen
            push!(removed, screen)
        else
            push!(kept, screen)
        end
    end
    stack.screens = kept
    return removed
end

function pop_to_screen!(stack::ScreenStack, id; inclusive::Bool=false)
    index = findlast(screen -> screen.id == id, stack.screens)
    index === nothing && return Screen[]
    target = inclusive ? index - 1 : index
    removed = Screen[]
    while length(stack.screens) > target
        pushfirst!(removed, pop!(stack.screens))
    end
    return removed
end

current_screen(stack::ScreenStack) = isempty(stack.screens) ? nothing : last(stack.screens)
screen_stack_count(stack::ScreenStack) = length(stack.screens)
screen_stack_empty(stack::ScreenStack) = isempty(stack.screens)
screen_stack_ids(stack::ScreenStack) = Any[screen.id for screen in stack.screens]
screen_stack_modes(stack::ScreenStack) = ScreenMode[screen.mode for screen in stack.screens]
has_screen(stack::ScreenStack, id) = any(screen -> screen.id == id, stack.screens)

function screen_stack_records(stack::ScreenStack)
    current = current_screen(stack)
    return [
        (
            index=index,
            id=screen.id,
            mode=screen.mode,
            current=current !== nothing && screen.id == current.id,
        )
        for (index, screen) in enumerate(stack.screens)
    ]
end

function screen_stack_summary(stack::ScreenStack)
    current = current_screen(stack)
    return (
        count=screen_stack_count(stack),
        current_id=current === nothing ? nothing : current.id,
        replace_count=count(screen -> screen.mode == ReplaceScreen, stack.screens),
        overlay_count=count(screen -> screen.mode == OverlayScreen, stack.screens),
    )
end

screen_stack_markdown(stack::ScreenStack) =
    _screen_records_markdown(screen_stack_records(stack); columns=(:index, :id, :mode, :current))

screen_stack_tsv(stack::ScreenStack; header::Bool=true) =
    _screen_records_tsv(screen_stack_records(stack); columns=(:index, :id, :mode, :current), header)

screen_stack_json(stack::ScreenStack) =
    _screen_records_json(screen_stack_records(stack); columns=(:index, :id, :mode, :current))

function _screen_element(screen::Screen, app, model)
    if applicable(screen.build, app, model)
        return screen.build(app, model)
    elseif applicable(screen.build, model)
        return screen.build(model)
    elseif applicable(screen.build)
        return screen.build()
    end
    throw(ArgumentError("screen builder must accept (app, model), (model), or no arguments"))
end

function screen_stack_element(::Nothing, screens::ScreenStack, app=nothing, model=nothing)
    element = nothing
    for screen in screens.screens
        screen_element = _screen_element(screen, app, model)
        element = screen.mode == ReplaceScreen || element === nothing ? screen_element : stack(element, screen_element)
    end
    return element
end

function screen_stack_element(root::Element, screens::ScreenStack, app=nothing, model=nothing)
    element = root
    for screen in screens.screens
        screen_element = _screen_element(screen, app, model)
        element = screen.mode == ReplaceScreen || element === nothing ? screen_element : stack(element, screen_element)
    end
    return element
end

screen_stack_element(screens::ScreenStack, app=nothing, model=nothing) =
    screen_stack_element(nothing, screens, app, model)

struct PushScreen{S<:Screen}
    screen::S
end

struct PushRegisteredScreen{R<:ScreenRegistry,K}
    registry::R
    id::K
end

struct NavigateRegisteredScreen{R<:ScreenRegistry,K}
    registry::R
    id::K
    replace::Any
    record_history::Bool
end

NavigateRegisteredScreen(registry::ScreenRegistry, id; replace=nothing, record_history::Bool=true) =
    NavigateRegisteredScreen{typeof(registry),typeof(id)}(registry, id, replace, record_history)

struct PopScreen end

struct BackRegisteredScreen{R<:ScreenRegistry}
    registry::R
    replace::Bool
end

BackRegisteredScreen(registry::ScreenRegistry; replace::Bool=true) =
    BackRegisteredScreen{typeof(registry)}(registry, replace)

struct ForwardRegisteredScreen{R<:ScreenRegistry}
    registry::R
    replace::Bool
end

ForwardRegisteredScreen(registry::ScreenRegistry; replace::Bool=true) =
    ForwardRegisteredScreen{typeof(registry)}(registry, replace)

struct ReplaceWithScreen{S<:Screen}
    screen::S
end

struct ReplaceWithRegisteredScreen{R<:ScreenRegistry,K}
    registry::R
    id::K
end

struct PopToScreen{K}
    id::K
    inclusive::Bool
end

PopToScreen(id; inclusive::Bool=false) =
    PopToScreen{typeof(id)}(id, inclusive)

struct RemoveScreen{K}
    id::K
end

struct ClearOverlayScreens end

struct ClearScreens end

"""Runtime-owned domain, retained element tree, and navigation state."""
mutable struct ToolkitModel{M}
    model::M
    tree::ToolkitTree
    screens::ScreenStack
    history::ScreenHistory
end

ToolkitModel(model::M, tree::ToolkitTree, screens::ScreenStack) where {M} =
    ToolkitModel{M}(model, tree, screens, ScreenHistory())

function _screen_root(app::ToolkitApp, model::ToolkitModel)
    return screen_stack_element(toolkit_view(app, model.model), model.screens, app, model.model)
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
    elseif message isa PushRegisteredScreen
        push_registered_screen!(model.screens, message.registry, message.id)
        return FrameCommand()
    elseif message isa NavigateRegisteredScreen
        navigate_registered_screen!(
            model.screens,
            model.history,
            message.registry,
            message.id;
            replace=message.replace,
            record_history=message.record_history,
        )
        return FrameCommand()
    elseif message isa PopScreen
        pop_screen!(model.screens)
        return FrameCommand()
    elseif message isa BackRegisteredScreen
        back_registered_screen!(model.screens, model.history, message.registry; replace=message.replace)
        return FrameCommand()
    elseif message isa ForwardRegisteredScreen
        forward_registered_screen!(model.screens, model.history, message.registry; replace=message.replace)
        return FrameCommand()
    elseif message isa PopToScreen
        pop_to_screen!(model.screens, message.id; inclusive=message.inclusive)
        return FrameCommand()
    elseif message isa RemoveScreen
        remove_screen!(model.screens, message.id)
        return FrameCommand()
    elseif message isa ReplaceWithScreen
        replace_screen!(model.screens, message.screen)
        return FrameCommand()
    elseif message isa ReplaceWithRegisteredScreen
        replace_registered_screen!(model.screens, message.registry, message.id)
        return FrameCommand()
    elseif message isa ClearOverlayScreens
        clear_overlay_screens!(model.screens)
        return FrameCommand()
    elseif message isa ClearScreens
        clear_screens!(model.screens)
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
    focus_changed = !isnothing(response.focus) && _apply_focus_response!(toolkit, response.focus)
    return focus_changed
end

function _apply_focus_response!(toolkit::ToolkitState, focus)
    before = focused(toolkit.focus)
    accepted = if focus === :next
        focus_next!(toolkit.focus)
    elseif focus === :previous || focus === :prev
        focus_previous!(toolkit.focus)
    elseif focus === :clear || focus === :none
        clear_focus!(toolkit.focus)
    elseif focus === :first
        focus_first!(toolkit.focus)
    elseif focus === :last
        focus_last!(toolkit.focus)
    elseif focus in (:up, :down, :left, :right)
        focus_direction!(toolkit.focus, focus)
    else
        focus!(toolkit.focus, focus)
    end
    return accepted && !isequal(before, focused(toolkit.focus))
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
    builtin_focus_changed = _apply_response!(state, builtin, messages)
    focus_changed = builtin_focus_changed
    consumed = builtin.consumed
    redraw = builtin.redraw || builtin_focus_changed
    current_path = path
    phase = TargetPhase
    while !isnothing(current_path)
        current = state.instances[current_path]
        current_target = isnothing(current.element.id) ? current_path : current.element.id
        routed = RoutedEvent(event, focus_target, current_target, phase)
        response = _normalize_response(current.element.on_event(routed, current.state))
        response_focus_changed = _apply_response!(state, response, messages)
        focus_changed |= response_focus_changed
        consumed |= response.consumed
        redraw |= response.redraw || response_focus_changed
        response.stop_propagation && break
        current_path = current.parent
        phase = BubblePhase
    end
    if !consumed && !focus_changed && event isa KeyEvent
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
       ScreenRegistry,
       ScreenRouteMetadata,
       ScreenHistory,
       ScreenStack,
       OverlayScreen,
       ClearOverlayScreens,
       ClearScreens,
       PopScreen,
       PopToScreen,
       PushScreen,
       PushRegisteredScreen,
       NavigateRegisteredScreen,
       BackRegisteredScreen,
       ForwardRegisteredScreen,
       ReplaceScreen,
       ReplaceWithScreen,
       ReplaceWithRegisteredScreen,
       RemoveScreen,
       clear_overlay_screens!,
       clear_screen_route_disabled_reason!,
       clear_screen_history!,
       clear_screens!,
       can_go_back,
       can_go_forward,
       disable_screen_route!,
       enable_screen_route!,
       back_registered_screen!,
       back_screen_history!,
       current_screen_history_id,
       forward_registered_screen!,
       forward_screen_history!,
       has_registered_screen,
       has_screen,
       centered,
       hbox,
       hsplit,
       hstack,
       horizontal,
       column,
       overlay,
       dispatch!,
       element_instance,
       element_path_components,
       element_state,
       vbox,
       vertical,
       vsplit,
       vstack,
       zstack,
       grid,
       leaf,
       render_toolkit!,
       current_screen,
       initialize_model,
       pop_screen!,
       pop_to_screen!,
       push_screen!,
       push_screen_history!,
       push_registered_screen!,
       registered_screen,
       remove_screen!,
       replace_screen!,
       replace_screen_history!,
       replace_registered_screen!,
       register_screen!,
       navigate_registered_screen!,
       screen_history_count,
       screen_history_empty,
       screen_history_command_items,
       screen_history_command_palette,
       screen_history_command_palette_session,
       screen_history_binding_layer,
       screen_history_binding_map,
       screen_history_json,
       screen_history_markdown,
       screen_history_menu,
       screen_history_menu_items,
       screen_history_menu_session,
       screen_history_records,
       screen_history_summary,
       screen_history_tsv,
       screen_route_description,
       screen_route_disabled_reason,
       screen_route_enabled,
       screen_route_group,
       screen_route_keywords,
       screen_route_metadata,
       screen_route_title,
       set_screen_route_disabled_reason!,
       set_screen_route_enabled!,
       search_screen_registry_count,
       search_screen_registry_command_items,
       search_screen_registry_command_palette,
       search_screen_registry_command_palette_session,
       search_screen_registry_json,
       search_screen_registry_markdown,
       search_screen_registry_menu,
       search_screen_registry_menu_items,
       search_screen_registry_menu_session,
       search_screen_registry_records,
       search_screen_registry_tsv,
       screen_registry_command_items,
       screen_registry_command_palette,
       screen_registry_command_palette_session,
       screen_registry_count,
       screen_registry_empty,
       screen_registry_filter_count,
       screen_registry_filter_records,
       screen_registry_group_json,
       screen_registry_group_markdown,
       screen_registry_group_records,
       screen_registry_group_summary,
       screen_registry_group_summary_text,
       screen_registry_group_text,
       screen_registry_group_tsv,
       screen_registry_groups,
       screen_registry_ids,
       screen_registry_json,
       screen_registry_markdown,
       screen_registry_menu,
       screen_registry_menu_items,
       screen_registry_menu_session,
       screen_registry_modes,
       screen_registry_records,
       screen_registry_screens,
       screen_registry_summary,
       screen_registry_summary_text,
       screen_registry_tsv,
       screen_registry_text,
       screen_registry_binding_layer,
       screen_registry_binding_map,
       screen_stack_count,
       screen_stack_empty,
       screen_stack_element,
       screen_stack_ids,
       screen_stack_json,
       screen_stack_markdown,
       screen_stack_modes,
       screen_stack_records,
       screen_stack_summary,
       screen_stack_tsv,
       set_screen_route_metadata!,
       row,
       stack,
       state_for,
       toolkit_subscriptions,
       toolkit_update!,
       toolkit_view,
       unregister_screen!

end
