# Release Evidence

This page records acceptance commands executed against the current Wicked.jl worktree. It distinguishes observed results from configured CI jobs and unexecuted manual gates. It does not declare a production release candidate complete.

> **Staleness note:** the evidence below predates the latest API-stabilization
> work that moved the reviewed experimental surface into `Wicked.API`. Do not use
> the recorded API baseline hashes, symbol counts, or test totals as evidence for
> the current worktree until the candidate repetition procedure is rerun.

## Evidence identity

| Field                    | Recorded value                                                                    |
| ------------------------ | --------------------------------------------------------------------------------- |
| Recorded at              | 2026-07-11 07:10:01 UTC                                                           |
| Julia                    | 1.12.6                                                                            |
| Validated Julia lines    | 1.10.11 and 1.12.6                                                                |
| Kernel                   | Linux 7.0.0-27-generic                                                            |
| Architecture             | x86_64                                                                            |
| CPU                      | `znver3`                                                                          |
| Julia threads            | 1                                                                                 |
| Commit identifier        | Not recorded; this is worktree evidence, not immutable candidate evidence         |
| Julia 1.10 manifest SHA-256 | `346c1b62a4261bc0bc0cd5f7fad65b4ebfa7fc55a91802f98329827c3ac7c0e6`             |
| Julia 1.12 manifest SHA-256 | `a7d71591ec6a888f4d9893c8ad82d7b64b6415e6842962013c7084c491dc77a9`             |
| Root API baseline SHA-256 | `743e60bcbb3432b019c4f68f3fbe8aaffa0f3275394ebbc1bb3e8492c94bca6a`               |
| Stable API baseline SHA-256 | Changed after wrapper promotions; rerun `scripts/api_audit.jl --write-baseline` |
| Experimental API baseline SHA-256 | `c7c15cbb9b1160b41e22c871384f534e3a2c43ff84d4ef5e7aaa2e44bd4bbe1f`       |
| Benchmark budget SHA-256 | `562ee7beacc30cbebd6b0285a3dc3938b27a01778c2cb3e8c43d6ea92c41f156`               |

The manifest digests identify the dependency graphs selected automatically by their matching Julia minor versions. The other digests identify acceptance inputs, but none identifies uncommitted source changes. A release candidate must repeat every mandatory gate from an immutable commit and attach the actual CI run.

## Observed automated results

Every result in this table was observed in a fresh process during the same worktree audit. A configured workflow that was not executed is not listed as passing evidence.

| Gate                         | Command or scope                                                | Observed result                                                                 |
| ---------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Package loading              | `using Wicked`                                                  | Passed; package precompiled and loaded                                          |
| Clean-depot package loading  | fresh `JULIA_DEPOT_PATH`, instantiate, precompile, and load     | Passed without using the normal depot's package or compiled caches              |
| Clean-depot package suite    | `Pkg.test()` in the same fresh depot                            | Earlier 3,672-test run passed; repeat with the expanded suite is pending        |
| Minimum Julia compatibility  | Julia 1.10.11, version-specific manifest                        | Earlier 4,352-test run passed; repeat after wrapper, example, and audit changes is pending |
| Current Julia compatibility  | Julia 1.12.6, version-specific manifest                         | Earlier 4,352-test run passed; repeat after wrapper, example, and audit changes is pending |
| Focused acceptance widgets   | `test/acceptance_widgets.jl`                                    | 20 passed, 0 failed, 0 skipped                                                  |
| Isolated package suite       | `Pkg.test()`                                                    | Earlier 4,352-test run passed per runtime; repeat with current worktree is pending |
| Strict widget audit          | `scripts/widget_audit.jl --require-complete`                    | Checked-in ledger records 173 renderables and 1,730 required dimension cells; audit rerun pending |
| API audit                    | `scripts/api_audit.jl --write-baseline`                         | Checked-in baselines currently record 3 root, 2,186 stable, and 1 experimental names; audit rerun pending |
| Repository quality          | `scripts/quality_gate.jl`                                       | Earlier gate passed; repeat after compatibility-alias audit, component-catalog contract, examples-index, and real-terminal matrix policy changes is pending |
| Public examples              | every `examples/*.jl` in a separate process                     | Earlier 5-example run passed; repeat with the current 6-example index is pending |
| Documenter manual            | `docs/make.jl` in the docs environment                          | Earlier build passed; repeat after docs additions is pending                    |
| Optional HTTP extension      | temporary environment with `HTTP` 2.5.4                         | 8 passed, 0 failed                                                             |
| Browser client syntax        | `node --check assets/remote/wicked-remote.js`                   | Passed                                                                          |
| Linux pseudo-terminal gate   | `scripts/pty_gate.jl`                                           | Normal, error, interrupt, and signal scenarios passed; 1,438 transcript bytes   |
| Allocation benchmark gate    | `benchmark/run.jl --quick --check`                              | 22 of 22 workloads remained within versioned allocation budgets                |

