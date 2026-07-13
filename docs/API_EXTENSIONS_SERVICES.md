# Extensions and Services API

This page contains generated reference documentation for extension ownership,
interaction services, and root-level application service contracts.

The stable extension surface covers:

- Extension descriptors, versions, dependencies, policies, states, errors, and
  activation contexts.
- Dependency-ordered activation and reverse-order deactivation.
- Contribution ownership for widgets, themes, syntax highlighters, backends,
  commands, inspector panels, and services.
- Service registration and lookup with bounded registry policy.
- Scoped `with_extensions` activation that cleans up contributions after the
  operation exits.

The stable application-services surface includes `NotificationCenter`,
`NotificationView`, `NotificationManager`, `ManagedNotificationView`, `Progress`,
and `ProgressTracker` so notification and progress state can be represented
through public API contracts as well as the higher-level manager types.

Use managers such as `NotificationManager` and `ProgressTracker` for lifecycle,
deduplication, expiration, aggregation, and deterministic shutdown. Use
renderable widgets such as `ManagedNotificationView` and `Progress` at the view
boundary. This keeps application services testable and lets UI code depend on
stable widget types instead of service internals.

Extensions should contribute through `ExtensionContext` instead of mutating
global tables. Contributions are owned by one extension and removed during
deactivation or activation rollback.

For a focused extension lifecycle example, see
[`examples/extensions_quickstart.jl`](examples/extensions_quickstart.jl).

## Stable application-services quickstart

Use `ApplicationServices` when an application needs one host for cross-cutting
managers that pulse once per frame. The host keeps actions, themes,
notifications, progress, overlays, animations, live reload, and optional tracing
coordinated without making render functions own lifecycle work:

```julia
using Wicked.API

clock_value = Ref(UInt64(0))
clock = () -> clock_value[]

services = ApplicationServices(
    progress=ProgressTracker{Symbol}(; clock),
    notifications=NotificationManager(5; clock),
    recorder=EventRecorder(; clock),
    clock=clock,
)

register_action!(
    services.actions,
    Action(
        :save,
        "Save",
        context -> (:saved, context.data.name);
        enabled=context -> context.data.dirty,
        category="File",
    ),
)

document = (name="README.md", dirty=true)
result = invoke_action!(services.actions, :save, ActionContext(; data=document))
@assert result.status == ActionInvoked

set_theme_preference!(services.themes, LightTheme)
notify!(services.notifications, "Connected"; severity=:success, timeout=2.0)
add_progress_task!(services.progress, :index; description="Indexing", total=10)
advance_progress!(services.progress, :index, 4)

notification_view = ManagedNotificationView(services.notifications)
progress_widget = Progress(0.4; label="Indexing")
service_dispatcher = SemanticDispatcher()
notification_binding = register_managed_notification_view_semantic_handlers!(
    service_dispatcher,
    :notifications,
    notification_view,
)
register_progress_semantic_handlers!(service_dispatcher, :progress, progress_widget, ProgressState())
@assert notification_view isa ManagedNotificationView
@assert progress_widget isa Progress

clock_value[] = UInt64(500_000_000)
pulse = pulse_services!(services)
@assert :actions in pulse.render_reasons
@assert :theme in pulse.render_reasons
@assert :notifications in pulse.render_reasons
@assert :progress in pulse.render_reasons

report = shutdown_services!(services)
@assert unbind_notification_semantics!(notification_binding)
@assert report.quiescent
```

Use `ManagedNotificationView` when the UI should render the current
`NotificationManager` snapshot without copying notifications into a separate
view model. Use `Progress(aggregate_progress(services.progress))` when the UI
should summarize all tracked tasks through one stable progress widget.
Use `register_managed_notification_view_semantic_handlers!` or
`register_notification_view_semantic_handlers!` to bind notification dismissal
and notification actions to a `SemanticDispatcher`. Use
`register_progress_semantic_handlers!` or
`register_progress_bar_semantic_handlers!` when progress indicators should be
visible to semantic pilots and accessibility tooling.

Call `pulse_services!` from the managed runtime, a timer, or a controlled
headless test loop. Use `shutdown_services!` during application teardown so
overlays, animations, notifications, and tracing converge deterministically.
See [Application Services](APPLICATION_SERVICES.md) and
[`examples/application_services.jl`](examples/application_services.jl) for a
complete deterministic example.

For a focused rendering-only feedback example, see
[`examples/feedback_quickstart.jl`](examples/feedback_quickstart.jl).

```@autodocs
Modules = [
    Wicked.Extensions,
    Wicked.InteractionServices,
    Wicked,
]
Private = false
```
