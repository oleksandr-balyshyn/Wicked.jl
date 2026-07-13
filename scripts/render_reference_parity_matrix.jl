#!/usr/bin/env julia

module ReferenceParityMatrixRender

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SURVEY = joinpath(ROOT, "docs", "REFERENCE_PARITY_SURVEY.md")
const VALID_FORMATS = Set(["json", "markdown", "tsv"])
const COLUMNS = (
    :family,
    :ratatui,
    :textual,
    :tamboui,
    :lanterna,
    :wicked,
    :status,
    :follow_up,
)
const RELEASE_READY_STATUS = "matched"

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/render_reference_parity_matrix.jl [options]")
    println(io, "")
    println(io, "Renders the cross-library capability matrix from docs/REFERENCE_PARITY_SURVEY.md.")
    println(io, "")
    println(io, "Options:")
    println(io, "  --format <json|markdown|tsv>  Output format. Default: markdown")
    println(io, "  --columns <names>             Comma-separated Markdown/TSV columns")
    println(io, "  --status <status>             Filter by parity status")
    println(io, "  --family <text>               Filter by family substring")
    println(io, "  --source <path>               Read a specific reference survey file")
    println(io, "  --summary                     Render status counts instead of matrix rows")
    println(io, "  --blocking-only               Render only non-matched release-blocking rows")
    println(io, "  --release-status              Render one compact release-readiness line")
    println(io, "  --release-blockers            Render newline-separated release blocker details")
    println(io, "  --release-status-json         Render release-readiness status as JSON")
    println(io, "  --require-release-ready       Exit non-zero when release status is blocked")
    println(io, "  --no-header                   Omit TSV header")
    println(io, "  --output <path>               Write output to a file")
    println(io, "  --help, -h                    Show this help")
end

function parse_args(arguments)
    options = Dict(
        "format" => "markdown",
        "columns" => "",
        "status" => "",
        "family" => "",
        "release-status" => "no",
        "release-blockers" => "no",
        "release-status-json" => "no",
        "require-release-ready" => "no",
        "source" => "",
        "summary" => "no",
        "blocking-only" => "no",
        "header" => "yes",
        "output" => "",
    )
    index = 1
    while index <= length(arguments)
        argument = arguments[index]
        argument in ("--help", "-h") && return nothing
        if argument == "--no-header"
            options["header"] = "no"
            index += 1
            continue
        end
        if argument == "--release-status"
            options["release-status"] = "yes"
            index += 1
            continue
        end
        if argument == "--release-blockers"
            options["release-blockers"] = "yes"
            index += 1
            continue
        end
        if argument == "--release-status-json"
            options["release-status-json"] = "yes"
            index += 1
            continue
        end
        if argument == "--summary"
            options["summary"] = "yes"
            index += 1
            continue
        end
        if argument == "--blocking-only"
            options["blocking-only"] = "yes"
            index += 1
            continue
        end
        if argument == "--require-release-ready"
            options["require-release-ready"] = "yes"
            index += 1
            continue
        end
        argument in ("--format", "--columns", "--status", "--family", "--output", "--source") ||
            error("unknown argument: $argument")
        index == length(arguments) && error("missing value for $argument")
        options[argument[3:end]] = arguments[index + 1]
        index += 2
    end

    format = lowercase(strip(options["format"]))
    format in VALID_FORMATS || error("--format must be json, markdown, or tsv")
    options["header"] == "no" && format != "tsv" &&
        error("--no-header requires --format tsv")
    release_output_modes = (options["release-status"] == "yes" ? 1 : 0) +
        (options["release-blockers"] == "yes" ? 1 : 0) +
        (options["release-status-json"] == "yes" ? 1 : 0)
    release_output_modes <= 1 ||
        error("--release-status, --release-blockers, and --release-status-json are mutually exclusive")
    options["blocking-only"] == "yes" && release_output_modes > 0 &&
        error("--blocking-only cannot be used with release-status output")
    options["format"] = format
    !isempty(strip(options["columns"])) && format == "json" &&
        error("--columns cannot be used with --format json")
    !isempty(strip(options["columns"])) && options["summary"] == "yes" &&
        error("--columns cannot be used with --summary")
    !isempty(strip(options["columns"])) && release_output_modes > 0 &&
        error("--columns cannot be used with release-status output")
    options["columns"] = strip(options["columns"])
    options["status"] = lowercase(strip(options["status"]))
    options["family"] = lowercase(strip(options["family"]))
    options["source"] = strip(options["source"])
    options["output"] = strip(options["output"])
    return options
