#!/usr/bin/env julia

module WidgetCatalogRender

using Dates
using Wicked.API

const DEFAULT_COLUMNS = (:name, :source, :surface, :status, :reason)
const DEFAULT_COVERAGE_COLUMNS = (:name, :family, :issue, :missing_checks)
const DEFAULT_STABILITY_COLUMNS = (:name, :family, :ready, :blockers)
const ROOT = normpath(joinpath(@__DIR__, ".."))

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/render_widget_catalog.jl [--count|--names|--sources|--families|--family-slugs|--summary|--source-summary|--family-summary|--family-catalog|--coverage|--coverage-gaps|--coverage-summary|--coverage-summary-json|--coverage-status|--coverage-issue issue|--coverage-issue-names issue|--stability|--stability-gaps|--stability-summary|--stability-status|--stability-json|--stabilization-status|--stabilization-blockers|--stabilization-json|--surface-release-status|--surface-release-json|--vocabulary|--vocabulary-widgets] [--query text] [--format markdown|tsv] [--columns name,source,status] [--status stable|all] [--surface stable|all] [--family name|all] [--output path] [--append] [--no-header] [--min-count n] [--max-count n] [--require-complete-coverage] [--require-stability-ready] [--require-stabilization-ready] [--require-surface-release-ready] [--require-clean-git]")
    println(io, "")
    println(io, "Renders the reviewed widget catalog as Markdown or TSV.")
    println(io, "Use --query to render only matching widget or family catalog entries.")
    println(io, "Use --count to render a single matching widget count.")
    println(io, "Use --names to render newline-separated widget names.")
    println(io, "Use --sources to render newline-separated widget source files.")
    println(io, "Use --families to render newline-separated widget family names.")
    println(io, "Use --family-slugs to render newline-separated widget family slugs.")
    println(io, "Use --summary to render catalog counts instead of catalog rows.")
    println(io, "Use --source-summary to render source files, counts, and widget names.")
    println(io, "Use --family-summary to render widget families, counts, and widget names.")
    println(io, "Use --family-catalog to render family names, slugs, counts, and widget names.")
    println(io, "Use --coverage to render behavior-evidence coverage for stable widget catalog rows.")
    println(io, "Use --coverage-gaps to render only missing, incomplete, or source-mismatched evidence rows.")
    println(io, "Use --coverage-summary to render compact behavior-evidence summary counts.")
    println(io, "Use --coverage-summary-json to render versioned machine-readable behavior-evidence summary counts.")
    println(io, "Use --coverage-status to render one compact behavior-evidence status line.")
    println(io, "Use --coverage-issue to render one issue class: complete, missing_record, source_mismatch, or missing_checks.")
    println(io, "Use --coverage-issue-names to render newline-separated widget names for one issue class.")
    println(io, "Use --stability to render promotion-readiness reports for reviewed widgets.")
    println(io, "Use --stability-gaps to render only widgets that still have promotion blockers.")
    println(io, "Use --stability-summary to render compact promotion-readiness summary counts.")
    println(io, "Use --stability-status to render one compact promotion-readiness status line.")
    println(io, "Use --stability-json to render versioned machine-readable promotion-readiness reports.")
    println(io, "Use --stabilization-status to render one compact experimental/candidate closeout status line.")
    println(io, "Use --stabilization-blockers to render stabilization closeout blocker details.")
    println(io, "Use --stabilization-json to render machine-readable experimental/candidate closeout status.")
    println(io, "Use --surface-release-status to render one compact stable widget-surface release status line.")
    println(io, "Use --surface-release-json to render compact machine-readable stable widget-surface release status.")
    println(io, "Use --vocabulary to render the cross-framework widget vocabulary.")
    println(io, "Use --vocabulary-widgets with --query to render Wicked widget names for one source-framework concept.")
    println(io, "Use --status all or --surface all to disable the default stable filters.")
    println(io, "Use --family to restrict rows to one cross-library widget family.")
    println(io, "Use --min-count to fail when the filtered catalog has too few widgets.")
    println(io, "Use --max-count to fail when the filtered catalog has too many widgets.")
    println(io, "Use --require-complete-coverage to fail when stable widget evidence has gaps.")
    println(io, "Use --require-stability-ready to fail when any reviewed widget has promotion blockers.")
    println(io, "Use --require-stabilization-ready to fail when experimental, candidate, stability, or family closeout blockers remain.")
    println(io, "Use --require-surface-release-ready to fail unless coverage, stability, family closeout, and git metadata are release-ready.")
    println(io, "Use --require-clean-git to fail when git metadata is unavailable or dirty.")
    println(io, "Use --output to write the table to a file instead of stdout.")
    println(io, "Use --append with --output to append to an existing artifact.")
    println(io, "Use --no-header with --format tsv to omit the TSV header row.")
