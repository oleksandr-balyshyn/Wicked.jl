# Immediate Widgets API

This page contains generated reference documentation for Wicked's foundational
stateless and stateful immediate widgets, editing primitives, canvas helpers, and
widget interaction methods.

Stable widget names on this page are application-facing contracts. New widgets
should not be promoted by export alone: add complete behavior evidence, public
docs, examples, semantic/Toolkit coverage, and startup precompile coverage, then
run the widget stabilization release gate before treating the surface as
publishable:

```sh
julia --project=. --startup-file=no scripts/widget_stabilization_gate.jl --release-check
```

Use `Wicked.Experimental` only for short-lived compatibility bindings with an
accepted promotion, qualification, or removal row. Candidate widgets that are not
ready for that gate should remain internal or documented as candidates until the
evidence packet is complete.

## Stable widget support types

Text widgets use `WrapMode` values to control line wrapping:

- `NoWrap`
- `CharacterWrap`
- `WordWrap`

`Paragraph`, `MarkupText`, and rich text adapters accept these modes where
wrapping is configurable.

Use `RichText` when styled `Line` and `Span` values should be passed around as a
direct renderable widget instead of only as lower-level text data:

```julia
rich = RichText(Line([Span("ok"; style=Style(modifiers=BOLD))]))
render!(buffer, rich, area)
```

Use `Label`, `Paragraph`, `Heading`, `MarkupText`, `Rule`, `Separator`, `Divider`, and
`Clear` for the smallest immediate-mode text and structure primitives. `Label`
draws a single aligned text value, `Paragraph` wraps multi-line content,
`Heading` renders level-aware emphasized content with heading semantics,
`MarkupText` renders markdown-style inline/block markup as styled paragraph
content while preserving parsed markdown roles for semantic metadata, `Rule`,
`Separator`, and `Divider` draw separators, and `Clear` resets a region before later widgets
render over it. Use `register_label_semantic_handlers!`,
`register_paragraph_semantic_handlers!`,
`register_heading_semantic_handlers!`,
`register_markup_text_semantic_handlers!`,
`register_static_semantic_handlers!`,
`register_text_view_semantic_handlers!`,
`register_rich_text_semantic_handlers!`,
`register_block_semantic_handlers!`, `register_clear_semantic_handlers!`,
`register_spacer_semantic_handlers!`, `register_rule_semantic_handlers!`,
`register_separator_semantic_handlers!`, and
`register_divider_semantic_handlers!` to expose read-only text and structure
widgets to semantic pilots, accessibility tooling, and smoke tests:

```julia
title = Label("Builds")
body = Paragraph("Queued\nRunning")
section = Heading("Deployments"; level=2)
summary = MarkupText("**Ready** to publish")
```

`MarkupText` keeps parsed markdown role summaries on the widget as immutable
tuples. Use `block_roles` and `inline_roles` when tests, semantic queries, or
tooling need to distinguish headings, paragraphs, strong spans, inline code,
links, tables, and other markdown roles without reparsing the source:

```julia
markup = MarkupText("# Release\n\n**Ready**"; width=40)
@assert has_block_role(markup, :heading_1)
@assert has_inline_role(markup, :strong)
```

For a runnable public-API example, see `examples/text_quickstart.jl`.

`RuleDirection` controls `Rule`, `Separator`, and `Divider` orientation. Use
`HorizontalRule` for row separators and `VerticalRule` for column separators.

For layout composition with borders, cards, panels, rows, columns, boxes,
padding, sidebars, docks, wrapping flows, stacks, overlays, centers, and grids,
see `examples/layout_quickstart.jl`. Use
`register_border_semantic_handlers!`, `register_card_semantic_handlers!`,
`register_panel_semantic_handlers!`, `register_group_semantic_handlers!`,
`register_layer_semantic_handlers!`, `register_flow_semantic_handlers!`,
`register_wrap_semantic_handlers!`, `register_sidebar_semantic_handlers!`,
`register_dock_layout_semantic_handlers!`, `register_dock_semantic_handlers!`,
`register_app_shell_semantic_handlers!`,
`register_padding_semantic_handlers!`, `register_box_semantic_handlers!`,
`register_row_semantic_handlers!`, `register_column_semantic_handlers!`,
`register_stack_semantic_handlers!`, `register_overlay_semantic_handlers!`,
`register_center_semantic_handlers!`, and
`register_grid_semantic_handlers!` to expose read-only layout containers to
semantic pilots, accessibility tooling, and smoke tests.

