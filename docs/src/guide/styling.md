# Styling & Themes

Wicked has a typed styling core plus a CSS-like stylesheet system, roles, and
themes — so you can style a single span or theme an entire application.

## The style core

```julia
using Wicked.API

Style(foreground=AnsiColor(6), background=DefaultColor(), modifiers=BOLD | UNDERLINE)
```

- **Colors**: `AnsiColor(0..15)` (named 16), `IndexedColor(0..255)` (256-color),
  `RGBColor(r, g, b)` (truecolor), `DefaultColor()`.
- **Modifiers**: `BOLD`, `DIM`, `ITALIC`, `UNDERLINE`, `DOUBLE_UNDERLINE`,
  `BLINK`, `REVERSED`, `HIDDEN`, `STRIKETHROUGH` — combine with `|`.
- **`StylePatch`**: a partial update that preserves unspecified properties
  (`StylePatch(add_modifiers=UNDERLINE)`).

Color strings are parsed by `parse_color`: names (`"bright-cyan"`), hex
(`"#00d7ff"`), `"rgb(0, 215, 255)"`, or `"indexed(45)"`.

## CSS-like stylesheets

Parse a stylesheet with selectors and pseudo-states:

```julia
sheet = parse_stylesheet("""
Button.primary        { color: bright-cyan; }
Button.primary:focus  { modifiers: bold underline; }
Button.secondary      { color: yellow; }
""")
```

Selectors support widget types, `.class`, and pseudo-states like `:focus`,
mirroring Textual's TCSS.

## Themes and roles

A `Theme` maps semantic **roles** to styles, so widgets style by intent
(`:accent`, `:error`, `:text`) rather than hard-coded colors:

```julia
theme = Theme(:app; roles=Dict(
    :text   => Style(foreground=AnsiColor(15)),
    :accent => Style(foreground=AnsiColor(6), modifiers=BOLD),
))
```

Combine a theme and stylesheets into a `StyleEngine`, then hand it to a Toolkit
tree or pilot:

```julia
engine = StyleEngine(; theme, stylesheets=[sheet])

root = column(
    Element(Label("Deployments"); id=:title, key=:title, style_role=:accent),
    Element(Button("Deploy", :deploy); id=:deploy, key=:deploy, classes=[:primary], focusable=true);
    constraints=[Length(1), Length(3)],
)

pilot = ToolkitPilot(root; height=4, width=28, styles=engine)
```

Themes support light, dark, and high-contrast preferences, and terminal palette
downgrade when truecolor is unavailable.

## Adaptive color & downsampling

For per-value light/dark pairs and profile downsampling (Lip Gloss style), see
[Cross-Library Features](cross-library.md):

```julia
import Wicked
Wicked.adaptive_color("black", "white"; dark_background=true)   # → white on dark bg
Wicked.downsample_color(RGBColor(255, 128, 0), :ansi256)        # truecolor → 256
```

See [`examples/styling_quickstart.jl`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/examples/styling_quickstart.jl).
