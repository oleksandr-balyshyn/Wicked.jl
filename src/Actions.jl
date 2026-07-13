using .Events: KeyEvent, KeyModifiers, NONE
using .Interaction: Binding,
                    BindingLayer,
                    BindingMap,
                    BindingStack,
                    binding_records,
                    binding_help_lines,
                    binding_help_text,
                    binding_label,
                    bind!
using .Widgets: CommandItem,
                CommandPalette,
                CommandPaletteState,
                Footer,
                HelpView,
                KeyHint,
                Menu,
                MenuItem,
                MenuState,
                activate,
                set_command_palette_query!


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

"""Immutable diagnostic bundle for action workflow inspectors and tests."""
struct ActionWorkflowDiagnostics
    invocations::Vector{ActionInvocation}
    records::Vector{NamedTuple}
    summary::NamedTuple
    issues::Vector{ActionInvocation}
    failures::Vector{ActionInvocation}
end

"""Immutable diagnostic snapshot of an action registry."""
struct ActionRegistrySnapshot
    generation::UInt64
    active_scopes::Vector{Symbol}
    total::Int
    visible::Int
    hidden::Int
    enabled::Int
    disabled::Int
    checked::Int
    errored::Int
    category_count::Int
    categories::Vector{String}
    error_count::Int
end

"""Immutable diagnostic bundle for action registry inspectors and tests."""
struct ActionRegistryDiagnostics
    snapshot::ActionRegistrySnapshot
    summary::NamedTuple
    categories::Vector{NamedTuple}
    actions::Vector{NamedTuple}
    bindings::Vector{NamedTuple}
    errors::Vector{CapturedException}
end

function Base.show(io::IO, snapshot::ActionRegistrySnapshot)
    print(
        io,
        "ActionRegistrySnapshot(generation=",
        snapshot.generation,
        ", scopes=",
        snapshot.active_scopes,
        ", actions=",
        snapshot.total,
        ", visible=",
        snapshot.visible,
        ", enabled=",
        snapshot.enabled,
        ", categories=",
        snapshot.category_count,
        ", errors=",
        snapshot.error_count,
        ")",
    )
end

function Base.show(io::IO, diagnostics::ActionRegistryDiagnostics)
    print(
        io,
        "ActionRegistryDiagnostics(actions=",
        diagnostics.summary.total,
        ", categories=",
        length(diagnostics.categories),
        ", bindings=",
        length(diagnostics.bindings),
        ", errors=",
        length(diagnostics.errors),
        ")",
    )
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

"""
    invoke_action_diagnostics!(registry, id, context=ActionContext())

Invoke one action and return `ActionWorkflowDiagnostics`.
"""
invoke_action_diagnostics!(
    registry::ActionRegistry,
    id::Symbol,
    context::ActionContext=ActionContext(),
) = action_workflow_diagnostics(invoke_action!(registry, id, context))

function _selected_action_id(selected)
    selected === nothing && return nothing
    selected isa Symbol && return selected
    selected isa AbstractString && return Symbol(selected)
    throw(ArgumentError("selected action must be nothing, a Symbol, or a string"))
end

"""
    invoke_selected_action!(registry, selected, context=ActionContext())

Invoke a selected action ID from a menu, command palette, or custom picker.
Returns `nothing` when `selected` is `nothing`; otherwise returns the same
`ActionInvocation` produced by `invoke_action!`.
"""
function invoke_selected_action!(
    registry::ActionRegistry,
    selected,
    context::ActionContext=ActionContext(),
)
    id = _selected_action_id(selected)
    id === nothing && return nothing
    return invoke_action!(registry, id, context)
end

"""
    invoke_selected_action_diagnostics!(registry, selected, context=ActionContext())

Invoke a selected action ID and return `ActionWorkflowDiagnostics`. A `nothing`
selection returns an empty diagnostics bundle.
"""
function invoke_selected_action_diagnostics!(
    registry::ActionRegistry,
    selected,
    context::ActionContext=ActionContext(),
)
    invocation = invoke_selected_action!(registry, selected, context)
    return action_workflow_diagnostics(invocation === nothing ? ActionInvocation[] : [invocation])
end

"""
    invoke_activated_action!(registry, widget, state, context=ActionContext())

Activate a menu, command palette, or custom action picker and dispatch the
selected action ID through `invoke_selected_action!`.
"""
function invoke_activated_action!(
    registry::ActionRegistry,
    widget,
    state,
    context::ActionContext=ActionContext(),
)
    return invoke_selected_action!(registry, activate(widget, state), context)
end

"""
    invoke_activated_action_diagnostics!(registry, widget, state, context=ActionContext())

Activate a menu, command palette, or custom action picker and return
`ActionWorkflowDiagnostics`. Empty activations return an empty diagnostics
bundle.
"""
function invoke_activated_action_diagnostics!(
    registry::ActionRegistry,
    widget,
    state,
    context::ActionContext=ActionContext(),
)
    return invoke_selected_action_diagnostics!(registry, activate(widget, state), context)
end

"""
    invoke_actions!(registry, selections, context=ActionContext())

Invoke a sequence of selected action IDs and return the resulting
`ActionInvocation` values. `nothing` selections are ignored, matching
`invoke_selected_action!`.
"""
function invoke_actions!(
    registry::ActionRegistry,
    selections,
    context::ActionContext=ActionContext(),
)
    invocations = ActionInvocation[]
    for selected in selections
        invocation = invoke_selected_action!(registry, selected, context)
        invocation === nothing || push!(invocations, invocation)
    end
    return invocations
end

"""
    invoke_actions_diagnostics!(registry, selections, context=ActionContext())

Invoke a sequence of selected action IDs and return `ActionWorkflowDiagnostics`.
`nothing` selections are ignored, matching `invoke_actions!`.
"""
function invoke_actions_diagnostics!(
    registry::ActionRegistry,
    selections,
    context::ActionContext=ActionContext(),
)
    return action_workflow_diagnostics(invoke_actions!(registry, selections, context))
end

function _action_invocation_error_fields(error::Nothing)
    return (error_type=nothing, error_message="")
end

function _action_invocation_error_fields(error::CapturedException)
    exception = error.ex
    return (
        error_type=Symbol(nameof(typeof(exception))),
        error_message=sprint(showerror, exception),
    )
end

"""
    action_invocation_record(invocation)

Return a plain named tuple describing an `ActionInvocation`.
"""
function action_invocation_record(invocation::ActionInvocation)
    error_fields = _action_invocation_error_fields(invocation.error)
    return (
        id=invocation.id,
        status=Symbol(invocation.status),
        value=invocation.value,
        has_value=invocation.value !== nothing,
        error_type=error_fields.error_type,
        error_message=error_fields.error_message,
    )
end

"""
    action_invocation_text(invocation)

Render an `ActionInvocation` as compact human-readable text.
"""
function action_invocation_text(invocation::ActionInvocation)
    record = action_invocation_record(invocation)
    parts = String["$(record.id): $(record.status)"]
    record.has_value && push!(parts, "value=$(repr(record.value))")
    record.error_type === nothing ||
        push!(parts, "error=$(record.error_type): $(record.error_message)")
    return join(parts, " ")
end

function _action_invocation_columns(columns)
    selected = Tuple(Symbol(column) for column in columns)
    isempty(selected) && throw(ArgumentError("action invocation columns cannot be empty"))
    allowed = Set([:id, :status, :has_value, :value, :error_type, :error_message])
    for column in selected
        column in allowed || throw(ArgumentError(
            "action invocation column must be one of :id, :status, :has_value, :value, :error_type, or :error_message",
        ))
    end
    return selected
end

function _action_invocation_field(record, column::Symbol)
    column === :id && return String(record.id)
    column === :status && return String(record.status)
    column === :has_value && return string(record.has_value)
    column === :value && return repr(record.value)
    column === :error_type && return record.error_type === nothing ? "" : String(record.error_type)
    column === :error_message && return record.error_message
    throw(ArgumentError(
        "action invocation column must be one of :id, :status, :has_value, :value, :error_type, or :error_message",
    ))
end

"""
    action_invocation_markdown(invocation; columns=(:id, :status, :has_value, :error_type, :error_message))

Render an `ActionInvocation` as a GitHub-flavored Markdown table.
"""
function action_invocation_markdown(
    invocation::ActionInvocation;
    columns=(:id, :status, :has_value, :error_type, :error_message),
)
    selected = _action_invocation_columns(columns)
    record = action_invocation_record(invocation)
    header = "| $(join(("`$(String(column))`" for column in selected), " | ")) |"
    divider = "| $(join(fill("---", length(selected)), " | ")) |"
    values = join(
        (_escape_action_markdown(_action_invocation_field(record, column)) for column in selected),
        " | ",
    )
    return join((header, divider, "| $values |"), "\n")
end

"""
    action_invocation_tsv(invocation; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)

Render an `ActionInvocation` as tab-separated values.
"""
function action_invocation_tsv(
    invocation::ActionInvocation;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
)
    selected = _action_invocation_columns(columns)
    record = action_invocation_record(invocation)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    push!(
        rows,
        join(
            (_escape_action_tsv(_action_invocation_field(record, column)) for column in selected),
            "\t",
        ),
    )
    return join(rows, "\n")
end

"""
    action_invocation_records(invocations)

Return plain named tuples for a sequence of `ActionInvocation` values.
"""
action_invocation_records(invocations) =
    [action_invocation_record(invocation) for invocation in invocations]

"""
    action_invocations_text(invocations; newline="\n")

Render a sequence of `ActionInvocation` values as compact text.
"""
function action_invocations_text(invocations; newline::AbstractString="\n")
    rows = [action_invocation_text(invocation) for invocation in invocations]
    isempty(rows) && return "No action invocations"
    return join(rows, newline)
end

"""
    action_invocations_markdown(invocations; columns=(:id, :status, :has_value, :error_type, :error_message))

Render a sequence of `ActionInvocation` values as a GitHub-flavored Markdown table.
"""
function action_invocations_markdown(
    invocations;
    columns=(:id, :status, :has_value, :error_type, :error_message),
)
    selected = _action_invocation_columns(columns)
    rows = String["| $(join(("`$(String(column))`" for column in selected), " | ")) |",
                  "| $(join(fill("---", length(selected)), " | ")) |"]
    for record in action_invocation_records(invocations)
        values = join(
            (_escape_action_markdown(_action_invocation_field(record, column)) for column in selected),
            " | ",
        )
        push!(rows, "| $values |")
    end
    return join(rows, "\n")
end

"""
    action_invocations_tsv(invocations; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)

Render a sequence of `ActionInvocation` values as tab-separated values.
"""
function action_invocations_tsv(
    invocations;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
)
    selected = _action_invocation_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in action_invocation_records(invocations)
        push!(
            rows,
            join(
                (_escape_action_tsv(_action_invocation_field(record, column)) for column in selected),
                "\t",
            ),
        )
    end
    return join(rows, "\n")
end

"""
    action_invocation_summary(invocations)

Return compact counts for a sequence of `ActionInvocation` values.
"""
function action_invocation_summary(invocations)
    by_status = Dict{Symbol,Int}()
    total = 0
    for invocation in invocations
        total += 1
        status = Symbol(invocation.status)
        by_status[status] = get(by_status, status, 0) + 1
    end
    return (total=total, by_status=by_status)
end

"""
    action_invocation_summary_records(invocations)

Return one record per invocation status in a sequence.
"""
function action_invocation_summary_records(invocations)
    summary = action_invocation_summary(invocations)
    statuses = sort(collect(keys(summary.by_status)); by=string)
    return [(status=status, count=summary.by_status[status]) for status in statuses]
end

function _action_invocation_summary_columns(columns)
    selected = Tuple(Symbol(column) for column in columns)
    isempty(selected) && throw(ArgumentError("action invocation summary columns cannot be empty"))
    allowed = Set([:status, :count])
    for column in selected
        column in allowed ||
            throw(ArgumentError("action invocation summary column must be one of :status or :count"))
    end
    return selected
end

function _action_invocation_summary_field(record, column::Symbol)
    column === :status && return String(record.status)
    column === :count && return string(record.count)
    throw(ArgumentError("action invocation summary column must be one of :status or :count"))
end

"""
    action_invocation_summary_text(invocations; newline="\n")

Render invocation status counts as compact text.
"""
function action_invocation_summary_text(invocations; newline::AbstractString="\n")
    summary = action_invocation_summary(invocations)
    summary.total == 0 && return "No action invocations"
    lines = String["Action invocations ($(summary.total))"]
    for record in action_invocation_summary_records(invocations)
        push!(lines, "$(record.status): $(record.count)")
    end
    return join(lines, newline)
end

"""
    action_invocation_summary_markdown(invocations; columns=(:status, :count))

Render invocation status counts as a GitHub-flavored Markdown table.
"""
function action_invocation_summary_markdown(
    invocations;
    columns=(:status, :count),
)
    selected = _action_invocation_summary_columns(columns)
    rows = String["| $(join(("`$(String(column))`" for column in selected), " | ")) |",
                  "| $(join(fill("---", length(selected)), " | ")) |"]
    for record in action_invocation_summary_records(invocations)
        values = join(
            (_escape_action_markdown(_action_invocation_summary_field(record, column)) for column in selected),
            " | ",
        )
        push!(rows, "| $values |")
    end
    return join(rows, "\n")
end

"""
    action_invocation_summary_tsv(invocations; columns=(:status, :count), header=true)

Render invocation status counts as tab-separated values.
"""
function action_invocation_summary_tsv(
    invocations;
    columns=(:status, :count),
    header::Bool=true,
)
    selected = _action_invocation_summary_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in action_invocation_summary_records(invocations)
        push!(
            rows,
            join(
                (_escape_action_tsv(_action_invocation_summary_field(record, column)) for column in selected),
                "\t",
            ),
        )
    end
    return join(rows, "\n")
end

function _action_invocation_search_query(query)
    query isa Regex && return query
    query isa Symbol && return lowercase(String(query))
    query isa AbstractString && return lowercase(String(query))
    throw(ArgumentError("action invocation search query must be a Regex, Symbol, or String"))
end

function _action_invocation_record_matches(record, query)
    text = join(
        (
            String(record.id),
            String(record.status),
            string(record.has_value),
            repr(record.value),
            record.error_type === nothing ? "" : String(record.error_type),
            record.error_message,
        ),
        " ",
    )
    query isa Regex && return occursin(query, text)
    return occursin(query, lowercase(text))
end

"""
    search_action_invocation_records(invocations, query)

Return invocation records whose ID, status, value, error type, or error message
matches `query`.
"""
function search_action_invocation_records(invocations, query)
    prepared_query = _action_invocation_search_query(query)
    return [
        record for record in action_invocation_records(invocations)
        if _action_invocation_record_matches(record, prepared_query)
    ]
end

"""
    search_action_invocation_count(invocations, query)

Count invocation records matching `query`.
"""
search_action_invocation_count(invocations, query) =
    length(search_action_invocation_records(invocations, query))

"""
    search_action_invocations_text(invocations, query; newline="\n")

Render matching invocation records as compact text.
"""
function search_action_invocations_text(invocations, query; newline::AbstractString="\n")
    records = search_action_invocation_records(invocations, query)
    isempty(records) && return "No matching action invocations"
    rows = String[]
    for record in records
        parts = String["$(record.id): $(record.status)"]
        record.has_value && push!(parts, "value=$(repr(record.value))")
        record.error_type === nothing ||
            push!(parts, "error=$(record.error_type): $(record.error_message)")
        push!(rows, join(parts, " "))
    end
    return join(rows, newline)
end

"""
    search_action_invocations_markdown(invocations, query; columns=(:id, :status, :has_value, :error_type, :error_message))

Render matching invocation records as a GitHub-flavored Markdown table.
"""
function search_action_invocations_markdown(
    invocations,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
)
    selected = _action_invocation_columns(columns)
    rows = String["| $(join(("`$(String(column))`" for column in selected), " | ")) |",
                  "| $(join(fill("---", length(selected)), " | ")) |"]
    for record in search_action_invocation_records(invocations, query)
        values = join(
            (_escape_action_markdown(_action_invocation_field(record, column)) for column in selected),
            " | ",
        )
        push!(rows, "| $values |")
    end
    return join(rows, "\n")
end

"""
    search_action_invocations_tsv(invocations, query; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)

Render matching invocation records as tab-separated values.
"""
function search_action_invocations_tsv(
    invocations,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
)
    selected = _action_invocation_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in search_action_invocation_records(invocations, query)
        push!(
            rows,
            join(
                (_escape_action_tsv(_action_invocation_field(record, column)) for column in selected),
                "\t",
            ),
        )
    end
    return join(rows, "\n")
end

function _action_invocation_summary_search_text(record)
    return lowercase(join((String(record.status), string(record.count)), " "))
end

"""
    search_action_invocation_summary_records(invocations, query)

Return invocation summary records whose status or count matches `query`.
"""
function search_action_invocation_summary_records(invocations, query)
    prepared_query = _action_invocation_search_query(query)
    records = action_invocation_summary_records(invocations)
    return [
        record for record in records
        if prepared_query isa Regex ?
           occursin(prepared_query, "$(record.status) $(record.count)") :
           occursin(prepared_query, _action_invocation_summary_search_text(record))
    ]
end

"""
    search_action_invocation_summary_count(invocations, query)

Count invocation summary records matching `query`.
"""
search_action_invocation_summary_count(invocations, query) =
    length(search_action_invocation_summary_records(invocations, query))

