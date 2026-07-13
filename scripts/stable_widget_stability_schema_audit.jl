#!/usr/bin/env julia

module StableWidgetStabilitySchemaAudit

using Wicked.API: widget_stability_json

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SCHEMA_PATH = joinpath(ROOT, "docs", "evidence", "stable_widget_stability.schema.json")
const REQUIRED_TOP_LEVEL_KEYS = ("schema_version", "metadata", "ready", "summary", "rows")
const REQUIRED_METADATA_KEYS = ("generated_at", "root")
const REQUIRED_SUMMARY_KEYS = ("total", "ready", "blocked")
const REQUIRED_ROW_KEYS = (
    "name",
    "family",
    "family_slug",
    "surface",
    "status",
    "catalog_source",
    "coverage_source",
    "stable",
    "coverage_complete",
    "ready",
    "missing_checks",
    "blockers",
)

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/stable_widget_stability_schema_audit.jl")
    println(io, "")
    println(io, "Checks the stable widget stability JSON schema and generated JSON contract.")
end

function schema_failures(path::AbstractString=SCHEMA_PATH)
    failures = String[]
    isfile(path) || return ["missing stable widget stability schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"metadata\"",
        "\"generated_at\"",
        "\"root\"",
        "\"ready\"",
        "\"summary\"",
        "\"total\"",
        "\"blocked\"",
        "\"rows\"",
        "\"name\"",
        "\"family\"",
        "\"family_slug\"",
        "\"surface\"",
        "\"status\"",
        "\"catalog_source\"",
        "\"coverage_source\"",
        "\"stable\"",
        "\"coverage_complete\"",
        "\"missing_checks\"",
        "\"blockers\"",
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

function key_contract_failures(schema_source::AbstractString, json_source::AbstractString)
    failures = String[]
    schema = schema_keys(schema_source)
    generated = generated_keys(json_source)
    for key in (REQUIRED_TOP_LEVEL_KEYS..., REQUIRED_METADATA_KEYS..., REQUIRED_SUMMARY_KEYS..., REQUIRED_ROW_KEYS...)
        key in schema || push!(failures, "schema is missing generated key `$key`")
        key in generated || push!(failures, "generated JSON is missing schema key `$key`")
    end
    return failures
end

function summary_arithmetic_failures(json_source::AbstractString)
    failures = String[]
    total = json_integer_value(json_source, "total")
    ready_count = json_integer_value(json_source, "ready")
    blocked = json_integer_value(json_source, "blocked")
    ready_flag = json_bool_value(json_source, "ready")
    for (label, value) in (
        ("total", total),
        ("ready", ready_count),
        ("blocked", blocked),
    )
        value === nothing && push!(failures, "generated JSON summary is missing `$label`")
    end
    ready_flag === nothing && push!(failures, "generated JSON is missing boolean `ready`")
    !isempty(failures) && return failures
    total == ready_count + blocked ||
        push!(failures, "generated JSON summary total must equal ready plus blocked")
    ready_flag == (blocked == 0) ||
        push!(failures, "generated JSON ready flag must match blocked count")
    row_count = length(collect(eachmatch(r"\"name\"\s*:", json_source)))
    row_count == total ||
        push!(failures, "generated JSON summary total must equal row count")
    return failures
end

function generated_json_failures()
    failures = String[]
    json = widget_stability_json()
    for required in (
        "\"schema_version\": 1",
        "\"metadata\": {",
        "\"generated_at\":",
        "\"root\":",
        "\"ready\":",
        "\"summary\": {",
        "\"total\":",
        "\"blocked\":",
        "\"rows\": [",
        "\"name\":",
        "\"family\":",
        "\"family_slug\":",
        "\"surface\":",
        "\"status\":",
        "\"catalog_source\":",
        "\"coverage_source\":",
        "\"stable\":",
        "\"coverage_complete\":",
        "\"missing_checks\":",
        "\"blockers\":",
    )
        occursin(required, json) || push!(failures, "generated JSON missing required token: $required")
    end
    if isfile(SCHEMA_PATH)
        append!(failures, key_contract_failures(read(SCHEMA_PATH, String), json))
    end
    append!(failures, summary_arithmetic_failures(json))
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
        println("stable widget stability schema audit: schema and generated JSON contract are valid")
        return 0
    end
    for failure in failures
        println(stderr, "stable widget stability schema audit: $failure")
    end
    return 1
end

end # module StableWidgetStabilitySchemaAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(StableWidgetStabilitySchemaAudit.main())
end
