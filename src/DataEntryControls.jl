module DataEntryControls

import Dates
using Dates: Date, Time, Day, Month, Hour, Minute, Second, Nanosecond, year, month, daysinmonth

export CompletionItem,
       CompletionMatchMode,
       PrefixCompletion,
       ContainsCompletion,
       FuzzyCompletion,
       AutocompleteState,
       update_autocomplete!,
       move_autocomplete!,
       accept_autocomplete!,
       close_autocomplete!,
       visible_completions,
       visible_completion_range,
       ComboBoxState,
       set_combobox_query!,
       move_combobox!,
       accept_combobox!,
       clear_combobox!,
       TagInputState,
       add_tag!,
       remove_tag!,
       clear_tags!,
       NumericInputState,
       set_numeric_text!,
       set_numeric_value!,
       commit_numeric_input!,
       increment_numeric_input!,
       numeric_input_valid,
       MaskTokenKind,
       MaskLiteral,
       MaskDigit,
       MaskLetter,
       MaskAlphanumeric,
       MaskAny,
       MaskToken,
       InputMask,
       MaskedInputState,
       insert_masked_input!,
       backspace_masked_input!,
       delete_masked_input!,
       move_masked_input_cursor!,
       set_masked_input_cursor!,
       masked_input_text,
       masked_input_complete,
       clear_masked_input!,
       DatePickerState,
       date_picker_grid,
       move_date_picker!,
       move_date_picker_month!,
       select_date!,
       TimePickerState,
       set_time_picker!,
       increment_time_picker!,
       ColorValue,
       ColorPickerState,
       set_color_rgb!,
       set_color_hsv!,
       set_color_hex!,
       color_hex,
       color_hsv

struct CompletionItem{T}
    label::String
    value::T
    detail::Union{Nothing,String}
    keywords::Vector{String}
    disabled::Bool
end

function CompletionItem(
    label::AbstractString,
    value;
    detail::Union{Nothing,AbstractString}=nothing,
    keywords=String[],
    disabled::Bool=false,
)
    return CompletionItem{typeof(value)}(
        String(label),
        value,
        detail === nothing ? nothing : String(detail),
        String[String(keyword) for keyword in keywords],
        disabled,
    )
end

@enum CompletionMatchMode begin
    PrefixCompletion
    ContainsCompletion
    FuzzyCompletion
end

mutable struct AutocompleteState{T}
    items::Vector{CompletionItem{T}}
    query::String
    matches::Vector{Int}
    highlighted::Union{Nothing,Int}
    open::Bool
    max_visible::Int
    mode::CompletionMatchMode
    case_sensitive::Bool

    function AutocompleteState(
        items::AbstractVector{CompletionItem{T}};
        max_visible::Integer=10,
        mode::CompletionMatchMode=FuzzyCompletion,
        case_sensitive::Bool=false,
    ) where {T}
        max_visible > 0 || throw(ArgumentError("maximum visible completions must be positive"))
        state = new{T}(
            Vector{CompletionItem{T}}(items),
            "",
            Int[],
            nothing,
            false,
            Int(max_visible),
            mode,
            case_sensitive,
        )
        update_autocomplete!(state, "")
        return state
    end
end

_completion_text(state::AutocompleteState, value::AbstractString) =
    state.case_sensitive ? String(value) : lowercase(String(value))

function _fuzzy_score(needle::String, haystack::String)
    isempty(needle) && return 0
    needle_index = firstindex(needle)
    score = 0
    consecutive = 0
    position = 0
    for character in haystack
        position += 1
        needle_index > lastindex(needle) && break
        if character == needle[needle_index]
            consecutive += 1
            score += 10 + consecutive * 3 - min(position, 9)
            needle_index = nextind(needle, needle_index)
        else
            consecutive = 0
        end
    end
    return needle_index > lastindex(needle) ? score : nothing
end

