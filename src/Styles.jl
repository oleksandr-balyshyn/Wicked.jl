module Styles

using ..Core

"""A named collection of semantic terminal styles."""
struct Theme
    name::Symbol
    roles::Dict{Symbol,Style}
end

Theme(name::Symbol; roles=Dict{Symbol,Style}()) =
    Theme(name, Dict{Symbol,Style}(Symbol(key) => value for (key, value) in roles))

const DEFAULT_THEME = Theme(
    :default;
    roles=Dict(
        :text => Style(),
        :muted => Style(modifiers=DIM),
        :primary => Style(foreground=AnsiColor(6)),
        :success => Style(foreground=AnsiColor(2)),
        :warning => Style(foreground=AnsiColor(3)),
        :error => Style(foreground=AnsiColor(1)),
        :focus => Style(modifiers=REVERSED),
        :selected => Style(modifiers=REVERSED | BOLD),
        :disabled => Style(modifiers=DIM),
    ),
)

theme_style(theme::Theme, role::Symbol) = get(theme.roles, role) do
    throw(KeyError(role))
end

"""Widget metadata used to match stylesheet selectors."""
struct StyleContext
    widget_type::Any
    id::Any
    classes::Set{Symbol}
    states::Set{Symbol}
    ancestor_classes::Set{Symbol}
end

"""A deliberately small CSS-like selector."""
struct Selector
    widget_type::Any
    id::Any
    classes::Set{Symbol}
    states::Set{Symbol}
    ancestor_classes::Set{Symbol}
end

function Selector(;
    widget_type=nothing,
    id=nothing,
    classes=Symbol[],
    states=Symbol[],
    ancestor_classes=Symbol[],
)
    class_values = Symbol[Symbol(value) for value in classes]
    state_values = Symbol[Symbol(value) for value in states]
    ancestor_values = Symbol[Symbol(value) for value in ancestor_classes]
    length(unique(class_values)) == length(class_values) ||
        throw(ArgumentError("selector classes cannot contain duplicates"))
    length(unique(state_values)) == length(state_values) ||
        throw(ArgumentError("selector states cannot contain duplicates"))
    length(unique(ancestor_values)) == length(ancestor_values) ||
        throw(ArgumentError("selector ancestor classes cannot contain duplicates"))
    Selector(
        widget_type,
        id,
        Set{Symbol}(class_values),
        Set{Symbol}(state_values),
        Set{Symbol}(ancestor_values),
    )
end

function _type_matches(selector_type, widget_type)
    isnothing(selector_type) && return true
    isnothing(widget_type) && return false
    resolved_widget_type = widget_type isa Type || widget_type isa UnionAll ?
        widget_type : typeof(widget_type)
    selector_type isa Symbol && return nameof(resolved_widget_type) == selector_type
    try
        resolved_widget_type <: selector_type
    catch
        resolved_widget_type == selector_type
    end
end

"""One source-located stylesheet diagnostic."""
struct StyleDiagnostic
    severity::Symbol
    message::String
    source::String
    line::Int
    column::Int
end

struct StylesheetParseError <: Exception
    diagnostics::Vector{StyleDiagnostic}
end

function Base.showerror(io::IO, error::StylesheetParseError)
    print(io, "stylesheet contains ", length(error.diagnostics), " error(s)")
    for diagnostic in error.diagnostics
        print(
            io,
            "\n", diagnostic.source, ':', diagnostic.line, ':', diagnostic.column,
            ": ", diagnostic.message,
        )
    end
end

const _NAMED_COLORS = Dict(
    "black" => 0,
    "red" => 1,
    "green" => 2,
    "yellow" => 3,
    "blue" => 4,
    "magenta" => 5,
    "cyan" => 6,
    "white" => 7,
    "bright-black" => 8,
    "bright-red" => 9,
    "bright-green" => 10,
    "bright-yellow" => 11,
    "bright-blue" => 12,
    "bright-magenta" => 13,
    "bright-cyan" => 14,
    "bright-white" => 15,
)

