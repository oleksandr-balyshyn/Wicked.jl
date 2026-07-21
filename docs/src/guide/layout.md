# Layout

Wicked's layout engine is Ratatui-inspired: **constraints** describe how space is
divided along an axis, **flex alignment** distributes leftover space, and
**grids** handle two dimensions.

## Constraints

Split an axis with a vector of constraints:

| Constraint | Meaning |
| --- | --- |
| `Length(n)` | Exactly `n` cells. |
| `Min(n)` | At least `n` cells. |
| `Max(n)` | At most `n` cells. |
| `Percentage(p)` | `p`% of the available space. |
| `Ratio(a, b)` | `a/b` of the available space. |
| `Fill(weight)` | A weighted share of the remainder. |

```julia
using Wicked.API

row(
    Element(Label("sidebar")),
    Element(Label("content")),
    Element(Label("aside"));
    constraints=[Length(20), Fill(1), Percentage(25)],
)
```

## Rows, columns, stacks, grids

```julia
# Horizontal / vertical containers
row(children...; constraints, gap, alignment, margin)
column(children...; constraints, gap, alignment, margin)

# Overlay stack (later children layer above earlier ones)
stack(children...)

# Two-axis grid
grid(Element(Label("a")), Element(Label("b")); rows=[Length(1)], columns=[Fill(1), Fill(1)])

# Center a fixed-size child
centered(Element(Label("modal")); height=3, width=20)
```

## Flex alignment

`row`/`column` distribute leftover space with a `FlexAlignment`:

`StartFlex`, `CenterFlex`, `EndFlex`, `SpaceBetween`, `SpaceAround`,
`SpaceEvenly` — matching CSS flexbox and Ratatui's `Flex`.

```julia
column(Element(Label("top")), Element(Label("bottom")); alignment=SpaceBetween, gap=1)
```

## Migration aliases

Porting from another framework? Directional aliases read naturally:

- `hstack` / `vstack`, `hbox` / `vbox`, `horizontal` / `vertical`
- `hsplit` / `vsplit`
- `zstack` / `overlay`
- Upper-case `HStack` / `VStack` / `HBox` / `VBox` / `ZStack`

They all resolve to `row` / `column` / `stack`.

## Shared borders

For blocks that should share a border column or row, use the additive
`overlap_layout` helper (see [Cross-Library Features](cross-library.md)):

```julia
import Wicked
Wicked.overlap_layout(Rect(1, 1, 3, 20), [10, 10]; overlap=1)   # segments share 1 column
```

See [`examples/layout_quickstart.jl`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/examples/layout_quickstart.jl).
