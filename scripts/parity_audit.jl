#!/usr/bin/env julia

module ParityAudit

using Wicked

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SURVEY_PATH = joinpath(ROOT, "docs", "REFERENCE_PARITY_SURVEY.md")
const VALID_STATUSES = (
    "matched",
    "adapted",
    "intentional divergence",
    "not yet implemented",
)
const REQUIRED_FAMILIES = (
    "Core rendering",
    "Layout",
    "Input/event",
    "Stateful controls",
    "Data displays",
    "Runtime",
    "Developer experience",
    "Styling/theming",
)

function split_table_row(line::AbstractString)
    raw = split(line, "|")
    values = String[]
    for value in raw
        value = strip(value)
        !isempty(value) && push!(values, value)
    end
    return values
end

function parse_parity_survey()
    isfile(SURVEY_PATH) || error("missing parity survey file: $(relpath(SURVEY_PATH, ROOT))")
    lines = readlines(SURVEY_PATH)
    start = findfirst(l -> occursin(r"^\|\s*Family\b", l), lines)
    start === nothing && error("parity survey table missing Family header")

    rows = Dict{String,Dict{String,String}}()
    for offset in (start + 1):length(lines)
        line = strip(lines[offset])
        isempty(line) && break
        startswith(line, "|") || break
        if startswith(line, "| ---")
            continue
        end
        values = split_table_row(line)
        length(values) < 8 && continue
        family = values[1]
        status = lowercase(values[7])
        direction = values[6]
        follow_up = values[8]
        haskey(rows, family) && error("duplicate parity row for family: $family")
        rows[family] = Dict(
            "status" => status,
            "direction" => direction,
            "follow_up" => follow_up,
        )
    end
    return rows
end

function check_reference_parity()
    rows = try
        parse_parity_survey()
    catch error
        return String[error.msg]
    end

    failures = String[]

    for family in REQUIRED_FAMILIES
        row = get(rows, family, nothing)
        row === nothing && push!(failures, "parity survey missing required family: $family")
    end

    for (family, record) in rows
        status = get(record, "status", "")
        status in VALID_STATUSES || push!(failures, "$family has invalid parity status: $status")
        if status in ("adapted", "intentional divergence", "not yet implemented")
            follow_up = strip(get(record, "follow_up", ""))
            isempty(follow_up) && push!(failures, "$family status=$status requires explicit follow-up")
        end
        direction = strip(get(record, "direction", ""))
        isempty(direction) && push!(failures, "$family missing implementation direction")
    end

    return failures
end

end

function main()
    failures = ParityAudit.check_reference_parity()
    if isempty(failures)
        println("parity audit: checked $(length(ParityAudit.REQUIRED_FAMILIES)) required families")
        return 0
    end
    foreach(message -> println(stderr, "parity audit: ", message), failures)
    return 1
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
