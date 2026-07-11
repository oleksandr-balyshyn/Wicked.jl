"""Immediate-mode code and masked input widgets over the shared editing engines."""

struct CodeEditor
    source::String
    language::String
    area::TextArea
    history_limit::Int
end

function CodeEditor(
    source::AbstractString="";
    language::AbstractString="",
    block::Union{Nothing,Block}=nothing,
    style::Style=Style(),
    selection_style::Style=Style(modifiers=REVERSED),
    line_number_style::Style=Style(modifiers=DIM),
    show_line_numbers::Bool=true,
    maximum_length::Integer=typemax(Int),
    history_limit::Integer=100,
)
    history_limit >= 0 || throw(ArgumentError("code-editor history limit must be non-negative"))
    area = TextArea(; block, style, selection_style, line_number_style, show_line_numbers, maximum_length)
    return CodeEditor(String(source), String(language), area, Int(history_limit))
end

"""Shared editable text plus code-view metadata for `CodeEditor`."""
mutable struct CodeEditorState
    text::TextAreaState
    code::CodeViewState
end

function CodeEditorState(source::AbstractString=""; language::AbstractString="", history_limit::Integer=100)
    history_limit >= 0 || throw(ArgumentError("code-editor history limit must be non-negative"))
    return CodeEditorState(
        TextAreaState(source; focused=true, history_limit),
        CodeViewState(source; language),
    )
end

state_for(widget::CodeEditor) = CodeEditorState(widget.source; language=widget.language, history_limit=widget.history_limit)
code_editor_text(state::CodeEditorState) = editing_text(state.text.editing)

function _synchronize_code_editor!(state::CodeEditorState)
    source = code_editor_text(state)
    source != state.code.source && set_code_source!(state.code, source)
    return state
end

function set_code_editor_text!(state::CodeEditorState, source::AbstractString; record::Bool=true)
    set_text!(state.text.editing, source; record)
    return _synchronize_code_editor!(state)
end

function set_code_editor_language!(state::CodeEditorState, language::AbstractString)
    set_code_language!(state.code, language)
    return state
end

measure(widget::CodeEditor, available::Rect) = measure(widget.area, available)

function render!(buffer::Buffer, widget::CodeEditor, area::Rect, state::CodeEditorState)
    _synchronize_code_editor!(state)
    return render!(buffer, widget.area, area, state.text)
end

function render!(frame::Frame, widget::CodeEditor, area::Rect, state::CodeEditorState)
    _synchronize_code_editor!(state)
    return render!(frame, widget.area, area, state.text)
end

render!(buffer::Buffer, widget::CodeEditor, area::Rect) = render!(buffer, widget, area, state_for(widget))

function handle!(state::CodeEditorState, widget::CodeEditor, event::KeyEvent)
    handled = handle!(state.text, widget.area, event)
    handled && _synchronize_code_editor!(state)
    return handled
end

function handle!(state::CodeEditorState, widget::CodeEditor, event::PasteEvent)
    handled = handle!(state.text, widget.area, event)
    handled && _synchronize_code_editor!(state)
    return handled
end

function handle!(state::CodeEditorState, widget::CodeEditor, event::MouseEvent, area::Rect)
    handled = handle!(state.text, widget.area, event, area)
    handled && (state.text.focused = true)
    return handled
end

code_editor_semantic_node(state::CodeEditorState, id; label::AbstractString="Code editor", bounds=nothing) =
    code_view_semantic_node(state.code, id; label, bounds)

function SemanticToolkit.widget_semantic_descriptor(widget::CodeEditor, state::CodeEditorState)
    metadata = Dict{Symbol,Any}(
        :language => state.code.language,
        :revision => state.code.revision,
        :diagnostic_count => length(state.code.diagnostics),
        :multiline => true,
    )
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label=isempty(widget.language) ? "Code editor" : "$(widget.language) code editor",
        state=Accessibility.SemanticState(
            focusable=true,
            focused=state.text.focused,
            value=code_editor_text(state),
        ),
        actions=[Accessibility.FocusSemanticAction, Accessibility.SetValueSemanticAction],
        metadata,
    )
end

struct MaskedInput
    mask::InputMask
    width::Int
    height::Int
    bindings::DataEntryBindings
    style::Style
    incomplete_style::Style
end

