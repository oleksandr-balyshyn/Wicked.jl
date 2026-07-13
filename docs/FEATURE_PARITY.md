# Feature Parity Ledger

This ledger compares Wicked's intended surface with Ratatui, Textual, Lanterna, and
TamboUI. It is an implementation audit aid, not a release claim.

## Evidence levels

- **Source present** means an implementation exists in the repository.
- **Integrated** means the implementation has a public adapter or lifecycle path to
  the surrounding framework.
- **Automated worktree** means focused automated tests, examples, or benchmarks
  passed in the recorded local worktree, but immutable candidate and complete
  platform evidence are not established.
- **Production verified** requires every applicable validation gate, supported
  platform, real-terminal category, and release artifact to pass for an immutable
  candidate.
- **Verified** requires package loading, automated tests, examples, compatibility
  checks, and benchmarks appropriate to the claim.

The current repository has extensive source, integration, and automated worktree
coverage, but it has not passed the full production verification gate. See
[Release Evidence](RELEASE_EVIDENCE.md) for exact commands and unresolved scope.
No feature should be described as production-verified solely because it appears
below.

For execution sequencing, the closeout criteria for each family are tracked in
`docs/PARITY_EXECUTION_PLAN.md`.

Parity governance is explicit in
`docs/REFERENCE_PARITY_SURVEY.md`, and the implementation check is enforced by
`scripts/parity_audit.jl` (run via `scripts/quality_gate.jl`) with required
status tracking, follow-up obligations, and structured parity/migration notes for
non-matching behavior.

## API surface status

The reviewed developer surface is concentrated in `Wicked.API`. The current
symbol ledgers record `Wicked.Experimental` as a compatibility namespace with no
application-facing experimental bindings. This improves developer ergonomics for
Ratatui-style immediate rendering, Textual-style Toolkit composition, and
Lanterna/TamboUI-style retained application flows because widgets, state values,
layout helpers, runtime helpers, pilots, semantic helpers, and Toolkit callback
types can be imported from one stable facade.

This status is source-level evidence. The API contract, API audit, quality gate,
docs build, and release evidence must be rerun before the widened facade can be
treated as candidate evidence.

## Widget stabilization status

Widget parity is governed by [Widget Stabilization Tracker](WIDGET_STABILIZATION.md).
The tracker defines the promotion levels, family batches, audit commands, and
release definition of done for the stable widget surface.

The current `api/stable_widget_candidates.tsv` ledger records the direct
renderable inventory as stable, and `api/experimental_api.tsv` records
`Wicked.Experimental` as a compatibility namespace with no app-facing
experimental bindings. This is source-level and ledger-level evidence only. A
release candidate still needs a fresh run of the widget audit, stable-candidate
audit, experimental-promotion audit, compatibility-widget alias audit, examples,
docs, precompile, and Linux CI gates before the widget surface can be called
production verified.

When adding a Ratatui, Textual, TamboUI, or Lanterna-inspired widget, update the
widget stabilization tracker before updating this parity ledger. A feature-family
row below should not move past `Integrated` unless the corresponding
stabilization batch has evidence for constructors, state ownership, rendering,
interaction, semantics, Toolkit integration, examples, precompile, and release
review.

## Reference-library adaptation notes

These rows track survey families whose parity status is `adapted`,
`intentional divergence`, or `not yet implemented`. `scripts/parity_audit.jl`
requires a row here with both a parity note and a migration note before a
non-matching survey status can pass the quality gate. The parity note must name a
reference library or an intentional divergence so adapted behavior stays tied to
the Ratatui/Textual/TamboUI/Lanterna research baseline.

| Family | Parity note | Migration note |
|---|---|---|
| Layout | Wicked adapts Ratatui/TamboUI layout concepts into Julia constraints, flex, grid, dock, flow, and deterministic clipping rather than copying one library's exact type hierarchy. | Prefer `Wicked.API` layout values and document narrow-terminal behavior when porting Ratatui or TamboUI layouts. |
| Input/event | Wicked adapts Textual-style routing and Ratatui terminal input into typed events with cancellation-safe dispatch and Toolkit callbacks. | Port handlers to explicit `KeyEvent`, `MouseEvent`, commands, and Toolkit routing rather than relying on framework-specific event objects. |
| Data displays | Wicked adapts Ratatui stateful collections and Textual/TamboUI data workflows through immediate renderables, virtualized data sources, semantic states, and Toolkit integration. | Keep collection state explicit and use virtualized adapters for large lists, tables, and trees. |
| Runtime | Wicked adapts Textual worker ideas and Lanterna-style terminal lifetime boundaries into managed tasks, subscriptions, bounded queues, and deterministic redraw services. | Move long-running work into runtime services or subscriptions instead of mutating widgets during render. |
| Styling/theming | Wicked adapts Textual CSS-like styling and terminal palette fallback into a typed role/theme system with selectors, pseudo-state, and downgrade policy. | Map CSS-like styling to Wicked roles, classes, and theme patches; record intentional selector or cascade differences. |
| Remote delivery | Wicked adapts Textual-style remote surfaces behind core protocol/session APIs and an HTTP.jl extension rather than making browser delivery part of the core runtime. | Treat browser/server transport as optional extension work and keep core apps backend-agnostic. |

## Rendering and terminal

| Capability | Evidence |
|---|---|
| Cell buffer, frame, clipping, Unicode width | Automated worktree |
| Buffer diffing and ANSI output | Automated worktree |
| Raw mode, alternate screen, cursor and mouse lifecycle | Automated worktree PTY; real-terminal matrix pending |
| Test backend | Automated worktree |
| Kitty, Sixel, and Unicode graphics fallback | Integrated |
| Capability negotiation | Automated worktree |

