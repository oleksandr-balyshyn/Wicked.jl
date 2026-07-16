# Production Release Checklist

No release is production grade until every required item has recorded evidence.
The current worktree results and unresolved evidence are recorded in
[Release Evidence](RELEASE_EVIDENCE.md). Leave an item unchecked when evidence
exists only locally, describes CI configuration rather than an actual candidate
run, or does not cover the full platform and behavior scope of the requirement.

## Package integrity

- [ ] `Project.toml` contains every standard-library and package dependency.
- [ ] The manifest is regenerated from the supported Julia baseline.
- [ ] `using Wicked` succeeds on every supported Julia version.
- [ ] `using Wicked.API` exposes every app-facing widget, state, runtime, Toolkit,
      testing, backend, graphics, reactive, and extension contract needed by the
      reference applications.
- [ ] `scripts/loading_evidence_audit.jl --require-complete` passes for
      package-loading records in `docs/loading-evidence`.
- [ ] [Widget Stabilization Tracker](WIDGET_STABILIZATION.md) definition of done
      is satisfied for every stable widget family, with evidence attached to the
      release candidate.
- [ ] `scripts/widget_stabilization_gate.jl` passes on the immutable release
      candidate. In `--release-check` mode it rejects incomplete stable widget
      coverage and dirty git provenance before family closeout.
- [ ] `scripts/widget_family_evidence_audit.jl` proves every stable widget
      family has indexed focused docs, indexed and family-mapped public
      examples, stable API tokens mentioned in focused docs and demonstrated in
      public examples, and representative precompile workload coverage.
- [ ] Widget-family helper-function tokens are supplemental only; each stable
      family row still has at least three type-backed widget, state, pilot,
      manager, or data-model tokens.
- [ ] Every type-backed stable API token in `api/widget_family_evidence.tsv`
      has a matching precompile token, either by exact public spelling or by a
      module-qualified spelling with the same final segment.
- [ ] [Widget Family Evidence Ledger](WIDGET_FAMILY_EVIDENCE.md) is current for
      every stable widget family in the release candidate.
- [ ] The immutable candidate's `api/widget_family_evidence.tsv` is archived with
      release evidence and reviewed against artifact review criteria in
      [Widget Family Evidence Ledger](WIDGET_FAMILY_EVIDENCE.md).
- [ ] The CI `widget-family-closeout-<julia-version>` artifact is reviewed for
      every supported Julia quality job, and its
      `ci-artifacts/widget-family-closeout.md` report shows no blocked family
      before release, including blocker details when a family is not ready. The
      CI command uses `--release-check`, which bundles
      `--require-complete-coverage`, `--require-ready`, `--require-clean-git`,
      and `--require-blocked-count 0`, and the artifact upload step uses
      `if: always()` so blocked-family reports remain available for review.
      The uploaded `ci-artifacts/widget-family-closeout-summary.tsv` summary is
      reviewed for total, ready, and blocked family counts.
      Release tooling derives the expected family count with `--count` and
      asserts it with `--require-total-count`.
      Release tooling rejects dirty-worktree evidence and asserts zero blocked
      families through `--release-check`; the same wrapper rejects stable widget
      behavior-evidence gaps through `--require-complete-coverage`.
      Machine-readable `ci-artifacts/widget-family-closeout.json` rows are
      archived for dashboards and downstream release tooling, and follow
      `docs/evidence/widget_family_closeout.schema.json`.
- [ ] The CI `stable-widget-coverage-<julia-version>` artifact is reviewed for
      every supported Julia quality job. Its
      `ci-artifacts/stable-widget-coverage-status.txt` status line has zero
      incomplete coverage counts, its
      `ci-artifacts/stable-widget-coverage-summary.tsv` report shows complete
      stable widget behavior evidence, its
      `ci-artifacts/stable-widget-coverage-summary.json` artifact is archived
      for dashboards and follows
      `docs/evidence/stable_widget_coverage.schema.json`, and
      `ci-artifacts/stable-widget-coverage-gaps.md` has no missing,
      incomplete, or source-mismatched evidence rows. If that report is not
      empty, review the focused
      `ci-artifacts/stable-widget-coverage-missing-records.md`,
      `ci-artifacts/stable-widget-coverage-source-mismatches.md`, and
      `ci-artifacts/stable-widget-coverage-missing-checks.md` reports before
      release. Use the matching `*-names.txt` files when release notes or issue
      trackers need only affected widget names. For local immutable release
      evidence, rerun `scripts/render_widget_catalog.jl` with
      `--require-clean-git` before archiving coverage artifacts.
