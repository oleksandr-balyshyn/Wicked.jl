include(joinpath(@__DIR__, "..", "scripts", "render_widget_promotion_requirements.jl"))

@testset "widget promotion requirements render" begin
    mktempdir() do directory
        ledger = joinpath(directory, "requirements.tsv")
        write(
            ledger,
            """
            id\tarea\trequirement\tevidence\tgate\trelease_required
            api-shape\tapi\tReview public API shape.\tAPI docs.\tscripts/api_audit.jl\tyes
            docs-guide\tdocs\tWrite developer docs.\tDocs.\tscripts/documentation_evidence_audit.jl\tno
            """,
        )

        rows = WidgetPromotionRequirementsRender.read_rows(ledger)
        @test length(rows) == 2
        @test WidgetPromotionRequirementsRender.filter_rows(rows; area="api") == rows[1:1]
        @test WidgetPromotionRequirementsRender.filter_rows(rows; release_required="no") == rows[2:2]

        markdown = WidgetPromotionRequirementsRender.render(; path=ledger, format="markdown")
        @test occursin("| ID | Area | Requirement | Evidence | Gate | Release required |", markdown)
        @test occursin("api-shape", markdown)
        @test occursin("docs-guide", markdown)

        tsv = WidgetPromotionRequirementsRender.render(; path=ledger, format="tsv", area="api", release_required="yes", header=false)
        @test tsv == "api-shape\tapi\tReview public API shape.\tAPI docs.\tscripts/api_audit.jl\tyes"

        json = WidgetPromotionRequirementsRender.render(; path=ledger, format="json", release_required="yes")
        @test occursin("\"schema_version\": 1", json)
        @test occursin("\"summary\": {", json)
        @test occursin("\"total\": 1", json)
        @test occursin("\"by_area\": {", json)
        @test occursin("\"api\": 1", json)
        @test occursin("\"by_release_required\": {", json)
        @test occursin("\"id\": \"api-shape\"", json)
        @test occursin("\"release_required\": \"yes\"", json)
        @test !occursin("docs-guide", json)

        output = joinpath(directory, "promotion-requirements.md")
        WidgetPromotionRequirementsRender.write_output(output, markdown)
        @test isfile(output)

        help_output = IOBuffer()
        help_status = redirect_stdout(help_output) do
            WidgetPromotionRequirementsRender.main(["--help"])
        end
        @test help_status == 0
        @test occursin("Renders the widget promotion requirements ledger", String(take!(help_output)))

        json_status = redirect_stdout(IOBuffer()) do
            WidgetPromotionRequirementsRender.main(["--format", "json"])
        end
        @test json_status == 0
        invalid_status = redirect_stderr(IOBuffer()) do
            WidgetPromotionRequirementsRender.main(["--format", "xml"])
        end
        @test invalid_status == 1
    end
end