Use `Sparkline`, `BarChart`, `Chart`, `Timeline`, and `Plot` for Ratatui-style
terminal data visualization. `Sparkline` renders compact trends, `BarChart`
renders categorical magnitudes, `Chart` renders one or more coordinate datasets,
`Timeline` renders event sequences, and `Plot` wraps chart rendering in a bounded
viewport.
`Bar` is the stable categorical data model for `BarChart`:

```julia
chart = BarChart([
    Bar("build", 0.8),
    Bar("test", 0.6),
])
```

Use these support types directly when composing custom dashboards, chart
adapters, or widgets that forward configuration into the built-in renderers.
Use `register_gauge_semantic_handlers!`,
`register_line_gauge_semantic_handlers!`,
`register_sparkline_semantic_handlers!`,
`register_bar_chart_semantic_handlers!`, `register_chart_semantic_handlers!`,
`register_plot_semantic_handlers!`, and `register_meter_semantic_handlers!`
to expose read-only visualization values to semantic pilots and accessibility
tooling.

Use `Histogram`, `Heatmap`, `Calendar`, and `Canvas` for richer terminal
visualization families. `Histogram` groups numeric distributions, `Heatmap`
renders matrix intensity, `Calendar` renders date grids, and `Canvas` gives
applications a low-level drawing surface:

```julia
heatmap = Heatmap(reshape([0.1, 0.5, 0.8, 1.0], 2, 2))
canvas = Canvas(context -> canvas_line!(context, 0.0, 0.0, 1.0, 1.0))
```
Use `register_histogram_semantic_handlers!`,
`register_heatmap_semantic_handlers!`, `register_calendar_semantic_handlers!`,
and `register_canvas_semantic_handlers!` for semantic inspection and
pilot-driven tests of these visualization widgets.

Use `Table`, `VirtualList`, `DataGrid`, `DataStateView`, `DataTable`,
`VirtualTable`, `Tree`, `TreeView`, `VirtualTree`, and `TreeTable` for
retained-mode and Textual data-display ports. `Table`, `Tree`, and `TreeView`
cover immediate in-memory models, while `VirtualList`, `DataGrid`,
`DataStateView`, `DataTable`, `VirtualTable`, `VirtualTree`, and `TreeTable`
connect the same public widget vocabulary to virtual data sources and
loading/empty/error states. Their state contracts are `TableState`,
`VirtualListState`, `DataGridState`, wrapped widget state for `DataStateView`,
`DataTableState`, `VirtualTableState`, `TreeState`, `TreeViewState`,
`VirtualTreeState`, and `TreeTableState`:

```julia
table = Table([TableColumn("Name")], [["build"]])
virtual_list = VirtualList([(name="build", status="ready")];
    key=(row, _) -> row.name,
    format=VirtualListFormat(item=(row, _) -> row.name),
)
query_source = QueryDataSource(
    [(name="build", status="ready"), (name="test", status="queued")];
    query=DataQuery(filters=Dict(:status => "ready"), search="build"),
    search_text=row -> "$(row.name) $(row.status)",
)
data_table = DataTable([(name="build", status="ready")], [
    VirtualTableColumn(:name, "Name"; accessor=row -> row.name),
])
loading_table = DataStateView(data_table; status=DataLoading)
virtual_table = VirtualTable([(name="build", status="ready")], [
    VirtualTableColumn(:name, "Name"; accessor=row -> row.name),
])
tree = Tree([TreeNode(:root, "Root")])
tree_view = TreeView([TreeNode(:root, "Root")])
virtual_tree = VirtualTree(CallbackTreeDataSource{String,Symbol}(
    roots=() -> ["root"],
    children=item -> item == "root" ? ["child"] : String[],
    key=item -> Symbol(item),
))
```

