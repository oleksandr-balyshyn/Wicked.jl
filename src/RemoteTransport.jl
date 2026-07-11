module RemoteTransport

using ..Core
using ..Events
import ..Core: ColorKind, CursorShape
using ..Backends: AbstractBackend
import ..Backends: backend_capabilities,
                   backend_size,
                   enter!,
                   flush!,
                   leave!,
                   present!

export REMOTE_PROTOCOL_VERSION,
       AbstractRemoteMessage,
       RemoteAck,
       RemoteBackend,
       RemoteDecoder,
       RemoteEvent,
       RemoteFrame,
       RemoteHello,
       RemoteProtocolError,
       RemoteProtocolLimits,
       RemoteSession,
       close_remote_session!,
       decode_remote_packet,
       encode_remote_message,
       feed_remote!,
       ingest_remote!,
       pump_websocket!,
       request_remote_full_frame!,
       resize_remote_backend!,
       websocket_session

const REMOTE_PROTOCOL_VERSION = UInt16(1)
const _REMOTE_MAGIC = UInt8[0x57, 0x4b, 0x54, 0x31] # WKT1
const _HEADER_BYTES = 20
const _FULL_FRAME_FLAG = UInt8(0x01)

@enum _PacketKind::UInt8 begin
    _HelloPacket = 0x01
    _FramePacket = 0x02
    _EventPacket = 0x03
    _AckPacket = 0x04
end

"""Bounds applied before allocating or decoding remote protocol data."""
struct RemoteProtocolLimits
    maximum_packet_bytes::Int
    maximum_buffer_bytes::Int
    maximum_cells::Int
    maximum_string_bytes::Int

    function RemoteProtocolLimits(;
        maximum_packet_bytes::Integer=16 * 1024 * 1024,
        maximum_buffer_bytes::Integer=32 * 1024 * 1024,
        maximum_cells::Integer=4_000_000,
        maximum_string_bytes::Integer=1024 * 1024,
    )
        maximum_packet_bytes >= _HEADER_BYTES ||
            throw(ArgumentError("maximum packet size is smaller than the protocol header"))
        maximum_buffer_bytes >= maximum_packet_bytes ||
            throw(ArgumentError("maximum decoder buffer must hold one maximum-size packet"))
        maximum_cells > 0 || throw(ArgumentError("maximum cell count must be positive"))
        maximum_string_bytes > 0 ||
            throw(ArgumentError("maximum string size must be positive"))
        new(
            Int(maximum_packet_bytes),
            Int(maximum_buffer_bytes),
            Int(maximum_cells),
            Int(maximum_string_bytes),
        )
    end
end

"""Malformed, unsupported, or policy-violating remote protocol data."""
struct RemoteProtocolError <: Exception
    message::String
end

Base.showerror(io::IO, error::RemoteProtocolError) = print(io, error.message)

abstract type AbstractRemoteMessage end

"""Session negotiation message containing viewport and rendering capabilities."""
struct RemoteHello <: AbstractRemoteMessage
    sequence::UInt64
    size::Size
    capabilities::TerminalCapabilities
end

"""One authoritative full frame or ordered delta frame."""
struct RemoteFrame <: AbstractRemoteMessage
    sequence::UInt64
    full::Bool
    size::Size
    changes::Vector{CellChange}
    cursor::Union{Nothing,CursorRequest}
end

"""One typed input event received from a remote client."""
struct RemoteEvent <: AbstractRemoteMessage
    sequence::UInt64
    event::AbstractEvent
end

"""Acknowledgement of a successfully applied remote sequence."""
struct RemoteAck <: AbstractRemoteMessage
    sequence::UInt64
end

mutable struct RemoteDecoder
    buffer::Vector{UInt8}
    limits::RemoteProtocolLimits
end

RemoteDecoder(; limits::RemoteProtocolLimits=RemoteProtocolLimits()) =
    RemoteDecoder(UInt8[], limits)

