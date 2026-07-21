module Toolkit

using ..Core
using ..Events
using ..Interaction
using ..Layout
using ..Runtime
using ..Styles
using ..Widgets
import ..Core: render!
import ..Runtime: app_view, attach_runtime!, initialize, subscriptions, update!

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

const _ELEMENT_MODIFIER_KEYS = Set((
    :key,
    :id,
    :state_factory,
    :on_capture,
    :on_event,
    :on_mount,
    :on_unmount,
    :focusable,
    :disabled,
    :hidden,
    :tab_index,
    :classes,
    :style_role,
    :style_patch,
    :semantics,
))

"""Reusable, immutable overrides for declarative element behavior and styling.

Compose modifiers with then. When multiple modifiers set the same property,
the rightmost value wins.
"""
struct ElementModifier{P<:NamedTuple}
    properties::P

    function ElementModifier(properties::P) where {P<:NamedTuple}
        unknown = setdiff(Set(keys(properties)), _ELEMENT_MODIFIER_KEYS)
        isempty(unknown) || throw(ArgumentError("unsupported element modifier properties: $(join(sort!(string.(collect(unknown))), ", "))"))
        new{P}(properties)
    end
end

ElementModifier(; kwargs...) = ElementModifier((; kwargs...))
element_modifier(; kwargs...) = ElementModifier(; kwargs...)

"""Compose element modifiers left to right, with later properties overriding earlier ones."""
then(modifiers::ElementModifier...) = foldl(
    (left, right) -> ElementModifier(merge(left.properties, right.properties)),
    modifiers;
    init=ElementModifier(),
)

mutable struct ComponentEffect
    dependencies::Any
    setup::Any
    cleanup::Any
    seen::Bool
    pending::Bool
end

"""One independently mutable value remembered by an explicit component key."""
mutable struct RememberedValue
    value::Any
    dependencies::Any
    seen::Bool
    invalidator::Any
    version::UInt64
    lock::ReentrantLock
    on_change::Any
end

"""Retained local value and keyed effects owned by one declarative component."""
mutable struct ComponentState
    value::Any
    effects::Dict{Any,ComponentEffect}
    effect_order::Vector{Any}
    invalidator::Any
    version::UInt64
    invalidated::Bool
    lock::ReentrantLock
    composition::Dict{Any,Any}
    remembered::Dict{Any,RememberedValue}
end

ComponentState(value=nothing) =
    ComponentState(value, Dict{Any,ComponentEffect}(), Any[], nothing, UInt64(0), false, ReentrantLock(), Dict{Any,Any}(), Dict{Any,RememberedValue}())

component_value(state::ComponentState) = lock(state.lock) do
    state.value
end

"""Return the number of meaningful local-value changes made to a component."""
component_version(state::ComponentState) = lock(state.lock) do
    state.version
end

"""Return whether a component has changed since its invalidation was cleared."""
component_invalidated(state::ComponentState) = lock(state.lock) do
    state.invalidated
end

function _component_invalidator(state::ComponentState)
    lock(state.lock) do
        state.invalidator
    end
end

function _set_component_invalidator!(state::ComponentState, invalidator)
    lock(state.lock) do
        state.invalidator = invalidator
    end
    return state
end

"""Mark a component dirty and notify its owning retained tree once."""
function invalidate_component!(state::ComponentState)
    invalidator = lock(state.lock) do
        state.invalidated = true
        state.invalidator
    end
    invalidator === nothing || invalidator()
    return state
end

"""Acknowledge pending component invalidation without changing its value."""
function clear_component_invalidation!(state::ComponentState)
    lock(state.lock) do
        state.invalidated = false
    end
    return state
end

function set_component_value!(state::ComponentState, value)
    invalidator = lock(state.lock) do
        isequal(state.value, value) && return nothing
        state.value = value
        state.version += UInt64(1)
        state.invalidated = true
        state.invalidator
    end
    invalidator === nothing || invalidator()
    return state
end

function update_component_value!(operation, state::ComponentState, arguments...; kwargs...)
    invalidator = lock(state.lock) do
        applicable(operation, state.value, arguments...) ||
            throw(ArgumentError("component state update is not applicable to the current value"))
        value = operation(state.value, arguments...; kwargs...)
        isequal(state.value, value) && return nothing
        state.value = value
        state.version += UInt64(1)
        state.invalidated = true
        state.invalidator
    end
    invalidator === nothing || invalidator()
    return state
end

remembered_value(value::RememberedValue) = lock(value.lock) do
    value.value
end

remembered_version(value::RememberedValue) = lock(value.lock) do
    value.version
end

function set_remembered_value!(remembered::RememberedValue, value)
    changed, invalidator, on_change = lock(remembered.lock) do
        isequal(remembered.value, value) && return (false, nothing, nothing)
        remembered.value = value
        remembered.version += UInt64(1)
        (true, remembered.invalidator, remembered.on_change)
    end
    changed || return remembered
    on_change === nothing || on_change(value)
    invalidator === nothing || invalidator()
    return remembered
end

function update_remembered_value!(operation, remembered::RememberedValue, arguments...; kwargs...)
    changed, value, invalidator, on_change = lock(remembered.lock) do
        applicable(operation, remembered.value, arguments...) ||
            throw(ArgumentError("remembered state update is not applicable to the current value"))
        value = operation(remembered.value, arguments...; kwargs...)
        isequal(remembered.value, value) && return (false, value, nothing, nothing)
        remembered.value = value
        remembered.version += UInt64(1)
        (true, value, remembered.invalidator, remembered.on_change)
    end
    changed || return remembered
    on_change === nothing || on_change(value)
    invalidator === nothing || invalidator()
    return remembered
end

function _remembered!(state::ComponentState, key, initial, dependencies)
    return lock(state.lock) do
        if haskey(state.remembered, key)
            remembered = state.remembered[key]
            remembered.seen && throw(ArgumentError("duplicate remembered state key: $key"))
            remembered.seen = true
            if dependencies !== nothing && !isequal(remembered.dependencies, dependencies)
                lock(remembered.lock) do
                    remembered.value = initial
                    remembered.dependencies = dependencies
                    remembered.version += UInt64(1)
                end
            end
            return remembered
        end
        remembered = RememberedValue(
            initial,
            dependencies,
            true,
            () -> invalidate_component!(state),
            UInt64(0),
            ReentrantLock(),
            nothing,
        )
        state.remembered[key] = remembered
        return remembered
    end
end

"""Retain an independently mutable value under an explicit component key."""
remember!(state::ComponentState, key, initial) = _remembered!(state, key, initial, nothing)

function _invoke_remember_factory(factory, state::ComponentState, dependencies)
    arguments = dependencies isa Tuple ? dependencies : (dependencies,)
    applicable(factory, arguments...) && return factory(arguments...)
    applicable(factory, state) && return factory(state)
    applicable(factory) && return factory()
    throw(ArgumentError("remember factory must accept dependency values, ComponentState, or no arguments"))
end

"""Retain a value and recreate it when its dependency value changes."""
function remember!(factory, state::ComponentState, key, dependencies=())
    existing = lock(state.lock) do
        get(state.remembered, key, nothing)
    end
    if existing !== nothing && isequal(existing.dependencies, dependencies)
        return _remembered!(state, key, nothing, dependencies)
    end
    return _remembered!(state, key, _invoke_remember_factory(factory, state, dependencies), dependencies)
end

remember!(state::ComponentState, key, dependencies, factory::Function) =
    remember!(factory, state, key, dependencies)

remember!(::ComponentState, ::ComponentState, key) =
    throw(ArgumentError("remember! cannot use ComponentState as both factory and key; choose an unambiguous key"))

remember!(::ComponentState, ::ComponentState, dependencies, factory::Function) =
    throw(ArgumentError("remember! cannot use ComponentState as both factory and key; choose an unambiguous key"))

"""Memoize a derived value by explicit key and dependency snapshot."""
derived_remember!(compute, state::ComponentState, key, dependencies) =
    remember!(compute, state, key, dependencies)

"""Common protocol for controlled and component-owned state hoisting."""
abstract type AbstractStateBinding end

struct StateBinding{G,S,E} <: AbstractStateBinding
    getter::G
    setter::S
    equals::E
end

struct RememberedStateBinding <: AbstractStateBinding
    remembered::RememberedValue
end

function state_binding(getter, setter; equals=isequal)
    applicable(getter) || throw(ArgumentError("state binding getter must accept no arguments"))
    value = getter()
    applicable(setter, value) || throw(ArgumentError("state binding setter must accept a value"))
    applicable(equals, value, value) || throw(ArgumentError("state binding equality must accept two values"))
    return StateBinding(getter, setter, equals)
end

state_binding(value; on_change, equals=isequal) =
    state_binding(() -> value, on_change; equals)

"""Create an uncontrolled binding backed by keyed remembered component state."""
remember_binding!(state::ComponentState, key, initial) =
    RememberedStateBinding(remember!(state, key, initial))

binding_value(binding::StateBinding) = binding.getter()
binding_value(binding::RememberedStateBinding) = remembered_value(binding.remembered)

function set_binding_value!(binding::StateBinding, value)
    current = binding_value(binding)
    binding.equals(current, value) && return binding
    binding.setter(value)
    return binding
end

function set_binding_value!(binding::RememberedStateBinding, value)
    set_remembered_value!(binding.remembered, value)
    return binding
end

function update_binding_value!(operation, binding::AbstractStateBinding, arguments...; kwargs...)
    current = binding_value(binding)
    applicable(operation, current, arguments...) ||
        throw(ArgumentError("state binding update is not applicable to the current value"))
    return set_binding_value!(binding, operation(current, arguments...; kwargs...))
end

"""Focus a parent binding through getter/setter lens functions."""
function map_binding(binding::AbstractStateBinding; get, set, equals=isequal)
    parent = binding_value(binding)
    applicable(get, parent) || throw(ArgumentError("binding lens getter is not applicable"))
    child = get(parent)
    applicable(set, parent, child) ||
        throw(ArgumentError("binding lens setter must accept parent and child values"))
    return state_binding(
        () -> get(binding_value(binding)),
        value -> set_binding_value!(binding, set(binding_value(binding), value));
        equals,
    )
end

"""Retained widget state synchronized with a controlled or uncontrolled binding."""
mutable struct BoundWidgetState{S,B,A,E}
    inner::S
    binding::B
    apply_value!::A
    extract_value::E
end

bound_widget_state(state::BoundWidgetState) = state.inner

function _apply_bound_value!(state::BoundWidgetState)
    value = binding_value(state.binding)
    applicable(state.apply_value!, state.inner, value) ||
        throw(ArgumentError("bound widget apply callback must accept state and value"))
    state.apply_value!(state.inner, value)
    return state
end

function _publish_bound_value!(state::BoundWidgetState)
    applicable(state.extract_value, state.inner) ||
        throw(ArgumentError("bound widget extract callback must accept widget state"))
    set_binding_value!(state.binding, state.extract_value(state.inner))
    return state
end

"""Wrap any stateful interactive widget with two-way binding synchronization."""
function bound_element(
    widget,
    binding::AbstractStateBinding;
    apply_value!,
    extract_value,
    state_factory=() -> state_for(widget),
    kwargs...,
)
    factory = () -> begin
        state = BoundWidgetState(state_factory(), binding, apply_value!, extract_value)
        _apply_bound_value!(state)
    end
    return Element(widget; state_factory=factory, kwargs...)
end

"""Bind a mutable property on an ordinary widget state."""
function bound_property_element(
    widget,
    binding::AbstractStateBinding,
    property::Symbol;
    state_factory=() -> state_for(widget),
    kwargs...,
)
    return bound_element(
        widget,
        binding;
        state_factory,
        apply_value! = (state, value) -> setproperty!(state, property, value),
        extract_value=state -> getproperty(state, property),
        kwargs...,
    )
end

function _begin_component_remembered!(state::ComponentState)
    for remembered in values(state.remembered)
        remembered.seen = false
    end
    return state
end

function _finish_component_remembered!(state::ComponentState)
    for (key, remembered) in collect(state.remembered)
        remembered.seen && continue
        lock(remembered.lock) do
            remembered.invalidator = nothing
            remembered.on_change = nothing
        end
        delete!(state.remembered, key)
    end
    return state
end

"""Address of one component-owned value in a saveable-state registry."""
struct SaveableStateAddress
    scope::Any
    key::Any
end

Base.:(==)(left::SaveableStateAddress, right::SaveableStateAddress) =
    left.scope == right.scope && left.key == right.key
Base.isequal(left::SaveableStateAddress, right::SaveableStateAddress) =
    isequal(left.scope, right.scope) && isequal(left.key, right.key)
Base.hash(address::SaveableStateAddress, seed::UInt) =
    hash(address.key, hash(address.scope, seed))

