
@enum TraceOverflowPolicy::UInt8 begin
    DropOldestTrace
    StopTraceRecording
    FailTraceRecording
end

struct TraceEntry
    sequence::UInt64
    timestamp_ns::UInt64
    kind::Symbol
    source::Symbol
    correlation::Any
    payload::Any
    metadata::Dict{Symbol,Any}
end

struct EventTrace
    version::VersionNumber
    started_ns::UInt64
    ended_ns::UInt64
    entries::Vector{TraceEntry}
    metadata::Dict{Symbol,Any}
    dropped_count::UInt64

    function EventTrace(
        version::VersionNumber,
        started_ns::UInt64,
        ended_ns::UInt64,
        entries::Vector{TraceEntry},
        metadata::Dict{Symbol,Any},
        dropped_count::UInt64,
    )
        ended_ns >= started_ns || throw(ArgumentError("trace end precedes its start"))
        resolved_entries = copy(entries)
        resolved_metadata = copy(metadata)
        previous_sequence = UInt64(0)
        previous_timestamp = started_ns
        for entry in resolved_entries
            entry.sequence > previous_sequence ||
                throw(ArgumentError("trace entry sequences must increase"))
            entry.timestamp_ns >= previous_timestamp ||
                throw(ArgumentError("trace timestamps must be monotonic"))
            previous_sequence = entry.sequence
            previous_timestamp = entry.timestamp_ns
        end
        return new(
            version,
            started_ns,
            ended_ns,
            resolved_entries,
            resolved_metadata,
            dropped_count,
        )
    end
end

mutable struct EventRecorder
    buffer::Vector{TraceEntry}
    start::Int
    length::Int
    capacity::Int
    overflow::TraceOverflowPolicy
    sequence::UInt64
    dropped::UInt64
    started_ns::UInt64
    last_timestamp_ns::UInt64
    active::Bool
    filter::Any
    snapshot::Any
    clock::Any
    metadata::Dict{Symbol,Any}
    errors::Vector{CapturedException}
    strict::Bool
    mutex::ReentrantLock
end

function EventRecorder(;
    capacity::Integer=10_000,
    overflow::TraceOverflowPolicy=DropOldestTrace,
    filter=(kind, payload, source, metadata) -> true,
    snapshot=identity,
    clock=time_ns,
    metadata=Dict{Symbol,Any}(),
    strict::Bool=false,
)
    capacity > 0 || throw(ArgumentError("trace capacity must be positive"))
    applicable(filter, :event, nothing, :application, Dict{Symbol,Any}()) ||
        throw(ArgumentError("trace filter must accept kind, payload, source, and metadata"))
    applicable(snapshot, nothing) ||
        throw(ArgumentError("trace snapshot callback must accept a payload"))
    applicable(clock) || throw(ArgumentError("trace clock must be callable without arguments"))
    return EventRecorder(
        TraceEntry[],
        1,
        0,
        Int(capacity),
        overflow,
        UInt64(0),
        UInt64(0),
        UInt64(0),
        UInt64(0),
        true,
        filter,
        snapshot,
        clock,
        Dict{Symbol,Any}(Symbol(key) => value for (key, value) in metadata),
        CapturedException[],
        strict,
        ReentrantLock(),
    )
end

function _trace_now(recorder::EventRecorder)
    value = recorder.clock()
    value isa Integer && value >= 0 ||
        throw(ArgumentError("trace clock must return a non-negative integer"))
    return UInt64(value)
end

function _capture_trace_error!(recorder::EventRecorder, error, backtrace)
    captured = CapturedException(error, backtrace)
    lock(recorder.mutex) do
        push!(recorder.errors, captured)
    end
    recorder.strict && Base.throw(error)
    return nothing
end

function _ordered_trace_entries(recorder::EventRecorder)
    entries = TraceEntry[]
    sizehint!(entries, recorder.length)
    isempty(recorder.buffer) && return entries
    for offset in 0:(recorder.length - 1)
        index = mod1(recorder.start + offset, length(recorder.buffer))
        push!(entries, recorder.buffer[index])
    end
    return entries
end

function _append_trace_entry!(recorder::EventRecorder, entry::TraceEntry)
    if recorder.length < recorder.capacity
        push!(recorder.buffer, entry)
        recorder.length += 1
        return true
    elseif recorder.overflow == DropOldestTrace
        recorder.dropped == typemax(UInt64) && throw(OverflowError("trace drop counter exhausted"))
        recorder.buffer[recorder.start] = entry
        recorder.start = mod1(recorder.start + 1, recorder.capacity)
        recorder.dropped += UInt64(1)
        return true
    elseif recorder.overflow == StopTraceRecording
        recorder.active = false
        return false
    else
        throw(OverflowError("trace recorder capacity exhausted"))
    end
end

