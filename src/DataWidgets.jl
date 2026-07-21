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
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(:column_count => length(widget.columns), :row_cursor => state.rows.cursor),
    )
end

function SemanticToolkit.widget_semantic_children(widget::DataGrid, state::DataGridState, id)
    return data_grid_semantic_tree(widget, state; id, label="Data grid").root.children
end

function _semantic_table_cursor_row(window::VirtualTableWindow, state::DataGridState)
    if state.rows.cursor === nothing
        return findfirst(row -> row.kind == ReadySlot && row.key !== nothing, window.rows)
    end
    return findfirst(row -> row.index == state.rows.cursor && row.kind == ReadySlot && row.key !== nothing, window.rows)
end

function _select_semantic_table_cursor!(state::DataGridState, window::VirtualTableWindow)
    row_index = _semantic_table_cursor_row(window, state)
    row_index === nothing && return nothing
    row = window.rows[row_index]
    key = row.key
    key === nothing && return nothing
    state.rows.multiple || empty!(state.rows.selected)
    push!(state.rows.selected, key)
    state.rows.cursor = row.index
    state.rows.anchor = row.index
    ensure_virtual_cursor_visible!(state.rows; total_length=window.total_length)
    return key
end

function _register_virtual_table_state_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::DataGridState,
    window_function,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        window = window_function()
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.rows.cursor)
        elseif request.action == Accessibility.ScrollIntoViewSemanticAction
            ensure_virtual_cursor_visible!(state.rows; total_length=window.total_length)
            return Accessibility.SemanticActionResult(true; value=state.rows.cursor)
        elseif request.action == Accessibility.IncrementSemanticAction
            move_virtual_cursor!(state.rows, 1; total_length=window.total_length)
            ensure_virtual_cursor_visible!(state.rows; total_length=window.total_length)
            return Accessibility.SemanticActionResult(true; value=state.rows.cursor)
        elseif request.action == Accessibility.DecrementSemanticAction
            move_virtual_cursor!(state.rows, -1; total_length=window.total_length)
            ensure_virtual_cursor_visible!(state.rows; total_length=window.total_length)
            return Accessibility.SemanticActionResult(true; value=state.rows.cursor)
        elseif request.action == Accessibility.SelectSemanticAction || request.action == Accessibility.ActivateSemanticAction
            key = _select_semantic_table_cursor!(state, window)
            key === nothing && return Accessibility.SemanticActionResult(false; message="virtual table cursor is not on a selectable row")
            return Accessibility.SemanticActionResult(true; value=key)
        end
        return Accessibility.SemanticActionResult(false; message="virtual table semantic action is not supported")
    end)
    return dispatcher
end

function register_data_grid_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataGrid,
    state::DataGridState,
)
    return _register_virtual_table_state_semantic_handlers!(
        dispatcher,
        id,
        state,
        () -> _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0))),
    )
end

function _semantic_table_row_id(id, row::VirtualTableRow)
    return string(id, "/", something(row.key, row.index))
end

function _semantic_table_row_item(widget::DataGrid, row::VirtualTableRow)
    items = fetch_items(widget.source, row.index:row.index)
    isempty(items) && return nothing
    return first(items)
end

function _semantic_selected_table_rows(widget::DataGrid, state::DataGridState, window::VirtualTableWindow)
    selected = state.rows.selected
    isempty(selected) && return NamedTuple[]
    rows = NamedTuple[]
    for row in window.rows
        row.kind == ReadySlot || continue
        row.key === nothing && continue
        row.key in selected || continue
        item = _semantic_table_row_item(widget, row)
        item === nothing && continue
        push!(rows, (item=item, index=row.index, key=row.key))
    end
    sort!(rows; by=row -> row.index)
    return rows
end

function VirtualAdvanced.virtual_selected_row_records(
    widget::DataGrid,
    state::DataGridState;
    include_unready::Bool=false,
)
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    return virtual_selected_row_records(state.rows, window; include_unready)
end

function VirtualAdvanced.virtual_selected_row_snapshot(
    widget::DataGrid,
    state::DataGridState;
    include_unready::Bool=false,
)
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    return virtual_selected_row_snapshot(state.rows, window; include_unready)
end

function VirtualAdvanced.virtual_range_selected_row_records(
    widget::DataGrid,
    state::DataGridState,
    selection::VirtualRangeSelection;
    include_unready::Bool=false,
)
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    return virtual_range_selected_row_records(selection, window; include_unready)
end

function VirtualAdvanced.virtual_range_selected_row_snapshot(
    widget::DataGrid,
    state::DataGridState,
    selection::VirtualRangeSelection;
    include_unready::Bool=false,
)
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    return virtual_range_selected_row_snapshot(selection, window; include_unready)
end

function _range_table_action_items(widget::DataGrid, selection::VirtualRangeSelection, window::VirtualTableWindow)
    records = virtual_range_selected_row_records(selection, window)
    items = Any[]
    indices = Int[]
    keys = Any[]
    for record in records
        fetched = fetch_items(widget.source, record.index:record.index)
        isempty(fetched) && continue
        push!(items, first(fetched))
        push!(indices, record.index)
        push!(keys, record.key)
    end
    return (items=items, indices=indices, keys=keys)
end

function VirtualAdvanced.invoke_virtual_range_row_action_batch(
    action::VirtualRowAction,
    widget::DataGrid,
    state::DataGridState,
    selection::VirtualRangeSelection,
)
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    rows = _range_table_action_items(widget, selection, window)
    return invoke_virtual_row_action_batch(action, rows.items; indices=rows.indices, keys=rows.keys)
end

function VirtualAdvanced.invoke_virtual_range_row_action_batch(
    actions::AbstractVector{<:VirtualRowAction},
    action_id,
    widget::DataGrid,
    state::DataGridState,
    selection::VirtualRangeSelection,
)
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    rows = _range_table_action_items(widget, selection, window)
    return invoke_virtual_row_action_batch(actions, action_id, rows.items; indices=rows.indices, keys=rows.keys)
end

function _register_virtual_row_action_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataGrid,
    state::DataGridState,
    actions::AbstractVector{<:VirtualRowAction};
    include_disabled::Bool=false,
)
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    for row in window.rows
        row.kind == ReadySlot || continue
        node_id = _semantic_table_row_id(id, row)
        item = _semantic_table_row_item(widget, row)
        item === nothing && continue
        row_actions = virtual_row_action_menu(actions, item, row.index; key=row.key, include_disabled)
        isempty(row_actions) && continue
        Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
            request.action == Accessibility.ActivateSemanticAction ||
                return Accessibility.SemanticActionResult(false; message="virtual row action semantic handler supports activation only")
            requested = request.value === nothing ? first(row_actions).id : Symbol(request.value)
            result = invoke_virtual_row_action(actions, requested, item, row.index; key=row.key)
            return Accessibility.SemanticActionResult(
                result.handled;
                message=result.handled ? nothing : "virtual row action is disabled",
                value=result,
            )
        end)
    end
    return dispatcher
end

function register_virtual_row_action_batch_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataGrid,
    state::DataGridState,
    actions::AbstractVector{<:VirtualRowAction};
    include_disabled::Bool=false,
)
    node_id = string(id, "/selection")
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        request.action == Accessibility.ActivateSemanticAction ||
            return Accessibility.SemanticActionResult(false; message="virtual row action batch semantic handler supports activation only")
        isempty(actions) &&
            return Accessibility.SemanticActionResult(false; message="no virtual row actions are registered")
        window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
        rows = _semantic_selected_table_rows(widget, state, window)
        isempty(rows) &&
            return Accessibility.SemanticActionResult(false; message="no selected virtual rows are available in the current window")
        requested = request.value === nothing ? first(actions).id : Symbol(request.value)
        result = invoke_virtual_row_action_batch(
            actions,
            requested,
            (row.item for row in rows);
            indices=(row.index for row in rows),
            keys=(row.key for row in rows),
        )
        return Accessibility.SemanticActionResult(
            result.handled > 0;
            message=result.handled > 0 ? nothing : "virtual row action is disabled for selected rows",
            value=result,
        )
    end)
    return dispatcher
