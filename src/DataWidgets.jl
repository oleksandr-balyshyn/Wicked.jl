"""
Virtualized immediate-mode data widgets built from Wicked's shared data,
tree, event-routing, rendering, and semantic primitives.
"""

struct DataGrid{S,F}
    source::S
    columns::Vector{VirtualTableColumn}
    format::F
    width::Int
    height::Int
    show_header::Bool
    separator::String
    header_style::Style
    cursor_style::Style
    selected_style::Style
    bindings::VirtualBindings
    pointer_options::VirtualPointerOptions
end

function DataGrid(
    source::AbstractDataSource,
    columns::AbstractVector{<:VirtualTableColumn};
    format=(value, column) -> string(value),
    width::Integer=80,
    height::Integer=24,
    show_header::Bool=true,
    separator::AbstractString=" | ",
    header_style::Style=Style(modifiers=BOLD),
    cursor_style::Style=Style(modifiers=REVERSED),
    selected_style::Style=Style(modifiers=BOLD),
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
)
    width > 0 || throw(ArgumentError("data grid width must be positive"))
    height >= 0 || throw(ArgumentError("data grid height cannot be negative"))
    return DataGrid(source, VirtualTableColumn[column for column in columns], format,
        Int(width), Int(height), show_header, String(separator), header_style,
        cursor_style, selected_style, bindings, pointer_options)
end

"""Explicit cursor, selection, column-focus, and virtual viewport state for `DataGrid`."""
mutable struct DataGridState{K}
    rows::VirtualListState{K}
    selected_column::Union{Nothing,Int}
end

function DataGridState(
    source::AbstractDataSource{T,K};
    first_index::Integer=1,
    viewport_size::Integer=0,
    overscan::Integer=5,
    multiple::Bool=false,
    selected_column::Union{Nothing,Integer}=nothing,
) where {T,K}
    selected_column !== nothing && selected_column < 1 &&
        throw(ArgumentError("selected data-grid column must be positive"))
    return DataGridState{K}(
        VirtualListState{K}(; first_index, viewport_size, overscan, multiple),
        selected_column === nothing ? nothing : Int(selected_column),
    )
end

state_for(widget::DataGrid) = DataGridState(widget.source)
measure(widget::DataGrid, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function _data_widget_area(widget, area::Rect)
    return Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width))
end

function _data_column_area(columns, separator::AbstractString, area::Rect, column_index::Int)
    column_index in eachindex(columns) || return nothing
    column = area.column
    separator_width = text_width(separator)
    for index in eachindex(columns)
        width = min(columns[index].width, max(0, area.column + area.width - column))
        index == column_index && return Rect(area.row, column, area.height, width)
        column += columns[index].width + separator_width
        column >= area.column + area.width && break
    end
    return nothing
end

function _data_grid_window!(widget::DataGrid, state::DataGridState, content_height::Integer)
    resize_virtual_list!(state.rows, max(0, Int(content_height)))
    return project_virtual_table(refresh_virtual_list!(widget.source, state.rows), widget.columns; format=widget.format)
end

function _render_data_grid_row!(buffer::Buffer, widget::DataGrid, area::Rect, row::VirtualTableRow, state::DataGridState)
    style = row.key !== nothing && row.key in state.rows.selected ? widget.selected_style :
            state.rows.cursor == row.index ? widget.cursor_style : Style()
    if row.kind == LoadingSlot
        draw_text!(buffer, area.row, area.column, "loading..."; style, clip=area)
    elseif row.kind == FailedSlot
        draw_text!(buffer, area.row, area.column, "error"; style, clip=area)
    elseif row.kind == ReadySlot
        for (index, cell) in enumerate(row.cells)
            target = _data_column_area(widget.columns, widget.separator, area, index)
            target === nothing && break
            draw_text!(buffer, target.row, target.column, cell.value; style, clip=target)
        end
    end
    return buffer
end

render!(buffer::Buffer, widget::DataGrid, area::Rect) = render!(buffer, widget, area, state_for(widget))

