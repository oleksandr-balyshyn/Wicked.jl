#!/usr/bin/env julia

module ParityCloseoutAudit

include(joinpath(@__DIR__, "render_reference_parity_matrix.jl"))

const ROOT = normpath(joinpath(@__DIR__, ".."))
const POLICY = joinpath(ROOT, "docs", "evidence", "parity_policy.json")
const CLOSEOUT_REQUIREMENTS_SCHEMA = joinpath(ROOT, "docs", "evidence", "parity_closeout_requirements.schema.json")
const EVIDENCE_DIR = joinpath(ROOT, "docs", "evidence")
const RELEASE_READY_STATUS = ReferenceParityMatrixRender.RELEASE_READY_STATUS
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
const SURVEY_TO_POLICY_FAMILY = Dict(
    "Layout" => "Layout",
    "Input/event" => "Input-event",
    "Stateful controls" => "Stateful-controls",
    "Data displays" => "Data-display",
    "Runtime" => "Runtime",
    "Developer experience" => "Developer-experience",
    "Styling/theming" => "Styling-theming",
    "Remote delivery" => "Remote-delivery",
)
const REQUIRED_FIELDS = (
    "Family",
    "Release-candidate commit",
    "Date and UTC time",
    "Julia version",
    "Kernel and distribution",
    "Terminal or browser environment",
    "Width policy and color capability",
    "Command",
    "Exit status",
    "Artifact path or CI URL",
)
const REQUIRED_SECTIONS = (
    "Behaviors checked",
    "Reference-library parity notes",
    "Evidence summary",
    "Risks and follow-up",
)
const PLACEHOLDER_PATTERN = r"(?i)\b(todo|placeholder|dummy|tbd|unknown)\b"
const ARTIFACT_PLACEHOLDER_PATTERN = r"(?i)\b(example\.invalid|example\.com|placeholder|dummy)\b|/OWNER/|/REPO/|/RUN_ID"
const REFERENCE_PATTERN = r"(?i)\b(ratatui|textual|tamboui|lanterna|intentional divergence)\b"

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/parity_closeout_audit.jl [--require-complete] [--status] [--report <markdown|tsv|json>] [--family <family>] [--output <path>]")
    println(io, "")
    println(io, "Validates committed final parity evidence records under docs/evidence/.")
    println(io, "--require-complete also requires at least one valid record for every non-matched reference-survey family.")
end

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
    value === nothing && error("parity policy missing $key integer")
    value > 0 || error("parity policy $key must be positive")
    return value
end

function policy_contract(policy_path::AbstractString=POLICY)
    isfile(policy_path) || error("missing parity policy: $(relpath(policy_path, ROOT))")
    source = read(policy_path, String)
    families = object_entries(source, "families")
    families === nothing && error("parity policy missing families object")
    required_fields = array_values(source, "required_identity_fields")
    required_fields === nothing && error("parity policy missing required_identity_fields array")
    required_sections = array_values(source, "required_sections")
    required_sections === nothing && error("parity policy missing required_sections array")
    command_entrypoints = array_values(source, "required_command_entrypoints")
    command_entrypoints === nothing && error("parity policy missing required_command_entrypoints array")
    artifact_url_schemes = array_values(source, "allowed_artifact_url_schemes")
    artifact_url_schemes === nothing && error("parity policy missing allowed_artifact_url_schemes array")
    manual_artifact_hints = array_values(source, "manual_artifact_hints")
    manual_artifact_hints === nothing && error("parity policy missing manual_artifact_hints array")
    minimum_final_records_per_family = positive_integer_value(source, "minimum_final_records_per_family")
    return (
        families=families,
        required_fields=required_fields,
        required_sections=required_sections,
        command_entrypoints=command_entrypoints,
        artifact_url_schemes=artifact_url_schemes,
        manual_artifact_hints=manual_artifact_hints,
        minimum_final_records_per_family=minimum_final_records_per_family,
    )
