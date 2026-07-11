using .Core: Style
using .Styles: DEFAULT_THEME, StyleEngine, Theme, set_theme!


@enum ThemeVariant::UInt8 begin
    LightTheme
    DarkTheme
    HighContrastTheme
end

@enum ThemeChangeReason::UInt8 begin
    ThemeSelected
    ActiveThemeReplaced
    ActiveThemeRemoved
    ThemePreferenceChanged
end

function _copy_managed_theme(theme::Theme)
    return Theme(theme.name; roles=copy(theme.roles))
end

struct ThemeDescriptor
    id::Symbol
    display_name::String
    variant::ThemeVariant
    theme::Theme
    priority::Int
    metadata::Dict{Symbol,Any}

    function ThemeDescriptor(
        id::Symbol,
        display_name::String,
        variant::ThemeVariant,
        theme::Theme,
        priority::Int,
        metadata::Dict{Symbol,Any},
    )
        return new(
            id,
            display_name,
            variant,
            _copy_managed_theme(theme),
            priority,
            copy(metadata),
        )
    end
end

function ThemeDescriptor(
    id::Symbol,
    theme::Theme;
    display_name::AbstractString=string(id),
    variant::ThemeVariant=DarkTheme,
    priority::Integer=0,
    metadata=Dict{Symbol,Any}(),
)
    return ThemeDescriptor(
        id,
        String(display_name),
        variant,
        theme,
        Int(priority),
        Dict{Symbol,Any}(Symbol(key) => value for (key, value) in metadata),
    )
end

function _copy_theme_descriptor(descriptor::ThemeDescriptor)
    return ThemeDescriptor(
        descriptor.id,
        descriptor.display_name,
        descriptor.variant,
        descriptor.theme,
        descriptor.priority,
        descriptor.metadata,
    )
end

struct ThemeChangeEvent
    previous::ThemeDescriptor
    current::ThemeDescriptor
    reason::ThemeChangeReason
    generation::UInt64
end

struct ThemeSubscription
    id::UInt64
end

mutable struct ThemeRegistry
    themes::Dict{Symbol,ThemeDescriptor}
    active::Symbol
    preference::ThemeVariant
    subscribers::Dict{ThemeSubscription,Any}
    sequence::UInt64
    generation::UInt64
    errors::Vector{CapturedException}
    mutex::ReentrantLock
end

function ThemeRegistry(
    descriptors::AbstractVector{<:ThemeDescriptor}=ThemeDescriptor[
        ThemeDescriptor(:default, DEFAULT_THEME; display_name="Default", variant=DarkTheme),
    ];
    active=nothing,
    preference::ThemeVariant=DarkTheme,
)
    isempty(descriptors) && throw(ArgumentError("a theme registry requires at least one theme"))
    themes = Dict{Symbol,ThemeDescriptor}()
    for descriptor in descriptors
        haskey(themes, descriptor.id) &&
            throw(ArgumentError("duplicate theme ID: $(descriptor.id)"))
        themes[descriptor.id] = _copy_theme_descriptor(descriptor)
    end
    active_id = if active === nothing
        first(sort!(collect(keys(themes)); by=String))
    else
        Symbol(active)
    end
    haskey(themes, active_id) || throw(KeyError(active_id))
    return ThemeRegistry(
        themes,
        active_id,
        preference,
        Dict{ThemeSubscription,Any}(),
        UInt64(0),
        UInt64(0),
        CapturedException[],
        ReentrantLock(),
    )
end

function _next_theme_counter(value::UInt64, name::AbstractString)
    value == typemax(UInt64) && throw(OverflowError("$name exhausted"))
    return value + UInt64(1)
end

function derive_theme(
    base::Theme,
    name::Symbol;
    roles=Dict{Symbol,Style}(),
    remove=Symbol[],
)
    merged = copy(base.roles)
    for role in remove
        delete!(merged, Symbol(role))
    end
    for (role, style) in roles
        style isa Style || throw(ArgumentError("theme role values must be Style"))
        merged[Symbol(role)] = style
    end
    return Theme(name; roles=merged)
end

