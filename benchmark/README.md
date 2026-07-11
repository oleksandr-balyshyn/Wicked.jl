# Wicked.jl benchmarks

The benchmark suite measures fixed production workloads without adding dependencies to the core package. It records elapsed time, allocations, and a result checksum. Allocation budgets are versioned in `budgets.toml`; wall-clock measurements are informational because they are not comparable across different hardware.

Run a short local sample:

```sh
julia --project=. benchmark/run.jl --quick
```

Run the allocation gate with the default warmup and sample counts:

```sh
julia --project=. benchmark/run.jl --check
```

Write machine-readable TOML evidence:

```sh
julia --project=. benchmark/run.jl --check --output=benchmark/results.toml
```

Environment controls:

- `WICKED_BENCH_SAMPLES` sets measured samples. The default is `20`.
- `WICKED_BENCH_WARMUPS` sets warmup iterations. The default is `3`.
- `WICKED_BENCH_OUTPUT` sets an optional TOML output path.

`--quick` always uses one warmup and three measured samples. `--list` prints stable case identifiers without executing workloads.

The suite currently covers sparse and full-screen buffer diffs, Unicode width, large grid and deep flex layout, selector cascade and stylesheet parsing, stable and moved keyed reconciliation, large Markdown parsing/rendering, million-row virtual list/table viewports, and semantic-tree diffing.
