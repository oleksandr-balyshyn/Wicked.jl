using Wicked.API

buffer = Buffer(16, 72)
text_dispatcher = SemanticDispatcher()

title = Heading("Text quickstart"; level=1)
register_heading_semantic_handlers!(text_dispatcher, :title, title)
render!(buffer, title, Rect(1, 1, 2, 72))

divider = Rule()
register_rule_semantic_handlers!(text_dispatcher, :divider, divider)
render!(buffer, divider, Rect(3, 1, 1, 72))

label = Label("Label: single-line text"; style=Style(modifiers=BOLD))
register_label_semantic_handlers!(text_dispatcher, :label, label)
render!(buffer, label, Rect(5, 1, 1, 32))

paragraph = Paragraph("Paragraph: wrapped text stays deterministic in narrow regions."; wrap=WordWrap)
register_paragraph_semantic_handlers!(text_dispatcher, :paragraph, paragraph)
render!(
    buffer,
    paragraph,
    Rect(7, 1, 3, 32),
)

static_text = Static("Static: read-only display")
register_static_semantic_handlers!(text_dispatcher, :static_text, static_text)
render!(buffer, static_text, Rect(11, 1, 1, 32))

text_view = TextView("TextView: named display view")
register_text_view_semantic_handlers!(text_dispatcher, :text_view, text_view)
render!(buffer, text_view, Rect(13, 1, 1, 32))

separator = Separator(VerticalRule)
register_separator_semantic_handlers!(text_dispatcher, :separator, separator)
render!(buffer, separator, Rect(5, 36, 9, 1))

section_divider = Divider(HorizontalRule; symbol="═")
register_divider_semantic_handlers!(text_dispatcher, :section_divider, section_divider)
render!(buffer, section_divider, Rect(15, 40, 1, 30))

markup = MarkupText("# Markup\n**Ready** to publish"; width=30)
register_markup_text_semantic_handlers!(text_dispatcher, :markup, markup)
render!(buffer, markup, Rect(5, 40, 6, 30))

subsection = Heading("Subsection"; level=3)
register_heading_semantic_handlers!(text_dispatcher, :subsection, subsection)
render!(buffer, subsection, Rect(12, 40, 1, 30))

done = Label("Done")
register_label_semantic_handlers!(text_dispatcher, :done, done)
render!(buffer, done, Rect(14, 40, 1, 30))

snapshot = plain_snapshot(buffer)
@assert occursin("Text quickstart", snapshot)
@assert occursin("Label: single-line text", snapshot)
@assert occursin("Paragraph: wrapped text", snapshot)
@assert occursin("Static: read-only display", snapshot)
@assert occursin("TextView: named display view", snapshot)
@assert occursin("Markup", snapshot)
@assert occursin("Ready", snapshot)
@assert has_inline_role(markup, :strong)
@assert occursin("Subsection", snapshot)
@assert occursin("Done", snapshot)
@assert occursin("═", snapshot)

println("text quickstart example completed")
