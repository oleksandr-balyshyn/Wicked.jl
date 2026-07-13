# Contributing to Wicked.jl

Contributions should follow the evidence expectations in `docs/FEATURE_PARITY.md` and `docs/RELEASE_CHECKLIST.md`. Source presence is not sufficient: behavior requires tests, documentation, and relevant production evidence.

## Set up the repository

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); using Wicked'
```

Run the local gates:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. scripts/quality_gate.jl
julia --project=. benchmark/run.jl --quick --check
```

The compatibility matrix runs on Linux with the minimum supported Julia version and the latest Julia `1.x` release.

## Design rules

- Keep core rendering independent from retained Toolkit behavior.
- Keep immediate widget state explicit and persistent across frames.
- Use ordinary Julia values, functions, keyword arguments, `do` blocks, and multiple dispatch before introducing macros.
- Keep render and update paths deterministic and nonblocking.
- Route background results through managed messages; do not mutate application models from worker tasks.
- Bound untrusted input before allocation, decoding, sanitization, or terminal output.
- Run user callbacks outside locks unless the contract explicitly requires otherwise.
- Make cleanup idempotent and safe after partial initialization.
- Preserve one-based coordinates and cell-width-aware Unicode behavior.

## Public API changes

Explain ownership, mutation, error, cancellation, threading, and lifecycle behavior. Add a changelog entry for user-visible changes. Follow `VERSIONING.md`; do not silently remove or reinterpret a documented API.

External extension points such as `render!` must remain usable without registration or dependencies on underscored internals.

## New widgets and components

Include evidence for:

- Explicit state and validated transitions.
- Clipping, zero-sized areas, narrow terminals, and resizing.
- Keyboard-only operation and pointer behavior where applicable.
- Focus, disabled, hidden, selected, checked, expanded, invalid, busy, and pending state.
- Light, dark, and high-contrast styling.
- Semantic role, label, bounds, states, and actions.
- Mount/unmount and subscription disposal.
- Immediate-mode and Toolkit interoperability.
- Deterministic state-transition tests and visual/semantic snapshots.

Draft a stable promotion packet before promoting any new public widget to
`Wicked.API`:

```sh
julia --project=. --startup-file=no scripts/new_stable_promotion_packet.jl \
  --family Stateful-controls \
  --widget ComboBox \
  --source src/AcceptanceWidgets.jl \
  --candidate <sha> \
  --decision promote
```

Completed packet records live in `docs/stable-promotion-packets` and must pass:

```sh
julia --project=. --startup-file=no scripts/stable_promotion_packet_audit.jl
julia --project=. --startup-file=no scripts/pilot_evidence_package_audit.jl
```

Promotion packets must cite the package produced by
`write_pilot_evidence_package`, the package-level reports produced by
`write_pilot_evidence_package_reports`, and the
`scripts/pilot_evidence_package_audit.jl` result for the same candidate.

Update `docs/COMPONENT_CATALOG.md`, `docs/API_REFERENCE.md`, the feature parity
ledger, and the stable promotion packet when the public surface changes.

## Performance changes

Run the quick allocation gate for changes to buffers, layout, Toolkit, styles, Markdown, virtual data, or semantics. Add a fixed workload when introducing a new performance-sensitive subsystem. Do not raise a budget solely to make CI green; document the workload change or measured tradeoff.

## Security reports

Do not submit vulnerability details through a normal issue or pull request. Follow `SECURITY.md`.

## Pull request scope

Keep changes reviewable and separate unrelated cleanup. Describe behavioral changes, compatibility impact, tests run, benchmark impact, documentation updates, and remaining risks.