function _put_unsigned!(output::Vector{UInt8}, value::Integer, bytes::Int)
    value >= 0 || throw(ArgumentError("wire integers must be non-negative"))
    maximum = bytes == 8 ? typemax(UInt64) : (UInt64(1) << (8 * bytes)) - 1
    UInt128(value) <= maximum || throw(ArgumentError("wire integer does not fit"))
    encoded = UInt64(value)
    for shift in (8 * (bytes - 1)):-8:0
        push!(output, UInt8((encoded >> shift) & 0xff))
    end
    return output
end

_put_u8!(output, value) = _put_unsigned!(output, value, 1)
_put_u16!(output, value) = _put_unsigned!(output, value, 2)
_put_u32!(output, value) = _put_unsigned!(output, value, 4)
_put_u64!(output, value) = _put_unsigned!(output, value, 8)

function _read_unsigned(data::AbstractVector{UInt8}, cursor::Base.RefValue{Int}, bytes::Int)
    cursor[] + bytes - 1 <= length(data) ||
        throw(RemoteProtocolError("truncated remote packet"))
    value = UInt64(0)
    for _ in 1:bytes
        value = (value << 8) | data[cursor[]]
        cursor[] += 1
    end
    return value
end

_read_u8(data, cursor) = UInt8(_read_unsigned(data, cursor, 1))
_read_u16(data, cursor) = UInt16(_read_unsigned(data, cursor, 2))
_read_u32(data, cursor) = UInt32(_read_unsigned(data, cursor, 4))
_read_u64(data, cursor) = _read_unsigned(data, cursor, 8)

function _put_blob!(output::Vector{UInt8}, data, limits::RemoteProtocolLimits)
    bytes = collect(UInt8, data)
    length(bytes) <= limits.maximum_string_bytes ||
        throw(RemoteProtocolError("remote byte string exceeds configured maximum"))
    _put_u32!(output, length(bytes))
    append!(output, bytes)
    return output
end

_put_string!(output, value::AbstractString, limits) =
    _put_blob!(output, codeunits(value), limits)

function _read_blob(data, cursor, limits::RemoteProtocolLimits)
    length = Int(_read_u32(data, cursor))
    length <= limits.maximum_string_bytes ||
        throw(RemoteProtocolError("remote byte string exceeds configured maximum"))
    cursor[] + length - 1 <= Base.length(data) ||
        throw(RemoteProtocolError("truncated remote byte string"))
    value = collect(UInt8, @view data[cursor[]:(cursor[] + length - 1)])
    cursor[] += length
    return value
end

function _read_string(data, cursor, limits)
    value = String(_read_blob(data, cursor, limits))
    isvalid(value) || throw(RemoteProtocolError("remote string is not valid UTF-8"))
    return value
end

function _put_size!(output, size::Size)
    _put_u32!(output, size.height)
    _put_u32!(output, size.width)
end

function _read_size(data, cursor, limits)
    height = Int(_read_u32(data, cursor))
    width = Int(_read_u32(data, cursor))
    height > 0 && width > div(typemax(Int), height) &&
        throw(RemoteProtocolError("remote viewport cell count overflows"))
    height * width <= limits.maximum_cells ||
        throw(RemoteProtocolError("remote viewport exceeds configured cell maximum"))
    return Size(height, width)
end

const _COLOR_LEVEL_TO_WIRE = Dict(:none => 0x00, :ansi16 => 0x01, :ansi256 => 0x02, :truecolor => 0x03)
const _WIRE_TO_COLOR_LEVEL = (:none, :ansi16, :ansi256, :truecolor)

function _put_capabilities!(output, capabilities::TerminalCapabilities)
    _put_u8!(output, _COLOR_LEVEL_TO_WIRE[capabilities.color_level])
    flags = UInt8(0)
    flags |= capabilities.mouse ? 0x01 : 0x00
    flags |= capabilities.focus ? 0x02 : 0x00
    flags |= capabilities.bracketed_paste ? 0x04 : 0x00
    flags |= capabilities.synchronized_updates ? 0x08 : 0x00
    flags |= capabilities.enhanced_keyboard ? 0x10 : 0x00
    flags |= capabilities.underline_color ? 0x20 : 0x00
    flags |= capabilities.terminal_title ? 0x40 : 0x00
    _put_u8!(output, flags)
