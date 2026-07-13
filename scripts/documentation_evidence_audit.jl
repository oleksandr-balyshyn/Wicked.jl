#!/usr/bin/env julia

module DocumentationEvidenceAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EVIDENCE_DIR = joinpath(ROOT, "docs", "documentation-evidence")
const MINIMUM_JULIA_VERSIONS = 2
const REQUIRED_IDENTITY_FIELDS = (
    "Release-candidate commit",
    "Date and UTC time",
    "Julia version",
    "Linux distribution, kernel, architecture, and shell",
    "Documentation project and manifest digest",
    "Documentation instantiate command",
    "Documentation build command",
    "Exit status",
    "Documentation artifact path or CI URL",
    "Generated output path",
    "Documenter configuration",
)
const REQUIRED_BEHAVIOR_FIELDS = (
    "`Pkg.develop(PackageSpec(path=pwd()))` completed",
    "`Pkg.instantiate()` completed",
    "`docs/make.jl` completed",
    "`doctest = true` enforced",
    "`checkdocs = :exports` enforced",
    "`WICKED_DOC_MODULES` discovered Wicked submodules",
    "API route map and stable facade guidance were included",
    "Public example family index was included",
    "Release and evidence gates were linked",
    "Generated HTML was archived",
    "No Documenter warnings",
    "No missing cross-reference or link errors",
)
const PLACEHOLDER_PATTERN = r"(?i)\b(todo|placeholder|dummy|tbd|unknown)\b"
const ARTIFACT_PLACEHOLDER_PATTERN = r"(?i)\b(example\.invalid|example\.com|placeholder|dummy)\b|/OWNER/|/REPO/|/RUN_ID"

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/documentation_evidence_audit.jl [--require-complete]")
    println(io, "")
    println(io, "Validates completed strict Documenter manual evidence records.")
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

function julia_minor(version::AbstractString)
    matched = match(r"^(\d+\.\d+)(?:\.\d+)?(?:-[A-Za-z0-9.+-]+)?$", strip(version))
    matched === nothing && return ""
    return matched.captures[1]
end

function is_url_or_existing_path(value::AbstractString)
    stripped = strip(value)
    startswith(stripped, "https://") && return true
    startswith(stripped, "http://") && return true
    return ispath(isabspath(stripped) ? stripped : normpath(joinpath(ROOT, stripped)))
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
    version = get(fields, "Julia version", "")
    !isempty(candidate) && !occursin(lowercase(candidate), lowercase(basename(path))) &&
        push!(failures, "$relative filename must include release-candidate commit `$candidate`")
    minor = julia_minor(version)
    !isempty(minor) && !occursin(replace(minor, "." => "-"), lowercase(basename(path))) &&
        push!(failures, "$relative filename must include Julia minor version `$(replace(minor, "." => "-"))`")
    occursin(r"^[0-9a-fA-F]{7,40}$", candidate) ||
        push!(failures, "$relative release-candidate commit must be a short or full hexadecimal SHA")
    !isempty(minor) || push!(failures, "$relative Julia version must use a semver-like value")
    occursin(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC$", get(fields, "Date and UTC time", "")) ||
        push!(failures, "$relative date must use YYYY-MM-DD HH:MM:SS UTC")
    occursin(r"(?i)\blinux\b", get(fields, "Linux distribution, kernel, architecture, and shell", "")) ||
        push!(failures, "$relative kernel identity must be Linux")
    occursin(r"^\d+$", get(fields, "Exit status", "")) ||
        push!(failures, "$relative exit status must be a non-negative integer")

    instantiate_command = get(fields, "Documentation instantiate command", "")
    occursin("--project=docs", instantiate_command) || push!(failures, "$relative instantiate command must use --project=docs")
    occursin("Pkg.develop", instantiate_command) || push!(failures, "$relative instantiate command must run Pkg.develop")
    occursin("PackageSpec(path=pwd())", instantiate_command) || push!(failures, "$relative instantiate command must develop the current checkout")
    occursin("Pkg.instantiate", instantiate_command) || push!(failures, "$relative instantiate command must run Pkg.instantiate()")

    build_command = get(fields, "Documentation build command", "")
    occursin("--project=docs", build_command) || push!(failures, "$relative documentation build command must use --project=docs")
    occursin("docs/make.jl", build_command) || push!(failures, "$relative documentation build command must run docs/make.jl")

    config = get(fields, "Documenter configuration", "")
    occursin("doctest = true", config) || push!(failures, "$relative Documenter configuration must record doctest = true")
    occursin("checkdocs = :exports", config) || push!(failures, "$relative Documenter configuration must record checkdocs = :exports")
    output_path = get(fields, "Generated output path", "")
    occursin("build/docs", output_path) || push!(failures, "$relative generated output path must reference build/docs")

    artifact = get(fields, "Documentation artifact path or CI URL", "")
    occursin(ARTIFACT_PLACEHOLDER_PATTERN, artifact) &&
        push!(failures, "$relative artifact must be a real documentation artifact path or CI URL")
    !isempty(strip(artifact)) && !is_url_or_existing_path(artifact) &&
        push!(failures, "$relative artifact must be an HTTP(S) URL or an existing artifact path")

    for section in ("Evidence summary", "Risks and follow-up")
        body = section_body(source, section)
        concrete_text(body) || push!(failures, "$relative section `$section` must contain concrete evidence text")
    end
    return failures
end

function audit(; evidence_dir::AbstractString=EVIDENCE_DIR, require_complete::Bool=false)
    failures = String[]
    versions = Set{String}()
    identities = Dict{Tuple{String,String},String}()
    for path in evidence_files(evidence_dir)
        append!(failures, validate_record(path))
        fields = table_fields(read(path, String))
        version = julia_minor(get(fields, "Julia version", ""))
        candidate = lowercase(get(fields, "Release-candidate commit", ""))
        !isempty(version) && push!(versions, version)
        identity = (version, candidate)
        if !isempty(version) && !isempty(candidate)
            if haskey(identities, identity)
                push!(
                    failures,
                    "$(relpath(path, ROOT)) duplicates documentation evidence identity from $(identities[identity])",
                )
            else
                identities[identity] = relpath(path, ROOT)
            end
        end
    end
    if require_complete && length(versions) < MINIMUM_JULIA_VERSIONS
        push!(
            failures,
            "documentation evidence complete mode requires at least $MINIMUM_JULIA_VERSIONS distinct Julia versions, found $(length(versions))",
        )
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
        mode = "--require-complete" in arguments ? "complete documentation evidence" : "documentation evidence record shape"
        println("documentation evidence audit: $mode passed")
        return 0
    end
    foreach(failure -> println(stderr, "documentation evidence audit: $failure"), failures)
    return 1
end

end # module DocumentationEvidenceAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(DocumentationEvidenceAudit.main())
end
