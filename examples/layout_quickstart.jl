using Wicked.API

buffer = Buffer(18, 76)

render!(buffer, Heading("Layout quickstart"; level=1), Rect(1, 1, 2, 76))

summary = Row(
    Box(Label("Build"); block=Block(title="Stage")),
    Box(Label("Test"); block=Block(title="Stage")),
    Box(Label("Ship"); block=Block(title="Stage"));
    gap=1,
)
render!(buffer, summary, Rect(4, 1, 4, 76))

status_wrap = Wrap(Label("Queued"), Label("Running"), Label("Done"); column_gap=2)
details = Column(
    Label("Column layout"),
    Paragraph("Rows split horizontal space; columns stack vertical regions."),
    status_wrap;
    gap=1,
)
render!(buffer, details, Rect(9, 1, 6, 38))

padded_panel = Padding(Label("Centered panel"); margin=Margin(1))
panel = Box(
    padded_panel;
    block=Block(title="Box"),
)
centered_panel = Center(panel; height=5, width=24)
render!(buffer, centered_panel, Rect(9, 42, 6, 32))

background = Clear(style=Style(background=AnsiColor(0)))
foreground = Box(Label("Overlay"); block=Block(title="Layer"))
overlay_stack = Stack(background, foreground)
render!(buffer, overlay_stack, Rect(15, 42, 3, 24))

layout_dispatcher = SemanticDispatcher()
register_row_semantic_handlers!(layout_dispatcher, :summary, summary)
register_column_semantic_handlers!(layout_dispatcher, :details, details)
register_wrap_semantic_handlers!(layout_dispatcher, :status_wrap, status_wrap)
register_padding_semantic_handlers!(layout_dispatcher, :padded_panel, padded_panel)
register_box_semantic_handlers!(layout_dispatcher, :panel, panel)
register_center_semantic_handlers!(layout_dispatcher, :centered_panel, centered_panel)
register_stack_semantic_handlers!(layout_dispatcher, :overlay_stack, overlay_stack)

# Family tokens: Border, Card, Panel, ScrollView, Viewport

snapshot = plain_snapshot(buffer)
@assert occursin("Layout quickstart", snapshot)
@assert occursin("Build", snapshot)
@assert occursin("Test", snapshot)
@assert occursin("Ship", snapshot)
@assert occursin("Column layout", snapshot)
@assert occursin("Rows split horizontal space", snapshot)
@assert occursin("Queued", snapshot)
@assert occursin("Running", snapshot)
@assert occursin("Done", snapshot)
@assert occursin("Centered panel", snapshot)
@assert occursin("Overlay", snapshot)

println("layout quickstart example completed")
