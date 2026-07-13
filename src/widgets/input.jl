"""Externally owned state for a single-line text input."""
mutable struct TextInputState
    editing::EditingBuffer
    horizontal_offset::Int
    focused::Bool
end

_single_line_text(text::AbstractString) =
    replace(String(text), "\r\n" => " ", '\r' => ' ', '\n' => ' ')

TextInputState(text::AbstractString=""; focused::Bool=false, history_limit::Integer=100) =
    TextInputState(EditingBuffer(_single_line_text(text); history_limit), 0, focused)

editing_text(state::TextInputState) = editing_text(state.editing)

function set_text!(state::TextInputState, text::AbstractString; record::Bool=true)
    set_text!(state.editing, _single_line_text(text); record)
    state.horizontal_offset = 0
    return state
end

"""A Unicode-aware single-line editor."""
struct TextInput
    placeholder::String
    block::Union{Nothing,Block}
    style::Style
    placeholder_style::Style
    selection_style::Style
    cursor_style::Style
    mask::Union{Nothing,String}
    maximum_length::Int
end

state_for(::TextInput) = TextInputState()

function TextInput(;
    placeholder::AbstractString="",
    block::Union{Nothing,Block}=nothing,
    style::Style=Style(),
    placeholder_style::Style=Style(modifiers=DIM),
    selection_style::Style=Style(modifiers=REVERSED),
    cursor_style::Style=Style(modifiers=REVERSED),
    mask::Union{Nothing,AbstractString}=nothing,
    maximum_length::Integer=typemax(Int),
)
    maximum_length >= 0 || throw(ArgumentError("maximum input length must be non-negative"))
    resolved_mask = isnothing(mask) ? nothing : String(mask)
    !isnothing(resolved_mask) && grapheme_width(DEFAULT_WIDTH_POLICY, resolved_mask) != 1 &&
        throw(ArgumentError("input mask must occupy one terminal column"))
    TextInput(
        String(placeholder),
        block,
        style,
        placeholder_style,
        selection_style,
        cursor_style,
        resolved_mask,
        Int(maximum_length),
    )
end

"""
    Input(; kwargs...)

Textual-style single-line input backed by `TextInput` and `TextInputState`.

`Input` is a stable compatibility name for applications porting Textual-style
forms. It intentionally shares `InputState` with `TextInputState` so editing,
cursor, selection, paste, pointer, and semantic behavior stay identical.
"""
struct Input
    input::TextInput
end

"""Compatibility state alias for `Input`; identical to `TextInputState`."""
const InputState = TextInputState

Input(; kwargs...) = Input(TextInput(; kwargs...))

state_for(widget::Input) = state_for(widget.input)

render!(buffer::Buffer, widget::Input, area::Rect, state::InputState) =
    render!(buffer, widget.input, area, state)

render!(buffer::Buffer, widget::Input, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::Input, area::Rect, state::InputState)
    render!(frame, widget.input, area, state)
end

handle!(state::InputState, widget::Input, event::KeyEvent) =
    handle!(state, widget.input, event)

handle!(state::InputState, widget::Input, event::PasteEvent) =
    handle!(state, widget.input, event)

handle!(state::InputState, widget::Input, event::MouseEvent, area::Rect) =
    handle!(state, widget.input, event, area)

"""
    TextBox(; kwargs...)

Lanterna-style single-line text box backed by `TextInput`.

`TextBox` is a stable compatibility name for applications porting conservative
retained-mode TUI code. It intentionally shares `TextBoxState` with
`TextInputState` so editing, cursor, selection, paste, pointer, and semantic
behavior stay identical to `TextInput`.
"""
struct TextBox
    input::TextInput
end

"""Compatibility state alias for `TextBox`; identical to `TextInputState`."""
const TextBoxState = TextInputState

TextBox(; kwargs...) = TextBox(TextInput(; kwargs...))

state_for(widget::TextBox) = state_for(widget.input)

render!(buffer::Buffer, widget::TextBox, area::Rect, state::TextBoxState) =
    render!(buffer, widget.input, area, state)

render!(buffer::Buffer, widget::TextBox, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::TextBox, area::Rect, state::TextBoxState)
    render!(frame, widget.input, area, state)
end

handle!(state::TextBoxState, widget::TextBox, event::KeyEvent) =
    handle!(state, widget.input, event)

handle!(state::TextBoxState, widget::TextBox, event::PasteEvent) =
    handle!(state, widget.input, event)

handle!(state::TextBoxState, widget::TextBox, event::MouseEvent, area::Rect) =
    handle!(state, widget.input, event, area)

"""
    TextField(; kwargs...)

Generic single-line text-field compatibility widget backed by `TextInput`.

`TextField` shares `TextFieldState` with `TextInputState`, so editing, cursor,
selection, paste, pointer, and semantic behavior stay identical to `TextInput`.
"""
struct TextField
    input::TextInput
end

"""Compatibility state alias for `TextField`; identical to `TextInputState`."""
const TextFieldState = TextInputState

TextField(; kwargs...) = TextField(TextInput(; kwargs...))

state_for(widget::TextField) = state_for(widget.input)

render!(buffer::Buffer, widget::TextField, area::Rect, state::TextFieldState) =
    render!(buffer, widget.input, area, state)

render!(buffer::Buffer, widget::TextField, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::TextField, area::Rect, state::TextFieldState)
    render!(frame, widget.input, area, state)
end

handle!(state::TextFieldState, widget::TextField, event::KeyEvent) =
    handle!(state, widget.input, event)

handle!(state::TextFieldState, widget::TextField, event::PasteEvent) =
    handle!(state, widget.input, event)

handle!(state::TextFieldState, widget::TextField, event::MouseEvent, area::Rect) =
    handle!(state, widget.input, event, area)

"""Masked single-line password entry backed by the text-input editor."""
struct PasswordInput
    input::TextInput
end

PasswordInput(; mask::AbstractString="•", kwargs...) =
    PasswordInput(TextInput(; mask, kwargs...))

state_for(widget::PasswordInput) = state_for(widget.input)

render!(buffer::Buffer, widget::PasswordInput, area::Rect, state::TextInputState) =
    render!(buffer, widget.input, area, state)

render!(buffer::Buffer, widget::PasswordInput, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::PasswordInput, area::Rect, state::TextInputState)
    render!(frame, widget.input, area, state)
end

handle!(state::TextInputState, widget::PasswordInput, event::KeyEvent) =
    handle!(state, widget.input, event)

handle!(state::TextInputState, widget::PasswordInput, event::PasteEvent) =
    handle!(state, widget.input, event)

handle!(state::TextInputState, widget::PasswordInput, event::MouseEvent, area::Rect) =
    handle!(state, widget.input, event, area)

"""
    PasswordField(; kwargs...)

Generic masked password-field compatibility widget backed by `PasswordInput`.

`PasswordField` shares `PasswordFieldState` with `TextInputState`, so editing,
cursor, selection, paste, pointer, mask rendering, and protected semantic
behavior stay identical to `PasswordInput`.
"""
struct PasswordField
    input::PasswordInput
end

"""Compatibility state alias for `PasswordField`; identical to `TextInputState`."""
const PasswordFieldState = TextInputState

PasswordField(; kwargs...) = PasswordField(PasswordInput(; kwargs...))

