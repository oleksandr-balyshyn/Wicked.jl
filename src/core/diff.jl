"""One changed cell between two terminal buffers."""
struct CellChange
    position::Position
    cell::Cell
end

"""Return ordered row-major changes needed to transform `previous` into `current`."""
function diff_buffers(previous::Buffer, current::Buffer; force::Bool=false)
    same_area = previous.area == current.area
    changes = CellChange[]
    dense = force || !same_area
    dense && sizehint!(changes, length(current))
    width = current.area.width
    for cell_index in eachindex(current.cells)
        cell = @inbounds current.cells[cell_index]
        if force || !same_area || @inbounds(previous.cells[cell_index] != cell)
            # Preserve the sparse zero-reservation path, but stop geometrically
            # reallocating once a frame has demonstrated that it is dense.
            if !dense && length(changes) == 64 && length(current) > 64
                sizehint!(changes, length(current))
                dense = true
            end
            offset = cell_index - 1
            row_offset, column_offset = divrem(offset, width)
            push!(
                changes,
                CellChange(
                    Position(current.area.row + row_offset, current.area.column + column_offset),
                    cell,
                ),
            )
        end
    end
    changes
end
