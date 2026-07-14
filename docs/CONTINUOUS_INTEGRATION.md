# Continuous integration

Wicked.jl uses GitHub Actions to keep package loading, behavior, examples, documentation, and allocation budgets independently visible.

## Required jobs

| Job                         | Evidence                                                                                                      |
| --------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `Julia <version> / ubuntu-latest` | Clean instantiation, precompilation, package loading, and the complete test suite                        |
| `Quality / Julia <version>` | Source parsing, exports, ambiguities, optional loading, API baselines, experimental promotion plans, widget promotion requirements, widget stabilization gate, public examples audit, public example family audit, component catalog contract, real-terminal matrix shape, example index coverage, default-state render policy, parity evidence records, documentation evidence records, docs, policies, manifests, and links |
| `Documenter manual`         | Strict doctests, cross-references, export coverage, and HTML generation                                      |
| `HTTP WebSocket extension`  | Optional extension activation and live loopback WebSocket transport in an isolated environment               |
| `Executable examples`       | Every script in `examples/` runs independently and satisfies its assertions                                  |
| `Allocation budgets`        | Every quick benchmark stays within its versioned allocation ceiling                                          |
| `Terminal PTY / ubuntu-latest` | Real pseudo-terminal mode and protocol restoration across normal, error, interrupt, and signal exits       |

The test matrix covers Julia `1.10`, the minimum version declared by `Project.toml`, and the latest Julia `1.x` release on Linux. The quality job runs on both Julia lines and verifies that each runtime selects its matching version-specific manifest. Matrix jobs use `fail-fast: false` so one job failure does not hide results from the others.

CI is intentionally Linux-only. The workflow must not define an operating-system
matrix or non-Ubuntu runners. `scripts/quality_gate.jl` enforces this so the
supported platform scope cannot drift silently.

## Local commands

