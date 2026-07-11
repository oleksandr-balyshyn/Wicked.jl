#!/usr/bin/env julia

using Wicked
using Test

const ROOT = normpath(joinpath(@__DIR__, ".."))
const SOURCE_DIRECTORIES = ("src", "test", "examples", "benchmark", "scripts")
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
    sort!(files)
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

function check_public_exports!()
    failures = String[]
    for name in names(Wicked; all=false, imported=false)
        isdefined(Wicked, name) || push!(failures, "Wicked exports undefined binding: $name")
    end
    return failures
end

function check_method_ambiguities!()
    ambiguities = Test.detect_ambiguities(Wicked; recursive=true)
    return String[
        "ambiguous public/internal dispatch: $(sprint(show, ambiguity))"
        for ambiguity in ambiguities
    ]
end

function check_optional_loading!()
    Base.get_extension(Wicked, :WickedHTTPWebSocketsExt) === nothing ||
        return ["HTTP extension loaded without HTTP being requested"]
    return String[]
end

function public_binding_kind(value)
    value isa Module && return "module"
    value isa Function && return "function"
    value isa DataType && return "datatype"
    value isa UnionAll && return "unionall"
    return "value"
end

function check_public_api_baseline!()
    failures = String[]
    for (label, target, path) in (
        ("root", Wicked, API_BASELINE),
        ("stable", Wicked.API, STABLE_API_BASELINE),
        ("experimental", Wicked.Experimental, EXPERIMENTAL_API_BASELINE),
    )
        isfile(path) || begin
            push!(failures, "missing reviewed $label API baseline: $(relpath(path, ROOT))")
            continue
        end
        expected = String[
            line for line in readlines(path)
            if !isempty(strip(line)) && !startswith(strip(line), '#')
        ]
        names = sort!(collect(Base.names(target; all=false, imported=false)); by=string)
        current = ["$(name)\t$(public_binding_kind(getfield(target, name)))" for name in names]
        current == expected && continue
        current_set = Set(current)
        expected_set = Set(expected)
        append!(failures, ("unreviewed $label API addition or kind change: $entry" for entry in sort!(collect(setdiff(current_set, expected_set)))))
        append!(failures, ("unreviewed $label API removal or kind change: $entry" for entry in sort!(collect(setdiff(expected_set, current_set)))))
    end
    return failures
end

function check_facade_overlap!()
    stable = Set(Base.names(Wicked.API; all=false, imported=false))
    experimental = Set(Base.names(Wicked.Experimental; all=false, imported=false))
    return String[
        "facade export is both stable and experimental: $name"
        for name in sort!(collect(intersect(stable, experimental)); by=string)
    ]
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

function check_policy_files!()
    return String[
        "missing required repository policy file: $name"
        for name in REQUIRED_POLICY_FILES
        if !isfile(joinpath(ROOT, name))
    ]
end

function check_manifest_layout!()
    failures = String[]
    generic = joinpath(ROOT, "Manifest.toml")
    isfile(generic) && push!(
        failures,
        "generic Manifest.toml is forbidden; use one manifest per supported Julia minor",
    )
    for (name, version_prefix) in VERSIONED_MANIFESTS
        path = joinpath(ROOT, name)
        if !isfile(path)
            push!(failures, "missing version-specific environment file: $name")
            continue
        end
        content = read(path, String)
        marker = "julia_version = \"$version_prefix"
        occursin(marker, content) || push!(
            failures,
            "$name was not generated by Julia $version_prefix*",
        )
    end
    return failures
end

function markdown_files()
    files = String[]
    for name in readdir(ROOT; join=true)
        isfile(name) && endswith(name, ".md") && push!(files, name)
    end
    append!(files, files_with_extension(("docs", "benchmark"), ".md"))
    sort!(unique!(files))
end

function check_parity_survey!()
    include(joinpath(ROOT, "scripts", "parity_audit.jl"))
    return Base.invokelatest(() -> begin
        audit = getfield(Main, :ParityAudit)
        getfield(audit, :check_reference_parity)()
    end)
end

function check_stable_widget_surface!()
    include(joinpath(ROOT, "scripts", "stable_widget_candidates.jl"))
    return Base.invokelatest(() -> begin
        rows = getfield(Main, :candidate_rows)()
        failures = String[]
        for row in rows
            row.status == "stable" && continue
            push!(
                failures,
                "$(row.widget) is $(row.status) on $(row.surface): $(row.reason)",
            )
        end
        return failures
    end)
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
            ispath(resolved) || push!(
                failures,
                "$(relpath(path, ROOT)): missing local Markdown target $(repr(target))",
            )
        end
    end
    return failures
end

function main()
    checks = (
        "Julia syntax" => check_julia_syntax!,
        "public exports" => check_public_exports!,
        "method ambiguities" => check_method_ambiguities!,
        "optional loading" => check_optional_loading!,
        "public API baseline" => check_public_api_baseline!,
        "facade overlap" => check_facade_overlap!,
        "public documentation" => check_public_documentation!,
        "repository policy" => check_policy_files!,
        "versioned manifests" => check_manifest_layout!,
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

exit(main())
