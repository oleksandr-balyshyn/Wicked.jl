module Interaction

using ..Core: Position, Rect, contains
using ..Events: ALT,
                CAPS_LOCK,
                CTRL,
                HYPER,
                KeyEvent,
                KeyModifiers,
                META,
                NONE,
                NUM_LOCK,
                SHIFT,
                SUPER

struct FocusEntry
    id::Any
    area::Rect
    tab_index::Int
    scope::Any
    disabled::Bool
    hidden::Bool
end

mutable struct FocusRegistry
    entries::Vector{FocusEntry}
    current::Any
    scopes::Vector{Any}
    restore_stack::Vector{Any}
end

struct FocusSnapshot
    scope::Any
    scopes::Vector{Any}
    scope_depth::Int
    restore_targets::Vector{Any}
    restore_depth::Int
    current::Any
    count::Int
    index::Union{Nothing,Int}
    order::Vector{Any}
end

function Base.show(io::IO, snapshot::FocusSnapshot)
    print(
        io,
        "FocusSnapshot(scope=",
        repr(snapshot.scope),
        ", scope_depth=",
        snapshot.scope_depth,
        ", restore_depth=",
        snapshot.restore_depth,
        ", current=",
        repr(snapshot.current),
        ", index=",
        snapshot.index === nothing ? "nothing" : string(snapshot.index),
        "/",
        snapshot.count,
        ", order=",
        repr(snapshot.order),
        ")",
    )
end

FocusRegistry(; scope=:root) = FocusRegistry(FocusEntry[], nothing, Any[scope], Any[])
current_scope(registry::FocusRegistry) = last(registry.scopes)
focus_scopes(registry::FocusRegistry) = Any[scope for scope in registry.scopes]
focus_scope_depth(registry::FocusRegistry) = length(registry.scopes)
focus_restore_targets(registry::FocusRegistry) = Any[target for target in registry.restore_stack]
focus_restore_depth(registry::FocusRegistry) = length(registry.restore_stack)
focus_restore_target(registry::FocusRegistry) =
    isempty(registry.restore_stack) ? nothing : last(registry.restore_stack)
focused(registry::FocusRegistry) = registry.current

function clear_focus!(registry::FocusRegistry)
    was_focused = registry.current !== nothing
    registry.current = nothing
    return was_focused
end

function begin_focus_frame!(registry::FocusRegistry)
    empty!(registry.entries)
    registry
end

function register_focus!(
    registry::FocusRegistry,
    id,
    area::Rect;
    tab_index::Integer=0,
    scope=current_scope(registry),
    disabled::Bool=false,
    hidden::Bool=false,
)
    any(entry -> entry.id == id && entry.scope == scope, registry.entries) &&
        throw(ArgumentError("duplicate focus ID in scope: $id"))
    push!(registry.entries, FocusEntry(id, area, Int(tab_index), scope, disabled, hidden))
    registry
end

function _candidates(registry::FocusRegistry)
    scope = current_scope(registry)
    values = [
        entry for entry in registry.entries
        if entry.scope == scope && !entry.disabled && !entry.hidden && !isempty(entry.area)
    ]
    sort!(values; by=entry -> (entry.tab_index, findfirst(==(entry), registry.entries)))
end

function focus!(registry::FocusRegistry, id)
    candidate = findfirst(
        entry -> entry.id == id && entry.scope == current_scope(registry) &&
                 !entry.disabled && !entry.hidden && !isempty(entry.area),
        registry.entries,
    )
    isnothing(candidate) && return false
    registry.current = id
    true
end

function _focus_step!(registry::FocusRegistry, direction::Int)
    candidates = _candidates(registry)
    isempty(candidates) && (registry.current = nothing; return false)
    current = findfirst(entry -> entry.id == registry.current, candidates)
    index = isnothing(current) ? (direction > 0 ? 1 : length(candidates)) :
            mod1(current + direction, length(candidates))
    registry.current = candidates[index].id
    true
end

focus_next!(registry::FocusRegistry) = _focus_step!(registry, 1)
focus_previous!(registry::FocusRegistry) = _focus_step!(registry, -1)
focus_count(registry::FocusRegistry) = length(_candidates(registry))
focus_order(registry::FocusRegistry) = Any[entry.id for entry in _candidates(registry)]
can_focus(registry::FocusRegistry, id) =
    any(entry -> isequal(entry.id, id), _candidates(registry))

function focus_index(registry::FocusRegistry)
    candidates = _candidates(registry)
    return findfirst(entry -> isequal(entry.id, registry.current), candidates)
end

focus_snapshot(registry::FocusRegistry) = FocusSnapshot(
    current_scope(registry),
    focus_scopes(registry),
    focus_scope_depth(registry),
    focus_restore_targets(registry),
    focus_restore_depth(registry),
    focused(registry),
    focus_count(registry),
    focus_index(registry),
    focus_order(registry),
)