end

function _read_capabilities(data, cursor)
    color = Int(_read_u8(data, cursor)) + 1
    color in eachindex(_WIRE_TO_COLOR_LEVEL) ||
        throw(RemoteProtocolError("unsupported remote color capability"))
    flags = _read_u8(data, cursor)
    flags & 0x80 == 0 || throw(RemoteProtocolError("unknown remote capability flag"))
    return TerminalCapabilities(
        color_level=_WIRE_TO_COLOR_LEVEL[color],
        mouse=flags & 0x01 != 0,
        focus=flags & 0x02 != 0,
        bracketed_paste=flags & 0x04 != 0,
        synchronized_updates=flags & 0x08 != 0,
        enhanced_keyboard=flags & 0x10 != 0,
        underline_color=flags & 0x20 != 0,
        terminal_title=flags & 0x40 != 0,
    )
end

function _put_color!(output, color::Color)
    _put_u8!(output, Int(color.kind))
    _put_u32!(output, color.value)
end

function _read_color(data, cursor)
    kind_value = _read_u8(data, cursor)
    kind_value <= 0x03 || throw(RemoteProtocolError("unknown remote color kind"))
    value = _read_u32(data, cursor)
    try
        return Color(ColorKind(kind_value), value)
    catch error
        throw(RemoteProtocolError("invalid remote color: $(sprint(showerror, error))"))
    end
end

function _contains_control(value::AbstractString)
    any(value) do character
        codepoint = Int(character)
        codepoint < 0x20 || 0x7f <= codepoint <= 0x9f
    end
end

function _put_style!(output, style::Style, limits)
    _put_color!(output, style.foreground)
    _put_color!(output, style.background)
    _put_color!(output, style.underline_color)
    _put_u16!(output, style.modifiers.bits)
    if style.hyperlink === nothing
        _put_u8!(output, 0)
    else
        _contains_control(style.hyperlink) &&
            throw(RemoteProtocolError("remote hyperlink contains a control character"))
        _put_u8!(output, 1)
        _put_string!(output, style.hyperlink, limits)
    end
end

function _read_style(data, cursor, limits)
    foreground = _read_color(data, cursor)
    background = _read_color(data, cursor)
    underline = _read_color(data, cursor)
    modifiers = Modifiers(_read_u16(data, cursor))
    hyperlink_tag = _read_u8(data, cursor)
    hyperlink_tag <= 1 || throw(RemoteProtocolError("invalid remote hyperlink tag"))
    hyperlink = hyperlink_tag == 0 ? nothing : _read_string(data, cursor, limits)
    hyperlink !== nothing && _contains_control(hyperlink) &&
        throw(RemoteProtocolError("remote hyperlink contains a control character"))
    return Style(
        foreground=foreground,
        background=background,
        underline_color=underline,
        modifiers=modifiers,
        hyperlink=hyperlink,
    )
end

function _put_cell!(output, cell::Cell, limits)
    !cell.continuation && _contains_control(cell.grapheme) &&
        throw(RemoteProtocolError("remote cell grapheme contains a control character"))
    _put_u8!(output, cell.width)
    _put_u8!(output, cell.continuation ? 1 : 0)
    _put_string!(output, cell.grapheme, limits)
    _put_style!(output, cell.style, limits)
end

function _read_cell(data, cursor, limits)
    width = _read_u8(data, cursor)
    continuation_tag = _read_u8(data, cursor)
    continuation_tag <= 1 || throw(RemoteProtocolError("invalid continuation tag"))
    grapheme = _read_string(data, cursor, limits)
    continuation = continuation_tag == 1
    !continuation && _contains_control(grapheme) &&
        throw(RemoteProtocolError("remote cell grapheme contains a control character"))
    style = _read_style(data, cursor, limits)
    try
        return Cell(grapheme, style, width, continuation)
    catch error
        throw(RemoteProtocolError("invalid remote cell: $(sprint(showerror, error))"))
    end
