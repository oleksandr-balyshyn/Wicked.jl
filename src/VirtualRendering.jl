module VirtualRendering

using Unicode: graphemes
using ..RichContent: RichSpan, RichLine
using ..RichSurfaces: RichSurface, RichRenderStats, render_rich_lines!
using ..Virtualization: DataSlotKind,
                        ReadySlot,
                        LoadingSlot,
                        FailedSlot,
                        EndSlot,
                        DataSlot,
                        VirtualListState,
                        VirtualListWindow,
                        VirtualTableColumn,
                        VirtualTableCell,
                        VirtualTableRow,
                        VirtualTableWindow,
                        scroll_virtual_list!,
                        move_virtual_cursor!,
                        select_virtual_index!,
                        toggle_virtual_selection!,
                        ensure_virtual_cursor_visible!
using ..VirtualTrees: VirtualTreeState,
                      VirtualTreeRow,
                      VirtualTreeWindow,
                      move_virtual_tree_cursor!,
                      select_virtual_tree!,
                      toggle_virtual_tree!,
                      expand_virtual_tree!,
                      collapse_virtual_tree!
using ..Accessibility: SemanticRect,
                       SemanticState,
                       SemanticAction,
                       SemanticNode,
                       SemanticTree,
                       ListRole,
                       ListItemRole,
                       TableRole,
                       RowRole,
                       CellRole,
                       TreeRole,
                       TreeItemRole,
                       SelectSemanticAction,
                       ActivateSemanticAction,
                       ExpandSemanticAction,
                       CollapseSemanticAction

export VirtualListFormat,
       VirtualTableFormat,
       VirtualTreeFormat,
       render_virtual_list,
       render_virtual_table,
       render_virtual_tree,
       render_virtual_list_surface!,
       render_virtual_table_surface!,
       render_virtual_tree_surface!,
       virtual_list_slot_at,
       virtual_tree_row_at,
       VirtualAction,
       VirtualCursorUp,
       VirtualCursorDown,
       VirtualPageUp,
       VirtualPageDown,
       VirtualHome,
       VirtualEnd,
       VirtualToggleSelection,
       VirtualActivate,
       VirtualExpand,
       VirtualCollapse,
       VirtualActionResult,
       handle_virtual_list_action!,
       handle_virtual_tree_action!,
       virtual_list_semantic_tree,
       virtual_table_semantic_tree,
       virtual_tree_semantic_tree

struct VirtualListFormat{F,E}
    item::F
    error::E
    cursor_marker::String
    selected_marker::String
    normal_marker::String
    loading_text::String
    end_text::String

    function VirtualListFormat(;
        item=(value, index) -> string(value),
        error=(value, index) -> "error loading item $index",
        cursor_marker::AbstractString=">",
        selected_marker::AbstractString="*",
        normal_marker::AbstractString=" ",
        loading_text::AbstractString="loading...",
        end_text::AbstractString="",
    )
        new{typeof(item),typeof(error)}(
            item,
            error,
            String(cursor_marker),
            String(selected_marker),
            String(normal_marker),
            String(loading_text),
            String(end_text),
        )
    end
end

struct VirtualTableFormat
    separator::String
    show_header::Bool
    loading_text::String
    error_text::String

    function VirtualTableFormat(;
        separator::AbstractString=" | ",
        show_header::Bool=true,
        loading_text::AbstractString="loading...",
        error_text::AbstractString="error",
    )
        new(String(separator), show_header, String(loading_text), String(error_text))
    end
end

struct VirtualTreeFormat{F}
    item::F
    indent::String
    expanded_marker::String
    collapsed_marker::String
    leaf_marker::String
    cursor_marker::String
    selected_marker::String

    function VirtualTreeFormat(;
        item=(value, depth) -> string(value),
        indent::AbstractString="  ",
        expanded_marker::AbstractString="-",
        collapsed_marker::AbstractString="+",
        leaf_marker::AbstractString=" ",
        cursor_marker::AbstractString=">",
        selected_marker::AbstractString="*",
    )
        new{typeof(item)}(
            item,
            String(indent),
            String(expanded_marker),
            String(collapsed_marker),
            String(leaf_marker),
            String(cursor_marker),
            String(selected_marker),
        )
    end
end

function _clip_text(value::AbstractString, width::Int)
    width <= 0 && return ""
    textwidth(value) <= width && return String(value)
    width == 1 && return "~"
    output = IOBuffer()
    used = 0
    for grapheme in graphemes(value)
        grapheme_width = max(1, textwidth(grapheme))
        used + grapheme_width > width - 1 && break
        print(output, grapheme)
        used += grapheme_width
    end
    print(output, '~')
    return String(take!(output))
end