function record_trace!(
    recorder::EventRecorder,
    kind::Symbol,
    payload;
    source::Symbol=:application,
    correlation=nothing,
    metadata=Dict{Symbol,Any}(),
    timestamp_ns=nothing,
)
    details = Dict{Symbol,Any}(Symbol(key) => value for (key, value) in metadata)
    included = try
        value = recorder.filter(kind, payload, source, details)
        value isa Bool || throw(ArgumentError("trace filter must return Bool"))
        value
    catch error
        return _capture_trace_error!(recorder, error, catch_backtrace())
    end
    included || return nothing
    captured_payload = try
        recorder.snapshot(payload)
    catch error
        return _capture_trace_error!(recorder, error, catch_backtrace())
    end
    timestamp = try
        timestamp_ns === nothing ? _trace_now(recorder) : UInt64(timestamp_ns)
    catch error
        return _capture_trace_error!(recorder, error, catch_backtrace())
    end
    try
        return lock(recorder.mutex) do
            recorder.active || return nothing
            timestamp >= recorder.last_timestamp_ns ||
                throw(ArgumentError("trace timestamps must be monotonic"))
            recorder.sequence == typemax(UInt64) &&
                throw(OverflowError("trace sequence exhausted"))
            sequence = recorder.sequence + UInt64(1)
            entry = TraceEntry(
                sequence,
                timestamp,
                kind,
                source,
                correlation,
                captured_payload,
                details,
            )
            first_entry = recorder.sequence == 0
            _append_trace_entry!(recorder, entry) || return nothing
            recorder.sequence = sequence
            first_entry && (recorder.started_ns = timestamp)
            recorder.last_timestamp_ns = timestamp
            return entry
        end
    catch error
        return _capture_trace_error!(recorder, error, catch_backtrace())
    end
end

record_checkpoint!(recorder::EventRecorder, name::Symbol, value; kwargs...) =
    record_trace!(recorder, :checkpoint, value; source=name, kwargs...)

trace_entries(recorder::EventRecorder) = lock(recorder.mutex) do
    _ordered_trace_entries(recorder)
end

trace_entries(trace::EventTrace) = copy(trace.entries)

trace_length(recorder::EventRecorder) = lock(recorder.mutex) do
    recorder.length
end

trace_length(trace::EventTrace) = length(trace.entries)

trace_dropped_count(recorder::EventRecorder) = lock(recorder.mutex) do
    recorder.dropped
end

trace_dropped_count(trace::EventTrace) = trace.dropped_count

trace_errors(recorder::EventRecorder) = lock(recorder.mutex) do
    copy(recorder.errors)
end

function take_trace_errors!(recorder::EventRecorder)
    return lock(recorder.mutex) do
        errors = copy(recorder.errors)
        empty!(recorder.errors)
        errors
    end
end

function trace_snapshot(recorder::EventRecorder; ended_ns=nothing)
    ended = ended_ns === nothing ? _trace_now(recorder) : UInt64(ended_ns)
    return lock(recorder.mutex) do
        started = recorder.sequence == 0 ? ended : recorder.started_ns
        ended >= recorder.last_timestamp_ns ||
            throw(ArgumentError("trace snapshot end precedes the last entry"))
        EventTrace(
            v"1.0.0",
            started,
            ended,
            _ordered_trace_entries(recorder),
            copy(recorder.metadata),
            recorder.dropped,
        )
    end
end

function seal_trace!(recorder::EventRecorder; ended_ns=nothing)
    ended = ended_ns === nothing ? _trace_now(recorder) : UInt64(ended_ns)
    return lock(recorder.mutex) do
        started = recorder.sequence == 0 ? ended : recorder.started_ns
        ended >= recorder.last_timestamp_ns ||
            throw(ArgumentError("trace end precedes the last entry"))
        trace = EventTrace(
            v"1.0.0",
            started,
            ended,
            _ordered_trace_entries(recorder),
            copy(recorder.metadata),
            recorder.dropped,
        )
        recorder.active = false
        return trace
    end
end

function clear_trace!(recorder::EventRecorder; resume::Bool=true)
    lock(recorder.mutex) do
        empty!(recorder.buffer)
        recorder.start = 1
        recorder.length = 0
        recorder.sequence = UInt64(0)
        recorder.dropped = UInt64(0)
        recorder.started_ns = UInt64(0)
        recorder.last_timestamp_ns = UInt64(0)
        recorder.active = resume
    end
    return recorder
end

@enum ReplayStatus::UInt8 begin
    ReplayReady
    ReplayRunning
    ReplayPaused
    ReplayCompleted
    ReplayFailed
end

struct ReplayResult
    entry::TraceEntry
    value::Any
    error::Union{Nothing,CapturedException}
end

mutable struct ReplayController
    trace::EventTrace
    dispatch::Any
    position::Int
    status::ReplayStatus
    speed::Float64
    clock::Any
    origin_clock_ns::UInt64
    origin_trace_ns::UInt64
    errors::Vector{CapturedException}
    strict::Bool
    mutex::ReentrantLock
end

