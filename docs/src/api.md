# API Reference

The complete developer surface is exported from **`Wicked.API`** — a single,
stable facade. This page documents the headline symbols; the
[guides](guide/immediate.md) carry the narrative, and every feature has a
runnable program under
[`examples/`](https://github.com/oleksandr-balyshyn/Wicked.jl/tree/master/examples).

```julia
using Wicked.API        # widgets, layout, runtime, toolkit, styling, testing
import Wicked           # newer cross-library helpers (see below)
```

## Rendering core

```@docs
Wicked.Buffer
Wicked.Frame
Wicked.Rect
```

## Text & style

```@docs
Wicked.Style
Wicked.Line
Wicked.Text
Wicked.parse_color
```

## Selection widgets

```@docs
Wicked.List
Wicked.ListState
Wicked.Table
Wicked.Block
```

## Cross-library helpers

Scoped styling DSL, spring physics, adaptive color, keybinding help, canvas
markers, and overlapping layout. Reach these with `import Wicked` (they are
ready to promote into `Wicked.API`). See
[Cross-Library Features](guide/cross-library.md) for usage.

```@docs
Wicked.styled_text
Wicked.StyledTextBuilder
Wicked.styled
Wicked.emit!
Wicked.newline!
Wicked.Spring
Wicked.spring_update
Wicked.adaptive_color
Wicked.downsample_color
Wicked.KeyBinding
Wicked.help_hints
Wicked.short_help
Wicked.PixelCanvas
Wicked.pixel_set!
Wicked.pixel_render
Wicked.overlap_layout
```

!!! note "The full surface"
    `Wicked.API` re-exports well over a thousand bindings — widgets, states,
    layout helpers, runtime and toolkit types, pilots, and semantic helpers.
    Browse them from the REPL with `names(Wicked.API)`, or explore the
    categorized [Widget Catalog](guide/widgets.md).