`DataTableState` and `VirtualTableState` are intentionally the same state
contract as `DataGridState`. Use `DataTable` when porting Textual-style table
code, `VirtualTable` when the API should emphasize virtualized large-data
rendering, and `DataGrid` when grid terminology better matches the domain. All
data and virtualized widget states can also be driven through
`register_table_semantic_handlers!`, `register_tree_semantic_handlers!`,
`register_tree_view_semantic_handlers!`,
`register_data_grid_semantic_handlers!`, `register_data_table_semantic_handlers!`,
`register_virtual_list_semantic_handlers!`,
`register_virtual_table_semantic_handlers!`,
`register_virtual_tree_semantic_handlers!`, and
`register_tree_table_semantic_handlers!` for WidgetPilot tests and semantic
automation.

Use `DataStateView` when the screen should keep one data-widget slot while the
application switches between `DataReady`, `DataLoading`, `DataEmpty`, and
`DataError`. `data_state_status`, `data_state_ready`, `data_state_loading`,
`data_state_empty`, and `data_state_error` are stable helpers for update/view
code. Register `register_data_state_view_semantic_handlers!` when tests or
pilots need to assert the loading, empty, or error state semantically.
Use `QueryDataSource` when a local collection needs `DataQuery` filtering,
search, and sorting before it is rendered by `VirtualList`, `DataGrid`, or
`DataTable`. Use `set_query_search!`, `set_query_filter!`,
`clear_query_filter!`, `toggle_query_sort!`, and `clear_query!` for update
functions that change the local query incrementally. `query_data_source` returns
a defensive query copy, and local filters can be exact values, collections, sets,
or callable predicates.
three names keep the same virtual cursor, selected row, selected column,
viewport, and selection model.

Use `PropertyList`, `KeyValueList`, `MetadataList`, `DescriptionList`, and
`DefinitionList` for key-value, metadata, term-description, and glossary-style
inspection panes. Their state contracts are `PropertyListState`,
`KeyValueListState`, `MetadataListState`, `DescriptionListState`, and
`DefinitionListState`, which keep focus and scrolling explicit:

```julia
properties = PropertyList(["status" => "ready"])
metadata = KeyValueList(["region" => "eu"])
details = MetadataList(["version" => "dev"])
descriptions = DescriptionList(["build" => "Compile and test"])
definitions = DefinitionList(["widget" => "Renderable UI unit"])
```

Register `register_property_list_semantic_handlers!`,
`register_key_value_list_semantic_handlers!`,
`register_metadata_list_semantic_handlers!`, and
`register_description_list_semantic_handlers!` or
`register_definition_list_semantic_handlers!` when these panes need semantic
pilot automation. These handlers support focus, scroll-into-view, set-value,
increment, and decrement actions over the list offset.

For runnable public-API examples, see `examples/data_display_quickstart.jl` for
in-memory data displays and `examples/virtualization_quickstart.jl` for large
virtualized data.

Use `TabbedContentView` with `TabbedContent` for Textual-style tabbed content.
`TabbedContent` is the application-owned model/state contract, while
`TabbedContentView` provides the direct renderable surface:

```julia
tabs = TabbedContent([ContentPage(:logs, "Logs", Label("ready"))])
view = TabbedContentView()
```

Register `register_tabbed_content_view_semantic_handlers!` when semantic pilots,
accessibility adapters, or integration tests need to focus tabs, move focus,
activate the focused tab, select a tab, or dismiss closable tabs through the
same retained `TabbedContent` state model used by rendering.

Use `Static`, `TextView`, `MarkdownView`, `CodeView`, `DiffView`, `LogView`, `RichLog`, and `HelpView` for
developer-facing application panes. These names match common Textual and
retained-mode application vocabulary while keeping rendering immediate and
terminal-native:

```julia
summary = Static("Build finished")
details = TextView("Build finished\nArtifacts ready")
docs = MarkdownView("# Release notes")
diff = DiffView("--- old\n+++ new")
log = RichLog()
```

Use `register_help_view_semantic_handlers!` when help overlays or shortcut
panels need semantic-pilot inspection of root metadata and individual key hints.

`RichLogState` is intentionally the same state contract as `LogState`. Use
`RichLog` when porting Textual-style log panes, and use `LogView` when the
shorter Wicked-native name is preferred.

Use `SyntaxView`, `ErrorView`, `ProcessView`, and `ReplView` for richer
developer workflows. `SyntaxViewState`, `ProcessViewState`, and `ReplViewState`
preserve scroll, process, and input history state, while `ErrorView` renders a
stateless error report:

```julia
syntax = SyntaxView("println(:ok)"; language="julia")
error = ErrorView(ErrorException("boom"))
```

