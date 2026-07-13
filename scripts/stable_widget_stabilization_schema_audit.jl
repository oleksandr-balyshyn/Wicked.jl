#!/usr/bin/env julia

module StableWidgetStabilizationSchemaAudit

using Wicked.API: widget_stabilization_status_json

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SCHEMA_PATH = joinpath(ROOT, "docs", "evidence", "stable_widget_stabilization.schema.json")
const REQUIRED_KEYS = (
    "schema_version",
    "ready",
    "total_widgets",
    "stable_widgets",
    "candidate_widget_count",
    "candidate_widgets",
    "experimental_widget_count",
    "experimental_widgets",
    "stability_blocked",
    "family_closeout_blocked",
)

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/stable_widget_stabilization_schema_audit.jl")
    println(io, "")
    println(io, "Checks the stable widget stabilization JSON schema and generated JSON contract.")
end

function schema_failures(path::AbstractString=SCHEMA_PATH)
    failures = String[]
    isfile(path) || return ["missing stable widget stabilization schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"ready\"",
        "\"total_widgets\"",
        "\"stable_widgets\"",
        "\"candidate_widget_count\"",
        "\"candidate_widgets\"",
        "\"experimental_widget_count\"",
        "\"experimental_widgets\"",
        "\"stability_blocked\"",
        "\"family_closeout_blocked\"",
        "\"additionalProperties\": false",
    )
        occursin(required, source) || push!(failures, "schema missing required contract token: $required")
    end
    return failures
end

function quoted_keys(source::AbstractString)
    return Set(String(match.captures[1]) for match in eachmatch(r"\"([A-Za-z_][A-Za-z0-9_]*)\"\s*:", source))
end

schema_keys(source::AbstractString) = quoted_keys(source)
generated_keys(source::AbstractString) = quoted_keys(source)

function json_integer_value(source::AbstractString, key::AbstractString)
    matched = match(Regex("\"" * key * "\"\\s*:\\s*(\\d+)"), source)
    return matched === nothing ? nothing : parse(Int, matched.captures[1])
end

function json_bool_value(source::AbstractString, key::AbstractString)
    matched = match(Regex("\"" * key * "\"\\s*:\\s*(true|false)"), source)
    return matched === nothing ? nothing : matched.captures[1] == "true"
end

function json_array_count(source::AbstractString, key::AbstractString)
    matched = match(Regex("\"" * key * "\"\\s*:\\s*\\[(.*?)\\]", "s"), source)
    matched === nothing && return nothing
    body = matched.captures[1]
    isempty(strip(body)) && return 0
    return count(_ -> true, eachmatch(r"\"(?:\\.|[^\"])*\"", body))
end

function key_contract_failures(schema_source::AbstractString, json_source::AbstractString)
    failures = String[]
    schema = schema_keys(schema_source)
    generated = generated_keys(json_source)
    for key in REQUIRED_KEYS
        key in schema || push!(failures, "schema is missing generated key `$key`")
        key in generated || push!(failures, "generated JSON is missing schema key `$key`")
    end
    return failures
end

function readiness_consistency_failures(json_source::AbstractString)
    failures = String[]
    ready = json_bool_value(json_source, "ready")
    candidate_count = json_integer_value(json_source, "candidate_widget_count")
    candidate_array_count = json_array_count(json_source, "candidate_widgets")
    experimental_count = json_integer_value(json_source, "experimental_widget_count")
    experimental_array_count = json_array_count(json_source, "experimental_widgets")
    stability_blocked = json_integer_value(json_source, "stability_blocked")
    family_closeout_blocked = json_integer_value(json_source, "family_closeout_blocked")
    for (label, value) in (
        ("ready", ready),
        ("candidate_widget_count", candidate_count),
        ("candidate_widgets", candidate_array_count),
        ("experimental_widget_count", experimental_count),
        ("experimental_widgets", experimental_array_count),
        ("stability_blocked", stability_blocked),
        ("family_closeout_blocked", family_closeout_blocked),
    )
        value === nothing && push!(failures, "generated JSON is missing `$label`")
    end
    !isempty(failures) && return failures
    candidate_count == candidate_array_count ||
        push!(failures, "candidate_widget_count must match candidate_widgets length")
    experimental_count == experimental_array_count ||
        push!(failures, "experimental_widget_count must match experimental_widgets length")
    ready == (candidate_count == 0 && experimental_count == 0 && stability_blocked == 0 && family_closeout_blocked == 0) ||
        push!(failures, "ready must match candidate, experimental, stability, and family closeout blockers")
    return failures
end

function generated_json_failures()
    failures = String[]
    json = widget_stabilization_status_json()
    for required in (
        "\"schema_version\": 1",
        "\"ready\":",
        "\"total_widgets\":",
        "\"stable_widgets\":",
        "\"candidate_widget_count\":",
        "\"candidate_widgets\":",
        "\"experimental_widget_count\":",
        "\"experimental_widgets\":",
        "\"stability_blocked\":",
        "\"family_closeout_blocked\":",
    )
        occursin(required, json) || push!(failures, "generated JSON missing required token: $required")
    end
    if isfile(SCHEMA_PATH)
        append!(failures, key_contract_failures(read(SCHEMA_PATH, String), json))
    end
    append!(failures, readiness_consistency_failures(json))
    return failures
end

function audit()
    failures = String[]
    append!(failures, schema_failures())
    append!(failures, generated_json_failures())
    return failures
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    isempty(arguments) || begin
        print_usage(stderr)
        return 2
    end
    failures = audit()
    if isempty(failures)
        println("stable widget stabilization schema audit: schema and generated JSON contract are valid")
        return 0
    end
    for failure in failures
        println(stderr, "stable widget stabilization schema audit: $failure")
    end
    return 1
end

end # module StableWidgetStabilizationSchemaAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(StableWidgetStabilizationSchemaAudit.main())
end
