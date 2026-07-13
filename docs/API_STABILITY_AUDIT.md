# API Stability Audit

Wicked's public API is not frozen. Passing tests and broad feature coverage do not
make the current `0.0.1` root namespace suitable for a `1.0` compatibility promise.
This page records executable evidence and remaining blockers.

> **Staleness note:** the symbol counts below reflect the current checked-in
> baselines after the stable-facade expansion. Validation claims that depend on
> `scripts/api_audit.jl`, `scripts/quality_gate.jl`, or the docs build must be
> rerun before they are release evidence for the current worktree.

## Current evidence

Audit date: 2026-07-11.

| Check | Current result | Release meaning |
| --- | ---: | --- |
| Root exported bindings | 3 | `Wicked`, `API`, and `Experimental` only |
| Candidate stable bindings | 2,186 | Independently baselined |
| Experimental bindings | 1 | Compatibility module marker only |
| Undefined exports | Requires rerun | `scripts/api_audit.jl` evidence pending |
| Recursive method ambiguities | Requires rerun | `scripts/api_audit.jl` evidence pending |
| Root bindings without root-local docs | Requires rerun | Documentation audit evidence pending |
| Exports without discoverable docs | Requires rerun | `scripts/api_audit.jl` evidence pending |
| HTTP extension loaded without HTTP | Requires rerun | Loading evidence must check `Base.get_extension(Wicked, :WickedHTTPWebSocketsExt) === nothing` before HTTP.jl is loaded |
| Experimental imports in source/extensions | Requires rerun | `scripts/quality_gate.jl` policy evidence pending |
| External widget contract | Requires rerun | `test/api_contract.jl` evidence pending |
| External backend contract | Requires rerun | `test/api_contract.jl` evidence pending |
| External input-source contract | Requires rerun | `test/api_contract.jl` evidence pending |

The strict root-placement count comes from:

```julia
using Wicked
length(Docs.undocumented_names(Wicked; private=false))
```

Enum members and constants are included in this count. They are still public names
and many deliberately use documentation attached to their enum/type owner. The API
audit separately calls `Docs.doc` on each exported value; rerun the audit and
Documenter build after facade changes before treating canonical documentation
coverage as current evidence.

`api/public_api.tsv`, `api/stable_api.tsv`, and `api/experimental_api.tsv` record
every reviewed name and binding kind. The quality gate rejects additions, removals,
and kind changes until the relevant baseline is updated through API review.
`api/experimental_promotions.tsv` records the required promote, qualify, or remove
decision for any future `Wicked.Experimental` binding beyond the namespace marker.

`Wicked.API` provides the candidate stable facade, independently recorded in
`api/stable_api.tsv`. `Wicked.Experimental` currently records only the
compatibility module marker. Names outside the facade should stay qualified under
their owning subsystem until they complete API review. See
[Candidate Stable API](STABLE_API.md).

`api/stable_widget_candidates.tsv` records the widget-specific promotion status.
Stable rows mean `Wicked.API` export plus complete widget evidence, including
render coverage, Toolkit interoperability, semantic coverage, snapshots, and
public `state_for(widget)` construction for stateful widgets. Export alone is
not release evidence.

Stable widget names must also be concrete or parameterized type bindings in
`api/stable_api.tsv`. Constructor-only function exports are valid for helper
APIs, but not for public widget concepts, because the component catalog, widget
candidate report, semantic metadata, precompile coverage, and migration notes
need a durable type identity.

## Ambiguity policy

The quality gate runs `Test.detect_ambiguities(Wicked; recursive=true)` and rejects
every result. Wicked does not maintain a general ambiguity allowlist.

Reactive and theme subscription APIs support both styles:

```julia
subscription = subscribe!(signal, callable_functor)

subscription = subscribe!(signal) do new_value, old_value, source
    # ...
end
```

The source-first form accepts callable objects. Callback-first methods used by
Julia's do-block lowering accept `Function`, preventing a reactive value or theme
registry from also being interpreted as the callback in reversed argument order.

## Downstream extension policy

`test/api_contract.jl` defines its types in a separate module and imports only
public Wicked bindings. It proves that downstream packages can provide:

- Stateless widgets through `render!`.
- Rendering backends through `backend_size`, `backend_capabilities`, and `present!`.
- Input sources through `read_event!`.
- Callable subscription functors without subtype piracy or internal imports.

The test also confirms the HTTP extension is absent when HTTP.jl is not loaded.
Optional integration tests separately load HTTP in an isolated environment.

Production code, package extensions, examples, and benchmarks must not import or
reference `Wicked.Experimental`. The quality gate parses those directories and
rejects direct `Experimental` imports, relative `Experimental` imports, and
qualified `Wicked.Experimental` references so compatibility-only names do not
leak back into the developer-facing surface.

## Freeze blockers

Before an API release candidate:

1. Keep `Wicked.Experimental` empty or document any newly introduced entry with a
   promotion, qualification, or removal decision in
   `api/experimental_promotions.tsv`.
2. Keep source, extension, example, and benchmark code free of
   `Wicked.Experimental` imports.
3. Keep implementation states, internal result records, and subsystem-specific
   constants qualified unless they have a documented stable extension contract.
4. Decide whether value/owner documentation is sufficient for every enum member and
   constant or whether selected names require root-local reference entries.
5. Keep the machine-readable public symbol baseline synchronized only through
   reviewed API changes.
6. Keep public widget concepts backed by concrete or parameterized `Wicked.API`
   type bindings rather than constructor-only function exports.
7. Run ambiguity checks on the oldest and newest supported Julia versions.
8. Test downstream widget, backend, event source, and optional-extension packages
   against the release candidate.
9. Apply the deprecation policy to any name retained from an earlier public release.

The experimental namespace review is complete for the current baseline, but it
remains a release gate for future additions. A generated symbol list without
behavioral documentation would not satisfy this requirement; baselines are change
detectors, not docs.
