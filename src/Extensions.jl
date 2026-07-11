module Extensions

export ExtensionContributionKind,
       WidgetContribution,
       ThemeContribution,
       SyntaxContribution,
       BackendContribution,
       CommandContribution,
       InspectorContribution,
       ServiceContribution,
       ExtensionState,
       ExtensionRegistered,
       ExtensionActivating,
       ExtensionActive,
       ExtensionDeactivating,
       ExtensionFailed,
       ExtensionDependency,
       ExtensionDescriptor,
       ExtensionPolicy,
       ExtensionContribution,
       ExtensionError,
       ExtensionContext,
       ExtensionRegistry,
       register_extension!,
       unregister_extension!,
       resolve_extensions,
       activate_extension!,
       activate_extensions!,
       deactivate_extension!,
       deactivate_extensions!,
       contribute_extension!,
       remove_extension_contributions!,
       extension_contribution,
       extension_contributions,
       extension_service,
       set_extension_service!,
       extension_state,
       extension_snapshot,
       with_extensions

@enum ExtensionContributionKind begin
    WidgetContribution
    ThemeContribution
    SyntaxContribution
    BackendContribution
    CommandContribution
    InspectorContribution
    ServiceContribution
end

@enum ExtensionState begin
    ExtensionRegistered
    ExtensionActivating
    ExtensionActive
    ExtensionDeactivating
    ExtensionFailed
end

function _extension_identifier(value; label::AbstractString="extension name", maximum_bytes::Int=128)
    value isa Union{Symbol,AbstractString} ||
        throw(ArgumentError("$label must be a Symbol or string"))
    text = String(value)
    isvalid(text) || throw(ArgumentError("$label must be valid UTF-8"))
    1 <= ncodeunits(text) <= maximum_bytes ||
        throw(ArgumentError("$label must contain between 1 and $maximum_bytes bytes"))
    occursin(r"^[A-Za-z][A-Za-z0-9_.-]*$", text) ||
        throw(ArgumentError("$label contains unsupported characters"))
    return Symbol(text)
end

function _extension_key(value; label::AbstractString="extension key", maximum_bytes::Int=128)
    value isa Union{Symbol,AbstractString} ||
        throw(ArgumentError("$label must be a Symbol or string"))
    text = String(value)
    isvalid(text) || throw(ArgumentError("$label must be valid UTF-8"))
    1 <= ncodeunits(text) <= maximum_bytes ||
        throw(ArgumentError("$label must contain between 1 and $maximum_bytes bytes"))
    occursin(r"^[A-Za-z][A-Za-z0-9_.:/-]*$", text) ||
        throw(ArgumentError("$label contains unsupported characters"))
    return Symbol(text)
end

struct ExtensionDependency
    name::Symbol
    minimum::VersionNumber
    maximum_exclusive::Union{Nothing,VersionNumber}
    optional::Bool

    function ExtensionDependency(
        name;
        minimum::VersionNumber=v"0.0.0",
        maximum_exclusive::Union{Nothing,VersionNumber}=nothing,
        optional::Bool=false,
    )
        maximum_exclusive !== nothing && maximum_exclusive <= minimum &&
            throw(ArgumentError("extension dependency maximum must exceed minimum"))
        new(_extension_identifier(name; label="extension dependency name"), minimum, maximum_exclusive, optional)
    end
end

