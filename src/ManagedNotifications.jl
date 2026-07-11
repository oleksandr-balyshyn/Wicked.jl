using .Accessibility: AnnouncementQueue,
                      AssertiveAnnouncement,
                      PoliteAnnouncement,
                      announce!
using .Core: Buffer, Rect
import .Core: render!
using .Widgets: Notification, NotificationCenter, NotificationView
import .Widgets: dismiss_notification!, expire_notifications!, push_notification!


struct NotificationAction
    id::Symbol
    label::String
    value::Any
    enabled::Bool
    dismiss::Bool
end

function NotificationAction(
    id::Symbol,
    label::AbstractString,
    value=id;
    enabled::Bool=true,
    dismiss::Bool=true,
)
    return NotificationAction(id, String(label), value, enabled, dismiss)
end

@enum NotificationLifecycle::UInt8 begin
    NotificationAdded
    NotificationUpdated
    NotificationDismissed
    NotificationExpired
    NotificationEvicted
    NotificationActionInvoked
end

struct NotificationEvent
    lifecycle::NotificationLifecycle
    notification::Notification
    action_id::Union{Nothing,Symbol}
    timestamp_ns::UInt64
end

struct NotificationSnapshot
    notification::Notification
    actions::Vector{NotificationAction}
    dismissible::Bool
    paused::Bool
    remaining_ns::Union{Nothing,UInt64}
    dedup_key::Any
end

@enum NotificationActionStatus::UInt8 begin
    NotificationActionHandled
    NotificationActionMissing
    NotificationActionDisabled
end

struct NotificationActionResult
    status::NotificationActionStatus
    value::Any
    dismissed::Bool
end

struct _ManagedNotification
    notification::Notification
    actions::Vector{NotificationAction}
    dismissible::Bool
    paused::Bool
    remaining_ns::Union{Nothing,UInt64}
    dedup_key::Any
end

mutable struct NotificationManager
    entries::Dict{Any,_ManagedNotification}
    order::Vector{Any}
    dedup::Dict{Any,Any}
    maximum::Int
    generation::UInt64
    events::Vector{NotificationEvent}
    errors::Vector{CapturedException}
    announcements::Union{Nothing,AnnouncementQueue}
    clock::Any
    mutex::ReentrantLock
end

function NotificationManager(
    maximum::Integer=5;
    announcements::Union{Nothing,AnnouncementQueue}=nothing,
    clock=time_ns,
)
    maximum > 0 || throw(ArgumentError("notification maximum must be positive"))
    applicable(clock) || throw(ArgumentError("notification clock must be callable without arguments"))
    return NotificationManager(
        Dict{Any,_ManagedNotification}(),
        Any[],
        Dict{Any,Any}(),
        Int(maximum),
        UInt64(0),
        NotificationEvent[],
        CapturedException[],
        announcements,
        clock,
        ReentrantLock(),
    )
end

function _notification_now(manager::NotificationManager)
    value = manager.clock()
    value isa Integer && value >= 0 ||
        throw(ArgumentError("notification clock must return a non-negative integer"))
    return UInt64(value)
end

function _next_notification_generation(manager::NotificationManager)
    manager.generation == typemax(UInt64) &&
        throw(OverflowError("notification generation exhausted"))
    return manager.generation + UInt64(1)
end

function _notification_timeout(value)
    value === nothing && return nothing
    seconds = Float64(value)
    isfinite(seconds) && seconds >= 0.0 ||
        throw(ArgumentError("notification timeout must be finite and non-negative"))
    nanoseconds = seconds * 1.0e9
    nanoseconds <= typemax(UInt64) || throw(OverflowError("notification timeout is too large"))
    return round(UInt64, nanoseconds)
end

function _remaining_notification_ns(entry::_ManagedNotification, now::UInt64)
    entry.paused && return entry.remaining_ns
    timeout = entry.notification.timeout_ns
    timeout === nothing && return nothing
    elapsed = now >= entry.notification.created_ns ?
        now - entry.notification.created_ns : UInt64(0)
    return elapsed >= timeout ? UInt64(0) : timeout - elapsed
end

function _copy_notification_snapshot(entry::_ManagedNotification, now::UInt64)
    return NotificationSnapshot(
        entry.notification,
        copy(entry.actions),
        entry.dismissible,
        entry.paused,
        _remaining_notification_ns(entry, now),
        entry.dedup_key,
    )
end

function _capture_notification_error!(manager::NotificationManager, error, backtrace)
    lock(manager.mutex) do
        push!(manager.errors, CapturedException(error, backtrace))
    end
    return nothing
end

function _announce_notification!(manager::NotificationManager, notification::Notification)
    queue = manager.announcements
    queue === nothing && return nothing
    message = isempty(notification.title) ? notification.message :
        string(notification.title, ": ", notification.message)
    politeness = notification.severity == :error ? AssertiveAnnouncement : PoliteAnnouncement
    try
        return announce!(queue, message; politeness, source_id=notification.id)
    catch error
        _capture_notification_error!(manager, error, catch_backtrace())
        return nothing
    end