end

function release_blocking_policy_families(survey_path::AbstractString=ReferenceParityMatrixRender.SURVEY)
    rows = ReferenceParityMatrixRender.parity_rows(survey_path)
    families = String[]
    for row in rows
        lowercase(row.status) == RELEASE_READY_STATUS && continue
        policy_family = get(SURVEY_TO_POLICY_FAMILY, row.family, "")
        !isempty(policy_family) && push!(families, policy_family)
    end
    return sort!(unique(families))
end

function release_blocking_survey_records(survey_path::AbstractString=ReferenceParityMatrixRender.SURVEY)
    records = Dict{String,NamedTuple}()
    for row in ReferenceParityMatrixRender.parity_rows(survey_path)
        lowercase(row.status) == RELEASE_READY_STATUS && continue
        policy_family = get(SURVEY_TO_POLICY_FAMILY, row.family, "")
        isempty(policy_family) && continue
        records[policy_family] = (
            survey_family=row.family,
            parity_status=row.status,
            follow_up=row.follow_up,
        )
    end
    return records
end

function survey_policy_mapping_failures(policy_families, survey_path::AbstractString=ReferenceParityMatrixRender.SURVEY)
    failures = String[]
    rows = ReferenceParityMatrixRender.parity_rows(survey_path)
    for row in rows
        lowercase(row.status) == RELEASE_READY_STATUS && continue
        policy_family = get(SURVEY_TO_POLICY_FAMILY, row.family, "")
        isempty(policy_family) && push!(failures, "reference parity survey family `$(row.family)` has no parity policy mapping")
        !isempty(policy_family) && !haskey(policy_families, policy_family) &&
            push!(failures, "reference parity survey family `$(row.family)` maps to missing parity policy family: $policy_family")
    end
    return failures
end

function policy_contract_failures(policy_path::AbstractString=POLICY)
    try
        return String[], policy_contract(policy_path)
    catch error
        return [sprint(showerror, error)], nothing
    end
end

function closeout_requirements_schema_failures(path::AbstractString=CLOSEOUT_REQUIREMENTS_SCHEMA)
    failures = String[]
    isfile(path) || return ["missing parity closeout requirements schema: $(relpath(path, ROOT))"]
    source = read(path, String)
    for required in (
        "\"schema_version\"",
        "\"const\": 1",
        "\"total\"",
        "\"missing\"",
        "\"release_ready\"",
        "\"rows\"",
        "\"family\"",
        "\"survey_family\"",
        "\"parity_status\"",
        "\"follow_up\"",
        "\"required\"",
        "\"observed\"",
        "\"status\"",
        "\"scope\"",
        "\"scaffold_command\"",
        "\"additionalProperties\": false",
    )
        occursin(required, source) || push!(failures, "parity closeout requirements schema missing required token: $required")
    end
    return failures
end

function json_integer_value(source::AbstractString, key::AbstractString)
    matched = match(Regex("\"" * key * "\"\\s*:\\s*(\\d+)"), source)
    return matched === nothing ? nothing : parse(Int, matched.captures[1])
end

function json_bool_value(source::AbstractString, key::AbstractString)
    matched = match(Regex("\"" * key * "\"\\s*:\\s*(true|false)"), source)
    return matched === nothing ? nothing : matched.captures[1] == "true"
end

function closeout_requirement_json_rows(source::AbstractString)
    return NamedTuple[
        (
            family=matched.captures[1],
            survey_family=matched.captures[2],
            parity_status=matched.captures[3],
            follow_up=matched.captures[4],
            required=parse(Int, matched.captures[5]),
            observed=parse(Int, matched.captures[6]),
            missing=parse(Int, matched.captures[7]),
            status=matched.captures[8],
            scaffold_command=matched.captures[9],
        )
        for matched in eachmatch(
            r"(?s)\"family\"\s*:\s*\"([^\"]+)\".*?\"survey_family\"\s*:\s*\"([^\"]+)\".*?\"parity_status\"\s*:\s*\"([^\"]+)\".*?\"follow_up\"\s*:\s*\"([^\"]+)\".*?\"required\"\s*:\s*(\d+).*?\"observed\"\s*:\s*(\d+).*?\"missing\"\s*:\s*(\d+).*?\"status\"\s*:\s*\"([^\"]+)\".*?\"scaffold_command\"\s*:\s*\"([^\"]+)\"",
            source,
        )
    ]
