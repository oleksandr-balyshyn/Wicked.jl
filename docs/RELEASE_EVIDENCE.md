# Release Evidence

This page records acceptance commands executed against the current Wicked.jl worktree. It distinguishes observed results from configured CI jobs and unexecuted manual gates. It does not declare a production release candidate complete.

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
| Stable API baseline SHA-256 | `477b782ffe1d604c9ce1408510b3adbc8437cd63dc5c6ab4319ad1288daec94a`             |
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
| Minimum Julia compatibility  | Julia 1.10.11, version-specific manifest                        | Instantiate, precompile, load, and all 4,352 tests passed without warnings      |
| Current Julia compatibility  | Julia 1.12.6, version-specific manifest                         | Instantiate, precompile, load, and all 4,352 tests passed without warnings      |
| Focused acceptance widgets   | `test/acceptance_widgets.jl`                                    | 20 passed, 0 failed, 0 skipped                                                  |
| Isolated package suite       | `Pkg.test()`                                                    | 4,352 passed per runtime, 0 failed; no retries or skips reported                |
| Strict widget audit          | `scripts/widget_audit.jl --require-complete`                    | 58 renderables and 580 of 580 required dimension cells complete on both runtimes |
| API audit                    | `scripts/api_audit.jl --write-baseline`                         | 3 root, 379 stable, and 1,612 experimental names recorded                       |
| Repository quality          | `scripts/quality_gate.jl`                                       | Syntax, exports, ambiguities, optional loading, API baselines, docs, policies, and links passed |
| Public examples              | every `examples/*.jl` in a separate process                     | 5 of 5 passed                                                                  |
| Documenter manual            | `docs/make.jl` in the docs environment                          | Doctests, expansion, cross-references, document checks, and HTML build passed   |
| Optional HTTP extension      | temporary environment with `HTTP` 2.5.4                         | 8 passed, 0 failed                                                             |
| Browser client syntax        | `node --check assets/remote/wicked-remote.js`                   | Passed                                                                          |
| Unix pseudo-terminal gate    | `scripts/pty_gate.jl`                                           | Normal, error, interrupt, and signal scenarios passed; 1,438 transcript bytes   |
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
- An attached CI run for Julia 1.10 and current Julia across Linux, macOS, and Windows.
- Candidate PTY results from both Linux and macOS CI jobs.
- Windows ConPTY lifecycle, resize, input, interrupt, and restoration evidence.
- Manual results for minimal ANSI, 256 color, truecolor, Kitty or WezTerm, Sixel, iTerm2, Windows Terminal, tmux, GNU screen, SSH, redirected output, Unicode, paste, focus, mouse, resize, and graphics fallback.
- Immutable-candidate repetition of the complete 58-renderable, 580-dimension widget ledger and review of its golden snapshots.
- Race and failure-injection evidence for every manager listed in the validation strategy.
- Snapshot review and approval metadata for an immutable candidate.
- Tests of the candidate in at least two independent real applications.
- Commit identifier, CI run URL, snapshot approvals, benchmark artifact, known-risk approval, and final tag evidence.

CI configuration is not a substitute for the corresponding run. Headless buffers cannot verify glyph appearance or graphics support on terminals that did not execute the application.

## Candidate repetition procedure

Run the gates in the order defined by the [Validation Strategy](./VALIDATION_STRATEGY.md). Record the immutable commit, clean depot, manifest digest, command output, exit status, test count, skips, retries, benchmark artifact, and actual workflow URL. Complete the manual matrix in [Terminal Compatibility Evidence](./TERMINAL_COMPATIBILITY.md), then update the [Release Checklist](./RELEASE_CHECKLIST.md) only for requirements supported by attached evidence.
