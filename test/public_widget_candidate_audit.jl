include(joinpath(@__DIR__, "..", "scripts", "public_widget_candidate_audit.jl"))

@testset "public widget candidate audit" begin
    stable_row = (
        widget="Panel",
        source="src/widgets.jl",
        surface="stable",
        status="stable",
        reason="exported by Wicked.API; evidence complete",
    )
    candidate_row = (
        widget="ExperimentalPanel",
        source="src/widgets.jl",
        surface="compatibility",
        status="candidate",
        reason="promote to Wicked.API.ExperimentalPanel: evidence complete",
    )
    blocked_row = (
        widget="BlockedPanel",
        source="src/widgets.jl",
        surface="stable",
        status="blocked",
        reason="missing snapshot evidence",
    )

    @test isempty(PublicWidgetCandidateAudit.public_surface_failures([stable_row], Set(["Panel"])))
    @test any(
        contains("public renderable widget is missing from stable candidate evidence"),
        PublicWidgetCandidateAudit.public_surface_failures([stable_row], Set(["MissingPanel"])),
    )
    @test any(
        contains("public renderable widget is not on the stable surface"),
        PublicWidgetCandidateAudit.public_surface_failures([candidate_row], Set(["ExperimentalPanel"])),
    )
    @test any(
        contains("public renderable widget is not stable"),
        PublicWidgetCandidateAudit.public_surface_failures([blocked_row], Set(["BlockedPanel"])),
    )
    @test any(
        contains("stable widget candidate is not exported as a public renderable Wicked.API widget"),
        PublicWidgetCandidateAudit.public_surface_failures([stable_row], Set{String}()),
    )

    duplicate_map, duplicates = PublicWidgetCandidateAudit.candidate_row_map([stable_row, stable_row])
    @test haskey(duplicate_map, "Panel")
    @test duplicates == ["Panel"]
    @test any(
        contains("duplicate widget candidate row: Panel"),
        PublicWidgetCandidateAudit.public_surface_failures([stable_row, stable_row], Set(["Panel"])),
    )

    lines = PublicWidgetCandidateAudit.expected_report_lines([stable_row])
    @test first(lines) == "widget\tsource\tsurface\tstatus\treason"
    @test last(lines) == "Panel\tsrc/widgets.jl\tstable\tstable\texported by Wicked.API; evidence complete"

    mktempdir() do directory
        report = joinpath(directory, "stable_widget_candidates.tsv")
        write(report, join(lines, '\n') * "\n")
        @test isempty(PublicWidgetCandidateAudit.report_current_failures(report; rows=[stable_row]))
        write(report, "widget\tsource\tsurface\tstatus\treason\n")
        @test any(
            contains("stable widget candidate report is stale"),
            PublicWidgetCandidateAudit.report_current_failures(report; rows=[stable_row]),
        )
        @test any(
            contains("missing stable widget candidate report"),
            PublicWidgetCandidateAudit.report_current_failures(joinpath(directory, "missing.tsv"); rows=[stable_row]),
        )
    end

    @test !isempty(PublicWidgetCandidateAudit.api_renderable_widget_names())
    @test !isempty(PublicWidgetCandidateAudit.renderable_widget_names())
end
