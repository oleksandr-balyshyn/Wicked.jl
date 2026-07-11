# API stabilization

Wicked exposes two application-facing facades:

- `Wicked.API` is the candidate stable surface for application code.
- `Wicked.Experimental` is reviewed pre-1.0 surface that can still change faster.

Do not promote an experimental widget by moving the export alone. Stabilization is
an API commitment. A promoted widget must have enough evidence for users to rely on
its constructors, state ownership, rendering behavior, input behavior, Toolkit
interop, semantic output, and documentation.

## Promotion requirements

A widget can move from `Wicked.Experimental` to `Wicked.API` only when:

- Its constructor keywords and state type are intentional and documented.
- Immediate rendering works at zero, minimal, clipped, resized, and normal sizes.
- Stateful widgets have explicit state-transition evidence.
- Golden snapshot evidence exists.
- Toolkit interoperability evidence exists.
- Semantic-tree evidence exists.
- Keyboard and pointer behavior are tested or explicitly non-applicable.
- Public docstrings are discoverable by `scripts/api_audit.jl`.
- The widget appears in the API reference or a focused guide.
- The promotion is listed in `CHANGELOG.md` when it affects users.

## Candidate audit

Run the widget stabilization audit from the repository root:

```sh
julia --project=. --startup-file=no scripts/stable_widget_candidates.jl
```

To refresh the report used during release review:

```sh
julia --project=. --startup-file=no scripts/stable_widget_candidates.jl --write-report
```

The report is written to `api/stable_widget_candidates.tsv` with these columns:

- `widget`: renderable type name.
- `source`: implementation file recorded by the widget coverage ledger.
- `surface`: `stable`, `experimental`, or `internal`.
- `status`: `stable`, `candidate`, or `blocked`.
- `reason`: evidence summary or blocker.

The audit cross-references:

- `api/widget_coverage.tsv`
- `api/stable_api.tsv`
- `api/experimental_api.tsv`

It does not replace `scripts/widget_audit.jl --require-complete`; it turns that
evidence into a promotion queue.

As of the current development baseline, every renderable widget in
`api/widget_coverage.tsv` is exported through `Wicked.API`. The report remains in
the repository so new renderables cannot silently stay experimental without an
explicit review decision.

## Promotion workflow

Promote widgets in small batches by family:

1. Run `scripts/stable_widget_candidates.jl --write-report`.
2. Pick a small set of `candidate` rows from the same component family.
3. Move the widget and required companion state types from `Wicked.Experimental`
   to `Wicked.API`.
4. Update the generated API baselines with `scripts/api_audit.jl --write-baseline`.
5. Update API docs, examples, and changelog entries.
6. Run the quality gates before merging.

Do not promote internal helper types solely because a widget uses them. Prefer
stable constructors, accessors, and documented extension methods over exposing
struct layout or manager internals.
