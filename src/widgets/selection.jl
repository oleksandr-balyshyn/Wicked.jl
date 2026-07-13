"""One styled item in a selection list."""
struct ListItem
    line::Line
    style::Style
end

ListItem(content::AbstractString; style::Style=Style()) =
    ListItem(Line(content; style), style)
ListItem(line::Line; style::Style=Style()) = ListItem(line, style)

_selection_key_event(event::KeyEvent) = event.kind in (KeyPress, KeyRepeat)
_selection_mouse_event(event::MouseEvent) =
    event.action == MouseRelease && event.button == LeftMouseButton

"""Externally owned selection and viewport state for `List`."""
mutable struct ListState
    selected::Union{Nothing,Int}
    offset::Int

    function ListState(; selected::Union{Nothing,Integer}=nothing, offset::Integer=0)
        !isnothing(selected) && selected < 1 &&
            throw(ArgumentError("selected list index must be positive"))
        offset >= 0 || throw(ArgumentError("list offset must be non-negative"))
        new(isnothing(selected) ? nothing : Int(selected), Int(offset))
    end
end

"""A scrollable list with explicit external selection state."""
struct List
    items::Vector{ListItem}
    block::Union{Nothing,Block}
    highlight_style::Style
    highlight_symbol::String
end

state_for(::List) = ListState()

function List(
    items;
    block::Union{Nothing,Block}=nothing,
    highlight_style::Style=Style(modifiers=REVERSED),
    highlight_symbol::AbstractString="› ",
)
    resolved = ListItem[
        item isa ListItem ? item :
        item isa Line ? ListItem(item) : ListItem(string(item))
        for item in items
    ]
    List(resolved, block, highlight_style, String(highlight_symbol))
end

function _list_area(buffer::Buffer, widget::List, area::Rect)
    if isnothing(widget.block)
        intersection(buffer.area, area)
    else
        render!(buffer, widget.block, area)
        intersection(buffer.area, inner(widget.block, area))
    end
end

function _normalize!(state::ListState, count::Int, visible::Int)
    if count == 0
        state.selected = nothing
        state.offset = 0
        return
    end
    !isnothing(state.selected) && (state.selected = clamp(state.selected, 1, count))
    maximum_offset = max(0, count - visible)
    state.offset = clamp(state.offset, 0, maximum_offset)
    if !isnothing(state.selected) && visible > 0
        state.selected <= state.offset && (state.offset = state.selected - 1)
        state.selected > state.offset + visible && (state.offset = state.selected - visible)
    end
end

function _fill_row!(buffer::Buffer, row::Int, area::Rect, style::Style)
    for column in area.column:(area.column + area.width - 1)
        buffer[row, column] = Cell(; style)
    end
end

function render!(buffer::Buffer, widget::List, area::Rect, state::ListState)
    active = _list_area(buffer, widget, area)
    isempty(active) && return buffer
    _normalize!(state, length(widget.items), active.height)
    symbol_width = text_width(widget.highlight_symbol)
    for visible_index in 1:active.height
        item_index = state.offset + visible_index
        item_index > length(widget.items) && break
        row = active.row + visible_index - 1
        selected = state.selected == item_index
        selected && _fill_row!(buffer, row, active, widget.highlight_style)
        column = active.column
        if selected && symbol_width <= active.width
            position = draw_text!(
                buffer,
                row,
                column,
                widget.highlight_symbol;
                style=widget.highlight_style,
                clip=active,
            )
            column = position.column
        elseif symbol_width <= active.width
            column += symbol_width
        end
        text_area = Rect(row, column, 1, max(0, active.column + active.width - column))
        line = widget.items[item_index].line
        draw_line!(buffer, row, text_area, line)
    end
    buffer
end

render!(buffer::Buffer, widget::List, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::ListState, widget::List, event::KeyEvent; viewport_height::Integer=1)
    _selection_key_event(event) || return false
    count = length(widget.items)
    count == 0 && return false
    if event.key.code == :up
        state.selected = isnothing(state.selected) ? count : max(1, state.selected - 1)
    elseif event.key.code == :down
        state.selected = isnothing(state.selected) ? 1 : min(count, state.selected + 1)
    elseif event.key.code == :home
        state.selected = 1
    elseif event.key.code == :end
        state.selected = count
    elseif event.key.code == :page_up
        selected = something(state.selected, 1)
        state.selected = max(1, selected - max(1, Int(viewport_height)))
    elseif event.key.code == :page_down
        selected = something(state.selected, 0)
        state.selected = min(count, selected + max(1, Int(viewport_height)))
    else
        return false
    end
    _normalize!(state, count, max(1, Int(viewport_height)))
    true