"""Explicit owner for component state that may outlive a mounted subtree."""
mutable struct SaveableStateRegistry
    values::Dict{SaveableStateAddress,Any}
    lock::ReentrantLock
end

SaveableStateRegistry() = SaveableStateRegistry(Dict{SaveableStateAddress,Any}(), ReentrantLock())

function SaveableStateRegistry(snapshot::AbstractDict)
    values = Dict{SaveableStateAddress,Any}()
    for (address, value) in snapshot
        address isa SaveableStateAddress ||
            throw(ArgumentError("saveable state snapshot keys must be SaveableStateAddress values"))
        values[address] = value
    end
    return SaveableStateRegistry(values, ReentrantLock())
end

saveable_state_snapshot(registry::SaveableStateRegistry) = lock(registry.lock) do
    copy(registry.values)
end

has_saveable_state(registry::SaveableStateRegistry, key; scope=nothing) = lock(registry.lock) do
    haskey(registry.values, SaveableStateAddress(scope, key))
end

function remove_saveable_state!(registry::SaveableStateRegistry, key; scope=nothing)
    lock(registry.lock) do
        pop!(registry.values, SaveableStateAddress(scope, key), nothing)
    end
    return registry
end

function clear_saveable_state!(registry::SaveableStateRegistry; scope=nothing, all::Bool=false)
    lock(registry.lock) do
        if all
            empty!(registry.values)
        else
            for address in collect(keys(registry.values))
                isequal(address.scope, scope) && delete!(registry.values, address)
            end
        end
    end
    return registry
end

function restore_saveable_state!(
    registry::SaveableStateRegistry,
    snapshot::AbstractDict;
    replace::Bool=true,
)
    restored = SaveableStateRegistry(snapshot)
    lock(registry.lock) do
        replace && empty!(registry.values)
        merge!(registry.values, restored.values)
    end
    return registry
end

@enum AsyncResourceStatus begin
    ResourceIdle
    ResourceLoading
    ResourceSuccess
    ResourceFailure
end

mutable struct AsyncResourceToken
    cancelled::Threads.Atomic{Bool}
end

AsyncResourceToken() = AsyncResourceToken(Threads.Atomic{Bool}(false))
resource_cancelled(token::AsyncResourceToken) = token.cancelled[]
throw_if_resource_cancelled(token::AsyncResourceToken) =
    (resource_cancelled(token) && throw(InterruptException()); token)

"""Component-owned asynchronous value with stale-result suppression."""
mutable struct AsyncResource
    status::AsyncResourceStatus
    value::Any
    failure::Union{Nothing,CapturedException}
    generation::UInt64
    task::Union{Nothing,Task}
    token::Union{Nothing,AsyncResourceToken}
    loader::Any
    keep_value::Bool
    invalidator::Any
    lock::ReentrantLock
end

AsyncResource(initial=nothing) = AsyncResource(
    ResourceIdle,
    initial,
    nothing,
    UInt64(0),
    nothing,
    nothing,
    nothing,
    true,
    nothing,
    ReentrantLock(),
)

resource_status(resource::AsyncResource) = lock(resource.lock) do
    resource.status
end
resource_value(resource::AsyncResource) = lock(resource.lock) do
    resource.value
end
resource_failure(resource::AsyncResource) = lock(resource.lock) do
    resource.failure
end
resource_generation(resource::AsyncResource) = lock(resource.lock) do
    resource.generation
end
resource_loading(resource::AsyncResource) = resource_status(resource) == ResourceLoading
resource_succeeded(resource::AsyncResource) = resource_status(resource) == ResourceSuccess
resource_failed(resource::AsyncResource) = resource_status(resource) == ResourceFailure

function _invoke_resource_loader(loader, token, dependencies)
    arguments = dependencies isa Tuple ? dependencies : (dependencies,)
    applicable(loader, token, arguments...) && return loader(token, arguments...)
    applicable(loader, arguments...) && return loader(arguments...)
    applicable(loader, token) && return loader(token)
    applicable(loader) && return loader()
    throw(ArgumentError("async resource loader must accept token/dependencies, dependencies, token, or no arguments"))
end

function load_async_resource!(
    resource::AsyncResource,
    loader=resource.loader;
    dependencies=(),
    keep_value::Bool=resource.keep_value,
)
    loader === nothing && throw(ArgumentError("async resource has no loader"))
    token = AsyncResourceToken()
    generation, invalidator = lock(resource.lock) do
        resource.token === nothing || Threads.atomic_xchg!(resource.token.cancelled, true)
        resource.generation += UInt64(1)
        resource.status = ResourceLoading
        keep_value || (resource.value = nothing)
        resource.failure = nothing
        resource.loader = loader
        resource.keep_value = keep_value
        resource.token = token
        resource.generation, resource.invalidator
    end
    invalidator === nothing || invalidator()
    task = @async begin
        try
            value = _invoke_resource_loader(loader, token, dependencies)
            notify = lock(resource.lock) do
                (resource.generation == generation && resource.token === token && !resource_cancelled(token)) ||
                    return nothing
                resource.value = value
                resource.failure = nothing
                resource.status = ResourceSuccess
                resource.task = nothing
                resource.invalidator
            end
            notify === nothing || notify()
        catch error
            resource_cancelled(token) && return
            failure = CapturedException(error, catch_backtrace())
            notify = lock(resource.lock) do
                (resource.generation == generation && resource.token === token) || return nothing
                resource.failure = failure
                resource.status = ResourceFailure
                resource.task = nothing
                resource.invalidator
            end
            notify === nothing || notify()
        end
    end
    lock(resource.lock) do
        resource.generation == generation && resource.token === token && (resource.task = task)
    end
    return resource
end

function cancel_async_resource!(resource::AsyncResource)
    invalidator = lock(resource.lock) do
        resource.token === nothing || Threads.atomic_xchg!(resource.token.cancelled, true)
        resource.task = nothing
        resource.token = nothing
        resource.status = ResourceIdle
        resource.invalidator
    end
    invalidator === nothing || invalidator()
    return resource
end

retry_async_resource!(resource::AsyncResource; kwargs...) =
    load_async_resource!(resource, resource.loader; kwargs...)

struct AsyncResourceMemoryKey
    key::Any
end
struct AsyncResourceEffectKey
    key::Any
end

"""Retain and load an async resource under an explicit component key."""
function use_resource!(
    state::ComponentState,
    key,
    loader;
    dependencies=(),
    initial=nothing,
    keep_value::Bool=true,
)
    remembered = remember!(state, AsyncResourceMemoryKey(key), AsyncResource(initial))
    resource = remembered_value(remembered)
    use_effect!(state, AsyncResourceEffectKey(key), dependencies) do component_state
        lock(resource.lock) do
            resource.invalidator = () -> invalidate_component!(component_state)
        end
        load_async_resource!(resource, loader; dependencies, keep_value)
        return () -> begin
            lock(resource.lock) do
                resource.invalidator = nothing
            end
            cancel_async_resource!(resource)
        end
    end
    return resource
end

function _invoke_resource_content(builder, primary, resource)
    applicable(builder, primary, resource) && return builder(primary, resource)
    applicable(builder, primary) && return builder(primary)
    applicable(builder, resource) && return builder(resource)
    applicable(builder) && return builder()
    return builder
end

"""Select declarative content for an async resource's current state."""
function resource_content(
    resource::AsyncResource;
    idle=nothing,
    loading="Loading…",
    success=value -> value,
    failure=error -> "Error: $(error.ex)",
)
    status, value, captured = lock(resource.lock) do
        resource.status, resource.value, resource.failure
    end
    status == ResourceIdle && return _invoke_resource_content(idle === nothing ? loading : idle, resource, resource)
    status == ResourceLoading && return _invoke_resource_content(loading, resource, resource)
    status == ResourceSuccess && return _invoke_resource_content(success, value, resource)
    return _invoke_resource_content(failure, captured, resource)
end

"""Build a retained component around loading/error/success resource content."""
function async_resource_component(
    loader;
    dependencies=(),
    resource_key=:resource,
    initial=nothing,
    keep_value::Bool=true,
    idle="Loading…",
    loading=idle,
    success=value -> value,
    failure=error -> "Error: $(error.ex)",
    kwargs...,
)
    return component(; kwargs...) do state
        resource = use_resource!(
            state,
            resource_key,
            loader;
            dependencies,
            initial,
            keep_value,
        )
        resource_content(resource; idle, loading, success, failure)
    end
end

function _begin_component_effects!(state::ComponentState)
    for effect in values(state.effects)
        effect.seen = false
    end
    return state
end

function _invoke_component_cleanup!(cleanup, state::ComponentState)
    cleanup === nothing && return nothing
    if applicable(cleanup, state)
        cleanup(state)
    elseif applicable(cleanup)
        cleanup()
    else
        throw(ArgumentError("component effect cleanup must accept ComponentState or no arguments"))
    end
    return nothing
end

function _invoke_component_effect_setup(setup, state::ComponentState)
    result = if applicable(setup, state)
        setup(state)
    elseif applicable(setup)
        setup()
    else
        throw(ArgumentError("component effect setup must accept ComponentState or no arguments"))
    end
    (result === nothing || applicable(result) || applicable(result, state)) ||
        throw(ArgumentError("component effect setup must return a cleanup callback or nothing"))
    return result
end

"""Register a keyed effect for the current component render.

The setup callback runs after a successful component view build. It runs again
only when dependencies change by isequal; the previous cleanup runs first.
"""
function use_effect!(
    setup,
    state::ComponentState,
    key,
    dependencies=(),
)
    if haskey(state.effects, key)
        effect = state.effects[key]
        changed = !isequal(effect.dependencies, dependencies)
        effect.dependencies = dependencies
        effect.setup = setup
        effect.seen = true
        effect.pending |= changed
    else
        state.effects[key] = ComponentEffect(dependencies, setup, nothing, true, true)
        push!(state.effect_order, key)
    end
    return state
end

use_effect!(state::ComponentState, key, dependencies, setup) =
    use_effect!(setup, state, key, dependencies)

use_effect!(::ComponentState, ::ComponentState, key, dependencies) =
    throw(ArgumentError("use_effect! cannot use ComponentState as both callback and key; choose an unambiguous key"))

"""Compose-compatible name for a keyed setup/cleanup effect."""
disposable_effect!(setup, state::ComponentState, key, dependencies=()) =
    use_effect!(setup, state, key, dependencies)

disposable_effect!(state::ComponentState, key, dependencies, setup) =
    use_effect!(setup, state, key, dependencies)

disposable_effect!(::ComponentState, ::ComponentState, key, dependencies) =
    throw(ArgumentError("disposable_effect! cannot use ComponentState as both callback and key; choose an unambiguous key"))

struct SideEffectKey
    key::Any
end

function _invoke_side_effect(callback, state::ComponentState)
    if applicable(callback, state)
        callback(state)
    elseif applicable(callback)
        callback()
    else
        throw(ArgumentError("side effect must accept ComponentState or no arguments"))
    end
    return nothing
end

"""Run a keyed callback after every successful component commit."""
function side_effect!(callback, state::ComponentState, key)
    effect_key = SideEffectKey(key)
    setup = component_state -> _invoke_side_effect(callback, component_state)
    if haskey(state.effects, effect_key)
        effect = state.effects[effect_key]
        effect.seen && throw(ArgumentError("duplicate side effect key: $key"))
        effect.setup = setup
        effect.seen = true
        effect.pending = true
    else
        state.effects[effect_key] = ComponentEffect((), setup, nothing, true, true)
        push!(state.effect_order, effect_key)
    end
    return state
end

side_effect!(state::ComponentState, key, callback) = side_effect!(callback, state, key)

side_effect!(::ComponentState, ::ComponentState, key) =
    throw(ArgumentError("side_effect! cannot use ComponentState as both callback and key; choose an unambiguous key"))

struct UpdatedRememberedKey
    key::Any
end

"""Remember a cell whose value is refreshed during render without invalidating.

Long-lived effects can retain this cell and read the latest callback or model
value without adding that value to their restart dependencies.
"""
function remember_updated!(state::ComponentState, key, value)
    remembered = remember!(state, UpdatedRememberedKey(key), value)
    lock(remembered.lock) do
        if !isequal(remembered.value, value)
            remembered.value = value
            remembered.version += UInt64(1)
        end
    end
    return remembered
end

function _commit_component_effects!(state::ComponentState)
    for key in reverse(copy(state.effect_order))
        effect = get(state.effects, key, nothing)
        effect === nothing && continue
        if !effect.seen
            _invoke_component_cleanup!(effect.cleanup, state)
            delete!(state.effects, key)
            index = findfirst(item -> isequal(item, key), state.effect_order)
            index === nothing || deleteat!(state.effect_order, index)
        end
    end
    for key in state.effect_order
        effect = state.effects[key]
        effect.pending || continue
        _invoke_component_cleanup!(effect.cleanup, state)
        effect.cleanup = nothing
        effect.cleanup = _invoke_component_effect_setup(effect.setup, state)
        effect.pending = false
    end
    return state
