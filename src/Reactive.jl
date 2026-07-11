module Reactive

export ReactiveRuntime,
       AbstractReactive,
       Signal,
       signal_value,
       set_signal!,
       update_signal!,
       signal_version,
       reactive_runtime,
       ReactiveSubscription,
       subscribe!,
       unsubscribe!,
       transaction!,
       ComputedSignal,
       computed_signal,
       recompute!,
       ReactiveEffect,
       reactive_effect!,
       dispose!,
       ReactiveBinding,
       bind_signals!,
       ReactiveCycleError,
       ReactiveNotificationError,
       ReactiveValidationError

abstract type AbstractReactive{T} end

mutable struct PendingChange
    source::Any
    old_value::Any
    new_value::Any
    old_version::UInt64
end

mutable struct TransactionFrame
    snapshots::IdDict{Any,Tuple{Any,UInt64}}
end

TransactionFrame() = TransactionFrame(IdDict{Any,Tuple{Any,UInt64}}())

mutable struct ReactiveRuntime
    mutex::ReentrantLock
    transaction_depth::Int
    transaction_frames::Vector{TransactionFrame}
    pending::IdDict{Any,PendingChange}
    next_subscription::UInt64
end

ReactiveRuntime() = ReactiveRuntime(
    ReentrantLock(),
    0,
    TransactionFrame[],
    IdDict{Any,PendingChange}(),
    1,
)

struct ReactiveValidationError <: Exception
    signal::Union{Nothing,String}
    value::Any
    message::String
end

function Base.showerror(io::IO, error::ReactiveValidationError)
    print(io, "reactive validation failed")
    error.signal === nothing || print(io, " for ", error.signal)
    print(io, ": ", error.message)
end

struct ReactiveCycleError <: Exception
    name::String
end

Base.showerror(io::IO, error::ReactiveCycleError) =
    print(io, "reactive computation cycle detected in ", error.name)

struct ReactiveNotificationError <: Exception
    errors::Vector{Any}
end

function Base.showerror(io::IO, error::ReactiveNotificationError)
    print(io, length(error.errors), " reactive subscriber(s) failed")
    for failure in error.errors
        print(io, "\n", repr(failure[1]))
    end
end

mutable struct Signal{T,V,E} <: AbstractReactive{T}
    runtime::ReactiveRuntime
    value::T
    version::UInt64
    validator::V
    equals::E
    subscribers::Dict{UInt64,Any}
    name::Union{Nothing,String}
end

function Signal(
    value::T;
    runtime::ReactiveRuntime=ReactiveRuntime(),
    validator=value -> true,
    equals=isequal,
    name=nothing,
) where {T}
    applicable(validator, value) || throw(ArgumentError("signal validator must accept the signal value"))
    result = validator(value)
    result === true || throw(ReactiveValidationError(
        name === nothing ? nothing : string(name),
        value,
        result isa AbstractString ? String(result) : "initial value was rejected",
    ))
    return Signal{T,typeof(validator),typeof(equals)}(
        runtime,
        value,
        1,
        validator,
        equals,
        Dict{UInt64,Any}(),
        name === nothing ? nothing : string(name),
    )
end

signal_value(signal::Signal) = lock(signal.runtime.mutex) do
    signal.value
end

signal_version(signal::Signal) = lock(signal.runtime.mutex) do
    signal.version
end

reactive_runtime(signal::Signal) = signal.runtime

function _validate(signal::Signal, value)
    applicable(signal.validator, value) ||
        throw(ReactiveValidationError(signal.name, value, "validator is not applicable to the new value"))
    result = signal.validator(value)
    result === true && return
    throw(ReactiveValidationError(
        signal.name,
        value,
        result isa AbstractString ? String(result) : "value was rejected",
    ))
end

function _notify(change::PendingChange)
    source = change.source
    callbacks = lock(source.runtime.mutex) do
        collect(values(source.subscribers))
    end
    failures = Any[]
    for callback in callbacks
        try
            callback(change.new_value, change.old_value, source)
        catch error
            push!(failures, (error, catch_backtrace()))
        end
    end
    isempty(failures) || throw(ReactiveNotificationError(failures))
    return source
end

function set_signal!(signal::Signal{T}, value) where {T}
    converted = convert(T, value)
    _validate(signal, converted)
    change = lock(signal.runtime.mutex) do
        signal.equals(signal.value, converted) && return nothing
        signal.version == typemax(UInt64) && throw(OverflowError("signal version overflow"))
        old_value = signal.value
        old_version = signal.version
        if signal.runtime.transaction_depth > 0
            frame = last(signal.runtime.transaction_frames)
            haskey(frame.snapshots, signal) ||
                (frame.snapshots[signal] = (old_value, old_version))
        end
        signal.value = converted
        signal.version += 1
        if signal.runtime.transaction_depth > 0
            pending = get(signal.runtime.pending, signal, nothing)
            if pending === nothing
                signal.runtime.pending[signal] = PendingChange(
                    signal,
                    old_value,
                    converted,
                    old_version,
                )
            else
                pending.new_value = converted
                if signal.equals(pending.old_value, converted)
                    signal.value = pending.old_value
                    signal.version = pending.old_version
                    delete!(signal.runtime.pending, signal)
                end
            end
            return nothing
        end
        return PendingChange(signal, old_value, converted, old_version)
    end
    change === nothing || _notify(change)
    return signal
