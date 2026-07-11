
@enum ReloadMissingPolicy::UInt8 begin
    IgnoreMissingFiles
    WaitForMissingFiles
    FailOnMissingFiles
end

@enum ReloadState::UInt8 begin
    WatchingReload
    PendingReload
    LoadingReload
    ApplyingReload
    DisabledReload
end

@enum ReloadOutcome::UInt8 begin
    ReloadApplied
    ReloadFailed
    ReloadMissing
end

struct FileFingerprint
    exists::Bool
    size::Int64
    modified::Float64
end

struct ReloadEvent
    id::Symbol
    outcome::ReloadOutcome
    paths::Vector{String}
    value::Any
    error::Union{Nothing,CapturedException}
    timestamp_ns::UInt64
end

mutable struct _ReloadTarget
    id::Symbol
    paths::Vector{String}
    loader::Any
    apply::Any
    debounce_ns::UInt64
    missing_policy::ReloadMissingPolicy
    state::ReloadState
    observed::Union{Nothing,Vector{FileFingerprint}}
    pending_since_ns::UInt64
    pending_fingerprint::Union{Nothing,Vector{FileFingerprint}}
    applied::Union{Nothing,Vector{FileFingerprint}}
    force::Bool
    revision::UInt64
end

mutable struct LiveReloadManager
    targets::Dict{Symbol,_ReloadTarget}
    events::Vector{ReloadEvent}
    errors::Vector{CapturedException}
    clock::Any
    polling::Bool
    mutex::ReentrantLock
end

function LiveReloadManager(; clock=time_ns)
    applicable(clock) || throw(ArgumentError("reload clock must be callable without arguments"))
    return LiveReloadManager(
        Dict{Symbol,_ReloadTarget}(),
        ReloadEvent[],
        CapturedException[],
        clock,
        false,
        ReentrantLock(),
    )
end

function _reload_now(manager::LiveReloadManager)
    value = manager.clock()
    value isa Integer && value >= 0 ||
        throw(ArgumentError("reload clock must return a non-negative integer"))
    return UInt64(value)
end

function _reload_nanoseconds(value::Real)
    seconds = Float64(value)
    isfinite(seconds) && seconds >= 0.0 ||
        throw(ArgumentError("reload debounce must be finite and non-negative"))
    nanoseconds = seconds * 1.0e9
    nanoseconds <= typemax(UInt64) || throw(OverflowError("reload debounce is too large"))
    return round(UInt64, nanoseconds)
end

function _reload_paths(paths)
    source = paths isa AbstractString ? (paths,) : paths
    resolved = unique!(String[
        abspath(normpath(String(path))) for path in source
    ])
    isempty(resolved) && throw(ArgumentError("a reload target requires at least one path"))
    sort!(resolved)
    return resolved
end

function _file_fingerprint(path::AbstractString)
    isfile(path) || return FileFingerprint(false, Int64(0), 0.0)
    information = stat(path)
    return FileFingerprint(true, Int64(information.size), Float64(information.mtime))
end

_reload_fingerprint(paths) = FileFingerprint[_file_fingerprint(path) for path in paths]

_has_missing_file(fingerprint) = any(item -> !item.exists, fingerprint)

function _default_reload_loader(paths)
    length(paths) == 1 && return read(only(paths), String)
    return Dict(path => read(path, String) for path in paths)
end

function _next_reload_revision(target::_ReloadTarget)
    target.revision == typemax(UInt64) && throw(OverflowError("reload target revision exhausted"))
    return target.revision + UInt64(1)
end

function register_reload_target!(
    manager::LiveReloadManager,
    id::Symbol,
    paths;
    loader=_default_reload_loader,
    apply=value -> nothing,
    debounce::Real=0.1,
    missing_policy::ReloadMissingPolicy=WaitForMissingFiles,
    enabled::Bool=true,
    load_initial::Bool=false,
    replace::Bool=false,
)
    resolved_paths = _reload_paths(paths)
    applicable(loader, resolved_paths) ||
        throw(ArgumentError("reload loader must accept a vector of paths"))
    fingerprint = load_initial ? nothing : _reload_fingerprint(resolved_paths)
    target = _ReloadTarget(
        id,
        resolved_paths,
        loader,
        apply,
        _reload_nanoseconds(debounce),
        missing_policy,
        enabled ? WatchingReload : DisabledReload,
        fingerprint,
        UInt64(0),
        nothing,
        nothing,
        load_initial,
        UInt64(0),
    )
    lock(manager.mutex) do
        existing = get(manager.targets, id, nothing)
        existing !== nothing && !replace &&
            throw(ArgumentError("reload target is already registered: $id"))
        existing !== nothing && existing.state in (LoadingReload, ApplyingReload) &&
            throw(InvalidStateException("cannot replace an active reload target", :active))
        targets = copy(manager.targets)
        targets[id] = target
        manager.targets = targets
    end
    return manager
