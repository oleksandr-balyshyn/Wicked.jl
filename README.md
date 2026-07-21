<p align="center">
  <img src="assets/wicked-logo.svg" width="160" alt="Wicked.jl logo">
</p>

<h1 align="center">Wicked.jl 🧙‍♀️</h1>

<p align="center">
  <b>Serious terminal user interfaces, in pure Julia.</b><br>
  <i>The rendering power of Ratatui, the composition of Textual & Compose, the ergonomics of Terminus & Bubble&nbsp;Tea — one Julia-first framework.</i>
</p>

<p align="center">
  <a href="https://julialang.org/"><img src="https://img.shields.io/badge/Julia-1.10%2B-9558B2?logo=julia&logoColor=white" alt="Julia 1.10+"></a>
  <img src="https://img.shields.io/badge/platform-Linux%20terminals-2F855A?logo=linux&logoColor=white" alt="Linux terminals">
  <img src="https://img.shields.io/badge/dependencies-pure%20Julia-2F6F8F" alt="Pure Julia">
  <img src="https://img.shields.io/badge/API-immediate%20·%20managed%20·%20declarative-183D3D" alt="Three API levels">
  <img src="https://img.shields.io/badge/widgets-180%2B-D18236" alt="180+ widgets">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license">
</p>

---

> [!WARNING]
> Wicked.jl is **`0.0.1`** and under active development. The implementation and
> automated test coverage are extensive, but broad real-terminal validation and
> a release-candidate freeze are still ahead. Great for building and
> experimenting — pin the commit for anything you ship.

## ✨ Why Wicked?

Most terminal libraries make you pick a philosophy. Wicked gives you **three
cooperating layers** over one fast, Unicode-correct rendering core — use the one
that fits the moment, mix them freely.

| | |
| --- | --- |
| ⚡ **Fast, explicit rendering** | Cell buffers, frames, minimal diffs, Unicode/East-Asian width, constraint + flex + grid layout, and 180+ stateful widgets. |
| 🧭 **Real application structure** | An Elm-style `model → update → view` runtime with commands, subscriptions, timers, cancellation, and diagnostics. |
| 🧩 **Declarative composition** | A keyed, reconciling Toolkit with a `@ui` DSL, React/Compose-style hooks, focus, routed events, screens, forms, and overlays. |
| 🎨 **Styling that scales** | A typed style/theme system with CSS-like stylesheets, selectors, pseudo-states, roles, and light/dark/high-contrast. |
| 🧪 **Tests you can trust** | Headless buffers, snapshots, semantic assertions, pilots, and virtual time — no real terminal required. |
| 🌈 **Rich output** | Kitty / Sixel graphics, braille & block canvases, markdown, syntax highlighting, sparklines, charts, and more. |

## 📦 Install

```julia
using Pkg
Pkg.add(url="https://github.com/oleksandr-balyshyn/Wicked.jl")
```

```julia
using Wicked.API   # the single, stable developer facade
```

Everything below is importable from `Wicked.API`.

## 🚀 Quick taste

```julia
using Wicked.API

buffer = Buffer(5, 42)                 # 5 rows × 42 cols
frame  = Frame(buffer)
render!(frame, Paragraph("Deploy safely. Observe everything."), frame.area)

print(plain_snapshot(buffer))          # render anywhere — even headless
```

The same primitives power dashboards, data explorers, interactive CLIs, admin
consoles, and full-screen apps.

---

## 🎚️ Choose your level

### 1️⃣ Immediate mode — direct & deterministic

Own the frame loop; give each widget explicit state.

```julia
using Wicked.API

items = List(["Build", "Test", "Release"])
state = ListState(selected=1)

buffer = Buffer(4, 24)
render!(Frame(buffer), items, buffer.area, state)

handle!(state, items, KeyEvent(Key(:down)); viewport_height=4)  # → selects "Test"
```

### 2️⃣ Managed runtime — Elm-style applications

Your app owns a model; `update!` changes it and returns commands; `app_view`
renders it. Commands cover frames, delays/timers, batches, and exit.

```julia
using Wicked.API
import Wicked.API: app_view, initialize, update!

mutable struct CounterModel; count::Int; end
struct CounterApp <: WickedApp end

initialize(::CounterApp) = CounterModel(0)

app_view(::CounterApp, m::CounterModel) =
    Panel(Paragraph("count = $(m.count)"); block=Block(title="Counter"))

function update!(::CounterApp, m::CounterModel, msg)
    msg === :increment && (m.count += 1; return FrameCommand())
    msg === :tick      && return DelayCommand(0.25, :increment)   # timer
    msg === :quit      && return ExitCommand(m.count)
    return NoCommand()
end

# Drive it headlessly with a pilot + virtual time:
pilot = RuntimePilot(CounterApp(); height=3, width=24)
send!(pilot, :increment)
@assert occursin("count = 1", plain_snapshot(pilot))
send!(pilot, :tick); advance_time!(pilot, 0.25)
@assert occursin("count = 2", plain_snapshot(pilot))
```

