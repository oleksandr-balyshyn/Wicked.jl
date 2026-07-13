module SemanticToolkit

using ..Accessibility: SemanticRole,
                       ApplicationRole,
                       GenericRole,
                       GroupRole,
                       ButtonRole,
                       CheckboxRole,
                       RadioRole,
                       TextboxRole,
                       ListRole,
                       ListItemRole,
                       TableRole,
                       RowRole,
                       CellRole,
                       TabListRole,
                       TabRole,
                       TreeRole,
                       TreeItemRole,
                       MenuRole,
                       MenuItemRole,
                       SliderRole,
                       ScrollbarRole,
                       NotCheckable,
                       CheckedState,
                       UncheckedState,
                       CheckedValue,
                       SemanticRect,
                       SemanticState,
                       SemanticAction,
                       ActivateSemanticAction,
                       FocusSemanticAction,
                       SetValueSemanticAction,
                       SelectSemanticAction,
                       DismissSemanticAction,
                       ExpandSemanticAction,
                       CollapseSemanticAction,
                       IncrementSemanticAction,
                       DecrementSemanticAction,
                       ScrollIntoViewSemanticAction,
                       SemanticNode,
                       SemanticTree,
                       SemanticDiagnostic,
                       validate_semantics,
                       semantic_nodes,
                       semantic_node,
                       diff_semantics,
                       SemanticChange,
                       SemanticActionRequest,
                       SemanticActionResult,
                       SemanticDispatcher,
                       register_semantic_handler!,
                       dispatch_semantic_action!,
                       AnnouncementQueue,
                       take_announcements!,
                       semantic_snapshot
using ..Interaction: focused
using ..Toolkit: ToolkitTree,
                 ElementPath,
                 element_path_components
using ..Widgets: Button,
                 ButtonState,
                 PushButton,
                 PushButtonState,
                 CheckBox,
                 CheckBoxState,
                 Checkbox,
                 CheckboxState,
                 Switch,
                 SwitchState,
                 Toggle,
                 ToggleState,
                 Input,
                 InputState,
                 TextBox,
                 TextBoxState,
                 TextField,
                 TextFieldState,
                 TextInput,
                 TextInputState,
                 PasswordField,
                 PasswordFieldState,
                 PasswordInput,
                 SearchInput,
                 TextArea,
                 TextAreaState,
                 Textarea,
                 ListView,
                 ListViewState,
                 OptionList,
                 OptionListState,
                 RadioBoxList,
                 RadioBoxListState,
                 RadioGroup,
                 RadioGroupState,
                 RadioSet,
                 RadioSetState,
                 Select,
                 SelectState,
                 CheckBoxList,
                 CheckBoxListState,
                 MultiSelect,
                 MultiSelectState,
                 SelectionList,
                 SelectionListState,
                 List,
                 ListState,
                 Table,
                 TableState,
                 Tabs,
                 TabsState,
                 selected_tab,
                 select_tab!,
                 Tree,
                 TreeState,
                 TreeView,
                 TreeViewState,
                 TreeNode,
                 Menu,
                 MenuState,
                 select_menu_item!,
                 selected_menu_item,
                 selected_menu_message,
                 ScrollView,
                 ScrollState,
                 NumberInput,
                 NumberInputState,
                 increment_number_input!,
                 number_input_value,
                 set_number_text!,
                 set_number_value!,
                 editing_text,
                 set_text!

export SemanticDescriptor,
       RoleRegistry,
       register_role_factory!,
       unregister_role_factory!,
       semantic_descriptor,
       widget_semantic_descriptor,
       widget_semantic_children,
       register_menu_semantic_handlers!,
       register_tabs_semantic_handlers!,
       register_button_semantic_handlers!,
       register_push_button_semantic_handlers!,
       register_text_input_semantic_handlers!,
       register_input_semantic_handlers!,
       register_text_box_semantic_handlers!,
       register_text_field_semantic_handlers!,
       register_password_input_semantic_handlers!,
       register_password_field_semantic_handlers!,
       register_search_input_semantic_handlers!,
       register_number_input_semantic_handlers!,
       register_text_area_semantic_handlers!,
       register_textarea_semantic_handlers!,
       toolkit_semantic_tree,
       SemanticBuilder,
       SemanticBuildError,
       begin_semantic_tree!,
       push_semantic_node!,
       pop_semantic_node!,
       with_semantic_node,
       finish_semantic_tree!,
       abort_semantic_tree!,
       SemanticQuery,
       SemanticQueryError,
       query_semantics,
       query_one_semantic,
       SemanticPilot,
       refresh_semantic_pilot!,
       perform_semantic_action!,
       take_semantic_announcements!,
       semantic_pilot_snapshot

struct SemanticDescriptor
    role::SemanticRole
    label::String
    description::Union{Nothing,String}
    state::SemanticState
    actions::Set{SemanticAction}
    metadata::Dict{Symbol,Any}

    function SemanticDescriptor(
        role::SemanticRole=GenericRole;
        label::AbstractString="",
        description::Union{Nothing,AbstractString}=nothing,
        state::SemanticState=SemanticState(),
        actions=SemanticAction[],
        metadata=Dict{Symbol,Any}(),
    )
        new(
            role,
            String(label),
            description === nothing ? nothing : String(description),
            state,
            Set{SemanticAction}(actions),
            Dict{Symbol,Any}(Symbol(key) => value for (key, value) in pairs(metadata)),
        )
    end
end

mutable struct RoleRegistry
    factories::Dict{Any,Any}
end

RoleRegistry() = RoleRegistry(Dict{Any,Any}())

function register_role_factory!(registry::RoleRegistry, key, factory)
    registry.factories[key] = factory
    return registry
end

function unregister_role_factory!(registry::RoleRegistry, key)
    pop!(registry.factories, key, nothing)
    return registry
end

function semantic_descriptor(registry::RoleRegistry, key, value)
    factory = get(registry.factories, key, nothing)
    factory === nothing && return SemanticDescriptor()
    applicable(factory, value) || throw(ArgumentError("semantic role factory is not applicable to the supplied value"))
    descriptor = factory(value)
    descriptor isa SemanticDescriptor || throw(ArgumentError("semantic role factory must return SemanticDescriptor"))
    return descriptor
end

_line_text(line) = join(span.content for span in line.spans)

"""Return the semantic descriptor for an immediate widget and its retained state."""
widget_semantic_descriptor(widget, state) = SemanticDescriptor(GenericRole)
widget_semantic_descriptor(::Nothing, state) = SemanticDescriptor(GroupRole)

function widget_semantic_descriptor(widget::Button, state::ButtonState)
    enabled = !widget.disabled
    return SemanticDescriptor(
        ButtonRole;
        label=_line_text(widget.label),
        state=SemanticState(enabled=enabled, focusable=enabled, focused=state.focused),
        actions=enabled ? [ActivateSemanticAction, FocusSemanticAction] : SemanticAction[],
    )