function render!(buffer::Buffer, widget::DataGrid, area::Rect, state::DataGridState)
    active = intersection(buffer.area, _data_widget_area(widget, area))
    isempty(active) && return buffer
    header_rows = widget.show_header && !isempty(widget.columns) ? 1 : 0
    window = _data_grid_window!(widget, state, max(0, active.height - header_rows))
    state.selected_column = isempty(widget.columns) ? nothing : clamp(something(state.selected_column, 1), 1, length(widget.columns))
    if header_rows == 1
        for (index, column) in enumerate(widget.columns)
            target = _data_column_area(widget.columns, widget.separator, active, index)
            target === nothing && break
            draw_text!(buffer, active.row, target.column, column.title; style=widget.header_style, clip=target)
        end
    end
    for row in window.rows
        window.first_visible <= row.index <= window.last_visible || continue
        target_row = active.row + header_rows + row.index - window.first_visible
        target_row >= active.row + active.height && break
        _render_data_grid_row!(buffer, widget, Rect(target_row, active.column, 1, active.width), row, state)
    end
    return buffer
end

function handle!(state::DataGridState, widget::DataGrid, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :left && !isempty(widget.columns)
        state.selected_column = max(1, something(state.selected_column, 1) - 1)
        return true
    elseif event.key.code == :right && !isempty(widget.columns)
        state.selected_column = min(length(widget.columns), something(state.selected_column, 1) + 1)
        return true
    end
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    result = handle_virtual_key!(state.rows, window, widget.bindings, event.key.code;
        control=in(CTRL, event.modifiers), alt=in(ALT, event.modifiers), shift=in(SHIFT, event.modifiers))
    return result.consumed
end

function handle!(state::DataGridState, widget::DataGrid, event::MouseEvent, area::Rect)
    active = _data_widget_area(widget, area)
    contains(active, event.position) || return false
    header_rows = widget.show_header && !isempty(widget.columns) ? 1 : 0
    window = _data_grid_window!(widget, state, max(0, active.height - header_rows))
    if event.action == MouseScroll
        delta = event.button == WheelUpButton ? -3 : event.button == WheelDownButton ? 3 : 0
        delta == 0 && return false
        scroll_virtual_list!(state.rows, delta; total_length=window.total_length)
        return true
    end
    event.action in (MousePress, MouseRelease, MouseMove) || return false
    kind = event.action == MouseMove ? VirtualPointerHover : event.click_count > 1 ? VirtualPointerDoublePress : VirtualPointerPress
    result = handle_virtual_pointer!(state.rows, window,
        VirtualPointerEvent(kind, event.position.row - active.row + 1, event.position.column - active.column + 1;
            control=in(CTRL, event.modifiers), shift=in(SHIFT, event.modifiers));
        options=widget.pointer_options, header_rows)
    if result.consumed
        state.selected_column = findfirst(index -> begin
            target = _data_column_area(widget.columns, widget.separator, active, index)
            target !== nothing && contains(target, event.position)
        end, eachindex(widget.columns))
    end
    return result.consumed
end

handle!(::DataGridState, ::DataGrid, ::PasteEvent) = false

"""Return semantic inspection metadata for the current virtual `DataGrid` window."""
function data_grid_semantic_tree(widget::DataGrid, state::DataGridState; id="data-grid", label::AbstractString="Data grid", origin_row::Integer=1, origin_column::Integer=1)
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    return virtual_table_semantic_tree(window; id, label, origin_row, origin_column)
end

function SemanticToolkit.widget_semantic_descriptor(widget::DataGrid, state::DataGridState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TableRole;
        label="Data grid",
        state=Accessibility.SemanticState(focusable=true),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:column_count => length(widget.columns), :row_cursor => state.rows.cursor),
    )
end

function SemanticToolkit.widget_semantic_children(widget::DataGrid, state::DataGridState, id)
    return data_grid_semantic_tree(widget, state; id, label="Data grid").root.children
end

struct TreeTable{S,F}
    source::S
    columns::Vector{VirtualTableColumn}
    format::F
    tree_column::Symbol
    width::Int
    height::Int
    show_header::Bool
    separator::String
    indent::String
    expanded_marker::String
    collapsed_marker::String
    leaf_marker::String
    header_style::Style
    cursor_style::Style
    selected_style::Style
    bindings::VirtualBindings
    pointer_options::VirtualPointerOptions
    max_rows::Int
    max_depth::Int
end