end

function update_signal!(operation::F, signal::Signal) where {F}
    old_value = signal_value(signal)
    applicable(operation, old_value) || throw(ArgumentError("signal update callback is not applicable"))
    return set_signal!(signal, operation(old_value))
end

mutable struct ReactiveSubscription
    source::Any
    id::UInt64
    active::Bool
end

function subscribe!(
    signal::Signal,
    callback;
    immediate::Bool=false,
)
    applicable(callback, signal.value, signal.value, signal) ||
        throw(ArgumentError("subscriber must accept (new_value, old_value, signal)"))
    subscription = lock(signal.runtime.mutex) do
        signal.runtime.next_subscription == typemax(UInt64) &&
            throw(OverflowError("reactive subscription id overflow"))
        id = signal.runtime.next_subscription
        signal.runtime.next_subscription += 1
        signal.subscribers[id] = callback
        ReactiveSubscription(signal, id, true)
    end
    if immediate
        value = signal_value(signal)
        try
            callback(value, value, signal)
        catch
            unsubscribe!(subscription)
            rethrow()
        end
    end
    return subscription
end

subscribe!(callback::Function, signal::Signal; kwargs...) =
    subscribe!(signal, callback; kwargs...)

function unsubscribe!(subscription::ReactiveSubscription)
    source = subscription.source
    return lock(source.runtime.mutex) do
        subscription.active || return false
        removed = pop!(source.subscribers, subscription.id, nothing) !== nothing
        subscription.active = false
        return removed
    end
end

function _rollback_frame!(
    runtime::ReactiveRuntime,
    frame::TransactionFrame;
    outermost::Bool,
)
    for (source, snapshot) in frame.snapshots
        source.value, source.version = snapshot
        outermost && continue
        change = get(runtime.pending, source, nothing)
        change === nothing && continue
        if source.equals(change.old_value, source.value)
            delete!(runtime.pending, source)
        else
            change.new_value = source.value
        end
    end
    outermost && empty!(runtime.pending)
    return runtime
end

function _merge_frame!(parent::TransactionFrame, child::TransactionFrame)
    for (source, snapshot) in child.snapshots
        haskey(parent.snapshots, source) || (parent.snapshots[source] = snapshot)
    end
    return parent
end

function _notify_changes(changes::Vector{PendingChange})
    failures = Any[]
    for change in changes
        try
            _notify(change)
        catch error
            if error isa ReactiveNotificationError
                append!(failures, error.errors)
            else
                push!(failures, (error, catch_backtrace()))
            end
        end
    end
    isempty(failures) || throw(ReactiveNotificationError(failures))
    return nothing
end

function transaction!(operation::F, runtime::ReactiveRuntime) where {F}
    lock(runtime.mutex)
    runtime.transaction_depth += 1
    outermost = runtime.transaction_depth == 1
    push!(runtime.transaction_frames, TransactionFrame())
    result = nothing
    changes = PendingChange[]
    try
        result = operation()
        frame = pop!(runtime.transaction_frames)
        runtime.transaction_depth -= 1
        if outermost
            changes = collect(values(runtime.pending))
            empty!(runtime.pending)
        else
            _merge_frame!(last(runtime.transaction_frames), frame)
        end
    catch
        frame = pop!(runtime.transaction_frames)
        runtime.transaction_depth -= 1
        _rollback_frame!(runtime, frame; outermost=outermost)
        unlock(runtime.mutex)
        rethrow()
    end
    unlock(runtime.mutex)
    _notify_changes(changes)
    return result
end

mutable struct ComputedSignal{T,F} <: AbstractReactive{T}
    signal::Signal{T}
    compute::F
    dependencies::Vector{Any}
    subscriptions::Vector{ReactiveSubscription}
    computing::Bool
    disposed::Bool
    name::String
end

signal_value(computed::ComputedSignal) = signal_value(computed.signal)
signal_version(computed::ComputedSignal) = signal_version(computed.signal)
reactive_runtime(computed::ComputedSignal) = reactive_runtime(computed.signal)
subscribe!(computed::ComputedSignal, callback; kwargs...) =
    subscribe!(computed.signal, callback; kwargs...)
subscribe!(callback::Function, computed::ComputedSignal; kwargs...) =
    subscribe!(computed.signal, callback; kwargs...)