end

function handle!(state::ListState, widget::List, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) && contains(area, event.position) || return false
    index = state.offset + event.position.row - area.row + 1
    1 <= index <= length(widget.items) || return false
    state.selected = index
    true
end

"""
    ListView(items; block=nothing, highlight_style=Style(modifiers=REVERSED), highlight_symbol="› ")

Textual-style list view backed by `List` and `ListState`.

`ListView` is a stable compatibility surface for applications that use retained
TUI vocabulary while still keeping Wicked's immediate render contract and
externally owned selection state.
"""
struct ListView
    list::List
end

"""Compatibility state alias for `ListView`; identical to `ListState`."""
const ListViewState = ListState

ListView(items::AbstractVector; kwargs...) = ListView(List(items; kwargs...))

state_for(::ListView) = ListViewState()

render!(buffer::Buffer, widget::ListView, area::Rect, state::ListViewState) =
    render!(buffer, widget.list, area, state)

render!(buffer::Buffer, widget::ListView, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::ListViewState, widget::ListView, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.list, event; viewport_height)

handle!(state::ListViewState, widget::ListView, event::MouseEvent, area::Rect) =
    handle!(state, widget.list, event, area)

"""
    OptionList(items; block=nothing, highlight_style=Style(modifiers=REVERSED), highlight_symbol="› ")

Textual-style option list backed by `List` and `ListState`.

`OptionList` is a stable compatibility surface for selectable option lists. It
shares `OptionListState` with `ListState` so keyboard navigation, pointer
selection, viewport scrolling, and semantic children stay identical to `List`.
"""
struct OptionList
    list::List
end

"""Compatibility state alias for `OptionList`; identical to `ListState`."""
const OptionListState = ListState

OptionList(items::AbstractVector; kwargs...) = OptionList(List(items; kwargs...))

state_for(::OptionList) = OptionListState()

render!(buffer::Buffer, widget::OptionList, area::Rect, state::OptionListState) =
    render!(buffer, widget.list, area, state)

render!(buffer::Buffer, widget::OptionList, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::OptionListState, widget::OptionList, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.list, event; viewport_height)

handle!(state::OptionListState, widget::OptionList, event::MouseEvent, area::Rect) =
    handle!(state, widget.list, event, area)

"""A column definition for a data table."""
struct TableColumn
    title::Line
    constraint::Constraint
end

TableColumn(title::AbstractString; constraint::Constraint=Fill(1), style::Style=Style()) =
    TableColumn(Line(title; style), constraint)

"""One styled row in a data table."""
struct TableRow
    cells::Vector{Line}
    style::Style
end

function TableRow(cells; style::Style=Style())
    resolved = Line[
        cell isa Line ? cell : Line(string(cell); style)
        for cell in cells
    ]
    TableRow(resolved, style)
end

"""Externally owned row, column, and viewport state for `Table`."""
mutable struct TableState
    selected_row::Union{Nothing,Int}
    selected_column::Union{Nothing,Int}
    row_offset::Int

    function TableState(;
        selected_row::Union{Nothing,Integer}=nothing,
        selected_column::Union{Nothing,Integer}=nothing,
        row_offset::Integer=0,
    )
        !isnothing(selected_row) && selected_row < 1 &&
            throw(ArgumentError("selected table row must be positive"))
        !isnothing(selected_column) && selected_column < 1 &&
            throw(ArgumentError("selected table column must be positive"))
        row_offset >= 0 || throw(ArgumentError("table offset must be non-negative"))
        new(
            isnothing(selected_row) ? nothing : Int(selected_row),
            isnothing(selected_column) ? nothing : Int(selected_column),
            Int(row_offset),
        )
    end
end

"""A selectable table with constraint-sized columns and virtual viewport state."""
struct Table
    columns::Vector{TableColumn}
    rows::Vector{TableRow}
    block::Union{Nothing,Block}
    header_style::Style
    highlight_style::Style
    column_gap::Int
    show_header::Bool
end

state_for(::Table) = TableState()