function TreeTable(
    source::AbstractTreeDataSource,
    columns::AbstractVector{<:VirtualTableColumn};
    format=(value, column) -> string(value),
    tree_column::Union{Symbol,AbstractString}=isempty(columns) ? :tree : first(columns).id,
    width::Integer=80,
    height::Integer=24,
    show_header::Bool=true,
    separator::AbstractString=" | ",
    indent::AbstractString="  ",
    expanded_marker::AbstractString="-",
    collapsed_marker::AbstractString="+",
    leaf_marker::AbstractString=" ",
    header_style::Style=Style(modifiers=BOLD),
    cursor_style::Style=Style(modifiers=REVERSED),
    selected_style::Style=Style(modifiers=BOLD),
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
    max_rows::Integer=100_000,
    max_depth::Integer=256,
)
    width > 0 || throw(ArgumentError("tree table width must be positive"))
    height >= 0 || throw(ArgumentError("tree table height cannot be negative"))
    max_rows > 0 || throw(ArgumentError("tree table maximum rows must be positive"))
    max_depth >= 0 || throw(ArgumentError("tree table maximum depth cannot be negative"))
    return TreeTable(source, VirtualTableColumn[column for column in columns], format, Symbol(tree_column),
        Int(width), Int(height), show_header, String(separator), String(indent), String(expanded_marker),
        String(collapsed_marker), String(leaf_marker), header_style, cursor_style, selected_style,
        bindings, pointer_options, Int(max_rows), Int(max_depth))
end

"""Explicit expansion, selection, cursor, and viewport state for `TreeTable`."""
mutable struct TreeTableState{K}
    tree::VirtualTreeState{K}
    first_row::Int
    selected_column::Union{Nothing,Int}
end

function TreeTableState(source::AbstractTreeDataSource{T,K}; multiple::Bool=false, first_row::Integer=1, selected_column::Union{Nothing,Integer}=nothing) where {T,K}
    first_row > 0 || throw(ArgumentError("tree-table first row must be positive"))
    selected_column !== nothing && selected_column < 1 && throw(ArgumentError("selected tree-table column must be positive"))
    return TreeTableState{K}(VirtualTreeState{K}(; multiple), Int(first_row), selected_column === nothing ? nothing : Int(selected_column))
end