state_for(widget::PasswordField) = state_for(widget.input)

render!(buffer::Buffer, widget::PasswordField, area::Rect, state::PasswordFieldState) =
    render!(buffer, widget.input, area, state)

render!(buffer::Buffer, widget::PasswordField, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::PasswordField, area::Rect, state::PasswordFieldState)
    render!(frame, widget.input, area, state)
end

handle!(state::PasswordFieldState, widget::PasswordField, event::KeyEvent) =
    handle!(state, widget.input, event)

handle!(state::PasswordFieldState, widget::PasswordField, event::PasteEvent) =
    handle!(state, widget.input, event)

handle!(state::PasswordFieldState, widget::PasswordField, event::MouseEvent, area::Rect) =
    handle!(state, widget.input, event, area)

"""Focused single-line query entry backed by the text-input editor."""
struct SearchInput
    input::TextInput
end

SearchInput(; kwargs...) = SearchInput(TextInput(; kwargs...))

state_for(widget::SearchInput) = state_for(widget.input)

render!(buffer::Buffer, widget::SearchInput, area::Rect, state::TextInputState) =
    render!(buffer, widget.input, area, state)

render!(buffer::Buffer, widget::SearchInput, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::SearchInput, area::Rect, state::TextInputState)
    render!(frame, widget.input, area, state)
end

handle!(state::TextInputState, widget::SearchInput, event::KeyEvent) =
    handle!(state, widget.input, event)

handle!(state::TextInputState, widget::SearchInput, event::PasteEvent) =
    handle!(state, widget.input, event)

handle!(state::TextInputState, widget::SearchInput, event::MouseEvent, area::Rect) =
    handle!(state, widget.input, event, area)

const SearchInputState = TextInputState

"""Externally owned state for a single-line numeric input."""
mutable struct NumberInputState
    editing::EditingBuffer
    horizontal_offset::Int
    focused::Bool
    minimum::Union{Nothing,Float64}
    maximum::Union{Nothing,Float64}
    step::Float64
    allow_empty::Bool
    value::Union{Nothing,Float64}
    valid::Bool
    error::Union{Nothing,String}
end

function NumberInputState(;
    value::Union{Nothing,Real}=nothing,
    minimum::Union{Nothing,Real}=nothing,
    maximum::Union{Nothing,Real}=nothing,
    step::Real=1,
    allow_empty::Bool=true,
    history_limit::Integer=100,
)
    minimum !== nothing && !isfinite(minimum) &&
        throw(ArgumentError("numeric minimum must be finite"))
    maximum !== nothing && !isfinite(maximum) &&
        throw(ArgumentError("numeric maximum must be finite"))
    minimum !== nothing && maximum !== nothing && minimum > maximum &&
        throw(ArgumentError("numeric minimum exceeds maximum"))
    isfinite(step) && step > 0 || throw(ArgumentError("numeric step must be finite and positive"))
    state = NumberInputState(
        EditingBuffer(value === nothing ? "" : _single_line_text(string(value)); history_limit),
        0,
        false,
        minimum === nothing ? nothing : Float64(minimum),
        maximum === nothing ? nothing : Float64(maximum),
        Float64(step),
        allow_empty,
        nothing,
        false,
        nothing,
    )
    _sync_number_state!(state)
    return state
end

editing_text(state::NumberInputState) = editing_text(state.editing)

function _sync_number_state!(state::NumberInputState)
    value_text = strip(editing_text(state.editing))
    if isempty(value_text)
        state.value = nothing
        state.valid = state.allow_empty
        state.error = state.valid ? nothing : "a value is required"
        return state.valid
    end
    parsed = tryparse(Float64, value_text)
    if parsed === nothing || !isfinite(parsed)
        state.value = nothing
        state.valid = false
        state.error = "invalid numeric value"
        return false
    end
    if state.minimum !== nothing && parsed < state.minimum
        state.value = nothing
        state.valid = false
        state.error = "value is below the minimum"
        return false
    elseif state.maximum !== nothing && parsed > state.maximum
        state.value = nothing
        state.valid = false
        state.error = "value is above the maximum"
        return false
    end
    state.value = parsed
    state.valid = true
    state.error = nothing
    return true
end

"""Return whether the current numeric input text parses and satisfies bounds."""
number_input_valid(state::NumberInputState) = state.valid

"""Return the committed numeric value, or `nothing` when empty or invalid."""
number_input_value(state::NumberInputState) = state.value

"""Replace the edited numeric text and refresh validity, value, and error state."""
function set_number_text!(state::NumberInputState, text::AbstractString)
    set_text!(state.editing, text)
    state.horizontal_offset = 0
    _sync_number_state!(state)
    return state
end

"""Replace the numeric value and refresh the visible text."""
function set_number_value!(state::NumberInputState, value::Union{Nothing,Real})
    state_text = value === nothing ? "" : string(value)
    set_text!(state.editing, state_text)
    state.horizontal_offset = 0
    _sync_number_state!(state)
    return state
end

"""Increment the numeric value by `steps * state.step`, clamped to configured bounds."""
function increment_number_input!(state::NumberInputState, steps::Integer=1)
    base = something(state.value, state.minimum, 0.0)
    next_value = base + Float64(steps) * state.step
    if state.minimum !== nothing
        next_value = max(next_value, state.minimum)
    end
    if state.maximum !== nothing
        next_value = min(next_value, state.maximum)
    end
    set_number_text!(state, string(next_value))
    return state
end

"""A Unicode-aware single-line numeric editor."""
struct NumberInput
    placeholder::String
    block::Union{Nothing,Block}
    style::Style
    placeholder_style::Style
    selection_style::Style
    cursor_style::Style
    maximum_length::Int
end

function NumberInput(;
    placeholder::AbstractString="",
    block::Union{Nothing,Block}=nothing,
    style::Style=Style(),
    placeholder_style::Style=Style(modifiers=DIM),
    selection_style::Style=Style(modifiers=REVERSED),
    cursor_style::Style=Style(modifiers=REVERSED),
    maximum_length::Integer=typemax(Int),
)
    maximum_length >= 0 || throw(ArgumentError("maximum input length must be non-negative"))
    NumberInput(
        String(placeholder),
        block,
        style,
        placeholder_style,
        selection_style,
        cursor_style,
        Int(maximum_length),
    )
end

"""Compatibility constructor for applications expecting `NumericInput` naming.

`NumericInput` is an alias for `NumberInput` with identical behavior and state
model. It keeps migration paths simple for frameworks with a `NumericInput`
constructor.
"""
NumericInput(; kwargs...) = NumberInput(; kwargs...)

state_for(::NumberInput) = NumberInputState()

function _number_input_area(buffer::Buffer, widget::NumberInput, area::Rect)
    if isnothing(widget.block)
        intersection(buffer.area, area)
    else
        render!(buffer, widget.block, area)
        intersection(buffer.area, inner(widget.block, area))
    end
end

function _number_input_cursor_offset(state::NumberInputState, width::Int)
    width <= 0 && return 0
    values = state.editing.graphemes
    cursor = state.editing.cursor
    state.horizontal_offset = min(state.horizontal_offset, cursor)
    function visible_width(start)
        sum(index -> grapheme_width(DEFAULT_WIDTH_POLICY, values[index]), (start + 1):cursor; init=0)
    end
    while state.horizontal_offset < cursor && visible_width(state.horizontal_offset) >= width
        state.horizontal_offset += 1
    end
    while state.horizontal_offset > 0 && visible_width(state.horizontal_offset - 1) < width
        state.horizontal_offset -= 1
    end
    visible_width(state.horizontal_offset)