function _fit_text(value::AbstractString, width::Int, alignment::Symbol=:left)
    clipped = _clip_text(value, width)
    padding = max(0, width - textwidth(clipped))
    if alignment == :right
        return repeat(" ", padding) * clipped
    elseif alignment == :center
        left = div(padding, 2)
        return repeat(" ", left) * clipped * repeat(" ", padding - left)
    end
    return clipped * repeat(" ", padding)
end

_line(text, role::Symbol) = RichLine(RichSpan[RichSpan(String(text), role, nothing)], role, nothing)

function _visible_slots(window::VirtualListWindow)
    return DataSlot[
        slot for slot in window.slots
        if window.first_visible <= slot.index <= window.last_visible
    ]
end

function render_virtual_list(
    window::VirtualListWindow{T,K},
    state::VirtualListState{K};
    width::Integer=80,
    format::VirtualListFormat=VirtualListFormat(),
) where {T,K}
    width > 0 || throw(ArgumentError("virtual list width must be positive"))
    lines = RichLine[]
    for slot in _visible_slots(window)
        cursor = state.cursor == slot.index
        selected = slot.key !== nothing && slot.key in state.selected
        marker = cursor ? format.cursor_marker : selected ? format.selected_marker : format.normal_marker
        body, role = if slot.kind == ReadySlot
            (string(format.item(slot.item, slot.index)), selected ? :virtual_item_selected : cursor ? :virtual_item_cursor : :virtual_item)
        elseif slot.kind == LoadingSlot
            (format.loading_text, :virtual_loading)
        elseif slot.kind == FailedSlot
            (string(format.error(slot.error, slot.index)), :virtual_error)
        else
            (format.end_text, :virtual_end)
        end
        push!(lines, _line(_clip_text("$marker $body", Int(width)), role))
    end
    return lines
end

function _table_row_text(cells::Vector{VirtualTableCell}, separator::String)
    return join((_fit_text(cell.value, cell.width, cell.alignment) for cell in cells), separator)
end

function render_virtual_table(
    window::VirtualTableWindow{K};
    width::Integer=80,
    format::VirtualTableFormat=VirtualTableFormat(),
    selected=Set{K}(),
    cursor::Union{Nothing,Integer}=nothing,
) where {K}
    width > 0 || throw(ArgumentError("virtual table width must be positive"))
    lines = RichLine[]
    if format.show_header
        headers = VirtualTableCell[
            VirtualTableCell(column.id, column.title, column.width, column.alignment) for column in window.columns
        ]
        push!(lines, _line(_clip_text(_table_row_text(headers, format.separator), Int(width)), :virtual_table_header))
    end
    for row in window.rows
        window.first_visible <= row.index <= window.last_visible || continue
        text, role = if row.kind == ReadySlot
            (_table_row_text(row.cells, format.separator), row.key !== nothing && row.key in selected ? :virtual_table_selected : cursor == row.index ? :virtual_table_cursor : :virtual_table_row)
        elseif row.kind == LoadingSlot
            (format.loading_text, :virtual_loading)
        elseif row.kind == FailedSlot
            (format.error_text, :virtual_error)
        else
            ("", :virtual_end)
        end
        push!(lines, _line(_clip_text(text, Int(width)), role))
    end
    return lines
end

function render_virtual_tree(
    window::VirtualTreeWindow{T,K},
    state::VirtualTreeState{K};
    first_row::Integer=1,
    height::Integer=length(window.rows),
    width::Integer=80,
    format::VirtualTreeFormat=VirtualTreeFormat(),
) where {T,K}
    first_row > 0 || throw(ArgumentError("first virtual tree row must be positive"))
    height >= 0 || throw(ArgumentError("virtual tree height cannot be negative"))
    width > 0 || throw(ArgumentError("virtual tree width must be positive"))
    stop_row = min(length(window.rows), Int(first_row) + Int(height) - 1)
    first_row > stop_row && return RichLine[]
    lines = RichLine[]
    for row in @view window.rows[Int(first_row):stop_row]
        cursor_marker = state.cursor == row.key ? format.cursor_marker : row.key in state.selected ? format.selected_marker : " "
        expansion = !row.expandable ? format.leaf_marker : row.expanded ? format.expanded_marker : format.collapsed_marker
        body = string(format.item(row.item, row.depth))
        text = cursor_marker * " " * repeat(format.indent, row.depth) * expansion * " " * body
        role = row.key in state.selected ? :virtual_tree_selected : state.cursor == row.key ? :virtual_tree_cursor : :virtual_tree_item
        push!(lines, _line(_clip_text(text, Int(width)), role))
    end
    return lines
end

function render_virtual_list_surface!(
    surface::RichSurface,
    window::VirtualListWindow,
    state::VirtualListState;
    kwargs...,
)
    lines = render_virtual_list(window, state; width=surface.width, kwargs...)
    return render_rich_lines!(surface, lines)
