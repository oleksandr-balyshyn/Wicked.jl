module Accessibility

export SemanticRole,
       ApplicationRole,
       WindowRole,
       DialogRole,
       GroupRole,
       ButtonRole,
       CheckboxRole,
       RadioRole,
       TextboxRole,
       SearchboxRole,
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
       ProgressRole,
       SliderRole,
       ScrollbarRole,
       LinkRole,
       ImageRole,
       HeadingRole,
       ParagraphRole,
       StatusRole,
       AlertRole,
       LogRole,
       TerminalRole,
       GenericRole,
       CheckedState,
       NotCheckable,
       UncheckedState,
       CheckedValue,
       MixedValue,
       SemanticRect,
       SemanticState,
       SemanticAction,
       ActivateSemanticAction,
       FocusSemanticAction,
       BlurSemanticAction,
       IncrementSemanticAction,
       DecrementSemanticAction,
       ExpandSemanticAction,
       CollapseSemanticAction,
       SelectSemanticAction,
       DismissSemanticAction,
       SetValueSemanticAction,
       ScrollIntoViewSemanticAction,
       SemanticNode,
       SemanticTree,
       SemanticDiagnostic,
       validate_semantics,
       semantic_node,
       semantic_nodes,
       semantic_hit_test,
       semantic_focus_order,
       SemanticChangeKind,
       AddedSemanticNode,
       RemovedSemanticNode,
       UpdatedSemanticNode,
       MovedSemanticNode,
       SemanticChange,
       diff_semantics,
       SemanticActionRequest,
       SemanticActionResult,
       SemanticDispatcher,
       register_semantic_handler!,
       unregister_semantic_handler!,
       dispatch_semantic_action!,
       LivePoliteness,
       PoliteAnnouncement,
       AssertiveAnnouncement,
       SemanticAnnouncement,
       AnnouncementQueue,
       announce!,
       take_announcements!,
       clear_announcements!,
       semantic_snapshot

@enum SemanticRole begin
    ApplicationRole
    WindowRole
    DialogRole
    GroupRole
    ButtonRole
    CheckboxRole
    RadioRole
    TextboxRole
    SearchboxRole
    ListRole
    ListItemRole
    TableRole
    RowRole
    CellRole
    TabListRole
    TabRole
    TreeRole
    TreeItemRole
    MenuRole
    MenuItemRole
    ProgressRole
    SliderRole
    ScrollbarRole
    LinkRole
    ImageRole
    HeadingRole
    ParagraphRole
    StatusRole
    AlertRole
    LogRole
    TerminalRole
    GenericRole
end

@enum CheckedState begin
    NotCheckable
    UncheckedState
    CheckedValue
    MixedValue
end

struct SemanticRect
    row::Int
    column::Int
    width::Int
    height::Int

    function SemanticRect(row::Integer, column::Integer, width::Integer, height::Integer)
        row > 0 || throw(ArgumentError("semantic row must be positive"))
        column > 0 || throw(ArgumentError("semantic column must be positive"))
        width >= 0 || throw(ArgumentError("semantic width cannot be negative"))
        height >= 0 || throw(ArgumentError("semantic height cannot be negative"))
        new(Int(row), Int(column), Int(width), Int(height))
    end
end

function _contains(rect::SemanticRect, row::Int, column::Int)
    return rect.row <= row < rect.row + rect.height &&
           rect.column <= column < rect.column + rect.width
end

struct SemanticState
    enabled::Bool
    focusable::Bool
    focused::Bool
    selected::Bool
    expanded::Union{Nothing,Bool}
    checked::CheckedState
    busy::Bool
    hidden::Bool
    invalid::Bool
    readonly::Bool
    required::Bool
    value::Union{Nothing,String}
    value_now::Union{Nothing,Float64}
    value_min::Union{Nothing,Float64}
    value_max::Union{Nothing,Float64}

    function SemanticState(;
        enabled::Bool=true,
        focusable::Bool=false,
        focused::Bool=false,
        selected::Bool=false,
        expanded::Union{Nothing,Bool}=nothing,
        checked::CheckedState=NotCheckable,
        busy::Bool=false,
        hidden::Bool=false,
        invalid::Bool=false,
        readonly::Bool=false,
        required::Bool=false,
        value::Union{Nothing,AbstractString}=nothing,
        value_now::Union{Nothing,Real}=nothing,
        value_min::Union{Nothing,Real}=nothing,
        value_max::Union{Nothing,Real}=nothing,
    )
        new(
            enabled,
            focusable,
            focused,
            selected,
            expanded,
            checked,
            busy,
            hidden,
            invalid,
            readonly,
            required,
            value === nothing ? nothing : String(value),
            value_now === nothing ? nothing : Float64(value_now),
            value_min === nothing ? nothing : Float64(value_min),
            value_max === nothing ? nothing : Float64(value_max),
        )
    end
