const _ESC = UInt8(0x1b)
const _PASTE_START = UInt8[0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7e]
const _PASTE_END = UInt8[0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7e]

"""Incremental parser for common ANSI keyboard, mouse, focus, and paste sequences."""
mutable struct AnsiInputParser
    buffer::Vector{UInt8}
    max_buffer_bytes::Int
    max_paste_bytes::Int

    function AnsiInputParser(;
        max_buffer_bytes::Integer=1024 * 1024 + 2 * length(_PASTE_END),
        max_paste_bytes::Integer=1024 * 1024,
    )
        max_buffer_bytes > 0 || throw(ArgumentError("maximum buffer size must be positive"))
        max_paste_bytes > 0 || throw(ArgumentError("maximum paste size must be positive"))
        max_buffer_bytes >= max_paste_bytes + length(_PASTE_START) + length(_PASTE_END) ||
            throw(ArgumentError("maximum buffer size must accommodate the maximum paste"))
        new(UInt8[], Int(max_buffer_bytes), Int(max_paste_bytes))
    end
end

function _starts_with(buffer::Vector{UInt8}, sequence::Vector{UInt8})
    length(buffer) >= length(sequence) || return false
    @inbounds for index in eachindex(sequence)
        buffer[index] == sequence[index] || return false
    end
    true
end

function _find_sequence(
    buffer::Vector{UInt8},
    sequence::Vector{UInt8},
    start::Int=1,
)
    last_start = length(buffer) - length(sequence) + 1
    for offset in start:last_start
        found = true
        @inbounds for index in eachindex(sequence)
            if buffer[offset + index - 1] != sequence[index]
                found = false
                break
            end
        end
        found && return offset
    end
    nothing
end

function _consume!(parser::AnsiInputParser, count::Int)
    bytes = copy(@view parser.buffer[1:count])
    deleteat!(parser.buffer, 1:count)
    bytes
end

function _utf8_length(first_byte::UInt8)
    first_byte < 0x80 && return 1
    0xc2 <= first_byte <= 0xdf && return 2
    0xe0 <= first_byte <= 0xef && return 3
    0xf0 <= first_byte <= 0xf4 && return 4
    0
end

function _modifier_from_parameter(parameter::Int)
    parameter == 2 && return SHIFT
    parameter == 3 && return ALT
    parameter == 4 && return SHIFT | ALT
    parameter == 5 && return CTRL
    parameter == 6 && return SHIFT | CTRL
    parameter == 7 && return ALT | CTRL
    parameter == 8 && return SHIFT | ALT | CTRL
    NONE
end

function _csi_parameters(body::String)
    isempty(body) && return Int[]
    parsed = tryparse.(Int, split(body, ';'))
    any(isnothing, parsed) && return nothing
    return Int[something(value) for value in parsed]
end

function _csi_key(final::Char, body::String, raw::Vector{UInt8})
    parameters = _csi_parameters(body)
    parameters === nothing && return UnknownEvent(raw)
    modifier = length(parameters) >= 2 ? _modifier_from_parameter(parameters[end]) : NONE
    key = if final == 'A'
        :up
    elseif final == 'B'
        :down
    elseif final == 'C'
        :right
    elseif final == 'D'
        :left
    elseif final == 'H'
        :home
    elseif final == 'F'
        :end
    elseif final == 'Z'
        :backtab
    else
        return UnknownEvent(raw)
    end
    final == 'Z' && (modifier = modifier | SHIFT)
    KeyEvent(Key(key); modifiers=modifier, raw)
end

function _tilde_key(body::String, raw::Vector{UInt8})
    parameters = _csi_parameters(body)
    parameters === nothing && return UnknownEvent(raw)
    isempty(parameters) && return UnknownEvent(raw)
    key = get(
        Dict(
            1 => :home,
            2 => :insert,
            3 => :delete,
            4 => :end,
            5 => :page_up,
            6 => :page_down,
            7 => :home,
            8 => :end,
            11 => :f1,
            12 => :f2,
            13 => :f3,
            14 => :f4,
            15 => :f5,
            17 => :f6,
            18 => :f7,
            19 => :f8,
            20 => :f9,
            21 => :f10,
            23 => :f11,
            24 => :f12,
        ),
        parameters[1],
        nothing,
    )
    isnothing(key) && return UnknownEvent(raw)
    modifier = length(parameters) >= 2 ? _modifier_from_parameter(parameters[end]) : NONE
    KeyEvent(Key(key); modifiers=modifier, raw)
end

