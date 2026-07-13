#!/usr/bin/env julia

module WidgetFamilyEvidenceAudit

const ROOT = rstrip(normpath(joinpath(@__DIR__, "..")), '/')
const LEDGER = joinpath(ROOT, "api", "widget_family_evidence.tsv")
const PRECOMPILE_SOURCE = joinpath(ROOT, "src", "Precompile.jl")
const STABLE_API_PATH = joinpath(ROOT, "api", "stable_api.tsv")
const EXAMPLES_README = joinpath(ROOT, "examples", "README.md")
const DOCS_README = joinpath(ROOT, "docs", "README.md")
const EXAMPLE_FAMILIES_DOC = joinpath(ROOT, "docs", "EXAMPLE_FAMILIES.md")
const MIN_STABLE_API_TOKENS_PER_FAMILY = 3
const MIN_STABLE_API_TYPE_TOKENS_PER_FAMILY = 3
const MIN_PRECOMPILE_TOKENS_PER_FAMILY = 3

const REQUIRED_FAMILIES = Set([
    "Core layout",
    "Text and structure",
    "Inputs and controls",
    "Navigation",
    "Data and virtualization",
    "Visualization",
    "Rich content",
    "Runtime and services",
    "Toolkit",
    "Testing and semantics",
])

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/widget_family_evidence_audit.jl [widget_family_evidence.tsv]")
    println(io, "")
    println(io, "Checks that every stable widget family has indexed focused docs,")
    println(io, "indexed and family-mapped public examples, stable API tokens,")
    println(io, "and representative precompile workload coverage.")
end

split_list(value::AbstractString) = [strip(item) for item in split(value, ',') if !isempty(strip(item))]

function duplicate_values(values)
    seen = Set{String}()
    duplicates = Set{String}()
    for value in values
        value in seen ? push!(duplicates, value) : push!(seen, value)
    end
    return sort!(collect(duplicates))
end

function read_rows(path::AbstractString=LEDGER)
    isfile(path) || error("missing widget family evidence ledger: $(relpath(path, ROOT))")
    lines = readlines(path)
    isempty(lines) && error("empty widget family evidence ledger: $(relpath(path, ROOT))")
    header = split(first(lines), '\t'; keepempty=true)
    required = ("family", "docs", "examples", "example_family_labels", "stable_api_tokens", "precompile_tokens", "notes")
    for column in required
        column in header || error("widget family evidence ledger is missing `$column` column")
    end
    rows = Dict{String,Dict{String,String}}()
    failures = String[]
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        isempty(strip(line)) && continue
        values = split(line, '\t'; keepempty=true)
        if length(values) != length(header)
            push!(failures, "$(relpath(path, ROOT)):$(offset + 1) has $(length(values)) fields; expected $(length(header))")
            continue
        end
        row = Dict(String(key) => String(value) for (key, value) in zip(header, values))
        family = strip(get(row, "family", ""))
        if isempty(family)
            push!(failures, "$(relpath(path, ROOT)):$(offset + 1) has empty family")
            continue
        end
        if haskey(rows, family)
            push!(failures, "$(relpath(path, ROOT)):$(offset + 1) duplicates family `$family`")
            continue
        end
        rows[family] = row
    end
    return rows, failures
end

function inside_root(path::AbstractString)
    normalized_root = ROOT
    normalized_path = normpath(path)
    return normalized_path == normalized_root || startswith(normalized_path, normalized_root * "/")
end

function path_exists(relative::AbstractString)
    isabspath(relative) && return false
    normalized = normpath(joinpath(ROOT, relative))
    return inside_root(normalized) && isfile(normalized)
end

function indexed_docs_path(relative::AbstractString)
    prefix = "docs/"
    startswith(relative, prefix) && return relative[(lastindex(prefix) + 1):end]
    return relative
end

function example_family_rows(source::AbstractString)
    rows = Dict{String,String}()
    for line in split(source, '\n')
        stripped = strip(line)
        startswith(stripped, "|") || continue
        occursin("`examples/", stripped) || continue
        cells = [strip(cell) for cell in split(stripped, '|')][2:end-1]
        length(cells) >= 2 || continue
        family_label = cells[1]
        example_cell = cells[2]
        match_result = match(r"`([^`]+)`", example_cell)
        match_result === nothing && continue
        rows[String(match_result.captures[1])] = family_label
    end
    return rows
