
linear_easing(value::Real) = Float64(value)
ease_in_quad(value::Real) = Float64(value)^2
ease_out_quad(value::Real) = 1.0 - (1.0 - Float64(value))^2

function ease_in_out_quad(value::Real)
    progress = Float64(value)
    return progress < 0.5 ? 2.0 * progress^2 : 1.0 - (-2.0 * progress + 2.0)^2 / 2.0
end

ease_in_cubic(value::Real) = Float64(value)^3
ease_out_cubic(value::Real) = 1.0 - (1.0 - Float64(value))^3

function ease_in_out_cubic(value::Real)
    progress = Float64(value)
    return progress < 0.5 ? 4.0 * progress^3 : 1.0 - (-2.0 * progress + 2.0)^3 / 2.0
end

function ease_out_back(value::Real)
    progress = Float64(value)
    c1 = 1.70158
    c3 = c1 + 1.0
    return 1.0 + c3 * (progress - 1.0)^3 + c1 * (progress - 1.0)^2
end

interpolate_value(from::Bool, to::Bool, progress::Real) = progress < 1 ? from : to

function interpolate_value(from::T, to::T, progress::Real) where {T<:Integer}
    position = Float64(progress)
    position == 0.0 && return from
    position == 1.0 && return to
    value = muladd(Float64(to) - Float64(from), position, Float64(from))
    isfinite(value) || throw(OverflowError("integer interpolation produced a non-finite value"))
    return round(T, value)
end

function interpolate_value(from::Real, to::Real, progress::Real)
    return from + (to - from) * Float64(progress)
end

function interpolate_value(from::Tuple, to::Tuple, progress::Real)
    length(from) == length(to) || throw(DimensionMismatch("tuple interpolation requires equal lengths"))
    return map((left, right) -> interpolate_value(left, right, progress), from, to)
end

function interpolate_value(from::AbstractVector, to::AbstractVector, progress::Real)
    axes(from) == axes(to) || throw(DimensionMismatch("vector interpolation requires equal axes"))
    return map((left, right) -> interpolate_value(left, right, progress), from, to)
end

interpolate_value(from, to, progress::Real) = progress < 1 ? from : to

struct Keyframe{T}
    offset::Float64
    value::T
    easing::Any

    function Keyframe(offset::Real, value::T; easing=linear_easing) where {T}
        resolved = Float64(offset)
        isfinite(resolved) && 0.0 <= resolved <= 1.0 ||
            throw(ArgumentError("keyframe offset must be finite and between zero and one"))
        applicable(easing, 0.5) ||
            throw(ArgumentError("keyframe easing must accept a progress value"))
        return new{T}(resolved, value, easing)
    end
end

struct AnimationTrack{T}
    keyframes::Vector{Keyframe{T}}
    offsets::Vector{Float64}
    interpolation::Any

    function AnimationTrack(
        keyframes::AbstractVector{<:Keyframe{T}};
        interpolation=interpolate_value,
    ) where {T}
        resolved = Keyframe{T}[frame for frame in keyframes]
        length(resolved) >= 2 || throw(ArgumentError("an animation track requires at least two keyframes"))
        first(resolved).offset == 0.0 || throw(ArgumentError("the first keyframe must start at zero"))
        last(resolved).offset == 1.0 || throw(ArgumentError("the last keyframe must end at one"))
        for index in 2:length(resolved)
            resolved[index - 1].offset < resolved[index].offset ||
                throw(ArgumentError("keyframe offsets must be strictly increasing"))
        end
        applicable(interpolation, first(resolved).value, last(resolved).value, 0.5) ||
            throw(ArgumentError("track interpolation must accept two values and progress"))
        return new{T}(resolved, [frame.offset for frame in resolved], interpolation)
    end
end

AnimationTrack(from::T, to::T; easing=linear_easing, interpolation=interpolate_value) where {T} =
    AnimationTrack(
        Keyframe{T}[
            Keyframe(0.0, from; easing),
            Keyframe(1.0, to),
        ];
        interpolation,
    )

