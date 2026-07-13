# Experimental Compatibility

`Wicked.Experimental` is retained as a compatibility namespace for pre-`1.0`
migration tooling and future short-lived experiments. The current reviewed
baseline exports no application-facing experimental bindings; use `Wicked.API`
for application, widget, runtime, Toolkit, testing, backend, graphics, reactive,
and extension contracts.

```julia
using Wicked.API
```

The facade aliases existing Wicked bindings if future experimental names are
introduced. It does not wrap types or functions.

In the current baseline, `names(Wicked.Experimental; all=false, imported=false)`
contains only `:Experimental`.

`api/experimental_api.tsv` records the compatibility module marker and any future
experimental exports. CI rejects unreviewed drift, but new experimental entries
are not compatibility promises. Names must be promoted into `Wicked.API`, moved
to qualified child modules, renamed with migration notes, or removed before
`1.0`.

`api/experimental_promotions.tsv` is the required ledger for any future
experimental binding. Each non-marker export must name its `promote`, `qualify`,
or `remove` decision, target, review status, and remaining evidence. The quality
gate rejects experimental bindings that lack this plan.

Library authors should not depend on `Wicked.Experimental` for normal
applications. Import `Wicked.API` and qualify subsystem internals through their
owning modules when needed.