focus_snapshot_record(snapshot::FocusSnapshot) = (
    scope=snapshot.scope,
    scopes=copy(snapshot.scopes),
    scope_depth=snapshot.scope_depth,
    restore_targets=copy(snapshot.restore_targets),
    restore_depth=snapshot.restore_depth,
    current=snapshot.current,
    count=snapshot.count,
    index=snapshot.index,
    order=copy(snapshot.order),
)

focus_snapshot_record(registry::FocusRegistry) =
    focus_snapshot_record(focus_snapshot(registry))

function focus_first!(registry::FocusRegistry)
    candidates = _candidates(registry)
    isempty(candidates) && (registry.current = nothing; return false)
    registry.current = first(candidates).id
    true
end

function focus_last!(registry::FocusRegistry)
    candidates = _candidates(registry)
    isempty(candidates) && (registry.current = nothing; return false)
    registry.current = last(candidates).id
    true
end

_center(entry::FocusEntry) = (
    entry.area.row + (entry.area.height - 1) / 2,
    entry.area.column + (entry.area.width - 1) / 2,
)

function focus_direction!(registry::FocusRegistry, direction::Symbol)
    direction in (:up, :down, :left, :right) ||
        throw(ArgumentError("focus direction must be up, down, left, or right"))
    candidates = _candidates(registry)
    isempty(candidates) && return false
    current_index = findfirst(entry -> entry.id == registry.current, candidates)
    isnothing(current_index) && return _focus_step!(registry, 1)
    row, column = _center(candidates[current_index])
    best = nothing
    best_score = Inf
    for candidate in candidates
        candidate.id == registry.current && continue
        target_row, target_column = _center(candidate)
        primary, secondary = if direction == :up
            row - target_row, abs(column - target_column)
        elseif direction == :down
            target_row - row, abs(column - target_column)
        elseif direction == :left
            column - target_column, abs(row - target_row)
        else
            target_column - column, abs(row - target_row)
        end
        primary <= 0 && continue
        score = primary * 1000 + secondary
        if score < best_score
            best = candidate
            best_score = score
        end
    end
    isnothing(best) && return false
    registry.current = best.id
    true
end

function push_focus_scope!(registry::FocusRegistry, scope)
    push!(registry.restore_stack, registry.current)
    push!(registry.scopes, scope)
    registry.current = nothing
    registry
end

function pop_focus_scope!(registry::FocusRegistry)
    length(registry.scopes) == 1 && return false
    pop!(registry.scopes)
    restored = pop!(registry.restore_stack)
    registry.current = nothing
    restored !== nothing && focus!(registry, restored) && return true
    focus_next!(registry)
    true
end

function focus_at(registry::FocusRegistry, position::Position)
    scope = current_scope(registry)
    index = findlast(
        entry -> entry.scope == scope && !entry.disabled && !entry.hidden &&
                 contains(entry.area, position),
        registry.entries,
    )
    isnothing(index) ? nothing : registry.entries[index].id
end

struct Binding
    key::Symbol
    modifiers::KeyModifiers
    action::Any
    description::String
    priority::Int
end

Binding(
    key::Symbol,
    action;
    modifiers::KeyModifiers=NONE,
    description::AbstractString="",
    priority::Integer=0,
) = Binding(key, modifiers, action, String(description), Int(priority))

mutable struct BindingMap
    bindings::Vector{Binding}
end

struct BindingLayer
    name::Symbol
    map::BindingMap
    active::Bool
end

struct BindingStack
    name::Symbol
    layers::Vector{BindingLayer}
end

struct BindingStackSnapshot
    name::Symbol
    layers::Vector{Symbol}
    active_layers::Vector{Symbol}
    inactive_layers::Vector{Symbol}
    layer_count::Int
    active_count::Int
    inactive_count::Int
    binding_count::Int
    active_binding_count::Int
    documented::Bool
    conflict_count::Int
    conflict_labels::Vector{String}
end

function Base.show(io::IO, snapshot::BindingStackSnapshot)
    print(
        io,
        "BindingStackSnapshot(name=:",
        snapshot.name,
        ", layers=",
        snapshot.layer_count,
        ", active=",
        snapshot.active_count,
        ", inactive=",
        snapshot.inactive_count,
        ", bindings=",
        snapshot.binding_count,
        ", conflicts=",
        snapshot.conflict_count,
        ")",
    )
end

BindingLayer(name::Symbol; active::Bool=true) =
    BindingLayer(name, BindingMap(), active)

BindingLayer(name::Symbol, map::BindingMap; active::Bool=true) =
    BindingLayer(name, map, active)

BindingLayer(name::AbstractString, map::BindingMap=BindingMap(); active::Bool=true) =
    BindingLayer(Symbol(name), map, active=active)

BindingStack(name::Symbol) =
    BindingStack(name, BindingLayer[])

BindingStack(name::AbstractString) =
    BindingStack(Symbol(name), BindingLayer[])

BindingStack(name::Symbol, layers::BindingLayer...) =
    BindingStack(name, BindingLayer[layers...])

BindingStack(layers::BindingLayer...; name::Symbol=:bindings) =
    BindingStack(name, layers...)

