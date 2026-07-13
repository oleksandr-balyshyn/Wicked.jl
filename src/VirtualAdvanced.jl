module VirtualAdvanced

using ..Virtualization: ReadySlot,
                        EndSlot,
                        VirtualListState,
                        VirtualViewport,
                        VirtualListWindow,
                        VirtualTableColumn,
                        VirtualTableWindow,
                        ensure_virtual_cursor_visible!,
                        SortDirection,
                        AscendingSort,
                        DescendingSort,
                        SortTerm,
                        DataQuery,
                        set_data_query!

export VirtualRangeSelection,
       RangeSelectionResult,
       begin_virtual_range_selection,
       apply_virtual_range_selection!,
       cancel_virtual_range_selection!,
       virtual_selection_snapshot,
       restore_virtual_selection!,
       virtual_selected_row_records,
       virtual_selected_row_snapshot,
       virtual_range_selected_row_records,
       virtual_range_selected_row_snapshot,
       VirtualCellEditState,
       VirtualCellEditResult,
       VirtualCellEditHistory,
       begin_virtual_cell_edit!,
       update_virtual_cell_edit!,
       commit_virtual_cell_edit!,
       cancel_virtual_cell_edit!,
       virtual_cell_edit_snapshot,
       restore_virtual_cell_edit!,
       apply_virtual_cell_edit,
       apply_virtual_cell_edit!,
       record_virtual_cell_edit!,
       undo_virtual_cell_edit!,
       redo_virtual_cell_edit!,
       virtual_cell_edit_history_snapshot,
       restore_virtual_cell_edit_history!,
       VirtualTypeAhead,
       push_virtual_typeahead!,
       backspace_virtual_typeahead!,
       clear_virtual_typeahead!,
       apply_virtual_typeahead!,
       TableLayoutState,
       table_layout_snapshot,
       restore_table_layout!,
       table_preferences_bundle,
       restore_table_preferences!,
       apply_table_preferences,
       table_preferences_summary,
       table_preferences_text,
       table_preferences_markdown,
       table_preferences_tsv,
       ColumnVisibilityState,
       column_visibility_snapshot,
       restore_column_visibility!,
       hide_virtual_column!,
       show_virtual_column!,
       toggle_virtual_column_visibility!,
       virtual_column_visible,
       visible_virtual_columns,
       apply_virtual_column_visibility,
       ColumnPinState,
       column_pin_snapshot,
       restore_column_pin!,
       pin_virtual_column_left!,
       pin_virtual_column_right!,
       unpin_virtual_column!,
       toggle_virtual_column_pin!,
       virtual_column_pin_position,
       pinned_virtual_columns,
       apply_virtual_column_pinning,
       VirtualColumnAction,
       VirtualColumnActionResult,
       default_virtual_column_actions,
       virtual_column_action_enabled,
       virtual_column_action_menu,
       virtual_column_action_records,
       invoke_virtual_column_action,
       virtual_column_action_for_shortcut,
       invoke_virtual_column_action_shortcut,
       virtual_column_action_summary,
       virtual_column_action_text,
       virtual_column_action_markdown,
       virtual_column_action_tsv,
       VirtualRowAction,
       VirtualRowActionResult,
       VirtualRowActionBatchResult,
       virtual_row_action_enabled,
       virtual_row_action_menu,
       virtual_row_action_records,
       invoke_virtual_row_action,
       invoke_virtual_row_action_batch,
       invoke_virtual_range_row_action_batch,
       virtual_row_action_batch_records,
       virtual_row_action_batch_summary,
       virtual_row_action_batch_text,
       virtual_row_action_batch_markdown,
       virtual_row_action_batch_tsv,
       virtual_row_action_for_shortcut,
       invoke_virtual_row_action_shortcut,
       set_virtual_column_width!,
       reorder_virtual_column!,
       apply_virtual_table_layout,
       ColumnResizeSession,
       begin_virtual_column_resize,
       update_virtual_column_resize!,
       finish_virtual_column_resize!,
       cancel_virtual_column_resize!,
       toggle_virtual_sort!,
       set_virtual_filter!,
       clear_virtual_filter!,
       set_virtual_search!,
       virtual_table_query,
       apply_virtual_table_query!,
       data_query_summary,
       data_query_text,
       data_query_markdown,
       data_query_tsv,
       virtual_table_column_at

mutable struct VirtualRangeSelection
    anchor::Int
    target::Int
    additive::Bool
    initialized::Bool
    resolved::BitSet
    cancelled::Bool
    generation::Union{Nothing,UInt64}

    function VirtualRangeSelection(
        anchor::Integer,
        target::Integer;
        additive::Bool=false,
        max_items::Integer=1_000_000,
        generation::Union{Nothing,Integer}=nothing,
    )
        anchor > 0 || throw(ArgumentError("range anchor must be positive"))
        target > 0 || throw(ArgumentError("range target must be positive"))
        max_items > 0 || throw(ArgumentError("maximum selectable range must be positive"))
        span = abs(big(target) - big(anchor)) + 1
        span <= max_items || throw(ArgumentError("selection range exceeds configured maximum"))
        generation !== nothing && generation < 0 && throw(ArgumentError("selection generation cannot be negative"))
        new(
            Int(anchor),
            Int(target),
            additive,
            false,
            BitSet(),
            false,
            generation === nothing ? nothing : UInt64(generation),
        )
    end
end

function begin_virtual_range_selection(
    state::VirtualListState,
    target::Integer;
    additive::Bool=false,
    max_items::Integer=1_000_000,
    generation::Union{Nothing,Integer}=nothing,
)
    anchor = something(state.anchor, state.cursor, Int(target))
    return VirtualRangeSelection(
        anchor,
        target;
        additive=additive,
        max_items=max_items,
        generation=generation,
    )
end

begin_virtual_range_selection(
    state::VirtualListState,
    window::VirtualListWindow,
    target::Integer;
    kwargs...,
) = begin_virtual_range_selection(state, target; generation=window.version, kwargs...)

struct RangeSelectionResult
    applied::Int
    pending::Int
    complete::Bool
    invalidated::Bool
end

function apply_virtual_range_selection!(
    state::VirtualListState{K},
    window::VirtualListWindow{T,K},
    selection::VirtualRangeSelection,
) where {T,K}
    selection.cancelled && return RangeSelectionResult(0, 0, false, true)
    if selection.generation === nothing
        selection.generation = window.version
    elseif selection.generation != window.version
        selection.cancelled = true
        return RangeSelectionResult(0, 0, false, true)
    end
    if !selection.initialized
        selection.additive || empty!(state.selected)
        selection.initialized = true
    end
    first_index, stop_index = minmax(selection.anchor, selection.target)
    applied = 0
    for slot in window.slots
        first_index <= slot.index <= stop_index || continue
        slot.index in selection.resolved && continue
        if slot.kind == ReadySlot
            push!(state.selected, slot.key::K)
            push!(selection.resolved, slot.index)
            applied += 1
        elseif slot.kind == EndSlot
            push!(selection.resolved, slot.index)
        end
    end
    expected = stop_index - first_index + 1
    complete = length(selection.resolved) == expected
    pending = max(0, expected - length(selection.resolved))
    state.cursor = selection.target
    complete && (state.anchor = selection.anchor)
    return RangeSelectionResult(applied, pending, complete, false)
end

cancel_virtual_range_selection!(selection::VirtualRangeSelection) =
    (selection.cancelled = true; selection)

function virtual_selection_snapshot(state::VirtualListState)
    selected = collect(state.selected)
    sort!(selected; by=string)
    return (
        cursor=state.cursor,
        anchor=state.anchor,
        selected=selected,
        first_index=state.viewport.first_index,
        viewport_size=state.viewport.viewport_size,
        overscan=state.viewport.overscan,
        multiple=state.multiple,
    )
end

