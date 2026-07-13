include(joinpath(@__DIR__, "..", "scripts", "parity_closeout_audit.jl"))

function parity_closeout_policy_source()
    family_rows = join(
        ("\"$family\": \"scope for $family\"" for family in ParityCloseoutAudit.EXPECTED_FAMILIES),
        ",\n",
    )
    return """
    {
      "schema_version": 1,
      "families": {
        $family_rows
      },
      "required_identity_fields": [
        "Family",
        "Release-candidate commit",
        "Date and UTC time",
        "Julia version",
        "Kernel and distribution",
        "Terminal or browser environment",
        "Width policy and color capability",
        "Command",
        "Exit status",
        "Artifact path or CI URL"
      ],
      "required_sections": [
        "Behaviors checked",
        "Reference-library parity notes",
        "Evidence summary",
        "Risks and follow-up"
      ],
      "required_command_entrypoints": [
        "scripts/",
        "test/",
        "benchmark/",
        "docs/make.jl",
        "Pkg.test",
        "node --check",
        "manual:"
      ],
      "allowed_artifact_url_schemes": [
        "http://",
        "https://"
      ],
      "manual_artifact_hints": [
        "terminal",
        "manual",
        "transcript",
        "screenshot",
        "recording",
        "matrix"
      ],
      "minimum_final_records_per_family": 1
    }
    """
end

function parity_closeout_record(;
    family="Layout",
    commit="abcdef1",
    behavior="scope for Layout was exercised.",
    artifact="https://github.com/acme/wicked/actions/runs/123456",
    command="julia --project=. --startup-file=no scripts/widget_audit.jl --require-complete",
)
    return """
    # Parity Evidence Record

    ## Record identity

    | Field | Value |
    | --- | --- |
    | Family | $family |
    | Release-candidate commit | $commit |
    | Date and UTC time | 2026-07-12 12:00:00 UTC |
    | Julia version | 1.12.6 |
    | Kernel and distribution | Linux 7.0.0 x86_64 |
    | Terminal or browser environment | ubuntu-latest CI |
    | Width policy and color capability | UnicodeWidthPolicy, truecolor |
    | Command | $command |
    | Exit status | 0 |
    | Artifact path or CI URL | $artifact |

    ## Behaviors checked

    - $behavior

    ## Reference-library parity notes

    - The result matches Ratatui deterministic layout expectations and records Wicked-specific clipping behavior.

    ## Evidence summary

    - The command completed successfully and produced the attached CI artifact.

    ## Risks and follow-up

    - Real-terminal glyph rendering remains tracked by the terminal matrix.
    """
end