end

function Base.:(==)(left::SemanticState, right::SemanticState)
    return left.enabled == right.enabled &&
           left.focusable == right.focusable &&
           left.focused == right.focused &&
           left.selected == right.selected &&
           left.expanded == right.expanded &&
           left.checked == right.checked &&
           left.busy == right.busy &&
           left.hidden == right.hidden &&
           left.invalid == right.invalid &&
           left.readonly == right.readonly &&
           left.required == right.required &&
           left.value == right.value &&
           left.value_now == right.value_now &&
           left.value_min == right.value_min &&
           left.value_max == right.value_max
end

Base.isequal(left::SemanticState, right::SemanticState) =
    isequal(left.enabled, right.enabled) &&
    isequal(left.focusable, right.focusable) &&
    isequal(left.focused, right.focused) &&
    isequal(left.selected, right.selected) &&
    isequal(left.expanded, right.expanded) &&
    isequal(left.checked, right.checked) &&
    isequal(left.busy, right.busy) &&
    isequal(left.hidden, right.hidden) &&
    isequal(left.invalid, right.invalid) &&
    isequal(left.readonly, right.readonly) &&
    isequal(left.required, right.required) &&
    isequal(left.value, right.value) &&
    isequal(left.value_now, right.value_now) &&
    isequal(left.value_min, right.value_min) &&
    isequal(left.value_max, right.value_max)

function Base.hash(state::SemanticState, seed::UInt)
    return hash(
        (
            state.enabled,
            state.focusable,
            state.focused,
            state.selected,
            state.expanded,
            state.checked,
            state.busy,
            state.hidden,
            state.invalid,
            state.readonly,
            state.required,
            state.value,
            state.value_now,
            state.value_min,
            state.value_max,
        ),
        seed,
    )
end

@enum SemanticAction begin
    ActivateSemanticAction
    FocusSemanticAction
    BlurSemanticAction
    IncrementSemanticAction
    DecrementSemanticAction
    ExpandSemanticAction
    CollapseSemanticAction
    SelectSemanticAction
    DismissSemanticAction
    SetValueSemanticAction
    ScrollIntoViewSemanticAction
end

struct SemanticNode
    id::String
    role::SemanticRole
    label::String
    description::Union{Nothing,String}
    bounds::Union{Nothing,SemanticRect}
    state::SemanticState
    actions::Set{SemanticAction}
    children::Vector{SemanticNode}
    metadata::Dict{Symbol,Any}

    function SemanticNode(
        id,
        role::SemanticRole;
        label::AbstractString="",
        description::Union{Nothing,AbstractString}=nothing,
        bounds::Union{Nothing,SemanticRect}=nothing,
        state::SemanticState=SemanticState(),
        actions=SemanticAction[],
        children=SemanticNode[],
        metadata=Dict{Symbol,Any}(),
    )
        identifier = string(id)
        isempty(identifier) && throw(ArgumentError("semantic node id cannot be empty"))
        new(
            identifier,
            role,
            String(label),
            description === nothing ? nothing : String(description),
            bounds,
            state,
            Set{SemanticAction}(actions),
            SemanticNode[child for child in children],
            Dict{Symbol,Any}(Symbol(key) => value for (key, value) in pairs(metadata)),
        )
    end
end

struct SemanticTree
    root::SemanticNode
    generation::UInt64
end

SemanticTree(root::SemanticNode; generation::Integer=0) = begin
    generation >= 0 || throw(ArgumentError("semantic generation cannot be negative"))
    SemanticTree(root, UInt64(generation))
end

struct SemanticDiagnostic
    severity::Symbol
    node_id::String
    message::String
end

function _walk!(result::Vector{SemanticNode}, node::SemanticNode)
    push!(result, node)
    for child in node.children
        _walk!(result, child)
    end
    return result
end

semantic_nodes(tree::SemanticTree) = _walk!(SemanticNode[], tree.root)