function restore_virtual_selection!(state::VirtualListState{K}, snapshot) where {K}
    cursor = _snapshot_value(snapshot, :cursor, state.cursor)
    anchor = _snapshot_value(snapshot, :anchor, state.anchor)
    selected = _snapshot_value(snapshot, :selected, K[])
    first_index = _snapshot_value(snapshot, :first_index, state.viewport.first_index)
    viewport_size = _snapshot_value(snapshot, :viewport_size, state.viewport.viewport_size)
    overscan = _snapshot_value(snapshot, :overscan, state.viewport.overscan)
    multiple = _snapshot_value(snapshot, :multiple, state.multiple)
    state.cursor = cursor === nothing ? nothing : Int(cursor)
    state.anchor = anchor === nothing ? nothing : Int(anchor)
    state.selected = Set{K}(selected)
    state.viewport = VirtualViewport(Int(first_index), Int(viewport_size); overscan=Int(overscan))
    state.multiple = Bool(multiple)
    return state
end

function _virtual_cell_record(cell)
    return (
        column=cell.column,
        value=cell.value,
        width=cell.width,
        alignment=cell.alignment,
    )
end

function virtual_selected_row_records(
    state::VirtualListState,
    window::VirtualTableWindow;
    include_unready::Bool=false,
)
    records = NamedTuple[]
    for row in window.rows
        row.key === nothing && continue
        row.key in state.selected || continue
        include_unready || row.kind == ReadySlot || continue
        cells = [_virtual_cell_record(cell) for cell in row.cells]
        push!(records, (
            index=row.index,
            key=row.key,
            kind=row.kind,
            cells=cells,
            cell_values=Dict(cell.column => cell.value for cell in row.cells),
        ))
    end
    sort!(records; by=record -> record.index)
    return records
end

function virtual_selected_row_snapshot(
    state::VirtualListState,
    window::VirtualTableWindow;
    include_unready::Bool=false,
)
    records = virtual_selected_row_records(state, window; include_unready)
    return (
        selection=virtual_selection_snapshot(state),
        first_visible=window.first_visible,
        last_visible=window.last_visible,
        total_length=window.total_length,
        count=length(records),
        rows=records,
    )
end

function _virtual_range_bounds(selection::VirtualRangeSelection)
    return minmax(selection.anchor, selection.target)
end

function virtual_range_selected_row_records(
    selection::VirtualRangeSelection,
    window::VirtualTableWindow;
    include_unready::Bool=false,
)
    selection.cancelled && return NamedTuple[]
    first_index, stop_index = _virtual_range_bounds(selection)
    records = NamedTuple[]
    for row in window.rows
        first_index <= row.index <= stop_index || continue
        include_unready || row.kind == ReadySlot || continue
        cells = [_virtual_cell_record(cell) for cell in row.cells]
        push!(records, (
            index=row.index,
            key=row.key,
            kind=row.kind,
            resolved=row.index in selection.resolved,
            cells=cells,
            cell_values=Dict(cell.column => cell.value for cell in row.cells),
        ))
    end
    sort!(records; by=record -> record.index)
    return records
end

function virtual_range_selected_row_snapshot(
    selection::VirtualRangeSelection,
    window::VirtualTableWindow;
    include_unready::Bool=false,
)
    first_index, stop_index = _virtual_range_bounds(selection)
    expected = stop_index - first_index + 1
    records = virtual_range_selected_row_records(selection, window; include_unready)
    resolved = collect(selection.resolved)
    sort!(resolved)
    return (
        anchor=selection.anchor,
        target=selection.target,
        first_index=first_index,
        last_index=stop_index,
        additive=selection.additive,
        initialized=selection.initialized,
        cancelled=selection.cancelled,
        generation=selection.generation,
        resolved=resolved,
        expected=expected,
        pending=max(0, expected - length(selection.resolved)),
        first_visible=window.first_visible,
        last_visible=window.last_visible,
        total_length=window.total_length,
        count=length(records),
        rows=records,
    )
end

mutable struct VirtualCellEditState
    active::Bool
    row::Union{Nothing,Int}
    key::Any
    column::Union{Nothing,Symbol}
    original::Any
    draft::Any
    valid::Bool
    message::Union{Nothing,String}
end

VirtualCellEditState() =
    VirtualCellEditState(false, nothing, nothing, nothing, nothing, nothing, true, nothing)

struct VirtualCellEditResult
    committed::Bool
    row::Union{Nothing,Int}
    key::Any
    column::Union{Nothing,Symbol}
    original::Any
    value::Any
    valid::Bool
    message::Union{Nothing,String}
end

mutable struct VirtualCellEditHistory
    undo::Vector{VirtualCellEditResult}
    redo::Vector{VirtualCellEditResult}
    limit::Int

    function VirtualCellEditHistory(;
        undo::AbstractVector{<:VirtualCellEditResult}=VirtualCellEditResult[],
        redo::AbstractVector{<:VirtualCellEditResult}=VirtualCellEditResult[],
        limit::Integer=100,
    )
        limit >= 0 || throw(ArgumentError("virtual cell edit history limit cannot be negative"))
        history = new(VirtualCellEditResult[undo...], VirtualCellEditResult[redo...], Int(limit))
        _trim_virtual_cell_edit_history!(history.undo, history.limit)
        _trim_virtual_cell_edit_history!(history.redo, history.limit)
        return history
    end
end

function begin_virtual_cell_edit!(
    state::VirtualCellEditState,
    row::Integer,
    column;
    key=nothing,
    value=nothing,
)
    state.active = true
    state.row = Int(row)
    state.key = key
    state.column = Symbol(column)
    state.original = value
    state.draft = value
    state.valid = true
    state.message = nothing
    return state
end

function update_virtual_cell_edit!(
    state::VirtualCellEditState,
    value;
    validator=nothing,
)
    state.active || throw(ArgumentError("no active virtual cell edit"))
    state.draft = value
    if validator !== nothing
        result = validator(value)
        if result isa Tuple
            state.valid = Bool(first(result))
            state.message = length(result) > 1 && result[2] !== nothing ? string(result[2]) : nothing
        else
            state.valid = Bool(result)
            state.message = state.valid ? nothing : "cell value is invalid"
        end
    else
        state.valid = true
        state.message = nothing
    end
    return state
end

function commit_virtual_cell_edit!(state::VirtualCellEditState)
    state.active || return VirtualCellEditResult(false, nothing, nothing, nothing, nothing, nothing, false, "no active virtual cell edit")
    result = VirtualCellEditResult(
        state.valid,
        state.row,
        state.key,
        state.column,
        state.original,
        state.draft,
        state.valid,
        state.message,
    )
    state.active = false
    return result
end

function cancel_virtual_cell_edit!(state::VirtualCellEditState)
    result = VirtualCellEditResult(
        false,
        state.row,
        state.key,
        state.column,
        state.original,
        state.original,
        true,
        "cell edit cancelled",
    )
    state.active = false
    return result
end

function virtual_cell_edit_snapshot(state::VirtualCellEditState)
    return (
        active=state.active,
        row=state.row,
        key=state.key,
        column=state.column,
        original=state.original,
        draft=state.draft,
        valid=state.valid,
        message=state.message,
    )
end

function restore_virtual_cell_edit!(state::VirtualCellEditState, snapshot)
    state.active = Bool(_snapshot_value(snapshot, :active, state.active))
    row = _snapshot_value(snapshot, :row, state.row)
    state.row = row === nothing ? nothing : Int(row)
    state.key = _snapshot_value(snapshot, :key, state.key)
    column = _snapshot_value(snapshot, :column, state.column)
    state.column = column === nothing ? nothing : Symbol(column)
    state.original = _snapshot_value(snapshot, :original, state.original)
    state.draft = _snapshot_value(snapshot, :draft, state.draft)
    state.valid = Bool(_snapshot_value(snapshot, :valid, state.valid))
    message = _snapshot_value(snapshot, :message, state.message)
    state.message = message === nothing ? nothing : string(message)
    return state
end