end

function parse_filter(value::AbstractString, label::AbstractString)
    isempty(strip(value)) && throw(ArgumentError("$label cannot be empty"))
    lowercase(strip(value)) == "all" && return nothing
    return Symbol(strip(value))
end

function parse_columns(value::AbstractString)
    parts = [strip(part) for part in split(value, ',')]
    any(isempty, parts) && throw(ArgumentError("--columns cannot contain empty column names"))
    return Tuple(Symbol.(parts))
end

function parse_format(value::AbstractString)
    format = Symbol(lowercase(strip(value)))
    format in (:markdown, :tsv) || throw(ArgumentError("--format must be markdown or tsv"))
    return format
end

function parse_arguments(arguments)
    columns = DEFAULT_COLUMNS
    columns_given = false
    status = :stable
    surface = :stable
    family = nothing
    output = nothing
    format = :markdown
    count = false
    summary = false
    source_summary = false
    family_summary = false
    family_catalog = false
    coverage = false
    coverage_gaps = false
    coverage_summary = false
    coverage_summary_json = false
    coverage_status = false
    coverage_issue = nothing
    coverage_issue_names = nothing
    stability = false
    stability_gaps = false
    stability_summary = false
    stability_status = false
    stability_json = false
    stabilization_status = false
    stabilization_blockers = false
    stabilization_json = false
    surface_release_status = false
    surface_release_json = false
    vocabulary = false
    vocabulary_widgets = false
    names = false
    sources = false
    families = false
    family_slugs = false
    query = nothing
    append = false
    header = true
    min_count = nothing
    max_count = nothing
    require_complete_coverage = false
    require_stability_ready = false
    require_stabilization_ready = false
    require_surface_release_ready = false
    require_clean_git = false
    index = firstindex(arguments)
    while index <= lastindex(arguments)
        argument = arguments[index]
        if argument == "--help" || argument == "-h"
            return (help=true, columns=columns, columns_given=columns_given, status=status, surface=surface, family=family, output=output, format=format, count=count, summary=summary, source_summary=source_summary, family_summary=family_summary, family_catalog=family_catalog, coverage=coverage, coverage_gaps=coverage_gaps, coverage_summary=coverage_summary, coverage_summary_json=coverage_summary_json, coverage_status=coverage_status, coverage_issue=coverage_issue, coverage_issue_names=coverage_issue_names, stability=stability, stability_gaps=stability_gaps, stability_summary=stability_summary, stability_status=stability_status, stability_json=stability_json, stabilization_status=stabilization_status, stabilization_blockers=stabilization_blockers, stabilization_json=stabilization_json, surface_release_status=surface_release_status, surface_release_json=surface_release_json, vocabulary=vocabulary, vocabulary_widgets=vocabulary_widgets, names=names, sources=sources, families=families, family_slugs=family_slugs, query=query, append=append, header=header, min_count=min_count, max_count=max_count, require_complete_coverage=require_complete_coverage, require_stability_ready=require_stability_ready, require_stabilization_ready=require_stabilization_ready, require_surface_release_ready=require_surface_release_ready, require_clean_git=require_clean_git)
        elseif argument == "--count"
            count = true
        elseif argument == "--names"
            names = true
        elseif argument == "--sources"
            sources = true
        elseif argument == "--families"
            families = true
        elseif argument == "--family-slugs"
            family_slugs = true
        elseif argument == "--summary"
            summary = true
        elseif argument == "--source-summary"
            source_summary = true
        elseif argument == "--family-summary"
            family_summary = true
        elseif argument == "--family-catalog"
            family_catalog = true
        elseif argument == "--coverage"
            coverage = true
        elseif argument == "--coverage-gaps"
            coverage_gaps = true
        elseif argument == "--coverage-summary"
            coverage_summary = true
        elseif argument == "--coverage-summary-json"
            coverage_summary_json = true
        elseif argument == "--coverage-status"
            coverage_status = true
        elseif argument == "--coverage-issue"
            index < lastindex(arguments) || throw(ArgumentError("--coverage-issue requires complete, missing_record, source_mismatch, or missing_checks"))
            index += 1
            coverage_issue = Symbol(strip(arguments[index]))
        elseif argument == "--coverage-issue-names"
            index < lastindex(arguments) || throw(ArgumentError("--coverage-issue-names requires complete, missing_record, source_mismatch, or missing_checks"))
            index += 1
            coverage_issue_names = Symbol(strip(arguments[index]))
        elseif argument == "--stability"
            stability = true
        elseif argument == "--stability-gaps"
            stability_gaps = true
        elseif argument == "--stability-summary"
            stability_summary = true
        elseif argument == "--stability-status"
            stability_status = true
        elseif argument == "--stability-json"
            stability_json = true
        elseif argument == "--stabilization-status"
            stabilization_status = true
        elseif argument == "--stabilization-blockers"
            stabilization_blockers = true
        elseif argument == "--stabilization-json"
            stabilization_json = true
        elseif argument == "--surface-release-status"
            surface_release_status = true
        elseif argument == "--surface-release-json"
            surface_release_json = true
        elseif argument == "--vocabulary"
            vocabulary = true
        elseif argument == "--vocabulary-widgets"
            vocabulary_widgets = true
        elseif argument == "--append"
            append = true
        elseif argument == "--no-header"
            header = false
        elseif argument == "--require-complete-coverage"
            require_complete_coverage = true
        elseif argument == "--require-stability-ready"
            require_stability_ready = true
        elseif argument == "--require-stabilization-ready"
            require_stabilization_ready = true
        elseif argument == "--require-surface-release-ready"
            require_surface_release_ready = true
        elseif argument == "--require-clean-git"
            require_clean_git = true
        elseif argument == "--query"
            index < lastindex(arguments) || throw(ArgumentError("--query requires a search string"))
            index += 1
            query = strip(arguments[index])
            isempty(query) && throw(ArgumentError("--query requires a non-empty search string"))
        elseif argument == "--min-count"
            index < lastindex(arguments) || throw(ArgumentError("--min-count requires a non-negative integer"))
            index += 1
            min_count = tryparse(Int, arguments[index])
            min_count === nothing && throw(ArgumentError("--min-count requires a non-negative integer"))
            min_count >= 0 || throw(ArgumentError("--min-count requires a non-negative integer"))
        elseif argument == "--max-count"
            index < lastindex(arguments) || throw(ArgumentError("--max-count requires a non-negative integer"))
            index += 1
            max_count = tryparse(Int, arguments[index])
            max_count === nothing && throw(ArgumentError("--max-count requires a non-negative integer"))
            max_count >= 0 || throw(ArgumentError("--max-count requires a non-negative integer"))
        elseif argument == "--format"
            index < lastindex(arguments) || throw(ArgumentError("--format requires markdown or tsv"))
            index += 1
            format = parse_format(arguments[index])
        elseif argument == "--columns"
            index < lastindex(arguments) || throw(ArgumentError("--columns requires a comma-separated value"))
            index += 1
            columns = parse_columns(arguments[index])
            columns_given = true
        elseif argument == "--status"
            index < lastindex(arguments) || throw(ArgumentError("--status requires stable or all"))
            index += 1
            status = parse_filter(arguments[index], "--status")
        elseif argument == "--surface"
            index < lastindex(arguments) || throw(ArgumentError("--surface requires stable or all"))
            index += 1
            surface = parse_filter(arguments[index], "--surface")
        elseif argument == "--family"
            index < lastindex(arguments) || throw(ArgumentError("--family requires a family name or all"))
            index += 1
            family = parse_filter(arguments[index], "--family")
        elseif argument == "--output"
            index < lastindex(arguments) || throw(ArgumentError("--output requires a file path"))
            index += 1
            output = strip(arguments[index])
            isempty(output) && throw(ArgumentError("--output requires a non-empty file path"))
        else
            throw(ArgumentError("unknown argument: $argument"))
        end
        index += 1
    end
    active_modes = (count ? 1 : 0) + (names ? 1 : 0) + (sources ? 1 : 0) + (families ? 1 : 0) + (family_slugs ? 1 : 0) + (summary ? 1 : 0) + (source_summary ? 1 : 0) + (family_summary ? 1 : 0) + (family_catalog ? 1 : 0) + (coverage ? 1 : 0) + (coverage_gaps ? 1 : 0) + (coverage_summary ? 1 : 0) + (coverage_summary_json ? 1 : 0) + (coverage_status ? 1 : 0) + (coverage_issue === nothing ? 0 : 1) + (coverage_issue_names === nothing ? 0 : 1) + (stability ? 1 : 0) + (stability_gaps ? 1 : 0) + (stability_summary ? 1 : 0) + (stability_status ? 1 : 0) + (stability_json ? 1 : 0) + (stabilization_status ? 1 : 0) + (stabilization_blockers ? 1 : 0) + (stabilization_json ? 1 : 0) + (surface_release_status ? 1 : 0) + (surface_release_json ? 1 : 0) + (vocabulary ? 1 : 0) + (vocabulary_widgets ? 1 : 0)
    active_modes <= 1 || throw(ArgumentError("--count, --names, --sources, --families, --family-slugs, --summary, --source-summary, --family-summary, --family-catalog, --coverage, --coverage-gaps, --coverage-summary, --coverage-summary-json, --coverage-status, --coverage-issue, --coverage-issue-names, --stability, --stability-gaps, --stability-summary, --stability-status, --stability-json, --stabilization-status, --stabilization-blockers, --stabilization-json, --surface-release-status, --surface-release-json, --vocabulary, and --vocabulary-widgets are mutually exclusive"))
    count && !header && throw(ArgumentError("--no-header cannot be used with --count"))
    names && !header && throw(ArgumentError("--no-header cannot be used with --names"))
    sources && !header && throw(ArgumentError("--no-header cannot be used with --sources"))
    families && !header && throw(ArgumentError("--no-header cannot be used with --families"))
    family_slugs && !header && throw(ArgumentError("--no-header cannot be used with --family-slugs"))
    coverage_status && !header && throw(ArgumentError("--no-header cannot be used with --coverage-status"))
    coverage_issue_names !== nothing && !header && throw(ArgumentError("--no-header cannot be used with --coverage-issue-names"))
    stability_status && !header && throw(ArgumentError("--no-header cannot be used with --stability-status"))
    stabilization_status && !header && throw(ArgumentError("--no-header cannot be used with --stabilization-status"))
    stabilization_blockers && !header && throw(ArgumentError("--no-header cannot be used with --stabilization-blockers"))
    surface_release_status && !header && throw(ArgumentError("--no-header cannot be used with --surface-release-status"))
    vocabulary_widgets && !header && throw(ArgumentError("--no-header cannot be used with --vocabulary-widgets"))
    append && output === nothing && throw(ArgumentError("--append requires --output"))
    !header && format !== :tsv && throw(ArgumentError("--no-header requires --format tsv"))
    return (help=false, columns=columns, columns_given=columns_given, status=status, surface=surface, family=family, output=output, format=format, count=count, summary=summary, source_summary=source_summary, family_summary=family_summary, family_catalog=family_catalog, coverage=coverage, coverage_gaps=coverage_gaps, coverage_summary=coverage_summary, coverage_summary_json=coverage_summary_json, coverage_status=coverage_status, coverage_issue=coverage_issue, coverage_issue_names=coverage_issue_names, stability=stability, stability_gaps=stability_gaps, stability_summary=stability_summary, stability_status=stability_status, stability_json=stability_json, stabilization_status=stabilization_status, stabilization_blockers=stabilization_blockers, stabilization_json=stabilization_json, surface_release_status=surface_release_status, surface_release_json=surface_release_json, vocabulary=vocabulary, vocabulary_widgets=vocabulary_widgets, names=names, sources=sources, families=families, family_slugs=family_slugs, query=query, append=append, header=header, min_count=min_count, max_count=max_count, require_complete_coverage=require_complete_coverage, require_stability_ready=require_stability_ready, require_stabilization_ready=require_stabilization_ready, require_surface_release_ready=require_surface_release_ready, require_clean_git=require_clean_git)