end

function markdown_cells(line::AbstractString)
    stripped = strip(line)
    startswith(stripped, "|") && endswith(stripped, "|") || return nothing
    cells = split(stripped[2:end - 1], '|'; keepempty=true)
    return String[strip(cell) for cell in cells]
end

function parity_rows(path::AbstractString=SURVEY)
    isfile(path) || error("missing reference parity survey: $(relpath(path, ROOT))")
    rows = NamedTuple[]
    in_matrix = false
    saw_header = false
    for raw_line in readlines(path)
        cells = markdown_cells(raw_line)
        if cells === nothing
            in_matrix = false
            continue
        end
        if length(cells) == length(COLUMNS) && cells[1] == "Family"
            in_matrix = true
            saw_header = true
            continue
        end
        in_matrix || continue
        all(cell -> occursin(r"^-+$", cell), cells) && continue
        length(cells) == length(COLUMNS) || continue
        push!(
            rows,
            (
                family=cells[1],
                ratatui=cells[2],
                textual=cells[3],
                tamboui=cells[4],
                lanterna=cells[5],
                wicked=cells[6],
                status=cells[7],
                follow_up=cells[8],
            ),
        )
    end
    saw_header || error("reference parity survey is missing the capability audit matrix")
    return rows
end

function filter_rows(rows; status::AbstractString="", family::AbstractString="")
    selected = rows
    if !isempty(status)
        selected = [row for row in selected if lowercase(row.status) == status]
    end
    if !isempty(family)
        selected = [row for row in selected if occursin(family, lowercase(row.family))]
    end
    return selected
end

function blocking_rows(rows)
    return [row for row in rows if lowercase(row.status) != RELEASE_READY_STATUS]
end

function counts_by(rows, selector)
    counts = Dict{String,Int}()
    for row in rows
        key = selector(row)
        counts[key] = get(counts, key, 0) + 1
    end
    return sort!(collect(counts); by=first)
end

function parse_columns(value::AbstractString)
    isempty(strip(value)) && return COLUMNS
    parsed = Symbol[]
    valid = Set(COLUMNS)
    for raw in split(value, ',')
        stripped = strip(raw)
        isempty(stripped) && error("--columns cannot contain empty column names")
        column = Symbol(stripped)
        column in valid || error("unknown column: $(strip(raw))")
        column in parsed && error("--columns cannot contain duplicate column names")
        push!(parsed, column)
    end
    isempty(parsed) && error("--columns cannot contain empty column names")
    return Tuple(parsed)
end

function column_label(column::Symbol)
    return Dict(
        :family => "Family",
        :ratatui => "Ratatui",
        :textual => "Textual",
        :tamboui => "TamboUI",
        :lanterna => "Lanterna",
        :wicked => "Wicked direction",
        :status => "Status",
        :follow_up => "Follow-up",
    )[column]
end

column_value(row, column::Symbol) = getproperty(row, column)

function markdown_escape(value)
    return replace(String(value), "|" => "\\|", "\n" => " ")
end

function json_escape(value)
    escaped = replace(
        String(value),
        "\\" => "\\\\",
        "\"" => "\\\"",
        "\n" => "\\n",
        "\r" => "\\r",
        "\t" => "\\t",
    )
    return "\"$escaped\""
end

function render_markdown(rows; columns=COLUMNS)
    lines = String[
        "| $(join((column_label(column) for column in columns), " | ")) |",
        "| $(join(("---" for _ in columns), " | ")) |",
    ]
    for row in rows
        push!(
            lines,
            "| $(join((markdown_escape(column_value(row, column)) for column in columns), " | ")) |",
        )
    end
    return join(lines, "\n")
