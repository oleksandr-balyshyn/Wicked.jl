# API stabilization

Wicked exposes one application-facing facade and one compatibility namespace:

- `Wicked.API` is the candidate stable surface for application code.
- `Wicked.Experimental` is a compatibility namespace. The current baseline has no
  application-facing experimental bindings.

Do not promote a widget, state type, or helper by moving the export alone.
Stabilization is an API commitment. A promoted binding must have enough evidence
for users to rely on its constructors, state ownership, rendering behavior, input
behavior, Toolkit interop, semantic output, and documentation.

## Promotion requirements

A widget, companion state type, or helper can move into `Wicked.API` only when:

- Its constructor keywords and state type are intentional and documented.
- Immediate rendering works at zero, minimal, clipped, resized, and normal sizes.
- Stateful widgets have explicit state-transition evidence.
- Golden snapshot evidence exists.
- Toolkit interoperability evidence exists.
- Semantic-tree evidence exists.
- Keyboard and pointer behavior are tested or explicitly non-applicable.
- Public docstrings are discoverable by `scripts/api_audit.jl`.
- The widget appears in the API reference or a focused guide.
- Type-backed stable API tokens are represented in `src/Precompile.jl` and in
  `api/widget_family_evidence.tsv` with matching precompile tokens.
- The promotion is listed in `CHANGELOG.md` when it affects users.

For widget-specific promotion decisions, use [Widget Stabilization Tracker](WIDGET_STABILIZATION.md). It defines the promote, keep-candidate, qualify, remove, and keep-internal decisions for experimental or candidate widget concepts and lists the evidence packet required before a widget is treated as release-stable.

## Compatibility widget names

Common names from Ratatui, Textual, TamboUI, Lanterna, and retained UI
frameworks are useful only when they make the developer API clearer. Do not add a
new stable widget name as a bare type alias unless identity is intentionally part
of the contract.

Prefer a first-class wrapper when the public name describes a distinct user
concept, even if rendering delegates to an existing implementation. Examples
include `Panel`, `Border`, `SearchInput`, `PasswordInput`, `StatusBar`,
`TitleBar`, `AppShell`, `app_shell_layout`, `Modal`, `Overlay`, and
`LoadingIndicator`. These wrappers and helper APIs should:

- Preserve the underlying behavior and state ownership model.
- Expose a constructor under the compatibility name.
- Delegate `measure`, `render!`, `handle!`, and `state_for` where applicable.
- Provide semantic output using the compatibility name when that improves
  automation or accessibility clarity.
- Appear in the widget coverage ledger when they are direct renderables.
- Be exported by `Wicked.API` as a concrete or parameterized widget type binding.
- Appear in the public widget-name map in `docs/COMPONENT_CATALOG.md`.
- List any non-stateless state contract in that map as a concrete or
  parameterized `Wicked.API` type binding.
- Document both the widget name and any listed state contract in the focused
  widget, control, navigation, or utility API guide.

State aliases remain acceptable when two public widget names intentionally share
one external state type. For example, `SearchInputState` can remain compatible
with `TextInputState` because the edit buffer contract is the same. Document the
shared state explicitly so applications do not create parallel state models for
the same interaction.

Avoid adding a compatibility wrapper when an existing similarly named state
machine has different ownership semantics. In that case, document the split
instead of creating a confusing API. The `NumberInput` and `NumericInputState`
guidance follows this rule.

## Candidate audit

Run the widget stabilization audit from the repository root:

```sh
julia --project=. --startup-file=no scripts/stable_widget_candidates.jl
```

To refresh the report used during release review:

```sh
julia --project=. --startup-file=no scripts/stable_widget_candidates.jl --write-report
```

To fail when any direct renderable remains outside the stable application facade
or lacks complete promotion evidence:

```sh
julia --project=. --startup-file=no scripts/stable_widget_candidates.jl --require-stable
```

To fail when a stable direct-renderable or public widget-name-map compatibility
widget name is implemented as a bare `const Widget = OtherWidget` alias:

```sh
julia --project=. --startup-file=no scripts/compatibility_widget_alias_audit.jl
```

The report is written to `api/stable_widget_candidates.tsv` with these columns:

- `widget`: renderable type name.
- `source`: implementation file recorded by the widget coverage ledger.
- `surface`: `stable`, `compatibility`, or `internal`.
- `status`: `stable`, `candidate`, or `blocked`.
- `reason`: evidence summary or blocker.

Stable widget rows also require the `Wicked.API` binding to be a concrete or
parameterized type. Constructor-only functions are blocked because the widget
candidate report, component catalog, semantic metadata, and precompile evidence
need a stable type identity.
When a stable widget type is listed as representative family API, its
`api/widget_family_evidence.tsv` row must include a matching precompile token by
exact public spelling or module-qualified spelling with the same final segment.

The audit cross-references:

- `api/widget_coverage.tsv`
- `api/stable_api.tsv`
- `api/experimental_api.tsv`
- `api/experimental_promotions.tsv`

It does not replace `scripts/widget_audit.jl --require-complete`; it turns that
evidence into a promotion queue.

As of the current development baseline, every renderable widget in
`api/widget_coverage.tsv` is exported through `Wicked.API`. The report remains in
the repository so new renderables cannot silently remain outside the stable facade
without an explicit review decision.

For a fast in-process check, call `experimental_widget_names()`,
`experimental_widget_records()`, `experimental_widget_records_json()`,
`experimental_widget_records_markdown()`, `experimental_widget_records_tsv()`,
`candidate_widget_names()`, `candidate_widget_count()`,
`candidate_widget_records()`, `candidate_widget_records_json()`,
`candidate_widget_records_markdown()`, `candidate_widget_records_tsv()`,
`widget_stabilization_closeout_records()`,
`widget_stabilization_closeout_kind_records(:experimental)`,
`widget_stabilization_closeout_kind_count(:candidate)`,
`widget_stabilization_closeout_kind_artifacts(:experimental)`,
`widget_stabilization_closeout_kind_json(:experimental)`,
`widget_stabilization_closeout_kind_markdown(:experimental)`,
`widget_stabilization_closeout_kind_tsv(:candidate)`,
`widget_stabilization_closeout_kind_text(:candidate)`,
`widget_stabilization_closeout_kind_complete(:experimental)`,
`assert_widget_stabilization_closeout_kind_complete(:candidate)`,
`search_widget_stabilization_closeout_records("button")`,
`search_widget_stabilization_closeout_count("button")`,
`search_widget_stabilization_closeout_summary("button")`,
`search_widget_stabilization_closeout_summary_records("button")`,
`search_widget_stabilization_closeout_summary_json("button")`,
`search_widget_stabilization_closeout_summary_markdown("button")`,
`search_widget_stabilization_closeout_summary_tsv("button")`,
`search_widget_stabilization_closeout_summary_text("button")`,
`search_widget_stabilization_closeout_complete("button")`,
`assert_search_widget_stabilization_closeout_complete("button")`,
`search_widget_stabilization_closeout_json("button")`,
`search_widget_stabilization_closeout_markdown("button")`,
`search_widget_stabilization_closeout_tsv("button")`,
`search_widget_stabilization_closeout_text("button")`,
`search_widget_stabilization_closeout_artifacts("button")`,
`widget_stabilization_closeout_count()`,
`widget_stabilization_closeout_complete()`,
`assert_widget_stabilization_closeout_complete()`,
`widget_stabilization_closeout_summary()`,
`widget_stabilization_closeout_summary_records()`,
`widget_stabilization_closeout_summary_json()`,
`widget_stabilization_closeout_summary_markdown()`,
`widget_stabilization_closeout_summary_text()`,
`widget_stabilization_closeout_summary_tsv()`,
`widget_stabilization_closeout_status_record()`,
`widget_stabilization_closeout_status_text()`,
`widget_stabilization_closeout_status_json()`,
`widget_stabilization_closeout_status_markdown()`,
`widget_stabilization_closeout_status_tsv()`,
`widget_stabilization_closeout_json()`,
`widget_stabilization_closeout_markdown()`,
`widget_stabilization_closeout_text()`,
`widget_stabilization_closeout_tsv()`,
`widget_stabilization_closeout_artifacts()`,
`widget_stabilization_artifacts()`,
`widget_stabilization_artifacts_json()`,
`widget_stabilization_artifacts_text()`,
`widget_stabilization_artifacts_markdown()`,
`widget_stabilization_artifacts_tsv()`,
`widget_stabilization_artifacts_ready()`,
`assert_widget_stabilization_artifacts_ready()`,
`widget_stabilization_status_record()`, or
`widget_stabilization_status_json()` from `Wicked.API`. A release candidate
can also publish `widget_stabilization_status_records()`,
`widget_stabilization_status_markdown()`, or `widget_stabilization_status_tsv()`
artifacts when reviewers need structured or readable closeout summaries without
shelling out to scripts. Use `widget_stabilization_ready()` for a direct boolean
gate and `assert_widget_stabilization_ready()` when blocked closeout should
raise an error with details. Use `widget_stabilization_blocker_records()` when
tooling needs structured blocker categories, counts, and details, and use
`widget_stabilization_blocker_records_json()`,
`widget_stabilization_blocker_records_markdown()`, or
`widget_stabilization_blocker_records_tsv()` to publish those structured records
as machine-readable or review artifacts. Use
`widget_stabilization_blocker_count()` for compact threshold checks. Use
`widget_stabilization_blockers_markdown()` or
`widget_stabilization_blockers_tsv()` when a review packet should include only
blocking reasons. It should report no
experimental bindings, no non-stable catalog candidates, and no stability or
family-closeout blockers before the heavier shell gates are run.