end

function _register_button_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    state::ButtonState,
    label::AbstractString,
    message,
    disabled::Bool,
)
    register_semantic_handler!(dispatcher, string(id), function (request)
        if disabled
            return SemanticActionResult(false; message="button is disabled")
        elseif request.action == FocusSemanticAction
            state.focused = true
            return SemanticActionResult(true; value=Dict{Symbol,Any}(:label => String(label), :focused => true))
        elseif request.action == ActivateSemanticAction
            state.pressed = false
            return SemanticActionResult(true; value=message)
        end
        return SemanticActionResult(false; message="button semantic action is not supported")
    end)
    return dispatcher
end

register_button_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::Button,
    state::ButtonState,
) =
    _register_button_semantic_handlers!(
        dispatcher,
        id,
        state,
        _line_text(widget.label),
        widget.message,
        widget.disabled,
    )

function widget_semantic_descriptor(widget::PushButton, state::PushButtonState)
    return widget_semantic_descriptor(widget.button, state)
end

register_push_button_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::PushButton,
    state::PushButtonState,
) =
    _register_button_semantic_handlers!(
        dispatcher,
        id,
        state,
        _line_text(widget.button.label),
        widget.button.message,
        widget.button.disabled,
    )

function widget_semantic_descriptor(widget::Checkbox, state::CheckboxState)
    return SemanticDescriptor(
        CheckboxRole;
        label=_line_text(widget.label),
        state=SemanticState(focusable=true, checked=state.checked ? CheckedValue : UncheckedState),
        actions=[ActivateSemanticAction, FocusSemanticAction, SetValueSemanticAction],
    )
end

function widget_semantic_descriptor(widget::CheckBox, state::CheckBoxState)
    return widget_semantic_descriptor(widget.checkbox, state)
end

function widget_semantic_descriptor(widget::Toggle, state::ToggleState)
    return SemanticDescriptor(
        CheckboxRole;
        label=state.enabled ? widget.on_label : widget.off_label,
        state=SemanticState(focusable=true, checked=state.enabled ? CheckedValue : UncheckedState),
        actions=[ActivateSemanticAction, FocusSemanticAction, SetValueSemanticAction],
    )
end

function widget_semantic_descriptor(widget::Switch, state::SwitchState)
    return SemanticDescriptor(
        CheckboxRole;
        label=state.enabled ? widget.toggle.on_label : widget.toggle.off_label,
        state=SemanticState(focusable=true, checked=state.enabled ? CheckedValue : UncheckedState),
        actions=[ActivateSemanticAction, FocusSemanticAction, SetValueSemanticAction],
    )
end

function widget_semantic_descriptor(widget::TextInput, state::TextInputState)
    protected = widget.mask !== nothing
    return SemanticDescriptor(
        TextboxRole;
        label=isempty(widget.placeholder) ? "Text input" : widget.placeholder,
        state=SemanticState(
            focusable=true,
            focused=state.focused,
            value=protected ? nothing : editing_text(state.editing),
        ),
        actions=[FocusSemanticAction, SetValueSemanticAction],
        metadata=Dict(:protected => protected),
    )
end

function _text_input_semantic_value(
    label::AbstractString,
    state::TextInputState;
    protected::Bool=false,
    metadata::Dict{Symbol,Any}=Dict{Symbol,Any}(),
)
    return merge(
        Dict{Symbol,Any}(
            :label => String(label),
            :value => protected ? nothing : editing_text(state),
            :focused => state.focused,
            :protected => protected,
        ),
        metadata,
    )
end

function _register_text_input_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    state::TextInputState,
    label::AbstractString;
    protected::Bool=false,
    metadata::Dict{Symbol,Any}=Dict{Symbol,Any}(),
)
    register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action == FocusSemanticAction
            state.focused = true
            return SemanticActionResult(true; value=_text_input_semantic_value(label, state; protected, metadata))
        elseif request.action == SetValueSemanticAction
            set_text!(state, string(request.value))
            return SemanticActionResult(true; value=_text_input_semantic_value(label, state; protected, metadata))
        end
        return SemanticActionResult(false; message="text input semantic action is not supported")
    end)
    return dispatcher
end

register_text_input_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::TextInput,
    state::TextInputState,
) =
    _register_text_input_semantic_handlers!(
        dispatcher,
        id,
        state,
        isempty(widget.placeholder) ? "Text input" : widget.placeholder;
        protected=widget.mask !== nothing,
        metadata=Dict{Symbol,Any}(:protected => widget.mask !== nothing),
    )

function widget_semantic_descriptor(widget::Input, state::InputState)
    descriptor = widget_semantic_descriptor(widget.input, state)
    return SemanticDescriptor(
        descriptor.role;
        label=descriptor.label,
        state=descriptor.state,
        actions=descriptor.actions,
        metadata=merge(descriptor.metadata, Dict(:input => true)),
    )
end

register_input_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::Input,
    state::InputState,
) =
    _register_text_input_semantic_handlers!(
        dispatcher,
        id,
        state,
        isempty(widget.input.placeholder) ? "Text input" : widget.input.placeholder;
        protected=widget.input.mask !== nothing,
        metadata=Dict{Symbol,Any}(:protected => widget.input.mask !== nothing, :input => true),
    )

function widget_semantic_descriptor(widget::TextBox, state::TextBoxState)
    descriptor = widget_semantic_descriptor(widget.input, state)
    return SemanticDescriptor(
        descriptor.role;
        label=descriptor.label,
        state=descriptor.state,
        actions=descriptor.actions,
        metadata=merge(descriptor.metadata, Dict(:text_box => true)),
    )
end

register_text_box_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::TextBox,
    state::TextBoxState,
) =
    _register_text_input_semantic_handlers!(
        dispatcher,
        id,
        state,
        isempty(widget.input.placeholder) ? "Text input" : widget.input.placeholder;
        protected=widget.input.mask !== nothing,
        metadata=Dict{Symbol,Any}(:protected => widget.input.mask !== nothing, :text_box => true),
    )

function widget_semantic_descriptor(widget::TextField, state::TextFieldState)
    descriptor = widget_semantic_descriptor(widget.input, state)
    return SemanticDescriptor(
        descriptor.role;
        label=descriptor.label,
        state=descriptor.state,
        actions=descriptor.actions,
        metadata=merge(descriptor.metadata, Dict(:text_field => true)),
    )
end

register_text_field_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::TextField,
    state::TextFieldState,
) =
    _register_text_input_semantic_handlers!(
        dispatcher,
        id,
        state,
        isempty(widget.input.placeholder) ? "Text input" : widget.input.placeholder;
        protected=widget.input.mask !== nothing,
        metadata=Dict{Symbol,Any}(:protected => widget.input.mask !== nothing, :text_field => true),
    )

