module Runtime

import Base: run
using FileWatching: watch_file
using ..Backends
using ..Core
using ..Events
import ..Core: render!

"""Marker type for applications managed by Wicked's model/update/view runtime."""
abstract type WickedApp end

"""Initialize an application's domain model."""
function initialize end

"""Update an application model in response to a message."""
function update! end

"""Return an immediate-mode widget tree or declarative `ApplicationView`."""
function app_view end

"""Return the current set of ongoing application subscriptions."""
subscriptions(::WickedApp, model) = ()

"""Attach runtime-owned wake-up services to an application model."""
attach_runtime!(::WickedApp, model, runtime) = model

"""Content plus terminal presentation requested by one model view."""
struct ApplicationView{C}
    content::C
    title::Union{Nothing,String}
    modes::TerminalModeRequest
    cursor::Union{Missing,Nothing,CursorRequest}
end

function ApplicationView(
    content;
    title::Union{Nothing,AbstractString}=nothing,
    cursor::Union{Missing,Nothing,CursorRequest}=missing,
    alternate_screen::Union{Nothing,Bool}=nothing,
    mouse_capture::Union{Nothing,Bool}=nothing,
    mouse_tracking::Union{Nothing,MouseTrackingMode}=nothing,
    focus_reporting::Union{Nothing,Bool}=nothing,
    bracketed_paste::Union{Nothing,Bool}=nothing,
)
    ApplicationView(
        content,
        title === nothing ? nothing : String(title),
        TerminalModeRequest(;
            alternate_screen,
            mouse_capture,
            mouse_tracking,
            focus_reporting,
            bracketed_paste,
        ),
        cursor,
    )
end

_application_view(view::ApplicationView) = view
_application_view(content) = ApplicationView(content)

"""Render a resolved application view into a frame."""
function render_application!(frame::Frame, view::ApplicationView)
    render!(frame, view.content, frame.area)
    ismissing(view.cursor) || (frame.cursor = view.cursor)
    frame
end

"""Render an application model into a frame."""
function render_application!(frame::Frame, app::WickedApp, model)
    render_application!(frame, _application_view(app_view(app, model)))
end

"""Base type for finite effects returned from an update."""
abstract type AbstractCommand end

struct NoCommand <: AbstractCommand end

struct MessageCommand{T} <: AbstractCommand
    message::T
end

struct DelayCommand{T} <: AbstractCommand
    delay_seconds::Float64
    message::T

    function DelayCommand(delay::Real, message)
        delay >= 0 || throw(ArgumentError("command delay must be non-negative"))
        new{typeof(message)}(Float64(delay), message)
    end
end

struct TaskCommand{F,S,E,K} <: AbstractCommand
    id::K
    work::F
    on_success::S
    on_error::E
    replace::Bool
end

"""Finite operation executed against the terminal on the runtime UI task."""
struct TerminalCommand{F,S,E,K} <: AbstractCommand
    id::K
    operation::F
    on_success::S
    on_error::E
end

"""Captured result of an explicitly requested operating-system process."""
struct ProcessResult
    command::Cmd
    exit_code::Int
    stdout::Vector{UInt8}
    stderr::Vector{UInt8}
end

process_succeeded(result::ProcessResult) = result.exit_code == 0

"""A checked process completed with a nonzero exit status."""
struct ProcessExitError <: Exception
    result::ProcessResult
end

function Base.showerror(io::IO, error::ProcessExitError)
    print(io, "process exited with status ", error.result.exit_code, ": ", error.result.command)
end

"""Captured process output exceeded its configured byte bound."""
struct ProcessOutputLimitError <: Exception
    stream::Symbol
    maximum_bytes::Int
end

function Base.showerror(io::IO, error::ProcessOutputLimitError)
    print(io, "process ", error.stream, " exceeded ", error.maximum_bytes, " bytes")
end

"""Cancellable subprocess command with bounded byte capture."""
struct ProcessCommand{S,E,K} <: AbstractCommand
    id::K
    command::Cmd
    input::Union{Nothing,Vector{UInt8}}
    check::Bool
    maximum_output_bytes::Int
    on_success::S
    on_error::E
    replace::Bool
end

function ProcessCommand(
    command::Cmd;
    id=nothing,
    input::Union{Nothing,AbstractString,AbstractVector{UInt8}}=nothing,
    check::Bool=false,
    maximum_output_bytes::Integer=1024 * 1024,
    on_success::S=identity,
    on_error::E=identity,
    replace::Bool=false,
) where {S,E}
    maximum_output_bytes > 0 ||
        throw(ArgumentError("maximum process output size must be positive"))
    maximum_output_bytes <= typemax(Int) ||
        throw(ArgumentError("maximum process output size is too large"))
    bytes = isnothing(input) ? nothing :
            input isa AbstractString ? collect(codeunits(String(input))) : collect(UInt8, input)
    ProcessCommand{S,E,typeof(id)}(
        id,
        command,
        bytes,
        check,
        Int(maximum_output_bytes),
        on_success,
        on_error,
        replace,
    )
end

function TerminalCommand(
    operation::F;
    id=nothing,
    on_success::S=identity,
    on_error::E=identity,
) where {F,S,E}
    TerminalCommand{F,S,E,typeof(id)}(id, operation, on_success, on_error)
end

function TaskCommand(
    work::F;
    id=nothing,
    on_success::S=identity,
    on_error::E=identity,
    replace::Bool=false,
) where {F,S,E}
    TaskCommand{F,S,E,typeof(id)}(id, work, on_success, on_error, replace)
end

"""Validated retry/backoff policy for `RetryCommand`."""
struct RetryPolicy{F}
    maximum_attempts::Int
    initial_delay_seconds::Float64
    multiplier::Float64
    maximum_delay_seconds::Float64
    retry_if::F
end

function RetryPolicy(
    ;
    maximum_attempts::Integer=3,
    initial_delay::Real=0,
    multiplier::Real=2,
    maximum_delay::Real=Inf,
    retry_if=(error, attempt) -> true,
)
    maximum_attempts > 0 || throw(ArgumentError("maximum retry attempts must be positive"))
    initial_delay >= 0 || throw(ArgumentError("initial retry delay must be non-negative"))
    isfinite(multiplier) && multiplier >= 1 ||
        throw(ArgumentError("retry multiplier must be finite and at least one"))
    (isfinite(maximum_delay) && maximum_delay >= 0) || maximum_delay == Inf ||
        throw(ArgumentError("maximum retry delay must be non-negative or Inf"))
    maximum_delay >= initial_delay ||
        throw(ArgumentError("maximum retry delay must not be smaller than initial delay"))
    RetryPolicy{typeof(retry_if)}(
        Int(maximum_attempts),
        Float64(initial_delay),
        Float64(multiplier),
        Float64(maximum_delay),
        retry_if,
    )
