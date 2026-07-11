#!/usr/bin/env julia

using Wicked

const ROOT = normpath(joinpath(@__DIR__, ".."))
const COVERAGE_PATH = joinpath(ROOT, "api", "widget_coverage.tsv")
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
const BASE_COLUMNS = ("widget_type", "stateless", "stateful", "source")
const ALL_COLUMNS = (BASE_COLUMNS..., COVERAGE_COLUMNS...)

function relative_source(file)
    path = normpath(String(file))
    return startswith(path, ROOT) ? relpath(path, ROOT) : path
end

function widget_inventory()
    records = Dict{String,NamedTuple{(:stateless,:stateful,:sources),Tuple{Bool,Bool,Set{String}}}}()
    for method in methods(Wicked.render!)
        signature = Base.unwrap_unionall(method.sig)
        parameters = signature.parameters
        length(parameters) >= 4 || continue
        buffer_type = parameters[2]
        buffer_type isa Type && buffer_type <: Wicked.Buffer || continue
        widget_type = parameters[3]
        widget_type isa Type || widget_type isa UnionAll || continue
        widget_type in (Any, Wicked.Buffer, Wicked.Frame) && continue
        startswith(string(parentmodule(widget_type)), "Wicked") || continue

        name = string(widget_type)
        current = get(
            records,
            name,
            (stateless=false, stateful=false, sources=Set{String}()),
        )
        sources = copy(current.sources)
        push!(sources, relative_source(method.file))
        records[name] = (
            stateless=current.stateless || length(parameters) == 4,
            stateful=current.stateful || length(parameters) >= 5,
            sources,
        )
    end
    return records
end

function direct_interaction_inventory()
    interactions = Dict{String,Set{String}}()
    for method in methods(Wicked.handle!)
        signature = Base.unwrap_unionall(method.sig)
        parameters = signature.parameters
        length(parameters) >= 4 || continue
        widget_type = parameters[3]
        event_type = parameters[4]
        widget_type isa Type || widget_type isa UnionAll || continue
        event_type isa Type || continue
        startswith(string(parentmodule(widget_type)), "Wicked") || continue
        accepted = get!(interactions, string(widget_type), Set{String}())
        Wicked.KeyEvent <: event_type && push!(accepted, "keyboard")
        Wicked.MouseEvent <: event_type && push!(accepted, "pointer")
    end
    return interactions
end

function read_coverage()
    isfile(COVERAGE_PATH) || return String[], Dict{String,Dict{String,String}}()
    lines = readlines(COVERAGE_PATH)
    isempty(lines) && return String[], Dict{String,Dict{String,String}}()
    header = split(first(lines), '\t'; keepempty=true)
    rows = Dict{String,Dict{String,String}}()
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        line_number = offset + 1
        isempty(strip(line)) && continue
        values = split(line, '\t'; keepempty=true)
        length(values) == length(header) || error(
            "$(relpath(COVERAGE_PATH, ROOT)):$line_number has $(length(values)) fields; expected $(length(header))",
        )
        row = Dict(zip(header, values))
        name = get(row, "widget_type", "")
        isempty(name) && error("$(relpath(COVERAGE_PATH, ROOT)):$line_number has no widget_type")
        haskey(rows, name) && error("duplicate widget coverage row: $name")
        rows[name] = row
    end
    return header, rows
end

function write_coverage!()
    inventory = widget_inventory()
    _, existing = read_coverage()
    mkpath(dirname(COVERAGE_PATH))
    open(COVERAGE_PATH, "w") do io
        println(io, join(ALL_COLUMNS, '\t'))
        for name in sort!(collect(keys(inventory)))
            record = inventory[name]
            previous = get(existing, name, Dict{String,String}())
            values = String[
                name,
                string(record.stateless),
                string(record.stateful),
                join(sort!(collect(record.sources)), ','),
            ]
            append!(values, (get(previous, column, "missing") for column in COVERAGE_COLUMNS))
            println(io, join(values, '\t'))
        end
    end
    println("widget audit: wrote $(length(inventory)) renderable types to $(relpath(COVERAGE_PATH, ROOT))")
end