function widget_semantic_descriptor(widget::SearchInput, state::TextInputState)
    descriptor = widget_semantic_descriptor(widget.input, state)
    return SemanticDescriptor(
        descriptor.role;
        label=isempty(widget.input.placeholder) ? "Search" : widget.input.placeholder,
        state=descriptor.state,
        actions=descriptor.actions,
        metadata=merge(descriptor.metadata, Dict(:search => true)),
    )
end

register_search_input_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::SearchInput,
    state::TextInputState,
) =
    _register_text_input_semantic_handlers!(
        dispatcher,
        id,
        state,
        isempty(widget.input.placeholder) ? "Search" : widget.input.placeholder;
        protected=widget.input.mask !== nothing,
        metadata=Dict{Symbol,Any}(:protected => widget.input.mask !== nothing, :search => true),
    )

function widget_semantic_descriptor(widget::PasswordInput, state::TextInputState)
    descriptor = widget_semantic_descriptor(widget.input, state)
    return SemanticDescriptor(
        descriptor.role;
        label=isempty(widget.input.placeholder) ? "Password" : widget.input.placeholder,
        state=descriptor.state,
        actions=descriptor.actions,
        metadata=merge(descriptor.metadata, Dict(:password => true, :protected => true)),
    )
end

register_password_input_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::PasswordInput,
    state::TextInputState,
) =
    _register_text_input_semantic_handlers!(
        dispatcher,
        id,
        state,
        isempty(widget.input.placeholder) ? "Password" : widget.input.placeholder;
        protected=true,
        metadata=Dict{Symbol,Any}(:password => true, :protected => true),
    )

function widget_semantic_descriptor(widget::PasswordField, state::PasswordFieldState)
    descriptor = widget_semantic_descriptor(widget.input, state)
    return SemanticDescriptor(
        descriptor.role;
        label=descriptor.label,
        state=descriptor.state,
        actions=descriptor.actions,
        metadata=merge(descriptor.metadata, Dict(:password_field => true)),
    )
end

register_password_field_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::PasswordField,
    state::PasswordFieldState,
) =
    _register_text_input_semantic_handlers!(
        dispatcher,
        id,
        state,
        isempty(widget.input.input.placeholder) ? "Password" : widget.input.input.placeholder;
        protected=true,
        metadata=Dict{Symbol,Any}(:password => true, :password_field => true, :protected => true),
    )

function widget_semantic_descriptor(widget::NumberInput, state::NumberInputState)
    return SemanticDescriptor(
        SliderRole;
        label=isempty(widget.placeholder) ? "Number input" : widget.placeholder,
        state=SemanticState(
            focusable=true,
            focused=state.focused,
            invalid=!state.valid,
            value=editing_text(state),
            value_now=number_input_value(state),
            value_min=state.minimum,
            value_max=state.maximum,
        ),
        actions=[FocusSemanticAction, SetValueSemanticAction, IncrementSemanticAction, DecrementSemanticAction],
        metadata=Dict(:step => state.step, :error => state.error),
    )
end

function _number_input_semantic_value(state::NumberInputState)
    return Dict{Symbol,Any}(
        :value => editing_text(state),
        :value_now => number_input_value(state),
        :value_min => state.minimum,
        :value_max => state.maximum,
        :step => state.step,
        :valid => state.valid,
        :error => state.error,
        :focused => state.focused,
    )
end

function _set_number_input_semantic_value!(state::NumberInputState, value)
    if value === nothing || value isa Real
        set_number_value!(state, value)
    else
        set_number_text!(state, string(value))
    end
    return state.valid
end

function register_number_input_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::NumberInput,
    state::NumberInputState,
)
    register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action == FocusSemanticAction
            state.focused = true
            return SemanticActionResult(true; value=_number_input_semantic_value(state))
        elseif request.action == SetValueSemanticAction
            handled = _set_number_input_semantic_value!(state, request.value)
            return SemanticActionResult(
                handled;
                value=_number_input_semantic_value(state),
                message=handled ? nothing : something(state.error, "invalid numeric value"),
            )
        elseif request.action == IncrementSemanticAction
            increment_number_input!(state, 1)
            return SemanticActionResult(true; value=_number_input_semantic_value(state))
        elseif request.action == DecrementSemanticAction
            increment_number_input!(state, -1)
            return SemanticActionResult(true; value=_number_input_semantic_value(state))
        end
        return SemanticActionResult(false; message="number input semantic action is not supported")
    end)
    return dispatcher
end

function widget_semantic_descriptor(::TextArea, state::TextAreaState)
    return SemanticDescriptor(
        TextboxRole;
        label="Text area",
        state=SemanticState(focusable=true, focused=state.focused, value=editing_text(state.editing)),
        actions=[FocusSemanticAction, SetValueSemanticAction],
        metadata=Dict(:multiline => true),
    )
end

function _text_area_semantic_value(
    label::AbstractString,
    state::TextAreaState;
    compatibility_spelling::Bool=false,
)
    value = Dict{Symbol,Any}(
        :label => String(label),
        :value => editing_text(state),
        :focused => state.focused,
        :multiline => true,
    )
    compatibility_spelling && (value[:compatibility_spelling] = true)
    return value
end

function _register_text_area_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    state::TextAreaState,
    label::AbstractString;
    compatibility_spelling::Bool=false,
)
    register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action == FocusSemanticAction
            state.focused = true
            return SemanticActionResult(true; value=_text_area_semantic_value(label, state; compatibility_spelling))
        elseif request.action == SetValueSemanticAction
            set_text!(state.editing, string(request.value))
            state.vertical_offset = 0
            state.horizontal_offset = 0
            return SemanticActionResult(true; value=_text_area_semantic_value(label, state; compatibility_spelling))
        end
        return SemanticActionResult(false; message="text area semantic action is not supported")
    end)
    return dispatcher
end

register_text_area_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::TextArea,
    state::TextAreaState,
) =
    _register_text_area_semantic_handlers!(dispatcher, id, state, "Text area")

function widget_semantic_descriptor(::Textarea, state::TextAreaState)
    return SemanticDescriptor(
        TextboxRole;
        label="Textarea",
        state=SemanticState(focusable=true, focused=state.focused, value=editing_text(state.editing)),
        actions=[FocusSemanticAction, SetValueSemanticAction],
        metadata=Dict(:multiline => true, :compatibility_spelling => true),
    )
end

register_textarea_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::Textarea,
    state::TextAreaState,
) =
    _register_text_area_semantic_handlers!(
        dispatcher,
        id,
        state,
        "Textarea";
        compatibility_spelling=true,
    )