end

"""Run and remove all effect cleanups owned by a component."""
function clear_component_effects!(state::ComponentState)
    first_error = nothing
    for key in reverse(state.effect_order)
        effect = get(state.effects, key, nothing)
        effect === nothing && continue
        try
            _invoke_component_cleanup!(effect.cleanup, state)
        catch error
            first_error === nothing && (first_error = error)
        end
    end
    empty!(state.effects)
    empty!(state.effect_order)
    first_error === nothing || throw(first_error)
    return state
end

@enum LaunchedTaskStatus begin
    LaunchedIdle
    LaunchedRunning
    LaunchedSucceeded
    LaunchedFailed
    LaunchedCancelled
end

"""Cooperative cancellation token passed to a component launched task."""
mutable struct LaunchedTaskToken
    cancelled::Threads.Atomic{Bool}
end

LaunchedTaskToken() = LaunchedTaskToken(Threads.Atomic{Bool}(false))
launched_task_cancelled(token::LaunchedTaskToken) = token.cancelled[]
throw_if_launched_task_cancelled(token::LaunchedTaskToken) =
    (launched_task_cancelled(token) && throw(InterruptException()); token)

"""Lifecycle-bound asynchronous work started by `launched_effect!`."""
mutable struct LaunchedTask
    status::LaunchedTaskStatus
    failure::Union{Nothing,CapturedException}
    generation::UInt64
    task::Union{Nothing,Task}
    token::Union{Nothing,LaunchedTaskToken}
    invalidator::Any
    lock::ReentrantLock
end

LaunchedTask() = LaunchedTask(
    LaunchedIdle,
    nothing,
    UInt64(0),
    nothing,
    nothing,
    nothing,
    ReentrantLock(),
)

launched_task_status(task::LaunchedTask) = lock(task.lock) do
    task.status
end
launched_task_failure(task::LaunchedTask) = lock(task.lock) do
    task.failure
end
launched_task_generation(task::LaunchedTask) = lock(task.lock) do
    task.generation
end
launched_task_running(task::LaunchedTask) = launched_task_status(task) == LaunchedRunning
launched_task_succeeded(task::LaunchedTask) = launched_task_status(task) == LaunchedSucceeded
launched_task_failed(task::LaunchedTask) = launched_task_status(task) == LaunchedFailed

function _invoke_launched_task(operation, token, state, dependencies)
    arguments = dependencies isa Tuple ? dependencies : (dependencies,)
    applicable(operation, token, state, arguments...) && return operation(token, state, arguments...)
    applicable(operation, token, arguments...) && return operation(token, arguments...)
    applicable(operation, state, arguments...) && return operation(state, arguments...)
    applicable(operation, arguments...) && return operation(arguments...)
    applicable(operation, token, state) && return operation(token, state)
    applicable(operation, token) && return operation(token)
    applicable(operation, state) && return operation(state)
    applicable(operation) && return operation()
    throw(ArgumentError("launched effect must accept token/state/dependencies, dependencies, token/state, or no arguments"))
end

function cancel_launched_task!(launched::LaunchedTask)
    invalidator = lock(launched.lock) do
        launched.token === nothing || Threads.atomic_xchg!(launched.token.cancelled, true)
        launched.task = nothing
        launched.token = nothing
        launched.status == LaunchedRunning && (launched.status = LaunchedCancelled)
        launched.invalidator
    end
    invalidator === nothing || invalidator()
    return launched
end

function _start_launched_task!(launched::LaunchedTask, operation, state, dependencies)
    token = LaunchedTaskToken()
    generation, invalidator = lock(launched.lock) do
        launched.token === nothing || Threads.atomic_xchg!(launched.token.cancelled, true)
        launched.generation += UInt64(1)
        launched.status = LaunchedRunning
        launched.failure = nothing
        launched.token = token
        launched.generation, launched.invalidator
    end
    invalidator === nothing || invalidator()
    task = @async try
        _invoke_launched_task(operation, token, state, dependencies)
        notify = lock(launched.lock) do
            (launched.generation == generation && launched.token === token && !launched_task_cancelled(token)) ||
                return nothing
            launched.status = LaunchedSucceeded
            launched.task = nothing
            launched.invalidator
        end
        notify === nothing || notify()
    catch error
        cancelled = launched_task_cancelled(token) || error isa InterruptException
        failure = cancelled ? nothing : CapturedException(error, catch_backtrace())
        notify = lock(launched.lock) do
            (launched.generation == generation && launched.token === token) || return nothing
            launched.status = cancelled ? LaunchedCancelled : LaunchedFailed
            launched.failure = failure
            launched.task = nothing
            launched.invalidator
        end
        notify === nothing || notify()
    end
    lock(launched.lock) do
        launched.generation == generation && launched.token === token && (launched.task = task)
    end
    return launched
end

struct LaunchedTaskMemoryKey
    key::Any
end
struct LaunchedTaskEffectKey
    key::Any
end

"""Launch keyed asynchronous work after a successful component commit.

Changing `dependencies`, omitting the call on a later render, or unmounting the
component cooperatively cancels the previous token. Late completions cannot
overwrite the state of a newer generation.
"""
function launched_effect!(
    operation,
    state::ComponentState,
    key,
    dependencies=(),
)
    remembered = remember!(state, LaunchedTaskMemoryKey(key), LaunchedTask())
    launched = remembered_value(remembered)
    use_effect!(state, LaunchedTaskEffectKey(key), dependencies) do component_state
        lock(launched.lock) do
            launched.invalidator = () -> invalidate_component!(component_state)
        end
        _start_launched_task!(launched, operation, component_state, dependencies)
        return () -> begin
            cancel_launched_task!(launched)
            lock(launched.lock) do
                launched.invalidator = nothing
            end
        end
    end
    return launched
end

launched_effect!(state::ComponentState, key, dependencies, operation) =
    launched_effect!(operation, state, key, dependencies)

launched_effect!(::ComponentState, ::ComponentState, key, dependencies) =
    throw(ArgumentError("launched_effect! cannot use ComponentState as both operation and key; choose an unambiguous key"))

"""A remembered value paired with the lifecycle task producing it."""
struct ProducedState
    remembered::RememberedValue
    task::LaunchedTask
end

produced_value(state::ProducedState) = remembered_value(state.remembered)
produced_version(state::ProducedState) = remembered_version(state.remembered)
produced_status(state::ProducedState) = launched_task_status(state.task)
produced_failure(state::ProducedState) = launched_task_failure(state.task)
produced_running(state::ProducedState) = launched_task_running(state.task)
produced_succeeded(state::ProducedState) = launched_task_succeeded(state.task)
produced_failed(state::ProducedState) = launched_task_failed(state.task)

struct ProducedStateMemoryKey
    key::Any
end

struct ProducedStateTaskKey
    key::Any
end

function _invoke_state_producer(producer, publish, token, state, dependencies)
    arguments = dependencies isa Tuple ? dependencies : (dependencies,)
    applicable(producer, publish, token, state, arguments...) &&
        return producer(publish, token, state, arguments...)
    applicable(producer, publish, token, arguments...) &&
        return producer(publish, token, arguments...)
    applicable(producer, publish, state, arguments...) &&
        return producer(publish, state, arguments...)
    applicable(producer, publish, arguments...) && return producer(publish, arguments...)
    applicable(producer, publish, token, state) && return producer(publish, token, state)
    applicable(producer, publish, token) && return producer(publish, token)
    applicable(producer, publish, state) && return producer(publish, state)
    applicable(producer, publish) && return producer(publish)
    throw(ArgumentError(
        "state producer must accept publish/token/state/dependencies, publish/dependencies, or publish",
    ))
end

"""Produce remembered component state from lifecycle-bound asynchronous work.

The producer receives a `publish(value)` callback followed by the same optional
token, component state, and dependency arguments as `launched_effect!`.
Publishing from a cancelled or superseded generation returns `false` and cannot
overwrite the current generation.
"""
function produce_state!(
    producer,
    state::ComponentState,
    key,
    initial,
    dependencies=(),
)
    remembered = remember!(state, ProducedStateMemoryKey(key), initial)
    task_ref = Ref{Union{Nothing,LaunchedTask}}(nothing)
    task = launched_effect!(state, ProducedStateTaskKey(key), dependencies) do token, component_state, arguments...
        publish = value -> begin
            launched = task_ref[]
            launched === nothing && return false
            return lock(launched.lock) do
                launched.token === token &&
                    launched.status == LaunchedRunning &&
                    !launched_task_cancelled(token) || return false
                set_remembered_value!(remembered, value)
                true
            end
        end
        _invoke_state_producer(producer, publish, token, component_state, arguments)
    end
    task_ref[] = task
    return ProducedState(remembered, task)
end

produce_state!(state::ComponentState, key, initial, dependencies, producer) =
    produce_state!(producer, state, key, initial, dependencies)

produce_state!(::ComponentState, ::ComponentState, key, initial, producer) =
    throw(ArgumentError("produce_state! cannot use ComponentState as both producer and key; choose an unambiguous key"))

"""A functional component whose view is derived from retained local state."""
struct StatefulComponent{F}
    view::F
end

"""Typed composition-local value with identity independent of its display name."""
mutable struct CompositionLocal{T}
    name::Symbol
    default::T
end

"""Create a typed value that can be overridden for one declarative subtree."""
function composition_local(name, default; value_type::Type=typeof(default))
    default isa value_type || throw(ArgumentError("composition-local default does not match value_type"))
    return CompositionLocal{value_type}(Symbol(name), default)
end

"""Read the nearest provided value, or the composition local's default."""
function composition_value(state::ComponentState, composition_local_value::CompositionLocal{T}) where {T}
    return lock(state.lock) do
        get(
            state.composition,
            composition_local_value,
            composition_local_value.default,
        )::T
    end
end

const ComponentAreaLocal = composition_local(
    :component_area,
    Rect(1, 1, 0, 0);
    value_type=Rect,
)

"""Return the current allocation of a retained component."""
component_area(state::ComponentState) = composition_value(state, ComponentAreaLocal)

"""Return the current height and width allocated to a retained component."""
component_size(state::ComponentState) = begin
    area = component_area(state)
    Size(area.height, area.width)
end

function _invoke_constraints_builder(builder, state::ComponentState, area::Rect)
    applicable(builder, state, area) && return builder(state, area)
    applicable(builder, area, state) && return builder(area, state)
    applicable(builder, area) && return builder(area)
    applicable(builder, state) && return builder(state)
    applicable(builder) && return builder()
    throw(ArgumentError(
        "constraint builder must accept state/area, area/state, area, state, or no arguments",
    ))
end

"""Create a component whose content can branch on its allocated `Rect`."""
function box_with_constraints(builder; kwargs...)
    return component(
        state -> _invoke_constraints_builder(builder, state, component_area(state));
        kwargs...,
    )
end

struct SaveableStateContext
    registry::SaveableStateRegistry
    scope::Any
end

const SaveableStateLocal = composition_local(
    :saveable_state_registry,
    nothing;
    value_type=Union{Nothing,SaveableStateContext},
)

struct ContextProvider
    bindings::Vector{Pair{Any,Any}}
end

"""Retained failure state for one declarative error boundary."""
mutable struct ComponentErrorBoundaryState
    failure::Union{Nothing,CapturedException}
    failure_count::UInt64
    reset_key::Any
    invalidator::Any
end

"""Compatibility name for `ComponentErrorBoundaryState`."""
const ErrorBoundaryState = ComponentErrorBoundaryState

struct ComponentErrorBoundary{F,H}
    fallback::F
    on_error::H
    reset_key::Any
end

"""Wrap a subtree and replace it with fallback content after a render failure."""
function error_boundary(
    children...;
    fallback=error -> "Error: $(error.ex)",
    on_error=(error, state) -> nothing,
    reset_key=nothing,
    kwargs...,
)
    widget = ComponentErrorBoundary(fallback, on_error, reset_key)
    return Element(
        widget;
        children,
        state_factory=() -> ComponentErrorBoundaryState(nothing, UInt64(0), reset_key, nothing),
        kwargs...,
    )
end

boundary_failure(state::ComponentErrorBoundaryState) = state.failure
boundary_failed(state::ComponentErrorBoundaryState) = state.failure !== nothing

"""Clear a captured boundary failure and request another render attempt."""
function retry_error_boundary!(state::ComponentErrorBoundaryState)
    state.failure = nothing
    invalidator = state.invalidator
    invalidator === nothing || invalidator()
    return state
