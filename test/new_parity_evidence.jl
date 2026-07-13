module NewParityEvidenceScaffoldTest

using Test

include(joinpath(@__DIR__, "..", "scripts", "new_parity_evidence.jl"))

@testset "new parity evidence scaffold" begin
    @test "Stateful-controls" in VALID_FAMILIES
    @test "Developer-experience" in VALID_FAMILIES
    @test "manual:" in policy_command_entrypoints()
    @test "https://" in policy_artifact_url_schemes()
    @test "transcript" in policy_manual_artifact_hints()
    @test "Family" in policy_required_identity_fields()
    @test "Evidence summary" in policy_required_sections()
    @test "manual:" in policy_contract().command_entrypoints
    @test policy_minimum_final_records_per_family() == 1
    @test "Runtime\tqueue replacement, task cancellation races, redraw determinism, resource cleanup, subscription shutdown" in blocking_family_lines()
    @test !any(startswith("Developer-experience\t"), blocking_family_lines())
    @test parse_bool("true")
    @test !parse_bool("false")
    @test_throws ErrorException parse_bool("maybe")

    mktempdir() do directory
        draft_dir = joinpath(directory, "drafts")
        final_dir = joinpath(directory, "final")
        policy_without_entrypoints = joinpath(directory, "parity_policy.json")
        write(policy_without_entrypoints, """{"schema_version": 1}""")
        try
            policy_command_entrypoints(policy_without_entrypoints)
            @test false
        catch error
            @test occursin("required_command_entrypoints", sprint(showerror, error))
        end
        try
            policy_artifact_url_schemes(policy_without_entrypoints)
            @test false
        catch error
            @test occursin("allowed_artifact_url_schemes", sprint(showerror, error))
        end
        try
            policy_manual_artifact_hints(policy_without_entrypoints)
            @test false
        catch error
            @test occursin("manual_artifact_hints", sprint(showerror, error))
        end
        try
            policy_required_identity_fields(policy_without_entrypoints)
            @test false
        catch error
            @test occursin("required_identity_fields", sprint(showerror, error))
        end
        try
            policy_required_sections(policy_without_entrypoints)
            @test false
        catch error
            @test occursin("required_sections", sprint(showerror, error))
        end
        try
            policy_minimum_final_records_per_family(policy_without_entrypoints)
            @test false
        catch error
            @test occursin("minimum_final_records_per_family", sprint(showerror, error))
        end
        policy_with_zero_minimum = joinpath(directory, "zero_minimum_policy.json")
        write(
            policy_with_zero_minimum,
            """
            {
              "required_command_entrypoints": ["scripts/"],
              "allowed_artifact_url_schemes": ["https://"],
              "manual_artifact_hints": ["manual"],
              "required_identity_fields": ["Family"],
              "required_sections": ["Evidence summary"],
              "minimum_final_records_per_family": 0
            }
            """,
        )
        try
            policy_minimum_final_records_per_family(policy_with_zero_minimum)
            @test false
        catch error
            @test occursin("minimum_final_records_per_family must be positive", sprint(showerror, error))
        end
        template_missing_field = joinpath(directory, "missing-field-template.md")
        write(template_missing_field, replace(read(TEMPLATE, String), "| Family | Layout / Input-event / Stateful-controls / Data-display / Runtime / Developer-experience / Styling-theming / Remote-delivery |\n" => ""))
        try
            create_record(
                Dict(
                    "family" => "Stateful-controls",
                    "environment" => "linux-pty-missing-field",
                    "candidate" => "0123456789abcdee",
                );
                template=template_missing_field,
                draft_dir,
                evidence_dir=final_dir,
            )
            @test false
        catch error
            @test occursin("template missing required identity field from policy: Family", sprint(showerror, error))
        end
        template_missing_section = joinpath(directory, "missing-section-template.md")
        write(template_missing_section, replace(read(TEMPLATE, String), "## Evidence summary\n\nRecord the observed result. Include test counts, snapshot IDs, benchmark artifact\nnames, browser client version, terminal emulator version, or manual transcript\npaths when applicable.\n\n- \n\n" => ""))
        try
            create_record(
                Dict(
                    "family" => "Stateful-controls",
                    "environment" => "linux-pty-missing-section",
                    "candidate" => "0123456789abcdea",
                );
                template=template_missing_section,
                draft_dir,
                evidence_dir=final_dir,
            )
            @test false
        catch error
            @test occursin("template missing required section from policy: Evidence summary", sprint(showerror, error))
        end

        draft_path, draft_final = create_record(
            Dict(
                "family" => "Stateful-controls",
                "environment" => "linux-pty",
                "candidate" => "0123456789abcdef",
            );
            draft_dir,
            evidence_dir=final_dir,
        )
        @test !draft_final
        @test startswith(draft_path, draft_dir)
        @test occursin("| Family | Stateful-controls |", read(draft_path, String))

        final_path, final_record = create_record(
            Dict(
                "family" => "Developer-experience",
                "environment" => "linux-ci",
                "candidate" => "abcdef1234567890",
                "final" => "true",
                "date" => "2026-07-12 12:00:00 UTC",
                "julia-version" => "1.12.6",
                "kernel" => "Linux 7.0.0 x86_64",
                "capability" => "UnicodeWidthPolicy, truecolor",
                "command" => "julia --project=. --startup-file=no scripts/quality_gate.jl",
                "exit-status" => "0",
                "artifact" => "https://github.com/owner/repo/actions/runs/123456",
                "behavior" => "API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output were reviewed",
                "summary" => "developer API evidence was recorded for the release candidate",
                "parity-notes" => "observed behavior matches Textual developer tooling expectations with documented Wicked API names",
                "risks" => "independent downstream application adoption remains a release checklist item",
            );
            draft_dir,
            evidence_dir=final_dir,
        )
        @test final_record
        @test startswith(final_path, final_dir)
        @test basename(final_path) == "developer-experience-linux-ci-abcdef1234567890.md"
        final_source = read(final_path, String)
        @test occursin("| Family | Developer-experience |", final_source)
        @test occursin("- API contract tests", final_source)
        @test_throws ErrorException create_record(
            Dict(
                "family" => "Developer-experience",
                "environment" => "linux-ci-scope-failure",
                "candidate" => "abcdef1234567891",
                "final" => "true",
                "date" => "2026-07-12 12:00:00 UTC",
                "julia-version" => "1.12.6",
                "kernel" => "Linux 7.0.0 x86_64",
                "capability" => "UnicodeWidthPolicy, truecolor",
                "command" => "julia --project=. --startup-file=no scripts/quality_gate.jl",
                "exit-status" => "0",
                "artifact" => "https://github.com/owner/repo/actions/runs/123457",
                "behavior" => "API contract tests, examples, and documentation build output were reviewed",
                "summary" => "developer API evidence was recorded for the release candidate",
                "parity-notes" => "observed behavior matches Textual developer tooling expectations with documented Wicked API names",
                "risks" => "independent downstream application adoption remains a release checklist item",
            );
            draft_dir,
            evidence_dir=final_dir,
        )
        @test_throws ErrorException create_record(
            Dict(
                "family" => "Developer-experience",
                "environment" => "linux-ci-artifact-failure",
                "candidate" => "abcdef1234567892",
                "final" => "true",
                "date" => "2026-07-12 12:00:00 UTC",
                "julia-version" => "1.12.6",
                "kernel" => "Linux 7.0.0 x86_64",
                "capability" => "UnicodeWidthPolicy, truecolor",
                "command" => "julia --project=. --startup-file=no scripts/quality_gate.jl",
                "exit-status" => "0",
                "artifact" => "missing-artifact.txt",
                "behavior" => "API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output were reviewed",
                "summary" => "developer API evidence was recorded for the release candidate",
                "parity-notes" => "observed behavior matches Textual developer tooling expectations with documented Wicked API names",
                "risks" => "independent downstream application adoption remains a release checklist item",
            );
            draft_dir,
            evidence_dir=final_dir,
        )
        @test_throws ErrorException create_record(
            Dict(
                "family" => "Developer-experience",
                "environment" => "linux-ci-command-failure",
                "candidate" => "abcdef1234567893",
                "final" => "true",
                "date" => "2026-07-12 12:00:00 UTC",
                "julia-version" => "1.12.6",
                "kernel" => "Linux 7.0.0 x86_64",
                "capability" => "UnicodeWidthPolicy, truecolor",
                "command" => "run the quality checks",
                "exit-status" => "0",
                "artifact" => "https://github.com/owner/repo/actions/runs/123458",
                "behavior" => "API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output were reviewed",
                "summary" => "developer API evidence was recorded for the release candidate",
                "parity-notes" => "observed behavior matches Textual developer tooling expectations with documented Wicked API names",
                "risks" => "independent downstream application adoption remains a release checklist item",
            );
            draft_dir,
            evidence_dir=final_dir,
        )
        try
            create_record(
                Dict(
                    "family" => "Developer-experience",
                    "environment" => "linux-ci-manual-artifact-failure",
                    "candidate" => "abcdef1234567894",
                    "final" => "true",
                    "date" => "2026-07-12 12:00:00 UTC",
                    "julia-version" => "1.12.6",
                    "kernel" => "Linux 7.0.0 x86_64",
                    "capability" => "UnicodeWidthPolicy, truecolor",
                    "command" => "manual: downstream application walkthrough",
                    "exit-status" => "0",
                    "artifact" => "https://github.com/owner/repo/actions/runs/123459",
                    "behavior" => "API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output were reviewed",
                    "summary" => "developer API evidence was recorded for the release candidate",
                    "parity-notes" => "observed behavior matches Textual developer tooling expectations with documented Wicked API names",
                    "risks" => "independent downstream application adoption remains a release checklist item",
                );
                draft_dir,
                evidence_dir=final_dir,
            )
            @test false
        catch error
            @test occursin("manual artifact hint", sprint(showerror, error))
        end

        @test_throws ErrorException create_record(
            Dict(
                "family" => "Unsupported",
                "environment" => "linux-ci",
                "candidate" => "0123456789abcdef",
            );
            draft_dir,
            evidence_dir=final_dir,
        )
        @test_throws ErrorException create_record(
            Dict(
                "family" => "Developer-experience",
                "environment" => "linux-ci",
                "candidate" => "abcdef1234567890",
                "final" => "true",
            );
            draft_dir,
            evidence_dir=final_dir,
        )
    end
end

end # module NewParityEvidenceScaffoldTest
