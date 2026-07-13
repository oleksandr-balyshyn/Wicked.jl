#!/usr/bin/env julia

module WidgetPromotionRequirementsAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const LEDGER = joinpath(ROOT, "api", "widget_promotion_requirements.tsv")
const EXPECTED_HEADER = ["id", "area", "requirement", "evidence", "gate", "release_required"]
const VALID_AREAS = Set(["api", "behavior", "docs", "examples", "semantics", "toolkit", "performance", "release"])
const VALID_RELEASE_REQUIRED = Set(["yes", "no"])
const REQUIRED_RELEASE_AREAS = Set(["api", "behavior", "docs", "examples", "semantics", "toolkit", "performance", "release"])

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/widget_promotion_requirements_audit.jl [widget-promotion-requirements.tsv]")
    println(io, "")
    println(io, "Checks that widget promotion requirements are concrete, gated, and release-classified.")
end

function _relative(path::AbstractString)
    return relpath(path, ROOT)
end

function _valid_requirement_id(id::AbstractString)
    return occursin(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$", id)
end

function _gate_script_tokens(gate::AbstractString)
    scripts = String[]
    for command in split(gate, ';')
        stripped = strip(command)
        isempty(stripped) && continue
        token = first(split(stripped))
        startswith(token, "scripts/") && endswith(token, ".jl") && push!(scripts, String(token))
    end
    return scripts
end

function read_rows(path::AbstractString=LEDGER)
    isfile(path) || error("missing widget promotion requirements ledger: $(_relative(path))")

    rows = Dict{String,NamedTuple{(:area,:requirement,:evidence,:gate,:release_required),NTuple{5,String}}}()
    failures = String[]
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

        if length(fields) != length(EXPECTED_HEADER)
            push!(
                failures,
                "$(_relative(path)):$offset has $(length(fields)) fields; expected $(length(EXPECTED_HEADER))",
            )
            continue
        end

        id, area, requirement, evidence, gate, release_required = fields

        _valid_requirement_id(id) || push!(
            failures,
            "$(_relative(path)):$offset has invalid requirement id `$id`",
        )
        area in VALID_AREAS || push!(
            failures,
            "$(_relative(path)):$offset has invalid area `$area`",
        )
        isempty(strip(requirement)) && push!(
            failures,
            "$(_relative(path)):$offset has empty requirement",
        )
        isempty(strip(evidence)) && push!(
            failures,
            "$(_relative(path)):$offset has empty evidence",
        )
        isempty(strip(gate)) && push!(
            failures,
            "$(_relative(path)):$offset has empty gate",
        )
        gate_scripts = _gate_script_tokens(gate)
        isempty(gate_scripts) && !isempty(strip(gate)) && push!(
            failures,
            "$(_relative(path)):$offset gate must reference at least one scripts/*.jl command",
        )
        for script in gate_scripts
            isfile(joinpath(ROOT, script)) || push!(
                failures,
                "$(_relative(path)):$offset references missing gate script `$script`",
            )
        end
        release_required in VALID_RELEASE_REQUIRED || push!(
            failures,
            "$(_relative(path)):$offset has invalid release_required `$release_required`",
        )

        if haskey(rows, id)
            push!(
                failures,
                "$(_relative(path)):$offset duplicates widget promotion requirement `$id`",
            )
        else
            rows[id] = (
                area=String(area),
                requirement=String(requirement),
                evidence=String(evidence),
                gate=String(gate),
                release_required=String(release_required),
            )
        end
    end

    saw_header || push!(failures, "$(_relative(path)) is missing the expected header")
    return rows, failures
end

function audit(path::AbstractString=LEDGER)
    rows, failures = read_rows(path)
    release_areas = Set(row.area for row in values(rows) if row.release_required == "yes")

    for area in sort!(collect(setdiff(REQUIRED_RELEASE_AREAS, release_areas)))
        push!(
            failures,
            "$(_relative(path)) has no release-required widget promotion requirement for `$area`",
        )
    end

    return failures, rows
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    if length(arguments) > 1
        print_usage(stderr)
        return 2
    end

    path = isempty(arguments) ? LEDGER : first(arguments)
    failures, rows = audit(path)
    if isempty(failures)
        println("widget promotion requirements audit: $(length(rows)) requirements")
        return 0
    end

    for failure in failures
        println(stderr, "widget promotion requirements audit: $failure")
    end
    return 1
end

end # module WidgetPromotionRequirementsAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(WidgetPromotionRequirementsAudit.main())
end
