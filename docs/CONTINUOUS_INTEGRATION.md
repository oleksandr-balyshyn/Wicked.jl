# Continuous integration

Wicked.jl uses GitHub Actions to keep package loading, behavior, examples, documentation, and allocation budgets independently visible.

## Required jobs

| Job                         | Evidence                                                                                                      |
| --------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `Julia <version> / <os>`    | Clean instantiation, precompilation, package loading, and the complete test suite                             |
| `Quality / Julia <version>` | Source parsing, exports, ambiguities, optional loading, API baselines, docs, policies, manifests, and links   |
| `Documenter manual`         | Strict doctests, cross-references, export coverage, and HTML generation                                      |
| `HTTP WebSocket extension`  | Optional extension activation and live loopback WebSocket transport in an isolated environment               |
| `Executable examples`       | Every script in `examples/` runs independently and satisfies its assertions                                  |
| `Allocation budgets`        | Every quick benchmark stays within its versioned allocation ceiling                                          |
| `Terminal PTY / <os>`       | Real pseudo-terminal mode and protocol restoration across normal, error, interrupt, and signal exits         |

The test matrix covers Julia `1.10`, the minimum version declared by `Project.toml`, and the latest Julia `1.x` release on Linux. Wicked.jl currently supports Linux only; macOS and Windows are outside the supported CI and release matrix. The quality job runs on both Julia lines and verifies that each runtime selects its matching version-specific manifest. Matrix jobs use `fail-fast: false` so one job failure does not hide results from the others.

## Local commands

Run the same gates before opening a pull request:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); using Wicked'
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. scripts/quality_gate.jl
julia --project=. benchmark/run.jl --quick --check
julia --project=. --startup-file=no scripts/pty_gate.jl
julia --project=. --startup-file=no scripts/api_audit.jl
julia --project=. --startup-file=no scripts/parity_audit.jl
```

When both supported Julia channels are installed through `juliaup`, run the quality gate against each manifest:

```sh
julia +1.10 --project=. --startup-file=no scripts/quality_gate.jl
julia +1.12 --project=. --startup-file=no scripts/quality_gate.jl
```

Run examples independently:

```sh
for example in examples/*.jl; do
  julia --project=. "$example"
done
```

## Benchmark policy

Allocation ceilings in `benchmark/budgets.toml` are blocking and hardware-independent. Wall-clock results are diagnostic because timings from different machines are not directly comparable. Changes to a budget require an explanation of the workload change or measured tradeoff.

## Compatibility evidence

The matrix proves package-level behavior in non-interactive Linux processes. It does not replace the real-terminal compatibility matrix for Linux terminals such as Kitty, WezTerm, Sixel-capable emulators, tmux, GNU screen, SSH, or PTY lifecycle behavior. Those manual and PTY gates remain tracked in the release checklist.
