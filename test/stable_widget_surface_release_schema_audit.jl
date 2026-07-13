include(joinpath(@__DIR__, "..", "scripts", "stable_widget_surface_release_schema_audit.jl"))

@testset "stable widget surface release schema audit" begin
    @test isempty(StableWidgetSurfaceReleaseSchemaAudit.audit())

    help_output = IOBuffer()
    @test redirect_stdout(help_output) do
        StableWidgetSurfaceReleaseSchemaAudit.main(["--help"])
    end == 0
    @test occursin("stable_widget_surface_release_schema_audit.jl", String(take!(help_output)))
    @test !isdefined(StableWidgetSurfaceReleaseSchemaAudit, :WidgetCatalogRender)

    bad_status = redirect_stderr(IOBuffer()) do
        StableWidgetSurfaceReleaseSchemaAudit.main(["--bad"])
    end
    @test bad_status == 2

    schema_source = read(StableWidgetSurfaceReleaseSchemaAudit.SCHEMA_PATH, String)
    generated = StableWidgetSurfaceReleaseSchemaAudit.widget_surface_release_status_json()
    @test isempty(StableWidgetSurfaceReleaseSchemaAudit.key_contract_failures(schema_source, generated))
    @test isempty(StableWidgetSurfaceReleaseSchemaAudit.readiness_consistency_failures(generated))
    @test "schema_version" in StableWidgetSurfaceReleaseSchemaAudit.generated_keys(generated)
    @test "release_ready" in StableWidgetSurfaceReleaseSchemaAudit.generated_keys(generated)
    @test "coverage_release_ready" in StableWidgetSurfaceReleaseSchemaAudit.generated_keys(generated)
    @test "git_commit" in StableWidgetSurfaceReleaseSchemaAudit.schema_keys(schema_source)
    @test "family_closeout_blocked" in StableWidgetSurfaceReleaseSchemaAudit.schema_keys(schema_source)
    @test StableWidgetSurfaceReleaseSchemaAudit.json_bool_value("{\"release_ready\":true}", "release_ready")
    @test StableWidgetSurfaceReleaseSchemaAudit.json_null_value("{\"git_commit\":null}", "git_commit")
    @test any(
        occursin("release_ready must match coverage, stability, and family closeout readiness"),
        StableWidgetSurfaceReleaseSchemaAudit.readiness_consistency_failures(
            "{\"release_ready\":true,\"coverage_release_ready\":false,\"coverage_complete\":false,\"git_available\":true,\"git_dirty\":false,\"git_commit\":null,\"stability_complete\":true,\"stability_blocked\":0,\"family_closeout_complete\":true,\"family_closeout_blocked\":0}",
        ),
    )
    @test any(
        occursin("stability_complete must match stability_blocked"),
        StableWidgetSurfaceReleaseSchemaAudit.readiness_consistency_failures(
            "{\"release_ready\":false,\"coverage_release_ready\":true,\"coverage_complete\":true,\"git_available\":true,\"git_dirty\":false,\"git_commit\":null,\"stability_complete\":true,\"stability_blocked\":1,\"family_closeout_complete\":true,\"family_closeout_blocked\":0}",
        ),
    )
    @test any(
        occursin("generated JSON is missing schema key `git_commit`"),
        StableWidgetSurfaceReleaseSchemaAudit.key_contract_failures(
            schema_source,
            "{\"schema_version\":1,\"release_ready\":false,\"coverage_release_ready\":false,\"coverage_complete\":false,\"git_available\":false,\"git_dirty\":false,\"stability_complete\":false,\"stability_blocked\":1,\"family_closeout_complete\":false,\"family_closeout_blocked\":1}",
        ),
    )

    mktempdir() do directory
        schema = joinpath(directory, "schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = StableWidgetSurfaceReleaseSchemaAudit.schema_failures(schema)
        @test any(occursin("\"release_ready\""), failures)
        @test any(occursin("\"coverage_release_ready\""), failures)
        @test any(occursin("\"git_commit\""), failures)
        @test any(occursin("\"stability_blocked\""), failures)
        @test any(occursin("\"family_closeout_blocked\""), failures)
    end
end
