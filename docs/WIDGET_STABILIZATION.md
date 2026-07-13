# Widget Stabilization Tracker

This tracker defines how Wicked promotes, keeps, and audits production widget
APIs. It complements [API Stabilization](API_STABILIZATION.md), [Widget Promotion
Guide](WIDGET_PROMOTION.md), [Widget Coverage Audit](WIDGET_COVERAGE.md),
[Widget Family Evidence Ledger](WIDGET_FAMILY_EVIDENCE.md), and
[Component Catalog](COMPONENT_CATALOG.md).

The goal is not only to expose many widgets. The goal is to make every stable
widget safe for application developers to depend on across releases.

## Short answer

Yes, experimental or candidate widgets can become stable. In the current baseline, `Wicked.Experimental` is intentionally empty except for the namespace marker, so there is no large experimental widget pile to bulk-promote. The active stabilization work is to keep new app-facing widgets out of `Wicked.Experimental`, graduate any future candidates through review, and close the release evidence for the already exported `Wicked.API` surface.

Treat a widget as stable only when the public API, runtime behavior, documentation, examples, precompile path, semantic metadata, Toolkit interop, and release artifacts all agree. Exporting the name is not enough.

Use this decision matrix when deciding what to do with an experimental or candidate widget:

| Current state                          | Target decision | Required action                                                                                  |
| -------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------ |
| API shape is good and evidence exists  | Promote         | Add the stable facade entry, complete the ledgers, update docs/examples, and run release gates.   |
| API shape is good but evidence is thin | Keep candidate  | Add tests, semantic coverage, Toolkit interop, examples, precompile coverage, and docs first.     |
| API shape is wrong but concept matters | Qualify         | Add a corrected stable API and keep the old name only as a documented compatibility wrapper.      |
| Concept duplicates a better widget     | Remove          | Document the migration path, update the promotion ledger, and remove the unstable public binding. |
| Concept is infrastructure-only         | Keep internal   | Do not list it in the component catalog or stable widget candidate report.                        |

The minimum promotion packet for a widget contains these artifacts:

| Artifact                           | Purpose                                                                              |
| ---------------------------------- | ------------------------------------------------------------------------------------ |
| `api/stable_api.tsv`               | Proves the stable facade exposes the public type and helper names.                    |
| `api/stable_widget_candidates.tsv` | Proves the direct renderable is stable, not candidate or blocked.                     |
| `api/widget_coverage.tsv`          | Proves render, resize, clipping, interaction, Toolkit, and semantics evidence exists. |
| `api/widget_family_evidence.tsv`   | Proves the widget family has docs, examples, API tokens, and precompile tokens.       |
| Focused API guide                  | Explains constructor keywords, state ownership, behavior, and examples.              |
| Public quickstart or gallery path  | Shows copyable application-facing usage through `Wicked.API`.                        |
| `src/Precompile.jl` workload       | Warms the normal construction, state, render, and helper paths.                       |
| Stable promotion packet            | Binds pilot evidence and release review evidence to one immutable candidate.          |

## Current policy

`Wicked.API` is the application-facing surface. A widget is stable only when it
is exported there and has evidence for rendering, state ownership, interaction,
Toolkit integration, semantics, documentation, and examples.

`Wicked.Experimental` is a compatibility namespace. It must stay empty except for
short-lived reviewed compatibility bindings that have an owner, a target
decision, and an audit row.

The current direct-renderable promotion ledger is
`api/stable_widget_candidates.tsv`. It should contain only `stable` rows before a
release candidate.

The canonical promotion checklist is
`api/widget_promotion_requirements.tsv`. It defines the release-required API,
behavior, docs, examples, semantic, Toolkit, performance, and release evidence
that must exist before an internal, candidate, or compatibility widget becomes
stable.

## Current repository status

The current application-facing widget surface is already centered on
`Wicked.API`. `Wicked.Experimental` is intentionally empty except for the
compatibility namespace marker, so there is no broad set of experimental widgets
to bulk-promote.

That does not make the widget surface release-ready by itself. A stable export
is only one input to stabilization. Release readiness still requires immutable
candidate evidence that the exported widgets behave correctly, are documented,
are covered by public examples, have semantic and Toolkit evidence, and are
warmed by representative precompile workloads.

Treat the current state as a stabilization closeout project:

