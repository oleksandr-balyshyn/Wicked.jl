# Event Tracing and Replay

Event traces capture input, messages, commands, timers, resizes, checkpoints, and
application-specific events in one monotonic sequence. They support reproducible
bug reports and deterministic regression scenarios beyond a final screen snapshot.

## Record a session

```julia
recorder = EventRecorder(
    capacity=20_000,
    snapshot=deepcopy,
    metadata=Dict(:terminal => "xterm-256color"),
)

record_trace!(recorder, :input, event; source=:terminal)
record_trace!(recorder, :message, message; correlation=request_id)
record_checkpoint!(recorder, :after_login, model)

trace = seal_trace!(recorder)
```

The recorder uses a bounded ring buffer. `DropOldestTrace` is the default overflow
policy; `StopTraceRecording` preserves the first entries, and `FailTraceRecording`
reports overflow through the recorder error channel.

Payload snapshotting is configurable. `identity` avoids allocations but requires
the caller not to mutate recorded payloads. Use `deepcopy` or a domain-specific
redactor to produce durable, secret-free values. Sealed traces defensively copy
their entry vector and metadata dictionary; payload ownership follows the selected
snapshot policy.

## Replay deterministically

```julia
replay = ReplayController(trace, entry -> dispatch_recorded(entry))

replay_step!(replay)
seek_replay!(replay, 1)
results = replay_all!(replay)
```

Manual stepping ignores wall time and preserves trace order. Dispatch results are
returned as `ReplayResult` values, allowing a test to compare model snapshots or
rendered buffers after selected entries.

## Replay with timing

```julia
replay = ReplayController(trace, dispatch_recorded; speed=2.0)
start_replay!(replay)

while replay_status(replay) == ReplayRunning
    poll_replay!(replay)
end
```

Clocked replay maps trace time to an injected monotonic clock. A speed of `2.0`
replays twice as fast. Pause and restart establish a new timing origin at the next
entry without changing ordering.

## Persistence

`EventTrace` is codec-neutral because Wicked events and application messages may
contain arbitrary Julia values. Applications can encode its immutable fields with
JSON, MessagePack, Julia Serialization, or a domain schema. Persist the trace
version and reject unsupported major versions when loading.

## Failure isolation

Filter, snapshot, clock, and dispatch failures are captured. Non-strict recorders
and replay controllers preserve the application loop and expose failures through
`take_trace_errors!` and `take_replay_errors!`. Strict mode rethrows after capture
for tests and development environments.
