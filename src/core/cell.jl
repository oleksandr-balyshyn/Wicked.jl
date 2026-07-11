"""One terminal cell or the continuation of a width-two grapheme."""
struct Cell
    grapheme::String
    style::Style
    width::UInt8
    continuation::Bool

    function Cell(grapheme::String, style::Style, width::UInt8, continuation::Bool)
        if continuation
            isempty(grapheme) ||
                throw(ArgumentError("a continuation cell cannot contain a grapheme"))
            width == 0 || throw(ArgumentError("a continuation cell has width zero"))
        else
            isempty(grapheme) && throw(ArgumentError("a display cell requires a grapheme"))
            width in (1, 2) || throw(ArgumentError("a display cell width must be 1 or 2"))
            iterator = Unicode.graphemes(grapheme)
            first_item = iterate(iterator)
            isnothing(first_item) && throw(ArgumentError("a display cell requires a grapheme"))
            isnothing(iterate(iterator, first_item[2])) ||
                throw(ArgumentError("a cell can contain exactly one grapheme cluster"))
        end
        new(grapheme, style, width, continuation)
    end
end

function Cell(
    grapheme::AbstractString;
    style::Style=Style(),
    width_policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY,
)
    value = String(grapheme)
    width = grapheme_width(width_policy, value)
    width in (1, 2) ||
        throw(ArgumentError("a display grapheme must occupy one or two terminal columns"))
    Cell(value, style, UInt8(width), false)
end

Cell(; style::Style=Style()) = Cell(" ", style, 0x01, false)

continuation_cell(style::Style) = Cell("", style, 0x00, true)