function _completion_score(state::AutocompleteState, item::CompletionItem)
    item.disabled && return nothing
    query = _completion_text(state, state.query)
    candidates = String[item.label; item.keywords]
    best = nothing
    for candidate_value in candidates
        candidate = _completion_text(state, candidate_value)
        score = if state.mode == PrefixCompletion
            startswith(candidate, query) ? 1_000 - length(candidate) : nothing
        elseif state.mode == ContainsCompletion
            position = findfirst(query, candidate)
            position === nothing ? nothing : 1_000 - first(position) - length(candidate)
        else
            _fuzzy_score(query, candidate)
        end
        score === nothing || (best = best === nothing ? score : max(best, score))
    end
    return best
end

function update_autocomplete!(state::AutocompleteState, query::AbstractString)
    state.query = String(query)
    scored = Tuple{Int,Int}[]
    for (index, item) in enumerate(state.items)
        score = _completion_score(state, item)
        score === nothing || push!(scored, (index, score))
    end
    sort!(scored; by=value -> (-value[2], value[1]))
    state.matches = Int[value[1] for value in scored]
    state.highlighted = isempty(state.matches) ? nothing : 1
    state.open = !isempty(state.matches)
    return state
end

function move_autocomplete!(state::AutocompleteState, delta::Integer; wrap::Bool=true)
    isempty(state.matches) && (state.highlighted = nothing; return state)
    current = something(state.highlighted, 1)
    target = big(current) + big(delta)
    state.highlighted = wrap ? mod1(Int(mod(target - 1, length(state.matches))) + 1, length(state.matches)) :
                        Int(clamp(target, big(1), big(length(state.matches))))
    return state
end

function accept_autocomplete!(state::AutocompleteState)
    state.highlighted === nothing && return nothing
    item = state.items[state.matches[state.highlighted]]
    item.disabled && return nothing
    state.open = false
    return item.value
end

close_autocomplete!(state::AutocompleteState) = (state.open = false; state)

function visible_completion_range(state::AutocompleteState)
    isempty(state.matches) && return 1:0
    maximum_start = max(1, length(state.matches) - state.max_visible + 1)
    center = something(state.highlighted, 1) - div(state.max_visible - 1, 2)
    first_index = clamp(center, 1, maximum_start)
    return first_index:min(length(state.matches), first_index + state.max_visible - 1)
end

function visible_completions(state::AutocompleteState)
    return CompletionItem[
        state.items[state.matches[index]] for index in visible_completion_range(state)
    ]
end

mutable struct ComboBoxState{T}
    autocomplete::AutocompleteState{T}
    selected::Union{Nothing,T}
    editable::Bool
    required::Bool
end

ComboBoxState(
    items::AbstractVector{CompletionItem{T}};
    editable::Bool=false,
    required::Bool=false,
    kwargs...,
) where {T} = ComboBoxState{T}(
    AutocompleteState(items; kwargs...),
    nothing,
    editable,
    required,
)

function set_combobox_query!(state::ComboBoxState, query::AbstractString)
    state.editable || isempty(query) || return state
    update_autocomplete!(state.autocomplete, query)
    return state
end

move_combobox!(state::ComboBoxState, delta::Integer; kwargs...) =
    (move_autocomplete!(state.autocomplete, delta; kwargs...); state)

function accept_combobox!(state::ComboBoxState)
    value = accept_autocomplete!(state.autocomplete)
    value === nothing || (state.selected = value)
    return value
end

function clear_combobox!(state::ComboBoxState)
    state.required && return state
    state.selected = nothing
    update_autocomplete!(state.autocomplete, "")
    return state
end

mutable struct TagInputState
    tags::Vector{String}
    maximum::Union{Nothing,Int}
    allow_duplicates::Bool
    case_sensitive::Bool

    function TagInputState(
        tags=String[];
        maximum::Union{Nothing,Integer}=nothing,
        allow_duplicates::Bool=false,
        case_sensitive::Bool=false,
    )
        maximum !== nothing && maximum < 0 && throw(ArgumentError("maximum tag count cannot be negative"))
        state = new(
            String[],
            maximum === nothing ? nothing : Int(maximum),
            allow_duplicates,
            case_sensitive,
        )
        for tag in tags
            add_tag!(state, tag)
        end
        return state
    end
