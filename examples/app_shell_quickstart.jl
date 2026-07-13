using Wicked.API

buffer = Buffer(12, 72)

shell = AppShell(
    Paragraph("Build output\nTests queued\nRelease pending");
    title="Wicked",
    subtitle="Application shell quickstart",
    toolbar=Toolbar(Button("Run"), Button("Stop"); gap=1),
    sidebar=List(["Overview", "Jobs", "Settings"]),
    sidebar_size=14,
    shortcuts=[:q => "Quit", :r => "Refresh"],
)

render!(buffer, shell, buffer.area)

layout = app_shell_layout(shell)
@assert layout.top_size == 2
@assert layout.left_size == 14
summary = app_shell_summary(shell)
@assert summary.sidebar_side == :left

snapshot = plain_snapshot(buffer)
@assert occursin("Wicked", snapshot)
@assert occursin("Application shell quickstart", snapshot)
@assert occursin("Overview", snapshot)
@assert occursin("Build output", snapshot)
@assert occursin("Quit", snapshot)

println("app shell quickstart example completed")
