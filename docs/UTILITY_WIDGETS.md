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
to interpret the visual font.

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

## Placeholder

`Placeholder` fills a layout region with a one-cell pattern and centers its label
plus measured dimensions.

```julia
render!(buffer, Placeholder("Chart"), area)
```

It is intended for layout development, unavailable optional components, and
diagnostic screen composition.

## Loading indicator

`LoadingIndicator` and `LoadingIndicatorState` are descriptive aliases for the
existing `Spinner` and `SpinnerState` APIs.
