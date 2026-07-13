#!/usr/bin/env julia

module BenchmarkEvidenceAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EVIDENCE_DIR = joinpath(ROOT, "docs", "benchmark-evidence")
const REQUIRED_IDENTITY_FIELDS = (
    "Release-candidate commit",
    "Date and UTC time",
    "Julia version",
    "Linux distribution, kernel, architecture, and shell",
    "Active project and manifest digest",
    "Benchmark command",
    "Exit status",
    "Benchmark artifact path or CI URL",
    "Budget file digest",
    "Samples and warmups",
)
const REQUIRED_WORKLOADS = (
    "Buffer diff",
    "Sparse and full-screen buffer diff",
    "Unicode width",
    "Runtime input and idle draw",
    "Diagnostics overhead",
    "Services pulse",
    "Actions and routed events",
    "Animations",
    "Layout",
    "Deep flex and grid layout",
    "Stylesheet parsing and cascade",
    "Toolkit reconciliation",
    "High-churn Toolkit reconciliation",
    "Markdown parsing and rendering",
    "Large Markdown and stylesheet documents",
    "Virtual data",
    "Million-row virtual list and table windows",
    "Semantic diffing",
    "Progress and live-display workloads",
)
const PLACEHOLDER_PATTERN = r"(?i)\b(todo|placeholder|dummy|tbd|unknown)\b"
const ARTIFACT_PLACEHOLDER_PATTERN = r"(?i)\b(example\.invalid|example\.com|placeholder|dummy)\b|/OWNER/|/REPO/|/RUN_ID"

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/benchmark_evidence_audit.jl [--require-complete]")
    println(io, "")
    println(io, "Validates completed release-candidate benchmark evidence records.")
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
        key in ("Field", "Workload group", "---") && continue
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
    for workload in REQUIRED_WORKLOADS
        value = get(fields, workload, "")
        concrete_text(value) || push!(failures, "$relative has empty or placeholder workload field: $workload")
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

    command = get(fields, "Benchmark command", "")
    occursin("benchmark/run.jl", command) && occursin("--check", command) ||
        push!(failures, "$relative benchmark command must run benchmark/run.jl --check")
    artifact = get(fields, "Benchmark artifact path or CI URL", "")
    occursin(ARTIFACT_PLACEHOLDER_PATTERN, artifact) &&
        push!(failures, "$relative artifact must be a real benchmark artifact path or CI URL")
    !isempty(strip(artifact)) && !is_url_or_existing_path(artifact) &&
        push!(failures, "$relative artifact must be an HTTP(S) URL or an existing artifact path")

    for section in ("Evidence summary", "Regression review")
        body = section_body(source, section)
        concrete_text(body) || push!(failures, "$relative section `$section` must contain concrete evidence text")
    end
    return failures
end

function audit(; evidence_dir::AbstractString=EVIDENCE_DIR, require_complete::Bool=false)
    failures = String[]
    files = evidence_files(evidence_dir)
    candidates = Set{String}()
    for path in files
        append!(failures, validate_record(path))
        candidate = lowercase(get(table_fields(read(path, String)), "Release-candidate commit", ""))
        if !isempty(candidate)
            candidate in candidates &&
                push!(failures, "$(relpath(path, ROOT)) duplicates benchmark evidence for candidate `$candidate`")
            push!(candidates, candidate)
        end
    end
    require_complete && isempty(candidates) &&
        push!(failures, "benchmark evidence complete mode requires at least one completed benchmark record")
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
        mode = "--require-complete" in arguments ? "complete benchmark evidence" : "benchmark evidence record shape"
        println("benchmark evidence audit: $mode passed")
        return 0
    end
    foreach(failure -> println(stderr, "benchmark evidence audit: $failure"), failures)
    return 1
end

end # module BenchmarkEvidenceAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(BenchmarkEvidenceAudit.main())
end
