module Interaction

using ..Core: Position, Rect, contains
using ..Events: KeyEvent, KeyModifiers, NONE

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

FocusRegistry(; scope=:root) = FocusRegistry(FocusEntry[], nothing, Any[scope], Any[])
current_scope(registry::FocusRegistry) = last(registry.scopes)
focused(registry::FocusRegistry) = registry.current

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
                 !entry.disabled && !entry.hidden,
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
    registry.current = pop!(registry.restore_stack)
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

BindingMap() = BindingMap(Binding[])

function bind!(map::BindingMap, binding::Binding)
    filter!(
        existing -> existing.key != binding.key || existing.modifiers != binding.modifiers,
        map.bindings,
    )
    push!(map.bindings, binding)
    sort!(map.bindings; by=binding -> -binding.priority)
    map
end

function unbind!(map::BindingMap, key::Symbol; modifiers::KeyModifiers=NONE)
    previous = length(map.bindings)
    filter!(binding -> binding.key != key || binding.modifiers != modifiers, map.bindings)
    length(map.bindings) != previous
end

function resolve_binding(map::BindingMap, event::KeyEvent)
    index = findfirst(
        binding -> binding.key == event.key.code && binding.modifiers == event.modifiers,
        map.bindings,
    )
    isnothing(index) ? nothing : map.bindings[index].action
end

export Binding,
       BindingMap,
       FocusEntry,
       FocusRegistry,
       begin_focus_frame!,
       bind!,
       current_scope,
       focus!,
       focus_at,
       focus_direction!,
       focus_next!,
       focus_previous!,
       focused,
       pop_focus_scope!,
       push_focus_scope!,
       register_focus!,
       resolve_binding,
       unbind!

end
