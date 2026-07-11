"""A one-based row and column in a terminal surface."""
struct Position
    row::Int
    column::Int

    function Position(row::Integer, column::Integer)
        row >= 1 || throw(ArgumentError("row must be at least 1"))
        column >= 1 || throw(ArgumentError("column must be at least 1"))
        new(Int(row), Int(column))
    end
end

"""A non-negative terminal height and width."""
struct Size
    height::Int
    width::Int

    function Size(height::Integer, width::Integer)
        height >= 0 || throw(ArgumentError("height must be non-negative"))
        width >= 0 || throw(ArgumentError("width must be non-negative"))
        height <= typemax(Int) || throw(OverflowError("height does not fit in Int"))
        width <= typemax(Int) || throw(OverflowError("width does not fit in Int"))
        new(Int(height), Int(width))
    end
end

"""A one-based, half-open rectangular terminal region."""
struct Rect
    row::Int
    column::Int
    height::Int
    width::Int

    function Rect(row::Integer, column::Integer, height::Integer, width::Integer)
        row >= 1 || throw(ArgumentError("row must be at least 1"))
        column >= 1 || throw(ArgumentError("column must be at least 1"))
        height >= 0 || throw(ArgumentError("height must be non-negative"))
        width >= 0 || throw(ArgumentError("width must be non-negative"))
        row <= typemax(Int) || throw(OverflowError("row does not fit in Int"))
        column <= typemax(Int) || throw(OverflowError("column does not fit in Int"))
        height <= typemax(Int) - Int(row) || throw(OverflowError("row and height overflow Int"))
        width <= typemax(Int) - Int(column) || throw(OverflowError("column and width overflow Int"))
        new(Int(row), Int(column), Int(height), Int(width))
    end
end

Rect(size::Size; row::Integer=1, column::Integer=1) = Rect(row, column, size.height, size.width)
Rect(; row::Integer=1, column::Integer=1, height::Integer, width::Integer) =
    Rect(row, column, height, width)

@enum RectSplitDirection::UInt8 begin
    RowSplit
    ColumnSplit
end

Base.size(rect::Rect) = (rect.height, rect.width)
Base.isempty(rect::Rect) = rect.height == 0 || rect.width == 0

row_end(rect::Rect) = rect.row + rect.height
column_end(rect::Rect) = rect.column + rect.width

"""Return whether `position` is inside `rect`."""
contains(rect::Rect, position::Position) =
    rect.row <= position.row < row_end(rect) &&
    rect.column <= position.column < column_end(rect)

"""Return the common region of two rectangles."""
function intersection(left::Rect, right::Rect)
    row = max(left.row, right.row)
    column = max(left.column, right.column)
    last_row = min(row_end(left), row_end(right))
    last_column = min(column_end(left), column_end(right))
    Rect(row, column, max(0, last_row - row), max(0, last_column - column))
end

"""Return the smallest rectangle containing both non-empty rectangles."""
function union(left::Rect, right::Rect)
    isempty(left) && return right
    isempty(right) && return left
    row = min(left.row, right.row)
    column = min(left.column, right.column)
    last_row = max(row_end(left), row_end(right))
    last_column = max(column_end(left), column_end(right))
    return Rect(row, column, last_row - row, last_column - column)
end

"""Move and, when necessary, shrink a rectangle so it fits inside `bounds`."""
function clamp(rect::Rect, bounds::Rect)
    isempty(bounds) && return Rect(bounds.row, bounds.column, 0, 0)
    height = min(rect.height, bounds.height)
    width = min(rect.width, bounds.width)
    row = clamp(rect.row, bounds.row, row_end(bounds) - height)
    column = clamp(rect.column, bounds.column, column_end(bounds) - width)
    return Rect(row, column, height, width)
end

"""Split a rectangle into two regions separated by an optional checked gap."""
function split(
    rect::Rect,
    offset::Integer;
    direction::RectSplitDirection=RowSplit,
    gap::Integer=0,
)
    offset >= 0 || throw(ArgumentError("rectangle split offset must be non-negative"))
    gap >= 0 || throw(ArgumentError("rectangle split gap must be non-negative"))
    extent = direction == RowSplit ? rect.height : rect.width
    offset <= extent || throw(ArgumentError("rectangle split offset exceeds its extent"))
    gap <= extent - offset || throw(ArgumentError("rectangle split gap exceeds its extent"))
    first_extent = Int(offset)
    second_extent = extent - first_extent - Int(gap)
    if direction == RowSplit
        return (
            Rect(rect.row, rect.column, first_extent, rect.width),
            Rect(rect.row + first_extent + Int(gap), rect.column, second_extent, rect.width),
        )
    end
    return (
        Rect(rect.row, rect.column, rect.height, first_extent),
        Rect(rect.row, rect.column + first_extent + Int(gap), rect.height, second_extent),
    )
end

"""Non-negative insets around a rectangular region."""
struct Margin
    top::Int
    right::Int
    bottom::Int
    left::Int

    function Margin(top::Integer, right::Integer, bottom::Integer, left::Integer)
        all(value -> value >= 0, (top, right, bottom, left)) ||
            throw(ArgumentError("margin values must be non-negative"))
        new(Int(top), Int(right), Int(bottom), Int(left))
    end
end

Margin(all::Integer) = Margin(all, all, all, all)
Margin(vertical::Integer, horizontal::Integer) =
    Margin(vertical, horizontal, vertical, horizontal)

"""Return `rect` reduced by `margin`, clamping the result to an empty region."""
function inset(rect::Rect, margin::Margin)
    top = min(margin.top, rect.height)
    bottom = min(margin.bottom, rect.height - top)
    left = min(margin.left, rect.width)
    right = min(margin.right, rect.width - left)
    Rect(
        rect.row + top,
        rect.column + left,
        rect.height - top - bottom,
        rect.width - left - right,
    )
end