end

function register_virtual_row_action_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataGrid,
    state::DataGridState,
    actions::AbstractVector{<:VirtualRowAction};
    include_disabled::Bool=false,
)
    return _register_virtual_row_action_semantic_handlers!(
        dispatcher,
        id,
        widget,
        state,
        actions;
        include_disabled,
    )
end

function _semantic_table_column_id(id, column) 
    return string(id, "/column/", Symbol(column))
end

function register_virtual_column_action_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    columns::AbstractVector{<:VirtualTableColumn},
    layout::TableLayoutState,
    actions::AbstractVector{<:VirtualColumnAction};
    visibility=nothing,
    pinning=nothing,
    include_disabled::Bool=false,
)
    for column in columns
        column_actions = virtual_column_action_menu(
            actions,
            column.id,
            layout;
            visibility=visibility,
            pinning=pinning,
            include_disabled,
        )
        isempty(column_actions) && continue
        Accessibility.register_semantic_handler!(
            dispatcher,
            _semantic_table_column_id(id, column.id),
            function (request)
                request.action == Accessibility.ActivateSemanticAction ||
                    return Accessibility.SemanticActionResult(false; message="virtual column action semantic handler supports activation only")
                requested = request.value === nothing ? first(column_actions).id : Symbol(request.value)
                result = invoke_virtual_column_action(
                    actions,
                    requested,
                    column.id,
                    layout;
                    visibility=visibility,
                    pinning=pinning,
                )
                return Accessibility.SemanticActionResult(
                    result.handled;
                    message=result.handled ? nothing : "virtual column action is disabled",
                    value=result,
                )
            end,
        )
    end
    return dispatcher
end

function register_virtual_cell_edit_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataGrid,
    state::DataGridState,
    edit::VirtualCellEditState;
    validator=nothing,
)
    window = _data_grid_window!(widget, state, max(0, widget.height - (widget.show_header ? 1 : 0)))
    for row in window.rows
        row.kind == ReadySlot || continue
        for cell in row.cells
            node_id = string(id, "/", row.index, "/", cell.column)
            Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
                if request.action == Accessibility.ActivateSemanticAction
                    begin_virtual_cell_edit!(edit, row.index, cell.column; key=row.key, value=cell.value)
                    return Accessibility.SemanticActionResult(true; value=virtual_cell_edit_snapshot(edit))
                elseif request.action == Accessibility.SetValueSemanticAction
                    edit.active || begin_virtual_cell_edit!(edit, row.index, cell.column; key=row.key, value=cell.value)
                    update_virtual_cell_edit!(edit, request.value; validator=validator)
                    return Accessibility.SemanticActionResult(edit.valid; message=edit.message, value=virtual_cell_edit_snapshot(edit))
                end
                return Accessibility.SemanticActionResult(false; message="virtual cell edit semantic handler supports activate and set-value only")
            end)
        end
    end
    return dispatcher
end

"""
Textual-style virtual data table backed by Wicked's stable `DataGrid` engine.

`DataTable` is a first-class compatibility widget name. It intentionally shares
`DataTableState` with `DataGridState` so applications do not need parallel
virtual-table state models when moving between grid and table terminology.
"""
struct DataTable{S,F}
    grid::DataGrid{S,F}
end

"""Compatibility state alias for `DataTable`; identical to `DataGridState`."""
const DataTableState = DataGridState

DataTable(source::AbstractDataSource, columns::AbstractVector{<:VirtualTableColumn}; kwargs...) =
    DataTable(DataGrid(source, columns; kwargs...))

DataTable(rows::AbstractVector, columns::AbstractVector{<:VirtualTableColumn}; kwargs...) =
    DataTable(VectorDataSource(rows), columns; kwargs...)

state_for(widget::DataTable) = state_for(widget.grid)
measure(widget::DataTable, available::Rect) = measure(widget.grid, available)

render!(buffer::Buffer, widget::DataTable, area::Rect) =
    render!(buffer, widget.grid, area)

render!(buffer::Buffer, widget::DataTable, area::Rect, state::DataTableState) =
    render!(buffer, widget.grid, area, state)

handle!(state::DataTableState, widget::DataTable, event::KeyEvent) =
    handle!(state, widget.grid, event)

handle!(state::DataTableState, widget::DataTable, event::MouseEvent, area::Rect) =
    handle!(state, widget.grid, event, area)

handle!(::DataTableState, ::DataTable, ::PasteEvent) = false

"""Return semantic inspection metadata for the current virtual `DataTable` window."""
function data_table_semantic_tree(widget::DataTable, state::DataTableState; id="data-table", label::AbstractString="Data table", origin_row::Integer=1, origin_column::Integer=1)
    return data_grid_semantic_tree(widget.grid, state; id, label, origin_row, origin_column)
end

function SemanticToolkit.widget_semantic_descriptor(widget::DataTable, state::DataTableState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TableRole;
        label="Data table",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(:column_count => length(widget.grid.columns), :row_cursor => state.rows.cursor),
    )
end

function SemanticToolkit.widget_semantic_children(widget::DataTable, state::DataTableState, id)
    return data_table_semantic_tree(widget, state; id, label="Data table").root.children
end

register_data_table_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataTable,
    state::DataTableState,
) = register_data_grid_semantic_handlers!(dispatcher, id, widget.grid, state)

VirtualAdvanced.virtual_selected_row_records(
    widget::DataTable,
    state::DataTableState;
    include_unready::Bool=false,
) = virtual_selected_row_records(widget.grid, state; include_unready)

VirtualAdvanced.virtual_selected_row_snapshot(
    widget::DataTable,
    state::DataTableState;
    include_unready::Bool=false,
) = virtual_selected_row_snapshot(widget.grid, state; include_unready)

VirtualAdvanced.virtual_range_selected_row_records(
    widget::DataTable,
    state::DataTableState,
    selection::VirtualRangeSelection;
    include_unready::Bool=false,
) = virtual_range_selected_row_records(widget.grid, state, selection; include_unready)

VirtualAdvanced.virtual_range_selected_row_snapshot(
    widget::DataTable,
    state::DataTableState,
    selection::VirtualRangeSelection;
    include_unready::Bool=false,
) = virtual_range_selected_row_snapshot(widget.grid, state, selection; include_unready)

VirtualAdvanced.invoke_virtual_range_row_action_batch(
    action::VirtualRowAction,
    widget::DataTable,
    state::DataTableState,
    selection::VirtualRangeSelection,
) = invoke_virtual_range_row_action_batch(action, widget.grid, state, selection)

VirtualAdvanced.invoke_virtual_range_row_action_batch(
    actions::AbstractVector{<:VirtualRowAction},
    action_id,
    widget::DataTable,
    state::DataTableState,
    selection::VirtualRangeSelection,
) = invoke_virtual_range_row_action_batch(actions, action_id, widget.grid, state, selection)

function register_virtual_row_action_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataTable,
    state::DataTableState,
    actions::AbstractVector{<:VirtualRowAction};
    include_disabled::Bool=false,
)
    return register_virtual_row_action_semantic_handlers!(
        dispatcher,
        id,
        widget.grid,
        state,
        actions;
        include_disabled,
    )
end

function register_virtual_row_action_batch_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataTable,
    state::DataTableState,
    actions::AbstractVector{<:VirtualRowAction};
    include_disabled::Bool=false,
)
    return register_virtual_row_action_batch_semantic_handlers!(
        dispatcher,
        id,
        widget.grid,
        state,
        actions;
        include_disabled,
    )
end

