# Widget Catalog

Wicked ships **180+ widgets**. All are importable from `Wicked.API`. Most render
in immediate mode (`render!`) and many carry explicit state (`*State`) plus an
event handler (`handle!`).

## By category

### 🧾 Text & content
`Paragraph`, `Label`, `Heading`, `MarkupText`, `MarkdownView`, `SyntaxView`,
`Pretty`, `RichLog`, `LogView`, `TextView`, `Static`

### 📋 Collections
`List`, `Table`, `DataTable`, `DataGrid`, `TreeTable`, `Tree`, `TreeView`,
`OptionList`, `SelectionList`, `ListView`

### 🗂️ Navigation
`Tabs`, `Menu`, `Breadcrumb`, `Pagination`, `Stepper`, `CommandPalette`,
`Drawer`, `Carousel`, `Timeline`

### 🎛️ Controls
`Button`, `PushButton`, `Checkbox`, `Switch`, `Toggle`, `RadioGroup`, `RadioSet`,
`Select`, `MultiSelect`, `ColorPicker`, `Calendar`

### ⌨️ Input
`Input`, `TextArea`, `MaskedInput`, `PasswordField`, `NumberInput`,
`SearchInput`, `CodeEditor`

### 📊 Visualization
`Gauge`, `LineGauge`, `Sparkline`, `BarChart`, `Chart`, `Histogram`, `Heatmap`,
`Canvas`, `Plot`, `Digits`

### 🔔 Feedback
`Notification`, `NotificationCenter`, `Alert`, `Badge`, `Spinner`, `Progress`,
`ProgressGroup`, `Skeleton`, `LoadingIndicator`, `Status`

### 🪟 Structure
`Block`, `Panel`, `Card`, `Divider`, `Rule`, `Separator`, `Scrollbar`,
`Collapsible`, `Popover`, `Overlay`, `Placeholder`, `Spacer`, `Padding`, `Clear`

### 🗃️ App chrome
`Header`, `Footer`, `TitleBar`, `KeyHint`, `HelpView`, `FileBrowser`,
`TerminalView`, `ReplView`, `DevConsole`, `Inspector`

## Stateful widget pattern

Stateful widgets follow a consistent contract: a widget value, a `*State`, a
`render!(buffer, widget, area, state)` method, and a `handle!(state, widget,
event)` method.

```julia
using Wicked.API

table = Table(["Name", "Size"], [["main.jl", "4 KB"], ["util.jl", "2 KB"]])
state = TableState(selected_row=1)

buffer = Buffer(4, 30)
render!(buffer, table, buffer.area, state)
handle!(state, table, KeyEvent(Key(:down)); viewport_height=4)
```

## Cross-library concept map

Coming from another framework and want the right name? The
[`api/widget_vocabulary.tsv`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/api/widget_vocabulary.tsv)
ledger maps cross-library concepts (e.g. "Bordered surface", "Panel/card") to
their Wicked widget names and state contracts.

## See everything

[`examples/widget_gallery.jl`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/examples/widget_gallery.jl)
renders a broad selection in one runnable program.
