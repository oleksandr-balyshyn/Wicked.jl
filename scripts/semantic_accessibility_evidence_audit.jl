#!/usr/bin/env julia

module SemanticAccessibilityEvidenceAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EVIDENCE_DIR = joinpath(ROOT, "docs", "semantic-evidence")
const REQUIRED_FAMILIES = (
    "Core layout",
    "Text and structure",
    "Inputs and controls",
    "Navigation",
    "Data and virtualization",
    "Visualization",
    "Rich content",
    "Runtime and services",
    "Toolkit",
    "Testing and semantics",
)
const REQUIRED_IDENTITY_FIELDS = (
    "Release-candidate commit",
    "Date and UTC time",
    "Julia version",
    "Linux distribution, kernel, architecture, and shell",
    "Active project and manifest digest",
    "Widget family scope",
    "Interactive widget inventory digest",
    "Semantic audit command",
    "Exit status",
    "Semantic snapshot artifact path or CI URL",
    "Action dispatch artifact path or CI URL",
)
const REQUIRED_BEHAVIOR_FIELDS = (
    "Semantic tree generated for each interactive stable widget",
    "Semantic roles, labels, states, and bounds checked",
    "Stable semantic node IDs checked",
    "Semantic actions exposed for actionable widgets",
    "Semantic dispatch handlers registered for actionable widgets",
    "Keyboard action dispatch checked",
    "Pointer action dispatch checked or marked not applicable",
    "Focus and disabled-state semantics checked",
    "Virtualized, modal, tabbed, progress, and notification states checked when present",
    "WidgetPilot or ToolkitPilot semantic queries checked",
    "No placeholder-only semantic snapshots accepted",
)
const PLACEHOLDER_PATTERN = r"(?i)\b(todo|placeholder|dummy|tbd|unknown)\b"
const ARTIFACT_PLACEHOLDER_PATTERN = r"(?i)\b(example\.invalid|example\.com|placeholder|dummy)\b|/OWNER/|/REPO/|/RUN_ID"

family_slug(family::AbstractString) = replace(lowercase(strip(family)), r"[^a-z0-9]+" => "-") |> value -> strip(value, '-')

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/semantic_accessibility_evidence_audit.jl [--require-complete]")
    println(io, "")
    println(io, "Validates completed semantic and accessibility evidence records for stable widget families.")
end

function evidence_files(evidence_dir::AbstractString=EVIDENCE_DIR)
    isdir(evidence_dir) || return String[]
    return sort!(
        String[
            path for path in readdir(evidence_dir; join=true)
            if isfile(path) && endswith(path, ".md") && basename(path) != "README.md"
        ],
    )
end

function table_fields(source::AbstractString)
    fields = Dict{String,String}()
    for line in eachsplit(source, '\n')
        matched = match(r"^\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|$", line)
        matched === nothing && continue
        key = strip(matched.captures[1])
        value = strip(matched.captures[2])
        key in ("Field", "Behavior", "---") && continue
        isempty(key) && continue
        fields[key] = value
    end
    return fields
end

function section_body(source::AbstractString, heading::AbstractString)
    matched = match(Regex("(?ms)^##\\s+" * escape_string(heading) * "\\s*\$\\n(.*?)(?=^##\\s+|\\z)"), source)
    matched === nothing && return nothing
    return strip(matched.captures[1])
end

has_placeholder(value::AbstractString) = occursin(PLACEHOLDER_PATTERN, value)

function concrete_text(value)
    value === nothing && return false
    stripped = strip(String(value))
    isempty(stripped) && return false
    stripped in ("-", "- ") && return false
    has_placeholder(stripped) && return false
    return true
end

function is_url_or_existing_path(value::AbstractString)
    stripped = strip(value)
    startswith(stripped, "https://") && return true
    startswith(stripped, "http://") && return true
    return ispath(isabspath(stripped) ? stripped : normpath(joinpath(ROOT, stripped)))
end

function validate_artifact!(failures::Vector{String}, relative::AbstractString, field::AbstractString, value::AbstractString)
    occursin(ARTIFACT_PLACEHOLDER_PATTERN, value) &&
        push!(failures, "$relative $field must be a real semantic evidence artifact path or CI URL")
    !isempty(strip(value)) && !is_url_or_existing_path(value) &&
        push!(failures, "$relative $field must be an HTTP(S) URL or an existing artifact path")
end