function _kitty_modifiers(value::Int)
    value >= 1 || return nothing
    flags = value - 1
    modifiers = NONE
    flags & 0x01 != 0 && (modifiers = modifiers | SHIFT)
    flags & 0x02 != 0 && (modifiers = modifiers | ALT)
    flags & 0x04 != 0 && (modifiers = modifiers | CTRL)
    flags & 0x08 != 0 && (modifiers = modifiers | SUPER)
    flags & 0x10 != 0 && (modifiers = modifiers | HYPER)
    flags & 0x20 != 0 && (modifiers = modifiers | META)
    flags & 0x40 != 0 && (modifiers = modifiers | CAPS_LOCK)
    flags & 0x80 != 0 && (modifiers = modifiers | NUM_LOCK)
    flags & ~0xff == 0 || return nothing
    modifiers
end

const _KITTY_FUNCTION_KEYS = Dict(
    57358 => :caps_lock,
    57359 => :scroll_lock,
    57360 => :num_lock,
    57361 => :print_screen,
    57362 => :pause,
    57363 => :menu,
    57376 => :f13,
    57377 => :f14,
    57378 => :f15,
    57379 => :f16,
    57380 => :f17,
    57381 => :f18,
    57430 => :media_play_pause,
    57431 => :media_reverse,
    57432 => :media_stop,
    57433 => :media_fast_forward,
    57434 => :media_rewind,
    57435 => :media_next,
    57436 => :media_previous,
    57437 => :media_record,
    57438 => :volume_down,
    57439 => :volume_up,
    57440 => :volume_mute,
    57441 => :left_shift,
    57442 => :left_control,
    57443 => :left_alt,
    57444 => :left_super,
    57445 => :left_hyper,
    57446 => :left_meta,
    57447 => :right_shift,
    57448 => :right_control,
    57449 => :right_alt,
    57450 => :right_super,
    57451 => :right_hyper,
    57452 => :right_meta,
    57453 => :iso_level3_shift,
    57454 => :iso_level5_shift,
)

function _valid_unicode_codepoint(value::Int)
    0 <= value <= 0x10ffff && !(0xd800 <= value <= 0xdfff)
end

function _kitty_text(field::AbstractString)
    isempty(field) && return ""
    values = tryparse.(Int, split(field, ':'; keepempty=true))
    any(isnothing, values) && return nothing
    codepoints = Int[something(value) for value in values]
    all(_valid_unicode_codepoint, codepoints) || return nothing
    any(value -> value < 0x20 || 0x7f <= value <= 0x9f, codepoints) && return nothing
    join(Char(value) for value in codepoints)
end

function _kitty_key(codepoint::Int, text::String)
    codepoint == 0 && return isempty(text) ? nothing : Key(:character)
    codepoint == 27 && return Key(:escape)
    codepoint == 13 && return Key(:enter)
    codepoint == 9 && return Key(:tab)
    codepoint in (8, 127) && return Key(:backspace)
    haskey(_KITTY_FUNCTION_KEYS, codepoint) && return Key(_KITTY_FUNCTION_KEYS[codepoint])
    _valid_unicode_codepoint(codepoint) || return nothing
    character = Char(codepoint)
    if isascii(character) && (isletter(character) || isnumeric(character))
        return Key(Symbol(lowercase(string(character))))
    end
    Key(:character)
end

function _kitty_key_event(body::String, raw::Vector{UInt8})
    startswith(body, '?') && return UnknownEvent(raw)
    fields = split(body, ';'; keepempty=true)
    1 <= length(fields) <= 3 || return UnknownEvent(raw)
    key_fields = split(fields[1], ':'; keepempty=true)
    isempty(key_fields) && return UnknownEvent(raw)
    codepoint = tryparse(Int, first(key_fields))
    isnothing(codepoint) && return UnknownEvent(raw)
    all(field -> isempty(field) || !isnothing(tryparse(Int, field)), key_fields[2:end]) ||
        return UnknownEvent(raw)

    modifier_fields = length(fields) >= 2 ? split(fields[2], ':'; keepempty=true) : SubString{String}[]
    modifier_value = isempty(modifier_fields) || isempty(modifier_fields[1]) ? 1 :
                     tryparse(Int, modifier_fields[1])
    isnothing(modifier_value) && return UnknownEvent(raw)
    modifiers = _kitty_modifiers(modifier_value)
    isnothing(modifiers) && return UnknownEvent(raw)
    event_value = length(modifier_fields) < 2 || isempty(modifier_fields[2]) ? 1 :
                  tryparse(Int, modifier_fields[2])
    isnothing(event_value) && return UnknownEvent(raw)
    kind = event_value == 1 ? KeyPress :
           event_value == 2 ? KeyRepeat :
           event_value == 3 ? KeyRelease : nothing
    isnothing(kind) && return UnknownEvent(raw)
    length(modifier_fields) <= 2 || return UnknownEvent(raw)

    text = length(fields) == 3 ? _kitty_text(fields[3]) : ""
    isnothing(text) && return UnknownEvent(raw)
    key = _kitty_key(codepoint, text)
    isnothing(key) && return UnknownEvent(raw)
    KeyEvent(key; text, modifiers, kind, raw)
