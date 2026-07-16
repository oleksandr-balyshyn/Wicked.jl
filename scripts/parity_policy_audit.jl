#!/usr/bin/env julia

module ParityPolicyAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const POLICY = joinpath(ROOT, "docs", "evidence", "parity_policy.json")
const SCAFFOLD = joinpath(ROOT, "scripts", "new_parity_evidence.jl")
const CLOSEOUT_AUDIT = joinpath(ROOT, "scripts", "parity_closeout_audit.jl")
const README = joinpath(ROOT, "docs", "evidence", "README.md")
const RELEASE_CHECKLIST = joinpath(ROOT, "docs", "RELEASE_CHECKLIST.md")
const GITIGNORE = joinpath(ROOT, ".gitignore")

const EXPECTED_FAMILIES = (
    "Layout",
    "Input-event",
    "Stateful-controls",
    "Data-display",
    "Runtime",
    "Developer-experience",
    "Styling-theming",
    "Remote-delivery",
)
const EXPECTED_SCOPES = Dict(
    "Layout" => "constraint edge cases, clipping policy, resize continuity, and narrow-terminal behavior",
    "Input-event" => "routed events, async delivery, cancellation behavior, focus restoration, and terminal lifecycle recovery",
    "Stateful-controls" => "widget contract tests, state-transition tests, semantic snapshots, and stable widget candidate evidence",
    "Data-display" => "virtual list/table/tree stress cases, stale data, loading/error slots, and screen-reader semantic state",
    "Runtime" => "queue replacement, task cancellation races, redraw determinism, resource cleanup, and subscription shutdown",
    "Developer-experience" => "API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output",
    "Styling-theming" => "selector specificity, cascade order, role downgrade behavior, diagnostics, and monochrome fallback",
    "Remote-delivery" => "browser deployment, WebSocket hardening, protocol versioning, security policy, and real-client compatibility",
)
const EXPECTED_REFERENCES = (
    "Ratatui",
    "Textual",
    "TamboUI",
    "Lanterna",
    "intentional divergence",
)
const EXPECTED_COMMAND_ENTRYPOINTS = (
    "scripts/",
    "test/",
    "benchmark/",
    "docs/make.jl",
    "Pkg.test",
    "node --check",
    "manual:",
)
const EXPECTED_ARTIFACT_URL_SCHEMES = (
    "http://",
    "https://",
)
const EXPECTED_MANUAL_ARTIFACT_HINTS = (
    "terminal",
    "manual",
    "transcript",
    "screenshot",
    "recording",
    "matrix",
)
const CHECKLIST_LABELS = Dict(
    "Layout" => "Layout",
    "Input-event" => "Input/event",
    "Stateful-controls" => "Stateful-controls",
    "Data-display" => "Data-display",
    "Runtime" => "Runtime",
    "Developer-experience" => "Developer-experience",
    "Styling-theming" => "Styling/theming",
    "Remote-delivery" => "Remote-delivery",
)

function object_entries(source::AbstractString, key::AbstractString)
    matched = match(Regex("(?s)\\\"" * escape_string(key) * "\\\"\\s*:\\s*\\{(.*?)\\}"), source)
    matched === nothing && return nothing
    entries = Dict{String,String}()
    for pair in eachmatch(r"\"([^\"]+)\"\s*:\s*\"([^\"]+)\"", matched.captures[1])
        entries[pair.captures[1]] = pair.captures[2]
    end
    return entries
end

function array_values(source::AbstractString, key::AbstractString)
    matched = match(Regex("(?s)\\\"" * escape_string(key) * "\\\"\\s*:\\s*\\[(.*?)\\]"), source)
    matched === nothing && return nothing
    return String[value.captures[1] for value in eachmatch(r"\"([^\"]+)\"", matched.captures[1])]
end

function integer_value(source::AbstractString, key::AbstractString)
    matched = match(Regex("\\\"" * escape_string(key) * "\\\"\\s*:\\s*(\\d+)"), source)
    matched === nothing && return nothing
    return parse(Int, matched.captures[1])