Run the same gates before opening a pull request:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); using Wicked; using Wicked.API'
julia --project=. -e 'using Pkg; Pkg.test()'
julia --project=. scripts/quality_gate.jl
julia --project=. -e 'using Test, Wicked, Wicked.API; include("test/api_contract.jl")'
julia --project=. benchmark/run.jl --quick --check
julia --project=. --startup-file=no scripts/pty_gate.jl
julia --project=. --startup-file=no scripts/api_audit.jl
julia --project=. --startup-file=no scripts/widget_promotion_requirements_audit.jl
julia --project=. --startup-file=no scripts/widget_stabilization_gate.jl
julia --project=. --startup-file=no scripts/stable_promotion_packet_audit.jl
julia --project=. --startup-file=no scripts/render_widget_family_closeout.jl --format markdown --columns family,status,docs,examples,blockers,blocker_details --release-check --require-total-count "$(julia --project=. --startup-file=no scripts/render_widget_family_closeout.jl --count)"
julia --project=. --startup-file=no scripts/render_widget_family_closeout.jl --format json
julia --project=. --startup-file=no scripts/render_widget_family_closeout.jl --summary --format tsv
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --coverage-status
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --coverage-summary --format tsv
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --coverage-summary-json
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --coverage-gaps --format markdown
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --coverage-issue-names source_mismatch
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --stability --require-stability-ready
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --coverage-issue-names missing_record
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --coverage-issue-names missing_checks
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --coverage-status --require-clean-git
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --surface-release-status --require-surface-release-ready
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --surface-release-json
julia --project=. --startup-file=no scripts/widget_family_closeout_schema_audit.jl
julia --project=. --startup-file=no scripts/stable_widget_stabilization_schema_audit.jl
julia --project=. --startup-file=no scripts/stable_widget_surface_release_schema_audit.jl
julia --project=. --startup-file=no scripts/widget_family_evidence_audit.jl
julia --project=. --startup-file=no scripts/unicode_width_corpus_audit.jl
julia --project=. --startup-file=no scripts/remote_protocol_fixture_audit.jl
julia --project=. --startup-file=no scripts/real_terminal_matrix_audit.jl
julia --project=. --startup-file=no scripts/terminal_evidence_audit.jl
julia --project=. --startup-file=no scripts/application_evidence_audit.jl
julia --project=. --startup-file=no scripts/benchmark_evidence_audit.jl
julia --project=. --startup-file=no scripts/loading_evidence_audit.jl
julia --project=. --startup-file=no scripts/documentation_evidence_audit.jl
julia --project=. --startup-file=no scripts/semantic_accessibility_evidence_audit.jl
julia --project=. --startup-file=no scripts/pilot_evidence_package_audit.jl
julia --project=. --startup-file=no scripts/public_examples_audit.jl
julia --project=. --startup-file=no scripts/example_family_audit.jl
julia --project=. --startup-file=no scripts/experimental_promotion_audit.jl
julia --project=. --startup-file=no scripts/stable_widget_candidates.jl --require-stable
julia --project=. --startup-file=no scripts/public_widget_candidate_audit.jl
julia --project=. --startup-file=no scripts/component_catalog_public_map.jl
julia --project=. --startup-file=no scripts/component_catalog_public_map.jl --list-unmapped
julia --project=. --startup-file=no scripts/component_catalog_public_map.jl --list-exclusions
julia --project=. --startup-file=no scripts/compatibility_widget_alias_audit.jl
julia --project=. --startup-file=no scripts/parity_policy_audit.jl
julia --project=. --startup-file=no scripts/parity_closeout_audit.jl
julia --project=. --startup-file=no scripts/parity_audit.jl
```

When both supported Julia channels are installed through `juliaup`, run the quality gate against each manifest:

```sh
julia +1.10 --project=. --startup-file=no scripts/quality_gate.jl
julia +1 --project=. --startup-file=no scripts/quality_gate.jl
```

Run examples independently:

```sh
for example in examples/*.jl; do
  julia --project=. "$example"
done
```

`scripts/quality_gate.jl` also checks that every `examples/*.jl` script appears
in `examples/README.md` and that the README does not list missing example files.
It parses the public widget-name map in `docs/COMPONENT_CATALOG.md`, requires
each listed widget name and non-stateless state contract to be exported by
`Wicked.API` as concrete or parameterized type bindings, requires each widget
name and state contract to appear in the focused widget, control, navigation, or
utility API docs, and rejects any direct renderable from `api/widget_coverage.tsv`
that is neither public-mapped nor listed as an internal renderable exclusion.
`scripts/experimental_promotion_audit.jl` checks that every future
`Wicked.Experimental` binding has a promote, qualify, or remove decision recorded
in `api/experimental_promotions.tsv`.
`scripts/widget_stabilization_gate.jl` runs the widget coverage audit, stable
widget candidate audit, public widget candidate audit, widget family evidence
audit, widget promotion requirements audit, experimental promotion audit,
compatibility widget alias audit, and stable promotion packet audit as one
CI-friendly gate. In `--release-check` mode it also validates the stable
widget-surface release schema, runs the combined surface-release readiness gate,
and runs the stable widget coverage completeness check with
`--require-complete-coverage` and `--require-clean-git` before the family
closeout release check.
The stable widget candidate audit treats generic coverage values such as `ok`,
`done`, or `covered` as blockers; applicable behavior cells must cite checked-in
Julia source files, and `n/a:` cells must include a specific reason.
CI also renders stable widget coverage artifacts directly from
`scripts/render_widget_catalog.jl`: a one-line
`ci-artifacts/stable-widget-coverage-status.txt` status file, a compact
`ci-artifacts/stable-widget-coverage-summary.tsv` file, a versioned
`ci-artifacts/stable-widget-coverage-summary.json` dashboard artifact, and a
`ci-artifacts/stable-widget-coverage-gaps.md` gap report. CI also writes
issue-specific Markdown reports:
`ci-artifacts/stable-widget-coverage-missing-records.md`,
`ci-artifacts/stable-widget-coverage-source-mismatches.md`, and
`ci-artifacts/stable-widget-coverage-missing-checks.md`. Matching plain name
lists are written to
`ci-artifacts/stable-widget-coverage-missing-record-names.txt`,
`ci-artifacts/stable-widget-coverage-source-mismatch-names.txt`, and
`ci-artifacts/stable-widget-coverage-missing-check-names.txt`. The summary command
uses `--require-complete-coverage`, so missing, incomplete, or
source-mismatched stable widget behavior evidence fails the quality job after
printing the reports.
The same job writes promotion-readiness reports to
`ci-artifacts/stable-widget-stability.md` and
`ci-artifacts/stable-widget-stability-gaps.md`, plus the versioned
`ci-artifacts/stable-widget-stability.json` dashboard artifact described by
`docs/evidence/stable_widget_stability.schema.json` and audited by
`scripts/stable_widget_stability_schema_audit.jl`. The stability command uses
`--require-stability-ready`, so a reviewed widget with an unstable surface,
non-stable status, missing coverage record, source mismatch, or missing behavior
check fails the quality job after printing the reports.
CI writes the widget stabilization closeout status to
`ci-artifacts/stable-widget-stabilization-status.txt` and the machine-readable
closeout artifact to `ci-artifacts/stable-widget-stabilization.json`. The JSON
artifact is described by
`docs/evidence/stable_widget_stabilization.schema.json` and audited by
`scripts/stable_widget_stabilization_schema_audit.jl`, which checks that the
top-level `ready` decision agrees with candidate widgets, experimental widgets,
stability blockers, and family closeout blockers.
CI also writes the combined stable widget-surface release status to
`ci-artifacts/stable-widget-surface-release-status.txt` and the machine-readable
release artifact to `ci-artifacts/stable-widget-surface-release.json`. The JSON
artifact is described by
`docs/evidence/stable_widget_surface_release.schema.json` and audited by
`scripts/stable_widget_surface_release_schema_audit.jl`, which checks that the
top-level `release_ready` decision agrees with coverage, stability, family
closeout, and git metadata flags.
For a local immutable-candidate audit this is the `--surface-release-status
--require-surface-release-ready` mode.
CI renders the release-required widget promotion checklist from
`api/widget_promotion_requirements.tsv` to
`ci-artifacts/widget-promotion-requirements.md` and
`ci-artifacts/widget-promotion-requirements.json` so reviewers and dashboards can
inspect the current stable-promotion contract next to the coverage artifacts.
The JSON artifact includes summary counts by requirement area and
`release_required` value.
The JSON artifact is checked against
`docs/evidence/widget_promotion_requirements.schema.json` by
`scripts/widget_promotion_requirements_schema_audit.jl`.
CI also renders the reference parity matrix from
`docs/REFERENCE_PARITY_SURVEY.md` to
`ci-artifacts/reference-parity-matrix.md`,
`ci-artifacts/reference-parity-review.md`, and
`ci-artifacts/reference-parity-blocking.md`,
`ci-artifacts/reference-parity-blocking.json`,
`ci-artifacts/reference-parity-adapted.md`,
`ci-artifacts/reference-parity-adapted.json`,
`ci-artifacts/reference-parity-remote-delivery.md`,
`ci-artifacts/reference-parity-remote-delivery.json`,
`ci-artifacts/reference-parity-summary.tsv`,
`ci-artifacts/reference-parity-summary.json`,
`ci-artifacts/reference-parity-matrix.json`, and writes
`ci-artifacts/reference-parity-matrix-status.txt` plus
`ci-artifacts/reference-parity-matrix-status.json`. The same renderer can emit a
focused `--release-blockers` list for local release triage, and renders
`ci-artifacts/parity-closeout-requirements.md`,
`ci-artifacts/parity-closeout-requirements-status.txt`,
`ci-artifacts/parity-closeout-requirements.tsv`, and
`ci-artifacts/parity-closeout-requirements.json`, plus the focused
`ci-artifacts/parity-closeout-remote-delivery.md`, giving reviewers and
dashboards a generated view of Ratatui, Textual, TamboUI, Lanterna, and Wicked
capability alignment.
The closeout requirements JSON artifact is described by
`docs/evidence/parity_closeout_requirements.schema.json`.
The JSON artifact is checked against
`docs/evidence/reference_parity_matrix.schema.json` by
`scripts/reference_parity_matrix_schema_audit.jl`, including `summary.total` and
`summary.by_status` consistency checks against the generated rows. Its
`--release-check` mode rejects any row that is not marked `matched`, including
adapted rows that still need final parity closeout evidence. CI renders the text
status with `--require-release-ready`; when any non-`matched` row exists, the
command writes the status artifact first and then blocks the quality job. The
status JSON artifact is
checked against
`docs/evidence/reference_parity_matrix_status.schema.json` by the same audit.
The summary JSON artifact is checked against
`docs/evidence/reference_parity_summary.schema.json`. The adapted JSON artifact
uses the full matrix schema and the audit verifies that it contains only
`adapted` rows. When the full matrix reports adapted work, the audit also
requires the adapted artifact to be non-empty. The remote-delivery JSON artifact
uses the same schema and the audit verifies that it contains only the remote
delivery row.
`scripts/widget_family_evidence_audit.jl` checks that every stable widget family
has focused documentation listed in `docs/README.md`, at least one public
example path listed in `examples/README.md` and
`docs/EXAMPLE_FAMILIES.md`, stable API tokens listed in `api/stable_api.tsv`,
stable API token mentions in the focused docs and public examples, and
representative precompile workload coverage recorded in
`api/widget_family_evidence.tsv`. The full ledger contract is documented in
[Widget Family Evidence Ledger](WIDGET_FAMILY_EVIDENCE.md). Matching
`precompile_token` coverage is accepted when each type-backed
`stable_api_token` has exact spelling, or module-qualified spelling sharing the
same final segment.
`scripts/render_widget_family_closeout.jl` renders the same family ledger as a
Markdown, TSV, or JSON planning artifact so release review can see which Ratatui,
Textual, TamboUI, and Lanterna parity families are ready or blocked, including
blocker details, without loosening the stricter audit gate. CI writes the
Markdown report to `ci-artifacts/widget-family-closeout.md`, writes a compact
summary to `ci-artifacts/widget-family-closeout-summary.tsv`, writes
machine-readable versioned rows and summary data to
`ci-artifacts/widget-family-closeout.json`, prints all three in the quality-job
log, and uploads them as
`widget-family-closeout-<julia-version>`. The CI command uses
`--release-check`, which bundles stable widget coverage completeness,
`--require-ready`, `--require-clean-git`, and `--require-blocked-count 0`, so
coverage gaps, blocked families, or dirty-worktree release evidence fail the
quality job instead of relying on manual interpretation. The upload step runs
with `if: always()` so the Markdown, TSV, and JSON reports remain available when
a blocked family fails the quality job.
The stable coverage reports are uploaded separately as
`stable-widget-coverage-<julia-version>` so reviewers can inspect
`ci-artifacts/stable-widget-coverage-status.txt`,
`ci-artifacts/stable-widget-coverage-summary.tsv`,
`ci-artifacts/stable-widget-coverage-summary.json`, and
`ci-artifacts/stable-widget-coverage-gaps.md` plus the issue-specific reports
even when the coverage gate fails.
Use `--summary --format tsv` for a compact total/ready/blocked count during
local release review. Use `--require-total-count` with the value from `--count`
when release tooling should assert that every expected stable widget family is
present without duplicating the family count. Use the individual
`--require-ready`, `--require-clean-git`, and `--require-blocked-count 0` flags
for focused debugging when the combined `--release-check` is too broad.
The JSON artifact shape is versioned by
[Widget family closeout schema](./evidence/widget_family_closeout.schema.json).
The JSON includes `metadata.generated_at` and `metadata.root` so release tooling
can identify when and where the closeout artifact was produced. When the command
runs inside a git checkout, JSON metadata also includes `metadata.git_commit`
and `metadata.git_dirty` so dashboards can distinguish immutable candidate
evidence from dirty-worktree evidence.
Validate the schema and generated JSON contract with
`scripts/widget_family_closeout_schema_audit.jl`.
The stable widget coverage JSON artifact is versioned by
[Stable widget coverage schema](./evidence/stable_widget_coverage.schema.json)
and includes `metadata.generated_at` plus `metadata.root` so dashboards can
identify when and where the coverage artifact was produced. When the command
runs inside a git checkout, JSON metadata also includes `metadata.git_commit`
and `metadata.git_dirty` so dashboards can distinguish immutable candidate
evidence from dirty-worktree evidence, including untracked files. Its generated
contract is validated with
`scripts/stable_widget_coverage_schema_audit.jl`.
For immutable local release candidates, run `scripts/render_widget_catalog.jl`
with `--require-clean-git` before publishing coverage evidence.
`scripts/public_examples_audit.jl` checks that runnable examples import
`Wicked.API`, assert at least one deterministic behavior, and do not reach into
root, internal, or experimental Wicked modules.
`scripts/example_family_audit.jl` checks that each required public quickstart
family has an example file and an `examples/README.md` entry.
`scripts/parity_closeout_audit.jl` validates any final parity evidence records
committed under `docs/evidence/`. Use `--require-complete` only for release
candidates, where every reviewed adapted family must have a final record.
`scripts/documentation_evidence_audit.jl` validates completed strict Documenter
manual records under `docs/documentation-evidence/`. Use `--require-complete`
only for release candidates, where at least two supported Julia documentation
builds must have archived artifacts and strict `docs/make.jl` provenance.
`scripts/semantic_accessibility_evidence_audit.jl` validates completed semantic
and accessibility records under `docs/semantic-evidence/`. Use
`--require-complete` only for release candidates, where every stable widget
family must have semantic snapshot and action-dispatch artifacts.
Experimental widgets are promoted only after their pilot evidence is packaged
with both raw evidence and derived reports. For each promotion candidate, create
a package with `write_pilot_evidence_package`, verify it with
`verify_pilot_evidence_package`, create package-level reports with
`write_pilot_evidence_package_reports`, and verify those reports with
`verify_pilot_evidence_package_report_artifacts`. Use
`scripts/pilot_evidence_package_audit.jl` in release jobs or local release
checks to validate archived packages and any matching `--package-report-dir`
outputs. Archive the resulting `evidence/`, `reports/`, and package-level report
directories next to the promotion packet so CI and release reviewers can compare
status files, manifests, summaries, snapshots, and package-level report
manifests without rerunning the application manually.
The standalone component-catalog self-check reports these as unmapped direct
renderables. Use `scripts/component_catalog_public_map.jl --list-unmapped` when
you only need the renderable names for review or release notes. Use
`scripts/component_catalog_public_map.jl --list-exclusions` when reviewing the
intentional internal renderable exclusions.
When adding a compatibility widget name for Ratatui, Textual, TamboUI, or
Lanterna parity, update the facade, catalog, and focused API guidance in the same
change.

## Benchmark policy

Allocation ceilings in `benchmark/budgets.toml` are blocking and hardware-independent. Wall-clock results are diagnostic because timings from different machines are not directly comparable. Changes to a budget require an explanation of the workload change or measured tradeoff.

## Compatibility evidence

The matrix proves package-level behavior in non-interactive Linux processes. It does not replace the real-terminal compatibility matrix for Linux terminals such as Kitty, WezTerm, Sixel-capable emulators, tmux, GNU screen, SSH, or PTY lifecycle behavior. Those manual and PTY gates remain tracked in the release checklist.
The quality gate checks that the Linux real-terminal matrix keeps its required
categories and identity fields, but it does not convert the worksheet into
release evidence.

## Widget-family evidence token policy

The CI quality gate treats `scripts/widget_family_evidence_audit.jl` and
`docs/WIDGET_FAMILY_EVIDENCE.md` as the source of truth for stable widget-family
evidence. Every type-backed `stable_api_token` in
`api/widget_family_evidence.tsv` must have a matching `precompile_token`, either
by exact public spelling or by a module-qualified spelling with the same final
segment. Helper functions may appear as supplemental evidence, but they do not
replace type-backed widget, state, pilot, manager, or data-model coverage.
