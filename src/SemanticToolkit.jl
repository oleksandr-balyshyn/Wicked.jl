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
                       UncheckedState,
                       CheckedValue,
                       SemanticRect,
                       SemanticState,
                       SemanticAction,
                       ActivateSemanticAction,
                       FocusSemanticAction,
                       SetValueSemanticAction,
                       SelectSemanticAction,
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
                 Checkbox,
                 CheckboxState,
                 Toggle,
                 ToggleState,
                 TextInput,
                 TextInputState,
                 TextArea,
                 TextAreaState,
                 RadioGroup,
                 RadioGroupState,
                 Select,
                 SelectState,
                 MultiSelect,
                 MultiSelectState,
                 List,
                 ListState,
                 Table,
                 TableState,
                 Tabs,
                 TabsState,
                 Tree,
                 TreeState,
                 TreeNode,
                 Menu,
                 MenuState,
                 ScrollView,
                 ScrollState,
                 NumberInput,
                 NumberInputState,
                 number_input_value,
                 editing_text

export SemanticDescriptor,
       RoleRegistry,
       register_role_factory!,
       unregister_role_factory!,
       semantic_descriptor,
       widget_semantic_descriptor,
       widget_semantic_children,
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

function widget_semantic_descriptor(widget::Checkbox, state::CheckboxState)
    return SemanticDescriptor(
        CheckboxRole;
        label=_line_text(widget.label),
        state=SemanticState(focusable=true, checked=state.checked ? CheckedValue : UncheckedState),
        actions=[ActivateSemanticAction, FocusSemanticAction],
    )
end

function widget_semantic_descriptor(widget::Toggle, state::ToggleState)
    return SemanticDescriptor(
        CheckboxRole;
        label=state.enabled ? widget.on_label : widget.off_label,
        state=SemanticState(focusable=true, checked=state.enabled ? CheckedValue : UncheckedState),
        actions=[ActivateSemanticAction, FocusSemanticAction],
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

function widget_semantic_descriptor(::TextArea, state::TextAreaState)
    return SemanticDescriptor(
        TextboxRole;
        label="Text area",
        state=SemanticState(focusable=true, focused=state.focused, value=editing_text(state.editing)),
        actions=[FocusSemanticAction, SetValueSemanticAction],
        metadata=Dict(:multiline => true),
    )
end

function widget_semantic_descriptor(::RadioGroup, state::RadioGroupState)
    SemanticDescriptor(GroupRole; state=SemanticState(focusable=true, focused=state.focused))
end

function widget_semantic_descriptor(widget::Select, state::SelectState)
    value = state.selected === nothing || state.selected > length(widget.options) ? nothing :
            _line_text(widget.options[state.selected].label)
    return SemanticDescriptor(
        ListRole;
        label=widget.placeholder,
        state=SemanticState(focusable=true, focused=state.focused, expanded=state.open, value=value),
        actions=[FocusSemanticAction, ActivateSemanticAction, SetValueSemanticAction],
    )
end

widget_semantic_descriptor(::MultiSelect, ::MultiSelectState) =
    SemanticDescriptor(ListRole; state=SemanticState(focusable=true), actions=[FocusSemanticAction])

widget_semantic_descriptor(::List, ::ListState) =
    SemanticDescriptor(ListRole; state=SemanticState(focusable=true), actions=[FocusSemanticAction])

widget_semantic_descriptor(::Table, ::TableState) =
    SemanticDescriptor(TableRole; state=SemanticState(focusable=true), actions=[FocusSemanticAction])

widget_semantic_descriptor(::Tabs, ::TabsState) =
    SemanticDescriptor(TabListRole; state=SemanticState(focusable=true), actions=[FocusSemanticAction])

widget_semantic_descriptor(::Tree, ::TreeState) =
    SemanticDescriptor(TreeRole; state=SemanticState(focusable=true), actions=[FocusSemanticAction])

function widget_semantic_descriptor(widget::Menu, state::MenuState)
    selected = if state.selected === nothing || state.selected > length(widget.items)
        nothing
    else
        candidate = widget.items[state.selected]
        candidate.disabled ? nothing : candidate
    end
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
            actions=option.disabled ? SemanticAction[] : [SelectSemanticAction],
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
            actions=option.disabled ? SemanticAction[] : [SelectSemanticAction],
        ) for (index, option) in enumerate(widget.options)
    ]