function sample_animation(track::AnimationTrack, progress::Real)
    position = clamp(Float64(progress), 0.0, 1.0)
    position == 1.0 && return last(track.keyframes).value
    index = searchsortedlast(track.offsets, position)
    index = clamp(index, 1, length(track.keyframes) - 1)
    left = track.keyframes[index]
    right = track.keyframes[index + 1]
    local_progress = (position - left.offset) / (right.offset - left.offset)
    eased = left.easing(local_progress)
    eased isa Real && isfinite(eased) ||
        throw(ArgumentError("animation easing must return a finite real value"))
    return track.interpolation(left.value, right.value, Float64(eased))
end

@enum AnimationDirection::UInt8 begin
    ForwardAnimation
    ReverseAnimation
    AlternateAnimation
    AlternateReverseAnimation
end

@enum MotionPolicy::UInt8 begin
    FullMotion
    ReducedMotion
    DisabledMotion
end

@enum AnimationStatus::UInt8 begin
    PendingAnimation
    RunningAnimation
    PausedAnimation
    CompletedAnimation
    CancelledAnimation
end

@enum AnimationEndReason::UInt8 begin
    AnimationFinished
    AnimationCancelled
    AnimationReplaced
    AnimationFailed
end

struct AnimationHandle
    id::UInt64
end

Base.show(io::IO, handle::AnimationHandle) = print(io, "AnimationHandle(", handle.id, ")")

struct AnimationSpec{T}
    track::AnimationTrack{T}
    duration_ns::UInt64
    delay_ns::UInt64
    iterations::Union{Nothing,Int}
    direction::AnimationDirection
    key::Any
    essential::Bool
end

function _animation_nanoseconds(value::Real, name::AbstractString)
    seconds = Float64(value)
    isfinite(seconds) && seconds >= 0.0 ||
        throw(ArgumentError("$name must be finite and non-negative"))
    nanoseconds = seconds * 1.0e9
    nanoseconds <= typemax(UInt64) || throw(OverflowError("$name is too large"))
    return round(UInt64, nanoseconds)
end

function AnimationSpec(
    track::AnimationTrack{T};
    duration::Real=0.25,
    delay::Real=0.0,
    iterations::Union{Nothing,Integer}=1,
    direction::AnimationDirection=ForwardAnimation,
    key=nothing,
    essential::Bool=false,
) where {T}
    resolved_duration = _animation_nanoseconds(duration, "animation duration")
    resolved_delay = _animation_nanoseconds(delay, "animation delay")
    resolved_iterations = iterations === nothing ? nothing : Int(iterations)
    resolved_iterations !== nothing && resolved_iterations < 1 &&
        throw(ArgumentError("animation iterations must be positive or nothing"))
    resolved_iterations === nothing && resolved_duration == 0 &&
        throw(ArgumentError("an infinite animation must have a positive duration"))
    return AnimationSpec{T}(
        track,
        resolved_duration,
        resolved_delay,
        resolved_iterations,
        direction,
        key,
        essential,
    )
end

struct AnimationUpdate
    handle::AnimationHandle
    key::Any
    value::Any
    progress::Float64
    iteration::UInt64
    status::AnimationStatus
end

struct _AnimationEntry
    handle::AnimationHandle
    spec::AnimationSpec
    started_ns::UInt64
    duration_ns::UInt64
    delay_ns::UInt64
    reduced::Bool
    status::AnimationStatus
    paused_at_ns::UInt64
    last_value::Any
    on_update::Any
    on_finish::Any
    revision::UInt64
end

mutable struct AnimationManager
    entries::Dict{AnimationHandle,_AnimationEntry}
    keyed::Dict{Any,AnimationHandle}
    errors::Vector{CapturedException}
    sequence::UInt64
    policy::MotionPolicy
    reduced_duration_ns::UInt64
    clock::Any
    mutex::ReentrantLock
end

