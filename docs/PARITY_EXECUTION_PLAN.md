# Parity Execution Plan

This file converts the reference survey into an executable implementation roadmap.
It binds each widget/runtime family to the reference survey, parity phase, and
concrete work artifacts.

## Governance

- Every family here is one implementation PR boundary.
- Before moving from draft to complete in this document:
  - `REFERENCE_PARITY_SURVEY.md` must contain an updated row for that family,
  - parity status must match behavior evidence (`matched`, `adapted`, `intentional divergence`, `not yet implemented`),
  - all cited follow-ups must exist as explicit issue references or exact
    release-checklist checkbox items.
- In-code or user-facing behavior differences must be documented in `FEATURE_PARITY.md` or a dedicated changelog entry.
- Adapted parity evidence families and scope phrases must stay synchronized with
  [evidence/parity_policy.json](evidence/parity_policy.json), the evidence
  scaffold, and the quality gate.

## Current API-surface status

The reviewed app-facing surface now lives in `Wicked.API`. Widget state types,
layout helpers, runtime helpers, Toolkit routing values, semantic helpers, testing
pilots, and support data models have been promoted out of `Wicked.Experimental`.
`Wicked.Experimental` remains only as a compatibility namespace for future
short-lived experiments.

Remaining roadmap work is therefore not broad experimental-widget promotion. The
priority is to prove the widened facade through API contract tests, API audit,
quality gate, docs build, real-terminal checks, independent app adoption, and
immutable release-candidate evidence.
The stable-widget candidate report treats `Wicked.API` export as only one input:
already-exported widgets still block release if coverage evidence or public
`state_for(widget)` state construction is incomplete.

## Survey family coverage

The reference survey is the authoritative family list. Keep these rows aligned
with `docs/REFERENCE_PARITY_SURVEY.md`, `docs/FEATURE_PARITY.md`,
`docs/VALIDATION_STRATEGY.md`, and `docs/RELEASE_EVIDENCE.md`; the parity audit
checks that every survey family remains represented here.

The machine-readable parity evidence policy covers reviewed adapted families.
`Core rendering` is tracked in this execution plan and the release checklist, but
it is not a reviewed adapted-family record because the survey marks it as
`matched`. Its production closeout evidence belongs to the core API tests,
terminal byte tests, Unicode/width corpus, Linux real-terminal matrix, and
immutable release-candidate evidence rather than an adapted-family migration
record.

Use `scripts/render_reference_parity_matrix.jl` when a pull request, release
note, or dashboard needs a generated view of the cross-library capability matrix
from `docs/REFERENCE_PARITY_SURVEY.md`.

| Survey family | Execution phase | Primary closeout artifact |
|---|---|---|
| Core rendering | Phase 3 | Core API tests, terminal byte tests, Unicode/width corpus, and immutable release evidence |
| Layout | Phase 3 | Layout parity evidence for constraint edge cases, clipping policy, resize continuity, and narrow-terminal behavior |
| Input/event | Phase 5 and Phase 6 | Input/event parity evidence for routed events, async delivery, cancellation behavior, focus restoration, and terminal lifecycle recovery |
| Stateful controls | Phase 5 | Widget contract tests, state-transition tests, semantic snapshots, and stable widget candidate evidence |
| Data displays | Phase 5 and Phase 7 | Data-display parity evidence for virtual list/table/tree stress cases, stale data, loading/error slots, and screen-reader semantic state |
| Runtime | Phase 6 and Phase 8+ | Runtime parity evidence for queue replacement, task cancellation races, redraw determinism, resource cleanup, and subscription shutdown |
| Developer experience | Phase 7 | API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output |
| Styling/theming | Phase 3 and Phase 7 | Styling/theming parity evidence for selector specificity, cascade order, role downgrade behavior, diagnostics, and monochrome fallback |
| Remote delivery | Phase 8+ | Remote-delivery parity evidence for browser deployment, WebSocket hardening, protocol versioning, security policy, and real-client compatibility |

## Phase 3 / Foundation parity worklist

| Family | Required behavior sources | Current status target | Planned evidence | API ownership |
| ------ | ----------------------- | -------------------- | --------------- | ------------ |
| Core text and buffers | Ratatui rendering model, Lanterna terminal abstraction | matched/adapted baseline already present | core API tests + terminal byte tests + Unicode/width corpus | Immediate core API (`Wicked.Core`) |
| Layout primitives (`Layout`, constraints, flow, grid, dock, stack, row/column) | Ratatui Layout, TamboUI layouts | adapted | layout unit tests + clipped resize snapshots + docs examples | Immediate + toolkit containers |
| Scrolling and viewport primitives | Ratatui list-like scrolling + layout clipping | matched/adapted | widget contract tests for viewport movement + resize continuity | Immediate renderables and toolkit states |

## Phase 5 / Stateful interaction parity worklist