1. Keep `Wicked.Experimental` empty unless a short-lived compatibility binding
   has an accepted promotion, qualification, or removal plan.
2. Keep `api/stable_widget_candidates.tsv` at only `stable` rows.
3. Close each widget family against behavior, docs, examples, semantic output,
   Toolkit interop, precompile coverage, and release evidence.
4. Add new widgets as internal or candidate first, then promote only after the
   evidence packet is complete.

Use `experimental_widget_names()`, `candidate_widget_names()`, and
`widget_stabilization_status_record()` from `Wicked.API` for a fast in-process
status check before running the heavier shell gates. Use
`widget_stabilization_blockers()` or `widget_stabilization_blockers_text()` when
reviewers need the exact blocker list without parsing the compact status line.
Use `widget_stabilization_status_json()` or
`scripts/render_widget_catalog.jl --stabilization-json` when CI or release
dashboards need machine-readable closeout evidence. The expected release
candidate state is zero experimental bindings, zero non-stable catalog
candidates, zero stability blockers, and zero family closeout blockers.

## What remains before publication

Use this release-readiness backlog after a widget or family is already exported through `Wicked.API`:

1. Close any missing coverage dimensions in `api/widget_coverage.tsv`.
2. Keep `api/stable_widget_candidates.tsv` free of `candidate` and `blocked` rows.
3. Ensure every stable family row in `api/widget_family_evidence.tsv` has matching docs, examples, stable tokens, representative API tokens, and precompile tokens.
4. Ensure each stable public widget has focused docs, a public example, semantic evidence, Toolkit interop evidence, and release notes when user-visible.
5. Generate stable promotion packets for newly promoted widgets and attach pilot evidence packages to the same immutable candidate.
6. Run the widget stabilization, family closeout, surface release, promotion packet, and pilot evidence audits before tagging.

This keeps the project aligned with Ratatui-style immediate rendering, Textual-style component trees, TamboUI-style declarative composition, and Lanterna-style conservative production use without turning compatibility names into unsupported promises.

## Stabilization levels

| Level | Meaning | Allowed use |
|---|---|---|
| Internal | Implementation detail, helper, manager, or private renderer | Not imported by applications |
| Candidate | Public concept exists but promotion evidence is incomplete | May appear in development docs only |
| Stable | Exported through `Wicked.API` with complete evidence | Safe for application code |
| Deprecated | Stable name scheduled for removal or replacement | Must have documented migration path |

Do not use `Experimental` as a long-term fourth level. If an API is not ready,
keep it internal or candidate until the evidence is complete.

## Experimental-to-stable workflow

Use this workflow when an existing experimental or candidate widget should become
stable:

1. Decide whether the public name, constructor shape, state type, and event
   results are good enough to preserve across releases.
2. If the API shape is wrong, add the corrected stable API first and keep the old
   name only as a documented compatibility wrapper.
3. Add or update the row in `api/experimental_promotions.tsv` with one of three
   outcomes: `promote`, `qualify`, or `remove`.
4. Move the row to `accepted` only after API review. A `proposed` row documents
   intent, but it cannot make the binding a stable-widget promotion candidate.
5. Add complete behavior evidence in `api/widget_coverage.tsv`.
   The `source` column must be a repository-relative path to a checked-in `.jl`
   source file. Absolute paths, path traversal, non-Julia files, and missing files block
   promotion.
6. Add the stable facade entry in `api/stable_api.tsv` as a concrete or
   parameterized type binding and ensure the widget is exported through
   `Wicked.API`.
7. Add the widget to `api/stable_widget_candidates.tsv` and require the row to
   become `stable`.
8. Add or update focused API docs, component catalog coverage, and at least one
   public example path.
9. Add precompile coverage for the normal construction, state, render, and event
   paths that applications will hit during startup.
10. Package pilot evidence with `write_pilot_evidence_package`, render the
   matching package-level reports with `write_pilot_evidence_package_reports`,
   and check both artifacts with `scripts/pilot_evidence_package_audit.jl`.
11. Run the widget stabilization gate before release review.
12. Run the combined stable widget-surface release gate and treat any failed
    coverage, stability, family-closeout, or git-provenance flag as a blocker.

Do not stabilize an experimental binding by simply moving its export. Promotion
is only complete when the old compatibility story, stable facade, coverage
evidence, docs, examples, precompile path, and release notes agree.

Use this compact checklist during review:

