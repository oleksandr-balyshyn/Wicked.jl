# Progress

Wicked separates progress tracking from rendering. `ProgressTracker` owns task
lifecycle and timing; `ProgressSnapshot` is an immutable view for widgets,
semantics, logs, and tests; `ProgressBar` renders one snapshot or aggregate.

## Track work

```julia
tracker = ProgressTracker{Symbol}()

add_progress_task!(
    tracker,
    :download;
    description="Downloading archive",
    total=bytes_expected,
)

advance_progress!(tracker, :download, bytes_received)
pause_progress!(tracker, :download)
resume_progress!(tracker, :download)
complete_progress!(tracker, :download)
```

Use `total=nothing` for indeterminate work. Task IDs have one concrete type per
tracker. Duplicate IDs are rejected unless `replace=true` is explicit.

Elapsed time counts only running segments. ETA is available for running,
determinate tasks after measurable progress. The tracker accepts an injected
nanosecond clock for deterministic tests.

## Terminal states

```julia
fail_progress!(tracker, :download, "connection closed")
cancel_progress!(tracker, :indexing)
reset_progress!(tracker, :download)
```

Completed, failed, and cancelled tasks reject further ordinary progress changes.
Reset starts a new timing interval while preserving description, total, and
metadata.

## Render a task

```julia
snapshot = progress_snapshot(tracker, :download)
widget = ProgressBar(snapshot; show_percentage=true, show_eta=true)
state = ProgressBarState()

render!(buffer, widget, area, state)
```

Determinate bars fill according to ratio. Indeterminate bars render a moving pulse;
send `TickEvent` values through `handle!` to advance `ProgressBarState`.

## Aggregate tasks

```julia
aggregate = aggregate_progress(tracker)
widget = ProgressBar(aggregate; label="Build")
```

Determinate work is weighted by task totals rather than averaging percentages. If
any running or paused task is indeterminate, the aggregate ratio is also
indeterminate. The aggregate exposes counts for every lifecycle state so
applications can render detailed summaries or failure badges. Aggregate progress
bars automatically use failure presentation when any task has failed.

## Runtime integration

Read `progress_generation(tracker)` to invalidate cached views only after task state
changes. Snapshot methods sort tasks by ID for deterministic output. Clock reads and
rendering occur outside tracker locks.

## Toolkit integration

```julia
component = progress_component(
    toolkit_adapter,
    snapshot;
    width=48,
    phase=spinner_phase,
    semantic_id="download-progress",
)
```

`render_progress_control` produces a width-bounded `RichLine` with semantic span
roles for filled, empty, pulse, label, failed, paused, cancelled, and completed
states. `progress_semantic_node` exposes `ProgressRole`, determinate value ranges,
busy state for running indeterminate work, failure state, elapsed time, and ETA.

`progress_component` combines both through the existing `ToolkitElementAdapter`, so
progress participates in declarative composition, styling, accessibility snapshots,
and Toolkit reconciliation without duplicating tracker state.
