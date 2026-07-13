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

function _selector_type_text(selector_type)
    isnothing(selector_type) && return ""
    selector_type isa Symbol && return string(selector_type)
    selector_type isa Type && return string(nameof(selector_type))
    selector_type isa UnionAll && return string(nameof(Base.unwrap_unionall(selector_type)))
    return string(selector_type)
end

_style_symbol_list_text(values) =
    join((string(value) for value in sort!(collect(values); by=string)), " ")

"""Return a plain record describing the context used for style matching."""
style_context_record(context::StyleContext) = (
    widget_type=_selector_type_text(context.widget_type),
    id=_style_resolution_value(context.id),
    classes=_style_symbol_list_text(context.classes),
    states=_style_symbol_list_text(context.states),
    ancestor_classes=_style_symbol_list_text(context.ancestor_classes),
)

"""Render a style context as plain text for logs and assertions."""
function style_context_text(context::StyleContext)
    record = style_context_record(context)
    return join((
        "widget_type: $(record.widget_type)",
        "id: $(record.id)",
        "classes: $(record.classes)",
        "states: $(record.states)",
        "ancestor_classes: $(record.ancestor_classes)",
    ), "\n")
end

"""Render a style context as Markdown."""
function style_context_markdown(context::StyleContext)
    record = style_context_record(context)
    return join((
        "| field | value |",
        "|---|---|",
        "| widget_type | $(_style_markdown_escape(record.widget_type)) |",
        "| id | $(_style_markdown_escape(record.id)) |",
        "| classes | $(_style_markdown_escape(record.classes)) |",
        "| states | $(_style_markdown_escape(record.states)) |",
        "| ancestor_classes | $(_style_markdown_escape(record.ancestor_classes)) |",
    ), "\n")
end

"""Render a style context as TSV."""
function style_context_tsv(context::StyleContext)
    record = style_context_record(context)
    return join((
        "field\tvalue",
        "widget_type\t$(_style_tsv_escape(record.widget_type))",
        "id\t$(_style_tsv_escape(record.id))",
        "classes\t$(_style_tsv_escape(record.classes))",
        "states\t$(_style_tsv_escape(record.states))",
        "ancestor_classes\t$(_style_tsv_escape(record.ancestor_classes))",
    ), "\n")
end

"""Render a selector as a compact CSS-like string for diagnostics."""
function selector_text(selector::Selector)
    parts = String[]
    for class in sort!(collect(selector.ancestor_classes); by=string)
        push!(parts, "." * string(class))
    end
    current = _selector_type_text(selector.widget_type)
    !isnothing(selector.id) && (current *= "#" * string(selector.id))
    for class in sort!(collect(selector.classes); by=string)
        current *= "." * string(class)
    end
    for state in sort!(collect(selector.states); by=string)
        current *= ":" * string(state)
    end
    isempty(current) && (current = "*")
    push!(parts, current)
    return join(parts, " ")
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

"""Return selector components that prevent a selector from matching a context."""
function selector_match_reasons(selector::Selector, context::StyleContext)
    reasons = String[]
    _type_matches(selector.widget_type, context.widget_type) ||
        push!(reasons, "widget type")
    !isnothing(selector.id) && selector.id != context.id &&
        push!(reasons, "id")
    issubset(selector.classes, context.classes) ||
        push!(reasons, "classes")
    issubset(selector.states, context.states) ||
        push!(reasons, "states")
    issubset(selector.ancestor_classes, context.ancestor_classes) ||
        push!(reasons, "ancestor classes")
    return reasons
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

"""One ordered step in CSS-like style resolution."""
struct StyleResolutionStep
    source::Symbol
    label::String
    selector::Union{Nothing,Selector}
    patch::StylePatch
    specificity::Tuple{Int,Int,Int}
    stylesheet_index::Union{Nothing,Int}
    order::Union{Nothing,Int}
    before::Style
    after::Style
end

"""Developer-facing explanation of how a component style was resolved."""
struct StyleExplanation
    context::StyleContext
    base::Style
    role::Union{Nothing,Symbol}
    inline::StylePatch
    result::Style
    steps::Vector{StyleResolutionStep}
end

"""Aggregate diagnostics for CSS-like style matching and resolution."""
struct StyleDiagnostics
    context::StyleContext
    explanation::StyleExplanation
    rule_matches::Vector{NamedTuple}
    rule_summary::NamedTuple
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

