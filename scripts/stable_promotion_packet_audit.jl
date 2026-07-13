#!/usr/bin/env julia

module StablePromotionPacketAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const PACKET_DIR = joinpath(ROOT, "docs", "stable-promotion-packets")
const STABLE_API_PATH = joinpath(ROOT, "api", "stable_api.tsv")
const STABLE_WIDGET_CANDIDATES_PATH = joinpath(ROOT, "api", "stable_widget_candidates.tsv")
const WIDGET_COVERAGE_PATH = joinpath(ROOT, "api", "widget_coverage.tsv")
const WIDGET_FAMILY_EVIDENCE_PATH = joinpath(ROOT, "api", "widget_family_evidence.tsv")
const VALID_DECISIONS = Set(("promote", "qualify", "remove"))
const REQUIRED_IDENTITY_FIELDS = (
    "Widget family",
    "Widget name",
    "Source file",
    "Release-candidate commit",
    "Reviewer",
    "Decision",
)
const REQUIRED_SECTIONS = (
    "Public API decision",
    "Behavior evidence",
    "Promotion evidence",
    "Developer evidence",
    "Family and startup evidence",
    "Compatibility and release evidence",
    "Risks and follow-ups",
)
const PLACEHOLDER_PATTERN = r"(?i)\b(todo|placeholder|dummy|tbd|unknown)\b"

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/stable_promotion_packet_audit.jl [--require-complete]")
    println(io, "")
    println(io, "Validates completed stable widget promotion packet records.")
end