## Layout and styling

| Capability | Evidence |
|---|---|
| Constraints, flex, grid, dock, flow | Automated worktree |
| Margins, padding, alignment, clipping | Automated worktree |
| Stylesheet parsing, selectors, cascade, pseudo-state | Automated worktree |
| Semantic theme roles | Automated worktree |
| Named theme registry and live engine binding | Automated worktree |
| Light, dark, high-contrast preference | Automated worktree |

## Application architecture

| Capability | Evidence |
|---|---|
| Immediate-mode widgets | Automated worktree; checked-in 173-type, 1,730-dimension matrix recorded; strict audit rerun pending |
| Stateful widget contracts | Automated worktree; state-transition evidence enforced for every stateful renderer |
| Keyed declarative Toolkit | Automated worktree |
| Reconciliation and routed events | Automated worktree |
| Reactive values, computed state, transactions, effects | Automated worktree |
| Screens and focus scopes | Automated worktree |
| Modal/modeless overlays and input barriers | Automated worktree |
| Unified application service pulse and shutdown | Automated worktree |

## Widget families

| Family | Evidence |
|---|---|
| Text, blocks, labels, rules, alerts, headers, footers | Integrated |
| Buttons, toggles, checkbox, radio, select | Integrated |
| Text input, masked input, numeric input, search input, password input, and text area | Integrated |
| Autocomplete, combo box, tags, date, time, color | Integrated |
| Lists, tables, trees, menus, tabs | Integrated |
| Virtual lists, tables, trees, and data sources | Integrated |
| Scroll views, split panes, breadcrumbs, pagination | Integrated |
| Application shell widgets, sidebars, toolbars, drawers, popovers, and tooltips | Integrated |
| Collapsible, accordion, carousel, timeline, stepper | Integrated |
| Dialog and form validation | Integrated |
| Feedback widgets, badges, skeletons, empty states, placeholders, and validation summaries | Integrated |
| File browser | Integrated |
| Markdown, links, syntax, code, diffs, logs | Integrated |
| Gauges, progress, charts, bars, sparklines, canvas | Integrated |
| Kitty, Sixel, Unicode image fallback, and remote browser frame rendering | Integrated; real-terminal and browser deployment evidence pending |
| Calendar and spinner | Integrated |
| Content switcher and tabbed content | Integrated |
| Managed notifications with actions | Integrated |
| Developer utility views, inspector, developer console, help view, pretty display, and large digits | Integrated |

## Interaction and services

| Capability | Evidence |
|---|---|
| Typed key, mouse, paste, resize, focus, tick events | Automated worktree |
| Bindings and scoped named actions | Automated worktree |
| Command palette generation | Automated worktree |
| Clipboard and OSC 52 | Automated worktree |
| Drag and drop | Integrated |
| Runtime tasks, cancellation, subscriptions | Automated worktree |
| Animation, keyframes, easing, reduced motion | Automated worktree |
| Progress tasks, ETA, aggregation | Automated worktree |
| Live reload | Automated worktree |
| Extension registry | Automated worktree |
| Remote binary protocol, bounded decoder, frame backend, typed client events, and fixture ledger | Integrated; see `docs/REMOTE_TRANSPORT.md` and `api/remote_protocol_fixtures.tsv` |
| Browser-hosted remote UI adapter | Integrated through HTTP.jl extension and reference browser client; production deployment evidence remains a release gate |

## Accessibility and testing

| Capability | Evidence |
|---|---|
| Semantic roles, states, actions, trees | Automated worktree; direct-renderable semantic evidence complete |
| Semantic diff and dispatch | Automated worktree |
| Live announcements | Automated worktree |
| Toolkit pilot and semantic queries | Automated worktree |
| Buffer and semantic snapshots | Automated worktree |
| Event recording and replay | Automated worktree |
| Runtime diagnostics and inspector | Automated worktree |

## Verification work still required

The following evidence is required before the project can claim production parity:

1. Attach clean candidate CI results for Julia 1.10 and current Julia on Linux;
   configuration alone is not execution evidence.
2. Attach candidate Linux PTY results and complete the required real-terminal
   lifecycle matrix.
3. Validate Unicode width, combining marks, wide graphemes, emoji, ambiguous-width
   policy, clipping, and diff output against representative real terminals and fonts.
4. Complete accessibility tree and action coverage for every interactive component,
   including dynamic, virtualized, modal, tabbed, progress, and notification
   states. Record the release-candidate artifacts with
   `scripts/semantic_accessibility_evidence_audit.jl --require-complete` and
   `docs/semantic-evidence`.
5. Expand deterministic race and failure-injection evidence across subscriptions,
   callbacks, reload, services, overlays, themes, semantic bindings, and terminal
   partial writes.
6. Archive candidate benchmark output for all versioned workloads and investigate
   any regression against an approved baseline rather than relying on one local run.
7. Repeat examples and the warning-free manual build from a clean depot attached to
   the immutable candidate.
8. Test the release candidate in at least two independent real applications.
9. Rerun the API contract, API audit, quality gate, and docs build after the
   stable-facade expansion and archive the exact command output.
10. Archive commit identity, CI run URLs, snapshot approvals, known-risk decisions,
    manifest digests, benchmark artifacts, and final release metadata.

Until those gates have authoritative results, parity remains implemented but
unverified.