function semantic_node(tree::SemanticTree, id)
    identifier = string(id)
    for node in semantic_nodes(tree)
        node.id == identifier && return node
    end
    return nothing
end

function validate_semantics(tree::SemanticTree)
    diagnostics = SemanticDiagnostic[]
    seen = Set{String}()
    focused = String[]
    for node in semantic_nodes(tree)
        if node.id in seen
            push!(diagnostics, SemanticDiagnostic(:error, node.id, "duplicate semantic id"))
        else
            push!(seen, node.id)
        end
        node.state.focused && push!(focused, node.id)
        node.state.focused && !node.state.focusable &&
            push!(diagnostics, SemanticDiagnostic(:error, node.id, "focused node is not focusable"))
        node.state.hidden && node.state.focused &&
            push!(diagnostics, SemanticDiagnostic(:error, node.id, "hidden node cannot be focused"))
        node.state.value_min !== nothing && node.state.value_max !== nothing &&
            node.state.value_min > node.state.value_max &&
            push!(diagnostics, SemanticDiagnostic(:error, node.id, "value_min exceeds value_max"))
        if node.state.value_now !== nothing
            node.state.value_min !== nothing && node.state.value_now < node.state.value_min &&
                push!(diagnostics, SemanticDiagnostic(:warning, node.id, "value_now is below value_min"))
            node.state.value_max !== nothing && node.state.value_now > node.state.value_max &&
                push!(diagnostics, SemanticDiagnostic(:warning, node.id, "value_now is above value_max"))
        end
        isempty(node.label) && node.role in (ButtonRole, CheckboxRole, RadioRole, TextboxRole, LinkRole, ImageRole) &&
            push!(diagnostics, SemanticDiagnostic(:warning, node.id, "interactive semantic node has no label"))
    end
    length(focused) > 1 && push!(diagnostics, SemanticDiagnostic(:error, tree.root.id, "multiple semantic nodes are focused"))
    return diagnostics
end

function semantic_hit_test(tree::SemanticTree, row::Integer, column::Integer)
    row > 0 || return nothing
    column > 0 || return nothing
    result = nothing
    function visit(node::SemanticNode)
        node.state.hidden && return
        if node.bounds !== nothing && _contains(node.bounds, Int(row), Int(column))
            result = node
        end
        for child in node.children
            visit(child)
        end
    end
    visit(tree.root)
    return result
end

function semantic_focus_order(tree::SemanticTree)
    return SemanticNode[
        node for node in semantic_nodes(tree)
        if node.state.focusable && node.state.enabled && !node.state.hidden
    ]
end

@enum SemanticChangeKind begin
    AddedSemanticNode
    RemovedSemanticNode
    UpdatedSemanticNode
    MovedSemanticNode
end

struct SemanticChange
    kind::SemanticChangeKind
    node_id::String
    before::Union{Nothing,SemanticNode}
    after::Union{Nothing,SemanticNode}
end

function _indexed(tree::SemanticTree)
    nodes = Dict{String,SemanticNode}()
    positions = Dict{String,Tuple{Union{Nothing,String},Int}}()
    function visit(node::SemanticNode, parent, position::Int)
        nodes[node.id] = node
        positions[node.id] = (parent, position)
        for (child_position, child) in enumerate(node.children)
            visit(child, node.id, child_position)
        end
    end
    visit(tree.root, nothing, 1)
    return nodes, positions
end

function _node_payload_equal(left::SemanticNode, right::SemanticNode)
    return left.role == right.role &&
           left.label == right.label &&
           left.description == right.description &&
           left.bounds == right.bounds &&
           left.state == right.state &&
           left.actions == right.actions &&
           left.metadata == right.metadata
end

function diff_semantics(before::SemanticTree, after::SemanticTree)
    old_nodes, old_parents = _indexed(before)
    new_nodes, new_parents = _indexed(after)
    changes = SemanticChange[]
    for id in sort!(collect(setdiff(keys(old_nodes), keys(new_nodes))))
        push!(changes, SemanticChange(RemovedSemanticNode, id, old_nodes[id], nothing))
    end
    for id in sort!(collect(setdiff(keys(new_nodes), keys(old_nodes))))
        push!(changes, SemanticChange(AddedSemanticNode, id, nothing, new_nodes[id]))
    end
    for id in sort!(collect(intersect(keys(old_nodes), keys(new_nodes))))
        old_parents[id] != new_parents[id] &&
            push!(changes, SemanticChange(MovedSemanticNode, id, old_nodes[id], new_nodes[id]))
        _node_payload_equal(old_nodes[id], new_nodes[id]) ||
            push!(changes, SemanticChange(UpdatedSemanticNode, id, old_nodes[id], new_nodes[id]))
    end
    return changes