BindingMap() = BindingMap(Binding[])
_binding_layer_name(name::Symbol) = name
_binding_layer_name(name::AbstractString) = Symbol(name)
binding_layer_name(layer::BindingLayer) = layer.name
binding_layer_map(layer::BindingLayer) = layer.map
binding_layer_active(layer::BindingLayer) = layer.active
binding_layer_count(layer::BindingLayer) = binding_count(layer.map)
binding_stack_name(stack::BindingStack) = stack.name
binding_stack_layers(stack::BindingStack) = BindingLayer[layer for layer in stack.layers]
active_binding_stack_layers(stack::BindingStack) = BindingLayer[layer for layer in stack.layers if layer.active]
inactive_binding_stack_layers(stack::BindingStack) = BindingLayer[layer for layer in stack.layers if !layer.active]
binding_stack_layer_names(stack::BindingStack) = Symbol[layer.name for layer in stack.layers]
active_binding_stack_layer_names(stack::BindingStack) = Symbol[layer.name for layer in stack.layers if layer.active]
inactive_binding_stack_layer_names(stack::BindingStack) = Symbol[layer.name for layer in stack.layers if !layer.active]
binding_stack_count(stack::BindingStack) = length(stack.layers)
active_binding_stack_count(stack::BindingStack) = length(active_binding_stack_layers(stack))
inactive_binding_stack_count(stack::BindingStack) = length(inactive_binding_stack_layers(stack))
binding_stack_binding_count(stack::BindingStack) =
    sum(binding_layer_count(layer) for layer in stack.layers; init=0)
active_binding_stack_binding_count(stack::BindingStack) =
    sum(binding_layer_count(layer) for layer in stack.layers if layer.active; init=0)

function binding_stack_layer(stack::BindingStack, name)
    target = _binding_layer_name(name)
    index = findfirst(layer -> layer.name == target, stack.layers)
    isnothing(index) ? nothing : stack.layers[index]
end

has_binding_layer(stack::BindingStack, name) =
    binding_stack_layer(stack, name) !== nothing

has_active_binding_layer(stack::BindingStack, name) =
    (layer = binding_stack_layer(stack, name); layer !== nothing && layer.active)

function activate_binding_layer!(stack::BindingStack, name)
    layer = assert_binding_stack_layer(stack, name)
    active = BindingLayer(layer.name, layer.map, active=true)
    replace_binding_layer!(stack, active)
    return active
end

function deactivate_binding_layer!(stack::BindingStack, name)
    layer = assert_binding_stack_layer(stack, name)
    inactive = BindingLayer(layer.name, layer.map, active=false)
    replace_binding_layer!(stack, inactive)
    return inactive
end

function assert_binding_stack_layer(stack::BindingStack, name)
    layer = binding_stack_layer(stack, name)
    layer !== nothing && return layer
    throw(ArgumentError("binding stack $(stack.name) does not contain layer: $(_binding_layer_name(name))"))
end

function push_binding_layer!(stack::BindingStack, layer::BindingLayer)
    push!(stack.layers, layer)
    return stack
end

function prepend_binding_layer!(stack::BindingStack, layer::BindingLayer)
    pushfirst!(stack.layers, layer)
    return stack
end

function remove_binding_layer!(stack::BindingStack, name)
    target = _binding_layer_name(name)
    index = findfirst(layer -> layer.name == target, stack.layers)
    isnothing(index) && return nothing
    return splice!(stack.layers, index)
end

function replace_binding_layer!(stack::BindingStack, layer::BindingLayer)
    index = findfirst(existing -> existing.name == layer.name, stack.layers)
    isnothing(index) && return nothing
    previous = stack.layers[index]
    stack.layers[index] = layer
    return previous
end

function upsert_binding_layer!(stack::BindingStack, layer::BindingLayer; position::Symbol=:append)
    position in (:append, :prepend) ||
        throw(ArgumentError("binding stack insertion position must be :append or :prepend"))
    previous = replace_binding_layer!(stack, layer)
    previous === nothing || return stack
    position === :prepend ? prepend_binding_layer!(stack, layer) : push_binding_layer!(stack, layer)
    return stack
end

function binding_layer_summary(layer::BindingLayer)
    summary = binding_summary(layer.map)
    return (
        layer=layer.name,
        total=summary.total,
        described=summary.described,
        undocumented=summary.undocumented,
    )
end

binding_layers_summary(layers::BindingLayer...) =
    [binding_layer_summary(layer) for layer in layers]

function binding_stack_summary(stack::BindingStack)
    summaries = binding_layers_summary(stack.layers...)
    return (
        stack=stack.name,
        layers=length(stack.layers),
        active=active_binding_stack_count(stack),
        inactive=inactive_binding_stack_count(stack),
        total=sum(summary.total for summary in summaries; init=0),
        described=sum(summary.described for summary in summaries; init=0),
        undocumented=sum(summary.undocumented for summary in summaries; init=0),
    )
end

