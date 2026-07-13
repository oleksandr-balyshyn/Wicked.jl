include(joinpath(@__DIR__, "..", "scripts", "quality_gate.jl"))

@testset "examples README policy" begin
    examples = Set(["examples/dashboard.jl", "forms.jl", "nested.jl", "space demo.jl"])
    valid = """
    # Examples

    - `dashboard.jl`
    - [`forms.jl`](forms.jl)
    - [nested.jl](./examples/nested.jl#run)
    - [space demo](./examples/space%20demo.jl)
    """
    @test isempty(examples_readme_policy_failures(valid, examples))

    missing_listing = """
    # Examples

    - `dashboard.jl`
    """
    failures = examples_readme_policy_failures(missing_listing, examples)
    @test any(failure -> occursin("must list forms.jl", failure), failures)

    stale_code_name = """
    # Examples

    - `dashboard.jl`
    - `forms.jl`
    - `removed.jl`
    """
    failures = examples_readme_policy_failures(stale_code_name, examples)
    @test any(failure -> occursin("lists missing example file: removed.jl", failure), failures)

    stale_link = """
    # Examples

    - `dashboard.jl`
    - `forms.jl`
    - [old.jl](old.jl)
    """
    failures = examples_readme_policy_failures(stale_link, examples)
    @test any(failure -> occursin("links missing example file: old.jl", failure), failures)

    duplicate_entries = """
    # Examples

    - `dashboard.jl`
    - `dashboard.jl`
    - `forms.jl`
    - [nested.jl](nested.jl)
    - [nested again](./nested.jl#run)
    """
    failures = examples_readme_policy_failures(duplicate_entries, examples)
    @test any(failure -> occursin("lists dashboard.jl multiple times", failure), failures)
    @test any(failure -> occursin("links nested.jl multiple times", failure), failures)

    mixed_duplicate = """
    # Examples

    - `dashboard.jl`
    - [dashboard link](dashboard.jl)
    - [`forms.jl`](forms.jl)
    - [nested.jl](nested.jl)
    - [space demo](space%20demo.jl)
    """
    @test isempty(examples_readme_policy_failures(mixed_duplicate, examples))
end

@testset "component catalog widget type binding policy" begin
    mktempdir() do directory
        catalog = joinpath(directory, "COMPONENT_CATALOG.md")
        stable_api = joinpath(directory, "stable_api.tsv")

        write(
            catalog,
            """
            # Catalog

            ## Public widget-name map

            | Cross-library concept | Wicked API name | State contract |
            |---|---|---|
            | Panel | `Panel` or `Card` | Stateless |
            | Input | `TextInput` | `TextInputState` |

            ## Internal renderable exclusions
            """,
        )
        write(
            stable_api,
            """
            # Wicked.API candidate stable API
            # name<TAB>binding-kind
            Panel\tdatatype
            Card\tunionall
            TextInput\tdatatype
            TextInputState\tdatatype
            """,
        )
        @test isempty(check_component_catalog_widget_type_bindings!(catalog, stable_api))

        write(
            stable_api,
            """
            # Wicked.API candidate stable API
            # name<TAB>binding-kind
            Panel\tdatatype
            Card\tfunction
            TextInput\tdatatype
            """,
        )
        failures = check_component_catalog_widget_type_bindings!(catalog, stable_api)
        @test any(
            occursin("component catalog widget `Card` must be a concrete or parameterized Wicked.API type binding, found `function`"),
            failures,
        )

        write(
            stable_api,
            """
            # Wicked.API candidate stable API
            # name<TAB>binding-kind
            Panel\tdatatype
            TextInput\tdatatype
            """,
        )
        missing_failures = check_component_catalog_widget_type_bindings!(catalog, stable_api)
        @test any(
            occursin("component catalog widget `Card` must be a concrete or parameterized Wicked.API type binding, found `missing`"),
            missing_failures,
        )
    end
end