function apply_virtual_cell_edit(row, result::VirtualCellEditResult)
    result.committed && result.valid || return row
    column = result.column
    column === nothing && return row
    if row isa AbstractDict
        updated = copy(row)
        key = haskey(updated, column) ? column : string(column)
        updated[key] = result.value
        return updated
    elseif row isa NamedTuple
        return merge(row, NamedTuple{(column,)}((result.value,)))
    end
    throw(ArgumentError("virtual cell edit application supports dictionaries and named tuples"))
end

function apply_virtual_cell_edit!(row::AbstractDict, result::VirtualCellEditResult)
    result.committed && result.valid || return row
    column = result.column
    column === nothing && return row
    key = haskey(row, column) ? column : string(column)
    row[key] = result.value
    return row
end

function _trim_virtual_cell_edit_history!(stack::Vector{VirtualCellEditResult}, limit::Int)
    while length(stack) > limit
        popfirst!(stack)
    end
    return stack
end

function _virtual_cell_edit_result_snapshot(result::VirtualCellEditResult)
    return (
        committed=result.committed,
        row=result.row,
        key=result.key,
        column=result.column,
        original=result.original,
        value=result.value,
        valid=result.valid,
        message=result.message,
    )
end

function _virtual_cell_edit_result_from_snapshot(snapshot)
    row = _snapshot_value(snapshot, :row, nothing)
    column = _snapshot_value(snapshot, :column, nothing)
    message = _snapshot_value(snapshot, :message, nothing)
    return VirtualCellEditResult(
        Bool(_snapshot_value(snapshot, :committed, false)),
        row === nothing ? nothing : Int(row),
        _snapshot_value(snapshot, :key, nothing),
        column === nothing ? nothing : Symbol(column),
        _snapshot_value(snapshot, :original, nothing),
        _snapshot_value(snapshot, :value, nothing),
        Bool(_snapshot_value(snapshot, :valid, false)),
        message === nothing ? nothing : string(message),
    )
end

_inverse_virtual_cell_edit(result::VirtualCellEditResult) = VirtualCellEditResult(
    true,
    result.row,
    result.key,
    result.column,
    result.value,
    result.original,
    result.valid,
    result.message,
)

function record_virtual_cell_edit!(history::VirtualCellEditHistory, result::VirtualCellEditResult)
    result.committed && result.valid || return history
    push!(history.undo, result)
    empty!(history.redo)
    _trim_virtual_cell_edit_history!(history.undo, history.limit)
    return history
end

function undo_virtual_cell_edit!(history::VirtualCellEditHistory)
    isempty(history.undo) && return nothing
    result = pop!(history.undo)
    push!(history.redo, result)
    _trim_virtual_cell_edit_history!(history.redo, history.limit)
    return _inverse_virtual_cell_edit(result)
end

function redo_virtual_cell_edit!(history::VirtualCellEditHistory)
    isempty(history.redo) && return nothing
    result = pop!(history.redo)
    push!(history.undo, result)
    _trim_virtual_cell_edit_history!(history.undo, history.limit)
    return result
end

function virtual_cell_edit_history_snapshot(history::VirtualCellEditHistory)
    return (
        undo=[_virtual_cell_edit_result_snapshot(result) for result in history.undo],
        redo=[_virtual_cell_edit_result_snapshot(result) for result in history.redo],
        limit=history.limit,
    )
end

function restore_virtual_cell_edit_history!(history::VirtualCellEditHistory, snapshot)
    history.limit = Int(_snapshot_value(snapshot, :limit, history.limit))
    history.limit >= 0 || throw(ArgumentError("virtual cell edit history limit cannot be negative"))
    history.undo = VirtualCellEditResult[
        _virtual_cell_edit_result_from_snapshot(result)
        for result in _snapshot_value(snapshot, :undo, ())
    ]
    history.redo = VirtualCellEditResult[
        _virtual_cell_edit_result_from_snapshot(result)
        for result in _snapshot_value(snapshot, :redo, ())
    ]
    _trim_virtual_cell_edit_history!(history.undo, history.limit)
    _trim_virtual_cell_edit_history!(history.redo, history.limit)
    return history
end

mutable struct VirtualTypeAhead
    query::String
    last_input_ns::UInt64
    timeout_ns::UInt64
    case_sensitive::Bool

    function VirtualTypeAhead(;
        timeout_ms::Integer=750,
        case_sensitive::Bool=false,
    )
        timeout_ms > 0 || throw(ArgumentError("type-ahead timeout must be positive"))
        timeout_ns = big(timeout_ms) * 1_000_000
        timeout_ns <= typemax(UInt64) || throw(ArgumentError("type-ahead timeout is too large"))
        new("", 0, UInt64(timeout_ns), case_sensitive)
    end
end

function _expired(state::VirtualTypeAhead, now_ns::UInt64)
    state.last_input_ns == 0 && return true
    now_ns < state.last_input_ns && return true
    return now_ns - state.last_input_ns > state.timeout_ns
end

function push_virtual_typeahead!(
    state::VirtualTypeAhead,
    input::AbstractString;
    now_ns::Integer=time_ns(),
)
    0 <= now_ns <= typemax(UInt64) || throw(ArgumentError("type-ahead timestamp must fit UInt64"))
    any(iscntrl, input) && throw(ArgumentError("type-ahead input cannot contain control characters"))
    timestamp = UInt64(now_ns)
    _expired(state, timestamp) && (state.query = "")
    state.query *= String(input)
    state.last_input_ns = timestamp
    return state
end

function backspace_virtual_typeahead!(state::VirtualTypeAhead; now_ns::Integer=time_ns())
    if !isempty(state.query)
        state.query = chop(state.query; tail=1)
    end
    state.last_input_ns = UInt64(now_ns)
    return state
end

clear_virtual_typeahead!(state::VirtualTypeAhead) =
    (state.query = ""; state.last_input_ns = 0; state)

function _normalized(state::VirtualTypeAhead, value::AbstractString)
    return state.case_sensitive ? String(value) : lowercase(String(value))
end

function apply_virtual_typeahead!(
    list_state::VirtualListState{K},
    window::VirtualListWindow{T,K},
    typeahead::VirtualTypeAhead;
    item_text=(item, index) -> string(item),
    wrap::Bool=true,
) where {T,K}
    isempty(typeahead.query) && return nothing
    candidates = [slot for slot in window.slots if slot.kind == ReadySlot]
    isempty(candidates) && return nothing
    sort!(candidates; by=slot -> slot.index)
    current = something(list_state.cursor, first(candidates).index - 1)
    ordered = [slot for slot in candidates if slot.index > current]
    wrap && append!(ordered, (slot for slot in candidates if slot.index <= current))
    needle = _normalized(typeahead, typeahead.query)
    for slot in ordered
        haystack = _normalized(typeahead, string(item_text(slot.item, slot.index)))
        startswith(haystack, needle) || continue
        list_state.cursor = slot.index
        ensure_virtual_cursor_visible!(list_state; total_length=window.total_length)
        return slot
    end
    return nothing
end

mutable struct TableLayoutState
    order::Vector{Symbol}
    widths::Dict{Symbol,Int}
    sort::Vector{SortTerm}
    filters::Dict{Symbol,Any}
    search::Union{Nothing,String}
    query_revision::UInt64
end

TableLayoutState(columns=VirtualTableColumn[]) = TableLayoutState(
    Symbol[column.id for column in columns],
    Dict{Symbol,Int}(column.id => column.width for column in columns),
    SortTerm[],
    Dict{Symbol,Any}(),
    nothing,
    0,
)

function _snapshot_value(snapshot, field::Symbol, default=nothing)
    if snapshot isa AbstractDict
        haskey(snapshot, field) && return snapshot[field]
        key = String(field)
        haskey(snapshot, key) && return snapshot[key]
        return default
    end
    return hasproperty(snapshot, field) ? getproperty(snapshot, field) : default
end

_sort_direction_symbol(direction::SortDirection) =
    direction == AscendingSort ? :ascending : :descending

