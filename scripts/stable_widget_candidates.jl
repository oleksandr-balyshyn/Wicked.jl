#!/usr/bin/env julia

using Wicked

const ROOT = normpath(joinpath(@__DIR__, ".."))
const COVERAGE_PATH = joinpath(ROOT, "api", "widget_coverage.tsv")
const STABLE_API_PATH = joinpath(ROOT, "api", "stable_api.tsv")
const EXPERIMENTAL_API_PATH = joinpath(ROOT, "api", "experimental_api.tsv")
const EXPERIMENTAL_PROMOTION_LEDGER = joinpath(ROOT, "api", "experimental_promotions.tsv")
const REPORT_PATH = joinpath(ROOT, "api", "stable_widget_candidates.tsv")

isdefined(@__MODULE__, :ExperimentalPromotionAudit) ||
    include(joinpath(ROOT, "scripts", "experimental_promotion_audit.jl"))

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

function read_api_kinds(path)
    isfile(path) || error("missing API ledger: $(relpath(path, ROOT))")
    kinds = Dict{String,String}()
    for line in readlines(path)
        stripped = strip(line)
        isempty(stripped) && continue
        startswith(stripped, "#") && continue
        fields = split(stripped, '\t'; keepempty=true)
        length(fields) >= 2 || error("invalid API ledger row in $(relpath(path, ROOT)): $line")
        kinds[String(fields[1])] = String(fields[2])
    end
    return kinds
end

read_api_names(path) = Set(keys(read_api_kinds(path)))

stable_widget_binding(kind::AbstractString) = kind in ("datatype", "unionall")

function read_experimental_promotion_plan(path::AbstractString=EXPERIMENTAL_PROMOTION_LEDGER)
    rows, failures = ExperimentalPromotionAudit.read_rows(path)
    isempty(failures) || error(join(failures, "\n"))
    return rows
end

