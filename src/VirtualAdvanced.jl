module VirtualAdvanced

using ..Virtualization: ReadySlot,
                        EndSlot,
                        VirtualListState,
                        VirtualListWindow,
                        VirtualTableColumn,
                        ensure_virtual_cursor_visible!,
                        SortDirection,
                        AscendingSort,
                        DescendingSort,
                        SortTerm,
                        DataQuery

export VirtualRangeSelection,
       RangeSelectionResult,
       begin_virtual_range_selection,
       apply_virtual_range_selection!,
       cancel_virtual_range_selection!,
       VirtualTypeAhead,
       push_virtual_typeahead!,
       backspace_virtual_typeahead!,
       clear_virtual_typeahead!,
       apply_virtual_typeahead!,
       TableLayoutState,
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
