#!/usr/bin/env julia

module UnicodeWidthCorpusAudit

using Unicode
using Wicked.API: UnicodeWidthPolicy, grapheme_width, text_width

const ROOT = normpath(joinpath(@__DIR__, ".."))
const CORPUS = joinpath(ROOT, "api", "unicode_width_corpus.tsv")
const REQUIRED_COLUMNS = (
    "case",
    "escaped",
    "expected_graphemes",
    "expected_default_width",
    "expected_ambiguous_width",
    "notes",
)

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/unicode_width_corpus_audit.jl [api/unicode_width_corpus.tsv]")
    println(io, "")
    println(io, "Validates the checked-in Unicode grapheme and terminal-width corpus.")
end

function decode_escaped(value::AbstractString)
    bytes = codeunits(value)
    output = IOBuffer()
    index = 1
    while index <= length(bytes)
        character = Char(bytes[index])
        if character != '\\'
            print(output, character)
            index += 1
            continue
        end
        index += 1
        index <= length(bytes) || error("trailing escape in `$value`")
        marker = Char(bytes[index])
        if marker == 'u' || marker == 'U'
            width = marker == 'u' ? 4 : 8
            stop = index + width
            stop <= length(bytes) || error("short $marker escape in `$value`")
            hex = String(Vector{UInt8}(bytes[(index + 1):stop]))
            codepoint = parse(UInt32, hex; base=16)
            print(output, Char(codepoint))
            index = stop + 1
        elseif marker == 'n'
            print(output, '\n')
            index += 1
        elseif marker == 't'
            print(output, '\t')
            index += 1
        elseif marker == 'r'
            print(output, '\r')
            index += 1
        elseif marker == '\\'
            print(output, '\\')
            index += 1
        else
            error("unsupported escape \\$marker in `$value`")
        end
    end
    return String(take!(output))
end

function parse_integer(value::AbstractString, path::AbstractString, line_number::Integer, column::AbstractString)
    try
        return parse(Int, strip(value))
    catch error
        throw(ArgumentError("$(relpath(path, ROOT)):$line_number has invalid integer in `$column`: $(sprint(showerror, error))"))
    end
end

function read_rows(path::AbstractString=CORPUS)
    isfile(path) || error("missing Unicode width corpus: $(relpath(path, ROOT))")
    lines = readlines(path)
    header_index = findfirst(line -> !isempty(strip(line)) && !startswith(strip(line), "#"), lines)
    header_index === nothing && error("Unicode width corpus has no header: $(relpath(path, ROOT))")
    header = split(lines[header_index], '\t')
    indexes = Dict(name => index for (index, name) in pairs(header))
    for column in REQUIRED_COLUMNS
        haskey(indexes, column) || error("Unicode width corpus is missing `$column` column")
    end
    rows = NamedTuple[]
    seen = Set{String}()
    for line_number in (header_index + 1):length(lines)
        line = lines[line_number]
        stripped = strip(line)
        isempty(stripped) && continue
        startswith(stripped, "#") && continue
        fields = split(line, '\t'; keepempty=true)
        length(fields) == length(header) ||
            error("$(relpath(path, ROOT)):$line_number has $(length(fields)) fields, expected $(length(header))")
        name = strip(fields[indexes["case"]])
        isempty(name) && error("$(relpath(path, ROOT)):$line_number has empty case name")
        name in seen && error("$(relpath(path, ROOT)):$line_number duplicates case `$name`")
        push!(seen, name)
        push!(
            rows,
            (
                line=line_number,
                name=name,
                escaped=fields[indexes["escaped"]],
                expected_graphemes=parse_integer(fields[indexes["expected_graphemes"]], path, line_number, "expected_graphemes"),
                expected_default_width=parse_integer(fields[indexes["expected_default_width"]], path, line_number, "expected_default_width"),
                expected_ambiguous_width=parse_integer(fields[indexes["expected_ambiguous_width"]], path, line_number, "expected_ambiguous_width"),
                notes=strip(fields[indexes["notes"]]),
            ),
        )
    end
    return rows
end

function audit(path::AbstractString=CORPUS)
    failures = String[]
    rows = try
        read_rows(path)
    catch error
        return String[sprint(showerror, error)]
    end
    isempty(rows) && push!(failures, "Unicode width corpus has no cases")
    default_policy = UnicodeWidthPolicy(1)
    ambiguous_policy = UnicodeWidthPolicy(2)
    required_cases = Set((
        "ascii-letter",
        "cjk-wide",
        "greek-ambiguous",
        "box-drawing-ambiguous",
        "latin-combining",
        "combining-mark-only",
        "emoji-zwj-woman-technologist",
        "mixed-wide-text",
        "mixed-ambiguous-text",
    ))
    observed = Set(row.name for row in rows)
    for name in sort!(collect(setdiff(required_cases, observed)))
        push!(failures, "Unicode width corpus missing required case `$name`")
    end
    for row in rows
        value = try
            decode_escaped(row.escaped)
        catch error
            push!(failures, "api/unicode_width_corpus.tsv:$(row.line) $(row.name) has invalid escaped value: $(sprint(showerror, error))")
            continue
        end
        graphemes = collect(Unicode.graphemes(value))
        length(graphemes) == row.expected_graphemes ||
            push!(failures, "$(row.name) expected $(row.expected_graphemes) grapheme(s), got $(length(graphemes))")
        isempty(row.notes) && push!(failures, "$(row.name) must document why the case exists")
        default_width = text_width(value, default_policy)
        ambiguous_width = text_width(value, ambiguous_policy)
        default_width == row.expected_default_width ||
            push!(failures, "$(row.name) default text width expected $(row.expected_default_width), got $default_width")
        ambiguous_width == row.expected_ambiguous_width ||
            push!(failures, "$(row.name) ambiguous text width expected $(row.expected_ambiguous_width), got $ambiguous_width")
        if length(graphemes) == 1
            default_grapheme_width = grapheme_width(default_policy, only(graphemes))
            ambiguous_grapheme_width = grapheme_width(ambiguous_policy, only(graphemes))
            default_grapheme_width == row.expected_default_width ||
                push!(failures, "$(row.name) default grapheme width expected $(row.expected_default_width), got $default_grapheme_width")
            ambiguous_grapheme_width == row.expected_ambiguous_width ||
                push!(failures, "$(row.name) ambiguous grapheme width expected $(row.expected_ambiguous_width), got $ambiguous_grapheme_width")
        end
    end
    return failures
end

function main(arguments=ARGS)
    "--help" in arguments && (print_usage(); return 0)
    path = isempty(arguments) ? CORPUS : only(arguments)
    failures = audit(path)
    if isempty(failures)
        println("Unicode width corpus audit: checked $(length(read_rows(path))) cases")
        return 0
    end
    foreach(failure -> println(stderr, "Unicode width corpus audit: $failure"), failures)
    return 1
end

end # module UnicodeWidthCorpusAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(UnicodeWidthCorpusAudit.main())
end
