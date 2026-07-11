module Runtime

import Base: run
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

"""Return the immediate-mode widget tree for an application model."""
function app_view end

"""Return the current set of ongoing application subscriptions."""
subscriptions(::WickedApp, model) = ()

"""Render an application model into a frame."""
function render_application!(frame::Frame, app::WickedApp, model)
    widget = app_view(app, model)
    render!(frame, widget, frame.area)
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

struct BatchCommand <: AbstractCommand
    commands::Vector{AbstractCommand}
end

BatchCommand(commands::AbstractVector{<:AbstractCommand}) =
    BatchCommand(AbstractCommand[commands...])
BatchCommand(commands::AbstractCommand...) = BatchCommand(AbstractCommand[commands...])

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
    subscription_tasks::Dict{Any,ManagedTask}
    subscription_specs::Dict{Any,AbstractSubscription}
    input_task::Union{Nothing,Task}
    resize_task::Union{Nothing,Task}
    terminal_size::Size
    running::Bool
    suspended::Bool
    redraw::Bool
    result::Any
    last_frame_ns::UInt64
end

function ApplicationRuntime(
    app::A,
    model::M,
    terminal::T,
    input_source::S;
    config::RuntimeConfig=RuntimeConfig(),
) where {A<:WickedApp,M,T<:Terminal,S<:AbstractInputSource}
    ApplicationRuntime{A,M,T,S}(
        app,
        model,
        terminal,
        input_source,
        config,
        Channel{Any}(config.queue_capacity),
        Dict{Any,ManagedTask}(),
        Dict{Any,ManagedTask}(),
        Dict{Any,AbstractSubscription}(),
        nothing,
        nothing,
        backend_size(terminal.backend),
        false,
        false,
        true,
        nothing,
        UInt64(0),
    )
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
    runtime.running = false
    true
end

function _cancel_managed!(managed::ManagedTask)
    managed.token.cancelled = true
    if !istaskdone(managed.task)
        try
            schedule(managed.task, InterruptException(); error=true)
        catch
        end
    end
    nothing
end

"""Cancel a command or subscription by ID."""
function cancel!(runtime::ApplicationRuntime, id)
    if haskey(runtime.commands, id)
        _cancel_managed!(pop!(runtime.commands, id))
        return true
    elseif haskey(runtime.subscription_tasks, id)
        _cancel_managed!(pop!(runtime.subscription_tasks, id))
        return true
    end
    false
end

function _spawn!(operation::Function, runtime::ApplicationRuntime)
    token = CancellationToken(false)
    task = @async operation(token)
    ManagedTask(task, token)
end

_execute!(runtime::ApplicationRuntime, ::NoCommand) = nothing
_execute!(runtime::ApplicationRuntime, command::MessageCommand) =
    post!(runtime, command.message)

function _execute!(runtime::ApplicationRuntime, command::DelayCommand)
    id = gensym(:delay)
    runtime.commands[id] = _spawn!(runtime) do token
        try
            sleep(command.delay_seconds)
            token.cancelled || post!(runtime, command.message)
        finally
            pop!(runtime.commands, id, nothing)
        end
    end
    nothing
end

function _execute!(runtime::ApplicationRuntime, command::TaskCommand)
    id = isnothing(command.id) ? gensym(:task) : command.id
    if haskey(runtime.commands, id)
        command.replace || return nothing
        _cancel_managed!(pop!(runtime.commands, id))
    end
    runtime.commands[id] = _spawn!(runtime) do token
        try
            value = command.work()
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
    nothing
end

function _execute!(runtime::ApplicationRuntime, command::ProcessCommand)
    id = isnothing(command.id) ? gensym(:process) : command.id
    if haskey(runtime.commands, id)
        command.replace || return nothing
        _cancel_managed!(pop!(runtime.commands, id))
    end
    runtime.commands[id] = _spawn!(runtime) do token
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
    nothing
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

function _same_subscription(
    current::IntervalSubscription,
    desired::IntervalSubscription,
)
    current.interval_seconds == desired.interval_seconds &&
        isequal(current.message, desired.message)
end

_same_subscription(current::AbstractSubscription, desired::AbstractSubscription) =
    typeof(current) === typeof(desired) && isequal(current, desired)

function _sync_subscriptions!(runtime::ApplicationRuntime)
    desired = _subscription_map(runtime.app, runtime.model)
    for id in setdiff(Set(keys(runtime.subscription_tasks)), Set(keys(desired)))
        _cancel_managed!(pop!(runtime.subscription_tasks, id))
        pop!(runtime.subscription_specs, id, nothing)
    end
    for (id, subscription) in desired
        subscription isa IntervalSubscription ||
            throw(ArgumentError("unsupported subscription type: $(typeof(subscription))"))
        if haskey(runtime.subscription_tasks, id)
            current = runtime.subscription_specs[id]
            _same_subscription(current, subscription) && continue
            _cancel_managed!(pop!(runtime.subscription_tasks, id))
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
    draw!(runtime.terminal) do frame
        render_application!(frame, runtime.app, runtime.model)
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
    for managed in values(runtime.commands)
        _cancel_managed!(managed)
    end
    for managed in values(runtime.subscription_tasks)
        _cancel_managed!(managed)
    end
    empty!(runtime.commands)
    empty!(runtime.subscription_tasks)
    empty!(runtime.subscription_specs)
    if !isnothing(runtime.input_task) && !istaskdone(runtime.input_task)
        try
            schedule(runtime.input_task, InterruptException(); error=true)
        catch
        end
    end
    if !isnothing(runtime.resize_task) && !istaskdone(runtime.resize_task)
        try
            schedule(runtime.resize_task, InterruptException(); error=true)
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
       BatchCommand,
       CancelCommand,
       CommandFinished,
       DelayCommand,
       ExitCommand,
       FrameCommand,
       IntervalSubscription,
       MessageCommand,
       NoCommand,
       ProcessCommand,
       ProcessExitError,
       ProcessOutputLimitError,
       ProcessResult,
       RuntimeConfig,
       RuntimeFailure,
       TaskCommand,
       TerminalCommand,
       SuspendCommand,
       UpdateResult,
       WickedApp,
       app_view,
       cancel!,
       initialize,
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
