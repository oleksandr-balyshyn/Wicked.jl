module DragDrop

using ..NavigationControls: ComponentRect

export DragEffect,
       NoDragEffect,
       CopyDragEffect,
       MoveDragEffect,
       LinkDragEffect,
       DragPoint,
       DragPayload,
       DropTarget,
       DragPhase,
       DragIdle,
       DragCandidate,
       Dragging,
       DragCompleted,
       DragCancelled,
       DragEventKind,
       DragStartedEvent,
       DragMovedEvent,
       DragEnteredEvent,
       DragLeftEvent,
       DragDroppedEvent,
       DragCancelledEvent,
       DragEvent,
       DropResult,
       AutoScrollRequest,
       DragDropManager,
       register_drop_target!,
       unregister_drop_target!,
       update_drop_target!,
       begin_drag_candidate!,
       update_drag!,
       drop_drag!,
       cancel_drag!,
       take_drag_events!,
       drag_autoscroll_request,
       active_drop_target

@enum DragEffect begin
    NoDragEffect
    CopyDragEffect
    MoveDragEffect
    LinkDragEffect
end

struct DragPoint
    row::Int
    column::Int

    function DragPoint(row::Integer, column::Integer)
        row > 0 || throw(ArgumentError("drag row must be positive"))
        column > 0 || throw(ArgumentError("drag column must be positive"))
        new(Int(row), Int(column))
    end
end

struct DragPayload{T}
    value::T
    mime::String
    allowed_effects::Set{DragEffect}
    description::Union{Nothing,String}

    function DragPayload(
        value::T;
        mime::AbstractString="application/octet-stream",
        allowed_effects=(CopyDragEffect,),
        description::Union{Nothing,AbstractString}=nothing,
    ) where {T}
        effects = Set{DragEffect}(allowed_effects)
        delete!(effects, NoDragEffect)
        isempty(effects) && throw(ArgumentError("drag payload requires at least one effect"))
        new{T}(
            value,
            lowercase(strip(String(mime))),
            effects,
            description === nothing ? nothing : String(description),
        )
    end
end

mutable struct DropTarget
    id::String
    rect::ComponentRect
    accepted_mime_prefixes::Vector{String}
    accepted_effects::Set{DragEffect}
    preferred_effect::DragEffect
    priority::Int
    enabled::Bool

    function DropTarget(
        id,
        rect::ComponentRect;
        accepted_mime_prefixes=("",),
        accepted_effects=(CopyDragEffect, MoveDragEffect, LinkDragEffect),
        preferred_effect::DragEffect=CopyDragEffect,
        priority::Integer=0,
        enabled::Bool=true,
    )
        effects = Set{DragEffect}(accepted_effects)
        delete!(effects, NoDragEffect)
        isempty(effects) && throw(ArgumentError("drop target requires at least one accepted effect"))
        preferred_effect == NoDragEffect && throw(ArgumentError("NoDragEffect cannot be preferred"))
        preferred_effect in effects || throw(ArgumentError("preferred drag effect is not accepted"))
        new(
            string(id),
            rect,
            String[lowercase(String(prefix)) for prefix in accepted_mime_prefixes],
            effects,
            preferred_effect,
            Int(priority),
            enabled,
        )
    end
end

@enum DragPhase begin
    DragIdle
    DragCandidate
    Dragging
    DragCompleted
    DragCancelled
end

@enum DragEventKind begin
    DragStartedEvent
    DragMovedEvent
    DragEnteredEvent
    DragLeftEvent
    DragDroppedEvent
    DragCancelledEvent
end

struct DragEvent
    kind::DragEventKind
    point::DragPoint
    source_id::Union{Nothing,String}
    target_id::Union{Nothing,String}
    effect::DragEffect
end

struct DropResult
    accepted::Bool
    source_id::Union{Nothing,String}
    target_id::Union{Nothing,String}
    effect::DragEffect
    payload::Any
end

