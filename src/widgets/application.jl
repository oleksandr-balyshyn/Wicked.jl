struct Header
    title::String
    subtitle::String
    style::Style
    subtitle_style::Style
end

Header(
    title::AbstractString;
    subtitle::AbstractString="",
    style::Style=Style(modifiers=BOLD),
    subtitle_style::Style=Style(modifiers=DIM),
) = Header(String(title), String(subtitle), style, subtitle_style)

function render!(buffer::Buffer, widget::Header, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    render!(buffer, Label(widget.title; style=widget.style, alignment=CenterAlign), Rect(active.row, active.column, 1, active.width))
    active.height > 1 && !isempty(widget.subtitle) &&
        render!(buffer, Label(widget.subtitle; style=widget.subtitle_style, alignment=CenterAlign), Rect(active.row + 1, active.column, 1, active.width))
    buffer
end

struct KeyHint
    key::String
    description::String

    KeyHint(key, description) = new(string(key), string(description))
end

struct Footer
    hints::Vector{KeyHint}
    separator::String
    key_style::Style
    description_style::Style
end

function Footer(
    hints;
    separator::AbstractString="  ",
    key_style::Style=Style(modifiers=REVERSED),
    description_style::Style=Style(),
)
    Footer(KeyHint[hint isa KeyHint ? hint : KeyHint(first(hint), last(hint)) for hint in hints], String(separator), key_style, description_style)
end

function render!(buffer::Buffer, widget::Footer, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    spans = Span[]
    for (index, hint) in enumerate(widget.hints)
        index > 1 && push!(spans, Span(widget.separator; style=widget.description_style))
        push!(spans, Span(" " * hint.key * " "; style=widget.key_style))
        push!(spans, Span(" " * hint.description; style=widget.description_style))
    end
    draw_line!(buffer, active.row, active, Line(spans))
    buffer
end

struct Badge
    text::String
    style::Style
end

Badge(text; style::Style=Style(modifiers=REVERSED)) = Badge(string(text), style)
render!(buffer::Buffer, widget::Badge, area::Rect) =
    render!(buffer, Label(" " * widget.text * " "; style=widget.style, alignment=CenterAlign), area)

struct Alert
    message::Text
    severity::Symbol
    block::Block
end

function Alert(
    message::AbstractString;
    title::AbstractString="Alert",
    severity::Symbol=:info,
)
    severity in (:info, :success, :warning, :error) ||
        throw(ArgumentError("alert severity must be info, success, warning, or error"))
    color = severity == :error ? AnsiColor(1) :
            severity == :warning ? AnsiColor(3) :
            severity == :success ? AnsiColor(2) : AnsiColor(4)
    style = Style(foreground=color)
    Alert(Text(message; style), severity, Block(title=title, border_style=style, title_style=style, padding=Margin(0, 1)))
end

function render!(buffer::Buffer, widget::Alert, area::Rect)
    render!(buffer, widget.block, area)
    render!(buffer, Paragraph(widget.message), inner(widget.block, area))
end

struct Notification
    id::Any
    title::String
    message::String
    severity::Symbol
    created_ns::UInt64
    timeout_ns::Union{Nothing,UInt64}
end

function Notification(
    message::AbstractString;
    id=gensym(:notification),
    title::AbstractString="",
    severity::Symbol=:info,
    timeout::Union{Nothing,Real}=5.0,
    created_ns::Integer=time_ns(),
)
    severity in (:info, :success, :warning, :error) ||
        throw(ArgumentError("notification severity must be info, success, warning, or error"))
    !isnothing(timeout) && timeout < 0 &&
        throw(ArgumentError("notification timeout must be non-negative"))
    timeout_ns = isnothing(timeout) ? nothing : round(UInt64, timeout * 1_000_000_000)
    Notification(id, String(title), String(message), severity, UInt64(created_ns), timeout_ns)
end

mutable struct NotificationCenter
    notifications::Vector{Notification}
    maximum::Int

    function NotificationCenter(maximum::Integer=5)
        maximum > 0 || throw(ArgumentError("notification maximum must be positive"))
        new(Notification[], Int(maximum))
    end
end

function push_notification!(center::NotificationCenter, notification::Notification)
    existing = findfirst(item -> item.id == notification.id, center.notifications)
    isnothing(existing) ? push!(center.notifications, notification) :
        (center.notifications[existing] = notification)
    while length(center.notifications) > center.maximum
        popfirst!(center.notifications)
    end
    center
end

function dismiss_notification!(center::NotificationCenter, id)
    index = findfirst(item -> item.id == id, center.notifications)
    isnothing(index) && return false
    deleteat!(center.notifications, index)
    true
end

function expire_notifications!(center::NotificationCenter, now_ns::Integer=time_ns())
    previous = length(center.notifications)
    filter!(center.notifications) do notification
        isnothing(notification.timeout_ns) ||
            UInt64(now_ns) - notification.created_ns < notification.timeout_ns
    end
    previous - length(center.notifications)
end

struct NotificationView
    center::NotificationCenter
end

function render!(buffer::Buffer, widget::NotificationView, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    visible = min(active.height, length(widget.center.notifications))
    start = length(widget.center.notifications) - visible + 1
    for (offset, index) in enumerate(start:length(widget.center.notifications))
        notification = widget.center.notifications[index]
        color = notification.severity == :error ? AnsiColor(1) :
                notification.severity == :warning ? AnsiColor(3) :
                notification.severity == :success ? AnsiColor(2) : AnsiColor(4)
        prefix = isempty(notification.title) ? "" : notification.title * ": "
        render!(buffer, Label(prefix * notification.message; style=Style(foreground=color)), Rect(active.row + offset - 1, active.column, 1, active.width))
    end
    buffer
end

struct CommandItem
    id::Any
    title::String
    description::String
    action::Any
    keywords::Vector{String}
    disabled::Bool
end

function CommandItem(
    id,
    title::AbstractString,
    action=id;
    description::AbstractString="",
    keywords=String[],
    disabled::Bool=false,
)
    CommandItem(id, String(title), String(description), action, lowercase.(String.(keywords)), disabled)
end

mutable struct CommandPaletteState
    query::TextInputState
    selected::Union{Nothing,Int}
    filtered::Vector{Int}
    open::Bool
end

CommandPaletteState(; open::Bool=false) =
    CommandPaletteState(TextInputState(; focused=open), nothing, Int[], open)

struct CommandPalette
    commands::Vector{CommandItem}
    block::Block
    input::TextInput
    highlight_style::Style
end

function CommandPalette(
    commands;
    title::AbstractString="Command Palette",
    highlight_style::Style=Style(modifiers=REVERSED),
)
    CommandPalette(
        CommandItem[commands...],
        Block(title=title, padding=Margin(0, 1)),
        TextInput(placeholder="Type a command..."),
        highlight_style,
    )
end

function _command_score(command::CommandItem, query::String)
    isempty(query) && return 1
    title = lowercase(command.title)
    startswith(title, query) && return 1000 - length(title)
    position = findfirst(query, title)
    !isnothing(position) && return 500 - first(position)
    any(keyword -> occursin(query, keyword), command.keywords) && return 100
    0
end

function _filter_commands!(widget::CommandPalette, state::CommandPaletteState)
    query = lowercase(strip(editing_text(state.query.editing)))
    scored = Tuple{Int,Int}[]
    for (index, command) in enumerate(widget.commands)
        command.disabled && continue
        score = _command_score(command, query)
        score > 0 && push!(scored, (score, index))
    end
    sort!(scored; by=first, rev=true)
    state.filtered = last.(scored)
    isempty(state.filtered) ? (state.selected = nothing) :
        (state.selected = clamp(something(state.selected, 1), 1, length(state.filtered)))
    state
end

function render!(buffer::Buffer, widget::CommandPalette, area::Rect, state::CommandPaletteState)
    state.open || return buffer
    render!(buffer, Clear(), area)
    render!(buffer, widget.block, area)
    active = intersection(buffer.area, inner(widget.block, area))
    isempty(active) && return buffer
    _filter_commands!(widget, state)
    render!(buffer, widget.input, Rect(active.row, active.column, 1, active.width), state.query)
    for visible_index in 1:max(0, active.height - 1)
        visible_index > length(state.filtered) && break
        command = widget.commands[state.filtered[visible_index]]
        row = active.row + visible_index
        row_area = Rect(row, active.column, 1, active.width)
        selected = state.selected == visible_index
        selected && _fill_row!(buffer, row, row_area, widget.highlight_style)
        style = selected ? widget.highlight_style : Style()
        description = isempty(command.description) ? "" : " - " * command.description
        render!(buffer, Label(command.title * description; style), row_area)
    end
    buffer
end

function render!(frame::Frame, widget::CommandPalette, area::Rect, state::CommandPaletteState)
    render!(frame.buffer, widget, area, state)
    state.open || return frame.buffer
    active = intersection(frame.buffer.area, inner(widget.block, area))
    !isempty(active) && render!(frame, widget.input, Rect(active.row, active.column, 1, active.width), state.query)
    frame.buffer
end

function handle!(state::CommandPaletteState, widget::CommandPalette, event::KeyEvent)
    if !state.open
        return false
    elseif event.key.code == :escape
        state.open = false
        state.query.focused = false
        return true
    elseif event.key.code == :up && !isempty(state.filtered)
        state.selected = mod1(something(state.selected, 1) - 1, length(state.filtered))
        return true
    elseif event.key.code == :down && !isempty(state.filtered)
        state.selected = mod1(something(state.selected, 0) + 1, length(state.filtered))
        return true
    elseif event.key.code == :enter
        return !isnothing(state.selected)
    end
    changed = handle!(state.query, widget.input, event)
    changed && (state.selected = nothing; _filter_commands!(widget, state))
    changed
end

function handle!(state::CommandPaletteState, widget::CommandPalette, event::PasteEvent)
    changed = handle!(state.query, widget.input, event)
    changed && (state.selected = nothing; _filter_commands!(widget, state))
    changed
end

function activate(widget::CommandPalette, state::CommandPaletteState)
    isnothing(state.selected) && return nothing
    widget.commands[state.filtered[state.selected]].action
end

open_palette!(state::CommandPaletteState) =
    (state.open = true; state.query.focused = true; state)
close_palette!(state::CommandPaletteState) =
    (state.open = false; state.query.focused = false; state)

struct HelpView
    hints::Vector{KeyHint}
    block::Union{Nothing,Block}
    key_style::Style
end

HelpView(hints; block=nothing, key_style::Style=Style(modifiers=REVERSED)) =
    HelpView(KeyHint[hint isa KeyHint ? hint : KeyHint(first(hint), last(hint)) for hint in hints], block, key_style)

function render!(buffer::Buffer, widget::HelpView, area::Rect)
    active = _visual_area(buffer, widget.block, area)
    for (offset, hint) in enumerate(widget.hints)
        offset > active.height && break
        row = active.row + offset - 1
        position = draw_text!(buffer, row, active.column, " " * hint.key * " "; style=widget.key_style, clip=active)
        position.column < active.column + active.width &&
            draw_text!(buffer, row, position.column + 1, hint.description; clip=active)
    end
    buffer
end

struct LogEntry
    timestamp_ns::UInt64
    level::Symbol
    message::String
end

mutable struct LogState
    entries::Vector{LogEntry}
    offset::Int
    maximum::Int

    function LogState(maximum::Integer=1000)
        maximum > 0 || throw(ArgumentError("log maximum must be positive"))
        new(LogEntry[], 0, Int(maximum))
    end
end

function push_log!(state::LogState, message::AbstractString; level::Symbol=:info, timestamp_ns::Integer=time_ns())
    level in (:debug, :info, :warning, :error) ||
        throw(ArgumentError("log level must be debug, info, warning, or error"))
    push!(state.entries, LogEntry(UInt64(timestamp_ns), level, String(message)))
    length(state.entries) > state.maximum && popfirst!(state.entries)
    state
end

clear_log!(state::LogState) = (empty!(state.entries); state.offset = 0; state)

struct LogView
    block::Union{Nothing,Block}
end

LogView(; block=nothing) = LogView(block)

function render!(buffer::Buffer, widget::LogView, area::Rect, state::LogState)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    state.offset = clamp(state.offset, 0, max(0, length(state.entries) - active.height))
    start = max(1, length(state.entries) - active.height - state.offset + 1)
    stop = min(length(state.entries), start + active.height - 1)
    for (offset, index) in enumerate(start:stop)
        entry = state.entries[index]
        color = entry.level == :error ? AnsiColor(1) :
                entry.level == :warning ? AnsiColor(3) :
                entry.level == :debug ? AnsiColor(8) : DefaultColor()
        draw_text!(buffer, active.row + offset - 1, active.column, "[" * uppercase(string(entry.level)) * "] " * entry.message; style=Style(foreground=color), clip=active)
    end
    buffer
end

function handle!(
    state::CommandPaletteState,
    widget::CommandPalette,
    event::MouseEvent,
    area::Rect,
)
    state.open || return false
    active = inner(widget.block, area)
    contains(active, event.position) || return false
    input_area = Rect(active.row, active.column, min(1, active.height), active.width)
    if event.position.row == active.row
        return handle!(state.query, widget.input, event, input_area)
    end
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    visible_index = event.position.row - active.row
    1 <= visible_index <= length(state.filtered) || return false
    command_index = state.filtered[visible_index]
    widget.commands[command_index].disabled && return false
    state.selected = visible_index
    return true
end

function handle!(
    state::LogState,
    ::LogView,
    event::MouseEvent,
    area::Rect;
    wheel_step::Integer=3,
)
    wheel_step > 0 || throw(ArgumentError("log wheel step must be positive"))
    contains(area, event.position) || return false
    event.action == MouseScroll || return false
    delta = event.button == WheelUpButton ? wheel_step :
        event.button == WheelDownButton ? -wheel_step : return false
    maximum = max(0, length(state.entries) - area.height)
    state.offset = clamp(_scroll_offset(state.offset, delta), 0, maximum)
    return true
end

function handle!(state::LogState, ::LogView, event::KeyEvent; viewport_height::Integer=1)
    if event.key.code == :up
        state.offset += 1
    elseif event.key.code == :down
        state.offset = max(0, state.offset - 1)
    elseif event.key.code == :page_up
        state.offset += max(1, Int(viewport_height))
    elseif event.key.code == :page_down
        state.offset = max(0, state.offset - max(1, Int(viewport_height)))
    elseif event.key.code == :end
        state.offset = 0
    else
        return false
    end
    true
end