end

"""Return the delay after a failed retry attempt (the first failure is attempt one)."""
function retry_delay(policy::RetryPolicy, failed_attempt::Integer)
    failed_attempt > 0 || throw(ArgumentError("failed retry attempt must be positive"))
    min(
        policy.maximum_delay_seconds,
        policy.initial_delay_seconds * policy.multiplier^(Int(failed_attempt) - 1),
    )
end

"""A cooperative per-attempt timeout elapsed before work returned."""
struct CommandTimeoutError <: Exception
    timeout_seconds::Float64
end

Base.showerror(io::IO, error::CommandTimeoutError) =
    print(io, "command attempt exceeded timeout of ", error.timeout_seconds, " seconds")

"""A retry policy exhausted all permitted attempts."""
struct RetryExhaustedError{E} <: Exception
    attempts::Int
    error::E
end

function Base.showerror(io::IO, error::RetryExhaustedError)
    print(io, "command retry exhausted after ", error.attempts, " attempts: ")
    showerror(io, error.error)
end

"""Asynchronous work with explicit retry/backoff, cooperative timeout, and exhaustion semantics."""
struct RetryCommand{F,S,E,K,P<:RetryPolicy} <: AbstractCommand
    id::K
    work::F
    on_success::S
    on_error::E
    replace::Bool
    policy::P
    timeout_seconds::Union{Nothing,Float64}
end

function RetryCommand(
    work::F;
    id=nothing,
    on_success::S=identity,
    on_error::E=identity,
    replace::Bool=false,
    policy::RetryPolicy=RetryPolicy(),
    timeout::Union{Nothing,Real}=nothing,
) where {F,S,E}
    timeout_value = isnothing(timeout) ? nothing : Float64(timeout)
    isnothing(timeout_value) ||
        (isfinite(timeout_value) && timeout_value > 0) ||
        throw(ArgumentError("retry command timeout must be finite and positive"))
    RetryCommand{F,S,E,typeof(id),typeof(policy)}(
        id,
        work,
        on_success,
        on_error,
        replace,
        policy,
        timeout_value,
    )
end

retry_command(work; kwargs...) = RetryCommand(work; kwargs...)

struct BatchCommand <: AbstractCommand
    commands::Vector{AbstractCommand}
end

BatchCommand(commands::AbstractVector{<:AbstractCommand}) =
    BatchCommand(AbstractCommand[commands...])
BatchCommand(commands::AbstractCommand...) = BatchCommand(AbstractCommand[commands...])

"""Ordered command composition.

Children start in declaration order. A child starts only after the preceding
child has completed and enqueued its result message. A nested `BatchCommand`
acts as a barrier: all of its children complete before the sequence advances.
Application messages remain FIFO, so each command result is observed before a
later sequence step is started.
"""
struct SequenceCommand <: AbstractCommand
    commands::Vector{AbstractCommand}
end

SequenceCommand(commands::AbstractVector{<:AbstractCommand}) =
    SequenceCommand(AbstractCommand[commands...])
SequenceCommand(commands::AbstractCommand...) = SequenceCommand(AbstractCommand[commands...])

function _map_command_callback(mapper, callback)
    return value -> begin
        message = callback(value)
        isnothing(message) ? nothing : mapper(message)
    end
end

"""Transform every application-message payload emitted by a command tree.

`BatchCommand` and `SequenceCommand` are mapped recursively without changing
their concurrent or ordered completion semantics. Command IDs remain runtime
envelopes: callbacks are mapped before `CommandFinished` is applied.
Commands that emit no application message are returned unchanged.
"""
map_command(mapper, command::NoCommand) = command
map_command(mapper, command::MessageCommand) = MessageCommand(mapper(command.message))
map_command(mapper, command::DelayCommand) =
    DelayCommand(command.delay_seconds, mapper(command.message))
map_command(mapper, command::TaskCommand) = TaskCommand(
    command.work;
    id=command.id,
    on_success=_map_command_callback(mapper, command.on_success),
    on_error=_map_command_callback(mapper, command.on_error),
    replace=command.replace,
)
map_command(mapper, command::RetryCommand) = RetryCommand(
    command.work;
    id=command.id,
    on_success=_map_command_callback(mapper, command.on_success),
    on_error=_map_command_callback(mapper, command.on_error),
    replace=command.replace,
    policy=command.policy,
    timeout=command.timeout_seconds,
)
map_command(mapper, command::TerminalCommand) = TerminalCommand(
    command.operation;
    id=command.id,
    on_success=_map_command_callback(mapper, command.on_success),
    on_error=_map_command_callback(mapper, command.on_error),
)
map_command(mapper, command::ProcessCommand) = ProcessCommand(
    command.command;
    id=command.id,
    input=command.input,
    check=command.check,
    maximum_output_bytes=command.maximum_output_bytes,
    on_success=_map_command_callback(mapper, command.on_success),
    on_error=_map_command_callback(mapper, command.on_error),
    replace=command.replace,
)
map_command(mapper, command::BatchCommand) =
    BatchCommand(map(child -> map_command(mapper, child), command.commands))
map_command(mapper, command::SequenceCommand) =
    SequenceCommand(map(child -> map_command(mapper, child), command.commands))

struct CancelCommand{K} <: AbstractCommand
    id::K
end

struct ExitCommand{T} <: AbstractCommand
    result::T
end

ExitCommand() = ExitCommand(nothing)

"""Request a frame without initiating another effect."""
struct FrameCommand <: AbstractCommand end

"""Leave terminal modes around an explicit operating-system suspension action."""
struct SuspendCommand{F,S,E,K} <: AbstractCommand
    id::K
    operation::F
    on_success::S
    on_error::E
end

function SuspendCommand(
    operation::F;
    id=nothing,
    on_success::S=identity,
    on_error::E=identity,
) where {F,S,E}
    applicable(operation) || throw(ArgumentError("suspend operation must accept no arguments"))
    SuspendCommand{F,S,E,typeof(id)}(id, operation, on_success, on_error)
end

map_command(mapper, command::CancelCommand) = command
map_command(mapper, command::ExitCommand) = command
map_command(mapper, command::FrameCommand) = command
map_command(mapper, command::SuspendCommand) = SuspendCommand(
    command.operation;
    id=command.id,
    on_success=_map_command_callback(mapper, command.on_success),
    on_error=_map_command_callback(mapper, command.on_error),
)