struct ExtensionDescriptor{I,S}
    name::Symbol
    version::VersionNumber
    description::String
    dependencies::Vector{ExtensionDependency}
    initialize::I
    shutdown::S

    function ExtensionDescriptor(
        name,
        version::VersionNumber;
        description::AbstractString="",
        dependencies=ExtensionDependency[],
        initialize=context -> nothing,
        shutdown=context -> nothing,
    )
        identifier = _extension_identifier(name)
        description_value = String(description)
        isvalid(description_value) || throw(ArgumentError("extension description must be valid UTF-8"))
        ncodeunits(description_value) <= 16_384 ||
            throw(ArgumentError("extension description exceeds 16384 bytes"))
        any(iscntrl, description_value) &&
            throw(ArgumentError("extension description cannot contain control characters"))
        resolved_dependencies = ExtensionDependency[dependency for dependency in dependencies]
        length(resolved_dependencies) <= 256 ||
            throw(ArgumentError("extension descriptor has too many dependencies"))
        dependency_names = getfield.(resolved_dependencies, :name)
        length(unique(dependency_names)) == length(dependency_names) ||
            throw(ArgumentError("extension descriptor contains duplicate dependencies"))
        new{typeof(initialize),typeof(shutdown)}(
            identifier,
            version,
            description_value,
            resolved_dependencies,
            initialize,
            shutdown,
        )
    end
end

struct ExtensionPolicy
    maximum_extensions::Int
    maximum_contributions_per_extension::Int
    maximum_services::Int
    maximum_description_bytes::Int
    maximum_dependencies::Int

    function ExtensionPolicy(;
        maximum_extensions::Integer=1_024,
        maximum_contributions_per_extension::Integer=1_024,
        maximum_services::Integer=1_024,
        maximum_description_bytes::Integer=4_096,
        maximum_dependencies::Integer=128,
    )
        values = (
            maximum_extensions,
            maximum_contributions_per_extension,
            maximum_services,
            maximum_description_bytes,
            maximum_dependencies,
        )
        all(value -> 0 <= value <= typemax(Int), values) ||
            throw(ArgumentError("extension policy limits must be nonnegative Int values"))
        new(Int.(values)...)
    end
end

struct ExtensionContribution
    kind::ExtensionContributionKind
    key::Symbol
    value::Any
    owner::Symbol
end

struct ExtensionError <: Exception
    operation::Symbol
    extension::Union{Nothing,Symbol}
    message::String
    cause::Any
end

ExtensionError(operation::Symbol, extension, message::AbstractString; cause=nothing) =
    ExtensionError(
        operation,
        extension === nothing ? nothing : _extension_identifier(extension),
        String(message),
        cause,
    )

function Base.showerror(io::IO, error::ExtensionError)
    print(io, "extension ", error.operation, " failed")
    error.extension === nothing || print(io, " for ", error.extension)
    print(io, ": ", error.message)
    error.cause === nothing || print(io, " (", repr(error.cause), ")")
end

mutable struct ExtensionRegistry
    descriptors::Dict{Symbol,ExtensionDescriptor}
    states::Dict{Symbol,ExtensionState}
    failures::Dict{Symbol,Any}
    contributions::Dict{Tuple{ExtensionContributionKind,Symbol},ExtensionContribution}
    activation_order::Vector{Symbol}
    services::Dict{Symbol,Any}
    policy::ExtensionPolicy
    mutex::ReentrantLock
end

function ExtensionRegistry(;
    services=Dict{Symbol,Any}(),
    policy::ExtensionPolicy=ExtensionPolicy(),
)
    length(services) <= policy.maximum_services ||
        throw(ArgumentError("initial extension services exceed the configured limit"))
    resolved_services = Dict{Symbol,Any}(
        _extension_key(key; label="extension service key") => value for (key, value) in pairs(services)
    )
    return ExtensionRegistry(
        Dict{Symbol,ExtensionDescriptor}(),
        Dict{Symbol,ExtensionState}(),
        Dict{Symbol,Any}(),
        Dict{Tuple{ExtensionContributionKind,Symbol},ExtensionContribution}(),
        Symbol[],
        resolved_services,
        policy,
        ReentrantLock(),
    )
end

struct ExtensionContext
    registry::ExtensionRegistry
    extension::Symbol
end

