include(joinpath(@__DIR__, "..", "scripts", "parity_policy_audit.jl"))

@testset "parity policy audit" begin
    @test isempty(ParityPolicyAudit.audit())
    @test "Stateful-controls" in ParityPolicyAudit.EXPECTED_FAMILIES
    @test "Developer-experience" in ParityPolicyAudit.EXPECTED_FAMILIES
    @test "manual:" in ParityPolicyAudit.EXPECTED_COMMAND_ENTRYPOINTS
    @test "https://" in ParityPolicyAudit.EXPECTED_ARTIFACT_URL_SCHEMES
    @test "transcript" in ParityPolicyAudit.EXPECTED_MANUAL_ARTIFACT_HINTS
    @test ParityPolicyAudit.checklist_item(
        "Input-event",
        ParityPolicyAudit.EXPECTED_SCOPES["Input-event"],
    ) == "Input/event parity evidence covers routed events, async delivery, cancellation behavior, focus restoration, and terminal lifecycle recovery."
    @test startswith(
        ParityPolicyAudit.checklist_item(
            "Stateful-controls",
            ParityPolicyAudit.EXPECTED_SCOPES["Stateful-controls"],
        ),
        "Stateful-controls parity evidence covers ",
    )
    @test startswith(
        ParityPolicyAudit.checklist_item(
            "Developer-experience",
            ParityPolicyAudit.EXPECTED_SCOPES["Developer-experience"],
        ),
        "Developer-experience parity evidence covers ",
    )

    mktempdir() do directory
        policy = joinpath(directory, "parity_policy.json")
        scaffold = joinpath(directory, "new_parity_evidence.jl")
        closeout = joinpath(directory, "parity_closeout_audit.jl")
        readme = joinpath(directory, "README.md")
        checklist = joinpath(directory, "RELEASE_CHECKLIST.md")
        gitignore = joinpath(directory, ".gitignore")
        write(
            policy,
            """
            {
              "schema_version": 1,
              "families": {
                "Layout": "wrong scope"
              },
              "reference_libraries": ["Ratatui"],
              "required_command_entrypoints": ["scripts/"],
              "allowed_artifact_url_schemes": ["https://"],
              "manual_artifact_hints": ["terminal"],
              "minimum_final_records_per_family": 0,
              "kernel_scope": "Linux only"
            }
            """,
        )
        write(scaffold, "")
        write(closeout, "")
        write(readme, "")
        write(checklist, "")
        write(gitignore, "")
        failures = ParityPolicyAudit.audit(;
            policy_path=policy,
            scaffold_path=scaffold,
            closeout_path=closeout,
            readme_path=readme,
            checklist_path=checklist,
            gitignore_path=gitignore,
        )
        @test any(failure -> occursin("missing family: Stateful-controls", failure), failures)
        @test any(failure -> occursin("must use scope", failure), failures)
        @test any(failure -> occursin("missing reference label: Textual", failure), failures)
        @test any(failure -> occursin("missing command entrypoint: manual:", failure), failures)
        @test any(failure -> occursin("missing artifact URL scheme: http://", failure), failures)
        @test any(failure -> occursin("missing manual artifact hint: transcript", failure), failures)
        @test any(failure -> occursin("minimum_final_records_per_family must be 1", failure), failures)
        @test any(failure -> occursin("scaffold must read required_command_entrypoints", failure), failures)
        @test any(failure -> occursin("closeout audit must read required_command_entrypoints", failure), failures)
        @test any(failure -> occursin("scaffold must read allowed_artifact_url_schemes", failure), failures)
        @test any(failure -> occursin("closeout audit must read allowed_artifact_url_schemes", failure), failures)
        @test any(failure -> occursin("closeout audit must read manual_artifact_hints", failure), failures)
        @test any(failure -> occursin("closeout audit must read minimum_final_records_per_family", failure), failures)
        @test any(failure -> occursin("scaffold missing family", failure), failures)
        @test any(failure -> occursin("release checklist missing parity evidence item", failure), failures)
        @test any(failure -> occursin("scratch/parity-evidence", failure), failures)
    end
end
