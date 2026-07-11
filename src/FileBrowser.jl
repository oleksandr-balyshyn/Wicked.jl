module FileBrowser

using Dates: DateTime, unix2datetime
using Unicode: graphemes
using ..AdvancedControls: BreadcrumbItem
using ..RichContent: RichSpan, RichLine
using ..Accessibility: SemanticRect,
                       SemanticState,
                       SemanticNode,
                       SemanticTree,
                       TreeRole,
                       TreeItemRole,
                       SelectSemanticAction,
                       ActivateSemanticAction,
                       ExpandSemanticAction

export FileEntryKind,
       RegularFileEntry,
       DirectoryFileEntry,
       SymbolicLinkFileEntry,
       OtherFileEntry,
       FileEntry,
       DirectoryEntryLimitError,
       FileBrowserDiagnostic,
       DirectoryReadResult,
       read_directory_entries,
       FileSortField,
       FileNameSort,
       FileSizeSort,
       FileModifiedSort,
       FileKindSort,
       FileSortDirection,
       AscendingFileSort,
       DescendingFileSort,
       FilePickerMode,
       SelectFileMode,
       SelectDirectoryMode,
       SelectMultipleMode,
       FileChoice,
       FileBrowserState,
       refresh_file_browser!,
       set_file_filter!,
       set_file_sort!,
       move_file_cursor!,
       set_file_cursor!,
       current_file_entry,
       enter_file_entry!,
       leave_file_directory!,
       toggle_file_selection!,
       clear_file_selection!,
       choose_file_entry!,
       choose_current_directory!,
       file_choices,
       navigate_file_browser!,
       file_path_breadcrumbs,
       render_file_browser,
       file_browser_semantic_tree,
       FileBrowserController,
       request_file_refresh!,
       poll_file_refresh!,
       cancel_file_refresh!

@enum FileEntryKind begin
    RegularFileEntry
    DirectoryFileEntry
    SymbolicLinkFileEntry
    OtherFileEntry
end

struct FileEntry
    name::String
    path::String
    kind::FileEntryKind
    size::Union{Nothing,Int64}
    modified::Union{Nothing,DateTime}
    hidden::Bool
end

struct DirectoryEntryLimitError <: Exception
    maximum_entries::Int
end

Base.showerror(io::IO, error::DirectoryEntryLimitError) =
    print(io, "directory contains more than ", error.maximum_entries, " visible entries")

struct FileBrowserDiagnostic
    path::String
    operation::Symbol
    error::Any
end

struct DirectoryReadResult
    path::String
    entries::Vector{FileEntry}
    diagnostics::Vector{FileBrowserDiagnostic}
end

function _entry_kind(path::AbstractString)
    islink(path) && return SymbolicLinkFileEntry
    isdir(path) && return DirectoryFileEntry
    isfile(path) && return RegularFileEntry
    return OtherFileEntry
end

function _entry_metadata(path::String, kind::FileEntryKind)
    information = kind == SymbolicLinkFileEntry ? lstat(path) : stat(path)
    size = kind == DirectoryFileEntry ? nothing : Int64(information.size)
    modified = try
        unix2datetime(information.mtime)
    catch
        nothing
    end
    return size, modified
end

"""Read one directory while retaining per-entry failures as diagnostics."""
function read_directory_entries(
    path::AbstractString;
    show_hidden::Bool=false,
    maximum_entries::Integer=100_000,
)
    maximum_entries >= 0 || throw(ArgumentError("maximum directory entries cannot be negative"))
    maximum_entries <= typemax(Int) || throw(ArgumentError("maximum directory entries is too large"))
    limit = Int(maximum_entries)
    directory = abspath(normpath(String(path)))
    diagnostics = FileBrowserDiagnostic[]
    names = try
        readdir(directory; join=false, sort=false)
    catch error
        push!(diagnostics, FileBrowserDiagnostic(directory, :readdir, (error, catch_backtrace())))
        return DirectoryReadResult(directory, FileEntry[], diagnostics)
    end
    entries = FileEntry[]
    for name in names
        hidden = startswith(name, '.') && name != "." && name != ".."
        hidden && !show_hidden && continue
        full_path = joinpath(directory, name)
        if length(entries) >= limit
            error = DirectoryEntryLimitError(limit)
            push!(diagnostics, FileBrowserDiagnostic(directory, :limit, (error, nothing)))
            break
        end
        try
            kind = _entry_kind(full_path)
            size, modified = _entry_metadata(full_path, kind)
            push!(entries, FileEntry(String(name), full_path, kind, size, modified, hidden))
        catch error
            push!(diagnostics, FileBrowserDiagnostic(full_path, :metadata, (error, catch_backtrace())))
            push!(entries, FileEntry(String(name), full_path, OtherFileEntry, nothing, nothing, hidden))
        end
    end
    return DirectoryReadResult(directory, entries, diagnostics)