function _matching_rule_entries(engine::StyleEngine, context::StyleContext)
    ranked = Tuple{StyleRule,Int}[]
    for (stylesheet_index, stylesheet) in enumerate(engine.stylesheets), rule in stylesheet.rules
        matches(rule.selector, context) && push!(ranked, (rule, stylesheet_index))
    end
    sort!(ranked; by=item -> (specificity(item[1].selector), item[2], item[1].order))
    return ranked
end

_matching_rules(engine::StyleEngine, context::StyleContext) =
    StyleRule[item[1] for item in _matching_rule_entries(engine, context)]

function _style_rule_match_record(index::Integer, stylesheet_index::Integer, rule::StyleRule, context::StyleContext)
    reasons = selector_match_reasons(rule.selector, context)
    return (
        index=Int(index),
        stylesheet_index=Int(stylesheet_index),
        order=rule.order,
        selector=rule.selector,
        selector_text=selector_text(rule.selector),
        specificity=specificity(rule.selector),
        matched=isempty(reasons),
        mismatch_reasons=reasons,
        mismatch_reason_text=join(reasons, ", "),
    )
end

"""Return match diagnostics for every stylesheet rule against a style context."""
function style_rule_match_records(engine::StyleEngine, context::StyleContext)
    records = NamedTuple[]
    index = 1
    for (stylesheet_index, stylesheet) in enumerate(engine.stylesheets), rule in stylesheet.rules
        push!(records, _style_rule_match_record(index, stylesheet_index, rule, context))
        index += 1
    end
    return records
end

"""Return only stylesheet rule diagnostics whose selectors match a style context."""
matching_style_rule_records(engine::StyleEngine, context::StyleContext) =
    [record for record in style_rule_match_records(engine, context) if record.matched]

"""Return only stylesheet rule diagnostics whose selectors do not match a style context."""
unmatched_style_rule_records(engine::StyleEngine, context::StyleContext) =
    [record for record in style_rule_match_records(engine, context) if !record.matched]

"""Return total, matched, and unmatched stylesheet rule counts for a style context."""
function style_rule_match_summary(engine::StyleEngine, context::StyleContext)
    records = style_rule_match_records(engine, context)
    matched = count(record -> record.matched, records)
    return (
        total=length(records),
        matched=matched,
        unmatched=length(records) - matched,
    )
end

function _style_rule_match_search_text(record)
    return lowercase(join((
        record.index,
        record.selector_text,
        record.matched,
        record.mismatch_reason_text,
        record.specificity,
        record.stylesheet_index,
        record.order,
    ), " "))
end

"""Return stylesheet rule match records whose selector, match state, reason, specificity, stylesheet, or order matches a query."""
function search_style_rule_match_records(engine::StyleEngine, context::StyleContext, query)
    text = lowercase(strip(string(query)))
    records = style_rule_match_records(engine, context)
    isempty(text) && return records
    return [
        record for record in records
        if occursin(text, _style_rule_match_search_text(record))
    ]
end

"""Count stylesheet rule match records matching a query."""
search_style_rule_match_count(engine::StyleEngine, context::StyleContext, query) =
    length(search_style_rule_match_records(engine, context, query))

function _style_patch(style::Style)
    StylePatch(
        foreground=style.foreground,
        background=style.background,
        underline_color=style.underline_color,
        add_modifiers=style.modifiers,
        hyperlink=style.hyperlink,
    )
end

function _resolution_step(
    source::Symbol,
    label::AbstractString,
    before::Style,
    patch::StylePatch;
    selector::Union{Nothing,Selector}=nothing,
    stylesheet_index::Union{Nothing,Int}=nothing,
    order::Union{Nothing,Int}=nothing,
)
    after = apply(before, patch)
    step = StyleResolutionStep(
        source,
        String(label),
        selector,
        patch,
        isnothing(selector) ? (0, 0, 0) : specificity(selector),
        stylesheet_index,
        order,
        before,
        after,
    )
    return after, step
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

