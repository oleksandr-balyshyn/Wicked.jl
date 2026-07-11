module Events

using ..Core: Position, Size

"""Base type for terminal and application events."""
abstract type AbstractEvent end

"""Base type for cancellable event sources."""
abstract type AbstractInputSource end

"""A logical keyboard key independent of a terminal byte sequence."""
struct Key
    code::Symbol
end

@enum KeyEventKind::UInt8 begin
    KeyPress
    KeyRepeat
    KeyRelease
end

"""A compact set of keyboard modifiers."""
struct KeyModifiers
    bits::UInt8
end

const NONE = KeyModifiers(0x00)
const SHIFT = KeyModifiers(0x01)
const ALT = KeyModifiers(0x02)
const CTRL = KeyModifiers(0x04)
const SUPER = KeyModifiers(0x08)
const HYPER = KeyModifiers(0x10)
const META = KeyModifiers(0x20)
const CAPS_LOCK = KeyModifiers(0x40)
const NUM_LOCK = KeyModifiers(0x80)

Base.:|(left::KeyModifiers, right::KeyModifiers) =
    KeyModifiers(left.bits | right.bits)
Base.:&(left::KeyModifiers, right::KeyModifiers) =
    KeyModifiers(left.bits & right.bits)
Base.in(modifier::KeyModifiers, modifiers::KeyModifiers) =
    (modifiers.bits & modifier.bits) == modifier.bits
Base.isempty(modifiers::KeyModifiers) = iszero(modifiers.bits)

"""A parsed keyboard event."""
struct KeyEvent <: AbstractEvent
    key::Key
    text::String
    modifiers::KeyModifiers
    kind::KeyEventKind
    raw::Vector{UInt8}
end

KeyEvent(
    key::Key;
    text::AbstractString="",
    modifiers::KeyModifiers=NONE,
    kind::KeyEventKind=KeyPress,
    raw::AbstractVector{UInt8}=UInt8[],
) = KeyEvent(key, String(text), modifiers, kind, collect(UInt8, raw))

@enum MouseButton::UInt8 begin
    NoMouseButton
    LeftMouseButton
    MiddleMouseButton
    RightMouseButton
    WheelUpButton
    WheelDownButton
end

@enum MouseAction::UInt8 begin
    MousePress
    MouseRelease
    MouseMove
    MouseDrag
    MouseScroll
end

"""A mouse event using one-based terminal coordinates."""
struct MouseEvent <: AbstractEvent
    position::Position
    button::MouseButton
    action::MouseAction
    modifiers::KeyModifiers
    click_count::UInt8
end

MouseEvent(
    position::Position,
    button::MouseButton,
    action::MouseAction;
    modifiers::KeyModifiers=NONE,
    click_count::Integer=1,
) = begin
    0 <= click_count <= typemax(UInt8) ||
        throw(ArgumentError("click count must fit in UInt8"))
    MouseEvent(position, button, action, modifiers, UInt8(click_count))
end

"""A complete bracketed-paste payload."""
struct PasteEvent <: AbstractEvent
    text::String
end

"""A terminal resize notification."""
struct ResizeEvent <: AbstractEvent
    size::Size
end

"""A terminal focus notification."""
struct FocusEvent <: AbstractEvent
    focused::Bool
end

"""A monotonic application tick."""
struct TickEvent <: AbstractEvent
    timestamp_ns::UInt64
    elapsed_ns::UInt64
end

"""An application-defined event payload."""
struct CustomEvent{T} <: AbstractEvent
    payload::T
end

"""A terminal sequence that the parser does not recognize."""
struct UnknownEvent <: AbstractEvent
    raw::Vector{UInt8}
end

Base.:(==)(left::Key, right::Key) = left.code == right.code
Base.isequal(left::Key, right::Key) = isequal(left.code, right.code)
Base.hash(value::Key, seed::UInt) = hash(value.code, seed)

Base.:(==)(left::KeyModifiers, right::KeyModifiers) = left.bits == right.bits
Base.isequal(left::KeyModifiers, right::KeyModifiers) = isequal(left.bits, right.bits)
Base.hash(value::KeyModifiers, seed::UInt) = hash(value.bits, seed)

