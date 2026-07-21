# Immediate Mode

Immediate mode is the most direct way to use Wicked: **you own the frame loop**,
and each widget is drawn with explicit state you keep. It maps closely to
Ratatui's model.

## Draw a widget

```julia
using Wicked.API

items = List(["Build", "Test", "Release"])
state = ListState(selected=1)

buffer = Buffer(4, 24)
render!(Frame(buffer), items, buffer.area, state)
```

`render!` has two shapes:

- `render!(target, widget, area)` — for stateless widgets.
- `render!(target, widget, area, state)` — for stateful widgets, where `state`
  is a mutable value you own (e.g. `ListState`, `TableState`).

`target` can be a `Buffer` or a `Frame`. `area` is a `Rect`.

## Handle input

Feed events to a widget's state with `handle!`. It returns `true` when the event
was consumed.

```julia
handle!(state, items, KeyEvent(Key(:down)); viewport_height=4)   # → selects "Test"
handle!(state, items, KeyEvent(Key(:up));   viewport_height=4)
@assert state.selected == 1
```

Mouse events work too:

```julia
event = MouseEvent(Position(2, 3), LeftMouseButton, MouseRelease)
handle!(state, items, event, Rect(1, 1, 4, 24))
```

## Compose a screen

Split the buffer into regions with [layout](layout.md) and render each widget
into its own `Rect`:

```julia
using Wicked.API

buffer = Buffer(10, 48)
frame  = Frame(buffer)

render!(frame, TitleBar("Dashboard"; subtitle="immediate mode"), Rect(1, 1, 2, 48))

items = List(["Build", "Test", "Release"]); items_state = ListState(selected=1)
render!(buffer, items, Rect(3, 1, 3, 18), items_state)

render!(buffer, Gauge(0.6; label="Build"), Rect(7, 1, 1, 30))
render!(buffer, Status("Ready"; severity=:success), Rect(8, 1, 3, 30))
```

## Selection refinements

`List` and `Table` support Ratatui-style scrolling refinements:

```julia
# Keep 1 row of context above/below the selection while scrolling
List(["a", "b", "c", "d"]; scroll_padding=1)

# Control the selection gutter: :always (default), :when_selected, or :never
List(["a", "b", "c"]; highlight_spacing=:when_selected)

Table(["Name", "Size"], rows; scroll_padding=2)
```

See the full runnable version in
[`examples/immediate_quickstart.jl`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/examples/immediate_quickstart.jl).
