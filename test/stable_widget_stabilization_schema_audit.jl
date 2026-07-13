include(joinpath(@__DIR__, "..", "scripts", "stable_widget_stabilization_schema_audit.jl"))

@testset "stable widget stabilization schema audit" begin
    @test isempty(StableWidgetStabilizationSchemaAudit.audit())

    help_output = IOBuffer()
    @test redirect_stdout(help_output) do
        StableWidgetStabilizationSchemaAudit.main(["--help"])
    end == 0
    @test occursin("stable_widget_stabilization_schema_audit.jl", String(take!(help_output)))
    @test !isdefined(StableWidgetStabilizationSchemaAudit, :WidgetCatalogRender)

    bad_status = redirect_stderr(IOBuffer()) do
        StableWidgetStabilizationSchemaAudit.main(["--bad"])
    end
    @test bad_status == 2

    schema_source = read(StableWidgetStabilizationSchemaAudit.SCHEMA_PATH, String)
    generated = StableWidgetStabilizationSchemaAudit.widget_stabilization_status_json()
    @test isempty(StableWidgetStabilizationSchemaAudit.key_contract_failures(schema_source, generated))
    @test isempty(StableWidgetStabilizationSchemaAudit.readiness_consistency_failures(generated))
    @test "schema_version" in StableWidgetStabilizationSchemaAudit.generated_keys(generated)
    @test "ready" in StableWidgetStabilizationSchemaAudit.generated_keys(generated)
    @test "candidate_widgets" in StableWidgetStabilizationSchemaAudit.schema_keys(schema_source)
    @test "experimental_widgets" in StableWidgetStabilizationSchemaAudit.schema_keys(schema_source)
    @test StableWidgetStabilizationSchemaAudit.json_bool_value("{\"ready\":true}", "ready")
    @test StableWidgetStabilizationSchemaAudit.json_array_count("{\"candidate_widgets\":[\"A\",\"B\"]}", "candidate_widgets") == 2
    @test any(
        occursin("ready must match candidate, experimental, stability, and family closeout blockers"),
        StableWidgetStabilizationSchemaAudit.readiness_consistency_failures(
            "{\"ready\":true,\"candidate_widget_count\":1,\"candidate_widgets\":[\"Panel\"],\"experimental_widget_count\":0,\"experimental_widgets\":[],\"stability_blocked\":0,\"family_closeout_blocked\":0}",
        ),
    )
    @test any(
        occursin("candidate_widget_count must match candidate_widgets length"),
        StableWidgetStabilizationSchemaAudit.readiness_consistency_failures(
            "{\"ready\":false,\"candidate_widget_count\":2,\"candidate_widgets\":[\"Panel\"],\"experimental_widget_count\":0,\"experimental_widgets\":[],\"stability_blocked\":0,\"family_closeout_blocked\":0}",
        ),
    )
    @test any(
        occursin("generated JSON is missing schema key `experimental_widgets`"),
        StableWidgetStabilizationSchemaAudit.key_contract_failures(
            schema_source,
            "{\"schema_version\":1,\"ready\":false,\"total_widgets\":1,\"stable_widgets\":0,\"candidate_widget_count\":1,\"candidate_widgets\":[\"Panel\"],\"experimental_widget_count\":0,\"stability_blocked\":0,\"family_closeout_blocked\":0}",
        ),
    )

    mktempdir() do directory
        schema = joinpath(directory, "schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = StableWidgetStabilizationSchemaAudit.schema_failures(schema)
        @test any(occursin("\"ready\""), failures)
        @test any(occursin("\"candidate_widget_count\""), failures)
        @test any(occursin("\"candidate_widgets\""), failures)
        @test any(occursin("\"experimental_widget_count\""), failures)
        @test any(occursin("\"family_closeout_blocked\""), failures)
    end
end