end

_tag_key(state::TagInputState, value::String) =
    state.case_sensitive ? value : lowercase(value)

function add_tag!(state::TagInputState, tag::AbstractString)
    value = strip(String(tag))
    isempty(value) && return false
    state.maximum !== nothing && length(state.tags) >= state.maximum && return false
    if !state.allow_duplicates
        key = _tag_key(state, value)
        any(existing -> _tag_key(state, existing) == key, state.tags) && return false
    end
    push!(state.tags, value)
    return true
end

function remove_tag!(state::TagInputState, index::Integer)
    1 <= index <= length(state.tags) || return nothing
    return splice!(state.tags, Int(index))
end

clear_tags!(state::TagInputState) = (empty!(state.tags); state)

mutable struct NumericInputState
    text::String
    value::Union{Nothing,Float64}
    minimum::Union{Nothing,Float64}
    maximum::Union{Nothing,Float64}
    step::Float64
    allow_empty::Bool
    valid::Bool
    error::Union{Nothing,String}

    function NumericInputState(;
        value::Union{Nothing,Real}=nothing,
        minimum::Union{Nothing,Real}=nothing,
        maximum::Union{Nothing,Real}=nothing,
        step::Real=1,
        allow_empty::Bool=true,
    )
        minimum !== nothing && !isfinite(minimum) && throw(ArgumentError("numeric minimum must be finite"))
        maximum !== nothing && !isfinite(maximum) && throw(ArgumentError("numeric maximum must be finite"))
        minimum !== nothing && maximum !== nothing && minimum > maximum &&
            throw(ArgumentError("numeric minimum exceeds maximum"))
        isfinite(step) && step > 0 || throw(ArgumentError("numeric step must be finite and positive"))
        state = new(
            value === nothing ? "" : string(value),
            nothing,
            minimum === nothing ? nothing : Float64(minimum),
            maximum === nothing ? nothing : Float64(maximum),
            Float64(step),
            allow_empty,
            false,
            nothing,
        )
        commit_numeric_input!(state)
        return state
    end
end

function set_numeric_text!(state::NumericInputState, text::AbstractString; commit::Bool=false)
    state.text = String(text)
    if commit
        commit_numeric_input!(state)
    else
        state.valid = false
        state.error = nothing
    end
    return state
end

function commit_numeric_input!(state::NumericInputState)
    value_text = strip(state.text)
    if isempty(value_text)
        state.value = nothing
        state.valid = state.allow_empty
        state.error = state.valid ? nothing : "a value is required"
        return state.valid
    end
    parsed = tryparse(Float64, value_text)
    if parsed === nothing || !isfinite(parsed)
        state.valid = false
        state.error = "invalid numeric value"
        return false
    end
    if state.minimum !== nothing && parsed < state.minimum
        state.valid = false
        state.error = "value is below the minimum"
        return false
    elseif state.maximum !== nothing && parsed > state.maximum
        state.valid = false
        state.error = "value is above the maximum"
        return false
    end
    state.value = parsed
    state.text = string(parsed)
    state.valid = true
    state.error = nothing
    return true
end

function set_numeric_value!(state::NumericInputState, value::Union{Nothing,Real})
    state.text = value === nothing ? "" : string(value)
    commit_numeric_input!(state)
    return state
end

function increment_numeric_input!(state::NumericInputState, steps::Integer=1)
    base = something(state.value, state.minimum, 0.0)
    next_value = base + Float64(steps) * state.step
    state.minimum === nothing || (next_value = max(next_value, state.minimum))
    state.maximum === nothing || (next_value = min(next_value, state.maximum))
    return set_numeric_value!(state, next_value)
end

numeric_input_valid(state::NumericInputState) = state.valid