struct AutoScrollRequest
    target_id::String
    vertical::Int
    horizontal::Int
end

mutable struct DragDropManager
    phase::DragPhase
    source_id::Union{Nothing,String}
    payload::Any
    origin::Union{Nothing,DragPoint}
    current::Union{Nothing,DragPoint}
    targets::Dict{String,DropTarget}
    hovered_target::Union{Nothing,String}
    threshold::Int
    captured::Bool
    events::Vector{DragEvent}
    mutex::ReentrantLock

    function DragDropManager(; threshold::Integer=2)
        threshold >= 0 || throw(ArgumentError("drag threshold cannot be negative"))
        new(
            DragIdle,
            nothing,
            nothing,
            nothing,
            nothing,
            Dict{String,DropTarget}(),
            nothing,
            Int(threshold),
            false,
            DragEvent[],
            ReentrantLock(),
        )
    end
end

function register_drop_target!(manager::DragDropManager, target::DropTarget)
    lock(manager.mutex) do
        haskey(manager.targets, target.id) && throw(ArgumentError("duplicate drop target id: $(target.id)"))
        manager.targets[target.id] = target
    end
    return manager
end

function unregister_drop_target!(manager::DragDropManager, id)
    lock(manager.mutex) do
        identifier = string(id)
        pop!(manager.targets, identifier, nothing)
        manager.hovered_target == identifier && (manager.hovered_target = nothing)
    end
    return manager
end

function update_drop_target!(manager::DragDropManager, id, rect::ComponentRect; enabled=nothing)
    lock(manager.mutex) do
        target = get(manager.targets, string(id), nothing)
        target === nothing && throw(ArgumentError("unknown drop target: $id"))
        target.rect = rect
        enabled === nothing || (target.enabled = Bool(enabled))
    end
    return manager
end

function _reset_drag!(manager::DragDropManager, phase::DragPhase)
    manager.phase = phase
    manager.source_id = nothing
    manager.payload = nothing
    manager.origin = nothing
    manager.current = nothing
    manager.hovered_target = nothing
    manager.captured = false
    return manager
end

function begin_drag_candidate!(
    manager::DragDropManager,
    source_id,
    payload::DragPayload,
    point::DragPoint,
)
    lock(manager.mutex) do
        manager.phase in (DragIdle, DragCompleted, DragCancelled) ||
            throw(ArgumentError("a drag operation is already active"))
        manager.phase = DragCandidate
        manager.source_id = string(source_id)
        manager.payload = payload
        manager.origin = point
        manager.current = point
        manager.hovered_target = nothing
        manager.captured = true
    end
    return manager
end

function _contains(rect::ComponentRect, point::DragPoint)
    return rect.row <= point.row < rect.row + rect.height &&
           rect.column <= point.column < rect.column + rect.width
end

function _target_effect(target::DropTarget, payload::DragPayload)
    target.enabled || return NoDragEffect
    any(prefix -> startswith(payload.mime, prefix), target.accepted_mime_prefixes) || return NoDragEffect
    allowed = intersect(target.accepted_effects, payload.allowed_effects)
    isempty(allowed) && return NoDragEffect
    target.preferred_effect in allowed && return target.preferred_effect
    for effect in (CopyDragEffect, MoveDragEffect, LinkDragEffect)
        effect in allowed && return effect
    end
    return NoDragEffect
end

function _target_at(manager::DragDropManager, point::DragPoint)
    payload = manager.payload
    payload isa DragPayload || return nothing, NoDragEffect
    candidates = Tuple{DropTarget,DragEffect}[]
    for target in values(manager.targets)
        _contains(target.rect, point) || continue
        effect = _target_effect(target, payload)
        effect == NoDragEffect || push!(candidates, (target, effect))
    end
    isempty(candidates) && return nothing, NoDragEffect
    sort!(candidates; by=value -> (-value[1].priority, value[1].rect.width * value[1].rect.height, value[1].id))
    return first(candidates)
end

