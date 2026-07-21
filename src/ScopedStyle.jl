# Scoped styling DSL — Terminus-inspired nested style combinators that build a
# native Wicked `Text`.
#
# This is an ergonomic layer over the existing `Text`/`Line`/`Span`/`Style`
# model. It combines ideas from several toolkits:
#
#   * Terminus (Scala 3): scoped, nestable `foreground.green { ... }` combinators
#     that apply a style to everything emitted in the block and restore the
#     previous style on exit.
#   * Ratatui `Stylize` / Lip Gloss: fluent color + modifier styling.
#   * Jetpack Compose modifiers: reusable, composable style scopes.
#
# The result is a `Text` value, so it renders anywhere Wicked already accepts
# rich text (for example `Paragraph`, `Static`, `TextView`).
#
# These bindings are intentionally NOT exported yet. They live in the `Wicked`
# module and are reachable as `Wicked.styled_text`, `Wicked.styled`, etc. To
# promote them to the stable public surface, export them from `Wicked.API`, add
# matching rows to `api/stable_api.tsv` (and the root baseline), and keep the
# docstrings below as their discoverable documentation.

"""Mutable accumulator used while building a `Text` with scoped style combinators.

Holds the finished lines, the spans of the line currently being built, and a
stack of styles. The top of the stack is the style applied to newly emitted
text; `styled` pushes a merged style and pops it when its block returns.
"""
mutable struct StyledTextBuilder
    lines::Vector{Line}
    spans::Vector{Span}
    stack::Vector{Style}
end

StyledTextBuilder() = StyledTextBuilder(Line[], Span[], Style[Style()])

_scoped_current_style(builder::StyledTextBuilder) = builder.stack[end]

function _scoped_resolve_color(value)
    value isa Color && return value
    value isa Symbol && return parse_color(String(value))
    value isa AbstractString && return parse_color(value)
    throw(ArgumentError("scoped style color must be a Color, Symbol, or String"))
end

function _scoped_merge_style(
    base::Style;
    fg=nothing,
    bg=nothing,
    underline_color=nothing,
    bold::Bool=false,
    dim::Bool=false,
    italic::Bool=false,
    underline::Bool=false,
    reverse::Bool=false,
    strikethrough::Bool=false,
    blink::Bool=false,
)
    add = Modifiers()
    bold && (add |= BOLD)
    dim && (add |= DIM)
    italic && (add |= ITALIC)
    underline && (add |= UNDERLINE)
    reverse && (add |= REVERSED)
    strikethrough && (add |= STRIKETHROUGH)
    blink && (add |= BLINK)
    Style(;
        foreground=fg === nothing ? base.foreground : _scoped_resolve_color(fg),
        background=bg === nothing ? base.background : _scoped_resolve_color(bg),
        underline_color=underline_color === nothing ? base.underline_color :
                        _scoped_resolve_color(underline_color),
        modifiers=base.modifiers | add,
        hyperlink=base.hyperlink,
    )
end

"""
    styled(block, builder; fg, bg, bold, dim, italic, underline, reverse, ...)

Apply a merged style to everything `block` emits into `builder`, then restore
the previous style. Scopes nest: an inner `styled` merges its options onto the
enclosing style, so `styled(b; bold=true) do; styled(b; fg=:green) do ... end`
produces bold-green text. Returns `builder` for chaining.

```julia
text = styled_text() do b
    styled(b; fg=:cyan, bold=true) do
        emit!(b, "Deploy ")
        styled(b; fg=:green) do
            emit!(b, "ready")
        end
    end
    newline!(b)
    styled(b; dim=true) do
        emit!(b, "press q to quit")
    end
end
```
"""
function styled(block, builder::StyledTextBuilder; kwargs...)
    push!(builder.stack, _scoped_merge_style(_scoped_current_style(builder); kwargs...))
    try
        block()
    finally
        pop!(builder.stack)
    end
    return builder
end

"""
    emit!(builder, content; kwargs...)

Emit inline text into `builder`. With no keywords the text uses the current
scoped style; with keywords (`fg`, `bold`, …) it is wrapped in a one-shot
`styled` scope so `emit!(builder, "text"; fg=:red)` styles just that fragment.
"""
function emit!(builder::StyledTextBuilder, content::AbstractString; kwargs...)
    if isempty(kwargs)
        isempty(content) ||
            push!(builder.spans, Span(content; style=_scoped_current_style(builder)))
        return builder
    end
    return styled(builder; kwargs...) do
        emit!(builder, content)
    end
end

"""Finish the current line in `builder` and begin a new one."""
function newline!(builder::StyledTextBuilder)
    push!(builder.lines, Line(copy(builder.spans)))
    empty!(builder.spans)
    return builder
end

"""
    styled_text(block) -> Text

Build a Wicked `Text` using nested scoped-style combinators. `block` receives a
[`StyledTextBuilder`](@ref); use [`styled`](@ref), [`emit!`](@ref), and
[`newline!`](@ref) inside it. Trailing spans are flushed into a final line.
"""
function styled_text(block)
    builder = StyledTextBuilder()
    block(builder)
    if !isempty(builder.spans) || isempty(builder.lines)
        push!(builder.lines, Line(copy(builder.spans)))
    end
    return Text(builder.lines)
end
