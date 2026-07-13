#!/usr/bin/env julia

module ReferenceParityMatrixSchemaAudit

include(joinpath(@__DIR__, "render_reference_parity_matrix.jl"))

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SCHEMA_PATH = joinpath(ROOT, "docs", "evidence", "reference_parity_matrix.schema.json")
const SUMMARY_SCHEMA_PATH = joinpath(ROOT, "docs", "evidence", "reference_parity_summary.schema.json")
const STATUS_SCHEMA_PATH = joinpath(ROOT, "docs", "evidence", "reference_parity_matrix_status.schema.json")
const REQUIRED_TOP_LEVEL_KEYS = ("schema_version", "summary", "rows")
const REQUIRED_SUMMARY_KEYS = ("total", "by_status")
const REQUIRED_ROW_KEYS = ("family", "ratatui", "textual", "tamboui", "lanterna", "wicked", "status", "follow_up")
const REQUIRED_STATUS_KEYS = ("schema_version", "release_ready", "total", "blocking", "blocking_families", "blocking_records")
const STATUSES_REQUIRING_ACTIONABLE_FOLLOW_UP = Set(("adapted", "intentional divergence", "not yet implemented"))
const REMOTE_DELIVERY_FAMILY = "Remote delivery"

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/reference_parity_matrix_schema_audit.jl [--release-check]")
    println(io, "")
    println(io, "Checks the reference parity matrix JSON schema and generated JSON contract.")
    println(io, "Use --release-check to reject rows that are not marked `matched`.")
end

function schema_failures(path::AbstractString=SCHEMA_PATH)
    failures = String[]
    isfile(path) || return ["missing reference parity matrix schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"summary\"",
        "\"total\"",
        "\"by_status\"",
        "\"rows\"",
        "\"family\"",
        "\"ratatui\"",
        "\"textual\"",
        "\"tamboui\"",
        "\"lanterna\"",
        "\"wicked\"",
        "\"status\"",
        "\"follow_up\"",
        "\"matched\"",
        "\"adapted\"",
        "\"intentional divergence\"",
        "\"not yet implemented\"",
        "\"additionalProperties\": false",
    )
        occursin(required, source) || push!(failures, "schema missing required contract token: $required")
    end
    return failures
end

function status_schema_failures(path::AbstractString=STATUS_SCHEMA_PATH)
    failures = String[]
    isfile(path) || return ["missing reference parity matrix status schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"release_ready\"",
        "\"total\"",
        "\"blocking\"",
        "\"blocking_families\"",
        "\"blocking_records\"",
        "\"follow_up\"",
        "\"additionalProperties\": false",
    )
        occursin(required, source) || push!(failures, "status schema missing required contract token: $required")
    end
    return failures
end

function summary_schema_failures(path::AbstractString=SUMMARY_SCHEMA_PATH)
    failures = String[]
    isfile(path) || return ["missing reference parity summary schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"total\"",
        "\"by_status\"",
        "\"additionalProperties\": false",
    )
        occursin(required, source) || push!(failures, "summary schema missing required contract token: $required")
    end
    return failures
end

function quoted_keys(source::AbstractString)
    return Set(String(match.captures[1]) for match in eachmatch(r"\"([A-Za-z_][A-Za-z0-9_]*)\"\s*:", source))
end

schema_keys(source::AbstractString) = quoted_keys(source)
generated_keys(source::AbstractString) = quoted_keys(source)

function key_contract_failures(schema_source::AbstractString, json_source::AbstractString)
    failures = String[]
    schema = schema_keys(schema_source)
    generated = generated_keys(json_source)
    for key in (REQUIRED_TOP_LEVEL_KEYS..., REQUIRED_SUMMARY_KEYS..., REQUIRED_ROW_KEYS...)
        key in schema || push!(failures, "schema is missing generated key `$key`")
        key in generated || push!(failures, "generated JSON is missing schema key `$key`")
    end
    return failures
end

function json_integer_value(source::AbstractString, key::AbstractString)
    matched = match(Regex("\"" * key * "\"\\s*:\\s*(\\d+)"), source)
    return matched === nothing ? nothing : parse(Int, matched.captures[1])
end

function row_status_values(source::AbstractString)
    return String[matched.captures[1] for matched in eachmatch(r"\"status\"\s*:\s*\"([^\"]+)\"", source)]
end