function register_virtual_cell_edit_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataTable,
    state::DataTableState,
    edit::VirtualCellEditState;
    validator=nothing,
)
    return register_virtual_cell_edit_semantic_handlers!(
        dispatcher,
        id,
        widget.grid,
        state,
        edit;
        validator=validator,
    )
end

"""
Source-backed virtual table widget backed by Wicked's stable `DataTable` engine.

`VirtualTable` is the explicit large-data table name that pairs with
`VirtualList` and `VirtualTree`. It intentionally shares `VirtualTableState`
with `DataTableState` so applications do not need parallel virtual-table state
models when moving between table vocabularies.
"""
struct VirtualTable{S,F}
    table::DataTable{S,F}
end

"""Compatibility state alias for `VirtualTable`; identical to `DataTableState`."""
const VirtualTableState = DataTableState

VirtualTable(source::AbstractDataSource, columns::AbstractVector{<:VirtualTableColumn}; kwargs...) =
    VirtualTable(DataTable(source, columns; kwargs...))

VirtualTable(rows::AbstractVector, columns::AbstractVector{<:VirtualTableColumn}; kwargs...) =
    VirtualTable(VectorDataSource(rows), columns; kwargs...)

state_for(widget::VirtualTable) = state_for(widget.table)
measure(widget::VirtualTable, available::Rect) = measure(widget.table, available)

render!(buffer::Buffer, widget::VirtualTable, area::Rect) =
    render!(buffer, widget.table, area)

render!(buffer::Buffer, widget::VirtualTable, area::Rect, state::VirtualTableState) =
    render!(buffer, widget.table, area, state)

handle!(state::VirtualTableState, widget::VirtualTable, event::KeyEvent) =
    handle!(state, widget.table, event)

handle!(state::VirtualTableState, widget::VirtualTable, event::MouseEvent, area::Rect) =
    handle!(state, widget.table, event, area)

handle!(::VirtualTableState, ::VirtualTable, ::PasteEvent) = false

"""Return semantic inspection metadata for the current virtual `VirtualTable` window."""
function VirtualRendering.virtual_table_semantic_tree(
    widget::VirtualTable,
    state::VirtualTableState;
    id="virtual-table",
    label::AbstractString="Virtual table",
    origin_row::Integer=1,
    origin_column::Integer=1
)
    return data_table_semantic_tree(widget.table, state; id, label, origin_row, origin_column)
end

function SemanticToolkit.widget_semantic_descriptor(widget::VirtualTable, state::VirtualTableState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TableRole;
        label="Virtual table",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(:column_count => length(widget.table.grid.columns), :row_cursor => state.rows.cursor),
    )
end

function SemanticToolkit.widget_semantic_children(widget::VirtualTable, state::VirtualTableState, id)
    return virtual_table_semantic_tree(widget, state; id, label="Virtual table").root.children
end

register_virtual_table_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::VirtualTable,
    state::VirtualTableState,
) = register_data_table_semantic_handlers!(dispatcher, id, widget.table, state)

VirtualAdvanced.virtual_selected_row_records(
    widget::VirtualTable,
    state::VirtualTableState;
    include_unready::Bool=false,
) = virtual_selected_row_records(widget.table, state; include_unready)

VirtualAdvanced.virtual_selected_row_snapshot(
    widget::VirtualTable,
    state::VirtualTableState;
    include_unready::Bool=false,
) = virtual_selected_row_snapshot(widget.table, state; include_unready)

VirtualAdvanced.virtual_range_selected_row_records(
    widget::VirtualTable,
    state::VirtualTableState,
    selection::VirtualRangeSelection;
    include_unready::Bool=false,
) = virtual_range_selected_row_records(widget.table, state, selection; include_unready)

VirtualAdvanced.virtual_range_selected_row_snapshot(
    widget::VirtualTable,
    state::VirtualTableState,
    selection::VirtualRangeSelection;
    include_unready::Bool=false,
) = virtual_range_selected_row_snapshot(widget.table, state, selection; include_unready)

VirtualAdvanced.invoke_virtual_range_row_action_batch(
    action::VirtualRowAction,
    widget::VirtualTable,
    state::VirtualTableState,
    selection::VirtualRangeSelection,
) = invoke_virtual_range_row_action_batch(action, widget.table, state, selection)

VirtualAdvanced.invoke_virtual_range_row_action_batch(
    actions::AbstractVector{<:VirtualRowAction},
    action_id,
    widget::VirtualTable,
    state::VirtualTableState,
    selection::VirtualRangeSelection,
) = invoke_virtual_range_row_action_batch(actions, action_id, widget.table, state, selection)

function register_virtual_row_action_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::VirtualTable,
    state::VirtualTableState,
    actions::AbstractVector{<:VirtualRowAction};
    include_disabled::Bool=false,
)
    return register_virtual_row_action_semantic_handlers!(
        dispatcher,
        id,
        widget.table,
        state,
        actions;
        include_disabled,
    )
end

function register_virtual_row_action_batch_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::VirtualTable,
    state::VirtualTableState,
    actions::AbstractVector{<:VirtualRowAction};
    include_disabled::Bool=false,
)
    return register_virtual_row_action_batch_semantic_handlers!(
        dispatcher,
        id,
        widget.table,
        state,
        actions;
        include_disabled,
    )
end

function register_virtual_cell_edit_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::VirtualTable,
    state::VirtualTableState,
    edit::VirtualCellEditState;
    validator=nothing,
)
    return register_virtual_cell_edit_semantic_handlers!(
        dispatcher,
        id,
        widget.table,
        state,
        edit;
        validator=validator,
    )
end

"""
Source-backed virtual list widget for large, paged, or frequently changing data.

`VirtualList` exposes the lower-level virtual data primitives as a normal Wicked
widget. It reuses `VirtualListState`, `VirtualListFormat`, virtual keyboard
bindings, pointer routing, and semantic tree generation.
"""
struct VirtualList{S,F}
    source::S
    format::F
    width::Int
    height::Int
    multiple::Bool
    bindings::VirtualBindings
    pointer_options::VirtualPointerOptions
    cursor_style::Style
    selected_style::Style
    loading_style::Style
    error_style::Style
end

function VirtualList(
    source::AbstractDataSource;
    format::VirtualListFormat=VirtualListFormat(),
    width::Integer=80,
    height::Integer=24,
    multiple::Bool=false,
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
    cursor_style::Style=Style(modifiers=REVERSED),
    selected_style::Style=Style(modifiers=BOLD),
    loading_style::Style=Style(modifiers=DIM),
    error_style::Style=Style(modifiers=BOLD),
)
    width > 0 || throw(ArgumentError("virtual list width must be positive"))
    height >= 0 || throw(ArgumentError("virtual list height cannot be negative"))
    return VirtualList(
        source,
        format,
        Int(width),
        Int(height),
        multiple,
        bindings,
        pointer_options,
        cursor_style,
        selected_style,
        loading_style,
        error_style,
    )
end

function VirtualList(items::AbstractVector; key=(item, index) -> index, kwargs...)
    return VirtualList(VectorDataSource(items; key); kwargs...)
end

function state_for(widget::VirtualList{S}) where {T,K,S<:AbstractDataSource{T,K}}
    return VirtualListState{K}(viewport_size=widget.height, multiple=widget.multiple)
end

