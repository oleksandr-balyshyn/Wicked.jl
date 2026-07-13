using Wicked.API

clock_value = Ref(UInt64(0))
clock = () -> clock_value[]

tracker = ProgressTracker{Symbol}(; clock=clock)
add_progress_task!(tracker, :download; description="Download", total=100)

clock_value[] = UInt64(2_000_000_000)
advance_progress!(tracker, :download, 25)
snapshot = progress_snapshot(tracker, :download)

@assert snapshot.ratio == 0.25
@assert snapshot.elapsed_seconds == 2.0
@assert snapshot.eta_seconds == 6.0

line = render_progress_control(snapshot; width=40, show_eta=true)
semantics = progress_semantic_node(snapshot; id="download-progress")

@assert line isa RichLine
@assert semantics.role == ProgressRole
@assert semantics.state.value_now == 25.0

announcements = AnnouncementQueue()
notifications = NotificationManager(3; announcements=announcements, clock=clock)

event = notify!(
    notifications,
    "Archive downloaded";
    title="Network",
    severity=:success,
    timeout=nothing,
    actions=[
        NotificationAction(:open, "Open", :open_archive; dismiss=false),
    ],
)

notification_id = event.notification.id
result = activate_notification_action!(notifications, notification_id, :open)

@assert result.status == NotificationActionHandled
@assert result.value == :open_archive
@assert !result.dismissed
@assert length(notification_snapshots(notifications)) == 1

notification_tree = notification_semantic_tree(
    notification_snapshots(notifications);
    id="notifications",
)
@assert notification_tree.root.role == LogRole
@assert length(take_announcements!(announcements)) == 1

@assert dismiss_notification!(notifications, notification_id)
@assert isempty(notification_snapshots(notifications))

complete_progress!(tracker, :download)
@assert progress_snapshot(tracker, :download).status == CompletedProgress

println("progress and notifications example completed")
