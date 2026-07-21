using Wicked.API

home = Screen(:home, (app, model) -> Element(Label("Home"); id=:home, key=:home))
details = Screen(:details, model -> Element(Label("Details"); id=:details, key=:details))
help = Screen(:help, () -> Element(Panel(Label("Help")); id=:help, key=:help); mode=OverlayScreen)

screens = ScreenStack()
registry = ScreenRegistry()
register_screen!(registry, home; title="Home", description="Main dashboard", group="Main", keywords=("dashboard", "start"))
register_screen!(
    registry,
    help;
    title="Help",
    description="Overlay help",
    group="Support",
    keywords=("docs", "shortcuts"),
    enabled=false,
    disabled_reason="Requires documentation context",
)
@assert screen_stack_empty(screens)
@assert screen_registry_count(registry) == 2
@assert screen_registry_ids(registry) == Any[:home, :help]
@assert screen_registry_modes(registry) == [ReplaceScreen, OverlayScreen]
@assert registered_screen(registry, :home) === home
@assert has_registered_screen(registry, :help)
@assert screen_route_title(registry, :home) == "Home"
@assert screen_route_description(registry, :help) == "Overlay help"
@assert screen_route_group(registry, :home) == "Main"
@assert "dashboard" in screen_route_keywords(registry, :home)
@assert screen_route_enabled(registry, :home)
@assert !screen_route_enabled(registry, :help)
@assert screen_route_disabled_reason(registry, :help) == "Requires documentation context"
enable_screen_route!(registry, :help)
@assert screen_route_enabled(registry, :help)
@assert isempty(screen_route_disabled_reason(registry, :help))
disable_screen_route!(registry, :help; reason="Documentation panel is not mounted")
@assert !screen_route_enabled(registry, :help)
@assert screen_route_disabled_reason(registry, :help) == "Documentation panel is not mounted"
set_screen_route_disabled_reason!(registry, :help, "Waiting for docs")
@assert screen_route_disabled_reason(registry, :help) == "Waiting for docs"
set_screen_route_enabled!(registry, :help, true)
@assert isempty(screen_route_disabled_reason(registry, :help))
set_screen_route_metadata!(registry, :home; group="Primary", keywords=("dashboard", "landing"))
@assert screen_route_group(registry, :home) == "Primary"
@assert "landing" in screen_route_keywords(registry, :home)
@assert screen_registry_records(registry)[2].id == :help
@assert screen_registry_summary(registry).overlay_count == 1
@assert screen_registry_groups(registry) == ["Primary", "Support"]
@assert first(screen_registry_group_records(registry)).group == "Primary"
@assert screen_registry_group_summary(registry).route_count == 2
@assert occursin("\"group\": \"Primary\"", screen_registry_group_json(registry))
@assert startswith(screen_registry_group_markdown(registry), "| `index` | `group` | `count` | `enabled_count` | `disabled_count` | `route_ids` |")
@assert occursin("group=Primary", screen_registry_group_text(registry))
@assert startswith(screen_registry_group_summary_text(registry), "groups=2 routes=2")
@assert startswith(screen_registry_group_tsv(registry), "index\tgroup\tcount\tenabled_count\tdisabled_count\troute_ids")
@assert occursin("\"title\": \"Home\"", screen_registry_json(registry))
@assert occursin("id=home", screen_registry_text(registry))
@assert startswith(screen_registry_summary_text(registry), "screens=2")
@assert startswith(screen_registry_markdown(registry), "| `index` | `id` | `title` | `description` | `group` | `mode` | `enabled` | `disabled_reason` | `keywords` |")
@assert startswith(screen_registry_tsv(registry), "index\tid\ttitle\tdescription\tgroup\tmode\tenabled\tdisabled_reason\tkeywords")
@assert only(screen_registry_filter_records(registry; mode=OverlayScreen)).id == :help
@assert only(screen_registry_filter_records(registry; group="Primary")).id == :home
@assert screen_registry_filter_count(registry; enabled=true) == 2
@assert screen_registry_filter_count(registry; group="Support") == 1
@assert screen_registry_filter_count(registry; mode=ReplaceScreen) == 1
@assert only(search_screen_registry_records(registry, "landing")).id == :home
@assert only(search_screen_registry_records(registry, "Primary")).id == :home
@assert search_screen_registry_count(registry, "Overlay") == 1
@assert occursin("\"id\": \"help\"", search_screen_registry_json(registry, "help"))
@assert startswith(search_screen_registry_markdown(registry, "home"), "| `index` | `id` | `title` | `description` | `group` | `mode` | `enabled` | `disabled_reason` | `keywords` |")
@assert startswith(search_screen_registry_tsv(registry, "Overlay"), "index\tid\ttitle\tdescription\tgroup\tmode\tenabled\tdisabled_reason\tkeywords")
@assert first(screen_registry_command_items(registry)).action isa PushRegisteredScreen
@assert first(screen_registry_command_items(registry; replace=true)).action isa ReplaceWithRegisteredScreen
@assert screen_registry_command_palette(registry) isa CommandPalette
@assert screen_registry_command_palette_session(registry; query="home").state.open
@assert only(search_screen_registry_command_items(registry, "help")).id == :help
@assert search_screen_registry_command_palette(registry, "home") isa CommandPalette
@assert search_screen_registry_command_palette_session(registry, "help"; palette_query="help").palette isa CommandPalette
@assert first(screen_registry_menu_items(registry)).message isa PushRegisteredScreen
@assert first(screen_registry_menu_items(registry; replace=true)).message isa ReplaceWithRegisteredScreen
@assert screen_registry_menu(registry) isa Menu
@assert screen_registry_menu_session(registry).state isa MenuState
@assert only(search_screen_registry_menu_items(registry, "help")).id == :help
@assert search_screen_registry_menu(registry, "help") isa Menu
@assert search_screen_registry_menu_session(registry, "home").menu isa Menu
@assert first(screen_registry_navigation_items(registry)).message isa PushRegisteredScreen
@assert first(screen_registry_navigation_items(registry; replace=true)).message isa ReplaceWithRegisteredScreen
@assert screen_registry_navigation_rail(registry) isa NavigationRail
@assert screen_registry_navigation_rail_session(registry).state isa NavigationRailState
@assert only(search_screen_registry_navigation_items(registry, "help")).id == :help
@assert search_screen_registry_navigation_rail(registry, "help") isa NavigationRail
@assert search_screen_registry_navigation_rail_session(registry, "home").rail isa NavigationRail
route_tabs = screen_registry_tabs(registry)
route_tabs_state = TabsState()
@assert first(screen_registry_tab_items(registry)).id == :home
@assert route_tabs isa Tabs
@assert screen_registry_tabs_session(registry).state isa TabsState
@assert only(search_screen_registry_tab_items(registry, "help")).id == :help
@assert search_screen_registry_tabs(registry, "help") isa Tabs
@assert search_screen_registry_tabs_session(registry, "home").tabs isa Tabs
@assert selected_screen_registry_tab_message(registry, route_tabs, route_tabs_state) isa PushRegisteredScreen
@assert selected_screen_registry_tab_message(registry, route_tabs, route_tabs_state; replace=true) isa ReplaceWithRegisteredScreen
register_screen!(registry, details; title="Details", description="Details screen", keywords=("detail", "record"))
history = ScreenHistory()
@assert screen_history_empty(history)
push_screen_history!(history, :home)
replace_screen_history!(history, :home)
push_screen_history!(history, :details)
@assert current_screen_history_id(history) == :details
@assert can_go_back(history)
@assert !can_go_forward(history)
@assert screen_history_count(history) == 2
@assert screen_history_records(history)[2].current
@assert screen_history_summary(history).current_id == :details
@assert occursin("\"id\": \"details\"", screen_history_json(history))
@assert startswith(screen_history_markdown(history), "| `index` | `id` | `current` |")
@assert startswith(screen_history_tsv(history), "index\tid\tcurrent")
@assert screen_history_command_items(history, registry)[1].action isa BackRegisteredScreen
@assert screen_history_command_palette(history, registry) isa CommandPalette
@assert screen_history_command_palette_session(history, registry; query="back").state.open
@assert screen_history_menu_items(history, registry)[2].message isa ForwardRegisteredScreen
@assert screen_history_menu(history, registry) isa Menu
@assert screen_history_menu_session(history, registry).state isa MenuState
route_bindings = screen_registry_binding_map(registry, [:home => :h, :details => :d])
history_bindings = screen_history_binding_map(history, registry; include_unavailable=true)
@assert resolve_binding(route_bindings, KeyEvent(Key(:h))) isa NavigateRegisteredScreen
@assert screen_registry_binding_layer(registry, [:home => :h]) isa BindingLayer
@assert resolve_binding(history_bindings, KeyEvent(Key(:left); modifiers=ALT)) isa BackRegisteredScreen
@assert screen_history_binding_layer(history, registry; include_unavailable=true) isa BindingLayer
@assert back_screen_history!(history) == :home
@assert forward_screen_history!(history) == :details
@assert NavigateRegisteredScreen(registry, :home).id == :home
@assert BackRegisteredScreen(registry).registry === registry
@assert ForwardRegisteredScreen(registry).registry === registry
clear_screen_history!(history)
navigate_registered_screen!(screens, history, registry, :home)
navigate_registered_screen!(screens, history, registry, :details)
@assert screen_stack_ids(screens) == Any[:details]
@assert back_registered_screen!(screens, history, registry).id == :home
@assert screen_stack_ids(screens) == Any[:home]
@assert forward_registered_screen!(screens, history, registry).id == :details
@assert screen_stack_ids(screens) == Any[:details]
clear_screens!(screens)