measure(widget::VirtualList, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function _virtual_list_window!(widget::VirtualList, state::VirtualListState, content_height::Integer)
    resize_virtual_list!(state, max(0, Int(content_height)))
    return refresh_virtual_list!(widget.source, state)
end

function _virtual_list_style(widget::VirtualList, role::Symbol)
    role == :virtual_item_cursor && return widget.cursor_style
    role == :virtual_item_selected && return widget.selected_style
    role == :virtual_loading && return widget.loading_style
    role == :virtual_error && return widget.error_style
    return Style()
end

render!(buffer::Buffer, widget::VirtualList, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(buffer::Buffer, widget::VirtualList, area::Rect, state::VirtualListState)
    active = intersection(buffer.area, _data_widget_area(widget, area))
    isempty(active) && return buffer
    window = _virtual_list_window!(widget, state, active.height)
    lines = render_virtual_list(window, state; width=active.width, format=widget.format)
    for (offset, line) in enumerate(lines)
        offset > active.height && break
        row = active.row + offset - 1
        draw_text!(buffer, row, active.column, plain_text(line); style=_virtual_list_style(widget, line.role), clip=active)
    end
    return buffer
end

function handle!(state::VirtualListState, widget::VirtualList, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    window = _virtual_list_window!(widget, state, widget.height)
    result = handle_virtual_key!(state, window, widget.bindings, event.key.code;
        control=in(CTRL, event.modifiers), alt=in(ALT, event.modifiers), shift=in(SHIFT, event.modifiers))
    return result.consumed
end

function handle!(state::VirtualListState, widget::VirtualList, event::MouseEvent, area::Rect)
    active = _data_widget_area(widget, area)
    contains(active, event.position) || return false
    window = _virtual_list_window!(widget, state, active.height)
    if event.action == MouseScroll
        delta = event.button == WheelUpButton ? -3 : event.button == WheelDownButton ? 3 : 0
        delta == 0 && return false
        scroll_virtual_list!(state, delta; total_length=window.total_length)
        return true
    end
    event.action in (MousePress, MouseRelease, MouseMove) || return false
    kind = event.action == MouseMove ? VirtualPointerHover : event.click_count > 1 ? VirtualPointerDoublePress : VirtualPointerPress
    result = handle_virtual_pointer!(state, window,
        VirtualPointerEvent(kind, event.position.row - active.row + 1, event.position.column - active.column + 1;
            control=in(CTRL, event.modifiers), shift=in(SHIFT, event.modifiers));
        options=widget.pointer_options)
    return result.consumed
end

handle!(::VirtualListState, ::VirtualList, ::PasteEvent) = false

"""Return semantic inspection metadata for the current virtual list window."""
function VirtualRendering.virtual_list_semantic_tree(
    widget::VirtualList,
    state::VirtualListState;
    id="virtual-list",
    label::AbstractString="Virtual list",
    origin_row::Integer=1,
    origin_column::Integer=1,
)
    window = _virtual_list_window!(widget, state, widget.height)
    return VirtualRendering.virtual_list_semantic_tree(window, state; id, label, origin_row, origin_column)
end

function SemanticToolkit.widget_semantic_descriptor(widget::VirtualList, state::VirtualListState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Virtual list",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(:row_cursor => state.cursor, :selected_count => length(state.selected)),
    )
end

function SemanticToolkit.widget_semantic_children(widget::VirtualList, state::VirtualListState, id)
    return virtual_list_semantic_tree(widget, state; id, label="Virtual list").root.children
end

function _semantic_virtual_list_slot(window::VirtualListWindow, state::VirtualListState)
    if state.cursor === nothing
        return findfirst(slot -> slot.kind == ReadySlot, window.slots)
    end
    return findfirst(slot -> slot.index == state.cursor && slot.kind == ReadySlot, window.slots)
end

function _select_semantic_virtual_list_cursor!(state::VirtualListState, window::VirtualListWindow)
    slot_index = _semantic_virtual_list_slot(window, state)
    slot_index === nothing && return nothing
    slot = window.slots[slot_index]
    select_virtual_index!(state, slot) || return nothing
    ensure_virtual_cursor_visible!(state; total_length=window.total_length)
    return slot.key
end

function register_virtual_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::VirtualList,
    state::VirtualListState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        window = _virtual_list_window!(widget, state, widget.height)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.cursor)
        elseif request.action == Accessibility.ScrollIntoViewSemanticAction
            ensure_virtual_cursor_visible!(state; total_length=window.total_length)
            return Accessibility.SemanticActionResult(true; value=state.cursor)
        elseif request.action == Accessibility.IncrementSemanticAction
            move_virtual_cursor!(state, 1; total_length=window.total_length)
            ensure_virtual_cursor_visible!(state; total_length=window.total_length)
            return Accessibility.SemanticActionResult(true; value=state.cursor)
        elseif request.action == Accessibility.DecrementSemanticAction
            move_virtual_cursor!(state, -1; total_length=window.total_length)
            ensure_virtual_cursor_visible!(state; total_length=window.total_length)
            return Accessibility.SemanticActionResult(true; value=state.cursor)
        elseif request.action == Accessibility.SelectSemanticAction || request.action == Accessibility.ActivateSemanticAction
            key = _select_semantic_virtual_list_cursor!(state, window)
            key === nothing && return Accessibility.SemanticActionResult(false; message="virtual list cursor is not on a selectable row")
            return Accessibility.SemanticActionResult(true; value=key)
        end
        return Accessibility.SemanticActionResult(false; message="virtual list semantic action is not supported")
    end)
    return dispatcher
end

"""
Source-backed virtual tree widget for large or lazily flattened hierarchies.

`VirtualTree` exposes the lower-level virtual tree primitives as a normal Wicked
widget. It reuses `VirtualTreeState`, `VirtualTreeFormat`, virtual keyboard
bindings, pointer routing, and semantic tree generation.
"""
struct VirtualTree{S,F}
    source::S
    format::F
    width::Int
    height::Int
    multiple::Bool
    bindings::VirtualBindings
    pointer_options::VirtualPointerOptions
    cursor_style::Style
    selected_style::Style
    max_rows::Int
    max_depth::Int
end

function VirtualTree(
    source::AbstractTreeDataSource;
    format::VirtualTreeFormat=VirtualTreeFormat(),
    width::Integer=80,
    height::Integer=24,
    multiple::Bool=false,
    bindings::VirtualBindings=default_virtual_bindings(),
    pointer_options::VirtualPointerOptions=VirtualPointerOptions(),
    cursor_style::Style=Style(modifiers=REVERSED),
    selected_style::Style=Style(modifiers=BOLD),
    max_rows::Integer=100_000,
    max_depth::Integer=256,
)
    width > 0 || throw(ArgumentError("virtual tree width must be positive"))
    height >= 0 || throw(ArgumentError("virtual tree height cannot be negative"))
    max_rows > 0 || throw(ArgumentError("virtual tree maximum rows must be positive"))
    max_depth >= 0 || throw(ArgumentError("virtual tree maximum depth cannot be negative"))
    return VirtualTree(
        source,
        format,
        Int(width),
        Int(height),
        multiple,
        bindings,
        pointer_options,
        cursor_style,
        selected_style,
        Int(max_rows),
        Int(max_depth),
    )
end

function state_for(widget::VirtualTree{S}) where {T,K,S<:AbstractTreeDataSource{T,K}}
    return VirtualTreeState{K}(multiple=widget.multiple)
end

measure(widget::VirtualTree, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function _virtual_tree_window(widget::VirtualTree, state::VirtualTreeState)
    return flatten_virtual_tree(widget.source, state; max_rows=widget.max_rows, max_depth=widget.max_depth)
end

function _virtual_tree_first_row(widget::VirtualTree, state::VirtualTreeState, window::VirtualTreeWindow, height::Integer)
    isempty(window.rows) && return 1
    height = max(0, Int(height))
    height == 0 && return 1
    index = state.cursor === nothing ? 1 : something(findfirst(row -> row.key == state.cursor, window.rows), 1)
    return clamp(index - height + 1, 1, max(1, length(window.rows) - height + 1))
end

function _virtual_tree_style(widget::VirtualTree, role::Symbol)
    role == :virtual_tree_cursor && return widget.cursor_style
    role == :virtual_tree_selected && return widget.selected_style
    return Style()
end

render!(buffer::Buffer, widget::VirtualTree, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function render!(buffer::Buffer, widget::VirtualTree, area::Rect, state::VirtualTreeState)
    active = intersection(buffer.area, _data_widget_area(widget, area))
    isempty(active) && return buffer
    window = _virtual_tree_window(widget, state)
    first_row = _virtual_tree_first_row(widget, state, window, active.height)
    lines = render_virtual_tree(window, state; first_row, height=active.height, width=active.width, format=widget.format)
    for (offset, line) in enumerate(lines)
        offset > active.height && break
        row = active.row + offset - 1
        draw_text!(buffer, row, active.column, plain_text(line); style=_virtual_tree_style(widget, line.role), clip=active)
    end
    return buffer
end

function handle!(state::VirtualTreeState, widget::VirtualTree, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    window = _virtual_tree_window(widget, state)
    result = handle_virtual_key!(state, window, widget.bindings, event.key.code;
        control=in(CTRL, event.modifiers), alt=in(ALT, event.modifiers), shift=in(SHIFT, event.modifiers),
        page_size=max(1, widget.height))
    return result.consumed
end

function handle!(state::VirtualTreeState, widget::VirtualTree, event::MouseEvent, area::Rect)
    active = _data_widget_area(widget, area)
    contains(active, event.position) || return false
    window = _virtual_tree_window(widget, state)
    if event.action == MouseScroll
        delta = event.button == WheelUpButton ? -3 : event.button == WheelDownButton ? 3 : 0
        delta == 0 && return false
        move_virtual_tree_cursor!(state, window, delta)
        return true
    end
    event.action in (MousePress, MouseRelease, MouseMove) || return false
    first_row = _virtual_tree_first_row(widget, state, window, active.height)
    kind = event.action == MouseMove ? VirtualPointerHover : event.click_count > 1 ? VirtualPointerDoublePress : VirtualPointerPress
    result = handle_virtual_pointer!(state, window,
        VirtualPointerEvent(kind, event.position.row - active.row + 1, event.position.column - active.column + 1;
            control=in(CTRL, event.modifiers), shift=in(SHIFT, event.modifiers));
        options=widget.pointer_options, first_row)
    return result.consumed
end

handle!(::VirtualTreeState, ::VirtualTree, ::PasteEvent) = false

"""Return semantic inspection metadata for the current virtual tree window."""
function VirtualRendering.virtual_tree_semantic_tree(
    widget::VirtualTree,
    state::VirtualTreeState;
    id="virtual-tree",
    label::AbstractString="Virtual tree",
    origin_row::Integer=1,
    origin_column::Integer=1,
)
    return VirtualRendering.virtual_tree_semantic_tree(
        _virtual_tree_window(widget, state),
        state;
        id,
        label,
        origin_row,
        origin_column,
        width=widget.width,
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::VirtualTree, state::VirtualTreeState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TreeRole;
        label="Virtual tree",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
            Accessibility.ExpandSemanticAction,
            Accessibility.CollapseSemanticAction,
        ],
        metadata=Dict(:row_cursor => state.cursor, :selected_count => length(state.selected)),
    )
end

function SemanticToolkit.widget_semantic_children(widget::VirtualTree, state::VirtualTreeState, id)
    return VirtualRendering.virtual_tree_semantic_tree(widget, state; id, label="Virtual tree").root.children
end

function _semantic_tree_row(window::VirtualTreeWindow, key)
    index = findfirst(row -> row.key == key, window.rows)
    return index === nothing ? nothing : window.rows[index]
end

function _semantic_tree_cursor_row(window::VirtualTreeWindow, state::VirtualTreeState)
    state.cursor === nothing && return isempty(window.rows) ? nothing : first(window.rows)
    return _semantic_tree_row(window, state.cursor)
end

function _perform_semantic_tree_row_action!(state::VirtualTreeState, row, action)
    row === nothing && return Accessibility.SemanticActionResult(false; message="virtual tree row is not available")
    if action == Accessibility.SelectSemanticAction || action == Accessibility.ActivateSemanticAction
        select_virtual_tree!(state, row.key)
        return Accessibility.SemanticActionResult(true; value=row.key)
    elseif action == Accessibility.ExpandSemanticAction
        row.expandable || return Accessibility.SemanticActionResult(false; message="virtual tree row is not expandable")
        expand_virtual_tree!(state, row.key)
        return Accessibility.SemanticActionResult(true; value=row.key)
    elseif action == Accessibility.CollapseSemanticAction
        row.expandable || return Accessibility.SemanticActionResult(false; message="virtual tree row is not collapsible")
        collapse_virtual_tree!(state, row.key)
        return Accessibility.SemanticActionResult(true; value=row.key)
    end
    return Accessibility.SemanticActionResult(false; message="virtual tree row semantic action is not supported")
end

function register_virtual_tree_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::VirtualTree,
    state::VirtualTreeState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        window = _virtual_tree_window(widget, state)
        if request.action == Accessibility.FocusSemanticAction || request.action == Accessibility.ScrollIntoViewSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.cursor)
        elseif request.action == Accessibility.IncrementSemanticAction
            move_virtual_tree_cursor!(state, window, 1)
            return Accessibility.SemanticActionResult(true; value=state.cursor)
        elseif request.action == Accessibility.DecrementSemanticAction
            move_virtual_tree_cursor!(state, window, -1)
            return Accessibility.SemanticActionResult(true; value=state.cursor)
        elseif request.action in (
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
            Accessibility.ExpandSemanticAction,
            Accessibility.CollapseSemanticAction,
        )
            return _perform_semantic_tree_row_action!(state, _semantic_tree_cursor_row(window, state), request.action)
        end
        return Accessibility.SemanticActionResult(false; message="virtual tree semantic action is not supported")
    end)
    for registered_row in _virtual_tree_window(widget, state).rows
        key = registered_row.key
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/$(key)", function (request)
            row = _semantic_tree_row(_virtual_tree_window(widget, state), key)
            return _perform_semantic_tree_row_action!(state, row, request.action)
        end)
    end
    return dispatcher
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
    return VirtualRendering.virtual_tree_semantic_tree(_tree_table_window(widget, state), state.tree; id, label, width=widget.width)
