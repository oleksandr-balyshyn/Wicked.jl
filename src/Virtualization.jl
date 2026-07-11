module Virtualization

export AbstractDataSource,
       data_length,
       data_version,
       item_key,
       fetch_items,
       VectorDataSource,
       replace_data!,
       append_data!,
       splice_data!,
       CallbackDataSource,
       PageResult,
       DataRequestToken,
       data_request_cancelled,
       SortDirection,
       AscendingSort,
       DescendingSort,
       SortTerm,
       DataQuery,
       PageStatus,
       IdlePage,
       LoadingPage,
       ReadyPage,
       FailedPage,
       DataSlotKind,
       ReadySlot,
       LoadingSlot,
       FailedSlot,
       EndSlot,
       DataSlot,
       PagedDataSource,
       request_items!,
       retry_page!,
       cancel_data_requests!,
       poll_data_updates!,
       invalidate_data!,
       set_data_query!,
       fetch_slots,
       page_cache_size,
       inflight_page_count,
       VirtualViewport,
       visible_range,
       VirtualListState,
       VirtualListWindow,
       refresh_virtual_list!,
       resize_virtual_list!,
       scroll_virtual_list!,
       move_virtual_cursor!,
       select_virtual_index!,
       toggle_virtual_selection!,
       clear_virtual_selection!,
       ensure_virtual_cursor_visible!,
       reconcile_virtual_selection!,
       VirtualTableColumn,
       VirtualTableCell,
       VirtualTableRow,
       VirtualTableWindow,
       project_virtual_table

abstract type AbstractDataSource{T,K} end

data_length(::AbstractDataSource) = throw(MethodError(data_length, ()))
data_version(::AbstractDataSource) = UInt64(0)
item_key(::AbstractDataSource, item, index::Integer) = index
fetch_items(::AbstractDataSource, range::UnitRange{Int}) =
    throw(MethodError(fetch_items, (range,)))

mutable struct VectorDataSource{T,K,F} <: AbstractDataSource{T,K}
    items::Vector{T}
    key_function::F
    version::UInt64
    mutex::ReentrantLock
end

function VectorDataSource(
    items::AbstractVector{T};
    key=(item, index) -> index,
) where {T}
    values = Vector{T}(items)
    key_type = isempty(values) ? Any : typeof(key(first(values), 1))
    return VectorDataSource{T,key_type,typeof(key)}(values, key, 1, ReentrantLock())
end

data_length(source::VectorDataSource) = lock(source.mutex) do
    length(source.items)
end

data_version(source::VectorDataSource) = lock(source.mutex) do
    source.version
end

item_key(source::VectorDataSource, item, index::Integer) = source.key_function(item, Int(index))

function fetch_items(source::VectorDataSource{T}, range::UnitRange{Int}) where {T}
    return lock(source.mutex) do
        isempty(range) && return T[]
        first_index = clamp(first(range), 1, length(source.items) + 1)
        stop_index = clamp(last(range), 0, length(source.items))
        first_index > stop_index && return T[]
        return copy(@view source.items[first_index:stop_index])
    end
end

function replace_data!(source::VectorDataSource{T}, items::AbstractVector{T}) where {T}
    lock(source.mutex) do
        source.items = Vector{T}(items)
        source.version += 1
    end
    return source
end

function append_data!(source::VectorDataSource{T}, items::AbstractVector{T}) where {T}
    lock(source.mutex) do
        append!(source.items, items)
        source.version += 1
    end
    return source
end

function splice_data!(
    source::VectorDataSource{T},
    range::UnitRange{Int},
    replacement::AbstractVector{T}=T[],
) where {T}
    lock(source.mutex) do
        splice!(source.items, range, replacement)
        source.version += 1
    end
    return source
end

struct CallbackDataSource{T,K,L,V,F,I} <: AbstractDataSource{T,K}
    length_function::L
    version_function::V
    fetch_function::F
    key_function::I
end

function CallbackDataSource{T,K}(;
    length,
    fetch,
    key=(item, index) -> index,
    version=() -> UInt64(0),
) where {T,K}
    return CallbackDataSource{T,K,typeof(length),typeof(version),typeof(fetch),typeof(key)}(
        length,
        version,
        fetch,
        key,
    )
end

