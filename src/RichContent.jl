module RichContent

using Unicode: graphemes

export SourcePosition,
       SourceRange,
       MarkdownDiagnostic,
       MarkdownDocument,
       MarkdownBlock,
       MarkdownInline,
       HeadingBlock,
       ParagraphBlock,
       QuoteBlock,
       ListItem,
       ListBlock,
       CodeFenceBlock,
       ThematicBreak,
       MarkdownTable,
       PlainText,
       EmphasisInline,
       StrongInline,
       StrikeInline,
       InlineCode,
       MarkdownLink,
       MarkdownImage,
       SoftBreak,
       HardBreak,
       parse_markdown,
       SemanticTokenKind,
       PlainToken,
       KeywordToken,
       TypeToken,
       FunctionToken,
       StringToken,
       NumberToken,
       CommentToken,
       OperatorToken,
       PunctuationToken,
       ConstantToken,
       ErrorToken,
       SyntaxToken,
       SyntaxRegistry,
       default_syntax_registry,
       register_syntax!,
       highlight,
       MarkdownLinkPolicy,
       markdown_link_safe,
       LinkTarget,
       RenderedLink,
       RichSpan,
       RichLine,
       RichDocument,
       render_markdown,
       plain_text,
       link_by_id,
       links_at_line

struct SourcePosition
    line::Int
    column::Int

    function SourcePosition(line::Integer, column::Integer)
        line > 0 || throw(ArgumentError("source line must be positive"))
        column > 0 || throw(ArgumentError("source column must be positive"))
        new(Int(line), Int(column))
    end
end

struct SourceRange
    start::SourcePosition
    stop::SourcePosition
end

struct MarkdownDiagnostic
    severity::Symbol
    message::String
    source::SourceRange
end

abstract type MarkdownBlock end
abstract type MarkdownInline end

struct PlainText <: MarkdownInline
    value::String
    source::SourceRange
end

struct EmphasisInline <: MarkdownInline
    children::Vector{MarkdownInline}
    source::SourceRange
end

struct StrongInline <: MarkdownInline
    children::Vector{MarkdownInline}
    source::SourceRange
end

struct StrikeInline <: MarkdownInline
    children::Vector{MarkdownInline}
    source::SourceRange
end

struct InlineCode <: MarkdownInline
    code::String
    source::SourceRange
end

struct MarkdownLink <: MarkdownInline
    children::Vector{MarkdownInline}
    destination::String
    title::Union{Nothing,String}
    source::SourceRange
end

struct MarkdownImage <: MarkdownInline
    alt::String
    destination::String
    title::Union{Nothing,String}
    source::SourceRange
end

struct SoftBreak <: MarkdownInline
    source::SourceRange
end

struct HardBreak <: MarkdownInline
    source::SourceRange
end

struct HeadingBlock <: MarkdownBlock
    level::Int
    children::Vector{MarkdownInline}
    source::SourceRange
end

struct ParagraphBlock <: MarkdownBlock
    children::Vector{MarkdownInline}
    source::SourceRange
end

struct QuoteBlock <: MarkdownBlock
    blocks::Vector{MarkdownBlock}
    source::SourceRange
end

struct ListItem
    blocks::Vector{MarkdownBlock}
    checked::Union{Nothing,Bool}
    source::SourceRange
end

struct ListBlock <: MarkdownBlock
    ordered::Bool
    start_number::Int
    items::Vector{ListItem}
    source::SourceRange
end

struct CodeFenceBlock <: MarkdownBlock
    language::String
    info::String
    code::String
    source::SourceRange
end

struct ThematicBreak <: MarkdownBlock
    source::SourceRange
end

struct MarkdownTable <: MarkdownBlock
    headers::Vector{Vector{MarkdownInline}}
    alignments::Vector{Symbol}
    rows::Vector{Vector{Vector{MarkdownInline}}}
    source::SourceRange
end

struct MarkdownDocument
    source::String
    blocks::Vector{MarkdownBlock}
    diagnostics::Vector{MarkdownDiagnostic}
end

_line_range(line::Int, value::AbstractString) =
    SourceRange(SourcePosition(line, 1), SourcePosition(line, max(1, length(value) + 1)))

function _inline_range(line::Int, start_column::Int, value::AbstractString)
    return SourceRange(
        SourcePosition(line, start_column),
        SourcePosition(line, start_column + max(1, length(value))),
    )
end

_at(value::AbstractString, index::Int, marker::AbstractString) =
    startswith(SubString(value, index), marker)

function _advance(value::AbstractString, index::Int, count::Int)
    result = index
    for _ in 1:count
        result > lastindex(value) && return ncodeunits(value) + 1
        result = nextind(value, result)
    end
    return result
end

_column(value::AbstractString, index::Int) =
    index <= firstindex(value) ? 1 : length(SubString(value, firstindex(value), prevind(value, index))) + 1

function _append_plain_inline!(
    nodes::Vector{MarkdownInline},
    value::AbstractString,
    source::SourceRange,
)
    isempty(value) && return nodes
    text = String(value)
    if !isempty(nodes) && last(nodes) isa PlainText
        previous = pop!(nodes)::PlainText
        push!(nodes, PlainText(previous.value * text, SourceRange(previous.source.start, source.stop)))
    else
        push!(nodes, PlainText(text, source))
    end
    return nodes
end

function _parse_destination(value::AbstractString)
    text = strip(value)
    isempty(text) && return nothing
    index = firstindex(text)
    while index <= lastindex(text) && !isspace(text[index]) && text[index] != ')'
        index = nextind(text, index)
    end
    uri_stop = prevind(text, index)
    uri_stop < firstindex(text) && return nothing
    uri = String(SubString(text, firstindex(text), uri_stop))
    index > lastindex(text) && return uri, nothing
    while index <= lastindex(text) && isspace(text[index])
        index = nextind(text, index)
    end
    index > lastindex(text) && return nothing
    delimiter = text[index]
    delimiter in ('\'', '"') || return nothing
    title_start = nextind(text, index)
    closing = lastindex(text)
    text[closing] == delimiter || return nothing
    title_stop = prevind(text, closing)
    if title_start <= title_stop
        for character in SubString(text, title_start, title_stop)
            character in ('\'', '"') && return nothing
        end
    end
    title = title_start > title_stop ? "" : String(SubString(text, title_start, title_stop))
    return uri, title