The package suite covers rendering foundations, buffers, geometry, layout, ANSI input, immediate widgets, editing, selection, terminal lifecycle, remote transport, managed runtime, styling, testing APIs, capabilities, allocation limits, color detection, inline mode, recovery, enhanced keyboard input, mouse modes, terminal commands, process and clipboard commands, subscriptions, reactive lifecycle, public extension contracts, toolkit reconciliation, virtual data, semantics, fuzz input, stylesheet parsing, and adversarial boundaries.

## Benchmark evidence

The quick gate records time and allocations for fixed workloads. Allocation budgets are acceptance limits; single-host wall-clock values are diagnostic and are not portable release thresholds.

| Workload group               | Recorded coverage                                                                       |
| ---------------------------- | --------------------------------------------------------------------------------------- |
| Buffer                       | Sparse and full buffer diff                                                             |
| Unicode                      | Large grapheme-width corpus                                                             |
| Runtime                      | Idle terminal draw and common focused-button input                                      |
| Diagnostics                  | 1,000 input records with diagnostics disabled and enabled                               |
| Services                     | Idle application-service pulse                                                          |
| Actions and events           | 256 competing action bindings and Tab routing through 128 keyed elements                |
| Animations                   | Mid-progress tick across 256 active tracks                                              |
| Layout                       | 4,096 grid cells and 128 nested flex containers                                         |
| Styles                       | 512-rule cascade and stylesheet parsing                                                 |
| Toolkit                      | Stable and moved reconciliation across 256 children                                     |
| Rich content                | Parse and render 500 Markdown sections                                                   |
| Virtual data                | List and table projection over one million logical rows                                 |
| Accessibility               | Semantic diff across 1,000 nodes                                                        |

The disabled diagnostics workload recorded approximately 0.056 ms and 32 KiB per 1,000 events on this host; the equivalent enabled workload recorded approximately 4.0 ms and 2.0 MiB. Common button input recorded zero allocations. An idle application-service pulse recorded 320 bytes. These values require repetition on the candidate hardware before being treated as a regression baseline.

## Documentation build status

The strict Documenter build passes without warnings. Generated API documentation is partitioned by responsibility so every page remains below Documenter's HTML size warning threshold. The repository navbar link is explicitly disabled until an authoritative deployment remote is configured; local source, edit, and repository links are not inferred from an unrelated checkout remote.

## Evidence not established

The following mandatory evidence remains missing or too weak to support a production claim:

- A clean-depot repetition from an immutable release-candidate commit. The current worktree passed this procedure on Julia 1.10.11 and 1.12.6, but it has no immutable candidate identity.
- An attached Linux CI run for Julia 1.10 and current Julia.
- Candidate Linux PTY results from CI.
- Manual results for minimal ANSI, 256 color, truecolor, Kitty or WezTerm, Sixel, tmux, GNU screen, SSH, redirected output, Unicode, paste, focus, mouse, resize, and graphics fallback, recorded with the Linux real-terminal matrix and Terminal Evidence Record Template.
- `scripts/terminal_evidence_audit.jl --require-complete` has not been run
  against completed records in `docs/terminal-evidence`.
- `scripts/application_evidence_audit.jl --require-complete` has not been run
  against at least two completed independent application records in
  `docs/application-evidence`.