"""Explain theme role, stylesheet rule, and inline patch application order."""
function explain_style(
    engine::StyleEngine,
    context::StyleContext,
    base::Style=Style();
    role::Union{Nothing,Symbol}=nothing,
    inline::StylePatch=StylePatch(),
)
    result = base
    steps = StyleResolutionStep[]
    if !isnothing(role)
        result, step = _resolution_step(
            :theme,
            "theme role `$(role)`",
            result,
            _style_patch(theme_style(engine.theme, role)),
        )
        push!(steps, step)
    end
    for (rule, stylesheet_index) in _matching_rule_entries(engine, context)
        result, step = _resolution_step(
            :stylesheet,
            "stylesheet $(stylesheet_index), rule $(rule.order)",
            result,
            rule.patch;
            selector=rule.selector,
            stylesheet_index,
            order=rule.order,
        )
        push!(steps, step)
    end
    result, step = _resolution_step(:inline, "inline style patch", result, inline)
    push!(steps, step)
    return StyleExplanation(context, base, role, inline, result, steps)
end

"""Build one diagnostics bundle containing context, rule matches, and cascade explanation."""
function style_diagnostics(
    engine::StyleEngine,
    context::StyleContext,
    base::Style=Style();
    role::Union{Nothing,Symbol}=nothing,
    inline::StylePatch=StylePatch(),
)
    explanation = explain_style(engine, context, base; role, inline)
    return StyleDiagnostics(
        context,
        explanation,
        style_rule_match_records(engine, context),
        style_rule_match_summary(engine, context),
    )
end

function _style_explanation_record(index::Integer, step::StyleResolutionStep)
    return (
        index=Int(index),
        source=step.source,
        label=step.label,
        stylesheet_index=step.stylesheet_index,
        order=step.order,
        specificity=step.specificity,
        selector=step.selector,
        selector_text=isnothing(step.selector) ? "" : selector_text(step.selector),
        before=step.before,
        after=step.after,
    )
end

function _style_explanation_records(steps)
    return [
        _style_explanation_record(index, step)
        for (index, step) in enumerate(steps)
    ]
end

function _style_explanation_records_from_indexed(indexed_steps)
    return [
        _style_explanation_record(index, step)
        for (index, step) in indexed_steps
    ]
end

"""Return plain records for logging, snapshots, or test assertions."""
style_explanation_records(explanation::StyleExplanation) =
    _style_explanation_records(explanation.steps)

_style_resolution_value(value) = isnothing(value) ? "" : string(value)

function _style_resolution_row(index::Integer, step::StyleResolutionStep)
    return (
        index=Int(index),
        source=step.source,
        label=step.label,
        selector=isnothing(step.selector) ? "" : selector_text(step.selector),
        specificity=step.specificity,
        stylesheet_index=step.stylesheet_index,
        order=step.order,
        after=sprint(show, step.after),
    )
end

_style_resolution_rows(steps) = [
    _style_resolution_row(index, step)
    for (index, step) in enumerate(steps)
]

_style_resolution_rows(explanation::StyleExplanation) =
    _style_resolution_rows(explanation.steps)

_style_resolution_rows_from_indexed(indexed_steps) = [
    _style_resolution_row(index, step)
    for (index, step) in indexed_steps
]

function _style_explanation_search_text(step::StyleResolutionStep)
    return lowercase(join((
        step.source,
        step.label,
        isnothing(step.selector) ? "" : selector_text(step.selector),
        step.specificity,
        _style_resolution_value(step.stylesheet_index),
        _style_resolution_value(step.order),
        sprint(show, step.after),
    ), " "))
end

function _search_style_explanation_indexed_steps(explanation::StyleExplanation, query)
    text = lowercase(strip(string(query)))
    indexed = Tuple{Int,StyleResolutionStep}[]
    for (index, step) in enumerate(explanation.steps)
        (isempty(text) || occursin(text, _style_explanation_search_text(step))) &&
            push!(indexed, (index, step))
    end
    return indexed
end

search_style_explanation_steps(explanation::StyleExplanation, query) =
    StyleResolutionStep[step for (_, step) in _search_style_explanation_indexed_steps(explanation, query)]

"""Return style explanation records whose source, label, specificity, order, or output style matches a query."""
search_style_explanation_records(explanation::StyleExplanation, query) =
    _style_explanation_records_from_indexed(_search_style_explanation_indexed_steps(explanation, query))

"""Count style explanation steps matching a query."""
search_style_explanation_count(explanation::StyleExplanation, query) =
    length(search_style_explanation_steps(explanation, query))

