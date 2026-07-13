# Navigation and Forms API

Navigation controls, forms, drag-and-drop, and the file browser/file picker APIs
are available through the stable `Wicked.API` facade.

This page contains generated reference documentation for navigation controls,
forms, drag-and-drop behavior, and file browsing.

## Carousel helpers

`CarouselState` stores the item list, current index, and looping policy. The
stable helpers mutate state explicitly and never hide timers or global state:

```julia
state = CarouselState(["Overview", "Logs", "Metrics"]; index=1)

next_carousel!(state)
current = carousel_item(state)
visible = carousel_window(state, 2)
set_carousel_index!(state, 1)
```

Use these helpers from keyboard handlers, pointer handlers, or Toolkit callbacks
when building tab strips, onboarding flows, dashboards, and paged cards.
Use `register_carousel_semantic_handlers!` when tests or automation should
drive carousel focus, next/previous navigation, or direct item selection through
semantic actions.

Use `Carousel` when the same state should be rendered as a direct widget:

```julia
widget = Carousel(["Overview", "Logs", "Metrics"]; window=1)
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `Collapsible`, `Accordion`, `Drawer`, `Popover`, and `Tooltip` for
disclosure, hover-help, and overlay navigation patterns. Their state contracts
are `CollapsibleState`, `AccordionState`, `DrawerState`, `PopoverState`, and
`TooltipState`, which keeps open/closed or hover-visible state explicit and
application-owned:

```julia
drawer = Drawer(Label("Menu"); edge=:left)
popover = Popover(Label("Details"))
tooltip = Tooltip("Runs the current task", Rect(1, 1, 1, 8); delay_ms=400)
```

Use `register_drawer_semantic_handlers!`, `register_popover_semantic_handlers!`,
and `register_tooltip_semantic_handlers!` when overlay tests should toggle,
expand, collapse, focus, or dismiss these surfaces through semantic actions.

For a runnable public-API example, see
[`examples/disclosure_overlay_quickstart.jl`](examples/disclosure_overlay_quickstart.jl).

## Screen stack helpers

Use `Screen`, `ScreenStack`, `PushScreen`, `PushRegisteredScreen`,
`NavigateRegisteredScreen`, `BackRegisteredScreen`, `ForwardRegisteredScreen`,
`PopScreen`, `PopToScreen`, `ReplaceWithScreen`,
`ReplaceWithRegisteredScreen`, `RemoveScreen`, `ClearOverlayScreens`, and
`ClearScreens` when a Toolkit application needs Textual-style screens, modal
overlays, or browser-style route history with stable identities. `ReplaceScreen`
makes a screen replace the previous root, while `OverlayScreen` stacks a screen
above the current root. A `ToolkitApp` update handler can return these message
values directly to change the mounted screen stack.

Use `ScreenRegistry` when screens should be defined once and navigated by ID.
`register_screen!`, `unregister_screen!`, `registered_screen`,
`has_registered_screen`, `screen_registry_ids`, `screen_registry_records`, and
`screen_registry_summary` expose the registered route set, while
`push_registered_screen!` and `replace_registered_screen!` move registered
screens into a `ScreenStack` without passing concrete `Screen` objects through
application code. Return `PushRegisteredScreen(registry, id)` or
`ReplaceWithRegisteredScreen(registry, id)` from `toolkit_update!` when the
managed Toolkit runtime should perform that route navigation. Use
`ScreenHistory`, `navigate_registered_screen!`, `back_registered_screen!`,
`forward_registered_screen!`, `push_screen_history!`,
`replace_screen_history!`, `back_screen_history!`,
`forward_screen_history!`, `clear_screen_history!`,
`current_screen_history_id`, `can_go_back`, `can_go_forward`,
`screen_history_records`, `screen_history_summary`, `screen_history_json`,
`screen_history_markdown`, and `screen_history_tsv` when route navigation should
support explicit back/forward history and reviewable history artifacts. Use
`screen_history_command_items`, `screen_history_command_palette`,
`screen_history_command_palette_session`, `screen_history_menu_items`,
`screen_history_menu`, and `screen_history_menu_session` to expose Back and
Forward actions in route command surfaces with automatic disabled states. Use
`screen_registry_binding_map`, `screen_registry_binding_layer`,
`screen_history_binding_map`, and `screen_history_binding_layer` when registered
routes and route history should feed the stable keybinding, shortcut bar, and
help-view APIs.
Pass `title`, `description`, `group`, and `keywords` to `register_screen!` when
route switchers should show user-facing labels and sections rather than raw IDs.
Use `screen_route_metadata`, `screen_route_title`,
`screen_route_description`, `screen_route_group`, `screen_route_keywords`,
`screen_registry_groups`, and `set_screen_route_metadata!` to inspect or update
that route metadata after registration without changing the underlying `Screen`.
Use `screen_route_enabled`, `screen_route_disabled_reason`,
`set_screen_route_disabled_reason!`, `clear_screen_route_disabled_reason!`,
`set_screen_route_enabled!`, `enable_screen_route!`, and
`disable_screen_route!` when route switchers should show disabled routes,
explain why they are unavailable, and prevent navigation through unavailable
screens.
Use `screen_registry_json`, `screen_registry_markdown`, and
`screen_registry_tsv`, and `screen_registry_text` when route registrations
should become machine-readable, reviewable, or log-friendly artifacts. Use
`screen_registry_summary_text` when logs need one compact route registry status
line. Use `screen_registry_group_records`,
`screen_registry_group_summary`, `screen_registry_group_json`,
`screen_registry_group_markdown`, `screen_registry_group_tsv`,
`screen_registry_group_text`, and `screen_registry_group_summary_text` when app
shells, debug panels, logs, or release evidence need section-level route
diagnostics.
Use `screen_registry_filter_records`,
`screen_registry_filter_count`, `search_screen_registry_records`,
`search_screen_registry_count`, `search_screen_registry_json`,
`search_screen_registry_markdown`, and `search_screen_registry_tsv` when route
pickers, debug panels, or command palettes need to narrow the registered route
set by ID text, title, description, group, mode, enabled state, disabled reason,
or keyword.
Use `screen_registry_command_items`, `search_screen_registry_command_items`,
`screen_registry_menu_items`, and `search_screen_registry_menu_items` when
registered screens should feed a command palette, menu, navigation rail, or
route switcher. Use
`screen_registry_command_palette`, `screen_registry_command_palette_session`,
`search_screen_registry_command_palette`,
`search_screen_registry_command_palette_session`, `screen_registry_menu`,
`screen_registry_menu_session`, `search_screen_registry_menu`, and
`search_screen_registry_menu_session` when route switchers should be constructed
as complete widgets and matching state. Use `screen_registry_navigation_items`,
`screen_registry_navigation_rail`, `screen_registry_navigation_rail_session`,
`search_screen_registry_navigation_items`,
`search_screen_registry_navigation_rail`, and
`search_screen_registry_navigation_rail_session` for side-navigation surfaces
that present registered routes through the stable `NavigationRail` widget. Use
`screen_registry_tab_items`, `screen_registry_tabs`,
`screen_registry_tabs_session`, `search_screen_registry_tab_items`,
`search_screen_registry_tabs`, `search_screen_registry_tabs_session`, and
`selected_screen_registry_tab_message` when registered routes should become a
tab strip with explicit selected-tab state and route navigation messages.

The stack is explicit, inspectable, and independently composable. Use
`screen_stack_element` to compose a base `Element` with replace screens and
overlays when an application needs the same screen behavior outside a full
`ToolkitApp`. Use `pop_to_screen!`, `remove_screen!`, `clear_overlay_screens!`,
and `clear_screens!` for route-style navigation mutations beyond basic
push/pop/replace. Use `current_screen`,
`screen_stack_count`, `screen_stack_empty`, `screen_stack_ids`,
`screen_stack_modes`, `screen_stack_records`, `screen_stack_summary`, and
`has_screen` in tests, diagnostics, and application logic instead of reaching
into internal fields. Use `screen_stack_json`, `screen_stack_markdown`, and
`screen_stack_tsv` when the active stack should be emitted to logs, debug
panels, CI artifacts, or documentation. Use `screen_stack_breadcrumb_items`,
`screen_stack_breadcrumb`, and `screen_stack_breadcrumb_session` when the active
screen stack should become a breadcrumb trail with registry-backed labels:

```julia
using Wicked.API

