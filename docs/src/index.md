```@raw html
<p align="center">
  <img src="assets/logo.svg" width="150" alt="Wicked.jl logo">
</p>
```

# Wicked.jl

**Serious terminal user interfaces, in pure Julia.**

Wicked.jl gives you the rendering power of [Ratatui](https://ratatui.rs), the
composition model of [Textual](https://textual.textualize.io) & Jetpack Compose,
and the ergonomics of [Terminus](https://github.com/creativescala/terminus) &
[Bubble Tea](https://github.com/charmbracelet/bubbletea) — as one Julia-first
framework with **no non-Julia dependencies**.

!!! warning "Pre-release"
    Wicked.jl is `0.0.1` and under active development. The implementation and
    automated test coverage are extensive, but broad real-terminal validation
    and a release-candidate freeze are still ahead. Pin the commit for anything
    you ship.

## Three cooperating layers

Most terminal libraries make you pick a philosophy. Wicked gives you three
layers over one fast, Unicode-correct rendering core — use the one that fits,
and mix them freely.

| Layer | Use it when | Feels like |
| --- | --- | --- |
| [**Immediate mode**](guide/immediate.md) | You own the frame loop and want direct control | Ratatui |
| [**Managed runtime**](guide/runtime.md) | You want one observable app lifecycle | Bubble Tea / Elm |
| [**Declarative Toolkit**](guide/toolkit.md) | You want components, hooks, and reconciliation | Textual / React / Compose |

## A first taste

```julia
using Wicked.API

buffer = Buffer(5, 42)                 # 5 rows × 42 cols
frame  = Frame(buffer)
render!(frame, Paragraph("Deploy safely. Observe everything."), frame.area)

print(plain_snapshot(buffer))          # render anywhere — even headless
```

## What's inside

- ⚡ **Rendering core** — cell buffers, frames, minimal diffs, Unicode/East-Asian
  width, and clipping.
- 🧱 **Layout** — Ratatui-style constraints (`Length`, `Min`, `Max`,
  `Percentage`, `Ratio`, `Fill`), flexbox distribution, grids, docking, and flow.
- 🧰 **180+ widgets** — lists, tables, trees, tabs, gauges, charts, canvases,
  inputs, forms, command palettes, notifications, and more.
- 🎨 **Styling & themes** — a typed style core plus CSS-like stylesheets with
  selectors, pseudo-states, roles, and light/dark/high-contrast.
- 🧭 **Runtime** — model/update/view with commands, subscriptions, timers, and
  cancellation.
- 🧩 **Toolkit** — keyed reconciliation, a `@ui` macro, React/Compose-style
  hooks, focus, routed events, and screens.
- 🌈 **Rich output** — Kitty/Sixel graphics, braille & block canvases, markdown,
  and syntax highlighting.
- 🧪 **Testing** — headless buffers, snapshots, semantic assertions, pilots, and
  virtual time.

## Install

```julia
using Pkg
Pkg.add(url="https://github.com/oleksandr-balyshyn/Wicked.jl")
```

Continue to [Getting Started](getting-started.md).
