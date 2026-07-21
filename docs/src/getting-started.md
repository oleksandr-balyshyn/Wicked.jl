# Getting Started

## Install

```julia
using Pkg
Pkg.add(url="https://github.com/oleksandr-balyshyn/Wicked.jl")
```

Then bring in the single, stable developer facade:

```julia
using Wicked.API
```

Everything documented in these guides is importable from `Wicked.API`. A small
set of newer, still-internal helpers live on the `Wicked` module itself (see
[Cross-Library Features](guide/cross-library.md)) and are reached with
`import Wicked`.

## Core concepts

A handful of types show up everywhere.

| Type | What it is |
| --- | --- |
| `Buffer` | A 2‑D grid of styled cells — the render target. `Buffer(rows, cols)`. |
| `Frame` | A per-frame handle over a buffer, with an `area`. |
| `Rect` | A rectangular region: `Rect(row, column, height, width)` (1-based). |
| `Style` / `Color` / `Modifiers` | Foreground/background colors and text attributes. |
| `render!` | Draws a widget into a buffer/frame within an area. |
| `handle!` | Feeds an event (key/mouse) to a widget's state. |

Rendering is **explicit and headless-friendly**: you can render any widget into a
`Buffer` and inspect the result as text with `plain_snapshot` — no terminal
required. That is what makes Wicked easy to test.

```julia
using Wicked.API

buffer = Buffer(3, 20)
render!(Frame(buffer), Paragraph("Hello, Wicked!"), buffer.area)
@assert occursin("Hello, Wicked!", plain_snapshot(buffer))
```

## Follow a tutorial

- [Hello, World](tutorials/hello-world.md) — the smallest possible program.
- [Weather App](tutorials/weather-app.md) — a complete interactive TUI.

## Pick a layer

- **[Immediate Mode](guide/immediate.md)** — you drive the loop; each widget
  carries explicit state. Most control, least ceremony.
- **[Managed Runtime](guide/runtime.md)** — an Elm-style `model → update → view`
  application with commands and subscriptions.
- **[Declarative Toolkit](guide/toolkit.md)** — describe the UI with the `@ui`
  macro and components; the Toolkit reconciles it and manages state with hooks.

## Run the examples

Every file in the [`examples/`](https://github.com/oleksandr-balyshyn/Wicked.jl/tree/master/examples)
directory is a self-contained, runnable, CI-tested program:

```bash
julia --project=. examples/immediate_quickstart.jl
julia --project=. examples/toolkit_quickstart.jl
julia --project=. examples/widget_gallery.jl
```

They are the fastest way to see real, working API for every feature.