function widget_semantic_descriptor(::RadioGroup, state::RadioGroupState)
    SemanticDescriptor(
        GroupRole;
        state=SemanticState(focusable=true, focused=state.focused),
        actions=[FocusSemanticAction, IncrementSemanticAction, DecrementSemanticAction, SetValueSemanticAction],
    )
end

function widget_semantic_descriptor(widget::RadioBoxList, state::RadioBoxListState)
    return widget_semantic_descriptor(widget.group, state)
end

function widget_semantic_descriptor(widget::RadioSet, state::RadioSetState)
    SemanticDescriptor(
        GroupRole;
        label="Radio set",
        state=SemanticState(focusable=true, focused=state.focused),
        actions=[FocusSemanticAction, IncrementSemanticAction, DecrementSemanticAction, SetValueSemanticAction],
        metadata=Dict(:option_count => length(widget.group.options)),
    )
end

function widget_semantic_descriptor(widget::Select, state::SelectState)
    value = state.selected === nothing || state.selected > length(widget.options) ? nothing :
            _line_text(widget.options[state.selected].label)
    return SemanticDescriptor(
        ListRole;
        label=widget.placeholder,
        state=SemanticState(focusable=true, focused=state.focused, expanded=state.open, value=value),
        actions=[
            FocusSemanticAction,
            ActivateSemanticAction,
            SetValueSemanticAction,
            IncrementSemanticAction,
            DecrementSemanticAction,
            DismissSemanticAction,
        ],
    )
end

widget_semantic_descriptor(::MultiSelect, ::MultiSelectState) =
    SemanticDescriptor(
        ListRole;
        state=SemanticState(focusable=true),
        actions=[FocusSemanticAction, IncrementSemanticAction, DecrementSemanticAction, SetValueSemanticAction],
    )

widget_semantic_descriptor(widget::CheckBoxList, state::CheckBoxListState) =
    widget_semantic_descriptor(widget.multiselect, state)

widget_semantic_descriptor(widget::SelectionList, state::SelectionListState) =
    SemanticDescriptor(
        ListRole;
        label="Selection list",
        state=SemanticState(focusable=true),
        actions=[FocusSemanticAction, IncrementSemanticAction, DecrementSemanticAction, SetValueSemanticAction],
        metadata=Dict(:option_count => length(widget.multiselect.options)),
    )

widget_semantic_descriptor(::List, ::ListState) =
    SemanticDescriptor(
        ListRole;
        state=SemanticState(focusable=true),
        actions=[
            FocusSemanticAction,
            IncrementSemanticAction,
            DecrementSemanticAction,
            SetValueSemanticAction,
            ScrollIntoViewSemanticAction,
        ],
    )

widget_semantic_descriptor(widget::ListView, state::ListViewState) =
    SemanticDescriptor(
        ListRole;
        label="List view",
        state=SemanticState(focusable=true),
        actions=[
            FocusSemanticAction,
            IncrementSemanticAction,
            DecrementSemanticAction,
            SetValueSemanticAction,
            ScrollIntoViewSemanticAction,
        ],
        metadata=Dict(:item_count => length(widget.list.items)),
    )

widget_semantic_descriptor(widget::OptionList, state::OptionListState) =
    SemanticDescriptor(
        ListRole;
        label="Option list",
        state=SemanticState(focusable=true),
        actions=[
            FocusSemanticAction,
            IncrementSemanticAction,
            DecrementSemanticAction,
            SetValueSemanticAction,
            ScrollIntoViewSemanticAction,
        ],
        metadata=Dict(:item_count => length(widget.list.items)),
    )

widget_semantic_descriptor(::Table, ::TableState) =
    SemanticDescriptor(
        TableRole;
        state=SemanticState(focusable=true),
        actions=[
            FocusSemanticAction,
            IncrementSemanticAction,
            DecrementSemanticAction,
            SetValueSemanticAction,
            ScrollIntoViewSemanticAction,
        ],
    )

widget_semantic_descriptor(::Tabs, ::TabsState) =
    SemanticDescriptor(TabListRole; state=SemanticState(focusable=true), actions=[FocusSemanticAction])

widget_semantic_descriptor(::Tree, ::TreeState) =
    SemanticDescriptor(
        TreeRole;
        state=SemanticState(focusable=true),
        actions=[
            FocusSemanticAction,
            IncrementSemanticAction,
            DecrementSemanticAction,
            SetValueSemanticAction,
            ExpandSemanticAction,
            CollapseSemanticAction,
            ScrollIntoViewSemanticAction,
        ],
    )

widget_semantic_descriptor(widget::TreeView, state::TreeViewState) =
    SemanticDescriptor(
        TreeRole;
        label="Tree view",
        state=SemanticState(focusable=true),
        actions=[
            FocusSemanticAction,
            IncrementSemanticAction,
            DecrementSemanticAction,
            SetValueSemanticAction,
            ExpandSemanticAction,
            CollapseSemanticAction,
            ScrollIntoViewSemanticAction,
        ],
        metadata=Dict(:root_count => length(widget.tree.roots)),
    )

function widget_semantic_descriptor(widget::Menu, state::MenuState)
    selected = selected_menu_item(widget, state)
    title = widget.block === nothing || widget.block.title === nothing ? "Menu" :
            _line_text(widget.block.title)
    return SemanticDescriptor(
        MenuRole;
        label=title,
        state=SemanticState(
            focusable=true,
            value=selected === nothing ? nothing : _line_text(selected.label),
        ),
        actions=[FocusSemanticAction],
        metadata=Dict(
            :item_count => length(widget.items),
            :selected_id => selected === nothing ? nothing : selected.id,
        ),
    )
end

function widget_semantic_descriptor(widget::ScrollView, state::ScrollState)
    maximum = max(0, widget.content_size.height - 1)
    return SemanticDescriptor(
        ScrollbarRole;
        label="Scrollable content",
        state=SemanticState(focusable=true, value_now=state.row, value_min=0, value_max=maximum),
        actions=[FocusSemanticAction, IncrementSemanticAction, DecrementSemanticAction, ScrollIntoViewSemanticAction],
    )
end

"""Return semantic child nodes represented internally by a compound widget."""
widget_semantic_children(widget, state, id) = SemanticNode[]

function widget_semantic_children(widget::RadioGroup, state::RadioGroupState, id)
    return SemanticNode[
        SemanticNode(
            "$id/option-$index",
            RadioRole;
            label=_line_text(option.label),
            state=SemanticState(
                enabled=!option.disabled,
                focusable=!option.disabled,
                selected=state.selected == index,
                checked=state.selected == index ? CheckedValue : UncheckedState,
            ),
            actions=option.disabled ? SemanticAction[] : [FocusSemanticAction, SelectSemanticAction, ActivateSemanticAction],
        ) for (index, option) in enumerate(widget.options)
    ]
