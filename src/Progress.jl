using .Core: AnsiColor,
             Buffer,
             Cell,
             CenterAlign,
             DIM,
             REVERSED,
             Rect,
             Style
import .Core: render!
using .Events: TickEvent
using .Widgets: Block, Label, _visual_area
import .Widgets: handle!


@enum ProgressTaskStatus::UInt8 begin
    RunningProgress
    PausedProgress
    CompletedProgress
    FailedProgress
    CancelledProgress
end

struct ProgressTask{K}
    id::K
    description::String
    total::Union{Nothing,Float64}
    completed::Float64
    status::ProgressTaskStatus
    started_ns::UInt64
    active_ns::UInt64
    segment_started_ns::UInt64
    updated_ns::UInt64
    finished_ns::UInt64
    error::Union{Nothing,String}
    metadata::Any
end

struct ProgressSnapshot{K}
    id::K
    description::String
    total::Union{Nothing,Float64}
    completed::Float64
    ratio::Union{Nothing,Float64}
    status::ProgressTaskStatus
    elapsed_seconds::Float64
    eta_seconds::Union{Nothing,Float64}
    error::Union{Nothing,String}
    metadata::Any
end

struct ProgressAggregate
    total_tasks::Int
    running_tasks::Int
    paused_tasks::Int
    completed_tasks::Int
    failed_tasks::Int
    cancelled_tasks::Int
    indeterminate_tasks::Int
    ratio::Union{Nothing,Float64}
    elapsed_seconds::Float64
end

mutable struct ProgressTracker{K}
    tasks::Dict{K,ProgressTask{K}}
    generation::UInt64
    clock::Any
    mutex::ReentrantLock
end

function ProgressTracker{K}(; clock=time_ns) where {K}
    applicable(clock) || throw(ArgumentError("progress clock must be callable without arguments"))
    return ProgressTracker{K}(Dict{K,ProgressTask{K}}(), UInt64(0), clock, ReentrantLock())
end

ProgressTracker(; clock=time_ns) = ProgressTracker{Any}(; clock)

function _progress_now(tracker::ProgressTracker)
    value = tracker.clock()
    value isa Integer && value >= 0 ||
        throw(ArgumentError("progress clock must return a non-negative integer"))
    return UInt64(value)
end

function _next_progress_generation(tracker::ProgressTracker)
    tracker.generation == typemax(UInt64) &&
        throw(OverflowError("progress tracker generation exhausted"))
    return tracker.generation + UInt64(1)
end

function _progress_total(total)
    total === nothing && return nothing
    resolved = Float64(total)
    isfinite(resolved) && resolved >= 0.0 ||
        throw(ArgumentError("progress total must be finite and non-negative"))
    return resolved
end

function _progress_completed(value::Real)
    resolved = Float64(value)
    isfinite(resolved) && resolved >= 0.0 ||
        throw(ArgumentError("completed progress must be finite and non-negative"))
    return resolved
end

function _bounded_progress(completed::Float64, total)
    return total === nothing ? completed : min(completed, total)
end

function _active_progress_ns(task::ProgressTask, now::UInt64)
    segment = task.status == RunningProgress && now >= task.segment_started_ns ?
        now - task.segment_started_ns : UInt64(0)
    return task.active_ns > typemax(UInt64) - segment ? typemax(UInt64) :
        task.active_ns + segment
end

function _stop_progress_task(task::ProgressTask{K}, now::UInt64) where {K}
    return _active_progress_ns(task, now)
end

function _replace_progress_task(
    task::ProgressTask{K};
    description::AbstractString=task.description,
    total=task.total,
    completed::Real=task.completed,
    status::ProgressTaskStatus=task.status,
    active_ns::UInt64=task.active_ns,
    segment_started_ns::UInt64=task.segment_started_ns,
    updated_ns::UInt64=task.updated_ns,
    finished_ns::UInt64=task.finished_ns,
    error=task.error,
    metadata=task.metadata,
) where {K}
    resolved_total = _progress_total(total)
    resolved_completed = _bounded_progress(_progress_completed(completed), resolved_total)
    resolved_error = error === nothing ? nothing : String(error)
    return ProgressTask{K}(
        task.id,
        String(description),
        resolved_total,
        resolved_completed,
        status,
        task.started_ns,
        active_ns,
        segment_started_ns,
        updated_ns,
        finished_ns,
        resolved_error,
        metadata,
    )
end

function _commit_progress_task!(
    tracker::ProgressTracker{K},
    task::ProgressTask{K},
    generation::UInt64,
) where {K}
    tasks = copy(tracker.tasks)
    tasks[task.id] = task
    tracker.tasks = tasks
    tracker.generation = generation
    return task
end