end

function render_virtual_table_surface!(surface::RichSurface, window::VirtualTableWindow; kwargs...)
    lines = render_virtual_table(window; width=surface.width, kwargs...)
    return render_rich_lines!(surface, lines)
end

function render_virtual_tree_surface!(
    surface::RichSurface,
    window::VirtualTreeWindow,
    state::VirtualTreeState;
    kwargs...,
)
    lines = render_virtual_tree(window, state; width=surface.width, height=surface.height, kwargs...)
    return render_rich_lines!(surface, lines)
end

function virtual_list_slot_at(window::VirtualListWindow, viewport_row::Integer)
    viewport_row > 0 || return nothing
    index = window.first_visible + Int(viewport_row) - 1
    index > window.last_visible && return nothing
    for slot in window.slots
        slot.index == index && return slot
    end
    return nothing
end

function virtual_tree_row_at(
    window::VirtualTreeWindow,
    viewport_row::Integer;
    first_row::Integer=1,
)
    viewport_row > 0 || return nothing
    index = Int(first_row) + Int(viewport_row) - 1
    return 1 <= index <= length(window.rows) ? window.rows[index] : nothing
end

@enum VirtualAction begin
    VirtualCursorUp
    VirtualCursorDown
    VirtualPageUp
    VirtualPageDown
    VirtualHome
    VirtualEnd
    VirtualToggleSelection
    VirtualActivate
    VirtualExpand
    VirtualCollapse
end

struct VirtualActionResult{K}
    consumed::Bool
    action::VirtualAction
    key::Union{Nothing,K}
end

function _slot_for_cursor(window::VirtualListWindow, cursor)
    cursor === nothing && return nothing
    index = findfirst(slot -> slot.index == cursor, window.slots)
    return index === nothing ? nothing : window.slots[index]
end

function handle_virtual_list_action!(
    state::VirtualListState{K},
    window::VirtualListWindow{T,K},
    action::VirtualAction,
) where {T,K}
    total = window.total_length
    page = max(1, state.viewport.viewport_size - 1)
    if action == VirtualCursorUp
        move_virtual_cursor!(state, -1; total_length=total)
    elseif action == VirtualCursorDown
        move_virtual_cursor!(state, 1; total_length=total)
    elseif action == VirtualPageUp
        move_virtual_cursor!(state, -page; total_length=total)
    elseif action == VirtualPageDown
        move_virtual_cursor!(state, page; total_length=total)
    elseif action == VirtualHome
        state.cursor = total == 0 ? nothing : 1
    elseif action == VirtualEnd
        total === nothing && return VirtualActionResult{K}(false, action, nothing)
        state.cursor = total == 0 ? nothing : total
    elseif action == VirtualToggleSelection
        slot = _slot_for_cursor(window, state.cursor)
        slot === nothing && return VirtualActionResult{K}(false, action, nothing)
        toggle_virtual_selection!(state, slot) || return VirtualActionResult{K}(false, action, nothing)
    elseif action == VirtualActivate
        slot = _slot_for_cursor(window, state.cursor)
        key = slot === nothing ? nothing : slot.key
        return VirtualActionResult{K}(key !== nothing, action, key)
    else
        return VirtualActionResult{K}(false, action, nothing)
    end
    ensure_virtual_cursor_visible!(state; total_length=total)
    slot = _slot_for_cursor(window, state.cursor)
    return VirtualActionResult{K}(true, action, slot === nothing ? nothing : slot.key)
end

function handle_virtual_tree_action!(
    state::VirtualTreeState{K},
    window::VirtualTreeWindow{T,K},
    action::VirtualAction;
    page_size::Integer=10,
) where {T,K}
    if action == VirtualCursorUp
        move_virtual_tree_cursor!(state, window, -1)
    elseif action == VirtualCursorDown
        move_virtual_tree_cursor!(state, window, 1)
    elseif action == VirtualPageUp
        move_virtual_tree_cursor!(state, window, -max(1, Int(page_size)))
    elseif action == VirtualPageDown
        move_virtual_tree_cursor!(state, window, max(1, Int(page_size)))
    elseif action == VirtualHome
        state.cursor = isempty(window.rows) ? nothing : first(window.rows).key
    elseif action == VirtualEnd
        state.cursor = isempty(window.rows) ? nothing : last(window.rows).key
    elseif action == VirtualToggleSelection
        state.cursor === nothing && return VirtualActionResult{K}(false, action, nothing)
        if state.cursor in state.selected
            delete!(state.selected, state.cursor)
        else
            select_virtual_tree!(state, state.cursor)
        end
    elseif action == VirtualActivate
        return VirtualActionResult{K}(state.cursor !== nothing, action, state.cursor)
    elseif action == VirtualExpand || action == VirtualCollapse
        state.cursor === nothing && return VirtualActionResult{K}(false, action, nothing)
        row_index = findfirst(row -> row.key == state.cursor, window.rows)
        row_index === nothing && return VirtualActionResult{K}(false, action, nothing)
        row = window.rows[row_index]
        row.expandable || return VirtualActionResult{K}(false, action, nothing)
        action == VirtualExpand ? expand_virtual_tree!(state, row.key) : collapse_virtual_tree!(state, row.key)
    else
        return VirtualActionResult{K}(false, action, nothing)
    end
    return VirtualActionResult{K}(true, action, state.cursor)