function register_extension!(registry::ExtensionRegistry, descriptor::ExtensionDescriptor)
    lock(registry.mutex) do
        haskey(registry.descriptors, descriptor.name) &&
            throw(ExtensionError(:register, descriptor.name, "extension is already registered"))
        length(registry.descriptors) < registry.policy.maximum_extensions ||
            throw(ExtensionError(:register, descriptor.name, "extension registry limit was reached"))
        ncodeunits(descriptor.description) <= registry.policy.maximum_description_bytes ||
            throw(ExtensionError(:register, descriptor.name, "extension description exceeds the registry policy"))
        length(descriptor.dependencies) <= registry.policy.maximum_dependencies ||
            throw(ExtensionError(:register, descriptor.name, "extension dependencies exceed the registry policy"))
        registry.descriptors[descriptor.name] = descriptor
        registry.states[descriptor.name] = ExtensionRegistered
        pop!(registry.failures, descriptor.name, nothing)
    end
    return registry
end

function unregister_extension!(registry::ExtensionRegistry, name)
    identifier = _extension_identifier(name)
    lock(registry.mutex) do
        state = get(registry.states, identifier, nothing)
        state === nothing && return false
        state in (ExtensionActive, ExtensionActivating, ExtensionDeactivating) &&
            throw(ExtensionError(:unregister, identifier, "active or transitional extension cannot be unregistered"))
        delete!(registry.descriptors, identifier)
        delete!(registry.states, identifier)
        delete!(registry.failures, identifier)
        filter!(!=(identifier), registry.activation_order)
        remove_extension_contributions!(registry, identifier)
        return true
    end
end

function _dependency_satisfied(dependency::ExtensionDependency, version::VersionNumber)
    version >= dependency.minimum || return false
    dependency.maximum_exclusive === nothing && return true
    return version < dependency.maximum_exclusive
end

function resolve_extensions(registry::ExtensionRegistry, requested=collect(keys(registry.descriptors)))
    return lock(registry.mutex) do
        order = Symbol[]
        permanent = Set{Symbol}()
        temporary = Symbol[]

        function visit(name::Symbol)
            name in permanent && return
            if name in temporary
                start = findfirst(==(name), temporary)
                cycle = vcat(temporary[start:end], name)
                throw(ExtensionError(:resolve, name, "dependency cycle: $(join(cycle, " -> "))"))
            end
            descriptor = get(registry.descriptors, name, nothing)
            descriptor === nothing &&
                throw(ExtensionError(:resolve, name, "extension is not registered"))
            push!(temporary, name)
            dependencies = sort(copy(descriptor.dependencies); by=dependency -> string(dependency.name))
            for dependency in dependencies
                target = get(registry.descriptors, dependency.name, nothing)
                if target === nothing
                    dependency.optional && continue
                    throw(ExtensionError(:resolve, name, "missing dependency $(dependency.name)"))
                end
                if !_dependency_satisfied(dependency, target.version)
                    dependency.optional && continue
                    throw(ExtensionError(
                        :resolve,
                        name,
                        "dependency $(dependency.name) has incompatible version $(target.version)",
                    ))
                end
                visit(dependency.name)
            end
            pop!(temporary)
            push!(permanent, name)
            push!(order, name)
        end

        for name in sort!(Symbol[_extension_identifier(value) for value in requested]; by=string)
            visit(name)
        end
        return order
    end
end

function contribute_extension!(
    context::ExtensionContext,
    kind::ExtensionContributionKind,
    key,
    value;
    replace::Bool=false,
)
    identifier = _extension_key(key; label="extension contribution key")
    registry = context.registry
    lock(registry.mutex) do
        get(registry.states, context.extension, nothing) in (ExtensionActivating, ExtensionActive) ||
            throw(ExtensionError(:contribute, context.extension, "extension is not active or activating"))
        contribution_key = (kind, identifier)
        existing = get(registry.contributions, contribution_key, nothing)
        if existing !== nothing && !(replace && existing.owner == context.extension)
            throw(ExtensionError(:contribute, context.extension, "contribution $kind/$identifier already belongs to $(existing.owner)"))
        end
        if existing === nothing
            owned = count(contribution -> contribution.owner == context.extension, values(registry.contributions))
            owned < registry.policy.maximum_contributions_per_extension ||
                throw(ExtensionError(:contribute, context.extension, "extension contribution limit was reached"))
        end
        contribution = ExtensionContribution(kind, identifier, value, context.extension)
        registry.contributions[contribution_key] = contribution
        return contribution
    end
