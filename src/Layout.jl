module Layout

using ..Core: Margin, Rect, Size, inset

"""Base type for a main-axis layout constraint."""
abstract type Constraint end

struct Length <: Constraint
    value::Int
    Length(value::Integer) = value >= 0 ? new(Int(value)) :
        throw(ArgumentError("length must be non-negative"))
end

struct Min <: Constraint
    value::Int
    Min(value::Integer) = value >= 0 ? new(Int(value)) :
        throw(ArgumentError("minimum must be non-negative"))
end

struct Max <: Constraint
    value::Int
    Max(value::Integer) = value >= 0 ? new(Int(value)) :
        throw(ArgumentError("maximum must be non-negative"))
end

struct Percentage <: Constraint
    value::Float64
    Percentage(value::Real) = 0 <= value <= 100 ? new(Float64(value)) :
        throw(ArgumentError("percentage must be between 0 and 100"))
end

struct Ratio <: Constraint
    numerator::Int
    denominator::Int

    function Ratio(numerator::Integer, denominator::Integer)
        numerator >= 0 || throw(ArgumentError("ratio numerator must be non-negative"))
        denominator > 0 || throw(ArgumentError("ratio denominator must be positive"))
        new(Int(numerator), Int(denominator))
    end
end

struct Fill <: Constraint
    weight::Int
    Fill(weight::Integer=1) = weight > 0 ? new(Int(weight)) :
        throw(ArgumentError("fill weight must be positive"))
end

struct Content <: Constraint
    minimum::Int
    maximum::Int

    function Content(minimum::Integer=0, maximum::Integer=typemax(Int))
        minimum >= 0 || throw(ArgumentError("content minimum must be non-negative"))
        maximum >= minimum || throw(ArgumentError("content maximum must not be smaller than minimum"))
        new(Int(minimum), Int(maximum))
    end
end

@enum LayoutDirection::UInt8 begin
    HorizontalLayout
    VerticalLayout
end

@enum FlexAlignment::UInt8 begin
    StartFlex
    CenterFlex
    EndFlex
    SpaceBetween
    SpaceAround
    SpaceEvenly
end

"""A deterministic one-dimensional constraint layout."""
struct FlexLayout
    direction::LayoutDirection
    constraints::Vector{Constraint}
    margin::Margin
    gap::Int
    alignment::FlexAlignment

    function FlexLayout(
        direction::LayoutDirection,
        constraints::AbstractVector{<:Constraint};
        margin::Margin=Margin(0),
        gap::Integer=0,
        alignment::FlexAlignment=StartFlex,
    )
        gap >= 0 || throw(ArgumentError("layout gap must be non-negative"))
        new(direction, Constraint[constraints...], margin, Int(gap), alignment)
    end
end

FlexLayout(
    direction::LayoutDirection,
    constraints::Tuple;
    kwargs...,
) = FlexLayout(direction, Constraint[constraints...]; kwargs...)

function _constraint_values(
    constraint::Constraint,
    available::Int,
    measured::Int,
)
    if constraint isa Length
        value = min(constraint.value, available)
        return value, value, value, 0
    elseif constraint isa Min
        value = min(constraint.value, available)
        return value, value, available, 1
    elseif constraint isa Max
        maximum = min(constraint.value, available)
        return 0, 0, maximum, 1
    elseif constraint isa Percentage
        value = clamp(floor(Int, available * constraint.value / 100), 0, available)
        return value, value, value, 0
    elseif constraint isa Ratio
        scaled = div(
            Int128(available) * Int128(constraint.numerator),
            Int128(constraint.denominator),
        )
        value = Int(clamp(scaled, Int128(0), Int128(available)))
        return value, value, value, 0
    elseif constraint isa Fill
        return 0, 0, available, constraint.weight
    elseif constraint isa Content
        value = clamp(measured, constraint.minimum, min(constraint.maximum, available))
        return min(constraint.minimum, available), value, min(constraint.maximum, available), 0
    end
    throw(ArgumentError("unsupported layout constraint"))
end

