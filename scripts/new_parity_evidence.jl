#!/usr/bin/env julia

const ROOT = normpath(joinpath(@__DIR__, ".."))

include(joinpath(@__DIR__, "parity_closeout_audit.jl"))

const TEMPLATE = joinpath(ROOT, "docs", "PARITY_EVIDENCE_TEMPLATE.md")
const POLICY = joinpath(ROOT, "docs", "evidence", "parity_policy.json")
const EVIDENCE_DIR = joinpath(ROOT, "docs", "evidence")
const DRAFT_DIR = joinpath(ROOT, "scratch", "parity-evidence")
const VALID_FAMILIES = Set((
    "Layout",
    "Input-event",
    "Stateful-controls",
    "Data-display",
    "Runtime",
    "Developer-experience",
    "Styling-theming",
    "Remote-delivery",
))
const FAMILY_SCOPES = (
    "Layout" => "constraint edge cases, clipping policy, resize continuity, and narrow-terminal behavior",
    "Input-event" => "routed events, async delivery, cancellation behavior, focus restoration, and terminal lifecycle recovery",
    "Stateful-controls" => "widget contract tests, state-transition tests, semantic snapshots, and stable widget candidate evidence",
    "Data-display" => "virtual list/table/tree stress cases, stale data, loading/error slots, and screen-reader semantic state",
    "Runtime" => "queue replacement, task cancellation races, redraw determinism, resource cleanup, and subscription shutdown",
    "Developer-experience" => "API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output",
    "Styling-theming" => "selector specificity, cascade order, role downgrade behavior, diagnostics, and monochrome fallback",
    "Remote-delivery" => "browser deployment, WebSocket hardening, protocol versioning, security policy, and real-client compatibility",
)
const FAMILY_SCOPE_MAP = Dict(FAMILY_SCOPES)
const GENERIC_PLACEHOLDER_PATTERN = r"(?i)\b(todo|placeholder|dummy)\b"
const ARTIFACT_PLACEHOLDER_PATTERN = r"(?i)\b(example\.invalid|example\.com|placeholder|dummy)\b|/OWNER/|/REPO/|/RUN_ID"
const ENVIRONMENT_PLACEHOLDER_PATTERN = r"(?i)\b(todo|placeholder|dummy|unknown|tbd)\b"
const TEXT_PLACEHOLDER_PATTERN = r"(?i)\b(todo|placeholder|dummy|tbd)\b"

function usage()
    println("""
    usage: julia --project=. scripts/new_parity_evidence.jl \\
      --family <family> --environment <environment> --candidate <candidate> [--final true] \\
      [--date <utc-time> --julia-version <version> --kernel <kernel>] \\
      [--capability <width-policy-and-color> --command <command>] \\
      [--exit-status <status> --artifact <path-or-url>] [--behavior <text> --summary <text>] \\
      [--parity-notes <text> --risks <text>]

    usage: julia --project=. scripts/new_parity_evidence.jl --list-blocking

    families:
      Layout            $(FAMILY_SCOPE_MAP["Layout"])
      Input-event       $(FAMILY_SCOPE_MAP["Input-event"])
      Stateful-controls $(FAMILY_SCOPE_MAP["Stateful-controls"])
      Data-display      $(FAMILY_SCOPE_MAP["Data-display"])
      Runtime           $(FAMILY_SCOPE_MAP["Runtime"])
      Developer-experience $(FAMILY_SCOPE_MAP["Developer-experience"])
      Styling-theming   $(FAMILY_SCOPE_MAP["Styling-theming"])
      Remote-delivery   $(FAMILY_SCOPE_MAP["Remote-delivery"])

    By default this creates a draft Markdown record under scratch/parity-evidence/.
    Use --final true only when creating a completed, quality-gated record under
    docs/evidence/. Final records require every identity field plus --behavior,
    --summary, --parity-notes, and --risks. Final --behavior text must include
    the family closeout scope printed above. Final --artifact must be an HTTP(S)
    URL or an existing artifact path. This script validates record shape but
    does not make the record release evidence.
    Use --list-blocking to print only the current non-matched reference-survey
    families that require final parity closeout records before release.
    """)
end

