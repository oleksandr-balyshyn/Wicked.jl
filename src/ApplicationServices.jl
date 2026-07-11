
struct ServiceFailure
    subsystem::Symbol
    error::CapturedException
end

struct ServicePulse
    timestamp_ns::UInt64
    animation_updates::Vector{AnimationUpdate}
    reload_events::Vector{ReloadEvent}
    expired_notifications::Int
    render_reasons::Vector{Symbol}
    failures::Vector{ServiceFailure}
end

Base.isempty(pulse::ServicePulse) = isempty(pulse.render_reasons) && isempty(pulse.failures)

struct ServiceShutdownReport
    timestamp_ns::UInt64
    closed_overlays::Int
    cancelled_animations::Int
    cleared_notifications::Int
    remaining_overlays::Int
    remaining_animations::Int
    quiescent::Bool
    trace::Union{Nothing,EventTrace}
    failures::Vector{ServiceFailure}
end

mutable struct ApplicationServices{O,K}
    overlays::OverlayManager{O}
    animations::AnimationManager
    actions::ActionRegistry
    themes::ThemeRegistry
    notifications::NotificationManager
    reloads::LiveReloadManager
    progress::ProgressTracker{K}
    recorder::Union{Nothing,EventRecorder}
    clock::Any
    last_action_generation::UInt64
    last_theme_generation::UInt64
    last_notification_generation::UInt64
    last_progress_generation::UInt64
    last_overlay_handles::Vector{OverlayHandle}
    running::Bool
    pulsing::Bool
    errors::Vector{ServiceFailure}
    mutex::ReentrantLock
end

function ApplicationServices(
    overlays::OverlayManager{O},
    animations::AnimationManager,
    actions::ActionRegistry,
    reloads::LiveReloadManager,
    progress::ProgressTracker{K};
    themes::ThemeRegistry=ThemeRegistry(),
    notifications::NotificationManager=NotificationManager(),
    recorder::Union{Nothing,EventRecorder}=nothing,
    clock=time_ns,
) where {O,K}
    applicable(clock) || throw(ArgumentError("service clock must be callable without arguments"))
    handles = OverlayHandle[record.handle for record in overlay_entries(overlays)]
    return ApplicationServices{O,K}(
        overlays,
        animations,
        actions,
        themes,
        notifications,
        reloads,
        progress,
        recorder,
        clock,
        action_registry_generation(actions),
        theme_generation(themes),
        notification_generation(notifications),
        progress_generation(progress),
        handles,
        true,
        false,
        ServiceFailure[],
        ReentrantLock(),
    )
end

function ApplicationServices(;
    overlays=OverlayManager(),
    animations=AnimationManager(),
    actions=ActionRegistry(),
    themes=ThemeRegistry(),
    notifications=NotificationManager(),
    reloads=LiveReloadManager(),
    progress=ProgressTracker(),
    recorder=nothing,
    clock=time_ns,
)
    return ApplicationServices(
        overlays,
        animations,
        actions,
        reloads,
        progress;
        themes,
        notifications,
        recorder,
        clock,
    )
end

function _service_now(services::ApplicationServices)
    value = services.clock()
    value isa Integer && value >= 0 ||
        throw(ArgumentError("service clock must return a non-negative integer"))
    return UInt64(value)
end

function _record_service_failure!(services::ApplicationServices, subsystem::Symbol, error, backtrace)
    failure = ServiceFailure(subsystem, CapturedException(error, backtrace))
    lock(services.mutex) do
        push!(services.errors, failure)
    end
    return failure
end

services_running(services::ApplicationServices) = lock(services.mutex) do
    services.running
end

service_errors(services::ApplicationServices) = lock(services.mutex) do
    copy(services.errors)
end

function take_service_errors!(services::ApplicationServices)
    return lock(services.mutex) do
        errors = copy(services.errors)
        empty!(services.errors)
        errors
    end
end

function set_service_recorder!(
    services::ApplicationServices,
    recorder::Union{Nothing,EventRecorder},
)
    lock(services.mutex) do
        services.running || throw(InvalidStateException("application services are stopped", :closed))
        services.pulsing &&
            throw(InvalidStateException("cannot replace the recorder during a service pulse", :active))
        services.recorder = recorder
    end
    return services
end

function _record_service_pulse!(services::ApplicationServices, pulse::ServicePulse)
    recorder = lock(services.mutex) do
        services.recorder
    end
    recorder === nothing && return nothing
    payload = (
        animation_updates=length(pulse.animation_updates),
        reload_events=length(pulse.reload_events),
        expired_notifications=pulse.expired_notifications,
        render_reasons=copy(pulse.render_reasons),
        failures=Symbol[failure.subsystem for failure in pulse.failures],
    )
    return record_trace!(
        recorder,
        :service_pulse,
        payload;
        source=:runtime,
        timestamp_ns=pulse.timestamp_ns,
    )
end