end

function unregister_reload_target!(manager::LiveReloadManager, id::Symbol)
    return lock(manager.mutex) do
        target = get(manager.targets, id, nothing)
        target === nothing && return false
        target.state in (LoadingReload, ApplyingReload) &&
            throw(InvalidStateException("cannot unregister an active reload target", :active))
        targets = copy(manager.targets)
        delete!(targets, id)
        manager.targets = targets
        return true
    end
end

function set_reload_enabled!(manager::LiveReloadManager, id::Symbol, enabled::Bool)
    return lock(manager.mutex) do
        target = get(manager.targets, id, nothing)
        target === nothing && throw(KeyError(id))
        target.state in (LoadingReload, ApplyingReload) &&
            throw(InvalidStateException("cannot change an active reload target", :active))
        desired = enabled ? WatchingReload : DisabledReload
        target.state == desired && return false
        revision = _next_reload_revision(target)
        target.state = desired
        target.pending_fingerprint = nothing
        target.force = false
        target.revision = revision
        return true
    end
end

function trigger_reload!(manager::LiveReloadManager, id::Symbol)
    return lock(manager.mutex) do
        target = get(manager.targets, id, nothing)
        target === nothing && throw(KeyError(id))
        target.state == DisabledReload && return false
        target.state in (LoadingReload, ApplyingReload) && return false
        revision = _next_reload_revision(target)
        target.force = true
        target.state = PendingReload
        target.pending_since_ns = UInt64(0)
        target.pending_fingerprint = target.observed === nothing ?
            nothing : copy(target.observed)
        target.revision = revision
        return true
    end
end

function reload_target_state(manager::LiveReloadManager, id::Symbol)
    return lock(manager.mutex) do
        target = get(manager.targets, id, nothing)
        target === nothing ? nothing : target.state
    end
end

watched_reload_paths(manager::LiveReloadManager, id::Symbol) = lock(manager.mutex) do
    target = get(manager.targets, id, nothing)
    target === nothing ? nothing : copy(target.paths)
end

function _record_reload_event!(manager::LiveReloadManager, event::ReloadEvent)
    lock(manager.mutex) do
        push!(manager.events, event)
        event.error === nothing || push!(manager.errors, event.error)
    end
    return event
end

function _observe_reload_target!(
    manager::LiveReloadManager,
    id::Symbol,
    fingerprint::Vector{FileFingerprint},
    now::UInt64,
)
    return lock(manager.mutex) do
        target = get(manager.targets, id, nothing)
        target === nothing && return nothing
        target.state in (DisabledReload, LoadingReload, ApplyingReload) && return nothing
        changed = target.observed === nothing || target.observed != fingerprint
        if changed
            revision = _next_reload_revision(target)
            target.observed = fingerprint
            target.pending_fingerprint = fingerprint
            target.pending_since_ns = now
            target.state = PendingReload
            target.revision = revision
        end
        missing = _has_missing_file(fingerprint)
        if missing
            if target.missing_policy == IgnoreMissingFiles
                target.state = WatchingReload
                target.pending_fingerprint = nothing
                target.force = false
                return nothing
            elseif target.missing_policy == WaitForMissingFiles
                return nothing
            else
                target.state == PendingReload || return nothing
                revision = _next_reload_revision(target)
                target.state = WatchingReload
                target.pending_fingerprint = nothing
                target.force = false
                target.revision = revision
                return (:missing, copy(target.paths), target.revision)
            end
        end
        target.state == PendingReload || return nothing
        target.pending_fingerprint === nothing &&
            (target.pending_fingerprint = copy(fingerprint))
        elapsed = now >= target.pending_since_ns ? now - target.pending_since_ns : UInt64(0)
        (target.force || elapsed >= target.debounce_ns) || return nothing
        revision = _next_reload_revision(target)
        target.state = LoadingReload
        target.force = false
        target.revision = revision
        return (
            :load,
            copy(target.paths),
            target.loader,
            target.apply,
            copy(target.pending_fingerprint),
            target.revision,
        )
    end