end

function expected_scaffold_command(family::AbstractString)
    return "julia --project=. scripts/new_parity_evidence.jl --family $family --environment <environment> --candidate <sha>"
end

function closeout_requirement_records(;
    policy_path::AbstractString=POLICY,
    evidence_dir::AbstractString=EVIDENCE_DIR,
    survey_path::AbstractString=ReferenceParityMatrixRender.SURVEY,
)
    contract = policy_contract(policy_path)
    observed = valid_record_counts(contract; evidence_dir=evidence_dir)
    required_families = release_blocking_policy_families(survey_path)
    survey_records = release_blocking_survey_records(survey_path)
    return [
        let
            survey_record = get(survey_records, family, (survey_family=family, parity_status="", follow_up=""))
            observed_count = get(observed, family, 0)
            (
                family=family,
                survey_family=survey_record.survey_family,
                parity_status=survey_record.parity_status,
                follow_up=survey_record.follow_up,
                required=contract.minimum_final_records_per_family,
                observed=observed_count,
                missing=max(contract.minimum_final_records_per_family - observed_count, 0),
                status=observed_count >= contract.minimum_final_records_per_family ? "ready" : "missing",
                scope=get(contract.families, family, ""),
                scaffold_command=expected_scaffold_command(family),
            )
        end for family in required_families
    ]
end

function closeout_requirements_json_failures(json::AbstractString)
    failures = String[]
    has_rows = occursin(r"\"rows\"\s*:\s*\[\s*\{", json)
    for required in (
        "\"schema_version\": 1",
        "\"total\":",
        "\"missing\":",
        "\"release_ready\":",
        "\"rows\": [",
        has_rows ? "\"family\":" : "",
        has_rows ? "\"survey_family\":" : "",
        has_rows ? "\"parity_status\":" : "",
        has_rows ? "\"follow_up\":" : "",
        has_rows ? "\"required\":" : "",
        has_rows ? "\"observed\":" : "",
        has_rows ? "\"missing\":" : "",
        has_rows ? "\"status\":" : "",
        has_rows ? "\"scope\":" : "",
        has_rows ? "\"scaffold_command\":" : "",
    )
        isempty(required) && continue
        occursin(required, json) || push!(failures, "parity closeout requirements JSON missing required token: $required")
    end
    total = json_integer_value(json, "total")
    missing = json_integer_value(json, "missing")
    release_ready = json_bool_value(json, "release_ready")
    rows = closeout_requirement_json_rows(json)
    total === nothing && push!(failures, "parity closeout requirements JSON missing `total`")
    missing === nothing && push!(failures, "parity closeout requirements JSON missing `missing`")
    release_ready === nothing && push!(failures, "parity closeout requirements JSON missing `release_ready`")
    !isempty(failures) && return failures

    total == length(rows) ||
        push!(failures, "parity closeout requirements JSON total must equal row count")
    json_missing = 0
    for row in rows
        json_missing += row.missing
    end
    json_missing == missing ||
        push!(failures, "parity closeout requirements JSON missing total must equal row missing sum")
    release_ready == (missing == 0) ||
        push!(failures, "parity closeout requirements JSON release_ready must match missing count")
    for row in rows
        required = row.required
        observed = row.observed
        row_missing = row.missing
        status = row.status
        isempty(row.survey_family) &&
            push!(failures, "parity closeout requirements JSON survey_family must not be empty")
        isempty(row.parity_status) &&
            push!(failures, "parity closeout requirements JSON parity_status must not be empty")
        isempty(row.follow_up) &&
            push!(failures, "parity closeout requirements JSON follow_up must not be empty")
        max(required - observed, 0) == row_missing ||
            push!(failures, "parity closeout requirements JSON row missing must equal max(required - observed, 0)")
        expected_status = row_missing == 0 ? "ready" : "missing"
        status == expected_status ||
            push!(failures, "parity closeout requirements JSON row status must match missing count")
        row.scaffold_command == expected_scaffold_command(row.family) ||
            push!(failures, "parity closeout requirements JSON scaffold_command must match row family")
    end
    return failures
