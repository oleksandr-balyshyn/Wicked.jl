"""One changed cell between two terminal buffers."""
struct CellChange
    position::Position
    cell::Cell
end

"""Return ordered row-major changes needed to transform `previous` into `current`."""
function diff_buffers(previous::Buffer, current::Buffer; force::Bool=false)
    same_area = previous.area == current.area
    changes = CellChange[]
    sizehint!(changes, force || !same_area ? length(current) : 0)
    for row in current.area.row:(row_end(current.area) - 1)
        for column in current.area.column:(column_end(current.area) - 1)
            cell = current[row, column]
            if force || !same_area || previous[row, column] != cell
                push!(changes, CellChange(Position(row, column), cell))
            end
        end
    end
    changes
end