end

function remove_extension_contributions!(registry::ExtensionRegistry, owner)
    identifier = _extension_identifier(owner)
    lock(registry.mutex) do
        for (key, contribution) in collect(registry.contributions)
            contribution.owner == identifier && delete!(registry.contributions, key)
        end
    end
    return registry
end

function _activate_one!(registry::ExtensionRegistry, name::Symbol)
    descriptor = lock(registry.mutex) do
        state = get(registry.states, name, nothing)
        state === nothing && throw(ExtensionError(:activate, name, "extension is not registered"))
        state == ExtensionActive && return nothing
        state in (ExtensionActivating, ExtensionDeactivating) &&
            throw(ExtensionError(:activate, name, "extension is in a transitional state"))
        registry.states[name] = ExtensionActivating
        registry.descriptors[name]
    end
    descriptor === nothing && return false
    context = ExtensionContext(registry, name)
    initialization_started = false
    try
        applicable(descriptor.initialize, context) ||
            throw(ExtensionError(:activate, name, "initialize callback is not applicable to ExtensionContext"))
        initialization_started = true
        descriptor.initialize(context)
        lock(registry.mutex) do
            registry.states[name] = ExtensionActive
            name in registry.activation_order || push!(registry.activation_order, name)
            pop!(registry.failures, name, nothing)
        end
        return true
    catch error
        cleanup_failure = nothing
        if initialization_started && applicable(descriptor.shutdown, context)
            try
                descriptor.shutdown(context)
            catch shutdown_error
                cleanup_failure = (shutdown_error, catch_backtrace())
            end
        end
        remove_extension_contributions!(registry, name)
        lock(registry.mutex) do
            registry.states[name] = ExtensionFailed
            registry.failures[name] = (error, catch_backtrace(), cleanup_failure)
            filter!(!=(name), registry.activation_order)
        end
        error isa ExtensionError && rethrow()
        throw(ExtensionError(:activate, name, "initialize callback failed"; cause=error))
    end
end

function activate_extension!(registry::ExtensionRegistry, name)
    order = resolve_extensions(registry, [_extension_identifier(name)])
    activated = Symbol[]
    try
        for identifier in order
            _activate_one!(registry, identifier) && push!(activated, identifier)
        end
    catch
        for identifier in reverse(activated)
            try
                deactivate_extension!(registry, identifier; cascade=false)
            catch
            end
        end
        rethrow()
    end
    return activated
end

function activate_extensions!(registry::ExtensionRegistry, requested=collect(keys(registry.descriptors)))
    order = resolve_extensions(registry, requested)
    activated = Symbol[]
    try
        for identifier in order
            _activate_one!(registry, identifier) && push!(activated, identifier)
        end
    catch
        for identifier in reverse(activated)
            try
                deactivate_extension!(registry, identifier; cascade=false)
            catch
            end
        end
        rethrow()
    end
    return activated
end

function _active_dependents(registry::ExtensionRegistry, name::Symbol)
    return Symbol[
        descriptor.name for descriptor in values(registry.descriptors)
        if get(registry.states, descriptor.name, nothing) == ExtensionActive &&
           any(dependency -> dependency.name == name, descriptor.dependencies)
    ]
end