state_for(widget::TreeTable) = TreeTableState(widget.source)
measure(widget::TreeTable, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function _tree_table_window(widget::TreeTable, state::TreeTableState)
    return flatten_virtual_tree(widget.source, state.tree; max_rows=widget.max_rows, max_depth=widget.max_depth)
end

function _normalize_tree_table!(state::TreeTableState, window::VirtualTreeWindow, content_height::Integer)
    height = max(0, Int(content_height))
    if isempty(window.rows)
        state.tree.cursor = nothing
        state.first_row = 1
        return state
    end
    index = findfirst(row -> row.key == state.tree.cursor, window.rows)
    index === nothing && (state.tree.cursor = first(window.rows).key; index = 1)
    state.first_row = clamp(state.first_row, 1, max(1, length(window.rows) - height + 1))
    index < state.first_row && (state.first_row = index)
    index >= state.first_row + height && (state.first_row = max(1, index - max(0, height - 1)))
    return state
end

function _tree_table_prefix(widget::TreeTable, row::VirtualTreeRow)
    marker = row.expandable ? (row.expanded ? widget.expanded_marker : widget.collapsed_marker) : widget.leaf_marker
    return repeat(widget.indent, row.depth) * marker * " "
end

render!(buffer::Buffer, widget::TreeTable, area::Rect) = render!(buffer, widget, area, state_for(widget))

function render!(buffer::Buffer, widget::TreeTable, area::Rect, state::TreeTableState)
    active = intersection(buffer.area, _data_widget_area(widget, area))
    isempty(active) && return buffer
    header_rows = widget.show_header && !isempty(widget.columns) ? 1 : 0
    content_height = max(0, active.height - header_rows)
    window = _tree_table_window(widget, state)
    _normalize_tree_table!(state, window, content_height)
    if header_rows == 1
        for (index, column) in enumerate(widget.columns)
            target = _data_column_area(widget.columns, widget.separator, active, index)
            target === nothing && break
            draw_text!(buffer, active.row, target.column, column.title; style=widget.header_style, clip=target)
        end
    end
    stop = min(length(window.rows), state.first_row + content_height - 1)
    for source_index in state.first_row:stop
        row = window.rows[source_index]
        target_row = active.row + header_rows + source_index - state.first_row
        style = row.key in state.tree.selected ? widget.selected_style : state.tree.cursor == row.key ? widget.cursor_style : Style()
        target_area = Rect(target_row, active.column, 1, active.width)
        for (column_index, column) in enumerate(widget.columns)
            target = _data_column_area(widget.columns, widget.separator, target_area, column_index)
            target === nothing && break
            value = string(widget.format(column.accessor(row.item), column))
            column.id == widget.tree_column && (value = _tree_table_prefix(widget, row) * value)
            draw_text!(buffer, target.row, target.column, value; style, clip=target)
        end
    end
    return buffer
end

function handle!(state::TreeTableState, widget::TreeTable, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    window = _tree_table_window(widget, state)
    result = handle_virtual_key!(state.tree, window, widget.bindings, event.key.code;
        control=in(CTRL, event.modifiers), alt=in(ALT, event.modifiers), shift=in(SHIFT, event.modifiers),
        page_size=max(1, widget.height - (widget.show_header ? 1 : 0)))
    result.consumed || return false
    _normalize_tree_table!(state, _tree_table_window(widget, state), max(0, widget.height - (widget.show_header ? 1 : 0)))
    return true
end

function handle!(state::TreeTableState, widget::TreeTable, event::MouseEvent, area::Rect)
    active = _data_widget_area(widget, area)
    contains(active, event.position) || return false
    header_rows = widget.show_header && !isempty(widget.columns) ? 1 : 0
    height = max(0, active.height - header_rows)
    window = _tree_table_window(widget, state)
    _normalize_tree_table!(state, window, height)
    if event.action == MouseScroll
        delta = event.button == WheelUpButton ? -3 : event.button == WheelDownButton ? 3 : 0
        delta == 0 && return false
        state.first_row = clamp(state.first_row + delta, 1, max(1, length(window.rows) - height + 1))
        return true
    end
    event.action in (MousePress, MouseRelease, MouseMove) || return false
    kind = event.action == MouseMove ? VirtualPointerHover : event.click_count > 1 ? VirtualPointerDoublePress : VirtualPointerPress
    result = handle_virtual_pointer!(state.tree, window,
        VirtualPointerEvent(kind, event.position.row - active.row + 1 - header_rows, event.position.column - active.column + 1;
            control=in(CTRL, event.modifiers), shift=in(SHIFT, event.modifiers));
        options=widget.pointer_options, first_row=state.first_row)
    return result.consumed
end

handle!(::TreeTableState, ::TreeTable, ::PasteEvent) = false

"""Return semantic inspection metadata for the current `TreeTable` window."""
function tree_table_semantic_tree(widget::TreeTable, state::TreeTableState; id="tree-table", label::AbstractString="Tree table")
    return virtual_tree_semantic_tree(_tree_table_window(widget, state), state.tree; id, label, width=widget.width)
end

function SemanticToolkit.widget_semantic_descriptor(widget::TreeTable, state::TreeTableState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TreeRole;
        label="Tree table",
        state=Accessibility.SemanticState(focusable=true),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:column_count => length(widget.columns), :row_cursor => state.tree.cursor),
    )
end

function SemanticToolkit.widget_semantic_children(widget::TreeTable, state::TreeTableState, id)
    window = _tree_table_window(widget, state)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(row.key)",
            Accessibility.TreeItemRole;
            label=string(row.key),
            state=Accessibility.SemanticState(
                selected=row.key in state.tree.selected || state.tree.cursor == row.key,
                expanded=row.expandable ? row.expanded : nothing,
            ),
            actions=row.expandable ?
                (row.expanded ? [Accessibility.SelectSemanticAction, Accessibility.CollapseSemanticAction] : [Accessibility.SelectSemanticAction, Accessibility.ExpandSemanticAction]) :
                [Accessibility.SelectSemanticAction],
            metadata=Dict(:depth => row.depth, :parent => row.parent),
        ) for row in window.rows
    ]
end

struct PropertyItem
    label::String
    value::String
end
PropertyItem(label::AbstractString, value::AbstractString) = PropertyItem(String(label), String(value))
PropertyItem(item::Pair) = PropertyItem(string(first(item)), string(last(item)))