function _sort_direction_value(value)
    value isa SortDirection && return value
    identifier = Symbol(value)
    identifier in (:ascending, :asc, :AscendingSort) && return AscendingSort
    identifier in (:descending, :desc, :DescendingSort) && return DescendingSort
    throw(ArgumentError("unsupported sort direction: $value"))
end

function _snapshot_sort_term(term)
    term isa SortTerm && return SortTerm(term.column, term.direction)
    column = _snapshot_value(term, :column, nothing)
    column === nothing && throw(ArgumentError("sort term snapshot is missing column"))
    direction = _snapshot_value(term, :direction, AscendingSort)
    return SortTerm(Symbol(column), _sort_direction_value(direction))
end

function table_layout_snapshot(state::TableLayoutState)
    return (
        order=Symbol[column for column in state.order],
        widths=Dict{Symbol,Int}(column => width for (column, width) in pairs(state.widths)),
        sort=[(column=term.column, direction=_sort_direction_symbol(term.direction)) for term in state.sort],
        filters=Dict{Symbol,Any}(column => value for (column, value) in pairs(state.filters)),
        search=state.search,
        query_revision=state.query_revision,
    )
end

function restore_table_layout!(state::TableLayoutState, snapshot)
    order = _snapshot_value(snapshot, :order, state.order)
    widths = _snapshot_value(snapshot, :widths, state.widths)
    sort = _snapshot_value(snapshot, :sort, state.sort)
    filters = _snapshot_value(snapshot, :filters, state.filters)
    search = _snapshot_value(snapshot, :search, state.search)
    query_revision = _snapshot_value(snapshot, :query_revision, state.query_revision)

    state.order = Symbol[Symbol(column) for column in order]
    state.widths = Dict{Symbol,Int}(Symbol(column) => Int(width) for (column, width) in pairs(widths))
    state.sort = SortTerm[_snapshot_sort_term(term) for term in sort]
    state.filters = Dict{Symbol,Any}(Symbol(column) => value for (column, value) in pairs(filters))
    state.search = search === nothing ? nothing : String(search)
    query_revision >= 0 || throw(ArgumentError("table query revision cannot be negative"))
    state.query_revision = UInt64(query_revision)
    return state
end

mutable struct ColumnVisibilityState
    hidden::Set{Symbol}
end

function ColumnVisibilityState(; hidden=Symbol[])
    return ColumnVisibilityState(Set{Symbol}(Symbol(column) for column in hidden))
end

ColumnVisibilityState(hidden::AbstractVector) = ColumnVisibilityState(; hidden=hidden)

function column_visibility_snapshot(state::ColumnVisibilityState)
    hidden = Symbol[column for column in state.hidden]
    sort!(hidden; by=string)
    return (hidden=hidden,)
end

function restore_column_visibility!(state::ColumnVisibilityState, snapshot)
    hidden = _snapshot_value(snapshot, :hidden, snapshot)
    empty!(state.hidden)
    foreach(column -> push!(state.hidden, Symbol(column)), hidden)
    return state
end

hide_virtual_column!(state::ColumnVisibilityState, column) =
    (push!(state.hidden, Symbol(column)); state)

show_virtual_column!(state::ColumnVisibilityState, column) =
    (delete!(state.hidden, Symbol(column)); state)

function toggle_virtual_column_visibility!(state::ColumnVisibilityState, column)
    identifier = Symbol(column)
    if identifier in state.hidden
        delete!(state.hidden, identifier)
    else
        push!(state.hidden, identifier)
    end
    return state
end

virtual_column_visible(state::ColumnVisibilityState, column) =
    !(Symbol(column) in state.hidden)

visible_virtual_columns(
    columns::AbstractVector{<:VirtualTableColumn},
    state::ColumnVisibilityState,
) = VirtualTableColumn[
    column for column in columns if virtual_column_visible(state, column.id)
]

function apply_virtual_column_visibility(
    columns::AbstractVector{<:VirtualTableColumn},
    layout::TableLayoutState,
    visibility::ColumnVisibilityState,
)
    return apply_virtual_table_layout(visible_virtual_columns(columns, visibility), layout)
end

mutable struct ColumnPinState
    left::Vector{Symbol}
    right::Vector{Symbol}
end

function _normalized_column_vector(columns)
    result = Symbol[]
    for column in columns
        identifier = Symbol(column)
        identifier in result || push!(result, identifier)
    end
    return result
end

function ColumnPinState(; left=Symbol[], right=Symbol[])
    left_columns = _normalized_column_vector(left)
    right_columns = Symbol[
        column for column in _normalized_column_vector(right)
        if !(column in left_columns)
    ]
    return ColumnPinState(left_columns, right_columns)
end

ColumnPinState(left::AbstractVector{<:Any}, right::AbstractVector{<:Any}=Symbol[]) = ColumnPinState(; left=left, right=right)

function column_pin_snapshot(state::ColumnPinState)
    return (left=Symbol[column for column in state.left], right=Symbol[column for column in state.right])
end

function restore_column_pin!(state::ColumnPinState, snapshot)
    left = _snapshot_value(snapshot, :left, Symbol[])
    right = _snapshot_value(snapshot, :right, Symbol[])
    restored = ColumnPinState(; left, right)
    state.left = restored.left
    state.right = restored.right
    return state
end

function _unpin_column!(state::ColumnPinState, column)
    identifier = Symbol(column)
    filter!(!=(identifier), state.left)
    filter!(!=(identifier), state.right)
    return identifier
end

function pin_virtual_column_left!(state::ColumnPinState, column)
    identifier = _unpin_column!(state, column)
    push!(state.left, identifier)
    return state
end

function pin_virtual_column_right!(state::ColumnPinState, column)
    identifier = _unpin_column!(state, column)
    push!(state.right, identifier)
    return state
end

unpin_virtual_column!(state::ColumnPinState, column) =
    (_unpin_column!(state, column); state)

function toggle_virtual_column_pin!(
    state::ColumnPinState,
    column;
    side::Symbol=:left,
)
    identifier = Symbol(column)
    if identifier in state.left || identifier in state.right
        unpin_virtual_column!(state, identifier)
    elseif side == :left
        pin_virtual_column_left!(state, identifier)
    elseif side == :right
        pin_virtual_column_right!(state, identifier)
    else
        throw(ArgumentError("unsupported virtual column pin side: $side"))
    end
    return state
end

function virtual_column_pin_position(state::ColumnPinState, column)
    identifier = Symbol(column)
    identifier in state.left && return :left
    identifier in state.right && return :right
    return nothing
end

function _column_by_id(columns)
    return Dict{Symbol,Any}(column.id => column for column in columns)
end

function pinned_virtual_columns(
    columns::AbstractVector{<:VirtualTableColumn},
    state::ColumnPinState,
)
    by_id = _column_by_id(columns)
    left = Symbol[column for column in state.left if haskey(by_id, column)]
    right = Symbol[column for column in state.right if haskey(by_id, column) && !(column in left)]
    middle = Symbol[
        column.id for column in columns
        if !(column.id in left) && !(column.id in right)
    ]
    ordered = vcat(left, middle, right)
    return VirtualTableColumn[by_id[column] for column in ordered]
end

function apply_virtual_column_pinning(
    columns::AbstractVector{<:VirtualTableColumn},
    layout::TableLayoutState,
    pinning::ColumnPinState,
)
    return pinned_virtual_columns(apply_virtual_table_layout(columns, layout), pinning)
end

struct VirtualColumnAction{H,E}
    id::Symbol
    label::String
    handler::H
    enabled::E
    shortcut::Union{Nothing,String}
end

function VirtualColumnAction(
    id,
    label::AbstractString;
    handler=(column, layout, visibility, pinning) -> Symbol(id),
    enabled=true,
    shortcut=nothing,
)
    return VirtualColumnAction{typeof(handler),typeof(enabled)}(
        Symbol(id),
        String(label),
        handler,
        enabled,
        shortcut === nothing ? nothing : string(shortcut),
    )