end

matching_widget_count(options) =
    options.vocabulary ?
        length(widget_vocabulary()) :
    options.vocabulary_widgets ?
        length(widget_vocabulary_widget_names(options.query)) :
    options.stability ?
        length(widget_stability_reports(; status=options.status, surface=options.surface, family=options.family)) :
    options.stability_gaps ?
        length(widget_stability_gaps(; status=options.status, surface=options.surface, family=options.family)) :
    options.stability_summary ?
        length(widget_stability_summary_records(; status=options.status, surface=options.surface, family=options.family)) :
    options.stability_status ?
        1 :
    options.stability_json ?
        length(widget_stability_reports(; status=options.status, surface=options.surface, family=options.family)) :
    options.stabilization_status ?
        1 :
    options.stabilization_blockers ?
        length(widget_stabilization_blockers(; family=options.family)) :
    options.stabilization_json ?
        1 :
    options.surface_release_status || options.surface_release_json ?
        1 :
    options.coverage ?
        length(widget_coverage_records(; status=options.status, surface=options.surface, family=options.family)) :
    options.coverage_gaps ?
        length(widget_coverage_gaps(; status=options.status, surface=options.surface, family=options.family)) :
    options.coverage_summary ?
        length(widget_coverage_summary_records(; status=options.status, surface=options.surface, family=options.family)) :
    options.coverage_summary_json ?
        length(widget_coverage_summary_records(; status=options.status, surface=options.surface, family=options.family)) :
    options.coverage_status ?
        1 :
    options.coverage_issue !== nothing ?
        widget_coverage_issue_count(options.coverage_issue; status=options.status, surface=options.surface, family=options.family) :
    options.coverage_issue_names !== nothing ?
        length(widget_coverage_issue_names(options.coverage_issue_names; status=options.status, surface=options.surface, family=options.family)) :
    options.query === nothing ?
        stable_widget_count(; status=options.status, surface=options.surface, family=options.family) :
        search_widget_count(options.query; status=options.status, surface=options.surface, family=options.family)

