#!/usr/bin/env julia

module CompatibilityWidgetAliasAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const CANDIDATES_PATH = joinpath(ROOT, "api", "stable_widget_candidates.tsv")
const COMPONENT_CATALOG_PATH = joinpath(ROOT, "docs", "COMPONENT_CATALOG.md")
const SOURCE_ROOT = joinpath(ROOT, "src")

include(joinpath(ROOT, "scripts", "component_catalog_public_map.jl"))

function read_stable_widget_names()
    isfile(CANDIDATES_PATH) || error("missing stable widget candidate ledger: $(relpath(CANDIDATES_PATH, ROOT))")
    lines = readlines(CANDIDATES_PATH)
    isempty(lines) && error("empty stable widget candidate ledger: $(relpath(CANDIDATES_PATH, ROOT))")
    header = split(first(lines), '\t'; keepempty=true)
    indexes = Dict(name => index for (index, name) in pairs(header))
    haskey(indexes, "widget") || error("stable widget candidate ledger is missing widget column")
    haskey(indexes, "status") || error("stable widget candidate ledger is missing status column")

    widgets = Set{String}()
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        isempty(strip(line)) && continue
        fields = split(line, '\t'; keepempty=true)
        length(fields) == length(header) || error(
            "$(relpath(CANDIDATES_PATH, ROOT)):$(offset + 1) has $(length(fields)) fields; expected $(length(header))",
        )
        fields[indexes["status"]] == "stable" || continue
        push!(widgets, String(fields[indexes["widget"]]))
    end
    return widgets
end

function read_component_catalog_widget_names()
    entries = getfield(ComponentCatalogPublicMap, :read_entries)(COMPONENT_CATALOG_PATH; root=ROOT)
    return getfield(ComponentCatalogPublicMap, :widget_names)(entries)
end

function source_files(source_root::AbstractString=SOURCE_ROOT)
    files = String[]
    for (path, subdirectories, names) in walkdir(source_root)
        filter!(name -> name != ".git", subdirectories)
        for name in names
            endswith(name, ".jl") && push!(files, joinpath(path, name))
        end
    end
    return sort!(files)
end

function find_widget_aliases(widgets; source_root::AbstractString=SOURCE_ROOT)
    aliases = NamedTuple{(:path,:line,:widget,:target),Tuple{String,Int,String,String}}[]
    pattern = r"^\s*const\s+([A-Z][A-Za-z0-9_]*)\s*=\s*([A-Z][A-Za-z0-9_.]*)\s*(?:#.*)?$"
    for path in source_files(source_root)
        for (line_number, line) in enumerate(eachline(path))
            match_result = match(pattern, line)
            match_result === nothing && continue
            widget, target = String(match_result.captures[1]), String(match_result.captures[2])
            widget in widgets || continue
            push!(aliases, (
                path=relpath(path, source_root),
                line=line_number,
                widget=widget,
                target=target,
            ))
        end
    end
    return aliases
end

function main(arguments=ARGS)
    isempty(arguments) || error("unknown arguments: $(join(arguments, ", "))")
    widgets = union(read_stable_widget_names(), read_component_catalog_widget_names())
    aliases = find_widget_aliases(widgets)
    if isempty(aliases)
        println("compatibility widget alias audit: no stable direct-renderable or public widget-name-map aliases found")
        return 0
    end
    for alias in aliases
        println(
            stderr,
            "compatibility widget alias audit: $(alias.path):$(alias.line): $(alias.widget) is a bare alias to $(alias.target)",
        )
    end
    println(
        stderr,
        "compatibility widget alias audit: use a first-class wrapper for stable widget names, or remove the name from the direct-renderable ledger and public widget-name map",
    )
    return 1
end

end # module CompatibilityWidgetAliasAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(CompatibilityWidgetAliasAudit.main())
end