function ReplayController(
    trace::EventTrace,
    dispatch;
    speed::Real=1.0,
    clock=time_ns,
    strict::Bool=false,
)
    resolved_speed = Float64(speed)
    isfinite(resolved_speed) && resolved_speed > 0.0 ||
        throw(ArgumentError("replay speed must be finite and positive"))
    applicable(clock) || throw(ArgumentError("replay clock must be callable without arguments"))
    isempty(trace.entries) || applicable(dispatch, first(trace.entries)) ||
        throw(ArgumentError("replay dispatcher must accept a TraceEntry"))
    return ReplayController(
        trace,
        dispatch,
        1,
        isempty(trace.entries) ? ReplayCompleted : ReplayReady,
        resolved_speed,
        clock,
        UInt64(0),
        UInt64(0),
        CapturedException[],
        strict,
        ReentrantLock(),
    )
end

function _replay_now(replay::ReplayController)
    value = replay.clock()
    value isa Integer && value >= 0 ||
        throw(ArgumentError("replay clock must return a non-negative integer"))
    return UInt64(value)
end

replay_status(replay::ReplayController) = lock(replay.mutex) do
    replay.status
end

replay_position(replay::ReplayController) = lock(replay.mutex) do
    replay.position
end

function start_replay!(replay::ReplayController; now_ns=nothing)
    now = now_ns === nothing ? _replay_now(replay) : UInt64(now_ns)
    return lock(replay.mutex) do
        replay.position > length(replay.trace.entries) &&
            (replay.status = ReplayCompleted; return false)
        replay.status == ReplayRunning && return false
        replay.origin_clock_ns = now
        replay.origin_trace_ns = replay.trace.entries[replay.position].timestamp_ns
        replay.status = ReplayRunning
        return true
    end
end

function pause_replay!(replay::ReplayController)
    return lock(replay.mutex) do
        replay.status == ReplayRunning || return false
        replay.status = ReplayPaused
        return true
    end
end

function _capture_replay_failure!(replay::ReplayController, entry::TraceEntry, error, backtrace)
    captured = CapturedException(error, backtrace)
    lock(replay.mutex) do
        push!(replay.errors, captured)
        replay.status = ReplayFailed
    end
    replay.strict && Base.throw(error)
    return ReplayResult(entry, nothing, captured)
end

function replay_step!(replay::ReplayController)
    entry = lock(replay.mutex) do
        replay.status == ReplayFailed && return nothing
        replay.position > length(replay.trace.entries) &&
            (replay.status = ReplayCompleted; return nothing)
        entry = replay.trace.entries[replay.position]
        replay.position += 1
        entry
    end
    entry === nothing && return nothing
    value = try
        replay.dispatch(entry)
    catch error
        return _capture_replay_failure!(replay, entry, error, catch_backtrace())
    end
    lock(replay.mutex) do
        replay.position > length(replay.trace.entries) && (replay.status = ReplayCompleted)
    end
    return ReplayResult(entry, value, nothing)
end

function poll_replay!(replay::ReplayController; now_ns=nothing)
    now = now_ns === nothing ? _replay_now(replay) : UInt64(now_ns)
    results = ReplayResult[]
    while true
        entry = lock(replay.mutex) do
            replay.status == ReplayRunning || return nothing
            replay.position > length(replay.trace.entries) &&
                (replay.status = ReplayCompleted; return nothing)
            clock_elapsed = now >= replay.origin_clock_ns ?
                now - replay.origin_clock_ns : UInt64(0)
            allowed = Float64(clock_elapsed) * replay.speed
            candidate = replay.trace.entries[replay.position]
            trace_elapsed = candidate.timestamp_ns - replay.origin_trace_ns
            Float64(trace_elapsed) <= allowed || return nothing
            replay.position += 1
            return candidate
        end
        entry === nothing && break
        value = try
            replay.dispatch(entry)
        catch error
            push!(results, _capture_replay_failure!(replay, entry, error, catch_backtrace()))
            break
        end
        push!(results, ReplayResult(entry, value, nothing))
    end
    lock(replay.mutex) do
        replay.status != ReplayFailed && replay.position > length(replay.trace.entries) &&
            (replay.status = ReplayCompleted)
    end
    return results
end

function replay_all!(replay::ReplayController)
    results = ReplayResult[]
    while true
        result = replay_step!(replay)
        result === nothing && break
        push!(results, result)
        result.error === nothing || break
    end
    return results
end

function seek_replay!(replay::ReplayController, position::Integer)
    return lock(replay.mutex) do
        1 <= position <= length(replay.trace.entries) + 1 ||
            throw(BoundsError(replay.trace.entries, position))
        replay.position = Int(position)
        replay.status = replay.position > length(replay.trace.entries) ? ReplayCompleted : ReplayReady
        replay.origin_clock_ns = UInt64(0)
        replay.origin_trace_ns = UInt64(0)
        return replay
    end
end

reset_replay!(replay::ReplayController) = seek_replay!(replay, 1)

replay_errors(replay::ReplayController) = lock(replay.mutex) do
    copy(replay.errors)
end

function take_replay_errors!(replay::ReplayController)
    return lock(replay.mutex) do
        errors = copy(replay.errors)
        empty!(replay.errors)
        errors
    end
end
