module ReactiveToolkit

import ..Reactive: dispose!
using ..Reactive: ReactiveRuntime,
                  AbstractReactive,
                  Signal,
                  ComputedSignal,
                  ReactiveEffect,
                  ReactiveSubscription,
                  signal_value,
                  signal_version,
                  reactive_runtime,
                  set_signal!,
                  subscribe!,
                  unsubscribe!,
                  transaction!,
                  computed_signal,
                  reactive_effect!

export InvalidationKind,
       RenderInvalidation,
       LayoutInvalidation,
       StyleInvalidation,
       SemanticsInvalidation,
       SubscriptionInvalidation,
       ReactiveInvalidation,
       ReactiveInvalidationQueue,
       enqueue_invalidation!,
       take_invalidations!,
       pending_invalidations,
       clear_invalidations!,
       ReactiveComponentBinding,
       bind_component_signal!,
       bind_component_signals!,
       component_invalidations,
       ReactiveComponentState,
       component_signal!,
       component_signal,
       set_component_state!,
       component_state_value,
       computed_component_state!,
       component_effect!,
       transaction_component!,
       ReactiveElement,
       reactive_element,
       reactive_element_value!,
       invalidate_reactive_element!,
       ReactiveClassSet,
       bind_reactive_class!,
       unbind_reactive_class!,
       reactive_classes

@enum InvalidationKind begin
    RenderInvalidation
    LayoutInvalidation
    StyleInvalidation
    SemanticsInvalidation
    SubscriptionInvalidation
end

mutable struct ReactiveInvalidation
    component_id::String
    kinds::Set{InvalidationKind}
    maximum_version::UInt64
    timestamp_ns::UInt64
end

mutable struct ReactiveInvalidationQueue
    pending::Dict{String,ReactiveInvalidation}
    mutex::ReentrantLock
end

ReactiveInvalidationQueue() = ReactiveInvalidationQueue(
    Dict{String,ReactiveInvalidation}(),
    ReentrantLock(),
)

function enqueue_invalidation!(
    queue::ReactiveInvalidationQueue,
    component_id,
    kinds;
    version::Integer=0,
    timestamp_ns::Integer=time_ns(),
)
    0 <= version <= typemax(UInt64) || throw(ArgumentError("invalidation version must fit UInt64"))
    0 <= timestamp_ns <= typemax(UInt64) || throw(ArgumentError("invalidation timestamp must fit UInt64"))
    identifier = string(component_id)
    values = Set{InvalidationKind}(kinds)
    isempty(values) && return queue
    lock(queue.mutex) do
        existing = get(queue.pending, identifier, nothing)
        if existing === nothing
            queue.pending[identifier] = ReactiveInvalidation(
                identifier,
                values,
                UInt64(version),
                UInt64(timestamp_ns),
            )
        else
            union!(existing.kinds, values)
            existing.maximum_version = max(existing.maximum_version, UInt64(version))
            existing.timestamp_ns = max(existing.timestamp_ns, UInt64(timestamp_ns))
        end
    end
    return queue
end

function take_invalidations!(queue::ReactiveInvalidationQueue)
    return lock(queue.mutex) do
        result = sort!(
            ReactiveInvalidation[
                ReactiveInvalidation(
                    value.component_id,
                    copy(value.kinds),
                    value.maximum_version,
                    value.timestamp_ns,
                ) for value in values(queue.pending)
            ];
            by=value -> value.component_id,
        )
        empty!(queue.pending)
        return result
    end
end

pending_invalidations(queue::ReactiveInvalidationQueue) = lock(queue.mutex) do
    sort!(
        ReactiveInvalidation[
            ReactiveInvalidation(
                value.component_id,
                copy(value.kinds),
                value.maximum_version,
                value.timestamp_ns,
            ) for value in values(queue.pending)
        ];
        by=value -> value.component_id,
    )
end

function clear_invalidations!(queue::ReactiveInvalidationQueue)
    lock(queue.mutex) do
        empty!(queue.pending)
    end
    return queue
end

mutable struct ReactiveComponentBinding
    component_id::String
    queue::ReactiveInvalidationQueue
    subscriptions::Vector{ReactiveSubscription}
    disposed::Bool
end

ReactiveComponentBinding(
    component_id;
    queue::ReactiveInvalidationQueue=ReactiveInvalidationQueue(),
) = ReactiveComponentBinding(
    string(component_id),
    queue,
    ReactiveSubscription[],
    false,
)

function bind_component_signal!(
    binding::ReactiveComponentBinding,
    reactive::AbstractReactive;
    kinds=(RenderInvalidation,),
    immediate::Bool=false,
)
    binding.disposed && throw(ArgumentError("reactive component binding is disposed"))
    invalidation_kinds = Set{InvalidationKind}(kinds)
    subscription = subscribe!(reactive; immediate=immediate) do _, _, source
        enqueue_invalidation!(
            binding.queue,
            binding.component_id,
            invalidation_kinds;
            version=signal_version(source),
        )
    end
    push!(binding.subscriptions, subscription)
    return subscription
