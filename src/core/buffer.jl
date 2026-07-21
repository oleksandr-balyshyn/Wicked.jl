"""A rectangular row-major terminal cell buffer."""
mutable struct Buffer
    area::Rect
    cells::Vector{Cell}

    function Buffer(area::Rect; cell::Cell=Cell())
        area.height > 0 && area.width > div(typemax(Int), area.height) &&
            throw(OverflowError("buffer cell count overflows Int"))
        new(area, fill(cell, area.height * area.width))
    end
end

Buffer(height::Integer, width::Integer; row::Integer=1, column::Integer=1, cell::Cell=Cell()) =
    Buffer(Rect(row, column, height, width); cell)

Base.size(buffer::Buffer) = size(buffer.area)
Base.length(buffer::Buffer) = length(buffer.cells)
Base.copy(buffer::Buffer) = Buffer(buffer.area, copy(buffer.cells))
Base.:(==)(left::Buffer, right::Buffer) =
    left.area == right.area && left.cells == right.cells

"""A non-owning, one-dimensional view of a buffer row."""
struct BufferRowView
    buffer::Buffer
    row::Int
end

"""A non-owning iterable over the rows of a buffer."""
struct BufferRows
    buffer::Buffer
end

buffer_rows(buffer::Buffer) = BufferRows(buffer)

Base.IteratorSize(::Type{BufferRows}) = Base.HasLength()
Base.IteratorEltype(::Type{BufferRows}) = Base.HasEltype()
Base.eltype(::Type{BufferRows}) = BufferRowView
Base.length(rows::BufferRows) = rows.buffer.area.height

function Base.getindex(rows::BufferRows, index::Integer)
    1 <= index <= length(rows) || throw(BoundsError(rows, index))
    return BufferRowView(rows.buffer, rows.buffer.area.row + Int(index) - 1)
end

function Base.iterate(rows::BufferRows, index::Int=1)
    index > length(rows) && return nothing
    return rows[index], index + 1
end

Base.IteratorSize(::Type{BufferRowView}) = Base.HasLength()
Base.IteratorEltype(::Type{BufferRowView}) = Base.HasEltype()
Base.eltype(::Type{BufferRowView}) = Cell
Base.length(row::BufferRowView) = row.buffer.area.width

function Base.getindex(row::BufferRowView, index::Integer)
    1 <= index <= length(row) || throw(BoundsError(row, index))
    return row.buffer[row.row, row.buffer.area.column + Int(index) - 1]
end

function Base.iterate(row::BufferRowView, index::Int=1)
    index > length(row) && return nothing
    return row[index], index + 1
end

function Base.show(io::IO, buffer::Buffer)
    print(
        io,
        "Buffer(", buffer.area.height, 'x', buffer.area.width,
        ", origin=(", buffer.area.row, ", ", buffer.area.column, "))",
    )
end

function Base.show(io::IO, ::MIME"text/plain", buffer::Buffer)
    show(io, buffer)
    for row in buffer_rows(buffer)
        print(io, '\n')
        for cell in row
            cell.continuation || print(io, cell.grapheme)
        end
    end
end

Buffer(area::Rect, cells::Vector{Cell}) = begin
    length(cells) == area.height * area.width ||
        throw(DimensionMismatch("cell count does not match buffer area"))
    Buffer(area, cells, Val(:unchecked))
end

Buffer(area::Rect, cells::Vector{Cell}, ::Val{:unchecked}) = begin
    buffer = Buffer(area)
    buffer.cells = cells
    buffer
end

function _index(buffer::Buffer, row::Int, column::Int)
    if !(buffer.area.row <= row < row_end(buffer.area)) ||
       !(buffer.area.column <= column < column_end(buffer.area))
        throw(BoundsError(buffer, (row, column)))
    end
    (row - buffer.area.row) * buffer.area.width + (column - buffer.area.column) + 1
end

_raw_cell(buffer::Buffer, row::Int, column::Int) = buffer.cells[_index(buffer, row, column)]
_raw_cell!(buffer::Buffer, cell::Cell, row::Int, column::Int) =
    (buffer.cells[_index(buffer, row, column)] = cell)