end

@enum FileSortField begin
    FileNameSort
    FileSizeSort
    FileModifiedSort
    FileKindSort
end

@enum FileSortDirection begin
    AscendingFileSort
    DescendingFileSort
end

@enum FilePickerMode begin
    SelectFileMode
    SelectDirectoryMode
    SelectMultipleMode
end

struct FileChoice
    path::String
    kind::FileEntryKind
end

mutable struct FileBrowserState
    root::String
    current_path::String
    entries::Vector{FileEntry}
    diagnostics::Vector{FileBrowserDiagnostic}
    cursor::Union{Nothing,Int}
    selected::Set{String}
    choices::Vector{FileChoice}
    mode::FilePickerMode
    show_hidden::Bool
    follow_symlinks::Bool
    directories_first::Bool
    sort_field::FileSortField
    sort_direction::FileSortDirection
    filter::Union{Nothing,String,Regex}
    maximum_entries::Int
    generation::UInt64
    loading::Bool

    function FileBrowserState(
        path::AbstractString=pwd();
        root::AbstractString=path,
        mode::FilePickerMode=SelectFileMode,
        show_hidden::Bool=false,
        follow_symlinks::Bool=false,
        directories_first::Bool=true,
        sort_field::FileSortField=FileNameSort,
        sort_direction::FileSortDirection=AscendingFileSort,
        filter::Union{Nothing,AbstractString,Regex}=nothing,
        maximum_entries::Integer=100_000,
        refresh::Bool=true,
    )
        maximum_entries >= 0 || throw(ArgumentError("maximum directory entries cannot be negative"))
        maximum_entries <= typemax(Int) || throw(ArgumentError("maximum directory entries is too large"))
        root_path = _canonical_existing_directory(root)
        current = _canonical_existing_directory(path)
        _within_root(root_path, current) || throw(ArgumentError("initial file-browser path is outside its root"))
        filter_value = filter === nothing || filter isa Regex ? filter : String(filter)
        state = new(
            root_path,
            current,
            FileEntry[],
            FileBrowserDiagnostic[],
            nothing,
            Set{String}(),
            FileChoice[],
            mode,
            show_hidden,
            follow_symlinks,
            directories_first,
            sort_field,
            sort_direction,
            filter_value,
            Int(maximum_entries),
            0,
            false,
        )
        refresh && refresh_file_browser!(state)
        return state
    end
end

_safe_file_label(value::AbstractString) = escape_string(String(value))

function _canonical_existing_directory(path::AbstractString)
    value = abspath(normpath(String(path)))
    isdir(value) || throw(ArgumentError("not an existing directory: $value"))
    return realpath(value)
end

function _canonical_existing(path::AbstractString)
    value = abspath(normpath(String(path)))
    return ispath(value) ? realpath(value) : value
end

function _within_root(root::String, path::String)
    relative = relpath(path, root)
    return relative == "." ||
           !(relative == ".." || startswith(relative, "../") || startswith(relative, "..\\"))
end

function _entry_matches(state::FileBrowserState, entry::FileEntry)
    state.filter === nothing && return true
    label = _safe_file_label(entry.name)
    state.filter isa Regex && return occursin(state.filter, label)
    return occursin(lowercase(state.filter::String), lowercase(label))
end

function _sort_value(entry::FileEntry, field::FileSortField)
    field == FileNameSort && return lowercase(_safe_file_label(entry.name))
    field == FileSizeSort && return something(entry.size, typemax(Int64))
    field == FileModifiedSort && return something(entry.modified, DateTime(9999, 12, 31))
    return Int(entry.kind)
end

function _entry_before(state::FileBrowserState, left::FileEntry, right::FileEntry)
    if state.directories_first
        left_directory = left.kind == DirectoryFileEntry
        right_directory = right.kind == DirectoryFileEntry
        left_directory != right_directory && return left_directory
    end
    left_value = _sort_value(left, state.sort_field)
    right_value = _sort_value(right, state.sort_field)
    if left_value == right_value
        return lowercase(_safe_file_label(left.name)) < lowercase(_safe_file_label(right.name))
    end
    ascending = isless(left_value, right_value)
    return state.sort_direction == AscendingFileSort ? ascending : !ascending
