using Wicked.API

buffer = Buffer(40, 100)

render!(buffer, TitleBar("Wicked Widget Gallery"; subtitle="stable immediate-mode API"), Rect(1, 1, 2, 100))
render!(buffer, StatusBar(["q" => "Quit", "tab" => "Next"]), Rect(40, 1, 1, 100))

render!(buffer, Panel(Paragraph("Layout wrappers: Panel, Border, Wrap, Dock, Overlay")), Rect(3, 1, 4, 38))
render!(buffer, Separator(), Rect(7, 1, 1, 38))
render!(buffer, Border(title="Inputs"), Rect(3, 40, 7, 30))
render!(buffer, Border(title="Feedback"), Rect(3, 70, 9, 28))

render!(buffer, Badge("READY"), Rect(4, 72, 1, 10))
render!(buffer, Status("Healthy"; severity=:success), Rect(5, 72, 3, 24))
render!(buffer, Toast("Saved"; title="Build", severity=:success), Rect(8, 72, 1, 24))

center = NotificationCenter(2)
push_notification!(center, Notification("Deployment completed"; id=:deploy, title="Deploy", severity=:success))
render!(buffer, NotificationView(center), Rect(9, 71, 1, 29))

issues = ValidationIssue[ValidationIssue(:required, "Name is required")]
render!(buffer, ValidationMessage(issues), Rect(10, 72, 1, 24))

search = SearchInput(placeholder="Find")
search_state = SearchInputState("widgets"; focused=true)
render!(buffer, search, Rect(4, 42, 1, 20), search_state)

field = TextField(placeholder="Project")
field_state = TextFieldState("Wicked"; focused=true)
render!(buffer, field, Rect(5, 42, 1, 20), field_state)

password = PasswordField(placeholder="Password", mask="*")
password_state = PasswordFieldState("secret"; focused=true)
render!(buffer, password, Rect(6, 42, 1, 20), password_state)

number = NumberInput(placeholder="Port")
number_state = NumberInputState(value=8080, minimum=1, maximum=65535)
render!(buffer, number, Rect(7, 42, 1, 20), number_state)

notes = Textarea(show_line_numbers=true)
notes_state = TextAreaState("first note\nsecond note")
render!(buffer, notes, Rect(8, 1, 4, 38), notes_state)

render!(buffer, Static("Static summary"), Rect(12, 1, 1, 24))
render!(buffer, TextView("Text view\nready"), Rect(13, 1, 2, 24))

items = ListBox(["Build", "Test", "Release"])
render!(buffer, items, Rect(10, 40, 3, 18), state_for(items))

options = [ChoiceOption(:debug, "Debug"), ChoiceOption(:release, "Release")]
select = Select(options)
render!(buffer, select, Rect(10, 60, 2, 10), SelectState(selected=1))

multi = MultiSelect(options)
render!(buffer, multi, Rect(12, 60, 2, 10), MultiSelectState(selected=[1, 2]))

combo = Combobox(["Debug", "Release"]; placeholder="Mode")
render!(buffer, combo, Rect(13, 40, 2, 18), state_for(combo))

option_list = OptionList(["Fast", "Safe"])
render!(buffer, option_list, Rect(14, 60, 2, 10), OptionListState(selected=1))

radio = RadioBoxList([:debug => "Debug", :release => "Release"])
render!(buffer, radio, Rect(15, 40, 2, 24), RadioBoxListState(selected=2))

checks = CheckBoxList([:docs => "Docs", :tests => "Tests"])
render!(buffer, checks, Rect(17, 40, 2, 24), CheckBoxListState(selected=[1, 2]))

palette = CommandPalette([CommandItem(:open, "Open"), CommandItem(:rollback, "Rollback")]; title="Commands")
render!(buffer, palette, Rect(19, 40, 3, 24), CommandPaletteState(open=true))

split = SplitButton("Launch release", :launch_release)
render!(buffer, split, Rect(22, 40, 3, 24), state_for(split))

render!(buffer, Border(title="Data"), Rect(17, 70, 7, 28))
data_rows = [(name="Build", status="Ready"), (name="Test", status="Queued")]
data_columns = [
    VirtualTableColumn(:name, "Name"; accessor=row -> row.name),
    VirtualTableColumn(:status, "Status"; accessor=row -> row.status),
]

virtual_list = VirtualList(
    data_rows;
    width=24,
    height=2,
    key=(row, _) -> Symbol(row.name),
    format=VirtualListFormat(item=(row, _) -> "$(row.name) $(row.status)"),
)
render!(buffer, virtual_list, Rect(18, 72, 2, 24))

virtual_table = VirtualTable(data_rows, data_columns; width=24, height=2)
render!(buffer, virtual_table, Rect(20, 72, 2, 24))

tree_source = CallbackTreeDataSource{String,Symbol}(
    roots=() -> ["Project"],
    children=item -> item == "Project" ? ["Build"] : String[],
    key=item -> Symbol(item),
)
render!(buffer, VirtualTree(tree_source; width=24, height=1), Rect(22, 72, 1, 24))

modal = Window("Apply changes?"; title="Confirm")
render!(buffer, modal, Rect(12, 70, 5, 28), WindowState(DialogButton{Nothing}[]; open=true))

