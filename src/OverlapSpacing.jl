# Overlapping layout — split an area into segments that share cells with their
# neighbours, mirroring Ratatui's `Spacing::Overlap`.
#
# The main `FlexLayout` resolver only supports non-negative gaps (segments never
# touch). This additive helper produces segments that overlap by a fixed number
# of cells so adjacent blocks can share a border column/row, without touching the
# flex engine or its snapshot-tested distribution logic.
#
# Internal, non-exported: reachable as `Wicked.overlap_layout`. Promote via
# `Wicked.API` + a ledger row as usual.

"""
    overlap_layout(area, lengths; direction=:horizontal, overlap=1) -> Vector{Rect}

Lay out segments of the given `lengths` along `direction` inside `area`, with
each segment starting `overlap` cells before the previous one ends, so adjacent
segments share `overlap` cells (use `overlap=1` for shared single-cell borders,
`overlap=0` for ordinary abutting segments). Each returned `Rect` is clipped to
`area`; lengths that run past the edge are truncated.
"""
function overlap_layout(
    area::Rect,
    lengths;
    direction::Symbol = :horizontal,
    overlap::Integer = 1,
)
    direction in (:horizontal, :vertical) ||
        throw(ArgumentError("overlap_layout direction must be :horizontal or :vertical"))
    overlap >= 0 || throw(ArgumentError("overlap_layout overlap must be non-negative"))
    axis_length = direction === :horizontal ? area.width : area.height
    rects = Rect[]
    cursor = 0
    for length in lengths
        length >= 0 ||
            throw(ArgumentError("overlap_layout segment lengths must be non-negative"))
        length = Int(length)
        start = clamp(cursor, 0, axis_length)
        stop = clamp(cursor + length, 0, axis_length)
        span = max(0, stop - start)
        if direction === :horizontal
            push!(rects, Rect(area.row, area.column + start, area.height, span))
        else
            push!(rects, Rect(area.row + start, area.column, span, area.width))
        end
        cursor += max(0, length - Int(overlap))
    end
    return rects
end
