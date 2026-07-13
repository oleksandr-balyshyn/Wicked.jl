#!/usr/bin/env julia

module WidgetFamilyCloseoutRender

isdefined(@__MODULE__, :WidgetFamilyEvidenceAudit) ||
    include(joinpath(@__DIR__, "widget_family_evidence_audit.jl"))

const ROOT = normpath(joinpath(@__DIR__, ".."))
const DEFAULT_COLUMNS = (:family, :status, :docs, :examples, :stable_api_tokens, :precompile_tokens, :blockers, :blocker_details)

struct FamilyCloseoutRow
    family::String
    status::Symbol
    docs::Vector{String}
    examples::Vector{String}
    stable_api_tokens::Vector{String}
    precompile_tokens::Vector{String}
    notes::String
    blockers::Vector{String}
end

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/render_widget_family_closeout.jl [--family text] [--status ready|blocked|all] [--format markdown|tsv|json] [--columns family,status,docs,examples,stable_api_tokens,precompile_tokens,blockers,blocker_details] [--count|--summary] [--require-ready] [--require-clean-git] [--release-check] [--require-total-count n] [--require-ready-count n] [--require-blocked-count n] [--output path] [--no-header]")
    println(io, "")
    println(io, "Renders family-level widget stabilization closeout evidence.")
    println(io, "Use --family to render only matching widget families.")
    println(io, "Use --status ready, blocked, or all to focus the closeout loop.")
    println(io, "Use --count to print the number of matching families.")
    println(io, "Use --summary to print total, ready, and blocked family counts.")
    println(io, "Use --require-ready to fail when any matching family is blocked.")
    println(io, "Use --require-clean-git to fail when git metadata reports uncommitted changes.")
    println(io, "Use --release-check to require ready families, clean git metadata, and zero blocked families.")
    println(io, "Use --require-total-count, --require-ready-count, and --require-blocked-count to assert exact family counts.")
    println(io, "Use --no-header with --format tsv to omit the TSV header row.")
end

split_list(value::AbstractString) = WidgetFamilyEvidenceAudit.split_list(value)

function parse_columns(value::AbstractString)
    parts = [strip(part) for part in split(value, ',')]
    any(isempty, parts) && throw(ArgumentError("--columns cannot contain empty column names"))
    return Tuple(Symbol.(parts))
end

function parse_format(value::AbstractString)
    format = Symbol(lowercase(strip(value)))
    format in (:markdown, :tsv, :json) || throw(ArgumentError("--format must be markdown, tsv, or json"))
    return format
end

function parse_status(value::AbstractString)
    status = Symbol(lowercase(strip(value)))
    status === :all && return nothing
    status in (:ready, :blocked) || throw(ArgumentError("--status must be ready, blocked, or all"))
    return status
end

function parse_nonnegative_integer(value::AbstractString, label::AbstractString)
    parsed = tryparse(Int, value)
    parsed === nothing && throw(ArgumentError("$label requires a non-negative integer"))
    parsed >= 0 || throw(ArgumentError("$label requires a non-negative integer"))
    return parsed
end

