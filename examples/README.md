# Wicked Examples

The example index maps every examples/*.jl file to a feature family and keeps all
public example coverage discoverable for stable-widget release evidence.

## Running examples

From the repository root:

```sh
julia --project=. examples/<example>.jl
```

Replace `<example>` with one of the files listed in the table below.

These examples use `Wicked.API`, deterministic clocks, and assertions, so they can
also be reused as start points for application tests. They exercise reviewed
public APIs and avoid terminal takeover.

| Goal | Example |
| --- | --- |
| Build application shell primitives | [`app_shell_quickstart.jl`](app_shell_quickstart.jl) |
| Learn Ratatui-style immediate rendering with explicit state | [`immediate_quickstart.jl`](immediate_quickstart.jl) |
| Compose rows, columns, boxes, wrapping flows, and overlays | [`layout_quickstart.jl`](layout_quickstart.jl) |
| Render labels, paragraphs, headings, and separators | [`text_quickstart.jl`](text_quickstart.jl) |
| Build scrollable panes, viewports, and scrollbars | [`scrolling_quickstart.jl`](scrolling_quickstart.jl) |
| Route typed key, mouse, paste, resize, focus, tick, and custom events | [`input_events_quickstart.jl`](input_events_quickstart.jl) |
| Render tables, trees, and property data surfaces | [`data_display_quickstart.jl`](data_display_quickstart.jl) |
| Render badges, alerts, status, notifications, and validation feedback | [`feedback_quickstart.jl`](feedback_quickstart.jl) |
| Build drawers, popovers, tooltips, collapsibles, and overlays | [`disclosure_overlay_quickstart.jl`](disclosure_overlay_quickstart.jl) |
| Browse files and directory trees | [`file_browser_quickstart.jl`](file_browser_quickstart.jl) |
| Drive animations, spinners, skeletons, and loading indicators | [`animations_loading_quickstart.jl`](animations_loading_quickstart.jl) |
| Learn managed runtime command/update loops | [`runtime_quickstart.jl`](runtime_quickstart.jl) |
| Build Textual-style component trees with Toolkit semantics | [`toolkit_quickstart.jl`](toolkit_quickstart.jl) |
| Use CSS-like styling and pseudo-state behavior | [`styling_quickstart.jl`](styling_quickstart.jl) |
| Render large virtual lists, tables, and trees | [`virtualization_quickstart.jl`](virtualization_quickstart.jl) |
| Add visualization and charting examples | [`visualization_quickstart.jl`](visualization_quickstart.jl) |
| Write headless widget and Toolkit tests | [`testing_quickstart.jl`](testing_quickstart.jl) |
| Embed Wicked over a remote transport | [`remote_transport_quickstart.jl`](remote_transport_quickstart.jl) |
| Build form-heavy control surfaces | [`controls_quickstart.jl`](controls_quickstart.jl) |
| Render Markdown, code, diffs, logs, and terminals | [`rich_content_quickstart.jl`](rich_content_quickstart.jl) |
| Build navigation surfaces and modal windows | [`navigation_quickstart.jl`](navigation_quickstart.jl) |
| Coordinate actions, progress, and tracing services | [`services_quickstart.jl`](services_quickstart.jl) |
| Render terminal images with Unicode graphics fallback | [`graphics_quickstart.jl`](graphics_quickstart.jl) |
| Register extensions and scoped contributions | [`extensions_quickstart.jl`](extensions_quickstart.jl) |
| Add deterministic application services | [`application_services.jl`](application_services.jl) |
| Implement live-reload workflows for services | [`live_reload.jl`](live_reload.jl) |
| Track progress and publish notifications | [`progress_notifications.jl`](progress_notifications.jl) |
| Build tabbed containers and detail views | [`tabbed_content.jl`](tabbed_content.jl) |
| Manage Toolkit screen stacks and shell overlays | [`screen_stack_quickstart.jl`](screen_stack_quickstart.jl) |
| Map stable widgets in a gallery-style composition | [`widget_gallery.jl`](widget_gallery.jl) |
| Study a larger public-API reference composition | [`reference_application.jl`](reference_application.jl) |
| Define and run reusable keybinding patterns | [`keybindings_quickstart.jl`](keybindings_quickstart.jl) |

For automation scanners that validate family closeout evidence, these are the exact paths that must be present:

- `examples/app_shell_quickstart.jl`
- `examples/immediate_quickstart.jl`
- `examples/layout_quickstart.jl`
- `examples/text_quickstart.jl`
- `examples/scrolling_quickstart.jl`
- `examples/input_events_quickstart.jl`
- `examples/data_display_quickstart.jl`
- `examples/feedback_quickstart.jl`
- `examples/disclosure_overlay_quickstart.jl`
- `examples/screen_stack_quickstart.jl`
- `examples/file_browser_quickstart.jl`
- `examples/controls_quickstart.jl`
- `examples/virtualization_quickstart.jl`
- `examples/animations_loading_quickstart.jl`
- `examples/navigation_quickstart.jl`
- `examples/visualization_quickstart.jl`
- `examples/graphics_quickstart.jl`
- `examples/rich_content_quickstart.jl`
- `examples/toolkit_quickstart.jl`
- `examples/styling_quickstart.jl`
- `examples/testing_quickstart.jl`
- `examples/runtime_quickstart.jl`
- `examples/services_quickstart.jl`
- `examples/extensions_quickstart.jl`
- `examples/remote_transport_quickstart.jl`
- `examples/live_reload.jl`
- `examples/reference_application.jl`
- `examples/widget_gallery.jl`
- `examples/keybindings_quickstart.jl`
- `examples/application_services.jl`
- `examples/progress_notifications.jl`
- `examples/tabbed_content.jl`