function add_progress_task!(
    tracker::ProgressTracker{K},
    id::K;
    description::AbstractString=string(id),
    total=nothing,
    completed::Real=0.0,
    metadata=nothing,
    replace::Bool=false,
) where {K}
    now = _progress_now(tracker)
    resolved_total = _progress_total(total)
    resolved_completed = _bounded_progress(_progress_completed(completed), resolved_total)
    task = ProgressTask{K}(
        id,
        String(description),
        resolved_total,
        resolved_completed,
        RunningProgress,
        now,
        UInt64(0),
        now,
        now,
        UInt64(0),
        nothing,
        metadata,
    )
    lock(tracker.mutex) do
        haskey(tracker.tasks, id) && !replace &&
            throw(ArgumentError("progress task already exists: $id"))
        generation = _next_progress_generation(tracker)
        _commit_progress_task!(tracker, task, generation)
    end
    return task
end

function remove_progress_task!(tracker::ProgressTracker, id)
    return lock(tracker.mutex) do
        haskey(tracker.tasks, id) || return false
        generation = _next_progress_generation(tracker)
        tasks = copy(tracker.tasks)
        delete!(tasks, id)
        tracker.tasks = tasks
        tracker.generation = generation
        return true
    end
end

function set_progress!(tracker::ProgressTracker{K}, id::K, completed::Real) where {K}
    now = _progress_now(tracker)
    return lock(tracker.mutex) do
        task = get(tracker.tasks, id, nothing)
        task === nothing && throw(KeyError(id))
        task.status == RunningProgress || return false
        resolved = _bounded_progress(_progress_completed(completed), task.total)
        resolved == task.completed && return false
        generation = _next_progress_generation(tracker)
        updated = _replace_progress_task(task; completed=resolved, updated_ns=now)
        _commit_progress_task!(tracker, updated, generation)
        return true
    end
end

function advance_progress!(tracker::ProgressTracker{K}, id::K, amount::Real=1.0) where {K}
    delta = _progress_completed(amount)
    now = _progress_now(tracker)
    return lock(tracker.mutex) do
        task = get(tracker.tasks, id, nothing)
        task === nothing && throw(KeyError(id))
        task.status == RunningProgress || return false
        resolved = _bounded_progress(_progress_completed(task.completed + delta), task.total)
        resolved == task.completed && return false
        generation = _next_progress_generation(tracker)
        updated = _replace_progress_task(task; completed=resolved, updated_ns=now)
        _commit_progress_task!(tracker, updated, generation)
        return true
    end
end

function set_progress_total!(tracker::ProgressTracker{K}, id::K, total) where {K}
    now = _progress_now(tracker)
    resolved_total = _progress_total(total)
    return lock(tracker.mutex) do
        task = get(tracker.tasks, id, nothing)
        task === nothing && throw(KeyError(id))
        task.status in (CompletedProgress, FailedProgress, CancelledProgress) && return false
        task.total == resolved_total && return false
        generation = _next_progress_generation(tracker)
        updated = _replace_progress_task(task; total=resolved_total, updated_ns=now)
        _commit_progress_task!(tracker, updated, generation)
        return true
    end
end

function pause_progress!(tracker::ProgressTracker{K}, id::K) where {K}
    now = _progress_now(tracker)
    return lock(tracker.mutex) do
        task = get(tracker.tasks, id, nothing)
        task === nothing && throw(KeyError(id))
        task.status == RunningProgress || return false
        generation = _next_progress_generation(tracker)
        updated = _replace_progress_task(
            task;
            status=PausedProgress,
            active_ns=_stop_progress_task(task, now),
            segment_started_ns=UInt64(0),
            updated_ns=now,
        )
        _commit_progress_task!(tracker, updated, generation)
        return true
    end
end

function resume_progress!(tracker::ProgressTracker{K}, id::K) where {K}
    now = _progress_now(tracker)
    return lock(tracker.mutex) do
        task = get(tracker.tasks, id, nothing)
        task === nothing && throw(KeyError(id))
        task.status == PausedProgress || return false
        generation = _next_progress_generation(tracker)
        updated = _replace_progress_task(
            task;
            status=RunningProgress,
            segment_started_ns=now,
            updated_ns=now,
        )
        _commit_progress_task!(tracker, updated, generation)
        return true
    end
end

function _finish_progress!(
    tracker::ProgressTracker{K},
    id::K,
    status::ProgressTaskStatus;
    error=nothing,
) where {K}
    now = _progress_now(tracker)
    return lock(tracker.mutex) do
        task = get(tracker.tasks, id, nothing)
        task === nothing && throw(KeyError(id))
        task.status in (CompletedProgress, FailedProgress, CancelledProgress) && return false
        generation = _next_progress_generation(tracker)
        completed = status == CompletedProgress && task.total !== nothing ? task.total : task.completed
        updated = _replace_progress_task(
            task;
            completed,
            status,
            active_ns=_stop_progress_task(task, now),
            segment_started_ns=UInt64(0),
            updated_ns=now,
            finished_ns=now,
            error,
        )
        _commit_progress_task!(tracker, updated, generation)
        return true
    end
