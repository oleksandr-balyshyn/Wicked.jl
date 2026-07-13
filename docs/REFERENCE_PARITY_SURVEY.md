# Competitive Library Reference Survey (2026-07-11)

This document tracks the explicit research baseline used to drive Wicked.jl implementation decisions.

- Reference date: `2026-07-11`
- Libraries: [Ratatui](https://ratatui.rs), [Textual](https://textual.textualize.io), [TamboUI](https://tamboui.dev/docs/main/), [Lanterna](https://github.com/mabe02/lanterna)
- Scope: rendering core, interaction model, widgets, application lifecycle, testing and developer workflow.

## Snapshot of reference capabilities

### Ratatui
- Architecture: immediate-mode rendering + app-level state management, terminal backends, and widget/stateful-widget traits.
- Relevant baseline docs:
  - architecture (`Frame` and render model): https://ratatui.rs/concepts/rendering/
  - layout (`Constraint`, `Layout`, `Direction`): https://ratatui.rs/concepts/layout/
  - widgets examples and built-ins: https://ratatui.rs/recipes/widgets/
  - event handling model and application flow: https://ratatui.rs/concepts/event-handling/
- Observable maturity in latest docs: `v0.30.x` series references are active in official docs.

### Textual
- Architecture: declarative component tree, message event system, widget library with focus, CSS-like styling, and async workers.
- Relevant baseline docs:
  - widgets and app structure: https://textual.textualize.io/guide/widgets/
  - reactivity and updates: https://textual.textualize.io/guide/reactivity/
  - input focus model and key event handling (guide index): https://textual.textualize.io/guide/
- Observable maturity: rich event pipeline with target/bubble phases and explicit focus semantics.

### TamboUI
- Architecture: explicit layered toolkit/model split (runner/toolkit), immediate widgets + toolkit state bridge, and broad chart/layout/widget catalog.
- Relevant baseline docs:
  - homepage and concepts: https://tamboui.dev/docs/main/
  - widget inventory: https://tamboui.dev/docs/main/widgets.html
  - core concepts and binding model: https://tamboui.dev/docs/main/core-concepts.html
  - layouts: https://tamboui.dev/docs/main/layouts.html
- Observable maturity: designed for composability and practical immediate/declarative transitions.

### Lanterna
- Architecture: screen hierarchy and pure-Java terminal abstraction with three layers (terminal, screen, gui toolkit).
- Relevant baseline docs:
  - repository readme and architecture summary: https://github.com/mabe02/lanterna
  - javadocs (stable API snapshots): http://mabe02.github.io/lanterna/apidocs/3.1/
- Observable maturity: conservative lifecycle model and low-risk terminal abstraction.

## Capability audit matrix for Wicked.jl implementation

| Family | Ratatui baseline to mirror | Textual baseline to mirror | TamboUI baseline to mirror | Lanterna baseline to mirror | Wicked implementation direction | Parity status | Follow-up |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Core rendering | diff + frame + buffer ownership | app composition boundaries | component adapters + rendering integration | screen and terminal abstraction | keep pure-Julia diffed buffer core; adopt explicit backend/session boundaries | matched | Validate terminal redraw and fallback paths in real-terminal matrix. |
| Layout | rich constraints and flex-like split behavior | reactive sizing hooks | rows/columns/container abstractions | deterministic viewport handling | support mixed fixed+flex+ratio+content constraints and deterministic clip behavior | matched | Release checklist: Layout parity evidence covers constraint edge cases, clipping policy, resize continuity, and narrow-terminal behavior. |
| Input/event | terminal event stream and key/mouse parsing | routed events and focus scopes | toolkit actions and interaction contracts | conservative key/mouse handling | unify into typed event envelope with named routing and cancellation-safe dispatch | matched | Release checklist: Input/event parity evidence covers routed events, async delivery, cancellation behavior, focus restoration, and terminal lifecycle recovery. |
| Stateful controls | focused state in app-owned models | focusable/replayable events and automation | immediate + toolkit state bridge | conservative input controls | require explicit state for all interactive widgets and toolkit state interoperability | matched | Keep widget tests current as API and interaction cases evolve. |
| Data displays | list/table/tree/stateful scroll models | screen components and query patterns | virtualized collections and lazy rendering | grid-oriented table abstractions | provide immediate and toolkit variants sharing measurement and interaction logic | matched | Release checklist: Data-display parity evidence covers virtual list/table/tree stress cases, stale data, loading/error slots, and screen-reader semantic state. |
| Runtime | managed app loop and error handling patterns | worker model and cancellation semantics | service-style tasks | terminal-safe session lifetime | implement structured task ownership, queue bounds, worker cancellation, deterministic redrawing | matched | Release checklist: Runtime parity evidence covers queue replacement, task cancellation races, redraw determinism, resource cleanup, and subscription shutdown. |
| Developer experience | tests and examples on built-in widgets | automation hooks + diagnostics | runner/declarative parity | explicit abstractions and compatibility story | invest in pilot APIs, semantic queries, snapshots, and migration guides | matched | Keep migration notes for API evolution and plugin lifecycles. |
| Styling/theming | palette/state-aware rendering | CSS-like styles and classes | theme roles | conservative fallback behavior | keep stable style/role system with tested downgrade and diagnostics | matched | Release checklist: Styling/theming parity evidence covers selector specificity, cascade order, role downgrade behavior, diagnostics, and monochrome fallback. |
| Remote delivery | backend abstraction suitable for external presentation | remote/application surfaces and worker-friendly event transport | runner-compatible remote workflows | conservative protocol boundaries | keep a stable binary protocol and session API in core; provide browser/server delivery through the HTTP.jl extension | matched | Release checklist: Remote-delivery parity evidence covers browser deployment, WebSocket hardening, protocol versioning, security policy, and real-client compatibility. |

## Mandatory evidence workflow (for every widget family)

For each family before marking feature-complete, implement the following in this order:

1. Reference behavior extraction from the four libraries.
2. Mapping document in `docs/REFERENCE_PARITY_SURVEY.md` updated for that family.
3. API surface decision in `API_REFERENCE.md` or an explicit ADR.
4. Implementation in immediate mode (state model + render behavior).
5. Managed-runtime integration (message/command compatibility).
6. Declarative toolkit integration (where applicable).
7. Test evidence for:
   - keyboard navigation and activation,
   - pointer semantics,
   - clipping/resizing,
   - disabled/validation states,
   - theme and monochrome fallback,
   - and at least one real or synthetic interoperability scenario.
8. Cross-library migration note for any intentional divergence.

## Library coverage backlog target (next objective cycle)

Phase mapping is tied to the release phases in `docs/PARITY_EXECUTION_PLAN.md`:

- Phase 3: align foundation layout/text/navigation primitives from Ratatui and TamboUI.
- Phase 5: prioritize selection/input parity where Ratatui/Textual/TamboUI differ.
- Phase 6: align routing/focus/stylesheet behavior with Textual/TamboUI.
- Phase 7: complete visualization and diagnostics parity using Ratatui and TamboUI surfaces plus Textual automation expectations.
- Phase 8: keep optional advanced capabilities behind explicit feature flags/extensions as planned.

Any gap marked as `adapted`, `intentional divergence`, or `not yet implemented`
must include either a follow-up issue or an exact release-checklist checkbox
reference, plus a migration note in the parity ledger. The generated matrix
schema audit enforces that those statuses cite a release-checklist item or issue
follow-up.
Families marked `matched`, such as core rendering, still need release-candidate
evidence, but they do not require adapted-family migration evidence records.

Render this matrix for CI artifacts, release dashboards, or implementation
planning with:

```sh
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --format markdown
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --summary --format markdown
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --format markdown --columns family,status,follow_up
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --blocking-only --format markdown --columns family,status,follow_up
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --blocking-only --format json
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --source docs/REFERENCE_PARITY_SURVEY.md --format tsv --columns family,status
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --format json
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --release-status
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --release-blockers
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --release-status-json
julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --release-status --require-release-ready
julia --project=. --startup-file=no scripts/reference_parity_matrix_schema_audit.jl
julia --project=. --startup-file=no scripts/reference_parity_matrix_schema_audit.jl --release-check
```

Release readiness is intentionally stricter than matrix validity. Rows marked
`adapted`, `intentional divergence`, or `not yet implemented` remain useful for
planning and implementation review, but release status reports them as blockers
until the family has final parity closeout evidence and the matrix row can be
changed to `matched`. Release-status JSON includes `blocking_records` with each
blocking family, status, and follow-up so CI artifacts can point directly at the
remaining closeout work.
