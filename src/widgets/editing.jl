struct EditSnapshot
    graphemes::Vector{String}
    cursor::Int
    anchor::Union{Nothing,Int}
end

"""Unicode-grapheme editing state shared by all text input widgets."""
mutable struct EditingBuffer
    graphemes::Vector{String}
    cursor::Int
    anchor::Union{Nothing,Int}
    undo_stack::Vector{EditSnapshot}
    redo_stack::Vector{EditSnapshot}
    history_limit::Int

    function EditingBuffer(text::AbstractString=""; history_limit::Integer=100)
        history_limit >= 0 || throw(ArgumentError("history limit must be non-negative"))
        values = String[String(value) for value in Unicode.graphemes(text)]
        new(values, length(values), nothing, EditSnapshot[], EditSnapshot[], Int(history_limit))
    end
end

editing_text(buffer::EditingBuffer) = join(buffer.graphemes)
Base.length(buffer::EditingBuffer) = length(buffer.graphemes)
Base.isempty(buffer::EditingBuffer) = isempty(buffer.graphemes)

function _snapshot(buffer::EditingBuffer)
    EditSnapshot(copy(buffer.graphemes), buffer.cursor, buffer.anchor)
end

function _restore!(buffer::EditingBuffer, snapshot::EditSnapshot)
    buffer.graphemes = copy(snapshot.graphemes)
    buffer.cursor = snapshot.cursor
    buffer.anchor = snapshot.anchor
    buffer
end

function _record!(buffer::EditingBuffer)
    buffer.history_limit == 0 && return
    push!(buffer.undo_stack, _snapshot(buffer))
    length(buffer.undo_stack) > buffer.history_limit && popfirst!(buffer.undo_stack)
    empty!(buffer.redo_stack)
    nothing
end

function _selection(buffer::EditingBuffer)
    isnothing(buffer.anchor) && return nothing
    buffer.anchor == buffer.cursor && return nothing
    min(buffer.anchor, buffer.cursor) + 1:max(buffer.anchor, buffer.cursor)
end

"""Clear the active selection without changing the cursor."""
function clear_selection!(buffer::EditingBuffer)
    buffer.anchor = nothing
    buffer
end

"""Select all content."""
function select_all!(buffer::EditingBuffer)
    buffer.anchor = 0
    buffer.cursor = length(buffer)
    buffer
end

function _delete_selection!(buffer::EditingBuffer)
    selected = _selection(buffer)
    isnothing(selected) && return false
    first_index = first(selected)
    deleteat!(buffer.graphemes, selected)
    buffer.cursor = first_index - 1
    buffer.anchor = nothing
    true
end

"""Replace the complete buffer contents."""
function set_text!(buffer::EditingBuffer, text::AbstractString; record::Bool=true)
    record && _record!(buffer)
    buffer.graphemes = String[String(value) for value in Unicode.graphemes(text)]
    buffer.cursor = length(buffer)
    buffer.anchor = nothing
    buffer
end

"""Insert text at the cursor, replacing the active selection."""
function insert!(buffer::EditingBuffer, text::AbstractString; maximum_length::Integer=typemax(Int))
    maximum_length >= 0 || throw(ArgumentError("maximum length must be non-negative"))
    values = String[String(value) for value in Unicode.graphemes(text)]
    selected = _selection(buffer)
    selected_count = isnothing(selected) ? 0 : length(selected)
    room = max(0, Int(maximum_length) - (length(buffer) - selected_count))
    length(values) > room && resize!(values, room)
    isempty(values) && selected_count == 0 && return false
    _record!(buffer)
    _delete_selection!(buffer)
    insert_position = buffer.cursor + 1
    splice!(buffer.graphemes, insert_position:(insert_position - 1), values)
    buffer.cursor += length(values)
    buffer.anchor = nothing
    true
end

"""Delete the selection or the grapheme before the cursor."""
function backspace!(buffer::EditingBuffer)
    isnothing(_selection(buffer)) && buffer.cursor == 0 && return false
    _record!(buffer)
    _delete_selection!(buffer) && return true
    deleteat!(buffer.graphemes, buffer.cursor)
    buffer.cursor -= 1
    true
end

"""Delete the selection or the grapheme after the cursor."""
function delete_forward!(buffer::EditingBuffer)
    isnothing(_selection(buffer)) && buffer.cursor == length(buffer) && return false
    _record!(buffer)
    _delete_selection!(buffer) && return true
    deleteat!(buffer.graphemes, buffer.cursor + 1)
    true
