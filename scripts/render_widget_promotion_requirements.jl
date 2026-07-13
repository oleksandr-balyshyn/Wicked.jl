#!/usr/bin/env julia

module WidgetPromotionRequirementsRender

const ROOT = normpath(joinpath(@__DIR__, ".."))
const LEDGER = joinpath(ROOT, "api", "widget_promotion_requirements.tsv")
const EXPECTED_HEADER = ["id", "area", "requirement", "evidence", "gate", "release_required"]
const VALID_FORMATS = Set(["json", "markdown", "tsv"])
const VALID_RELEASE_FILTERS = Set(["all", "yes", "no"])

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/render_widget_promotion_requirements.jl [options]")
    println(io, "")
    println(io, "Renders the widget promotion requirements ledger for release review.")
    println(io, "")
    println(io, "Options:")
    println(io, "  --format <json|markdown|tsv>  Output format. Default: markdown")
    println(io, "  --area <name>                 Filter by requirement area")
    println(io, "  --release-required <all|yes|no>")
    println(io, "                                Filter by release_required. Default: all")
    println(io, "  --no-header                   Omit TSV header")
    println(io, "  --output <path>               Write output to a file")
    println(io, "  --help, -h                    Show this help")
end

function parse_args(arguments)
    options = Dict(
        "format" => "markdown",
        "area" => "",
        "release-required" => "all",
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
        argument in ("--format", "--area", "--release-required", "--output") ||
            error("unknown argument: $argument")
        index == length(arguments) && error("missing value for $argument")
        options[argument[3:end]] = arguments[index + 1]
        index += 2
    end

    format = lowercase(strip(options["format"]))
    format in VALID_FORMATS || error("--format must be json, markdown, or tsv")
    release_required = lowercase(strip(options["release-required"]))
    release_required in VALID_RELEASE_FILTERS || error("--release-required must be all, yes, or no")
    options["format"] = format
    options["release-required"] = release_required
    options["area"] = lowercase(strip(options["area"]))
    options["output"] = strip(options["output"])
    return options
end

function read_rows(path::AbstractString=LEDGER)
    isfile(path) || error("missing widget promotion requirements ledger: $(relpath(path, ROOT))")
    rows = NamedTuple[]
    saw_header = false
    for (offset, raw_line) in enumerate(readlines(path))
        line = strip(raw_line)
        isempty(line) && continue
        startswith(line, "#") && continue
        fields = split(raw_line, '\t'; keepempty=true)
        if fields == EXPECTED_HEADER
            saw_header = true
            continue
        end
        length(fields) == length(EXPECTED_HEADER) ||
            error("$(relpath(path, ROOT)):$offset has $(length(fields)) fields; expected $(length(EXPECTED_HEADER))")
        id, area, requirement, evidence, gate, release_required = fields
        push!(
            rows,
            (
                id=String(id),
                area=String(area),
                requirement=String(requirement),
                evidence=String(evidence),
                gate=String(gate),
                release_required=String(release_required),
            ),
        )
    end
    saw_header || error("$(relpath(path, ROOT)) is missing the expected header")
    return rows
end

function filter_rows(rows; area::AbstractString="", release_required::AbstractString="all")
    selected = rows
    if !isempty(area)
        selected = [row for row in selected if lowercase(row.area) == lowercase(area)]
    end
    if release_required != "all"
        selected = [row for row in selected if lowercase(row.release_required) == release_required]
    end
    return selected
end

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

function render_markdown(rows)
    lines = String[
        "| ID | Area | Requirement | Evidence | Gate | Release required |",
        "|---|---|---|---|---|---|",
    ]
    for row in rows
        push!(
            lines,
            "| $(markdown_escape(row.id)) | $(markdown_escape(row.area)) | $(markdown_escape(row.requirement)) | $(markdown_escape(row.evidence)) | $(markdown_escape(row.gate)) | $(markdown_escape(row.release_required)) |",
        )
    end
    return join(lines, "\n")
end

function render_tsv(rows; header::Bool=true)
    lines = String[]
    header && push!(lines, join(EXPECTED_HEADER, '\t'))
    for row in rows
        push!(
            lines,
            join((row.id, row.area, row.requirement, row.evidence, row.gate, row.release_required), '\t'),
        )
    end
    return join(lines, "\n")
end

function summary(rows)
    by_area = Dict{String,Int}()
    by_release_required = Dict{String,Int}()
    for row in rows
        by_area[row.area] = get(by_area, row.area, 0) + 1
        by_release_required[row.release_required] = get(by_release_required, row.release_required, 0) + 1
    end
    return (
        total=length(rows),
        by_area=sort!(collect(by_area); by=first),
        by_release_required=sort!(collect(by_release_required); by=first),
    )
end

function render_json_object_counts(lines, indentation, rows)
    for (index, (key, count)) in enumerate(rows)
        suffix = index == length(rows) ? "" : ","
        push!(lines, "$(indentation)$(json_escape(key)): $count$suffix")
    end
end

function render_json(rows)
    counts = summary(rows)
    lines = String[
        "{",
        "  \"schema_version\": 1,",
        "  \"summary\": {",
        "    \"total\": $(counts.total),",
        "    \"by_area\": {",
    ]
    render_json_object_counts(lines, "      ", counts.by_area)
    append!(
        lines,
        (
            "    },",
            "    \"by_release_required\": {",
        ),
    )
    render_json_object_counts(lines, "      ", counts.by_release_required)
    append!(
        lines,
        (
            "    }",
            "  },",
        ),
    )
    push!(
        lines,
        "  \"requirements\": [",
    )
    for (index, row) in enumerate(rows)
        suffix = index == length(rows) ? "" : ","
        push!(lines, "    {")
        push!(lines, "      \"id\": $(json_escape(row.id)),")
        push!(lines, "      \"area\": $(json_escape(row.area)),")
        push!(lines, "      \"requirement\": $(json_escape(row.requirement)),")
        push!(lines, "      \"evidence\": $(json_escape(row.evidence)),")
        push!(lines, "      \"gate\": $(json_escape(row.gate)),")
        push!(lines, "      \"release_required\": $(json_escape(row.release_required))")
        push!(lines, "    }$suffix")
    end
    push!(lines, "  ]")
    push!(lines, "}")
    return join(lines, "\n")
end

function render(; path::AbstractString=LEDGER, format::AbstractString="markdown", area::AbstractString="", release_required::AbstractString="all", header::Bool=true)
    rows = filter_rows(read_rows(path); area=area, release_required=release_required)
    format == "json" && return render_json(rows)
    format == "markdown" && return render_markdown(rows)
    format == "tsv" && return render_tsv(rows; header=header)
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
            format=options["format"],
            area=options["area"],
            release_required=options["release-required"],
            header=options["header"] == "yes",
        )
        write_output(options["output"], content)
        return 0
    catch error
        println(stderr, "widget promotion requirements render: $(sprint(showerror, error))")
        return 1
    end
end

end # module WidgetPromotionRequirementsRender

if abspath(PROGRAM_FILE) == @__FILE__
    exit(WidgetPromotionRequirementsRender.main())
end
