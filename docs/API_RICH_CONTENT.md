# Rich Content API

Markdown, syntax highlighting, code views, diffs, rich surfaces, and the
associated keyboard/pointer adapters are available through the stable
`Wicked.API` facade.

This page contains generated reference documentation for Markdown, code views,
rich surfaces, rich widgets, and integration adapters.

## Stable widget quickstart

Use `Wicked.API` names for application panes, diagnostics, and captured terminal
content. These widgets keep scroll, focus, and log state explicit so render
functions remain deterministic:

```julia
using Wicked.API

markdown = MarkdownView("# Release notes\nReady to publish"; width=40)
code = CodeView("println(:ok)"; language="julia", width=40, height=4)
syntax = SyntaxView("x = 1"; language="julia", width=40, height=3)
diff = DiffView(parse_unified_diff("--- a/file.jl\n+++ b/file.jl\n@@ -1 +1 @@\n-old\n+new\n"); width=40, height=4)
error = ErrorView(ErrorException("boom"))

log_state = LogState()
push_log!(log_state, "build started"; level=:info)
log = LogView()

terminal = TerminalView("build complete"; width=40, height=2)
terminal_state = state_for(terminal)

ansi = AnsiView("\e[32mok\e[0m"; width=12, height=1)
ansi_state = state_for(ansi)

link = Hyperlink("Open docs", :docs)
link_state = state_for(link)

buffer = Buffer(20, 80)
render!(buffer, markdown, Rect(1, 1, 4, 40))
render!(buffer, code, Rect(5, 1, 4, 40), state_for(code))
render!(buffer, syntax, Rect(9, 1, 3, 40), state_for(syntax))
render!(buffer, diff, Rect(12, 1, 4, 40), state_for(diff))
render!(buffer, error, Rect(1, 42, 4, 36))
render!(buffer, log, Rect(5, 42, 3, 36), log_state)
render!(buffer, terminal, Rect(8, 42, 2, 36), terminal_state)
render!(buffer, ansi, Rect(10, 42, 1, 36), ansi_state)
render!(buffer, link, Rect(11, 42, 1, 36), link_state)
```

Use `register_markdown_view_semantic_handlers!`,
`register_code_view_semantic_handlers!`,
`register_code_editor_semantic_handlers!`,
`register_syntax_view_semantic_handlers!`,
`register_diff_view_semantic_handlers!`,
`register_ansi_view_semantic_handlers!`,
`register_hyperlink_semantic_handlers!`,
`register_link_semantic_handlers!`,
`register_terminal_view_semantic_handlers!`,
`register_process_view_semantic_handlers!`,
`register_log_view_semantic_handlers!`,
`register_rich_log_semantic_handlers!`,
`register_log_tail_semantic_handlers!`,
`register_repl_view_semantic_handlers!`,
`register_task_monitor_semantic_handlers!`,
`register_live_display_semantic_handlers!`, and
`register_progress_group_semantic_handlers!` when tests or automation should
drive rich content and runtime panes through semantic actions. These handlers
reuse the same explicit scroll, link focus, safe-link activation, paused,
progress, and REPL input state used by keyboard input.

Use `MarkdownView` for documents with links, `CodeView` and `SyntaxView` for
source panes, `DiffView` for unified diffs, `ErrorView` for failure reports,
`LogView` and `RichLog` for append-only application logs, and `TerminalView` or
`AnsiView` for captured process output. Use `Hyperlink` or `Link` when the text
should activate an application target through explicit widget state.

```@autodocs
Modules = [
    Wicked.RichContent,
    Wicked.RichWidgets,
    Wicked.RichAdapters,
    Wicked.RichSurfaces,
    Wicked.CodeViewer,
    Wicked.CodeViewerIntegration,
]
Private = false
```