| Area | Required before promotion |
|---|---|
| Public API | Stable name, constructor keywords, state type, event result shape, and exported facade entry are final enough to preserve |
| Compatibility | Old experimental or compatibility name has a `promote`, `qualify`, or `remove` decision with owner and rationale |
| Behavior | Rendering, resize, clipping, keyboard, pointer, state transition, semantics, and source-path evidence are complete |
| Developer UX | API docs, README or guide snippet, copyable example, and gallery or cookbook path exist |
| Runtime | Toolkit integration, semantic query behavior, pilot evidence, and precompile workload cover the normal user path |
| Release | Family closeout is ready, coverage has no gaps, stability reports have no blockers, git metadata is clean, and `--require-surface-release-ready` passes |

Run the promotion requirement audit whenever the promotion policy changes:

```sh
julia --project=. --startup-file=no scripts/widget_promotion_requirements_audit.jl
```

## Promotion gate

Before a widget family becomes stable, every public widget and companion state
type must satisfy this checklist:

| Requirement | Evidence owner |
|---|---|
| Constructor names and keywords are documented | Focused API guide or docstring |
| State ownership is explicit | State type, `state_for`, and examples |
| Rendering is deterministic | `api/widget_coverage.tsv` evidence |
| Source file is traceable | Repository-relative `api/widget_coverage.tsv` source path |
| Small, clipped, resized, and zero-size rendering are covered | `api/widget_coverage.tsv` evidence |
| Keyboard behavior is covered or non-applicable | `api/widget_coverage.tsv` evidence |
| Pointer behavior is covered or non-applicable | `api/widget_coverage.tsv` evidence |
| Toolkit interop exists where promised | Tests and focused guide |
| Semantic tree output exists for interactive widgets | Tests and semantics guide |
| Public examples are copyable | `examples/*_quickstart.jl` or gallery |
| First-use path is warmed | `src/Precompile.jl` workload |
| API surface is audited | `api/stable_api.tsv` and candidate audit |
| Release impact is recorded | `CHANGELOG.md` when user-visible |

Promotion by export alone is not allowed.

## Stabilization batches

Promote and review widgets by family so tests, examples, and docs stay coherent.

| Family | Scope |
|---|---|
| Core layout | Blocks, borders, rows, columns, grids, overlays, scroll views |
| Text and structure | Labels, paragraphs, rules, separators, static text, rich text |
| Inputs and controls | Buttons, fields, checkboxes, radios, sliders, selects, forms |
| Navigation | Tabs, menus, breadcrumbs, rails, drawers, modals, windows |
| Data and virtualization | Tables, grids, data-state wrappers, query data sources, trees, pagers, virtual lists, virtual tables, property lists, key/value lists, metadata lists, description lists, definition lists |
| Visualization | Gauges, charts, sparklines, plots, calendars, meters, canvases |
| Rich content | Markdown, code, syntax, diff, logs, ANSI, terminal panes |
| Runtime and services | Notifications, progress, actions, themes, tracing, shutdown |
| Toolkit | Components, keyed state, reactive bindings, CSS-like styling |
| Testing and semantics | Widget pilots, Toolkit pilots, queries, accessibility trees |

Each batch should land with matching tests, docs, examples, and precompile
coverage in the same pull request.

## Commands for release review

Run these checks from the repository root before treating the widget surface as
release-ready:

```sh
julia --project=. --startup-file=no scripts/widget_stabilization_gate.jl
```

The wrapper runs the source-level stabilization gate used before release review.
It does not replace examples, docs, precompile, Linux CI, real-terminal, or
immutable-candidate evidence.

Use the stricter release mode when the question is whether the stable widget
surface is ready to publish:

```sh
julia --project=. --startup-file=no scripts/widget_stabilization_gate.jl --release-check
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --stabilization-status --require-stabilization-ready
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --stabilization-blockers
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --stabilization-json
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --surface-release-status --require-surface-release-ready
julia --project=. --startup-file=no scripts/pilot_evidence_package_audit.jl --require-complete
```

Release mode runs the normal stabilization gate and adds stable widget coverage
completeness plus the family closeout release check. It also validates the
stable widget-surface release JSON schema before checking the combined release
status. The coverage step rejects missing, incomplete, or source-mismatched
behavior evidence and requires clean git provenance. The closeout step requires
every indexed widget family to be ready, requires zero blocked families, and
requires clean release metadata. It is the gate to use before saying that
formerly experimental or candidate widgets are stable enough for a tagged
release. The catalog surface-release gate is the single CLI assertion for the
same decision: it combines coverage release readiness, promotion-readiness
stability reports, family closeout completeness, and git provenance into one
pass/fail status.