end

function _mouse_event(body::String, final::Char, raw::Vector{UInt8})
    startswith(body, '<') || return UnknownEvent(raw)
    values = split(body[2:end], ';')
    length(values) == 3 || return UnknownEvent(raw)
    parsed = tryparse.(Int, values)
    any(isnothing, parsed) && return UnknownEvent(raw)
    code, column, row = something.(parsed)
    code >= 0 && row >= 1 && column >= 1 || return UnknownEvent(raw)
    modifiers = NONE
    code & 4 != 0 && (modifiers = modifiers | SHIFT)
    code & 8 != 0 && (modifiers = modifiers | ALT)
    code & 16 != 0 && (modifiers = modifiers | CTRL)
    base = code & 3
    wheel = code & 64 != 0
    motion = code & 32 != 0
    button = if wheel
        base == 0 ? WheelUpButton : WheelDownButton
    elseif base == 0
        LeftMouseButton
    elseif base == 1
        MiddleMouseButton
    elseif base == 2
        RightMouseButton
    else
        NoMouseButton
    end
    action = if wheel
        MouseScroll
    elseif final == 'm'
        MouseRelease
    elseif motion && button == NoMouseButton
        MouseMove
    elseif motion
        MouseDrag
    else
        MousePress
    end
    MouseEvent(Position(row, column), button, action; modifiers)
end

function _parse_csi!(parser::AnsiInputParser)
    final_index = findfirst(byte -> 0x40 <= byte <= 0x7e, @view(parser.buffer[3:end]))
    isnothing(final_index) && return nothing
    count = final_index + 2
    raw = _consume!(parser, count)
    final = Char(raw[end])
    body = String(raw[3:(end - 1)])
    isvalid(body) || return UnknownEvent(raw)
    final in ('A', 'B', 'C', 'D', 'H', 'F', 'Z') && return _csi_key(final, body, raw)
    final == '~' && return _tilde_key(body, raw)
    final == 'u' && return _kitty_key_event(body, raw)
    final in ('M', 'm') && return _mouse_event(body, final, raw)
    final == 'I' && return FocusEvent(true)
    final == 'O' && return FocusEvent(false)
    UnknownEvent(raw)
end

function _parse_regular!(parser::AnsiInputParser, modifiers::KeyModifiers=NONE)
    byte = parser.buffer[1]
    if byte in (0x0d, 0x0a)
        raw = _consume!(parser, 1)
        return KeyEvent(Key(:enter); text="\n", modifiers, raw)
    elseif byte == 0x09
        raw = _consume!(parser, 1)
        return KeyEvent(Key(:tab); text="\t", modifiers, raw)
    elseif byte in (0x08, 0x7f)
        raw = _consume!(parser, 1)
        return KeyEvent(Key(:backspace); modifiers, raw)
    elseif 0x01 <= byte <= 0x1a
        raw = _consume!(parser, 1)
        letter = Char(Int('a') + Int(byte) - 1)
        return KeyEvent(Key(Symbol(string(letter))); modifiers=modifiers | CTRL, raw)
    end
    count = _utf8_length(byte)
    count == 0 && return UnknownEvent(_consume!(parser, 1))
    length(parser.buffer) >= count || return nothing
    raw = _consume!(parser, count)
    if count > 1 && any(value -> value & 0xc0 != 0x80, @view(raw[2:end]))
        return UnknownEvent(raw)
    end
    text = String(copy(raw))
    isvalid(text) || return UnknownEvent(raw)
    KeyEvent(Key(:character); text, modifiers, raw)
end

