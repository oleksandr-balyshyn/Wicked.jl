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

## Adding or stabilizing a widget

Treat every new app-facing widget as a small public API. Do not add a renderable,
export it from `Wicked.API`, and call it stable in one step without matching
behavioral evidence.

Use this sequence:

1. Define the public constructor and keyword names before writing broad tests.
   Constructor names should match the cross-library concept when the widget exists
   to help Ratatui, Textual, TamboUI, or Lanterna users migrate.
2. Keep mutable interaction state in a dedicated state type. Stateless widgets
   should not allocate hidden state during rendering.
3. Add `state_for(widget)` for every stateful direct renderable. The default state
   path is required for previews, smoke tests, precompilation, and the gallery;
   production applications still retain and reuse explicit state.
4. Implement `measure`, `render!`, `handle!`, and pointer handling where they
   apply. Zero-size, minimal-size, clipped, resized, and normal render paths must
   return deterministically without terminal IO.
5. Add semantic descriptors or semantic children before documenting the widget as
   interactive. Focusable or actionable nodes need labels, states, bounds where
   available, and actions that match the real transition layer.
6. Add Toolkit interoperability through `Element` state factories or component
   builders when the widget is expected to appear in declarative applications.
7. Add coverage rows and evidence for every required dimension in
   `api/widget_coverage.tsv`; use `n/a:<reason>` only when the dimension truly
   cannot apply.
8. Add the widget and state contract to `docs/COMPONENT_CATALOG.md` when the name
   is part of the public vocabulary. Compatibility names should be wrappers unless
   a shared state alias is intentional and documented.
9. Add focused API documentation, a copyable example, and precompile/gallery
   coverage for the normal constructor shape. If the widget is a representative
   stable family token, add a matching precompile token in
   `api/widget_family_evidence.tsv`.
10. Ensure every app-facing widget name exported through `Wicked.API` is backed
    by a concrete or parameterized widget type. Constructor-only functions are
    fine for helpers, but not for public widget concepts in the component catalog
    or stable widget candidate report.
11. Update `api/stable_widget_candidates.tsv`, `api/stable_api.tsv`, and release
    notes through the review workflow, not by hand-editing around a failing gate.
12. Draft a stable promotion packet with
    `scripts/new_stable_promotion_packet.jl`, store completed records in
    `docs/stable-promotion-packets`, and run
    `scripts/stable_promotion_packet_audit.jl` before release review.
    Promotion packets must cite the matching `write_pilot_evidence_package`
    package, `write_pilot_evidence_package_reports` dashboard reports, and
    `scripts/pilot_evidence_package_audit.jl` output for the same immutable
    candidate.

The authoritative details live in [API Stabilization](API_STABILIZATION.md),
[Widget Stabilization Tracker](WIDGET_STABILIZATION.md), and [Widget Coverage
Audit](WIDGET_COVERAGE.md). This checklist exists so the default implementation
path already satisfies those gates instead of treating them as a late release
cleanup.

## Default widget state

Use `state_for(widget)` to construct the default external state for a stateful
widget. Application code should import this function from `Wicked.API`.
Extension packages that add stateful widgets should extend the owning Toolkit
generic so the method is visible through the stable facade:

```julia
using Wicked.API: Buffer, Rect, draw_text!, render!
import Wicked.Toolkit: state_for

struct MyWidget
    label::String
end

mutable struct MyWidgetState
    focused::Bool
end

state_for(::MyWidget) = MyWidgetState(false)
```

Default state is for previews, examples, smoke tests, and initial state
construction. Interactive applications should retain the returned state and pass
it back to `render!` and `handle!` rather than reconstructing it every frame.
The low-level `Widgets` module has an internal `state_for` generic for built-in
immediate renderers and does not export it. Public extensions should target
`Wicked.Toolkit.state_for`, which is re-exported through `Wicked.API`.

For declarative applications, use `ToolkitTree` as the retained shell instead of
storing widget state manually at every call site. `Element` describes the current
view, stable `key` values preserve local state across rebuilt views, and stable
`id` values make focus, diagnostics, semantic automation, and
`element_state(tree, id)` deterministic. This keeps direct widgets immediate-mode
while giving larger applications a Textual/TamboUI-style component tree.

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

For application-level render latency, allocation budgets, virtual data, Toolkit
key stability, animation ticks, precompilation, and benchmark commands, see
[Performance and Latency Guide](PERFORMANCE.md).

## Styles

Components emit semantic roles instead of hard-coded colors. Themes and
stylesheets map roles, selectors, classes, and states to concrete styles.

Selector matching must remain deterministic. Specificity and source order decide
ties. Invalid external stylesheets produce source diagnostics rather than partial
silent behavior.

Use `explain_style(engine, context; role, inline)` when a Toolkit component does
not look as expected. The returned `StyleExplanation` records the theme role,
matching stylesheet rules, specificity, source order, inline patch, and final
style. `style_explanation_records` converts that trace into plain records for
logs, snapshots, and tests. `style_explanation_text`,
`style_explanation_markdown`, and `style_explanation_tsv` render the same trace
for logs, CI artifacts, and machine-readable diagnostics.
Use `style_context_record`, `style_context_text`, `style_context_markdown`, and
`style_context_tsv` to record the actual widget type, id, classes, states, and
ancestor classes that selectors evaluate against.
Use `style_diagnostics(engine, context; role, inline)` to collect the style
context, rule-match diagnostics, cascade explanation, and summary counts into
one `StyleDiagnostics` bundle. Render it with `style_diagnostics_text`,
`style_diagnostics_markdown`, or `style_diagnostics_tsv` for bug reports and CI
artifacts.
Use `search_style_diagnostics_records`, `search_style_diagnostics_text`,
`search_style_diagnostics_markdown`, `search_style_diagnostics_tsv`, and
`search_style_diagnostics_count` to query the aggregate bundle across both
stylesheet rule matches and cascade resolution steps.
Use `search_style_explanation_records`, `search_style_explanation_text`,
`search_style_explanation_markdown`, `search_style_explanation_tsv`, and
`search_style_explanation_count` to isolate a specific role, selector source,
specificity value, rule order, or final style in larger applications. Filtered
records preserve the original resolution `index`, so a search result still
points back to the full cascade trace.
`selector_text(selector)` renders matched rules as compact CSS-like strings such
as `Button.primary:focus`, and selector text participates in style explanation
search.
Use `style_rule_match_records(engine, context)` to inspect every stylesheet rule
against a component, including unmatched selectors. The matching and unmatched
variants plus text, Markdown, and TSV renderers make selector debugging usable in
logs and CI artifacts.
Each rule-match record includes `mismatch_reasons` and `mismatch_reason_text`;
use `selector_match_reasons(selector, context)` when a test or diagnostic needs
the failed selector parts directly.
Use `search_style_rule_match_records`, `search_style_rule_match_text`,
`search_style_rule_match_markdown`, `search_style_rule_match_tsv`, and
`search_style_rule_match_count` to filter large stylesheet diagnostics by
selector, `matched=true`, `matched=false`, mismatch reason, specificity,
stylesheet index, or rule order.
Use `style_explanation_summary`, `style_explanation_summary_records`,
`style_explanation_summary_text`, `style_explanation_summary_markdown`, and
`style_explanation_summary_tsv` when logs or CI only need source counts such as
theme, stylesheet, and inline steps.

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
