# Wicked.jl Component Catalog

This catalog records the intended public component surface. "Implemented" means
the source API exists. It does not imply that the production gates in
`ARCHITECTURE.md` have passed.

## Foundation

| Family | Components and capabilities | Status |
|---|---|---|
| Structure | Block, borders, clear, spacer, rule, padding, box | Implemented |
| Containers | Row, column, stack, overlay, center, grid, dock, flow | Implemented |
| Text | Label, paragraph, heading, markup text, spans, lines, wrapping, alignment | Implemented |
| Scrolling | Scroll state, viewport, ensure-visible, scrollbars | Implemented |
| Navigation | Tabs, menus, screen stack, overlays, drawers, popovers | Implemented |

## Input and selection

| Family | Components and capabilities | Status |
|---|---|---|
| Text editing | Text input, password input, search input, text area, cursor, selection, undo/redo | Implemented |
| Choices | Checkbox, toggle, radio group, select, multiselect | Implemented |
| Actions | Button, bindings, command palette, context menus | Implemented |
| Advanced entry | Numeric input, masked input, tags, autocomplete, combobox | Implemented |
| Pickers | Date, time, color, file, directory, multiple files | Implemented |
| Range controls | Slider, range slider, scrollbar, pagination | Implemented |

## Public widget-name map

Use these names from `Wicked.API` when porting examples from Ratatui, Textual,
TamboUI, or Lanterna. The table lists the preferred application-facing widget
name, not every helper type behind it. Ordinary first-party widgets such as
buttons, tables, charts, menus, notifications, and rich-content views remain
listed in the family sections above and below this map.

Compatibility names are first-class wrappers when they describe a distinct
developer concept. Shared state aliases are listed only when the interaction
state is intentionally identical. Bare widget aliases are rejected by the
compatibility alias audit; use a first-class wrapper or leave the name out of
this map.