end

function notify!(
    manager::NotificationManager,
    message::AbstractString;
    id=gensym(:notification),
    title::AbstractString="",
    severity::Symbol=:info,
    timeout=5.0,
    actions=NotificationAction[],
    dismissible::Bool=true,
    dedup_key=nothing,
)
    severity in (:info, :success, :warning, :error) ||
        throw(ArgumentError("notification severity must be info, success, warning, or error"))
    now = _notification_now(manager)
    timeout_ns = _notification_timeout(timeout)
    notification = Notification(
        id,
        String(title),
        String(message),
        severity,
        now,
        timeout_ns,
    )
    return push_notification!(
        manager,
        notification;
        actions,
        dismissible,
        dedup_key,
        now_ns=now,
    )
end

function push_notification!(
    manager::NotificationManager,
    notification::Notification;
    actions=NotificationAction[],
    dismissible::Bool=true,
    dedup_key=nothing,
    now_ns=nothing,
)
    notification.severity in (:info, :success, :warning, :error) ||
        throw(ArgumentError("notification severity must be info, success, warning, or error"))
    now = now_ns === nothing ? _notification_now(manager) : UInt64(now_ns)
    resolved_actions = NotificationAction[action for action in actions]
    entry = _ManagedNotification(
        notification,
        resolved_actions,
        dismissible,
        false,
        notification.timeout_ns,
        dedup_key,
    )
    events = lock(manager.mutex) do
        generation = _next_notification_generation(manager)
        entries = copy(manager.entries)
        order = copy(manager.order)
        dedup = copy(manager.dedup)
        conflicts = Set{Any}()
        haskey(entries, notification.id) && push!(conflicts, notification.id)
        if dedup_key !== nothing
            dedup_id = get(dedup, dedup_key, nothing)
            dedup_id === nothing || push!(conflicts, dedup_id)
        end
        lifecycle = isempty(conflicts) ? NotificationAdded : NotificationUpdated
        if !isempty(conflicts)
            filter!(candidate -> !(candidate in conflicts), order)
        end
        for conflict in conflicts
            previous = entries[conflict]
            previous.dedup_key === nothing || delete!(dedup, previous.dedup_key)
            delete!(entries, conflict)
        end
        entries[notification.id] = entry
        push!(order, notification.id)
        dedup_key === nothing || (dedup[dedup_key] = notification.id)
        produced = NotificationEvent[
            NotificationEvent(lifecycle, notification, nothing, now),
        ]
        while length(order) > manager.maximum
            evicted_id = popfirst!(order)
            evicted = pop!(entries, evicted_id)
            evicted.dedup_key === nothing || delete!(dedup, evicted.dedup_key)
            push!(
                produced,
                NotificationEvent(NotificationEvicted, evicted.notification, nothing, now),
            )
        end
        manager.entries = entries
        manager.order = order
        manager.dedup = dedup
        append!(manager.events, produced)
        manager.generation = generation
        return produced
    end
    _announce_notification!(manager, notification)
    return first(events)
end

function dismiss_notification!(
    manager::NotificationManager,
    id;
    force::Bool=false,
    now_ns=nothing,
)
    now = now_ns === nothing ? _notification_now(manager) : UInt64(now_ns)
    return lock(manager.mutex) do
        entry = get(manager.entries, id, nothing)
        entry === nothing && return false
        !entry.dismissible && !force && return false
        generation = _next_notification_generation(manager)
        entries = copy(manager.entries)
        order = copy(manager.order)
        dedup = copy(manager.dedup)
        delete!(entries, id)
        filter!(candidate -> candidate != id, order)
        entry.dedup_key === nothing || delete!(dedup, entry.dedup_key)
        event = NotificationEvent(NotificationDismissed, entry.notification, nothing, now)
        manager.entries = entries
        manager.order = order
        manager.dedup = dedup
        push!(manager.events, event)
        manager.generation = generation
        return true
    end
end

function pause_notification!(manager::NotificationManager, id; now_ns=nothing)
    now = now_ns === nothing ? _notification_now(manager) : UInt64(now_ns)
    return lock(manager.mutex) do
        entry = get(manager.entries, id, nothing)
        entry === nothing && return false
        entry.paused && return false
        generation = _next_notification_generation(manager)
        entries = copy(manager.entries)
        entries[id] = _ManagedNotification(
            entry.notification,
            entry.actions,
            entry.dismissible,
            true,
            _remaining_notification_ns(entry, now),
            entry.dedup_key,
        )
        manager.entries = entries
        manager.generation = generation
        return true
    end
end