"""Base type for an ongoing event source declared by application state."""
abstract type AbstractSubscription end

struct IntervalSubscription{F,K} <: AbstractSubscription
    id::K
    interval_seconds::Float64
    message::F

    function IntervalSubscription(id::K, interval::Real, message::F) where {F,K}
        interval > 0 || throw(ArgumentError("subscription interval must be positive"))
        new{F,K}(id, Float64(interval), message)
    end
end

"""Model-derived callback event source with deterministic cleanup.

`register(emit)` installs the external listener and must return either a
zero-argument cleanup callback or `nothing`. Calling `emit(message)` enqueues a
normal application message while the subscription is active. `revision` gives
recreated closures stable identity: subscriptions with equal non-`nothing`
revisions are retained without re-registering.
"""
struct EventSubscription{K,F,R} <: AbstractSubscription
    id::K
    register::F
    revision::R

    function EventSubscription(id::K, register::F; revision=nothing) where {K,F}
        applicable(register, identity) ||
            throw(ArgumentError("event subscription register callback must accept emit"))
        new{K,F,typeof(revision)}(id, register, revision)
    end
end

_channel_subscription_message(value) = value
_channel_subscription_error(failure) = failure

"""Adapt a single-consumer `Channel` into a model-derived event subscription.

The reader cooperatively polls so removal never injects asynchronous exceptions
into Julia tasks. Buffered values are drained before a closed channel stops the
reader. `mapper(value)` transforms each item, while `on_error(RuntimeFailure)`
may return an application message or `nothing`. Set `close_on_cleanup=true`
only when the subscription owns the source channel.
"""
function channel_subscription(
    id,
    channel::Channel;
    mapper=_channel_subscription_message,
    on_error=_channel_subscription_error,
    poll_interval::Real=0.01,
    close_on_cleanup::Bool=false,
    revision=(channel, mapper, on_error, Float64(poll_interval), close_on_cleanup),
)
    interval = Float64(poll_interval)
    isfinite(interval) && interval > 0 ||
        throw(ArgumentError("channel subscription poll interval must be finite and positive"))
    register = emit -> begin
        active = Threads.Atomic{Bool}(true)
        @async begin
            try
                while active[]
                    if isready(channel)
                        value = take!(channel)
                        applicable(mapper, value) ||
                            throw(ArgumentError("channel subscription mapper must accept a channel value"))
                        emit(mapper(value))
                    elseif !isopen(channel)
                        break
                    else
                        sleep(interval)
                    end
                end
            catch error
                if active[]
                    failure = RuntimeFailure(:subscription, id, error, catch_backtrace())
                    message = try
                        applicable(on_error, failure) || throw(ArgumentError(
                            "channel subscription error callback must accept RuntimeFailure",
                        ))
                        on_error(failure)
                    catch callback_error
                        RuntimeFailure(
                            :subscription,
                            id,
                            callback_error,
                            catch_backtrace(),
                        )
                    end
                    isnothing(message) || emit(message)
                end
            end
        end
        () -> begin
            active[] = false
            close_on_cleanup && isopen(channel) && close(channel)
            nothing
        end
    end
    EventSubscription(id, register; revision)
end

"""Portable runtime message describing one watched-file observation."""
struct FileWatchEvent
    path::String
    renamed::Bool
    changed::Bool
end

_file_subscription_message(path, event) =
    FileWatchEvent(path, event.renamed, event.changed)

function _invoke_file_subscription_mapper(mapper, path, event)
    applicable(mapper, path, event) && return mapper(path, event)
    applicable(mapper, event) && return mapper(event)
    throw(ArgumentError("file subscription mapper must accept event or (path, event)"))
end

"""Watch a path and emit model/update messages for file-system changes.

Bounded `watch_file` calls make removal cooperative without asynchronous task
interruption. Timed-out observations are internal and never emitted. The mapper
may accept the raw `FileWatching.FileEvent` or `(path, event)`; the default
returns `FileWatchEvent`. Errors are converted through `on_error` just like
`channel_subscription` failures.
"""
function file_subscription(
    id,
    path::AbstractString;
    mapper=_file_subscription_message,
    on_error=_channel_subscription_error,
    wait_timeout::Real=0.1,
    revision=(String(path), mapper, on_error, Float64(wait_timeout)),
)
    watched_path = String(path)
    isempty(watched_path) && throw(ArgumentError("file subscription path cannot be empty"))
    timeout = Float64(wait_timeout)
    isfinite(timeout) && timeout > 0 ||
        throw(ArgumentError("file subscription wait timeout must be finite and positive"))
    register = emit -> begin
        active = Threads.Atomic{Bool}(true)
        @async begin
            try
                while active[]
                    event = watch_file(watched_path, timeout)
                    active[] || break
                    event.timedout && continue
                    emit(_invoke_file_subscription_mapper(mapper, watched_path, event))
                end
            catch error
                if active[]
                    failure = RuntimeFailure(:subscription, id, error, catch_backtrace())
                    message = try
                        applicable(on_error, failure) || throw(ArgumentError(
                            "file subscription error callback must accept RuntimeFailure",
                        ))
                        on_error(failure)
                    catch callback_error
                        RuntimeFailure(
                            :subscription,
                            id,
                            callback_error,
                            catch_backtrace(),
                        )
                    end
                    isnothing(message) || emit(message)
                end
            end
        end
        () -> begin
            active[] = false
            nothing
        end
    end
    EventSubscription(id, register; revision)
end

"""One bounded stdout or stderr payload emitted by a process subscription."""
struct ProcessStreamChunk{K}
    id::K
    stream::Symbol
    bytes::Vector{UInt8}
end

"""Final process status emitted after both output streams have drained."""
struct ProcessStreamExit{K}
    id::K
    command::Cmd
    exit_code::Int
end

_process_stream_chunk(id, stream, bytes) = ProcessStreamChunk(id, stream, bytes)
_process_stream_exit(id, command, exit_code) = ProcessStreamExit(id, command, exit_code)

function _invoke_process_chunk_mapper(mapper, id, stream, bytes)
    applicable(mapper, id, stream, bytes) && return mapper(id, stream, bytes)
    applicable(mapper, stream, bytes) && return mapper(stream, bytes)
    throw(ArgumentError(
        "process chunk mapper must accept (stream, bytes) or (id, stream, bytes)",
    ))
end