Use `register_error_view_semantic_handlers!` when tests or accessibility tooling
need to inspect stateless error panes through semantic actions.

Use `CodeEditor`, `LogTail`, `LiveDisplay`, `TerminalView`, `TaskMonitor`,
`Inspector`, and `DevConsole` for interactive developer/runtime panes.
`CodeEditorState`, `LogTailState`, `LiveDisplayState`, `TerminalViewState`,
`TaskMonitorState`, `InspectorState`, and `DevConsoleState` keep editor,
streaming, scrolling, and visibility state explicit:

```julia
editor = CodeEditor("println(:ok)"; language="julia")
terminal = TerminalView("build complete")
```

Use `register_inspector_semantic_handlers!` and
`register_dev_console_semantic_handlers!` when diagnostics overlays need
pilot-driven focus, dismissal, panel switching, visibility toggling, or console
scrolling.
Use `register_code_editor_semantic_handlers!` when semantic pilots should focus
or replace the text in a `CodeEditor` while preserving the synchronized
`CodeEditorState` and `CodeViewState`.

Use `ImageView`, `BrailleImage`, `AnsiView`, `Hyperlink`, and `ThemePreview`
for media-rich terminal interfaces. `ImageView` and `BrailleImage` render image
content, `AnsiView` preserves captured terminal output with `AnsiViewState`,
`Hyperlink` owns a `HyperlinkState` activation contract, and `ThemePreview`
shows theme palettes with `ThemePreviewState`:

```julia
link = Hyperlink("Open logs", "/var/log/app.log")
ansi = AnsiView("\\e[32mok\\e[0m")
```

Use `register_image_view_semantic_handlers!`,
`register_braille_image_semantic_handlers!`,
`register_ansi_view_semantic_handlers!`,
`register_hyperlink_semantic_handlers!`, and
`register_theme_preview_semantic_handlers!` when pilots or accessibility tooling
need to inspect rich media, activate links, or select themes.

## Default-state rendering

Every built-in stateful immediate widget has two render paths:

```julia
render!(buffer, widget, area, state)  # production path with persistent state
render!(buffer, widget, area)         # preview path with default state
```

Use the explicit-state path in applications so focus, selection, scrolling,
cursor position, edits, and transient interaction state survive redraws. Use the
default-state path for static previews, examples, smoke tests, and simple
composition checks.

`state_for(widget)` constructs the default state used by the preview path:

```julia
list = List(["Build", "Test", "Release"])
state = state_for(list)

render!(Buffer(3, 24), list, Rect(1, 1, 3, 24), state)
```

Use `ListBox`, `ListView`, or `OptionList` when porting code from retained TUI
libraries that name the same pattern as a list box, list view, or option list.
They keep the same `ListState` contract as `List`:

```julia
box = ListBox(["Build", "Test", "Release"])
state = state_for(box)

render!(Buffer(3, 24), box, Rect(1, 1, 3, 24), state)

view = ListView(["Build", "Test", "Release"])
view_state = state_for(view)

options = OptionList(["Build", "Test", "Release"])
option_state = state_for(options)
```

Use `Input`, `TextBox`, `TextField`, or `TextInput` for single-line fields, and
`SearchInput` for query fields. `InputState`, `TextBoxState`, `TextFieldState`,
and `SearchInputState` are aliases over the `TextInputState` editing contract.
`SearchInput` adds search-specific semantics for automation and Toolkit tests:

```julia
name = Input(placeholder="Project name")
name_state = InputState("Wicked")

textbox = TextBox(placeholder="Project name")
textbox_state = TextBoxState("Wicked")

field = TextField(placeholder="Project name")
field_state = TextFieldState("Wicked")

search = SearchInput(placeholder="Find")
state = SearchInputState("query")
render!(buffer, search, area, state)
```

Use `PasswordInput` or `PasswordField` for masked credential fields. They keep
the same `TextInputState`/`PasswordFieldState` editing contract while hiding
semantic values and rendering a single-column mask:

```julia
password = PasswordInput(placeholder="Password", mask="*")
password_field = PasswordField(placeholder="Password", mask="*")
state = TextInputState("secret")
render!(buffer, password, area, state)
```