end

function bind_component_signals!(
    binding::ReactiveComponentBinding,
    reactives;
    kwargs...,
)
    return ReactiveSubscription[
        bind_component_signal!(binding, reactive; kwargs...) for reactive in reactives
    ]
end

component_invalidations(binding::ReactiveComponentBinding) =
    pending_invalidations(binding.queue)

function dispose!(binding::ReactiveComponentBinding)
    binding.disposed && return binding
    for subscription in binding.subscriptions
        unsubscribe!(subscription)
    end
    empty!(binding.subscriptions)
    binding.disposed = true
    return binding
end

mutable struct ReactiveComponentState
    runtime::ReactiveRuntime
    signals::Dict{Symbol,Any}
    computed::Dict{Symbol,ComputedSignal}
    effects::Vector{ReactiveEffect}
end

ReactiveComponentState(; runtime::ReactiveRuntime=ReactiveRuntime()) =
    ReactiveComponentState(
        runtime,
        Dict{Symbol,Any}(),
        Dict{Symbol,ComputedSignal}(),
        ReactiveEffect[],
    )

function component_signal!(
    state::ReactiveComponentState,
    name,
    value;
    kwargs...,
)
    identifier = Symbol(name)
    haskey(state.signals, identifier) &&
        throw(ArgumentError("component signal already exists: $identifier"))
    signal = Signal(value; runtime=state.runtime, name=string(identifier), kwargs...)
    state.signals[identifier] = signal
    return signal
end

function component_signal(state::ReactiveComponentState, name)
    identifier = Symbol(name)
    signal = get(state.signals, identifier, nothing)
    signal === nothing && (signal = get(state.computed, identifier, nothing))
    signal === nothing && throw(ArgumentError("unknown component signal: $identifier"))
    return signal
end

set_component_state!(state::ReactiveComponentState, name, value) =
    set_signal!(component_signal(state, name), value)

component_state_value(state::ReactiveComponentState, name) =
    signal_value(component_signal(state, name))

function computed_component_state!(
    state::ReactiveComponentState,
    name,
    dependencies,
    compute,
)
    identifier = Symbol(name)
    (haskey(state.signals, identifier) || haskey(state.computed, identifier)) &&
        throw(ArgumentError("component state already exists: $identifier"))
    resolved = AbstractReactive[
        dependency isa Symbol || dependency isa AbstractString ?
            component_signal(state, dependency) : dependency
        for dependency in dependencies
    ]
    value = computed_signal(
        compute,
        resolved;
        runtime=state.runtime,
        name=string(identifier),
    )
    state.computed[identifier] = value
    return value
end

function component_effect!(
    state::ReactiveComponentState,
    dependencies,
    operation;
    kwargs...,
)
    resolved = AbstractReactive[
        dependency isa Symbol || dependency isa AbstractString ?
            component_signal(state, dependency) : dependency
        for dependency in dependencies
    ]
    effect = reactive_effect!(operation, resolved; kwargs...)
    push!(state.effects, effect)
    return effect
end

transaction_component!(operation::F, state::ReactiveComponentState) where {F} =
    transaction!(() -> operation(state), state.runtime)

function dispose!(state::ReactiveComponentState)
    for value in values(state.computed)
        dispose!(value)
    end
    for effect in state.effects
        dispose!(effect)
    end
    empty!(state.computed)
    empty!(state.effects)
    return state
end

mutable struct ReactiveElement{F}
    component_id::String
    builder::F
    dependencies::Vector{Any}
    subscriptions::Vector{ReactiveSubscription}
    queue::ReactiveInvalidationQueue
    cached::Any
    dirty::Bool
    generation::UInt64
    invalidation_epoch::UInt64
    disposed::Bool
    mutex::ReentrantLock
end

function reactive_element(
    component_id,
    builder,
    dependencies::AbstractVector{<:AbstractReactive};
    queue::ReactiveInvalidationQueue=ReactiveInvalidationQueue(),
    kinds=(RenderInvalidation, SemanticsInvalidation),
)
    values = (signal_value(dependency) for dependency in dependencies)
    applicable(builder, values...) ||
        throw(ArgumentError("reactive element builder is not applicable to dependency values"))
    element = ReactiveElement{typeof(builder)}(
        string(component_id),
        builder,
        Any[dependency for dependency in dependencies],
        ReactiveSubscription[],
        queue,
        nothing,
        true,
        0,
        0,
        false,
        ReentrantLock(),
    )
    invalidation_kinds = Set{InvalidationKind}(kinds)
    for dependency in dependencies
        push!(element.subscriptions, subscribe!(dependency) do _, _, source
            should_enqueue = lock(element.mutex) do
                element.disposed && return false
                element.invalidation_epoch == typemax(UInt64) &&
                    throw(OverflowError("reactive element invalidation epoch overflow"))
                element.invalidation_epoch += 1
                element.dirty = true
                return true
            end
            should_enqueue || return
            enqueue_invalidation!(
                queue,
                element.component_id,
                invalidation_kinds;
                version=signal_version(source),
            )
        end)
    end
    return element