function render_catalog(options)
    options.count && return string(matching_widget_count(options))
    options.names && return options.query === nothing ?
        widget_names_text(; status=options.status, surface=options.surface, family=options.family) :
        search_widget_names_text(options.query; status=options.status, surface=options.surface, family=options.family)
    options.sources && return options.query === nothing ?
        widget_source_files_text(; status=options.status, surface=options.surface, family=options.family) :
        search_widget_source_files_text(options.query; status=options.status, surface=options.surface, family=options.family)
    options.families && return render_families(options)
    options.family_slugs && return render_family_slugs(options)
    options.summary && return render_summary(options)
    options.source_summary && return render_source_summary(options)
    options.family_summary && return render_family_summary(options)
    options.family_catalog && return render_family_catalog(options)
    options.coverage && return render_coverage(options; gaps=false)
    options.coverage_gaps && return render_coverage(options; gaps=true)
    options.coverage_summary && return render_coverage_summary(options)
    options.coverage_summary_json && return render_coverage_summary_json(options)
    options.coverage_status && return render_coverage_status(options)
    options.coverage_issue !== nothing && return render_coverage_issue(options)
    options.coverage_issue_names !== nothing && return render_coverage_issue_names(options)
    options.stability && return render_stability(options; gaps=false)
    options.stability_gaps && return render_stability(options; gaps=true)
    options.stability_summary && return render_stability_summary(options)
    options.stability_status && return render_stability_status(options)
    options.stability_json && return render_stability_json(options)
    options.stabilization_status && return render_stabilization_status(options)
    options.stabilization_blockers && return render_stabilization_blockers(options)
    options.stabilization_json && return render_stabilization_json(options)
    options.surface_release_status && return render_surface_release_status(options)
    options.surface_release_json && return render_surface_release_json(options)
    options.vocabulary && return render_vocabulary(options)
    options.vocabulary_widgets && return render_vocabulary_widgets(options)
    options.format === :markdown &&
        return options.query === nothing ?
            widget_catalog_markdown(; status=options.status, surface=options.surface, family=options.family, columns=options.columns) :
            search_widget_catalog_markdown(options.query; status=options.status, surface=options.surface, family=options.family, columns=options.columns)
    options.format === :tsv &&
        return options.query === nothing ?
            widget_catalog_tsv(; status=options.status, surface=options.surface, family=options.family, columns=options.columns, header=options.header) :
            search_widget_catalog_tsv(options.query; status=options.status, surface=options.surface, family=options.family, columns=options.columns, header=options.header)
    throw(ArgumentError("unsupported widget catalog render format: $(options.format)"))
