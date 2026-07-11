module Reliability

import ..Runtime: cancel!

export FailureStage,
       InitializeFailure,
       UpdateFailure,
       RenderFailure,
       LayoutFailure,
       InputFailure,
       CommandFailure,
       SubscriptionFailure,
       ShutdownFailure,
       ExtensionFailure,
       UnknownFailure,
       FailureRecord,
       FailureCollector,
       record_failure!,
       failure_records,
       clear_failures!,
       ErrorBoundaryPolicy,
       RethrowBoundary,
       ContainBoundary,
       DisableBoundary,
       ErrorBoundary,
       BoundaryResult,
       protect!,
       reset_error_boundary!,
       CleanupFailure,
       ScopeCloseReport,
       CompositeCleanupError,
       ResourceScope,
       defer_cleanup!,
       acquire_resource!,
       close_resource_scope!,
       with_resource_scope,
       CancellationToken,
       cancel!,
       is_cancelled,
       throw_if_cancelled,
       ManagedTaskGroup,
       ManagedTaskFailure,
       spawn_managed!,
       cancel_managed_tasks!,
       join_managed_tasks!,
       close_managed_tasks!

@enum FailureStage begin
    InitializeFailure
    UpdateFailure
    RenderFailure
    LayoutFailure
    InputFailure
    CommandFailure
    SubscriptionFailure
    ShutdownFailure
    ExtensionFailure
    UnknownFailure
end

struct FailureRecord
    sequence::UInt64
    timestamp_ns::UInt64
    stage::FailureStage
    component::Union{Nothing,String}
    error::Any
    backtrace::Any
    metadata::Dict{Symbol,Any}
    fatal::Bool
end

mutable struct FailureCollector
    capacity::Int
    records::Vector{FailureRecord}
    next_sequence::UInt64
    mutex::ReentrantLock

    function FailureCollector(capacity::Integer=256)
        capacity > 0 || throw(ArgumentError("failure collector capacity must be positive"))
        new(Int(capacity), FailureRecord[], 1, ReentrantLock())
    end
end

function record_failure!(
    collector::FailureCollector,
    stage::FailureStage,
    error;
    component=nothing,
    backtrace=nothing,
    metadata=Dict{Symbol,Any}(),
    fatal::Bool=false,
)
    return lock(collector.mutex) do
        collector.next_sequence == typemax(UInt64) &&
            throw(OverflowError("failure sequence overflow"))
        record = FailureRecord(
            collector.next_sequence,
            time_ns(),
            stage,
            component === nothing ? nothing : string(component),
            error,
            backtrace,
            Dict{Symbol,Any}(Symbol(key) => value for (key, value) in pairs(metadata)),
            fatal,
        )
        collector.next_sequence += 1
        length(collector.records) == collector.capacity && popfirst!(collector.records)
        push!(collector.records, record)
        return record
    end
end

failure_records(collector::FailureCollector) = lock(collector.mutex) do
    copy(collector.records)
end

function clear_failures!(collector::FailureCollector)
    lock(collector.mutex) do
        empty!(collector.records)
    end
    return collector
end

@enum ErrorBoundaryPolicy begin
    RethrowBoundary
    ContainBoundary
    DisableBoundary
end

mutable struct ErrorBoundary{F}
    id::String
    policy::ErrorBoundaryPolicy
    fallback::F
    collector::FailureCollector
    failures::Int
    maximum_failures::Int
    disabled::Bool

    function ErrorBoundary(
        id;
        policy::ErrorBoundaryPolicy=ContainBoundary,
        fallback=record -> nothing,
        collector::FailureCollector=FailureCollector(),
        maximum_failures::Integer=3,
    )
        maximum_failures > 0 || throw(ArgumentError("maximum boundary failures must be positive"))
        new{typeof(fallback)}(
            string(id),
            policy,
            fallback,
            collector,
            0,
            Int(maximum_failures),
            false,
        )
    end
end

struct BoundaryResult{T}
    value::T
    failure::Union{Nothing,FailureRecord}
    contained::Bool
end

function protect!(
    operation::F,
    boundary::ErrorBoundary;
    stage::FailureStage=UnknownFailure,
    metadata=Dict{Symbol,Any}(),
) where {F}
    if boundary.disabled
        record = record_failure!(
            boundary.collector,
            stage,
            ErrorException("error boundary is disabled");
            component=boundary.id,
            metadata=metadata,
        )
        value = boundary.fallback(record)
        return BoundaryResult(value, record, true)
    end
    try
        return BoundaryResult(operation(), nothing, false)
    catch error
        trace = catch_backtrace()
        boundary.failures += 1
        boundary.policy == DisableBoundary && boundary.failures >= boundary.maximum_failures &&
            (boundary.disabled = true)
        record = record_failure!(
            boundary.collector,
            stage,
            error;
            component=boundary.id,
            backtrace=trace,
            metadata=metadata,
            fatal=boundary.policy == RethrowBoundary,
        )
        boundary.policy == RethrowBoundary && rethrow()
        value = boundary.fallback(record)
        return BoundaryResult(value, record, true)
    end
end

function reset_error_boundary!(boundary::ErrorBoundary; clear_records::Bool=false)
    boundary.failures = 0
    boundary.disabled = false
    clear_records && clear_failures!(boundary.collector)
    return boundary
end

struct CleanupFailure
    label::String
    error::Any
    backtrace::Any
end

struct ScopeCloseReport
    closed::Bool
    completed::Int
    failures::Vector{CleanupFailure}
end

