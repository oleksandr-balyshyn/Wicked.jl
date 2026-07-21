# Managed Runtime

The managed runtime is Wicked's **Elm-style application model**. Your app owns a
model; `update!` changes it and returns a command; `app_view` renders it. The
runtime owns the loop, timers, async work, and cleanup — one observable
lifecycle.

## Define an app

```julia
using Wicked.API
import Wicked.API: app_view, initialize, update!

mutable struct CounterModel
    count::Int
end

struct CounterApp <: WickedApp end

initialize(::CounterApp) = CounterModel(0)

app_view(::CounterApp, m::CounterModel) =
    Panel(Paragraph("count = $(m.count)"); block=Block(title="Counter"))

function update!(::CounterApp, m::CounterModel, msg)
    msg === :increment && (m.count += 1; return FrameCommand())
    msg === :tick      && return DelayCommand(0.25, :increment)
    msg === :quit      && return ExitCommand(m.count)
    return NoCommand()
end
```

You implement three methods on your app type:

- `initialize(app)` → the initial model.
- `app_view(app, model)` → a widget (or Toolkit element) to render.
- `update!(app, model, message)` → mutate the model, return a **command**.

## Commands

Commands are the runtime's vocabulary for effects. `update!` returns one:

| Command | Effect |
| --- | --- |
| `NoCommand()` | Do nothing. |
| `FrameCommand()` | Request a redraw. |
| `MessageCommand(msg)` | Deliver another message now. |
| `DelayCommand(seconds, msg)` | Deliver `msg` after a delay (a timer). |
| `BatchCommand(cmds...)` | Run several commands. |
| `ExitCommand(result)` | Stop the app and return `result`. |

This mirrors Bubble Tea's `Cmd`/`Batch`/`Tick` and Elm's command model.

## Drive it headlessly

You do not need a real terminal to run — or test — an app. A `RuntimePilot`
plus virtual time gives you full control:

```julia
pilot = RuntimePilot(CounterApp(); height=3, width=24)
@assert occursin("count = 0", plain_snapshot(pilot))

send!(pilot, :increment)
@assert occursin("count = 1", plain_snapshot(pilot))

send!(pilot, :tick)
advance_time!(pilot, 0.25)                 # fast-forward the timer
@assert occursin("count = 2", plain_snapshot(pilot))

result = send!(pilot, :quit)
@assert result.exited
```

`advance_time!` deterministically fires timers and subscriptions — no sleeping,
no flakiness. See [Testing](testing.md) for more.

The full runnable version is in
[`examples/runtime_quickstart.jl`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/examples/runtime_quickstart.jl).