function row_family_values(source::AbstractString)
    return String[matched.captures[1] for matched in eachmatch(r"\"family\"\s*:\s*\"([^\"]+)\"", source)]
end

function summary_status_counts(source::AbstractString)
    matched = match(r"(?s)\"by_status\"\s*:\s*\{(.*?)\}", source)
    matched === nothing && return nothing
    counts = Dict{String,Int}()
    for pair in eachmatch(r"\"([^\"]+)\"\s*:\s*(\d+)", matched.captures[1])
        counts[pair.captures[1]] = parse(Int, pair.captures[2])
    end
    return counts
end

function summary_arithmetic_failures(json_source::AbstractString)
    failures = String[]
    total = json_integer_value(json_source, "total")
    statuses = row_status_values(json_source)
    counts = summary_status_counts(json_source)
    total === nothing && push!(failures, "generated JSON summary is missing `total`")
    counts === nothing && push!(failures, "generated JSON summary is missing `by_status`")
    !isempty(failures) && return failures

    total == length(statuses) ||
        push!(failures, "generated JSON summary total must equal row count")

    actual = Dict{String,Int}()
    for status in statuses
        actual[status] = get(actual, status, 0) + 1
    end
    for (status, count) in actual
        get(counts, status, 0) == count ||
            push!(failures, "generated JSON summary by_status count for `$status` must equal row count")
    end
    for status in setdiff(Set(keys(counts)), Set(keys(actual)))
        push!(failures, "generated JSON summary by_status includes unused status `$status`")
    end
    return failures
end

function row_status_follow_ups(source::AbstractString)
    return Tuple{String,String}[
        (matched.captures[1], matched.captures[2])
        for matched in eachmatch(r"(?s)\"status\"\s*:\s*\"([^\"]+)\".*?\"follow_up\"\s*:\s*\"([^\"]*)\"", source)
    ]
end

function actionable_follow_up(value::AbstractString)
    lowered = lowercase(value)
    return occursin("release checklist:", lowered) ||
        occursin("issue", lowered) ||
        occursin("#", lowered)
end

function follow_up_policy_failures(json_source::AbstractString)
    failures = String[]
    pairs = row_status_follow_ups(json_source)
    isempty(pairs) && return ["generated JSON has no status/follow_up row pairs"]
    for (status, follow_up) in pairs
        status in STATUSES_REQUIRING_ACTIONABLE_FOLLOW_UP || continue
        actionable_follow_up(follow_up) || push!(
            failures,
            "generated JSON row with status `$status` must cite a release checklist item or issue follow-up",
        )
    end
    return failures
end

function release_policy_failures(json_source::AbstractString)
    failures = String[]
    for status in row_status_values(json_source)
        lowercase(status) == ReferenceParityMatrixRender.RELEASE_READY_STATUS && continue
        push!(failures, "release check rejects reference parity rows not marked `matched`: $status")
    end
    return failures
end

function generated_json_failures(; release_check::Bool=false)
    json = ReferenceParityMatrixRender.render(; format="json")
    failures = matrix_json_failures(json)
    release_check && append!(failures, release_policy_failures(json))
    return failures
end

function matrix_json_failures(json::AbstractString; label::AbstractString="generated JSON")
    failures = String[]
    for required in (
        "\"schema_version\": 1",
        "\"summary\": {",
        "\"total\":",
        "\"by_status\": {",
        "\"rows\": [",
        "\"family\":",
        "\"ratatui\":",
        "\"textual\":",
        "\"tamboui\":",
        "\"lanterna\":",
        "\"wicked\":",
        "\"status\":",
        "\"follow_up\":",
    )
        occursin(required, json) || push!(failures, "$label missing required token: $required")
    end
    if isfile(SCHEMA_PATH)
        append!(failures, key_contract_failures(read(SCHEMA_PATH, String), json))
    end
    append!(failures, summary_arithmetic_failures(json))
    append!(failures, follow_up_policy_failures(json))
    return failures
end

function adapted_status_filter_failures(json_source::AbstractString; require_nonempty::Bool=true)
    failures = String[]
    statuses = row_status_values(json_source)
    require_nonempty && isempty(statuses) && push!(failures, "generated adapted JSON must contain at least one adapted row when adapted work exists")
    for status in statuses
        status == "adapted" || push!(failures, "generated adapted JSON contains non-adapted row status `$status`")
    end
    return failures
