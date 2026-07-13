using Wicked.API

buffer = Buffer(18, 80)

markdown = MarkdownView("# Release notes\n[Docs](https://example.com)\nReady to publish"; width=36)
markdown_state = state_for(markdown)
markdown_dispatcher = SemanticDispatcher()
register_markdown_view_semantic_handlers!(markdown_dispatcher, :markdown, markdown_state)
render!(buffer, markdown, Rect(1, 1, 3, 36), markdown_state)

code = CodeView("println(:ok)\nprintln(:done)"; language="julia", width=36, height=4)
code_state = state_for(code)
code_dispatcher = SemanticDispatcher()
register_code_view_semantic_handlers!(code_dispatcher, :code, code, code_state)
render!(buffer, code, Rect(4, 1, 4, 36), code_state)

editor = CodeEditor("println(:draft)"; language="julia")
editor_state = state_for(editor)
editor_dispatcher = SemanticDispatcher()
register_code_editor_semantic_handlers!(editor_dispatcher, :editor, editor, editor_state)

syntax = SyntaxView("x = 1"; language="julia", width=36, height=2)
syntax_state = state_for(syntax)
syntax_dispatcher = SemanticDispatcher()
register_syntax_view_semantic_handlers!(syntax_dispatcher, :syntax, syntax, syntax_state)
render!(buffer, syntax, Rect(8, 1, 2, 36), syntax_state)

diff = DiffView(
    parse_unified_diff("--- a/app.jl\n+++ b/app.jl\n@@ -1 +1 @@\n-old\n+new\n");
    width=36,
    height=3,
)
diff_state = state_for(diff)
diff_dispatcher = SemanticDispatcher()
register_diff_view_semantic_handlers!(diff_dispatcher, :diff, diff, diff_state)
render!(buffer, diff, Rect(10, 1, 3, 36), diff_state)

error_view = ErrorView(ErrorException("boom"); title="Error")
error_dispatcher = SemanticDispatcher()
register_error_view_semantic_handlers!(error_dispatcher, :error, error_view)
render!(buffer, error_view, Rect(13, 1, 4, 36))

terminal = TerminalView("build complete"; width=36, height=1)
terminal_state = state_for(terminal)
terminal_dispatcher = SemanticDispatcher()
register_terminal_view_semantic_handlers!(terminal_dispatcher, :terminal, terminal, terminal_state)
render!(buffer, terminal, Rect(1, 42, 1, 36), terminal_state)

ansi = AnsiView("\e[32mok\e[0m"; width=12, height=1)
ansi_state = state_for(ansi)
ansi_dispatcher = SemanticDispatcher()
register_ansi_view_semantic_handlers!(ansi_dispatcher, :ansi, ansi, ansi_state)
render!(buffer, ansi, Rect(2, 42, 1, 36), ansi_state)

link = Hyperlink("Open docs", :docs)
link_state = state_for(link)
link_dispatcher = SemanticDispatcher()
register_hyperlink_semantic_handlers!(link_dispatcher, :link, link, link_state)
render!(buffer, link, Rect(3, 42, 1, 36), link_state)

log_state = LogState()
push_log!(log_state, "watch"; level=:info)
push_log!(log_state, "warning"; level=:warning)
log_dispatcher = SemanticDispatcher()
register_log_view_semantic_handlers!(log_dispatcher, :log, log_state; viewport_height=3)
render!(buffer, LogView(), Rect(5, 42, 3, 36), log_state)

rich_log_state = RichLogState()
push_log!(rich_log_state, "rich"; level=:info)
rich_log_dispatcher = SemanticDispatcher()
register_rich_log_semantic_handlers!(rich_log_dispatcher, :rich_log, rich_log_state; viewport_height=2)
render!(buffer, RichLog(), Rect(9, 42, 2, 36), rich_log_state)

theme_registry = ThemeRegistry()
preview = ThemePreview(theme_registry; width=30, height=3)
preview_state = state_for(preview)
theme_dispatcher = SemanticDispatcher()
register_theme_preview_semantic_handlers!(theme_dispatcher, :theme_preview, preview, preview_state)
render!(buffer, preview, Rect(12, 42, 3, 30), preview_state)

hub = DiagnosticsHub()
inspector = Inspector(hub; visible=true, width=36, height=2)
inspector_state = state_for(inspector)
inspector_dispatcher = SemanticDispatcher()
register_inspector_semantic_handlers!(inspector_dispatcher, :inspector, inspector_state)
render!(buffer, inspector, Rect(16, 1, 2, 36), inspector_state)