Also available: `BatchCommand`, `MessageCommand`, subscriptions, and
cancellation — one observable lifecycle for everything async.

### 3️⃣ Declarative Toolkit — the `@ui` DSL, hooks & modifiers

Describe the UI; the Toolkit reconciles it against retained state using stable
`key`/`id`. Reusable **modifiers** read like Compose/Tailwind; **hooks**
(`use_effect!`, `remember!`, …) manage local state and effects.

```julia
using Wicked.API

const PRIMARY = then(
    element_modifier(focusable=true),
    element_modifier(classes=[:primary], style_role=:primary),
)

view(status) = @ui column(; constraints=[Length(1), Length(3)], gap=0) do
    Element(Label("Deployment: $status"); id=:status, key=:status)
    element(Button("Deploy", :deploy); id=:deploy, key=:deploy, modifier=PRIMARY)
end

pilot = ToolkitPilot(view("ready"); height=5, width=32)
focus_element!(pilot, :deploy)
key!(pilot, :enter)                    # → emits the :deploy message
@assert :deploy in pilot.messages
```

Stateful components with hooks:

```julia
counter = component(initial=0, key=:counter, id=:counter) do state
    n = component_value(state)
    use_effect!(state, :n, (n,)) do _
        # runs on mount / when n changes; return a cleanup closure
        () -> nothing
    end
    "Local count: $n"
end
```

---

## 🧱 Layout in 30 seconds

Ratatui-style constraints, flexbox distribution, and grids:

```julia
using Wicked.API

# Constraints: Length, Min, Max, Percentage, Ratio, Fill
row(
    Element(Label("sidebar")),
    Element(Label("content")),
    Element(Label("aside"));
    constraints=[Length(20), Fill(1), Percentage(25)],
)

# Flex alignment: StartFlex, CenterFlex, EndFlex,
#                 SpaceBetween, SpaceAround, SpaceEvenly
column(Element(Label("top")), Element(Label("bottom")); alignment=SpaceBetween, gap=1)

grid(Element(Label("a")), Element(Label("b")); rows=[Length(1)], columns=[Fill(1), Fill(1)])

# Inside a component, the @ui macro turns do-blocks into children:
@ui column(; constraints=[Length(1), Length(1)]) do
    Element(Label("top")); Element(Label("bottom"))
end
```

Migration-friendly aliases exist too: `hstack`/`vstack`, `hbox`/`vbox`,
`zstack`/`overlay`, `HStack`/`VStack`, … so ports from Textual, Ratatui, or JS
frameworks read naturally.

## 🎨 Styling & themes

A typed `Style`/`Color`/`Modifiers` core, plus CSS-like stylesheets, roles, and
themes with light/dark/high-contrast:

```julia
using Wicked.API

sheet = parse_stylesheet("""
Button.primary        { color: bright-cyan; }
Button.primary:focus  { modifiers: bold underline; }
""")

theme = Theme(:app; roles=Dict(
    :text   => Style(foreground=AnsiColor(15)),
    :accent => Style(foreground=AnsiColor(6), modifiers=BOLD),
))

engine = StyleEngine(; theme, stylesheets=[sheet])   # feed to a ToolkitPilot / tree
```

Colors accept names (`"bright-cyan"`), hex (`"#00d7ff"`), `rgb(...)`, indexed,
or the typed `AnsiColor` / `RGBColor` / `IndexedColor` constructors.

## 🧰 The widget catalog (180+)

<details open>
<summary><b>A tour by category</b></summary>

- 🧾 **Text & content** — `Paragraph`, `Label`, `Heading`, `MarkupText`, `MarkdownView`, `SyntaxView`, `Pretty`, `RichLog`, `LogView`
- 📋 **Collections** — `List`, `Table`, `DataTable`, `DataGrid`, `TreeTable`, `Tree`, `OptionList`, `SelectionList`
- 🗂️ **Navigation** — `Tabs`, `Menu`, `Breadcrumb`, `Pagination`, `Stepper`, `CommandPalette`, `Drawer`
- 🎛️ **Controls** — `Button`, `Checkbox`, `Switch`, `Toggle`, `RadioGroup`, `Select`, `MultiSelect`, `ColorPicker`, `Calendar`
- ⌨️ **Input** — `Input`, `TextArea`, `MaskedInput`, `PasswordField`, `NumberInput`, `SearchInput`, `CodeEditor`
- 📊 **Visualization** — `Gauge`, `LineGauge`, `Sparkline`, `BarChart`, `Chart`, `Histogram`, `Heatmap`, `Canvas`, `Plot`
- 🔔 **Feedback** — `Notification`, `NotificationCenter`, `Alert`, `Badge`, `Spinner`, `Progress`, `ProgressGroup`, `Skeleton`, `LoadingIndicator`
- 🪟 **Structure** — `Block`, `Panel`, `Card`, `Divider`, `Rule`, `Scrollbar`, `Collapsible`, `Popover`, `Overlay`
- 🗃️ **App chrome** — `Header`, `Footer`, `TitleBar`, `Status`, `KeyHint`, `HelpView`, `FileBrowser`, `TerminalView`, `ReplView`

