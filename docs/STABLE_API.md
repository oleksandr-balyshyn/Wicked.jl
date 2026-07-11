# Candidate Stable API

`Wicked.API` is the reviewed candidate surface for Wicked's eventual `1.0` API.
It covers the normative immediate-mode, terminal, event, layout, widget, runtime,
toolkit, form, style, reactive, and testing contracts while the broad pre-`1.0`
root namespace remains available for compatibility and experimentation.

Use the candidate surface in applications that want early feedback about the
planned stable developer experience:

```julia
using Wicked.API

terminal = Terminal(TestBackend(8, 40))
draw!(terminal) do frame
    render!(frame, Paragraph("Stable facade"), frame.area)
end
```

`Wicked.API` reuses the exact root types and generic functions. It does not wrap
values, introduce duplicate dispatch domains, or prevent third-party `render!`,
backend, and input-source methods.

## Surface policy

The facade includes:

- Geometry, cells, Unicode width, text, styles, buffers, frames, and `render!`.
- ANSI, inline, test, and third-party backend contracts plus terminal ownership.
- Typed input events, parsers, and custom input-source contracts.
- Constraint, flex, grid, dock, flow, and centering layout primitives.
- Required `1.0` immediate widgets and their explicit state values.
- Managed model/update/view commands and subscriptions.
- Declarative toolkit identity, reconciliation, routing, forms, and themes.
- Reactive values and deterministic widget/application/toolkit pilots.

Advanced controls, protocol-specific graphics, remote transport, diagnostics,
extension-registry internals, and rapidly evolving domain adapters remain on the
`Wicked.Experimental` or qualified subsystem surfaces until their contracts
complete a separate stability review.

## Compatibility status

This facade is a candidate, not a `1.0` promise while the package version remains
`0.0.x`. `api/stable_api.tsv` records every exported name and binding kind. CI
rejects unreviewed additions, removals, and kind changes for the root module,
candidate facade, and experimental facade.

Before `1.0`, maintainers must:

1. Complete behavior and documentation review for every facade entry.
2. Promote, retain, or remove every `Wicked.Experimental` binding.
3. Publish migration guidance for removed root imports.
4. Run downstream application and extension tests against a release candidate.

Use `Wicked.Experimental`, `Wicked.RemoteTransport`, `Wicked.Graphics`, and other
qualified child modules for subsystems not in `Wicked.API`.
