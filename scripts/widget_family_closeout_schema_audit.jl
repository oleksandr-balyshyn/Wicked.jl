#!/usr/bin/env julia

module WidgetFamilyCloseoutSchemaAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SCHEMA_PATH = joinpath(ROOT, "docs", "evidence", "widget_family_closeout.schema.json")
const RENDER_SCRIPT = joinpath(ROOT, "scripts", "render_widget_family_closeout.jl")
const REQUIRED_TOP_LEVEL_KEYS = ("schema_version", "metadata", "summary", "families")
const REQUIRED_METADATA_KEYS = ("generated_at", "root")
const OPTIONAL_METADATA_KEYS = ("git_commit", "git_dirty")
const REQUIRED_SUMMARY_KEYS = ("total", "ready", "blocked")
const REQUIRED_FAMILY_KEYS = (
    "family",
    "status",
    "docs",
    "examples",
    "stable_api_tokens",
    "precompile_tokens",
    "notes",
    "blockers",
    "blocker_details",
)

isdefined(@__MODULE__, :WidgetFamilyCloseoutRender) || include(RENDER_SCRIPT)

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/widget_family_closeout_schema_audit.jl")
    println(io, "")
    println(io, "Checks the widget family closeout JSON schema and generated JSON contract.")
end

function schema_failures(path::AbstractString=SCHEMA_PATH)
    failures = String[]
    isfile(path) || return ["missing widget family closeout schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"metadata\"",
        "\"generated_at\"",
        "\"root\"",
        "\"git_commit\"",
        "\"git_dirty\"",
        "\"summary\"",
        "\"total\"",
        "\"ready\"",
        "\"blocked\"",
        "\"families\"",
        "\"family\"",
        "\"status\"",
        "\"docs\"",
        "\"examples\"",
        "\"stable_api_tokens\"",
        "\"precompile_tokens\"",
        "\"notes\"",
        "\"blockers\"",
        "\"blocker_details\"",
        "\"enum\": [\"ready\", \"blocked\"]",
        "\"additionalProperties\": false",
    )
        occursin(required, source) || push!(failures, "schema missing required contract token: $required")
    end
    return failures
end

function quoted_keys(source::AbstractString)
    return Set(String(match.captures[1]) for match in eachmatch(r"\"([A-Za-z_][A-Za-z0-9_]*)\"\s*:", source))
end

function schema_keys(source::AbstractString)
    return quoted_keys(source)
end

function generated_keys(source::AbstractString)
    return quoted_keys(source)
end

json_integer_value(source::AbstractString, key::AbstractString) = begin
    matched = match(Regex("\"" * key * "\"\\s*:\\s*(\\d+)"), source)
    matched === nothing ? nothing : parse(Int, matched.captures[1])
end

function generated_status_counts(source::AbstractString)
    ready = length(collect(eachmatch(r"\"status\":\"ready\"", source)))
    blocked = length(collect(eachmatch(r"\"status\":\"blocked\"", source)))
    return (ready=ready, blocked=blocked, total=ready + blocked)
end

function key_contract_failures(schema_source::AbstractString, json_source::AbstractString)
    failures = String[]
    schema = schema_keys(schema_source)
    generated = generated_keys(json_source)
    for key in (REQUIRED_TOP_LEVEL_KEYS..., REQUIRED_METADATA_KEYS..., REQUIRED_SUMMARY_KEYS..., REQUIRED_FAMILY_KEYS...)
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
    summary_total = json_integer_value(json_source, "total")
    summary_ready = json_integer_value(json_source, "ready")
    summary_blocked = json_integer_value(json_source, "blocked")
    statuses = generated_status_counts(json_source)
    summary_total === nothing && push!(failures, "generated JSON summary is missing `total`")
    summary_ready === nothing && push!(failures, "generated JSON summary is missing `ready`")
    summary_blocked === nothing && push!(failures, "generated JSON summary is missing `blocked`")
    (summary_total === nothing || summary_ready === nothing || summary_blocked === nothing) && return failures
    summary_ready == statuses.ready || push!(failures, "generated JSON summary ready count $(summary_ready) does not match $(statuses.ready) ready family rows")
    summary_blocked == statuses.blocked || push!(failures, "generated JSON summary blocked count $(summary_blocked) does not match $(statuses.blocked) blocked family rows")
    summary_total == statuses.total || push!(failures, "generated JSON summary total count $(summary_total) does not match $(statuses.total) family rows")
    summary_total == summary_ready + summary_blocked || push!(failures, "generated JSON summary total must equal ready plus blocked")
    return failures
end

function generated_json_failures()
    failures = String[]
    json = WidgetFamilyCloseoutRender.render_closeout(
        (
            family=nothing,
            count=false,
            summary=false,
            format=:json,
            columns=WidgetFamilyCloseoutRender.DEFAULT_COLUMNS,
            header=true,
        ),
    )
    for required in (
        "{\"schema_version\":1",
        "\"metadata\":{\"generated_at\":",
        "\"root\":",
        "\"summary\":{\"total\":",
        "\"ready\":",
        "\"blocked\":",
        "\"families\":[",
        "\"family\":",
        "\"status\":",
        "\"docs\":",
        "\"examples\":",
        "\"stable_api_tokens\":",
        "\"precompile_tokens\":",
        "\"notes\":",
        "\"blockers\":",
        "\"blocker_details\":",
    )
        occursin(required, json) || push!(failures, "generated JSON missing required token: $required")
    end
    rows = WidgetFamilyCloseoutRender.closeout_rows()
    summary = WidgetFamilyCloseoutRender.summary_counts(rows)
    occursin("\"total\":$(summary.total)", json) || push!(failures, "generated JSON summary total does not match closeout rows")
    occursin("\"ready\":$(summary.ready)", json) || push!(failures, "generated JSON summary ready count does not match closeout rows")
    occursin("\"blocked\":$(summary.blocked)", json) || push!(failures, "generated JSON summary blocked count does not match closeout rows")
    family_count = length(collect(eachmatch(r"\"family\":", json)))
    family_count == summary.total || push!(failures, "generated JSON has $family_count family objects; expected $(summary.total)")
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
        println("widget family closeout schema audit: schema and generated JSON contract are valid")
        return 0
    end
    for failure in failures
        println(stderr, "widget family closeout schema audit: $failure")
    end
    return 1
end

end # module WidgetFamilyCloseoutSchemaAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(WidgetFamilyCloseoutSchemaAudit.main())
end