end

function _put_cursor!(output, cursor::Union{Nothing,CursorRequest})
    if cursor === nothing
        _put_u8!(output, 0)
        return
    end
    _put_u8!(output, 1)
    _put_u32!(output, cursor.position.row)
    _put_u32!(output, cursor.position.column)
    _put_u8!(output, cursor.visible ? 1 : 0)
    _put_u8!(output, Int(cursor.shape))
end

function _read_cursor(data, cursor, size::Size)
    tag = _read_u8(data, cursor)
    tag <= 1 || throw(RemoteProtocolError("invalid remote cursor tag"))
    tag == 0 && return nothing
    row = Int(_read_u32(data, cursor))
    column = Int(_read_u32(data, cursor))
    1 <= row <= size.height && 1 <= column <= size.width ||
        throw(RemoteProtocolError("remote cursor is outside the viewport"))
    visible = _read_u8(data, cursor)
    visible <= 1 || throw(RemoteProtocolError("invalid remote cursor visibility"))
    shape = _read_u8(data, cursor)
    shape <= UInt8(Int(BarCursor)) ||
        throw(RemoteProtocolError("unknown remote cursor shape"))
    return CursorRequest(Position(row, column), visible == 1, CursorShape(shape))
end

const _REMOTE_KEY_CODES = let
    codes = Symbol[
        :character, :escape, :enter, :tab, :backtab, :backspace, :delete,
        :insert, :home, :end, :pageup, :pagedown, :up, :down, :left, :right,
        :space, :null,
    ]
    append!(codes, [Symbol(string(character)) for character in 'a':'z'])
    append!(codes, [Symbol("f", index) for index in 1:64])
    Dict(string(code) => code for code in codes)
end

function _put_event!(output, event::AbstractEvent, limits)
    if event isa KeyEvent
        haskey(_REMOTE_KEY_CODES, string(event.key.code)) ||
            throw(RemoteProtocolError("unsupported remote key code: $(event.key.code)"))
        _put_u8!(output, 0x01)
        _put_string!(output, string(event.key.code), limits)
        _put_string!(output, event.text, limits)
        _put_u8!(output, event.modifiers.bits)
        _put_u8!(output, Int(event.kind))
        _put_blob!(output, event.raw, limits)
    elseif event isa MouseEvent
        _put_u8!(output, 0x02)
        _put_u32!(output, event.position.row)
        _put_u32!(output, event.position.column)
        _put_u8!(output, Int(event.button))
        _put_u8!(output, Int(event.action))
        _put_u8!(output, event.modifiers.bits)
        _put_u8!(output, event.click_count)
    elseif event isa PasteEvent
        _put_u8!(output, 0x03)
        _put_string!(output, event.text, limits)
    elseif event isa ResizeEvent
        _put_u8!(output, 0x04)
        _put_size!(output, event.size)
    elseif event isa FocusEvent
        _put_u8!(output, 0x05)
        _put_u8!(output, event.focused ? 1 : 0)
    elseif event isa TickEvent
        _put_u8!(output, 0x06)
        _put_u64!(output, event.timestamp_ns)
        _put_u64!(output, event.elapsed_ns)
    elseif event isa UnknownEvent
        _put_u8!(output, 0x07)
        _put_blob!(output, event.raw, limits)
    else
        throw(RemoteProtocolError("event type $(typeof(event)) is not remotely serializable"))
    end
end

function _enum_value(type, value, label)
    try
        return type(value)
    catch
        throw(RemoteProtocolError("unknown remote $label"))
    end
end

