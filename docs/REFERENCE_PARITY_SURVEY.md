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
| Layout | rich constraints and flex-like split behavior | reactive sizing hooks | rows/columns/container abstractions | deterministic viewport handling | support mixed fixed+flex+ratio+content constraints and deterministic clip behavior | adapted | Keep parity note for constraint edge cases and clipping policy. |
| Input/event | terminal event stream and key/mouse parsing | routed events and focus scopes | toolkit actions and interaction contracts | conservative key/mouse handling | unify into typed event envelope with named routing and cancellation-safe dispatch | adapted | Add end-to-end event-routing tests for async and cancellation behavior. |
| Stateful controls | focused state in app-owned models | focusable/replayable events and automation | immediate + toolkit state bridge | conservative input controls | require explicit state for all interactive widgets and toolkit state interoperability | matched | Keep widget tests current as API and interaction cases evolve. |
| Data displays | list/table/tree/stateful scroll models | screen components and query patterns | virtualized collections and lazy rendering | grid-oriented table abstractions | provide immediate and toolkit variants sharing measurement and interaction logic | adapted | Prioritize virtual data stress cases and screen-reader semantic state coverage. |
| Runtime | managed app loop and error handling patterns | worker model and cancellation semantics | service-style tasks | terminal-safe session lifetime | implement structured task ownership, queue bounds, worker cancellation, deterministic redrawing | adapted | Expand failure-injection around queue replacement and cancellation races. |
| Developer experience | tests and examples on built-in widgets | automation hooks + diagnostics | runner/declarative parity | explicit abstractions and compatibility story | invest in pilot APIs, semantic queries, snapshots, and migration guides | matched | Keep migration notes for API evolution and plugin lifecycles. |
| Styling/theming | palette/state-aware rendering | CSS-like styles and classes | theme roles | conservative fallback behavior | keep stable style/role system with tested downgrade and diagnostics | adapted | Expand specificity + cascade test matrix and failure diagnostics. |

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

Phase mapping is tied to the existing PLAN release phases:

- Phase 3: align foundation layout/text/navigation primitives from Ratatui and TamboUI.
- Phase 5: prioritize selection/input parity where Ratatui/Textual/TamboUI differ.
- Phase 6: align routing/focus/stylesheet behavior with Textual/TamboUI.
- Phase 7: complete visualization and diagnostics parity using Ratatui and TamboUI surfaces plus Textual automation expectations.
- Phase 8: keep optional advanced capabilities behind explicit feature flags/extensions as planned.

Any gap marked as `adapted`, `intentional divergence`, or `not yet implemented` must
include a follow-up issue and a migration note in the parity ledger.