function pulse_services!(services::ApplicationServices; now_ns=nothing)
    lock(services.mutex) do
        services.running || throw(InvalidStateException("application services are stopped", :closed))
        services.pulsing &&
            throw(InvalidStateException("an application service pulse is already active", :active))
        services.pulsing = true
    end
    try
        now = now_ns === nothing ? _service_now(services) : UInt64(now_ns)
        failures = ServiceFailure[]
        animation_updates = try
            tick_animations!(services.animations; now_ns=now)
        catch error
            failure = _record_service_failure!(services, :animations, error, catch_backtrace())
            push!(failures, failure)
            AnimationUpdate[]
        end
        reload_events = try
            poll_reloads!(services.reloads; now_ns=now)
        catch error
            failure = _record_service_failure!(services, :reload, error, catch_backtrace())
            push!(failures, failure)
            ReloadEvent[]
        end
        expired_notifications = try
            expire_notifications!(services.notifications, now)
        catch error
            failure = _record_service_failure!(
                services,
                :notifications,
                error,
                catch_backtrace(),
            )
            push!(failures, failure)
            0
        end
        action_generation = action_registry_generation(services.actions)
        current_theme_generation = theme_generation(services.themes)
        current_notification_generation = notification_generation(services.notifications)
        progress_state_generation = progress_generation(services.progress)
        overlay_handles = OverlayHandle[
            record.handle for record in overlay_entries(services.overlays)
        ]
        previous_action, previous_theme, previous_notifications, previous_progress,
            previous_overlays = lock(services.mutex) do
            previous = (
                services.last_action_generation,
                services.last_theme_generation,
                services.last_notification_generation,
                services.last_progress_generation,
                services.last_overlay_handles,
            )
            services.last_action_generation = action_generation
            services.last_theme_generation = current_theme_generation
            services.last_notification_generation = current_notification_generation
            services.last_progress_generation = progress_state_generation
            services.last_overlay_handles = overlay_handles
            previous
        end
        reasons = Symbol[]
        isempty(animation_updates) || push!(reasons, :animation)
        isempty(reload_events) || push!(reasons, :reload)
        action_generation != previous_action && push!(reasons, :actions)
        current_theme_generation != previous_theme && push!(reasons, :theme)
        current_notification_generation != previous_notifications &&
            push!(reasons, :notifications)
        progress_state_generation != previous_progress && push!(reasons, :progress)
        overlay_handles != previous_overlays && push!(reasons, :overlays)
        pulse = ServicePulse(
            now,
            animation_updates,
            reload_events,
            expired_notifications,
            reasons,
            failures,
        )
        _record_service_pulse!(services, pulse)
        return pulse
    finally
        lock(services.mutex) do
            services.pulsing = false
        end
    end
end

function shutdown_services!(
    services::ApplicationServices;
    now_ns=nothing,
    max_passes::Integer=16,
)
    passes = Int(max_passes)
    passes > 0 || throw(ArgumentError("shutdown pass limit must be positive"))
    now = now_ns === nothing ? _service_now(services) : UInt64(now_ns)
    lock(services.mutex) do
        services.running || throw(InvalidStateException("application services are stopped", :closed))
        services.pulsing &&
            throw(InvalidStateException("cannot stop application services during a pulse", :active))
        services.running = false
    end
    failures = ServiceFailure[]
    closed_overlays = 0
    cancelled_animations = 0
    for _ in 1:passes
        handles = active_animation_handles(services.animations)
        for handle in handles
            try
                cancel_animation!(services.animations, handle) &&
                    (cancelled_animations += 1)
            catch error
                failure = _record_service_failure!(
                    services,
                    :animations,
                    error,
                    catch_backtrace(),
                )
                push!(failures, failure)
            end
        end
        try
            closed_overlays += close_all_overlays!(services.overlays; reason=OverlayShutdown)
        catch error
            failure = _record_service_failure!(services, :overlays, error, catch_backtrace())
            push!(failures, failure)
        end
        isempty(active_animation_handles(services.animations)) &&
            overlay_count(services.overlays) == 0 && break
    end
    remaining_animations = length(active_animation_handles(services.animations))
    remaining_overlays = overlay_count(services.overlays)
    quiescent = remaining_animations == 0 && remaining_overlays == 0
    if !quiescent
        failure = _record_service_failure!(
            services,
            :shutdown,
            InvalidStateException(
                "service callbacks kept creating overlays or animations during shutdown",
                :active,
            ),
            backtrace(),
        )
        push!(failures, failure)
    end
    cleared_notifications = try
        clear_notifications!(services.notifications; now_ns=now)
    catch error
        failure = _record_service_failure!(
            services,
            :notifications,
            error,
            catch_backtrace(),
        )
        push!(failures, failure)
        0
    end
    recorder = lock(services.mutex) do
        services.recorder
    end
    trace = if recorder === nothing
        nothing
    else
        try
            seal_trace!(recorder; ended_ns=now)
        catch error
            failure = _record_service_failure!(services, :tracing, error, catch_backtrace())
            push!(failures, failure)
            nothing
        end
    end
    return ServiceShutdownReport(
        now,
        closed_overlays,
        cancelled_animations,
        cleared_notifications,
        remaining_overlays,
        remaining_animations,
        quiescent,
        trace,
        failures,
    )
end
