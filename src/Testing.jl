module Testing

using Unicode
using SHA: sha256
using ..Backends
using ..Core
using ..Events
using ..Interaction
using ..Toolkit
using ..Widgets
import ..Backends: draw!
import ..Runtime
import ..Runtime: request_exit!
import ..Clipboard

"""Failure raised by a headless buffer or snapshot assertion."""
struct BufferAssertionError <: Exception
    message::String
end

Base.showerror(io::IO, error::BufferAssertionError) = print(io, error.message)

"""Opaque handle for work scheduled on a `VirtualClock`."""
struct ScheduledToken
    id::UInt64
end

struct _ScheduledCall
    token::ScheduledToken
    deadline_ns::UInt64
    callback::Any
end

"""Deterministic monotonic clock with explicitly advanced scheduled work."""
mutable struct VirtualClock
    now_ns::UInt64
    next_id::UInt64
    scheduled::Vector{_ScheduledCall}
end

function VirtualClock(; start_ns::Integer=0)
    start_ns >= 0 || throw(ArgumentError("virtual clock start must be nonnegative"))
    start_ns <= typemax(UInt64) || throw(ArgumentError("virtual clock start is too large"))
    VirtualClock(UInt64(start_ns), UInt64(1), _ScheduledCall[])
end

virtual_time_ns(clock::VirtualClock) = clock.now_ns
pending_scheduled(clock::VirtualClock) = length(clock.scheduled)

function _seconds_to_nanoseconds(seconds::Real)
    value = Float64(seconds)
    isfinite(value) || throw(ArgumentError("time interval must be finite"))
    value >= 0 || throw(ArgumentError("time interval must be nonnegative"))
    scaled = value * 1_000_000_000
    scaled <= Float64(typemax(UInt64)) || throw(ArgumentError("time interval is too large"))
    UInt64(round(scaled))
end

function _invoke_scheduled(callback, clock::VirtualClock)
    applicable(callback, clock) && return callback(clock)
    applicable(callback) && return callback()
    throw(ArgumentError("scheduled callback must accept zero arguments or the virtual clock"))
end

"""Schedule a callback after a virtual delay measured in seconds."""
function schedule_after!(callback, clock::VirtualClock, delay_seconds::Real)
    applicable(callback, clock) || applicable(callback) ||
        throw(ArgumentError("scheduled callback must accept zero arguments or the virtual clock"))
    delay_ns = _seconds_to_nanoseconds(delay_seconds)
    delay_ns <= typemax(UInt64) - clock.now_ns ||
        throw(OverflowError("virtual deadline exceeds UInt64 nanoseconds"))
    clock.next_id == 0 && throw(OverflowError("virtual schedule token space exhausted"))
    token = ScheduledToken(clock.next_id)
    clock.next_id += 1
    push!(clock.scheduled, _ScheduledCall(token, clock.now_ns + delay_ns, callback))
    token
end

schedule_after!(clock::VirtualClock, delay_seconds::Real, callback) =
    schedule_after!(callback, clock, delay_seconds)

"""Cancel pending virtual work, returning whether the token was present."""
function cancel_scheduled!(clock::VirtualClock, token::ScheduledToken)
    index = findfirst(call -> call.token == token, clock.scheduled)
    isnothing(index) && return false
    deleteat!(clock.scheduled, index)
    true
end

"""Advance virtual time and synchronously run due callbacks in deadline order."""
function advance_time!(
    clock::VirtualClock,
    elapsed_seconds::Real;
    max_callbacks::Integer=100_000,
)
    max_callbacks > 0 || throw(ArgumentError("callback limit must be positive"))
    elapsed_ns = _seconds_to_nanoseconds(elapsed_seconds)
    elapsed_ns <= typemax(UInt64) - clock.now_ns ||
        throw(OverflowError("virtual clock exceeds UInt64 nanoseconds"))
    clock.now_ns += elapsed_ns
    executed = 0
    while true
        sort!(clock.scheduled; by=call -> (call.deadline_ns, call.token.id))
        isempty(clock.scheduled) && break
        first(clock.scheduled).deadline_ns <= clock.now_ns || break
        executed < max_callbacks ||
            throw(ErrorException("virtual callback limit exceeded while advancing time"))
        call = popfirst!(clock.scheduled)
        _invoke_scheduled(call.callback, clock)
        executed += 1
    end
    executed
end

struct _InitializeRuntimeModel end
const _INITIALIZE_RUNTIME_MODEL = _InitializeRuntimeModel()

"""Summary of one deterministic managed-application pilot operation."""
struct RuntimePilotResult
    accepted::Bool
    processed_messages::Int
    redrawn::Bool
    exited::Bool
    result::Any
end

struct _AutomaticWidgetState end
const _AUTOMATIC_WIDGET_STATE = _AutomaticWidgetState()

"""Summary of one immediate widget pilot event."""
struct WidgetPilotResult
    handled::Bool
    redrawn::Bool
end

"""Deterministic visual artifacts captured from one buffer or pilot frame."""
struct SnapshotBundle
    source_kind::Symbol
    plain::String
    ansi::String
    structured::Any
    svg::String
end

"""Integrity metadata for one file in a snapshot bundle artifact directory."""
struct SnapshotArtifactRecord
    name::String
    bytes::Int
    sha256::String
end

"""Compact metadata summary for one snapshot bundle or artifact directory."""
struct SnapshotArtifactSummary
    source_kind::Symbol
    artifact_count::Int
    total_bytes::Int
end

Base.:(==)(left::SnapshotArtifactRecord, right::SnapshotArtifactRecord) =
    left.name == right.name && left.bytes == right.bytes && left.sha256 == right.sha256
Base.isequal(left::SnapshotArtifactRecord, right::SnapshotArtifactRecord) =
    isequal(left.name, right.name) && isequal(left.bytes, right.bytes) && isequal(left.sha256, right.sha256)
Base.hash(record::SnapshotArtifactRecord, seed::UInt) =
    hash((record.name, record.bytes, record.sha256), seed)

Base.:(==)(left::SnapshotArtifactSummary, right::SnapshotArtifactSummary) =
    left.source_kind == right.source_kind &&
    left.artifact_count == right.artifact_count &&
    left.total_bytes == right.total_bytes
Base.isequal(left::SnapshotArtifactSummary, right::SnapshotArtifactSummary) =
    isequal(left.source_kind, right.source_kind) &&
    isequal(left.artifact_count, right.artifact_count) &&
    isequal(left.total_bytes, right.total_bytes)
Base.hash(summary::SnapshotArtifactSummary, seed::UInt) =
    hash((summary.source_kind, summary.artifact_count, summary.total_bytes), seed)

Base.:(==)(left::SnapshotBundle, right::SnapshotBundle) =
    left.source_kind == right.source_kind &&
    left.plain == right.plain &&
    left.ansi == right.ansi &&
    left.structured == right.structured &&
    left.svg == right.svg
Base.isequal(left::SnapshotBundle, right::SnapshotBundle) =
    isequal(left.source_kind, right.source_kind) &&
    isequal(left.plain, right.plain) &&
    isequal(left.ansi, right.ansi) &&
    isequal(left.structured, right.structured) &&
    isequal(left.svg, right.svg)
Base.hash(bundle::SnapshotBundle, seed::UInt) =
    hash((bundle.source_kind, bundle.plain, bundle.ansi, bundle.structured, bundle.svg), seed)

_combine_widget_results(results) =
    WidgetPilotResult(any(result -> result.handled, results), any(result -> result.redrawn, results))

_combine_dispatch_results(results) =
    DispatchResult(
        any(result -> result.consumed, results),
        any(result -> result.redraw, results),
        Any[message for result in results for message in result.messages],
    )

_combine_runtime_results(results) =
    RuntimePilotResult(
        any(result -> result.accepted, results),
        sum(result -> result.processed_messages, results; init=0),
        any(result -> result.redrawn, results),
        isempty(results) ? false : last(results).exited,
        isempty(results) ? nothing : last(results).result,
    )

"""Headless driver for one immediate-mode widget and its explicit state value."""
mutable struct WidgetPilot
    widget::Any
    state::Any
    stateful::Bool
    backend::TestBackend
    terminal::Terminal
    clock::VirtualClock
end

function WidgetPilot(
    widget;
    state=_AUTOMATIC_WIDGET_STATE,
    stateful::Union{Nothing,Bool}=nothing,
    height::Integer=24,
    width::Integer=80,
    capabilities::TerminalCapabilities=TerminalCapabilities(),
    clock::VirtualClock=VirtualClock(),
)
    automatic = state === _AUTOMATIC_WIDGET_STATE
    resolved_state = automatic ? state_for(widget) : state
    uses_state = isnothing(stateful) ? !(automatic && isnothing(resolved_state)) : stateful
    backend = TestBackend(height, width; capabilities)
    pilot = WidgetPilot(widget, resolved_state, uses_state, backend, Terminal(backend), clock)
    draw!(pilot)
    pilot
end

"""Render one immediate widget frame with explicit state when configured."""
function draw!(pilot::WidgetPilot)
    draw!(pilot.terminal) do frame
        if pilot.stateful
            render!(frame, pilot.widget, frame.area, pilot.state)
        else
            render!(frame, pilot.widget, frame.area)
        end
    end
end

"""Dispatch through the widget's open `handle!` interface and redraw when handled."""
function send!(pilot::WidgetPilot, event::AbstractEvent)
    handled = if applicable(handle!, pilot.state, pilot.widget, event, pilot.backend.screen.area)
        handle!(pilot.state, pilot.widget, event, pilot.backend.screen.area)
    elseif applicable(handle!, pilot.state, pilot.widget, event)
        handle!(pilot.state, pilot.widget, event)
    else
        false
    end
    handled isa Bool || throw(ArgumentError("widget handle! must return Bool"))
    handled && draw!(pilot)
    WidgetPilotResult(handled, handled)
end

function advance_time!(pilot::WidgetPilot, elapsed_seconds::Real)
    previous = virtual_time_ns(pilot.clock)
    advance_time!(pilot.clock, elapsed_seconds)
    current = virtual_time_ns(pilot.clock)
    send!(pilot, TickEvent(current, current - previous))
end

