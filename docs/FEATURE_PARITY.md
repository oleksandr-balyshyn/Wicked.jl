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
status tracking and follow-up obligations for non-matching behavior.

## Rendering and terminal

| Capability | Evidence |
|---|---|
| Cell buffer, frame, clipping, Unicode width | Automated worktree |
| Buffer diffing and ANSI output | Automated worktree |
| Raw mode, alternate screen, cursor and mouse lifecycle | Automated worktree PTY; real-terminal matrix pending |
| Test backend | Automated worktree |
| Kitty, Sixel, iTerm, and Unicode graphics fallback | Integrated |
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
| Immediate-mode widgets | Automated worktree; strict 58-type, 580-dimension matrix complete |
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
| Text, blocks, labels, rules, alerts, headers, footers | Source present |
| Buttons, toggles, checkbox, radio, select | Integrated |
| Text input, masked input, numeric input, search input, password input, and text area | Integrated |
| Autocomplete, combo box, tags, date, time, color | Integrated |
| Lists, tables, trees, menus, tabs | Integrated |
| Virtual lists, tables, trees, and data sources | Integrated |
| Scroll views, split panes, breadcrumbs, pagination | Integrated |
| Collapsible, accordion, carousel, timeline, stepper | Integrated |
| Dialog and form validation | Integrated |
| File browser | Integrated |
| Markdown, links, syntax, code, diffs, logs | Integrated |
| Gauges, progress, charts, bars, sparklines, canvas | Integrated |
| Calendar and spinner | Source present |
| Content switcher and tabbed content | Integrated |
| Managed notifications with actions | Integrated |

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

1. Attach clean candidate CI results for Julia 1.10 and current Julia across Linux,
   macOS, and Windows; configuration alone is not execution evidence.
2. Attach candidate PTY results for Linux and macOS, automate Windows ConPTY where
   practical, and complete the required real-terminal lifecycle matrix.
3. Validate Unicode width, combining marks, wide graphemes, emoji, ambiguous-width
   policy, clipping, and diff output against representative real terminals and fonts.
4. Complete accessibility tree and action coverage for every interactive component,
   including dynamic, virtualized, modal, tabbed, progress, and notification states.
5. Expand deterministic race and failure-injection evidence across subscriptions,
   callbacks, reload, services, overlays, themes, semantic bindings, and terminal
   partial writes.
6. Archive candidate benchmark output for all versioned workloads and investigate
   any regression against an approved baseline rather than relying on one local run.
7. Repeat examples and the warning-free manual build from a clean depot attached to
   the immutable candidate.
8. Test the release candidate in at least two independent real applications.
9. Archive commit identity, CI run URLs, snapshot approvals, known-risk decisions,
    manifest digests, benchmark artifacts, and final release metadata.

Until those gates have authoritative results, parity remains implemented but
unverified.
