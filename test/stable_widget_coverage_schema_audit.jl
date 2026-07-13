include(joinpath(@__DIR__, "..", "scripts", "stable_widget_coverage_schema_audit.jl"))

@testset "stable widget coverage schema audit" begin
    @test isempty(StableWidgetCoverageSchemaAudit.audit())

    help_output = IOBuffer()
    @test redirect_stdout(help_output) do
        StableWidgetCoverageSchemaAudit.main(["--help"])
    end == 0
    @test occursin("stable_widget_coverage_schema_audit.jl", String(take!(help_output)))
    @test !isdefined(StableWidgetCoverageSchemaAudit, :WidgetCatalogRender)

    bad_status = redirect_stderr(IOBuffer()) do
        StableWidgetCoverageSchemaAudit.main(["--bad"])
    end
    @test bad_status == 2

    schema_source = read(StableWidgetCoverageSchemaAudit.SCHEMA_PATH, String)
    generated = StableWidgetCoverageSchemaAudit.widget_coverage_summary_json(include_git=false)
    @test isempty(StableWidgetCoverageSchemaAudit.key_contract_failures(schema_source, generated))
    @test isempty(StableWidgetCoverageSchemaAudit.summary_arithmetic_failures(generated))
    @test "schema_version" in StableWidgetCoverageSchemaAudit.generated_keys(generated)
    @test "metadata" in StableWidgetCoverageSchemaAudit.generated_keys(generated)
    @test "generated_at" in StableWidgetCoverageSchemaAudit.generated_keys(generated)
    @test "root" in StableWidgetCoverageSchemaAudit.generated_keys(generated)
    @test "summary" in StableWidgetCoverageSchemaAudit.generated_keys(generated)
    @test "rows" in StableWidgetCoverageSchemaAudit.schema_keys(schema_source)
    @test "git_commit" in StableWidgetCoverageSchemaAudit.schema_keys(schema_source)
    @test "git_dirty" in StableWidgetCoverageSchemaAudit.schema_keys(schema_source)
    @test StableWidgetCoverageSchemaAudit.json_bool_value("{\"complete\":true}", "complete")
    @test any(
        occursin("total must equal complete plus incomplete"),
        StableWidgetCoverageSchemaAudit.summary_arithmetic_failures(
            "{\"complete\":false,\"summary\":{\"total\":2,\"complete\":2,\"incomplete\":1,\"missing_records\":1,\"source_mismatches\":0,\"missing_checks\":0},\"rows\":[]}",
        ),
    )
    @test any(
        occursin("generated JSON is missing schema key `rows`"),
        StableWidgetCoverageSchemaAudit.key_contract_failures(schema_source, "{\"schema_version\":1,\"metadata\":{\"generated_at\":\"2026-01-01T00:00:00Z\",\"root\":\"/repo\"},\"summary\":{\"total\":0},\"rows\":[]}"),
    )

    mktempdir() do directory
        schema = joinpath(directory, "schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = StableWidgetCoverageSchemaAudit.schema_failures(schema)
        @test any(occursin("\"metadata\""), failures)
        @test any(occursin("\"git_commit\""), failures)
        @test any(occursin("\"git_dirty\""), failures)
        @test any(occursin("\"rows\""), failures)
        @test any(occursin("\"missing_checks\""), failures)
    end
end
