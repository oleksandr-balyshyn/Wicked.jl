# SPEC

Wicked.jl is a Julia-first terminal UI platform targeting parity with the practical feature set of Ratatui, Textual, TamboUI, and Lanterna:

- immediate, deterministic rendering and layout contracts,
- retained trees with identity, focus, and event routing,
- managed app runtime with commands, subscriptions, and deterministic redraw,
- accessible semantics, diagnostics, and headless test tooling,
- runtime and remote transport adapters.

This repository’s executable target is the parity model in:

- `docs/REFERENCE_PARITY_SURVEY.md` (reference behavior baseline),
- `docs/FEATURE_PARITY.md` (capability evidence status and migration notes),
- `docs/PARITY_EXECUTION_PLAN.md` (family execution roadmap and closeout artifacts),
- `docs/WIDGET_STABILIZATION.md` (public widget promotion policy and release gate contract).

A capability is considered implementation-ready only when the above documents and the gating scripts agree that the current worktree is complete for the required scope.

## Authoritative design target

Wicked must provide three interoperable API levels:

1. Immediate mode rendering for Ratatui-like direct control and custom renderers.
2. Declarative, keyed `Element` trees and Toolkit routing for Textual-style structure.
3. Managed application execution with command queues, subscriptions, lifecycle services, and remote sessions.

All three levels must remain usable independently and composable into one app.

## Evidence and acceptance criteria (minimum)

### 1) Feature surface parity

For each family in `REFERENCE_PARITY_SURVEY.md`, the following must remain true:

- a) the row status is current (`matched`/`adapted`/`intentional divergence`),
- b) migration notes exist when behavior diverges,
- c) closeout evidence is attached through the family-specific release checklist items,
- d) parity matrix checks are green in release mode.

### 2) Developer API quality

`Wicked.API` is the supported application facade. A stable API claim requires:

- stable widget constructors + state types in `api/stable_api.tsv`,
- complete candidate evidence in `api/widget_coverage.tsv`,
- family evidence and closeout in `api/widget_family_evidence.tsv`,
- no unresolved compatibility obligations in `api/experimental_promotions.tsv`.

### 3) Operational readiness

A production-ready surface requires all of the following to pass under Linux with clean git metadata:

- widget stabilization release gate,
- parity closeout and reference-parity gates,
- terminal/lifecycle and real-world evidence artifacts,
- documentation and API audit gates,
- semantic/accessibility and semantic tree evidence.

### 4) Scope constraints

- Linux-only terminal support.
- No API migration path depends on `Wicked.Experimental`; compatibility-only entries must follow promotion rules and are short-lived.
- Remote/browser capabilities are stable at the session/protocol/service boundary, with production delivery treated as an extension-grade concern, not a baseline core replacement.

## Non-goals

- feature claims that are not represented in a completed parity family.
- Windows targets.
- browser-first UX claims not backed by remote deployment evidence.

## Required artifacts before claiming production parity

- Updated parity artifacts and closeout files produced by:
  - `scripts/render_reference_parity_matrix.jl`
  - `scripts/parity_closeout_audit.jl`
  - `scripts/widget_stabilization_gate.jl --release-check`
  - `scripts/render_widget_family_closeout.jl --release-check`
- Release evidence records under `docs/evidence` and immutable candidate logs for:
  - terminal/real-app validation,
  - docs build,
  - loading,
  - package loading,
  - loading/benchmark/semantic/accessibility checks.
