# Public API Facades

Wicked exposes reviewed public contracts through explicit facades:

```@docs
Wicked.API
Wicked.Experimental
```

Use [Candidate Stable API](./STABLE_API.md) for the reviewed name inventory.
[Experimental Compatibility](./EXPERIMENTAL_API.md) documents the compatibility
namespace; the current reviewed baseline has no application-facing experimental
bindings.

## Import policy

Use the facade that matches the stability contract you need:

| Code location | Recommended import | Rationale |
| --- | --- | --- |
| Applications and examples | `using Wicked.API` | Imports the reviewed app-facing surface without pulling subsystem internals into the root namespace. |
| Package extensions | `using Wicked.API` plus qualified child modules when needed | Keeps extension contracts stable while making intentional subsystem dependencies visible. |
| Internal Wicked implementation | Owning child modules | Implementation code can share internals without expanding the public facade. |
| Short-lived experiments | Qualified owning module, or future `Wicked.Experimental` only with a ledger row | Experimental names are not compatibility promises and must have promotion, qualification, or removal plans. |

Do not use `Wicked.Experimental` for normal application code. The current
baseline exports only the namespace marker, and the quality gate rejects future
application-facing experimental bindings unless `api/experimental_promotions.tsv`
records the review plan.

Compatibility widget names exported by `Wicked.API` follow the
[API stabilization policy](./API_STABILIZATION.md#compatibility-widget-names):
distinct user concepts should be first-class wrappers, while shared state aliases
must be documented explicitly.

For widget names, prefer the public map in
[Component Catalog](./COMPONENT_CATALOG.md#public-widget-name-map). A name in that
map is the reviewed application-facing vocabulary for porting Ratatui, Textual,
TamboUI, or Lanterna examples. Stateful entries should keep their explicit state
objects in application models and use `state_for(widget)` only for previews,
smoke tests, and pilot setup. Use `stable_widget_catalog`,
`stable_widget_count`, `stable_widget_names`, `widget_names_text`,
`search_widget_count`, `search_widget_names_text`,
`widget_source_files`, `widget_source_files_text`, `search_widget_source_files_text`,
`widget_source_summary`,
`widget_source_summary_markdown`, `widget_source_summary_tsv`, `search_widgets`, `group_widgets`,
`widget_catalog_summary`, `widget_catalog_markdown`, `widget_catalog_records`,
`widget_catalog_tsv`, `search_widget_catalog_markdown`,
`search_widget_catalog_tsv`, `widget_vocabulary`, `widget_vocabulary_records`,
`search_widget_vocabulary`, `widget_vocabulary_entry`,
`widget_vocabulary_widget_names`, `widget_vocabulary_markdown`,
`widget_vocabulary_tsv`, `is_stable_widget`, `assert_stable_widget`, and
`widget_catalog_entry` when developer tooling needs to inspect the reviewed
stable widget surface programmatically or generate query-filtered catalog
documentation. Use `columns=:name` or a column collection with
`widget_catalog_markdown`. Use widget names, public widget types, or widget
instances for catalog lookup. Use `assert_stable_widget` when adapters or app
builders should fail fast for non-stable widgets. Use
`scripts/render_widget_catalog.jl --format markdown --output stable-widgets.md`
or `--format tsv` when shell workflows need to emit the same catalog as an
artifact. Add `--count` when release review needs only a matching widget count.
Add `--min-count 1` when CI should fail if a filtered catalog becomes empty.
Add `--max-count 20` when CI should fail if a filtered catalog becomes too
broad.
Add `--names` when release review needs a plain widget-name list, and combine it
with `--query button` for a focused name list. Add `--sources` when release
review needs a plain source-file list, and combine it with `--query button` for
a focused source-file list. Add
`experimental_widget_records` when review tooling needs structured records for
remaining `Wicked.Experimental` bindings, including catalog linkage and the
required promote, qualify, or remove decision. Add
`experimental_widget_record` when you need one binding's promotion ledger row,
`experimental_widget_readiness_record` when you need blockers plus a boolean
`ready` status, and `assert_experimental_widget_ready_for_stable` when release
or migration tooling should fail if the binding is not ready. Use
`experimental_widget_records_json`, `experimental_widget_records_markdown`, and
`experimental_widget_records_tsv` when experimental closeout needs
machine-readable or human-readable artifacts. Add
`AppShell`, `app_shell_dock`, `app_shell_layout`, `app_shell_regions`, and
`app_shell_summary` when application chrome should be constructed and inspected
as one high-level shell.
Use `binding_key_hints`, `binding_help_json`, `binding_help_markdown`, `binding_help_tsv`,
`binding_layer_help_json`, `binding_layer_help_markdown`,
`binding_layer_help_tsv`, `binding_stack_help_json`,
`binding_stack_help_markdown`, and `binding_stack_help_tsv` when shortcut help
or keybinding diagnostics should become renderable key hints or be emitted as
JSON, Markdown, or TSV artifacts.
Add
`--summary` when release review needs counts instead of row-level catalog
output. Add `--source-summary` when release review needs source files,
counts, and widget names. Add `--query button` when a generated artifact should
include only matching widgets. Add `--append` with `--output` when a release artifact
should collect multiple generated sections. Nested `--output` directories are
created automatically. Use `--no-header` with `--format tsv` when appending TSV
sections should not repeat column headers. Use
`scripts/render_widget_family_closeout.jl --format markdown` when release
planning needs family-level documentation, example, precompile-token,
blocker-count, and blocker-detail visibility for the Ratatui, Textual, TamboUI,
and Lanterna parity families. Combine it with `--family toolkit` or `--count` for focused planning
checks. Add `--require-ready` when a blocked family should fail CI or release
review. Use `--summary --format tsv` for a compact total/ready/blocked count.
Use `--format json` when release dashboards or scripts need a machine-readable
family closeout artifact with `schema_version`, `metadata`, `summary`, and
`families`. In git checkouts, `metadata.git_commit` records the source revision
and `metadata.git_dirty` records whether uncommitted changes were present.
Use `--require-total-count` with the value from `--count` when a workflow should
assert that every expected stable widget family is present.
Use `--release-check` for release-candidate closeout when a workflow should
bundle stable widget coverage completeness, ready-family, clean-git, and
zero-blocked-family assertions.
The same family closeout data is available from `Wicked.API` through
`WidgetFamilyCloseoutReport`, `widget_family_closeout_reports`,
`widget_family_closeout_gaps`, `widget_family_closeout_summary`,
`widget_family_closeout_complete`, `assert_widget_family_closeout_complete`,
`widget_family_closeout_markdown`, `widget_family_closeout_tsv`,
`widget_family_closeout_json`, `widget_family_closeout_artifacts`,
`widget_family_closeout_artifacts_json`,
`widget_family_closeout_artifacts_text`,
`widget_family_closeout_artifacts_markdown`, and
`widget_family_closeout_artifacts_tsv` when Julia tooling should avoid shelling
out to the renderer.
Use `widget_surface_release_status_record`, `widget_surface_release_ready`,
`assert_widget_surface_release_ready`, `widget_surface_release_status_text`, and
`widget_surface_release_status_json` when Julia release tooling needs one
combined stable widget-surface gate for coverage, stability, and family
closeout.
Use `widget_stabilization_artifacts` when release tooling needs the complete
schema-versioned widget stabilization evidence bundle in one call: broad status,
blockers, closeout artifacts, stability summary, and family-closeout summary.
Use `widget_stabilization_artifacts_json` when dashboards or CI need that full
stabilization evidence bundle as one JSON document. Use
`widget_stabilization_artifacts_text` when release logs need the same bundle as
compact multiline text. Use `widget_stabilization_artifacts_markdown` and
`widget_stabilization_artifacts_tsv` when release review needs the full bundle
as a table artifact. Use `assert_widget_stabilization_artifacts_ready` when
release tooling should return the ready bundle or fail fast with closeout and
blocker counts. Use `widget_stabilization_artifacts_ready` when callers need the
same aggregate bundle readiness as a boolean.
Use `widget_stabilization_status_records`,
`widget_stabilization_status_markdown`, and `widget_stabilization_status_tsv`
when promotion closeout needs structured data or a human-readable artifact that
lists candidate widgets, experimental bindings, stability blockers, and family
closeout blockers. Use `widget_stabilization_closeout_records` when tooling
needs one normalized list of remaining experimental bindings and non-stable
catalog candidates. Use `widget_stabilization_closeout_kind_records` and
`widget_stabilization_closeout_kind_count` when review tooling needs only
`:experimental` or `:candidate` closeout work. Use
`widget_stabilization_closeout_kind_complete` and
`assert_widget_stabilization_closeout_kind_complete` when one closeout kind
needs its own boolean or fail-fast gate. Use
`widget_stabilization_closeout_kind_json`,
`widget_stabilization_closeout_kind_markdown`,
`widget_stabilization_closeout_kind_tsv`, and
`widget_stabilization_closeout_kind_text` when one closeout kind should be
published as release artifacts or logs. Use
`widget_stabilization_closeout_count` for a direct
numeric threshold over that normalized list. Use
`widget_stabilization_closeout_complete` for a closeout-only boolean gate and
`assert_widget_stabilization_closeout_complete` when that gate should fail fast
with the first remaining records. Use `widget_stabilization_closeout_summary`
and `widget_stabilization_closeout_summary_records` when dashboards need compact
total, experimental, and candidate counts. Use
`widget_stabilization_closeout_summary_json`,
`widget_stabilization_closeout_summary_markdown`, and
`widget_stabilization_closeout_summary_tsv` when those summary counts should be
published as machine-readable or human-readable artifacts. Use
`widget_stabilization_closeout_summary_text` when CI logs need one compact
summary line. Use `widget_stabilization_closeout_status_record`,
`widget_stabilization_closeout_status_text`, and
`widget_stabilization_closeout_status_json` when release tooling needs one
aggregate closeout gate bundle. Use `widget_stabilization_closeout_status_markdown`
and `widget_stabilization_closeout_status_tsv` when that status bundle should be
published as a table artifact. Use `widget_stabilization_closeout_json`,
`widget_stabilization_closeout_markdown`, and
`widget_stabilization_closeout_tsv` when that normalized closeout list should be
published as machine-readable or human-readable artifacts. Use
`widget_stabilization_closeout_text` when CI logs need a compact line per
remaining closeout item. Use `widget_stabilization_closeout_artifacts` when
release tooling needs the complete schema-versioned closeout evidence bundle in
one call. Use
`search_widget_stabilization_closeout_records` and
`search_widget_stabilization_closeout_count` when reviewers need to filter the
unified closeout list by widget name, family, source, status, action, or reason.
Use `search_widget_stabilization_closeout_summary` and
`search_widget_stabilization_closeout_summary_records` when filtered closeout
reviews need compact total, experimental, and candidate counts.
Use `search_widget_stabilization_closeout_summary_json`,
`search_widget_stabilization_closeout_summary_markdown`,
`search_widget_stabilization_closeout_summary_tsv`, and
`search_widget_stabilization_closeout_summary_text` when filtered closeout
summary counts should be published as artifacts or logs.
Use `search_widget_stabilization_closeout_complete` for a filtered closeout
boolean gate and `assert_search_widget_stabilization_closeout_complete` when a
focused closeout review should fail fast with matching records.
Use `search_widget_stabilization_closeout_json`,
`search_widget_stabilization_closeout_markdown`,
`search_widget_stabilization_closeout_tsv`, and
`search_widget_stabilization_closeout_text` when filtered closeout results
should be published as release artifacts or logs. Use
`search_widget_stabilization_closeout_artifacts` when a filtered closeout review
needs records, count, summary, text, Markdown, TSV, and JSON in one
schema-versioned bundle. Use
`widget_stabilization_ready` for a direct boolean gate
and `assert_widget_stabilization_ready` when release tooling should fail fast
with blocker details. Use `widget_stabilization_blocker_records` when tooling
needs structured blocker categories, counts, and details, and use
`widget_stabilization_blocker_records_json`,
`widget_stabilization_blocker_records_markdown`, or
`widget_stabilization_blocker_records_tsv` to publish those structured records
as machine-readable or review artifacts. Use
`widget_stabilization_blocker_count` for compact threshold checks. Use
`widget_stabilization_blockers_markdown` and
`widget_stabilization_blockers_tsv` when blocked closeout needs a focused
artifact containing only the blocker list.
Use `scripts/render_widget_catalog.jl --coverage-summary --require-complete-coverage --require-clean-git`
when a workflow should reject incomplete or dirty stable widget coverage
evidence before publishing.
Use `--require-clean-git` when a release workflow should reject dirty-worktree
evidence.
Use `--require-blocked-count 0` when a workflow should assert the exact
blocked-family count. Use `candidate_widget_count` when release tooling needs a
direct count of reviewed widget catalog entries that are not yet stable on the
stable application surface, and use `candidate_widget_records` when tooling
needs the corresponding name, family, source, surface, status, and reason
fields. Use `candidate_widget_records_json`,
`candidate_widget_records_markdown`, and `candidate_widget_records_tsv` when
candidate review needs machine-readable or human-readable artifacts. Use
`pilot_semantic_tree`,
`pilot_semantic_snapshot`, `assert_semantic_snapshot`, and
`assert_semantic_query` from `Wicked.API` for stable semantic assertions in pilot
tests.
Use `query_semantics` and `query_one_semantic` with an explicit `SemanticQuery`
directly on `WidgetPilot` or `ToolkitPilot` when tests need Textual-style
semantic node lookup.
