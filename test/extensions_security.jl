@testset "Extension registry adversarial lifecycle" begin
    @testset "identifiers and descriptor metadata are bounded" begin
        for name in ("", "1starts-with-digit", "bad name", "bad/control\n", repeat("a", 129))
            @test_throws ArgumentError ExtensionDescriptor(name, v"1.0.0")
        end
        @test_throws ArgumentError ExtensionDependency("bad dependency")
        @test_throws ArgumentError ExtensionDescriptor(
            :duplicate,
            v"1.0.0";
            dependencies=[ExtensionDependency(:base), ExtensionDependency(:base)],
        )
        @test_throws ArgumentError ExtensionDescriptor(
            :described,
            v"1.0.0";
            description="control\ntext",
        )
        @test_throws ArgumentError ExtensionPolicy(maximum_extensions=-1)
        @test_throws ArgumentError ExtensionRegistry(services=Dict("bad key" => 1))
        @test_throws ArgumentError extension_contribution(
            ExtensionRegistry(),
            WidgetContribution,
            "bad contribution key",
        )
    end

    @testset "policy limits registrations, contributions, and services" begin
        policy = ExtensionPolicy(
            maximum_extensions=1,
            maximum_contributions_per_extension=1,
            maximum_services=1,
            maximum_description_bytes=4,
            maximum_dependencies=0,
        )
        registry = ExtensionRegistry(policy=policy)
        descriptor = ExtensionDescriptor(
            :first,
            v"1.0.0";
            description="four",
            initialize=context -> begin
                contribute_extension!(context, WidgetContribution, :widget, 1)
                @test_throws ExtensionError contribute_extension!(context, ThemeContribution, :theme, 2)
            end,
        )
        register_extension!(registry, descriptor)
        @test_throws ExtensionError register_extension!(registry, ExtensionDescriptor(:second, v"1.0.0"))
        @test activate_extension!(registry, :first) == [:first]
        @test extension_contribution(registry, WidgetContribution, :widget).value == 1
        set_extension_service!(registry, :service, 1)
        @test_throws ExtensionError set_extension_service!(registry, :second_service, 2)
        @test_throws ArgumentError extension_service(registry, "bad service key")
        deactivate_extension!(registry, :first)
    end

    @testset "dependency resolution is deterministic and strict" begin
        registry = ExtensionRegistry()
        register_extension!(registry, ExtensionDescriptor(:base, v"1.2.0"))
        register_extension!(registry, ExtensionDescriptor(
            :feature,
            v"2.0.0";
            dependencies=[ExtensionDependency(:base; minimum=v"1.0.0", maximum_exclusive=v"2.0.0")],
        ))
        register_extension!(registry, ExtensionDescriptor(
            :optional,
            v"1.0.0";
            dependencies=[ExtensionDependency(:missing; optional=true)],
        ))
        @test resolve_extensions(registry, [:feature, :optional]) == [:base, :feature, :optional]

        incompatible = ExtensionRegistry()
        register_extension!(incompatible, ExtensionDescriptor(:base, v"2.0.0"))
        register_extension!(incompatible, ExtensionDescriptor(
            :consumer,
            v"1.0.0";
            dependencies=[ExtensionDependency(:base; maximum_exclusive=v"2.0.0")],
        ))
        @test_throws ExtensionError resolve_extensions(incompatible, [:consumer])

        cyclic = ExtensionRegistry()
        register_extension!(cyclic, ExtensionDescriptor(
            :left,
            v"1.0.0";
            dependencies=[ExtensionDependency(:right)],
        ))
        register_extension!(cyclic, ExtensionDescriptor(
            :right,
            v"1.0.0";
            dependencies=[ExtensionDependency(:left)],
        ))
        @test_throws ExtensionError resolve_extensions(cyclic, [:left])
    end

    @testset "failed initialization rolls back contributions and resources" begin
        events = Symbol[]
        registry = ExtensionRegistry()
        descriptor = ExtensionDescriptor(
            :failing,
            v"1.0.0";
            initialize=context -> begin
                push!(events, :initialize)
                contribute_extension!(context, WidgetContribution, :temporary, :value)
                error("initialization failed")
            end,
            shutdown=context -> push!(events, :shutdown),
        )
        register_extension!(registry, descriptor)

        @test_throws ExtensionError activate_extension!(registry, :failing)
        @test events == [:initialize, :shutdown]
        @test extension_state(registry, :failing) == ExtensionFailed
        @test extension_contribution(registry, WidgetContribution, :temporary) === nothing
        @test isempty(registry.activation_order)
        @test haskey(registry.failures, :failing)
    end

    @testset "failed shutdown still removes owned state" begin
        registry = ExtensionRegistry()
        descriptor = ExtensionDescriptor(
            :shutdown_failure,
            v"1.0.0";
            initialize=context -> contribute_extension!(context, CommandContribution, :command, :value),
            shutdown=context -> error("shutdown failed"),
        )
        register_extension!(registry, descriptor)
        activate_extension!(registry, :shutdown_failure)

        @test_throws ExtensionError deactivate_extension!(registry, :shutdown_failure)
        @test extension_state(registry, :shutdown_failure) == ExtensionFailed
        @test extension_contribution(registry, CommandContribution, :command) === nothing
        @test isempty(registry.activation_order)
        @test unregister_extension!(registry, :shutdown_failure)
    end

    @testset "batch failure unwinds successful dependencies" begin
        events = Symbol[]
        registry = ExtensionRegistry()
        register_extension!(registry, ExtensionDescriptor(
            :base,
            v"1.0.0";
            initialize=context -> push!(events, :base_up),
            shutdown=context -> push!(events, :base_down),
        ))
        register_extension!(registry, ExtensionDescriptor(
            :consumer,
            v"1.0.0";
            dependencies=[ExtensionDependency(:base)],
            initialize=context -> error("consumer failed"),
            shutdown=context -> push!(events, :consumer_cleanup),
        ))

        @test_throws ExtensionError activate_extension!(registry, :consumer)
        @test events == [:base_up, :consumer_cleanup, :base_down]
        @test extension_state(registry, :base) == ExtensionRegistered
        @test extension_state(registry, :consumer) == ExtensionFailed
        @test isempty(registry.activation_order)
    end

    @testset "scoped activation always cleans up" begin
        events = Symbol[]
        registry = ExtensionRegistry()
        register_extension!(registry, ExtensionDescriptor(
            :scoped,
            v"1.0.0";
            initialize=context -> push!(events, :up),
            shutdown=context -> push!(events, :down),
        ))
        @test_throws ErrorException with_extensions(registry, [:scoped]) do _
            error("operation failed")
        end
        @test events == [:up, :down]
        @test extension_state(registry, :scoped) == ExtensionRegistered
    end
end