end

function SemanticToolkit.widget_semantic_descriptor(widget::TreeTable, state::TreeTableState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TreeRole;
        label="Tree table",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
            Accessibility.ExpandSemanticAction,
            Accessibility.CollapseSemanticAction,
        ],
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

function register_tree_table_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::TreeTable,
    state::TreeTableState,
)
    node_id = string(id)
    content_height = max(0, widget.height - (widget.show_header ? 1 : 0))
    window_function = function ()
        window = _tree_table_window(widget, state)
        _normalize_tree_table!(state, window, content_height)
        return window
    end
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        window = window_function()
        if request.action == Accessibility.FocusSemanticAction || request.action == Accessibility.ScrollIntoViewSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.tree.cursor)
        elseif request.action == Accessibility.IncrementSemanticAction
            move_virtual_tree_cursor!(state.tree, window, 1)
            _normalize_tree_table!(state, _tree_table_window(widget, state), content_height)
            return Accessibility.SemanticActionResult(true; value=state.tree.cursor)
        elseif request.action == Accessibility.DecrementSemanticAction
            move_virtual_tree_cursor!(state.tree, window, -1)
            _normalize_tree_table!(state, _tree_table_window(widget, state), content_height)
            return Accessibility.SemanticActionResult(true; value=state.tree.cursor)
        elseif request.action in (
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
            Accessibility.ExpandSemanticAction,
            Accessibility.CollapseSemanticAction,
        )
            result = _perform_semantic_tree_row_action!(state.tree, _semantic_tree_cursor_row(window, state.tree), request.action)
            _normalize_tree_table!(state, _tree_table_window(widget, state), content_height)
            return result
        end
        return Accessibility.SemanticActionResult(false; message="tree table semantic action is not supported")
    end)
    for registered_row in window_function().rows
        key = registered_row.key
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/$(key)", function (request)
            result = _perform_semantic_tree_row_action!(state.tree, _semantic_tree_row(window_function(), key), request.action)
            _normalize_tree_table!(state, _tree_table_window(widget, state), content_height)
            return result
        end)
    end
    return dispatcher
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