end

function reactive_element_value!(element::ReactiveElement)
    return lock(element.mutex) do
        element.disposed && throw(ArgumentError("reactive element is disposed"))
        element.dirty || return element.cached
        initial_epoch = element.invalidation_epoch
        values = (signal_value(dependency) for dependency in element.dependencies)
        value = element.builder(values...)
        element.generation == typemax(UInt64) &&
            throw(OverflowError("reactive element generation overflow"))
        element.cached = value
        element.generation += 1
        element.dirty = element.invalidation_epoch != initial_epoch
        return value
    end
end

function invalidate_reactive_element!(
    element::ReactiveElement;
    kinds=(RenderInvalidation,),
)
    generation = lock(element.mutex) do
        element.disposed && throw(ArgumentError("reactive element is disposed"))
        element.invalidation_epoch == typemax(UInt64) &&
            throw(OverflowError("reactive element invalidation epoch overflow"))
        element.invalidation_epoch += 1
        element.dirty = true
        element.generation
    end
    enqueue_invalidation!(
        element.queue,
        element.component_id,
        kinds;
        version=generation,
    )
    return element
end

function dispose!(element::ReactiveElement)
    subscriptions = lock(element.mutex) do
        element.disposed && return ReactiveSubscription[]
        values = copy(element.subscriptions)
        empty!(element.subscriptions)
        element.cached = nothing
        element.disposed = true
        values
    end
    for subscription in subscriptions
        unsubscribe!(subscription)
    end
    return element
end

struct ReactiveClassBinding{F}
    name::String
    reactive::Any
    predicate::F
    subscription::ReactiveSubscription
end

mutable struct ReactiveClassSet
    component_id::String
    classes::Set{String}
    bindings::Dict{String,ReactiveClassBinding}
    queue::ReactiveInvalidationQueue
    mutex::ReentrantLock
end

ReactiveClassSet(
    component_id;
    classes=String[],
    queue::ReactiveInvalidationQueue=ReactiveInvalidationQueue(),
) = ReactiveClassSet(
    string(component_id),
    Set{String}(String(value) for value in classes),
    Dict{String,ReactiveClassBinding}(),
    queue,
    ReentrantLock(),
)

function bind_reactive_class!(
    classes::ReactiveClassSet,
    name::AbstractString,
    reactive::AbstractReactive;
    predicate=Bool,
)
    identifier = String(name)
    applicable(predicate, signal_value(reactive)) ||
        throw(ArgumentError("reactive class predicate is not applicable"))
    function update(value; notify::Bool=true)
        enabled = Bool(predicate(value))
        changed = lock(classes.mutex) do
            changed_value = enabled ? !(identifier in classes.classes) : identifier in classes.classes
            enabled ? push!(classes.classes, identifier) : delete!(classes.classes, identifier)
            changed_value
        end
        changed && notify && enqueue_invalidation!(
            classes.queue,
            classes.component_id,
            (StyleInvalidation, RenderInvalidation);
            version=signal_version(reactive),
        )
    end
    subscription = nothing
    try
        return lock(classes.mutex) do
            haskey(classes.bindings, identifier) &&
                throw(ArgumentError("reactive class is already bound: $identifier"))
            was_enabled = identifier in classes.classes
            subscription = subscribe!(reactive) do value, _, _
                update(signal_value(reactive))
            end
            try
                update(signal_value(reactive); notify=false)
                classes.bindings[identifier] = ReactiveClassBinding(
                    identifier,
                    reactive,
                    predicate,
                    subscription,
                )
                was_enabled != (identifier in classes.classes) && enqueue_invalidation!(
                    classes.queue,
                    classes.component_id,
                    (StyleInvalidation, RenderInvalidation);
                    version=signal_version(reactive),
                )
            catch
                delete!(classes.bindings, identifier)
                was_enabled ? push!(classes.classes, identifier) : delete!(classes.classes, identifier)
                rethrow()
            end
            return classes
        end
    catch
        subscription === nothing || unsubscribe!(subscription)
        rethrow()
    end
end

function unbind_reactive_class!(classes::ReactiveClassSet, name::AbstractString)
    identifier = String(name)
    binding = lock(classes.mutex) do
        pop!(classes.bindings, identifier, nothing)
    end
    binding === nothing && return false
    unsubscribe!(binding.subscription)
    lock(classes.mutex) do
        delete!(classes.classes, identifier)
    end
    enqueue_invalidation!(
        classes.queue,
        classes.component_id,
        (StyleInvalidation, RenderInvalidation),
    )
    return true
end

reactive_classes(classes::ReactiveClassSet) = lock(classes.mutex) do
    sort!(collect(classes.classes))
end

function dispose!(classes::ReactiveClassSet)
    bindings = lock(classes.mutex) do
        values = collect(values(classes.bindings))
        empty!(classes.bindings)
        values
    end
    for binding in bindings
        unsubscribe!(binding.subscription)
    end
    return classes
end

end
