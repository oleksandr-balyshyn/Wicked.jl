include(joinpath(@__DIR__, "..", "scripts", "widget_family_closeout_schema_audit.jl"))

@testset "widget family closeout schema audit" begin
    @test isempty(WidgetFamilyCloseoutSchemaAudit.audit())

    help_output = IOBuffer()
    @test redirect_stdout(help_output) do
        WidgetFamilyCloseoutSchemaAudit.main(["--help"])
    end == 0
    @test occursin("widget_family_closeout_schema_audit.jl", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        WidgetFamilyCloseoutSchemaAudit.main(["--bad"])
    end
    @test bad_status == 2

    schema_source = read(WidgetFamilyCloseoutSchemaAudit.SCHEMA_PATH, String)
    generated = WidgetFamilyCloseoutRender.render_closeout(
        (
            family=nothing,
            count=false,
            summary=false,
            format=:json,
            columns=WidgetFamilyCloseoutRender.DEFAULT_COLUMNS,
            header=true,
        ),
    )
    @test isempty(WidgetFamilyCloseoutSchemaAudit.key_contract_failures(schema_source, generated))
    @test isempty(WidgetFamilyCloseoutSchemaAudit.summary_arithmetic_failures(generated))
    @test "schema_version" in WidgetFamilyCloseoutSchemaAudit.generated_keys(generated)
    @test "metadata" in WidgetFamilyCloseoutSchemaAudit.generated_keys(generated)
    @test "generated_at" in WidgetFamilyCloseoutSchemaAudit.generated_keys(generated)
    @test "families" in WidgetFamilyCloseoutSchemaAudit.schema_keys(schema_source)
    @test "git_commit" in WidgetFamilyCloseoutSchemaAudit.schema_keys(schema_source)
    @test "git_dirty" in WidgetFamilyCloseoutSchemaAudit.schema_keys(schema_source)
    @test WidgetFamilyCloseoutSchemaAudit.generated_status_counts(
            "{\"metadata\":{\"generated_at\":\"2026-01-01T00:00:00Z\",\"root\":\"/repo\"},\"summary\":{\"total\":2,\"ready\":1,\"blocked\":1},\"families\":[{\"status\":\"ready\"},{\"status\":\"blocked\"}]}",
    ) == (ready=1, blocked=1, total=2)
    @test any(
        occursin("summary total count 2 does not match 1 family rows"),
        WidgetFamilyCloseoutSchemaAudit.summary_arithmetic_failures(
            "{\"metadata\":{\"generated_at\":\"2026-01-01T00:00:00Z\",\"root\":\"/repo\"},\"summary\":{\"total\":2,\"ready\":1,\"blocked\":1},\"families\":[{\"status\":\"ready\"}]}",
        ),
    )
    @test any(
        occursin("generated JSON is missing schema key `blocker_details`"),
        WidgetFamilyCloseoutSchemaAudit.key_contract_failures(schema_source, "{\"schema_version\":1,\"summary\":{\"total\":0,\"ready\":0,\"blocked\":0},\"families\":[]}"),
    )

    mktempdir() do directory
        schema = joinpath(directory, "schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = WidgetFamilyCloseoutSchemaAudit.schema_failures(schema)
        @test any(occursin("\"families\""), failures)
        @test any(occursin("\"blocker_details\""), failures)
    end
end
