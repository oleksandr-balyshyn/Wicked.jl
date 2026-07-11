import Wicked
using Wicked.API

pages = ContentPage{Symbol}[
    ContentPage(:overview, "Overview", "Overview content"),
    lazy_content_page(
        :metrics,
        "Metrics",
        () -> "Metrics content";
        closable=true,
    ),
]

tabs = TabbedContent(
    pages;
    active=:overview,
    activation=ManualTabActivation,
    placement=TabsAbove,
)

@assert selected_tab(tabs) == :overview
@assert focused_tab(tabs) == :overview

move_tab_focus!(tabs, 1)
@assert focused_tab(tabs) == :metrics
@assert selected_tab(tabs) == :overview

activate_focused_tab!(tabs)
snapshot = tabbed_content_snapshot!(tabs)

@assert snapshot.active_key == :metrics
@assert snapshot.content == "Metrics content"
@assert snapshot.content_version !== nothing

strip = render_tab_strip_control(snapshot; width=40)
semantics = tabbed_content_semantic_tree(snapshot; id="example-tabs")

@assert strip isa Wicked.RichContent.RichLine
@assert semantics.root.id == "example-tabs"
@assert length(semantics.root.children) == 2

set_tab_placement!(tabs, TabsLeft)
state = tabbed_content_state_snapshot(tabs)
@assert state.placement == TabsLeft

@assert close_tab!(tabs, :metrics)
@assert selected_tab(tabs) == :overview

println("tabbed content example completed")