push_registered_screen!(screens, registry, :home)
@assert current_screen(screens).id == :home
@assert screen_stack_ids(screens) == Any[:home]

push_registered_screen!(screens, registry, :help)
@assert current_screen(screens).id == :help
@assert has_screen(screens, :home)
@assert screen_stack_count(screens) == 2
@assert screen_stack_modes(screens) == [ReplaceScreen, OverlayScreen]

records = screen_stack_records(screens)
@assert records[1].id == :home
@assert records[2].current
@assert occursin("\"current\": \"true\"", screen_stack_json(screens))
@assert startswith(screen_stack_markdown(screens), "| `index` | `id` | `mode` | `current` |")
@assert startswith(screen_stack_tsv(screens), "index\tid\tmode\tcurrent")

summary = screen_stack_summary(screens)
@assert summary.current_id == :help
@assert summary.overlay_count == 1
@assert screen_stack_breadcrumb_items(screens; registry=registry)[1].label == "Home"
@assert screen_stack_breadcrumb(screens; registry=registry) isa Breadcrumb
@assert screen_stack_breadcrumb_session(screens; registry=registry).state isa BreadcrumbState
composed = screen_stack_element(Element(Label("Base"); id=:base, key=:base), screens, nothing, nothing)
@assert composed isa Element

@assert PopScreen() isa PopScreen
@assert PopToScreen(:home).id == :home
@assert PushScreen(details).screen === details
@assert PushRegisteredScreen(registry, :home).id == :home
@assert ReplaceWithScreen(home).screen === home
@assert ReplaceWithRegisteredScreen(registry, :help).id == :help
@assert RemoveScreen(:help).id == :help
@assert ClearOverlayScreens() isa ClearOverlayScreens
@assert ClearScreens() isa ClearScreens

@assert only(pop_to_screen!(screens, :home)).id == :help
push_screen!(screens, help)
@assert only(clear_overlay_screens!(screens)).id == :help
push_screen!(screens, help)
@assert remove_screen!(screens, :help).id == :help
push_screen!(screens, help)
pop_screen!(screens)
@assert registered_screen(registry, :details) === details
replace_registered_screen!(screens, registry, :details)
@assert screen_stack_ids(screens) == Any[:details]
@assert screen_stack_summary(screens).replace_count == 1
@assert only(clear_screens!(screens)).id == :details
@assert screen_stack_empty(screens)
@assert unregister_screen!(registry, :details) === details

println("screen stack quickstart example completed")