home = Screen(:home, (app, model) -> Element(Label("Home"); id=:home, key=:home))
help = Screen(:help, (app, model) -> Element(Label("Help"); id=:help, key=:help); mode=OverlayScreen)

screens = ScreenStack()
registry = ScreenRegistry()
register_screen!(registry, home; title="Home", description="Main dashboard", keywords=("dashboard", "start"))
register_screen!(registry, help; title="Help", description="Overlay help", keywords=("docs", "shortcuts"))
push_registered_screen!(screens, registry, :home)
push_registered_screen!(screens, registry, :help)

root = screen_stack_element(Element(Label("Base"); id=:base, key=:base), screens)
popped = pop_to_screen!(screens, :home)
message = PopToScreen(:home)
route_message = PushRegisteredScreen(registry, :help)
history = ScreenHistory()
navigate_registered_screen!(screens, history, registry, :home)
back_message = BackRegisteredScreen(registry)
forward_message = ForwardRegisteredScreen(registry)
history_artifact = screen_history_json(history)
history_commands = screen_history_command_palette(history, registry)
route_bindings = screen_registry_binding_map(registry, [:home => :h, :help => :question])
history_bindings = screen_history_binding_layer(history, registry)
routes = screen_registry_markdown(registry)
matches = search_screen_registry_records(registry, "shortcuts")
commands = screen_registry_command_items(registry)
palette = screen_registry_command_palette(registry)
menu = screen_registry_menu(registry)
rail = screen_registry_navigation_rail(registry)
tabs = screen_registry_tabs(registry)
tab_state = TabsState()
tab_message = selected_screen_registry_tab_message(registry, tabs, tab_state)
breadcrumb = screen_stack_breadcrumb(screens; registry=registry)
stack_artifact = screen_stack_json(screens)
summary = screen_stack_summary(screens)
```

For a runnable public-API example, see
[`examples/screen_stack_quickstart.jl`](examples/screen_stack_quickstart.jl).

## Timeline helpers

`TimelineState` and `TimelineItem` model ordered progress with explicit focus.
`move_timeline_focus!` updates focus without rendering, while `render_timeline`
and `timeline_semantic_tree` expose visual and accessibility views from the same
state:

```julia
timeline = TimelineState([
    TimelineItem("Queued", :queued),
    TimelineItem("Running", :running; detail="worker", status=TimelineActive),
])

