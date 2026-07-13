include(joinpath(@__DIR__, "..", "scripts", "render_widget_catalog.jl"))

@testset "widget catalog render script" begin
    help_output = IOBuffer()
    @test WidgetCatalogRender.main(["--help"]; io=help_output) == 0
    help = String(take!(help_output))
    @test occursin("render_widget_catalog.jl", help)
    @test occursin("--require-clean-git", help)
    @test occursin("--stability", help)
    @test occursin("--stability-gaps", help)
    @test occursin("--stability-summary", help)
    @test occursin("--stability-status", help)
    @test occursin("--stability-json", help)
    @test occursin("--stabilization-status", help)
    @test occursin("--stabilization-blockers", help)
    @test occursin("--stabilization-json", help)
    @test occursin("--surface-release-status", help)
    @test occursin("--surface-release-json", help)
    @test occursin("--vocabulary", help)
    @test occursin("--vocabulary-widgets", help)
    @test occursin("--require-stability-ready", help)
    @test occursin("--require-stabilization-ready", help)
    @test occursin("--require-surface-release-ready", help)
    @test WidgetCatalogRender.parse_arguments(["--coverage-status", "--require-clean-git"]).require_clean_git
    @test WidgetCatalogRender.parse_arguments(["--stability", "--require-stability-ready"]).require_stability_ready
    @test WidgetCatalogRender.parse_arguments(["--stabilization-status", "--require-stabilization-ready"]).require_stabilization_ready
    @test WidgetCatalogRender.parse_arguments(["--surface-release-status", "--require-surface-release-ready"]).require_surface_release_ready
    combined_release_options = WidgetCatalogRender.parse_arguments(["--coverage-status", "--require-complete-coverage", "--require-clean-git"])
    @test combined_release_options.require_complete_coverage
    @test combined_release_options.require_clean_git

    output = IOBuffer()
    @test WidgetCatalogRender.main(["--columns", "name,status"]; io=output) == 0
    markdown = String(take!(output))
    @test startswith(markdown, "| `name` | `status` |")
    @test occursin("| Button | stable |", markdown)

    tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--format", "tsv", "--columns", "name,status"]; io=tsv_output) == 0
    tsv = String(take!(tsv_output))
    @test startswith(tsv, "name\tstatus\n")
    @test occursin("Button\tstable", tsv)

    tsv_no_header_output = IOBuffer()
    @test WidgetCatalogRender.main(["--format", "tsv", "--no-header", "--columns", "name,status"]; io=tsv_no_header_output) == 0
    tsv_no_header = String(take!(tsv_no_header_output))
    @test !startswith(tsv_no_header, "name\tstatus")
    @test occursin("Button\tstable", tsv_no_header)

    count_output = IOBuffer()
    @test WidgetCatalogRender.main(["--count"]; io=count_output) == 0
    @test parse(Int, strip(String(take!(count_output)))) > 0

    query_count_output = IOBuffer()
    @test WidgetCatalogRender.main(["--count", "--query", "button"]; io=query_count_output) == 0
    @test parse(Int, strip(String(take!(query_count_output)))) > 0

    min_count_output = IOBuffer()
    @test WidgetCatalogRender.main(["--query", "button", "--min-count", "1", "--columns", "name"]; io=min_count_output) == 0
    @test occursin("| Button |", String(take!(min_count_output)))

    max_count_output = IOBuffer()
    @test WidgetCatalogRender.main(["--query", "definitely-not-a-widget", "--max-count", "0"]; io=max_count_output) == 0
    @test startswith(String(take!(max_count_output)), "| `name` |")

    names_output = IOBuffer()
    @test WidgetCatalogRender.main(["--names"]; io=names_output) == 0
    names = String(take!(names_output))
    @test occursin("Button", names)
    @test !occursin('\t', names)

    query_names_output = IOBuffer()
    @test WidgetCatalogRender.main(["--names", "--query", "button"]; io=query_names_output) == 0
    query_names = String(take!(query_names_output))
    @test occursin("Button", query_names)
    @test !occursin('\t', query_names)

    sources_output = IOBuffer()
    @test WidgetCatalogRender.main(["--sources"]; io=sources_output) == 0
    sources = String(take!(sources_output))
    @test occursin(".jl", sources)
    @test !occursin('\t', sources)

    families_output = IOBuffer()
    @test WidgetCatalogRender.main(["--families"]; io=families_output) == 0
    families = String(take!(families_output))
    @test occursin("Inputs and controls", families)
    @test !occursin('\t', families)

    family_slugs_output = IOBuffer()
    @test WidgetCatalogRender.main(["--family-slugs"]; io=family_slugs_output) == 0
    family_slugs = String(take!(family_slugs_output))
    @test occursin("inputs-and-controls", family_slugs)
    @test !occursin('\t', family_slugs)

    query_sources_output = IOBuffer()
    @test WidgetCatalogRender.main(["--sources", "--query", "button"]; io=query_sources_output) == 0
    query_sources = String(take!(query_sources_output))
    @test occursin(".jl", query_sources)
    @test !occursin('\t', query_sources)

    query_output = IOBuffer()
    @test WidgetCatalogRender.main(["--query", "button", "--columns", "name"]; io=query_output) == 0
    query_markdown = String(take!(query_output))
    @test startswith(query_markdown, "| `name` |")
    @test occursin("| Button |", query_markdown)

    family_slug_query_output = IOBuffer()
    @test WidgetCatalogRender.main(["--query", "inputs-and-controls", "--columns", "name,family_slug"]; io=family_slug_query_output) == 0
    family_slug_query = String(take!(family_slug_query_output))
    @test startswith(family_slug_query, "| `name` | `family_slug` |")
    @test occursin("| Button | inputs-and-controls |", family_slug_query)

    family_output = IOBuffer()
    @test WidgetCatalogRender.main(["--family", "Inputs and controls", "--columns", "name,family,family_slug"]; io=family_output) == 0
    family_markdown = String(take!(family_output))
    @test occursin("| Button | Inputs and controls | inputs-and-controls |", family_markdown)

    family_count_output = IOBuffer()
    @test WidgetCatalogRender.main(["--count", "--family", "inputs-and-controls"]; io=family_count_output) == 0
    @test parse(Int, strip(String(take!(family_count_output)))) > 0

    summary_output = IOBuffer()
    @test WidgetCatalogRender.main(["--summary"]; io=summary_output) == 0
    summary_markdown = String(take!(summary_output))
    @test startswith(summary_markdown, "| `metric` | `key` | `count` |")
    @test occursin("| total | all |", summary_markdown)
    @test occursin("| family_slug | inputs-and-controls |", summary_markdown)

    summary_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--summary", "--format", "tsv"]; io=summary_tsv_output) == 0
    summary_tsv = String(take!(summary_tsv_output))
    @test startswith(summary_tsv, "metric\tkey\tcount\n")
    @test occursin("total\tall\t", summary_tsv)

    summary_tsv_no_header_output = IOBuffer()
    @test WidgetCatalogRender.main(["--summary", "--format", "tsv", "--no-header"]; io=summary_tsv_no_header_output) == 0
    @test !startswith(String(take!(summary_tsv_no_header_output)), "metric\tkey\tcount")

    source_summary_output = IOBuffer()
    @test WidgetCatalogRender.main(["--source-summary"]; io=source_summary_output) == 0
    source_summary = String(take!(source_summary_output))
    @test startswith(source_summary, "| `source` | `count` | `widgets` |")
    @test occursin("Button", source_summary)

    source_summary_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--source-summary", "--format", "tsv", "--no-header"]; io=source_summary_tsv_output) == 0
    source_summary_tsv = String(take!(source_summary_tsv_output))
    @test !startswith(source_summary_tsv, "source\tcount\twidgets")
    @test occursin("Button", source_summary_tsv)

    family_summary_output = IOBuffer()
    @test WidgetCatalogRender.main(["--family-summary"]; io=family_summary_output) == 0
    family_summary = String(take!(family_summary_output))
    @test startswith(family_summary, "| `family` | `count` | `widgets` |")
    @test occursin("Inputs and controls", family_summary)

    family_summary_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--family-summary", "--format", "tsv", "--no-header"]; io=family_summary_tsv_output) == 0
    family_summary_tsv = String(take!(family_summary_tsv_output))
    @test !startswith(family_summary_tsv, "family\tcount\twidgets")
    @test occursin("Inputs and controls", family_summary_tsv)

    filtered_family_summary_output = IOBuffer()
    @test WidgetCatalogRender.main(["--family-summary", "--family", "Inputs and controls"]; io=filtered_family_summary_output) == 0
    filtered_family_summary = String(take!(filtered_family_summary_output))
    @test occursin("Inputs and controls", filtered_family_summary)

    family_catalog_output = IOBuffer()
    @test WidgetCatalogRender.main(["--family-catalog"]; io=family_catalog_output) == 0
    family_catalog = String(take!(family_catalog_output))
    @test startswith(family_catalog, "| `family` | `family_slug` | `count` | `widgets` |")
    @test occursin("| Inputs and controls | inputs-and-controls |", family_catalog)

    family_catalog_columns_output = IOBuffer()
    @test WidgetCatalogRender.main(["--family-catalog", "--columns", "family_slug,count"]; io=family_catalog_columns_output) == 0
    family_catalog_columns = String(take!(family_catalog_columns_output))
    @test startswith(family_catalog_columns, "| `family_slug` | `count` |")
    @test occursin("| inputs-and-controls |", family_catalog_columns)

    family_catalog_query_output = IOBuffer()
    @test WidgetCatalogRender.main(["--family-catalog", "--query", "button", "--columns", "family_slug,count"]; io=family_catalog_query_output) == 0
    family_catalog_query = String(take!(family_catalog_query_output))
    @test startswith(family_catalog_query, "| `family_slug` | `count` |")
    @test occursin("| inputs-and-controls |", family_catalog_query)

    coverage_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage"]; io=coverage_output) == 0
    coverage = String(take!(coverage_output))
    @test startswith(coverage, "| `name` | `family` | `issue` | `missing_checks` |")
    @test occursin("| Button | Inputs and controls |", coverage)

    coverage_columns_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage", "--columns", "name,complete,issue"]; io=coverage_columns_output) == 0
    coverage_columns = String(take!(coverage_columns_output))
    @test startswith(coverage_columns, "| `name` | `complete` | `issue` |")
    @test occursin("| Button |", coverage_columns)

    coverage_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage", "--format", "tsv", "--columns", "name,issue", "--no-header"]; io=coverage_tsv_output) == 0
    coverage_tsv = String(take!(coverage_tsv_output))
    @test !startswith(coverage_tsv, "name\tissue")
    @test occursin("Button\t", coverage_tsv)

    coverage_gaps_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-gaps", "--family", "inputs-and-controls"]; io=coverage_gaps_output) == 0
    coverage_gaps = String(take!(coverage_gaps_output))
    @test startswith(coverage_gaps, "| `name` | `family` | `issue` | `missing_checks` |")

    stability_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stability"]; io=stability_output) == 0
    stability = String(take!(stability_output))
    @test startswith(stability, "| `name` | `family` | `ready` | `blockers` |")
    @test occursin("| Button | Inputs and controls |", stability)

    stability_columns_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stability", "--columns", "name,ready,blockers"]; io=stability_columns_output) == 0
    stability_columns = String(take!(stability_columns_output))
    @test startswith(stability_columns, "| `name` | `ready` | `blockers` |")

    stability_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stability", "--format", "tsv", "--columns", "name,ready", "--no-header"]; io=stability_tsv_output) == 0
    stability_tsv = String(take!(stability_tsv_output))
    @test !startswith(stability_tsv, "name\tready")
    @test occursin("Button\t", stability_tsv)

    stability_gaps_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-gaps", "--family", "inputs-and-controls"]; io=stability_gaps_output) == 0
    stability_gaps = String(take!(stability_gaps_output))
    @test startswith(stability_gaps, "| `name` | `family` | `ready` | `blockers` |")

    stability_summary_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-summary"]; io=stability_summary_output) == 0
    stability_summary = String(take!(stability_summary_output))
    @test startswith(stability_summary, "| `metric` | `key` | `count` |")
    @test occursin("| total | all |", stability_summary)

    stability_summary_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-summary", "--format", "tsv", "--no-header"]; io=stability_summary_tsv_output) == 0
    stability_summary_tsv = String(take!(stability_summary_tsv_output))
    @test !startswith(stability_summary_tsv, "metric\tkey\tcount")
    @test occursin("total\tall\t", stability_summary_tsv)

    stability_status_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-status"]; io=stability_status_output) == 0
    stability_status = String(take!(stability_status_output))
    @test occursin("total=", stability_status)
    @test occursin("blocked=", stability_status)

    stability_json_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-json"]; io=stability_json_output) == 0
    stability_json = String(take!(stability_json_output))
    @test occursin("\"schema_version\": 1", stability_json)
    @test occursin("\"summary\"", stability_json)
    @test occursin("\"rows\": [", stability_json)

    stabilization_status_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stabilization-status"]; io=stabilization_status_output) == 0
    stabilization_status = String(take!(stabilization_status_output))
    @test occursin("candidate_widgets=", stabilization_status)
    @test occursin("experimental_widgets=", stabilization_status)

    stabilization_blockers_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stabilization-blockers"]; io=stabilization_blockers_output) == 0
    @test String(take!(stabilization_blockers_output)) isa String

    stabilization_json_output = IOBuffer()
    @test WidgetCatalogRender.main(["--stabilization-json"]; io=stabilization_json_output) == 0
    stabilization_json = String(take!(stabilization_json_output))
    @test occursin("\"schema_version\": 1", stabilization_json)
    @test occursin("\"candidate_widget_count\":", stabilization_json)
    @test occursin("\"experimental_widget_count\":", stabilization_json)

    surface_release_status_output = IOBuffer()
    @test WidgetCatalogRender.main(["--surface-release-status"]; io=surface_release_status_output) == 0
    surface_release_status = String(take!(surface_release_status_output))
    @test occursin("release_ready=", surface_release_status)
    @test occursin("coverage_release_ready=", surface_release_status)
    @test occursin("stability_complete=", surface_release_status)
    @test occursin("family_closeout_complete=", surface_release_status)

    surface_release_json_output = IOBuffer()
    @test WidgetCatalogRender.main(["--surface-release-json"]; io=surface_release_json_output) == 0
    surface_release_json = String(take!(surface_release_json_output))
    @test occursin("\"schema_version\": 1", surface_release_json)
    @test occursin("\"release_ready\":", surface_release_json)
    @test occursin("\"coverage_release_ready\":", surface_release_json)
    @test occursin("\"stability_complete\":", surface_release_json)
    @test occursin("\"family_closeout_complete\":", surface_release_json)

    vocabulary_output = IOBuffer()
    @test WidgetCatalogRender.main(["--vocabulary"]; io=vocabulary_output) == 0
    vocabulary = String(take!(vocabulary_output))
    @test startswith(vocabulary, "| `concept` | `widgets` | `state_contracts` |")
    @test occursin("| Button |", vocabulary)
    @test occursin("| Divider or separator |", vocabulary)
    @test occursin("Divider", vocabulary)

    vocabulary_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--vocabulary", "--format", "tsv", "--no-header"]; io=vocabulary_tsv_output) == 0
    vocabulary_tsv = String(take!(vocabulary_tsv_output))
    @test !startswith(vocabulary_tsv, "concept\twidgets\tstate_contracts")
    @test occursin("Button\t", vocabulary_tsv)

    vocabulary_widgets_output = IOBuffer()
    @test WidgetCatalogRender.main(["--vocabulary-widgets", "--query", "Button"]; io=vocabulary_widgets_output) == 0
    vocabulary_widgets = String(take!(vocabulary_widgets_output))
    @test occursin("Button", vocabulary_widgets)
    @test !occursin('\t', vocabulary_widgets)

    divider_vocabulary_widgets_output = IOBuffer()
    @test WidgetCatalogRender.main(["--vocabulary-widgets", "--query", "Divider or separator"]; io=divider_vocabulary_widgets_output) == 0
    divider_vocabulary_widgets = String(take!(divider_vocabulary_widgets_output))
    @test occursin("Divider", divider_vocabulary_widgets)
    @test occursin("Separator", divider_vocabulary_widgets)

    coverage_issue_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-issue", "missing_checks", "--columns", "name,issue"]; io=coverage_issue_output) == 0
    coverage_issue = String(take!(coverage_issue_output))
    @test startswith(coverage_issue, "| `name` | `issue` |")

    coverage_issue_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-issue", "source_mismatch", "--format", "tsv", "--columns", "name,issue", "--no-header"]; io=coverage_issue_tsv_output) == 0
    @test !startswith(String(take!(coverage_issue_tsv_output)), "name\tissue")

    coverage_issue_names_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-issue-names", "missing_checks"]; io=coverage_issue_names_output) == 0
    @test !occursin('\t', String(take!(coverage_issue_names_output)))

    coverage_summary_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-summary"]; io=coverage_summary_output) == 0
    coverage_summary = String(take!(coverage_summary_output))
    @test startswith(coverage_summary, "| `metric` | `key` | `count` |")
    @test occursin("| total | all |", coverage_summary)

    coverage_summary_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-summary", "--format", "tsv", "--no-header"]; io=coverage_summary_tsv_output) == 0
    coverage_summary_tsv = String(take!(coverage_summary_tsv_output))
    @test !startswith(coverage_summary_tsv, "metric\tkey\tcount")
    @test occursin("total\tall\t", coverage_summary_tsv)

    coverage_summary_json_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-summary-json"]; io=coverage_summary_json_output) == 0
    coverage_summary_json = String(take!(coverage_summary_json_output))
    @test occursin("\"schema_version\": 1", coverage_summary_json)
    @test occursin("\"metadata\"", coverage_summary_json)
    @test occursin("\"generated_at\"", coverage_summary_json)
    @test occursin("\"root\"", coverage_summary_json)
    @test occursin("\"summary\"", coverage_summary_json)
    coverage_schema_source = read(joinpath(@__DIR__, "..", "docs", "evidence", "stable_widget_coverage.schema.json"), String)
    @test occursin("\"git_commit\"", coverage_schema_source)
    @test occursin("\"git_dirty\"", coverage_schema_source)

    coverage_status_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-status"]; io=coverage_status_output) == 0
    coverage_status = String(take!(coverage_status_output))
    @test occursin("total=", coverage_status)
    @test occursin("incomplete=", coverage_status)
    release_coverage_status_output = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-status", "--require-clean-git"]; io=release_coverage_status_output) == 0
    @test occursin("release_ready=", String(take!(release_coverage_status_output)))

    require_coverage_output = IOBuffer()
    require_coverage_error = IOBuffer()
    require_coverage_status = WidgetCatalogRender.main(["--coverage-summary", "--require-complete-coverage"]; io=require_coverage_output, err=require_coverage_error)
    @test require_coverage_status == (isempty(widget_coverage_gaps()) ? 0 : 1)
    if require_coverage_status == 0
        @test occursin("total", String(take!(require_coverage_output)))
    else
        @test occursin("expected complete stable widget coverage evidence", String(take!(require_coverage_error)))
    end

    require_stability_output = IOBuffer()
    require_stability_error = IOBuffer()
    require_stability_status = WidgetCatalogRender.main(["--stability", "--require-stability-ready"]; io=require_stability_output, err=require_stability_error)
    @test require_stability_status == (isempty(widget_stability_gaps()) ? 0 : 1)
    if require_stability_status == 0
        @test occursin("ready", String(take!(require_stability_output)))
    else
        @test occursin("expected promotion-ready stable widgets", String(take!(require_stability_error)))
    end

    require_stabilization_output = IOBuffer()
    require_stabilization_error = IOBuffer()
    require_stabilization_status = WidgetCatalogRender.main(["--stabilization-status", "--require-stabilization-ready"]; io=require_stabilization_output, err=require_stabilization_error)
    @test require_stabilization_status == (widget_stabilization_status_record().ready ? 0 : 1)
    if require_stabilization_status == 0
        @test occursin("ready=", String(take!(require_stabilization_output)))
    else
        @test occursin("expected stabilization-ready widget surface", String(take!(require_stabilization_error)))
    end

    require_surface_release_output = IOBuffer()
    require_surface_release_error = IOBuffer()
    require_surface_release_status = WidgetCatalogRender.main(["--surface-release-status", "--require-surface-release-ready"]; io=require_surface_release_output, err=require_surface_release_error)
    @test require_surface_release_status == (widget_surface_release_ready(; root=WidgetCatalogRender.ROOT) ? 0 : 1)
    if require_surface_release_status == 0
        @test occursin("release_ready=", String(take!(require_surface_release_output)))
    else
        @test occursin("expected release-ready stable widget surface", String(take!(require_surface_release_error)))
    end

    filtered_family_catalog_tsv_output = IOBuffer()
    @test WidgetCatalogRender.main(["--family-catalog", "--family", "inputs-and-controls", "--format", "tsv", "--columns", "family_slug,count", "--no-header"]; io=filtered_family_catalog_tsv_output) == 0
    filtered_family_catalog_tsv = String(take!(filtered_family_catalog_tsv_output))
    @test !startswith(filtered_family_catalog_tsv, "family_slug\tcount")
    @test occursin("inputs-and-controls\t", filtered_family_catalog_tsv)

    query_summary_output = IOBuffer()
    @test WidgetCatalogRender.main(["--summary", "--query", "button", "--format", "tsv"]; io=query_summary_output) == 0
    @test occursin("total\tall\t", String(take!(query_summary_output)))

    all_output = IOBuffer()
    @test WidgetCatalogRender.main(["--status", "all", "--surface", "all", "--columns", "name"]; io=all_output) == 0
    @test startswith(String(take!(all_output)), "| `name` |")

    mktempdir() do directory
        output_path = joinpath(directory, "catalog", "widgets.md")
        @test WidgetCatalogRender.main(["--columns", "name", "--output", output_path]) == 0
        @test startswith(read(output_path, String), "| `name` |")

        @test WidgetCatalogRender.main(["--summary", "--output", output_path, "--append"]) == 0
        appended = read(output_path, String)
        @test occursin("| `name` |", appended)
        @test occursin("| `metric` | `key` | `count` |", appended)
    end

    error_output = IOBuffer()
    @test WidgetCatalogRender.main(["--columns", "name,"]; err=error_output) == 2
    @test occursin("--columns cannot contain empty column names", String(take!(error_output)))

    format_error = IOBuffer()
    @test WidgetCatalogRender.main(["--format", "json"]; err=format_error) == 2
    @test occursin("--format must be markdown or tsv", String(take!(format_error)))

    missing_output_error = IOBuffer()
    @test WidgetCatalogRender.main(["--output", ""]; err=missing_output_error) == 2
    @test occursin("--output requires a non-empty file path", String(take!(missing_output_error)))

    missing_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--query", ""]; err=missing_query_error) == 2
    @test occursin("--query requires a non-empty search string", String(take!(missing_query_error)))

    min_count_error = IOBuffer()
    @test WidgetCatalogRender.main(["--query", "definitely-not-a-widget", "--min-count", "1"]; err=min_count_error) == 1
    @test occursin("expected at least 1 matching widgets, got 0", String(take!(min_count_error)))

    invalid_min_count_error = IOBuffer()
    @test WidgetCatalogRender.main(["--min-count", "-1"]; err=invalid_min_count_error) == 2
    @test occursin("--min-count requires a non-negative integer", String(take!(invalid_min_count_error)))

    max_count_error = IOBuffer()
    @test WidgetCatalogRender.main(["--query", "button", "--max-count", "0"]; err=max_count_error) == 1
    @test occursin("expected at most 0 matching widgets", String(take!(max_count_error)))

    invalid_max_count_error = IOBuffer()
    @test WidgetCatalogRender.main(["--max-count", "-1"]; err=invalid_max_count_error) == 2
    @test occursin("--max-count requires a non-negative integer", String(take!(invalid_max_count_error)))

    append_error = IOBuffer()
    @test WidgetCatalogRender.main(["--append"]; err=append_error) == 2
    @test occursin("--append requires --output", String(take!(append_error)))

    mode_error = IOBuffer()
    @test WidgetCatalogRender.main(["--summary", "--source-summary"]; err=mode_error) == 2
    @test occursin("--count, --names, --sources, --families, --family-slugs, --summary, --source-summary, --family-summary, --family-catalog, --coverage, --coverage-gaps, --coverage-summary, --coverage-summary-json, --coverage-status, --coverage-issue, --coverage-issue-names, --stability, --stability-gaps, --stability-summary, --stability-status, --stability-json, --stabilization-status, --stabilization-blockers, --stabilization-json, --surface-release-status, --surface-release-json, --vocabulary, and --vocabulary-widgets are mutually exclusive", String(take!(mode_error)))

    source_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--source-summary", "--query", "button"]; err=source_query_error) == 2
    @test occursin("--query cannot be used with --source-summary", String(take!(source_query_error)))

    family_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--family-summary", "--query", "button"]; err=family_query_error) == 2
    @test occursin("--query cannot be used with --family-summary", String(take!(family_query_error)))

    stability_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stability", "--query", "button"]; err=stability_query_error) == 2
    @test occursin("--query cannot be used with --stability or --stability-gaps", String(take!(stability_query_error)))

    stability_json_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-json", "--query", "button"]; err=stability_json_query_error) == 2
    @test occursin("--query cannot be used with --stability-json", String(take!(stability_json_query_error)))

    stability_json_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-json", "--columns", "name"]; err=stability_json_columns_error) == 2
    @test occursin("--columns cannot be used with --stability-json", String(take!(stability_json_columns_error)))

    stability_summary_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-summary", "--query", "button"]; err=stability_summary_query_error) == 2
    @test occursin("--query cannot be used with --stability-summary", String(take!(stability_summary_query_error)))

    stability_summary_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-summary", "--columns", "name"]; err=stability_summary_columns_error) == 2
    @test occursin("--columns cannot be used with --stability-summary", String(take!(stability_summary_columns_error)))

    stability_status_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-status", "--query", "button"]; err=stability_status_query_error) == 2
    @test occursin("--query cannot be used with --stability-status", String(take!(stability_status_query_error)))

    stability_status_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stability-status", "--columns", "name"]; err=stability_status_columns_error) == 2
    @test occursin("--columns cannot be used with --stability-status", String(take!(stability_status_columns_error)))

    stabilization_status_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stabilization-status", "--query", "button"]; err=stabilization_status_query_error) == 2
    @test occursin("--query cannot be used with --stabilization-status", String(take!(stabilization_status_query_error)))

    stabilization_status_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stabilization-status", "--columns", "name"]; err=stabilization_status_columns_error) == 2
    @test occursin("--columns cannot be used with --stabilization-status", String(take!(stabilization_status_columns_error)))

    stabilization_blockers_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stabilization-blockers", "--query", "button"]; err=stabilization_blockers_query_error) == 2
    @test occursin("--query cannot be used with --stabilization-blockers", String(take!(stabilization_blockers_query_error)))

    stabilization_blockers_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stabilization-blockers", "--columns", "name"]; err=stabilization_blockers_columns_error) == 2
    @test occursin("--columns cannot be used with --stabilization-blockers", String(take!(stabilization_blockers_columns_error)))

    stabilization_json_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stabilization-json", "--query", "button"]; err=stabilization_json_query_error) == 2
    @test occursin("--query cannot be used with --stabilization-json", String(take!(stabilization_json_query_error)))

    stabilization_json_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--stabilization-json", "--columns", "name"]; err=stabilization_json_columns_error) == 2
    @test occursin("--columns cannot be used with --stabilization-json", String(take!(stabilization_json_columns_error)))

    surface_release_status_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--surface-release-status", "--query", "button"]; err=surface_release_status_query_error) == 2
    @test occursin("--query cannot be used with --surface-release-status", String(take!(surface_release_status_query_error)))

    surface_release_status_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--surface-release-status", "--columns", "name"]; err=surface_release_status_columns_error) == 2
    @test occursin("--columns cannot be used with --surface-release-status", String(take!(surface_release_status_columns_error)))

    surface_release_json_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--surface-release-json", "--query", "button"]; err=surface_release_json_query_error) == 2
    @test occursin("--query cannot be used with --surface-release-json", String(take!(surface_release_json_query_error)))

    surface_release_json_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--surface-release-json", "--columns", "name"]; err=surface_release_json_columns_error) == 2
    @test occursin("--columns cannot be used with --surface-release-json", String(take!(surface_release_json_columns_error)))

    vocabulary_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--vocabulary", "--query", "button"]; err=vocabulary_query_error) == 2
    @test occursin("--query cannot be used with --vocabulary", String(take!(vocabulary_query_error)))

    vocabulary_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--vocabulary", "--columns", "name"]; err=vocabulary_columns_error) == 2
    @test occursin("--columns cannot be used with --vocabulary", String(take!(vocabulary_columns_error)))

    vocabulary_widgets_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--vocabulary-widgets"]; err=vocabulary_widgets_query_error) == 2
    @test occursin("--vocabulary-widgets requires --query", String(take!(vocabulary_widgets_query_error)))

    vocabulary_widgets_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--vocabulary-widgets", "--query", "Button", "--columns", "name"]; err=vocabulary_widgets_columns_error) == 2
    @test occursin("--columns cannot be used with --vocabulary-widgets", String(take!(vocabulary_widgets_columns_error)))

    family_catalog_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--family-catalog", "--query", "button", "--family", "inputs-and-controls"]; err=family_catalog_query_error) == 2
    @test occursin("--family cannot be used with --query for --family-catalog", String(take!(family_catalog_query_error)))

    names_mode_error = IOBuffer()
    @test WidgetCatalogRender.main(["--names", "--summary"]; err=names_mode_error) == 2
    @test occursin("--count, --names, --sources, --families, --family-slugs, --summary, --source-summary, --family-summary, --family-catalog, --coverage, --coverage-gaps, --coverage-summary, --coverage-summary-json, --coverage-status, --coverage-issue, --coverage-issue-names, --stability, --stability-gaps, --stability-summary, --stability-status, --stability-json, --stabilization-status, --stabilization-blockers, --stabilization-json, --surface-release-status, --surface-release-json, --vocabulary, and --vocabulary-widgets are mutually exclusive", String(take!(names_mode_error)))

    coverage_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage", "--query", "button"]; err=coverage_query_error) == 2
    @test occursin("--query cannot be used with --coverage or --coverage-gaps", String(take!(coverage_query_error)))

    coverage_summary_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-summary", "--query", "button"]; err=coverage_summary_query_error) == 2
    @test occursin("--query cannot be used with --coverage-summary", String(take!(coverage_summary_query_error)))

    coverage_summary_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-summary", "--columns", "name"]; err=coverage_summary_columns_error) == 2
    @test occursin("--columns cannot be used with --coverage-summary", String(take!(coverage_summary_columns_error)))

    coverage_summary_json_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-summary-json", "--query", "button"]; err=coverage_summary_json_query_error) == 2
    @test occursin("--query cannot be used with --coverage-summary-json", String(take!(coverage_summary_json_query_error)))

    coverage_summary_json_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-summary-json", "--columns", "name"]; err=coverage_summary_json_columns_error) == 2
    @test occursin("--columns cannot be used with --coverage-summary-json", String(take!(coverage_summary_json_columns_error)))

    coverage_status_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-status", "--query", "button"]; err=coverage_status_query_error) == 2
    @test occursin("--query cannot be used with --coverage-status", String(take!(coverage_status_query_error)))

    coverage_status_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-status", "--columns", "name"]; err=coverage_status_columns_error) == 2
    @test occursin("--columns cannot be used with --coverage-status", String(take!(coverage_status_columns_error)))

    coverage_issue_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-issue", "missing_record", "--query", "button"]; err=coverage_issue_query_error) == 2
    @test occursin("--query cannot be used with --coverage-issue", String(take!(coverage_issue_query_error)))

    coverage_issue_value_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-issue", "missing"]; err=coverage_issue_value_error) == 2
    @test occursin("widget coverage issue must be one of", String(take!(coverage_issue_value_error)))

    coverage_issue_names_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-issue-names", "missing_record", "--query", "button"]; err=coverage_issue_names_query_error) == 2
    @test occursin("--query cannot be used with --coverage-issue-names", String(take!(coverage_issue_names_query_error)))

    coverage_issue_names_columns_error = IOBuffer()
    @test WidgetCatalogRender.main(["--coverage-issue-names", "missing_record", "--columns", "name"]; err=coverage_issue_names_columns_error) == 2
    @test occursin("--columns cannot be used with --coverage-issue-names", String(take!(coverage_issue_names_columns_error)))

    families_query_error = IOBuffer()
    @test WidgetCatalogRender.main(["--families", "--query", "button"]; err=families_query_error) == 2
    @test occursin("--query cannot be used with --families", String(take!(families_query_error)))

    family_slugs_filter_error = IOBuffer()
    @test WidgetCatalogRender.main(["--family-slugs", "--family", "inputs-and-controls"]; err=family_slugs_filter_error) == 2
    @test occursin("--family cannot be used with --family-slugs", String(take!(family_slugs_filter_error)))

    no_header_error = IOBuffer()
    @test WidgetCatalogRender.main(["--no-header"]; err=no_header_error) == 2
    @test occursin("--no-header requires --format tsv", String(take!(no_header_error)))

    count_no_header_error = IOBuffer()
    @test WidgetCatalogRender.main(["--count", "--format", "tsv", "--no-header"]; err=count_no_header_error) == 2
    @test occursin("--no-header cannot be used with --count", String(take!(count_no_header_error)))

    families_no_header_error = IOBuffer()
    @test WidgetCatalogRender.main(["--families", "--format", "tsv", "--no-header"]; err=families_no_header_error) == 2
    @test occursin("--no-header cannot be used with --families", String(take!(families_no_header_error)))
end