Base.:(==)(left::KeyEvent, right::KeyEvent) =
    left.key == right.key &&
    left.text == right.text &&
    left.modifiers == right.modifiers &&
    left.kind == right.kind &&
    left.raw == right.raw
Base.isequal(left::KeyEvent, right::KeyEvent) =
    isequal(left.key, right.key) &&
    isequal(left.text, right.text) &&
    isequal(left.modifiers, right.modifiers) &&
    isequal(left.kind, right.kind) &&
    isequal(left.raw, right.raw)
Base.hash(value::KeyEvent, seed::UInt) =
    hash((value.key, value.text, value.modifiers, value.kind, value.raw), seed)

Base.:(==)(left::MouseEvent, right::MouseEvent) =
    left.position == right.position &&
    left.button == right.button &&
    left.action == right.action &&
    left.modifiers == right.modifiers &&
    left.click_count == right.click_count
Base.isequal(left::MouseEvent, right::MouseEvent) =
    isequal(left.position, right.position) &&
    isequal(left.button, right.button) &&
    isequal(left.action, right.action) &&
    isequal(left.modifiers, right.modifiers) &&
    isequal(left.click_count, right.click_count)
Base.hash(value::MouseEvent, seed::UInt) = hash(
    (value.position, value.button, value.action, value.modifiers, value.click_count),
    seed,
)

Base.:(==)(left::PasteEvent, right::PasteEvent) = left.text == right.text
Base.isequal(left::PasteEvent, right::PasteEvent) = isequal(left.text, right.text)
Base.hash(value::PasteEvent, seed::UInt) = hash(value.text, seed)

Base.:(==)(left::ResizeEvent, right::ResizeEvent) = left.size == right.size
Base.isequal(left::ResizeEvent, right::ResizeEvent) = isequal(left.size, right.size)
Base.hash(value::ResizeEvent, seed::UInt) = hash(value.size, seed)

Base.:(==)(left::FocusEvent, right::FocusEvent) = left.focused == right.focused
Base.isequal(left::FocusEvent, right::FocusEvent) = isequal(left.focused, right.focused)
Base.hash(value::FocusEvent, seed::UInt) = hash(value.focused, seed)

Base.:(==)(left::TickEvent, right::TickEvent) =
    left.timestamp_ns == right.timestamp_ns && left.elapsed_ns == right.elapsed_ns
Base.isequal(left::TickEvent, right::TickEvent) =
    isequal(left.timestamp_ns, right.timestamp_ns) &&
    isequal(left.elapsed_ns, right.elapsed_ns)
Base.hash(value::TickEvent, seed::UInt) = hash((value.timestamp_ns, value.elapsed_ns), seed)

Base.:(==)(left::CustomEvent, right::CustomEvent) = left.payload == right.payload
Base.isequal(left::CustomEvent, right::CustomEvent) = isequal(left.payload, right.payload)
Base.hash(value::CustomEvent, seed::UInt) = hash(value.payload, seed)

Base.:(==)(left::UnknownEvent, right::UnknownEvent) = left.raw == right.raw
Base.isequal(left::UnknownEvent, right::UnknownEvent) = isequal(left.raw, right.raw)
Base.hash(value::UnknownEvent, seed::UInt) = hash(value.raw, seed)

include("events/ansi_parser.jl")
include("events/channel_source.jl")

export ALT,
       AnsiInputParser,
       AbstractEvent,
       AbstractInputSource,
       CTRL,
       CAPS_LOCK,
       ChannelInputSource,
       CustomEvent,
       FocusEvent,
       Key,
       KeyEvent,
       KeyModifiers,
       KeyPress,
       KeyRelease,
       KeyRepeat,
       HYPER,
       LeftMouseButton,
       META,
       MouseAction,
       MouseButton,
       MouseDrag,
       MouseEvent,
       MouseMove,
       MousePress,
       MouseRelease,
       MouseScroll,
       MiddleMouseButton,
       NONE,
       NUM_LOCK,
       NoMouseButton,
       ParserInputSource,
       PasteEvent,
       ResizeEvent,
       RightMouseButton,
       SHIFT,
       SUPER,
       TickEvent,
       WheelDownButton,
       WheelUpButton,
       UnknownEvent,
       feed!,
       flush_escape!,
       flush_input!,
       close_input!,
       post_event!,
       read_event!

end
