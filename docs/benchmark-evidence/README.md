# Benchmark Evidence Records

Store completed release-candidate benchmark evidence in this directory. Use one
Markdown file per release-candidate commit, copied from
`../BENCHMARK_EVIDENCE_TEMPLATE.md`.

Run the benchmark evidence audit from the repository root:

```sh
julia --project=. --startup-file=no scripts/benchmark_evidence_audit.jl
```

Before publishing a production-ready release candidate, require at least one
valid benchmark record:

```sh
julia --project=. --startup-file=no scripts/benchmark_evidence_audit.jl --require-complete
```

The benchmark command should normally be:

```sh
julia --project=. --startup-file=no benchmark/run.jl --check --output=release-evidence/benchmark/results.toml
```

The audit rejects placeholder text, missing workload groups, invalid release
identity, missing artifacts, duplicate candidate records, and records that do not
reference `benchmark/run.jl --check`.

The required workload table intentionally includes both broad subsystem groups
and release-checklist scale cases. Records must explicitly cover sparse and
full-screen buffer diffs, deep flex/grid layout, high-churn Toolkit
reconciliation, large Markdown and stylesheet documents, and million-row virtual
list/table windows rather than relying on generic group names alone.

Wall-clock times are diagnostic. Allocation budget failures block release unless
the release notes explain an approved workload change or measured tradeoff.