end

function _apply_directory_result!(state::FileBrowserState, result::DirectoryReadResult)
    result.path == state.current_path || return false
    entries = FileEntry[entry for entry in result.entries if _entry_matches(state, entry)]
    sort!(entries; lt=(left, right) -> _entry_before(state, left, right))
    state.entries = entries
    state.diagnostics = copy(result.diagnostics)
    valid_paths = Set(entry.path for entry in entries)
    intersect!(state.selected, valid_paths)
    state.cursor = isempty(entries) ? nothing : clamp(something(state.cursor, 1), 1, length(entries))
    state.loading = false
    return true
end

function refresh_file_browser!(state::FileBrowserState)
    result = read_directory_entries(
        state.current_path;
        show_hidden=state.show_hidden,
        maximum_entries=state.maximum_entries,
    )
    state.generation == typemax(UInt64) && throw(OverflowError("file-browser generation overflow"))
    state.generation += 1
    _apply_directory_result!(state, result)
    return state
end

function set_file_filter!(state::FileBrowserState, filter)
    state.filter = filter === nothing || filter isa Regex ? filter : String(filter)
    return refresh_file_browser!(state)
end

function set_file_sort!(
    state::FileBrowserState,
    field::FileSortField;
    direction::FileSortDirection=state.sort_direction,
)
    state.sort_field = field
    state.sort_direction = direction
    return refresh_file_browser!(state)
end

function set_file_cursor!(state::FileBrowserState, index::Union{Nothing,Integer})
    if index === nothing || isempty(state.entries)
        state.cursor = nothing
    else
        state.cursor = clamp(Int(index), 1, length(state.entries))
    end
    return state
end

function move_file_cursor!(state::FileBrowserState, delta::Integer; wrap::Bool=false)
    isempty(state.entries) && (state.cursor = nothing; return state)
    current = something(state.cursor, 1)
    target = big(current) + big(delta)
    state.cursor = wrap ? mod1(Int(mod(target - 1, length(state.entries))) + 1, length(state.entries)) :
                   Int(clamp(target, big(1), big(length(state.entries))))
    return state
end

current_file_entry(state::FileBrowserState) =
    state.cursor === nothing ? nothing : state.entries[state.cursor]

function _navigate!(state::FileBrowserState, path::AbstractString)
    target = _canonical_existing_directory(path)
    _within_root(state.root, target) || throw(ArgumentError("file-browser navigation escaped its root"))
    state.current_path = target
    state.cursor = nothing
    empty!(state.selected)
    return refresh_file_browser!(state)
end

function enter_file_entry!(state::FileBrowserState)
    entry = current_file_entry(state)
    entry === nothing && return false
    directory = entry.kind == DirectoryFileEntry ||
                (entry.kind == SymbolicLinkFileEntry && state.follow_symlinks && isdir(entry.path))
    directory || return false
    try
        _navigate!(state, entry.path)
    catch error
        push!(state.diagnostics, FileBrowserDiagnostic(entry.path, :navigate, (error, catch_backtrace())))
        return false
    end
    return true
end

function leave_file_directory!(state::FileBrowserState)
    state.current_path == state.root && return false
    try
        _navigate!(state, dirname(state.current_path))
    catch error
        push!(state.diagnostics, FileBrowserDiagnostic(state.current_path, :navigate, (error, catch_backtrace())))
        return false
    end
    return true
end

function toggle_file_selection!(state::FileBrowserState)
    entry = current_file_entry(state)
    entry === nothing && return false
    if entry.path in state.selected
        delete!(state.selected, entry.path)
    else
        state.mode == SelectMultipleMode || empty!(state.selected)
        push!(state.selected, entry.path)
    end
    return true
end

clear_file_selection!(state::FileBrowserState) = (empty!(state.selected); state)

function _choice_allowed(state::FileBrowserState, entry::FileEntry)
    state.mode == SelectFileMode && return entry.kind == RegularFileEntry
    state.mode == SelectDirectoryMode && return entry.kind == DirectoryFileEntry
    return entry.kind in (RegularFileEntry, DirectoryFileEntry)
end

function _validated_file_choice(state::FileBrowserState, entry::FileEntry)
    try
        (ispath(entry.path) || islink(entry.path)) ||
            throw(ArgumentError("selected path no longer exists"))
        current_kind = _entry_kind(entry.path)
        current_kind == entry.kind ||
            throw(ArgumentError("selected path changed kind after the directory refresh"))
        canonical = _canonical_existing(entry.path)
        _within_root(state.root, canonical) ||
            throw(ArgumentError("selected path escaped the file-browser root"))
        return FileChoice(canonical, current_kind)
    catch error
        push!(state.diagnostics, FileBrowserDiagnostic(entry.path, :choose, (error, catch_backtrace())))
        return nothing
    end