function parse_arguments(arguments)
    columns = DEFAULT_COLUMNS
    format = :markdown
    family = nothing
    status = nothing
    count = false
    summary = false
    require_ready = false
    require_clean_git = false
    release_check = false
    require_total_count = nothing
    require_ready_count = nothing
    require_blocked_count = nothing
    output = nothing
    header = true
    index = firstindex(arguments)
    while index <= lastindex(arguments)
        argument = arguments[index]
        if argument == "--help" || argument == "-h"
            return (help=true, columns=columns, format=format, family=family, status=status, count=count, summary=summary, require_ready=require_ready, require_clean_git=require_clean_git, release_check=release_check, require_total_count=require_total_count, require_ready_count=require_ready_count, require_blocked_count=require_blocked_count, output=output, header=header)
        elseif argument == "--family"
            index < lastindex(arguments) || throw(ArgumentError("--family requires a search string"))
            index += 1
            family = lowercase(strip(arguments[index]))
            isempty(family) && throw(ArgumentError("--family requires a non-empty search string"))
        elseif argument == "--status"
            index < lastindex(arguments) || throw(ArgumentError("--status requires ready, blocked, or all"))
            index += 1
            status = parse_status(arguments[index])
        elseif argument == "--format"
            index < lastindex(arguments) || throw(ArgumentError("--format requires markdown or tsv"))
            index += 1
            format = parse_format(arguments[index])
        elseif argument == "--columns"
            index < lastindex(arguments) || throw(ArgumentError("--columns requires a comma-separated value"))
            index += 1
            columns = parse_columns(arguments[index])
        elseif argument == "--count"
            count = true
        elseif argument == "--summary"
            summary = true
        elseif argument == "--require-ready"
            require_ready = true
        elseif argument == "--require-clean-git"
            require_clean_git = true
        elseif argument == "--release-check"
            release_check = true
        elseif argument == "--require-total-count"
            index < lastindex(arguments) || throw(ArgumentError("--require-total-count requires a non-negative integer"))
            index += 1
            require_total_count = parse_nonnegative_integer(arguments[index], "--require-total-count")
        elseif argument == "--require-ready-count"
            index < lastindex(arguments) || throw(ArgumentError("--require-ready-count requires a non-negative integer"))
            index += 1
            require_ready_count = parse_nonnegative_integer(arguments[index], "--require-ready-count")
        elseif argument == "--require-blocked-count"
            index < lastindex(arguments) || throw(ArgumentError("--require-blocked-count requires a non-negative integer"))
            index += 1
            require_blocked_count = parse_nonnegative_integer(arguments[index], "--require-blocked-count")
        elseif argument == "--output"
            index < lastindex(arguments) || throw(ArgumentError("--output requires a file path"))
            index += 1
            output = strip(arguments[index])
            isempty(output) && throw(ArgumentError("--output requires a non-empty file path"))
        elseif argument == "--no-header"
            header = false
        else
            throw(ArgumentError("unknown argument: $argument"))
        end
        index += 1
    end
    if release_check
        require_ready = true
        require_clean_git = true
        require_blocked_count = 0
    end
    count && summary && throw(ArgumentError("--count and --summary are mutually exclusive"))
    count && !header && throw(ArgumentError("--no-header cannot be used with --count"))
    !header && format !== :tsv && throw(ArgumentError("--no-header requires --format tsv"))
    return (help=false, columns=columns, format=format, family=family, status=status, count=count, summary=summary, require_ready=require_ready, require_clean_git=require_clean_git, release_check=release_check, require_total_count=require_total_count, require_ready_count=require_ready_count, require_blocked_count=require_blocked_count, output=output, header=header)
end

function _row_blockers(family::AbstractString, failures)
    prefix = string(family, " ")
    return String[failure for failure in failures if startswith(failure, prefix)]
end

function closeout_rows(ledger::AbstractString=WidgetFamilyEvidenceAudit.LEDGER)
    rows, read_failures = WidgetFamilyEvidenceAudit.read_rows(ledger)
    audit_failures = isempty(read_failures) ? WidgetFamilyEvidenceAudit.audit(ledger) : read_failures
    output = FamilyCloseoutRow[]
    for family in sort!(collect(keys(rows)))
        row = rows[family]
        blockers = _row_blockers(family, audit_failures)
        push!(
            output,
            FamilyCloseoutRow(
                family,
                isempty(blockers) ? :ready : :blocked,
                split_list(get(row, "docs", "")),
                split_list(get(row, "examples", "")),
                split_list(get(row, "stable_api_tokens", "")),
                split_list(get(row, "precompile_tokens", "")),
                get(row, "notes", ""),
                blockers,
            ),
        )
    end
    return output
end

function filter_rows(rows, query, status=nothing)
    family_filtered = query === nothing ? rows : FamilyCloseoutRow[
        row for row in rows
        if occursin(query, lowercase(join((row.family, row.notes, join(row.docs, " "), join(row.examples, " "), join(row.stable_api_tokens, " ")), " ")))
    ]
    status === nothing && return family_filtered
    return FamilyCloseoutRow[row for row in family_filtered if row.status == status]
end

_markdown_escape(value::AbstractString) = replace(value, "\\" => "\\\\", "|" => "\\|", "\n" => " ")
_tsv_escape(value::AbstractString) = replace(value, "\t" => " ", "\r" => " ", "\n" => " ")