"""
    search_action_invocation_summary_text(invocations, query; newline="\n")

Render matching invocation status counts as compact text.
"""
function search_action_invocation_summary_text(
    invocations,
    query;
    newline::AbstractString="\n",
)
    records = search_action_invocation_summary_records(invocations, query)
    isempty(records) && return "No matching action invocation summary"
    total = sum(record.count for record in records)
    lines = String["Action invocations ($(total)) matching \"$(string(query))\""]
    for record in records
        push!(lines, "$(record.status): $(record.count)")
    end
    return join(lines, newline)
end

"""
    search_action_invocation_summary_markdown(invocations, query; columns=(:status, :count))

Render matching invocation status counts as a GitHub-flavored Markdown table.
"""
function search_action_invocation_summary_markdown(
    invocations,
    query;
    columns=(:status, :count),
)
    selected = _action_invocation_summary_columns(columns)
    rows = String["| $(join(("`$(String(column))`" for column in selected), " | ")) |",
                  "| $(join(fill("---", length(selected)), " | ")) |"]
    for record in search_action_invocation_summary_records(invocations, query)
        values = join(
            (_escape_action_markdown(_action_invocation_summary_field(record, column)) for column in selected),
            " | ",
        )
        push!(rows, "| $values |")
    end
    return join(rows, "\n")
end

"""
    search_action_invocation_summary_tsv(invocations, query; columns=(:status, :count), header=true)

Render matching invocation status counts as tab-separated values.
"""
function search_action_invocation_summary_tsv(
    invocations,
    query;
    columns=(:status, :count),
    header::Bool=true,
)
    selected = _action_invocation_summary_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in search_action_invocation_summary_records(invocations, query)
        push!(
            rows,
            join(
                (_escape_action_tsv(_action_invocation_summary_field(record, column)) for column in selected),
                "\t",
            ),
        )
    end
    return join(rows, "\n")
end

"""Return `true` when an action invocation completed successfully."""
action_invocation_invoked(invocation::ActionInvocation) =
    invocation.status == ActionInvoked

"""Return `true` when an action invocation targeted a missing action."""
action_invocation_missing(invocation::ActionInvocation) =
    invocation.status == ActionMissing

"""Return `true` when an action invocation targeted a disabled or hidden action."""
action_invocation_disabled(invocation::ActionInvocation) =
    invocation.status == ActionDisabled

"""Return `true` when an action invocation captured a handler failure."""
action_invocation_failed(invocation::ActionInvocation) =
    invocation.status == ActionFailed

function _assert_action_invocation(
    invocation::ActionInvocation,
    predicate,
    expected::AbstractString,
)
    predicate(invocation) && return invocation
    throw(ArgumentError("expected action invocation to be $(expected), got $(action_invocation_text(invocation))"))
end

"""Assert that an action invocation completed successfully."""
assert_action_invoked(invocation::ActionInvocation) =
    _assert_action_invocation(invocation, action_invocation_invoked, "invoked")

"""Assert that an action invocation targeted a missing action."""
assert_action_missing(invocation::ActionInvocation) =
    _assert_action_invocation(invocation, action_invocation_missing, "missing")

"""Assert that an action invocation targeted a disabled or hidden action."""
assert_action_disabled(invocation::ActionInvocation) =
    _assert_action_invocation(invocation, action_invocation_disabled, "disabled")

"""Assert that an action invocation captured a handler failure."""
assert_action_failed(invocation::ActionInvocation) =
    _assert_action_invocation(invocation, action_invocation_failed, "failed")

"""Return `true` when every invocation in a workflow completed successfully."""
action_invocations_all_invoked(invocations) =
    all(action_invocation_invoked, invocations)

"""Return failed invocations from a workflow."""
action_invocation_failures(invocations) =
    [invocation for invocation in invocations if action_invocation_failed(invocation)]

"""Return `true` when any invocation in a workflow failed."""
action_invocations_any_failed(invocations) =
    !isempty(action_invocation_failures(invocations))

"""Return every non-successful invocation from a workflow."""
action_invocation_issues(invocations) =
    [invocation for invocation in invocations if !action_invocation_invoked(invocation)]

"""Return `true` when a workflow contains any non-successful invocation."""
action_invocations_any_issue(invocations) =
    !isempty(action_invocation_issues(invocations))

"""Return records for every non-successful invocation in a workflow."""
action_invocation_issue_records(invocations) =
    action_invocation_records(action_invocation_issues(invocations))

"""
    action_invocation_issues_text(invocations; newline="\n")

Render non-successful workflow invocations as compact text.
"""
action_invocation_issues_text(invocations; newline::AbstractString="\n") =
    action_invocations_text(action_invocation_issues(invocations); newline)

