"""A compact set of enabled block borders."""
struct BorderSet
    bits::UInt8
end

const NoBorders = BorderSet(0x00)
const TopBorder = BorderSet(0x01)
const RightBorder = BorderSet(0x02)
const BottomBorder = BorderSet(0x04)
const LeftBorder = BorderSet(0x08)
const AllBorders = BorderSet(0x0f)

Base.:|(left::BorderSet, right::BorderSet) = BorderSet(left.bits | right.bits)
Base.in(border::BorderSet, borders::BorderSet) = (borders.bits & border.bits) == border.bits

"""Graphemes used to draw a bordered surface."""
struct BorderSymbols
    horizontal::String
    vertical::String
    top_left::String
    top_right::String
    bottom_left::String
    bottom_right::String

    function BorderSymbols(values::Vararg{AbstractString,6})
        resolved = String[String(value) for value in values]
        for value in resolved
            graphemes = collect(Unicode.graphemes(value))
            length(graphemes) == 1 &&
                grapheme_width(DEFAULT_WIDTH_POLICY, only(graphemes)) == 1 ||
                throw(ArgumentError("border symbols must be single-cell graphemes"))
        end
        new(resolved...)
    end
end

const ASCII_BORDERS = BorderSymbols("-", "|", "+", "+", "+", "+")
const ROUNDED_BORDERS = BorderSymbols("─", "│", "╭", "╮", "╰", "╯")
const DOUBLE_BORDERS = BorderSymbols("═", "║", "╔", "╗", "╚", "╝")

"""A border, title, and padding surface."""
struct Block
    title::Union{Nothing,Line}
    borders::BorderSet
    symbols::BorderSymbols
    border_style::Style
    title_style::Style
    padding::Margin
end

function Block(;
    title::Union{Nothing,AbstractString,Line}=nothing,
    borders::BorderSet=AllBorders,
    symbols::BorderSymbols=ROUNDED_BORDERS,
    border_style::Style=Style(),
    title_style::Style=border_style,
    padding::Margin=Margin(0),
)
    resolved_title = isnothing(title) ? nothing :
                     title isa Line ? title : Line(title; style=title_style)
    Block(resolved_title, borders, symbols, border_style, title_style, padding)
end

"""Return the content region inside a block's enabled borders and padding."""
function inner(block::Block, area::Rect)
    border_margin = Margin(
        TopBorder in block.borders ? 1 : 0,
        RightBorder in block.borders ? 1 : 0,
        BottomBorder in block.borders ? 1 : 0,
        LeftBorder in block.borders ? 1 : 0,
    )
    inset(inset(area, border_margin), block.padding)
end

function measure(block::Block, available::Rect)
    height = block.padding.top + block.padding.bottom +
             (TopBorder in block.borders ? 1 : 0) +
             (BottomBorder in block.borders ? 1 : 0)
    width = block.padding.left + block.padding.right +
            (LeftBorder in block.borders ? 1 : 0) +
            (RightBorder in block.borders ? 1 : 0)
    if block.title !== nothing
        title_width = sum(span -> text_width(span.content), block.title.spans; init=0)
        width = max(width, title_width + 4)
        height = max(height, 1)
    end
    return Size(min(available.height, height), min(available.width, width))
end

function _put!(buffer::Buffer, row::Int, column::Int, grapheme::String, style::Style, area::Rect)
    position = Position(row, column)
    contains(intersection(buffer.area, area), position) || return
    grapheme_width(DEFAULT_WIDTH_POLICY, grapheme) == 1 || return
    buffer[row, column] = Cell(grapheme; style)
end

function render!(buffer::Buffer, block::Block, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    top = area.row
    bottom = area.row + area.height - 1
    left = area.column
    right = area.column + area.width - 1
    if TopBorder in block.borders && area.height > 0
        for column in max(left, active.column):min(right, active.column + active.width - 1)
            _put!(buffer, top, column, block.symbols.horizontal, block.border_style, active)
        end
    end
    if BottomBorder in block.borders && area.height > 0
        for column in max(left, active.column):min(right, active.column + active.width - 1)
            _put!(buffer, bottom, column, block.symbols.horizontal, block.border_style, active)
        end
    end
    if LeftBorder in block.borders && area.width > 0
        for row in max(top, active.row):min(bottom, active.row + active.height - 1)
            _put!(buffer, row, left, block.symbols.vertical, block.border_style, active)
        end
    end
    if RightBorder in block.borders && area.width > 0
        for row in max(top, active.row):min(bottom, active.row + active.height - 1)
            _put!(buffer, row, right, block.symbols.vertical, block.border_style, active)
        end
    end
    TopBorder in block.borders && LeftBorder in block.borders &&
        _put!(buffer, top, left, block.symbols.top_left, block.border_style, active)
    TopBorder in block.borders && RightBorder in block.borders &&
        _put!(buffer, top, right, block.symbols.top_right, block.border_style, active)
    BottomBorder in block.borders && LeftBorder in block.borders &&
        _put!(buffer, bottom, left, block.symbols.bottom_left, block.border_style, active)
    BottomBorder in block.borders && RightBorder in block.borders &&
        _put!(buffer, bottom, right, block.symbols.bottom_right, block.border_style, active)
    if !isnothing(block.title) && TopBorder in block.borders && area.width > 4
        title_area = Rect(top, left + 2, 1, max(0, area.width - 4))
        draw_line!(buffer, top, intersection(active, title_area), block.title)
    end
    buffer
end

struct Clear
    cell::Cell
end

Clear(; style::Style=Style()) = Clear(Cell(; style))

function render!(buffer::Buffer, widget::Clear, area::Rect)
    active = intersection(buffer.area, area)
    for row in active.row:(active.row + active.height - 1),
        column in active.column:(active.column + active.width - 1)
        buffer[row, column] = widget.cell
    end
    buffer
end

measure(::Clear, available::Rect) = Size(available.height, available.width)

struct Spacer end
render!(buffer::Buffer, ::Spacer, ::Rect) = buffer
measure(::Spacer, ::Rect) = Size(0, 0)

@enum RuleDirection::UInt8 begin
    HorizontalRule
    VerticalRule
end

struct Rule
    direction::RuleDirection
    symbol::String
    style::Style
end

function Rule(
    direction::RuleDirection=HorizontalRule;
    symbol::AbstractString="─",
    style::Style=Style(),
)
    graphemes = collect(Unicode.graphemes(symbol))
    length(graphemes) == 1 &&
        grapheme_width(DEFAULT_WIDTH_POLICY, only(graphemes)) == 1 ||
        throw(ArgumentError("rule symbol must be a single-cell grapheme"))
    return Rule(direction, String(symbol), style)
end

measure(rule::Rule, available::Rect) = rule.direction == HorizontalRule ?
    Size(min(available.height, 1), available.width) :
    Size(available.height, min(available.width, 1))

function render!(buffer::Buffer, rule::Rule, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    if rule.direction == HorizontalRule
        row = active.row + div(active.height - 1, 2)
        for column in active.column:(active.column + active.width - 1)
            _put!(buffer, row, column, rule.symbol, rule.style, active)
        end
    else
        column = active.column + div(active.width - 1, 2)
        for row in active.row:(active.row + active.height - 1)
            _put!(buffer, row, column, rule.symbol, rule.style, active)
        end
    end
    buffer
end