end

struct VirtualColumnActionResult
    action::Symbol
    label::String
    column::Symbol
    value::Any
    handled::Bool
end

function _call_column_action(function_or_value, column::Symbol, layout::TableLayoutState, visibility, pinning)
    applicable(function_or_value, column, layout, visibility, pinning) && return function_or_value(column, layout, visibility, pinning)
    applicable(function_or_value, column, layout, visibility) && return function_or_value(column, layout, visibility)
    applicable(function_or_value, column, layout) && return function_or_value(column, layout)
    applicable(function_or_value, column) && return function_or_value(column)
    applicable(function_or_value) && return function_or_value()
    return function_or_value
end

function virtual_column_action_enabled(
    action::VirtualColumnAction,
    column,
    layout::TableLayoutState;
    visibility=nothing,
    pinning=nothing,
)
    enabled = _call_column_action(action.enabled, Symbol(column), layout, visibility, pinning)
    enabled isa Bool || throw(ArgumentError("column action enabled value must resolve to Bool"))
    return enabled
end

function virtual_column_action_menu(
    actions::AbstractVector{<:VirtualColumnAction},
    column,
    layout::TableLayoutState;
    visibility=nothing,
    pinning=nothing,
    include_disabled::Bool=false,
)
    return VirtualColumnAction[
        action for action in actions
        if include_disabled || virtual_column_action_enabled(action, column, layout; visibility=visibility, pinning=pinning)
    ]
end

function virtual_column_action_records(
    actions::AbstractVector{<:VirtualColumnAction},
    column,
    layout::TableLayoutState;
    visibility=nothing,
    pinning=nothing,
    include_disabled::Bool=true,
)
    identifier = Symbol(column)
    records = NamedTuple[]
    for action in actions
        enabled = virtual_column_action_enabled(action, identifier, layout; visibility=visibility, pinning=pinning)
        include_disabled || enabled || continue
        push!(records, (
            id=action.id,
            label=action.label,
            shortcut=action.shortcut,
            enabled=enabled,
            column=identifier,
        ))
    end
    return records
end

function _find_virtual_column_action(actions::AbstractVector{<:VirtualColumnAction}, action_id)
    identifier = Symbol(action_id)
    index = findfirst(action -> action.id == identifier, actions)
    index === nothing && throw(ArgumentError("unknown virtual column action: $identifier"))
    return actions[index]
end

function _normalized_virtual_action_shortcut(shortcut)
    shortcut === nothing && return nothing
    value = lowercase(strip(string(shortcut)))
    return isempty(value) ? nothing : value
end

function virtual_column_action_for_shortcut(
    actions::AbstractVector{<:VirtualColumnAction},
    shortcut,
    column,
    layout::TableLayoutState;
    visibility=nothing,
    pinning=nothing,
    include_disabled::Bool=false,
)
    target = _normalized_virtual_action_shortcut(shortcut)
    target === nothing && return nothing
    identifier = Symbol(column)
    for action in actions
        _normalized_virtual_action_shortcut(action.shortcut) == target || continue
        include_disabled || virtual_column_action_enabled(action, identifier, layout; visibility=visibility, pinning=pinning) || continue
        return action
    end
    return nothing
end

function invoke_virtual_column_action(
    action::VirtualColumnAction,
    column,
    layout::TableLayoutState;
    visibility=nothing,
    pinning=nothing,
)
    identifier = Symbol(column)
    if !virtual_column_action_enabled(action, identifier, layout; visibility=visibility, pinning=pinning)
        return VirtualColumnActionResult(action.id, action.label, identifier, nothing, false)
    end
    value = _call_column_action(action.handler, identifier, layout, visibility, pinning)
    return VirtualColumnActionResult(action.id, action.label, identifier, value, true)
end

function invoke_virtual_column_action(
    actions::AbstractVector{<:VirtualColumnAction},
    action_id,
    column,
    layout::TableLayoutState;
    visibility=nothing,
    pinning=nothing,
)
    return invoke_virtual_column_action(
        _find_virtual_column_action(actions, action_id),
        column,
        layout;
        visibility=visibility,
        pinning=pinning,
    )
end

function invoke_virtual_column_action_shortcut(
    actions::AbstractVector{<:VirtualColumnAction},
    shortcut,
    column,
    layout::TableLayoutState;
    visibility=nothing,
    pinning=nothing,
)
    action = virtual_column_action_for_shortcut(
        actions,
        shortcut,
        column,
        layout;
        visibility,
        pinning,
    )
    action === nothing && return nothing
    return invoke_virtual_column_action(action, column, layout; visibility, pinning)
end

function virtual_column_action_summary(result::VirtualColumnActionResult)
    return (
        action=result.action,
        label=result.label,
        column=result.column,
        handled=result.handled,
        value=result.value,
    )
end

function virtual_column_action_text(result::VirtualColumnActionResult)
    status = result.handled ? "handled" : "disabled"
    return "column $(result.column) action $(result.action) ($(result.label)): $status value=$(_batch_cell_text(result.value))"
end

function virtual_column_action_markdown(result::VirtualColumnActionResult)
    summary = virtual_column_action_summary(result)
    lines = String[
        "| field | value |",
        "| --- | --- |",
        "| action | $(summary.action) |",
        "| label | $(summary.label) |",
        "| column | $(summary.column) |",
        "| handled | $(summary.handled) |",
        "| value | $(_batch_cell_text(summary.value)) |",
    ]
    return join(lines, "\n")
end

function virtual_column_action_tsv(result::VirtualColumnActionResult)
    return join([
        "action\tlabel\tcolumn\thandled\tvalue",
        "$(result.action)\t$(_batch_cell_text(result.label))\t$(result.column)\t$(result.handled)\t$(_batch_cell_text(result.value))",
    ], "\n")
end

function default_virtual_column_actions(;
    sort::Bool=true,
    clear_filter::Bool=true,
    hide::Bool=true,
    show::Bool=true,
    toggle_visibility::Bool=false,
    pin_left::Bool=true,
    pin_right::Bool=true,
    unpin::Bool=true,
)
    actions = VirtualColumnAction[]
    sort && push!(actions, VirtualColumnAction(
        :sort,
        "Toggle sort";
        handler=(column, layout, visibility) -> (toggle_virtual_sort!(layout, column); virtual_table_query(layout)),
        shortcut="s",
    ))
    clear_filter && push!(actions, VirtualColumnAction(
        :clear_filter,
        "Clear filter";
        handler=(column, layout, visibility) -> (clear_virtual_filter!(layout, column); virtual_table_query(layout)),
        enabled=(column, layout, visibility) -> haskey(layout.filters, column),
        shortcut="f",
    ))
    hide && push!(actions, VirtualColumnAction(
        :hide,
        "Hide column";
        handler=(column, layout, visibility) -> (hide_virtual_column!(visibility, column); column_visibility_snapshot(visibility)),
        enabled=(column, layout, visibility) -> visibility isa ColumnVisibilityState && virtual_column_visible(visibility, column),
        shortcut="h",
    ))
    show && push!(actions, VirtualColumnAction(
        :show,
        "Show column";
        handler=(column, layout, visibility) -> (show_virtual_column!(visibility, column); column_visibility_snapshot(visibility)),
        enabled=(column, layout, visibility) -> visibility isa ColumnVisibilityState && !virtual_column_visible(visibility, column),
    ))
    toggle_visibility && push!(actions, VirtualColumnAction(
        :toggle_visibility,
        "Toggle column visibility";
        handler=(column, layout, visibility) -> (toggle_virtual_column_visibility!(visibility, column); column_visibility_snapshot(visibility)),
        enabled=(column, layout, visibility) -> visibility isa ColumnVisibilityState,
    ))
    pin_left && push!(actions, VirtualColumnAction(
        :pin_left,
        "Pin column left";
        handler=(column, layout, visibility, pinning) -> (pin_virtual_column_left!(pinning, column); column_pin_snapshot(pinning)),
        enabled=(column, layout, visibility, pinning) -> pinning isa ColumnPinState && virtual_column_pin_position(pinning, column) != :left,
    ))
    pin_right && push!(actions, VirtualColumnAction(
        :pin_right,
        "Pin column right";
        handler=(column, layout, visibility, pinning) -> (pin_virtual_column_right!(pinning, column); column_pin_snapshot(pinning)),
        enabled=(column, layout, visibility, pinning) -> pinning isa ColumnPinState && virtual_column_pin_position(pinning, column) != :right,
    ))
    unpin && push!(actions, VirtualColumnAction(
        :unpin,
        "Unpin column";
        handler=(column, layout, visibility, pinning) -> (unpin_virtual_column!(pinning, column); column_pin_snapshot(pinning)),
        enabled=(column, layout, visibility, pinning) -> pinning isa ColumnPinState && virtual_column_pin_position(pinning, column) !== nothing,
    ))
    return actions
