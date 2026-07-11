module CodeViewerIntegration

using Unicode: graphemes
using ..RichAdapters: KeyChord
using ..RichContent: RichSpan, RichLine
using ..CodeViewer: CodeViewState,
                    CodeViewRender,
                    UnifiedDiff,
                    DiffLine,
                    DiffLineKind,
                    DiffAddedLine,
                    DiffRemovedLine,
                    DiffContextLine,
                    DiffHeaderLine,
                    DiffHunkLine,
                    render_code_view,
                    render_unified_diff,
                    code_view_semantic_node,
                    scroll_code_view!,
                    move_code_cursor!,
                    toggle_code_breakpoint!,
                    next_code_match!,
                    previous_code_match!,
                    selected_code_text
using ..Clipboard: ClipboardContent, ClipboardService, copy_to_clipboard!
using ..CoreIntegration: ToolkitElementAdapter
using ..ToolkitComponents: ToolkitComponentView, toolkit_component_view

export CodeViewAction,
       CodeCursorUp,
       CodeCursorDown,
       CodePageUp,
       CodePageDown,
       CodeHome,
       CodeEnd,
       CodeScrollLeft,
       CodeScrollRight,
       CodeNextMatch,
       CodePreviousMatch,
       CodeToggleBreakpoint,
       CodeCopySelection,
       CodeViewBindings,
       bind_code_view_key!,
       unbind_code_view_key!,
       default_code_view_bindings,
       code_view_action_for_key,
       CodeViewActionResult,
       handle_code_view_key!,
       copy_code_selection!,
       code_view_component,
       diff_view_component,
       SideBySideDiffRow,
       SideBySideDiff,
       project_side_by_side_diff,
       render_side_by_side_diff,
       side_by_side_diff_component

@enum CodeViewAction begin
    CodeCursorUp
    CodeCursorDown
    CodePageUp
    CodePageDown
    CodeHome
    CodeEnd
    CodeScrollLeft
    CodeScrollRight
    CodeNextMatch
    CodePreviousMatch
    CodeToggleBreakpoint
    CodeCopySelection
end

mutable struct CodeViewBindings
    actions::Dict{KeyChord,CodeViewAction}
end

CodeViewBindings() = CodeViewBindings(Dict{KeyChord,CodeViewAction}())

function bind_code_view_key!(bindings::CodeViewBindings, chord::KeyChord, action::CodeViewAction)
    bindings.actions[chord] = action
    return bindings
end

function bind_code_view_key!(bindings::CodeViewBindings, key, action::CodeViewAction; modifiers...)
    return bind_code_view_key!(bindings, KeyChord(key; modifiers...), action)
end

function unbind_code_view_key!(bindings::CodeViewBindings, chord::KeyChord)
    pop!(bindings.actions, chord, nothing)
    return bindings
end

function default_code_view_bindings(; vim::Bool=false)
    bindings = CodeViewBindings()
    bind_code_view_key!(bindings, :up, CodeCursorUp)
    bind_code_view_key!(bindings, :down, CodeCursorDown)
    bind_code_view_key!(bindings, :pageup, CodePageUp)
    bind_code_view_key!(bindings, :pagedown, CodePageDown)
    bind_code_view_key!(bindings, :home, CodeHome)
    bind_code_view_key!(bindings, :end, CodeEnd)
    bind_code_view_key!(bindings, :left, CodeScrollLeft; alt=true)
    bind_code_view_key!(bindings, :right, CodeScrollRight; alt=true)
    bind_code_view_key!(bindings, :n, CodeNextMatch; control=true)
    bind_code_view_key!(bindings, :n, CodePreviousMatch; control=true, shift=true)
    bind_code_view_key!(bindings, :b, CodeToggleBreakpoint; control=true)
    bind_code_view_key!(bindings, :c, CodeCopySelection; control=true)
    if vim
        bind_code_view_key!(bindings, :k, CodeCursorUp)
        bind_code_view_key!(bindings, :j, CodeCursorDown)
        bind_code_view_key!(bindings, :g, CodeHome)
        bind_code_view_key!(bindings, :g, CodeEnd; shift=true)
        bind_code_view_key!(bindings, :h, CodeScrollLeft)
        bind_code_view_key!(bindings, :l, CodeScrollRight)
    end
    return bindings
