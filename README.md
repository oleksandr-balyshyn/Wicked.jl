<p align="center">
  <img src="assets/wicked-logo.svg" width="160" alt="Wicked.jl logo">
</p>

<h1 align="center">Wicked.jl</h1>

<p align="center">
  A Julia-first framework for serious terminal applications.
</p>

<p align="center">
  <a href="https://julialang.org/"><img src="https://img.shields.io/badge/Julia-1.10%2B-9558B2?logo=julia&logoColor=white" alt="Julia 1.10+"></a>
  <img src="https://img.shields.io/badge/runtime-pure%20Julia-2F6F8F" alt="Pure Julia">
  <img src="https://img.shields.io/badge/rendering-immediate%20%2B%20managed%20%2B%20declarative-183D3D" alt="Three API levels">
  <a href="docs/FEATURE_PARITY.md"><img src="https://img.shields.io/badge/parity-evidence%20tracked-D18236" alt="Parity evidence tracked"></a>
</p>

> [!WARNING]
> Wicked.jl is `0.0.1` and under active development. Local implementation and
> automated evidence are strong, but Linux real-terminal compatibility evidence,
> immutable release-candidate approvals, and independent application validation
> remain before a production release. See [Release Evidence](docs/RELEASE_EVIDENCE.md).

## Build terminal software, not terminal glue

Wicked.jl combines the best ideas from Ratatui, Textual, TamboUI, and Lanterna
without importing their language or runtime constraints:

| You need | Wicked gives you |
| --- | --- |
| Fast, explicit rendering | Buffers, frames, Unicode-aware cells, layouts, minimal diffs, and stateful widgets. |
| Application structure | An explicit model/update/view runtime with commands, subscriptions, cancellation, and diagnostics. |
| Polished composition | Keyed Toolkit elements, focus, routed events, forms, overlays, themes, semantic trees, and pilots. |
| Trustworthy tests | Headless buffers, snapshots, semantic assertions, pilots, virtual time, and deterministic event routing. |

```julia
using Wicked.API

buffer = Buffer(5, 42)
frame = Frame(buffer)
render!(frame, Paragraph("Deploy safely. Observe everything."), frame.area)
```

The same rendering primitives power dashboards, data explorers, interactive
CLIs, administration consoles, and full-screen applications.

## Choose your level

### 1. Immediate mode: direct and deterministic

Use widgets with explicit state when you own the frame loop.

```julia
using Wicked.API

widget = List(["Build", "Test", "Release"])
state = ListState(selected=1)
buffer = Buffer(4, 24)

render!(Frame(buffer), widget, buffer.area, state)
handle!(state, widget, KeyEvent(Key(:down)); viewport_height=4)
```

### 2. Managed runtime: explicit application state

Use the runtime when updates, commands, subscriptions, timers, workers, and
cleanup should have a single observable lifecycle. The runtime is deliberately
Elm-like: your application owns its model, `update!` changes it, and `view`
renders it.

Read the [architecture guide](docs/ARCHITECTURE.md) and
[validation strategy](docs/VALIDATION_STRATEGY.md) before introducing services
or background work.

### 3. Toolkit: retained identity, immediate rendering underneath

Use keyed elements for full applications with focus and routed input. Toolkit
components reuse the same renderers as the immediate API.

```julia
using Wicked.API
using Wicked.Experimental

tree = ToolkitTree(
    Element(Button("Deploy", :deploy); id=:deploy, key=:deploy, focusable=true),
)
frame = Frame(Buffer(3, 24))
render_toolkit!(frame, tree)

semantics = toolkit_semantic_tree(tree)
```

## Install and load

Wicked targets Linux terminals on Julia `1.10` and later. The rendering core has
no native UI or `ncurses` dependency.

```julia
import Pkg
Pkg.add("Wicked") # when published to the Julia registry
```

For a local checkout or an unreleased branch:

```julia
import Pkg

Pkg.develop(path="/path/to/Wicked.jl")
Pkg.instantiate()
Pkg.precompile()
```

Use the stable facade in application entry points:

```julia
using Wicked.API
```

Use `Wicked.Experimental` only for APIs explicitly marked experimental. This
boundary lets application code stay stable while advanced integrations evolve.

### Predictable precompilation

Use this bootstrap command locally and in CI:

```sh
JULIA_NUM_THREADS=1 julia --project=. --startup-file=no \
  -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); using Wicked.API'
```

`Pkg.precompile()` builds cache artifacts for the active Julia version,
environment, and manifest. It does not run your application. First startup is
expected to be slower; later loads reuse valid cache entries. Full troubleshooting
and environment guidance: [Loading and precompilation](docs/PACKAGE_LOADING.md).

