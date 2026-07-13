include(joinpath(@__DIR__, "..", "scripts", "component_catalog_public_map.jl"))

@testset "component catalog public map parser" begin
    entries = ComponentCatalogPublicMap.read_entries(
        joinpath(@__DIR__, "..", "docs", "COMPONENT_CATALOG.md");
        root=joinpath(@__DIR__, ".."),
    )
    widgets = ComponentCatalogPublicMap.widget_names(entries)
    states = ComponentCatalogPublicMap.state_contract_names(entries)
    exclusions = ComponentCatalogPublicMap.read_exclusions(
        joinpath(@__DIR__, "..", "docs", "COMPONENT_CATALOG.md");
        root=joinpath(@__DIR__, ".."),
    )
    missing = ComponentCatalogPublicMap.missing_renderables(
        joinpath(@__DIR__, "..", "docs", "COMPONENT_CATALOG.md");
        coverage_path=joinpath(@__DIR__, "..", "api", "widget_coverage.tsv"),
        root=joinpath(@__DIR__, ".."),
    )

    @test !isempty(entries)
    @test "Modal" in widgets
    @test "SearchInput" in widgets
    @test "TextInputState" in states
    @test "Stateless" ∉ states
    @test "ToolkitTree" in exclusions
    @test isempty(missing)
    list_exclusions_output = IOBuffer()
    list_exclusions_status = redirect_stdout(list_exclusions_output) do
        ComponentCatalogPublicMap.main(["--list-exclusions"])
    end
    @test list_exclusions_status == 0
    @test occursin("ToolkitTree", String(take!(list_exclusions_output)))
    incompatible_list_modes_status = redirect_stderr(IOBuffer()) do
        ComponentCatalogPublicMap.main(["--list-unmapped", "--list-exclusions"])
    end
    @test incompatible_list_modes_status == 2

    mktempdir() do directory
        invalid_widget = joinpath(directory, "invalid-widget.md")
        write(
            invalid_widget,
            """
            # Catalog

            ## Public widget-name map

            | Cross-library concept | Wicked API name | State contract |
            |---|---|---|
            | Broken | Modal | Stateless |
            """,
        )
        @test_throws ErrorException ComponentCatalogPublicMap.read_entries(
            invalid_widget;
            root=directory,
        )

        invalid_state = joinpath(directory, "invalid-state.md")
        write(
            invalid_state,
            """
            # Catalog

            ## Public widget-name map

            | Cross-library concept | Wicked API name | State contract |
            |---|---|---|
            | Broken | `Modal` | DialogState |
            """,
        )
        @test_throws ErrorException ComponentCatalogPublicMap.read_entries(
            invalid_state;
            root=directory,
        )

        duplicate_widget = joinpath(directory, "duplicate-widget.md")
        write(
            duplicate_widget,
            """
            # Catalog

            ## Public widget-name map

            | Cross-library concept | Wicked API name | State contract |
            |---|---|---|
            | Dialog | `Modal` | Stateless |
            | Overlay dialog | `Modal` | Stateless |
            """,
        )
        try
            ComponentCatalogPublicMap.read_entries(duplicate_widget; root=directory)
            @test false
        catch error
            @test error isa ErrorException
            message = sprint(showerror, error)
            @test occursin("line", message)
            @test occursin("Dialog", message)
            @test occursin("Overlay dialog", message)
        end

        duplicate_concept = joinpath(directory, "duplicate-concept.md")
        write(
            duplicate_concept,
            """
            # Catalog

            ## Public widget-name map

            | Cross-library concept | Wicked API name | State contract |
            |---|---|---|
            | Dialog | `Modal` | Stateless |
            | Dialog | `Overlay` | Stateless |
            """,
        )
        try
            ComponentCatalogPublicMap.read_entries(duplicate_concept; root=directory)
            @test false
        catch error
            @test error isa ErrorException
            message = sprint(showerror, error)
            @test occursin("concept", message)
            @test occursin("Dialog", message)
        end

        coverage = joinpath(directory, "widget_coverage.tsv")
        write(
            coverage,
            """
            widget_type\tstateless\tstateful
            Wicked.Modal\ttrue\tfalse
            Wicked.Toolkit.ToolkitTree\ttrue\tfalse
            Wicked.Unmapped\ttrue\tfalse
            """,
        )
        catalog = joinpath(directory, "catalog.md")
        write(
            catalog,
            """
            # Catalog

            ## Public widget-name map

            | Cross-library concept | Wicked API name | State contract |
            |---|---|---|
            | Dialog | `Modal` | Stateless |

            ## Internal renderable exclusions

            | Renderable | Reason |
            |---|---|
            | `ToolkitTree` | Internal Toolkit render tree used by reconciliation diagnostics; application developers should build declarative UI with public Toolkit APIs instead. |
            """,
        )
        @test ComponentCatalogPublicMap.missing_renderables(
            catalog;
            coverage_path=coverage,
            root=directory,
        ) == Set(["Unmapped"])

        weak_exclusion_reason = joinpath(directory, "weak-exclusion-reason.md")
        write(
            weak_exclusion_reason,
            """
            # Catalog

            ## Public widget-name map

            | Cross-library concept | Wicked API name | State contract |
            |---|---|---|
            | Dialog | `Modal` | Stateless |

            ## Internal renderable exclusions

            | Renderable | Reason |
            |---|---|
            | `ToolkitTree` | Internal |
            """,
        )
        try
            ComponentCatalogPublicMap.read_exclusions(weak_exclusion_reason; root=directory)
            @test false
        catch error
            @test error isa ErrorException
            @test occursin("exclusion reason", sprint(showerror, error))
        end
    end
end
