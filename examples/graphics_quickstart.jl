using Wicked.API

pixels = UInt8[
    255, 0, 0,      0, 255, 0,
    0, 0, 255,      255, 255, 0,
]
image = RasterImage(2, 2, RGB24, pixels)

buffer = Buffer(14, 70)
render!(buffer, Heading("Graphics quickstart"; level=1), Rect(1, 1, 2, 70))

capabilities = GraphicsCapabilities([UnicodeGraphics])
fallback = unicode_fallback(image, 4, 2)
graphics_dispatcher = SemanticDispatcher()

render!(buffer, Label("ImageView unicode fallback"), Rect(4, 1, 1, 34))
image_view = ImageView(image; width=4, height=2)
register_image_view_semantic_handlers!(graphics_dispatcher, :image_view, image_view)
render!(buffer, image_view, Rect(5, 1, 2, 4))

render!(buffer, Label("BrailleImage fallback"), Rect(8, 1, 1, 34))
braille_image = BrailleImage(image; width=4, height=2)
register_braille_image_semantic_handlers!(graphics_dispatcher, :braille_image, braille_image)
render!(buffer, braille_image, Rect(9, 1, 2, 4))

summary = """
protocols: $(join(string.(capabilities.protocols), ","))
pixels: $(image.width)x$(image.height)
fallback cells: $(size(fallback, 1))x$(size(fallback, 2))
"""
render!(buffer, Box(Paragraph(summary; wrap=NoWrap); block=Block(title="Graphics metadata")), Rect(4, 28, 7, 40))

snapshot = plain_snapshot(buffer)
@assert occursin("Graphics quickstart", snapshot)
@assert occursin("ImageView unicode fallback", snapshot)
@assert occursin("BrailleImage fallback", snapshot)
@assert occursin("Graphics metadata", snapshot)
@assert occursin("protocols: UnicodeGraphics", snapshot)
@assert occursin("pixels: 2x2", snapshot)
@assert occursin("fallback cells: 2x4", snapshot)
graphics_tree = ToolkitTree(column(
    Element(image_view; id=:image_view, key=:image_view),
    Element(braille_image; id=:braille_image, key=:braille_image),
))
graphics_pilot = SemanticPilot(toolkit_semantic_tree(graphics_tree); dispatcher=graphics_dispatcher)
@assert perform_semantic_action!(graphics_pilot, "image_view", FocusSemanticAction).handled
@assert perform_semantic_action!(graphics_pilot, "braille_image", SelectSemanticAction).handled

println("graphics quickstart example completed")
