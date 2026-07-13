# Widget Promotion Guide

This guide defines how a Wicked widget moves from internal or compatibility-only
code to a stable public API. It is the operational checklist for answering
whether an experimental widget is ready for application developers.

Promotion is not an export move. A widget is stable only when its API contract,
behavior evidence, docs, examples, semantic output, Toolkit integration,
precompile path, and release metadata all agree.

## Promotion states

| State | Meaning | Public promise |
|---|---|---|
| Internal | Implementation detail or private helper | No application import |
| Candidate | Public concept under review | May change before release |
| Compatibility | Short-lived binding kept for migration | Must have a promote, qualify, or remove decision |
| Stable | Exported through `Wicked.API` with complete evidence | Supported for application code |
| Deprecated | Stable name scheduled for replacement or removal | Requires migration path |

Do not keep long-lived widgets in `Wicked.Experimental`. If the API is not ready,
keep the widget internal or candidate. If an experimental export is unavoidable,
add a row to `api/experimental_promotions.tsv` immediately.

## Required evidence

The canonical machine-readable checklist is
`api/widget_promotion_requirements.tsv`.

Every release-required row in that file must be satisfied before a widget is
called stable. Every `gate` entry must reference at least one checked-in
`scripts/*.jl` command so promotion criteria stay executable instead of drifting
into manual-only policy. The requirements intentionally cover more than
rendering:

| Area | Required outcome |
|---|---|
| API | Constructor shape, state model, event result, facade export, and compatibility story are reviewed |
| Behavior | Rendering, layout, clipping, focus, input, invalid states, and source traceability are covered |
| Docs | Developer-facing API docs and catalog/migration docs explain the widget |
| Examples | Public examples are copyable, mapped to the widget family, import `Wicked.API`, and avoid internals |
| Semantics | Interactive widgets expose stable semantic roles, labels, values, and state |
| Toolkit | Keyed state, reactive updates, styling, focus routing, and composition work where promised |
| Performance | Startup precompile and scale evidence exist for normal and large-data paths |
| Release | Family closeout, clean coverage evidence, and release notes are complete |

## Promotion workflow

1. Review the public API shape before changing exports.
2. Add or update `api/experimental_promotions.tsv` for compatibility bindings.
3. Add behavior evidence to `api/widget_coverage.tsv`. Each applicable evidence
   cell must cite at least one checked-in Julia source file such as
   `test/widget_contract.jl:case-name`; generic status words such as `ok`,
   `done`, or `covered` are not release evidence. Non-applicable cells must use
   `n/a:<reason>` with a specific reason.
4. Add the stable facade export and `api/stable_api.tsv` entry.
5. Add or update `api/stable_widget_candidates.tsv`.
6. Confirm the public renderable widget appears in the stable candidate ledger.
7. Cite satisfied `api/widget_promotion_requirements.tsv` rows in the stable
   promotion packet.
8. Add focused docs, component catalog coverage, migration vocabulary, and examples.
9. Add semantic and Toolkit evidence for interactive or component-oriented widgets.
10. Add precompile coverage for construction, state, render, and event paths.
11. Close the owning widget family with zero blockers.
12. Run release mode from a clean checkout before publishing.

## Required commands

Use the requirement audit first. It checks that the promotion checklist itself is
not vague, incomplete, or missing a release-critical area:

```sh
julia --project=. --startup-file=no scripts/widget_promotion_requirements_audit.jl
julia --project=. --startup-file=no scripts/widget_promotion_requirements_schema_audit.jl
```

Render the checklist when a pull request, release note, or dashboard needs the
current promotion requirements:

```sh
julia --project=. --startup-file=no scripts/render_widget_promotion_requirements.jl --format markdown
julia --project=. --startup-file=no scripts/render_widget_promotion_requirements.jl --format tsv --release-required yes
julia --project=. --startup-file=no scripts/render_widget_promotion_requirements.jl --format json --release-required yes
```

The JSON artifact is described by
`docs/evidence/widget_promotion_requirements.schema.json` and includes summary
counts by requirement area and `release_required` value.

Use the experimental promotion audit when a compatibility binding exists:

```sh
julia --project=. --startup-file=no scripts/experimental_promotion_audit.jl
```

Use release mode when deciding whether stable widgets are ready to publish:

```sh
julia --project=. --startup-file=no scripts/widget_stabilization_gate.jl --release-check
```

Focused checks are useful while closing a widget family:

```sh
julia --project=. --startup-file=no scripts/widget_audit.jl --require-complete
julia --project=. --startup-file=no scripts/stable_widget_candidates.jl --require-stable
julia --project=. --startup-file=no scripts/public_widget_candidate_audit.jl
julia --project=. --startup-file=no scripts/widget_family_evidence_audit.jl
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --coverage-summary --require-complete-coverage
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --stability --require-stability-ready
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --stability-gaps --format markdown
julia --project=. --startup-file=no scripts/render_widget_catalog.jl --stability-json
julia --project=. --startup-file=no scripts/render_widget_family_closeout.jl --release-check
julia --project=. --startup-file=no scripts/stable_promotion_packet_audit.jl
```

## Promotion review questions

Before approving promotion, answer these questions in the promotion packet or
release review notes:

| Question | Blocking answer |
|---|---|
| Would we keep this constructor shape for the next minor release? | No |
| Is state explicit and testable? | No |
| Are input and focus semantics deterministic? | No |
| Does rendering behave correctly in narrow, clipped, empty, and resized regions? | No |
| Can users copy an example and build an application? | No |
| Can Toolkit users compose and style the widget? | No, when Toolkit support is claimed |
| Can automated tests query semantic output? | No, for interactive widgets |
| Is first-use latency covered by precompile evidence? | No |
| Does the owning family closeout have zero blockers? | No |

If any blocking answer remains, the widget is not stable. Keep it candidate,
qualify the compatibility binding, or remove the export.

## Programmatic readiness API

Applications and release tooling can inspect promotion readiness without
scraping TSV ledgers:

```julia
using Wicked.API

report = widget_stability_report(:Button)
reports = widget_stability_reports()
gaps = widget_stability_gaps()
table = widget_stability_markdown(columns=(:name, :family, :ready, :blockers))
tsv = widget_stability_tsv(family=:inputs_and_controls, columns=(:name, :ready))
json = widget_stability_json()

@assert widget_stability_ready(:Button)
@assert assert_widget_stability_ready(:Button).ready
```

`WidgetStabilityReport` is ready only when the widget is reviewed as stable,
exported on the stable surface, and has complete coverage evidence with matching
source paths. Any blocker means the widget remains candidate, compatibility, or
internal until the promotion packet and evidence are closed.

## Recommended promotion order

Stabilize low-risk families first, then move toward complex interactive
surfaces:

1. Text and static display widgets.
2. Layout and container widgets.
3. Basic inputs and controls.
4. Navigation and overlays.
5. Data display, virtualization, and trees.
6. Rich content, code, logs, ANSI, and terminal panes.
7. Runtime services, remote delivery, and developer tooling.

This order reduces churn because complex widgets depend on layout, text, focus,
styling, events, and semantic primitives.
