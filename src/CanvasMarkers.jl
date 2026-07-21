# Multi-resolution pixel canvas — draw on a sub-cell pixel grid and render it
# with a choice of glyph "markers", mirroring Ratatui's canvas markers.
#
# The existing braille `Canvas`/`CanvasContext` is a fixed 2x4 braille surface.
# This adds an additive, opt-in surface that supports several markers, trading
# resolution for terminal compatibility:
#
#   * :braille    2x4 per cell (U+2800 block) — highest density.
#   * :quadrant   2x2 per cell (block quadrants) — universally supported.
#   * :half_block 1x2 per cell (upper/lower half block).
#   * :dot        1x1 per cell (full block) — coarsest, maximal compatibility.
#
# It leaves the existing `Canvas` untouched. Internal, non-exported: reachable as
# `Wicked.PixelCanvas`, `Wicked.pixel_set!`, `Wicked.pixel_render`,
# `Wicked.pixel_dimensions`. Promote via `Wicked.API` + ledger rows as usual.
#
# Sextant (2x3) and octant (2x4) markers are intentionally omitted for now: their
# glyph tables have special cases (blank/full/half-block collisions) and newer,
# less-supported code points, and shipping an unverified table would be a subtle
# correctness bug. Add them behind a verified mapping when needed.

# (pixel_width, pixel_height) per cell for each marker.
function _marker_resolution(marker::Symbol)
    marker === :braille && return (2, 4)
    marker === :quadrant && return (2, 2)
    marker === :half_block && return (1, 2)
    marker === :dot && return (1, 1)
    throw(ArgumentError("canvas marker must be :braille, :quadrant, :half_block, or :dot"))
end

# Block-quadrant glyphs indexed by a 4-bit value (tl<<3 | tr<<2 | bl<<1 | br).
const _QUADRANT_GLYPHS = (
    " ", "▗", "▖", "▄", "▝", "▐", "▞", "▟",
    "▘", "▚", "▌", "▙", "▀", "▜", "▛", "█",
)

# Braille dot number (1..8) for a sub-cell position (x in 0:1, y in 0:3),
# matching the existing braille `CanvasContext` dot numbering.
function _braille_dot(x::Int, y::Int)
    if x == 0
        return y == 0 ? 1 : y == 1 ? 2 : y == 2 ? 3 : 7
    else
        return y == 0 ? 4 : y == 1 ? 5 : y == 2 ? 6 : 8
    end
end

"""A sub-cell pixel grid rendered with a chosen glyph marker.

`rows`/`cols` are in terminal cells; the pixel grid is
`rows*pixel_height` by `cols*pixel_width`. Set pixels with [`pixel_set!`](@ref)
(1-based `x` horizontal, `y` vertical) and render with [`pixel_render`](@ref).
"""
struct PixelCanvas
    marker::Symbol
    pixel_width::Int
    pixel_height::Int
    rows::Int
    cols::Int
    pixels::Matrix{Bool}
end

function PixelCanvas(rows::Integer, cols::Integer; marker::Symbol = :braille)
    rows >= 0 && cols >= 0 ||
        throw(ArgumentError("pixel canvas dimensions must be non-negative"))
    pixel_width, pixel_height = _marker_resolution(marker)
    PixelCanvas(
        marker,
        pixel_width,
        pixel_height,
        Int(rows),
        Int(cols),
        falses(Int(rows) * pixel_height, Int(cols) * pixel_width),
    )
end

"""Return the pixel-grid size as `(height, width)` (rows*height, cols*width)."""
pixel_dimensions(canvas::PixelCanvas) = size(canvas.pixels)

"""
    pixel_set!(canvas, x, y, on=true) -> Bool

Set the pixel at 1-based column `x` and row `y`. Returns `false` (a no-op) when
the coordinate is outside the grid, so callers can plot without bounds-checking.
"""
function pixel_set!(canvas::PixelCanvas, x::Integer, y::Integer, on::Bool = true)
    (1 <= x <= size(canvas.pixels, 2) && 1 <= y <= size(canvas.pixels, 1)) || return false
    canvas.pixels[Int(y), Int(x)] = on
    return true
end

function _cell_glyph(canvas::PixelCanvas, cell_row::Int, cell_col::Int)
    pixel_height = canvas.pixel_height
    pixel_width = canvas.pixel_width
    base_y = (cell_row - 1) * pixel_height
    base_x = (cell_col - 1) * pixel_width
    sub(dy, dx) = canvas.pixels[base_y + dy, base_x + dx]
    if canvas.marker === :braille
        mask = 0
        for dx in 1:2, dy in 1:4
            sub(dy, dx) && (mask |= 1 << (_braille_dot(dx - 1, dy - 1) - 1))
        end
        return mask == 0 ? " " : string(Char(0x2800 + mask))
    elseif canvas.marker === :quadrant
        index = (sub(1, 1) << 3) | (sub(1, 2) << 2) | (sub(2, 1) << 1) | sub(2, 2)
        return _QUADRANT_GLYPHS[index + 1]
    elseif canvas.marker === :half_block
        top = sub(1, 1)
        bottom = sub(2, 1)
        return top ? (bottom ? "█" : "▀") : (bottom ? "▄" : " ")
    else # :dot
        return sub(1, 1) ? "█" : " "
    end
end

"""
    pixel_render(canvas) -> Vector{String}

Render the pixel grid to one string per terminal-cell row, mapping each cell's
sub-pixels to the canvas's marker glyph.
"""
function pixel_render(canvas::PixelCanvas)
    rows = String[]
    for cell_row in 1:canvas.rows
        buffer = IOBuffer()
        for cell_col in 1:canvas.cols
            print(buffer, _cell_glyph(canvas, cell_row, cell_col))
        end
        push!(rows, String(take!(buffer)))
    end
    return rows
end
