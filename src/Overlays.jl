
@enum OverlayModality::UInt8 begin
    ModelessOverlay
    ModalOverlay
end

@enum OverlayPlacement::UInt8 begin
    OverlayCenter
    OverlayFullscreen
    OverlayTopLeft
    OverlayTop
    OverlayTopRight
    OverlayRight
    OverlayBottomRight
    OverlayBottom
    OverlayBottomLeft
    OverlayLeft
    OverlayAnchor
end

@enum OverlayDismissReason::UInt8 begin
    OverlayClosed
    OverlayEscaped
    OverlayBlurred
    OverlayReplaced
    OverlayGroupReplaced
    OverlayShutdown
end

"""Behavioral and placement policy for one overlay."""
struct OverlayOptions
    modality::OverlayModality
    placement::OverlayPlacement
    dismiss_on_escape::Bool
    dismiss_on_blur::Bool
    trap_focus::Bool
    restore_focus::Bool
    priority::Int
    group::Union{Nothing,Symbol}
    exclusive::Bool

    function OverlayOptions(
        modality::OverlayModality,
        placement::OverlayPlacement,
        dismiss_on_escape::Bool,
        dismiss_on_blur::Bool,
        trap_focus::Bool,
        restore_focus::Bool,
        priority::Int,
        group::Union{Nothing,Symbol},
        exclusive::Bool,
    )
        exclusive && group === nothing &&
            throw(ArgumentError("an exclusive overlay requires a group"))
        return new(
            modality,
            placement,
            dismiss_on_escape,
            dismiss_on_blur,
            trap_focus,
            restore_focus,
            priority,
            group,
            exclusive,
        )
    end
end

function OverlayOptions(;
    modality::OverlayModality=ModelessOverlay,
    placement::OverlayPlacement=OverlayCenter,
    dismiss_on_escape::Bool=true,
    dismiss_on_blur::Bool=false,
    trap_focus::Bool=modality == ModalOverlay,
    restore_focus::Bool=true,
    priority::Integer=0,
    group::Union{Nothing,Symbol}=nothing,
    exclusive::Bool=false,
)
    return OverlayOptions(
        modality,
        placement,
        dismiss_on_escape,
        dismiss_on_blur,
        trap_focus,
        restore_focus,
        Int(priority),
        group,
        exclusive,
    )
end

"""Stable identity returned by `open_overlay!`. Handles are local to a manager."""
struct OverlayHandle
    id::UInt64
end

Base.show(io::IO, handle::OverlayHandle) = print(io, "OverlayHandle(", handle.id, ")")

"""Immutable public snapshot of an overlay registered with a manager."""
struct OverlayRecord{T}
    handle::OverlayHandle
    content::T
    options::OverlayOptions
    focus_restore_token::Any
    sequence::UInt64
end

"""
Owns overlay ordering and dismissal state.

Close callbacks run after state is committed and outside the manager lock. Callback
failures are captured and can be drained with `take_overlay_errors!`.
"""
mutable struct OverlayManager{T}
    entries::Vector{OverlayRecord{T}}
    close_callbacks::Dict{OverlayHandle,Any}
    errors::Vector{CapturedException}
    sequence::UInt64
    mutex::ReentrantLock
end

OverlayManager{T}() where {T} = OverlayManager{T}(
    OverlayRecord{T}[],
    Dict{OverlayHandle,Any}(),
    CapturedException[],
    UInt64(0),
    ReentrantLock(),
)

OverlayManager() = OverlayManager{Any}()

function _next_overlay_handle(manager::OverlayManager)
    manager.sequence == typemax(UInt64) &&
        throw(OverflowError("overlay handle sequence exhausted"))
    return OverlayHandle(manager.sequence + UInt64(1))
end

function _ordered_overlays(entries; reverse::Bool=false)
    return sort(copy(entries); by=record -> (record.options.priority, record.sequence), rev=reverse)
end

function _capture_overlay_callback!(manager::OverlayManager, callback, record, reason)
    try
        callback(record, reason)
    catch error
        captured = CapturedException(error, catch_backtrace())
        lock(manager.mutex) do
            push!(manager.errors, captured)
        end
    end
    return nothing
end

function _partition_overlays(manager::OverlayManager{T}, predicate) where {T}
    records = OverlayRecord{T}[record for record in manager.entries if predicate(record)]
    handles = Set(record.handle for record in records)
    entries = OverlayRecord{T}[
        record for record in manager.entries if !(record.handle in handles)
    ]
    callbacks = copy(manager.close_callbacks)
    ordered = _ordered_overlays(records; reverse=true)
    removed = Tuple{OverlayRecord{T},Any}[
        (record, callbacks[record.handle]) for record in ordered
    ]
    for handle in handles
        delete!(callbacks, handle)
    end
    return entries, callbacks, removed
end

function _take_overlays!(manager::OverlayManager{T}, predicate) where {T}
    entries, callbacks, removed = _partition_overlays(manager, predicate)
    manager.entries = entries
    manager.close_callbacks = callbacks
    return removed
end