end

function _context_bindings(bindings)
    resolved = Pair{Any,Any}[]
    seen = Set{Any}()
    for binding in bindings
        local_value = first(binding)
        local_value isa CompositionLocal || throw(ArgumentError("composition provider key must be CompositionLocal"))
        value = last(binding)
        value isa typeof(local_value).parameters[1] ||
            throw(ArgumentError("provided value does not match composition-local type"))
        local_value in seen && throw(ArgumentError("duplicate composition-local binding: $(local_value.name)"))
        push!(seen, local_value)
        push!(resolved, local_value => value)
    end
    return resolved
end

"""Provide composition-local values to retained components below this node."""
provide_context(bindings::Pair...; children=(), kwargs...) =
    Element(ContextProvider(_context_bindings(bindings)); children, kwargs...)

provide_context(build::Function, bindings::Pair...; kwargs...) =
    provide_context(bindings...; children=(build(),), kwargs...)

"""Provide one saveable-state registry and optional namespace to a subtree."""
saveable_state_provider(
    registry::SaveableStateRegistry,
    children...;
    scope=nothing,
    kwargs...,
) = provide_context(
    SaveableStateLocal => SaveableStateContext(registry, scope);
    children,
    kwargs...,
)

saveable_state_provider(
    build::Function,
    registry::SaveableStateRegistry;
    scope=nothing,
    kwargs...,
) = saveable_state_provider(registry, build(); scope, kwargs...)

struct InheritSaveableStateScope end
const INHERIT_SAVEABLE_STATE_SCOPE = InheritSaveableStateScope()

struct SaveableRememberedKey
    registry::SaveableStateRegistry
    address::SaveableStateAddress
end

Base.:(==)(left::SaveableRememberedKey, right::SaveableRememberedKey) =
    left.registry === right.registry && left.address == right.address
Base.isequal(left::SaveableRememberedKey, right::SaveableRememberedKey) =
    left.registry === right.registry && isequal(left.address, right.address)
Base.hash(key::SaveableRememberedKey, seed::UInt) =
    hash(key.address, hash(objectid(key.registry), seed))

function _saveable_context(
    state::ComponentState,
    registry::Union{Nothing,SaveableStateRegistry},
    scope,
)
    if registry !== nothing
        resolved_scope = scope isa InheritSaveableStateScope ? nothing : scope
        return SaveableStateContext(registry, resolved_scope)
    end
    context = composition_value(state, SaveableStateLocal)
    context === nothing && throw(ArgumentError(
        "remember_saveable! requires a registry keyword or saveable_state_provider ancestor",
    ))
    resolved_scope = scope isa InheritSaveableStateScope ? context.scope : scope
    return SaveableStateContext(context.registry, resolved_scope)
end

function _invoke_saveable_transform(transform, value, state::ComponentState, label::AbstractString)
    applicable(transform, value, state) && return transform(value, state)
    applicable(transform, value) && return transform(value)
    throw(ArgumentError("saveable state $label must accept value/state or value"))
end

function _invoke_saveable_factory(factory, state::ComponentState)
    applicable(factory, state) && return factory(state)
    applicable(factory) && return factory()
    throw(ArgumentError("saveable state factory must accept ComponentState or no arguments"))
end

function _write_saveable_state!(
    registry::SaveableStateRegistry,
    address::SaveableStateAddress,
    value,
    save,
    state::ComponentState,
)
    saved = _invoke_saveable_transform(save, value, state, "saver")
    lock(registry.lock) do
        registry.values[address] = saved
    end
    return value
end

function _remember_saveable!(
    factory,
    state::ComponentState,
    key;
    registry::Union{Nothing,SaveableStateRegistry}=nothing,
    scope=INHERIT_SAVEABLE_STATE_SCOPE,
    save=identity,
    restore=identity,
)
    context = _saveable_context(state, registry, scope)
    address = SaveableStateAddress(context.scope, key)
    memory_key = SaveableRememberedKey(context.registry, address)
    existing = lock(state.lock) do
        get(state.remembered, memory_key, nothing)
    end
    initial = if existing === nothing
        found, saved = lock(context.registry.lock) do
            haskey(context.registry.values, address) ?
                (true, context.registry.values[address]) : (false, nothing)
        end
        found ? _invoke_saveable_transform(restore, saved, state, "restorer") :
            _invoke_saveable_factory(factory, state)
    else
        nothing
    end
    remembered = remember!(state, memory_key, initial)
    observer = value -> _write_saveable_state!(context.registry, address, value, save, state)
    lock(remembered.lock) do
        remembered.on_change = observer
    end
    _write_saveable_state!(context.registry, address, remembered_value(remembered), save, state)
    return remembered
end

"""Retain state locally while mirroring it into an explicit restoration registry."""
remember_saveable!(
    state::ComponentState,
    key,
    initial;
    kwargs...,
) = _remember_saveable!(() -> initial, state, key; kwargs...)

remember_saveable!(
    factory::Function,
    state::ComponentState,
    key;
    kwargs...,
) = _remember_saveable!(factory, state, key; kwargs...)

remember_saveable!(state::ComponentState, key, factory::Function; kwargs...) =
    _remember_saveable!(factory, state, key; kwargs...)