function PropertyList(body::Vararg{Any}; kwargs...)
    length(body) == 0 && throw(ArgumentError("PropertyList requires an items argument"))
    length(body) > 1 && throw(ArgumentError("PropertyList accepts exactly one positional argument"))
    return _property_list(body[1]; kwargs...)
end

_property_list(
    items;
    width::Integer=80,
    height::Integer=24,
    separator::AbstractString=": ",
    label_style::Style=Style(modifiers=BOLD),
    value_style::Style=Style(),
) = _property_list(PropertyList(PropertyItem[item isa PropertyItem ? item : PropertyItem(item) for item in items], Int(width), Int(height), String(separator), label_style, value_style))

_property_list(items::PropertyList) = items

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
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.row),
    )
end

function SemanticToolkit.widget_semantic_children(widget::PropertyList, ::PropertyListState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode("$(id)/$(index)", Accessibility.ListItemRole; label=item.label, description=item.value)
        for (index, item) in enumerate(widget.items)
    ]
end

function _static_list_semantic_value(label::AbstractString, state::ScrollState, total::Integer, height::Integer)
    return Dict{Symbol,Any}(
        :label => String(label),
        :offset => state.row,
        :item_count => Int(total),
        :viewport_height => Int(height),
    )
end

function _set_static_list_offset!(state::ScrollState, value, total::Integer, height::Integer)
    offset = tryparse(Int, string(value))
    offset === nothing && return false
    state.row = clamp(offset, 0, max(0, Int(total) - max(0, Int(height))))
    return true
end

function _register_static_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::ScrollState;
    label::AbstractString,
    total::Integer,
    height::Integer,
    unsupported::AbstractString,
)
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=_static_list_semantic_value(label, state, total, height))
        elseif request.action == Accessibility.ScrollIntoViewSemanticAction || request.action == Accessibility.SetValueSemanticAction
            handled = _set_static_list_offset!(state, request.value, total, height)
            return Accessibility.SemanticActionResult(
                handled;
                value=_static_list_semantic_value(label, state, total, height),
                message=handled ? nothing : "list semantic value must be an integer offset",
            )
        elseif request.action == Accessibility.IncrementSemanticAction
            _scroll_static_list!(state, 1, total, height)
            return Accessibility.SemanticActionResult(true; value=_static_list_semantic_value(label, state, total, height))
        elseif request.action == Accessibility.DecrementSemanticAction
            _scroll_static_list!(state, -1, total, height)
            return Accessibility.SemanticActionResult(true; value=_static_list_semantic_value(label, state, total, height))
        end
        return Accessibility.SemanticActionResult(false; message=unsupported)
    end)
    return dispatcher
end

register_property_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::PropertyList,
    state::PropertyListState,
) =
    _register_static_list_semantic_handlers!(
        dispatcher,
        id,
        state;
        label="Properties",
        total=length(widget.items),
        height=widget.height,
        unsupported="property list semantic action is not supported",
    )

"""
    KeyValueList(items; width=80, height=24, separator=": ", key_style=Style(modifiers=BOLD), value_style=Style())

Scrollable key/value metadata list backed by `PropertyList`.

`KeyValueList` gives applications a direct API name for configuration,
environment, and record-inspection panes while reusing the same scroll state,
rendering, pointer, keyboard, and semantic behavior as `PropertyList`.
"""
struct KeyValueList
    properties::PropertyList
end

KeyValueList(items::AbstractVector; kwargs...) = _key_value_list(items; kwargs...)
KeyValueList(items::Tuple; kwargs...) = _key_value_list(items; kwargs...)

function KeyValueList(body::Vararg{Any}; kwargs...)
    length(body) == 0 && throw(ArgumentError("KeyValueList requires an items argument"))
    length(body) > 1 && throw(ArgumentError("KeyValueList accepts exactly one positional argument"))
    return _key_value_list(body[1]; kwargs...)
end

_key_value_list(
    items;
    width::Integer=80,
    height::Integer=24,
    separator::AbstractString=": ",
    key_style::Style=Style(modifiers=BOLD),
    value_style::Style=Style(),
) = _key_value_list(PropertyList(
    items;
    width,
    height,
    separator,
    label_style=key_style,
    value_style,
))

_key_value_list(properties::PropertyList) = KeyValueList(properties)

const KeyValueListState = PropertyListState

state_for(::KeyValueList) = KeyValueListState()
measure(widget::KeyValueList, available::Rect) = measure(widget.properties, available)

render!(buffer::Buffer, widget::KeyValueList, area::Rect, state::KeyValueListState) =
    render!(buffer, widget.properties, area, state)

render!(buffer::Buffer, widget::KeyValueList, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(
    state::KeyValueListState,
    widget::KeyValueList,
    event::KeyEvent;
    viewport_height::Integer=widget.properties.height,
) =
    handle!(state, widget.properties, event; viewport_height)

handle!(state::KeyValueListState, widget::KeyValueList, event::MouseEvent, area::Rect) =
    handle!(state, widget.properties, event, area)

function SemanticToolkit.widget_semantic_descriptor(::KeyValueList, state::KeyValueListState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Key values",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.row),
    )
end

function SemanticToolkit.widget_semantic_children(widget::KeyValueList, ::KeyValueListState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode("$(id)/$(index)", Accessibility.ListItemRole; label=item.label, description=item.value)
        for (index, item) in enumerate(widget.properties.items)
    ]
end

register_key_value_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::KeyValueList,
    state::KeyValueListState,
) =
    _register_static_list_semantic_handlers!(
        dispatcher,
        id,
        state;
        label="Key values",
        total=length(widget.properties.items),
        height=widget.properties.height,
        unsupported="key/value list semantic action is not supported",
    )

"""
    MetadataList(items; width=80, height=24, separator=": ", key_style=Style(modifiers=BOLD), value_style=Style())

Scrollable read-only metadata panel backed by `KeyValueList`.

`MetadataList` is intended for application, resource, and diagnostics metadata
where a key/value presentation is the developer-facing concept. It preserves the
same state and interaction behavior as `KeyValueList`.
"""
struct MetadataList
    key_values::KeyValueList
end

MetadataList(items::AbstractVector; kwargs...) = _metadata_list(items; kwargs...)
MetadataList(items::Tuple; kwargs...) = _metadata_list(items; kwargs...)

function MetadataList(body::Vararg{Any}; kwargs...)
    length(body) == 0 && throw(ArgumentError("MetadataList requires an items argument"))
    length(body) > 1 && throw(ArgumentError("MetadataList accepts exactly one positional argument"))
    return _metadata_list(body[1]; kwargs...)
end

_metadata_list(
    items;
    width::Integer=80,
    height::Integer=24,
    separator::AbstractString=": ",
    key_style::Style=Style(modifiers=BOLD),
    value_style::Style=Style(),
) = _metadata_list(KeyValueList(
    items;
    width,
    height,
    separator,
    key_style,
    value_style,
))

_metadata_list(key_values::KeyValueList) = MetadataList(key_values)

const MetadataListState = KeyValueListState

state_for(::MetadataList) = MetadataListState()
measure(widget::MetadataList, available::Rect) = measure(widget.key_values, available)

render!(buffer::Buffer, widget::MetadataList, area::Rect, state::MetadataListState) =
    render!(buffer, widget.key_values, area, state)

