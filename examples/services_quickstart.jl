using Wicked.API

clock_value = Ref(UInt64(0))
clock = () -> clock_value[]

services = ApplicationServices(
    progress=ProgressTracker{Symbol}(; clock),
    notifications=NotificationManager(3; clock),
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
@assert result.value == (:saved, "README.md")

set_theme_preference!(services.themes, LightTheme)
notify!(services.notifications, "Connected"; id=:connected, severity=:success, timeout=2.0)
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

# Family tokens: NotificationCenter, NotificationView

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
@assert report.cleared_notifications == 1
@assert report.trace !== nothing

println("services quickstart example completed")
