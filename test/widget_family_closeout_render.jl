include(joinpath(@__DIR__, "..", "scripts", "render_widget_family_closeout.jl"))

@testset "widget family closeout render" begin
    help_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--help"]; io=help_output) == 0
    help_text = String(take!(help_output))
    @test occursin("render_widget_family_closeout.jl", help_text)
    @test occursin("--release-check", help_text)
    @test occursin("--status ready|blocked|all", help_text)

    output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--columns", "family,status,blockers,blocker_details"]; io=output) == 0
    markdown = String(take!(output))
    @test startswith(markdown, "| `family` | `status` | `blockers` | `blocker_details` |")
    @test occursin("Core layout", markdown)

    tsv_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--format", "tsv", "--columns", "family,status"]; io=tsv_output) == 0
    tsv = String(take!(tsv_output))
    @test startswith(tsv, "family\tstatus\n")
    @test occursin("Toolkit\t", tsv)

    no_header_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--format", "tsv", "--no-header", "--columns", "family,status"]; io=no_header_output) == 0
    no_header = String(take!(no_header_output))
    @test !startswith(no_header, "family\tstatus")

    json_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--format", "json", "--family", "toolkit"]; io=json_output) == 0
    json = String(take!(json_output))
    @test startswith(json, "{\"schema_version\":1,\"metadata\":")
    @test occursin("\"generated_at\":\"", json)
    @test occursin("\"root\":\"", json)
    commit = WidgetFamilyCloseoutRender.git_commit()
    commit === nothing || @test occursin("\"git_commit\":\"$commit\"", json)
    dirty = WidgetFamilyCloseoutRender.git_dirty()
    dirty === nothing || @test occursin("\"git_dirty\":$(dirty)", json)
    @test occursin("\"families\":[{\"family\":\"Toolkit\"", json)

    clean_git_error = IOBuffer()
    clean_git_status = WidgetFamilyCloseoutRender.main(["--family", "toolkit", "--require-clean-git"]; err=clean_git_error)
    if dirty === false
        @test clean_git_status == 0
    else
        @test clean_git_status == 1
        @test occursin("git ", String(take!(clean_git_error)))
    end
    @test occursin("\"blocker_details\":[]", json)

    release_check_options = WidgetFamilyCloseoutRender.parse_arguments(["--release-check"])
    @test release_check_options.release_check
    @test release_check_options.require_ready
    @test release_check_options.require_clean_git
    @test release_check_options.require_blocked_count == 0

    count_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--count", "--family", "toolkit"]; io=count_output) == 0
    @test strip(String(take!(count_output))) == "1"

    summary_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--summary", "--format", "tsv"]; io=summary_output) == 0
    summary = String(take!(summary_output))
    @test startswith(summary, "status\tcount\n")
    @test occursin("ready\t", summary)
    @test occursin("blocked\t", summary)

    json_summary_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--summary", "--format", "json"]; io=json_summary_output) == 0
    @test startswith(String(take!(json_summary_output)), "{\"total\":")

    ready_status_count_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--status", "ready", "--count"]; io=ready_status_count_output) == 0
    @test parse(Int, strip(String(take!(ready_status_count_output)))) >= 0

    count_assertion_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--family", "toolkit", "--require-total-count", "1", "--require-ready-count", "1", "--require-blocked-count", "0"]; io=count_assertion_output) == 0
    @test occursin("Toolkit", String(take!(count_assertion_output)))

    ready_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--require-ready", "--family", "toolkit"]; io=ready_output) == 0
    @test occursin("Toolkit", String(take!(ready_output)))

    mktempdir() do directory
        blocked_ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            blocked_ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Toolkit\tdocs/MISSING.md\texamples/toolkit_quickstart.jl\tToolkit\tElement,ToolkitPilot,Button\tToolkit.ToolkitTree,Toolkit.Element,ToolkitPilot\tCovered for Toolkit.",
                ],
                "\n",
            ),
        )
        blocked_error = IOBuffer()
        blocked_output = joinpath(directory, "blocked.md")
        @test WidgetFamilyCloseoutRender.main(["--require-ready", "--family", "toolkit", "--columns", "family,status,blockers,blocker_details", "--output", blocked_output]; err=blocked_error, ledger=blocked_ledger) == 1
        @test occursin("blocked families: Toolkit", String(take!(blocked_error)))
        @test occursin("| Toolkit | blocked |", read(blocked_output, String))
        @test occursin("references missing documentation path", read(blocked_output, String))

        blocked_filter_output = IOBuffer()
        @test WidgetFamilyCloseoutRender.main(["--status", "blocked", "--columns", "family,status"]; io=blocked_filter_output, ledger=blocked_ledger) == 0
        @test occursin("| Toolkit | blocked |", String(take!(blocked_filter_output)))

        ready_filter_output = IOBuffer()
        @test WidgetFamilyCloseoutRender.main(["--status", "ready", "--count"]; io=ready_filter_output, ledger=blocked_ledger) == 0
        @test strip(String(take!(ready_filter_output))) == "0"
    end

    ready_count_error = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--family", "toolkit", "--require-ready-count", "0"]; err=ready_count_error) == 1
    @test occursin("expected 0 ready families, got 1", String(take!(ready_count_error)))

    mktempdir() do directory
        total_count_error = IOBuffer()
        total_count_output = joinpath(directory, "total-count-output.md")
        @test WidgetFamilyCloseoutRender.main(["--family", "toolkit", "--require-total-count", "2", "--output", total_count_output]; err=total_count_error) == 1
        @test occursin("expected 2 total families, got 1", String(take!(total_count_error)))
        @test occursin("Toolkit", read(total_count_output, String))
    end

    invalid_total_count_error = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--require-total-count", "bad"]; err=invalid_total_count_error) == 2
    @test occursin("--require-total-count requires a non-negative integer", String(take!(invalid_total_count_error)))

    invalid_status_error = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--status", "unknown"]; err=invalid_status_error) == 2
    @test occursin("--status must be ready, blocked, or all", String(take!(invalid_status_error)))

    invalid_ready_count_error = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--require-ready-count", "-1"]; err=invalid_ready_count_error) == 2
    @test occursin("--require-ready-count requires a non-negative integer", String(take!(invalid_ready_count_error)))

    invalid_blocked_count_error = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--require-blocked-count", "nope"]; err=invalid_blocked_count_error) == 2
    @test occursin("--require-blocked-count requires a non-negative integer", String(take!(invalid_blocked_count_error)))

    invalid_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--columns", "family,missing"]; err=invalid_output) == 2
    @test occursin("family closeout column must be one of", String(take!(invalid_output)))

    invalid_header_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--format", "json", "--no-header"]; err=invalid_header_output) == 2
    @test occursin("--no-header requires --format tsv", String(take!(invalid_header_output)))

    invalid_summary_output = IOBuffer()
    @test WidgetFamilyCloseoutRender.main(["--count", "--summary"]; err=invalid_summary_output) == 2
    @test occursin("--count and --summary are mutually exclusive", String(take!(invalid_summary_output)))
end
