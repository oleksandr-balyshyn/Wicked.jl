using Wicked.API
using Wicked.Experimental

clock_value = Ref(UInt64(0))
clock = () -> clock_value[]

progress = ProgressTracker{Symbol}(; clock=clock)
notifications = NotificationManager(5; clock=clock)
recorder = EventRecorder(; clock=clock)

services = ApplicationServices(
    animations=AnimationManager(; clock=clock),
    reloads=LiveReloadManager(; clock=clock),
    progress=progress,
    notifications=notifications,
    recorder=recorder,
    clock=clock,
)

register_action!(
    services.actions,
    Action(
        :save,
        "Save",
        context -> (:saved, context.data.name);
        enabled=context -> context.data.dirty,
        description="Save the current document",
        category="File",
    ),
)

document = (name="SPEC.md", dirty=true)
invocation = invoke_action!(services.actions, :save, ActionContext(; data=document))
@assert invocation.status == ActionInvoked
@assert invocation.value == (:saved, "SPEC.md")

set_theme_preference!(services.themes, LightTheme)
notify!(services.notifications, "Connected"; severity=:success, timeout=2.0)
add_progress_task!(services.progress, :index; description="Indexing", total=10)
advance_progress!(services.progress, :index, 4)

samples = Float64[]
animate!(
    services.animations,
    AnimationSpec(
        AnimationTrack(0.0, 1.0; easing=ease_in_out_cubic);
        duration=1.0,
        key=:opacity,
    );
    on_update=value -> push!(samples, value),
)

clock_value[] = UInt64(500_000_000)
pulse = pulse_services!(services)

@assert :animation in pulse.render_reasons
@assert :actions in pulse.render_reasons
@assert :theme in pulse.render_reasons
@assert :notifications in pulse.render_reasons
@assert :progress in pulse.render_reasons
@assert !isempty(samples)

report = shutdown_services!(services)
@assert report.quiescent
@assert report.cancelled_animations == 1
@assert report.cleared_notifications == 1
@assert report.trace !== nothing

println("application services example completed")