data_length(source::CallbackDataSource) = source.length_function()
data_version(source::CallbackDataSource) = UInt64(source.version_function())
item_key(source::CallbackDataSource, item, index::Integer) = source.key_function(item, Int(index))

function fetch_items(source::CallbackDataSource{T}, range::UnitRange{Int}) where {T}
    return Vector{T}(source.fetch_function(range))
end

struct PageResult{T}
    items::Vector{T}
    total_length::Union{Nothing,Int}
    complete::Bool

    function PageResult(
        items::AbstractVector{T};
        total_length::Union{Nothing,Integer}=nothing,
        complete::Bool=false,
    ) where {T}
        total_length !== nothing && total_length < 0 && throw(ArgumentError("total data length cannot be negative"))
        new{T}(
            Vector{T}(items),
            total_length === nothing ? nothing : Int(total_length),
            complete,
        )
    end
end

"""Cooperative cancellation state passed to five-argument page loaders."""
struct DataRequestToken
    cancelled::Threads.Atomic{Bool}
end

DataRequestToken() = DataRequestToken(Threads.Atomic{Bool}(false))
data_request_cancelled(token::DataRequestToken) = token.cancelled[]
_cancel_data_request!(token::DataRequestToken) = (token.cancelled[] = true; token)

@enum SortDirection begin
    AscendingSort
    DescendingSort
end

struct SortTerm
    column::Symbol
    direction::SortDirection
end

struct DataQuery
    sort::Vector{SortTerm}
    filters::Dict{Symbol,Any}
    search::Union{Nothing,String}
    revision::UInt64

    function DataQuery(;
        sort=SortTerm[],
        filters=Dict{Symbol,Any}(),
        search::Union{Nothing,AbstractString}=nothing,
        revision::Integer=0,
    )
        revision >= 0 || throw(ArgumentError("query revision cannot be negative"))
        new(
            SortTerm[term for term in sort],
            Dict{Symbol,Any}(Symbol(key) => value for (key, value) in pairs(filters)),
            search === nothing ? nothing : String(search),
            UInt64(revision),
        )
    end
end

@enum PageStatus begin
    IdlePage
    LoadingPage
    ReadyPage
    FailedPage
end

mutable struct PageRecord{T}
    status::PageStatus
    items::Vector{T}
    error::Any
    generation::UInt64
    last_access::UInt64
    token::DataRequestToken
end

struct PageCompletion{T}
    page::Int
    generation::UInt64
    result::Union{Nothing,PageResult{T}}
    error::Any
end

@enum DataSlotKind begin
    ReadySlot
    LoadingSlot
    FailedSlot
    EndSlot
end

struct DataSlot{T,K}
    index::Int
    kind::DataSlotKind
    key::Union{Nothing,K}
    item::Union{Nothing,T}
    error::Any
end

mutable struct PagedDataSource{T,K,F,I} <: AbstractDataSource{T,K}
    loader::F
    key_function::I
    page_size::Int
    max_cached_pages::Int
    max_inflight_pages::Int
    total_length::Union{Nothing,Int}
    query::DataQuery
    generation::UInt64
    access_clock::UInt64
    pages::Dict{Int,PageRecord{T}}
    completions::Channel{PageCompletion{T}}
    tasks::Set{Task}
    mutex::ReentrantLock
end

function PagedDataSource{T,K}(
    loader;
    key=(item, index) -> index,
    page_size::Integer=100,
    max_cached_pages::Integer=32,
    max_inflight_pages::Integer=4,
    total_length::Union{Nothing,Integer}=nothing,
    query::DataQuery=DataQuery(),
) where {T,K}
    page_size > 0 || throw(ArgumentError("page size must be positive"))
    max_cached_pages > 0 || throw(ArgumentError("page cache size must be positive"))
    max_inflight_pages > 0 || throw(ArgumentError("maximum in-flight pages must be positive"))
    total_length !== nothing && total_length < 0 && throw(ArgumentError("total data length cannot be negative"))
    return PagedDataSource{T,K,typeof(loader),typeof(key)}(
        loader,
        key,
        Int(page_size),
        Int(max_cached_pages),
        Int(max_inflight_pages),
        total_length === nothing ? nothing : Int(total_length),
        query,
        1,
        0,
        Dict{Int,PageRecord{T}}(),
        Channel{PageCompletion{T}}(max(16, Int(max_cached_pages) * 2)),
        Set{Task}(),
        ReentrantLock(),
    )