end

function code_view_action_for_key(
    bindings::CodeViewBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
)
    action = get(bindings.actions, KeyChord(key; control=control, alt=alt, shift=shift), nothing)
    action === nothing && shift &&
        (action = get(bindings.actions, KeyChord(key; control=control, alt=alt, shift=false), nothing))
    return action
end

struct CodeViewActionResult
    consumed::Bool
    action::Union{Nothing,CodeViewAction}
    value::Any
end

function handle_code_view_key!(
    state::CodeViewState,
    bindings::CodeViewBindings,
    key;
    control::Bool=false,
    alt::Bool=false,
    shift::Bool=false,
    viewport_height::Integer=24,
    clipboard::Union{Nothing,ClipboardService}=nothing,
)
    action = code_view_action_for_key(bindings, key; control=control, alt=alt, shift=shift)
    action === nothing && return CodeViewActionResult(false, nothing, nothing)
    page = max(1, Int(viewport_height) - 1)
    if action == CodeCursorUp
        move_code_cursor!(state, -1; viewport_height=viewport_height, extend_selection=shift)
    elseif action == CodeCursorDown
        move_code_cursor!(state, 1; viewport_height=viewport_height, extend_selection=shift)
    elseif action == CodePageUp
        move_code_cursor!(state, -page; viewport_height=viewport_height, extend_selection=shift)
    elseif action == CodePageDown
        move_code_cursor!(state, page; viewport_height=viewport_height, extend_selection=shift)
    elseif action == CodeHome
        shift && state.selection_anchor === nothing && (state.selection_anchor = state.cursor_line)
        shift || (state.selection_anchor = nothing)
        state.cursor_line = isempty(state.lines) ? nothing : 1
        state.first_line = 1
    elseif action == CodeEnd
        shift && state.selection_anchor === nothing && (state.selection_anchor = state.cursor_line)
        shift || (state.selection_anchor = nothing)
        state.cursor_line = isempty(state.lines) ? nothing : length(state.lines)
        state.first_line = max(1, length(state.lines) - Int(viewport_height) + 1)
    elseif action == CodeScrollLeft
        scroll_code_view!(state, 0, -4; viewport_height=viewport_height)
    elseif action == CodeScrollRight
        scroll_code_view!(state, 0, 4; viewport_height=viewport_height)
    elseif action == CodeNextMatch
        return CodeViewActionResult(true, action, next_code_match!(state))
    elseif action == CodePreviousMatch
        return CodeViewActionResult(true, action, previous_code_match!(state))
    elseif action == CodeToggleBreakpoint
        return CodeViewActionResult(true, action, toggle_code_breakpoint!(state))
    elseif action == CodeCopySelection
        clipboard === nothing && return CodeViewActionResult(false, action, nothing)
        return CodeViewActionResult(true, action, copy_code_selection!(clipboard, state))
    end
    return CodeViewActionResult(true, action, state.cursor_line)
end

function copy_code_selection!(
    clipboard::ClipboardService,
    state::CodeViewState;
    current_line_fallback::Bool=true,
    sensitive::Bool=false,
)
    text = selected_code_text(state; current_line_fallback=current_line_fallback)
    isempty(text) && return false
    copy_to_clipboard!(clipboard, ClipboardContent(text; sensitive=sensitive))
    return true
end