end

function _render_number_input!(buffer::Buffer, widget::NumberInput, area::Rect, state::NumberInputState)
    active = _number_input_area(buffer, widget, area)
    isempty(active) && return nothing
    if isempty(state.editing)
        draw_text!(
            buffer,
            active.row,
            active.column,
            widget.placeholder;
            style=widget.placeholder_style,
            clip=active,
        )
        return Position(active.row, active.column)
    end
    cursor_offset = _number_input_cursor_offset(state, active.width)
    selected = _selection(state.editing)
    column = active.column
    for index in (state.horizontal_offset + 1):length(state.editing)
        source = state.editing.graphemes[index]
        source == "\n" && continue
        width = grapheme_width(DEFAULT_WIDTH_POLICY, source)
        column + width > active.column + active.width && break
        style = !isnothing(selected) && index in selected ? widget.selection_style : widget.style
        column = draw_grapheme!(buffer, active.row, column, source; style)
    end
    Position(active.row, min(active.column + active.width - 1, active.column + cursor_offset))
end

function render!(buffer::Buffer, widget::NumberInput, area::Rect, state::NumberInputState)
    _render_number_input!(buffer, widget, area, state)
    buffer
end

render!(buffer::Buffer, widget::NumberInput, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::NumberInput, area::Rect, state::NumberInputState)
    position = _render_number_input!(frame.buffer, widget, area, state)
    state.focused && !isnothing(position) && request_cursor!(frame, CursorRequest(position))
    frame.buffer
end