function validate_theme_roles(theme::Theme, required)
    missing = Symbol[Symbol(role) for role in required if !haskey(theme.roles, Symbol(role))]
    return isempty(missing), missing
end

function _preferred_theme_locked(registry::ThemeRegistry)
    exact = ThemeDescriptor[
        descriptor for descriptor in values(registry.themes)
        if descriptor.variant == registry.preference
    ]
    candidates = isempty(exact) ? collect(values(registry.themes)) : exact
    sort!(candidates; by=descriptor -> (-descriptor.priority, String(descriptor.id)))
    return first(candidates)
end

function _theme_event(previous, current, reason, generation)
    return ThemeChangeEvent(
        _copy_theme_descriptor(previous),
        _copy_theme_descriptor(current),
        reason,
        generation,
    )
end

function _capture_theme_error!(registry::ThemeRegistry, error, backtrace)
    captured = CapturedException(error, backtrace)
    lock(registry.mutex) do
        push!(registry.errors, captured)
    end
    return nothing
end

function _notify_theme_subscribers!(registry::ThemeRegistry, event::ThemeChangeEvent)
    subscribers = lock(registry.mutex) do
        sort!(collect(registry.subscribers); by=pair -> first(pair).id)
    end
    for (_, callback) in subscribers
        try
            callback(event)
        catch error
            _capture_theme_error!(registry, error, catch_backtrace())
        end
    end
    return event
end

function register_theme!(
    registry::ThemeRegistry,
    descriptor::ThemeDescriptor;
    replace::Bool=false,
)
    event = lock(registry.mutex) do
        existing = get(registry.themes, descriptor.id, nothing)
        existing !== nothing && !replace &&
            throw(ArgumentError("theme is already registered: $(descriptor.id)"))
        generation = _next_theme_counter(registry.generation, "theme registry generation")
        themes = copy(registry.themes)
        replacement = _copy_theme_descriptor(descriptor)
        themes[descriptor.id] = replacement
        registry.themes = themes
        registry.generation = generation
        existing !== nothing && registry.active == descriptor.id ?
            _theme_event(existing, replacement, ActiveThemeReplaced, generation) : nothing
    end
    event === nothing || _notify_theme_subscribers!(registry, event)
    return registry
end

function unregister_theme!(registry::ThemeRegistry, id::Symbol)
    removed, event = lock(registry.mutex) do
        existing = get(registry.themes, id, nothing)
        existing === nothing && return false, nothing
        length(registry.themes) == 1 &&
            throw(ArgumentError("cannot remove the last registered theme"))
        generation = _next_theme_counter(registry.generation, "theme registry generation")
        themes = copy(registry.themes)
        delete!(themes, id)
        registry.themes = themes
        event = if registry.active == id
            replacement = _preferred_theme_locked(registry)
            registry.active = replacement.id
            _theme_event(existing, replacement, ActiveThemeRemoved, generation)
        else
            nothing
        end
        registry.generation = generation
        return true, event
    end
    event === nothing || _notify_theme_subscribers!(registry, event)
    return removed
end

function set_active_theme!(registry::ThemeRegistry, id::Symbol)
    event = lock(registry.mutex) do
        current = registry.themes[registry.active]
        replacement = get(registry.themes, id, nothing)
        replacement === nothing && throw(KeyError(id))
        registry.active == id && return nothing
        generation = _next_theme_counter(registry.generation, "theme registry generation")
        registry.active = id
        registry.generation = generation
        _theme_event(current, replacement, ThemeSelected, generation)
    end
    event === nothing && return false
    _notify_theme_subscribers!(registry, event)
    return true
end

function set_theme_preference!(
    registry::ThemeRegistry,
    preference::ThemeVariant;
    activate::Bool=true,
)
    changed, event = lock(registry.mutex) do
        registry.preference == preference && !activate && return false, nothing
        current = registry.themes[registry.active]
        generation = _next_theme_counter(registry.generation, "theme registry generation")
        registry.preference = preference
        replacement = activate ? _preferred_theme_locked(registry) : current
        registry.active = replacement.id
        registry.generation = generation
        event = replacement.id == current.id ? nothing :
            _theme_event(current, replacement, ThemePreferenceChanged, generation)
        return true, event
    end
    event === nothing || _notify_theme_subscribers!(registry, event)
    return changed