end

function render_coverage_summary(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --coverage-summary"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --coverage-summary"))
    if options.format === :markdown
        return widget_coverage_summary_markdown(; status=options.status, surface=options.surface, family=options.family)
    elseif options.format === :tsv
        return widget_coverage_summary_tsv(; status=options.status, surface=options.surface, family=options.family, header=options.header)
    end
    throw(ArgumentError("unsupported widget coverage summary format: $(options.format)"))
end

function assert_clean_git_metadata(root::AbstractString=ROOT)
    return assert_widget_coverage_clean_git(; root=root)
end

function render_coverage_summary_json(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --coverage-summary-json"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --coverage-summary-json"))
    return widget_coverage_summary_json(; status=options.status, surface=options.surface, family=options.family)
end

function render_coverage_issue_names(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --coverage-issue-names"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --coverage-issue-names"))
    return widget_coverage_issue_text(options.coverage_issue_names; status=options.status, surface=options.surface, family=options.family)
end

function render_coverage_issue(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --coverage-issue"))
    columns = coverage_columns(options)
    if options.format === :markdown
        return widget_coverage_issue_markdown(options.coverage_issue; status=options.status, surface=options.surface, family=options.family, columns=columns)
    elseif options.format === :tsv
        return widget_coverage_issue_tsv(options.coverage_issue; status=options.status, surface=options.surface, family=options.family, columns=columns, header=options.header)
    end
    throw(ArgumentError("unsupported widget coverage issue format: $(options.format)"))
end

function render_coverage_status(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --coverage-status"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --coverage-status"))
    if options.require_clean_git
        return widget_coverage_release_status_text(; status=options.status, surface=options.surface, family=options.family, root=ROOT)
    end
    return widget_coverage_summary_text(; status=options.status, surface=options.surface, family=options.family)