function Table(
    columns,
    rows;
    block::Union{Nothing,Block}=nothing,
    header_style::Style=Style(modifiers=BOLD),
    highlight_style::Style=Style(modifiers=REVERSED),
    column_gap::Integer=1,
    show_header::Bool=true,
)
    column_gap >= 0 || throw(ArgumentError("table column gap must be non-negative"))
    resolved_columns = TableColumn[
        column isa TableColumn ? column : TableColumn(string(column))
        for column in columns
    ]
    resolved_rows = TableRow[row isa TableRow ? row : TableRow(row) for row in rows]
    Table(
        resolved_columns,
        resolved_rows,
        block,
        header_style,
        highlight_style,
        Int(column_gap),
        show_header,
    )
end

function _table_area(buffer::Buffer, widget::Table, area::Rect)
    if isnothing(widget.block)
        intersection(buffer.area, area)
    else
        render!(buffer, widget.block, area)
        intersection(buffer.area, inner(widget.block, area))
    end
end

function _normalize!(state::TableState, row_count::Int, column_count::Int, visible_rows::Int)
    if row_count == 0
        state.selected_row = nothing
        state.row_offset = 0
    elseif !isnothing(state.selected_row)
        state.selected_row = clamp(state.selected_row, 1, row_count)
    end
    column_count == 0 ? (state.selected_column = nothing) :
        !isnothing(state.selected_column) &&
            (state.selected_column = clamp(state.selected_column, 1, column_count))
    state.row_offset = clamp(state.row_offset, 0, max(0, row_count - visible_rows))
    if !isnothing(state.selected_row) && visible_rows > 0
        state.selected_row <= state.row_offset && (state.row_offset = state.selected_row - 1)
        state.selected_row > state.row_offset + visible_rows &&
            (state.row_offset = state.selected_row - visible_rows)
    end
end

function _styled_line(line::Line, style::Style)
    Line([Span(span.content; style=apply(span.style, StylePatch(
        foreground=style.foreground,
        background=style.background,
        add_modifiers=style.modifiers,
    ))) for span in line.spans]; alignment=line.alignment)
end

function render!(buffer::Buffer, widget::Table, area::Rect, state::TableState)
    active = _table_area(buffer, widget, area)
    isempty(active) && return buffer
    header_height = widget.show_header && !isempty(widget.columns) ? 1 : 0
    visible_rows = max(0, active.height - header_height)
    _normalize!(state, length(widget.rows), length(widget.columns), visible_rows)
    column_areas = resolve(
        FlexLayout(
            HorizontalLayout,
            Constraint[column.constraint for column in widget.columns];
            gap=widget.column_gap,
        ),
        active,
    )
    if header_height == 1
        for (column, column_area) in zip(widget.columns, column_areas)
            header_area = Rect(active.row, column_area.column, 1, column_area.width)
            draw_line!(buffer, active.row, header_area, _styled_line(column.title, widget.header_style))
        end
    end
    for visible_index in 1:visible_rows
        row_index = state.row_offset + visible_index
        row_index > length(widget.rows) && break
        target_row = active.row + header_height + visible_index - 1
        selected = state.selected_row == row_index
        selected && _fill_row!(buffer, target_row, Rect(target_row, active.column, 1, active.width), widget.highlight_style)
        table_row = widget.rows[row_index]
        for (column_index, column_area) in enumerate(column_areas)
            column_index > length(table_row.cells) && break
            cell_area = Rect(target_row, column_area.column, 1, column_area.width)
            line = selected ? _styled_line(table_row.cells[column_index], widget.highlight_style) :
                   table_row.cells[column_index]
            draw_line!(buffer, target_row, cell_area, line)
        end
    end
    buffer
end

render!(buffer::Buffer, widget::Table, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::TableState, widget::Table, event::KeyEvent; viewport_height::Integer=1)
    _selection_key_event(event) || return false
    rows = length(widget.rows)
    columns = length(widget.columns)
    rows == 0 && columns == 0 && return false
    if event.key.code == :up && rows > 0
        state.selected_row = isnothing(state.selected_row) ? rows : max(1, state.selected_row - 1)
    elseif event.key.code == :down && rows > 0
        state.selected_row = isnothing(state.selected_row) ? 1 : min(rows, state.selected_row + 1)
    elseif event.key.code == :left && columns > 0
        state.selected_column = isnothing(state.selected_column) ? columns :
            max(1, state.selected_column - 1)
    elseif event.key.code == :right && columns > 0
        state.selected_column = isnothing(state.selected_column) ? 1 :
            min(columns, state.selected_column + 1)
    elseif event.key.code == :home && rows > 0
        state.selected_row = 1
    elseif event.key.code == :end && rows > 0
        state.selected_row = rows
    elseif event.key.code == :page_up && rows > 0
        row = something(state.selected_row, 1)
        state.selected_row = max(1, row - max(1, Int(viewport_height)))
    elseif event.key.code == :page_down && rows > 0
        row = something(state.selected_row, 0)
        state.selected_row = min(rows, row + max(1, Int(viewport_height)))
    else
        return false
    end
    _normalize!(state, rows, columns, max(1, Int(viewport_height)))
    true