end

struct VirtualRowAction{H,E}
    id::Symbol
    label::String
    handler::H
    enabled::E
    shortcut::Union{Nothing,String}
end

function VirtualRowAction(
    id,
    label::AbstractString;
    handler=(item, index, key) -> Symbol(id),
    enabled=true,
    shortcut=nothing,
)
    return VirtualRowAction{typeof(handler),typeof(enabled)}(
        Symbol(id),
        String(label),
        handler,
        enabled,
        shortcut === nothing ? nothing : string(shortcut),
    )
end

struct VirtualRowActionResult
    action::Symbol
    label::String
    item::Any
    index::Int
    key::Any
    value::Any
    handled::Bool
end

struct VirtualRowActionBatchResult
    action::Symbol
    label::String
    results::Vector{VirtualRowActionResult}
    requested::Int
    handled::Int
    disabled::Int
end

function _call_row_action(function_or_value, item, index::Int, key)
    applicable(function_or_value, item, index, key) && return function_or_value(item, index, key)
    applicable(function_or_value, item, index) && return function_or_value(item, index)
    applicable(function_or_value, item) && return function_or_value(item)
    applicable(function_or_value) && return function_or_value()
    return function_or_value
end

function virtual_row_action_enabled(
    action::VirtualRowAction,
    item,
    index::Integer;
    key=nothing,
)
    enabled = _call_row_action(action.enabled, item, Int(index), key)
    enabled isa Bool || throw(ArgumentError("row action enabled value must resolve to Bool"))
    return enabled
end

function virtual_row_action_menu(
    actions::AbstractVector{<:VirtualRowAction},
    item,
    index::Integer;
    key=nothing,
    include_disabled::Bool=false,
)
    return VirtualRowAction[
        action for action in actions
        if include_disabled || virtual_row_action_enabled(action, item, index; key=key)
    ]
end

function virtual_row_action_records(
    actions::AbstractVector{<:VirtualRowAction},
    item,
    index::Integer;
    key=nothing,
    include_disabled::Bool=true,
)
    row_index = Int(index)
    records = NamedTuple[]
    for action in actions
        enabled = virtual_row_action_enabled(action, item, row_index; key=key)
        include_disabled || enabled || continue
        push!(records, (
            id=action.id,
            label=action.label,
            shortcut=action.shortcut,
            enabled=enabled,
            index=row_index,
            key=key,
        ))
    end
    return records
end

function _find_virtual_row_action(actions::AbstractVector{<:VirtualRowAction}, action_id)
    identifier = Symbol(action_id)
    index = findfirst(action -> action.id == identifier, actions)
    index === nothing && throw(ArgumentError("unknown virtual row action: $identifier"))
    return actions[index]
end

function virtual_row_action_for_shortcut(
    actions::AbstractVector{<:VirtualRowAction},
    shortcut,
    item,
    index::Integer;
    key=nothing,
    include_disabled::Bool=false,
)
    target = _normalized_virtual_action_shortcut(shortcut)
    target === nothing && return nothing
    row_index = Int(index)
    for action in actions
        _normalized_virtual_action_shortcut(action.shortcut) == target || continue
        include_disabled || virtual_row_action_enabled(action, item, row_index; key=key) || continue
        return action
    end
    return nothing
end

function invoke_virtual_row_action(
    action::VirtualRowAction,
    item,
    index::Integer;
    key=nothing,
)
    row_index = Int(index)
    if !virtual_row_action_enabled(action, item, row_index; key=key)
        return VirtualRowActionResult(action.id, action.label, item, row_index, key, nothing, false)
    end
    value = _call_row_action(action.handler, item, row_index, key)
    return VirtualRowActionResult(action.id, action.label, item, row_index, key, value, true)
end

function invoke_virtual_row_action(
    actions::AbstractVector{<:VirtualRowAction},
    action_id,
    item,
    index::Integer;
    key=nothing,
)
    return invoke_virtual_row_action(
        _find_virtual_row_action(actions, action_id),
        item,
        index;
        key=key,
    )
end

function invoke_virtual_row_action_shortcut(
    actions::AbstractVector{<:VirtualRowAction},
    shortcut,
    item,
    index::Integer;
    key=nothing,
)
    action = virtual_row_action_for_shortcut(actions, shortcut, item, index; key=key)
    action === nothing && return nothing
    return invoke_virtual_row_action(action, item, index; key=key)
end

function invoke_virtual_row_action_batch(
    action::VirtualRowAction,
    items;
    indices=nothing,
    keys=nothing,
)
    row_items = collect(items)
    row_indices = indices === nothing ? collect(eachindex(row_items)) : Int[Int(index) for index in indices]
    length(row_indices) == length(row_items) ||
        throw(ArgumentError("virtual row action batch indices must match item count"))
    row_keys = keys === nothing ? fill(nothing, length(row_items)) : collect(keys)
    length(row_keys) == length(row_items) ||
        throw(ArgumentError("virtual row action batch keys must match item count"))
    results = VirtualRowActionResult[]
    for position in eachindex(row_items)
        push!(
            results,
            invoke_virtual_row_action(
                action,
                row_items[position],
                row_indices[position];
                key=row_keys[position],
            ),
        )
    end
    handled = count(result -> result.handled, results)
    return VirtualRowActionBatchResult(
        action.id,
        action.label,
        results,
        length(results),
        handled,
        length(results) - handled,
    )
end

function invoke_virtual_row_action_batch(
    actions::AbstractVector{<:VirtualRowAction},
    action_id,
    items;
    indices=nothing,
    keys=nothing,
)
    return invoke_virtual_row_action_batch(
        _find_virtual_row_action(actions, action_id),
        items;
        indices,
        keys,
    )
end

function invoke_virtual_range_row_action_batch(
    action::VirtualRowAction,
    selection::VirtualRangeSelection,
    window::VirtualTableWindow;
    include_unready::Bool=false,
)
    records = virtual_range_selected_row_records(selection, window; include_unready)
    return invoke_virtual_row_action_batch(
        action,
        records;
        indices=(record.index for record in records),
        keys=(record.key for record in records),
    )
end

function invoke_virtual_range_row_action_batch(
    actions::AbstractVector{<:VirtualRowAction},
    action_id,
    selection::VirtualRangeSelection,
    window::VirtualTableWindow;
    include_unready::Bool=false,
)
    return invoke_virtual_range_row_action_batch(
        _find_virtual_row_action(actions, action_id),
        selection,
        window;
        include_unready,
    )
end

function virtual_row_action_batch_records(result::VirtualRowActionBatchResult)
    return [
        (
            action=row.action,
            label=row.label,
            index=row.index,
            key=row.key,
            handled=row.handled,
            value=row.value,
        )
        for row in result.results
    ]
end

function virtual_row_action_batch_summary(result::VirtualRowActionBatchResult)
    return (
        action=result.action,
        label=result.label,
        requested=result.requested,
        handled=result.handled,
        disabled=result.disabled,
        complete=result.requested == result.handled,
    )