Use the JSON form when release dashboards, CI annotations, or package-review
artifacts need machine-readable status:

```sh
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --surface-release-json
julia --project=. --startup-file=no scripts/stable_widget_stabilization_schema_audit.jl
julia --project=. --startup-file=no scripts/stable_widget_surface_release_schema_audit.jl
```

For focused debugging, run the underlying checks individually:

```sh
julia --project=. --startup-file=no scripts/widget_audit.jl --require-complete
julia --project=. --startup-file=no scripts/stable_widget_candidates.jl --require-stable
julia --project=. --startup-file=no scripts/widget_family_evidence_audit.jl
julia --project=. --startup-file=no scripts/widget_promotion_requirements_audit.jl
julia --project=. --startup-file=no scripts/widget_promotion_requirements_schema_audit.jl
julia --project=. --startup-file=no scripts/render_widget_promotion_requirements.jl --format markdown
julia --project=. --startup-file=no scripts/render_widget_promotion_requirements.jl --format json --release-required yes
julia --project=. --startup-file=no scripts/experimental_promotion_audit.jl
julia --project=. --startup-file=no scripts/compatibility_widget_alias_audit.jl
julia --project=. --startup-file=no scripts/stable_promotion_packet_audit.jl
julia --project=. --startup-file=no scripts/pilot_evidence_package_audit.jl
```

The checks answer different questions:

| Command | Question |
|---|---|
| `widget_audit.jl --require-complete` | Does every direct renderable have complete behavior evidence? |
| `stable_widget_candidates.jl --require-stable` | Is every direct renderable available through the stable facade? |
| `widget_family_evidence_audit.jl` | Does every stable widget family have indexed docs, indexed and family-mapped examples, and precompile coverage? |
| `widget_promotion_requirements_audit.jl` | Is the experimental-to-stable promotion checklist concrete, gated, and release-classified across every required evidence area? |
| `widget_promotion_requirements_schema_audit.jl` | Does the promotion requirements JSON artifact match its versioned schema? |
| `render_widget_promotion_requirements.jl` | What release-required promotion requirements should reviewers attach to dashboards, pull requests, or release notes? |
| `experimental_promotion_audit.jl` | Is the experimental namespace empty or explicitly reviewed? |
| `experimental_widget_names()` / `candidate_widget_names()` | Are there any in-process compatibility bindings or non-stable catalog rows left before shell gates run? |
| `render_widget_catalog.jl --stabilization-status` | Are there any experimental bindings, non-stable catalog rows, stability blockers, or family closeout blockers left? |
| `render_widget_catalog.jl --stabilization-blockers` | Which stabilization blocker details should reviewers inspect before release gates run? |
| `render_widget_catalog.jl --stabilization-json` | What machine-readable closeout status should CI dashboards archive before heavier release gates run? |
| `compatibility_widget_alias_audit.jl` | Are compatibility widget names real public concepts instead of accidental aliases? |
| `stable_promotion_packet_audit.jl` | Are completed stable promotion packet records concrete, traceable, and linked to behavior, promotion requirements, promotion, and startup evidence? |
| `pilot_evidence_package_audit.jl` | Are archived WidgetPilot or ToolkitPilot evidence packages and optional package-level reports structurally valid and internally consistent? |
| `render_widget_catalog.jl --coverage-summary --format tsv --require-complete-coverage --require-clean-git` | Does every stable widget have complete behavior evidence with matching source paths from a clean checkout? |
| `render_widget_family_closeout.jl --release-check` | Are all stable widget families ready with clean release metadata and zero blockers? |
| `render_widget_catalog.jl --surface-release-status --require-surface-release-ready` | Are coverage, stability, family closeout, and git provenance all release-ready for the stable widget surface? |
| `render_reference_parity_matrix.jl --release-status --require-release-ready` | Does the cross-library parity matrix have no remaining `not yet implemented` release blockers? |
| `render_reference_parity_matrix.jl --release-blockers` | Which adapted or not-yet-matched reference families still need parity closeout evidence? |

## Family closeout loop

Use this loop when making an existing stable-looking widget family genuinely
production-ready:

1. Pick one family from [Parity Execution Plan](PARITY_EXECUTION_PLAN.md).
2. List its public widgets with `stable_widget_catalog` or
   `scripts/render_widget_catalog.jl --query <family-or-widget>`.
   Use `stable_widget_families`, `group_widgets(:family)`, and
   `widget_family_summary_markdown()` when a release note, gallery, or closeout
   report needs the reviewed widget surface grouped by cross-library family.
   Pass `family="Inputs and controls"`, `family=:inputs_and_controls`, or
   another family from `stable_widget_families()` to `stable_widget_catalog`,
   `widget_catalog_tsv`, `widget_catalog_markdown`, and summary helpers when the
   closeout work should stay scoped to one family.
   Use `stable_widget_family_slugs()` or `widget_catalog_family_slug(:Button)`
   when generated artifacts need stable kebab-case filenames, URLs, or Markdown
   anchors.
   Use `widget_families_text()` or
   `scripts/render_widget_catalog.jl --families` when a generated index needs a
   plain newline-separated list of reviewed families. Use
   `widget_family_slugs_text()` or
   `scripts/render_widget_catalog.jl --family-slugs` for matching slug lists.
   Use `stable_widget_family_catalog()` or
   `scripts/render_widget_catalog.jl --family-catalog` when generated docs need
   one structured row per family with display name, slug, count, and widget
   names.
   Use `widget_family_catalog_markdown()` or `widget_family_catalog_tsv()` when
   generated docs should be produced from Julia code without invoking the CLI.
   Pass `columns=(:family_slug, :count)` to the Julia helpers, or
   `--columns family_slug,count` to the CLI, when generated artifacts need only
   stable identifiers and counts.
   Use `search_widget_families("button")`,
   `search_widget_family_catalog_markdown("button"; columns=(:family_slug, :count))`,
   or `scripts/render_widget_catalog.jl --family-catalog --query button` when a
   generated migration index needs to find the family that owns a widget or
   compatibility concept.
   Use `search_widgets("inputs-and-controls")` or
   `scripts/render_widget_catalog.jl --query inputs-and-controls --columns name,family_slug`
   when a generated page starts from a stable family slug and needs the matching
   widget rows.
   Use `widget_coverage_records()` or
   `scripts/render_widget_catalog.jl --coverage` when a release dashboard needs
   behavior-evidence status for every reviewed widget. Use
   `widget_coverage_gaps()` or
   `scripts/render_widget_catalog.jl --coverage-gaps --family inputs-and-controls`
   when the closeout task should focus only on missing, incomplete, or
   source-mismatched evidence rows. Use
   `widget_coverage_issue_records(:source_mismatch)` or
   `widget_coverage_issue_names(:missing_checks)` when a release checklist needs
   only the affected widget names; the CLI equivalent is
   `scripts/render_widget_catalog.jl --coverage-issue-names missing_checks`.
   Use
   `widget_coverage_issue_markdown(:missing_checks)`, or run
   `scripts/render_widget_catalog.jl --coverage-issue missing_checks` when a
   release dashboard needs one issue class at a time. Use
   `widget_coverage_complete()` or
   `assert_widget_coverage_complete()` when tests or release scripts need a
   direct pass/fail API for the same evidence policy; assertion failures include
   the gap count and a short sample of affected widget names. Use
   `widget_coverage_git_metadata()` and `assert_widget_coverage_clean_git()`
   when release scripts need direct git-provenance checks from Julia code. Use
   `widget_coverage_release_ready()` or
   `assert_widget_coverage_release_ready()` when release scripts need one API
   for complete coverage plus clean git provenance. Use
   `widget_coverage_release_status_record()` when dashboards or tests need
   typed release-readiness fields. Use
   `widget_coverage_release_status_json()` when dashboards need a compact
   machine-readable readiness object. Use
   `widget_coverage_release_status_text()` or
   `scripts/render_widget_catalog.jl --coverage-status --require-clean-git`
   when release logs need one compact readiness line. Use
   `widget_coverage_summary_text()`,
   `scripts/render_widget_catalog.jl --coverage-status`,
   `widget_coverage_summary_markdown()`, or
   `scripts/render_widget_catalog.jl --coverage-summary --format tsv` when CI
   or release notes need compact coverage totals instead of per-widget rows.
   Add `--require-complete-coverage` when release tooling must fail on any
   stable widget coverage gap before publishing. Add `--require-clean-git`
   when release tooling must reject dirty or unavailable git provenance before
   producing coverage evidence. When both flags are present, the CLI delegates
   to `assert_widget_coverage_release_ready`.
   Use `widget_family_widgets(:inputs_and_controls)`,
   `widget_family_widget_names(:inputs_and_controls)`, or
   `widget_family_widget_count(:inputs_and_controls)` when a family typo should
   fail loudly instead of returning an empty filtered catalog.
   The CLI equivalent is
   `scripts/render_widget_catalog.jl --family-summary --format markdown`.
   Render family-level docs, examples, tokens, blocker counts, and blocker
   details with
   `scripts/render_widget_family_closeout.jl --family <family>`.
   Use `scripts/render_widget_family_closeout.jl --status blocked` when the
   closeout loop should show only families that still have stabilization
   blockers.
   Add `--require-ready` when the command should fail for blocked families.
   Use `--summary --format tsv` for a compact total/ready/blocked count.
   Use `--format json` when downstream release tooling needs machine-readable
   family closeout rows with `schema_version`, `metadata`, `summary`, and
   `families`. In git checkouts, `metadata.git_commit` records the source
   revision and `metadata.git_dirty` records whether uncommitted changes were
   present.
   Use
   `--require-total-count "$(julia --project=. scripts/render_widget_family_closeout.jl --count)"`
   when release tooling should assert that all expected stable widget families
   are present without duplicating the family count.
   Use `--release-check` for release-candidate closeout; it bundles
   `--require-ready`, `--require-clean-git`, and `--require-blocked-count 0`.
   Use `--require-clean-git` when release tooling must reject dirty-worktree
   evidence.
   Use `--require-blocked-count 0` when release tooling should assert that no
   families remain blocked.