function code_view_component(
    adapter::ToolkitElementAdapter,
    state::CodeViewState;
    width::Integer=80,
    height::Integer=24,
    semantic_id="code-view",
    semantic_label::AbstractString="Code",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_code_view(state; width=width, height=height)
    semantics = code_view_semantic_node(state, semantic_id; label=semantic_label)
    return toolkit_component_view(
        adapter,
        rendered.lines,
        semantics;
        key=key,
        id=id,
        classes=classes,
        focusable=focusable,
    )
end

function diff_view_component(
    adapter::ToolkitElementAdapter,
    diff::UnifiedDiff;
    width::Integer=100,
    height::Integer=24,
    first_line::Integer=1,
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_unified_diff(diff; width=width, height=height, first_line=first_line)
    return toolkit_component_view(adapter, rendered, nothing; key=key, id=id, classes=classes, focusable=focusable)
end

struct SideBySideDiffRow
    old_line::Union{Nothing,Int}
    old_text::String
    old_kind::DiffLineKind
    new_line::Union{Nothing,Int}
    new_text::String
    new_kind::DiffLineKind
end

struct SideBySideDiff
    rows::Vector{SideBySideDiffRow}
    diagnostics::Vector{String}
end

function project_side_by_side_diff(diff::UnifiedDiff)
    rows = SideBySideDiffRow[]
    index = 1
    while index <= length(diff.lines)
        line = diff.lines[index]
        if line.kind == DiffRemovedLine
            removed = DiffLine[]
            added = DiffLine[]
            while index <= length(diff.lines) && diff.lines[index].kind == DiffRemovedLine
                push!(removed, diff.lines[index])
                index += 1
            end
            while index <= length(diff.lines) && diff.lines[index].kind == DiffAddedLine
                push!(added, diff.lines[index])
                index += 1
            end
            for offset in 1:max(length(removed), length(added))
                old = offset <= length(removed) ? removed[offset] : nothing
                new = offset <= length(added) ? added[offset] : nothing
                push!(rows, SideBySideDiffRow(
                    old === nothing ? nothing : old.old_line,
                    old === nothing ? "" : old.text,
                    old === nothing ? DiffContextLine : old.kind,
                    new === nothing ? nothing : new.new_line,
                    new === nothing ? "" : new.text,
                    new === nothing ? DiffContextLine : new.kind,
                ))
            end
            continue
        elseif line.kind == DiffAddedLine
            push!(rows, SideBySideDiffRow(nothing, "", DiffContextLine, line.new_line, line.text, line.kind))
        else
            push!(rows, SideBySideDiffRow(
                line.old_line,
                line.text,
                line.kind,
                line.new_line,
                line.text,
                line.kind,
            ))
        end
        index += 1
    end
    return SideBySideDiff(rows, copy(diff.diagnostics))
end

function _clip_side(text::String, width::Int)
    textwidth(text) <= width && return text * repeat(" ", max(0, width - textwidth(text)))
    width <= 0 && return ""
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

function render_side_by_side_diff(
    diff::SideBySideDiff;
    width::Integer=120,
    height::Integer=24,
    first_row::Integer=1,
    separator::AbstractString=" | ",
)
    width > textwidth(separator) + 2 || throw(ArgumentError("side-by-side diff width is too small"))
    height >= 0 || throw(ArgumentError("side-by-side diff height cannot be negative"))
    first_row > 0 || throw(ArgumentError("first diff row must be positive"))
    content_width = Int(width) - textwidth(separator)
    left_width = div(content_width, 2)
    right_width = content_width - left_width
    stop = min(length(diff.rows), Int(clamp(big(first_row) + big(height) - 1, big(0), big(typemax(Int)))))
    first_row > stop && return RichLine[]
    lines = RichLine[]
    for row in @view diff.rows[Int(first_row):stop]
        old_prefix = row.old_line === nothing ? "      " : lpad(string(row.old_line), 5) * " "
        new_prefix = row.new_line === nothing ? "      " : lpad(string(row.new_line), 5) * " "
        left = _clip_side(old_prefix * row.old_text, left_width)
        right = _clip_side(new_prefix * row.new_text, right_width)
        left_role = row.old_kind == DiffRemovedLine ? :diff_removed : row.old_kind == DiffHunkLine ? :diff_hunk : :diff_context
        right_role = row.new_kind == DiffAddedLine ? :diff_added : row.new_kind == DiffHunkLine ? :diff_hunk : :diff_context
        spans = RichSpan[
            RichSpan(left, left_role, nothing),
            RichSpan(String(separator), :diff_separator, nothing),
            RichSpan(right, right_role, nothing),
        ]
        push!(lines, RichLine(spans, :diff_side_by_side, nothing))
    end
    return lines
end

function side_by_side_diff_component(
    adapter::ToolkitElementAdapter,
    diff::SideBySideDiff;
    width::Integer=120,
    height::Integer=24,
    first_row::Integer=1,
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_side_by_side_diff(diff; width=width, height=height, first_row=first_row)
    return toolkit_component_view(adapter, rendered, nothing; key=key, id=id, classes=classes, focusable=focusable)
end

end