end

function render_tsv(rows; columns=COLUMNS, header::Bool=true)
    lines = String[]
    header && push!(lines, join(String.(columns), '\t'))
    for row in rows
        push!(
            lines,
            join((column_value(row, column) for column in columns), '\t'),
        )
    end
    return join(lines, "\n")
end

function render_json_counts(lines, indentation, rows)
    for (index, (key, count)) in enumerate(rows)
        suffix = index == length(rows) ? "" : ","
        push!(lines, "$(indentation)$(json_escape(key)): $count$suffix")
    end
end

function render_json(rows)
    lines = String[
        "{",
        "  \"schema_version\": 1,",
        "  \"summary\": {",
        "    \"total\": $(length(rows)),",
        "    \"by_status\": {",
    ]
    render_json_counts(lines, "      ", counts_by(rows, row -> row.status))
    append!(lines, ("    }", "  },", "  \"rows\": ["))
    for (index, row) in enumerate(rows)
        suffix = index == length(rows) ? "" : ","
        push!(lines, "    {")
        push!(lines, "      \"family\": $(json_escape(row.family)),")
        push!(lines, "      \"ratatui\": $(json_escape(row.ratatui)),")
        push!(lines, "      \"textual\": $(json_escape(row.textual)),")
        push!(lines, "      \"tamboui\": $(json_escape(row.tamboui)),")
        push!(lines, "      \"lanterna\": $(json_escape(row.lanterna)),")
        push!(lines, "      \"wicked\": $(json_escape(row.wicked)),")
        push!(lines, "      \"status\": $(json_escape(row.status)),")
        push!(lines, "      \"follow_up\": $(json_escape(row.follow_up))")
        push!(lines, "    }$suffix")
    end
    push!(lines, "  ]")
    push!(lines, "}")
    return join(lines, "\n")
end

function status_summary(rows)
    return (
        total=length(rows),
        by_status=counts_by(rows, row -> row.status),
    )
end

function render_summary_markdown(rows)
    summary = status_summary(rows)
    lines = String[
        "| Metric | Key | Count |",
        "|---|---|---|",
        "| total | all | $(summary.total) |",
    ]
    for (status, count) in summary.by_status
        push!(lines, "| status | $(markdown_escape(status)) | $count |")
    end
    return join(lines, "\n")
end

function render_summary_tsv(rows; header::Bool=true)
    summary = status_summary(rows)
    lines = String[]
    header && push!(lines, "metric\tkey\tcount")
    push!(lines, "total\tall\t$(summary.total)")
    for (status, count) in summary.by_status
        push!(lines, "status\t$status\t$count")
    end
    return join(lines, "\n")
end

function render_summary_json(rows)
    summary = status_summary(rows)
    lines = String[
        "{",
        "  \"schema_version\": 1,",
        "  \"total\": $(summary.total),",
        "  \"by_status\": {",
    ]
    render_json_counts(lines, "    ", summary.by_status)
    push!(lines, "  }")
    push!(lines, "}")
    return join(lines, "\n")
end

function release_status(rows)
    blocking = [row for row in rows if lowercase(row.status) != RELEASE_READY_STATUS]
    return (
        release_ready=isempty(blocking),
        total=length(rows),
        blocking=length(blocking),
        blocking_families=String[row.family for row in blocking],
        blocking_records=[
            (
                family=row.family,
                status=row.status,
                follow_up=row.follow_up,
            ) for row in blocking
        ],
    )
end

function render_release_status(rows)
    status = release_status(rows)
    families = isempty(status.blocking_families) ? "none" : join(status.blocking_families, ", ")
    details = isempty(status.blocking_records) ? "none" : join(
        ("$(record.family)[$(record.status)]: $(record.follow_up)" for record in status.blocking_records),
        "; ",
    )
    return "release_ready=$(status.release_ready) total=$(status.total) blocking=$(status.blocking) blocking_families=$(families) blocking_details=$(details)"