"""A cheap declarative description of one widget or layout container."""
struct Element{W,S,C,H,M,U}
    key::Any
    id::Any
    widget::W
    children::Vector{Element}
    layout::Any
    state_factory::S
    on_capture::C
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
    on_capture=(event, state) -> nothing,
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
    modifier::ElementModifier=ElementModifier(),
)
    resolved_children = Element[]
    for child in children
        _append_elements!(resolved_children, child)
    end
    value = Element(
        key,
        id,
        widget,
        resolved_children,
        layout,
        state_factory,
        on_capture,
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
    return isempty(modifier.properties) ? value : modify(value, modifier)
end

function _modifier_property(modifier::ElementModifier, name::Symbol, fallback)
    return haskey(modifier.properties, name) ? getproperty(modifier.properties, name) : fallback
end

"""Apply a reusable modifier chain to an existing declarative element."""
function modify(value::Element, modifiers::ElementModifier...)
    modifier = then(modifiers...)
    isempty(modifier.properties) && return value
    focusable = _modifier_property(modifier, :focusable, value.focusable)
    disabled = _modifier_property(modifier, :disabled, value.disabled)
    hidden = _modifier_property(modifier, :hidden, value.hidden)
    tab_index = _modifier_property(modifier, :tab_index, value.tab_index)
    classes = _modifier_property(modifier, :classes, value.classes)
    style_role = _modifier_property(modifier, :style_role, value.style_role)
    style_patch = _modifier_property(modifier, :style_patch, value.style_patch)
    focusable isa Bool || throw(ArgumentError("element modifier focusable must be Bool"))
    disabled isa Bool || throw(ArgumentError("element modifier disabled must be Bool"))
    hidden isa Bool || throw(ArgumentError("element modifier hidden must be Bool"))
    tab_index isa Integer || throw(ArgumentError("element modifier tab_index must be an integer"))
    style_role isa Union{Nothing,Symbol} || throw(ArgumentError("element modifier style_role must be Symbol or nothing"))
    style_patch isa StylePatch || throw(ArgumentError("element modifier style_patch must be StylePatch"))
    return Element(
        _modifier_property(modifier, :key, value.key),
        _modifier_property(modifier, :id, value.id),
        value.widget,
        value.children,
        value.layout,
        _modifier_property(modifier, :state_factory, value.state_factory),
        _modifier_property(modifier, :on_capture, value.on_capture),
        _modifier_property(modifier, :on_event, value.on_event),
        _modifier_property(modifier, :on_mount, value.on_mount),
        _modifier_property(modifier, :on_unmount, value.on_unmount),
        focusable,
        disabled,
        hidden,
        Int(tab_index),
        Set{Symbol}(Symbol(item) for item in classes),
        style_role,
        style_patch,
        _modifier_property(modifier, :semantics, value.semantics),
    )
end

"""Stable handle for requesting focus from declarative component code.

Attach it with `focus_requester(element, requester)`, then call
`request_focus!(tree, requester)` after the element has been rendered. The
requester itself becomes the focus identity when the element has no explicit
`id`, so callers do not need to invent globally unique IDs.
"""
mutable struct FocusRequester
    target::Any
end

FocusRequester() = FocusRequester(nothing)
focus_requester_target(requester::FocusRequester) = requester.target

"""Attach a focus requester to an element and make that element focusable."""
function focus_requester(
    value::Element,
    requester::FocusRequester;
    target=nothing,
)
    resolved = target === nothing ?
        (value.id === nothing ? requester : value.id) : target
    value.id === nothing || isequal(value.id, resolved) ||
        throw(ArgumentError("focus requester target must match the element ID"))
    requester.target = resolved
    modifier = value.id === nothing ?
        element_modifier(id=resolved, focusable=true) :
        element_modifier(focusable=true)
    return modify(value, modifier)
end

focus_requester(widget, requester::FocusRequester; kwargs...) =
    focus_requester(element(widget), requester; kwargs...)

"""Wrap an immediate-mode widget in a declarative element."""
leaf(widget; kwargs...) = Element(widget; kwargs...)

"""Convert a widget or an existing `Element` to a declarative element.

`element` is the primary leaf constructor for Compose-style trees. Existing
elements pass through unchanged when no properties are supplied, which makes
conditional and generated child collections easy to compose.
"""
function element(
    value::Element;
    modifier::ElementModifier=ElementModifier(),
    kwargs...,
)
    isempty(kwargs) ||
        throw(ArgumentError("cannot apply element properties to an existing Element; use an ElementModifier"))
    return isempty(modifier.properties) ? value : modify(value, modifier)
end
element(widget; kwargs...) = Element(widget; kwargs...)

"""Create a retained functional component boundary.

The view receives a ComponentState and may return an element, widget, string,
collection, generator, or nothing. Rebuilding the description with the same key
preserves the local value, descendant state, and keyed effects.
"""
function component(
    view;
    initial=nothing,
    state_factory=() -> ComponentState(initial),
    kwargs...,
)
    haskey(kwargs, :children) &&
        throw(ArgumentError("component view owns its children; return them from the view callback"))
    return Element(
        StatefulComponent(view);
        state_factory,
        kwargs...,
    )
end

function _append_elements!(destination::Vector{Element}, child)
    isnothing(child) && return destination
    if child isa Element
        push!(destination, child)
    elseif child isa Tuple || child isa AbstractVector || child isa Base.Generator
        for nested in child
            _append_elements!(destination, nested)
        end
    elseif child isa AbstractString
        push!(destination, element(Label(child)))
    else
        push!(destination, element(child))
    end
    return destination
end

function _normalize_elements(children)
    resolved = Element[]
    for child in children
        _append_elements!(resolved, child)
    end
    return resolved
end

"""Attach an explicit reconciliation key to exactly one normalized child.

An existing equal key is preserved. A conflicting key is rejected so collection
helpers cannot silently replace identity chosen by the child itself.
"""
function keyed(key, content)
    isnothing(key) && throw(ArgumentError("keyed content requires a non-nothing key"))
    children = _normalize_elements((content,))
    length(children) == 1 || throw(ArgumentError(
        "keyed content must normalize to exactly one element; wrap multiple children in fragment or a layout",
    ))
    child = only(children)
    if isnothing(child.key)
        return modify(child, element_modifier(key=key))
    end
    isequal(child.key, key) || throw(ArgumentError(
        "keyed content already has conflicting key $(repr(child.key)); requested $(repr(key))",
    ))
    return child
end

keyed(builder::Function, key) = keyed(key, builder())

function _invoke_keyed_collection_key(key_function, item, index::Int)
    applicable(key_function, item, index) && return key_function(item, index)
    applicable(key_function, item) && return key_function(item)
    throw(ArgumentError("keyed_each key function must accept item/index or item"))
end

function _invoke_keyed_collection_item(builder, item, index::Int, key)
    applicable(builder, item, index, key) && return builder(item, index, key)
    applicable(builder, item, index) && return builder(item, index)
    applicable(builder, item) && return builder(item)
    applicable(builder) && return builder()
    throw(ArgumentError(
        "keyed_each item builder must accept item/index/key, item/index, item, or no arguments",
    ))
end

"""Build one explicitly keyed element per value from any finite iterable.

The key callback accepts `(item, index)` or `item`; the item callback accepts
`(item, index, key)`, `(item, index)`, `item`, or no arguments. Keys are checked
for `nothing` and duplicates before the result is returned.
"""
function keyed_each(items; key, item)
    elements = Element[]
    keys = Set{Any}()
    for (index, value) in enumerate(items)
        resolved_key = _invoke_keyed_collection_key(key, value, index)
        isnothing(resolved_key) && throw(ArgumentError(
            "keyed_each produced nothing for item $index",
        ))
        resolved_key in keys && throw(ArgumentError(
            "keyed_each produced duplicate key $(repr(resolved_key)) at item $index",
        ))
        push!(keys, resolved_key)
        content = _invoke_keyed_collection_item(item, value, index, resolved_key)
        push!(elements, keyed(resolved_key, content))
    end
    return elements
end

keyed_each(item::Function, items; key) = keyed_each(items; key, item)

"""Normalized default and named child content for reusable components."""
struct ComponentSlots
    values::Dict{Symbol,Vector{Element}}
end

function component_slots(default...; kwargs...)
    values = Dict{Symbol,Vector{Element}}(:default => _normalize_elements(default))
    for (name, content) in pairs(kwargs)
        values[Symbol(name)] = _normalize_elements((content,))
    end
    return ComponentSlots(values)
end

"""Return normalized content for a named component slot."""
function slot(slots::ComponentSlots, name=:default; fallback=())
    identifier = Symbol(name)
    return haskey(slots.values, identifier) ? copy(slots.values[identifier]) : _normalize_elements((fallback,))
end

has_slot(slots::ComponentSlots, name) = !isempty(get(slots.values, Symbol(name), Element[]))
slot_names(slots::ComponentSlots) = sort!(collect(keys(slots.values)))

"""Create a layout-only element and flatten tuple, vector, and generator children.

`fragment` is useful for conditional or generated UI. `nothing` children are
omitted, and immediate-mode widgets are automatically wrapped as elements.
"""
fragment(children...; kwargs...) = Element(nothing; children, kwargs...)

function _ui_block_expressions(body)
    expressions = body isa Expr && body.head == :block ? body.args : Any[body]
    return Any[expression for expression in expressions if !(expression isa LineNumberNode)]
end

function _expand_ui_expression(expression)
    expression isa Expr || return expression
    if expression.head == :do
        length(expression.args) == 2 || throw(ArgumentError("invalid @ui do block"))
        call, closure = expression.args
        call isa Expr && call.head == :call ||
            throw(ArgumentError("@ui do blocks must decorate a component call"))
        closure isa Expr && closure.head == :-> ||
            throw(ArgumentError("invalid @ui component body"))
        parameters, body = closure.args
        parameters isa Expr && parameters.head == :tuple && isempty(parameters.args) ||
            throw(ArgumentError("@ui component bodies cannot declare arguments"))
        expanded_call = _expand_ui_expression(call)
        children = map(_expand_ui_expression, _ui_block_expressions(body))
        return Expr(:call, expanded_call.args..., children...)
    end
    return Expr(expression.head, map(_expand_ui_expression, expression.args)...)
end

"""Build a nested declarative Toolkit tree using zero-argument `do` blocks.

Every expression in a component body becomes a child of the decorated call.
Nested blocks are expanded recursively, while ordinary Julia conditionals and
comprehensions remain ordinary expressions and are normalized by the Toolkit.
"""
macro ui(expression)
    return esc(_expand_ui_expression(expression))
end

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
    resolved_children = _normalize_elements(children)
    resolved = isnothing(constraints) ? [Fill(1) for _ in resolved_children] : Constraint[constraints...]
    length(resolved) == length(resolved_children) ||
        throw(DimensionMismatch("row constraints must match child count"))
    Element(
        nothing;
        key,
        id,
        children=resolved_children,
        layout=FlexLayout(HorizontalLayout, resolved; margin, gap, alignment),
        kwargs...,
    )
end

"""Construct a horizontal container using `row` semantics.

`hstack` is a convenience alias for migration from frameworks with explicit
horizontal-stack terminology (for example Textual and TuiKit-style APIs).
"""
hstack(children...; kwargs...) = row(children...; kwargs...)

"""Compatibility migration alias for upper-case layout naming conventions."""
HStack(children...; kwargs...) = row(children...; kwargs...)

"""Construct a horizontal container using `row` semantics using `hbox` naming.

`hbox` is a lightweight compatibility alias for Ratatui/JS-style horizontal box
layout helpers.
"""
hbox(children...; kwargs...) = row(children...; kwargs...)

"""Compatibility migration alias for upper-case layout naming conventions."""
HBox(children...; kwargs...) = row(children...; kwargs...)

"""Construct a horizontal container using `row` semantics with a UI-framework-neutral name."""
horizontal(children...; kwargs...) = row(children...; kwargs...)

"""Construct a two-axis horizontal split container using `row` semantics.

`hsplit` is a migration alias for split-style layout APIs that use fixed
directional composition (for example textual split panes and Ratatui-style rows).
"""
hsplit(children...; kwargs...) = row(children...; kwargs...)

"""Compatibility migration alias for upper-case split naming conventions."""
HSplit(children...; kwargs...) = row(children...; kwargs...)

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
    resolved_children = _normalize_elements(children)
    resolved = isnothing(constraints) ? [Fill(1) for _ in resolved_children] : Constraint[constraints...]
    length(resolved) == length(resolved_children) ||
        throw(DimensionMismatch("column constraints must match child count"))
    Element(
        nothing;
        key,
        id,
        children=resolved_children,
        layout=FlexLayout(VerticalLayout, resolved; margin, gap, alignment),
        kwargs...,
    )
end

"""Construct a vertical container using `column` semantics.

`vstack` is a compatibility alias for migration from retained-widget frameworks.
"""
vstack(children...; kwargs...) = column(children...; kwargs...)

"""Compatibility migration alias for upper-case layout naming conventions."""
VStack(children...; kwargs...) = column(children...; kwargs...)

"""Construct a vertical container using `column` semantics using `vbox` naming."""
vbox(children...; kwargs...) = column(children...; kwargs...)

"""Compatibility migration alias for upper-case layout naming conventions."""
VBox(children...; kwargs...) = column(children...; kwargs...)

"""Construct a vertical container using `column` semantics with a UI-framework-neutral name."""
vertical(children...; kwargs...) = column(children...; kwargs...)

"""Construct a two-axis vertical split container using `column` semantics.

`vsplit` is a migration alias for split-style layout APIs that use stacked
children (for example docked stacks and tabular side-by-side transitions).
"""
vsplit(children...; kwargs...) = column(children...; kwargs...)

"""Compatibility migration alias for upper-case split naming conventions."""
VSplit(children...; kwargs...) = column(children...; kwargs...)

stack(children...; kwargs...) = Element(nothing; children, layout=:stack, kwargs...)
"""Construct an overlay stack using `stack` semantics.

`zstack` is a compatibility alias for retained-toolkit style absolute overlay
composition where later children are layered above earlier children.
"""
zstack(children...; kwargs...) = stack(children...; kwargs...)

"""Compatibility migration alias for upper-case overlay naming conventions."""
ZStack(children...; kwargs...) = stack(children...; kwargs...)

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

@enum ReconciliationAction::UInt8 begin
    ReconciliationMount
    ReconciliationReuse
    ReconciliationReplace
    ReconciliationMove
    ReconciliationUnmount
end

"""One retained-tree identity decision captured during reconciliation."""
struct ReconciliationRecord
    sequence::UInt64
    action::ReconciliationAction
    path::Vector{Tuple{Symbol,Any}}
    element_id::Any
    key::Any
    previous_signature::Union{Nothing,ElementSignature}
    signature::Union{Nothing,ElementSignature}
    previous_index::Union{Nothing,Int}
    index::Union{Nothing,Int}
    reason::Symbol
end

"""Bounded reconciliation history owned by a `ToolkitState`."""
mutable struct ReconciliationTrace
    capacity::Int
    sequence::UInt64
    records::Vector{ReconciliationRecord}
end

"""Development diagnostic for retained state exposed to positional identity shifts."""
struct PositionalIdentityWarning
    sequence::UInt64
    parent_path::Vector{Tuple{Symbol,Any}}
    change::Symbol
    previous_count::Int
    count::Int
    affected_indices::Vector{Int}
    reason::Symbol
end

struct PositionalChildSnapshot
    index::Int
    element_id::Any
    signature::ElementSignature
    stateful::Bool
end

function ReconciliationTrace(capacity::Integer=1024)
    capacity >= 0 || throw(ArgumentError("reconciliation trace capacity must be nonnegative"))
    ReconciliationTrace(Int(capacity), UInt64(0), ReconciliationRecord[])
end

function _signature(element::Element)
    kind = element.layout isa FlexLayout ? :flex :
           element.layout isa GridLayout ? :grid :
           element.layout isa CenteredLayout ? :centered :
           element.layout == :stack ? :stack : :leaf
    widget_type = element.widget isa ComponentErrorBoundary ? ComponentErrorBoundary : typeof(element.widget)
    ElementSignature(kind, widget_type)
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

struct FlexAreaCache
    direction::LayoutDirection
    constraints::Vector{Constraint}
    margin::Margin
    gap::Int
    alignment::FlexAlignment
    area::Rect
    count::Int
    regions::Vector{Rect}
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
    pointer_capture::Any
    styles::StyleEngine
    pending_component_effects::Vector{ComponentState}
    invalidator::Any
    invalidation_pending::Bool
    dispatch_depth::Int
    invalidation_lock::ReentrantLock
    composition::Dict{Any,Any}
    validation_ids::Set{Any}
    validation_keys::Vector{Set{Any}}
    flex_area_cache::Dict{ElementPath,FlexAreaCache}
    reconciliation::ReconciliationTrace
    sibling_indices::Dict{ElementPath,Int}
    positional_identity_warnings::Bool
    positional_warnings::Vector{PositionalIdentityWarning}
    positional_warning_sequence::UInt64
    positional_children::Dict{ElementPath,Vector{PositionalChildSnapshot}}
end

ToolkitState(
    ;
    styles::StyleEngine=StyleEngine(),
    reconciliation_capacity::Integer=1024,
    positional_identity_warnings::Bool=true,
) = ToolkitState(
    Dict{ElementPath,ElementInstance}(),
    Dict{Any,ElementPath}(),
    Dict{Any,ElementPath}(),
    ElementPath[],
    Set{ElementPath}(),
    Dict{Tuple{Symbol,Any},ElementPath}(),
    FocusRegistry(),
    nothing,
    styles,
    ComponentState[],
    nothing,
    false,
    0,
    ReentrantLock(),
    Dict{Any,Any}(),
    Set{Any}(),
    Set{Any}[],
    Dict{ElementPath,FlexAreaCache}(),
    ReconciliationTrace(reconciliation_capacity),
    Dict{ElementPath,Int}(),
    positional_identity_warnings,
    PositionalIdentityWarning[],
    UInt64(0),
    Dict{ElementPath,Vector{PositionalChildSnapshot}}(),
)

"""Return a snapshot of the retained state's bounded reconciliation history."""
reconciliation_records(state::ToolkitState) = copy(state.reconciliation.records)

"""Discard reconciliation history without changing retained element state."""
function clear_reconciliation_trace!(state::ToolkitState)
    empty!(state.reconciliation.records)
    return state
end

"""Return positional identity hazards observed while reconciling retained children."""
positional_identity_warning_records(state::ToolkitState) =
    copy(state.positional_warnings)

"""Discard positional identity warnings without changing retained state."""
function clear_positional_identity_warnings!(state::ToolkitState)
    empty!(state.positional_warnings)
    return state
end

function _record_positional_warning!(
    state::ToolkitState,
    parent::ElementPath,
    change::Symbol,
    previous_count::Int,
    count::Int,
    affected_indices::Vector{Int},
    reason::Symbol,
)
    state.positional_identity_warnings || return nothing
    capacity = state.reconciliation.capacity
    capacity == 0 && return nothing
    state.positional_warning_sequence == typemax(UInt64) &&
        throw(OverflowError("positional identity warning sequence exhausted"))
    state.positional_warning_sequence += UInt64(1)
    push!(state.positional_warnings, PositionalIdentityWarning(
        state.positional_warning_sequence,
        element_path_components(parent),
        change,
        previous_count,
        count,
        affected_indices,
        reason,
    ))
    length(state.positional_warnings) > capacity && popfirst!(state.positional_warnings)
    return nothing
end

function _record_reconciliation!(
    state::ToolkitState,
    action::ReconciliationAction,
    path::ElementPath,
    element;
    previous_signature=nothing,
    signature=nothing,
    previous_index=nothing,
    index=nothing,
    reason::Symbol,
)
    trace = state.reconciliation
    trace.capacity == 0 && return nothing
    trace.sequence == typemax(UInt64) && throw(OverflowError("reconciliation sequence exhausted"))
    trace.sequence += UInt64(1)
    push!(trace.records, ReconciliationRecord(
        trace.sequence,
        action,
        element_path_components(path),
        element.id,
        element.key,
        previous_signature,
        signature,
        previous_index,
        index,
        reason,
    ))
    length(trace.records) > trace.capacity && popfirst!(trace.records)
    return nothing
end

"""Return whether retained component state has requested another render."""
toolkit_invalidated(state::ToolkitState) = lock(state.invalidation_lock) do
    state.invalidation_pending
end

pointer_capture_target(state::ToolkitState) = state.pointer_capture
has_pointer_capture(state::ToolkitState) = state.pointer_capture !== nothing

function _pointer_capture_path(state::ToolkitState, target=state.pointer_capture)
    target === nothing && return nothing
    if target isa ElementPath
        return haskey(state.instances, target) ? target : nothing
    end
    return get(state.ids, target, nothing)
end

"""Capture subsequent pointer motion and release for a rendered element."""
function capture_pointer!(state::ToolkitState, target)
    path = _pointer_capture_path(state, target)
    path === nothing && return false
    instance = state.instances[path]
    (instance.hidden || instance.element.disabled || isempty(instance.area)) && return false
    state.pointer_capture = target
    return true
end

"""Release the current pointer capture, optionally only for one owner."""
function release_pointer!(state::ToolkitState, target=nothing)
    state.pointer_capture === nothing && return false
    target === nothing || isequal(state.pointer_capture, target) || return false
    state.pointer_capture = nothing
    return true
end

"""Coalesce a redraw request and notify the attached runtime when appropriate."""
function invalidate_toolkit!(state::ToolkitState)
    invalidator = lock(state.invalidation_lock) do
        was_pending = state.invalidation_pending
        state.invalidation_pending = true
        !was_pending && state.dispatch_depth == 0 ? state.invalidator : nothing
    end
    invalidator === nothing || invalidator()
    return state
end

"""Acknowledge a retained tree's pending redraw request."""
function clear_toolkit_invalidation!(state::ToolkitState)
    lock(state.invalidation_lock) do
        state.invalidation_pending = false
    end
    return state
end

"""A declarative root plus the persistent state required to render and dispatch it."""
mutable struct ToolkitTree
    root::Element
    state::ToolkitState
end

ToolkitTree(
    root::Element;
    styles::StyleEngine=StyleEngine(),
    reconciliation_capacity::Integer=1024,
    positional_identity_warnings::Bool=true,
) = ToolkitTree(root, ToolkitState(; styles, reconciliation_capacity, positional_identity_warnings))

reconciliation_records(tree::ToolkitTree) = reconciliation_records(tree.state)
clear_reconciliation_trace!(tree::ToolkitTree) =
    (clear_reconciliation_trace!(tree.state); tree)
positional_identity_warning_records(tree::ToolkitTree) =
    positional_identity_warning_records(tree.state)
clear_positional_identity_warnings!(tree::ToolkitTree) =
    (clear_positional_identity_warnings!(tree.state); tree)

pointer_capture_target(tree::ToolkitTree) = pointer_capture_target(tree.state)
has_pointer_capture(tree::ToolkitTree) = has_pointer_capture(tree.state)
capture_pointer!(tree::ToolkitTree, target) = capture_pointer!(tree.state, target)
release_pointer!(tree::ToolkitTree, target=nothing) = release_pointer!(tree.state, target)

"""Request focus for an attached declarative `FocusRequester`.

Returns `false` when the requester is unattached, has not been rendered in the
active focus scope, or targets a disabled, hidden, or empty element.
"""
function request_focus!(state::ToolkitState, requester::FocusRequester)
    target = requester.target
    target === nothing && return false
    before = focused(state.focus)
    focus!(state.focus, target) || return false
    changed = !isequal(before, focused(state.focus))
    changed && invalidate_toolkit!(state)
    return true
end

request_focus!(tree::ToolkitTree, requester::FocusRequester) =
    request_focus!(tree.state, requester)

"""Return whether an attached requester currently owns focus."""
focus_requester_focused(state::ToolkitState, requester::FocusRequester) =
    requester.target !== nothing && isequal(focused(state.focus), requester.target)

focus_requester_focused(tree::ToolkitTree, requester::FocusRequester) =
    focus_requester_focused(tree.state, requester)

"""Clear focus only when it is currently owned by this requester."""
function release_focus!(state::ToolkitState, requester::FocusRequester)
    focus_requester_focused(state, requester) || return false
    clear_focus!(state.focus)
    invalidate_toolkit!(state)
    return true
end

release_focus!(tree::ToolkitTree, requester::FocusRequester) =
    release_focus!(tree.state, requester)

toolkit_invalidated(tree::ToolkitTree) = toolkit_invalidated(tree.state)
invalidate_toolkit!(tree::ToolkitTree) = (invalidate_toolkit!(tree.state); tree)
clear_toolkit_invalidation!(tree::ToolkitTree) = (clear_toolkit_invalidation!(tree.state); tree)

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
    instance.state isa ComponentState && _set_component_invalidator!(instance.state, nothing)
    instance.state isa ComponentErrorBoundaryState && (instance.state.invalidator = nothing)
    try
        instance.element.on_unmount(instance.state)
    finally
        try
            if instance.state isa ComponentState
                clear_component_effects!(instance.state)
            end
        finally
            if instance.state isa ComponentState
                lock(instance.state.lock) do
                    empty!(instance.state.composition)
                    for remembered in values(instance.state.remembered)
                        lock(remembered.lock) do
                            remembered.invalidator = nothing
                            remembered.on_change = nothing
                        end
                    end
                    empty!(instance.state.remembered)
                end
            end
            instance.mounted = false
        end
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
    index::Int,
)
    signature = _signature(element)
    if haskey(state.instances, path)
        instance = state.instances[path]
        previous_index = get(state.sibling_indices, path, nothing)
        if path.component[1] === :key && previous_index !== nothing && previous_index != index
            _record_reconciliation!(
                state, ReconciliationMove, path, element;
                previous_signature=instance.signature,
                signature,
                previous_index,
                index,
                reason=:keyed_sibling_index_changed,
            )
        end
        if instance.signature != signature
            previous_signature = instance.signature
            delete!(state.instances, path)
            _unmount!(instance)
            instance = _mount_instance(element, area, parent, hidden)
            state.instances[path] = instance
            _record_reconciliation!(
                state, ReconciliationReplace, path, element;
                previous_signature,
                signature,
                previous_index,
                index,
                reason=:signature_changed,
            )
        else
            instance.element = element
            instance.area = area
            instance.parent = parent
            instance.hidden = hidden
            _record_reconciliation!(
                state, ReconciliationReuse, path, element;
                previous_signature=signature,
                signature,
                previous_index,
                index,
                reason=:identity_and_signature_matched,
            )
        end
    else
        state.instances[path] = _mount_instance(element, area, parent, hidden)
        _record_reconciliation!(
            state, ReconciliationMount, path, element;
            signature,
            index,
            reason=:new_identity,
        )
    end
    state.sibling_indices[path] = index
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
    state = instance.state isa BoundWidgetState ? instance.state.inner : instance.state
    if !isnothing(state) && ismutabletype(typeof(state)) && hasproperty(state, :focused)
        current = getproperty(state, :focused)
        current isa Bool && setproperty!(state, :focused, focused_value)
    end
    nothing