render!(buffer::Buffer, widget::MetadataList, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(
    state::MetadataListState,
    widget::MetadataList,
    event::KeyEvent;
    viewport_height::Integer=widget.key_values.properties.height,
) =
    handle!(state, widget.key_values, event; viewport_height)

handle!(state::MetadataListState, widget::MetadataList, event::MouseEvent, area::Rect) =
    handle!(state, widget.key_values, event, area)

function SemanticToolkit.widget_semantic_descriptor(::MetadataList, state::MetadataListState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Metadata",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.row),
    )
end

function SemanticToolkit.widget_semantic_children(widget::MetadataList, ::MetadataListState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode("$(id)/$(index)", Accessibility.ListItemRole; label=item.label, description=item.value)
        for (index, item) in enumerate(widget.key_values.properties.items)
    ]
end

register_metadata_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::MetadataList,
    state::MetadataListState,
) =
    _register_static_list_semantic_handlers!(
        dispatcher,
        id,
        state;
        label="Metadata",
        total=length(widget.key_values.properties.items),
        height=widget.key_values.properties.height,
        unsupported="metadata list semantic action is not supported",
    )

@enum DataViewStatus::UInt8 begin
    DataReady
    DataLoading
    DataEmpty
    DataError
end

"""
    DataStateView(content; status=DataReady, loading="Loading data...", empty="No data", error="Data failed to load")

Status wrapper for data-display widgets.

`DataStateView` keeps a table, list, tree, or metadata widget in one stable
screen position while the application switches between ready, loading, empty,
and error states. In `DataReady` it delegates rendering and input handling to
the wrapped content. In all other states it renders deterministic status text
and exposes semantic status metadata.
"""
struct DataStateView{C}
    content::C
    status::DataViewStatus
    loading::String
    empty::String
    error::String
    style::Style
    loading_style::Style
    empty_style::Style
    error_style::Style
end

function DataStateView(
    content;
    status::DataViewStatus=DataReady,
    loading::AbstractString="Loading data...",
    empty::AbstractString="No data",
    error::AbstractString="Data failed to load",
    style::Style=Style(),
    loading_style::Style=Style(modifiers=DIM),
    empty_style::Style=Style(modifiers=DIM),
    error_style::Style=Style(modifiers=BOLD),
)
    return DataStateView(
        content,
        status,
        String(loading),
        String(empty),
        String(error),
        style,
        loading_style,
        empty_style,
        error_style,
    )
end

data_state_status(widget::DataStateView) = widget.status
data_state_ready(widget::DataStateView) = widget.status == DataReady
data_state_loading(widget::DataStateView) = widget.status == DataLoading
data_state_empty(widget::DataStateView) = widget.status == DataEmpty
data_state_error(widget::DataStateView) = widget.status == DataError
state_for(widget::DataStateView) = state_for(widget.content)

function _data_state_text(widget::DataStateView)
    widget.status == DataLoading && return widget.loading
    widget.status == DataEmpty && return widget.empty
    widget.status == DataError && return widget.error
    return ""
end

function _data_state_style(widget::DataStateView)
    widget.status == DataLoading && return widget.loading_style
    widget.status == DataEmpty && return widget.empty_style
    widget.status == DataError && return widget.error_style
    return widget.style
end

function measure(widget::DataStateView, available::Rect)
    widget.status == DataReady && return measure(widget.content, available)
    return Size(min(available.height, 1), min(available.width, text_width(_data_state_text(widget))))
end

function render!(buffer::Buffer, widget::DataStateView, area::Rect)
    widget.status == DataReady && return render!(buffer, widget.content, area)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    draw_text!(
        buffer,
        active.row,
        active.column,
        _data_state_text(widget);
        style=_data_state_style(widget),
        clip=active,
    )
    return buffer
end

function render!(buffer::Buffer, widget::DataStateView, area::Rect, state)
    widget.status == DataReady && return render!(buffer, widget.content, area, state)
    return render!(buffer, widget, area)
end

function handle!(state, widget::DataStateView, event::KeyEvent; kwargs...)
    widget.status == DataReady || return false
    return handle!(state, widget.content, event; kwargs...)
end

function handle!(state, widget::DataStateView, event::MouseEvent, area::Rect)
    widget.status == DataReady || return false
    return handle!(state, widget.content, event, area)
end

_data_state_semantic_value(widget::DataStateView) = Dict{Symbol,Any}(
    :status => Symbol(string(widget.status)),
    :ready => data_state_ready(widget),
    :loading => data_state_loading(widget),
    :empty => data_state_empty(widget),
    :error => data_state_error(widget),
    :message => _data_state_text(widget),
)

function SemanticToolkit.widget_semantic_descriptor(widget::DataStateView, state)
    status_text = _data_state_text(widget)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.StatusRole;
        label=isempty(status_text) ? "Data ready" : status_text,
        state=Accessibility.SemanticState(
            readonly=true,
            busy=data_state_loading(widget),
            invalid=data_state_error(widget),
            value=string(widget.status),
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
        ],
        metadata=_data_state_semantic_value(widget),
    )
end

register_data_state_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DataStateView,
) = begin
    Accessibility.register_semantic_handler!(dispatcher, string(id), function (request)
        if request.action == Accessibility.FocusSemanticAction ||
           request.action == Accessibility.ScrollIntoViewSemanticAction
            return Accessibility.SemanticActionResult(true; value=_data_state_semantic_value(widget))
        end
        return Accessibility.SemanticActionResult(false; message="data state view semantic action is not supported")
    end)
    return dispatcher
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

Base.length(descriptions::DescriptionList) = length(descriptions.items)
Base.iterate(descriptions::DescriptionList) = iterate(descriptions.items)
Base.iterate(descriptions::DescriptionList, state) = iterate(descriptions.items, state)
Base.getindex(descriptions::DescriptionList, index::Int) = descriptions.items[index]

function DescriptionList(body::Vararg{Any}; kwargs...)
    length(body) == 0 && throw(ArgumentError("DescriptionList requires an items argument"))
    length(body) > 1 && throw(ArgumentError("DescriptionList accepts exactly one positional argument"))
    return _description_list(body[1]; kwargs...)
end

_description_list(
    items::DescriptionList;
    width::Integer=80,
    height::Integer=24,
    label_style::Style=Style(modifiers=BOLD),
    description_style::Style=Style(),
) = DescriptionList(
    items.items,
    Int(width),
    Int(height),
    label_style,
    description_style,
)

_description_list(
    items;
    width::Integer=80,
    height::Integer=24,
    label_style::Style=Style(modifiers=BOLD),
    description_style::Style=Style(),
) = _description_list(DescriptionList(
    DescriptionItem[item isa DescriptionItem ? item : DescriptionItem(item) for item in items],
    Int(width),
    Int(height),
    label_style,
    description_style,
))

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
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.row),
    )
end

function SemanticToolkit.widget_semantic_children(widget::DescriptionList, ::DescriptionListState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode("$(id)/$(index)", Accessibility.ListItemRole; label=item.label, description=item.description)
        for (index, item) in enumerate(widget.items)
    ]
end

register_description_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DescriptionList,
    state::DescriptionListState,
) =
    _register_static_list_semantic_handlers!(
        dispatcher,
        id,
        state;
        label="Descriptions",
        total=length(widget.items),
        height=widget.height,
        unsupported="description list semantic action is not supported",
    )

"""
    DefinitionList(items; width=80, height=24, term_style=Style(modifiers=BOLD), definition_style=Style())

Scrollable term-and-definition list backed by `DescriptionList`.

`DefinitionList` provides a documentation-oriented API name for glossary,
metadata, and help panes while preserving the same scroll state, rendering, and
semantic behavior as `DescriptionList`.
"""
struct DefinitionList
    descriptions::DescriptionList
end

DefinitionList(items::AbstractVector; kwargs...) = _definition_list(items; kwargs...)
DefinitionList(items::Tuple; kwargs...) = _definition_list(items; kwargs...)

function DefinitionList(body::Vararg{Any}; kwargs...)
    length(body) == 0 && throw(ArgumentError("DefinitionList requires an items argument"))
    length(body) > 1 && throw(ArgumentError("DefinitionList accepts exactly one positional argument"))
    return _definition_list(body[1]; kwargs...)