Base.getindex(buffer::Buffer, row::Integer, column::Integer) =
    _raw_cell(buffer, Int(row), Int(column))

function _erase_footprint!(buffer::Buffer, row::Int, column::Int)
    cell = _raw_cell(buffer, row, column)
    blank = Cell()
    if cell.continuation && column > buffer.area.column
        previous = _raw_cell(buffer, row, column - 1)
        previous.width == 2 && _raw_cell!(buffer, blank, row, column - 1)
    elseif cell.width == 2 && column + 1 < column_end(buffer.area)
        _raw_cell!(buffer, blank, row, column + 1)
    end
    _raw_cell!(buffer, blank, row, column)
    nothing
end

function Base.setindex!(buffer::Buffer, cell::Cell, row::Integer, column::Integer)
    cell.continuation &&
        throw(ArgumentError("continuation cells are maintained by Buffer"))
    target_row = Int(row)
    target_column = Int(column)
    _index(buffer, target_row, target_column)
    if cell.width == 2 && target_column + 1 >= column_end(buffer.area)
        throw(BoundsError(buffer, (target_row, target_column + 1)))
    end
    _erase_footprint!(buffer, target_row, target_column)
    if cell.width == 2
        _erase_footprint!(buffer, target_row, target_column + 1)
    end
    _raw_cell!(buffer, cell, target_row, target_column)
    if cell.width == 2
        _raw_cell!(buffer, continuation_cell(cell.style), target_row, target_column + 1)
    end
    cell
end

"""Reset every cell in `buffer`."""
function clear!(buffer::Buffer; cell::Cell=Cell())
    cell.continuation && throw(ArgumentError("a buffer cannot be cleared to a continuation cell"))
    fill!(buffer.cells, cell)
    buffer
end

"""Fill a clipped buffer region with one width-one display cell."""
function fill!(buffer::Buffer, cell::Cell; area::Rect=buffer.area)
    !cell.continuation && cell.width == 1 ||
        throw(ArgumentError("buffer fill requires a width-one display cell"))
    active = intersection(buffer.area, area)
    for row in active.row:(active.row + active.height - 1),
        column in active.column:(active.column + active.width - 1)
        buffer[row, column] = cell
    end
    return buffer
end

fill!(buffer::Buffer, area::Rect, cell::Cell=Cell()) = fill!(buffer, cell; area)

"""Restore every buffer cell to the default blank cell."""
reset!(buffer::Buffer) = clear!(buffer)

"""Copy complete, clipped cell footprints from one buffer into another."""
function merge!(destination::Buffer, source::Buffer; area::Rect=source.area)
    active = intersection(intersection(source.area, destination.area), area)
    for row in active.row:(active.row + active.height - 1)
        for column in active.column:(active.column + active.width - 1)
            cell = source[row, column]
            cell.continuation && continue
            if cell.width == 2
                column + 1 < active.column + active.width || continue
                source[row, column + 1].continuation || continue
            end
            destination[row, column] = cell
        end
    end
    return destination
end

"""Draw one grapheme and return the next column."""
function draw_grapheme!(
    buffer::Buffer,
    row::Integer,
    column::Integer,
    grapheme::AbstractString;
    style::Style=Style(),
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
)
    cell = Cell(grapheme; style, width_policy)
    buffer[Int(row), Int(column)] = cell
    Int(column) + Int(cell.width)
end

const _ASCII_GRAPHEMES = ntuple(index -> string(Char(index - 1)), 128)

function _is_simple_ascii(content::AbstractString)
    for byte in codeunits(content)
        (byte == 0x09 || byte == 0x0a || 0x20 <= byte <= 0x7e) || return false
    end
    return true
end