end

active_theme_descriptor(registry::ThemeRegistry) = lock(registry.mutex) do
    _copy_theme_descriptor(registry.themes[registry.active])
end

active_theme(registry::ThemeRegistry) = active_theme_descriptor(registry).theme

available_themes(registry::ThemeRegistry) = lock(registry.mutex) do
    descriptors = [_copy_theme_descriptor(descriptor) for descriptor in values(registry.themes)]
    sort!(descriptors; by=descriptor -> (
        Int(descriptor.variant),
        -descriptor.priority,
        lowercase(descriptor.display_name),
        String(descriptor.id),
    ))
end

theme_generation(registry::ThemeRegistry) = lock(registry.mutex) do
    registry.generation
end

function subscribe_theme!(registry::ThemeRegistry, callback)
    current = active_theme_descriptor(registry)
    sample = ThemeChangeEvent(current, current, ThemeSelected, theme_generation(registry))
    applicable(callback, sample) ||
        throw(ArgumentError("theme subscriber must accept ThemeChangeEvent"))
    return lock(registry.mutex) do
        sequence = _next_theme_counter(registry.sequence, "theme subscription sequence")
        subscription = ThemeSubscription(sequence)
        subscribers = copy(registry.subscribers)
        subscribers[subscription] = callback
        registry.subscribers = subscribers
        registry.sequence = sequence
        return subscription
    end
end

subscribe_theme!(callback::Function, registry::ThemeRegistry) =
    subscribe_theme!(registry, callback)

function unsubscribe_theme!(registry::ThemeRegistry, subscription::ThemeSubscription)
    return lock(registry.mutex) do
        haskey(registry.subscribers, subscription) || return false
        subscribers = copy(registry.subscribers)
        delete!(subscribers, subscription)
        registry.subscribers = subscribers
        return true
    end
end

struct ThemeEngineBinding
    registry::ThemeRegistry
    subscription::ThemeSubscription
    active::Base.Threads.Atomic{Bool}
    mutex::ReentrantLock
end

function _synchronize_theme_engine!(
    registry::ThemeRegistry,
    engine::StyleEngine,
    active::Base.Threads.Atomic{Bool};
    max_attempts::Int=64,
)
    for _ in 1:max_attempts
        active[] || return false
        before = theme_generation(registry)
        theme = active_theme(registry)
        active[] || return false
        set_theme!(engine, theme)
        theme_generation(registry) == before && return true
    end
    throw(InvalidStateException(
        "theme registry changed continuously during style engine synchronization",
        :active,
    ))
end

function bind_theme_engine!(
    registry::ThemeRegistry,
    engine::StyleEngine;
    apply_initial::Bool=true,
)
    active = Base.Threads.Atomic{Bool}(true)
    synchronization = ReentrantLock()
    subscription = subscribe_theme!(registry) do _
        active[] || return nothing
        lock(synchronization) do
            active[] || return nothing
            _synchronize_theme_engine!(registry, engine, active)
        end
        return nothing
    end
    binding = ThemeEngineBinding(registry, subscription, active, synchronization)
    if apply_initial
        try
            lock(synchronization) do
                try
                    _synchronize_theme_engine!(registry, engine, active)
                catch
                    active[] = false
                    rethrow()
                end
            end
        catch
            unsubscribe_theme!(registry, subscription)
            rethrow()
        end
    end
    return binding
end

function unbind_theme_engine!(binding::ThemeEngineBinding)
    Base.Threads.atomic_cas!(binding.active, true, false) || return false
    lock(binding.mutex) do
        nothing
    end
    unsubscribe_theme!(binding.registry, binding.subscription)
    return true
end

theme_errors(registry::ThemeRegistry) = lock(registry.mutex) do
    copy(registry.errors)
end

function take_theme_errors!(registry::ThemeRegistry)
    return lock(registry.mutex) do
        errors = copy(registry.errors)
        empty!(registry.errors)
        errors
    end
end