end

function widget_semantic_children(widget::Select, state::SelectState, id)
    return SemanticNode[
        SemanticNode(
            "$id/option-$index",
            ListItemRole;
            label=_line_text(option.label),
            state=SemanticState(enabled=!option.disabled, selected=state.selected == index),
            actions=option.disabled ? SemanticAction[] : [FocusSemanticAction, SelectSemanticAction, ActivateSemanticAction],
        ) for (index, option) in enumerate(widget.options)
    ]
end

widget_semantic_children(widget::RadioSet, state::RadioSetState, id) =
    widget_semantic_children(widget.group, state, id)

function widget_semantic_children(widget::MultiSelect, state::MultiSelectState, id)
    return SemanticNode[
        SemanticNode(
            "$id/option-$index",
            CheckboxRole;
            label=_line_text(option.label),
            state=SemanticState(
                enabled=!option.disabled,
                checked=index in state.selected ? CheckedValue : UncheckedState,
            ),
            actions=option.disabled ? SemanticAction[] : [FocusSemanticAction, SelectSemanticAction, ActivateSemanticAction],
        ) for (index, option) in enumerate(widget.options)
    ]
end

widget_semantic_children(widget::SelectionList, state::SelectionListState, id) =
    widget_semantic_children(widget.multiselect, state, id)

function widget_semantic_children(widget::List, state::ListState, id)
    return SemanticNode[
        SemanticNode(
            "$id/item-$index",
            ListItemRole;
            label=_line_text(item.line),
            state=SemanticState(selected=state.selected == index),
            actions=[FocusSemanticAction, SelectSemanticAction, ActivateSemanticAction],
        ) for (index, item) in enumerate(widget.items)
    ]
end

widget_semantic_children(widget::ListView, state::ListViewState, id) =
    widget_semantic_children(widget.list, state, id)

widget_semantic_children(widget::OptionList, state::OptionListState, id) =
    widget_semantic_children(widget.list, state, id)

function widget_semantic_children(widget::Table, state::TableState, id)
    return SemanticNode[
        SemanticNode(
            "$id/row-$row_index",
            RowRole;
            state=SemanticState(selected=state.selected_row == row_index),
            actions=[FocusSemanticAction, SelectSemanticAction, ActivateSemanticAction],
            children=SemanticNode[
                SemanticNode(
                    "$id/row-$row_index/cell-$column_index",
                    CellRole;
                    label=_line_text(cell),
                    state=SemanticState(selected=state.selected_row == row_index && state.selected_column == column_index),
                    actions=[FocusSemanticAction, SelectSemanticAction, ActivateSemanticAction],
                ) for (column_index, cell) in enumerate(row.cells)
            ],
        ) for (row_index, row) in enumerate(widget.rows)
    ]
end

function widget_semantic_children(widget::Tabs, state::TabsState, id)
    return SemanticNode[
        SemanticNode(
            "$id/tab-$index",
            TabRole;
            label=_line_text(tab.title),
            state=SemanticState(focusable=true, selected=state.selected == index),
            actions=[SelectSemanticAction],
            metadata=Dict(:tab_id => tab.id),
        ) for (index, tab) in enumerate(widget.tabs)
    ]
end

"""Register semantic action handlers for a standalone tab bar."""
function register_tabs_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::Tabs,
    state::TabsState,
)
    node_id = string(id)
    register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == FocusSemanticAction
            selected = selected_tab(widget, state)
            return SemanticActionResult(true; value=isnothing(selected) ? nothing : selected.id)
        end
        return SemanticActionResult(false; message="tabs semantic action is not supported")
    end)
    for (registered_index, tab) in enumerate(widget.tabs)
        tab_id = tab.id
        register_semantic_handler!(dispatcher, "$(node_id)/tab-$registered_index", function (request)
            index = findfirst(candidate -> candidate.id == tab_id, widget.tabs)
            isnothing(index) && return SemanticActionResult(false; message="tab is not available")
            if request.action == FocusSemanticAction || request.action == SelectSemanticAction
                select_tab!(state, widget, index)
                return SemanticActionResult(true; value=tab_id)
            end
            return SemanticActionResult(false; message="tab semantic action is not supported")
        end)
    end
    return dispatcher
end

function _tree_semantic_node(node::TreeNode, state::TreeState, id)
    expandable = !isempty(node.children)
    expanded = expandable ? node.id in state.expanded : nothing
    actions = SemanticAction[FocusSemanticAction, SelectSemanticAction, ActivateSemanticAction]
    expandable && push!(actions, expanded ? CollapseSemanticAction : ExpandSemanticAction)
    children = expanded === true ? SemanticNode[
        _tree_semantic_node(child, state, "$id/child-$index") for (index, child) in enumerate(node.children)
    ] : SemanticNode[]
    return SemanticNode(
        id,
        TreeItemRole;
        label=_line_text(node.label),
        state=SemanticState(selected=isequal(state.selected, node.id), expanded=expanded),
        actions,
        children,
        metadata=Dict(:item_id => node.id),
    )
end

function widget_semantic_children(widget::Tree, state::TreeState, id)
    SemanticNode[
        _tree_semantic_node(node, state, "$id/root-$index") for (index, node) in enumerate(widget.roots)
    ]
end

widget_semantic_children(widget::TreeView, state::TreeViewState, id) =
    widget_semantic_children(widget.tree, state, id)

function widget_semantic_children(widget::Menu, state::MenuState, id)
    return SemanticNode[
        SemanticNode(
            "$id/item-$index",
            MenuItemRole;
            label=_line_text(item.label),
            description=isempty(item.shortcut) ? nothing : "Shortcut: $(item.shortcut)",
            state=SemanticState(
                enabled=!item.disabled,
                focusable=!item.disabled,
                selected=state.selected == index,
            ),
            actions=item.disabled ? SemanticAction[] : [
                ActivateSemanticAction,
                FocusSemanticAction,
                SelectSemanticAction,
            ],
            metadata=Dict(
                :item_id => item.id,
                :message => item.message,
                :shortcut => item.shortcut,
            ),
        ) for (index, item) in enumerate(widget.items)
    ]
end