function binding_stack_snapshot(stack::BindingStack)
    conflicts = binding_stack_conflicts(stack)
    return BindingStackSnapshot(
        stack.name,
        binding_stack_layer_names(stack),
        active_binding_stack_layer_names(stack),
        inactive_binding_stack_layer_names(stack),
        binding_stack_count(stack),
        active_binding_stack_count(stack),
        inactive_binding_stack_count(stack),
        binding_stack_binding_count(stack),
        active_binding_stack_binding_count(stack),
        binding_stack_documented(stack),
        length(conflicts),
        String[conflict.label for conflict in conflicts],
    )
end

binding_stack_snapshot_record(snapshot::BindingStackSnapshot) = (
    name=snapshot.name,
    layers=copy(snapshot.layers),
    active_layers=copy(snapshot.active_layers),
    inactive_layers=copy(snapshot.inactive_layers),
    layer_count=snapshot.layer_count,
    active_count=snapshot.active_count,
    inactive_count=snapshot.inactive_count,
    binding_count=snapshot.binding_count,
    active_binding_count=snapshot.active_binding_count,
    documented=snapshot.documented,
    conflict_count=snapshot.conflict_count,
    conflict_labels=copy(snapshot.conflict_labels),
)

binding_stack_snapshot_record(stack::BindingStack) =
    binding_stack_snapshot_record(binding_stack_snapshot(stack))

binding_count(map::BindingMap) = length(map.bindings)
const _BINDING_MODIFIER_LABELS = (
    (CTRL, "Ctrl"),
    (ALT, "Alt"),
    (SHIFT, "Shift"),
    (SUPER, "Super"),
    (HYPER, "Hyper"),
    (META, "Meta"),
    (CAPS_LOCK, "CapsLock"),
    (NUM_LOCK, "NumLock"),
)

function binding_label(key::Symbol; modifiers::KeyModifiers=NONE)
    parts = String[label for (modifier, label) in _BINDING_MODIFIER_LABELS if modifier in modifiers]
    push!(parts, string(key))
    return join(parts, "+")
end

binding_label(binding::Binding) =
    binding_label(binding.key; modifiers=binding.modifiers)

function binding_label(record::NamedTuple)
    haskey(record, :key) && haskey(record, :modifiers) ||
        throw(ArgumentError("binding label record must contain key and modifiers fields"))
    return binding_label(record.key; modifiers=record.modifiers)
end

function binding_help_line(record::NamedTuple; separator::AbstractString="  ")
    haskey(record, :description) ||
        throw(ArgumentError("binding help record must contain a description field"))
    label = binding_label(record)
    description = String(record.description)
    isempty(description) && return label
    return string(label, separator, description)
end

binding_help_line(binding::Binding; separator::AbstractString="  ") =
    binding_help_line(
        (
            key=binding.key,
            modifiers=binding.modifiers,
            action=binding.action,
            description=binding.description,
            priority=binding.priority,
        );
        separator,
    )

binding_help_lines(map::BindingMap; separator::AbstractString="  ") = [
    binding_help_line(record; separator)
    for record in described_binding_display_records(map)
]

binding_help_text(
    map::BindingMap;
    separator::AbstractString="  ",
    newline::AbstractString="\n",
) = join(binding_help_lines(map; separator), newline)

_binding_table_escape(value) =
    replace(replace(string(value), "|" => "\\|"), "\n" => " ")

_binding_tsv_escape(value) =
    replace(replace(string(value), "\t" => " "), "\n" => " ")

_binding_json_string(value) =
    "\"" * replace(string(value), "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t") * "\""

function _binding_display_markdown(records; columns)
    output = String[
        "| $(join(("`$(column)`" for column in columns), " | ")) |",
        "| $(join(fill("---", length(columns)), " | ")) |",
    ]
    for record in records
        push!(output, "| $(join((_binding_table_escape(getproperty(record, column)) for column in columns), " | ")) |")
    end
    return join(output, "\n")
end

function _binding_display_tsv(records; columns, header::Bool=true)
    output = header ? String[join((String(column) for column in columns), "\t")] : String[]
    for record in records
        push!(output, join((_binding_tsv_escape(getproperty(record, column)) for column in columns), "\t"))
    end
    return join(output, "\n")
end

function _binding_display_json(records; columns)
    output = String[
        "{",
        "  \"schema_version\": 1,",
        "  \"count\": $(length(records)),",
        "  \"records\": [",
    ]
    for (index, record) in enumerate(records)
        fields = join(("\"$(column)\": $(_binding_json_string(getproperty(record, column)))" for column in columns), ", ")
        suffix = index == length(records) ? "" : ","
        push!(output, "    {$fields}$suffix")
    end
    push!(output, "  ]")
    push!(output, "}")
    return join(output, "\n")
end

"""
    binding_help_markdown(map)

Render described bindings in `map` as a Markdown table.
"""
binding_help_markdown(map::BindingMap) =
    _binding_display_markdown(described_binding_display_records(map); columns=(:label, :action, :description, :priority))

"""
    binding_help_json(map)

Render described bindings in `map` as schema-versioned JSON.
"""
binding_help_json(map::BindingMap) =
    _binding_display_json(described_binding_display_records(map); columns=(:label, :action, :description, :priority))