function resume_notification!(manager::NotificationManager, id; now_ns=nothing)
    now = now_ns === nothing ? _notification_now(manager) : UInt64(now_ns)
    return lock(manager.mutex) do
        entry = get(manager.entries, id, nothing)
        entry === nothing && return false
        entry.paused || return false
        generation = _next_notification_generation(manager)
        notification = Notification(
            entry.notification.id,
            entry.notification.title,
            entry.notification.message,
            entry.notification.severity,
            now,
            entry.remaining_ns,
        )
        entries = copy(manager.entries)
        entries[id] = _ManagedNotification(
            notification,
            entry.actions,
            entry.dismissible,
            false,
            entry.remaining_ns,
            entry.dedup_key,
        )
        manager.entries = entries
        manager.generation = generation
        return true
    end
end

function expire_notifications!(manager::NotificationManager, now_ns::Integer=_notification_now(manager))
    now = UInt64(now_ns)
    return lock(manager.mutex) do
        expired = Any[
            id for id in manager.order
            if !manager.entries[id].paused &&
               _remaining_notification_ns(manager.entries[id], now) == UInt64(0)
        ]
        isempty(expired) && return 0
        generation = _next_notification_generation(manager)
        entries = copy(manager.entries)
        expired_ids = Set(expired)
        order = Any[id for id in manager.order if !(id in expired_ids)]
        dedup = copy(manager.dedup)
        for id in expired
            entry = pop!(entries, id)
            entry.dedup_key === nothing || delete!(dedup, entry.dedup_key)
            push!(
                manager.events,
                NotificationEvent(NotificationExpired, entry.notification, nothing, now),
            )
        end
        manager.entries = entries
        manager.order = order
        manager.dedup = dedup
        manager.generation = generation
        return length(expired)
    end
end

function activate_notification_action!(
    manager::NotificationManager,
    notification_id,
    action_id::Symbol;
    now_ns=nothing,
)
    now = now_ns === nothing ? _notification_now(manager) : UInt64(now_ns)
    return lock(manager.mutex) do
        entry = get(manager.entries, notification_id, nothing)
        entry === nothing &&
            return NotificationActionResult(NotificationActionMissing, nothing, false)
        index = findfirst(action -> action.id == action_id, entry.actions)
        index === nothing &&
            return NotificationActionResult(NotificationActionMissing, nothing, false)
        action = entry.actions[index]
        action.enabled ||
            return NotificationActionResult(NotificationActionDisabled, nothing, false)
        generation = _next_notification_generation(manager)
        event = NotificationEvent(
            NotificationActionInvoked,
            entry.notification,
            action.id,
            now,
        )
        dismissed = false
        if action.dismiss
            entries = copy(manager.entries)
            order = copy(manager.order)
            dedup = copy(manager.dedup)
            delete!(entries, notification_id)
            filter!(candidate -> candidate != notification_id, order)
            entry.dedup_key === nothing || delete!(dedup, entry.dedup_key)
            manager.entries = entries
            manager.order = order
            manager.dedup = dedup
            dismissed = true
        end
        push!(manager.events, event)
        manager.generation = generation
        return NotificationActionResult(NotificationActionHandled, action.value, dismissed)
    end
end

function notification_snapshots(manager::NotificationManager; now_ns=nothing)
    now = now_ns === nothing ? _notification_now(manager) : UInt64(now_ns)
    return lock(manager.mutex) do
        NotificationSnapshot[
            _copy_notification_snapshot(manager.entries[id], now) for id in manager.order
        ]
    end
end

function notification_center_snapshot(manager::NotificationManager; now_ns=nothing)
    snapshots = notification_snapshots(manager; now_ns)
    center = NotificationCenter(manager.maximum)
    append!(center.notifications, (snapshot.notification for snapshot in snapshots))
    return center
end

struct ManagedNotificationView
    manager::NotificationManager
end

function render!(buffer::Buffer, view::ManagedNotificationView, area::Rect)
    return render!(buffer, NotificationView(notification_center_snapshot(view.manager)), area)
end

notification_generation(manager::NotificationManager) = lock(manager.mutex) do
    manager.generation
end

function clear_notifications!(manager::NotificationManager; now_ns=nothing)
    now = now_ns === nothing ? _notification_now(manager) : UInt64(now_ns)
    return lock(manager.mutex) do
        isempty(manager.order) && return 0
        generation = _next_notification_generation(manager)
        count = length(manager.order)
        for id in manager.order
            push!(
                manager.events,
                NotificationEvent(
                    NotificationDismissed,
                    manager.entries[id].notification,
                    nothing,
                    now,
                ),
            )
        end
        manager.entries = Dict{Any,_ManagedNotification}()
        manager.order = Any[]
        manager.dedup = Dict{Any,Any}()
        manager.generation = generation
        return count
    end
end

notification_events(manager::NotificationManager) = lock(manager.mutex) do
    copy(manager.events)
end

function take_notification_events!(manager::NotificationManager)
    return lock(manager.mutex) do
        events = copy(manager.events)
        empty!(manager.events)
        events
    end
end

notification_errors(manager::NotificationManager) = lock(manager.mutex) do
    copy(manager.errors)
end

function take_notification_errors!(manager::NotificationManager)
    return lock(manager.mutex) do
        errors = copy(manager.errors)
        empty!(manager.errors)
        errors
    end
end
