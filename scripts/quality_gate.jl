#!/usr/bin/env julia

using Wicked
using Test

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SOURCE_DIRECTORIES = ("src", "ext", "test", "examples", "benchmark", "scripts")
const EXPERIMENTAL_IMPORT_POLICY_DIRECTORIES = ("src", "ext", "examples", "benchmark")
const REQUIRED_POLICY_FILES = (
    "CHANGELOG.md",
    "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md",
    "LICENSE.md",
    "SECURITY.md",
    "SUPPORT.md",
    "THIRD_PARTY_NOTICES.md",
    "VERSIONING.md",
)
const VERSIONED_MANIFESTS = (
    "Manifest-v1.10.toml" => "1.10.",
    "Manifest-v1.12.toml" => "1.12.",
)
const API_BASELINE = joinpath(ROOT, "api", "public_api.tsv")
const STABLE_API_BASELINE = joinpath(ROOT, "api", "stable_api.tsv")
const EXPERIMENTAL_API_BASELINE = joinpath(ROOT, "api", "experimental_api.tsv")
const WIDGET_COVERAGE_LEDGER = joinpath(ROOT, "api", "widget_coverage.tsv")
const EXPERIMENTAL_PROMOTION_LEDGER = joinpath(ROOT, "api", "experimental_promotions.tsv")
const EXPERIMENTAL_PROMOTION_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "experimental_promotion_audit.jl")
const WIDGET_PROMOTION_REQUIREMENTS_LEDGER = joinpath(ROOT, "api", "widget_promotion_requirements.tsv")
const WIDGET_PROMOTION_REQUIREMENTS_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "widget_promotion_requirements_audit.jl")
const WIDGET_PROMOTION_REQUIREMENTS_RENDER_SCRIPT = joinpath(ROOT, "scripts", "render_widget_promotion_requirements.jl")
const WIDGET_PROMOTION_REQUIREMENTS_SCHEMA = joinpath(ROOT, "docs", "evidence", "widget_promotion_requirements.schema.json")
const WIDGET_PROMOTION_REQUIREMENTS_SCHEMA_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "widget_promotion_requirements_schema_audit.jl")
const COMPONENT_CATALOG_PUBLIC_MAP_HELPER = joinpath(ROOT, "scripts", "component_catalog_public_map.jl")
const COMPATIBILITY_WIDGET_ALIAS_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "compatibility_widget_alias_audit.jl")
const CI_WORKFLOW = joinpath(ROOT, ".github", "workflows", "ci.yml")
const CONTINUOUS_INTEGRATION_DOC = joinpath(ROOT, "docs", "CONTINUOUS_INTEGRATION.md")
const RELEASE_CHECKLIST = joinpath(ROOT, "docs", "RELEASE_CHECKLIST.md")
const RELEASE_EVIDENCE = joinpath(ROOT, "docs", "RELEASE_EVIDENCE.md")
const COMPONENT_CATALOG = joinpath(ROOT, "docs", "COMPONENT_CATALOG.md")
const TEST_RUNNER = joinpath(ROOT, "test", "runtests.jl")
const COMPONENT_CATALOG_PUBLIC_MAP_TEST = joinpath(ROOT, "test", "component_catalog_public_map.jl")
const COMPATIBILITY_WIDGET_ALIAS_AUDIT_TEST = joinpath(ROOT, "test", "compatibility_widget_alias_audit.jl")
const EXPERIMENTAL_PROMOTION_AUDIT_TEST = joinpath(ROOT, "test", "experimental_promotion_audit.jl")
const WIDGET_PROMOTION_REQUIREMENTS_AUDIT_TEST = joinpath(ROOT, "test", "widget_promotion_requirements_audit.jl")
const WIDGET_PROMOTION_REQUIREMENTS_RENDER_TEST = joinpath(ROOT, "test", "widget_promotion_requirements_render.jl")
const WIDGET_PROMOTION_REQUIREMENTS_SCHEMA_AUDIT_TEST = joinpath(ROOT, "test", "widget_promotion_requirements_schema_audit.jl")
const STABLE_WIDGET_CANDIDATES_TEST = joinpath(ROOT, "test", "stable_widget_candidates.jl")
const PUBLIC_WIDGET_CANDIDATE_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "public_widget_candidate_audit.jl")
const PUBLIC_WIDGET_CANDIDATE_AUDIT_TEST = joinpath(ROOT, "test", "public_widget_candidate_audit.jl")
const WIDGET_CATALOG_TEST = joinpath(ROOT, "test", "widget_catalog.jl")
const WIDGET_CATALOG_RENDER_TEST = joinpath(ROOT, "test", "widget_catalog_render.jl")
const WIDGET_STABILIZATION_GATE_TEST = joinpath(ROOT, "test", "widget_stabilization_gate.jl")
const PARITY_EVIDENCE_SCAFFOLD_TEST = joinpath(ROOT, "test", "new_parity_evidence.jl")
const PARITY_POLICY_AUDIT_TEST = joinpath(ROOT, "test", "parity_policy_audit.jl")
const PARITY_CLOSEOUT_AUDIT_TEST = joinpath(ROOT, "test", "parity_closeout_audit.jl")
const REFERENCE_PARITY_MATRIX_RENDER_TEST = joinpath(ROOT, "test", "reference_parity_matrix_render.jl")
const REFERENCE_PARITY_MATRIX_SCHEMA_AUDIT_TEST = joinpath(ROOT, "test", "reference_parity_matrix_schema_audit.jl")
const STABLE_PROMOTION_PACKET_TEST = joinpath(ROOT, "test", "new_stable_promotion_packet.jl")
const STABLE_PROMOTION_PACKET_AUDIT_TEST = joinpath(ROOT, "test", "stable_promotion_packet_audit.jl")
const EXAMPLES_README_POLICY_TEST = joinpath(ROOT, "test", "examples_readme_policy.jl")
const PUBLIC_EXAMPLES_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "public_examples_audit.jl")
const PUBLIC_EXAMPLES_AUDIT_TEST = joinpath(ROOT, "test", "public_examples_audit.jl")
const EXAMPLE_FAMILY_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "example_family_audit.jl")
const EXAMPLE_FAMILY_AUDIT_TEST = joinpath(ROOT, "test", "example_family_audit.jl")
const UNICODE_WIDTH_CORPUS_AUDIT_TEST = joinpath(ROOT, "test", "unicode_width_corpus_audit.jl")
const PARITY_POLICY_JSON = joinpath(ROOT, "docs", "evidence", "parity_policy.json")
const PARITY_CLOSEOUT_REQUIREMENTS_SCHEMA = joinpath(ROOT, "docs", "evidence", "parity_closeout_requirements.schema.json")
const WIDGET_FAMILY_CLOSEOUT_SCHEMA = joinpath(ROOT, "docs", "evidence", "widget_family_closeout.schema.json")
const WIDGET_FAMILY_CLOSEOUT_SCHEMA_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "widget_family_closeout_schema_audit.jl")
const WIDGET_FAMILY_CLOSEOUT_SCHEMA_AUDIT_TEST = joinpath(ROOT, "test", "widget_family_closeout_schema_audit.jl")
const STABLE_WIDGET_COVERAGE_SCHEMA = joinpath(ROOT, "docs", "evidence", "stable_widget_coverage.schema.json")
const STABLE_WIDGET_STABILITY_SCHEMA = joinpath(ROOT, "docs", "evidence", "stable_widget_stability.schema.json")
const STABLE_WIDGET_STABILIZATION_SCHEMA = joinpath(ROOT, "docs", "evidence", "stable_widget_stabilization.schema.json")
const STABLE_WIDGET_SURFACE_RELEASE_SCHEMA = joinpath(ROOT, "docs", "evidence", "stable_widget_surface_release.schema.json")
const STABLE_WIDGET_COVERAGE_SCHEMA_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "stable_widget_coverage_schema_audit.jl")
const STABLE_WIDGET_COVERAGE_SCHEMA_AUDIT_TEST = joinpath(ROOT, "test", "stable_widget_coverage_schema_audit.jl")
const STABLE_WIDGET_STABILITY_SCHEMA_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "stable_widget_stability_schema_audit.jl")
const STABLE_WIDGET_STABILITY_SCHEMA_AUDIT_TEST = joinpath(ROOT, "test", "stable_widget_stability_schema_audit.jl")
const STABLE_WIDGET_STABILIZATION_SCHEMA_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "stable_widget_stabilization_schema_audit.jl")
const STABLE_WIDGET_STABILIZATION_SCHEMA_AUDIT_TEST = joinpath(ROOT, "test", "stable_widget_stabilization_schema_audit.jl")
const STABLE_WIDGET_SURFACE_RELEASE_SCHEMA_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "stable_widget_surface_release_schema_audit.jl")
const STABLE_WIDGET_SURFACE_RELEASE_SCHEMA_AUDIT_TEST = joinpath(ROOT, "test", "stable_widget_surface_release_schema_audit.jl")
const PARITY_POLICY_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "parity_policy_audit.jl")
const PARITY_CLOSEOUT_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "parity_closeout_audit.jl")
const REFERENCE_PARITY_MATRIX_RENDER_SCRIPT = joinpath(ROOT, "scripts", "render_reference_parity_matrix.jl")
const REFERENCE_PARITY_MATRIX_SCHEMA = joinpath(ROOT, "docs", "evidence", "reference_parity_matrix.schema.json")
const REFERENCE_PARITY_SUMMARY_SCHEMA = joinpath(ROOT, "docs", "evidence", "reference_parity_summary.schema.json")
const REFERENCE_PARITY_MATRIX_STATUS_SCHEMA = joinpath(ROOT, "docs", "evidence", "reference_parity_matrix_status.schema.json")
const REFERENCE_PARITY_MATRIX_SCHEMA_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "reference_parity_matrix_schema_audit.jl")
const PARITY_EVIDENCE_SCAFFOLD = joinpath(ROOT, "scripts", "new_parity_evidence.jl")
const STABLE_PROMOTION_PACKET_SCRIPT = joinpath(ROOT, "scripts", "new_stable_promotion_packet.jl")
const STABLE_PROMOTION_PACKET_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "stable_promotion_packet_audit.jl")
const UNICODE_WIDTH_CORPUS = joinpath(ROOT, "api", "unicode_width_corpus.tsv")
const UNICODE_WIDTH_CORPUS_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "unicode_width_corpus_audit.jl")
const UNICODE_WIDTH_CORPUS_DOC = joinpath(ROOT, "docs", "UNICODE_WIDTH_CORPUS.md")
const REMOTE_PROTOCOL_FIXTURES = joinpath(ROOT, "api", "remote_protocol_fixtures.tsv")
const REMOTE_PROTOCOL_FIXTURE_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "remote_protocol_fixture_audit.jl")
const REMOTE_PROTOCOL_FIXTURE_AUDIT_TEST = joinpath(ROOT, "test", "remote_protocol_fixture_audit.jl")
const REMOTE_TRANSPORT_DOC = joinpath(ROOT, "docs", "REMOTE_TRANSPORT.md")
const REAL_TERMINAL_MATRIX = joinpath(ROOT, "docs", "REAL_TERMINAL_MATRIX.md")
const TERMINAL_COMPATIBILITY_DOC = joinpath(ROOT, "docs", "TERMINAL_COMPATIBILITY.md")
const TERMINAL_EVIDENCE_TEMPLATE = joinpath(ROOT, "docs", "TERMINAL_EVIDENCE_TEMPLATE.md")
const TERMINAL_EVIDENCE_DIR = joinpath(ROOT, "docs", "terminal-evidence")
const TERMINAL_EVIDENCE_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "terminal_evidence_audit.jl")
const TERMINAL_EVIDENCE_AUDIT_TEST = joinpath(ROOT, "test", "terminal_evidence_audit.jl")
const APPLICATION_EVIDENCE_TEMPLATE = joinpath(ROOT, "docs", "REAL_APPLICATION_EVIDENCE_TEMPLATE.md")
const APPLICATION_EVIDENCE_DIR = joinpath(ROOT, "docs", "application-evidence")
const APPLICATION_EVIDENCE_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "application_evidence_audit.jl")
const APPLICATION_EVIDENCE_AUDIT_TEST = joinpath(ROOT, "test", "application_evidence_audit.jl")
const BENCHMARK_EVIDENCE_TEMPLATE = joinpath(ROOT, "docs", "BENCHMARK_EVIDENCE_TEMPLATE.md")
const BENCHMARK_EVIDENCE_DIR = joinpath(ROOT, "docs", "benchmark-evidence")
const BENCHMARK_EVIDENCE_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "benchmark_evidence_audit.jl")
const BENCHMARK_EVIDENCE_AUDIT_TEST = joinpath(ROOT, "test", "benchmark_evidence_audit.jl")
const LOADING_EVIDENCE_TEMPLATE = joinpath(ROOT, "docs", "PACKAGE_LOADING_EVIDENCE_TEMPLATE.md")
const LOADING_EVIDENCE_DIR = joinpath(ROOT, "docs", "loading-evidence")
const LOADING_EVIDENCE_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "loading_evidence_audit.jl")
const LOADING_EVIDENCE_AUDIT_TEST = joinpath(ROOT, "test", "loading_evidence_audit.jl")
const DOCUMENTATION_EVIDENCE_TEMPLATE = joinpath(ROOT, "docs", "DOCUMENTATION_EVIDENCE_TEMPLATE.md")
const DOCUMENTATION_EVIDENCE_DIR = joinpath(ROOT, "docs", "documentation-evidence")
const DOCUMENTATION_EVIDENCE_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "documentation_evidence_audit.jl")
const DOCUMENTATION_EVIDENCE_AUDIT_TEST = joinpath(ROOT, "test", "documentation_evidence_audit.jl")
const SEMANTIC_EVIDENCE_TEMPLATE = joinpath(ROOT, "docs", "SEMANTIC_ACCESSIBILITY_EVIDENCE_TEMPLATE.md")
const SEMANTIC_EVIDENCE_DIR = joinpath(ROOT, "docs", "semantic-evidence")
const SEMANTIC_EVIDENCE_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "semantic_accessibility_evidence_audit.jl")
const SEMANTIC_EVIDENCE_AUDIT_TEST = joinpath(ROOT, "test", "semantic_accessibility_evidence_audit.jl")
const PILOT_EVIDENCE_PACKAGE_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "pilot_evidence_package_audit.jl")
const PILOT_EVIDENCE_PACKAGE_AUDIT_TEST = joinpath(ROOT, "test", "pilot_evidence_package_audit.jl")
const REAL_TERMINAL_MATRIX_AUDIT_SCRIPT = joinpath(ROOT, "scripts", "real_terminal_matrix_audit.jl")
const REAL_TERMINAL_MATRIX_AUDIT_TEST = joinpath(ROOT, "test", "real_terminal_matrix_audit.jl")
const README = joinpath(ROOT, "README.md")
const EXAMPLES_README = joinpath(ROOT, "examples", "README.md")
const EXAMPLE_FAMILIES_DOC = joinpath(ROOT, "docs", "EXAMPLE_FAMILIES.md")
const GITIGNORE = joinpath(ROOT, ".gitignore")
const FOCUSED_API_WIDGET_DOCS = (
    joinpath(ROOT, "docs", "API_WIDGETS.md"),
    joinpath(ROOT, "docs", "API_CONTROLS.md"),
    joinpath(ROOT, "docs", "API_NAVIGATION.md"),
    joinpath(ROOT, "docs", "UTILITY_WIDGETS.md"),
)
const PARITY_EVIDENCE_FAMILIES = (
    "Layout",
    "Input-event",
    "Stateful-controls",
    "Data-display",
    "Runtime",
    "Developer-experience",
    "Styling-theming",
    "Remote-delivery",
)
const PARITY_EVIDENCE_SCOPE_PHRASES = (
    "constraint edge cases, clipping policy, resize continuity, narrow-terminal behavior",
    "routed events, async delivery, cancellation behavior, focus restoration, terminal lifecycle recovery",
    "widget contract tests, state-transition tests, semantic snapshots, and stable widget candidate evidence",
    "virtual list/table/tree stress cases, stale data, loading/error slots, and screen-reader semantic state",
    "queue replacement, task cancellation races, redraw determinism, resource cleanup, subscription shutdown",
    "API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output",
    "selector specificity, cascade order, role downgrade behavior, diagnostics, monochrome fallback",
    "browser deployment, WebSocket hardening, protocol versioning, security policy, real-client compatibility",
)
const PARITY_CLOSEOUT_ITEMS = (
    "Layout parity closeout evidence covers constraint edge cases, clipping policy, resize continuity, and narrow-terminal behavior.",
    "Input/event parity closeout evidence covers routed events, async delivery, cancellation behavior, focus restoration, and terminal lifecycle recovery.",
    "Stateful-controls parity closeout evidence covers widget contract tests, state-transition tests, semantic snapshots, and stable widget candidate evidence.",
    "Data-display parity closeout evidence covers virtual list/table/tree stress cases, stale data, loading/error slots, and screen-reader semantic state.",
    "Runtime parity closeout evidence covers queue replacement, task cancellation races, redraw determinism, resource cleanup, and subscription shutdown.",
    "Developer-experience parity closeout evidence covers API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output.",
    "Styling/theming parity closeout evidence covers selector specificity, cascade order, role downgrade behavior, diagnostics, and monochrome fallback.",
    "Remote-delivery parity closeout evidence covers browser deployment, WebSocket hardening, protocol versioning, security policy, and real-client compatibility.",
    "`scripts/remote_protocol_fixture_audit.jl` passes against `api/remote_protocol_fixtures.tsv`.",
)
const REQUIRED_PARITY_CHECKLIST_ITEMS = (
    "Layout parity evidence covers constraint edge cases, clipping policy, resize continuity, and narrow-terminal behavior.",
    "Input/event parity evidence covers routed events, async delivery, cancellation behavior, focus restoration, and terminal lifecycle recovery.",
    "Stateful-controls parity evidence covers widget contract tests, state-transition tests, semantic snapshots, and stable widget candidate evidence.",
    "Data-display parity evidence covers virtual list/table/tree stress cases, stale data, loading/error slots, and screen-reader semantic state.",
    "Runtime parity evidence covers queue replacement, task cancellation races, redraw determinism, resource cleanup, and subscription shutdown.",
    "Developer-experience parity evidence covers API contract tests, Pilot/semantic query evidence, migration notes, examples, and documentation build output.",
    "Styling/theming parity evidence covers selector specificity, cascade order, role downgrade behavior, diagnostics, and monochrome fallback.",
    "Remote-delivery parity evidence covers browser deployment, WebSocket hardening, protocol versioning, security policy, and real-client compatibility.",
)
const PARITY_REFERENCE_LABELS = (
    "Ratatui",
    "Textual",
    "TamboUI",
    "Lanterna",
    "intentional divergence",
)

function files_with_extension(directories, extension)
    files = String[]
    for relative in directories
        directory = joinpath(ROOT, relative)
        isdir(directory) || continue
        for (path, subdirectories, names) in walkdir(directory)
            filter!(name -> name != ".git", subdirectories)
            for name in names
                endswith(name, extension) && push!(files, joinpath(path, name))
            end
        end
    end
    return sort!(files)
end

function check_julia_syntax!()
    failures = String[]
    for path in files_with_extension(SOURCE_DIRECTORIES, ".jl")
        source = read(path, String)
        try
            Meta.parseall(source; filename=relpath(path, ROOT))
        catch error
            push!(failures, "$(relpath(path, ROOT)): $(sprint(showerror, error))")
        end
    end
    return failures
end

function public_binding_kind(value)
    value isa Module && return "module"
    value isa Function && return "function"
    value isa DataType && return "datatype"
    value isa UnionAll && return "unionall"
    return "value"
end

function check_public_exports!()
    failures = String[]
    for name in names(Wicked; all=false, imported=false)
        isdefined(Wicked, name) || push!(failures, "Wicked exports undefined binding: $name")
    end
    return failures
end

function check_method_ambiguities!()
    return String[
        "ambiguous public/internal dispatch: $(sprint(show, ambiguity))"
        for ambiguity in Test.detect_ambiguities(Wicked; recursive=true)
    ]
end

function check_optional_loading!()
    Base.get_extension(Wicked, :WickedHTTPWebSocketsExt) === nothing ||
        return ["HTTP extension loaded without HTTP being requested"]
    return String[]
end

function check_public_api_baseline!()
    failures = String[]
    for (label, target, path) in (
        ("root", Wicked, API_BASELINE),
        ("stable", Wicked.API, STABLE_API_BASELINE),
        ("experimental", Wicked.Experimental, EXPERIMENTAL_API_BASELINE),
    )
        if !isfile(path)
            push!(failures, "missing reviewed $label API baseline: $(relpath(path, ROOT))")
            continue
        end
        expected = String[
            line for line in readlines(path)
            if !isempty(strip(line)) && !startswith(strip(line), '#')
        ]
        exported = sort!(collect(Base.names(target; all=false, imported=false)); by=string)
        current = ["$(name)\t$(public_binding_kind(getfield(target, name)))" for name in exported]
        current == expected && continue
        append!(failures, ("unreviewed $label API addition or kind change: $entry" for entry in sort!(collect(setdiff(Set(current), Set(expected))))))
        append!(failures, ("unreviewed $label API removal or kind change: $entry" for entry in sort!(collect(setdiff(Set(expected), Set(current))))))
    end
    return failures
end

function check_facade_overlap!()
    stable = Set(Base.names(Wicked.API; all=false, imported=false))
    compatibility = Set(Base.names(Wicked.Experimental; all=false, imported=false))
    return String[
        "facade export is both stable and compatibility-only: $name"
        for name in sort!(collect(intersect(stable, compatibility)); by=string)
    ]
end

function check_experimental_import_policy!()
    failures = String[]
    import_pattern = r"\b(using|import)\s+(?:Wicked\.|\.+)?Experimental\b"
    qualified_pattern = r"\bWicked\.Experimental\b"
    for path in files_with_extension(EXPERIMENTAL_IMPORT_POLICY_DIRECTORIES, ".jl")
        relative = relpath(path, ROOT)
        relative == joinpath("src", "ExperimentalAPI.jl") && continue
        for (index, line) in enumerate(eachsplit(read(path, String), '\n'))
            stripped = strip(line)
            startswith(stripped, "#") && continue
            occursin(import_pattern, line) || occursin(qualified_pattern, line) || continue
            push!(failures, "$relative:$index references Wicked.Experimental; use Wicked.API or an internal module instead")
        end
    end
    return failures
end

function check_experimental_promotion_ledger!()
    failures = String[]
    isfile(EXPERIMENTAL_PROMOTION_AUDIT_SCRIPT) || push!(failures, "missing experimental promotion audit: scripts/experimental_promotion_audit.jl")
    isfile(EXPERIMENTAL_PROMOTION_AUDIT_TEST) || push!(failures, "missing experimental promotion audit tests: test/experimental_promotion_audit.jl")
    isfile(WIDGET_PROMOTION_REQUIREMENTS_LEDGER) || push!(failures, "missing widget promotion requirements ledger: api/widget_promotion_requirements.tsv")
    isfile(WIDGET_PROMOTION_REQUIREMENTS_AUDIT_SCRIPT) || push!(failures, "missing widget promotion requirements audit: scripts/widget_promotion_requirements_audit.jl")
    isfile(WIDGET_PROMOTION_REQUIREMENTS_AUDIT_TEST) || push!(failures, "missing widget promotion requirements audit tests: test/widget_promotion_requirements_audit.jl")
    isfile(WIDGET_PROMOTION_REQUIREMENTS_RENDER_SCRIPT) || push!(failures, "missing widget promotion requirements renderer: scripts/render_widget_promotion_requirements.jl")
    isfile(WIDGET_PROMOTION_REQUIREMENTS_RENDER_TEST) || push!(failures, "missing widget promotion requirements renderer tests: test/widget_promotion_requirements_render.jl")
    isfile(WIDGET_PROMOTION_REQUIREMENTS_SCHEMA) || push!(failures, "missing widget promotion requirements JSON schema: docs/evidence/widget_promotion_requirements.schema.json")
    isfile(WIDGET_PROMOTION_REQUIREMENTS_SCHEMA_AUDIT_SCRIPT) || push!(failures, "missing widget promotion requirements schema audit: scripts/widget_promotion_requirements_schema_audit.jl")
    isfile(WIDGET_PROMOTION_REQUIREMENTS_SCHEMA_AUDIT_TEST) || push!(failures, "missing widget promotion requirements schema audit tests: test/widget_promotion_requirements_schema_audit.jl")
    isfile(PILOT_EVIDENCE_PACKAGE_AUDIT_SCRIPT) || push!(failures, "missing pilot evidence package audit: scripts/pilot_evidence_package_audit.jl")
    isfile(PILOT_EVIDENCE_PACKAGE_AUDIT_TEST) || push!(failures, "missing pilot evidence package audit tests: test/pilot_evidence_package_audit.jl")
    if isfile(WIDGET_PROMOTION_REQUIREMENTS_RENDER_SCRIPT)
        source = read(WIDGET_PROMOTION_REQUIREMENTS_RENDER_SCRIPT, String)
        occursin("render_json", source) &&
            occursin("\"summary\"", source) &&
            occursin("\"by_area\"", source) &&
            occursin("\"by_release_required\"", source) ||
            push!(failures, "widget promotion requirements renderer must emit JSON summary counts by area and release-required status")
    end
    if isfile(WIDGET_PROMOTION_REQUIREMENTS_SCHEMA)
        source = read(WIDGET_PROMOTION_REQUIREMENTS_SCHEMA, String)
        occursin("\"summary\"", source) &&
            occursin("\"total\"", source) &&
            occursin("\"by_area\"", source) &&
            occursin("\"by_release_required\"", source) ||
            push!(failures, "widget promotion requirements JSON schema must include summary counts by area and release-required status")
    end
    if isfile(WIDGET_PROMOTION_REQUIREMENTS_SCHEMA_AUDIT_SCRIPT)
        source = read(WIDGET_PROMOTION_REQUIREMENTS_SCHEMA_AUDIT_SCRIPT, String)
        occursin("REQUIRED_SUMMARY_KEYS", source) &&
            occursin("\"by_area\"", source) &&
            occursin("\"by_release_required\"", source) ||
            push!(failures, "widget promotion requirements schema audit must check summary keys")
    end
    if isfile(EXPERIMENTAL_PROMOTION_AUDIT_TEST)
        source = read(EXPERIMENTAL_PROMOTION_AUDIT_TEST, String)
        occursin("ExperimentalPromotionAudit.audit", source) &&
            occursin("proposed-stale.tsv", source) &&
            occursin("invalid decision", source) &&
            occursin("duplicates experimental binding", source) || push!(failures, "experimental promotion audit tests must cover default audit, stale proposed rows, malformed rows, and duplicate rows")
    end
    if isfile(PILOT_EVIDENCE_PACKAGE_AUDIT_TEST)
        source = read(PILOT_EVIDENCE_PACKAGE_AUDIT_TEST, String)
        occursin("PilotEvidencePackageAudit.audit", source) &&
            occursin("write_pilot_evidence_package", source) &&
            occursin("write_pilot_evidence_package_reports", source) &&
            occursin("package reports failed", source) &&
            occursin("--package-report-dir requires a directory argument", source) || push!(failures, "pilot evidence package audit tests must cover package validation, report validation, corruption failures, and CLI argument errors")
    end
    if isfile(TEST_RUNNER)
        runner = read(TEST_RUNNER, String)
        occursin("include(\"experimental_promotion_audit.jl\")", runner) || push!(failures, "main test runner must include experimental promotion audit tests")
        occursin("include(\"widget_promotion_requirements_audit.jl\")", runner) || push!(failures, "main test runner must include widget promotion requirements audit tests")
        occursin("include(\"widget_promotion_requirements_render.jl\")", runner) || push!(failures, "main test runner must include widget promotion requirements renderer tests")
        occursin("include(\"widget_promotion_requirements_schema_audit.jl\")", runner) || push!(failures, "main test runner must include widget promotion requirements schema audit tests")
        occursin("include(\"pilot_evidence_package_audit.jl\")", runner) || push!(failures, "main test runner must include pilot evidence package audit tests")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        documentation = read(CONTINUOUS_INTEGRATION_DOC, String)
        occursin("scripts/experimental_promotion_audit.jl", documentation) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/experimental_promotion_audit.jl")
        occursin("scripts/widget_promotion_requirements_audit.jl", documentation) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/widget_promotion_requirements_audit.jl")
        occursin("scripts/widget_promotion_requirements_schema_audit.jl", documentation) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/widget_promotion_requirements_schema_audit.jl")
        occursin("ci-artifacts/widget-promotion-requirements.json", documentation) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document widget promotion requirements JSON artifact")
        occursin("scripts/pilot_evidence_package_audit.jl", documentation) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/pilot_evidence_package_audit.jl")
    end
    if !isfile(EXPERIMENTAL_PROMOTION_LEDGER)
        push!(failures, "missing experimental promotion ledger: api/experimental_promotions.tsv")
        return failures
    end
    if isfile(EXPERIMENTAL_PROMOTION_AUDIT_SCRIPT)
        audit_failures = try
            include(EXPERIMENTAL_PROMOTION_AUDIT_SCRIPT)
            _invoke_audit_call!(:ExperimentalPromotionAudit, :audit, EXPERIMENTAL_PROMOTION_LEDGER)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_public_documentation!()
    failures = String[]
    for target in (Wicked.API, Wicked.Experimental)
        for name in Base.names(target; all=false, imported=false)
            value = getfield(target, name)
            documented = try
                Docs.doc(value) !== nothing
            catch
                false
            end
            documented || push!(failures, "facade export has no discoverable documentation: $name")
        end
    end
    return failures
end

function _mentions_code_name(source::AbstractString, name::AbstractString)
    return occursin("`$name`", source) || occursin(Regex("\\b" * escape_string(name) * "\\b"), source)
end

function _api_binding_is_type(name::AbstractString)
    symbol = Symbol(name)
    isdefined(Wicked.API, symbol) || return false
    binding = getfield(Wicked.API, symbol)
    return binding isa Type || binding isa UnionAll
end

function _invoke_audit_call!(module_name::Symbol, function_name::Symbol, args...)
    module_obj = getfield(Main, module_name)
    method = getfield(module_obj, function_name)
    try
        result = if isempty(args)
            Base.invokelatest(method)
        else
            Base.invokelatest(method, args...)
        end
        result === nothing && return ["$module_name.$function_name has no usable audit signature for the provided arguments"]
        if result isa Tuple
            return result[1] isa AbstractVector ? result[1] : [string(result[1])]
        end
        return result isa AbstractVector ? result : [string(result)]
    catch error
        if error isa MethodError
            return ["$module_name.$function_name has no usable audit signature for the provided arguments"]
        end
        rethrow(error)
    end
    return ["$module_name.$function_name has no audit method"]
end

function check_component_catalog_contract!()
    failures = String[]
    isfile(COMPONENT_CATALOG_PUBLIC_MAP_HELPER) || return ["missing shared component catalog public map parser: scripts/component_catalog_public_map.jl"]
    isfile(COMPONENT_CATALOG_PUBLIC_MAP_TEST) || push!(failures, "missing component catalog public map parser tests: test/component_catalog_public_map.jl")
    if isfile(COMPONENT_CATALOG_PUBLIC_MAP_TEST)
        test_source = read(COMPONENT_CATALOG_PUBLIC_MAP_TEST, String)
        occursin("ComponentCatalogPublicMap.read_entries", test_source) &&
            occursin("invalid-widget.md", test_source) &&
            occursin("invalid-state.md", test_source) &&
            occursin("duplicate-widget.md", test_source) &&
            occursin("duplicate-concept.md", test_source) &&
            occursin("Overlay dialog", test_source) || push!(
            failures,
            "component catalog public map parser tests must cover valid parsing, malformed widget/state rows, duplicate widget diagnostics, and duplicate concept diagnostics",
        )
        occursin("ToolkitTree", test_source) || push!(
            failures,
            "component catalog public map parser tests must cover intentional ToolkitTree exclusion",
        )
        occursin("missing_renderables", test_source) && occursin("Unmapped", test_source) || push!(
            failures,
            "component catalog public map parser tests must cover direct renderable completeness",
        )
        occursin("--list-exclusions", test_source) && occursin("list_exclusions_status", test_source) || push!(
            failures,
            "component catalog public map parser tests must cover the list-exclusions CLI mode",
        )
    end
    if isfile(TEST_RUNNER)
        runner = read(TEST_RUNNER, String)
        occursin("include(\"component_catalog_public_map.jl\")", runner) || push!(
            failures,
            "main test runner must include component catalog public map parser tests",
        )
    end
    include(COMPONENT_CATALOG_PUBLIC_MAP_HELPER)
    catalog = getfield(Main, :ComponentCatalogPublicMap)
    entries = try
        Base.invokelatest(catalog.read_entries, COMPONENT_CATALOG; root=ROOT)
    catch error
        return [sprint(showerror, error)]
    end
    exclusions = try
        Base.invokelatest(catalog.read_exclusions, COMPONENT_CATALOG; root=ROOT)
    catch error
        return [sprint(showerror, error)]
    end
    renderables = try
        Base.invokelatest(catalog.read_widget_coverage_renderables, WIDGET_COVERAGE_LEDGER; root=ROOT)
    catch error
        push!(failures, sprint(showerror, error))
        Set{String}()
    end
    missing = try
        Base.invokelatest(catalog.missing_renderables, COMPONENT_CATALOG; coverage_path=WIDGET_COVERAGE_LEDGER)
    catch error
        push!(failures, sprint(showerror, error))
        Set{String}()
    end
    widget_names = Base.invokelatest(catalog.widget_names, entries)
    state_names = Base.invokelatest(catalog.state_contract_names, entries)
    focused = IOBuffer()
    for path in FOCUSED_API_WIDGET_DOCS
        if !isfile(path)
            push!(failures, "missing focused widget API documentation: $(relpath(path, ROOT))")
            continue
        end
        write(focused, read(path, String), '\n')
    end
    docs_source = String(take!(focused))
    stable_names = Set(string(name) for name in Base.names(Wicked.API; all=false, imported=false))
    for name in sort!(collect(widget_names))
        name in stable_names || push!(failures, "public widget-name map lists `$name` but Wicked.API does not export it")
        name in stable_names && !_api_binding_is_type(name) && push!(failures, "public widget-name map lists `$name` as a widget but Wicked.API binding is not a concrete or parameterized type")
        _mentions_code_name(docs_source, name) || push!(failures, "public widget-name map lists `$name` but focused API docs do not mention it as a code name")
    end
    for name in sort!(collect(state_names))
        name in stable_names || push!(failures, "public widget-name map lists state contract `$name` but Wicked.API does not export it")
        name in stable_names && !_api_binding_is_type(name) && push!(failures, "public widget-name map lists `$name` as a state contract but Wicked.API binding is not a concrete or parameterized type")
        _mentions_code_name(docs_source, name) || push!(failures, "public widget-name map lists state contract `$name` but focused API docs do not mention it as a code name")
    end
    catalog_source = isfile(COMPONENT_CATALOG) ? read(COMPONENT_CATALOG, String) : ""
    script_source = isfile(COMPONENT_CATALOG_PUBLIC_MAP_HELPER) ? read(COMPONENT_CATALOG_PUBLIC_MAP_HELPER, String) : ""
    occursin("exclusion reason must explain why the renderable is internal", script_source) || push!(failures, "scripts/component_catalog_public_map.jl must require descriptive internal exclusion reasons")
    for name in sort!(collect(exclusions))
        name in renderables || push!(failures, "internal renderable exclusions list `$name` but widget coverage does not record it")
        _mentions_code_name(catalog_source, name) || push!(failures, "internal renderable exclusion `$name` must appear as a code name in the component catalog")
    end
    for name in sort!(collect(missing))
        push!(failures, "direct renderable `$name` is missing from the public widget-name map or internal renderable exclusions")
    end
    for path in (CONTINUOUS_INTEGRATION_DOC, RELEASE_CHECKLIST)
        isfile(path) || begin
            push!(failures, "missing component catalog self-check documentation target: $(relpath(path, ROOT))")
            continue
        end
        documentation = read(path, String)
        occursin("scripts/component_catalog_public_map.jl", documentation) || push!(failures, "$(relpath(path, ROOT)) must document scripts/component_catalog_public_map.jl")
        occursin("unmapped direct renderables", documentation) || push!(failures, "$(relpath(path, ROOT)) must mention unmapped direct renderables")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        documentation = read(CONTINUOUS_INTEGRATION_DOC, String)
        occursin("--list-unmapped", documentation) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/component_catalog_public_map.jl --list-unmapped")
        occursin("--list-exclusions", documentation) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/component_catalog_public_map.jl --list-exclusions")
    end
    return failures
