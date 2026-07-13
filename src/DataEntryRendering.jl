module DataEntryRendering

import Dates
using Dates: Date, Time, day, monthname, dayofweek
using Unicode: graphemes
using ..RichAdapters: KeyChord
using ..RichContent: RichSpan, RichLine
using ..DataEntryControls: AutocompleteState,
                           CompletionItem,
                           ComboBoxState,
                           TagInputState,
                           NumericInputState,
                           MaskedInputState,
                           DatePickerState,
                           TimePickerState,
                           ColorPickerState,
                           ColorValue,
                           update_autocomplete!,
                           move_autocomplete!,
                           accept_autocomplete!,
                           close_autocomplete!,
                           visible_completions,
                           visible_completion_range,
                           set_combobox_query!,
                           move_combobox!,
                           accept_combobox!,
                           increment_numeric_input!,
                           commit_numeric_input!,
                           backspace_masked_input!,
                           delete_masked_input!,
                           insert_masked_input!,
                           masked_input_text,
                           masked_input_complete,
                           clear_masked_input!,
                           move_date_picker!,
                           move_date_picker_month!,
                           date_picker_grid,
                           increment_time_picker!,
                           color_hex,
                           color_hsv,
                           set_color_hsv!,
                           set_numeric_value!,
                           set_time_picker!,
                           select_date!,
                           set_color_rgb!
using ..Accessibility: SemanticRect,
                       SemanticState,
                       SemanticNode,
                       SemanticTree,
                       GroupRole,
                       ListRole,
                       ListItemRole,
                       TextboxRole,
                       ButtonRole,
                       SliderRole,
                       SelectSemanticAction,
                       ActivateSemanticAction,
                       SetValueSemanticAction,
                       IncrementSemanticAction,
                       DecrementSemanticAction

export DataEntryAction,
       EntryPrevious,
       EntryNext,
       EntryPagePrevious,
       EntryPageNext,
       EntryAccept,
       EntryCancel,
       EntryIncrement,
       EntryDecrement,
       EntryBackspace,
       EntryDelete,
       EntrySwitch,
       DataEntryBindings,
       bind_data_entry_key!,
       unbind_data_entry_key!,
       default_data_entry_bindings,
       data_entry_action_for_key,
       DataEntryActionResult,
       handle_data_entry_key!,
       handle_data_entry_character!,
       render_autocomplete,
       render_combobox,
       render_tags,
       render_numeric_input,
       render_masked_input,
       render_date_picker,
       render_time_picker,
       render_color_picker,
       control_value,
       set_control_value!,
       control_valid,
       control_error,
       autocomplete_semantic_tree,
       data_entry_semantic_node

@enum DataEntryAction begin
    EntryPrevious
    EntryNext
    EntryPagePrevious
    EntryPageNext
    EntryAccept
    EntryCancel
    EntryIncrement
    EntryDecrement
    EntryBackspace
    EntryDelete
    EntrySwitch
end

mutable struct DataEntryBindings
    actions::Dict{KeyChord,DataEntryAction}
end

DataEntryBindings() = DataEntryBindings(Dict{KeyChord,DataEntryAction}())

function bind_data_entry_key!(bindings::DataEntryBindings, chord::KeyChord, action::DataEntryAction)
    bindings.actions[chord] = action
    return bindings
end

function bind_data_entry_key!(bindings::DataEntryBindings, key, action::DataEntryAction; modifiers...)
    return bind_data_entry_key!(bindings, KeyChord(key; modifiers...), action)
end

function unbind_data_entry_key!(bindings::DataEntryBindings, chord::KeyChord)
    pop!(bindings.actions, chord, nothing)
    return bindings
end

function unbind_data_entry_key!(bindings::DataEntryBindings, key; modifiers...)
    return unbind_data_entry_key!(bindings, KeyChord(key; modifiers...))
end

