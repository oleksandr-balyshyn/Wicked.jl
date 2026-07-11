#!/usr/bin/env julia

using Test
using Wicked

const ROOT = normpath(joinpath(@__DIR__, ".."))
const BASELINE = joinpath(ROOT, "api", "public_api.tsv")
const STABLE_BASELINE = joinpath(ROOT, "api", "stable_api.tsv")
const EXPERIMENTAL_BASELINE = joinpath(ROOT, "api", "experimental_api.tsv")

function binding_kind(value)
    value isa Module && return "module"
    value isa Function && return "function"
    value isa DataType && return "datatype"
    value isa UnionAll && return "unionall"
    return "value"
end

function public_api_entries(target::Module=Wicked)
    names = sort!(collect(Base.names(target; all=false, imported=false)); by=string)
    return ["$(name)\t$(binding_kind(getfield(target, name)))" for name in names]
end

function write_baseline!()
    baselines = (
        (BASELINE, "Wicked.jl reviewed root compatibility API", public_api_entries()),
        (STABLE_BASELINE, "Wicked.API candidate stable API", public_api_entries(Wicked.API)),
        (EXPERIMENTAL_BASELINE, "Wicked.Experimental reviewed pre-1.0 API", public_api_entries(Wicked.Experimental)),
    )
    mkpath(dirname(BASELINE))
    for (path, title, entries) in baselines
        open(path, "w") do output
            println(output, "# $title")
            println(output, "# name<TAB>binding-kind")
            foreach(entry -> println(output, entry), entries)
        end
        println("API audit: wrote $(length(entries)) entries to $(relpath(path, ROOT))")
    end
end

function read_baseline(path)
    isfile(path) || error("missing API baseline: $(relpath(path, ROOT))")
    return String[
        line for line in readlines(path)
        if !isempty(strip(line)) && !startswith(strip(line), '#')
    ]
end

function audit()
    failures = String[]
    surfaces = (
        ("root", public_api_entries(), read_baseline(BASELINE)),
        ("stable", public_api_entries(Wicked.API), read_baseline(STABLE_BASELINE)),
        ("experimental", public_api_entries(Wicked.Experimental), read_baseline(EXPERIMENTAL_BASELINE)),
    )
    for (surface, current, expected) in surfaces
        current == expected && continue
        current_set = Set(current)
        expected_set = Set(expected)
        append!(failures, ("unreviewed $surface API addition or kind change: $entry" for entry in sort!(collect(setdiff(current_set, expected_set)))))
        append!(failures, ("unreviewed $surface API removal or kind change: $entry" for entry in sort!(collect(setdiff(expected_set, current_set)))))
    end

    missing_docs = Symbol[]
    root_docs = 0
    value_docs = 0
    for target in (Wicked.API, Wicked.Experimental)
        for name in Base.names(target; all=false, imported=false)
            value = getfield(target, name)
            if Docs.hasdoc(target, name)
                root_docs += 1
            elseif try
                Docs.doc(value) !== nothing
            catch
                false
            end
                value_docs += 1
            else
                push!(missing_docs, name)
            end
        end
    end
    append!(failures, ("export has no discoverable documentation: $name" for name in sort!(missing_docs; by=string)))

    ambiguities = Test.detect_ambiguities(Wicked; recursive=true)
    append!(failures, ("method ambiguity: $(sprint(show, ambiguity))" for ambiguity in ambiguities))
    Base.get_extension(Wicked, :WickedHTTPWebSocketsExt) === nothing ||
        push!(failures, "HTTP extension loaded without HTTP being requested")

    println("API audit: $(length(first(surfaces)[2])) reviewed root exports")
    println("API audit: $(length(surfaces[2][2])) candidate stable exports")
    println("API audit: $(length(surfaces[3][2])) reviewed experimental exports")
    println("API audit: $root_docs facade binding docs, $value_docs canonical value/owner docs")
    println("API audit: $(length(ambiguities)) method ambiguities")
    return failures
end

function main(arguments)
    if arguments == ["--write-baseline"]
        write_baseline!()
        return 0
    elseif !isempty(arguments)
        println(stderr, "usage: api_audit.jl [--write-baseline]")
        return 2
    end
    failures = audit()
    foreach(failure -> println(stderr, "API audit: ", failure), failures)
    isempty(failures) || return 1
    println("API audit: all checks passed")
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end
