include(joinpath(@__DIR__, "..", "scripts", "widget_promotion_requirements_schema_audit.jl"))

@testset "widget promotion requirements schema audit" begin
    @test isempty(WidgetPromotionRequirementsSchemaAudit.audit())

    help_output = IOBuffer()
    @test redirect_stdout(help_output) do
        WidgetPromotionRequirementsSchemaAudit.main(["--help"])
    end == 0
    @test occursin("widget_promotion_requirements_schema_audit.jl", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        WidgetPromotionRequirementsSchemaAudit.main(["--bad"])
    end
    @test bad_status == 2

    schema_source = read(WidgetPromotionRequirementsSchemaAudit.SCHEMA_PATH, String)
    generated = WidgetPromotionRequirementsSchemaAudit.WidgetPromotionRequirementsRender.render(; format="json", release_required="yes")
    @test isempty(WidgetPromotionRequirementsSchemaAudit.key_contract_failures(schema_source, generated))
    @test "schema_version" in WidgetPromotionRequirementsSchemaAudit.generated_keys(generated)
    @test "summary" in WidgetPromotionRequirementsSchemaAudit.generated_keys(generated)
    @test "total" in WidgetPromotionRequirementsSchemaAudit.generated_keys(generated)
    @test "by_area" in WidgetPromotionRequirementsSchemaAudit.generated_keys(generated)
    @test "by_release_required" in WidgetPromotionRequirementsSchemaAudit.generated_keys(generated)
    @test "requirements" in WidgetPromotionRequirementsSchemaAudit.generated_keys(generated)
    @test "release_required" in WidgetPromotionRequirementsSchemaAudit.schema_keys(schema_source)
    @test !occursin("\"release_required\": \"no\"", generated)

    mktempdir() do directory
        schema = joinpath(directory, "schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = WidgetPromotionRequirementsSchemaAudit.schema_failures(schema)
        @test any(occursin("\"summary\""), failures)
        @test any(occursin("\"by_area\""), failures)
        @test any(occursin("\"requirements\""), failures)
        @test any(occursin("\"release_required\""), failures)
        @test any(occursin("\"additionalProperties\": false"), failures)
    end
end