- `scripts/benchmark_evidence_audit.jl --require-complete` has not been run
  against completed benchmark records in `docs/benchmark-evidence`.
- `scripts/loading_evidence_audit.jl --require-complete` has not been run
  against package-loading records for at least two supported Julia versions in
  `docs/loading-evidence`.
- `scripts/documentation_evidence_audit.jl --require-complete` has not been run
  against strict Documenter manual records for at least two supported Julia
  versions in `docs/documentation-evidence`.
- `scripts/semantic_accessibility_evidence_audit.jl --require-complete` has not
  been run against semantic snapshot and action-dispatch records for every
  stable widget family in `docs/semantic-evidence`.
- Immutable-candidate repetition of the complete 173-renderable, 1,730-dimension widget ledger and review of its golden snapshots.
- Immutable-candidate repetition of the widget stabilization release review in
  `docs/WIDGET_STABILIZATION.md`, including stable-candidate, experimental
  promotion, compatibility-widget alias, examples, docs, and precompile evidence.
- Stable promotion packets based on
  `docs/STABLE_PROMOTION_PACKET_TEMPLATE.md` for every widget promoted in the
  candidate, with accepted or completed review status when `Wicked.Experimental`
  was involved. Run `scripts/stable_promotion_packet_audit.jl` against completed
  records in `docs/stable-promotion-packets`. Each completed packet must cite
  stable `Wicked.API` facade usage without internals, the matching
  `write_pilot_evidence_package` output, the
  `write_pilot_evidence_package_reports` output, and
  `scripts/pilot_evidence_package_audit.jl` result for the same immutable
  candidate.
- Immutable-candidate execution of `scripts/widget_family_evidence_audit.jl`
  proving every stable widget family has indexed focused docs, indexed and
  family-mapped public examples, stable API tokens mentioned in focused docs and
  demonstrated in public examples, representative precompile workload coverage,
  and matching `precompile_token` coverage for every type-backed
  `stable_api_token`.
- Archived `api/widget_family_evidence.tsv` from the immutable candidate commit
  so reviewers can inspect the exact family evidence rows used by the audit.
  Store it with the command shown in
  [Widget Family Evidence Ledger](WIDGET_FAMILY_EVIDENCE.md), including the
  UTC capture time, candidate commit identity, Julia version, Linux environment,
  SHA-256 digest, audit stdout, audit stderr, audit exit status, and artifact
  manifest.
- Archived CI `widget-family-closeout-<julia-version>` artifacts for every
  supported Julia quality job, each containing
  `ci-artifacts/widget-family-closeout.md` and
  `ci-artifacts/widget-family-closeout-summary.tsv`, plus machine-readable
  `ci-artifacts/widget-family-closeout.json`, so reviewers can inspect the exact
  family-level ready/blocked status, blocker details, compact
  total/ready/blocked counts, and dashboard-ready `schema_version`, `metadata`,
  `summary`, and `families` rows used during release closeout. The command must
  include `--require-blocked-count 0`. When available,
  `metadata.git_commit` must match the immutable candidate commit and
  `metadata.git_dirty` must be `false`. The CI command must use
  `--release-check` to require ready families, reject dirty-worktree evidence,
  and assert zero blocked families, must use `--count` and
  `--require-total-count` so the expected stable-family count is derived and
  asserted, and the upload step must use `if: always()` so the failure reports
  remain available. The JSON artifact must follow
  `docs/evidence/widget_family_closeout.schema.json`.
- Archived CI stable widget surface-release artifacts for every supported Julia
  quality job, each containing
  `ci-artifacts/stable-widget-surface-release-status.txt` and
  `ci-artifacts/stable-widget-surface-release.json`. The JSON artifact must
  follow `docs/evidence/stable_widget_surface_release.schema.json`, pass
  `scripts/stable_widget_surface_release_schema_audit.jl`, and report
  `release_ready` consistently with coverage readiness, stability readiness,
  family closeout readiness, and git provenance for the immutable candidate.