end

function _bracketed_inline(value::AbstractString, index::Int, image::Bool)
    label_start = image ? _advance(value, index, 2) : nextind(value, index)
    label_end = findnext(']', value, label_start)
    label_end === nothing && return nothing
    !image && label_end == label_start && return nothing
    opening = nextind(value, label_end)
    opening <= lastindex(value) && value[opening] == '(' || return nothing
    destination_start = nextind(value, opening)
    closing = findnext(')', value, destination_start)
    closing === nothing && return nothing
    return label_start, label_end, destination_start, closing, nextind(value, closing)
end

function _parse_inlines(value::AbstractString, line::Int; base_column::Int=1)
    isempty(value) && return MarkdownInline[]
    nodes = MarkdownInline[]
    index = firstindex(value)
    while index <= lastindex(value)
        column = base_column + _column(value, index) - 1

        if value[index] == '\\' && nextind(value, index) <= lastindex(value)
            next_index = nextind(value, index)
            escaped = string(value[next_index])
            _append_plain_inline!(nodes, escaped, _inline_range(line, column, escaped))
            index = nextind(value, next_index)
            continue
        end

        if _at(value, index, "![")
            bracketed = _bracketed_inline(value, index, true)
            if bracketed !== nothing
                label_start, label_end, destination_start, closing, stop_index = bracketed
                label = label_end == label_start ? SubString(value, label_start, label_start - 1) :
                        SubString(value, label_start, prevind(value, label_end))
                destination_text = closing == destination_start ?
                                   SubString(value, destination_start, destination_start - 1) :
                                   SubString(value, destination_start, prevind(value, closing))
                destination = _parse_destination(destination_text)
                if destination !== nothing
                    uri, title = destination
                    matched = SubString(value, index, prevind(value, stop_index))
                    push!(nodes, MarkdownImage(String(label), uri, title, _inline_range(line, column, matched)))
                    index = stop_index
                    continue
                end
            end
        end

        if value[index] == '['
            bracketed = _bracketed_inline(value, index, false)
            if bracketed !== nothing
                label_start, label_end, destination_start, closing, stop_index = bracketed
                label = SubString(value, label_start, prevind(value, label_end))
                destination_text = closing == destination_start ?
                                   SubString(value, destination_start, destination_start - 1) :
                                   SubString(value, destination_start, prevind(value, closing))
                destination = _parse_destination(destination_text)
                if destination !== nothing
                    uri, title = destination
                    children = _parse_inlines(label, line; base_column=column + 1)
                    matched = SubString(value, index, prevind(value, stop_index))
                    push!(nodes, MarkdownLink(children, uri, title, _inline_range(line, column, matched)))
                    index = stop_index
                    continue
                end
            end
        end

        if value[index] == '<'
            remainder = SubString(value, index)
            auto_match = match(r"^<(https?://[^ >]+|mailto:[^ >]+)>", remainder)
            if auto_match !== nothing
                matched = String(auto_match.match)
                uri = String(auto_match.captures[1])
                child = PlainText(uri, _inline_range(line, column + 1, uri))
                push!(nodes, MarkdownLink(MarkdownInline[child], uri, nothing, _inline_range(line, column, matched)))
                index = _advance(value, index, length(matched))
                continue
            end
        end

        matched_delimiter = false
        for (marker, constructor) in (("**", StrongInline), ("__", StrongInline), ("~~", StrikeInline), ("*", EmphasisInline), ("_", EmphasisInline))
            _at(value, index, marker) || continue
            content_start = _advance(value, index, length(marker))
            closing = findnext(marker, value, content_start)
            closing === nothing && continue
            closing_start = first(closing)
            closing_start == content_start && continue
            content = SubString(value, content_start, prevind(value, closing_start))
            stop_index = nextind(value, last(closing))
            matched = SubString(value, index, prevind(value, stop_index))
            children = _parse_inlines(content, line; base_column=column + length(marker))
            push!(nodes, constructor(children, _inline_range(line, column, matched)))
            index = stop_index
            matched_delimiter = true
            break
        end
        matched_delimiter && continue

        if value[index] == '`'
            closing = findnext('`', value, nextind(value, index))
            if closing !== nothing
                code_start = nextind(value, index)
                code = code_start == closing ? "" : String(SubString(value, code_start, prevind(value, closing)))
                matched = SubString(value, index, closing)
                push!(nodes, InlineCode(code, _inline_range(line, column, matched)))
                index = nextind(value, closing)
                continue
            end
        end

        if value[index] == '\n'
            previous_spaces = !isempty(nodes) && last(nodes) isa PlainText && endswith((last(nodes)::PlainText).value, "  ")
            range = _inline_range(line, column, "\n")
            push!(nodes, previous_spaces ? HardBreak(range) : SoftBreak(range))
            index = nextind(value, index)
            continue
        end

        text_start = index
        index = nextind(value, index)
        while index <= lastindex(value) &&
                !(value[index] in ('\\', '!', '[', '<', '*', '_', '~', '`', '\n'))
            index = nextind(value, index)
        end
        text = String(SubString(value, text_start, prevind(value, index)))
        _append_plain_inline!(nodes, text, _inline_range(line, column, text))
    end
    return nodes
end

function _possible_block_marker(line::AbstractString, markers)
    for character in line
        isspace(character) && continue
        return character in markers
    end
    return false
end

_is_fence(line::AbstractString) = _possible_block_marker(line, ('`', '~')) ?
    match(r"^\s*(`{3,}|~{3,})(.*)$", line) : nothing