end

function _row_bounds(origin_row::Int, origin_column::Int, offset::Int, width::Int)
    return SemanticRect(origin_row + offset, origin_column, max(0, width), 1)
end

function virtual_list_semantic_tree(
    window::VirtualListWindow{T,K},
    state::VirtualListState{K};
    id="virtual-list",
    label::AbstractString="",
    origin_row::Integer=1,
    origin_column::Integer=1,
    width::Integer=1,
    format::VirtualListFormat=VirtualListFormat(),
) where {T,K}
    children = SemanticNode[]
    for (offset, slot) in enumerate(_visible_slots(window))
        slot.kind == EndSlot && continue
        item_label = slot.kind == ReadySlot ? string(format.item(slot.item, slot.index)) :
                     slot.kind == LoadingSlot ? format.loading_text : "error"
        key_text = slot.key === nothing ? "index-$(slot.index)" : string(slot.key)
        state_value = SemanticState(
            enabled=slot.kind == ReadySlot,
            focusable=slot.kind == ReadySlot,
            focused=state.cursor == slot.index,
            selected=slot.key !== nothing && slot.key in state.selected,
            busy=slot.kind == LoadingSlot,
            invalid=slot.kind == FailedSlot,
        )
        push!(children, SemanticNode(
            "$(id)/$key_text",
            ListItemRole;
            label=item_label,
            bounds=_row_bounds(Int(origin_row), Int(origin_column), offset - 1, Int(width)),
            state=state_value,
            actions=slot.kind == ReadySlot ? [SelectSemanticAction, ActivateSemanticAction] : [],
        ))
    end
    root = SemanticNode(
        id,
        ListRole;
        label=label,
        bounds=SemanticRect(origin_row, origin_column, width, length(children)),
        children=children,
    )
    return SemanticTree(root; generation=window.version)
end

function virtual_table_semantic_tree(
    window::VirtualTableWindow{K};
    id="virtual-table",
    label::AbstractString="",
    origin_row::Integer=1,
    origin_column::Integer=1,
) where {K}
    rows = SemanticNode[]
    for row in window.rows
        row.kind == ReadySlot || continue
        cells = SemanticNode[
            SemanticNode("$(id)/$(row.index)/$(cell.column)", CellRole; label=cell.value) for cell in row.cells
        ]
        push!(rows, SemanticNode(
            "$(id)/$(something(row.key, row.index))",
            RowRole;
            label=join((cell.value for cell in row.cells), " "),
            children=cells,
            actions=[SelectSemanticAction, ActivateSemanticAction],
        ))
    end
    width = sum(column.width for column in window.columns) + max(0, length(window.columns) - 1) * 3
    return SemanticTree(SemanticNode(
        id,
        TableRole;
        label=label,
        bounds=SemanticRect(origin_row, origin_column, width, length(rows) + 1),
        children=rows,
    ))
end

function virtual_tree_semantic_tree(
    window::VirtualTreeWindow{T,K},
    state::VirtualTreeState{K};
    id="virtual-tree",
    label::AbstractString="",
    origin_row::Integer=1,
    origin_column::Integer=1,
    width::Integer=1,
    format::VirtualTreeFormat=VirtualTreeFormat(),
) where {T,K}
    children = SemanticNode[]
    for (offset, row) in enumerate(window.rows)
        actions = SemanticAction[SelectSemanticAction, ActivateSemanticAction]
        row.expandable && push!(actions, row.expanded ? CollapseSemanticAction : ExpandSemanticAction)
        push!(children, SemanticNode(
            "$(id)/$(row.key)",
            TreeItemRole;
            label=string(format.item(row.item, row.depth)),
            bounds=_row_bounds(Int(origin_row), Int(origin_column), offset - 1, Int(width)),
            state=SemanticState(
                focusable=true,
                focused=state.cursor == row.key,
                selected=row.key in state.selected,
                expanded=row.expandable ? row.expanded : nothing,
            ),
            actions=actions,
            metadata=Dict(:depth => row.depth, :parent => row.parent),
        ))
    end
    return SemanticTree(SemanticNode(
        id,
        TreeRole;
        label=label,
        bounds=SemanticRect(origin_row, origin_column, width, length(children)),
        children=children,
    ))
end

end
