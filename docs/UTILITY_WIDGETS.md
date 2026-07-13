# Utility Widgets

## Link

`Link` is a focusable, pointer-aware activation widget whose target may be a URL,
message, route, or application value.

```julia
link = Link("Open documentation", :show_docs)
state = LinkState(focused=true)

render!(buffer, link, area, state)
handle!(state, link, event)
message = activate(link, state)
```

`link_semantic_node` exposes `LinkRole` and activation metadata. Disabled links
cannot focus or activate.

## Digits

`Digits` renders numbers, time separators, decimal points, spaces, and minus signs
with a five-row terminal font.

```julia
render!(buffer, Digits("12:45"), area)
```

Unsupported characters render as a question-mark glyph. `digits_semantic_node`
preserves the original value as a read-only status so assistive clients do not need
to interpret the visual font. Use `register_digits_semantic_handlers!` when a
`SemanticPilot` should inspect large digits through focus or select actions.

## Meter and Stepper

Use `Meter` for compact scalar status and `Stepper` for multi-step progress
flows. `Meter` is stateless, while `Stepper` keeps current step and completion
status in `StepperState`:

```julia
meter = Meter(42; minimum=0, maximum=100)
stepper = Stepper(["Queued", "Running", "Done"])
```

Use `register_stepper_semantic_handlers!` when tests or automation should move,
complete, fail, skip, or jump to a step through semantic actions.

## Pretty

`Pretty` renders any Julia value through its `text/plain` display with bounded
`IOContext` dimensions.

```julia
widget = Pretty(model; compact=false, block=Block(title="Model"))
render!(buffer, widget, area)
```

Use it for inspectors, debug panels, REPL-like tools, and placeholder developer
views. User-defined `show` methods execute during rendering and should avoid mutating
application state.

`pretty_text(widget; height, width)` exposes the same bounded `text/plain`
conversion used by the renderer. Use it in inspectors, logs, tests, or semantic
metadata without allocating a buffer:

```julia
text = pretty_text(Pretty((status=:ready, count=3)); height=8, width=40)
node = pretty_semantic_node(Pretty((status=:ready, count=3)); id="model")
```

Use `register_pretty_semantic_handlers!` when tests or accessibility tooling
need to inspect a pretty-printed value through semantic actions.

## Placeholder

`Placeholder` fills a layout region with a one-cell pattern and centers its label
plus measured dimensions.

```julia
render!(buffer, Placeholder("Chart"), area)
```

It is intended for layout development, unavailable optional components, and
diagnostic screen composition.
Use `register_placeholder_semantic_handlers!` when tests should inspect the
placeholder label and fill symbol through semantic automation.

## Loading indicator

`LoadingIndicator` is a first-class wrapper over the existing spinner renderer.
It keeps `LoadingIndicatorState` as a descriptive alias for `SpinnerState`, so
applications can share tick handling with `Spinner` while naming loading
workflows directly.
Use `register_spinner_semantic_handlers!` and
`register_loading_indicator_semantic_handlers!` to expose current frame metadata
and deterministic frame advancement to semantic pilots.

## Skeleton

`Skeleton` renders an animated loading placeholder over the allocated area. It
uses explicit `SkeletonState`, so applications can advance it from runtime ticks
without hidden timers.

```julia
widget = Skeleton()
state = state_for(widget)

handle!(state, widget, TickEvent(UInt64(1), UInt64(1)))
render!(buffer, widget, area, state)
```

Use `render_skeleton(state, width, height)` when a custom component needs the
placeholder as rich lines instead of directly painting a buffer:

```julia
lines = render_skeleton(SkeletonState(), 24, 3; highlight_width=4)
```

Use `register_skeleton_semantic_handlers!` to expose loading phase metadata and
deterministic semantic advancement.

## Empty state

`EmptyState` renders a centered title, optional message, and optional action label
for list, search, and dashboard regions that currently have no content.

```julia
render!(
    buffer,
    EmptyState("No results"; message="Try another query.", action_label="Reset filters"),
    area,
)
```

Use `render_empty_state(empty)` for rich-line adapters, diagnostics, and snapshot
tests:

```julia
empty = EmptyState("No results"; message="Try another query.", action_label="Reset")
lines = render_empty_state(empty)
node = navigation_control_semantic_node(empty, "empty")
```

When the action label should be reachable through semantic automation, register
the generated action node with a dispatcher:

```julia
empty = EmptyState("No results"; action_label="Reset filters")
dispatcher = SemanticDispatcher()

register_empty_state_semantic_handlers!(
    dispatcher,
    "empty",
    empty;
    value=:reset_filters,
)
```