struct CompositeCleanupError <: Exception
    failures::Vector{CleanupFailure}
end

function Base.showerror(io::IO, error::CompositeCleanupError)
    print(io, length(error.failures), " resource cleanup operation(s) failed")
    for failure in error.failures
        print(io, "\n", failure.label, ": ", repr(failure.error))
    end
end

struct CleanupEntry{F}
    label::String
    cleanup::F
end

mutable struct ResourceScope
    entries::Vector{CleanupEntry}
    state::Symbol
    report::Union{Nothing,ScopeCloseReport}
    mutex::ReentrantLock
end

ResourceScope() = ResourceScope(CleanupEntry[], :open, nothing, ReentrantLock())

function defer_cleanup!(scope::ResourceScope, cleanup; label::AbstractString="cleanup")
    lock(scope.mutex) do
        scope.state == :open || throw(ArgumentError("resource scope is not open"))
        applicable(cleanup) || throw(ArgumentError("cleanup callback must accept no arguments"))
        push!(scope.entries, CleanupEntry(String(label), cleanup))
    end
    return scope
end

function acquire_resource!(
    scope::ResourceScope,
    acquire,
    release;
    label::AbstractString="resource",
)
    applicable(acquire) || throw(ArgumentError("resource acquire callback must accept no arguments"))
    value = acquire()
    applicable(release, value) || begin
        applicable(close, value) && close(value)
        throw(ArgumentError("resource release callback is not applicable to the acquired value"))
    end
    cleanup = () -> release(value)
    try
        defer_cleanup!(scope, cleanup; label=label)
    catch
        cleanup()
        rethrow()
    end
    return value
end

function close_resource_scope!(scope::ResourceScope; throw_errors::Bool=false)
    entries, existing = lock(scope.mutex) do
        if scope.state == :closed
            return CleanupEntry[], scope.report
        elseif scope.state == :closing
            throw(ArgumentError("resource scope is already closing"))
        end
        scope.state = :closing
        values = reverse(copy(scope.entries))
        empty!(scope.entries)
        return values, nothing
    end
    existing !== nothing && return existing
    failures = CleanupFailure[]
    completed = 0
    for entry in entries
        try
            entry.cleanup()
            completed += 1
        catch error
            push!(failures, CleanupFailure(entry.label, error, catch_backtrace()))
        end
    end
    report = ScopeCloseReport(true, completed, failures)
    lock(scope.mutex) do
        scope.state = :closed
        scope.report = report
    end
    throw_errors && !isempty(failures) && throw(CompositeCleanupError(failures))
    return report
end

function with_resource_scope(operation::F; throw_cleanup_errors::Bool=true) where {F}
    scope = ResourceScope()
    operation_error = nothing
    try
        return operation(scope)
    catch error
        operation_error = error
        rethrow()
    finally
        report = close_resource_scope!(scope; throw_errors=false)
        if operation_error === nothing && throw_cleanup_errors && !isempty(report.failures)
            throw(CompositeCleanupError(report.failures))
        end
    end
end

mutable struct CancellationToken
    cancelled::Threads.Atomic{Bool}
end

CancellationToken() = CancellationToken(Threads.Atomic{Bool}(false))
cancel!(token::CancellationToken) = (Threads.atomic_xchg!(token.cancelled, true); token)
is_cancelled(token::CancellationToken) = token.cancelled[]

function throw_if_cancelled(token::CancellationToken)
    is_cancelled(token) && throw(InterruptException())
    return token
end

struct ManagedTaskFailure
    label::String
    error::Any
    backtrace::Any
end

mutable struct ManagedTaskGroup
    token::CancellationToken
    tasks::Dict{Task,String}
    failures::Vector{ManagedTaskFailure}
    closed::Bool
    mutex::ReentrantLock
end

ManagedTaskGroup(; token::CancellationToken=CancellationToken()) =
    ManagedTaskGroup(token, Dict{Task,String}(), ManagedTaskFailure[], false, ReentrantLock())

function spawn_managed!(
    operation::F,
    group::ManagedTaskGroup;
    label::AbstractString="task",
) where {F}
    task = Task() do
        try
            operation(group.token)
        catch error
            error isa InterruptException || lock(group.mutex) do
                push!(group.failures, ManagedTaskFailure(String(label), error, catch_backtrace()))
            end
        end
    end
    lock(group.mutex) do
        group.closed && throw(ArgumentError("managed task group is closed"))
        group.tasks[task] = String(label)
        try
            schedule(task)
        catch
            delete!(group.tasks, task)
            rethrow()
        end
    end
    return task
end

cancel_managed_tasks!(group::ManagedTaskGroup) = (cancel!(group.token); group)

function join_managed_tasks!(group::ManagedTaskGroup; throw_errors::Bool=false)
    tasks = lock(group.mutex) do
        collect(keys(group.tasks))
    end
    for task in tasks
        wait(task)
    end
    failures = lock(group.mutex) do
        for task in tasks
            delete!(group.tasks, task)
        end
        copy(group.failures)
    end
    throw_errors && !isempty(failures) &&
        throw(CompositeCleanupError(CleanupFailure[
            CleanupFailure(failure.label, failure.error, failure.backtrace) for failure in failures
        ]))
    return failures
end

function close_managed_tasks!(group::ManagedTaskGroup; cancel::Bool=true, throw_errors::Bool=false)
    lock(group.mutex) do
        group.closed = true
    end
    cancel && cancel_managed_tasks!(group)
    return join_managed_tasks!(group; throw_errors=throw_errors)
end

end
