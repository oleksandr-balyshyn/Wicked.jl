module RichSurfaces

using Unicode: graphemes
using ..RichContent: RichLine, RichSpan, plain_text
using ..RichWidgets: MarkdownView,
                     MarkdownViewport,
                     TextSelection,
                     TextPoint,
                     markdown_viewport

export RichSurfaceCell,
       RichSurface,
       RichRenderStats,
       resize_rich_surface!,
       clear_rich_surface!,
       render_rich_lines!,
       render_markdown_surface!,
       rich_surface_hit_test,
       rich_surface_lines,
       rich_surface_snapshot,
       blit_rich_surface!

struct RichSurfaceCell
    grapheme::String
    role::Symbol
    link_id::Union{Nothing,Int}
    continuation::Bool
    selected::Bool
end

_blank_cell() = RichSurfaceCell(" ", :text, nothing, false, false)

mutable struct RichSurface
    width::Int
    height::Int
    cells::Matrix{RichSurfaceCell}

    function RichSurface(width::Integer, height::Integer)
        width >= 0 || throw(ArgumentError("surface width cannot be negative"))
        height >= 0 || throw(ArgumentError("surface height cannot be negative"))
        cells = fill(_blank_cell(), Int(height), Int(width))
        new(Int(width), Int(height), cells)
    end
end

struct RichRenderStats
    graphemes::Int
    cells::Int
    clipped_graphemes::Int
    lines::Int
end

function resize_rich_surface!(surface::RichSurface, width::Integer, height::Integer)
    width >= 0 || throw(ArgumentError("surface width cannot be negative"))
    height >= 0 || throw(ArgumentError("surface height cannot be negative"))
    surface.width = Int(width)
    surface.height = Int(height)
    surface.cells = fill(_blank_cell(), surface.height, surface.width)
    return surface
end

function clear_rich_surface!(surface::RichSurface)
    fill!(surface.cells, _blank_cell())
    return surface
end

function _ordered(selection::TextSelection)
    anchor = (selection.anchor.line, selection.anchor.column)
    head = (selection.head.line, selection.head.column)
    return anchor <= head ? (selection.anchor, selection.head) : (selection.head, selection.anchor)
end

function _is_selected(
    selection::Union{Nothing,TextSelection},
    line::Int,
    first_column::Int,
    stop_column::Int,
)
    selection === nothing && return false
    first_point, stop_point = _ordered(selection)
    line < first_point.line && return false
    line > stop_point.line && return false
    selection_start = line == first_point.line ? first_point.column : 1
    selection_stop = line == stop_point.line ? stop_point.column : typemax(Int)
    return first_column < selection_stop && stop_column > selection_start
end

function _put_grapheme!(
    surface::RichSurface,
    row::Int,
    column::Int,
    grapheme::AbstractString,
    role::Symbol,
    link_id,
    selected::Bool,
)
    width = max(1, textwidth(grapheme))
    column + width - 1 <= surface.width || return false
    surface.cells[row, column] = RichSurfaceCell(String(grapheme), role, link_id, false, selected)
    for continuation_column in (column + 1):(column + width - 1)
        surface.cells[row, continuation_column] = RichSurfaceCell("", role, link_id, true, selected)
    end
    return true
end

