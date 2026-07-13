using Wicked.API

events = String[]
registry = ExtensionRegistry(services=Dict(:events => events))

base = ExtensionDescriptor(
    :base,
    v"1.0.0";
    description="Base theme contribution",
    initialize=context -> begin
        push!(extension_service(context.registry, :events), "base:init")
        contribute_extension!(context, ThemeContribution, :theme, :paper)
    end,
    shutdown=context -> push!(extension_service(context.registry, :events), "base:shutdown"),
)

feature = ExtensionDescriptor(
    :feature,
    v"1.0.0";
    description="Feature command contribution",
    dependencies=[ExtensionDependency(:base; minimum=v"1.0.0")],
    initialize=context -> begin
        push!(extension_service(context.registry, :events), "feature:init")
        contribute_extension!(context, CommandContribution, :command, :deploy)
        contribute_extension!(context, ServiceContribution, :service, (; name=:deployments))
    end,
    shutdown=context -> push!(extension_service(context.registry, :events), "feature:shutdown"),
)

register_extension!(registry, base)
register_extension!(registry, feature)

activated = activate_extension!(registry, :feature)
@assert activated == [:base, :feature]
@assert extension_state(registry, :base) == ExtensionActive
@assert extension_state(registry, :feature) == ExtensionActive
@assert extension_contribution(registry, ThemeContribution, :theme).value == :paper
@assert extension_contribution(registry, CommandContribution, :command).value == :deploy
@assert extension_contribution(registry, ServiceContribution, :service).value.name == :deployments

snapshot = extension_snapshot(registry)
@assert occursin("base", snapshot)
@assert occursin("feature", snapshot)
@assert occursin("ThemeContribution/theme", snapshot)
@assert occursin("CommandContribution/command", snapshot)

@assert deactivate_extension!(registry, :feature) === true
@assert extension_contribution(registry, CommandContribution, :command) === nothing
@assert deactivate_extension!(registry, :base) === true
@assert extension_contribution(registry, ThemeContribution, :theme) === nothing
@assert events == ["base:init", "feature:init", "feature:shutdown", "base:shutdown"]

scoped = ExtensionRegistry()
register_extension!(
    scoped,
    ExtensionDescriptor(
        :scoped,
        v"1.0.0";
        initialize=context -> contribute_extension!(context, WidgetContribution, :preview, Label("Preview")),
    ),
)

scoped_value = with_extensions(scoped, [:scoped]) do active_registry
    contribution = extension_contribution(active_registry, WidgetContribution, :preview)
    @assert contribution.value isa Label
    extension_state(active_registry, :scoped)
end

@assert scoped_value == ExtensionActive
@assert extension_contribution(scoped, WidgetContribution, :preview) === nothing

println("extensions quickstart example completed")