end

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
            actions=option.disabled ? SemanticAction[] : [SelectSemanticAction],
        ) for (index, option) in enumerate(widget.options)
    ]
end

function widget_semantic_children(widget::List, state::ListState, id)
    return SemanticNode[
        SemanticNode(
            "$id/item-$index",
            ListItemRole;
            label=_line_text(item.line),
            state=SemanticState(selected=state.selected == index),
            actions=[SelectSemanticAction],
        ) for (index, item) in enumerate(widget.items)
    ]
end

function widget_semantic_children(widget::Table, state::TableState, id)
    return SemanticNode[
        SemanticNode(
            "$id/row-$row_index",
            RowRole;
            state=SemanticState(selected=state.selected_row == row_index),
            actions=[SelectSemanticAction],
            children=SemanticNode[
                SemanticNode(
                    "$id/row-$row_index/cell-$column_index",
                    CellRole;
                    label=_line_text(cell),
                    state=SemanticState(selected=state.selected_row == row_index && state.selected_column == column_index),
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

function _tree_semantic_node(node::TreeNode, state::TreeState, id)
    expandable = !isempty(node.children)
    expanded = expandable ? node.id in state.expanded : nothing
    actions = SemanticAction[SelectSemanticAction]
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

struct SemanticQuery
    id::Union{Nothing,String}
    role::Union{Nothing,SemanticRole}
    label::Union{Nothing,String,Regex}
    action::Union{Nothing,SemanticAction}
    focused::Union{Nothing,Bool}
    selected::Union{Nothing,Bool}
    enabled::Union{Nothing,Bool}
    include_hidden::Bool
    predicate::Any

    function SemanticQuery(;
        id=nothing,
        role::Union{Nothing,SemanticRole}=nothing,
        label::Union{Nothing,AbstractString,Regex}=nothing,
        action::Union{Nothing,SemanticAction}=nothing,
        focused::Union{Nothing,Bool}=nothing,
        selected::Union{Nothing,Bool}=nothing,
        enabled::Union{Nothing,Bool}=nothing,
        include_hidden::Bool=false,
        predicate=node -> true,
    )
        new(
            id === nothing ? nothing : string(id),
            role,
            label === nothing || label isa Regex ? label : String(label),
            action,
            focused,
            selected,
            enabled,
            include_hidden,
            predicate,
        )
    end
end

function _matches(query::SemanticQuery, node::SemanticNode)
    query.include_hidden || !node.state.hidden || return false
    query.id === nothing || node.id == query.id || return false
    query.role === nothing || node.role == query.role || return false
    if query.label isa String
        node.label == query.label || return false
    elseif query.label isa Regex
        occursin(query.label, node.label) || return false
    end
    query.action === nothing || query.action in node.actions || return false
    query.focused === nothing || node.state.focused == query.focused || return false
    query.selected === nothing || node.state.selected == query.selected || return false
    query.enabled === nothing || node.state.enabled == query.enabled || return false
    applicable(query.predicate, node) || throw(ArgumentError("semantic query predicate is not callable for SemanticNode"))
    return Bool(query.predicate(node))
end

query_semantics(tree::SemanticTree, query::SemanticQuery=SemanticQuery()) =
    SemanticNode[node for node in semantic_nodes(tree) if _matches(query, node)]

struct SemanticQueryError <: Exception
    message::String
    matches::Int
end

Base.showerror(io::IO, error::SemanticQueryError) =
    print(io, error.message, " (matches=", error.matches, ')')

function query_one_semantic(tree::SemanticTree, query::SemanticQuery)
    matches = query_semantics(tree, query)
    length(matches) == 1 || throw(SemanticQueryError("expected exactly one semantic node", length(matches)))
    return first(matches)
end

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