"""
    binding_help_tsv(map; header=true)

Render described bindings in `map` as tab-separated values.
"""
binding_help_tsv(map::BindingMap; header::Bool=true) =
    _binding_display_tsv(described_binding_display_records(map); columns=(:label, :action, :description, :priority), header)

function binding_summary(map::BindingMap)
    total = binding_count(map)
    described = length(described_bindings(map))
    return (
        total=total,
        described=described,
        undocumented=total - described,
    )
end

binding_keys(map::BindingMap) = [
    (key=binding.key, modifiers=binding.modifiers)
    for binding in map.bindings
]
has_binding(map::BindingMap, key::Symbol; modifiers::KeyModifiers=NONE) =
    any(binding -> binding.key == key && binding.modifiers == modifiers, map.bindings)
has_binding(layer::BindingLayer, key::Symbol; modifiers::KeyModifiers=NONE) =
    has_binding(layer.map, key; modifiers)
binding_records(map::BindingMap) = [
    (
        key=binding.key,
        modifiers=binding.modifiers,
        action=binding.action,
        description=binding.description,
        priority=binding.priority,
    )
    for binding in map.bindings
]

binding_layer_keys(layer::BindingLayer) = [
    merge(record, (layer=layer.name,))
    for record in binding_keys(layer.map)
]

binding_stack_keys(stack::BindingStack) = [
    merge(record, (stack=stack.name,))
    for layer in active_binding_stack_layers(stack)
    for record in binding_layer_keys(layer)
]

function binding_layer_record(layer::BindingLayer, key::Symbol; modifiers::KeyModifiers=NONE)
    record = binding_record(layer.map, key; modifiers)
    record === nothing && return nothing
    return merge(record, (layer=layer.name, label=binding_label(record)))
end

binding_layer_records(layer::BindingLayer) = [
    merge(record, (layer=layer.name,))
    for record in binding_records(layer.map)
]

binding_stack_records(stack::BindingStack) = [
    merge(record, (stack=stack.name,))
    for layer in active_binding_stack_layers(stack)
    for record in binding_layer_records(layer)
]

undocumented_binding_layer_records(layer::BindingLayer) = [
    record for record in binding_layer_records(layer)
    if isempty(record.description)
]

binding_layer_documented(layer::BindingLayer) =
    isempty(undocumented_binding_layer_records(layer))

function assert_binding_layer_documented(layer::BindingLayer)
    missing = undocumented_binding_layer_records(layer)
    isempty(missing) && return layer
    labels = join((string(record.layer, ": ", binding_label(record)) for record in missing), ", ")
    throw(ArgumentError("binding layer has undocumented bindings: $labels"))
end

function undocumented_binding_layers_records(layers::BindingLayer...)
    records = NamedTuple[]
    for layer in layers
        append!(records, undocumented_binding_layer_records(layer))
    end
    return records
end

binding_layers_documented(layers::BindingLayer...) =
    isempty(undocumented_binding_layers_records(layers...))

function assert_binding_layers_documented(layers::BindingLayer...)
    missing = undocumented_binding_layers_records(layers...)
    isempty(missing) && return layers
    labels = join((string(record.layer, ": ", binding_label(record)) for record in missing), ", ")
    throw(ArgumentError("binding layers have undocumented bindings: $labels"))
end

undocumented_binding_stack_records(stack::BindingStack) =
    undocumented_binding_layers_records(active_binding_stack_layers(stack)...)

binding_stack_documented(stack::BindingStack) =
    binding_layers_documented(active_binding_stack_layers(stack)...)

function assert_binding_stack_documented(stack::BindingStack)
    missing = undocumented_binding_stack_records(stack)
    isempty(missing) && return stack
    labels = join((string(record.layer, ": ", binding_label(record)) for record in missing), ", ")
    throw(ArgumentError("binding stack has undocumented bindings: $labels"))
end

binding_layer_display_records(layer::BindingLayer) = [
    merge(record, (label=binding_label(record),))
    for record in binding_layer_records(layer)
]

binding_stack_display_records(stack::BindingStack) = [
    merge(record, (stack=stack.name,))
    for layer in active_binding_stack_layers(stack)
    for record in binding_layer_display_records(layer)
]

described_binding_layer_display_records(layer::BindingLayer) = [
    record for record in binding_layer_display_records(layer)
    if !isempty(record.description)
]

described_binding_stack_display_records(stack::BindingStack) = [
    record for record in binding_stack_display_records(stack)
    if !isempty(record.description)
]

function binding_layer_help_lines(
    layer::BindingLayer;
    separator::AbstractString="  ",
    prefix::Bool=true,
)
    return String[
        string(prefix ? string(layer.name, ": ") : "", binding_help_line(record; separator))
        for record in described_binding_layer_display_records(layer)
    ]
end

binding_layer_help_text(
    layer::BindingLayer;
    separator::AbstractString="  ",
    newline::AbstractString="\n",
    prefix::Bool=true,
) = join(binding_layer_help_lines(layer; separator, prefix), newline)