end

function blocking_status_filter_failures(json_source::AbstractString; require_nonempty::Bool=true)
    failures = String[]
    statuses = row_status_values(json_source)
    require_nonempty && isempty(statuses) && push!(failures, "generated blocking JSON must contain at least one blocking row when non-matched work exists")
    for status in statuses
        lowercase(status) != ReferenceParityMatrixRender.RELEASE_READY_STATUS ||
            push!(failures, "generated blocking JSON contains matched row status `$status`")
    end
    return failures
end

function generated_adapted_json_failures()
    full = ReferenceParityMatrixRender.render(; format="json")
    json = ReferenceParityMatrixRender.render(; format="json", status="adapted")
    full_counts = summary_status_counts(full)
    require_nonempty = get(full_counts === nothing ? Dict{String,Int}() : full_counts, "adapted", 0) > 0
    failures = matrix_json_failures(json; label="generated adapted JSON")
    append!(failures, adapted_status_filter_failures(json; require_nonempty=require_nonempty))
    return failures
end

function generated_blocking_json_failures()
    full = ReferenceParityMatrixRender.render(; format="json")
    json = ReferenceParityMatrixRender.render(; format="json", blocking_only=true)
    statuses = row_status_values(full)
    require_nonempty = any(status -> lowercase(status) != ReferenceParityMatrixRender.RELEASE_READY_STATUS, statuses)
    failures = matrix_json_failures(json; label="generated blocking JSON")
    append!(failures, blocking_status_filter_failures(json; require_nonempty=require_nonempty))
    return failures
end

function single_family_filter_failures(json_source::AbstractString, family::AbstractString)
    failures = String[]
    families = row_family_values(json_source)
    isempty(families) && push!(failures, "generated family-filtered JSON must contain at least one row for `$family`")
    for row_family in families
        row_family == family || push!(failures, "generated family-filtered JSON contains unexpected family `$row_family`")
    end
    return failures
end

function generated_remote_delivery_json_failures()
    json = ReferenceParityMatrixRender.render(; format="json", family=lowercase(REMOTE_DELIVERY_FAMILY))
    failures = matrix_json_failures(json; label="generated remote-delivery JSON")
    append!(failures, single_family_filter_failures(json, REMOTE_DELIVERY_FAMILY))
    return failures
end

function status_key_contract_failures(schema_source::AbstractString, json_source::AbstractString)
    failures = String[]
    schema = schema_keys(schema_source)
    generated = generated_keys(json_source)
    for key in REQUIRED_STATUS_KEYS
        key in schema || push!(failures, "status schema is missing generated key `$key`")
        key in generated || push!(failures, "generated status JSON is missing schema key `$key`")
    end
    return failures
end

function summary_key_contract_failures(schema_source::AbstractString, json_source::AbstractString)
    failures = String[]
    schema = schema_keys(schema_source)
    generated = generated_keys(json_source)
    for key in ("schema_version", REQUIRED_SUMMARY_KEYS...)
        key in schema || push!(failures, "summary schema is missing generated key `$key`")
        key in generated || push!(failures, "generated summary JSON is missing schema key `$key`")
    end
    return failures
end

function json_bool_value(source::AbstractString, key::AbstractString)
    matched = match(Regex("\"" * key * "\"\\s*:\\s*(true|false)"), source)
    return matched === nothing ? nothing : matched.captures[1] == "true"
end

function json_string_array_values(source::AbstractString, key::AbstractString)
    matched = match(Regex("(?s)\"" * key * "\"\\s*:\\s*\\[(.*?)\\]"), source)
    matched === nothing && return nothing
    return String[value.captures[1] for value in eachmatch(r"\"([^\"]+)\"", matched.captures[1])]
end

function status_blocking_records(source::AbstractString)
    occursin("\"blocking_records\"", source) || return nothing
    return Tuple{String,String,String}[
        (matched.captures[1], matched.captures[2], matched.captures[3])
        for matched in eachmatch(
            r"(?s)\{\s*\"family\"\s*:\s*\"([^\"]+)\"\s*,\s*\"status\"\s*:\s*\"([^\"]+)\"\s*,\s*\"follow_up\"\s*:\s*\"([^\"]+)\"\s*\}",
            source,
        )
    ]
end

