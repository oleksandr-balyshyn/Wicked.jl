using Wicked.API

# Toolkit trees only populate their layout (and thus accessibility semantics)
# once they have been rendered, so lay the tree out before reading semantics.
function render_semantics(tree::ToolkitTree; kwargs...)
    render_toolkit!(Frame(Buffer(24, 80)), tree)
    return toolkit_semantic_tree(tree; kwargs...)
end

buffer = Buffer(18, 72)

render!(buffer, Heading("Scrolling quickstart"; level=1), Rect(1, 1, 2, 72))

content = Paragraph(
    "line 1: queued\nline 2: building\nline 3: testing\nline 4: packaging\nline 5: shipped";
    wrap=NoWrap,
)

scroll = ScrollView(content; height=5, width=28)
scroll_state = ScrollState(row=1, column=0)
scroll_dispatcher = SemanticDispatcher()
register_scroll_view_semantic_handlers!(
    scroll_dispatcher,
    :scroll,
    scroll,
    scroll_state;
    viewport_height=3,
)
scroll_block = Block(title="ScrollView")
scroll_area = Rect(4, 1, 5, 32)
render!(buffer, scroll_block, scroll_area)
render!(buffer, scroll, inner(scroll_block, scroll_area), scroll_state)

vertical = Scrollbar(VerticalScrollbar, 5, 3)
register_scrollbar_semantic_handlers!(scroll_dispatcher, :scrollbar, vertical, scroll_state)
render!(buffer, vertical, Rect(5, 34, 3, 1), scroll_state)

viewport = Viewport(content; height=5, width=28)
viewport_state = state_for(viewport)
viewport_dispatcher = SemanticDispatcher()
register_viewport_semantic_handlers!(
    viewport_dispatcher,
    :viewport,
    viewport,
    viewport_state;
    viewport_height=3,
)
handle!(viewport_state, viewport, KeyEvent(Key(:down)))
viewport_block = Block(title="Viewport")
viewport_area = Rect(10, 1, 5, 32)
render!(buffer, viewport_block, viewport_area)
render!(buffer, viewport, inner(viewport_block, viewport_area), viewport_state)

wheel_state = ScrollState()
handle!(
    wheel_state,
    scroll,
    MouseEvent(Position(10, 42), WheelDownButton, MouseScroll),
    Rect(10, 40, 4, 28),
)
wheel_block = Block(title="Mouse wheel")
wheel_area = Rect(10, 40, 5, 30)
render!(buffer, wheel_block, wheel_area)
render!(buffer, scroll, inner(wheel_block, wheel_area), wheel_state)

scroll_tree = ToolkitTree(Element(scroll; id=:scroll, key=:scroll, state_factory=() -> scroll_state))
scroll_pilot = SemanticPilot(render_semantics(scroll_tree); dispatcher=scroll_dispatcher)
@assert perform_semantic_action!(scroll_pilot, "scroll", IncrementSemanticAction).handled

viewport_tree = ToolkitTree(Element(viewport; id=:viewport, key=:viewport, state_factory=() -> viewport_state))
viewport_pilot = SemanticPilot(render_semantics(viewport_tree); dispatcher=viewport_dispatcher)
@assert perform_semantic_action!(viewport_pilot, "viewport", ScrollIntoViewSemanticAction; value=2).handled

snapshot = plain_snapshot(buffer)
@assert occursin("Scrolling quickstart", snapshot)
@assert occursin("ScrollView", snapshot)
@assert occursin("Viewport", snapshot)
@assert occursin("Mouse wheel", snapshot)
@assert occursin("line 2: building", snapshot)
@assert occursin("line 3: testing", snapshot)
@assert occursin("line 4: packaging", snapshot)

println("scrolling quickstart example completed")
