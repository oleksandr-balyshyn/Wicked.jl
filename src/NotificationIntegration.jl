using Unicode

using .Accessibility: ActivateSemanticAction,
                      AlertRole,
                      ButtonRole,
                      DismissSemanticAction,
                      FocusSemanticAction,
                      LogRole,
                      SelectSemanticAction,
                      SemanticAction,
                      SemanticActionRequest,
                      SemanticActionResult,
                      SemanticDispatcher,
                      SemanticNode,
                      SemanticRect,
                      SemanticState,
                      SemanticTree,
                      StatusRole
using .Core: DEFAULT_WIDTH_POLICY, grapheme_width


function _clip_notification_text(value::AbstractString, width::Int)
    width <= 0 && return ""
    output = IOBuffer()
    used = 0
    for grapheme in Unicode.graphemes(value)
        cells = grapheme_width(DEFAULT_WIDTH_POLICY, grapheme)
        used + cells > width && break
        print(output, grapheme)
        used += cells
    end
    return String(take!(output))
end

_notification_role(severity::Symbol) = Symbol("notification_", severity)

function render_notification_control(
    snapshots::AbstractVector{<:NotificationSnapshot};
    width::Integer=80,
    newest_first::Bool=false,
    show_actions::Bool=true,
)
    resolved_width = Int(width)
    resolved_width > 0 || throw(ArgumentError("notification control width must be positive"))
    ordered = newest_first ? reverse(snapshots) : snapshots
    lines = RichContent.RichLine[]
    for snapshot in ordered
        notification = snapshot.notification
        prefix = isempty(notification.title) ? "" : string(notification.title, ": ")
        status = snapshot.paused ? " [paused]" : ""
        actions = if show_actions
            visible = [action.label for action in snapshot.actions if action.enabled]
            isempty(visible) ? "" : string(" [", join(visible, " | "), "]")
        else
            ""
        end
        text = _clip_notification_text(
            string(prefix, notification.message, status, actions),
            resolved_width,
        )
        push!(
            lines,
            RichContent.RichLine(
                RichContent.RichSpan[
                    RichContent.RichSpan(text, _notification_role(notification.severity), nothing),
                ],
                :notification,
                nothing,
            ),
        )
    end
    return lines
end

function notification_semantic_tree(
    snapshots::AbstractVector{<:NotificationSnapshot};
    id="notifications",
    label::AbstractString="Notifications",
    bounds::Union{Nothing,SemanticRect}=nothing,
)
    identifier = string(id)
    children = SemanticNode[]
    for (index, snapshot) in enumerate(snapshots)
        notification = snapshot.notification
        action_nodes = SemanticNode[
            SemanticNode(
                "$(identifier)/$index/action/$action_index",
                ButtonRole;
                label=action.label,
                state=SemanticState(
                    enabled=action.enabled,
                    focusable=action.enabled,
                ),
                actions=action.enabled ? SemanticAction[ActivateSemanticAction] : SemanticAction[],
                metadata=Dict(
                    :notification_id => notification.id,
                    :action_id => action.id,
                    :dismiss => action.dismiss,
                ),
            ) for (action_index, action) in enumerate(snapshot.actions)
        ]
        role = notification.severity in (:warning, :error) ? AlertRole : StatusRole
        actions = snapshot.dismissible ? SemanticAction[DismissSemanticAction] : SemanticAction[]
        push!(
            children,
            SemanticNode(
                "$(identifier)/$index",
                role;
                label=isempty(notification.title) ? notification.message : notification.title,
                description=isempty(notification.title) ? nothing : notification.message,
                state=SemanticState(
                    invalid=notification.severity == :error,
                    readonly=true,
                ),
                actions,
                children=action_nodes,
                metadata=Dict(
                    :notification_id => notification.id,
                    :severity => notification.severity,
                    :paused => snapshot.paused,
                    :remaining_ns => snapshot.remaining_ns,
                    :dedup_key => snapshot.dedup_key,
                ),
            ),
        )
    end
    return SemanticTree(
        SemanticNode(
            identifier,
            LogRole;
            label,
            bounds,
            state=SemanticState(readonly=true),
            actions=SemanticAction[FocusSemanticAction, SelectSemanticAction],
            children,
        ),
    )
end

function notification_component(
    adapter::CoreIntegration.ToolkitElementAdapter,
    manager::NotificationManager;
    width::Integer=80,
    now_ns=nothing,
    newest_first::Bool=false,
    show_actions::Bool=true,
    semantic_id="notifications",
    semantic_label::AbstractString="Notifications",
    semantic_bounds::Union{Nothing,SemanticRect}=nothing,
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=false,
)
    snapshots = notification_snapshots(manager; now_ns)
    ordered = newest_first ? reverse(snapshots) : snapshots
    rendered = render_notification_control(
        ordered;
        width,
        newest_first=false,
        show_actions,
    )
    semantics = notification_semantic_tree(
        ordered;
        id=semantic_id,
        label=semantic_label,
        bounds=semantic_bounds,
    )
    return ToolkitComponents.toolkit_component_view(
        adapter,
        rendered,
        semantics;
        key,
        id,
        classes,
        focusable,
    )
end

struct NotificationSemanticBinding
    dispatcher::SemanticDispatcher
    handlers::Dict{String,Function}
    previous::Dict{String,Union{Nothing,Function}}
    active::Base.Threads.Atomic{Bool}
    mutex::ReentrantLock
end

