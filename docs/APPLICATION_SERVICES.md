# Application Services

`ApplicationServices` groups cross-cutting facilities behind one runtime pulse. It
does not replace Wicked's application model or Toolkit tree; it removes repetitive
coordination code for overlays, animations, actions, live reload, progress, and
optional event tracing.

## Create a service host

```julia
services = ApplicationServices(recorder=EventRecorder())
```

Every manager remains directly accessible:

```julia
register_action!(services.actions, save_action)
set_theme_preference!(services.themes, LightTheme)
notify!(services.notifications, "Connected"; severity=:success)
open_overlay!(services.overlays, dialog)
add_progress_task!(services.progress, :build; total=20)
animate!(services.animations, fade_spec; on_update=set_opacity!)
```

Applications can inject preconfigured, concretely typed managers through the
positional constructor when overlay content or progress task IDs should not use
`Any`.

## Pulse once per runtime frame

```julia
pulse = pulse_services!(services)

isempty(pulse.render_reasons) || request_render!()
```

One clock value drives animation and reload work. A pulse reports animation
updates, reload events, isolated subsystem failures, and deterministic render
reasons:

- `:animation` when animation values advanced.
- `:reload` when live assets produced events.
- `:actions` when registrations or active scopes changed.
- `:theme` when theme selection, preference, or registration state changed.
- `:notifications` when notifications are posted, updated, dismissed, or expire.
- `:progress` when tracked task state changed.
- `:overlays` when the overlay stack gained, lost, or reordered handles.

Concurrent pulses are rejected. Manager callbacks execute according to their own
lifecycle guarantees and never run while the service-host lock is held.

## Tracing

When a recorder is attached, each pulse records counts, render reasons, and failed
subsystem names at the shared timestamp. Use `set_service_recorder!` to attach or
detach recording while the host is idle.

## Shutdown

```julia
report = shutdown_services!(services)
```

Shutdown is one-way. It closes overlays from top to bottom, cancels active
animations, clears retained notifications, and seals the trace. Reload polling is
passive and owns no task that needs cancellation. Callback and subsystem failures
are retained in both their origin manager and the shutdown report where applicable.

Animation and overlay callbacks may create more lifecycle work. Shutdown therefore
repeats cancellation and closure until both managers are empty. `max_passes`
defaults to 16; if callbacks still repopulate work, the report has `quiescent=false`,
includes residual counts, and records a `:shutdown` failure instead of looping
forever.

Calling pulse or shutdown again raises `InvalidStateException`. Shutdown is rejected
while a pulse is active so lifecycle callbacks cannot observe a half-closed host.