render!(buffer, RichText("RichText wrapper"), Rect(15, 1, 1, 24))
render!(buffer, LoadingIndicator(frames=["-", "\\"], label="Loading"), Rect(16, 1, 1, 24), LoadingIndicatorState())
render!(buffer, Skeleton(), Rect(17, 1, 1, 24), SkeletonState(period=4))
render!(buffer, EmptyState("No results"; message="Try another query."), Rect(18, 1, 3, 30))
render!(buffer, Progress(0.42; label="Building"), Rect(21, 1, 1, 30), ProgressState())

floating = Overlay(Paragraph("base layer"), Label("floating"))
render!(buffer, floating, Rect(22, 1, 2, 24))

render!(buffer, Border(title="Navigation"), Rect(24, 1, 4, 98))
menu_button = MenuButton("Open", :open)
render!(buffer, menu_button, Rect(25, 3, 3, 16), state_for(menu_button))

context_menu = ContextMenu([MenuItem(:copy, "Copy"), MenuItem(:paste, "Paste")])
render!(buffer, context_menu, Rect(25, 22, 2, 18), state_for(context_menu))

rail = NavigationRail([MenuItem(:home, "Home"), MenuItem(:logs, "Logs"), MenuItem(:settings, "Settings")])
render!(buffer, rail, Rect(25, 43, 3, 18), state_for(rail))

breadcrumbs = Breadcrumb([BreadcrumbItem("Root", :root), BreadcrumbItem("Build", :build)])
render!(buffer, breadcrumbs, Rect(25, 65, 1, 30), state_for(breadcrumbs))

render!(buffer, Border(title="Visuals"), Rect(28, 1, 6, 98))
render!(buffer, Gauge(0.75; label="Upload"), Rect(29, 3, 3, 22))
render!(buffer, Sparkline([1.0, 2.0, 3.0, 2.0]), Rect(32, 3, 1, 22))
render!(buffer, BarChart(["Build" => 3.0, "Test" => 2.0]), Rect(29, 28, 4, 20))
render!(buffer, Chart([ChartDataset([(0.0, 0.0), (1.0, 1.0)])]), Rect(29, 51, 4, 20))
render!(buffer, Heatmap([1.0 2.0; 3.0 4.0]), Rect(29, 74, 2, 10))
render!(buffer, Calendar(2026, 7), Rect(29, 86, 4, 12))

render!(buffer, Border(title="Rich content"), Rect(34, 1, 6, 98))
markdown = MarkdownView("# Docs\nReady"; width=22)
render!(buffer, markdown, Rect(35, 3, 2, 22))

code = CodeView("println(:ok)"; language="julia", width=22, height=2)
render!(buffer, code, Rect(37, 3, 2, 22), state_for(code))

syntax = SyntaxView("x = 1"; language="julia", width=20, height=2)
render!(buffer, syntax, Rect(35, 28, 2, 20), state_for(syntax))

diff = DiffView(parse_unified_diff("--- a/file.jl\n+++ b/file.jl\n@@ -1 +1 @@\n-old\n+new\n"); width=20, height=2)
render!(buffer, diff, Rect(37, 28, 2, 20), state_for(diff))

render!(buffer, ErrorView(ErrorException("boom"); title="Error"), Rect(35, 51, 3, 20))

terminal = TerminalView("build complete"; width=20, height=1)
render!(buffer, terminal, Rect(38, 51, 1, 20), state_for(terminal))

ansi = AnsiView("\e[32mok\e[0m"; width=10, height=1)
render!(buffer, ansi, Rect(35, 74, 1, 12), state_for(ansi))

link = Hyperlink("Docs", :docs)
render!(buffer, link, Rect(36, 74, 1, 12), state_for(link))

log_state = LogState()
push_log!(log_state, "watch"; level=:info)
render!(buffer, LogView(), Rect(37, 74, 2, 20), log_state)

snapshot = plain_snapshot(buffer)

@assert occursin("Wicked Widget Gallery", snapshot)
@assert occursin("widgets", snapshot)
@assert occursin("Wicked", snapshot)
@assert occursin("READY", snapshot)
@assert occursin("Healthy", snapshot)
@assert occursin("Saved", snapshot)
@assert occursin("Deployment completed", snapshot)
@assert occursin("Name is required", snapshot)
@assert occursin("***", snapshot)
@assert occursin("8080", snapshot)
@assert occursin("first note", snapshot)
@assert occursin("Static summary", snapshot)
@assert occursin("Text view", snapshot)
@assert occursin("Build", snapshot)
@assert occursin("Release", snapshot)
@assert occursin("Fast", snapshot)
@assert occursin("Docs", snapshot)
@assert occursin("Commands", snapshot)
@assert occursin("Launch release", snapshot)
@assert occursin("Queued", snapshot)
@assert occursin("Project", snapshot)
@assert occursin("Open", snapshot)
@assert occursin("Copy", snapshot)
@assert occursin("Home", snapshot)
@assert occursin("Root", snapshot)
@assert occursin("Visuals", snapshot)
@assert occursin("Upload", snapshot)
@assert occursin("Rich content", snapshot)
@assert occursin("println", snapshot)
@assert occursin("boom", snapshot)
@assert occursin("build complete", snapshot)
@assert occursin("watch", snapshot)
@assert occursin("Confirm", snapshot)
@assert occursin("RichText wrapper", snapshot)
@assert occursin("No results", snapshot)
@assert occursin("Building", snapshot)
@assert occursin("floating", snapshot)

println("widget gallery example completed")