- [ ] The CI `stable-widget-coverage-<julia-version>` artifact also includes
      `ci-artifacts/stable-widget-surface-release-status.txt` and
      `ci-artifacts/stable-widget-surface-release.json` for every supported
      Julia quality job. The JSON artifact follows
      `docs/evidence/stable_widget_surface_release.schema.json`, is checked by
      `scripts/stable_widget_surface_release_schema_audit.jl`, and its
      `release_ready` value is reviewed together with coverage, stability,
      family closeout, and git provenance before publishing.
- [ ] `scripts/stable_widget_candidates.jl --require-stable` reports no
      candidate or blocked direct renderables.
- [ ] Stable widget candidate rows are backed by concrete or parameterized
      `Wicked.API` type bindings, not constructor-only function exports.
- [ ] Every direct stateful renderable has a default-state render path for
      previews, examples, and smoke tests.
- [ ] Stable compatibility widget names are first-class wrappers or explicitly
      documented state aliases; no app-facing widget name is an accidental bare
      alias. Run `scripts/compatibility_widget_alias_audit.jl`.
- [ ] The public widget-name map lists only concrete or parameterized
      `Wicked.API` widget type bindings and non-stateless state-contract type
      bindings, and every listed name appears in the focused widget, control,
      navigation, or utility API docs.
- [ ] `scripts/component_catalog_public_map.jl` reports zero unmapped direct renderables,
      with every internal direct renderable listed in the catalog exclusions.
- [ ] `Wicked.Experimental` has no app-facing bindings, or every binding has a
      documented promotion/removal plan in `api/experimental_promotions.tsv`.
- [ ] Every widget promoted during this release has a stable promotion packet
      based on [Stable Promotion Packet Template](STABLE_PROMOTION_PACKET_TEMPLATE.md)
      that cites its API decision, behavior evidence, promotion evidence,
      developer evidence, stable `Wicked.API` facade usage without internals,
      family evidence, startup evidence, compatibility evidence, and
      accepted/completed promotion review status when `Wicked.Experimental` was
      involved.
- [ ] Every promoted experimental widget archives a verified pilot evidence
      package and package-level report set. The package is produced with
      `write_pilot_evidence_package`, verified with
      `verify_pilot_evidence_package`, reported with
      `write_pilot_evidence_package_reports`, and checked with
      `verify_pilot_evidence_package_report_artifacts` and
      `scripts/pilot_evidence_package_audit.jl` so reviewers can inspect raw
      status, evidence, manifests, snapshots, summaries, and derived package
      reports from immutable release artifacts.
- [ ] Source, extensions, examples, and benchmarks do not import
      `Wicked.Experimental`.
- [ ] Public exports are free of collisions and undefined bindings.
- [ ] Package precompilation succeeds without warnings.

## Correctness

- [ ] No placeholder-only test remains as release evidence.
- [ ] Core geometry, cells, buffers, diffs, Unicode widths, and layout have unit tests.
- [ ] `scripts/unicode_width_corpus_audit.jl` passes against
      `api/unicode_width_corpus.tsv`.
- [ ] ANSI input parsing has split-sequence, malformed-sequence, and fuzz tests.
- [ ] Terminal setup and restoration are tested across thrown errors and cancellation.
- [ ] `scripts/widget_audit.jl --require-complete` records complete evidence for
      every direct renderable dimension.
- [ ] Every widget family has state-transition and snapshot tests.
- [ ] Toolkit reconciliation covers keyed moves, duplicate keys, mount, and unmount.
- [ ] Stylesheet parsing and selector specificity have property tests.
- [ ] Reactive transactions cover rollback, nested transactions, reentrant updates, and disposal.
- [ ] Virtual data covers stale pages, cancellation, failures, eviction, and stable selection.
- [ ] Accessibility trees validate and snapshot for every interactive component.
- [ ] Clipboard, file paths, Markdown links, and extension inputs have adversarial tests.

## Parity closeout

The quality gate enforces the presence of these family-level parity items so the
reference-survey follow-ups remain tied to concrete release evidence. The
machine-readable family and evidence-shape policy is
[Parity Evidence Policy](./evidence/parity_policy.json).
Run `scripts/parity_closeout_audit.jl --require-complete` before checking off
this section.

- [ ] Layout parity evidence covers constraint edge cases, clipping policy, resize
      continuity, and narrow-terminal behavior.
- [ ] Input/event parity evidence covers routed events, async delivery, cancellation
      behavior, focus restoration, and terminal lifecycle recovery.
- [ ] Stateful-controls parity evidence covers widget contract tests,
      state-transition tests, semantic snapshots, and stable widget candidate
      evidence.