function AnimationManager(;
    policy::MotionPolicy=FullMotion,
    reduced_duration::Real=0.05,
    clock=time_ns,
)
    applicable(clock) || throw(ArgumentError("animation clock must be callable without arguments"))
    return AnimationManager(
        Dict{AnimationHandle,_AnimationEntry}(),
        Dict{Any,AnimationHandle}(),
        CapturedException[],
        UInt64(0),
        policy,
        _animation_nanoseconds(reduced_duration, "reduced motion duration"),
        clock,
        ReentrantLock(),
    )
end

function _animation_now(manager::AnimationManager)
    value = manager.clock()
    value isa Integer && value >= 0 ||
        throw(ArgumentError("animation clock must return a non-negative integer"))
    return UInt64(value)
end

function _next_animation_handle(manager::AnimationManager)
    manager.sequence == typemax(UInt64) && throw(OverflowError("animation handle sequence exhausted"))
    return AnimationHandle(manager.sequence + UInt64(1))
end

function _directed_progress(direction::AnimationDirection, iteration::UInt64, progress::Float64)
    direction == ForwardAnimation && return progress
    direction == ReverseAnimation && return 1.0 - progress
    direction == AlternateAnimation && return iseven(iteration) ? progress : 1.0 - progress
    return iseven(iteration) ? 1.0 - progress : progress
end

function _terminal_iteration(spec::AnimationSpec)
    return spec.iterations === nothing ? UInt64(0) : UInt64(spec.iterations - 1)
end

function _terminal_progress(spec::AnimationSpec)
    return _directed_progress(spec.direction, _terminal_iteration(spec), 1.0)
end

function _capture_animation_error!(manager::AnimationManager, error, backtrace)
    lock(manager.mutex) do
        push!(manager.errors, CapturedException(error, backtrace))
    end
    return nothing
end

function _invoke_animation_callback!(manager::AnimationManager, callback, arguments...)
    try
        callback(arguments...)
    catch error
        _capture_animation_error!(manager, error, catch_backtrace())
    end
    return nothing
end

function _remove_animation_locked!(manager::AnimationManager, handle::AnimationHandle)
    entry = pop!(manager.entries, handle, nothing)
    entry === nothing && return nothing
    if entry.spec.key !== nothing && get(manager.keyed, entry.spec.key, nothing) == handle
        delete!(manager.keyed, entry.spec.key)
    end
    return entry
end

function animate!(
    manager::AnimationManager,
    spec::AnimationSpec;
    on_update=value -> nothing,
    on_finish=(handle, reason, value) -> nothing,
    now_ns=nothing,
)
    initial_progress = _directed_progress(spec.direction, UInt64(0), 0.0)
    initial = sample_animation(spec.track, initial_progress)
    terminal = sample_animation(spec.track, _terminal_progress(spec))
    applicable(on_update, initial) ||
        throw(ArgumentError("animation update callback must accept a value"))
    applicable(on_finish, AnimationHandle(0), AnimationFinished, terminal) ||
        throw(ArgumentError("animation finish callback must accept handle, reason, and value"))
    now = now_ns === nothing ? _animation_now(manager) : UInt64(now_ns)
    handle, replaced, immediate = lock(manager.mutex) do
        handle = _next_animation_handle(manager)
        immediate = manager.policy == DisabledMotion && !spec.essential
        reduced = manager.policy == ReducedMotion && !spec.essential
        duration = reduced ? min(spec.duration_ns, manager.reduced_duration_ns) : spec.duration_ns
        delay = reduced ? min(spec.delay_ns, manager.reduced_duration_ns) : spec.delay_ns
        entry = _AnimationEntry(
            handle,
            spec,
            now,
            duration,
            delay,
            reduced,
            delay == 0 ? RunningAnimation : PendingAnimation,
            UInt64(0),
            initial,
            on_update,
            on_finish,
            UInt64(0),
        )
        entries = copy(manager.entries)
        keyed = copy(manager.keyed)
        replaced = nothing
        if spec.key !== nothing
            previous_handle = get(keyed, spec.key, nothing)
            if previous_handle !== nothing
                replaced = entries[previous_handle]
                delete!(entries, previous_handle)
                delete!(keyed, spec.key)
            end
        end
        if !immediate
            entries[handle] = entry
            spec.key !== nothing && (keyed[spec.key] = handle)
        end
        manager.entries = entries
        manager.keyed = keyed
        manager.sequence = handle.id
        return handle, replaced, immediate
    end
    replaced !== nothing && _invoke_animation_callback!(
        manager,
        replaced.on_finish,
        replaced.handle,
        AnimationReplaced,
        replaced.last_value,
    )
    if immediate
        _invoke_animation_callback!(manager, on_update, terminal)
        _invoke_animation_callback!(manager, on_finish, handle, AnimationFinished, terminal)
    end
    return handle