function binding_layers_help_lines(
    layers::BindingLayer...;
    separator::AbstractString="  ",
    prefix::Bool=true,
)
    lines = String[]
    for layer in layers
        append!(lines, binding_layer_help_lines(layer; separator, prefix))
    end
    return lines
end

binding_layers_help_text(
    layers::BindingLayer...;
    separator::AbstractString="  ",
    newline::AbstractString="\n",
    prefix::Bool=true,
) = join(binding_layers_help_lines(layers...; separator, prefix), newline)

binding_stack_help_lines(
    stack::BindingStack;
    separator::AbstractString="  ",
    prefix::Bool=true,
) = binding_layers_help_lines(active_binding_stack_layers(stack)...; separator, prefix)

binding_stack_help_text(
    stack::BindingStack;
    separator::AbstractString="  ",
    newline::AbstractString="\n",
    prefix::Bool=true,
) = binding_layers_help_text(active_binding_stack_layers(stack)...; separator, newline, prefix)

"""
    binding_layer_help_markdown(layer)

Render described bindings in `layer` as a Markdown table.
"""
binding_layer_help_markdown(layer::BindingLayer) =
    _binding_display_markdown(described_binding_layer_display_records(layer); columns=(:layer, :label, :action, :description, :priority))

"""
    binding_layer_help_json(layer)

Render described bindings in `layer` as schema-versioned JSON.
"""
binding_layer_help_json(layer::BindingLayer) =
    _binding_display_json(described_binding_layer_display_records(layer); columns=(:layer, :label, :action, :description, :priority))

"""
    binding_layer_help_tsv(layer; header=true)

Render described bindings in `layer` as tab-separated values.
"""
binding_layer_help_tsv(layer::BindingLayer; header::Bool=true) =
    _binding_display_tsv(described_binding_layer_display_records(layer); columns=(:layer, :label, :action, :description, :priority), header)

"""
    binding_stack_help_markdown(stack)

Render described active bindings in `stack` as a Markdown table.
"""
binding_stack_help_markdown(stack::BindingStack) =
    _binding_display_markdown(described_binding_stack_display_records(stack); columns=(:stack, :layer, :label, :action, :description, :priority))

"""
    binding_stack_help_json(stack)

Render described active bindings in `stack` as schema-versioned JSON.
"""
binding_stack_help_json(stack::BindingStack) =
    _binding_display_json(described_binding_stack_display_records(stack); columns=(:stack, :layer, :label, :action, :description, :priority))

"""
    binding_stack_help_tsv(stack; header=true)

Render described active bindings in `stack` as tab-separated values.
"""
binding_stack_help_tsv(stack::BindingStack; header::Bool=true) =
    _binding_display_tsv(described_binding_stack_display_records(stack); columns=(:stack, :layer, :label, :action, :description, :priority), header)

described_bindings(map::BindingMap) = [
    record for record in binding_records(map)
    if !isempty(record.description)
]

undocumented_bindings(map::BindingMap) = [
    record for record in binding_records(map)
    if isempty(record.description)
]

bindings_documented(map::BindingMap) = isempty(undocumented_bindings(map))

binding_display_records(map::BindingMap) = [
    merge(record, (label=binding_label(record),))
    for record in binding_records(map)
]

function assert_bindings_documented(map::BindingMap)
    missing = undocumented_bindings(map)
    isempty(missing) && return map
    labels = join((binding_label(record) for record in missing), ", ")
    throw(ArgumentError("binding map has undocumented bindings: $labels"))
end

described_binding_display_records(map::BindingMap) = [
    record for record in binding_display_records(map)
    if !isempty(record.description)
]

function binding_record(map::BindingMap, key::Symbol; modifiers::KeyModifiers=NONE)
    index = findfirst(
        binding -> binding.key == key && binding.modifiers == modifiers,
        map.bindings,
    )
    isnothing(index) && return nothing
    binding = map.bindings[index]
    return (
        key=binding.key,
        modifiers=binding.modifiers,
        action=binding.action,
        description=binding.description,
        priority=binding.priority,
    )
end

binding_conflict(map::BindingMap, binding::Binding) =
    binding_record(map, binding.key; modifiers=binding.modifiers)

function binding_conflicts(target::BindingMap, source::BindingMap)
    conflicts = NamedTuple[]
    for binding in source.bindings
        existing = binding_conflict(target, binding)
        existing === nothing && continue
        push!(
            conflicts,
            (
                key=binding.key,
                modifiers=binding.modifiers,
                label=binding_label(binding),
                existing=existing,
                incoming=(
                    key=binding.key,
                    modifiers=binding.modifiers,
                    action=binding.action,
                    description=binding.description,
                    priority=binding.priority,
                ),
            ),
        )
    end
    return conflicts
end

binding_conflict_labels(target::BindingMap, source::BindingMap) =
    String[conflict.label for conflict in binding_conflicts(target, source)]

has_binding_conflicts(target::BindingMap, source::BindingMap) =
    !isempty(binding_conflicts(target, source))