- Review of [Widget Family Evidence Ledger](WIDGET_FAMILY_EVIDENCE.md) proving
  the release candidate's family evidence rows match the documented column
  contract, including matching `precompile_token` coverage for every
  type-backed `stable_api_token` by exact public spelling or module-qualified
  spelling with the same final segment.
- Immutable-candidate execution of `scripts/public_examples_audit.jl` proving
  runnable examples use `Wicked.API`, assert deterministic behavior, and avoid
  root, internal, or experimental Wicked modules.
- Immutable-candidate execution of `scripts/example_family_audit.jl` proving
  every required public quickstart family has an example file and examples index
  entry.
- Immutable-candidate execution of `scripts/unicode_width_corpus_audit.jl`
  proving the checked-in `api/unicode_width_corpus.tsv` still matches
  grapheme segmentation, default-width policy, and ambiguous-width policy.
- Archived `api/unicode_width_corpus.tsv`, audit stdout/stderr, audit exit
  status, and SHA-256 digest for the release-candidate commit.
- Immutable-candidate execution of `scripts/remote_protocol_fixture_audit.jl`
  proving the checked-in `api/remote_protocol_fixtures.tsv` still matches the
  protocol-v1 remote packet envelope for hello, frame, event, and
  acknowledgement messages.
- Archived `api/remote_protocol_fixtures.tsv`, audit stdout/stderr, audit exit
  status, and SHA-256 digest for the release-candidate commit.
- Layout parity closeout evidence for constraint edge cases, clipping policy, resize continuity, and narrow-terminal behavior.
- Input/event parity closeout evidence for routed events, async delivery, cancellation behavior, focus restoration, and terminal lifecycle recovery.
- Stateful-controls parity closeout evidence for widget contract tests, state-transition tests, semantic snapshots, and stable widget candidate evidence.
- Data-display parity closeout evidence for virtual list/table/tree stress cases, stale data, loading/error slots, and screen-reader semantic state.
- Runtime parity closeout evidence for queue replacement, task cancellation races, redraw determinism, resource cleanup, and subscription shutdown.
- Developer-experience parity closeout evidence for API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output.
- Styling/theming parity closeout evidence for selector specificity, cascade order, role downgrade behavior, diagnostics, and monochrome fallback.
- Remote-delivery parity closeout evidence for browser deployment, WebSocket hardening, protocol versioning, security policy, and real-client compatibility, captured with `docs/REMOTE_DELIVERY_EVIDENCE_TEMPLATE.md`.
- `scripts/parity_closeout_audit.jl --require-complete` has not been run
  against final records for every reviewed adapted parity family.
- Race and failure-injection evidence for every manager listed in the validation strategy.
- Snapshot review and approval metadata for an immutable candidate.
- Tests of the candidate in at least two independent real applications that use
  `Wicked.API` without importing Wicked internals or `Wicked.Experimental`.
- Commit identifier, CI run URL, snapshot approvals, benchmark artifact, known-risk approval, and final tag evidence.

CI configuration is not a substitute for the corresponding run. Headless buffers cannot verify glyph appearance or graphics support on terminals that did not execute the application.

## Candidate repetition procedure

Run the gates in the order defined by the [Validation Strategy](./VALIDATION_STRATEGY.md). Record the immutable commit, clean depot, manifest digest, command output, exit status, test count, skips, retries, benchmark artifact, and actual workflow URL. Complete the manual matrix in [Terminal Compatibility Evidence](./TERMINAL_COMPATIBILITY.md), then update the [Release Checklist](./RELEASE_CHECKLIST.md) only for requirements supported by attached evidence.

For adapted parity families, attach one
[Parity Evidence Record Template](./PARITY_EVIDENCE_TEMPLATE.md) record per
family and environment class under [`docs/evidence`](./evidence/README.md) before
checking off the corresponding parity closeout item. Follow the creation rules in
[`docs/evidence/README.md`](./evidence/README.md) so quality-gate validation can
distinguish release-candidate evidence from local notes. Keep
[`docs/evidence/parity_policy.json`](./evidence/parity_policy.json) synchronized
with any change to adapted parity families, required fields, or required
sections. Run `scripts/parity_closeout_audit.jl --require-complete` before
claiming production reference-library parity.