"""A scrollable two-column property list for concise key/value metadata."""
struct PropertyList
    items::Vector{PropertyItem}
    width::Int
    height::Int
    separator::String
    label_style::Style
    value_style::Style
end

function PropertyList(items; width::Integer=80, height::Integer=24, separator::AbstractString=": ", label_style::Style=Style(modifiers=BOLD), value_style::Style=Style())
    width > 0 || throw(ArgumentError("property list width must be positive"))
    height >= 0 || throw(ArgumentError("property list height cannot be negative"))
    return PropertyList(PropertyItem[item isa PropertyItem ? item : PropertyItem(item) for item in items], Int(width), Int(height), String(separator), label_style, value_style)
end

const PropertyListState = ScrollState
state_for(::PropertyList) = PropertyListState()
measure(widget::PropertyList, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function _scroll_static_list!(state::ScrollState, delta::Integer, total::Integer, height::Integer)
    state.row = clamp(state.row + Int(delta), 0, max(0, Int(total) - max(0, Int(height))))
    return state
end

function render!(buffer::Buffer, widget::PropertyList, area::Rect, state::PropertyListState)
    active = intersection(buffer.area, _data_widget_area(widget, area))
    isempty(active) && return buffer
    _scroll_static_list!(state, 0, length(widget.items), active.height)
    for visible in 1:active.height
        index = state.row + visible
        index > length(widget.items) && break
        item = widget.items[index]
        row = active.row + visible - 1
        draw_text!(buffer, row, active.column, item.label; style=widget.label_style, clip=active)
        column = active.column + min(active.width, text_width(item.label))
        column < active.column + active.width && draw_text!(buffer, row, column, widget.separator * item.value; style=widget.value_style, clip=active)
    end
    return buffer
end
render!(buffer::Buffer, widget::PropertyList, area::Rect) = render!(buffer, widget, area, state_for(widget))

function _handle_static_list!(state::ScrollState, total::Integer, event::KeyEvent, height::Integer)
    event.kind in (KeyPress, KeyRepeat) || return false
    delta = event.key.code == :up ? -1 : event.key.code == :down ? 1 :
            event.key.code in (:page_up, :pageup) ? -max(1, Int(height)) :
            event.key.code in (:page_down, :pagedown) ? max(1, Int(height)) :
            event.key.code == :home ? -typemax(Int) : event.key.code == :end ? typemax(Int) : nothing
    delta === nothing && return false
    _scroll_static_list!(state, delta, total, height)
    return true
end
handle!(state::PropertyListState, widget::PropertyList, event::KeyEvent; viewport_height::Integer=widget.height) = _handle_static_list!(state, length(widget.items), event, viewport_height)
function handle!(state::PropertyListState, widget::PropertyList, event::MouseEvent, area::Rect)
    event.action == MouseScroll && contains(area, event.position) || return false
    delta = event.button == WheelUpButton ? -3 : event.button == WheelDownButton ? 3 : 0
    delta == 0 && return false
    _scroll_static_list!(state, delta, length(widget.items), min(area.height, widget.height))
    return true
end

function SemanticToolkit.widget_semantic_descriptor(::PropertyList, state::PropertyListState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Properties",
        state=Accessibility.SemanticState(focusable=true),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:offset => state.row),
    )
end

function SemanticToolkit.widget_semantic_children(widget::PropertyList, ::PropertyListState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode("$(id)/$(index)", Accessibility.ListItemRole; label=item.label, description=item.value)
        for (index, item) in enumerate(widget.items)
    ]
end

struct DescriptionItem
    label::String
    description::String
end
DescriptionItem(label::AbstractString, description::AbstractString) = DescriptionItem(String(label), String(description))
DescriptionItem(item::Pair) = DescriptionItem(string(first(item)), string(last(item)))

"""A scrollable label-and-description list for explanatory metadata and help text."""
struct DescriptionList
    items::Vector{DescriptionItem}
    width::Int
    height::Int
    label_style::Style
    description_style::Style
end

function DescriptionList(items; width::Integer=80, height::Integer=24, label_style::Style=Style(modifiers=BOLD), description_style::Style=Style())
    width > 0 || throw(ArgumentError("description list width must be positive"))
    height >= 0 || throw(ArgumentError("description list height cannot be negative"))
    return DescriptionList(DescriptionItem[item isa DescriptionItem ? item : DescriptionItem(item) for item in items], Int(width), Int(height), label_style, description_style)
