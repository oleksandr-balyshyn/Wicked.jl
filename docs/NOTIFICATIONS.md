# Managed Notifications

The core `NotificationCenter` remains a small collection suitable for immediate-mode
rendering. `NotificationManager` adds the retained lifecycle needed by production
applications while continuing to render through `NotificationView`.

## Post notifications

```julia
notifications = NotificationManager(
    5;
    announcements=AnnouncementQueue(),
)

event = notify!(
    notifications,
    "Build completed";
    title="Compiler",
    severity=:success,
    timeout=4.0,
    dedup_key=:build_status,
    actions=[NotificationAction(:open_log, "Open log", :show_build_log)],
)
```

Posting the same ID or deduplication key replaces the previous entry. New entries
move to the end of display order. Exceeding the maximum evicts the oldest entry and
records `NotificationEvicted`.

Error notifications use assertive accessibility announcements; other severities use
polite announcements. Announcement failure is captured without rolling back the
committed notification.

## Timeout lifecycle

```julia
pause_notification!(notifications, event.notification.id)
resume_notification!(notifications, event.notification.id)
expire_notifications!(notifications)
```

Pause stores the exact remaining nanoseconds. Resume starts a new timeout segment,
so hover or keyboard focus can suspend expiry without extending already elapsed
time. Clock regression is treated as zero elapsed time rather than unsigned
underflow.

## Actions and dismissal

```julia
result = activate_notification_action!(notifications, id, :open_log)
result.status == NotificationActionHandled && dispatch(result.value)

dismiss_notification!(notifications, id)
```

Actions may be disabled and may choose whether activation dismisses the notification.
Non-dismissible notifications reject ordinary dismissal; administrative code can use
`force=true`.

## Rendering

```julia
render!(buffer, ManagedNotificationView(notifications), area)
```

The managed view creates a synchronized `NotificationCenter` snapshot and delegates
to the existing renderer. `notification_snapshots` additionally exposes actions,
remaining time, pause state, dismissal policy, and deduplication keys for custom
toast layouts.

Use `notification_generation` for render invalidation and
`take_notification_events!` for audit, telemetry, or application messages.

## Toolkit and accessibility

```julia
component = notification_component(
    toolkit_adapter,
    notifications;
    width=72,
    semantic_id="toast-region",
)
```

The component takes one synchronized notification snapshot, then uses it for both
rich rendering and semantics. `render_notification_control` emits width-bounded
severity roles and optional action labels. `notification_semantic_tree` represents
warnings and errors as `AlertRole`, other messages as `StatusRole`, and the region as
`LogRole`.

Dismissible notifications expose `DismissSemanticAction`. Notification actions are
focusable `ButtonRole` children with activation actions and metadata mapping back to
`activate_notification_action!`.

Bind those actions to a semantic dispatcher using the same ordered snapshot used to
build the tree:

```julia
snapshots = notification_snapshots(notifications)
tree = notification_semantic_tree(snapshots; id="toast-region")
binding = bind_notification_semantics!(
    dispatcher,
    notifications,
    snapshots;
    id="toast-region",
)

unbind_notification_semantics!(binding)
```

Registration is copied-state and rejects handler collisions by default. With
`replace=true`, displaced handlers are retained and restored during unbind. Unbind
uses atomic ownership and restores a node only when the dispatcher still contains
that binding's handler, so a newer registration is never overwritten.