end

struct SemanticActionRequest
    node_id::String
    action::SemanticAction
    value::Any
end

SemanticActionRequest(node_id, action::SemanticAction; value=nothing) =
    SemanticActionRequest(string(node_id), action, value)

struct SemanticActionResult
    handled::Bool
    message::Union{Nothing,String}
    value::Any
end

SemanticActionResult(handled::Bool; message=nothing, value=nothing) =
    SemanticActionResult(handled, message === nothing ? nothing : String(message), value)

mutable struct SemanticDispatcher
    handlers::Dict{String,Function}
    mutex::ReentrantLock
end

SemanticDispatcher() = SemanticDispatcher(Dict{String,Function}(), ReentrantLock())

function register_semantic_handler!(dispatcher::SemanticDispatcher, node_id, handler::Function)
    lock(dispatcher.mutex) do
        dispatcher.handlers[string(node_id)] = handler
    end
    return dispatcher
end

function unregister_semantic_handler!(dispatcher::SemanticDispatcher, node_id)
    lock(dispatcher.mutex) do
        pop!(dispatcher.handlers, string(node_id), nothing)
    end
    return dispatcher
end

function dispatch_semantic_action!(dispatcher::SemanticDispatcher, request::SemanticActionRequest)
    handler = lock(dispatcher.mutex) do
        get(dispatcher.handlers, request.node_id, nothing)
    end
    handler === nothing && return SemanticActionResult(false; message="no semantic action handler")
    result = handler(request)
    result isa SemanticActionResult && return result
    result isa Bool && return SemanticActionResult(result)
    return SemanticActionResult(true; value=result)
end

@enum LivePoliteness begin
    PoliteAnnouncement
    AssertiveAnnouncement
end

struct SemanticAnnouncement
    sequence::UInt64
    message::String
    politeness::LivePoliteness
    source_id::Union{Nothing,String}
end

mutable struct AnnouncementQueue
    capacity::Int
    items::Vector{SemanticAnnouncement}
    next_sequence::UInt64
    mutex::ReentrantLock

    function AnnouncementQueue(capacity::Integer=128)
        capacity > 0 || throw(ArgumentError("announcement capacity must be positive"))
        new(Int(capacity), SemanticAnnouncement[], 1, ReentrantLock())
    end
end

function announce!(
    queue::AnnouncementQueue,
    message::AbstractString;
    politeness::LivePoliteness=PoliteAnnouncement,
    source_id=nothing,
)
    isempty(message) && return nothing
    return lock(queue.mutex) do
        announcement = SemanticAnnouncement(
            queue.next_sequence,
            String(message),
            politeness,
            source_id === nothing ? nothing : string(source_id),
        )
        queue.next_sequence += 1
        length(queue.items) == queue.capacity && popfirst!(queue.items)
        push!(queue.items, announcement)
        return announcement
    end
end

function take_announcements!(queue::AnnouncementQueue)
    return lock(queue.mutex) do
        result = copy(queue.items)
        empty!(queue.items)
        return result
    end
end

function clear_announcements!(queue::AnnouncementQueue)
    lock(queue.mutex) do
        empty!(queue.items)
    end
    return queue
end

function semantic_snapshot(tree::SemanticTree)
    lines = String[]
    function visit(node::SemanticNode, depth::Int)
        state = String[]
        node.state.focusable && push!(state, "focusable")
        node.state.focused && push!(state, "focused")
        node.state.selected && push!(state, "selected")
        node.state.hidden && push!(state, "hidden")
        node.state.checked != NotCheckable && push!(state, lowercase(string(node.state.checked)))
        suffix = isempty(state) ? "" : " [$(join(state, ','))]"
        label = isempty(node.label) ? "" : " label=$(repr(node.label))"
        push!(lines, repeat("  ", depth) * "$(node.id):$(node.role)$label$suffix")
        for child in node.children
            visit(child, depth + 1)
        end
    end
    visit(tree.root, 0)
    return join(lines, '\n')
end

end