@testset "parity closeout audit" begin
    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, """{"schema_version": 1, "families": {"Layout": "scope for Layout"}}""")
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), parity_closeout_record())

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("required_command_entrypoints", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, replace(parity_closeout_policy_source(), "\"minimum_final_records_per_family\": 1" => "\"minimum_final_records_per_family\": 0"))
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), parity_closeout_record())

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("minimum_final_records_per_family must be positive", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), parity_closeout_record())

        @test isempty(ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence))
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), replace(parity_closeout_record(), "attached CI artifact" => "TODO"))

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("TODO placeholder", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "unknown-ci-abcdef1.md"), parity_closeout_record(; family="Unknown"))

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("unknown parity family", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), parity_closeout_record(; behavior="layout smoke coverage was exercised"))

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("policy closeout scope for Layout", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), parity_closeout_record(; artifact="missing-artifact.txt"))

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("HTTP(S) URL or an existing artifact path", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), parity_closeout_record(; command="run the widget checks"))

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("Wicked validation/evidence entry point", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), parity_closeout_record(; command="manual: kitty resize pass", artifact="https://github.com/acme/wicked/actions/runs/123456"))

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("manual evidence artifact must include a manual artifact hint", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "wrong-name.md"), parity_closeout_record())

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("filename must include family slug `layout`", failure), failures)
        @test any(failure -> occursin("filename must include environment slug `ubuntu-latest-ci`", failure), failures)
        @test any(failure -> occursin("filename must include release-candidate commit `abcdef1`", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), parity_closeout_record())
        write(joinpath(evidence, "layout-ubuntu-latest-ci-copy-abcdef1.md"), parity_closeout_record())

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence)
        @test any(failure -> occursin("duplicates parity evidence identity", failure), failures)
    end

    mktempdir() do dir
        policy = joinpath(dir, "parity_policy.json")
        evidence = joinpath(dir, "evidence")
        mkpath(evidence)
        write(policy, parity_closeout_policy_source())
        write(joinpath(evidence, "layout-ubuntu-latest-ci-abcdef1.md"), parity_closeout_record())

        failures = ParityCloseoutAudit.audit(; policy_path=policy, evidence_dir=evidence, require_complete=true)
        @test any(failure -> occursin("missing final parity evidence record for family: Runtime (0/1)", failure), failures)
        @test !any(failure -> occursin("missing final parity evidence record for family: Developer-experience", failure), failures)
        @test !any(failure -> occursin("missing final parity evidence record for family: Stateful-controls", failure), failures)
    end

    @test "Runtime" in ParityCloseoutAudit.release_blocking_policy_families()
    @test "Remote-delivery" in ParityCloseoutAudit.release_blocking_policy_families()
    @test !("Developer-experience" in ParityCloseoutAudit.release_blocking_policy_families())
    @test !("Stateful-controls" in ParityCloseoutAudit.release_blocking_policy_families())
    survey_records = ParityCloseoutAudit.release_blocking_survey_records()
    @test survey_records["Remote-delivery"].survey_family == "Remote delivery"
    @test survey_records["Remote-delivery"].parity_status == "adapted"
    @test !isempty(survey_records["Remote-delivery"].follow_up)
    @test isempty(ParityCloseoutAudit.closeout_requirements_schema_failures())
    mktempdir() do dir
        schema = joinpath(dir, "schema.json")
        write(schema, "{\"schema_version\":1}")
        failures = ParityCloseoutAudit.closeout_requirements_schema_failures(schema)
        @test any(occursin("\"rows\""), failures)
        @test any(occursin("\"release_ready\""), failures)
    end

    records = ParityCloseoutAudit.closeout_requirement_records()
    @test any(record -> record.family == "Runtime" && record.missing >= 0, records)
    @test any(record -> record.family == "Remote-delivery" && record.survey_family == "Remote delivery", records)
    @test all(record -> !isempty(record.parity_status) && !isempty(record.follow_up), records)
    @test all(record -> record.required >= 1, records)
    @test all(record -> occursin("scripts/new_parity_evidence.jl --family $(record.family)", record.scaffold_command), records)
    requirements_tsv = ParityCloseoutAudit.render_closeout_requirements_tsv(records)
    @test startswith(requirements_tsv, "family\tsurvey_family\tparity_status\tfollow_up\trequired\tobserved\tmissing\tstatus\tscope\tscaffold_command")
    @test occursin("Remote-delivery", requirements_tsv)
    requirements_markdown = ParityCloseoutAudit.render_closeout_requirements_markdown(records)
    @test startswith(requirements_markdown, "| Family | Survey family | Parity status | Follow-up | Required | Observed | Missing | Status | Scope | Scaffold command |")
    requirements_json = ParityCloseoutAudit.render_closeout_requirements_json(records)
    @test occursin("\"schema_version\": 1", requirements_json)
    @test occursin("\"rows\": [", requirements_json)
    @test occursin("\"family\": \"Runtime\"", requirements_json)
    @test occursin("\"survey_family\":", requirements_json)
    @test occursin("\"parity_status\":", requirements_json)
    @test occursin("\"follow_up\":", requirements_json)
    @test occursin("\"scaffold_command\":", requirements_json)
    requirements_status = ParityCloseoutAudit.render_closeout_requirements_status(records)
    @test occursin("parity_closeout_release_ready=", requirements_status)
    @test occursin("missing_families=", requirements_status)
    @test occursin("Runtime", requirements_status)
    runtime_records = ParityCloseoutAudit.filter_closeout_requirement_records(records, "Runtime")
    @test all(record -> record.family == "Runtime", runtime_records)
    remote_records = ParityCloseoutAudit.filter_closeout_requirement_records(records, "Remote delivery")
    @test all(record -> record.family == "Remote-delivery", remote_records)
    lower_remote_records = ParityCloseoutAudit.filter_closeout_requirement_records(records, "remote delivery")
    @test all(record -> record.family == "Remote-delivery", lower_remote_records)
    @test_throws ErrorException ParityCloseoutAudit.filter_closeout_requirement_records(records, "missing-family")
    @test isempty(ParityCloseoutAudit.closeout_requirements_json_failures(requirements_json))
    @test any(
        occursin("total must equal row count"),
        ParityCloseoutAudit.closeout_requirements_json_failures(
            replace(requirements_json, "\"total\": $(length(records))" => "\"total\": 999"; count=1),
        ),
    )
    @test any(
        occursin("missing total must equal row missing sum"),
        ParityCloseoutAudit.closeout_requirements_json_failures(
            replace(requirements_json, "\"missing\": " => "\"missing\": 999"; count=1),
        ),
    )
    @test any(
        occursin("row status must match missing count"),
        ParityCloseoutAudit.closeout_requirements_json_failures(
            replace(requirements_json, "\"status\": \"missing\"" => "\"status\": \"ready\""; count=1),
        ),
    )
    @test any(
        occursin("scaffold_command must match row family"),
        ParityCloseoutAudit.closeout_requirements_json_failures(
            replace(requirements_json, "scripts/new_parity_evidence.jl --family Runtime" => "scripts/new_parity_evidence.jl --family Layout"; count=1),
        ),
    )

    mktempdir() do dir
        output = joinpath(dir, "parity-closeout-requirements.tsv")
        status = ParityCloseoutAudit.main(["--report", "tsv", "--output", output])
        @test status == 0 || status == 1
        @test isfile(output)
        @test startswith(read(output, String), "family\tsurvey_family\tparity_status")
        @test occursin("scaffold_command", read(output, String))
    end
    mktempdir() do dir
        output = joinpath(dir, "parity-closeout-requirements-status.txt")
        status = ParityCloseoutAudit.main(["--status", "--output", output])
        @test status == 0 || status == 1
        @test isfile(output)
        @test startswith(read(output, String), "parity_closeout_release_ready=")
    end
    mktempdir() do dir
        output = joinpath(dir, "runtime-closeout-requirements.tsv")
        status = ParityCloseoutAudit.main(["--report", "tsv", "--family", "remote delivery", "--output", output])
        @test status == 0 || status == 1
        @test isfile(output)
        source = read(output, String)
        @test occursin("Remote-delivery", source)
        @test !occursin("Runtime", source)
    end
    mktempdir() do dir
        output = joinpath(dir, "unknown-closeout-requirements.tsv")
        status = redirect_stderr(IOBuffer()) do
            ParityCloseoutAudit.main(["--report", "tsv", "--family", "missing-family", "--output", output])
        end
        @test status == 1
        @test !isfile(output)
    end
end