function _read_event(data, cursor, limits)
    tag = _read_u8(data, cursor)
    if tag == 0x01
        code = _read_string(data, cursor, limits)
        key = get(_REMOTE_KEY_CODES, code, nothing)
        key === nothing && throw(RemoteProtocolError("unsupported remote key code"))
        text = _read_string(data, cursor, limits)
        modifiers = KeyModifiers(_read_u8(data, cursor))
        kind = _enum_value(Events.KeyEventKind, _read_u8(data, cursor), "key event kind")
        raw = _read_blob(data, cursor, limits)
        return KeyEvent(Key(key); text, modifiers, kind, raw)
    elseif tag == 0x02
        row = Int(_read_u32(data, cursor))
        column = Int(_read_u32(data, cursor))
        row > 0 && column > 0 || throw(RemoteProtocolError("remote mouse position must be positive"))
        button = _enum_value(Events.MouseButton, _read_u8(data, cursor), "mouse button")
        action = _enum_value(Events.MouseAction, _read_u8(data, cursor), "mouse action")
        modifiers = KeyModifiers(_read_u8(data, cursor))
        clicks = _read_u8(data, cursor)
        return MouseEvent(Position(row, column), button, action; modifiers, click_count=clicks)
    elseif tag == 0x03
        return PasteEvent(_read_string(data, cursor, limits))
    elseif tag == 0x04
        return ResizeEvent(_read_size(data, cursor, limits))
    elseif tag == 0x05
        focused = _read_u8(data, cursor)
        focused <= 1 || throw(RemoteProtocolError("invalid remote focus value"))
        return FocusEvent(focused == 1)
    elseif tag == 0x06
        return TickEvent(_read_u64(data, cursor), _read_u64(data, cursor))
    elseif tag == 0x07
        return UnknownEvent(_read_blob(data, cursor, limits))
    end
    throw(RemoteProtocolError("unknown remote event type"))
end

function _payload(message::RemoteHello, limits)
    output = UInt8[]
    _put_size!(output, message.size)
    _put_capabilities!(output, message.capabilities)
    return output
end

function _payload(message::RemoteFrame, limits)
    cells = message.size.height * message.size.width
    cells <= limits.maximum_cells ||
        throw(RemoteProtocolError("remote viewport exceeds configured cell maximum"))
    length(message.changes) <= cells ||
        throw(RemoteProtocolError("remote frame contains too many cell changes"))
    message.full && length(message.changes) != cells &&
        throw(RemoteProtocolError("a full remote frame must contain every cell"))
    output = UInt8[]
    _put_size!(output, message.size)
    _put_cursor!(output, message.cursor)
    _put_u32!(output, length(message.changes))
    seen = Set{Tuple{Int,Int}}()
    for change in message.changes
        row = change.position.row
        column = change.position.column
        1 <= row <= message.size.height && 1 <= column <= message.size.width ||
            throw(RemoteProtocolError("remote cell change is outside the viewport"))
        location = (row, column)
        location in seen && throw(RemoteProtocolError("remote frame contains duplicate cell changes"))
        push!(seen, location)
        _put_u32!(output, row)
        _put_u32!(output, column)
        _put_cell!(output, change.cell, limits)
    end
    return output
end

function _payload(message::RemoteEvent, limits)
    output = UInt8[]
    _put_event!(output, message.event, limits)
    return output
end

_payload(::RemoteAck, ::RemoteProtocolLimits) = UInt8[]

_packet_kind(::RemoteHello) = _HelloPacket
_packet_kind(::RemoteFrame) = _FramePacket
_packet_kind(::RemoteEvent) = _EventPacket
_packet_kind(::RemoteAck) = _AckPacket
_packet_flags(::AbstractRemoteMessage) = UInt8(0)
_packet_flags(message::RemoteFrame) = message.full ? _FULL_FRAME_FLAG : UInt8(0)