function assert_no_binding_conflicts(target::BindingMap, source::BindingMap)
    conflicts = binding_conflicts(target, source)
    isempty(conflicts) && return source
    labels = join((conflict.label for conflict in conflicts), ", ")
    throw(ArgumentError("binding maps have conflicting shortcuts: $labels"))
end

function bind!(map::BindingMap, binding::Binding)
    filter!(
        existing -> existing.key != binding.key || existing.modifiers != binding.modifiers,
        map.bindings,
    )
    push!(map.bindings, binding)
    sort!(map.bindings; by=binding -> -binding.priority)
    map
end

function bind!(layer::BindingLayer, binding::Binding)
    bind!(layer.map, binding)
    return layer
end

function bind_strict!(map::BindingMap, binding::Binding)
    conflict = binding_conflict(map, binding)
    if conflict !== nothing
        throw(ArgumentError("binding already exists for $(binding_label(conflict)); use bind! to replace it explicitly"))
    end
    bind!(map, binding)
end

function bind_strict!(layer::BindingLayer, binding::Binding)
    bind_strict!(layer.map, binding)
    return layer
end

function merge_bindings!(target::BindingMap, source::BindingMap; conflict::Symbol=:replace)
    conflict in (:replace, :skip, :error) ||
        throw(ArgumentError("binding merge conflict policy must be :replace, :skip, or :error"))
    for binding in source.bindings
        if conflict === :replace
            bind!(target, binding)
        elseif conflict === :skip
            binding_conflict(target, binding) === nothing && bind!(target, binding)
        else
            bind_strict!(target, binding)
        end
    end
    target
end

function merge_bindings!(target::BindingLayer, source::BindingMap; conflict::Symbol=:replace)
    merge_bindings!(target.map, source; conflict)
    return target
end

merge_bindings!(target::BindingMap, source::BindingLayer; conflict::Symbol=:replace) =
    merge_bindings!(target, source.map; conflict)

function merge_bindings!(target::BindingLayer, source::BindingLayer; conflict::Symbol=:replace)
    merge_bindings!(target.map, source.map; conflict)
    return target
end

function binding_layer_conflicts(existing::BindingLayer, incoming::BindingLayer)
    return [
        merge(conflict, (existing_layer=existing.name, incoming_layer=incoming.name))
        for conflict in binding_conflicts(existing.map, incoming.map)
    ]
end

binding_layer_conflict_labels(existing::BindingLayer, incoming::BindingLayer) =
    String[conflict.label for conflict in binding_layer_conflicts(existing, incoming)]

has_binding_layer_conflicts(existing::BindingLayer, incoming::BindingLayer) =
    !isempty(binding_layer_conflicts(existing, incoming))

function assert_no_binding_layer_conflicts(existing::BindingLayer, incoming::BindingLayer)
    conflicts = binding_layer_conflicts(existing, incoming)
    isempty(conflicts) && return incoming
    labels = join((string(conflict.existing_layer, " vs ", conflict.incoming_layer, ": ", conflict.label) for conflict in conflicts), ", ")
    throw(ArgumentError("binding layers have conflicting shortcuts: $labels"))
end

function binding_stack_conflicts(stack::BindingStack)
    conflicts = NamedTuple[]
    active_layers = active_binding_stack_layers(stack)
    for incoming_index in 2:length(active_layers)
        incoming = active_layers[incoming_index]
        for existing in @view active_layers[1:(incoming_index - 1)]
            append!(
                conflicts,
                (
                    merge(conflict, (stack=stack.name,))
                    for conflict in binding_layer_conflicts(existing, incoming)
                ),
            )
        end
    end
    return conflicts
end

binding_stack_conflict_labels(stack::BindingStack) =
    String[conflict.label for conflict in binding_stack_conflicts(stack)]

has_binding_stack_conflicts(stack::BindingStack) =
    !isempty(binding_stack_conflicts(stack))

function assert_no_binding_stack_conflicts(stack::BindingStack)
    conflicts = binding_stack_conflicts(stack)
    isempty(conflicts) && return stack
    labels = join((string(conflict.existing_layer, " vs ", conflict.incoming_layer, ": ", conflict.label) for conflict in conflicts), ", ")
    throw(ArgumentError("binding stack has conflicting shortcuts: $labels"))
end

function merged_bindings(maps::BindingMap...; conflict::Symbol=:replace)
    target = BindingMap()
    for map in maps
        merge_bindings!(target, map; conflict)
    end
    target
end

function merged_binding_layers(layers::BindingLayer...; conflict::Symbol=:replace)
    target = BindingMap()
    for layer in layers
        merge_bindings!(target, layer.map; conflict)
    end
    target
end

merged_binding_stack(stack::BindingStack; conflict::Symbol=:replace) =
    merged_binding_layers(active_binding_stack_layers(stack)...; conflict)

function unbind!(map::BindingMap, key::Symbol; modifiers::KeyModifiers=NONE)
    previous = length(map.bindings)
    filter!(binding -> binding.key != key || binding.modifiers != modifiers, map.bindings)
    length(map.bindings) != previous
end

