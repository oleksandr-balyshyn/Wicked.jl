# PLAN

## Plan authority

The release execution plan is `docs/PARITY_EXECUTION_PLAN.md`.

This plan is implemented in three tightly ordered workstreams:

1. library parity execution by family,
2. stabilization and promotion closure,
3. immutable-candidate release posture.

## Current implementation stream by family

Use the rows in `docs/PARITY_EXECUTION_PLAN.md` as the canonical checklist.
Each family is complete only after closeout evidence is generated and accepted by release-mode gates.

### Family-level baseline (already implemented)

- Layout
- Input/event
- Stateful controls
- Data displays
- Runtime
- Developer experience
- Styling/theming
- Remote delivery

### Family-level backlog before production claim

The gap now is proof and hardening, not raw widget inventory:

1. narrow-terminal and resize continuity evidence,
2. async/event cancellation and focus-recovery evidence,
3. virtualized stale-data/loading/error slot evidence,
4. remote transport and browser deployment hardening,
5. semantic/action coverage for interactive and modal/virtual widgets,
6. immutable-candidate artifact regeneration and archival.

## Delivery track (execution order)

### Track A: Parity proof completion

Run and record:

- `julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --release-status --require-release-ready`
- `julia --project=. --startup-file=no scripts/parity_closeout_audit.jl`
- `julia --project=. --startup-file=no scripts/widget_audit.jl --require-complete`

### Track B: Widget and family promotion closure

For every family and impacted widget:

- keep `Wicked.API` as the surface,
- keep `api/stable_widget_candidates.tsv` with promotion-complete rows,
- align public examples and focused docs,
- keep precompile token coverage in `src/Precompile.jl`,
- run: `julia --project=. --startup-file=no scripts/widget_family_evidence_audit.jl`,
  `julia --project=. --startup-file=no scripts/public_widget_candidate_audit.jl`,
  `julia --project=. --startup-file=no scripts/stable_promotion_packet_audit.jl`.

### Track C: Release-mode hardening

Before claiming stable public production parity:

1. `julia --project=. --startup-file=no scripts/widget_stabilization_gate.jl --release-check`
2. `julia --project=. --startup-file=no scripts/render_widget_catalog.jl --surface-release-status --require-surface-release-ready`
3. `julia --project=. --startup-file=no scripts/render_widget_catalog.jl --stability --require-stability-ready`
4. `julia --project=. --startup-file=no scripts/render_widget_family_closeout.jl --release-check`
5. archive all generated artifacts under `docs/evidence` with candidate identity.

## Engineering invariants for every change

- No framework compatibility behavior should depend on `Wicked.Experimental`.
- Any incompatible semantics from references must be written as migration notes in `docs/FEATURE_PARITY.md` and reflected in `docs/evidence/parity_policy.json`.
- Every newly promoted stable capability requires a corresponding promotion packet and closed family row.
- Evidence artifacts remain Linux-only and must include command output, candidate SHA, and manifest digest.

## Definition of done

A family or full repo is production-ready when all of these are true:

- evidence gates pass in release mode,
- parity closeout status is release-ready,
- stabilized widget surface has zero blockers,
- immutable-candidate evidence references include terminal, docs, loading, application, benchmark, and semantic records,
- open follow-up issues are either resolved or documented in the release checklist before shipment.