function _shrink!(sizes::Vector{Int}, minimums::Vector{Int}, overflow::Int128)
    for index in reverse(eachindex(sizes))
        overflow == 0 && break
        amount = Int(min(overflow, Int128(sizes[index] - minimums[index])))
        sizes[index] -= amount
        overflow -= amount
    end
    for index in reverse(eachindex(sizes))
        overflow == 0 && break
        amount = Int(min(overflow, Int128(sizes[index])))
        sizes[index] -= amount
        overflow -= amount
    end
    nothing
end

function _grow!(
    sizes::Vector{Int},
    maximums::Vector{Int},
    weights::Vector{Int},
    remaining::Int,
)
    while remaining > 0
        active = [
            index for index in eachindex(sizes)
            if weights[index] > 0 && sizes[index] < maximums[index]
        ]
        active_weight = sum(index -> Int128(weights[index]), active; init=Int128(0))
        active_weight == 0 && break
        available = remaining
        allocations = zeros(Int, length(active))
        for (offset, index) in enumerate(active)
            share = div(Int128(available) * Int128(weights[index]), active_weight)
            allocations[offset] = Int(min(
                share,
                Int128(maximums[index] - sizes[index]),
            ))
        end
        all(iszero, allocations) && (allocations[1] = 1)
        changed = false
        for (offset, index) in enumerate(active)
            amount = min(allocations[offset], remaining)
            sizes[index] += amount
            remaining -= amount
            changed |= amount > 0
            remaining == 0 && break
        end
        changed || break
    end
    remaining
end

function _total_gap(axis_length::Int, gap::Int, count::Int)
    slots = max(0, count - 1)
    slots == 0 && return 0
    gap > div(axis_length, slots) && return axis_length
    return gap * slots
end

function _resolved_gaps(total_gap::Int, count::Int)
    slots = max(0, count - 1)
    slots == 0 && return Int[]
    base = div(total_gap, slots)
    remainder = total_gap - base * slots
    gaps = fill(base, slots)
    for index in 1:remainder
        gaps[index] += 1
    end
    return gaps
end

function _spacing(
    alignment::FlexAlignment,
    leftover::Int,
    count::Int,
    gaps::Vector{Int},
)
    count == 0 && return 0, Int[]
    leftover <= 0 && return 0, gaps
    if alignment == CenterFlex
        return div(leftover, 2), gaps
    elseif alignment == EndFlex
        return leftover, gaps
    elseif alignment == SpaceBetween && count > 1
        for unit in 1:leftover
            gaps[mod1(unit, length(gaps))] += 1
        end
        return 0, gaps
    elseif alignment == SpaceAround
        slots = 2 * count
        unit = div(leftover, slots)
        remainder = leftover - unit * slots
        leading = unit
        for index in eachindex(gaps)
            gaps[index] += 2 * unit
        end
        leading += min(remainder, 1)
        for unit_index in 2:remainder
            !isempty(gaps) && (gaps[mod1(unit_index - 1, length(gaps))] += 1)
        end
        return leading, gaps
    elseif alignment == SpaceEvenly
        slots = count + 1
        unit = div(leftover, slots)
        remainder = leftover - unit * slots
        leading = unit + (remainder > 0 ? 1 : 0)
        for index in eachindex(gaps)
            gaps[index] += unit + (index + 1 <= remainder ? 1 : 0)
        end
        return leading, gaps
    end
    0, gaps
end

