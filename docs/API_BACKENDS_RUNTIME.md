# Backends and Runtime API

Terminal backends, remote frame transport, managed runtime behavior, clipboard
providers, OSC52 helpers, clipboard commands, and editor copy/cut/paste helpers
are available through the stable `Wicked.API` facade.

This page contains generated reference documentation for terminal backends, core
integration, reliability, remote transport, managed runtime behavior, and
clipboard boundaries.

## Stable remote transport

`RemoteBackend` and `RemoteSession` provide the stable low-level contract for
remote Wicked surfaces. The protocol is transport agnostic: embedders can carry
encoded packets over a WebSocket, Linux domain socket, process pipe, test
harness, or custom binary channel.

The stable transport layer includes:

- `RemoteHello` for negotiated viewport and terminal capability metadata.
- `RemoteFrame` for ordered full-frame and delta-frame updates.
- `RemoteEvent` for typed client input.
- `RemoteAck` for sequence acknowledgement.
- `RemoteProtocolLimits` for bounded packet, buffer, cell, and string sizes.
- `RemoteDecoder`, `feed_remote!`, and `decode_remote_packet` for fragmented or
  combined transport bytes.
- `ingest_remote!` for ordered event delivery into a bounded input source.

The reference browser client lives under `assets/remote`, and HTTP.jl WebSocket
integration is provided by the `WickedHTTPWebSocketsExt` package extension. The
core package still does not own HTTP routing, static asset serving,
authentication, origin checks, TLS, connection limits, or deployment policy;
those remain responsibilities of the hosting application.

### Remote transport quickstart

Use `RemoteBackend` when the server owns rendering and a transport adapter owns
delivery of binary packets:

```julia
using Wicked.API

packets = Vector{Vector{UInt8}}()
limits = RemoteProtocolLimits(maximum_packet_bytes=1_000_000)
backend = RemoteBackend(
    packet -> push!(packets, copy(packet));
    size=Size(3, 20),
    capabilities=TerminalCapabilities(color_level=:truecolor),
    limits,
)
terminal = Terminal(backend)

enter!(backend)
@assert decode_remote_packet(packets[1]; limits) isa RemoteHello

draw!(terminal) do frame
    render!(frame, Label("remote ready"), frame.area)
end

frame = decode_remote_packet(packets[end]; limits)
@assert frame isa RemoteFrame
@assert frame.full
```

Use `RemoteSession` when the same transport also receives typed client input.
`ingest_remote!` accepts fragmented or complete packets, enforces event ordering,
updates the backend size for resize events, and queues typed events into the
session input source:

```julia
session = RemoteSession(
    packet -> push!(packets, copy(packet));
    size=Size(3, 20),
    limits,
    input_capacity=16,
)

bytes = encode_remote_message(RemoteEvent(UInt64(0), KeyEvent(Key(:enter))); limits)
ingest_remote!(session, bytes)
@assert read_event!(session.input) == KeyEvent(Key(:enter))
```

See [Remote Frame Transport](REMOTE_TRANSPORT.md) for protocol lifecycle,
fragmented decoding, browser-adapter security guidance, and HTTP.jl WebSocket
extension notes.

For Textual-style browser hosting, keep the stable boundary split in two:
`Wicked.API` owns the binary protocol, frame backend, event session, decoder,
limits, and extension hooks; the application or deployment layer owns HTTP
routing, static asset serving, authentication, origin policy, TLS, and rate
limits. Loading HTTP.jl activates `WickedHTTPWebSocketsExt`, which provides
`websocket_session` and `pump_websocket!` methods for `HTTP.WebSockets` without
making HTTP part of ordinary package loading or terminal startup.

## Stable runtime entry points

Use `run(app)` for ordinary managed applications and `run!(runtime)` when tests,
embedders, or advanced integrations need to construct `ApplicationRuntime`
explicitly. `run_async` starts the same lifecycle in a Julia task.

`UpdateResult` is the stable way for `update!` to replace the model, return a
command, and control redraw from one value. `subscriptions(app, model)` is the
stable extension point for ongoing model-derived event sources.

## Stable managed-runtime quickstart

Managed applications implement three public hooks: `initialize`, `app_view`, and
`update!`. The model is ordinary Julia data, the view is any renderable widget or
Toolkit tree, and `update!` mutates the model or returns commands for work that
must happen outside the render pass:

```julia
using Wicked.API
import Wicked.API: app_view, initialize, update!

mutable struct CounterModel
    count::Int
    loading::Bool
end

struct CounterApp <: WickedApp end

initialize(::CounterApp) = CounterModel(0, false)

app_view(::CounterApp, model::CounterModel) = Panel(
    Paragraph("count=$(model.count)\nloading=$(model.loading)");
    title="Counter",
)

function update!(::CounterApp, model::CounterModel, message)
    if message === :increment
        model.count += 1
        return FrameCommand()
    elseif message === :refresh
        model.loading = true
        return TaskCommand(
            () -> 41;
            id=:refresh,
            replace=true,
            on_success=value -> (:loaded, value),
            on_error=error -> (:failed, error),
        )
    elseif message isa Tuple && first(message) === :loaded
        model.loading = false
        model.count = last(message)
        return BatchCommand(
            FrameCommand(),
            DelayCommand(0.25, :increment),
            MessageCommand(:record_activity),
        )
    elseif message === :quit
        return ExitCommand(model.count)
    end
    return NoCommand()
end

run(CounterApp())
```

Use `FrameCommand` when the model changed and a redraw is enough,
`MessageCommand` when another update message should be queued, `DelayCommand`
for deterministic delayed messages, `TaskCommand` for finite Julia work,
`BatchCommand` to start several commands from one update, and `ExitCommand` to
stop the application with a result.

For tests, drive the same application with `RuntimePilot` instead of `run`:

```julia
pilot = RuntimePilot(CounterApp(); height=8, width=32)
send!(pilot, :increment)
@assert occursin("count=1", plain_snapshot(pilot))
```

## Stable runtime helpers

`execute_process(ProcessCommand(...))` runs the same bounded subprocess capture
used by managed process commands without entering the application loop. Use it for
tooling, tests, or setup steps that need Wicked's `ProcessResult`,
`ProcessExitError`, and `ProcessOutputLimitError` behavior.

`suspend!(runtime)` and `resume!(runtime)` expose the terminal-mode transition
used by `SuspendCommand`. They are intended for embedders and controlled runtime
integrations; ordinary applications should prefer returning `SuspendCommand` from
`update!`.

`poll_terminal_resize!(runtime)` performs one deterministic backend size check
and queues a `ResizeEvent` only when dimensions changed. It is useful for custom
event loops and tests that disable the background resize watcher.

```@autodocs
Modules = [
    Wicked.Backends,
    Wicked.CoreIntegration,
    Wicked.Reliability,
    Wicked.RemoteTransport,
    Wicked.Runtime,
    Wicked.Clipboard,
]
Private = false
```
