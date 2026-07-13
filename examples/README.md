# Wicked Examples

Run examples from the repository root:

```sh
julia --project=. examples/application_services.jl
julia --project=. examples/immediate_quickstart.jl
julia --project=. examples/layout_quickstart.jl
julia --project=. examples/text_quickstart.jl
julia --project=. examples/scrolling_quickstart.jl
julia --project=. examples/input_events_quickstart.jl
julia --project=. examples/data_display_quickstart.jl
julia --project=. examples/feedback_quickstart.jl
julia --project=. examples/disclosure_overlay_quickstart.jl
julia --project=. examples/file_browser_quickstart.jl
julia --project=. examples/animations_loading_quickstart.jl
julia --project=. examples/tabbed_content.jl
julia --project=. examples/progress_notifications.jl
julia --project=. examples/runtime_quickstart.jl
julia --project=. examples/toolkit_quickstart.jl
julia --project=. examples/styling_quickstart.jl
julia --project=. examples/virtualization_quickstart.jl
julia --project=. examples/testing_quickstart.jl
julia --project=. examples/remote_transport_quickstart.jl
julia --project=. examples/controls_quickstart.jl
julia --project=. examples/rich_content_quickstart.jl
julia --project=. examples/navigation_quickstart.jl
julia --project=. examples/services_quickstart.jl
julia --project=. examples/visualization_quickstart.jl
julia --project=. examples/graphics_quickstart.jl
julia --project=. examples/extensions_quickstart.jl
julia --project=. examples/live_reload.jl
julia --project=. examples/widget_gallery.jl
julia --project=. examples/reference_application.jl
```

These examples use `Wicked.API`, deterministic clocks, and assertions so they can
also serve as starting points for application tests. They exercise reviewed public
APIs only and do not take over the terminal.

The documentation guide `docs/EXAMPLE_FAMILIES.md` maps each quickstart to the
Ratatui, Textual, TamboUI, and Lanterna-style feature family it demonstrates.

## Quickstart map

| Goal | Example |
| --- | --- |
| Learn Ratatui-style immediate rendering with explicit state | `immediate_quickstart.jl` |
| Compose rows, columns, boxes, wrapping flows, and overlays | `layout_quickstart.jl` |
| Render labels, paragraphs, headings, markup, separators, and dividers | `text_quickstart.jl` |
| Build scrollable panes, viewports, and scrollbars | `scrolling_quickstart.jl` |
| Route typed key, mouse, paste, resize, focus, tick, and custom events | `input_events_quickstart.jl` |
| Render tables, data tables, trees, tree tables, and property panes | `data_display_quickstart.jl` |
| Render badges, alerts, status, notifications, and validation feedback | `feedback_quickstart.jl` |
| Build drawers, popovers, tooltips, collapsibles, accordions, and carousels | `disclosure_overlay_quickstart.jl` |
| Manage Toolkit screens and overlays | `screen_stack_quickstart.jl` |
| Browse files, directories, directory trees, and multi-file selections | `file_browser_quickstart.jl` |
| Drive animations, spinners, skeletons, and loading indicators | `animations_loading_quickstart.jl` |
| Learn the managed runtime command/update loop | `runtime_quickstart.jl` |
| Build Textual-style keyed component trees | `toolkit_quickstart.jl` |
| Use CSS-like styling, theme roles, and pseudo-state | `styling_quickstart.jl` |
| Render large lists, tables, and trees | `virtualization_quickstart.jl` |
| Write headless widget and Toolkit tests | `testing_quickstart.jl` |
| Embed Wicked over a remote binary transport | `remote_transport_quickstart.jl` |
| Build form-heavy screens and validation feedback | `controls_quickstart.jl` |
| Render Markdown, code, diffs, logs, and terminal captures | `rich_content_quickstart.jl` |
| Build menus, breadcrumbs, rails, dialogs, and windows | `navigation_quickstart.jl` |
| Coordinate actions, notifications, progress, themes, and tracing | `services_quickstart.jl` |
| Render terminal images with Unicode graphics fallback | `graphics_quickstart.jl` |
| Register extensions and scoped contributions | `extensions_quickstart.jl` |
| See many stable widgets at once | `widget_gallery.jl` |
| Study a larger public-API acceptance composition | `reference_application.jl` |

`widget_gallery.jl` is a deterministic immediate-mode gallery that renders stable
layout, input, text, feedback, loading, native and compatibility selection,
virtual data, modal, overlay, navigation/action surfaces, command-heavy
controls, visualization widgets, rich/developer panes, and
compatibility-wrapper widgets into an in-memory buffer and asserts the resulting
snapshot.

`immediate_quickstart.jl` is a minimal immediate-mode example that renders
directly into a `Buffer`, keeps widget state explicit, handles a key event, and
asserts the resulting plain-text snapshot without opening a real terminal.

`layout_quickstart.jl` is a minimal layout-composition example that renders
rows, columns, wrapping flows, boxes, padding, centering, and layered overlays
into an in-memory buffer.

`text_quickstart.jl` is a minimal text and structure example that renders
labels, paragraphs, headings, markdown-style markup, static text, text views,
rules, separators, and dividers into an in-memory buffer.

