# Reference TUI audit

This audit compares Wicked.jl with the upstream `main` branches inspected on
2026-07-21:

- [Terminus](https://github.com/creativescala/terminus) (`922984c`)
- [TamboUI](https://github.com/tamboui/tamboui) (`69c1b94`)
- [Ratatui](https://github.com/ratatui/ratatui) (`a2ca2df`)
- [Bubble Tea](https://github.com/charmbracelet/bubbletea) (`fc707bb`)
- [Textual](https://github.com/Textualize/textual) (`06dbeef`)
- [Ink](https://github.com/vadimdemedes/ink) (`70af033`)

The purpose is design research, not source transplantation. Foreign code must
not be copied into Wicked without a separate license and provenance review.

## Architectural position

Wicked already combines three approaches which are separate in most reference
libraries:

1. Ratatui-style immediate rendering into a cell buffer, with stateless and
   externally stateful widgets.
2. Bubble Tea / Elm-style model-update-view execution with finite commands and
   model-derived subscriptions.
3. Compose / React-style retained components through `Element`, `component`,
   `@ui`, keys, remembered and saveable state, composition locals, effects,
   modifiers, lazy collections, semantics, and reconciliation.

The public widget inventory is broader than Ratatui core and broadly covers the
widgets shipped by TamboUI and Textual. Adding more aliases or nominal widget
types is therefore lower value than closing the behavioral gaps below.

## Capability matrix

| Area | Wicked today | Strong reference | Assessment |
|---|---|---|---|
| Cell buffer and differential rendering | Present, including Unicode-width policy and ANSI/inline/remote backends | Ratatui | Strong |
| Constraint and responsive layout | Length/min/max/ratio/percentage/fill/content, flex, grid, dock, stack, split panes | Ratatui, Textual | Strong |
| Widget breadth | Data, navigation, inputs, rich content, visualization, streaming, overlays, forms, virtualized collections | TamboUI, Textual | Strong |
| Declarative composition | `@ui`, keyed elements and collection helpers, components, slots, modifiers, locals, state and effects | Ink, Jetpack Compose | Strong but young |
| Command algebra | Message, delay, task, process, terminal, concurrent batch, ordered sequence, recursive message mapping, cancel, exit, frame and suspend | Bubble Tea | Ordered composition and mapping landed; retry/backoff and timeout policies remain |
| Subscriptions | Model-derived interval and callback event subscriptions with identity, replacement, cancellation and cleanup; reactive signal, cooperative channel, file-watch, and bounded process-stream adapters | Bubble Tea, Textual | Core general-purpose adapters delivered; protocol-specific socket integrations can build on `EventSubscription` |
| Terminal feature declaration | `ApplicationView` couples content with diffed title, cursor, mouse, alternate-screen, focus, and paste requests | Bubble Tea v2 | Core declarative terminal contract delivered; future backends implement the neutral mode interface |
| Styling | Themes, roles, patches and reactive classes | Textual CSS, Ink props | Capable, but lacks a compact selector stylesheet and live inspector workflow |
| Reconciliation tooling | Stable keys, duplicate-key checks, retained state, semantics, bounded mount/reuse/replace/move/unmount traces, and inspectable positional-state identity warnings | React/Ink, Compose | Core diagnostics delivered; a live inspector remains |
| Testing | Buffers, snapshots, runtime pilot, virtual time, terminal evidence | Textual pilot, TamboUI pilot | Strong; should add declarative terminal-mode and ordered-effect pilots |
| Platform/backend reach | Linux terminals only | Ratatui, Bubble Tea, Textual, Terminus | Major product gap: macOS and Windows are unsupported |
| Documentation | README remains, but the current worktree removes the complete `docs/` manual and evidence corpus | All references | Release blocker until an intentional replacement exists |

## Priority gaps

### P0: restore a releasable baseline

- Resolve the current deletion of the documentation tree and root release
  documents. If intentional, replace them with a smaller generated manual in
  the same change; otherwise restore them.
- Keep the full Julia 1.10 and 1.12 test, API-audit, benchmark, PTY, and docs
  gates green. A passing widget test subset cannot validate the release surface.
- Split the very large toolkit and acceptance-widget files into internal modules
  without changing the stable facade. Their present size makes review,
  precompilation diagnosis, and ownership difficult.

### P1: complete the application architecture

- Extend the ordered `SequenceCommand` and concurrent `BatchCommand` algebra,
  now equipped with recursive `map_command`, with retry/backoff, timeout, and
  explicit exhaustion policies.
- Build protocol-specific socket integrations on the general
  `EventSubscription` registration/cleanup protocol as concrete applications require them.
- Extend the declarative `ApplicationView` backend-neutral mode interface when
  future terminal protocols add capabilities beyond title, cursor, mouse,
  alternate-screen, focus reporting, and bracketed paste.
- Make command and subscription failures consistently typed, inspectable, and
  composable with component error boundaries.

### P1: harden the declarative DSL

- Build inspector views on the delivered bounded reconciliation trace, whose
  mount, reuse, replace, move, and unmount records include stable paths and reasons.
- Surface the delivered stateful positional-child insertion, removal, and
  ID-backed reorder warnings in a future live inspector.
- Extend the delivered `keyed` and `keyed_each` collection helpers only where
  future DSL usage reveals additional finite-iterable ergonomics.
- Define modifier precedence, parent-data modifiers, measurement contracts, and
  effect commit ordering as explicit tested specifications.
- Add a renderer-independent component test harness for recomposition counts,
  effect cleanup, state restoration, focus, and semantics.

### P2: ecosystem and usability

- Support macOS first, then Windows, behind terminal-controller interfaces; keep
  core buffer, layout, widgets, and testing platform-independent.
- Add a live inspector showing the element tree, areas, constraints, focus,
  semantics, invalidations, render cost, and last routed event.
- Provide first-class application templates for dashboards, forms, pagers,
  command palettes, streaming logs, and multi-screen applications.
- Build compatibility cookbooks rather than aliases: Terminus component/state,
  Ratatui widget/state, Bubble Tea model/update/view, Textual app/widget/CSS, and
  Ink component/hook mappings.

## Widget-gap conclusion

No major core widget family from Ratatui or TamboUI is plainly absent from the
current Wicked source inventory. Textual's higher-level conveniences are also
mostly represented: directory trees, data tables, markdown, rich logs, command
palettes, content switching, tabbed content, selection controls, masked input,
toasts, loading and progress UI.

Future widget work should be driven by behavioral contracts rather than names:
large-data virtualization, keyboard and pointer parity, Unicode edge cases,
accessibility semantics, controlled/uncontrolled state, composition behavior,
and deterministic tests. The architecture gaps above will improve every widget
and should precede another broad widget-import campaign.

## Upstream research forks

The requested research forks were created under the configured GitHub account:

- <https://github.com/w0rxbend/terminus>
- <https://github.com/w0rxbend/ratatui>
- <https://github.com/w0rxbend/bubbletea>
