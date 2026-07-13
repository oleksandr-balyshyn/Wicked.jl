module ComponentCatalogPublicMap

export PUBLIC_WIDGET_NAME_MAP_HEADER,
    missing_renderables,
    read_exclusions,
    read_entries,
    read_widget_coverage_renderables,
    state_contract_names,
    widget_names

const PUBLIC_WIDGET_NAME_MAP_HEADER = "| Cross-library concept | Wicked API name | State contract |"
const SCRIPT_ROOT = normpath(joinpath(@__DIR__, ".."))
const DEFAULT_COMPONENT_CATALOG = joinpath(SCRIPT_ROOT, "docs", "COMPONENT_CATALOG.md")
const DEFAULT_WIDGET_COVERAGE = joinpath(SCRIPT_ROOT, "api", "widget_coverage.tsv")

function _relative_path(path::AbstractString, root::AbstractString)
    try
        return relpath(path, root)
    catch
        return path
    end
end

function _code_names(cell::AbstractString)
    names = String[]
    for matched in eachmatch(r"`([^`]+)`", cell)
        push!(names, matched.captures[1])
    end
    return names
end

function read_entries(path::AbstractString; root::AbstractString=dirname(dirname(path)))
    isfile(path) || error("missing component catalog: $(_relative_path(path, root))")
    lines = readlines(path)
    start = findfirst(==("## Public widget-name map"), lines)
    start === nothing && error("component catalog missing Public widget-name map")
    has_expected_header = false
    for offset in start:length(lines)
        line = lines[offset]
        offset != start && startswith(line, "## ") && break
        if occursin(PUBLIC_WIDGET_NAME_MAP_HEADER, line)
            has_expected_header = true
            break
        end
    end
    has_expected_header || error(
        "component catalog Public widget-name map missing expected table header",
    )

    entries = Tuple{String,String}[]
    entry_lines = Int[]
    entry_concepts = String[]
    for offset in start:length(lines)
        line = lines[offset]
        startswith(line, "## ") && line != "## Public widget-name map" && break
        startswith(strip(line), "|") || continue
        occursin("|---", line) && continue
        occursin("Wicked API name", line) && continue
        values = String[]
        for value in split(line, "|")
            stripped = strip(value)
            isempty(stripped) || push!(values, stripped)
        end
        length(values) >= 3 || error(
            "$(_relative_path(path, root)):$offset has malformed Public widget-name map row",
        )
        !isempty(_code_names(values[2])) || error(
            "$(_relative_path(path, root)):$offset Public widget-name map row has no backticked Wicked API widget name",
        )
        state_names = _code_names(values[3])
        values[3] == "Stateless" || !isempty(state_names) || error(
            "$(_relative_path(path, root)):$offset Public widget-name map row has no backticked state contract or Stateless marker",
        )
        push!(entries, (values[2], values[3]))
        push!(entry_lines, offset)
        push!(entry_concepts, values[1])
    end
    isempty(entries) && error("component catalog Public widget-name map has no rows")
    seen_concepts = Dict{String,Int}()
    for (index, concept) in pairs(entry_concepts)
        previous = get(seen_concepts, concept, nothing)
        previous === nothing || error(
            "component catalog Public widget-name map lists concept `$concept` in multiple rows: line $(entry_lines[previous]) and line $(entry_lines[index])",
        )
        seen_concepts[concept] = index
    end
    seen_widgets = Dict{String,Tuple{Int,Int}}()
    for (index, (widget_cell, _)) in pairs(entries)
        for name in _code_names(widget_cell)
            previous = get(seen_widgets, name, nothing)
            previous === nothing || error(
                "component catalog Public widget-name map lists `$name` in multiple rows: line $(previous[2]) ($(entry_concepts[previous[1]])) and line $(entry_lines[index]) ($(entry_concepts[index]))",
            )
            seen_widgets[name] = (index, entry_lines[index])
        end
    end
    return entries
end

function read_exclusions(path::AbstractString; root::AbstractString=dirname(dirname(path)))
    isfile(path) || error("missing component catalog: $(_relative_path(path, root))")
    lines = readlines(path)
    start = findfirst(==("## Internal renderable exclusions"), lines)
    start === nothing && return Set{String}()
    exclusions = Set{String}()
    for offset in start:length(lines)
        line = lines[offset]
        offset != start && startswith(line, "## ") && break
        startswith(strip(line), "|") || continue
        occursin("|---", line) && continue
        occursin("Renderable", line) && continue
        values = String[]
        for value in split(line, "|")
            stripped = strip(value)
            isempty(stripped) || push!(values, stripped)
        end
        length(values) >= 2 || error(
            "$(_relative_path(path, root)):$offset has malformed Internal renderable exclusions row",
        )
        reason = strip(values[2])
        _valid_exclusion_reason(reason) || error(
            "$(_relative_path(path, root)):$offset exclusion reason must explain why the renderable is internal and where application developers should go instead",
        )
        names = _code_names(values[1])
        !isempty(names) || error(
            "$(_relative_path(path, root)):$offset exclusion row has no backticked renderable name",
        )
        union!(exclusions, names)
    end
    return exclusions