function deactivate_extension!(registry::ExtensionRegistry, name; cascade::Bool=false)
    identifier = _extension_identifier(name)
    dependents = lock(registry.mutex) do
        _active_dependents(registry, identifier)
    end
    if !isempty(dependents)
        cascade || throw(ExtensionError(:deactivate, identifier, "active dependents: $(join(dependents, ", "))"))
        for dependent in reverse(dependents)
            deactivate_extension!(registry, dependent; cascade=true)
        end
    end
    descriptor = lock(registry.mutex) do
        state = get(registry.states, identifier, nothing)
        state === nothing && return nothing
        state == ExtensionActive || return nothing
        registry.states[identifier] = ExtensionDeactivating
        registry.descriptors[identifier]
    end
    descriptor === nothing && return false
    context = ExtensionContext(registry, identifier)
    failure = nothing
    try
        applicable(descriptor.shutdown, context) ||
            throw(ExtensionError(:deactivate, identifier, "shutdown callback is not applicable to ExtensionContext"))
        descriptor.shutdown(context)
    catch error
        failure = (error, catch_backtrace())
    end
    remove_extension_contributions!(registry, identifier)
    lock(registry.mutex) do
        filter!(!=(identifier), registry.activation_order)
        if failure === nothing
            registry.states[identifier] = ExtensionRegistered
            pop!(registry.failures, identifier, nothing)
        else
            registry.states[identifier] = ExtensionFailed
            registry.failures[identifier] = failure
        end
    end
    if failure !== nothing
        error = failure[1]
        error isa ExtensionError && throw(error)
        throw(ExtensionError(:deactivate, identifier, "shutdown callback failed"; cause=error))
    end
    return true
end

function deactivate_extensions!(registry::ExtensionRegistry)
    order = lock(registry.mutex) do
        reverse(copy(registry.activation_order))
    end
    deactivated = Symbol[]
    for identifier in order
        deactivate_extension!(registry, identifier; cascade=false) && push!(deactivated, identifier)
    end
    return deactivated
end

function extension_contribution(
    registry::ExtensionRegistry,
    kind::ExtensionContributionKind,
    key,
)
    return lock(registry.mutex) do
        identifier = _extension_key(key; label="extension contribution key")
        get(registry.contributions, (kind, identifier), nothing)
    end
end

function extension_contributions(
    registry::ExtensionRegistry;
    kind::Union{Nothing,ExtensionContributionKind}=nothing,
    owner=nothing,
)
    owner_id = owner === nothing ? nothing : _extension_identifier(owner)
    return lock(registry.mutex) do
        sort!(
            ExtensionContribution[
                contribution for contribution in values(registry.contributions)
                if (kind === nothing || contribution.kind == kind) &&
                   (owner_id === nothing || contribution.owner == owner_id)
            ];
            by=contribution -> (Int(contribution.kind), string(contribution.key)),
        )
    end
end

function set_extension_service!(registry::ExtensionRegistry, key, value; replace::Bool=false)
    identifier = _extension_key(key; label="extension service key")
    lock(registry.mutex) do
        haskey(registry.services, identifier) && !replace &&
            throw(ExtensionError(:service, nothing, "service $identifier already exists"))
        !haskey(registry.services, identifier) && length(registry.services) >= registry.policy.maximum_services &&
            throw(ExtensionError(:service, nothing, "extension service limit was reached"))
        registry.services[identifier] = value
    end
    return registry
end

extension_service(registry::ExtensionRegistry, key, default=nothing) = lock(registry.mutex) do
    get(registry.services, _extension_key(key; label="extension service key"), default)
end

extension_state(registry::ExtensionRegistry, name) = lock(registry.mutex) do
    get(registry.states, _extension_identifier(name), nothing)
end

function extension_snapshot(registry::ExtensionRegistry)
    return lock(registry.mutex) do
        lines = String[]
        for name in sort!(collect(keys(registry.descriptors)); by=string)
            descriptor = registry.descriptors[name]
            state = registry.states[name]
            push!(lines, "$name $(descriptor.version) $state")
            for contribution in extension_contributions(registry; owner=name)
                push!(lines, "  $(contribution.kind)/$(contribution.key)")
            end
        end
        return join(lines, '\n')
    end
end

function with_extensions(
    operation::F,
    registry::ExtensionRegistry,
    requested=collect(keys(registry.descriptors)),
) where {F}
    activated = activate_extensions!(registry, requested)
    try
        return operation(registry)
    finally
        for identifier in reverse(activated)
            deactivate_extension!(registry, identifier; cascade=false)
        end
    end
end

end