end

function _render_widget!(frame::Frame, instance::ElementInstance)
    element = instance.element
    isnothing(element.widget) && return
    element.widget isa StatefulComponent && return
    element.widget isa ContextProvider && return
    element.widget isa ComponentErrorBoundary && return
    state = instance.state
    if state isa BoundWidgetState
        _apply_bound_value!(state)
        state = state.inner
    end
    if isnothing(state)
        render!(frame, element.widget, instance.area)
    else
        render!(frame, element.widget, instance.area, state)
    end
end

function _pseudo_states(toolkit::ToolkitState, path::ElementPath, instance::ElementInstance)
    element = instance.element
    values = Set{Symbol}()
    element.disabled && push!(values, :disabled)
    element.hidden && push!(values, :hidden)
    target = isnothing(element.id) ? path : element.id
    focused(toolkit.focus) == target && push!(values, :focus)
    state = instance.state isa BoundWidgetState ? instance.state.inner : instance.state
    if !isnothing(state)
        hasproperty(state, :checked) && getproperty(state, :checked) && push!(values, :checked)
        if hasproperty(state, :selected)
            selected = getproperty(state, :selected)
            (selected isa Bool ? selected : !isnothing(selected)) && push!(values, :selected)
        end
        hasproperty(state, :open) && getproperty(state, :open) && push!(values, :open)
        hasproperty(state, :pressed) && getproperty(state, :pressed) && push!(values, :pressed)
        hasproperty(state, :hovered) && getproperty(state, :hovered) && push!(values, :hover)
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

function _child_areas(element::Element, area::Rect, count::Integer=length(element.children))
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

function _child_areas_retained!(
    state::ToolkitState,
    path::ElementPath,
    element::Element,
    area::Rect,
    count::Int,
)
    layout = element.layout
    if !(layout isa FlexLayout)
        delete!(state.flex_area_cache, path)
        return _child_areas(element, area, count)
    end
    cached = get(state.flex_area_cache, path, nothing)
    if cached !== nothing &&
       cached.direction == layout.direction &&
       cached.constraints == layout.constraints &&
       cached.margin == layout.margin &&
       cached.gap == layout.gap &&
       cached.alignment == layout.alignment &&
       cached.area == area &&
       cached.count == count
        return cached.regions
    end
    regions = resolve(layout, area)
    state.flex_area_cache[path] = FlexAreaCache(
        layout.direction,
        copy(layout.constraints),
        layout.margin,
        layout.gap,
        layout.alignment,
        area,
        count,
        regions,
    )
    return regions
end

function _component_children!(toolkit::ToolkitState, instance::ElementInstance)
    widget = instance.element.widget
    widget isa StatefulComponent || return instance.element.children
    state = instance.state
    state isa ComponentState ||
        throw(ArgumentError("component state_factory must return ComponentState"))
    lock(state.lock) do
        empty!(state.composition)
        merge!(state.composition, toolkit.composition)
        state.composition[ComponentAreaLocal] = instance.area
    end
    _set_component_invalidator!(state, () -> invalidate_toolkit!(toolkit))
    clear_component_invalidation!(state)
    _begin_component_effects!(state)
    _begin_component_remembered!(state)
    applicable(widget.view, state) ||
        throw(ArgumentError("component view must accept ComponentState"))
    output = widget.view(state)
    children = _normalize_elements((output,))
    _validate_sibling_keys(children)
    dynamic_ids = Set{Any}()
    for child in children
        _validate_tree!(child, dynamic_ids)
    end
    _finish_component_remembered!(state)
    any(candidate -> candidate === state, toolkit.pending_component_effects) ||
        push!(toolkit.pending_component_effects, state)
    return children
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

function _validation_keys!(key_sets::Vector{Set{Any}}, depth::Int)
    while length(key_sets) < depth
        push!(key_sets, Set{Any}())
    end
    keys = key_sets[depth]
    empty!(keys)
    return keys
end

function _validate_tree_retained!(
    element::Element,
    ids::Set{Any},
    key_sets::Vector{Set{Any}},
    depth::Int=1,
)
    if !isnothing(element.id)
        element.id in ids && throw(ArgumentError("duplicate element ID: $(element.id)"))
        push!(ids, element.id)
    end
    keys = _validation_keys!(key_sets, depth)
    for child in element.children
        isnothing(child.key) && continue
        child.key in keys && throw(ArgumentError("duplicate sibling element key: $(child.key)"))
        push!(keys, child.key)
    end
    for child in element.children
        child isa Element || throw(ArgumentError("element children must be Element values"))
        _validate_tree_retained!(child, ids, key_sets, depth + 1)
    end
    return element
end

function _validate_tree_retained!(state::ToolkitState, element::Element)
    empty!(state.validation_ids)
    return _validate_tree_retained!(element, state.validation_ids, state.validation_keys)
end

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
    instance = _instance!(state, path, element, area, parent, hidden, index)
    _register_identity!(state, path, instance)
    target = isnothing(element.id) ? path : element.id
    _set_focus_state!(instance, !hidden && element.focusable && focused(state.focus) == target)
    if !hidden
        _render_widget!(frame, instance)
        _apply_element_style!(frame, state, path, instance)
    end
    children = _component_children!(state, instance)
    provider = element.widget isa ContextProvider ? element.widget : nothing
    previous = Pair{Any,Any}[]
    missing = Set{Any}()
    if provider !== nothing
        for binding in provider.bindings
            local_value = first(binding)
            if haskey(state.composition, local_value)
                push!(previous, local_value => state.composition[local_value])
            else
                push!(missing, local_value)
            end
            state.composition[local_value] = last(binding)
        end
    end
    try
        if element.widget isa ComponentErrorBoundary
            _render_error_boundary_children!(
                frame,
                state,
                instance,
                children,
                area,
                path,
                hidden,
            )
        else
            _render_children!(frame, state, element, children, area, path, hidden)
        end
    finally
        if provider !== nothing
            for local_value in missing
                delete!(state.composition, local_value)
            end
            for binding in previous
                state.composition[first(binding)] = last(binding)
            end
        end
    end
    nothing