end

function choose_file_entry!(state::FileBrowserState)
    empty!(state.choices)
    candidates = if state.mode == SelectMultipleMode && !isempty(state.selected)
        FileEntry[entry for entry in state.entries if entry.path in state.selected]
    else
        entry = current_file_entry(state)
        entry === nothing ? FileEntry[] : FileEntry[entry]
    end
    choices = FileChoice[]
    for entry in candidates
        _choice_allowed(state, entry) || continue
        choice = _validated_file_choice(state, entry)
        choice === nothing || push!(choices, choice)
    end
    isempty(choices) && return FileChoice[]
    state.choices = choices
    return copy(state.choices)
end

function choose_current_directory!(state::FileBrowserState)
    empty!(state.choices)
    state.mode in (SelectDirectoryMode, SelectMultipleMode) || return FileChoice[]
    current = try
        _canonical_existing_directory(state.current_path)
    catch error
        push!(state.diagnostics, FileBrowserDiagnostic(state.current_path, :choose, (error, catch_backtrace())))
        return FileChoice[]
    end
    if !_within_root(state.root, current)
        error = ArgumentError("current directory escaped the file-browser root")
        push!(state.diagnostics, FileBrowserDiagnostic(current, :choose, (error, nothing)))
        return FileChoice[]
    end
    choice = FileChoice(current, DirectoryFileEntry)
    state.choices = FileChoice[choice]
    return copy(state.choices)
end

file_choices(state::FileBrowserState) = copy(state.choices)

navigate_file_browser!(state::FileBrowserState, path::AbstractString) =
    _navigate!(state, path)

function file_path_breadcrumbs(state::FileBrowserState)
    root_label = _safe_file_label(isempty(basename(state.root)) ? state.root : basename(state.root))
    items = BreadcrumbItem{String}[BreadcrumbItem(root_label, state.root)]
    relative = relpath(state.current_path, state.root)
    relative == "." && return items
    path = state.root
    for component in split(replace(relative, '\\' => '/'), '/'; keepempty=false)
        path = joinpath(path, component)
        push!(items, BreadcrumbItem(_safe_file_label(component), path))
    end
    return items
end

function _human_size(size::Union{Nothing,Int64})
    size === nothing && return ""
    value = Float64(size)
    units = ("B", "KB", "MB", "GB", "TB")
    unit = 1
    while value >= 1024 && unit < length(units)
        value /= 1024
        unit += 1
    end
    return unit == 1 ? "$(size) B" : "$(round(value; digits=1)) $(units[unit])"
end

function _clip_file_text(value::AbstractString, width::Int)
    width <= 0 && return ""
    textwidth(value) <= width && return String(value)
    width == 1 && return "~"
    output = IOBuffer()
    used = 0
    for grapheme in graphemes(value)
        grapheme_width = max(1, textwidth(grapheme))
        used + grapheme_width > width - 1 && break
        print(output, grapheme)
        used += grapheme_width
    end
    print(output, '~')
    return String(take!(output))
end

function render_file_browser(
    state::FileBrowserState;
    width::Integer=80,
    height::Integer=24,
    first_entry::Integer=1,
)
    width > 0 || throw(ArgumentError("file-browser width must be positive"))
    height >= 0 || throw(ArgumentError("file-browser height cannot be negative"))
    first_entry > 0 || throw(ArgumentError("first file-browser entry must be positive"))
    lines = RichLine[]
    for index in Int(first_entry):min(length(state.entries), Int(first_entry) + Int(height) - 1)
        entry = state.entries[index]
        cursor = state.cursor == index ? ">" : " "
        selected = entry.path in state.selected ? "*" : " "
        kind = entry.kind == DirectoryFileEntry ? "d" : entry.kind == SymbolicLinkFileEntry ? "l" : entry.kind == RegularFileEntry ? "f" : "?"
        suffix = entry.kind == DirectoryFileEntry ? "/" : ""
        size = _human_size(entry.size)
        text = "$cursor$selected $kind $(_safe_file_label(entry.name))$suffix"
        isempty(size) || (text *= "  $size")
        text = _clip_file_text(text, Int(width))
        role = entry.path in state.selected ? :file_selected : state.cursor == index ? :file_cursor :
               entry.kind == DirectoryFileEntry ? :file_directory : :file_entry
        push!(lines, RichLine(RichSpan[RichSpan(text, role, nothing)], role, nothing))
    end
    return lines
