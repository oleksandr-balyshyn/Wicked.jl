# API Stability Audit

Wicked's public API is not frozen. Passing tests and broad feature coverage do not
make the current `0.0.1` root namespace suitable for a `1.0` compatibility promise.
This page records executable evidence and remaining blockers.

## Current evidence

Audit date: 2026-07-11.

| Check | Current result | Release meaning |
| --- | ---: | --- |
| Root exported bindings | 3 | `Wicked`, `API`, and `Experimental` only |
| Candidate stable bindings | 374 | Independently baselined |
| Experimental bindings | 1,612 | Reviewed pre-`1.0` compatibility surface |
| Undefined exports | 0 | Passing quality gate |
| Recursive method ambiguities | 0 after subscription fixes | Passing quality gate |
| Root bindings without root-local docs | 1,681 | Canonical docs resolve through value/owner |
| Exports without discoverable docs | 0 | Passing quality gate |
| HTTP extension loaded without HTTP | No | Passing optional-loading gate |
| External widget contract | Passing | Uses only root public interfaces |
| External backend contract | Passing | Uses only `AbstractBackend` methods |
| External input-source contract | Passing | Uses only `AbstractInputSource` methods |

The strict root-placement count comes from:

```julia
using Wicked
length(Docs.undocumented_names(Wicked; private=false))
```

Enum members and constants are included in this count. They are still public names
and many deliberately use documentation attached to their enum/type owner. The API
audit separately calls `Docs.doc` on each exported value; all 1,985 currently have
discoverable canonical documentation. Documenter builds across Wicked and every
owned child module, so those canonical docstrings appear in the generated manual.

`api/public_api.tsv`, `api/stable_api.tsv`, and `api/experimental_api.tsv` record
every reviewed name and binding kind. The quality gate rejects additions, removals,
and kind changes until the relevant baseline is updated through API review.

`Wicked.API` provides the candidate stable facade, independently recorded in
`api/stable_api.tsv`. Names outside that facade remain compatibility or experimental
surface until explicitly promoted. See [Candidate Stable API](STABLE_API.md).

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

## Freeze blockers

Before an API release candidate:

1. Review every `Wicked.Experimental` entry for promotion, qualification, or removal.
2. Reduce experimental exports that are implementation states, internal result
   records, or subsystem-specific constants better accessed through a child module.
3. Decide whether value/owner documentation is sufficient for every enum member and
   constant or whether selected names require root-local reference entries.
4. Keep the machine-readable public symbol baseline synchronized only through
   reviewed API changes.
5. Run ambiguity checks on the oldest and newest supported Julia versions.
6. Test downstream widget, backend, event source, and optional-extension packages
   against the release candidate.
7. Apply the deprecation policy to any name retained from an earlier public release.

The experimental namespace review remains blocking even though root reduction and
canonical documentation coverage are complete. A generated symbol list without
behavioral documentation would not satisfy this requirement; baselines are change
detectors, not docs.
