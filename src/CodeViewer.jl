module CodeViewer

using Unicode: graphemes
using ..RichContent: RichSpan,
                     RichLine,
                     SyntaxRegistry,
                     SyntaxToken,
                     SemanticTokenKind,
                     default_syntax_registry,
                     highlight
using ..Accessibility: SemanticState,
                       SemanticNode,
                       TextboxRole,
                       SetValueSemanticAction,
                       ScrollIntoViewSemanticAction

export CodeLocation,
       CodeRange,
       CodeDiagnosticSeverity,
       CodeHint,
       CodeWarning,
       CodeError,
       CodeDiagnostic,
       CodeSearchMatch,
       CodeViewState,
       set_code_source!,
       set_code_language!,
       scroll_code_view!,
       move_code_cursor!,
       toggle_code_breakpoint!,
       begin_code_selection!,
       clear_code_selection!,
       selected_code_lines,
       selected_code_text,
       set_code_diagnostics!,
       search_code!,
       next_code_match!,
       previous_code_match!,
       clear_code_search!,
       CodeViewRender,
       render_code_view,
       code_view_semantic_node,
       DiffLineKind,
       DiffContextLine,
       DiffAddedLine,
       DiffRemovedLine,
       DiffHeaderLine,
       DiffHunkLine,
       DiffMetadataLine,
       DiffLine,
       UnifiedDiff,
       parse_unified_diff,
       render_unified_diff

struct CodeLocation
    line::Int
    column::Int

    function CodeLocation(line::Integer, column::Integer)
        line > 0 || throw(ArgumentError("code line must be positive"))
        column > 0 || throw(ArgumentError("code column must be positive"))
        new(Int(line), Int(column))
    end
end

struct CodeRange
    start::CodeLocation
    stop::CodeLocation
end

@enum CodeDiagnosticSeverity begin
    CodeHint
    CodeWarning
    CodeError
end

struct CodeDiagnostic
    range::CodeRange
    severity::CodeDiagnosticSeverity
    message::String
    source::Union{Nothing,String}

    function CodeDiagnostic(
        range::CodeRange,
        severity::CodeDiagnosticSeverity,
        message::AbstractString;
        source::Union{Nothing,AbstractString}=nothing,
    )
        new(
            range,
            severity,
            String(message),
            source === nothing ? nothing : String(source),
        )
    end
end

struct CodeSearchMatch
    range::CodeRange
    text::String
end

mutable struct CodeViewState
    source::String
    lines::Vector{String}
    language::String
    registry::SyntaxRegistry
    first_line::Int
    horizontal_offset::Int
    cursor_line::Union{Nothing,Int}
    selection_anchor::Union{Nothing,Int}
    show_line_numbers::Bool
    breakpoints::Set{Int}
    diagnostics::Vector{CodeDiagnostic}
    search_query::Union{Nothing,String,Regex}
    search_case_sensitive::Bool
    matches::Vector{CodeSearchMatch}
    current_match::Union{Nothing,Int}
    revision::UInt64

    function CodeViewState(
        source::AbstractString="";
        language::AbstractString="",
        registry::SyntaxRegistry=default_syntax_registry(),
        show_line_numbers::Bool=true,
    )
        value = _normalize_source(source)
        lines = String[String(line) for line in split(value, '\n'; keepempty=true)]
        new(
            value,
            lines,
            String(language),
            registry,
            1,
            0,
            isempty(lines) ? nothing : 1,
            nothing,
            show_line_numbers,
            Set{Int}(),
            CodeDiagnostic[],
            nothing,
            false,
            CodeSearchMatch[],
            nothing,
            1,
        )
    end
end

_normalize_source(source::AbstractString) =
    replace(String(source), "\r\n" => "\n", '\r' => '\n')

function set_code_source!(state::CodeViewState, source::AbstractString)
    state.source = _normalize_source(source)
    state.lines = String[String(line) for line in split(state.source, '\n'; keepempty=true)]
    state.first_line = clamp(state.first_line, 1, max(1, length(state.lines)))
    state.cursor_line = state.cursor_line === nothing ? nothing :
        clamp(state.cursor_line, 1, max(1, length(state.lines)))
    state.selection_anchor = state.selection_anchor === nothing ? nothing :
        clamp(state.selection_anchor, 1, max(1, length(state.lines)))
    intersect!(state.breakpoints, Set(1:length(state.lines)))
    state.revision == typemax(UInt64) && throw(OverflowError("code-view revision overflow"))
    state.revision += 1
    state.search_query === nothing || search_code!(
        state,
        state.search_query;
        case_sensitive=state.search_case_sensitive,
    )
    return state
end

function set_code_language!(state::CodeViewState, language::AbstractString)
    state.language = String(language)
    return state
end