function _draw_ascii_text!(buffer, row, column, content, style, active_clip, tab_width)
    current_row = Int(row)
    current_column = Int(column)
    start_column = current_column
    for byte in codeunits(content)
        if byte == 0x0a
            current_row += 1
            current_column = start_column
        elseif byte == 0x09
            spaces = Int(tab_width) - mod(current_column - start_column, Int(tab_width))
            for _ in 1:spaces
                current_column >= column_end(active_clip) && break
                contains(active_clip, Position(current_row, current_column)) &&
                    (buffer[current_row, current_column] = Cell(; style))
                current_column += 1
            end
        else
            current_row >= row_end(active_clip) && break
            if current_row < active_clip.row || current_column < active_clip.column
                current_column += 1
                continue
            end
            current_column >= column_end(active_clip) && break
            grapheme = @inbounds _ASCII_GRAPHEMES[Int(byte) + 1]
            buffer[current_row, current_column] =
                Cell(grapheme, style, 0x01, false, _UNCHECKED_CELL)
            current_column += 1
        end
    end
    return Position(max(1, current_row), max(1, current_column))
end

"""Draw plain text inside a clipping region and return the final position."""
function draw_text!(
    buffer::Buffer,
    row::Integer,
    column::Integer,
    content::AbstractString;
    style::Style=Style(),
    clip::Rect=buffer.area,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
    tab_width::Integer=4,
)
    tab_width >= 1 || throw(ArgumentError("tab width must be positive"))
    active_clip = intersection(buffer.area, clip)
    _is_simple_ascii(content) &&
        return _draw_ascii_text!(buffer, row, column, content, style, active_clip, tab_width)
    current_row = Int(row)
    current_column = Int(column)
    start_column = current_column
    for grapheme in Unicode.graphemes(content)
        if grapheme == "\n"
            current_row += 1
            current_column = start_column
            continue
        elseif grapheme == "\t"
            spaces = Int(tab_width) - mod(current_column - start_column, Int(tab_width))
            for _ in 1:spaces
                current_column >= column_end(active_clip) && break
                contains(active_clip, Position(current_row, current_column)) &&
                    (buffer[current_row, current_column] = Cell(; style))
                current_column += 1
            end
            continue
        end
        width = grapheme_width(width_policy, grapheme)
        width == 0 && continue
        current_row >= row_end(active_clip) && break
        if current_row < active_clip.row || current_column < active_clip.column
            current_column += width
            continue
        end
        current_column + width > column_end(active_clip) && break
        current_column = draw_grapheme!(
            buffer,
            current_row,
            current_column,
            grapheme;
            style,
            width_policy,
        )
    end
    Position(max(1, current_row), max(1, current_column))
end

"""Draw a styled span inside `area`."""
function draw_span!(
    buffer::Buffer,
    row::Integer,
    column::Integer,
    span::Span;
    area::Rect=buffer.area,
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
)
    draw_text!(buffer, row, column, span.content; style=span.style, clip=area, width_policy)
end

"""Draw a line using its configured alignment."""
function draw_line!(
    buffer::Buffer,
    row::Integer,
    area::Rect,
    line::Line;
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
    content_width::Union{Nothing,Integer}=nothing,
)
    resolved_width = isnothing(content_width) ?
                     sum(span -> text_width(span.content, width_policy), line.spans; init=0) :
                     Int(content_width)
    offset = if line.alignment == CenterAlign
        max(0, (area.width - resolved_width) ÷ 2)
    elseif line.alignment == RightAlign
        max(0, area.width - resolved_width)
    else
        0
    end
    column = area.column + offset
    for span in line.spans
        position = draw_span!(buffer, row, column, span; area, width_policy)
        column = position.column
        column >= column_end(area) && break
    end
    Position(Int(row), max(1, column))
end

"""Draw styled text into `area`."""
function draw_text!(
    buffer::Buffer,
    area::Rect,
    text::Text;
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
)
    active_area = intersection(buffer.area, area)
    for (offset, line) in enumerate(text.lines)
        row = area.row + offset - 1
        row >= row_end(active_area) && break
        row < active_area.row && continue
        draw_line!(buffer, row, active_area, line; width_policy)
    end
    buffer
end
