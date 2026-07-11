@enum CursorShape::UInt8 begin
    DefaultCursor
    BlockCursor
    UnderlineCursor
    BarCursor
end

"""Capabilities negotiated or explicitly configured for a rendering surface."""
struct TerminalCapabilities
    color_level::Symbol
    mouse::Bool
    focus::Bool
    bracketed_paste::Bool
    synchronized_updates::Bool
    enhanced_keyboard::Bool
    underline_color::Bool
    terminal_title::Bool

    function TerminalCapabilities(;
        color_level::Symbol=:ansi16,
        mouse::Bool=true,
        focus::Bool=true,
        bracketed_paste::Bool=true,
        synchronized_updates::Bool=false,
        enhanced_keyboard::Bool=false,
        underline_color::Bool=true,
        terminal_title::Bool=true,
    )
        color_level in (:none, :ansi16, :ansi256, :truecolor) ||
            throw(ArgumentError("unsupported color capability: $color_level"))
        new(
            color_level,
            mouse,
            focus,
            bracketed_paste,
            synchronized_updates,
            enhanced_keyboard,
            underline_color,
            terminal_title,
        )
    end
end

"""A widget request for terminal cursor placement and shape."""
struct CursorRequest
    position::Position
    visible::Bool
    shape::CursorShape
end

CursorRequest(position::Position; visible::Bool=true, shape::CursorShape=DefaultCursor) =
    CursorRequest(position, visible, shape)

"""The mutable render context for one terminal frame."""
mutable struct Frame
    buffer::Buffer
    area::Rect
    frame_count::UInt64
    cursor::Union{Nothing,CursorRequest}
    capabilities::TerminalCapabilities
end

function Frame(
    buffer::Buffer,
    frame_count::Integer=0;
    capabilities::TerminalCapabilities=TerminalCapabilities(),
)
    Frame(buffer, buffer.area, UInt64(frame_count), nothing, capabilities)
end

function Frame(
    buffer::Buffer,
    area::Rect,
    frame_count::Integer,
    cursor::Union{Nothing,CursorRequest};
    capabilities::TerminalCapabilities=TerminalCapabilities(),
)
    Frame(buffer, area, UInt64(frame_count), cursor, capabilities)
end

"""Set the cursor request for the current frame."""
function request_cursor!(frame::Frame, request::CursorRequest)
    contains(frame.area, request.position) ||
        throw(BoundsError(frame.buffer, (request.position.row, request.position.column)))
    frame.cursor = request
    frame
end

function request_cursor!(
    frame::Frame,
    row::Integer,
    column::Integer;
    visible::Bool=true,
    shape::CursorShape=DefaultCursor,
)
    request_cursor!(frame, CursorRequest(Position(row, column); visible, shape))
end

"""Open rendering interface for stateless and stateful widgets."""
function render! end

"""Optional content measurement interface for widgets."""
function measure end

render!(frame::Frame, widget, area::Rect) = render!(frame.buffer, widget, area)
render!(frame::Frame, widget, area::Rect, state) =
    render!(frame.buffer, widget, area, state)