end

function positive_integer_value(source::AbstractString, key::AbstractString)
    value = integer_value(source, key)
    value === nothing && return nothing
    return value > 0 ? value : nothing
end

function checklist_item(family, scope)
    label = CHECKLIST_LABELS[family]
    return "$label parity evidence covers $scope."
end

function audit(;
    policy_path::AbstractString=POLICY,
    scaffold_path::AbstractString=SCAFFOLD,
    closeout_path::AbstractString=CLOSEOUT_AUDIT,
    readme_path::AbstractString=README,
    checklist_path::AbstractString=RELEASE_CHECKLIST,
    gitignore_path::AbstractString=GITIGNORE,
)
    failures = String[]
    for path in (policy_path, scaffold_path, closeout_path, readme_path, checklist_path)
        isfile(path) || push!(failures, "missing parity policy file: $(relpath(path, ROOT))")
    end
    isfile(gitignore_path) || push!(failures, "missing parity draft ignore policy file: $(relpath(gitignore_path, ROOT))")
    isempty(failures) || return failures

    policy = read(policy_path, String)
    scaffold = read(scaffold_path, String)
    closeout = read(closeout_path, String)
    readme = read(readme_path, String)
    checklist = replace(read(checklist_path, String), r"\s+" => " ")
    gitignore = read(gitignore_path, String)

    occursin(r"\"schema_version\"\s*:\s*1\b", policy) ||
        push!(failures, "parity policy schema_version must be 1")
    occursin("\"kernel_scope\": \"Linux only\"", policy) ||
        push!(failures, "parity policy must remain Linux only")
    positive_integer_value(policy, "minimum_final_records_per_family") == 1 ||
        push!(failures, "parity policy minimum_final_records_per_family must be 1")
    occursin("scratch/parity-evidence", gitignore) ||
        push!(failures, ".gitignore must ignore scratch/parity-evidence parity drafts")

    families = object_entries(policy, "families")
    if families === nothing
        push!(failures, "parity policy missing families object")
    else
        expected = Set(EXPECTED_FAMILIES)
        actual = Set(keys(families))
        for family in sort!(collect(setdiff(expected, actual)))
            push!(failures, "parity policy missing family: $family")
        end
        for family in sort!(collect(setdiff(actual, expected)))
            push!(failures, "parity policy contains unknown family: $family")
        end
        for (family, scope) in EXPECTED_SCOPES
            get(families, family, nothing) == scope || push!(
                failures,
                "parity policy family `$family` must use scope: $scope",
            )
        end
    end

    references = array_values(policy, "reference_libraries")
    if references === nothing
        push!(failures, "parity policy missing reference_libraries array")
    else
        expected = Set(EXPECTED_REFERENCES)
        actual = Set(references)
        for label in sort!(collect(setdiff(expected, actual)))
            push!(failures, "parity policy missing reference label: $label")
        end
        for label in sort!(collect(setdiff(actual, expected)))
            push!(failures, "parity policy contains unknown reference label: $label")
        end
    end

    command_entrypoints = array_values(policy, "required_command_entrypoints")
    if command_entrypoints === nothing
        push!(failures, "parity policy missing required_command_entrypoints array")
    else
        expected = Set(EXPECTED_COMMAND_ENTRYPOINTS)
        actual = Set(command_entrypoints)
        for label in sort!(collect(setdiff(expected, actual)))
            push!(failures, "parity policy missing command entrypoint: $label")
        end
        for label in sort!(collect(setdiff(actual, expected)))
            push!(failures, "parity policy contains unknown command entrypoint: $label")
        end
        for label in EXPECTED_COMMAND_ENTRYPOINTS
            occursin(label, readme) || push!(
                failures,
                "parity evidence README missing command entrypoint: $label",
            )
        end
        occursin("required_command_entrypoints", scaffold) &&
            occursin("policy_command_entrypoints", scaffold) || push!(
                failures,
                "parity evidence scaffold must read required_command_entrypoints from policy",
            )
        occursin("required_command_entrypoints", closeout) &&
            occursin("policy_contract", closeout) || push!(
                failures,
                "parity closeout audit must read required_command_entrypoints from policy",
            )
    end

    artifact_url_schemes = array_values(policy, "allowed_artifact_url_schemes")
    if artifact_url_schemes === nothing
        push!(failures, "parity policy missing allowed_artifact_url_schemes array")
    else
        expected = Set(EXPECTED_ARTIFACT_URL_SCHEMES)
        actual = Set(artifact_url_schemes)
        for label in sort!(collect(setdiff(expected, actual)))
            push!(failures, "parity policy missing artifact URL scheme: $label")
        end
        for label in sort!(collect(setdiff(actual, expected)))
            push!(failures, "parity policy contains unknown artifact URL scheme: $label")
        end
        for label in EXPECTED_ARTIFACT_URL_SCHEMES
            occursin(label, readme) || push!(
                failures,
                "parity evidence README missing artifact URL scheme: $label",
            )
        end
        occursin("allowed_artifact_url_schemes", scaffold) &&
            occursin("policy_artifact_url_schemes", scaffold) || push!(
                failures,
                "parity evidence scaffold must read allowed_artifact_url_schemes from policy",
            )
        occursin("allowed_artifact_url_schemes", closeout) &&
            occursin("policy_contract", closeout) || push!(
                failures,
                "parity closeout audit must read allowed_artifact_url_schemes from policy",
            )
    end

    manual_artifact_hints = array_values(policy, "manual_artifact_hints")
    if manual_artifact_hints === nothing
        push!(failures, "parity policy missing manual_artifact_hints array")
    else
        expected = Set(EXPECTED_MANUAL_ARTIFACT_HINTS)
        actual = Set(manual_artifact_hints)
        for label in sort!(collect(setdiff(expected, actual)))
            push!(failures, "parity policy missing manual artifact hint: $label")
        end
        for label in sort!(collect(setdiff(actual, expected)))
            push!(failures, "parity policy contains unknown manual artifact hint: $label")
        end
        for label in EXPECTED_MANUAL_ARTIFACT_HINTS
            occursin(label, readme) || push!(
                failures,
                "parity evidence README missing manual artifact hint: $label",
            )
        end
        occursin("manual_artifact_hints", closeout) &&
            occursin("artifact_matches_manual_hint", closeout) || push!(
                failures,
                "parity closeout audit must read manual_artifact_hints from policy",
            )
    end

    occursin("minimum_final_records_per_family", closeout) &&
        occursin("positive_integer_value", closeout) || push!(
            failures,
            "parity closeout audit must read minimum_final_records_per_family from policy",
        )

    for family in EXPECTED_FAMILIES
        scope = EXPECTED_SCOPES[family]
        occursin("\"$family\"", scaffold) || push!(
            failures,
            "parity evidence scaffold missing family: $family",
        )
        occursin(scope, scaffold) || push!(
            failures,
            "parity evidence scaffold missing scope for $family",
        )
        occursin("`$family`", readme) || push!(
            failures,
            "parity evidence README missing family: $family",
        )
        occursin(scope, readme) || push!(
            failures,
            "parity evidence README missing scope for $family",
        )
        occursin(checklist_item(family, scope), checklist) || push!(
            failures,
            "release checklist missing parity evidence item for $family",
        )
    end

    return failures
end

function main(arguments=ARGS)
    isempty(arguments) || error("unknown arguments: $(join(arguments, ", "))")
    failures = audit()
    if isempty(failures)
        println("parity policy audit: checked $(length(EXPECTED_FAMILIES)) evidence families")
        return 0
    end
    foreach(failure -> println(stderr, "parity policy audit: $failure"), failures)
    return 1
end

end # module ParityPolicyAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(ParityPolicyAudit.main())
end