end

function render_release_blockers(rows)
    status = release_status(rows)
    return join(
        ("$(record.family)[$(record.status)]: $(record.follow_up)" for record in status.blocking_records),
        "\n",
    )
end

function render_release_status_json(rows)
    status = release_status(rows)
    lines = String[
        "{",
        "  \"schema_version\": 1,",
        "  \"release_ready\": $(status.release_ready),",
        "  \"total\": $(status.total),",
        "  \"blocking\": $(status.blocking),",
        "  \"blocking_families\": [",
    ]
    for (index, family) in enumerate(status.blocking_families)
        suffix = index == length(status.blocking_families) ? "" : ","
        push!(lines, "    $(json_escape(family))$suffix")
    end
    push!(lines, "  ],")
    push!(lines, "  \"blocking_records\": [")
    for (index, record) in enumerate(status.blocking_records)
        suffix = index == length(status.blocking_records) ? "" : ","
        push!(lines, "    {")
        push!(lines, "      \"family\": $(json_escape(record.family)),")
        push!(lines, "      \"status\": $(json_escape(record.status)),")
        push!(lines, "      \"follow_up\": $(json_escape(record.follow_up))")
        push!(lines, "    }$suffix")
    end
    push!(lines, "  ]")
    push!(lines, "}")
    return join(lines, "\n")
end

function assert_release_ready(rows)
    status = release_status(rows)
    status.release_ready && return true
    families = isempty(status.blocking_families) ? "unknown" : join(status.blocking_families, ", ")
    throw(ArgumentError("reference parity matrix has $(status.blocking) non-matched release blocker(s): $(families)"))
end

function render(; path::AbstractString=SURVEY, format::AbstractString="markdown", columns=COLUMNS, status::AbstractString="", family::AbstractString="", summary::Bool=false, header::Bool=true, blocking_only::Bool=false)
    rows = filter_rows(parity_rows(path); status=status, family=family)
    blocking_only && (rows = blocking_rows(rows))
    if summary
        format == "json" && return render_summary_json(rows)
        format == "markdown" && return render_summary_markdown(rows)
        format == "tsv" && return render_summary_tsv(rows; header=header)
    end
    format == "json" && return render_json(rows)
    format == "markdown" && return render_markdown(rows; columns=columns)
    format == "tsv" && return render_tsv(rows; columns=columns, header=header)
    error("unsupported format: $format")
end

function write_output(output::AbstractString, content::AbstractString)
    if isempty(output)
        println(content)
    else
        mkpath(dirname(output))
        write(output, content)
    end
end

function main(arguments=ARGS)
    try
        options = parse_args(arguments)
        if options === nothing
            print_usage()
            return 0
        end
        content = render(;
            path=isempty(options["source"]) ? SURVEY : options["source"],
            format=options["format"],
            columns=parse_columns(options["columns"]),
            status=options["status"],
            family=options["family"],
            summary=options["summary"] == "yes",
            header=options["header"] == "yes",
            blocking_only=options["blocking-only"] == "yes",
        )
        require_release_ready = options["require-release-ready"] == "yes"
        status_rows = nothing
        if options["release-status"] == "yes" || options["release-blockers"] == "yes" || options["release-status-json"] == "yes" || require_release_ready
            source = isempty(options["source"]) ? SURVEY : options["source"]
            rows = filter_rows(parity_rows(source); status=options["status"], family=options["family"])
            status_rows = rows
            content = options["release-status-json"] == "yes" ? render_release_status_json(rows) :
                options["release-blockers"] == "yes" ? render_release_blockers(rows) :
                render_release_status(rows)
        end
        write_output(options["output"], content)
        require_release_ready && assert_release_ready(status_rows)
        return 0
    catch error
        println(stderr, "reference parity matrix render: $(sprint(showerror, error))")
        return 1
    end
end

end # module ReferenceParityMatrixRender

if abspath(PROGRAM_FILE) == @__FILE__
    exit(ReferenceParityMatrixRender.main())
end
