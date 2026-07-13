"""Explicit two-dimensional scroll state."""
mutable struct ScrollState
    row::Int
    column::Int

    function ScrollState(; row::Integer=0, column::Integer=0)
        row >= 0 || throw(ArgumentError("scroll row must be non-negative"))
        column >= 0 || throw(ArgumentError("scroll column must be non-negative"))
        new(Int(row), Int(column))
    end
end

"""Render a child into a virtual surface and copy its visible viewport."""
struct ScrollView{W}
    child::W
    content_size::Size
end

state_for(::ScrollView) = ScrollState()

ScrollView(child; height::Integer, width::Integer) = ScrollView(child, Size(height, width))

function render!(buffer::Buffer, widget::ScrollView, area::Rect, state::ScrollState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    surface = Buffer(widget.content_size.height, widget.content_size.width)
    render!(surface, widget.child, surface.area)
    max_row = max(0, widget.content_size.height - active.height)
    max_column = max(0, widget.content_size.width - active.width)
    state.row = clamp(state.row, 0, max_row)
    state.column = clamp(state.column, 0, max_column)
    for target_row in active.row:(active.row + active.height - 1)
        source_row = target_row - active.row + state.row + 1
        source_row > widget.content_size.height && break
        for target_column in active.column:(active.column + active.width - 1)
            source_column = target_column - active.column + state.column + 1
            source_column > widget.content_size.width && break
            cell = surface[source_row, source_column]
            cell.continuation && continue
            cell.width == 2 && target_column == active.column + active.width - 1 && continue
            buffer[target_row, target_column] = cell
        end
    end
    buffer
end

render!(buffer::Buffer, widget::ScrollView, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

@enum ScrollbarDirection::UInt8 begin
    VerticalScrollbar
    HorizontalScrollbar
end

"""A track and thumb representation of scroll state."""
struct Scrollbar
    direction::ScrollbarDirection
    content_length::Int
    viewport_length::Int
    track_style::Style
    thumb_style::Style
    track_symbol::String
    thumb_symbol::String

    function Scrollbar(
        direction::ScrollbarDirection,
        content_length::Integer,
        viewport_length::Integer;
        track_style::Style=Style(),
        thumb_style::Style=Style(modifiers=REVERSED),
        track_symbol::AbstractString="░",
        thumb_symbol::AbstractString="█",
    )
        content_length >= 0 || throw(ArgumentError("content length must be non-negative"))
        viewport_length >= 0 || throw(ArgumentError("viewport length must be non-negative"))
        new(
            direction,
            Int(content_length),
            Int(viewport_length),
            track_style,
            thumb_style,
            String(track_symbol),
            String(thumb_symbol),
        )
    end
end

state_for(::Scrollbar) = ScrollState()

function render!(buffer::Buffer, widget::Scrollbar, area::Rect, state::ScrollState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    track_length = widget.direction == VerticalScrollbar ? active.height : active.width
    track_length == 0 && return buffer
    content_length = max(widget.content_length, widget.viewport_length, 1)
    thumb_length = clamp(
        floor(Int, track_length * widget.viewport_length / content_length),
        1,
        track_length,
    )
    scroll = widget.direction == VerticalScrollbar ? state.row : state.column
    maximum_scroll = max(0, widget.content_length - widget.viewport_length)
    thumb_offset = maximum_scroll == 0 ? 0 :
        round(Int, (track_length - thumb_length) * clamp(scroll, 0, maximum_scroll) / maximum_scroll)
    for offset in 0:(track_length - 1)
        thumb = thumb_offset <= offset < thumb_offset + thumb_length
        row = widget.direction == VerticalScrollbar ? active.row + offset : active.row
        column = widget.direction == VerticalScrollbar ? active.column : active.column + offset
        symbol = thumb ? widget.thumb_symbol : widget.track_symbol
        style = thumb ? widget.thumb_style : widget.track_style
        _put!(buffer, row, column, symbol, style, active)
    end
    buffer
end

render!(buffer::Buffer, widget::Scrollbar, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function _scroll_offset(value::Int, delta::Integer)
    return Int(clamp(Int128(value) + Int128(delta), Int128(0), Int128(typemax(Int))))
end

function handle!(
    state::ScrollState,
    widget::ScrollView,
    event::KeyEvent;
    page_step::Integer=10,
)
    event.kind == KeyRelease && return false
    page_step > 0 || throw(ArgumentError("scroll page step must be positive"))
    key = event.key.code
    if key == :up
        state.row = _scroll_offset(state.row, -1)
    elseif key == :down
        state.row = _scroll_offset(state.row, 1)
    elseif key == :left
        state.column = _scroll_offset(state.column, -1)
    elseif key == :right
        state.column = _scroll_offset(state.column, 1)
    elseif key == :page_up
        state.row = _scroll_offset(state.row, -page_step)
    elseif key == :page_down
        state.row = _scroll_offset(state.row, page_step)
    elseif key == :home
        state.row = 0
        state.column = 0
    elseif key == :end
        state.row = max(0, widget.content_size.height - 1)
        state.column = max(0, widget.content_size.width - 1)
    else
        return false
    end
    return true
end

function handle!(
    state::ScrollState,
    ::ScrollView,
    event::MouseEvent,
    area::Rect;
    wheel_step::Integer=3,
)
    wheel_step > 0 || throw(ArgumentError("scroll wheel step must be positive"))
    contains(area, event.position) || return false
    event.action == MouseScroll || return false
    if event.button == WheelUpButton
        state.row = _scroll_offset(state.row, -wheel_step)
    elseif event.button == WheelDownButton
        state.row = _scroll_offset(state.row, wheel_step)
    else
        return false
    end
    return true
end

function handle!(
    state::ScrollState,
    widget::Scrollbar,
    event::KeyEvent;
    page_step::Integer=max(1, widget.viewport_length),
)
    event.kind == KeyRelease && return false
    page_step > 0 || throw(ArgumentError("scroll page step must be positive"))
    key = event.key.code
    current = widget.direction == VerticalScrollbar ? state.row : state.column
    updated = if key == :home
        0
    elseif key == :end
        max(0, widget.content_length - widget.viewport_length)
    elseif key == :page_up
        _scroll_offset(current, -page_step)
    elseif key == :page_down
        _scroll_offset(current, page_step)
    elseif (widget.direction == VerticalScrollbar && key == :up) ||
            (widget.direction == HorizontalScrollbar && key == :left)
        _scroll_offset(current, -1)
    elseif (widget.direction == VerticalScrollbar && key == :down) ||
            (widget.direction == HorizontalScrollbar && key == :right)
        _scroll_offset(current, 1)
    else
        return false
    end
    maximum = max(0, widget.content_length - widget.viewport_length)
    updated = clamp(updated, 0, maximum)
    widget.direction == VerticalScrollbar ? (state.row = updated) : (state.column = updated)
    return true
end

function handle!(
    state::ScrollState,
    widget::Scrollbar,
    event::MouseEvent,
    area::Rect;
    wheel_step::Integer=3,
)
    wheel_step > 0 || throw(ArgumentError("scroll wheel step must be positive"))
    contains(area, event.position) || return false
    maximum = max(0, widget.content_length - widget.viewport_length)
    current = widget.direction == VerticalScrollbar ? state.row : state.column
    updated = if event.action == MouseScroll && event.button == WheelUpButton
        _scroll_offset(current, -wheel_step)
    elseif event.action == MouseScroll && event.button == WheelDownButton
        _scroll_offset(current, wheel_step)
    elseif event.action == MouseRelease && event.button == LeftMouseButton
        track_length = widget.direction == VerticalScrollbar ? area.height : area.width
        position = widget.direction == VerticalScrollbar ?
            event.position.row - area.row : event.position.column - area.column
        track_length <= 1 ? 0 : round(Int, maximum * position / (track_length - 1))
    else
        return false
    end
    updated = clamp(updated, 0, maximum)
    widget.direction == VerticalScrollbar ? (state.row = updated) : (state.column = updated)
    return true
end