@enum MaskTokenKind begin
    MaskLiteral
    MaskDigit
    MaskLetter
    MaskAlphanumeric
    MaskAny
end

struct MaskToken
    kind::MaskTokenKind
    literal::Union{Nothing,Char}
end

struct InputMask
    tokens::Vector{MaskToken}
    placeholder::Char

    function InputMask(pattern::AbstractString; placeholder::Char='_')
        tokens = MaskToken[]
        escaped = false
        for character in pattern
            if escaped
                push!(tokens, MaskToken(MaskLiteral, character))
                escaped = false
            elseif character == '\\'
                escaped = true
            elseif character == '#'
                push!(tokens, MaskToken(MaskDigit, nothing))
            elseif character == 'A'
                push!(tokens, MaskToken(MaskLetter, nothing))
            elseif character == 'a'
                push!(tokens, MaskToken(MaskAlphanumeric, nothing))
            elseif character == '*'
                push!(tokens, MaskToken(MaskAny, nothing))
            else
                push!(tokens, MaskToken(MaskLiteral, character))
            end
        end
        escaped && throw(ArgumentError("input mask ends with an escape"))
        isempty(tokens) && throw(ArgumentError("input mask cannot be empty"))
        new(tokens, placeholder)
    end
end

mutable struct MaskedInputState
    mask::InputMask
    values::Vector{Union{Nothing,Char}}
    cursor::Int
    focused::Bool

    function MaskedInputState(mask::InputMask)
        values = Union{Nothing,Char}[
            token.kind == MaskLiteral ? token.literal : nothing for token in mask.tokens
        ]
        cursor = something(findfirst(token -> token.kind != MaskLiteral, mask.tokens), length(mask.tokens) + 1)
        new(mask, values, cursor, false)
    end
end

MaskedInputState(
    mask::InputMask,
    values::Vector{Union{Nothing,Char}},
    cursor::Integer,
) = MaskedInputState(mask, values, Int(cursor), false)

function _accepts(token::MaskToken, character::Char)
    token.kind == MaskDigit && return isdigit(character)
    token.kind == MaskLetter && return isletter(character)
    token.kind == MaskAlphanumeric && return isletter(character) || isdigit(character)
    token.kind == MaskAny && return !iscntrl(character)
    return false
end

function _next_editable(state::MaskedInputState, index::Int, direction::Int)
    cursor = index
    while 1 <= cursor <= length(state.mask.tokens)
        state.mask.tokens[cursor].kind != MaskLiteral && return cursor
        cursor += direction
    end
    return direction > 0 ? length(state.mask.tokens) + 1 : 0
end

function insert_masked_input!(state::MaskedInputState, character::Char)
    1 <= state.cursor <= length(state.mask.tokens) || return false
    token = state.mask.tokens[state.cursor]
    _accepts(token, character) || return false
    state.values[state.cursor] = character
    state.cursor = _next_editable(state, state.cursor + 1, 1)
    return true
end

function backspace_masked_input!(state::MaskedInputState)
    target = _next_editable(state, min(state.cursor - 1, length(state.mask.tokens)), -1)
    target > 0 || return false
    state.values[target] = nothing
    state.cursor = target
    return true
end

function delete_masked_input!(state::MaskedInputState)
    1 <= state.cursor <= length(state.mask.tokens) || return false
    state.values[state.cursor] = nothing
    return true
end

"""Move a masked-input cursor between editable mask positions."""
function move_masked_input_cursor!(state::MaskedInputState, delta::Integer)
    direction = sign(Int(delta))
    direction == 0 && return false
    cursor = state.cursor
    for _ in 1:abs(Int(delta))
        candidate = _next_editable(state, cursor + direction, direction)
        candidate == cursor && break
        cursor = candidate
    end
    changed = cursor != state.cursor
    state.cursor = cursor
    return changed
end