end

function handle!(state::TableState, widget::Table, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) || return false
    active = isnothing(widget.block) ? area : inner(widget.block, area)
    contains(active, event.position) || return false
    header = widget.show_header ? 1 : 0
    relative_row = event.position.row - active.row - header
    relative_row >= 0 || return false
    row = state.row_offset + relative_row + 1
    1 <= row <= length(widget.rows) || return false
    state.selected_row = row
    column_areas = resolve(
        FlexLayout(
            HorizontalLayout,
            Constraint[column.constraint for column in widget.columns];
            gap=widget.column_gap,
        ),
        active,
    )
    state.selected_column = findfirst(region -> contains(region, event.position), column_areas)
    true
end

struct Tab{T}
    id::T
    title::Line
end

Tab(id, title::AbstractString; style::Style=Style()) = Tab(id, Line(title; style))

mutable struct TabsState
    selected::Int
    function TabsState(selected::Integer=1)
        selected >= 1 || throw(ArgumentError("selected tab must be positive"))
        new(Int(selected))
    end
end

"""A horizontal tab bar with explicit selected-tab state."""
struct Tabs
    tabs::Vector{Tab}
    divider::String
    style::Style
    selected_style::Style
end

state_for(::Tabs) = TabsState()

function Tabs(
    tabs;
    divider::AbstractString=" │ ",
    style::Style=Style(),
    selected_style::Style=Style(modifiers=REVERSED | BOLD),
)
    resolved = Tab[
        tab isa Tab ? tab : Tab(first(tab), last(tab))
        for tab in tabs
    ]
    Tabs(resolved, String(divider), style, selected_style)
end