"""Render a style explanation as plain text for logs and assertions."""
function style_explanation_text(explanation::StyleExplanation)
    rows = _style_resolution_rows(explanation)
    isempty(rows) && return "No style resolution steps"
    return join(
        (
            "$(row.index). $(row.source): $(row.label) selector=$(_style_resolution_value(row.selector)) specificity=$(row.specificity) stylesheet=$(_style_resolution_value(row.stylesheet_index)) order=$(_style_resolution_value(row.order)) after=$(row.after)"
            for row in rows
        ),
        "\n",
    )
end

function _style_explanation_text(rows)
    isempty(rows) && return "No matching style resolution steps"
    return join(
        (
            "$(row.index). $(row.source): $(row.label) selector=$(_style_resolution_value(row.selector)) specificity=$(row.specificity) stylesheet=$(_style_resolution_value(row.stylesheet_index)) order=$(_style_resolution_value(row.order)) after=$(row.after)"
            for row in rows
        ),
        "\n",
    )
end

"""Render matching style explanation steps as plain text."""
search_style_explanation_text(explanation::StyleExplanation, query) =
    _style_explanation_text(_style_resolution_rows_from_indexed(_search_style_explanation_indexed_steps(explanation, query)))

_style_markdown_escape(value) = replace(string(value), "|" => "\\|", "\n" => " ")
_style_tsv_escape(value) = replace(string(value), '\t' => ' ', '\n' => ' ')

function _style_rule_match_text(records)
    isempty(records) && return "No stylesheet rules"
    return join(
        (
            "$(record.index). selector=$(record.selector_text) matched=$(record.matched) reasons=$(record.mismatch_reason_text) specificity=$(record.specificity) stylesheet=$(record.stylesheet_index) order=$(record.order)"
            for record in records
        ),
        "\n",
    )
end

"""Render stylesheet rule match diagnostics as plain text."""
style_rule_match_text(engine::StyleEngine, context::StyleContext) =
    _style_rule_match_text(style_rule_match_records(engine, context))

"""Render matching stylesheet rule diagnostics as plain text."""
matching_style_rule_text(engine::StyleEngine, context::StyleContext) =
    _style_rule_match_text(matching_style_rule_records(engine, context))

"""Render unmatched stylesheet rule diagnostics as plain text."""
unmatched_style_rule_text(engine::StyleEngine, context::StyleContext) =
    _style_rule_match_text(unmatched_style_rule_records(engine, context))

"""Render searched stylesheet rule match diagnostics as plain text."""
search_style_rule_match_text(engine::StyleEngine, context::StyleContext, query) =
    _style_rule_match_text(search_style_rule_match_records(engine, context, query))

function _style_rule_match_markdown(records)
    lines = String[
        "| index | selector | matched | mismatch reasons | specificity | stylesheet | order |",
        "|---|---|---|---|---|---|---|",
    ]
    for record in records
        push!(
            lines,
            "| $(record.index) | $(_style_markdown_escape(record.selector_text)) | $(record.matched) | $(_style_markdown_escape(record.mismatch_reason_text)) | $(_style_markdown_escape(record.specificity)) | $(record.stylesheet_index) | $(record.order) |",
        )
    end
    return join(lines, "\n")
end

"""Render stylesheet rule match diagnostics as Markdown."""
style_rule_match_markdown(engine::StyleEngine, context::StyleContext) =
    _style_rule_match_markdown(style_rule_match_records(engine, context))

"""Render matching stylesheet rule diagnostics as Markdown."""
matching_style_rule_markdown(engine::StyleEngine, context::StyleContext) =
    _style_rule_match_markdown(matching_style_rule_records(engine, context))

"""Render unmatched stylesheet rule diagnostics as Markdown."""
unmatched_style_rule_markdown(engine::StyleEngine, context::StyleContext) =
    _style_rule_match_markdown(unmatched_style_rule_records(engine, context))

"""Render searched stylesheet rule match diagnostics as Markdown."""
search_style_rule_match_markdown(engine::StyleEngine, context::StyleContext, query) =
    _style_rule_match_markdown(search_style_rule_match_records(engine, context, query))

function _style_rule_match_tsv(records)
    lines = ["index\tselector\tmatched\tmismatch_reasons\tspecificity\tstylesheet\torder"]
    for record in records
        push!(
            lines,
            join(
                (
                    record.index,
                    _style_tsv_escape(record.selector_text),
                    record.matched,
                    _style_tsv_escape(record.mismatch_reason_text),
                    _style_tsv_escape(record.specificity),
                    record.stylesheet_index,
                    record.order,
                ),
                "\t",
            ),
        )
    end
    return join(lines, "\n")
