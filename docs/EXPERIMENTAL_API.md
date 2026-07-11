# Experimental API

`Wicked.Experimental` contains the reviewed pre-`1.0` compatibility surface that
has not entered `Wicked.API`. It is explicit by design:

```julia
using Wicked.API
using Wicked.Experimental
```

The facade aliases existing Wicked bindings and does not wrap types or functions.
It includes advanced controls, remote transport, graphics protocols, diagnostics,
application-service managers, rich adapters, virtualization internals, and detailed
state/result enums still undergoing stability review.

`api/experimental_api.tsv` records every exported name and binding kind. CI rejects
unreviewed drift, but the baseline is not a compatibility promise. Names may be
promoted into `Wicked.API`, moved to qualified child modules, renamed with migration
notes, or removed before `1.0`.

Library authors should avoid re-exporting this entire facade. Import the smallest
set of names needed, or qualify them through their owning module, so future
migrations remain local.
