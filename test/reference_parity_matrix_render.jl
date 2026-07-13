include(joinpath(@__DIR__, "..", "scripts", "render_reference_parity_matrix.jl"))

@testset "reference parity matrix render" begin
    mktempdir() do directory
        survey = joinpath(directory, "survey.md")
        write(
            survey,
            """
            # Survey

            | Family | Ratatui baseline to mirror | Textual baseline to mirror | TamboUI baseline to mirror | Lanterna baseline to mirror | Wicked implementation direction | Parity status | Follow-up |
            | --- | --- | --- | --- | --- | --- | --- | --- |
            | Layout | constraints | sizing | rows | viewport | deterministic layout | adapted | release checklist |
            | Developer experience | examples | pilot | runner | compatibility | diagnostics | matched | keep notes |
            """,
        )

        rows = ReferenceParityMatrixRender.parity_rows(survey)
        @test length(rows) == 2
        @test rows[1].family == "Layout"
        @test ReferenceParityMatrixRender.filter_rows(rows; status="matched") == rows[2:2]
        @test ReferenceParityMatrixRender.filter_rows(rows; family="layout") == rows[1:1]
        @test ReferenceParityMatrixRender.blocking_rows(rows) == rows[1:1]

        markdown = ReferenceParityMatrixRender.render(; path=survey, format="markdown")
        @test occursin("| Family | Ratatui | Textual | TamboUI | Lanterna | Wicked direction | Status | Follow-up |", markdown)
        @test occursin("Developer experience", markdown)
        blocking_markdown = ReferenceParityMatrixRender.render(; path=survey, format="markdown", blocking_only=true)
        @test occursin("Layout", blocking_markdown)
        @test !occursin("Developer experience", blocking_markdown)
        focused_markdown = ReferenceParityMatrixRender.render(; path=survey, format="markdown", columns=(:family, :status, :follow_up))
        @test occursin("| Family | Status | Follow-up |", focused_markdown)
        @test !occursin("Ratatui", focused_markdown)

        tsv = ReferenceParityMatrixRender.render(; path=survey, format="tsv", status="adapted", header=false)
        @test startswith(tsv, "Layout\tconstraints\tsizing")
        focused_tsv = ReferenceParityMatrixRender.render(; path=survey, format="tsv", columns=(:family, :status))
        @test startswith(focused_tsv, "family\tstatus")
        @test occursin("Layout\tadapted", focused_tsv)
        @test ReferenceParityMatrixRender.parse_columns("family,status,follow_up") == (:family, :status, :follow_up)
        @test_throws ErrorException ReferenceParityMatrixRender.parse_columns("missing")
        @test_throws ErrorException ReferenceParityMatrixRender.parse_columns("family,,status")
        @test_throws ErrorException ReferenceParityMatrixRender.parse_columns("family,status,status")

        json = ReferenceParityMatrixRender.render(; path=survey, format="json")
        @test occursin("\"schema_version\": 1", json)
        @test occursin("\"by_status\": {", json)
        @test occursin("\"adapted\": 1", json)
        @test occursin("\"matched\": 1", json)
        @test occursin("\"family\": \"Layout\"", json)
        summary_markdown = ReferenceParityMatrixRender.render(; path=survey, format="markdown", summary=true)
        @test occursin("| Metric | Key | Count |", summary_markdown)
        @test occursin("| status | adapted | 1 |", summary_markdown)
        summary_tsv = ReferenceParityMatrixRender.render(; path=survey, format="tsv", summary=true, header=false)
        @test startswith(summary_tsv, "total\tall\t2")
        summary_json = ReferenceParityMatrixRender.render(; path=survey, format="json", summary=true)
        @test occursin("\"total\": 2", summary_json)
        @test occursin("\"matched\": 1", summary_json)
        blocking_summary_json = ReferenceParityMatrixRender.render(; path=survey, format="json", summary=true, blocking_only=true)
        @test occursin("\"total\": 1", blocking_summary_json)
        @test !occursin("\"matched\"", blocking_summary_json)

        release_status = ReferenceParityMatrixRender.render_release_status(rows)
        @test occursin("release_ready=false", release_status)
        @test occursin("blocking=1", release_status)
        @test occursin("Layout", release_status)
        @test occursin("Layout[adapted]: release checklist", release_status)
        release_blockers = ReferenceParityMatrixRender.render_release_blockers(rows)
        @test release_blockers == "Layout[adapted]: release checklist"
        release_status_json = ReferenceParityMatrixRender.render_release_status_json(rows)
        @test occursin("\"schema_version\": 1", release_status_json)
        @test occursin("\"release_ready\": false", release_status_json)
        @test occursin("\"blocking\": 1", release_status_json)
        @test occursin("\"blocking_records\": [", release_status_json)
        @test occursin("\"status\": \"adapted\"", release_status_json)
        @test occursin("\"follow_up\": \"release checklist\"", release_status_json)

        matched_survey = joinpath(directory, "matched-survey.md")
        write(
            matched_survey,
            """
            # Survey

            | Family | Ratatui baseline to mirror | Textual baseline to mirror | TamboUI baseline to mirror | Lanterna baseline to mirror | Wicked implementation direction | Parity status | Follow-up |
            | --- | --- | --- | --- | --- | --- | --- | --- |
            | Developer experience | examples | pilot | runner | compatibility | diagnostics | matched | keep notes |
            """,
        )
        matched_rows = ReferenceParityMatrixRender.parity_rows(matched_survey)
        matched_release_status = ReferenceParityMatrixRender.render_release_status(matched_rows)
        @test occursin("release_ready=true", matched_release_status)
        @test occursin("blocking=0", matched_release_status)
        @test ReferenceParityMatrixRender.render_release_blockers(matched_rows) == ""
        matched_release_status_json = ReferenceParityMatrixRender.render_release_status_json(matched_rows)
        @test occursin("\"schema_version\": 1", matched_release_status_json)
        @test occursin("\"release_ready\": true", matched_release_status_json)
        @test occursin("\"blocking\": 0", matched_release_status_json)

        blocked_survey = joinpath(directory, "blocked-survey.md")
        write(
            blocked_survey,
            """
            # Survey

            | Family | Ratatui baseline to mirror | Textual baseline to mirror | TamboUI baseline to mirror | Lanterna baseline to mirror | Wicked implementation direction | Parity status | Follow-up |
            | --- | --- | --- | --- | --- | --- | --- | --- |
            | Remote delivery | backend | remote | runner | protocol | browser delivery | not yet implemented | issue #42 |
            """,
        )
        blocked_rows = ReferenceParityMatrixRender.parity_rows(blocked_survey)
        blocked_status = ReferenceParityMatrixRender.render_release_status(blocked_rows)
        @test occursin("release_ready=false", blocked_status)
        @test occursin("blocking=1", blocked_status)
        @test occursin("Remote delivery", blocked_status)
        @test occursin("Remote delivery[not yet implemented]: issue #42", blocked_status)
        @test ReferenceParityMatrixRender.render_release_blockers(blocked_rows) == "Remote delivery[not yet implemented]: issue #42"
        blocked_status_json = ReferenceParityMatrixRender.render_release_status_json(blocked_rows)
        @test occursin("\"release_ready\": false", blocked_status_json)
        @test occursin("\"blocking\": 1", blocked_status_json)
        @test occursin("\"Remote delivery\"", blocked_status_json)
        @test occursin("\"status\": \"not yet implemented\"", blocked_status_json)
        @test occursin("\"follow_up\": \"issue #42\"", blocked_status_json)
        @test ReferenceParityMatrixRender.assert_release_ready(matched_rows)
        @test_throws ArgumentError ReferenceParityMatrixRender.assert_release_ready(rows)
        @test_throws ArgumentError ReferenceParityMatrixRender.assert_release_ready(blocked_rows)

        output = joinpath(directory, "reference-parity-matrix.md")
        ReferenceParityMatrixRender.write_output(output, markdown)
        @test isfile(output)

        help_output = IOBuffer()
        help_status = redirect_stdout(help_output) do
            ReferenceParityMatrixRender.main(["--help"])
        end
        @test help_status == 0
        @test occursin("cross-library capability matrix", String(take!(help_output)))

        invalid_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--format", "xml"])
        end
        @test invalid_status == 1
        invalid_header_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--no-header"])
        end
        @test invalid_header_status == 1
        invalid_release_mode_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--release-status", "--release-status-json"])
        end
        @test invalid_release_mode_status == 1
        invalid_release_blockers_mode_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--release-status", "--release-blockers"])
        end
        @test invalid_release_blockers_mode_status == 1
        invalid_blocking_release_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--blocking-only", "--release-status"])
        end
        @test invalid_blocking_release_status == 1
        invalid_blocking_release_blockers_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--blocking-only", "--release-blockers"])
        end
        @test invalid_blocking_release_blockers_status == 1
        invalid_json_columns_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--format", "json", "--columns", "family,status"])
        end
        @test invalid_json_columns_status == 1
        invalid_summary_columns_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--summary", "--columns", "family,status"])
        end
        @test invalid_summary_columns_status == 1
        invalid_empty_columns_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--format", "tsv", "--columns", "family,,status"])
        end
        @test invalid_empty_columns_status == 1
        invalid_duplicate_columns_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main(["--format", "tsv", "--columns", "family,status,status"])
        end
        @test invalid_duplicate_columns_status == 1

        source_output = joinpath(directory, "source-output.tsv")
        source_status = ReferenceParityMatrixRender.main([
            "--source", blocked_survey,
            "--format", "tsv",
            "--columns", "family,status",
            "--output", source_output,
        ])
        @test source_status == 0
        @test occursin("Remote delivery\tnot yet implemented", read(source_output, String))
        @test !occursin("Developer experience\tmatched", read(source_output, String))
        blocking_output = joinpath(directory, "blocking-output.tsv")
        blocking_status = ReferenceParityMatrixRender.main([
            "--source", survey,
            "--blocking-only",
            "--format", "tsv",
            "--columns", "family,status,follow_up",
            "--output", blocking_output,
        ])
        @test blocking_status == 0
        blocking_source = read(blocking_output, String)
        @test occursin("Layout\tadapted\trelease checklist", blocking_source)
        @test !occursin("Developer experience\tmatched", blocking_source)

        blocker_output = joinpath(directory, "release-blockers.txt")
        blocker_status = ReferenceParityMatrixRender.main([
            "--source", survey,
            "--release-blockers",
            "--output", blocker_output,
        ])
        @test blocker_status == 0
        @test read(blocker_output, String) == "Layout[adapted]: release checklist"

        blocked_output = joinpath(directory, "blocked-status.txt")
        failed_status = redirect_stderr(IOBuffer()) do
            ReferenceParityMatrixRender.main([
                "--source", blocked_survey,
                "--release-status",
                "--require-release-ready",
                "--output", blocked_output,
            ])
        end
        @test failed_status == 1
        @test isfile(blocked_output)
        @test occursin("release_ready=false", read(blocked_output, String))
    end
end