end

function _valid_exclusion_reason(reason::AbstractString)
    normalized = lowercase(strip(reason))
    length(normalized) >= 48 || return false
    explains_internal_status = any(term -> occursin(term, normalized), (
        "internal",
        "infrastructure",
        "not application-facing",
    ))
    routes_developers = any(term -> occursin(term, normalized), (
        "application",
        "developers",
        "use ",
        "instead",
        "build ",
    ))
    return explains_internal_status && routes_developers
end

function _bare_renderable_name(qualified::AbstractString)
    text = String(qualified)
    startswith(text, "Wicked.") && (text = text[(lastindex("Wicked.") + 1):end])
    return String(last(split(text, '.')))
end

function read_widget_coverage_renderables(path::AbstractString; root::AbstractString=dirname(dirname(path)))
    isfile(path) || error("missing widget coverage ledger: $(_relative_path(path, root))")
    lines = readlines(path)
    isempty(lines) && error("empty widget coverage ledger: $(_relative_path(path, root))")
    header = split(first(lines), '\t'; keepempty=true)
    widget_index = findfirst(==("widget_type"), header)
    widget_index === nothing && error("widget coverage ledger missing widget_type column")
    names = Set{String}()
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        isempty(strip(line)) && continue
        fields = split(line, '\t'; keepempty=true)
        length(fields) == length(header) || error(
            "$(_relative_path(path, root)):$(offset + 1) has $(length(fields)) fields; expected $(length(header))",
        )
        push!(names, _bare_renderable_name(fields[widget_index]))
    end
    return names
end

function missing_renderables(
    catalog_path::AbstractString=DEFAULT_COMPONENT_CATALOG;
    coverage_path::AbstractString=DEFAULT_WIDGET_COVERAGE,
    root::AbstractString=SCRIPT_ROOT,
)
    entries = read_entries(catalog_path; root)
    mapped = widget_names(entries)
    exclusions = read_exclusions(catalog_path; root)
    renderables = read_widget_coverage_renderables(coverage_path; root)
    return setdiff(renderables, union(mapped, exclusions))
end

function widget_names(entries)
    names = Set{String}()
    for (widget_cell, _) in entries
        union!(names, _code_names(widget_cell))
    end
    return names
end

function state_contract_names(entries)
    names = Set{String}()
    for (_, state_cell) in entries
        for name in _code_names(state_cell)
            name == "Stateless" || push!(names, name)
        end
    end
    return names
end

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/component_catalog_public_map.jl [--list-unmapped|--list-exclusions] [component-catalog.md]")
    println(io, "")
    println(io, "Validates the Wicked public widget-name map and reports row, widget, and state-contract counts.")
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    list_unmapped = "--list-unmapped" in arguments
    list_exclusions = "--list-exclusions" in arguments
    if list_unmapped && list_exclusions
        print_usage(stderr)
        return 2
    end
    paths = [
        argument for argument in arguments if argument != "--list-unmapped" &&
            argument != "--list-exclusions"
    ]
    if length(paths) > 1
        print_usage(stderr)
        return 2
    end
    path = isempty(paths) ? DEFAULT_COMPONENT_CATALOG : first(paths)
    entries = read_entries(path; root=SCRIPT_ROOT)
    widgets = widget_names(entries)
    states = state_contract_names(entries)
    exclusions = read_exclusions(path; root=SCRIPT_ROOT)
    missing = missing_renderables(path; root=SCRIPT_ROOT)
    if list_exclusions
        foreach(name -> println(name), sort!(collect(exclusions)))
        return 0
    end
    if list_unmapped
        foreach(name -> println(name), sort!(collect(missing)))
        return isempty(missing) ? 0 : 1
    end
    println(
        "component catalog public map: $(length(entries)) rows, $(length(widgets)) widget names, $(length(states)) state contracts, $(length(exclusions)) exclusions, $(length(missing)) unmapped renderables",
    )
    if !isempty(missing)
        for name in sort!(collect(missing))
            println(stderr, "component catalog public map: unmapped direct renderable `$name`")
        end
        return 1
    end
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end

end # module ComponentCatalogPublicMap
