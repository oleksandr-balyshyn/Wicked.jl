#!/usr/bin/env julia

module PublicWidgetCandidateAudit

using Wicked

include(joinpath(@__DIR__, "stable_widget_candidates.jl"))

const REPORT_COLUMNS = ("widget", "source", "surface", "status", "reason")

function binding_kind(value)
    value isa Module && return "module"
    value isa Function && return "function"
    value isa DataType && return "datatype"
    value isa UnionAll && return "unionall"
    return "value"
end

function renderable_widget_names()
    names = Set{String}()
    for method in methods(Wicked.render!)
        signature = Base.unwrap_unionall(method.sig)
        parameters = signature.parameters
        length(parameters) >= 4 || continue
        buffer_type = parameters[2]
        buffer_type isa Type && buffer_type <: Wicked.Buffer || continue
        widget_type = parameters[3]
        (widget_type isa Type || widget_type isa UnionAll) || continue
        widget_type in (Any, Wicked.Buffer, Wicked.Frame) && continue
        startswith(string(parentmodule(widget_type)), "Wicked") || continue
        push!(names, bare_name(normalized_type_name(widget_type)))
    end
    return names
end

function api_renderable_widget_names(target=Wicked.API)
    renderables = renderable_widget_names()
    names = Set{String}()
    for name in Base.names(target; all=false, imported=false)
        isdefined(target, name) || continue
        value = getfield(target, name)
        stable_widget_binding(binding_kind(value)) || continue
        exported = String(name)
        bound = bare_name(normalized_type_name(value))
        (exported in renderables || bound in renderables) && push!(names, exported)
    end
    return names
end

function read_candidate_report(path::AbstractString=REPORT_PATH)
    isfile(path) || error("missing stable widget candidate report: $(relpath(path, ROOT))")
    lines = readlines(path)
    isempty(lines) && error("empty stable widget candidate report: $(relpath(path, ROOT))")
    header = Tuple(split(first(lines), '\t'; keepempty=true))
    header == REPORT_COLUMNS || error(
        "stable widget candidate report header must be $(join(REPORT_COLUMNS, ','))",
    )
    rows = Vector{NamedTuple{(:widget,:source,:surface,:status,:reason),NTuple{5,String}}}()
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        isempty(strip(line)) && continue
        fields = split(line, '\t'; keepempty=true)
        length(fields) == length(REPORT_COLUMNS) || error(
            "$(relpath(path, ROOT)):$(offset + 1) has $(length(fields)) fields; expected $(length(REPORT_COLUMNS))",
        )
        push!(
            rows,
            (
                widget=String(fields[1]),
                source=String(fields[2]),
                surface=String(fields[3]),
                status=String(fields[4]),
                reason=String(fields[5]),
            ),
        )
    end
    return rows
end

function expected_report_lines(rows)
    lines = ["widget\tsource\tsurface\tstatus\treason"]
    append!(
        lines,
        join((row.widget, row.source, row.surface, row.status, row.reason), '\t')
        for row in rows
    )
    return lines
end

function report_current_failures(path::AbstractString=REPORT_PATH; rows=candidate_rows())
    if !isfile(path)
        return ["missing stable widget candidate report: $(relpath(path, ROOT))"]
    end
    actual = readlines(path)
    expected = expected_report_lines(rows)
    actual == expected && return String[]
    return [
        "stable widget candidate report is stale; run julia --project=. --startup-file=no scripts/stable_widget_candidates.jl --write-report",
    ]
end

function candidate_row_map(rows)
    mapped = Dict{String,NamedTuple{(:widget,:source,:surface,:status,:reason),NTuple{5,String}}}()
    duplicates = String[]
    for row in rows
        if haskey(mapped, row.widget)
            push!(duplicates, row.widget)
        else
            mapped[row.widget] = row
        end
    end
    return mapped, sort!(unique(duplicates))
end

function public_surface_failures(rows, public_widgets=api_renderable_widget_names())
    mapped, duplicates = candidate_row_map(rows)
    failures = String[
        "duplicate widget candidate row: $widget"
        for widget in duplicates
    ]
    for widget in sort!(collect(public_widgets))
        row = get(mapped, widget, nothing)
        if row === nothing
            push!(failures, "public renderable widget is missing from stable candidate evidence: $widget")
            continue
        end
        row.surface == "stable" || push!(
            failures,
            "public renderable widget is not on the stable surface: $widget ($(row.surface))",
        )
        row.status == "stable" || push!(
            failures,
            "public renderable widget is not stable: $widget ($(row.status): $(row.reason))",
        )
    end
    for row in rows
        row.surface == "stable" && row.status == "stable" || continue
        row.widget in public_widgets || push!(
            failures,
            "stable widget candidate is not exported as a public renderable Wicked.API widget: $(row.widget)",
        )
    end
    return failures
end

function audit(; rows=candidate_rows(), public_widgets=api_renderable_widget_names(), report_path::AbstractString=REPORT_PATH)
    failures = report_current_failures(report_path; rows=rows)
    append!(failures, public_surface_failures(rows, public_widgets))
    return failures
end

function print_public_widgets(io::IO=stdout)
    for name in sort!(collect(api_renderable_widget_names()))
        println(io, name)
    end
end

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/public_widget_candidate_audit.jl [--list-public]")
    println(io, "")
    println(io, "Checks that every public renderable Wicked.API widget is covered by")
    println(io, "api/stable_widget_candidates.tsv and that every stable candidate is")
    println(io, "actually exported as a public renderable Wicked.API widget.")
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    list_public = "--list-public" in arguments
    known = Set(["--list-public"])
    unknown = [argument for argument in arguments if argument ∉ known]
    if !isempty(unknown)
        print_usage(stderr)
        return 2
    end
    if list_public
        print_public_widgets()
        return 0
    end
    failures = audit()
    if isempty(failures)
        println("public widget candidate audit: all public renderable widgets have stable candidate evidence")
        return 0
    end
    foreach(failure -> println(stderr, "public widget candidate audit: $failure"), failures)
    return 1
end

end # module PublicWidgetCandidateAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(PublicWidgetCandidateAudit.main())
end