"""Parse default, named ANSI, indexed, hexadecimal, or RGB color syntax."""
function parse_color(value::AbstractString)
    text = lowercase(strip(value))
    text == "default" && return DefaultColor()
    haskey(_NAMED_COLORS, text) && return AnsiColor(_NAMED_COLORS[text])
    if startswith(text, '#') && length(text) == 7
        parsed = tryparse(UInt32, text[2:end]; base=16)
        isnothing(parsed) && throw(ArgumentError("invalid hexadecimal color: $value"))
        return RGBColor((parsed >> 16) & 0xff, (parsed >> 8) & 0xff, parsed & 0xff)
    end
    indexed = match(r"^indexed\((\d+)\)$", text)
    !isnothing(indexed) && return IndexedColor(parse(Int, indexed.captures[1]))
    rgb = match(r"^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$", text)
    !isnothing(rgb) && return RGBColor(parse.(Int, rgb.captures)...)
    throw(ArgumentError("unsupported color value: $value"))
end

function _modifier(name::AbstractString)
    normalized = lowercase(strip(name))
    normalized == "bold" && return BOLD
    normalized == "dim" && return DIM
    normalized == "italic" && return ITALIC
    normalized == "underline" && return UNDERLINE
    normalized == "double-underline" && return DOUBLE_UNDERLINE
    normalized == "blink" && return BLINK
    normalized == "reverse" && return REVERSED
    normalized == "hidden" && return HIDDEN
    normalized == "strikethrough" && return STRIKETHROUGH
    throw(ArgumentError("unsupported text modifier: $name"))
end

function _parse_modifiers(value::AbstractString)
    result = Modifiers()
    for name in split(replace(strip(value), ',' => ' '))
        isempty(name) || (result = result | _modifier(name))
    end
    result
end

function _line_column(text::String, offset::Int)
    prefix = SubString(text, firstindex(text), prevind(text, offset))
    line = count(==('\n'), prefix) + 1
    last_newline = findlast(==('\n'), prefix)
    column = isnothing(last_newline) ? length(prefix) + 1 :
             length(SubString(prefix, nextind(prefix, last_newline))) + 1
    line, column
end

function _selector_token(token::AbstractString; ancestor::Bool=false)
    widget_type = nothing
    id = nothing
    classes = Symbol[]
    states = Symbol[]
    index = firstindex(token)
    type_match = match(r"^[A-Za-z_][A-Za-z0-9_]*", token)
    if !isnothing(type_match)
        widget_type = Symbol(type_match.match)
        index = nextind(token, lastindex(type_match.match))
    end
    while index <= lastindex(token)
        marker = token[index]
        marker in ('#', '.', ':') || throw(ArgumentError("invalid selector near: $(token[index:end])"))
        start = nextind(token, index)
        finish = start
        while finish <= lastindex(token) &&
                (isletter(token[finish]) || isnumeric(token[finish]) || token[finish] in ('_', '-'))
            finish = nextind(token, finish)
        end
        start == finish && throw(ArgumentError("empty selector component"))
        value = Symbol(token[start:prevind(token, finish)])
        if marker == '#'
            isnothing(id) || throw(ArgumentError("selector cannot contain multiple IDs"))
            id = value
        elseif marker == '.'
            value in classes && throw(ArgumentError("selector cannot repeat class .$value"))
            push!(classes, value)
        else
            value in states && throw(ArgumentError("selector cannot repeat state :$value"))
            push!(states, value)
        end
        index = finish
    end
    ancestor && (!isnothing(widget_type) || !isnothing(id) || !isempty(states)) &&
        throw(ArgumentError("ancestor selector currently supports classes only"))
    widget_type, id, classes, states
end

function _parse_selector(value::AbstractString)
    tokens = split(strip(value))
    isempty(tokens) && throw(ArgumentError("selector cannot be empty"))
    length(tokens) > 2 && throw(ArgumentError("only one ancestor selector is supported"))
    ancestor_classes = Symbol[]
    if length(tokens) == 2
        _, _, ancestor_classes, _ = _selector_token(tokens[1]; ancestor=true)
    end
    widget_type, id, classes, states = _selector_token(last(tokens))
    Selector(; widget_type, id, classes, states, ancestor_classes)
