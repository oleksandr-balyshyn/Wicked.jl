using .Events: KeyEvent, KeyModifiers, NONE
using .Interaction: Binding, BindingMap, bind!
using .Widgets: CommandItem


"""Application state supplied to action predicates and handlers."""
struct ActionContext{A,S,F,E,D}
    application::A
    screen::S
    focused::F
    event::E
    data::D
end

ActionContext(;
    application=nothing,
    screen=nothing,
    focused=nothing,
    event=nothing,
    data=nothing,
) = ActionContext(application, screen, focused, event, data)

"""A keyboard shortcut advertised by an action."""
struct ActionBinding
    key::Symbol
    modifiers::KeyModifiers
    description::String
    priority::Int
end

function ActionBinding(
    key::Symbol;
    modifiers::KeyModifiers=NONE,
    description::AbstractString="",
    priority::Integer=0,
)
    return ActionBinding(key, modifiers, String(description), Int(priority))
end

"""
Discoverable named behavior.

Predicates receive `ActionContext`; the handler receives the same context and may
return an `AbstractCommand`, application message, task descriptor, or ordinary
value chosen by the application.
"""
struct Action
    id::Symbol
    title::String
    description::String
    category::String
    keywords::Vector{String}
    handler::Any
    enabled::Any
    visible::Any
    checked::Any
    bindings::Vector{ActionBinding}
    priority::Int
end

function Action(
    id::Symbol,
    title::AbstractString,
    handler;
    description::AbstractString="",
    category::AbstractString="General",
    keywords=String[],
    enabled=context -> true,
    visible=context -> true,
    checked=context -> false,
    bindings=ActionBinding[],
    priority::Integer=0,
)
    return Action(
        id,
        String(title),
        String(description),
        String(category),
        unique(lowercase.(String.(keywords))),
        handler,
        enabled,
        visible,
        checked,
        ActionBinding[binding for binding in bindings],
        Int(priority),
    )
end

struct ActionState
    action::Action
    scope::Symbol
    enabled::Bool
    visible::Bool
    checked::Bool
    error::Union{Nothing,CapturedException}
end

@enum ActionInvocationStatus::UInt8 begin
    ActionInvoked
    ActionMissing
    ActionDisabled
    ActionFailed
end

struct ActionInvocation
    id::Symbol
    status::ActionInvocationStatus
    value::Any
    error::Union{Nothing,CapturedException}
end

struct _ActionRegistration
    action::Action
    scope::Symbol
    sequence::UInt64
end

mutable struct ActionRegistry
    registrations::Dict{Symbol,Dict{Symbol,_ActionRegistration}}
    scopes::Vector{Symbol}
    errors::Vector{CapturedException}
    sequence::UInt64
    generation::UInt64
    mutex::ReentrantLock
end

ActionRegistry() = ActionRegistry(
    Dict{Symbol,Dict{Symbol,_ActionRegistration}}(),
    Symbol[:global],
    CapturedException[],
    UInt64(0),
    UInt64(0),
    ReentrantLock(),
)

function _next_action_counter(value::UInt64, name::AbstractString)
    value == typemax(UInt64) && throw(OverflowError("$name exhausted"))
    return value + UInt64(1)
end

function register_action!(
    registry::ActionRegistry,
    action::Action;
    scope::Symbol=:global,
    replace::Bool=false,
)
    return lock(registry.mutex) do
        sequence = _next_action_counter(registry.sequence, "action registration sequence")
        generation = _next_action_counter(registry.generation, "action registry generation")
        registrations = copy(registry.registrations)
        scoped = copy(get(registrations, action.id, Dict{Symbol,_ActionRegistration}()))
        haskey(scoped, scope) && !replace &&
            throw(ArgumentError("action $(action.id) is already registered in scope $scope"))
        scoped[scope] = _ActionRegistration(action, scope, sequence)
        registrations[action.id] = scoped
        registry.registrations = registrations
        registry.sequence = sequence
        registry.generation = generation
        return registry
    end
end

function unregister_action!(registry::ActionRegistry, id::Symbol; scope::Symbol=:global)
    return lock(registry.mutex) do
        scoped = get(registry.registrations, id, nothing)
        scoped === nothing && return false
        haskey(scoped, scope) || return false
        generation = _next_action_counter(registry.generation, "action registry generation")
        registrations = copy(registry.registrations)
        updated = copy(scoped)
        delete!(updated, scope)
        isempty(updated) ? delete!(registrations, id) : (registrations[id] = updated)
        registry.registrations = registrations
        registry.generation = generation
        return true
    end