3. Confirm each direct renderable has complete rows in `api/widget_coverage.tsv`
   and no non-actionable `n/a` values.
4. Confirm stateful widgets expose a public `state_for` path and document the
   state ownership model.
5. Add or harden render snapshots for zero-size, minimal, clipped, resized, and
   normal layouts.
6. Add interaction evidence for keyboard, pointer, actions, validation, focus,
   cancellation, or explicitly documented non-applicability.
7. Add semantic snapshots with labels, roles, state, bounds, and supported
   actions.
8. Add Toolkit examples or tests when the widget can be used in declarative
   applications.
9. Add public examples that import `Wicked.API` and avoid internal modules.
10. Add representative precompile coverage for construction, state, render, and
    first-use paths.
11. Update docs, component catalog rows, changelog or migration notes, and
    family evidence rows in the same change.
12. Run `scripts/widget_stabilization_gate.jl` on the release candidate before
    checking off the family.

The loop is intentionally family-scoped. Stabilizing one widget by name while
leaving its state type, Toolkit path, examples, or companion widgets uncovered
creates an API surface that looks stable but is hard for application developers
to rely on.

## Common promotion blockers

| Blocker | Required fix |
|---|---|
| Widget exists only in `Wicked.Experimental` | Add an accepted or completed row in `api/experimental_promotions.tsv`, then promote, qualify, or remove it |
| Stable export is a constructor-only function | Expose a concrete or parameterized public widget type binding |
| Stable compatibility name is a bare alias | Replace it with a first-class wrapper or document the shared state contract explicitly |
| Stateful widget has no public state path | Add or document `state_for(widget)` and the public state type |
| Coverage row has missing render evidence | Add deterministic zero-size, minimal, clipped, resized, and normal render evidence |
| Coverage row has missing interaction evidence | Add keyboard, pointer, action, focus, or validation tests, or record concrete non-applicability |
| Semantic evidence is missing | Add semantic-tree assertions with labels, roles, bounds, state, and actions |
| Toolkit path is missing | Add Toolkit integration or document why the widget is immediate-mode only |
| Family evidence is too narrow | Add focused docs, public examples, stable API tokens, and matching precompile tokens |
| Promotion packet cites prose only | Replace prose claims with checked-in ledgers, tests, examples, docs, and release artifacts |