"""Resolve a flex layout into ordered non-overlapping regions."""
function resolve(
    layout::FlexLayout,
    area::Rect;
    content_sizes::AbstractVector{<:Integer}=Int[],
)
    active = inset(area, layout.margin)
    count = length(layout.constraints)
    count == 0 && return Rect[]
    !isempty(content_sizes) && length(content_sizes) != count &&
        throw(DimensionMismatch("content size count must match constraint count"))
    axis_length = layout.direction == HorizontalLayout ? active.width : active.height
    total_gap = _total_gap(axis_length, layout.gap, count)
    available = axis_length - total_gap
    minimums = zeros(Int, count)
    sizes = zeros(Int, count)
    maximums = zeros(Int, count)
    weights = zeros(Int, count)
    for index in eachindex(layout.constraints)
        measured = isempty(content_sizes) ? 0 : Int(content_sizes[index])
        minimums[index], sizes[index], maximums[index], weights[index] =
            _constraint_values(layout.constraints[index], available, measured)
    end
    used = sum(Int128, sizes)
    used > available && _shrink!(sizes, minimums, used - Int128(available))
    used = sum(sizes)
    leftover = _grow!(sizes, maximums, weights, available - used)
    leading, gaps = _spacing(
        layout.alignment,
        leftover,
        count,
        _resolved_gaps(total_gap, count),
    )
    cursor = (layout.direction == HorizontalLayout ? active.column : active.row) + leading
    regions = Vector{Rect}(undef, count)
    for index in eachindex(sizes)
        if layout.direction == HorizontalLayout
            regions[index] = Rect(active.row, cursor, active.height, sizes[index])
        else
            regions[index] = Rect(cursor, active.column, sizes[index], active.width)
        end
        cursor += sizes[index]
        index <= length(gaps) && (cursor += gaps[index])
    end
    regions
end

"""A row and column constraint grid."""
struct GridLayout
    rows::Vector{Constraint}
    columns::Vector{Constraint}
    margin::Margin
    row_gap::Int
    column_gap::Int

    function GridLayout(
        rows::AbstractVector{<:Constraint},
        columns::AbstractVector{<:Constraint};
        margin::Margin=Margin(0),
        row_gap::Integer=0,
        column_gap::Integer=0,
    )
        row_gap >= 0 || throw(ArgumentError("row gap must be non-negative"))
        column_gap >= 0 || throw(ArgumentError("column gap must be non-negative"))
        new(Constraint[rows...], Constraint[columns...], margin, Int(row_gap), Int(column_gap))
    end
end

GridLayout(rows::Tuple, columns::Tuple; kwargs...) =
    GridLayout(Constraint[rows...], Constraint[columns...]; kwargs...)

"""A one-based grid cell location with checked row and column spans."""
struct GridCell
    row::Int
    column::Int
    row_span::Int
    column_span::Int

    function GridCell(
        row::Integer,
        column::Integer;
        row_span::Integer=1,
        column_span::Integer=1,
    )
        row >= 1 || throw(ArgumentError("grid row must be at least one"))
        column >= 1 || throw(ArgumentError("grid column must be at least one"))
        row_span >= 1 || throw(ArgumentError("grid row span must be positive"))
        column_span >= 1 || throw(ArgumentError("grid column span must be positive"))
        new(Int(row), Int(column), Int(row_span), Int(column_span))
    end
end

"""Resolve a grid into a matrix indexed by row and column."""
function resolve(
    layout::GridLayout,
    area::Rect;
    row_content_sizes::AbstractVector{<:Integer}=Int[],
    column_content_sizes::AbstractVector{<:Integer}=Int[],
)
    active = inset(area, layout.margin)
    row_regions = resolve(
        FlexLayout(VerticalLayout, layout.rows; gap=layout.row_gap),
        active;
        content_sizes=row_content_sizes,
    )
    column_regions = resolve(
        FlexLayout(HorizontalLayout, layout.columns; gap=layout.column_gap),
        active;
        content_sizes=column_content_sizes,
    )
    cells = Matrix{Rect}(undef, length(row_regions), length(column_regions))
    for row in eachindex(row_regions), column in eachindex(column_regions)
        cells[row, column] = Rect(
            row_regions[row].row,
            column_regions[column].column,
            row_regions[row].height,
            column_regions[column].width,
        )
    end
    cells
end