function status_arithmetic_failures(json_source::AbstractString)
    failures = String[]
    release_ready = json_bool_value(json_source, "release_ready")
    total = json_integer_value(json_source, "total")
    blocking = json_integer_value(json_source, "blocking")
    blocking_families = json_string_array_values(json_source, "blocking_families")
    blocking_records = status_blocking_records(json_source)
    release_ready === nothing && push!(failures, "generated status JSON is missing `release_ready`")
    total === nothing && push!(failures, "generated status JSON is missing `total`")
    blocking === nothing && push!(failures, "generated status JSON is missing `blocking`")
    blocking_families === nothing && push!(failures, "generated status JSON is missing `blocking_families`")
    blocking_records === nothing && push!(failures, "generated status JSON is missing `blocking_records`")
    !isempty(failures) && return failures

    blocking <= total || push!(failures, "generated status JSON blocking count must not exceed total")
    blocking == length(blocking_families) ||
        push!(failures, "generated status JSON blocking count must equal blocking_families length")
    blocking == length(blocking_records) ||
        push!(failures, "generated status JSON blocking count must equal blocking_records length")
    record_families = String[record[1] for record in blocking_records]
    Set(record_families) == Set(blocking_families) ||
        push!(failures, "generated status JSON blocking_records families must match blocking_families")
    release_ready == (blocking == 0) ||
        push!(failures, "generated status JSON release_ready must match blocking count")
    return failures
end

function generated_status_json_failures()
    json = ReferenceParityMatrixRender.render_release_status_json(ReferenceParityMatrixRender.parity_rows())
    failures = String[]
    for required in (
        "\"schema_version\": 1",
        "\"release_ready\":",
        "\"total\":",
        "\"blocking\":",
        "\"blocking_families\": [",
        "\"blocking_records\": [",
        "\"follow_up\":",
    )
        occursin(required, json) || push!(failures, "generated status JSON missing required token: $required")
    end
    if isfile(STATUS_SCHEMA_PATH)
        append!(failures, status_key_contract_failures(read(STATUS_SCHEMA_PATH, String), json))
    end
    append!(failures, status_arithmetic_failures(json))
    return failures
end

function summary_json_arithmetic_failures(json_source::AbstractString)
    failures = String[]
    total = json_integer_value(json_source, "total")
    counts = summary_status_counts(json_source)
    total === nothing && push!(failures, "generated summary JSON is missing `total`")
    counts === nothing && push!(failures, "generated summary JSON is missing `by_status`")
    !isempty(failures) && return failures

    sum(values(counts)) == total ||
        push!(failures, "generated summary JSON total must equal by_status count sum")
    return failures
end

function generated_summary_json_failures()
    json = ReferenceParityMatrixRender.render(; format="json", summary=true)
    failures = String[]
    for required in (
        "\"schema_version\": 1",
        "\"total\":",
        "\"by_status\": {",
    )
        occursin(required, json) || push!(failures, "generated summary JSON missing required token: $required")
    end
    if isfile(SUMMARY_SCHEMA_PATH)
        append!(failures, summary_key_contract_failures(read(SUMMARY_SCHEMA_PATH, String), json))
    end
    append!(failures, summary_json_arithmetic_failures(json))
    return failures
end

function audit(; release_check::Bool=false)
    failures = String[]
    append!(failures, schema_failures())
    append!(failures, summary_schema_failures())
    append!(failures, status_schema_failures())
    append!(failures, generated_json_failures(; release_check=release_check))
    append!(failures, generated_adapted_json_failures())
    append!(failures, generated_blocking_json_failures())
    append!(failures, generated_remote_delivery_json_failures())
    append!(failures, generated_summary_json_failures())
    append!(failures, generated_status_json_failures())
    return failures
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    known = Set(["--release-check"])
    for argument in arguments
        argument in known || begin
            print_usage(stderr)
            return 2
        end
    end
    length(arguments) <= 1 || begin
        print_usage(stderr)
        return 2
    end
    release_check = "--release-check" in arguments
    failures = audit(; release_check=release_check)
    if isempty(failures)
        mode = release_check ? "release schema and generated JSON contract are valid" : "schema and generated JSON contract are valid"
        println("reference parity matrix schema audit: $mode")
        return 0
    end
    for failure in failures
        println(stderr, "reference parity matrix schema audit: $failure")
    end
    return 1
end

end # module ReferenceParityMatrixSchemaAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(ReferenceParityMatrixSchemaAudit.main())
end