function scroll_code_view!(
    state::CodeViewState,
    line_delta::Integer=0,
    column_delta::Integer=0;
    viewport_height::Integer=1,
)
    viewport_height >= 0 || throw(ArgumentError("code viewport height cannot be negative"))
    maximum_first = max(1, length(state.lines) - Int(viewport_height) + 1)
    state.first_line = Int(clamp(big(state.first_line) + big(line_delta), big(1), big(maximum_first)))
    state.horizontal_offset = Int(clamp(big(state.horizontal_offset) + big(column_delta), big(0), big(typemax(Int))))
    return state
end

function move_code_cursor!(
    state::CodeViewState,
    delta::Integer;
    viewport_height::Integer=1,
    extend_selection::Bool=false,
)
    isempty(state.lines) && (state.cursor_line = nothing; return state)
    current = something(state.cursor_line, 1)
    if extend_selection
        state.selection_anchor === nothing && (state.selection_anchor = current)
    else
        state.selection_anchor = nothing
    end
    state.cursor_line = Int(clamp(big(current) + big(delta), big(1), big(length(state.lines))))
    if state.cursor_line < state.first_line
        state.first_line = state.cursor_line
    elseif state.cursor_line >= state.first_line + viewport_height
        state.first_line = max(1, state.cursor_line - Int(viewport_height) + 1)
    end
    return state
end

function begin_code_selection!(state::CodeViewState, line::Integer=something(state.cursor_line, 1))
    isempty(state.lines) && return state
    state.selection_anchor = clamp(Int(line), 1, length(state.lines))
    state.cursor_line = state.selection_anchor
    return state
end

clear_code_selection!(state::CodeViewState) = (state.selection_anchor = nothing; state)

function selected_code_lines(state::CodeViewState)
    state.selection_anchor === nothing && return 1:0
    state.cursor_line === nothing && return 1:0
    first_line, stop_line = minmax(state.selection_anchor, state.cursor_line)
    return first_line:stop_line
end

function selected_code_text(state::CodeViewState; current_line_fallback::Bool=false)
    range = selected_code_lines(state)
    if isempty(range)
        current_line_fallback || return ""
        state.cursor_line === nothing && return ""
        return state.lines[state.cursor_line]
    end
    return join(@view(state.lines[range]), '\n')
end

function toggle_code_breakpoint!(state::CodeViewState, line::Integer=something(state.cursor_line, 0))
    1 <= line <= length(state.lines) || return false
    if line in state.breakpoints
        delete!(state.breakpoints, Int(line))
    else
        push!(state.breakpoints, Int(line))
    end
    return true
end

function set_code_diagnostics!(state::CodeViewState, diagnostics)
    state.diagnostics = CodeDiagnostic[diagnostic for diagnostic in diagnostics]
    return state
end

function _column_at(text::String, index::Int)
    index <= firstindex(text) && return 1
    return length(SubString(text, firstindex(text), prevind(text, index))) + 1
end

function _literal_matches(line::String, query::String, line_number::Int, case_sensitive::Bool)
    if !case_sensitive
        escaped = replace(query, r"([\\.^$|?*+()\[\]{}])" => s"\\\1")
        return _regex_matches(line, Regex(escaped, "i"), line_number)
    end
    haystack = line
    needle = query
    matches = CodeSearchMatch[]
    isempty(needle) && return matches
    index = firstindex(haystack)
    while index <= lastindex(haystack)
        found = findnext(needle, haystack, index)
        found === nothing && break
        start_column = _column_at(haystack, first(found))
        stop_column = start_column + length(needle)
        matched_text = String(SubString(line, first(found), last(found)))
        push!(matches, CodeSearchMatch(
            CodeRange(CodeLocation(line_number, start_column), CodeLocation(line_number, stop_column)),
            matched_text,
        ))
        index = nextind(haystack, last(found))
    end
    return matches
end

function _regex_matches(line::String, query::Regex, line_number::Int)
    matches = CodeSearchMatch[]
    for matched in eachmatch(query, line)
        isempty(matched.match) && continue
        start_index = matched.offset
        stop_index = nextind(line, start_index, length(matched.match))
        push!(matches, CodeSearchMatch(
            CodeRange(
                CodeLocation(line_number, _column_at(line, start_index)),
                CodeLocation(line_number, _column_at(line, stop_index)),
            ),
            String(matched.match),
        ))
    end
    return matches
end

function search_code!(
    state::CodeViewState,
    query::Union{AbstractString,Regex};
    case_sensitive::Bool=false,
)
    state.search_query = query isa Regex ? query : String(query)
    state.search_case_sensitive = case_sensitive
    empty!(state.matches)
    for (line_number, line) in enumerate(state.lines)
        append!(
            state.matches,
            query isa Regex ? _regex_matches(line, query, line_number) :
            _literal_matches(line, String(query), line_number, case_sensitive),
        )
    end
    state.current_match = isempty(state.matches) ? nothing : 1
    state.current_match === nothing || (state.cursor_line = state.matches[1].range.start.line)
    return state.matches