end

function read_stable_api_names(path::AbstractString=STABLE_API_PATH)
    isfile(path) || error("missing stable API ledger: $(relpath(path, ROOT))")
    kinds = Dict{String,String}()
    for line in readlines(path)
        stripped = strip(line)
        isempty(stripped) && continue
        startswith(stripped, "#") && continue
        fields = split(stripped, '\t'; keepempty=true)
        isempty(fields) && continue
        length(fields) >= 2 || continue
        kinds[String(fields[1])] = String(fields[2])
    end
    return kinds
end

stable_api_type_token(stable_api_kinds, token::AbstractString) =
    get(stable_api_kinds, token, "") in ("datatype", "unionall")

token_leaf(token::AbstractString) = last(split(token, '.'))

precompile_token_represents_stable_token(precompile_token::AbstractString, stable_token::AbstractString) =
    precompile_token == stable_token || token_leaf(precompile_token) == stable_token

function regex_escape_literal(value::AbstractString)
    replace(value, r"([\\\^\$\.\|\?\*\+\(\)\[\]\{\}])" => s"\\\1")
end

function source_mentions_token(source::AbstractString, token::AbstractString)
    token_pattern = Regex("(^|[^A-Za-z0-9_!])" * regex_escape_literal(token) * "([^A-Za-z0-9_!.]|\$)")
    return occursin(token_pattern, source)
end

function documentation_mentions_token(docs, token::AbstractString)
    for relative in docs
        path_exists(relative) || continue
        source = read(normpath(joinpath(ROOT, relative)), String)
        source_mentions_token(source, token) && return true
    end
    return false
end

function examples_mention_token(examples, token::AbstractString)
    for relative in examples
        path_exists(relative) || continue
        source = read(normpath(joinpath(ROOT, relative)), String)
        source_mentions_token(source, token) && return true
    end
    return false
end