function _invoke_process_exit_mapper(mapper, id, command, exit_code)
    applicable(mapper, id, command, exit_code) && return mapper(id, command, exit_code)
    applicable(mapper, command, exit_code) && return mapper(command, exit_code)
    applicable(mapper, exit_code) && return mapper(exit_code)
    throw(ArgumentError(
        "process exit mapper must accept exit code, (command, exit code), or (id, command, exit code)",
    ))
end


function _stream_process_pipe!(
    stream::Pipe,
    name::Symbol,
    active::Threads.Atomic{Bool},
    emit,
    id,
    mapper,
    maximum_chunk_bytes::Int,
)
    while active[] && !eof(stream)
        first_byte = try
            read(stream, UInt8)
        catch error
            error isa EOFError && break
            rethrow()
        end
        bytes = UInt8[first_byte]
        append!(bytes, readavailable(stream))
        offset = 1
        while active[] && offset <= length(bytes)
            last_index = min(length(bytes), offset + maximum_chunk_bytes - 1)
            chunk = copy(@view bytes[offset:last_index])
            emit(_invoke_process_chunk_mapper(mapper, id, name, chunk))
            offset = last_index + 1
        end
    end
    nothing
end


"""Stream a child process into model/update messages.

The default messages are `ProcessStreamChunk` for bounded stdout/stderr chunks
and one `ProcessStreamExit` after both pipes drain. Removing or replacing the
subscription terminates the child and deactivates all later emissions. Nonzero
exit status is represented by the exit message; launch, read, and mapper errors
are routed through `on_error(RuntimeFailure)`.
"""
function process_subscription(
    id,
    command::Cmd;
    input::Union{Nothing,AbstractString,AbstractVector{UInt8}}=nothing,
    chunk_mapper=_process_stream_chunk,
    exit_mapper=_process_stream_exit,
    on_error=_channel_subscription_error,
    maximum_chunk_bytes::Integer=4096,
    revision=(command, input, chunk_mapper, exit_mapper, on_error, Int(maximum_chunk_bytes)),
)
    maximum_chunk_bytes > 0 ||
        throw(ArgumentError("process stream chunk size must be positive"))
    maximum_chunk_bytes <= typemax(Int) ||
        throw(ArgumentError("process stream chunk size is too large"))
    chunk_size = Int(maximum_chunk_bytes)
    input_bytes = isnothing(input) ? nothing :
                  input isa AbstractString ? collect(codeunits(String(input))) : collect(UInt8, input)
    register = emit -> begin
        active = Threads.Atomic{Bool}(true)
        process_ref = Ref{Union{Nothing,Base.Process}}(nothing)
        @async begin
            stdout_pipe = Pipe()
            stderr_pipe = Pipe()
            try
                active[] || return
                process_input = isnothing(input_bytes) ? devnull : IOBuffer(input_bytes)
                process = run(
                    pipeline(
                        ignorestatus(command),
                        stdin=process_input,
                        stdout=stdout_pipe,
                        stderr=stderr_pipe,
                    );
                    wait=false,
                )
                process_ref[] = process
                close(stdout_pipe.in)
                close(stderr_pipe.in)
                active[] || _terminate_process!(process)
                stdout_task = @async _stream_process_pipe!(
                    stdout_pipe,
                    :stdout,
                    active,
                    emit,
                    id,
                    chunk_mapper,
                    chunk_size,
                )
                stderr_task = @async _stream_process_pipe!(
                    stderr_pipe,
                    :stderr,
                    active,
                    emit,
                    id,
                    chunk_mapper,
                    chunk_size,
                )
                wait(process)
                fetch(stdout_task)
                fetch(stderr_task)
                active[] && emit(_invoke_process_exit_mapper(
                    exit_mapper,
                    id,
                    command,
                    process.exitcode,
                ))
            catch error
                process = process_ref[]
                process === nothing || _terminate_process!(process)
                if active[]
                    failure = RuntimeFailure(:subscription, id, error, catch_backtrace())
                    message = try
                        applicable(on_error, failure) || throw(ArgumentError(
                            "process subscription error callback must accept RuntimeFailure",
                        ))
                        on_error(failure)
                    catch callback_error
                        RuntimeFailure(
                            :subscription,
                            id,
                            callback_error,
                            catch_backtrace(),
                        )
                    end
                    isnothing(message) || emit(message)
                end
            finally
                isopen(stdout_pipe) && close(stdout_pipe)
                isopen(stderr_pipe) && close(stderr_pipe)
            end
        end
        () -> begin
            active[] = false
            process = process_ref[]
            process === nothing || _terminate_process!(process)
            nothing
        end
    end
    EventSubscription(id, register; revision)
end

"""An update that optionally replaces the model and controls redraw."""
struct UpdateResult{M,C<:AbstractCommand}
    model::M
    command::C
    redraw::Bool
end

UpdateResult(model; command::AbstractCommand=NoCommand(), redraw::Bool=true) =
    UpdateResult(model, command, redraw)

"""Result message emitted by a command with an explicit ID."""
struct CommandFinished{K,T}
    id::K
    value::T
end

"""Failure message emitted by runtime-managed work."""
struct RuntimeFailure{K,E}
    phase::Symbol
    id::K
    error::E
    backtrace::Any
end

struct _RuntimeExitRequested end

struct _SequenceContinuation
    commands::Vector{AbstractCommand}
    index::Int
    on_complete::Any
end

"""Managed runtime configuration."""
struct RuntimeConfig
    queue_capacity::Int
    maximum_frames_per_second::Float64
    redraw_on_message::Bool
    resize_poll_seconds::Union{Nothing,Float64}

    function RuntimeConfig(;
        queue_capacity::Integer=1024,
        maximum_frames_per_second::Real=60,
        redraw_on_message::Bool=true,
        resize_poll_seconds::Union{Nothing,Real}=0.1,
    )
        queue_capacity > 0 || throw(ArgumentError("queue capacity must be positive"))
        maximum_frames_per_second > 0 ||
            throw(ArgumentError("maximum frame rate must be positive"))
        resize_interval = isnothing(resize_poll_seconds) ? nothing : Float64(resize_poll_seconds)
        isnothing(resize_interval) ||
            (isfinite(resize_interval) && resize_interval > 0) ||
            throw(ArgumentError("resize poll interval must be finite and positive"))
        new(
            Int(queue_capacity),
            Float64(maximum_frames_per_second),
            redraw_on_message,
            resize_interval,
        )
    end
end

mutable struct CancellationToken
    cancelled::Bool
end

mutable struct ManagedTask
    task::Task
    token::CancellationToken
end

mutable struct _EventSubscriptionHandle
    active::Threads.Atomic{Bool}
    cleanup::Any
end