end

function _render_children!(frame, state, element, children, area, path, hidden)
    _diagnose_positional_children!(state, path, children)
    for (child_index, child_area, child) in
        zip(
            eachindex(children),
            _child_areas_retained!(state, path, element, area, length(children)),
            children,
        )
        _render_element!(frame, state, child, child_area, path, child_index, hidden)
    end
    _snapshot_positional_children!(state, path, children)
    return nothing
end

function _positional_child_descriptions(children)
    return [
        (index=index, element=child)
        for (index, child) in pairs(children)
        if child.key === nothing
    ]
end

function _diagnose_positional_children!(state::ToolkitState, parent::ElementPath, children)
    state.positional_identity_warnings || return nothing
    previous = get(state.positional_children, parent, nothing)
    previous === nothing && return nothing
    current = _positional_child_descriptions(children)
    previous_indices = [child.index for child in previous]
    current_indices = [child.index for child in current]
    previous_ids = [child.element_id for child in previous]
    current_ids = [child.element.id for child in current]

    change = if length(current) > length(previous)
        :insertion
    elseif length(current) < length(previous)
        :removal
    elseif previous_indices != current_indices
        :insertion_or_removal
    elseif !isempty(previous) &&
           all(value -> !isnothing(value), previous_ids) &&
           all(value -> !isnothing(value), current_ids) &&
           Set(previous_ids) == Set(current_ids) &&
           previous_ids != current_ids
        :reorder
    else
        nothing
    end
    change === nothing && return nothing
    affected = [child.index for child in previous if child.stateful]
    isempty(affected) && return nothing
    reason = change === :reorder ? :stateful_positional_children_reordered_without_keys :
             change === :insertion ? :stateful_positional_children_shifted_by_insertion :
             change === :removal ? :stateful_positional_children_shifted_by_removal :
             :stateful_positional_children_shifted_by_keyed_change
    _record_positional_warning!(
        state,
        parent,
        change,
        length(previous),
        length(current),
        affected,
        reason,
    )
    return nothing
end

function _snapshot_positional_children!(state::ToolkitState, parent::ElementPath, children)
    snapshots = PositionalChildSnapshot[]
    for (index, child) in pairs(children)
        child.key === nothing || continue
        child_path = get(parent.children, (:position, index), nothing)
        instance = child_path === nothing ? nothing : get(state.instances, child_path, nothing)
        push!(snapshots, PositionalChildSnapshot(
            index,
            child.id,
            _signature(child),
            instance !== nothing && instance.state !== nothing,
        ))
    end
    state.positional_children[parent] = snapshots
    return nothing
end

function _is_descendant_path(candidate::ElementPath, ancestor::ElementPath)
    current = candidate.parent
    while current !== nothing
        current === ancestor && return true
        current = current.parent
    end
    return false
end

function _remove_boundary_descendants!(toolkit::ToolkitState, path::ElementPath)
    removed = ElementPath[
        candidate for candidate in keys(toolkit.instances)
        if _is_descendant_path(candidate, path)
    ]
    sort!(removed; by=candidate -> candidate.depth, rev=true)
    for candidate in removed
        instance = pop!(toolkit.instances, candidate)
        try
            _record_reconciliation!(
                toolkit, ReconciliationUnmount, candidate, instance.element;
                previous_signature=instance.signature,
                previous_index=get(toolkit.sibling_indices, candidate, nothing),
                reason=:error_boundary_rollback,
            )
            _unmount!(instance)
        finally
            siblings = candidate.parent.children
            get(siblings, candidate.component, nothing) === candidate &&
                delete!(siblings, candidate.component)
            empty!(candidate.children)
            delete!(toolkit.seen, candidate)
            delete!(toolkit.flex_area_cache, candidate)
            delete!(toolkit.sibling_indices, candidate)
            delete!(toolkit.positional_children, candidate)
        end
    end
    return nothing
end

function _invoke_boundary_fallback(boundary::ComponentErrorBoundary, failure, state)
    fallback = boundary.fallback
    applicable(fallback, failure, state) && return fallback(failure, state)
    applicable(fallback, failure) && return fallback(failure)
    applicable(fallback, failure.ex) && return fallback(failure.ex)
    applicable(fallback) && return fallback()
    return fallback
end

function _notify_boundary_error(boundary::ComponentErrorBoundary, failure, state)
    callback = boundary.on_error
    if applicable(callback, failure, state)
        callback(failure, state)
    elseif applicable(callback, failure)
        callback(failure)
    elseif applicable(callback, failure.ex)
        callback(failure.ex)
    elseif applicable(callback)
        callback()
    else
        throw(ArgumentError("error boundary callback must accept failure/state, failure, exception, or no arguments"))
    end
    return nothing
end

function _boundary_fallback_children(boundary, boundary_state)
    output = _invoke_boundary_fallback(boundary, boundary_state.failure, boundary_state)
    children = _normalize_elements((output,))
    _validate_sibling_keys(children)
    ids = Set{Any}()
    for child in children
        _validate_tree!(child, ids)
    end
    return children
end

function _render_error_boundary_children!(frame, toolkit, instance, children, area, path, hidden)
    boundary = instance.element.widget
    boundary_state = instance.state
    boundary_state isa ComponentErrorBoundaryState ||
        throw(ArgumentError("error boundary state_factory must return ComponentErrorBoundaryState"))
    boundary_state.invalidator = () -> invalidate_toolkit!(toolkit)
    if !isequal(boundary_state.reset_key, boundary.reset_key)
        boundary_state.reset_key = boundary.reset_key
        boundary_state.failure = nothing
    end
    if boundary_state.failure !== nothing
        fallback = _boundary_fallback_children(boundary, boundary_state)
        return _render_children!(frame, toolkit, instance.element, fallback, area, path, hidden)
    end

    buffer_cells = copy(frame.buffer.cells)
    cursor = frame.cursor
    seen = copy(toolkit.seen)
    paint_length = length(toolkit.paint_order)
    ids = copy(toolkit.ids)
    focus_targets = copy(toolkit.focus_targets)
    focus_length = length(toolkit.focus.entries)
    pending_length = length(toolkit.pending_component_effects)
    try
        return _render_children!(frame, toolkit, instance.element, children, area, path, hidden)
    catch error
        failure = CapturedException(error, catch_backtrace())
        frame.buffer.cells = buffer_cells
        frame.cursor = cursor
        empty!(toolkit.seen)
        union!(toolkit.seen, seen)
        resize!(toolkit.paint_order, paint_length)
        empty!(toolkit.ids)
        merge!(toolkit.ids, ids)
        empty!(toolkit.focus_targets)
        merge!(toolkit.focus_targets, focus_targets)
        resize!(toolkit.focus.entries, focus_length)
        resize!(toolkit.pending_component_effects, pending_length)
        _remove_boundary_descendants!(toolkit, path)
        boundary_state.failure = failure
        boundary_state.failure_count += UInt64(1)
        _notify_boundary_error(boundary, failure, boundary_state)
        fallback = _boundary_fallback_children(boundary, boundary_state)
        return _render_children!(frame, toolkit, instance.element, fallback, area, path, hidden)
    end
end

function _prune!(state::ToolkitState)
    removed = ElementPath[path for path in keys(state.instances) if !(path in state.seen)]
    sort!(removed; by=path -> path.depth, rev=true)
    for path in removed
        instance = pop!(state.instances, path)
        try
            _record_reconciliation!(
                state, ReconciliationUnmount, path, instance.element;
                previous_signature=instance.signature,
                previous_index=get(state.sibling_indices, path, nothing),
                reason=:not_seen,
            )
            _unmount!(instance)
        finally
            siblings = path.parent === nothing ? state.roots : path.parent.children
            get(siblings, path.component, nothing) === path && delete!(siblings, path.component)
            empty!(path.children)
            delete!(state.flex_area_cache, path)
            delete!(state.sibling_indices, path)
            delete!(state.positional_children, path)
        end
    end
    has_pointer_capture(state) && _pointer_capture_path(state) === nothing &&
        release_pointer!(state)
    nothing
end

"""Reconcile and render a complete declarative element tree."""
function render_toolkit!(frame::Frame, tree::ToolkitTree, area::Rect=frame.area)
    state = tree.state
    clear_toolkit_invalidation!(state)
    _validate_tree_retained!(state, tree.root)
    empty!(state.ids)
    empty!(state.focus_targets)
    empty!(state.paint_order)
    empty!(state.seen)
    empty!(state.pending_component_effects)
    empty!(state.composition)
    begin_focus_frame!(state.focus)
    _render_element!(frame, state, tree.root, area, nothing, 1)
    _prune!(state)
    for component_state in state.pending_component_effects
        _commit_component_effects!(component_state)
    end
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

"""Render an element description once with ephemeral retained state.

Wrap the element in `ToolkitTree` when state, focus, or lifecycle identity must
survive across frames. This bridge lets declarative layout values participate in
the same immediate rendering paths as ordinary widgets.
"""
function render_toolkit!(frame::Frame, element::Element, area::Rect=frame.area)
    tree = ToolkitTree(element)
    try
        return render_toolkit!(frame, tree, area)
    finally
        empty!(tree.state.seen)
        _prune!(tree.state)
    end
end

render!(frame::Frame, tree::ToolkitTree, area::Rect) = render_toolkit!(frame, tree, area)
render!(buffer::Buffer, tree::ToolkitTree, area::Rect) =
    render_toolkit!(Frame(buffer), tree, area)
render!(frame::Frame, element::Element, area::Rect) = render_toolkit!(frame, element, area)
render!(buffer::Buffer, element::Element, area::Rect) =
    render_toolkit!(Frame(buffer), element, area)

@enum EventPhase::UInt8 begin
    TargetPhase
    BubblePhase
    CapturePhase
end

"""Migration alias for frameworks that use `target_phase` naming."""
const target_phase::EventPhase = TargetPhase

"""Root-to-target capture phase for declarative routed events."""
const capture_phase::EventPhase = CapturePhase

"""Migration alias for frameworks that use `bubble_phase` naming."""
const bubble_phase::EventPhase = BubblePhase

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
    pointer_capture::Any
end

"""Explicit batch of application messages emitted by one routed callback."""
struct EventMessages
    values::Vector{Any}

    EventMessages(values::Vector{Any}) = new(values)
end

EventMessages(values) = EventMessages(Any[value for value in values if value !== nothing])
event_messages(values...) = EventMessages(values)

EventResponse(;
    consumed::Bool=false,
    stop_propagation::Bool=false,
    redraw::Bool=consumed,
    message=nothing,
    focus=nothing,
    pointer_capture=nothing,
) = EventResponse(consumed, stop_propagation, redraw, message, focus, pointer_capture)

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
        if event.action != MousePress && has_pointer_capture(state)
            captured = _pointer_capture_path(state)
            if captured !== nothing
                return captured
            end
            release_pointer!(state)
        end
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

_hover_transition_message(widget, state, hovered::Bool) = nothing

function _hover_ancestry(state::ToolkitState, path, event::MouseEvent)
    path === nothing && return Set{ElementPath}()
    instance = state.instances[path]
    contains(instance.area, event.position) || return Set{ElementPath}()
    ancestry = Set{ElementPath}()
    current = path
    while current !== nothing
        push!(ancestry, current)
        current = state.instances[current].parent
    end
    return ancestry
end

"""Synchronize Boolean `hovered` state across the routed pointer ancestry."""
function _update_hover_states!(state::ToolkitState, path, event::MouseEvent)
    ancestry = _hover_ancestry(state, path, event)
    changed = false
    messages = Any[]
    for (candidate, instance) in state.instances
        instance_state = instance.state isa BoundWidgetState ? instance.state.inner : instance.state
        instance_state === nothing && continue
        ismutabletype(typeof(instance_state)) || continue
        hasproperty(instance_state, :hovered) || continue
        current = getproperty(instance_state, :hovered)
        current isa Bool || continue
        hovered = candidate in ancestry && !instance.hidden && !instance.element.disabled
        current == hovered && continue
        setproperty!(instance_state, :hovered, hovered)
        changed = true
        message = _hover_transition_message(instance.element.widget, instance_state, hovered)
        message === nothing || push!(messages, message)
    end
    if event.action in (MousePress, MouseRelease)
        for (candidate, instance) in state.instances
            candidate in ancestry && continue
            instance_state = instance.state isa BoundWidgetState ? instance.state.inner : instance.state
            instance_state === nothing && continue
            ismutabletype(typeof(instance_state)) || continue
            hasproperty(instance_state, :pressed) || continue
            pressed = getproperty(instance_state, :pressed)
            pressed isa Bool && pressed || continue
            setproperty!(instance_state, :pressed, false)
            if hasproperty(instance_state, :pressed_at_ns)
                setproperty!(instance_state, :pressed_at_ns, nothing)
            end
            changed = true
        end
    end
    return changed, messages