function audit(
    path::AbstractString=LEDGER;
    precompile_source::AbstractString=PRECOMPILE_SOURCE,
    stable_api_path::AbstractString=STABLE_API_PATH,
    examples_index_source::AbstractString=EXAMPLES_README,
    docs_index_source::AbstractString=DOCS_README,
    example_families_source::AbstractString=EXAMPLE_FAMILIES_DOC,
)
    rows, failures = read_rows(path)
    stable_api_kinds = try
        read_stable_api_names(stable_api_path)
    catch error
        push!(failures, sprint(showerror, error))
        Dict{String,String}()
    end
    docs_index = if isfile(docs_index_source)
        read(docs_index_source, String)
    else
        push!(failures, "missing docs index: $(relpath(docs_index_source, ROOT))")
        nothing
    end
    examples_index = if isfile(examples_index_source)
        read(examples_index_source, String)
    else
        push!(failures, "missing examples index: $(relpath(examples_index_source, ROOT))")
        nothing
    end
    example_families = if isfile(example_families_source)
        read(example_families_source, String)
    else
        push!(failures, "missing example family map: $(relpath(example_families_source, ROOT))")
        nothing
    end
    example_family_index = example_families === nothing ? Dict{String,String}() : example_family_rows(example_families)
    for family in sort!(collect(REQUIRED_FAMILIES))
        haskey(rows, family) || push!(failures, "missing widget family evidence row for `$family`")
    end
    for family in sort!(collect(keys(rows)))
        family in REQUIRED_FAMILIES || push!(failures, "unexpected widget family evidence row `$family`")
        row = rows[family]
        docs = split_list(get(row, "docs", ""))
        examples = split_list(get(row, "examples", ""))
        labels = split_list(get(row, "example_family_labels", ""))
        stable_tokens = split_list(get(row, "stable_api_tokens", ""))
        tokens = split_list(get(row, "precompile_tokens", ""))
        isempty(docs) && push!(failures, "$family has no focused documentation path")
        doc_duplicates = duplicate_values(docs)
        isempty(doc_duplicates) ||
            push!(failures, "$family has duplicate documentation paths: $(join(doc_duplicates, ", "))")
        isempty(examples) && push!(failures, "$family has no public example path")
        example_duplicates = duplicate_values(examples)
        isempty(example_duplicates) ||
            push!(failures, "$family has duplicate public example paths: $(join(example_duplicates, ", "))")
        length(labels) == length(examples) || push!(failures, "$family must list one example family label per example")
        label_duplicates = duplicate_values(labels)
        isempty(label_duplicates) ||
            push!(failures, "$family has duplicate example family labels: $(join(label_duplicates, ", "))")
        isempty(stable_tokens) && push!(failures, "$family has no stable API token")
        length(stable_tokens) >= MIN_STABLE_API_TOKENS_PER_FAMILY ||
            push!(failures, "$family must list at least $MIN_STABLE_API_TOKENS_PER_FAMILY representative stable API tokens")
        stable_type_tokens = [token for token in stable_tokens if stable_api_type_token(stable_api_kinds, token)]
        length(stable_type_tokens) >= MIN_STABLE_API_TYPE_TOKENS_PER_FAMILY ||
            push!(failures, "$family must list at least $MIN_STABLE_API_TYPE_TOKENS_PER_FAMILY representative stable API type tokens")
        stable_duplicates = duplicate_values(stable_tokens)
        isempty(stable_duplicates) ||
            push!(failures, "$family has duplicate stable API tokens: $(join(stable_duplicates, ", "))")
        isempty(tokens) && push!(failures, "$family has no precompile workload token")
        length(tokens) >= MIN_PRECOMPILE_TOKENS_PER_FAMILY ||
            push!(failures, "$family must list at least $MIN_PRECOMPILE_TOKENS_PER_FAMILY representative precompile tokens")
        token_duplicates = duplicate_values(tokens)
        isempty(token_duplicates) ||
            push!(failures, "$family has duplicate precompile tokens: $(join(token_duplicates, ", "))")
        for token in stable_type_tokens
            any(precompile -> precompile_token_represents_stable_token(precompile, token), tokens) ||
                push!(failures, "$family stable API type token `$token` must have a matching precompile token")
        end
        for token in stable_tokens
            haskey(stable_api_kinds, token) || push!(failures, "$family stable API token `$token` is missing from api/stable_api.tsv")
            documentation_mentions_token(docs, token) || push!(failures, "$family stable API token `$token` is not mentioned in focused documentation")
            examples_mention_token(examples, token) || push!(failures, "$family stable API token `$token` is not demonstrated in public examples")
        end
        for relative in docs
            path_exists(relative) || push!(failures, "$family references missing documentation path `$relative`")
            if docs_index !== nothing && !occursin(relative, docs_index) && !occursin(indexed_docs_path(relative), docs_index)
                push!(failures, "$family documentation path `$relative` is not listed in docs/README.md")
            end
        end
        for (index, relative) in enumerate(examples)
            path_exists(relative) || push!(failures, "$family references missing example path `$relative`")
            if examples_index !== nothing && !occursin(relative, examples_index)
                push!(failures, "$family example path `$relative` is not listed in examples/README.md")
            end
            expected_label = index <= length(labels) ? labels[index] : ""
            actual_label = get(example_family_index, relative, nothing)
            if example_families !== nothing && actual_label === nothing
                push!(failures, "$family example path `$relative` is not listed in docs/EXAMPLE_FAMILIES.md")
            elseif example_families !== nothing && actual_label != expected_label
                push!(failures, "$family example path `$relative` is mapped to `$actual_label`; expected `$expected_label`")
            end
        end
        notes = strip(get(row, "notes", ""))
        isempty(notes) && push!(failures, "$family has empty stabilization notes")
        !occursin(family, notes) && push!(failures, "$family stabilization notes must mention the family name")
    end
    if !isfile(precompile_source)
        push!(failures, "missing precompile workload source: $(relpath(precompile_source, ROOT))")
    else
        source = read(precompile_source, String)
        for family in sort!(collect(keys(rows)))
            for token in split_list(get(rows[family], "precompile_tokens", ""))
                source_mentions_token(source, token) || push!(failures, "$family precompile token `$token` is missing from $(relpath(precompile_source, ROOT))")
            end
        end
    end
    return failures
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    length(arguments) <= 1 || error("expected at most one ledger path")
    path = isempty(arguments) ? LEDGER : only(arguments)
    failures = audit(path)
    if isempty(failures)
        println("widget family evidence audit: all stable widget families have indexed docs, family-mapped examples, and precompile coverage")
        return 0
    end
    for failure in failures
        println(stderr, "widget family evidence audit: $failure")
    end
    return 1
end

end # module WidgetFamilyEvidenceAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(WidgetFamilyEvidenceAudit.main())
end
