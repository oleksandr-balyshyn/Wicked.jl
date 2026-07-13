# Public Example Families

This guide maps Wicked's public examples to the major feature families needed
for Ratatui, Textual, TamboUI, and Lanterna-style applications.

Every example in this table should use `Wicked.API`, run without taking over the
terminal, render into an in-memory buffer or controlled pilot, and assert the
resulting behavior. `scripts/example_family_audit.jl` checks that each required
family has an example file and an `examples/README.md` entry.

## Family map

| Family | Example | Primary APIs |
|---|---|---|
| Immediate rendering | `examples/immediate_quickstart.jl` | `Buffer`, `Frame`, `Rect`, `render!`, `handle!` |
| Docked application shell | `examples/app_shell_quickstart.jl` | `AppShell`, `app_shell_layout`, `app_shell_summary`, `TitleBar`, `Toolbar`, `Sidebar`, `StatusBar` |
| Layout composition | `examples/layout_quickstart.jl` | `Row`, `Column`, `Wrap`, `Box`, `Padding`, `Center`, `Stack` |
| Text and structure | `examples/text_quickstart.jl` | `Label`, `Paragraph`, `Heading`, `MarkupText`, `Rule`, `Separator`, `Divider` |
| Scrolling and viewport | `examples/scrolling_quickstart.jl` | `ScrollView`, `Viewport`, `Scrollbar`, `ScrollState` |
| Input events | `examples/input_events_quickstart.jl` | `KeyEvent`, `MouseEvent`, `PasteEvent`, `ResizeEvent`, `FocusEvent`, `TickEvent` |
| Data display | `examples/data_display_quickstart.jl` | `Table`, `DataTable`, `DataStateView`, `TreeView`, `TreeTable`, `PropertyList`, `KeyValueList`, `MetadataList`, `DescriptionList`, `DefinitionList` |
| Virtual data | `examples/virtualization_quickstart.jl` | `QueryDataSource`, `VirtualList`, `VirtualTable`, `VirtualTree`, virtual data sources |
| Controls and forms | `examples/controls_quickstart.jl` | Inputs, selects, command palettes, sliders, pickers, forms, validation |
| Feedback and validation | `examples/feedback_quickstart.jl` | `Badge`, `Status`, `Alert`, `Toast`, `NotificationView`, validation feedback |
| Disclosure and overlays | `examples/disclosure_overlay_quickstart.jl` | `Drawer`, `Popover`, `Tooltip`, `Collapsible`, `Accordion`, `Carousel` |
| Screen stack | `examples/screen_stack_quickstart.jl` | `Screen`, `ScreenRegistry`, `ScreenRouteMetadata`, `ScreenHistory`, `ScreenStack`, `PushScreen`, `PushRegisteredScreen`, `NavigateRegisteredScreen`, `BackRegisteredScreen`, `ForwardRegisteredScreen`, `PopScreen`, `PopToScreen`, `ReplaceWithScreen`, `ReplaceWithRegisteredScreen`, `RemoveScreen`, `ClearOverlayScreens`, `screen_route_metadata`, `screen_route_title`, `screen_route_description`, `screen_route_group,screen_route_keywords`, `screen_route_disabled_reason`, `set_screen_route_disabled_reason!`, `clear_screen_route_disabled_reason!`, `set_screen_route_metadata!`, `navigate_registered_screen!`, `back_registered_screen!`, `forward_registered_screen!`, `screen_history_records`, `screen_history_json`, `screen_history_command_items`, `screen_history_command_palette`, `screen_history_menu_items`, `screen_history_menu`, `screen_registry_binding_map`, `screen_registry_binding_layer`, `screen_history_binding_map`, `screen_history_binding_layer`, `screen_stack_element`, `screen_registry_json`, `search_screen_registry_records`, `screen_registry_command_items`, `screen_registry_command_palette`, `screen_registry_menu_items`, `screen_registry_menu`, `screen_registry_navigation_items`, `screen_registry_navigation_rail`, `screen_registry_tab_items`, `screen_registry_tabs`, `selected_screen_registry_tab_message`, `screen_stack_breadcrumb_items`, `screen_stack_breadcrumb`, `screen_stack_markdown`, `push_registered_screen!`, `replace_registered_screen!`, `pop_to_screen!`, `remove_screen!`, `clear_overlay_screens!`, `screen_stack_summary` |
| File browser | `examples/file_browser_quickstart.jl` | `FilePicker`, `DirectoryPicker`, `DirectoryTree`, `MultiFilePicker` |
| Navigation surfaces | `examples/navigation_quickstart.jl` | Breadcrumbs, menus, rails, modals, windows, status bars |
| Visualization | `examples/visualization_quickstart.jl` | Gauges, charts, plots, histograms, heatmaps, calendar, canvas |
| Terminal graphics | `examples/graphics_quickstart.jl` | `RasterImage`, `ImageView`, `BrailleImage`, Unicode fallback |
| Rich content | `examples/rich_content_quickstart.jl` | Markdown, code, syntax, diff, ANSI, logs, terminal views |
| Animations and loading | `examples/animations_loading_quickstart.jl` | `AnimationManager`, `Spinner`, `LoadingIndicator`, `Skeleton` |
| Toolkit | `examples/toolkit_quickstart.jl` | `ToolkitTree`, `Element`, keyed state, focus, semantic queries |
| Styling and themes | `examples/styling_quickstart.jl` | Stylesheets, classes, pseudo-state, theme roles, style engine |
| Testing and semantics | `examples/testing_quickstart.jl` | `WidgetPilot`, `ToolkitPilot`, semantic trees, snapshots |
| Runtime | `examples/runtime_quickstart.jl` | `WickedApp`, runtime pilots, messages, commands, exit |
| Keybindings and shortcut help | `examples/keybindings_quickstart.jl` | `BindingMap`, `BindingLayer`, `BindingStack`, `binding_key_hints`, `ShortcutBar`, `HelpView`, `binding_help_json`, `binding_layer_help_markdown`, `binding_stack_help_tsv` |
| Services | `examples/services_quickstart.jl` | Actions, notifications, progress, themes, tracing, shutdown |
| Extensions | `examples/extensions_quickstart.jl` | Descriptors, dependencies, contributions, scoped cleanup |
| Remote transport | `examples/remote_transport_quickstart.jl` | `RemoteBackend`, `RemoteSession`, encoded remote events |
| Live reload | `examples/live_reload.jl` | Reload targets, reload controller, deterministic refresh |
| Reference application | `examples/reference_application.jl` | Larger app composition through stable public APIs |
| Widget gallery | `examples/widget_gallery.jl` | Broad stable widget surface smoke composition |

## Adding a new public example family

Use this checklist when adding a new required family:

1. Add the example under `examples/`.
2. Import `Wicked.API`, not root or internal modules.
3. Avoid real terminal takeover.
4. Use deterministic clocks, temporary fixtures, or in-memory buffers.
5. Assert at least one behavior with snapshots, pilot state, semantic output, or
   another deterministic public result.
6. Add the file to `examples/README.md`.
7. Add the family to `scripts/example_family_audit.jl`.
8. Link the example from the focused API guide.

The goal is copyable developer guidance, not only test coverage. Examples should
show the API shape a user should write in an application.