function computed_signal(
    compute,
    dependencies::AbstractVector{<:AbstractReactive};
    runtime::ReactiveRuntime=isempty(dependencies) ? ReactiveRuntime() : reactive_runtime(first(dependencies)),
    name::AbstractString="computed",
)
    all(dependency -> reactive_runtime(dependency) === runtime, dependencies) ||
        throw(ArgumentError("computed dependencies must share one ReactiveRuntime"))
    applicable(compute, (signal_value(dependency) for dependency in dependencies)...) ||
        throw(ArgumentError("computed callback is not applicable to dependency values"))
    initial = compute((signal_value(dependency) for dependency in dependencies)...)
    output = Signal(initial; runtime=runtime, name=name)
    computed = ComputedSignal{typeof(initial),typeof(compute)}(
        output,
        compute,
        Any[dependency for dependency in dependencies],
        ReactiveSubscription[],
        false,
        false,
        String(name),
    )
    for dependency in dependencies
        push!(computed.subscriptions, subscribe!(dependency) do _, _, _
            recompute!(computed)
        end)
    end
    return computed
end

function recompute!(computed::ComputedSignal)
    computed.disposed && return computed
    computed.computing && throw(ReactiveCycleError(computed.name))
    computed.computing = true
    try
        values = (signal_value(dependency) for dependency in computed.dependencies)
        set_signal!(computed.signal, computed.compute(values...))
    finally
        computed.computing = false
    end
    return computed
end

mutable struct ReactiveEffect{F}
    effect::F
    dependencies::Vector{Any}
    subscriptions::Vector{ReactiveSubscription}
    cleanup::Any
    running::Bool
    disposed::Bool
    name::String
end

function _run_effect!(effect::ReactiveEffect)
    effect.disposed && return effect
    effect.running && throw(ReactiveCycleError(effect.name))
    effect.running = true
    try
        effect.cleanup === nothing || effect.cleanup()
        values = (signal_value(dependency) for dependency in effect.dependencies)
        cleanup = effect.effect(values...)
        effect.cleanup = applicable(cleanup) ? cleanup : nothing
    finally
        effect.running = false
    end
    return effect
end

function reactive_effect!(
    operation,
    dependencies::AbstractVector{<:AbstractReactive};
    name::AbstractString="effect",
    immediate::Bool=true,
)
    values = (signal_value(dependency) for dependency in dependencies)
    applicable(operation, values...) ||
        throw(ArgumentError("reactive effect is not applicable to dependency values"))
    effect = ReactiveEffect{typeof(operation)}(
        operation,
        Any[dependency for dependency in dependencies],
        ReactiveSubscription[],
        nothing,
        false,
        false,
        String(name),
    )
    for dependency in dependencies
        push!(effect.subscriptions, subscribe!(dependency) do _, _, _
            _run_effect!(effect)
        end)
    end
    immediate && _run_effect!(effect)
    return effect
end

function dispose!(computed::ComputedSignal)
    computed.disposed && return computed
    subscriptions = copy(computed.subscriptions)
    empty!(computed.subscriptions)
    computed.disposed = true
    for subscription in subscriptions
        unsubscribe!(subscription)
    end
    return computed
end

function dispose!(effect::ReactiveEffect)
    effect.disposed && return effect
    subscriptions = copy(effect.subscriptions)
    empty!(effect.subscriptions)
    cleanup = effect.cleanup
    effect.cleanup = nothing
    effect.disposed = true
    for subscription in subscriptions
        unsubscribe!(subscription)
    end
    cleanup === nothing || cleanup()
    return effect
end

mutable struct ReactiveBinding
    left_to_right::ReactiveSubscription
    right_to_left::ReactiveSubscription
    updating::Bool
    disposed::Bool
end

function bind_signals!(
    left::Signal,
    right::Signal;
    to_right=identity,
    to_left=identity,
    initialize::Symbol=:left,
)
    left.runtime === right.runtime ||
        throw(ArgumentError("bound signals must share one ReactiveRuntime"))
    initialize in (:left, :right, :none) ||
        throw(ArgumentError("binding initialization must be :left, :right, or :none"))
    placeholder = ReactiveSubscription(left, 0, false)
    binding = ReactiveBinding(placeholder, placeholder, false, false)
    binding.left_to_right = subscribe!(left) do value, _, _
        binding.updating && return
        binding.updating = true
        try
            set_signal!(right, to_right(value))
        finally
            binding.updating = false
        end
    end
    binding.right_to_left = subscribe!(right) do value, _, _
        binding.updating && return
        binding.updating = true
        try
            set_signal!(left, to_left(value))
        finally
            binding.updating = false
        end
    end
    initialize == :left && set_signal!(right, to_right(signal_value(left)))
    initialize == :right && set_signal!(left, to_left(signal_value(right)))
    return binding
end

function dispose!(binding::ReactiveBinding)
    binding.disposed && return binding
    binding.disposed = true
    unsubscribe!(binding.left_to_right)
    unsubscribe!(binding.right_to_left)
    return binding
end

end