end

"""Move the cursor to a grapheme boundary and optionally extend selection."""
function move_cursor!(buffer::EditingBuffer, position::Integer; extend::Bool=false)
    target = clamp(Int(position), 0, length(buffer))
    extend && isnothing(buffer.anchor) && (buffer.anchor = buffer.cursor)
    !extend && (buffer.anchor = nothing)
    changed = target != buffer.cursor
    buffer.cursor = target
    changed
end

function _word_left(buffer::EditingBuffer)
    position = buffer.cursor
    while position > 0 && all(isspace, buffer.graphemes[position])
        position -= 1
    end
    while position > 0 && !all(isspace, buffer.graphemes[position])
        position -= 1
    end
    position
end

function _word_right(buffer::EditingBuffer)
    position = buffer.cursor
    while position < length(buffer) && all(isspace, buffer.graphemes[position + 1])
        position += 1
    end
    while position < length(buffer) && !all(isspace, buffer.graphemes[position + 1])
        position += 1
    end
    position
end

function _line_start(buffer::EditingBuffer, position::Int=buffer.cursor)
    index = position
    while index > 0 && buffer.graphemes[index] != "\n"
        index -= 1
    end
    index
end

function _line_end(buffer::EditingBuffer, position::Int=buffer.cursor)
    index = position
    while index < length(buffer) && buffer.graphemes[index + 1] != "\n"
        index += 1
    end
    index
end

function _move_vertical!(buffer::EditingBuffer, direction::Int; extend::Bool=false)
    start = _line_start(buffer)
    column = buffer.cursor - start
    if direction < 0
        start == 0 && return false
        previous_end = start - 1
        previous_start = _line_start(buffer, previous_end)
        move_cursor!(buffer, min(previous_start + column, previous_end); extend)
    else
        ending = _line_end(buffer)
        ending == length(buffer) && return false
        next_start = ending + 1
        next_end = _line_end(buffer, next_start)
        move_cursor!(buffer, min(next_start + column, next_end); extend)
    end
end

"""Restore the previous editing snapshot."""
function undo!(buffer::EditingBuffer)
    isempty(buffer.undo_stack) && return false
    push!(buffer.redo_stack, _snapshot(buffer))
    _restore!(buffer, pop!(buffer.undo_stack))
    true
end

"""Reapply the next editing snapshot."""
function redo!(buffer::EditingBuffer)
    isempty(buffer.redo_stack) && return false
    push!(buffer.undo_stack, _snapshot(buffer))
    _restore!(buffer, pop!(buffer.redo_stack))
    true
end

function _handle_editing!(
    buffer::EditingBuffer,
    event::KeyEvent;
    multiline::Bool,
    maximum_length::Int,
)
    event.kind in (KeyPress, KeyRepeat) || return false
    extend = SHIFT in event.modifiers
    control = CTRL in event.modifiers
    if event.key.code == :character && control
        lowered = lowercase(event.text)
        lowered == "a" && (select_all!(buffer); return true)
        lowered == "z" && return undo!(buffer)
        lowered == "y" && return redo!(buffer)
        return false
    elseif event.key.code == :character && !isempty(event.text)
        text = multiline ? event.text :
            replace(event.text, "\r\n" => " ", '\r' => ' ', '\n' => ' ')
        return insert!(buffer, text; maximum_length)
    elseif event.key.code == :left
        target = control ? _word_left(buffer) : buffer.cursor - 1
        return move_cursor!(buffer, target; extend)
    elseif event.key.code == :right
        target = control ? _word_right(buffer) : buffer.cursor + 1
        return move_cursor!(buffer, target; extend)
    elseif event.key.code == :home
        return move_cursor!(buffer, multiline ? _line_start(buffer) : 0; extend)
    elseif event.key.code == :end
        return move_cursor!(buffer, multiline ? _line_end(buffer) : length(buffer); extend)
    elseif event.key.code == :up && multiline
        return _move_vertical!(buffer, -1; extend)
    elseif event.key.code == :down && multiline
        return _move_vertical!(buffer, 1; extend)
    elseif event.key.code == :backspace
        return backspace!(buffer)
    elseif event.key.code == :delete
        return delete_forward!(buffer)
    elseif event.key.code == :enter && multiline
        return insert!(buffer, "\n"; maximum_length)
    end
    false
end