function column_value(row::FamilyCloseoutRow, column::Symbol)
    column === :family && return row.family
    column === :status && return String(row.status)
    column === :docs && return join(row.docs, ", ")
    column === :examples && return join(row.examples, ", ")
    column === :stable_api_tokens && return join(row.stable_api_tokens, ", ")
    column === :precompile_tokens && return join(row.precompile_tokens, ", ")
    column === :notes && return row.notes
    column === :blockers && return isempty(row.blockers) ? "0" : string(length(row.blockers))
    column === :blocker_details && return isempty(row.blockers) ? "" : join(row.blockers, "; ")
    throw(ArgumentError("family closeout column must be one of :family, :status, :docs, :examples, :stable_api_tokens, :precompile_tokens, :notes, :blockers, or :blocker_details"))
end

function render_markdown(rows, columns)
    lines = String[
        "| " * join(("`$(column)`" for column in columns), " | ") * " |",
        "| " * join(("---" for _ in columns), " | ") * " |",
    ]
    for row in rows
        push!(lines, "| " * join((_markdown_escape(column_value(row, column)) for column in columns), " | ") * " |")
    end
    return join(lines, "\n")
end

function render_tsv(rows, columns; header::Bool=true)
    lines = header ? String[join(String.(columns), '\t')] : String[]
    for row in rows
        push!(lines, join((_tsv_escape(column_value(row, column)) for column in columns), '\t'))
    end
    return join(lines, "\n")
end

function render_closeout(options; ledger::AbstractString=WidgetFamilyEvidenceAudit.LEDGER)
    rows = filter_rows(closeout_rows(ledger), options.family, options.status)
    options.count && return string(length(rows))
    options.summary && return render_summary(rows, options.format; header=options.header)
    options.format === :markdown && return render_markdown(rows, options.columns)
    options.format === :tsv && return render_tsv(rows, options.columns; header=options.header)
    options.format === :json && return render_json(rows)
    throw(ArgumentError("unsupported family closeout format: $(options.format)"))
end

blocked_rows(rows) = FamilyCloseoutRow[row for row in rows if row.status == :blocked]

function summary_rows(rows)
    ready = count(row -> row.status == :ready, rows)
    blocked = count(row -> row.status == :blocked, rows)
    return [("total", length(rows)), ("ready", ready), ("blocked", blocked)]
end

function summary_counts(rows)
    return (total=length(rows), ready=count(row -> row.status == :ready, rows), blocked=count(row -> row.status == :blocked, rows))
end

function render_summary(rows, format::Symbol; header::Bool=true)
    summary = summary_rows(rows)
    if format === :markdown
        lines = String["| `status` | `count` |", "| --- | --- |"]
        append!(lines, "| $(status) | $(count) |" for (status, count) in summary)
        return join(lines, "\n")
    elseif format === :tsv
        lines = header ? String["status\tcount"] : String[]
        append!(lines, "$(status)\t$(count)" for (status, count) in summary)
        return join(lines, "\n")
    elseif format === :json
        return "{" * join(("\"$(status)\":$(count)" for (status, count) in summary), ",") * "}"
    end
    throw(ArgumentError("unsupported family closeout summary format: $format"))
end

function _json_escape(value::AbstractString)
    escaped = IOBuffer()
    for character in value
        if character == '"'
            print(escaped, "\\\"")
        elseif character == '\\'
            print(escaped, "\\\\")
        elseif character == '\n'
            print(escaped, "\\n")
        elseif character == '\r'
            print(escaped, "\\r")
        elseif character == '\t'
            print(escaped, "\\t")
        else
            print(escaped, character)
        end
    end
    return String(take!(escaped))
end

json_string(value::AbstractString) = "\"" * _json_escape(value) * "\""
json_array(values) = "[" * join((json_string(String(value)) for value in values), ",") * "]"

function git_commit(root::AbstractString=ROOT)
    try
        output = read(`git -C $root rev-parse HEAD`, String)
        commit = strip(output)
        isempty(commit) && return nothing
        return commit
    catch
        return nothing
    end
end