end

function _parse_declarations(body::AbstractString)
    foreground = nothing
    background = nothing
    underline_color = nothing
    add_modifiers = Modifiers()
    remove_modifiers = Modifiers()
    hyperlink = missing
    for declaration in split(body, ';')
        text = strip(declaration)
        isempty(text) && continue
        pair = split(text, ':'; limit=2)
        length(pair) == 2 || throw(ArgumentError("declaration must contain ':'"))
        property = lowercase(strip(pair[1]))
        value = strip(pair[2])
        if property == "foreground" || property == "color"
            foreground = parse_color(value)
        elseif property == "background"
            background = parse_color(value)
        elseif property == "underline-color"
            underline_color = parse_color(value)
        elseif property in ("modifiers", "add-modifiers")
            add_modifiers = _parse_modifiers(value)
        elseif property == "remove-modifiers"
            remove_modifiers = _parse_modifiers(value)
        elseif property == "hyperlink"
            hyperlink = lowercase(value) in ("none", "unset") ? nothing : value
        else
            throw(ArgumentError("unsupported style property: $property"))
        end
    end
    StylePatch(;
        foreground,
        background,
        underline_color,
        add_modifiers,
        remove_modifiers,
        hyperlink,
    )
end

function _strip_comments(text::String)
    replace(text, r"/\*.*?\*/"s => matched -> replace(matched, r"[^\n]" => " "))
end

"""Parse a strict external Wicked stylesheet and return diagnostics without throwing."""
function try_parse_stylesheet(
    input::AbstractString;
    source::AbstractString="<memory>",
)
    original = String(input)
    text = _strip_comments(original)
    stylesheet = Stylesheet()
    diagnostics = StyleDiagnostic[]
    consumed = falses(ncodeunits(text))
    for matched in eachmatch(r"([^{}]+)\{([^{}]*)\}"s, text)
        selector_text = strip(matched.captures[1])
        body = matched.captures[2]
        offset = matched.offset
        line, column = _line_column(text, offset)
        for index in offset:(offset + ncodeunits(matched.match) - 1)
            index <= length(consumed) && (consumed[index] = true)
        end
        try
            patch = _parse_declarations(body)
            selectors = Selector[
                _parse_selector(selector_value) for selector_value in split(selector_text, ',')
            ]
            for selector in selectors
                add_rule!(stylesheet, selector, patch)
            end
        catch error
            push!(
                diagnostics,
                StyleDiagnostic(:error, sprint(showerror, error), String(source), line, column),
            )
        end
    end
    remainder = String(UInt8[
        codeunits(text)[index] for index in eachindex(consumed)
        if !consumed[index] && !isspace(Char(codeunits(text)[index]))
    ])
    !isempty(remainder) && push!(
        diagnostics,
        StyleDiagnostic(:error, "unparsed stylesheet content", String(source), 1, 1),
    )
    stylesheet, diagnostics
end

"""Parse a stylesheet, throwing source diagnostics when any rule is invalid."""
function parse_stylesheet(input::AbstractString; source::AbstractString="<memory>")
    stylesheet, diagnostics = try_parse_stylesheet(input; source)
    isempty(diagnostics) || throw(StylesheetParseError(diagnostics))
    stylesheet
end

load_stylesheet(path::AbstractString) =
    parse_stylesheet(read(path, String); source=String(path))

"""Return whether a selector applies to a style context."""
function matches(selector::Selector, context::StyleContext)
    _type_matches(selector.widget_type, context.widget_type) || return false
    !isnothing(selector.id) && selector.id != context.id && return false
    issubset(selector.classes, context.classes) || return false
    issubset(selector.states, context.states) || return false
    issubset(selector.ancestor_classes, context.ancestor_classes)
end

specificity(selector::Selector) = (
    isnothing(selector.id) ? 0 : 1,
    length(selector.classes) + length(selector.states) + length(selector.ancestor_classes),
    isnothing(selector.widget_type) ? 0 : 1,
)