console = DevConsole(hub; visible=true, width=30, height=2)
console_state = state_for(console)
console_dispatcher = SemanticDispatcher()
register_dev_console_semantic_handlers!(console_dispatcher, :console, console, console_state)
render!(buffer, console, Rect(16, 42, 2, 30), console_state)

help = HelpView([KeyHint("q", "Quit"), KeyHint("?", "Show help")])
help_dispatcher = SemanticDispatcher()
register_help_view_semantic_handlers!(help_dispatcher, :help, help)

snapshot = plain_snapshot(buffer)
markdown_semantics = toolkit_semantic_tree(ToolkitTree(Element(markdown; id=:markdown, key=:markdown, state_factory=() -> markdown_state)))
markdown_pilot = SemanticPilot(markdown_semantics; dispatcher=markdown_dispatcher)
@assert perform_semantic_action!(markdown_pilot, "markdown", FocusSemanticAction).handled
semantics = toolkit_semantic_tree(ToolkitTree(Element(terminal; id=:terminal, key=:terminal, state_factory=() -> terminal_state)))
terminal_pilot = SemanticPilot(semantics; dispatcher=terminal_dispatcher)
@assert perform_semantic_action!(terminal_pilot, "terminal", ScrollIntoViewSemanticAction).handled
log_semantics = toolkit_semantic_tree(ToolkitTree(Element(LogView(); id=:log, key=:log, state_factory=() -> log_state)))
log_pilot = SemanticPilot(log_semantics; dispatcher=log_dispatcher)
@assert perform_semantic_action!(log_pilot, "log", ScrollIntoViewSemanticAction).handled
code_semantics = toolkit_semantic_tree(ToolkitTree(Element(code; id=:code, key=:code, state_factory=() -> code_state)))
code_pilot = SemanticPilot(code_semantics; dispatcher=code_dispatcher)
@assert perform_semantic_action!(code_pilot, "code", IncrementSemanticAction).handled
editor_semantics = toolkit_semantic_tree(ToolkitTree(Element(editor; id=:editor, key=:editor, state_factory=() -> editor_state)))
editor_pilot = SemanticPilot(editor_semantics; dispatcher=editor_dispatcher)
@assert perform_semantic_action!(editor_pilot, "editor", SetValueSemanticAction; value="println(:ready)").handled
error_semantics = toolkit_semantic_tree(ToolkitTree(Element(error_view; id=:error, key=:error)))
error_pilot = SemanticPilot(error_semantics; dispatcher=error_dispatcher)
@assert perform_semantic_action!(error_pilot, "error", SelectSemanticAction).handled
link_semantics = toolkit_semantic_tree(ToolkitTree(Element(link; id=:link, key=:link, state_factory=() -> link_state)))
link_pilot = SemanticPilot(link_semantics; dispatcher=link_dispatcher)
@assert perform_semantic_action!(link_pilot, "link", ActivateSemanticAction).handled
theme_semantics = toolkit_semantic_tree(ToolkitTree(Element(preview; id=:theme_preview, key=:theme_preview, state_factory=() -> preview_state)))
theme_pilot = SemanticPilot(theme_semantics; dispatcher=theme_dispatcher)
@assert perform_semantic_action!(theme_pilot, "theme_preview", FocusSemanticAction).handled
inspector_semantics = toolkit_semantic_tree(ToolkitTree(Element(inspector; id=:inspector, key=:inspector, state_factory=() -> inspector_state)))
inspector_pilot = SemanticPilot(inspector_semantics; dispatcher=inspector_dispatcher)
@assert perform_semantic_action!(inspector_pilot, "inspector", IncrementSemanticAction).handled
console_semantics = toolkit_semantic_tree(ToolkitTree(Element(console; id=:console, key=:console, state_factory=() -> console_state)))
console_pilot = SemanticPilot(console_semantics; dispatcher=console_dispatcher)
@assert perform_semantic_action!(console_pilot, "console", ScrollIntoViewSemanticAction).handled
help_semantics = toolkit_semantic_tree(ToolkitTree(Element(help; id=:help, key=:help)))
help_pilot = SemanticPilot(help_semantics; dispatcher=help_dispatcher)
@assert perform_semantic_action!(help_pilot, "help/hint/1", SelectSemanticAction).handled
@assert occursin("Release notes", snapshot)
@assert occursin("println", snapshot)
@assert occursin("new", snapshot)
@assert occursin("boom", snapshot)
@assert occursin("build complete", snapshot)
@assert occursin("ok", snapshot)
@assert occursin("Open docs", snapshot)
@assert occursin("watch", snapshot)
@assert occursin("rich", snapshot)
@assert occursin("MetricsPanel", snapshot)

println("rich content quickstart example completed")
