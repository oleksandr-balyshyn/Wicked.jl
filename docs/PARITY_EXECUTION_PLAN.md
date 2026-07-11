# Parity Execution Plan

This file converts the reference survey into an executable implementation roadmap.
It binds each widget/runtime family to SPEC, PLAN phase, and concrete work artifacts.

## Governance

- Every family here is one implementation PR boundary.
- Before moving from draft to complete in this document:
  - `REFERENCE_PARITY_SURVEY.md` must contain an updated row for that family,
  - parity status must match behavior evidence (`matched`, `adapted`, `intentional divergence`, `not yet implemented`),
  - all cited follow-ups must exist as explicit issue references or release-checklist items.
- In-code or user-facing behavior differences must be documented in `FEATURE_PARITY.md` or a dedicated changelog entry.

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
| Text editing controls (`TextInput`, `Textarea`, `Masked`, `Number`, `Autocomplete`) | Textual editing semantics + Ratatui-like explicit state + TamboUI form controls | adapted/matched | undo/redo, cursor semantics, resize behavior, paste and clipboard integration tests | Immediate state + runtime commands |
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
| Markup/syntax highlighting and images | TamboUI and Textual content rendering | adapted/not yet implemented | streaming content tests, sanitization, security tests, fallback coverage | Optional integrations + services |
| Remote/protocol and remote transport | Textual-inspired remote workflow + Term.jl capture analogs | adapted/not yet implemented | handshake tests, frame compatibility checks, transport failures | Extensions |
| Browser/remote delivery | Textual-like remote surfaces | not yet implemented | adapter API, protocol versioning, capability negotiation, security boundary tests | Extensions / remote transport |

## Family closeout criteria

A family is considered closeable when all of the following are true:

1. Survey row exists and includes explicit status and follow-up (if needed).
2. `API_REFERENCE.md` reflects adopted/adapted/divergence semantics where public behavior is affected.
3. `FEATURE_PARITY.md` has a parity note for the family if behavior differs from references.
4. Immediate, managed, and toolkit APIs exist where relevant.
5. There is direct interaction coverage for keyboard, pointer, resize, clipping, and accessibility semantics.
6. Migration language and risk notes are recorded in [RELEASE_CHECKLIST.md].

This is expected to change as implementations advance; keep it updated every phase transition.
