# Candidate Stable API

`Wicked.API` is the reviewed candidate surface for Wicked's eventual `1.0` API.
It covers the normative immediate-mode, terminal, event, layout, widget, runtime,
toolkit, form, style, graphics, reactive, and testing contracts. Application code
should import this facade by default.

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
- Stable advanced-control state machines, key bindings, render helpers, semantic
  adapters, dialogs, and modal stacks.
- Stable data-entry state machines, validation helpers, key bindings, render
  helpers, and semantic adapters for custom forms.
- Stable diagnostics, frame metrics, inspector snapshots, and runtime
  instrumentation hooks for developer tooling.
- Stable event recording and deterministic replay contracts for reproducible
  sessions and regression tests.
- Stable extension registry, dependency resolution, contribution ownership,
  scoped activation, and service lookup contracts.
- Stable remote frame transport protocol, backend, session, decoder, limits, and
  WebSocket extension hooks.
- Stable stylesheet parsing, selector cascade, theme registry, theme events,
  style-engine binding, role validation, and role-style resolution contracts.
- Terminal graphics protocols, image sources, Unicode fallback, animation state,
  and frame-scoped graphics sinks.
- Reactive values, deterministic widget/application/toolkit pilots,
  pilot-level semantic tree and snapshot helpers, and semantic snapshot
  assertions.

## Widget state convention

Stateful immediate widgets expose explicit state values through `Wicked.API`.
Applications should keep those state values in their model and pass them to
`render!` on every frame:

```julia
list = List(["Build", "Test", "Release"])
state = ListState(selected=1)

render!(buffer, list, area, state)
```

`state_for(widget)` constructs the default state used by preview rendering,
`WidgetPilot`, and simple smoke tests:

```julia
preview_state = state_for(list)
render!(buffer, list, area, preview_state)
render!(buffer, list, area)  # equivalent default-state preview path
```

Do not rebuild default state on every interactive frame. Use it to start a
stateful workflow, then retain and update the returned value.

The widget candidate report treats this as a stabilization requirement: a
stateful widget is not stable unless it is exported through `Wicked.API`, has
complete widget evidence, and exposes public `state_for(widget)` construction.

`Wicked.Experimental` is retained as a compatibility namespace. The current
reviewed baseline has no application-facing experimental bindings; new APIs must
either enter `Wicked.API` through review or stay qualified under their owning
subsystem until they are ready. Any future experimental export must also have a
row in `api/experimental_promotions.tsv` that records its promote, qualify, or
remove decision.

## Compatibility status

This facade is a candidate, not a `1.0` promise while the package version remains
`0.0.x`. `api/stable_api.tsv` records every exported name and binding kind. CI
rejects unreviewed additions, removals, and kind changes for the root module,
candidate facade, and experimental compatibility namespace.

Before `1.0`, maintainers must:

1. Complete behavior and documentation review for every facade entry.
2. Keep `Wicked.Experimental` empty or document any newly introduced
   experimental binding with an explicit promotion/removal plan in
   `api/experimental_promotions.tsv`.
3. Publish migration guidance for removed root imports.
4. Run downstream application and extension tests against a release candidate.

Use qualified child modules for subsystem internals that are intentionally not in
`Wicked.API`.