end

function _sample_animation_entry(entry::_AnimationEntry, now::UInt64)
    elapsed = now >= entry.started_ns ? now - entry.started_ns : UInt64(0)
    elapsed < entry.delay_ns && return (
        entry.last_value,
        0.0,
        UInt64(0),
        PendingAnimation,
        false,
    )
    active = elapsed - entry.delay_ns
    if entry.duration_ns == 0
        progress = _terminal_progress(entry.spec)
        return sample_animation(entry.spec.track, progress), progress, UInt64(0), CompletedAnimation, true
    end
    iteration = active ÷ entry.duration_ns
    if entry.reduced
        completed = iteration >= UInt64(1)
        raw = completed ? 1.0 : Float64(active % entry.duration_ns) / Float64(entry.duration_ns)
        start = _directed_progress(entry.spec.direction, UInt64(0), 0.0)
        terminal = _terminal_progress(entry.spec)
        progress = start + (terminal - start) * raw
        return sample_animation(entry.spec.track, progress), progress, UInt64(0),
            completed ? CompletedAnimation : RunningAnimation, completed
    end
    if entry.spec.iterations !== nothing && iteration >= UInt64(entry.spec.iterations)
        final_iteration = UInt64(entry.spec.iterations - 1)
        progress = _directed_progress(entry.spec.direction, final_iteration, 1.0)
        return sample_animation(entry.spec.track, progress), progress, final_iteration,
            CompletedAnimation, true
    end
    raw = Float64(active % entry.duration_ns) / Float64(entry.duration_ns)
    progress = _directed_progress(entry.spec.direction, iteration, raw)
    return sample_animation(entry.spec.track, progress), progress, iteration, RunningAnimation, false
end

function tick_animations!(manager::AnimationManager; now_ns=nothing)
    now = now_ns === nothing ? _animation_now(manager) : UInt64(now_ns)
    snapshots = lock(manager.mutex) do
        sort!(collect(values(manager.entries)); by=entry -> entry.handle.id)
    end
    updates = AnimationUpdate[]
    for snapshot in snapshots
        snapshot.status == PausedAnimation && continue
        sample = try
            _sample_animation_entry(snapshot, now)
        catch error
            backtrace = catch_backtrace()
            removed = lock(manager.mutex) do
                current = get(manager.entries, snapshot.handle, nothing)
                current !== nothing && current.revision == snapshot.revision ?
                    _remove_animation_locked!(manager, snapshot.handle) : nothing
            end
            if removed !== nothing
                _capture_animation_error!(manager, error, backtrace)
                _invoke_animation_callback!(
                    manager,
                    removed.on_finish,
                    removed.handle,
                    AnimationFailed,
                    removed.last_value,
                )
            end
            continue
        end
        value, progress, iteration, status, completed = sample
        committed = lock(manager.mutex) do
            current = get(manager.entries, snapshot.handle, nothing)
            current !== nothing && current.revision == snapshot.revision || return false
            if completed
                _remove_animation_locked!(manager, snapshot.handle)
            else
                snapshot.revision == typemax(UInt64) &&
                    throw(OverflowError("animation entry revision exhausted"))
                manager.entries[snapshot.handle] = _AnimationEntry(
                    snapshot.handle,
                    snapshot.spec,
                    snapshot.started_ns,
                    snapshot.duration_ns,
                    snapshot.delay_ns,
                    snapshot.reduced,
                    status,
                    snapshot.paused_at_ns,
                    value,
                    snapshot.on_update,
                    snapshot.on_finish,
                    snapshot.revision + UInt64(1),
                )
            end
            return true
        end
        committed || continue
        update = AnimationUpdate(snapshot.handle, snapshot.spec.key, value, progress, iteration, status)
        push!(updates, update)
        _invoke_animation_callback!(manager, snapshot.on_update, value)
        completed && _invoke_animation_callback!(
            manager,
            snapshot.on_finish,
            snapshot.handle,
            AnimationFinished,
            value,
        )
    end
    return updates
