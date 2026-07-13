#!/usr/bin/env julia

module PilotEvidencePackageAudit

using Wicked.API:
    assert_pilot_evidence_package_report_artifacts,
    pilot_evidence_package_artifact_summary_text,
    pilot_evidence_package_report_artifact_summary_text,
    verify_pilot_evidence_package

const ROOT = normpath(joinpath(@__DIR__, ".."))
const DEFAULT_EVIDENCE_DIR = joinpath(ROOT, "docs", "pilot-evidence")

struct AuditOptions
    allow_extra::Bool
    evidence_allow_extra::Bool
    reports_allow_extra::Bool
    report_allow_extra::Bool
    require_complete::Bool
end

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/pilot_evidence_package_audit.jl [options] [PACKAGE_DIR...]")
    println(io, "")
    println(io, "Validates packaged WidgetPilot or ToolkitPilot evidence artifacts.")
    println(io, "")
    println(io, "Options:")
    println(io, "  --package-report-dir DIR    Verify package-level reports for the matching PACKAGE_DIR")
    println(io, "  --allow-extra               Allow extra files in package, evidence, reports, and package-report dirs")
    println(io, "  --evidence-allow-extra      Allow extra files in PACKAGE_DIR/evidence")
    println(io, "  --reports-allow-extra       Allow extra files in PACKAGE_DIR/reports")
    println(io, "  --report-allow-extra        Allow extra files in --package-report-dir")
    println(io, "  --require-complete          Fail when no package artifacts are found")
    println(io, "")
    println(io, "When PACKAGE_DIR is omitted, the script audits package directories under docs/pilot-evidence.")
    println(io, "When --package-report-dir is used, provide one report directory for each PACKAGE_DIR.")
end

resolve_path(path::AbstractString) =
    isabspath(path) ? normpath(path) : normpath(joinpath(ROOT, path))

function default_package_paths()
    isdir(DEFAULT_EVIDENCE_DIR) || return String[]
    return sort!(
        String[
            path for path in readdir(DEFAULT_EVIDENCE_DIR; join=true)
            if isdir(path) && isdir(joinpath(path, "evidence")) && isdir(joinpath(path, "reports"))
        ],
    )
end

function parse_arguments(arguments)
    package_paths = String[]
    report_dirs = String[]
    allow_extra = false
    evidence_allow_extra = false
    reports_allow_extra = false
    report_allow_extra = false
    require_complete = false

    index = firstindex(arguments)
    while index <= lastindex(arguments)
        argument = arguments[index]
        if argument == "--help"
            print_usage()
            return nothing
        elseif argument == "--allow-extra"
            allow_extra = true
            evidence_allow_extra = true
            reports_allow_extra = true
            report_allow_extra = true
        elseif argument == "--evidence-allow-extra"
            evidence_allow_extra = true
        elseif argument == "--reports-allow-extra"
            reports_allow_extra = true
        elseif argument == "--report-allow-extra"
            report_allow_extra = true
        elseif argument == "--require-complete"
            require_complete = true
        elseif argument == "--package-report-dir"
            index += 1
            index <= lastindex(arguments) || error("--package-report-dir requires a directory argument")
            push!(report_dirs, resolve_path(arguments[index]))
        elseif startswith(argument, "-")
            error("unknown argument: $argument")
        else
            push!(package_paths, resolve_path(argument))
        end
        index += 1
    end

    isempty(package_paths) && append!(package_paths, default_package_paths())
    if !isempty(report_dirs) && length(report_dirs) != length(package_paths)
        error("--package-report-dir must be supplied once for each package directory")
    end

    options = AuditOptions(
        allow_extra,
        evidence_allow_extra,
        reports_allow_extra,
        report_allow_extra,
        require_complete,
    )
    return (; options, package_paths, report_dirs)
end

function validate_package(path::AbstractString, options::AuditOptions; report_dir=nothing)
    failures = String[]
    relative = relpath(path, ROOT)
    try
        verify_pilot_evidence_package(
            path;
            allow_extra=options.allow_extra,
            evidence_allow_extra=options.evidence_allow_extra,
            reports_allow_extra=options.reports_allow_extra,
        )
        println("pilot evidence package audit: $relative package passed")
        println("pilot evidence package audit: " * pilot_evidence_package_artifact_summary_text(path))
    catch error
        push!(failures, "$relative package failed: $(sprint(showerror, error))")
    end

    report_dir === nothing && return failures
    report_relative = relpath(report_dir, ROOT)
    try
        assert_pilot_evidence_package_report_artifacts(
            report_dir,
            path;
            allow_extra=options.report_allow_extra,
            package_allow_extra=options.allow_extra,
            evidence_allow_extra=options.evidence_allow_extra,
            reports_allow_extra=options.reports_allow_extra,
        )
        println("pilot evidence package audit: $report_relative package reports passed")
        println("pilot evidence package audit: " * pilot_evidence_package_report_artifact_summary_text(report_dir))
    catch error
        push!(failures, "$report_relative package reports failed: $(sprint(showerror, error))")
    end
    return failures
end

function audit(package_paths, report_dirs, options::AuditOptions)
    failures = String[]
    if options.require_complete && isempty(package_paths)
        push!(failures, "pilot evidence package complete mode requires at least one package artifact")
    end
    for (index, path) in enumerate(package_paths)
        report_dir = isempty(report_dirs) ? nothing : report_dirs[index]
        append!(failures, validate_package(path, options; report_dir))
    end
    return failures
end

function main(arguments=ARGS)
    parsed = try
        parse_arguments(arguments)
    catch error
        println(stderr, "pilot evidence package audit: $(sprint(showerror, error))")
        print_usage(stderr)
        return 2
    end
    parsed === nothing && return 0

    failures = audit(parsed.package_paths, parsed.report_dirs, parsed.options)
    if isempty(failures)
        mode = parsed.options.require_complete ? "complete pilot evidence packages" : "pilot evidence package artifacts"
        println("pilot evidence package audit: $mode passed")
        return 0
    end
    foreach(failure -> println(stderr, "pilot evidence package audit: $failure"), failures)
    return 1
end

end # module PilotEvidencePackageAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(PilotEvidencePackageAudit.main())
end