end

_definition_list(
    items::DescriptionList;
    width::Integer=80,
    height::Integer=24,
    term_style::Style=Style(modifiers=BOLD),
    definition_style::Style=Style(),
) = DefinitionList(
    DescriptionList(
        items.items,
        Int(width),
        Int(height),
        term_style,
        definition_style,
    ),
)

_definition_list(
    items;
    width::Integer=80,
    height::Integer=24,
    term_style::Style=Style(modifiers=BOLD),
    definition_style::Style=Style(),
) = _definition_list(DescriptionList(
    items;
    width,
    height,
    label_style=term_style,
    description_style=definition_style,
))

_definition_list(items::DefinitionList) = items

const DefinitionListState = DescriptionListState

state_for(::DefinitionList) = DefinitionListState()
measure(widget::DefinitionList, available::Rect) = measure(widget.descriptions, available)

render!(buffer::Buffer, widget::DefinitionList, area::Rect, state::DefinitionListState) =
    render!(buffer, widget.descriptions, area, state)

render!(buffer::Buffer, widget::DefinitionList, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(
    state::DefinitionListState,
    widget::DefinitionList,
    event::KeyEvent;
    viewport_height::Integer=widget.descriptions.height,
) =
    handle!(state, widget.descriptions, event; viewport_height)

handle!(state::DefinitionListState, widget::DefinitionList, event::MouseEvent, area::Rect) =
    handle!(state, widget.descriptions, event, area)

function SemanticToolkit.widget_semantic_descriptor(::DefinitionList, state::DefinitionListState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Definitions",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.row),
    )
end

function SemanticToolkit.widget_semantic_children(widget::DefinitionList, ::DefinitionListState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode("$(id)/$(index)", Accessibility.ListItemRole; label=item.label, description=item.description)
        for (index, item) in enumerate(widget.descriptions.items)
    ]
end

register_definition_list_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::DefinitionList,
    state::DefinitionListState,
) =
    _register_static_list_semantic_handlers!(
        dispatcher,
        id,
        state;
        label="Definitions",
        total=length(widget.descriptions.items),
        height=widget.descriptions.height,
        unsupported="definition list semantic action is not supported",
    )

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

function _screen_stack_breadcrumb_label(screen::Toolkit.Screen, registry)
    if registry === nothing || !Toolkit.has_registered_screen(registry, screen.id)
        return string(screen.id)
    end
    return Toolkit.screen_route_title(registry, screen.id)
end

function screen_stack_breadcrumb_items(stack::Toolkit.ScreenStack; registry=nothing)
    return BreadcrumbItem{Any}[
        BreadcrumbItem{Any}(
            _screen_stack_breadcrumb_label(screen, registry),
            screen.id,
            registry !== nothing && Toolkit.has_registered_screen(registry, screen.id) &&
                !Toolkit.screen_route_enabled(registry, screen.id),
        )
        for screen in stack.screens
    ]
end

function screen_stack_breadcrumb(stack::Toolkit.ScreenStack; registry=nothing, kwargs...)
    return Breadcrumb(screen_stack_breadcrumb_items(stack; registry=registry); kwargs...)
end

function screen_stack_breadcrumb_session(stack::Toolkit.ScreenStack; registry=nothing, kwargs...)
    breadcrumb = screen_stack_breadcrumb(stack; registry=registry, kwargs...)
    return (breadcrumb=breadcrumb, state=state_for(breadcrumb))
end

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

function selected_breadcrumb_item(widget::Breadcrumb, state::BreadcrumbState)
    index = state.focused
    index isa Integer || return nothing
    index in eachindex(widget.items) || return nothing
    item = widget.items[index]
    return item.disabled ? nothing : item
end

function selected_breadcrumb_value(widget::Breadcrumb, state::BreadcrumbState)
    item = selected_breadcrumb_item(widget, state)
    return item === nothing ? nothing : item.value
end

function select_breadcrumb_item!(state::BreadcrumbState, widget::Breadcrumb, index::Integer)
    target = Int(index)
    target in eachindex(widget.items) ||
        throw(ArgumentError("breadcrumb item index must be within widget item bounds"))
    widget.items[target].disabled || (state.focused = target)
    return state
end

select_next_breadcrumb_item!(state::BreadcrumbState, widget::Breadcrumb) =
    move_breadcrumb_focus!(state, 1)

select_previous_breadcrumb_item!(state::BreadcrumbState, widget::Breadcrumb) =
    move_breadcrumb_focus!(state, -1)

function activate_selected_breadcrumb!(state::BreadcrumbState, widget::Breadcrumb)
    item = selected_breadcrumb_item(widget, state)
    item === nothing && return nothing
    state.active = state.focused
    return item.value
end

function handle!(state::BreadcrumbState, widget::Breadcrumb, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :left
        select_previous_breadcrumb_item!(state, widget)
    elseif event.key.code == :right
        select_next_breadcrumb_item!(state, widget)
    elseif event.key.code == :home
        state.focused = findfirst(item -> !item.disabled, state.items)
    elseif event.key.code == :end
        state.focused = findlast(item -> !item.disabled, state.items)
    elseif event.key.code == :enter || (event.key.code == :character && event.text == " ")
        activate_selected_breadcrumb!(state, widget)
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
            select_breadcrumb_item!(state, widget, index)
            activate_selected_breadcrumb!(state, widget)
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
            actions=item.disabled ? Accessibility.SemanticAction[] : [
                Accessibility.FocusSemanticAction,
                Accessibility.SelectSemanticAction,
                Accessibility.ActivateSemanticAction,
            ],
            metadata=Dict(:value => item.value),
        ) for (index, item) in enumerate(widget.items)
    ]
end

function register_breadcrumb_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Breadcrumb,
    state::BreadcrumbState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=selected_breadcrumb_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="breadcrumb semantic action is not supported")
    end)
    for (registered_index, item) in enumerate(widget.items)
        value = item.value
        Accessibility.register_semantic_handler!(dispatcher, "$(node_id)/$(registered_index)", function (request)
            index = findfirst(candidate -> candidate.value == value, widget.items)
            index === nothing && return Accessibility.SemanticActionResult(false; message="breadcrumb item is not available")
            widget.items[index].disabled && return Accessibility.SemanticActionResult(false; message="breadcrumb item is disabled")
            if request.action == Accessibility.FocusSemanticAction || request.action == Accessibility.SelectSemanticAction
                select_breadcrumb_item!(state, widget, index)
                return Accessibility.SemanticActionResult(true; value)
            elseif request.action == Accessibility.ActivateSemanticAction
                select_breadcrumb_item!(state, widget, index)
                return Accessibility.SemanticActionResult(true; value=activate_selected_breadcrumb!(state, widget))
            end
            return Accessibility.SemanticActionResult(false; message="breadcrumb item semantic action is not supported")
        end)
    end
    return dispatcher
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

function _semantic_page_value(value)
    value isa Integer && return Int(value)
    value isa AbstractString && return parse(Int, value)
    return parse(Int, string(value))
end

function register_pagination_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::PaginationState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.page)
        elseif request.action == Accessibility.IncrementSemanticAction
            next_page!(state)
            return Accessibility.SemanticActionResult(true; value=state.page)
        elseif request.action == Accessibility.DecrementSemanticAction
            previous_page!(state)
            return Accessibility.SemanticActionResult(true; value=state.page)
        elseif request.action == Accessibility.SetValueSemanticAction
            try
                set_page!(state, _semantic_page_value(request.value))
                return Accessibility.SemanticActionResult(true; value=state.page)
            catch
                return Accessibility.SemanticActionResult(false; message="pagination value must be an integer page")
            end
        end
        return Accessibility.SemanticActionResult(false; message="pagination semantic action is not supported")
    end)
    return dispatcher
end