end

_batch_cell_text(value) = value === nothing ? "" : replace(string(value), '\t' => ' ', '\n' => ' ')

function virtual_row_action_batch_text(result::VirtualRowActionBatchResult)
    summary = virtual_row_action_batch_summary(result)
    lines = String[
        "action $(summary.action) ($(summary.label)): $(summary.handled)/$(summary.requested) handled, $(summary.disabled) disabled",
    ]
    for record in virtual_row_action_batch_records(result)
        status = record.handled ? "handled" : "disabled"
        push!(lines, "row $(record.index) key=$(_batch_cell_text(record.key)) $status value=$(_batch_cell_text(record.value))")
    end
    return join(lines, "\n")
end

function virtual_row_action_batch_markdown(result::VirtualRowActionBatchResult)
    summary = virtual_row_action_batch_summary(result)
    lines = String[
        "| field | value |",
        "| --- | --- |",
        "| action | $(summary.action) |",
        "| label | $(summary.label) |",
        "| requested | $(summary.requested) |",
        "| handled | $(summary.handled) |",
        "| disabled | $(summary.disabled) |",
        "",
        "| index | key | handled | value |",
        "| --- | --- | --- | --- |",
    ]
    for record in virtual_row_action_batch_records(result)
        push!(
            lines,
            "| $(record.index) | $(_batch_cell_text(record.key)) | $(record.handled) | $(_batch_cell_text(record.value)) |",
        )
    end
    return join(lines, "\n")
end

function virtual_row_action_batch_tsv(result::VirtualRowActionBatchResult)
    lines = String["index\tkey\thandled\tvalue"]
    for record in virtual_row_action_batch_records(result)
        push!(
            lines,
            "$(record.index)\t$(_batch_cell_text(record.key))\t$(record.handled)\t$(_batch_cell_text(record.value))",
        )
    end
    return join(lines, "\n")
end

function _data_query_snapshot(query::DataQuery)
    return (
        sort=[(column=term.column, direction=_sort_direction_symbol(term.direction)) for term in query.sort],
        filters=Dict{Symbol,Any}(column => value for (column, value) in pairs(query.filters)),
        search=query.search,
        revision=query.revision,
    )
end

function data_query_summary(query::DataQuery)
    sort_columns = Symbol[term.column for term in query.sort]
    filter_columns = Symbol[column for column in keys(query.filters)]
    sort!(filter_columns; by=string)
    return (
        revision=query.revision,
        search=query.search,
        has_search=query.search !== nothing && !isempty(query.search),
        sort_count=length(query.sort),
        filter_count=length(query.filters),
        sort_columns=sort_columns,
        filter_columns=filter_columns,
    )
end

function _data_query_sort_text(term::SortTerm)
    return "$(term.column):$(_sort_direction_symbol(term.direction))"
end

function data_query_text(query::DataQuery)
    summary = data_query_summary(query)
    sort_text = isempty(query.sort) ? "" : join((_data_query_sort_text(term) for term in query.sort), ", ")
    filter_text = isempty(query.filters) ? "" :
                  join(("$(column)=$(_batch_cell_text(value))" for (column, value) in sort!(collect(query.filters); by=pair -> string(first(pair)))), ", ")
    return join(String[
        "revision: $(summary.revision)",
        "search: $(_batch_cell_text(summary.search))",
        "sorts: $(summary.sort_count) $sort_text",
        "filters: $(summary.filter_count) $filter_text",
    ], "\n")
end

function data_query_markdown(query::DataQuery)
    summary = data_query_summary(query)
    lines = String[
        "| field | value |",
        "| --- | --- |",
        "| revision | $(summary.revision) |",
        "| search | $(_batch_cell_text(summary.search)) |",
        "| sort_count | $(summary.sort_count) |",
        "| filter_count | $(summary.filter_count) |",
        "",
        "| kind | column | value |",
        "| --- | --- | --- |",
    ]
    for term in query.sort
        push!(lines, "| sort | $(term.column) | $(_sort_direction_symbol(term.direction)) |")
    end
    for (column, value) in sort!(collect(query.filters); by=pair -> string(first(pair)))
        push!(lines, "| filter | $(column) | $(_batch_cell_text(value)) |")
    end
    return join(lines, "\n")
end

function data_query_tsv(query::DataQuery)
    lines = String["kind\tcolumn\tvalue"]
    push!(lines, "summary\trevision\t$(query.revision)")
    push!(lines, "summary\tsearch\t$(_batch_cell_text(query.search))")
    for term in query.sort
        push!(lines, "sort\t$(term.column)\t$(_sort_direction_symbol(term.direction))")
    end
    for (column, value) in sort!(collect(query.filters); by=pair -> string(first(pair)))
        push!(lines, "filter\t$(column)\t$(_batch_cell_text(value))")
    end
    return join(lines, "\n")
end

_action_metadata(action::VirtualColumnAction) = (
    id=action.id,
    label=action.label,
    shortcut=action.shortcut,
)

_action_metadata(action::VirtualRowAction) = (
    id=action.id,
    label=action.label,
    shortcut=action.shortcut,
)

function table_preferences_bundle(
    layout::TableLayoutState;
    visibility=nothing,
    pinning=nothing,
    column_actions=VirtualColumnAction[],
    row_actions=VirtualRowAction[],
)
    return (
        layout=table_layout_snapshot(layout),
        query=_data_query_snapshot(virtual_table_query(layout)),
        visibility=visibility isa ColumnVisibilityState ? column_visibility_snapshot(visibility) : nothing,
        pinning=pinning isa ColumnPinState ? column_pin_snapshot(pinning) : nothing,
        column_actions=[_action_metadata(action) for action in column_actions],
        row_actions=[_action_metadata(action) for action in row_actions],
    )
end

function restore_table_preferences!(
    layout::TableLayoutState,
    bundle;
    visibility=nothing,
    pinning=nothing,
)
    layout_snapshot = _snapshot_value(bundle, :layout, nothing)
    layout_snapshot === nothing || restore_table_layout!(layout, layout_snapshot)
    visibility_snapshot = _snapshot_value(bundle, :visibility, nothing)
    if visibility isa ColumnVisibilityState && visibility_snapshot !== nothing
        restore_column_visibility!(visibility, visibility_snapshot)
    end
    pin_snapshot = _snapshot_value(bundle, :pinning, nothing)
    if pinning isa ColumnPinState && pin_snapshot !== nothing
        restore_column_pin!(pinning, pin_snapshot)
    end
    return (layout=layout, visibility=visibility, pinning=pinning)
end

function apply_table_preferences(
    columns::AbstractVector{<:VirtualTableColumn},
    layout::TableLayoutState;
    visibility=nothing,
    pinning=nothing,
)
    laid_out = apply_virtual_table_layout(columns, layout)
    visible = visibility isa ColumnVisibilityState ?
              visible_virtual_columns(laid_out, visibility) :
              laid_out
    return pinning isa ColumnPinState ?
           pinned_virtual_columns(visible, pinning) :
           visible
end

function table_preferences_summary(bundle)
    layout = _snapshot_value(bundle, :layout, NamedTuple())
    query = _snapshot_value(bundle, :query, NamedTuple())
    visibility = _snapshot_value(bundle, :visibility, nothing)
    pinning = _snapshot_value(bundle, :pinning, nothing)
    order = _snapshot_value(layout, :order, Symbol[])
    widths = _snapshot_value(layout, :widths, Dict())
    sort = _snapshot_value(layout, :sort, ())
    filters = _snapshot_value(layout, :filters, Dict())
    hidden = visibility === nothing ? Symbol[] : _snapshot_value(visibility, :hidden, Symbol[])
    left = pinning === nothing ? Symbol[] : _snapshot_value(pinning, :left, Symbol[])
    right = pinning === nothing ? Symbol[] : _snapshot_value(pinning, :right, Symbol[])
    column_actions = _snapshot_value(bundle, :column_actions, ())
    row_actions = _snapshot_value(bundle, :row_actions, ())
    return (
        column_count=length(order),
        width_count=length(widths),
        sort_count=length(sort),
        filter_count=length(filters),
        search=_snapshot_value(query, :search, _snapshot_value(layout, :search, nothing)),
        query_revision=_snapshot_value(query, :revision, _snapshot_value(layout, :query_revision, nothing)),
        hidden_count=length(hidden),
        pinned_left_count=length(left),
        pinned_right_count=length(right),
        column_action_count=length(column_actions),
        row_action_count=length(row_actions),
    )