end

const DescriptionListState = ScrollState
state_for(::DescriptionList) = DescriptionListState()
measure(widget::DescriptionList, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::DescriptionList, area::Rect, state::DescriptionListState)
    active = intersection(buffer.area, _data_widget_area(widget, area))
    isempty(active) && return buffer
    _scroll_static_list!(state, 0, length(widget.items), active.height)
    for visible in 1:active.height
        index = state.row + visible
        index > length(widget.items) && break
        item = widget.items[index]
        row = active.row + visible - 1
        draw_text!(buffer, row, active.column, item.label; style=widget.label_style, clip=active)
        column = active.column + min(active.width, text_width(item.label) + 1)
        column < active.column + active.width && draw_text!(buffer, row, column, item.description; style=widget.description_style, clip=active)
    end
    return buffer
end
render!(buffer::Buffer, widget::DescriptionList, area::Rect) = render!(buffer, widget, area, state_for(widget))
handle!(state::DescriptionListState, widget::DescriptionList, event::KeyEvent; viewport_height::Integer=widget.height) = _handle_static_list!(state, length(widget.items), event, viewport_height)
function handle!(state::DescriptionListState, widget::DescriptionList, event::MouseEvent, area::Rect)
    event.action == MouseScroll && contains(area, event.position) || return false
    delta = event.button == WheelUpButton ? -3 : event.button == WheelDownButton ? 3 : 0
    delta == 0 && return false
    _scroll_static_list!(state, delta, length(widget.items), min(area.height, widget.height))
    return true
end

function SemanticToolkit.widget_semantic_descriptor(::DescriptionList, state::DescriptionListState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Descriptions",
        state=Accessibility.SemanticState(focusable=true),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:offset => state.row),
    )
end

function SemanticToolkit.widget_semantic_children(widget::DescriptionList, ::DescriptionListState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode("$(id)/$(index)", Accessibility.ListItemRole; label=item.label, description=item.description)
        for (index, item) in enumerate(widget.items)
    ]
end

"""An immediate-mode breadcrumb widget backed by shared `BreadcrumbState`."""
struct Breadcrumb{T}
    items::Vector{BreadcrumbItem{T}}
    separator::String
    width::Int
    height::Int
    style::Style
    focused_style::Style
end

function Breadcrumb(
    items::AbstractVector{BreadcrumbItem{T}};
    separator::AbstractString=" / ",
    width::Integer=80,
    height::Integer=1,
    style::Style=Style(),
    focused_style::Style=Style(modifiers=REVERSED),
) where {T}
    width > 0 || throw(ArgumentError("breadcrumb width must be positive"))
    height >= 0 || throw(ArgumentError("breadcrumb height cannot be negative"))
    return Breadcrumb{T}(Vector{BreadcrumbItem{T}}(items), String(separator), Int(width), Int(height), style, focused_style)
end

state_for(widget::Breadcrumb) = BreadcrumbState(widget.items)
measure(widget::Breadcrumb, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::Breadcrumb, area::Rect, state::BreadcrumbState)
    active = intersection(buffer.area, _data_widget_area(widget, area))
    isempty(active) && return buffer
    column = active.column
    for (index, item) in enumerate(state.items)
        index > 1 && begin
            position = draw_text!(buffer, active.row, column, widget.separator; style=widget.style, clip=active)
            column = position.column
        end
        style = index == state.focused ? widget.focused_style : widget.style
        label = item.disabled ? "($(item.label))" : item.label
        position = draw_text!(buffer, active.row, column, label; style, clip=active)
        column = position.column
        column >= active.column + active.width && break
    end
    return buffer
end
render!(buffer::Buffer, widget::Breadcrumb, area::Rect) = render!(buffer, widget, area, state_for(widget))