function parse_args(args)
    parsed = Dict{String,String}()
    index = 1
    while index <= length(args)
        key = args[index]
        key in ("--help", "-h") && return nothing
        if key == "--list-blocking"
            parsed["list-blocking"] = "true"
            index += 1
            continue
        end
        startswith(key, "--") || error("unexpected argument: $key")
        index == length(args) && error("missing value for $key")
        parsed[key[3:end]] = args[index + 1]
        index += 2
    end
    return parsed
end

function blocking_family_lines()
    families = ParityCloseoutAudit.release_blocking_policy_families()
    return String["$family\t$(FAMILY_SCOPE_MAP[family])" for family in families]
end

function required(parsed, key)
    value = get(parsed, key, "")
    isempty(strip(value)) && error("missing required --$key")
    return strip(value)
end

function slug(value)
    lowered = lowercase(strip(value))
    replaced = replace(lowered, r"[^a-z0-9]+" => "-")
    return replace(replaced, r"^-+|-+$" => "")
end

function validate_candidate(value)
    occursin(r"^[0-9a-fA-F]{7,40}$", value) ||
        error("--candidate must be a short or full git commit SHA")
    return value
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
    value === nothing && error("parity evidence policy missing $key integer")
    value > 0 || error("parity evidence policy $key must be positive")
    return value
end

function policy_command_entrypoints(policy::AbstractString=POLICY)
    return policy_contract(policy).command_entrypoints
end

function policy_artifact_url_schemes(policy::AbstractString=POLICY)
    return policy_contract(policy).artifact_url_schemes
end

function policy_manual_artifact_hints(policy::AbstractString=POLICY)
    return policy_contract(policy).manual_artifact_hints
end

function policy_required_identity_fields(policy::AbstractString=POLICY)
    return policy_contract(policy).required_identity_fields
end

function policy_required_sections(policy::AbstractString=POLICY)
    return policy_contract(policy).required_sections
end

function policy_minimum_final_records_per_family(policy::AbstractString=POLICY)
    return policy_contract(policy).minimum_final_records_per_family
end

function policy_contract(policy::AbstractString=POLICY)
    isfile(policy) || error("missing parity evidence policy: docs/evidence/parity_policy.json")
    source = read(policy, String)
    command_entrypoints = array_values(source, "required_command_entrypoints")
    command_entrypoints === nothing && error("parity evidence policy missing required_command_entrypoints array")
    artifact_url_schemes = array_values(source, "allowed_artifact_url_schemes")
    artifact_url_schemes === nothing && error("parity evidence policy missing allowed_artifact_url_schemes array")
    manual_artifact_hints = array_values(source, "manual_artifact_hints")
    manual_artifact_hints === nothing && error("parity evidence policy missing manual_artifact_hints array")
    fields = array_values(source, "required_identity_fields")
    fields === nothing && error("parity evidence policy missing required_identity_fields array")
    sections = array_values(source, "required_sections")
    sections === nothing && error("parity evidence policy missing required_sections array")
    minimum_final_records_per_family = positive_integer_value(source, "minimum_final_records_per_family")
    return (
        command_entrypoints=command_entrypoints,
        artifact_url_schemes=artifact_url_schemes,
        manual_artifact_hints=manual_artifact_hints,
        required_identity_fields=fields,
        required_sections=sections,
        minimum_final_records_per_family=minimum_final_records_per_family,
    )
end

function parse_bool(value)
    lowered = lowercase(strip(value))
    lowered in ("true", "yes", "1") && return true
    lowered in ("false", "no", "0") && return false
    error("expected boolean value, got: $value")
end

function validate_exit_status(value)
    stripped = strip(value)
    occursin(r"^\d+$", stripped) || error("--exit-status must be a non-negative integer")
    return stripped
end

has_generic_placeholder(value::AbstractString) =
    occursin(GENERIC_PLACEHOLDER_PATTERN, value)

has_artifact_placeholder(value::AbstractString) =
    occursin(ARTIFACT_PLACEHOLDER_PATTERN, value)

has_environment_placeholder(value::AbstractString) =
    occursin(ENVIRONMENT_PLACEHOLDER_PATTERN, value)

