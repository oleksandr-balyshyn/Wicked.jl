# Benchmark Evidence Record Template

Use this template for one immutable release-candidate benchmark run. Store
completed records under `docs/benchmark-evidence/`; keep local drafts and raw
experiment notes outside the repository.

## Record identity

| Field | Value |
| --- | --- |
| Release-candidate commit | short or full git commit SHA |
| Date and UTC time | YYYY-MM-DD HH:MM:SS UTC |
| Julia version | Julia version, for example 1.10.11 or 1.12.6 |
| Linux distribution, kernel, architecture, and shell | |
| Active project and manifest digest | |
| Benchmark command | |
| Exit status | non-negative integer process exit code |
| Benchmark artifact path or CI URL | |
| Budget file digest | |
| Samples and warmups | |

## Workloads checked

Record the benchmark groups exercised by this run.

| Workload group | Result |
| --- | --- |
| Buffer diff | |
| Sparse and full-screen buffer diff | |
| Unicode width | |
| Runtime input and idle draw | |
| Diagnostics overhead | |
| Services pulse | |
| Actions and routed events | |
| Animations | |
| Layout | |
| Deep flex and grid layout | |
| Stylesheet parsing and cascade | |
| Toolkit reconciliation | |
| High-churn Toolkit reconciliation | |
| Markdown parsing and rendering | |
| Large Markdown and stylesheet documents | |
| Virtual data | |
| Million-row virtual list and table windows | |
| Semantic diffing | |
| Progress and live-display workloads | |

## Evidence summary

Record allocation-budget status, benchmark artifact names, checksum details, and
any diagnostic timing observations.

- 

## Regression review

Record regressions, budget changes, accepted tradeoffs, or follow-up work.

- 