function _event!(manager, kind, point, target_id, effect)
    push!(manager.events, DragEvent(kind, point, manager.source_id, target_id, effect))
end

function update_drag!(manager::DragDropManager, point::DragPoint)
    return lock(manager.mutex) do
        manager.phase in (DragCandidate, Dragging) || return false
        manager.current = point
        if manager.phase == DragCandidate
            origin = manager.origin::DragPoint
            distance = abs(point.row - origin.row) + abs(point.column - origin.column)
            distance < manager.threshold && return false
            manager.phase = Dragging
            _event!(manager, DragStartedEvent, point, nothing, NoDragEffect)
        end
        target, effect = _target_at(manager, point)
        target_id = target === nothing ? nothing : target.id
        if manager.hovered_target != target_id
            manager.hovered_target === nothing ||
                _event!(manager, DragLeftEvent, point, manager.hovered_target, NoDragEffect)
            target_id === nothing || _event!(manager, DragEnteredEvent, point, target_id, effect)
            manager.hovered_target = target_id
        end
        _event!(manager, DragMovedEvent, point, target_id, effect)
        return true
    end
end

function drop_drag!(manager::DragDropManager, point::DragPoint)
    return lock(manager.mutex) do
        manager.phase == Dragging || begin
            _reset_drag!(manager, DragCancelled)
            return DropResult(false, nothing, nothing, NoDragEffect, nothing)
        end
        source_id = manager.source_id
        payload = manager.payload
        target, effect = _target_at(manager, point)
        target_id = target === nothing ? nothing : target.id
        accepted = target !== nothing && effect != NoDragEffect
        _event!(manager, accepted ? DragDroppedEvent : DragCancelledEvent, point, target_id, effect)
        result = DropResult(accepted, source_id, target_id, effect, payload)
        _reset_drag!(manager, accepted ? DragCompleted : DragCancelled)
        return result
    end
end

function cancel_drag!(manager::DragDropManager)
    lock(manager.mutex) do
        if manager.phase in (DragCandidate, Dragging)
            point = something(manager.current, manager.origin)
            point === nothing || _event!(manager, DragCancelledEvent, point, manager.hovered_target, NoDragEffect)
        end
        _reset_drag!(manager, DragCancelled)
    end
    return manager
end

function take_drag_events!(manager::DragDropManager)
    return lock(manager.mutex) do
        events = copy(manager.events)
        empty!(manager.events)
        return events
    end
end

active_drop_target(manager::DragDropManager) = lock(manager.mutex) do
    manager.hovered_target === nothing ? nothing : get(manager.targets, manager.hovered_target, nothing)
end

function drag_autoscroll_request(
    manager::DragDropManager;
    edge_size::Integer=2,
    maximum_speed::Integer=3,
)
    edge_size > 0 || throw(ArgumentError("autoscroll edge size must be positive"))
    maximum_speed > 0 || throw(ArgumentError("autoscroll speed must be positive"))
    return lock(manager.mutex) do
        manager.phase == Dragging || return nothing
        point = manager.current::DragPoint
        target = manager.hovered_target === nothing ? nothing : get(manager.targets, manager.hovered_target, nothing)
        target === nothing && return nothing
        rect = target.rect
        top_distance = point.row - rect.row
        bottom_distance = rect.row + rect.height - 1 - point.row
        left_distance = point.column - rect.column
        right_distance = rect.column + rect.width - 1 - point.column
        vertical = top_distance < edge_size ? -min(maximum_speed, edge_size - top_distance) :
                   bottom_distance < edge_size ? min(maximum_speed, edge_size - bottom_distance) : 0
        horizontal = left_distance < edge_size ? -min(maximum_speed, edge_size - left_distance) :
                     right_distance < edge_size ? min(maximum_speed, edge_size - right_distance) : 0
        vertical == 0 && horizontal == 0 && return nothing
        return AutoScrollRequest(target.id, vertical, horizontal)
    end
end

end
