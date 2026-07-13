include(joinpath(@__DIR__, "..", "scripts", "reference_parity_matrix_schema_audit.jl"))

@testset "reference parity matrix schema audit" begin
    @test isempty(ReferenceParityMatrixSchemaAudit.audit())

    help_output = IOBuffer()
    @test redirect_stdout(help_output) do
        ReferenceParityMatrixSchemaAudit.main(["--help"])
    end == 0
    @test occursin("reference_parity_matrix_schema_audit.jl", String(take!(help_output)))
    release_error = IOBuffer()
    @test redirect_stderr(release_error) do
        ReferenceParityMatrixSchemaAudit.main(["--release-check"])
    end == 1
    @test occursin("not marked `matched`", String(take!(release_error)))

    bad_status = redirect_stderr(IOBuffer()) do
        ReferenceParityMatrixSchemaAudit.main(["--bad"])
    end
    @test bad_status == 2

    schema_source = read(ReferenceParityMatrixSchemaAudit.SCHEMA_PATH, String)
    summary_schema_source = read(ReferenceParityMatrixSchemaAudit.SUMMARY_SCHEMA_PATH, String)
    status_schema_source = read(ReferenceParityMatrixSchemaAudit.STATUS_SCHEMA_PATH, String)
    generated = ReferenceParityMatrixSchemaAudit.ReferenceParityMatrixRender.render(; format="json")
    generated_adapted = ReferenceParityMatrixSchemaAudit.ReferenceParityMatrixRender.render(; format="json", status="adapted")
    generated_blocking = ReferenceParityMatrixSchemaAudit.ReferenceParityMatrixRender.render(; format="json", blocking_only=true)
    generated_remote = ReferenceParityMatrixSchemaAudit.ReferenceParityMatrixRender.render(; format="json", family="remote delivery")
    generated_summary = ReferenceParityMatrixSchemaAudit.ReferenceParityMatrixRender.render(; format="json", summary=true)
    generated_status = ReferenceParityMatrixSchemaAudit.ReferenceParityMatrixRender.render_release_status_json(
        ReferenceParityMatrixSchemaAudit.ReferenceParityMatrixRender.parity_rows(),
    )
    @test isempty(ReferenceParityMatrixSchemaAudit.key_contract_failures(schema_source, generated))
    @test isempty(ReferenceParityMatrixSchemaAudit.matrix_json_failures(generated_adapted; label="generated adapted JSON"))
    @test isempty(ReferenceParityMatrixSchemaAudit.adapted_status_filter_failures(generated_adapted))
    @test isempty(ReferenceParityMatrixSchemaAudit.generated_adapted_json_failures())
    @test isempty(ReferenceParityMatrixSchemaAudit.matrix_json_failures(generated_blocking; label="generated blocking JSON"))
    @test isempty(ReferenceParityMatrixSchemaAudit.blocking_status_filter_failures(generated_blocking))
    @test isempty(ReferenceParityMatrixSchemaAudit.generated_blocking_json_failures())
    @test isempty(ReferenceParityMatrixSchemaAudit.matrix_json_failures(generated_remote; label="generated remote-delivery JSON"))
    @test isempty(ReferenceParityMatrixSchemaAudit.single_family_filter_failures(generated_remote, ReferenceParityMatrixSchemaAudit.REMOTE_DELIVERY_FAMILY))
    @test isempty(ReferenceParityMatrixSchemaAudit.generated_remote_delivery_json_failures())
    @test isempty(ReferenceParityMatrixSchemaAudit.summary_key_contract_failures(summary_schema_source, generated_summary))
    @test isempty(ReferenceParityMatrixSchemaAudit.status_key_contract_failures(status_schema_source, generated_status))
    @test "schema_version" in ReferenceParityMatrixSchemaAudit.generated_keys(generated)
    @test "summary" in ReferenceParityMatrixSchemaAudit.generated_keys(generated)
    @test "by_status" in ReferenceParityMatrixSchemaAudit.generated_keys(generated)
    @test "rows" in ReferenceParityMatrixSchemaAudit.generated_keys(generated)
    @test "ratatui" in ReferenceParityMatrixSchemaAudit.schema_keys(schema_source)
    @test "tamboui" in ReferenceParityMatrixSchemaAudit.schema_keys(schema_source)
    @test "follow_up" in ReferenceParityMatrixSchemaAudit.schema_keys(schema_source)
    @test "by_status" in ReferenceParityMatrixSchemaAudit.schema_keys(summary_schema_source)
    @test "release_ready" in ReferenceParityMatrixSchemaAudit.schema_keys(status_schema_source)
    @test "blocking_families" in ReferenceParityMatrixSchemaAudit.schema_keys(status_schema_source)
    @test "blocking_records" in ReferenceParityMatrixSchemaAudit.schema_keys(status_schema_source)
    @test "follow_up" in ReferenceParityMatrixSchemaAudit.schema_keys(status_schema_source)
    @test ReferenceParityMatrixSchemaAudit.json_integer_value(generated, "total") !== nothing
    @test ReferenceParityMatrixSchemaAudit.json_bool_value(generated_status, "release_ready") !== nothing
    @test isempty(ReferenceParityMatrixSchemaAudit.generated_summary_json_failures())
    @test isempty(ReferenceParityMatrixSchemaAudit.summary_json_arithmetic_failures(generated_summary))
    @test ReferenceParityMatrixSchemaAudit.json_string_array_values(generated_status, "blocking_families") !== nothing
    @test ReferenceParityMatrixSchemaAudit.status_blocking_records(generated_status) !== nothing
    @test !isempty(ReferenceParityMatrixSchemaAudit.row_status_values(generated))
    @test !isempty(ReferenceParityMatrixSchemaAudit.row_family_values(generated))
    @test !isempty(ReferenceParityMatrixSchemaAudit.summary_status_counts(generated))
    @test isempty(ReferenceParityMatrixSchemaAudit.summary_arithmetic_failures(generated))
    @test isempty(ReferenceParityMatrixSchemaAudit.status_arithmetic_failures(generated_status))
    @test isempty(ReferenceParityMatrixSchemaAudit.follow_up_policy_failures(generated))
    @test ReferenceParityMatrixSchemaAudit.actionable_follow_up("Release checklist: Layout parity evidence covers resize.")
    @test ReferenceParityMatrixSchemaAudit.actionable_follow_up("Tracked by issue #42.")
    @test !ReferenceParityMatrixSchemaAudit.actionable_follow_up("keep notes current")
    @test any(
        occursin("total must equal row count"),
        ReferenceParityMatrixSchemaAudit.summary_arithmetic_failures(
            "{\"schema_version\":1,\"summary\":{\"total\":2,\"by_status\":{\"matched\":1}},\"rows\":[{\"status\":\"matched\"}]}",
        ),
    )
    @test any(
        occursin("by_status count for `matched`"),
        ReferenceParityMatrixSchemaAudit.summary_arithmetic_failures(
            "{\"schema_version\":1,\"summary\":{\"total\":1,\"by_status\":{\"matched\":2}},\"rows\":[{\"status\":\"matched\"}]}",
        ),
    )
    @test any(
        occursin("must cite a release checklist item or issue follow-up"),
        ReferenceParityMatrixSchemaAudit.follow_up_policy_failures(
            "{\"rows\":[{\"status\":\"adapted\",\"follow_up\":\"keep notes current\"}]}",
        ),
    )
    @test any(
        occursin("non-adapted row status `matched`"),
        ReferenceParityMatrixSchemaAudit.adapted_status_filter_failures(
            "{\"rows\":[{\"status\":\"adapted\"},{\"status\":\"matched\"}]}",
        ),
    )
    @test any(
        occursin("matched row status `matched`"),
        ReferenceParityMatrixSchemaAudit.blocking_status_filter_failures(
            "{\"rows\":[{\"status\":\"adapted\"},{\"status\":\"matched\"}]}",
        ),
    )
    @test any(
        occursin("unexpected family `Layout`"),
        ReferenceParityMatrixSchemaAudit.single_family_filter_failures(
            "{\"rows\":[{\"family\":\"Remote delivery\"},{\"family\":\"Layout\"}]}",
            "Remote delivery",
        ),
    )
    @test any(
        occursin("at least one row"),
        ReferenceParityMatrixSchemaAudit.single_family_filter_failures(
            "{\"rows\":[]}",
            "Remote delivery",
        ),
    )
    @test any(
        occursin("at least one adapted row"),
        ReferenceParityMatrixSchemaAudit.adapted_status_filter_failures(
            "{\"rows\":[]}",
        ),
    )
    @test any(
        occursin("at least one blocking row"),
        ReferenceParityMatrixSchemaAudit.blocking_status_filter_failures(
            "{\"rows\":[]}",
        ),
    )
    @test isempty(
        ReferenceParityMatrixSchemaAudit.adapted_status_filter_failures(
            "{\"rows\":[]}";
            require_nonempty=false,
        ),
    )
    @test isempty(
        ReferenceParityMatrixSchemaAudit.blocking_status_filter_failures(
            "{\"rows\":[]}";
            require_nonempty=false,
        ),
    )
    @test any(
        occursin("not marked `matched`: adapted"),
        ReferenceParityMatrixSchemaAudit.release_policy_failures(
            "{\"rows\":[{\"status\":\"matched\"},{\"status\":\"adapted\"}]}",
        ),
    )
    @test any(
        occursin("not marked `matched`: not yet implemented"),
        ReferenceParityMatrixSchemaAudit.release_policy_failures(
            "{\"rows\":[{\"status\":\"not yet implemented\"}]}",
        ),
    )
    @test any(
        occursin("release_ready must match blocking count"),
        ReferenceParityMatrixSchemaAudit.status_arithmetic_failures(
            "{\"release_ready\":true,\"total\":1,\"blocking\":1,\"blocking_families\":[\"Remote delivery\"],\"blocking_records\":[{\"family\":\"Remote delivery\",\"status\":\"adapted\",\"follow_up\":\"issue #42\"}]}",
        ),
    )
    @test any(
        occursin("blocking count must equal blocking_families length"),
        ReferenceParityMatrixSchemaAudit.status_arithmetic_failures(
            "{\"release_ready\":false,\"total\":1,\"blocking\":1,\"blocking_families\":[],\"blocking_records\":[{\"family\":\"Remote delivery\",\"status\":\"adapted\",\"follow_up\":\"issue #42\"}]}",
        ),
    )
    @test any(
        occursin("blocking count must equal blocking_records length"),
        ReferenceParityMatrixSchemaAudit.status_arithmetic_failures(
            "{\"release_ready\":false,\"total\":1,\"blocking\":1,\"blocking_families\":[\"Remote delivery\"],\"blocking_records\":[]}",
        ),
    )
    @test any(
        occursin("blocking_records families must match blocking_families"),
        ReferenceParityMatrixSchemaAudit.status_arithmetic_failures(
            "{\"release_ready\":false,\"total\":1,\"blocking\":1,\"blocking_families\":[\"Layout\"],\"blocking_records\":[{\"family\":\"Remote delivery\",\"status\":\"adapted\",\"follow_up\":\"issue #42\"}]}",
        ),
    )
    @test any(
        occursin("total must equal by_status count sum"),
        ReferenceParityMatrixSchemaAudit.summary_json_arithmetic_failures(
            "{\"schema_version\":1,\"total\":2,\"by_status\":{\"matched\":1}}",
        ),
    )

    mktempdir() do directory
        schema = joinpath(directory, "schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = ReferenceParityMatrixSchemaAudit.schema_failures(schema)
        @test any(occursin("\"summary\""), failures)
        @test any(occursin("\"by_status\""), failures)
        @test any(occursin("\"rows\""), failures)
        @test any(occursin("\"ratatui\""), failures)
        @test any(occursin("\"follow_up\""), failures)
    end

    mktempdir() do directory
        schema = joinpath(directory, "status-schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = ReferenceParityMatrixSchemaAudit.status_schema_failures(schema)
        @test any(occursin("\"release_ready\""), failures)
        @test any(occursin("\"blocking_families\""), failures)
        @test any(occursin("\"blocking_records\""), failures)
        @test any(occursin("\"follow_up\""), failures)
        @test any(occursin("\"additionalProperties\": false"), failures)
    end

    mktempdir() do directory
        schema = joinpath(directory, "summary-schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = ReferenceParityMatrixSchemaAudit.summary_schema_failures(schema)
        @test any(occursin("\"total\""), failures)
        @test any(occursin("\"by_status\""), failures)
        @test any(occursin("\"additionalProperties\": false"), failures)
    end
end