end

function coverage_columns(options)
    return options.columns_given ? options.columns : DEFAULT_COVERAGE_COLUMNS
end

function stability_columns(options)
    return options.columns_given ? options.columns : DEFAULT_STABILITY_COLUMNS
end

function render_coverage(options; gaps::Bool)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --coverage or --coverage-gaps"))
    columns = coverage_columns(options)
    if options.format === :markdown
        return gaps ?
            widget_coverage_gaps_markdown(; status=options.status, surface=options.surface, family=options.family, columns=columns) :
            widget_coverage_records_markdown(; status=options.status, surface=options.surface, family=options.family, columns=columns)
    elseif options.format === :tsv
        return gaps ?
            widget_coverage_gaps_tsv(; status=options.status, surface=options.surface, family=options.family, columns=columns, header=options.header) :
            widget_coverage_records_tsv(; status=options.status, surface=options.surface, family=options.family, columns=columns, header=options.header)
    end
    throw(ArgumentError("unsupported widget coverage format: $(options.format)"))
end

function render_stability(options; gaps::Bool)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --stability or --stability-gaps"))
    columns = stability_columns(options)
    if options.format === :markdown
        return gaps ?
            widget_stability_gaps_markdown(; status=options.status, surface=options.surface, family=options.family, columns=columns) :
            widget_stability_markdown(; status=options.status, surface=options.surface, family=options.family, columns=columns)
    elseif options.format === :tsv
        return gaps ?
            widget_stability_gaps_tsv(; status=options.status, surface=options.surface, family=options.family, columns=columns, header=options.header) :
            widget_stability_tsv(; status=options.status, surface=options.surface, family=options.family, columns=columns, header=options.header)
    end
    throw(ArgumentError("unsupported widget stability format: $(options.format)"))
end

function render_stability_json(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --stability-json"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --stability-json"))
    return widget_stability_json(; status=options.status, surface=options.surface, family=options.family)
end

function render_stability_summary(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --stability-summary"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --stability-summary"))
    if options.format === :markdown
        return widget_stability_summary_markdown(; status=options.status, surface=options.surface, family=options.family)
    elseif options.format === :tsv
        return widget_stability_summary_tsv(; status=options.status, surface=options.surface, family=options.family, header=options.header)
    end
    throw(ArgumentError("unsupported widget stability summary format: $(options.format)"))
end

function render_stability_status(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --stability-status"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --stability-status"))
    return widget_stability_summary_text(; status=options.status, surface=options.surface, family=options.family)
end

function render_stabilization_status(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --stabilization-status"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --stabilization-status"))
    return widget_stabilization_status_text(; family=options.family)
end

function render_stabilization_blockers(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --stabilization-blockers"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --stabilization-blockers"))
    return widget_stabilization_blockers_text(; family=options.family)
