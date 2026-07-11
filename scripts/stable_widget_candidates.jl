#!/usr/bin/env julia

const ROOT = normpath(joinpath(@__DIR__, ".."))
const COVERAGE_PATH = joinpath(ROOT, "api", "widget_coverage.tsv")
const STABLE_API_PATH = joinpath(ROOT, "api", "stable_api.tsv")
const EXPERIMENTAL_API_PATH = joinpath(ROOT, "api", "experimental_api.tsv")
const REPORT_PATH = joinpath(ROOT, "api", "stable_widget_candidates.tsv")

const COVERAGE_COLUMNS = (
    "zero_size",
    "minimal",
    "clipped",
    "resize",
    "state_transition",
    "snapshot",
    "toolkit",
    "semantics",
    "keyboard",
    "pointer",
)

function read_api_names(path)
    isfile(path) || error("missing API ledger: $(relpath(path, ROOT))")
    names = Set{String}()
    for line in readlines(path)
        stripped = strip(line)
        isempty(stripped) && continue
        startswith(stripped, "#") && continue
        fields = split(stripped, '\t'; keepempty=true)
        length(fields) >= 2 || error("invalid API ledger row in $(relpath(path, ROOT)): $line")
        push!(names, String(fields[1]))
    end
    return names
end

function read_widget_coverage()
    isfile(COVERAGE_PATH) || error("missing widget coverage ledger: $(relpath(COVERAGE_PATH, ROOT))")
    lines = readlines(COVERAGE_PATH)
    isempty(lines) && error("empty widget coverage ledger: $(relpath(COVERAGE_PATH, ROOT))")
    header = split(first(lines), '\t'; keepempty=true)
    rows = Vector{Dict{String,String}}()
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        isempty(strip(line)) && continue
        values = split(line, '\t'; keepempty=true)
        length(values) == length(header) || error(
            "$(relpath(COVERAGE_PATH, ROOT)):$(offset + 1) has $(length(values)) fields; expected $(length(header))",
        )
        push!(rows, Dict(String(key) => String(value) for (key, value) in zip(header, values)))
    end
    return rows
end

function bare_name(qualified::AbstractString)
    text = String(qualified)
    prefix = "Wicked."
    startswith(text, prefix) && (text = text[(lastindex(prefix) + 1):end])
    parts = split(text, '.')
    return String(last(parts))
end

function evidence_status(row)
    missing = String[]
    nonapplicable = String[]
    for column in COVERAGE_COLUMNS
        value = get(row, column, "missing")
        value == "missing" && push!(missing, column)
        startswith(value, "n/a:") && push!(nonapplicable, column)
    end
    if !isempty(missing)
        return "blocked", "missing evidence: $(join(missing, ","))"
    end
    if get(row, "toolkit", "missing") == "missing" || startswith(get(row, "toolkit", ""), "n/a:")
        return "blocked", "missing Toolkit interoperability evidence"
    end
    if get(row, "semantics", "missing") == "missing" || startswith(get(row, "semantics", ""), "n/a:")
        return "blocked", "missing semantic-tree evidence"
    end
    if get(row, "snapshot", "missing") == "missing" || startswith(get(row, "snapshot", ""), "n/a:")
        return "blocked", "missing snapshot evidence"
    end
    if lowercase(get(row, "stateful", "false")) == "true"
        value = get(row, "state_transition", "missing")
        (value == "missing" || startswith(value, "n/a:")) &&
            return "blocked", "missing state-transition evidence"
    end
    if isempty(nonapplicable)
        return "complete", "all widget evidence dimensions recorded"
    end
    return "complete", "all required evidence recorded; non-applicable: $(join(nonapplicable, ","))"
end

function candidate_rows()
    stable = read_api_names(STABLE_API_PATH)
    experimental = read_api_names(EXPERIMENTAL_API_PATH)
    rows = read_widget_coverage()
    output = Vector{NamedTuple{(:widget,:source,:surface,:status,:reason),NTuple{5,String}}}()
    for row in rows
        qualified = get(row, "widget_type", "")
        widget = bare_name(qualified)
        source = get(row, "source", "")
        if widget in stable
            push!(output, (widget=widget, source=source, surface="stable", status="stable", reason="already exported by Wicked.API"))
            continue
        end
        status, reason = evidence_status(row)
        if widget in experimental
            surface = "experimental"
            promotion_status = status == "complete" ? "candidate" : "blocked"
            push!(output, (widget=widget, source=source, surface=surface, status=promotion_status, reason=reason))
        else
            push!(output, (widget=widget, source=source, surface="internal", status="blocked", reason="renderable is not exported by Wicked.API or Wicked.Experimental"))
        end
    end
    return sort!(output; by=row -> (row.status, row.widget))
end

function write_report!(rows)
    mkpath(dirname(REPORT_PATH))
    open(REPORT_PATH, "w") do io
        println(io, "widget\tsource\tsurface\tstatus\treason")
        for row in rows
            println(io, join((row.widget, row.source, row.surface, row.status, row.reason), '\t'))
        end
    end
    println("stable widget candidates: wrote $(length(rows)) rows to $(relpath(REPORT_PATH, ROOT))")
end

function print_summary(rows)
    counts = Dict{String,Int}()
    for row in rows
        counts[row.status] = get(counts, row.status, 0) + 1
    end
    for status in sort!(collect(keys(counts)))
        println("stable widget candidates: $status $(counts[status])")
    end
    candidates = [row for row in rows if row.status == "candidate"]
    if !isempty(candidates)
        println("stable widget candidates: promotion candidates")
        for row in candidates
            println("  - $(row.widget) ($(row.source))")
        end
    end
end

function main(arguments=ARGS)
    write = "--write-report" in arguments
    known = Set(["--write-report"])
    unknown = [argument for argument in arguments if argument ∉ known]
    isempty(unknown) || error("unknown arguments: $(join(unknown, ", "))")
    rows = candidate_rows()
    print_summary(rows)
    write && write_report!(rows)
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
