# Performance and Latency Guide

Wicked targets responsive terminal applications on Linux. Ratatui-style
immediate rendering, Textual-style retained Toolkit trees, virtualized data, and
managed runtime services share the same buffer, layout, event, and semantic
contracts.

This guide defines the performance expectations for production applications and
for widgets that are promoted to the stable API. It complements
[Package Loading and Precompilation](PACKAGE_LOADING.md),
[Widget Stabilization Tracker](WIDGET_STABILIZATION.md),
[Validation Strategy](VALIDATION_STRATEGY.md), and the benchmark suite in
`benchmark/`.

## Design rules

1. Keep render functions deterministic and nonblocking.
2. Keep selection, scroll, cursor, focus, animation, and async state outside
   stateless widget values.
3. Reuse explicit state with `render!(buffer, widget, area, state)` in
   production redraw loops.
4. Use `state_for(widget)` for initial state construction, previews, smoke
   tests, examples, and precompile workloads.
5. Use virtual data widgets when logical rows or tree nodes are much larger than
   the viewport.
6. Use runtime commands, subscriptions, services, or managed tasks for
   background work.
7. Use semantic queries and pilots for tests instead of scraping full ANSI
   output.
8. Prefer explicit clocks in animations, services, reload, tests, and
   benchmarks.

## Immediate rendering

Immediate rendering should allocate predictable amounts per frame. Avoid
building large temporary strings during every redraw. Prefer existing `Line`,
`Span`, `Text`, `Paragraph`, `Table`, `VirtualTable`, and `VirtualTree` APIs
when possible.

Good immediate-mode pattern:

```julia
state = state_for(widget)

draw!(terminal) do frame
    render!(frame, widget, frame.area, state)
end
```

Use default-state rendering only when state does not need to survive redraws:

```julia
render!(buffer, Label("ready"), Rect(1, 1, 1, 20))
```

## Toolkit rendering

Toolkit apps should keep keys stable across renders. Reusing keys lets Wicked
preserve mounted state and avoid unnecessary lifecycle churn.

Good Toolkit pattern:

```julia
root = column(
    Element(Label("Build"); key=:title, id=:title),
    Element(Button("Deploy", :deploy); key=:deploy, id=:deploy, focusable=true),
)
```

Avoid deriving keys from list positions when rows can sort, filter, page, or
refresh. Use domain keys.

## Virtual data

Use virtual data widgets when data size exceeds the viewport:

- `VirtualList` for large row lists.
- `VirtualTable`, `DataTable`, and `DataGrid` for large tabular data.
- `VirtualTree` and `TreeTable` for hierarchical data.

Virtual data keeps viewport, cursor, selection, loading, and error state
explicit. That is the stable path for million-row tables and large filesystem or
service trees.

## Styling

Stylesheets are powerful but should not be reparsed every frame. Parse
stylesheets when configuration changes, then reuse a `StyleEngine`.

Good styling pattern:

```julia
sheet = parse_stylesheet("Button.primary { modifiers: bold; }")
engine = StyleEngine(stylesheets=[sheet])
tree = ToolkitTree(root; styles=engine)
```

Use theme roles and classes for bounded state such as `loading`, `invalid`, or
`selected`. Avoid creating unbounded class names from user or domain values.

## Animations and loading

Animations are tick-driven. They do not sleep or spawn tasks by themselves. Call
`tick_animations!` from the runtime, a timer, or a deterministic test loop.

```julia
manager = AnimationManager()
animate!(manager, AnimationSpec(AnimationTrack(0.0, 1.0); duration=0.2))
updates = tick_animations!(manager; now_ns=UInt64(100_000_000))
```

Use reduced-motion and disabled-motion policies for accessibility and low-power
environments. Use `Spinner`, `LoadingIndicator`, and `Skeleton` to communicate
progress without blocking render paths.

## Package loading and precompilation

For package loading and first-use latency, run:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); using Wicked.API'
```

Precompilation warms package code for the active Julia version and manifest. It
does not replace runtime benchmarks, example execution, or real-terminal
validation. See [Package Loading and Precompilation](PACKAGE_LOADING.md).

Stable widgets should add representative construction, `state_for`, render, and
event paths to the precompile workload when those paths are part of normal
application startup.

## Benchmarks

Run a quick local sample:

```sh
julia --project=. benchmark/run.jl --quick
```

Run the allocation gate:

```sh
julia --project=. benchmark/run.jl --check
```

Write machine-readable evidence:

```sh
julia --project=. benchmark/run.jl --check --output=benchmark/results.toml
```

The suite records elapsed time, allocations, and a checksum. Allocation ceilings
in `benchmark/budgets.toml` are blocking and hardware-independent. Wall-clock
times are diagnostic because they are not comparable across different machines.

Current benchmark groups cover:

- Buffer diffs.
- Sparse and full-screen buffer diff cases.
- Unicode width.
- Runtime input and idle draw.
- Diagnostics overhead.
- Services pulse.
- Actions and routed events.
- Animations.
- Layout.
- Deep flex and grid layout.
- Stylesheet parsing and cascade.
- Toolkit reconciliation.
- High-churn Toolkit reconciliation.
- Markdown parsing and rendering.
- Large Markdown and stylesheet documents.
- Virtual data.
- Million-row virtual list and table windows.
- Semantic diffing.
- Progress and live-display workloads.

## Stable widget promotion

A widget family should not be promoted to stable until its normal rendering path
is compatible with these expectations:

- State can be constructed once and reused across frames.
- Render paths avoid terminal IO and blocking work.
- Large data sets have virtualized or paged alternatives.
- Expensive parsing, measurement, or style resolution can be cached outside the
  frame loop.
- Animation and loading work is driven by explicit ticks.
- Tests can assert behavior through state transitions and semantics.
- Benchmarks or audit evidence exist for performance-sensitive paths.

Use the commands in [Widget Stabilization Tracker](WIDGET_STABILIZATION.md)
before release review.

## Release evidence

A release candidate needs attached benchmark output from the immutable candidate
commit. Local runs and CI configuration are useful, but they are not release
evidence until the command output, manifest identity, commit, and artifact are
archived in [Release Evidence](RELEASE_EVIDENCE.md).
Use [Benchmark Evidence Record Template](BENCHMARK_EVIDENCE_TEMPLATE.md) for
completed records under [Benchmark Evidence Records](benchmark-evidence/README.md)
and run `scripts/benchmark_evidence_audit.jl --require-complete` before release
review.