struct _ProcessCapture
    bytes::Vector{UInt8}
    error::Union{Nothing,Exception}
end

function _terminate_process!(process::Base.Process)
    process_exited(process) && return nothing
    try
        kill(process)
    catch
    end
    nothing
end

function _capture_process_stream(
    stream::Pipe,
    maximum_bytes::Int,
    name::Symbol,
    process::Base.Process,
)
    bytes = UInt8[]
    try
        while !eof(stream)
            first_byte = try
                read(stream, UInt8)
            catch error
                error isa EOFError && break
                rethrow()
            end
            length(bytes) < maximum_bytes || begin
                _terminate_process!(process)
                return _ProcessCapture(bytes, ProcessOutputLimitError(name, maximum_bytes))
            end
            push!(bytes, first_byte)
            available = readavailable(stream)
            if length(bytes) + length(available) > maximum_bytes
                remaining = maximum_bytes - length(bytes)
                remaining > 0 && append!(bytes, @view available[1:remaining])
                _terminate_process!(process)
                return _ProcessCapture(bytes, ProcessOutputLimitError(name, maximum_bytes))
            end
            append!(bytes, available)
        end
        _ProcessCapture(bytes, nothing)
    catch error
        _terminate_process!(process)
        _ProcessCapture(bytes, error)
    end
end

function _execute_process(command::ProcessCommand, token::CancellationToken)
    stdout_pipe = Pipe()
    stderr_pipe = Pipe()
    input = isnothing(command.input) ? devnull : IOBuffer(command.input)
    process = run(
        pipeline(
            ignorestatus(command.command),
            stdin=input,
            stdout=stdout_pipe,
            stderr=stderr_pipe,
        );
        wait=false,
    )
    close(stdout_pipe.in)
    close(stderr_pipe.in)
    stdout_task = @async _capture_process_stream(
        stdout_pipe,
        command.maximum_output_bytes,
        :stdout,
        process,
    )
    stderr_task = @async _capture_process_stream(
        stderr_pipe,
        command.maximum_output_bytes,
        :stderr,
        process,
    )
    try
        wait(process)
    catch error
        _terminate_process!(process)
        try
            wait(process)
        catch
        end
        rethrow(error)
    finally
        token.cancelled && _terminate_process!(process)
    end
    stdout_capture = fetch(stdout_task)
    stderr_capture = fetch(stderr_task)
    isnothing(stdout_capture.error) || throw(stdout_capture.error)
    isnothing(stderr_capture.error) || throw(stderr_capture.error)
    result = ProcessResult(
        command.command,
        process.exitcode,
        stdout_capture.bytes,
        stderr_capture.bytes,
    )
    command.check && !process_succeeded(result) && throw(ProcessExitError(result))
    result
end

"""Execute a process command synchronously outside the managed runtime."""
execute_process(command::ProcessCommand) =
    _execute_process(command, CancellationToken(false))

"""State and resources owned by one running application."""
mutable struct ApplicationRuntime{A<:WickedApp,M,T<:Terminal,S<:AbstractInputSource}
    app::A
    model::M
    terminal::T
    input_source::S
    config::RuntimeConfig
    messages::Channel{Any}
    commands::Dict{Any,ManagedTask}
    subscription_tasks::Dict{Any,Any}
    subscription_specs::Dict{Any,AbstractSubscription}
    input_task::Union{Nothing,Task}
    resize_task::Union{Nothing,Task}
    terminal_size::Size
    running::Bool
    suspended::Bool
    redraw::Bool
    result::Any
    last_view_state::Any
    last_frame_ns::UInt64
end

function ApplicationRuntime(
    app::A,
    model::M,
    terminal::T,
    input_source::S;
    config::RuntimeConfig=RuntimeConfig(),
) where {A<:WickedApp,M,T<:Terminal,S<:AbstractInputSource}
    runtime = ApplicationRuntime{A,M,T,S}(
        app,
        model,
        terminal,
        input_source,
        config,
        Channel{Any}(config.queue_capacity),
        Dict{Any,ManagedTask}(),
        Dict{Any,Any}(),
        Dict{Any,AbstractSubscription}(),
        nothing,
        nothing,
        backend_size(terminal.backend),
        false,
        false,
        true,
        nothing,
        nothing,
        UInt64(0),
    )
    attach_runtime!(app, model, runtime)
    return runtime
end

"""Leave interactive terminal modes before an external suspension action."""
function suspend!(runtime::ApplicationRuntime)
    runtime.running || return false
    runtime.suspended && return false
    leave!(runtime.terminal.backend)
    runtime.suspended = true
    true
end

"""Re-enter terminal modes after suspension and require a complete redraw."""
function resume!(runtime::ApplicationRuntime)
    runtime.suspended || return false
    enter!(runtime.terminal.backend)
    runtime.suspended = false
    runtime.last_view_state = nothing
    force_redraw!(runtime.terminal)
    runtime.redraw = true
    true
end

function _run_suspended(runtime::ApplicationRuntime, operation)
    suspend!(runtime) || throw(ArgumentError("runtime is not available for suspension"))
    value = try
        operation()
    catch error
        primary = CapturedException(error, catch_backtrace())
        try
            resume!(runtime)
        catch cleanup_error
            throw(TerminalSessionError(
                primary,
                CapturedException(cleanup_error, catch_backtrace()),
            ))
        end
        rethrow()
    end
    resume!(runtime)
    value
end

"""Poll backend dimensions once and enqueue a typed resize event when changed."""
function poll_terminal_resize!(runtime::ApplicationRuntime)
    current = backend_size(runtime.terminal.backend)
    current == runtime.terminal_size && return false
    runtime.terminal_size = current
    post!(runtime, ResizeEvent(current))
end

"""Post a message to the runtime queue."""
function post!(runtime::ApplicationRuntime, message)
    runtime.running || return false
    put!(runtime.messages, message)
    true
end

"""Request an orderly application exit."""
function request_exit!(runtime::ApplicationRuntime, result=nothing)
    runtime.result = result
    was_running = runtime.running
    runtime.running = false
    was_running && put!(runtime.messages, _RuntimeExitRequested())
    true
end

function _cancel_managed!(managed::ManagedTask)
    managed.token.cancelled = true
    nothing
end

function _deactivate_event_subscription!(handle::_EventSubscriptionHandle)
    handle.active[] || return nothing
    handle.active[] = false
    cleanup = handle.cleanup
    cleanup === nothing || cleanup()
    nothing
end

