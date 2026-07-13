#!/usr/bin/env julia

module WidgetPromotionRequirementsSchemaAudit

include(joinpath(@__DIR__, "render_widget_promotion_requirements.jl"))

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SCHEMA_PATH = joinpath(ROOT, "docs", "evidence", "widget_promotion_requirements.schema.json")
const REQUIRED_TOP_LEVEL_KEYS = ("schema_version", "summary", "requirements")
const REQUIRED_SUMMARY_KEYS = ("total", "by_area", "by_release_required")
const REQUIRED_REQUIREMENT_KEYS = ("id", "area", "requirement", "evidence", "gate", "release_required")

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/widget_promotion_requirements_schema_audit.jl")
    println(io, "")
    println(io, "Checks the widget promotion requirements JSON schema and generated JSON contract.")
end

function schema_failures(path::AbstractString=SCHEMA_PATH)
    failures = String[]
    isfile(path) || return ["missing widget promotion requirements schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"summary\"",
        "\"total\"",
        "\"by_area\"",
        "\"by_release_required\"",
        "\"requirements\"",
        "\"id\"",
        "\"area\"",
        "\"requirement\"",
        "\"evidence\"",
        "\"gate\"",
        "\"release_required\"",
        "\"additionalProperties\": false",
        "\"api\"",
        "\"behavior\"",
        "\"docs\"",
        "\"examples\"",
        "\"semantics\"",
        "\"toolkit\"",
        "\"performance\"",
        "\"release\"",
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

function key_contract_failures(schema_source::AbstractString, json_source::AbstractString)
    failures = String[]
    schema = schema_keys(schema_source)
    generated = generated_keys(json_source)
    for key in (REQUIRED_TOP_LEVEL_KEYS..., REQUIRED_SUMMARY_KEYS..., REQUIRED_REQUIREMENT_KEYS...)
        key in schema || push!(failures, "schema is missing generated key `$key`")
        key in generated || push!(failures, "generated JSON is missing schema key `$key`")
    end
    return failures
end

function generated_json_failures()
    json = WidgetPromotionRequirementsRender.render(; format="json", release_required="yes")
    failures = String[]
    for required in (
        "\"schema_version\": 1",
        "\"summary\": {",
        "\"total\":",
        "\"by_area\": {",
        "\"by_release_required\": {",
        "\"requirements\": [",
        "\"id\":",
        "\"area\":",
        "\"requirement\":",
        "\"evidence\":",
        "\"gate\":",
        "\"release_required\": \"yes\"",
    )
        occursin(required, json) || push!(failures, "generated JSON missing required token: $required")
    end
    occursin("\"release_required\": \"no\"", json) &&
        push!(failures, "release-required generated JSON must not include non-release requirements")
    if isfile(SCHEMA_PATH)
        append!(failures, key_contract_failures(read(SCHEMA_PATH, String), json))
    end
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
        println("widget promotion requirements schema audit: schema and generated JSON contract are valid")
        return 0
    end
    for failure in failures
        println(stderr, "widget promotion requirements schema audit: $failure")
    end
    return 1
end

end # module WidgetPromotionRequirementsSchemaAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(WidgetPromotionRequirementsSchemaAudit.main())
end
