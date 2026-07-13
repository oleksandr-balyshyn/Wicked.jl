include(joinpath(@__DIR__, "..", "scripts", "stable_widget_stability_schema_audit.jl"))

@testset "stable widget stability schema audit" begin
    @test isempty(StableWidgetStabilitySchemaAudit.audit())

    help_output = IOBuffer()
    @test redirect_stdout(help_output) do
        StableWidgetStabilitySchemaAudit.main(["--help"])
    end == 0
    @test occursin("stable_widget_stability_schema_audit.jl", String(take!(help_output)))
    @test !isdefined(StableWidgetStabilitySchemaAudit, :WidgetCatalogRender)

    bad_status = redirect_stderr(IOBuffer()) do
        StableWidgetStabilitySchemaAudit.main(["--bad"])
    end
    @test bad_status == 2

    schema_source = read(StableWidgetStabilitySchemaAudit.SCHEMA_PATH, String)
    generated = StableWidgetStabilitySchemaAudit.widget_stability_json()
    @test isempty(StableWidgetStabilitySchemaAudit.key_contract_failures(schema_source, generated))
    @test isempty(StableWidgetStabilitySchemaAudit.summary_arithmetic_failures(generated))
    @test "schema_version" in StableWidgetStabilitySchemaAudit.generated_keys(generated)
    @test "metadata" in StableWidgetStabilitySchemaAudit.generated_keys(generated)
    @test "generated_at" in StableWidgetStabilitySchemaAudit.generated_keys(generated)
    @test "root" in StableWidgetStabilitySchemaAudit.generated_keys(generated)
    @test "summary" in StableWidgetStabilitySchemaAudit.generated_keys(generated)
    @test "rows" in StableWidgetStabilitySchemaAudit.schema_keys(schema_source)
    @test "blockers" in StableWidgetStabilitySchemaAudit.schema_keys(schema_source)
    @test StableWidgetStabilitySchemaAudit.json_bool_value("{\"ready\":true}", "ready")
    @test any(
        occursin("total must equal ready plus blocked"),
        StableWidgetStabilitySchemaAudit.summary_arithmetic_failures(
            "{\"ready\":false,\"summary\":{\"total\":2,\"ready\":2,\"blocked\":1},\"rows\":[{\"name\":\"Button\"},{\"name\":\"Input\"}]}",
        ),
    )
    @test any(
        occursin("ready flag must match blocked count"),
        StableWidgetStabilitySchemaAudit.summary_arithmetic_failures(
            "{\"ready\":true,\"summary\":{\"total\":1,\"ready\":0,\"blocked\":1},\"rows\":[{\"name\":\"Button\"}]}",
        ),
    )
    @test any(
        occursin("generated JSON is missing schema key `rows`"),
        StableWidgetStabilitySchemaAudit.key_contract_failures(schema_source, "{\"schema_version\":1,\"metadata\":{\"generated_at\":\"2026-01-01T00:00:00Z\",\"root\":\"/repo\"},\"summary\":{\"total\":0}}"),
    )

    mktempdir() do directory
        schema = joinpath(directory, "schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = StableWidgetStabilitySchemaAudit.schema_failures(schema)
        @test any(occursin("\"metadata\""), failures)
        @test any(occursin("\"ready\""), failures)
        @test any(occursin("\"rows\""), failures)
        @test any(occursin("\"missing_checks\""), failures)
        @test any(occursin("\"blockers\""), failures)
    end
end