"""Encode one complete, transport-agnostic Wicked remote protocol packet."""
function encode_remote_message(
    message::AbstractRemoteMessage;
    limits::RemoteProtocolLimits=RemoteProtocolLimits(),
)
    payload = _payload(message, limits)
    length(payload) + _HEADER_BYTES <= limits.maximum_packet_bytes ||
        throw(RemoteProtocolError("remote packet exceeds configured maximum"))
    output = copy(_REMOTE_MAGIC)
    _put_u16!(output, REMOTE_PROTOCOL_VERSION)
    _put_u8!(output, Int(_packet_kind(message)))
    _put_u8!(output, _packet_flags(message))
    _put_u64!(output, message.sequence)
    _put_u32!(output, length(payload))
    append!(output, payload)
    return output
end

function _decode_frame(payload, cursor, sequence, full, limits)
    size = _read_size(payload, cursor, limits)
    cursor_request = _read_cursor(payload, cursor, size)
    count = Int(_read_u32(payload, cursor))
    cells = size.height * size.width
    count <= cells || throw(RemoteProtocolError("remote frame contains too many cell changes"))
    full && count != cells &&
        throw(RemoteProtocolError("a full remote frame must contain every cell"))
    changes = CellChange[]
    sizehint!(changes, count)
    seen = Set{Tuple{Int,Int}}()
    for _ in 1:count
        row = Int(_read_u32(payload, cursor))
        column = Int(_read_u32(payload, cursor))
        1 <= row <= size.height && 1 <= column <= size.width ||
            throw(RemoteProtocolError("remote cell change is outside the viewport"))
        location = (row, column)
        location in seen && throw(RemoteProtocolError("remote frame contains duplicate cell changes"))
        push!(seen, location)
        push!(changes, CellChange(Position(row, column), _read_cell(payload, cursor, limits)))
    end
    return RemoteFrame(sequence, full, size, changes, cursor_request)
end

function _decode_payload(kind, flags, sequence, payload, limits)
    cursor = Ref(1)
    message = if kind == _HelloPacket
        flags == 0 || throw(RemoteProtocolError("unknown remote hello flags"))
        RemoteHello(sequence, _read_size(payload, cursor, limits), _read_capabilities(payload, cursor))
    elseif kind == _FramePacket
        flags & ~_FULL_FRAME_FLAG == 0 || throw(RemoteProtocolError("unknown remote frame flags"))
        _decode_frame(payload, cursor, sequence, flags & _FULL_FRAME_FLAG != 0, limits)
    elseif kind == _EventPacket
        flags == 0 || throw(RemoteProtocolError("unknown remote event flags"))
        RemoteEvent(sequence, _read_event(payload, cursor, limits))
    elseif kind == _AckPacket
        flags == 0 || throw(RemoteProtocolError("unknown remote acknowledgement flags"))
        RemoteAck(sequence)
    else
        throw(RemoteProtocolError("unknown remote packet kind"))
    end
    cursor[] == length(payload) + 1 ||
        throw(RemoteProtocolError("remote packet contains trailing payload data"))
    return message
end

"""Decode exactly one complete remote packet."""
function decode_remote_packet(
    packet::AbstractVector{UInt8};
    limits::RemoteProtocolLimits=RemoteProtocolLimits(),
)
    length(packet) >= _HEADER_BYTES || throw(RemoteProtocolError("truncated remote header"))
    length(packet) <= limits.maximum_packet_bytes ||
        throw(RemoteProtocolError("remote packet exceeds configured maximum"))
    packet[1:4] == _REMOTE_MAGIC || throw(RemoteProtocolError("invalid remote packet magic"))
    cursor = Ref(5)
    version = _read_u16(packet, cursor)
    version == REMOTE_PROTOCOL_VERSION ||
        throw(RemoteProtocolError("unsupported remote protocol version $version"))
    kind_value = _read_u8(packet, cursor)
    kind = try
        _PacketKind(kind_value)
    catch
        throw(RemoteProtocolError("unknown remote packet kind"))
    end
    flags = _read_u8(packet, cursor)
    sequence = _read_u64(packet, cursor)
    payload_length = Int(_read_u32(packet, cursor))
    payload_length + _HEADER_BYTES == length(packet) ||
        throw(RemoteProtocolError("remote packet length does not match its header"))
    payload = @view packet[cursor[]:end]
    return _decode_payload(kind, flags, sequence, payload, limits)