end

function check_policy_files!()
    return String[
        "missing required repository policy file: $name"
        for name in REQUIRED_POLICY_FILES
        if !isfile(joinpath(ROOT, name))
    ]
end

function check_examples_readme_policy!()
    isfile(EXAMPLES_README) || return ["missing examples index: examples/README.md"]
    source = read(EXAMPLES_README, String)
    examples = Set(basename(path) for path in files_with_extension(("examples",), ".jl"))
    failures = examples_readme_policy_failures(source, examples)
    isfile(PUBLIC_EXAMPLES_AUDIT_SCRIPT) || push!(failures, "missing public examples audit: scripts/public_examples_audit.jl")
    if isfile(PUBLIC_EXAMPLES_AUDIT_SCRIPT)
        audit_source = read(PUBLIC_EXAMPLES_AUDIT_SCRIPT, String)
        occursin("PublicExamplesAudit", audit_source) &&
            occursin("Wicked.API", audit_source) &&
            occursin("ASSERTION_PATTERN", audit_source) &&
            occursin("INTERNAL_IMPORT_PATTERN", audit_source) &&
            occursin("ROOT_IMPORT_PATTERN", audit_source) &&
            occursin("INTERNAL_REFERENCE_PATTERN", audit_source) || push!(failures, "public examples audit must require Wicked.API, assertions, and reject root/internal Wicked imports or references")
    end
    isfile(PUBLIC_EXAMPLES_AUDIT_TEST) || push!(failures, "missing public examples audit tests: test/public_examples_audit.jl")
    if isfile(PUBLIC_EXAMPLES_AUDIT_TEST)
        test_source = read(PUBLIC_EXAMPLES_AUDIT_TEST, String)
        occursin("PublicExamplesAudit.audit", test_source) &&
            occursin("missing_api.jl", test_source) &&
            occursin("missing_assertion.jl", test_source) &&
            occursin("root_import.jl", test_source) &&
            occursin("internal_import.jl", test_source) &&
            occursin("internal_reference.jl", test_source) || push!(failures, "public examples audit tests must cover missing Wicked.API, missing assertions, root import, internal import, and internal reference failures")
    end
    isfile(EXAMPLE_FAMILY_AUDIT_SCRIPT) || push!(failures, "missing example family audit: scripts/example_family_audit.jl")
    isfile(EXAMPLE_FAMILIES_DOC) || push!(failures, "missing public example family guide: docs/EXAMPLE_FAMILIES.md")
    if isfile(EXAMPLE_FAMILIES_DOC)
        family_doc = read(EXAMPLE_FAMILIES_DOC, String)
        occursin("scripts/example_family_audit.jl", family_doc) &&
            occursin("examples/immediate_quickstart.jl", family_doc) &&
            occursin("examples/toolkit_quickstart.jl", family_doc) &&
            occursin("examples/reference_application.jl", family_doc) &&
            occursin("`Rule`, `Separator`, `Divider`", family_doc) &&
            occursin("`Table`, `DataTable`, `DataStateView`", family_doc) &&
            occursin("`PropertyList`, `KeyValueList`, `MetadataList`, `DescriptionList`, `DefinitionList`", family_doc) &&
            occursin("`QueryDataSource`, `VirtualList`, `VirtualTable`, `VirtualTree`", family_doc) || push!(failures, "docs/EXAMPLE_FAMILIES.md must document the example family audit, core public quickstart families, Divider in text/structure examples, DataStateView/KeyValueList/MetadataList/DefinitionList in data-display examples, and QueryDataSource in virtual-data examples")
    end
    text_quickstart = joinpath(ROOT, "examples", "text_quickstart.jl")
    if isfile(text_quickstart)
        text_quickstart_source = read(text_quickstart, String)
        occursin("Divider(HorizontalRule", text_quickstart_source) &&
            occursin("register_divider_semantic_handlers!", text_quickstart_source) &&
            occursin("@assert occursin(\"═\", snapshot)", text_quickstart_source) ||
            push!(failures, "examples/text_quickstart.jl must demonstrate Divider rendering and semantic registration")
    end
    data_display_quickstart = joinpath(ROOT, "examples", "data_display_quickstart.jl")
    if isfile(data_display_quickstart)
        data_display_quickstart_source = read(data_display_quickstart, String)
        occursin("DataStateView(data_table; status=DataLoading", data_display_quickstart_source) &&
            occursin("register_data_state_view_semantic_handlers!", data_display_quickstart_source) &&
            occursin("@assert occursin(\"Loading rows\", snapshot)", data_display_quickstart_source) &&
            occursin("KeyValueList([", data_display_quickstart_source) &&
            occursin("register_key_value_list_semantic_handlers!", data_display_quickstart_source) &&
            occursin("@assert occursin(\"KeyValueList\", snapshot)", data_display_quickstart_source) &&
            occursin("MetadataList([", data_display_quickstart_source) &&
            occursin("register_metadata_list_semantic_handlers!", data_display_quickstart_source) &&
            occursin("@assert occursin(\"MetadataList\", snapshot)", data_display_quickstart_source) &&
            occursin("DefinitionList([", data_display_quickstart_source) &&
            occursin("register_definition_list_semantic_handlers!", data_display_quickstart_source) &&
            occursin("@assert occursin(\"DefinitionList\", snapshot)", data_display_quickstart_source) ||
            push!(failures, "examples/data_display_quickstart.jl must demonstrate DataStateView, KeyValueList, MetadataList, and DefinitionList rendering and semantic registration")
    end
    virtualization_quickstart = joinpath(ROOT, "examples", "virtualization_quickstart.jl")
    if isfile(virtualization_quickstart)
        virtualization_quickstart_source = read(virtualization_quickstart, String)
        occursin("QueryDataSource(", virtualization_quickstart_source) &&
            occursin("query_data_source(query_source)", virtualization_quickstart_source) &&
            occursin("data_query_summary(query_data_source(query_source))", virtualization_quickstart_source) &&
            occursin("data_query_text(query_data_source(query_source))", virtualization_quickstart_source) &&
            occursin("data_query_markdown(query_data_source(query_source))", virtualization_quickstart_source) &&
            occursin("data_query_tsv(query_data_source(query_source))", virtualization_quickstart_source) &&
            occursin("set_query_search!(query_source", virtualization_quickstart_source) &&
            occursin("set_query_filter!(query_source", virtualization_quickstart_source) &&
            occursin("query_contains(\"Build\")", virtualization_quickstart_source) &&
            occursin("query_range(minimum=\"A\", maximum=\"C\")", virtualization_quickstart_source) &&
            occursin("query_regex(r\"Build|Release\")", virtualization_quickstart_source) &&
            occursin("VirtualRowAction(:open, \"Open\"", virtualization_quickstart_source) &&
            occursin("virtual_row_action_menu(row_actions", virtualization_quickstart_source) &&
            occursin("virtual_row_action_records(row_actions", virtualization_quickstart_source) &&
            occursin("virtual_row_action_for_shortcut(row_actions", virtualization_quickstart_source) &&
            occursin("invoke_virtual_row_action(row_actions, :open", virtualization_quickstart_source) &&
            occursin("invoke_virtual_row_action_shortcut(row_actions", virtualization_quickstart_source) &&
            occursin("invoke_virtual_row_action_batch(row_actions", virtualization_quickstart_source) &&
            occursin("virtual_row_action_batch_records(row_batch_result)", virtualization_quickstart_source) &&
            occursin("virtual_row_action_batch_summary(row_batch_result)", virtualization_quickstart_source) &&
            occursin("virtual_row_action_batch_text(row_batch_result)", virtualization_quickstart_source) &&
            occursin("virtual_row_action_batch_markdown(row_batch_result)", virtualization_quickstart_source) &&
            occursin("virtual_row_action_batch_tsv(row_batch_result)", virtualization_quickstart_source) &&
            occursin("virtual_column_action_for_shortcut(column_actions", virtualization_quickstart_source) &&
            occursin("invoke_virtual_column_action_shortcut(column_actions", virtualization_quickstart_source) &&
            occursin("virtual_column_action_summary(column_shortcut_result)", virtualization_quickstart_source) &&
            occursin("virtual_column_action_text(column_shortcut_result)", virtualization_quickstart_source) &&
            occursin("virtual_column_action_markdown(column_shortcut_result)", virtualization_quickstart_source) &&
            occursin("virtual_column_action_tsv(column_shortcut_result)", virtualization_quickstart_source) &&
            occursin("register_virtual_row_action_semantic_handlers!(table_dispatcher", virtualization_quickstart_source) &&
            occursin("register_virtual_row_action_batch_semantic_handlers!(table_dispatcher", virtualization_quickstart_source) &&
            occursin("perform_semantic_action!(table_pilot, \"virtual_table/1\", ActivateSemanticAction; value=:open)", virtualization_quickstart_source) &&
            occursin("perform_semantic_action!(table_pilot, \"virtual_table/selection\", ActivateSemanticAction; value=:open)", virtualization_quickstart_source) &&
            occursin("clear_query!(query_source)", virtualization_quickstart_source) &&
            occursin("apply_virtual_table_query!(query_source, layout)", virtualization_quickstart_source) &&
            occursin("table_layout_snapshot(layout)", virtualization_quickstart_source) &&
            occursin("restore_table_layout!(layout, layout_snapshot)", virtualization_quickstart_source) &&
            occursin("ColumnVisibilityState(hidden=[:status])", virtualization_quickstart_source) &&
            occursin("column_visibility_snapshot(visibility)", virtualization_quickstart_source) &&
            occursin("restore_column_visibility!(visibility, visibility_snapshot)", virtualization_quickstart_source) &&
            occursin("apply_virtual_column_visibility(columns, layout, visibility)", virtualization_quickstart_source) &&
            occursin("ColumnPinState(left=[:name], right=[:status])", virtualization_quickstart_source) &&
            occursin("column_pin_snapshot(pinning)", virtualization_quickstart_source) &&
            occursin("restore_column_pin!(pinning, pin_snapshot)", virtualization_quickstart_source) &&
            occursin("apply_virtual_column_pinning(columns, layout, pinning)", virtualization_quickstart_source) &&
            occursin("default_virtual_column_actions()", virtualization_quickstart_source) &&
            occursin("virtual_column_action_records(column_actions", virtualization_quickstart_source) &&
            occursin("invoke_virtual_column_action(column_actions, :show", virtualization_quickstart_source) &&
            occursin("invoke_virtual_column_action(column_actions, :pin_left", virtualization_quickstart_source) &&
            occursin("virtual_column_pin_position(pinning, :status) == :left", virtualization_quickstart_source) &&
            occursin("table_preferences_bundle(layout; visibility, pinning, column_actions, row_actions)", virtualization_quickstart_source) &&
            occursin("table_preferences_summary(preferences)", virtualization_quickstart_source) &&
            occursin("table_preferences_text(preferences)", virtualization_quickstart_source) &&
            occursin("table_preferences_markdown(preferences)", virtualization_quickstart_source) &&
            occursin("table_preferences_tsv(preferences)", virtualization_quickstart_source) &&
            occursin("restore_table_preferences!(layout, preferences; visibility, pinning)", virtualization_quickstart_source) &&
            occursin("apply_table_preferences(columns, layout; visibility, pinning)", virtualization_quickstart_source) &&
            occursin("virtual_selection_snapshot(table_state.rows)", virtualization_quickstart_source) &&
            occursin("restore_virtual_selection!(table_state.rows, selection_snapshot)", virtualization_quickstart_source) &&
            occursin("virtual_selected_row_records(table, table_state)", virtualization_quickstart_source) &&
            occursin("virtual_selected_row_snapshot(table, table_state)", virtualization_quickstart_source) &&
            occursin("virtual_range_selected_row_records(table, table_state, range_selection)", virtualization_quickstart_source) &&
            occursin("virtual_range_selected_row_snapshot(table, table_state, range_selection)", virtualization_quickstart_source) &&
            occursin("invoke_virtual_range_row_action_batch(row_actions, :open, table, table_state, range_selection)", virtualization_quickstart_source) &&
            occursin("VirtualCellEditState()", virtualization_quickstart_source) &&
            occursin("begin_virtual_cell_edit!(cell_edit", virtualization_quickstart_source) &&
            occursin("commit_virtual_cell_edit!(cell_edit)", virtualization_quickstart_source) &&
            occursin("apply_virtual_cell_edit(rows[1], cell_commit)", virtualization_quickstart_source) &&
            occursin("apply_virtual_cell_edit!(editable_row, cell_commit)", virtualization_quickstart_source) &&
            occursin("VirtualCellEditHistory()", virtualization_quickstart_source) &&
            occursin("record_virtual_cell_edit!(edit_history, cell_commit)", virtualization_quickstart_source) &&
            occursin("undo_virtual_cell_edit!(edit_history)", virtualization_quickstart_source) &&
            occursin("redo_virtual_cell_edit!(edit_history)", virtualization_quickstart_source) &&
            occursin("register_virtual_cell_edit_semantic_handlers!(table_dispatcher", virtualization_quickstart_source) &&
            occursin("perform_semantic_action!(table_pilot, \"virtual_table/1/status\", SetValueSemanticAction; value=\"Ready\")", virtualization_quickstart_source) &&
            occursin("register_virtual_column_action_semantic_handlers!", virtualization_quickstart_source) &&
            occursin("perform_semantic_action!(table_pilot, \"virtual_table/column/status\", ActivateSemanticAction; value=:sort)", virtualization_quickstart_source) &&
            occursin("@assert [row.name for row in fetch_items(query_source", virtualization_quickstart_source) &&
            occursin("@assert !occursin(\"Test Queued\", snapshot)", virtualization_quickstart_source) ||
            push!(failures, "examples/virtualization_quickstart.jl must demonstrate QueryDataSource incremental search/filter behavior, table-layout query bridging, and column visibility")
    end
    framework_migration_doc = joinpath(ROOT, "docs", "FRAMEWORK_MIGRATION.md")
    if isfile(framework_migration_doc)
        framework_migration_source = read(framework_migration_doc, String)
        occursin("| Divider or separator | `Rule`, `Separator`, `Divider` |", framework_migration_source) ||
            push!(failures, "docs/FRAMEWORK_MIGRATION.md must include Divider in the divider/separator vocabulary row")
    end
    if isfile(EXAMPLE_FAMILY_AUDIT_SCRIPT)
        family_source = read(EXAMPLE_FAMILY_AUDIT_SCRIPT, String)
        occursin("ExampleFamilyAudit", family_source) &&
            occursin("REQUIRED_EXAMPLES", family_source) &&
            occursin("immediate_quickstart.jl", family_source) &&
            occursin("input_events_quickstart.jl", family_source) &&
            occursin("animations_loading_quickstart.jl", family_source) &&
            occursin("graphics_quickstart.jl", family_source) &&
            occursin("extensions_quickstart.jl", family_source) &&
            occursin("toolkit_quickstart.jl", family_source) &&
            occursin("remote_transport_quickstart.jl", family_source) &&
            occursin("reference_application.jl", family_source) || push!(failures, "example family audit must cover required public quickstart families")
    end
    isfile(EXAMPLE_FAMILY_AUDIT_TEST) || push!(failures, "missing example family audit tests: test/example_family_audit.jl")
    if isfile(EXAMPLE_FAMILY_AUDIT_TEST)
        family_test_source = read(EXAMPLE_FAMILY_AUDIT_TEST, String)
        occursin("ExampleFamilyAudit.audit", family_test_source) &&
            occursin("Two example is missing", family_test_source) &&
            occursin("Two example is not listed", family_test_source) || push!(failures, "example family audit tests must cover missing files and missing README entries")
    end
    isfile(EXAMPLES_README_POLICY_TEST) || push!(failures, "missing examples README policy tests: test/examples_readme_policy.jl")
    if isfile(EXAMPLES_README_POLICY_TEST)
        test_source = read(EXAMPLES_README_POLICY_TEST, String)
        occursin("examples_readme_policy_failures", test_source) &&
            occursin("removed.jl", test_source) &&
            occursin("old.jl", test_source) || push!(failures, "examples README policy tests must cover missing listings and stale entries")
    end
    if isfile(TEST_RUNNER)
        runner = read(TEST_RUNNER, String)
        occursin("include(\"examples_readme_policy.jl\")", runner) || push!(failures, "main test runner must include examples README policy tests")
        occursin("include(\"public_examples_audit.jl\")", runner) || push!(failures, "main test runner must include public examples audit tests")
        occursin("include(\"example_family_audit.jl\")", runner) || push!(failures, "main test runner must include example family audit tests")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        documentation = read(CONTINUOUS_INTEGRATION_DOC, String)
        occursin("scripts/public_examples_audit.jl", documentation) &&
            occursin("assert at least one deterministic behavior", documentation) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/public_examples_audit.jl and assertion coverage")
        occursin("scripts/example_family_audit.jl", documentation) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/example_family_audit.jl")
        occursin("scripts/widget_family_evidence_audit.jl", documentation) &&
            occursin("WIDGET_FAMILY_EVIDENCE.md", documentation) &&
            occursin("Every type-backed `stable_api_token`", documentation) &&
            occursin("matching `precompile_token`", documentation) &&
            occursin("same final segment", documentation) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document widget family evidence audit, ledger contract, and matching precompile-token policy")
    end
    if isfile(PUBLIC_EXAMPLES_AUDIT_SCRIPT)
        audit_failures = try
            include(PUBLIC_EXAMPLES_AUDIT_SCRIPT)
            _invoke_audit_call!(:PublicExamplesAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    if isfile(EXAMPLE_FAMILY_AUDIT_SCRIPT)
        family_failures = try
            include(EXAMPLE_FAMILY_AUDIT_SCRIPT)
            _invoke_audit_call!(:ExampleFamilyAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, family_failures)
    end
    return failures
end

function examples_readme_policy_failures(source::AbstractString, examples)
    failures = String[]
    example_names = Set(basename(String(example)) for example in examples)
    documented = Set{String}()
    listed = Dict{String,Int}()
    for matched in eachmatch(r"(?<!\[)`([^`]+\.jl)`(?!\])", source)
        target = first(split(matched.captures[1], '#'; limit=2))
        name = basename(target)
        listed[name] = get(listed, name, 0) + 1
        push!(documented, name)
        name in example_names || push!(failures, "examples/README.md lists missing example file: $name")
    end
    linked = Dict{String,Int}()
    for matched in eachmatch(r"\(([^)]+\.jl(?:#[^)]+)?)\)", source)
        target = first(split(matched.captures[1], '#'; limit=2))
        target = replace(target, "%20" => " ")
        name = basename(target)
        linked[name] = get(linked, name, 0) + 1
        push!(documented, name)
        name in example_names || push!(failures, "examples/README.md links missing example file: $name")
    end
    for name in example_names
        name in documented || push!(failures, "examples/README.md must list $name")
    end
    for (name, count) in listed
        count == 1 || push!(failures, "examples/README.md lists $name multiple times")
    end
    for (name, count) in linked
        count == 1 || push!(failures, "examples/README.md links $name multiple times")
    end
    return failures
end

function check_manifest_layout!()
    failures = String[]
    generic = joinpath(ROOT, "Manifest.toml")
    isfile(generic) && push!(failures, "generic Manifest.toml is forbidden; use one manifest per supported Julia minor")
    for (name, version_prefix) in VERSIONED_MANIFESTS
        path = joinpath(ROOT, name)
        if !isfile(path)
            push!(failures, "missing version-specific environment file: $name")
            continue
        end
        content = read(path, String)
        marker = "julia_version = \"$version_prefix"
        occursin(marker, content) || push!(failures, "$name was not generated by Julia $version_prefix*")
    end
    return failures
end

function check_linux_ci_policy!()
    isfile(CI_WORKFLOW) || return ["missing Linux CI workflow: .github/workflows/ci.yml"]
    source = read(CI_WORKFLOW, String)
    failures = String[]
    non_linux_platform_pattern = Regex("(?i)\\b($(join(("win" * "dows", "mac" * "os", "dar" * "win"), "|")))\\b")
    occursin(non_linux_platform_pattern, source) && push!(failures, "CI workflow contains a non-Linux runner or platform reference")
    occursin(r"\bmatrix\.os\b", source) && push!(failures, "CI workflow must not use an OS matrix; Wicked.jl CI is Linux-only")
    occursin("scripts/experimental_promotion_audit.jl", source) || push!(failures, "CI workflow must run scripts/experimental_promotion_audit.jl")
    occursin("scripts/widget_stabilization_gate.jl", source) || push!(failures, "CI workflow must run scripts/widget_stabilization_gate.jl")
    occursin("scripts/widget_family_evidence_audit.jl", source) || push!(failures, "CI workflow must run scripts/widget_family_evidence_audit.jl")
    occursin("scripts/render_widget_family_closeout.jl", source) || push!(failures, "CI workflow must render scripts/render_widget_family_closeout.jl")
    occursin("scripts/render_widget_promotion_requirements.jl", source) &&
        occursin("scripts/widget_promotion_requirements_schema_audit.jl", source) &&
        occursin("ci-artifacts/widget-promotion-requirements.md", source) &&
        occursin("ci-artifacts/widget-promotion-requirements.json", source) ||
        push!(failures, "CI workflow must audit and render widget promotion requirements as Markdown and JSON artifacts")
    occursin("scripts/render_reference_parity_matrix.jl", source) &&
        occursin("scripts/reference_parity_matrix_schema_audit.jl", source) &&
        occursin("ci-artifacts/reference-parity-matrix.md", source) &&
        occursin("ci-artifacts/reference-parity-review.md", source) &&
        occursin("ci-artifacts/reference-parity-blocking.md", source) &&
        occursin("ci-artifacts/reference-parity-blocking.json", source) &&
        occursin("ci-artifacts/reference-parity-adapted.md", source) &&
        occursin("ci-artifacts/reference-parity-adapted.json", source) &&
        occursin("ci-artifacts/reference-parity-remote-delivery.md", source) &&
        occursin("ci-artifacts/reference-parity-remote-delivery.json", source) &&
        occursin("ci-artifacts/reference-parity-summary.tsv", source) &&
        occursin("ci-artifacts/reference-parity-summary.json", source) &&
        occursin("ci-artifacts/reference-parity-matrix.json", source) &&
        occursin("ci-artifacts/reference-parity-matrix-status.txt", source) &&
        occursin("ci-artifacts/reference-parity-matrix-status.json", source) &&
        occursin("ci-artifacts/parity-closeout-requirements.md", source) &&
        occursin("ci-artifacts/parity-closeout-requirements-status.txt", source) &&
        occursin("ci-artifacts/parity-closeout-requirements.tsv", source) &&
        occursin("ci-artifacts/parity-closeout-requirements.json", source) &&
        occursin("ci-artifacts/parity-closeout-remote-delivery.md", source) &&
        occursin("--release-status", source) &&
        occursin("--require-release-ready", source) &&
        occursin("--status", source) &&
        occursin("--report markdown", source) &&
        occursin("--family \"remote delivery\"", source) &&
        occursin("--report tsv", source) &&
        occursin("--report json", source) &&
        occursin("--columns family,status,follow_up", source) &&
        occursin("--blocking-only", source) &&
        occursin("--status adapted", source) &&
        occursin("reference-parity-adapted.json", source) &&
        occursin("--family \"Remote delivery\"", source) &&
        occursin("reference-parity-remote-delivery.json", source) &&
        occursin("--summary", source) &&
        occursin("--release-status-json", source) ||
        push!(failures, "CI workflow must render and schema-audit the reference parity matrix as full, focused review, JSON, and release-ready status artifacts")
        occursin("scripts/render_widget_catalog.jl", source) &&
        occursin("--coverage-summary", source) &&
        occursin("--coverage-summary-json", source) &&
        occursin("--coverage-status", source) &&
        occursin("--coverage-gaps", source) &&
        occursin("--stability", source) &&
        occursin("--stability-gaps", source) &&
        occursin("--stability-json", source) &&
        occursin("--surface-release-status", source) &&
        occursin("--surface-release-json", source) &&
        occursin("--require-stability-ready", source) &&
        occursin("--coverage-issue missing_record", source) &&
        occursin("--coverage-issue source_mismatch", source) &&
        occursin("--coverage-issue missing_checks", source) &&
        occursin("--coverage-issue-names missing_record", source) &&
        occursin("--coverage-issue-names source_mismatch", source) &&
        occursin("--coverage-issue-names missing_checks", source) &&
        occursin("--require-complete-coverage", source) ||
        push!(failures, "CI workflow must render stable widget coverage summary and gap artifacts with complete-coverage enforcement")
    occursin("--release-check", source) || push!(failures, "CI workflow must use --release-check for release-grade widget family closeout assertions")
    occursin("expected_family_count", source) &&
        occursin("scripts/render_widget_family_closeout.jl --count", source) &&
        occursin("--require-total-count \"\${expected_family_count}\"", source) ||
        push!(failures, "CI workflow must derive and assert the expected widget family count")
    occursin("blockers,blocker_details", source) || push!(failures, "CI workflow must include blocker details in the widget family closeout report")
    occursin("closeout_status=0", source) &&
        occursin("closeout_status=\$?", source) &&
        occursin("exit \"\${closeout_status}\"", source) ||
        push!(failures, "CI workflow must preserve widget family closeout failure status after printing artifacts")
    occursin("ci-artifacts/widget-family-closeout.md", source) || push!(failures, "CI workflow must write widget family closeout report to ci-artifacts/widget-family-closeout.md")
    occursin("ci-artifacts/widget-family-closeout-summary.tsv", source) || push!(failures, "CI workflow must write widget family closeout summary to ci-artifacts/widget-family-closeout-summary.tsv")
    occursin("ci-artifacts/widget-family-closeout.json", source) &&
        occursin("--format json", source) ||
        push!(failures, "CI workflow must write widget family closeout JSON to ci-artifacts/widget-family-closeout.json")
    occursin("ci-artifacts/stable-widget-coverage-status.txt", source) ||
        push!(failures, "CI workflow must write stable widget coverage status to ci-artifacts/stable-widget-coverage-status.txt")
    occursin("ci-artifacts/stable-widget-coverage-summary.tsv", source) ||
        push!(failures, "CI workflow must write stable widget coverage summary to ci-artifacts/stable-widget-coverage-summary.tsv")
    occursin("ci-artifacts/stable-widget-coverage-summary.json", source) ||
        push!(failures, "CI workflow must write stable widget coverage JSON summary to ci-artifacts/stable-widget-coverage-summary.json")
    occursin("ci-artifacts/stable-widget-coverage-gaps.md", source) ||
        push!(failures, "CI workflow must write stable widget coverage gaps to ci-artifacts/stable-widget-coverage-gaps.md")
    occursin("ci-artifacts/stable-widget-coverage-missing-records.md", source) ||
        push!(failures, "CI workflow must write stable widget missing-record coverage report to ci-artifacts/stable-widget-coverage-missing-records.md")
    occursin("ci-artifacts/stable-widget-coverage-missing-record-names.txt", source) ||
        push!(failures, "CI workflow must write stable widget missing-record name list to ci-artifacts/stable-widget-coverage-missing-record-names.txt")
    occursin("ci-artifacts/stable-widget-coverage-source-mismatches.md", source) ||
        push!(failures, "CI workflow must write stable widget source-mismatch coverage report to ci-artifacts/stable-widget-coverage-source-mismatches.md")
    occursin("ci-artifacts/stable-widget-coverage-source-mismatch-names.txt", source) ||
        push!(failures, "CI workflow must write stable widget source-mismatch name list to ci-artifacts/stable-widget-coverage-source-mismatch-names.txt")
    occursin("ci-artifacts/stable-widget-coverage-missing-checks.md", source) ||
        push!(failures, "CI workflow must write stable widget missing-check coverage report to ci-artifacts/stable-widget-coverage-missing-checks.md")
    occursin("ci-artifacts/stable-widget-coverage-missing-check-names.txt", source) ||
        push!(failures, "CI workflow must write stable widget missing-check name list to ci-artifacts/stable-widget-coverage-missing-check-names.txt")
    occursin("ci-artifacts/stable-widget-stability.md", source) ||
        push!(failures, "CI workflow must write stable widget stability readiness report to ci-artifacts/stable-widget-stability.md")
    occursin("ci-artifacts/stable-widget-stability-gaps.md", source) ||
        push!(failures, "CI workflow must write stable widget stability blocker report to ci-artifacts/stable-widget-stability-gaps.md")
    occursin("ci-artifacts/stable-widget-stability.json", source) ||
        push!(failures, "CI workflow must write stable widget stability JSON artifact to ci-artifacts/stable-widget-stability.json")
    occursin("ci-artifacts/stable-widget-stabilization-status.txt", source) ||
        push!(failures, "CI workflow must write stable widget stabilization status to ci-artifacts/stable-widget-stabilization-status.txt")
    occursin("ci-artifacts/stable-widget-stabilization.json", source) ||
        push!(failures, "CI workflow must write stable widget stabilization JSON artifact to ci-artifacts/stable-widget-stabilization.json")
    occursin("ci-artifacts/stable-widget-surface-release-status.txt", source) ||
        push!(failures, "CI workflow must write stable widget surface release status to ci-artifacts/stable-widget-surface-release-status.txt")
    occursin("ci-artifacts/stable-widget-surface-release.json", source) ||
        push!(failures, "CI workflow must write stable widget surface release JSON artifact to ci-artifacts/stable-widget-surface-release.json")
    occursin("scripts/widget_family_closeout_schema_audit.jl", source) ||
        push!(failures, "CI workflow must run scripts/widget_family_closeout_schema_audit.jl")
    occursin("scripts/stable_widget_coverage_schema_audit.jl", source) ||
        push!(failures, "CI workflow must run scripts/stable_widget_coverage_schema_audit.jl")
    occursin("scripts/stable_widget_stability_schema_audit.jl", source) ||
        push!(failures, "CI workflow must run scripts/stable_widget_stability_schema_audit.jl")
    occursin("scripts/stable_widget_stabilization_schema_audit.jl", source) ||
        push!(failures, "CI workflow must run scripts/stable_widget_stabilization_schema_audit.jl")
    occursin("scripts/stable_widget_surface_release_schema_audit.jl", source) ||
        push!(failures, "CI workflow must run scripts/stable_widget_surface_release_schema_audit.jl")
    occursin("actions/upload-artifact", source) &&
        occursin("widget-family-closeout-\${{ matrix.julia }}", source) &&
        occursin("if: always()", source) &&
        occursin("if-no-files-found: error", source) ||
        push!(failures, "CI workflow must upload the widget family closeout report artifact for each Julia quality job")
    occursin("actions/upload-artifact", source) &&
        occursin("stable-widget-coverage-\${{ matrix.julia }}", source) &&
        occursin("ci-artifacts/stable-widget-coverage-status.txt", source) &&
        occursin("ci-artifacts/stable-widget-coverage-summary.tsv", source) &&
        occursin("ci-artifacts/stable-widget-coverage-summary.json", source) &&
        occursin("ci-artifacts/stable-widget-coverage-gaps.md", source) &&
        occursin("ci-artifacts/stable-widget-coverage-missing-records.md", source) &&
        occursin("ci-artifacts/stable-widget-coverage-missing-record-names.txt", source) &&
        occursin("ci-artifacts/stable-widget-coverage-source-mismatches.md", source) &&
        occursin("ci-artifacts/stable-widget-coverage-source-mismatch-names.txt", source) &&
        occursin("ci-artifacts/stable-widget-coverage-missing-checks.md", source) &&
        occursin("ci-artifacts/stable-widget-coverage-missing-check-names.txt", source) &&
        occursin("ci-artifacts/stable-widget-stability.md", source) &&
        occursin("ci-artifacts/stable-widget-stability-gaps.md", source) &&
        occursin("ci-artifacts/stable-widget-stability.json", source) &&
        occursin("ci-artifacts/stable-widget-surface-release-status.txt", source) &&
        occursin("ci-artifacts/stable-widget-surface-release.json", source) &&
        occursin("ci-artifacts/widget-promotion-requirements.md", source) &&
        occursin("ci-artifacts/widget-promotion-requirements.json", source) &&
        occursin("ci-artifacts/reference-parity-matrix.md", source) &&
        occursin("ci-artifacts/reference-parity-review.md", source) &&
        occursin("ci-artifacts/reference-parity-blocking.md", source) &&
        occursin("ci-artifacts/reference-parity-blocking.json", source) &&
        occursin("ci-artifacts/reference-parity-adapted.md", source) &&
        occursin("ci-artifacts/reference-parity-adapted.json", source) &&
        occursin("ci-artifacts/reference-parity-remote-delivery.md", source) &&
        occursin("ci-artifacts/reference-parity-remote-delivery.json", source) &&
        occursin("ci-artifacts/reference-parity-summary.tsv", source) &&
        occursin("ci-artifacts/reference-parity-summary.json", source) &&
        occursin("ci-artifacts/reference-parity-matrix.json", source) &&
        occursin("ci-artifacts/reference-parity-matrix-status.txt", source) &&
        occursin("ci-artifacts/reference-parity-matrix-status.json", source) &&
        occursin("ci-artifacts/parity-closeout-requirements.md", source) &&
        occursin("ci-artifacts/parity-closeout-requirements-status.txt", source) &&
        occursin("ci-artifacts/parity-closeout-requirements.tsv", source) &&
        occursin("ci-artifacts/parity-closeout-requirements.json", source) &&
        occursin("ci-artifacts/parity-closeout-remote-delivery.md", source) &&
        occursin("if: always()", source) &&
        occursin("if-no-files-found: error", source) ||
        push!(failures, "CI workflow must upload the stable widget coverage report artifact for each Julia quality job")
    occursin("scripts/unicode_width_corpus_audit.jl", source) || push!(failures, "CI workflow must run scripts/unicode_width_corpus_audit.jl")
    occursin("scripts/remote_protocol_fixture_audit.jl", source) || push!(failures, "CI workflow must run scripts/remote_protocol_fixture_audit.jl")
    occursin("scripts/real_terminal_matrix_audit.jl", source) || push!(failures, "CI workflow must run scripts/real_terminal_matrix_audit.jl")
    occursin("scripts/terminal_evidence_audit.jl", source) || push!(failures, "CI workflow must run scripts/terminal_evidence_audit.jl")
    occursin("scripts/application_evidence_audit.jl", source) || push!(failures, "CI workflow must run scripts/application_evidence_audit.jl")
    occursin("scripts/benchmark_evidence_audit.jl", source) || push!(failures, "CI workflow must run scripts/benchmark_evidence_audit.jl")
    occursin("scripts/loading_evidence_audit.jl", source) || push!(failures, "CI workflow must run scripts/loading_evidence_audit.jl")
    occursin("scripts/documentation_evidence_audit.jl", source) || push!(failures, "CI workflow must run scripts/documentation_evidence_audit.jl")
    occursin("scripts/semantic_accessibility_evidence_audit.jl", source) || push!(failures, "CI workflow must run scripts/semantic_accessibility_evidence_audit.jl")
    occursin("using Wicked; using Wicked.API", source) || push!(failures, "CI workflow must load both Wicked and Wicked.API after precompilation")
    occursin("scripts/public_examples_audit.jl", source) || push!(failures, "CI workflow must run scripts/public_examples_audit.jl")
    occursin("scripts/example_family_audit.jl", source) || push!(failures, "CI workflow must run scripts/example_family_audit.jl")
    occursin("scripts/parity_policy_audit.jl", source) || push!(failures, "CI workflow must run scripts/parity_policy_audit.jl")
    occursin("scripts/parity_closeout_audit.jl", source) || push!(failures, "CI workflow must run scripts/parity_closeout_audit.jl")
    for (index, line) in enumerate(eachsplit(source, '\n'))
        stripped = strip(line)
        startswith(stripped, "runs-on:") || continue
        occursin("ubuntu-", stripped) || push!(failures, ".github/workflows/ci.yml:$index uses non-Ubuntu runner: $stripped")
    end
    return failures
end

function _markdown_checklist_items(path)
    isfile(path) || return Set{String}()
    items = Set{String}()
    current = nothing
    for line in readlines(path)
        matched = match(r"^\s*-\s+\[[ xX]\]\s+(.+)$", line)
        if matched !== nothing
            current !== nothing && push!(items, replace(strip(current), r"\s+" => " "))
            current = matched.captures[1]
            continue
        end
        if current !== nothing
            continuation = match(r"^\s{2,}(\S.*)$", line)
            if continuation !== nothing
                current *= " " * continuation.captures[1]
                continue
            end
            push!(items, replace(strip(current), r"\s+" => " "))
            current = nothing
        end
    end
    current !== nothing && push!(items, replace(strip(current), r"\s+" => " "))
    return items
end

function check_unicode_width_corpus!()
    failures = String[]
    isfile(UNICODE_WIDTH_CORPUS) || push!(failures, "missing Unicode width corpus: api/unicode_width_corpus.tsv")
    isfile(UNICODE_WIDTH_CORPUS_AUDIT_SCRIPT) || push!(failures, "missing Unicode width corpus audit: scripts/unicode_width_corpus_audit.jl")
    isfile(UNICODE_WIDTH_CORPUS_AUDIT_TEST) || push!(failures, "missing Unicode width corpus audit tests: test/unicode_width_corpus_audit.jl")
    isfile(UNICODE_WIDTH_CORPUS_DOC) || push!(failures, "missing Unicode width corpus documentation: docs/UNICODE_WIDTH_CORPUS.md")
    if isfile(UNICODE_WIDTH_CORPUS_DOC)
        documentation = read(UNICODE_WIDTH_CORPUS_DOC, String)
        occursin("api/unicode_width_corpus.tsv", documentation) &&
            occursin("scripts/unicode_width_corpus_audit.jl", documentation) &&
            occursin("UnicodeWidthPolicy(1)", documentation) &&
            occursin("UnicodeWidthPolicy(2)", documentation) &&
            occursin("release-evidence/unicode-width", documentation) &&
            occursin("unicode_width_corpus.sha256", documentation) &&
            occursin("unicode_width_corpus_audit.status", documentation) ||
            push!(failures, "docs/UNICODE_WIDTH_CORPUS.md must document corpus path, audit command, and width policies")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        occursin("scripts/unicode_width_corpus_audit.jl", read(CONTINUOUS_INTEGRATION_DOC, String)) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/unicode_width_corpus_audit.jl")
    end
    if isfile(RELEASE_CHECKLIST)
        checklist = read(RELEASE_CHECKLIST, String)
        occursin("scripts/unicode_width_corpus_audit.jl", checklist) &&
            occursin("api/unicode_width_corpus.tsv", checklist) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require the Unicode width corpus audit")
    end
    if isfile(RELEASE_EVIDENCE)
        release_evidence = read(RELEASE_EVIDENCE, String)
        occursin("scripts/unicode_width_corpus_audit.jl", release_evidence) &&
            occursin("Archived `api/unicode_width_corpus.tsv`", release_evidence) &&
            occursin("SHA-256 digest", release_evidence) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require archived Unicode width corpus evidence")
    end
    if isfile(UNICODE_WIDTH_CORPUS_AUDIT_SCRIPT)
        audit_source = read(UNICODE_WIDTH_CORPUS_AUDIT_SCRIPT, String)
        occursin("decode_escaped", audit_source) &&
            occursin("grapheme_width", audit_source) &&
            occursin("text_width", audit_source) &&
            occursin("expected_ambiguous_width", audit_source) ||
            push!(failures, "Unicode width corpus audit must validate escaped values, grapheme width, text width, and ambiguous width")
    end
    if isfile(UNICODE_WIDTH_CORPUS_AUDIT_TEST)
        test_source = read(UNICODE_WIDTH_CORPUS_AUDIT_TEST, String)
        occursin("UnicodeWidthCorpusAudit.audit()", test_source) &&
            occursin("decode_escaped", test_source) &&
            occursin("missing required case", test_source) &&
            occursin("duplicates case", test_source) &&
            occursin("bad-escape has invalid escaped value", test_source) ||
            push!(failures, "Unicode width corpus audit tests must cover default corpus, escape decoding, missing required cases, duplicate cases, and invalid escapes")
    end
    if isfile(TEST_RUNNER)
        occursin("include(\"unicode_width_corpus_audit.jl\")", read(TEST_RUNNER, String)) ||
            push!(failures, "main test runner must include Unicode width corpus audit tests")
    end
    if isempty(failures) && isfile(UNICODE_WIDTH_CORPUS_AUDIT_SCRIPT)
        audit_failures = try
            include(UNICODE_WIDTH_CORPUS_AUDIT_SCRIPT)
            _invoke_audit_call!(:UnicodeWidthCorpusAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_remote_protocol_fixtures!()
    failures = String[]
    isfile(REMOTE_PROTOCOL_FIXTURES) || push!(failures, "missing remote protocol fixture ledger: api/remote_protocol_fixtures.tsv")
    isfile(REMOTE_PROTOCOL_FIXTURE_AUDIT_SCRIPT) || push!(failures, "missing remote protocol fixture audit: scripts/remote_protocol_fixture_audit.jl")
    isfile(REMOTE_PROTOCOL_FIXTURE_AUDIT_TEST) || push!(failures, "missing remote protocol fixture audit tests: test/remote_protocol_fixture_audit.jl")
    isfile(REMOTE_TRANSPORT_DOC) || push!(failures, "missing remote transport documentation: docs/REMOTE_TRANSPORT.md")
    if isfile(REMOTE_TRANSPORT_DOC)
        documentation = read(REMOTE_TRANSPORT_DOC, String)
        occursin("api/remote_protocol_fixtures.tsv", documentation) &&
            occursin("scripts/remote_protocol_fixture_audit.jl", documentation) &&
            occursin("remote packet magic", documentation) &&
            occursin("protocol version", documentation) &&
            occursin("packet kinds", documentation) &&
            occursin("release-evidence/remote-protocol", documentation) &&
            occursin("remote_protocol_fixtures.sha256", documentation) &&
            occursin("remote_protocol_fixture_audit.status", documentation) ||
            push!(failures, "docs/REMOTE_TRANSPORT.md must document remote protocol fixtures and audit command")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        occursin("scripts/remote_protocol_fixture_audit.jl", read(CONTINUOUS_INTEGRATION_DOC, String)) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/remote_protocol_fixture_audit.jl")
    end
    if isfile(RELEASE_EVIDENCE)
        release_evidence = read(RELEASE_EVIDENCE, String)
        occursin("scripts/remote_protocol_fixture_audit.jl", release_evidence) &&
            occursin("api/remote_protocol_fixtures.tsv", release_evidence) &&
            occursin("protocol-v1 remote packet envelope", release_evidence) &&
            occursin("Archived `api/remote_protocol_fixtures.tsv`", release_evidence) &&
            occursin("SHA-256 digest", release_evidence) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require remote protocol fixture evidence")
    end
    if isfile(RELEASE_CHECKLIST)
        checklist = read(RELEASE_CHECKLIST, String)
        occursin("scripts/remote_protocol_fixture_audit.jl", checklist) &&
            occursin("api/remote_protocol_fixtures.tsv", checklist) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require the remote protocol fixture audit")
    end
    if isfile(REMOTE_PROTOCOL_FIXTURE_AUDIT_SCRIPT)
        audit_source = read(REMOTE_PROTOCOL_FIXTURE_AUDIT_SCRIPT, String)
        occursin("MAGIC", audit_source) &&
            occursin("REMOTE_PROTOCOL_VERSION", audit_source) &&
            occursin("minimum_payload_bytes", audit_source) &&
            occursin("decode_remote_packet", audit_source) &&
            occursin("header.flags", audit_source) ||
            push!(failures, "remote protocol fixture audit must validate magic, version, payload length, flags, and decoded messages")
    end
    if isfile(REMOTE_PROTOCOL_FIXTURE_AUDIT_TEST)
        test_source = read(REMOTE_PROTOCOL_FIXTURE_AUDIT_TEST, String)
        occursin("RemoteProtocolFixtureAudit.audit()", test_source) &&
            occursin("envelope", test_source) &&
            occursin("missing required case", test_source) &&
            occursin("duplicates fixture case", test_source) &&
            occursin("packet kind expected", test_source) &&
            occursin("unknown remote protocol fixture case", test_source) ||
            push!(failures, "remote protocol fixture audit tests must cover default fixtures, envelope parsing, missing required cases, duplicate cases, kind mismatch, and unknown cases")
    end
    if isfile(TEST_RUNNER)
        occursin("include(\"remote_protocol_fixture_audit.jl\")", read(TEST_RUNNER, String)) ||
            push!(failures, "main test runner must include remote protocol fixture audit tests")
    end
    if isempty(failures) && isfile(REMOTE_PROTOCOL_FIXTURE_AUDIT_SCRIPT)
        audit_failures = try
            include(REMOTE_PROTOCOL_FIXTURE_AUDIT_SCRIPT)
            _invoke_audit_call!(:RemoteProtocolFixtureAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_real_terminal_matrix!()
    failures = String[]
    isfile(REAL_TERMINAL_MATRIX) || push!(failures, "missing Linux real-terminal matrix: docs/REAL_TERMINAL_MATRIX.md")
    isfile(TERMINAL_COMPATIBILITY_DOC) || push!(failures, "missing terminal compatibility evidence doc: docs/TERMINAL_COMPATIBILITY.md")
    isfile(TERMINAL_EVIDENCE_TEMPLATE) || push!(failures, "missing terminal evidence template: docs/TERMINAL_EVIDENCE_TEMPLATE.md")
    isfile(REAL_TERMINAL_MATRIX_AUDIT_SCRIPT) || push!(failures, "missing real-terminal matrix audit: scripts/real_terminal_matrix_audit.jl")
    isfile(REAL_TERMINAL_MATRIX_AUDIT_TEST) || push!(failures, "missing real-terminal matrix audit tests: test/real_terminal_matrix_audit.jl")
    if isfile(REAL_TERMINAL_MATRIX_AUDIT_SCRIPT)
        audit_source = read(REAL_TERMINAL_MATRIX_AUDIT_SCRIPT, String)
        occursin("REQUIRED_CATEGORIES", audit_source) &&
            occursin("REQUIRED_IDENTITY_FIELDS", audit_source) &&
            occursin("REQUIRED_BEHAVIOR_FIELDS", audit_source) &&
            occursin("REQUIRED_COMMANDS", audit_source) &&
            occursin("Do not record non-Linux operating systems", audit_source) &&
            occursin("TERMINAL_EVIDENCE_TEMPLATE", audit_source) ||
            push!(failures, "real-terminal matrix audit must validate categories, identity fields, behavior fields, commands, Linux-only scope, and terminal evidence template")
    end
    if isfile(REAL_TERMINAL_MATRIX_AUDIT_TEST)
        test_source = read(REAL_TERMINAL_MATRIX_AUDIT_TEST, String)
        occursin("RealTerminalMatrixAudit.audit()", test_source) &&
            occursin("missing category: SSH", test_source) &&
            occursin("missing identity field: Wicked commit SHA", test_source) &&
            occursin("missing behavior field: Startup and shutdown restore terminal modes", test_source) &&
            occursin("invalid evidence status: Maybe", test_source) &&
            occursin("terminal evidence template missing identity field: Matrix category", test_source) ||
            push!(failures, "real-terminal matrix audit tests must cover default matrix, missing categories, missing fields, invalid statuses, and template failures")
    end
    if isfile(TERMINAL_EVIDENCE_TEMPLATE)
        template = read(TERMINAL_EVIDENCE_TEMPLATE, String)
        occursin("Matrix category", template) &&
            occursin("Wicked commit SHA", template) &&
            occursin("Transcript, screenshot, recording, or CI artifact URI", template) &&
            occursin("Startup and shutdown restore terminal modes", template) &&
            occursin("Risks and follow-up", template) ||
            push!(failures, "terminal evidence template must include identity, behavior, artifact, and risk sections")
    end
    if isfile(TEST_RUNNER)
        occursin("include(\"real_terminal_matrix_audit.jl\")", read(TEST_RUNNER, String)) ||
            push!(failures, "main test runner must include real-terminal matrix audit tests")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        occursin("scripts/real_terminal_matrix_audit.jl", read(CONTINUOUS_INTEGRATION_DOC, String)) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/real_terminal_matrix_audit.jl")
    end
    if isempty(failures) && isfile(REAL_TERMINAL_MATRIX_AUDIT_SCRIPT)
        audit_failures = try
            include(REAL_TERMINAL_MATRIX_AUDIT_SCRIPT)
            _invoke_audit_call!(:RealTerminalMatrixAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_terminal_evidence_records!()
    failures = String[]
    isdir(TERMINAL_EVIDENCE_DIR) || push!(failures, "missing terminal evidence records directory: docs/terminal-evidence")
    isfile(joinpath(TERMINAL_EVIDENCE_DIR, "README.md")) || push!(failures, "missing terminal evidence records README: docs/terminal-evidence/README.md")
    isfile(TERMINAL_EVIDENCE_AUDIT_SCRIPT) || push!(failures, "missing terminal evidence audit: scripts/terminal_evidence_audit.jl")
    isfile(TERMINAL_EVIDENCE_AUDIT_TEST) || push!(failures, "missing terminal evidence audit tests: test/terminal_evidence_audit.jl")
    if isfile(TERMINAL_EVIDENCE_AUDIT_SCRIPT)
        audit_source = read(TERMINAL_EVIDENCE_AUDIT_SCRIPT, String)
        occursin("REQUIRED_CATEGORIES", audit_source) &&
            occursin("REQUIRED_IDENTITY_FIELDS", audit_source) &&
            occursin("REQUIRED_BEHAVIOR_FIELDS", audit_source) &&
            occursin("--require-complete", audit_source) &&
            occursin("duplicates terminal evidence identity", audit_source) &&
            occursin("artifact must be an HTTP(S) URL or an existing artifact path", audit_source) ||
            push!(failures, "terminal evidence audit must validate categories, identity fields, behavior fields, complete mode, duplicates, and artifacts")
    end
    if isfile(TERMINAL_EVIDENCE_AUDIT_TEST)
        test_source = read(TERMINAL_EVIDENCE_AUDIT_TEST, String)
        occursin("TerminalEvidenceAudit.audit", test_source) &&
            occursin("complete mode missing category: SSH", test_source) &&
            occursin("contains TODO placeholder text", test_source) &&
            occursin("unknown matrix category: Bad terminal", test_source) &&
            occursin("duplicates terminal evidence identity", test_source) &&
            occursin("bad_status == 2", test_source) ||
            push!(failures, "terminal evidence audit tests must cover default records, complete mode, placeholders, unknown categories, duplicate identities, and bad arguments")
    end
    if isfile(TEST_RUNNER)
        occursin("include(\"terminal_evidence_audit.jl\")", read(TEST_RUNNER, String)) ||
            push!(failures, "main test runner must include terminal evidence audit tests")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        occursin("scripts/terminal_evidence_audit.jl", read(CONTINUOUS_INTEGRATION_DOC, String)) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/terminal_evidence_audit.jl")
    end
    if isfile(TERMINAL_COMPATIBILITY_DOC)
        compatibility = read(TERMINAL_COMPATIBILITY_DOC, String)
        occursin("terminal-evidence/README.md", compatibility) &&
            occursin("scripts/terminal_evidence_audit.jl --require-complete", compatibility) ||
            push!(failures, "docs/TERMINAL_COMPATIBILITY.md must document terminal evidence records and complete-mode audit")
    end
    if isfile(RELEASE_EVIDENCE)
        release_evidence = read(RELEASE_EVIDENCE, String)
        occursin("scripts/terminal_evidence_audit.jl --require-complete", release_evidence) &&
            occursin("docs/terminal-evidence", release_evidence) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require complete terminal evidence audit")
    end
    if isfile(joinpath(TERMINAL_EVIDENCE_DIR, "README.md"))
        readme = read(joinpath(TERMINAL_EVIDENCE_DIR, "README.md"), String)
        occursin("scripts/terminal_evidence_audit.jl", readme) &&
            occursin("scripts/terminal_evidence_audit.jl --require-complete", readme) &&
            occursin("REAL_TERMINAL_MATRIX.md", readme) &&
            occursin("TERMINAL_EVIDENCE_TEMPLATE.md", readme) ||
            push!(failures, "docs/terminal-evidence/README.md must document record audit, complete mode, matrix, and template")
    end
    if isempty(failures) && isfile(TERMINAL_EVIDENCE_AUDIT_SCRIPT)
        audit_failures = try
            include(TERMINAL_EVIDENCE_AUDIT_SCRIPT)
            _invoke_audit_call!(:TerminalEvidenceAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_application_evidence_records!()
    failures = String[]
    isfile(APPLICATION_EVIDENCE_TEMPLATE) || push!(failures, "missing real application evidence template: docs/REAL_APPLICATION_EVIDENCE_TEMPLATE.md")
    isdir(APPLICATION_EVIDENCE_DIR) || push!(failures, "missing real application evidence records directory: docs/application-evidence")
    isfile(joinpath(APPLICATION_EVIDENCE_DIR, "README.md")) || push!(failures, "missing real application evidence README: docs/application-evidence/README.md")
    isfile(APPLICATION_EVIDENCE_AUDIT_SCRIPT) || push!(failures, "missing real application evidence audit: scripts/application_evidence_audit.jl")
    isfile(APPLICATION_EVIDENCE_AUDIT_TEST) || push!(failures, "missing real application evidence audit tests: test/application_evidence_audit.jl")
    if isfile(APPLICATION_EVIDENCE_TEMPLATE)
        template = read(APPLICATION_EVIDENCE_TEMPLATE, String)
        occursin("Application name", template) &&
            occursin("Release-candidate commit", template) &&
            occursin("Package loading and precompilation", template) &&
            occursin("At least one interactive widget flow", template) &&
            occursin("Risks and follow-up", template) ||
            push!(failures, "real application evidence template must include identity, behavior, and risk sections")
    end
    if isfile(APPLICATION_EVIDENCE_AUDIT_SCRIPT)
        audit_source = read(APPLICATION_EVIDENCE_AUDIT_SCRIPT, String)
        occursin("MINIMUM_APPLICATIONS = 2", audit_source) &&
            occursin("REQUIRED_IDENTITY_FIELDS", audit_source) &&
            occursin("REQUIRED_BEHAVIOR_FIELDS", audit_source) &&
            occursin("--require-complete", audit_source) &&
            occursin("duplicates application evidence identity", audit_source) &&
            occursin("artifact must be an HTTP(S) URL or an existing artifact path", audit_source) ||
            push!(failures, "real application evidence audit must validate two-app complete mode, identity fields, behavior fields, duplicates, and artifacts")
    end
    if isfile(APPLICATION_EVIDENCE_AUDIT_TEST)
        test_source = read(APPLICATION_EVIDENCE_AUDIT_TEST, String)
        occursin("ApplicationEvidenceAudit.audit", test_source) &&
            occursin("requires at least 2 distinct applications, found 1", test_source) &&
            occursin("placeholder behavior field: Application startup and shutdown", test_source) &&
            occursin("artifact must be an HTTP(S) URL or an existing artifact path", test_source) &&
            occursin("duplicates application evidence identity", test_source) &&
            occursin("bad_status == 2", test_source) ||
            push!(failures, "real application evidence audit tests must cover valid records, complete mode, placeholders, artifacts, duplicate identities, and bad arguments")
    end
    if isfile(TEST_RUNNER)
        occursin("include(\"application_evidence_audit.jl\")", read(TEST_RUNNER, String)) ||
            push!(failures, "main test runner must include real application evidence audit tests")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        occursin("scripts/application_evidence_audit.jl", read(CONTINUOUS_INTEGRATION_DOC, String)) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/application_evidence_audit.jl")
    end
    if isfile(RELEASE_EVIDENCE)
        release_evidence = read(RELEASE_EVIDENCE, String)
        occursin("scripts/application_evidence_audit.jl --require-complete", release_evidence) &&
            occursin("docs/application-evidence", release_evidence) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require complete real application evidence audit")
    end
    if isfile(RELEASE_CHECKLIST)
        checklist = read(RELEASE_CHECKLIST, String)
        occursin("at least two real applications", checklist) &&
            occursin("scripts/application_evidence_audit.jl --require-complete", checklist) &&
            occursin("docs/application-evidence", checklist) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require complete real application evidence audit")
    end
    if isfile(joinpath(APPLICATION_EVIDENCE_DIR, "README.md"))
        readme = read(joinpath(APPLICATION_EVIDENCE_DIR, "README.md"), String)
        occursin("scripts/application_evidence_audit.jl", readme) &&
            occursin("scripts/application_evidence_audit.jl --require-complete", readme) &&
            occursin("at least two", readme) &&
            occursin("REAL_APPLICATION_EVIDENCE_TEMPLATE.md", readme) ||
            push!(failures, "docs/application-evidence/README.md must document audit, complete mode, two-application threshold, and template")
    end
    if isempty(failures) && isfile(APPLICATION_EVIDENCE_AUDIT_SCRIPT)
        audit_failures = try
            include(APPLICATION_EVIDENCE_AUDIT_SCRIPT)
            _invoke_audit_call!(:ApplicationEvidenceAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_benchmark_evidence_records!()
    failures = String[]
    isfile(BENCHMARK_EVIDENCE_TEMPLATE) || push!(failures, "missing benchmark evidence template: docs/BENCHMARK_EVIDENCE_TEMPLATE.md")
    isdir(BENCHMARK_EVIDENCE_DIR) || push!(failures, "missing benchmark evidence records directory: docs/benchmark-evidence")
    isfile(joinpath(BENCHMARK_EVIDENCE_DIR, "README.md")) || push!(failures, "missing benchmark evidence README: docs/benchmark-evidence/README.md")
    isfile(BENCHMARK_EVIDENCE_AUDIT_SCRIPT) || push!(failures, "missing benchmark evidence audit: scripts/benchmark_evidence_audit.jl")
    isfile(BENCHMARK_EVIDENCE_AUDIT_TEST) || push!(failures, "missing benchmark evidence audit tests: test/benchmark_evidence_audit.jl")
    benchmark_runner = joinpath(ROOT, "benchmark", "run.jl")
    if isfile(benchmark_runner)
        occursin("Wicked.Experimental", read(benchmark_runner, String)) &&
            push!(failures, "benchmark/run.jl must use Wicked.API only, not Wicked.Experimental")
    end
    if isfile(BENCHMARK_EVIDENCE_TEMPLATE)
        template = read(BENCHMARK_EVIDENCE_TEMPLATE, String)
        occursin("Benchmark command", template) &&
            occursin("Benchmark artifact path or CI URL", template) &&
            occursin("Buffer diff", template) &&
            occursin("Virtual data", template) &&
            occursin("Regression review", template) ||
            push!(failures, "benchmark evidence template must include identity, workload, artifact, and regression sections")
    end
    if isfile(BENCHMARK_EVIDENCE_AUDIT_SCRIPT)
        audit_source = read(BENCHMARK_EVIDENCE_AUDIT_SCRIPT, String)
        occursin("REQUIRED_WORKLOADS", audit_source) &&
            occursin("--require-complete", audit_source) &&
            occursin("benchmark command must run benchmark/run.jl --check", audit_source) &&
            occursin("duplicates benchmark evidence for candidate", audit_source) &&
            occursin("artifact must be an HTTP(S) URL or an existing artifact path", audit_source) ||
            push!(failures, "benchmark evidence audit must validate workloads, complete mode, command provenance, duplicates, and artifacts")
    end
    if isfile(BENCHMARK_EVIDENCE_AUDIT_TEST)
        test_source = read(BENCHMARK_EVIDENCE_AUDIT_TEST, String)
        occursin("BenchmarkEvidenceAudit.audit", test_source) &&
            occursin("complete mode requires at least one completed benchmark record", test_source) &&
            occursin("placeholder workload field: Buffer diff", test_source) &&
            occursin("benchmark command must run benchmark/run.jl --check", test_source) &&
            occursin("duplicates benchmark evidence for candidate", test_source) &&
            occursin("bad_status == 2", test_source) ||
            push!(failures, "benchmark evidence audit tests must cover valid records, complete mode, placeholders, command provenance, duplicate identities, and bad arguments")
    end
    if isfile(TEST_RUNNER)
        occursin("include(\"benchmark_evidence_audit.jl\")", read(TEST_RUNNER, String)) ||
            push!(failures, "main test runner must include benchmark evidence audit tests")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        occursin("scripts/benchmark_evidence_audit.jl", read(CONTINUOUS_INTEGRATION_DOC, String)) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/benchmark_evidence_audit.jl")
    end
    if isfile(RELEASE_EVIDENCE)
        release_evidence = read(RELEASE_EVIDENCE, String)
        occursin("scripts/benchmark_evidence_audit.jl --require-complete", release_evidence) &&
            occursin("docs/benchmark-evidence", release_evidence) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require complete benchmark evidence audit")
    end
    if isfile(RELEASE_CHECKLIST)
        checklist = read(RELEASE_CHECKLIST, String)
        occursin("scripts/benchmark_evidence_audit.jl --require-complete", checklist) &&
            occursin("docs/benchmark-evidence", checklist) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require complete benchmark evidence audit")
    end
    if isfile(joinpath(BENCHMARK_EVIDENCE_DIR, "README.md"))
        readme = read(joinpath(BENCHMARK_EVIDENCE_DIR, "README.md"), String)
        occursin("scripts/benchmark_evidence_audit.jl", readme) &&
            occursin("scripts/benchmark_evidence_audit.jl --require-complete", readme) &&
            occursin("BENCHMARK_EVIDENCE_TEMPLATE.md", readme) &&
            occursin("benchmark/run.jl --check", readme) ||
            push!(failures, "docs/benchmark-evidence/README.md must document audit, complete mode, template, and benchmark command")
    end
    if isempty(failures) && isfile(BENCHMARK_EVIDENCE_AUDIT_SCRIPT)
        audit_failures = try
            include(BENCHMARK_EVIDENCE_AUDIT_SCRIPT)
            _invoke_audit_call!(:BenchmarkEvidenceAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_loading_evidence_records!()
    failures = String[]
    isfile(LOADING_EVIDENCE_TEMPLATE) || push!(failures, "missing package loading evidence template: docs/PACKAGE_LOADING_EVIDENCE_TEMPLATE.md")
    isdir(LOADING_EVIDENCE_DIR) || push!(failures, "missing package loading evidence records directory: docs/loading-evidence")
    isfile(joinpath(LOADING_EVIDENCE_DIR, "README.md")) || push!(failures, "missing package loading evidence README: docs/loading-evidence/README.md")
    isfile(LOADING_EVIDENCE_AUDIT_SCRIPT) || push!(failures, "missing package loading evidence audit: scripts/loading_evidence_audit.jl")
    isfile(LOADING_EVIDENCE_AUDIT_TEST) || push!(failures, "missing package loading evidence audit tests: test/loading_evidence_audit.jl")
    if isfile(LOADING_EVIDENCE_TEMPLATE)
        template = read(LOADING_EVIDENCE_TEMPLATE, String)
        occursin("Depot profile", template) &&
            occursin("Loading command", template) &&
            occursin("`Pkg.precompile()` completed", template) &&
            occursin("`using Wicked.API` completed", template) &&
            occursin("No raw terminal mode", template) ||
            push!(failures, "package loading evidence template must include depot, command, precompile, API import, and no-terminal-side-effect fields")
    end
    if isfile(LOADING_EVIDENCE_AUDIT_SCRIPT)
        audit_source = read(LOADING_EVIDENCE_AUDIT_SCRIPT, String)
        occursin("MINIMUM_JULIA_VERSIONS = 2", audit_source) &&
            occursin("REQUIRED_IDENTITY_FIELDS", audit_source) &&
            occursin("REQUIRED_BEHAVIOR_FIELDS", audit_source) &&
            occursin("--require-complete", audit_source) &&
            occursin("loading command must run Pkg.precompile()", audit_source) &&
            occursin("duplicates loading evidence identity", audit_source) ||
            push!(failures, "package loading evidence audit must validate two Julia versions, identity fields, behavior fields, complete mode, precompile command, and duplicates")
    end
    if isfile(LOADING_EVIDENCE_AUDIT_TEST)
        test_source = read(LOADING_EVIDENCE_AUDIT_TEST, String)
        occursin("LoadingEvidenceAudit.audit", test_source) &&
            occursin("requires at least 2 distinct Julia versions, found 1", test_source) &&
            occursin("placeholder behavior field: `using Wicked.API` completed", test_source) &&
            occursin("loading command must import Wicked.API", test_source) &&
            occursin("duplicates loading evidence identity", test_source) &&
            occursin("bad_status == 2", test_source) ||
            push!(failures, "package loading evidence audit tests must cover valid records, complete mode, placeholders, command provenance, duplicate identities, and bad arguments")
    end
    if isfile(TEST_RUNNER)
        occursin("include(\"loading_evidence_audit.jl\")", read(TEST_RUNNER, String)) ||
            push!(failures, "main test runner must include package loading evidence audit tests")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        occursin("scripts/loading_evidence_audit.jl", read(CONTINUOUS_INTEGRATION_DOC, String)) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/loading_evidence_audit.jl")
    end
    package_loading_doc = joinpath(ROOT, "docs", "PACKAGE_LOADING.md")
    if isfile(package_loading_doc)
        package_loading_source = read(package_loading_doc, String)
            occursin("`Divider`", package_loading_source) &&
            occursin("`DataStateView`", package_loading_source) &&
            occursin("`QueryDataSource`", package_loading_source) &&
            occursin("incremental query helpers and diagnostics", package_loading_source) &&
            occursin("`query_equals`", package_loading_source) &&
            occursin("`query_contains`", package_loading_source) &&
            occursin("`query_range`", package_loading_source) &&
            occursin("`query_regex`", package_loading_source) &&
            occursin("`data_query_summary`", package_loading_source) &&
            occursin("`data_query_text`", package_loading_source) &&
            occursin("`data_query_markdown`", package_loading_source) &&
            occursin("`data_query_tsv`", package_loading_source) &&
            occursin("`apply_virtual_table_query!`", package_loading_source) &&
            occursin("`table_layout_snapshot`", package_loading_source) &&
            occursin("`restore_table_layout!`", package_loading_source) &&
            occursin("`table_preferences_bundle`", package_loading_source) &&
            occursin("`restore_table_preferences!`", package_loading_source) &&
            occursin("`apply_table_preferences`", package_loading_source) &&
            occursin("`table_preferences_summary`", package_loading_source) &&
            occursin("`table_preferences_text`", package_loading_source) &&
            occursin("`table_preferences_markdown`", package_loading_source) &&
            occursin("`table_preferences_tsv`", package_loading_source) &&
            occursin("`virtual_selection_snapshot`", package_loading_source) &&
            occursin("`restore_virtual_selection!`", package_loading_source) &&
            occursin("`virtual_selected_row_records`", package_loading_source) &&
            occursin("`virtual_selected_row_snapshot`", package_loading_source) &&
            occursin("`virtual_range_selected_row_records`", package_loading_source) &&
            occursin("`virtual_range_selected_row_snapshot`", package_loading_source) &&
            occursin("`invoke_virtual_range_row_action_batch`", package_loading_source) &&
            occursin("`VirtualCellEditState`", package_loading_source) &&
            occursin("`begin_virtual_cell_edit!`", package_loading_source) &&
            occursin("`commit_virtual_cell_edit!`", package_loading_source) &&
            occursin("`apply_virtual_cell_edit`", package_loading_source) &&
            occursin("`apply_virtual_cell_edit!`", package_loading_source) &&
            occursin("`VirtualCellEditHistory`", package_loading_source) &&
            occursin("`record_virtual_cell_edit!`", package_loading_source) &&
            occursin("`undo_virtual_cell_edit!`", package_loading_source) &&
            occursin("`redo_virtual_cell_edit!`", package_loading_source) &&
            occursin("`virtual_cell_edit_history_snapshot`", package_loading_source) &&
            occursin("`restore_virtual_cell_edit_history!`", package_loading_source) &&
            occursin("`register_virtual_cell_edit_semantic_handlers!`", package_loading_source) &&
            occursin("`ColumnVisibilityState`", package_loading_source) &&
            occursin("`column_visibility_snapshot`", package_loading_source) &&
            occursin("`restore_column_visibility!`", package_loading_source) &&
            occursin("`apply_virtual_column_visibility`", package_loading_source) &&
            occursin("`ColumnPinState`", package_loading_source) &&
            occursin("`column_pin_snapshot`", package_loading_source) &&
            occursin("`restore_column_pin!`", package_loading_source) &&
            occursin("`apply_virtual_column_pinning`", package_loading_source) &&
            occursin("`VirtualColumnAction`", package_loading_source) &&
            occursin("`VirtualRowActionBatchResult`", package_loading_source) &&
            occursin("`virtual_row_action_for_shortcut`", package_loading_source) &&
            occursin("`invoke_virtual_row_action_shortcut`", package_loading_source) &&
            occursin("`invoke_virtual_row_action_batch`", package_loading_source) &&
            occursin("`virtual_row_action_batch_records`", package_loading_source) &&
            occursin("`virtual_row_action_batch_summary`", package_loading_source) &&
            occursin("`virtual_row_action_batch_text`", package_loading_source) &&
            occursin("`virtual_row_action_batch_markdown`", package_loading_source) &&
            occursin("`virtual_row_action_batch_tsv`", package_loading_source) &&
            occursin("`virtual_column_action_for_shortcut`", package_loading_source) &&
            occursin("`invoke_virtual_column_action_shortcut`", package_loading_source) &&
            occursin("`default_virtual_column_actions`", package_loading_source) &&
            occursin("`virtual_column_action_menu`", package_loading_source) &&
            occursin("`virtual_column_action_records`", package_loading_source) &&
            occursin("`invoke_virtual_column_action`", package_loading_source) &&
            occursin("`virtual_column_action_summary`", package_loading_source) &&
            occursin("`virtual_column_action_text`", package_loading_source) &&
            occursin("`virtual_column_action_markdown`", package_loading_source) &&
            occursin("`virtual_column_action_tsv`", package_loading_source) &&
            occursin("`register_virtual_column_action_semantic_handlers!`", package_loading_source) &&
            occursin("`VirtualRowAction`", package_loading_source) &&
            occursin("`virtual_row_action_menu`", package_loading_source) &&
            occursin("`virtual_row_action_records`", package_loading_source) &&
            occursin("`invoke_virtual_row_action`", package_loading_source) &&
            occursin("`register_virtual_row_action_semantic_handlers!`", package_loading_source) &&
            occursin("`register_virtual_row_action_batch_semantic_handlers!`", package_loading_source) &&
            occursin("`KeyValueList`", package_loading_source) &&
            occursin("`MetadataList`", package_loading_source) &&
            occursin("`DefinitionList`", package_loading_source) ||
            push!(failures, "docs/PACKAGE_LOADING.md must document Divider, DataStateView, QueryDataSource, named query filters, table preference bundles and diagnostics, semantic table cell editing, selected-row records, range-selected row records and batch actions, batch action diagnostics, apply_table_preferences, table preference snapshots, column pinning, semantic column actions, column action diagnostics, semantic row actions, selected-row semantic batch actions, apply_virtual_table_query!, ColumnVisibilityState, apply_virtual_column_visibility, KeyValueList, MetadataList, and DefinitionList in the stable precompile workload")
    end
    if isfile(RELEASE_EVIDENCE)
        release_evidence = read(RELEASE_EVIDENCE, String)
        occursin("scripts/loading_evidence_audit.jl --require-complete", release_evidence) &&
            occursin("docs/loading-evidence", release_evidence) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require complete package loading evidence audit")
    end
    if isfile(RELEASE_CHECKLIST)
        checklist = read(RELEASE_CHECKLIST, String)
        occursin("scripts/loading_evidence_audit.jl --require-complete", checklist) &&
            occursin("docs/loading-evidence", checklist) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require complete package loading evidence audit")
    end
    if isfile(joinpath(LOADING_EVIDENCE_DIR, "README.md"))
        readme = read(joinpath(LOADING_EVIDENCE_DIR, "README.md"), String)
        occursin("scripts/loading_evidence_audit.jl", readme) &&
            occursin("scripts/loading_evidence_audit.jl --require-complete", readme) &&
            occursin("at least two distinct supported Julia versions", readme) &&
            occursin("PACKAGE_LOADING_EVIDENCE_TEMPLATE.md", readme) ||
            push!(failures, "docs/loading-evidence/README.md must document audit, complete mode, Julia-version threshold, and template")
    end
    if isempty(failures) && isfile(LOADING_EVIDENCE_AUDIT_SCRIPT)
        audit_failures = try
            include(LOADING_EVIDENCE_AUDIT_SCRIPT)
            _invoke_audit_call!(:LoadingEvidenceAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_documentation_evidence_records!()
    failures = String[]
    isfile(DOCUMENTATION_EVIDENCE_TEMPLATE) || push!(failures, "missing documentation evidence template: docs/DOCUMENTATION_EVIDENCE_TEMPLATE.md")
    isdir(DOCUMENTATION_EVIDENCE_DIR) || push!(failures, "missing documentation evidence records directory: docs/documentation-evidence")
    isfile(joinpath(DOCUMENTATION_EVIDENCE_DIR, "README.md")) || push!(failures, "missing documentation evidence README: docs/documentation-evidence/README.md")
    isfile(DOCUMENTATION_EVIDENCE_AUDIT_SCRIPT) || push!(failures, "missing documentation evidence audit: scripts/documentation_evidence_audit.jl")
    isfile(DOCUMENTATION_EVIDENCE_AUDIT_TEST) || push!(failures, "missing documentation evidence audit tests: test/documentation_evidence_audit.jl")
    if isfile(DOCUMENTATION_EVIDENCE_TEMPLATE)
        template = read(DOCUMENTATION_EVIDENCE_TEMPLATE, String)
        occursin("Documentation instantiate command", template) &&
            occursin("Documentation build command", template) &&
            occursin("`doctest = true` enforced", template) &&
            occursin("`checkdocs = :exports` enforced", template) &&
            occursin("Generated HTML was archived", template) ||
            push!(failures, "documentation evidence template must include instantiate, build, doctest, checkdocs, and generated HTML fields")
    end
    if isfile(DOCUMENTATION_EVIDENCE_AUDIT_SCRIPT)
        audit_source = read(DOCUMENTATION_EVIDENCE_AUDIT_SCRIPT, String)
        occursin("MINIMUM_JULIA_VERSIONS = 2", audit_source) &&
            occursin("REQUIRED_IDENTITY_FIELDS", audit_source) &&
            occursin("REQUIRED_BEHAVIOR_FIELDS", audit_source) &&
            occursin("--require-complete", audit_source) &&
            occursin("documentation build command must run docs/make.jl", audit_source) &&
            occursin("duplicates documentation evidence identity", audit_source) ||
            push!(failures, "documentation evidence audit must validate two Julia versions, identity fields, behavior fields, complete mode, docs/make.jl command provenance, and duplicates")
    end
    if isfile(DOCUMENTATION_EVIDENCE_AUDIT_TEST)
        test_source = read(DOCUMENTATION_EVIDENCE_AUDIT_TEST, String)
        occursin("DocumentationEvidenceAudit.audit", test_source) &&
            occursin("requires at least 2 distinct Julia versions, found 1", test_source) &&
            occursin("placeholder behavior field: No Documenter warnings", test_source) &&
            occursin("documentation build command must run docs/make.jl", test_source) &&
            occursin("duplicates documentation evidence identity", test_source) &&
            occursin("bad_status == 2", test_source) ||
            push!(failures, "documentation evidence audit tests must cover valid records, complete mode, placeholders, command provenance, duplicate identities, and bad arguments")
    end
    if isfile(TEST_RUNNER)
        occursin("include(\"documentation_evidence_audit.jl\")", read(TEST_RUNNER, String)) ||
            push!(failures, "main test runner must include documentation evidence audit tests")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        occursin("scripts/documentation_evidence_audit.jl", read(CONTINUOUS_INTEGRATION_DOC, String)) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/documentation_evidence_audit.jl")
    end
    if isfile(RELEASE_EVIDENCE)
        release_evidence = read(RELEASE_EVIDENCE, String)
        occursin("scripts/documentation_evidence_audit.jl --require-complete", release_evidence) &&
            occursin("docs/documentation-evidence", release_evidence) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require complete documentation evidence audit")
    end
    if isfile(RELEASE_CHECKLIST)
        checklist = read(RELEASE_CHECKLIST, String)
        occursin("scripts/documentation_evidence_audit.jl --require-complete", checklist) &&
            occursin("docs/documentation-evidence", checklist) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require complete documentation evidence audit")
    end
    if isfile(joinpath(DOCUMENTATION_EVIDENCE_DIR, "README.md"))
        readme = read(joinpath(DOCUMENTATION_EVIDENCE_DIR, "README.md"), String)
        occursin("scripts/documentation_evidence_audit.jl", readme) &&
            occursin("scripts/documentation_evidence_audit.jl --require-complete", readme) &&
            occursin("at least two distinct supported Julia versions", readme) &&
            occursin("DOCUMENTATION_EVIDENCE_TEMPLATE.md", readme) ||
            push!(failures, "docs/documentation-evidence/README.md must document audit, complete mode, Julia-version threshold, and template")
    end
    if isfile(joinpath(ROOT, "docs", "make.jl"))
        docs_make = read(joinpath(ROOT, "docs", "make.jl"), String)
        occursin("DOCUMENTATION_EVIDENCE_TEMPLATE.md", docs_make) &&
            occursin("documentation-evidence/README.md", docs_make) ||
            push!(failures, "docs/make.jl must include documentation evidence pages")
    end
    if isempty(failures) && isfile(DOCUMENTATION_EVIDENCE_AUDIT_SCRIPT)
        audit_failures = try
            include(DOCUMENTATION_EVIDENCE_AUDIT_SCRIPT)
            _invoke_audit_call!(:DocumentationEvidenceAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_semantic_evidence_records!()
    failures = String[]
    isfile(SEMANTIC_EVIDENCE_TEMPLATE) || push!(failures, "missing semantic accessibility evidence template: docs/SEMANTIC_ACCESSIBILITY_EVIDENCE_TEMPLATE.md")
    isdir(SEMANTIC_EVIDENCE_DIR) || push!(failures, "missing semantic accessibility evidence records directory: docs/semantic-evidence")
    isfile(joinpath(SEMANTIC_EVIDENCE_DIR, "README.md")) || push!(failures, "missing semantic accessibility evidence README: docs/semantic-evidence/README.md")
    isfile(SEMANTIC_EVIDENCE_AUDIT_SCRIPT) || push!(failures, "missing semantic accessibility evidence audit: scripts/semantic_accessibility_evidence_audit.jl")
    isfile(SEMANTIC_EVIDENCE_AUDIT_TEST) || push!(failures, "missing semantic accessibility evidence audit tests: test/semantic_accessibility_evidence_audit.jl")
    if isfile(SEMANTIC_EVIDENCE_TEMPLATE)
        template = read(SEMANTIC_EVIDENCE_TEMPLATE, String)
        occursin("Widget family scope", template) &&
            occursin("Semantic tree generated for each interactive stable widget", template) &&
            occursin("Semantic actions exposed for actionable widgets", template) &&
            occursin("WidgetPilot or ToolkitPilot semantic queries checked", template) &&
            occursin("Action dispatch artifact path or CI URL", template) ||
            push!(failures, "semantic accessibility evidence template must include family scope, semantic tree, semantic actions, pilot query, and action artifact fields")
    end
    if isfile(SEMANTIC_EVIDENCE_AUDIT_SCRIPT)
        audit_source = read(SEMANTIC_EVIDENCE_AUDIT_SCRIPT, String)
        occursin("REQUIRED_FAMILIES", audit_source) &&
            occursin("REQUIRED_IDENTITY_FIELDS", audit_source) &&
            occursin("REQUIRED_BEHAVIOR_FIELDS", audit_source) &&
            occursin("--require-complete", audit_source) &&
            occursin("semantic audit command must run scripts/widget_audit.jl --require-complete", audit_source) &&
            occursin("duplicates semantic evidence identity", audit_source) ||
            push!(failures, "semantic accessibility evidence audit must validate families, identity fields, behavior fields, complete mode, widget audit command provenance, and duplicates")
    end
    if isfile(SEMANTIC_EVIDENCE_AUDIT_TEST)
        test_source = read(SEMANTIC_EVIDENCE_AUDIT_TEST, String)
        occursin("SemanticAccessibilityEvidenceAudit.audit", test_source) &&
            occursin("requires a completed record for family `Core layout`", test_source) &&
            occursin("placeholder behavior field: Semantic actions exposed for actionable widgets", test_source) &&
            occursin("semantic audit command must run scripts/widget_audit.jl --require-complete", test_source) &&
            occursin("duplicates semantic evidence identity", test_source) &&
            occursin("bad_status == 2", test_source) ||
            push!(failures, "semantic accessibility evidence audit tests must cover valid records, complete mode, placeholders, command provenance, duplicate identities, and bad arguments")
    end
    if isfile(TEST_RUNNER)
        occursin("include(\"semantic_accessibility_evidence_audit.jl\")", read(TEST_RUNNER, String)) ||
            push!(failures, "main test runner must include semantic accessibility evidence audit tests")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        occursin("scripts/semantic_accessibility_evidence_audit.jl", read(CONTINUOUS_INTEGRATION_DOC, String)) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/semantic_accessibility_evidence_audit.jl")
    end
    if isfile(RELEASE_EVIDENCE)
        release_evidence = read(RELEASE_EVIDENCE, String)
        occursin("scripts/semantic_accessibility_evidence_audit.jl --require-complete", release_evidence) &&
            occursin("docs/semantic-evidence", release_evidence) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require complete semantic accessibility evidence audit")
    end
    if isfile(RELEASE_CHECKLIST)
        checklist = read(RELEASE_CHECKLIST, String)
        occursin("scripts/semantic_accessibility_evidence_audit.jl --require-complete", checklist) &&
            occursin("docs/semantic-evidence", checklist) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require complete semantic accessibility evidence audit")
    end
    if isfile(joinpath(SEMANTIC_EVIDENCE_DIR, "README.md"))
        readme = read(joinpath(SEMANTIC_EVIDENCE_DIR, "README.md"), String)
        occursin("scripts/semantic_accessibility_evidence_audit.jl", readme) &&
            occursin("scripts/semantic_accessibility_evidence_audit.jl --require-complete", readme) &&
            occursin("every stable widget family", readme) &&
            occursin("SEMANTIC_ACCESSIBILITY_EVIDENCE_TEMPLATE.md", readme) ||
            push!(failures, "docs/semantic-evidence/README.md must document audit, complete mode, stable family threshold, and template")
    end
    if isfile(joinpath(ROOT, "docs", "make.jl"))
        docs_make = read(joinpath(ROOT, "docs", "make.jl"), String)
        occursin("SEMANTIC_ACCESSIBILITY_EVIDENCE_TEMPLATE.md", docs_make) &&
            occursin("semantic-evidence/README.md", docs_make) ||
            push!(failures, "docs/make.jl must include semantic accessibility evidence pages")
    end
    if isfile(joinpath(ROOT, "docs", "FEATURE_PARITY.md"))
        feature_parity = read(joinpath(ROOT, "docs", "FEATURE_PARITY.md"), String)
        occursin("scripts/semantic_accessibility_evidence_audit.jl --require-complete", feature_parity) &&
            occursin("docs/semantic-evidence", feature_parity) ||
            push!(failures, "docs/FEATURE_PARITY.md must tie accessibility closeout to semantic accessibility evidence records")
    end
    if isempty(failures) && isfile(SEMANTIC_EVIDENCE_AUDIT_SCRIPT)
        audit_failures = try
            include(SEMANTIC_EVIDENCE_AUDIT_SCRIPT)
            _invoke_audit_call!(:SemanticAccessibilityEvidenceAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_component_catalog_widget_type_bindings!(
    component_catalog::AbstractString=COMPONENT_CATALOG,
    stable_api_baseline::AbstractString=STABLE_API_BASELINE,
)
    isfile(component_catalog) || return ["missing component catalog: $(relpath(component_catalog, ROOT))"]
    isfile(stable_api_baseline) || return ["missing stable API baseline: $(relpath(stable_api_baseline, ROOT))"]

    stable_kinds = Dict{String,String}()
    for line in eachsplit(read(stable_api_baseline, String), '\n')
        stripped = strip(line)
        (isempty(stripped) || startswith(stripped, "#") || startswith(stripped, "name\t")) && continue
        fields = split(stripped, '\t')
        length(fields) == 2 || continue
        stable_kinds[fields[1]] = fields[2]
    end

    catalog = read(component_catalog, String)
    failures = String[]
    in_public_map = false
    for line in eachsplit(catalog, '\n')
        startswith(line, "## Public widget-name map") && (in_public_map = true; continue)
        in_public_map && startswith(line, "## Internal renderable exclusions") && break
        in_public_map || continue
        startswith(line, "|") || continue
        occursin("`", line) || continue
        fields = split(line, '|')
        length(fields) >= 4 || continue
        api_cell = fields[3]
        for matched in eachmatch(r"`([^`]+)`", api_cell)
            name = matched.captures[1]
            kind = get(stable_kinds, name, "")
            kind in ("datatype", "unionall") ||
                push!(failures, "component catalog widget `$name` must be a concrete or parameterized Wicked.API type binding, found `$(isempty(kind) ? "missing" : kind)`")
        end
    end
    return failures
end

function check_parity_policy_json!()
    isfile(PARITY_POLICY_JSON) || return ["missing parity evidence policy: docs/evidence/parity_policy.json"]
    source = read(PARITY_POLICY_JSON, String)
    failures = String[]
    isfile(PARITY_POLICY_AUDIT_SCRIPT) || push!(failures, "missing parity policy audit: scripts/parity_policy_audit.jl")
    isfile(PARITY_POLICY_AUDIT_TEST) || push!(failures, "missing parity policy audit tests: test/parity_policy_audit.jl")
    if isfile(PARITY_POLICY_AUDIT_SCRIPT)
        policy_audit_source = read(PARITY_POLICY_AUDIT_SCRIPT, String)
        occursin("closeout_path", policy_audit_source) &&
            occursin("parity closeout audit must read required_command_entrypoints from policy", policy_audit_source) &&
            occursin("allowed_artifact_url_schemes", policy_audit_source) &&
            occursin("parity evidence scaffold must read allowed_artifact_url_schemes from policy", policy_audit_source) &&
            occursin("parity closeout audit must read allowed_artifact_url_schemes from policy", policy_audit_source) &&
            occursin("manual_artifact_hints", policy_audit_source) &&
            occursin("parity closeout audit must read manual_artifact_hints from policy", policy_audit_source) || push!(failures, "parity policy audit must check scaffold and closeout command-entrypoint, artifact-scheme, and manual-artifact-hint policy parsing")
    end
    if isfile(PARITY_POLICY_AUDIT_TEST)
        policy_audit_test_source = read(PARITY_POLICY_AUDIT_TEST, String)
            occursin("closeout_path=closeout", policy_audit_test_source) &&
            occursin("closeout audit must read required_command_entrypoints", policy_audit_test_source) &&
            occursin("missing artifact URL scheme: http://", policy_audit_test_source) &&
            occursin("scaffold must read allowed_artifact_url_schemes", policy_audit_test_source) &&
            occursin("closeout audit must read allowed_artifact_url_schemes", policy_audit_test_source) &&
            occursin("missing manual artifact hint: transcript", policy_audit_test_source) &&
            occursin("closeout audit must read manual_artifact_hints", policy_audit_test_source) || push!(failures, "parity policy audit tests must cover scaffold and closeout command-entrypoint, artifact-scheme, and manual-artifact-hint policy parsing")
    end
    evidence_readme = joinpath(ROOT, "docs", "evidence", "README.md")
    if isfile(evidence_readme)
        readme = read(evidence_readme, String)
        occursin("scripts/parity_policy_audit.jl", readme) || push!(failures, "docs/evidence/README.md must document scripts/parity_policy_audit.jl")
        occursin("stable_widget_stability.schema.json", readme) &&
            occursin("ci-artifacts/stable-widget-stability.json", readme) &&
            occursin("--stability-json", readme) ||
            push!(failures, "docs/evidence/README.md must document the stable widget stability JSON schema and artifact")
        occursin("stable_widget_surface_release.schema.json", readme) &&
            occursin("ci-artifacts/stable-widget-surface-release.json", readme) &&
            occursin("ci-artifacts/stable-widget-surface-release-status.txt", readme) &&
            occursin("scripts/stable_widget_surface_release_schema_audit.jl", readme) &&
            occursin("--surface-release-json", readme) &&
            occursin("release_ready", readme) ||
            push!(failures, "docs/evidence/README.md must document the stable widget surface-release JSON schema and artifact")
    end
    if isfile(TEST_RUNNER)
        runner = read(TEST_RUNNER, String)
        occursin("include(\"parity_policy_audit.jl\")", runner) || push!(failures, "main test runner must include parity policy audit tests")
    end
    for key in ("\"schema_version\"", "\"families\"", "\"required_identity_fields\"", "\"required_sections\"", "\"reference_libraries\"", "\"required_command_entrypoints\"", "\"allowed_artifact_url_schemes\"", "\"manual_artifact_hints\"", "\"minimum_final_records_per_family\"", "\"kernel_scope\"", "\"draft_directory\"", "\"final_directory\"")
        occursin(key, source) || push!(failures, "parity evidence policy missing required key: $key")
    end
    occursin("\"minimum_final_records_per_family\": 1", source) || push!(failures, "parity evidence policy minimum_final_records_per_family must be 1")
    for entrypoint in ("scripts/", "test/", "benchmark/", "docs/make.jl", "Pkg.test", "node --check", "manual:")
        occursin("\"$entrypoint\"", source) || push!(failures, "parity evidence policy required_command_entrypoints missing entrypoint: $entrypoint")
    end
    for scheme in ("http://", "https://")
        occursin("\"$scheme\"", source) || push!(failures, "parity evidence policy allowed_artifact_url_schemes missing scheme: $scheme")
    end
    for hint in ("terminal", "manual", "transcript", "screenshot", "recording", "matrix")
        occursin("\"$hint\"", source) || push!(failures, "parity evidence policy manual_artifact_hints missing hint: $hint")
    end
    for family in PARITY_EVIDENCE_FAMILIES
        occursin("\"$family\"", source) || push!(failures, "parity evidence policy families object missing family: $family")
    end
    for phrase in PARITY_EVIDENCE_SCOPE_PHRASES
        occursin(phrase, source) || push!(failures, "parity evidence policy missing scope phrase: $phrase")
    end
    for label in PARITY_REFERENCE_LABELS
        occursin("\"$label\"", source) || push!(failures, "parity evidence policy reference_libraries missing label: $label")
    end
    occursin("Linux only", source) || push!(failures, "parity evidence policy must remain Linux-only")
    if isfile(PARITY_POLICY_AUDIT_SCRIPT)
        audit_failures = try
            include(PARITY_POLICY_AUDIT_SCRIPT)
            _invoke_audit_call!(:ParityPolicyAudit, :audit)
        catch error
            [sprint(showerror, error)]
        end
        append!(failures, audit_failures)
    end
    return failures
end

function check_parity_closeout_audit!()
    failures = String[]
    evidence_readme = joinpath(ROOT, "docs", "evidence", "README.md")
    isfile(PARITY_CLOSEOUT_AUDIT_SCRIPT) || push!(failures, "missing parity closeout audit: scripts/parity_closeout_audit.jl")
    isfile(PARITY_CLOSEOUT_AUDIT_TEST) || push!(failures, "missing parity closeout audit tests: test/parity_closeout_audit.jl")
    isfile(PARITY_CLOSEOUT_REQUIREMENTS_SCHEMA) || push!(failures, "missing parity closeout requirements schema: docs/evidence/parity_closeout_requirements.schema.json")
    if isfile(PARITY_CLOSEOUT_REQUIREMENTS_SCHEMA)
        source = read(PARITY_CLOSEOUT_REQUIREMENTS_SCHEMA, String)
        occursin("\"schema_version\"", source) &&
            occursin("\"total\"", source) &&
            occursin("\"missing\"", source) &&
            occursin("\"release_ready\"", source) &&
            occursin("\"rows\"", source) &&
            occursin("\"family\"", source) &&
            occursin("\"survey_family\"", source) &&
            occursin("\"parity_status\"", source) &&
            occursin("\"follow_up\"", source) &&
            occursin("\"required\"", source) &&
            occursin("\"observed\"", source) &&
            occursin("\"status\"", source) &&
            occursin("\"scope\"", source) &&
            occursin("\"scaffold_command\"", source) &&
            occursin("\"additionalProperties\": false", source) ||
            push!(failures, "parity closeout requirements schema must cover summary and row fields")
    end
    isfile(REFERENCE_PARITY_MATRIX_RENDER_SCRIPT) || push!(failures, "missing reference parity matrix renderer: scripts/render_reference_parity_matrix.jl")
    isfile(REFERENCE_PARITY_MATRIX_RENDER_TEST) || push!(failures, "missing reference parity matrix renderer tests: test/reference_parity_matrix_render.jl")
    isfile(REFERENCE_PARITY_MATRIX_SCHEMA) || push!(failures, "missing reference parity matrix schema: docs/evidence/reference_parity_matrix.schema.json")
    isfile(REFERENCE_PARITY_SUMMARY_SCHEMA) || push!(failures, "missing reference parity summary schema: docs/evidence/reference_parity_summary.schema.json")
    isfile(REFERENCE_PARITY_MATRIX_STATUS_SCHEMA) || push!(failures, "missing reference parity matrix status schema: docs/evidence/reference_parity_matrix_status.schema.json")
    isfile(REFERENCE_PARITY_MATRIX_SCHEMA_AUDIT_SCRIPT) || push!(failures, "missing reference parity matrix schema audit: scripts/reference_parity_matrix_schema_audit.jl")
    isfile(REFERENCE_PARITY_MATRIX_SCHEMA_AUDIT_TEST) || push!(failures, "missing reference parity matrix schema audit tests: test/reference_parity_matrix_schema_audit.jl")
    if isfile(REFERENCE_PARITY_MATRIX_RENDER_SCRIPT)
        source = read(REFERENCE_PARITY_MATRIX_RENDER_SCRIPT, String)
        occursin("ReferenceParityMatrixRender", source) &&
            occursin("REFERENCE_PARITY_SURVEY.md", source) &&
            occursin("render_json", source) &&
            occursin("parse_columns", source) &&
            occursin("render_summary_json", source) &&
            occursin("--blocking-only", source) &&
            occursin("blocking_rows", source) &&
            occursin("--columns cannot be used with --summary", source) &&
            occursin("--columns cannot be used with --format json", source) &&
            occursin("render_release_status", source) &&
            occursin("render_release_blockers", source) &&
            occursin("render_release_status_json", source) &&
            occursin("blocking_records", source) &&
            occursin("blocking_details", source) &&
            occursin("assert_release_ready", source) &&
            occursin("RELEASE_READY_STATUS", source) &&
            occursin("non-matched release blocker", source) &&
            occursin("--release-status", source) &&
            occursin("--release-blockers", source) &&
            occursin("--require-release-ready", source) &&
            occursin("--source", source) &&
            occursin("--release-status-json", source) &&
            occursin("--no-header requires --format tsv", source) &&
            occursin("--columns cannot contain empty column names", source) &&
            occursin("--columns cannot contain duplicate column names", source) &&
            occursin("mutually exclusive", source) &&
            occursin("\"by_status\"", source) &&
            occursin("Renders the cross-library capability matrix", source) ||
            push!(failures, "reference parity matrix renderer must read the survey matrix, reject incompatible flags, and render Markdown, TSV, JSON status summaries, text/JSON release status, and release blocker details")
    end
    if isfile(REFERENCE_PARITY_MATRIX_RENDER_TEST)
        source = read(REFERENCE_PARITY_MATRIX_RENDER_TEST, String)
            occursin("ReferenceParityMatrixRender.parity_rows", source) &&
            occursin("family,status,follow_up", source) &&
            occursin("parse_columns", source) &&
            occursin("summary=true", source) &&
            occursin("\"adapted\": 1", source) &&
            occursin("\"matched\": 1", source) &&
            occursin("release_ready=false", source) &&
            occursin("matched-survey.md", source) &&
            occursin("render_release_status", source) &&
            occursin("render_release_blockers", source) &&
            occursin("render_release_status_json", source) &&
            occursin("assert_release_ready", source) &&
            occursin("blocked-status.txt", source) &&
            occursin("--no-header", source) &&
            occursin("family,,status", source) &&
            occursin("family,status,status", source) &&
            occursin("--release-status-json", source) &&
            occursin("--release-blockers", source) &&
            occursin("release-blockers.txt", source) &&
            occursin("source-output.tsv", source) &&
            occursin("blocking-output.tsv", source) &&
            occursin("blocking_only=true", source) &&
            occursin("blocking_records", source) &&
            occursin("--format\", \"xml", source) ||
            push!(failures, "reference parity matrix renderer tests must cover parsing, filtering, JSON summaries, text/JSON release status, release blockers, release assertion, incompatible flags, and invalid formats")
    end
    if isfile(REFERENCE_PARITY_MATRIX_SCHEMA)
        source = read(REFERENCE_PARITY_MATRIX_SCHEMA, String)
        occursin("\"schema_version\"", source) &&
            occursin("\"by_status\"", source) &&
            occursin("\"ratatui\"", source) &&
            occursin("\"textual\"", source) &&
            occursin("\"tamboui\"", source) &&
            occursin("\"lanterna\"", source) &&
            occursin("\"follow_up\"", source) ||
            push!(failures, "reference parity matrix schema must cover status summary and cross-library row fields")
    end
    if isfile(REFERENCE_PARITY_MATRIX_STATUS_SCHEMA)
        source = read(REFERENCE_PARITY_MATRIX_STATUS_SCHEMA, String)
        occursin("\"release_ready\"", source) &&
            occursin("\"total\"", source) &&
            occursin("\"blocking\"", source) &&
            occursin("\"blocking_families\"", source) &&
            occursin("\"blocking_records\"", source) &&
            occursin("\"follow_up\"", source) ||
            push!(failures, "reference parity matrix status schema must cover release readiness fields")
    end
    if isfile(REFERENCE_PARITY_SUMMARY_SCHEMA)
        source = read(REFERENCE_PARITY_SUMMARY_SCHEMA, String)
        occursin("\"schema_version\"", source) &&
            occursin("\"total\"", source) &&
            occursin("\"by_status\"", source) ||
            push!(failures, "reference parity summary schema must cover status summary fields")
    end
    if isfile(REFERENCE_PARITY_MATRIX_SCHEMA_AUDIT_SCRIPT)
        source = read(REFERENCE_PARITY_MATRIX_SCHEMA_AUDIT_SCRIPT, String)
        occursin("ReferenceParityMatrixSchemaAudit", source) &&
            occursin("reference_parity_matrix.schema.json", source) &&
            occursin("reference_parity_summary.schema.json", source) &&
            occursin("reference_parity_matrix_status.schema.json", source) &&
            occursin("REMOTE_DELIVERY_FAMILY", source) &&
            occursin("REQUIRED_ROW_KEYS", source) &&
            occursin("REQUIRED_STATUS_KEYS", source) &&
            occursin("generated_adapted_json_failures", source) &&
            occursin("generated_blocking_json_failures", source) &&
            occursin("blocking_status_filter_failures", source) &&
            occursin("generated_remote_delivery_json_failures", source) &&
            occursin("single_family_filter_failures", source) &&
            occursin("adapted_status_filter_failures", source) &&
            occursin("generated adapted JSON", source) &&
            occursin("require_nonempty", source) &&
            occursin("when adapted work exists", source) &&
            occursin("summary_key_contract_failures", source) &&
            occursin("generated_summary_json_failures", source) &&
            occursin("summary_json_arithmetic_failures", source) &&
            occursin("summary_arithmetic_failures", source) &&
            occursin("status_arithmetic_failures", source) &&
            occursin("status_blocking_records", source) &&
            occursin("blocking_records families must match blocking_families", source) &&
            occursin("follow_up_policy_failures", source) &&
            occursin("release_policy_failures", source) &&
            occursin("--release-check", source) &&
            occursin("\"ratatui\"", source) &&
            occursin("\"lanterna\"", source) ||
            push!(failures, "reference parity matrix schema audit must validate generated JSON against the schema contract, summary arithmetic, actionable follow-up policy, and release policy")
    end
    if isfile(REFERENCE_PARITY_MATRIX_SCHEMA_AUDIT_TEST)
        source = read(REFERENCE_PARITY_MATRIX_SCHEMA_AUDIT_TEST, String)
        occursin("ReferenceParityMatrixSchemaAudit.audit", source) &&
            occursin("key_contract_failures", source) &&
            occursin("generated_adapted_json_failures", source) &&
            occursin("generated_blocking_json_failures", source) &&
            occursin("blocking_status_filter_failures", source) &&
            occursin("generated_remote_delivery_json_failures", source) &&
            occursin("single_family_filter_failures", source) &&
            occursin("adapted_status_filter_failures", source) &&
            occursin("require_nonempty=false", source) &&
            occursin("summary_key_contract_failures", source) &&
            occursin("status_key_contract_failures", source) &&
            occursin("generated_summary_json_failures", source) &&
            occursin("summary_json_arithmetic_failures", source) &&
            occursin("summary_arithmetic_failures", source) &&
            occursin("status_arithmetic_failures", source) &&
            occursin("status_blocking_records", source) &&
            occursin("blocking_records families must match blocking_families", source) &&
            occursin("follow_up_policy_failures", source) &&
            occursin("release_policy_failures", source) &&
            occursin("--release-check", source) &&
            occursin("\"by_status\"", source) &&
            occursin("\"follow_up\"", source) ||
            push!(failures, "reference parity matrix schema audit tests must cover schema keys, generated JSON contract, summary arithmetic, follow-up policy, and release policy")
    end
    if isfile(PARITY_CLOSEOUT_AUDIT_SCRIPT)
        source = read(PARITY_CLOSEOUT_AUDIT_SCRIPT, String)
        for required in ("--require-complete", "--report", "--status", "--family", "policy_contract", "positive_integer_value", "contract.minimum_final_records_per_family", "release_blocking_policy_families", "release_blocking_survey_records", "survey_policy_mapping_failures", "SURVEY_TO_POLICY_FAMILY", "survey_family", "parity_status", "follow_up", "alias_map", "expected_scaffold_command", "scaffold_command", "scaffold_command must match row family", "filter_closeout_requirement_records", "unknown parity closeout family filter", "normalized_needle", "closeout_requirements_schema_failures", "closeout_requirements_json_failures", "closeout_requirement_json_rows", "closeout_requirement_records", "render_closeout_requirements_status", "render_closeout_requirements_json", "render_closeout_requirements_tsv", "render_closeout_requirements_markdown", "non-matched reference-survey family", "required_identity_fields", "required_sections", "required_command_entrypoints", "allowed_artifact_url_schemes", "manual_artifact_hints", "minimum_final_records_per_family", "policy closeout scope", "Behaviors checked", "filename must include family slug", "filename must include environment slug", "filename must include release-candidate commit", "duplicates parity evidence identity", "command_has_evidence_entrypoint", "Wicked validation/evidence entry point", "artifact_matches_manual_hint", "manual evidence artifact must include a manual artifact hint", "is_url_or_existing_path", "HTTP(S) URL or an existing artifact path", "Release-candidate commit", "Artifact path or CI URL", "Reference-library parity notes", "Ratatui", "Textual", "TamboUI", "Lanterna")
            occursin(required, source) || push!(failures, "parity closeout audit missing required validation marker: $required")
        end
    end
    if isfile(PARITY_CLOSEOUT_AUDIT_TEST)
        test_source = read(PARITY_CLOSEOUT_AUDIT_TEST, String)
        occursin("require_complete=true", test_source) &&
            occursin("TODO placeholder", test_source) &&
            occursin("unknown parity family", test_source) &&
            occursin("policy closeout scope for Layout", test_source) &&
            occursin("release_blocking_policy_families", test_source) &&
            occursin("release_blocking_survey_records", test_source) &&
            occursin("Developer-experience", test_source) &&
            occursin("Stateful-controls", test_source) &&
            occursin("closeout_requirement_records", test_source) &&
            occursin("closeout_requirements_schema_failures", test_source) &&
            occursin("closeout_requirements_json_failures", test_source) &&
            occursin("survey_family", test_source) &&
            occursin("parity_status", test_source) &&
            occursin("follow_up", test_source) &&
            occursin("render_closeout_requirements_status", test_source) &&
            occursin("parity-closeout-requirements-status.txt", test_source) &&
            occursin("scaffold_command", test_source) &&
            occursin("filter_closeout_requirement_records", test_source) &&
            occursin("--family", test_source) &&
            occursin("Remote delivery", test_source) &&
            occursin("remote delivery", test_source) &&
            occursin("missing-family", test_source) &&
            occursin("total must equal row count", test_source) &&
            occursin("missing total must equal row missing sum", test_source) &&
            occursin("row status must match missing count", test_source) &&
            occursin("scaffold_command must match row family", test_source) &&
            occursin("render_closeout_requirements_json", test_source) &&
            occursin("parity-closeout-requirements.tsv", test_source) &&
            occursin("missing-artifact.txt", test_source) &&
            occursin("\"schema_version\": 1", test_source) &&
            occursin("required_identity_fields", test_source) &&
            occursin("required_sections", test_source) &&
            occursin("required_command_entrypoints", test_source) &&
            occursin("allowed_artifact_url_schemes", test_source) &&
            occursin("minimum_final_records_per_family", test_source) &&
            occursin("minimum_final_records_per_family must be positive", test_source) &&
            occursin("run the widget checks", test_source) &&
            occursin("manual evidence artifact must include a manual artifact hint", test_source) &&
            occursin("wrong-name.md", test_source) &&
            occursin("ubuntu-latest-ci", test_source) &&
            occursin("duplicates parity evidence identity", test_source) || push!(failures, "parity closeout audit tests must cover complete-mode, placeholder, unknown-family, scope-coverage, artifact-reference, command-provenance, filename-traceability, and duplicate-identity failures")
    end
    if isfile(TEST_RUNNER)
        runner = read(TEST_RUNNER, String)
        occursin("include(\"parity_closeout_audit.jl\")", runner) || push!(failures, "main test runner must include parity closeout audit tests")
        occursin("include(\"reference_parity_matrix_render.jl\")", runner) || push!(failures, "main test runner must include reference parity matrix renderer tests")
        occursin("include(\"reference_parity_matrix_schema_audit.jl\")", runner) || push!(failures, "main test runner must include reference parity matrix schema audit tests")
    end
    if isfile(evidence_readme)
        readme = read(evidence_readme, String)
        occursin("scripts/parity_closeout_audit.jl", readme) &&
            occursin("--require-complete", readme) &&
            occursin("minimum_final_records_per_family", readme) &&
            occursin("exact family closeout scope", readme) &&
            occursin("filename to include the normalized family name", readme) &&
            occursin("terminal or browser environment", readme) &&
            occursin("manual:", readme) &&
            occursin("allowed_artifact_url_schemes", readme) &&
            occursin("manual_artifact_hints", readme) &&
            !occursin("github.com/OWNER/REPO/actions/runs/RUN_ID", readme) || push!(failures, "docs/evidence/README.md must document parity closeout audit, release-complete mode, exact family-scope behavior validation, filename traceability, and non-placeholder final artifact examples")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        ci_doc = read(CONTINUOUS_INTEGRATION_DOC, String)
        occursin("scripts/parity_closeout_audit.jl", ci_doc) || push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document scripts/parity_closeout_audit.jl")
        occursin("scripts/render_reference_parity_matrix.jl", ci_doc) &&
            occursin("scripts/reference_parity_matrix_schema_audit.jl", ci_doc) &&
            occursin("ci-artifacts/reference-parity-matrix.json", ci_doc) &&
            occursin("ci-artifacts/reference-parity-review.md", ci_doc) &&
            occursin("ci-artifacts/reference-parity-blocking.md", ci_doc) &&
            occursin("ci-artifacts/reference-parity-blocking.json", ci_doc) &&
            occursin("ci-artifacts/reference-parity-adapted.md", ci_doc) &&
            occursin("ci-artifacts/reference-parity-adapted.json", ci_doc) &&
            occursin("ci-artifacts/reference-parity-remote-delivery.md", ci_doc) &&
            occursin("ci-artifacts/reference-parity-remote-delivery.json", ci_doc) &&
            occursin("ci-artifacts/reference-parity-summary.tsv", ci_doc) &&
            occursin("ci-artifacts/reference-parity-summary.json", ci_doc) &&
            occursin("ci-artifacts/reference-parity-matrix-status.txt", ci_doc) &&
            occursin("ci-artifacts/reference-parity-matrix-status.json", ci_doc) &&
            occursin("ci-artifacts/parity-closeout-requirements.md", ci_doc) &&
            occursin("ci-artifacts/parity-closeout-requirements-status.txt", ci_doc) &&
            occursin("ci-artifacts/parity-closeout-requirements.tsv", ci_doc) &&
            occursin("ci-artifacts/parity-closeout-requirements.json", ci_doc) &&
            occursin("ci-artifacts/parity-closeout-remote-delivery.md", ci_doc) &&
            occursin("parity_closeout_requirements.schema.json", ci_doc) &&
            occursin("--require-release-ready", ci_doc) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document reference parity matrix artifacts and schema audit")
    end
    if isfile(RELEASE_EVIDENCE)
        release_evidence = read(RELEASE_EVIDENCE, String)
        occursin("scripts/parity_closeout_audit.jl --require-complete", release_evidence) || push!(failures, "docs/RELEASE_EVIDENCE.md must identify parity closeout complete-mode as required release evidence")
        for item in PARITY_CLOSEOUT_ITEMS
            occursin(item, release_evidence) || push!(failures, "docs/RELEASE_EVIDENCE.md missing parity closeout evidence item: $item")
        end
    end
    isempty(failures) || return failures
    audit_failures = try
        include(PARITY_CLOSEOUT_AUDIT_SCRIPT)
        _invoke_audit_call!(:ParityCloseoutAudit, :audit)
    catch error
        [sprint(showerror, error)]
    end
    append!(failures, audit_failures)
    return failures
end

function check_parity_release_checklist!()
    items = _markdown_checklist_items(RELEASE_CHECKLIST)
    failures = String[]
    for item in REQUIRED_PARITY_CHECKLIST_ITEMS
        item in items || push!(failures, "release checklist missing parity closeout item: $item")
    end
    return failures
end

function check_parity_evidence_scaffold!()
    isfile(PARITY_EVIDENCE_SCAFFOLD) || return ["missing parity evidence scaffold: scripts/new_parity_evidence.jl"]
    source = read(PARITY_EVIDENCE_SCAFFOLD, String)
    failures = String[]
    template_source = isfile(joinpath(ROOT, "docs", "PARITY_EVIDENCE_TEMPLATE.md")) ? read(joinpath(ROOT, "docs", "PARITY_EVIDENCE_TEMPLATE.md"), String) : ""
    for family in PARITY_EVIDENCE_FAMILIES
        occursin("\"$family\"", source) || push!(failures, "parity evidence scaffold missing family: $family")
        occursin(family, template_source) || push!(failures, "parity evidence template missing family: $family")
    end
    for required in ("--family", "--environment", "--candidate", "--final", "--date", "--julia-version", "--kernel", "--capability", "--command", "--exit-status", "--artifact", "--behavior", "--summary", "--parity-notes", "--risks", "--list-blocking")
        occursin(required, source) || push!(failures, "parity evidence scaffold missing flag: $required")
    end
    occursin("function blocking_family_lines", source) &&
        occursin("release_blocking_policy_families", source) &&
        occursin("non-matched reference-survey", source) ||
        push!(failures, "parity evidence scaffold must list current non-matched release-blocking families")
    occursin("final =", source) && occursin("environment = final ?", source) || push!(failures, "parity evidence scaffold must parse --final before final-only validation")
    occursin("function create_record", source) || push!(failures, "parity evidence scaffold must expose a testable create_record seam")
    occursin("function validate_behavior", source) &&
        occursin("FAMILY_SCOPE_MAP[family]", source) &&
        occursin("--behavior must include the closeout scope", source) || push!(failures, "parity evidence scaffold must validate final behavior text against the family closeout scope")
    occursin("function policy_contract", source) &&
        occursin("function integer_value", source) &&
        occursin("function positive_integer_value", source) &&
        occursin("function policy_command_entrypoints", source) &&
        occursin("policy_minimum_final_records_per_family", source) &&
        occursin("minimum_final_records_per_family", source) &&
        occursin("required_command_entrypoints", source) &&
        occursin("command_entrypoints=contract.command_entrypoints", source) &&
        occursin("function command_has_evidence_entrypoint", source) &&
        occursin("--command must reference a Wicked validation/evidence entry point", source) || push!(failures, "parity evidence scaffold must validate final command provenance")
    occursin("function policy_artifact_url_schemes", source) &&
        occursin("allowed_artifact_url_schemes", source) &&
        occursin("artifact_url_schemes=contract.artifact_url_schemes", source) &&
        occursin("function is_url_or_existing_path", source) &&
        occursin("--artifact must be an HTTP(S) URL or an existing artifact path", source) || push!(failures, "parity evidence scaffold must require final artifacts to be HTTP(S) URLs or existing paths")
    occursin("function policy_manual_artifact_hints", source) &&
        occursin("manual_artifact_hints", source) &&
        occursin("validate_manual_artifact", source) &&
        occursin("manual artifact hint from policy", source) || push!(failures, "parity evidence scaffold must validate manual final artifacts against policy hints")
    occursin("function policy_required_identity_fields", source) &&
        occursin("function policy_required_sections", source) &&
        occursin("require_template_field", source) &&
        occursin("require_template_section", source) || push!(failures, "parity evidence scaffold must validate template shape from policy-required fields and sections")
    if isfile(GITIGNORE)
        gitignore = read(GITIGNORE, String)
        occursin("scratch/parity-evidence", gitignore) || push!(failures, ".gitignore must keep scaffolded parity evidence drafts out of commits")
    else
        push!(failures, "missing .gitignore for parity evidence draft policy")
    end
    isfile(PARITY_EVIDENCE_SCAFFOLD_TEST) || push!(failures, "missing parity evidence scaffold tests: test/new_parity_evidence.jl")
    if isfile(PARITY_EVIDENCE_SCAFFOLD_TEST)
        test_source = read(PARITY_EVIDENCE_SCAFFOLD_TEST, String)
        occursin("Stateful-controls", test_source) &&
            occursin("Developer-experience", test_source) &&
            occursin("blocking_family_lines", test_source) &&
            occursin("Runtime\\tqueue replacement", test_source) &&
            occursin("create_record", test_source) &&
            occursin("policy_contract", test_source) &&
            occursin("policy_command_entrypoints", test_source) &&
            occursin("policy_without_entrypoints", test_source) &&
            occursin("policy_minimum_final_records_per_family", test_source) &&
            occursin("required_command_entrypoints", test_source) &&
            occursin("policy_manual_artifact_hints", test_source) &&
            occursin("linux-ci-manual-artifact-failure", test_source) &&
            occursin("policy_required_identity_fields", test_source) &&
            occursin("policy_required_sections", test_source) &&
            occursin("minimum_final_records_per_family must be positive", test_source) &&
            occursin("missing-field-template.md", test_source) &&
            occursin("missing-section-template.md", test_source) &&
            occursin("template missing required identity field from policy: Family", test_source) &&
            occursin("template missing required section from policy: Evidence summary", test_source) &&
            occursin("final", test_source) &&
            occursin("linux-ci-scope-failure", test_source) &&
            occursin("linux-ci-artifact-failure", test_source) &&
            occursin("linux-ci-command-failure", test_source) &&
            occursin("developer-experience-linux-ci-abcdef1234567890.md", test_source) || push!(failures, "parity evidence scaffold tests must cover expanded families, create_record, final-mode parsing, scope validation, artifact-reference validation, command provenance validation, and filename traceability")
    end
    if isfile(TEST_RUNNER)
        runner = read(TEST_RUNNER, String)
        occursin("include(\"new_parity_evidence.jl\")", runner) || push!(failures, "main test runner must include parity evidence scaffold tests")
    end
    return failures
end

function check_stable_widget_surface!()
    candidate_script = joinpath(ROOT, "scripts", "stable_widget_candidates.jl")
    public_candidate_script = PUBLIC_WIDGET_CANDIDATE_AUDIT_SCRIPT
    widget_catalog_source = joinpath(ROOT, "src", "WidgetCatalog.jl")
    widget_catalog_render_script = joinpath(ROOT, "scripts", "render_widget_catalog.jl")
    family_closeout_render_script = joinpath(ROOT, "scripts", "render_widget_family_closeout.jl")
    family_closeout_render_test = joinpath(ROOT, "test", "widget_family_closeout_render.jl")
    family_evidence_script = joinpath(ROOT, "scripts", "widget_family_evidence_audit.jl")
    family_evidence_ledger = joinpath(ROOT, "api", "widget_family_evidence.tsv")
    family_evidence_doc = joinpath(ROOT, "docs", "WIDGET_FAMILY_EVIDENCE.md")
    family_evidence_test = joinpath(ROOT, "test", "widget_family_evidence_audit.jl")
    widget_stabilization_gate = joinpath(ROOT, "scripts", "widget_stabilization_gate.jl")
    report_path = joinpath(ROOT, "api", "stable_widget_candidates.tsv")
    isfile(candidate_script) || return ["missing stable widget candidate script: scripts/stable_widget_candidates.jl"]
    source = read(candidate_script, String)
    public_candidate_source = isfile(public_candidate_script) ? read(public_candidate_script, String) : ""
    family_source = isfile(family_evidence_script) ? read(family_evidence_script, String) : ""
    gate_source = isfile(widget_stabilization_gate) ? read(widget_stabilization_gate, String) : ""
    ci_source = isfile(CI_WORKFLOW) ? read(CI_WORKFLOW, String) : ""
    alias_source = isfile(COMPATIBILITY_WIDGET_ALIAS_AUDIT_SCRIPT) ? read(COMPATIBILITY_WIDGET_ALIAS_AUDIT_SCRIPT, String) : ""
    failures = String[]
    isfile(widget_stabilization_gate) || push!(failures, "missing widget stabilization gate: scripts/widget_stabilization_gate.jl")
    isfile(public_candidate_script) || push!(failures, "missing public widget candidate audit: scripts/public_widget_candidate_audit.jl")
    occursin("scripts/public_widget_candidate_audit.jl", ci_source) ||
        push!(failures, "CI workflow must run scripts/public_widget_candidate_audit.jl")
    occursin("api_renderable_widget_names", public_candidate_source) &&
        occursin("public_surface_failures", public_candidate_source) &&
        occursin("report_current_failures", public_candidate_source) &&
        occursin("stable widget candidate report is stale", public_candidate_source) ||
        push!(failures, "public widget candidate audit must compare public renderable API widgets with stable candidate evidence and report freshness")
    isfile(widget_catalog_source) || push!(failures, "missing stable widget catalog API source: src/WidgetCatalog.jl")
    if isfile(widget_catalog_source)
        catalog_source = read(widget_catalog_source, String)
        occursin("struct WidgetCatalogEntry", catalog_source) &&
            occursin("stable_widget_catalog", catalog_source) &&
            occursin("stable_widget_count", catalog_source) &&
            occursin("stable_widget_names", catalog_source) &&
            occursin("widget_names_text", catalog_source) &&
            occursin("search_widget_names_text", catalog_source) &&
            occursin("widget_source_files", catalog_source) &&
            occursin("widget_source_files_text", catalog_source) &&
            occursin("search_widget_source_files_text", catalog_source) &&
            occursin("widget_source_summary", catalog_source) &&
            occursin("widget_source_summary_markdown", catalog_source) &&
            occursin("widget_source_summary_tsv", catalog_source) &&
            occursin("search_widgets", catalog_source) &&
            occursin("search_widget_count", catalog_source) &&
            occursin("group_widgets", catalog_source) &&
            occursin("widget_catalog_summary", catalog_source) &&
            occursin("widget_catalog_markdown", catalog_source) &&
            occursin("search_widget_catalog_markdown", catalog_source) &&
            occursin("search_widget_catalog_tsv", catalog_source) &&
            occursin("widget_catalog_records", catalog_source) &&
            occursin("widget_catalog_tsv", catalog_source) &&
            occursin("header::Bool", catalog_source) &&
            occursin("_widget_catalog_columns", catalog_source) &&
            occursin("iterable collection", catalog_source) &&
            occursin("Wicked widget type", catalog_source) &&
            occursin("Wicked widget instance", catalog_source) &&
            occursin("is_stable_widget", catalog_source) &&
            occursin("widget_catalog_entry", catalog_source) &&
            occursin("struct WidgetVocabularyEntry", catalog_source) &&
            occursin("widget_vocabulary", catalog_source) &&
            occursin("widget_vocabulary_records", catalog_source) &&
            occursin("search_widget_vocabulary", catalog_source) &&
            occursin("widget_vocabulary_entry", catalog_source) &&
            occursin("widget_vocabulary_widget_names", catalog_source) &&
            occursin("widget_vocabulary_markdown", catalog_source) &&
            occursin("widget_vocabulary_tsv", catalog_source) &&
            occursin("Public widget-name map", catalog_source) &&
            occursin("struct WidgetFamilyCloseoutReport", catalog_source) &&
            occursin("widget_family_closeout_reports", catalog_source) &&
            occursin("widget_family_closeout_report", catalog_source) &&
            occursin("widget_family_closeout_records", catalog_source) &&
            occursin("widget_family_closeout_gaps", catalog_source) &&
            occursin("widget_family_closeout_summary", catalog_source) &&
            occursin("widget_family_closeout_complete", catalog_source) &&
            occursin("assert_widget_family_closeout_complete", catalog_source) &&
            occursin("widget_family_closeout_markdown", catalog_source) &&
            occursin("widget_family_closeout_tsv", catalog_source) &&
            occursin("api/widget_family_evidence.tsv", catalog_source) &&
            occursin("struct WidgetStabilityReport", catalog_source) &&
            occursin("widget_stability_report", catalog_source) &&
            occursin("widget_stability_reports", catalog_source) &&
            occursin("widget_stability_gaps", catalog_source) &&
            occursin("widget_stability_ready", catalog_source) &&
            occursin("widget_stability_complete", catalog_source) &&
            occursin("assert_widget_stability_complete", catalog_source) &&
            occursin("assert_widget_stability_ready", catalog_source) &&
            occursin("widget_stability_summary", catalog_source) &&
            occursin("widget_stability_summary_records", catalog_source) &&
            occursin("widget_stability_summary_markdown", catalog_source) &&
            occursin("widget_stability_summary_tsv", catalog_source) &&
            occursin("widget_stability_summary_text", catalog_source) &&
            occursin("widget_stability_markdown", catalog_source) &&
            occursin("widget_stability_tsv", catalog_source) &&
            occursin("widget_stability_gaps_markdown", catalog_source) &&
            occursin("widget_stability_gaps_tsv", catalog_source) &&
            occursin("widget_stability_json", catalog_source) &&
            occursin("widget_surface_release_status_record", catalog_source) &&
            occursin("widget_surface_release_ready", catalog_source) &&
            occursin("assert_widget_surface_release_ready", catalog_source) &&
            occursin("widget_surface_release_status_text", catalog_source) &&
            occursin("widget_surface_release_status_json", catalog_source) &&
            occursin("widget_coverage_records", catalog_source) &&
            occursin("widget_coverage_gaps", catalog_source) &&
            occursin("widget_coverage_issue_records", catalog_source) &&
            occursin("widget_coverage_issue_count", catalog_source) &&
            occursin("widget_coverage_issue_names", catalog_source) &&
            occursin("widget_coverage_issue_text", catalog_source) &&
            occursin("widget_coverage_issue_markdown", catalog_source) &&
            occursin("widget_coverage_issue_tsv", catalog_source) &&
            occursin("widget_coverage_complete", catalog_source) &&
            occursin("assert_widget_coverage_complete", catalog_source) &&
            occursin("widget_coverage_git_metadata", catalog_source) &&
            occursin("assert_widget_coverage_clean_git", catalog_source) &&
            occursin("widget_coverage_release_ready", catalog_source) &&
            occursin("assert_widget_coverage_release_ready", catalog_source) &&
            occursin("widget_coverage_release_status_record", catalog_source) &&
            occursin("widget_coverage_release_status_json", catalog_source) &&
            occursin("widget_coverage_release_status_text", catalog_source) &&
            occursin("status --porcelain --untracked-files=all", catalog_source) &&
            occursin("Iterators.take(gaps, 5)", catalog_source) &&
            occursin("widget_coverage_summary", catalog_source) &&
            occursin("widget_coverage_summary_records", catalog_source) &&
            occursin("widget_coverage_summary_markdown", catalog_source) &&
            occursin("widget_coverage_summary_json", catalog_source) &&
            occursin("widget_coverage_summary_text", catalog_source) &&
            occursin("widget_coverage_summary_tsv", catalog_source) &&
            occursin("widget_coverage_records_markdown", catalog_source) &&
            occursin("widget_coverage_gaps_tsv", catalog_source) &&
            occursin("widget_coverage.tsv", catalog_source) &&
            occursin("stable_widget_candidates.tsv", catalog_source) ||
            push!(failures, "src/WidgetCatalog.jl must expose typed stable widget catalog helpers backed by the candidate ledger")
    end
    isfile(WIDGET_CATALOG_TEST) || push!(failures, "missing stable widget catalog tests: test/widget_catalog.jl")
    isfile(STABLE_WIDGET_STABILIZATION_SCHEMA) || push!(failures, "missing stable widget stabilization schema: docs/evidence/stable_widget_stabilization.schema.json")
    isfile(STABLE_WIDGET_STABILIZATION_SCHEMA_AUDIT_SCRIPT) || push!(failures, "missing stable widget stabilization schema audit: scripts/stable_widget_stabilization_schema_audit.jl")
    isfile(STABLE_WIDGET_STABILIZATION_SCHEMA_AUDIT_TEST) || push!(failures, "missing stable widget stabilization schema audit tests: test/stable_widget_stabilization_schema_audit.jl")
    if isfile(STABLE_WIDGET_STABILIZATION_SCHEMA)
        stabilization_schema_source = read(STABLE_WIDGET_STABILIZATION_SCHEMA, String)
        occursin("\"schema_version\"", stabilization_schema_source) &&
            occursin("\"ready\"", stabilization_schema_source) &&
            occursin("\"candidate_widget_count\"", stabilization_schema_source) &&
            occursin("\"candidate_widgets\"", stabilization_schema_source) &&
            occursin("\"experimental_widget_count\"", stabilization_schema_source) &&
            occursin("\"experimental_widgets\"", stabilization_schema_source) &&
            occursin("\"stability_blocked\"", stabilization_schema_source) &&
            occursin("\"family_closeout_blocked\"", stabilization_schema_source) &&
            occursin("\"additionalProperties\": false", stabilization_schema_source) ||
            push!(failures, "stable widget stabilization schema must define the complete closeout contract")
    end
    if isfile(STABLE_WIDGET_STABILIZATION_SCHEMA_AUDIT_SCRIPT)
        stabilization_audit_source = read(STABLE_WIDGET_STABILIZATION_SCHEMA_AUDIT_SCRIPT, String)
        occursin("module StableWidgetStabilizationSchemaAudit", stabilization_audit_source) &&
            occursin("widget_stabilization_status_json", stabilization_audit_source) &&
            occursin("stable_widget_stabilization.schema.json", stabilization_audit_source) &&
            occursin("readiness_consistency_failures", stabilization_audit_source) &&
            occursin("candidate_widget_count must match candidate_widgets length", stabilization_audit_source) &&
            occursin("experimental_widget_count must match experimental_widgets length", stabilization_audit_source) &&
            occursin("ready must match candidate, experimental, stability, and family closeout blockers", stabilization_audit_source) ||
            push!(failures, "stable widget stabilization schema audit must validate generated JSON keys and closeout consistency")
    end
    if isfile(STABLE_WIDGET_STABILIZATION_SCHEMA_AUDIT_TEST)
        stabilization_audit_test_source = read(STABLE_WIDGET_STABILIZATION_SCHEMA_AUDIT_TEST, String)
        occursin("StableWidgetStabilizationSchemaAudit.audit()", stabilization_audit_test_source) &&
            occursin("stable_widget_stabilization_schema_audit.jl", stabilization_audit_test_source) &&
            occursin("key_contract_failures", stabilization_audit_test_source) &&
            occursin("readiness_consistency_failures", stabilization_audit_test_source) &&
            occursin("candidate_widget_count must match candidate_widgets length", stabilization_audit_test_source) &&
            occursin("ready must match candidate, experimental, stability, and family closeout blockers", stabilization_audit_test_source) &&
            occursin("generated JSON is missing schema key `experimental_widgets`", stabilization_audit_test_source) ||
            push!(failures, "stable widget stabilization schema audit tests must cover help, contract keys, array counts, and readiness consistency errors")
    end
    isfile(STABLE_WIDGET_SURFACE_RELEASE_SCHEMA) || push!(failures, "missing stable widget surface release schema: docs/evidence/stable_widget_surface_release.schema.json")
    isfile(STABLE_WIDGET_SURFACE_RELEASE_SCHEMA_AUDIT_SCRIPT) || push!(failures, "missing stable widget surface release schema audit: scripts/stable_widget_surface_release_schema_audit.jl")
    isfile(STABLE_WIDGET_SURFACE_RELEASE_SCHEMA_AUDIT_TEST) || push!(failures, "missing stable widget surface release schema audit tests: test/stable_widget_surface_release_schema_audit.jl")
    if isfile(STABLE_WIDGET_SURFACE_RELEASE_SCHEMA)
        surface_release_schema_source = read(STABLE_WIDGET_SURFACE_RELEASE_SCHEMA, String)
        occursin("\"schema_version\"", surface_release_schema_source) &&
            occursin("\"release_ready\"", surface_release_schema_source) &&
            occursin("\"coverage_release_ready\"", surface_release_schema_source) &&
            occursin("\"coverage_complete\"", surface_release_schema_source) &&
            occursin("\"git_available\"", surface_release_schema_source) &&
            occursin("\"git_dirty\"", surface_release_schema_source) &&
            occursin("\"git_commit\"", surface_release_schema_source) &&
            occursin("\"stability_complete\"", surface_release_schema_source) &&
            occursin("\"stability_blocked\"", surface_release_schema_source) &&
            occursin("\"family_closeout_complete\"", surface_release_schema_source) &&
            occursin("\"family_closeout_blocked\"", surface_release_schema_source) &&
            occursin("\"additionalProperties\": false", surface_release_schema_source) ||
            push!(failures, "stable widget surface release schema must define the complete release-readiness contract")
    end
    if isfile(STABLE_WIDGET_SURFACE_RELEASE_SCHEMA_AUDIT_SCRIPT)
        surface_release_audit_source = read(STABLE_WIDGET_SURFACE_RELEASE_SCHEMA_AUDIT_SCRIPT, String)
        occursin("module StableWidgetSurfaceReleaseSchemaAudit", surface_release_audit_source) &&
            occursin("widget_surface_release_status_json", surface_release_audit_source) &&
            occursin("stable_widget_surface_release.schema.json", surface_release_audit_source) &&
            occursin("readiness_consistency_failures", surface_release_audit_source) &&
            occursin("release_ready must match coverage, stability, and family closeout readiness", surface_release_audit_source) &&
            occursin("coverage_release_ready must match coverage_complete, git_available, and git_dirty", surface_release_audit_source) &&
            occursin("stability_complete must match stability_blocked", surface_release_audit_source) &&
            occursin("family_closeout_complete must match family_closeout_blocked", surface_release_audit_source) ||
            push!(failures, "stable widget surface release schema audit must validate generated JSON keys and readiness consistency")
    end
    if isfile(STABLE_WIDGET_SURFACE_RELEASE_SCHEMA_AUDIT_TEST)
        surface_release_audit_test_source = read(STABLE_WIDGET_SURFACE_RELEASE_SCHEMA_AUDIT_TEST, String)
        occursin("StableWidgetSurfaceReleaseSchemaAudit.audit()", surface_release_audit_test_source) &&
            occursin("stable_widget_surface_release_schema_audit.jl", surface_release_audit_test_source) &&
            occursin("key_contract_failures", surface_release_audit_test_source) &&
            occursin("readiness_consistency_failures", surface_release_audit_test_source) &&
            occursin("release_ready must match coverage, stability, and family closeout readiness", surface_release_audit_test_source) &&
            occursin("stability_complete must match stability_blocked", surface_release_audit_test_source) &&
            occursin("generated JSON is missing schema key `git_commit`", surface_release_audit_test_source) ||
            push!(failures, "stable widget surface release schema audit tests must cover help, contract keys, and readiness consistency errors")
    end
    isfile(widget_catalog_render_script) || push!(failures, "missing stable widget catalog render script: scripts/render_widget_catalog.jl")
    if isfile(widget_catalog_render_script)
        render_source = read(widget_catalog_render_script, String)
        occursin("module WidgetCatalogRender", render_source) &&
            occursin("widget_catalog_markdown", render_source) &&
            occursin("widget_catalog_tsv", render_source) &&
            occursin("widget_catalog_summary", render_source) &&
            occursin("widget_names_text", render_source) &&
            occursin("search_widget_names_text", render_source) &&
            occursin("widget_source_files_text", render_source) &&
            occursin("search_widget_source_files_text", render_source) &&
            occursin("widget_source_summary_markdown", render_source) &&
            occursin("widget_source_summary_tsv", render_source) &&
            occursin("widget_coverage_records_markdown", render_source) &&
            occursin("widget_coverage_gaps_markdown", render_source) &&
            occursin("widget_coverage_records_tsv", render_source) &&
            occursin("widget_coverage_gaps_tsv", render_source) &&
            occursin("widget_coverage_issue_markdown", render_source) &&
            occursin("widget_coverage_issue_tsv", render_source) &&
            occursin("widget_coverage_summary_markdown", render_source) &&
            occursin("widget_coverage_summary_text", render_source) &&
            occursin("widget_coverage_release_status_text", render_source) &&
            occursin("widget_coverage_summary_tsv", render_source) &&
            occursin("widget_stability_markdown", render_source) &&
            occursin("widget_stability_tsv", render_source) &&
            occursin("widget_stability_gaps_markdown", render_source) &&
            occursin("widget_stability_gaps_tsv", render_source) &&
            occursin("widget_stability_summary_markdown", render_source) &&
            occursin("widget_stability_summary_tsv", render_source) &&
            occursin("widget_stability_summary_text", render_source) &&
            occursin("widget_stability_json", render_source) &&
            occursin("widget_stability_gaps", render_source) &&
            occursin("widget_surface_release_status_text", render_source) &&
            occursin("widget_surface_release_status_json", render_source) &&
            occursin("assert_widget_surface_release_ready", render_source) &&
            occursin("widget_vocabulary_markdown", render_source) &&
            occursin("widget_vocabulary_tsv", render_source) &&
            occursin("widget_vocabulary_widget_names", render_source) &&
            occursin("assert_widget_coverage_clean_git", render_source) &&
            occursin("assert_widget_coverage_release_ready", render_source) &&
            occursin("expected release-ready stable widget coverage evidence", render_source) &&
            occursin("expected promotion-ready stable widgets", render_source) &&
            occursin("expected release-ready stable widget surface", render_source) &&
            occursin("stable_widget_count", render_source) &&
            occursin("search_widget_count", render_source) &&
            occursin("--format", render_source) &&
            occursin("--count", render_source) &&
            occursin("--min-count", render_source) &&
            occursin("--max-count", render_source) &&
            occursin("--require-complete-coverage", render_source) &&
            occursin("--require-stability-ready", render_source) &&
            occursin("--require-stabilization-ready", render_source) &&
            occursin("--require-clean-git", render_source) &&
            occursin("--names", render_source) &&
            occursin("--sources", render_source) &&
            occursin("--summary", render_source) &&
            occursin("--source-summary", render_source) &&
            occursin("--coverage", render_source) &&
            occursin("--coverage-gaps", render_source) &&
            occursin("--coverage-summary", render_source) &&
            occursin("--coverage-status", render_source) &&
            occursin("--coverage-issue", render_source) &&
            occursin("--coverage-issue-names", render_source) &&
            occursin("--stability", render_source) &&
            occursin("--stability-json", render_source) &&
            occursin("--stability-gaps", render_source) &&
            occursin("--stability-summary", render_source) &&
            occursin("--stability-status", render_source) &&
            occursin("--stabilization-status", render_source) &&
            occursin("--stabilization-json", render_source) &&
            occursin("--surface-release-status", render_source) &&
            occursin("--surface-release-json", render_source) &&
            occursin("--require-surface-release-ready", render_source) &&
            occursin("--vocabulary", render_source) &&
            occursin("--vocabulary-widgets", render_source) &&
            occursin("--vocabulary-widgets requires --query", render_source) &&
            occursin("--query", render_source) &&
            occursin("--append", render_source) &&
            occursin("--no-header", render_source) &&
            occursin("mkpath", render_source) &&
            occursin("--columns", render_source) &&
            occursin("--status", render_source) &&
            occursin("--surface", render_source) &&
            occursin("--output", render_source) ||
            push!(failures, "scripts/render_widget_catalog.jl must render the stable widget catalog as configurable Markdown or TSV")
    end
    isfile(WIDGET_CATALOG_RENDER_TEST) || push!(failures, "missing stable widget catalog render tests: test/widget_catalog_render.jl")
    isfile(family_closeout_render_script) || push!(failures, "missing widget family closeout render script: scripts/render_widget_family_closeout.jl")
    if isfile(family_closeout_render_script)
        closeout_source = read(family_closeout_render_script, String)
        occursin("module WidgetFamilyCloseoutRender", closeout_source) &&
            occursin("WidgetFamilyEvidenceAudit", closeout_source) &&
            occursin("FamilyCloseoutRow", closeout_source) &&
            occursin("closeout_rows", closeout_source) &&
            occursin("filter_rows", closeout_source) &&
            occursin("render_markdown", closeout_source) &&
            occursin("render_tsv", closeout_source) &&
            occursin("render_json", closeout_source) &&
            occursin("json_string", closeout_source) &&
            occursin("_json_escape", closeout_source) &&
            occursin("schema_version", closeout_source) &&
            occursin("metadata", closeout_source) &&
            occursin("generated_at", closeout_source) &&
            occursin("git_commit", closeout_source) &&
            occursin("git_dirty", closeout_source) &&
            occursin("status --porcelain", closeout_source) &&
            occursin("rev-parse HEAD", closeout_source) &&
            occursin("\"families\"", closeout_source) &&
            occursin("--family", closeout_source) &&
            occursin("--status", closeout_source) &&
            occursin("parse_status", closeout_source) &&
            occursin("--status must be ready, blocked, or all", closeout_source) &&
            occursin("--format", closeout_source) &&
            occursin("--columns", closeout_source) &&
            occursin("--count", closeout_source) &&
            occursin("--summary", closeout_source) &&
            occursin("render_summary", closeout_source) &&
            occursin("summary_rows", closeout_source) &&
            occursin("summary_counts", closeout_source) &&
            occursin("--release-check", closeout_source) &&
            occursin("--require-total-count", closeout_source) &&
            occursin("--require-clean-git", closeout_source) &&
            occursin("--require-ready-count", closeout_source) &&
            occursin("--require-blocked-count", closeout_source) &&
            occursin("parse_nonnegative_integer", closeout_source) &&
            occursin("total", closeout_source) &&
            occursin("--require-ready", closeout_source) &&
            occursin("--output", closeout_source) &&
            occursin("--no-header", closeout_source) &&
            occursin("blocker_details", closeout_source) &&
            occursin("blocked_rows", closeout_source) &&
            occursin("ready", closeout_source) &&
            occursin("blocked", closeout_source) ||
            push!(failures, "scripts/render_widget_family_closeout.jl must render family stabilization closeout evidence as configurable Markdown or TSV")
    end
    isfile(family_closeout_render_test) || push!(failures, "missing widget family closeout render tests: test/widget_family_closeout_render.jl")
    occursin("source_file_status", source) &&
        occursin("source_root", source) &&
        occursin("missing widget source file", source) &&
        occursin("widget source path must point to a Julia source file", source) ||
        push!(failures, "stable widget candidate audit must reject missing, escaping, or non-Julia source paths")
    if isfile(STABLE_WIDGET_CANDIDATES_TEST)
        stable_widget_candidate_test_source = read(STABLE_WIDGET_CANDIDATES_TEST, String)
        occursin("missing_source_widget_coverage.tsv", stable_widget_candidate_test_source) &&
            occursin("escaping_source_widget_coverage.tsv", stable_widget_candidate_test_source) &&
            occursin("non_julia_source_widget_coverage.tsv", stable_widget_candidate_test_source) ||
            push!(failures, "stable widget candidate tests must cover missing, escaping, and non-Julia source paths")
    end
    occursin("WidgetStabilizationGate", gate_source) &&
        occursin("widget_audit.jl", gate_source) &&
        occursin("--require-complete", gate_source) &&
        occursin("stable_widget_candidates.jl", gate_source) &&
        occursin("--require-stable", gate_source) &&
        occursin("public_widget_candidate_audit.jl", gate_source) &&
        occursin("public widget candidate audit", gate_source) &&
        occursin("widget_family_evidence_audit.jl", gate_source) &&
        occursin("experimental_promotion_audit.jl", gate_source) &&
        occursin("compatibility_widget_alias_audit.jl", gate_source) &&
        occursin("stable_promotion_packet_audit.jl", gate_source) &&
        occursin("render_widget_catalog.jl", gate_source) &&
        occursin("stable_widget_stabilization_schema_audit.jl", gate_source) &&
        occursin("stable widget stabilization schema audit", gate_source) &&
        occursin("stable widget stabilization readiness", gate_source) &&
        occursin("--stabilization-status", gate_source) &&
        occursin("--require-stabilization-ready", gate_source) &&
        occursin("stable_widget_surface_release_schema_audit.jl", gate_source) &&
        occursin("stable widget surface release schema audit", gate_source) &&
        occursin("stable widget surface release readiness", gate_source) &&
        occursin("--surface-release-status", gate_source) &&
        occursin("--require-surface-release-ready", gate_source) &&
        occursin("--coverage-summary", gate_source) &&
        occursin("--require-complete-coverage", gate_source) &&
        occursin("--require-clean-git", gate_source) &&
        occursin("reference_parity_matrix_schema_audit.jl", gate_source) &&
        occursin("reference parity matrix release check", gate_source) ||
        push!(failures, "widget stabilization gate must run widget coverage, stable candidate, public widget candidate, widget family evidence, experimental promotion, compatibility alias, stable promotion packet, release coverage-completeness, and reference parity release checks")
    isfile(WIDGET_STABILIZATION_GATE_TEST) || push!(failures, "missing widget stabilization gate tests: test/widget_stabilization_gate.jl")
    if isfile(WIDGET_STABILIZATION_GATE_TEST)
        gate_test_source = read(WIDGET_STABILIZATION_GATE_TEST, String)
        occursin("WidgetStabilizationGate.main([\"--list\"])", gate_test_source) &&
            occursin("widget coverage audit", gate_test_source) &&
            occursin("stable widget candidate audit", gate_test_source) &&
            occursin("public widget candidate audit", gate_test_source) &&
            occursin("widget family evidence audit", gate_test_source) &&
            occursin("experimental promotion audit", gate_test_source) &&
            occursin("compatibility widget alias audit", gate_test_source) &&
            occursin("stable promotion packet audit", gate_test_source) &&
            occursin("stable widget stabilization schema audit", gate_test_source) &&
            occursin("scripts/stable_widget_stabilization_schema_audit.jl", gate_test_source) &&
            occursin("stable widget stabilization readiness", gate_test_source) &&
            occursin("scripts/render_widget_catalog.jl --stabilization-status --require-stabilization-ready", gate_test_source) &&
            occursin("stable widget surface release schema audit", gate_test_source) &&
            occursin("scripts/stable_widget_surface_release_schema_audit.jl", gate_test_source) &&
            occursin("stable widget surface release readiness", gate_test_source) &&
            occursin("scripts/render_widget_catalog.jl --surface-release-status --require-surface-release-ready", gate_test_source) &&
            occursin("stable widget coverage completeness", gate_test_source) &&
            occursin("reference parity matrix release check", gate_test_source) &&
            occursin("scripts/render_widget_catalog.jl --coverage-summary --format tsv --require-complete-coverage --require-clean-git", gate_test_source) ||
            push!(failures, "widget stabilization gate tests must cover the non-executing list path and every required sub-audit including public widget candidate and reference parity release checks")
    end
    isfile(family_evidence_ledger) || push!(failures, "missing widget family evidence ledger: api/widget_family_evidence.tsv")
    isfile(family_evidence_doc) || push!(failures, "missing widget family evidence documentation: docs/WIDGET_FAMILY_EVIDENCE.md")
    if isfile(family_evidence_doc)
        family_doc_source = read(family_evidence_doc, String)
        occursin("stable_api_tokens", family_doc_source) &&
            occursin("precompile_tokens", family_doc_source) &&
            occursin("example_family_labels", family_doc_source) &&
            occursin("duplicate values", family_doc_source) &&
            occursin("At least three distinct", family_doc_source) &&
            occursin("Token matching", family_doc_source) &&
            occursin("OtherWidgets.Column", family_doc_source) &&
            occursin("pulse_services!x", family_doc_source) &&
            occursin("Helper functions may be included", family_doc_source) &&
            occursin("at least three type-backed", family_doc_source) &&
            occursin("Testing-family helper tokens", family_doc_source) &&
            occursin("assert_semantic_snapshot", family_doc_source) &&
            occursin("assert_semantic_query", family_doc_source) &&
            occursin("valid supplemental", family_doc_source) &&
            occursin("Each type-backed `stable_api_token` has a matching `precompile_token`", family_doc_source) &&
            occursin("same final segment", family_doc_source) &&
            occursin("Widgets.TextInput` does not prove startup coverage for `SearchInput", family_doc_source) &&
            occursin("set -euo pipefail", family_doc_source) &&
            occursin("release-evidence/widget-family/commit.txt", family_doc_source) &&
            occursin("git rev-parse HEAD", family_doc_source) &&
            occursin("release-evidence/widget-family/julia-version.txt", family_doc_source) &&
            occursin("julia --version", family_doc_source) &&
            occursin("release-evidence/widget-family/uname.txt", family_doc_source) &&
            occursin("uname -a", family_doc_source) &&
            occursin("sha256sum release-evidence/widget-family/widget_family_evidence.tsv", family_doc_source) &&
            occursin("sha256sum --check release-evidence/widget-family/widget_family_evidence.sha256", family_doc_source) &&
            occursin("widget_family_evidence.sha256.check", family_doc_source) &&
            occursin("widget_family_evidence.sha256", family_doc_source) &&
            occursin("release-evidence/widget-family/widget_family_evidence.tsv", family_doc_source) &&
            occursin("widget_family_evidence_audit.stdout.txt", family_doc_source) &&
            occursin("widget_family_evidence_audit.stderr.txt", family_doc_source) &&
            occursin("widget_family_evidence_audit.status", family_doc_source) &&
            occursin("exit_status=%s", family_doc_source) &&
            occursin("release-evidence/widget-family/manifest.txt", family_doc_source) &&
            occursin("find release-evidence/widget-family -maxdepth 1 -type f", family_doc_source) &&
            occursin("Reviewers should check", family_doc_source) &&
            occursin("release-evidence/widget-family/recorded-at.txt", family_doc_source) &&
            occursin("date -u +%Y-%m-%dT%H:%M:%SZ", family_doc_source) &&
            occursin("exit_status=0", family_doc_source) &&
            occursin("stderr.txt", family_doc_source) &&
            occursin("scripts/widget_family_evidence_audit.jl", family_doc_source) || push!(failures, "widget family evidence documentation must describe ledger columns and audit command")
    end
    docs_index_path = joinpath(ROOT, "docs", "README.md")
    api_reference_path = joinpath(ROOT, "docs", "API_REFERENCE.md")
    api_facades_path = joinpath(ROOT, "docs", "API_FACADES.md")
    api_stabilization_path = joinpath(ROOT, "docs", "API_STABILIZATION.md")
    stabilization_doc_path = joinpath(ROOT, "docs", "WIDGET_STABILIZATION.md")
    stable_promotion_template_path = joinpath(ROOT, "docs", "STABLE_PROMOTION_PACKET_TEMPLATE.md")
    stable_promotion_records_path = joinpath(ROOT, "docs", "stable-promotion-packets", "README.md")
    developer_guide_path = joinpath(ROOT, "docs", "DEVELOPER_GUIDE.md")
    release_checklist_path = joinpath(ROOT, "docs", "RELEASE_CHECKLIST.md")
    validation_strategy_path = joinpath(ROOT, "docs", "VALIDATION_STRATEGY.md")
    release_evidence_path = joinpath(ROOT, "docs", "RELEASE_EVIDENCE.md")
    docs_make_path = joinpath(ROOT, "docs", "make.jl")
    if isfile(docs_index_path)
        docs_index_source = read(docs_index_path, String)
        occursin("WIDGET_FAMILY_EVIDENCE.md", docs_index_source) ||
            push!(failures, "docs/README.md must link docs/WIDGET_FAMILY_EVIDENCE.md")
        occursin("STABLE_PROMOTION_PACKET_TEMPLATE.md", docs_index_source) ||
            push!(failures, "docs/README.md must link docs/STABLE_PROMOTION_PACKET_TEMPLATE.md")
        occursin("stable-promotion-packets/README.md", docs_index_source) ||
            push!(failures, "docs/README.md must link docs/stable-promotion-packets/README.md")
    end
    if isfile(api_facades_path)
        api_facades_source = read(api_facades_path, String)
        occursin("pilot_semantic_tree", api_facades_source) &&
            occursin("pilot_semantic_snapshot", api_facades_source) &&
            occursin("assert_semantic_snapshot", api_facades_source) &&
            occursin("assert_semantic_query", api_facades_source) &&
            occursin("query_one_semantic", api_facades_source) &&
            occursin("WidgetPilot", api_facades_source) &&
            occursin("Wicked.API", api_facades_source) ||
            push!(failures, "docs/API_FACADES.md must document stable pilot semantic assertion helpers on Wicked.API")
            occursin("stable_widget_catalog", api_facades_source) &&
            occursin("stable_widget_count", api_facades_source) &&
            occursin("stable_widget_names", api_facades_source) &&
            occursin("widget_names_text", api_facades_source) &&
            occursin("search_widget_names_text", api_facades_source) &&
            occursin("widget_source_files", api_facades_source) &&
            occursin("widget_source_files_text", api_facades_source) &&
            occursin("search_widget_source_files_text", api_facades_source) &&
            occursin("widget_source_summary", api_facades_source) &&
            occursin("widget_source_summary_markdown", api_facades_source) &&
            occursin("widget_source_summary_tsv", api_facades_source) &&
            occursin("search_widgets", api_facades_source) &&
            occursin("search_widget_count", api_facades_source) &&
            occursin("search_widget_catalog_markdown", api_facades_source) &&
            occursin("search_widget_catalog_tsv", api_facades_source) &&
            occursin("group_widgets", api_facades_source) &&
            occursin("widget_catalog_summary", api_facades_source) &&
            occursin("widget_catalog_markdown", api_facades_source) &&
            occursin("widget_vocabulary", api_facades_source) &&
            occursin("search_widget_vocabulary", api_facades_source) &&
            occursin("widget_vocabulary_widget_names", api_facades_source) &&
            occursin("WidgetFamilyCloseoutReport", api_facades_source) &&
            occursin("widget_family_closeout_reports", api_facades_source) &&
            occursin("widget_family_closeout_gaps", api_facades_source) &&
            occursin("widget_family_closeout_summary", api_facades_source) &&
            occursin("widget_family_closeout_complete", api_facades_source) &&
            occursin("assert_widget_family_closeout_complete", api_facades_source) &&
            occursin("widget_family_closeout_markdown", api_facades_source) &&
            occursin("widget_family_closeout_tsv", api_facades_source) &&
            occursin("widget_surface_release_status_record", api_facades_source) &&
            occursin("widget_surface_release_ready", api_facades_source) &&
            occursin("assert_widget_surface_release_ready", api_facades_source) &&
            occursin("widget_surface_release_status_text", api_facades_source) &&
            occursin("widget_surface_release_status_json", api_facades_source) &&
            occursin("widget_catalog_records", api_facades_source) &&
            occursin("widget_catalog_tsv", api_facades_source) &&
            occursin("columns=:name", api_facades_source) &&
            occursin("scripts/render_widget_catalog.jl", api_facades_source) &&
            occursin("--format markdown", api_facades_source) &&
            occursin("--format tsv", api_facades_source) &&
            occursin("--count", api_facades_source) &&
            occursin("--min-count 1", api_facades_source) &&
            occursin("--max-count 20", api_facades_source) &&
            occursin("--names", api_facades_source) &&
            occursin("--sources", api_facades_source) &&
            occursin("--query button", api_facades_source) &&
            occursin("--summary", api_facades_source) &&
            occursin("--source-summary", api_facades_source) &&
            occursin("--require-clean-git", api_facades_source) &&
            occursin("--query button", api_facades_source) &&
            occursin("--append", api_facades_source) &&
            occursin("--no-header", api_facades_source) &&
            occursin("created automatically", api_facades_source) &&
            occursin("scripts/render_widget_family_closeout.jl", api_facades_source) &&
            occursin("--family toolkit", api_facades_source) &&
            occursin("--require-ready", api_facades_source) &&
            occursin("blocker-count, and blocker-detail", api_facades_source) &&
            occursin("widget instances", api_facades_source) &&
            occursin("is_stable_widget", api_facades_source) &&
            occursin("widget_catalog_entry", api_facades_source) ||
            push!(failures, "docs/API_FACADES.md must document stable widget catalog helpers and family closeout renderer")
    end
    if isfile(api_reference_path)
        api_reference_source = read(api_reference_path, String)
        occursin("stable_widget_catalog", api_reference_source) &&
            occursin("stable_widget_count", api_reference_source) &&
            occursin("stable_widget_names", api_reference_source) &&
            occursin("widget_names_text", api_reference_source) &&
            occursin("search_widget_names_text", api_reference_source) &&
            occursin("widget_source_files", api_reference_source) &&
            occursin("widget_source_files_text", api_reference_source) &&
            occursin("search_widget_source_files_text", api_reference_source) &&
            occursin("widget_source_summary", api_reference_source) &&
            occursin("widget_source_summary_markdown", api_reference_source) &&
            occursin("widget_source_summary_tsv", api_reference_source) &&
            occursin("search_widgets", api_reference_source) &&
            occursin("search_widget_count", api_reference_source) &&
            occursin("search_widget_catalog_markdown", api_reference_source) &&
            occursin("search_widget_catalog_tsv", api_reference_source) &&
            occursin("group_widgets", api_reference_source) &&
            occursin("widget_catalog_summary", api_reference_source) &&
            occursin("widget_catalog_markdown", api_reference_source) &&
            occursin("widget_vocabulary", api_reference_source) &&
            occursin("search_widget_vocabulary", api_reference_source) &&
            occursin("widget_vocabulary_widget_names", api_reference_source) &&
            occursin("WidgetFamilyCloseoutReport", api_reference_source) &&
            occursin("widget_family_closeout_reports", api_reference_source) &&
            occursin("widget_family_closeout_gaps", api_reference_source) &&
            occursin("widget_family_closeout_summary", api_reference_source) &&
            occursin("widget_family_closeout_complete", api_reference_source) &&
            occursin("assert_widget_family_closeout_complete", api_reference_source) &&
            occursin("widget_stability_complete", api_reference_source) &&
            occursin("assert_widget_stability_complete", api_reference_source) &&
            occursin("widget_stability_summary", api_reference_source) &&
            occursin("widget_stability_summary_records", api_reference_source) &&
            occursin("widget_stability_summary_markdown", api_reference_source) &&
            occursin("widget_stability_summary_tsv", api_reference_source) &&
            occursin("widget_stability_summary_text", api_reference_source) &&
            occursin("widget_surface_release_status_record", api_reference_source) &&
            occursin("widget_surface_release_ready", api_reference_source) &&
            occursin("assert_widget_surface_release_ready", api_reference_source) &&
            occursin("widget_surface_release_status_text", api_reference_source) &&
            occursin("widget_surface_release_status_json", api_reference_source) &&
            occursin("widget_family_closeout_markdown", api_reference_source) &&
            occursin("widget_family_closeout_tsv", api_reference_source) &&
            occursin("widget_catalog_records", api_reference_source) &&
            occursin("widget_catalog_tsv", api_reference_source) &&
            occursin("columns=:name", api_reference_source) &&
            occursin("widget instances", api_reference_source) &&
            occursin("widget_catalog_entry", api_reference_source) ||
            push!(failures, "docs/API_REFERENCE.md must document stable widget catalog discovery helpers")
    end
    wicked_source_path = joinpath(ROOT, "src", "Wicked.jl")
    if isfile(wicked_source_path)
        wicked_source = read(wicked_source_path, String)
        occursin("import .SemanticToolkit: query_semantics", wicked_source) &&
            occursin("query_one_semantic", wicked_source) &&
            occursin("pilot::Union{WidgetPilot,ToolkitPilot}", wicked_source) ||
            push!(failures, "src/Wicked.jl must explicitly import semantic query functions before adding pilot overloads")
    end
    semantics_testing_path = joinpath(ROOT, "docs", "API_SEMANTICS_TESTING.md")
    if isfile(semantics_testing_path)
        semantics_testing_source = read(semantics_testing_path, String)
        occursin("query_one_semantic(tree; role=ButtonRole)", semantics_testing_source) &&
            occursin("query_semantics(tree; id=\"submit\", enabled=true, focusable=true)", semantics_testing_source) &&
            occursin("description", semantics_testing_source) &&
            occursin("bounds=SemanticRect", semantics_testing_source) &&
            occursin("actions=[ActivateSemanticAction, FocusSemanticAction]", semantics_testing_source) &&
            occursin("metadata=Dict(:key => value)", semantics_testing_source) &&
            occursin("value_now", semantics_testing_source) &&
            occursin("hidden=true", semantics_testing_source) &&
            occursin("active filters", semantics_testing_source) &&
            occursin("compact `SemanticQuery`", semantics_testing_source) &&
            occursin("minimum=2", semantics_testing_source) &&
            occursin("maximum=1", semantics_testing_source) &&
            occursin("assertion options, not", semantics_testing_source) &&
            occursin("assert_semantic_query(tree; role=ButtonRole)", semantics_testing_source) &&
            occursin("pass an explicit `SemanticQuery`", semantics_testing_source) &&
            occursin("pilot_semantic_tree", semantics_testing_source) &&
            !occursin("count=nothing, minimum=2", semantics_testing_source) &&
            occursin("assert_semantic_query", semantics_testing_source) &&
            occursin("SemanticPilot", semantics_testing_source) &&
            occursin("matching semantic IDs", semantics_testing_source) ||
            push!(failures, "docs/API_SEMANTICS_TESTING.md must document keyword semantic-tree queries, SemanticPilot queries, and query-one error diagnostics")
    end
    if isfile(README)
        readme_source = read(README, String)
        occursin("WidgetPilot", readme_source) &&
            occursin("ToolkitPilot", readme_source) &&
            occursin("RuntimePilot", readme_source) &&
            occursin("pilot_semantic_tree", readme_source) &&
            occursin("pilot_semantic_snapshot", readme_source) &&
            occursin("SemanticQuery", readme_source) &&
            occursin("query_semantics", readme_source) &&
            occursin("query_one_semantic", readme_source) &&
        occursin("assert_semantic_query", readme_source) &&
            occursin("assert_semantic_snapshot", readme_source) ||
            push!(failures, "README.md must document stable pilot semantic testing helpers")
        occursin("stable_widget_catalog", readme_source) &&
            occursin("stable_widget_count", readme_source) &&
            occursin("stable_widget_names", readme_source) &&
            occursin("widget_names_text", readme_source) &&
            occursin("search_widget_names_text", readme_source) &&
            occursin("widget_source_files", readme_source) &&
            occursin("widget_source_files_text", readme_source) &&
            occursin("search_widget_source_files_text", readme_source) &&
            occursin("widget_source_summary", readme_source) &&
            occursin("widget_source_summary_markdown", readme_source) &&
            occursin("widget_source_summary_tsv", readme_source) &&
            occursin("search_widgets", readme_source) &&
            occursin("search_widget_count", readme_source) &&
            occursin("search_widget_catalog_markdown", readme_source) &&
            occursin("search_widget_catalog_tsv", readme_source) &&
            occursin("group_widgets", readme_source) &&
            occursin("widget_catalog_summary", readme_source) &&
            occursin("widget_catalog_markdown", readme_source) &&
            occursin("widget_vocabulary", readme_source) &&
            occursin("search_widget_vocabulary", readme_source) &&
            occursin("widget_vocabulary_widget_names", readme_source) &&
            occursin("WidgetFamilyCloseoutReport", readme_source) &&
            occursin("widget_family_closeout_reports", readme_source) &&
            occursin("widget_family_closeout_gaps", readme_source) &&
            occursin("widget_family_closeout_summary", readme_source) &&
            occursin("widget_family_closeout_complete", readme_source) &&
            occursin("assert_widget_family_closeout_complete", readme_source) &&
            occursin("widget_stability_complete", readme_source) &&
            occursin("assert_widget_stability_complete", readme_source) &&
            occursin("widget_stability_summary", readme_source) &&
            occursin("widget_stability_summary_text", readme_source) &&
            occursin("widget_surface_release_status_record", readme_source) &&
            occursin("widget_surface_release_ready", readme_source) &&
            occursin("assert_widget_surface_release_ready", readme_source) &&
            occursin("widget_surface_release_status_text", readme_source) &&
            occursin("widget_surface_release_status_json", readme_source) &&
            occursin("--vocabulary", readme_source) &&
            occursin("--vocabulary-widgets", readme_source) &&
            occursin("widget_catalog_records", readme_source) &&
            occursin("widget_catalog_tsv", readme_source) &&
            occursin("columns=:name", readme_source) &&
            occursin("scripts/render_widget_catalog.jl", readme_source) &&
            occursin("--format markdown", readme_source) &&
            occursin("--count", readme_source) &&
            occursin("--min-count 1", readme_source) &&
            occursin("--max-count 20", readme_source) &&
            occursin("--names --output stable-widget-names.txt", readme_source) &&
            occursin("--sources --output stable-widget-sources.txt", readme_source) &&
            occursin("--sources --query button", readme_source) &&
            occursin("--names --query button", readme_source) &&
            occursin("--query button", readme_source) &&
            occursin("--summary --format tsv", readme_source) &&
            occursin("--source-summary --format markdown", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --format markdown", readme_source) &&
            occursin("scripts/render_widget_catalog.jl --stability-summary --format tsv", readme_source) &&
            occursin("scripts/render_widget_catalog.jl --stability-status", readme_source) &&
            occursin("scripts/render_widget_catalog.jl --stabilization-blockers", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --status blocked", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --format json", readme_source) &&
            occursin("blocker_details", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --summary --format tsv", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --release-check --require-total-count", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --require-ready", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --require-clean-git", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --require-total-count \"\$(julia --project=. scripts/render_widget_family_closeout.jl --count)\"", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --require-blocked-count 0", readme_source) &&
            occursin("scripts/render_widget_family_closeout.jl --count --family toolkit", readme_source) &&
            occursin("--format tsv --no-header", readme_source) &&
            occursin("--append", readme_source) &&
            occursin("is_stable_widget(Button(\"Run\", :run))", readme_source) &&
            occursin("is_stable_widget", readme_source) &&
            occursin("widget_catalog_entry", readme_source) &&
            occursin("WidgetCatalogEntry", readme_source) ||
            push!(failures, "README.md must document stable widget catalog discovery helpers")
        occursin("scripts/new_stable_promotion_packet.jl", readme_source) &&
            occursin("STABLE_PROMOTION_PACKET_TEMPLATE.md", readme_source) ||
            push!(failures, "README.md must document stable promotion packet scaffold and template")
    end
    if isfile(stabilization_doc_path)
        stabilization_source = read(stabilization_doc_path, String)
        occursin("WIDGET_FAMILY_EVIDENCE.md", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must link docs/WIDGET_FAMILY_EVIDENCE.md")
        occursin("STABLE_PROMOTION_PACKET_TEMPLATE.md", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must link docs/STABLE_PROMOTION_PACKET_TEMPLATE.md")
        occursin("scripts/new_stable_promotion_packet.jl", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document stable promotion packet scaffold command")
            occursin("scripts/stable_promotion_packet_audit.jl", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document stable promotion packet audit command")
        occursin("scripts/render_widget_family_closeout.jl --family <family>", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document the widget family closeout renderer in the family closeout loop")
        occursin("scripts/render_widget_family_closeout.jl --status blocked", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document blocked-family closeout filtering")
        occursin("blocker counts", stabilization_source) &&
            occursin("details with", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document blocker detail reporting for widget family closeout")
        occursin("--require-ready", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document require-ready mode for widget family closeout")
        occursin("--release-check", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document release-check mode for widget family closeout")
        occursin("--summary --format tsv", stabilization_source) &&
            occursin("total/ready/blocked", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document summary mode for widget family closeout")
        occursin("--format json", stabilization_source) &&
            occursin("machine-readable", stabilization_source) &&
            occursin("schema_version", stabilization_source) &&
            occursin("metadata", stabilization_source) &&
            occursin("metadata.git_commit", stabilization_source) &&
            occursin("metadata.git_dirty", stabilization_source) &&
            occursin("families", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document JSON mode for widget family closeout")
        occursin("--require-blocked-count 0", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document exact blocked-count assertion for widget family closeout")
        occursin("--require-clean-git", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document clean-git assertion for widget family closeout")
        occursin("--require-total-count", stabilization_source) &&
            occursin("--count", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must document derived total-count assertion for widget family closeout")
        occursin("Stable promotion packet", stabilization_source) &&
            occursin("Public API decision", stabilization_source) &&
            occursin("Behavior evidence", stabilization_source) &&
            occursin("Promotion evidence", stabilization_source) &&
            occursin("A `proposed` row documents", stabilization_source) &&
            occursin("Developer evidence", stabilization_source) &&
            occursin("Family evidence", stabilization_source) &&
            occursin("Startup evidence", stabilization_source) &&
            occursin("Compatibility evidence", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must define the stable widget promotion packet")
        occursin("Every type-backed `stable_api_token`", stabilization_source) &&
            occursin("must also have a matching", stabilization_source) &&
            occursin("same final segment", stabilization_source) &&
            occursin("matching precompile token for each type-backed stable API token", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must require matching precompile tokens for type-backed stable API tokens")
        occursin("repository-relative path to a checked-in `.jl`", stabilization_source) &&
            occursin("non-Julia files", stabilization_source) &&
            occursin("Source file is traceable", stabilization_source) ||
            push!(failures, "docs/WIDGET_STABILIZATION.md must require traceable Julia source paths for widget promotion evidence")
    end
    isfile(stable_promotion_template_path) || push!(failures, "missing stable promotion packet template: docs/STABLE_PROMOTION_PACKET_TEMPLATE.md")
    if isfile(stable_promotion_template_path)
        template_source = read(stable_promotion_template_path, String)
        occursin("Public API decision", template_source) &&
            occursin("Behavior evidence", template_source) &&
            occursin("Promotion evidence", template_source) &&
            occursin("Developer evidence", template_source) &&
            occursin("Family and startup evidence", template_source) &&
            occursin("Compatibility and release evidence", template_source) &&
            occursin("accepted", template_source) &&
            occursin("completed", template_source) &&
            occursin("api/widget_promotion_requirements.tsv", template_source) &&
            occursin("matching precompile coverage", template_source) &&
            occursin("scripts/pilot_evidence_package_audit.jl", template_source) &&
            occursin("Pilot evidence package checked", template_source) &&
            occursin("Package-level pilot evidence reports", template_source) &&
            occursin("Stable facade usage with no Wicked internals", template_source) &&
            occursin("write_pilot_evidence_package", template_source) &&
            occursin("write_pilot_evidence_package_reports", template_source) ||
            push!(failures, "docs/STABLE_PROMOTION_PACKET_TEMPLATE.md must cover API, behavior, promotion requirements, promotion, developer, stable facade usage, family/startup, compatibility, accepted/completed review, matching precompile evidence, and pilot evidence package artifacts")
    end
    isfile(stable_promotion_records_path) || push!(failures, "missing stable promotion packet records README: docs/stable-promotion-packets/README.md")
    if isfile(stable_promotion_records_path)
        records_source = read(stable_promotion_records_path, String)
        occursin("scripts/new_stable_promotion_packet.jl", records_source) &&
            occursin("scripts/stable_promotion_packet_audit.jl", records_source) &&
            occursin("scripts/pilot_evidence_package_audit.jl", records_source) &&
            occursin("write_pilot_evidence_package", records_source) &&
            occursin("write_pilot_evidence_package_reports", records_source) &&
            occursin("Stable facade usage with no Wicked internals", records_source) &&
            occursin("--require-complete", records_source) &&
            occursin("Wicked.Experimental", records_source) ||
            push!(failures, "docs/stable-promotion-packets/README.md must document scaffold, audit, complete mode, pilot evidence packages, stable facade usage, and experimental review policy")
    end
    if isfile(CONTINUOUS_INTEGRATION_DOC)
        ci_doc_source = read(CONTINUOUS_INTEGRATION_DOC, String)
        occursin("scripts/widget_stabilization_gate.jl", ci_doc_source) &&
        occursin("stable promotion packet audit", ci_doc_source) &&
        occursin("stable widget-surface release schema", ci_doc_source) &&
        occursin("ci-artifacts/stable-widget-surface-release.json", ci_doc_source) &&
        occursin("scripts/stable_widget_surface_release_schema_audit.jl", ci_doc_source) &&
        occursin("--require-complete-coverage", ci_doc_source) &&
            occursin("--require-stability-ready", ci_doc_source) &&
        occursin("--require-clean-git", ci_doc_source) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document stable promotion packet audit and release coverage completeness in the widget stabilization gate")
        occursin("scripts/render_widget_family_closeout.jl", ci_doc_source) &&
            occursin("Markdown, TSV, or JSON planning artifact", ci_doc_source) &&
            occursin("blocker details", ci_doc_source) &&
            occursin("ci-artifacts/widget-family-closeout.json", ci_doc_source) &&
            occursin("stable-widget-coverage-", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-status.txt", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-summary.tsv", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-summary.json", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-gaps.md", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-missing-records.md", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-missing-record-names.txt", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-source-mismatches.md", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-source-mismatch-names.txt", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-missing-checks.md", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-coverage-missing-check-names.txt", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-stability.md", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-stability-gaps.md", ci_doc_source) &&
            occursin("ci-artifacts/stable-widget-stability.json", ci_doc_source) &&
            occursin("stable_widget_stability.schema.json", ci_doc_source) &&
            occursin("stable_widget_stability_schema_audit.jl", ci_doc_source) &&
            occursin("ci-artifacts/widget-promotion-requirements.md", ci_doc_source) &&
            occursin("ci-artifacts/widget-promotion-requirements.json", ci_doc_source) &&
            occursin("widget_promotion_requirements.schema.json", ci_doc_source) &&
            occursin("scripts/widget_promotion_requirements_schema_audit.jl", ci_doc_source) &&
            occursin("versioned rows and summary data", ci_doc_source) &&
            occursin("metadata.generated_at", ci_doc_source) &&
            occursin("metadata.git_commit", ci_doc_source) &&
            occursin("metadata.git_dirty", ci_doc_source) &&
            occursin("widget_family_closeout.schema.json", ci_doc_source) &&
            occursin("scripts/widget_family_closeout_schema_audit.jl", ci_doc_source) &&
            occursin("stable_widget_coverage.schema.json", ci_doc_source) &&
            occursin("scripts/stable_widget_coverage_schema_audit.jl", ci_doc_source) &&
            occursin("--release-check", ci_doc_source) &&
            occursin("--require-ready", ci_doc_source) &&
            occursin("--require-clean-git", ci_doc_source) &&
            occursin("--require-total-count", ci_doc_source) &&
            occursin("without duplicating the family count", ci_doc_source) &&
            occursin("--require-blocked-count 0", ci_doc_source) &&
            occursin("--summary --format tsv", ci_doc_source) &&
            occursin("total/ready/blocked", ci_doc_source) &&
            occursin("ci-artifacts/widget-family-closeout.md", ci_doc_source) &&
            occursin("ci-artifacts/widget-family-closeout-summary.tsv", ci_doc_source) &&
            occursin("if: always()", ci_doc_source) &&
            occursin("widget-family-closeout-<julia-version>", ci_doc_source) ||
            push!(failures, "docs/CONTINUOUS_INTEGRATION.md must document the widget family closeout renderer as a planning artifact")
    end
    isfile(STABLE_PROMOTION_PACKET_SCRIPT) || push!(failures, "missing stable promotion packet scaffold: scripts/new_stable_promotion_packet.jl")
    if isfile(STABLE_PROMOTION_PACKET_SCRIPT)
        scaffold_source = read(STABLE_PROMOTION_PACKET_SCRIPT, String)
        occursin("StablePromotionPacketScaffold", scaffold_source) &&
            occursin("STABLE_PROMOTION_PACKET_TEMPLATE.md", scaffold_source) &&
            occursin("validate_candidate", scaffold_source) &&
            occursin("validate_decision", scaffold_source) &&
            occursin("Wicked.API.", scaffold_source) &&
            occursin("docs/pilot-evidence/", scaffold_source) &&
            occursin("ci-artifacts/pilot-evidence-package-reports/", scaffold_source) &&
            occursin("write_pilot_evidence_package", scaffold_source) &&
            occursin("write_pilot_evidence_package_reports", scaffold_source) ||
            push!(failures, "stable promotion packet scaffold must use the template and validate candidate SHA, decision, stable API target, and pilot evidence package paths")
    end
    isfile(STABLE_PROMOTION_PACKET_TEST) || push!(failures, "missing stable promotion packet scaffold tests: test/new_stable_promotion_packet.jl")
    if isfile(STABLE_PROMOTION_PACKET_TEST)
        scaffold_test_source = read(STABLE_PROMOTION_PACKET_TEST, String)
        occursin("StablePromotionPacketScaffold", scaffold_test_source) &&
        occursin("create_packet", scaffold_test_source) &&
            occursin("validate_candidate", scaffold_test_source) &&
            occursin("validate_decision", scaffold_test_source) &&
            occursin("Wicked.API.ComboBox", scaffold_test_source) &&
            occursin("docs/pilot-evidence/stateful-controls-combobox-abcdef1234567890", scaffold_test_source) &&
            occursin("ci-artifacts/pilot-evidence-package-reports/stateful-controls-combobox-abcdef1234567890", scaffold_test_source) ||
            push!(failures, "stable promotion packet scaffold tests must cover packet generation, SHA validation, decision validation, stable API target replacement, and pilot evidence package path replacement")
    end
    isfile(STABLE_PROMOTION_PACKET_AUDIT_SCRIPT) || push!(failures, "missing stable promotion packet audit: scripts/stable_promotion_packet_audit.jl")
    if isfile(STABLE_PROMOTION_PACKET_AUDIT_SCRIPT)
        packet_audit_source = read(STABLE_PROMOTION_PACKET_AUDIT_SCRIPT, String)
        occursin("StablePromotionPacketAudit", packet_audit_source) &&
            occursin("stable-promotion-packets", packet_audit_source) &&
            occursin("REQUIRED_IDENTITY_FIELDS", packet_audit_source) &&
            occursin("REQUIRED_SECTIONS", packet_audit_source) &&
            occursin("api/widget_coverage.tsv", packet_audit_source) &&
            occursin("api/widget_promotion_requirements.tsv", packet_audit_source) &&
            occursin("api/stable_widget_candidates.tsv", packet_audit_source) &&
            occursin("src/Precompile.jl", packet_audit_source) &&
            occursin("scripts/pilot_evidence_package_audit.jl", packet_audit_source) &&
            occursin("Pilot evidence package checked", packet_audit_source) &&
            occursin("Package-level pilot evidence reports", packet_audit_source) &&
            occursin("Stable facade usage with no Wicked internals", packet_audit_source) &&
            occursin("write_pilot_evidence_package", packet_audit_source) &&
            occursin("write_pilot_evidence_package_reports", packet_audit_source) &&
            occursin("accepted or completed", packet_audit_source) ||
            push!(failures, "stable promotion packet audit must validate records, required sections, behavior/promotion-requirements/promotion/startup evidence, pilot evidence package artifacts, stable facade usage, and accepted/completed experimental review")
    end
    isfile(STABLE_PROMOTION_PACKET_AUDIT_TEST) || push!(failures, "missing stable promotion packet audit tests: test/stable_promotion_packet_audit.jl")
    if isfile(STABLE_PROMOTION_PACKET_AUDIT_TEST)
        packet_audit_test_source = read(STABLE_PROMOTION_PACKET_AUDIT_TEST, String)
        occursin("StablePromotionPacketAudit.audit", packet_audit_test_source) &&
            occursin("contains placeholder text", packet_audit_test_source) &&
            occursin("release-candidate commit must be", packet_audit_test_source) &&
            occursin("duplicates stable promotion packet identity", packet_audit_test_source) &&
            occursin("api/widget_promotion_requirements.tsv", packet_audit_test_source) &&
            occursin("scripts/pilot_evidence_package_audit.jl", packet_audit_test_source) &&
            occursin("must include a pilot evidence package promotion row", packet_audit_test_source) &&
            occursin("must include a package-level pilot evidence reports promotion row", packet_audit_test_source) &&
            occursin("must include stable facade usage developer evidence", packet_audit_test_source) &&
            occursin("write_pilot_evidence_package_reports", packet_audit_test_source) &&
            occursin("requires at least one completed packet record", packet_audit_test_source) ||
            push!(failures, "stable promotion packet audit tests must cover valid records, placeholders, malformed identity, duplicate identity, promotion requirements evidence, pilot evidence package evidence, stable facade usage evidence, and complete mode")
    end
    if isfile(TEST_RUNNER)
        runner_source = read(TEST_RUNNER, String)
        occursin("include(\"new_stable_promotion_packet.jl\")", runner_source) ||
            push!(failures, "main test runner must include stable promotion packet scaffold tests")
        occursin("include(\"stable_promotion_packet_audit.jl\")", runner_source) ||
            push!(failures, "main test runner must include stable promotion packet audit tests")
    end
    if isfile(api_stabilization_path)
        api_stabilization_source = read(api_stabilization_path, String)
        occursin("Type-backed stable API tokens are represented in `src/Precompile.jl`", api_stabilization_source) &&
            occursin("matching precompile tokens", api_stabilization_source) &&
            occursin("same final segment", api_stabilization_source) ||
            push!(failures, "docs/API_STABILIZATION.md must require matching precompile evidence for type-backed stable API tokens")
    end
    if isfile(developer_guide_path)
        developer_guide_source = read(developer_guide_path, String)
        occursin("representative stable family token", developer_guide_source) &&
            occursin("matching precompile token", developer_guide_source) &&
            occursin("api/widget_family_evidence.tsv", developer_guide_source) ||
            push!(failures, "docs/DEVELOPER_GUIDE.md must require matching family precompile tokens for representative stable widgets")
        occursin("scripts/new_stable_promotion_packet.jl", developer_guide_source) &&
            occursin("scripts/stable_promotion_packet_audit.jl", developer_guide_source) &&
            occursin("scripts/pilot_evidence_package_audit.jl", developer_guide_source) &&
            occursin("write_pilot_evidence_package", developer_guide_source) &&
            occursin("write_pilot_evidence_package_reports", developer_guide_source) &&
            occursin("docs/stable-promotion-packets", developer_guide_source) ||
            push!(failures, "docs/DEVELOPER_GUIDE.md must require stable promotion packet scaffold, audit, and pilot evidence packages for widget stabilization")
    end
    contributing_path = joinpath(ROOT, "CONTRIBUTING.md")
    if isfile(contributing_path)
        contributing_source = read(contributing_path, String)
        occursin("scripts/new_stable_promotion_packet.jl", contributing_source) &&
            occursin("scripts/stable_promotion_packet_audit.jl", contributing_source) &&
            occursin("scripts/pilot_evidence_package_audit.jl", contributing_source) &&
            occursin("write_pilot_evidence_package", contributing_source) &&
            occursin("write_pilot_evidence_package_reports", contributing_source) &&
            occursin("docs/stable-promotion-packets", contributing_source) ||
            push!(failures, "CONTRIBUTING.md must document stable promotion packet scaffold, audit, and pilot evidence package workflow for new widgets")
    end
    if isfile(release_checklist_path)
        release_checklist_source = read(release_checklist_path, String)
        occursin("WIDGET_FAMILY_EVIDENCE.md", release_checklist_source) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must link docs/WIDGET_FAMILY_EVIDENCE.md")
        occursin("api/widget_family_evidence.tsv", release_checklist_source) &&
            occursin("artifact review criteria", release_checklist_source) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require widget family evidence artifact review criteria")
        occursin("widget-family-closeout-<julia-version>", release_checklist_source) &&
            occursin("ci-artifacts/widget-family-closeout.md", release_checklist_source) &&
            occursin("ci-artifacts/widget-family-closeout-summary.tsv", release_checklist_source) &&
            occursin("ci-artifacts/widget-family-closeout.json", release_checklist_source) &&
            occursin("widget_family_closeout.schema.json", release_checklist_source) &&
            occursin("blocker details", release_checklist_source) &&
            occursin("--release-check", release_checklist_source) &&
            occursin("--require-ready", release_checklist_source) &&
            occursin("--require-clean-git", release_checklist_source) &&
            occursin("--require-total-count", release_checklist_source) &&
            occursin("derives the expected family count", release_checklist_source) &&
            occursin("--require-blocked-count 0", release_checklist_source) &&
            occursin("--summary --format tsv", release_checklist_source) &&
            occursin("total, ready", release_checklist_source) &&
            occursin("if: always()", release_checklist_source) &&
            occursin("no blocked family", release_checklist_source) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require review of the CI widget family closeout artifact")
        occursin("stable-widget-surface-release.json", release_checklist_source) &&
            occursin("stable_widget_surface_release.schema.json", release_checklist_source) &&
            occursin("stable-widget-surface-release-status.txt", release_checklist_source) &&
            occursin("scripts/stable_widget_surface_release_schema_audit.jl", release_checklist_source) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require review of the stable widget surface release artifacts")
        occursin("stable promotion packet", release_checklist_source) &&
            occursin("STABLE_PROMOTION_PACKET_TEMPLATE.md", release_checklist_source) &&
            occursin("API decision", release_checklist_source) &&
            occursin("behavior evidence", release_checklist_source) &&
            occursin("startup evidence", release_checklist_source) &&
            occursin("scripts/pilot_evidence_package_audit.jl", release_checklist_source) &&
            occursin("write_pilot_evidence_package", release_checklist_source) &&
            occursin("write_pilot_evidence_package_reports", release_checklist_source) &&
            occursin("accepted/completed", release_checklist_source) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require promotion packets and pilot evidence packages for newly stabilized widgets")
        occursin("Stable widget candidate rows are backed by concrete or parameterized", release_checklist_source) &&
            occursin("not constructor-only function exports", release_checklist_source) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require stable widget candidate type bindings")
        occursin("Widget-family helper-function tokens are supplemental only", release_checklist_source) &&
            occursin("at least three type-backed", release_checklist_source) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require helper tokens to be supplemental to type-backed widget family tokens")
        occursin("Every type-backed stable API token", release_checklist_source) &&
            occursin("has a matching precompile token", release_checklist_source) &&
            occursin("same final segment", release_checklist_source) ||
            push!(failures, "docs/RELEASE_CHECKLIST.md must require type-backed stable API tokens to have matching precompile tokens")
    end
    if isfile(validation_strategy_path)
        occursin("WIDGET_FAMILY_EVIDENCE.md", read(validation_strategy_path, String)) ||
            push!(failures, "docs/VALIDATION_STRATEGY.md must link docs/WIDGET_FAMILY_EVIDENCE.md")
    end
    if isfile(release_evidence_path)
        release_evidence_source = read(release_evidence_path, String)
        occursin("WIDGET_FAMILY_EVIDENCE.md", release_evidence_source) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must link docs/WIDGET_FAMILY_EVIDENCE.md")
        occursin("STABLE_PROMOTION_PACKET_TEMPLATE.md", release_evidence_source) &&
            occursin("Stable promotion packets", release_evidence_source) &&
            occursin("scripts/stable_promotion_packet_audit.jl", release_evidence_source) &&
            occursin("scripts/pilot_evidence_package_audit.jl", release_evidence_source) &&
            occursin("write_pilot_evidence_package", release_evidence_source) &&
            occursin("write_pilot_evidence_package_reports", release_evidence_source) &&
            occursin("accepted or completed", release_evidence_source) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require stable promotion packets and pilot evidence packages for promoted widgets")
        occursin("api/widget_family_evidence.tsv", release_evidence_source) &&
            occursin("Archived", release_evidence_source) &&
            occursin("matching `precompile_token` coverage", release_evidence_source) &&
            occursin("type-backed `stable_api_token`", release_evidence_source) &&
            occursin("same final segment", release_evidence_source) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require archived widget family evidence ledger and matching precompile-token review")
        occursin("widget-family-closeout-<julia-version>", release_evidence_source) &&
            occursin("ci-artifacts/widget-family-closeout.md", release_evidence_source) &&
            occursin("ci-artifacts/widget-family-closeout-summary.tsv", release_evidence_source) &&
            occursin("ci-artifacts/widget-family-closeout.json", release_evidence_source) &&
            occursin("widget_family_closeout.schema.json", release_evidence_source) &&
            occursin("schema_version", release_evidence_source) &&
            occursin("metadata", release_evidence_source) &&
            occursin("metadata.git_commit", release_evidence_source) &&
            occursin("metadata.git_dirty", release_evidence_source) &&
            occursin("families", release_evidence_source) &&
            occursin("blocker details", release_evidence_source) &&
            occursin("--release-check", release_evidence_source) &&
            occursin("--require-ready", release_evidence_source) &&
            occursin("--require-clean-git", release_evidence_source) &&
            occursin("--count", release_evidence_source) &&
            occursin("--require-total-count", release_evidence_source) &&
            occursin("--require-blocked-count 0", release_evidence_source) &&
            occursin("total/ready/blocked counts", release_evidence_source) &&
            occursin("if: always()", release_evidence_source) &&
            occursin("family-level ready/blocked status", release_evidence_source) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require archived widget family closeout report artifacts")
        occursin("stable-widget-surface-release-status.txt", release_evidence_source) &&
            occursin("stable-widget-surface-release.json", release_evidence_source) &&
            occursin("stable_widget_surface_release.schema.json", release_evidence_source) &&
            occursin("scripts/stable_widget_surface_release_schema_audit.jl", release_evidence_source) &&
            occursin("release_ready", release_evidence_source) &&
            occursin("coverage readiness", release_evidence_source) &&
            occursin("git provenance", release_evidence_source) ||
            push!(failures, "docs/RELEASE_EVIDENCE.md must require archived stable widget surface-release CI artifacts")
    end
    if isfile(validation_strategy_path)
        validation_strategy_source = read(validation_strategy_path, String)
        occursin("generated Documenter manual", validation_strategy_source) &&
            occursin("widget family evidence pages", validation_strategy_source) ||
            push!(failures, "docs/VALIDATION_STRATEGY.md must require generated manual navigation for stabilization evidence pages")
        occursin("Every type-backed `stable_api_token`", validation_strategy_source) &&
            occursin("matching `precompile_token`", validation_strategy_source) &&
            occursin("same final segment", validation_strategy_source) &&
            occursin("helper-only evidence is incomplete", validation_strategy_source) ||
            push!(failures, "docs/VALIDATION_STRATEGY.md must document matching stable-token and precompile-token validation")
    end
    if isfile(docs_make_path)
        docs_make_source = read(docs_make_path, String)
        occursin("WIDGET_STABILIZATION.md", docs_make_source) &&
            occursin("STABLE_PROMOTION_PACKET_TEMPLATE.md", docs_make_source) &&
            occursin("stable-promotion-packets/README.md", docs_make_source) &&
            occursin("WIDGET_FAMILY_EVIDENCE.md", docs_make_source) &&
            occursin("PERFORMANCE.md", docs_make_source) &&
            occursin("EXAMPLE_FAMILIES.md", docs_make_source) ||
            push!(failures, "docs/make.jl must include stabilization, promotion template, promotion packet records, family evidence, performance, and example-family pages")
    end
    parity_execution_path = joinpath(ROOT, "docs", "PARITY_EXECUTION_PLAN.md")
    if isfile(parity_execution_path)
        parity_execution_source = read(parity_execution_path, String)
        occursin("STABLE_PROMOTION_PACKET_TEMPLATE.md", parity_execution_source) &&
            occursin("scripts/new_stable_promotion_packet.jl", parity_execution_source) &&
            occursin("PARITY_EVIDENCE_TEMPLATE.md", parity_execution_source) ||
            push!(failures, "docs/PARITY_EXECUTION_PLAN.md must require promotion packets and parity evidence records for family closeout")
    end
    isfile(family_evidence_script) || push!(failures, "missing widget family evidence audit: scripts/widget_family_evidence_audit.jl")
    isfile(WIDGET_FAMILY_CLOSEOUT_SCHEMA) || push!(failures, "missing widget family closeout JSON schema: docs/evidence/widget_family_closeout.schema.json")
    isfile(WIDGET_FAMILY_CLOSEOUT_SCHEMA_AUDIT_SCRIPT) || push!(failures, "missing widget family closeout schema audit: scripts/widget_family_closeout_schema_audit.jl")
    if isfile(WIDGET_FAMILY_CLOSEOUT_SCHEMA_AUDIT_SCRIPT)
        schema_audit_source = read(WIDGET_FAMILY_CLOSEOUT_SCHEMA_AUDIT_SCRIPT, String)
        occursin("WidgetFamilyCloseoutSchemaAudit", schema_audit_source) &&
            occursin("schema_failures", schema_audit_source) &&
            occursin("generated_json_failures", schema_audit_source) &&
            occursin("key_contract_failures", schema_audit_source) &&
            occursin("summary_arithmetic_failures", schema_audit_source) &&
            occursin("generated_status_counts", schema_audit_source) &&
            occursin("total must equal ready plus blocked", schema_audit_source) &&
            occursin("REQUIRED_METADATA_KEYS", schema_audit_source) &&
            occursin("OPTIONAL_METADATA_KEYS", schema_audit_source) &&
            occursin("REQUIRED_FAMILY_KEYS", schema_audit_source) &&
            occursin("generated JSON is missing schema key", schema_audit_source) &&
            occursin("schema_version", schema_audit_source) &&
            occursin("metadata", schema_audit_source) &&
            occursin("blocker_details", schema_audit_source) ||
            push!(failures, "widget family closeout schema audit must validate schema tokens and generated JSON")
    end
    isfile(WIDGET_FAMILY_CLOSEOUT_SCHEMA_AUDIT_TEST) || push!(failures, "missing widget family closeout schema audit tests: test/widget_family_closeout_schema_audit.jl")
    if isfile(WIDGET_FAMILY_CLOSEOUT_SCHEMA_AUDIT_TEST)
        schema_audit_test_source = read(WIDGET_FAMILY_CLOSEOUT_SCHEMA_AUDIT_TEST, String)
        occursin("WidgetFamilyCloseoutSchemaAudit.audit()", schema_audit_test_source) &&
            occursin("widget_family_closeout_schema_audit.jl", schema_audit_test_source) &&
            occursin("key_contract_failures", schema_audit_test_source) &&
            occursin("\"metadata\"", schema_audit_test_source) &&
            occursin("\"git_commit\"", schema_audit_test_source) &&
            occursin("\"git_dirty\"", schema_audit_test_source) &&
            occursin("summary_arithmetic_failures", schema_audit_test_source) &&
            occursin("summary total count 2 does not match 1 family rows", schema_audit_test_source) &&
            occursin("generated JSON is missing schema key `blocker_details`", schema_audit_test_source) &&
            occursin("\"families\"", schema_audit_test_source) &&
            occursin("\"blocker_details\"", schema_audit_test_source) ||
            push!(failures, "widget family closeout schema audit tests must cover default audit, help, bad arguments, and malformed schema")
    end
    if isfile(WIDGET_FAMILY_CLOSEOUT_SCHEMA)
        schema_source = read(WIDGET_FAMILY_CLOSEOUT_SCHEMA, String)
            occursin("\"schema_version\"", schema_source) &&
            occursin("\"const\": 1", schema_source) &&
            occursin("\"metadata\"", schema_source) &&
            occursin("\"generated_at\"", schema_source) &&
            occursin("\"git_commit\"", schema_source) &&
            occursin("\"git_dirty\"", schema_source) &&
            occursin("\"summary\"", schema_source) &&
            occursin("\"families\"", schema_source) &&
            occursin("\"blocker_details\"", schema_source) &&
            occursin("\"ready\"", schema_source) &&
            occursin("\"blocked\"", schema_source) ||
            push!(failures, "widget family closeout JSON schema must cover schema version, summary, families, blocker details, and status values")
    end
    isfile(STABLE_WIDGET_COVERAGE_SCHEMA) || push!(failures, "missing stable widget coverage JSON schema: docs/evidence/stable_widget_coverage.schema.json")
    isfile(STABLE_WIDGET_STABILITY_SCHEMA) || push!(failures, "missing stable widget stability JSON schema: docs/evidence/stable_widget_stability.schema.json")
    if isfile(STABLE_WIDGET_STABILITY_SCHEMA)
        stability_schema_source = read(STABLE_WIDGET_STABILITY_SCHEMA, String)
        occursin("\"schema_version\"", stability_schema_source) &&
            occursin("\"metadata\"", stability_schema_source) &&
            occursin("\"ready\"", stability_schema_source) &&
            occursin("\"summary\"", stability_schema_source) &&
            occursin("\"rows\"", stability_schema_source) &&
            occursin("\"name\"", stability_schema_source) &&
            occursin("\"family\"", stability_schema_source) &&
            occursin("\"family_slug\"", stability_schema_source) &&
            occursin("\"surface\"", stability_schema_source) &&
            occursin("\"status\"", stability_schema_source) &&
            occursin("\"coverage_complete\"", stability_schema_source) &&
            occursin("\"missing_checks\"", stability_schema_source) &&
            occursin("\"blockers\"", stability_schema_source) &&
            occursin("\"additionalProperties\": false", stability_schema_source) ||
            push!(failures, "stable widget stability JSON schema must cover metadata, summary, row readiness, checks, and blockers")
    end
    isfile(STABLE_WIDGET_COVERAGE_SCHEMA_AUDIT_SCRIPT) || push!(failures, "missing stable widget coverage schema audit: scripts/stable_widget_coverage_schema_audit.jl")
    isfile(STABLE_WIDGET_STABILITY_SCHEMA_AUDIT_SCRIPT) || push!(failures, "missing stable widget stability schema audit: scripts/stable_widget_stability_schema_audit.jl")
    if isfile(STABLE_WIDGET_STABILITY_SCHEMA_AUDIT_SCRIPT)
        stability_schema_audit_source = read(STABLE_WIDGET_STABILITY_SCHEMA_AUDIT_SCRIPT, String)
        occursin("StableWidgetStabilitySchemaAudit", stability_schema_audit_source) &&
            occursin("using Wicked.API: widget_stability_json", stability_schema_audit_source) &&
            !occursin("render_widget_catalog.jl", stability_schema_audit_source) &&
            occursin("schema_failures", stability_schema_audit_source) &&
            occursin("generated_json_failures", stability_schema_audit_source) &&
            occursin("key_contract_failures", stability_schema_audit_source) &&
            occursin("summary_arithmetic_failures", stability_schema_audit_source) &&
            occursin("REQUIRED_METADATA_KEYS", stability_schema_audit_source) &&
            occursin("REQUIRED_ROW_KEYS", stability_schema_audit_source) &&
            occursin("total must equal ready plus blocked", stability_schema_audit_source) &&
            occursin("ready flag must match blocked count", stability_schema_audit_source) &&
            occursin("summary total must equal row count", stability_schema_audit_source) &&
            occursin("schema_version", stability_schema_audit_source) &&
            occursin("metadata", stability_schema_audit_source) &&
            occursin("generated_at", stability_schema_audit_source) &&
            occursin("root", stability_schema_audit_source) &&
            occursin("rows", stability_schema_audit_source) &&
            occursin("missing_checks", stability_schema_audit_source) &&
            occursin("blockers", stability_schema_audit_source) ||
            push!(failures, "stable widget stability schema audit must validate schema tokens, generated JSON, and summary arithmetic")
    end
    if isfile(STABLE_WIDGET_COVERAGE_SCHEMA_AUDIT_SCRIPT)
        coverage_schema_audit_source = read(STABLE_WIDGET_COVERAGE_SCHEMA_AUDIT_SCRIPT, String)
        occursin("StableWidgetCoverageSchemaAudit", coverage_schema_audit_source) &&
            occursin("using Wicked.API: widget_coverage_summary_json", coverage_schema_audit_source) &&
            !occursin("render_widget_catalog.jl", coverage_schema_audit_source) &&
            occursin("schema_failures", coverage_schema_audit_source) &&
            occursin("generated_json_failures", coverage_schema_audit_source) &&
            occursin("key_contract_failures", coverage_schema_audit_source) &&
            occursin("summary_arithmetic_failures", coverage_schema_audit_source) &&
            occursin("REQUIRED_METADATA_KEYS", coverage_schema_audit_source) &&
            occursin("OPTIONAL_METADATA_KEYS", coverage_schema_audit_source) &&
            occursin("total must equal complete plus incomplete", coverage_schema_audit_source) &&
            occursin("incomplete must equal missing_records plus source_mismatches plus missing_checks", coverage_schema_audit_source) &&
            occursin("schema_version", coverage_schema_audit_source) &&
            occursin("metadata", coverage_schema_audit_source) &&
            occursin("generated_at", coverage_schema_audit_source) &&
            occursin("root", coverage_schema_audit_source) &&
            occursin("git_commit", coverage_schema_audit_source) &&
            occursin("git_dirty", coverage_schema_audit_source) &&
            occursin("rows", coverage_schema_audit_source) &&
            occursin("missing_checks", coverage_schema_audit_source) ||
            push!(failures, "stable widget coverage schema audit must validate schema tokens and generated JSON")
    end
    isfile(STABLE_WIDGET_COVERAGE_SCHEMA_AUDIT_TEST) || push!(failures, "missing stable widget coverage schema audit tests: test/stable_widget_coverage_schema_audit.jl")
    isfile(STABLE_WIDGET_STABILITY_SCHEMA_AUDIT_TEST) || push!(failures, "missing stable widget stability schema audit tests: test/stable_widget_stability_schema_audit.jl")
    if isfile(STABLE_WIDGET_STABILITY_SCHEMA_AUDIT_TEST)
        stability_schema_audit_test_source = read(STABLE_WIDGET_STABILITY_SCHEMA_AUDIT_TEST, String)
        occursin("StableWidgetStabilitySchemaAudit.audit()", stability_schema_audit_test_source) &&
            occursin("stable_widget_stability_schema_audit.jl", stability_schema_audit_test_source) &&
            occursin("!isdefined(StableWidgetStabilitySchemaAudit, :WidgetCatalogRender)", stability_schema_audit_test_source) &&
            occursin("key_contract_failures", stability_schema_audit_test_source) &&
            occursin("\"metadata\"", stability_schema_audit_test_source) &&
            occursin("\"generated_at\"", stability_schema_audit_test_source) &&
            occursin("\"root\"", stability_schema_audit_test_source) &&
            occursin("\"summary\"", stability_schema_audit_test_source) &&
            occursin("\"rows\"", stability_schema_audit_test_source) &&
            occursin("summary_arithmetic_failures", stability_schema_audit_test_source) &&
            occursin("total must equal ready plus blocked", stability_schema_audit_test_source) &&
            occursin("ready flag must match blocked count", stability_schema_audit_test_source) &&
            occursin("generated JSON is missing schema key `rows`", stability_schema_audit_test_source) &&
            occursin("\"missing_checks\"", stability_schema_audit_test_source) &&
            occursin("\"blockers\"", stability_schema_audit_test_source) ||
            push!(failures, "stable widget stability schema audit tests must cover default audit, help, bad arguments, malformed schema, and arithmetic failures")
    end
    if isfile(STABLE_WIDGET_COVERAGE_SCHEMA_AUDIT_TEST)
        coverage_schema_audit_test_source = read(STABLE_WIDGET_COVERAGE_SCHEMA_AUDIT_TEST, String)
        occursin("StableWidgetCoverageSchemaAudit.audit()", coverage_schema_audit_test_source) &&
            occursin("stable_widget_coverage_schema_audit.jl", coverage_schema_audit_test_source) &&
            occursin("!isdefined(StableWidgetCoverageSchemaAudit, :WidgetCatalogRender)", coverage_schema_audit_test_source) &&
            occursin("key_contract_failures", coverage_schema_audit_test_source) &&
            occursin("\"metadata\"", coverage_schema_audit_test_source) &&
            occursin("\"generated_at\"", coverage_schema_audit_test_source) &&
            occursin("\"root\"", coverage_schema_audit_test_source) &&
            occursin("\"git_commit\"", coverage_schema_audit_test_source) &&
            occursin("\"git_dirty\"", coverage_schema_audit_test_source) &&
            occursin("\"summary\"", coverage_schema_audit_test_source) &&
            occursin("\"rows\"", coverage_schema_audit_test_source) &&
            occursin("summary_arithmetic_failures", coverage_schema_audit_test_source) &&
            occursin("total must equal complete plus incomplete", coverage_schema_audit_test_source) &&
            occursin("generated JSON is missing schema key `rows`", coverage_schema_audit_test_source) &&
            occursin("\"missing_checks\"", coverage_schema_audit_test_source) ||
            push!(failures, "stable widget coverage schema audit tests must cover default audit, help, bad arguments, and malformed schema")
    end
        occursin("REQUIRED_FAMILIES", family_source) &&
        occursin("STABLE_API_PATH", family_source) &&
        occursin("read_stable_api_names", family_source) &&
        occursin("stable_api_tokens", family_source) &&
        occursin("MIN_STABLE_API_TOKENS_PER_FAMILY", family_source) &&
        occursin("MIN_STABLE_API_TYPE_TOKENS_PER_FAMILY", family_source) &&
        occursin("stable_api_type_token", family_source) &&
        occursin("token_leaf", family_source) &&
        occursin("precompile_token_represents_stable_token", family_source) &&
        occursin("must have a matching precompile token", family_source) &&
        occursin("representative stable API type tokens", family_source) &&
        occursin("MIN_PRECOMPILE_TOKENS_PER_FAMILY", family_source) &&
        occursin("representative stable API tokens", family_source) &&
        occursin("duplicate_values", family_source) &&
        occursin("duplicate documentation paths", family_source) &&
        occursin("duplicate public example paths", family_source) &&
        occursin("duplicate example family labels", family_source) &&
        occursin("duplicate stable API tokens", family_source) &&
        occursin("duplicate precompile tokens", family_source) &&
        occursin("source_mentions_token", family_source) &&
        occursin("documentation_mentions_token", family_source) &&
        occursin("examples_mention_token", family_source) &&
        occursin("Regex", family_source) &&
        occursin("regex_escape_literal", family_source) &&
        occursin("precompile_tokens", family_source) &&
        occursin("PRECOMPILE_SOURCE", family_source) &&
        occursin("example_family_labels", family_source) &&
        occursin("example_family_rows", family_source) &&
        occursin("EXAMPLES_README", family_source) &&
        occursin("DOCS_README", family_source) &&
        occursin("EXAMPLE_FAMILIES_DOC", family_source) &&
        occursin("inside_root", family_source) &&
        occursin("isabspath", family_source) &&
        occursin("is not listed in docs/README.md", family_source) &&
        occursin("is not listed in examples/README.md", family_source) &&
        occursin("is not listed in docs/EXAMPLE_FAMILIES.md", family_source) &&
        occursin("is mapped to", family_source) &&
        occursin("is missing from api/stable_api.tsv", family_source) &&
        occursin("is not mentioned in focused documentation", family_source) &&
        occursin("is not demonstrated in public examples", family_source) &&
        occursin("indexed focused docs", family_source) &&
        occursin("family-mapped public examples", family_source) || push!(failures, "widget family evidence audit must require family rows, indexed docs, indexed and family-mapped examples, stable API tokens, and precompile tokens")
    isfile(family_evidence_test) || push!(failures, "missing widget family evidence audit tests: test/widget_family_evidence_audit.jl")
    if isfile(family_evidence_test)
        family_test_source = read(family_evidence_test, String)
        occursin("WidgetFamilyEvidenceAudit.audit()", family_test_source) &&
            occursin("missing widget family evidence row", family_test_source) &&
            occursin("inside_root", family_test_source) &&
            occursin("regex_escape_literal(\"Token+\") == \"Token\\\\+\"", family_test_source) &&
            occursin("source_mentions_token(\"Widgets.ColumnView only\", \"Widgets.Column\")", family_test_source) &&
            occursin("source_mentions_token(\"OtherWidgets.Column only\", \"Widgets.Column\")", family_test_source) &&
            occursin("source_mentions_token(\"pulse_services!x only\", \"pulse_services!\")", family_test_source) &&
            occursin("must list at least 3 representative stable API tokens", family_test_source) &&
            occursin("must list at least 3 representative stable API type tokens", family_test_source) &&
            occursin("must list at least 3 representative precompile tokens", family_test_source) &&
            occursin("has duplicate stable API tokens: Column", family_test_source) &&
            occursin("has duplicate precompile tokens: Widgets.Column", family_test_source) &&
            occursin("has duplicate documentation paths: docs/API_WIDGETS.md", family_test_source) &&
            occursin("has duplicate public example paths: examples/layout_quickstart.jl", family_test_source) &&
            occursin("has duplicate example family labels: Layout composition", family_test_source) &&
            occursin("stabilization notes must mention the family name", family_test_source) &&
            occursin("is not listed in docs/README.md", family_test_source) &&
            occursin("is not listed in docs/EXAMPLE_FAMILIES.md", family_test_source) &&
            occursin("expected `Wrong label`", family_test_source) &&
            occursin("MissingPublicToken", family_test_source) &&
            occursin("stable API token `Column` is not mentioned in focused documentation", family_test_source) &&
            occursin("stable API token `MarkdownView` is not demonstrated in public examples", family_test_source) &&
            occursin("TableView only", family_test_source) &&
            occursin("Token+", family_test_source) &&
            occursin("precompile_token_represents_stable_token(\"Widgets.Column\", \"Column\")", family_test_source) &&
            occursin("stable API type token `Box` must have a matching precompile token", family_test_source) &&
            occursin("references missing documentation path", family_test_source) &&
            occursin("precompile token `MissingToken` is missing", family_test_source) &&
            occursin("is not listed in examples/README.md", family_test_source) || push!(failures, "widget family evidence audit tests must cover default audit, missing families, missing docs/examples, missing example index entries, and missing precompile tokens")
    end
    isfile(COMPATIBILITY_WIDGET_ALIAS_AUDIT_SCRIPT) || push!(failures, "missing compatibility widget alias audit: scripts/compatibility_widget_alias_audit.jl")
    occursin("component_catalog_public_map.jl", alias_source) || push!(failures, "compatibility widget alias audit must use the shared component catalog public map parser")
    occursin("read_component_catalog_widget_names", alias_source) || push!(failures, "compatibility widget alias audit must include public widget-name-map compatibility names")
    occursin("read_stable_widget_names", alias_source) || push!(failures, "compatibility widget alias audit must include stable direct-renderable names")
    occursin("find_widget_aliases", alias_source) || push!(failures, "compatibility widget alias audit must scan source aliases")
    occursin("source_root", alias_source) || push!(failures, "compatibility widget alias audit must support testable source roots")
    isfile(COMPATIBILITY_WIDGET_ALIAS_AUDIT_TEST) || push!(failures, "missing compatibility widget alias audit tests: test/compatibility_widget_alias_audit.jl")
    if isfile(COMPATIBILITY_WIDGET_ALIAS_AUDIT_TEST)
        alias_test_source = read(COMPATIBILITY_WIDGET_ALIAS_AUDIT_TEST, String)
        occursin("find_widget_aliases", alias_test_source) &&
            occursin("source_root", alias_test_source) &&
            occursin("Panel", alias_test_source) &&
            occursin("Card", alias_test_source) || push!(failures, "compatibility widget alias audit tests must cover synthetic bare widget aliases")
    end
    occursin("read_widget_coverage", source) || push!(failures, "stable widget candidate report must read the widget coverage ledger")
    occursin("read_api_kinds", source) &&
        occursin("stable_widget_binding", source) &&
        occursin("stable widget must be a concrete or parameterized Wicked.API type binding", source) ||
        push!(failures, "stable widget candidate report must block stable widget names whose Wicked.API binding is not a concrete or parameterized type")
    occursin("missing public state_for method", source) || push!(failures, "stable widget candidate report must block stateful widgets without public state_for support")
    occursin("experimental_promotion_audit.jl", source) && occursin("ExperimentalPromotionAudit.read_rows", source) && occursin("missing experimental promotion/removal plan", source) && occursin("accepted or completed", source) || push!(failures, "stable widget candidate report must reuse the experimental promotion audit and block compatibility widgets without an accepted promotion/removal plan")
    occursin("stable_status = status == \"complete\" ? \"stable\" : \"blocked\"", source) || push!(failures, "stable widget candidate report must not let Wicked.API exports bypass evidence checks")
    occursin("evidence_cell_status", source) &&
        occursin("must cite a checked-in Julia source file", source) &&
        occursin("generic status", source) &&
        occursin("non-applicable evidence must include a reason", source) ||
        push!(failures, "stable widget candidate report must reject placeholder behavior evidence and weak n/a reasons")
    isfile(STABLE_WIDGET_CANDIDATES_TEST) || push!(failures, "missing stable widget candidate tests: test/stable_widget_candidates.jl")
    if isfile(STABLE_WIDGET_CANDIDATES_TEST)
        test_source = read(STABLE_WIDGET_CANDIDATES_TEST, String)
        occursin("read_experimental_promotion_plan", test_source) &&
            occursin("compatibility_candidate_row", test_source) &&
            occursin("candidate_rows(;", test_source) &&
            occursin("missing experimental promotion/removal plan", test_source) &&
            occursin("must be accepted or completed", test_source) &&
            occursin("invalid decision", test_source) &&
            occursin("stable widget must be a concrete or parameterized Wicked.API type binding", test_source) ||
            push!(failures, "stable widget candidate tests must cover promotion-plan parsing, full candidate-row integration, compatibility candidate blocking, accepted-review blocking, and function-shaped stable widget blocking")
        occursin("generic_evidence_widget_coverage.tsv", test_source) &&
            occursin("short_nonapplicable_widget_coverage.tsv", test_source) ||
            push!(failures, "stable widget candidate tests must cover generic evidence and weak n/a reason blockers")
    end
    if isfile(WIDGET_CATALOG_TEST)
        catalog_test_source = read(WIDGET_CATALOG_TEST, String)
        occursin("stable_widget_catalog", catalog_test_source) &&
            occursin("stable_widget_count()", catalog_test_source) &&
            occursin("stable_widget_names", catalog_test_source) &&
            occursin("widget_names_text()", catalog_test_source) &&
            occursin("search_widget_names_text", catalog_test_source) &&
            occursin("widget_source_files()", catalog_test_source) &&
            occursin("widget_source_files_text()", catalog_test_source) &&
            occursin("search_widget_source_files_text", catalog_test_source) &&
            occursin("widget_source_summary()", catalog_test_source) &&
            occursin("widget_source_summary_markdown()", catalog_test_source) &&
            occursin("widget_source_summary_tsv()", catalog_test_source) &&
            occursin("search_widgets(\"button\")", catalog_test_source) &&
            occursin("search_widget_count(\"button\")", catalog_test_source) &&
            occursin("group_widgets(:source)", catalog_test_source) &&
            occursin("widget_catalog_summary()", catalog_test_source) &&
            occursin("widget_catalog_markdown", catalog_test_source) &&
            occursin("widget_catalog_records()", catalog_test_source) &&
            occursin("widget_catalog_tsv", catalog_test_source) &&
            occursin("header=false", catalog_test_source) &&
            occursin("search_widget_catalog_markdown", catalog_test_source) &&
            occursin("search_widget_catalog_tsv", catalog_test_source) &&
            occursin("widget_vocabulary()", catalog_test_source) &&
            occursin("WidgetVocabularyEntry", catalog_test_source) &&
            occursin("WidgetFamilyCloseoutReport", catalog_test_source) &&
            occursin("widget_family_closeout_reports()", catalog_test_source) &&
            occursin("widget_family_closeout_report(:toolkit)", catalog_test_source) &&
            occursin("widget_family_closeout_records", catalog_test_source) &&
            occursin("widget_family_closeout_gaps", catalog_test_source) &&
            occursin("widget_family_closeout_summary", catalog_test_source) &&
            occursin("widget_family_closeout_complete", catalog_test_source) &&
            occursin("assert_widget_family_closeout_complete", catalog_test_source) &&
            occursin("widget_family_closeout_markdown", catalog_test_source) &&
            occursin("widget_family_closeout_tsv", catalog_test_source) &&
            occursin("assert_widget_family_closeout_ready", catalog_test_source) &&
            occursin("widget_vocabulary_records", catalog_test_source) &&
            occursin("search_widget_vocabulary", catalog_test_source) &&
            occursin("widget_vocabulary_entry", catalog_test_source) &&
            occursin("widget_vocabulary_widget_names", catalog_test_source) &&
            occursin("widget_vocabulary_entry(\"Divider or separator\")", catalog_test_source) &&
            occursin("widget_vocabulary_widget_names(\"Divider or separator\")", catalog_test_source) &&
            occursin("widget_vocabulary_markdown", catalog_test_source) &&
            occursin("widget_vocabulary_tsv", catalog_test_source) &&
            occursin("columns=:name", catalog_test_source) &&
            occursin("columns=1", catalog_test_source) &&
            occursin("widget_catalog_entry(Button)", catalog_test_source) &&
            occursin("widget_catalog_entry(:Divider)", catalog_test_source) &&
            occursin("widget_catalog_family(:Divider)", catalog_test_source) &&
            occursin("widget_catalog_entry(:DataStateView)", catalog_test_source) &&
            occursin("widget_catalog_family(:DataStateView)", catalog_test_source) &&
            occursin("widget_catalog_entry(:KeyValueList)", catalog_test_source) &&
            occursin("widget_catalog_family(:KeyValueList)", catalog_test_source) &&
            occursin("widget_catalog_entry(:MetadataList)", catalog_test_source) &&
            occursin("widget_catalog_family(:MetadataList)", catalog_test_source) &&
            occursin("widget_catalog_entry(:DefinitionList)", catalog_test_source) &&
            occursin("widget_catalog_family(:DefinitionList)", catalog_test_source) &&
            occursin("is_stable_widget(Button(\"Lookup\", :lookup))", catalog_test_source) &&
            occursin("is_stable_widget(:Button)", catalog_test_source) &&
            occursin("widget_catalog_entry(:Button)", catalog_test_source) &&
            occursin("widget_coverage_records()", catalog_test_source) &&
            occursin("widget_coverage_gaps()", catalog_test_source) &&
            occursin("widget_coverage_issue_records(:complete)", catalog_test_source) &&
            occursin("widget_coverage_issue_count(:missing_record)", catalog_test_source) &&
            occursin("widget_coverage_issue_names(:missing_record)", catalog_test_source) &&
            occursin("widget_coverage_issue_text(:missing_record)", catalog_test_source) &&
            occursin("widget_coverage_issue_markdown", catalog_test_source) &&
            occursin("widget_coverage_issue_tsv", catalog_test_source) &&
            occursin("widget_coverage_complete()", catalog_test_source) &&
            occursin("assert_widget_coverage_complete()", catalog_test_source) &&
            occursin("widget_coverage_git_metadata(root=pwd())", catalog_test_source) &&
            occursin("assert_widget_coverage_clean_git", catalog_test_source) &&
            occursin("widget_coverage_release_ready", catalog_test_source) &&
            occursin("assert_widget_coverage_release_ready", catalog_test_source) &&
            occursin("widget_coverage_release_status_record", catalog_test_source) &&
            occursin("widget_coverage_release_status_json", catalog_test_source) &&
            occursin("widget_coverage_release_status_text", catalog_test_source) &&
            occursin("stable widget coverage evidence has", catalog_test_source) &&
            occursin("widget_stability_complete", catalog_test_source) &&
            occursin("assert_widget_stability_complete", catalog_test_source) &&
            occursin("widget_stability_summary", catalog_test_source) &&
            occursin("widget_stability_summary_records", catalog_test_source) &&
            occursin("widget_stability_summary_markdown", catalog_test_source) &&
            occursin("widget_stability_summary_tsv", catalog_test_source) &&
            occursin("widget_stability_summary_text", catalog_test_source) &&
            occursin("widget_surface_release_status_record", catalog_test_source) &&
            occursin("widget_surface_release_ready", catalog_test_source) &&
            occursin("assert_widget_surface_release_ready", catalog_test_source) &&
            occursin("widget_surface_release_status_text", catalog_test_source) &&
            occursin("widget_surface_release_status_json", catalog_test_source) &&
            occursin("widget_coverage_summary()", catalog_test_source) &&
            occursin("widget_coverage_summary_records()", catalog_test_source) &&
            occursin("widget_coverage_summary_markdown", catalog_test_source) &&
            occursin("widget_coverage_summary_json", catalog_test_source) &&
            occursin("widget_coverage_summary_text", catalog_test_source) &&
            occursin("widget_coverage_summary_tsv", catalog_test_source) &&
            occursin("widget_coverage_records_markdown", catalog_test_source) &&
            occursin("widget_coverage_gaps_tsv", catalog_test_source) &&
            occursin("WidgetCatalogEntry", catalog_test_source) ||
            push!(failures, "stable widget catalog tests must cover listing, filtering, and widget lookup")
    end
    if isfile(WIDGET_CATALOG_RENDER_TEST)
        render_test_source = read(WIDGET_CATALOG_RENDER_TEST, String)
            occursin("WidgetCatalogRender.main([\"--help\"]", render_test_source) &&
            occursin("--require-clean-git", render_test_source) &&
            occursin("--require-stability-ready", render_test_source) &&
            occursin("--require-stabilization-ready", render_test_source) &&
            occursin("--require-surface-release-ready", render_test_source) &&
            occursin("parse_arguments([\"--coverage-status\", \"--require-clean-git\"])", render_test_source) &&
            occursin("parse_arguments([\"--stability\", \"--require-stability-ready\"])", render_test_source) &&
            occursin("parse_arguments([\"--surface-release-status\", \"--require-surface-release-ready\"])", render_test_source) &&
            occursin("parse_arguments([\"--coverage-status\", \"--require-complete-coverage\", \"--require-clean-git\"])", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--columns\", \"name,status\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--format\", \"tsv\"", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--count\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--count\", \"--query\", \"button\"]", render_test_source) &&
            occursin("--min-count", render_test_source) &&
            occursin("expected at least 1 matching widgets, got 0", render_test_source) &&
            occursin("--min-count requires a non-negative integer", render_test_source) &&
            occursin("--max-count", render_test_source) &&
            occursin("expected at most 0 matching widgets", render_test_source) &&
            occursin("--max-count requires a non-negative integer", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--names\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--names\", \"--query\", \"button\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--sources\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--sources\", \"--query\", \"button\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--summary\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--summary\", \"--format\", \"tsv\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--source-summary\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--source-summary\", \"--format\", \"tsv\", \"--no-header\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage\", \"--columns\", \"name,complete,issue\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage-gaps\"", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage-issue\", \"missing_checks\"", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage-issue\", \"source_mismatch\"", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage-issue-names\", \"missing_checks\"", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage-summary\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage-summary\", \"--format\", \"tsv\", \"--no-header\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage-summary-json\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage-status\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--coverage-status\", \"--require-clean-git\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stability\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stability\", \"--columns\", \"name,ready,blockers\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stability-gaps\"", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stability-summary\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stability-summary\", \"--format\", \"tsv\", \"--no-header\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stability-status\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stability-json\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stabilization-status\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stabilization-status\", \"--require-stabilization-ready\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stabilization-json\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--surface-release-status\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--surface-release-json\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--surface-release-status\", \"--require-surface-release-ready\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--vocabulary\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--vocabulary\", \"--format\", \"tsv\", \"--no-header\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--vocabulary-widgets\", \"--query\", \"Button\"]", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--vocabulary-widgets\", \"--query\", \"Divider or separator\"]", render_test_source) &&
            occursin("--require-complete-coverage", render_test_source) &&
            occursin("expected promotion-ready stable widgets", render_test_source) &&
            occursin("expected complete stable widget coverage evidence", render_test_source) &&
            occursin("expected release-ready stable widget surface", render_test_source) &&
            occursin("--no-header", render_test_source) &&
            occursin("--count, --names, --sources, --families, --family-slugs, --summary, --source-summary, --family-summary, --family-catalog, --coverage, --coverage-gaps, --coverage-summary, --coverage-summary-json, --coverage-status, --coverage-issue, --coverage-issue-names, --stability, --stability-gaps, --stability-summary, --stability-status, --stability-json, --stabilization-status, --stabilization-blockers, --stabilization-json, --surface-release-status, --surface-release-json, --vocabulary, and --vocabulary-widgets are mutually exclusive", render_test_source) &&
            occursin("--no-header cannot be used with --count", render_test_source) &&
            occursin("--query cannot be used with --source-summary", render_test_source) &&
            occursin("--query cannot be used with --coverage or --coverage-gaps", render_test_source) &&
            occursin("--query cannot be used with --coverage-summary", render_test_source) &&
            occursin("--columns cannot be used with --coverage-summary", render_test_source) &&
            occursin("--query cannot be used with --coverage-summary-json", render_test_source) &&
            occursin("--columns cannot be used with --coverage-summary-json", render_test_source) &&
            occursin("--query cannot be used with --coverage-status", render_test_source) &&
            occursin("--columns cannot be used with --coverage-status", render_test_source) &&
            occursin("--query cannot be used with --coverage-issue", render_test_source) &&
            occursin("--query cannot be used with --coverage-issue-names", render_test_source) &&
            occursin("--columns cannot be used with --coverage-issue-names", render_test_source) &&
            occursin("--query cannot be used with --stability or --stability-gaps", render_test_source) &&
            occursin("--query cannot be used with --stability-json", render_test_source) &&
            occursin("--columns cannot be used with --stability-json", render_test_source) &&
            occursin("--query cannot be used with --stability-summary", render_test_source) &&
            occursin("--columns cannot be used with --stability-summary", render_test_source) &&
            occursin("--query cannot be used with --stability-status", render_test_source) &&
            occursin("--columns cannot be used with --stability-status", render_test_source) &&
            occursin("--query cannot be used with --stabilization-status", render_test_source) &&
            occursin("--columns cannot be used with --stabilization-status", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--stabilization-blockers\"]", render_test_source) &&
            occursin("--query cannot be used with --stabilization-blockers", render_test_source) &&
            occursin("--columns cannot be used with --stabilization-blockers", render_test_source) &&
            occursin("--query cannot be used with --stabilization-json", render_test_source) &&
            occursin("--columns cannot be used with --stabilization-json", render_test_source) &&
            occursin("--query cannot be used with --surface-release-status", render_test_source) &&
            occursin("--columns cannot be used with --surface-release-status", render_test_source) &&
            occursin("--query cannot be used with --surface-release-json", render_test_source) &&
            occursin("--columns cannot be used with --surface-release-json", render_test_source) &&
            occursin("--query cannot be used with --vocabulary", render_test_source) &&
            occursin("--columns cannot be used with --vocabulary", render_test_source) &&
            occursin("--vocabulary-widgets requires --query", render_test_source) &&
            occursin("--columns cannot be used with --vocabulary-widgets", render_test_source) &&
            occursin("--no-header requires --format tsv", render_test_source) &&
            occursin("WidgetCatalogRender.main([\"--query\", \"button\"", render_test_source) &&
            occursin("--output", render_test_source) &&
            occursin("--append", render_test_source) &&
            occursin("--append requires --output", render_test_source) &&
            occursin("catalog\", \"widgets.md", render_test_source) &&
            occursin("--format must be markdown or tsv", render_test_source) &&
            occursin("--query requires a non-empty search string", render_test_source) &&
            occursin("--columns cannot contain empty column names", render_test_source) ||
            push!(failures, "stable widget catalog render tests must cover help, selected columns, and argument errors")
    end
    if isfile(family_closeout_render_test)
        closeout_test_source = read(family_closeout_render_test, String)
        occursin("WidgetFamilyCloseoutRender.main([\"--help\"]", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--columns\", \"family,status,blockers,blocker_details\"]", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--format\", \"tsv\"", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--format\", \"tsv\", \"--no-header\"", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--format\", \"json\", \"--family\", \"toolkit\"]", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--summary\", \"--format\", \"json\"]", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--status\", \"ready\", \"--count\"]", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--status\", \"blocked\", \"--columns\", \"family,status\"]", closeout_test_source) &&
            occursin("\"schema_version\":1", closeout_test_source) &&
            occursin("\"metadata\":", closeout_test_source) &&
            occursin("\"generated_at\":\"", closeout_test_source) &&
            occursin("git_commit()", closeout_test_source) &&
            occursin("git_dirty()", closeout_test_source) &&
            occursin("--release-check", closeout_test_source) &&
            occursin("--require-clean-git", closeout_test_source) &&
            occursin("\"families\":[{\"family\":\"Toolkit\"", closeout_test_source) &&
            occursin("\"blocker_details\":[]", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--count\", \"--family\", \"toolkit\"]", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--summary\", \"--format\", \"tsv\"]", closeout_test_source) &&
            occursin("--count and --summary are mutually exclusive", closeout_test_source) &&
            occursin("--require-ready-count", closeout_test_source) &&
            occursin("--status must be ready, blocked, or all", closeout_test_source) &&
            occursin("--require-total-count", closeout_test_source) &&
            occursin("--require-blocked-count", closeout_test_source) &&
            occursin("expected 2 total families, got 1", closeout_test_source) &&
            occursin("total-count-output.md", closeout_test_source) &&
            occursin("expected 0 ready families, got 1", closeout_test_source) &&
            occursin("WidgetFamilyCloseoutRender.main([\"--require-ready\", \"--family\", \"toolkit\"]", closeout_test_source) &&
            occursin("blocked families: Toolkit", closeout_test_source) &&
            occursin("references missing documentation path", closeout_test_source) &&
            occursin("blocked.md", closeout_test_source) &&
            occursin("family closeout column must be one of", closeout_test_source) &&
            occursin("--no-header requires --format tsv", closeout_test_source) ||
            push!(failures, "widget family closeout render tests must cover help, selected columns, TSV, count, and argument errors")
    end
    isfile(COMPONENT_CATALOG_PUBLIC_MAP_TEST) || push!(failures, "missing component catalog public map parser tests: test/component_catalog_public_map.jl")
    isfile(PUBLIC_WIDGET_CANDIDATE_AUDIT_TEST) || push!(failures, "missing public widget candidate audit tests: test/public_widget_candidate_audit.jl")
    if isfile(PUBLIC_WIDGET_CANDIDATE_AUDIT_TEST)
        public_candidate_test_source = read(PUBLIC_WIDGET_CANDIDATE_AUDIT_TEST, String)
        occursin("public_surface_failures", public_candidate_test_source) &&
            occursin("report_current_failures", public_candidate_test_source) &&
            occursin("api_renderable_widget_names", public_candidate_test_source) &&
            occursin("stable widget candidate report is stale", public_candidate_test_source) ||
            push!(failures, "public widget candidate audit tests must cover public surface checks, report freshness, and live API discovery")
    end
    if isfile(TEST_RUNNER)
        runner = read(TEST_RUNNER, String)
        occursin("include(\"component_catalog_public_map.jl\")", runner) || push!(failures, "main test runner must include component catalog public map parser tests")
        occursin("include(\"compatibility_widget_alias_audit.jl\")", runner) || push!(failures, "main test runner must include compatibility widget alias audit tests")
        occursin("include(\"experimental_promotion_audit.jl\")", runner) || push!(failures, "main test runner must include experimental promotion audit tests")
        occursin("include(\"stable_widget_candidates.jl\")", runner) || push!(failures, "main test runner must include stable widget candidate tests")
        occursin("include(\"public_widget_candidate_audit.jl\")", runner) || push!(failures, "main test runner must include public widget candidate audit tests")
        occursin("include(\"widget_catalog.jl\")", runner) || push!(failures, "main test runner must include stable widget catalog tests")
        occursin("include(\"widget_catalog_render.jl\")", runner) || push!(failures, "main test runner must include stable widget catalog render tests")
        occursin("include(\"widget_family_evidence_audit.jl\")", runner) || push!(failures, "main test runner must include widget family evidence audit tests")
        occursin("include(\"widget_family_closeout_render.jl\")", runner) || push!(failures, "main test runner must include widget family closeout render tests")
        occursin("include(\"widget_family_closeout_schema_audit.jl\")", runner) || push!(failures, "main test runner must include widget family closeout schema audit tests")
        occursin("include(\"stable_widget_coverage_schema_audit.jl\")", runner) || push!(failures, "main test runner must include stable widget coverage schema audit tests")
        occursin("include(\"stable_widget_stability_schema_audit.jl\")", runner) || push!(failures, "main test runner must include stable widget stability schema audit tests")
        occursin("include(\"stable_widget_stabilization_schema_audit.jl\")", runner) || push!(failures, "main test runner must include stable widget stabilization schema audit tests")
        occursin("include(\"stable_widget_surface_release_schema_audit.jl\")", runner) || push!(failures, "main test runner must include stable widget surface release schema audit tests")
        occursin("include(\"widget_stabilization_gate.jl\")", runner) || push!(failures, "main test runner must include widget stabilization gate tests")
    end
    isempty(failures) || return failures
    include(family_evidence_script)
    family_failures = _invoke_audit_call!(:WidgetFamilyEvidenceAudit, :audit)
    isempty(family_failures) || return ["widget family evidence audit: $failure" for failure in family_failures]
    include(candidate_script)
    return Base.invokelatest(() -> begin
        rows = getfield(Main, :candidate_rows)()
        failures = String[]
        expected_lines = ["widget\tsource\tsurface\tstatus\treason"]
        append!(
            expected_lines,
            join((row.widget, row.source, row.surface, row.status, row.reason), '\t')
            for row in rows
        )
        if !isfile(report_path)
            push!(failures, "missing stable widget candidate report: api/stable_widget_candidates.tsv")
        else
            actual_lines = readlines(report_path)
            actual_lines == expected_lines || push!(
                failures,
                "stable widget candidate report is stale; run julia --project=. --startup-file=no scripts/stable_widget_candidates.jl --write-report",
            )
        end
        for row in rows
            row.status == "stable" && continue
            push!(failures, "$(row.widget) is $(row.status) on $(row.surface): $(row.reason)")
        end
        if isfile(PUBLIC_WIDGET_CANDIDATE_AUDIT_SCRIPT)
            include(PUBLIC_WIDGET_CANDIDATE_AUDIT_SCRIPT)
            public_failures = _invoke_audit_call!(:PublicWidgetCandidateAudit, :audit)
            append!(failures, ("public widget candidate audit: $failure" for failure in public_failures))
        end
        if isfile(COMPATIBILITY_WIDGET_ALIAS_AUDIT_SCRIPT)
            include(COMPATIBILITY_WIDGET_ALIAS_AUDIT_SCRIPT)
            aliases = Base.invokelatest(() -> begin
                audit = getfield(Main, :CompatibilityWidgetAliasAudit)
                widgets = union(
                    getfield(audit, :read_stable_widget_names)(),
                    getfield(audit, :read_component_catalog_widget_names)(),
                )
                getfield(audit, :find_widget_aliases)(widgets)
            end)
            for alias in aliases
                push!(
                    failures,
                    "$(alias.path):$(alias.line): $(alias.widget) is a bare alias to $(alias.target); use a first-class wrapper for stable direct-renderable and public widget-name-map names",
                )
            end
        end
        return failures
    end)
end

function markdown_files()
    files = String[]
    for name in readdir(ROOT; join=true)
        isfile(name) && endswith(name, ".md") && push!(files, name)
    end
    append!(files, files_with_extension(("docs", "benchmark", "examples"), ".md"))
    return sort!(unique!(files))
end

function local_markdown_target(raw_target::AbstractString)
    target = strip(String(raw_target))
    startswith(target, '<') && endswith(target, '>') && (target = target[2:(end - 1)])
    isempty(target) && return nothing
    startswith(target, '#') && return nothing
    occursin(r"^[A-Za-z][A-Za-z0-9+.-]*:", target) && return nothing
    target = first(split(target, '#'; limit=2))
    target = replace(target, "%20" => " ")
    isempty(target) ? nothing : target
end

function check_markdown_links!()
    failures = String[]
    pattern = r"\[[^\]]*\]\(([^)]+)\)"
    for path in markdown_files()
        source = read(path, String)
        for matched in eachmatch(pattern, source)
            target = local_markdown_target(matched.captures[1])
            target === nothing && continue
            resolved = normpath(joinpath(dirname(path), target))
            ispath(resolved) || push!(failures, "$(relpath(path, ROOT)): missing local Markdown target $(repr(target))")
        end
    end
    return failures
end

function check_parity_survey!()
    include(joinpath(ROOT, "scripts", "parity_audit.jl"))
    return Base.invokelatest(() -> begin
        audit = getfield(Main, :ParityAudit)
        getfield(audit, :check_reference_parity)()
    end)
end

function main()
    checks = (
        "Julia syntax" => check_julia_syntax!,
        "public exports" => check_public_exports!,
        "method ambiguities" => check_method_ambiguities!,
        "optional loading" => check_optional_loading!,
        "public API baseline" => check_public_api_baseline!,
        "facade overlap" => check_facade_overlap!,
        "experimental import policy" => check_experimental_import_policy!,
        "experimental promotion ledger" => check_experimental_promotion_ledger!,
        "public documentation" => check_public_documentation!,
        "component catalog contract" => check_component_catalog_contract!,
        "component catalog widget type bindings" => check_component_catalog_widget_type_bindings!,
        "repository policy" => check_policy_files!,
        "examples index" => check_examples_readme_policy!,
        "versioned manifests" => check_manifest_layout!,
        "Linux CI policy" => check_linux_ci_policy!,
        "Unicode width corpus" => check_unicode_width_corpus!,
        "remote protocol fixtures" => check_remote_protocol_fixtures!,
        "real-terminal matrix" => check_real_terminal_matrix!,
        "terminal evidence records" => check_terminal_evidence_records!,
        "real application evidence records" => check_application_evidence_records!,
        "benchmark evidence records" => check_benchmark_evidence_records!,
        "package loading evidence records" => check_loading_evidence_records!,
        "documentation evidence records" => check_documentation_evidence_records!,
        "semantic accessibility evidence records" => check_semantic_evidence_records!,
        "parity release checklist" => check_parity_release_checklist!,
        "parity evidence policy" => check_parity_policy_json!,
        "parity closeout audit" => check_parity_closeout_audit!,
        "parity evidence scaffold" => check_parity_evidence_scaffold!,
        "Markdown links" => check_markdown_links!,
        "reference parity survey" => check_parity_survey!,
        "stable widget surface" => check_stable_widget_surface!,
    )
    failures = String[]
    for (name, check) in checks
        result = check()
        if isempty(result)
            println("quality gate: $name passed")
        else
            append!(failures, ("$name: $message" for message in result))
        end
    end
    if !isempty(failures)
        foreach(message -> println(stderr, "quality gate: ", message), failures)
        return 1
    end
    println("quality gate: all checks passed")
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