function handle!(state::BreadcrumbState, widget::Breadcrumb, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :left
        move_breadcrumb_focus!(state, -1)
    elseif event.key.code == :right
        move_breadcrumb_focus!(state, 1)
    elseif event.key.code == :home
        state.focused = findfirst(item -> !item.disabled, state.items)
    elseif event.key.code == :end
        state.focused = findlast(item -> !item.disabled, state.items)
    elseif event.key.code == :enter || (event.key.code == :character && event.text == " ")
        activate_breadcrumb!(state)
    else
        return false
    end
    return true
end

function handle!(state::BreadcrumbState, widget::Breadcrumb, event::MouseEvent, area::Rect)
    event.action == MousePress && event.button == LeftMouseButton || return false
    active = _data_widget_area(widget, area)
    contains(active, event.position) || return false
    column = active.column
    for (index, item) in enumerate(state.items)
        index > 1 && (column += text_width(widget.separator))
        width = text_width(item.disabled ? "($(item.label))" : item.label)
        if column <= event.position.column < column + width
            item.disabled && return false
            state.focused = index
            activate_breadcrumb!(state)
            return true
        end
        column += width
    end
    return false
end

function SemanticToolkit.widget_semantic_descriptor(::Breadcrumb, state::BreadcrumbState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Breadcrumbs",
        state=Accessibility.SemanticState(focusable=true),
        actions=[Accessibility.FocusSemanticAction],
        metadata=Dict(:focused_index => state.focused, :active_index => state.active),
    )
end

function SemanticToolkit.widget_semantic_children(widget::Breadcrumb, state::BreadcrumbState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(index)",
            Accessibility.ButtonRole;
            label=item.label,
            state=Accessibility.SemanticState(enabled=!item.disabled, selected=state.focused == index),
            actions=item.disabled ? Accessibility.SemanticAction[] : [Accessibility.ActivateSemanticAction],
            metadata=Dict(:value => item.value),
        ) for (index, item) in enumerate(widget.items)
    ]
end

"""An immediate-mode pagination control backed by shared `PaginationState`."""
struct Pagination
    total_items::Int
    page_size::Int
    initial_page::Int
    width::Int
    height::Int
    style::Style
end

function Pagination(total_items::Integer; page_size::Integer=20, page::Integer=1, width::Integer=40, height::Integer=1, style::Style=Style())
    total_items >= 0 || throw(ArgumentError("pagination total cannot be negative"))
    page_size > 0 || throw(ArgumentError("pagination page size must be positive"))
    width > 0 || throw(ArgumentError("pagination width must be positive"))
    height >= 0 || throw(ArgumentError("pagination height cannot be negative"))
    return Pagination(Int(total_items), Int(page_size), Int(page), Int(width), Int(height), style)
end

state_for(widget::Pagination) = PaginationState(widget.total_items; page_size=widget.page_size, page=widget.initial_page)
measure(widget::Pagination, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::Pagination, area::Rect, state::PaginationState)
    active = intersection(buffer.area, _data_widget_area(widget, area))
    isempty(active) && return buffer
    draw_text!(buffer, active.row, active.column, render_pagination(state); style=widget.style, clip=active)
    return buffer
end
render!(buffer::Buffer, widget::Pagination, area::Rect) = render!(buffer, widget, area, state_for(widget))

function handle!(state::PaginationState, ::Pagination, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code in (:left, :page_up, :pageup)
        previous_page!(state)
    elseif event.key.code in (:right, :page_down, :pagedown)
        next_page!(state)
    elseif event.key.code == :home
        set_page!(state, 1)
    elseif event.key.code == :end
        set_page!(state, page_count(state))
    else
        return false
    end
    return true
end

function handle!(state::PaginationState, widget::Pagination, event::MouseEvent, area::Rect)
    active = _data_widget_area(widget, area)
    contains(active, event.position) || return false
    if event.action == MouseScroll
        event.button == WheelUpButton ? previous_page!(state) : event.button == WheelDownButton ? next_page!(state) : return false
        return true
    end
    event.action == MousePress && event.button == LeftMouseButton || return false
    event.position.column < active.column + div(active.width, 2) ? previous_page!(state) : next_page!(state)
    return true
end

function SemanticToolkit.widget_semantic_descriptor(::Pagination, state::PaginationState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Pagination",
        state=Accessibility.SemanticState(
            focusable=true,
            value="$(state.page)/$(page_count(state))",
            value_now=state.page,
            value_min=1,
            value_max=max(1, page_count(state)),
        ),
        actions=[Accessibility.FocusSemanticAction, Accessibility.IncrementSemanticAction, Accessibility.DecrementSemanticAction, Accessibility.SetValueSemanticAction],
        metadata=Dict(:page_size => state.page_size, :total_items => state.total_items),
    )
end