end

function render_stabilization_json(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --stabilization-json"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --stabilization-json"))
    return widget_stabilization_status_json(; family=options.family)
end

function render_surface_release_status(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --surface-release-status"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --surface-release-status"))
    return widget_surface_release_status_text(; status=options.status, surface=options.surface, family=options.family, root=ROOT)
end

function render_surface_release_json(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --surface-release-json"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --surface-release-json"))
    return widget_surface_release_status_json(; status=options.status, surface=options.surface, family=options.family, root=ROOT)
end

function render_vocabulary(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --vocabulary"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --vocabulary"))
    if options.format === :markdown
        return widget_vocabulary_markdown()
    elseif options.format === :tsv
        return widget_vocabulary_tsv(header=options.header)
    end
    throw(ArgumentError("unsupported widget vocabulary format: $(options.format)"))
end

function render_vocabulary_widgets(options)
    options.query === nothing && throw(ArgumentError("--vocabulary-widgets requires --query"))
    options.columns_given && throw(ArgumentError("--columns cannot be used with --vocabulary-widgets"))
    return join((String(name) for name in widget_vocabulary_widget_names(options.query)), "\n")
end

function render_family_catalog(options)
    options.query !== nothing && options.family !== nothing &&
        throw(ArgumentError("--family cannot be used with --query for --family-catalog"))
    options.format === :markdown &&
        return options.query === nothing ?
            widget_family_catalog_markdown(; status=options.status, surface=options.surface, family=options.family, columns=options.columns) :
            search_widget_family_catalog_markdown(options.query; status=options.status, surface=options.surface, columns=options.columns)
    options.format === :tsv &&
        return options.query === nothing ?
            widget_family_catalog_tsv(; status=options.status, surface=options.surface, family=options.family, columns=options.columns, header=options.header) :
            search_widget_family_catalog_tsv(options.query; status=options.status, surface=options.surface, columns=options.columns, header=options.header)
    throw(ArgumentError("unsupported widget family catalog format: $(options.format)"))
end