end

function evidence_files(evidence_dir::AbstractString=EVIDENCE_DIR)
    isdir(evidence_dir) || return String[]
    return sort!(
        String[path for path in readdir(evidence_dir; join=true)
        if isfile(path) &&
            endswith(path, ".md") &&
            basename(path) != "README.md" &&
            basename(path) != "parity_policy.md"
        ]
    )
end

function identity_fields(source::AbstractString)
    fields = Dict{String,String}()
    for line in eachsplit(source, '\n')
        matched = match(r"^\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|$", line)
        matched === nothing && continue
        field = strip(matched.captures[1])
        value = strip(matched.captures[2])
        field in ("Field", "---") && continue
        isempty(field) && continue
        fields[field] = value
    end
    return fields
end

function section_body(source::AbstractString, heading::AbstractString)
    pattern = Regex("(?ms)^##\\s+" * escape_string(heading) * "\\s*\$\\n(.*?)(?=^##\\s+|\\z)")
    matched = match(pattern, source)
    matched === nothing && return nothing
    return strip(matched.captures[1])
end

function slug(value)
    lowered = lowercase(strip(value))
    replaced = replace(lowered, r"[^a-z0-9]+" => "-")
    return replace(replaced, r"^-+|-+$" => "")
end

has_placeholder(value::AbstractString) = occursin(PLACEHOLDER_PATTERN, value)

function is_url_or_existing_path(value::AbstractString, artifact_url_schemes)
    stripped = strip(value)
    any(scheme -> startswith(stripped, scheme), artifact_url_schemes) && return true
    return ispath(isabspath(stripped) ? stripped : normpath(joinpath(ROOT, stripped)))
end

function command_has_evidence_entrypoint(value::AbstractString, command_entrypoints)
    stripped = strip(value)
    return any(marker -> startswith(lowercase(marker), "manual:") ? startswith(lowercase(stripped), lowercase(marker)) : occursin(marker, stripped), command_entrypoints)
end

is_manual_command(value::AbstractString) = startswith(lowercase(strip(value)), "manual:")

function artifact_matches_manual_hint(value::AbstractString, manual_artifact_hints)
    lowered = lowercase(strip(value))
    return any(hint -> occursin(lowercase(hint), lowered), manual_artifact_hints)
end

function concrete_text(value)
    value === nothing && return false
    stripped = strip(String(value))
    isempty(stripped) && return false
    stripped in ("-", "- ") && return false
    has_placeholder(stripped) && return false
    return true
end

