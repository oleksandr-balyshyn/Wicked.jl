#!/usr/bin/env julia

module WidgetStabilizationGate

const ROOT = normpath(joinpath(@__DIR__, ".."))

const DEFAULT_STEPS = (
    (
        name="widget coverage audit",
        script=joinpath(ROOT, "scripts", "widget_audit.jl"),
        arguments=("--require-complete",),
    ),
    (
        name="stable widget candidate audit",
        script=joinpath(ROOT, "scripts", "stable_widget_candidates.jl"),
        arguments=("--require-stable",),
    ),
    (
        name="public widget candidate audit",
        script=joinpath(ROOT, "scripts", "public_widget_candidate_audit.jl"),
        arguments=(),
    ),
    (
        name="widget family evidence audit",
        script=joinpath(ROOT, "scripts", "widget_family_evidence_audit.jl"),
        arguments=(),
    ),
    (
        name="experimental promotion audit",
        script=joinpath(ROOT, "scripts", "experimental_promotion_audit.jl"),
        arguments=(),
    ),
    (
        name="widget promotion requirements audit",
        script=joinpath(ROOT, "scripts", "widget_promotion_requirements_audit.jl"),
        arguments=(),
    ),
    (
        name="compatibility widget alias audit",
        script=joinpath(ROOT, "scripts", "compatibility_widget_alias_audit.jl"),
        arguments=(),
    ),
    (
        name="stable promotion packet audit",
        script=joinpath(ROOT, "scripts", "stable_promotion_packet_audit.jl"),
        arguments=(),
    ),
)

const RELEASE_STEPS = (
    (
        name="stable widget stabilization schema audit",
        script=joinpath(ROOT, "scripts", "stable_widget_stabilization_schema_audit.jl"),
        arguments=(),
    ),
    (
        name="stable widget stabilization readiness",
        script=joinpath(ROOT, "scripts", "render_widget_catalog.jl"),
        arguments=("--stabilization-status", "--require-stabilization-ready"),
    ),
    (
        name="stable widget surface release schema audit",
        script=joinpath(ROOT, "scripts", "stable_widget_surface_release_schema_audit.jl"),
        arguments=(),
    ),
    (
        name="stable widget surface release readiness",
        script=joinpath(ROOT, "scripts", "render_widget_catalog.jl"),
        arguments=("--surface-release-status", "--require-surface-release-ready"),
    ),
    (
        name="stable widget coverage completeness",
        script=joinpath(ROOT, "scripts", "render_widget_catalog.jl"),
        arguments=("--coverage-summary", "--format", "tsv", "--require-complete-coverage", "--require-clean-git"),
    ),
    (
        name="widget family release closeout",
        script=joinpath(ROOT, "scripts", "render_widget_family_closeout.jl"),
        arguments=("--release-check", "--summary", "--format", "tsv"),
    ),
    (
        name="reference parity matrix release check",
        script=joinpath(ROOT, "scripts", "render_reference_parity_matrix.jl"),
        arguments=("--release-status", "--require-release-ready"),
    ),
)

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/widget_stabilization_gate.jl [--list] [--release-check]")
    println(io, "")
    println(io, "Runs the widget-stabilization gate used before release review.")
    println(io, "The gate checks widget coverage, stable facade promotion,")
    println(io, "public renderable widget coverage in the candidate ledger,")
    println(io, "family documentation/example/precompile evidence,")
    println(io, "experimental promotion policy, widget promotion requirements,")
    println(io, "compatibility widget aliases,")
    println(io, "and completed stable promotion packet record shape.")
    println(io, "")
    println(io, "Use --release-check to also validate the stable widget stabilization schema,")
    println(io, "stable widget stabilization readiness,")
    println(io, "stable widget-surface release schema,")
    println(io, "stable widget-surface release readiness,")
    println(io, "complete stable widget coverage,")
    println(io, "family closeout readiness, zero blocked widget families,")
    println(io, "reference parity matrix release readiness, and clean release metadata.")
end

function julia_script_command(script::AbstractString, arguments)
    argument_vector = String[string(argument) for argument in arguments]
    return `$(Base.julia_cmd()) --project=$ROOT --startup-file=no $script $argument_vector`
end

function print_steps(steps=DEFAULT_STEPS)
    for (index, step) in enumerate(steps)
        println("$index. $(step.name): $(relpath(step.script, ROOT)) $(join(step.arguments, " "))")
    end
end

function run_step(step)
    isfile(step.script) || error("missing script: $(relpath(step.script, ROOT))")
    println("widget stabilization gate: running $(step.name)")
    command = julia_script_command(step.script, step.arguments)
    process = run(command; wait=false)
    wait(process)
    if !success(process)
        println(stderr, "widget stabilization gate: $(step.name) failed")
        return false
    end
    println("widget stabilization gate: $(step.name) passed")
    return true
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    release_check = "--release-check" in arguments
    list = "--list" in arguments
    known = Set(["--list", "--release-check"])
    unknown = [argument for argument in arguments if argument ∉ known]
    if !isempty(unknown)
        print_usage(stderr)
        return 2
    end
    steps = release_check ? (DEFAULT_STEPS..., RELEASE_STEPS...) : DEFAULT_STEPS
    if list
        print_steps(steps)
        return 0
    end
    failures = String[]
    for step in steps
        run_step(step) || push!(failures, step.name)
    end
    if isempty(failures)
        println("widget stabilization gate: all checks passed")
        return 0
    end
    println(stderr, "widget stabilization gate: failed checks: $(join(failures, ", "))")
    return 1
end

end # module WidgetStabilizationGate

if abspath(PROGRAM_FILE) == @__FILE__
    exit(WidgetStabilizationGate.main())
end