end

"""Feed fragmented or combined transport bytes and return complete messages."""
function feed_remote!(decoder::RemoteDecoder, data)
    bytes = collect(UInt8, data)
    length(decoder.buffer) + length(bytes) <= decoder.limits.maximum_buffer_bytes || begin
        empty!(decoder.buffer)
        throw(RemoteProtocolError("remote decoder buffer exceeds configured maximum"))
    end
    append!(decoder.buffer, bytes)
    messages = AbstractRemoteMessage[]
    consumed = 0
    while length(decoder.buffer) - consumed >= _HEADER_BYTES
        start = consumed + 1
        decoder.buffer[start:(start + 3)] == _REMOTE_MAGIC || begin
            empty!(decoder.buffer)
            throw(RemoteProtocolError("invalid remote packet magic"))
        end
        header_cursor = Ref(start + 16)
        payload_length = Int(_read_u32(decoder.buffer, header_cursor))
        packet_length = _HEADER_BYTES + payload_length
        packet_length <= decoder.limits.maximum_packet_bytes || begin
            empty!(decoder.buffer)
            throw(RemoteProtocolError("remote packet exceeds configured maximum"))
        end
        length(decoder.buffer) - consumed >= packet_length || break
        packet = @view decoder.buffer[start:(start + packet_length - 1)]
        try
            push!(messages, decode_remote_packet(packet; limits=decoder.limits))
        catch
            empty!(decoder.buffer)
            rethrow()
        end
        consumed += packet_length
    end
    consumed > 0 && deleteat!(decoder.buffer, 1:consumed)
    return messages
end

struct _RemoteIOSender{I<:IO}
    output::I
end

(sender::_RemoteIOSender)(packet) = write(sender.output, packet)

"""Backend that emits versioned frame packets through an injected binary sender."""
mutable struct RemoteBackend{S} <: AbstractBackend
    sender::S
    viewport::Size
    capabilities::TerminalCapabilities
    limits::RemoteProtocolLimits
    next_sequence::UInt64
    force_full::Bool
    active::Bool
end

function RemoteBackend(
    sender::S;
    size::Size=Size(24, 80),
    capabilities::TerminalCapabilities=TerminalCapabilities(),
    limits::RemoteProtocolLimits=RemoteProtocolLimits(),
) where {S}
    size.height * size.width <= limits.maximum_cells ||
        throw(ArgumentError("remote viewport exceeds configured cell maximum"))
    applicable(sender, UInt8[]) ||
        throw(ArgumentError("remote sender must accept a Vector{UInt8}"))
    return RemoteBackend{S}(sender, size, capabilities, limits, 0, true, false)
end

RemoteBackend(output::IO; kwargs...) = RemoteBackend(_RemoteIOSender(output); kwargs...)

backend_size(backend::RemoteBackend) = backend.viewport
backend_capabilities(backend::RemoteBackend) = backend.capabilities

function _send_remote!(backend::RemoteBackend, message::AbstractRemoteMessage)
    backend.next_sequence == typemax(UInt64) &&
        throw(OverflowError("remote transport sequence exhausted"))
    packet = encode_remote_message(message; limits=backend.limits)
    result = backend.sender(packet)
    result === false && throw(RemoteProtocolError("remote sender rejected packet"))
    backend.next_sequence += 1
    return packet
end

function enter!(backend::RemoteBackend)
    backend.active && return nothing
    _send_remote!(
        backend,
        RemoteHello(backend.next_sequence, backend.viewport, backend.capabilities),
    )
    backend.active = true
    backend.force_full = true
    return nothing
end

function leave!(backend::RemoteBackend)
    backend.active || return nothing
    flush!(backend)
    backend.active = false
    return nothing
end

flush!(backend::RemoteBackend{<:_RemoteIOSender}) = flush(backend.sender.output)
flush!(::RemoteBackend) = nothing