"""Set a masked-input cursor, snapping literal positions to an editable slot."""
function set_masked_input_cursor!(state::MaskedInputState, position::Integer)
    limit = length(state.mask.tokens) + 1
    target = clamp(Int(position), 1, limit)
    if target <= length(state.mask.tokens) && state.mask.tokens[target].kind == MaskLiteral
        direction = target >= state.cursor ? 1 : -1
        target = _next_editable(state, target, direction)
    end
    target == 0 && (target = _next_editable(state, 1, 1))
    changed = state.cursor != target
    state.cursor = target
    return changed
end

function masked_input_text(state::MaskedInputState; include_placeholders::Bool=true)
    output = IOBuffer()
    for (index, token) in enumerate(state.mask.tokens)
        value = state.values[index]
        if token.kind == MaskLiteral
            print(output, token.literal)
        elseif value !== nothing
            print(output, value)
        elseif include_placeholders
            print(output, state.mask.placeholder)
        end
    end
    return String(take!(output))
end

masked_input_complete(state::MaskedInputState) = all(
    index -> state.mask.tokens[index].kind == MaskLiteral || state.values[index] !== nothing,
    eachindex(state.mask.tokens),
)

function clear_masked_input!(state::MaskedInputState)
    for index in eachindex(state.mask.tokens)
        state.mask.tokens[index].kind == MaskLiteral || (state.values[index] = nothing)
    end
    state.cursor = something(findfirst(token -> token.kind != MaskLiteral, state.mask.tokens), length(state.mask.tokens) + 1)
    return state
end

mutable struct DatePickerState
    selected::Date
    visible_month::Date
    minimum::Union{Nothing,Date}
    maximum::Union{Nothing,Date}
    week_start::Int

    function DatePickerState(;
        selected::Date=Date(Dates.today()),
        minimum::Union{Nothing,Date}=nothing,
        maximum::Union{Nothing,Date}=nothing,
        week_start::Integer=1,
    )
        minimum !== nothing && maximum !== nothing && minimum > maximum &&
            throw(ArgumentError("date-picker minimum exceeds maximum"))
        1 <= week_start <= 7 || throw(ArgumentError("week start must be between 1 and 7"))
        value = _clamp_date(selected, minimum, maximum)
        new(value, Date(year(value), month(value), 1), minimum, maximum, Int(week_start))
    end
end

function _clamp_date(value::Date, minimum, maximum)
    minimum === nothing || (value = max(value, minimum))
    maximum === nothing || (value = min(value, maximum))
    return value
end

function select_date!(state::DatePickerState, value::Date)
    state.selected = _clamp_date(value, state.minimum, state.maximum)
    state.visible_month = Date(year(state.selected), month(state.selected), 1)
    return state
end

move_date_picker!(state::DatePickerState, days::Integer) =
    select_date!(state, state.selected + Day(days))

function move_date_picker_month!(state::DatePickerState, months::Integer)
    target_month = state.visible_month + Month(months)
    target_day = min(Dates.day(state.selected), daysinmonth(target_month))
    return select_date!(state, Date(year(target_month), month(target_month), target_day))
end

function date_picker_grid(state::DatePickerState)
    first_day = state.visible_month
    weekday = Dates.dayofweek(first_day)
    leading = mod(weekday - state.week_start, 7)
    grid_start = first_day - Day(leading)
    return reshape(Date[grid_start + Day(offset) for offset in 0:41], 6, 7)
end

mutable struct TimePickerState
    value::Time
    minimum::Time
    maximum::Time
    step_seconds::Int

    function TimePickerState(;
        value::Time=Time(0),
        minimum::Time=Time(0),
        maximum::Time=Time(23, 59, 59),
        step_seconds::Integer=60,
    )
        minimum <= maximum || throw(ArgumentError("time-picker minimum exceeds maximum"))
        step_seconds > 0 || throw(ArgumentError("time-picker step must be positive"))
        state = new(value, minimum, maximum, Int(step_seconds))
        set_time_picker!(state, value)
        return state
    end