function render_families(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --families"))
    options.family !== nothing && throw(ArgumentError("--family cannot be used with --families"))
    return widget_families_text(; status=options.status, surface=options.surface)
end

function render_family_slugs(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --family-slugs"))
    options.family !== nothing && throw(ArgumentError("--family cannot be used with --family-slugs"))
    return widget_family_slugs_text(; status=options.status, surface=options.surface)
end

function render_family_summary(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --family-summary"))
    options.format === :markdown &&
        return widget_family_summary_markdown(; status=options.status, surface=options.surface, family=options.family)
    options.format === :tsv &&
        return widget_family_summary_tsv(; status=options.status, surface=options.surface, family=options.family, header=options.header)
    throw(ArgumentError("unsupported widget family summary format: $(options.format)"))
end

function render_source_summary(options)
    options.query !== nothing && throw(ArgumentError("--query cannot be used with --source-summary"))
    options.format === :markdown &&
        return widget_source_summary_markdown(; status=options.status, surface=options.surface, family=options.family)
    options.format === :tsv &&
        return widget_source_summary_tsv(; status=options.status, surface=options.surface, family=options.family, header=options.header)
    throw(ArgumentError("unsupported widget source summary format: $(options.format)"))
end

function sorted_summary_rows(entries)
    by_status = Dict{Symbol,Int}()
    by_surface = Dict{Symbol,Int}()
    by_family = Dict{String,Int}()
    by_source = Dict{String,Int}()
    for entry in entries
        by_status[entry.status] = get(by_status, entry.status, 0) + 1
        by_surface[entry.surface] = get(by_surface, entry.surface, 0) + 1
        family = widget_catalog_family(entry)
        by_family[family] = get(by_family, family, 0) + 1
        by_source[entry.source] = get(by_source, entry.source, 0) + 1
    end
    summary = (total=length(entries), by_status=by_status, by_surface=by_surface, by_family=by_family, by_source=by_source)
    rows = [("total", "all", summary.total)]
    append!(rows, [("status", String(key), value) for (key, value) in summary.by_status])
    append!(rows, [("surface", String(key), value) for (key, value) in summary.by_surface])
    append!(rows, [("family", key, value) for (key, value) in summary.by_family])
    append!(rows, [("family_slug", widget_catalog_family_slug(key), value) for (key, value) in summary.by_family])
    append!(rows, [("source", String(key), value) for (key, value) in summary.by_source])
    return sort!(rows; by=row -> (row[1], row[2]))
end

function render_summary(options)
    entries = options.query === nothing ?
        stable_widget_catalog(; status=options.status, surface=options.surface, family=options.family) :
        search_widgets(options.query; status=options.status, surface=options.surface, family=options.family)
    rows = sorted_summary_rows(entries)
    if options.format === :markdown
        lines = String["| `metric` | `key` | `count` |", "| --- | --- | --- |"]
        append!(lines, "| $(metric) | $(key) | $(count) |" for (metric, key, count) in rows)
        return join(lines, "\n")
    elseif options.format === :tsv
        lines = options.header ? String["metric\tkey\tcount"] : String[]
        append!(lines, "$(metric)\t$(key)\t$(count)" for (metric, key, count) in rows)
        return join(lines, "\n")
    end
    throw(ArgumentError("unsupported widget catalog summary format: $(options.format)"))
end

function main(arguments=ARGS; io::IO=stdout, err::IO=stderr)
    try
        options = parse_arguments(arguments)
        if options.help
            print_usage(io)
            return 0
        end
        if options.min_count !== nothing
            actual = matching_widget_count(options)
            if actual < options.min_count
                println(err, "render widget catalog: expected at least $(options.min_count) matching widgets, got $actual")
                return 1
            end
        end
        if options.max_count !== nothing
            actual = matching_widget_count(options)
            if actual > options.max_count
                println(err, "render widget catalog: expected at most $(options.max_count) matching widgets, got $actual")
                return 1
            end
        end
        if options.require_stability_ready
            gaps = widget_stability_gaps(; status=options.status, surface=options.surface, family=options.family)
            if !isempty(gaps)
                sample = join((String(report.name) for report in Iterators.take(gaps, 5)), ", ")
                suffix = length(gaps) > 5 ? ", ..." : ""
                println(err, "render widget catalog: expected promotion-ready stable widgets; $(length(gaps)) blocker report(s): $(sample)$(suffix)")
                return 1
            end
        end
        if options.require_stabilization_ready
            try
                assert_widget_stabilization_ready(; family=options.family)
            catch error
                if error isa ArgumentError
                    println(err, "render widget catalog: expected stabilization-ready widget surface; $(sprint(showerror, error))")
                    return 1
                end
                rethrow()
            end
        end
        if options.require_surface_release_ready
            try
                assert_widget_surface_release_ready(; status=options.status, surface=options.surface, family=options.family, root=ROOT)
            catch error
                if error isa ArgumentError
                    println(err, "render widget catalog: expected release-ready stable widget surface; $(sprint(showerror, error))")
                    return 1
                end
                rethrow()
            end
        end
        if options.require_complete_coverage && options.require_clean_git
            try
                assert_widget_coverage_release_ready(; status=options.status, surface=options.surface, family=options.family, root=ROOT)
            catch error
                if error isa ArgumentError
                    println(err, "render widget catalog: expected release-ready stable widget coverage evidence; $(sprint(showerror, error))")
                    return 1
                end
                rethrow()
            end
        elseif options.require_complete_coverage
            try
                assert_widget_coverage_complete(; status=options.status, surface=options.surface, family=options.family)
            catch error
                if error isa ArgumentError
                    println(err, "render widget catalog: expected complete stable widget coverage evidence; $(sprint(showerror, error))")
                    return 1
                end
                rethrow()
            end
        end
        if options.require_clean_git && !options.require_complete_coverage
            try
                assert_clean_git_metadata()
            catch error
                if error isa ArgumentError
                    println(err, "render widget catalog: expected clean git metadata; $(sprint(showerror, error))")
                    return 1
                end
                rethrow()
            end
        end
        rendered = render_catalog(options)
        if options.output === nothing
            println(io, rendered)
        else
            output_directory = dirname(options.output)
            isempty(output_directory) || output_directory == "." || mkpath(output_directory)
            mode = options.append ? "a" : "w"
            open(options.output, mode) do output_io
                println(output_io, rendered)
            end
        end
        return 0
    catch error
        println(err, "render widget catalog: $(sprint(showerror, error))")
        print_usage(err)
        return 2
    end
end

end # module WidgetCatalogRender

if abspath(PROGRAM_FILE) == @__FILE__
    exit(WidgetCatalogRender.main())
end