end

function _fail_reload!(
    manager::LiveReloadManager,
    id::Symbol,
    revision::UInt64,
    paths,
    error,
    backtrace,
    now::UInt64;
    outcome::ReloadOutcome=ReloadFailed,
)
    captured = CapturedException(error, backtrace)
    committed = lock(manager.mutex) do
        target = get(manager.targets, id, nothing)
        target === nothing && return false
        target.revision == revision || return false
        next_revision = _next_reload_revision(target)
        target.state = WatchingReload
        target.pending_fingerprint = nothing
        target.revision = next_revision
        return true
    end
    committed || return nothing
    return _record_reload_event!(
        manager,
        ReloadEvent(id, outcome, copy(paths), nothing, captured, now),
    )
end

function _apply_reload!(manager::LiveReloadManager, id::Symbol, claim, now::UInt64)
    _, paths, loader, apply, fingerprint, revision = claim
    candidate = try
        loader(paths)
    catch error
        return _fail_reload!(manager, id, revision, paths, error, catch_backtrace(), now)
    end
    applicable(apply, candidate) || return _fail_reload!(
        manager,
        id,
        revision,
        paths,
        ArgumentError("reload apply callback must accept the loaded value"),
        backtrace(),
        now,
    )
    applying_revision = lock(manager.mutex) do
        target = get(manager.targets, id, nothing)
        target === nothing && return nothing
        target.revision == revision && target.state == LoadingReload || return nothing
        next_revision = _next_reload_revision(target)
        target.state = ApplyingReload
        target.revision = next_revision
        return next_revision
    end
    applying_revision === nothing && return nothing
    try
        apply(candidate)
    catch error
        return _fail_reload!(
            manager,
            id,
            applying_revision,
            paths,
            error,
            catch_backtrace(),
            now,
        )
    end
    committed = lock(manager.mutex) do
        target = get(manager.targets, id, nothing)
        target === nothing && return false
        target.revision == applying_revision && target.state == ApplyingReload || return false
        next_revision = _next_reload_revision(target)
        target.state = WatchingReload
        target.pending_fingerprint = nothing
        target.applied = fingerprint
        target.revision = next_revision
        return true
    end
    committed || return nothing
    return _record_reload_event!(
        manager,
        ReloadEvent(id, ReloadApplied, copy(paths), candidate, nothing, now),
    )
end

function poll_reloads!(manager::LiveReloadManager; now_ns=nothing)
    now = now_ns === nothing ? _reload_now(manager) : UInt64(now_ns)
    ids = lock(manager.mutex) do
        manager.polling && throw(InvalidStateException("reload polling is already active", :active))
        manager.polling = true
        sort!(collect(keys(manager.targets)); by=String)
    end
    produced = ReloadEvent[]
    try
        for id in ids
            paths = watched_reload_paths(manager, id)
            paths === nothing && continue
            fingerprint = try
                _reload_fingerprint(paths)
            catch error
                captured = CapturedException(error, catch_backtrace())
                event = ReloadEvent(id, ReloadFailed, paths, nothing, captured, now)
                _record_reload_event!(manager, event)
                push!(produced, event)
                continue
            end
            claim = _observe_reload_target!(manager, id, fingerprint, now)
            claim === nothing && continue
            if first(claim) == :missing
                _, missing_paths, revision = claim
                event = _fail_reload!(
                    manager,
                    id,
                    revision,
                    missing_paths,
                    SystemError("reload target contains a missing file", 0),
                    backtrace(),
                    now;
                    outcome=ReloadMissing,
                )
                event === nothing || push!(produced, event)
            else
                event = _apply_reload!(manager, id, claim, now)
                event === nothing || push!(produced, event)
            end
        end
    finally
        lock(manager.mutex) do
            manager.polling = false
        end
    end
    return produced
end

reload_events(manager::LiveReloadManager) = lock(manager.mutex) do
    copy(manager.events)
end

function take_reload_events!(manager::LiveReloadManager)
    return lock(manager.mutex) do
        events = copy(manager.events)
        empty!(manager.events)
        events
    end
end

reload_errors(manager::LiveReloadManager) = lock(manager.mutex) do
    copy(manager.errors)
end

function take_reload_errors!(manager::LiveReloadManager)
    return lock(manager.mutex) do
        errors = copy(manager.errors)
        empty!(manager.errors)
        errors
    end
end
