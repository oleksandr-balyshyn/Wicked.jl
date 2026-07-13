using Wicked.API

mktempdir() do root
    mkdir(joinpath(root, "src"))
    write(joinpath(root, "README.md"), "Wicked example\n")
    write(joinpath(root, "src", "app.jl"), "println(\"hello\")\n")

    buffer = Buffer(24, 92)
    render!(buffer, Heading("File browser quickstart"; level=1), Rect(1, 1, 2, 92))

    files = FilePicker(root; root, width=42, height=6)
    file_state = state_for(files)
    render!(buffer, Label("FilePicker"), Rect(4, 1, 1, 42))
    render!(buffer, files, Rect(5, 1, 6, 42), file_state)

    directories = DirectoryPicker(root; root, width=42, height=5)
    directory_state = state_for(directories)
    render!(buffer, Label("DirectoryPicker"), Rect(4, 48, 1, 42))
    render!(buffer, directories, Rect(5, 48, 5, 42), directory_state)

    tree = DirectoryTree(root; root, width=42, height=5)
    tree_state = state_for(tree)
    handle!(tree_state, tree, KeyEvent(Key(:down)))
    render!(buffer, Label("DirectoryTree"), Rect(12, 1, 1, 42))
    render!(buffer, tree, Rect(13, 1, 5, 42), tree_state)

    many = MultiFilePicker(root; root, width=42, height=5)
    many_state = state_for(many)
    handle!(many_state, many, KeyEvent(Key(:space)))
    render!(buffer, Label("MultiFilePicker"), Rect(12, 48, 1, 42))
    render!(buffer, many, Rect(13, 48, 5, 42), many_state)

    snapshot = plain_snapshot(buffer)
    @assert occursin("File browser quickstart", snapshot)
    @assert occursin("FilePicker", snapshot)
    @assert occursin("DirectoryPicker", snapshot)
    @assert occursin("DirectoryTree", snapshot)
    @assert occursin("MultiFilePicker", snapshot)
    @assert occursin("README.md", snapshot)
    @assert occursin("src", snapshot)
end

println("file browser quickstart example completed")
