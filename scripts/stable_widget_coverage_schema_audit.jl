#!/usr/bin/env julia

module StableWidgetCoverageSchemaAudit

using Wicked.API: widget_coverage_summary_json

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SCHEMA_PATH = joinpath(ROOT, "docs", "evidence", "stable_widget_coverage.schema.json")
const REQUIRED_TOP_LEVEL_KEYS = ("schema_version", "metadata", "complete", "summary", "rows")
const REQUIRED_METADATA_KEYS = ("generated_at", "root")
const OPTIONAL_METADATA_KEYS = ("git_commit", "git_dirty")
const REQUIRED_SUMMARY_KEYS = ("total", "complete", "incomplete", "missing_records", "source_mismatches", "missing_checks")
const REQUIRED_ROW_KEYS = ("metric", "key", "count")

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/stable_widget_coverage_schema_audit.jl")
    println(io, "")
    println(io, "Checks the stable widget coverage JSON schema and generated JSON contract.")
end

function schema_failures(path::AbstractString=SCHEMA_PATH)
    failures = String[]
    isfile(path) || return ["missing stable widget coverage schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"metadata\"",
        "\"generated_at\"",
        "\"root\"",
        "\"git_commit\"",
        "\"git_dirty\"",
        "\"complete\"",
        "\"summary\"",
        "\"total\"",
        "\"incomplete\"",
        "\"missing_records\"",
        "\"source_mismatches\"",
        "\"missing_checks\"",
        "\"rows\"",
        "\"metric\"",
        "\"key\"",
        "\"count\"",
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

json_integer_value(source::AbstractString, key::AbstractString) = begin
    matched = match(Regex("\"" * key * "\"\\s*:\\s*(\\d+)"), source)
    matched === nothing ? nothing : parse(Int, matched.captures[1])
end

json_bool_value(source::AbstractString, key::AbstractString) = begin
    matched = match(Regex("\"" * key * "\"\\s*:\\s*(true|false)"), source)
    matched === nothing ? nothing : matched.captures[1] == "true"
end

function key_contract_failures(schema_source::AbstractString, json_source::AbstractString)
    failures = String[]
    schema = schema_keys(schema_source)
    generated = generated_keys(json_source)
    for key in (REQUIRED_TOP_LEVEL_KEYS..., REQUIRED_METADATA_KEYS..., REQUIRED_SUMMARY_KEYS..., REQUIRED_ROW_KEYS...)
        key in schema || push!(failures, "schema is missing generated key `$key`")
        key in generated || push!(failures, "generated JSON is missing schema key `$key`")
    end
    for key in OPTIONAL_METADATA_KEYS
        key in schema || push!(failures, "schema is missing optional generated key `$key`")
    end
    return failures
end

function summary_arithmetic_failures(json_source::AbstractString)
    failures = String[]
    total = json_integer_value(json_source, "total")
    complete_count = json_integer_value(json_source, "complete")
    incomplete = json_integer_value(json_source, "incomplete")
    missing_records = json_integer_value(json_source, "missing_records")
    source_mismatches = json_integer_value(json_source, "source_mismatches")
    missing_checks = json_integer_value(json_source, "missing_checks")
    complete_flag = json_bool_value(json_source, "complete")
    for (label, value) in (
        ("total", total),
        ("complete", complete_count),
        ("incomplete", incomplete),
        ("missing_records", missing_records),
        ("source_mismatches", source_mismatches),
        ("missing_checks", missing_checks),
    )
        value === nothing && push!(failures, "generated JSON summary is missing `$label`")
    end
    complete_flag === nothing && push!(failures, "generated JSON is missing boolean `complete`")
    !isempty(failures) && return failures
    total == complete_count + incomplete || push!(failures, "generated JSON summary total must equal complete plus incomplete")
    incomplete == missing_records + source_mismatches + missing_checks ||
        push!(failures, "generated JSON summary incomplete must equal missing_records plus source_mismatches plus missing_checks")
    complete_flag == (incomplete == 0) || push!(failures, "generated JSON complete flag must match incomplete count")
    return failures
end

function generated_json_failures()
    failures = String[]
    json = widget_coverage_summary_json(include_git=false)
    for required in (
        "\"schema_version\": 1",
        "\"metadata\": {",
        "\"generated_at\":",
        "\"root\":",
        "\"complete\":",
        "\"summary\": {",
        "\"total\":",
        "\"incomplete\":",
        "\"missing_records\":",
        "\"source_mismatches\":",
        "\"missing_checks\":",
        "\"rows\": [",
        "\"metric\":",
        "\"key\":",
        "\"count\":",
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
        println("stable widget coverage schema audit: schema and generated JSON contract are valid")
        return 0
    end
    for failure in failures
        println(stderr, "stable widget coverage schema audit: $failure")
    end
    return 1
end

end # module StableWidgetCoverageSchemaAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(StableWidgetCoverageSchemaAudit.main())
end