function validate_record(path::AbstractString)
    source = read(path, String)
    fields = table_fields(source)
    failures = String[]
    relative = relpath(path, ROOT)

    occursin("TODO", source) && push!(failures, "$relative contains TODO placeholder text")
    for field in REQUIRED_IDENTITY_FIELDS
        value = get(fields, field, "")
        concrete_text(value) || push!(failures, "$relative has empty or placeholder identity field: $field")
    end
    for behavior in REQUIRED_BEHAVIOR_FIELDS
        value = get(fields, behavior, "")
        concrete_text(value) || push!(failures, "$relative has empty or placeholder behavior field: $behavior")
    end

    candidate = get(fields, "Release-candidate commit", "")
    !isempty(candidate) && !occursin(lowercase(candidate), lowercase(basename(path))) &&
        push!(failures, "$relative filename must include release-candidate commit `$candidate`")
    occursin(r"^[0-9a-fA-F]{7,40}$", candidate) ||
        push!(failures, "$relative release-candidate commit must be a short or full hexadecimal SHA")
    occursin(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC$", get(fields, "Date and UTC time", "")) ||
        push!(failures, "$relative date must use YYYY-MM-DD HH:MM:SS UTC")
    occursin(r"^\d+\.\d+(\.\d+)?(-[A-Za-z0-9.+-]+)?$", get(fields, "Julia version", "")) ||
        push!(failures, "$relative Julia version must use a semver-like value")
    occursin(r"(?i)\blinux\b", get(fields, "Linux distribution, kernel, architecture, and shell", "")) ||
        push!(failures, "$relative kernel identity must be Linux")
    occursin(r"^\d+$", get(fields, "Exit status", "")) ||
        push!(failures, "$relative exit status must be a non-negative integer")

    family = get(fields, "Widget family scope", "")
    family in REQUIRED_FAMILIES || push!(failures, "$relative widget family scope must match a stable widget family")
    !isempty(family) && !occursin(family_slug(family), lowercase(basename(path))) &&
        push!(failures, "$relative filename must include widget family slug `$(family_slug(family))`")

    command = get(fields, "Semantic audit command", "")
    occursin("scripts/widget_audit.jl", command) && occursin("--require-complete", command) ||
        push!(failures, "$relative semantic audit command must run scripts/widget_audit.jl --require-complete")
    occursin("scripts/widget_family_evidence_audit.jl", command) ||
        push!(failures, "$relative semantic audit command must include scripts/widget_family_evidence_audit.jl")

    validate_artifact!(failures, relative, "semantic snapshot artifact", get(fields, "Semantic snapshot artifact path or CI URL", ""))
    validate_artifact!(failures, relative, "action dispatch artifact", get(fields, "Action dispatch artifact path or CI URL", ""))

    for section in ("Evidence summary", "Risks and follow-up")
        body = section_body(source, section)
        concrete_text(body) || push!(failures, "$relative section `$section` must contain concrete evidence text")
    end
    return failures
end

function audit(; evidence_dir::AbstractString=EVIDENCE_DIR, require_complete::Bool=false)
    failures = String[]
    families = Set{String}()
    identities = Dict{Tuple{String,String},String}()
    for path in evidence_files(evidence_dir)
        append!(failures, validate_record(path))
        fields = table_fields(read(path, String))
        family = get(fields, "Widget family scope", "")
        candidate = lowercase(get(fields, "Release-candidate commit", ""))
        family in REQUIRED_FAMILIES && push!(families, family)
        identity = (family, candidate)
        if family in REQUIRED_FAMILIES && !isempty(candidate)
            if haskey(identities, identity)
                push!(failures, "$(relpath(path, ROOT)) duplicates semantic evidence identity from $(identities[identity])")
            else
                identities[identity] = relpath(path, ROOT)
            end
        end
    end
    if require_complete
        for family in REQUIRED_FAMILIES
            family in families || push!(failures, "semantic evidence complete mode requires a completed record for family `$family`")
        end
    end
    return failures
end

function main(arguments=ARGS)
    "--help" in arguments && (print_usage(); return 0)
    known = Set(["--require-complete"])
    for argument in arguments
        argument in known || (println(stderr, "unknown argument: $argument"); print_usage(stderr); return 2)
    end
    failures = audit(; require_complete="--require-complete" in arguments)
    if isempty(failures)
        mode = "--require-complete" in arguments ? "complete semantic evidence" : "semantic evidence record shape"
        println("semantic accessibility evidence audit: $mode passed")
        return 0
    end
    foreach(failure -> println(stderr, "semantic accessibility evidence audit: $failure"), failures)
    return 1
end

end # module SemanticAccessibilityEvidenceAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(SemanticAccessibilityEvidenceAudit.main())
end