end

complete_progress!(tracker::ProgressTracker, id) =
    _finish_progress!(tracker, id, CompletedProgress)

fail_progress!(tracker::ProgressTracker, id, error) =
    _finish_progress!(tracker, id, FailedProgress; error)

cancel_progress!(tracker::ProgressTracker, id) =
    _finish_progress!(tracker, id, CancelledProgress)

function reset_progress!(tracker::ProgressTracker{K}, id::K; completed::Real=0.0) where {K}
    now = _progress_now(tracker)
    return lock(tracker.mutex) do
        task = get(tracker.tasks, id, nothing)
        task === nothing && throw(KeyError(id))
        generation = _next_progress_generation(tracker)
        updated = ProgressTask{K}(
            task.id,
            task.description,
            task.total,
            _bounded_progress(_progress_completed(completed), task.total),
            RunningProgress,
            now,
            UInt64(0),
            now,
            now,
            UInt64(0),
            nothing,
            task.metadata,
        )
        _commit_progress_task!(tracker, updated, generation)
        return true
    end
end

function _progress_snapshot(task::ProgressTask{K}, now::UInt64) where {K}
    elapsed_ns = _active_progress_ns(task, now)
    elapsed = Float64(elapsed_ns) / 1.0e9
    ratio = if task.total === nothing
        task.status == CompletedProgress ? 1.0 : nothing
    elseif task.total == 0.0
        task.status == CompletedProgress ? 1.0 : 0.0
    else
        clamp(task.completed / task.total, 0.0, 1.0)
    end
    eta = if task.status == RunningProgress && task.total !== nothing &&
             task.completed > 0.0 && task.completed < task.total && elapsed > 0.0
        rate = task.completed / elapsed
        (task.total - task.completed) / rate
    else
        nothing
    end
    return ProgressSnapshot{K}(
        task.id,
        task.description,
        task.total,
        task.completed,
        ratio,
        task.status,
        elapsed,
        eta,
        task.error,
        task.metadata,
    )
end

function progress_snapshot(tracker::ProgressTracker, id; now_ns=nothing)
    now = now_ns === nothing ? _progress_now(tracker) : UInt64(now_ns)
    task = lock(tracker.mutex) do
        get(tracker.tasks, id, nothing)
    end
    return task === nothing ? nothing : _progress_snapshot(task, now)
end

function progress_snapshots(tracker::ProgressTracker; now_ns=nothing)
    now = now_ns === nothing ? _progress_now(tracker) : UInt64(now_ns)
    tasks = lock(tracker.mutex) do
        sort!(collect(values(tracker.tasks)); by=task -> string(task.id))
    end
    return [_progress_snapshot(task, now) for task in tasks]
end

function aggregate_progress(tracker::ProgressTracker; now_ns=nothing)
    snapshots = progress_snapshots(tracker; now_ns)
    total_completed = 0.0
    total_work = 0.0
    indeterminate = 0
    unmeasured_incomplete = 0
    for snapshot in snapshots
        if snapshot.total === nothing && snapshot.status in (RunningProgress, PausedProgress)
            indeterminate += 1
        elseif snapshot.total === nothing && snapshot.status != CompletedProgress
            unmeasured_incomplete += 1
        elseif snapshot.total !== nothing
            total_completed += min(snapshot.completed, snapshot.total)
            total_work += snapshot.total
        end
    end
    ratio = indeterminate > 0 || unmeasured_incomplete > 0 ? nothing :
        (total_work == 0.0 ? (isempty(snapshots) ? nothing : 1.0) :
         clamp(total_completed / total_work, 0.0, 1.0))
    return ProgressAggregate(
        length(snapshots),
        count(snapshot -> snapshot.status == RunningProgress, snapshots),
        count(snapshot -> snapshot.status == PausedProgress, snapshots),
        count(snapshot -> snapshot.status == CompletedProgress, snapshots),
        count(snapshot -> snapshot.status == FailedProgress, snapshots),
        count(snapshot -> snapshot.status == CancelledProgress, snapshots),
        indeterminate,
        ratio,
        isempty(snapshots) ? 0.0 : maximum(snapshot.elapsed_seconds for snapshot in snapshots),
    )
end

progress_generation(tracker::ProgressTracker) = lock(tracker.mutex) do
    tracker.generation
end

struct ProgressBar
    ratio::Union{Nothing,Float64}
    label::String
    status::ProgressTaskStatus
    pulse_width::Int
    block::Union{Nothing,Block}
    empty_style::Style
    filled_style::Style
    pulse_style::Style
    failed_style::Style