function _stop_subscription!(runtime::ApplicationRuntime, id; report_failure::Bool=true)
    handle = pop!(runtime.subscription_tasks, id, nothing)
    handle === nothing && return false
    try
        if handle isa ManagedTask
            _cancel_managed!(handle)
        elseif handle isa _EventSubscriptionHandle
            _deactivate_event_subscription!(handle)
        else
            throw(ArgumentError("unsupported subscription handle: $(typeof(handle))"))
        end
    catch error
        report_failure && runtime.running && post!(
            runtime,
            RuntimeFailure(:subscription_cleanup, id, error, catch_backtrace()),
        )
    end
    true
end

"""Cancel a command or subscription by ID."""
function cancel!(runtime::ApplicationRuntime, id)
    if haskey(runtime.commands, id)
        _cancel_managed!(pop!(runtime.commands, id))
        return true
    elseif haskey(runtime.subscription_tasks, id)
        return _stop_subscription!(runtime, id)
    end
    false
end

function _spawn!(operation::Function, runtime::ApplicationRuntime)
    token = CancellationToken(false)
    task = @async operation(token)
    ManagedTask(task, token)
end

function _invoke_command_work(work, token)
    applicable(work, token) ? work(token) : work()
end

function _retry_permitted(policy::RetryPolicy, error, attempt::Int)
    callback = policy.retry_if
    applicable(callback, error, attempt) && return Bool(callback(error, attempt))
    applicable(callback, error) && return Bool(callback(error))
    throw(ArgumentError("retry predicate must accept error/attempt or error"))
end

function _sleep_cancellable!(token::CancellationToken, seconds::Float64)
    deadline = time() + seconds
    while !token.cancelled
        remaining = deadline - time()
        remaining <= 0 && return true
        sleep(min(remaining, 0.01))
    end
    return false
end

function _invoke_retry_work(command::RetryCommand, token::CancellationToken)
    timeout = command.timeout_seconds
    timeout === nothing && return _invoke_command_work(command.work, token)
    attempt_token = CancellationToken(false)
    result = Channel{Any}(1)
    @async begin
        try
            put!(result, (:success, _invoke_command_work(command.work, attempt_token)))
        catch error
            put!(result, (:failure, error))
        end
    end
    deadline = time() + timeout
    while !isready(result)
        if token.cancelled
            attempt_token.cancelled = true
            throw(InterruptException())
        elseif time() >= deadline
            attempt_token.cancelled = true
            throw(CommandTimeoutError(timeout))
        end
        sleep(min(0.001, max(0.0, deadline - time())))
    end
    outcome = take!(result)
    outcome[1] === :success && return outcome[2]
    throw(outcome[2])
end

_execute!(runtime::ApplicationRuntime, ::NoCommand) = nothing
_execute!(runtime::ApplicationRuntime, command::MessageCommand) =
    post!(runtime, command.message)

function _execute!(runtime::ApplicationRuntime, command::DelayCommand)
    id = gensym(:delay)
    managed = _spawn!(runtime) do token
        try
            sleep(command.delay_seconds)
            token.cancelled || post!(runtime, command.message)
        finally
            pop!(runtime.commands, id, nothing)
        end
    end
    runtime.commands[id] = managed
    managed
end

function _execute!(runtime::ApplicationRuntime, command::TaskCommand)
    id = isnothing(command.id) ? gensym(:task) : command.id
    if haskey(runtime.commands, id)
        command.replace || return nothing
        _cancel_managed!(pop!(runtime.commands, id))
    end
    managed = _spawn!(runtime) do token
        try
            value = applicable(command.work, token) ? command.work(token) : command.work()
            if !token.cancelled
                message = command.on_success(value)
                wrapped = isnothing(command.id) ? message : CommandFinished(command.id, message)
                post!(runtime, wrapped)
            end
        catch error
            if !token.cancelled
                failure = RuntimeFailure(:command, command.id, error, catch_backtrace())
                post!(runtime, command.on_error(failure))
            end
        finally
            haskey(runtime.commands, id) && runtime.commands[id].token === token &&
                pop!(runtime.commands, id)
        end
    end
    runtime.commands[id] = managed
    managed
end

function _execute!(runtime::ApplicationRuntime, command::RetryCommand)
    id = isnothing(command.id) ? gensym(:retry) : command.id
    if haskey(runtime.commands, id)
        command.replace || return nothing
        _cancel_managed!(pop!(runtime.commands, id))
    end
    managed = _spawn!(runtime) do token
        attempt = 1
        try
            while !token.cancelled
                try
                    value = _invoke_retry_work(command, token)
                    token.cancelled && break
                    message = command.on_success(value)
                    wrapped = isnothing(command.id) ? message : CommandFinished(command.id, message)
                    isnothing(wrapped) || post!(runtime, wrapped)
                    break
                catch error
                    token.cancelled && break
                    retry = _retry_permitted(command.policy, error, attempt)
                    if retry && attempt < command.policy.maximum_attempts
                        _sleep_cancellable!(token, retry_delay(command.policy, attempt)) || break
                        attempt += 1
                        continue
                    end
                    final_error = retry && attempt >= command.policy.maximum_attempts ?
                                  RetryExhaustedError(attempt, error) : error
                    failure = RuntimeFailure(:command, command.id, final_error, catch_backtrace())
                    message = command.on_error(failure)
                    isnothing(message) || post!(runtime, message)
                    break
                end
            end
        finally
            haskey(runtime.commands, id) && runtime.commands[id].token === token &&
                pop!(runtime.commands, id)
        end
    end
    runtime.commands[id] = managed
    managed
end

function _execute!(runtime::ApplicationRuntime, command::ProcessCommand)
    id = isnothing(command.id) ? gensym(:process) : command.id
    if haskey(runtime.commands, id)
        command.replace || return nothing
        _cancel_managed!(pop!(runtime.commands, id))
    end
    managed = _spawn!(runtime) do token
        try
            result = _execute_process(command, token)
            if !token.cancelled
                message = command.on_success(result)
                wrapped = isnothing(command.id) ? message : CommandFinished(command.id, message)
                isnothing(wrapped) || post!(runtime, wrapped)
            end
        catch error
            if !token.cancelled
                failure = RuntimeFailure(:process, command.id, error, catch_backtrace())
                message = command.on_error(failure)
                isnothing(message) || post!(runtime, message)
            end
        finally
            haskey(runtime.commands, id) && runtime.commands[id].token === token &&
                pop!(runtime.commands, id)
        end
    end
    runtime.commands[id] = managed
    managed
end