function _notification_dismiss_handler(
    active::Base.Threads.Atomic{Bool},
    execution::ReentrantLock,
    manager::NotificationManager,
    notification_id,
)
    return function(request::SemanticActionRequest)
        active[] || return SemanticActionResult(false; message="notification binding is inactive")
        return lock(execution) do
            active[] || return SemanticActionResult(false; message="notification binding is inactive")
            request.action == DismissSemanticAction ||
                return SemanticActionResult(false; message="unsupported notification action")
            dismissed = dismiss_notification!(manager, notification_id)
            return SemanticActionResult(
                dismissed;
                message=dismissed ? nothing : "notification is missing or not dismissible",
            )
        end
    end
end

function _notification_action_handler(
    active::Base.Threads.Atomic{Bool},
    execution::ReentrantLock,
    manager::NotificationManager,
    notification_id,
    action_id::Symbol,
)
    return function(request::SemanticActionRequest)
        active[] || return SemanticActionResult(false; message="notification binding is inactive")
        return lock(execution) do
            active[] || return SemanticActionResult(false; message="notification binding is inactive")
            request.action == ActivateSemanticAction ||
                return SemanticActionResult(false; message="unsupported notification action")
            result = activate_notification_action!(manager, notification_id, action_id)
            if result.status == NotificationActionHandled
                return SemanticActionResult(true; value=result.value)
            elseif result.status == NotificationActionDisabled
                return SemanticActionResult(false; message="notification action is disabled")
            end
            return SemanticActionResult(false; message="notification or action is missing")
        end
    end
end

function bind_notification_semantics!(
    dispatcher::SemanticDispatcher,
    manager::NotificationManager,
    snapshots::AbstractVector{<:NotificationSnapshot};
    id="notifications",
    replace::Bool=false,
)
    identifier = string(id)
    active = Base.Threads.Atomic{Bool}(true)
    execution = ReentrantLock()
    handlers = Dict{String,Function}(
        identifier => function (request::SemanticActionRequest)
            active[] || return SemanticActionResult(false; message="notification binding is inactive")
            request.action in (FocusSemanticAction, SelectSemanticAction) ||
                return SemanticActionResult(false; message="unsupported notification action")
            return SemanticActionResult(true; value=notification_snapshots(manager))
        end,
    )
    for (index, snapshot) in enumerate(snapshots)
        notification_id = snapshot.notification.id
        if snapshot.dismissible
            node_id = "$(identifier)/$index"
            handlers[node_id] = _notification_dismiss_handler(
                active,
                execution,
                manager,
                notification_id,
            )
        end
        for (action_index, action) in enumerate(snapshot.actions)
            action.enabled || continue
            node_id = "$(identifier)/$index/action/$action_index"
            handlers[node_id] = _notification_action_handler(
                active,
                execution,
                manager,
                notification_id,
                action.id,
            )
        end
    end
    previous = lock(dispatcher.mutex) do
        collisions = String[node_id for node_id in keys(handlers) if haskey(dispatcher.handlers, node_id)]
        !replace && !isempty(collisions) && throw(ArgumentError(
            "semantic handlers are already registered: $(join(sort!(collisions), ", "))",
        ))
        updated = copy(dispatcher.handlers)
        previous = Dict{String,Union{Nothing,Function}}()
        for (node_id, handler) in handlers
            previous[node_id] = get(updated, node_id, nothing)
            updated[node_id] = handler
        end
        dispatcher.handlers = updated
        return previous
    end
    return NotificationSemanticBinding(dispatcher, handlers, previous, active, execution)
end

function bind_notification_semantics!(
    dispatcher::SemanticDispatcher,
    manager::NotificationManager;
    id="notifications",
    newest_first::Bool=false,
    now_ns=nothing,
    replace::Bool=false,
)
    snapshots = notification_snapshots(manager; now_ns)
    ordered = newest_first ? reverse(snapshots) : snapshots
    return bind_notification_semantics!(
        dispatcher,
        manager,
        ordered;
        id,
        replace,
    )
end

register_managed_notification_view_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::ManagedNotificationView;
    newest_first::Bool=false,
    now_ns=nothing,
    replace::Bool=false,
) = bind_notification_semantics!(
    dispatcher,
    widget.manager;
    id,
    newest_first,
    now_ns,
    replace,
)

function register_notification_view_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::NotificationView,
)
    identifier = string(id)
    Accessibility.register_semantic_handler!(dispatcher, identifier, function (request)
        request.action in (FocusSemanticAction, SelectSemanticAction) ||
            return SemanticActionResult(false; message="unsupported notification action")
        return SemanticActionResult(true; value=copy(widget.center.notifications))
    end)
    for notification in widget.center.notifications
        node_id = "$(identifier)/notification/$(notification.id)"
        Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
            request.action == DismissSemanticAction ||
                return SemanticActionResult(false; message="unsupported notification action")
            dismissed = dismiss_notification!(widget.center, notification.id)
            return SemanticActionResult(
                dismissed;
                message=dismissed ? nothing : "notification is missing",
            )
        end)
    end
    return dispatcher
end

function unbind_notification_semantics!(binding::NotificationSemanticBinding)
    Base.Threads.atomic_cas!(binding.active, true, false) || return false
    lock(binding.mutex) do
        nothing
    end
    lock(binding.dispatcher.mutex) do
        updated = copy(binding.dispatcher.handlers)
        for (node_id, handler) in binding.handlers
            get(updated, node_id, nothing) === handler || continue
            previous = binding.previous[node_id]
            previous === nothing ? delete!(updated, node_id) : (updated[node_id] = previous)
        end
        binding.dispatcher.handlers = updated
    end
    return true
end
