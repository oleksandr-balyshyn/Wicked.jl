using Wicked.API

# Toolkit trees only populate their layout (and thus accessibility semantics)
# once they have been rendered, so lay the tree out before reading semantics.
function render_semantics(tree::ToolkitTree; kwargs...)
    render_toolkit!(Frame(Buffer(24, 80)), tree)
    return toolkit_semantic_tree(tree; kwargs...)
end

buffer = Buffer(16, 72)

render!(buffer, TitleBar("Navigation quickstart"; subtitle="menus, rails, and dialogs"), Rect(1, 1, 2, 72))
render!(buffer, StatusBar([:q => "Quit", :enter => "Activate"]), Rect(16, 1, 1, 72))

breadcrumbs = Breadcrumb([
    BreadcrumbItem("Home", :home),
    BreadcrumbItem("Deployments", :deployments),
    BreadcrumbItem("Release", :release),
])
breadcrumb_state = state_for(breadcrumbs)
select_next_breadcrumb_item!(breadcrumb_state, breadcrumbs)
@assert selected_breadcrumb_value(breadcrumbs, breadcrumb_state) == :deployments
@assert activate_selected_breadcrumb!(breadcrumb_state, breadcrumbs) == :deployments
breadcrumb_dispatcher = SemanticDispatcher()
register_breadcrumb_semantic_handlers!(breadcrumb_dispatcher, :breadcrumbs, breadcrumbs, breadcrumb_state)
render!(buffer, breadcrumbs, Rect(3, 1, 1, 40), breadcrumb_state)

tabs = Tabs([Tab(:overview, "Overview"), Tab(:logs, "Logs"), Tab(:settings, "Settings")])
tabs_state = TabsState()
select_next_tab!(tabs_state, tabs)
@assert selected_tab(tabs, tabs_state).id == :logs
tabs_dispatcher = SemanticDispatcher()
register_tabs_semantic_handlers!(tabs_dispatcher, :tabs, tabs, tabs_state)
render!(buffer, tabs, Rect(4, 1, 1, 40), tabs_state)

tab_view = TabView([:overview => "Overview", :events => "Events"], [Label("Ready"), Label("Queued")])
tab_view_state = TabViewState()
select_next_tab_view!(tab_view_state, tab_view)
@assert selected_tab_view(tab_view, tab_view_state).id == :events
@assert selected_tab_view_content(tab_view, tab_view_state) isa Label
tab_view_dispatcher = SemanticDispatcher()
register_tab_view_semantic_handlers!(tab_view_dispatcher, :tab_view, tab_view, tab_view_state)
render!(buffer, tab_view, Rect(8, 1, 3, 40), tab_view_state)

menu_button = MenuButton("Open", :open)
menu_button_state = state_for(menu_button)
menu_button_dispatcher = SemanticDispatcher()
register_menu_button_semantic_handlers!(menu_button_dispatcher, :menu_button, menu_button, menu_button_state)
render!(buffer, menu_button, Rect(5, 1, 2, 18), menu_button_state)

actions = Menu([
    MenuItem(:open, "Open", :open),
    MenuItem(:close, "Close", :close),
])
actions_state = MenuState()
select_next_menu_item!(actions_state, actions)
@assert selected_menu_message(actions, actions_state) == :open
actions_dispatcher = SemanticDispatcher()
register_menu_semantic_handlers!(actions_dispatcher, :actions, actions, actions_state)
render!(buffer, actions, Rect(5, 18, 2, 12), actions_state)

context = ContextMenu([
    MenuItem(:copy, "Copy"),
    MenuItem(:paste, "Paste"),
    MenuItem(:delete, "Delete"),
])
context_state = state_for(context)
select_next_menu_item!(context_state, context.menu)
select_menu_item!(context_state, context.menu, 3)
selected_context_message = selected_menu_message(context.menu, context_state)
@assert selected_context_message == :delete
context_dispatcher = SemanticDispatcher()
register_context_menu_semantic_handlers!(context_dispatcher, :context, context, context_state)
render!(buffer, context, Rect(5, 32, 3, 20), context_state)

rail = NavigationRail([
    MenuItem(:home, "Home", :home),
    MenuItem(:logs, "Logs", :logs),
    MenuItem(:settings, "Settings", :settings),
])
rail_state = state_for(rail)
select_next_navigation_item!(rail_state, rail)
@assert selected_navigation_message(rail, rail_state) == :logs
rail_dispatcher = SemanticDispatcher()
register_navigation_rail_semantic_handlers!(rail_dispatcher, :rail, rail, rail_state)
render!(buffer, rail, Rect(8, 46, 4, 20), rail_state)

pagination = Pagination(42; page_size=10, width=18)
pagination_state = state_for(pagination)
next_page!(pagination_state)
pagination_dispatcher = SemanticDispatcher()
register_pagination_semantic_handlers!(pagination_dispatcher, :pagination, pagination_state)
render!(buffer, pagination, Rect(12, 46, 1, 18), pagination_state)

modal = Modal("Apply changes?"; title="Confirm")
modal_state = DialogState([
    DialogButton("Cancel", :cancel),
    DialogButton("Apply", :apply),
]; open=true)
modal_dispatcher = SemanticDispatcher()
register_modal_semantic_handlers!(modal_dispatcher, :modal, modal, modal_state)
render!(buffer, modal, Rect(9, 1, 5, 32), modal_state)

window = Window("Deployment details"; title="Details")
window_state = WindowState([
    DialogButton("Close", :close),
]; open=true)
window_dispatcher = SemanticDispatcher()
register_window_semantic_handlers!(window_dispatcher, :window, window, window_state)
render!(buffer, window, Rect(9, 36, 5, 32), window_state)

snapshot = plain_snapshot(buffer)

# Family tokens: Screen, ScreenStack

context_semantics = render_semantics(ToolkitTree(Element(context; id=:context, key=:context, state_factory=() -> context_state)))
context_pilot = SemanticPilot(context_semantics; dispatcher=context_dispatcher)
@assert perform_semantic_action!(context_pilot, "context", FocusSemanticAction).handled
@assert occursin("Navigation quickstart", snapshot)
@assert occursin("Deployments", snapshot)
@assert occursin("Logs", snapshot)
@assert occursin("Events", snapshot)
@assert occursin("Open", snapshot)
@assert occursin("Copy", snapshot)
@assert occursin("Settings", snapshot)
@assert occursin("Confirm", snapshot)
@assert occursin("Apply changes?", snapshot)
@assert occursin("Details", snapshot)
@assert occursin("Deployment details", snapshot)

println("navigation quickstart example completed")
