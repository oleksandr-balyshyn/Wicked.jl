module FileBrowserInput

using ..RichAdapters: KeyChord
using ..FileBrowser: FileBrowserState,
                     FileChoice,
                     move_file_cursor!,
                     set_file_cursor!,
                     current_file_entry,
                     enter_file_entry!,
                     leave_file_directory!,
                     toggle_file_selection!,
                     choose_file_entry!,
                     choose_current_directory!,
                     refresh_file_browser!

export FileBrowserAction,
       FileCursorUp,
       FileCursorDown,
       FilePageUp,
       FilePageDown,
       FileCursorHome,
       FileCursorEnd,
       FileActivate,
       FileParentDirectory,
       FileToggleSelection,
       FileChoose,
       FileChooseCurrentDirectory,
       FileRefresh,
       FileToggleHidden,
       FileBrowserBindings,
       bind_file_browser_key!,
       unbind_file_browser_key!,
       default_file_browser_bindings,
       file_browser_action_for_key,
       FileBrowserActionResult,
       handle_file_browser_key!,
       FilePointerKind,
       FilePointerHover,
       FilePointerPress,
       FilePointerDoublePress,
       FilePointerEvent,
       handle_file_browser_pointer!

@enum FileBrowserAction begin
    FileCursorUp
    FileCursorDown
    FilePageUp
    FilePageDown
    FileCursorHome
    FileCursorEnd
    FileActivate
    FileParentDirectory
    FileToggleSelection
    FileChoose
    FileChooseCurrentDirectory
    FileRefresh
    FileToggleHidden
end

mutable struct FileBrowserBindings
    actions::Dict{KeyChord,FileBrowserAction}
end

FileBrowserBindings() = FileBrowserBindings(Dict{KeyChord,FileBrowserAction}())

function bind_file_browser_key!(
    bindings::FileBrowserBindings,
    chord::KeyChord,
    action::FileBrowserAction,
)
    bindings.actions[chord] = action
    return bindings
end

function bind_file_browser_key!(bindings::FileBrowserBindings, key, action::FileBrowserAction; modifiers...)
    return bind_file_browser_key!(bindings, KeyChord(key; modifiers...), action)
end

function unbind_file_browser_key!(bindings::FileBrowserBindings, chord::KeyChord)
    pop!(bindings.actions, chord, nothing)
    return bindings
end

function default_file_browser_bindings(; vim::Bool=false)
    bindings = FileBrowserBindings()
    bind_file_browser_key!(bindings, :up, FileCursorUp)
    bind_file_browser_key!(bindings, :down, FileCursorDown)
    bind_file_browser_key!(bindings, :pageup, FilePageUp)
    bind_file_browser_key!(bindings, :pagedown, FilePageDown)
    bind_file_browser_key!(bindings, :home, FileCursorHome)
    bind_file_browser_key!(bindings, :end, FileCursorEnd)
    bind_file_browser_key!(bindings, :enter, FileActivate)
    bind_file_browser_key!(bindings, :backspace, FileParentDirectory)
    bind_file_browser_key!(bindings, :space, FileToggleSelection)
    bind_file_browser_key!(bindings, :enter, FileChoose; control=true)
    bind_file_browser_key!(bindings, :enter, FileChooseCurrentDirectory; control=true, shift=true)
    bind_file_browser_key!(bindings, :r, FileRefresh; control=true)
    bind_file_browser_key!(bindings, :h, FileToggleHidden; control=true)
    if vim
        bind_file_browser_key!(bindings, :k, FileCursorUp)
        bind_file_browser_key!(bindings, :j, FileCursorDown)
        bind_file_browser_key!(bindings, :g, FileCursorHome)
        bind_file_browser_key!(bindings, :g, FileCursorEnd; shift=true)
        bind_file_browser_key!(bindings, :l, FileActivate)
        bind_file_browser_key!(bindings, :h, FileParentDirectory)
    end
    return bindings
end

function file_browser_action_for_key(
    bindings::FileBrowserBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    return get(
        bindings.actions,
        KeyChord(key; control=control, alt=alt, shift=shift),
        nothing,
    )
end

struct FileBrowserActionResult
    consumed::Bool
    action::Union{Nothing,FileBrowserAction}
    navigated::Bool
    choices::Vector{FileChoice}
end

function handle_file_browser_key!(
    state::FileBrowserState,
    bindings::FileBrowserBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
    viewport_height::Integer=20,
)
    action = file_browser_action_for_key(bindings, key; control=control, alt=alt, shift=shift)
    action === nothing && return FileBrowserActionResult(false, nothing, false, FileChoice[])
    navigated = false
    choices = FileChoice[]
    if action == FileCursorUp
        move_file_cursor!(state, -1)
    elseif action == FileCursorDown
        move_file_cursor!(state, 1)
    elseif action == FilePageUp
        move_file_cursor!(state, -max(1, Int(viewport_height) - 1))
    elseif action == FilePageDown
        move_file_cursor!(state, max(1, Int(viewport_height) - 1))
    elseif action == FileCursorHome
        set_file_cursor!(state, 1)
    elseif action == FileCursorEnd
        set_file_cursor!(state, length(state.entries))
    elseif action == FileActivate
        navigated = enter_file_entry!(state)
        navigated || (choices = choose_file_entry!(state))
    elseif action == FileParentDirectory
        navigated = leave_file_directory!(state)
    elseif action == FileToggleSelection
        toggle_file_selection!(state)
    elseif action == FileChoose
        choices = choose_file_entry!(state)
    elseif action == FileChooseCurrentDirectory
        choices = choose_current_directory!(state)
    elseif action == FileRefresh
        refresh_file_browser!(state)
    elseif action == FileToggleHidden
        state.show_hidden = !state.show_hidden
        refresh_file_browser!(state)
    end
    return FileBrowserActionResult(true, action, navigated, choices)
end

@enum FilePointerKind begin
    FilePointerHover
    FilePointerPress
    FilePointerDoublePress
end

struct FilePointerEvent
    kind::FilePointerKind
    row::Int
    column::Int
    control::Bool

    function FilePointerEvent(
        kind::FilePointerKind,
        row::Integer,
        column::Integer;
        control::Bool=false,
    )
        row > 0 || throw(ArgumentError("file pointer row must be positive"))
        column > 0 || throw(ArgumentError("file pointer column must be positive"))
        new(kind, Int(row), Int(column), control)
    end
end

function handle_file_browser_pointer!(
    state::FileBrowserState,
    event::FilePointerEvent;
    first_entry::Integer=1,
    focus_on_hover::Bool=true,
    select_on_press::Bool=true,
)
    first_entry > 0 || throw(ArgumentError("first file entry must be positive"))
    index = Int(first_entry) + event.row - 1
    1 <= index <= length(state.entries) ||
        return FileBrowserActionResult(false, nothing, false, FileChoice[])
    if event.kind == FilePointerHover
        focus_on_hover || return FileBrowserActionResult(false, nothing, false, FileChoice[])
        set_file_cursor!(state, index)
        return FileBrowserActionResult(true, nothing, false, FileChoice[])
    elseif event.kind == FilePointerPress
        set_file_cursor!(state, index)
        select_on_press && toggle_file_selection!(state)
        return FileBrowserActionResult(true, FileToggleSelection, false, FileChoice[])
    else
        set_file_cursor!(state, index)
        navigated = enter_file_entry!(state)
        choices = navigated ? FileChoice[] : choose_file_entry!(state)
        return FileBrowserActionResult(true, FileActivate, navigated, choices)
    end
end

end