end

function pause_animation!(manager::AnimationManager, handle::AnimationHandle; now_ns=nothing)
    now = now_ns === nothing ? _animation_now(manager) : UInt64(now_ns)
    return lock(manager.mutex) do
        entry = get(manager.entries, handle, nothing)
        entry === nothing && return false
        entry.status == PausedAnimation && return false
        entry.revision == typemax(UInt64) && throw(OverflowError("animation entry revision exhausted"))
        manager.entries[handle] = _AnimationEntry(
            entry.handle,
            entry.spec,
            entry.started_ns,
            entry.duration_ns,
            entry.delay_ns,
            entry.reduced,
            PausedAnimation,
            now,
            entry.last_value,
            entry.on_update,
            entry.on_finish,
            entry.revision + UInt64(1),
        )
        return true
    end
end

function resume_animation!(manager::AnimationManager, handle::AnimationHandle; now_ns=nothing)
    now = now_ns === nothing ? _animation_now(manager) : UInt64(now_ns)
    return lock(manager.mutex) do
        entry = get(manager.entries, handle, nothing)
        entry === nothing && return false
        entry.status == PausedAnimation || return false
        paused = now >= entry.paused_at_ns ? now - entry.paused_at_ns : UInt64(0)
        entry.started_ns <= typemax(UInt64) - paused ||
            throw(OverflowError("animation resume time overflow"))
        entry.revision == typemax(UInt64) && throw(OverflowError("animation entry revision exhausted"))
        started = entry.started_ns + paused
        elapsed = now >= started ? now - started : UInt64(0)
        status = elapsed < entry.delay_ns ? PendingAnimation : RunningAnimation
        manager.entries[handle] = _AnimationEntry(
            entry.handle,
            entry.spec,
            started,
            entry.duration_ns,
            entry.delay_ns,
            entry.reduced,
            status,
            UInt64(0),
            entry.last_value,
            entry.on_update,
            entry.on_finish,
            entry.revision + UInt64(1),
        )
        return true
    end
end

function cancel_animation!(manager::AnimationManager, handle::AnimationHandle)
    entry = lock(manager.mutex) do
        _remove_animation_locked!(manager, handle)
    end
    entry === nothing && return false
    _invoke_animation_callback!(
        manager,
        entry.on_finish,
        entry.handle,
        AnimationCancelled,
        entry.last_value,
    )
    return true
end

function cancel_animation_key!(manager::AnimationManager, key)
    handle = lock(manager.mutex) do
        get(manager.keyed, key, nothing)
    end
    return handle === nothing ? false : cancel_animation!(manager, handle)
end

animation_status(manager::AnimationManager, handle::AnimationHandle) = lock(manager.mutex) do
    entry = get(manager.entries, handle, nothing)
    entry === nothing ? nothing : entry.status
end

active_animation_handles(manager::AnimationManager) = lock(manager.mutex) do
    sort!(collect(keys(manager.entries)); by=handle -> handle.id)
end

function set_motion_policy!(manager::AnimationManager, policy::MotionPolicy)
    lock(manager.mutex) do
        manager.policy = policy
    end
    return manager
end

animation_errors(manager::AnimationManager) = lock(manager.mutex) do
    copy(manager.errors)
end

function take_animation_errors!(manager::AnimationManager)
    return lock(manager.mutex) do
        errors = copy(manager.errors)
        empty!(manager.errors)
        errors
    end
end
