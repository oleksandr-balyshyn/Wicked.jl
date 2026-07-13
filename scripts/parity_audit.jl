#!/usr/bin/env julia

module ParityAudit

using Wicked

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SURVEY_PATH = joinpath(ROOT, "docs", "REFERENCE_PARITY_SURVEY.md")
const FEATURE_PARITY_PATH = joinpath(ROOT, "docs", "FEATURE_PARITY.md")
const RELEASE_CHECKLIST_PATH = joinpath(ROOT, "docs", "RELEASE_CHECKLIST.md")
const EXECUTION_PLAN_PATH = joinpath(ROOT, "docs", "PARITY_EXECUTION_PLAN.md")
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
    "Remote delivery",
)
const REFERENCE_LABEL_PATTERN = r"(?i)\b(ratatui|textual|tamboui|lanterna|intentional divergence)\b"

function normalize_follow_up(value::AbstractString)
    lowered = lowercase(strip(value))
    lowered = replace(lowered, r"`" => "")
    lowered = replace(lowered, r"\s+" => " ")
    lowered = replace(lowered, r"[.:;,\s]+$" => "")
    return lowered
end

function release_checklist_items()
    isfile(RELEASE_CHECKLIST_PATH) || error("missing release checklist file: $(relpath(RELEASE_CHECKLIST_PATH, ROOT))")
    items = Set{String}()
    current = nothing
    for line in readlines(RELEASE_CHECKLIST_PATH)
        matched = match(r"^\s*-\s+\[[ xX]\]\s+(.+)$", line)
        if matched !== nothing
            current !== nothing && push!(items, normalize_follow_up(current))
            current = matched.captures[1]
            continue
        end
        if current !== nothing
            continuation = match(r"^\s{2,}(\S.*)$", line)
            if continuation !== nothing
                current *= " " * continuation.captures[1]
                continue
            end
            push!(items, normalize_follow_up(current))
            current = nothing
        end
    end
    current !== nothing && push!(items, normalize_follow_up(current))
    return items
end

function feature_parity_notes()
    isfile(FEATURE_PARITY_PATH) || error("missing feature parity ledger: $(relpath(FEATURE_PARITY_PATH, ROOT))")
    lines = readlines(FEATURE_PARITY_PATH)
    start = findfirst(l -> occursin(r"^\|\s*Family\s*\|\s*Parity note\s*\|\s*Migration note\s*\|", l), lines)
    start === nothing && error("feature parity ledger missing Reference-library adaptation notes table")
    notes = Dict{String,NamedTuple{(:parity,:migration),Tuple{String,String}}}()
    for offset in (start + 1):length(lines)
        line = strip(lines[offset])
        isempty(line) && break
        startswith(line, "|") || break
        startswith(line, "|---") && continue
        values = split_table_row(line)
        length(values) < 3 && continue
        family = values[1]
        haskey(notes, family) && error("duplicate feature parity note for family: $family")
        notes[family] = (parity=values[2], migration=values[3])
    end
    return notes
end

function tracked_follow_up_kind(value::AbstractString, checklist_items::Set{String})
    follow_up = strip(value)
    isempty(follow_up) && return :missing
    occursin("#", follow_up) && return :issue
    lowered = lowercase(follow_up)
    prefix = "release checklist:"
    startswith(lowered, prefix) || return :untracked
    cited = normalize_follow_up(follow_up[(lastindex(prefix) + 1):end])
    cited in checklist_items && return :release_checklist
    return :missing_release_checklist_item
end

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

function execution_plan_failures()
    isfile(EXECUTION_PLAN_PATH) || return String[
        "missing parity execution plan: $(relpath(EXECUTION_PLAN_PATH, ROOT))",
    ]
    survey_source = isfile(SURVEY_PATH) ? read(SURVEY_PATH, String) : ""
    source = read(EXECUTION_PLAN_PATH, String)
    failures = String[]
    for family in REQUIRED_FAMILIES
        occursin("| $family |", source) || push!(
            failures,
            "parity execution plan missing survey family coverage row: $family",
        )
    end
    for required_reference in (
        "docs/REFERENCE_PARITY_SURVEY.md",
        "docs/FEATURE_PARITY.md",
        "docs/VALIDATION_STRATEGY.md",
        "docs/RELEASE_EVIDENCE.md",
    )
        occursin(required_reference, source) || push!(
            failures,
            "parity execution plan must reference $required_reference",
        )
    end
    occursin("exact release-checklist checkbox", survey_source) ||
        push!(failures, "parity survey must allow exact release-checklist checkbox follow-ups")
    occursin("release-checklist checkbox items", source) ||
        push!(failures, "parity execution plan must allow exact release-checklist checkbox follow-ups")
    return failures
end

function check_reference_parity()
    rows = try
        parse_parity_survey()
    catch error
        return String[error.msg]
    end
    checklist_items = try
        release_checklist_items()
    catch error
        return String[error.msg]
    end
    feature_notes = try
        feature_parity_notes()
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
            kind = tracked_follow_up_kind(follow_up, checklist_items)
            kind == :missing && push!(failures, "$family status=$status requires explicit follow-up")
            kind == :untracked && push!(
                failures,
                "$family status=$status follow-up must cite an issue or release checklist item",
            )
            kind == :missing_release_checklist_item && push!(
                failures,
                "$family status=$status follow-up cites a missing release checklist item: $follow_up",
            )
            note = get(feature_notes, family, nothing)
            if note === nothing
                push!(
                    failures,
                    "$family status=$status requires a migration/parity note in docs/FEATURE_PARITY.md",
                )
            else
                isempty(strip(note.parity)) && push!(
                    failures,
                    "$family feature parity row must include a parity note",
                )
                isempty(strip(note.migration)) && push!(
                    failures,
                    "$family feature parity row must include a migration note",
                )
                occursin(REFERENCE_LABEL_PATTERN, note.parity) || push!(
                    failures,
                    "$family feature parity note must mention Ratatui, Textual, TamboUI, Lanterna, or intentional divergence",
                )
            end
        end
        direction = strip(get(record, "direction", ""))
        isempty(direction) && push!(failures, "$family missing implementation direction")
    end

    append!(failures, execution_plan_failures())

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