end

_automatic_mouse_activation(widget) = true

function _activation_message(instance::ElementInstance, event::AbstractEvent)
    widget = instance.element.widget
    state = instance.state isa BoundWidgetState ? instance.state.inner : instance.state
    isnothing(widget) && return nothing
    activated = (event isa KeyEvent &&
        (event.key.code in (:enter, :space) || (event.key.code == :character && event.text == " "))) ||
        (event isa MouseEvent && event.action == MouseRelease && _automatic_mouse_activation(widget))
    activated && applicable(activate, widget, state) ? activate(widget, state) : nothing
end

function _builtin!(instance::ElementInstance, event::AbstractEvent)
    widget = instance.element.widget
    retained_state = instance.state
    state = retained_state isa BoundWidgetState ? retained_state.inner : retained_state
    isnothing(widget) && return EventResponse()
    handled = if !isnothing(state) && applicable(handle!, state, widget, event, instance.area)
        handle!(state, widget, event, instance.area)
    elseif !isnothing(state) && applicable(handle!, state, widget, event)
        handle!(state, widget, event)
    else
        false
    end
    handled && retained_state isa BoundWidgetState && _publish_bound_value!(retained_state)
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

"""Construct a push-screen command."""
push_screen(screen::Screen) = PushScreen(screen)

struct PushRegisteredScreen{R<:ScreenRegistry,K}
    registry::R
    id::K
end

"""Construct a push-registered-screen command."""
push_registered_screen(registry::ScreenRegistry, id) = PushRegisteredScreen(registry, id)

struct NavigateRegisteredScreen{R<:ScreenRegistry,K}
    registry::R
    id::K
    replace::Any
    record_history::Bool
end

"""Construct a navigate-registered-screen command."""
navigate_registered_screen(registry::ScreenRegistry, id; replace=nothing, record_history::Bool=true) =
    NavigateRegisteredScreen(registry, id; replace=replace, record_history=record_history)

NavigateRegisteredScreen(registry::ScreenRegistry, id; replace=nothing, record_history::Bool=true) =
    NavigateRegisteredScreen{typeof(registry),typeof(id)}(registry, id, replace, record_history)

struct PopScreen end

"""Construct a pop-screen command."""
pop_screen() = PopScreen()

struct BackRegisteredScreen{R<:ScreenRegistry}
    registry::R
    replace::Bool
end

BackRegisteredScreen(registry::ScreenRegistry; replace::Bool=true) =
    BackRegisteredScreen{typeof(registry)}(registry, replace)

"""Construct a back-registered-screen command."""
back_registered_screen(registry::ScreenRegistry; replace::Bool=true) =
    BackRegisteredScreen(registry; replace=replace)

struct ForwardRegisteredScreen{R<:ScreenRegistry}
    registry::R
    replace::Bool
end

ForwardRegisteredScreen(registry::ScreenRegistry; replace::Bool=true) =
    ForwardRegisteredScreen{typeof(registry)}(registry, replace)

"""Construct a forward-registered-screen command."""
forward_registered_screen(registry::ScreenRegistry; replace::Bool=true) =
    ForwardRegisteredScreen(registry; replace=replace)

struct ReplaceWithScreen{S<:Screen}
    screen::S
end

"""Construct a replace-screen command."""
replace_with_screen(screen::Screen) = ReplaceWithScreen(screen)

struct ReplaceWithRegisteredScreen{R<:ScreenRegistry,K}
    registry::R
    id::K
end

"""Construct a replace-registered-screen command."""
replace_with_registered_screen(registry::ScreenRegistry, id) =
    ReplaceWithRegisteredScreen(registry, id)

struct PopToScreen{K}
    id::K
    inclusive::Bool
end

PopToScreen(id; inclusive::Bool=false) =
    PopToScreen{typeof(id)}(id, inclusive)

"""Construct a pop-to-screen command."""
pop_to_screen(id; inclusive::Bool=false) = PopToScreen(id; inclusive=inclusive)

struct RemoveScreen{K}
    id::K
end

"""Construct a remove-screen command."""
remove_screen(id) = RemoveScreen(id)

struct ClearOverlayScreens end

"""Construct a clear-overlay-screens command."""
clear_overlay_screens() = ClearOverlayScreens()

struct ClearScreens end

"""Construct a clear-screens command."""
clear_screens() = ClearScreens()

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

struct _ToolkitRedrawRequested end

function attach_runtime!(::ToolkitApp, model::ToolkitModel, runtime)
    lock(model.tree.state.invalidation_lock) do
        model.tree.state.invalidator = () -> post!(runtime, _ToolkitRedrawRequested())
    end
    return model
end

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
    if message isa _ToolkitRedrawRequested
        return FrameCommand()
    elseif message isa PushScreen
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
    if response.message isa EventMessages
        append!(messages, response.message.values)
    elseif !isnothing(response.message)
        push!(messages, response.message)
    end
    if response.pointer_capture === :release || response.pointer_capture === :none
        release_pointer!(toolkit)
    elseif response.pointer_capture !== nothing
        capture_pointer!(toolkit, response.pointer_capture)
    end
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

function _dispatch!(tree::ToolkitTree, event::AbstractEvent)
    state = tree.state
    path = _target_path(state, event)
    isnothing(path) && return DispatchResult(false, false, Any[])
    instance = state.instances[path]
    focus_target = isnothing(instance.element.id) ? path : instance.element.id
    event isa MouseEvent && event.action == MousePress && instance.element.focusable &&
        focus!(state.focus, focus_target)
    hover_changed, messages = event isa MouseEvent ?
        _update_hover_states!(state, path, event) : (false, Any[])
    focus_changed = false
    consumed = false
    redraw = hover_changed

    ancestors = ElementPath[]
    ancestor = instance.parent
    while ancestor !== nothing
        push!(ancestors, ancestor)
        ancestor = state.instances[ancestor].parent
    end
    for current_path in Iterators.reverse(ancestors)
        current = state.instances[current_path]
        current_target = isnothing(current.element.id) ? current_path : current.element.id
        routed = RoutedEvent(event, focus_target, current_target, CapturePhase)
        response = _normalize_response(current.element.on_capture(routed, current.state))
        response_focus_changed = _apply_response!(state, response, messages)
        focus_changed |= response_focus_changed
        consumed |= response.consumed
        redraw |= response.redraw || response_focus_changed
        response.stop_propagation && return DispatchResult(consumed, redraw, messages)
    end

    builtin = _builtin!(instance, event)
    builtin_focus_changed = _apply_response!(state, builtin, messages)
    focus_changed |= builtin_focus_changed
    consumed |= builtin.consumed
    redraw |= builtin.redraw || builtin_focus_changed

    current = instance
    current_target = isnothing(current.element.id) ? path : current.element.id
    routed = RoutedEvent(event, focus_target, current_target, TargetPhase)
    response = _normalize_response(current.element.on_event(routed, current.state))
    response_focus_changed = _apply_response!(state, response, messages)
    focus_changed |= response_focus_changed
    consumed |= response.consumed
    redraw |= response.redraw || response_focus_changed
    propagation_stopped = response.stop_propagation

    for current_path in ancestors
        propagation_stopped && break
        current = state.instances[current_path]
        current_target = isnothing(current.element.id) ? current_path : current.element.id
        routed = RoutedEvent(event, focus_target, current_target, BubblePhase)
        response = _normalize_response(current.element.on_event(routed, current.state))
        response_focus_changed = _apply_response!(state, response, messages)
        focus_changed |= response_focus_changed
        consumed |= response.consumed
        redraw |= response.redraw || response_focus_changed
        propagation_stopped = response.stop_propagation
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

"""Route an event to its target and then through ancestor elements."""
function dispatch!(tree::ToolkitTree, event::AbstractEvent)
    state = tree.state
    lock(state.invalidation_lock) do
        state.dispatch_depth += 1
    end
    result = try
        _dispatch!(tree, event)
    finally
        event isa MouseEvent && event.action == MouseRelease && release_pointer!(state)
        lock(state.invalidation_lock) do
            state.dispatch_depth -= 1
        end
    end
    return DispatchResult(result.consumed, result.redraw || toolkit_invalidated(state), result.messages)
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

export @ui,
       BubblePhase,
       CapturePhase,
       bubble_phase,
       capture_phase,
       capture_pointer!,
       DispatchResult,
       ComponentState,
       ComponentSlots,
       CompositionLocal,
       FocusRequester,
       ContextProvider,
       ComponentErrorBoundary,
       ComponentErrorBoundaryState,
       ErrorBoundaryState,
       RememberedValue,
       ProducedState,
       produce_state!,
       produced_value,
       produced_version,
       produced_status,
       produced_failure,
       produced_running,
       produced_succeeded,
       produced_failed,
       AbstractStateBinding,
       StateBinding,
       RememberedStateBinding,
       BoundWidgetState,
       binding_value,
       bound_element,
       bound_property_element,
       bound_widget_state,
       map_binding,
       remember_binding!,
       set_binding_value!,
       state_binding,
       update_binding_value!,
       AsyncResource,
       AsyncResourceStatus,
       AsyncResourceToken,
       ResourceIdle,
       ResourceLoading,
       ResourceSuccess,
       ResourceFailure,
       async_resource_component,
       cancel_async_resource!,
       load_async_resource!,
       resource_cancelled,
       resource_content,
       resource_failed,
       resource_failure,
       resource_generation,
       resource_loading,
       resource_status,
       resource_succeeded,
       resource_value,
       retry_async_resource!,
       throw_if_resource_cancelled,
       use_resource!,
       clear_component_invalidation!,
       clear_toolkit_invalidation!,
       component_invalidated,
       component_slots,
       component_version,
       composition_local,
       composition_value,
       boundary_failed,
       boundary_failure,
       derived_remember!,
       Element,
       ElementModifier,
       ElementSignature,
       ElementPath,
       ElementInstance,
       ReconciliationAction,
       ReconciliationMount,
       ReconciliationReuse,
       ReconciliationReplace,
       ReconciliationMove,
       ReconciliationUnmount,
       ReconciliationRecord,
       ReconciliationTrace,
       PositionalIdentityWarning,
       reconciliation_records,
       clear_reconciliation_trace!,
       positional_identity_warning_records,
       clear_positional_identity_warnings!,
       EventPhase,
       EventMessages,
       event_messages,
       target_phase,
       EventResponse,
       RoutedEvent,
       TargetPhase,
       ToolkitState,
       ToolkitTree,
       invalidate_component!,
       invalidate_toolkit!,
       toolkit_invalidated,
       ToolkitApp,
       ToolkitModel,
       StatefulComponent,
       clear_component_effects!,
       component,
       component_value,
       keyed,
       keyed_each,
       focus_requester,
       focus_requester_focused,
       focus_requester_target,
       has_slot,
       has_pointer_capture,
       element_modifier,
       error_boundary,
       modify,
       provide_context,
       pointer_capture_target,
       remember!,
       release_pointer!,
       release_focus!,
       request_focus!,
       remembered_value,
       remembered_version,
       retry_error_boundary!,
       set_component_value!,
       set_remembered_value!,
       then,
       update_component_value!,
       update_remembered_value!,
       use_effect!,
       slot,
       slot_names,
       Screen,
       ScreenMode,
       ScreenRegistry,
       ScreenRouteMetadata,
       ScreenHistory,
       ScreenStack,
       OverlayScreen,
       back_registered_screen,
       forward_registered_screen,
       clear_overlay_screens,
       clear_screens,
       ClearOverlayScreens,
       ClearScreens,
       PopScreen,
       pop_screen,
       PopToScreen,
       pop_to_screen,
       PushScreen,
       push_screen,
       PushRegisteredScreen,
       push_registered_screen,
       NavigateRegisteredScreen,
       navigate_registered_screen,
       BackRegisteredScreen,
       ForwardRegisteredScreen,
       ReplaceScreen,
       replace_with_screen,
       ReplaceWithScreen,
       replace_with_registered_screen,
       ReplaceWithRegisteredScreen,
       RemoveScreen,
       remove_screen,
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
       HBox,
       HStack,
       HSplit,
       VBox,
       VStack,
       VSplit,
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
       ZStack,
       vbox,
       vertical,
       vsplit,
       vstack,
       zstack,
       grid,
       element,
       fragment,
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