end

function next_code_match!(state::CodeViewState; wrap::Bool=true)
    isempty(state.matches) && return nothing
    current = something(state.current_match, 0) + 1
    state.current_match = wrap ? mod1(current, length(state.matches)) : min(current, length(state.matches))
    match_result = state.matches[state.current_match]
    state.cursor_line = match_result.range.start.line
    return match_result
end

function previous_code_match!(state::CodeViewState; wrap::Bool=true)
    isempty(state.matches) && return nothing
    current = something(state.current_match, 2) - 1
    state.current_match = wrap ? mod1(current, length(state.matches)) : max(current, 1)
    match_result = state.matches[state.current_match]
    state.cursor_line = match_result.range.start.line
    return match_result
end

clear_code_search!(state::CodeViewState) =
    (state.search_query = nothing; empty!(state.matches); state.current_match = nothing; state)

function _syntax_role(kind::SemanticTokenKind)
    return Symbol("syntax_", lowercase(replace(string(kind), "Token" => "")))
end

function _append_span!(spans::Vector{RichSpan}, text, role)
    isempty(text) && return spans
    if !isempty(spans) && last(spans).role == role
        previous = pop!(spans)
        push!(spans, RichSpan(previous.text * String(text), role, nothing))
    else
        push!(spans, RichSpan(String(text), role, nothing))
    end
    return spans
end

function _clip_code_spans(spans::Vector{RichSpan}, offset::Int, width::Int)
    output = RichSpan[]
    skipped = 0
    used = 0
    for span in spans, grapheme in graphemes(span.text)
        grapheme_width = max(1, textwidth(grapheme))
        if skipped + grapheme_width <= offset
            skipped += grapheme_width
            continue
        elseif skipped < offset
            skipped += grapheme_width
            continue
        end
        used + grapheme_width > width && break
        _append_span!(output, grapheme, span.role)
        used += grapheme_width
    end
    return output
end

function _line_has_diagnostic(state::CodeViewState, line::Int)
    return any(diagnostic -> diagnostic.range.start.line <= line <= diagnostic.range.stop.line, state.diagnostics)
end

function _line_has_match(state::CodeViewState, line::Int)
    return any(match_result -> match_result.range.start.line == line, state.matches)
end

struct CodeViewRender
    lines::Vector{RichLine}
    first_line::Int
    total_lines::Int
    cursor_row::Union{Nothing,Int}
end

function render_code_view(
    state::CodeViewState;
    width::Integer=80,
    height::Integer=24,
)
    width > 0 || throw(ArgumentError("code-view width must be positive"))
    height >= 0 || throw(ArgumentError("code-view height cannot be negative"))
    desired_gutter_width = state.show_line_numbers ? length(string(max(1, length(state.lines)))) + 4 : 3
    gutter_width = min(Int(width), desired_gutter_width)
    code_width = max(0, Int(width) - gutter_width)
    lines = RichLine[]
    stop_value = clamp(big(state.first_line) + big(height) - 1, big(0), big(typemax(Int)))
    stop_line = min(length(state.lines), Int(stop_value))
    if height > 0 && state.first_line <= stop_line
        for line_number in state.first_line:stop_line
            breakpoint = line_number in state.breakpoints ? "*" : " "
            diagnostic = _line_has_diagnostic(state, line_number) ? "!" : _line_has_match(state, line_number) ? "?" : " "
            number = state.show_line_numbers ? lpad(string(line_number), desired_gutter_width - 3) * " " : ""
            gutter_role = state.cursor_line == line_number ? :code_gutter_cursor : :code_gutter
            gutter = _clip_code_spans(
                RichSpan[RichSpan("$breakpoint$diagnostic $number", gutter_role, nothing)],
                0,
                gutter_width,
            )
            spans = RichSpan[span for span in gutter]
            tokens = highlight(state.registry, state.lines[line_number], state.language)
            syntax = RichSpan[
                RichSpan(token.value, _syntax_role(token.kind), nothing) for token in tokens
            ]
            append!(spans, _clip_code_spans(syntax, state.horizontal_offset, code_width))
            selected = line_number in selected_code_lines(state)
            role = selected ? :code_selected_line : state.cursor_line == line_number ? :code_cursor_line : :code_line
            push!(lines, RichLine(spans, role, nothing))
        end
    end
    cursor_row = state.cursor_line === nothing || !(state.first_line <= state.cursor_line <= stop_line) ? nothing :
        state.cursor_line - state.first_line + 1
    return CodeViewRender(lines, state.first_line, length(state.lines), cursor_row)