function default_data_entry_bindings()
    bindings = DataEntryBindings()
    bind_data_entry_key!(bindings, :up, EntryPrevious)
    bind_data_entry_key!(bindings, :down, EntryNext)
    bind_data_entry_key!(bindings, :pageup, EntryPagePrevious)
    bind_data_entry_key!(bindings, :pagedown, EntryPageNext)
    bind_data_entry_key!(bindings, :enter, EntryAccept)
    bind_data_entry_key!(bindings, :escape, EntryCancel)
    bind_data_entry_key!(bindings, :right, EntryIncrement)
    bind_data_entry_key!(bindings, :left, EntryDecrement)
    bind_data_entry_key!(bindings, :backspace, EntryBackspace)
    bind_data_entry_key!(bindings, :delete, EntryDelete)
    bind_data_entry_key!(bindings, :tab, EntrySwitch)
    return bindings
end

function data_entry_action_for_key(
    bindings::DataEntryBindings,
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

struct DataEntryActionResult
    consumed::Bool
    action::Union{Nothing,DataEntryAction}
    committed::Bool
    value::Any
end

_unhandled_entry() = DataEntryActionResult(false, nothing, false, nothing)

function _action(
    bindings::DataEntryBindings,
    key,
    control::Bool,
    alt::Bool,
    shift::Bool,
)
    return data_entry_action_for_key(bindings, key; control=control, alt=alt, shift=shift)
end

function handle_data_entry_key!(
    state::AutocompleteState,
    bindings::DataEntryBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_entry()
    if action in (EntryPrevious, EntryDecrement)
        move_autocomplete!(state, -1)
    elseif action in (EntryNext, EntryIncrement)
        move_autocomplete!(state, 1)
    elseif action == EntryPagePrevious
        move_autocomplete!(state, -state.max_visible)
    elseif action == EntryPageNext
        move_autocomplete!(state, state.max_visible)
    elseif action == EntryAccept
        value = accept_autocomplete!(state)
        return DataEntryActionResult(true, action, value !== nothing, value)
    elseif action == EntryCancel
        close_autocomplete!(state)
    else
        return DataEntryActionResult(false, action, false, nothing)
    end
    return DataEntryActionResult(true, action, false, nothing)
end

function handle_data_entry_key!(
    state::ComboBoxState,
    bindings::DataEntryBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_entry()
    if action in (EntryPrevious, EntryDecrement)
        move_combobox!(state, -1)
    elseif action in (EntryNext, EntryIncrement)
        move_combobox!(state, 1)
    elseif action == EntryAccept
        value = accept_combobox!(state)
        return DataEntryActionResult(true, action, value !== nothing, value)
    elseif action == EntryCancel
        close_autocomplete!(state.autocomplete)
    else
        return DataEntryActionResult(false, action, false, nothing)
    end
    return DataEntryActionResult(true, action, false, nothing)
end

function handle_data_entry_key!(
    state::NumericInputState,
    bindings::DataEntryBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_entry()
    if action in (EntryPrevious, EntryIncrement)
        increment_numeric_input!(state, shift ? 10 : 1)
    elseif action in (EntryNext, EntryDecrement)
        increment_numeric_input!(state, shift ? -10 : -1)
    elseif action == EntryAccept
        committed = commit_numeric_input!(state)
        return DataEntryActionResult(true, action, committed, state.value)
    else
        return DataEntryActionResult(false, action, false, nothing)
    end
    return DataEntryActionResult(true, action, false, state.value)
end

function handle_data_entry_key!(
    state::MaskedInputState,
    bindings::DataEntryBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_entry()
    handled = action == EntryBackspace ? backspace_masked_input!(state) :
              action == EntryDelete ? delete_masked_input!(state) : false
    if action == EntryAccept
        complete = masked_input_complete(state)
        return DataEntryActionResult(true, action, complete, masked_input_text(state; include_placeholders=false))
    end
    return DataEntryActionResult(handled, action, false, nothing)
end

function handle_data_entry_key!(
    state::DatePickerState,
    bindings::DataEntryBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_entry()
    if action == EntryPrevious
        move_date_picker!(state, -7)
    elseif action == EntryNext
        move_date_picker!(state, 7)
    elseif action == EntryDecrement
        move_date_picker!(state, -1)
    elseif action == EntryIncrement
        move_date_picker!(state, 1)
    elseif action == EntryPagePrevious
        move_date_picker_month!(state, -1)
    elseif action == EntryPageNext
        move_date_picker_month!(state, 1)
    elseif action == EntryAccept
        return DataEntryActionResult(true, action, true, state.selected)
    else
        return DataEntryActionResult(false, action, false, nothing)
    end
    return DataEntryActionResult(true, action, false, state.selected)
end

function handle_data_entry_key!(
    state::TimePickerState,
    bindings::DataEntryBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_entry()
    if action in (EntryPrevious, EntryIncrement)
        increment_time_picker!(state, shift ? 10 : 1)
    elseif action in (EntryNext, EntryDecrement)
        increment_time_picker!(state, shift ? -10 : -1)
    elseif action == EntryAccept
        return DataEntryActionResult(true, action, true, state.value)
    else
        return DataEntryActionResult(false, action, false, nothing)
    end
    return DataEntryActionResult(true, action, false, state.value)
end

function handle_data_entry_key!(
    state::ColorPickerState,
    bindings::DataEntryBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = _action(bindings, key, control, alt, shift)
    action === nothing && return _unhandled_entry()
    hue, saturation, value = color_hsv(state.value)
    amount = shift ? 10.0 : 1.0
    if action in (EntryPrevious, EntryDecrement)
        set_color_hsv!(state, hue - amount, saturation, value)
    elseif action in (EntryNext, EntryIncrement)
        set_color_hsv!(state, hue + amount, saturation, value)
    elseif action == EntryAccept
        return DataEntryActionResult(true, action, true, state.value)
    else
        return DataEntryActionResult(false, action, false, nothing)
    end
    return DataEntryActionResult(true, action, false, state.value)
end

function handle_data_entry_character!(state::AutocompleteState, character::Char)
    iscntrl(character) && return false
    update_autocomplete!(state, state.query * character)
    return true
end

function handle_data_entry_character!(state::ComboBoxState, character::Char)
    state.editable || return false
    iscntrl(character) && return false
    set_combobox_query!(state, state.autocomplete.query * character)
    return true
end

handle_data_entry_character!(state::MaskedInputState, character::Char) =
    insert_masked_input!(state, character)

function _clip(value::AbstractString, width::Int)
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

_rich_line(value, role) = RichLine(RichSpan[RichSpan(String(value), role, nothing)], role, nothing)

function render_autocomplete(state::AutocompleteState; width::Integer=40)
    width > 0 || throw(ArgumentError("autocomplete width must be positive"))
    lines = RichLine[]
    for (visible_index, item) in zip(visible_completion_range(state), visible_completions(state))
        marker = state.highlighted == visible_index ? ">" : " "
        detail = item.detail === nothing ? "" : "  $(item.detail)"
        role = state.highlighted == visible_index ? :completion_highlighted : :completion
        push!(lines, _rich_line(_clip("$marker $(item.label)$detail", Int(width)), role))
    end
    return lines
end

function render_combobox(state::ComboBoxState; width::Integer=40)
    selected = state.selected === nothing ? state.autocomplete.query :
        something(findfirst(item -> isequal(item.value, state.selected), state.autocomplete.items), 0) == 0 ? string(state.selected) :
        state.autocomplete.items[findfirst(item -> isequal(item.value, state.selected), state.autocomplete.items)].label
    return _rich_line(_clip("[$selected]", Int(width)), :combobox)
end

function render_tags(state::TagInputState; width::Integer=80, separator::AbstractString=" ")
    value = join(("[$tag]" for tag in state.tags), separator)
    return _rich_line(_clip(value, Int(width)), :tag_input)
end

function render_numeric_input(state::NumericInputState; width::Integer=20)
    role = state.valid ? :numeric_input : state.error === nothing ? :numeric_input_pending : :numeric_input_invalid
    return _rich_line(_clip(state.text, Int(width)), role)
end

render_masked_input(state::MaskedInputState; width::Integer=40) =
    _rich_line(_clip(masked_input_text(state), Int(width)), masked_input_complete(state) ? :masked_input_complete : :masked_input)

function render_date_picker(state::DatePickerState; width::Integer=28)
    width > 0 || throw(ArgumentError("date-picker width must be positive"))
    lines = RichLine[_rich_line(_clip("$(monthname(state.visible_month)) $(Dates.year(state.visible_month))", Int(width)), :date_header)]
    grid = date_picker_grid(state)
    for row in axes(grid, 1)
        parts = String[]
        for column in axes(grid, 2)
            value = grid[row, column]
            label = lpad(string(day(value)), 2)
            value == state.selected && (label = "[$(day(value))]")
            push!(parts, rpad(label, 4))
        end
        push!(lines, _rich_line(_clip(join(parts), Int(width)), :date_week))
    end
    return lines
end

render_time_picker(state::TimePickerState; width::Integer=16) =
    _rich_line(_clip(Dates.format(state.value, Dates.DateFormat("HH:MM:SS")), Int(width)), :time_picker)

function render_color_picker(state::ColorPickerState; width::Integer=32)
    hue, saturation, value = color_hsv(state.value)
    text = "$(color_hex(state)) H=$(round(hue; digits=1)) S=$(round(100saturation; digits=1))% V=$(round(100value; digits=1))%"
    return _rich_line(_clip(text, Int(width)), :color_picker)
end

control_value(state::ComboBoxState) = state.selected
control_value(state::TagInputState) = copy(state.tags)
control_value(state::NumericInputState) = state.value
control_value(state::MaskedInputState) = masked_input_text(state; include_placeholders=false)
control_value(state::DatePickerState) = state.selected
control_value(state::TimePickerState) = state.value
control_value(state::ColorPickerState) = state.value

set_control_value!(state::NumericInputState, value) = set_numeric_value!(state, value)
set_control_value!(state::MaskedInputState, value::AbstractString) = begin
    clear_masked_input!(state)
    for character in value
        insert_masked_input!(state, character) || break
    end
    state
end
set_control_value!(state::DatePickerState, value::Date) = select_date!(state, value)
set_control_value!(state::TimePickerState, value::Time) = set_time_picker!(state, value)
set_control_value!(state::ColorPickerState, value::ColorValue) =
    set_color_rgb!(state, value.red, value.green, value.blue; alpha=value.alpha)

control_valid(state::ComboBoxState) = !state.required || state.selected !== nothing
control_valid(::TagInputState) = true
control_valid(state::NumericInputState) = state.valid
control_valid(state::MaskedInputState) = masked_input_complete(state)
control_valid(::DatePickerState) = true
control_valid(::TimePickerState) = true
control_valid(::ColorPickerState) = true

control_error(state::ComboBoxState) = control_valid(state) ? nothing : "a selection is required"
control_error(::TagInputState) = nothing
control_error(state::NumericInputState) = state.error
control_error(state::MaskedInputState) = control_valid(state) ? nothing : "input is incomplete"
control_error(::DatePickerState) = nothing
control_error(::TimePickerState) = nothing
control_error(::ColorPickerState) = nothing

function autocomplete_semantic_tree(
    state::AutocompleteState;
    id="autocomplete",
    label::AbstractString="Suggestions",
    origin_row::Integer=1,
    origin_column::Integer=1,
    width::Integer=1,
)
    children = SemanticNode[]
    for (visible_index, item) in enumerate(visible_completions(state))
        push!(children, SemanticNode(
            "$(id)/$visible_index",
            ListItemRole;
            label=item.label,
            description=item.detail,
            bounds=SemanticRect(origin_row + visible_index - 1, origin_column, width, 1),
            state=SemanticState(
                enabled=!item.disabled,
                focusable=!item.disabled,
                focused=state.highlighted == visible_index,
            ),
            actions=item.disabled ? [] : [SelectSemanticAction, ActivateSemanticAction],
        ))
    end
    return SemanticTree(SemanticNode(
        id,
        ListRole;
        label=label,
        bounds=SemanticRect(origin_row, origin_column, width, length(children)),
        state=SemanticState(hidden=!state.open),
        children=children,
    ))
end

function data_entry_semantic_node(
    state::ComboBoxState,
    id;
    label::AbstractString="",
    bounds=nothing,
)
    selected = state.selected === nothing ? nothing : string(state.selected)
    return SemanticNode(
        id,
        GroupRole;
        label=label,
        bounds=bounds,
        state=SemanticState(
            focusable=true,
            required=state.required,
            invalid=state.required && state.selected === nothing,
            value=selected,
            expanded=state.autocomplete.open,
        ),
        actions=[SetValueSemanticAction, ActivateSemanticAction],
    )
end

function data_entry_semantic_node(
    state::TagInputState,
    id;
    label::AbstractString="",
    bounds=nothing,
)
    children = SemanticNode[
        SemanticNode("$(id)/$index", ListItemRole; label=tag, actions=[ActivateSemanticAction])
        for (index, tag) in enumerate(state.tags)
    ]
    return SemanticNode(
        id,
        ListRole;
        label=label,
        bounds=bounds,
        state=SemanticState(focusable=true, value=join(state.tags, ", ")),
        actions=[SetValueSemanticAction],
        children=children,
    )
end

function data_entry_semantic_node(
    state::NumericInputState,
    id;
    label::AbstractString="",
    bounds=nothing,
)
    return SemanticNode(
        id,
        TextboxRole;
        label=label,
        bounds=bounds,
        state=SemanticState(
            focusable=true,
            invalid=!state.valid,
            value=state.text,
            value_now=state.value,
            value_min=state.minimum,
            value_max=state.maximum,
        ),
        actions=[SetValueSemanticAction, IncrementSemanticAction, DecrementSemanticAction],
    )
end

function data_entry_semantic_node(
    state::MaskedInputState,
    id;
    label::AbstractString="",
    bounds=nothing,
)
    return SemanticNode(
        id,
        TextboxRole;
        label=label,
        bounds=bounds,
        state=SemanticState(focusable=true, invalid=!masked_input_complete(state), value=masked_input_text(state)),
        actions=[SetValueSemanticAction],
    )
end

function data_entry_semantic_node(state::DatePickerState, id; label::AbstractString="", bounds=nothing)
    return SemanticNode(
        id,
        GroupRole;
        label=label,
        bounds=bounds,
        state=SemanticState(focusable=true, value=string(state.selected)),
        actions=[SetValueSemanticAction, IncrementSemanticAction, DecrementSemanticAction],
    )
end

function data_entry_semantic_node(state::TimePickerState, id; label::AbstractString="", bounds=nothing)
    return SemanticNode(
        id,
        GroupRole;
        label=label,
        bounds=bounds,
        state=SemanticState(focusable=true, value=string(state.value)),
        actions=[SetValueSemanticAction, IncrementSemanticAction, DecrementSemanticAction],
    )
end

function data_entry_semantic_node(state::ColorPickerState, id; label::AbstractString="", bounds=nothing)
    return SemanticNode(
        id,
        SliderRole;
        label=label,
        bounds=bounds,
        state=SemanticState(focusable=true, value=color_hex(state)),
        actions=[SetValueSemanticAction, IncrementSemanticAction, DecrementSemanticAction],
    )
end

end