`scrolling_quickstart.jl` is a minimal scrolling example that renders
`ScrollView`, `Viewport`, `Scrollbar`, keyboard scrolling, and mouse-wheel
scrolling into an in-memory buffer.

`input_events_quickstart.jl` is a minimal input example that constructs typed
key, mouse, paste, resize, focus, tick, and custom events, routes key and mouse
events through widgets, and renders the resulting state into an in-memory
buffer.

`data_display_quickstart.jl` is a minimal data-display example that renders
`Table`, `DataTable`, `DataStateView`, `TreeView`, `TreeTable`, `PropertyList`,
`KeyValueList`, `MetadataList`, `DescriptionList`, and `DefinitionList` into an
in-memory buffer.

`feedback_quickstart.jl` is a minimal feedback example that renders `Badge`,
`Status`, `Alert`, `Toast`, `NotificationView`, `ValidationMessage`,
`ValidationSummary`, `Header`, and `Footer` into an in-memory buffer.

`disclosure_overlay_quickstart.jl` is a minimal disclosure and overlay example
that renders `Drawer`, `Popover`, `Tooltip`, `Collapsible`, `Accordion`, and
`Carousel` into an in-memory buffer.

`file_browser_quickstart.jl` is a minimal filesystem example that creates a
temporary fixture and renders `FilePicker`, `DirectoryPicker`, `DirectoryTree`,
and `MultiFilePicker` into an in-memory buffer.

`animations_loading_quickstart.jl` is a minimal animation and loading example
that drives `AnimationManager`, `Spinner`, `LoadingIndicator`, `Skeleton`, and
`render_skeleton` with deterministic ticks.

`reference_application.jl` is the release-acceptance composition example. It uses a
managed application, tabs, a selectable table, synchronous and asynchronous form
validation, a confirmation dialog, theme switching, successful and failing
background work, error recovery, headless rendering, and application exit through
public APIs.

`runtime_quickstart.jl` is a minimal managed-runtime example that drives a
`WickedApp` with `RuntimePilot`, messages, delayed commands, batch commands, and
typed exit results without opening a real terminal.

`toolkit_quickstart.jl` is a minimal declarative Toolkit example that drives a
keyed component tree with `ToolkitPilot`, focus, routed input, retained state,
queries, and semantic validation without opening a real terminal.

`styling_quickstart.jl` is a minimal CSS-like styling example that drives a
Toolkit tree with a parsed stylesheet, classes, focus pseudo-state, theme roles,
inline style patches, aggregate style diagnostics, style-context records, formatted and searchable
style-resolution explanations, searchable aggregate diagnostics, selector-aware style traces, compact
style-resolution summaries, and stylesheet rule-match diagnostics with
searchable mismatch reasons without opening a real terminal.

`virtualization_quickstart.jl` is a minimal large-data example that renders
`QueryDataSource`, `VirtualList`, `VirtualTable`, and `VirtualTree` with
explicit state, then wraps them in a Toolkit tree and validates the semantic
roles without opening a real terminal.

`testing_quickstart.jl` is a minimal headless testing example that drives
`WidgetPilot` and `ToolkitPilot`, performs visual snapshot checks, queries keyed
components, routes input, and validates semantic output without opening a real
terminal.

`remote_transport_quickstart.jl` is a minimal remote-frame example that renders
through `RemoteBackend`, decodes emitted protocol packets, ingests typed remote
input through `RemoteSession`, handles resize events, and tracks acknowledgements
without opening a real terminal or loading an HTTP stack.
For browser/WebSocket hosting, pair the same protocol with the optional HTTP.jl
extension documented in `docs/REMOTE_TRANSPORT.md`; serving, authentication,
origin policy, TLS, and rate limits remain application deployment concerns.
The static reference browser client lives in `assets/remote/` and has its own
asset-local deployment checklist.

`controls_quickstart.jl` is a minimal forms and controls example that renders
search, numeric input, tags, autocomplete, combo boxes, choices, sliders,
pickers, and validation feedback into an in-memory buffer.

`rich_content_quickstart.jl` is a minimal rich-content example that renders
Markdown, source code, syntax views, diffs, errors, terminal captures, ANSI text,
links, logs, rich logs, and theme previews into an in-memory buffer.

`navigation_quickstart.jl` is a minimal navigation and action-surface example
that renders breadcrumbs, menu buttons, context menus, navigation rails, modal
dialogs, windows, and status bars into an in-memory buffer.

`services_quickstart.jl` is a minimal application-services example that drives
actions, theme preference, notifications, progress, service pulses, tracing, and
shutdown with an injected deterministic clock.

`visualization_quickstart.jl` is a minimal terminal-dashboard example that
renders gauges, meters, sparklines, bar charts, coordinate charts, plots,
histograms, heatmaps, calendars, canvas drawing, and large digits into an
in-memory buffer.

`graphics_quickstart.jl` is a minimal terminal-graphics example that renders
`ImageView` and `BrailleImage` from a deterministic `RasterImage` and checks
Unicode fallback metadata. It is headless regression coverage; production
graphics claims still require Linux real-terminal evidence for Kitty, WezTerm,
Sixel, and fallback behavior.

`extensions_quickstart.jl` is a minimal extension lifecycle example that
registers descriptors, resolves dependencies, contributes themes, commands,
services, and widgets, and verifies scoped cleanup.