function read_widget_coverage(path::AbstractString=COVERAGE_PATH)
    isfile(path) || error("missing widget coverage ledger: $(relpath(path, ROOT))")
    lines = readlines(path)
    isempty(lines) && error("empty widget coverage ledger: $(relpath(path, ROOT))")
    header = split(first(lines), '\t'; keepempty=true)
    rows = Vector{Dict{String,String}}()
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        isempty(strip(line)) && continue
        values = split(line, '\t'; keepempty=true)
        length(values) == length(header) || error(
            "$(relpath(path, ROOT)):$(offset + 1) has $(length(values)) fields; expected $(length(header))",
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

normalized_type_name(value) = first(split(string(value), '{'; limit=2))

function public_state_for_names()
    names = Set{String}()
    for method in methods(Wicked.API.state_for)
        signature = Base.unwrap_unionall(method.sig)
        parameters = signature.parameters
        length(parameters) >= 2 || continue
        widget_type = parameters[2]
        (widget_type isa Type || widget_type isa UnionAll) || continue
        widget_type === Any && continue
        startswith(string(parentmodule(widget_type)), "Wicked") || continue
        push!(names, bare_name(normalized_type_name(widget_type)))
    end
    return names
end

function evidence_source_paths(value::AbstractString)
    paths = String[]
    for token in split(value, r"[\s,;]+")
        cleaned = strip(token, ['`', '\'', '"', '(', ')', '[', ']'])
        match = findfirst(".jl", cleaned)
        match === nothing && continue
        push!(paths, String(cleaned[firstindex(cleaned):last(match)]))
    end
    return unique(paths)
end

function evidence_source_status(path::AbstractString; root::AbstractString=ROOT)
    isempty(strip(path)) &&
        return "blocked", "empty evidence source path"
    isabspath(path) &&
        return "blocked", "evidence source path must be repository-relative: $path"
    normalized = normpath(path)
    (normalized == "." || normalized == ".." || startswith(normalized, "../")) &&
        return "blocked", "evidence source path must stay inside the repository: $path"
    endswith(normalized, ".jl") ||
        return "blocked", "evidence source path must point to a Julia source file: $path"
    isfile(joinpath(root, normalized)) ||
        return "blocked", "missing evidence source file: $path"
    return "complete", "evidence source file exists"
end

function evidence_cell_status(column::AbstractString, value::AbstractString; root::AbstractString=ROOT)
    normalized = lowercase(strip(value))
    normalized in ("ok", "yes", "done", "complete", "covered", "tested", "pass", "passes") &&
        return "blocked", "$column evidence must cite a checked-in Julia source file, not generic status `$value`"
    paths = evidence_source_paths(value)
    isempty(paths) &&
        return "blocked", "$column evidence must cite at least one checked-in Julia source file"
    for path in paths
        status, reason = evidence_source_status(path; root=root)
        status == "complete" || return status, "$column evidence $reason"
    end
    return "complete", "evidence cites checked-in Julia source"
end

function nonapplicable_status(column::AbstractString, value::AbstractString)
    reason = strip(chopprefix(value, "n/a:"))
    isempty(reason) &&
        return "blocked", "$column non-applicable evidence must include a reason"
    lowercase(reason) in ("todo", "tbd", "none", "na", "n/a") &&
        return "blocked", "$column non-applicable evidence has placeholder reason `$reason`"
    length(reason) < 8 &&
        return "blocked", "$column non-applicable evidence reason is too short"
    return "complete", "non-applicable evidence includes a reason"
end

function evidence_status(row, state_factories; root::AbstractString=ROOT)
    missing = String[]
    nonapplicable = String[]
    for column in COVERAGE_COLUMNS
        value = get(row, column, "missing")
        value == "missing" && push!(missing, column)
        if startswith(value, "n/a:")
            status, reason = nonapplicable_status(column, value)
            status == "complete" || return status, reason
            push!(nonapplicable, column)
        elseif value != "missing"
            status, reason = evidence_cell_status(column, value; root=root)
            status == "complete" || return status, reason
        end
    end
    if !isempty(missing)
        return "blocked", "missing evidence: $(join(missing, ","))"
    end
    if lowercase(get(row, "stateful", "false")) == "true"
        widget = bare_name(get(row, "widget_type", ""))
        widget in state_factories ||
            return "blocked", "missing public state_for method"
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

function source_file_status(row; root::AbstractString=ROOT)
    source = get(row, "source", "")
    isempty(strip(source)) &&
        return "blocked", "missing widget source path"
    isabspath(source) &&
        return "blocked", "widget source path must be repository-relative"
    normalized = normpath(source)
    (normalized == "." || normalized == ".." || startswith(normalized, "../")) &&
        return "blocked", "widget source path must stay inside the repository"
    endswith(normalized, ".jl") ||
        return "blocked", "widget source path must point to a Julia source file"
    isfile(joinpath(root, normalized)) ||
        return "blocked", "missing widget source file: $source"
    return "complete", "widget source file exists"
end

function compatibility_candidate_row(widget, source, status, reason, promotion_plan)
    surface = "compatibility"
    plan = get(promotion_plan, widget, nothing)
    if plan === nothing
        return (
            widget=widget,
            source=source,
            surface=surface,
            status="blocked",
            reason="missing experimental promotion/removal plan",
        )
    end
    if !(plan.review_status in ("accepted", "completed"))
        return (
            widget=widget,
            source=source,
            surface=surface,
            status="blocked",
            reason="experimental promotion/removal plan must be accepted or completed before candidate promotion",
        )
    end
    promotion_status = status == "complete" ? "candidate" : "blocked"
    promotion_reason = status == "complete" ? "$(plan.decision) to $(plan.target): $(plan.notes)" : reason
    return (
        widget=widget,
        source=source,
        surface=surface,
        status=promotion_status,
        reason=promotion_reason,
    )
end

function candidate_rows(;
    stable_path::AbstractString=STABLE_API_PATH,
    compatibility_path::AbstractString=EXPERIMENTAL_API_PATH,
    promotion_path::AbstractString=EXPERIMENTAL_PROMOTION_LEDGER,
    coverage_path::AbstractString=COVERAGE_PATH,
    source_root::AbstractString=ROOT,
    state_factories=public_state_for_names(),
)
    stable_kinds = read_api_kinds(stable_path)
    stable = Set(keys(stable_kinds))
    compatibility = read_api_names(compatibility_path)
    promotion_plan = read_experimental_promotion_plan(promotion_path)
    rows = read_widget_coverage(coverage_path)
    output = Vector{NamedTuple{(:widget,:source,:surface,:status,:reason),NTuple{5,String}}}()
    for row in rows
        qualified = get(row, "widget_type", "")
        widget = bare_name(qualified)
        source = get(row, "source", "")
        source_status, source_reason = source_file_status(row; root=source_root)
        status, reason = source_status == "complete" ? evidence_status(row, state_factories; root=source_root) : (source_status, source_reason)
        if widget in stable
            stable_kind = get(stable_kinds, widget, "")
            stable_status = status == "complete" && stable_widget_binding(stable_kind) ? "stable" : "blocked"
            stable_reason = if !stable_widget_binding(stable_kind)
                "stable widget must be a concrete or parameterized Wicked.API type binding, found `$(isempty(stable_kind) ? "missing" : stable_kind)`"
            elseif status == "complete"
                "exported by Wicked.API; evidence complete"
            else
                reason
            end
            push!(output, (widget=widget, source=source, surface="stable", status=stable_status, reason=stable_reason))
            continue
        end
        if widget in compatibility
            push!(output, compatibility_candidate_row(widget, source, status, reason, promotion_plan))
        else
            push!(output, (widget=widget, source=source, surface="internal", status="blocked", reason="renderable is not exported by Wicked.API or a reviewed compatibility namespace"))
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
    require_stable = "--require-stable" in arguments
    known = Set(["--write-report", "--require-stable"])
    unknown = [argument for argument in arguments if argument ∉ known]
    isempty(unknown) || error("unknown arguments: $(join(unknown, ", "))")
    rows = candidate_rows()
    print_summary(rows)
    write && write_report!(rows)
    if require_stable
        failures = [row for row in rows if row.status != "stable"]
        if !isempty(failures)
            for row in failures
                println(stderr, "stable widget candidates: $(row.widget) is $(row.status) on $(row.surface): $(row.reason)")
            end
            return 1
        end
    end
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
