using Wicked.API

buffer = Buffer(28, 90)

render!(buffer, Heading("Disclosure and overlay quickstart"; level=1), Rect(1, 1, 2, 90))

drawer = Drawer(Label("Navigation drawer"); edge=:left, size=24)
drawer_state = state_for(drawer)
open_drawer!(drawer_state)
drawer_dispatcher = SemanticDispatcher()
register_drawer_semantic_handlers!(drawer_dispatcher, :drawer, drawer_state)
render!(buffer, Label("Drawer"), Rect(4, 1, 1, 28))
render!(buffer, drawer, Rect(5, 1, 5, 38), drawer_state)

popover = Popover(Label("Popover details"), Rect(5, 48, 1, 10); width=24, height=3, preferred=:below)
popover_state = PopoverState(open=true)
popover_dispatcher = SemanticDispatcher()
register_popover_semantic_handlers!(popover_dispatcher, :popover, popover_state; dismissible=popover.dismissible)
render!(buffer, Label("Popover"), Rect(4, 46, 1, 34))
render!(buffer, popover, Rect(5, 46, 6, 34), popover_state)

tooltip = Tooltip("Tooltip help", Rect(12, 1, 1, 8); target=:help, width=24, height=3, delay_ms=0)
tooltip_state = state_for(tooltip)
begin_tooltip_hover!(tooltip_state, :help, tooltip.content; now_ns=UInt64(1))
tooltip_dispatcher = SemanticDispatcher()
register_tooltip_semantic_handlers!(tooltip_dispatcher, :tooltip, tooltip_state; dismissible=tooltip.dismissible)
render!(buffer, Label("Tooltip anchor"), Rect(12, 1, 1, 18))
render!(buffer, tooltip, Rect(11, 1, 5, 38), tooltip_state)

collapsible = Collapsible(
    "Build details",
    Paragraph("Compile, test, package");
    width=38,
    height=4,
    expanded=true,
)
collapsible_state = state_for(collapsible)
collapsible_dispatcher = SemanticDispatcher()
register_collapsible_semantic_handlers!(collapsible_dispatcher, :collapsible, collapsible_state)
render!(buffer, Label("Collapsible"), Rect(17, 1, 1, 38))
render!(buffer, collapsible, Rect(18, 1, 4, 38), collapsible_state)

accordion = Accordion(
    [
        (:logs, "Logs", Paragraph("stdout\nstderr")),
        (:metrics, "Metrics", Label("CPU 12%")),
    ];
    width=38,
    item_height=2,
    multiple=true,
    expanded=[:logs],
)
accordion_state = state_for(accordion)
accordion_dispatcher = SemanticDispatcher()
register_accordion_semantic_handlers!(accordion_dispatcher, :accordion, accordion, accordion_state)
render!(buffer, Label("Accordion"), Rect(17, 46, 1, 38))
render!(buffer, accordion, Rect(18, 46, 6, 38), accordion_state)

carousel = Carousel(["Queued", "Running", "Done"]; index=2, window=2, width=38, height=4)
carousel_state = state_for(carousel)
next_carousel!(carousel_state)
carousel_dispatcher = SemanticDispatcher()
register_carousel_semantic_handlers!(carousel_dispatcher, :carousel, carousel_state)
render!(buffer, Label("Carousel"), Rect(24, 1, 1, 38))
render!(buffer, carousel, Rect(25, 1, 3, 38), carousel_state)

snapshot = plain_snapshot(buffer)
@assert occursin("Disclosure and overlay quickstart", snapshot)
@assert occursin("Drawer", snapshot)
@assert occursin("Navigation drawer", snapshot)
@assert occursin("Popover", snapshot)
@assert occursin("Popover details", snapshot)
@assert occursin("Tooltip help", snapshot)
@assert occursin("Collapsible", snapshot)
@assert occursin("Compile, test, package", snapshot)
@assert occursin("Accordion", snapshot)
@assert occursin("stdout", snapshot)
@assert occursin("Carousel", snapshot)
@assert occursin("Done", snapshot)

println("disclosure and overlay quickstart example completed")
