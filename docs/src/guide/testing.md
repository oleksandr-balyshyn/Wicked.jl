# Testing

Because every widget renders into a `Buffer`, Wicked apps are **fast and
deterministic to test — no real terminal required**. Wicked ships pilots,
snapshots, semantic queries, and virtual time.

## Snapshots

Render, then compare the plain text:

```julia
using Wicked.API

buffer = Buffer(1, 8)
render!(Frame(buffer), Label("Wicked"), buffer.area)

@assert occursin("Wicked", plain_snapshot(buffer))
assert_plain_snapshot(buffer, "Wicked")
```

`plain_snapshot` strips styling and returns the on-screen text (rows joined by
newlines), so assertions are easy to read and stable.

## Pilots

A pilot wraps a headless backend and drives your UI:

| Pilot | Drives |
| --- | --- |
| `RuntimePilot` | A managed [runtime](runtime.md) app. |
| `ToolkitPilot` | A declarative [Toolkit](toolkit.md) tree. |
| `WidgetPilot` | A single immediate-mode widget. |

```julia
pilot = RuntimePilot(CounterApp(); height=3, width=24)

send!(pilot, :increment)                       # deliver a message
@assert occursin("count = 1", plain_snapshot(pilot))
```

Toolkit pilots add input and query helpers:

```julia
pilot = ToolkitPilot(view("ready"); height=5, width=32)
focus_element!(pilot, :deploy)
key!(pilot, :enter)
button = query_one(pilot; id=:deploy, widget_type=Button, focused=true)
```

## Virtual time

Timers and subscriptions fire on a virtual clock, so tests never sleep and never
flake:

```julia
send!(pilot, :tick)             # schedules a DelayCommand
advance_time!(pilot, 0.25)      # deterministically fires it
@assert occursin("count = 2", plain_snapshot(pilot))
```

## Semantics

Project an accessibility/testing tree and assert against roles and structure:

```julia
semantics = toolkit_semantic_tree(pilot.tree; label="Deployment")
@assert isempty(filter(d -> d.severity == :error, validate_semantics(semantics)))
@assert occursin("deploy:ButtonRole", semantic_snapshot(semantics))
```

See [`examples/testing_quickstart.jl`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/examples/testing_quickstart.jl).