end

function file_browser_semantic_tree(
    state::FileBrowserState;
    id="file-browser",
    label::AbstractString="File browser",
    origin_row::Integer=1,
    origin_column::Integer=1,
    width::Integer=1,
)
    children = SemanticNode[]
    for (index, entry) in enumerate(state.entries)
        actions = entry.kind == DirectoryFileEntry ?
            [SelectSemanticAction, ActivateSemanticAction, ExpandSemanticAction] :
            [SelectSemanticAction, ActivateSemanticAction]
        push!(children, SemanticNode(
            "$(id)/entry-$index",
            TreeItemRole;
            label=_safe_file_label(entry.name),
            description=entry.kind == DirectoryFileEntry ? "directory" : "file",
            bounds=SemanticRect(origin_row + index - 1, origin_column, width, 1),
            state=SemanticState(
                focusable=true,
                focused=state.cursor == index,
                selected=entry.path in state.selected,
                expanded=entry.kind == DirectoryFileEntry ? false : nothing,
            ),
            actions=actions,
        ))
    end
    return SemanticTree(SemanticNode(
        id,
        TreeRole;
        label=label,
        bounds=SemanticRect(origin_row, origin_column, width, length(children)),
        state=SemanticState(busy=state.loading),
        children=children,
    ); generation=state.generation)
end

struct FileScanCompletion
    generation::UInt64
    path::String
    result::DirectoryReadResult
end

mutable struct FileBrowserController
    state::FileBrowserState
    active_generation::UInt64
    completions::Channel{FileScanCompletion}
    tasks::Dict{Task,UInt64}
    max_inflight::Int
    pending_request::Bool
    mutex::ReentrantLock
end

function FileBrowserController(state::FileBrowserState; max_inflight::Integer=1)
    max_inflight > 0 || throw(ArgumentError("maximum file scans must be positive"))
    return FileBrowserController(
        state,
        state.generation,
        Channel{FileScanCompletion}(max(8, Int(max_inflight) * 2)),
        Dict{Task,UInt64}(),
        Int(max_inflight),
        false,
        ReentrantLock(),
    )
end

function _launch_file_scan!(controller::FileBrowserController, generation::UInt64)
    path = controller.state.current_path
    show_hidden = controller.state.show_hidden
    maximum_entries = controller.state.maximum_entries
    task = @async begin
        result = read_directory_entries(
            path;
            show_hidden=show_hidden,
            maximum_entries,
        )
        put!(controller.completions, FileScanCompletion(generation, path, result))
    end
    controller.tasks[task] = generation
    return task
end

function request_file_refresh!(controller::FileBrowserController)
    return lock(controller.mutex) do
        base_generation = max(controller.active_generation, controller.state.generation)
        base_generation == typemax(UInt64) && throw(OverflowError("file scan generation overflow"))
        controller.active_generation = base_generation + 1
        generation = controller.active_generation
        controller.state.loading = true
        if length(controller.tasks) < controller.max_inflight
            _launch_file_scan!(controller, generation)
        else
            controller.pending_request = true
        end
        return generation
    end
end

function poll_file_refresh!(controller::FileBrowserController; limit::Integer=typemax(Int))
    limit >= 0 || throw(ArgumentError("file refresh poll limit cannot be negative"))
    applied = 0
    while applied < limit && isready(controller.completions)
        completion = take!(controller.completions)
        lock(controller.mutex) do
            for (task, generation) in collect(controller.tasks)
                generation == completion.generation && delete!(controller.tasks, task)
            end
            if completion.generation == controller.active_generation &&
               completion.generation >= controller.state.generation &&
               completion.path == controller.state.current_path
                controller.state.generation = completion.generation
                _apply_directory_result!(controller.state, completion.result)
                applied += 1
            end
            if controller.pending_request && length(controller.tasks) < controller.max_inflight
                controller.pending_request = false
                _launch_file_scan!(controller, controller.active_generation)
            end
        end
    end
    return applied
end

function cancel_file_refresh!(controller::FileBrowserController)
    lock(controller.mutex) do
        controller.active_generation == typemax(UInt64) && throw(OverflowError("file scan generation overflow"))
        controller.active_generation += 1
        controller.pending_request = false
        controller.state.loading = false
    end
    return controller
end

end