"""Resolve selected grid cells, including spans, into ordered regions."""
function resolve(
    layout::GridLayout,
    area::Rect,
    requested::AbstractVector{GridCell};
    row_content_sizes::AbstractVector{<:Integer}=Int[],
    column_content_sizes::AbstractVector{<:Integer}=Int[],
)
    cells = resolve(
        layout,
        area;
        row_content_sizes,
        column_content_sizes,
    )
    row_count, column_count = size(cells)
    regions = Rect[]
    sizehint!(regions, length(requested))
    for cell in requested
        cell.row <= row_count || throw(BoundsError(cells, (cell.row, cell.column)))
        cell.column <= column_count || throw(BoundsError(cells, (cell.row, cell.column)))
        last_row = cell.row + cell.row_span - 1
        last_column = cell.column + cell.column_span - 1
        last_row <= row_count || throw(BoundsError(cells, (last_row, cell.column)))
        last_column <= column_count || throw(BoundsError(cells, (cell.row, last_column)))
        first_region = cells[cell.row, cell.column]
        last_region = cells[last_row, last_column]
        push!(
            regions,
            Rect(
                first_region.row,
                first_region.column,
                last_region.row + last_region.height - first_region.row,
                last_region.column + last_region.width - first_region.column,
            ),
        )
    end
    return regions
end

@enum DockSide::UInt8 begin
    DockTop
    DockRight
    DockBottom
    DockLeft
end

struct DockItem
    side::DockSide
    size::Int
    function DockItem(side::DockSide, size::Integer)
        size >= 0 || throw(ArgumentError("dock size must be non-negative"))
        new(side, Int(size))
    end
end

"""Resolve sequential dock items and return their regions plus the remaining area."""
function dock(area::Rect, items::AbstractVector{DockItem})
    remaining = area
    regions = Rect[]
    sizehint!(regions, length(items))
    for item in items
        if item.side == DockTop
            height = min(item.size, remaining.height)
            region = Rect(remaining.row, remaining.column, height, remaining.width)
            remaining = Rect(remaining.row + height, remaining.column, remaining.height - height, remaining.width)
        elseif item.side == DockBottom
            height = min(item.size, remaining.height)
            region = Rect(remaining.row + remaining.height - height, remaining.column, height, remaining.width)
            remaining = Rect(remaining.row, remaining.column, remaining.height - height, remaining.width)
        elseif item.side == DockLeft
            width = min(item.size, remaining.width)
            region = Rect(remaining.row, remaining.column, remaining.height, width)
            remaining = Rect(remaining.row, remaining.column + width, remaining.height, remaining.width - width)
        else
            width = min(item.size, remaining.width)
            region = Rect(remaining.row, remaining.column + remaining.width - width, remaining.height, width)
            remaining = Rect(remaining.row, remaining.column, remaining.height, remaining.width - width)
        end
        push!(regions, region)
    end
    regions, remaining
end

"""Return a centered region with clamped dimensions."""
function center(area::Rect, size::Size)
    height = min(area.height, size.height)
    width = min(area.width, size.width)
    Rect(
        area.row + div(area.height - height, 2),
        area.column + div(area.width - width, 2),
        height,
        width,
    )
end

"""Lay out measured items in rows, wrapping at the available width."""
function flow(
    area::Rect,
    sizes::AbstractVector{Size};
    column_gap::Integer=0,
    row_gap::Integer=0,
)
    column_gap >= 0 || throw(ArgumentError("column gap must be non-negative"))
    row_gap >= 0 || throw(ArgumentError("row gap must be non-negative"))
    regions = Rect[]
    row = area.row
    column = area.column
    line_height = 0
    for size in sizes
        width = min(size.width, area.width)
        if column > area.column && column + width > area.column + area.width
            row += line_height + Int(row_gap)
            column = area.column
            line_height = 0
        end
        row >= area.row + area.height && break
        height = min(size.height, area.row + area.height - row)
        push!(regions, Rect(row, column, height, width))
        column += width + Int(column_gap)
        line_height = max(line_height, height)
    end
    regions
end

export CenterFlex,
       Constraint,
       Content,
       DockBottom,
       DockItem,
       DockLeft,
       DockRight,
       DockSide,
       DockTop,
       EndFlex,
       Fill,
       FlexAlignment,
       FlexLayout,
       GridCell,
       GridLayout,
       HorizontalLayout,
       LayoutDirection,
       Length,
       Max,
       Min,
       Percentage,
       Ratio,
       SpaceAround,
       SpaceBetween,
       SpaceEvenly,
       StartFlex,
       VerticalLayout,
       center,
       dock,
       flow,
       resolve

end
