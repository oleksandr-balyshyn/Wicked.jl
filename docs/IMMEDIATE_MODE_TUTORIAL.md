# Immediate-mode Tutorial

This tutorial builds a terminal interface whose application owns every state value. Immediate mode is the closest Wicked API to Ratatui: each frame renders ordinary widget descriptions into a buffer, while stateful widgets receive a separate persistent state object.

## Render the first frame

Start with a headless backend. It uses the same frame and buffer pipeline as an interactive terminal without changing terminal modes:

```julia
using Wicked.API

backend = TestBackend(5, 32)
terminal = Terminal(backend)

draw!(terminal) do frame
    render!(frame, Label("Wicked is running"), frame.area)
end

println(plain_snapshot(backend.screen))
```

`Frame` owns the current target buffer and clipping area. Widgets never print directly to standard output.

## Keep widget state outside the widget

A `Button` is an immutable description. `ButtonState` holds focus and press state across frames:

```julia
button = Button("Run", :run_requested)
state = ButtonState(focused=true)

draw!(terminal) do frame
    render!(frame, button, frame.area, state)
end
```

The application routes input into that state:

```julia
event = KeyEvent(Key(:enter))
handled = handle!(state, button, event, backend.screen.area)

@assert handled
@assert state.pressed
@assert activate(button, state) == :run_requested
```

Keep the state object when rebuilding the widget description. Replacing `ButtonState()` every frame would also reset interaction state every frame.

## Compose layout without nesting buffers

Resolve layout areas and render each widget into its assigned rectangle:

```julia
layout = FlexLayout(
    VerticalLayout,
    [Length(1), Fill(1), Length(3)];
    gap=1,
)

draw!(terminal) do frame
    header, body, footer = resolve(layout, frame.area)
    render!(frame, Label("Build dashboard"; alignment=CenterAlign), header)
    render!(frame, Paragraph("Waiting for work..."), body)
    render!(frame, button, footer, state)
end
```

`Rect` coordinates are one-based. Layout resolution is pure and does not render or allocate terminal resources.

## Test interaction without a terminal

`WidgetPilot` creates state automatically for built-in stateful widgets:

```julia
pilot = WidgetPilot(Button("Save", :save); height=3, width=16)

key!(pilot, :enter)

@assert pilot.state.pressed
@assert occursin("Save", plain_snapshot(pilot))
```

Use cell assertions when style matters and plain snapshots when only visible text matters.

## Implement an external widget

`render!` is an open multiple-dispatch interface. External packages do not register widget types globally:

```julia
struct StatusLine
    label::String
    healthy::Bool
end

function Wicked.render!(frame::Frame, widget::StatusLine, area::Rect)
    role = widget.healthy ? AnsiColor(2) : AnsiColor(1)
    render!(
        frame,
        Label(widget.label; style=Style(foreground=role)),
        area,
    )
end
```

Add a four-argument `render!` method when the custom widget has explicit state.

## Move to a managed application when needed

Immediate mode is sufficient when an existing loop owns input, state, and redraw timing. Use `WickedApp` when Wicked should own terminal cleanup, commands, subscriptions, resize delivery, and exit. Use Toolkit when keyed component state, routed events, screens, semantic trees, or stylesheet selectors become more valuable than direct frame control.