"""Register semantic action handlers for a menu and its enabled items."""
function register_menu_semantic_handlers!(
    dispatcher::SemanticDispatcher,
    id,
    widget::Menu,
    state::MenuState,
)
    node_id = string(id)
    register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == FocusSemanticAction
            return SemanticActionResult(true; value=selected_menu_message(widget, state))
        end
        return SemanticActionResult(false; message="menu semantic action is not supported")
    end)
    for (registered_index, item) in enumerate(widget.items)
        item.disabled && continue
        item_id = item.id
        register_semantic_handler!(dispatcher, "$(node_id)/item-$registered_index", function (request)
            index = findfirst(candidate -> candidate.id == item_id, widget.items)
            if isnothing(index) || widget.items[index].disabled
                return SemanticActionResult(false; message="menu item is not available")
            end
            if request.action == FocusSemanticAction || request.action == SelectSemanticAction
                select_menu_item!(state, widget, index)
                return SemanticActionResult(true; value=item_id)
            elseif request.action == ActivateSemanticAction
                select_menu_item!(state, widget, index)
                return SemanticActionResult(true; value=selected_menu_message(widget, state))
            end
            return SemanticActionResult(false; message="menu item semantic action is not supported")
        end)
    end
    return dispatcher
end

function _merge_semantic_state(instance, descriptor::SemanticDescriptor, toolkit, path)
    value = descriptor.state
    element = instance.element
    target = element.id === nothing ? path : element.id
    hidden = value.hidden || instance.hidden
    enabled = value.enabled && !element.disabled
    focusable = (value.focusable || element.focusable) && enabled && !hidden
    return SemanticState(
        enabled=enabled,
        focusable=focusable,
        focused=focusable && focused(toolkit.focus) == target,
        selected=value.selected,
        expanded=value.expanded,
        checked=value.checked,
        busy=value.busy,
        hidden=hidden,
        invalid=value.invalid,
        readonly=value.readonly,
        required=value.required,
        value=value.value,
        value_now=value.value_now,
        value_min=value.value_min,
        value_max=value.value_max,
    )
end

function _without_semantic_focus(state::SemanticState)
    return SemanticState(
        enabled=state.enabled,
        focusable=state.focusable,
        focused=false,
        selected=state.selected,
        expanded=state.expanded,
        checked=state.checked,
        busy=state.busy,
        hidden=state.hidden,
        invalid=state.invalid,
        readonly=state.readonly,
        required=state.required,
        value=state.value,
        value_now=state.value_now,
        value_min=state.value_min,
        value_max=state.value_max,
    )
end

function _subtree_has_focus(nodes)
    return any(node -> node.state.focused || _subtree_has_focus(node.children), nodes)
end

function _instance_semantic_id(root_id::String, path, instance)
    instance.element.id === nothing || return string(instance.element.id)
    components = String[
        component[1] == :key ? "key:$(component[2])" : "position:$(component[2])"
        for component in element_path_components(path)
    ]
    return root_id * "/" * join(components, '/')
end

function _instance_descriptor(instance)
    override = instance.element.semantics
    override === nothing && return widget_semantic_descriptor(instance.element.widget, instance.state)
    override isa SemanticDescriptor && return override
    applicable(override, instance.element.widget, instance.state, instance.element) ||
        throw(ArgumentError("element semantics callback must accept (widget, state, element)"))
    descriptor = override(instance.element.widget, instance.state, instance.element)
    descriptor isa SemanticDescriptor ||
        throw(ArgumentError("element semantics callback must return SemanticDescriptor"))
    return descriptor
end

"""Build and validate an accessibility tree from the last rendered toolkit tree."""
function toolkit_semantic_tree(
    tree::ToolkitTree;
    id="application",
    label::AbstractString="Application",
    generation::Integer=0,
    validate::Bool=true,
)
    root_id = string(id)
    children_by_parent = Dict{Any,Vector{ElementPath}}()
    for path in tree.state.paint_order
        instance = tree.state.instances[path]
        push!(get!(children_by_parent, instance.parent, ElementPath[]), path)
    end
    function build(path)
        instance = tree.state.instances[path]
        descriptor = _instance_descriptor(instance)
        node_id = _instance_semantic_id(root_id, path, instance)
        state = _merge_semantic_state(instance, descriptor, tree.state, path)
        actions = state.enabled && !state.hidden ? descriptor.actions : Set{SemanticAction}()
        internal = widget_semantic_children(instance.element.widget, instance.state, node_id)
        descendants = SemanticNode[build(child) for child in get(children_by_parent, path, ElementPath[])]
        children = vcat(internal, descendants)
        state = state.focused && _subtree_has_focus(children) ? _without_semantic_focus(state) : state
        return SemanticNode(
            node_id,
            descriptor.role;
            label=descriptor.label,
            description=descriptor.description,
            bounds=SemanticRect(instance.area.row, instance.area.column, instance.area.width, instance.area.height),
            state,
            actions,
            children,
            metadata=merge(Dict{Symbol,Any}(:widget_type => typeof(instance.element.widget)), descriptor.metadata),
        )
    end
    children = SemanticNode[build(path) for path in get(children_by_parent, nothing, ElementPath[])]
    result = SemanticTree(SemanticNode(root_id, ApplicationRole; label, children); generation)
    if validate
        diagnostics = validate_semantics(result)
        errors = SemanticDiagnostic[diagnostic for diagnostic in diagnostics if diagnostic.severity == :error]
        isempty(errors) || throw(SemanticBuildError("toolkit semantic tree validation failed", diagnostics))
    end
    return result
end

mutable struct SemanticDraft
    id::String
    descriptor::SemanticDescriptor
    bounds::Union{Nothing,SemanticRect}
    children::Vector{SemanticNode}
end

struct SemanticBuildError <: Exception
    message::String
    diagnostics::Vector{SemanticDiagnostic}
end

function Base.showerror(io::IO, error::SemanticBuildError)
    print(io, error.message)
    for diagnostic in error.diagnostics
        print(io, "\n", diagnostic.severity, " ", diagnostic.node_id, ": ", diagnostic.message)
    end
end

mutable struct SemanticBuilder
    stack::Vector{SemanticDraft}
    root::Union{Nothing,SemanticNode}
    generation::UInt64
    active::Bool
end

SemanticBuilder(; generation::Integer=0) = begin
    generation >= 0 || throw(ArgumentError("semantic generation cannot be negative"))
    SemanticBuilder(SemanticDraft[], nothing, UInt64(generation), false)
end

function begin_semantic_tree!(builder::SemanticBuilder)
    builder.active && throw(SemanticBuildError("a semantic build is already active", SemanticDiagnostic[]))
    empty!(builder.stack)
    builder.root = nothing
    builder.active = true
    return builder
end

function push_semantic_node!(
    builder::SemanticBuilder,
    id,
    descriptor::SemanticDescriptor=SemanticDescriptor();
    bounds::Union{Nothing,SemanticRect}=nothing,
)
    builder.active || throw(SemanticBuildError("begin_semantic_tree! must be called first", SemanticDiagnostic[]))
    push!(builder.stack, SemanticDraft(string(id), descriptor, bounds, SemanticNode[]))
    return builder
end