This means current stabilization work is mostly evidence closeout, not mass
promotion from `Wicked.Experimental`. A widget row marked `stable` proves that
the direct renderable is exported through the stable facade and has complete
candidate-audit evidence. It does not by itself prove release readiness for the
whole widget family. Release readiness also requires focused documentation,
public examples, semantic evidence, Toolkit interop evidence, representative
precompile coverage, and immutable release-candidate artifacts.

## Promotion workflow

Promote widgets in small batches by family:

1. Run `scripts/stable_widget_candidates.jl --write-report`.
2. Pick a small set of `candidate` rows from the same component family.
3. Move the widget and required companion state types from their owning subsystem
   or short-lived compatibility namespace to `Wicked.API`.
4. Update the generated API baselines with `scripts/api_audit.jl --write-baseline`.
5. Update API docs, examples, and changelog entries.
6. Run `scripts/stable_widget_candidates.jl --require-stable`.
7. Run the quality gates before merging.

If there are no `candidate` rows, do not create artificial promotion work. Pick a
stable family from [Parity Execution Plan](PARITY_EXECUTION_PLAN.md) and close
its remaining behavior, docs, examples, semantic, Toolkit, precompile, and
release-evidence gaps instead.

Do not promote internal helper types solely because a widget uses them. Prefer
stable constructors, accessors, and documented extension methods over exposing
struct layout or manager internals.

## Experimental binding ledger

`Wicked.Experimental` must stay empty except for short-lived compatibility names.
Any future binding beyond the namespace marker requires a row in
`api/experimental_promotions.tsv`.

The ledger columns are:

- `name`: exported binding in `Wicked.Experimental`.
- `decision`: `promote`, `qualify`, or `remove`.
- `target`: destination public API name, owning qualified module, or removal
  milestone.
- `review_status`: `proposed`, `accepted`, or `completed`.
- `notes`: concrete reason and evidence still needed.

The quality gate rejects experimental bindings without a row. It also rejects
stale proposed or accepted rows for names that no longer exist, which keeps the
experimental namespace from becoming an undocumented second API surface.

Review the ledger directly before opening a pull request:

```sh
julia --project=. --startup-file=no scripts/experimental_promotion_audit.jl
```

## Stable release gate

For a production release, the candidate report must contain only `stable` rows.
`candidate` means the widget has enough evidence to promote but has not yet been
exported through `Wicked.API`. `blocked` means the widget is missing evidence or
is an unreviewed internal renderable. Neither state is acceptable for the
release-candidate branch.

This gate is intentionally narrower than full reference-library parity. It
answers one question: can application developers rely on every direct Wicked
renderable through the stable facade without importing `Wicked.Experimental` or
reaching into internal modules? Family parity is closed separately through the
parity evidence records and release checklist.