end

function code_view_semantic_node(state::CodeViewState, id; label::AbstractString="Code", bounds=nothing)
    error_count = count(diagnostic -> diagnostic.severity == CodeError, state.diagnostics)
    return SemanticNode(
        id,
        TextboxRole;
        label=label,
        bounds=bounds,
        state=SemanticState(
            focusable=true,
            readonly=true,
            invalid=error_count > 0,
            value="$(length(state.lines)) lines",
        ),
        actions=[ScrollIntoViewSemanticAction],
        metadata=Dict(
            :language => state.language,
            :revision => state.revision,
            :breakpoints => sort!(collect(state.breakpoints)),
            :diagnostic_count => length(state.diagnostics),
        ),
    )
end

@enum DiffLineKind begin
    DiffContextLine
    DiffAddedLine
    DiffRemovedLine
    DiffHeaderLine
    DiffHunkLine
    DiffMetadataLine
end

struct DiffLine
    kind::DiffLineKind
    text::String
    old_line::Union{Nothing,Int}
    new_line::Union{Nothing,Int}
end

struct UnifiedDiff
    lines::Vector{DiffLine}
    diagnostics::Vector{String}
end

function parse_unified_diff(source::AbstractString)
    lines = DiffLine[]
    diagnostics = String[]
    old_line = nothing
    new_line = nothing
    for raw_line in split(_normalize_source(source), '\n'; keepempty=true)
        line = String(raw_line)
        if startswith(line, "@@")
            matched = match(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
            if matched === nothing
                push!(diagnostics, "invalid hunk header: $line")
                push!(lines, DiffLine(DiffHunkLine, line, nothing, nothing))
            else
                old_line = parse(Int, matched.captures[1])
                new_line = parse(Int, matched.captures[3])
                push!(lines, DiffLine(DiffHunkLine, line, old_line, new_line))
            end
        elseif startswith(line, "---") || startswith(line, "+++") || startswith(line, "diff ") || startswith(line, "index ")
            push!(lines, DiffLine(DiffHeaderLine, line, nothing, nothing))
        elseif startswith(line, "+") && new_line !== nothing
            push!(lines, DiffLine(DiffAddedLine, line[2:end], nothing, new_line))
            new_line += 1
        elseif startswith(line, "-") && old_line !== nothing
            push!(lines, DiffLine(DiffRemovedLine, line[2:end], old_line, nothing))
            old_line += 1
        elseif startswith(line, " ") && old_line !== nothing && new_line !== nothing
            push!(lines, DiffLine(DiffContextLine, line[2:end], old_line, new_line))
            old_line += 1
            new_line += 1
        else
            push!(lines, DiffLine(DiffMetadataLine, line, nothing, nothing))
        end
    end
    return UnifiedDiff(lines, diagnostics)
end

function _clip_diff_text(text::String, width::Int)
    textwidth(text) <= width && return text
    width <= 0 && return ""
    width == 1 && return "~"
    output = IOBuffer()
    used = 0
    for grapheme in graphemes(text)
        grapheme_width = max(1, textwidth(grapheme))
        used + grapheme_width > width - 1 && break
        print(output, grapheme)
        used += grapheme_width
    end
    print(output, '~')
    return String(take!(output))
end

function render_unified_diff(
    diff::UnifiedDiff;
    width::Integer=100,
    height::Integer=typemax(Int),
    first_line::Integer=1,
)
    width > 0 || throw(ArgumentError("diff width must be positive"))
    height >= 0 || throw(ArgumentError("diff height cannot be negative"))
    first_line > 0 || throw(ArgumentError("first diff line must be positive"))
    stop_value = clamp(big(first_line) + big(height) - 1, big(0), big(typemax(Int)))
    stop = min(length(diff.lines), Int(stop_value))
    first_line > stop && return RichLine[]
    rendered = RichLine[]
    for line in @view diff.lines[Int(first_line):stop]
        old_number = line.old_line === nothing ? "" : string(line.old_line)
        new_number = line.new_line === nothing ? "" : string(line.new_line)
        marker = line.kind == DiffAddedLine ? "+" : line.kind == DiffRemovedLine ? "-" : " "
        prefix = lpad(old_number, 5) * " " * lpad(new_number, 5) * " $marker "
        role = line.kind == DiffAddedLine ? :diff_added :
               line.kind == DiffRemovedLine ? :diff_removed :
               line.kind == DiffHunkLine ? :diff_hunk :
               line.kind == DiffHeaderLine ? :diff_header : :diff_context
        text = _clip_diff_text(prefix * line.text, Int(width))
        push!(rendered, RichLine(RichSpan[RichSpan(text, role, nothing)], role, nothing))
    end
    return rendered
end

end