move_timeline_focus!(timeline, 1)
lines = render_timeline(timeline; width=40)
semantics = timeline_semantic_tree(timeline; id="build")
```

Use the helpers for job monitors, setup wizards, deployment flows, and other
ordered status displays.
Use `register_timeline_semantic_handlers!` when tests or automation should move
focus, jump to a timeline item, or activate an item through semantic actions.

Use `Timeline` when that ordered status model should render as a direct widget.
The direct widget uses `TimelineWidgetState`; the lower-level `TimelineState`
remains available when you only need model helpers or semantic extraction.

Use `Tabs` and `TabView` for tab navigation ports. `TabsState` tracks the active
tab for standalone tab strips, while `TabViewState` owns the selected tab and
content viewport for a combined tabbed view:

```julia
tabs = Tabs([Tab(:logs, "Logs")])
tabs_state = TabsState()
select_next_tab!(tabs_state, tabs)
active = selected_tab(tabs, tabs_state)
tab_view = TabView([:logs => "Logs", :status => "Status"], [Label("ready"), Label("green")])
tab_view_state = TabViewState()
select_next_tab_view!(tab_view_state, tab_view)
active_view = selected_tab_view(tab_view, tab_view_state)
```

Use `select_tab!`, `select_next_tab!`, `select_previous_tab!`, and
`selected_tab` when tests or key handlers need to drive standalone `Tabs`
without mutating `TabsState.selected` directly.
Use `select_tab_view!`, `select_next_tab_view!`,
`select_previous_tab_view!`, `selected_tab_view`, and
`selected_tab_view_content` for combined tab/content views.
Use `register_tab_view_semantic_handlers!` when automation should focus or
select tabs in a combined tab/content view through semantic actions.
Use `register_tabs_semantic_handlers!` when automation should focus or select
standalone tabs through semantic actions.
Use `register_tabbed_content_view_semantic_handlers!` when a retained
`TabbedContentView` should expose focus movement, activation, selection, and
closable-tab dismissal through semantic actions.

Use `Breadcrumb` for path, hierarchy, and wizard-step navigation. The widget
uses `BreadcrumbState`, while stable helpers expose direct state transitions:

```julia
breadcrumbs = Breadcrumb([
    BreadcrumbItem("Home", :home),
    BreadcrumbItem("Deployments", :deployments),
])
breadcrumb_state = state_for(breadcrumbs)
select_next_breadcrumb_item!(breadcrumb_state, breadcrumbs)
active = activate_selected_breadcrumb!(breadcrumb_state, breadcrumbs)
```

Use `select_breadcrumb_item!`, `select_next_breadcrumb_item!`,
`select_previous_breadcrumb_item!`, `selected_breadcrumb_item`,
`selected_breadcrumb_value`, and `activate_selected_breadcrumb!` when key
handlers, tests, or automation need to drive breadcrumbs without mutating
`BreadcrumbState.focused` or `BreadcrumbState.active` directly.
Use `register_breadcrumb_semantic_handlers!` when `SemanticPilot` should focus,
select, or activate breadcrumb items through semantic actions.

Use `Menu`, `ContextMenu`, `MenuBar`, `MenuButton`, and `NavigationRail` for
menu and navigation-shell ports. `MenuState`, `ContextMenuState`,
`MenuButtonState`, and `NavigationRailState` preserve selection and activation
state explicitly, while `MenuBar` renders stateless menu chrome:

```julia
items = Menu([MenuItem(:open, "Open", :open)])
state = MenuState()
select_next_menu_item!(state, items)
message = selected_menu_message(items, state)
menu = ContextMenu(["Open", "Close"])
rail = NavigationRail(["Home", "Logs", "Settings"])
```

Use `select_menu_item!`, `select_next_menu_item!`,
`select_previous_menu_item!`, `selected_menu_item`, and
`selected_menu_message` when keyboard handlers, tests, or automation need to
drive menu state directly without reaching into `MenuState` fields.
Use `select_navigation_item!`, `select_next_navigation_item!`,
`select_previous_navigation_item!`, `selected_navigation_item`, and
`selected_navigation_message` for rail-specific navigation state helpers.
Use `register_menu_semantic_handlers!` when a `SemanticPilot` or automation
layer should focus, select, or activate menu items through semantic actions.
Use `register_context_menu_semantic_handlers!` for the same semantic action
contract on `ContextMenu` without reaching through its internal menu adapter.
Use `register_menu_button_semantic_handlers!` when an individual menu launch
button should be focusable and activatable through the same semantic path as
ordinary buttons.
Use `register_navigation_rail_semantic_handlers!` for the same behavior on
`NavigationRail` without reaching through its internal menu adapter.

Use `Pagination` for page navigation in tables, result lists, and long forms.
`PaginationState` owns page count and current page, while `set_page!`,
`next_page!`, and `previous_page!` are the stable mutation API.
Use `register_pagination_semantic_handlers!` when tests or automation should
drive page changes through semantic increment, decrement, or set-value actions.

## Dialog and modal surfaces

Use `Dialog` for explicit dialog rendering, `Modal` when application code should
name the blocking overlay pattern directly, and `Window` when porting
retained-mode or JVM-style TUI code that names top-level surfaces explicitly.
All three share `DialogState`/`WindowState`, keyboard navigation, pointer
activation, and semantic dialog children:

```julia
modal = Modal("Apply changes?"; title="Confirm")
window = Window("Apply changes?"; title="Confirm")
state = DialogState([DialogButton("Cancel", :cancel), DialogButton("Apply", :apply)]; open=true)