end

"""Render stylesheet rule match diagnostics as TSV."""
style_rule_match_tsv(engine::StyleEngine, context::StyleContext) =
    _style_rule_match_tsv(style_rule_match_records(engine, context))

"""Render matching stylesheet rule diagnostics as TSV."""
matching_style_rule_tsv(engine::StyleEngine, context::StyleContext) =
    _style_rule_match_tsv(matching_style_rule_records(engine, context))

"""Render unmatched stylesheet rule diagnostics as TSV."""
unmatched_style_rule_tsv(engine::StyleEngine, context::StyleContext) =
    _style_rule_match_tsv(unmatched_style_rule_records(engine, context))

"""Render searched stylesheet rule match diagnostics as TSV."""
search_style_rule_match_tsv(engine::StyleEngine, context::StyleContext, query) =
    _style_rule_match_tsv(search_style_rule_match_records(engine, context, query))

"""Render a style explanation as Markdown for diagnostics artifacts."""
function style_explanation_markdown(explanation::StyleExplanation)
    return _style_explanation_markdown(_style_resolution_rows(explanation))
end

function _style_explanation_markdown(rows)
    lines = String[
        "| index | source | label | selector | specificity | stylesheet | order | after |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for row in rows
        cells = join(
            (
                row.index,
                row.source,
                _style_markdown_escape(row.label),
                _style_markdown_escape(row.selector),
                _style_markdown_escape(row.specificity),
                _style_markdown_escape(_style_resolution_value(row.stylesheet_index)),
                _style_markdown_escape(_style_resolution_value(row.order)),
                _style_markdown_escape(row.after),
            ),
            " | ",
        )
        push!(lines, "| $cells |")
    end
    return join(lines, "\n")
end

"""Render matching style explanation steps as Markdown."""
search_style_explanation_markdown(explanation::StyleExplanation, query) =
    _style_explanation_markdown(_style_resolution_rows_from_indexed(_search_style_explanation_indexed_steps(explanation, query)))

"""Render a style explanation as TSV for machine-readable diagnostics."""
function style_explanation_tsv(explanation::StyleExplanation)
    return _style_explanation_tsv(_style_resolution_rows(explanation))
end

function _style_explanation_tsv(rows)
    lines = ["index\tsource\tlabel\tselector\tspecificity\tstylesheet\torder\tafter"]
    for row in rows
        push!(
            lines,
            join(
                (
                    row.index,
                    row.source,
                    _style_tsv_escape(row.label),
                    _style_tsv_escape(row.selector),
                    _style_tsv_escape(row.specificity),
                    _style_tsv_escape(_style_resolution_value(row.stylesheet_index)),
                    _style_tsv_escape(_style_resolution_value(row.order)),
                    _style_tsv_escape(row.after),
                ),
                "\t",
            ),
        )
    end
    return join(lines, "\n")
end

"""Render matching style explanation steps as TSV."""
search_style_explanation_tsv(explanation::StyleExplanation, query) =
    _style_explanation_tsv(_style_resolution_rows_from_indexed(_search_style_explanation_indexed_steps(explanation, query)))

"""Return counts of resolution steps by source plus total step count."""
function style_explanation_summary(explanation::StyleExplanation)
    counts = Dict{Symbol,Int}()
    for step in explanation.steps
        counts[step.source] = get(counts, step.source, 0) + 1
    end
    return (
        total=length(explanation.steps),
        by_source=sort!(collect(counts); by=first),
    )
end

"""Return plain summary records for logs, dashboards, and assertions."""
style_explanation_summary_records(explanation::StyleExplanation) = [
    (source=source, count=count)
    for (source, count) in style_explanation_summary(explanation).by_source
]

"""Render style explanation source counts as plain text."""
function style_explanation_summary_text(explanation::StyleExplanation)
    summary = style_explanation_summary(explanation)
    lines = ["total: $(summary.total)"]
    append!(lines, "$(source): $(count)" for (source, count) in summary.by_source)
    return join(lines, "\n")
end

"""Render style explanation source counts as Markdown."""
function style_explanation_summary_markdown(explanation::StyleExplanation)
    summary = style_explanation_summary(explanation)
    lines = String[
        "| source | count |",
        "|---|---|",
        "| total | $(summary.total) |",
    ]
    for (source, count) in summary.by_source
        push!(lines, "| $(source) | $(count) |")
    end
    return join(lines, "\n")
end

"""Render style explanation source counts as TSV."""
function style_explanation_summary_tsv(explanation::StyleExplanation)
    summary = style_explanation_summary(explanation)
    lines = ["source\tcount", "total\t$(summary.total)"]
    append!(lines, "$(source)\t$(count)" for (source, count) in summary.by_source)
    return join(lines, "\n")
end

"""Return a compact record for a style diagnostics bundle."""
style_diagnostics_record(diagnostics::StyleDiagnostics) = (
    context=style_context_record(diagnostics.context),
    result=diagnostics.explanation.result,
    resolution_steps=length(diagnostics.explanation.steps),
    total_rules=diagnostics.rule_summary.total,
    matched_rules=diagnostics.rule_summary.matched,
    unmatched_rules=diagnostics.rule_summary.unmatched,
)

"""Render aggregate style diagnostics as plain text."""
function style_diagnostics_text(diagnostics::StyleDiagnostics)
    return join((
        "[style context]",
        style_context_text(diagnostics.context),
        "",
        "[rule matches]",
        _style_rule_match_text(diagnostics.rule_matches),
        "",
        "[resolution]",
        style_explanation_text(diagnostics.explanation),
        "",
        "[summary]",
        "resolution_steps: $(length(diagnostics.explanation.steps))",
        "total_rules: $(diagnostics.rule_summary.total)",
        "matched_rules: $(diagnostics.rule_summary.matched)",
        "unmatched_rules: $(diagnostics.rule_summary.unmatched)",
    ), "\n")
end

"""Render aggregate style diagnostics as Markdown."""
function style_diagnostics_markdown(diagnostics::StyleDiagnostics)
    return join((
        "## Style context",
        style_context_markdown(diagnostics.context),
        "",
        "## Rule matches",
        _style_rule_match_markdown(diagnostics.rule_matches),
        "",
        "## Resolution",
        style_explanation_markdown(diagnostics.explanation),
        "",
        "## Summary",
        join((
            "| metric | value |",
            "|---|---|",
            "| resolution_steps | $(length(diagnostics.explanation.steps)) |",
            "| total_rules | $(diagnostics.rule_summary.total) |",
            "| matched_rules | $(diagnostics.rule_summary.matched) |",
            "| unmatched_rules | $(diagnostics.rule_summary.unmatched) |",
        ), "\n"),
    ), "\n")
end

"""Render aggregate style diagnostics summary as TSV."""
function style_diagnostics_tsv(diagnostics::StyleDiagnostics)
    record = style_diagnostics_record(diagnostics)
    context = record.context
    return join((
        "section\tfield\tvalue",
        "context\twidget_type\t$(_style_tsv_escape(context.widget_type))",
        "context\tid\t$(_style_tsv_escape(context.id))",
        "context\tclasses\t$(_style_tsv_escape(context.classes))",
        "context\tstates\t$(_style_tsv_escape(context.states))",
        "context\tancestor_classes\t$(_style_tsv_escape(context.ancestor_classes))",
        "summary\tresolution_steps\t$(record.resolution_steps)",
        "summary\ttotal_rules\t$(record.total_rules)",
        "summary\tmatched_rules\t$(record.matched_rules)",
        "summary\tunmatched_rules\t$(record.unmatched_rules)",
    ), "\n")
end

function _style_diagnostics_rule_record(record)
    return (
        section=:rule_match,
        index=record.index,
        source=:stylesheet,
        label=record.selector_text,
        matched=record.matched,
        detail=record.matched ? "matched" : record.mismatch_reason_text,
    )
end

function _style_diagnostics_resolution_record(record)
    return (
        section=:resolution,
        index=record.index,
        source=record.source,
        label=record.label,
        matched=true,
        detail=record.selector_text,
    )
end

function _style_diagnostics_search_text(record)
    return lowercase(join((
        record.section,
        record.index,
        record.source,
        record.label,
        record.matched,
        record.detail,
    ), " "))
end

"""Return aggregate diagnostics records matching a query across rule matches and resolution steps."""
function search_style_diagnostics_records(diagnostics::StyleDiagnostics, query)
    text = lowercase(strip(string(query)))
    records = NamedTuple[]
    append!(records, (_style_diagnostics_rule_record(record) for record in diagnostics.rule_matches))
    append!(records, (_style_diagnostics_resolution_record(record) for record in style_explanation_records(diagnostics.explanation)))
    isempty(text) && return records
    return [
        record for record in records
        if occursin(text, _style_diagnostics_search_text(record))
    ]
end

"""Count aggregate diagnostics records matching a query."""
search_style_diagnostics_count(diagnostics::StyleDiagnostics, query) =
    length(search_style_diagnostics_records(diagnostics, query))

function _style_diagnostics_search_text_output(records)
    isempty(records) && return "No matching style diagnostics"
    return join(
        (
            "$(record.section)[$(record.index)] source=$(record.source) label=$(record.label) matched=$(record.matched) detail=$(record.detail)"
            for record in records
        ),
        "\n",
    )
end

"""Render searched aggregate diagnostics records as plain text."""
search_style_diagnostics_text(diagnostics::StyleDiagnostics, query) =
    _style_diagnostics_search_text_output(search_style_diagnostics_records(diagnostics, query))

function _style_diagnostics_search_markdown(records)
    lines = String[
        "| section | index | source | label | matched | detail |",
        "|---|---|---|---|---|---|",
    ]
    for record in records
        push!(
            lines,
            "| $(record.section) | $(record.index) | $(record.source) | $(_style_markdown_escape(record.label)) | $(record.matched) | $(_style_markdown_escape(record.detail)) |",
        )
    end
    return join(lines, "\n")
end

"""Render searched aggregate diagnostics records as Markdown."""
search_style_diagnostics_markdown(diagnostics::StyleDiagnostics, query) =
    _style_diagnostics_search_markdown(search_style_diagnostics_records(diagnostics, query))

function _style_diagnostics_search_tsv(records)
    lines = ["section\tindex\tsource\tlabel\tmatched\tdetail"]
    for record in records
        push!(
            lines,
            join((
                record.section,
                record.index,
                record.source,
                _style_tsv_escape(record.label),
                record.matched,
                _style_tsv_escape(record.detail),
            ), "\t"),
        )
    end
    return join(lines, "\n")
end

"""Render searched aggregate diagnostics records as TSV."""
search_style_diagnostics_tsv(diagnostics::StyleDiagnostics, query) =
    _style_diagnostics_search_tsv(search_style_diagnostics_records(diagnostics, query))

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
       StyleDiagnostics,
       StyleEngine,
       StyleExplanation,
       StyleRule,
       StyleResolutionStep,
       StyleDiagnostic,
       Stylesheet,
       StylesheetParseError,
       Theme,
       add_rule!,
       add_stylesheet!,
       apply_style!,
       computed_style,
       explain_style,
       matches,
       load_stylesheet,
       parse_color,
       parse_stylesheet,
       remove_rule!,
       search_style_explanation_count,
       search_style_diagnostics_count,
       search_style_diagnostics_markdown,
       search_style_diagnostics_records,
       search_style_diagnostics_text,
       search_style_diagnostics_tsv,
       search_style_explanation_markdown,
       search_style_explanation_records,
       search_style_explanation_text,
       search_style_explanation_tsv,
       search_style_rule_match_count,
       search_style_rule_match_markdown,
       search_style_rule_match_records,
       search_style_rule_match_text,
       search_style_rule_match_tsv,
       selector_match_reasons,
       selector_text,
       set_theme!,
       specificity,
       style_context_markdown,
       style_context_record,
       style_context_text,
       style_context_tsv,
       style_diagnostics,
       style_diagnostics_markdown,
       style_diagnostics_record,
       style_diagnostics_text,
       style_diagnostics_tsv,
       matching_style_rule_markdown,
       matching_style_rule_records,
       matching_style_rule_text,
       matching_style_rule_tsv,
       style_explanation_markdown,
       style_explanation_records,
       style_explanation_summary,
       style_explanation_summary_markdown,
       style_explanation_summary_records,
       style_explanation_summary_text,
       style_explanation_summary_tsv,
       style_explanation_text,
       style_explanation_tsv,
       style_rule_match_markdown,
       style_rule_match_records,
       style_rule_match_summary,
       style_rule_match_text,
       style_rule_match_tsv,
       theme_style,
       unmatched_style_rule_markdown,
       unmatched_style_rule_records,
       unmatched_style_rule_text,
       unmatched_style_rule_tsv,
       try_parse_stylesheet

end