end

function _normalize_action_scopes(scopes)
    resolved = Symbol[:global]
    for scope in scopes
        identifier = Symbol(scope)
        identifier == :global && continue
        identifier in resolved || push!(resolved, identifier)
    end
    return resolved
end

function set_action_scopes!(registry::ActionRegistry, scopes)
    resolved = _normalize_action_scopes(scopes)
    lock(registry.mutex) do
        registry.scopes == resolved && return registry
        generation = _next_action_counter(registry.generation, "action registry generation")
        registry.scopes = resolved
        registry.generation = generation
    end
    return registry
end

function activate_action_scope!(registry::ActionRegistry, scope::Symbol)
    scope == :global && return registry
    lock(registry.mutex) do
        !isempty(registry.scopes) && last(registry.scopes) == scope && return registry
        generation = _next_action_counter(registry.generation, "action registry generation")
        scopes = Symbol[candidate for candidate in registry.scopes if candidate != scope]
        push!(scopes, scope)
        registry.scopes = scopes
        registry.generation = generation
    end
    return registry
end

function deactivate_action_scope!(registry::ActionRegistry, scope::Symbol)
    scope == :global && return false
    return lock(registry.mutex) do
        scope in registry.scopes || return false
        generation = _next_action_counter(registry.generation, "action registry generation")
        registry.scopes = Symbol[candidate for candidate in registry.scopes if candidate != scope]
        registry.generation = generation
        return true
    end
end

active_action_scopes(registry::ActionRegistry) = lock(registry.mutex) do
    copy(registry.scopes)
end

action_registry_generation(registry::ActionRegistry) = lock(registry.mutex) do
    registry.generation
end

function _resolve_action_locked(registry::ActionRegistry, id::Symbol)
    scoped = get(registry.registrations, id, nothing)
    scoped === nothing && return nothing
    for scope in Iterators.reverse(registry.scopes)
        registration = get(scoped, scope, nothing)
        registration === nothing || return registration
    end
    return nothing
end

function _capture_action_error!(registry::ActionRegistry, captured::CapturedException)
    lock(registry.mutex) do
        push!(registry.errors, captured)
    end
    return captured
end

function _evaluate_action_predicate(registry::ActionRegistry, predicate, context, fallback::Bool)
    try
        applicable(predicate, context) ||
            throw(ArgumentError("action predicate must accept ActionContext"))
        value = predicate(context)
        value isa Bool || throw(ArgumentError("action predicate must return Bool"))
        return value, nothing
    catch error
        captured = CapturedException(error, catch_backtrace())
        _capture_action_error!(registry, captured)
        return fallback, captured
    end
end

function _state_for_registration(
    registry::ActionRegistry,
    registration::_ActionRegistration,
    context::ActionContext,
)
    visible, visible_error = _evaluate_action_predicate(
        registry,
        registration.action.visible,
        context,
        false,
    )
    enabled, enabled_error = visible ? _evaluate_action_predicate(
        registry,
        registration.action.enabled,
        context,
        false,
    ) : (false, nothing)
    checked, checked_error = visible ? _evaluate_action_predicate(
        registry,
        registration.action.checked,
        context,
        false,
    ) : (false, nothing)
    error = if visible_error !== nothing
        visible_error
    elseif enabled_error !== nothing
        enabled_error
    else
        checked_error
    end
    return ActionState(registration.action, registration.scope, enabled, visible, checked, error)
end

function action_state(
    registry::ActionRegistry,
    id::Symbol,
    context::ActionContext=ActionContext(),
)
    registration = lock(registry.mutex) do
        _resolve_action_locked(registry, id)
    end
    return registration === nothing ? nothing :
        _state_for_registration(registry, registration, context)
end

