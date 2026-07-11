struct Padding{W}
    child::W
    margin::Margin
end

function _container_total_gap(extent::Int, gap::Int, count::Int)
    slots = max(0, count - 1)
    slots == 0 && return 0
    gap > div(extent, slots) && return extent
    return gap * slots
end

Padding(child; margin::Margin=Margin(1)) = Padding(child, margin)

function render!(buffer::Buffer, widget::Padding, area::Rect)
    render!(buffer, widget.child, inset(area, widget.margin))
end

function measure(widget::Padding, available::Rect)
    active = inset(available, widget.margin)
    child = measure(widget.child, active)
    return Size(
        min(available.height, child.height + available.height - active.height),
        min(available.width, child.width + available.width - active.width),
    )
end

struct Box{W}
    child::W
    block::Block
end

Box(child; block::Block=Block()) = Box(child, block)

function render!(buffer::Buffer, widget::Box, area::Rect)
    render!(buffer, widget.block, area)
    render!(buffer, widget.child, inner(widget.block, area))
end

function measure(widget::Box, available::Rect)
    active = inner(widget.block, available)
    child = measure(widget.child, active)
    return Size(
        min(available.height, child.height + available.height - active.height),
        min(available.width, child.width + available.width - active.width),
    )
end

struct Row{T<:Tuple}
    children::T
    layout::FlexLayout
end

function Row(
    children...;
    constraints=nothing,
    margin::Margin=Margin(0),
    gap::Integer=0,
    alignment::FlexAlignment=StartFlex,
)
    resolved = isnothing(constraints) ? [Fill(1) for _ in children] : Constraint[constraints...]
    length(resolved) == length(children) ||
        throw(DimensionMismatch("row constraints must match child count"))
    Row(children, FlexLayout(HorizontalLayout, resolved; margin, gap, alignment))
end

function render!(buffer::Buffer, widget::Row, area::Rect)
    for (child, region) in zip(widget.children, resolve(widget.layout, area))
        render!(buffer, child, region)
    end
    buffer
end

function measure(widget::Row, available::Rect)
    active = inset(available, widget.layout.margin)
    sizes = Size[measure(child, active) for child in widget.children]
    gaps = _container_total_gap(active.width, widget.layout.gap, length(sizes))
    width = sum(size -> Int128(size.width), sizes; init=Int128(gaps))
    height = isempty(sizes) ? 0 : maximum(size.height for size in sizes)
    return Size(
        min(available.height, height + available.height - active.height),
        Int(min(Int128(available.width), width + available.width - active.width)),
    )
end

struct Column{T<:Tuple}
    children::T
    layout::FlexLayout
end

function Column(
    children...;
    constraints=nothing,
    margin::Margin=Margin(0),
    gap::Integer=0,
    alignment::FlexAlignment=StartFlex,
)
    resolved = isnothing(constraints) ? [Fill(1) for _ in children] : Constraint[constraints...]
    length(resolved) == length(children) ||
        throw(DimensionMismatch("column constraints must match child count"))
    Column(children, FlexLayout(VerticalLayout, resolved; margin, gap, alignment))
end

function render!(buffer::Buffer, widget::Column, area::Rect)
    for (child, region) in zip(widget.children, resolve(widget.layout, area))
        render!(buffer, child, region)
    end
    buffer
end

function measure(widget::Column, available::Rect)
    active = inset(available, widget.layout.margin)
    sizes = Size[measure(child, active) for child in widget.children]
    gaps = _container_total_gap(active.height, widget.layout.gap, length(sizes))
    height = sum(size -> Int128(size.height), sizes; init=Int128(gaps))
    width = isempty(sizes) ? 0 : maximum(size.width for size in sizes)
    return Size(
        Int(min(Int128(available.height), height + available.height - active.height)),
        min(available.width, width + available.width - active.width),
    )
end

struct Stack{T<:Tuple}
    children::T
end

Stack(children...) = Stack(children)

function render!(buffer::Buffer, widget::Stack, area::Rect)
    for child in widget.children
        render!(buffer, child, area)
    end
    buffer
end

function measure(widget::Stack, available::Rect)
    sizes = Size[measure(child, available) for child in widget.children]
    return Size(
        isempty(sizes) ? 0 : maximum(size.height for size in sizes),
        isempty(sizes) ? 0 : maximum(size.width for size in sizes),
    )
end

const Overlay = Stack

struct Center{W}
    child::W
    size::Size
end

Center(child; height::Integer, width::Integer) = Center(child, Size(height, width))
render!(buffer::Buffer, widget::Center, area::Rect) =
    render!(buffer, widget.child, center(area, widget.size))

function measure(widget::Center, available::Rect)
    centered = center(available, widget.size)
    return measure(widget.child, centered)
end

struct Grid{T<:Tuple}
    children::T
    layout::GridLayout
    cells::Union{Nothing,Vector{GridCell}}
end

function Grid(
    children...;
    rows,
    columns,
    cells=nothing,
    margin::Margin=Margin(0),
    row_gap::Integer=0,
    column_gap::Integer=0,
)
    layout = GridLayout(rows, columns; margin, row_gap, column_gap)
    resolved_cells = cells === nothing ? nothing : GridCell[cell for cell in cells]
    if resolved_cells === nothing
        capacity = Int128(length(layout.rows)) * Int128(length(layout.columns))
        length(children) <= capacity ||
            throw(DimensionMismatch("grid child count exceeds cell count"))
    else
        length(resolved_cells) == length(children) ||
            throw(DimensionMismatch("grid cells must match child count"))
    end
    return Grid(children, layout, resolved_cells)
end

function render!(buffer::Buffer, widget::Grid, area::Rect)
    if widget.cells === nothing
        regions = resolve(widget.layout, area)
        index = 1
        for row in axes(regions, 1), column in axes(regions, 2)
            index > length(widget.children) && return buffer
            render!(buffer, widget.children[index], regions[row, column])
            index += 1
        end
    else
        regions = resolve(widget.layout, area, widget.cells)
        for (child, region) in zip(widget.children, regions)
            render!(buffer, child, region)
        end
    end
    buffer
end
