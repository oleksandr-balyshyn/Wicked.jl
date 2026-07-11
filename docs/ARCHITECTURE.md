# Wicked.jl Architecture

Wicked.jl is organized as a layered terminal application framework. The lower
layers do not depend on application widgets, and higher layers consume stable
protocols rather than terminal escape sequences directly.

## Layer map

| Layer | Modules | Responsibility |
|---|---|---|
| Terminal primitives | `Core`, `Events`, `Backends` | Geometry, styled cells, Unicode text, buffers, diffs, terminal sessions, typed input |
| Composition | `Layout`, `Widgets`, `Interaction`, `Styles` | Constraints, widgets, focus, bindings, hit testing, themes, selectors |
| Application runtime | `Runtime`, `Toolkit`, `Forms` | Model/update/view loop, commands, subscriptions, keyed reconciliation, validation |
| Rich content | `RichContent`, `RichWidgets`, `RichAdapters`, `RichSurfaces` | Markdown AST, syntax tokens, safe links, scrolling, selection, semantic cell surfaces |
| Integration | `CoreIntegration`, `ToolkitComponents` | Core text/buffer adapters and Toolkit element construction |
| Large data | `Virtualization`, `VirtualTrees`, `VirtualRendering`, `VirtualInput`, `VirtualAdvanced` | Paged sources, stable keys, overscan, virtual tables and trees |
| Extended controls | `AdvancedControls`, `DataEntryControls`, `NavigationControls` | Stateful controls not covered by the base widget set |
| Platform services | `Graphics`, `GraphicsBackend`, `Clipboard`, `DragDrop`, `FileBrowser` | Images, OSC 52, drag routing, filesystem selection |
| Developer services | `Diagnostics`, `RuntimeDiagnostics`, `Testing`, `Accessibility`, `SemanticToolkit` | Traces, metrics, pilots, snapshots, semantic automation |
| Reliability | `Reactive`, `ReactiveToolkit`, `Reliability`, `Extensions` | Reactive state, invalidation, error boundaries, resource scopes, extension lifecycle |

## Rendering pipeline

1. Application state is updated from a typed event or command result.
2. Immediate-mode applications render widgets directly; Toolkit applications reconcile keyed elements.
3. Layout resolves rectangles without writing terminal output.
4. Widgets write immutable cells into the current frame buffer.
5. Buffer diffing emits only changed terminal cells.
6. Graphics commands are committed through a separate frame layer because image protocols are not cell diffs.
7. The terminal session restores cursor, input modes, and alternate-screen state on shutdown.

## State ownership

Widget configuration is immutable where practical. Interaction state is held by
explicit state objects, Toolkit keyed state, or typed reactive signals. Render
methods must not own terminal-global state.

External state is required for lists, tables, trees, editors, virtualized data,
dialogs, and file pickers. This makes state testable and avoids hidden mutation
inside value-like widget declarations.

## Immediate mode and Toolkit

The immediate-mode API is the lowest common rendering model. It is appropriate
for dashboards, small tools, and integrations that already own application
state.

Toolkit adds keyed reconciliation, mounted state, routed events, focus scopes,
style selectors, screens, overlays, and semantic trees. Toolkit components
ultimately render through the same Core buffers as immediate-mode widgets.

`CoreIntegration` and `ToolkitComponents` form the compatibility boundary for
rich and advanced components. Applications may replace their factories when a
custom widget, buffer, or element implementation is required.

## Reactive invalidation

Signals are typed and belong to one `ReactiveRuntime`. Transactions hold the
runtime lock, coalesce changes, and notify after commit. A failed transaction
restores values and versions.

Computed signals declare dependencies explicitly. Effects may return cleanup
callbacks. Toolkit bindings coalesce render, layout, style, semantics, and
subscription invalidations by component ID.

Reactive callbacks must remain short. Long-running work belongs in runtime
commands, subscriptions, or managed task groups.

## Concurrency rules

Terminal rendering is serialized by the application runtime. Background work
communicates through messages, channels, or generation-safe completion records.

Public mutable services use locks. Callbacks are invoked outside service locks
unless a type explicitly documents a transaction callback. User callbacks must
not assume a particular Julia thread.

Generation values protect paged data, validation, file scans, and asynchronous
component refreshes from stale completions.

## Unicode rules

Core cells store grapheme clusters rather than bytes or code points. Wide cells
own continuation cells, and overwriting either side repairs the invariant.

Wrapping, clipping, selection, hit testing, and horizontal scrolling use terminal
cell width. APIs that use logical character columns document that distinction.

## Failure and shutdown rules

`ErrorBoundary` records structured failures and either rethrows, contains, or
disables a failing component. Containment must produce an explicit fallback.

`ResourceScope` closes registered resources in reverse order and aggregates
cleanup failures. Managed task groups register tasks before scheduling, support
cooperative cancellation, and join before shutdown completes.

Terminal restoration belongs in the outermost resource scope and must not depend
on a successful application update or render.

## Extension rules

Extensions declare versions and dependencies. Activation is dependency ordered,
and partial activation rolls back contributions. Contributions are owned by one
extension and removed during deactivation.

Extensions should contribute through typed contribution kinds instead of
mutating global tables. Existing active extensions are preserved by scoped
activation.

## Security boundaries

Hyperlinks and Markdown destinations are classified before activation. OSC 52
payloads are size limited, MIME checked, UTF-8 validated, and stripped of unsafe
text controls according to policy.

File browsers resolve real paths and enforce a configured root after following
symlinks. They do not expose destructive filesystem operations.

Drag payloads and drop targets negotiate MIME prefixes and allowed effects.
`NoDragEffect` is never accepted as a target capability.

## Production gates

The following evidence is required before a stable release:

- Package loading on every supported Julia version.
- Unit tests for public state transitions and invariants.
- Property and fuzz tests for parsers, layout, Unicode cells, and event decoding.
- Snapshot tests for every widget family and terminal capability tier.
- Integration tests for terminal restoration after failures and cancellation.
- Benchmarks for frame diffing, reconciliation, large data, Markdown, and styles.
- Compatibility runs on Kitty, WezTerm, iTerm2, Windows Terminal, tmux, screen, and a minimal ANSI terminal.
- API reference documentation and executable examples.

Until these gates are executed and recorded, feature presence is not evidence of
production readiness.
