# Widget Coverage Audit

Wicked derives its authoritative immediate-renderable inventory from concrete `render!` methods whose first argument is `Buffer`. The versioned ledger at `api/widget_coverage.tsv` records every discovered type, stateless and stateful render modes, source ownership, and evidence across ten required behavior dimensions.

## Coverage dimensions

| Column             | Required evidence                                                                    |
| ------------------ | ------------------------------------------------------------------------------------ |
| `zero_size`        | Rendering into an empty area and zero-sized buffer                                   |
| `minimal`          | Smallest meaningful dimensions and narrow-terminal behavior                          |
| `clipped`          | Partial intersection with buffer and parent clip                                     |
| `resize`           | State and rendering behavior across dimension changes                                |
| `state_transition` | Explicit state mutation and invalid or boundary transitions                          |
| `snapshot`         | Stable visual buffer assertion under declared capabilities and width policy          |
| `toolkit`          | Declarative element integration where promised                                       |
| `semantics`        | Role, label, bounds, states, and actions where applicable                            |
| `keyboard`         | Keyboard-only operation where applicable                                             |
| `pointer`          | Mouse or pointer operation where applicable                                          |

Each evidence cell has one of these forms:

- `missing` means the behavior is not yet proven.
- `n/a:<reason>` records why the dimension does not apply.
- `test/<file>.jl:<testset>` identifies the automated evidence owner.

Source mention or a passing unrelated suite is not valid evidence. The testset must exercise the stated dimension for that renderable type.

## Commands

Regenerate inventory metadata while preserving existing evidence cells:

```sh
julia --project=. --startup-file=no scripts/widget_audit.jl --write-baseline
```

Check schema, renderable inventory drift, source ownership, referenced test files,
evidence for every implemented keyboard and pointer handler, and state contracts
for every stateful renderer. Every direct renderable must also have Toolkit
interoperability, validated semantic-tree evidence, and a golden visual snapshot:

```sh
julia --project=. --startup-file=no scripts/widget_audit.jl
```

Require every dimension to contain evidence or a reviewed non-applicability reason:

```sh
julia --project=. --startup-file=no scripts/widget_audit.jl --require-complete
```

CI runs the strict `--require-complete` check on both the minimum and current
supported Julia lines. Inventory drift, invalid evidence, or any `missing`
ledger cell therefore blocks every change rather than being deferred until a
release candidate.

The current ledger contains 58 direct renderable types and 580 required
dimension cells. All 580 cells contain automated evidence or a reviewed,
specific non-applicability reason. This is worktree evidence; it does not
replace the platform and real-terminal evidence required for a production
release.

## Scope boundary

The ledger covers types that participate directly in the open immediate `render!` contract. Declarative-only components, managers, services, data sources, and helper values require their own integration suites and are not made complete by this ledger. A new rendering function that bypasses `render!` is an API-design review item rather than an automatic widget exemption.