</details>

Not sure of a name? Browse the **`examples/`** directory (each file is a runnable,
tested demo) or the cross-library concept map in `api/widget_vocabulary.tsv`.

## 🧬 Cross-library goodies

Ideas borrowed from the best and made idiomatic (available as `Wicked.*`, ready
to promote into `Wicked.API`):

```julia
using Wicked.API
import Wicked   # these live on the module, ready to promote into Wicked.API

# 🪢 Terminus/Compose-style scoped styling DSL → builds a native `Text`
doc = Wicked.styled_text() do b
    Wicked.styled(b; fg=:cyan, bold=true) do
        Wicked.emit!(b, "Deploy ")
        Wicked.styled(b; fg=:green) do; Wicked.emit!(b, "ready"); end
    end
    Wicked.newline!(b)
    Wicked.emit!(b, "press q to quit"; dim=true)
end
render!(Frame(Buffer(2, 24)), Paragraph(doc), Rect(1, 1, 2, 24))

# 🌊 Harmonica-style spring physics (smooth scroll / progress)
s = Wicked.Spring(1/60; angular_frequency=8.0, damping_ratio=0.6)
pos, vel = Wicked.spring_update(s, 0.0, 0.0, 1.0)

# 🌗 Lip Gloss-style adaptive color + downsampling
Wicked.adaptive_color("black", "white"; dark_background=true)
Wicked.downsample_color(RGBColor(255, 128, 0), :ansi256)

# ⌨️ Bubble Tea-style help from a single keybinding source of truth
binds = [Wicked.KeyBinding("q", "quit"), Wicked.KeyBinding("?", "help")]
Footer(Wicked.help_hints(binds))                    # feeds Footer / HelpView
Wicked.short_help(binds; max_width=40)              # width-truncated one-liner

# 🖼️ Multi-resolution canvas markers & shared-border layout
pc = Wicked.PixelCanvas(4, 8; marker=:quadrant)     # :braille :quadrant :half_block :dot
Wicked.overlap_layout(Rect(1, 1, 3, 20), [10, 10]; overlap=1)   # shared borders
```

## 🧪 Testing (no terminal needed)

Everything renders to a buffer, so tests are fast and deterministic:

```julia
using Wicked.API

pilot = RuntimePilot(CounterApp(); height=3, width=24)
send!(pilot, :increment)

@assert occursin("count = 1", plain_snapshot(pilot))    # text snapshot
```

Pilots (`RuntimePilot`, `ToolkitPilot`, `WidgetPilot`) support key/mouse input,
focus, virtual time (`advance_time!`), semantic queries (`query_one`), and
semantic-tree assertions.

## 📚 Examples

Every file in [`examples/`](examples/) is a self-contained, runnable, CI-tested
program. Run any of them:

```bash
julia --project=. examples/immediate_quickstart.jl
julia --project=. examples/toolkit_quickstart.jl
julia --project=. examples/widget_gallery.jl
```

| Want to… | Start here |
| --- | --- |
| Say hello | `examples/hello_world.jl` |
| Build a complete app | `examples/weather_app.jl` |
| Render widgets by hand | `examples/immediate_quickstart.jl` |
| Build a full app shell | `examples/app_shell_quickstart.jl` |
| Use the Elm-style runtime | `examples/runtime_quickstart.jl` |
| Compose declaratively | `examples/toolkit_quickstart.jl` |
| Style with CSS-like sheets | `examples/styling_quickstart.jl` |
| Charts & canvases | `examples/visualization_quickstart.jl`, `examples/graphics_quickstart.jl` |
| Forms & controls | `examples/controls_quickstart.jl`, `examples/navigation_quickstart.jl` |
| Big virtualized data | `examples/virtualization_quickstart.jl` |
| Keybindings & help | `examples/keybindings_quickstart.jl` |
| Tabs & disclosure | `examples/tabbed_content.jl`, `examples/disclosure_overlay_quickstart.jl` |
| See everything | `examples/widget_gallery.jl` |

## 🗺️ Project layout

```
src/         # the framework (Core, Layout, Runtime, Toolkit, widgets, …)
examples/    # runnable, tested demos — the fastest way to learn the API
test/        # the test suite: julia --project=. -e 'using Pkg; Pkg.test()'
api/         # structured data ledgers (stable API surface, widget vocabulary)
benchmark/   # allocation budgets
```

## 🛠️ Develop

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'
```

Contributions welcome — add a widget, wire up an example, and keep the tests
green. The public surface lives behind `Wicked.API`.

## 📄 License

MIT — see [LICENSE.md](LICENSE.md).

<p align="center"><sub>Built with ⚡ in pure Julia. Deploy safely. Observe everything.</sub></p>
