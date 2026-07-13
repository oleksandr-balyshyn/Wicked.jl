# Porting Cookbook

This cookbook maps common Ratatui, Textual, TamboUI, and Lanterna application
shapes to the Wicked APIs and examples that should be used first.

It is a developer workflow guide. Production parity still depends on the release
gates in [Feature Parity Ledger](FEATURE_PARITY.md), [Validation Strategy](VALIDATION_STRATEGY.md),
and [Release Checklist](RELEASE_CHECKLIST.md).

## Pick the closest app shape

| Source shape | Wicked path | Start with |
|---|---|---|
| Ratatui draw loop | Immediate rendering with explicit state | `examples/immediate_quickstart.jl` |
| Ratatui layout-heavy dashboard | Immediate layout widgets | `examples/layout_quickstart.jl` |
| Ratatui list/table/tree app | Immediate and virtual data widgets | `examples/data_display_quickstart.jl`, `examples/virtualization_quickstart.jl` |
| Textual widget tree | Keyed Toolkit tree | `examples/toolkit_quickstart.jl` |
| Textual CSS app | Stylesheets and theme engine | `examples/styling_quickstart.jl` |
| Textual Pilot tests | Widget/Toolkit pilots and semantics | `examples/testing_quickstart.jl` |
| Textual workers/actions | Runtime commands and services | `examples/runtime_quickstart.jl`, `examples/services_quickstart.jl` |
| TamboUI immediate app | Immediate widgets and buffer snapshots | `examples/immediate_quickstart.jl` |
| TamboUI Toolkit app | Toolkit elements, routes, and reactive state | `examples/toolkit_quickstart.jl` |
| Lanterna retained forms | Controls, forms, dialogs, and navigation | `examples/controls_quickstart.jl`, `examples/navigation_quickstart.jl` |
| Lanterna file browser | File picker widgets | `examples/file_browser_quickstart.jl` |
| Remote/browser adapter | Remote frame transport | `examples/remote_transport_quickstart.jl` |

## Translate common responsibilities

| Responsibility | Use in Wicked | Example |
|---|---|---|
| Terminal geometry | `Rect`, `Position`, `Size` | `examples/immediate_quickstart.jl` |
| Styled text | `Span`, `Line`, `Text`, `Label`, `Paragraph`, `Heading` | `examples/text_quickstart.jl` |
| Layout | `Row`, `Column`, `Grid`, `Wrap`, `Box`, `Padding`, `Stack` | `examples/layout_quickstart.jl` |
| Scrollable panes | `ScrollView`, `Viewport`, `Scrollbar`, `ScrollState` | `examples/scrolling_quickstart.jl` |
| Typed input | `KeyEvent`, `MouseEvent`, `PasteEvent`, `ResizeEvent`, `FocusEvent` | `examples/input_events_quickstart.jl` |
| Data tables | `Table`, `DataTable`, `VirtualTable`, `DataGrid` | `examples/data_display_quickstart.jl` |
| Trees | `Tree`, `TreeView`, `VirtualTree`, `TreeTable` | `examples/data_display_quickstart.jl` |
| Forms | `Form`, field states, validation widgets | `examples/controls_quickstart.jl` |
| Feedback | `Badge`, `Status`, `Alert`, `Toast`, notifications | `examples/feedback_quickstart.jl` |
| Overlays | `Drawer`, `Popover`, `Tooltip`, `Modal`, `Window` | `examples/disclosure_overlay_quickstart.jl`, `examples/navigation_quickstart.jl` |
| Rich panes | Markdown, code, syntax, diffs, logs, terminal views | `examples/rich_content_quickstart.jl` |
| Visualizations | Gauges, charts, plots, histograms, heatmaps, canvas | `examples/visualization_quickstart.jl` |
| Animation and loading | `AnimationManager`, `Spinner`, `LoadingIndicator`, `Skeleton` | `examples/animations_loading_quickstart.jl` |
| Runtime loop | `WickedApp`, messages, commands, subscriptions | `examples/runtime_quickstart.jl` |
| App services | Actions, progress, themes, notifications, tracing | `examples/services_quickstart.jl` |

## Migration rules of thumb

1. Use `using Wicked.API` in application code.
2. Keep widget state explicit when selection, focus, scrolling, cursor, or animation frame must survive redraws.
3. Prefer `state_for(widget)` for initial state construction, previews, examples, and smoke tests.
4. Use immediate widgets for high-volume rendering and Toolkit for retained identity, focus scopes, styling, and semantic queries.
5. Route terminal input as typed events instead of parsing escape sequences inside widgets.
6. Put background work behind runtime commands, subscriptions, services, or managed tasks.
7. Use `WidgetPilot`, `ToolkitPilot`, `RuntimePilot`, `pilot_semantic_tree`, and
   `pilot_semantic_snapshot` for tests instead of scraping ANSI output. Prefer
   `assert_semantic_snapshot` when the expected semantic tree should be fixed.
8. Keep root and internal Wicked modules out of examples and application imports unless extending internals deliberately.

## Evidence boundary

The cookbook points to implemented public APIs and examples. It does not prove a
release candidate. Before publishing, run the checks in [Validation Strategy](VALIDATION_STRATEGY.md)
and archive evidence in [Release Evidence](RELEASE_EVIDENCE.md).
