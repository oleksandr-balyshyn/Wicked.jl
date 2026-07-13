# Async Commands, Subscriptions, and Cancellation

The managed runtime is a model/update/view loop. `update!` is the only owner of model mutation. Commands perform finite work and return messages; subscriptions describe ongoing sources derived from current model state.

## Command types

| Command | Purpose |
| --- | --- |
| `NoCommand` | Perform no effect |
| `MessageCommand` | Queue another message |
| `FrameCommand` | Request a redraw |
| `DelayCommand` | Queue a message after a finite delay |
| `TaskCommand` | Run a Julia callback as managed background work |
| `ProcessCommand` | Run a subprocess with cancellation and bounded output capture |
| `TerminalCommand` | Execute a finite terminal operation on the UI task |
| `SuspendCommand` | Temporarily leave terminal modes around an OS operation |
| `BatchCommand` | Start multiple commands from one update |
| `CancelCommand` | Cancel a command or subscription by ID |
| `ExitCommand` | Stop the application and return a result |

## Start finite background work

```julia
struct LoadRequested end
struct Loaded
    value::String
end

function update!(app::MyApp, model, message)
    if message isa LoadRequested
        return TaskCommand(
            () -> read("data.txt", String);
            id=:load,
            replace=true,
            on_success=value -> Loaded(value),
            on_error=identity,
        )
    elseif message isa CommandFinished && message.id == :load
        model.value = message.value.value
        return FrameCommand()
    elseif message isa RuntimeFailure
        model.error = sprint(showerror, message.error)
        return FrameCommand()
    end
    return NoCommand()
end
```

An explicit command ID wraps successful output in `CommandFinished(id, value)`. `replace=true` cancels existing work with the same ID before starting the replacement. Without replacement, a duplicate active ID is ignored.

`TaskCommand` work should use `try`/`finally` for resources. Cancellation interrupts the managed Julia task and suppresses late success/error messages.

## Cancel explicitly

Return `CancelCommand(:load)` from an update to cancel the active command with that ID. Cancellation is idempotent from the application’s perspective; no completion message is delivered after the runtime accepts cancellation.

Do not mutate `model` inside `work`. Background callbacks run outside the update loop and may be interrupted.

## Run subprocesses safely

```julia
command = ProcessCommand(
    `git status --short`;
    id=:status,
    check=true,
    maximum_output_bytes=256 * 1024,
    on_success=result -> String(result.stdout),
    on_error=identity,
    replace=true,
)
```

Both standard output and standard error are bounded. `check=true` converts a nonzero exit into `ProcessExitError`; exceeding the bound produces `ProcessOutputLimitError`. Cancellation terminates the managed process and suppresses stale output.

Use `execute_process(ProcessCommand(...))` when the same bounded capture behavior
is needed outside a running application. This helper is stable for command-line
tooling, setup probes, and tests that should not enter terminal modes.

## Batch independent effects

```julia
return BatchCommand(
    FrameCommand(),
    DelayCommand(0.25, :refresh_preview),
    MessageCommand(:record_activity),
)
```

Batching starts commands in order but does not make their asynchronous completion order deterministic. Encode causal dependencies as messages instead of assuming completion order.

## Declare ongoing subscriptions

```julia
function subscriptions(::MyApp, model)
    model.polling || return ()
    return (
        IntervalSubscription(:poll, model.poll_seconds, :poll_tick),
    )
end
```

The runtime synchronizes subscriptions after model updates:

- Removing an ID cancels its task.
- Changing the interval or message for an existing ID replaces it.
- Duplicate IDs are rejected.
- Callback failures arrive as `RuntimeFailure(:subscription, id, error, backtrace)`.

Subscriptions must describe current state, not mutate it. Return a message value or a zero-argument function that creates one.

## Test time deterministically

`RuntimePilot` uses the stable `VirtualClock` scheduler for delays and interval subscriptions:

```julia
pilot = RuntimePilot(MyApp(); height=5, width=40)

send!(pilot, :start_polling)
advance_time!(pilot, 5.0)

@assert pilot.model.poll_count == 1
```

No wall-clock sleep is required. Pilot execution also bounds processed messages so a self-posting command loop fails clearly instead of hanging the test process.

## Drive low-level runtime transitions

Most applications should express terminal suspension as `SuspendCommand` and let
the runtime call `suspend!` and `resume!`. Embedders and deterministic tests may
call these helpers directly on an `ApplicationRuntime` when they own the runtime
lifecycle.

Use `poll_terminal_resize!` for one explicit resize check when the background
watcher is disabled or when an external loop owns timing. It posts a `ResizeEvent`
only when the backend size changes.

## Choose the correct boundary

- Use `TaskCommand` for finite Julia work.
- Use `ProcessCommand` for explicit operating-system processes.
- Use `IntervalSubscription` for state-dependent recurring input.
- Use paged data sources for cancellable virtualized loading.
- Use application services for notifications, progress, animations, and live reload.
- Use `TerminalCommand` only for short terminal operations that must run on the UI task.
