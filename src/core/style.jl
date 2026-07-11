@enum ColorKind::UInt8 begin
    DefaultColorKind
    AnsiColorKind
    IndexedColorKind
    RGBColorKind
end

"""A type-stable terminal color value."""
struct Color
    kind::ColorKind
    value::UInt32

    function Color(kind::ColorKind, value::Integer=0)
        value >= 0 || throw(ArgumentError("color value must be non-negative"))
        value <= typemax(UInt32) || throw(ArgumentError("color value is too large"))
        kind == DefaultColorKind && value != 0 &&
            throw(ArgumentError("default color cannot contain a value"))
        kind == AnsiColorKind && value > 15 &&
            throw(ArgumentError("ANSI color index must be between 0 and 15"))
        kind == IndexedColorKind && value > 255 &&
            throw(ArgumentError("indexed color must be between 0 and 255"))
        kind == RGBColorKind && value > 0x00ffffff &&
            throw(ArgumentError("RGB color value must contain at most 24 bits"))
        new(kind, UInt32(value))
    end
end

DefaultColor() = Color(DefaultColorKind)
AnsiColor(index::Integer) = Color(AnsiColorKind, index)
IndexedColor(index::Integer) = Color(IndexedColorKind, index)
RGBColor(red::Integer, green::Integer, blue::Integer) = begin
    all(channel -> 0 <= channel <= 255, (red, green, blue)) ||
        throw(ArgumentError("RGB channels must be between 0 and 255"))
    Color(RGBColorKind, (UInt32(red) << 16) | (UInt32(green) << 8) | UInt32(blue))
end

"""A compact set of terminal text modifiers."""
struct Modifiers
    bits::UInt16
end

Modifiers() = Modifiers(0x0000)

const BOLD = Modifiers(0x0001)
const DIM = Modifiers(0x0002)
const ITALIC = Modifiers(0x0004)
const UNDERLINE = Modifiers(0x0008)
const DOUBLE_UNDERLINE = Modifiers(0x0010)
const BLINK = Modifiers(0x0020)
const REVERSED = Modifiers(0x0040)
const HIDDEN = Modifiers(0x0080)
const STRIKETHROUGH = Modifiers(0x0100)

Base.:|(left::Modifiers, right::Modifiers) = Modifiers(left.bits | right.bits)
Base.:&(left::Modifiers, right::Modifiers) = Modifiers(left.bits & right.bits)
Base.:~(modifiers::Modifiers) = Modifiers(~modifiers.bits)
Base.isempty(modifiers::Modifiers) = iszero(modifiers.bits)
Base.in(modifier::Modifiers, modifiers::Modifiers) =
    (modifiers.bits & modifier.bits) == modifier.bits

"""A resolved terminal style."""
struct Style
    foreground::Color
    background::Color
    underline_color::Color
    modifiers::Modifiers
    hyperlink::Union{Nothing,String}
end

Style(;
    foreground::Color=DefaultColor(),
    background::Color=DefaultColor(),
    underline_color::Color=DefaultColor(),
    modifiers::Modifiers=Modifiers(),
    hyperlink::Union{Nothing,AbstractString}=nothing,
) = Style(
    foreground,
    background,
    underline_color,
    modifiers,
    isnothing(hyperlink) ? nothing : String(hyperlink),
)

"""A partial style update that preserves unspecified properties."""
struct StylePatch
    foreground::Union{Nothing,Color}
    background::Union{Nothing,Color}
    underline_color::Union{Nothing,Color}
    add_modifiers::Modifiers
    remove_modifiers::Modifiers
    hyperlink::Union{Missing,Nothing,String}
end

StylePatch(;
    foreground::Union{Nothing,Color}=nothing,
    background::Union{Nothing,Color}=nothing,
    underline_color::Union{Nothing,Color}=nothing,
    add_modifiers::Modifiers=Modifiers(),
    remove_modifiers::Modifiers=Modifiers(),
    hyperlink::Union{Missing,Nothing,AbstractString}=missing,
) = StylePatch(
    foreground,
    background,
    underline_color,
    add_modifiers,
    remove_modifiers,
    ismissing(hyperlink) ? missing : isnothing(hyperlink) ? nothing : String(hyperlink),
)

Base.isempty(patch::StylePatch) =
    patch.foreground === nothing &&
    patch.background === nothing &&
    patch.underline_color === nothing &&
    isempty(patch.add_modifiers) &&
    isempty(patch.remove_modifiers) &&
    ismissing(patch.hyperlink)

"""Apply a partial style update to a resolved style."""
function apply(style::Style, patch::StylePatch)
    modifiers = Modifiers(
        (style.modifiers.bits | patch.add_modifiers.bits) & ~patch.remove_modifiers.bits,
    )
    hyperlink = ismissing(patch.hyperlink) ? style.hyperlink : patch.hyperlink
    Style(
        foreground=something(patch.foreground, style.foreground),
        background=something(patch.background, style.background),
        underline_color=something(patch.underline_color, style.underline_color),
        modifiers=modifiers,
        hyperlink=hyperlink,
    )
end