end

data_length(source::PagedDataSource) = lock(source.mutex) do
    source.total_length
end

data_version(source::PagedDataSource) = lock(source.mutex) do
    source.generation
end

item_key(source::PagedDataSource, item, index::Integer) = source.key_function(item, Int(index))

function _normalize_page_result(::Type{T}, value) where {T}
    value isa PageResult{T} && return value
    value isa AbstractVector && return PageResult(Vector{T}(value))
    throw(ArgumentError("page loader must return PageResult{$T} or a vector"))
end

function _start_page!(source::PagedDataSource{T}, page::Int) where {T}
    generation = source.generation
    query = DataQuery(
        sort=copy(source.query.sort),
        filters=copy(source.query.filters),
        search=source.query.search,
        revision=source.query.revision,
    )
    token = DataRequestToken()
    source.access_clock += 1
    source.pages[page] = PageRecord{T}(
        LoadingPage,
        T[],
        nothing,
        generation,
        source.access_clock,
        token,
    )
    task = @async begin
        completion = try
            value = if applicable(
                source.loader,
                page,
                source.page_size,
                generation,
                query,
                token,
            )
                source.loader(page, source.page_size, generation, query, token)
            elseif applicable(source.loader, page, source.page_size, generation, query)
                source.loader(page, source.page_size, generation, query)
            else
                source.loader(page, source.page_size, generation)
            end
            PageCompletion{T}(page, generation, _normalize_page_result(T, value), nothing)
        catch error
            PageCompletion{T}(page, generation, nothing, (error, catch_backtrace()))
        end
        put!(source.completions, completion)
    end
    push!(source.tasks, task)
    return task
end

function _inflight_page_count(source::PagedDataSource)
    return count(record -> record.status == LoadingPage, values(source.pages))
end

inflight_page_count(source::PagedDataSource) = lock(source.mutex) do
    _inflight_page_count(source)
end

function request_items!(source::PagedDataSource, range::UnitRange{Int})
    isempty(range) && return Int[]
    first(range) > 0 || throw(ArgumentError("data range must use positive indices"))
    return lock(source.mutex) do
        total = source.total_length
        total !== nothing && first(range) > total && return Int[]
        stop_index = total === nothing ? last(range) : min(last(range), total)
        first_page = div(first(range) - 1, source.page_size) + 1
        last_page = div(max(first(range), stop_index) - 1, source.page_size) + 1
        requested = Int[]
        inflight = _inflight_page_count(source)
        for page in first_page:last_page
            record = get(source.pages, page, nothing)
            if record === nothing || record.status == IdlePage ||
               (record.status == FailedPage && record.generation != source.generation)
                inflight >= source.max_inflight_pages && continue
                _start_page!(source, page)
                push!(requested, page)
                inflight += 1
            elseif record !== nothing
                source.access_clock += 1
                record.last_access = source.access_clock
            end
        end
        return requested
    end
end

function retry_page!(source::PagedDataSource, page::Integer)
    page > 0 || throw(ArgumentError("page number must be positive"))
    return lock(source.mutex) do
        record = get(source.pages, Int(page), nothing)
        record === nothing && return false
        record.status == FailedPage || return false
        _inflight_page_count(source) < source.max_inflight_pages || return false
        delete!(source.pages, Int(page))
        _start_page!(source, Int(page))
        return true
    end
end

function _evict_pages!(source::PagedDataSource)
    ready = Pair{Int,UInt64}[
        page => record.last_access for (page, record) in source.pages
        if record.status != LoadingPage
    ]
    sort!(ready; by=last)
    while length(ready) > source.max_cached_pages
        page = popfirst!(ready).first
        delete!(source.pages, page)
    end
    return source
end


function cancel_data_requests!(source::PagedDataSource)
    lock(source.mutex) do
        source.generation == typemax(UInt64) && throw(OverflowError("data generation overflow"))
        source.generation += 1
        for (page, record) in collect(source.pages)
            if record.status == LoadingPage
                _cancel_data_request!(record.token)
                delete!(source.pages, page)
            else
                record.generation = source.generation
            end
        end
    end
    return source
end

