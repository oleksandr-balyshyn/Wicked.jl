#!/usr/bin/env julia

module StableWidgetSurfaceReleaseSchemaAudit

using Wicked.API: widget_surface_release_status_json

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SCHEMA_PATH = joinpath(ROOT, "docs", "evidence", "stable_widget_surface_release.schema.json")
const REQUIRED_KEYS = (
    "schema_version",
    "release_ready",
    "coverage_release_ready",
    "coverage_complete",
    "git_available",
    "git_dirty",
    "git_commit",
    "stability_complete",
    "stability_blocked",
    "family_closeout_complete",
    "family_closeout_blocked",
)

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/stable_widget_surface_release_schema_audit.jl")
    println(io, "")
    println(io, "Checks the stable widget surface release JSON schema and generated JSON contract.")
end

function schema_failures(path::AbstractString=SCHEMA_PATH)
    failures = String[]
    isfile(path) || return ["missing stable widget surface release schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"release_ready\"",
        "\"coverage_release_ready\"",
        "\"coverage_complete\"",
        "\"git_available\"",
        "\"git_dirty\"",
        "\"git_commit\"",
        "\"stability_complete\"",
        "\"stability_blocked\"",
        "\"family_closeout_complete\"",
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

function json_null_value(source::AbstractString, key::AbstractString)
    return occursin(Regex("\"" * key * "\"\\s*:\\s*null"), source)
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
    release_ready = json_bool_value(json_source, "release_ready")
    coverage_release_ready = json_bool_value(json_source, "coverage_release_ready")
    coverage_complete = json_bool_value(json_source, "coverage_complete")
    git_available = json_bool_value(json_source, "git_available")
    git_dirty = json_bool_value(json_source, "git_dirty")
    stability_complete = json_bool_value(json_source, "stability_complete")
    stability_blocked = json_integer_value(json_source, "stability_blocked")
    family_closeout_complete = json_bool_value(json_source, "family_closeout_complete")
    family_closeout_blocked = json_integer_value(json_source, "family_closeout_blocked")
    for (label, value) in (
        ("release_ready", release_ready),
        ("coverage_release_ready", coverage_release_ready),
        ("coverage_complete", coverage_complete),
        ("git_available", git_available),
        ("git_dirty", git_dirty),
        ("stability_complete", stability_complete),
        ("stability_blocked", stability_blocked),
        ("family_closeout_complete", family_closeout_complete),
        ("family_closeout_blocked", family_closeout_blocked),
    )
        value === nothing && push!(failures, "generated JSON is missing `$label`")
    end
    !isempty(failures) && return failures
    coverage_release_ready == (coverage_complete && git_available && !git_dirty) ||
        push!(failures, "coverage_release_ready must match coverage_complete, git_available, and git_dirty")
    stability_complete == (stability_blocked == 0) ||
        push!(failures, "stability_complete must match stability_blocked")
    family_closeout_complete == (family_closeout_blocked == 0) ||
        push!(failures, "family_closeout_complete must match family_closeout_blocked")
    release_ready == (coverage_release_ready && stability_complete && family_closeout_complete) ||
        push!(failures, "release_ready must match coverage, stability, and family closeout readiness")
    git_available || json_null_value(json_source, "git_commit") ||
        push!(failures, "git_commit must be null when git metadata is unavailable")
    return failures
end

function generated_json_failures()
    failures = String[]
    json = widget_surface_release_status_json()
    for required in (
        "\"schema_version\": 1",
        "\"release_ready\":",
        "\"coverage_release_ready\":",
        "\"coverage_complete\":",
        "\"git_available\":",
        "\"git_dirty\":",
        "\"git_commit\":",
        "\"stability_complete\":",
        "\"stability_blocked\":",
        "\"family_closeout_complete\":",
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
        println("stable widget surface release schema audit: schema and generated JSON contract are valid")
        return 0
    end
    for failure in failures
        println(stderr, "stable widget surface release schema audit: $failure")
    end
    return 1
end

end # module StableWidgetSurfaceReleaseSchemaAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(StableWidgetSurfaceReleaseSchemaAudit.main())
end