function MaskedInput(
    pattern::AbstractString;
    placeholder::Char='_',
    width::Integer=40,
    height::Integer=1,
    bindings::DataEntryBindings=default_data_entry_bindings(),
    style::Style=Style(),
    incomplete_style::Style=Style(modifiers=DIM),
)
    width > 0 || throw(ArgumentError("masked-input width must be positive"))
    height >= 0 || throw(ArgumentError("masked-input height cannot be negative"))
    return MaskedInput(InputMask(pattern; placeholder), Int(width), Int(height), bindings, style, incomplete_style)
end

state_for(widget::MaskedInput) = MaskedInputState(widget.mask)
measure(widget::MaskedInput, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function _masked_input_area(buffer::Buffer, widget::MaskedInput, area::Rect)
    active = intersection(buffer.area, area)
    return Rect(active.row, active.column, min(active.height, widget.height), min(active.width, widget.width))
end

function _masked_input_prefix_width(state::MaskedInputState)
    output = IOBuffer()
    for index in 1:min(state.cursor - 1, length(state.mask.tokens))
        token = state.mask.tokens[index]
        value = state.values[index]
        print(output, token.kind == MaskLiteral ? token.literal : something(value, state.mask.placeholder))
    end
    return text_width(String(take!(output)))
end

function render!(buffer::Buffer, widget::MaskedInput, area::Rect, state::MaskedInputState)
    active = _masked_input_area(buffer, widget, area)
    isempty(active) && return buffer
    style = masked_input_complete(state) ? widget.style : widget.incomplete_style
    draw_text!(buffer, active.row, active.column, masked_input_text(state); style, clip=active)
    return buffer
end

function render!(frame::Frame, widget::MaskedInput, area::Rect, state::MaskedInputState)
    render!(frame.buffer, widget, area, state)
    active = _masked_input_area(frame.buffer, widget, area)
    column = active.column + _masked_input_prefix_width(state)
    state.focused && column < active.column + active.width &&
        request_cursor!(frame, CursorRequest(Position(active.row, column)))
    return frame.buffer
end

render!(buffer::Buffer, widget::MaskedInput, area::Rect) = render!(buffer, widget, area, state_for(widget))

function handle!(state::MaskedInputState, widget::MaskedInput, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    state.focused = true
    if event.key.code == :left
        return move_masked_input_cursor!(state, -1)
    elseif event.key.code == :right
        return move_masked_input_cursor!(state, 1)
    elseif event.key.code == :home
        return set_masked_input_cursor!(state, 1)
    elseif event.key.code == :end
        return set_masked_input_cursor!(state, length(state.mask.tokens) + 1)
    elseif event.key.code == :character && !isempty(event.text)
        handled = false
        for character in event.text
            handled = handle_data_entry_character!(state, character) || handled
        end
        return handled
    end
    return handle_data_entry_key!(state, widget.bindings, event.key.code;
        control=in(CTRL, event.modifiers), alt=in(ALT, event.modifiers), shift=in(SHIFT, event.modifiers)).consumed
end

function handle!(state::MaskedInputState, widget::MaskedInput, event::PasteEvent)
    state.focused = true
    handled = false
    for character in event.text
        handled = handle_data_entry_character!(state, character) || handled
    end
    return handled
end

function handle!(state::MaskedInputState, widget::MaskedInput, event::MouseEvent, area::Rect)
    event.action == MousePress && event.button == LeftMouseButton || return false
    active = _data_widget_area(widget, area)
    contains(active, event.position) || return false
    state.focused = true
    target = event.position.column - active.column + 1
    used = 0
    position = length(state.mask.tokens) + 1
    for index in eachindex(state.mask.tokens)
        token = state.mask.tokens[index]
        value = token.kind == MaskLiteral ? string(token.literal) : string(something(state.values[index], state.mask.placeholder))
        width = text_width(value)
        if target <= used + max(1, width)
            position = index
            break
        end
        used += width
    end
    set_masked_input_cursor!(state, position)
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::MaskedInput, state::MaskedInputState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label="Masked input",
        state=Accessibility.SemanticState(
            focusable=true,
            focused=state.focused,
            value=masked_input_text(state),
        ),
        actions=[Accessibility.FocusSemanticAction, Accessibility.SetValueSemanticAction],
        metadata=Dict(:mask_token_count => length(widget.mask.tokens), :complete => masked_input_complete(state)),
    )
end