function _is_heading(line::AbstractString)
    isempty(line) && return nothing
    index = firstindex(line)
    column = 1
    indentation = 0
    while index <= lastindex(line) && isspace(line[index]) && indentation < 3
        index = nextind(line, index)
        column += 1
        indentation += 1
    end
    index <= lastindex(line) && line[index] == '#' || return nothing
    level = 0
    while index <= lastindex(line) && line[index] == '#' && level < 6
        index = nextind(line, index)
        column += 1
        level += 1
    end
    index <= lastindex(line) && isspace(line[index]) || return nothing

    # Match the regex's greedy required whitespace while retaining at least one
    # character for the nonempty content capture.
    while isspace(line[index]) && nextind(line, index) <= lastindex(line)
        index = nextind(line, index)
        column += 1
    end
    content_start = index
    content_column = column
    content_stop = lastindex(line)
    while content_stop > content_start && isspace(line[content_stop])
        content_stop = prevind(line, content_stop)
    end
    while content_stop > content_start && line[content_stop] == '#'
        content_stop = prevind(line, content_stop)
    end
    while content_stop > content_start && isspace(line[content_stop])
        content_stop = prevind(line, content_stop)
    end
    return (
        level=level,
        content=SubString(line, content_start, content_stop),
        column=content_column,
    )
end
_is_quote(line::AbstractString) = _possible_block_marker(line, ('>',)) ?
    match(r"^\s{0,3}>\s?(.*)$", line) : nothing
_is_unordered(line::AbstractString) = _possible_block_marker(line, ('-', '+', '*')) ?
    match(r"^(\s*)[-+*]\s+(?:\[([ xX])\]\s+)?(.*)$", line) : nothing
