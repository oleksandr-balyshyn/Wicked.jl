"""Policy interface for mapping a grapheme cluster to terminal columns."""
abstract type AbstractWidthPolicy end

"""Use Julia's Unicode width with a configurable East Asian ambiguous width."""
struct UnicodeWidthPolicy <: AbstractWidthPolicy
    ambiguous_width::UInt8

    function UnicodeWidthPolicy(ambiguous_width::Integer=1)
        ambiguous_width in (1, 2) ||
            throw(ArgumentError("ambiguous width must be 1 or 2"))
        new(UInt8(ambiguous_width))
    end
end

const DEFAULT_WIDTH_POLICY = UnicodeWidthPolicy()

"""Return the terminal width of one extended grapheme cluster."""
function grapheme_width(::AbstractWidthPolicy, grapheme::AbstractString)
    isempty(grapheme) && return 0
    width = textwidth(grapheme)
    clamp(width, 0, 2)
end

"""Return the terminal width of a string by extended grapheme cluster."""
function text_width(text::AbstractString, policy::AbstractWidthPolicy=DEFAULT_WIDTH_POLICY)
    sum(grapheme -> grapheme_width(policy, grapheme), Unicode.graphemes(text); init=0)
end

@enum HorizontalAlignment::UInt8 begin
    LeftAlign
    CenterAlign
    RightAlign
end

"""A styled run of text."""
struct Span
    content::String
    style::Style
end

Span(content::AbstractString; style::Style=Style()) = Span(String(content), style)

"""A sequence of styled spans with horizontal alignment."""
struct Line
    spans::Vector{Span}
    alignment::HorizontalAlignment
end

Line(spans::AbstractVector{Span}; alignment::HorizontalAlignment=LeftAlign) =
    Line(collect(spans), alignment)
Line(content::AbstractString; style::Style=Style(), alignment::HorizontalAlignment=LeftAlign) =
    Line([Span(content; style)], alignment)

"""A sequence of styled terminal lines."""
struct Text
    lines::Vector{Line}
end

Text(lines::AbstractVector{Line}) = Text(collect(lines))
Text(content::AbstractString; style::Style=Style(), alignment::HorizontalAlignment=LeftAlign) =
    Text([Line(line; style, alignment) for line in split(String(content), '\n'; keepempty=true)])
