module Testing

using Unicode
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

"""Assert a stable plain-text buffer snapshot."""
function assert_plain_snapshot(source, expected::AbstractString)
    actual = plain_snapshot(source)
    actual == expected || throw(BufferAssertionError(
        "plain snapshot mismatch:\nexpected: $(repr(String(expected)))\nactual:   $(repr(actual))",
    ))
    source
end

"""Assert a stable ANSI buffer snapshot."""
function assert_ansi_snapshot(source, expected::AbstractString; kwargs...)
    actual = ansi_snapshot(source; kwargs...)
    actual == expected || throw(BufferAssertionError(
        "ANSI snapshot mismatch:\nexpected: $(repr(String(expected)))\nactual:   $(repr(actual))",
    ))
    source
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

function key!(
    pilot::WidgetPilot,
    key::Symbol;
    text::AbstractString="",
    modifiers::KeyModifiers=NONE,
    kind=KeyPress,
)
    send!(pilot, KeyEvent(Key(key); text, modifiers, kind))
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
       ToolkitPilot,
       VirtualClock,
       WidgetPilot,
       WidgetPilotResult,
       advance_time!,
       ansi_snapshot,
       assert_ansi_snapshot,
       assert_cell,
       assert_plain_snapshot,
       cancel_scheduled!,
       click!,
       draw!,
       focus_element!,
       hover!,
       key!,
       mouse!,
       paste!,
       plain_snapshot,
       query,
       query_one,
       request_exit!,
       resize_terminal!,
       pending_scheduled,
       schedule_after!,
       send!,
       structured_snapshot,
       svg_snapshot,
       take_messages!,
       type_text!
       virtual_time_ns

end