`api/widget_family_evidence.tsv` rows should identify the family scope in their
notes. Generic evidence notes are not enough because the ledger is used to prove
that each stable widget family has indexed docs, indexed and family-mapped
public examples, stable API tokens that are mentioned in focused docs and
demonstrated in public examples, and representative precompile coverage.
When a row lists public examples, `example_family_labels` must list the matching
family labels from `docs/EXAMPLE_FAMILIES.md` in the same order.
Documentation paths, public example paths, and example-family labels in a row
must be distinct.
Each row must include at least three representative `stable_api_tokens` so one
well-documented symbol cannot stand in for an entire widget family.
Those tokens must be distinct.
Representative `precompile_tokens` must also be distinct and present in the
checked-in precompile workload. Each row must include at least three
representative `precompile_tokens`.
Every type-backed `stable_api_token` in a row must also have a matching
`precompile_token`, either by exact public spelling or by a module-qualified
spelling with the same final segment.
See [Widget Family Evidence Ledger](WIDGET_FAMILY_EVIDENCE.md) for the full
column contract.

## Adding a new widget

Use this implementation order:

1. Add the state type and constructor contract.
2. Add rendering with deterministic clipping and width behavior.
3. Add `state_for` for stateful direct renderables.
4. Add keyboard and pointer handling where the widget is interactive.
5. Add semantic nodes with labels, states, bounds, and actions.
6. Add Toolkit integration when the widget belongs in declarative apps.
7. Add test evidence rows through the widget audit workflow.
8. Add focused docs and a copyable quickstart or gallery entry.
9. Add precompile coverage for the normal construction path.
10. If the widget becomes a representative stable family token, add a matching
    `precompile_token` in `api/widget_family_evidence.tsv`.
11. Promote through `Wicked.API` only after the evidence is complete.

## Stable promotion packet

Every widget promoted from candidate or compatibility-only status must have a
small review packet before the export is treated as stable. The packet may live
in the pull request description or release evidence, but it must cite checked-in
artifacts rather than relying on prose claims. Use
[Stable Promotion Packet Template](STABLE_PROMOTION_PACKET_TEMPLATE.md) as the
default structure.

Draft a packet with:

```sh
julia --project=. --startup-file=no scripts/new_stable_promotion_packet.jl \
  --family Stateful-controls \
  --widget ComboBox \
  --source src/AcceptanceWidgets.jl \
  --candidate <sha> \
  --decision promote
```

Audit completed packet records with:

```sh
julia --project=. --startup-file=no scripts/stable_promotion_packet_audit.jl
```

The packet must include:

1. Public API decision: stable name, constructor shape, state type, exported
   methods, and any compatibility alias or removal decision.
2. Behavior evidence: `api/widget_coverage.tsv` row with deterministic render,
   resize, clipping, state transition, keyboard, pointer, Toolkit, and semantic
   coverage, using `n/a:<reason>` only when the behavior cannot apply.
3. Promotion evidence: `api/stable_widget_candidates.tsv` row marked `stable`
   and, when `Wicked.Experimental` was involved, a completed
   `api/experimental_promotions.tsv` row.
4. Developer evidence: focused docs, component catalog entry, and at least one
   copyable public example that imports `Wicked.API`.
5. Family evidence: updated `api/widget_family_evidence.tsv` tokens when the
   widget changes representative API or precompile coverage for its family,
   including a matching precompile token for each type-backed stable API token.
6. Startup evidence: `src/Precompile.jl` workload that exercises normal
   construction and first-use paths.
7. Compatibility evidence: changelog, migration note, or deprecation plan when
   an old public spelling remains or changes.

If any item is missing, keep the widget internal or candidate. Do not add the
name to `Wicked.API` as a temporary shortcut.

## Keeping stable widgets stable

Stable widgets must preserve source compatibility for public constructors,
state types, exported names, semantic roles, and documented event results.

Breaking changes require:

1. A replacement API.
2. A migration note.
3. A deprecation window.
4. Release notes.
5. Updated examples and docs.

Internal layout or rendering improvements are acceptable when they preserve the
documented behavior and semantics.

## Definition of done

The widget surface is production-ready for a release when:

1. `Wicked.Experimental` has no unreviewed app-facing bindings.
2. The stable candidate report has only `stable` rows.
3. The widget coverage audit has no `missing` cells.
4. Every stable widget family has focused documentation.
5. Every stable widget family has at least one runnable example path.
6. Precompile coverage includes representative widgets from each family.
7. Linux CI runs the strict audit gates.

This tracker should be updated whenever a new widget family, evidence dimension,
or release gate is added.
