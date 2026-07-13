using Wicked.API

buffer = Buffer(10, 48)
frame = Frame(buffer)

title = TitleBar("Immediate quickstart"; subtitle="explicit state and render calls")
render!(frame, title, Rect(1, 1, 2, 48))

items = List(["Build", "Test", "Release"])
items_state = ListState(selected=1)
render!(buffer, items, Rect(3, 1, 3, 18), items_state)

handle!(items_state, items, KeyEvent(Key(:down)); viewport_height=3)
render!(buffer, items, Rect(3, 22, 3, 18), items_state)

progress = Progress(0.5; label="Build")
render!(buffer, progress, Rect(7, 1, 1, 30), ProgressState())

status = Status("Ready"; severity=:success)
render!(buffer, status, Rect(8, 1, 3, 30))

snapshot = plain_snapshot(buffer)
@assert occursin("Immediate quickstart", snapshot)
@assert occursin("Build", snapshot)
@assert occursin("Test", snapshot)
@assert occursin("Release", snapshot)
@assert occursin("Ready", snapshot)

println("immediate quickstart example completed")