function is_url_or_existing_path(value::AbstractString, artifact_url_schemes)
    stripped = strip(value)
    any(scheme -> startswith(stripped, scheme), artifact_url_schemes) && return true
    return ispath(isabspath(stripped) ? stripped : normpath(joinpath(ROOT, stripped)))
end

function validate_artifact(value; artifact_url_schemes=policy_artifact_url_schemes())
    stripped = strip(value)
    has_artifact_placeholder(stripped) &&
        error("--artifact must reference a real artifact or CI URL, not a placeholder")
    is_url_or_existing_path(stripped, artifact_url_schemes) ||
        error("--artifact must be an HTTP(S) URL or an existing artifact path")
    return stripped
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

function validate_manual_artifact(command, artifact, manual_artifact_hints)
    is_manual_command(command) && !artifact_matches_manual_hint(artifact, manual_artifact_hints) &&
        error("--artifact for manual evidence must include a manual artifact hint from policy")
    return artifact
end

function validate_command(value; command_entrypoints=policy_command_entrypoints())
    stripped = strip(value)
    has_generic_placeholder(stripped) &&
        error("--command must be the exact command that produced the evidence")
    command_has_evidence_entrypoint(stripped, command_entrypoints) ||
        error("--command must reference a Wicked validation/evidence entry point or start with manual:")
    return stripped
end

function validate_text_argument(name, value)
    stripped = strip(value)
    isempty(stripped) && error("--$name must not be empty")
    occursin(TEXT_PLACEHOLDER_PATTERN, stripped) &&
        error("--$name must contain concrete evidence text, not a placeholder")
    return stripped
end

function validate_parity_notes(value)
    stripped = validate_text_argument("parity-notes", value)
    occursin(r"(?i)\b(ratatui|textual|tamboui|lanterna|intentional divergence)\b", stripped) ||
        error("--parity-notes must mention Ratatui, Textual, TamboUI, Lanterna, or intentional divergence")
    return stripped
end

function validate_behavior(family, value)
    stripped = validate_text_argument("behavior", value)
    scope = FAMILY_SCOPE_MAP[family]
    occursin(scope, stripped) ||
        error("--behavior must include the closeout scope for $family: $scope")
    return stripped
end

function replace_section_placeholder(source, heading, text)
    pattern = Regex("(?ms)^" * escape_string(heading) * "\\s*\$\\n\\n-\\s*\$", "m")
    replacement = "$heading\n\n- $text"
    return replace(source, pattern => replacement)
end

function validate_environment(value)
    stripped = strip(value)
    has_environment_placeholder(stripped) &&
        error("--environment must identify the terminal, browser, or CI environment")
    return stripped
end

function validate_identity(name, value)
    stripped = strip(value)
    has_environment_placeholder(stripped) &&
        error("--$name must contain concrete release identity metadata, not a placeholder")
    return stripped
end