"""
Register content as an overlay and return its stable handle.

When `options.exclusive` is true, existing overlays in the same group are closed
before the new record becomes observable. Their callbacks receive
`OverlayGroupReplaced`.
"""
function open_overlay!(
    manager::OverlayManager{T},
    content::T;
    options::OverlayOptions=OverlayOptions(),
    focus_restore_token=nothing,
    on_close=(record, reason) -> nothing,
) where {T}
    record, replaced = lock(manager.mutex) do
        handle = _next_overlay_handle(manager)
        record = OverlayRecord{T}(handle, content, options, focus_restore_token, handle.id)
        applicable(on_close, record, OverlayClosed) ||
            throw(ArgumentError("overlay close callback must accept a record and reason"))
        entries, callbacks, replaced = if options.exclusive
            _partition_overlays(manager, candidate -> candidate.options.group == options.group)
        else
            copy(manager.entries), copy(manager.close_callbacks), Tuple{OverlayRecord{T},Any}[]
        end
        push!(entries, record)
        callbacks[handle] = on_close
        manager.entries = entries
        manager.close_callbacks = callbacks
        manager.sequence = handle.id
        return record, replaced
    end
    for (old_record, callback) in replaced
        _capture_overlay_callback!(manager, callback, old_record, OverlayGroupReplaced)
    end
    return record.handle
end

function find_overlay(manager::OverlayManager, handle::OverlayHandle)
    return lock(manager.mutex) do
        index = findfirst(record -> record.handle == handle, manager.entries)
        index === nothing ? nothing : manager.entries[index]
    end
end

has_overlay(manager::OverlayManager, handle::OverlayHandle) = find_overlay(manager, handle) !== nothing

overlay_count(manager::OverlayManager) = lock(manager.mutex) do
    length(manager.entries)
end

Base.isempty(manager::OverlayManager) = overlay_count(manager) == 0

"""Return all overlays in paint order, from lowest to highest."""
overlay_entries(manager::OverlayManager) = lock(manager.mutex) do
    _ordered_overlays(manager.entries)
end

"""
Return overlays eligible for input routing.

The highest modal overlay forms a barrier: entries below it remain paintable but
are excluded from the returned input-routing slice.
"""
function active_overlay_entries(manager::OverlayManager)
    records = overlay_entries(manager)
    barrier = findlast(record -> record.options.modality == ModalOverlay, records)
    return barrier === nothing ? records : records[barrier:end]
end

function top_overlay(manager::OverlayManager)
    records = overlay_entries(manager)
    return isempty(records) ? nothing : records[end]
end

function replace_overlay!(manager::OverlayManager{T}, handle::OverlayHandle, content::T) where {T}
    return lock(manager.mutex) do
        index = findfirst(record -> record.handle == handle, manager.entries)
        index === nothing && return false
        record = manager.entries[index]
        manager.entries[index] = OverlayRecord(
            record.handle,
            content,
            record.options,
            record.focus_restore_token,
            record.sequence,
        )
        return true
    end
end

function configure_overlay!(
    manager::OverlayManager{T},
    handle::OverlayHandle,
    options::OverlayOptions,
) where {T}
    configured, replaced = lock(manager.mutex) do
        index = findfirst(record -> record.handle == handle, manager.entries)
        index === nothing && return false, Tuple{OverlayRecord{T},Any}[]
        record = manager.entries[index]
        entries, callbacks, replaced = if options.exclusive
            _partition_overlays(
                manager,
                candidate -> candidate.handle != handle &&
                    candidate.options.group == options.group,
            )
        else
            copy(manager.entries), copy(manager.close_callbacks), Tuple{OverlayRecord{T},Any}[]
        end
        updated_index = findfirst(candidate -> candidate.handle == handle, entries)
        entries[updated_index] = OverlayRecord(
            record.handle,
            record.content,
            options,
            record.focus_restore_token,
            record.sequence,
        )
        manager.entries = entries
        manager.close_callbacks = callbacks
        return true, replaced
    end
    for (record, callback) in replaced
        _capture_overlay_callback!(manager, callback, record, OverlayGroupReplaced)
    end
    return configured
end

function close_overlay!(
    manager::OverlayManager,
    handle::OverlayHandle;
    reason::OverlayDismissReason=OverlayClosed,
)
    removed = lock(manager.mutex) do
        index = findfirst(record -> record.handle == handle, manager.entries)
        index === nothing && return nothing
        record = manager.entries[index]
        callback = manager.close_callbacks[handle]
        splice!(manager.entries, index)
        delete!(manager.close_callbacks, handle)
        return record, callback
    end
    removed === nothing && return false
    record, callback = removed
    _capture_overlay_callback!(manager, callback, record, reason)
    return true
end

function close_overlay_group!(
    manager::OverlayManager,
    group::Symbol;
    reason::OverlayDismissReason=OverlayClosed,
)
    removed = lock(manager.mutex) do
        _take_overlays!(manager, record -> record.options.group == group)
    end
    for (record, callback) in removed
        _capture_overlay_callback!(manager, callback, record, reason)
    end
    return length(removed)
end

function close_all_overlays!(
    manager::OverlayManager;
    reason::OverlayDismissReason=OverlayShutdown,
)
    removed = lock(manager.mutex) do
        _take_overlays!(manager, record -> true)
    end
    for (record, callback) in removed
        _capture_overlay_callback!(manager, callback, record, reason)
    end
    return length(removed)
end

function dismiss_overlay_on_escape!(manager::OverlayManager)
    record = top_overlay(manager)
    record === nothing && return false
    record.options.dismiss_on_escape || return false
    return close_overlay!(manager, record.handle; reason=OverlayEscaped)
end

function dismiss_overlay_on_blur!(manager::OverlayManager, handle::OverlayHandle)
    record = find_overlay(manager, handle)
    record === nothing && return false
    record.options.dismiss_on_blur || return false
    return close_overlay!(manager, handle; reason=OverlayBlurred)
end

overlay_errors(manager::OverlayManager) = lock(manager.mutex) do
    copy(manager.errors)
end

function take_overlay_errors!(manager::OverlayManager)
    return lock(manager.mutex) do
        errors = copy(manager.errors)
        empty!(manager.errors)
        errors
    end
end