function poll_data_updates!(source::PagedDataSource{T}; limit::Integer=typemax(Int)) where {T}
    limit >= 0 || throw(ArgumentError("poll limit cannot be negative"))
    applied = 0
    while applied < limit && isready(source.completions)
        completion = take!(source.completions)
        lock(source.mutex) do
            filter!(task -> !istaskdone(task), source.tasks)
            completion.generation == source.generation || return
            record = get(source.pages, completion.page, nothing)
            record === nothing && return
            record.generation == completion.generation || return
            source.access_clock += 1
            if completion.error === nothing
                result = completion.result::PageResult{T}
                record.status = ReadyPage
                record.items = result.items
                record.error = nothing
                record.last_access = source.access_clock
                result.total_length !== nothing && (source.total_length = result.total_length)
                if result.complete && result.total_length === nothing
                    source.total_length = (completion.page - 1) * source.page_size + length(result.items)
                end
            else
                record.status = FailedPage
                record.error = completion.error
                record.last_access = source.access_clock
            end
            _evict_pages!(source)
        end
        applied += 1
    end
    return applied
end

struct KeepDataLength end
const KEEP_DATA_LENGTH = KeepDataLength()

function invalidate_data!(source::PagedDataSource; total_length=KEEP_DATA_LENGTH)
    lock(source.mutex) do
        replacement_length = if total_length isa KeepDataLength
            source.total_length
        elseif total_length === nothing
            nothing
        elseif total_length isa Integer && total_length >= 0
            Int(total_length)
        else
            throw(ArgumentError("total data length must be nothing or a nonnegative integer"))
        end
        source.generation == typemax(UInt64) && throw(OverflowError("data generation overflow"))
        source.generation += 1
        source.total_length = replacement_length
        for record in values(source.pages)
            record.status == LoadingPage && _cancel_data_request!(record.token)
        end
        empty!(source.pages)
    end
    return source
end

function set_data_query!(source::PagedDataSource, query::DataQuery; total_length=nothing)
    total_length === nothing ||
        (total_length isa Integer && total_length >= 0) ||
        throw(ArgumentError("query total length must be nothing or a nonnegative integer"))
    lock(source.mutex) do
        source.generation == typemax(UInt64) && throw(OverflowError("data generation overflow"))
        source.query = query
        source.generation += 1
        source.total_length = total_length === nothing ? nothing : Int(total_length)
        for record in values(source.pages)
            record.status == LoadingPage && _cancel_data_request!(record.token)
        end
        empty!(source.pages)
    end
    return source
end

page_cache_size(source::PagedDataSource) = lock(source.mutex) do
    length(source.pages)
end

function _slot(source::PagedDataSource{T,K}, index::Int) where {T,K}
    total = source.total_length
    total !== nothing && index > total && return DataSlot{T,K}(index, EndSlot, nothing, nothing, nothing)
    page = div(index - 1, source.page_size) + 1
    offset = mod(index - 1, source.page_size) + 1
    record = get(source.pages, page, nothing)
    record === nothing && return DataSlot{T,K}(index, LoadingSlot, nothing, nothing, nothing)
    if record.status == FailedPage
        return DataSlot{T,K}(index, FailedSlot, nothing, nothing, record.error)
    elseif record.status != ReadyPage
        return DataSlot{T,K}(index, LoadingSlot, nothing, nothing, nothing)
    elseif offset > length(record.items)
        return DataSlot{T,K}(index, EndSlot, nothing, nothing, nothing)
    end
    item = record.items[offset]
    return DataSlot{T,K}(index, ReadySlot, item_key(source, item, index), item, nothing)
end

function fetch_slots(source::PagedDataSource{T,K}, range::UnitRange{Int}; request::Bool=true) where {T,K}
    request && request_items!(source, range)
    return lock(source.mutex) do
        DataSlot{T,K}[_slot(source, index) for index in range]
    end
end