function validate_record(path::AbstractString, family_scopes, required_fields, required_sections, command_entrypoints, artifact_url_schemes, manual_artifact_hints)
    source = read(path, String)
    failures = String[]
    relative = relpath(path, ROOT)
    fields = identity_fields(source)

    occursin("TODO", source) && push!(failures, "$relative contains TODO placeholder text")
    for field in required_fields
        value = get(fields, field, "")
        concrete_text(value) || push!(failures, "$relative has empty or placeholder identity field: $field")
    end

    family = get(fields, "Family", "")
    candidate = get(fields, "Release-candidate commit", "")
    environment = get(fields, "Terminal or browser environment", "")
    filename = lowercase(basename(path))
    haskey(family_scopes, family) || push!(failures, "$relative uses unknown parity family: $family")
    if haskey(family_scopes, family) && !occursin(slug(family), filename)
        push!(failures, "$relative filename must include family slug `$(slug(family))`")
    end
    !isempty(environment) && !occursin(slug(environment), filename) &&
        push!(failures, "$relative filename must include environment slug `$(slug(environment))`")
    !isempty(candidate) && !occursin(lowercase(candidate), filename) &&
        push!(failures, "$relative filename must include release-candidate commit `$candidate`")
    occursin(r"^[0-9a-fA-F]{7,40}$", candidate) ||
        push!(failures, "$relative release-candidate commit must be a short or full hexadecimal SHA")
    occursin(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC$", get(fields, "Date and UTC time", "")) ||
        push!(failures, "$relative date must use YYYY-MM-DD HH:MM:SS UTC")
    occursin(r"^\d+\.\d+(\.\d+)?(-[A-Za-z0-9.+-]+)?$", get(fields, "Julia version", "")) ||
        push!(failures, "$relative Julia version must use a semver-like value")
    occursin(r"(?i)\blinux\b", get(fields, "Kernel and distribution", "")) ||
        push!(failures, "$relative kernel identity must be Linux")
    occursin(r"^\d+$", get(fields, "Exit status", "")) ||
        push!(failures, "$relative exit status must be a non-negative integer")

    artifact = get(fields, "Artifact path or CI URL", "")
    occursin(ARTIFACT_PLACEHOLDER_PATTERN, artifact) &&
        push!(failures, "$relative artifact must be a real artifact path or CI URL")
    !isempty(strip(artifact)) && !is_url_or_existing_path(artifact, artifact_url_schemes) &&
        push!(failures, "$relative artifact must be an HTTP(S) URL or an existing artifact path")
    command = get(fields, "Command", "")
    has_placeholder(command) &&
        push!(failures, "$relative command must be the exact evidence-producing command")
    !isempty(strip(command)) && !command_has_evidence_entrypoint(command, command_entrypoints) &&
        push!(failures, "$relative command must reference a Wicked validation/evidence entry point or start with manual:")
    is_manual_command(command) && !artifact_matches_manual_hint(artifact, manual_artifact_hints) &&
        push!(failures, "$relative manual evidence artifact must include a manual artifact hint from policy")

    for section in required_sections
        body = section_body(source, section)
        concrete_text(body) || push!(failures, "$relative section `$section` must contain concrete evidence text")
    end
    behavior = section_body(source, "Behaviors checked")
    if haskey(family_scopes, family)
        scope = family_scopes[family]
        (behavior !== nothing && occursin(scope, behavior)) || push!(
            failures,
            "$relative behaviors checked must include the policy closeout scope for $family: $scope",
        )
    end
    notes = section_body(source, "Reference-library parity notes")
    (notes !== nothing && occursin(REFERENCE_PATTERN, notes)) || push!(
        failures,
        "$relative reference-library parity notes must mention Ratatui, Textual, TamboUI, Lanterna, or intentional divergence",
    )
    return failures
end

function audit(;
    policy_path::AbstractString=POLICY,
    evidence_dir::AbstractString=EVIDENCE_DIR,
    require_complete::Bool=false,
)
    failures = String[]
    contract_failures, contract = policy_contract_failures(policy_path)
    append!(failures, contract_failures)
    append!(failures, closeout_requirements_schema_failures())
    contract === nothing && return failures
    family_scopes = contract.families
    required_fields = contract.required_fields
    required_sections = contract.required_sections
    command_entrypoints = contract.command_entrypoints
    artifact_url_schemes = contract.artifact_url_schemes
    manual_artifact_hints = contract.manual_artifact_hints
    families = Set(keys(family_scopes))
    expected = Set(EXPECTED_FAMILIES)
    for family in sort!(collect(setdiff(expected, families)))
        push!(failures, "parity policy missing expected family: $family")
    end
    for family in sort!(collect(setdiff(families, expected)))
        push!(failures, "parity policy contains unknown family: $family")
    end
    append!(failures, survey_policy_mapping_failures(family_scopes))

    observed = valid_record_counts(contract; evidence_dir=evidence_dir, failures=failures)
    append!(
        failures,
        closeout_requirements_json_failures(
            render_closeout_requirements_json(
                closeout_requirement_records(; policy_path=policy_path, evidence_dir=evidence_dir),
            ),
        ),
    )

    if require_complete
        minimum = contract.minimum_final_records_per_family
        required_families = Set(release_blocking_policy_families())
        for family in sort!(collect(required_families))
            count = get(observed, family, 0)
            count >= minimum && continue
            push!(failures, "missing final parity evidence record for family: $family ($count/$minimum)")
        end
    end
    return failures
end

function valid_record_counts(contract; evidence_dir::AbstractString=EVIDENCE_DIR, failures::Vector{String}=String[])
    observed = Dict{String,Int}()
    identities = Dict{Tuple{String,String,String},String}()
    for path in evidence_files(evidence_dir)
        record_failures = validate_record(
            path,
            contract.families,
            contract.required_fields,
            contract.required_sections,
            contract.command_entrypoints,
            contract.artifact_url_schemes,
            contract.manual_artifact_hints,
        )
        append!(failures, record_failures)
        fields = identity_fields(read(path, String))
        family = get(fields, "Family", "")
        environment = get(fields, "Terminal or browser environment", "")
        candidate = get(fields, "Release-candidate commit", "")
        identity = (family, environment, lowercase(candidate))
        if !isempty(family) && !isempty(environment) && !isempty(candidate)
            previous = get(identities, identity, nothing)
            if previous === nothing
                identities[identity] = relpath(path, ROOT)
            else
                push!(
                    failures,
                    "$(relpath(path, ROOT)) duplicates parity evidence identity already recorded by $previous",
                )
            end
        end
        if isempty(record_failures)
            !isempty(family) && (observed[family] = get(observed, family, 0) + 1)
        end
    end
    return observed
end

function render_closeout_requirements_tsv(records; header::Bool=true)
    lines = String[]
    header && push!(lines, "family\tsurvey_family\tparity_status\tfollow_up\trequired\tobserved\tmissing\tstatus\tscope\tscaffold_command")
    for record in records
        push!(
            lines,
            join((record.family, record.survey_family, record.parity_status, record.follow_up, record.required, record.observed, record.missing, record.status, record.scope, record.scaffold_command), '\t'),
        )
    end
    return join(lines, "\n")
end

function markdown_escape(value)
    return replace(String(value), "|" => "\\|", "\n" => " ")
end

function render_closeout_requirements_markdown(records)
    lines = String[
        "| Family | Survey family | Parity status | Follow-up | Required | Observed | Missing | Status | Scope | Scaffold command |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for record in records
        push!(
            lines,
            "| $(markdown_escape(record.family)) | $(markdown_escape(record.survey_family)) | $(markdown_escape(record.parity_status)) | $(markdown_escape(record.follow_up)) | $(record.required) | $(record.observed) | $(record.missing) | $(record.status) | $(markdown_escape(record.scope)) | `$(markdown_escape(record.scaffold_command))` |",
        )
    end
    return join(lines, "\n")
end

function json_escape(value)
    escaped = replace(String(value), "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t")
    return "\"$escaped\""
end

function render_closeout_requirements_json(records)
    total_missing = 0
    for record in records
        total_missing += record.missing
    end
    lines = String[
        "{",
        "  \"schema_version\": 1,",
        "  \"total\": $(length(records)),",
        "  \"missing\": $total_missing,",
        "  \"release_ready\": $(total_missing == 0),",
        "  \"rows\": [",
    ]
    for (index, record) in enumerate(records)
        suffix = index == length(records) ? "" : ","
        push!(lines, "    {")
        push!(lines, "      \"family\": $(json_escape(record.family)),")
        push!(lines, "      \"survey_family\": $(json_escape(record.survey_family)),")
        push!(lines, "      \"parity_status\": $(json_escape(record.parity_status)),")
        push!(lines, "      \"follow_up\": $(json_escape(record.follow_up)),")
        push!(lines, "      \"required\": $(record.required),")
        push!(lines, "      \"observed\": $(record.observed),")
        push!(lines, "      \"missing\": $(record.missing),")
        push!(lines, "      \"status\": $(json_escape(record.status)),")
        push!(lines, "      \"scope\": $(json_escape(record.scope)),")
        push!(lines, "      \"scaffold_command\": $(json_escape(record.scaffold_command))")
        push!(lines, "    }$suffix")
    end
    push!(lines, "  ]")
    push!(lines, "}")
    return join(lines, "\n")
end

function render_closeout_requirements_status(records)
    missing = 0
    for record in records
        missing += record.missing
    end
    missing_families = String[record.family for record in records if record.missing > 0]
    families = isempty(missing_families) ? "none" : join(missing_families, ", ")
    return "parity_closeout_release_ready=$(missing == 0) total=$(length(records)) missing=$missing missing_families=$families"
end

function filter_closeout_requirement_records(records, family::AbstractString)
    needle = lowercase(strip(family))
    isempty(needle) && return records
    alias_map = Dict(lowercase(key) => value for (key, value) in SURVEY_TO_POLICY_FAMILY)
    normalized = get(alias_map, needle, strip(family))
    normalized_needle = lowercase(normalized)
    selected = [
        record for record in records
        if lowercase(record.family) == needle || lowercase(record.family) == normalized_needle
    ]
    isempty(selected) && error("unknown parity closeout family filter: $family")
    return selected
end

function render_closeout_requirements(records; format::AbstractString="markdown")
    format == "markdown" && return render_closeout_requirements_markdown(records)
    format == "tsv" && return render_closeout_requirements_tsv(records)
    format == "json" && return render_closeout_requirements_json(records)
    error("--report must be markdown, tsv, or json")
end

function write_output(output::AbstractString, content::AbstractString)
    if isempty(output)
        println(content)
    else
        mkpath(dirname(output))
        write(output, content)
    end
    return nothing
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    require_complete = false
    status = false
    report = ""
    family = ""
    output = ""
    index = 1
    while index <= length(arguments)
        argument = arguments[index]
        if argument == "--require-complete"
            require_complete = true
            index += 1
            continue
        elseif argument == "--status"
            status = true
            index += 1
            continue
        elseif argument == "--report"
            index == length(arguments) && (print_usage(stderr); return 2)
            report = lowercase(strip(arguments[index + 1]))
            index += 2
            continue
        elseif argument == "--family"
            index == length(arguments) && (print_usage(stderr); return 2)
            family = strip(arguments[index + 1])
            index += 2
            continue
        elseif argument == "--output"
            index == length(arguments) && (print_usage(stderr); return 2)
            output = strip(arguments[index + 1])
            index += 2
            continue
        else
            print_usage(stderr)
            return 2
        end
    end
    failures = audit(; require_complete)
    if status || !isempty(report)
        try
            records = filter_closeout_requirement_records(closeout_requirement_records(), family)
            content = status ? render_closeout_requirements_status(records) : render_closeout_requirements(records; format=report)
            write_output(output, content)
        catch error
            push!(failures, sprint(showerror, error))
        end
    end
    if isempty(failures)
        mode = require_complete ? "complete closeout" : "record shape"
        println("parity closeout audit: $mode passed")
        return 0
    end
    foreach(failure -> println(stderr, "parity closeout audit: $failure"), failures)
    return 1
end

end # module ParityCloseoutAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(ParityCloseoutAudit.main())
end