function packet_files(packet_dir::AbstractString=PACKET_DIR)
    isdir(packet_dir) || return String[]
    return sort!(
        String[
            path for path in readdir(packet_dir; join=true)
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
        key in ("Field", "Evidence", "---") && continue
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

function slug(value)
    lowered = lowercase(strip(value))
    replaced = replace(lowered, r"[^a-z0-9]+" => "-")
    return replace(replaced, r"^-+|-+$" => "")
end

function read_tsv_table(path::AbstractString)
    isfile(path) || return Dict{String,String}[]
    rows = Dict{String,String}[]
    header = String[]
    for raw_line in eachsplit(read(path, String), '\n')
        line = strip(raw_line)
        (isempty(line) || startswith(line, "#")) && continue
        cells = split(raw_line, '\t'; keepempty=true)
        if isempty(header)
            header = String.(cells)
            continue
        end
        row = Dict{String,String}()
        for (index, key) in enumerate(header)
            row[key] = index <= length(cells) ? cells[index] : ""
        end
        push!(rows, row)
    end
    return rows
end

function source_file_exists(source_file::AbstractString)
    startswith(source_file, "src/") || return false
    return isfile(joinpath(ROOT, source_file))
end

function stable_api_has_widget(widget::AbstractString)
    rows = read_tsv_table(STABLE_API_PATH)
    return any(rows) do row
        name = get(row, "name", get(row, "symbol", ""))
        binding = get(row, "binding-kind", get(row, "binding", get(row, "kind", "")))
        name == widget && !isempty(strip(binding))
    end
end

function stable_candidate_has_widget(widget::AbstractString, source_file::AbstractString)
    rows = read_tsv_table(STABLE_WIDGET_CANDIDATES_PATH)
    return any(rows) do row
        get(row, "widget", "") == widget &&
            get(row, "source", "") == source_file &&
            get(row, "surface", "") == "stable" &&
            get(row, "status", "") == "stable"
    end
end

function widget_coverage_has_widget(widget::AbstractString, source_file::AbstractString)
    accepted_names = Set(("Wicked.$widget", "Wicked.Widgets.$widget"))
    rows = read_tsv_table(WIDGET_COVERAGE_PATH)
    return any(rows) do row
        get(row, "widget_type", "") in accepted_names && get(row, "source", "") == source_file
    end
end

function family_evidence_has_widget(family::AbstractString, widget::AbstractString)
    family_key = lowercase(strip(family))
    rows = read_tsv_table(WIDGET_FAMILY_EVIDENCE_PATH)
    return any(rows) do row
        tokens = strip.(split(get(row, "stable_api_tokens", ""), ','))
        lowercase(strip(get(row, "family", ""))) == family_key &&
            widget in tokens
    end
end

function validate_record(path::AbstractString)
    source = read(path, String)
    fields = table_fields(source)
    failures = String[]
    relative = relpath(path, ROOT)

    has_placeholder(source) && push!(failures, "$relative contains placeholder text")
    for field in REQUIRED_IDENTITY_FIELDS
        value = get(fields, field, "")
        concrete_text(value) || push!(failures, "$relative has empty or placeholder identity field: $field")
    end
    for section in REQUIRED_SECTIONS
        body = section_body(source, section)
        concrete_text(body) || push!(failures, "$relative section `$section` must contain concrete evidence text")
    end

    family = get(fields, "Widget family", "")
    widget = get(fields, "Widget name", "")
    candidate = get(fields, "Release-candidate commit", "")
    decision = lowercase(get(fields, "Decision", ""))
    source_file = get(fields, "Source file", "")

    occursin(r"^[0-9a-fA-F]{7,40}$", candidate) ||
        push!(failures, "$relative release-candidate commit must be a short or full hexadecimal SHA")
    !isempty(candidate) && length(Set(collect(lowercase(candidate)))) == 1 &&
        push!(failures, "$relative release-candidate commit must not be a repeated-character placeholder")
    decision in VALID_DECISIONS ||
        push!(failures, "$relative decision must be one of promote, qualify, or remove")
    !isempty(strip(source_file)) && startswith(source_file, "src/") ||
        push!(failures, "$relative source file must identify a src/ path")
    source_file_exists(source_file) ||
        push!(failures, "$relative source file must exist in the repository")
    stable_api_has_widget(widget) ||
        push!(failures, "$relative widget `$widget` must exist in api/stable_api.tsv")
    stable_candidate_has_widget(widget, source_file) ||
        push!(failures, "$relative widget `$widget` must have a stable api/stable_widget_candidates.tsv row with source `$source_file`")
    widget_coverage_has_widget(widget, source_file) ||
        push!(failures, "$relative widget `$widget` must have api/widget_coverage.tsv behavior evidence with source `$source_file`")
    family_evidence_has_widget(family, widget) ||
        push!(failures, "$relative widget `$widget` must be listed in api/widget_family_evidence.tsv for family `$family`")

    filename = lowercase(basename(path))
    !isempty(family) && !occursin(slug(family), filename) &&
        push!(failures, "$relative filename must include widget family slug `$(slug(family))`")
    !isempty(widget) && !occursin(slug(widget), filename) &&
        push!(failures, "$relative filename must include widget slug `$(slug(widget))`")
    !isempty(candidate) && !occursin(lowercase(candidate), filename) &&
        push!(failures, "$relative filename must include release-candidate commit `$candidate`")

    if occursin("Wicked.Experimental", source)
        occursin("accepted", lowercase(source)) || occursin("completed", lowercase(source)) ||
            push!(failures, "$relative must record accepted or completed review status when Wicked.Experimental was involved")
    end
    occursin("api/widget_coverage.tsv", source) ||
        push!(failures, "$relative must cite api/widget_coverage.tsv behavior evidence")
    occursin("api/widget_promotion_requirements.tsv", source) ||
        push!(failures, "$relative must cite api/widget_promotion_requirements.tsv promotion requirements evidence")
    occursin("api/stable_widget_candidates.tsv", source) ||
        push!(failures, "$relative must cite api/stable_widget_candidates.tsv promotion evidence")
    occursin("api/stable_api.tsv", source) ||
        push!(failures, "$relative must cite api/stable_api.tsv stable API evidence")
    occursin("src/Precompile.jl", source) ||
        push!(failures, "$relative must cite src/Precompile.jl startup evidence")
    occursin("scripts/pilot_evidence_package_audit.jl", source) ||
        push!(failures, "$relative must cite scripts/pilot_evidence_package_audit.jl pilot evidence package validation")
    occursin("Pilot evidence package checked", source) ||
        push!(failures, "$relative must include a pilot evidence package promotion row")
    occursin("Package-level pilot evidence reports", source) ||
        push!(failures, "$relative must include a package-level pilot evidence reports promotion row")
    occursin("write_pilot_evidence_package", source) ||
        push!(failures, "$relative must cite write_pilot_evidence_package pilot evidence package creation")
    occursin("write_pilot_evidence_package_reports", source) ||
        push!(failures, "$relative must cite write_pilot_evidence_package_reports package-level report creation")
    occursin("Stable facade usage with no Wicked internals", source) ||
        push!(failures, "$relative must include stable facade usage developer evidence")
    occursin("Wicked.API", source) ||
        push!(failures, "$relative must cite Wicked.API stable facade usage")
    return failures
end

function audit(; packet_dir::AbstractString=PACKET_DIR, require_complete::Bool=false)
    failures = String[]
    identities = Dict{Tuple{String,String},String}()
    files = packet_files(packet_dir)
    for path in files
        append!(failures, validate_record(path))
        fields = table_fields(read(path, String))
        widget = get(fields, "Widget name", "")
        candidate = lowercase(get(fields, "Release-candidate commit", ""))
        identity = (widget, candidate)
        if !isempty(widget) && !isempty(candidate)
            if haskey(identities, identity)
                push!(
                    failures,
                    "$(relpath(path, ROOT)) duplicates stable promotion packet identity from $(identities[identity])",
                )
            else
                identities[identity] = relpath(path, ROOT)
            end
        end
    end
    if require_complete && isempty(files)
        push!(failures, "stable promotion packet complete mode requires at least one completed packet record")
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
        mode = "--require-complete" in arguments ? "complete stable promotion packet records" : "stable promotion packet record shape"
        println("stable promotion packet audit: $mode passed")
        return 0
    end
    foreach(failure -> println(stderr, "stable promotion packet audit: $failure"), failures)
    return 1
end

end # module StablePromotionPacketAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(StablePromotionPacketAudit.main())
end
