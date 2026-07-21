# Keybinding help — a single binding source-of-truth that drives help rendering,
# mirroring Bubble Tea's `key.Binding` + `help` bubble.
#
# A `KeyBinding` carries a key label, a human description, and whether it is
# currently enabled. From a list of bindings you derive:
#
#   * `help_hints`  -> `KeyHint`s for the enabled bindings, to feed the existing
#     `Footer` / `HelpView` widgets.
#   * `short_help`  -> a single-line help string, optionally truncated to a width
#     with an overflow marker (the Bubble Tea "short help" view).
#
# Internal, non-exported: reachable as `Wicked.KeyBinding`, `Wicked.help_hints`,
# `Wicked.short_help`. Promote by exporting from `Wicked.API` and adding ledger
# rows; the docstrings satisfy the documentation audit.

"""A keybinding: a key label, its description, and whether it is active.

The single source of truth for help rendering. Build a `Vector{KeyBinding}` once
and derive both the footer hints and the short help line from it, so keys and
their documentation never drift apart.

```julia
bindings = [
    KeyBinding("q", "quit"),
    KeyBinding("s", "save"; enabled = document_dirty),
]
Footer(help_hints(bindings))
short_help(bindings; max_width = width)
```
"""
struct KeyBinding
    key::String
    description::String
    enabled::Bool
end

KeyBinding(key, description; enabled::Bool = true) =
    KeyBinding(string(key), string(description), enabled)

"""Return `KeyHint`s for the enabled bindings (for `Footer` / `HelpView`)."""
help_hints(bindings) =
    KeyHint[KeyHint(binding.key, binding.description) for binding in bindings if binding.enabled]

"""
    short_help(bindings; separator=" • ", max_width=nothing, overflow="…") -> String

Render the enabled bindings as a single-line help string. Each entry is
`"<key> <description>"`, joined by `separator`. When `max_width` is given,
entries are included greedily until the line (plus an `overflow` marker if any
remain) would exceed `max_width` columns; the marker is then appended.
"""
function short_help(
    bindings;
    separator::AbstractString = " • ",
    max_width::Union{Nothing,Integer} = nothing,
    overflow::AbstractString = "…",
)
    entries = String["$(binding.key) $(binding.description)"
                     for binding in bindings if binding.enabled]
    isempty(entries) && return ""
    isnothing(max_width) && return join(entries, separator)
    limit = Int(max_width)
    limit <= 0 && return ""
    marker_cost = text_width(separator) + text_width(overflow)
    included = String[]
    for (index, entry) in enumerate(entries)
        trial = isempty(included) ? entry : join(included, separator) * separator * entry
        more_remain = index < length(entries)
        needed = text_width(trial) + (more_remain ? marker_cost : 0)
        needed <= limit || break
        push!(included, entry)
    end
    if isempty(included)
        return text_width(overflow) <= limit ? String(overflow) : ""
    end
    line = join(included, separator)
    length(included) < length(entries) && (line *= separator * overflow)
    return line
end
