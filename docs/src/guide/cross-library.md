# Cross-Library Features

Wicked borrows proven ideas from the wider TUI ecosystem and makes them
idiomatic Julia. These helpers currently live on the `Wicked` module (reach them
with `import Wicked`) and are ready to promote into `Wicked.API`.

```julia
using Wicked.API
import Wicked
```

## 🪢 Scoped styling DSL (Terminus / Compose / Lip Gloss)

A nestable, scoped styling DSL that builds a native `Text`. Inner scopes merge
onto the enclosing style, and each scope restores the previous style on exit —
the Terminus `foreground.green { … }` feel, with Compose-style nesting.

```julia
doc = Wicked.styled_text() do b
    Wicked.styled(b; fg=:cyan, bold=true) do
        Wicked.emit!(b, "Deploy ")
        Wicked.styled(b; fg=:green) do
            Wicked.emit!(b, "ready")               # inherits bold, overrides fg
        end
    end
    Wicked.newline!(b)
    Wicked.emit!(b, "press q to quit"; dim=true)   # one-shot styled fragment
end

render!(Frame(Buffer(2, 24)), Paragraph(doc), Rect(1, 1, 2, 24))
```

Keywords: `fg`, `bg`, `underline_color`, `bold`, `dim`, `italic`, `underline`,
`reverse`, `strikethrough`, `blink`. Colors may be `Color` values, `Symbol`s, or
strings (via `parse_color`).

## 🌊 Spring physics (Harmonica)

A numerically-stable damped-spring integrator for natural motion — smooth
scrolling, progress easing, cursor glide.

```julia
spring = Wicked.Spring(1/60; angular_frequency=8.0, damping_ratio=0.6)
position, velocity = 0.0, 0.0
for _ in 1:120
    position, velocity = Wicked.spring_update(spring, position, velocity, 1.0)
end
```

`damping_ratio < 1` overshoots and settles; `= 1` is critically damped; `> 1` is
slow with no overshoot.

## 🌗 Adaptive color & downsampling (Lip Gloss)

```julia
# Pick a light/dark variant for the terminal background
Wicked.adaptive_color("black", "white"; dark_background=true)   # → AnsiColor(white)

# Reduce a truecolor value to a lower profile, returning a Color
Wicked.downsample_color(RGBColor(255, 128, 0), :ansi256)        # 6×6×6 cube
Wicked.downsample_color(RGBColor(255, 128, 0), :ansi16)         # intensity+dominant
```

The downsampling uses the exact quantisation the ANSI backend applies, so a
pre-downsampled color renders identically to letting the backend degrade it.

## ⌨️ Keybinding help (Bubble Tea `key` + `help`)

A single binding source of truth (key + description + enabled) that drives both
the footer and a width-truncated help line.

```julia
binds = [
    Wicked.KeyBinding("q", "quit"),
    Wicked.KeyBinding("s", "save"; enabled=document_dirty),
    Wicked.KeyBinding("?", "help"),
]

Footer(Wicked.help_hints(binds))                 # feeds Footer / HelpView
Wicked.short_help(binds; max_width=40)           # "q quit • s save • …"
```

`help_hints` returns `KeyHint`s for the *enabled* bindings; `short_help` renders
a single line, dropping entries with an overflow marker to fit `max_width`.

## 🖼️ Multi-resolution canvas markers (Ratatui markers)

Draw on a sub-cell pixel grid and render it with a choice of glyph markers,
trading resolution for terminal compatibility.

```julia
canvas = Wicked.PixelCanvas(4, 8; marker=:quadrant)   # :braille :quadrant :half_block :dot
Wicked.pixel_set!(canvas, 3, 5)
rows = Wicked.pixel_render(canvas)                     # Vector{String}, one per cell row
```

| Marker | Resolution / cell | Notes |
| --- | --- | --- |
| `:braille` | 2×4 | Highest density (U+2800 block). |
| `:quadrant` | 2×2 | Universally supported block quadrants. |
| `:half_block` | 1×2 | Upper/lower half block. |
| `:dot` | 1×1 | Coarsest, maximal compatibility. |

## 🧩 Overlapping layout (Ratatui `Spacing::Overlap`)

Lay out segments that share cells with their neighbours — for blocks that share
a border — without touching the flex engine.

```julia
Wicked.overlap_layout(Rect(1, 1, 3, 20), [10, 10]; overlap=1)   # share 1 column
Wicked.overlap_layout(Rect(1, 1, 3, 20), [10, 10]; overlap=0)   # abut, no overlap
```