function validate_utc_timestamp(value)
    stripped = validate_identity("date", value)
    occursin(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC$", stripped) ||
        error("--date must use format YYYY-MM-DD HH:MM:SS UTC")
    return stripped
end

function validate_julia_version(value)
    stripped = validate_identity("julia-version", value)
    occursin(r"^\d+\.\d+(\.\d+)?(-[A-Za-z0-9.+-]+)?$", stripped) ||
        error("--julia-version must use a Julia version such as 1.10.11 or 1.12.6")
    return stripped
end

function validate_kernel(value)
    stripped = validate_identity("kernel", value)
    occursin(r"(?i)\blinux\b", stripped) ||
        error("--kernel must identify a Linux kernel or distribution")
    return stripped
end

function replace_field(source, field, value)
    pattern = Regex("^\\|\\s*" * escape_string(field) * "\\s*\\|\\s*.*?\\s*\\|\$", "m")
    replacement = "| $field | $value |"
    return replace(source, pattern => replacement)
end

function require_template_field(source, field)
    occursin(Regex("^\\|\\s*" * escape_string(field) * "\\s*\\|", "m"), source) ||
        error("template missing required identity field from policy: $field")
end

function require_template_section(source, section)
    occursin(Regex("^##\\s+" * escape_string(section) * "\\s*\$", "m"), source) ||
        error("template missing required section from policy: $section")
end

function optional_or_todo(parsed, key, fallback)
    value = get(parsed, key, "")
    isempty(strip(value)) ? fallback : strip(value)
end

function create_record(parsed; template::AbstractString=TEMPLATE, evidence_dir::AbstractString=EVIDENCE_DIR, draft_dir::AbstractString=DRAFT_DIR)
    family = required(parsed, "family")
    final = haskey(parsed, "final") ? parse_bool(parsed["final"]) : false
    contract = policy_contract()
    environment = final ? validate_environment(required(parsed, "environment")) : required(parsed, "environment")
    candidate = validate_candidate(required(parsed, "candidate"))
    command = final ? validate_command(required(parsed, "command"); command_entrypoints=contract.command_entrypoints) : optional_or_todo(parsed, "command", "TODO: record exact command")
    exit_status = final ? validate_exit_status(required(parsed, "exit-status")) : optional_or_todo(parsed, "exit-status", "TODO: record exit status")
    artifact = final ? validate_artifact(required(parsed, "artifact"); artifact_url_schemes=contract.artifact_url_schemes) : optional_or_todo(parsed, "artifact", "TODO: attach artifact or CI URL")
    final && validate_manual_artifact(command, artifact, contract.manual_artifact_hints)
    date = final ? validate_utc_timestamp(required(parsed, "date")) : ""
    julia_version = final ? validate_julia_version(required(parsed, "julia-version")) : ""
    kernel = final ? validate_kernel(required(parsed, "kernel")) : ""
    capability = final ? validate_identity("capability", required(parsed, "capability")) : ""
    family in VALID_FAMILIES || error("unsupported family: $family")
    behavior = final ? validate_behavior(family, required(parsed, "behavior")) : ""
    summary = final ? validate_text_argument("summary", required(parsed, "summary")) : ""
    parity_notes = final ? validate_parity_notes(required(parsed, "parity-notes")) : ""
    risks = final ? validate_text_argument("risks", required(parsed, "risks")) : ""

    isfile(template) || error("missing template: docs/PARITY_EVIDENCE_TEMPLATE.md")
    output_dir = final ? evidence_dir : draft_dir
    isdir(output_dir) || mkpath(output_dir)

    filename = "$(slug(family))-$(slug(environment))-$(slug(candidate)).md"
    path = joinpath(output_dir, filename)
    isfile(path) && error("refusing to overwrite existing evidence record: $(relpath(path, ROOT))")

    source = read(template, String)
    for field in contract.required_identity_fields
        require_template_field(source, field)
    end
    for section in contract.required_sections
        require_template_section(source, section)
    end
    source = replace_field(source, "Family", family)
    source = replace_field(source, "Release-candidate commit", candidate)
    source = replace_field(source, "Date and UTC time", date)
    source = replace_field(source, "Julia version", julia_version)
    source = replace_field(source, "Kernel and distribution", kernel)
    source = replace_field(source, "Terminal or browser environment", environment)
    source = replace_field(source, "Width policy and color capability", capability)
    source = replace_field(source, "Command", command)
    source = replace_field(source, "Exit status", exit_status)
    source = replace_field(source, "Artifact path or CI URL", artifact)
    if final
        source = replace_section_placeholder(source, "## Behaviors checked", behavior)
        source = replace_section_placeholder(source, "## Reference-library parity notes", parity_notes)
        source = replace_section_placeholder(source, "## Evidence summary", summary)
        source = replace_section_placeholder(source, "## Risks and follow-up", risks)
    end

    write(path, source)
    return path, final
end

function main(args=ARGS)
    parsed = parse_args(args)
    if parsed === nothing
        usage()
        return 0
    end
    if get(parsed, "list-blocking", "false") == "true"
        println(join(blocking_family_lines(), "\n"))
        return 0
    end

    path, final = create_record(parsed)
    if final
        println("created final parity evidence record scaffold: ", relpath(path, ROOT))
        println("complete every TODO before running the quality gate")
    else
        println("created draft parity evidence record: ", relpath(path, ROOT))
        println("drafts are ignored; move a completed record to docs/evidence/ or rerun with --final true")
    end
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
