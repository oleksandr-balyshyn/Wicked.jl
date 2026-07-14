# Benchmark Evidence Record

## Record identity

| Field | Value |
| --- | --- |
| Release-candidate commit | e73b2740c522af7d54d0d17e33bcacfd90cedf77 |
| Date and UTC time | 2026-07-14 00:46:29 UTC |
| Julia version | 1.12.6 |
| Linux distribution, kernel, architecture, and shell | Ubuntu 24.04, Linux 7.0.0-27-generic, x86_64, bash |
| Active project and manifest digest | Project.toml and Manifest-v1.12.toml sha a7d71591ec6a888f4d9893c8ad82d7b64b6415e6842962013c7084c491dc77a9 |
| Benchmark command | julia --project=. --startup-file=no benchmark/run.jl --check |
| Exit status | 0 |
| Benchmark artifact path or CI URL | docs/benchmark-evidence/artifacts/benchmark-e73b274-check.log |
| Budget file digest | sha256: 60b98ef72f2a574334e1ca11f8183a9d1246fd061fae7d45670e962e01f88559 |
| Samples and warmups | samples=20, warmups=3 |

## Workloads checked

| Workload group | Result |
| --- | --- |
| Buffer diff | Pass |
| Sparse and full-screen buffer diff | Pass |
| Unicode width | Pass |
| Runtime input and idle draw | Pass |
| Diagnostics overhead | Pass |
| Services pulse | Pass |
| Actions and routed events | Pass |
| Animations | Pass |
| Layout | Pass |
| Deep flex and grid layout | Pass |
| Stylesheet parsing and cascade | Pass |
| Toolkit reconciliation | Pass |
| High-churn Toolkit reconciliation | Pass |
| Markdown parsing and rendering | Pass |
| Large Markdown and stylesheet documents | Pass |
| Virtual data | Pass |
| Million-row virtual list and table windows | Pass |
| Semantic diffing | Pass |
| Progress and live-display workloads | Pass |

## Evidence summary

The benchmark suite produced successful timing and allocation snapshots across all required workload groups. Representative entries include `buffer_diff_sparse`, `layout_deep_flex_128`, `virtual_list_million_rows`, `virtual_table_million_rows`, and `semantic_diff_1000_nodes`.

## Regression review

One historical CLI bug was observed when using `benchmark/run.jl --check --output=<path>` with a `SubString` output argument in this repo environment.
Current evidence uses direct `--check` execution without an explicit output flag and passes.