function _execute!(runtime::ApplicationRuntime, command::TerminalCommand)
    message = try
        value = command.operation(runtime.terminal)
        resolved = command.on_success(value)
        isnothing(command.id) ? resolved : CommandFinished(command.id, resolved)
    catch error
        failure = RuntimeFailure(:terminal, command.id, error, catch_backtrace())
        command.on_error(failure)
    end
    isnothing(message) || post!(runtime, message)
    nothing
end

function _execute!(runtime::ApplicationRuntime, command::BatchCommand)
    for child in command.commands
        _execute!(runtime, child)
    end
    nothing
end

function _command_completed!(callback, lock, remaining::Base.RefValue{Int})
    finished = Base.lock(lock) do
        remaining[] -= 1
        remaining[] == 0
    end
    finished && callback()
    nothing
end

function _execute_with_completion!(callback, runtime::ApplicationRuntime, command::BatchCommand)
    isempty(command.commands) && return callback()
    completion_lock = ReentrantLock()
    remaining = Ref(length(command.commands))
    for child in command.commands
        _execute_with_completion!(runtime, child) do
            _command_completed!(callback, completion_lock, remaining)
        end
    end
    nothing
end

function _execute_with_completion!(callback, runtime::ApplicationRuntime, command::SequenceCommand)
    if isempty(command.commands)
        callback()
    else
        post!(runtime, _SequenceContinuation(command.commands, 1, callback))
    end
    nothing
end

function _execute_with_completion!(callback, runtime::ApplicationRuntime, command::AbstractCommand)
    result = _execute!(runtime, command)
    if result isa ManagedTask
        @async begin
            try
                wait(result.task)
            catch
            finally
                callback()
            end
        end
    else
        callback()
    end
    nothing
end

_execute_with_completion!(runtime::ApplicationRuntime, command::AbstractCommand, callback) =
    _execute_with_completion!(callback, runtime, command)

function _execute_sequence_step!(runtime::ApplicationRuntime, continuation::_SequenceContinuation)
    runtime.running || return nothing
    if continuation.index > length(continuation.commands)
        continuation.on_complete === nothing || continuation.on_complete()
        return nothing
    end
    child = continuation.commands[continuation.index]
    _execute_with_completion!(runtime, child) do
        post!(runtime, _SequenceContinuation(
            continuation.commands,
            continuation.index + 1,
            continuation.on_complete,
        ))
    end
    nothing
end

function _execute!(runtime::ApplicationRuntime, command::SequenceCommand)
    isempty(command.commands) || post!(runtime, _SequenceContinuation(command.commands, 1, nothing))
    nothing
end

_execute!(runtime::ApplicationRuntime, command::CancelCommand) = cancel!(runtime, command.id)
_execute!(runtime::ApplicationRuntime, command::ExitCommand) =
    request_exit!(runtime, command.result)
_execute!(runtime::ApplicationRuntime, ::FrameCommand) = (runtime.redraw = true)

function _execute!(runtime::ApplicationRuntime, command::SuspendCommand)
    message = try
        value = _run_suspended(runtime, command.operation)
        resolved = command.on_success(value)
        isnothing(command.id) ? resolved : CommandFinished(command.id, resolved)
    catch error
        failure = RuntimeFailure(:suspend, command.id, error, catch_backtrace())
        command.on_error(failure)
    end
    isnothing(message) || post!(runtime, message)
    nothing
end

function _subscription_map(app::WickedApp, model)
    result = Dict{Any,AbstractSubscription}()
    for subscription in subscriptions(app, model)
        haskey(result, subscription.id) &&
            throw(ArgumentError("duplicate subscription ID: $(subscription.id)"))
        result[subscription.id] = subscription
    end
    result
end

function _start_subscription!(runtime::ApplicationRuntime, subscription::IntervalSubscription)
    id = subscription.id
    runtime.subscription_tasks[id] = _spawn!(runtime) do token
        try
            while !token.cancelled && runtime.running
                sleep(subscription.interval_seconds)
                token.cancelled && break
                message = subscription.message isa Function ? subscription.message() : subscription.message
                post!(runtime, message)
            end
        catch error
            !token.cancelled && runtime.running && post!(
                runtime,
                RuntimeFailure(:subscription, id, error, catch_backtrace()),
            )
        end
    end
    runtime.subscription_specs[id] = subscription
end

function _start_subscription!(runtime::ApplicationRuntime, subscription::EventSubscription)
    id = subscription.id
    active = Threads.Atomic{Bool}(true)
    handle = _EventSubscriptionHandle(active, nothing)
    runtime.subscription_tasks[id] = handle
    runtime.subscription_specs[id] = subscription
    emit = message -> active[] && runtime.running && post!(runtime, message)
    try
        cleanup = subscription.register(emit)
        (cleanup === nothing || applicable(cleanup)) ||
            throw(ArgumentError("event subscription cleanup must accept no arguments or be nothing"))
        handle.cleanup = cleanup
    catch error
        active[] = false
        runtime.running && post!(
            runtime,
            RuntimeFailure(:subscription_registration, id, error, catch_backtrace()),
        )
    end
    handle
end

function _same_subscription(
    current::IntervalSubscription,
    desired::IntervalSubscription,
)
    current.interval_seconds == desired.interval_seconds &&
        isequal(current.message, desired.message)
end


function _same_subscription(current::EventSubscription, desired::EventSubscription)
    if current.revision !== nothing || desired.revision !== nothing
        return isequal(current.revision, desired.revision)
    end
    isequal(current.register, desired.register)
end

_same_subscription(current::AbstractSubscription, desired::AbstractSubscription) =
    typeof(current) === typeof(desired) && isequal(current, desired)

function _sync_subscriptions!(runtime::ApplicationRuntime)
    desired = _subscription_map(runtime.app, runtime.model)
    for id in setdiff(Set(keys(runtime.subscription_tasks)), Set(keys(desired)))
        _stop_subscription!(runtime, id)
        pop!(runtime.subscription_specs, id, nothing)
    end
    for (id, subscription) in desired
        subscription isa Union{IntervalSubscription,EventSubscription} ||
            throw(ArgumentError("unsupported subscription type: $(typeof(subscription))"))
        if haskey(runtime.subscription_tasks, id)
            current = runtime.subscription_specs[id]
            _same_subscription(current, subscription) && continue
            _stop_subscription!(runtime, id)
            pop!(runtime.subscription_specs, id, nothing)
        end
        _start_subscription!(runtime, subscription)
    end
    nothing
end