_is_ordered(line::AbstractString) = _possible_block_marker(line, ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')) ?
    match(r"^(\s*)(\d+)[\.)]\s+(.*)$", line) : nothing
_is_thematic(line::AbstractString) = _possible_block_marker(line, ('*', '-', '_')) &&
    match(r"^\s{0,3}(?:\*\s*){3,}$|^\s{0,3}(?:-\s*){3,}$|^\s{0,3}(?:_\s*){3,}$", line) !== nothing

function _table_cells(line::AbstractString)
    value = strip(line)
    startswith(value, '|') && (value = value[nextind(value, firstindex(value)):end])
    !isempty(value) && endswith(value, '|') && (value = value[begin:prevind(value, lastindex(value))])
    return String[strip(cell) for cell in split(value, '|'; keepempty=true)]
end

function _table_alignments(line::AbstractString)
    cells = _table_cells(line)
    isempty(cells) && return nothing
    alignments = Symbol[]
    for cell in cells
        match(r"^:?-{3,}:?$", cell) === nothing && return nothing
        push!(alignments, startswith(cell, ':') && endswith(cell, ':') ? :center : startswith(cell, ':') ? :left : endswith(cell, ':') ? :right : :default)
    end
    return alignments
end

function _starts_block(lines::AbstractVector{<:AbstractString}, index::Int, stop::Int)
    line = lines[index]
    isempty(strip(line)) && return true
    (_is_fence(line) !== nothing || _is_heading(line) !== nothing || _is_quote(line) !== nothing) && return true
    (_is_unordered(line) !== nothing || _is_ordered(line) !== nothing || _is_thematic(line)) && return true
    return index < stop && occursin('|', line) && _table_alignments(lines[index + 1]) !== nothing
end

function _parse_blocks(
    lines::AbstractVector{<:AbstractString},
    first_line::Int,
    last_line::Int,
    diagnostics::Vector{MarkdownDiagnostic},
)
    blocks = MarkdownBlock[]
    index = first_line
    while index <= last_line
        line = lines[index]
        if isempty(strip(line))
            index += 1
            continue
        end

        fence = _is_fence(line)
        if fence !== nothing
            marker = String(fence.captures[1])
            info = strip(String(fence.captures[2]))
            language = isempty(info) ? "" : first(split(info))
            content = String[]
            closing_line = nothing
            cursor = index + 1
            closing_pattern = Regex(
                "^\\s*" * first(marker, 1) * "{" * string(length(marker)) * ",}" * raw"\s*$",
            )
            while cursor <= last_line
                if match(closing_pattern, lines[cursor]) !== nothing
                    closing_line = cursor
                    break
                end
                push!(content, lines[cursor])
                cursor += 1
            end
            stop_line = closing_line === nothing ? last_line : closing_line
            if closing_line === nothing
                push!(diagnostics, MarkdownDiagnostic(:warning, "unclosed fenced code block", _line_range(index, line)))
            end
            push!(blocks, CodeFenceBlock(language, info, join(content, '\n'), SourceRange(SourcePosition(index, 1), SourcePosition(stop_line, length(lines[stop_line]) + 1))))
            index = stop_line + 1
            continue
        end

        heading = _is_heading(line)
        if heading !== nothing
            content = String(heading.content)
            push!(blocks, HeadingBlock(heading.level, _parse_inlines(content, index; base_column=heading.column), _line_range(index, line)))
            index += 1
            continue
        end

        if _is_thematic(line)
            push!(blocks, ThematicBreak(_line_range(index, line)))
            index += 1
            continue
        end

        quote_match = _is_quote(line)
        if quote_match !== nothing
            quote_start = index
            quote_lines = String[]
            while index <= last_line
                match_result = _is_quote(lines[index])
                match_result === nothing && break
                push!(quote_lines, String(match_result.captures[1]))
                index += 1
            end
            nested_diagnostics = MarkdownDiagnostic[]
            local_children = _parse_blocks(quote_lines, 1, length(quote_lines), nested_diagnostics)
            line_offset = quote_start - 1
            children = MarkdownBlock[_offset_block(child, line_offset) for child in local_children]
            append!(diagnostics, (_offset_diagnostic(diagnostic, line_offset) for diagnostic in nested_diagnostics))
            push!(blocks, QuoteBlock(children, SourceRange(SourcePosition(quote_start, 1), SourcePosition(index - 1, length(lines[index - 1]) + 1))))
            continue
        end

        unordered = _is_unordered(line)
        ordered = _is_ordered(line)
        if unordered !== nothing || ordered !== nothing
            list_start = index
            is_ordered = ordered !== nothing
            start_number = is_ordered ? parse(Int, ordered.captures[2]) : 1
            items = ListItem[]
            while index <= last_line
                match_result = is_ordered ? _is_ordered(lines[index]) : _is_unordered(lines[index])
                match_result === nothing && break
                item_line = index
                content = is_ordered ? String(match_result.captures[3]) : String(match_result.captures[3])
                checked = if is_ordered || match_result.captures[2] === nothing
                    nothing
                else
                    lowercase(String(match_result.captures[2])) == "x"
                end
                item_blocks = MarkdownBlock[ParagraphBlock(_parse_inlines(content, item_line), _line_range(item_line, lines[item_line]))]
                push!(items, ListItem(item_blocks, checked, _line_range(item_line, lines[item_line])))
                index += 1
            end
            push!(blocks, ListBlock(is_ordered, start_number, items, SourceRange(SourcePosition(list_start, 1), SourcePosition(index - 1, length(lines[index - 1]) + 1))))
            continue
        end

        if index < last_line && occursin('|', line)
            alignments = _table_alignments(lines[index + 1])
            if alignments !== nothing
                table_start = index
                header_cells = _table_cells(line)
                if length(header_cells) != length(alignments)
                    push!(diagnostics, MarkdownDiagnostic(:warning, "table header and delimiter column counts differ", _line_range(index + 1, lines[index + 1])))
                end
                headers = Vector{MarkdownInline}[_parse_inlines(cell, index) for cell in header_cells]
                index += 2
                rows = Vector{Vector{MarkdownInline}}[]
                while index <= last_line && occursin('|', lines[index]) && !isempty(strip(lines[index]))
                    cells = _table_cells(lines[index])
                    push!(rows, Vector{MarkdownInline}[_parse_inlines(cell, index) for cell in cells])
                    index += 1
                end
                push!(blocks, MarkdownTable(headers, alignments, rows, SourceRange(SourcePosition(table_start, 1), SourcePosition(index - 1, length(lines[index - 1]) + 1))))
                continue
            end
        end

        paragraph_start = index
        paragraph_lines = String[]
        while index <= last_line && (index == paragraph_start || !_starts_block(lines, index, last_line))
            push!(paragraph_lines, lines[index])
            index += 1
        end
        content = join(paragraph_lines, '\n')
        push!(blocks, ParagraphBlock(_parse_inlines(content, paragraph_start), SourceRange(SourcePosition(paragraph_start, 1), SourcePosition(index - 1, length(lines[index - 1]) + 1))))
    end
    return blocks
end

_offset_position(position::SourcePosition, lines::Int) =
    SourcePosition(position.line + lines, position.column)

_offset_range(range::SourceRange, lines::Int) =
    SourceRange(_offset_position(range.start, lines), _offset_position(range.stop, lines))

_offset_diagnostic(diagnostic::MarkdownDiagnostic, lines::Int) =
    MarkdownDiagnostic(diagnostic.severity, diagnostic.message, _offset_range(diagnostic.source, lines))

_offset_inline(node::PlainText, lines::Int) =
    PlainText(node.value, _offset_range(node.source, lines))
_offset_inline(node::EmphasisInline, lines::Int) =
    EmphasisInline(MarkdownInline[_offset_inline(child, lines) for child in node.children], _offset_range(node.source, lines))
_offset_inline(node::StrongInline, lines::Int) =
    StrongInline(MarkdownInline[_offset_inline(child, lines) for child in node.children], _offset_range(node.source, lines))
_offset_inline(node::StrikeInline, lines::Int) =
    StrikeInline(MarkdownInline[_offset_inline(child, lines) for child in node.children], _offset_range(node.source, lines))
_offset_inline(node::InlineCode, lines::Int) =
    InlineCode(node.code, _offset_range(node.source, lines))
_offset_inline(node::MarkdownLink, lines::Int) =
    MarkdownLink(MarkdownInline[_offset_inline(child, lines) for child in node.children], node.destination, node.title, _offset_range(node.source, lines))
_offset_inline(node::MarkdownImage, lines::Int) =
    MarkdownImage(node.alt, node.destination, node.title, _offset_range(node.source, lines))
_offset_inline(node::SoftBreak, lines::Int) = SoftBreak(_offset_range(node.source, lines))
_offset_inline(node::HardBreak, lines::Int) = HardBreak(_offset_range(node.source, lines))

_offset_block(block::HeadingBlock, lines::Int) =
    HeadingBlock(block.level, MarkdownInline[_offset_inline(child, lines) for child in block.children], _offset_range(block.source, lines))
_offset_block(block::ParagraphBlock, lines::Int) =
    ParagraphBlock(MarkdownInline[_offset_inline(child, lines) for child in block.children], _offset_range(block.source, lines))
_offset_block(block::QuoteBlock, lines::Int) =
    QuoteBlock(MarkdownBlock[_offset_block(child, lines) for child in block.blocks], _offset_range(block.source, lines))
function _offset_block(block::ListBlock, lines::Int)
    items = ListItem[
        ListItem(
            MarkdownBlock[_offset_block(child, lines) for child in item.blocks],
            item.checked,
            _offset_range(item.source, lines),
        ) for item in block.items
    ]
    return ListBlock(block.ordered, block.start_number, items, _offset_range(block.source, lines))
end
_offset_block(block::CodeFenceBlock, lines::Int) =
    CodeFenceBlock(block.language, block.info, block.code, _offset_range(block.source, lines))
_offset_block(block::ThematicBreak, lines::Int) = ThematicBreak(_offset_range(block.source, lines))
function _offset_block(block::MarkdownTable, lines::Int)
    headers = Vector{MarkdownInline}[
        MarkdownInline[_offset_inline(child, lines) for child in cell] for cell in block.headers
    ]
    rows = Vector{Vector{MarkdownInline}}[
        Vector{MarkdownInline}[
            MarkdownInline[_offset_inline(child, lines) for child in cell] for cell in row
        ] for row in block.rows
    ]
    return MarkdownTable(headers, copy(block.alignments), rows, _offset_range(block.source, lines))
end

"""Parse CommonMark-style blocks plus task lists, tables, and strikethrough."""
function parse_markdown(source::AbstractString)
    value = replace(String(source), "\r\n" => "\n", '\r' => '\n')
    lines = split(value, '\n'; keepempty=true)
    diagnostics = MarkdownDiagnostic[]
    blocks = _parse_blocks(lines, 1, length(lines), diagnostics)
    return MarkdownDocument(value, blocks, diagnostics)
end

@enum SemanticTokenKind begin
    PlainToken
    KeywordToken
    TypeToken
    FunctionToken
    StringToken
    NumberToken
    CommentToken
    OperatorToken
    PunctuationToken
    ConstantToken
    ErrorToken
end

struct SyntaxToken
    value::String
    kind::SemanticTokenKind
    first_offset::Int
    last_offset::Int
end

struct LexerDefinition
    keywords::Set{String}
    constants::Set{String}
    types::Set{String}
    line_comment::Union{Nothing,String}
    hash_block_comments::Bool
end

mutable struct SyntaxRegistry
    lexers::Dict{String,Function}
end

SyntaxRegistry() = SyntaxRegistry(Dict{String,Function}())

function register_syntax!(registry::SyntaxRegistry, names, lexer::Function)
    for name in names
        registry.lexers[lowercase(strip(String(name)))] = lexer
    end
    return registry
end

function _consume_while(source::String, index::Int, predicate::Function)
    cursor = index
    while cursor <= lastindex(source) && predicate(source[cursor])
        cursor = nextind(source, cursor)
    end
    return cursor
end

function _number_end(source::String, index::Int)
    cursor = index
    has_decimal = false
    has_exponent = false

    if source[cursor] == '.'
        has_decimal = true
        cursor = nextind(source, cursor)
    elseif source[cursor] == '0'
        prefix_index = nextind(source, cursor)
        if prefix_index <= lastindex(source) && lowercase(source[prefix_index]) in ('x', 'o', 'b')
            prefix = lowercase(source[prefix_index])
            cursor = nextind(source, prefix_index)
            predicate = prefix == 'x' ? value -> isxdigit(value) || value == '_' :
                        prefix == 'o' ? value -> value in ('0':'7') || value == '_' :
                        value -> value in ('0', '1', '_')
            return _consume_while(source, cursor, predicate)
        end
    end

    while cursor <= lastindex(source)
        character = source[cursor]
        if isdigit(character) || character == '_'
            cursor = nextind(source, cursor)
        elseif character == '.' && !has_decimal && !has_exponent
            has_decimal = true
            cursor = nextind(source, cursor)
        elseif lowercase(character) == 'e' && !has_exponent
            has_exponent = true
            cursor = nextind(source, cursor)
            if cursor <= lastindex(source) && source[cursor] in ('+', '-')
                cursor = nextind(source, cursor)
            end
        else
            break
        end
    end
    return cursor
end

function _quoted_end(source::String, index::Int, quote_character::Char)
    cursor = nextind(source, index)
    escaped = false
    while cursor <= lastindex(source)
        character = source[cursor]
        if escaped
            escaped = false
        elseif character == '\\'
            escaped = true
        elseif character == quote_character
            return nextind(source, cursor)
        end
        cursor = nextind(source, cursor)
    end
    return ncodeunits(source) + 1
end

function _push_token!(tokens::Vector{SyntaxToken}, source::String, first_index::Int, next_index::Int, kind::SemanticTokenKind)
    next_index == first_index && return
    stop_index = prevind(source, next_index)
    push!(tokens, SyntaxToken(String(SubString(source, first_index, stop_index)), kind, first_index, stop_index))
end

function _lex(source_value::AbstractString, definition::LexerDefinition)
    source = String(source_value)
    isempty(source) && return SyntaxToken[]
    tokens = SyntaxToken[]
    index = firstindex(source)
    while index <= lastindex(source)
        character = source[index]

        if isspace(character)
            next_index = _consume_while(source, index, isspace)
            _push_token!(tokens, source, index, next_index, PlainToken)
            index = next_index
            continue
        end

        if definition.hash_block_comments && _at(source, index, "#=")
            closing = findnext("=#", source, _advance(source, index, 2))
            next_index = closing === nothing ? ncodeunits(source) + 1 : nextind(source, last(closing))
            _push_token!(tokens, source, index, next_index, CommentToken)
            index = next_index
            continue
        end

        if definition.line_comment !== nothing && _at(source, index, definition.line_comment)
            newline = findnext('\n', source, index)
            next_index = newline === nothing ? ncodeunits(source) + 1 : newline
            _push_token!(tokens, source, index, next_index, CommentToken)
            index = next_index
            continue
        end

        if character == '"' || character == '\''
            next_index = _quoted_end(source, index, character)
            _push_token!(tokens, source, index, next_index, StringToken)
            index = next_index
            continue
        end

        if isdigit(character) || (character == '.' && nextind(source, index) <= lastindex(source) && isdigit(source[nextind(source, index)]))
            next_index = _number_end(source, index)
            _push_token!(tokens, source, index, next_index, NumberToken)
            index = next_index
            continue
        end

        if isletter(character) || character == '_'
            next_index = _consume_while(source, index, value -> isletter(value) || isdigit(value) || value in ('_', '!', '?'))
            identifier = String(SubString(source, index, prevind(source, next_index)))
            kind = identifier in definition.keywords ? KeywordToken : identifier in definition.constants ? ConstantToken : identifier in definition.types ? TypeToken : PlainToken
            if kind == PlainToken
                cursor = next_index
                while cursor <= lastindex(source) && isspace(source[cursor])
                    cursor = nextind(source, cursor)
                end
                cursor <= lastindex(source) && source[cursor] == '(' && (kind = FunctionToken)
            end
            _push_token!(tokens, source, index, next_index, kind)
            index = next_index
            continue
        end

        kind = character in ('(', ')', '[', ']', '{', '}', ',', ';') ? PunctuationToken : character in ('+', '-', '*', '/', '=', '<', '>', ':', '.', '&', '|', '!', '%', '^', '~', '?') ? OperatorToken : PlainToken
        next_index = nextind(source, index)
        _push_token!(tokens, source, index, next_index, kind)
        index = next_index
    end
    return tokens
end

function default_syntax_registry()
    registry = SyntaxRegistry()
    julia = LexerDefinition(
        Set(split("baremodule begin break catch const continue do else elseif end export finally for function global if import let local macro module quote return struct try using while where mutable primitive abstract type in isa outer")),
        Set(["true", "false", "nothing", "missing", "Inf", "NaN"]),
        Set(["Any", "Bool", "Char", "String", "Symbol", "Int", "Int64", "UInt", "Float64", "Tuple", "NamedTuple", "Vector", "Matrix", "Dict", "Set", "Function", "Union", "Nothing"]),
        "#",
        true,
    )
    json = LexerDefinition(Set{String}(), Set(["true", "false", "null"]), Set{String}(), nothing, false)
    shell = LexerDefinition(Set(split("if then else elif fi for while in do done case esac function select until time coproc")), Set(["true", "false"]), Set{String}(), "#", false)
    sql = LexerDefinition(Set(lowercase.(split("select from where join inner left right full outer on group by order having limit offset insert into values update set delete create alter drop table view index as distinct union all case when then else end and or not null is like between exists"))), Set(["true", "false", "null"]), Set{String}(), "--", false)
    register_syntax!(registry, ["julia", "jl"], source -> _lex(source, julia))
    register_syntax!(registry, ["json", "jsonc"], source -> _lex(source, json))
    register_syntax!(registry, ["sh", "shell", "bash", "zsh"], source -> _lex(source, shell))
    register_syntax!(registry, ["sql"], source -> begin
        tokens = _lex(source, sql)
        SyntaxToken[SyntaxToken(token.value, lowercase(token.value) in sql.keywords ? KeywordToken : token.kind, token.first_offset, token.last_offset) for token in tokens]
    end)
    return registry
end

function highlight(registry::SyntaxRegistry, source::AbstractString, language::AbstractString="")
    lexer = get(registry.lexers, lowercase(strip(String(language))), nothing)
    lexer === nothing && return isempty(source) ? SyntaxToken[] : SyntaxToken[SyntaxToken(String(source), PlainToken, 1, lastindex(String(source)))]
    return lexer(String(source))
end

highlight(source::AbstractString, language::AbstractString=""; registry::SyntaxRegistry=default_syntax_registry()) =
    highlight(registry, source, language)

struct LinkTarget
    uri::String
    title::Union{Nothing,String}
    safe::Bool
end

struct MarkdownLinkPolicy
    maximum_links::Int
    maximum_uri_bytes::Int
    maximum_label_bytes::Int
    allowed_schemes::Set{String}
    allow_relative::Bool
    allow_fragments::Bool

    function MarkdownLinkPolicy(;
        maximum_links::Integer=10_000,
        maximum_uri_bytes::Integer=8_192,
        maximum_label_bytes::Integer=65_536,
        allowed_schemes=("http", "https", "mailto"),
        allow_relative::Bool=true,
        allow_fragments::Bool=true,
    )
        maximum_links >= 0 || throw(ArgumentError("maximum Markdown links cannot be negative"))
        maximum_uri_bytes >= 0 || throw(ArgumentError("maximum Markdown URI bytes cannot be negative"))
        maximum_label_bytes >= 0 || throw(ArgumentError("maximum Markdown link label bytes cannot be negative"))
        all(value -> value <= typemax(Int), (maximum_links, maximum_uri_bytes, maximum_label_bytes)) ||
            throw(ArgumentError("Markdown link policy limit is too large"))
        schemes = Set{String}()
        for value in allowed_schemes
            scheme = lowercase(String(value))
            occursin(r"^[a-z][a-z0-9+.-]*$", scheme) ||
                throw(ArgumentError("invalid allowed Markdown URI scheme: $value"))
            push!(schemes, scheme)
        end
        new(
            Int(maximum_links),
            Int(maximum_uri_bytes),
            Int(maximum_label_bytes),
            schemes,
            allow_relative,
            allow_fragments,
        )
    end
end

struct RenderedLink
    id::Int
    target::LinkTarget
    label::String
end

struct RichSpan
    text::String
    role::Symbol
    link_id::Union{Nothing,Int}
end

struct RichLine
    spans::Vector{RichSpan}
    role::Symbol
    source::Union{Nothing,SourceRange}
end

struct RichDocument
    lines::Vector{RichLine}
    links::Vector{RenderedLink}
    diagnostics::Vector{MarkdownDiagnostic}
end

mutable struct RenderContext
    links::Vector{RenderedLink}
    registry::SyntaxRegistry
    width::Int
    link_policy::MarkdownLinkPolicy
    diagnostics::Vector{MarkdownDiagnostic}
end

function _normalized_link(uri::AbstractString)
    value = String(uri)
    isvalid(value) || return value
    return strip(value)
end

function _link_input_error(uri::AbstractString, policy::MarkdownLinkPolicy)
    value = String(uri)
    isvalid(value) || return :invalid_utf8
    normalized = strip(value)
    ncodeunits(normalized) <= policy.maximum_uri_bytes || return :uri_too_long
    any(character -> iscntrl(character) || isspace(character), normalized) && return :invalid_character
    return nothing
end

_ascii_scheme_character(byte::UInt8, first::Bool=false) =
    0x41 <= byte <= 0x5a || 0x61 <= byte <= 0x7a ||
    (!first && (0x30 <= byte <= 0x39 || byte in (0x2b, 0x2d, 0x2e)))

function _scheme_allowed(value::AbstractString, last::Int, allowed_schemes::Set{String})
    length = last - firstindex(value) + 1
    for allowed in allowed_schemes
        ncodeunits(allowed) == length || continue
        matches = true
        for offset in 0:(length - 1)
            byte = codeunit(value, firstindex(value) + offset)
            lowered = 0x41 <= byte <= 0x5a ? byte + 0x20 : byte
            if lowered != codeunit(allowed, offset + 1)
                matches = false
                break
            end
        end
        matches && return true
    end
    return false
end

function _markdown_link_safe_normalized(value::AbstractString, policy::MarkdownLinkPolicy)
    startswith(value, "#") && return policy.allow_fragments
    (startswith(value, "//") || startswith(value, '\\') || startswith(value, '/')) && return false
    isempty(value) && return policy.allow_relative
    index = firstindex(value)
    first = true
    while index <= lastindex(value)
        byte = codeunit(value, index)
        if byte == 0x3a
            return first ? policy.allow_relative :
                   _scheme_allowed(value, prevind(value, index), policy.allowed_schemes)
        end
        _ascii_scheme_character(byte, first) || return policy.allow_relative
        first = false
        index = nextind(value, index)
    end
    return policy.allow_relative
end

function markdown_link_safe(
    uri::AbstractString;
    policy::MarkdownLinkPolicy=MarkdownLinkPolicy(),
)
    _link_input_error(uri, policy) === nothing || return false
    value = _normalized_link(uri)
    return _markdown_link_safe_normalized(value, policy)
end

function _terminal_safe_text(value::AbstractString)
    text = String(value)
    isvalid(text) || return "�"
    safe = true
    for character in text
        if character != '\n' && character != '\t' && iscntrl(character)
            safe = false
            break
        end
    end
    safe && return text
    output = IOBuffer()
    for character in text
        if character in ('\n', '\t') || !iscntrl(character)
            print(output, character)
        else
            print(output, '�')
        end
    end
    return String(take!(output))
end

function _append_span!(spans::Vector{RichSpan}, text::AbstractString, role::Symbol, link_id)
    isempty(text) && return spans
    value = _terminal_safe_text(text)
    if !isempty(spans) && last(spans).role == role && last(spans).link_id == link_id
        previous = pop!(spans)
        push!(spans, RichSpan(previous.text * value, role, link_id))
    else
        push!(spans, RichSpan(value, role, link_id))
    end
    return spans
end

function _register_link!(
    context::RenderContext,
    destination::AbstractString,
    title,
    label::String,
    source::SourceRange,
)
    input_error = _link_input_error(destination, context.link_policy)
    if input_error !== nothing
        push!(context.diagnostics, MarkdownDiagnostic(
            :warning,
            "Markdown link was omitted: $(replace(string(input_error), '_' => ' '))",
            source,
        ))
        return nothing, false
    end
    if ncodeunits(label) > context.link_policy.maximum_label_bytes
        push!(context.diagnostics, MarkdownDiagnostic(:warning, "Markdown link label exceeds the configured byte limit", source))
        return nothing, false
    end
    if length(context.links) >= context.link_policy.maximum_links
        push!(context.diagnostics, MarkdownDiagnostic(:warning, "Markdown link count exceeds the configured limit", source))
        return nothing, false
    end
    uri = _normalized_link(destination)
    safe = _markdown_link_safe_normalized(uri, context.link_policy)
    resolved_title = title === nothing ? nothing : _terminal_safe_text(title)
    id = length(context.links) + 1
    push!(context.links, RenderedLink(id, LinkTarget(uri, resolved_title, safe), label))
    return id, safe
end

function _inline_spans!(spans::Vector{RichSpan}, nodes::Vector{MarkdownInline}, context::RenderContext, inherited::Symbol=:text)
    for node in nodes
        if node isa PlainText
            _append_span!(spans, node.value, inherited, nothing)
        elseif node isa EmphasisInline
            _inline_spans!(spans, node.children, context, :emphasis)
        elseif node isa StrongInline
            _inline_spans!(spans, node.children, context, :strong)
        elseif node isa StrikeInline
            _inline_spans!(spans, node.children, context, :strikethrough)
        elseif node isa InlineCode
            _append_span!(spans, node.code, :inline_code, nothing)
        elseif node isa MarkdownLink
            label_spans = RichSpan[]
            _inline_spans!(label_spans, node.children, context, :link)
            label = join(span.text for span in label_spans)
            id, safe = _register_link!(context, node.destination, node.title, label, node.source)
            for span in label_spans
                _append_span!(spans, span.text, safe ? :link : :invalid_link, id)
            end
        elseif node isa MarkdownImage
            label = isempty(node.alt) ? "[image]" : "[image: $(node.alt)]"
            safe_label = _terminal_safe_text(label)
            id, safe = _register_link!(context, node.destination, node.title, safe_label, node.source)
            _append_span!(spans, safe_label, safe ? :image : :invalid_link, id)
        elseif node isa HardBreak || node isa SoftBreak
            _append_span!(spans, "\n", :text, nothing)
        end
    end
    return spans
end

function _hard_split(span::RichSpan, width::Int)
    parts = RichSpan[]
    current = IOBuffer()
    current_width = 0
    for grapheme in graphemes(span.text)
        grapheme_width = textwidth(grapheme)
        if current_width > 0 && current_width + grapheme_width > width
            push!(parts, RichSpan(String(take!(current)), span.role, span.link_id))
            current_width = 0
        end
        print(current, grapheme)
        current_width += grapheme_width
    end
    position(current) > 0 && push!(parts, RichSpan(String(take!(current)), span.role, span.link_id))
    return parts
end

function _place_wrapped_piece!(
    lines::Vector{Vector{RichSpan}},
    text::AbstractString,
    role::Symbol,
    link_id,
    piece_width::Int,
    width::Int,
    line_width::Int,
    whitespace::Bool=false,
)
    if line_width > 0 && line_width + piece_width > width
        push!(lines, RichSpan[])
        line_width = 0
        whitespace && return line_width
    end
    _append_span!(last(lines), text, role, link_id)
    return line_width + piece_width
end

function _place_wrapped_token!(
    lines::Vector{Vector{RichSpan}},
    text::AbstractString,
    span::RichSpan,
    width::Int,
    line_width::Int,
    whitespace::Bool,
)
    part_width = textwidth(text)
    if part_width <= width
        return _place_wrapped_piece!(
            lines,
            text,
            span.role,
            span.link_id,
            part_width,
            width,
            line_width,
            whitespace,
        )
    end
    for piece in _hard_split(RichSpan(String(text), span.role, span.link_id), width)
        line_width = _place_wrapped_piece!(
            lines,
            piece.text,
            piece.role,
            piece.link_id,
            textwidth(piece.text),
            width,
            line_width,
        )
    end
    return line_width
end

function _wrap_span!(lines::Vector{Vector{RichSpan}}, span::RichSpan, width::Int, line_width::Int)
    text = span.text
    isempty(text) && return line_width
    index = firstindex(text)
    final = lastindex(text)
    while index <= final
        character = text[index]
        if character == '\n'
            push!(lines, RichSpan[])
            line_width = 0
            index = nextind(text, index)
            continue
        end
        whitespace = isspace(character)
        start = index
        index = nextind(text, index)
        while index <= final
            character = text[index]
            (character == '\n' || isspace(character) != whitespace) && break
            index = nextind(text, index)
        end
        token = SubString(text, start, prevind(text, index))
        line_width = _place_wrapped_token!(lines, token, span, width, line_width, whitespace)
    end
    return line_width
end

function _wrap_spans(spans::Vector{RichSpan}, width::Int)
    width > 0 || return [RichSpan[]]
    lines = Vector{RichSpan}[RichSpan[]]
    line_width = 0
    for span in spans
        line_width = _wrap_span!(lines, span, width, line_width)
    end
    return lines
end

function _render_inline_lines!(lines::Vector{RichLine}, nodes, context, role, source; prefix::String="")
    spans = RichSpan[]
    isempty(prefix) || _append_span!(spans, prefix, Symbol(role, :_marker), nothing)
    _inline_spans!(spans, nodes, context)
    for wrapped in _wrap_spans(spans, context.width)
        push!(lines, RichLine(wrapped, role, source))
    end
end

function _token_role(kind::SemanticTokenKind)
    return Symbol("syntax_", lowercase(replace(string(kind), "Token" => "")))
end

function _render_blocks!(lines::Vector{RichLine}, blocks::Vector{MarkdownBlock}, context::RenderContext; prefix::String="")
    for block in blocks
        if block isa HeadingBlock
            _render_inline_lines!(lines, block.children, context, Symbol("heading_", block.level), block.source; prefix=prefix)
        elseif block isa ParagraphBlock
            _render_inline_lines!(lines, block.children, context, :paragraph, block.source; prefix=prefix)
        elseif block isa QuoteBlock
            before = length(lines)
            _render_blocks!(lines, block.blocks, context; prefix=prefix * "> ")
            for index in (before + 1):length(lines)
                lines[index] = RichLine(lines[index].spans, :quote, lines[index].source)
            end
        elseif block isa ListBlock
            for (offset, item) in enumerate(block.items)
                marker = block.ordered ? "$(block.start_number + offset - 1). " : item.checked === nothing ? "- " : item.checked ? "[x] " : "[ ] "
                if isempty(item.blocks)
                    push!(lines, RichLine(RichSpan[RichSpan(prefix * marker, :list_marker, nothing)], :list_item, item.source))
                else
                    first_block = first(item.blocks)
                    if first_block isa ParagraphBlock
                        _render_inline_lines!(lines, first_block.children, context, :list_item, item.source; prefix=prefix * marker)
                        length(item.blocks) > 1 && _render_blocks!(lines, item.blocks[2:end], context; prefix=prefix * repeat(" ", length(marker)))
                    else
                        _render_blocks!(lines, item.blocks, context; prefix=prefix * marker)
                    end
                end
            end
        elseif block isa CodeFenceBlock
            tokens = highlight(context.registry, block.code, block.language)
            current = RichSpan[]
            for token in tokens
                parts = split(token.value, '\n'; keepempty=true)
                for (index, part) in enumerate(parts)
                    isempty(part) || _append_span!(current, part, _token_role(token.kind), nothing)
                    if index < length(parts)
                        push!(lines, RichLine(copy(current), :code_block, block.source))
                        empty!(current)
                    end
                end
            end
            (!isempty(current) || isempty(tokens)) && push!(lines, RichLine(current, :code_block, block.source))
        elseif block isa ThematicBreak
            push!(lines, RichLine(RichSpan[RichSpan(repeat("-", max(1, context.width)), :thematic_break, nothing)], :thematic_break, block.source))
        elseif block isa MarkdownTable
            table_rows = vcat([block.headers], block.rows)
            for (row_index, row) in enumerate(table_rows)
                spans = RichSpan[]
                for (column, cell) in enumerate(row)
                    column > 1 && _append_span!(spans, " | ", :table_border, nothing)
                    _inline_spans!(spans, cell, context, row_index == 1 ? :table_header : :table_cell)
                end
                for wrapped in _wrap_spans(spans, context.width)
                    push!(lines, RichLine(wrapped, row_index == 1 ? :table_header : :table_row, block.source))
                end
            end
        end
    end
    return lines
end

"""Render a parsed Markdown AST into semantic, width-bounded terminal lines."""
function render_markdown(
    document::MarkdownDocument;
    width::Integer=80,
    registry::SyntaxRegistry=default_syntax_registry(),
    link_policy::MarkdownLinkPolicy=MarkdownLinkPolicy(),
)
    width > 0 || throw(ArgumentError("render width must be positive"))
    context = RenderContext(RenderedLink[], registry, Int(width), link_policy, MarkdownDiagnostic[])
    lines = RichLine[]
    _render_blocks!(lines, document.blocks, context)
    return RichDocument(lines, context.links, vcat(document.diagnostics, context.diagnostics))
end

render_markdown(source::AbstractString; kwargs...) = render_markdown(parse_markdown(source); kwargs...)

plain_text(line::RichLine) = join(span.text for span in line.spans)
plain_text(document::RichDocument) = join((plain_text(line) for line in document.lines), '\n')
plain_text(document::MarkdownDocument; kwargs...) = plain_text(render_markdown(document; kwargs...))

function link_by_id(document::RichDocument, id::Integer)
    index = findfirst(link -> link.id == id, document.links)
    return index === nothing ? nothing : document.links[index]
end

function links_at_line(document::RichDocument, line::Integer)
    1 <= line <= length(document.lines) || return RenderedLink[]
    ids = Set(span.link_id for span in document.lines[line].spans if span.link_id !== nothing)
    return RenderedLink[link for link in document.links if link.id in ids]
end

end