function available_actions(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    registrations = lock(registry.mutex) do
        resolved = _ActionRegistration[]
        ids = sort!(collect(keys(registry.registrations)); by=String)
        for id in ids
            registration = _resolve_action_locked(registry, id)
            registration === nothing || push!(resolved, registration)
        end
        resolved
    end
    states = ActionState[]
    for registration in registrations
        state = _state_for_registration(registry, registration, context)
        !include_hidden && !state.visible && continue
        !include_disabled && !state.enabled && continue
        push!(states, state)
    end
    sort!(states; by=state -> (
        -state.action.priority,
        lowercase(state.action.category),
        lowercase(state.action.title),
        String(state.action.id),
    ))
    return states
end

function invoke_action!(
    registry::ActionRegistry,
    id::Symbol,
    context::ActionContext=ActionContext(),
)
    state = action_state(registry, id, context)
    state === nothing && return ActionInvocation(id, ActionMissing, nothing, nothing)
    (!state.visible || !state.enabled) &&
        return ActionInvocation(id, ActionDisabled, nothing, state.error)
    try
        applicable(state.action.handler, context) ||
            throw(ArgumentError("action handler must accept ActionContext"))
        value = state.action.handler(context)
        return ActionInvocation(id, ActionInvoked, value, nothing)
    catch error
        captured = CapturedException(error, catch_backtrace())
        _capture_action_error!(registry, captured)
        return ActionInvocation(id, ActionFailed, nothing, captured)
    end
end

function _action_binding_priority(action_priority::Int, binding_priority::Int)
    total = Int128(action_priority) + Int128(binding_priority)
    return Int(clamp(total, Int128(typemin(Int)), Int128(typemax(Int))))
end

function _action_binding_is_better(candidate, current)
    candidate_priority = _action_binding_priority(
        candidate[1].action.priority,
        candidate[2].priority,
    )
    current_priority = _action_binding_priority(
        current[1].action.priority,
        current[2].priority,
    )
    candidate_priority != current_priority && return candidate_priority > current_priority
    candidate[1].action.priority != current[1].action.priority &&
        return candidate[1].action.priority > current[1].action.priority
    return String(candidate[1].action.id) < String(current[1].action.id)
end

function resolve_action_binding(
    registry::ActionRegistry,
    event::KeyEvent,
    context::ActionContext=ActionContext(; event),
)
    matches = Tuple{ActionState,ActionBinding}[]
    for state in available_actions(registry, context; include_hidden=false, include_disabled=false)
        for binding in state.action.bindings
            binding.key == event.key.code && binding.modifiers == event.modifiers || continue
            push!(matches, (state, binding))
        end
    end
    isempty(matches) && return nothing
    winner = first(matches)
    for candidate in Iterators.drop(matches, 1)
        _action_binding_is_better(candidate, winner) && (winner = candidate)
    end
    return winner[1].action.id
end

function invoke_key_action!(
    registry::ActionRegistry,
    event::KeyEvent,
    context::ActionContext=ActionContext(; event),
)
    id = resolve_action_binding(registry, event, context)
    return id === nothing ? ActionInvocation(:none, ActionMissing, nothing, nothing) :
        invoke_action!(registry, id, context)
end

function action_binding_map(
    registry::ActionRegistry,
    context::ActionContext=ActionContext(),
)
    winners = Dict{Tuple{Symbol,KeyModifiers},Tuple{ActionState,ActionBinding}}()
    for state in available_actions(registry, context; include_hidden=false, include_disabled=false)
        for shortcut in state.action.bindings
            key = (shortcut.key, shortcut.modifiers)
            candidate = (state, shortcut)
            current = get(winners, key, nothing)
            (current === nothing || _action_binding_is_better(candidate, current)) &&
                (winners[key] = candidate)
        end
    end
    map = BindingMap()
    ordered = sort!(collect(values(winners)); by=candidate -> (
        String(candidate[2].key),
        string(candidate[2].modifiers),
    ))
    for (state, shortcut) in ordered
        description = isempty(shortcut.description) ? state.action.title : shortcut.description
        bind!(
            map,
            Binding(
                shortcut.key,
                state.action.id;
                modifiers=shortcut.modifiers,
                description,
                priority=_action_binding_priority(state.action.priority, shortcut.priority),
            ),
        )
    end
    return map
end

function action_command_items(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_disabled::Bool=true,
)
    return CommandItem[
        CommandItem(
            state.action.id,
            state.action.title,
            state.action.id;
            description=state.action.description,
            keywords=vcat(state.action.keywords, [lowercase(state.action.category)]),
            disabled=!state.enabled,
        ) for state in available_actions(
            registry,
            context;
            include_hidden=false,
            include_disabled,
        )
    ]
end

action_errors(registry::ActionRegistry) = lock(registry.mutex) do
    copy(registry.errors)
end

function take_action_errors!(registry::ActionRegistry)
    return lock(registry.mutex) do
        errors = copy(registry.errors)
        empty!(registry.errors)
        errors
    end
end