function _complete_changes(buffer::Buffer)
    changes = CellChange[]
    sizehint!(changes, length(buffer))
    for row in buffer.area.row:(buffer.area.row + buffer.area.height - 1)
        for column in buffer.area.column:(buffer.area.column + buffer.area.width - 1)
            push!(changes, CellChange(Position(row, column), buffer[row, column]))
        end
    end
    return changes
end

function present!(
    backend::RemoteBackend,
    changes::AbstractVector{CellChange},
    completed::Buffer,
    cursor::Union{Nothing,CursorRequest},
)
    size(completed) == (backend.viewport.height, backend.viewport.width) ||
        throw(DimensionMismatch("completed frame does not match remote viewport"))
    full = backend.force_full
    transmitted = full ? _complete_changes(completed) : collect(CellChange, changes)
    _send_remote!(
        backend,
        RemoteFrame(backend.next_sequence, full, backend.viewport, transmitted, cursor),
    )
    backend.force_full = false
    return nothing
end

"""Force the next successful presentation to contain every viewport cell."""
request_remote_full_frame!(backend::RemoteBackend) = (backend.force_full = true; backend)

"""Update the negotiated viewport and force a complete synchronization frame."""
function resize_remote_backend!(backend::RemoteBackend, size::Size)
    size.height * size.width <= backend.limits.maximum_cells ||
        throw(ArgumentError("remote viewport exceeds configured cell maximum"))
    backend.viewport = size
    backend.force_full = true
    return backend
end

resize_remote_backend!(backend::RemoteBackend, height::Integer, width::Integer) =
    resize_remote_backend!(backend, Size(height, width))

"""A remote backend paired with bounded typed input and sequence tracking."""
mutable struct RemoteSession{B<:RemoteBackend}
    backend::B
    input::ChannelInputSource
    decoder::RemoteDecoder
    next_event_sequence::UInt64
    acknowledged_sequence::Union{Nothing,UInt64}
    closed::Bool
end

function RemoteSession(
    sender;
    size::Size=Size(24, 80),
    capabilities::TerminalCapabilities=TerminalCapabilities(),
    limits::RemoteProtocolLimits=RemoteProtocolLimits(),
    input_capacity::Integer=1024,
)
    backend = RemoteBackend(sender; size, capabilities, limits)
    return RemoteSession(
        backend,
        ChannelInputSource(input_capacity),
        RemoteDecoder(; limits),
        UInt64(0),
        nothing,
        false,
    )
end

"""Decode client packets, enforce ordering, and queue their typed events."""
function ingest_remote!(session::RemoteSession, data::AbstractVector{UInt8})
    session.closed && throw(RemoteProtocolError("remote session is closed"))
    messages = feed_remote!(session.decoder, data)
    for message in messages
        if message isa RemoteEvent
            message.sequence == session.next_event_sequence ||
                throw(RemoteProtocolError(
                    "remote event sequence gap: expected $(session.next_event_sequence), received $(message.sequence)",
                ))
            if message.event isa ResizeEvent
                resize_remote_backend!(session.backend, message.event.size)
            end
            post_event!(session.input, message.event) ||
                throw(RemoteProtocolError("remote input queue is closed or full"))
            session.next_event_sequence == typemax(UInt64) &&
                throw(OverflowError("remote event sequence exhausted"))
            session.next_event_sequence += 1
        elseif message isa RemoteAck
            session.acknowledged_sequence = message.sequence
        else
            throw(RemoteProtocolError("client sent a server-only remote message"))
        end
    end
    return length(messages)
end

"""Close remote input delivery. Repeated calls are harmless."""
function close_remote_session!(session::RemoteSession)
    session.closed && return session
    session.closed = true
    close_input!(session.input)
    empty!(session.decoder.buffer)
    return session
end

"""Construct a `RemoteSession` for an optional WebSocket implementation."""
function websocket_session end

"""Pump binary WebSocket messages into a `RemoteSession` until closure."""
function pump_websocket! end

end