function fetch_slots(source::AbstractDataSource{T,K}, range::UnitRange{Int}; request::Bool=true) where {T,K}
    isempty(range) && return DataSlot{T,K}[]
    first(range) > 0 || throw(ArgumentError("data range must use positive indices"))
    total_value = data_length(source)
    total_value isa Integer || throw(ArgumentError("synchronous data source length must be an integer"))
    total = Int(total_value)
    total >= 0 || throw(ArgumentError("data source length cannot be negative"))
    available_start = first(range)
    available_stop = min(last(range), total)
    available_range = available_start:available_stop
    items = available_start <= available_stop ? fetch_items(source, available_range) : T[]
    length(items) == length(available_range) ||
        throw(ArgumentError("synchronous data source returned an unexpected item count"))
    result = DataSlot{T,K}[]
    for index in range
        if index > total
            push!(result, DataSlot{T,K}(index, EndSlot, nothing, nothing, nothing))
        else
            item = items[index - available_start + 1]
            push!(result, DataSlot{T,K}(index, ReadySlot, item_key(source, item, index), item, nothing))
        end
    end
    return result
end

struct VirtualViewport
    first_index::Int
    viewport_size::Int
    overscan::Int

    function VirtualViewport(
        first_index::Integer=1,
        viewport_size::Integer=0;
        overscan::Integer=5,
    )
        first_index > 0 || throw(ArgumentError("first virtual index must be positive"))
        viewport_size >= 0 || throw(ArgumentError("virtual viewport size cannot be negative"))
        overscan >= 0 || throw(ArgumentError("virtual overscan cannot be negative"))
        new(Int(first_index), Int(viewport_size), Int(overscan))
    end
end

function _bounded_add(value::Integer, delta::Integer, lower::Int, upper::Int)
    result = clamp(big(value) + big(delta), big(lower), big(upper))
    return Int(result)
end

function visible_range(viewport::VirtualViewport, total_length::Union{Nothing,Integer}=nothing)
    first_index = max(1, viewport.first_index - viewport.overscan)
    stop_index = _bounded_add(
        viewport.first_index,
        big(viewport.viewport_size) + viewport.overscan - 1,
        0,
        typemax(Int),
    )
    total_length !== nothing && (stop_index = min(stop_index, Int(total_length)))
    return first_index:stop_index
end

mutable struct VirtualListState{K}
    viewport::VirtualViewport
    cursor::Union{Nothing,Int}
    selected::Set{K}
    anchor::Union{Nothing,Int}
    multiple::Bool
end

function VirtualListState{K}(;
    first_index::Integer=1,
    viewport_size::Integer=0,
    overscan::Integer=5,
    multiple::Bool=false,
) where {K}
    return VirtualListState{K}(
        VirtualViewport(first_index, viewport_size; overscan=overscan),
        nothing,
        Set{K}(),
        nothing,
        multiple,
    )
end

struct VirtualListWindow{T,K}
    slots::Vector{DataSlot{T,K}}
    first_visible::Int
    last_visible::Int
    total_length::Union{Nothing,Int}
    version::UInt64
end

function resize_virtual_list!(state::VirtualListState, viewport_size::Integer)
    state.viewport = VirtualViewport(
        state.viewport.first_index,
        viewport_size;
        overscan=state.viewport.overscan,
    )
    return state
end

function scroll_virtual_list!(
    state::VirtualListState,
    delta::Integer;
    total_length::Union{Nothing,Integer}=nothing,
)
    maximum_first = total_length === nothing ? typemax(Int) : max(1, Int(total_length) - state.viewport.viewport_size + 1)
    first_index = _bounded_add(state.viewport.first_index, delta, 1, maximum_first)
    state.viewport = VirtualViewport(first_index, state.viewport.viewport_size; overscan=state.viewport.overscan)
    return state
end

function move_virtual_cursor!(
    state::VirtualListState,
    delta::Integer;
    total_length::Union{Nothing,Integer}=nothing,
)
    if total_length !== nothing && total_length == 0
        state.cursor = nothing
        return state
    end
    current = something(state.cursor, state.viewport.first_index)
    maximum_index = total_length === nothing ? typemax(Int) : max(1, Int(total_length))
    state.cursor = _bounded_add(current, delta, 1, maximum_index)
    return state
end

function ensure_virtual_cursor_visible!(state::VirtualListState; total_length=nothing)
    state.cursor === nothing && return state
    first_index = state.viewport.first_index
    stop_index = first_index + max(0, state.viewport.viewport_size - 1)
    if state.cursor < first_index
        scroll_virtual_list!(state, state.cursor - first_index; total_length=total_length)
    elseif state.cursor > stop_index
        scroll_virtual_list!(state, state.cursor - stop_index; total_length=total_length)
    end
    return state
end

