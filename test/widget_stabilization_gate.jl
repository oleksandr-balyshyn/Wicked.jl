include(joinpath(@__DIR__, "..", "scripts", "widget_stabilization_gate.jl"))

@testset "widget stabilization gate" begin
    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        WidgetStabilizationGate.main(["--help"])
    end
    @test help_status == 0
    @test occursin("widget-stabilization gate", String(take!(help_output)))
    usage_output = IOBuffer()
    redirect_stdout(usage_output) do
        WidgetStabilizationGate.print_usage()
    end
    @test occursin("--release-check", String(take!(usage_output)))

    list_output = IOBuffer()
    list_status = redirect_stdout(list_output) do
        WidgetStabilizationGate.main(["--list"])
    end
    list_source = String(take!(list_output))
    @test list_status == 0
    @test occursin("widget coverage audit", list_source)
    @test occursin("scripts/widget_audit.jl --require-complete", list_source)
    @test occursin("stable widget candidate audit", list_source)
    @test occursin("public widget candidate audit", list_source)
    @test occursin("widget family evidence audit", list_source)
    @test occursin("experimental promotion audit", list_source)
    @test occursin("widget promotion requirements audit", list_source)
    @test occursin("compatibility widget alias audit", list_source)
    @test occursin("stable promotion packet audit", list_source)

    release_list_output = IOBuffer()
    release_list_status = redirect_stdout(release_list_output) do
        WidgetStabilizationGate.main(["--release-check", "--list"])
    end
    release_list_source = String(take!(release_list_output))
    @test release_list_status == 0
    @test occursin("stable widget stabilization schema audit", release_list_source)
    @test occursin("scripts/stable_widget_stabilization_schema_audit.jl", release_list_source)
    @test occursin("stable widget stabilization readiness", release_list_source)
    @test occursin("scripts/render_widget_catalog.jl --stabilization-status --require-stabilization-ready", release_list_source)
    @test occursin("stable widget surface release schema audit", release_list_source)
    @test occursin("scripts/stable_widget_surface_release_schema_audit.jl", release_list_source)
    @test occursin("stable widget surface release readiness", release_list_source)
    @test occursin("scripts/render_widget_catalog.jl --surface-release-status --require-surface-release-ready", release_list_source)
    @test occursin("stable widget coverage completeness", release_list_source)
    @test occursin("scripts/render_widget_catalog.jl --coverage-summary --format tsv --require-complete-coverage --require-clean-git", release_list_source)
    @test occursin("widget family release closeout", release_list_source)
    @test occursin("scripts/render_widget_family_closeout.jl --release-check --summary --format tsv", release_list_source)
    @test occursin("reference parity matrix release check", release_list_source)
    @test occursin("scripts/render_reference_parity_matrix.jl --release-status --require-release-ready", release_list_source)

    bad_status = redirect_stderr(IOBuffer()) do
        WidgetStabilizationGate.main(["--unknown"])
    end
    @test bad_status == 2

    @test all(step -> isfile(step.script), WidgetStabilizationGate.DEFAULT_STEPS)
    @test all(step -> isfile(step.script), WidgetStabilizationGate.RELEASE_STEPS)
end
