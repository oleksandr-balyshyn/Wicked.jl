"""
Semantic border widget backed by `Block`.

`Border` provides the specification name as a direct widget identity while
delegating measurement and rendering to Wicked's authoritative `Block` surface.
"""
struct Border
    block::Block
end

function Border(;
    title::Union{Nothing,AbstractString,Line}=nothing,
    borders::BorderSet=AllBorders,
    symbols::BorderSymbols=ROUNDED_BORDERS,
    border_style::Style=Style(),
    title_style::Style=border_style,
    padding::Margin=Margin(0),
)
    return Border(Block(; title, borders, symbols, border_style, title_style, padding))
end

measure(widget::Border, available::Rect) = measure(widget.block, available)

function render!(buffer::Buffer, widget::Border, area::Rect)
    render!(buffer, widget.block, area)
end

SemanticToolkit.widget_semantic_descriptor(::Border, state) = _static_group_semantics("Border")

"""
Dedicated card-like container built from an explicit border block and child.
"""
struct Card{W}
    child::W
    block::Block
end

Card(child; block::Block=Block()) = Card(child, block)

_static_group_semantics(label::AbstractString; metadata=Dict{Symbol,Any}()) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label,
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata,
    )

function _register_readonly_layout_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    value,
    unsupported::AbstractString,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction)
            return Accessibility.SemanticActionResult(true; value)
        end
        return Accessibility.SemanticActionResult(false; message=unsupported)
    end)
    return dispatcher
end

_readonly_widget_semantic_actions() = Accessibility.SemanticAction[
    Accessibility.FocusSemanticAction,
    Accessibility.SelectSemanticAction,
]

function _register_readonly_widget_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    value,
    unsupported::AbstractString,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction)
            return Accessibility.SemanticActionResult(true; value)
        end
        return Accessibility.SemanticActionResult(false; message=unsupported)
    end)
    return dispatcher
end

SemanticToolkit.widget_semantic_descriptor(::Card, state) = _static_group_semantics("Card")

register_border_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Border) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Border"),
        "border semantic action is not supported",
    )

register_card_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Card) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Card"),
        "card semantic action is not supported",
    )

measure(widget::Card, available::Rect) = measure(Box(widget.child; block=widget.block), available)

function render!(buffer::Buffer, widget::Card, area::Rect)
    render!(buffer, Box(widget.child; block=widget.block), area)
end

"""
Dedicated panel container preserved for parity migration from prior naming.

`Panel` renders through the same bordered-card implementation as `Card` while
exposing panel naming as its own widget identity for retained-mode migration.
"""
struct Panel{W}
    card::Card{W}
end

Panel(child; block::Block=Block()) = Panel(Card(child; block))

measure(widget::Panel, available::Rect) = measure(widget.card, available)

function render!(buffer::Buffer, widget::Panel, area::Rect)
    render!(buffer, widget.card, area)
end

SemanticToolkit.widget_semantic_descriptor(::Panel, state) = _static_group_semantics("Panel")

register_panel_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Panel) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Panel"),
        "panel semantic action is not supported",
    )

"""
Immediate autocomplete suggestion list with explicit externally owned state.

`Autocomplete` wraps the stable `AutocompleteState` state machine as a direct
renderable widget. Use `state_for(widget)` to create the initial query, match,
and highlight state, then keep that state in the application model between
frames.
"""
struct Autocomplete{T}
    items::Vector{CompletionItem{T}}
    width::Int
    max_visible::Int
    mode::CompletionMatchMode
    case_sensitive::Bool
    bindings::DataEntryBindings
    label::String
end

function Autocomplete(
    items::AbstractVector{CompletionItem{T}};
    width::Integer=40,
    max_visible::Integer=10,
    mode::CompletionMatchMode=FuzzyCompletion,
    case_sensitive::Bool=false,
    bindings::DataEntryBindings=default_data_entry_bindings(),
    label::AbstractString="Suggestions",
) where {T}
    width > 0 || throw(ArgumentError("autocomplete width must be positive"))
    max_visible > 0 || throw(ArgumentError("maximum visible completions must be positive"))
    return Autocomplete{T}(
        CompletionItem{T}[item for item in items],
        Int(width),
        Int(max_visible),
        mode,
        Bool(case_sensitive),
        bindings,
        String(label),
    )
end

Autocomplete(items::AbstractVector{<:AbstractString}; kwargs...) =
    Autocomplete([CompletionItem(item, String(item)) for item in items]; kwargs...)

state_for(widget::Autocomplete) = AutocompleteState(
    widget.items;
    max_visible=widget.max_visible,
    mode=widget.mode,
    case_sensitive=widget.case_sensitive,
)

measure(widget::Autocomplete, available::Rect) =
    Size(min(available.height, widget.max_visible), min(available.width, widget.width))

function render!(buffer::Buffer, widget::Autocomplete, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function render!(buffer::Buffer, widget::Autocomplete, area::Rect, state::AutocompleteState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    state.open || return buffer
    lines = render_autocomplete(state; width=min(active.width, widget.width))
    rendered = rich_lines_to_core_text(CoreTextAdapter(), lines)
    return render!(buffer, Paragraph(rendered), active)
end

function handle!(state::AutocompleteState, widget::Autocomplete, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :character && !isempty(event.text)
        handled = false
        for character in event.text
            handled = handle_data_entry_character!(state, character) || handled
        end
        return handled
    end
    return handle_data_entry_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    ).consumed
end

function handle!(state::AutocompleteState, widget::Autocomplete, event::PasteEvent)
    handled = false
    for character in event.text
        handled = handle_data_entry_character!(state, character) || handled
    end
    return handled
end

function handle!(state::AutocompleteState, ::Autocomplete, event::MouseEvent, area::Rect)
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    state.open || return false
    contains(area, event.position) || return false
    visible = visible_completion_range(state)
    isempty(visible) && return false
    row = event.position.row - area.row + 1
    1 <= row <= length(visible) || return false
    state.highlighted = first(visible) + row - 1
    accept_autocomplete!(state) === nothing && return false
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::Autocomplete, state::AutocompleteState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            hidden=!state.open,
            focusable=true,
            value=state.query,
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.DismissSemanticAction,
        ],
        metadata=Dict(:match_count => length(state.matches), :highlighted => state.highlighted),
    )
end

function SemanticToolkit.widget_semantic_children(widget::Autocomplete, state::AutocompleteState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(visible_index)",
            Accessibility.ListItemRole;
            label=item.label,
            description=item.detail,
            state=Accessibility.SemanticState(
                enabled=!item.disabled,
                focusable=!item.disabled,
                focused=state.highlighted == visible_index,
                selected=state.highlighted == visible_index,
            ),
            actions=item.disabled ? [] : [Accessibility.SelectSemanticAction, Accessibility.ActivateSemanticAction],
        ) for (visible_index, item) in zip(visible_completion_range(state), visible_completions(state))
    ]
end

"""
Immediate combo box widget backed by the stable `ComboBoxState` control model.

`ComboBox` combines a selected/query display with the autocomplete completion
list. Editable combo boxes accept typed query input; all combo boxes support
shared data-entry navigation bindings and pointer activation for visible
suggestions.
"""
struct ComboBox{T}
    items::Vector{CompletionItem{T}}
    width::Int
    max_visible::Int
    mode::CompletionMatchMode
    case_sensitive::Bool
    editable::Bool
    required::Bool
    bindings::DataEntryBindings
    label::String
end

function ComboBox(
    items::AbstractVector{CompletionItem{T}};
    width::Integer=40,
    max_visible::Integer=10,
    mode::CompletionMatchMode=FuzzyCompletion,
    case_sensitive::Bool=false,
    editable::Bool=false,
    required::Bool=false,
    bindings::DataEntryBindings=default_data_entry_bindings(),
    label::AbstractString="Combo box",
) where {T}
    width > 0 || throw(ArgumentError("combo box width must be positive"))
    max_visible > 0 || throw(ArgumentError("maximum visible completions must be positive"))
    return ComboBox{T}(
        CompletionItem{T}[item for item in items],
        Int(width),
        Int(max_visible),
        mode,
        Bool(case_sensitive),
        Bool(editable),
        Bool(required),
        bindings,
        String(label),
    )
end

ComboBox(items::AbstractVector{<:AbstractString}; kwargs...) =
    ComboBox([CompletionItem(item, String(item)) for item in items]; kwargs...)

state_for(widget::ComboBox) = ComboBoxState(
    widget.items;
    editable=widget.editable,
    required=widget.required,
    max_visible=widget.max_visible,
    mode=widget.mode,
    case_sensitive=widget.case_sensitive,
)

measure(widget::ComboBox, available::Rect) =
    Size(min(available.height, widget.max_visible + 1), min(available.width, widget.width))

function render!(buffer::Buffer, widget::ComboBox, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function render!(buffer::Buffer, widget::ComboBox, area::Rect, state::ComboBoxState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    lines = RichLine[render_combobox(state; width=min(active.width, widget.width))]
    if state.autocomplete.open && active.height > 1
        completion_lines = render_autocomplete(state.autocomplete; width=min(active.width, widget.width))
        append!(
            lines,
            completion_lines[1:min(
                active.height - 1,
                length(completion_lines),
            )],
        )
    end
    rendered = rich_lines_to_core_text(CoreTextAdapter(), lines)
    return render!(buffer, Paragraph(rendered), active)
end

function handle!(state::ComboBoxState, widget::ComboBox, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :character && !isempty(event.text)
        handled = false
        for character in event.text
            handled = handle_data_entry_character!(state, character) || handled
        end
        return handled
    end
    return handle_data_entry_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    ).consumed
end

function handle!(state::ComboBoxState, widget::ComboBox, event::PasteEvent)
    handled = false
    for character in event.text
        handled = handle_data_entry_character!(state, character) || handled
    end
    return handled
end

function handle!(state::ComboBoxState, ::ComboBox, event::MouseEvent, area::Rect)
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    contains(area, event.position) || return false
    relative_row = event.position.row - area.row
    if relative_row == 0
        state.autocomplete.open = !state.autocomplete.open
        return true
    end
    state.autocomplete.open || return false
    visible = visible_completion_range(state.autocomplete)
    1 <= relative_row <= length(visible) || return false
    state.autocomplete.highlighted = first(visible) + relative_row - 1
    accept_combobox!(state) === nothing && return false
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::ComboBox, state::ComboBoxState)
    selected = state.selected === nothing ? nothing : string(state.selected)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            focusable=true,
            required=state.required,
            invalid=state.required && state.selected === nothing,
            value=selected,
            expanded=state.autocomplete.open,
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.ActivateSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.DismissSemanticAction,
        ],
        metadata=Dict(:editable => widget.editable, :match_count => length(state.autocomplete.matches)),
    )
end

function SemanticToolkit.widget_semantic_children(widget::ComboBox, state::ComboBoxState, id)
    return SemanticToolkit.widget_semantic_children(
        Autocomplete(widget.items; width=widget.width, max_visible=widget.max_visible, mode=widget.mode, case_sensitive=widget.case_sensitive, label=widget.label),
        state.autocomplete,
        id,
    )
end

"""
Immediate tag-list input backed by the stable `TagInputState` control model.

`TagInput` renders tags as bracketed chips. Applications may mutate the state
with `add_tag!`, `remove_tag!`, and `clear_tags!`; the widget also supports
paste-to-add, backspace/delete removal of the last tag, and pointer removal of a
clicked tag.
"""
struct TagInput
    tags::Vector{String}
    width::Int
    maximum::Union{Nothing,Int}
    allow_duplicates::Bool
    case_sensitive::Bool
    separator::String
    label::String
end

function TagInput(
    tags=String[];
    width::Integer=80,
    maximum::Union{Nothing,Integer}=nothing,
    allow_duplicates::Bool=false,
    case_sensitive::Bool=false,
    separator::AbstractString=" ",
    label::AbstractString="Tags",
)
    width > 0 || throw(ArgumentError("tag input width must be positive"))
    maximum !== nothing && maximum < 0 && throw(ArgumentError("maximum tag count cannot be negative"))
    return TagInput(
        String[String(tag) for tag in tags],
        Int(width),
        maximum === nothing ? nothing : Int(maximum),
        Bool(allow_duplicates),
        Bool(case_sensitive),
        String(separator),
        String(label),
    )
end

state_for(widget::TagInput) = TagInputState(
    widget.tags;
    maximum=widget.maximum,
    allow_duplicates=widget.allow_duplicates,
    case_sensitive=widget.case_sensitive,
)

measure(widget::TagInput, available::Rect) =
    Size(min(available.height, 1), min(available.width, widget.width))

function render!(buffer::Buffer, widget::TagInput, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function render!(buffer::Buffer, widget::TagInput, area::Rect, state::TagInputState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    rendered = rich_lines_to_core_text(
        CoreTextAdapter(),
        RichLine[render_tags(state; width=min(active.width, widget.width), separator=widget.separator)],
    )
    return render!(buffer, Paragraph(rendered), active)
end

function handle!(state::TagInputState, ::TagInput, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code in (:backspace, :delete)
        isempty(state.tags) && return false
        remove_tag!(state, length(state.tags))
        return true
    end
    return false
end

function handle!(state::TagInputState, ::TagInput, event::PasteEvent)
    return add_tag!(state, event.text)
end

function _tag_index_at(widget::TagInput, state::TagInputState, position::Position, area::Rect)
    position.row == area.row || return nothing
    column = area.column
    for (index, tag) in enumerate(state.tags)
        token = "[$tag]"
        width = text_width(token)
        column <= position.column < column + width && return index
        column += width + text_width(widget.separator)
    end
    return nothing
end

function handle!(state::TagInputState, widget::TagInput, event::MouseEvent, area::Rect)
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    contains(area, event.position) || return false
    index = _tag_index_at(widget, state, event.position, area)
    index === nothing && return false
    remove_tag!(state, index)
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::TagInput, state::TagInputState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            focusable=true,
            value=join(state.tags, ", "),
        ),
        actions=[Accessibility.FocusSemanticAction, Accessibility.SetValueSemanticAction],
        metadata=Dict(:tag_count => length(state.tags), :maximum => state.maximum),
    )
end

function SemanticToolkit.widget_semantic_children(::TagInput, state::TagInputState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(index)",
            Accessibility.ListItemRole;
            label=tag,
            actions=[Accessibility.ActivateSemanticAction],
        ) for (index, tag) in enumerate(state.tags)
    ]
end

"""
Immediate slider widget backed by the stable `SliderState` control model.

`Slider` provides a direct renderable wrapper around the advanced-control slider
state machine. Applications keep `SliderState` between frames; the widget
contributes width, bindings, and semantic labeling.
"""
struct Slider
    minimum::Float64
    maximum::Float64
    value::Float64
    step::Float64
    width::Int
    disabled::Bool
    bindings::AdvancedControlBindings
    label::String
end

function Slider(
    minimum::Real=0,
    maximum::Real=100;
    value::Real=minimum,
    step::Real=1,
    width::Integer=20,
    disabled::Bool=false,
    bindings::AdvancedControlBindings=default_advanced_control_bindings(),
    label::AbstractString="Slider",
)
    width > 0 || throw(ArgumentError("slider width must be positive"))
    state = SliderState(minimum, maximum; value, step, disabled)
    return Slider(
        state.minimum,
        state.maximum,
        state.value,
        state.step,
        Int(width),
        Bool(disabled),
        bindings,
        String(label),
    )
end

state_for(widget::Slider) = SliderState(
    widget.minimum,
    widget.maximum;
    value=widget.value,
    step=widget.step,
    disabled=widget.disabled,
)

measure(widget::Slider, available::Rect) =
    Size(min(available.height, 1), min(available.width, widget.width))

function render!(buffer::Buffer, widget::Slider, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function render!(buffer::Buffer, widget::Slider, area::Rect, state::SliderState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    rendered = rich_lines_to_core_text(
        CoreTextAdapter(),
        RichLine[render_slider_control(state; length=min(active.width, widget.width))],
    )
    return render!(buffer, Paragraph(rendered), active)
end

function handle!(state::SliderState, widget::Slider, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    return handle_advanced_control_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    ).consumed
end

function handle!(state::SliderState, widget::Slider, event::MouseEvent, area::Rect)
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    state.disabled && return false
    contains(area, event.position) || return false
    width = min(area.width, widget.width)
    width <= 1 && return false
    fraction = clamp((event.position.column - area.column) / (width - 1), 0, 1)
    set_slider!(state, state.minimum + fraction * (state.maximum - state.minimum))
    return true
end

SemanticToolkit.widget_semantic_descriptor(widget::Slider, state::SliderState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.SliderRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            enabled=!state.disabled,
            focusable=!state.disabled,
            value_now=state.value,
            value_min=state.minimum,
            value_max=state.maximum,
        ),
        actions=state.disabled ? [] : [Accessibility.FocusSemanticAction, Accessibility.SetValueSemanticAction, Accessibility.IncrementSemanticAction, Accessibility.DecrementSemanticAction],
        metadata=Dict(:step => state.step),
    )

"""
Immediate range slider widget backed by `RangeSliderState`.

`RangeSlider` exposes two explicit handles over one track. The active handle
moves with the shared advanced-control key bindings; pointer release selects the
nearest handle and moves it to the clicked value.
"""
struct RangeSlider
    minimum::Float64
    maximum::Float64
    lower::Float64
    upper::Float64
    step::Float64
    active::RangeSliderHandle
    allow_crossing::Bool
    width::Int
    disabled::Bool
    bindings::AdvancedControlBindings
    label::String
end

function RangeSlider(
    minimum::Real=0,
    maximum::Real=100;
    lower::Real=minimum,
    upper::Real=maximum,
    step::Real=1,
    active::RangeSliderHandle=LowerRangeHandle,
    allow_crossing::Bool=false,
    width::Integer=20,
    disabled::Bool=false,
    bindings::AdvancedControlBindings=default_advanced_control_bindings(),
    label::AbstractString="Range slider",
)
    width > 0 || throw(ArgumentError("range slider width must be positive"))
    state = RangeSliderState(
        minimum,
        maximum;
        lower,
        upper,
        step,
        active,
        allow_crossing,
        disabled,
    )
    return RangeSlider(
        state.minimum,
        state.maximum,
        state.lower,
        state.upper,
        state.step,
        state.active,
        state.allow_crossing,
        Int(width),
        Bool(disabled),
        bindings,
        String(label),
    )
end

state_for(widget::RangeSlider) = RangeSliderState(
    widget.minimum,
    widget.maximum;
    lower=widget.lower,
    upper=widget.upper,
    step=widget.step,
    active=widget.active,
    allow_crossing=widget.allow_crossing,
    disabled=widget.disabled,
)

measure(widget::RangeSlider, available::Rect) =
    Size(min(available.height, 1), min(available.width, widget.width))

function render!(buffer::Buffer, widget::RangeSlider, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function render!(buffer::Buffer, widget::RangeSlider, area::Rect, state::RangeSliderState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    rendered = rich_lines_to_core_text(
        CoreTextAdapter(),
        RichLine[render_range_slider_control(state; length=min(active.width, widget.width))],
    )
    return render!(buffer, Paragraph(rendered), active)
end

function handle!(state::RangeSliderState, widget::RangeSlider, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    return handle_advanced_control_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    ).consumed
end

function handle!(state::RangeSliderState, widget::RangeSlider, event::MouseEvent, area::Rect)
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    state.disabled && return false
    contains(area, event.position) || return false
    width = min(area.width, widget.width)
    width <= 1 && return false
    fraction = clamp((event.position.column - area.column) / (width - 1), 0, 1)
    value = state.minimum + fraction * (state.maximum - state.minimum)
    if abs(value - state.lower) <= abs(value - state.upper)
        state.active = LowerRangeHandle
        set_range_slider!(state, value, state.upper)
    else
        state.active = UpperRangeHandle
        set_range_slider!(state, state.lower, value)
    end
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::RangeSlider, state::RangeSliderState)
    node = range_slider_semantic_node(state, "range-slider"; label=widget.label)
    return SemanticToolkit.SemanticDescriptor(
        node.role;
        label=node.label,
        state=node.state,
        actions=node.actions,
        metadata=Dict(:step => state.step, :active => state.active),
    )
end

function SemanticToolkit.widget_semantic_children(::RangeSlider, state::RangeSliderState, id)
    return range_slider_semantic_node(state, id).children
end

function _semantic_bool_value(value)
    value isa Bool && return value
    value isa Integer && return value != 0
    text = lowercase(strip(string(value)))
    text in ("true", "t", "yes", "y", "on", "checked", "enabled", "1") && return true
    text in ("false", "f", "no", "n", "off", "unchecked", "disabled", "0") && return false
    throw(ArgumentError("boolean semantic value must be a Bool or boolean-like string"))
end

function register_checkbox_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::Checkbox,
    state::CheckboxState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.checked)
        elseif request.action == Accessibility.ActivateSemanticAction ||
               request.action == Accessibility.SelectSemanticAction
            state.checked = !state.checked
            return Accessibility.SemanticActionResult(true; value=state.checked)
        elseif request.action == Accessibility.SetValueSemanticAction
            try
                state.checked = _semantic_bool_value(request.value)
                return Accessibility.SemanticActionResult(true; value=state.checked)
            catch
                return Accessibility.SemanticActionResult(false; message="checkbox value must be boolean-like")
            end
        end
        return Accessibility.SemanticActionResult(false; message="checkbox semantic action is not supported")
    end)
    return dispatcher
end

register_check_box_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::CheckBox,
    state::CheckBoxState,
) = register_checkbox_semantic_handlers!(dispatcher, id, Checkbox(""), state)

function register_toggle_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::Toggle,
    state::ToggleState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.enabled)
        elseif request.action == Accessibility.ActivateSemanticAction ||
               request.action == Accessibility.SelectSemanticAction
            state.enabled = !state.enabled
            return Accessibility.SemanticActionResult(true; value=state.enabled)
        elseif request.action == Accessibility.SetValueSemanticAction
            try
                state.enabled = _semantic_bool_value(request.value)
                return Accessibility.SemanticActionResult(true; value=state.enabled)
            catch
                return Accessibility.SemanticActionResult(false; message="toggle value must be boolean-like")
            end
        end
        return Accessibility.SemanticActionResult(false; message="toggle semantic action is not supported")
    end)
    return dispatcher
end

register_switch_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::Switch,
    state::SwitchState,
) = register_toggle_semantic_handlers!(dispatcher, id, Toggle(), state)

function register_slider_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::Slider,
    state::SliderState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        state.disabled && return Accessibility.SemanticActionResult(false; message="slider is disabled")
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.value)
        elseif request.action == Accessibility.SetValueSemanticAction
            try
                set_slider!(state, parse(Float64, string(request.value)))
                return Accessibility.SemanticActionResult(true; value=state.value)
            catch
                return Accessibility.SemanticActionResult(false; message="slider value must be numeric")
            end
        elseif request.action == Accessibility.IncrementSemanticAction
            increment_slider!(state)
            return Accessibility.SemanticActionResult(true; value=state.value)
        elseif request.action == Accessibility.DecrementSemanticAction
            decrement_slider!(state)
            return Accessibility.SemanticActionResult(true; value=state.value)
        end
        return Accessibility.SemanticActionResult(false; message="slider semantic action is not supported")
    end)
    return dispatcher
end

function _set_range_slider_semantic_value!(state::RangeSliderState, value)
    if value isa Tuple && length(value) >= 2
        set_range_slider!(state, parse(Float64, string(value[1])), parse(Float64, string(value[2])))
    elseif value isa AbstractVector && length(value) >= 2
        set_range_slider!(state, parse(Float64, string(value[1])), parse(Float64, string(value[2])))
    else
        current = parse(Float64, string(value))
        state.active == LowerRangeHandle ?
            set_range_slider!(state, current, state.upper) :
            set_range_slider!(state, state.lower, current)
    end
    return state
end

function _range_slider_semantic_value(state::RangeSliderState)
    return Dict(:lower => state.lower, :upper => state.upper, :active => state.active)
end

function register_range_slider_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::RangeSlider,
    state::RangeSliderState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        state.disabled && return Accessibility.SemanticActionResult(false; message="range slider is disabled")
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=_range_slider_semantic_value(state))
        elseif request.action == Accessibility.SetValueSemanticAction
            try
                _set_range_slider_semantic_value!(state, request.value)
                return Accessibility.SemanticActionResult(true; value=_range_slider_semantic_value(state))
            catch
                return Accessibility.SemanticActionResult(false; message="range slider value must be numeric or a lower/upper pair")
            end
        elseif request.action == Accessibility.IncrementSemanticAction
            move_range_slider!(state, 1)
            return Accessibility.SemanticActionResult(true; value=_range_slider_semantic_value(state))
        elseif request.action == Accessibility.DecrementSemanticAction
            move_range_slider!(state, -1)
            return Accessibility.SemanticActionResult(true; value=_range_slider_semantic_value(state))
        elseif request.action == Accessibility.ActivateSemanticAction ||
               request.action == Accessibility.SelectSemanticAction
            switch_range_handle!(state)
            return Accessibility.SemanticActionResult(true; value=_range_slider_semantic_value(state))
        end
        return Accessibility.SemanticActionResult(false; message="range slider semantic action is not supported")
    end)
    for (suffix, handle) in (("lower", LowerRangeHandle), ("upper", UpperRangeHandle))
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/$suffix", function (request)
            state.disabled && return Accessibility.SemanticActionResult(false; message="range slider is disabled")
            state.active = handle
            if request.action == Accessibility.FocusSemanticAction ||
               request.action == Accessibility.SelectSemanticAction
                return Accessibility.SemanticActionResult(true; value=_range_slider_semantic_value(state))
            elseif request.action == Accessibility.SetValueSemanticAction
                try
                    value = parse(Float64, string(request.value))
                    handle == LowerRangeHandle ? set_range_slider!(state, value, state.upper) :
                        set_range_slider!(state, state.lower, value)
                    return Accessibility.SemanticActionResult(true; value=_range_slider_semantic_value(state))
                catch
                    return Accessibility.SemanticActionResult(false; message="range slider handle value must be numeric")
                end
            elseif request.action == Accessibility.IncrementSemanticAction
                move_range_slider!(state, 1)
                return Accessibility.SemanticActionResult(true; value=_range_slider_semantic_value(state))
            elseif request.action == Accessibility.DecrementSemanticAction
                move_range_slider!(state, -1)
                return Accessibility.SemanticActionResult(true; value=_range_slider_semantic_value(state))
            end
            return Accessibility.SemanticActionResult(false; message="range slider handle semantic action is not supported")
        end)
    end
    return dispatcher
end

"""
Immediate collapsible disclosure container backed by `CollapsibleState`.

`Collapsible` renders a toggle header and an optional child region. Keep the
returned `CollapsibleState` between frames so expanded/collapsed state survives
redraws.
"""
struct Collapsible{W}
    title::String
    child::W
    width::Int
    height::Int
    expanded::Bool
    disabled::Bool
    collapsed_marker::String
    expanded_marker::String
    bindings::AdvancedControlBindings
end

function Collapsible(
    title::AbstractString,
    child;
    width::Integer=80,
    height::Integer=4,
    expanded::Bool=false,
    disabled::Bool=false,
    collapsed_marker::AbstractString="+",
    expanded_marker::AbstractString="-",
    bindings::AdvancedControlBindings=default_advanced_control_bindings(),
)
    width > 0 || throw(ArgumentError("collapsible width must be positive"))
    height > 0 || throw(ArgumentError("collapsible height must be positive"))
    return Collapsible(
        String(title),
        child,
        Int(width),
        Int(height),
        Bool(expanded),
        Bool(disabled),
        String(collapsed_marker),
        String(expanded_marker),
        bindings,
    )
end

state_for(widget::Collapsible) =
    CollapsibleState(expanded=widget.expanded, disabled=widget.disabled)

measure(widget::Collapsible, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::Collapsible, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function render!(buffer::Buffer, widget::Collapsible, area::Rect, state::CollapsibleState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    header = render_collapsible_control(
        state,
        widget.title;
        collapsed_marker=widget.collapsed_marker,
        expanded_marker=widget.expanded_marker,
    )
    render!(
        buffer,
        Paragraph(rich_lines_to_core_text(CoreTextAdapter(), RichLine[header])),
        Rect(active.row, active.column, 1, active.width),
    )
    if state.expanded && active.height > 1
        child_area = Rect(active.row + 1, active.column, min(active.height - 1, widget.height - 1), active.width)
        render!(buffer, widget.child, child_area)
    end
    return buffer
end

function handle!(state::CollapsibleState, widget::Collapsible, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    return handle_advanced_control_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    ).consumed
end

function handle!(state::CollapsibleState, ::Collapsible, event::MouseEvent, area::Rect)
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    contains(Rect(area.row, area.column, 1, area.width), event.position) || return false
    state.disabled && return false
    toggle_collapsible!(state)
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::Collapsible, state::CollapsibleState)
    node = collapsible_semantic_node(state, "collapsible"; label=widget.title)
    return SemanticToolkit.SemanticDescriptor(
        node.role;
        label=node.label,
        state=node.state,
        actions=node.actions,
        metadata=Dict(:child_type => string(typeof(widget.child))),
    )
end

function register_collapsible_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::CollapsibleState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        state.disabled && return Accessibility.SemanticActionResult(false; message="collapsible is disabled")
        if request.action == Accessibility.ActivateSemanticAction
            toggle_collapsible!(state)
            return Accessibility.SemanticActionResult(true; value=state.expanded)
        elseif request.action == Accessibility.ExpandSemanticAction
            expand_collapsible!(state)
            return Accessibility.SemanticActionResult(true; value=state.expanded)
        elseif request.action == Accessibility.CollapseSemanticAction
            collapse_collapsible!(state)
            return Accessibility.SemanticActionResult(true; value=state.expanded)
        elseif request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.expanded)
        end
        return Accessibility.SemanticActionResult(false; message="collapsible semantic action is not supported")
    end)
    return dispatcher
end

"""
Immediate accordion disclosure list backed by `AccordionState`.

`Accordion` renders a list of section headers and each expanded section's child
content. The state stores the set of expanded keys, while the widget owns labels,
children, layout sizing, markers, and input policy.
"""
struct Accordion{K}
    items::Vector{Tuple{K,String,Any}}
    width::Int
    item_height::Int
    multiple::Bool
    expanded::Vector{K}
    collapsed_marker::String
    expanded_marker::String
    label::String
end

function Accordion(
    items::AbstractVector{<:Tuple};
    width::Integer=80,
    item_height::Integer=1,
    multiple::Bool=false,
    expanded=Any[],
    collapsed_marker::AbstractString="+",
    expanded_marker::AbstractString="-",
    label::AbstractString="Accordion",
)
    width > 0 || throw(ArgumentError("accordion width must be positive"))
    item_height > 0 || throw(ArgumentError("accordion item height must be positive"))
    normalized = map(items) do item
        length(item) == 3 || throw(ArgumentError("accordion items must be (key, label, child) tuples"))
        (item[1], String(item[2]), item[3])
    end
    K = isempty(normalized) ? Any : typeof(first(normalized)[1])
    return Accordion{K}(
        Tuple{K,String,Any}[(key, title, child) for (key, title, child) in normalized],
        Int(width),
        Int(item_height),
        Bool(multiple),
        Vector{K}(expanded),
        String(collapsed_marker),
        String(expanded_marker),
        String(label),
    )
end

state_for(widget::Accordion{K}) where {K} =
    AccordionState{K}(expanded=widget.expanded, multiple=widget.multiple)

measure(widget::Accordion, available::Rect) =
    Size(min(available.height, max(1, length(widget.items) * (1 + widget.item_height))), min(available.width, widget.width))

function render!(buffer::Buffer, widget::Accordion, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function render!(buffer::Buffer, widget::Accordion, area::Rect, state::AccordionState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    headers = render_accordion_control(
        state,
        [(key, title) for (key, title, _) in widget.items];
        marker_open=widget.expanded_marker,
        marker_closed=widget.collapsed_marker,
    )
    row = active.row
    for (index, (key, _, child)) in enumerate(widget.items)
        row > active.row + active.height - 1 && break
        render!(
            buffer,
            Paragraph(rich_lines_to_core_text(CoreTextAdapter(), RichLine[headers[index]])),
            Rect(row, active.column, 1, active.width),
        )
        row += 1
        if key in state.expanded && row <= active.row + active.height - 1
            child_height = min(widget.item_height, active.row + active.height - row)
            render!(buffer, child, Rect(row, active.column, child_height, active.width))
            row += child_height
        end
    end
    return buffer
end

function handle!(state::AccordionState, widget::Accordion, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    event.key.code == :enter || event.key.code == :space ||
        (event.key.code == :character && event.text == " ") || return false
    isempty(widget.items) && return false
    toggle_accordion!(state, first(widget.items)[1])
    return true
end

function _accordion_key_at(widget::Accordion, state::AccordionState, row::Int)
    current = 1
    for (key, _, _) in widget.items
        row == current && return key
        current += 1
        key in state.expanded && (current += widget.item_height)
    end
    return nothing
end

function handle!(state::AccordionState, widget::Accordion, event::MouseEvent, area::Rect)
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    contains(area, event.position) || return false
    key = _accordion_key_at(widget, state, event.position.row - area.row + 1)
    key === nothing && return false
    toggle_accordion!(state, key)
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::Accordion, state::AccordionState)
    tree = accordion_semantic_tree(state, [(key, title) for (key, title, _) in widget.items]; label=widget.label)
    return SemanticToolkit.SemanticDescriptor(
        tree.root.role;
        label=tree.root.label,
        state=tree.root.state,
        actions=tree.root.actions,
        metadata=Dict(:item_count => length(widget.items), :multiple => state.multiple),
    )
end

function SemanticToolkit.widget_semantic_children(widget::Accordion, state::AccordionState, id)
    return accordion_semantic_tree(state, [(key, title) for (key, title, _) in widget.items]; id, label=widget.label).root.children
end

function register_accordion_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Accordion{K},
    state::AccordionState{K},
) where {K}
    node_id = string(id)
    for (registered_index, (key, _, _)) in enumerate(widget.items)
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/$(registered_index)", function (request)
            index = findfirst(item -> item[1] == key, widget.items)
            index === nothing && return Accessibility.SemanticActionResult(false; message="accordion item is not available")
            if request.action == Accessibility.ActivateSemanticAction
                toggle_accordion!(state, key)
                return Accessibility.SemanticActionResult(true; value=key)
            elseif request.action == Accessibility.ExpandSemanticAction
                expand_accordion!(state, key)
                return Accessibility.SemanticActionResult(true; value=key)
            elseif request.action == Accessibility.CollapseSemanticAction
                collapse_accordion!(state, key)
                return Accessibility.SemanticActionResult(true; value=key)
            elseif request.action == Accessibility.FocusSemanticAction
                return Accessibility.SemanticActionResult(true; value=key)
            end
            return Accessibility.SemanticActionResult(false; message="accordion item semantic action is not supported")
        end)
    end
    return dispatcher
end

"""
Rich styled text value alias.

Render a `RichText` directly through `Paragraph`, or compose it from `Span` and
`Line` values before rendering.
"""
struct RichText
    text::Text
end

RichText(line::Line) = RichText(Text([line]))
RichText(lines::AbstractVector{Line}) = RichText(Text(lines))
RichText(content::AbstractString; style::Style=Style(), alignment::HorizontalAlignment=LeftAlign) =
    RichText(Text(content; style, alignment))

render!(buffer::Buffer, widget::RichText, area::Rect) =
    render!(buffer, Paragraph(widget.text), area)

measure(widget::RichText, available::Rect) =
    measure(Paragraph(widget.text), available)

function SemanticToolkit.widget_semantic_descriptor(widget::RichText, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Rich text",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:line_count => length(widget.text.lines)),
    )
end

register_rich_text_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::RichText) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => "Rich text",
            :text => _core_text_plain(widget.text),
            :line_count => length(widget.text.lines),
        ),
        "rich text semantic action is not supported",
    )

"""
Dedicated code viewer with explicit state and key bindings.

The wrapper stores immutable rendering configuration while `CodeViewState` tracks
interactive cursor and scroll state.
"""
struct CodeView
    source::String
    language::String
    width::Int
    height::Int
    show_line_numbers::Bool
    bindings::CodeViewBindings
    clipboard::Union{Nothing,ClipboardService}
end

function CodeView(
    source::AbstractString;
    language::AbstractString="",
    width::Integer=80,
    height::Integer=24,
    show_line_numbers::Bool=true,
    bindings::CodeViewBindings=default_code_view_bindings(),
    clipboard::Union{Nothing,ClipboardService}=nothing,
)
    width > 0 || throw(ArgumentError("code view width must be positive"))
    height >= 0 || throw(ArgumentError("code view height cannot be negative"))
    return CodeView(
        String(source),
        String(language),
        Int(width),
        Int(height),
        Bool(show_line_numbers),
        bindings,
        clipboard,
    )
end

state_for(widget::CodeView) = CodeViewState(
    widget.source;
    language=widget.language,
    show_line_numbers=widget.show_line_numbers,
)

measure(widget::CodeView, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::CodeView, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function render!(buffer::Buffer, widget::CodeView, area::Rect, state::CodeViewState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    width = active.width
    height = active.height
    if width == 0 || height == 0
        return buffer
    end
    rendered = render_code_view(
        state;
        width=min(width, widget.width),
        height=min(height, widget.height),
    )
    return render!(
        buffer,
        Paragraph(rich_lines_to_core_text(CoreTextAdapter(), rendered.lines)),
        active,
    )
end

function handle!(state::CodeViewState, widget::CodeView, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_code_view_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
        viewport_height=widget.height,
        clipboard=widget.clipboard,
    )
    return result.consumed
end

function handle!(
    state::CodeViewState,
    widget::CodeView,
    event::MouseEvent,
    area::Rect;
    wheel_step::Integer=3,
)
    contains(area, event.position) || return false
    event.action == MouseScroll || return false
    wheel_step > 0 || throw(ArgumentError("code view wheel step must be positive"))
    if event.button == WheelUpButton
        scroll_code_view!(state, -wheel_step; viewport_height=widget.height)
        return true
    end
    if event.button == WheelDownButton
        scroll_code_view!(state, wheel_step; viewport_height=widget.height)
        return true
    end
    return false
end

function SemanticToolkit.widget_semantic_descriptor(widget::CodeView, state::CodeViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label=isempty(widget.language) ? "Code view" : "$(widget.language) source",
        state=Accessibility.SemanticState(
            focusable=true,
            readonly=true,
            invalid=any(diagnostic -> diagnostic.severity == CodeError, state.diagnostics),
            value="$(length(state.lines)) lines",
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:language => state.language, :first_line => state.first_line, :revision => state.revision),
    )
end

function register_code_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::CodeView,
    state::CodeViewState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.cursor_line)
        elseif request.action == Accessibility.ScrollIntoViewSemanticAction
            scroll_code_view!(state, 0; viewport_height=widget.height)
            return Accessibility.SemanticActionResult(true; value=state.first_line)
        elseif request.action == Accessibility.IncrementSemanticAction
            move_code_cursor!(state, 1; viewport_height=widget.height)
            return Accessibility.SemanticActionResult(true; value=state.cursor_line)
        elseif request.action == Accessibility.DecrementSemanticAction
            move_code_cursor!(state, -1; viewport_height=widget.height)
            return Accessibility.SemanticActionResult(true; value=state.cursor_line)
        end
        return Accessibility.SemanticActionResult(false; message="code view semantic action is not supported")
    end)
    return dispatcher
end

"""
Dedicated diff viewer with explicit `ScrollState` and shared scroll interactions.
"""
struct DiffView
    diff::UnifiedDiff
    width::Int
    height::Int
end

function DiffView(
    diff::UnifiedDiff;
    width::Integer=100,
    height::Integer=24,
)
    width > 0 || throw(ArgumentError("diff view width must be positive"))
    height >= 0 || throw(ArgumentError("diff view height cannot be negative"))
    return DiffView(diff, Int(width), Int(height))
end

const DiffViewState = ScrollState
state_for(::DiffView) = DiffViewState()

measure(widget::DiffView, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::DiffView, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function _diff_max_scroll(widget::DiffView, viewport_height::Integer)
    total = length(widget.diff.lines)
    viewport = max(0, Int(viewport_height))
    return max(0, total - viewport)
end

function render!(buffer::Buffer, widget::DiffView, area::Rect, state::DiffViewState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    width = active.width
    height = active.height
    if width == 0 || height == 0
        return buffer
    end
    content_height = min(height, widget.height)
    max_scroll = _diff_max_scroll(widget, content_height)
    state.row = clamp(state.row, 0, max_scroll)
    start_line = clamp(state.row + 1, 1, max(1, length(widget.diff.lines)))
    lines = render_unified_diff(
        widget.diff;
        width=min(width, widget.width),
        height=content_height,
        first_line=start_line,
    )
    rendered = rich_lines_to_core_text(CoreTextAdapter(), lines)
    return render!(buffer, Paragraph(rendered), active)
end

function handle!(state::DiffViewState, widget::DiffView, event::KeyEvent; page_step::Integer=10)
    event.kind in (KeyPress, KeyRepeat) || return false
    key = event.key.code
    new_row = state.row
    if key == :up
        new_row = max(0, state.row - 1)
    elseif key == :down
        new_row = new_row + 1
    elseif key == :page_up
        new_row = max(0, new_row - max(1, page_step))
    elseif key == :page_down
        new_row = new_row + max(1, page_step)
    elseif key == :home
        new_row = 0
    elseif key == :end
        new_row = _diff_max_scroll(widget, widget.height)
    else
        return false
    end
    state.row = min(_diff_max_scroll(widget, widget.height), max(0, new_row))
    return true
end

function handle!(
    state::DiffViewState,
    widget::DiffView,
    event::MouseEvent,
    area::Rect;
    wheel_step::Integer=3,
)
    contains(area, event.position) || return false
    event.action == MouseScroll || return false
    wheel_step > 0 || throw(ArgumentError("diff view wheel step must be positive"))
    if event.button == WheelUpButton
        state.row = max(0, state.row - wheel_step)
    elseif event.button == WheelDownButton
        state.row = state.row + wheel_step
    else
        return false
    end
    state.row = min(_diff_max_scroll(widget, widget.height), max(0, state.row))
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::DiffView, state::DiffViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label="Unified diff",
        state=Accessibility.SemanticState(
            focusable=true,
            readonly=true,
            value="$(length(widget.diff.lines)) lines",
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.row),
    )
end

function register_diff_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DiffView,
    state::DiffViewState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        maximum = _diff_max_scroll(widget, widget.height)
        if request.action == Accessibility.FocusSemanticAction || request.action == Accessibility.ScrollIntoViewSemanticAction
            state.row = clamp(state.row, 0, maximum)
            return Accessibility.SemanticActionResult(true; value=state.row)
        elseif request.action == Accessibility.IncrementSemanticAction
            state.row = min(maximum, state.row + 1)
            return Accessibility.SemanticActionResult(true; value=state.row)
        elseif request.action == Accessibility.DecrementSemanticAction
            state.row = max(0, state.row - 1)
            return Accessibility.SemanticActionResult(true; value=state.row)
        end
        return Accessibility.SemanticActionResult(false; message="diff view semantic action is not supported")
    end)
    return dispatcher
end

"""
Stateful adapter for markdown rendering with mutable input bindings and link policy.
"""
mutable struct MarkdownState
    view::MarkdownView
    bindings::MarkdownBindings
    viewport_height::Int
    allow_unsafe_links::Bool
end

function MarkdownState(
    view::MarkdownView;
    bindings::MarkdownBindings=default_markdown_bindings(),
    viewport_height::Integer=1,
    allow_unsafe_links::Bool=false,
)
    viewport_height >= 0 || throw(ArgumentError("markdown viewport height cannot be negative"))
    return MarkdownState(
        view,
        bindings,
        Int(viewport_height),
        Bool(allow_unsafe_links),
    )
end

state_for(view::MarkdownView) = MarkdownState(view)

function SemanticToolkit.widget_semantic_descriptor(widget::MarkdownView, state::MarkdownState)
    links = state.view.rendered.links
    focusable = !isempty(links)
    unsafe_links = count(link -> !link.target.safe, links)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Markdown document",
        state=Accessibility.SemanticState(
            enabled=true,
            focusable=focusable,
            focused=false,
        ),
        actions=focusable ? Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.ActivateSemanticAction,
        ] : Accessibility.SemanticAction[Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict{Symbol,Any}(
            :line_count => markdown_line_count(widget),
            :link_count => length(links),
            :unsafe_link_count => unsafe_links,
            :scroll_offset => state.view.scroll,
        ),
    )
end

function _markdown_activation_result(activation::LinkActivation)
    activation.link === nothing && return Accessibility.SemanticActionResult(false; message=string(activation.reason))
    return Accessibility.SemanticActionResult(
        activation.allowed;
        value=activation.link.target.uri,
        message=activation.allowed ? "" : string(activation.reason),
    )
end

function register_markdown_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::MarkdownState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            focus_next_link!(state.view)
            ensure_focused_link_visible!(state.view, max(1, state.viewport_height))
            return Accessibility.SemanticActionResult(true; value=state.view.focused_link)
        elseif request.action == Accessibility.ScrollIntoViewSemanticAction
            ensure_focused_link_visible!(state.view, max(1, state.viewport_height))
            scroll_markdown_to!(state.view, state.view.scroll; viewport_height=state.viewport_height)
            return Accessibility.SemanticActionResult(true; value=state.view.scroll)
        elseif request.action == Accessibility.IncrementSemanticAction
            scroll_markdown_by!(state.view, 1; viewport_height=state.viewport_height)
            return Accessibility.SemanticActionResult(true; value=state.view.scroll)
        elseif request.action == Accessibility.DecrementSemanticAction
            scroll_markdown_by!(state.view, -1; viewport_height=state.viewport_height)
            return Accessibility.SemanticActionResult(true; value=state.view.scroll)
        elseif request.action == Accessibility.ActivateSemanticAction
            return _markdown_activation_result(activate_focused_link(state.view; allow_unsafe=state.allow_unsafe_links))
        end
        return Accessibility.SemanticActionResult(false; message="markdown view semantic action is not supported")
    end)
    for link in state.view.rendered.links
        link_id = link.id
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/link/$(link_id)", function (request)
            if request.action == Accessibility.FocusSemanticAction
                focus_link!(state.view, link_id)
                ensure_focused_link_visible!(state.view, max(1, state.viewport_height))
                return Accessibility.SemanticActionResult(true; value=link.target.uri)
            elseif request.action == Accessibility.ActivateSemanticAction
                focus_link!(state.view, link_id)
                return _markdown_activation_result(activate_link(state.view, link_id; allow_unsafe=state.allow_unsafe_links))
            end
            return Accessibility.SemanticActionResult(false; message="markdown link semantic action is not supported")
        end)
    end
    return dispatcher
end

function SemanticToolkit.widget_semantic_children(widget::MarkdownView, state::MarkdownState, id)
    children = Accessibility.SemanticNode[]
    for link in state.view.rendered.links
        enabled = link.target.safe || state.allow_unsafe_links
        push!(
            children,
            Accessibility.SemanticNode(
                "$(id)/link/$(link.id)",
                Accessibility.LinkRole;
                label=link.label,
                state=Accessibility.SemanticState(
                    enabled=enabled,
                    focusable=true,
                    focused=state.view.focused_link == link.id,
                ),
                actions=enabled ? Accessibility.SemanticAction[
                    Accessibility.ActivateSemanticAction,
                    Accessibility.FocusSemanticAction,
                ] : Accessibility.SemanticAction[Accessibility.FocusSemanticAction],
                metadata=Dict{Symbol,Any}(
                    :target => link.target.uri,
                    :safe => link.target.safe,
                    :title => link.target.title,
                ),
            ),
        )
    end
    return children
end

measure(widget::MarkdownView, available::Rect) =
    Size(min(available.height, markdown_line_count(widget)), min(available.width, widget.width))

function render!(buffer::Buffer, widget::MarkdownView, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function _sync_markdown_state(state::MarkdownState, available_width::Integer, available_height::Integer)
    viewport_height = max(0, available_height)
    width = max(1, available_width)
    if state.view.width != width
        reflow_markdown!(state.view, width; viewport_height=viewport_height)
    else
        scroll_markdown_to!(state.view, state.view.scroll; viewport_height=viewport_height)
    end
    state.viewport_height = viewport_height
    return state
end

function render!(buffer::Buffer, widget::MarkdownView, area::Rect, state::MarkdownState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    if active.width == 0 || active.height == 0
        state.viewport_height = active.height
        return buffer
    end
    _sync_markdown_state(state, active.width, active.height)
    text = markdown_core_text(
        CoreTextAdapter(),
        state.view,
        min(active.height, state.viewport_height),
    )
    return render!(buffer, Paragraph(text), active)
end

function handle!(state::MarkdownState, widget::MarkdownView, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_markdown_key!(
        state.view,
        state.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
        viewport_height=max(1, state.viewport_height),
        allow_unsafe=state.allow_unsafe_links,
    )
    return result.consumed
end

function handle!(
    state::MarkdownState,
    widget::MarkdownView,
    event::MouseEvent,
    area::Rect;
    allow_unsafe::Union{Nothing,Bool}=nothing,
)
    if !contains(area, event.position)
        event.action == MouseMove || return false
        result = handle_markdown_pointer!(state.view, MarkdownPointerEvent(PointerLeave, 0, 0);
            allow_unsafe=something(allow_unsafe, state.allow_unsafe_links))
        return result.consumed === true
    end
    if state.viewport_height == 0
        return false
    end
    row = event.position.row - area.row + 1
    column = event.position.column - area.column + 1
    if event.action == MouseMove
        pointer = MarkdownPointerEvent(PointerHover, row, column)
    elseif event.action == MousePress && event.button == LeftMouseButton
        pointer = MarkdownPointerEvent(PointerPress, row, column)
    else
        return false
    end
    result = handle_markdown_pointer!(
        state.view,
        pointer;
        allow_unsafe=something(allow_unsafe, state.allow_unsafe_links),
    )
    return result.consumed === true
end

"""
Dedicated single-box layer container with draw order semantics.
"""
struct Layer{T<:Tuple}
    children::T
end

Layer(children...) = Layer(children)

render!(buffer::Buffer, widget::Layer, area::Rect) = render!(buffer, Stack(widget.children...), area)
measure(widget::Layer, available::Rect) = measure(Stack(widget.children...), available)
SemanticToolkit.widget_semantic_descriptor(::Layer, state) = _static_group_semantics("Layer")

register_layer_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Layer) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Layer", :child_count => length(widget.children)),
        "layer semantic action is not supported",
    )

"""
Dedicated grouping container for multiple children with optional bordered shell.
"""
struct Group{T<:Tuple}
    children::T
    block::Union{Nothing,Block}
    gap::Int
end

function Group(
    children...;
    block::Union{Nothing,Block}=nothing,
    gap::Integer=0,
)
    gap >= 0 || throw(ArgumentError("group gap must be non-negative"))
    Group{typeof(children)}(
        children,
        block,
        Int(gap),
    )
end

function _group_layout(widget::Group)
    content = Column(widget.children...; gap=widget.gap)
    return isnothing(widget.block) ? content : Box(content; block=widget.block)
end

measure(widget::Group, available::Rect) = measure(_group_layout(widget), available)

render!(buffer::Buffer, widget::Group, area::Rect) = render!(buffer, _group_layout(widget), area)
SemanticToolkit.widget_semantic_descriptor(::Group, state) = _static_group_semantics("Group")

register_group_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Group) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Group", :child_count => length(widget.children), :gap => widget.gap),
        "group semantic action is not supported",
    )

"""
Dedicated viewport container for virtualized content.
"""
struct Viewport{W}
    child::W
    content_size::Size
end

Viewport(child, height::Integer, width::Integer) =
    Viewport(child, Size(Int(height), Int(width)))
Viewport(child; height::Integer=1, width::Integer=1) = Viewport(child, height, width)

state_for(::Viewport) = ScrollState()
const ViewportState = ScrollState

measure(widget::Viewport, available::Rect) = Size(
    min(available.height, widget.content_size.height),
    min(available.width, widget.content_size.width),
)

function _scroll_view(widget::Viewport)
    ScrollView(widget.child; height=widget.content_size.height, width=widget.content_size.width)
end

render!(buffer::Buffer, widget::Viewport, area::Rect, state::ViewportState) =
    render!(buffer, _scroll_view(widget), area, state)
render!(buffer::Buffer, widget::Viewport, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::ViewportState, widget::Viewport, event::KeyEvent; page_step::Integer=10)
    handle!(state, _scroll_view(widget), event; page_step=page_step)
end

function handle!(state::ViewportState, widget::Viewport, event::MouseEvent, area::Rect; wheel_step::Integer=3)
    handle!(state, _scroll_view(widget), event, area; wheel_step=wheel_step)
end

SemanticToolkit.widget_semantic_descriptor(widget::Viewport, state::ViewportState) =
    SemanticToolkit.widget_semantic_descriptor(_scroll_view(widget), state)

"""
Compatibility aliases for the broader feature-family names used by the spec and
survey matrix.

These aliases expose existing implementations under additional API names to support
upstream migration and cross-library porting. `RadioButton`, `Combobox`,
`ListBox`, and `TransferList` have dedicated wrappers below while still sharing
`RadioGroupState`, `SelectState`, `ListState`, and `MultiSelectState`.
"""
const RadioButtonState = RadioGroupState
const ListBoxState = ListState
const ComboboxState = SelectState
const TransferListState = MultiSelectState

"""
Radio-button widget backed by the existing `RadioGroupState` selection model.

`RadioButton` gives radio-button naming a direct widget identity while delegating
rendering, keyboard movement, pointer selection, and semantic children to
`RadioGroup`. Passing a collection preserves the historical alias behavior;
passing one label constructs a single-option radio button.
"""
struct RadioButton
    group::RadioGroup
end

function RadioButton(
    options::AbstractVector;
    direction::LayoutDirection=VerticalLayout,
    selected_symbol::AbstractString="(*)",
    unselected_symbol::AbstractString="( )",
    style::Style=Style(),
    selected_style::Style=Style(modifiers=BOLD),
    disabled_style::Style=Style(modifiers=DIM),
    gap::Integer=0,
)
    return RadioButton(RadioGroup(
        options;
        direction,
        selected_symbol,
        unselected_symbol,
        style,
        selected_style,
        disabled_style,
        gap,
    ))
end

function RadioButton(
    value,
    label::AbstractString;
    disabled::Bool=false,
    kwargs...,
)
    return RadioButton([ChoiceOption(value, label; disabled)]; kwargs...)
end

state_for(::RadioButton) = RadioGroupState()
measure(::RadioButton, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, widget::RadioButton, area::Rect) =
    render!(buffer, widget.group, area)
render!(buffer::Buffer, widget::RadioButton, area::Rect, state::RadioGroupState) =
    render!(buffer, widget.group, area, state)
handle!(state::RadioGroupState, widget::RadioButton, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.group, event)
handle!(state::RadioGroupState, widget::RadioButton, event::MouseEvent, area::Rect) =
    handle!(state, widget.group, event, area)
Widgets.selected_value(widget::RadioButton, state::RadioGroupState) =
    selected_value(widget.group, state)

function SemanticToolkit.widget_semantic_descriptor(widget::RadioButton, state::RadioGroupState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Radio button",
        state=Accessibility.SemanticState(focusable=true, focused=state.focused),
        metadata=Dict(:option_count => length(widget.group.options)),
    )
end

SemanticToolkit.widget_semantic_children(widget::RadioButton, state::RadioGroupState, id) =
    SemanticToolkit.widget_semantic_children(widget.group, state, id)

"""
Retained-style combobox widget backed by the existing `SelectState` model.

`Combobox` preserves the historical select-like compatibility spelling while
giving it a direct widget identity. Use `ComboBox` for the autocomplete-backed
editable control; use `Combobox` for a closed/open dropdown that delegates to
`Select`.
"""
struct Combobox
    select::Select
end

function Combobox(
    options::AbstractVector;
    placeholder::AbstractString="Select...",
    block::Union{Nothing,Block}=nothing,
    style::Style=Style(),
    selected_style::Style=Style(modifiers=REVERSED),
    disabled_style::Style=Style(modifiers=DIM),
    open_symbol::AbstractString="▴",
    closed_symbol::AbstractString="▾",
)
    return Combobox(Select(
        options;
        placeholder,
        block,
        style,
        selected_style,
        disabled_style,
        open_symbol,
        closed_symbol,
    ))
end

state_for(::Combobox) = SelectState()
measure(::Combobox, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, widget::Combobox, area::Rect) =
    render!(buffer, widget.select, area)
render!(buffer::Buffer, widget::Combobox, area::Rect, state::SelectState) =
    render!(buffer, widget.select, area, state)
handle!(state::SelectState, widget::Combobox, event::KeyEvent; viewport_height::Integer=5) =
    handle!(state, widget.select, event; viewport_height)
handle!(state::SelectState, widget::Combobox, event::MouseEvent, area::Rect) =
    handle!(state, widget.select, event, area)
Widgets.selected_value(widget::Combobox, state::SelectState) =
    Widgets.selected_value(widget.select, state)

function SemanticToolkit.widget_semantic_descriptor(widget::Combobox, state::SelectState)
    selected = Widgets.selected_value(widget.select, state)
    label = state.selected === nothing || state.selected > length(widget.select.options) ? nothing :
        _line_label(widget.select.options[state.selected].label)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label=widget.select.placeholder,
        state=Accessibility.SemanticState(
            focusable=true,
            focused=state.focused,
            expanded=state.open,
            value=label,
        ),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ActivateSemanticAction, Accessibility.SetValueSemanticAction],
        metadata=Dict(
            :option_count => length(widget.select.options),
            :selected_value => selected,
        ),
    )
end

SemanticToolkit.widget_semantic_children(widget::Combobox, state::SelectState, id) =
    SemanticToolkit.widget_semantic_children(widget.select, state, id)

"""
List-box widget backed by the existing `ListState` selection model.

`ListBox` gives Lanterna/Textual-style list box naming a direct widget identity
while delegating rendering, keyboard movement, pointer selection, and semantic
children to `List`.
"""
struct ListBox
    list::List
end

function ListBox(
    items::AbstractVector;
    block::Union{Nothing,Block}=nothing,
    highlight_style::Style=Style(modifiers=REVERSED),
    highlight_symbol::AbstractString="› ",
)
    return ListBox(List(items; block, highlight_style, highlight_symbol))
end

state_for(::ListBox) = ListState()
measure(::ListBox, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, widget::ListBox, area::Rect) =
    render!(buffer, widget.list, area)
render!(buffer::Buffer, widget::ListBox, area::Rect, state::ListState) =
    render!(buffer, widget.list, area, state)
handle!(state::ListState, widget::ListBox, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.list, event; viewport_height)
handle!(state::ListState, widget::ListBox, event::MouseEvent, area::Rect) =
    handle!(state, widget.list, event, area)

function SemanticToolkit.widget_semantic_descriptor(widget::ListBox, state::ListState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="List box",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SetValueSemanticAction,
        ],
        metadata=Dict(:item_count => length(widget.list.items)),
    )
end

SemanticToolkit.widget_semantic_children(widget::ListBox, state::ListState, id) =
    SemanticToolkit.widget_semantic_children(widget.list, state, id)

"""
Transfer-list widget backed by the existing `MultiSelectState` selection model.

`TransferList` gives transfer-list naming a direct widget identity for workflows
where selected values are treated as the destination set. It delegates rendering,
keyboard movement, pointer toggling, selected-value reads, and semantic children
to `MultiSelect`.
"""
struct TransferList
    multiselect::MultiSelect
end

function TransferList(
    options::AbstractVector;
    checked_symbol::AbstractString="[x]",
    unchecked_symbol::AbstractString="[ ]",
    highlight_style::Style=Style(modifiers=REVERSED),
    disabled_style::Style=Style(modifiers=DIM),
)
    return TransferList(MultiSelect(
        options;
        checked_symbol,
        unchecked_symbol,
        highlight_style,
        disabled_style,
    ))
end

state_for(::TransferList) = MultiSelectState()
measure(::TransferList, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, widget::TransferList, area::Rect) =
    render!(buffer, widget.multiselect, area)
render!(buffer::Buffer, widget::TransferList, area::Rect, state::MultiSelectState) =
    render!(buffer, widget.multiselect, area, state)
handle!(state::MultiSelectState, widget::TransferList, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.multiselect, event; viewport_height)
handle!(state::MultiSelectState, widget::TransferList, event::MouseEvent, area::Rect) =
    handle!(state, widget.multiselect, event, area)
Widgets.selected_values(widget::TransferList, state::MultiSelectState) =
    Widgets.selected_values(widget.multiselect, state)

function SemanticToolkit.widget_semantic_descriptor(widget::TransferList, state::MultiSelectState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Transfer list",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SetValueSemanticAction,
        ],
        metadata=Dict(:option_count => length(widget.multiselect.options), :selected_count => length(state.selected)),
    )
end

SemanticToolkit.widget_semantic_children(widget::TransferList, state::MultiSelectState, id) =
    SemanticToolkit.widget_semantic_children(widget.multiselect, state, id)

function _autocomplete_semantic_value(state::AutocompleteState)
    return Dict(
        :query => state.query,
        :highlighted => state.highlighted,
        :open => state.open,
        :match_count => length(state.matches),
    )
end

function _completion_item_at_visible_index(state::AutocompleteState, visible_index::Integer)
    1 <= visible_index <= length(state.matches) || return nothing
    return state.items[state.matches[Int(visible_index)]]
end

function _set_autocomplete_highlight!(state::AutocompleteState, visible_index::Integer)
    _completion_item_at_visible_index(state, visible_index) === nothing && return false
    state.highlighted = Int(visible_index)
    state.open = true
    return true
end

function register_autocomplete_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::Autocomplete,
    state::AutocompleteState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            state.open = !isempty(state.matches)
            return Accessibility.SemanticActionResult(true; value=_autocomplete_semantic_value(state))
        elseif request.action == Accessibility.SetValueSemanticAction
            update_autocomplete!(state, string(request.value))
            return Accessibility.SemanticActionResult(true; value=_autocomplete_semantic_value(state))
        elseif request.action == Accessibility.IncrementSemanticAction
            move_autocomplete!(state, 1)
            return Accessibility.SemanticActionResult(true; value=_autocomplete_semantic_value(state))
        elseif request.action == Accessibility.DecrementSemanticAction
            move_autocomplete!(state, -1)
            return Accessibility.SemanticActionResult(true; value=_autocomplete_semantic_value(state))
        elseif request.action == Accessibility.SelectSemanticAction ||
               request.action == Accessibility.ActivateSemanticAction
            value = accept_autocomplete!(state)
            return Accessibility.SemanticActionResult(value !== nothing; value)
        elseif request.action == Accessibility.DismissSemanticAction
            close_autocomplete!(state)
            return Accessibility.SemanticActionResult(true; value=_autocomplete_semantic_value(state))
        end
        return Accessibility.SemanticActionResult(false; message="autocomplete semantic action is not supported")
    end)
    for visible_index in collect(visible_completion_range(state))
        child_id = "$(node_id)/$(visible_index)"
        Accessibility.register_semantic_handler!(dispatcher, child_id, function (request)
            item = _completion_item_at_visible_index(state, visible_index)
            item === nothing && return Accessibility.SemanticActionResult(false; message="autocomplete item is not available")
            item.disabled && return Accessibility.SemanticActionResult(false; message="autocomplete item is disabled")
            if request.action == Accessibility.FocusSemanticAction ||
               request.action == Accessibility.SelectSemanticAction
                _set_autocomplete_highlight!(state, visible_index)
                return Accessibility.SemanticActionResult(true; value=item.value)
            elseif request.action == Accessibility.ActivateSemanticAction
                _set_autocomplete_highlight!(state, visible_index)
                value = accept_autocomplete!(state)
                return Accessibility.SemanticActionResult(value !== nothing; value)
            end
            return Accessibility.SemanticActionResult(false; message="autocomplete item semantic action is not supported")
        end)
    end
    return dispatcher
end

function _combobox_semantic_value(state::ComboBoxState)
    return Dict(
        :selected => state.selected,
        :query => state.autocomplete.query,
        :open => state.autocomplete.open,
        :highlighted => state.autocomplete.highlighted,
    )
end

function _set_combobox_semantic_value!(state::ComboBoxState, value)
    label = string(value)
    for (index, item) in enumerate(state.autocomplete.items)
        item.disabled && continue
        if item.value == value || item.label == label || string(item.value) == label
            state.selected = item.value
            update_autocomplete!(state.autocomplete, item.label)
            state.autocomplete.highlighted = findfirst(match -> match == index, state.autocomplete.matches)
            close_autocomplete!(state.autocomplete)
            return true
        end
    end
    state.editable || return false
    set_combobox_query!(state, label)
    return true
end

function register_combobox_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::ComboBox,
    state::ComboBoxState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            state.autocomplete.open = !isempty(state.autocomplete.matches)
            return Accessibility.SemanticActionResult(true; value=_combobox_semantic_value(state))
        elseif request.action == Accessibility.SetValueSemanticAction
            handled = _set_combobox_semantic_value!(state, request.value)
            return Accessibility.SemanticActionResult(handled; value=_combobox_semantic_value(state))
        elseif request.action == Accessibility.IncrementSemanticAction
            move_combobox!(state, 1)
            return Accessibility.SemanticActionResult(true; value=_combobox_semantic_value(state))
        elseif request.action == Accessibility.DecrementSemanticAction
            move_combobox!(state, -1)
            return Accessibility.SemanticActionResult(true; value=_combobox_semantic_value(state))
        elseif request.action == Accessibility.ActivateSemanticAction
            if state.autocomplete.open
                value = accept_combobox!(state)
                return Accessibility.SemanticActionResult(value !== nothing; value=_combobox_semantic_value(state))
            end
            state.autocomplete.open = !isempty(state.autocomplete.matches)
            return Accessibility.SemanticActionResult(state.autocomplete.open; value=_combobox_semantic_value(state))
        elseif request.action == Accessibility.DismissSemanticAction
            close_autocomplete!(state.autocomplete)
            return Accessibility.SemanticActionResult(true; value=_combobox_semantic_value(state))
        end
        return Accessibility.SemanticActionResult(false; message="combo box semantic action is not supported")
    end)
    for visible_index in collect(visible_completion_range(state.autocomplete))
        child_id = "$(node_id)/$(visible_index)"
        Accessibility.register_semantic_handler!(dispatcher, child_id, function (request)
            item = _completion_item_at_visible_index(state.autocomplete, visible_index)
            item === nothing && return Accessibility.SemanticActionResult(false; message="combo box item is not available")
            item.disabled && return Accessibility.SemanticActionResult(false; message="combo box item is disabled")
            if request.action == Accessibility.FocusSemanticAction ||
               request.action == Accessibility.SelectSemanticAction
                _set_autocomplete_highlight!(state.autocomplete, visible_index)
                return Accessibility.SemanticActionResult(true; value=item.value)
            elseif request.action == Accessibility.ActivateSemanticAction
                _set_autocomplete_highlight!(state.autocomplete, visible_index)
                value = accept_combobox!(state)
                return Accessibility.SemanticActionResult(value !== nothing; value=_combobox_semantic_value(state))
            end
            return Accessibility.SemanticActionResult(false; message="combo box item semantic action is not supported")
        end)
    end
    return dispatcher
end

register_combo_box_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ComboBox,
    state::ComboBoxState,
) =
    register_combobox_semantic_handlers!(dispatcher, id, widget, state)

function _tag_semantic_value(state::TagInputState)
    return Dict(:tags => copy(state.tags), :tag_count => length(state.tags), :maximum => state.maximum)
end

function _set_tag_semantic_value!(state::TagInputState, value)
    clear_tags!(state)
    value === nothing && return true
    values = value isa AbstractVector ? value : Any[value]
    handled = true
    for item in values
        handled = add_tag!(state, string(item)) && handled
    end
    return handled
end

function register_tag_input_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::TagInput,
    state::TagInputState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=_tag_semantic_value(state))
        elseif request.action == Accessibility.SetValueSemanticAction
            handled = _set_tag_semantic_value!(state, request.value)
            return Accessibility.SemanticActionResult(handled; value=_tag_semantic_value(state))
        elseif request.action == Accessibility.DismissSemanticAction
            clear_tags!(state)
            return Accessibility.SemanticActionResult(true; value=_tag_semantic_value(state))
        end
        return Accessibility.SemanticActionResult(false; message="tag input semantic action is not supported")
    end)
    for index in eachindex(copy(state.tags))
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/$(index)", function (request)
            if request.action == Accessibility.ActivateSemanticAction ||
               request.action == Accessibility.DismissSemanticAction
                removed = remove_tag!(state, index)
                return Accessibility.SemanticActionResult(removed !== nothing; value=_tag_semantic_value(state))
            end
            return Accessibility.SemanticActionResult(false; message="tag semantic action is not supported")
        end)
    end
    return dispatcher
end

function _transfer_list_semantic_value(widget::TransferList, state::MultiSelectState)
    return Dict(
        :highlighted => state.highlighted,
        :selected => sort!(collect(state.selected)),
        :values => selected_values(widget, state),
    )
end

function _next_transfer_option(widget::TransferList, state::MultiSelectState, delta::Integer)
    options = widget.multiselect.options
    isempty(options) && return nothing
    start = something(state.highlighted, delta >= 0 ? 0 : length(options) + 1)
    index = start
    for _ in eachindex(options)
        index += delta >= 0 ? 1 : -1
        index < 1 && (index = length(options))
        index > length(options) && (index = 1)
        options[index].disabled || return index
    end
    return nothing
end

function _set_transfer_list_values!(widget::TransferList, state::MultiSelectState, value)
    empty!(state.selected)
    value === nothing && return true
    values = value isa AbstractVector ? value : Any[value]
    for requested in values
        label = string(requested)
        index = findfirst(widget.multiselect.options) do option
            !option.disabled &&
                (option.value == requested || option.label == label || string(option.value) == label)
        end
        index === nothing || push!(state.selected, index)
    end
    return true
end

function register_transfer_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::TransferList,
    state::MultiSelectState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            state.highlighted === nothing && (state.highlighted = _next_transfer_option(widget, state, 1))
            return Accessibility.SemanticActionResult(true; value=_transfer_list_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            state.highlighted = _next_transfer_option(widget, state, 1)
            return Accessibility.SemanticActionResult(state.highlighted !== nothing; value=_transfer_list_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            state.highlighted = _next_transfer_option(widget, state, -1)
            return Accessibility.SemanticActionResult(state.highlighted !== nothing; value=_transfer_list_semantic_value(widget, state))
        elseif request.action == Accessibility.SetValueSemanticAction
            _set_transfer_list_values!(widget, state, request.value)
            return Accessibility.SemanticActionResult(true; value=_transfer_list_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="transfer list semantic action is not supported")
    end)
    for index in eachindex(widget.multiselect.options)
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/option-$(index)", function (request)
            1 <= index <= length(widget.multiselect.options) ||
                return Accessibility.SemanticActionResult(false; message="transfer list option is not available")
            current = widget.multiselect.options[index]
            current.disabled && return Accessibility.SemanticActionResult(false; message="transfer list option is disabled")
            if request.action == Accessibility.FocusSemanticAction
                state.highlighted = index
                return Accessibility.SemanticActionResult(true; value=current.value)
            elseif request.action == Accessibility.SelectSemanticAction ||
                   request.action == Accessibility.ActivateSemanticAction
                state.highlighted = index
                index in state.selected ? delete!(state.selected, index) : push!(state.selected, index)
                return Accessibility.SemanticActionResult(true; value=_transfer_list_semantic_value(widget, state))
            end
            return Accessibility.SemanticActionResult(false; message="transfer list option semantic action is not supported")
        end)
    end
    return dispatcher
end

_choice_label(option::ChoiceOption) = join(span.content for span in option.label.spans)
_list_item_label(item::ListItem) = join(span.content for span in item.line.spans)

function _find_choice_index(options, value)
    value isa Integer && 1 <= Int(value) <= length(options) && return Int(value)
    label = string(value)
    return findfirst(options) do option
        !option.disabled && (option.value == value || _choice_label(option) == label || string(option.value) == label)
    end
end

function _radio_semantic_value(widget::RadioGroup, state::RadioGroupState)
    return Dict(:selected => state.selected, :value => selected_value(widget, state), :focused => state.focused)
end

function _set_radio_semantic_value!(widget::RadioGroup, state::RadioGroupState, value)
    index = _find_choice_index(widget.options, value)
    index === nothing && return false
    widget.options[index].disabled && return false
    state.selected = index
    return true
end

function register_radio_group_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::RadioGroup,
    state::RadioGroupState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            state.focused = true
            return Accessibility.SemanticActionResult(true; value=_radio_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            state.selected = Widgets._next_choice(widget.options, something(state.selected, 0), 1)
            return Accessibility.SemanticActionResult(state.selected !== nothing; value=_radio_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            state.selected = Widgets._next_choice(widget.options, something(state.selected, 1), -1)
            return Accessibility.SemanticActionResult(state.selected !== nothing; value=_radio_semantic_value(widget, state))
        elseif request.action == Accessibility.SetValueSemanticAction
            handled = _set_radio_semantic_value!(widget, state, request.value)
            return Accessibility.SemanticActionResult(handled; value=_radio_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="radio group semantic action is not supported")
    end)
    for index in eachindex(widget.options)
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/option-$index", function (request)
            1 <= index <= length(widget.options) ||
                return Accessibility.SemanticActionResult(false; message="radio option is not available")
            option = widget.options[index]
            option.disabled && return Accessibility.SemanticActionResult(false; message="radio option is disabled")
            if request.action == Accessibility.FocusSemanticAction ||
               request.action == Accessibility.SelectSemanticAction ||
               request.action == Accessibility.ActivateSemanticAction
                state.focused = true
                state.selected = index
                return Accessibility.SemanticActionResult(true; value=option.value)
            end
            return Accessibility.SemanticActionResult(false; message="radio option semantic action is not supported")
        end)
    end
    return dispatcher
end

register_radio_set_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::RadioSet,
    state::RadioSetState,
) = register_radio_group_semantic_handlers!(dispatcher, id, widget.group, state)

register_radio_box_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::RadioBoxList,
    state::RadioBoxListState,
) = register_radio_group_semantic_handlers!(dispatcher, id, widget.group, state)

register_radio_button_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::RadioButton,
    state::RadioGroupState,
) = register_radio_group_semantic_handlers!(dispatcher, id, widget.group, state)

function _select_semantic_value(widget::Select, state::SelectState)
    return Dict(
        :selected => state.selected,
        :highlighted => state.highlighted,
        :open => state.open,
        :value => selected_value(widget, state),
    )
end

function _set_select_semantic_value!(widget::Select, state::SelectState, value)
    index = _find_choice_index(widget.options, value)
    index === nothing && return false
    widget.options[index].disabled && return false
    state.selected = index
    state.highlighted = index
    state.open = false
    return true
end

function register_select_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Select,
    state::SelectState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            state.focused = true
            return Accessibility.SemanticActionResult(true; value=_select_semantic_value(widget, state))
        elseif request.action == Accessibility.ActivateSemanticAction
            if state.open && state.highlighted !== nothing && !widget.options[state.highlighted].disabled
                state.selected = state.highlighted
                state.open = false
            else
                state.open = true
                state.highlighted = something(state.selected, Widgets._next_choice(widget.options, 0, 1))
            end
            return Accessibility.SemanticActionResult(true; value=_select_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            state.open = true
            state.highlighted = Widgets._next_choice(widget.options, something(state.highlighted, 0), 1)
            return Accessibility.SemanticActionResult(state.highlighted !== nothing; value=_select_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            state.open = true
            state.highlighted = Widgets._next_choice(widget.options, something(state.highlighted, 1), -1)
            return Accessibility.SemanticActionResult(state.highlighted !== nothing; value=_select_semantic_value(widget, state))
        elseif request.action == Accessibility.SetValueSemanticAction
            handled = _set_select_semantic_value!(widget, state, request.value)
            return Accessibility.SemanticActionResult(handled; value=_select_semantic_value(widget, state))
        elseif request.action == Accessibility.DismissSemanticAction
            state.open = false
            return Accessibility.SemanticActionResult(true; value=_select_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="select semantic action is not supported")
    end)
    for index in eachindex(widget.options)
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/option-$index", function (request)
            1 <= index <= length(widget.options) ||
                return Accessibility.SemanticActionResult(false; message="select option is not available")
            option = widget.options[index]
            option.disabled && return Accessibility.SemanticActionResult(false; message="select option is disabled")
            if request.action == Accessibility.FocusSemanticAction
                state.focused = true
                state.open = true
                state.highlighted = index
                return Accessibility.SemanticActionResult(true; value=option.value)
            elseif request.action == Accessibility.SelectSemanticAction ||
                   request.action == Accessibility.ActivateSemanticAction
                state.focused = true
                state.highlighted = index
                state.selected = index
                state.open = false
                return Accessibility.SemanticActionResult(true; value=option.value)
            end
            return Accessibility.SemanticActionResult(false; message="select option semantic action is not supported")
        end)
    end
    return dispatcher
end

register_combobox_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Combobox,
    state::ComboboxState,
) = register_select_semantic_handlers!(dispatcher, id, widget.select, state)

function _multi_select_semantic_value(widget::MultiSelect, state::MultiSelectState)
    return Dict(
        :highlighted => state.highlighted,
        :selected => sort!(collect(state.selected)),
        :values => selected_values(widget, state),
    )
end

function _set_multi_select_values!(widget::MultiSelect, state::MultiSelectState, value)
    empty!(state.selected)
    value === nothing && return true
    values = value isa AbstractVector ? value : Any[value]
    for requested in values
        index = _find_choice_index(widget.options, requested)
        index === nothing || push!(state.selected, index)
    end
    return true
end

function register_multi_select_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::MultiSelect,
    state::MultiSelectState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            state.highlighted === nothing && (state.highlighted = Widgets._next_choice(widget.options, 0, 1))
            return Accessibility.SemanticActionResult(true; value=_multi_select_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            state.highlighted = Widgets._next_choice(widget.options, something(state.highlighted, 0), 1)
            return Accessibility.SemanticActionResult(state.highlighted !== nothing; value=_multi_select_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            state.highlighted = Widgets._next_choice(widget.options, something(state.highlighted, 1), -1)
            return Accessibility.SemanticActionResult(state.highlighted !== nothing; value=_multi_select_semantic_value(widget, state))
        elseif request.action == Accessibility.SetValueSemanticAction
            _set_multi_select_values!(widget, state, request.value)
            return Accessibility.SemanticActionResult(true; value=_multi_select_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="multi-select semantic action is not supported")
    end)
    for index in eachindex(widget.options)
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/option-$index", function (request)
            1 <= index <= length(widget.options) ||
                return Accessibility.SemanticActionResult(false; message="multi-select option is not available")
            option = widget.options[index]
            option.disabled && return Accessibility.SemanticActionResult(false; message="multi-select option is disabled")
            if request.action == Accessibility.FocusSemanticAction
                state.highlighted = index
                return Accessibility.SemanticActionResult(true; value=option.value)
            elseif request.action == Accessibility.SelectSemanticAction ||
                   request.action == Accessibility.ActivateSemanticAction
                state.highlighted = index
                index in state.selected ? delete!(state.selected, index) : push!(state.selected, index)
                return Accessibility.SemanticActionResult(true; value=_multi_select_semantic_value(widget, state))
            end
            return Accessibility.SemanticActionResult(false; message="multi-select option semantic action is not supported")
        end)
    end
    return dispatcher
end

register_selection_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::SelectionList,
    state::SelectionListState,
) = register_multi_select_semantic_handlers!(dispatcher, id, widget.multiselect, state)

register_check_box_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::CheckBoxList,
    state::CheckBoxListState,
) = register_multi_select_semantic_handlers!(dispatcher, id, widget.multiselect, state)

function _list_semantic_value(widget::List, state::ListState)
    label = state.selected === nothing || state.selected > length(widget.items) ? nothing :
            _list_item_label(widget.items[state.selected])
    return Dict(:selected => state.selected, :value => label)
end

function _set_list_semantic_value!(widget::List, state::ListState, value)
    if value isa Integer && 1 <= Int(value) <= length(widget.items)
        state.selected = Int(value)
        return true
    end
    label = string(value)
    index = findfirst(item -> _list_item_label(item) == label, widget.items)
    index === nothing && return false
    state.selected = index
    return true
end

function register_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::List,
    state::ListState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction ||
           request.action == Accessibility.ScrollIntoViewSemanticAction
            state.selected === nothing && !isempty(widget.items) && (state.selected = 1)
            return Accessibility.SemanticActionResult(true; value=_list_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            isempty(widget.items) && return Accessibility.SemanticActionResult(false; message="list is empty")
            state.selected = state.selected === nothing ? 1 : min(length(widget.items), state.selected + 1)
            return Accessibility.SemanticActionResult(true; value=_list_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            isempty(widget.items) && return Accessibility.SemanticActionResult(false; message="list is empty")
            state.selected = state.selected === nothing ? length(widget.items) : max(1, state.selected - 1)
            return Accessibility.SemanticActionResult(true; value=_list_semantic_value(widget, state))
        elseif request.action == Accessibility.SetValueSemanticAction
            handled = _set_list_semantic_value!(widget, state, request.value)
            return Accessibility.SemanticActionResult(handled; value=_list_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="list semantic action is not supported")
    end)
    for index in eachindex(widget.items)
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/item-$index", function (request)
            1 <= index <= length(widget.items) ||
                return Accessibility.SemanticActionResult(false; message="list item is not available")
            if request.action == Accessibility.FocusSemanticAction ||
               request.action == Accessibility.SelectSemanticAction ||
               request.action == Accessibility.ActivateSemanticAction
                state.selected = index
                return Accessibility.SemanticActionResult(true; value=_list_item_label(widget.items[index]))
            end
            return Accessibility.SemanticActionResult(false; message="list item semantic action is not supported")
        end)
    end
    return dispatcher
end

register_list_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ListView,
    state::ListViewState,
) = register_list_semantic_handlers!(dispatcher, id, widget.list, state)

register_option_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::OptionList,
    state::OptionListState,
) = register_list_semantic_handlers!(dispatcher, id, widget.list, state)

register_list_box_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ListBox,
    state::ListBoxState,
) = register_list_semantic_handlers!(dispatcher, id, widget.list, state)

_line_label(line::Line) = join(span.content for span in line.spans)

function _table_semantic_value(widget::Table, state::TableState)
    cells = if state.selected_row === nothing || !(1 <= state.selected_row <= length(widget.rows))
        String[]
    else
        String[_line_label(cell) for cell in widget.rows[state.selected_row].cells]
    end
    return Dict(
        :selected_row => state.selected_row,
        :selected_column => state.selected_column,
        :row_offset => state.row_offset,
        :cells => cells,
    )
end

function _set_table_semantic_value!(widget::Table, state::TableState, value)
    if value isa Integer
        isempty(widget.rows) && return false
        state.selected_row = clamp(Int(value), 1, length(widget.rows))
        state.selected_column === nothing && !isempty(widget.columns) && (state.selected_column = 1)
        return true
    elseif value isa Tuple && length(value) >= 1 && first(value) isa Integer
        isempty(widget.rows) && return false
        state.selected_row = clamp(Int(first(value)), 1, length(widget.rows))
        length(value) >= 2 && value[2] isa Integer && !isempty(widget.columns) &&
            (state.selected_column = clamp(Int(value[2]), 1, length(widget.columns)))
        return true
    else
        label = string(value)
        row = findfirst(table_row -> any(cell -> _line_label(cell) == label, table_row.cells), widget.rows)
        row === nothing && return false
        state.selected_row = row
        state.selected_column = findfirst(cell -> _line_label(cell) == label, widget.rows[row].cells)
        return true
    end
end

function register_table_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Table,
    state::TableState;
    viewport_height::Integer=1,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction ||
           request.action == Accessibility.ScrollIntoViewSemanticAction
            state.selected_row === nothing && !isempty(widget.rows) && (state.selected_row = 1)
            state.selected_column === nothing && !isempty(widget.columns) && (state.selected_column = 1)
            return Accessibility.SemanticActionResult(true; value=_table_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            isempty(widget.rows) && return Accessibility.SemanticActionResult(false; message="table has no rows")
            state.selected_row = state.selected_row === nothing ? 1 : min(length(widget.rows), state.selected_row + 1)
            return Accessibility.SemanticActionResult(true; value=_table_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            isempty(widget.rows) && return Accessibility.SemanticActionResult(false; message="table has no rows")
            state.selected_row = state.selected_row === nothing ? length(widget.rows) : max(1, state.selected_row - 1)
            return Accessibility.SemanticActionResult(true; value=_table_semantic_value(widget, state))
        elseif request.action == Accessibility.SetValueSemanticAction
            handled = _set_table_semantic_value!(widget, state, request.value)
            return Accessibility.SemanticActionResult(handled; value=_table_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="table semantic action is not supported")
    end)
    for row_index in eachindex(widget.rows)
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/row-$row_index", function (request)
            1 <= row_index <= length(widget.rows) ||
                return Accessibility.SemanticActionResult(false; message="table row is not available")
            if request.action == Accessibility.FocusSemanticAction ||
               request.action == Accessibility.SelectSemanticAction ||
               request.action == Accessibility.ActivateSemanticAction
                state.selected_row = row_index
                state.selected_column === nothing && !isempty(widget.columns) && (state.selected_column = 1)
                return Accessibility.SemanticActionResult(true; value=_table_semantic_value(widget, state))
            end
            return Accessibility.SemanticActionResult(false; message="table row semantic action is not supported")
        end)
        for column_index in eachindex(widget.rows[row_index].cells)
            Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/row-$row_index/cell-$column_index", function (request)
                if request.action == Accessibility.FocusSemanticAction ||
                   request.action == Accessibility.SelectSemanticAction ||
                   request.action == Accessibility.ActivateSemanticAction
                    state.selected_row = row_index
                    state.selected_column = column_index
                    return Accessibility.SemanticActionResult(true; value=_line_label(widget.rows[row_index].cells[column_index]))
                end
                return Accessibility.SemanticActionResult(false; message="table cell semantic action is not supported")
            end)
        end
    end
    return dispatcher
end

_tree_node_label(node::TreeNode) = _line_label(node.label)

function _find_tree_node(nodes::Vector{TreeNode}, value)
    for node in nodes
        if node.id == value || string(node.id) == string(value) || _tree_node_label(node) == string(value)
            return node
        end
        found = _find_tree_node(node.children, value)
        found === nothing || return found
    end
    return nothing
end

function _tree_semantic_value(widget::Tree, state::TreeState)
    node = _find_tree_node(widget.roots, state.selected)
    return Dict(
        :selected => state.selected,
        :selected_label => node === nothing ? nothing : _tree_node_label(node),
        :expanded => collect(state.expanded),
        :offset => state.offset,
    )
end

function _set_tree_selection!(widget::Tree, state::TreeState, value)
    node = _find_tree_node(widget.roots, value)
    node === nothing && return false
    state.selected = node.id
    return true
end

function _selected_visible_tree_node(widget::Tree, state::TreeState)
    visible = _visible_nodes(widget, state)
    isempty(visible) && return nothing
    selected_index = findfirst(item -> item.node.id == state.selected, visible)
    selected_index === nothing ? first(visible) : visible[selected_index]
end

function register_tree_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Tree,
    state::TreeState;
    viewport_height::Integer=1,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction ||
           request.action == Accessibility.ScrollIntoViewSemanticAction
            visible = _visible_nodes(widget, state)
            if !isempty(visible)
                index = something(findfirst(item -> item.node.id == state.selected, visible), 1)
                state.selected = visible[index].node.id
            end
            return Accessibility.SemanticActionResult(true; value=_tree_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            visible = _visible_nodes(widget, state)
            isempty(visible) && return Accessibility.SemanticActionResult(false; message="tree has no visible nodes")
            index = something(findfirst(item -> item.node.id == state.selected, visible), 0)
            state.selected = visible[min(length(visible), index + 1)].node.id
            return Accessibility.SemanticActionResult(true; value=_tree_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            visible = _visible_nodes(widget, state)
            isempty(visible) && return Accessibility.SemanticActionResult(false; message="tree has no visible nodes")
            index = something(findfirst(item -> item.node.id == state.selected, visible), length(visible) + 1)
            state.selected = visible[max(1, index - 1)].node.id
            return Accessibility.SemanticActionResult(true; value=_tree_semantic_value(widget, state))
        elseif request.action == Accessibility.SetValueSemanticAction
            handled = _set_tree_selection!(widget, state, request.value)
            return Accessibility.SemanticActionResult(handled; value=_tree_semantic_value(widget, state))
        elseif request.action == Accessibility.ExpandSemanticAction || request.action == Accessibility.CollapseSemanticAction
            item = _selected_visible_tree_node(widget, state)
            item === nothing && return Accessibility.SemanticActionResult(false; message="tree has no selected node")
            isempty(item.node.children) && return Accessibility.SemanticActionResult(false; message="tree node is not expandable")
            request.action == Accessibility.ExpandSemanticAction ? push!(state.expanded, item.node.id) : delete!(state.expanded, item.node.id)
            return Accessibility.SemanticActionResult(true; value=_tree_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="tree semantic action is not supported")
    end)
    _register_tree_node_semantic_handlers!(dispatcher, node_id, widget.roots, state)
    return dispatcher
end

_tree_child_id(parent_id::String, index::Integer) =
    occursin("/root-", parent_id) || occursin("/child-", parent_id) ?
        "$parent_id/child-$index" : "$parent_id/root-$index"

function _register_tree_node_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    parent_id::String,
    nodes::Vector{TreeNode},
    state::TreeState,
)
    for (index, node) in enumerate(nodes)
        child_id = _tree_child_id(parent_id, index)
        Accessibility.register_semantic_handler!(dispatcher, child_id, function (request)
            if request.action == Accessibility.FocusSemanticAction ||
               request.action == Accessibility.SelectSemanticAction ||
               request.action == Accessibility.ActivateSemanticAction
                state.selected = node.id
                return Accessibility.SemanticActionResult(true; value=node.id)
            elseif request.action == Accessibility.ExpandSemanticAction
                isempty(node.children) && return Accessibility.SemanticActionResult(false; message="tree node is not expandable")
                state.selected = node.id
                push!(state.expanded, node.id)
                return Accessibility.SemanticActionResult(true; value=node.id)
            elseif request.action == Accessibility.CollapseSemanticAction
                isempty(node.children) && return Accessibility.SemanticActionResult(false; message="tree node is not expandable")
                state.selected = node.id
                delete!(state.expanded, node.id)
                return Accessibility.SemanticActionResult(true; value=node.id)
            end
            return Accessibility.SemanticActionResult(false; message="tree item semantic action is not supported")
        end)
        _register_tree_node_semantic_handlers!(dispatcher, child_id, node.children, state)
    end
    return dispatcher
end

register_tree_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::TreeView,
    state::TreeViewState;
    viewport_height::Integer=1,
) = register_tree_semantic_handlers!(dispatcher, id, widget.tree, state; viewport_height)

"""Dedicated link adapter with the action semantics and styling of `Button`."""
struct Link{T}
    button::Button{T}
end

Link(label::AbstractString, target=nothing; kwargs...) = Link(Button(label, target; kwargs...))
state_for(::Link) = LinkState()
function _link_label(widget::Link)
    return join(span.content for span in widget.button.label.spans)
end
function render!(buffer::Buffer, widget::Link, area::Rect, state::LinkState)
    style = widget.button.disabled ? Style(modifiers=DIM) :
            state.focused || state.pressed ? widget.button.focused_style : widget.button.style
    return render!(buffer, Label(_link_label(widget); style), area)
end
render!(buffer::Buffer, widget::Link, area::Rect) = render!(buffer, widget, area, LinkState())
measure(widget::Link, available::Rect) = Size(min(available.height, 1), min(available.width, text_width(_link_label(widget))))
function handle!(state::LinkState, widget::Link, event::KeyEvent)
    widget.button.disabled && return false
    event.kind in (KeyPress, KeyRepeat) || return false
    return event.key.code == :enter ||
           (event.key.code == :character && event.text == " ")
end

function handle!(state::LinkState, widget::Link, event::MouseEvent, area::Rect)
    if widget.button.disabled
        changed = state.hovered || state.pressed
        state.hovered = false
        state.pressed = false
        return changed
    end

    inside = contains(area, event.position)
    if event.action == MouseMove
        changed = state.hovered != inside
        state.hovered = inside
        return changed
    elseif event.button == LeftMouseButton && event.action == MousePress
        state.pressed = inside
        state.hovered = inside
        return inside
    elseif event.button == LeftMouseButton && event.action == MouseRelease
        activated = state.pressed && inside
        state.pressed = false
        state.hovered = inside
        return activated
    end
    return false
end

activate(widget::Link, ::LinkState=LinkState()) =
    widget.button.disabled ? nothing : widget.button.message

function SemanticToolkit.widget_semantic_descriptor(widget::Link, state::LinkState)
    enabled = !widget.button.disabled
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.LinkRole;
        label=_link_label(widget),
        state=Accessibility.SemanticState(
            enabled=enabled,
            focusable=enabled,
            focused=state.focused,
        ),
        actions=enabled ? Accessibility.SemanticAction[
            Accessibility.ActivateSemanticAction,
            Accessibility.FocusSemanticAction,
        ] : Accessibility.SemanticAction[],
        metadata=Dict{Symbol,Any}(:target => widget.button.message),
    )
end

function register_link_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Link,
    state::LinkState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        widget.button.disabled && return Accessibility.SemanticActionResult(false; message="link is disabled")
        if request.action == Accessibility.FocusSemanticAction
            state.focused = true
            return Accessibility.SemanticActionResult(true; value=widget.button.message)
        elseif request.action == Accessibility.ActivateSemanticAction
            state.focused = true
            return Accessibility.SemanticActionResult(true; value=activate(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="link semantic action is not supported")
    end)
    return dispatcher
end

function link_semantic_node(
    widget::Link,
    state::LinkState;
    id="link",
    bounds::Union{Nothing,Accessibility.SemanticRect}=nothing,
)
    descriptor = SemanticToolkit.widget_semantic_descriptor(widget, state)
    return Accessibility.SemanticNode(
        id,
        descriptor.role;
        label=descriptor.label,
        bounds,
        state=descriptor.state,
        actions=descriptor.actions,
        metadata=descriptor.metadata,
    )
end

"""
Dedicated split-button API shape implemented as an explicit action adapter.
"""
struct MenuButton{T}
    button::Button{T}
end

MenuButton(label, message=nothing; kwargs...) = MenuButton(Button(label, message; kwargs...))
state_for(::MenuButton) = ButtonState()

render!(buffer::Buffer, widget::MenuButton, area::Rect, state::ButtonState) =
    render!(buffer, widget.button, area, state)
render!(buffer::Buffer, widget::MenuButton, area::Rect) =
    render!(buffer, widget, area, state_for(widget))
handle!(state::ButtonState, widget::MenuButton, event::KeyEvent) =
    handle!(state, widget.button, event)
handle!(state::ButtonState, widget::MenuButton, event::MouseEvent, area::Rect) =
    handle!(state, widget.button, event, area)
activate(widget::MenuButton, state::ButtonState) = activate(widget.button, state)

"""
Dedicated split-button API shape implemented as an explicit action adapter.
"""
const MenuButtonState = ButtonState

SemanticToolkit.widget_semantic_descriptor(widget::MenuButton, state::MenuButtonState) =
    SemanticToolkit.widget_semantic_descriptor(widget.button, state)

register_menu_button_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::MenuButton,
    state::MenuButtonState,
) =
    SemanticToolkit.register_button_semantic_handlers!(dispatcher, id, widget.button, state)

"""
Dedicated menu bar action container.
"""
struct MenuBar{T<:Tuple}
    row::Row{T}
end

MenuBar(children...; constraints=nothing, margin::Margin=Margin(0), gap::Integer=0, alignment::FlexAlignment=StartFlex) =
    MenuBar(Row(children...; constraints=constraints, margin=margin, gap=gap, alignment=alignment))

render!(buffer::Buffer, widget::MenuBar, area::Rect) = render!(buffer, widget.row, area)
measure(widget::MenuBar, available::Rect) = measure(widget.row, available)
SemanticToolkit.widget_semantic_descriptor(::MenuBar, state) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.MenuRole;
        label="Menu bar",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
    )

"""
Dedicated split-action API shape implemented as a dedicated action adapter.
"""
struct SplitButton{T}
    button::Button{T}
    split_indicator::String
end

SplitButton(label, message=nothing; split_indicator::AbstractString=" ▼", kwargs...) =
    SplitButton(Button(label, message; kwargs...), String(split_indicator))
SplitButton(button::Button; split_indicator::AbstractString=" ▼") =
    SplitButton(button, String(split_indicator))
state_for(::SplitButton) = ButtonState()

render!(buffer::Buffer, widget::SplitButton, area::Rect, state::ButtonState) =
    render!(buffer, widget.button, area, state)
render!(buffer::Buffer, widget::SplitButton, area::Rect) =
    render!(buffer, widget, area, state_for(widget))
handle!(state::ButtonState, widget::SplitButton, event::KeyEvent) =
    handle!(state, widget.button, event)
handle!(state::ButtonState, widget::SplitButton, event::MouseEvent, area::Rect) =
    handle!(state, widget.button, event, area)
activate(widget::SplitButton, state::ButtonState) = activate(widget.button, state)

"""
Dedicated split-button state is intentionally shared with `ButtonState`.
"""
const SplitButtonState = ButtonState

SemanticToolkit.widget_semantic_descriptor(widget::SplitButton, state::SplitButtonState) =
    SemanticToolkit.widget_semantic_descriptor(widget.button, state)

register_split_button_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::SplitButton,
    state::SplitButtonState,
) =
    SemanticToolkit.register_button_semantic_handlers!(dispatcher, id, widget.button, state)

"""
Dedicated toolbar action container.
"""
struct Toolbar{T<:Tuple}
    row::Row{T}
end

Toolbar(children...; constraints=nothing, margin::Margin=Margin(0), gap::Integer=0, alignment::FlexAlignment=StartFlex) =
    Toolbar(Row(children...; constraints=constraints, margin=margin, gap=gap, alignment=alignment))

render!(buffer::Buffer, widget::Toolbar, area::Rect) = render!(buffer, widget.row, area)
measure(widget::Toolbar, available::Rect) = measure(widget.row, available)
SemanticToolkit.widget_semantic_descriptor(::Toolbar, state) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Toolbar",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
    )

"""
Dedicated horizontal shortcut bar for key/composition hints.
"""
struct ShortcutBar
    hints::Vector{KeyHint}
    separator::String
    key_style::Style
    description_style::Style
end

ShortcutBar(
    hints;
    separator::AbstractString="  ",
    key_style::Style=Style(modifiers=REVERSED),
    description_style::Style=Style(),
) = ShortcutBar(KeyHint[hint isa KeyHint ? hint : KeyHint(first(hint), last(hint)) for hint in hints], String(separator), key_style, description_style)

"""
    binding_key_hints(bindings)

Convert described bindings from a `BindingMap`, `BindingLayer`, or `BindingStack`
into `KeyHint` values for shortcut bars, status bars, footers, and help views.
"""
binding_key_hints(map::Interaction.BindingMap) = KeyHint[
    KeyHint(record.label, record.description)
    for record in Interaction.described_binding_display_records(map)
]

binding_key_hints(layer::Interaction.BindingLayer) = KeyHint[
    KeyHint(record.label, record.description)
    for record in Interaction.described_binding_layer_display_records(layer)
]

binding_key_hints(stack::Interaction.BindingStack) = KeyHint[
    KeyHint(record.label, record.description)
    for record in Interaction.described_binding_stack_display_records(stack)
]

ShortcutBar(source::Interaction.BindingMap; kwargs...) =
    ShortcutBar(binding_key_hints(source); kwargs...)

ShortcutBar(source::Interaction.BindingLayer; kwargs...) =
    ShortcutBar(binding_key_hints(source); kwargs...)

ShortcutBar(source::Interaction.BindingStack; kwargs...) =
    ShortcutBar(binding_key_hints(source); kwargs...)

function measure(widget::ShortcutBar, available::Rect)
    total_width = 0
    for (index, hint) in enumerate(widget.hints)
        index > 1 && (total_width += text_width(widget.separator))
        total_width += text_width(" " * hint.key * " ")
        total_width += text_width(" " * hint.description)
    end
    return Size(1, min(available.width, max(0, total_width)))
end

function render!(buffer::Buffer, widget::ShortcutBar, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    spans = Span[]
    for (index, hint) in enumerate(widget.hints)
        index > 1 && push!(spans, Span(widget.separator; style=widget.description_style))
        push!(spans, Span(" " * hint.key * " "; style=widget.key_style))
        push!(spans, Span(" " * hint.description; style=widget.description_style))
    end
    draw_line!(buffer, active.row, active, Line(spans))
    buffer
end

function SemanticToolkit.widget_semantic_descriptor(widget::ShortcutBar, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Keyboard shortcuts",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(:hint_count => length(widget.hints)),
    )
end

function SemanticToolkit.widget_semantic_children(widget::ShortcutBar, state, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/hint/$(index)",
            Accessibility.ButtonRole;
            label=hint.key,
            description=hint.description,
            state=Accessibility.SemanticState(readonly=true, focusable=true),
            actions=Accessibility.SemanticAction[
                Accessibility.FocusSemanticAction,
                Accessibility.SelectSemanticAction,
                Accessibility.ActivateSemanticAction,
            ],
            metadata=Dict{Symbol,Any}(:key => hint.key),
        ) for (index, hint) in enumerate(widget.hints)
    ]
end

_chrome_hint_value(hint::KeyHint) = Dict{Symbol,Any}(
    :key => hint.key,
    :description => hint.description,
)

function _register_hint_bar_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    hints::AbstractVector{KeyHint},
    label::AbstractString,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction)
            return Accessibility.SemanticActionResult(
                true;
                value=Dict{Symbol,Any}(:label => String(label), :hint_count => length(hints)),
            )
        end
        return Accessibility.SemanticActionResult(false; message="chrome semantic action is not supported")
    end)
    for (index, hint) in enumerate(hints)
        hint_id = "$(node_id)/hint/$(index)"
        Accessibility.register_semantic_handler!(dispatcher, hint_id, function (request)
            if request.action in (
                Accessibility.FocusSemanticAction,
                Accessibility.SelectSemanticAction,
                Accessibility.ActivateSemanticAction,
            )
                return Accessibility.SemanticActionResult(true; value=_chrome_hint_value(hint))
            end
            return Accessibility.SemanticActionResult(false; message="shortcut semantic action is not supported")
        end)
    end
    return dispatcher
end

register_shortcut_bar_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ShortcutBar,
) = _register_hint_bar_semantic_handlers!(dispatcher, id, widget.hints, "Keyboard shortcuts")

function _register_readonly_chrome_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    value,
    unsupported::AbstractString,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction)
            return Accessibility.SemanticActionResult(true; value)
        end
        return Accessibility.SemanticActionResult(false; message=unsupported)
    end)
    return dispatcher
end

register_menu_bar_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::MenuBar) =
    _register_readonly_chrome_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Menu bar"),
        "menu bar semantic action is not supported",
    )

register_toolbar_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Toolbar) =
    _register_readonly_chrome_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Toolbar"),
        "toolbar semantic action is not supported",
    )

"""
Dedicated navigation tab container with selectable content regions.
"""
struct TabView{T}
    tabs::Tabs
    views::Vector{T}
    block::Union{Nothing,Block}
    body_block::Union{Nothing,Block}
end

mutable struct TabViewState
    selected::Int
    function TabViewState(selected::Integer=1)
        selected >= 1 || throw(ArgumentError("tab selection must be positive"))
        new(Int(selected))
    end
end

function TabView(
    tabs,
    views;
    divider::AbstractString=" │ ",
    style::Style=Style(),
    selected_style::Style=Style(modifiers=REVERSED | BOLD),
    block::Union{Nothing,Block}=nothing,
    body_block::Union{Nothing,Block}=nothing,
)
    resolved_tabs = [
        tab isa Tab ? tab : Tab(first(tab), last(tab)) for tab in tabs
    ]
    tab_count = length(resolved_tabs)
    tab_count == length(views) || throw(
        DimensionMismatch("tab count must match view count")
    )
    TabView(
        Tabs(resolved_tabs; divider, style, selected_style),
        collect(Any, views),
        block,
        body_block,
    )
end

state_for(::TabView) = TabViewState()

function selected_tab_view(widget::TabView, state::TabViewState)
    isempty(widget.tabs.tabs) && return nothing
    widget.tabs.tabs[clamp(state.selected, 1, length(widget.tabs.tabs))]
end

function selected_tab_view_content(widget::TabView, state::TabViewState)
    isempty(widget.views) && return nothing
    widget.views[clamp(state.selected, 1, length(widget.views))]
end

function select_tab_view!(state::TabViewState, widget::TabView, index::Integer)
    count = min(length(widget.tabs.tabs), length(widget.views))
    count == 0 && return state
    state.selected = clamp(Int(index), 1, count)
    state
end

function select_next_tab_view!(state::TabViewState, widget::TabView)
    count = min(length(widget.tabs.tabs), length(widget.views))
    count == 0 && return state
    state.selected = mod1(state.selected + 1, count)
    state
end

function select_previous_tab_view!(state::TabViewState, widget::TabView)
    count = min(length(widget.tabs.tabs), length(widget.views))
    count == 0 && return state
    state.selected = mod1(state.selected - 1, count)
    state
end

function measure(widget::TabView, available::Rect)
    isempty(available) && return Size(0, 0)
    tab_size = measure(widget.tabs, available)
    if isempty(widget.views)
        return Size(
            min(available.height, tab_size.height),
            min(available.width, tab_size.width),
        )
    end
    body_area = Rect(
        available.row + tab_size.height,
        available.column,
        max(0, available.height - tab_size.height),
        available.width,
    )
    first_view = measure(widget.views[1], body_area)
    return Size(
        min(
            available.height,
            tab_size.height + first_view.height,
        ),
        min(
            available.width,
            max(tab_size.width, first_view.width),
        ),
    )
end

render!(buffer::Buffer, widget::TabView, area::Rect) =
    render!(buffer, widget, area, TabViewState())

function render!(buffer::Buffer, widget::TabView, area::Rect, state::TabViewState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    tab_area = Rect(active.row, active.column, min(active.height, 1), active.width)
    render!(buffer, widget.tabs, tab_area, TabsState(state.selected))
    index = clamp(state.selected, 1, max(1, length(widget.views)))
    body_area = Rect(
        tab_area.row + tab_area.height,
        active.column,
        max(0, active.height - tab_area.height),
        active.width,
    )
    isempty(widget.views) || isempty(body_area) && return buffer
    selected_view = widget.views[index]
    if widget.body_block === nothing
        render!(buffer, selected_view, body_area)
    else
        render!(buffer, widget.body_block, body_area)
        render!(buffer, selected_view, inner(widget.body_block, body_area))
    end
    return buffer
end

function handle!(state::TabViewState, widget::TabView, event::KeyEvent)
    tabs_state = TabsState(state.selected)
    changed = handle!(tabs_state, widget.tabs, event)
    changed && select_tab_view!(state, widget, tabs_state.selected)
    return changed
end

function handle!(state::TabViewState, widget::TabView, event::MouseEvent, area::Rect)
    active = area
    isempty(active) && return false
    tab_state = TabsState(state.selected)
    if handle!(tab_state, widget.tabs, event, Rect(active.row, active.column, min(active.height, 1), active.width))
        select_tab_view!(state, widget, tab_state.selected)
        return true
    end
    return false
end

function SemanticToolkit.widget_semantic_descriptor(::TabView, ::TabViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TabListRole;
        label="Tabs",
        state=Accessibility.SemanticState(focusable=true),
        actions=[Accessibility.FocusSemanticAction],
    )
end

function SemanticToolkit.widget_semantic_children(widget::TabView, state::TabViewState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(index)",
            Accessibility.TabRole;
            label=join(span.content for span in tab.title.spans),
            state=Accessibility.SemanticState(selected=state.selected == index),
            actions=[Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction],
            metadata=Dict(:tab_id => tab.id),
        ) for (index, tab) in enumerate(widget.tabs.tabs)
    ]
end

function register_tab_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::TabView,
    state::TabViewState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            selected = selected_tab_view(widget, state)
            return Accessibility.SemanticActionResult(true; value=isnothing(selected) ? nothing : selected.id)
        end
        return Accessibility.SemanticActionResult(false; message="tab view semantic action is not supported")
    end)
    for (registered_index, tab) in enumerate(widget.tabs.tabs)
        tab_id = tab.id
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/$(registered_index)", function (request)
            index = findfirst(candidate -> candidate.id == tab_id, widget.tabs.tabs)
            isnothing(index) && return Accessibility.SemanticActionResult(false; message="tab view tab is not available")
            if request.action == Accessibility.FocusSemanticAction || request.action == Accessibility.SelectSemanticAction
                select_tab_view!(state, widget, index)
                return Accessibility.SemanticActionResult(true; value=tab_id)
            end
            return Accessibility.SemanticActionResult(false; message="tab view tab semantic action is not supported")
        end)
    end
    return dispatcher
end

"""
Dedicated context menu adapter over existing immediate menu behavior.
"""
struct ContextMenu
    menu::Menu
end

ContextMenu(items::AbstractVector; kwargs...) = ContextMenu(Menu(items; kwargs...))

const ContextMenuState = MenuState

state_for(widget::ContextMenu) = MenuState()
render!(buffer::Buffer, widget::ContextMenu, area::Rect, state::ContextMenuState) =
    render!(buffer, widget.menu, area, state)
render!(buffer::Buffer, widget::ContextMenu, area::Rect) =
    render!(buffer, widget, area, state_for(widget))
handle!(state::ContextMenuState, widget::ContextMenu, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.menu, event; viewport_height)
handle!(state::ContextMenuState, widget::ContextMenu, event::MouseEvent, area::Rect) =
    handle!(state, widget.menu, event, area)
activate(widget::ContextMenu, state::ContextMenuState) = activate(widget.menu, state)

SemanticToolkit.widget_semantic_descriptor(widget::ContextMenu, state::ContextMenuState) =
    SemanticToolkit.widget_semantic_descriptor(widget.menu, state)

SemanticToolkit.widget_semantic_children(widget::ContextMenu, state::ContextMenuState, id) =
    SemanticToolkit.widget_semantic_children(widget.menu, state, id)

register_context_menu_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ContextMenu,
    state::ContextMenuState,
) =
    SemanticToolkit.register_menu_semantic_handlers!(dispatcher, id, widget.menu, state)

"""
Dedicated sidebar adapter with fixed-size primary slot.
"""
struct Sidebar{S,C}
    sidebar::S
    content::C
    sidebar_size::Int
    side::Symbol
    gap::Int
    block::Union{Nothing,Block}
end

function Sidebar(
    sidebar,
    content;
    sidebar_size::Integer=24,
    side::Symbol=:left,
    gap::Integer=0,
    block::Union{Nothing,Block}=nothing,
)
    side in (:left, :right, :top, :bottom) ||
        throw(ArgumentError("sidebar side must be :left, :right, :top, or :bottom"))
    Sidebar(sidebar, content, max(0, Int(sidebar_size)), side, Int(gap), block)
end

function measure(widget::Sidebar, available::Rect)
    isempty(available) && return Size(0, 0)
    sidebar_area, body_area = _sidebar_regions(widget, available)
    sidebar_size = measure(widget.sidebar, sidebar_area)
    body_size = isempty(body_area) ? Size(0, 0) : measure(widget.content, body_area)

    return if widget.side in (:left, :right)
        Size(
            min(available.height, max(sidebar_size.height, body_size.height)),
            min(
                available.width,
                sidebar_area.width + (isempty(body_area) ? 0 : (widget.gap + body_size.width)),
            ),
        )
    else
        Size(
            min(
                available.height,
                sidebar_area.height + (isempty(body_area) ? 0 : (widget.gap + body_size.height)),
            ),
            min(available.width, max(sidebar_size.width, body_size.width)),
        )
    end
end

function _sidebar_regions(widget::Sidebar, available::Rect)
    available_width = max(0, available.width)
    available_height = max(0, available.height)

    if widget.side in (:left, :right)
        sidebar_width = min(widget.sidebar_size, available_width)
        gap = min(widget.gap, available_width)
        body_width = max(0, available_width - sidebar_width - gap)
        if widget.side == :left
            sidebar_area = Rect(available.row, available.column, available_height, sidebar_width)
            body_area = Rect(
                available.row,
                available.column + sidebar_width + gap,
                available_height,
                body_width,
            )
        else
            sidebar_area = Rect(
                available.row,
                available.column + max(0, available_width - sidebar_width),
                available_height,
                sidebar_width,
            )
            body_area = Rect(available.row, available.column, available_height, body_width)
        end
        return sidebar_area, body_area
    end

    sidebar_height = min(widget.sidebar_size, available_height)
    gap = min(widget.gap, available_height)
    body_height = max(0, available_height - sidebar_height - gap)
    if widget.side == :top
        sidebar_area = Rect(available.row, available.column, sidebar_height, available_width)
        body_area = Rect(
            available.row + sidebar_height + gap,
            available.column,
            body_height,
            available_width,
        )
    else
        sidebar_area = Rect(
            available.row + max(0, available_height - sidebar_height),
            available.column,
            sidebar_height,
            available_width,
        )
        body_area = Rect(available.row, available.column, body_height, available_width)
    end
    return sidebar_area, body_area
end

function render!(buffer::Buffer, widget::Sidebar, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    sidebar_area, body_area = _sidebar_regions(widget, active)
    if widget.block === nothing
        render!(buffer, widget.sidebar, sidebar_area)
        !isempty(body_area) && render!(buffer, widget.content, body_area)
    else
        render!(buffer, widget.block, active)
        active = inner(widget.block, active)
        render!(buffer, widget.sidebar, intersection(sidebar_area, active))
        isempty(body_area) || render!(buffer, widget.content, intersection(body_area, active))
    end
    return buffer
end

SemanticToolkit.widget_semantic_descriptor(widget::Sidebar, state) =
    _static_group_semantics("Sidebar layout"; metadata=Dict(:side => widget.side, :sidebar_size => widget.sidebar_size, :gap => widget.gap))

register_sidebar_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Sidebar) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => "Sidebar layout",
            :side => widget.side,
            :sidebar_size => widget.sidebar_size,
            :gap => widget.gap,
        ),
        "sidebar semantic action is not supported",
    )

"""
Dedicated navigation rail adapter for vertical menus.
"""
struct NavigationRail
    menu::Menu
end

NavigationRail(items::AbstractVector; kwargs...) = NavigationRail(Menu(items; kwargs...))
const NavigationRailState = MenuState
state_for(widget::NavigationRail) = MenuState(selected=findfirst(item -> !item.disabled, widget.menu.items))
render!(buffer::Buffer, widget::NavigationRail, area::Rect, state::NavigationRailState) =
    render!(buffer, widget.menu, area, state)
render!(buffer::Buffer, widget::NavigationRail, area::Rect) =
    render!(buffer, widget, area, state_for(widget))
handle!(state::NavigationRailState, widget::NavigationRail, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.menu, event; viewport_height)
handle!(state::NavigationRailState, widget::NavigationRail, event::MouseEvent, area::Rect) =
    handle!(state, widget.menu, event, area)
activate(widget::NavigationRail, state::NavigationRailState) = activate(widget.menu, state)

select_navigation_item!(state::NavigationRailState, widget::NavigationRail, index::Integer) =
    select_menu_item!(state, widget.menu, index)

select_next_navigation_item!(state::NavigationRailState, widget::NavigationRail) =
    select_next_menu_item!(state, widget.menu)

select_previous_navigation_item!(state::NavigationRailState, widget::NavigationRail) =
    select_previous_menu_item!(state, widget.menu)

selected_navigation_item(widget::NavigationRail, state::NavigationRailState) =
    selected_menu_item(widget.menu, state)

selected_navigation_message(widget::NavigationRail, state::NavigationRailState) =
    selected_menu_message(widget.menu, state)

function screen_registry_navigation_items(registry::Toolkit.ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false)
    return MenuItem[
        MenuItem(
            record.id,
            Toolkit.screen_route_title(registry, record.id),
            replace ? Toolkit.ReplaceWithRegisteredScreen(registry, record.id) :
                      Toolkit.PushRegisteredScreen(registry, record.id);
            disabled=!record.enabled,
        )
        for record in Toolkit.screen_registry_filter_records(registry; mode=mode, group=group, enabled=enabled)
    ]
end

screen_registry_navigation_rail(registry::Toolkit.ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false, kwargs...) =
    NavigationRail(screen_registry_navigation_items(registry; mode=mode, group=group, enabled=enabled, replace=replace); kwargs...)

function screen_registry_navigation_rail_session(registry::Toolkit.ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, replace::Bool=false, kwargs...)
    rail = screen_registry_navigation_rail(registry; mode=mode, group=group, enabled=enabled, replace=replace, kwargs...)
    return (rail=rail, state=state_for(rail))
end

function search_screen_registry_navigation_items(
    registry::Toolkit.ScreenRegistry,
    query;
    mode=nothing,
    group=nothing,
    enabled=nothing,
    replace::Bool=false,
)
    return MenuItem[
        MenuItem(
            record.id,
            Toolkit.screen_route_title(registry, record.id),
            replace ? Toolkit.ReplaceWithRegisteredScreen(registry, record.id) :
                      Toolkit.PushRegisteredScreen(registry, record.id);
            disabled=!record.enabled,
        )
        for record in Toolkit.search_screen_registry_records(registry, query; mode=mode, group=group, enabled=enabled)
    ]
end

search_screen_registry_navigation_rail(
    registry::Toolkit.ScreenRegistry,
    query;
    mode=nothing,
    group=nothing,
    enabled=nothing,
    replace::Bool=false,
    kwargs...,
) = NavigationRail(search_screen_registry_navigation_items(registry, query; mode=mode, group=group, enabled=enabled, replace=replace); kwargs...)

function search_screen_registry_navigation_rail_session(
    registry::Toolkit.ScreenRegistry,
    query;
    mode=nothing,
    group=nothing,
    enabled=nothing,
    replace::Bool=false,
    kwargs...,
)
    rail = search_screen_registry_navigation_rail(registry, query; mode=mode, group=group, enabled=enabled, replace=replace, kwargs...)
    return (rail=rail, state=state_for(rail))
end

function screen_registry_tab_items(registry::Toolkit.ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, include_disabled::Bool=false)
    return Tab[
        Tab(record.id, record.title)
        for record in Toolkit.screen_registry_filter_records(registry; mode=mode, group=group, enabled=enabled)
        if include_disabled || record.enabled || enabled === false
    ]
end

screen_registry_tabs(registry::Toolkit.ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, include_disabled::Bool=false, kwargs...) =
    Tabs(screen_registry_tab_items(registry; mode=mode, group=group, enabled=enabled, include_disabled=include_disabled); kwargs...)

function screen_registry_tabs_session(registry::Toolkit.ScreenRegistry; mode=nothing, group=nothing, enabled=nothing, include_disabled::Bool=false, selected::Integer=1, kwargs...)
    tabs = screen_registry_tabs(registry; mode=mode, group=group, enabled=enabled, include_disabled=include_disabled, kwargs...)
    return (tabs=tabs, state=TabsState(selected))
end

function search_screen_registry_tab_items(registry::Toolkit.ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing, include_disabled::Bool=false)
    return Tab[
        Tab(record.id, record.title)
        for record in Toolkit.search_screen_registry_records(registry, query; mode=mode, group=group, enabled=enabled)
        if include_disabled || record.enabled || enabled === false
    ]
end

search_screen_registry_tabs(registry::Toolkit.ScreenRegistry, query; mode=nothing, group=nothing, enabled=nothing, include_disabled::Bool=false, kwargs...) =
    Tabs(search_screen_registry_tab_items(registry, query; mode=mode, group=group, enabled=enabled, include_disabled=include_disabled); kwargs...)

function search_screen_registry_tabs_session(
    registry::Toolkit.ScreenRegistry,
    query;
    mode=nothing,
    group=nothing,
    enabled=nothing,
    include_disabled::Bool=false,
    selected::Integer=1,
    kwargs...,
)
    tabs = search_screen_registry_tabs(registry, query; mode=mode, group=group, enabled=enabled, include_disabled=include_disabled, kwargs...)
    return (tabs=tabs, state=TabsState(selected))
end

function selected_screen_registry_tab_message(
    registry::Toolkit.ScreenRegistry,
    tabs::Tabs,
    state::TabsState;
    replace::Bool=false,
)
    tab = selected_tab(tabs, state)
    tab === nothing && return nothing
    Toolkit.has_registered_screen(registry, tab.id) || return nothing
    Toolkit.screen_route_enabled(registry, tab.id) || return nothing
    return replace ? Toolkit.ReplaceWithRegisteredScreen(registry, tab.id) :
                     Toolkit.PushRegisteredScreen(registry, tab.id)
end

SemanticToolkit.widget_semantic_descriptor(widget::NavigationRail, state::NavigationRailState) =
    SemanticToolkit.widget_semantic_descriptor(widget.menu, state)

SemanticToolkit.widget_semantic_children(widget::NavigationRail, state::NavigationRailState, id) =
    SemanticToolkit.widget_semantic_children(widget.menu, state, id)

register_navigation_rail_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::NavigationRail,
    state::NavigationRailState,
) = SemanticToolkit.register_menu_semantic_handlers!(dispatcher, id, widget.menu, state)

"""
Flow-style container that wraps children to the next line when needed.

`Flow` delegates all wrapping decisions to the existing layout `flow` helper and
keeps each child independently renderable.
"""
struct Flow{T<:Tuple}
    children::T
    column_gap::Int
    row_gap::Int
    function Flow(children::Tuple, column_gap::Integer, row_gap::Integer)
        column_gap >= 0 || throw(ArgumentError("column gap must be non-negative"))
        row_gap >= 0 || throw(ArgumentError("row gap must be non-negative"))
        new{typeof(children)}(children, Int(column_gap), Int(row_gap))
    end
end

Flow(children...; column_gap::Integer=0, row_gap::Integer=0) =
    Flow(children, column_gap, row_gap)

function _flow_regions(area::Rect, children, column_gap::Int, row_gap::Int)
    sizes = [measure(child, area) for child in children]
    isempty(sizes) && return Rect[]
    return flow(area, sizes; column_gap=column_gap, row_gap=row_gap)
end

function measure(widget::Flow, available::Rect)
    regions = _flow_regions(available, widget.children, widget.column_gap, widget.row_gap)
    isempty(regions) && return Size(0, 0)
    max_row = maximum(region.row + region.height for region in regions)
    max_col = maximum(region.column + region.width for region in regions)
    return Size(
        min(available.height, max_row - available.row),
        min(available.width, max_col - available.column),
    )
end

function render!(buffer::Buffer, widget::Flow, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    regions = _flow_regions(active, widget.children, widget.column_gap, widget.row_gap)
    for (index, region) in enumerate(regions)
        render!(buffer, widget.children[index], region)
    end
    return buffer
end

SemanticToolkit.widget_semantic_descriptor(::Flow, state) = _static_group_semantics("Flow layout")

register_flow_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Flow) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => "Flow layout",
            :child_count => length(widget.children),
            :column_gap => widget.column_gap,
            :row_gap => widget.row_gap,
        ),
        "flow semantic action is not supported",
    )

"""
Alias-style flow container with explicit wrapped-line intent.
"""
struct Wrap{T<:Tuple}
    flow::Flow{T}
end

Wrap(children...; column_gap::Integer=0, row_gap::Integer=0) =
    Wrap(Flow(children...; column_gap, row_gap))

measure(widget::Wrap, available::Rect) = measure(widget.flow, available)

render!(buffer::Buffer, widget::Wrap, area::Rect) =
    render!(buffer, widget.flow, area)

SemanticToolkit.widget_semantic_descriptor(::Wrap, state) =
    _static_group_semantics("Wrap layout")

register_wrap_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Wrap) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => "Wrap layout",
            :child_count => length(widget.flow.children),
            :column_gap => widget.flow.column_gap,
            :row_gap => widget.flow.row_gap,
        ),
        "wrap semantic action is not supported",
    )

"""
Container that lays out two children in primary and secondary regions.
"""
struct SplitPane{A,B}
    first::A
    second::B
    first_fraction::UInt16
    orientation::SplitOrientation
    gap::Int
    margin::Margin
end

function SplitPane(
    first,
    second;
    fraction::Real=0.5,
    orientation::SplitOrientation=HorizontalSplit,
    gap::Integer=0,
    margin::Margin=Margin(0),
)
    0 <= fraction <= 1 || throw(ArgumentError("split fraction must be between 0 and 1"))
    gap >= 0 || throw(ArgumentError("split pane gap must be non-negative"))
    scaled = clamp(Int(round(fraction * 1000)), 0, 1000)
    SplitPane(first, second, UInt16(scaled), orientation, Int(gap), margin)
end

function _splitpane_regions(
    widget::SplitPane,
    area::Rect,
)
    first_fraction = Float64(widget.first_fraction) / 1000
    second_fraction = 1.0 - first_fraction
    first_constraint = Ratio(clamp(round(Int, first_fraction * 1000), 0, 1000), 1000)
    second_constraint = Ratio(clamp(round(Int, second_fraction * 1000), 0, 1000), 1000)
    layout = if widget.orientation == HorizontalSplit
        FlexLayout(HorizontalLayout, [first_constraint, second_constraint]; margin=widget.margin, gap=widget.gap)
    else
        FlexLayout(VerticalLayout, [first_constraint, second_constraint]; margin=widget.margin, gap=widget.gap)
    end
    return resolve(layout, area)
end

measure(widget::SplitPane, available::Rect) = begin
    regions = _splitpane_regions(widget, available)
    isempty(regions) && return Size(0, 0)
    first = measure(widget.first, regions[1])
    second = measure(widget.second, regions[2])
    widths = [regions[1].column + first.width - available.column, regions[2].column + second.width - available.column]
    heights = [regions[1].row + first.height - available.row, regions[2].row + second.height - available.row]
    Size(min(available.height, max(heights...)), min(available.width, max(widths...)))
end

function render!(buffer::Buffer, widget::SplitPane, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    regions = _splitpane_regions(widget, active)
    render!(buffer, widget.first, regions[1])
    render!(buffer, widget.second, regions[2])
    return buffer
end

SemanticToolkit.widget_semantic_descriptor(widget::SplitPane, state) =
    _static_group_semantics("Split pane"; metadata=Dict(:orientation => widget.orientation, :fraction => Float64(widget.first_fraction) / 1000, :gap => widget.gap))

register_split_pane_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::SplitPane,
) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => "Split pane",
            :orientation => widget.orientation,
            :fraction => Float64(widget.first_fraction) / 1000,
            :gap => widget.gap,
        ),
        "split pane semantic action is not supported",
    )

"""
Stateful resizable split pane built on explicit fractional control.
"""
const ResizablePaneState = SplitPaneState

struct ResizablePane{A,B}
    first::A
    second::B
    fraction::Float64
    orientation::SplitOrientation
    gap::Int
    margin::Margin
    minimum_first::Int
    minimum_second::Int
    handle_style::Style
    handle_size::Int
end

function ResizablePane(
    first,
    second;
    fraction::Real=0.5,
    orientation::SplitOrientation=HorizontalSplit,
    gap::Integer=0,
    margin::Margin=Margin(0),
    minimum_first::Integer=0,
    minimum_second::Integer=0,
    handle_style::Style=Style(foreground=AnsiColor(8)),
    handle_size::Integer=1,
)
    0 <= fraction <= 1 || throw(ArgumentError("split fraction must be between 0 and 1"))
    minimum_first >= 0 || throw(ArgumentError("minimum_first must be non-negative"))
    minimum_second >= 0 || throw(ArgumentError("minimum_second must be non-negative"))
    gap >= 0 || throw(ArgumentError("split pane gap must be non-negative"))
    ResizablePane(
        first,
        second,
        Float64(fraction),
        orientation,
        Int(gap),
        margin,
        Int(minimum_first),
        Int(minimum_second),
        handle_style,
        max(Int(handle_size), 0),
    )
end

state_for(widget::ResizablePane) = SplitPaneState(
    fraction=widget.fraction,
    minimum_first=widget.minimum_first,
    minimum_second=widget.minimum_second,
    orientation=widget.orientation,
    disabled=widget.handle_size <= 0 || widget.gap < 0,
)

function measure(widget::ResizablePane, available::Rect)
    state = state_for(widget)
    regions = split_pane_regions(
        state,
        ComponentRect(available.row, available.column, available.width, available.height);
        handle_size=widget.handle_size,
    )
    first = measure(widget.first, Rect(regions[1].row, regions[1].column, regions[1].height, regions[1].width))
    second = measure(widget.second, Rect(regions[2].row, regions[2].column, regions[2].height, regions[2].width))
    return Size(
        min(available.height, max(regions[1].row + first.height, regions[2].row + second.height) - available.row),
        min(available.width, max(regions[1].column + first.width, regions[2].column + second.width) - available.column),
    )
end

function _rect_from_component(region::ComponentRect)
    Rect(region.row, region.column, region.height, region.width)
end

function render!(buffer::Buffer, widget::ResizablePane, area::Rect, state::ResizablePaneState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    first_rect, handle_rect, second_rect = split_pane_regions(
        state,
        ComponentRect(active.row, active.column, active.width, active.height);
        handle_size=widget.handle_size,
    )
    render!(buffer, widget.first, _rect_from_component(first_rect))
    render!(buffer, widget.second, _rect_from_component(second_rect))
    if widget.handle_size > 0
        handle_area = _rect_from_component(handle_rect)
        fill!(buffer, handle_area, Cell(widget.orientation == HorizontalSplit ? "┃" : "━"; style=widget.handle_style))
    end
    return buffer
end

render!(buffer::Buffer, widget::ResizablePane, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::ResizablePaneState, widget::ResizablePane, event::MouseEvent, area::Rect)
    widget.handle_size > 0 || return false
    event.action in (MousePress, MouseDrag, MouseMove) || return false
    event.button == LeftMouseButton || return false
    active = area
    contains(active, event.position) || return false
    regions = split_pane_regions(
        state,
        ComponentRect(active.row, active.column, active.width, active.height);
        handle_size=widget.handle_size,
    )
    handle_area = intersection(active, _rect_from_component(regions[2]))
    event.action == MouseDrag ||
        (handle_area.width > 0 && handle_area.height > 0 && contains(handle_area, event.position)) || return false
    total = widget.orientation == HorizontalSplit ? active.width : active.height
    total > widget.handle_size || return false
    if widget.orientation == HorizontalSplit
        pointer = event.position.column
        offset = active.column
    else
        pointer = event.position.row
        offset = active.row
    end
    set_split_fraction!(state, clamp((pointer - offset) / max(total, 1), 0.0, 1.0))
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::ResizablePane, state::ResizablePaneState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.SliderRole;
        label="Resizable pane divider",
        state=Accessibility.SemanticState(
            focusable=true,
            value_now=state.fraction,
            value_min=0.0,
            value_max=1.0,
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:orientation => widget.orientation, :minimum_first => state.minimum_first, :minimum_second => state.minimum_second),
    )
end

function _resizable_pane_semantic_value(widget::ResizablePane, state::ResizablePaneState)
    return Dict{Symbol,Any}(
        :label => "Resizable pane divider",
        :fraction => state.fraction,
        :orientation => widget.orientation,
        :minimum_first => state.minimum_first,
        :minimum_second => state.minimum_second,
        :disabled => state.disabled,
    )
end

function register_resizable_pane_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ResizablePane,
    state::ResizablePaneState,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if state.disabled
            return Accessibility.SemanticActionResult(false; message="resizable pane is disabled")
        elseif request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=_resizable_pane_semantic_value(widget, state))
        elseif request.action == Accessibility.SetValueSemanticAction
            value = tryparse(Float64, string(request.value))
            handled = value !== nothing && isfinite(value)
            handled && set_split_fraction!(state, value)
            return Accessibility.SemanticActionResult(
                handled;
                value=_resizable_pane_semantic_value(widget, state),
                message=handled ? nothing : "resizable pane semantic value must be a finite number",
            )
        elseif request.action == Accessibility.IncrementSemanticAction
            set_split_fraction!(state, state.fraction + 0.05)
            return Accessibility.SemanticActionResult(true; value=_resizable_pane_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            set_split_fraction!(state, state.fraction - 0.05)
            return Accessibility.SemanticActionResult(true; value=_resizable_pane_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="resizable pane semantic action is not supported")
    end)
    return dispatcher
end

"""
Container that combines edge docks and a center region.
"""
struct DockLayout
    top::Any
    right::Any
    bottom::Any
    left::Any
    center::Any
    top_size::Int
    right_size::Int
    bottom_size::Int
    left_size::Int
    margin::Margin
end

function DockLayout(;
    top=nothing,
    right=nothing,
    bottom=nothing,
    left=nothing,
    center=nothing,
    top_size::Integer=0,
    right_size::Integer=0,
    bottom_size::Integer=0,
    left_size::Integer=0,
    margin::Margin=Margin(0),
)
    top_size >= 0 || throw(ArgumentError("top dock size must be non-negative"))
    right_size >= 0 || throw(ArgumentError("right dock size must be non-negative"))
    bottom_size >= 0 || throw(ArgumentError("bottom dock size must be non-negative"))
    left_size >= 0 || throw(ArgumentError("left dock size must be non-negative"))
    DockLayout(
        top,
        right,
        bottom,
        left,
        center,
        Int(top_size),
        Int(right_size),
        Int(bottom_size),
        Int(left_size),
        margin,
    )
end

struct Dock
    layout::DockLayout
end

Dock(; kwargs...) = Dock(DockLayout(; kwargs...))

function _dock_children_and_items(widget::DockLayout)
    children = Any[]
    items = DockItem[]
    if widget.top !== nothing
        push!(children, widget.top)
        push!(items, DockItem(DockTop, widget.top_size))
    end
    if widget.right !== nothing
        push!(children, widget.right)
        push!(items, DockItem(DockRight, widget.right_size))
    end
    if widget.bottom !== nothing
        push!(children, widget.bottom)
        push!(items, DockItem(DockBottom, widget.bottom_size))
    end
    if widget.left !== nothing
        push!(children, widget.left)
        push!(items, DockItem(DockLeft, widget.left_size))
    end
    return children, items
end

function _dock_regions(widget::DockLayout, area::Rect)
    working_area = inset(area, widget.margin)
    children, items = _dock_children_and_items(widget)
    dock_regions, remaining = dock(working_area, items)
    return children, dock_regions, remaining
end

measure(widget::DockLayout, available::Rect) = begin
    children, dock_regions, remaining = _dock_regions(widget, available)
    max_row = available.row
    max_col = available.column
    for (child, region) in zip(children, dock_regions)
        size = measure(child, region)
        max_row = max(max_row, region.row + size.height)
        max_col = max(max_col, region.column + size.width)
    end
    if widget.center !== nothing
        size = measure(widget.center, remaining)
        max_row = max(max_row, remaining.row + size.height)
        max_col = max(max_col, remaining.column + size.width)
    end
    Size(min(available.height, max_row - available.row), min(available.width, max_col - available.column))
end

measure(widget::Dock, available::Rect) = measure(widget.layout, available)

render!(buffer::Buffer, widget::Dock, area::Rect) =
    render!(buffer, widget.layout, area)

SemanticToolkit.widget_semantic_descriptor(widget::DockLayout, state) =
    _static_group_semantics("Dock layout"; metadata=Dict(
        :top_size => widget.top_size,
        :right_size => widget.right_size,
        :bottom_size => widget.bottom_size,
        :left_size => widget.left_size,
    ))

SemanticToolkit.widget_semantic_descriptor(widget::Dock, state) =
    _static_group_semantics("Dock"; metadata=Dict(
        :top_size => widget.layout.top_size,
        :right_size => widget.layout.right_size,
        :bottom_size => widget.layout.bottom_size,
        :left_size => widget.layout.left_size,
    ))

_dock_layout_semantic_value(widget::DockLayout; label="Dock layout") = Dict{Symbol,Any}(
    :label => label,
    :top_size => widget.top_size,
    :right_size => widget.right_size,
    :bottom_size => widget.bottom_size,
    :left_size => widget.left_size,
)

register_dock_layout_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::DockLayout) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        _dock_layout_semantic_value(widget),
        "dock layout semantic action is not supported",
    )

register_dock_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Dock) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        _dock_layout_semantic_value(widget.layout; label="Dock"),
        "dock semantic action is not supported",
    )

function render!(buffer::Buffer, widget::DockLayout, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    children, dock_regions, remaining = _dock_regions(widget, active)
    for (child, region) in zip(children, dock_regions)
        render!(buffer, child, region)
    end
    widget.center === nothing || render!(buffer, widget.center, remaining)
    return buffer
end

"""
Application shell convenience wrapper for common TUI chrome.

`AppShell` composes a title/header, optional toolbar, optional sidebar, body, and
optional status/footer line into the existing `Dock` layout.
"""
struct AppShell
    dock::Dock
end

function _app_shell_top(header, title, subtitle, toolbar)
    resolved_header = header !== nothing ? header :
        title === nothing ? nothing : TitleBar(string(title); subtitle=String(subtitle))
    resolved_header === nothing && return toolbar
    toolbar === nothing && return resolved_header
    return Column(resolved_header, toolbar; gap=0)
end

function _app_shell_default_top_size(header, title, subtitle, toolbar)
    size = 0
    if header !== nothing
        size += 1
    elseif title !== nothing
        size += isempty(String(subtitle)) ? 1 : 2
    end
    toolbar !== nothing && (size += 1)
    return size
end

_app_shell_default_bottom_size(bottom) = bottom === nothing ? 0 : 1

function AppShell(
    body::Vararg{Any};
    title::Union{Nothing,AbstractString}=nothing,
    subtitle::AbstractString="",
    header=nothing,
    toolbar=nothing,
    sidebar=nothing,
    sidebar_side::Symbol=:left,
    sidebar_size::Integer=24,
    status=nothing,
    shortcuts=nothing,
    footer=nothing,
    top_size::Union{Nothing,Integer}=nothing,
    bottom_size::Union{Nothing,Integer}=nothing,
    margin::Margin=Margin(0),
) 
    length(body) > 1 && throw(ArgumentError("AppShell accepts at most one positional body argument"))
    return _app_shell(
        isempty(body) ? nothing : body[1];
        title,
        subtitle,
        header,
        toolbar,
        sidebar,
        sidebar_side,
        sidebar_size,
        status,
        shortcuts,
        footer,
        top_size,
        bottom_size,
        margin,
    )
end

function _app_shell(
    body::Any=nothing;
    title::Union{Nothing,AbstractString}=nothing,
    subtitle::AbstractString="",
    header=nothing,
    toolbar=nothing,
    sidebar=nothing,
    sidebar_side::Symbol=:left,
    sidebar_size::Integer=24,
    status=nothing,
    shortcuts=nothing,
    footer=nothing,
    top_size::Union{Nothing,Integer}=nothing,
    bottom_size::Union{Nothing,Integer}=nothing,
    margin::Margin=Margin(0),
)
    sidebar_side in (:left, :right) ||
        throw(ArgumentError("app shell sidebar side must be :left or :right"))
    top = _app_shell_top(header, title, subtitle, toolbar)
    bottom = footer !== nothing ? footer : shortcuts !== nothing ? StatusBar(shortcuts) : status
    resolved_top_size = top_size === nothing ? _app_shell_default_top_size(header, title, subtitle, toolbar) : Int(top_size)
    resolved_bottom_size = bottom_size === nothing ? _app_shell_default_bottom_size(bottom) : Int(bottom_size)
    left = sidebar_side == :left ? sidebar : nothing
    right = sidebar_side == :right ? sidebar : nothing
    left_size = sidebar_side == :left && sidebar !== nothing ? Int(sidebar_size) : 0
    right_size = sidebar_side == :right && sidebar !== nothing ? Int(sidebar_size) : 0
    return AppShell(Dock(
        top=top,
        top_size=resolved_top_size,
        left=left,
        left_size=left_size,
        right=right,
        right_size=right_size,
        bottom=bottom,
        bottom_size=resolved_bottom_size,
        center=body,
        margin=margin,
    ))
end

measure(widget::AppShell, available::Rect) = measure(widget.dock, available)

render!(buffer::Buffer, widget::AppShell, area::Rect) =
    render!(buffer, widget.dock, area)

"""
    app_shell_dock(shell)

Return the composed `Dock` backing an `AppShell`.
"""
app_shell_dock(widget::AppShell) = widget.dock

"""
    app_shell_layout(shell)

Return the composed `DockLayout` backing an `AppShell`.
"""
app_shell_layout(widget::AppShell) = widget.dock.layout

"""
    app_shell_regions(shell, area)

Return the docked child widgets, docked regions, and remaining center region for
an `AppShell` in `area`.
"""
app_shell_regions(widget::AppShell, area::Rect) =
    _dock_regions(widget.dock.layout, area)

"""
    app_shell_summary(shell)

Return a named-tuple summary of the regions composed by an `AppShell`.
"""
function app_shell_summary(widget::AppShell)
    layout = widget.dock.layout
    return (
        has_top=layout.top !== nothing,
        has_right=layout.right !== nothing,
        has_bottom=layout.bottom !== nothing,
        has_left=layout.left !== nothing,
        has_center=layout.center !== nothing,
        top_size=layout.top_size,
        right_size=layout.right_size,
        bottom_size=layout.bottom_size,
        left_size=layout.left_size,
        sidebar_side=layout.left !== nothing ? :left : layout.right !== nothing ? :right : :none,
    )
end

SemanticToolkit.widget_semantic_descriptor(widget::AppShell, state) =
    _static_group_semantics("App shell"; metadata=Dict(
        :top_size => widget.dock.layout.top_size,
        :right_size => widget.dock.layout.right_size,
        :bottom_size => widget.dock.layout.bottom_size,
        :left_size => widget.dock.layout.left_size,
    ))

register_app_shell_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::AppShell) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        _dock_layout_semantic_value(widget.dock.layout; label="App shell"),
        "app shell semantic action is not supported",
    )

"""
Dedicated status message widget.

`Status` follows the same rendering structure as `Alert` so existing alert styling
and focus requirements remain consistent while exposing a first-class API name for
application messages.
"""
struct Status
    alert::Alert

    function Status(alert::Alert)
        return new(alert)
    end
end

"""
Construct a status widget from plain message text.
"""
Status(message::AbstractString; title::AbstractString="Status", severity::Symbol=:info) =
    Status(Alert(message; title=title, severity=severity))

render!(buffer::Buffer, widget::Status, area::Rect) = render!(buffer, widget.alert, area)

function SemanticToolkit.widget_semantic_descriptor(widget::Status, state)
    return SemanticToolkit.SemanticDescriptor(
        widget.alert.severity in (:warning, :error) ? Accessibility.AlertRole : Accessibility.StatusRole;
        label="Status",
        description=_core_text_plain(widget.alert.message),
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.DismissSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(:severity => widget.alert.severity),
    )
end

function _feedback_semantic_value(widget::Status)
    return Dict{Symbol,Any}(
        :label => "Status",
        :message => _core_text_plain(widget.alert.message),
        :severity => widget.alert.severity,
    )
end

"""
Dedicated toast notification widget.

`Toast` wraps the existing notification model and renders through a compact,
single-item notification surface suitable for transient UI feedback.
"""
struct Toast
    notification::Notification

    function Toast(notification::Notification)
        return new(notification)
    end
end

"""
Construct a toast widget from plain message text.
"""
Toast(message::AbstractString; title::AbstractString="", severity::Symbol=:info, timeout::Union{Nothing,Real}=5.0) =
    Toast(Notification(message; title=title, severity=severity, timeout=timeout))

function render!(buffer::Buffer, widget::Toast, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    color = widget.notification.severity == :error ? AnsiColor(1) :
            widget.notification.severity == :warning ? AnsiColor(3) :
            widget.notification.severity == :success ? AnsiColor(2) : AnsiColor(4)
    prefix = isempty(widget.notification.title) ? "" : widget.notification.title * ": "
    render!(buffer, Label(prefix * widget.notification.message; style=Style(foreground=color)), active)
    return buffer
end

function SemanticToolkit.widget_semantic_descriptor(widget::Toast, state)
    return SemanticToolkit.SemanticDescriptor(
        widget.notification.severity in (:warning, :error) ? Accessibility.AlertRole : Accessibility.StatusRole;
        label=isempty(widget.notification.title) ? "Toast" : widget.notification.title,
        description=widget.notification.message,
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.DismissSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :severity => widget.notification.severity,
            :timeout_ns => widget.notification.timeout_ns,
        ),
    )
end

function _feedback_semantic_value(widget::Toast)
    return Dict{Symbol,Any}(
        :title => widget.notification.title,
        :message => widget.notification.message,
        :severity => widget.notification.severity,
        :timeout_ns => widget.notification.timeout_ns,
    )
end

function _register_feedback_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    value,
    unsupported::AbstractString,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction, Accessibility.DismissSemanticAction)
            return Accessibility.SemanticActionResult(true; value=value)
        end
        return Accessibility.SemanticActionResult(false; message=unsupported)
    end)
    return dispatcher
end

register_status_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Status) =
    _register_feedback_semantic_handlers!(dispatcher, id, _feedback_semantic_value(widget), "status semantic action is not supported")

register_toast_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Toast) =
    _register_feedback_semantic_handlers!(dispatcher, id, _feedback_semantic_value(widget), "toast semantic action is not supported")

"""
Hover-triggered tooltip widget with explicit externally owned `TooltipState`.

`Tooltip` renders supplemental content near an anchor rectangle after the state
becomes visible. Applications can drive the state through mouse hover,
`TickEvent`, and escape-key dismissal without hidden timers or global state.
"""
struct Tooltip{W}
    content::W
    anchor::Rect
    target::Any
    width::Int
    height::Int
    preferred::Symbol
    gap::Int
    margin::Int
    delay_ms::Int
    dismissible::Bool
    block::Union{Nothing,Block}
    label::String
end

function Tooltip(
    content,
    anchor::Rect;
    target=:tooltip,
    width::Integer=40,
    height::Integer=3,
    preferred::Symbol=:above,
    gap::Integer=1,
    margin::Integer=0,
    delay_ms::Integer=500,
    dismissible::Bool=true,
    block::Union{Nothing,Block}=Block(),
    label::AbstractString="Tooltip",
)
    width >= 0 || throw(ArgumentError("tooltip width cannot be negative"))
    height >= 0 || throw(ArgumentError("tooltip height cannot be negative"))
    gap >= 0 || throw(ArgumentError("tooltip gap cannot be negative"))
    margin >= 0 || throw(ArgumentError("tooltip margin cannot be negative"))
    delay_ms >= 0 || throw(ArgumentError("tooltip delay cannot be negative"))
    _tooltip_placement(preferred)
    return Tooltip(
        content,
        anchor,
        target,
        Int(width),
        Int(height),
        preferred,
        Int(gap),
        Int(margin),
        Int(delay_ms),
        dismissible,
        block,
        String(label),
    )
end

Tooltip(content::AbstractString, anchor::Rect; kwargs...) =
    Tooltip(Label(content), anchor; kwargs...)

_tooltip_placement(placement::Symbol) = placement == :above ? AbovePopover : placement == :below ? BelowPopover :
    placement == :left ? LeftPopover : placement == :right ? RightPopover :
    throw(ArgumentError("tooltip placement must be :above, :below, :left, or :right"))

state_for(widget::Tooltip) = TooltipState(delay_ms=widget.delay_ms)

measure(widget::Tooltip, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function _tooltip_area(widget::Tooltip, area::Rect)
    viewport = ComponentRect(area.row, area.column, area.width, area.height)
    anchor = ComponentRect(widget.anchor.row, widget.anchor.column, widget.anchor.width, widget.anchor.height)
    result = place_popover(
        anchor,
        widget.width,
        widget.height,
        viewport;
        preferred=_tooltip_placement(widget.preferred),
        gap=widget.gap,
        margin=widget.margin,
    )
    return result, Rect(result.rect.row, result.rect.column, result.rect.height, result.rect.width)
end

function render!(buffer::Buffer, widget::Tooltip, area::Rect, state::TooltipState)
    state.visible || return buffer
    state.target == widget.target || return buffer
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    _, target = _tooltip_area(widget, active)
    target = intersection(buffer.area, target)
    isempty(target) && return buffer
    if widget.block !== nothing
        render!(buffer, widget.block, target)
        target = intersection(buffer.area, inner(widget.block, target))
    end
    isempty(target) || render!(buffer, widget.content, target)
    return buffer
end

render!(buffer::Buffer, widget::Tooltip, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::TooltipState, widget::Tooltip, event::TickEvent)
    if state.hovering && !state.visible && event.timestamp_ns < state.entered_ns
        state.entered_ns = event.timestamp_ns
    end
    return tick_tooltip!(state; now_ns=event.timestamp_ns)
end

function handle!(state::TooltipState, widget::Tooltip, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    event.key.code == :escape || return false
    state.visible && widget.dismissible || return false
    dismiss_tooltip!(state)
    return true
end

function handle!(state::TooltipState, widget::Tooltip, event::MouseEvent, area::Rect)
    event.action in (MouseMove, MousePress, MouseDrag) || return false
    contains(widget.anchor, event.position) && contains(area, event.position) || begin
        state.hovering && state.target == widget.target || return false
        leave_tooltip!(state)
        return true
    end
    state.hovering && state.target == widget.target && return false
    begin_tooltip_hover!(state, widget.target, widget.content)
    return true
end

_tooltip_content_description(content) = nothing
_tooltip_content_description(content::Label) = _core_line_plain(content.line)

function SemanticToolkit.widget_semantic_descriptor(widget::Tooltip, state::TooltipState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        description=_tooltip_content_description(widget.content),
        state=Accessibility.SemanticState(
            hidden=!state.visible,
            readonly=true,
        ),
        actions=state.visible && widget.dismissible ? [Accessibility.FocusSemanticAction, Accessibility.DismissSemanticAction] : Accessibility.SemanticAction[],
        metadata=Dict(:preferred => widget.preferred, :delay_ms => widget.delay_ms, :target => widget.target),
    )
end

function register_tooltip_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::TooltipState;
    dismissible::Bool=true,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.visible)
        elseif request.action == Accessibility.DismissSemanticAction
            dismissible || return Accessibility.SemanticActionResult(false; message="tooltip is not dismissible")
            dismiss_tooltip!(state)
            return Accessibility.SemanticActionResult(true; value=state.visible)
        end
        return Accessibility.SemanticActionResult(false; message="tooltip semantic action is not supported")
    end)
    return dispatcher
end

function SemanticToolkit.widget_semantic_descriptor(widget::Skeleton, state::SkeletonState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.StatusRole;
        label="Loading",
        state=Accessibility.SemanticState(readonly=true, busy=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.IncrementSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :phase => state.phase,
            :period => state.period,
            :highlight_width => widget.highlight_width,
        ),
    )
end

_loading_semantic_value(widget::Skeleton, state::SkeletonState) = Dict{Symbol,Any}(
    :phase => state.phase,
    :period => state.period,
    :highlight_width => widget.highlight_width,
)

function register_skeleton_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Skeleton,
    state::SkeletonState,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction)
            return Accessibility.SemanticActionResult(true; value=_loading_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            tick_skeleton!(state)
            return Accessibility.SemanticActionResult(true; value=_loading_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="skeleton semantic action is not supported")
    end)
    return dispatcher
end

function SemanticToolkit.widget_semantic_descriptor(widget::EmptyState, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.StatusRole;
        label=widget.title,
        description=widget.message,
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:action_label => widget.action_label),
    )
end

function SemanticToolkit.widget_semantic_children(widget::EmptyState, state, id)
    widget.action_label === nothing && return Accessibility.SemanticNode[]
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/action",
            Accessibility.ButtonRole;
            label=widget.action_label,
            actions=Accessibility.SemanticAction[Accessibility.ActivateSemanticAction],
        ),
    ]
end

function register_empty_state_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::EmptyState;
    value=widget.action_label,
)
    widget.action_label === nothing && return dispatcher
    Accessibility.register_semantic_handler!(
        dispatcher,
        "$(id)/action",
        function (request)
            request.action == Accessibility.ActivateSemanticAction ||
                return Accessibility.SemanticActionResult(
                    false;
                    message="empty-state semantic action is not supported",
                )
            return Accessibility.SemanticActionResult(true; value)
        end,
    )
    return dispatcher
end

struct StatusBar
    footer::Footer
end

StatusBar(source::Interaction.BindingMap; kwargs...) =
    _make_status_bar(binding_key_hints(source); kwargs...)

StatusBar(source::Interaction.BindingLayer; kwargs...) =
    _make_status_bar(binding_key_hints(source); kwargs...)

StatusBar(source::Interaction.BindingStack; kwargs...) =
    _make_status_bar(binding_key_hints(source); kwargs...)

StatusBar(hints::AbstractVector; kwargs...) = _make_status_bar(hints; kwargs...)

StatusBar(hints::Tuple; kwargs...) = _make_status_bar(hints; kwargs...)

_make_status_bar(hints; kwargs...) = StatusBar(Footer(hints; kwargs...))

render!(buffer::Buffer, widget::StatusBar, area::Rect) =
    render!(buffer, widget.footer, area)

SemanticToolkit.widget_semantic_descriptor(widget::StatusBar, state) =
    SemanticToolkit.widget_semantic_descriptor(widget.footer, state)

SemanticToolkit.widget_semantic_children(widget::StatusBar, state, id) =
    SemanticToolkit.widget_semantic_children(widget.footer, state, id)

register_status_bar_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::StatusBar,
) = _register_hint_bar_semantic_handlers!(dispatcher, id, widget.footer.hints, "Keyboard shortcuts")

struct TitleBar
    header::Header
end

TitleBar(title::AbstractString; kwargs...) = TitleBar(Header(title; kwargs...))

render!(buffer::Buffer, widget::TitleBar, area::Rect) =
    render!(buffer, widget.header, area)

SemanticToolkit.widget_semantic_descriptor(widget::TitleBar, state) =
    SemanticToolkit.widget_semantic_descriptor(widget.header, state)

register_title_bar_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::TitleBar,
) = _register_readonly_chrome_semantic_handlers!(
    dispatcher,
    id,
    Dict{Symbol,Any}(:title => widget.header.title, :subtitle => widget.header.subtitle),
    "title bar semantic action is not supported",
)

"""
File picker compatibility widget.

`FilePicker` provides a stable entrypoint for file-system navigation and selection
using the existing `FileBrowser` state and input behavior.
"""
const FilePickerState = FileBrowserState

"""
Immediate-mode file picker widget configuration.

Render and interaction delegate to the existing `FileBrowser` core behavior:
`render_file_browser`, `handle_file_browser_key!`, and `handle_file_browser_pointer!`.
"""
struct FilePicker
    path::String
    root::String
    width::Int
    height::Int
    first_entry::Int
    bindings::FileBrowserBindings
    focus_on_hover::Bool
    select_on_press::Bool
    mode::FilePickerMode
    show_hidden::Bool
    follow_symlinks::Bool
    directories_first::Bool
    sort_field::FileSortField
    sort_direction::FileSortDirection
    filter::Union{Nothing,String,Regex}
    maximum_entries::Int
end

function FilePicker(
    path::AbstractString=pwd();
    root::AbstractString=path,
    width::Integer=80,
    height::Integer=24,
    first_entry::Integer=1,
    bindings::FileBrowserBindings=default_file_browser_bindings(),
    focus_on_hover::Bool=true,
    select_on_press::Bool=true,
    vim::Bool=false,
    mode::FilePickerMode=SelectFileMode,
    show_hidden::Bool=false,
    follow_symlinks::Bool=false,
    directories_first::Bool=true,
    sort_field::FileSortField=FileNameSort,
    sort_direction::FileSortDirection=AscendingFileSort,
    filter::Union{Nothing,AbstractString,Regex}=nothing,
    maximum_entries::Integer=100_000,
)
    width >= 0 || throw(ArgumentError("file picker width must be non-negative"))
    height >= 0 || throw(ArgumentError("file picker height must be non-negative"))
    first_entry > 0 || throw(ArgumentError("file picker first_entry must be positive"))
    maximum_entries >= 0 || throw(ArgumentError("maximum_entries must be non-negative"))
    maximum_entries <= typemax(Int) || throw(ArgumentError("maximum_entries is too large"))
    effective_bindings = vim ? default_file_browser_bindings(vim=true) : bindings
    return FilePicker(
        String(path),
        String(root),
        Int(width),
        Int(height),
        Int(first_entry),
        effective_bindings,
        Bool(focus_on_hover),
        Bool(select_on_press),
        mode,
        Bool(show_hidden),
        Bool(follow_symlinks),
        Bool(directories_first),
        sort_field,
        sort_direction,
        isnothing(filter) ? nothing : (filter isa String ? String(filter) : filter),
        Int(maximum_entries),
    )
end

"""Build a default picker state for this widget configuration."""
state_for(widget::FilePicker) = FileBrowserState(
    widget.path;
    root=widget.root,
    mode=widget.mode,
    show_hidden=widget.show_hidden,
    follow_symlinks=widget.follow_symlinks,
    directories_first=widget.directories_first,
    sort_field=widget.sort_field,
    sort_direction=widget.sort_direction,
    filter=widget.filter,
    maximum_entries=widget.maximum_entries,
)

measure(widget::FilePicker, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::FilePicker, area::Rect, state::FilePickerState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    lines = render_file_browser(
        state;
        width=min(active.width, widget.width),
        height=min(active.height, widget.height),
        first_entry=widget.first_entry,
    )
    rendered = rich_lines_to_core_text(CoreTextAdapter(), lines)
    return render!(buffer, Paragraph(rendered), active)
end

render!(buffer::Buffer, widget::FilePicker, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::FilePickerState, widget::FilePicker, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_file_browser_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
        viewport_height=max(1, min(widget.height, 24)),
    )
    return result.consumed
end

function handle!(
    state::FilePickerState,
    widget::FilePicker,
    event::MouseEvent,
    area::Rect,
)
    contains(area, event.position) || return false
    inside_row = event.position.row - area.row + 1
    inside_row < 1 && return false
    if event.action == MouseMove
        kind = FilePointerHover
    elseif event.button != LeftMouseButton
        return false
    elseif event.action == MousePress && event.click_count > 1
        kind = FilePointerDoublePress
    elseif event.action == MousePress
        kind = FilePointerPress
    elseif event.action == MouseRelease && event.click_count > 1
        kind = FilePointerDoublePress
    else
        kind = FilePointerPress
    end
    result = handle_file_browser_pointer!(
        state,
        FilePointerEvent(
            kind,
            inside_row,
            1;
            control=in(CTRL, event.modifiers),
        );
        first_entry=widget.first_entry,
        focus_on_hover=widget.focus_on_hover,
        select_on_press=widget.select_on_press,
    )
    return result.consumed
end

function SemanticToolkit.widget_semantic_descriptor(::FilePicker, state::FilePickerState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TreeRole;
        label="File picker",
        state=Accessibility.SemanticState(focusable=true, busy=state.loading),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:path => state.current_path, :root => state.root, :generation => state.generation, :mode => state.mode),
    )
end

function SemanticToolkit.widget_semantic_children(::FilePicker, state::FilePickerState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/entry-$(index)",
            Accessibility.TreeItemRole;
            label=entry.name,
            description=entry.kind == DirectoryFileEntry ? "directory" : "file",
            state=Accessibility.SemanticState(
                focusable=true,
                focused=state.cursor == index,
                selected=entry.path in state.selected,
            ),
            actions=entry.kind == DirectoryFileEntry ? [Accessibility.SelectSemanticAction, Accessibility.ActivateSemanticAction, Accessibility.ExpandSemanticAction] : [Accessibility.SelectSemanticAction, Accessibility.ActivateSemanticAction],
            metadata=Dict(:path => entry.path, :kind => entry.kind),
        ) for (index, entry) in enumerate(state.entries)
    ]
end

"""
Directory picker widget backed by `FileBrowserState`.

`DirectoryPicker` is the picker-named surface for selecting directories. It
delegates rendering, navigation, filtering, and input behavior to `FilePicker`
with `SelectDirectoryMode`.
"""
struct DirectoryPicker
    picker::FilePicker
end

function DirectoryPicker(
    path::AbstractString=pwd();
    root::AbstractString=path,
    width::Integer=80,
    height::Integer=24,
    first_entry::Integer=1,
    bindings::FileBrowserBindings=default_file_browser_bindings(),
    focus_on_hover::Bool=true,
    select_on_press::Bool=true,
    vim::Bool=false,
    show_hidden::Bool=false,
    follow_symlinks::Bool=false,
    directories_first::Bool=true,
    sort_field::FileSortField=FileNameSort,
    sort_direction::FileSortDirection=AscendingFileSort,
    filter::Union{Nothing,AbstractString,Regex}=nothing,
    maximum_entries::Integer=100_000,
)
    return DirectoryPicker(FilePicker(
        path;
        root,
        width,
        height,
        first_entry,
        bindings,
        focus_on_hover,
        select_on_press,
        vim,
        mode=SelectDirectoryMode,
        show_hidden,
        follow_symlinks,
        directories_first,
        sort_field,
        sort_direction,
        filter,
        maximum_entries,
    ))
end

state_for(widget::DirectoryPicker) = state_for(widget.picker)
measure(widget::DirectoryPicker, available::Rect) = measure(widget.picker, available)
render!(buffer::Buffer, widget::DirectoryPicker, area::Rect) =
    render!(buffer, widget.picker, area)
render!(buffer::Buffer, widget::DirectoryPicker, area::Rect, state::FilePickerState) =
    render!(buffer, widget.picker, area, state)
handle!(state::FilePickerState, widget::DirectoryPicker, event::KeyEvent) =
    handle!(state, widget.picker, event)
handle!(state::FilePickerState, widget::DirectoryPicker, event::MouseEvent, area::Rect) =
    handle!(state, widget.picker, event, area)

function SemanticToolkit.widget_semantic_descriptor(::DirectoryPicker, state::FilePickerState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TreeRole;
        label="Directory picker",
        state=Accessibility.SemanticState(focusable=true, busy=state.loading),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:path => state.current_path, :root => state.root, :generation => state.generation, :mode => SelectDirectoryMode),
    )
end

SemanticToolkit.widget_semantic_children(::DirectoryPicker, state::FilePickerState, id) =
    SemanticToolkit.widget_semantic_children(FilePicker(state.current_path; root=state.root, mode=SelectDirectoryMode), state, id)

"""
Directory tree navigation widget backed by `FileBrowserState`.

`DirectoryTree` is the Textual-style tree-named surface for navigating directory
entries. It intentionally shares `DirectoryTreeState` with `FileBrowserState`
and delegates rendering, navigation, filtering, and input behavior to
`DirectoryPicker`.
"""
struct DirectoryTree
    picker::DirectoryPicker
end

"""Compatibility state alias for `DirectoryTree`; identical to `FileBrowserState`."""
const DirectoryTreeState = FileBrowserState

function DirectoryTree(
    path::AbstractString=pwd();
    root::AbstractString=path,
    width::Integer=80,
    height::Integer=24,
    first_entry::Integer=1,
    bindings::FileBrowserBindings=default_file_browser_bindings(),
    focus_on_hover::Bool=true,
    select_on_press::Bool=true,
    vim::Bool=false,
    show_hidden::Bool=false,
    follow_symlinks::Bool=false,
    directories_first::Bool=true,
    sort_field::FileSortField=FileNameSort,
    sort_direction::FileSortDirection=AscendingFileSort,
    filter::Union{Nothing,AbstractString,Regex}=nothing,
    maximum_entries::Integer=100_000,
)
    return DirectoryTree(DirectoryPicker(
        path;
        root,
        width,
        height,
        first_entry,
        bindings,
        focus_on_hover,
        select_on_press,
        vim,
        show_hidden,
        follow_symlinks,
        directories_first,
        sort_field,
        sort_direction,
        filter,
        maximum_entries,
    ))
end

state_for(widget::DirectoryTree) = state_for(widget.picker)
measure(widget::DirectoryTree, available::Rect) = measure(widget.picker, available)
render!(buffer::Buffer, widget::DirectoryTree, area::Rect) =
    render!(buffer, widget.picker, area)
render!(buffer::Buffer, widget::DirectoryTree, area::Rect, state::DirectoryTreeState) =
    render!(buffer, widget.picker, area, state)
handle!(state::DirectoryTreeState, widget::DirectoryTree, event::KeyEvent) =
    handle!(state, widget.picker, event)
handle!(state::DirectoryTreeState, widget::DirectoryTree, event::MouseEvent, area::Rect) =
    handle!(state, widget.picker, event, area)

function SemanticToolkit.widget_semantic_descriptor(::DirectoryTree, state::DirectoryTreeState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TreeRole;
        label="Directory tree",
        state=Accessibility.SemanticState(focusable=true, busy=state.loading),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:path => state.current_path, :root => state.root, :generation => state.generation, :mode => SelectDirectoryMode),
    )
end

SemanticToolkit.widget_semantic_children(::DirectoryTree, state::DirectoryTreeState, id) =
    SemanticToolkit.widget_semantic_children(FilePicker(state.current_path; root=state.root, mode=SelectDirectoryMode), state, id)

"""
Multiple-file picker widget backed by `FileBrowserState`.

`MultiFilePicker` is the direct widget for multi-selection workflows. It
delegates rendering, navigation, filtering, and input behavior to `FilePicker`
with `SelectMultipleMode`.
"""
struct MultiFilePicker
    picker::FilePicker
end

function MultiFilePicker(
    path::AbstractString=pwd();
    root::AbstractString=path,
    width::Integer=80,
    height::Integer=24,
    first_entry::Integer=1,
    bindings::FileBrowserBindings=default_file_browser_bindings(),
    focus_on_hover::Bool=true,
    select_on_press::Bool=true,
    vim::Bool=false,
    show_hidden::Bool=false,
    follow_symlinks::Bool=false,
    directories_first::Bool=true,
    sort_field::FileSortField=FileNameSort,
    sort_direction::FileSortDirection=AscendingFileSort,
    filter::Union{Nothing,AbstractString,Regex}=nothing,
    maximum_entries::Integer=100_000,
)
    return MultiFilePicker(FilePicker(
        path;
        root,
        width,
        height,
        first_entry,
        bindings,
        focus_on_hover,
        select_on_press,
        vim,
        mode=SelectMultipleMode,
        show_hidden,
        follow_symlinks,
        directories_first,
        sort_field,
        sort_direction,
        filter,
        maximum_entries,
    ))
end

state_for(widget::MultiFilePicker) = state_for(widget.picker)
measure(widget::MultiFilePicker, available::Rect) = measure(widget.picker, available)
render!(buffer::Buffer, widget::MultiFilePicker, area::Rect) =
    render!(buffer, widget.picker, area)
render!(buffer::Buffer, widget::MultiFilePicker, area::Rect, state::FilePickerState) =
    render!(buffer, widget.picker, area, state)
handle!(state::FilePickerState, widget::MultiFilePicker, event::KeyEvent) =
    handle!(state, widget.picker, event)
handle!(state::FilePickerState, widget::MultiFilePicker, event::MouseEvent, area::Rect) =
    handle!(state, widget.picker, event, area)

function SemanticToolkit.widget_semantic_descriptor(::MultiFilePicker, state::FilePickerState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TreeRole;
        label="Multiple-file picker",
        state=Accessibility.SemanticState(focusable=true, busy=state.loading),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:path => state.current_path, :root => state.root, :generation => state.generation, :mode => SelectMultipleMode),
    )
end

SemanticToolkit.widget_semantic_children(::MultiFilePicker, state::FilePickerState, id) =
    SemanticToolkit.widget_semantic_children(FilePicker(state.current_path; root=state.root, mode=SelectMultipleMode), state, id)

function _file_picker_result_value(state::FilePickerState)
    entry = current_file_entry(state)
    return Dict(
        :path => state.current_path,
        :cursor => state.cursor,
        :entry => entry === nothing ? nothing : entry.path,
        :choices => String[choice.path for choice in file_choices(state)],
    )
end

function _find_file_picker_entry(state::FilePickerState, path::String)
    return findfirst(entry -> entry.path == path, state.entries)
end

function _register_file_picker_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::FilePickerState,
    unsupported_message::AbstractString,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction ||
           request.action == Accessibility.ScrollIntoViewSemanticAction
            isempty(state.entries) || set_file_cursor!(state, something(state.cursor, 1))
            return Accessibility.SemanticActionResult(true; value=_file_picker_result_value(state))
        elseif request.action == Accessibility.IncrementSemanticAction
            move_file_cursor!(state, 1)
            return Accessibility.SemanticActionResult(true; value=_file_picker_result_value(state))
        elseif request.action == Accessibility.DecrementSemanticAction
            move_file_cursor!(state, -1)
            return Accessibility.SemanticActionResult(true; value=_file_picker_result_value(state))
        end
        return Accessibility.SemanticActionResult(false; message=unsupported_message)
    end)
    for entry in copy(state.entries)
        entry_id = "$(node_id)/entry-$(_find_file_picker_entry(state, entry.path))"
        entry_path = entry.path
        Accessibility.register_semantic_handler!(dispatcher, entry_id, function (request)
            index = _find_file_picker_entry(state, entry_path)
            index === nothing && return Accessibility.SemanticActionResult(false; message="file picker entry is not available")
            set_file_cursor!(state, index)
            active_entry = current_file_entry(state)
            if request.action == Accessibility.FocusSemanticAction
                return Accessibility.SemanticActionResult(true; value=entry_path)
            elseif request.action == Accessibility.SelectSemanticAction
                toggle_file_selection!(state)
                return Accessibility.SemanticActionResult(true; value=_file_picker_result_value(state))
            elseif request.action == Accessibility.ExpandSemanticAction
                active_entry === nothing || active_entry.kind == DirectoryFileEntry ||
                    return Accessibility.SemanticActionResult(false; message="file picker entry is not a directory")
                entered = enter_file_entry!(state)
                return Accessibility.SemanticActionResult(entered; value=_file_picker_result_value(state))
            elseif request.action == Accessibility.ActivateSemanticAction
                if active_entry !== nothing &&
                   active_entry.kind == DirectoryFileEntry &&
                   state.mode == SelectFileMode
                    entered = enter_file_entry!(state)
                    return Accessibility.SemanticActionResult(entered; value=_file_picker_result_value(state))
                end
                choices = choose_file_entry!(state)
                return Accessibility.SemanticActionResult(!isempty(choices); value=_file_picker_result_value(state))
            end
            return Accessibility.SemanticActionResult(false; message="file picker entry semantic action is not supported")
        end)
    end
    return dispatcher
end

register_file_picker_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::FilePicker,
    state::FilePickerState,
) = _register_file_picker_semantic_handlers!(
    dispatcher,
    id,
    state,
    "file picker semantic action is not supported",
)

register_directory_picker_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::DirectoryPicker,
    state::FilePickerState,
) = _register_file_picker_semantic_handlers!(
    dispatcher,
    id,
    state,
    "directory picker semantic action is not supported",
)

register_directory_tree_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::DirectoryTree,
    state::DirectoryTreeState,
) = _register_file_picker_semantic_handlers!(
    dispatcher,
    id,
    state,
    "directory tree semantic action is not supported",
)

register_multi_file_picker_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    ::MultiFilePicker,
    state::FilePickerState,
) = _register_file_picker_semantic_handlers!(
    dispatcher,
    id,
    state,
    "multiple-file picker semantic action is not supported",
)

"""
Compatibility date input widget.

`DateInput` is a stable-form adapter over `DatePickerState` for projects that
expect a direct date-entry widget in immediate-mode. Rendering and keyboard
interaction are delegated to `render_date_picker` and `handle_data_entry_key!`.
"""
const DateInputState = DatePickerState

struct DateInput
    selected::Dates.Date
    minimum::Union{Nothing,Dates.Date}
    maximum::Union{Nothing,Dates.Date}
    week_start::Int
    width::Int
    height::Int
    block::Union{Nothing,Block}
    bindings::DataEntryBindings
end

function DateInput(;
    selected::Dates.Date=Dates.Date(Dates.today()),
    minimum::Union{Nothing,Dates.Date}=nothing,
    maximum::Union{Nothing,Dates.Date}=nothing,
    week_start::Integer=1,
    width::Integer=28,
    height::Integer=7,
    block::Union{Nothing,Block}=nothing,
    bindings::DataEntryBindings=default_data_entry_bindings(),
)
    width >= 0 || throw(ArgumentError("date input width must be non-negative"))
    height >= 0 || throw(ArgumentError("date input height must be non-negative"))
    1 <= week_start <= 7 || throw(ArgumentError("week start must be between 1 and 7"))
    return DateInput(
        selected,
        minimum,
        maximum,
        Int(week_start),
        Int(width),
        Int(height),
        block,
        bindings,
    )
end

state_for(widget::DateInput) = DatePickerState(
    selected=widget.selected,
    minimum=widget.minimum,
    maximum=widget.maximum,
    week_start=widget.week_start,
)

function _data_input_active_area(buffer::Buffer, widget, area::Rect)
    if isnothing(widget.block)
        return intersection(buffer.area, area)
    end
    render!(buffer, widget.block, area)
    return intersection(buffer.area, inner(widget.block, area))
end

measure(widget::DateInput, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::DateInput, area::Rect, state::DateInputState)
    active = _data_input_active_area(buffer, widget, area)
    isempty(active) && return buffer
    clipped = Rect(active.row, active.column, min(active.height, widget.height), min(active.width, widget.width))
    isempty(clipped) && return buffer
    lines = render_date_picker(state; width=min(clipped.width, widget.width))
    rendered = rich_lines_to_core_text(CoreTextAdapter(), lines)
    render!(buffer, Paragraph(rendered), clipped)
    return buffer
end

render!(buffer::Buffer, widget::DateInput, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::DateInputState, widget::DateInput, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_data_entry_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    )
    return result.consumed
end

handle!(::DateInputState, ::DateInput, ::PasteEvent) = false
function handle!(state::DateInputState, widget::DateInput, event::MouseEvent, area::Rect)
    event.action == MouseScroll && contains(area, event.position) || return false
    key = event.button == WheelUpButton ? :up : event.button == WheelDownButton ? :down : nothing
    key === nothing && return false
    return handle_data_entry_key!(state, widget.bindings, key).consumed
end

function SemanticToolkit.widget_semantic_descriptor(::DateInput, state::DateInputState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Date input",
        state=Accessibility.SemanticState(focusable=true, value=string(state.selected)),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:visible_month => state.visible_month),
    )
end

_semantic_date_value(value) = value isa Dates.Date ? value : Dates.Date(string(value))

function register_date_picker_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::DatePickerState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.selected)
        elseif request.action == Accessibility.IncrementSemanticAction
            move_date_picker!(state, 1)
            return Accessibility.SemanticActionResult(true; value=state.selected)
        elseif request.action == Accessibility.DecrementSemanticAction
            move_date_picker!(state, -1)
            return Accessibility.SemanticActionResult(true; value=state.selected)
        elseif request.action == Accessibility.SetValueSemanticAction
            try
                select_date!(state, _semantic_date_value(request.value))
                return Accessibility.SemanticActionResult(true; value=state.selected)
            catch
                return Accessibility.SemanticActionResult(false; message="date value must be a Date or ISO date string")
            end
        end
        return Accessibility.SemanticActionResult(false; message="date picker semantic action is not supported")
    end)
    return dispatcher
end

register_date_input_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::DateInputState,
) = register_date_picker_semantic_handlers!(dispatcher, id, state)

"""
Calendar-style date picker widget backed by `DatePickerState`.

`DatePicker` is the direct picker-named surface for applications that want a
calendar control rather than a form-field naming convention. It delegates all
date movement, rendering, and state ownership to the same implementation as
`DateInput`.
"""
struct DatePicker
    input::DateInput
end

function DatePicker(;
    selected::Dates.Date=Dates.Date(Dates.today()),
    minimum::Union{Nothing,Dates.Date}=nothing,
    maximum::Union{Nothing,Dates.Date}=nothing,
    week_start::Integer=1,
    width::Integer=28,
    height::Integer=7,
    block::Union{Nothing,Block}=nothing,
    bindings::DataEntryBindings=default_data_entry_bindings(),
)
    return DatePicker(DateInput(; selected, minimum, maximum, week_start, width, height, block, bindings))
end

state_for(widget::DatePicker) = state_for(widget.input)
measure(widget::DatePicker, available::Rect) = measure(widget.input, available)
render!(buffer::Buffer, widget::DatePicker, area::Rect) = render!(buffer, widget.input, area)
render!(buffer::Buffer, widget::DatePicker, area::Rect, state::DatePickerState) =
    render!(buffer, widget.input, area, state)
handle!(state::DatePickerState, widget::DatePicker, event::KeyEvent) =
    handle!(state, widget.input, event)
handle!(state::DatePickerState, widget::DatePicker, event::PasteEvent) =
    handle!(state, widget.input, event)
handle!(state::DatePickerState, widget::DatePicker, event::MouseEvent, area::Rect) =
    handle!(state, widget.input, event, area)

function SemanticToolkit.widget_semantic_descriptor(::DatePicker, state::DatePickerState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Date picker",
        state=Accessibility.SemanticState(focusable=true, value=string(state.selected)),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:visible_month => state.visible_month),
    )
end

"""
Compatibility time input widget.

`TimeInput` adapts `TimePickerState` to the immediate-mode interface and keeps
keyboard behavior aligned with data-entry controls.
"""
const TimeInputState = TimePickerState

struct TimeInput
    value::Dates.Time
    minimum::Dates.Time
    maximum::Dates.Time
    step_seconds::Int
    width::Int
    height::Int
    block::Union{Nothing,Block}
    bindings::DataEntryBindings
end

function TimeInput(;
    value::Dates.Time=Dates.Time(0),
    minimum::Dates.Time=Dates.Time(0),
    maximum::Dates.Time=Dates.Time(23, 59, 59),
    step_seconds::Integer=60,
    width::Integer=16,
    height::Integer=1,
    block::Union{Nothing,Block}=nothing,
    bindings::DataEntryBindings=default_data_entry_bindings(),
)
    width >= 0 || throw(ArgumentError("time input width must be non-negative"))
    height >= 0 || throw(ArgumentError("time input height must be non-negative"))
    step_seconds >= 1 || throw(ArgumentError("step_seconds must be at least 1"))
    return TimeInput(
        value,
        minimum,
        maximum,
        Int(step_seconds),
        Int(width),
        Int(height),
        block,
        bindings,
    )
end

state_for(widget::TimeInput) = TimePickerState(
    value=widget.value,
    minimum=widget.minimum,
    maximum=widget.maximum,
    step_seconds=widget.step_seconds,
)

measure(widget::TimeInput, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::TimeInput, area::Rect, state::TimeInputState)
    active = _data_input_active_area(buffer, widget, area)
    isempty(active) && return buffer
    clipped = Rect(active.row, active.column, min(active.height, widget.height), min(active.width, widget.width))
    isempty(clipped) && return buffer
    lines = render_time_picker(state; width=min(clipped.width, widget.width))
    rendered = rich_lines_to_core_text(CoreTextAdapter(), [lines])
    render!(buffer, Paragraph(rendered), clipped)
    return buffer
end

render!(buffer::Buffer, widget::TimeInput, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::TimeInputState, widget::TimeInput, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_data_entry_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    )
    return result.consumed
end

handle!(::TimeInputState, ::TimeInput, ::PasteEvent) = false
function handle!(state::TimeInputState, widget::TimeInput, event::MouseEvent, area::Rect)
    event.action == MouseScroll && contains(area, event.position) || return false
    key = event.button == WheelUpButton ? :up : event.button == WheelDownButton ? :down : nothing
    key === nothing && return false
    return handle_data_entry_key!(state, widget.bindings, key).consumed
end

function SemanticToolkit.widget_semantic_descriptor(::TimeInput, state::TimeInputState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Time input",
        state=Accessibility.SemanticState(focusable=true, value=string(state.value)),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:minimum => state.minimum, :maximum => state.maximum, :step_seconds => state.step_seconds),
    )
end

_semantic_time_value(value) = value isa Dates.Time ? value : Dates.Time(string(value))

function register_time_picker_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::TimePickerState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.value)
        elseif request.action == Accessibility.IncrementSemanticAction
            increment_time_picker!(state, 1)
            return Accessibility.SemanticActionResult(true; value=state.value)
        elseif request.action == Accessibility.DecrementSemanticAction
            increment_time_picker!(state, -1)
            return Accessibility.SemanticActionResult(true; value=state.value)
        elseif request.action == Accessibility.SetValueSemanticAction
            try
                set_time_picker!(state, _semantic_time_value(request.value))
                return Accessibility.SemanticActionResult(true; value=state.value)
            catch
                return Accessibility.SemanticActionResult(false; message="time value must be a Time or ISO time string")
            end
        end
        return Accessibility.SemanticActionResult(false; message="time picker semantic action is not supported")
    end)
    return dispatcher
end

register_time_input_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::TimeInputState,
) = register_time_picker_semantic_handlers!(dispatcher, id, state)

"""
Clock-style time picker widget backed by `TimePickerState`.

`TimePicker` is the picker-named surface for applications that want a direct time
control. It delegates rendering, input, and state ownership to the same
implementation as `TimeInput`.
"""
struct TimePicker
    input::TimeInput
end

function TimePicker(;
    value::Dates.Time=Dates.Time(0),
    minimum::Dates.Time=Dates.Time(0),
    maximum::Dates.Time=Dates.Time(23, 59, 59),
    step_seconds::Integer=60,
    width::Integer=16,
    height::Integer=1,
    block::Union{Nothing,Block}=nothing,
    bindings::DataEntryBindings=default_data_entry_bindings(),
)
    return TimePicker(TimeInput(; value, minimum, maximum, step_seconds, width, height, block, bindings))
end

state_for(widget::TimePicker) = state_for(widget.input)
measure(widget::TimePicker, available::Rect) = measure(widget.input, available)
render!(buffer::Buffer, widget::TimePicker, area::Rect) = render!(buffer, widget.input, area)
render!(buffer::Buffer, widget::TimePicker, area::Rect, state::TimePickerState) =
    render!(buffer, widget.input, area, state)
handle!(state::TimePickerState, widget::TimePicker, event::KeyEvent) =
    handle!(state, widget.input, event)
handle!(state::TimePickerState, widget::TimePicker, event::PasteEvent) =
    handle!(state, widget.input, event)
handle!(state::TimePickerState, widget::TimePicker, event::MouseEvent, area::Rect) =
    handle!(state, widget.input, event, area)

function SemanticToolkit.widget_semantic_descriptor(::TimePicker, state::TimePickerState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Time picker",
        state=Accessibility.SemanticState(focusable=true, value=string(state.value)),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:minimum => state.minimum, :maximum => state.maximum, :step_seconds => state.step_seconds),
    )
end

"""
Compatibility datetime input widget.

`DateTimeInput` combines `DatePickerState` and `TimePickerState` for projects that
expect a direct datetime-entry control in immediate mode.
"""
mutable struct DateTimeInputState
    date::DatePickerState
    time::TimePickerState
    active::Bool
end

struct DateTimeInput
    selected::Dates.DateTime
    minimum::Union{Nothing,Dates.DateTime}
    maximum::Union{Nothing,Dates.DateTime}
    week_start::Int
    width::Int
    height::Int
    block::Union{Nothing,Block}
    date_bindings::DataEntryBindings
    time_bindings::DataEntryBindings
    step_seconds::Int
end

function DateTimeInput(
    selected::Dates.DateTime=Dates.now();
    minimum::Union{Nothing,Dates.DateTime}=nothing,
    maximum::Union{Nothing,Dates.DateTime}=nothing,
    week_start::Integer=1,
    width::Integer=28,
    height::Integer=8,
    block::Union{Nothing,Block}=nothing,
    date_bindings::DataEntryBindings=default_data_entry_bindings(),
    time_bindings::DataEntryBindings=default_data_entry_bindings(),
    step_seconds::Integer=60,
)
    width >= 0 || throw(ArgumentError("date-time input width must be non-negative"))
    height >= 0 || throw(ArgumentError("date-time input height must be non-negative"))
    1 <= week_start <= 7 || throw(ArgumentError("week start must be between 1 and 7"))
    step_seconds > 0 || throw(ArgumentError("step_seconds must be positive"))
    return DateTimeInput(
        selected,
        minimum,
        maximum,
        Int(week_start),
        Int(width),
        Int(height),
        block,
        date_bindings,
        time_bindings,
        Int(step_seconds),
    )
end

"""
Create a date-time state compatible with `DateTimeInput`.

The time bounds are automatically narrowed when the selected date matches
`minimum` or `maximum` to keep datetime values representable.
"""
function DateTimeInputState(
    selected::Dates.DateTime=Dates.now();
    minimum::Union{Nothing,Dates.DateTime}=nothing,
    maximum::Union{Nothing,Dates.DateTime}=nothing,
    week_start::Integer=1,
    step_seconds::Integer=60,
)
    minimum === nothing || maximum === nothing || minimum <= maximum ||
        throw(ArgumentError("date-time minimum must not exceed maximum"))
    1 <= week_start <= 7 || throw(ArgumentError("week start must be between 1 and 7"))
    clamped = selected
    minimum === nothing || (clamped = max(clamped, minimum))
    maximum === nothing || (clamped = min(clamped, maximum))
    date = DatePickerState(
        selected=Dates.Date(clamped),
        minimum=minimum === nothing ? nothing : Dates.Date(minimum),
        maximum=maximum === nothing ? nothing : Dates.Date(maximum),
        week_start=week_start,
    )
    minimum_time = _datetime_input_minimum_time(minimum, date)
    maximum_time = _datetime_input_maximum_time(maximum, date)
    time = TimePickerState(
        value=Dates.Time(clamped),
        minimum=minimum_time,
        maximum=maximum_time,
        step_seconds=step_seconds,
    )
    return DateTimeInputState(date, time, true)
end

function _datetime_input_minimum_time(
    minimum::Union{Nothing,Dates.DateTime},
    date_state::DatePickerState,
)
    minimum === nothing && return Dates.Time(0)
    Dates.Date(minimum) == date_state.selected ? Dates.Time(minimum) : Dates.Time(0)
end

function _datetime_input_maximum_time(
    maximum::Union{Nothing,Dates.DateTime},
    date_state::DatePickerState,
)
    maximum === nothing && return Dates.Time(23, 59, 59)
    Dates.Date(maximum) == date_state.selected ? Dates.Time(maximum) : Dates.Time(23, 59, 59)
end

function _datetime_input_sync_time_bounds!(
    state::DateTimeInputState,
    minimum::Union{Nothing,Dates.DateTime},
    maximum::Union{Nothing,Dates.DateTime},
)
    minimum_time = _datetime_input_minimum_time(minimum, state.date)
    maximum_time = _datetime_input_maximum_time(maximum, state.date)
    state.time.minimum = minimum_time
    state.time.maximum = maximum_time
    set_time_picker!(state.time, state.time.value)
    return state
end

state_for(widget::DateTimeInput) = DateTimeInputState(
    Dates.DateTime(widget.selected);
    minimum=widget.minimum,
    maximum=widget.maximum,
    week_start=widget.week_start,
    step_seconds=widget.step_seconds,
)

measure(widget::DateTimeInput, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function _render_datetime_lines(state::DateTimeInputState, width::Int)
    width = max(1, width)
    lines = render_date_picker(state.date; width=width)
    push!(lines, render_time_picker(state.time; width=width))
    return lines
end

function render!(buffer::Buffer, widget::DateTimeInput, area::Rect, state::DateTimeInputState)
    active = _data_input_active_area(buffer, widget, area)
    isempty(active) && return buffer
    clipped = Rect(active.row, active.column, min(active.height, widget.height), min(active.width, widget.width))
    isempty(clipped) && return buffer
    rendered = rich_lines_to_core_text(
        CoreTextAdapter(),
        _render_datetime_lines(state, clipped.width),
    )
    render!(buffer, Paragraph(rendered), clipped)
    return buffer
end

render!(buffer::Buffer, widget::DateTimeInput, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::DateTimeInputState, widget::DateTimeInput, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code in (:tab, :backtab)
        state.active = !state.active
        return true
    end
    if state.active
        result = handle_data_entry_key!(
            state.date,
            widget.date_bindings,
            event.key.code;
            control=in(CTRL, event.modifiers),
            alt=in(ALT, event.modifiers),
            shift=in(SHIFT, event.modifiers),
        )
        result.consumed || return false
        _datetime_input_sync_time_bounds!(state, widget.minimum, widget.maximum)
        return true
    end
    result = handle_data_entry_key!(
        state.time,
        widget.time_bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    )
    return result.consumed
end

handle!(::DateTimeInputState, ::DateTimeInput, ::PasteEvent) = false
function handle!(state::DateTimeInputState, widget::DateTimeInput, event::MouseEvent, area::Rect)
    event.action == MouseScroll && contains(area, event.position) || return false
    key = event.button == WheelUpButton ? :up : event.button == WheelDownButton ? :down : nothing
    key === nothing && return false
    bindings = state.active ? widget.date_bindings : widget.time_bindings
    target = state.active ? state.date : state.time
    consumed = handle_data_entry_key!(target, bindings, key).consumed
    consumed && state.active && _datetime_input_sync_time_bounds!(state, widget.minimum, widget.maximum)
    return consumed
end

function SemanticToolkit.widget_semantic_descriptor(::DateTimeInput, state::DateTimeInputState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Date and time input",
        state=Accessibility.SemanticState(focusable=true, value="$(state.date.selected) $(state.time.value)"),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:active_field => state.active ? :date : :time),
    )
end

function _semantic_datetime_value(value)
    value isa Dates.DateTime && return value
    value isa Dates.Date && return Dates.DateTime(value)
    return Dates.DateTime(string(value))
end

function _set_datetime_value!(
    state::DateTimeInputState,
    widget::DateTimeInput,
    value::Dates.DateTime,
)
    select_date!(state.date, Dates.Date(value))
    _datetime_input_sync_time_bounds!(state, widget.minimum, widget.maximum)
    set_time_picker!(state.time, Dates.Time(value))
    return state
end

function register_date_time_input_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DateTimeInput,
    state::DateTimeInputState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=(state.date.selected, state.time.value))
        elseif request.action == Accessibility.IncrementSemanticAction
            if state.active
                move_date_picker!(state.date, 1)
                _datetime_input_sync_time_bounds!(state, widget.minimum, widget.maximum)
            else
                increment_time_picker!(state.time, 1)
            end
            return Accessibility.SemanticActionResult(true; value=(state.date.selected, state.time.value))
        elseif request.action == Accessibility.DecrementSemanticAction
            if state.active
                move_date_picker!(state.date, -1)
                _datetime_input_sync_time_bounds!(state, widget.minimum, widget.maximum)
            else
                increment_time_picker!(state.time, -1)
            end
            return Accessibility.SemanticActionResult(true; value=(state.date.selected, state.time.value))
        elseif request.action == Accessibility.SetValueSemanticAction
            try
                _set_datetime_value!(state, widget, _semantic_datetime_value(request.value))
                return Accessibility.SemanticActionResult(true; value=(state.date.selected, state.time.value))
            catch
                return Accessibility.SemanticActionResult(false; message="datetime value must be a DateTime or ISO datetime string")
            end
        end
        return Accessibility.SemanticActionResult(false; message="date-time semantic action is not supported")
    end)
    return dispatcher
end

"""
Picker-named date-time control backed by `DateTimeInputState`.

`DateTimePicker` is the stable picker surface for applications that want one
combined date and time control. It delegates rendering, input, bounds handling,
and state ownership to the same implementation as `DateTimeInput`.
"""
struct DateTimePicker
    input::DateTimeInput
end

function DateTimePicker(
    selected::Dates.DateTime=Dates.now();
    minimum::Union{Nothing,Dates.DateTime}=nothing,
    maximum::Union{Nothing,Dates.DateTime}=nothing,
    week_start::Integer=1,
    width::Integer=28,
    height::Integer=8,
    block::Union{Nothing,Block}=nothing,
    date_bindings::DataEntryBindings=default_data_entry_bindings(),
    time_bindings::DataEntryBindings=default_data_entry_bindings(),
    step_seconds::Integer=60,
)
    return DateTimePicker(DateTimeInput(
        selected;
        minimum,
        maximum,
        week_start,
        width,
        height,
        block,
        date_bindings,
        time_bindings,
        step_seconds,
    ))
end

state_for(widget::DateTimePicker) = state_for(widget.input)
measure(widget::DateTimePicker, available::Rect) = measure(widget.input, available)
render!(buffer::Buffer, widget::DateTimePicker, area::Rect) =
    render!(buffer, widget.input, area)
render!(buffer::Buffer, widget::DateTimePicker, area::Rect, state::DateTimeInputState) =
    render!(buffer, widget.input, area, state)
handle!(state::DateTimeInputState, widget::DateTimePicker, event::KeyEvent) =
    handle!(state, widget.input, event)
handle!(state::DateTimeInputState, widget::DateTimePicker, event::PasteEvent) =
    handle!(state, widget.input, event)
handle!(state::DateTimeInputState, widget::DateTimePicker, event::MouseEvent, area::Rect) =
    handle!(state, widget.input, event, area)

function SemanticToolkit.widget_semantic_descriptor(::DateTimePicker, state::DateTimeInputState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Date-time picker",
        state=Accessibility.SemanticState(focusable=true, value="$(state.date.selected) $(state.time.value)"),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:active_field => state.active ? :date : :time),
    )
end

register_date_time_picker_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DateTimePicker,
    state::DateTimeInputState,
) = register_date_time_input_semantic_handlers!(dispatcher, id, widget.input, state)

"""A dialog surface rendered with explicit external `DialogState`."""
struct Dialog
    body::Text
    block::Block
    button_style::Style
    focused_button_style::Style
end

function Dialog(
    body;
    title::AbstractString="Dialog",
    border_style::Style=Style(),
    title_style::Style=Style(modifiers=BOLD),
    button_style::Style=Style(),
    focused_button_style::Style=Style(modifiers=REVERSED | BOLD),
)
    content = body isa Text ? body : Text(string(body))
    block = Block(
        title=title,
        border_style=border_style,
        title_style=title_style,
        padding=Margin(0, 1),
    )
    return Dialog(content, block, button_style, focused_button_style)
end

state_for(::Dialog) = DialogState(DialogButton{Nothing}[]; open=false)

function _dialog_button_regions(state::DialogState, area::Rect)
    isempty(area) && return Tuple{Int,Rect,String}[]
    widths = Int[text_width(" " * button.label * " ") for button in state.buttons]
    total = sum(widths; init=0) + max(0, length(widths) - 1)
    column = area.column + max(0, (area.width - total) ÷ 2)
    regions = Tuple{Int,Rect,String}[]
    for (index, button) in enumerate(state.buttons)
        width = min(widths[index], max(0, area.column + area.width - column))
        width > 0 && push!(regions, (index, Rect(area.row, column, 1, width), button.label))
        column += widths[index] + 1
        column >= area.column + area.width && break
    end
    return regions
end

function _render_dialog!(
    buffer::Buffer,
    widget::Dialog,
    area::Rect,
    state::Union{Nothing,DialogState},
)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    render!(buffer, Clear(), active)
    render!(buffer, widget.block, active)
    content = intersection(buffer.area, inner(widget.block, active))
    isempty(content) && return buffer

    button_height = state === nothing || isempty(state.buttons) ? 0 : 1
    body_height = max(0, content.height - button_height)
    body_height > 0 && render!(
        buffer,
        Paragraph(widget.body),
        Rect(content.row, content.column, body_height, content.width),
    )
    button_height == 0 && return buffer

    button_area = Rect(content.row + content.height - 1, content.column, 1, content.width)
    for (index, region, label) in _dialog_button_regions(state, button_area)
        button = state.buttons[index]
        style = button.disabled ? apply(widget.button_style, StylePatch(add_modifiers=DIM)) :
                state.focused == index ? widget.focused_button_style : widget.button_style
        render!(buffer, Label(" " * label * " "; style), region)
    end
    return buffer
end

render!(buffer::Buffer, widget::Dialog, area::Rect) =
    _render_dialog!(buffer, widget, area, nothing)

function render!(buffer::Buffer, widget::Dialog, area::Rect, state::DialogState)
    state.open || return buffer
    return _render_dialog!(buffer, widget, area, state)
end

"""Handle keyboard navigation, confirmation, and dismissal for an open dialog."""
function handle!(state::DialogState, ::Dialog, event::KeyEvent)
    state.open && event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code in (:left, :backtab)
        move_dialog_focus!(state, -1)
    elseif event.key.code in (:right, :tab)
        move_dialog_focus!(state, 1)
    elseif event.key.code == :enter
        activate_dialog_button!(state)
    elseif event.key.code == :escape
        close_dialog!(state)
    else
        return false
    end
    return true
end

"""Activate a dialog button from a one-based terminal mouse release."""
function handle!(state::DialogState, widget::Dialog, event::MouseEvent, area::Rect)
    state.open || return false
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    content = intersection(area, inner(widget.block, area))
    isempty(content) && return false
    button_area = Rect(content.row + content.height - 1, content.column, 1, content.width)
    for (index, region, _) in _dialog_button_regions(state, button_area)
        contains(region, event.position) || continue
        state.buttons[index].disabled && return false
        state.focused = index
        activate_dialog_button!(state)
        return true
    end
    return false
end

function SemanticToolkit.widget_semantic_descriptor(::Dialog, state::DialogState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.DialogRole;
        label="Dialog",
        state=Accessibility.SemanticState(hidden=!state.open, focusable=state.open),
        actions=[Accessibility.FocusSemanticAction, Accessibility.DismissSemanticAction],
        metadata=Dict(:result => state.result),
    )
end

function SemanticToolkit.widget_semantic_children(::Dialog, state::DialogState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(index)",
            Accessibility.ButtonRole;
            label=button.label,
            state=Accessibility.SemanticState(enabled=!button.disabled, selected=state.focused == index),
            actions=button.disabled ? Accessibility.SemanticAction[] : [
                Accessibility.FocusSemanticAction,
                Accessibility.SelectSemanticAction,
                Accessibility.ActivateSemanticAction,
            ],
            metadata=Dict(:role => button.role, :value => button.value),
        ) for (index, button) in enumerate(state.buttons)
    ]
end

function register_dialog_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::DialogState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.focused)
        elseif request.action == Accessibility.DismissSemanticAction
            close_dialog!(state)
            return Accessibility.SemanticActionResult(true; value=state.open)
        end
        return Accessibility.SemanticActionResult(false; message="dialog semantic action is not supported")
    end)
    for (registered_index, button) in enumerate(state.buttons)
        value = button.value
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/$(registered_index)", function (request)
            index = findfirst(candidate -> candidate.value == value, state.buttons)
            index === nothing && return Accessibility.SemanticActionResult(false; message="dialog button is not available")
            state.buttons[index].disabled && return Accessibility.SemanticActionResult(false; message="dialog button is disabled")
            if request.action == Accessibility.FocusSemanticAction || request.action == Accessibility.SelectSemanticAction
                state.focused = index
                return Accessibility.SemanticActionResult(true; value)
            elseif request.action == Accessibility.ActivateSemanticAction
                state.focused = index
                return Accessibility.SemanticActionResult(true; value=activate_dialog_button!(state))
            end
            return Accessibility.SemanticActionResult(false; message="dialog button semantic action is not supported")
        end)
    end
    return dispatcher
end

"""A clipped, non-throwing presentation of an application or runtime error."""
struct ErrorView
    title::String
    message::String
    details::Vector{String}
    block::Block
    message_style::Style
    detail_style::Style
end

"""Compatibility alias for a modal naming convention used by upstream frameworks."""
struct Modal
    dialog::Dialog
    Modal(dialog::Dialog) = new(dialog)
end

function Modal(body::Vararg{Any}; kwargs...)
    length(body) == 0 && throw(ArgumentError("Modal requires a body argument"))
    length(body) > 1 && throw(ArgumentError("Modal accepts exactly one positional argument"))
    return _modal(body[1]; kwargs...)
end

_modal(dialog::Dialog) = Modal(dialog)

_modal(body; kwargs...) = _modal(Dialog(body; kwargs...))

state_for(widget::Modal) = state_for(widget.dialog)

render!(buffer::Buffer, widget::Modal, area::Rect) =
    render!(buffer, widget.dialog, area)

render!(buffer::Buffer, widget::Modal, area::Rect, state::DialogState) =
    render!(buffer, widget.dialog, area, state)

handle!(state::DialogState, widget::Modal, event::KeyEvent) =
    handle!(state, widget.dialog, event)

handle!(state::DialogState, widget::Modal, event::MouseEvent, area::Rect) =
    handle!(state, widget.dialog, event, area)

function SemanticToolkit.widget_semantic_descriptor(::Modal, state::DialogState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.DialogRole;
        label="Modal",
        state=Accessibility.SemanticState(hidden=!state.open, focusable=state.open),
        actions=[Accessibility.FocusSemanticAction, Accessibility.DismissSemanticAction],
        metadata=Dict(:result => state.result),
    )
end

SemanticToolkit.widget_semantic_children(widget::Modal, state::DialogState, id) =
    SemanticToolkit.widget_semantic_children(widget.dialog, state, id)

register_modal_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Modal,
    state::DialogState,
) =
    register_dialog_semantic_handlers!(dispatcher, id, state)

"""Compatibility alias for a top-level dialog/window naming convention."""
struct Window
    dialog::Dialog
    Window(dialog::Dialog) = new(dialog)
end

"""Compatibility state alias for `Window`; identical to `DialogState`."""
const WindowState = DialogState

function Window(body::Vararg{Any}; kwargs...)
    length(body) == 0 && throw(ArgumentError("Window requires a body argument"))
    length(body) > 1 && throw(ArgumentError("Window accepts exactly one positional argument"))
    return _window(body[1]; kwargs...)
end

_window(dialog::Dialog) = Window(dialog)

_window(body; kwargs...) = _window(Dialog(body; kwargs...))

state_for(widget::Window) = state_for(widget.dialog)

render!(buffer::Buffer, widget::Window, area::Rect) =
    render!(buffer, widget.dialog, area)

render!(buffer::Buffer, widget::Window, area::Rect, state::WindowState) =
    render!(buffer, widget.dialog, area, state)

handle!(state::WindowState, widget::Window, event::KeyEvent) =
    handle!(state, widget.dialog, event)

handle!(state::WindowState, widget::Window, event::MouseEvent, area::Rect) =
    handle!(state, widget.dialog, event, area)

function SemanticToolkit.widget_semantic_descriptor(::Window, state::WindowState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.DialogRole;
        label="Window",
        state=Accessibility.SemanticState(hidden=!state.open, focusable=state.open),
        actions=[Accessibility.FocusSemanticAction, Accessibility.DismissSemanticAction],
        metadata=Dict(:result => state.result),
    )
end

SemanticToolkit.widget_semantic_children(widget::Window, state::WindowState, id) =
    SemanticToolkit.widget_semantic_children(widget.dialog, state, id)

register_window_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Window,
    state::WindowState,
) =
    register_dialog_semantic_handlers!(dispatcher, id, state)

function ErrorView(
    error;
    title::AbstractString="Application error",
    details=String[],
    border_style::Style=Style(foreground=AnsiColor(1)),
    message_style::Style=Style(foreground=AnsiColor(1), modifiers=BOLD),
    detail_style::Style=Style(modifiers=DIM),
)
    message = error isa Exception ? sprint(showerror, error) : string(error)
    block = Block(
        title=title,
        border_style=border_style,
        title_style=message_style,
        padding=Margin(0, 1),
    )
    return ErrorView(
        String(title),
        message,
        String[string(detail) for detail in details],
        block,
        message_style,
        detail_style,
    )
end

function render!(buffer::Buffer, widget::ErrorView, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    render!(buffer, widget.block, active)
    content = intersection(buffer.area, inner(widget.block, active))
    isempty(content) && return buffer
    lines = Line[Line(widget.message; style=widget.message_style)]
    append!(lines, (Line(detail; style=widget.detail_style) for detail in widget.details))
    render!(buffer, Paragraph(Text(lines)), content)
    return buffer
end

function SemanticToolkit.widget_semantic_descriptor(widget::ErrorView, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.AlertRole;
        label=widget.title,
        description=widget.message,
        state=Accessibility.SemanticState(enabled=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(
            :detail_count => length(widget.details),
            :details => copy(widget.details),
        ),
    )
end

_error_view_semantic_value(widget::ErrorView) = Dict{Symbol,Any}(
    :title => widget.title,
    :message => widget.message,
    :details => copy(widget.details),
)

register_error_view_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::ErrorView) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        _error_view_semantic_value(widget),
        "error view semantic action is not supported",
    )

_validation_role(issues) = any(issue -> issue.severity == :error, issues) ?
    Accessibility.AlertRole : Accessibility.StatusRole

function SemanticToolkit.widget_semantic_descriptor(widget::ValidationMessage, state)
    issues = widget.issues
    return SemanticToolkit.SemanticDescriptor(
        _validation_role(issues);
        label=length(issues) == 1 ? "Validation issue" : "Validation issues",
        description=join((issue.message for issue in issues), "\n"),
        state=Accessibility.SemanticState(enabled=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.DismissSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :issue_count => length(issues),
            :codes => Symbol[issue.code for issue in issues],
            :severities => Symbol[issue.severity for issue in issues],
        ),
    )
end

function _validation_message_semantic_value(widget::ValidationMessage)
    return Dict{Symbol,Any}(
        :issue_count => length(widget.issues),
        :codes => Symbol[issue.code for issue in widget.issues],
        :severities => Symbol[issue.severity for issue in widget.issues],
        :messages => String[issue.message for issue in widget.issues],
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::ValidationSummary, state)
    issues = form_issues(widget.form, widget.state)
    return SemanticToolkit.SemanticDescriptor(
        _validation_role(last(issue) for issue in issues);
        label="Form validation",
        description=join((
            "$(only(field.label for field in widget.form.fields if field.id == id)): $(issue.message)"
            for (id, issue) in issues
        ),
            "\n",
        ),
        state=Accessibility.SemanticState(enabled=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.DismissSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :issue_count => length(issues),
            :field_ids => Any[id for (id, _) in issues],
            :codes => Symbol[issue.code for (_, issue) in issues],
        ),
    )
end

function _validation_summary_semantic_value(widget::ValidationSummary)
    issues = form_issues(widget.form, widget.state)
    return Dict{Symbol,Any}(
        :issue_count => length(issues),
        :field_ids => Any[id for (id, _) in issues],
        :codes => Symbol[issue.code for (_, issue) in issues],
        :messages => String[issue.message for (_, issue) in issues],
    )
end

register_validation_message_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ValidationMessage,
) = _register_feedback_semantic_handlers!(
    dispatcher,
    id,
    _validation_message_semantic_value(widget),
    "validation message semantic action is not supported",
)

register_validation_summary_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ValidationSummary,
) = _register_feedback_semantic_handlers!(
    dispatcher,
    id,
    _validation_summary_semantic_value(widget),
    "validation summary semantic action is not supported",
)

function SemanticToolkit.widget_semantic_descriptor(widget::ManagedNotificationView, state)
    snapshots = notification_snapshots(widget.manager)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.LogRole;
        label="Notifications",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :notification_count => length(snapshots),
            :generation => notification_generation(widget.manager),
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::ManagedNotificationView, state, id)
    tree = notification_semantic_tree(notification_snapshots(widget.manager); id=id)
    return tree.root.children
end

_notification_role(notification::Notification) = notification.severity == :error ?
    Accessibility.AlertRole : Accessibility.StatusRole

function SemanticToolkit.widget_semantic_descriptor(widget::NotificationView, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.LogRole;
        label="Notifications",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :notification_count => length(widget.center.notifications),
            :maximum => widget.center.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::NotificationView, state, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/notification/$(notification.id)",
            _notification_role(notification);
            label=isempty(notification.title) ? "Notification" : notification.title,
            description=notification.message,
            state=Accessibility.SemanticState(readonly=true),
            actions=Accessibility.SemanticAction[Accessibility.DismissSemanticAction],
            metadata=Dict{Symbol,Any}(
                :notification_id => notification.id,
                :severity => notification.severity,
                :timeout_ns => notification.timeout_ns,
            ),
        ) for notification in widget.center.notifications
    ]
end

function SemanticToolkit.widget_semantic_descriptor(widget::CommandPalette, state::CommandPaletteState)
    filtered = Widgets.command_palette_filtered_commands(widget, state)
    selected = Widgets.command_palette_selected_command(widget, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.DialogRole;
        label="Command palette",
        state=Accessibility.SemanticState(
            hidden=!state.open,
            focusable=state.open,
            focused=state.open && state.query.focused,
        ),
        actions=state.open ? Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.DismissSemanticAction,
        ] : Accessibility.SemanticAction[Accessibility.FocusSemanticAction],
        metadata=Dict{Symbol,Any}(
            :open => state.open,
            :query => Widgets.command_palette_query(state),
            :result_count => length(filtered),
            :selected_command_id => isnothing(selected) ? nothing : selected.id,
            :selected_action => isnothing(selected) ? nothing : selected.action,
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::CommandPalette, state::CommandPaletteState, id)
    state.open || return Accessibility.SemanticNode[]
    Widgets._filter_commands!(widget, state)
    children = Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/search",
            Accessibility.SearchboxRole;
            label="Command search",
            state=Accessibility.SemanticState(
                focusable=true,
                focused=false,
                value=editing_text(state.query.editing),
            ),
            actions=Accessibility.SemanticAction[
                Accessibility.FocusSemanticAction,
                Accessibility.SetValueSemanticAction,
            ],
        ),
    ]
    for (visible_index, command_index) in enumerate(state.filtered)
        command = widget.commands[command_index]
        push!(
            children,
            Accessibility.SemanticNode(
                "$(id)/command/$(command.id)",
                Accessibility.ListItemRole;
                label=command.title,
                description=command.description,
                state=Accessibility.SemanticState(
                    enabled=!command.disabled,
                    focusable=!command.disabled,
                    selected=state.selected == visible_index,
                ),
                actions=command.disabled ? Accessibility.SemanticAction[] : Accessibility.SemanticAction[
                    Accessibility.ActivateSemanticAction,
                    Accessibility.FocusSemanticAction,
                ],
                metadata=Dict{Symbol,Any}(
                    :command_id => command.id,
                    :action => command.action,
                    :keywords => copy(command.keywords),
                ),
            ),
        )
    end
    return children
end

function register_command_palette_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::CommandPalette,
    state::CommandPaletteState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            open_palette!(state)
            return Accessibility.SemanticActionResult(true; value=state)
        elseif request.action == Accessibility.DismissSemanticAction
            close_palette!(state)
            return Accessibility.SemanticActionResult(true; value=state)
        end
        return Accessibility.SemanticActionResult(false; message="command palette semantic action is not supported")
    end)
    Widgets.command_palette_filtered_commands(widget, state)
    for (visible_index, command_index) in enumerate(state.filtered)
        command = widget.commands[command_index]
        command.disabled && continue
        command_id = "$(node_id)/command/$(command.id)"
        command_key = command.id
        Accessibility.register_semantic_handler!(dispatcher, command_id, function (request)
            Widgets.command_palette_filtered_commands(widget, state)
            target_index = findfirst(index -> widget.commands[index].id == command_key, state.filtered)
            if isnothing(target_index)
                return Accessibility.SemanticActionResult(false; message="command palette command is not visible")
            end
            target_command = widget.commands[state.filtered[target_index]]
            if request.action == Accessibility.FocusSemanticAction
                Widgets.select_command!(state, widget, target_index)
                return Accessibility.SemanticActionResult(true; value=target_command.id)
            elseif request.action == Accessibility.ActivateSemanticAction
                Widgets.select_command!(state, widget, target_index)
                return Accessibility.SemanticActionResult(true; value=target_command.action)
            end
            return Accessibility.SemanticActionResult(false; message="command palette command semantic action is not supported")
        end)
    end
    return dispatcher
end

function SemanticToolkit.widget_semantic_descriptor(widget::LogView, state::LogState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.LogRole;
        label="Log",
        state=Accessibility.SemanticState(focusable=true, readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :entry_count => length(state.entries),
            :offset => state.offset,
            :maximum_entries => state.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::RichLog, state::RichLogState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.LogRole;
        label="Rich log",
        state=Accessibility.SemanticState(focusable=true, readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :entry_count => length(state.entries),
            :offset => state.offset,
            :maximum_entries => state.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Scrollbar, state::ScrollState)
    vertical = widget.direction == VerticalScrollbar
    maximum = max(0, widget.content_length - widget.viewport_length)
    offset = vertical ? state.row : state.column
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ScrollbarRole;
        label=vertical ? "Vertical scrollbar" : "Horizontal scrollbar",
        state=Accessibility.SemanticState(
            focusable=true,
            value_now=offset,
            value_min=0,
            value_max=maximum,
        ),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :orientation => vertical ? :vertical : :horizontal,
            :content_length => widget.content_length,
            :viewport_length => widget.viewport_length,
        ),
    )
end

function _scrollbar_semantic_value(widget::Scrollbar, state::ScrollState)
    vertical = widget.direction == VerticalScrollbar
    maximum = max(0, widget.content_length - widget.viewport_length)
    offset = vertical ? state.row : state.column
    return Dict{Symbol,Any}(
        :orientation => vertical ? :vertical : :horizontal,
        :offset => offset,
        :maximum => maximum,
        :content_length => widget.content_length,
        :viewport_length => widget.viewport_length,
    )
end

function _set_scrollbar_offset!(widget::Scrollbar, state::ScrollState, value)
    vertical = widget.direction == VerticalScrollbar
    maximum = max(0, widget.content_length - widget.viewport_length)
    offset = tryparse(Int, string(value))
    offset === nothing && return false
    offset = clamp(offset, 0, maximum)
    vertical ? (state.row = offset) : (state.column = offset)
    return true
end

function _increment_scrollbar!(widget::Scrollbar, state::ScrollState, delta::Integer)
    vertical = widget.direction == VerticalScrollbar
    maximum = max(0, widget.content_length - widget.viewport_length)
    current = vertical ? state.row : state.column
    offset = clamp(current + Int(delta), 0, maximum)
    vertical ? (state.row = offset) : (state.column = offset)
    return true
end

function register_scrollbar_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Scrollbar,
    state::ScrollState,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=_scrollbar_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            _increment_scrollbar!(widget, state, 1)
            return Accessibility.SemanticActionResult(true; value=_scrollbar_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            _increment_scrollbar!(widget, state, -1)
            return Accessibility.SemanticActionResult(true; value=_scrollbar_semantic_value(widget, state))
        elseif request.action == Accessibility.ScrollIntoViewSemanticAction
            handled = _set_scrollbar_offset!(widget, state, request.value)
            return Accessibility.SemanticActionResult(
                handled;
                value=_scrollbar_semantic_value(widget, state),
                message=handled ? nothing : "scrollbar semantic value must be an integer offset",
            )
        end
        return Accessibility.SemanticActionResult(false; message="scrollbar semantic action is not supported")
    end)
    return dispatcher
end

register_scroll_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ScrollView,
    state::ScrollState;
    viewport_height::Integer=0,
    viewport_width::Integer=0,
) =
    register_scrollbar_semantic_handlers!(
        dispatcher,
        id,
        Scrollbar(
            VerticalScrollbar,
            widget.content_size.height,
            viewport_height <= 0 ? 1 : Int(viewport_height),
        ),
        state,
    )

register_viewport_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Viewport,
    state::ViewportState;
    viewport_height::Integer=0,
    viewport_width::Integer=0,
) =
    register_scroll_view_semantic_handlers!(
        dispatcher,
        id,
        _scroll_view(widget),
        state;
        viewport_height=viewport_height <= 0 ? widget.content_size.height : viewport_height,
        viewport_width=viewport_width <= 0 ? widget.content_size.width : viewport_width,
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Gauge, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ProgressRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            readonly=true,
            value=widget.label,
            value_now=widget.ratio,
            value_min=0,
            value_max=1,
        ),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::LineGauge, state)
    value = string(round(Int, widget.ratio * 100), "%")
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ProgressRole;
        label="Progress",
        state=Accessibility.SemanticState(
            readonly=true,
            value=value,
            value_now=widget.ratio,
            value_min=0,
            value_max=1,
        ),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
    )
end

_visual_semantic_value(widget::Gauge) = Dict{Symbol,Any}(:ratio => widget.ratio, :label => widget.label)
_visual_semantic_value(widget::LineGauge) = Dict{Symbol,Any}(:ratio => widget.ratio)
_visual_semantic_value(widget::Sparkline) = Dict{Symbol,Any}(:values => copy(widget.values), :minimum => widget.minimum, :maximum => widget.maximum)
_visual_semantic_value(widget::BarChart) = Dict{Symbol,Any}(:bars => [(bar.label, bar.value) for bar in widget.bars], :maximum => widget.maximum)
_visual_semantic_value(widget::Canvas) = Dict{Symbol,Any}(:x_bounds => widget.x_bounds, :y_bounds => widget.y_bounds)
_visual_semantic_value(widget::Chart) = Dict{Symbol,Any}(:dataset_count => length(widget.datasets), :x_bounds => widget.x_bounds, :y_bounds => widget.y_bounds)
_visual_semantic_value(widget::Histogram) = Dict{Symbol,Any}(:values => copy(widget.values), :bins => widget.bins)
_visual_semantic_value(widget::Heatmap) = Dict{Symbol,Any}(:rows => size(widget.values, 1), :columns => size(widget.values, 2), :minimum => widget.minimum, :maximum => widget.maximum)

function _register_readonly_visual_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget,
    unsupported::AbstractString,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction)
            return Accessibility.SemanticActionResult(true; value=_visual_semantic_value(widget))
        end
        return Accessibility.SemanticActionResult(false; message=unsupported)
    end)
    return dispatcher
end

register_gauge_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Gauge) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "gauge semantic action is not supported")

register_line_gauge_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::LineGauge) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "line gauge semantic action is not supported")

function SemanticToolkit.widget_semantic_descriptor(widget::Calendar, state::CalendarState)
    selected = state.selected
    visible = Date(state.visible_year, state.visible_month, 1)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TableRole;
        label="$(monthname(state.visible_month)) $(state.visible_year)",
        state=Accessibility.SemanticState(
            focusable=true,
            focused=state.focused,
            selected=true,
            value=string(selected),
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :selected => selected,
            :visible_month => visible,
            :marked_count => length(widget.marked),
            :activated => state.activated,
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::Calendar, state::CalendarState, id)
    first_date = Date(state.visible_year, state.visible_month, 1)
    day_count = daysinmonth(first_date)
    leading = dayofweek(first_date) - 1
    week_count = cld(leading + day_count, 7)
    children = Accessibility.SemanticNode[]
    for week in 1:week_count
        cells = Accessibility.SemanticNode[]
        for weekday_index in 1:7
            day_value = (week - 1) * 7 + weekday_index - leading
            1 <= day_value <= day_count || continue
            date = Date(state.visible_year, state.visible_month, day_value)
            push!(
                cells,
                Accessibility.SemanticNode(
                    "$(id)/week-$(week)/day-$(day_value)",
                    Accessibility.CellRole;
                    label=string(day_value),
                    description=Dates.format(date, dateformat"yyyy-mm-dd"),
                    state=Accessibility.SemanticState(
                        focusable=true,
                        focused=state.focused && date == state.selected,
                        selected=date == state.selected,
                    ),
                    actions=Accessibility.SemanticAction[
                        Accessibility.SelectSemanticAction,
                        Accessibility.ActivateSemanticAction,
                    ],
                    metadata=Dict{Symbol,Any}(
                        :date => date,
                        :weekday => dayname(date),
                        :marked => date in widget.marked,
                        :activated => state.activated == date,
                    ),
                ),
            )
        end
        push!(
            children,
            Accessibility.SemanticNode(
                "$(id)/week-$(week)",
                Accessibility.RowRole;
                label="Week $(week)",
                children=cells,
            ),
        )
    end
    return children
end

function register_calendar_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Calendar,
    state::CalendarState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.IncrementSemanticAction
            Widgets._set_calendar_date!(state, state.selected + Day(1))
            return Accessibility.SemanticActionResult(true; value=state.selected)
        elseif request.action == Accessibility.DecrementSemanticAction
            Widgets._set_calendar_date!(state, state.selected - Day(1))
            return Accessibility.SemanticActionResult(true; value=state.selected)
        elseif request.action == Accessibility.FocusSemanticAction
            state.focused = true
            return Accessibility.SemanticActionResult(true; value=state.selected)
        elseif request.action == Accessibility.SelectSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.selected)
        elseif request.action == Accessibility.ActivateSemanticAction
            state.activated = state.selected
            return Accessibility.SemanticActionResult(true; value=state.activated)
        end
        return Accessibility.SemanticActionResult(false; message="calendar semantic action is not supported")
    end)

    first_date = Date(state.visible_year, state.visible_month, 1)
    day_count = daysinmonth(first_date)
    leading = dayofweek(first_date) - 1
    week_count = cld(leading + day_count, 7)
    for week in 1:week_count
        for weekday_index in 1:7
            day_value = (week - 1) * 7 + weekday_index - leading
            1 <= day_value <= day_count || continue
            date = Date(state.visible_year, state.visible_month, day_value)
            day_id = "$(node_id)/week-$(week)/day-$(day_value)"
            Accessibility.register_semantic_handler!(dispatcher, day_id, function (request)
                if request.action == Accessibility.SelectSemanticAction
                    Widgets._set_calendar_date!(state, date)
                    return Accessibility.SemanticActionResult(true; value=date)
                elseif request.action == Accessibility.ActivateSemanticAction
                    Widgets._set_calendar_date!(state, date)
                    state.activated = date
                    return Accessibility.SemanticActionResult(true; value=date)
                elseif request.action == Accessibility.FocusSemanticAction
                    Widgets._set_calendar_date!(state, date)
                    return Accessibility.SemanticActionResult(true; value=date)
                end
                return Accessibility.SemanticActionResult(false; message="calendar day semantic action is not supported")
            end)
        end
    end
    return dispatcher
end

function SemanticToolkit.widget_semantic_descriptor(widget::Spinner, state::SpinnerState)
    frame = mod1(state.frame, length(widget.frames))
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ProgressRole;
        label=isempty(widget.label) ? "Loading" : widget.label,
        state=Accessibility.SemanticState(readonly=true, busy=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.IncrementSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :frame => frame,
            :frame_count => length(widget.frames),
        ),
    )
end

_loading_semantic_value(widget::Spinner, state::SpinnerState) = Dict{Symbol,Any}(
    :frame => mod1(state.frame, length(widget.frames)),
    :frame_count => length(widget.frames),
    :label => widget.label,
)

function register_spinner_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Spinner,
    state::SpinnerState,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction)
            return Accessibility.SemanticActionResult(true; value=_loading_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            state.frame = mod1(state.frame + 1, length(widget.frames))
            return Accessibility.SemanticActionResult(true; value=_loading_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="spinner semantic action is not supported")
    end)
    return dispatcher
end

function SemanticToolkit.widget_semantic_descriptor(widget::LoadingIndicator, state::SpinnerState)
    frame = mod1(state.frame, length(widget.spinner.frames))
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ProgressRole;
        label=isempty(widget.spinner.label) ? "Loading" : widget.spinner.label,
        state=Accessibility.SemanticState(readonly=true, busy=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.IncrementSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :frame => frame,
            :frame_count => length(widget.spinner.frames),
            :indicator => :loading,
        ),
    )
end

_loading_semantic_value(widget::LoadingIndicator, state::SpinnerState) = merge(
    _loading_semantic_value(widget.spinner, state),
    Dict{Symbol,Any}(:indicator => :loading),
)

function register_loading_indicator_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::LoadingIndicator,
    state::SpinnerState,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction)
            return Accessibility.SemanticActionResult(true; value=_loading_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            state.frame = mod1(state.frame + 1, length(widget.spinner.frames))
            return Accessibility.SemanticActionResult(true; value=_loading_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="loading indicator semantic action is not supported")
    end)
    return dispatcher
end

function SemanticToolkit.widget_semantic_descriptor(widget::Sparkline, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Sparkline",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :sample_count => length(widget.values),
            :minimum => widget.minimum,
            :maximum => widget.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::BarChart, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Bar chart",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :bar_count => length(widget.bars),
            :maximum => widget.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Canvas, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Canvas",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(:x_bounds => widget.x_bounds, :y_bounds => widget.y_bounds),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Chart, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Chart",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :dataset_count => length(widget.datasets),
            :x_bounds => widget.x_bounds,
            :y_bounds => widget.y_bounds,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Histogram, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Histogram",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(:sample_count => length(widget.values), :bins => widget.bins),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Heatmap, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Heatmap",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :rows => size(widget.values, 1),
            :columns => size(widget.values, 2),
            :minimum => widget.minimum,
            :maximum => widget.maximum,
        ),
    )
end

register_sparkline_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Sparkline) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "sparkline semantic action is not supported")

register_bar_chart_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::BarChart) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "bar chart semantic action is not supported")

register_canvas_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Canvas) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "canvas semantic action is not supported")

register_chart_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Chart) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "chart semantic action is not supported")

register_histogram_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Histogram) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "histogram semantic action is not supported")

register_heatmap_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Heatmap) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "heatmap semantic action is not supported")

function SemanticToolkit.widget_semantic_descriptor(widget::Calendar, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Calendar $(widget.year)-$(lpad(string(widget.month), 2, '0'))",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :year => widget.year,
            :month => widget.month,
            :selected => widget.selected,
            :marked_count => length(widget.marked),
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::LogView, state::LogState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/entry/$(index)",
            Accessibility.ListItemRole;
            label=uppercase(string(entry.level)),
            description=entry.message,
            state=Accessibility.SemanticState(readonly=true),
            metadata=Dict{Symbol,Any}(
                :timestamp_ns => entry.timestamp_ns,
                :level => entry.level,
            ),
        ) for (index, entry) in enumerate(state.entries)
    ]
end

SemanticToolkit.widget_semantic_children(widget::RichLog, state::RichLogState, id) =
    SemanticToolkit.widget_semantic_children(widget.view, state, id)

function _register_log_state_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::LogState,
    viewport_height::Integer,
    label::AbstractString,
)
    node_id = string(id)
    height = max(1, Int(viewport_height))
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        maximum = max(0, length(state.entries) - height)
        if request.action == Accessibility.FocusSemanticAction
            state.offset = clamp(state.offset, 0, maximum)
            return Accessibility.SemanticActionResult(true; value=state.offset)
        elseif request.action == Accessibility.ScrollIntoViewSemanticAction
            state.offset = 0
            return Accessibility.SemanticActionResult(true; value=state.offset)
        elseif request.action == Accessibility.IncrementSemanticAction
            state.offset = max(0, state.offset - 1)
            return Accessibility.SemanticActionResult(true; value=state.offset)
        elseif request.action == Accessibility.DecrementSemanticAction
            state.offset = min(maximum, state.offset + 1)
            return Accessibility.SemanticActionResult(true; value=state.offset)
        end
        return Accessibility.SemanticActionResult(false; message="$label semantic action is not supported")
    end)
    return dispatcher
end

function register_log_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::LogState;
    viewport_height::Integer=1,
)
    return _register_log_state_semantic_handlers!(dispatcher, id, state, viewport_height, "log view")
end

function register_rich_log_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::RichLogState;
    viewport_height::Integer=1,
)
    return _register_log_state_semantic_handlers!(dispatcher, id, state, viewport_height, "rich log")
end

function SemanticToolkit.widget_semantic_descriptor(widget::HelpView, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Keyboard shortcuts",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:hint_count => length(widget.hints)),
    )
end

function SemanticToolkit.widget_semantic_children(widget::HelpView, state, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/hint/$(index)",
            Accessibility.ListItemRole;
            label=hint.key,
            description=hint.description,
            state=Accessibility.SemanticState(readonly=true),
            actions=_readonly_widget_semantic_actions(),
            metadata=Dict{Symbol,Any}(:key => hint.key),
        ) for (index, hint) in enumerate(widget.hints)
    ]
end

_help_view_semantic_value(widget::HelpView) = Dict{Symbol,Any}(
    :hint_count => length(widget.hints),
    :hints => [(hint.key, hint.description) for hint in widget.hints],
)

_help_view_hint_semantic_value(hint::KeyHint) = Dict{Symbol,Any}(
    :key => hint.key,
    :description => hint.description,
)

function register_help_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::HelpView,
)
    root_id = string(id)
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        root_id,
        _help_view_semantic_value(widget),
        "help view semantic action is not supported",
    )
    for (index, hint) in enumerate(widget.hints)
        _register_readonly_widget_semantic_handlers!(
            dispatcher,
            "$(root_id)/hint/$(index)",
            _help_view_hint_semantic_value(hint),
            "help view hint semantic action is not supported",
        )
    end
    return dispatcher
end

_core_line_plain(line::Line) = join(span.content for span in line.spans)
_core_text_plain(text::Text) = join((_core_line_plain(line) for line in text.lines), "\n")

function SemanticToolkit.widget_semantic_descriptor(widget::Header, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.HeadingRole;
        label=widget.title,
        description=isempty(widget.subtitle) ? nothing : widget.subtitle,
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
    )
end

register_header_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Header,
) = _register_readonly_chrome_semantic_handlers!(
    dispatcher,
    id,
    Dict{Symbol,Any}(:title => widget.title, :subtitle => widget.subtitle),
    "header semantic action is not supported",
)

function SemanticToolkit.widget_semantic_descriptor(widget::Footer, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Keyboard shortcuts",
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(:hint_count => length(widget.hints)),
    )
end

function SemanticToolkit.widget_semantic_children(widget::Footer, state, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/hint/$(index)",
            Accessibility.ButtonRole;
            label=hint.key,
            description=hint.description,
            state=Accessibility.SemanticState(readonly=true, focusable=true),
            actions=Accessibility.SemanticAction[
                Accessibility.FocusSemanticAction,
                Accessibility.SelectSemanticAction,
                Accessibility.ActivateSemanticAction,
            ],
            metadata=Dict{Symbol,Any}(:key => hint.key),
        ) for (index, hint) in enumerate(widget.hints)
    ]
end

register_footer_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Footer,
) = _register_hint_bar_semantic_handlers!(dispatcher, id, widget.hints, "Keyboard shortcuts")

function SemanticToolkit.widget_semantic_descriptor(widget::Badge, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.StatusRole;
        label=widget.text,
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
    )
end

_feedback_semantic_value(widget::Badge) = Dict{Symbol,Any}(:text => widget.text)

register_badge_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Badge) =
    _register_feedback_semantic_handlers!(dispatcher, id, _feedback_semantic_value(widget), "badge semantic action is not supported")

function SemanticToolkit.widget_semantic_descriptor(widget::Alert, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.AlertRole;
        label=widget.block.title === nothing ? "Alert" : _core_line_plain(widget.block.title),
        description=_core_text_plain(widget.message),
        state=Accessibility.SemanticState(enabled=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.DismissSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(:severity => widget.severity),
    )
end

function _feedback_semantic_value(widget::Alert)
    return Dict{Symbol,Any}(
        :title => widget.block.title === nothing ? "Alert" : _core_line_plain(widget.block.title),
        :message => _core_text_plain(widget.message),
        :severity => widget.severity,
    )
end

register_alert_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Alert) =
    _register_feedback_semantic_handlers!(dispatcher, id, _feedback_semantic_value(widget), "alert semantic action is not supported")

function SemanticToolkit.widget_semantic_descriptor(widget::Digits, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.StatusRole;
        label=widget.value,
        state=Accessibility.SemanticState(readonly=true, value=widget.value),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:spacing => widget.spacing),
    )
end

_digits_semantic_value(widget::Digits) = Dict{Symbol,Any}(
    :value => widget.value,
    :spacing => widget.spacing,
)

register_digits_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Digits) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        _digits_semantic_value(widget),
        "digits semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Pretty, state)
    value = pretty_text(widget; height=24, width=80)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label="Value",
        state=Accessibility.SemanticState(readonly=true, value=value),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:compact => widget.compact),
    )
end

_pretty_semantic_value(widget::Pretty) = Dict{Symbol,Any}(
    :value => pretty_text(widget; height=24, width=80),
    :compact => widget.compact,
)

register_pretty_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Pretty) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        _pretty_semantic_value(widget),
        "pretty semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Placeholder, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        state=Accessibility.SemanticState(readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(:symbol => widget.symbol),
    )
end

_loading_semantic_value(widget::Placeholder) = Dict{Symbol,Any}(
    :label => widget.label,
    :symbol => widget.symbol,
)

function register_placeholder_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Placeholder,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action in (Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction)
            return Accessibility.SemanticActionResult(true; value=_loading_semantic_value(widget))
        end
        return Accessibility.SemanticActionResult(false; message="placeholder semantic action is not supported")
    end)
    return dispatcher
end

function SemanticToolkit.widget_semantic_descriptor(widget::Label, state)
    content = _core_line_plain(widget.line)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ParagraphRole;
        label=content,
        state=Accessibility.SemanticState(readonly=true, value=content),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:line_count => 1),
    )
end

register_label_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Label) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => _core_line_plain(widget.line),
            :line_count => 1,
        ),
        "label semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Paragraph, state)
    content = _core_text_plain(widget.text)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ParagraphRole;
        label=content,
        state=Accessibility.SemanticState(readonly=true, value=content),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:line_count => length(widget.text.lines), :wrap => widget.wrap),
    )
end

register_paragraph_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Paragraph) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => _core_text_plain(widget.text),
            :line_count => length(widget.text.lines),
            :wrap => widget.wrap,
        ),
        "paragraph semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Heading, state)
    content = _core_text_plain(widget.paragraph.text)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.HeadingRole;
        label=content,
        state=Accessibility.SemanticState(readonly=true, value=content),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(
            :line_count => length(widget.paragraph.text.lines),
            :wrap => widget.paragraph.wrap,
            :widget => :heading,
            :level => widget.level,
        ),
    )
end

register_heading_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Heading) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => _core_text_plain(widget.paragraph.text),
            :line_count => length(widget.paragraph.text.lines),
            :wrap => widget.paragraph.wrap,
            :widget => :heading,
            :level => widget.level,
        ),
        "heading semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::MarkupText, state)
    content = _core_text_plain(widget.paragraph.text)
    heading_roles = [role for role in widget.block_roles if startswith(String(role), "heading_")]
    non_heading_roles = [role for role in widget.block_roles if !startswith(String(role), "heading_")]
    semantic_role = length(heading_roles) == 1 && isempty(non_heading_roles) ?
                    Accessibility.HeadingRole : Accessibility.ParagraphRole
    return SemanticToolkit.SemanticDescriptor(
        semantic_role;
        label=content,
        state=Accessibility.SemanticState(readonly=true, value=content),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(
            :line_count => length(widget.paragraph.text.lines),
            :wrap => widget.paragraph.wrap,
            :widget => :markup_text,
            :block_roles => widget.block_roles,
            :inline_roles => widget.inline_roles,
        ),
    )
end

register_markup_text_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::MarkupText) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => _core_text_plain(widget.paragraph.text),
            :line_count => length(widget.paragraph.text.lines),
            :wrap => widget.paragraph.wrap,
            :widget => :markup_text,
            :block_roles => widget.block_roles,
            :inline_roles => widget.inline_roles,
        ),
        "markup text semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Static, state)
    content = _core_text_plain(widget.paragraph.text)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ParagraphRole;
        label=content,
        state=Accessibility.SemanticState(readonly=true, value=content),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(
            :line_count => length(widget.paragraph.text.lines),
            :wrap => widget.paragraph.wrap,
            :widget => :static,
        ),
    )
end

register_static_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Static) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => _core_text_plain(widget.paragraph.text),
            :line_count => length(widget.paragraph.text.lines),
            :wrap => widget.paragraph.wrap,
            :widget => :static,
        ),
        "static semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::TextView, state)
    content = _core_text_plain(widget.paragraph.text)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ParagraphRole;
        label=content,
        state=Accessibility.SemanticState(readonly=true, value=content),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(
            :line_count => length(widget.paragraph.text.lines),
            :wrap => widget.paragraph.wrap,
            :widget => :text_view,
        ),
    )
end

register_text_view_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::TextView) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => _core_text_plain(widget.paragraph.text),
            :line_count => length(widget.paragraph.text.lines),
            :wrap => widget.paragraph.wrap,
            :widget => :text_view,
        ),
        "text view semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Block, state)
    title = widget.title === nothing ? "Block" : _core_line_plain(widget.title)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=title,
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(
            :borders => widget.borders.bits,
            :padding => (widget.padding.top, widget.padding.right, widget.padding.bottom, widget.padding.left),
        ),
    )
end

register_block_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Block) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => widget.title === nothing ? "Block" : _core_line_plain(widget.title),
            :borders => widget.borders.bits,
            :padding => (widget.padding.top, widget.padding.right, widget.padding.bottom, widget.padding.left),
        ),
        "block semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Clear, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label="Clear surface",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
    )
end

register_clear_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Clear) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Clear surface"),
        "clear semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Spacer, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label="Spacer",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
    )
end

register_spacer_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Spacer) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Spacer"),
        "spacer semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Rule, state)
    direction = widget.direction == HorizontalRule ? :horizontal : :vertical
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label=direction == :horizontal ? "Horizontal rule" : "Vertical rule",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:direction => direction),
    )
end

register_rule_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Rule) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => widget.direction == HorizontalRule ? "Horizontal rule" : "Vertical rule",
            :direction => widget.direction == HorizontalRule ? :horizontal : :vertical,
        ),
        "rule semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Separator, state)
    direction = widget.rule.direction == HorizontalRule ? :horizontal : :vertical
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label=direction == :horizontal ? "Horizontal separator" : "Vertical separator",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:direction => direction),
    )
end

register_separator_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Separator) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => widget.rule.direction == HorizontalRule ? "Horizontal separator" : "Vertical separator",
            :direction => widget.rule.direction == HorizontalRule ? :horizontal : :vertical,
        ),
        "separator semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Divider, state)
    direction = widget.separator.rule.direction == HorizontalRule ? :horizontal : :vertical
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label=direction == :horizontal ? "Horizontal divider" : "Vertical divider",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:direction => direction),
    )
end

register_divider_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Divider) =
    _register_readonly_widget_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => widget.separator.rule.direction == HorizontalRule ? "Horizontal divider" : "Vertical divider",
            :direction => widget.separator.rule.direction == HorizontalRule ? :horizontal : :vertical,
        ),
        "divider semantic action is not supported",
    )

function SemanticToolkit.widget_semantic_descriptor(widget::Padding, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Padded content",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(
            :margin => (widget.margin.top, widget.margin.right, widget.margin.bottom, widget.margin.left),
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Box, state)
    title = widget.block.title === nothing ? "Box" : _core_line_plain(widget.block.title)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=title,
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:borders => widget.block.borders.bits),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Row, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Row",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:child_count => length(widget.children), :orientation => :horizontal),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Column, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Column",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:child_count => length(widget.children), :orientation => :vertical),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Stack, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Stack",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:child_count => length(widget.children), :layered => true),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Overlay, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Overlay",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:child_count => length(widget.stack.children), :layered => true),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Center, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Centered content",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(:height => widget.size.height, :width => widget.size.width),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Grid, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Grid",
        state=Accessibility.SemanticState(readonly=true),
        actions=_readonly_widget_semantic_actions(),
        metadata=Dict{Symbol,Any}(
            :child_count => length(widget.children),
            :rows => length(widget.layout.rows),
            :columns => length(widget.layout.columns),
        ),
    )
end

register_padding_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Padding) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Padded content", :margin => (widget.margin.top, widget.margin.right, widget.margin.bottom, widget.margin.left)),
        "padding semantic action is not supported",
    )

register_box_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Box) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => widget.block.title === nothing ? "Box" : _core_line_plain(widget.block.title),
            :borders => widget.block.borders.bits,
        ),
        "box semantic action is not supported",
    )

register_row_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Row) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Row", :child_count => length(widget.children), :orientation => :horizontal),
        "row semantic action is not supported",
    )

register_column_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Column) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Column", :child_count => length(widget.children), :orientation => :vertical),
        "column semantic action is not supported",
    )

register_stack_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Stack) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Stack", :child_count => length(widget.children), :layered => true),
        "stack semantic action is not supported",
    )

register_overlay_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Overlay) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Overlay", :child_count => length(widget.stack.children), :layered => true),
        "overlay semantic action is not supported",
    )

register_center_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Center) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(:label => "Centered content", :height => widget.size.height, :width => widget.size.width),
        "center semantic action is not supported",
    )

register_grid_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::Grid) =
    _register_readonly_layout_semantic_handlers!(
        dispatcher,
        id,
        Dict{Symbol,Any}(
            :label => "Grid",
            :child_count => length(widget.children),
            :rows => length(widget.layout.rows),
            :columns => length(widget.layout.columns),
        ),
        "grid semantic action is not supported",
    )
# Concise controlled/uncontrolled Toolkit constructors for common input widgets.
function bound_slider(
    binding::AbstractStateBinding;
    minimum::Real=0,
    maximum::Real=100,
    step::Real=1,
    width::Integer=20,
    disabled::Bool=false,
    bindings::AdvancedControlBindings=default_advanced_control_bindings(),
    label::AbstractString="Slider",
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
)
    widget = Slider(
        minimum,
        maximum;
        value=binding_value(binding),
        step,
        width,
        disabled,
        bindings,
        label,
    )
    return bound_element(
        widget,
        binding;
        key,
        id,
        classes,
        focusable,
        apply_value! = (state, value) -> set_slider!(state, value),
        extract_value=state -> state.value,
    )
end

function _range_binding_values(value)
    if value isa NamedTuple && haskey(value, :lower) && haskey(value, :upper)
        return value.lower, value.upper, :named
    elseif value isa Tuple && length(value) == 2
        return value[1], value[2], :tuple
    end
    throw(ArgumentError("range slider binding must contain (lower, upper) values"))
end

function bound_range_slider(
    binding::AbstractStateBinding;
    minimum::Real=0,
    maximum::Real=100,
    step::Real=1,
    active::RangeSliderHandle=LowerRangeHandle,
    allow_crossing::Bool=false,
    width::Integer=20,
    disabled::Bool=false,
    bindings::AdvancedControlBindings=default_advanced_control_bindings(),
    label::AbstractString="Range slider",
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
)
    lower, upper, shape = _range_binding_values(binding_value(binding))
    widget = RangeSlider(
        minimum,
        maximum;
        lower,
        upper,
        step,
        active,
        allow_crossing,
        width,
        disabled,
        bindings,
        label,
    )
    extract = shape == :named ?
        state -> (lower=state.lower, upper=state.upper) :
        state -> (state.lower, state.upper)
    return bound_element(
        widget,
        binding;
        key,
        id,
        classes,
        focusable,
        apply_value! = (state, value) -> begin
            next_lower, next_upper, _ = _range_binding_values(value)
            set_range_slider!(state, next_lower, next_upper)
        end,
        extract_value=extract,
    )
end

function bound_checkbox(
    label::AbstractString,
    binding::AbstractStateBinding;
    checked_symbol::AbstractString="[x]",
    unchecked_symbol::AbstractString="[ ]",
    style::Style=Style(),
    checked_style::Style=Style(modifiers=BOLD),
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
)
    widget = Checkbox(label; checked_symbol, unchecked_symbol, style, checked_style)
    return bound_property_element(
        widget,
        binding,
        :checked;
        key,
        id,
        classes,
        focusable,
    )
end

function bound_toggle(
    binding::AbstractStateBinding;
    on_label::AbstractString="ON",
    off_label::AbstractString="OFF",
    on_style::Style=Style(modifiers=BOLD),
    off_style::Style=Style(modifiers=DIM),
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
)
    widget = Toggle(; on_label, off_label, on_style, off_style)
    return bound_property_element(
        widget,
        binding,
        :enabled;
        key,
        id,
        classes,
        focusable,
    )
end

function bound_text_input(
    binding::AbstractStateBinding;
    placeholder::AbstractString="",
    block::Union{Nothing,Block}=nothing,
    style::Style=Style(),
    placeholder_style::Style=Style(modifiers=DIM),
    selection_style::Style=Style(modifiers=REVERSED),
    cursor_style::Style=Style(modifiers=REVERSED),
    mask::Union{Nothing,AbstractString}=nothing,
    maximum_length::Integer=typemax(Int),
    history_limit::Integer=100,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
)
    initial = String(binding_value(binding))
    widget = TextInput(;
        placeholder,
        block,
        style,
        placeholder_style,
        selection_style,
        cursor_style,
        mask,
        maximum_length,
    )
    return bound_element(
        widget,
        binding;
        key,
        id,
        classes,
        focusable,
        state_factory=() -> TextInputState(initial; history_limit),
        apply_value! = (state, value) -> begin
            text = String(value)
            editing_text(state) == text || set_text!(state, text; record=false)
            state
        end,
        extract_value=editing_text,
    )
end

"""Invisible controller backing a declaratively composed virtual viewport."""
abstract type AbstractLazyController end

struct LazyColumnController{S,B,P,A,C} <: AbstractLazyController
    source::S
    width::Int
    height::Int
    item_extent::Int
    overscan::Int
    multiple::Bool
    bindings::B
    pointer_options::P
    on_activate::A
    on_selection_change::C
end

function LazyColumnController(
    source::AbstractDataSource;
    width::Integer=80,
    height::Integer=24,
    item_extent::Integer=1,
    overscan::Integer=2,
    multiple::Bool=false,
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
    on_activate=nothing,
    on_selection_change=nothing,
)
    width > 0 || throw(ArgumentError("lazy column width must be positive"))
    height >= 0 || throw(ArgumentError("lazy column height cannot be negative"))
    item_extent > 0 || throw(ArgumentError("lazy column item extent must be positive"))
    overscan >= 0 || throw(ArgumentError("lazy column overscan cannot be negative"))
    return LazyColumnController(
        source,
        Int(width),
        Int(height),
        Int(item_extent),
        Int(overscan),
        multiple,
        bindings,
        pointer_options,
        on_activate,
        on_selection_change,
    )
end

function state_for(widget::LazyColumnController{S}) where {T,K,S<:AbstractDataSource{T,K}}
    return VirtualListState{K}(
        viewport_size=cld(widget.height, widget.item_extent),
        overscan=widget.overscan,
        multiple=widget.multiple,
    )
end

measure(widget::LazyColumnController, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

render!(buffer::Buffer, ::LazyColumnController, ::Rect, ::VirtualListState) = buffer
render!(buffer::Buffer, widget::LazyColumnController, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function _lazy_column_window!(widget::LazyColumnController, state::VirtualListState)
    resize_virtual_list!(state, cld(widget.height, widget.item_extent))
    return refresh_virtual_list!(widget.source, state)
end

function _notify_lazy_selection(widget::AbstractLazyController, state::VirtualListState)
    callback = widget.on_selection_change
    callback === nothing && return
    selection = copy(state.selected)
    if applicable(callback, selection, state)
        callback(selection, state)
    elseif applicable(callback, selection)
        callback(selection)
    elseif applicable(callback, state)
        callback(state)
    else
        throw(ArgumentError("lazy column selection callback must accept selection/state, selection, or state"))
    end
end

function _notify_lazy_activation(widget::AbstractLazyController, key, state::VirtualListState)
    callback = widget.on_activate
    callback === nothing && return
    if applicable(callback, key, state)
        callback(key, state)
    elseif applicable(callback, key)
        callback(key)
    elseif applicable(callback, state)
        callback(state)
    else
        throw(ArgumentError("lazy column activation callback must accept key/state, key, or state"))
    end
end

function handle!(state::VirtualListState, widget::LazyColumnController, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    window = _lazy_column_window!(widget, state)
    before = copy(state.selected)
    result = handle_virtual_key!(
        state,
        window,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    )
    before == state.selected || _notify_lazy_selection(widget, state)
    result.action == VirtualActivate && result.key !== nothing &&
        _notify_lazy_activation(widget, result.key, state)
    return result.consumed
end

function handle!(state::VirtualListState, widget::LazyColumnController, event::MouseEvent, area::Rect)
    active = intersection(area, Rect(area.row, area.column, widget.height, widget.width))
    contains(active, event.position) || return false
    window = _lazy_column_window!(widget, state)
    if event.action == MouseScroll
        delta = event.button == WheelUpButton ? -3 : event.button == WheelDownButton ? 3 : 0
        delta == 0 && return false
        scroll_virtual_list!(state, delta; total_length=window.total_length)
        return true
    end
    event.action in (MousePress, MouseRelease, MouseMove) || return false
    kind = event.action == MouseMove ? VirtualPointerHover :
           event.click_count > 1 ? VirtualPointerDoublePress : VirtualPointerPress
    viewport_row = div(event.position.row - active.row, widget.item_extent) + 1
    before = copy(state.selected)
    result = handle_virtual_pointer!(
        state,
        window,
        VirtualPointerEvent(
            kind,
            viewport_row,
            event.position.column - active.column + 1;
            control=in(CTRL, event.modifiers),
            shift=in(SHIFT, event.modifiers),
        );
        options=widget.pointer_options,
    )
    before == state.selected || _notify_lazy_selection(widget, state)
    result.activated && _notify_lazy_activation(widget, result.key, state)
    return result.consumed
end

handle!(::VirtualListState, ::LazyColumnController, ::PasteEvent) = false

SemanticToolkit.widget_semantic_descriptor(widget::LazyColumnController, state::VirtualListState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Lazy column",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(
            :cursor => state.cursor,
            :first_index => state.viewport.first_index,
            :selected_count => length(state.selected),
            :total_length => data_length(widget.source),
        ),
    )

function _invoke_lazy_content(builder, primary, slot::DataSlot, state::VirtualListState)
    applicable(builder, primary, slot.index, slot.key, state) &&
        return builder(primary, slot.index, slot.key, state)
    applicable(builder, primary, slot.index, slot.key) &&
        return builder(primary, slot.index, slot.key)
    applicable(builder, primary, slot.index) && return builder(primary, slot.index)
    applicable(builder, primary) && return builder(primary)
    applicable(builder) && return builder()
    throw(ArgumentError("lazy column content builder has an unsupported signature"))
end

function _keyed_lazy_content(content, key; on_event=nothing)
    children = Toolkit._normalize_elements((content,))
    isempty(children) && return nothing
    root = length(children) == 1 ? only(children) : column(children...)
    on_event === nothing && return modify(root, element_modifier(key=key))
    return Element(nothing; key, children=(root,), layout=:stack, on_event)
end

function _invoke_lazy_empty(builder, state::VirtualListState)
    applicable(builder, state) && return builder(state)
    applicable(builder) && return builder()
    throw(ArgumentError("lazy column empty builder must accept state or no arguments"))
end

struct LazyColumnStateKey end
struct LazyColumnViewportKey end

function _lazy_row_event_handler(
    controller::AbstractLazyController,
    state::VirtualListState,
    slot::DataSlot,
)
    return function (routed, _)
        routed.phase == BubblePhase || return nothing
        event = routed.event
        event isa MouseEvent || return nothing
        if event.action == MouseScroll
            amount = _lazy_scroll_step(controller)
            delta = event.button == WheelUpButton ? -amount : event.button == WheelDownButton ? amount : 0
            delta == 0 && return nothing
            window = _lazy_controller_window!(controller, state)
            scroll_virtual_list!(state, delta; total_length=window.total_length)
            return EventResponse(consumed=true, redraw=true)
        end
        slot.kind == ReadySlot || return nothing
        if event.action == MouseMove
            controller.pointer_options.focus_on_hover && (state.cursor = slot.index)
            return EventResponse(consumed=true, redraw=true)
        elseif event.action == MousePress
            before = copy(state.selected)
            if controller.pointer_options.select_on_press
                if controller.pointer_options.toggle_with_control && in(CTRL, event.modifiers) && slot.key in state.selected
                    delete!(state.selected, slot.key)
                    state.cursor = slot.index
                    state.anchor = slot.index
                else
                    select_virtual_index!(state, slot)
                end
            end
            before == state.selected || _notify_lazy_selection(controller, state)
            if event.click_count > 1 && controller.pointer_options.activate_on_double_press
                _notify_lazy_activation(controller, slot.key, state)
            end
            return EventResponse(consumed=true, redraw=true)
        end
        return nothing
    end
end

_lazy_controller_window!(controller::LazyColumnController, state::VirtualListState) =
    _lazy_column_window!(controller, state)
_lazy_scroll_step(::LazyColumnController) = 3

"""Compose only the visible rows of a keyed virtual data source.

The `item` builder may accept `(item, index, key, state)`, progressively fewer
arguments, or no arguments. Each materialized root is forcibly keyed from the
data source so retained descendant state follows the item while it remains in
the viewport. Loading and failure builders receive the slot and index through
the same progressive callback convention.
"""
function lazy_column(
    source::AbstractDataSource;
    item,
    loading=slot -> "Loading…",
    failure=(error, index) -> "Error loading row $index",
    empty="",
    width::Integer=80,
    height::Integer=24,
    item_extent::Integer=1,
    overscan::Integer=2,
    multiple::Bool=false,
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
    on_activate=nothing,
    on_selection_change=nothing,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
)
    controller = LazyColumnController(
        source;
        width,
        height,
        item_extent,
        overscan,
        multiple,
        bindings,
        pointer_options,
        on_activate,
        on_selection_change,
    )
    view = function (component_state)
        remembered = remember!(component_state, LazyColumnStateKey(), state_for(controller))
        state = remembered_value(remembered)
        window = _lazy_column_window!(controller, state)
        children = Element[]
        if window.total_length == 0
            content = empty isa Function ? _invoke_lazy_empty(empty, state) : empty
            keyed = _keyed_lazy_content(content, (:empty, 0))
            keyed === nothing || push!(children, keyed)
        else
            for slot in window.slots
                window.first_visible <= slot.index <= window.last_visible || continue
                content = if slot.kind == ReadySlot
                    _invoke_lazy_content(item, slot.item, slot, state)
                elseif slot.kind == LoadingSlot
                    _invoke_lazy_content(loading, slot, slot, state)
                elseif slot.kind == FailedSlot
                    _invoke_lazy_content(failure, slot.error, slot, state)
                else
                    continue
                end
                row_key = slot.kind == ReadySlot ? slot.key : (slot.kind, slot.index)
                keyed = _keyed_lazy_content(
                    content,
                    row_key;
                    on_event=_lazy_row_event_handler(controller, state, slot),
                )
                keyed === nothing || push!(children, keyed)
            end
        end
        constraints = Constraint[Length(item_extent) for _ in children]
        return Element(
            controller;
            key=LazyColumnViewportKey(),
            id,
            children,
            layout=FlexLayout(VerticalLayout, constraints),
            state_factory=() -> state,
            focusable,
            classes,
        )
    end
    return component(view; key)
end

function lazy_column(
    items::AbstractVector;
    item,
    item_key=(value, index) -> index,
    kwargs...,
)
    resolved_key = (value, index) -> begin
        applicable(item_key, value, index) && return item_key(value, index)
        applicable(item_key, value) && return item_key(value)
        throw(ArgumentError("lazy column item key must accept item/index or item"))
    end
    return lazy_column(VectorDataSource(items; key=resolved_key); item, kwargs...)
end

lazy_column(item::Function, source::AbstractDataSource; kwargs...) =
    lazy_column(source; item, kwargs...)

lazy_column(item::Function, items::AbstractVector; kwargs...) =
    lazy_column(items; item, kwargs...)

"""Invisible controller for a viewport-only declarative grid."""
struct LazyGridController{S,B,P,A,C} <: AbstractLazyController
    source::S
    width::Int
    height::Int
    columns::Int
    row_extent::Int
    row_gap::Int
    column_gap::Int
    overscan::Int
    multiple::Bool
    bindings::B
    pointer_options::P
    on_activate::A
    on_selection_change::C
end

function LazyGridController(
    source::AbstractDataSource;
    width::Integer=80,
    height::Integer=24,
    columns::Integer=2,
    row_extent::Integer=1,
    row_gap::Integer=0,
    column_gap::Integer=0,
    overscan::Integer=2,
    multiple::Bool=false,
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
    on_activate=nothing,
    on_selection_change=nothing,
)
    width > 0 || throw(ArgumentError("lazy grid width must be positive"))
    height >= 0 || throw(ArgumentError("lazy grid height cannot be negative"))
    columns > 0 || throw(ArgumentError("lazy grid column count must be positive"))
    row_extent > 0 || throw(ArgumentError("lazy grid row extent must be positive"))
    row_gap >= 0 || throw(ArgumentError("lazy grid row gap cannot be negative"))
    column_gap >= 0 || throw(ArgumentError("lazy grid column gap cannot be negative"))
    overscan >= 0 || throw(ArgumentError("lazy grid overscan cannot be negative"))
    return LazyGridController(
        source,
        Int(width),
        Int(height),
        Int(columns),
        Int(row_extent),
        Int(row_gap),
        Int(column_gap),
        Int(overscan),
        multiple,
        bindings,
        pointer_options,
        on_activate,
        on_selection_change,
    )
end

_lazy_grid_rows(widget::LazyGridController) = widget.height == 0 ? 0 :
    max(1, cld(widget.height + widget.row_gap, widget.row_extent + widget.row_gap))
_lazy_grid_capacity(widget::LazyGridController) = _lazy_grid_rows(widget) * widget.columns
_lazy_scroll_step(widget::LazyGridController) = 3 * widget.columns

function state_for(widget::LazyGridController{S}) where {T,K,S<:AbstractDataSource{T,K}}
    return VirtualListState{K}(
        viewport_size=_lazy_grid_capacity(widget),
        overscan=widget.overscan * widget.columns,
        multiple=widget.multiple,
    )
end

measure(widget::LazyGridController, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))
render!(buffer::Buffer, ::LazyGridController, ::Rect, ::VirtualListState) = buffer
render!(buffer::Buffer, widget::LazyGridController, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function _lazy_controller_window!(widget::LazyGridController, state::VirtualListState)
    resize_virtual_list!(state, _lazy_grid_capacity(widget))
    return refresh_virtual_list!(widget.source, state)
end

function _lazy_grid_cursor_slot(window::VirtualListWindow, cursor)
    cursor === nothing && return nothing
    return findfirst(slot -> slot.index == cursor && slot.kind == ReadySlot, window.slots)
end

function _ensure_lazy_grid_cursor_visible!(
    state::VirtualListState,
    widget::LazyGridController;
    total_length=nothing,
)
    state.cursor === nothing && return state
    rows = max(1, _lazy_grid_rows(widget))
    cursor_row = div(state.cursor - 1, widget.columns)
    first_row = div(state.viewport.first_index - 1, widget.columns)
    if cursor_row < first_row
        first_row = cursor_row
    elseif cursor_row >= first_row + rows
        first_row = cursor_row - rows + 1
    end
    first_index = first_row * widget.columns + 1
    if total_length !== nothing
        final_row = max(0, cld(Int(total_length), widget.columns) - 1)
        first_index = min(first_index, max(1, (max(0, final_row - rows + 1) * widget.columns) + 1))
    end
    state.viewport = VirtualViewport(
        max(1, first_index),
        state.viewport.viewport_size;
        overscan=state.viewport.overscan,
    )
    return state
end

function handle!(state::VirtualListState, widget::LazyGridController, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    action = virtual_action_for_key(
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    )
    action === nothing && return false
    window = _lazy_controller_window!(widget, state)
    total = window.total_length
    if action == VirtualCursorUp
        move_virtual_cursor!(state, -widget.columns; total_length=total)
    elseif action == VirtualCursorDown
        move_virtual_cursor!(state, widget.columns; total_length=total)
    elseif action == VirtualExpand
        move_virtual_cursor!(state, 1; total_length=total)
    elseif action == VirtualCollapse
        move_virtual_cursor!(state, -1; total_length=total)
    elseif action == VirtualPageUp
        move_virtual_cursor!(state, -max(1, _lazy_grid_capacity(widget)); total_length=total)
    elseif action == VirtualPageDown
        move_virtual_cursor!(state, max(1, _lazy_grid_capacity(widget)); total_length=total)
    elseif action == VirtualHome
        state.cursor = total == 0 ? nothing : 1
    elseif action == VirtualEnd
        total === nothing && return false
        state.cursor = total == 0 ? nothing : total
    elseif action in (VirtualToggleSelection, VirtualActivate)
        slot_index = _lazy_grid_cursor_slot(window, state.cursor)
        slot_index === nothing && return false
        slot = window.slots[slot_index]
        if action == VirtualToggleSelection
            before = copy(state.selected)
            toggle_virtual_selection!(state, slot)
            before == state.selected || _notify_lazy_selection(widget, state)
        else
            _notify_lazy_activation(widget, slot.key, state)
        end
        return true
    else
        return false
    end
    _ensure_lazy_grid_cursor_visible!(state, widget; total_length=total)
    return true
end

handle!(::VirtualListState, ::LazyGridController, ::PasteEvent) = false

SemanticToolkit.widget_semantic_descriptor(widget::LazyGridController, state::VirtualListState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.TableRole;
        label="Lazy grid",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(
            :columns => widget.columns,
            :cursor => state.cursor,
            :first_index => state.viewport.first_index,
            :selected_count => length(state.selected),
            :total_length => data_length(widget.source),
        ),
    )

struct LazyGridStateKey end
struct LazyGridViewportKey end

"""Compose only the visible cells of a keyed virtual data source."""
function lazy_grid(
    source::AbstractDataSource;
    item,
    loading=slot -> "Loading…",
    failure=(error, index) -> "Error loading cell $index",
    empty="",
    width::Integer=80,
    height::Integer=24,
    columns::Integer=2,
    row_extent::Integer=1,
    row_gap::Integer=0,
    column_gap::Integer=0,
    overscan::Integer=2,
    multiple::Bool=false,
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
    on_activate=nothing,
    on_selection_change=nothing,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
)
    controller = LazyGridController(
        source;
        width,
        height,
        columns,
        row_extent,
        row_gap,
        column_gap,
        overscan,
        multiple,
        bindings,
        pointer_options,
        on_activate,
        on_selection_change,
    )
    view = function (component_state)
        remembered = remember!(component_state, LazyGridStateKey(), state_for(controller))
        state = remembered_value(remembered)
        window = _lazy_controller_window!(controller, state)
        children = Element[]
        if window.total_length == 0
            content = empty isa Function ? _invoke_lazy_empty(empty, state) : empty
            keyed = _keyed_lazy_content(content, (:empty, 0))
            keyed === nothing || push!(children, keyed)
        else
            for slot in window.slots
                window.first_visible <= slot.index <= window.last_visible || continue
                content = slot.kind == ReadySlot ?
                    _invoke_lazy_content(item, slot.item, slot, state) :
                    slot.kind == LoadingSlot ? _invoke_lazy_content(loading, slot, slot, state) :
                    slot.kind == FailedSlot ? _invoke_lazy_content(failure, slot.error, slot, state) : nothing
                content === nothing && continue
                cell_key = slot.kind == ReadySlot ? slot.key : (slot.kind, slot.index)
                keyed = _keyed_lazy_content(
                    content,
                    cell_key;
                    on_event=_lazy_row_event_handler(controller, state, slot),
                )
                keyed === nothing || push!(children, keyed)
            end
        end
        row_count = isempty(children) ? 0 : cld(length(children), controller.columns)
        return Element(
            controller;
            key=LazyGridViewportKey(),
            id,
            children,
            layout=GridLayout(
                fill(Length(controller.row_extent), row_count),
                fill(Fill(1), controller.columns);
                row_gap=controller.row_gap,
                column_gap=controller.column_gap,
            ),
            state_factory=() -> state,
            focusable,
            classes,
        )
    end
    return component(view; key)
end

function lazy_grid(
    items::AbstractVector;
    item,
    item_key=(value, index) -> index,
    kwargs...,
)
    resolved_key = (value, index) -> begin
        applicable(item_key, value, index) && return item_key(value, index)
        applicable(item_key, value) && return item_key(value)
        throw(ArgumentError("lazy grid item key must accept item/index or item"))
    end
    return lazy_grid(VectorDataSource(items; key=resolved_key); item, kwargs...)
end

lazy_grid(item::Function, source::AbstractDataSource; kwargs...) =
    lazy_grid(source; item, kwargs...)
lazy_grid(item::Function, items::AbstractVector; kwargs...) =
    lazy_grid(items; item, kwargs...)

"""Invisible controller for a horizontally virtualized declarative row."""
struct LazyRowController{S,B,P,A,C} <: AbstractLazyController
    source::S
    width::Int
    height::Int
    item_extent::Int
    column_gap::Int
    overscan::Int
    multiple::Bool
    bindings::B
    pointer_options::P
    on_activate::A
    on_selection_change::C
end

function LazyRowController(
    source::AbstractDataSource;
    width::Integer=80,
    height::Integer=1,
    item_extent::Integer=12,
    column_gap::Integer=0,
    overscan::Integer=2,
    multiple::Bool=false,
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
    on_activate=nothing,
    on_selection_change=nothing,
)
    width > 0 || throw(ArgumentError("lazy row width must be positive"))
    height >= 0 || throw(ArgumentError("lazy row height cannot be negative"))
    item_extent > 0 || throw(ArgumentError("lazy row item extent must be positive"))
    column_gap >= 0 || throw(ArgumentError("lazy row column gap cannot be negative"))
    overscan >= 0 || throw(ArgumentError("lazy row overscan cannot be negative"))
    return LazyRowController(
        source,
        Int(width),
        Int(height),
        Int(item_extent),
        Int(column_gap),
        Int(overscan),
        multiple,
        bindings,
        pointer_options,
        on_activate,
        on_selection_change,
    )
end

_lazy_row_capacity(widget::LazyRowController) = max(
    1,
    cld(widget.width + widget.column_gap, widget.item_extent + widget.column_gap),
)
_lazy_scroll_step(::LazyRowController) = 3

function state_for(widget::LazyRowController{S}) where {T,K,S<:AbstractDataSource{T,K}}
    return VirtualListState{K}(
        viewport_size=_lazy_row_capacity(widget),
        overscan=widget.overscan,
        multiple=widget.multiple,
    )
end

measure(widget::LazyRowController, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))
render!(buffer::Buffer, ::LazyRowController, ::Rect, ::VirtualListState) = buffer
render!(buffer::Buffer, widget::LazyRowController, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function _lazy_controller_window!(widget::LazyRowController, state::VirtualListState)
    resize_virtual_list!(state, _lazy_row_capacity(widget))
    return refresh_virtual_list!(widget.source, state)
end

function handle!(state::VirtualListState, widget::LazyRowController, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    action = virtual_action_for_key(
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    )
    action === nothing && return false
    window = _lazy_controller_window!(widget, state)
    total = window.total_length
    if action == VirtualExpand
        move_virtual_cursor!(state, 1; total_length=total)
    elseif action == VirtualCollapse
        move_virtual_cursor!(state, -1; total_length=total)
    elseif action == VirtualPageUp
        move_virtual_cursor!(state, -max(1, _lazy_row_capacity(widget)); total_length=total)
    elseif action == VirtualPageDown
        move_virtual_cursor!(state, max(1, _lazy_row_capacity(widget)); total_length=total)
    elseif action == VirtualHome
        state.cursor = total == 0 ? nothing : 1
    elseif action == VirtualEnd
        total === nothing && return false
        state.cursor = total == 0 ? nothing : total
    elseif action in (VirtualToggleSelection, VirtualActivate)
        slot_index = _lazy_grid_cursor_slot(window, state.cursor)
        slot_index === nothing && return false
        slot = window.slots[slot_index]
        if action == VirtualToggleSelection
            before = copy(state.selected)
            toggle_virtual_selection!(state, slot)
            before == state.selected || _notify_lazy_selection(widget, state)
        else
            _notify_lazy_activation(widget, slot.key, state)
        end
        return true
    else
        return false
    end
    ensure_virtual_cursor_visible!(state; total_length=total)
    return true
end

handle!(::VirtualListState, ::LazyRowController, ::PasteEvent) = false

SemanticToolkit.widget_semantic_descriptor(widget::LazyRowController, state::VirtualListState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Lazy row",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(
            :orientation => :horizontal,
            :cursor => state.cursor,
            :first_index => state.viewport.first_index,
            :selected_count => length(state.selected),
            :total_length => data_length(widget.source),
        ),
    )

struct LazyRowStateKey end
struct LazyRowViewportKey end

"""Compose only the visible cells of a horizontally scrolling keyed row."""
function lazy_row(
    source::AbstractDataSource;
    item,
    loading=slot -> "Loading…",
    failure=(error, index) -> "Error loading item $index",
    empty="",
    width::Integer=80,
    height::Integer=1,
    item_extent::Integer=12,
    column_gap::Integer=0,
    overscan::Integer=2,
    multiple::Bool=false,
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
    on_activate=nothing,
    on_selection_change=nothing,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
)
    controller = LazyRowController(
        source;
        width,
        height,
        item_extent,
        column_gap,
        overscan,
        multiple,
        bindings,
        pointer_options,
        on_activate,
        on_selection_change,
    )
    view = function (component_state)
        remembered = remember!(component_state, LazyRowStateKey(), state_for(controller))
        state = remembered_value(remembered)
        window = _lazy_controller_window!(controller, state)
        children = Element[]
        if window.total_length == 0
            content = empty isa Function ? _invoke_lazy_empty(empty, state) : empty
            keyed = _keyed_lazy_content(content, (:empty, 0))
            keyed === nothing || push!(children, keyed)
        else
            for slot in window.slots
                window.first_visible <= slot.index <= window.last_visible || continue
                content = slot.kind == ReadySlot ?
                    _invoke_lazy_content(item, slot.item, slot, state) :
                    slot.kind == LoadingSlot ? _invoke_lazy_content(loading, slot, slot, state) :
                    slot.kind == FailedSlot ? _invoke_lazy_content(failure, slot.error, slot, state) : nothing
                content === nothing && continue
                cell_key = slot.kind == ReadySlot ? slot.key : (slot.kind, slot.index)
                keyed = _keyed_lazy_content(
                    content,
                    cell_key;
                    on_event=_lazy_row_event_handler(controller, state, slot),
                )
                keyed === nothing || push!(children, keyed)
            end
        end
        return Element(
            controller;
            key=LazyRowViewportKey(),
            id,
            children,
            layout=FlexLayout(
                HorizontalLayout,
                Constraint[Length(controller.item_extent) for _ in children];
                gap=controller.column_gap,
            ),
            state_factory=() -> state,
            focusable,
            classes,
        )
    end
    return component(view; key)
end

function lazy_row(
    items::AbstractVector;
    item,
    item_key=(value, index) -> index,
    kwargs...,
)
    resolved_key = (value, index) -> begin
        applicable(item_key, value, index) && return item_key(value, index)
        applicable(item_key, value) && return item_key(value)
        throw(ArgumentError("lazy row item key must accept item/index or item"))
    end
    return lazy_row(VectorDataSource(items; key=resolved_key); item, kwargs...)
end

lazy_row(item::Function, source::AbstractDataSource; kwargs...) =
    lazy_row(source; item, kwargs...)
lazy_row(item::Function, items::AbstractVector; kwargs...) =
    lazy_row(items; item, kwargs...)

"""Composition-local owner for declarative animations."""
struct AnimationContext
    manager::AnimationManager
end

const AnimationLocal = composition_local(
    :animation_manager,
    nothing;
    value_type=Union{Nothing,AnimationContext},
)

"""Provide an animation manager to declarative descendants."""
animation_provider(
    manager::AnimationManager,
    children...;
    kwargs...,
) = provide_context(AnimationLocal => AnimationContext(manager); children, kwargs...)

animation_provider(build::Function, manager::AnimationManager; kwargs...) =
    animation_provider(manager, build(); kwargs...)

"""Lifecycle-bound value driven by Wicked's deterministic animation manager."""
mutable struct AnimatedValue
    value::Any
    target::Any
    status::AnimationStatus
    handle::Union{Nothing,AnimationHandle}
    generation::UInt64
    lock::ReentrantLock
end

AnimatedValue(value) = AnimatedValue(
    value,
    value,
    CompletedAnimation,
    nothing,
    UInt64(0),
    ReentrantLock(),
)

animated_value(value::AnimatedValue) = lock(value.lock) do
    value.value
end
animation_target(value::AnimatedValue) = lock(value.lock) do
    value.target
end
animated_value_status(value::AnimatedValue) = lock(value.lock) do
    value.status
end
animated_value_running(value::AnimatedValue) = animated_value_status(value) in
    (PendingAnimation, RunningAnimation)

struct AnimatedValueMemoryKey
    key::Any
end
struct AnimatedValueEffectKey
    key::Any
end

function _animation_manager(
    state::ComponentState,
    manager::Union{Nothing,AnimationManager},
)
    manager !== nothing && return manager
    context = composition_value(state, AnimationLocal)
    context === nothing && throw(ArgumentError(
        "animate_value_as_state! requires a manager keyword or animation_provider ancestor",
    ))
    return context.manager
end

function _cancel_animated_value!(value::AnimatedValue, manager::AnimationManager)
    handle = lock(value.lock) do
        value.generation += UInt64(1)
        handle = value.handle
        value.handle = nothing
        value.status in (PendingAnimation, RunningAnimation, PausedAnimation) &&
            (value.status = CancelledAnimation)
        handle
    end
    handle === nothing || cancel_animation!(manager, handle)
    return value
end

function _start_animated_value!(
    value::AnimatedValue,
    target,
    manager::AnimationManager,
    state::ComponentState;
    duration::Real,
    delay::Real,
    easing,
    interpolation,
    essential::Bool,
)
    from, generation = lock(value.lock) do
        value.generation += UInt64(1)
        value.target = target
        value.status = RunningAnimation
        value.handle = nothing
        value.value, value.generation
    end
    if isequal(from, target)
        lock(value.lock) do
            value.status = CompletedAnimation
        end
        return value
    end
    spec = AnimationSpec(
        AnimationTrack(from, target; easing, interpolation);
        duration,
        delay,
        essential,
    )
    handle = animate!(
        manager,
        spec;
        on_update=sample -> begin
            changed = lock(value.lock) do
                value.generation == generation || return false
                previous_status = value.status
                changed = !isequal(value.value, sample)
                value.value = sample
                status = animation_status(manager, something(value.handle, AnimationHandle(0)))
                status === nothing || (value.status = status)
                changed || value.status != previous_status
            end
            changed && invalidate_component!(state)
        end,
        on_finish=(finished, reason, sample) -> begin
            changed = lock(value.lock) do
                value.generation == generation || return false
                changed = !isequal(value.value, sample) || value.handle !== nothing
                value.value = sample
                value.handle = nothing
                value.status = reason == AnimationFinished ? CompletedAnimation : CancelledAnimation
                changed
            end
            changed && invalidate_component!(state)
        end,
    )
    lock(value.lock) do
        if value.generation == generation && value.status != CompletedAnimation
            value.handle = handle
            current_status = animation_status(manager, handle)
            value.status = something(current_status, CompletedAnimation)
        end
    end
    return value
end

"""Animate a remembered value toward `target` and invalidate its component on samples.

The manager remains pull-driven; application services or tests advance it with
`tick_animations!`. Retargeting starts from the latest sampled value. Omitting
the call or unmounting the component cancels its current handle.
"""
function animate_value_as_state!(
    state::ComponentState,
    key,
    target;
    manager::Union{Nothing,AnimationManager}=nothing,
    duration::Real=0.25,
    delay::Real=0.0,
    easing=linear_easing,
    interpolation=interpolate_value,
    essential::Bool=false,
)
    resolved_manager = _animation_manager(state, manager)
    remembered = remember!(state, AnimatedValueMemoryKey(key), AnimatedValue(target))
    value = remembered_value(remembered)
    dependencies = (target, resolved_manager, duration, delay, easing, interpolation, essential)
    use_effect!(state, AnimatedValueEffectKey(key), dependencies) do component_state
        _start_animated_value!(
            value,
            target,
            resolved_manager,
            component_state;
            duration,
            delay,
            easing,
            interpolation,
            essential,
        )
        return () -> _cancel_animated_value!(value, resolved_manager)
    end
    return value
end

"""Retained interaction state for an arbitrary clickable content region."""
mutable struct ClickableState
    focused::Bool
    pressed::Bool
    hovered::Bool
    activations::UInt64
end

ClickableState() = ClickableState(false, false, false, UInt64(0))

struct ClickableRegion{F}
    on_click::F
    label::String
    disabled::Bool
end

function _invoke_clickable(widget::ClickableRegion, state::ClickableState)
    widget.disabled && return nothing
    state.activations == typemax(UInt64) && throw(OverflowError("clickable activation count exhausted"))
    state.activations += UInt64(1)
    callback = widget.on_click
    applicable(callback, state) && return callback(state)
    applicable(callback) && return callback()
    throw(ArgumentError("clickable callback must accept ClickableState or no arguments"))
end

activate(widget::ClickableRegion, state::ClickableState) = _invoke_clickable(widget, state)

function handle!(state::ClickableState, widget::ClickableRegion, event::KeyEvent)
    widget.disabled && return false
    event.kind in (KeyPress, KeyRepeat) || return false
    return event.key.code in (:enter, :space) ||
        (event.key.code == :character && event.text == " ")
end

function handle!(state::ClickableState, widget::ClickableRegion, event::MouseEvent)
    widget.disabled && return false
    if event.action == MousePress && event.button == LeftMouseButton
        state.pressed = true
        return true
    elseif event.action == MouseRelease && event.button == LeftMouseButton
        state.pressed = false
        return true
    end
    return false
end

measure(::ClickableRegion, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, ::ClickableRegion, ::Rect, ::ClickableState) = buffer
render!(buffer::Buffer, widget::ClickableRegion, area::Rect) =
    render!(buffer, widget, area, ClickableState())

SemanticToolkit.widget_semantic_descriptor(widget::ClickableRegion, state::ClickableState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.ButtonRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            enabled=!widget.disabled,
            focusable=!widget.disabled,
            focused=state.focused,
        ),
        actions=widget.disabled ? Accessibility.SemanticAction[] : [
            Accessibility.FocusSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(:activations => state.activations, :pressed => state.pressed, :hovered => state.hovered),
    )

function _clickable_bubble_handler(widget::ClickableRegion)
    return function (routed, state)
        routed.phase == BubblePhase || return nothing
        event = routed.event
        event isa MouseEvent || return nothing
        handled = handle!(state, widget, event)
        handled || return nothing
        if event.action == MouseRelease
            message = activate(widget, state)
            return EventResponse(
                consumed=true,
                stop_propagation=true,
                redraw=true,
                message=message,
            )
        end
        return EventResponse(
            consumed=true,
            stop_propagation=true,
            redraw=true,
            focus=routed.current,
        )
    end
end

"""Make arbitrary declarative content keyboard, pointer, and semantics actionable."""
function clickable(
    children...;
    on_click,
    label::AbstractString="Action",
    disabled::Bool=false,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
    tab_index::Integer=0,
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    widget = ClickableRegion(on_click, String(label), disabled)
    return Element(
        widget;
        key,
        id,
        children,
        layout=:stack,
        state_factory=ClickableState,
        on_event=_clickable_bubble_handler(widget),
        focusable,
        disabled,
        tab_index,
        classes,
        style_role,
        style_patch,
    )
end

clickable(build::Function; kwargs...) = clickable(build(); kwargs...)

"""Retained state for an arbitrary state-hoisted toggle region."""
mutable struct ToggleableState
    focused::Bool
    pressed::Bool
    hovered::Bool
    checked::Bool
    activations::UInt64
end

ToggleableState(checked::Bool=false) = ToggleableState(false, false, false, checked, UInt64(0))

struct ToggleableRegion{B,F}
    binding::B
    on_change::F
    label::String
    disabled::Bool
end

function _sync_toggleable!(state::ToggleableState, widget::ToggleableRegion)
    value = binding_value(widget.binding)
    value isa Bool || throw(ArgumentError("toggleable binding value must be Bool"))
    state.checked = value
    return state
end

function _invoke_toggleable(widget::ToggleableRegion, state::ToggleableState)
    widget.disabled && return nothing
    state.activations == typemax(UInt64) && throw(OverflowError("toggleable activation count exhausted"))
    value = !state.checked
    set_binding_value!(widget.binding, value)
    state.checked = value
    state.activations += UInt64(1)
    callback = widget.on_change
    callback === nothing && return nothing
    applicable(callback, value, state) && return callback(value, state)
    applicable(callback, value) && return callback(value)
    applicable(callback, state) && return callback(state)
    applicable(callback) && return callback()
    throw(ArgumentError("toggleable callback must accept value/state, value, state, or no arguments"))
end

activate(widget::ToggleableRegion, state::ToggleableState) = _invoke_toggleable(widget, state)

function handle!(state::ToggleableState, widget::ToggleableRegion, event::KeyEvent)
    widget.disabled && return false
    event.kind in (KeyPress, KeyRepeat) || return false
    return event.key.code in (:enter, :space) ||
        (event.key.code == :character && event.text == " ")
end

function handle!(state::ToggleableState, widget::ToggleableRegion, event::MouseEvent)
    widget.disabled && return false
    if event.action == MousePress && event.button == LeftMouseButton
        state.pressed = true
        return true
    elseif event.action == MouseRelease && event.button == LeftMouseButton
        state.pressed = false
        return true
    end
    return false
end

measure(::ToggleableRegion, available::Rect) = Size(available.height, available.width)
function render!(buffer::Buffer, widget::ToggleableRegion, area::Rect, state::ToggleableState)
    _sync_toggleable!(state, widget)
    return buffer
end
render!(buffer::Buffer, widget::ToggleableRegion, area::Rect) =
    render!(buffer, widget, area, ToggleableState(Bool(binding_value(widget.binding))))

SemanticToolkit.widget_semantic_descriptor(widget::ToggleableRegion, state::ToggleableState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.CheckboxRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            enabled=!widget.disabled,
            focusable=!widget.disabled,
            focused=state.focused,
            checked=state.checked ? Accessibility.CheckedValue : Accessibility.UncheckedState,
        ),
        actions=widget.disabled ? Accessibility.SemanticAction[] : [
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(:activations => state.activations, :pressed => state.pressed, :hovered => state.hovered),
    )

function _toggleable_bubble_handler(widget::ToggleableRegion)
    return function (routed, state)
        routed.phase == BubblePhase || return nothing
        event = routed.event
        event isa MouseEvent || return nothing
        handled = handle!(state, widget, event)
        handled || return nothing
        if event.action == MouseRelease
            message = activate(widget, state)
            return EventResponse(
                consumed=true,
                stop_propagation=true,
                redraw=true,
                message=message,
            )
        end
        return EventResponse(
            consumed=true,
            stop_propagation=true,
            redraw=true,
            focus=routed.current,
        )
    end
end

"""Make arbitrary content a controlled or remembered Boolean toggle surface."""
function toggleable(
    children...;
    binding::AbstractStateBinding,
    on_change=nothing,
    label::AbstractString="Toggle",
    disabled::Bool=false,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
    tab_index::Integer=0,
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    initial = binding_value(binding)
    initial isa Bool || throw(ArgumentError("toggleable binding value must be Bool"))
    widget = ToggleableRegion(binding, on_change, String(label), disabled)
    return Element(
        widget;
        key,
        id,
        children,
        layout=:stack,
        state_factory=() -> ToggleableState(initial),
        on_event=_toggleable_bubble_handler(widget),
        focusable,
        disabled,
        tab_index,
        classes,
        style_role,
        style_patch,
    )
end

toggleable(build::Function; kwargs...) = toggleable(build(); kwargs...)

"""Retained interaction state for one arbitrary-value selection surface."""
mutable struct SelectableState
    focused::Bool
    pressed::Bool
    hovered::Bool
    selected::Bool
    activations::UInt64
end

SelectableState(selected::Bool=false) = SelectableState(false, false, false, selected, UInt64(0))

struct SelectableRegion{B,V,F,E}
    binding::B
    value::V
    on_select::F
    equals::E
    label::String
    disabled::Bool
end

function _selectable_selected(widget::SelectableRegion)
    current = binding_value(widget.binding)
    applicable(widget.equals, current, widget.value) ||
        throw(ArgumentError("selectable equality must accept current and option values"))
    result = widget.equals(current, widget.value)
    result isa Bool || throw(ArgumentError("selectable equality must return Bool"))
    return result
end

function _sync_selectable!(state::SelectableState, widget::SelectableRegion)
    state.selected = _selectable_selected(widget)
    return state
end

function _invoke_selectable(widget::SelectableRegion, state::SelectableState)
    widget.disabled && return nothing
    state.activations == typemax(UInt64) && throw(OverflowError("selectable activation count exhausted"))
    set_binding_value!(widget.binding, widget.value)
    state.selected = true
    state.activations += UInt64(1)
    callback = widget.on_select
    callback === nothing && return nothing
    applicable(callback, widget.value, state) && return callback(widget.value, state)
    applicable(callback, widget.value) && return callback(widget.value)
    applicable(callback, state) && return callback(state)
    applicable(callback) && return callback()
    throw(ArgumentError("selectable callback must accept value/state, value, state, or no arguments"))
end

activate(widget::SelectableRegion, state::SelectableState) = _invoke_selectable(widget, state)

function handle!(state::SelectableState, widget::SelectableRegion, event::KeyEvent)
    widget.disabled && return false
    event.kind in (KeyPress, KeyRepeat) || return false
    return event.key.code in (:enter, :space) ||
        (event.key.code == :character && event.text == " ")
end


function handle!(state::SelectableState, widget::SelectableRegion, event::MouseEvent)
    widget.disabled && return false
    if event.action == MousePress && event.button == LeftMouseButton
        state.pressed = true
        return true
    elseif event.action == MouseRelease && event.button == LeftMouseButton
        state.pressed = false
        return true
    end
    return false
end

measure(::SelectableRegion, available::Rect) = Size(available.height, available.width)
function render!(buffer::Buffer, widget::SelectableRegion, area::Rect, state::SelectableState)
    _sync_selectable!(state, widget)
    return buffer
end
render!(buffer::Buffer, widget::SelectableRegion, area::Rect) =
    render!(buffer, widget, area, SelectableState(_selectable_selected(widget)))

SemanticToolkit.widget_semantic_descriptor(widget::SelectableRegion, state::SelectableState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.RadioRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            enabled=!widget.disabled,
            focusable=!widget.disabled,
            focused=state.focused,
            selected=state.selected,
            checked=state.selected ? Accessibility.CheckedValue : Accessibility.UncheckedState,
        ),
        actions=widget.disabled ? Accessibility.SemanticAction[] : [
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(:activations => state.activations, :pressed => state.pressed, :hovered => state.hovered),
    )

function _selectable_bubble_handler(widget::SelectableRegion)
    return function (routed, state)
        routed.phase == BubblePhase || return nothing
        event = routed.event
        event isa MouseEvent || return nothing
        handled = handle!(state, widget, event)
        handled || return nothing
        if event.action == MouseRelease
            message = activate(widget, state)
            return EventResponse(
                consumed=true,
                stop_propagation=true,
                redraw=true,
                message=message,
            )
        end
        return EventResponse(
            consumed=true,
            stop_propagation=true,
            redraw=true,
            focus=routed.current,
        )
    end
end

"""Make arbitrary content select an option value through a state binding."""
function selectable(
    children...;
    binding::AbstractStateBinding,
    value,
    on_select=nothing,
    equals=isequal,
    label::AbstractString="Option",
    disabled::Bool=false,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
    tab_index::Integer=0,
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    widget = SelectableRegion(binding, value, on_select, equals, String(label), disabled)
    initial = _selectable_selected(widget)
    return Element(
        widget;
        key,
        id,
        children,
        layout=:stack,
        state_factory=() -> SelectableState(initial),
        on_event=_selectable_bubble_handler(widget),
        focusable,
        disabled,
        tab_index,
        classes,
        style_role,
        style_patch,
    )
end


selectable(build::Function; kwargs...) = selectable(build(); kwargs...)

"""Retained pointer-presence state for arbitrary declarative content."""
mutable struct HoverableState
    hovered::Bool
    entries::UInt64
    exits::UInt64
end

HoverableState() = HoverableState(false, UInt64(0), UInt64(0))

struct HoverableRegion{F,G}
    on_enter::F
    on_exit::G
    label::String
    disabled::Bool
end

function _invoke_hover_callback(callback, state::HoverableState, hovered::Bool)
    callback === nothing && return nothing
    applicable(callback, hovered, state) && return callback(hovered, state)
    applicable(callback, hovered) && return callback(hovered)
    applicable(callback) && return callback()
    throw(ArgumentError("hover callback must accept hovered/state, hovered, or no arguments"))
end

function Toolkit._hover_transition_message(
    widget::HoverableRegion,
    state::HoverableState,
    hovered::Bool,
)
    widget.disabled && return nothing
    if hovered
        state.entries == typemax(UInt64) && throw(OverflowError("hover entry count exhausted"))
        state.entries += UInt64(1)
        return _invoke_hover_callback(widget.on_enter, state, true)
    end
    state.exits == typemax(UInt64) && throw(OverflowError("hover exit count exhausted"))
    state.exits += UInt64(1)
    return _invoke_hover_callback(widget.on_exit, state, false)
end

measure(::HoverableRegion, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, ::HoverableRegion, ::Rect, ::HoverableState) = buffer
render!(buffer::Buffer, ::HoverableRegion, ::Rect) = buffer

SemanticToolkit.widget_semantic_descriptor(widget::HoverableRegion, state::HoverableState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        state=Accessibility.SemanticState(enabled=!widget.disabled),
        metadata=Dict(
            :hovered => state.hovered,
            :entries => state.entries,
            :exits => state.exits,
        ),
    )

"""Track pointer entry and exit for arbitrary composed content.

Hover follows the routed element ancestry, so nested leaves keep their parent
region hovered and moving to a sibling produces exactly one exit and one entry.
Callback return values are emitted as Toolkit messages.
"""
function hoverable(
    children...;
    on_enter=nothing,
    on_exit=nothing,
    label::AbstractString="Hover region",
    disabled::Bool=false,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    widget = HoverableRegion(on_enter, on_exit, String(label), disabled)
    return Element(
        widget;
        key,
        id,
        children,
        layout=:stack,
        state_factory=HoverableState,
        disabled,
        classes,
        style_role,
        style_patch,
    )
end

hoverable(build::Function; kwargs...) = hoverable(build(); kwargs...)

"""Retained state for single, double, and long pointer activation."""
mutable struct CombinedClickableState
    focused::Bool
    pressed::Bool
    hovered::Bool
    pressed_at_ns::Union{Nothing,UInt64}
    activations::UInt64
    double_activations::UInt64
    long_activations::UInt64
end

CombinedClickableState() = CombinedClickableState(
    false,
    false,
    false,
    nothing,
    UInt64(0),
    UInt64(0),
    UInt64(0),
)

struct CombinedClickableRegion{F,G,H,C}
    on_click::F
    on_double_click::G
    on_long_click::H
    clock::C
    long_press_ns::UInt64
    label::String
    disabled::Bool
end

function _combined_clock(widget::CombinedClickableRegion)
    value = widget.clock()
    value isa Integer || throw(ArgumentError("combined clickable clock must return an integer nanosecond value"))
    value >= 0 || throw(ArgumentError("combined clickable clock cannot return a negative value"))
    UInt64(value)
end

function _invoke_combined_callback(callback, state::CombinedClickableState, label::AbstractString)
    callback === nothing && return nothing
    applicable(callback, state) && return callback(state)
    applicable(callback) && return callback()
    throw(ArgumentError("$label callback must accept CombinedClickableState or no arguments"))
end

function _increment_combined!(state::CombinedClickableState, kind::Symbol)
    field = kind === :double ? :double_activations : kind === :long ? :long_activations : :activations
    value = getproperty(state, field)
    value == typemax(UInt64) && throw(OverflowError("combined clickable $kind activation count exhausted"))
    setproperty!(state, field, value + UInt64(1))
    return state
end

function _activate_combined!(widget::CombinedClickableRegion, state::CombinedClickableState, kind::Symbol)
    widget.disabled && return nothing
    _increment_combined!(state, kind)
    callback = kind === :double ? widget.on_double_click :
        kind === :long ? widget.on_long_click : widget.on_click
    callback === nothing && kind !== :single && (callback = widget.on_click)
    return _invoke_combined_callback(callback, state, String(kind))
end

activate(widget::CombinedClickableRegion, state::CombinedClickableState) =
    _activate_combined!(widget, state, :single)

Toolkit._automatic_mouse_activation(::CombinedClickableRegion) = false

function handle!(state::CombinedClickableState, widget::CombinedClickableRegion, event::KeyEvent)
    widget.disabled && return false
    event.kind in (KeyPress, KeyRepeat) || return false
    return event.key.code in (:enter, :space) ||
        (event.key.code == :character && event.text == " ")
end

function handle!(state::CombinedClickableState, widget::CombinedClickableRegion, event::MouseEvent)
    return false
end

function _combined_release_kind(widget::CombinedClickableRegion, state::CombinedClickableState, event::MouseEvent)
    event.click_count > 1 && return :double
    started = state.pressed_at_ns
    started === nothing && return :single
    finished = _combined_clock(widget)
    finished >= started || return :single
    return finished - started >= widget.long_press_ns ? :long : :single
end

function _combined_clickable_bubble_handler(widget::CombinedClickableRegion)
    return function (routed, state)
        event = routed.event
        event isa MouseEvent || return nothing
        widget.disabled && return nothing
        if event.action == MousePress
            event.button == LeftMouseButton || return nothing
            state.pressed = true
            state.pressed_at_ns = _combined_clock(widget)
            return EventResponse(
                consumed=true,
                stop_propagation=true,
                redraw=true,
                focus=routed.current,
            )
        elseif event.action == MouseRelease && event.button == LeftMouseButton
            state.pressed || return nothing
            kind = _combined_release_kind(widget, state, event)
            state.pressed = false
            state.pressed_at_ns = nothing
            message = _activate_combined!(widget, state, kind)
            return EventResponse(
                consumed=true,
                stop_propagation=true,
                redraw=true,
                message=message,
            )
        end
        return nothing
    end
end

measure(::CombinedClickableRegion, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, ::CombinedClickableRegion, ::Rect, ::CombinedClickableState) = buffer
render!(buffer::Buffer, ::CombinedClickableRegion, ::Rect) = buffer

SemanticToolkit.widget_semantic_descriptor(widget::CombinedClickableRegion, state::CombinedClickableState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.ButtonRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            enabled=!widget.disabled,
            focusable=!widget.disabled,
            focused=state.focused,
        ),
        actions=widget.disabled ? Accessibility.SemanticAction[] : [
            Accessibility.FocusSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(
            :pressed => state.pressed,
            :hovered => state.hovered,
            :activations => state.activations,
            :double_activations => state.double_activations,
            :long_activations => state.long_activations,
            :long_press_ns => widget.long_press_ns,
        ),
    )

"""Make arbitrary content support single, double, and long activation gestures.

Double and long callbacks fall back to `on_click` when omitted. Long presses
are classified on pointer release using the injected monotonic `clock`.
"""
function combined_clickable(
    children...;
    on_click,
    on_double_click=nothing,
    on_long_click=nothing,
    long_press_duration::Real=0.5,
    clock=time_ns,
    label::AbstractString="Action",
    disabled::Bool=false,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
    tab_index::Integer=0,
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    isfinite(long_press_duration) && long_press_duration >= 0 ||
        throw(ArgumentError("long press duration must be finite and non-negative"))
    duration_ns = Float64(long_press_duration) * 1_000_000_000
    duration_ns <= Float64(typemax(UInt64)) ||
        throw(ArgumentError("long press duration is too large"))
    long_press_ns = round(UInt64, duration_ns)
    applicable(clock) || throw(ArgumentError("combined clickable clock must accept no arguments"))
    widget = CombinedClickableRegion(
        on_click,
        on_double_click,
        on_long_click,
        clock,
        long_press_ns,
        String(label),
        disabled,
    )
    return Element(
        widget;
        key,
        id,
        children,
        layout=:stack,
        state_factory=CombinedClickableState,
        on_event=_combined_clickable_bubble_handler(widget),
        focusable,
        disabled,
        tab_index,
        classes,
        style_role,
        style_patch,
    )
end

combined_clickable(build::Function; kwargs...) = combined_clickable(build(); kwargs...)

@enum DragGestureKind::UInt8 begin
    DragGestureStarted
    DragGestureMoved
    DragGestureEnded
    DragGestureCancelled
end

"""One declarative drag transition with signed row/column displacement."""
struct DragGesture
    kind::DragGestureKind
    origin::Position
    current::Position
    row_delta::Int
    column_delta::Int
    total_row_delta::Int
    total_column_delta::Int
end

"""Retained state for a pointer-captured declarative drag region."""
mutable struct DraggableState
    focused::Bool
    pressed::Bool
    hovered::Bool
    dragging::Bool
    origin::Union{Nothing,Position}
    current::Union{Nothing,Position}
    gestures::UInt64
end

DraggableState() = DraggableState(false, false, false, false, nothing, nothing, UInt64(0))

struct DraggableRegion{F}
    on_drag::F
    threshold::Int
    label::String
    disabled::Bool
end

function _drag_gesture(state::DraggableState, kind::DragGestureKind, position::Position)
    origin = something(state.origin, position)
    previous = something(state.current, origin)
    return DragGesture(
        kind,
        origin,
        position,
        position.row - previous.row,
        position.column - previous.column,
        position.row - origin.row,
        position.column - origin.column,
    )
end

function _invoke_drag_callback(widget::DraggableRegion, gesture::DragGesture, state::DraggableState)
    callback = widget.on_drag
    applicable(callback, gesture, state) && return callback(gesture, state)
    applicable(callback, gesture) && return callback(gesture)
    applicable(callback) && return callback()
    throw(ArgumentError("drag callback must accept DragGesture/state, DragGesture, or no arguments"))
end

function _emit_drag!(widget::DraggableRegion, state::DraggableState, gesture::DragGesture)
    state.gestures == typemax(UInt64) && throw(OverflowError("drag gesture count exhausted"))
    state.gestures += UInt64(1)
    return _invoke_drag_callback(widget, gesture, state)
end

function _reset_draggable!(state::DraggableState)
    state.pressed = false
    state.dragging = false
    state.origin = nothing
    state.current = nothing
    return state
end

function _draggable_event_handler(widget::DraggableRegion)
    return function (routed, state)
        widget.disabled && return nothing
        event = routed.event
        if event isa MouseEvent && event.button == LeftMouseButton
            if event.action == MousePress
                state.pressed = true
                state.dragging = false
                state.origin = event.position
                state.current = event.position
                return EventResponse(
                    consumed=true,
                    stop_propagation=true,
                    redraw=true,
                    focus=routed.current,
                    pointer_capture=routed.current,
                )
            elseif event.action == MouseDrag && state.pressed
                origin = something(state.origin, event.position)
                distance = max(
                    abs(event.position.row - origin.row),
                    abs(event.position.column - origin.column),
                )
                state.dragging || distance >= widget.threshold || return EventResponse(consumed=true)
                kind = state.dragging ? DragGestureMoved : DragGestureStarted
                gesture = _drag_gesture(state, kind, event.position)
                state.dragging = true
                state.current = event.position
                message = _emit_drag!(widget, state, gesture)
                return EventResponse(
                    consumed=true,
                    stop_propagation=true,
                    redraw=true,
                    message=message,
                )
            elseif event.action == MouseRelease && (state.pressed || state.dragging)
                message = nothing
                if state.dragging
                    gesture = _drag_gesture(state, DragGestureEnded, event.position)
                    state.current = event.position
                    message = _emit_drag!(widget, state, gesture)
                end
                _reset_draggable!(state)
                return EventResponse(
                    consumed=true,
                    stop_propagation=true,
                    redraw=true,
                    message=message,
                    pointer_capture=:release,
                )
            end
        elseif event isa KeyEvent && event.key.code == :escape && (state.pressed || state.dragging)
            position = something(state.current, something(state.origin, Position(1, 1)))
            gesture = _drag_gesture(state, DragGestureCancelled, position)
            message = _emit_drag!(widget, state, gesture)
            _reset_draggable!(state)
            return EventResponse(
                consumed=true,
                stop_propagation=true,
                redraw=true,
                message=message,
                pointer_capture=:release,
            )
        end
        return nothing
    end
end

measure(::DraggableRegion, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, ::DraggableRegion, ::Rect, ::DraggableState) = buffer
render!(buffer::Buffer, ::DraggableRegion, ::Rect) = buffer
Toolkit._automatic_mouse_activation(::DraggableRegion) = false

SemanticToolkit.widget_semantic_descriptor(widget::DraggableRegion, state::DraggableState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            enabled=!widget.disabled,
            focusable=!widget.disabled,
            focused=state.focused,
        ),
        actions=widget.disabled ? Accessibility.SemanticAction[] : [Accessibility.FocusSemanticAction],
        metadata=Dict(
            :draggable => true,
            :dragging => state.dragging,
            :pressed => state.pressed,
            :hovered => state.hovered,
            :gestures => state.gestures,
        ),
    )

"""Make arbitrary declarative content a pointer-captured drag source."""
function draggable(
    children...;
    on_drag,
    threshold::Integer=1,
    label::AbstractString="Draggable content",
    disabled::Bool=false,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=true,
    tab_index::Integer=0,
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    threshold >= 0 || throw(ArgumentError("drag threshold cannot be negative"))
    widget = DraggableRegion(on_drag, Int(threshold), String(label), disabled)
    handler = _draggable_event_handler(widget)
    return Element(
        widget;
        key,
        id,
        children,
        layout=:stack,
        state_factory=DraggableState,
        on_event=handler,
        focusable,
        disabled,
        tab_index,
        classes,
        style_role,
        style_patch,
    )
end

draggable(build::Function; kwargs...) = draggable(build(); kwargs...)

"""Composition-local owner for declarative payload drag/drop."""
struct DragDropContext
    router::ToolkitDragRouter
end

const DragDropLocal = composition_local(
    :drag_drop_router,
    nothing;
    value_type=Union{Nothing,DragDropContext},
)

drag_drop_provider(
    router::ToolkitDragRouter,
    children...;
    kwargs...,
) = provide_context(DragDropLocal => DragDropContext(router); children, kwargs...)

drag_drop_provider(build::Function, router::ToolkitDragRouter; kwargs...) =
    drag_drop_provider(router, build(); kwargs...)

function _drag_drop_router(state::ComponentState)
    context = composition_value(state, DragDropLocal)
    context === nothing && throw(ArgumentError(
        "declarative drag/drop requires a drag_drop_provider ancestor",
    ))
    return context.router
end

mutable struct DragSourceState
    focused::Bool
    pressed::Bool
    hovered::Bool
    dragging::Bool
end

DragSourceState() = DragSourceState(false, false, false, false)

struct DragSourceRegion{P}
    router::ToolkitDragRouter
    source_id::String
    payload::P
    label::String
    disabled::Bool
end

function _router_messages(router::ToolkitDragRouter, extra=nothing)
    dispatch = route_toolkit_drag_events!(router)
    isempty(dispatch.errors) || throw(first(dispatch.errors)[2])
    values = copy(dispatch.messages)
    extra === nothing || push!(values, extra)
    return EventMessages(values)
end

function _drag_source_handler(widget::DragSourceRegion)
    return function (routed, state)
        widget.disabled && return nothing
        event = routed.event
        if event isa MouseEvent && event.button == LeftMouseButton
            point = drag_point_from_event(event)
            if event.action == MousePress
                begin_toolkit_drag!(widget.router, widget.source_id, widget.payload, point)
                state.pressed = true
                state.dragging = false
                return EventResponse(
                    consumed=true,
                    stop_propagation=true,
                    redraw=true,
                    focus=routed.current,
                    pointer_capture=routed.current,
                )
            elseif event.action == MouseDrag && state.pressed
                update_toolkit_drag!(widget.router, point)
                state.dragging = widget.router.manager.phase == Dragging
                return EventResponse(
                    consumed=true,
                    stop_propagation=true,
                    redraw=true,
                    message=_router_messages(widget.router),
                )
            elseif event.action == MouseRelease && (state.pressed || state.dragging)
                result, drop_message = drop_toolkit_drag!(widget.router, point)
                state.pressed = false
                state.dragging = false
                return EventResponse(
                    consumed=true,
                    stop_propagation=true,
                    redraw=true,
                    message=_router_messages(widget.router, drop_message),
                    pointer_capture=:release,
                )
            end
        elseif event isa KeyEvent && event.key.code == :escape && (state.pressed || state.dragging)
            cancel_toolkit_drag!(widget.router)
            state.pressed = false
            state.dragging = false
            return EventResponse(
                consumed=true,
                stop_propagation=true,
                redraw=true,
                message=_router_messages(widget.router),
                pointer_capture=:release,
            )
        end
        return nothing
    end
end

measure(::DragSourceRegion, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, ::DragSourceRegion, ::Rect, ::DragSourceState) = buffer
render!(buffer::Buffer, ::DragSourceRegion, ::Rect) = buffer
Toolkit._automatic_mouse_activation(::DragSourceRegion) = false

SemanticToolkit.widget_semantic_descriptor(widget::DragSourceRegion, state::DragSourceState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            enabled=!widget.disabled,
            focusable=!widget.disabled,
            focused=state.focused,
        ),
        actions=widget.disabled ? Accessibility.SemanticAction[] : [Accessibility.FocusSemanticAction],
        metadata=Dict(
            :drag_source => true,
            :source_id => widget.source_id,
            :mime => widget.payload.mime,
            :dragging => state.dragging,
            :pressed => state.pressed,
            :hovered => state.hovered,
        ),
    )

function drag_source(
    children...;
    id,
    payload::DragPayload,
    label::AbstractString="Drag source",
    disabled::Bool=false,
    key=nothing,
    classes=Symbol[],
    focusable::Bool=true,
    tab_index::Integer=0,
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    return component(key=key) do component_state
        router = _drag_drop_router(component_state)
        widget = DragSourceRegion(router, string(id), payload, String(label), disabled)
        Element(
            widget;
            id,
            children,
            layout=:stack,
            state_factory=DragSourceState,
            on_event=_drag_source_handler(widget),
            focusable,
            disabled,
            tab_index,
            classes,
            style_role,
            style_patch,
        )
    end
end

drag_source(build::Function; kwargs...) = drag_source(build(); kwargs...)

mutable struct DropTargetState
    router::ToolkitDragRouter
    target_id::String
    registered::Bool
    config::Any
    handler::Any
    hovered::Bool
    drops::UInt64
end

struct DropTargetRegion
    router::ToolkitDragRouter
    target_id::String
    accepted_mime_prefixes::Vector{String}
    accepted_effects::Set{DragEffect}
    preferred_effect::DragEffect
    priority::Int
    enabled::Bool
    handler::Any
    label::String
end

function _invoke_declarative_drop(state::DropTargetState, result::DropResult)
    state.drops == typemax(UInt64) && throw(OverflowError("drop target count exhausted"))
    state.drops += UInt64(1)
    callback = state.handler
    applicable(callback, result, state) && return callback(result, state)
    applicable(callback, result) && return callback(result)
    applicable(callback) && return callback()
    throw(ArgumentError("drop callback must accept DropResult/state, DropResult, or no arguments"))
end

function _drop_target_config(widget::DropTargetRegion)
    return (
        widget.accepted_mime_prefixes,
        widget.accepted_effects,
        widget.preferred_effect,
        widget.priority,
    )
end

function render!(buffer::Buffer, widget::DropTargetRegion, area::Rect, state::DropTargetState)
    if state.router !== widget.router || state.target_id != widget.target_id
        state.registered && unregister_toolkit_drop_target!(state.router, state.target_id)
        state.router = widget.router
        state.target_id = widget.target_id
        state.registered = false
        state.config = nothing
    end
    state.handler = widget.handler
    config = _drop_target_config(widget)
    rect = ComponentRect(area.row, area.column, area.width, area.height)
    if !state.registered || !isequal(state.config, config)
        state.registered && unregister_toolkit_drop_target!(state.router, state.target_id)
        register_toolkit_drop_target!(
            state.router,
            widget.target_id,
            rect,
            result -> _invoke_declarative_drop(state, result);
            target_id=widget.target_id,
            accepted_mime_prefixes=widget.accepted_mime_prefixes,
            accepted_effects=widget.accepted_effects,
            preferred_effect=widget.preferred_effect,
            priority=widget.priority,
            enabled=widget.enabled,
        )
        state.registered = true
        state.config = config
    else
        sync_toolkit_drop_target!(state.router, widget.target_id, rect; enabled=widget.enabled)
    end
    active = active_drop_target(state.router.manager)
    state.hovered = active !== nothing && active.id == widget.target_id
    return buffer
end

render!(buffer::Buffer, widget::DropTargetRegion, area::Rect) = buffer
measure(::DropTargetRegion, available::Rect) = Size(available.height, available.width)

SemanticToolkit.widget_semantic_descriptor(widget::DropTargetRegion, state::DropTargetState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        state=Accessibility.SemanticState(enabled=widget.enabled),
        metadata=Dict(
            :drop_target => true,
            :target_id => widget.target_id,
            :hovered => state.hovered,
            :drops => state.drops,
            :preferred_effect => widget.preferred_effect,
        ),
    )

function drop_target(
    children...;
    id,
    on_drop,
    target_id=id,
    accepted_mime_prefixes=("",),
    accepted_effects=(CopyDragEffect,),
    preferred_effect::DragEffect=CopyDragEffect,
    priority::Integer=0,
    enabled::Bool=true,
    key=nothing,
    label::AbstractString="Drop target",
    classes=Symbol[],
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    return component(key=key) do component_state
        router = _drag_drop_router(component_state)
        identifier = string(target_id)
        widget = DropTargetRegion(
            router,
            identifier,
            String[lowercase(String(prefix)) for prefix in accepted_mime_prefixes],
            Set{DragEffect}(accepted_effects),
            preferred_effect,
            Int(priority),
            enabled,
            on_drop,
            String(label),
        )
        Element(
            widget;
            id,
            children,
            layout=:stack,
            state_factory=() -> DropTargetState(
                router,
                identifier,
                false,
                nothing,
                on_drop,
                false,
                UInt64(0),
            ),
            on_unmount=state -> begin
                state.registered && unregister_toolkit_drop_target!(state.router, state.target_id)
                state.registered = false
            end,
            disabled=!enabled,
            classes,
            style_role,
            style_patch,
        )
    end
end

drop_target(build::Function; kwargs...) = drop_target(build(); kwargs...)

"""Retained diagnostics for one declarative key-input region."""
mutable struct KeyInputState
    focused::Bool
    events::UInt64
    last_event::Union{Nothing,KeyEvent}
end

KeyInputState() = KeyInputState(false, UInt64(0), nothing)

struct KeyInputRegion{F}
    on_key::F
    preview::Bool
    key_codes::Union{Nothing,Set{Symbol}}
    kinds::Union{Nothing,Set{Events.KeyEventKind}}
    modifiers::Union{Nothing,KeyModifiers}
    label::String
    disabled::Bool
end

function _key_input_matches(widget::KeyInputRegion, event::KeyEvent)
    widget.key_codes === nothing || event.key.code in widget.key_codes || return false
    widget.kinds === nothing || event.kind in widget.kinds || return false
    widget.modifiers === nothing || event.modifiers == widget.modifiers || return false
    return true
end

function _invoke_key_input(widget::KeyInputRegion, event::KeyEvent, state::KeyInputState)
    state.events == typemax(UInt64) && throw(OverflowError("key input event count exhausted"))
    state.events += UInt64(1)
    state.last_event = event
    callback = widget.on_key
    applicable(callback, event, state) && return callback(event, state)
    applicable(callback, event) && return callback(event)
    applicable(callback) && return callback()
    throw(ArgumentError("key input callback must accept KeyEvent/state, KeyEvent, or no arguments"))
end

function _key_input_handler(widget::KeyInputRegion)
    return function (routed, state)
        widget.disabled && return nothing
        event = routed.event
        event isa KeyEvent || return nothing
        expected = widget.preview ? CapturePhase : routed.target == routed.current ? TargetPhase : BubblePhase
        routed.phase == expected || return nothing
        _key_input_matches(widget, event) || return nothing
        return _invoke_key_input(widget, event, state)
    end
end

measure(::KeyInputRegion, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, ::KeyInputRegion, ::Rect, ::KeyInputState) = buffer
render!(buffer::Buffer, ::KeyInputRegion, ::Rect) = buffer

SemanticToolkit.widget_semantic_descriptor(widget::KeyInputRegion, state::KeyInputState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            enabled=!widget.disabled,
            focusable=!widget.disabled,
            focused=state.focused,
        ),
        metadata=Dict(
            :key_input => true,
            :preview => widget.preview,
            :events => state.events,
            :last_key => state.last_event === nothing ? nothing : state.last_event.key.code,
        ),
    )

function _key_input_region(
    children...;
    on_key,
    preview::Bool,
    keys=nothing,
    kinds=nothing,
    modifiers::Union{Nothing,KeyModifiers}=nothing,
    label::AbstractString=preview ? "Preview key input" : "Key input",
    disabled::Bool=false,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=false,
    tab_index::Integer=0,
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    key_values = keys isa Union{Symbol,Key} ? (keys,) : keys
    key_codes = key_values === nothing ? nothing : Set{Symbol}(
        value isa Key ? value.code : Symbol(value) for value in key_values
    )
    kind_values = kinds isa Events.KeyEventKind ? (kinds,) : kinds
    event_kinds = kind_values === nothing ? nothing : Set{Events.KeyEventKind}(kind_values)
    widget = KeyInputRegion(
        on_key,
        preview,
        key_codes,
        event_kinds,
        modifiers,
        String(label),
        disabled,
    )
    handler = _key_input_handler(widget)
    return Element(
        widget;
        key,
        id,
        children,
        layout=:stack,
        state_factory=KeyInputState,
        on_capture=preview ? handler : (event, state) -> nothing,
        on_event=preview ? (event, state) -> nothing : handler,
        focusable,
        disabled,
        tab_index,
        classes,
        style_role,
        style_patch,
    )
end

"""Handle matching key events at target/bubble time around arbitrary content."""
key_input(children...; kwargs...) = _key_input_region(children...; preview=false, kwargs...)
key_input(build::Function; kwargs...) = key_input(build(); kwargs...)

"""Preview matching key events during root-to-target capture."""
preview_key_input(children...; kwargs...) = _key_input_region(children...; preview=true, kwargs...)
preview_key_input(build::Function; kwargs...) = preview_key_input(build(); kwargs...)

"""Retained diagnostics for one declarative pointer-input region."""
mutable struct PointerInputState
    focused::Bool
    hovered::Bool
    pressed::Bool
    events::UInt64
    last_event::Union{Nothing,MouseEvent}
end

PointerInputState() = PointerInputState(false, false, false, UInt64(0), nothing)

struct PointerInputRegion{F}
    on_pointer::F
    preview::Bool
    actions::Union{Nothing,Set{MouseAction}}
    buttons::Union{Nothing,Set{MouseButton}}
    modifiers::Union{Nothing,KeyModifiers}
    capture_on_press::Bool
    label::String
    disabled::Bool
end

function _pointer_input_matches(widget::PointerInputRegion, event::MouseEvent)
    widget.actions === nothing || event.action in widget.actions || return false
    widget.buttons === nothing || event.button in widget.buttons || return false
    widget.modifiers === nothing || event.modifiers == widget.modifiers || return false
    return true
end

function _invoke_pointer_input(widget::PointerInputRegion, event::MouseEvent, state::PointerInputState)
    state.events == typemax(UInt64) && throw(OverflowError("pointer input event count exhausted"))
    state.events += UInt64(1)
    state.last_event = event
    event.action == MousePress && event.button == LeftMouseButton && (state.pressed = true)
    event.action == MouseRelease && (state.pressed = false)
    callback = widget.on_pointer
    applicable(callback, event, state) && return callback(event, state)
    applicable(callback, event) && return callback(event)
    applicable(callback) && return callback()
    throw(ArgumentError("pointer input callback must accept MouseEvent/state, MouseEvent, or no arguments"))
end

function _pointer_capture_response(value, target)
    response = Toolkit._normalize_response(value)
    response.pointer_capture !== nothing && return response
    return EventResponse(
        consumed=response.consumed,
        stop_propagation=response.stop_propagation,
        redraw=response.redraw,
        message=response.message,
        focus=response.focus,
        pointer_capture=target,
    )
end

function _pointer_input_handler(widget::PointerInputRegion)
    return function (routed, state)
        widget.disabled && return nothing
        event = routed.event
        event isa MouseEvent || return nothing
        expected = widget.preview ? CapturePhase : routed.target == routed.current ? TargetPhase : BubblePhase
        routed.phase == expected || return nothing
        _pointer_input_matches(widget, event) || return nothing
        result = _invoke_pointer_input(widget, event, state)
        if widget.capture_on_press && event.action == MousePress
            return _pointer_capture_response(result, routed.current)
        end
        return result
    end
end

measure(::PointerInputRegion, available::Rect) = Size(available.height, available.width)
render!(buffer::Buffer, ::PointerInputRegion, ::Rect, ::PointerInputState) = buffer
render!(buffer::Buffer, ::PointerInputRegion, ::Rect) = buffer
Toolkit._automatic_mouse_activation(::PointerInputRegion) = false

SemanticToolkit.widget_semantic_descriptor(widget::PointerInputRegion, state::PointerInputState) =
    SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            enabled=!widget.disabled,
            focusable=!widget.disabled,
            focused=state.focused,
        ),
        metadata=Dict(
            :pointer_input => true,
            :preview => widget.preview,
            :capture_on_press => widget.capture_on_press,
            :hovered => state.hovered,
            :pressed => state.pressed,
            :events => state.events,
            :last_action => state.last_event === nothing ? nothing : state.last_event.action,
        ),
    )

function _pointer_input_region(
    children...;
    on_pointer,
    preview::Bool,
    actions=nothing,
    buttons=nothing,
    modifiers::Union{Nothing,KeyModifiers}=nothing,
    capture_on_press::Bool=false,
    label::AbstractString=preview ? "Preview pointer input" : "Pointer input",
    disabled::Bool=false,
    key=nothing,
    id=nothing,
    classes=Symbol[],
    focusable::Bool=false,
    tab_index::Integer=0,
    style_role::Union{Nothing,Symbol}=nothing,
    style_patch::StylePatch=StylePatch(),
)
    preview && capture_on_press && throw(ArgumentError(
        "preview pointer input cannot capture itself; use a normal pointer_input region",
    ))
    action_values = actions isa MouseAction ? (actions,) : actions
    action_set = action_values === nothing ? nothing : Set{MouseAction}(action_values)
    button_values = buttons isa MouseButton ? (buttons,) : buttons
    button_set = button_values === nothing ? nothing : Set{MouseButton}(button_values)
    widget = PointerInputRegion(
        on_pointer,
        preview,
        action_set,
        button_set,
        modifiers,
        capture_on_press,
        String(label),
        disabled,
    )
    handler = _pointer_input_handler(widget)
    return Element(
        widget;
        key,
        id,
        children,
        layout=:stack,
        state_factory=PointerInputState,
        on_capture=preview ? handler : (event, state) -> nothing,
        on_event=preview ? (event, state) -> nothing : handler,
        focusable,
        disabled,
        tab_index,
        classes,
        style_role,
        style_patch,
    )
end

"""Handle matching pointer events at target/bubble time around arbitrary content."""
pointer_input(children...; kwargs...) = _pointer_input_region(children...; preview=false, kwargs...)
pointer_input(build::Function; kwargs...) = pointer_input(build(); kwargs...)

"""Preview matching pointer events during root-to-target capture."""
preview_pointer_input(children...; kwargs...) = _pointer_input_region(children...; preview=true, kwargs...)
preview_pointer_input(build::Function; kwargs...) = preview_pointer_input(build(); kwargs...)