function select_virtual_index!(state::VirtualListState{K}, slot::DataSlot{T,K}) where {T,K}
    slot.kind == ReadySlot || return false
    key = slot.key::K
    state.multiple || empty!(state.selected)
    push!(state.selected, key)
    state.cursor = slot.index
    state.anchor = slot.index
    return true
end

function toggle_virtual_selection!(state::VirtualListState{K}, slot::DataSlot{T,K}) where {T,K}
    slot.kind == ReadySlot || return false
    key = slot.key::K
    if key in state.selected
        delete!(state.selected, key)
    else
        state.multiple || empty!(state.selected)
        push!(state.selected, key)
    end
    state.cursor = slot.index
    state.anchor = slot.index
    return true
end

clear_virtual_selection!(state::VirtualListState) = (empty!(state.selected); state.anchor = nothing; state)

function reconcile_virtual_selection!(state::VirtualListState{K}, known_keys) where {K}
    intersect!(state.selected, Set{K}(known_keys))
    return state
end

function refresh_virtual_list!(
    source::PagedDataSource{T,K},
    state::VirtualListState{K};
    poll_limit::Integer=typemax(Int),
) where {T,K}
    poll_data_updates!(source; limit=poll_limit)
    total = data_length(source)
    range = visible_range(state.viewport, total)
    slots = fetch_slots(source, range)
    first_visible = state.viewport.first_index
    unbounded_last = _bounded_add(first_visible, state.viewport.viewport_size - 1, 0, typemax(Int))
    last_visible = total === nothing ? unbounded_last : min(total, unbounded_last)
    return VirtualListWindow{T,K}(slots, first_visible, last_visible, total, data_version(source))
end

function refresh_virtual_list!(
    source::AbstractDataSource{T,K},
    state::VirtualListState{K};
    poll_limit::Integer=typemax(Int),
) where {T,K}
    total_value = data_length(source)
    total_value isa Integer || throw(ArgumentError("synchronous data source length must be an integer"))
    total = Int(total_value)
    range = visible_range(state.viewport, total)
    slots = fetch_slots(source, range; request=false)
    first_visible = state.viewport.first_index
    unbounded_last = _bounded_add(first_visible, state.viewport.viewport_size - 1, 0, typemax(Int))
    last_visible = min(total, unbounded_last)
    return VirtualListWindow{T,K}(slots, first_visible, last_visible, total, data_version(source))
end

struct VirtualTableColumn{F}
    id::Symbol
    title::String
    width::Int
    accessor::F
    alignment::Symbol

    function VirtualTableColumn(
        id,
        title::AbstractString;
        width::Integer=12,
        accessor=identity,
        alignment::Symbol=:left,
    )
        width > 0 || throw(ArgumentError("virtual table column width must be positive"))
        alignment in (:left, :center, :right) || throw(ArgumentError("unsupported column alignment"))
        new{typeof(accessor)}(Symbol(id), String(title), Int(width), accessor, alignment)
    end
end

struct VirtualTableCell
    column::Symbol
    value::String
    width::Int
    alignment::Symbol
end

struct VirtualTableRow{K}
    index::Int
    key::Union{Nothing,K}
    kind::DataSlotKind
    cells::Vector{VirtualTableCell}
    error::Any
end

struct VirtualTableWindow{K}
    columns::Vector{VirtualTableColumn}
    rows::Vector{VirtualTableRow{K}}
    first_visible::Int
    last_visible::Int
    total_length::Union{Nothing,Int}
end

function project_virtual_table(
    window::VirtualListWindow{T,K},
    columns::AbstractVector{<:VirtualTableColumn};
    format=(value, column) -> string(value),
) where {T,K}
    projected_columns = VirtualTableColumn[column for column in columns]
    rows = VirtualTableRow{K}[]
    for slot in window.slots
        cells = VirtualTableCell[]
        if slot.kind == ReadySlot
            for column in projected_columns
                value = column.accessor(slot.item)
                push!(cells, VirtualTableCell(column.id, string(format(value, column)), column.width, column.alignment))
            end
        end
        push!(rows, VirtualTableRow{K}(slot.index, slot.key, slot.kind, cells, slot.error))
    end
    return VirtualTableWindow{K}(
        projected_columns,
        rows,
        window.first_visible,
        window.last_visible,
        window.total_length,
    )
end

end