end

function set_time_picker!(state::TimePickerState, value::Time)
    state.value = clamp(value, state.minimum, state.maximum)
    return state
end

function increment_time_picker!(state::TimePickerState, steps::Integer=1)
    nanoseconds = Dates.value(state.value)
    delta = big(steps) * state.step_seconds * 1_000_000_000
    minimum = Dates.value(state.minimum)
    maximum = Dates.value(state.maximum)
    target = Int64(clamp(big(nanoseconds) + delta, big(minimum), big(maximum)))
    state.value = Time(Nanosecond(target))
    return state
end

struct ColorValue
    red::UInt8
    green::UInt8
    blue::UInt8
    alpha::UInt8
end

ColorValue(red::Integer, green::Integer, blue::Integer, alpha::Integer=255) =
    ColorValue(UInt8(clamp(red, 0, 255)), UInt8(clamp(green, 0, 255)), UInt8(clamp(blue, 0, 255)), UInt8(clamp(alpha, 0, 255)))

mutable struct ColorPickerState
    value::ColorValue
end

ColorPickerState() = ColorPickerState(ColorValue(0, 0, 0))

function set_color_rgb!(state::ColorPickerState, red::Integer, green::Integer, blue::Integer; alpha::Integer=state.value.alpha)
    state.value = ColorValue(red, green, blue, alpha)
    return state
end

function color_hsv(value::ColorValue)
    red, green, blue = Float64(value.red) / 255, Float64(value.green) / 255, Float64(value.blue) / 255
    maximum = max(red, green, blue)
    minimum = min(red, green, blue)
    delta = maximum - minimum
    hue = delta == 0 ? 0.0 : maximum == red ? 60 * mod((green - blue) / delta, 6) :
          maximum == green ? 60 * ((blue - red) / delta + 2) : 60 * ((red - green) / delta + 4)
    saturation = maximum == 0 ? 0.0 : delta / maximum
    return (hue, saturation, maximum)
end

function set_color_hsv!(
    state::ColorPickerState,
    hue::Real,
    saturation::Real,
    value::Real;
    alpha::Integer=state.value.alpha,
)
    isfinite(hue) && isfinite(saturation) && isfinite(value) ||
        throw(ArgumentError("HSV components must be finite"))
    h = mod(Float64(hue), 360) / 60
    s = clamp(Float64(saturation), 0, 1)
    v = clamp(Float64(value), 0, 1)
    chroma = v * s
    x = chroma * (1 - abs(mod(h, 2) - 1))
    red, green, blue = h < 1 ? (chroma, x, 0.0) : h < 2 ? (x, chroma, 0.0) :
                       h < 3 ? (0.0, chroma, x) : h < 4 ? (0.0, x, chroma) :
                       h < 5 ? (x, 0.0, chroma) : (chroma, 0.0, x)
    match_value = v - chroma
    return set_color_rgb!(
        state,
        round(Int, (red + match_value) * 255),
        round(Int, (green + match_value) * 255),
        round(Int, (blue + match_value) * 255);
        alpha=alpha,
    )
end

function set_color_hex!(state::ColorPickerState, value::AbstractString)
    text = uppercase(strip(String(value)))
    startswith(text, '#') && (text = text[2:end])
    length(text) in (6, 8) || return false
    all(isxdigit, text) || return false
    channels = [parse(UInt8, text[index:(index + 1)]; base=16) for index in 1:2:length(text)]
    state.value = ColorValue(channels[1], channels[2], channels[3], length(channels) == 4 ? channels[4] : 255)
    return true
end

color_hex(state::ColorPickerState; alpha::Bool=state.value.alpha != 255) =
    "#" * uppercase(string(state.value.red; base=16, pad=2)) *
    uppercase(string(state.value.green; base=16, pad=2)) *
    uppercase(string(state.value.blue; base=16, pad=2)) *
    (alpha ? uppercase(string(state.value.alpha; base=16, pad=2)) : "")

end