struct StyleRule
    selector::Selector
    patch::StylePatch
    order::Int
end

mutable struct Stylesheet
    rules::Vector{StyleRule}
    next_order::Int
end

Stylesheet() = Stylesheet(StyleRule[], 1)

function add_rule!(stylesheet::Stylesheet, selector::Selector, patch::StylePatch)
    stylesheet.next_order == typemax(Int) && throw(OverflowError("stylesheet rule order overflow"))
    push!(stylesheet.rules, StyleRule(selector, patch, stylesheet.next_order))
    stylesheet.next_order += 1
    stylesheet
end

function remove_rule!(stylesheet::Stylesheet, index::Integer)
    checkbounds(stylesheet.rules, Int(index))
    deleteat!(stylesheet.rules, Int(index))
    stylesheet
end

"""A theme and ordered set of application stylesheets."""
mutable struct StyleEngine
    theme::Theme
    stylesheets::Vector{Stylesheet}
    revision::UInt64
end

StyleEngine(; theme::Theme=DEFAULT_THEME, stylesheets=Stylesheet[]) =
    StyleEngine(theme, Stylesheet[stylesheets...], 0)

function set_theme!(engine::StyleEngine, theme::Theme)
    engine.revision == typemax(UInt64) && throw(OverflowError("style engine revision overflow"))
    engine.theme = theme
    engine.revision += 1
    engine
end

function add_stylesheet!(engine::StyleEngine, stylesheet::Stylesheet)
    engine.revision == typemax(UInt64) && throw(OverflowError("style engine revision overflow"))
    push!(engine.stylesheets, stylesheet)
    engine.revision += 1
    engine
end

function _matching_rules(engine::StyleEngine, context::StyleContext)
    ranked = Tuple{StyleRule,Int}[]
    for (stylesheet_index, stylesheet) in enumerate(engine.stylesheets), rule in stylesheet.rules
        matches(rule.selector, context) && push!(ranked, (rule, stylesheet_index))
    end
    sort!(ranked; by=item -> (specificity(item[1].selector), item[2], item[1].order))
    return StyleRule[item[1] for item in ranked]
end

function _style_patch(style::Style)
    StylePatch(
        foreground=style.foreground,
        background=style.background,
        underline_color=style.underline_color,
        add_modifiers=style.modifiers,
        hyperlink=style.hyperlink,
    )
end

"""Resolve theme role, matched rules, and inline style over a base cell style."""
function computed_style(
    engine::StyleEngine,
    context::StyleContext,
    base::Style=Style();
    role::Union{Nothing,Symbol}=nothing,
    inline::StylePatch=StylePatch(),
)
    result = base
    !isnothing(role) && (result = apply(result, _style_patch(theme_style(engine.theme, role))))
    for rule in _matching_rules(engine, context)
        result = apply(result, rule.patch)
    end
    apply(result, inline)
end

"""Apply computed component style to existing cells in a region."""
function apply_style!(
    buffer::Buffer,
    area::Rect,
    engine::StyleEngine,
    context::StyleContext;
    role::Union{Nothing,Symbol}=nothing,
    inline::StylePatch=StylePatch(),
)
    active = intersection(buffer.area, area)
    for row in active.row:(active.row + active.height - 1),
        column in active.column:(active.column + active.width - 1)
        cell = buffer[row, column]
        cell.continuation && continue
        style = computed_style(engine, context, cell.style; role, inline)
        buffer[row, column] = Cell(
            cell.grapheme;
            style,
            width_policy=DEFAULT_WIDTH_POLICY,
        )
    end
    buffer
end

export DEFAULT_THEME,
       Selector,
       StyleContext,
       StyleEngine,
       StyleRule,
       StyleDiagnostic,
       Stylesheet,
       StylesheetParseError,
       Theme,
       add_rule!,
       add_stylesheet!,
       apply_style!,
       computed_style,
       matches,
       load_stylesheet,
       parse_color,
       parse_stylesheet,
       remove_rule!,
       set_theme!,
       specificity,
       theme_style,
       try_parse_stylesheet

end