unbind!(layer::BindingLayer, key::Symbol; modifiers::KeyModifiers=NONE) =
    unbind!(layer.map, key; modifiers)

function resolve_binding(map::BindingMap, event::KeyEvent)
    index = findfirst(
        binding -> binding.key == event.key.code && binding.modifiers == event.modifiers,
        map.bindings,
    )
    isnothing(index) ? nothing : map.bindings[index].action
end

function resolve_binding_record(map::BindingMap, event::KeyEvent)
    binding = binding_record(map, event.key.code; modifiers=event.modifiers)
    binding === nothing && return nothing
    return merge(binding, (label=binding_label(binding),))
end

function resolve_binding_layer(layer::BindingLayer, event::KeyEvent)
    record = resolve_binding_record(layer.map, event)
    record === nothing && return nothing
    return merge(record, (layer=layer.name,))
end

function resolve_binding_layers(layers::BindingLayer...; event::KeyEvent)
    for layer in layers
        resolved = resolve_binding_layer(layer, event)
        resolved === nothing || return resolved
    end
    return nothing
end

resolve_binding_stack(stack::BindingStack, event::KeyEvent) =
    resolve_binding_layers(active_binding_stack_layers(stack)...; event)

export Binding,
       BindingLayer,
       BindingStack,
       BindingStackSnapshot,
       BindingMap,
       FocusEntry,
       FocusRegistry,
       FocusSnapshot,
       activate_binding_layer!,
       active_binding_stack_binding_count,
       active_binding_stack_count,
       active_binding_stack_layer_names,
       active_binding_stack_layers,
       assert_binding_layer_documented,
       assert_binding_layers_documented,
       assert_binding_stack_documented,
       assert_binding_stack_layer,
       assert_bindings_documented,
       assert_no_binding_layer_conflicts,
       assert_no_binding_stack_conflicts,
       assert_no_binding_conflicts,
       begin_focus_frame!,
       bind!,
       bind_strict!,
       binding_conflict,
       binding_conflict_labels,
       binding_conflicts,
       binding_count,
       binding_display_records,
       binding_help_line,
       binding_help_lines,
       binding_help_json,
       binding_help_markdown,
       binding_help_text,
       binding_help_tsv,
       binding_keys,
       binding_label,
       binding_layer_active,
       binding_layer_conflict_labels,
       binding_layer_conflicts,
       binding_layer_count,
       binding_layer_documented,
       binding_layer_display_records,
       binding_layer_help_lines,
       binding_layer_help_json,
       binding_layer_help_markdown,
       binding_layer_help_text,
       binding_layer_help_tsv,
       binding_layer_keys,
       binding_layer_map,
       binding_layer_name,
       binding_layer_record,
       binding_layer_records,
       binding_layer_summary,
       binding_layers_documented,
       binding_layers_help_lines,
       binding_layers_help_text,
       binding_layers_summary,
       binding_record,
       binding_records,
       binding_stack_binding_count,
       binding_stack_conflict_labels,
       binding_stack_conflicts,
       binding_stack_count,
       binding_stack_documented,
       binding_stack_display_records,
       binding_stack_help_lines,
       binding_stack_help_json,
       binding_stack_help_markdown,
       binding_stack_help_text,
       binding_stack_help_tsv,
       binding_stack_keys,
       binding_stack_layer,
       binding_stack_layer_names,
       binding_stack_layers,
       binding_stack_name,
       binding_stack_records,
       binding_stack_snapshot,
       binding_stack_snapshot_record,
       binding_stack_summary,
       binding_summary,
       bindings_documented,
       can_focus,
       clear_focus!,
       current_scope,
       deactivate_binding_layer!,
       described_binding_layer_display_records,
       described_binding_display_records,
       described_binding_stack_display_records,
       described_bindings,
       focus!,
       focus_at,
       focus_count,
       focus_direction!,
       focus_first!,
       focus_index,
       focus_last!,
       focus_next!,
       focus_previous!,
       focus_order,
       focus_restore_depth,
       focus_restore_target,
       focus_restore_targets,
       focus_scope_depth,
       focus_scopes,
       focus_snapshot,
       focus_snapshot_record,
       focused,
       has_binding,
       has_binding_conflicts,
       has_active_binding_layer,
       has_binding_layer_conflicts,
       has_binding_layer,
       has_binding_stack_conflicts,
       inactive_binding_stack_count,
       inactive_binding_stack_layer_names,
       inactive_binding_stack_layers,
       merge_bindings!,
       merged_binding_layers,
       merged_binding_stack,
       merged_bindings,
       pop_focus_scope!,
       prepend_binding_layer!,
       push_binding_layer!,
       push_focus_scope!,
       register_focus!,
       resolve_binding,
       resolve_binding_layer,
       resolve_binding_layers,
       resolve_binding_record,
       resolve_binding_stack,
       remove_binding_layer!,
       replace_binding_layer!,
       undocumented_binding_layer_records,
       undocumented_binding_layers_records,
       undocumented_binding_stack_records,
       undocumented_bindings,
       upsert_binding_layer!,
       unbind!

end