end

function ProgressBar(;
    ratio=nothing,
    label::AbstractString="",
    status::ProgressTaskStatus=RunningProgress,
    pulse_width::Integer=4,
    block::Union{Nothing,Block}=nothing,
    empty_style::Style=Style(modifiers=DIM),
    filled_style::Style=Style(foreground=AnsiColor(6), modifiers=REVERSED),
    pulse_style::Style=Style(foreground=AnsiColor(4), modifiers=REVERSED),
    failed_style::Style=Style(foreground=AnsiColor(1), modifiers=REVERSED),
)
    resolved_ratio = ratio === nothing ? nothing : Float64(ratio)
    resolved_ratio === nothing || 0.0 <= resolved_ratio <= 1.0 ||
        throw(ArgumentError("progress bar ratio must be between zero and one"))
    pulse_width > 0 || throw(ArgumentError("progress pulse width must be positive"))
    return ProgressBar(
        resolved_ratio,
        String(label),
        status,
        Int(pulse_width),
        block,
        empty_style,
        filled_style,
        pulse_style,
        failed_style,
    )
end

function _progress_label(snapshot::ProgressSnapshot; percentage::Bool=true, eta::Bool=false)
    parts = isempty(snapshot.description) ? String[] : String[snapshot.description]
    percentage && snapshot.ratio !== nothing &&
        push!(parts, string(round(Int, snapshot.ratio * 100), "%"))
    eta && snapshot.eta_seconds !== nothing &&
        push!(parts, string("ETA ", round(Int, snapshot.eta_seconds), "s"))
    snapshot.status == FailedProgress && snapshot.error !== nothing && push!(parts, snapshot.error)
    return join(parts, " · ")
end

ProgressBar(
    snapshot::ProgressSnapshot;
    show_percentage::Bool=true,
    show_eta::Bool=false,
    kwargs...,
) = ProgressBar(;
    ratio=snapshot.ratio,
    label=_progress_label(snapshot; percentage=show_percentage, eta=show_eta),
    status=snapshot.status,
    kwargs...,
)

function ProgressBar(aggregate::ProgressAggregate; label::AbstractString="", kwargs...)
    status = if aggregate.failed_tasks > 0
        FailedProgress
    elseif aggregate.running_tasks > 0
        RunningProgress
    elseif aggregate.paused_tasks > 0
        PausedProgress
    elseif aggregate.cancelled_tasks > 0
        CancelledProgress
    elseif aggregate.total_tasks > 0 && aggregate.completed_tasks == aggregate.total_tasks
        CompletedProgress
    else
        RunningProgress
    end
    return ProgressBar(; ratio=aggregate.ratio, label, status, kwargs...)
end

mutable struct ProgressBarState
    phase::UInt64
end

ProgressBarState(; phase::Integer=0) = begin
    phase >= 0 || throw(ArgumentError("progress phase must be non-negative"))
    ProgressBarState(UInt64(phase))
end

function handle!(state::ProgressBarState, ::ProgressBar, ::TickEvent)
    state.phase += UInt64(1)
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::ProgressBar, state::ProgressBarState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ProgressRole;
        label=isempty(widget.label) ? "Progress" : widget.label,
        state=Accessibility.SemanticState(
            busy=widget.ratio === nothing,
            value_now=widget.ratio,
            value_min=widget.ratio === nothing ? nothing : 0.0,
            value_max=widget.ratio === nothing ? nothing : 1.0,
        ),
        metadata=Dict(:status => widget.status, :phase => state.phase),
    )
end

function render!(
    buffer::Buffer,
    widget::ProgressBar,
    area::Rect,
    state::ProgressBarState=ProgressBarState(),
)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    width = active.width
    filled = widget.ratio === nothing ? 0 : clamp(round(Int, width * widget.ratio), 0, width)
    pulse = min(widget.pulse_width, width)
    pulse_start = widget.ratio === nothing && width > 0 ?
        Int(mod(state.phase, UInt64(width + pulse))) - pulse : 0
    for row in active.row:(active.row + active.height - 1)
        for offset in 0:(width - 1)
            style = if widget.status == FailedProgress && offset < max(filled, 1)
                widget.failed_style
            elseif widget.ratio === nothing && pulse_start <= offset < pulse_start + pulse
                widget.pulse_style
            elseif offset < filled
                widget.filled_style
            else
                widget.empty_style
            end
            buffer[row, active.column + offset] = Cell(" "; style)
        end
    end
    isempty(widget.label) || render!(
        buffer,
        Label(widget.label; alignment=CenterAlign),
        Rect(active.row + div(active.height - 1, 2), active.column, 1, active.width),
    )
    return buffer
end