"""
    action_invocation_issues_markdown(invocations; columns=(:id, :status, :has_value, :error_type, :error_message))

Render non-successful workflow invocations as a GitHub-flavored Markdown table.
"""
action_invocation_issues_markdown(
    invocations;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = action_invocations_markdown(action_invocation_issues(invocations); columns)

"""
    action_invocation_issues_tsv(invocations; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)

Render non-successful workflow invocations as tab-separated values.
"""
action_invocation_issues_tsv(
    invocations;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = action_invocations_tsv(action_invocation_issues(invocations); columns, header)

"""Return status counts for only non-successful workflow invocations."""
action_invocation_issue_summary(invocations) =
    action_invocation_summary(action_invocation_issues(invocations))

"""Return status-count records for only non-successful workflow invocations."""
action_invocation_issue_summary_records(invocations) =
    action_invocation_summary_records(action_invocation_issues(invocations))

"""
    action_invocation_issue_summary_text(invocations; newline="\n")

Render status counts for non-successful workflow invocations as compact text.
"""
action_invocation_issue_summary_text(invocations; newline::AbstractString="\n") =
    action_invocation_summary_text(action_invocation_issues(invocations); newline)

"""
    action_invocation_issue_summary_markdown(invocations; columns=(:status, :count))

Render status counts for non-successful workflow invocations as Markdown.
"""
action_invocation_issue_summary_markdown(
    invocations;
    columns=(:status, :count),
) = action_invocation_summary_markdown(action_invocation_issues(invocations); columns)

"""
    action_invocation_issue_summary_tsv(invocations; columns=(:status, :count), header=true)

Render status counts for non-successful workflow invocations as TSV.
"""
action_invocation_issue_summary_tsv(
    invocations;
    columns=(:status, :count),
    header::Bool=true,
) = action_invocation_summary_tsv(action_invocation_issues(invocations); columns, header)

"""Return matching status-count records for non-successful workflow invocations."""
search_action_invocation_issue_summary_records(invocations, query) =
    search_action_invocation_summary_records(action_invocation_issues(invocations), query)

"""Count matching status-count records for non-successful workflow invocations."""
search_action_invocation_issue_summary_count(invocations, query) =
    search_action_invocation_summary_count(action_invocation_issues(invocations), query)

"""
    search_action_invocation_issue_summary_text(invocations, query; newline="\n")

Render matching status counts for non-successful workflow invocations as compact text.
"""
search_action_invocation_issue_summary_text(
    invocations,
    query;
    newline::AbstractString="\n",
) = search_action_invocation_summary_text(action_invocation_issues(invocations), query; newline)

"""
    search_action_invocation_issue_summary_markdown(invocations, query; columns=(:status, :count))

Render matching status counts for non-successful workflow invocations as Markdown.
"""
search_action_invocation_issue_summary_markdown(
    invocations,
    query;
    columns=(:status, :count),
) = search_action_invocation_summary_markdown(action_invocation_issues(invocations), query; columns)

"""
    search_action_invocation_issue_summary_tsv(invocations, query; columns=(:status, :count), header=true)

Render matching status counts for non-successful workflow invocations as TSV.
"""
search_action_invocation_issue_summary_tsv(
    invocations,
    query;
    columns=(:status, :count),
    header::Bool=true,
) = search_action_invocation_summary_tsv(action_invocation_issues(invocations), query; columns, header)

"""
    assert_action_invocations_invoked(invocations)

Assert that every invocation in a workflow completed successfully.
"""
function assert_action_invocations_invoked(invocations)
    action_invocations_all_invoked(invocations) && return invocations
    throw(ArgumentError(
        "expected all action invocations to be invoked, got $(action_invocation_summary_text(invocations; newline="; "))",
    ))
end

"""
    assert_no_action_invocation_failures(invocations)

Assert that a workflow has no failed action invocations.
"""
function assert_no_action_invocation_failures(invocations)
    failures = action_invocation_failures(invocations)
    isempty(failures) && return invocations
    throw(ArgumentError(
        "expected no failed action invocations, got $(action_invocations_text(failures; newline="; "))",
    ))
end

"""
    assert_no_action_invocation_issues(invocations)

Assert that a workflow has no missing, disabled, or failed action invocations.
"""
function assert_no_action_invocation_issues(invocations)
    issues = action_invocation_issues(invocations)
    isempty(issues) && return invocations
    throw(ArgumentError(
        "expected no action invocation issues, got $(action_invocations_text(issues; newline="; "))",
    ))
end

function Base.show(io::IO, diagnostics::ActionWorkflowDiagnostics)
    print(
        io,
        "ActionWorkflowDiagnostics(total=$(diagnostics.summary.total), issues=$(length(diagnostics.issues)), failures=$(length(diagnostics.failures)))",
    )
end

"""
    action_workflow_diagnostics(invocations)

Return an immutable workflow diagnostics bundle for a sequence of action
invocations.
"""
function action_workflow_diagnostics(invocations)
    collected = ActionInvocation[invocation for invocation in invocations]
    return ActionWorkflowDiagnostics(
        collected,
        action_invocation_records(collected),
        action_invocation_summary(collected),
        action_invocation_issues(collected),
        action_invocation_failures(collected),
    )
end

"""Return workflow diagnostics for one invocation."""
action_workflow_diagnostics(invocation::ActionInvocation) =
    action_workflow_diagnostics([invocation])

"""Return empty action workflow diagnostics."""
empty_action_workflow_diagnostics() =
    action_workflow_diagnostics(ActionInvocation[])

"""
    merge_action_workflow_diagnostics(diagnostics...)

Merge multiple action workflow diagnostics bundles into one fresh diagnostics
bundle.
"""
function merge_action_workflow_diagnostics(diagnostics::ActionWorkflowDiagnostics...)
    invocations = ActionInvocation[]
    for item in diagnostics
        append!(invocations, item.invocations)
    end
    return action_workflow_diagnostics(invocations)
end

merge_action_workflow_diagnostics(diagnostics::AbstractVector{<:ActionWorkflowDiagnostics}) =
    merge_action_workflow_diagnostics(diagnostics...)

"""Return a stable named-tuple record for workflow diagnostics."""
function action_workflow_diagnostics_record(diagnostics::ActionWorkflowDiagnostics)
    return (
        total=diagnostics.summary.total,
        issue_count=length(diagnostics.issues),
        failure_count=length(diagnostics.failures),
        summary=action_workflow_diagnostics_summary(diagnostics),
        invocations=action_workflow_diagnostics_records(diagnostics),
        issues=action_workflow_diagnostics_issue_records(diagnostics),
        failures=action_workflow_diagnostics_failure_records(diagnostics),
    )
end

action_workflow_diagnostics_record(invocations) =
    action_workflow_diagnostics_record(action_workflow_diagnostics(invocations))

"""Return stable records for multiple workflow diagnostics bundles."""
function action_workflow_diagnostics_bundle_records(diagnostics::ActionWorkflowDiagnostics...)
    return [action_workflow_diagnostics_record(item) for item in diagnostics]
end

action_workflow_diagnostics_bundle_records(diagnostics::AbstractVector{<:ActionWorkflowDiagnostics}) =
    action_workflow_diagnostics_bundle_records(diagnostics...)

function _action_workflow_bundle_record_columns(columns)
    selected = Tuple(Symbol(column) for column in columns)
    isempty(selected) && throw(ArgumentError("action workflow diagnostics bundle columns cannot be empty"))
    allowed = Set([:index, :total, :issue_count, :failure_count])
    for column in selected
        column in allowed ||
            throw(ArgumentError("action workflow diagnostics bundle column must be one of :index, :total, :issue_count, or :failure_count"))
    end
    return selected
end

function _action_workflow_bundle_record_field(index::Int, record, column::Symbol)
    column === :index && return string(index)
    column === :total && return string(record.total)
    column === :issue_count && return string(record.issue_count)
    column === :failure_count && return string(record.failure_count)
    throw(ArgumentError("action workflow diagnostics bundle column must be one of :index, :total, :issue_count, or :failure_count"))
end

"""
    action_workflow_diagnostics_bundle_records_markdown(diagnostics...; columns=(:index, :total, :issue_count, :failure_count))

Render workflow diagnostics bundle records as a GitHub-flavored Markdown table.
"""
function action_workflow_diagnostics_bundle_records_markdown(
    diagnostics::ActionWorkflowDiagnostics...;
    columns=(:index, :total, :issue_count, :failure_count),
)
    selected = _action_workflow_bundle_record_columns(columns)
    records = action_workflow_diagnostics_bundle_records(diagnostics...)
    lines = String[
        "| " * join(("`$column`" for column in selected), " | ") * " |",
        "|" * join(("---" for _ in selected), "|") * "|",
    ]
    for (index, record) in enumerate(records)
        push!(
            lines,
            "| " * join((_escape_action_markdown(_action_workflow_bundle_record_field(index, record, column)) for column in selected), " | ") * " |",
        )
    end
    return join(lines, "\n")
end

action_workflow_diagnostics_bundle_records_markdown(
    diagnostics::AbstractVector{<:ActionWorkflowDiagnostics};
    columns=(:index, :total, :issue_count, :failure_count),
) = action_workflow_diagnostics_bundle_records_markdown(diagnostics...; columns)

"""
    action_workflow_diagnostics_bundle_records_tsv(diagnostics...; columns=(:index, :total, :issue_count, :failure_count), header=true)

Render workflow diagnostics bundle records as tab-separated values.
"""
function action_workflow_diagnostics_bundle_records_tsv(
    diagnostics::ActionWorkflowDiagnostics...;
    columns=(:index, :total, :issue_count, :failure_count),
    header::Bool=true,
)
    selected = _action_workflow_bundle_record_columns(columns)
    records = action_workflow_diagnostics_bundle_records(diagnostics...)
    lines = header ? String[join((string(column) for column in selected), "\t")] : String[]
    for (index, record) in enumerate(records)
        push!(
            lines,
            join((_escape_action_tsv(_action_workflow_bundle_record_field(index, record, column)) for column in selected), "\t"),
        )
    end
    return join(lines, "\n")
end

action_workflow_diagnostics_bundle_records_tsv(
    diagnostics::AbstractVector{<:ActionWorkflowDiagnostics};
    columns=(:index, :total, :issue_count, :failure_count),
    header::Bool=true,
) = action_workflow_diagnostics_bundle_records_tsv(diagnostics...; columns, header)

"""
    action_workflow_diagnostics_bundle_records_text(diagnostics...; newline="\n")

Render workflow diagnostics bundle records as compact text.
"""
function action_workflow_diagnostics_bundle_records_text(
    diagnostics::ActionWorkflowDiagnostics...;
    newline::AbstractString="\n",
)
    records = action_workflow_diagnostics_bundle_records(diagnostics...)
    isempty(records) && return "No action workflow diagnostics"
    lines = String["Action workflow diagnostics bundles ($(length(records)))"]
    for (index, record) in enumerate(records)
        push!(
            lines,
            "#$index total=$(record.total) issues=$(record.issue_count) failures=$(record.failure_count)",
        )
    end
    return join(lines, newline)
end

action_workflow_diagnostics_bundle_records_text(
    diagnostics::AbstractVector{<:ActionWorkflowDiagnostics};
    newline::AbstractString="\n",
) = action_workflow_diagnostics_bundle_records_text(diagnostics...; newline)

"""
    action_workflow_diagnostics_bundle_summary(diagnostics...)

Return aggregate counts for multiple workflow diagnostics bundles.
"""
function action_workflow_diagnostics_bundle_summary(diagnostics::ActionWorkflowDiagnostics...)
    total = 0
    issue_count = 0
    failure_count = 0
    for item in diagnostics
        total += item.summary.total
        issue_count += length(item.issues)
        failure_count += length(item.failures)
    end
    return (
        bundles=length(diagnostics),
        total=total,
        issue_count=issue_count,
        failure_count=failure_count,
        all_invoked=issue_count == 0,
    )
end

action_workflow_diagnostics_bundle_summary(diagnostics::AbstractVector{<:ActionWorkflowDiagnostics}) =
    action_workflow_diagnostics_bundle_summary(diagnostics...)

"""
    action_workflow_diagnostics_bundle_summary_text(diagnostics...; newline="\n")

Render aggregate workflow diagnostics bundle counts as compact text.
"""
function action_workflow_diagnostics_bundle_summary_text(
    diagnostics::ActionWorkflowDiagnostics...;
    newline::AbstractString="\n",
)
    summary = action_workflow_diagnostics_bundle_summary(diagnostics...)
    return join(
        String[
            "Action workflow diagnostics bundle summary",
            "Bundles: $(summary.bundles)",
            "Total: $(summary.total)",
            "Issues: $(summary.issue_count)",
            "Failures: $(summary.failure_count)",
            "All invoked: $(summary.all_invoked)",
        ],
        newline,
    )
end

action_workflow_diagnostics_bundle_summary_text(
    diagnostics::AbstractVector{<:ActionWorkflowDiagnostics};
    newline::AbstractString="\n",
) = action_workflow_diagnostics_bundle_summary_text(diagnostics...; newline)

"""
    action_workflow_diagnostics_bundle_summary_markdown(diagnostics...)

Render aggregate workflow diagnostics bundle counts as a Markdown table.
"""
function action_workflow_diagnostics_bundle_summary_markdown(diagnostics::ActionWorkflowDiagnostics...)
    summary = action_workflow_diagnostics_bundle_summary(diagnostics...)
    rows = (
        (:bundles, summary.bundles),
        (:total, summary.total),
        (:issue_count, summary.issue_count),
        (:failure_count, summary.failure_count),
        (:all_invoked, summary.all_invoked),
    )
    lines = String["| `metric` | `value` |", "|---|---:|"]
    for row in rows
        push!(lines, "| $(_escape_action_markdown(row[1])) | $(_escape_action_markdown(row[2])) |")
    end
    return join(lines, "\n")
end

action_workflow_diagnostics_bundle_summary_markdown(
    diagnostics::AbstractVector{<:ActionWorkflowDiagnostics},
) = action_workflow_diagnostics_bundle_summary_markdown(diagnostics...)

"""
    action_workflow_diagnostics_bundle_summary_tsv(diagnostics...; header=true)

Render aggregate workflow diagnostics bundle counts as tab-separated values.
"""
function action_workflow_diagnostics_bundle_summary_tsv(
    diagnostics::ActionWorkflowDiagnostics...;
    header::Bool=true,
)
    summary = action_workflow_diagnostics_bundle_summary(diagnostics...)
    rows = (
        (:bundles, summary.bundles),
        (:total, summary.total),
        (:issue_count, summary.issue_count),
        (:failure_count, summary.failure_count),
        (:all_invoked, summary.all_invoked),
    )
    lines = header ? String["metric\tvalue"] : String[]
    for row in rows
        push!(lines, "$(_escape_action_tsv(row[1]))\t$(_escape_action_tsv(row[2]))")
    end
    return join(lines, "\n")
end

action_workflow_diagnostics_bundle_summary_tsv(
    diagnostics::AbstractVector{<:ActionWorkflowDiagnostics};
    header::Bool=true,
) = action_workflow_diagnostics_bundle_summary_tsv(diagnostics...; header)

"""Return `true` when every diagnostics bundle has only successful invocations."""
action_workflow_diagnostics_bundle_all_invoked(diagnostics::ActionWorkflowDiagnostics...) =
    action_workflow_diagnostics_bundle_summary(diagnostics...).all_invoked

action_workflow_diagnostics_bundle_all_invoked(diagnostics::AbstractVector{<:ActionWorkflowDiagnostics}) =
    action_workflow_diagnostics_bundle_all_invoked(diagnostics...)

"""Return `true` when any diagnostics bundle contains non-successful invocations."""
action_workflow_diagnostics_bundle_has_issues(diagnostics::ActionWorkflowDiagnostics...) =
    action_workflow_diagnostics_bundle_summary(diagnostics...).issue_count > 0

action_workflow_diagnostics_bundle_has_issues(diagnostics::AbstractVector{<:ActionWorkflowDiagnostics}) =
    action_workflow_diagnostics_bundle_has_issues(diagnostics...)

"""Return `true` when any diagnostics bundle contains failed invocations."""
action_workflow_diagnostics_bundle_has_failures(diagnostics::ActionWorkflowDiagnostics...) =
    action_workflow_diagnostics_bundle_summary(diagnostics...).failure_count > 0

action_workflow_diagnostics_bundle_has_failures(diagnostics::AbstractVector{<:ActionWorkflowDiagnostics}) =
    action_workflow_diagnostics_bundle_has_failures(diagnostics...)

"""Assert that every diagnostics bundle has only successful invocations."""
function assert_action_workflow_diagnostics_bundle_all_invoked(diagnostics::ActionWorkflowDiagnostics...)
    action_workflow_diagnostics_bundle_all_invoked(diagnostics...) && return diagnostics
    throw(ArgumentError(
        "expected all action workflow diagnostics bundles to be invoked, got $(action_workflow_diagnostics_bundle_summary_text(diagnostics...; newline="; "))",
    ))
end

assert_action_workflow_diagnostics_bundle_all_invoked(diagnostics::AbstractVector{<:ActionWorkflowDiagnostics}) =
    assert_action_workflow_diagnostics_bundle_all_invoked(diagnostics...)

"""Assert that diagnostics bundles contain no non-successful invocations."""
function assert_action_workflow_diagnostics_bundle_no_issues(diagnostics::ActionWorkflowDiagnostics...)
    !action_workflow_diagnostics_bundle_has_issues(diagnostics...) && return diagnostics
    throw(ArgumentError(
        "expected no action workflow diagnostics bundle issues, got $(action_workflow_diagnostics_bundle_summary_text(diagnostics...; newline="; "))",
    ))
end

assert_action_workflow_diagnostics_bundle_no_issues(diagnostics::AbstractVector{<:ActionWorkflowDiagnostics}) =
    assert_action_workflow_diagnostics_bundle_no_issues(diagnostics...)

"""Assert that diagnostics bundles contain no failed invocations."""
function assert_action_workflow_diagnostics_bundle_no_failures(diagnostics::ActionWorkflowDiagnostics...)
    !action_workflow_diagnostics_bundle_has_failures(diagnostics...) && return diagnostics
    throw(ArgumentError(
        "expected no action workflow diagnostics bundle failures, got $(action_workflow_diagnostics_bundle_summary_text(diagnostics...; newline="; "))",
    ))
end

assert_action_workflow_diagnostics_bundle_no_failures(diagnostics::AbstractVector{<:ActionWorkflowDiagnostics}) =
    assert_action_workflow_diagnostics_bundle_no_failures(diagnostics...)

"""Return invocations captured by workflow diagnostics."""
action_workflow_diagnostics_invocations(diagnostics::ActionWorkflowDiagnostics) =
    copy(diagnostics.invocations)

action_workflow_diagnostics_invocations(invocations) =
    action_workflow_diagnostics_invocations(action_workflow_diagnostics(invocations))

"""Return invocation records captured by workflow diagnostics."""
action_workflow_diagnostics_records(diagnostics::ActionWorkflowDiagnostics) =
    copy(diagnostics.records)

action_workflow_diagnostics_records(invocations) =
    action_workflow_diagnostics_records(action_workflow_diagnostics(invocations))

"""Return matching invocation records captured by workflow diagnostics."""
search_action_workflow_diagnostics_records(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_records(diagnostics.invocations, query)

search_action_workflow_diagnostics_records(invocations, query) =
    search_action_workflow_diagnostics_records(action_workflow_diagnostics(invocations), query)

"""Count matching invocation records captured by workflow diagnostics."""
search_action_workflow_diagnostics_count(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_count(diagnostics.invocations, query)

search_action_workflow_diagnostics_count(invocations, query) =
    search_action_workflow_diagnostics_count(action_workflow_diagnostics(invocations), query)

"""
    search_action_workflow_diagnostics_text(diagnostics, query; newline="\n")
    search_action_workflow_diagnostics_text(invocations, query; newline="\n")

Render matching workflow diagnostics invocations as compact text.
"""
search_action_workflow_diagnostics_text(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    newline::AbstractString="\n",
) = search_action_invocations_text(diagnostics.invocations, query; newline)

search_action_workflow_diagnostics_text(invocations, query; newline::AbstractString="\n") =
    search_action_workflow_diagnostics_text(action_workflow_diagnostics(invocations), query; newline)

"""
    search_action_workflow_diagnostics_markdown(diagnostics, query; columns=(:id, :status, :has_value, :error_type, :error_message))
    search_action_workflow_diagnostics_markdown(invocations, query; columns=(:id, :status, :has_value, :error_type, :error_message))

Render matching workflow diagnostics invocations as Markdown.
"""
search_action_workflow_diagnostics_markdown(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = search_action_invocations_markdown(diagnostics.invocations, query; columns)

search_action_workflow_diagnostics_markdown(
    invocations,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = search_action_workflow_diagnostics_markdown(action_workflow_diagnostics(invocations), query; columns)

"""
    search_action_workflow_diagnostics_tsv(diagnostics, query; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)
    search_action_workflow_diagnostics_tsv(invocations, query; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)

Render matching workflow diagnostics invocations as TSV.
"""
search_action_workflow_diagnostics_tsv(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = search_action_invocations_tsv(diagnostics.invocations, query; columns, header)

search_action_workflow_diagnostics_tsv(
    invocations,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = search_action_workflow_diagnostics_tsv(action_workflow_diagnostics(invocations), query; columns, header)

"""Return the compact status summary captured by workflow diagnostics."""
action_workflow_diagnostics_summary(diagnostics::ActionWorkflowDiagnostics) =
    (total=diagnostics.summary.total, by_status=copy(diagnostics.summary.by_status))

action_workflow_diagnostics_summary(invocations) =
    action_workflow_diagnostics_summary(action_workflow_diagnostics(invocations))

"""Return status-count records captured by workflow diagnostics."""
action_workflow_diagnostics_summary_records(diagnostics::ActionWorkflowDiagnostics) =
    action_invocation_summary_records(diagnostics.invocations)

action_workflow_diagnostics_summary_records(invocations) =
    action_workflow_diagnostics_summary_records(action_workflow_diagnostics(invocations))

"""Return matching status-count records captured by workflow diagnostics."""
search_action_workflow_diagnostics_summary_records(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_summary_records(diagnostics.invocations, query)

search_action_workflow_diagnostics_summary_records(invocations, query) =
    search_action_workflow_diagnostics_summary_records(action_workflow_diagnostics(invocations), query)

"""Count matching status-count records captured by workflow diagnostics."""
search_action_workflow_diagnostics_summary_count(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_summary_count(diagnostics.invocations, query)

search_action_workflow_diagnostics_summary_count(invocations, query) =
    search_action_workflow_diagnostics_summary_count(action_workflow_diagnostics(invocations), query)

"""
    search_action_workflow_diagnostics_summary_text(diagnostics, query; newline="\n")
    search_action_workflow_diagnostics_summary_text(invocations, query; newline="\n")

Render matching workflow diagnostics status counts as compact text.
"""
search_action_workflow_diagnostics_summary_text(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    newline::AbstractString="\n",
) = search_action_invocation_summary_text(diagnostics.invocations, query; newline)

search_action_workflow_diagnostics_summary_text(invocations, query; newline::AbstractString="\n") =
    search_action_workflow_diagnostics_summary_text(action_workflow_diagnostics(invocations), query; newline)

"""
    search_action_workflow_diagnostics_summary_markdown(diagnostics, query; columns=(:status, :count))
    search_action_workflow_diagnostics_summary_markdown(invocations, query; columns=(:status, :count))

Render matching workflow diagnostics status counts as Markdown.
"""
search_action_workflow_diagnostics_summary_markdown(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:status, :count),
) = search_action_invocation_summary_markdown(diagnostics.invocations, query; columns)

search_action_workflow_diagnostics_summary_markdown(
    invocations,
    query;
    columns=(:status, :count),
) = search_action_workflow_diagnostics_summary_markdown(action_workflow_diagnostics(invocations), query; columns)

"""
    search_action_workflow_diagnostics_summary_tsv(diagnostics, query; columns=(:status, :count), header=true)
    search_action_workflow_diagnostics_summary_tsv(invocations, query; columns=(:status, :count), header=true)

Render matching workflow diagnostics status counts as TSV.
"""
search_action_workflow_diagnostics_summary_tsv(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:status, :count),
    header::Bool=true,
) = search_action_invocation_summary_tsv(diagnostics.invocations, query; columns, header)

search_action_workflow_diagnostics_summary_tsv(
    invocations,
    query;
    columns=(:status, :count),
    header::Bool=true,
) = search_action_workflow_diagnostics_summary_tsv(action_workflow_diagnostics(invocations), query; columns, header)

function _action_workflow_status_key(status::ActionInvocationStatus)
    return Symbol(status)
end

function _action_workflow_status_key(status::Symbol)
    return status
end

function _action_workflow_status_key(status::AbstractString)
    return Symbol(status)
end

function _action_workflow_status_key(status)
    throw(ArgumentError("action workflow status must be an ActionInvocationStatus, Symbol, or string"))
end

"""Return a status count from workflow diagnostics."""
function action_workflow_diagnostics_status_count(diagnostics::ActionWorkflowDiagnostics, status)
    return get(diagnostics.summary.by_status, _action_workflow_status_key(status), 0)
end

action_workflow_diagnostics_status_count(invocations, status) =
    action_workflow_diagnostics_status_count(action_workflow_diagnostics(invocations), status)

"""Return a status count from non-successful workflow diagnostics invocations."""
function action_workflow_diagnostics_issue_status_count(diagnostics::ActionWorkflowDiagnostics, status)
    summary = action_invocation_summary(diagnostics.issues)
    return get(summary.by_status, _action_workflow_status_key(status), 0)
end

action_workflow_diagnostics_issue_status_count(invocations, status) =
    action_workflow_diagnostics_issue_status_count(action_workflow_diagnostics(invocations), status)

"""Return a status count from failed workflow diagnostics invocations."""
function action_workflow_diagnostics_failure_status_count(diagnostics::ActionWorkflowDiagnostics, status)
    summary = action_invocation_summary(diagnostics.failures)
    return get(summary.by_status, _action_workflow_status_key(status), 0)
end

action_workflow_diagnostics_failure_status_count(invocations, status) =
    action_workflow_diagnostics_failure_status_count(action_workflow_diagnostics(invocations), status)

"""Return the number of successfully invoked actions in workflow diagnostics."""
action_workflow_diagnostics_invoked_count(value) =
    action_workflow_diagnostics_status_count(value, ActionInvoked)

"""Return the number of missing actions in workflow diagnostics."""
action_workflow_diagnostics_missing_count(value) =
    action_workflow_diagnostics_status_count(value, ActionMissing)

"""Return the number of disabled actions in workflow diagnostics."""
action_workflow_diagnostics_disabled_count(value) =
    action_workflow_diagnostics_status_count(value, ActionDisabled)

"""Return the number of failed actions in workflow diagnostics."""
action_workflow_diagnostics_failed_count(value) =
    action_workflow_diagnostics_status_count(value, ActionFailed)

"""Return the total number of invocations in workflow diagnostics."""
action_workflow_diagnostics_total_count(diagnostics::ActionWorkflowDiagnostics) =
    diagnostics.summary.total

action_workflow_diagnostics_total_count(value) =
    action_workflow_diagnostics_total_count(action_workflow_diagnostics(value))

"""Return the total number of non-successful invocations in workflow diagnostics."""
action_workflow_diagnostics_issue_count(diagnostics::ActionWorkflowDiagnostics) =
    length(diagnostics.issues)

action_workflow_diagnostics_issue_count(value) =
    action_workflow_diagnostics_issue_count(action_workflow_diagnostics(value))

"""Return the total number of failed invocations in workflow diagnostics."""
action_workflow_diagnostics_failure_count(diagnostics::ActionWorkflowDiagnostics) =
    length(diagnostics.failures)

action_workflow_diagnostics_failure_count(value) =
    action_workflow_diagnostics_failure_count(action_workflow_diagnostics(value))

"""
    action_workflow_diagnostics_summary_text(diagnostics; newline="\n")
    action_workflow_diagnostics_summary_text(invocations; newline="\n")

Render workflow diagnostics status counts as compact text.
"""
action_workflow_diagnostics_summary_text(
    diagnostics::ActionWorkflowDiagnostics;
    newline::AbstractString="\n",
) = action_invocation_summary_text(diagnostics.invocations; newline)

action_workflow_diagnostics_summary_text(invocations; newline::AbstractString="\n") =
    action_workflow_diagnostics_summary_text(action_workflow_diagnostics(invocations); newline)

"""
    action_workflow_diagnostics_summary_markdown(diagnostics; columns=(:status, :count))
    action_workflow_diagnostics_summary_markdown(invocations; columns=(:status, :count))

Render workflow diagnostics status counts as Markdown.
"""
action_workflow_diagnostics_summary_markdown(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:status, :count),
) = action_invocation_summary_markdown(diagnostics.invocations; columns)

action_workflow_diagnostics_summary_markdown(
    invocations;
    columns=(:status, :count),
) = action_workflow_diagnostics_summary_markdown(action_workflow_diagnostics(invocations); columns)

"""
    action_workflow_diagnostics_summary_tsv(diagnostics; columns=(:status, :count), header=true)
    action_workflow_diagnostics_summary_tsv(invocations; columns=(:status, :count), header=true)

Render workflow diagnostics status counts as TSV.
"""
action_workflow_diagnostics_summary_tsv(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:status, :count),
    header::Bool=true,
) = action_invocation_summary_tsv(diagnostics.invocations; columns, header)

action_workflow_diagnostics_summary_tsv(
    invocations;
    columns=(:status, :count),
    header::Bool=true,
) = action_workflow_diagnostics_summary_tsv(action_workflow_diagnostics(invocations); columns, header)

"""Return failed invocations captured by workflow diagnostics."""
action_workflow_diagnostics_failures(diagnostics::ActionWorkflowDiagnostics) =
    copy(diagnostics.failures)

action_workflow_diagnostics_failures(invocations) =
    action_workflow_diagnostics_failures(action_workflow_diagnostics(invocations))

"""Return non-successful invocations captured by workflow diagnostics."""
action_workflow_diagnostics_issues(diagnostics::ActionWorkflowDiagnostics) =
    copy(diagnostics.issues)

action_workflow_diagnostics_issues(invocations) =
    action_workflow_diagnostics_issues(action_workflow_diagnostics(invocations))

"""Return records for failed invocations captured by workflow diagnostics."""
action_workflow_diagnostics_failure_records(diagnostics::ActionWorkflowDiagnostics) =
    action_invocation_records(diagnostics.failures)

action_workflow_diagnostics_failure_records(invocations) =
    action_workflow_diagnostics_failure_records(action_workflow_diagnostics(invocations))

"""
    action_workflow_diagnostics_failures_text(diagnostics; newline="\n")
    action_workflow_diagnostics_failures_text(invocations; newline="\n")

Render failed workflow diagnostics invocations as compact text.
"""
action_workflow_diagnostics_failures_text(
    diagnostics::ActionWorkflowDiagnostics;
    newline::AbstractString="\n",
) = action_invocations_text(diagnostics.failures; newline)

action_workflow_diagnostics_failures_text(invocations; newline::AbstractString="\n") =
    action_workflow_diagnostics_failures_text(action_workflow_diagnostics(invocations); newline)

"""
    action_workflow_diagnostics_failures_markdown(diagnostics; columns=(:id, :status, :has_value, :error_type, :error_message))
    action_workflow_diagnostics_failures_markdown(invocations; columns=(:id, :status, :has_value, :error_type, :error_message))

Render failed workflow diagnostics invocations as Markdown.
"""
action_workflow_diagnostics_failures_markdown(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = action_invocations_markdown(diagnostics.failures; columns)

action_workflow_diagnostics_failures_markdown(
    invocations;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = action_workflow_diagnostics_failures_markdown(action_workflow_diagnostics(invocations); columns)

"""
    action_workflow_diagnostics_failures_tsv(diagnostics; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)
    action_workflow_diagnostics_failures_tsv(invocations; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)

Render failed workflow diagnostics invocations as TSV.
"""
action_workflow_diagnostics_failures_tsv(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = action_invocations_tsv(diagnostics.failures; columns, header)

action_workflow_diagnostics_failures_tsv(
    invocations;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = action_workflow_diagnostics_failures_tsv(action_workflow_diagnostics(invocations); columns, header)

"""Return matching failed invocation records captured by workflow diagnostics."""
search_action_workflow_diagnostics_failure_records(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_records(diagnostics.failures, query)

search_action_workflow_diagnostics_failure_records(invocations, query) =
    search_action_workflow_diagnostics_failure_records(action_workflow_diagnostics(invocations), query)

"""Count matching failed invocation records captured by workflow diagnostics."""
search_action_workflow_diagnostics_failure_count(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_count(diagnostics.failures, query)

search_action_workflow_diagnostics_failure_count(invocations, query) =
    search_action_workflow_diagnostics_failure_count(action_workflow_diagnostics(invocations), query)

"""
    search_action_workflow_diagnostics_failures_text(diagnostics, query; newline="\n")
    search_action_workflow_diagnostics_failures_text(invocations, query; newline="\n")

Render matching failed workflow diagnostics invocations as compact text.
"""
search_action_workflow_diagnostics_failures_text(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    newline::AbstractString="\n",
) = search_action_invocations_text(diagnostics.failures, query; newline)

search_action_workflow_diagnostics_failures_text(invocations, query; newline::AbstractString="\n") =
    search_action_workflow_diagnostics_failures_text(action_workflow_diagnostics(invocations), query; newline)

"""
    search_action_workflow_diagnostics_failures_markdown(diagnostics, query; columns=(:id, :status, :has_value, :error_type, :error_message))
    search_action_workflow_diagnostics_failures_markdown(invocations, query; columns=(:id, :status, :has_value, :error_type, :error_message))

Render matching failed workflow diagnostics invocations as Markdown.
"""
search_action_workflow_diagnostics_failures_markdown(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = search_action_invocations_markdown(diagnostics.failures, query; columns)

search_action_workflow_diagnostics_failures_markdown(
    invocations,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = search_action_workflow_diagnostics_failures_markdown(action_workflow_diagnostics(invocations), query; columns)

"""
    search_action_workflow_diagnostics_failures_tsv(diagnostics, query; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)
    search_action_workflow_diagnostics_failures_tsv(invocations, query; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)

Render matching failed workflow diagnostics invocations as TSV.
"""
search_action_workflow_diagnostics_failures_tsv(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = search_action_invocations_tsv(diagnostics.failures, query; columns, header)

search_action_workflow_diagnostics_failures_tsv(
    invocations,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = search_action_workflow_diagnostics_failures_tsv(action_workflow_diagnostics(invocations), query; columns, header)

"""Return status counts for failed workflow diagnostics invocations."""
action_workflow_diagnostics_failure_summary(diagnostics::ActionWorkflowDiagnostics) =
    action_invocation_summary(diagnostics.failures)

action_workflow_diagnostics_failure_summary(invocations) =
    action_workflow_diagnostics_failure_summary(action_workflow_diagnostics(invocations))

"""Return status-count records for failed workflow diagnostics invocations."""
action_workflow_diagnostics_failure_summary_records(diagnostics::ActionWorkflowDiagnostics) =
    action_invocation_summary_records(diagnostics.failures)

action_workflow_diagnostics_failure_summary_records(invocations) =
    action_workflow_diagnostics_failure_summary_records(action_workflow_diagnostics(invocations))

"""
    action_workflow_diagnostics_failure_summary_text(diagnostics; newline="\n")
    action_workflow_diagnostics_failure_summary_text(invocations; newline="\n")

Render status counts for failed workflow diagnostics invocations as compact text.
"""
action_workflow_diagnostics_failure_summary_text(
    diagnostics::ActionWorkflowDiagnostics;
    newline::AbstractString="\n",
) = action_invocation_summary_text(diagnostics.failures; newline)

action_workflow_diagnostics_failure_summary_text(invocations; newline::AbstractString="\n") =
    action_workflow_diagnostics_failure_summary_text(action_workflow_diagnostics(invocations); newline)

"""
    action_workflow_diagnostics_failure_summary_markdown(diagnostics; columns=(:status, :count))
    action_workflow_diagnostics_failure_summary_markdown(invocations; columns=(:status, :count))

Render status counts for failed workflow diagnostics invocations as Markdown.
"""
action_workflow_diagnostics_failure_summary_markdown(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:status, :count),
) = action_invocation_summary_markdown(diagnostics.failures; columns)

action_workflow_diagnostics_failure_summary_markdown(
    invocations;
    columns=(:status, :count),
) = action_workflow_diagnostics_failure_summary_markdown(action_workflow_diagnostics(invocations); columns)

"""
    action_workflow_diagnostics_failure_summary_tsv(diagnostics; columns=(:status, :count), header=true)
    action_workflow_diagnostics_failure_summary_tsv(invocations; columns=(:status, :count), header=true)

Render status counts for failed workflow diagnostics invocations as TSV.
"""
action_workflow_diagnostics_failure_summary_tsv(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:status, :count),
    header::Bool=true,
) = action_invocation_summary_tsv(diagnostics.failures; columns, header)

action_workflow_diagnostics_failure_summary_tsv(
    invocations;
    columns=(:status, :count),
    header::Bool=true,
) = action_workflow_diagnostics_failure_summary_tsv(action_workflow_diagnostics(invocations); columns, header)

"""Return matching status-count records for failed workflow diagnostics invocations."""
search_action_workflow_diagnostics_failure_summary_records(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_summary_records(diagnostics.failures, query)

search_action_workflow_diagnostics_failure_summary_records(invocations, query) =
    search_action_workflow_diagnostics_failure_summary_records(action_workflow_diagnostics(invocations), query)

"""Count matching status-count records for failed workflow diagnostics invocations."""
search_action_workflow_diagnostics_failure_summary_count(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_summary_count(diagnostics.failures, query)

search_action_workflow_diagnostics_failure_summary_count(invocations, query) =
    search_action_workflow_diagnostics_failure_summary_count(action_workflow_diagnostics(invocations), query)

"""
    search_action_workflow_diagnostics_failure_summary_text(diagnostics, query; newline="\n")
    search_action_workflow_diagnostics_failure_summary_text(invocations, query; newline="\n")

Render matching status counts for failed workflow diagnostics invocations as compact text.
"""
search_action_workflow_diagnostics_failure_summary_text(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    newline::AbstractString="\n",
) = search_action_invocation_summary_text(diagnostics.failures, query; newline)

search_action_workflow_diagnostics_failure_summary_text(invocations, query; newline::AbstractString="\n") =
    search_action_workflow_diagnostics_failure_summary_text(action_workflow_diagnostics(invocations), query; newline)

"""
    search_action_workflow_diagnostics_failure_summary_markdown(diagnostics, query; columns=(:status, :count))
    search_action_workflow_diagnostics_failure_summary_markdown(invocations, query; columns=(:status, :count))

Render matching status counts for failed workflow diagnostics invocations as Markdown.
"""
search_action_workflow_diagnostics_failure_summary_markdown(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:status, :count),
) = search_action_invocation_summary_markdown(diagnostics.failures, query; columns)

search_action_workflow_diagnostics_failure_summary_markdown(
    invocations,
    query;
    columns=(:status, :count),
) = search_action_workflow_diagnostics_failure_summary_markdown(action_workflow_diagnostics(invocations), query; columns)

"""
    search_action_workflow_diagnostics_failure_summary_tsv(diagnostics, query; columns=(:status, :count), header=true)
    search_action_workflow_diagnostics_failure_summary_tsv(invocations, query; columns=(:status, :count), header=true)

Render matching status counts for failed workflow diagnostics invocations as TSV.
"""
search_action_workflow_diagnostics_failure_summary_tsv(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:status, :count),
    header::Bool=true,
) = search_action_invocation_summary_tsv(diagnostics.failures, query; columns, header)

search_action_workflow_diagnostics_failure_summary_tsv(
    invocations,
    query;
    columns=(:status, :count),
    header::Bool=true,
) = search_action_workflow_diagnostics_failure_summary_tsv(action_workflow_diagnostics(invocations), query; columns, header)

"""Return records for non-successful invocations captured by workflow diagnostics."""
action_workflow_diagnostics_issue_records(diagnostics::ActionWorkflowDiagnostics) =
    action_invocation_records(diagnostics.issues)

action_workflow_diagnostics_issue_records(invocations) =
    action_workflow_diagnostics_issue_records(action_workflow_diagnostics(invocations))

"""
    action_workflow_diagnostics_issues_text(diagnostics; newline="\n")
    action_workflow_diagnostics_issues_text(invocations; newline="\n")

Render non-successful workflow diagnostics invocations as compact text.
"""
action_workflow_diagnostics_issues_text(
    diagnostics::ActionWorkflowDiagnostics;
    newline::AbstractString="\n",
) = action_invocations_text(diagnostics.issues; newline)

action_workflow_diagnostics_issues_text(invocations; newline::AbstractString="\n") =
    action_workflow_diagnostics_issues_text(action_workflow_diagnostics(invocations); newline)

"""
    action_workflow_diagnostics_issues_markdown(diagnostics; columns=(:id, :status, :has_value, :error_type, :error_message))
    action_workflow_diagnostics_issues_markdown(invocations; columns=(:id, :status, :has_value, :error_type, :error_message))

Render non-successful workflow diagnostics invocations as Markdown.
"""
action_workflow_diagnostics_issues_markdown(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = action_invocations_markdown(diagnostics.issues; columns)

action_workflow_diagnostics_issues_markdown(
    invocations;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = action_workflow_diagnostics_issues_markdown(action_workflow_diagnostics(invocations); columns)

"""
    action_workflow_diagnostics_issues_tsv(diagnostics; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)
    action_workflow_diagnostics_issues_tsv(invocations; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)

Render non-successful workflow diagnostics invocations as TSV.
"""
action_workflow_diagnostics_issues_tsv(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = action_invocations_tsv(diagnostics.issues; columns, header)

action_workflow_diagnostics_issues_tsv(
    invocations;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = action_workflow_diagnostics_issues_tsv(action_workflow_diagnostics(invocations); columns, header)

"""Return matching non-successful invocation records captured by workflow diagnostics."""
search_action_workflow_diagnostics_issue_records(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_records(diagnostics.issues, query)

search_action_workflow_diagnostics_issue_records(invocations, query) =
    search_action_workflow_diagnostics_issue_records(action_workflow_diagnostics(invocations), query)

"""Count matching non-successful invocation records captured by workflow diagnostics."""
search_action_workflow_diagnostics_issue_count(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_count(diagnostics.issues, query)

search_action_workflow_diagnostics_issue_count(invocations, query) =
    search_action_workflow_diagnostics_issue_count(action_workflow_diagnostics(invocations), query)

"""
    search_action_workflow_diagnostics_issues_text(diagnostics, query; newline="\n")
    search_action_workflow_diagnostics_issues_text(invocations, query; newline="\n")

Render matching non-successful workflow diagnostics invocations as compact text.
"""
search_action_workflow_diagnostics_issues_text(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    newline::AbstractString="\n",
) = search_action_invocations_text(diagnostics.issues, query; newline)

search_action_workflow_diagnostics_issues_text(invocations, query; newline::AbstractString="\n") =
    search_action_workflow_diagnostics_issues_text(action_workflow_diagnostics(invocations), query; newline)

"""
    search_action_workflow_diagnostics_issues_markdown(diagnostics, query; columns=(:id, :status, :has_value, :error_type, :error_message))
    search_action_workflow_diagnostics_issues_markdown(invocations, query; columns=(:id, :status, :has_value, :error_type, :error_message))

Render matching non-successful workflow diagnostics invocations as Markdown.
"""
search_action_workflow_diagnostics_issues_markdown(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = search_action_invocations_markdown(diagnostics.issues, query; columns)

search_action_workflow_diagnostics_issues_markdown(
    invocations,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
) = search_action_workflow_diagnostics_issues_markdown(action_workflow_diagnostics(invocations), query; columns)

"""
    search_action_workflow_diagnostics_issues_tsv(diagnostics, query; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)
    search_action_workflow_diagnostics_issues_tsv(invocations, query; columns=(:id, :status, :has_value, :error_type, :error_message), header=true)

Render matching non-successful workflow diagnostics invocations as TSV.
"""
search_action_workflow_diagnostics_issues_tsv(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = search_action_invocations_tsv(diagnostics.issues, query; columns, header)

search_action_workflow_diagnostics_issues_tsv(
    invocations,
    query;
    columns=(:id, :status, :has_value, :error_type, :error_message),
    header::Bool=true,
) = search_action_workflow_diagnostics_issues_tsv(action_workflow_diagnostics(invocations), query; columns, header)

"""Return status counts for non-successful workflow diagnostics invocations."""
action_workflow_diagnostics_issue_summary(diagnostics::ActionWorkflowDiagnostics) =
    action_invocation_summary(diagnostics.issues)

action_workflow_diagnostics_issue_summary(invocations) =
    action_workflow_diagnostics_issue_summary(action_workflow_diagnostics(invocations))

"""Return status-count records for non-successful workflow diagnostics invocations."""
action_workflow_diagnostics_issue_summary_records(diagnostics::ActionWorkflowDiagnostics) =
    action_invocation_summary_records(diagnostics.issues)

action_workflow_diagnostics_issue_summary_records(invocations) =
    action_workflow_diagnostics_issue_summary_records(action_workflow_diagnostics(invocations))

"""
    action_workflow_diagnostics_issue_summary_text(diagnostics; newline="\n")
    action_workflow_diagnostics_issue_summary_text(invocations; newline="\n")

Render status counts for non-successful workflow diagnostics invocations as compact text.
"""
action_workflow_diagnostics_issue_summary_text(
    diagnostics::ActionWorkflowDiagnostics;
    newline::AbstractString="\n",
) = action_invocation_summary_text(diagnostics.issues; newline)

action_workflow_diagnostics_issue_summary_text(invocations; newline::AbstractString="\n") =
    action_workflow_diagnostics_issue_summary_text(action_workflow_diagnostics(invocations); newline)

"""
    action_workflow_diagnostics_issue_summary_markdown(diagnostics; columns=(:status, :count))
    action_workflow_diagnostics_issue_summary_markdown(invocations; columns=(:status, :count))

Render status counts for non-successful workflow diagnostics invocations as Markdown.
"""
action_workflow_diagnostics_issue_summary_markdown(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:status, :count),
) = action_invocation_summary_markdown(diagnostics.issues; columns)

action_workflow_diagnostics_issue_summary_markdown(
    invocations;
    columns=(:status, :count),
) = action_workflow_diagnostics_issue_summary_markdown(action_workflow_diagnostics(invocations); columns)

"""
    action_workflow_diagnostics_issue_summary_tsv(diagnostics; columns=(:status, :count), header=true)
    action_workflow_diagnostics_issue_summary_tsv(invocations; columns=(:status, :count), header=true)

Render status counts for non-successful workflow diagnostics invocations as TSV.
"""
action_workflow_diagnostics_issue_summary_tsv(
    diagnostics::ActionWorkflowDiagnostics;
    columns=(:status, :count),
    header::Bool=true,
) = action_invocation_summary_tsv(diagnostics.issues; columns, header)

action_workflow_diagnostics_issue_summary_tsv(
    invocations;
    columns=(:status, :count),
    header::Bool=true,
) = action_workflow_diagnostics_issue_summary_tsv(action_workflow_diagnostics(invocations); columns, header)

"""Return matching status-count records for non-successful workflow diagnostics invocations."""
search_action_workflow_diagnostics_issue_summary_records(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_summary_records(diagnostics.issues, query)

search_action_workflow_diagnostics_issue_summary_records(invocations, query) =
    search_action_workflow_diagnostics_issue_summary_records(action_workflow_diagnostics(invocations), query)

"""Count matching status-count records for non-successful workflow diagnostics invocations."""
search_action_workflow_diagnostics_issue_summary_count(diagnostics::ActionWorkflowDiagnostics, query) =
    search_action_invocation_summary_count(diagnostics.issues, query)

search_action_workflow_diagnostics_issue_summary_count(invocations, query) =
    search_action_workflow_diagnostics_issue_summary_count(action_workflow_diagnostics(invocations), query)

"""
    search_action_workflow_diagnostics_issue_summary_text(diagnostics, query; newline="\n")
    search_action_workflow_diagnostics_issue_summary_text(invocations, query; newline="\n")

Render matching status counts for non-successful workflow diagnostics invocations as compact text.
"""
search_action_workflow_diagnostics_issue_summary_text(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    newline::AbstractString="\n",
) = search_action_invocation_summary_text(diagnostics.issues, query; newline)

search_action_workflow_diagnostics_issue_summary_text(invocations, query; newline::AbstractString="\n") =
    search_action_workflow_diagnostics_issue_summary_text(action_workflow_diagnostics(invocations), query; newline)

"""
    search_action_workflow_diagnostics_issue_summary_markdown(diagnostics, query; columns=(:status, :count))
    search_action_workflow_diagnostics_issue_summary_markdown(invocations, query; columns=(:status, :count))

Render matching status counts for non-successful workflow diagnostics invocations as Markdown.
"""
search_action_workflow_diagnostics_issue_summary_markdown(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:status, :count),
) = search_action_invocation_summary_markdown(diagnostics.issues, query; columns)

search_action_workflow_diagnostics_issue_summary_markdown(
    invocations,
    query;
    columns=(:status, :count),
) = search_action_workflow_diagnostics_issue_summary_markdown(action_workflow_diagnostics(invocations), query; columns)

"""
    search_action_workflow_diagnostics_issue_summary_tsv(diagnostics, query; columns=(:status, :count), header=true)
    search_action_workflow_diagnostics_issue_summary_tsv(invocations, query; columns=(:status, :count), header=true)

Render matching status counts for non-successful workflow diagnostics invocations as TSV.
"""
search_action_workflow_diagnostics_issue_summary_tsv(
    diagnostics::ActionWorkflowDiagnostics,
    query;
    columns=(:status, :count),
    header::Bool=true,
) = search_action_invocation_summary_tsv(diagnostics.issues, query; columns, header)

search_action_workflow_diagnostics_issue_summary_tsv(
    invocations,
    query;
    columns=(:status, :count),
    header::Bool=true,
) = search_action_workflow_diagnostics_issue_summary_tsv(action_workflow_diagnostics(invocations), query; columns, header)

"""
    action_workflow_diagnostics_text(diagnostics; newline="\n")
    action_workflow_diagnostics_text(invocations; newline="\n")

Render workflow diagnostics as compact human-readable text.
"""
function action_workflow_diagnostics_text(
    diagnostics::ActionWorkflowDiagnostics;
    newline::AbstractString="\n",
)
    lines = String[
        "Action workflow diagnostics",
        "Total: $(diagnostics.summary.total)",
        "Issues: $(length(diagnostics.issues))",
        "Failures: $(length(diagnostics.failures))",
    ]
    append!(lines, split(action_invocation_summary_text(diagnostics.invocations; newline), newline; keepempty=false))
    return join(lines, newline)
end

action_workflow_diagnostics_text(invocations; newline::AbstractString="\n") =
    action_workflow_diagnostics_text(action_workflow_diagnostics(invocations); newline)

function _action_workflow_diagnostics_metric_records(diagnostics::ActionWorkflowDiagnostics)
    records = [
        (metric=:total, value=diagnostics.summary.total),
        (metric=:issues, value=length(diagnostics.issues)),
        (metric=:failures, value=length(diagnostics.failures)),
    ]
    for record in action_invocation_summary_records(diagnostics.invocations)
        push!(records, (metric=Symbol("status_", record.status), value=record.count))
    end
    return records
end

"""
    action_workflow_diagnostics_markdown(diagnostics)
    action_workflow_diagnostics_markdown(invocations)

Render workflow diagnostics as a GitHub-flavored Markdown metric table.
"""
function action_workflow_diagnostics_markdown(diagnostics::ActionWorkflowDiagnostics)
    lines = String["| `metric` | `value` |", "|---|---:|"]
    for record in _action_workflow_diagnostics_metric_records(diagnostics)
        push!(
            lines,
            "| $(_escape_action_markdown(record.metric)) | $(_escape_action_markdown(record.value)) |",
        )
    end
    return join(lines, "\n")
end

action_workflow_diagnostics_markdown(invocations) =
    action_workflow_diagnostics_markdown(action_workflow_diagnostics(invocations))

"""
    action_workflow_diagnostics_tsv(diagnostics; header=true)
    action_workflow_diagnostics_tsv(invocations; header=true)

Render workflow diagnostics as tab-separated metric rows.
"""
function action_workflow_diagnostics_tsv(
    diagnostics::ActionWorkflowDiagnostics;
    header::Bool=true,
)
    lines = header ? String["metric\tvalue"] : String[]
    for record in _action_workflow_diagnostics_metric_records(diagnostics)
        push!(lines, "$(_escape_action_tsv(record.metric))\t$(_escape_action_tsv(record.value))")
    end
    return join(lines, "\n")
end

action_workflow_diagnostics_tsv(invocations; header::Bool=true) =
    action_workflow_diagnostics_tsv(action_workflow_diagnostics(invocations); header)

"""Return `true` when workflow diagnostics contain failed invocations."""
action_workflow_diagnostics_has_failures(diagnostics::ActionWorkflowDiagnostics) =
    !isempty(diagnostics.failures)

action_workflow_diagnostics_has_failures(invocations) =
    action_workflow_diagnostics_has_failures(action_workflow_diagnostics(invocations))

"""Return `true` when every workflow diagnostics invocation completed successfully."""
action_workflow_diagnostics_all_invoked(diagnostics::ActionWorkflowDiagnostics) =
    isempty(diagnostics.issues)

action_workflow_diagnostics_all_invoked(invocations) =
    action_workflow_diagnostics_all_invoked(action_workflow_diagnostics(invocations))

"""Return `true` when workflow diagnostics contain missing, disabled, or failed invocations."""
action_workflow_diagnostics_has_issues(diagnostics::ActionWorkflowDiagnostics) =
    !isempty(diagnostics.issues)

action_workflow_diagnostics_has_issues(invocations) =
    action_workflow_diagnostics_has_issues(action_workflow_diagnostics(invocations))

"""Assert that workflow diagnostics contain no failed invocations."""
function assert_action_workflow_diagnostics_no_failures(diagnostics::ActionWorkflowDiagnostics)
    action_workflow_diagnostics_has_failures(diagnostics) || return diagnostics
    throw(ArgumentError(
        "expected no failed action workflow invocations, got $(action_invocations_text(diagnostics.failures; newline="; "))",
    ))
end

assert_action_workflow_diagnostics_no_failures(invocations) =
    assert_action_workflow_diagnostics_no_failures(action_workflow_diagnostics(invocations))

"""Assert that every workflow diagnostics invocation completed successfully."""
function assert_action_workflow_diagnostics_all_invoked(diagnostics::ActionWorkflowDiagnostics)
    action_workflow_diagnostics_all_invoked(diagnostics) && return diagnostics
    throw(ArgumentError(
        "expected all action workflow invocations to be invoked, got $(action_invocation_summary_text(diagnostics.invocations; newline="; "))",
    ))
end

assert_action_workflow_diagnostics_all_invoked(invocations) =
    assert_action_workflow_diagnostics_all_invoked(action_workflow_diagnostics(invocations))

"""Assert that workflow diagnostics contain no missing, disabled, or failed invocations."""
function assert_action_workflow_diagnostics_no_issues(diagnostics::ActionWorkflowDiagnostics)
    action_workflow_diagnostics_has_issues(diagnostics) || return diagnostics
    throw(ArgumentError(
        "expected no action workflow invocation issues, got $(action_invocations_text(diagnostics.issues; newline="; "))",
    ))
end

assert_action_workflow_diagnostics_no_issues(invocations) =
    assert_action_workflow_diagnostics_no_issues(action_workflow_diagnostics(invocations))

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

"""
    invoke_key_action_diagnostics!(registry, event, context=ActionContext(; event))

Invoke one key event through the action registry and return
`ActionWorkflowDiagnostics`.
"""
invoke_key_action_diagnostics!(
    registry::ActionRegistry,
    event::KeyEvent,
    context::ActionContext=ActionContext(; event),
) = action_workflow_diagnostics(invoke_key_action!(registry, event, context))

"""
    invoke_key_actions!(registry, events, context=ActionContext())

Invoke a sequence of key events through the action registry and return the
resulting `ActionInvocation` values.
"""
function invoke_key_actions!(
    registry::ActionRegistry,
    events,
    context::ActionContext=ActionContext(),
)
    return ActionInvocation[
        invoke_key_action!(registry, event, ActionContext(
            application=context.application,
            screen=context.screen,
            focused=context.focused,
            event=event,
            data=context.data,
        ))
        for event in events
    ]
end

"""
    invoke_key_actions_diagnostics!(registry, events, context=ActionContext())

Invoke a sequence of key events through the action registry and return
`ActionWorkflowDiagnostics`.
"""
function invoke_key_actions_diagnostics!(
    registry::ActionRegistry,
    events,
    context::ActionContext=ActionContext(),
)
    return action_workflow_diagnostics(invoke_key_actions!(registry, events, context))
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

"""
    search_action_binding_map(registry, query, context=ActionContext(); include_hidden=false)

Build a `BindingMap` from visible and enabled actions matching `query`.
"""
function search_action_binding_map(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
)
    winners = Dict{Tuple{Symbol,KeyModifiers},Tuple{ActionState,ActionBinding}}()
    for state in _search_action_states(registry, query, context; include_hidden, include_disabled=false)
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

"""
    search_action_binding_layer(registry, query, context=ActionContext(); name=:actions, active=true, include_hidden=false)

Adapt visible and enabled actions matching `query` to a named `BindingLayer`.
"""
function search_action_binding_layer(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    name::Union{Symbol,AbstractString}=:actions,
    active::Bool=true,
    include_hidden::Bool=false,
)
    return BindingLayer(Symbol(name), search_action_binding_map(registry, query, context; include_hidden); active=active)
end

"""
    search_action_binding_stack(registry, query, context=ActionContext(); name=:actions, layer=:actions, active=true, include_hidden=false)

Adapt visible and enabled actions matching `query` to a one-layer
`BindingStack`.
"""
function search_action_binding_stack(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    name::Union{Symbol,AbstractString}=:actions,
    layer::Union{Symbol,AbstractString}=:actions,
    active::Bool=true,
    include_hidden::Bool=false,
)
    return BindingStack(
        Symbol(name),
        search_action_binding_layer(registry, query, context; name=layer, active=active, include_hidden),
    )
end

"""
    action_binding_layer(registry, context=ActionContext(); name=:actions, active=true)

Adapt currently visible and enabled action bindings to a named `BindingLayer`.
Use this when an application composes actions with component, screen, modal, or
global binding layers.
"""
function action_binding_layer(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    name::Union{Symbol,AbstractString}=:actions,
    active::Bool=true,
)
    return BindingLayer(Symbol(name), action_binding_map(registry, context); active=active)
end

"""
    action_binding_stack(registry, context=ActionContext(); name=:actions, layer=:actions, active=true)

Adapt currently visible and enabled action bindings to a one-layer
`BindingStack`. Applications can push additional layers for screens, modals, or
focused components.
"""
function action_binding_stack(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    name::Union{Symbol,AbstractString}=:actions,
    layer::Union{Symbol,AbstractString}=:actions,
    active::Bool=true,
)
    return BindingStack(Symbol(name), action_binding_layer(registry, context; name=layer, active=active))
end

"""
    action_help_lines(registry, context=ActionContext(); separator="  ")

Render currently visible and enabled action shortcuts as help lines.
"""
action_help_lines(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    separator::AbstractString="  ",
) = binding_help_lines(action_binding_map(registry, context); separator)

"""
    action_help_text(registry, context=ActionContext(); separator="  ", newline="\\n")

Render currently visible and enabled action shortcuts as newline-separated help
text.
"""
action_help_text(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    separator::AbstractString="  ",
    newline::AbstractString="\n",
) = binding_help_text(action_binding_map(registry, context); separator, newline)

"""
    action_help_view(registry, context=ActionContext(); kwargs...)

Build a ready-to-render `HelpView` from currently visible and enabled action
shortcuts. Keyword arguments are forwarded to `HelpView`.
"""
function action_help_view(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    kwargs...,
)
    hints = KeyHint[
        KeyHint(record.action, record.description)
        for record in binding_records(action_binding_map(registry, context))
        if !isempty(record.description)
    ]
    return HelpView(hints; kwargs...)
end

"""
    action_footer(registry, context=ActionContext(); kwargs...)

Build a ready-to-render `Footer` from currently visible and enabled action
shortcuts. Keyword arguments are forwarded to `Footer`.
"""
function action_footer(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    kwargs...,
)
    hints = KeyHint[
        KeyHint(record.action, record.description)
        for record in binding_records(action_binding_map(registry, context))
        if !isempty(record.description)
    ]
    return Footer(hints; kwargs...)
end

"""
    action_surface(registry, context=ActionContext(); open=true, selected=nothing, binding_name=:actions, binding_layer=:actions, include_disabled=true)

Build a complete ready-to-use action UI bundle from currently visible actions.
The returned named tuple contains `bindings`, `layer`, `stack`, `palette`,
`palette_state`, `menu`, `menu_state`, `help_view`, and `footer` fields.
"""
function action_surface(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    open::Bool=true,
    selected::Union{Nothing,Integer}=nothing,
    binding_name::Union{Symbol,AbstractString}=:actions,
    binding_layer::Union{Symbol,AbstractString}=:actions,
    include_disabled::Bool=true,
)
    bindings = action_binding_map(registry, context)
    layer = BindingLayer(Symbol(binding_layer), bindings)
    stack = BindingStack(Symbol(binding_name), layer)
    palette_session = action_command_palette_session(registry, context; open, include_disabled)
    menu_session = action_menu_session(registry, context; selected, include_disabled)
    return (
        bindings=bindings,
        layer=layer,
        stack=stack,
        palette=palette_session.palette,
        palette_state=palette_session.state,
        menu=menu_session.menu,
        menu_state=menu_session.state,
        help_view=action_help_view(registry, context),
        footer=action_footer(registry, context),
    )
end

"""
    action_category_surfaces(registry, context=ActionContext(); open=true, selected=nothing, binding_name=:actions, include_disabled=true)

Build one ready-to-use action UI bundle per visible action category. Each
returned record contains `category`, `bindings`, `layer`, `stack`, `palette`,
`palette_state`, `menu`, `menu_state`, `help_view`, and `footer` fields.
"""
function action_category_surfaces(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    open::Bool=true,
    selected::Union{Nothing,Integer}=nothing,
    binding_name::Union{Symbol,AbstractString}=:actions,
    include_disabled::Bool=true,
)
    maps = Dict(entry.category => entry.map for entry in action_category_binding_maps(registry, context))
    palettes = Dict(entry.category => entry for entry in action_category_command_palette_sessions(registry, context; open, include_disabled))
    menus = Dict(entry.category => entry for entry in action_category_menu_sessions(registry, context; selected, include_disabled))
    help_views = Dict(entry.category => entry.view for entry in action_category_help_views(registry, context))
    footers = Dict(entry.category => entry.footer for entry in action_category_footers(registry, context))
    return [
        begin
            layer = BindingLayer(Symbol(category), maps[category])
            (
                category=category,
                bindings=maps[category],
                layer=layer,
                stack=BindingStack(Symbol(binding_name), layer),
                palette=palettes[category].palette,
                palette_state=palettes[category].state,
                menu=menus[category].menu,
                menu_state=menus[category].state,
                help_view=help_views[category],
                footer=footers[category],
            )
        end
        for category in sort!(collect(keys(maps)))
    ]
end

function _action_states_binding_map(states)
    winners = Dict{Tuple{Symbol,KeyModifiers},Tuple{ActionState,ActionBinding}}()
    for state in states
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

function _binding_map_hints(map::BindingMap)
    return KeyHint[
        KeyHint(record.action, record.description)
        for record in binding_records(map)
        if !isempty(record.description)
    ]
end

"""
    action_category_binding_maps(registry, context=ActionContext())

Build one `BindingMap` per category from currently visible and enabled action
shortcuts. Each returned record has `category` and `map` fields.
"""
function action_category_binding_maps(
    registry::ActionRegistry,
    context::ActionContext=ActionContext(),
)
    grouped = Dict{String,Vector{ActionState}}()
    for state in available_actions(registry, context; include_hidden=false, include_disabled=false)
        push!(get!(grouped, state.action.category, ActionState[]), state)
    end
    return [
        (category=category, map=_action_states_binding_map(grouped[category]))
        for category in sort!(collect(keys(grouped)))
    ]
end

"""
    action_category_binding_layers(registry, context=ActionContext(); active=true)

Build one `BindingLayer` per category from currently visible and enabled action
shortcuts. Each returned record has `category` and `layer` fields.
"""
function action_category_binding_layers(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    active::Bool=true,
)
    return [
        (category=entry.category, layer=BindingLayer(Symbol(entry.category), entry.map; active))
        for entry in action_category_binding_maps(registry, context)
    ]
end

"""
    action_category_binding_stacks(registry, context=ActionContext(); name=:actions, active=true)

Build one one-layer `BindingStack` per category from currently visible and
enabled action shortcuts. Each returned record has `category` and `stack` fields.
"""
function action_category_binding_stacks(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    name::Union{Symbol,AbstractString}=:actions,
    active::Bool=true,
)
    return [
        (
            category=entry.category,
            stack=BindingStack(Symbol(name), BindingLayer(Symbol(entry.category), entry.map; active)),
        )
        for entry in action_category_binding_maps(registry, context)
    ]
end

"""
    action_category_help_lines(registry, context=ActionContext(); separator="  ")

Render shortcut help lines grouped by visible action category. Each returned
record has `category` and `lines` fields.
"""
function action_category_help_lines(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    separator::AbstractString="  ",
)
    return [
        (category=entry.category, lines=binding_help_lines(entry.map; separator))
        for entry in action_category_binding_maps(registry, context)
    ]
end

"""
    action_category_help_text(registry, context=ActionContext(); separator="  ", newline="\\n")

Render shortcut help text grouped by visible action category. Each returned
record has `category` and `text` fields.
"""
function action_category_help_text(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    separator::AbstractString="  ",
    newline::AbstractString="\n",
)
    return [
        (category=entry.category, text=binding_help_text(entry.map; separator, newline))
        for entry in action_category_binding_maps(registry, context)
    ]
end

"""
    action_category_help_views(registry, context=ActionContext(); kwargs...)

Build one ready-to-render `HelpView` per visible action category. Each returned
record has `category` and `view` fields.
"""
function action_category_help_views(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    kwargs...,
)
    return [
        (category=entry.category, view=HelpView(_binding_map_hints(entry.map); kwargs...))
        for entry in action_category_binding_maps(registry, context)
    ]
end

"""
    action_category_footers(registry, context=ActionContext(); kwargs...)

Build one ready-to-render `Footer` per visible action category. Each returned
record has `category` and `footer` fields.
"""
function action_category_footers(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    kwargs...,
)
    return [
        (category=entry.category, footer=Footer(_binding_map_hints(entry.map); kwargs...))
        for entry in action_category_binding_maps(registry, context)
    ]
end

"""
    search_action_category_binding_maps(registry, query, context=ActionContext(); include_hidden=false)

Build one `BindingMap` per category from visible and enabled actions matching
`query`. Each returned record has `category` and `map` fields.
"""
function search_action_category_binding_maps(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
)
    grouped = Dict{String,Vector{ActionState}}()
    for state in _search_action_states(registry, query, context; include_hidden, include_disabled=false)
        push!(get!(grouped, state.action.category, ActionState[]), state)
    end
    return [
        (category=category, map=_action_states_binding_map(grouped[category]))
        for category in sort!(collect(keys(grouped)))
    ]
end

"""
    search_action_category_binding_layers(registry, query, context=ActionContext(); active=true, include_hidden=false)

Build one `BindingLayer` per category from visible and enabled actions matching
`query`. Each returned record has `category` and `layer` fields.
"""
function search_action_category_binding_layers(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    active::Bool=true,
    include_hidden::Bool=false,
)
    return [
        (category=entry.category, layer=BindingLayer(Symbol(entry.category), entry.map; active))
        for entry in search_action_category_binding_maps(registry, query, context; include_hidden)
    ]
end

"""
    search_action_category_binding_stacks(registry, query, context=ActionContext(); name=:actions, active=true, include_hidden=false)

Build one one-layer `BindingStack` per category from visible and enabled actions
matching `query`. Each returned record has `category` and `stack` fields.
"""
function search_action_category_binding_stacks(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    name::Union{Symbol,AbstractString}=:actions,
    active::Bool=true,
    include_hidden::Bool=false,
)
    return [
        (
            category=entry.category,
            stack=BindingStack(Symbol(name), BindingLayer(Symbol(entry.category), entry.map; active)),
        )
        for entry in search_action_category_binding_maps(registry, query, context; include_hidden)
    ]
end

"""
    search_action_category_help_lines(registry, query, context=ActionContext(); include_hidden=false, separator="  ")

Render shortcut help lines grouped by category for visible and enabled actions
matching `query`. Each returned record has `category` and `lines` fields.
"""
function search_action_category_help_lines(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    separator::AbstractString="  ",
)
    return [
        (category=entry.category, lines=binding_help_lines(entry.map; separator))
        for entry in search_action_category_binding_maps(registry, query, context; include_hidden)
    ]
end

"""
    search_action_category_help_text(registry, query, context=ActionContext(); include_hidden=false, separator="  ", newline="\\n")

Render shortcut help text grouped by category for visible and enabled actions
matching `query`. Each returned record has `category` and `text` fields.
"""
function search_action_category_help_text(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    separator::AbstractString="  ",
    newline::AbstractString="\n",
)
    return [
        (category=entry.category, text=binding_help_text(entry.map; separator, newline))
        for entry in search_action_category_binding_maps(registry, query, context; include_hidden)
    ]
end

"""
    search_action_category_help_views(registry, query, context=ActionContext(); include_hidden=false, kwargs...)

Build one `HelpView` per category from visible and enabled actions matching
`query`. Each returned record has `category` and `view` fields.
"""
function search_action_category_help_views(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    kwargs...,
)
    return [
        (category=entry.category, view=HelpView(_binding_map_hints(entry.map); kwargs...))
        for entry in search_action_category_binding_maps(registry, query, context; include_hidden)
    ]
end

"""
    search_action_category_footers(registry, query, context=ActionContext(); include_hidden=false, kwargs...)

Build one `Footer` per category from visible and enabled actions matching
`query`. Each returned record has `category` and `footer` fields.
"""
function search_action_category_footers(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    kwargs...,
)
    return [
        (category=entry.category, footer=Footer(_binding_map_hints(entry.map); kwargs...))
        for entry in search_action_category_binding_maps(registry, query, context; include_hidden)
    ]
end

"""
    search_action_help_lines(registry, query, context=ActionContext(); include_hidden=false, separator="  ")

Render shortcut help lines for visible, enabled actions matching `query`.
"""
search_action_help_lines(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    separator::AbstractString="  ",
) = binding_help_lines(search_action_binding_map(registry, query, context; include_hidden); separator)

"""
    search_action_help_text(registry, query, context=ActionContext(); include_hidden=false, separator="  ", newline="\\n")

Render shortcut help text for visible, enabled actions matching `query`.
"""
search_action_help_text(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    separator::AbstractString="  ",
    newline::AbstractString="\n",
) = binding_help_text(search_action_binding_map(registry, query, context; include_hidden); separator, newline)

"""
    search_action_help_view(registry, query, context=ActionContext(); include_hidden=false, kwargs...)

Build a `HelpView` from visible, enabled actions matching `query`.
"""
function search_action_help_view(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    kwargs...,
)
    hints = KeyHint[
        KeyHint(record.action, record.description)
        for record in binding_records(search_action_binding_map(registry, query, context; include_hidden))
        if !isempty(record.description)
    ]
    return HelpView(hints; kwargs...)
end

"""
    search_action_footer(registry, query, context=ActionContext(); include_hidden=false, kwargs...)

Build a `Footer` from visible, enabled actions matching `query`.
"""
function search_action_footer(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    kwargs...,
)
    hints = KeyHint[
        KeyHint(record.action, record.description)
        for record in binding_records(search_action_binding_map(registry, query, context; include_hidden))
        if !isempty(record.description)
    ]
    return Footer(hints; kwargs...)
end

"""
    search_action_surface(registry, query, context=ActionContext(); open=true, selected=nothing, binding_name=:actions, binding_layer=:actions, include_hidden=false, include_disabled=true)

Build a complete ready-to-use action UI bundle from actions matching `query`.
The returned named tuple contains `bindings`, `layer`, `stack`, `palette`,
`palette_state`, `menu`, `menu_state`, `help_view`, and `footer` fields.
"""
function search_action_surface(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    open::Bool=true,
    selected::Union{Nothing,Integer}=nothing,
    binding_name::Union{Symbol,AbstractString}=:actions,
    binding_layer::Union{Symbol,AbstractString}=:actions,
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    bindings = search_action_binding_map(registry, query, context; include_hidden)
    layer = BindingLayer(Symbol(binding_layer), bindings)
    stack = BindingStack(Symbol(binding_name), layer)
    palette_session = search_action_command_palette_session(
        registry,
        query,
        context;
        open,
        include_hidden,
        include_disabled,
    )
    menu_session = search_action_menu_session(
        registry,
        query,
        context;
        selected,
        include_hidden,
        include_disabled,
    )
    return (
        bindings=bindings,
        layer=layer,
        stack=stack,
        palette=palette_session.palette,
        palette_state=palette_session.state,
        menu=menu_session.menu,
        menu_state=menu_session.state,
        help_view=search_action_help_view(registry, query, context; include_hidden),
        footer=search_action_footer(registry, query, context; include_hidden),
    )
end

"""
    search_action_category_surfaces(registry, query, context=ActionContext(); open=true, selected=nothing, binding_name=:actions, include_hidden=false, include_disabled=true)

Build one ready-to-use action UI bundle per matching action category. Each
returned record contains `category`, `bindings`, `layer`, `stack`, `palette`,
`palette_state`, `menu`, `menu_state`, `help_view`, and `footer` fields.
"""
function search_action_category_surfaces(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    open::Bool=true,
    selected::Union{Nothing,Integer}=nothing,
    binding_name::Union{Symbol,AbstractString}=:actions,
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    maps = Dict(entry.category => entry.map for entry in search_action_category_binding_maps(registry, query, context; include_hidden))
    palettes = Dict(entry.category => entry for entry in search_action_category_command_palette_sessions(registry, query, context; open, include_hidden, include_disabled))
    menus = Dict(entry.category => entry for entry in search_action_category_menu_sessions(registry, query, context; selected, include_hidden, include_disabled))
    help_views = Dict(entry.category => entry.view for entry in search_action_category_help_views(registry, query, context; include_hidden))
    footers = Dict(entry.category => entry.footer for entry in search_action_category_footers(registry, query, context; include_hidden))
    return [
        begin
            layer = BindingLayer(Symbol(category), maps[category])
            (
                category=category,
                bindings=maps[category],
                layer=layer,
                stack=BindingStack(Symbol(binding_name), layer),
                palette=palettes[category].palette,
                palette_state=palettes[category].state,
                menu=menus[category].menu,
                menu_state=menus[category].state,
                help_view=help_views[category],
                footer=footers[category],
            )
        end
        for category in sort!(collect(keys(maps)))
    ]
end

function action_command_items(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_disabled::Bool=true,
)
    return CommandItem[
        _action_command_item(state) for state in available_actions(
            registry,
            context;
            include_hidden=false,
            include_disabled,
        )
    ]
end

function _action_command_item(state::ActionState)
    return CommandItem(
        state.action.id,
        state.action.title,
        state.action.id;
        description=state.action.description,
        keywords=vcat(state.action.keywords, [lowercase(state.action.category)]),
        disabled=!state.enabled,
    )
end

"""
    action_command_sections(registry, context=ActionContext(); include_disabled=true)

Group currently visible actions into deterministic command-palette sections by
action category. Each returned record has `category` and `items` fields.
"""
function action_command_sections(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_disabled::Bool=true,
)
    grouped = Dict{String,Vector{CommandItem}}()
    for state in available_actions(registry, context; include_hidden=false, include_disabled)
        push!(get!(grouped, state.action.category, CommandItem[]), _action_command_item(state))
    end
    return [
        (category=category, items=grouped[category])
        for category in sort!(collect(keys(grouped)))
    ]
end

"""
    action_category_command_palettes(registry, context=ActionContext(); include_disabled=true)

Build one ready-to-render `CommandPalette` per visible action category. Each
returned record has `category` and `palette` fields.
"""
function action_category_command_palettes(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_disabled::Bool=true,
)
    return [
        (category=section.category, palette=CommandPalette(section.items))
        for section in action_command_sections(registry, context; include_disabled)
    ]
end

"""
    action_category_command_palette_sessions(registry, context=ActionContext(); query="", open=true, include_disabled=true)

Build one ready-to-render command palette session per visible action category.
Each returned record has `category`, `palette`, and `state` fields.
"""
function action_category_command_palette_sessions(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    query::AbstractString="",
    open::Bool=true,
    include_disabled::Bool=true,
)
    return [
        begin
            state = CommandPaletteState(; open)
            isempty(query) || set_command_palette_query!(state, entry.palette, query; record=false)
            (category=entry.category, palette=entry.palette, state=state)
        end
        for entry in action_category_command_palettes(registry, context; include_disabled)
    ]
end

function _action_menu_shortcut(state::ActionState)
    isempty(state.action.bindings) && return ""
    bindings = sort(collect(state.action.bindings); by=binding -> (
        _action_binding_priority(state.action.priority, binding.priority),
        String(binding.key),
        string(binding.modifiers),
    ))
    first_binding = first(bindings)
    return binding_label(first_binding.key; modifiers=first_binding.modifiers)
end

function _action_menu_item(state::ActionState)
    return MenuItem(
        state.action.id,
        state.action.title,
        state.action.id;
        shortcut=_action_menu_shortcut(state),
        disabled=!state.enabled,
    )
end

"""
    action_menu_items(registry, context=ActionContext(); include_disabled=true)

Build `MenuItem` values from currently visible actions. Activating a menu item
returns the action ID so applications can pass it to `invoke_action!`.
"""
function action_menu_items(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_disabled::Bool=true,
)
    return MenuItem[
        _action_menu_item(state) for state in available_actions(
            registry,
            context;
            include_hidden=false,
            include_disabled,
        )
    ]
end

"""
    action_menu(registry, context=ActionContext(); include_disabled=true, kwargs...)

Build a ready-to-render `Menu` from currently visible actions.
"""
action_menu(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_disabled::Bool=true,
    kwargs...,
) = Menu(action_menu_items(registry, context; include_disabled); kwargs...)

"""
    action_menu_session(registry, context=ActionContext(); selected=nothing, include_disabled=true, kwargs...)

Build a ready-to-render menu and matching `MenuState` from currently visible
actions. The returned named tuple has `menu` and `state` fields. Pass `selected`
when an app wants the menu to open with a deterministic highlighted item.
"""
function action_menu_session(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    selected::Union{Nothing,Integer}=nothing,
    include_disabled::Bool=true,
    kwargs...,
)
    return (
        menu=action_menu(registry, context; include_disabled, kwargs...),
        state=MenuState(; selected),
    )
end

"""
    action_menu_sections(registry, context=ActionContext(); include_disabled=true)

Group currently visible actions into deterministic menu sections by action
category. Each returned record has `category` and `items` fields.
"""
function action_menu_sections(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_disabled::Bool=true,
)
    grouped = Dict{String,Vector{MenuItem}}()
    for state in available_actions(registry, context; include_hidden=false, include_disabled)
        push!(get!(grouped, state.action.category, MenuItem[]), _action_menu_item(state))
    end
    return [
        (category=category, items=grouped[category])
        for category in sort!(collect(keys(grouped)))
    ]
end

"""
    action_category_menus(registry, context=ActionContext(); include_disabled=true, kwargs...)

Build one ready-to-render `Menu` per visible action category. Each returned
record has `category` and `menu` fields.
"""
function action_category_menus(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_disabled::Bool=true,
    kwargs...,
)
    return [
        (category=section.category, menu=Menu(section.items; kwargs...))
        for section in action_menu_sections(registry, context; include_disabled)
    ]
end

"""
    action_category_menu_sessions(registry, context=ActionContext(); selected=nothing, include_disabled=true, kwargs...)

Build one ready-to-render menu session per visible action category. Each returned
record has `category`, `menu`, and `state` fields.
"""
function action_category_menu_sessions(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    selected::Union{Nothing,Integer}=nothing,
    include_disabled::Bool=true,
    kwargs...,
)
    return [
        (category=entry.category, menu=entry.menu, state=MenuState(; selected))
        for entry in action_category_menus(registry, context; include_disabled, kwargs...)
    ]
end

function _search_action_states(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    prepared_query = _action_search_query(query)
    return [
        state for state in available_actions(
            registry,
            context;
            include_hidden,
            include_disabled,
        )
        if _action_record_query_matches(_action_state_record(state), prepared_query)
    ]
end

"""
    search_action_menu_items(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Build `MenuItem` values from actions matching `query`.
"""
function search_action_menu_items(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    return MenuItem[
        _action_menu_item(state)
        for state in _search_action_states(registry, query, context; include_hidden, include_disabled)
    ]
end

"""
    search_action_menu(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true, kwargs...)

Build a ready-to-render `Menu` from actions matching `query`.
"""
search_action_menu(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    kwargs...,
) = Menu(search_action_menu_items(registry, query, context; include_hidden, include_disabled); kwargs...)

"""
    search_action_menu_session(registry, query, context=ActionContext(); selected=nothing, include_hidden=false, include_disabled=true, kwargs...)

Build a ready-to-render menu session from actions matching `query`. The returned
named tuple has `menu` and `state` fields.
"""
function search_action_menu_session(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    selected::Union{Nothing,Integer}=nothing,
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    kwargs...,
)
    return (
        menu=search_action_menu(registry, query, context; include_hidden, include_disabled, kwargs...),
        state=MenuState(; selected),
    )
end

"""
    search_action_menu_sections(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Group matching actions into deterministic menu sections by action category.
"""
function search_action_menu_sections(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    grouped = Dict{String,Vector{MenuItem}}()
    for state in _search_action_states(registry, query, context; include_hidden, include_disabled)
        push!(get!(grouped, state.action.category, MenuItem[]), _action_menu_item(state))
    end
    return [
        (category=category, items=grouped[category])
        for category in sort!(collect(keys(grouped)))
    ]
end

"""
    search_action_category_menus(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true, kwargs...)

Build one ready-to-render `Menu` per matching action category.
"""
function search_action_category_menus(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    kwargs...,
)
    return [
        (category=section.category, menu=Menu(section.items; kwargs...))
        for section in search_action_menu_sections(
            registry,
            query,
            context;
            include_hidden,
            include_disabled,
        )
    ]
end

"""
    search_action_category_menu_sessions(registry, query, context=ActionContext(); selected=nothing, include_hidden=false, include_disabled=true, kwargs...)

Build one ready-to-render menu session per matching action category. Each
returned record has `category`, `menu`, and `state` fields.
"""
function search_action_category_menu_sessions(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    selected::Union{Nothing,Integer}=nothing,
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    kwargs...,
)
    return [
        (category=entry.category, menu=entry.menu, state=MenuState(; selected))
        for entry in search_action_category_menus(
            registry,
            query,
            context;
            include_hidden,
            include_disabled,
            kwargs...,
        )
    ]
end

"""
    search_action_command_items(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Build `CommandItem` values from actions matching `query`.
"""
function search_action_command_items(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    return CommandItem[
        _action_command_item(state)
        for state in _search_action_states(registry, query, context; include_hidden, include_disabled)
    ]
end

"""
    search_action_command_palette(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Build a ready-to-render `CommandPalette` from actions matching `query`.
"""
search_action_command_palette(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
) = CommandPalette(
    search_action_command_items(registry, query, context; include_hidden, include_disabled),
)

"""
    search_action_command_palette_session(registry, query, context=ActionContext(); palette_query="", open=true, include_hidden=false, include_disabled=true)

Build a ready-to-render command palette session from actions matching `query`.
Use `palette_query` when the returned palette should also start with command
text in its input field.
"""
function search_action_command_palette_session(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    palette_query::AbstractString="",
    open::Bool=true,
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    palette = search_action_command_palette(registry, query, context; include_hidden, include_disabled)
    state = CommandPaletteState(; open)
    isempty(palette_query) || set_command_palette_query!(state, palette, palette_query; record=false)
    return (palette=palette, state=state)
end

"""
    search_action_command_sections(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Group matching actions into deterministic command-palette sections by action
category.
"""
function search_action_command_sections(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    grouped = Dict{String,Vector{CommandItem}}()
    for state in _search_action_states(registry, query, context; include_hidden, include_disabled)
        push!(get!(grouped, state.action.category, CommandItem[]), _action_command_item(state))
    end
    return [
        (category=category, items=grouped[category])
        for category in sort!(collect(keys(grouped)))
    ]
end

"""
    search_action_category_command_palettes(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Build one ready-to-render `CommandPalette` per matching action category.
"""
function search_action_category_command_palettes(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    return [
        (category=section.category, palette=CommandPalette(section.items))
        for section in search_action_command_sections(
            registry,
            query,
            context;
            include_hidden,
            include_disabled,
        )
    ]
end

"""
    search_action_category_command_palette_sessions(registry, query, context=ActionContext(); palette_query="", open=true, include_hidden=false, include_disabled=true)

Build one ready-to-render command palette session per matching action category.
Each returned record has `category`, `palette`, and `state` fields.
"""
function search_action_category_command_palette_sessions(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    palette_query::AbstractString="",
    open::Bool=true,
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    return [
        begin
            state = CommandPaletteState(; open)
            isempty(palette_query) || set_command_palette_query!(state, entry.palette, palette_query; record=false)
            (category=entry.category, palette=entry.palette, state=state)
        end
        for entry in search_action_category_command_palettes(
            registry,
            query,
            context;
            include_hidden,
            include_disabled,
        )
    ]
end

"""
    action_command_palette(registry, context=ActionContext(); include_disabled=true)

Build a `CommandPalette` from currently visible actions. This is a convenience
wrapper over `action_command_items` for applications that want a ready-to-render
command palette surface.
"""
action_command_palette(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_disabled::Bool=true,
) = CommandPalette(action_command_items(registry, context; include_disabled))

"""
    action_command_palette_session(registry, context=ActionContext(); query="", open=true, include_disabled=true)

Build a ready-to-render command palette and matching `CommandPaletteState` from
currently visible actions. The returned named tuple has `palette` and `state`
fields. Pass `query` to pre-filter the palette before the first render.
"""
function action_command_palette_session(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    query::AbstractString="",
    open::Bool=true,
    include_disabled::Bool=true,
)
    palette = action_command_palette(registry, context; include_disabled)
    state = CommandPaletteState(; open)
    isempty(query) || set_command_palette_query!(state, palette, query; record=false)
    return (palette=palette, state=state)
end

function _action_binding_record(binding::ActionBinding)
    return (
        key=binding.key,
        modifiers=binding.modifiers,
        label=binding_label(binding.key; modifiers=binding.modifiers),
        description=binding.description,
        priority=binding.priority,
    )
end

function _action_state_record(state::ActionState)
    return (
        id=state.action.id,
        title=state.action.title,
        description=state.action.description,
        category=state.action.category,
        keywords=copy(state.action.keywords),
        scope=state.scope,
        enabled=state.enabled,
        visible=state.visible,
        checked=state.checked,
        priority=state.action.priority,
        bindings=[_action_binding_record(binding) for binding in state.action.bindings],
    )
end

"""
    action_records(registry, context=ActionContext(); include_hidden=false, include_disabled=true)

Return currently resolved actions as plain named tuples for diagnostics,
generated docs, command surfaces, tests, and automation.
"""
function action_records(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    return [
        _action_state_record(state)
        for state in available_actions(
            registry,
            context;
            include_hidden=include_hidden,
            include_disabled=include_disabled,
        )
    ]
end

"""
    action_summary(registry, context=ActionContext())

Return compact action registry diagnostics with total, visible, hidden, enabled,
disabled, checked, errored, and active scope counts.
"""
function action_summary(registry::ActionRegistry, context::ActionContext=ActionContext())
    states = available_actions(registry, context; include_hidden=true, include_disabled=true)
    visible = count(state -> state.visible, states)
    enabled = count(state -> state.visible && state.enabled, states)
    checked = count(state -> state.visible && state.checked, states)
    errored = count(state -> state.error !== nothing, states)
    scopes = active_action_scopes(registry)
    return (
        total=length(states),
        visible=visible,
        hidden=length(states) - visible,
        enabled=enabled,
        disabled=visible - enabled,
        checked=checked,
        errored=errored,
        scopes=length(scopes),
        active_scopes=scopes,
    )
end

"""
    action_categories(registry, context=ActionContext(); include_hidden=false, include_disabled=true)

Return sorted action category names for the currently resolved actions.
"""
function action_categories(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    records = action_records(
        registry,
        context;
        include_hidden=include_hidden,
        include_disabled=include_disabled,
    )
    return sort!(collect(Set(record.category for record in records)))
end

"""
    action_category_records(registry, context=ActionContext(); include_hidden=false, include_disabled=true)

Return grouped action category records with counts and action IDs.
"""
function action_category_records(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    grouped = Dict{String,Vector{NamedTuple}}()
    for record in action_records(
        registry,
        context;
        include_hidden=include_hidden,
        include_disabled=include_disabled,
    )
        push!(get!(grouped, record.category, NamedTuple[]), record)
    end
    rows = [
        (
            category=category,
            count=length(records),
            enabled=count(record -> record.enabled, records),
            disabled=count(record -> !record.enabled, records),
            checked=count(record -> record.checked, records),
            actions=Symbol[record.id for record in records],
        )
        for (category, records) in grouped
    ]
    return sort!(rows; by=row -> lowercase(row.category))
end

function _action_category_column(value)
    value isa Symbol && return value
    value isa AbstractString && return Symbol(value)
    throw(ArgumentError("action category columns must be Symbols or Strings"))
end

function _action_category_columns(columns)
    selected = if columns isa Symbol || columns isa AbstractString
        Symbol[_action_category_column(columns)]
    else
        try
            Symbol[_action_category_column(column) for column in columns]
        catch error
            error isa MethodError &&
                throw(ArgumentError("action category columns must be a Symbol, String, or iterable collection of Symbols or Strings"))
            rethrow()
        end
    end
    isempty(selected) && throw(ArgumentError("action category records require at least one column"))
    for column in selected
        column in (:category, :count, :enabled, :disabled, :checked, :actions) ||
            throw(ArgumentError("action category column must be one of :category, :count, :enabled, :disabled, :checked, or :actions"))
    end
    return selected
end

_action_category_actions_text(record) =
    join((String(id) for id in record.actions), ", ")

function _action_category_field(record, column::Symbol)
    column === :category && return record.category
    column === :count && return string(record.count)
    column === :enabled && return string(record.enabled)
    column === :disabled && return string(record.disabled)
    column === :checked && return string(record.checked)
    column === :actions && return _action_category_actions_text(record)
    throw(ArgumentError("action category column must be one of :category, :count, :enabled, :disabled, :checked, or :actions"))
end

function _action_category_records_markdown(records, selected)
    header = join(("`$(String(column))`" for column in selected), " | ")
    separator = join(fill("---", length(selected)), " | ")
    rows = String["| $header |", "| $separator |"]
    for record in records
        row = join((_escape_action_markdown(_action_category_field(record, column)) for column in selected), " | ")
        push!(rows, "| $row |")
    end
    return join(rows, "\n")
end

function _action_category_records_tsv(records, selected; header::Bool=true)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in records
        push!(rows, join((_escape_action_tsv(_action_category_field(record, column)) for column in selected), "\t"))
    end
    return join(rows, "\n")
end

"""
    action_category_records_markdown(registry, context=ActionContext(); include_hidden=false, include_disabled=true, columns=...)

Render grouped action category records as a GitHub-flavored Markdown table.
"""
function action_category_records_markdown(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    columns=(:category, :count, :enabled, :disabled, :actions),
)
    selected = _action_category_columns(columns)
    return _action_category_records_markdown(
        action_category_records(registry, context; include_hidden, include_disabled),
        selected,
    )
end

"""
    action_category_records_tsv(registry, context=ActionContext(); include_hidden=false, include_disabled=true, columns=..., header=true)

Render grouped action category records as tab-separated values.
"""
function action_category_records_tsv(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    columns=(:category, :count, :enabled, :disabled, :actions),
    header::Bool=true,
)
    selected = _action_category_columns(columns)
    return _action_category_records_tsv(
        action_category_records(registry, context; include_hidden, include_disabled),
        selected;
        header,
    )
end

function _action_category_record_query_matches(record, query)
    text = join((record.category, string(record.count), _action_category_actions_text(record)), " ")
    query isa Regex && return occursin(query, text)
    return occursin(query, lowercase(text))
end

"""
    search_action_categories(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Search grouped action category records by category name, count, or action IDs.
"""
function search_action_categories(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    prepared_query = _action_search_query(query)
    return [
        record for record in action_category_records(
            registry,
            context;
            include_hidden=include_hidden,
            include_disabled=include_disabled,
        )
        if _action_category_record_query_matches(record, prepared_query)
    ]
end

"""
    search_action_category_count(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Return the number of grouped action category records matching `query`.
"""
search_action_category_count(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
) = length(search_action_categories(registry, query, context; include_hidden, include_disabled))

"""
    search_action_category_records_markdown(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true, columns=...)

Search grouped action category records and render matches as Markdown.
"""
function search_action_category_records_markdown(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    columns=(:category, :count, :enabled, :disabled, :actions),
)
    selected = _action_category_columns(columns)
    return _action_category_records_markdown(
        search_action_categories(registry, query, context; include_hidden, include_disabled),
        selected,
    )
end

"""
    search_action_category_records_tsv(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true, columns=..., header=true)

Search grouped action category records and render matches as TSV.
"""
function search_action_category_records_tsv(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    columns=(:category, :count, :enabled, :disabled, :actions),
    header::Bool=true,
)
    selected = _action_category_columns(columns)
    return _action_category_records_tsv(
        search_action_categories(registry, query, context; include_hidden, include_disabled),
        selected;
        header,
    )
end

"""
    action_registry_snapshot(registry, context=ActionContext())

Return an immutable diagnostic snapshot of an action registry suitable for
inspectors, tests, logs, and automation.
"""
function action_registry_snapshot(
    registry::ActionRegistry,
    context::ActionContext=ActionContext(),
)
    summary = action_summary(registry, context)
    categories = action_categories(registry, context; include_hidden=true, include_disabled=true)
    return ActionRegistrySnapshot(
        action_registry_generation(registry),
        Symbol[scope for scope in summary.active_scopes],
        summary.total,
        summary.visible,
        summary.hidden,
        summary.enabled,
        summary.disabled,
        summary.checked,
        summary.errored,
        length(categories),
        String[category for category in categories],
        length(action_errors(registry)),
    )
end

"""
    action_registry_snapshot_record(snapshot_or_registry, context=ActionContext())

Return action registry snapshot data as a plain named tuple.
"""
action_registry_snapshot_record(snapshot::ActionRegistrySnapshot) = (
    generation=snapshot.generation,
    active_scopes=copy(snapshot.active_scopes),
    total=snapshot.total,
    visible=snapshot.visible,
    hidden=snapshot.hidden,
    enabled=snapshot.enabled,
    disabled=snapshot.disabled,
    checked=snapshot.checked,
    errored=snapshot.errored,
    category_count=snapshot.category_count,
    categories=copy(snapshot.categories),
    error_count=snapshot.error_count,
)

action_registry_snapshot_record(
    registry::ActionRegistry,
    context::ActionContext=ActionContext(),
) = action_registry_snapshot_record(action_registry_snapshot(registry, context))

"""
    action_registry_diagnostics(registry, context=ActionContext())

Return an immutable diagnostic bundle containing snapshot, summary, category
records, action records, binding records, and captured errors.
"""
function action_registry_diagnostics(
    registry::ActionRegistry,
    context::ActionContext=ActionContext(),
)
    return ActionRegistryDiagnostics(
        action_registry_snapshot(registry, context),
        action_summary(registry, context),
        action_category_records(registry, context; include_hidden=true, include_disabled=true),
        action_records(registry, context; include_hidden=true, include_disabled=true),
        binding_records(action_binding_map(registry, context)),
        action_errors(registry),
    )
end

"""
    action_registry_diagnostics_record(diagnostics_or_registry, context=ActionContext())

Return action registry diagnostics as a plain named tuple.
"""
action_registry_diagnostics_record(diagnostics::ActionRegistryDiagnostics) = (
    snapshot=action_registry_snapshot_record(diagnostics.snapshot),
    summary=diagnostics.summary,
    categories=copy(diagnostics.categories),
    actions=copy(diagnostics.actions),
    bindings=copy(diagnostics.bindings),
    errors=copy(diagnostics.errors),
)

action_registry_diagnostics_record(
    registry::ActionRegistry,
    context::ActionContext=ActionContext(),
) = action_registry_diagnostics_record(action_registry_diagnostics(registry, context))

function _action_registry_diagnostics_rows(diagnostics::ActionRegistryDiagnostics)
    return [
        ("generation", string(diagnostics.snapshot.generation)),
        ("active_scopes", join((String(scope) for scope in diagnostics.snapshot.active_scopes), ", ")),
        ("actions", string(diagnostics.summary.total)),
        ("visible", string(diagnostics.summary.visible)),
        ("hidden", string(diagnostics.summary.hidden)),
        ("enabled", string(diagnostics.summary.enabled)),
        ("disabled", string(diagnostics.summary.disabled)),
        ("checked", string(diagnostics.summary.checked)),
        ("errored", string(diagnostics.summary.errored)),
        ("categories", join(diagnostics.snapshot.categories, ", ")),
        ("category_count", string(diagnostics.snapshot.category_count)),
        ("bindings", string(length(diagnostics.bindings))),
        ("captured_errors", string(length(diagnostics.errors))),
    ]
end

"""
    action_registry_diagnostics_markdown(diagnostics_or_registry, context=ActionContext())

Render compact action registry diagnostics as a GitHub-flavored Markdown table.
"""
function action_registry_diagnostics_markdown(diagnostics::ActionRegistryDiagnostics)
    rows = String["| `metric` | `value` |", "| --- | --- |"]
    for (metric, value) in _action_registry_diagnostics_rows(diagnostics)
        push!(rows, "| $(_escape_action_markdown(metric)) | $(_escape_action_markdown(value)) |")
    end
    return join(rows, "\n")
end

action_registry_diagnostics_markdown(
    registry::ActionRegistry,
    context::ActionContext=ActionContext(),
) = action_registry_diagnostics_markdown(action_registry_diagnostics(registry, context))

"""
    action_registry_diagnostics_tsv(diagnostics_or_registry, context=ActionContext(); header=true)

Render compact action registry diagnostics as tab-separated values.
"""
function action_registry_diagnostics_tsv(
    diagnostics::ActionRegistryDiagnostics;
    header::Bool=true,
)
    rows = header ? String["metric\tvalue"] : String[]
    for (metric, value) in _action_registry_diagnostics_rows(diagnostics)
        push!(rows, "$(_escape_action_tsv(metric))\t$(_escape_action_tsv(value))")
    end
    return join(rows, "\n")
end

action_registry_diagnostics_tsv(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    header::Bool=true,
) = action_registry_diagnostics_tsv(action_registry_diagnostics(registry, context); header)

"""
    action_registry_diagnostics_text(diagnostics_or_registry, context=ActionContext(); newline="\\n")

Render compact action registry diagnostics as human-readable multi-line text for
logs, inspector panels, and quick debug output.
"""
function action_registry_diagnostics_text(
    diagnostics::ActionRegistryDiagnostics;
    newline::AbstractString="\n",
)
    lines = String[
        "Action registry diagnostics",
        "generation: $(diagnostics.snapshot.generation)",
        "active scopes: $(isempty(diagnostics.snapshot.active_scopes) ? "(none)" : join((String(scope) for scope in diagnostics.snapshot.active_scopes), ", "))",
        "actions: $(diagnostics.summary.total) total, $(diagnostics.summary.visible) visible, $(diagnostics.summary.enabled) enabled, $(diagnostics.summary.disabled) disabled",
        "categories: $(diagnostics.snapshot.category_count)$(isempty(diagnostics.snapshot.categories) ? "" : " (" * join(diagnostics.snapshot.categories, ", ") * ")")",
        "bindings: $(length(diagnostics.bindings))",
        "captured errors: $(length(diagnostics.errors))",
    ]
    return join(lines, newline)
end

action_registry_diagnostics_text(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    newline::AbstractString="\n",
) = action_registry_diagnostics_text(action_registry_diagnostics(registry, context); newline)

function _action_search_query(value)
    value isa Regex && return value
    value isa Symbol && return lowercase(String(value))
    value isa AbstractString && return lowercase(String(value))
    throw(ArgumentError("action search query must be a Regex, Symbol, or String"))
end

function _action_record_query_matches(record, query)
    text = join(
        (
            String(record.id),
            record.title,
            record.description,
            record.category,
            join(record.keywords, " "),
            String(record.scope),
            join((binding.label for binding in record.bindings), " "),
        ),
        " ",
    )
    query isa Regex && return occursin(query, text)
    return occursin(query, lowercase(text))
end

function _action_record_column(value)
    value isa Symbol && return value
    value isa AbstractString && return Symbol(value)
    throw(ArgumentError("action record columns must be Symbols or Strings"))
end

function _action_record_columns(columns)
    selected = if columns isa Symbol || columns isa AbstractString
        Symbol[_action_record_column(columns)]
    else
        try
            Symbol[_action_record_column(column) for column in columns]
        catch error
            error isa MethodError &&
                throw(ArgumentError("action record columns must be a Symbol, String, or iterable collection of Symbols or Strings"))
            rethrow()
        end
    end
    isempty(selected) && throw(ArgumentError("action records require at least one column"))
    for column in selected
        column in (:id, :title, :description, :category, :scope, :enabled, :visible, :checked, :priority, :keywords, :bindings) ||
            throw(ArgumentError("action record column must be one of :id, :title, :description, :category, :scope, :enabled, :visible, :checked, :priority, :keywords, or :bindings"))
    end
    return selected
end

_action_record_bindings_text(record) =
    join((binding.label for binding in record.bindings), ", ")

function _action_record_field(record, column::Symbol)
    column === :id && return String(record.id)
    column === :title && return record.title
    column === :description && return record.description
    column === :category && return record.category
    column === :scope && return String(record.scope)
    column === :enabled && return string(record.enabled)
    column === :visible && return string(record.visible)
    column === :checked && return string(record.checked)
    column === :priority && return string(record.priority)
    column === :keywords && return join(record.keywords, ", ")
    column === :bindings && return _action_record_bindings_text(record)
    throw(ArgumentError("action record column must be one of :id, :title, :description, :category, :scope, :enabled, :visible, :checked, :priority, :keywords, or :bindings"))
end

_escape_action_markdown(value::AbstractString) =
    replace(value, "\\" => "\\\\", "|" => "\\|", "\n" => " ")

_escape_action_markdown(value) = _escape_action_markdown(string(value))

_escape_action_tsv(value::AbstractString) =
    replace(value, "\t" => " ", "\r" => " ", "\n" => " ")

_escape_action_tsv(value) = _escape_action_tsv(string(value))

function _action_records_markdown(records, selected)
    header = join(("`$(String(column))`" for column in selected), " | ")
    separator = join(fill("---", length(selected)), " | ")
    rows = String["| $header |", "| $separator |"]
    for record in records
        row = join((_escape_action_markdown(_action_record_field(record, column)) for column in selected), " | ")
        push!(rows, "| $row |")
    end
    return join(rows, "\n")
end

function _action_records_tsv(records, selected; header::Bool=true)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in records
        push!(rows, join((_escape_action_tsv(_action_record_field(record, column)) for column in selected), "\t"))
    end
    return join(rows, "\n")
end

"""
    search_actions(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Search resolved action records by ID, title, description, category, keywords,
scope, or shortcut labels.
"""
function search_actions(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
)
    prepared_query = _action_search_query(query)
    return [
        record for record in action_records(
            registry,
            context;
            include_hidden=include_hidden,
            include_disabled=include_disabled,
        )
        if _action_record_query_matches(record, prepared_query)
    ]
end

"""
    search_action_count(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true)

Return the number of resolved action records matching `query`.
"""
search_action_count(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
) = length(search_actions(registry, query, context; include_hidden, include_disabled))

"""
    action_records_markdown(registry, context=ActionContext(); include_hidden=false, include_disabled=true, columns=...)

Render resolved action records as a GitHub-flavored Markdown table.
"""
function action_records_markdown(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    columns=(:id, :title, :category, :enabled, :bindings),
)
    selected = _action_record_columns(columns)
    return _action_records_markdown(
        action_records(registry, context; include_hidden, include_disabled),
        selected,
    )
end

"""
    action_records_tsv(registry, context=ActionContext(); include_hidden=false, include_disabled=true, columns=..., header=true)

Render resolved action records as tab-separated values.
"""
function action_records_tsv(
    registry::ActionRegistry,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    columns=(:id, :title, :category, :enabled, :bindings),
    header::Bool=true,
)
    selected = _action_record_columns(columns)
    return _action_records_tsv(
        action_records(registry, context; include_hidden, include_disabled),
        selected;
        header,
    )
end

"""
    search_action_records_markdown(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true, columns=...)

Search resolved action records and render the matches as Markdown.
"""
function search_action_records_markdown(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    columns=(:id, :title, :category, :enabled, :bindings),
)
    selected = _action_record_columns(columns)
    return _action_records_markdown(
        search_actions(registry, query, context; include_hidden, include_disabled),
        selected,
    )
end

"""
    search_action_records_tsv(registry, query, context=ActionContext(); include_hidden=false, include_disabled=true, columns=..., header=true)

Search resolved action records and render the matches as TSV.
"""
function search_action_records_tsv(
    registry::ActionRegistry,
    query,
    context::ActionContext=ActionContext();
    include_hidden::Bool=false,
    include_disabled::Bool=true,
    columns=(:id, :title, :category, :enabled, :bindings),
    header::Bool=true,
)
    selected = _action_record_columns(columns)
    return _action_records_tsv(
        search_actions(registry, query, context; include_hidden, include_disabled),
        selected;
        header,
    )
end

action_errors(registry::ActionRegistry) = lock(registry.mutex) do
    copy(registry.errors)
end

function _action_error_record(captured::CapturedException, index::Integer)
    exception = captured.ex
    return (
        index=Int(index),
        type=Symbol(nameof(typeof(exception))),
        message=sprint(showerror, exception),
    )
end

"""
    action_error_records(registry)

Return captured action predicate and handler failures as plain named tuples.
"""
function action_error_records(registry::ActionRegistry)
    return [
        _action_error_record(captured, index)
        for (index, captured) in enumerate(action_errors(registry))
    ]
end

"""
    action_error_summary(registry)

Return compact counts for captured action predicate and handler failures.
"""
function action_error_summary(registry::ActionRegistry)
    records = action_error_records(registry)
    by_type = Dict{Symbol,Int}()
    for record in records
        by_type[record.type] = get(by_type, record.type, 0) + 1
    end
    return (total=length(records), by_type=by_type)
end

function _action_error_column(value)
    value isa Symbol && return value
    value isa AbstractString && return Symbol(value)
    throw(ArgumentError("action error columns must be Symbols or Strings"))
end

function _action_error_columns(columns)
    selected = if columns isa Symbol || columns isa AbstractString
        Symbol[_action_error_column(columns)]
    else
        try
            Symbol[_action_error_column(column) for column in columns]
        catch error
            error isa MethodError &&
                throw(ArgumentError("action error columns must be a Symbol, String, or iterable collection of Symbols or Strings"))
            rethrow()
        end
    end
    isempty(selected) && throw(ArgumentError("action error records require at least one column"))
    for column in selected
        column in (:index, :type, :message) ||
            throw(ArgumentError("action error column must be one of :index, :type, or :message"))
    end
    return selected
end

function _action_error_field(record, column::Symbol)
    column === :index && return string(record.index)
    column === :type && return String(record.type)
    column === :message && return record.message
    throw(ArgumentError("action error column must be one of :index, :type, or :message"))
end

"""
    action_error_records_markdown(registry; columns=(:index, :type, :message))

Render captured action failures as a GitHub-flavored Markdown table.
"""
function action_error_records_markdown(
    registry::ActionRegistry;
    columns=(:index, :type, :message),
)
    selected = _action_error_columns(columns)
    rows = String["| $(join(("`$(String(column))`" for column in selected), " | ")) |",
                  "| $(join(fill("---", length(selected)), " | ")) |"]
    for record in action_error_records(registry)
        row = join((_escape_action_markdown(_action_error_field(record, column)) for column in selected), " | ")
        push!(rows, "| $row |")
    end
    return join(rows, "\n")
end

"""
    action_error_records_tsv(registry; columns=(:index, :type, :message), header=true)

Render captured action failures as tab-separated values.
"""
function action_error_records_tsv(
    registry::ActionRegistry;
    columns=(:index, :type, :message),
    header::Bool=true,
)
    selected = _action_error_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in action_error_records(registry)
        push!(rows, join((_escape_action_tsv(_action_error_field(record, column)) for column in selected), "\t"))
    end
    return join(rows, "\n")
end

"""
    action_error_text(registry; newline="\n")

Render captured action failures as compact human-readable text.
"""
function action_error_text(
    registry::ActionRegistry;
    newline::AbstractString="\n",
)
    records = action_error_records(registry)
    isempty(records) && return "No action errors"
    lines = String["Action errors ($(length(records)))"]
    for record in records
        push!(lines, "$(record.index). $(record.type): $(record.message)")
    end
    return join(lines, newline)
end

_action_error_search_query(query) = lowercase(strip(string(query)))

function _action_error_search_text(record)
    return lowercase(join((string(record.index), String(record.type), record.message), " "))
end

"""
    search_action_error_records(registry, query)

Return captured action failure records whose index, exception type, or message
contains `query`.
"""
function search_action_error_records(registry::ActionRegistry, query)
    needle = _action_error_search_query(query)
    records = action_error_records(registry)
    isempty(needle) && return records
    return [record for record in records if occursin(needle, _action_error_search_text(record))]
end

"""
    search_action_error_count(registry, query)

Count captured action failures matching `query`.
"""
search_action_error_count(registry::ActionRegistry, query) =
    length(search_action_error_records(registry, query))

"""
    search_action_error_records_markdown(registry, query; columns=(:index, :type, :message))

Render matching captured action failures as a GitHub-flavored Markdown table.
"""
function search_action_error_records_markdown(
    registry::ActionRegistry,
    query;
    columns=(:index, :type, :message),
)
    selected = _action_error_columns(columns)
    rows = String["| $(join(("`$(String(column))`" for column in selected), " | ")) |",
                  "| $(join(fill("---", length(selected)), " | ")) |"]
    for record in search_action_error_records(registry, query)
        row = join((_escape_action_markdown(_action_error_field(record, column)) for column in selected), " | ")
        push!(rows, "| $row |")
    end
    return join(rows, "\n")
end

"""
    search_action_error_records_tsv(registry, query; columns=(:index, :type, :message), header=true)

Render matching captured action failures as tab-separated values.
"""
function search_action_error_records_tsv(
    registry::ActionRegistry,
    query;
    columns=(:index, :type, :message),
    header::Bool=true,
)
    selected = _action_error_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in search_action_error_records(registry, query)
        push!(rows, join((_escape_action_tsv(_action_error_field(record, column)) for column in selected), "\t"))
    end
    return join(rows, "\n")
end

"""
    search_action_error_text(registry, query; newline="\n")

Render matching captured action failures as compact human-readable text.
"""
function search_action_error_text(
    registry::ActionRegistry,
    query;
    newline::AbstractString="\n",
)
    records = search_action_error_records(registry, query)
    isempty(records) && return "No matching action errors"
    lines = String["Action errors ($(length(records))) matching \"$(string(query))\""]
    for record in records
        push!(lines, "$(record.index). $(record.type): $(record.message)")
    end
    return join(lines, newline)
end

"""
    action_error_summary_records(registry)

Return one record per captured action-failure exception type.
"""
function action_error_summary_records(registry::ActionRegistry)
    summary = action_error_summary(registry)
    types = sort(collect(keys(summary.by_type)); by=string)
    return [(type=type, count=summary.by_type[type]) for type in types]
end

function _action_error_summary_columns(columns)
    selected = Tuple(Symbol(column) for column in columns)
    isempty(selected) && throw(ArgumentError("action error summary columns cannot be empty"))
    allowed = Set([:type, :count])
    for column in selected
        column in allowed ||
            throw(ArgumentError("action error summary column must be one of :type or :count"))
    end
    return selected
end

function _action_error_summary_field(record, column::Symbol)
    column === :type && return String(record.type)
    column === :count && return string(record.count)
    throw(ArgumentError("action error summary column must be one of :type or :count"))
end

"""
    action_error_summary_markdown(registry; columns=(:type, :count))

Render captured action-failure counts by exception type as Markdown.
"""
function action_error_summary_markdown(
    registry::ActionRegistry;
    columns=(:type, :count),
)
    selected = _action_error_summary_columns(columns)
    rows = String["| $(join(("`$(String(column))`" for column in selected), " | ")) |",
                  "| $(join(fill("---", length(selected)), " | ")) |"]
    for record in action_error_summary_records(registry)
        row = join(
            (_escape_action_markdown(_action_error_summary_field(record, column)) for column in selected),
            " | ",
        )
        push!(rows, "| $row |")
    end
    return join(rows, "\n")
end

"""
    action_error_summary_tsv(registry; columns=(:type, :count), header=true)

Render captured action-failure counts by exception type as tab-separated values.
"""
function action_error_summary_tsv(
    registry::ActionRegistry;
    columns=(:type, :count),
    header::Bool=true,
)
    selected = _action_error_summary_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in action_error_summary_records(registry)
        push!(
            rows,
            join(
                (_escape_action_tsv(_action_error_summary_field(record, column)) for column in selected),
                "\t",
            ),
        )
    end
    return join(rows, "\n")
end

"""
    action_error_summary_text(registry; newline="\n")

Render captured action-failure counts by exception type as compact text.
"""
function action_error_summary_text(
    registry::ActionRegistry;
    newline::AbstractString="\n",
)
    summary = action_error_summary(registry)
    summary.total == 0 && return "No action errors"
    lines = String["Action errors ($(summary.total))"]
    for record in action_error_summary_records(registry)
        push!(lines, "$(record.type): $(record.count)")
    end
    return join(lines, newline)
end

function _action_error_summary_search_text(record)
    return lowercase(join((String(record.type), string(record.count)), " "))
end

"""
    search_action_error_summary_records(registry, query)

Return action-failure summary records whose exception type or count contains
`query`.
"""
function search_action_error_summary_records(registry::ActionRegistry, query)
    needle = _action_error_search_query(query)
    records = action_error_summary_records(registry)
    isempty(needle) && return records
    return [
        record
        for record in records
        if occursin(needle, _action_error_summary_search_text(record))
    ]
end

"""
    search_action_error_summary_count(registry, query)

Count action-failure summary records matching `query`.
"""
search_action_error_summary_count(registry::ActionRegistry, query) =
    length(search_action_error_summary_records(registry, query))

"""
    search_action_error_summary_markdown(registry, query; columns=(:type, :count))

Render matching action-failure summary records as Markdown.
"""
function search_action_error_summary_markdown(
    registry::ActionRegistry,
    query;
    columns=(:type, :count),
)
    selected = _action_error_summary_columns(columns)
    rows = String["| $(join(("`$(String(column))`" for column in selected), " | ")) |",
                  "| $(join(fill("---", length(selected)), " | ")) |"]
    for record in search_action_error_summary_records(registry, query)
        row = join(
            (_escape_action_markdown(_action_error_summary_field(record, column)) for column in selected),
            " | ",
        )
        push!(rows, "| $row |")
    end
    return join(rows, "\n")
end

"""
    search_action_error_summary_tsv(registry, query; columns=(:type, :count), header=true)

Render matching action-failure summary records as tab-separated values.
"""
function search_action_error_summary_tsv(
    registry::ActionRegistry,
    query;
    columns=(:type, :count),
    header::Bool=true,
)
    selected = _action_error_summary_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for record in search_action_error_summary_records(registry, query)
        push!(
            rows,
            join(
                (_escape_action_tsv(_action_error_summary_field(record, column)) for column in selected),
                "\t",
            ),
        )
    end
    return join(rows, "\n")
end

"""
    search_action_error_summary_text(registry, query; newline="\n")

Render matching action-failure summary records as compact text.
"""
function search_action_error_summary_text(
    registry::ActionRegistry,
    query;
    newline::AbstractString="\n",
)
    records = search_action_error_summary_records(registry, query)
    isempty(records) && return "No matching action error summary"
    total = sum(record.count for record in records)
    lines = String["Action errors ($(total)) matching \"$(string(query))\""]
    for record in records
        push!(lines, "$(record.type): $(record.count)")
    end
    return join(lines, newline)
end

function take_action_errors!(registry::ActionRegistry)
    return lock(registry.mutex) do
        errors = copy(registry.errors)
        empty!(registry.errors)
        errors
    end
end