function git_dirty(root::AbstractString=ROOT)
    try
        output = read(`git -C $root status --porcelain`, String)
        return !isempty(strip(output))
    catch
        return nothing
    end
end

function render_json(rows)
    objects = String[]
    for row in rows
        push!(
            objects,
            "{" *
            join(
                (
                    "\"family\":" * json_string(row.family),
                    "\"status\":" * json_string(String(row.status)),
                    "\"docs\":" * json_array(row.docs),
                    "\"examples\":" * json_array(row.examples),
                    "\"stable_api_tokens\":" * json_array(row.stable_api_tokens),
                    "\"precompile_tokens\":" * json_array(row.precompile_tokens),
                    "\"notes\":" * json_string(row.notes),
                    "\"blockers\":" * string(length(row.blockers)),
                    "\"blocker_details\":" * json_array(row.blockers),
                ),
                ",",
            ) *
            "}",
        )
    end
    counts = summary_counts(rows)
    generated_at = Libc.strftime("%Y-%m-%dT%H:%M:%SZ", time())
    summary = "\"summary\":{\"total\":$(counts.total),\"ready\":$(counts.ready),\"blocked\":$(counts.blocked)}"
    commit = git_commit()
    commit_field = commit === nothing ? "" : ",\"git_commit\":" * json_string(commit)
    dirty = git_dirty()
    dirty_field = dirty === nothing ? "" : ",\"git_dirty\":" * string(dirty)
    metadata = "\"metadata\":{\"generated_at\":" * json_string(generated_at) * ",\"root\":" * json_string(ROOT) * commit_field * dirty_field * "}"
    return "{\"schema_version\":1,$metadata,$summary,\"families\":[" * join(objects, ",") * "]}"
end

function main(arguments=ARGS; io::IO=stdout, err::IO=stderr, ledger::AbstractString=WidgetFamilyEvidenceAudit.LEDGER)
    try
        options = parse_arguments(arguments)
        if options.help
            print_usage(io)
            return 0
        end
        rows = filter_rows(closeout_rows(ledger), options.family, options.status)
        blocked = options.require_ready ? blocked_rows(rows) : FamilyCloseoutRow[]
        counts = summary_counts(rows)
        rendered = options.count ? string(length(rows)) :
            options.summary ? render_summary(rows, options.format; header=options.header) :
            options.format === :markdown ? render_markdown(rows, options.columns) :
            options.format === :tsv ? render_tsv(rows, options.columns; header=options.header) :
            options.format === :json ? render_json(rows) :
            throw(ArgumentError("unsupported family closeout format: $(options.format)"))
        if options.output === nothing
            println(io, rendered)
        else
            output_directory = dirname(options.output)
            isempty(output_directory) || output_directory == "." || mkpath(output_directory)
            open(options.output, "w") do output_io
                println(output_io, rendered)
            end
        end
        if !isempty(blocked)
            println(err, "render widget family closeout: blocked families: $(join((row.family for row in blocked), ", "))")
            return 1
        end
        if options.require_clean_git
            dirty = git_dirty()
            if dirty === nothing
                println(err, "render widget family closeout: git status unavailable; cannot enforce --require-clean-git")
                return 1
            elseif dirty
                println(err, "render widget family closeout: git worktree has uncommitted changes")
                return 1
            end
        end
        if options.require_total_count !== nothing && counts.total != options.require_total_count
            println(err, "render widget family closeout: expected $(options.require_total_count) total families, got $(counts.total)")
            return 1
        end
        if options.require_ready_count !== nothing && counts.ready != options.require_ready_count
            println(err, "render widget family closeout: expected $(options.require_ready_count) ready families, got $(counts.ready)")
            return 1
        end
        if options.require_blocked_count !== nothing && counts.blocked != options.require_blocked_count
            println(err, "render widget family closeout: expected $(options.require_blocked_count) blocked families, got $(counts.blocked)")
            return 1
        end
        return 0
    catch error
        println(err, "render widget family closeout: $(sprint(showerror, error))")
        print_usage(err)
        return 2
    end
end

end # module WidgetFamilyCloseoutRender

if abspath(PROGRAM_FILE) == @__FILE__
    exit(WidgetFamilyCloseoutRender.main())
end