function validate_evidence(value::String)
    value == "missing" && return nothing
    startswith(value, "n/a:") && length(value) > 4 && return nothing
    startswith(value, "test/") || return "must be missing, n/a:<reason>, or test/<file>.jl:<testset>"
    separator = findfirst(':', value)
    separator === nothing && return "test evidence must include a testset after ':'"
    path = value[1:(separator - 1)]
    isfile(joinpath(ROOT, path)) || return "test evidence file does not exist: $path"
    separator < lastindex(value) || return "test evidence must name a testset"
    return nothing
end

function audit(; require_complete::Bool=false)
    inventory = widget_inventory()
    interactions = direct_interaction_inventory()
    header, rows = read_coverage()
    failures = String[]
    header == collect(ALL_COLUMNS) || push!(
        failures,
        "coverage header does not match the required schema; run with --write-baseline",
    )

    inventory_names = Set(keys(inventory))
    row_names = Set(keys(rows))
    for name in sort!(collect(setdiff(inventory_names, row_names)))
        push!(failures, "renderable type is missing from coverage ledger: $name")
    end
    for name in sort!(collect(setdiff(row_names, inventory_names)))
        push!(failures, "coverage ledger contains a stale renderable type: $name")
    end

    missing = Pair{String,String}[]
    for name in sort!(collect(intersect(inventory_names, row_names)))
        record = inventory[name]
        row = rows[name]
        expected = Dict(
            "stateless" => string(record.stateless),
            "stateful" => string(record.stateful),
            "source" => join(sort!(collect(record.sources)), ','),
        )
        for (column, value) in expected
            get(row, column, "") == value || push!(
                failures,
                "$name has stale $column metadata; run with --write-baseline",
            )
        end
        for column in COVERAGE_COLUMNS
            value = get(row, column, "missing")
            problem = validate_evidence(value)
            problem === nothing || push!(failures, "$name $column $problem")
            value == "missing" && push!(missing, name => column)
        end
        for column in get(interactions, name, Set{String}())
            value = get(row, column, "missing")
            value == "missing" && push!(
                failures,
                "$name implements $column input but has no evidence",
            )
            startswith(value, "n/a:") && push!(
                failures,
                "$name implements $column input and cannot mark it non-applicable",
            )
        end
        if record.stateful
            value = get(row, "state_transition", "missing")
            value == "missing" && push!(
                failures,
                "$name has stateful rendering but no state-transition evidence",
            )
            startswith(value, "n/a:") && push!(
                failures,
                "$name has stateful rendering and cannot mark state transitions non-applicable",
            )
        end
        toolkit_value = get(row, "toolkit", "missing")
        toolkit_value == "missing" && push!(
            failures,
            "$name has direct rendering but no Toolkit interoperability evidence",
        )
        startswith(toolkit_value, "n/a:") && push!(
            failures,
            "$name has direct rendering and cannot mark Toolkit interoperability non-applicable",
        )
        semantics_value = get(row, "semantics", "missing")
        semantics_value == "missing" && push!(
            failures,
            "$name has direct rendering but no semantic-tree evidence",
        )
        startswith(semantics_value, "n/a:") && push!(
            failures,
            "$name has direct rendering and cannot mark semantics non-applicable",
        )
        snapshot_value = get(row, "snapshot", "missing")
        snapshot_value == "missing" && push!(
            failures,
            "$name has direct rendering but no golden snapshot evidence",
        )
        startswith(snapshot_value, "n/a:") && push!(
            failures,
            "$name has direct rendering and cannot mark snapshots non-applicable",
        )
    end

    if require_complete && !isempty(missing)
        append!(failures, ("missing widget evidence: $(entry.first) $(entry.second)" for entry in missing))
    end
    if isempty(failures)
        total = length(inventory) * length(COVERAGE_COLUMNS)
        covered = total - length(missing)
        println(
            "widget audit: inventory passed; $covered/$total coverage dimensions recorded, $(length(missing)) missing",
        )
        return 0
    end
    foreach(message -> println(stderr, "widget audit: ", message), failures)
    return 1
end

function main(arguments=ARGS)
    write_baseline = "--write-baseline" in arguments
    require_complete = "--require-complete" in arguments
    known = Set(("--write-baseline", "--require-complete"))
    unknown = String[argument for argument in arguments if argument ∉ known]
    isempty(unknown) || error("unknown widget audit arguments: $(join(unknown, ", "))")
    write_baseline && write_coverage!()
    return audit(; require_complete)
end

exit(main())