function _parse_one!(parser::AnsiInputParser)
    isempty(parser.buffer) && return nothing
    parser.buffer[1] != _ESC && return _parse_regular!(parser)
    length(parser.buffer) == 1 && return nothing
    if _starts_with(parser.buffer, _PASTE_START)
        ending = _find_sequence(parser.buffer, _PASTE_END, length(_PASTE_START) + 1)
        if isnothing(ending)
            if length(parser.buffer) > parser.max_paste_bytes + length(_PASTE_START)
                empty!(parser.buffer)
                throw(ArgumentError("bracketed paste exceeds configured maximum"))
            end
            return nothing
        end
        payload_start = length(_PASTE_START) + 1
        payload_length = ending - payload_start
        count = ending + length(_PASTE_END) - 1
        if payload_length > parser.max_paste_bytes
            _consume!(parser, count)
            throw(ArgumentError("bracketed paste exceeds configured maximum"))
        end
        raw = _consume!(parser, count)
        payload = String(copy(@view raw[payload_start:(ending - 1)]))
        isvalid(payload) || return UnknownEvent(raw)
        return PasteEvent(payload)
    elseif parser.buffer[2] == UInt8('[')
        return _parse_csi!(parser)
    elseif parser.buffer[2] == UInt8('O')
        length(parser.buffer) >= 3 || return nothing
        raw = _consume!(parser, 3)
        key = get(Dict('P' => :f1, 'Q' => :f2, 'R' => :f3, 'S' => :f4), Char(raw[3]), nothing)
        return isnothing(key) ? UnknownEvent(raw) : KeyEvent(Key(key); raw)
    end
    next_length = _utf8_length(parser.buffer[2])
    next_length > 0 && length(parser.buffer) < next_length + 1 && return nothing
    _consume!(parser, 1)
    event = _parse_regular!(parser, ALT)
    isnothing(event) ? KeyEvent(Key(:escape); raw=UInt8[_ESC]) : event
end

"""Append bytes and return all complete parsed events."""
function feed!(parser::AnsiInputParser, bytes::AbstractVector{UInt8})
    if length(bytes) > parser.max_buffer_bytes - length(parser.buffer)
        empty!(parser.buffer)
        throw(ArgumentError("ANSI input buffer exceeds configured maximum"))
    end
    append!(parser.buffer, bytes)
    events = AbstractEvent[]
    while true
        event = _parse_one!(parser)
        isnothing(event) && break
        push!(events, event)
    end
    events
end

feed!(parser::AnsiInputParser, text::AbstractString) =
    feed!(parser, collect(codeunits(String(text))))

"""Resolve a pending lone escape byte as an Escape key event."""
function flush_escape!(parser::AnsiInputParser)
    parser.buffer == UInt8[_ESC] || return nothing
    empty!(parser.buffer)
    KeyEvent(Key(:escape); raw=UInt8[_ESC])
end

"""Flush an incomplete end-of-stream fragment and reset the parser."""
function flush_input!(parser::AnsiInputParser)
    isempty(parser.buffer) && return AbstractEvent[]
    if parser.buffer == UInt8[_ESC]
        return AbstractEvent[flush_escape!(parser)]
    end
    raw = copy(parser.buffer)
    empty!(parser.buffer)
    return AbstractEvent[UnknownEvent(raw)]
end

function _wait_for_input(input::IO, timeout_seconds::Float64)
    bytesavailable(input) > 0 && return true
    timeout_seconds == 0 && return false
    poll_interval = clamp(timeout_seconds / 10, 0.0005, 0.01)
    timedwait(
        () -> bytesavailable(input) > 0,
        timeout_seconds;
        pollint=poll_interval,
    ) == :ok
end

"""Blocking input source with configurable Escape-key disambiguation."""
mutable struct ParserInputSource{I<:IO,F} <: AbstractInputSource
    input::I
    parser::AnsiInputParser
    pending::Vector{AbstractEvent}
    escape_timeout_seconds::Float64
    wait_for_input::F
end

function ParserInputSource(
    input::I;
    parser::AnsiInputParser=AnsiInputParser(),
    escape_timeout_seconds::Real=0.025,
    wait_for_input::F=_wait_for_input,
) where {I<:IO,F}
    timeout = Float64(escape_timeout_seconds)
    isfinite(timeout) && timeout >= 0 ||
        throw(ArgumentError("escape timeout must be finite and nonnegative"))
    applicable(wait_for_input, input, timeout) ||
        throw(ArgumentError("input readiness callback must accept input and timeout"))
    ParserInputSource{I,F}(input, parser, AbstractEvent[], timeout, wait_for_input)
end

"""Read one parsed event, blocking until input becomes available."""
function read_event!(source::ParserInputSource)
    while isempty(source.pending)
        if source.parser.buffer == UInt8[_ESC]
            ready = source.wait_for_input(source.input, source.escape_timeout_seconds)
            ready isa Bool ||
                throw(ArgumentError("input readiness callback must return Bool"))
            if !ready
                push!(source.pending, flush_escape!(source.parser))
                break
            end
        end
        byte = read(source.input, UInt8)
        append!(source.pending, feed!(source.parser, UInt8[byte]))
    end
    popfirst!(source.pending)
end