function _materialize(draft::SemanticDraft)
    descriptor = draft.descriptor
    return SemanticNode(
        draft.id,
        descriptor.role;
        label=descriptor.label,
        description=descriptor.description,
        bounds=draft.bounds,
        state=descriptor.state,
        actions=descriptor.actions,
        children=draft.children,
        metadata=descriptor.metadata,
    )
end

function pop_semantic_node!(builder::SemanticBuilder)
    builder.active || throw(SemanticBuildError("no semantic build is active", SemanticDiagnostic[]))
    isempty(builder.stack) && throw(SemanticBuildError("semantic node stack is empty", SemanticDiagnostic[]))
    node = _materialize(pop!(builder.stack))
    if isempty(builder.stack)
        builder.root === nothing || throw(SemanticBuildError("a semantic tree can have only one root", SemanticDiagnostic[]))
        builder.root = node
    else
        push!(last(builder.stack).children, node)
    end
    return node
end

function with_semantic_node(
    operation::F,
    builder::SemanticBuilder,
    id,
    descriptor::SemanticDescriptor=SemanticDescriptor();
    bounds::Union{Nothing,SemanticRect}=nothing,
) where {F}
    initial_depth = length(builder.stack)
    push_semantic_node!(builder, id, descriptor; bounds=bounds)
    try
        result = operation()
        pop_semantic_node!(builder)
        return result
    catch
        while length(builder.stack) > initial_depth
            pop!(builder.stack)
        end
        rethrow()
    end
end

function finish_semantic_tree!(builder::SemanticBuilder; validate::Bool=true)
    builder.active || throw(SemanticBuildError("no semantic build is active", SemanticDiagnostic[]))
    isempty(builder.stack) || throw(SemanticBuildError("semantic nodes remain open", SemanticDiagnostic[]))
    builder.root === nothing && throw(SemanticBuildError("semantic tree has no root", SemanticDiagnostic[]))
    tree = SemanticTree(builder.root; generation=builder.generation + 1)
    diagnostics = validate ? validate_semantics(tree) : SemanticDiagnostic[]
    errors = SemanticDiagnostic[diagnostic for diagnostic in diagnostics if diagnostic.severity == :error]
    isempty(errors) || throw(SemanticBuildError("semantic tree validation failed", diagnostics))
    builder.generation = tree.generation
    builder.active = false
    return tree
end

function abort_semantic_tree!(builder::SemanticBuilder)
    empty!(builder.stack)
    builder.root = nothing
    builder.active = false
    return builder
end

const _DEFAULT_SEMANTIC_QUERY_PREDICATE = node -> true

struct SemanticQuery
    id::Union{Nothing,String}
    role::Union{Nothing,SemanticRole}
    label::Union{Nothing,String,Regex}
    description::Union{Nothing,String,Regex}
    bounds::Union{Nothing,SemanticRect}
    action::Union{Nothing,SemanticAction}
    actions::Set{SemanticAction}
    focusable::Union{Nothing,Bool}
    focused::Union{Nothing,Bool}
    selected::Union{Nothing,Bool}
    expanded::Union{Nothing,Bool}
    checked::Union{Nothing,CheckedState}
    enabled::Union{Nothing,Bool}
    busy::Union{Nothing,Bool}
    hidden::Union{Nothing,Bool}
    invalid::Union{Nothing,Bool}
    readonly::Union{Nothing,Bool}
    required::Union{Nothing,Bool}
    value::Union{Nothing,String,Regex}
    value_now::Union{Nothing,Float64}
    value_min::Union{Nothing,Float64}
    value_max::Union{Nothing,Float64}
    metadata::Dict{Symbol,Any}
    include_hidden::Bool
    predicate::Any

    function SemanticQuery(;
        id=nothing,
        role::Union{Nothing,SemanticRole}=nothing,
        label::Union{Nothing,AbstractString,Regex}=nothing,
        description::Union{Nothing,AbstractString,Regex}=nothing,
        bounds::Union{Nothing,SemanticRect}=nothing,
        action::Union{Nothing,SemanticAction}=nothing,
        actions=SemanticAction[],
        focusable::Union{Nothing,Bool}=nothing,
        focused::Union{Nothing,Bool}=nothing,
        selected::Union{Nothing,Bool}=nothing,
        expanded::Union{Nothing,Bool}=nothing,
        checked::Union{Nothing,CheckedState}=nothing,
        enabled::Union{Nothing,Bool}=nothing,
        busy::Union{Nothing,Bool}=nothing,
        hidden::Union{Nothing,Bool}=nothing,
        invalid::Union{Nothing,Bool}=nothing,
        readonly::Union{Nothing,Bool}=nothing,
        required::Union{Nothing,Bool}=nothing,
        value::Union{Nothing,AbstractString,Regex}=nothing,
        value_now::Union{Nothing,Real}=nothing,
        value_min::Union{Nothing,Real}=nothing,
        value_max::Union{Nothing,Real}=nothing,
        metadata=Dict{Symbol,Any}(),
        include_hidden::Bool=false,
        predicate=_DEFAULT_SEMANTIC_QUERY_PREDICATE,
    )
        new(
            id === nothing ? nothing : string(id),
            role,
            label === nothing || label isa Regex ? label : String(label),
            description === nothing || description isa Regex ? description : String(description),
            bounds,
            action,
            Set{SemanticAction}(actions),
            focusable,
            focused,
            selected,
            expanded,
            checked,
            enabled,
            busy,
            hidden,
            invalid,
            readonly,
            required,
            value === nothing || value isa Regex ? value : String(value),
            value_now === nothing ? nothing : Float64(value_now),
            value_min === nothing ? nothing : Float64(value_min),
            value_max === nothing ? nothing : Float64(value_max),
            Dict{Symbol,Any}(Symbol(key) => value for (key, value) in pairs(metadata)),
            include_hidden,
            predicate,
        )
    end
end

function _semantic_query_display_pairs(query::SemanticQuery)
    pairs = Pair{Symbol,Any}[]
    add!(key::Symbol, value) = push!(pairs, Pair{Symbol,Any}(key, value))
    query.id === nothing || add!(:id, query.id)
    query.role === nothing || add!(:role, query.role)
    query.label === nothing || add!(:label, query.label)
    query.description === nothing || add!(:description, query.description)
    query.bounds === nothing || add!(:bounds, query.bounds)
    query.action === nothing || add!(:action, query.action)
    isempty(query.actions) || add!(:actions, query.actions)
    query.focusable === nothing || add!(:focusable, query.focusable)
    query.focused === nothing || add!(:focused, query.focused)
    query.selected === nothing || add!(:selected, query.selected)
    query.expanded === nothing || add!(:expanded, query.expanded)
    query.checked === nothing || add!(:checked, query.checked)
    query.enabled === nothing || add!(:enabled, query.enabled)
    query.busy === nothing || add!(:busy, query.busy)
    query.hidden === nothing || add!(:hidden, query.hidden)
    query.invalid === nothing || add!(:invalid, query.invalid)
    query.readonly === nothing || add!(:readonly, query.readonly)
    query.required === nothing || add!(:required, query.required)
    query.value === nothing || add!(:value, query.value)
    query.value_now === nothing || add!(:value_now, query.value_now)
    query.value_min === nothing || add!(:value_min, query.value_min)
    query.value_max === nothing || add!(:value_max, query.value_max)
    isempty(query.metadata) || add!(:metadata, query.metadata)
    query.include_hidden && add!(:include_hidden, true)
    query.predicate === _DEFAULT_SEMANTIC_QUERY_PREDICATE || add!(:predicate, "<custom>")
    return pairs
