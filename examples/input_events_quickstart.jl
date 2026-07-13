using Wicked.API

buffer = Buffer(18, 76)

render!(buffer, Heading("Input events quickstart"; level=1), Rect(1, 1, 2, 76))

button = Button("Run")
button_state = state_for(button)
key_event = KeyEvent(Key(:enter))
button_handled = handle!(button_state, button, key_event)
render!(buffer, Label("KeyEvent -> Button"), Rect(4, 1, 1, 34))
render!(buffer, button, Rect(5, 1, 3, 18), button_state)

checkbox = Checkbox("Ready")
checkbox_state = state_for(checkbox)
mouse_event = MouseEvent(Position(9, 2), LeftMouseButton, MouseRelease)
mouse_handled = handle!(checkbox_state, checkbox, mouse_event, Rect(9, 1, 1, 24))
render!(buffer, Label("MouseEvent -> Checkbox"), Rect(8, 1, 1, 34))
render!(buffer, checkbox, Rect(9, 1, 1, 24), checkbox_state)

paste_event = PasteEvent("deploy")
resize_event = ResizeEvent(Size(18, 76))
focus_event = FocusEvent(true)
tick_event = TickEvent(UInt64(2_000_000_000), UInt64(16_000_000))
custom_event = CustomEvent(:refresh)

summary = """
key handled: $button_handled
mouse handled: $mouse_handled
paste: $(paste_event.text)
resize: $(resize_event.size.height)x$(resize_event.size.width)
focus: $(focus_event.focused)
tick elapsed ns: $(tick_event.elapsed_ns)
custom payload: $(custom_event.payload)
"""
render!(buffer, Box(Paragraph(summary; wrap=NoWrap); block=Block(title="Typed events")), Rect(4, 38, 10, 36))

snapshot = plain_snapshot(buffer)
@assert occursin("Input events quickstart", snapshot)
@assert occursin("KeyEvent -> Button", snapshot)
@assert occursin("MouseEvent -> Checkbox", snapshot)
@assert occursin("key handled: true", snapshot)
@assert occursin("mouse handled: true", snapshot)
@assert occursin("paste: deploy", snapshot)
@assert occursin("resize: 18x76", snapshot)
@assert occursin("focus: true", snapshot)
@assert occursin("custom payload: refresh", snapshot)

println("input events quickstart example completed")