| Family | Required behavior sources | Current status target | Planned evidence | API ownership |
| ------ | ------------------------ | -------------------- | --------------- | ------------ |
| Selection and input widgets (`List`, `Table`, `Tree`, `Menu`, `Tabs`) | Ratatui + TamboUI stateful conventions | matched/adapted | keyboard/mouse tests, state-transition tests, toolkit interop tests, accessibility state snapshots | Immediate state (`*State`) + toolkit adapters |
| Text editing controls (`TextInput`, `Textarea`, `Masked`, `Number`, `Autocomplete`) | Textual editing semantics + Ratatui-like explicit state + TamboUI form controls | adapted/matched | undo/redo, cursor semantics, resize behavior, paste and clipboard integration tests | Immediate widgets + explicit state + runtime commands |
| Focus and traversal | Textual focus and input routing + Ratatui deterministic focus boundaries | adapted | key binding tests (tab/reverse-tab/page), focus scope and restore tests | Runtime + toolkit focus manager |

## Phase 6 / Declarative and navigation parity worklist

| Family | Required behavior sources | Current status target | Planned evidence | API ownership |
| ------ | ------------------------ | -------------------- | --------------- | ------------ |
| Routed events and message phases | Textual event pipeline + TamboUI routing | adapted | target/bubble/application event tests + propagation edge-cases | Toolkit event loop |
| Screens, modals, overlays, drawers, popovers | Textual navigation models + TamboUI modal workflows + Lanterna window model | matched/adapted | lifecycle tests, blocking behavior, escape/restore and dismissal tests | Toolkit navigation modules |
| Forms, validation, navigation shells (header/footer/status) | Textual/ratatui/form style APIs | matched/adapted | validation transitions, async summary tests, migration and state restore tests | Toolkit + runtime + services |

## Phase 7 / Visualization and developer UX parity worklist

| Family | Required behavior sources | Current status target | Planned evidence | API ownership |
| ------ | ------------------------ | -------------------- | --------------- | ------------ |
| Charts and gauges (`Progress`, `Spinner`, `Sparkline`, `Bar`, `Gauge`, `Chart`) | Ratatui widgets + TamboUI chart catalog | matched/adapted | deterministic raster snapshots + resize/min-size + monochrome fallback | Immediate renderables + visual utility modules |
| File and source tools (`FileBrowser`, logs, markdown, code view, diff) | TamboUI/TamboUI-like data widgets + Textual rich content workflows | matched/adapted | data mutation + clipboard + sorting/filtering + toolkit semantic states | Immediate + toolkit + virtual data adapters |
| Developer diagnostics (inspector, tracing, semantic snapshots, pilot API) | Textual developer tooling + Wicked existing tracing | matched | trace replay tests + stable query coverage + snapshot policy tests | Testing/runtime diagnostics services |

## Phase 8+ / Optional and extension parity worklist

| Family | Required behavior sources | Current status target | Planned evidence | API ownership |
| ------ | ------------------------ | -------------------- | --------------- | ------------ |
| Markup/syntax highlighting and images | TamboUI and Textual content rendering | adapted | streaming content tests, sanitization, security tests, fallback coverage, browser/remote rendering evidence | Rich content, graphics, optional integrations |
| Remote/protocol and remote transport | Textual-inspired remote workflow + Term.jl capture analogs | adapted | handshake tests, frame compatibility checks, transport failures, queue backpressure, bounded decoder failures | Stable remote transport API (`Wicked.API`) |
| Browser/remote delivery | Textual-like remote surfaces | adapted | HTTP.jl extension tests, protocol versioning, capability negotiation, security boundary tests, lifecycle docs, reference browser client, API discoverability, and production deployment evidence | Extension + remote transport |

## Family closeout criteria

A family is considered closeable when all of the following are true:

1. Survey row exists and includes explicit status and follow-up (if needed).
2. `API_REFERENCE.md` reflects adopted/adapted/divergence semantics where public behavior is affected.
3. `FEATURE_PARITY.md` has a parity note for the family if behavior differs from references.
4. Immediate, managed, and toolkit APIs exist where relevant.
5. There is direct interaction coverage for keyboard, pointer, resize, clipping, and accessibility semantics.
6. `Wicked.API` exposes the family without requiring `Wicked.Experimental`.
7. New or promoted public widgets have a stable promotion packet based on
   [STABLE_PROMOTION_PACKET_TEMPLATE.md](STABLE_PROMOTION_PACKET_TEMPLATE.md),
   preferably drafted with `scripts/new_stable_promotion_packet.jl`.
8. API contract tests, API audit, quality gate, and docs build pass after the
   family is added or changed.
9. The stable widget-surface release gate passes for the affected family and for
   the full surface:
   `scripts/render_widget_catalog.jl --surface-release-status --require-surface-release-ready`.
10. Parity evidence records use [PARITY_EVIDENCE_TEMPLATE.md](PARITY_EVIDENCE_TEMPLATE.md) and cite the
   release-candidate command, environment, checked behavior, and artifact.
11. Migration language and risk notes are recorded in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

This is expected to change as implementations advance; keep it updated every phase transition.
