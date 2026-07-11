# Wicked.jl Developer Guide

## Public API design

Prefer small typed state objects and functions that mutate them explicitly.
Rendering functions should consume state and return widgets, rich lines, semantic
nodes, or Toolkit elements without starting background work.

Use a trailing `!` only when a function mutates an argument or an external
resource. Queries should not mutate caches unless that behavior is part of the
documented protocol.

Reject invalid configuration in constructors. Reject invalid transient input at
the mutation boundary. Do not wait until rendering to discover impossible state.

## Widget structure

A production component normally has four layers:

| Layer | Output |
|---|---|
| State | Typed mutable state with validated transitions |
| Rendering | Base widget, `RichLine`, or `RichSurface` output |
| Interaction | Key/pointer actions returning explicit results or messages |
| Semantics | `SemanticNode` or `SemanticTree` with stable IDs |

Toolkit component builders combine rendering and semantics but do not hide the
state object. Applications may reuse the state with immediate-mode rendering.

## State and identity

Collection widgets use stable domain keys. Row indices are viewport locations,
not identity. Selection should survive sorting, filtering, paging, and refreshes
when the corresponding key still exists.

Toolkit keys identify mounted component state. Semantic IDs identify automation
nodes. They may be related, but each namespace must be unique within its own
tree.

## Commands and background work

Render and update paths must remain deterministic and nonblocking. Use runtime
commands, subscriptions, paged sources, file scan controllers, or managed task
groups for background work.

Every asynchronous result needs a generation or cancellation identity. Applying
a completion from an old query, path, validation run, or screen is a correctness
bug.

Managed task cancellation is cooperative. Operations must check their
`CancellationToken` around blocking or expensive phases.

## Reactive code

Signals sharing a transaction must use one `ReactiveRuntime`. Computed signals
declare dependencies explicitly. Effects are for integration side effects, not
for deriving values that can be represented by a computed signal.

Dispose computed signals, effects, bindings, reactive class sets, and reactive
elements when their component unmounts.

Reactive callbacks may run from the task that changed the signal. Keep callbacks
short and route expensive work through commands.

## Rendering and Unicode

Never use byte length or character count as terminal width. Use grapheme
iteration and terminal cell width for clipping, wrapping, cursor placement, hit
testing, and horizontal scrolling.

Do not write directly into a continuation cell. Core buffer operations must
repair both halves of a wide grapheme when either half is replaced.

Use ASCII in source files unless Unicode is required as runtime data. Terminal
glyph fallbacks can be constructed from code points when needed.

## Styles

Components emit semantic roles instead of hard-coded colors. Themes and
stylesheets map roles, selectors, classes, and states to concrete styles.

Selector matching must remain deterministic. Specificity and source order decide
ties. Invalid external stylesheets produce source diagnostics rather than partial
silent behavior.

Reactive classes should express component state such as `loading`, `invalid`, or
`selected`. They should not encode domain values into unbounded class names.

## Accessibility

Every focusable or actionable node requires a label. Hidden nodes cannot be
focused. A semantic tree should have at most one focused node per focus scope.

Expose supported semantic actions only. A disabled component must not advertise
actions that its state transition layer rejects.

Semantic trees are part of the testing API. Snapshot them alongside visual
output for interactive components.

## Security

Treat terminal input, pasted text, stylesheets, Markdown links, OSC responses,
file paths, extension contributions, and drag payloads as untrusted.

Enforce size limits before decoding encoded payloads. Strip or reject terminal
controls in clipboard text according to policy. Do not open links or execute file
actions implicitly.

Resolve file browser paths through `realpath` and check the configured root after
following symlinks.

## Extension development

Extensions declare dependencies and contribute through `ExtensionContext`.
Contributions are owned and removed during deactivation.

Initialization must either complete or throw. The registry removes partial
contributions on failure. Shutdown callbacks should be idempotent and should use
resource scopes for multiple cleanup operations.

## Error handling

Use typed argument errors for invalid caller configuration. Use domain-specific
errors for backend, parser, capability, clipboard, graphics, extension, and
lifecycle failures.

An error boundary is not a substitute for fixing invariants. Boundaries isolate
components and preserve terminal restoration; they should still expose failures
through diagnostics and automation.

## Review checklist

- Constructor rejects impossible state.
- Mutation preserves all invariants when callbacks throw.
- Async completions are generation safe.
- Mutable shared state is locked or task confined.
- User callbacks run outside service locks unless documented otherwise.
- Unicode width is cell based.
- Focus, pointer capture, and modal behavior are explicit.
- Semantic labels, states, bounds, and actions match visual behavior.
- State can be driven without a real terminal.
- Snapshot output is deterministic.
- Cleanup is idempotent and terminal state is restored after failure.
