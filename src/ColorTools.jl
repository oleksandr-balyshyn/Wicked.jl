# Color tooling — adaptive light/dark colors and profile downsampling.
#
# These bring Lip Gloss-style ergonomics to Wicked's `Color` model:
#
#   * `adaptive_color` picks a light- or dark-background variant, mirroring Lip
#     Gloss `AdaptiveColor`.
#   * `downsample_color` reduces a truecolor `Color` to a lower terminal profile
#     (`:ansi256` / `:ansi16` / `:none`), returning a `Color` value. It reuses
#     the exact quantisation the ANSI backend applies when emitting SGR codes
#     (the 6×6×6 color cube for 256-color, and an intensity+dominant-channel
#     mapping for 16-color), so a pre-downsampled color renders identically to
#     letting the backend degrade it.
#
# Internal, non-exported: reachable as `Wicked.adaptive_color` /
# `Wicked.downsample_color`. Promote by exporting from `Wicked.API` and adding
# ledger rows; the docstrings satisfy the documentation audit.

"""
    adaptive_color(light, dark; dark_background=true) -> Color

Return `dark` when rendering on a dark terminal background and `light`
otherwise, mirroring Lip Gloss `AdaptiveColor`. `light`/`dark` may be `Color`
values or any value accepted by [`parse_color`](@ref) (a named/hex/rgb string).
"""
function adaptive_color(light, dark; dark_background::Bool = true)
    chosen = dark_background ? dark : light
    chosen isa Color && return chosen
    chosen isa Symbol && return parse_color(String(chosen))
    chosen isa AbstractString && return parse_color(chosen)
    throw(ArgumentError("adaptive_color variants must be a Color, Symbol, or String"))
end

_rgb_channels(color::Color) = (
    Int((color.value >> 16) & 0xff),
    Int((color.value >> 8) & 0xff),
    Int(color.value & 0xff),
)

function _rgb_to_ansi256(red::Int, green::Int, blue::Int)
    16 + 36 * round(Int, red / 255 * 5) +
    6 * round(Int, green / 255 * 5) +
    round(Int, blue / 255 * 5)
end

function _rgb_to_ansi16(red::Int, green::Int, blue::Int)
    intensity = (red + green + blue) ÷ 3 >= 128 ? 8 : 0
    dominant = (red >= 128 ? 1 : 0) + (green >= 128 ? 2 : 0) + (blue >= 128 ? 4 : 0)
    intensity + dominant
end

"""
    downsample_color(color, level) -> Color

Reduce `color` to the terminal color `level`, returning a `Color` that renders
the same as letting the backend degrade the original. `level` is one of
`:truecolor` (unchanged), `:ansi256`, `:ansi16`, or `:none` (the default color).

Named/16-color and indexed colors are preserved where the level allows and
folded into the 16-color range for `:ansi16`; RGB colors are quantised with the
same math the ANSI backend uses.
"""
function downsample_color(color::Color, level::Symbol)
    level in (:truecolor, :ansi256, :ansi16, :none) ||
        throw(ArgumentError("color level must be :truecolor, :ansi256, :ansi16, or :none"))
    level === :none && return DefaultColor()
    # Color kinds follow the `ColorKind` enum ordering used across the backend:
    # 0 default, 1 ANSI (16-color), 2 indexed (256-color), 3 RGB (truecolor).
    kind = UInt8(color.kind)
    if kind == 0
        return color
    elseif kind == 1
        # 16-color names are valid at every non-:none level.
        return color
    elseif kind == 2
        level === :ansi16 && return AnsiColor(Int(color.value) % 16)
        return color
    end
    # RGB color.
    red, green, blue = _rgb_channels(color)
    level === :truecolor && return color
    level === :ansi256 && return IndexedColor(_rgb_to_ansi256(red, green, blue))
    return AnsiColor(_rgb_to_ansi16(red, green, blue))
end