Use `NumberInput` (or migration alias `NumericInput`) for directly rendered numeric
fields. Use
`NumericInputState` only for data-entry adapters and form components that render
through `render_numeric_input` or `numeric_input_component`:

```julia
number = NumberInput(placeholder="Port")
state = NumberInputState(value=8080, minimum=1, maximum=65535)
render!(buffer, number, area, state)
```

Use `Textarea` when porting code or examples that use the single-word spelling.
It delegates to `TextArea` and keeps the same `TextAreaState`/`TextareaState`
contract:

```julia
notes = Textarea(show_line_numbers=true)
state = TextareaState("first\nsecond")
render!(buffer, notes, area, state)
```

Use `Panel` when porting retained-mode layouts that distinguish panels from
cards. It renders with the same bordered container behavior as `Card` while
preserving panel semantics:

```julia
panel = Panel(Paragraph("Settings"))
render!(buffer, panel, area)
```

Use `Border` when porting code that names the bordered surface directly. It
delegates rendering to `Block` while exposing border semantics:

```julia
border = Border(title="Logs")
render!(buffer, border, area)
```

Use `Wrap` when a ported layout names wrapping behavior directly instead of the
underlying `Flow` layout algorithm:

```julia
wrap = Wrap(Label("Queued"), Label("Running"); column_gap=1)
render!(buffer, wrap, area)
```

Use `Row`, `Column`, `Grid`, `Center`, `Box`, `Padding`, `Spacer`, `Group`,
and `Layer` for
retained or declarative layout ports that name layout primitives directly. These
widgets are stateless containers, so applications can compose them without
allocating separate layout state:

```julia
layout = Column(
    Row(Label("Build"), Spacer(), Badge("READY")),
    Box(Padding(Label("Details"))),
)
```

Use `ScrollView`, `Scrollbar`, and `Viewport` for scrollable content regions
that keep offset in `ScrollState`. Use
`register_scroll_view_semantic_handlers!`,
`register_scrollbar_semantic_handlers!`, and
`register_viewport_semantic_handlers!` when semantic pilots or accessibility
automation should focus, increment, decrement, or scroll to an offset. Use
`SplitPane` for static split layouts when the public API should name a split
surface directly without widget-owned state, and use `ResizablePane` with
`ResizablePaneState` when pointer resizing must persist between frames. Use
`register_split_pane_semantic_handlers!` for read-only split inspection and
`register_resizable_pane_semantic_handlers!` when semantic pilots should focus
or resize the divider:

```julia
scroll = ScrollView(Paragraph("logs"); height=10, width=60)
viewport = Viewport(Paragraph("details"); height=8, width=40)
```

For a runnable public-API example, see `examples/scrolling_quickstart.jl`.
For a complete application-shell example, see `examples/app_shell_quickstart.jl`.

Use `Dock` when the public API should describe an application shell rather than
the lower-level `DockLayout` implementation:

```julia
shell = Dock(top=Label("Header"), top_size=1, center=Paragraph("Body"))
render!(buffer, shell, area)
```

Use `AppShell` when the application has standard chrome and should read like a
single high-level screen definition:

```julia
shell = AppShell(
    Paragraph("Build output");
    title="Wicked",
    subtitle="Deploy monitor",
    toolbar=Toolbar(Button("Run")),
    sidebar=Label("Projects"),
    shortcuts=[:q => "Quit"],
)
layout = app_shell_layout(shell)
summary = app_shell_summary(shell)
```

Use `Sidebar`, `Toolbar`, `ShortcutBar`, and `Status` for immediate application
shell surfaces. They are stateless renderables that make shell structure and
status feedback explicit in application code.

Use `binding_key_hints` when a `BindingMap`, `BindingLayer`, or `BindingStack`
should become visible shortcut help. `ShortcutBar` and `StatusBar` accept binding
sources directly, while `Footer` and `HelpView` accept the returned `KeyHint`
values. This lets an application keep one routing stack and render the matching
footer or help overlay without duplicating shortcut definitions:

```julia
using Wicked.API

bindings = BindingMap()
bind!(bindings, Binding(:q, :quit; modifiers=CTRL, description="Quit"))
bar = ShortcutBar(bindings)
overlay = HelpView(binding_key_hints(bindings))
```

Use `TitleBar` and `StatusBar` for application chrome when you want the public
code to describe shell intent directly while preserving `Header` and `Footer`
rendering behavior:

```julia
title = TitleBar("Wicked"; subtitle="Build monitor")
status = StatusBar([:q => "Quit", :r => "Refresh"])
```

Use `register_header_semantic_handlers!`, `register_footer_semantic_handlers!`,
`register_title_bar_semantic_handlers!`, `register_status_bar_semantic_handlers!`,
`register_menu_bar_semantic_handlers!`, `register_toolbar_semantic_handlers!`,
and `register_shortcut_bar_semantic_handlers!` when shell chrome should be
available to semantic pilots and app automation.

Use `Breadcrumb`, `Badge`, `Alert`, `Toast`, `NotificationView`, and
`ManagedNotificationView` for application chrome and feedback surfaces.
`Breadcrumb` owns a `BreadcrumbState` for keyboard and pointer navigation;
badges, alerts, toasts, and notification views render directly from their input
models. Use `register_badge_semantic_handlers!`,
`register_status_semantic_handlers!`, `register_alert_semantic_handlers!`, and
`register_toast_semantic_handlers!` when semantic pilots should inspect or
acknowledge feedback widgets:

```julia
badge = Badge("READY")
alert = Alert("Deployment failed")
toast = Toast("Saved")
```

Use `Skeleton` and `EmptyState` for loading and no-content feedback. `Skeleton`
uses `SkeletonState` for tick-driven shimmer movement, while `EmptyState`
renders a static title, message, and optional action label without external
state:

```julia
loading = Skeleton()
empty = EmptyState("No results"; message="Try another query.")
```

Use `Overlay` for layered composition when one widget should paint over another
inside the same rectangle. It is the preferred application-facing name when a
ported layout would otherwise call this pattern a `Stack`:

```julia
overlay = Overlay(Paragraph("body"), Label("floating"))
render!(buffer, overlay, area)
```

Use `LoadingIndicator` when porting code that names loading workflows directly
rather than spinner animation mechanics. It shares the same external
`SpinnerState` tick contract as `Spinner`; use `LoadingIndicatorState` when the
state variable should carry loading-oriented intent in application code:

```julia
loading = LoadingIndicator(label="Indexing")
state = state_for(loading)

handle!(state, loading, TickEvent(UInt64(1), UInt64(1)))
render!(buffer, loading, area, state)
```

Use `register_spinner_semantic_handlers!`,
`register_loading_indicator_semantic_handlers!`,
`register_skeleton_semantic_handlers!`, and
`register_placeholder_semantic_handlers!` when semantic pilots should inspect
or advance loading placeholders without relying on wall-clock timers.

Use `Progress` or `ProgressBar` for Textual-style progress indicators and
task-status views where the application owns the progress model. Pass a `ratio`
between zero and one for determinate progress, or leave it as `nothing` for an
indeterminate pulse driven by `ProgressState` or `ProgressBarState` ticks:

```julia
status = Progress(0.42; label="Building")
progress = ProgressBar(ratio=0.42, label="Building")
render!(buffer, progress, area, ProgressBarState())
```

`ProgressState` is intentionally identical to `ProgressBarState`. Use
`Progress` when the application API should use concise generic widget names, and
`ProgressBar` when bar-specific wording is clearer.

For service-backed applications, keep task lifecycle in `ProgressTracker` and
render an aggregate snapshot through the same widget:

```julia
tracker = ProgressTracker{Symbol}()
add_progress_task!(tracker, :build; description="Building", total=10)
advance_progress!(tracker, :build, 4)
render!(buffer, Progress(aggregate_progress(tracker); label="Build"), area, ProgressState())
```

Use `ProgressGroup` with `ProgressGroupState` when several `ProgressTracker`
tasks should render as one live task panel:

```julia
tracker = ProgressTracker{Symbol}()
group = ProgressGroup(tracker; width=60, height=8)
```

Use `Gauge` and `LineGauge` for Ratatui-style progress displays where the
widget itself is a direct ratio view and no external state is required:

```julia
gauge = Gauge(0.75; label="Upload")
line = LineGauge(0.25)
```

Model-backed renderers follow the same convention with an empty default model.
For example, `TabbedContentView` can render a no-content preview directly, while
production code should pass the application-owned `TabbedContent` model.

```@autodocs
Modules = [Wicked.Widgets]
Private = false
```