function render!(buffer::Buffer, widget::Tabs, area::Rect, state::TabsState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    isempty(widget.tabs) && return buffer
    state.selected = clamp(state.selected, 1, length(widget.tabs))
    column = active.column
    for (index, tab) in enumerate(widget.tabs)
        index > 1 && begin
            position = draw_text!(buffer, active.row, column, widget.divider; style=widget.style, clip=active)
            column = position.column
        end
        column >= active.column + active.width && break
        line = index == state.selected ? _styled_line(tab.title, widget.selected_style) : tab.title
        tab_area = Rect(active.row, column, 1, active.column + active.width - column)
        position = draw_line!(buffer, active.row, tab_area, line)
        column = position.column
    end
    buffer
end

render!(buffer::Buffer, widget::Tabs, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

"""Return the selected tab, or `nothing` when the tab set is empty."""
function selected_tab(widget::Tabs, state::TabsState)
    isempty(widget.tabs) && return nothing
    index = clamp(state.selected, 1, length(widget.tabs))
    widget.tabs[index]
end

"""Select a tab by absolute tab index."""
function select_tab!(state::TabsState, widget::Tabs, index::Integer)
    isempty(widget.tabs) && return state
    state.selected = clamp(Int(index), 1, length(widget.tabs))
    state
end

"""Select the next tab, wrapping at the end."""
function select_next_tab!(state::TabsState, widget::Tabs)
    isempty(widget.tabs) && return state
    state.selected = mod1(state.selected + 1, length(widget.tabs))
    state
end

"""Select the previous tab, wrapping at the beginning."""
function select_previous_tab!(state::TabsState, widget::Tabs)
    isempty(widget.tabs) && return state
    state.selected = mod1(state.selected - 1, length(widget.tabs))
    state
end

function handle!(state::TabsState, widget::Tabs, event::KeyEvent; page_size::Integer=4)
    _selection_key_event(event) || return false
    isempty(widget.tabs) && return false
    step = max(1, Int(page_size))
    if event.key.code in (:left, :backtab)
        select_previous_tab!(state, widget)
    elseif event.key.code in (:right, :tab)
        select_next_tab!(state, widget)
    elseif event.key.code == :home
        select_tab!(state, widget, 1)
    elseif event.key.code == :end
        select_tab!(state, widget, length(widget.tabs))
    elseif event.key.code == :page_up
        select_tab!(state, widget, state.selected - step)
    elseif event.key.code == :page_down
        select_tab!(state, widget, state.selected + step)
    elseif event.key.code in (:enter, :character) &&
           (event.key.code == :enter || event.text == " ")
        select_tab!(state, widget, state.selected)
    else
        return false
    end
    true
end

function handle!(state::TabsState, widget::Tabs, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) && contains(area, event.position) || return false
    event.position.row == area.row || return false
    column = area.column
    for (index, tab) in enumerate(widget.tabs)
        if index > 1
            divider_width = text_width(widget.divider)
            column <= event.position.column < column + divider_width && return false
            column += divider_width
        end
        width = sum(span -> text_width(span.content), tab.title.spans; init=0)
        if column <= event.position.column < min(column + width, area.column + area.width)
            select_tab!(state, widget, index)
            return true
        end
        column += width
        column >= area.column + area.width && break
    end
    return false
end

"""A convenience tree node with stable identity, display label, and child nodes."""
struct TreeNode
    id::Any
    label::Line
    data::Any
    children::Vector{TreeNode}
end

function TreeNode(
    id,
    label::Union{AbstractString,Line};
    data=nothing,
    children=TreeNode[],
    style::Style=Style(),
)
    resolved_label = label isa Line ? label : Line(label; style)
    TreeNode(id, resolved_label, data, TreeNode[children...])
end

"""Externally owned expansion, selection, and viewport state for `Tree`."""
mutable struct TreeState
    expanded::Set{Any}
    selected::Any
    offset::Int

    function TreeState(; expanded=Any[], selected=nothing, offset::Integer=0)
        offset >= 0 || throw(ArgumentError("tree offset must be non-negative"))
        new(Set{Any}(expanded), selected, Int(offset))
    end
end

"""A selectable and expandable tree with model/view separation through `TreeNode#data`."""
struct Tree
    roots::Vector{TreeNode}
    block::Union{Nothing,Block}
    highlight_style::Style
    indent::Int
    expanded_symbol::String
    collapsed_symbol::String
    leaf_symbol::String
end

state_for(::Tree) = TreeState()

function Tree(
    roots;
    block::Union{Nothing,Block}=nothing,
    highlight_style::Style=Style(modifiers=REVERSED),
    indent::Integer=2,
    expanded_symbol::AbstractString="▾ ",
    collapsed_symbol::AbstractString="▸ ",
    leaf_symbol::AbstractString="  ",
)
    indent >= 0 || throw(ArgumentError("tree indent must be non-negative"))
    Tree(
        TreeNode[roots...],
        block,
        highlight_style,
        Int(indent),
        String(expanded_symbol),
        String(collapsed_symbol),
        String(leaf_symbol),
    )
end

struct VisibleTreeNode
    node::TreeNode
    depth::Int
    parent::Any
end

function _append_visible!(
    output::Vector{VisibleTreeNode},
    nodes::Vector{TreeNode},
    state::TreeState,
    depth::Int,
    parent,
)
    for node in nodes
        push!(output, VisibleTreeNode(node, depth, parent))
        node.id in state.expanded &&
            _append_visible!(output, node.children, state, depth + 1, node.id)
    end
    output
end

function _visible_nodes(widget::Tree, state::TreeState)
    _append_visible!(VisibleTreeNode[], widget.roots, state, 0, nothing)
end

function _tree_area(buffer::Buffer, widget::Tree, area::Rect)
    if isnothing(widget.block)
        intersection(buffer.area, area)
    else
        render!(buffer, widget.block, area)
        intersection(buffer.area, inner(widget.block, area))
    end
end

function _normalize!(state::TreeState, visible::Vector{VisibleTreeNode}, height::Int)
    if isempty(visible)
        state.selected = nothing
        state.offset = 0
        return
    end
    selected_index = findfirst(item -> item.node.id == state.selected, visible)
    if isnothing(selected_index)
        state.selected = visible[1].node.id
        selected_index = 1
    end
    state.offset = clamp(state.offset, 0, max(0, length(visible) - height))
    selected_index <= state.offset && (state.offset = selected_index - 1)
    selected_index > state.offset + height && (state.offset = selected_index - height)
end

function render!(buffer::Buffer, widget::Tree, area::Rect, state::TreeState)
    active = _tree_area(buffer, widget, area)
    isempty(active) && return buffer
    visible = _visible_nodes(widget, state)
    _normalize!(state, visible, active.height)
    for visible_index in 1:active.height
        node_index = state.offset + visible_index
        node_index > length(visible) && break
        item = visible[node_index]
        row = active.row + visible_index - 1
        selected = item.node.id == state.selected
        selected && _fill_row!(buffer, row, active, widget.highlight_style)
        indentation = min(active.width, item.depth * widget.indent)
        column = active.column + indentation
        symbol = isempty(item.node.children) ? widget.leaf_symbol :
                 item.node.id in state.expanded ? widget.expanded_symbol : widget.collapsed_symbol
        style = selected ? widget.highlight_style : Style()
        position = draw_text!(buffer, row, column, symbol; style, clip=active)
        column = position.column
        column < active.column + active.width || continue
        label_area = Rect(row, column, 1, active.column + active.width - column)
        label = selected ? _styled_line(item.node.label, widget.highlight_style) : item.node.label
        draw_line!(buffer, row, label_area, label)
    end
    buffer
end

render!(buffer::Buffer, widget::Tree, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::TreeState, widget::Tree, event::KeyEvent; viewport_height::Integer=1)
    _selection_key_event(event) || return false
    visible = _visible_nodes(widget, state)
    isempty(visible) && return false
    _normalize!(state, visible, max(1, Int(viewport_height)))
    index = something(findfirst(item -> item.node.id == state.selected, visible), 1)
    current = visible[index]
    if event.key.code == :up
        state.selected = visible[max(1, index - 1)].node.id
    elseif event.key.code == :down
        state.selected = visible[min(length(visible), index + 1)].node.id
    elseif event.key.code == :home
        state.selected = first(visible).node.id
    elseif event.key.code == :end
        state.selected = last(visible).node.id
    elseif event.key.code == :page_up
        state.selected = visible[max(1, index - max(1, Int(viewport_height)))].node.id
    elseif event.key.code == :page_down
        state.selected = visible[min(length(visible), index + max(1, Int(viewport_height)))].node.id
    elseif event.key.code == :right
        if !isempty(current.node.children) && !(current.node.id in state.expanded)
            push!(state.expanded, current.node.id)
        elseif !isempty(current.node.children)
            state.selected = first(current.node.children).id
        else
            return false
        end
    elseif event.key.code == :left
        if current.node.id in state.expanded
            delete!(state.expanded, current.node.id)
        elseif !isnothing(current.parent)
            state.selected = current.parent
        else
            return false
        end
    elseif event.key.code in (:enter, :character) &&
           (event.key.code == :enter || event.text == " ") &&
           !isempty(current.node.children)
        current.node.id in state.expanded ?
            delete!(state.expanded, current.node.id) : push!(state.expanded, current.node.id)
    else
        return false
    end
    _normalize!(state, _visible_nodes(widget, state), max(1, Int(viewport_height)))
    true
end

function handle!(state::TreeState, widget::Tree, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) || return false
    active = isnothing(widget.block) ? area : inner(widget.block, area)
    contains(active, event.position) || return false
    visible = _visible_nodes(widget, state)
    _normalize!(state, visible, active.height)
    index = state.offset + event.position.row - active.row + 1
    1 <= index <= length(visible) || return false
    item = visible[index]
    changed = state.selected != item.node.id
    state.selected = item.node.id
    symbol = isempty(item.node.children) ? widget.leaf_symbol :
             item.node.id in state.expanded ? widget.expanded_symbol : widget.collapsed_symbol
    symbol_end = active.column + item.depth * widget.indent + text_width(symbol)
    if !isempty(item.node.children) && event.position.column < symbol_end
        item.node.id in state.expanded ? delete!(state.expanded, item.node.id) :
            push!(state.expanded, item.node.id)
        changed = true
    end
    _normalize!(state, _visible_nodes(widget, state), active.height)
    return changed
end

"""
    TreeView(roots; block=nothing, highlight_style=Style(modifiers=REVERSED), indent=2)

Retained-library style tree view backed by `Tree` and `TreeState`.

`TreeView` is a stable compatibility surface for applications porting Textual,
Lanterna, or other retained TUI tree-view code while preserving Wicked's
immediate rendering and externally owned expansion state.
"""
struct TreeView
    tree::Tree
end

"""Compatibility state alias for `TreeView`; identical to `TreeState`."""
const TreeViewState = TreeState

TreeView(roots::AbstractVector; kwargs...) = TreeView(Tree(roots; kwargs...))

state_for(::TreeView) = TreeViewState()

render!(buffer::Buffer, widget::TreeView, area::Rect, state::TreeViewState) =
    render!(buffer, widget.tree, area, state)

render!(buffer::Buffer, widget::TreeView, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::TreeViewState, widget::TreeView, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.tree, event; viewport_height)

handle!(state::TreeViewState, widget::TreeView, event::MouseEvent, area::Rect) =
    handle!(state, widget.tree, event, area)

"""One action in a menu."""
struct MenuItem
    id::Any
    label::Line
    message::Any
    shortcut::String
    disabled::Bool
end

function MenuItem(
    id,
    label::Union{AbstractString,Line},
    message=id;
    shortcut::AbstractString="",
    disabled::Bool=false,
    style::Style=Style(),
)
    resolved_label = label isa Line ? label : Line(label; style)
    MenuItem(id, resolved_label, message, String(shortcut), disabled)
end

mutable struct MenuState
    selected::Union{Nothing,Int}
    offset::Int
end

MenuState(; selected::Union{Nothing,Integer}=nothing, offset::Integer=0) = begin
    !isnothing(selected) && selected < 1 &&
        throw(ArgumentError("selected menu index must be positive"))
    offset >= 0 || throw(ArgumentError("menu offset must be non-negative"))
    MenuState(isnothing(selected) ? nothing : Int(selected), Int(offset))
end

"""A selectable action menu whose activation returns an application message."""
struct Menu
    items::Vector{MenuItem}
    block::Union{Nothing,Block}
    highlight_style::Style
    disabled_style::Style
end

state_for(::Menu) = MenuState()

function Menu(
    items;
    block::Union{Nothing,Block}=nothing,
    highlight_style::Style=Style(modifiers=REVERSED),
    disabled_style::Style=Style(modifiers=DIM),
)
    Menu(MenuItem[items...], block, highlight_style, disabled_style)
end

function _menu_list(widget::Menu)
    List(
        [ListItem(item.label) for item in widget.items];
        block=widget.block,
        highlight_style=widget.highlight_style,
        highlight_symbol="  ",
    )
end

function _menu_list_state(state::MenuState)
    ListState(selected=state.selected, offset=state.offset)
end

function _copy_menu_state!(state::MenuState, list_state::ListState)
    state.selected = list_state.selected
    state.offset = list_state.offset
    state
end

function _normalize_menu_selection!(state::MenuState, widget::Menu; viewport_height::Integer=1)
    if isnothing(state.selected)
        state.offset = clamp(state.offset, 0, max(0, length(widget.items) - max(1, Int(viewport_height))))
        return state
    end
    if !(1 <= state.selected <= length(widget.items)) || widget.items[state.selected].disabled
        state.selected = nothing
        return state
    end
    visible = max(1, Int(viewport_height))
    state.selected <= state.offset && (state.offset = state.selected - 1)
    state.selected > state.offset + visible && (state.offset = state.selected - visible)
    state
end

"""Select an enabled menu item by absolute item index."""
function select_menu_item!(
    state::MenuState,
    widget::Menu,
    index::Integer;
    viewport_height::Integer=1,
)
    resolved = Int(index)
    if !(1 <= resolved <= length(widget.items)) || widget.items[resolved].disabled
        state.selected = nothing
        return state
    end
    state.selected = resolved
    _normalize_menu_selection!(state, widget; viewport_height)
end

"""Select the next enabled menu item, wrapping at the end."""
function select_next_menu_item!(
    state::MenuState,
    widget::Menu;
    viewport_height::Integer=1,
)
    candidate = _next_enabled(widget, something(state.selected, 0), 1)
    isnothing(candidate) ? (state.selected = nothing) : (state.selected = candidate)
    _normalize_menu_selection!(state, widget; viewport_height)
end

"""Select the previous enabled menu item, wrapping at the beginning."""
function select_previous_menu_item!(
    state::MenuState,
    widget::Menu;
    viewport_height::Integer=1,
)
    start = isnothing(state.selected) ? 1 : state.selected
    candidate = _next_enabled(widget, start, -1)
    isnothing(candidate) ? (state.selected = nothing) : (state.selected = candidate)
    _normalize_menu_selection!(state, widget; viewport_height)
end

function render!(buffer::Buffer, widget::Menu, area::Rect, state::MenuState)
    list_state = _menu_list_state(state)
    render!(buffer, _menu_list(widget), area, list_state)
    _copy_menu_state!(state, list_state)
    active = isnothing(widget.block) ? intersection(buffer.area, area) :
             intersection(buffer.area, inner(widget.block, area))
    for visible_index in 1:active.height
        item_index = state.offset + visible_index
        item_index > length(widget.items) && break
        item = widget.items[item_index]
        item.disabled || isempty(item.shortcut) && continue
        row = active.row + visible_index - 1
        if item.disabled
            _fill_row!(buffer, row, active, widget.disabled_style)
            draw_line!(buffer, row, active, _styled_line(item.label, widget.disabled_style))
        end
        if !isempty(item.shortcut)
            width = min(active.width, text_width(item.shortcut))
            shortcut_area = Rect(row, active.column + active.width - width, 1, width)
            draw_text!(buffer, row, shortcut_area.column, item.shortcut; clip=shortcut_area)
        end
    end
    buffer
end

render!(buffer::Buffer, widget::Menu, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function _next_enabled(widget::Menu, start::Int, direction::Int)
    isempty(widget.items) && return nothing
    index = start
    for _ in eachindex(widget.items)
        index = mod1(index + direction, length(widget.items))
        !widget.items[index].disabled && return index
    end
    nothing
end

function _page_enabled(widget::Menu, target::Int, direction::Int)
    isempty(widget.items) && return nothing
    direction == 0 && return nothing
    count = length(widget.items)
    if direction < 0
        for index in clamp(target, 1, count):-1:1
            !widget.items[index].disabled && return index
        end
    else
        index = clamp(target, 1, count)
        !widget.items[index].disabled && return index
    end
    nothing
end

function handle!(state::MenuState, widget::Menu, event::KeyEvent; viewport_height::Integer=1)
    _selection_key_event(event) || return false
    isempty(widget.items) && return false
    current = something(state.selected, 0)
    if event.key.code in (:up, :backtab)
        state.selected = _next_enabled(widget, current == 0 ? 1 : current, -1)
    elseif event.key.code in (:down, :tab)
        state.selected = _next_enabled(widget, current, 1)
    elseif event.key.code == :home
        state.selected = findfirst(item -> !item.disabled, widget.items)
    elseif event.key.code == :end
        state.selected = findlast(item -> !item.disabled, widget.items)
    elseif event.key.code == :page_up
        start = something(state.selected, length(widget.items) + 1)
        target = start - max(1, Int(viewport_height))
        candidate = _page_enabled(widget, target, -1)
        candidate === nothing || (state.selected = candidate)
    elseif event.key.code == :page_down
        start = something(state.selected, 0)
        target = start + max(1, Int(viewport_height))
        candidate = _page_enabled(widget, target, 1)
        candidate === nothing || (state.selected = candidate)
    elseif event.key.code in (:enter, :character) &&
           (event.key.code == :enter || event.text == " ")
        if isnothing(state.selected) || widget.items[state.selected].disabled
            state.selected = _next_enabled(widget, current, 1)
            isnothing(state.selected) && return false
        end
    else
        return false
    end
    if isnothing(state.selected)
        return false
    end
    visible = max(1, Int(viewport_height))
    state.selected <= state.offset && (state.offset = state.selected - 1)
    state.selected > state.offset + visible && (state.offset = state.selected - visible)
    true
end

function handle!(state::MenuState, widget::Menu, event::MouseEvent, area::Rect)
    _selection_mouse_event(event) || return false
    active = isnothing(widget.block) ? area : inner(widget.block, area)
    contains(active, event.position) || return false
    index = state.offset + event.position.row - active.row + 1
    1 <= index <= length(widget.items) || return false
    widget.items[index].disabled && return false
    state.selected = index
    return true
end

"""Return the currently selected enabled menu item."""
function selected_item(widget::Menu, state::MenuState)
    isnothing(state.selected) && return nothing
    1 <= state.selected <= length(widget.items) || return nothing
    item = widget.items[state.selected]
    item.disabled ? nothing : item
end

"""Return the currently selected enabled menu item."""
selected_menu_item(widget::Menu, state::MenuState) =
    selected_item(widget, state)

"""Return the selected menu item's application message."""
function activate(widget::Menu, state::MenuState)
    item = selected_item(widget, state)
    isnothing(item) ? nothing : item.message
end

"""Return the currently selected menu item's application message."""
selected_menu_message(widget::Menu, state::MenuState) =
    activate(widget, state)