end

function Base.show(io::IO, query::SemanticQuery)
    pairs = _semantic_query_display_pairs(query)
    print(io, "SemanticQuery(")
    for (index, pair) in enumerate(pairs)
        index == 1 || print(io, ", ")
        print(io, pair.first, '=')
        show(io, pair.second)
    end
    print(io, ')')
end

function _matches(query::SemanticQuery, node::SemanticNode)
    (query.include_hidden || query.hidden === true) || !node.state.hidden || return false
    query.id === nothing || node.id == query.id || return false
    query.role === nothing || node.role == query.role || return false
    if query.label isa String
        node.label == query.label || return false
    elseif query.label isa Regex
        occursin(query.label, node.label) || return false
    end
    if query.description isa String
        node.description == query.description || return false
    elseif query.description isa Regex
        node.description !== nothing && occursin(query.description, node.description) || return false
    end
    query.bounds === nothing || node.bounds == query.bounds || return false
    query.action === nothing || query.action in node.actions || return false
    all(action -> action in node.actions, query.actions) || return false
    query.focusable === nothing || node.state.focusable == query.focusable || return false
    query.focused === nothing || node.state.focused == query.focused || return false
    query.selected === nothing || node.state.selected == query.selected || return false
    query.expanded === nothing || node.state.expanded == query.expanded || return false
    query.checked === nothing || node.state.checked == query.checked || return false
    query.enabled === nothing || node.state.enabled == query.enabled || return false
    query.busy === nothing || node.state.busy == query.busy || return false
    query.hidden === nothing || node.state.hidden == query.hidden || return false
    query.invalid === nothing || node.state.invalid == query.invalid || return false
    query.readonly === nothing || node.state.readonly == query.readonly || return false
    query.required === nothing || node.state.required == query.required || return false
    if query.value isa String
        node.state.value == query.value || return false
    elseif query.value isa Regex
        node.state.value !== nothing && occursin(query.value, node.state.value) || return false
    end
    query.value_now === nothing || node.state.value_now == query.value_now || return false
    query.value_min === nothing || node.state.value_min == query.value_min || return false
    query.value_max === nothing || node.state.value_max == query.value_max || return false
    for (key, expected) in query.metadata
        get(node.metadata, key, nothing) == expected || return false
    end
    applicable(query.predicate, node) || throw(ArgumentError("semantic query predicate is not callable for SemanticNode"))
    return Bool(query.predicate(node))
end

query_semantics(tree::SemanticTree, query::SemanticQuery) =
    SemanticNode[node for node in semantic_nodes(tree) if _matches(query, node)]

query_semantics(tree::SemanticTree; kwargs...) =
    query_semantics(tree, SemanticQuery(; kwargs...))

struct SemanticQueryError <: Exception
    message::String
    matches::Int
end

Base.showerror(io::IO, error::SemanticQueryError) =
    print(io, error.message, " (matches=", error.matches, ')')

function _semantic_query_match_summary(matches)
    isempty(matches) && return "no matching semantic ids"
    ids = String[node.id for node in Iterators.take(matches, 5)]
    suffix = length(matches) > length(ids) ? ", ..." : ""
    return "matched semantic ids: $(join(ids, ", "))$suffix"
end

function query_one_semantic(tree::SemanticTree, query::SemanticQuery)
    matches = query_semantics(tree, query)
    length(matches) == 1 || throw(SemanticQueryError(
        "expected exactly one semantic node for $(repr(query)); $(_semantic_query_match_summary(matches))",
        length(matches),
    ))
    return first(matches)
end

query_one_semantic(tree::SemanticTree; kwargs...) =
    query_one_semantic(tree, SemanticQuery(; kwargs...))

mutable struct SemanticPilot
    tree::SemanticTree
    dispatcher::SemanticDispatcher
    announcements::AnnouncementQueue
    changes::Vector{SemanticChange}
end

SemanticPilot(
    tree::SemanticTree;
    dispatcher::SemanticDispatcher=SemanticDispatcher(),
    announcements::AnnouncementQueue=AnnouncementQueue(),
) = SemanticPilot(tree, dispatcher, announcements, SemanticChange[])

query_semantics(pilot::SemanticPilot, query::SemanticQuery) =
    query_semantics(pilot.tree, query)

query_semantics(pilot::SemanticPilot; kwargs...) =
    query_semantics(pilot.tree; kwargs...)

query_one_semantic(pilot::SemanticPilot, query::SemanticQuery) =
    query_one_semantic(pilot.tree, query)

query_one_semantic(pilot::SemanticPilot; kwargs...) =
    query_one_semantic(pilot.tree; kwargs...)

function refresh_semantic_pilot!(pilot::SemanticPilot, tree::SemanticTree)
    pilot.changes = diff_semantics(pilot.tree, tree)
    pilot.tree = tree
    return pilot.changes
end

function perform_semantic_action!(
    pilot::SemanticPilot,
    node_id,
    action::SemanticAction;
    value=nothing,
)
    node = semantic_node(pilot.tree, node_id)
    node === nothing && return SemanticActionResult(false; message="semantic node was not found")
    node.state.hidden && return SemanticActionResult(false; message="semantic node is hidden")
    node.state.enabled || return SemanticActionResult(false; message="semantic node is disabled")
    action in node.actions || return SemanticActionResult(false; message="semantic action is not supported")
    return dispatch_semantic_action!(
        pilot.dispatcher,
        SemanticActionRequest(node.id, action; value=value),
    )
end

take_semantic_announcements!(pilot::SemanticPilot) = take_announcements!(pilot.announcements)

function semantic_pilot_snapshot(pilot::SemanticPilot; include_changes::Bool=false)
    tree_snapshot = semantic_snapshot(pilot.tree)
    include_changes || return tree_snapshot
    changes = String[
        "$(change.kind) $(change.node_id)" for change in pilot.changes
    ]
    return isempty(changes) ? tree_snapshot : tree_snapshot * "\n-- changes --\n" * join(changes, '\n')
end

end