## What is included

- **Core:** geometry, styles, grapheme-aware text, buffers, frames, capability
  fallback, ANSI and test backends.
- **Layout:** constraints, flex rows and columns, grids, docking, flow/wrap,
  overlays, split panes, clipping, and scrolling.
- **Controls:** text editing, lists, tables, trees, menus, tabs, forms,
  navigation, command palettes, dialogs, notifications, and validation.
- **Rich views:** Markdown, code and diff views, syntax, ANSI-safe text,
  terminal/process views, images with Unicode fallbacks, charts, canvas, and
  calendars.
- **Application services:** focus, themes, accessibility semantics, clipboard,
  drag/drop, virtualization, reactive state, diagnostics, tracing, and testing.

See the [component catalog](docs/COMPONENT_CATALOG.md) for the complete surface
and [feature parity](docs/FEATURE_PARITY.md) for evidence and deliberate deltas.

## Build an application safely

### Terminal lifecycle

Terminal state is a resource boundary. Use a scoped terminal session so raw mode,
alternate screen, cursor state, mouse tracking, focus reporting, and bracketed
paste are restored after normal exit, errors, interrupts, or signals.

```julia
using Wicked.API

terminal = Terminal(AnsiBackend(stdin, stdout))
with_terminal(terminal) do active
    draw!(active) do frame
        render!(frame, Paragraph("Hello from Wicked.jl"), frame.area)
    end
end
```

For recovery procedures and fallback behavior, read
[Terminal Recovery](docs/TERMINAL_RECOVERY.md) and
[Terminal Compatibility](docs/TERMINAL_COMPATIBILITY.md).

### Test before opening a real terminal

Start with `Buffer` and `TestBackend` for deterministic rendering tests. Use
Toolkit pilots and semantic queries for full interaction workflows. This keeps
Unicode clipping, layout, focus, disabled state, keyboard, pointer, and
accessibility behavior testable in CI.

```sh
julia --project=. --startup-file=no -e 'using Pkg; Pkg.test()'
julia --project=. --startup-file=no scripts/widget_audit.jl --require-complete
julia --project=. --startup-file=no scripts/quality_gate.jl
```

## Developer workflow

| Task | Command or reference |
| --- | --- |
| Install and warm caches | `julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'` |
| Run all tests | `julia --project=. -e 'using Pkg; Pkg.test()'` |
| Verify widget evidence | `julia --project=. scripts/widget_audit.jl --require-complete` |
| Verify public quality gates | `julia --project=. scripts/quality_gate.jl` |
| Run terminal cleanup evidence | `julia --project=. scripts/pty_gate.jl` |
| Build the manual | `julia --project=docs docs/make.jl` |

When adding a public widget or subsystem, preserve the contract:

1. Use shared buffers, layout, text, styles, events, and focus primitives.
2. Keep interactive state explicit and testable.
3. Provide constrained rendering, Unicode, keyboard, pointer, disabled, and
   semantic behavior where relevant.
4. Add immediate, Toolkit, and parity evidence before declaring the feature done.
5. Record intentional reference-library differences in the parity artifacts.

## Documentation map

- [Architecture](docs/ARCHITECTURE.md): module boundaries and rendering pipeline.
- [API Reference](docs/API_REFERENCE.md): public API conventions and capabilities.
- [Component Catalog](docs/COMPONENT_CATALOG.md): widget and service inventory.
- [Reference Parity Survey](docs/REFERENCE_PARITY_SURVEY.md): Ratatui, Textual,
  TamboUI, and Lanterna mapping.
- [Parity Execution Plan](docs/PARITY_EXECUTION_PLAN.md): family-level closure criteria.
- [Release Checklist](docs/RELEASE_CHECKLIST.md): candidate and release workflow.
- [Release Evidence](docs/RELEASE_EVIDENCE.md): what is verified locally and what
  still requires external proof.

## Contributing

Wicked is designed as a production library, not a collection of terminal demos.
Public changes need explicit ownership, deterministic behavior, focused tests,
semantic coverage, documented capability fallback, and reviewed API boundaries.

Read [Feature Parity](docs/FEATURE_PARITY.md),
[Release Checklist](docs/RELEASE_CHECKLIST.md), and
[CONTRIBUTING.md](CONTRIBUTING.md) before starting a subsystem or widget family.

---

<p align="center">
  Built in Julia. Rendered as cells. Tested without a terminal.
</p>
