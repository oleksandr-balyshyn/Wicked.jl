# Declarative Toolkit

The Toolkit is Wicked's **declarative layer**. You *describe* the UI as an element
tree; the Toolkit reconciles it against retained state using stable `key`/`id`
values, routes events, manages focus, and runs component effects. It feels like
Textual, React, and Jetpack Compose — while still rendering through Wicked's
immediate-mode core.

## The `@ui` macro

The `@ui` macro turns zero-argument `do` blocks into element children, so a UI
tree reads top-to-bottom:

```julia
using Wicked.API

const PRIMARY = then(
    element_modifier(focusable=true),
    element_modifier(classes=[:primary], style_role=:primary),
)

view(status) = @ui column(; constraints=[Length(1), Length(3)], gap=0) do
    Element(Label("Deployment: $status"); id=:status, key=:status)
    element(Button("Deploy", :deploy); id=:deploy, key=:deploy, modifier=PRIMARY)
end
```

- `Element(widget; id, key, ...)` wraps any widget as a tree node.
- `element(widget; ...)` is the same, with light-weight defaults.
- `key` keeps local state stable across rebuilds; `id` addresses a node for
  focus, queries, and semantics.

## Reusable modifiers

`element_modifier(...)` bundles element properties — `classes`, `style_role`,
`style_patch`, `focusable`, `disabled`, `hidden`, `tab_index`, `key`/`id` — into
a preset applied with `modify` or the `modifier=` keyword. Chain presets with
`then(...)`. These read like Compose modifiers or Tailwind class sets while
staying fully typed.

```julia
const FOCUSABLE = element_modifier(focusable=true)
const DANGER    = then(FOCUSABLE, element_modifier(classes=[:danger], style_role=:error))
```

## Drive it with a pilot

```julia
pilot = ToolkitPilot(view("ready"); height=5, width=32)
@assert occursin("Deployment: ready", plain_snapshot(pilot))

focus_element!(pilot, :deploy)
key!(pilot, :enter)                       # emits the :deploy message
@assert :deploy in pilot.messages

query_one(pilot; id=:deploy, widget_type=Button, focused=true)   # semantic query
```

## Components and hooks

Components own local state managed by **hooks** — a React/Compose-style API. The
framework retains a `ComponentState` for each stable `key`, so remembered values
and running effects survive re-renders.

```julia
counter = component(initial=0, key=:counter, id=:counter) do state
    n = component_value(state)
    use_effect!(state, :n, (n,)) do _
        # runs on mount and whenever n changes; return a cleanup closure
        () -> nothing
    end
    "Local count: $n"
end
```

Available hooks include:

- `remember!` — retain a value across renders.
- `state_binding` — a get/set binding into retained state.
- `use_effect!` — run a side effect with a cleanup, keyed on dependencies.
- `use_resource!` / `load_async_resource!` — load async data.
- `launched_effect!` / `side_effect!` — fire-and-forget effects.

## Screens

Toolkit apps can keep a stack of screens (`ScreenStack`) and navigate with
commands like `PushScreen`, `PopScreen`, and `ReplaceWithScreen` — mirroring
Textual's screen model — for modal dialogs, wizards, and routed navigation.

The full runnable version — including semantics, context, and component
lifecycle — is in
[`examples/toolkit_quickstart.jl`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/examples/toolkit_quickstart.jl).