This table is quality-gate enforced. Every listed widget name and non-stateless
state contract must be exported by `Wicked.API` as a concrete or parameterized
type binding and must appear as an inline code name in the focused API guides.
Constructor-only widget names are not sufficient: if a catalog entry is a public
widget concept, it must have its own stable type identity so coverage, semantic
metadata, precompile workloads, and migration notes can track it directly.
Every direct renderable in `api/widget_coverage.tsv` must either appear in this
map or be listed in the internal renderable exclusions below.
The review policy is documented in
[API Stabilization](API_STABILIZATION.md#compatibility-widget-names).

| Cross-library concept | Wicked API name | State contract |
|---|---|---|
| Bordered surface | `Border` or `Block` | Stateless |
| Panel/card | `Panel` or `Card` | Stateless |
| Text label | `Label` | Stateless |
| Wrapped paragraph | `Paragraph` | Stateless |
| Heading text | `Heading` | Stateless |
| Markup text | `MarkupText` | Stateless |
| Static display | `Static` or `TextView` | Stateless |
| Rule separator | `Rule`, `Separator`, or `Divider` | Stateless |
| Clear region | `Clear` | Stateless |
| Application shell | `AppShell` | Stateless |
| Header/title bar | `TitleBar` or `Header` | Stateless |
| Footer/status bar | `StatusBar` or `Footer` | Stateless |
| Status message | `Status` | Stateless |
| Breadcrumb navigation | `Breadcrumb` | `BreadcrumbState` |
| Drawer | `Drawer` | `DrawerState` |
| Popover | `Popover` | `PopoverState` |
| Tooltip | `Tooltip` | `TooltipState` |
| Collapsible section | `Collapsible` | `CollapsibleState` |
| Accordion | `Accordion` | `AccordionState` |
| Carousel | `Carousel` | `CarouselState` |
| Timeline | `Timeline` | `TimelineWidgetState` |
| Context menu | `ContextMenu` | `ContextMenuState` |
| Menu | `Menu` | `MenuState` |
| Menu bar | `MenuBar` | Stateless |
| Menu button | `MenuButton` | `MenuButtonState` |
| Navigation rail | `NavigationRail` | `NavigationRailState` |
| Status badge | `Badge` | Stateless |
| Alert message | `Alert` | Stateless |
| Toast message | `Toast` | Stateless |
| Notification list | `NotificationView` | Stateless |
| Managed notification list | `ManagedNotificationView` | Stateless |
| Validation message | `ValidationMessage` | Stateless |
| Validation summary | `ValidationSummary` | Stateless |
| Loading skeleton | `Skeleton` | `SkeletonState` |
| Empty state | `EmptyState` | Stateless |
| Button | `Button` or `PushButton` | `ButtonState` or `PushButtonState` |
| Split button | `SplitButton` | `SplitButtonState` |
| Command palette | `CommandPalette` | `CommandPaletteState` |
| Checkbox | `Checkbox` or `CheckBox` | `CheckboxState` or `CheckBoxState` |
| Toggle switch | `Toggle` or `Switch` | `ToggleState` or `SwitchState` |
| Flow/wrap layout | `Wrap` or `Flow` | Stateless |
| Group composition | `Group` | Stateless |
| Layer composition | `Layer` | Stateless |
| Horizontal layout | `Row`, `hbox`, `hstack`, `horizontal` | Stateless |
| Vertical layout | `Column`, `vbox`, `vstack`, `vertical` | Stateless |
| Grid layout | `Grid` | Stateless |
| Centered layout | `Center` | Stateless |
| Box container | `Box` | Stateless |
| Padding container | `Padding` | Stateless |
| Spacer | `Spacer` | Stateless |
| Scroll view | `ScrollView` | `ScrollState` |
| Scrollbar | `Scrollbar` | `ScrollState` |
| Viewport | `Viewport` | `ScrollState` |
| Virtualized list | `VirtualList` | `VirtualListState` |
| Virtualized table | `VirtualTable` | `VirtualTableState` |
| Virtualized tree | `VirtualTree` | `VirtualTreeState` |
| Split pane | `SplitPane` | Stateless |
| Resizable pane | `ResizablePane` | `ResizablePaneState` |
| Docked application shell | `Dock` or `DockLayout` | Stateless |
| Sidebar shell | `Sidebar` | Stateless |
| Toolbar | `Toolbar` | Stateless |
| Shortcut bar | `ShortcutBar` | Stateless |
| Layered overlay composition | `Overlay`, `Stack`, or `overlay` | Stateless |
| Single-line text field | `Input`, `TextBox`, `TextField`, or `TextInput` | `InputState`, `TextBoxState`, `TextFieldState`, or `TextInputState` |
| Search field | `SearchInput` | `SearchInputState` |
| Password field | `PasswordInput` or `PasswordField` | `TextInputState` or `PasswordFieldState` |
| Multiline text field | `TextArea` or `Textarea` | `TextAreaState` |
| Numeric field | `NumberInput` | `NumberInputState` |
| Masked field | `MaskedInput` | `MaskedInputState` |
| Dropdown/select | `Select` or `Combobox` | `SelectState` |
| Editable combo box | `ComboBox` | `ComboBoxState` |
| Completion list | `Autocomplete` | `AutocompleteState` |
| Slider | `Slider` | `SliderState` |
| Range slider | `RangeSlider` | `RangeSliderState` |
| List box/view | `List`, `ListBox`, `ListView`, or `OptionList` | `ListState`, `ListViewState`, or `OptionListState` |
| Radio button/group | `RadioButton`, `RadioBoxList`, `RadioGroup`, or `RadioSet` | `RadioBoxListState`, `RadioGroupState`, or `RadioSetState` |
| Transfer/multi-select list | `CheckBoxList`, `SelectionList`, `TransferList`, or `MultiSelect` | `CheckBoxListState`, `SelectionListState`, or `MultiSelectState` |
| Modal dialog | `Window`, `Modal`, or `Dialog` | `WindowState` or `DialogState` |
| Date picker | `DatePicker` or `DateInput` | `DatePickerState` |
| Time picker | `TimePicker` or `TimeInput` | `TimePickerState` |
| Date-time picker | `DateTimePicker` or `DateTimeInput` | `DateTimeInputState` |
| Color picker | `ColorPicker` | `ColorPickerState` |
| Tag input | `TagInput` | `TagInputState` |
| File picker | `FilePicker` | `FileBrowserState` |
| Directory picker | `DirectoryPicker` | `FileBrowserState` |
| Directory tree | `DirectoryTree` | `DirectoryTreeState` |
| Multiple-file picker | `MultiFilePicker` | `FileBrowserState` |
| Pagination | `Pagination` | `PaginationState` |
| Progress gauge | `Gauge` or `LineGauge` | Stateless |
| Progress bar | `Progress` or `ProgressBar` | `ProgressState` or `ProgressBarState` |
| Progress group | `ProgressGroup` | `ProgressGroupState` |
| Meter | `Meter` | Stateless |
| Large digits | `Digits` | Stateless |
| Stepper | `Stepper` | `StepperState` |
| Loading indicator | `LoadingIndicator` or `Spinner` | `LoadingIndicatorState` or `SpinnerState` |
| Inline trend | `Sparkline` | Stateless |
| Categorical chart | `BarChart` | Stateless |
| Cartesian chart | `Chart` | Stateless |
| Plot | `Plot` | Stateless |
| Histogram | `Histogram` | Stateless |
| Heatmap | `Heatmap` | Stateless |
| Calendar view | `Calendar` | Stateless |
| Drawing canvas | `Canvas` | Stateless |
| Table | `Table` | `TableState` |
| Data grid | `DataGrid` | `DataGridState` |
| Data state wrapper | `DataStateView` | Stateless |
| Data table | `DataTable` | `DataTableState` |
| Property list | `PropertyList` | `PropertyListState` |
| Key-value list | `KeyValueList` | `KeyValueListState` |
| Metadata list | `MetadataList` | `MetadataListState` |
| Description list | `DescriptionList` | `DescriptionListState` |
| Definition list | `DefinitionList` | `DefinitionListState` |
| Tree | `Tree` or `TreeView` | `TreeState` or `TreeViewState` |
| Tree table | `TreeTable` | `TreeTableState` |
| Tabs | `Tabs` | `TabsState` |
| Tab view | `TabView` | `TabViewState` |
| Tabbed content | `TabbedContentView` | `TabbedContent` |
| Markdown document | `MarkdownView` | Stateless |
| Code view | `CodeView` | Stateless |
| Syntax view | `SyntaxView` | `SyntaxViewState` |
| Code editor | `CodeEditor` | `CodeEditorState` |
| Diff view | `DiffView` | Stateless |
| Error view | `ErrorView` | Stateless |
| Log view | `LogView` | Stateless |
| Rich log | `RichLog` | `RichLogState` |
| Log tail | `LogTail` | `LogTailState` |
| Process view | `ProcessView` | `ProcessViewState` |
| REPL view | `ReplView` | `ReplViewState` |
| Live display | `LiveDisplay` | `LiveDisplayState` |
| Terminal output | `TerminalView` | `TerminalViewState` |
| Task monitor | `TaskMonitor` | `TaskMonitorState` |
| Help view | `HelpView` | Stateless |
| Inspector panel | `Inspector` | `InspectorState` |
| Developer console | `DevConsole` | `DevConsoleState` |
| Terminal image | `ImageView` or `BrailleImage` | Stateless |
| ANSI capture view | `AnsiView` | `AnsiViewState` |
| Hyperlink | `Hyperlink` | `HyperlinkState` |
| Activating link | `Link` | `LinkState` |
| Theme preview | `ThemePreview` | `ThemePreviewState` |
| Julia value display | `Pretty` | Stateless |
| Placeholder panel | `Placeholder` | Stateless |
| Rich styled text | `RichText` | Stateless |

## Internal renderable exclusions

The public widget-name map intentionally omits these direct renderables because
they are infrastructure surfaces rather than application-facing cross-library
widget concepts. Each exclusion must explain why the renderable is not
application-facing and where developers should go instead.

| Renderable | Reason |
|---|---|
| `ToolkitTree` | Internal Toolkit render tree used by reconciliation, testing, and diagnostics; application developers should build declarative UI with `Element`, `row`, `column`, `grid`, `stack`, `ToolkitPilot`, and `render_toolkit!` instead. |

## Collections and large data

| Family | Components and capabilities | Status |
|---|---|---|
| Lists | Stateful list, multiselect, stable keys | Implemented |
| Tables | Table, virtual table, column layout, resize, sort/filter/search | Implemented |
| Trees | Tree, virtual tree, lazy expansion, cycle diagnostics | Implemented |
| Remote data | Paged async sources, loading/error slots, retry, cancellation, LRU pages | Implemented |
| Selection | Deferred range selection and type-ahead navigation | Implemented |

## Rich and developer content

| Family | Components and capabilities | Status |
|---|---|---|
| Markdown | Typed AST, tables, task lists, code fences, links, images | Implemented |
| Syntax | Pluggable lexers, Julia, JSON, shell, SQL | Implemented |
| Source view | Gutters, breakpoints, diagnostics, search, selection, copy | Implemented |
| Diff view | Unified parser, inline view, side-by-side view | Implemented |
| Logs | Log state, filtering-ready view, structured entries | Implemented |
| Help | Help view, key hints, command descriptions | Implemented |

## Data visualization

| Family | Components and capabilities | Status |
|---|---|---|
| Progress | Gauge, line gauge, spinner, stepper | Implemented |
| Series | Sparkline, bar chart, chart, histogram | Implemented |
| Grids | Heatmap, calendar with keyboard and pointer date selection | Implemented |
| Drawing | Canvas, points, lines, Braille rendering | Implemented |
| Terminal images | Kitty, Sixel, Unicode fallback, animation | Implemented |

## Application chrome and feedback

| Family | Components and capabilities | Status |
|---|---|---|
| Chrome | Header, footer, breadcrumbs, badges, key hints | Implemented |
| Feedback | Alert, notifications, skeleton, empty state | Implemented |
| Dialogs | Dialog state, modal stack, dismiss policies | Implemented |
| Navigation | Collapsible, accordion, carousel, timeline | Implemented |
| Split UI | Split pane and pointer resize handles | Implemented |

## Framework services

| Family | Capabilities | Status |
|---|---|---|
| Runtime | Model/update/view, commands, tasks, intervals, cancellation | Implemented |
| Toolkit | Elements, keyed reconciliation, mount/unmount, routed events, screens | Implemented |
| Styling | Themes, semantic roles, selectors, specificity, stylesheet parser | Implemented |
| Forms | Schemas, synchronous and asynchronous validators, summaries | Implemented |
| Reactive | Signals, computed values, effects, transactions, classes, invalidation | Implemented |
| Accessibility | Semantic roles, trees, diffs, actions, announcements | Implemented |
| Automation | Pilot input, queries, clicks, snapshots, semantic actions | Implemented |
| Diagnostics | Traces, frame metrics, inspector panels, instrumentation | Implemented |
| Clipboard | Memory, OSC 52, policies, editor integration | Implemented |
| Drag/drop | Payload negotiation, capture, targets, Toolkit routing | Implemented |
| Extensions | Dependencies, activation, contributions, services | Implemented |
| Reliability | Error boundaries, resource scopes, managed tasks | Implemented |

## Validation status

The repository still requires its production validation campaign. In particular,
the package must be loaded on supported Julia versions from an immutable release
candidate, and all terminal compatibility, real-application, and benchmark gates
must be executed. See `FEATURE_PARITY.md` and `ARCHITECTURE.md` for the remaining
work.