function _apply_update!(runtime::ApplicationRuntime, message)
    message isa ResizeEvent && (runtime.terminal_size = message.size)
    result = update!(runtime.app, runtime.model, message)
    if result isa UpdateResult
        runtime.model = result.model
        runtime.redraw |= result.redraw
        _execute!(runtime, result.command)
    elseif result isa AbstractCommand
        runtime.redraw |= runtime.config.redraw_on_message
        _execute!(runtime, result)
    elseif isnothing(result)
        runtime.redraw |= runtime.config.redraw_on_message
    else
        throw(ArgumentError("update! must return nothing, AbstractCommand, or UpdateResult"))
    end
    attach_runtime!(runtime.app, runtime.model, runtime)
    nothing
end

function _start_resize_watcher!(runtime::ApplicationRuntime)
    interval = runtime.config.resize_poll_seconds
    isnothing(interval) && return nothing
    runtime.resize_task = @async begin
        while runtime.running
            sleep(interval)
            runtime.running || break
            try
                poll_terminal_resize!(runtime)
            catch error
                runtime.running && post!(
                    runtime,
                    RuntimeFailure(:resize, nothing, error, catch_backtrace()),
                )
                break
            end
        end
    end
    nothing
end

function _draw_runtime!(runtime::ApplicationRuntime)
    minimum_interval = round(UInt64, 1_000_000_000 / runtime.config.maximum_frames_per_second)
    if runtime.last_frame_ns != 0
        elapsed = UInt64(time_ns()) - runtime.last_frame_ns
        elapsed < minimum_interval && sleep((minimum_interval - elapsed) / 1_000_000_000)
    end
    view = _application_view(app_view(runtime.app, runtime.model))
    view_state = (title=view.title, modes=view.modes)
    previous = runtime.last_view_state
    if view.title !== nothing &&
       (previous === nothing || !isequal(previous.title, view.title))
        set_terminal_title!(runtime.terminal, view.title)
    end
    if previous === nothing || !isequal(previous.modes, view.modes)
        changed = apply_terminal_modes!(runtime.terminal.backend, view.modes)
        changed && force_redraw!(runtime.terminal)
    end
    runtime.last_view_state = view_state
    draw!(runtime.terminal) do frame
        render_application!(frame, view)
    end
    runtime.last_frame_ns = UInt64(time_ns())
    runtime.redraw = false
    nothing
end

function _start_input!(runtime::ApplicationRuntime)
    runtime.input_task = @async begin
        while runtime.running
            try
                post!(runtime, read_event!(runtime.input_source))
            catch error
                runtime.running && post!(
                    runtime,
                    RuntimeFailure(:input, nothing, error, catch_backtrace()),
                )
                break
            end
        end
    end
end

function _shutdown!(runtime::ApplicationRuntime)
    runtime.running = false
    runtime.suspended = false
    managed_tasks = ManagedTask[
        values(runtime.commands)...,
        (handle for handle in values(runtime.subscription_tasks) if handle isa ManagedTask)...,
    ]
    for managed in managed_tasks
        _cancel_managed!(managed)
    end
    for id in collect(keys(runtime.subscription_tasks))
        _stop_subscription!(runtime, id; report_failure=false)
    end
    empty!(runtime.commands)
    empty!(runtime.subscription_tasks)
    empty!(runtime.subscription_specs)
    if !isnothing(runtime.input_task) && !istaskdone(runtime.input_task)
        close_input!(runtime.input_source)
        try
            wait(runtime.input_task)
        catch
        end
    end
    if !isnothing(runtime.resize_task) && !istaskdone(runtime.resize_task)
        try
            wait(runtime.resize_task)
        catch
        end
    end
    for managed in managed_tasks
        istaskdone(managed.task) && continue
        try
            wait(managed.task)
        catch
        end
    end
    nothing
end

"""Run a configured application runtime until it requests exit."""
function run!(runtime::ApplicationRuntime)
    runtime.running && throw(ArgumentError("application runtime is already running"))
    runtime.running = true
    try
        with_terminal(runtime.terminal) do _
            _start_input!(runtime)
            _start_resize_watcher!(runtime)
            _sync_subscriptions!(runtime)
            _draw_runtime!(runtime)
            while runtime.running
                message = take!(runtime.messages)
                message isa _RuntimeExitRequested && break
                if message isa _SequenceContinuation
                    _execute_sequence_step!(runtime, message)
                    continue
                end
                _apply_update!(runtime, message)
                runtime.running || break
                _sync_subscriptions!(runtime)
                runtime.redraw && _draw_runtime!(runtime)
            end
        end
        runtime.result
    finally
        _shutdown!(runtime)
    end
end

"""Initialize and run a Wicked application with default terminal resources."""
function run(
    app::A;
    terminal::T=Terminal(AnsiBackend()),
    input_source=nothing,
    config::RuntimeConfig=RuntimeConfig(),
) where {A<:WickedApp,T<:Terminal}
    model = initialize(app)
    source = if isnothing(input_source)
        terminal.backend isa AnsiBackend ?
            ParserInputSource(terminal.backend.input) : ChannelInputSource()
    else
        input_source
    end
    source isa AbstractInputSource ||
        throw(ArgumentError("input_source must implement AbstractInputSource"))
    runtime = ApplicationRuntime(app, model, terminal, source; config)
    run!(runtime)
end

"""Run an existing application runtime in a composable Julia task."""
run_async(runtime::ApplicationRuntime) = @async run!(runtime)

"""Initialize and run an application in a composable Julia task."""
run_async(app::WickedApp; kwargs...) = @async run(app; kwargs...)

export AbstractCommand,
       AbstractSubscription,
       ApplicationRuntime,
       ApplicationView,
       BatchCommand,
       channel_subscription,
       file_subscription,
       process_subscription,
       CancelCommand,
       CommandTimeoutError,
       CommandFinished,
       DelayCommand,
       EventSubscription,
       ExitCommand,
       FileWatchEvent,
       FrameCommand,
       IntervalSubscription,
       MessageCommand,
       NoCommand,
       ProcessCommand,
       ProcessExitError,
       ProcessOutputLimitError,
       ProcessResult,
       ProcessStreamChunk,
       ProcessStreamExit,
       RuntimeConfig,
       RuntimeFailure,
       RetryCommand,
       RetryExhaustedError,
       RetryPolicy,
       SequenceCommand,
       TaskCommand,
       TerminalCommand,
       SuspendCommand,
       UpdateResult,
       WickedApp,
       app_view,
       cancel!,
       initialize,
       map_command,
       retry_command,
       retry_delay,
       execute_process,
       post!,
       process_succeeded,
       poll_terminal_resize!,
       render_application!,
       request_exit!,
       resume!,
       run,
       run!,
       run_async,
       suspend!,
       subscriptions,
       update!

end
