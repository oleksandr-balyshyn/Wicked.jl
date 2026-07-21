# Tutorial: Hello, World

The smallest possible Wicked program. It shows the one idea everything else
builds on: **you render widgets into a `Buffer`, and a buffer can be inspected as
plain text — no terminal required.**

The complete file is
[`examples/hello_world.jl`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/examples/hello_world.jl).
Run it with:

```bash
julia --project=. examples/hello_world.jl
```

## The whole program

```julia
using Wicked.API

# 1. Make a buffer: 3 rows tall, 34 columns wide.
buffer = Buffer(3, 34)

# 2. Render a bordered panel containing a paragraph into the whole buffer.
render!(
    Frame(buffer),
    Panel(Paragraph("Hello, Wicked!"); block=Block(title="hello")),
    buffer.area,
)

# 3. Look at the result.
println(plain_snapshot(buffer))
```

## What it prints

```text
╭─hello──────────────────────────╮
│Hello, Wicked!                  │
╰────────────────────────────────╯
```

## Line by line

- **`Buffer(3, 34)`** — a grid of styled cells, 3 rows by 34 columns. This is the
  render target. In a real app the terminal backend owns one of these; here we
  make our own so we can print it.
- **`Frame(buffer)`** — a per-frame handle over the buffer. `render!` accepts a
  `Buffer` or a `Frame`.
- **`Paragraph("Hello, Wicked!")`** — wrappable, styled text.
- **`Panel(...; block=Block(title="hello"))`** — a bordered container. `Block`
  carries the border and title; `Panel` renders a child inside it.
- **`render!(target, widget, area)`** — draws the widget into `area` (here
  `buffer.area`, the whole buffer).
- **`plain_snapshot(buffer)`** — returns the on-screen text with styling
  stripped. This is what makes Wicked trivial to test: assert on the text.

## Next

- Add explicit state and input in [Immediate Mode](../guide/immediate.md).
- Build a real interactive app in the [Weather App](weather-app.md) tutorial.