render!(buffer, modal, area, state)
```

Use `register_dialog_semantic_handlers!`, `register_modal_semantic_handlers!`,
or `register_window_semantic_handlers!` when automation should focus buttons,
select buttons, activate a dialog result, or dismiss the dialog through semantic
actions. All three handlers share the same `DialogState` behavior.

## Empty-state semantics

`navigation_control_semantic_node` covers navigation controls that need explicit
accessibility metadata, including split panes, drawers, and empty states. Pair it
with `render_empty_state` when a component exposes both visual rich lines and an
automation tree.

## File-system pickers

Use `FilePicker` for single-file workflows, `DirectoryPicker` when selection
should resolve to directories, `DirectoryTree` when porting Textual-style
directory navigation, and `MultiFilePicker` when users need to select more than
one entry. These widgets share `FileBrowserState` filtering, sorting, keyboard
bindings, and pointer behavior:

```julia
files = FilePicker(pwd(); width=48, height=12)
directories = DirectoryPicker(pwd(); width=48, height=12)
directory_tree = DirectoryTree(pwd(); width=48, height=12)
many = MultiFilePicker(pwd(); width=48, height=12)

state = state_for(many)
render!(buffer, many, area, state)
```

For a runnable public-API example with a temporary filesystem fixture, see
[`examples/file_browser_quickstart.jl`](examples/file_browser_quickstart.jl).

`DirectoryTreeState` is intentionally identical to `FileBrowserState`. The tree
name changes the developer-facing concept and semantic label, not the underlying
filesystem navigation state model. Prefer `DirectoryPicker` when the interaction
is choosing a directory value; prefer `DirectoryTree` when the interaction is
browsing or navigating a filesystem hierarchy.

```@autodocs
Modules = [
    Wicked.NavigationControls,
    Wicked.Forms,
    Wicked.DragDrop,
    Wicked.FileBrowser,
    Wicked.FileBrowserInput,
]
Private = false
```