- [ ] Data-display parity evidence covers virtual list/table/tree stress cases,
      stale data, loading/error slots, and screen-reader semantic state.
- [ ] Runtime parity evidence covers queue replacement, task cancellation races,
      redraw determinism, resource cleanup, and subscription shutdown.
- [ ] Developer-experience parity evidence covers API contract tests,
      Pilot/semantic query evidence, migration notes, examples, and
      documentation build output.
- [ ] Styling/theming parity evidence covers selector specificity, cascade order,
      role downgrade behavior, diagnostics, and monochrome fallback.
- [ ] Remote-delivery parity evidence covers browser deployment, WebSocket
      hardening, protocol versioning, security policy, and real-client
      compatibility.
- [ ] Remote-delivery evidence records use
      `docs/REMOTE_DELIVERY_EVIDENCE_TEMPLATE.md` for browser/WebSocket
      deployment and protocol validation.
- [ ] `scripts/remote_protocol_fixture_audit.jl` passes against
      `api/remote_protocol_fixtures.tsv`.

## Performance

- [ ] Buffer diff benchmarks cover sparse and full-screen updates.
- [ ] Layout benchmarks cover deep flex/grid trees.
- [ ] Toolkit benchmarks cover stable trees and high-churn keyed reconciliation.
- [ ] Markdown and stylesheet parsing benchmarks cover large documents.
- [ ] Virtual list/table benchmarks cover one million logical rows.
- [ ] Allocation budgets are defined for idle frames and common input events.
- [ ] Diagnostics disabled mode has a measured negligible overhead.
- [ ] `scripts/benchmark_evidence_audit.jl --require-complete` passes for
      completed records in `docs/benchmark-evidence`.

## Terminal compatibility

Record the manual results with the [Linux Real-Terminal Matrix](REAL_TERMINAL_MATRIX.md).
`scripts/quality_gate.jl` checks the worksheet shape; release readiness still
requires actual terminal transcripts, screenshots, recordings, or CI artifacts.

- [ ] Minimal ANSI and 16-color terminals.
- [ ] 256-color and truecolor terminals.
- [ ] Kitty and WezTerm graphics.
- [ ] Sixel-capable terminal.
- [ ] tmux and GNU screen.
- [ ] SSH session with unknown pixel dimensions.
- [ ] Bracketed paste, focus events, mouse modes, and resize behavior.
- [ ] Unicode narrow, wide, combining, emoji, and ambiguous-width cases,
      including the checked-in Unicode width corpus.

## Documentation

- [ ] Getting-started examples execute in CI.
- [ ] Public examples import `Wicked.API`, assert deterministic behavior, and
      avoid root, internal, or experimental Wicked modules. Run
      `scripts/public_examples_audit.jl`.
- [ ] Every required public quickstart family has an example file and examples
      index entry. Run `scripts/example_family_audit.jl`.
- [ ] Immediate-mode application tutorial.
- [ ] Toolkit application tutorial.
- [ ] Widget and component API reference.
- [ ] Widget stabilization status and promotion policy are current.
- [ ] Styling and theme guide.
- [ ] Async commands, subscriptions, and cancellation guide.
- [ ] Accessibility and testing guide.
- [ ] `scripts/semantic_accessibility_evidence_audit.jl --require-complete`
      passes for completed semantic and action-dispatch records in
      `docs/semantic-evidence`.
- [ ] Migration guide from the original Wicked.jl prototype.
- [ ] Comparison and migration notes for Ratatui, Textual, TamboUI, and Lanterna users.
- [ ] Public docs describe `Wicked.API` as the normal app import path and
      `Wicked.Experimental` as compatibility-only when applicable.
- [ ] `scripts/documentation_evidence_audit.jl --require-complete` passes for
      strict Documenter manual records in `docs/documentation-evidence`.

## Release engineering

- [ ] CI covers all supported Julia versions on Linux.
- [ ] CI has no operating-system matrix and no non-Linux runners.
- [ ] Formatting, static analysis, docs, tests, and benchmarks have explicit gates.
- [ ] SemVer policy and deprecation window are documented.
- [ ] Changelog contains user-visible additions, changes, and removals.
- [ ] Security reporting policy exists.
- [ ] License and third-party notices are complete.
- [ ] Release candidate is tested in at least two real applications using
      `Wicked.API` without importing Wicked internals or `Wicked.Experimental`.
- [ ] `scripts/application_evidence_audit.jl --require-complete` passes for
      completed records in `docs/application-evidence`.
- [ ] Final tag is created only after all blocking evidence is archived.