end

function table_preferences_text(bundle)
    summary = table_preferences_summary(bundle)
    return join(String[
        "columns: $(summary.column_count)",
        "widths: $(summary.width_count)",
        "sorts: $(summary.sort_count)",
        "filters: $(summary.filter_count)",
        "search: $(_batch_cell_text(summary.search))",
        "query revision: $(_batch_cell_text(summary.query_revision))",
        "hidden columns: $(summary.hidden_count)",
        "pinned left: $(summary.pinned_left_count)",
        "pinned right: $(summary.pinned_right_count)",
        "column actions: $(summary.column_action_count)",
        "row actions: $(summary.row_action_count)",
    ], "\n")
end

function table_preferences_markdown(bundle)
    summary = table_preferences_summary(bundle)
    rows = [
        (:column_count, summary.column_count),
        (:width_count, summary.width_count),
        (:sort_count, summary.sort_count),
        (:filter_count, summary.filter_count),
        (:search, summary.search),
        (:query_revision, summary.query_revision),
        (:hidden_count, summary.hidden_count),
        (:pinned_left_count, summary.pinned_left_count),
        (:pinned_right_count, summary.pinned_right_count),
        (:column_action_count, summary.column_action_count),
        (:row_action_count, summary.row_action_count),
    ]
    lines = String["| field | value |", "| --- | --- |"]
    append!(lines, "| $(field) | $(_batch_cell_text(value)) |" for (field, value) in rows)
    return join(lines, "\n")
end

function table_preferences_tsv(bundle)
    summary = table_preferences_summary(bundle)
    rows = [
        (:column_count, summary.column_count),
        (:width_count, summary.width_count),
        (:sort_count, summary.sort_count),
        (:filter_count, summary.filter_count),
        (:search, summary.search),
        (:query_revision, summary.query_revision),
        (:hidden_count, summary.hidden_count),
        (:pinned_left_count, summary.pinned_left_count),
        (:pinned_right_count, summary.pinned_right_count),
        (:column_action_count, summary.column_action_count),
        (:row_action_count, summary.row_action_count),
    ]
    lines = String["field\tvalue"]
    append!(lines, "$(field)\t$(_batch_cell_text(value))" for (field, value) in rows)
    return join(lines, "\n")
end

function set_virtual_column_width!(
    state::TableLayoutState,
    column,
    width::Integer;
    minimum::Integer=1,
    maximum::Integer=10_000,
)
    minimum > 0 || throw(ArgumentError("minimum column width must be positive"))
    maximum >= minimum || throw(ArgumentError("maximum column width is below minimum"))
    identifier = Symbol(column)
    state.widths[identifier] = clamp(Int(width), Int(minimum), Int(maximum))
    identifier in state.order || push!(state.order, identifier)
    return state
end

function reorder_virtual_column!(state::TableLayoutState, column, destination::Integer)
    identifier = Symbol(column)
    index = findfirst(==(identifier), state.order)
    index === nothing && throw(ArgumentError("unknown virtual table column: $identifier"))
    target = clamp(Int(destination), 1, length(state.order))
    deleteat!(state.order, index)
    insert!(state.order, target, identifier)
    return state
end

function apply_virtual_table_layout(
    columns::AbstractVector{<:VirtualTableColumn},
    state::TableLayoutState,
)
    by_id = Dict(column.id => column for column in columns)
    ordered_ids = Symbol[id for id in state.order if haskey(by_id, id)]
    append!(ordered_ids, (column.id for column in columns if !(column.id in ordered_ids)))
    return VirtualTableColumn[
        VirtualTableColumn(
            id,
            by_id[id].title;
            width=get(state.widths, id, by_id[id].width),
            accessor=by_id[id].accessor,
            alignment=by_id[id].alignment,
        ) for id in ordered_ids
    ]
end

mutable struct ColumnResizeSession
    column::Symbol
    pointer_start::Int
    width_start::Int
    current_width::Int
    active::Bool
end

function begin_virtual_column_resize(
    state::TableLayoutState,
    column,
    pointer_column::Integer,
)
    identifier = Symbol(column)
    width = get(state.widths, identifier, nothing)
    width === nothing && throw(ArgumentError("unknown virtual table column: $identifier"))
    return ColumnResizeSession(identifier, Int(pointer_column), width, width, true)
end

function update_virtual_column_resize!(
    state::TableLayoutState,
    session::ColumnResizeSession,
    pointer_column::Integer;
    minimum::Integer=1,
    maximum::Integer=10_000,
)
    session.active || throw(ArgumentError("column resize session is inactive"))
    delta = big(pointer_column) - session.pointer_start
    width = Int(clamp(big(session.width_start) + delta, big(minimum), big(maximum)))
    session.current_width = width
    set_virtual_column_width!(state, session.column, width; minimum=minimum, maximum=maximum)
    return width
end

finish_virtual_column_resize!(session::ColumnResizeSession) =
    (session.active = false; session.current_width)

function cancel_virtual_column_resize!(state::TableLayoutState, session::ColumnResizeSession)
    session.active || return state
    state.widths[session.column] = session.width_start
    session.current_width = session.width_start
    session.active = false
    return state
end

function _bump_query!(state::TableLayoutState)
    state.query_revision == typemax(UInt64) && throw(OverflowError("table query revision overflow"))
    state.query_revision += 1
    return state
end

function toggle_virtual_sort!(
    state::TableLayoutState,
    column;
    additive::Bool=false,
)
    identifier = Symbol(column)
    index = findfirst(term -> term.column == identifier, state.sort)
    existing = index === nothing ? nothing : state.sort[index]
    next_direction = existing === nothing ? AscendingSort :
                     existing.direction == AscendingSort ? DescendingSort : nothing
    if additive
        index === nothing || deleteat!(state.sort, index)
    else
        empty!(state.sort)
    end
    next_direction === nothing || push!(state.sort, SortTerm(identifier, next_direction))
    _bump_query!(state)
    return state
end

function set_virtual_filter!(state::TableLayoutState, column, value)
    state.filters[Symbol(column)] = value
    _bump_query!(state)
    return state
end

function clear_virtual_filter!(state::TableLayoutState, column)
    pop!(state.filters, Symbol(column), nothing)
    _bump_query!(state)
    return state
end

function set_virtual_search!(state::TableLayoutState, value)
    state.search = value === nothing ? nothing : String(value)
    _bump_query!(state)
    return state
end

virtual_table_query(state::TableLayoutState) = DataQuery(
    sort=state.sort,
    filters=state.filters,
    search=state.search,
    revision=state.query_revision,
)

function apply_virtual_table_query!(
    source,
    state::TableLayoutState;
    total_length=nothing,
)
    query = virtual_table_query(state)
    if total_length === nothing
        return set_data_query!(source, query)
    end
    return set_data_query!(source, query; total_length=total_length)
end

function virtual_table_column_at(
    columns::AbstractVector{<:VirtualTableColumn},
    cell_column::Integer;
    separator_width::Integer=3,
)
    cell_column > 0 || return nothing
    separator_width >= 0 || throw(ArgumentError("separator width cannot be negative"))
    cursor = 1
    for column in columns
        stop = cursor + column.width - 1
        cursor <= cell_column <= stop && return column.id
        cursor = stop + Int(separator_width) + 1
    end
    return nothing
end

end