function render_rich_lines!(
    surface::RichSurface,
    lines::AbstractVector{RichLine};
    row::Integer=1,
    column::Integer=1,
    first_document_line::Integer=1,
    focused_link::Union{Nothing,Integer}=nothing,
    selection::Union{Nothing,TextSelection}=nothing,
    clear::Bool=true,
    tab_width::Integer=4,
)
    row > 0 || throw(ArgumentError("render row must be positive"))
    column > 0 || throw(ArgumentError("render column must be positive"))
    first_document_line > 0 || throw(ArgumentError("first document line must be positive"))
    tab_width > 0 || throw(ArgumentError("tab width must be positive"))
    clear && clear_rich_surface!(surface)
    grapheme_count = 0
    cell_count = 0
    clipped = 0
    rendered_lines = 0
    start_row = Int(row)
    start_column = Int(column)
    for (line_offset, line) in enumerate(lines)
        target_row = start_row + line_offset - 1
        target_row > surface.height && break
        target_row < 1 && continue
        target_column = start_column
        character_column = 1
        document_line = Int(first_document_line) + line_offset - 1
        for span in line.spans
            role = focused_link !== nothing && span.link_id == focused_link ? :link_focused : span.role
            for item in graphemes(span.text)
                if item == "\t"
                    expansion = Int(tab_width) - mod(target_column - 1, Int(tab_width))
                    selected = _is_selected(selection, document_line, character_column, character_column + 1)
                    grapheme_count += 1
                    (target_column < 1 || target_column + expansion - 1 > surface.width) && (clipped += 1)
                    for offset in 0:(expansion - 1)
                        cell_column = target_column + offset
                        1 <= cell_column <= surface.width || continue
                        _put_grapheme!(surface, target_row, cell_column, " ", role, span.link_id, selected)
                        cell_count += 1
                    end
                    target_column += expansion
                    character_column += 1
                    continue
                end
                grapheme = String(item)
                width = max(1, textwidth(grapheme))
                character_width = max(1, length(grapheme))
                selected = _is_selected(selection, document_line, character_column, character_column + character_width)
                grapheme_count += 1
                if target_column < 1 || target_column + width - 1 > surface.width
                    clipped += 1
                elseif _put_grapheme!(surface, target_row, target_column, grapheme, role, span.link_id, selected)
                    cell_count += width
                end
                target_column += width
                character_column += character_width
            end
        end
        rendered_lines += 1
    end
    return RichRenderStats(grapheme_count, cell_count, clipped, rendered_lines)
end

function render_markdown_surface!(
    surface::RichSurface,
    view::MarkdownView;
    height::Integer=surface.height,
    row::Integer=1,
    column::Integer=1,
    clear::Bool=true,
)
    available_height = clamp(Int(height), 0, max(0, surface.height - Int(row) + 1))
    viewport = markdown_viewport(view, available_height)
    stats = render_rich_lines!(
        surface,
        viewport.lines;
        row=row,
        column=column,
        first_document_line=viewport.first_line,
        focused_link=viewport.focused_link,
        selection=viewport.selection,
        clear=clear,
    )
    return viewport, stats
end

function rich_surface_hit_test(surface::RichSurface, row::Integer, column::Integer)
    1 <= row <= surface.height || return nothing
    1 <= column <= surface.width || return nothing
    cell = surface.cells[row, column]
    return cell.link_id
end

function rich_surface_lines(surface::RichSurface)
    lines = String[]
    for row in 1:surface.height
        output = IOBuffer()
        for column in 1:surface.width
            cell = surface.cells[row, column]
            cell.continuation || print(output, cell.grapheme)
        end
        push!(lines, String(take!(output)))
    end
    return lines
end

function rich_surface_snapshot(surface::RichSurface; include_roles::Bool=false)
    lines = rich_surface_lines(surface)
    include_roles || return join(lines, '\n')
    role_lines = String[]
    for row in 1:surface.height
        runs = String[]
        current_role = nothing
        run_start = 1
        for column in 1:(surface.width + 1)
            role = column <= surface.width ? surface.cells[row, column].role : nothing
            if role != current_role
                current_role === nothing || push!(runs, "$run_start-$(column - 1):$current_role")
                current_role = role
                run_start = column
            end
        end
        push!(role_lines, "$(lines[row]) | " * join(runs, ','))
    end
    return join(role_lines, '\n')
end

"""
Copy a rich surface into another buffer through a caller-provided cell writer.

The callback receives `(target, row, column, cell)`. This keeps the rich renderer
usable with Wicked's Core buffer, test buffers, and third-party surfaces without
duplicating grapheme and continuation logic.
"""
function blit_rich_surface!(
    write_cell!::F,
    target,
    surface::RichSurface;
    row::Integer=1,
    column::Integer=1,
) where {F}
    for source_row in 1:surface.height, source_column in 1:surface.width
        write_cell!(
            target,
            Int(row) + source_row - 1,
            Int(column) + source_column - 1,
            surface.cells[source_row, source_column],
        )
    end
    return target
end

end