function handle!(state::NumberInputState, widget::NumberInput, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    steps = SHIFT in event.modifiers ? 10 : 1
    if event.key.code == :up
        return increment_number_input!(state, steps) === state
    elseif event.key.code == :down
        return increment_number_input!(state, -steps) === state
    end
    changed = _handle_editing!(
        state.editing,
        event;
        multiline=false,
        maximum_length=widget.maximum_length,
    )
    changed || return false
    state.horizontal_offset = min(state.horizontal_offset, state.editing.cursor)
    _sync_number_state!(state)
    return true
end

function handle!(state::NumberInputState, widget::NumberInput, event::PasteEvent)
    inserted = insert!(
        state.editing,
        _single_line_text(event.text);
        maximum_length=widget.maximum_length,
    )
    inserted || return false
    state.horizontal_offset = 0
    _sync_number_state!(state)
    return true
end

function handle!(
    state::NumberInputState,
    widget::NumberInput,
    event::MouseEvent,
    area::Rect,
)
    event.action == MousePress && event.button == LeftMouseButton || return false
    active = isnothing(widget.block) ? area : inner(widget.block, area)
    contains(active, event.position) || return false
    first_index = min(length(state.editing) + 1, state.horizontal_offset + 1)
    boundary = first_index > length(state.editing) ? length(state.editing) :
        _pointer_cursor_boundary(
            state.editing.graphemes,
            first_index,
            length(state.editing),
            event.position.column - active.column,
        )
    move_cursor!(state.editing, boundary)
    state.focused = true
    return true
end

function _input_area(buffer::Buffer, widget::TextInput, area::Rect)
    if isnothing(widget.block)
        intersection(buffer.area, area)
    else
        render!(buffer, widget.block, area)
        intersection(buffer.area, inner(widget.block, area))
    end
end

function _input_cursor_offset(state::TextInputState, width::Int, widget::TextInput)
    width <= 0 && return 0
    values = state.editing.graphemes
    cursor = state.editing.cursor
    state.horizontal_offset = min(state.horizontal_offset, cursor)
    function visible_width(start)
        sum(
            index -> grapheme_width(
                DEFAULT_WIDTH_POLICY,
                isnothing(widget.mask) ? values[index] : widget.mask,
            ),
            (start + 1):cursor;
            init=0,
        )
    end
    while state.horizontal_offset < cursor && visible_width(state.horizontal_offset) >= width
        state.horizontal_offset += 1
    end
    while state.horizontal_offset > 0 && visible_width(state.horizontal_offset - 1) < width
        state.horizontal_offset -= 1
    end
    visible_width(state.horizontal_offset)
end

function _render_text_input!(buffer::Buffer, widget::TextInput, area::Rect, state::TextInputState)
    active = _input_area(buffer, widget, area)
    isempty(active) && return nothing
    if isempty(state.editing)
        draw_text!(buffer, active.row, active.column, widget.placeholder; style=widget.placeholder_style, clip=active)
        return Position(active.row, active.column)
    end
    cursor_offset = _input_cursor_offset(state, active.width, widget)
    selected = _selection(state.editing)
    column = active.column
    for index in (state.horizontal_offset + 1):length(state.editing)
        source = state.editing.graphemes[index]
        source == "\n" && continue
        display = isnothing(widget.mask) ? source : widget.mask
        width = grapheme_width(DEFAULT_WIDTH_POLICY, display)
        column + width > active.column + active.width && break
        style = !isnothing(selected) && index in selected ? widget.selection_style : widget.style
        column = draw_grapheme!(buffer, active.row, column, display; style)
    end
    Position(active.row, min(active.column + active.width - 1, active.column + cursor_offset))
end

function render!(buffer::Buffer, widget::TextInput, area::Rect, state::TextInputState)
    _render_text_input!(buffer, widget, area, state)
    buffer
end

render!(buffer::Buffer, widget::TextInput, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::TextInput, area::Rect, state::TextInputState)
    position = _render_text_input!(frame.buffer, widget, area, state)
    state.focused && !isnothing(position) && request_cursor!(frame, CursorRequest(position))
    frame.buffer
end

handle!(state::TextInputState, widget::TextInput, event::KeyEvent) =
    _handle_editing!(
        state.editing,
        event;
        multiline=false,
        maximum_length=widget.maximum_length,
    )

handle!(state::TextInputState, widget::TextInput, event::PasteEvent) =
    insert!(
        state.editing,
        _single_line_text(event.text);
        maximum_length=widget.maximum_length,
    )

function _pointer_cursor_boundary(
    graphemes,
    first_index::Int,
    last_index::Int,
    target_column::Int;
    display_grapheme=identity,
)
    target_column <= 0 && return first_index - 1
    used = 0
    for index in first_index:last_index
        width = grapheme_width(DEFAULT_WIDTH_POLICY, display_grapheme(graphemes[index]))
        target_column < used + cld(width, 2) && return index - 1
        used += width
        target_column < used && return index
    end
    return last_index
end

function handle!(
    state::TextInputState,
    widget::TextInput,
    event::MouseEvent,
    area::Rect,
)
    event.action == MousePress && event.button == LeftMouseButton || return false
    active = isnothing(widget.block) ? area : inner(widget.block, area)
    contains(active, event.position) || return false
    first_index = min(length(state.editing) + 1, state.horizontal_offset + 1)
    display = isnothing(widget.mask) ? identity : _ -> widget.mask
    boundary = first_index > length(state.editing) ? length(state.editing) :
        _pointer_cursor_boundary(
            state.editing.graphemes,
            first_index,
            length(state.editing),
            event.position.column - active.column;
            display_grapheme=display,
        )
    move_cursor!(state.editing, boundary)
    state.focused = true
    return true
end

"""Externally owned state for a multi-line text area."""
mutable struct TextAreaState
    editing::EditingBuffer
    vertical_offset::Int
    horizontal_offset::Int
    focused::Bool
end

TextAreaState(text::AbstractString=""; focused::Bool=false, history_limit::Integer=100) =
    TextAreaState(EditingBuffer(text; history_limit), 0, 0, focused)

editing_text(state::TextAreaState) = editing_text(state.editing)

"""A Unicode-aware multi-line editor with line-number and scrolling support."""
struct TextArea
    block::Union{Nothing,Block}
    style::Style
    selection_style::Style
    line_number_style::Style
    show_line_numbers::Bool
    maximum_length::Int
end

state_for(::TextArea) = TextAreaState()

function TextArea(;
    block::Union{Nothing,Block}=nothing,
    style::Style=Style(),
    selection_style::Style=Style(modifiers=REVERSED),
    line_number_style::Style=Style(modifiers=DIM),
    show_line_numbers::Bool=false,
    maximum_length::Integer=typemax(Int),
)
    maximum_length >= 0 || throw(ArgumentError("maximum area length must be non-negative"))
    TextArea(
        block,
        style,
        selection_style,
        line_number_style,
        show_line_numbers,
        Int(maximum_length),
    )
end

function _area_content(buffer::Buffer, widget::TextArea, area::Rect)
    if isnothing(widget.block)
        intersection(buffer.area, area)
    else
        render!(buffer, widget.block, area)
        intersection(buffer.area, inner(widget.block, area))
    end
end

function _line_ranges(buffer::EditingBuffer)
    ranges = UnitRange{Int}[]
    start = 1
    for (index, grapheme) in enumerate(buffer.graphemes)
        if grapheme == "\n"
            push!(ranges, start:(index - 1))
            start = index + 1
        end
    end
    push!(ranges, start:length(buffer.graphemes))
    ranges
end

function _cursor_line_column(buffer::EditingBuffer, ranges)
    for (line_index, range) in enumerate(ranges)
        start_boundary = first(range) - 1
        end_boundary = isempty(range) ? start_boundary : last(range)
        buffer.cursor <= end_boundary && return line_index, buffer.cursor - start_boundary
    end
    length(ranges), 0
end

function _line_display_width(
    buffer::EditingBuffer,
    range::UnitRange{Int},
    first_offset::Int,
    last_offset::Int,
)
    last_offset <= first_offset && return 0
    first_index = first(range) + first_offset
    last_index = first(range) + last_offset - 1
    return sum(
        index -> grapheme_width(DEFAULT_WIDTH_POLICY, buffer.graphemes[index]),
        first_index:last_index;
        init=0,
    )
end

function _render_text_area!(buffer::Buffer, widget::TextArea, area::Rect, state::TextAreaState)
    active = _area_content(buffer, widget, area)
    isempty(active) && return nothing
    ranges = _line_ranges(state.editing)
    cursor_line, cursor_column = _cursor_line_column(state.editing, ranges)
    state.vertical_offset = clamp(
        state.vertical_offset,
        max(0, cursor_line - active.height),
        max(0, cursor_line - 1),
    )
    number_width = widget.show_line_numbers ? length(string(length(ranges))) + 1 : 0
    text_width_available = max(0, active.width - number_width)
    state.horizontal_offset = min(state.horizontal_offset, cursor_column)
    cursor_range = ranges[cursor_line]
    if text_width_available == 0
        state.horizontal_offset = cursor_column
    else
        while state.horizontal_offset < cursor_column &&
              _line_display_width(
                  state.editing,
                  cursor_range,
                  state.horizontal_offset,
                  cursor_column,
              ) >= text_width_available
            state.horizontal_offset += 1
        end
        while state.horizontal_offset > 0 &&
              _line_display_width(
                  state.editing,
                  cursor_range,
                  state.horizontal_offset - 1,
                  cursor_column,
              ) < text_width_available
            state.horizontal_offset -= 1
        end
    end
    selected = _selection(state.editing)
    for visible_line in 1:active.height
        line_index = state.vertical_offset + visible_line
        line_index > length(ranges) && break
        row = active.row + visible_line - 1
        column = active.column
        if widget.show_line_numbers
            number = lpad(string(line_index), number_width - 1) * " "
            column = draw_text!(buffer, row, column, number; style=widget.line_number_style, clip=active).column
        end
        range = ranges[line_index]
        skipped = 0
        for grapheme_index in range
            skipped < state.horizontal_offset && (skipped += 1; continue)
            grapheme = state.editing.graphemes[grapheme_index]
            width = grapheme_width(DEFAULT_WIDTH_POLICY, grapheme)
            column + width > active.column + active.width && break
            style = !isnothing(selected) && grapheme_index in selected ? widget.selection_style : widget.style
            column = draw_grapheme!(buffer, row, column, grapheme; style)
        end
    end
    cursor_row = active.row + cursor_line - state.vertical_offset - 1
    cursor_display_column = _line_display_width(
        state.editing,
        cursor_range,
        state.horizontal_offset,
        cursor_column,
    )
    cursor_column_position = active.column + number_width + cursor_display_column
    if active.row <= cursor_row < active.row + active.height &&
       active.column <= cursor_column_position < active.column + active.width
        Position(cursor_row, cursor_column_position)
    else
        nothing
    end
end

function render!(buffer::Buffer, widget::TextArea, area::Rect, state::TextAreaState)
    _render_text_area!(buffer, widget, area, state)
    buffer
end

render!(buffer::Buffer, widget::TextArea, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::TextArea, area::Rect, state::TextAreaState)
    position = _render_text_area!(frame.buffer, widget, area, state)
    state.focused && !isnothing(position) && request_cursor!(frame, CursorRequest(position))
    frame.buffer
end

handle!(state::TextAreaState, widget::TextArea, event::KeyEvent) =
    _handle_editing!(
        state.editing,
        event;
        multiline=true,
        maximum_length=widget.maximum_length,
    )

handle!(state::TextAreaState, widget::TextArea, event::PasteEvent) =
    insert!(state.editing, event.text; maximum_length=widget.maximum_length)

function handle!(
    state::TextAreaState,
    widget::TextArea,
    event::MouseEvent,
    area::Rect,
)
    event.action == MousePress && event.button == LeftMouseButton || return false
    active = isnothing(widget.block) ? area : inner(widget.block, area)
    contains(active, event.position) || return false
    ranges = _line_ranges(state.editing)
    line_index = clamp(
        state.vertical_offset + event.position.row - active.row + 1,
        1,
        length(ranges),
    )
    range = ranges[line_index]
    number_width = widget.show_line_numbers ? length(string(length(ranges))) + 1 : 0
    target_column = event.position.column - active.column - number_width
    first_offset = min(state.horizontal_offset, length(range))
    first_index = first(range) + first_offset
    boundary = if target_column <= 0 || isempty(range)
        first(range) - 1
    elseif first_index > last(range)
        last(range)
    else
        _pointer_cursor_boundary(
            state.editing.graphemes,
            first_index,
            last(range),
            target_column,
        )
    end
    move_cursor!(state.editing, boundary)
    state.focused = true
    return true
end

"""Compatibility spelling for a multi-line text area widget."""
struct Textarea
    area::TextArea
end

"""Compatibility state alias for `Textarea`; identical to `TextAreaState`."""
const TextareaState = TextAreaState

Textarea(; kwargs...) = Textarea(TextArea(; kwargs...))

state_for(widget::Textarea) = state_for(widget.area)

render!(buffer::Buffer, widget::Textarea, area::Rect, state::TextAreaState) =
    render!(buffer, widget.area, area, state)

render!(buffer::Buffer, widget::Textarea, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(frame::Frame, widget::Textarea, area::Rect, state::TextAreaState)
    render!(frame, widget.area, area, state)
end

handle!(state::TextAreaState, widget::Textarea, event::KeyEvent) =
    handle!(state, widget.area, event)

handle!(state::TextAreaState, widget::Textarea, event::PasteEvent) =
    handle!(state, widget.area, event)

handle!(state::TextAreaState, widget::Textarea, event::MouseEvent, area::Rect) =
    handle!(state, widget.area, event, area)

mutable struct ButtonState
    focused::Bool
    pressed::Bool
end

ButtonState(; focused::Bool=false, pressed::Bool=false) = ButtonState(focused, pressed)

struct Button{T}
    label::Line
    message::T
    block::Block
    style::Style
    focused_style::Style
    disabled::Bool
end

state_for(::Button) = ButtonState()

function Button(
    label::AbstractString,
    message=nothing;
    block::Block=Block(padding=Margin(0, 1)),
    style::Style=Style(),
    focused_style::Style=Style(modifiers=REVERSED | BOLD),
    disabled::Bool=false,
)
    Button(Line(label; alignment=CenterAlign), message, block, style, focused_style, disabled)
end

function render!(buffer::Buffer, widget::Button, area::Rect, state::ButtonState)
    render!(buffer, widget.block, area)
    active = intersection(buffer.area, inner(widget.block, area))
    isempty(active) && return buffer
    style = widget.disabled ? Style(modifiers=DIM) :
            state.focused || state.pressed ? widget.focused_style : widget.style
    for row in active.row:(active.row + active.height - 1)
        _fill_row!(buffer, row, active, style)
    end
    row = active.row + div(active.height - 1, 2)
    draw_line!(buffer, row, Rect(row, active.column, 1, active.width), _styled_line(widget.label, style))
    buffer
end

render!(buffer::Buffer, widget::Button, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::ButtonState, widget::Button, event::KeyEvent)
    widget.disabled && return false
    if event.key.code == :enter || (event.key.code == :character && event.text == " ")
        state.pressed = event.kind != KeyRelease
        return true
    end
    false
end

activate(widget::Button, ::ButtonState) = widget.disabled ? nothing : widget.message

function handle!(state::ButtonState, widget::Button, event::MouseEvent, area::Rect)
    widget.disabled && return false
    event.button == LeftMouseButton || return false
    inside = contains(area, event.position)
    if event.action == MousePress && inside
        state.pressed = true
        return true
    elseif event.action == MouseRelease
        activated = state.pressed && inside
        state.pressed = false
        return activated
    end
    false
end

"""
    PushButton(label, message=nothing; kwargs...)

Lanterna-style push-button compatibility widget backed by `Button`.

`PushButton` uses the same rendering, input, mouse, and activation semantics as
`Button`. Its state type is `PushButtonState`, an alias of `ButtonState`.
"""
struct PushButton{T}
    button::Button{T}
end

const PushButtonState = ButtonState

PushButton(label::AbstractString, message=nothing; kwargs...) =
    PushButton(Button(label, message; kwargs...))

state_for(::PushButton) = PushButtonState()

render!(buffer::Buffer, widget::PushButton, area::Rect, state::PushButtonState) =
    render!(buffer, widget.button, area, state)

render!(buffer::Buffer, widget::PushButton, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::PushButtonState, widget::PushButton, event::KeyEvent) =
    handle!(state, widget.button, event)

handle!(state::PushButtonState, widget::PushButton, event::MouseEvent, area::Rect) =
    handle!(state, widget.button, event, area)

activate(widget::PushButton, state::PushButtonState) =
    activate(widget.button, state)

mutable struct CheckboxState
    checked::Bool
end

CheckboxState() = CheckboxState(false)

struct Checkbox
    label::Line
    checked_symbol::String
    unchecked_symbol::String
    style::Style
    checked_style::Style
end

state_for(::Checkbox) = CheckboxState()

function Checkbox(
    label::AbstractString;
    checked_symbol::AbstractString="[x]",
    unchecked_symbol::AbstractString="[ ]",
    style::Style=Style(),
    checked_style::Style=Style(modifiers=BOLD),
)
    Checkbox(Line(label), String(checked_symbol), String(unchecked_symbol), style, checked_style)
end

function render!(buffer::Buffer, widget::Checkbox, area::Rect, state::CheckboxState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    symbol = state.checked ? widget.checked_symbol : widget.unchecked_symbol
    style = state.checked ? widget.checked_style : widget.style
    position = draw_text!(buffer, active.row, active.column, symbol * " "; style, clip=active)
    position.column < active.column + active.width &&
        draw_line!(
            buffer,
            active.row,
            Rect(active.row, position.column, 1, active.column + active.width - position.column),
            _styled_line(widget.label, style),
        )
    buffer
end

render!(buffer::Buffer, widget::Checkbox, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::CheckboxState, ::Checkbox, event::KeyEvent)
    _selection_key_event(event) || return false
    if event.key.code == :enter || (event.key.code == :character && event.text == " ")
        state.checked = !state.checked
        return true
    end
    false
end

function handle!(state::CheckboxState, ::Checkbox, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) && contains(area, event.position) || return false
    state.checked = !state.checked
    true
end

"""
    CheckBox(label; kwargs...)

Lanterna-style checkbox spelling backed by `Checkbox` and `CheckboxState`.

`CheckBox` is a stable compatibility name for applications porting conservative
retained-mode TUI code. It intentionally shares `CheckBoxState` with
`CheckboxState` so rendering, keyboard handling, pointer handling, and semantic
behavior stay identical to `Checkbox`.
"""
struct CheckBox
    checkbox::Checkbox
end

"""Compatibility state alias for `CheckBox`; identical to `CheckboxState`."""
const CheckBoxState = CheckboxState

CheckBox(label::AbstractString; kwargs...) = CheckBox(Checkbox(label; kwargs...))

state_for(::CheckBox) = CheckBoxState()

render!(buffer::Buffer, widget::CheckBox, area::Rect, state::CheckBoxState) =
    render!(buffer, widget.checkbox, area, state)

render!(buffer::Buffer, widget::CheckBox, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::CheckBoxState, widget::CheckBox, event::KeyEvent) =
    handle!(state, widget.checkbox, event)

handle!(state::CheckBoxState, widget::CheckBox, event::MouseEvent, area::Rect) =
    handle!(state, widget.checkbox, event, area)

mutable struct ToggleState
    enabled::Bool
end

ToggleState() = ToggleState(false)

struct Toggle
    on_label::String
    off_label::String
    on_style::Style
    off_style::Style
end

state_for(::Toggle) = ToggleState()

Toggle(;
    on_label::AbstractString="ON",
    off_label::AbstractString="OFF",
    on_style::Style=Style(modifiers=BOLD),
    off_style::Style=Style(modifiers=DIM),
) = Toggle(String(on_label), String(off_label), on_style, off_style)

function render!(buffer::Buffer, widget::Toggle, area::Rect, state::ToggleState)
    label = state.enabled ? widget.on_label : widget.off_label
    style = state.enabled ? widget.on_style : widget.off_style
    render!(buffer, Label("[ " * label * " ]"; style, alignment=CenterAlign), area)
end

render!(buffer::Buffer, widget::Toggle, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::ToggleState, ::Toggle, event::KeyEvent)
    _selection_key_event(event) || return false
    if event.key.code == :enter || (event.key.code == :character && event.text == " ")
        state.enabled = !state.enabled
        return true
    end
    false
end

function handle!(state::ToggleState, ::Toggle, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) && contains(area, event.position) || return false
    state.enabled = !state.enabled
    true
end

"""
    Switch(; on_label="ON", off_label="OFF", on_style=Style(modifiers=BOLD), off_style=Style(modifiers=DIM))

Textual-style switch control backed by `Toggle` and `ToggleState`.

`Switch` is a stable compatibility name for boolean controls. It intentionally
shares `SwitchState` with `ToggleState` so existing keyboard, pointer, Toolkit,
and semantic behavior remains identical to `Toggle`.
"""
struct Switch
    toggle::Toggle
end

"""Compatibility state alias for `Switch`; identical to `ToggleState`."""
const SwitchState = ToggleState

Switch(; kwargs...) = Switch(Toggle(; kwargs...))

state_for(::Switch) = SwitchState()

render!(buffer::Buffer, widget::Switch, area::Rect, state::SwitchState) =
    render!(buffer, widget.toggle, area, state)

render!(buffer::Buffer, widget::Switch, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::SwitchState, widget::Switch, event::KeyEvent) =
    handle!(state, widget.toggle, event)

handle!(state::SwitchState, widget::Switch, event::MouseEvent, area::Rect) =
    handle!(state, widget.toggle, event, area)

"""One value and label in a choice control."""
struct ChoiceOption{T}
    value::T
    label::Line
    disabled::Bool
end

ChoiceOption(
    value,
    label::AbstractString=string(value);
    disabled::Bool=false,
    style::Style=Style(),
) = ChoiceOption(value, Line(label; style), disabled)

mutable struct RadioGroupState
    selected::Union{Nothing,Int}
    focused::Bool
end

RadioGroupState(; selected::Union{Nothing,Integer}=nothing, focused::Bool=false) = begin
    !isnothing(selected) && selected < 1 &&
        throw(ArgumentError("selected radio index must be positive"))
    RadioGroupState(isnothing(selected) ? nothing : Int(selected), focused)
end

"""A single-choice control rendered vertically or horizontally."""
struct RadioGroup
    options::Vector{ChoiceOption}
    direction::LayoutDirection
    selected_symbol::String
    unselected_symbol::String
    style::Style
    selected_style::Style
    disabled_style::Style
    gap::Int
end

state_for(::RadioGroup) = RadioGroupState()

function RadioGroup(
    options;
    direction::LayoutDirection=VerticalLayout,
    selected_symbol::AbstractString="(*)",
    unselected_symbol::AbstractString="( )",
    style::Style=Style(),
    selected_style::Style=Style(modifiers=BOLD),
    disabled_style::Style=Style(modifiers=DIM),
    gap::Integer=0,
)
    gap >= 0 || throw(ArgumentError("radio group gap must be non-negative"))
    resolved = ChoiceOption[
        option isa ChoiceOption ? option :
        option isa Pair ? ChoiceOption(first(option), string(last(option))) : ChoiceOption(option)
        for option in options
    ]
    RadioGroup(
        resolved,
        direction,
        String(selected_symbol),
        String(unselected_symbol),
        style,
        selected_style,
        disabled_style,
        Int(gap),
    )
end

function render!(buffer::Buffer, widget::RadioGroup, area::Rect, state::RadioGroupState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    regions = _radio_regions(widget, active)
    for (index, option, region) in zip(eachindex(widget.options), widget.options, regions)
        selected = state.selected == index
        style = option.disabled ? widget.disabled_style :
                selected ? widget.selected_style : widget.style
        symbol = selected ? widget.selected_symbol : widget.unselected_symbol
        position = draw_text!(buffer, region.row, region.column, symbol * " "; style, clip=region)
        position.column < region.column + region.width &&
            draw_line!(
                buffer,
                region.row,
                Rect(region.row, position.column, 1, region.column + region.width - position.column),
                _styled_line(option.label, style),
            )
    end
    buffer
end

render!(buffer::Buffer, widget::RadioGroup, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function _radio_regions(widget::RadioGroup, area::Rect)
    constraints = if widget.direction == VerticalLayout
        Constraint[Length(1) for _ in widget.options]
    else
        symbol_width = max(text_width(widget.selected_symbol), text_width(widget.unselected_symbol))
        Constraint[
            Length(symbol_width + 1 + sum(span -> text_width(span.content), option.label.spans; init=0))
            for option in widget.options
        ]
    end
    return resolve(FlexLayout(widget.direction, constraints; gap=widget.gap), area)
end

function _next_choice(options, current::Int, direction::Int)
    isempty(options) && return nothing
    index = current
    for _ in eachindex(options)
        index = mod1(index + direction, length(options))
        !options[index].disabled && return index
    end
    nothing
end

function handle!(state::RadioGroupState, widget::RadioGroup, event::KeyEvent)
    _selection_key_event(event) || return false
    isempty(widget.options) && return false
    current = something(state.selected, 0)
    previous_keys = widget.direction == VerticalLayout ? (:up, :backtab) : (:left, :backtab)
    next_keys = widget.direction == VerticalLayout ? (:down, :tab) : (:right, :tab)
    if event.key.code in previous_keys
        state.selected = _next_choice(widget.options, current == 0 ? 1 : current, -1)
    elseif event.key.code in next_keys
        state.selected = _next_choice(widget.options, current, 1)
    elseif event.key.code == :home
        state.selected = findfirst(option -> !option.disabled, widget.options)
    elseif event.key.code == :end
        state.selected = findlast(option -> !option.disabled, widget.options)
    else
        return false
    end
    true
end

function handle!(state::RadioGroupState, widget::RadioGroup, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) && contains(area, event.position) || return false
    index = findfirst(region -> contains(region, event.position), _radio_regions(widget, area))
    index === nothing && return false
    widget.options[index].disabled && return false
    state.selected = index
    true
end

selected_value(widget::RadioGroup, state::RadioGroupState) =
    isnothing(state.selected) || !(1 <= state.selected <= length(widget.options)) ? nothing :
    widget.options[state.selected].disabled ? nothing : widget.options[state.selected].value

"""
    RadioSet(options; kwargs...)

Textual-style radio set backed by `RadioGroup` and `RadioGroupState`.

`RadioSet` is a stable compatibility surface for single-choice option groups.
It intentionally shares `RadioSetState` with `RadioGroupState` so layout,
disabled-option handling, keyboard navigation, pointer selection, and semantic
children stay identical to `RadioGroup`.
"""
struct RadioSet
    group::RadioGroup
end

"""Compatibility state alias for `RadioSet`; identical to `RadioGroupState`."""
const RadioSetState = RadioGroupState

RadioSet(options::AbstractVector; kwargs...) = RadioSet(RadioGroup(options; kwargs...))

state_for(::RadioSet) = RadioSetState()

render!(buffer::Buffer, widget::RadioSet, area::Rect, state::RadioSetState) =
    render!(buffer, widget.group, area, state)

render!(buffer::Buffer, widget::RadioSet, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::RadioSetState, widget::RadioSet, event::KeyEvent) =
    handle!(state, widget.group, event)

handle!(state::RadioSetState, widget::RadioSet, event::MouseEvent, area::Rect) =
    handle!(state, widget.group, event, area)

selected_value(widget::RadioSet, state::RadioSetState) =
    selected_value(widget.group, state)

"""
    RadioBoxList(options; kwargs...)

Lanterna-style radio-box list compatibility widget backed by `RadioGroup`.

`RadioBoxList` shares `RadioBoxListState` with `RadioGroupState`, so layout,
disabled-option handling, keyboard navigation, pointer selection, and
`selected_value` stay identical to `RadioGroup`.
"""
struct RadioBoxList
    group::RadioGroup
end

"""Compatibility state alias for `RadioBoxList`; identical to `RadioGroupState`."""
const RadioBoxListState = RadioGroupState

RadioBoxList(options::AbstractVector; kwargs...) = RadioBoxList(RadioGroup(options; kwargs...))

state_for(::RadioBoxList) = RadioBoxListState()

render!(buffer::Buffer, widget::RadioBoxList, area::Rect, state::RadioBoxListState) =
    render!(buffer, widget.group, area, state)

render!(buffer::Buffer, widget::RadioBoxList, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::RadioBoxListState, widget::RadioBoxList, event::KeyEvent) =
    handle!(state, widget.group, event)

handle!(state::RadioBoxListState, widget::RadioBoxList, event::MouseEvent, area::Rect) =
    handle!(state, widget.group, event, area)

selected_value(widget::RadioBoxList, state::RadioBoxListState) =
    selected_value(widget.group, state)

mutable struct SelectState
    selected::Union{Nothing,Int}
    highlighted::Union{Nothing,Int}
    open::Bool
    offset::Int
    focused::Bool
end

function SelectState(;
    selected::Union{Nothing,Integer}=nothing,
    open::Bool=false,
    focused::Bool=false,
)
    !isnothing(selected) && selected < 1 &&
        throw(ArgumentError("selected option index must be positive"))
    value = isnothing(selected) ? nothing : Int(selected)
    SelectState(value, value, open, 0, focused)
end

"""A single-choice dropdown with explicit open and highlighted state."""
struct Select
    options::Vector{ChoiceOption}
    placeholder::String
    block::Union{Nothing,Block}
    style::Style
    selected_style::Style
    disabled_style::Style
    open_symbol::String
    closed_symbol::String
end

state_for(::Select) = SelectState()

function Select(
    options;
    placeholder::AbstractString="Select...",
    block::Union{Nothing,Block}=nothing,
    style::Style=Style(),
    selected_style::Style=Style(modifiers=REVERSED),
    disabled_style::Style=Style(modifiers=DIM),
    open_symbol::AbstractString="▴",
    closed_symbol::AbstractString="▾",
)
    resolved = ChoiceOption[
        option isa ChoiceOption ? option :
        option isa Pair ? ChoiceOption(first(option), string(last(option))) : ChoiceOption(option)
        for option in options
    ]
    Select(
        resolved,
        String(placeholder),
        block,
        style,
        selected_style,
        disabled_style,
        String(open_symbol),
        String(closed_symbol),
    )
end

function _select_area(buffer::Buffer, widget::Select, area::Rect)
    if isnothing(widget.block)
        intersection(buffer.area, area)
    else
        render!(buffer, widget.block, area)
        intersection(buffer.area, inner(widget.block, area))
    end
end

function _normalize!(state::SelectState, widget::Select, visible::Int)
    count = length(widget.options)
    if count == 0
        state.selected = nothing
        state.highlighted = nothing
        state.offset = 0
        return
    end
    !isnothing(state.selected) && (state.selected = clamp(state.selected, 1, count))
    !isnothing(state.highlighted) && (state.highlighted = clamp(state.highlighted, 1, count))
    state.offset = clamp(state.offset, 0, max(0, count - visible))
    if !isnothing(state.highlighted) && visible > 0
        state.highlighted <= state.offset && (state.offset = state.highlighted - 1)
        state.highlighted > state.offset + visible && (state.offset = state.highlighted - visible)
    end
end

function render!(buffer::Buffer, widget::Select, area::Rect, state::SelectState)
    active = _select_area(buffer, widget, area)
    isempty(active) && return buffer
    _normalize!(state, widget, max(0, active.height - 1))
    line = isnothing(state.selected) ? Line(widget.placeholder; style=Style(modifiers=DIM)) :
           widget.options[state.selected].label
    symbol = state.open ? widget.open_symbol : widget.closed_symbol
    symbol_width = text_width(symbol) + 1
    value_area = Rect(active.row, active.column, 1, max(0, active.width - symbol_width))
    draw_line!(buffer, active.row, value_area, line)
    draw_text!(
        buffer,
        active.row,
        active.column + max(0, active.width - symbol_width + 1),
        symbol;
        style=widget.style,
        clip=active,
    )
    if state.open && active.height > 1
        for visible_index in 1:(active.height - 1)
            option_index = state.offset + visible_index
            option_index > length(widget.options) && break
            option = widget.options[option_index]
            row = active.row + visible_index
            option_area = Rect(row, active.column, 1, active.width)
            highlighted = state.highlighted == option_index
            style = option.disabled ? widget.disabled_style :
                    highlighted ? widget.selected_style : widget.style
            highlighted && _fill_row!(buffer, row, option_area, style)
            draw_line!(buffer, row, option_area, _styled_line(option.label, style))
        end
    end
    buffer
end

render!(buffer::Buffer, widget::Select, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::SelectState, widget::Select, event::KeyEvent; viewport_height::Integer=5)
    _selection_key_event(event) || return false
    if event.key.code in (:enter, :character) &&
       (event.key.code == :enter || event.text == " ")
        if state.open
            !isnothing(state.highlighted) && !widget.options[state.highlighted].disabled &&
                (state.selected = state.highlighted)
            state.open = false
        else
            state.open = true
            state.highlighted = something(state.selected, _next_choice(widget.options, 0, 1))
        end
    elseif event.key.code == :escape && state.open
        state.open = false
    elseif event.key.code in (:up, :down) && state.open
        current = something(state.highlighted, 0)
        state.highlighted = _next_choice(widget.options, current, event.key.code == :up ? -1 : 1)
    elseif event.key.code == :home && state.open
        state.highlighted = findfirst(option -> !option.disabled, widget.options)
    elseif event.key.code == :end && state.open
        state.highlighted = findlast(option -> !option.disabled, widget.options)
    else
        return false
    end
    _normalize!(state, widget, max(1, Int(viewport_height)))
    true
end

function handle!(state::SelectState, widget::Select, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) || return false
    active = isnothing(widget.block) ? area : inner(widget.block, area)
    contains(active, event.position) || return false
    relative_row = event.position.row - active.row
    if relative_row == 0
        state.open = !state.open
        state.highlighted = something(state.selected, _next_choice(widget.options, 0, 1))
    elseif state.open
        index = state.offset + relative_row
        1 <= index <= length(widget.options) || return false
        widget.options[index].disabled && return false
        state.highlighted = index
        state.selected = index
        state.open = false
    else
        return false
    end
    true
end

selected_value(widget::Select, state::SelectState) =
    isnothing(state.selected) || !(1 <= state.selected <= length(widget.options)) ? nothing :
    widget.options[state.selected].disabled ? nothing : widget.options[state.selected].value

mutable struct MultiSelectState
    selected::Set{Int}
    highlighted::Union{Nothing,Int}
    offset::Int
end

MultiSelectState(; selected=Int[]) =
    MultiSelectState(Set{Int}(Int(index) for index in selected), nothing, 0)

"""A multiple-choice list using the same option model as `Select`."""
struct MultiSelect
    options::Vector{ChoiceOption}
    checked_symbol::String
    unchecked_symbol::String
    highlight_style::Style
    disabled_style::Style
end

state_for(::MultiSelect) = MultiSelectState()

function MultiSelect(
    options;
    checked_symbol::AbstractString="[x]",
    unchecked_symbol::AbstractString="[ ]",
    highlight_style::Style=Style(modifiers=REVERSED),
    disabled_style::Style=Style(modifiers=DIM),
)
    resolved = ChoiceOption[
        option isa ChoiceOption ? option :
        option isa Pair ? ChoiceOption(first(option), string(last(option))) : ChoiceOption(option)
        for option in options
    ]
    MultiSelect(
        resolved,
        String(checked_symbol),
        String(unchecked_symbol),
        highlight_style,
        disabled_style,
    )
end


function render!(buffer::Buffer, widget::MultiSelect, area::Rect, state::MultiSelectState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    state.offset = clamp(state.offset, 0, max(0, length(widget.options) - active.height))
    for visible_index in 1:active.height
        option_index = state.offset + visible_index
        option_index > length(widget.options) && break
        option = widget.options[option_index]
        row = active.row + visible_index - 1
        row_area = Rect(row, active.column, 1, active.width)
        highlighted = state.highlighted == option_index
        style = option.disabled ? widget.disabled_style :
                highlighted ? widget.highlight_style : Style()
        highlighted && _fill_row!(buffer, row, row_area, style)
        symbol = option_index in state.selected ? widget.checked_symbol : widget.unchecked_symbol
        position = draw_text!(buffer, row, active.column, symbol * " "; style, clip=row_area)
        position.column < active.column + active.width &&
            draw_line!(
                buffer,
                row,
                Rect(row, position.column, 1, active.column + active.width - position.column),
                _styled_line(option.label, style),
            )
    end
    buffer
end

render!(buffer::Buffer, widget::MultiSelect, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::MultiSelectState, widget::MultiSelect, event::KeyEvent; viewport_height::Integer=1)
    _selection_key_event(event) || return false
    isempty(widget.options) && return false
    current = something(state.highlighted, 0)
    if event.key.code == :up
        state.highlighted = _next_choice(widget.options, current == 0 ? 1 : current, -1)
    elseif event.key.code == :down
        state.highlighted = _next_choice(widget.options, current, 1)
    elseif event.key.code == :home
        state.highlighted = findfirst(option -> !option.disabled, widget.options)
    elseif event.key.code == :end
        state.highlighted = findlast(option -> !option.disabled, widget.options)
    elseif event.key.code in (:enter, :character) &&
           (event.key.code == :enter || event.text == " ") &&
           !isnothing(state.highlighted)
        index = state.highlighted
        widget.options[index].disabled && return false
        index in state.selected ? delete!(state.selected, index) : push!(state.selected, index)
    else
        return false
    end
    if !isnothing(state.highlighted)
        visible = max(1, Int(viewport_height))
        state.highlighted <= state.offset && (state.offset = state.highlighted - 1)
        state.highlighted > state.offset + visible &&
            (state.offset = state.highlighted - visible)
    end
    true
end

function handle!(state::MultiSelectState, widget::MultiSelect, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) && contains(area, event.position) || return false
    index = state.offset + event.position.row - area.row + 1
    1 <= index <= length(widget.options) || return false
    widget.options[index].disabled && return false
    state.highlighted = index
    index in state.selected ? delete!(state.selected, index) : push!(state.selected, index)
    true
end

selected_values(widget::MultiSelect, state::MultiSelectState) =
    [
        widget.options[index].value for index in sort!(collect(state.selected))
        if 1 <= index <= length(widget.options) && !widget.options[index].disabled
    ]

"""
    SelectionList(options; kwargs...)

Textual-style multiple-selection list backed by `MultiSelect`.

`SelectionList` is a stable compatibility surface for multi-choice option lists.
It intentionally shares `SelectionListState` with `MultiSelectState` so
highlighting, disabled-option handling, checked state, keyboard navigation,
pointer selection, and `selected_values` stay identical to `MultiSelect`.
"""
struct SelectionList
    multiselect::MultiSelect
end

"""Compatibility state alias for `SelectionList`; identical to `MultiSelectState`."""
const SelectionListState = MultiSelectState

SelectionList(options::AbstractVector; kwargs...) = SelectionList(MultiSelect(options; kwargs...))

state_for(::SelectionList) = SelectionListState()

render!(buffer::Buffer, widget::SelectionList, area::Rect, state::SelectionListState) =
    render!(buffer, widget.multiselect, area, state)

render!(buffer::Buffer, widget::SelectionList, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::SelectionListState, widget::SelectionList, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.multiselect, event; viewport_height)

handle!(state::SelectionListState, widget::SelectionList, event::MouseEvent, area::Rect) =
    handle!(state, widget.multiselect, event, area)

selected_values(widget::SelectionList, state::SelectionListState) =
    selected_values(widget.multiselect, state)

"""
    CheckBoxList(options; kwargs...)

Lanterna-style checkbox-list compatibility widget backed by `MultiSelect`.

`CheckBoxList` shares `CheckBoxListState` with `MultiSelectState`, so disabled
options, checked rows, keyboard navigation, pointer selection, and
`selected_values` stay identical to `MultiSelect`.
"""
struct CheckBoxList
    multiselect::MultiSelect
end

"""Compatibility state alias for `CheckBoxList`; identical to `MultiSelectState`."""
const CheckBoxListState = MultiSelectState

CheckBoxList(options::AbstractVector; kwargs...) = CheckBoxList(MultiSelect(options; kwargs...))

state_for(::CheckBoxList) = CheckBoxListState()

render!(buffer::Buffer, widget::CheckBoxList, area::Rect, state::CheckBoxListState) =
    render!(buffer, widget.multiselect, area, state)

render!(buffer::Buffer, widget::CheckBoxList, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::CheckBoxListState, widget::CheckBoxList, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.multiselect, event; viewport_height)

handle!(state::CheckBoxListState, widget::CheckBoxList, event::MouseEvent, area::Rect) =
    handle!(state, widget.multiselect, event, area)

selected_values(widget::CheckBoxList, state::CheckBoxListState) =
    selected_values(widget.multiselect, state)