function _wait_until!(
    advance,
    pilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    timeout_seconds >= 0 || throw(ArgumentError("wait timeout must be nonnegative"))
    step_seconds > 0 || throw(ArgumentError("wait step must be positive"))
    applicable(predicate, pilot) || throw(ArgumentError("wait predicate must accept the pilot"))
    elapsed = 0.0
    timeout = Float64(timeout_seconds)
    step = Float64(step_seconds)
    while elapsed <= timeout
        result = predicate(pilot)
        result isa Bool || throw(ArgumentError("wait predicate must return Bool"))
        result && return pilot
        elapsed >= timeout && break
        delta = min(step, timeout - elapsed)
        advance(pilot, delta)
        elapsed += delta
    end
    final_time = hasproperty(pilot, :clock) ? virtual_time_ns(getproperty(pilot, :clock)) : nothing
    throw(BufferAssertionError(
        "wait condition was not satisfied within $(timeout_seconds) seconds " *
        "(pilot=$(typeof(pilot)), step_seconds=$(step_seconds), virtual_time_ns=$(final_time))",
    ))
end

"""Advance virtual widget time until a predicate is satisfied or the timeout expires."""
wait_until!(
    pilot::WidgetPilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = _wait_until!(advance_time!, pilot, predicate; timeout_seconds, step_seconds)

"""Advance virtual widget time until visible text appears."""
wait_for_text!(
    pilot::WidgetPilot,
    text;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> _matches_text(plain_snapshot(candidate), text);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual widget time until the full plain snapshot matches."""
wait_for_plain_snapshot!(
    pilot::WidgetPilot,
    expected::AbstractString;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> plain_snapshot(candidate) == String(expected);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual widget time until the full ANSI snapshot matches."""
wait_for_ansi_snapshot!(
    pilot::WidgetPilot,
    expected::AbstractString;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
) = wait_until!(
    pilot,
    candidate -> ansi_snapshot(candidate; kwargs...) == String(expected);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual widget time until the full structured snapshot matches."""
wait_for_structured_snapshot!(
    pilot::WidgetPilot,
    expected;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> structured_snapshot(candidate) == expected;
    timeout_seconds,
    step_seconds,
)

"""Advance virtual widget time until the full SVG snapshot matches."""
wait_for_svg_snapshot!(
    pilot::WidgetPilot,
    expected::AbstractString;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
) = wait_until!(
    pilot,
    candidate -> svg_snapshot(candidate; kwargs...) == String(expected);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual widget time until the full snapshot bundle matches."""
wait_for_snapshot_bundle!(
    pilot::WidgetPilot,
    expected::SnapshotBundle;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    ansi_options::NamedTuple=(;),
    svg_options::NamedTuple=(;),
) = wait_until!(
    pilot,
    candidate -> snapshot_bundle(candidate; ansi_options, svg_options) == expected;
    timeout_seconds,
    step_seconds,
)

"""Advance virtual widget time until a snapshot-bundle predicate is satisfied."""
wait_for_snapshot_bundle_where!(
    pilot::WidgetPilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    ansi_options::NamedTuple=(;),
    svg_options::NamedTuple=(;),
) = wait_until!(
    pilot,
    candidate -> begin
        result = predicate(snapshot_bundle(candidate; ansi_options, svg_options))
        result isa Bool || throw(ArgumentError("snapshot bundle wait predicate must return Bool"))
        result
    end;
    timeout_seconds,
    step_seconds,
)

function _cell_matches(
    buffer::Buffer,
    row::Integer,
    column::Integer;
    grapheme=missing,
    width=missing,
    continuation=missing,
    style=missing,
    hyperlink=missing,
)
    actual = buffer[row, column]
    checks = (
        (grapheme, actual.grapheme),
        (width, Int(actual.width)),
        (continuation, actual.continuation),
        (style, actual.style),
        (hyperlink, actual.style.hyperlink),
    )
    all(ismissing(expected) || observed == expected for (expected, observed) in checks)
end

"""Advance virtual widget time until a selected cell matches expected properties."""
wait_for_cell!(
    pilot::WidgetPilot,
    row::Integer,
    column::Integer;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
) = wait_until!(
    pilot,
    candidate -> _cell_matches(candidate.backend.screen, row, column; kwargs...);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual widget time until a rendered-buffer predicate is satisfied."""
wait_for_buffer!(
    pilot::WidgetPilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> begin
        result = predicate(candidate.backend.screen)
        result isa Bool || throw(ArgumentError("buffer wait predicate must return Bool"))
        result
    end;
    timeout_seconds,
    step_seconds,
)

"""Headless deterministic driver for a managed `WickedApp`."""
mutable struct RuntimePilot{A<:Runtime.WickedApp}
    app::A
    model::Any
    backend::TestBackend
    terminal::Terminal
    clock::VirtualClock
    process_executor::Any
    queue::Vector{Any}
    pending_delays::Dict{ScheduledToken,Nothing}
    subscription_tokens::Dict{Any,ScheduledToken}
    subscription_specs::Dict{Any,Runtime.AbstractSubscription}
    processed_messages::Vector{Any}
    last_command::Runtime.AbstractCommand
    redraw::Bool
    exited::Bool
    result::Any
end

"""Compact lifecycle and timing status for Toolkit and runtime pilots."""
struct PilotStatus
    virtual_time_ns::UInt64
    pending_scheduled::Int
    exited::Bool
    result::Any
end

Base.:(==)(left::PilotStatus, right::PilotStatus) =
    left.virtual_time_ns == right.virtual_time_ns &&
    left.pending_scheduled == right.pending_scheduled &&
    left.exited == right.exited &&
    left.result == right.result

Base.hash(status::PilotStatus, seed::UInt) =
    hash((status.virtual_time_ns, status.pending_scheduled, status.exited, status.result), seed)

"""Combined status and snapshot evidence captured from a Toolkit or runtime pilot."""
struct PilotEvidenceBundle
    status::PilotStatus
    snapshots::SnapshotBundle
end

Base.:(==)(left::PilotEvidenceBundle, right::PilotEvidenceBundle) =
    left.status == right.status && left.snapshots == right.snapshots

Base.hash(bundle::PilotEvidenceBundle, seed::UInt) =
    hash((bundle.status, bundle.snapshots), seed)

"""Compact status plus snapshot-artifact totals for CI dashboards."""
struct PilotEvidenceSummary
    virtual_time_ns::UInt64
    pending_scheduled::Int
    exited::Bool
    result::Any
    source_kind::Symbol
    snapshot_artifact_count::Int
    snapshot_total_bytes::Int
end

struct _PersistedPilotResult
    text::String
end

Base.:(==)(left::_PersistedPilotResult, right::_PersistedPilotResult) =
    left.text == right.text

Base.hash(result::_PersistedPilotResult, seed::UInt) =
    hash(result.text, seed)

_pilot_result_text(result) =
    result === nothing ? "nothing" :
    result isa _PersistedPilotResult ? result.text :
    repr(result)

Base.:(==)(left::PilotEvidenceSummary, right::PilotEvidenceSummary) =
    left.virtual_time_ns == right.virtual_time_ns &&
    left.pending_scheduled == right.pending_scheduled &&
    left.exited == right.exited &&
    _pilot_result_text(left.result) == _pilot_result_text(right.result) &&
    left.source_kind == right.source_kind &&
    left.snapshot_artifact_count == right.snapshot_artifact_count &&
    left.snapshot_total_bytes == right.snapshot_total_bytes

Base.hash(summary::PilotEvidenceSummary, seed::UInt) =
    hash((
        summary.virtual_time_ns,
        summary.pending_scheduled,
        summary.exited,
        _pilot_result_text(summary.result),
        summary.source_kind,
        summary.snapshot_artifact_count,
        summary.snapshot_total_bytes,
    ), seed)

function RuntimePilot(
    app::A;
    model=_INITIALIZE_RUNTIME_MODEL,
    height::Integer=24,
    width::Integer=80,
    capabilities::TerminalCapabilities=TerminalCapabilities(),
    clock::VirtualClock=VirtualClock(),
    process_executor=Runtime.execute_process,
) where {A<:Runtime.WickedApp}
    resolved_model = model === _INITIALIZE_RUNTIME_MODEL ? Runtime.initialize(app) : model
    backend = TestBackend(height, width; capabilities)
    pilot = RuntimePilot(
        app,
        resolved_model,
        backend,
        Terminal(backend),
        clock,
        process_executor,
        Any[],
        Dict{ScheduledToken,Nothing}(),
        Dict{Any,ScheduledToken}(),
        Dict{Any,Runtime.AbstractSubscription}(),
        Any[],
        Runtime.NoCommand(),
        true,
        false,
        nothing,
    )
    draw!(pilot)
    _sync_pilot_subscriptions!(pilot)
    pilot
end

"""Return the current managed runtime model."""
pilot_model(pilot::RuntimePilot) = pilot.model

"""Return the last command produced by the managed runtime update loop."""
last_command(pilot::RuntimePilot) = pilot.last_command

function _command_matches(command, expected)
    expected isa Type && return command isa expected
    if applicable(expected, command)
        result = expected(command)
        result isa Bool || throw(ArgumentError("command predicate must return Bool"))
        return result
    end
    return command == expected
end

"""Assert that the last managed runtime command matches a type, value, or predicate."""
function assert_command(pilot::RuntimePilot, expected)
    command = last_command(pilot)
    _command_matches(command, expected) || throw(BufferAssertionError(
        "command assertion mismatch: expected $(repr(expected)), got $(repr(command))",
    ))
    pilot
end

"""Advance managed runtime time until the last command matches a type, value, or predicate."""
function wait_for_command!(
    pilot::RuntimePilot,
    expected;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> _command_matches(last_command(candidate), expected);
        timeout_seconds,
        step_seconds,
    )
end

"""Return pending managed runtime messages without clearing them."""
runtime_queue(pilot::RuntimePilot) = copy(pilot.queue)

"""Return managed runtime messages processed by the pilot so far."""
processed_messages(pilot::RuntimePilot) = copy(pilot.processed_messages)

"""Assert that the managed runtime processed-message history exactly matches an expected sequence."""
function assert_processed_messages(pilot::RuntimePilot, expected)
    expected_messages = collect(expected)
    actual = processed_messages(pilot)
    actual == expected_messages || throw(BufferAssertionError(
        "processed message history mismatch: expected $(repr(expected_messages)), got $(repr(actual))",
    ))
    pilot
end

"""Assert that the managed runtime has not processed any messages."""
function assert_no_processed_messages(pilot::RuntimePilot)
    actual = processed_messages(pilot)
    isempty(actual) || throw(BufferAssertionError("processed message history contains $(length(actual)) messages: $(repr(actual))"))
    pilot
end

"""Advance managed runtime time until the processed-message history predicate is satisfied."""
function wait_for_processed_messages!(
    pilot::RuntimePilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> begin
            result = predicate(processed_messages(candidate))
            result isa Bool || throw(ArgumentError("processed message wait predicate must return Bool"))
            result
        end;
        timeout_seconds,
        step_seconds,
    )
end

"""Assert that the pending managed runtime queue exactly matches an expected sequence."""
function assert_runtime_queue(pilot::RuntimePilot, expected)
    expected_messages = collect(expected)
    actual = runtime_queue(pilot)
    actual == expected_messages || throw(BufferAssertionError(
        "runtime queue mismatch: expected $(repr(expected_messages)), got $(repr(actual))",
    ))
    pilot
end

"""Assert that the pending managed runtime queue is empty."""
function assert_no_runtime_queue(pilot::RuntimePilot)
    actual = runtime_queue(pilot)
    isempty(actual) || throw(BufferAssertionError("runtime queue contains $(length(actual)) messages: $(repr(actual))"))
    pilot
end

"""Advance managed runtime time until the pending queue predicate is satisfied."""
function wait_for_runtime_queue!(
    pilot::RuntimePilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> begin
            result = predicate(runtime_queue(candidate))
            result isa Bool || throw(ArgumentError("runtime queue wait predicate must return Bool"))
            result
        end;
        timeout_seconds,
        step_seconds,
    )
end

"""Advance managed runtime time until messages are pending, then return them."""
function wait_runtime_queue!(
    pilot::RuntimePilot;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_for_runtime_queue!(pilot, queued -> !isempty(queued); timeout_seconds, step_seconds)
    runtime_queue(pilot)
end

"""Assert that a managed runtime model predicate is satisfied."""
function assert_model(pilot::RuntimePilot, predicate)
    result = predicate(pilot_model(pilot))
    result isa Bool || throw(ArgumentError("model assertion predicate must return Bool"))
    result || throw(BufferAssertionError("model assertion predicate returned false for $(repr(pilot_model(pilot)))"))
    pilot
end

"""Advance managed runtime time until a model predicate is satisfied."""
function wait_for_model!(
    pilot::RuntimePilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> begin
            result = predicate(pilot_model(candidate))
            result isa Bool || throw(ArgumentError("model wait predicate must return Bool"))
            result
        end;
        timeout_seconds,
        step_seconds,
    )
end

function _schedule_pilot_subscription!(
    pilot::RuntimePilot,
    subscription::Runtime.IntervalSubscription,
)
    id = subscription.id
    token_ref = Ref{ScheduledToken}()
    token = schedule_after!(pilot.clock, subscription.interval_seconds) do _
        get(pilot.subscription_tokens, id, nothing) == token_ref[] || return
        pop!(pilot.subscription_tokens, id, nothing)
        if !pilot.exited && haskey(pilot.subscription_specs, id)
            message = try
                subscription.message isa Function ? subscription.message() : subscription.message
            catch error
                Runtime.RuntimeFailure(:subscription, id, error, catch_backtrace())
            end
            push!(pilot.queue, message)
            _schedule_pilot_subscription!(pilot, pilot.subscription_specs[id])
        end
    end
    token_ref[] = token
    pilot.subscription_tokens[id] = token
    token
end

function _sync_pilot_subscriptions!(pilot::RuntimePilot)
    desired = Runtime._subscription_map(pilot.app, pilot.model)
    for id in setdiff(Set(keys(pilot.subscription_specs)), Set(keys(desired)))
        token = pop!(pilot.subscription_tokens, id, nothing)
        isnothing(token) || cancel_scheduled!(pilot.clock, token)
        pop!(pilot.subscription_specs, id, nothing)
    end
    for (id, subscription) in desired
        subscription isa Runtime.IntervalSubscription ||
            throw(ArgumentError("unsupported subscription type: $(typeof(subscription))"))
        if haskey(pilot.subscription_specs, id)
            current = pilot.subscription_specs[id]
            Runtime._same_subscription(current, subscription) && continue
            token = pop!(pilot.subscription_tokens, id, nothing)
            isnothing(token) || cancel_scheduled!(pilot.clock, token)
        end
        pilot.subscription_specs[id] = subscription
        _schedule_pilot_subscription!(pilot, subscription)
    end
    nothing
end

function _execute_runtime_command!(pilot::RuntimePilot, command::Runtime.ProcessCommand)
    message = try
        result = pilot.process_executor(command)
        resolved = command.on_success(result)
        isnothing(command.id) ? resolved : Runtime.CommandFinished(command.id, resolved)
    catch error
        failure = Runtime.RuntimeFailure(:process, command.id, error, catch_backtrace())
        command.on_error(failure)
    end
    isnothing(message) || pilot.exited || push!(pilot.queue, message)
    nothing
end

"""Render the current managed model through its production `app_view` contract."""
function draw!(pilot::RuntimePilot)
    result = draw!(pilot.terminal) do frame
        Runtime.render_application!(frame, pilot.app, pilot.model)
    end
    pilot.redraw = false
    result
end

function request_exit!(pilot::RuntimePilot, result=nothing)
    pilot.result = result
    pilot.exited = true
    true
end

function _execute_runtime_command!(pilot::RuntimePilot, ::Runtime.NoCommand)
    nothing
end

function _execute_runtime_command!(pilot::RuntimePilot, command::Runtime.MessageCommand)
    pilot.exited || push!(pilot.queue, command.message)
    nothing
end

function _execute_runtime_command!(pilot::RuntimePilot, command::Runtime.DelayCommand)
    token_ref = Ref{ScheduledToken}()
    token = schedule_after!(pilot.clock, command.delay_seconds) do _
        token = token_ref[]
        pop!(pilot.pending_delays, token, nothing)
        pilot.exited || push!(pilot.queue, command.message)
    end
    token_ref[] = token
    pilot.pending_delays[token] = nothing
    nothing
end

function _execute_runtime_command!(pilot::RuntimePilot, command::Runtime.TaskCommand)
    message = try
        value = command.work()
        resolved = command.on_success(value)
        isnothing(command.id) ? resolved : Runtime.CommandFinished(command.id, resolved)
    catch error
        failure = Runtime.RuntimeFailure(:command, command.id, error, catch_backtrace())
        command.on_error(failure)
    end
    pilot.exited || push!(pilot.queue, message)
    nothing
end

function _execute_runtime_command!(pilot::RuntimePilot, command::Runtime.TerminalCommand)
    message = try
        value = command.operation(pilot.terminal)
        resolved = command.on_success(value)
        isnothing(command.id) ? resolved : Runtime.CommandFinished(command.id, resolved)
    catch error
        failure = Runtime.RuntimeFailure(:terminal, command.id, error, catch_backtrace())
        command.on_error(failure)
    end
    isnothing(message) || pilot.exited || push!(pilot.queue, message)
    nothing
end

function _execute_runtime_command!(pilot::RuntimePilot, command::Runtime.SuspendCommand)
    message = try
        leave!(pilot.terminal.backend)
        value = try
            command.operation()
        finally
            enter!(pilot.terminal.backend)
            force_redraw!(pilot.terminal)
            pilot.redraw = true
        end
        resolved = command.on_success(value)
        isnothing(command.id) ? resolved : Runtime.CommandFinished(command.id, resolved)
    catch error
        failure = Runtime.RuntimeFailure(:suspend, command.id, error, catch_backtrace())
        command.on_error(failure)
    end
    isnothing(message) || pilot.exited || push!(pilot.queue, message)
    nothing
end

function _execute_runtime_command!(
    pilot::RuntimePilot,
    command::Clipboard.AbstractClipboardCommand,
)
    message = Clipboard._clipboard_command_message(command)
    isnothing(message) || pilot.exited || push!(pilot.queue, message)
    nothing
end

function _execute_runtime_command!(pilot::RuntimePilot, command::Runtime.BatchCommand)
    for child in command.commands
        _execute_runtime_command!(pilot, child)
    end
    nothing
end

_execute_runtime_command!(pilot::RuntimePilot, command::Runtime.ExitCommand) =
    request_exit!(pilot, command.result)

function _execute_runtime_command!(pilot::RuntimePilot, ::Runtime.FrameCommand)
    pilot.redraw = true
    nothing
end

_execute_runtime_command!(::RuntimePilot, ::Runtime.CancelCommand) = false

function _apply_runtime_message!(pilot::RuntimePilot, message)
    result = Runtime.update!(pilot.app, pilot.model, message)
    command = Runtime.NoCommand()
    if result isa Runtime.UpdateResult
        pilot.model = result.model
        pilot.redraw |= result.redraw
        command = result.command
    elseif result isa Runtime.AbstractCommand
        pilot.redraw = true
        command = result
    elseif isnothing(result)
        pilot.redraw = true
    else
        throw(ArgumentError("update! must return nothing, AbstractCommand, or UpdateResult"))
    end
    pilot.last_command = command
    _execute_runtime_command!(pilot, command)
    nothing
end

function _drain_runtime!(pilot::RuntimePilot; max_messages::Integer=10_000)
    max_messages > 0 || throw(ArgumentError("message limit must be positive"))
    processed = 0
    while !pilot.exited && !isempty(pilot.queue)
        processed < max_messages ||
            throw(ErrorException("runtime pilot message limit exceeded"))
        message = popfirst!(pilot.queue)
        push!(pilot.processed_messages, message)
        _apply_runtime_message!(pilot, message)
        processed += 1
    end
    redrawn = pilot.redraw && !pilot.exited
    pilot.exited || _sync_pilot_subscriptions!(pilot)
    redrawn && draw!(pilot)
    RuntimePilotResult(true, processed, redrawn, pilot.exited, pilot.result)
end

"""Deliver a message and deterministically drain all immediate command messages."""
function send!(pilot::RuntimePilot, message; max_messages::Integer=10_000)
    pilot.exited && return RuntimePilotResult(false, 0, false, true, pilot.result)
    push!(pilot.queue, message)
    _drain_runtime!(pilot; max_messages)
end

"""Advance managed pilot time, run due delays, and drain resulting messages."""
function advance_time!(
    pilot::RuntimePilot,
    elapsed_seconds::Real;
    max_callbacks::Integer=100_000,
    max_messages::Integer=10_000,
)
    advance_time!(pilot.clock, elapsed_seconds; max_callbacks)
    _drain_runtime!(pilot; max_messages)
end

"""Advance virtual runtime time until a predicate is satisfied or the timeout expires."""
wait_until!(
    pilot::RuntimePilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = _wait_until!(
    (candidate, elapsed) -> advance_time!(candidate, elapsed),
    pilot,
    predicate;
    timeout_seconds,
    step_seconds,
)

"""Advance virtual runtime time until visible text appears."""
wait_for_text!(
    pilot::RuntimePilot,
    text;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> _matches_text(plain_snapshot(candidate), text);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual runtime time until the full plain snapshot matches."""
wait_for_plain_snapshot!(
    pilot::RuntimePilot,
    expected::AbstractString;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> plain_snapshot(candidate) == String(expected);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual runtime time until the full ANSI snapshot matches."""
wait_for_ansi_snapshot!(
    pilot::RuntimePilot,
    expected::AbstractString;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
) = wait_until!(
    pilot,
    candidate -> ansi_snapshot(candidate; kwargs...) == String(expected);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual runtime time until the full structured snapshot matches."""
wait_for_structured_snapshot!(
    pilot::RuntimePilot,
    expected;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> structured_snapshot(candidate) == expected;
    timeout_seconds,
    step_seconds,
)

"""Advance virtual runtime time until the full SVG snapshot matches."""
wait_for_svg_snapshot!(
    pilot::RuntimePilot,
    expected::AbstractString;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
) = wait_until!(
    pilot,
    candidate -> svg_snapshot(candidate; kwargs...) == String(expected);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual runtime time until the full snapshot bundle matches."""
wait_for_snapshot_bundle!(
    pilot::RuntimePilot,
    expected::SnapshotBundle;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    ansi_options::NamedTuple=(;),
    svg_options::NamedTuple=(;),
) = wait_until!(
    pilot,
    candidate -> snapshot_bundle(candidate; ansi_options, svg_options) == expected;
    timeout_seconds,
    step_seconds,
)

"""Advance virtual runtime time until a snapshot-bundle predicate is satisfied."""
wait_for_snapshot_bundle_where!(
    pilot::RuntimePilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    ansi_options::NamedTuple=(;),
    svg_options::NamedTuple=(;),
) = wait_until!(
    pilot,
    candidate -> begin
        result = predicate(snapshot_bundle(candidate; ansi_options, svg_options))
        result isa Bool || throw(ArgumentError("snapshot bundle wait predicate must return Bool"))
        result
    end;
    timeout_seconds,
    step_seconds,
)

"""Advance virtual runtime time until a selected cell matches expected properties."""
wait_for_cell!(
    pilot::RuntimePilot,
    row::Integer,
    column::Integer;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
) = wait_until!(
    pilot,
    candidate -> _cell_matches(candidate.backend.screen, row, column; kwargs...);
    timeout_seconds,
    step_seconds,
)

"""Advance virtual runtime time until a rendered-buffer predicate is satisfied."""
wait_for_buffer!(
    pilot::RuntimePilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> begin
        result = predicate(candidate.backend.screen)
        result isa Bool || throw(ArgumentError("buffer wait predicate must return Bool"))
        result
    end;
    timeout_seconds,
    step_seconds,
)

"""A retained element match returned from pilot queries."""
struct ElementMatch
    path::ElementPath
    id::Any
    widget::Any
    state::Any
    area::Rect
    classes::Set{Symbol}
    focused::Bool
end

"""Headless driver for a declarative toolkit tree."""
mutable struct ToolkitPilot
    tree::ToolkitTree
    backend::TestBackend
    terminal::Terminal
    clock::VirtualClock
    messages::Vector{Any}
    last_dispatch::Union{Nothing,DispatchResult}
    exited::Bool
    result::Any
end

function ToolkitPilot(
    root::Element;
    height::Integer=24,
    width::Integer=80,
    styles=nothing,
    capabilities::TerminalCapabilities=TerminalCapabilities(),
    clock::VirtualClock=VirtualClock(),
)
    tree = isnothing(styles) ? ToolkitTree(root) : ToolkitTree(root; styles)
    backend = TestBackend(height, width; capabilities)
    pilot = ToolkitPilot(tree, backend, Terminal(backend), clock, Any[], nothing, false, nothing)
    draw!(pilot)
    pilot
end

"""Record an orderly pilot application exit and its optional result."""
function request_exit!(pilot::ToolkitPilot, result=nothing)
    pilot.result = result
    pilot.exited = true
    true
end

"""Return whether a Toolkit or runtime pilot has requested exit."""
pilot_exited(pilot::Union{ToolkitPilot,RuntimePilot}) = pilot.exited

"""Return the virtual clock time for a Toolkit or runtime pilot."""
virtual_time_ns(pilot::Union{RuntimePilot,ToolkitPilot}) = virtual_time_ns(pilot.clock)

"""Return the number of pending scheduled callbacks for a Toolkit or runtime pilot."""
pending_scheduled(pilot::Union{RuntimePilot,ToolkitPilot}) = pending_scheduled(pilot.clock)

"""Return the exit result recorded by a Toolkit or runtime pilot."""
exit_result(pilot::Union{ToolkitPilot,RuntimePilot}) = pilot.result

"""Return compact lifecycle and timing status for a Toolkit or runtime pilot."""
pilot_status(pilot::Union{RuntimePilot,ToolkitPilot}) =
    PilotStatus(virtual_time_ns(pilot), pending_scheduled(pilot), pilot_exited(pilot), exit_result(pilot))

"""Render a compact human-readable pilot status line."""
function pilot_status_text(status::PilotStatus)
    result = status.result === nothing ? "nothing" : repr(status.result)
    "virtual_time_ns=$(status.virtual_time_ns) pending_scheduled=$(status.pending_scheduled) exited=$(status.exited) result=$result"
end

pilot_status_text(pilot::Union{RuntimePilot,ToolkitPilot}) = pilot_status_text(pilot_status(pilot))

"""Render pilot status as a headered TSV row."""
function pilot_status_tsv(status::PilotStatus)
    result = status.result === nothing ? "nothing" : repr(status.result)
    "virtual_time_ns\tpending_scheduled\texited\tresult\n$(status.virtual_time_ns)\t$(status.pending_scheduled)\t$(status.exited)\t$result"
end

pilot_status_tsv(pilot::Union{RuntimePilot,ToolkitPilot}) = pilot_status_tsv(pilot_status(pilot))

"""Render pilot status as a Markdown table."""
function pilot_status_markdown(status::PilotStatus)
    result = status.result === nothing ? "nothing" : repr(status.result)
    join((
        "| virtual_time_ns | pending_scheduled | exited | result |",
        "|---:|---:|:---:|---|",
        "| $(status.virtual_time_ns) | $(status.pending_scheduled) | $(status.exited) | `$result` |",
    ), "\n")
end

pilot_status_markdown(pilot::Union{RuntimePilot,ToolkitPilot}) = pilot_status_markdown(pilot_status(pilot))

"""Capture pilot status and all snapshot artifacts from the same pilot state."""
pilot_evidence_bundle(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    PilotEvidenceBundle(pilot_status(pilot), snapshot_bundle(pilot; kwargs...))

"""Render a compact human-readable pilot evidence summary."""
function pilot_evidence_text(evidence::PilotEvidenceBundle)
    "$(pilot_status_text(evidence.status)) source_kind=$(evidence.snapshots.source_kind)"
end

pilot_evidence_text(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_text(pilot_evidence_bundle(pilot; kwargs...))

"""Render pilot evidence as a headered TSV row."""
function pilot_evidence_tsv(evidence::PilotEvidenceBundle)
    result = evidence.status.result === nothing ? "nothing" : repr(evidence.status.result)
    join((
        "virtual_time_ns\tpending_scheduled\texited\tresult\tsource_kind",
        "$(evidence.status.virtual_time_ns)\t$(evidence.status.pending_scheduled)\t$(evidence.status.exited)\t$result\t$(evidence.snapshots.source_kind)",
    ), "\n")
end

pilot_evidence_tsv(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_tsv(pilot_evidence_bundle(pilot; kwargs...))

"""Render pilot evidence as a Markdown table."""
function pilot_evidence_markdown(evidence::PilotEvidenceBundle)
    result = evidence.status.result === nothing ? "nothing" : repr(evidence.status.result)
    join((
        "| virtual_time_ns | pending_scheduled | exited | result | source_kind |",
        "|---:|---:|:---:|---|---|",
        "| $(evidence.status.virtual_time_ns) | $(evidence.status.pending_scheduled) | $(evidence.status.exited) | `$result` | `$(evidence.snapshots.source_kind)` |",
    ), "\n")
end

pilot_evidence_markdown(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_markdown(pilot_evidence_bundle(pilot; kwargs...))

"""Return compact pilot status plus snapshot artifact totals."""
function pilot_evidence_summary(evidence::PilotEvidenceBundle)
    snapshots = snapshot_bundle_summary(evidence.snapshots)
    PilotEvidenceSummary(
        evidence.status.virtual_time_ns,
        evidence.status.pending_scheduled,
        evidence.status.exited,
        evidence.status.result,
        snapshots.source_kind,
        snapshots.artifact_count,
        snapshots.total_bytes,
    )
end

pilot_evidence_summary(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_summary(pilot_evidence_bundle(pilot; kwargs...))

function _pilot_status_from_tsv_file(path::AbstractString)
    isfile(path) || throw(BufferAssertionError("missing pilot status TSV artifact: $path"))
    lines = split(chomp(read(path, String)), '\n'; keepempty=false)
    length(lines) == 2 || throw(BufferAssertionError("invalid pilot status TSV artifact: $path"))
    lines[1] == "virtual_time_ns\tpending_scheduled\texited\tresult" ||
        throw(BufferAssertionError("invalid pilot status TSV header: $path"))
    fields = split(lines[2], '\t'; keepempty=true)
    length(fields) == 4 || throw(BufferAssertionError("invalid pilot status TSV row: $path"))
    virtual_time = try
        parse(UInt64, fields[1])
    catch error
        throw(BufferAssertionError("invalid pilot status virtual_time_ns: $(fields[1])"))
    end
    scheduled = try
        parse(Int, fields[2])
    catch error
        throw(BufferAssertionError("invalid pilot status pending_scheduled: $(fields[2])"))
    end
    exited = if fields[3] == "true"
        true
    elseif fields[3] == "false"
        false
    else
        throw(BufferAssertionError("invalid pilot status exited flag: $(fields[3])"))
    end
    result = fields[4] == "nothing" ? nothing : _PersistedPilotResult(String(fields[4]))
    PilotStatus(virtual_time, scheduled, exited, result)
end

"""Return compact pilot evidence metadata from a saved evidence directory."""
function pilot_evidence_artifact_summary(directory::AbstractString; allow_extra::Bool=false)
    verify_pilot_evidence_bundle(directory; allow_extra)
    status = _pilot_status_from_tsv_file(joinpath(directory, "status.tsv"))
    snapshots = snapshot_bundle_artifact_summary(joinpath(directory, "snapshots"))
    PilotEvidenceSummary(
        status.virtual_time_ns,
        status.pending_scheduled,
        status.exited,
        status.result,
        snapshots.source_kind,
        snapshots.artifact_count,
        snapshots.total_bytes,
    )
end

"""Render pilot evidence summary as one stable text line."""
function pilot_evidence_summary_text(summary::PilotEvidenceSummary)
    result = _pilot_result_text(summary.result)
    "virtual_time_ns=$(summary.virtual_time_ns) pending_scheduled=$(summary.pending_scheduled) exited=$(summary.exited) result=$result source_kind=$(summary.source_kind) snapshot_artifact_count=$(summary.snapshot_artifact_count) snapshot_total_bytes=$(summary.snapshot_total_bytes)"
end

pilot_evidence_summary_text(evidence::PilotEvidenceBundle) =
    pilot_evidence_summary_text(pilot_evidence_summary(evidence))

pilot_evidence_summary_text(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_summary_text(pilot_evidence_summary(pilot; kwargs...))

"""Render pilot evidence summary as a stable TSV table."""
function pilot_evidence_summary_tsv(summary::PilotEvidenceSummary; header::Bool=true)
    result = _pilot_result_text(summary.result)
    output = IOBuffer()
    header && println(output, "virtual_time_ns\tpending_scheduled\texited\tresult\tsource_kind\tsnapshot_artifact_count\tsnapshot_total_bytes")
    println(output, "$(summary.virtual_time_ns)\t$(summary.pending_scheduled)\t$(summary.exited)\t$result\t$(summary.source_kind)\t$(summary.snapshot_artifact_count)\t$(summary.snapshot_total_bytes)")
    String(take!(output))
end

pilot_evidence_summary_tsv(evidence::PilotEvidenceBundle; header::Bool=true) =
    pilot_evidence_summary_tsv(pilot_evidence_summary(evidence); header)

pilot_evidence_summary_tsv(pilot::Union{RuntimePilot,ToolkitPilot}; header::Bool=true, kwargs...) =
    pilot_evidence_summary_tsv(pilot_evidence_summary(pilot; kwargs...); header)

"""Render pilot evidence summary as a stable Markdown table."""
function pilot_evidence_summary_markdown(summary::PilotEvidenceSummary)
    result = _pilot_result_text(summary.result)
    join((
        "| virtual_time_ns | pending_scheduled | exited | result | source_kind | snapshot_artifact_count | snapshot_total_bytes |",
        "|---:|---:|:---:|---|---|---:|---:|",
        "| $(summary.virtual_time_ns) | $(summary.pending_scheduled) | $(summary.exited) | `$result` | `$(summary.source_kind)` | $(summary.snapshot_artifact_count) | $(summary.snapshot_total_bytes) |",
    ), "\n")
end

pilot_evidence_summary_markdown(evidence::PilotEvidenceBundle) =
    pilot_evidence_summary_markdown(pilot_evidence_summary(evidence))

pilot_evidence_summary_markdown(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_summary_markdown(pilot_evidence_summary(pilot; kwargs...))

"""Assert that a Toolkit or runtime pilot has requested exit."""
function assert_exited(pilot::Union{ToolkitPilot,RuntimePilot}; result=missing)
    pilot_exited(pilot) || throw(BufferAssertionError("pilot has not requested exit"))
    if !ismissing(result) && exit_result(pilot) != result
        throw(BufferAssertionError(
            "exit result mismatch: expected $(repr(result)), got $(repr(exit_result(pilot)))",
        ))
    end
    pilot
end

"""Assert that a Toolkit or runtime pilot is still running."""
function assert_running(pilot::Union{ToolkitPilot,RuntimePilot})
    pilot_exited(pilot) && throw(BufferAssertionError(
        "pilot has already requested exit with result $(repr(exit_result(pilot)))",
    ))
    pilot
end

"""Advance pilot virtual time until it requests exit."""
function wait_for_exit!(
    pilot::Union{ToolkitPilot,RuntimePilot};
    result=missing,
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> pilot_exited(candidate) && (ismissing(result) || exit_result(candidate) == result);
        timeout_seconds,
        step_seconds,
    )
end

"""Advance pilot virtual time until it is still running."""
function wait_for_running!(
    pilot::Union{ToolkitPilot,RuntimePilot};
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> !pilot_exited(candidate);
        timeout_seconds,
        step_seconds,
    )
end

"""Assert that a pilot has the expected number of scheduled callbacks."""
function assert_pending_scheduled(pilot::Union{ToolkitPilot,RuntimePilot}, expected::Integer)
    actual = pending_scheduled(pilot)
    actual == Int(expected) || throw(BufferAssertionError(
        "pending scheduled callback mismatch: expected $(Int(expected)), got $actual",
    ))
    pilot
end

"""Advance pilot virtual time until the pending scheduled callback count matches."""
function wait_for_pending_scheduled!(
    pilot::Union{ToolkitPilot,RuntimePilot},
    expected::Integer;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> pending_scheduled(candidate) == Int(expected);
        timeout_seconds,
        step_seconds,
    )
end

"""Assert that a pilot virtual clock equals the expected nanosecond timestamp."""
function assert_virtual_time(pilot::Union{ToolkitPilot,RuntimePilot}, expected_ns::Integer)
    actual = virtual_time_ns(pilot)
    actual == UInt64(expected_ns) || throw(BufferAssertionError(
        "virtual time mismatch: expected $(UInt64(expected_ns)), got $actual",
    ))
    pilot
end

"""Advance pilot virtual time until the clock equals the expected nanosecond timestamp."""
function wait_for_virtual_time!(
    pilot::Union{ToolkitPilot,RuntimePilot},
    expected_ns::Integer;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    target = UInt64(expected_ns)
    wait_until!(
        pilot,
        candidate -> virtual_time_ns(candidate) == target;
        timeout_seconds,
        step_seconds,
    )
end

"""Advance pilot time, run due work, dispatch one monotonic tick, and redraw if requested."""
function advance_time!(
    pilot::ToolkitPilot,
    elapsed_seconds::Real;
    max_callbacks::Integer=100_000,
)
    previous = virtual_time_ns(pilot.clock)
    advance_time!(pilot.clock, elapsed_seconds; max_callbacks)
    current = virtual_time_ns(pilot.clock)
    send!(pilot, TickEvent(current, current - previous))
end

"""Render one complete pilot frame through `Terminal#draw!`."""
function draw!(pilot::ToolkitPilot)
    result = draw!(pilot.terminal) do frame
        render!(frame, pilot.tree, frame.area)
    end
    result
end

"""Dispatch an event, retain emitted messages, and redraw when requested."""
function send!(pilot::ToolkitPilot, event::AbstractEvent)
    result = dispatch!(pilot.tree, event)
    pilot.last_dispatch = result
    append!(pilot.messages, result.messages)
    result.redraw && draw!(pilot)
    result
end

"""Send one logical key event."""
function key!(
    pilot::ToolkitPilot,
    key::Symbol;
    text::AbstractString="",
    modifiers::KeyModifiers=NONE,
    kind=KeyPress,
)
    send!(pilot, KeyEvent(Key(key); text, modifiers, kind))
end

function press!(
    pilot::ToolkitPilot,
    key::Symbol;
    text::AbstractString="",
    modifiers::KeyModifiers=NONE,
)
    _combine_dispatch_results(DispatchResult[
        key!(pilot, key; text, modifiers, kind=KeyPress),
        key!(pilot, key; text, modifiers, kind=KeyRelease),
    ])
end

"""Type text as a sequence of grapheme key events."""
function type_text!(pilot::ToolkitPilot, text::AbstractString)
    results = DispatchResult[]
    for grapheme in Unicode.graphemes(text)
        if grapheme == "\n"
            push!(results, key!(pilot, :enter; text="\n"))
        elseif grapheme == "\t"
            push!(results, key!(pilot, :tab; text="\t"))
        else
            push!(results, key!(pilot, :character; text=String(grapheme)))
        end
    end
    results
end

paste!(pilot::ToolkitPilot, text::AbstractString) = send!(pilot, PasteEvent(String(text)))

function mouse!(
    pilot::ToolkitPilot,
    row::Integer,
    column::Integer,
    button::MouseButton,
    action::MouseAction;
    modifiers::KeyModifiers=NONE,
    click_count::Integer=1,
)
    send!(
        pilot,
        MouseEvent(
            Position(row, column),
            button,
            action;
            modifiers,
            click_count,
        ),
    )
end

function click!(
    pilot::ToolkitPilot,
    row::Integer,
    column::Integer;
    button::MouseButton=LeftMouseButton,
    click_count::Integer=1,
)
    mouse!(pilot, row, column, button, MousePress; click_count)
    mouse!(pilot, row, column, button, MouseRelease; click_count)
end

double_click!(pilot::ToolkitPilot, row::Integer, column::Integer; button::MouseButton=LeftMouseButton) =
    click!(pilot, row, column; button, click_count=2)

right_click!(pilot::ToolkitPilot, row::Integer, column::Integer) =
    click!(pilot, row, column; button=RightMouseButton)

scroll_up!(pilot::ToolkitPilot, row::Integer, column::Integer; steps::Integer=1) =
    _combine_dispatch_results(DispatchResult[
        mouse!(pilot, row, column, WheelUpButton, MouseScroll)
        for _ in 1:max(0, Int(steps))
    ])

scroll_down!(pilot::ToolkitPilot, row::Integer, column::Integer; steps::Integer=1) =
    _combine_dispatch_results(DispatchResult[
        mouse!(pilot, row, column, WheelDownButton, MouseScroll)
        for _ in 1:max(0, Int(steps))
    ])

function drag!(
    pilot::ToolkitPilot,
    from_row::Integer,
    from_column::Integer,
    to_row::Integer,
    to_column::Integer;
    button::MouseButton=LeftMouseButton,
)
    _combine_dispatch_results(DispatchResult[
        mouse!(pilot, from_row, from_column, button, MousePress),
        mouse!(pilot, to_row, to_column, button, MouseDrag),
        mouse!(pilot, to_row, to_column, button, MouseRelease),
    ])
end

hover!(pilot::ToolkitPilot, row::Integer, column::Integer) =
    mouse!(pilot, row, column, NoMouseButton, MouseMove)

"""Resize the test backend and render the resulting frame."""
function resize_terminal!(pilot::ToolkitPilot, height::Integer, width::Integer)
    resize_backend!(pilot.backend, height, width)
    draw!(pilot)
end

"""Move toolkit focus directly by element ID."""
function focus_element!(pilot::ToolkitPilot, id)
    changed = focus!(pilot.tree.state.focus, id)
    changed && draw!(pilot)
    changed
end

"""Return the currently focused Toolkit element ID or path."""
focused_element(pilot::ToolkitPilot) = Interaction.focused(pilot.tree.state.focus)

"""Assert that the Toolkit focus manager points at an expected element."""
function assert_focus(pilot::ToolkitPilot, expected)
    actual = focused_element(pilot)
    actual == expected || throw(BufferAssertionError(
        "focus mismatch: expected $(repr(expected)), got $(repr(actual))",
    ))
    pilot
end

"""Assert that the Toolkit focus manager does not point at an element."""
function assert_no_focus(pilot::ToolkitPilot, unexpected)
    actual = focused_element(pilot)
    actual != unexpected || throw(BufferAssertionError(
        "focus mismatch: expected focus to differ from $(repr(unexpected))",
    ))
    pilot
end

"""Advance ToolkitPilot virtual time until focus points at an expected element."""
function wait_for_focus!(
    pilot::ToolkitPilot,
    expected;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> focused_element(candidate) == expected;
        timeout_seconds,
        step_seconds,
    )
end

"""Advance ToolkitPilot virtual time until focus no longer points at an element."""
function wait_for_no_focus!(
    pilot::ToolkitPilot,
    unexpected;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> focused_element(candidate) != unexpected;
        timeout_seconds,
        step_seconds,
    )
end

function _advance_toolkit_wait!(pilot::ToolkitPilot, elapsed_seconds::Real)
    advance_time!(pilot.clock, elapsed_seconds)
    draw!(pilot)
    pilot
end

"""Advance ToolkitPilot virtual time until a predicate is satisfied or the timeout expires."""
wait_until!(
    pilot::ToolkitPilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = _wait_until!(_advance_toolkit_wait!, pilot, predicate; timeout_seconds, step_seconds)

"""Advance ToolkitPilot virtual time until an element query matches at least one element."""
function wait_for_query!(
    pilot::ToolkitPilot;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
)
    _wait_until!(
        _advance_toolkit_wait!,
        pilot,
        candidate -> !isempty(query(candidate; kwargs...));
        timeout_seconds,
        step_seconds,
    )
end

"""Advance ToolkitPilot virtual time until an element query matches no elements."""
function wait_for_no_query!(
    pilot::ToolkitPilot;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
)
    _wait_until!(
        _advance_toolkit_wait!,
        pilot,
        candidate -> isempty(query(candidate; kwargs...));
        timeout_seconds,
        step_seconds,
    )
end

"""Advance ToolkitPilot virtual time until an element query matches, then return all matches."""
function wait_query!(
    pilot::ToolkitPilot;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
)
    wait_for_query!(pilot; timeout_seconds, step_seconds, kwargs...)
    query(pilot; kwargs...)
end

"""Advance ToolkitPilot virtual time until an element query resolves to exactly one element."""
function wait_query_one!(
    pilot::ToolkitPilot;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
)
    wait_for_query!(pilot; timeout_seconds, step_seconds, kwargs...)
    query_one(pilot; kwargs...)
end

"""Advance ToolkitPilot virtual time until rendered text appears in an element."""
function wait_for_text!(
    pilot::ToolkitPilot,
    text;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    _wait_until!(
        _advance_toolkit_wait!,
        pilot,
        candidate -> !isempty(query(candidate; text));
        timeout_seconds,
        step_seconds,
    )
end

"""Advance ToolkitPilot virtual time until the full plain snapshot matches."""
wait_for_plain_snapshot!(
    pilot::ToolkitPilot,
    expected::AbstractString;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> plain_snapshot(candidate) == expected;
    timeout_seconds,
    step_seconds,
)

"""Advance ToolkitPilot virtual time until the full ANSI snapshot matches."""
wait_for_ansi_snapshot!(
    pilot::ToolkitPilot,
    expected::AbstractString;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    capabilities=pilot.backend.capabilities,
) = wait_until!(
    pilot,
    candidate -> ansi_snapshot(candidate; capabilities) == expected;
    timeout_seconds,
    step_seconds,
)

"""Advance ToolkitPilot virtual time until the structured snapshot matches."""
wait_for_structured_snapshot!(
    pilot::ToolkitPilot,
    expected;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> structured_snapshot(candidate) == expected;
    timeout_seconds,
    step_seconds,
)

"""Advance ToolkitPilot virtual time until the SVG snapshot matches."""
wait_for_svg_snapshot!(
    pilot::ToolkitPilot,
    expected::AbstractString;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
) = wait_until!(
    pilot,
    candidate -> svg_snapshot(candidate; kwargs...) == expected;
    timeout_seconds,
    step_seconds,
)

"""Advance ToolkitPilot virtual time until a snapshot bundle matches."""
wait_for_snapshot_bundle!(
    pilot::ToolkitPilot,
    expected;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> snapshot_bundle(candidate) == expected;
    timeout_seconds,
    step_seconds,
)

"""Advance ToolkitPilot virtual time until a snapshot-bundle predicate matches."""
wait_for_snapshot_bundle_where!(
    pilot::ToolkitPilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> predicate(snapshot_bundle(candidate));
    timeout_seconds,
    step_seconds,
)

"""Advance ToolkitPilot virtual time until a selected cell matches expected properties."""
wait_for_cell!(
    pilot::ToolkitPilot,
    row::Integer,
    column::Integer;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
    kwargs...,
) = wait_until!(
    pilot,
    candidate -> _cell_matches(candidate.backend.screen, row, column; kwargs...);
    timeout_seconds,
    step_seconds,
)

"""Advance ToolkitPilot virtual time until a rendered-buffer predicate is satisfied."""
wait_for_buffer!(
    pilot::ToolkitPilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
) = wait_until!(
    pilot,
    candidate -> begin
        result = predicate(candidate.backend.screen)
        result isa Bool || throw(ArgumentError("buffer wait predicate must return Bool"))
        result
    end;
    timeout_seconds,
    step_seconds,
)

function _matches_type(widget, requested)
    isnothing(requested) && return true
    isnothing(widget) && return false
    try
        typeof(widget) <: requested
    catch
        typeof(widget) == requested
    end
end

function _element_text(pilot::ToolkitPilot, area::Rect)
    clipped = intersection(pilot.backend.screen.area, area)
    rows = String[]
    for row in clipped.row:(clipped.row + clipped.height - 1)
        output = IOBuffer()
        for column in clipped.column:(clipped.column + clipped.width - 1)
            cell = pilot.backend.screen[row, column]
            cell.continuation || print(output, cell.grapheme)
        end
        push!(rows, rstrip(String(take!(output))))
    end
    join(rows, '\n')
end

function _matches_text(rendered::String, requested)
    isnothing(requested) && return true
    requested isa AbstractString && return occursin(requested, rendered)
    requested isa Regex && return occursin(requested, rendered)
    if requested isa Function
        result = requested(rendered)
        result isa Bool || throw(ArgumentError("text query predicate must return Bool"))
        return result
    end
    throw(ArgumentError("text query must be a string, regex, function, or nothing"))
end

function _matches_state(value, requested)
    ismissing(requested) && return true
    requested isa Type && return value isa requested
    if requested isa Function
        result = requested(value)
        result isa Bool || throw(ArgumentError("state query predicate must return Bool"))
        return result
    end
    isequal(value, requested)
end

"""Query retained elements by identity, type, class, rendered text, state, and focus."""
function query(
    pilot::ToolkitPilot;
    id=nothing,
    widget_type=nothing,
    class::Union{Nothing,Symbol}=nothing,
    text=nothing,
    state=missing,
    focused::Union{Nothing,Bool}=nothing,
)
    matches = ElementMatch[]
    focus_id = Interaction.focused(pilot.tree.state.focus)
    for path in pilot.tree.state.paint_order
        instance = pilot.tree.state.instances[path]
        element = instance.element
        target = isnothing(element.id) ? path : element.id
        !isnothing(id) && element.id != id && continue
        _matches_type(element.widget, widget_type) || continue
        !isnothing(class) && !(class in element.classes) && continue
        _matches_text(_element_text(pilot, instance.area), text) || continue
        _matches_state(instance.state, state) || continue
        is_focused = target == focus_id
        !isnothing(focused) && is_focused != focused && continue
        push!(
            matches,
            ElementMatch(
                path,
                element.id,
                element.widget,
                instance.state,
                instance.area,
                copy(element.classes),
                is_focused,
            ),
        )
    end
    matches
end

function query_one(pilot::ToolkitPilot; kwargs...)
    matches = query(pilot; kwargs...)
    isempty(matches) && throw(KeyError("no element matched the query"))
    length(matches) == 1 || throw(ArgumentError("query matched more than one element"))
    first(matches)
end

"""Assert that a retained Toolkit element query matches at least one element."""
function assert_query(pilot::ToolkitPilot; kwargs...)
    matches = query(pilot; kwargs...)
    isempty(matches) && throw(BufferAssertionError("element query matched no elements"))
    matches
end

"""Assert that a retained Toolkit element query matches exactly one element."""
function assert_query_one(pilot::ToolkitPilot; kwargs...)
    matches = query(pilot; kwargs...)
    isempty(matches) && throw(BufferAssertionError("element query matched no elements"))
    length(matches) == 1 || throw(BufferAssertionError("element query matched $(length(matches)) elements; expected exactly one"))
    first(matches)
end

"""Assert that a retained Toolkit element query matches no elements."""
function assert_no_query(pilot::ToolkitPilot; kwargs...)
    matches = query(pilot; kwargs...)
    isempty(matches) || throw(BufferAssertionError("element query matched $(length(matches)) elements; expected none"))
    pilot
end

"""Return queued application messages without clearing them."""
messages(pilot::ToolkitPilot) = copy(pilot.messages)

"""Assert that a queued-message predicate is satisfied."""
function assert_message(pilot::ToolkitPilot, predicate)
    queued = messages(pilot)
    result = predicate(queued)
    result isa Bool || throw(ArgumentError("message assertion predicate must return Bool"))
    result || throw(BufferAssertionError("message assertion predicate returned false for $(repr(queued))"))
    pilot
end

"""Assert that queued ToolkitPilot messages exactly match an expected sequence."""
function assert_messages(pilot::ToolkitPilot, expected)
    expected_messages = collect(expected)
    actual = messages(pilot)
    actual == expected_messages || throw(BufferAssertionError(
        "message queue mismatch: expected $(repr(expected_messages)), got $(repr(actual))",
    ))
    pilot
end

"""Assert that no ToolkitPilot messages are queued."""
function assert_no_messages(pilot::ToolkitPilot)
    actual = messages(pilot)
    isempty(actual) || throw(BufferAssertionError("message queue contains $(length(actual)) messages: $(repr(actual))"))
    pilot
end

"""Advance ToolkitPilot virtual time until the message queue predicate is satisfied."""
function wait_for_message!(
    pilot::ToolkitPilot,
    predicate;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_until!(
        pilot,
        candidate -> begin
            result = predicate(messages(candidate))
            result isa Bool || throw(ArgumentError("message wait predicate must return Bool"))
            result
        end;
        timeout_seconds,
        step_seconds,
    )
end

"""Advance ToolkitPilot virtual time until messages are queued, then return them."""
function wait_messages!(
    pilot::ToolkitPilot;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_for_message!(pilot, queued -> !isempty(queued); timeout_seconds, step_seconds)
    messages(pilot)
end

"""Advance ToolkitPilot virtual time until no messages are queued."""
function wait_for_no_messages!(
    pilot::ToolkitPilot;
    timeout_seconds::Real=1,
    step_seconds::Real=0.016,
)
    wait_for_message!(pilot, isempty; timeout_seconds, step_seconds)
end

"""Take and clear all application messages emitted since the last call."""
function take_messages!(pilot::ToolkitPilot)
    values = copy(pilot.messages)
    empty!(pilot.messages)
    values
end

"""Return visible text from a buffer with trailing row whitespace removed."""
function plain_snapshot(buffer::Buffer)
    rows = String[]
    for row in buffer.area.row:(buffer.area.row + buffer.area.height - 1)
        output = IOBuffer()
        for column in buffer.area.column:(buffer.area.column + buffer.area.width - 1)
            cell = buffer[row, column]
            cell.continuation || print(output, cell.grapheme)
        end
        push!(rows, rstrip(String(take!(output))))
    end
    join(rows, '\n')
end

plain_snapshot(pilot::ToolkitPilot) = plain_snapshot(pilot.backend.screen)
plain_snapshot(pilot::RuntimePilot) = plain_snapshot(pilot.backend.screen)
plain_snapshot(pilot::WidgetPilot) = plain_snapshot(pilot.backend.screen)

"""Return every cell as stable serializable named tuples."""
function structured_snapshot(buffer::Buffer)
    [
        (
            row=row,
            column=column,
            grapheme=cell.grapheme,
            width=Int(cell.width),
            continuation=cell.continuation,
            foreground=(UInt8(cell.style.foreground.kind), cell.style.foreground.value),
            background=(UInt8(cell.style.background.kind), cell.style.background.value),
            modifiers=cell.style.modifiers.bits,
            hyperlink=cell.style.hyperlink,
        )
        for row in buffer.area.row:(buffer.area.row + buffer.area.height - 1)
        for column in buffer.area.column:(buffer.area.column + buffer.area.width - 1)
        for cell in (buffer[row, column],)
    ]
end

structured_snapshot(pilot::ToolkitPilot) = structured_snapshot(pilot.backend.screen)
structured_snapshot(pilot::RuntimePilot) = structured_snapshot(pilot.backend.screen)
structured_snapshot(pilot::WidgetPilot) = structured_snapshot(pilot.backend.screen)

"""Serialize a buffer as deterministic ANSI-styled text without cursor movement."""
function ansi_snapshot(
    buffer::Buffer;
    capabilities::TerminalCapabilities=TerminalCapabilities(color_level=:truecolor),
)
    isempty(buffer.cells) && return ""
    output = IOBuffer()
    current_style = Style()
    current_hyperlink = nothing
    emitted_style = false
    first_row = true
    for row in buffer.area.row:(buffer.area.row + buffer.area.height - 1)
        first_row || print(output, '\n')
        first_row = false
        for column in buffer.area.column:(buffer.area.column + buffer.area.width - 1)
            cell = buffer[row, column]
            cell.continuation && continue
            if cell.style.hyperlink != current_hyperlink
                Backends._write_hyperlink(output, cell.style.hyperlink)
                current_hyperlink = cell.style.hyperlink
            end
            if cell.style != current_style
                Backends._write_style(output, cell.style, capabilities)
                current_style = cell.style
                emitted_style = true
            end
            print(output, cell.grapheme)
        end
    end
    !isnothing(current_hyperlink) && Backends._write_hyperlink(output, nothing)
    emitted_style && print(output, "\e[0m")
    String(take!(output))
end

ansi_snapshot(pilot::ToolkitPilot; capabilities=pilot.backend.capabilities) =
    ansi_snapshot(pilot.backend.screen; capabilities)
ansi_snapshot(pilot::RuntimePilot; capabilities=pilot.backend.capabilities) =
    ansi_snapshot(pilot.backend.screen; capabilities)
ansi_snapshot(pilot::WidgetPilot; capabilities=pilot.backend.capabilities) =
    ansi_snapshot(pilot.backend.screen; capabilities)

"""Assert complete styled-cell equality at one buffer coordinate."""
function assert_cell(buffer::Buffer, row::Integer, column::Integer, expected::Cell)
    actual = buffer[row, column]
    actual == expected || throw(BufferAssertionError(
        "cell ($row, $column) mismatch: expected $(repr(expected)), got $(repr(actual))",
    ))
    actual
end

assert_cell(
    pilot::Union{WidgetPilot,ToolkitPilot,RuntimePilot},
    row::Integer,
    column::Integer,
    expected::Cell,
) = assert_cell(pilot.backend.screen, row, column, expected)

"""Assert selected cell properties while leaving unspecified properties unconstrained."""
function assert_cell(
    buffer::Buffer,
    row::Integer,
    column::Integer;
    grapheme=missing,
    width=missing,
    continuation=missing,
    style=missing,
    hyperlink=missing,
)
    actual = buffer[row, column]
    checks = (
        (:grapheme, grapheme, actual.grapheme),
        (:width, width, Int(actual.width)),
        (:continuation, continuation, actual.continuation),
        (:style, style, actual.style),
        (:hyperlink, hyperlink, actual.style.hyperlink),
    )
    for (name, expected, observed) in checks
        ismissing(expected) && continue
        observed == expected || throw(BufferAssertionError(
            "cell ($row, $column) $name mismatch: expected $(repr(expected)), got $(repr(observed))",
        ))
    end
    actual
end

assert_cell(
    pilot::Union{WidgetPilot,ToolkitPilot,RuntimePilot},
    row::Integer,
    column::Integer;
    kwargs...,
) = assert_cell(pilot.backend.screen, row, column; kwargs...)

_assertion_buffer(source::Buffer) = source
_assertion_buffer(source::Union{WidgetPilot,ToolkitPilot,RuntimePilot}) = source.backend.screen

"""Assert that a rendered-buffer predicate is satisfied."""
function assert_buffer(source, predicate)
    buffer = _assertion_buffer(source)
    result = predicate(buffer)
    result isa Bool || throw(ArgumentError("buffer assertion predicate must return Bool"))
    result || throw(BufferAssertionError("buffer assertion predicate returned false"))
    source
end

"""Assert a stable plain-text buffer snapshot."""
function assert_plain_snapshot(source, expected::AbstractString)
    actual = plain_snapshot(source)
    actual == expected || throw(BufferAssertionError(
        _snapshot_mismatch_message("plain snapshot", String(expected), actual),
    ))
    source
end

"""Assert a stable ANSI buffer snapshot."""
function assert_ansi_snapshot(source, expected::AbstractString; kwargs...)
    actual = ansi_snapshot(source; kwargs...)
    actual == expected || throw(BufferAssertionError(
        _snapshot_mismatch_message("ANSI snapshot", String(expected), actual),
    ))
    source
end

"""Assert stable cell-level structured snapshot data."""
function assert_structured_snapshot(source, expected)
    actual = structured_snapshot(source)
    actual == expected || throw(BufferAssertionError(
        _snapshot_mismatch_message("structured snapshot", expected, actual),
    ))
    source
end

function _short_repr(value; limit::Integer=240)
    text = repr(value)
    limit > 0 || return ""
    length(text) <= limit && return text
    index = firstindex(text)
    for _ in 1:(limit - 1)
        index == lastindex(text) && break
        index = nextind(text, index)
    end
    return text[begin:index] * "..."
end

function _line_column_difference(expected::AbstractString, actual::AbstractString)
    expected_lines = split(expected, '\n'; keepempty=true)
    actual_lines = split(actual, '\n'; keepempty=true)
    total = max(length(expected_lines), length(actual_lines))
    for line in 1:total
        line <= length(expected_lines) || return "first difference at line $line: expected <missing>, actual $(_short_repr(actual_lines[line]))"
        line <= length(actual_lines) || return "first difference at line $line: expected $(_short_repr(expected_lines[line])), actual <missing>"
        expected_line = expected_lines[line]
        actual_line = actual_lines[line]
        expected_line == actual_line && continue
        expected_chars = collect(expected_line)
        actual_chars = collect(actual_line)
        width = max(length(expected_chars), length(actual_chars))
        column = findfirst(index -> index > length(expected_chars) || index > length(actual_chars) || expected_chars[index] != actual_chars[index], 1:width)
        isnothing(column) && (column = 1)
        return "first difference at line $line, column $column: expected $(_short_repr(expected_line)), actual $(_short_repr(actual_line))"
    end
    return "values differ"
end

function _sequence_difference(expected::AbstractVector, actual::AbstractVector)
    total = max(length(expected), length(actual))
    for index in 1:total
        index <= length(expected) || return "first difference at index $index: expected <missing>, actual $(_short_repr(actual[index]))"
        index <= length(actual) || return "first difference at index $index: expected $(_short_repr(expected[index])), actual <missing>"
        expected[index] == actual[index] && continue
        return "first difference at index $index: expected $(_short_repr(expected[index])), actual $(_short_repr(actual[index]))"
    end
    return "values differ"
end

function _named_tuple_difference(expected::NamedTuple, actual::NamedTuple)
    expected_names = propertynames(expected)
    actual_names = propertynames(actual)
    expected_names == actual_names || return "fields differ: expected $(expected_names), actual $(actual_names)"
    for name in expected_names
        expected_value = getproperty(expected, name)
        actual_value = getproperty(actual, name)
        expected_value == actual_value && continue
        return "first difference at field :$name: $(_snapshot_difference(expected_value, actual_value))"
    end
    return "values differ"
end

function _snapshot_difference(expected, actual)
    expected isa AbstractString && actual isa AbstractString && return _line_column_difference(expected, actual)
    expected isa AbstractVector && actual isa AbstractVector && return _sequence_difference(expected, actual)
    expected isa NamedTuple && actual isa NamedTuple && return _named_tuple_difference(expected, actual)
    return "values differ"
end

function _snapshot_mismatch_message(kind::AbstractString, expected, actual)
    "$(kind) mismatch: $(_snapshot_difference(expected, actual))\nexpected: $(_short_repr(expected))\nactual:   $(_short_repr(actual))"
end

function _xml_escape(value::AbstractString)
    replace(value, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")
end

const _ANSI_RGB = [
    (0, 0, 0), (205, 49, 49), (13, 188, 121), (229, 229, 16),
    (36, 114, 200), (188, 63, 188), (17, 168, 205), (229, 229, 229),
    (102, 102, 102), (241, 76, 76), (35, 209, 139), (245, 245, 67),
    (59, 142, 234), (214, 112, 214), (41, 184, 219), (255, 255, 255),
]

function _svg_color(color::Color, default::String)
    kind = UInt8(color.kind)
    kind == 0 && return default
    if kind == 1
        red, green, blue = _ANSI_RGB[Int(color.value) + 1]
    elseif kind == 3
        red = Int((color.value >> 16) & 0xff)
        green = Int((color.value >> 8) & 0xff)
        blue = Int(color.value & 0xff)
    else
        index = Int(color.value)
        if index < 16
            red, green, blue = _ANSI_RGB[index + 1]
        elseif index <= 231
            cube = index - 16
            red = div(cube, 36) * 51
            green = div(mod(cube, 36), 6) * 51
            blue = mod(cube, 6) * 51
        else
            red = green = blue = 8 + (index - 232) * 10
        end
    end
    string('#', uppercase(string(red, base=16, pad=2)), uppercase(string(green, base=16, pad=2)), uppercase(string(blue, base=16, pad=2)))
end

"""Export a buffer as a standalone monospace SVG document."""
function svg_snapshot(
    buffer::Buffer;
    cell_width::Integer=9,
    cell_height::Integer=18,
    background::AbstractString="#101418",
    foreground::AbstractString="#E6EDF3",
    font_family::AbstractString="monospace",
)
    width = buffer.area.width * Int(cell_width)
    height = buffer.area.height * Int(cell_height)
    output = IOBuffer()
    print(
        output,
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"", width,
        "\" height=\"", height, "\" viewBox=\"0 0 ", width, ' ', height, "\">",
        "<rect width=\"100%\" height=\"100%\" fill=\"", _xml_escape(background), "\"/>",
        "<g font-family=\"", _xml_escape(font_family), "\" font-size=\"14\">",
    )
    for row in buffer.area.row:(buffer.area.row + buffer.area.height - 1),
        column in buffer.area.column:(buffer.area.column + buffer.area.width - 1)
        cell = buffer[row, column]
        cell.continuation && continue
        x = (column - buffer.area.column) * Int(cell_width)
        y = (row - buffer.area.row + 1) * Int(cell_height) - 4
        background_color = _svg_color(cell.style.background, "none")
        background_color != "none" && print(
            output,
            "<rect x=\"", x, "\" y=\"", y - Int(cell_height) + 4,
            "\" width=\"", Int(cell_width) * Int(cell.width), "\" height=\"", cell_height,
            "\" fill=\"", background_color, "\"/>",
        )
        cell.grapheme == " " && continue
        print(
            output,
            "<text x=\"", x, "\" y=\"", y, "\" fill=\"",
            _svg_color(cell.style.foreground, String(foreground)), "\">",
            _xml_escape(cell.grapheme), "</text>",
        )
    end
    print(output, "</g></svg>")
    String(take!(output))
end

svg_snapshot(pilot::ToolkitPilot; kwargs...) = svg_snapshot(pilot.backend.screen; kwargs...)
svg_snapshot(pilot::RuntimePilot; kwargs...) = svg_snapshot(pilot.backend.screen; kwargs...)
svg_snapshot(pilot::WidgetPilot; kwargs...) = svg_snapshot(pilot.backend.screen; kwargs...)

_snapshot_source_kind(::Buffer) = :buffer
_snapshot_source_kind(::WidgetPilot) = :widget_pilot
_snapshot_source_kind(::ToolkitPilot) = :toolkit_pilot
_snapshot_source_kind(::RuntimePilot) = :runtime_pilot
_snapshot_source_kind(_) = :unknown

"""Capture plain, ANSI, structured, and SVG snapshots in one stable bundle."""
function snapshot_bundle(
    source;
    ansi_options::NamedTuple=(;),
    svg_options::NamedTuple=(;),
)
    SnapshotBundle(
        _snapshot_source_kind(source),
        plain_snapshot(source),
        ansi_snapshot(source; ansi_options...),
        structured_snapshot(source),
        svg_snapshot(source; svg_options...),
    )
end

"""Return deterministic file contents for a snapshot bundle artifact directory."""
function snapshot_bundle_payloads(bundle::SnapshotBundle)
    Dict(
        "plain.txt" => bundle.plain,
        "ansi.txt" => bundle.ansi,
        "structured.txt" => repr(bundle.structured),
        "frame.svg" => bundle.svg,
    )
end

function _sha256_hex(value::AbstractString)
    bytes2hex(sha256(Vector{UInt8}(codeunits(value))))
end

"""Return typed integrity records for snapshot bundle payload files."""
function snapshot_bundle_manifest_records(bundle::SnapshotBundle)
    payloads = snapshot_bundle_payloads(bundle)
    SnapshotArtifactRecord[
        SnapshotArtifactRecord(name, sizeof(payloads[name]), _sha256_hex(payloads[name]))
        for name in sort!(collect(keys(payloads)))
    ]
end

"""Render snapshot bundle manifest records as a stable TSV table."""
function snapshot_manifest_records_tsv(records; header::Bool=true)
    output = IOBuffer()
    header && println(output, "name\tbytes\tsha256")
    for record in records
        println(output, "$(record.name)\t$(record.bytes)\t$(record.sha256)")
    end
    String(take!(output))
end

snapshot_bundle_manifest_tsv(bundle::SnapshotBundle; header::Bool=true) =
    snapshot_manifest_records_tsv(snapshot_bundle_manifest_records(bundle); header)

snapshot_bundle_artifact_manifest_tsv(directory::AbstractString; header::Bool=true) =
    snapshot_manifest_records_tsv(read_snapshot_bundle_manifest_records(directory); header)

"""Render snapshot bundle manifest records as a stable Markdown table."""
function snapshot_manifest_records_markdown(records)
    output = IOBuffer()
    println(output, "| `name` | `bytes` | `sha256` |")
    println(output, "|---|---:|---|")
    for record in records
        println(output, "| `$(record.name)` | $(record.bytes) | `$(record.sha256)` |")
    end
    String(take!(output))
end

snapshot_bundle_manifest_markdown(bundle::SnapshotBundle) =
    snapshot_manifest_records_markdown(snapshot_bundle_manifest_records(bundle))

snapshot_bundle_artifact_manifest_markdown(directory::AbstractString) =
    snapshot_manifest_records_markdown(read_snapshot_bundle_manifest_records(directory))

"""Return a deterministic manifest for snapshot bundle artifact files."""
function snapshot_bundle_manifest(bundle::SnapshotBundle)
    lines = ["source_kind=$(bundle.source_kind)"]
    for record in snapshot_bundle_manifest_records(bundle)
        push!(lines, "$(record.name)\tbytes=$(record.bytes)\tsha256=$(record.sha256)")
    end
    join(lines, '\n') * "\n"
end

"""Return deterministic file contents for a snapshot bundle artifact directory."""
function snapshot_bundle_artifacts(bundle::SnapshotBundle)
    artifacts = snapshot_bundle_payloads(bundle)
    artifacts["manifest.txt"] = snapshot_bundle_manifest(bundle)
    artifacts
end

"""Write a snapshot bundle artifact directory for CI or release review."""
function write_snapshot_bundle(
    directory::AbstractString,
    bundle::SnapshotBundle;
    overwrite::Bool=false,
)
    isempty(strip(directory)) && throw(ArgumentError("snapshot bundle directory must not be empty"))
    artifacts = snapshot_bundle_artifacts(bundle)
    mkpath(directory)
    written = Dict{String,String}()
    for name in sort!(collect(keys(artifacts)))
        path = joinpath(directory, name)
        if isfile(path) && !overwrite
            throw(ArgumentError("snapshot bundle artifact already exists: $path"))
        end
        write(path, artifacts[name])
        written[name] = path
    end
    written
end

function write_snapshot_bundle(
    directory::AbstractString,
    source;
    overwrite::Bool=false,
    ansi_options::NamedTuple=(;),
    svg_options::NamedTuple=(;),
)
    write_snapshot_bundle(
        directory,
        snapshot_bundle(source; ansi_options, svg_options);
        overwrite,
    )
end

"""Write pilot status summaries and snapshot artifacts for CI or release review."""
function write_pilot_evidence_bundle(
    directory::AbstractString,
    evidence::PilotEvidenceBundle;
    overwrite::Bool=false,
)
    isempty(strip(directory)) && throw(ArgumentError("pilot evidence directory must not be empty"))
    mkpath(directory)
    artifacts = _pilot_evidence_artifacts_with_manifest(evidence)
    written = Dict{String,String}()
    for name in sort!(collect(keys(artifacts)))
        path = joinpath(directory, name)
        if isfile(path) && !overwrite
            throw(ArgumentError("pilot evidence artifact already exists: $path"))
        end
        write(path, artifacts[name])
        written[name] = path
    end
    snapshot_paths = write_snapshot_bundle(joinpath(directory, "snapshots"), evidence.snapshots; overwrite)
    for (name, path) in snapshot_paths
        written[joinpath("snapshots", name)] = path
    end
    written
end

function write_pilot_evidence_bundle(
    directory::AbstractString,
    pilot::Union{RuntimePilot,ToolkitPilot};
    overwrite::Bool=false,
    kwargs...,
)
    write_pilot_evidence_bundle(directory, pilot_evidence_bundle(pilot; kwargs...); overwrite)
end

"""Return derived pilot evidence report files for dashboards and release notes."""
function pilot_evidence_report_artifacts(evidence::PilotEvidenceBundle)
    summary = pilot_evidence_summary(evidence)
    Dict(
        "manifest.tsv" => pilot_evidence_manifest_tsv(evidence),
        "manifest.md" => pilot_evidence_manifest_markdown(evidence),
        "summary.txt" => pilot_evidence_summary_text(summary),
        "summary.tsv" => pilot_evidence_summary_tsv(summary),
        "summary.md" => pilot_evidence_summary_markdown(summary),
    )
end

pilot_evidence_report_artifacts(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_report_artifacts(pilot_evidence_bundle(pilot; kwargs...))

pilot_evidence_report_artifacts(directory::AbstractString; allow_extra::Bool=false) =
    _pilot_evidence_report_artifacts_from_directory(directory; allow_extra)

function pilot_evidence_report_artifacts(summary::PilotEvidenceSummary)
    Dict(
        "summary.txt" => pilot_evidence_summary_text(summary),
        "summary.tsv" => pilot_evidence_summary_tsv(summary),
        "summary.md" => pilot_evidence_summary_markdown(summary),
    )
end

function _pilot_evidence_report_artifacts_from_directory(directory::AbstractString; allow_extra::Bool=false)
    reports = pilot_evidence_report_artifacts(pilot_evidence_artifact_summary(directory; allow_extra))
    reports["manifest.tsv"] = pilot_evidence_artifact_manifest_tsv(directory)
    reports["manifest.md"] = pilot_evidence_artifact_manifest_markdown(directory)
    reports
end

"""Return typed integrity records for derived pilot evidence report files."""
function pilot_evidence_report_manifest_records(evidence::PilotEvidenceBundle)
    reports = pilot_evidence_report_artifacts(evidence)
    SnapshotArtifactRecord[
        SnapshotArtifactRecord(name, sizeof(reports[name]), _sha256_hex(reports[name]))
        for name in sort!(collect(keys(reports)))
    ]
end

pilot_evidence_report_manifest_records(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_report_manifest_records(pilot_evidence_bundle(pilot; kwargs...))

_pilot_evidence_report_required_files() =
    Set(["manifest.tsv", "manifest.md", "summary.txt", "summary.tsv", "summary.md"])

"""Verify written pilot evidence report files for dashboards and release notes."""
function verify_pilot_evidence_report_artifacts(directory::AbstractString; allow_extra::Bool=false)
    isdir(directory) ||
        throw(BufferAssertionError("pilot evidence report directory does not exist: $directory"))
    expected_files = _pilot_evidence_report_required_files()
    actual_entries = Set(readdir(directory))
    if !allow_extra
        extra = sort!(collect(setdiff(actual_entries, expected_files)))
        isempty(extra) || throw(BufferAssertionError(
            "unexpected pilot evidence report artifacts: $(join(extra, ", "))",
        ))
    end
    for name in sort!(collect(expected_files))
        path = joinpath(directory, name)
        isfile(path) || throw(BufferAssertionError("missing pilot evidence report artifact: $path"))
    end
    true
end

"""Read typed integrity records from a written pilot evidence report directory."""
function read_pilot_evidence_report_manifest_records(directory::AbstractString; allow_extra::Bool=false)
    verify_pilot_evidence_report_artifacts(directory; allow_extra)
    records = SnapshotArtifactRecord[]
    for name in sort!(collect(_pilot_evidence_report_required_files()))
        content = read(joinpath(directory, name), String)
        push!(records, SnapshotArtifactRecord(name, sizeof(content), _sha256_hex(content)))
    end
    records
end

"""Return compact source-kind, report-count, and byte-count metadata for expected pilot evidence reports."""
function pilot_evidence_report_summary(evidence::PilotEvidenceBundle)
    _snapshot_artifact_summary(:pilot_evidence_reports, pilot_evidence_report_manifest_records(evidence))
end

pilot_evidence_report_summary(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_report_summary(pilot_evidence_bundle(pilot; kwargs...))

"""Return compact source-kind, report-count, and byte-count metadata for saved pilot evidence reports."""
function pilot_evidence_report_artifact_summary(directory::AbstractString; allow_extra::Bool=false)
    _snapshot_artifact_summary(:pilot_evidence_reports, read_pilot_evidence_report_manifest_records(directory; allow_extra))
end

"""Render expected pilot evidence report summary as one stable text line."""
pilot_evidence_report_summary_text(evidence::PilotEvidenceBundle) =
    snapshot_artifact_summary_text(pilot_evidence_report_summary(evidence))

pilot_evidence_report_summary_text(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_report_summary_text(pilot_evidence_bundle(pilot; kwargs...))

"""Render saved pilot evidence report summary as one stable text line."""
pilot_evidence_report_artifact_summary_text(directory::AbstractString; allow_extra::Bool=false) =
    snapshot_artifact_summary_text(pilot_evidence_report_artifact_summary(directory; allow_extra))

"""Render expected pilot evidence report summary as a stable TSV table."""
pilot_evidence_report_summary_tsv(evidence::PilotEvidenceBundle; header::Bool=true) =
    snapshot_artifact_summary_tsv(pilot_evidence_report_summary(evidence); header)

pilot_evidence_report_summary_tsv(pilot::Union{RuntimePilot,ToolkitPilot}; header::Bool=true, kwargs...) =
    pilot_evidence_report_summary_tsv(pilot_evidence_bundle(pilot; kwargs...); header)

"""Render saved pilot evidence report summary as a stable TSV table."""
pilot_evidence_report_artifact_summary_tsv(directory::AbstractString; header::Bool=true, allow_extra::Bool=false) =
    snapshot_artifact_summary_tsv(pilot_evidence_report_artifact_summary(directory; allow_extra); header)

"""Render expected pilot evidence report summary as a stable Markdown table."""
pilot_evidence_report_summary_markdown(evidence::PilotEvidenceBundle) =
    snapshot_artifact_summary_markdown(pilot_evidence_report_summary(evidence))

pilot_evidence_report_summary_markdown(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_report_summary_markdown(pilot_evidence_bundle(pilot; kwargs...))

"""Render saved pilot evidence report summary as a stable Markdown table."""
pilot_evidence_report_artifact_summary_markdown(directory::AbstractString; allow_extra::Bool=false) =
    snapshot_artifact_summary_markdown(pilot_evidence_report_artifact_summary(directory; allow_extra))

"""Render expected pilot evidence report manifest records as a stable TSV table."""
function pilot_evidence_report_manifest_tsv(evidence::PilotEvidenceBundle; header::Bool=true)
    snapshot_manifest_records_tsv(pilot_evidence_report_manifest_records(evidence); header)
end

pilot_evidence_report_manifest_tsv(pilot::Union{RuntimePilot,ToolkitPilot}; header::Bool=true, kwargs...) =
    pilot_evidence_report_manifest_tsv(pilot_evidence_bundle(pilot; kwargs...); header)

"""Render written pilot evidence report manifest records as a stable TSV table."""
function pilot_evidence_report_artifact_manifest_tsv(directory::AbstractString; header::Bool=true, allow_extra::Bool=false)
    snapshot_manifest_records_tsv(read_pilot_evidence_report_manifest_records(directory; allow_extra); header)
end

"""Render expected pilot evidence report manifest records as a stable Markdown table."""
function pilot_evidence_report_manifest_markdown(evidence::PilotEvidenceBundle)
    snapshot_manifest_records_markdown(pilot_evidence_report_manifest_records(evidence))
end

pilot_evidence_report_manifest_markdown(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_report_manifest_markdown(pilot_evidence_bundle(pilot; kwargs...))

"""Render written pilot evidence report manifest records as a stable Markdown table."""
function pilot_evidence_report_artifact_manifest_markdown(directory::AbstractString; allow_extra::Bool=false)
    snapshot_manifest_records_markdown(read_pilot_evidence_report_manifest_records(directory; allow_extra))
end

function _assert_pilot_evidence_report_artifacts(
    directory::AbstractString,
    expected_reports::Dict{String,String};
    allow_extra::Bool=false,
)
    for name in sort!(collect(keys(expected_reports)))
        path = joinpath(directory, name)
        isfile(path) || throw(BufferAssertionError("missing pilot evidence report artifact: $path"))
        actual = read(path, String)
        expected = expected_reports[name]
        actual == expected || throw(BufferAssertionError(
            _snapshot_mismatch_message("pilot evidence report artifact $name", expected, actual),
        ))
    end
    verify_pilot_evidence_report_artifacts(directory; allow_extra)
    directory
end

"""Assert that written pilot evidence report files match an expected evidence bundle."""
function assert_pilot_evidence_report_artifacts(
    directory::AbstractString,
    expected::PilotEvidenceBundle;
    allow_extra::Bool=false,
)
    _assert_pilot_evidence_report_artifacts(directory, pilot_evidence_report_artifacts(expected); allow_extra)
end

function assert_pilot_evidence_report_artifacts(
    directory::AbstractString,
    pilot::Union{RuntimePilot,ToolkitPilot};
    allow_extra::Bool=false,
    kwargs...,
)
    assert_pilot_evidence_report_artifacts(directory, pilot_evidence_bundle(pilot; kwargs...); allow_extra)
end

function assert_pilot_evidence_report_artifacts(
    report_directory::AbstractString,
    evidence_directory::AbstractString;
    allow_extra::Bool=false,
    evidence_allow_extra::Bool=false,
)
    _assert_pilot_evidence_report_artifacts(
        report_directory,
        _pilot_evidence_report_artifacts_from_directory(evidence_directory; allow_extra=evidence_allow_extra);
        allow_extra,
    )
end

"""Write derived pilot evidence report files for dashboards and release notes."""
function write_pilot_evidence_reports(
    directory::AbstractString,
    evidence::PilotEvidenceBundle;
    overwrite::Bool=false,
)
    isempty(strip(directory)) && throw(ArgumentError("pilot evidence report directory must not be empty"))
    reports = pilot_evidence_report_artifacts(evidence)
    mkpath(directory)
    written = Dict{String,String}()
    for name in sort!(collect(keys(reports)))
        path = joinpath(directory, name)
        if isfile(path) && !overwrite
            throw(ArgumentError("pilot evidence report already exists: $path"))
        end
        write(path, reports[name])
        written[name] = path
    end
    written
end

function write_pilot_evidence_reports(
    directory::AbstractString,
    pilot::Union{RuntimePilot,ToolkitPilot};
    overwrite::Bool=false,
    kwargs...,
)
    write_pilot_evidence_reports(directory, pilot_evidence_bundle(pilot; kwargs...); overwrite)
end

function write_pilot_evidence_reports(
    report_directory::AbstractString,
    evidence_directory::AbstractString;
    overwrite::Bool=false,
    allow_extra::Bool=false,
)
    isempty(strip(report_directory)) && throw(ArgumentError("pilot evidence report directory must not be empty"))
    reports = _pilot_evidence_report_artifacts_from_directory(evidence_directory; allow_extra)
    mkpath(report_directory)
    written = Dict{String,String}()
    for name in sort!(collect(keys(reports)))
        path = joinpath(report_directory, name)
        if isfile(path) && !overwrite
            throw(ArgumentError("pilot evidence report already exists: $path"))
        end
        write(path, reports[name])
        written[name] = path
    end
    written
end

"""Write strict pilot evidence artifacts and derived reports under one package directory."""
function write_pilot_evidence_package(
    directory::AbstractString,
    evidence::PilotEvidenceBundle;
    overwrite::Bool=false,
)
    isempty(strip(directory)) && throw(ArgumentError("pilot evidence package directory must not be empty"))
    evidence_paths = write_pilot_evidence_bundle(joinpath(directory, "evidence"), evidence; overwrite)
    report_paths = write_pilot_evidence_reports(joinpath(directory, "reports"), evidence; overwrite)
    written = Dict{String,String}()
    for (name, path) in evidence_paths
        written[joinpath("evidence", name)] = path
    end
    for (name, path) in report_paths
        written[joinpath("reports", name)] = path
    end
    written
end

function write_pilot_evidence_package(
    directory::AbstractString,
    pilot::Union{RuntimePilot,ToolkitPilot};
    overwrite::Bool=false,
    kwargs...,
)
    write_pilot_evidence_package(directory, pilot_evidence_bundle(pilot; kwargs...); overwrite)
end

function _pilot_evidence_package_artifacts(evidence::PilotEvidenceBundle)
    artifacts = Dict{String,String}()
    for (name, content) in _pilot_evidence_artifacts_with_manifest(evidence)
        artifacts[joinpath("evidence", name)] = content
    end
    for (name, content) in snapshot_bundle_artifacts(evidence.snapshots)
        artifacts[joinpath("evidence", "snapshots", name)] = content
    end
    for (name, content) in pilot_evidence_report_artifacts(evidence)
        artifacts[joinpath("reports", name)] = content
    end
    artifacts
end

"""Return typed integrity records for every file in an expected pilot evidence package."""
function pilot_evidence_package_manifest_records(evidence::PilotEvidenceBundle)
    artifacts = _pilot_evidence_package_artifacts(evidence)
    SnapshotArtifactRecord[
        SnapshotArtifactRecord(name, sizeof(artifacts[name]), _sha256_hex(artifacts[name]))
        for name in sort!(collect(keys(artifacts)))
    ]
end

pilot_evidence_package_manifest_records(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_manifest_records(pilot_evidence_bundle(pilot; kwargs...))

function _artifact_record_from_file(name::AbstractString, path::AbstractString)
    content = read(path, String)
    SnapshotArtifactRecord(String(name), sizeof(content), _sha256_hex(content))
end

"""Read typed integrity records for every required file in a saved pilot evidence package."""
function read_pilot_evidence_package_manifest_records(
    directory::AbstractString;
    allow_extra::Bool=false,
    evidence_allow_extra::Bool=false,
    reports_allow_extra::Bool=false,
)
    verify_pilot_evidence_package(directory; allow_extra, evidence_allow_extra, reports_allow_extra)
    records = SnapshotArtifactRecord[]
    evidence_directory = joinpath(directory, "evidence")
    for name in sort!(collect(setdiff(_pilot_evidence_required_entries(), Set(["snapshots"]))))
        push!(records, _artifact_record_from_file(joinpath("evidence", name), joinpath(evidence_directory, name)))
    end
    snapshot_directory = joinpath(evidence_directory, "snapshots")
    snapshot_names = union(
        Set(record.name for record in read_snapshot_bundle_manifest_records(snapshot_directory)),
        Set(["manifest.txt"]),
    )
    for name in sort!(collect(snapshot_names))
        push!(records, _artifact_record_from_file(joinpath("evidence", "snapshots", name), joinpath(snapshot_directory, name)))
    end
    reports_directory = joinpath(directory, "reports")
    for name in sort!(collect(_pilot_evidence_report_required_files()))
        push!(records, _artifact_record_from_file(joinpath("reports", name), joinpath(reports_directory, name)))
    end
    records
end

"""Render expected pilot evidence package manifest records as a stable TSV table."""
pilot_evidence_package_manifest_tsv(evidence::PilotEvidenceBundle; header::Bool=true) =
    snapshot_manifest_records_tsv(pilot_evidence_package_manifest_records(evidence); header)

pilot_evidence_package_manifest_tsv(pilot::Union{RuntimePilot,ToolkitPilot}; header::Bool=true, kwargs...) =
    pilot_evidence_package_manifest_tsv(pilot_evidence_bundle(pilot; kwargs...); header)

"""Render saved pilot evidence package manifest records as a stable TSV table."""
pilot_evidence_package_artifact_manifest_tsv(directory::AbstractString; header::Bool=true, kwargs...) =
    snapshot_manifest_records_tsv(read_pilot_evidence_package_manifest_records(directory; kwargs...); header)

"""Render expected pilot evidence package manifest records as a stable Markdown table."""
pilot_evidence_package_manifest_markdown(evidence::PilotEvidenceBundle) =
    snapshot_manifest_records_markdown(pilot_evidence_package_manifest_records(evidence))

pilot_evidence_package_manifest_markdown(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_manifest_markdown(pilot_evidence_bundle(pilot; kwargs...))

"""Render saved pilot evidence package manifest records as a stable Markdown table."""
pilot_evidence_package_artifact_manifest_markdown(directory::AbstractString; kwargs...) =
    snapshot_manifest_records_markdown(read_pilot_evidence_package_manifest_records(directory; kwargs...))

"""Return derived package-level report files for a pilot evidence package."""
function pilot_evidence_package_report_artifacts(evidence::PilotEvidenceBundle)
    summary = pilot_evidence_package_summary(evidence)
    Dict(
        "package-manifest.tsv" => pilot_evidence_package_manifest_tsv(evidence),
        "package-manifest.md" => pilot_evidence_package_manifest_markdown(evidence),
        "package-summary.txt" => snapshot_artifact_summary_text(summary),
        "package-summary.tsv" => snapshot_artifact_summary_tsv(summary),
        "package-summary.md" => snapshot_artifact_summary_markdown(summary),
    )
end

pilot_evidence_package_report_artifacts(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_report_artifacts(pilot_evidence_bundle(pilot; kwargs...))

function pilot_evidence_package_report_artifacts(
    directory::AbstractString;
    allow_extra::Bool=false,
    evidence_allow_extra::Bool=false,
    reports_allow_extra::Bool=false,
)
    summary = pilot_evidence_package_artifact_summary(
        directory;
        allow_extra,
        evidence_allow_extra,
        reports_allow_extra,
    )
    Dict(
        "package-manifest.tsv" => pilot_evidence_package_artifact_manifest_tsv(
            directory;
            allow_extra,
            evidence_allow_extra,
            reports_allow_extra,
        ),
        "package-manifest.md" => pilot_evidence_package_artifact_manifest_markdown(
            directory;
            allow_extra,
            evidence_allow_extra,
            reports_allow_extra,
        ),
        "package-summary.txt" => snapshot_artifact_summary_text(summary),
        "package-summary.tsv" => snapshot_artifact_summary_tsv(summary),
        "package-summary.md" => snapshot_artifact_summary_markdown(summary),
    )
end

"""Return typed integrity records for expected package-level pilot evidence reports."""
function pilot_evidence_package_report_manifest_records(evidence::PilotEvidenceBundle)
    reports = pilot_evidence_package_report_artifacts(evidence)
    SnapshotArtifactRecord[
        SnapshotArtifactRecord(name, sizeof(reports[name]), _sha256_hex(reports[name]))
        for name in sort!(collect(keys(reports)))
    ]
end

pilot_evidence_package_report_manifest_records(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_report_manifest_records(pilot_evidence_bundle(pilot; kwargs...))

"""Return compact file-count and byte-count metadata for expected package-level reports."""
function pilot_evidence_package_report_summary(evidence::PilotEvidenceBundle)
    _snapshot_artifact_summary(:pilot_evidence_package_reports, pilot_evidence_package_report_manifest_records(evidence))
end

pilot_evidence_package_report_summary(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_report_summary(pilot_evidence_bundle(pilot; kwargs...))

"""Render expected package-level report manifest records as a stable TSV table."""
pilot_evidence_package_report_manifest_tsv(evidence::PilotEvidenceBundle; header::Bool=true) =
    snapshot_manifest_records_tsv(pilot_evidence_package_report_manifest_records(evidence); header)

pilot_evidence_package_report_manifest_tsv(pilot::Union{RuntimePilot,ToolkitPilot}; header::Bool=true, kwargs...) =
    pilot_evidence_package_report_manifest_tsv(pilot_evidence_bundle(pilot; kwargs...); header)

"""Render expected package-level report manifest records as a stable Markdown table."""
pilot_evidence_package_report_manifest_markdown(evidence::PilotEvidenceBundle) =
    snapshot_manifest_records_markdown(pilot_evidence_package_report_manifest_records(evidence))

pilot_evidence_package_report_manifest_markdown(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_report_manifest_markdown(pilot_evidence_bundle(pilot; kwargs...))

"""Render expected package-level report summary as one stable text line."""
pilot_evidence_package_report_summary_text(evidence::PilotEvidenceBundle) =
    snapshot_artifact_summary_text(pilot_evidence_package_report_summary(evidence))

pilot_evidence_package_report_summary_text(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_report_summary_text(pilot_evidence_bundle(pilot; kwargs...))

"""Render expected package-level report summary as a stable TSV table."""
pilot_evidence_package_report_summary_tsv(evidence::PilotEvidenceBundle; header::Bool=true) =
    snapshot_artifact_summary_tsv(pilot_evidence_package_report_summary(evidence); header)

pilot_evidence_package_report_summary_tsv(pilot::Union{RuntimePilot,ToolkitPilot}; header::Bool=true, kwargs...) =
    pilot_evidence_package_report_summary_tsv(pilot_evidence_bundle(pilot; kwargs...); header)

"""Render expected package-level report summary as a stable Markdown table."""
pilot_evidence_package_report_summary_markdown(evidence::PilotEvidenceBundle) =
    snapshot_artifact_summary_markdown(pilot_evidence_package_report_summary(evidence))

pilot_evidence_package_report_summary_markdown(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_report_summary_markdown(pilot_evidence_bundle(pilot; kwargs...))

"""Write derived package-level report files for a pilot evidence package."""
function write_pilot_evidence_package_reports(
    directory::AbstractString,
    evidence::PilotEvidenceBundle;
    overwrite::Bool=false,
)
    isempty(strip(directory)) && throw(ArgumentError("pilot evidence package report directory must not be empty"))
    reports = pilot_evidence_package_report_artifacts(evidence)
    mkpath(directory)
    written = Dict{String,String}()
    for name in sort!(collect(keys(reports)))
        path = joinpath(directory, name)
        if isfile(path) && !overwrite
            throw(ArgumentError("pilot evidence package report already exists: $path"))
        end
        write(path, reports[name])
        written[name] = path
    end
    written
end

function write_pilot_evidence_package_reports(
    directory::AbstractString,
    pilot::Union{RuntimePilot,ToolkitPilot};
    overwrite::Bool=false,
    kwargs...,
)
    write_pilot_evidence_package_reports(directory, pilot_evidence_bundle(pilot; kwargs...); overwrite)
end

function write_pilot_evidence_package_reports(
    report_directory::AbstractString,
    package_directory::AbstractString;
    overwrite::Bool=false,
    allow_extra::Bool=false,
    evidence_allow_extra::Bool=false,
    reports_allow_extra::Bool=false,
)
    isempty(strip(report_directory)) && throw(ArgumentError("pilot evidence package report directory must not be empty"))
    reports = pilot_evidence_package_report_artifacts(
        package_directory;
        allow_extra,
        evidence_allow_extra,
        reports_allow_extra,
    )
    mkpath(report_directory)
    written = Dict{String,String}()
    for name in sort!(collect(keys(reports)))
        path = joinpath(report_directory, name)
        if isfile(path) && !overwrite
            throw(ArgumentError("pilot evidence package report already exists: $path"))
        end
        write(path, reports[name])
        written[name] = path
    end
    written
end

_pilot_evidence_package_report_required_files() =
    Set(["package-manifest.tsv", "package-manifest.md", "package-summary.txt", "package-summary.tsv", "package-summary.md"])

"""Verify written package-level pilot evidence report files."""
function verify_pilot_evidence_package_report_artifacts(directory::AbstractString; allow_extra::Bool=false)
    isdir(directory) ||
        throw(BufferAssertionError("pilot evidence package report directory does not exist: $directory"))
    expected_files = _pilot_evidence_package_report_required_files()
    actual_entries = Set(readdir(directory))
    if !allow_extra
        extra = sort!(collect(setdiff(actual_entries, expected_files)))
        isempty(extra) || throw(BufferAssertionError(
            "unexpected pilot evidence package report artifacts: $(join(extra, ", "))",
        ))
    end
    for name in sort!(collect(expected_files))
        path = joinpath(directory, name)
        isfile(path) || throw(BufferAssertionError("missing pilot evidence package report artifact: $path"))
    end
    true
end

"""Read typed integrity records from a written package-level report directory."""
function read_pilot_evidence_package_report_manifest_records(directory::AbstractString; allow_extra::Bool=false)
    verify_pilot_evidence_package_report_artifacts(directory; allow_extra)
    records = SnapshotArtifactRecord[]
    for name in sort!(collect(_pilot_evidence_package_report_required_files()))
        content = read(joinpath(directory, name), String)
        push!(records, SnapshotArtifactRecord(name, sizeof(content), _sha256_hex(content)))
    end
    records
end

"""Return compact file-count and byte-count metadata for a package-level report directory."""
function pilot_evidence_package_report_artifact_summary(directory::AbstractString; allow_extra::Bool=false)
    _snapshot_artifact_summary(:pilot_evidence_package_reports, read_pilot_evidence_package_report_manifest_records(directory; allow_extra))
end

"""Render package-level report manifest records from saved artifacts as a stable TSV table."""
pilot_evidence_package_report_artifact_manifest_tsv(directory::AbstractString; header::Bool=true, allow_extra::Bool=false) =
    snapshot_manifest_records_tsv(read_pilot_evidence_package_report_manifest_records(directory; allow_extra); header)

"""Render package-level report manifest records from saved artifacts as a stable Markdown table."""
pilot_evidence_package_report_artifact_manifest_markdown(directory::AbstractString; allow_extra::Bool=false) =
    snapshot_manifest_records_markdown(read_pilot_evidence_package_report_manifest_records(directory; allow_extra))

"""Render package-level report summary from saved artifacts as one stable text line."""
pilot_evidence_package_report_artifact_summary_text(directory::AbstractString; allow_extra::Bool=false) =
    snapshot_artifact_summary_text(pilot_evidence_package_report_artifact_summary(directory; allow_extra))

"""Render package-level report summary from saved artifacts as a stable TSV table."""
pilot_evidence_package_report_artifact_summary_tsv(directory::AbstractString; header::Bool=true, allow_extra::Bool=false) =
    snapshot_artifact_summary_tsv(pilot_evidence_package_report_artifact_summary(directory; allow_extra); header)

"""Render package-level report summary from saved artifacts as a stable Markdown table."""
pilot_evidence_package_report_artifact_summary_markdown(directory::AbstractString; allow_extra::Bool=false) =
    snapshot_artifact_summary_markdown(pilot_evidence_package_report_artifact_summary(directory; allow_extra))

function _assert_pilot_evidence_package_report_artifacts(
    directory::AbstractString,
    expected_reports::Dict{String,String};
    allow_extra::Bool=false,
)
    for name in sort!(collect(keys(expected_reports)))
        path = joinpath(directory, name)
        isfile(path) || throw(BufferAssertionError("missing pilot evidence package report artifact: $path"))
        actual = read(path, String)
        expected = expected_reports[name]
        actual == expected || throw(BufferAssertionError(
            _snapshot_mismatch_message("pilot evidence package report artifact $name", expected, actual),
        ))
    end
    verify_pilot_evidence_package_report_artifacts(directory; allow_extra)
    directory
end

"""Assert that written package-level pilot evidence reports match an expected bundle."""
function assert_pilot_evidence_package_report_artifacts(
    directory::AbstractString,
    expected::PilotEvidenceBundle;
    allow_extra::Bool=false,
)
    _assert_pilot_evidence_package_report_artifacts(directory, pilot_evidence_package_report_artifacts(expected); allow_extra)
end

function assert_pilot_evidence_package_report_artifacts(
    directory::AbstractString,
    pilot::Union{RuntimePilot,ToolkitPilot};
    allow_extra::Bool=false,
    kwargs...,
)
    assert_pilot_evidence_package_report_artifacts(directory, pilot_evidence_bundle(pilot; kwargs...); allow_extra)
end

function assert_pilot_evidence_package_report_artifacts(
    report_directory::AbstractString,
    package_directory::AbstractString;
    allow_extra::Bool=false,
    package_allow_extra::Bool=false,
    evidence_allow_extra::Bool=false,
    reports_allow_extra::Bool=false,
)
    _assert_pilot_evidence_package_report_artifacts(
        report_directory,
        pilot_evidence_package_report_artifacts(
            package_directory;
            allow_extra=package_allow_extra,
            evidence_allow_extra,
            reports_allow_extra,
        );
        allow_extra,
    )
end

"""Return compact total artifact-count and byte-count metadata for an expected pilot evidence package."""
function pilot_evidence_package_summary(evidence::PilotEvidenceBundle)
    records = SnapshotArtifactRecord[]
    append!(records, pilot_evidence_manifest_records(evidence))
    append!(records, snapshot_bundle_manifest_records(evidence.snapshots))
    append!(records, pilot_evidence_report_manifest_records(evidence))
    _snapshot_artifact_summary(:pilot_evidence_package, records)
end

pilot_evidence_package_summary(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_summary(pilot_evidence_bundle(pilot; kwargs...))

"""Return compact total artifact-count and byte-count metadata for a saved pilot evidence package."""
function pilot_evidence_package_artifact_summary(
    directory::AbstractString;
    allow_extra::Bool=false,
    evidence_allow_extra::Bool=false,
    reports_allow_extra::Bool=false,
)
    verify_pilot_evidence_package(directory; allow_extra, evidence_allow_extra, reports_allow_extra)
    evidence_directory = joinpath(directory, "evidence")
    records = SnapshotArtifactRecord[]
    append!(records, read_pilot_evidence_manifest_records(evidence_directory))
    append!(records, read_snapshot_bundle_manifest_records(joinpath(evidence_directory, "snapshots")))
    append!(records, read_pilot_evidence_report_manifest_records(joinpath(directory, "reports")))
    _snapshot_artifact_summary(:pilot_evidence_package, records)
end

"""Render expected pilot evidence package summary as one stable text line."""
pilot_evidence_package_summary_text(evidence::PilotEvidenceBundle) =
    snapshot_artifact_summary_text(pilot_evidence_package_summary(evidence))

pilot_evidence_package_summary_text(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_summary_text(pilot_evidence_bundle(pilot; kwargs...))

"""Render saved pilot evidence package summary as one stable text line."""
pilot_evidence_package_artifact_summary_text(directory::AbstractString; kwargs...) =
    snapshot_artifact_summary_text(pilot_evidence_package_artifact_summary(directory; kwargs...))

"""Render expected pilot evidence package summary as a stable TSV table."""
pilot_evidence_package_summary_tsv(evidence::PilotEvidenceBundle; header::Bool=true) =
    snapshot_artifact_summary_tsv(pilot_evidence_package_summary(evidence); header)

pilot_evidence_package_summary_tsv(pilot::Union{RuntimePilot,ToolkitPilot}; header::Bool=true, kwargs...) =
    pilot_evidence_package_summary_tsv(pilot_evidence_bundle(pilot; kwargs...); header)

"""Render saved pilot evidence package summary as a stable TSV table."""
pilot_evidence_package_artifact_summary_tsv(directory::AbstractString; header::Bool=true, kwargs...) =
    snapshot_artifact_summary_tsv(pilot_evidence_package_artifact_summary(directory; kwargs...); header)

"""Render expected pilot evidence package summary as a stable Markdown table."""
pilot_evidence_package_summary_markdown(evidence::PilotEvidenceBundle) =
    snapshot_artifact_summary_markdown(pilot_evidence_package_summary(evidence))

pilot_evidence_package_summary_markdown(pilot::Union{RuntimePilot,ToolkitPilot}; kwargs...) =
    pilot_evidence_package_summary_markdown(pilot_evidence_bundle(pilot; kwargs...))

"""Render saved pilot evidence package summary as a stable Markdown table."""
pilot_evidence_package_artifact_summary_markdown(directory::AbstractString; kwargs...) =
    snapshot_artifact_summary_markdown(pilot_evidence_package_artifact_summary(directory; kwargs...))

"""Verify a packaged pilot evidence artifact root."""
function verify_pilot_evidence_package(
    directory::AbstractString;
    allow_extra::Bool=false,
    evidence_allow_extra::Bool=false,
    reports_allow_extra::Bool=false,
)
    isdir(directory) ||
        throw(BufferAssertionError("pilot evidence package directory does not exist: $directory"))
    expected_entries = Set(["evidence", "reports"])
    actual_entries = Set(readdir(directory))
    if !allow_extra
        extra = sort!(collect(setdiff(actual_entries, expected_entries)))
        isempty(extra) || throw(BufferAssertionError(
            "unexpected pilot evidence package entries: $(join(extra, ", "))",
        ))
    end
    evidence_directory = joinpath(directory, "evidence")
    reports_directory = joinpath(directory, "reports")
    isdir(evidence_directory) ||
        throw(BufferAssertionError("missing pilot evidence package evidence directory: $evidence_directory"))
    isdir(reports_directory) ||
        throw(BufferAssertionError("missing pilot evidence package reports directory: $reports_directory"))
    verify_pilot_evidence_bundle(evidence_directory; allow_extra=evidence_allow_extra)
    verify_pilot_evidence_report_artifacts(reports_directory; allow_extra=reports_allow_extra)
    assert_pilot_evidence_report_artifacts(
        reports_directory,
        evidence_directory;
        allow_extra=reports_allow_extra,
        evidence_allow_extra,
    )
    true
end

"""Assert that a packaged pilot evidence artifact root matches an expected bundle."""
function assert_pilot_evidence_package_artifacts(
    directory::AbstractString,
    expected::PilotEvidenceBundle;
    allow_extra::Bool=false,
    evidence_allow_extra::Bool=false,
    reports_allow_extra::Bool=false,
)
    verify_pilot_evidence_package(directory; allow_extra, evidence_allow_extra, reports_allow_extra)
    expected_manifest = pilot_evidence_package_manifest_records(expected)
    actual_manifest = read_pilot_evidence_package_manifest_records(
        directory;
        allow_extra,
        evidence_allow_extra,
        reports_allow_extra,
    )
    actual_manifest == expected_manifest || throw(BufferAssertionError(
        _snapshot_mismatch_message("pilot evidence package manifest", expected_manifest, actual_manifest),
    ))
    assert_pilot_evidence_bundle_artifacts(joinpath(directory, "evidence"), expected; allow_extra=evidence_allow_extra)
    assert_pilot_evidence_report_artifacts(joinpath(directory, "reports"), expected; allow_extra=reports_allow_extra)
    directory
end

function assert_pilot_evidence_package_artifacts(
    directory::AbstractString,
    pilot::Union{RuntimePilot,ToolkitPilot};
    allow_extra::Bool=false,
    evidence_allow_extra::Bool=false,
    reports_allow_extra::Bool=false,
    kwargs...,
)
    assert_pilot_evidence_package_artifacts(
        directory,
        pilot_evidence_bundle(pilot; kwargs...);
        allow_extra,
        evidence_allow_extra,
        reports_allow_extra,
    )
end

function _pilot_evidence_artifacts(evidence::PilotEvidenceBundle)
    Dict(
        "status.txt" => pilot_status_text(evidence.status),
        "status.tsv" => pilot_status_tsv(evidence.status),
        "status.md" => pilot_status_markdown(evidence.status),
        "evidence.txt" => pilot_evidence_text(evidence),
        "evidence.tsv" => pilot_evidence_tsv(evidence),
        "evidence.md" => pilot_evidence_markdown(evidence),
    )
end

"""Return typed integrity records for top-level pilot evidence payload files."""
function pilot_evidence_manifest_records(evidence::PilotEvidenceBundle)
    artifacts = _pilot_evidence_artifacts(evidence)
    SnapshotArtifactRecord[
        SnapshotArtifactRecord(name, sizeof(artifacts[name]), _sha256_hex(artifacts[name]))
        for name in sort!(collect(keys(artifacts)))
    ]
end

"""Return a deterministic manifest for top-level pilot evidence files."""
function pilot_evidence_manifest(evidence::PilotEvidenceBundle)
    lines = ["source_kind=pilot_evidence"]
    for record in pilot_evidence_manifest_records(evidence)
        push!(lines, "$(record.name)\tbytes=$(record.bytes)\tsha256=$(record.sha256)")
    end
    join(lines, '\n') * "\n"
end

"""Render pilot evidence manifest records as a stable TSV table."""
function pilot_evidence_manifest_tsv(evidence::PilotEvidenceBundle; header::Bool=true)
    snapshot_manifest_records_tsv(pilot_evidence_manifest_records(evidence); header)
end

"""Render saved pilot evidence manifest records as a stable TSV table."""
function pilot_evidence_artifact_manifest_tsv(directory::AbstractString; header::Bool=true)
    snapshot_manifest_records_tsv(read_pilot_evidence_manifest_records(directory); header)
end

"""Render pilot evidence manifest records as a stable Markdown table."""
function pilot_evidence_manifest_markdown(evidence::PilotEvidenceBundle)
    snapshot_manifest_records_markdown(pilot_evidence_manifest_records(evidence))
end

"""Render saved pilot evidence manifest records as a stable Markdown table."""
function pilot_evidence_artifact_manifest_markdown(directory::AbstractString)
    snapshot_manifest_records_markdown(read_pilot_evidence_manifest_records(directory))
end

function _pilot_evidence_artifacts_with_manifest(evidence::PilotEvidenceBundle)
    artifacts = _pilot_evidence_artifacts(evidence)
    artifacts["manifest.txt"] = pilot_evidence_manifest(evidence)
    artifacts
end

_pilot_evidence_required_entries() =
    Set(["status.txt", "status.tsv", "status.md", "evidence.txt", "evidence.tsv", "evidence.md", "manifest.txt", "snapshots"])

"""Read typed pilot evidence artifact records from a written top-level manifest."""
function read_pilot_evidence_manifest_records(directory::AbstractString)
    isdir(directory) ||
        throw(BufferAssertionError("pilot evidence directory does not exist: $directory"))
    manifest_path = joinpath(directory, "manifest.txt")
    isfile(manifest_path) ||
        throw(BufferAssertionError("missing pilot evidence manifest: $manifest_path"))
    entries = _snapshot_manifest_entries(read(manifest_path, String))
    expected_names = setdiff(_pilot_evidence_required_entries(), Set(["manifest.txt", "snapshots"]))
    actual_names = Set(keys(entries))
    actual_names == expected_names || throw(BufferAssertionError(
        "pilot evidence manifest entries mismatch: expected $(join(sort!(collect(expected_names)), ", ")), got $(join(sort!(collect(actual_names)), ", "))",
    ))
    SnapshotArtifactRecord[
        SnapshotArtifactRecord(name, entries[name].bytes, entries[name].sha256)
        for name in sort!(collect(keys(entries)))
    ]
end

"""Verify a written pilot evidence directory and its nested snapshot bundle."""
function verify_pilot_evidence_bundle(directory::AbstractString; allow_extra::Bool=false)
    isdir(directory) ||
        throw(BufferAssertionError("pilot evidence directory does not exist: $directory"))
    expected_entries = _pilot_evidence_required_entries()
    actual_entries = Set(readdir(directory))
    if !allow_extra
        extra = sort!(collect(setdiff(actual_entries, expected_entries)))
        isempty(extra) || throw(BufferAssertionError(
            "unexpected pilot evidence artifact entries: $(join(extra, ", "))",
        ))
    end
    for name in sort!(collect(setdiff(expected_entries, Set(["snapshots"]))))
        path = joinpath(directory, name)
        isfile(path) || throw(BufferAssertionError("missing pilot evidence artifact: $path"))
    end
    for record in read_pilot_evidence_manifest_records(directory)
        path = joinpath(directory, record.name)
        content = read(path, String)
        sizeof(content) == record.bytes || throw(BufferAssertionError(
            "pilot evidence artifact byte count mismatch for $(record.name): expected $(record.bytes), actual $(sizeof(content))",
        ))
        digest = _sha256_hex(content)
        digest == record.sha256 || throw(BufferAssertionError(
            "pilot evidence artifact sha256 mismatch for $(record.name): expected $(record.sha256), actual $digest",
        ))
    end
    snapshot_directory = joinpath(directory, "snapshots")
    isdir(snapshot_directory) ||
        throw(BufferAssertionError("missing pilot evidence snapshot directory: $snapshot_directory"))
    verify_snapshot_bundle_artifacts(snapshot_directory; allow_extra)
    true
end

"""Assert that a written pilot evidence directory matches an expected bundle."""
function assert_pilot_evidence_bundle_artifacts(
    directory::AbstractString,
    expected::PilotEvidenceBundle;
    allow_extra::Bool=false,
)
    expected_artifacts = _pilot_evidence_artifacts_with_manifest(expected)
    for name in sort!(collect(keys(expected_artifacts)))
        path = joinpath(directory, name)
        isfile(path) || throw(BufferAssertionError("missing pilot evidence artifact: $path"))
        actual = read(path, String)
        expected_content = expected_artifacts[name]
        actual == expected_content || throw(BufferAssertionError(
            _snapshot_mismatch_message("pilot evidence artifact $name", expected_content, actual),
        ))
    end
    assert_snapshot_bundle_artifacts(joinpath(directory, "snapshots"), expected.snapshots; allow_extra)
    verify_pilot_evidence_bundle(directory; allow_extra)
    directory
end

function assert_pilot_evidence_bundle_artifacts(
    directory::AbstractString,
    pilot::Union{RuntimePilot,ToolkitPilot};
    allow_extra::Bool=false,
    kwargs...,
)
    assert_pilot_evidence_bundle_artifacts(directory, pilot_evidence_bundle(pilot; kwargs...); allow_extra)
end

function _snapshot_manifest_entries(manifest::AbstractString)
    lines = split(chomp(manifest), '\n'; keepempty=false)
    isempty(lines) && throw(BufferAssertionError("snapshot bundle manifest is empty"))
    startswith(first(lines), "source_kind=") ||
        throw(BufferAssertionError("snapshot bundle manifest is missing source_kind"))
    entries = Dict{String,NamedTuple{(:bytes,:sha256),Tuple{Int,String}}}()
    for line in Iterators.drop(lines, 1)
        fields = split(line, '\t'; keepempty=true)
        length(fields) == 3 ||
            throw(BufferAssertionError("invalid snapshot bundle manifest row: $line"))
        bytes_field = fields[2]
        sha_field = fields[3]
        startswith(bytes_field, "bytes=") ||
            throw(BufferAssertionError("invalid snapshot bundle byte field: $line"))
        startswith(sha_field, "sha256=") ||
            throw(BufferAssertionError("invalid snapshot bundle sha256 field: $line"))
        byte_count = try
            parse(Int, bytes_field[(lastindex("bytes=") + 1):end])
        catch error
            throw(BufferAssertionError("invalid snapshot bundle byte count: $line"))
        end
        entries[String(fields[1])] = (bytes=byte_count, sha256=String(sha_field[(lastindex("sha256=") + 1):end]))
    end
    entries
end

function _snapshot_manifest_source_kind(manifest::AbstractString)
    lines = split(chomp(manifest), '\n'; keepempty=false)
    isempty(lines) && throw(BufferAssertionError("snapshot bundle manifest is empty"))
    first_line = first(lines)
    startswith(first_line, "source_kind=") ||
        throw(BufferAssertionError("snapshot bundle manifest is missing source_kind"))
    Symbol(first_line[(lastindex("source_kind=") + 1):end])
end

"""Read typed snapshot artifact records from a written bundle manifest."""
function read_snapshot_bundle_manifest_records(directory::AbstractString)
    isdir(directory) ||
        throw(BufferAssertionError("snapshot bundle artifact directory does not exist: $directory"))
    manifest_path = joinpath(directory, "manifest.txt")
    isfile(manifest_path) ||
        throw(BufferAssertionError("missing snapshot bundle manifest: $manifest_path"))
    manifest = read(manifest_path, String)
    entries = _snapshot_manifest_entries(manifest)
    SnapshotArtifactRecord[
        SnapshotArtifactRecord(name, entries[name].bytes, entries[name].sha256)
        for name in sort!(collect(keys(entries)))
    ]
end

function _snapshot_artifact_summary(source_kind::Symbol, records)
    SnapshotArtifactSummary(
        source_kind,
        length(records),
        sum(record -> record.bytes, records; init=0),
    )
end

"""Return compact source-kind, artifact-count, and byte-count metadata for a bundle."""
snapshot_bundle_summary(bundle::SnapshotBundle) =
    _snapshot_artifact_summary(bundle.source_kind, snapshot_bundle_manifest_records(bundle))

"""Return compact source-kind, artifact-count, and byte-count metadata for saved artifacts."""
function snapshot_bundle_artifact_summary(directory::AbstractString)
    manifest_path = joinpath(directory, "manifest.txt")
    isfile(manifest_path) ||
        throw(BufferAssertionError("missing snapshot bundle manifest: $manifest_path"))
    manifest = read(manifest_path, String)
    _snapshot_artifact_summary(
        _snapshot_manifest_source_kind(manifest),
        read_snapshot_bundle_manifest_records(directory),
    )
end

"""Render snapshot artifact summary as one stable text line."""
snapshot_artifact_summary_text(summary::SnapshotArtifactSummary) =
    "source_kind=$(summary.source_kind) artifact_count=$(summary.artifact_count) total_bytes=$(summary.total_bytes)"

"""Render snapshot artifact summary as a stable TSV table."""
function snapshot_artifact_summary_tsv(summary::SnapshotArtifactSummary; header::Bool=true)
    output = IOBuffer()
    header && println(output, "source_kind\tartifact_count\ttotal_bytes")
    println(output, "$(summary.source_kind)\t$(summary.artifact_count)\t$(summary.total_bytes)")
    String(take!(output))
end

"""Render snapshot artifact summary as a stable Markdown table."""
function snapshot_artifact_summary_markdown(summary::SnapshotArtifactSummary)
    output = IOBuffer()
    println(output, "| `source_kind` | `artifact_count` | `total_bytes` |")
    println(output, "|---|---:|---:|")
    println(output, "| `$(summary.source_kind)` | $(summary.artifact_count) | $(summary.total_bytes) |")
    String(take!(output))
end

"""Return derived report files for snapshot bundle metadata dashboards."""
function snapshot_bundle_report_artifacts(bundle::SnapshotBundle)
    summary = snapshot_bundle_summary(bundle)
    Dict(
        "manifest.tsv" => snapshot_bundle_manifest_tsv(bundle),
        "manifest.md" => snapshot_bundle_manifest_markdown(bundle),
        "summary.txt" => snapshot_artifact_summary_text(summary),
        "summary.tsv" => snapshot_artifact_summary_tsv(summary),
        "summary.md" => snapshot_artifact_summary_markdown(summary),
    )
end

"""Write derived snapshot bundle report files for dashboards and release notes."""
function write_snapshot_bundle_reports(
    directory::AbstractString,
    bundle::SnapshotBundle;
    overwrite::Bool=false,
)
    isempty(strip(directory)) && throw(ArgumentError("snapshot bundle report directory must not be empty"))
    reports = snapshot_bundle_report_artifacts(bundle)
    mkpath(directory)
    written = Dict{String,String}()
    for name in sort!(collect(keys(reports)))
        path = joinpath(directory, name)
        if isfile(path) && !overwrite
            throw(ArgumentError("snapshot bundle report already exists: $path"))
        end
        write(path, reports[name])
        written[name] = path
    end
    written
end

function write_snapshot_bundle_reports(
    directory::AbstractString,
    source;
    overwrite::Bool=false,
    ansi_options::NamedTuple=(;),
    svg_options::NamedTuple=(;),
)
    write_snapshot_bundle_reports(
        directory,
        snapshot_bundle(source; ansi_options, svg_options);
        overwrite,
    )
end

"""Verify written snapshot bundle files against their manifest digests."""
function verify_snapshot_bundle_artifacts(directory::AbstractString; allow_extra::Bool=false)
    isdir(directory) ||
        throw(BufferAssertionError("snapshot bundle artifact directory does not exist: $directory"))
    entries = Dict(record.name => (bytes=record.bytes, sha256=record.sha256) for record in read_snapshot_bundle_manifest_records(directory))
    expected_files = union(Set(keys(entries)), Set(["manifest.txt"]))
    actual_files = Set(name for name in readdir(directory) if isfile(joinpath(directory, name)))
    if !allow_extra
        extra = sort!(collect(setdiff(actual_files, expected_files)))
        isempty(extra) || throw(BufferAssertionError(
            "unexpected snapshot bundle artifact files: $(join(extra, ", "))",
        ))
    end
    for name in sort!(collect(keys(entries)))
        path = joinpath(directory, name)
        isfile(path) || throw(BufferAssertionError("missing snapshot bundle artifact: $path"))
        content = read(path, String)
        entry = entries[name]
        sizeof(content) == entry.bytes || throw(BufferAssertionError(
            "snapshot bundle artifact byte count mismatch for $name: expected $(entry.bytes), actual $(sizeof(content))",
        ))
        digest = _sha256_hex(content)
        digest == entry.sha256 || throw(BufferAssertionError(
            "snapshot bundle artifact sha256 mismatch for $name: expected $(entry.sha256), actual $digest",
        ))
    end
    true
end

"""Assert that a written artifact directory matches an expected snapshot bundle."""
function assert_snapshot_bundle_artifacts(
    directory::AbstractString,
    expected::SnapshotBundle;
    allow_extra::Bool=false,
)
    expected_artifacts = snapshot_bundle_artifacts(expected)
    for name in sort!(collect(keys(expected_artifacts)))
        path = joinpath(directory, name)
        isfile(path) || throw(BufferAssertionError("missing snapshot bundle artifact: $path"))
        actual = read(path, String)
        expected_content = expected_artifacts[name]
        actual == expected_content || throw(BufferAssertionError(
            _snapshot_mismatch_message("snapshot bundle artifact $name", expected_content, actual),
        ))
    end
    verify_snapshot_bundle_artifacts(directory; allow_extra)
    directory
end

"""Assert that all visual artifacts in a snapshot bundle match expected values."""
function assert_snapshot_bundle(actual::SnapshotBundle, expected::SnapshotBundle)
    actual == expected || throw(BufferAssertionError(
        _snapshot_mismatch_message("snapshot bundle", (
            source_kind=expected.source_kind,
            plain=expected.plain,
            ansi=expected.ansi,
            structured=expected.structured,
            svg=expected.svg,
        ), (
            source_kind=actual.source_kind,
            plain=actual.plain,
            ansi=actual.ansi,
            structured=actual.structured,
            svg=actual.svg,
        )),
    ))
    actual
end

assert_snapshot_bundle(source, expected::SnapshotBundle; kwargs...) =
    assert_snapshot_bundle(snapshot_bundle(source; kwargs...), expected)

"""Assert a stable SVG snapshot for visual regression tests."""
function assert_svg_snapshot(source, expected::AbstractString; kwargs...)
    actual = svg_snapshot(source; kwargs...)
    actual == expected || throw(BufferAssertionError(
        _snapshot_mismatch_message("SVG snapshot", String(expected), actual),
    ))
    source
end

function key!(
    pilot::WidgetPilot,
    key::Symbol;
    text::AbstractString="",
    modifiers::KeyModifiers=NONE,
    kind=KeyPress,
)
    send!(pilot, KeyEvent(Key(key); text, modifiers, kind))
end

function press!(
    pilot::WidgetPilot,
    key::Symbol;
    text::AbstractString="",
    modifiers::KeyModifiers=NONE,
)
    _combine_widget_results(WidgetPilotResult[
        key!(pilot, key; text, modifiers, kind=KeyPress),
        key!(pilot, key; text, modifiers, kind=KeyRelease),
    ])
end

function type_text!(pilot::WidgetPilot, text::AbstractString)
    results = WidgetPilotResult[]
    for grapheme in Unicode.graphemes(text)
        if grapheme == "\n"
            push!(results, key!(pilot, :enter; text="\n"))
        elseif grapheme == "\t"
            push!(results, key!(pilot, :tab; text="\t"))
        else
            push!(results, key!(pilot, :character; text=String(grapheme)))
        end
    end
    results
end

paste!(pilot::WidgetPilot, text::AbstractString) = send!(pilot, PasteEvent(String(text)))

function mouse!(
    pilot::WidgetPilot,
    row::Integer,
    column::Integer,
    button::MouseButton,
    action::MouseAction;
    modifiers::KeyModifiers=NONE,
    click_count::Integer=1,
)
    send!(pilot, MouseEvent(
        Position(row, column),
        button,
        action;
        modifiers,
        click_count,
    ))
end

function click!(
    pilot::WidgetPilot,
    row::Integer,
    column::Integer;
    button::MouseButton=LeftMouseButton,
    click_count::Integer=1,
)
    mouse!(pilot, row, column, button, MousePress; click_count)
    mouse!(pilot, row, column, button, MouseRelease; click_count)
end

double_click!(pilot::WidgetPilot, row::Integer, column::Integer; button::MouseButton=LeftMouseButton) =
    click!(pilot, row, column; button, click_count=2)

right_click!(pilot::WidgetPilot, row::Integer, column::Integer) =
    click!(pilot, row, column; button=RightMouseButton)

scroll_up!(pilot::WidgetPilot, row::Integer, column::Integer; steps::Integer=1) =
    _combine_widget_results(WidgetPilotResult[
        mouse!(pilot, row, column, WheelUpButton, MouseScroll)
        for _ in 1:max(0, Int(steps))
    ])

scroll_down!(pilot::WidgetPilot, row::Integer, column::Integer; steps::Integer=1) =
    _combine_widget_results(WidgetPilotResult[
        mouse!(pilot, row, column, WheelDownButton, MouseScroll)
        for _ in 1:max(0, Int(steps))
    ])

function drag!(
    pilot::WidgetPilot,
    from_row::Integer,
    from_column::Integer,
    to_row::Integer,
    to_column::Integer;
    button::MouseButton=LeftMouseButton,
)
    _combine_widget_results(WidgetPilotResult[
        mouse!(pilot, from_row, from_column, button, MousePress),
        mouse!(pilot, to_row, to_column, button, MouseDrag),
        mouse!(pilot, to_row, to_column, button, MouseRelease),
    ])
end

hover!(pilot::WidgetPilot, row::Integer, column::Integer) =
    mouse!(pilot, row, column, NoMouseButton, MouseMove)

function resize_terminal!(pilot::WidgetPilot, height::Integer, width::Integer)
    resize_backend!(pilot.backend, height, width)
    draw!(pilot)
end

function key!(
    pilot::RuntimePilot,
    key::Symbol;
    text::AbstractString="",
    modifiers::KeyModifiers=NONE,
    kind=KeyPress,
)
    send!(pilot, KeyEvent(Key(key); text, modifiers, kind))
end

function press!(
    pilot::RuntimePilot,
    key::Symbol;
    text::AbstractString="",
    modifiers::KeyModifiers=NONE,
)
    _combine_runtime_results(RuntimePilotResult[
        key!(pilot, key; text, modifiers, kind=KeyPress),
        key!(pilot, key; text, modifiers, kind=KeyRelease),
    ])
end

function type_text!(pilot::RuntimePilot, text::AbstractString)
    results = RuntimePilotResult[]
    for grapheme in Unicode.graphemes(text)
        if grapheme == "\n"
            push!(results, key!(pilot, :enter; text="\n"))
        elseif grapheme == "\t"
            push!(results, key!(pilot, :tab; text="\t"))
        else
            push!(results, key!(pilot, :character; text=String(grapheme)))
        end
        pilot.exited && break
    end
    results
end

paste!(pilot::RuntimePilot, text::AbstractString) = send!(pilot, PasteEvent(String(text)))

function mouse!(
    pilot::RuntimePilot,
    row::Integer,
    column::Integer,
    button::MouseButton,
    action::MouseAction;
    modifiers::KeyModifiers=NONE,
    click_count::Integer=1,
)
    send!(pilot, MouseEvent(
        Position(row, column),
        button,
        action;
        modifiers,
        click_count,
    ))
end

function click!(
    pilot::RuntimePilot,
    row::Integer,
    column::Integer;
    button::MouseButton=LeftMouseButton,
    click_count::Integer=1,
)
    mouse!(pilot, row, column, button, MousePress; click_count)
    mouse!(pilot, row, column, button, MouseRelease; click_count)
end

double_click!(pilot::RuntimePilot, row::Integer, column::Integer; button::MouseButton=LeftMouseButton) =
    click!(pilot, row, column; button, click_count=2)

right_click!(pilot::RuntimePilot, row::Integer, column::Integer) =
    click!(pilot, row, column; button=RightMouseButton)

scroll_up!(pilot::RuntimePilot, row::Integer, column::Integer; steps::Integer=1) =
    _combine_runtime_results(RuntimePilotResult[
        mouse!(pilot, row, column, WheelUpButton, MouseScroll)
        for _ in 1:max(0, Int(steps))
    ])

scroll_down!(pilot::RuntimePilot, row::Integer, column::Integer; steps::Integer=1) =
    _combine_runtime_results(RuntimePilotResult[
        mouse!(pilot, row, column, WheelDownButton, MouseScroll)
        for _ in 1:max(0, Int(steps))
    ])

function drag!(
    pilot::RuntimePilot,
    from_row::Integer,
    from_column::Integer,
    to_row::Integer,
    to_column::Integer;
    button::MouseButton=LeftMouseButton,
)
    _combine_runtime_results(RuntimePilotResult[
        mouse!(pilot, from_row, from_column, button, MousePress),
        mouse!(pilot, to_row, to_column, button, MouseDrag),
        mouse!(pilot, to_row, to_column, button, MouseRelease),
    ])
end

hover!(pilot::RuntimePilot, row::Integer, column::Integer) =
    mouse!(pilot, row, column, NoMouseButton, MouseMove)

function resize_terminal!(pilot::RuntimePilot, height::Integer, width::Integer)
    resize_backend!(pilot.backend, height, width)
    pilot.redraw = true
    send!(pilot, ResizeEvent(Size(height, width)))
end

export BufferAssertionError,
       ElementMatch,
       RuntimePilot,
       RuntimePilotResult,
       ScheduledToken,
       SnapshotArtifactRecord,
       SnapshotArtifactSummary,
       SnapshotBundle,
       PilotEvidenceBundle,
       PilotEvidenceSummary,
       PilotStatus,
       ToolkitPilot,
       VirtualClock,
       WidgetPilot,
       WidgetPilotResult,
       advance_time!,
       ansi_snapshot,
       assert_ansi_snapshot,
       assert_buffer,
       assert_cell,
       assert_command,
       assert_exited,
       assert_focus,
       assert_message,
       assert_messages,
       assert_model,
       assert_no_focus,
       assert_no_messages,
       assert_no_processed_messages,
       assert_no_query,
       assert_no_runtime_queue,
       assert_pilot_evidence_bundle_artifacts,
       assert_pilot_evidence_package_artifacts,
       assert_pilot_evidence_package_report_artifacts,
       assert_pilot_evidence_report_artifacts,
       assert_plain_snapshot,
       assert_pending_scheduled,
       assert_query,
       assert_query_one,
       assert_processed_messages,
       assert_runtime_queue,
       assert_running,
       assert_snapshot_bundle_artifacts,
       assert_snapshot_bundle,
       assert_structured_snapshot,
       assert_svg_snapshot,
       assert_virtual_time,
       cancel_scheduled!,
       click!,
       double_click!,
       drag!,
       draw!,
       exit_result,
       focus_element!,
       focused_element,
       hover!,
       key!,
       last_command,
       messages,
       mouse!,
       paste!,
       pilot_exited,
       pilot_evidence_artifact_manifest_markdown,
       pilot_evidence_artifact_manifest_tsv,
       pilot_evidence_artifact_summary,
       pilot_evidence_bundle,
       pilot_evidence_markdown,
       pilot_evidence_manifest,
       pilot_evidence_manifest_markdown,
       pilot_evidence_manifest_records,
       pilot_evidence_manifest_tsv,
       pilot_evidence_package_artifact_manifest_markdown,
       pilot_evidence_package_artifact_manifest_tsv,
       pilot_evidence_package_artifact_summary,
       pilot_evidence_package_artifact_summary_markdown,
       pilot_evidence_package_artifact_summary_text,
       pilot_evidence_package_artifact_summary_tsv,
       pilot_evidence_package_manifest_markdown,
       pilot_evidence_package_manifest_records,
       pilot_evidence_package_manifest_tsv,
       pilot_evidence_package_report_artifact_manifest_markdown,
       pilot_evidence_package_report_artifact_manifest_tsv,
       pilot_evidence_package_report_artifact_summary,
       pilot_evidence_package_report_artifact_summary_markdown,
       pilot_evidence_package_report_artifact_summary_text,
       pilot_evidence_package_report_artifact_summary_tsv,
       pilot_evidence_package_report_artifacts,
       pilot_evidence_package_report_manifest_markdown,
       pilot_evidence_package_report_manifest_records,
       pilot_evidence_package_report_manifest_tsv,
       pilot_evidence_package_report_summary,
       pilot_evidence_package_report_summary_markdown,
       pilot_evidence_package_report_summary_text,
       pilot_evidence_package_report_summary_tsv,
       pilot_evidence_package_summary,
       pilot_evidence_package_summary_markdown,
       pilot_evidence_package_summary_text,
       pilot_evidence_package_summary_tsv,
       pilot_evidence_report_artifact_manifest_markdown,
       pilot_evidence_report_artifact_manifest_tsv,
       pilot_evidence_report_artifact_summary,
       pilot_evidence_report_artifact_summary_markdown,
       pilot_evidence_report_artifact_summary_text,
       pilot_evidence_report_artifact_summary_tsv,
       pilot_evidence_report_artifacts,
       pilot_evidence_report_manifest_markdown,
       pilot_evidence_report_manifest_records,
       pilot_evidence_report_manifest_tsv,
       pilot_evidence_report_summary,
       pilot_evidence_report_summary_markdown,
       pilot_evidence_report_summary_text,
       pilot_evidence_report_summary_tsv,
       pilot_evidence_summary,
       pilot_evidence_summary_markdown,
       pilot_evidence_summary_text,
       pilot_evidence_summary_tsv,
       pilot_evidence_text,
       pilot_evidence_tsv,
       pilot_model,
       pilot_status,
       pilot_status_markdown,
       pilot_status_text,
       pilot_status_tsv,
       plain_snapshot,
       press!,
       query,
       query_one,
       read_pilot_evidence_manifest_records,
       read_pilot_evidence_package_manifest_records,
       read_pilot_evidence_package_report_manifest_records,
       read_pilot_evidence_report_manifest_records,
       read_snapshot_bundle_manifest_records,
       request_exit!,
       right_click!,
       resize_terminal!,
       runtime_queue,
       scroll_down!,
       scroll_up!,
       pending_scheduled,
       processed_messages,
       schedule_after!,
       send!,
       snapshot_artifact_summary_markdown,
       snapshot_artifact_summary_text,
       snapshot_artifact_summary_tsv,
       snapshot_bundle_artifact_manifest_markdown,
       snapshot_bundle_artifact_manifest_tsv,
       snapshot_bundle_artifact_summary,
       snapshot_bundle_artifacts,
       snapshot_bundle_manifest,
       snapshot_bundle_manifest_markdown,
       snapshot_bundle_manifest_records,
       snapshot_bundle_manifest_tsv,
       snapshot_bundle_payloads,
       snapshot_bundle_report_artifacts,
       snapshot_bundle,
       snapshot_bundle_summary,
       snapshot_manifest_records_markdown,
       snapshot_manifest_records_tsv,
       structured_snapshot,
       svg_snapshot,
       take_messages!,
       type_text!,
       verify_pilot_evidence_bundle,
       verify_pilot_evidence_package,
       verify_pilot_evidence_package_report_artifacts,
       verify_pilot_evidence_report_artifacts,
       verify_snapshot_bundle_artifacts,
       virtual_time_ns,
       wait_for_ansi_snapshot!,
       wait_for_buffer!,
       wait_for_cell!,
       wait_for_command!,
       wait_for_exit!,
       wait_for_focus!,
       wait_for_message!,
       wait_for_model!,
       wait_for_no_focus!,
       wait_for_no_messages!,
       wait_for_processed_messages!,
       wait_for_no_query!,
       wait_for_runtime_queue!,
       wait_for_plain_snapshot!,
       wait_for_pending_scheduled!,
       wait_for_query!,
       wait_for_running!,
       wait_for_snapshot_bundle!,
       wait_for_snapshot_bundle_where!,
       wait_for_structured_snapshot!,
       wait_for_svg_snapshot!,
       wait_for_text!,
       wait_for_virtual_time!,
       wait_query!,
       wait_messages!,
       wait_runtime_queue!,
       wait_query_one!,
       wait_until!,
       write_pilot_evidence_bundle,
       write_pilot_evidence_package,
       write_pilot_evidence_package_reports,
       write_pilot_evidence_reports,
       write_snapshot_bundle,
       write_snapshot_bundle_reports

end
