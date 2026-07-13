function _visual_area(buffer::Buffer, block::Union{Nothing,Block}, area::Rect)
    if isnothing(block)
        intersection(buffer.area, area)
    else
        render!(buffer, block, area)
        intersection(buffer.area, inner(block, area))
    end
end

"""A horizontal progress gauge with a centered label."""
struct Gauge
    ratio::Float64
    label::String
    block::Union{Nothing,Block}
    empty_style::Style
    filled_style::Style
end

function Gauge(
    ratio::Real;
    label::Union{Nothing,AbstractString}=nothing,
    block::Union{Nothing,Block}=nothing,
    empty_style::Style=Style(modifiers=DIM),
    filled_style::Style=Style(modifiers=REVERSED),
)
    0 <= ratio <= 1 || throw(ArgumentError("gauge ratio must be between 0 and 1"))
    resolved_label = isnothing(label) ? string(round(Int, ratio * 100), "%") : String(label)
    Gauge(Float64(ratio), resolved_label, block, empty_style, filled_style)
end

function render!(buffer::Buffer, widget::Gauge, area::Rect)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    filled = clamp(round(Int, active.width * widget.ratio), 0, active.width)
    for row in active.row:(active.row + active.height - 1)
        for offset in 0:(active.width - 1)
            style = offset < filled ? widget.filled_style : widget.empty_style
            buffer[row, active.column + offset] = Cell(" "; style)
        end
    end
    label_row = active.row + div(active.height - 1, 2)
    render!(
        buffer,
        Label(widget.label; alignment=CenterAlign),
        Rect(label_row, active.column, 1, active.width),
    )
    buffer
end

"""A compact one-line progress gauge."""
struct LineGauge
    ratio::Float64
    filled_symbol::String
    empty_symbol::String
    filled_style::Style
    empty_style::Style
end

function LineGauge(
    ratio::Real;
    filled_symbol::AbstractString="━",
    empty_symbol::AbstractString="─",
    filled_style::Style=Style(foreground=AnsiColor(6)),
    empty_style::Style=Style(modifiers=DIM),
)
    0 <= ratio <= 1 || throw(ArgumentError("line gauge ratio must be between 0 and 1"))
    LineGauge(
        Float64(ratio),
        String(filled_symbol),
        String(empty_symbol),
        filled_style,
        empty_style,
    )
end

function render!(buffer::Buffer, widget::LineGauge, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    filled = clamp(round(Int, active.width * widget.ratio), 0, active.width)
    row = active.row + div(active.height - 1, 2)
    for offset in 0:(active.width - 1)
        symbol = offset < filled ? widget.filled_symbol : widget.empty_symbol
        style = offset < filled ? widget.filled_style : widget.empty_style
        grapheme_width(DEFAULT_WIDTH_POLICY, symbol) == 1 &&
            (buffer[row, active.column + offset] = Cell(symbol; style))
    end
    buffer
end

const _SPARK_SYMBOLS = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

"""A compact series rendered with Unicode height symbols."""
struct Sparkline
    values::Vector{Float64}
    minimum::Union{Nothing,Float64}
    maximum::Union{Nothing,Float64}
    style::Style
end

function Sparkline(
    values::AbstractVector{<:Real};
    minimum::Union{Nothing,Real}=nothing,
    maximum::Union{Nothing,Real}=nothing,
    style::Style=Style(),
)
    !isnothing(minimum) && !isnothing(maximum) && maximum < minimum &&
        throw(ArgumentError("sparkline maximum must not be smaller than minimum"))
    Sparkline(
        Float64.(values),
        isnothing(minimum) ? nothing : Float64(minimum),
        isnothing(maximum) ? nothing : Float64(maximum),
        style,
    )
end

function render!(buffer::Buffer, widget::Sparkline, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    isempty(widget.values) && return buffer
    values = length(widget.values) > active.width ? widget.values[(end - active.width + 1):end] : widget.values
    minimum = something(widget.minimum, Base.minimum(values))
    maximum = something(widget.maximum, Base.maximum(values))
    span = maximum - minimum
    row = active.row + div(active.height - 1, 2)
    for (offset, value) in enumerate(values)
        level = span == 0 ? length(_SPARK_SYMBOLS) :
                clamp(floor(Int, (value - minimum) / span * (length(_SPARK_SYMBOLS) - 1)) + 1, 1, length(_SPARK_SYMBOLS))
        buffer[row, active.column + offset - 1] = Cell(_SPARK_SYMBOLS[level]; style=widget.style)
    end
    buffer
end

struct Bar
    label::String
    value::Float64
    style::Style
end

Bar(label::AbstractString, value::Real; style::Style=Style(foreground=AnsiColor(6))) =
    Bar(String(label), Float64(value), style)

"""A vertical categorical bar chart."""
struct BarChart
    bars::Vector{Bar}
    maximum::Union{Nothing,Float64}
    bar_width::Int
    gap::Int
    block::Union{Nothing,Block}
end

function BarChart(
    bars;
    maximum::Union{Nothing,Real}=nothing,
    bar_width::Integer=1,
    gap::Integer=1,
    block::Union{Nothing,Block}=nothing,
)
    bar_width > 0 || throw(ArgumentError("bar width must be positive"))
    gap >= 0 || throw(ArgumentError("bar gap must be non-negative"))
    resolved = Bar[
        bar isa Bar ? bar : Bar(string(first(bar)), last(bar))
        for bar in bars
    ]
    BarChart(
        resolved,
        isnothing(maximum) ? nothing : Float64(maximum),
        Int(bar_width),
        Int(gap),
        block,
    )
end

function render!(buffer::Buffer, widget::BarChart, area::Rect)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    isempty(widget.bars) && return buffer
    label_height = active.height >= 2 ? 1 : 0
    chart_height = active.height - label_height
    maximum = something(widget.maximum, max(0.0, Base.maximum(bar.value for bar in widget.bars)))
    stride = widget.bar_width + widget.gap
    visible = min(length(widget.bars), div(active.width + widget.gap, stride))
    for index in 1:visible
        bar = widget.bars[index]
        height = maximum <= 0 ? 0 : clamp(round(Int, chart_height * max(0, bar.value) / maximum), 0, chart_height)
        column = active.column + (index - 1) * stride
        for x in 0:(widget.bar_width - 1), y in 0:(height - 1)
            buffer[active.row + chart_height - y - 1, column + x] = Cell("█"; style=bar.style)
        end
        if label_height == 1
            label_area = Rect(active.row + chart_height, column, 1, min(widget.bar_width, active.column + active.width - column))
            render!(buffer, Label(bar.label; alignment=CenterAlign), label_area)
        end
    end
    buffer
end

"""Logical braille-pixel drawing context for a terminal cell region."""
mutable struct CanvasContext
    dots::Matrix{UInt8}
    x_bounds::Tuple{Float64,Float64}
    y_bounds::Tuple{Float64,Float64}
    style::Style
end

function CanvasContext(
    height::Integer,
    width::Integer,
    x_bounds,
    y_bounds,
    style::Style,
)
    height >= 0 && width >= 0 || throw(ArgumentError("canvas dimensions must be non-negative"))
    x_bounds[2] > x_bounds[1] || throw(ArgumentError("canvas x bounds must increase"))
    y_bounds[2] > y_bounds[1] || throw(ArgumentError("canvas y bounds must increase"))
    CanvasContext(
        zeros(UInt8, Int(height), Int(width)),
        (Float64(x_bounds[1]), Float64(x_bounds[2])),
        (Float64(y_bounds[1]), Float64(y_bounds[2])),
        style,
    )
end

function _logical_point(context::CanvasContext, x::Real, y::Real)
    logical_width = size(context.dots, 2) * 2
    logical_height = size(context.dots, 1) * 4
    (logical_width == 0 || logical_height == 0) && return nothing
    normalized_x = (Float64(x) - context.x_bounds[1]) / (context.x_bounds[2] - context.x_bounds[1])
    normalized_y = (Float64(y) - context.y_bounds[1]) / (context.y_bounds[2] - context.y_bounds[1])
    (0 <= normalized_x <= 1 && 0 <= normalized_y <= 1) || return nothing
    pixel_x = clamp(round(Int, normalized_x * (logical_width - 1)), 0, logical_width - 1)
    pixel_y = clamp(round(Int, (1 - normalized_y) * (logical_height - 1)), 0, logical_height - 1)
    pixel_x, pixel_y
end

function _dot_mask(pixel_x::Int, pixel_y::Int)
    local_x = mod(pixel_x, 2)
    local_y = mod(pixel_y, 4)
    dot = if local_x == 0
        local_y == 0 ? 1 : local_y == 1 ? 2 : local_y == 2 ? 3 : 7
    else
        local_y == 0 ? 4 : local_y == 1 ? 5 : local_y == 2 ? 6 : 8
    end
    UInt8(1 << (dot - 1))
end

"""Set one data-space point in a braille canvas."""
function canvas_point!(context::CanvasContext, x::Real, y::Real)
    point = _logical_point(context, x, y)
    isnothing(point) && return false
    pixel_x, pixel_y = point
    row = div(pixel_y, 4) + 1
    column = div(pixel_x, 2) + 1
    context.dots[row, column] |= _dot_mask(pixel_x, pixel_y)
    true
end

"""Draw a data-space line with Bresenham rasterization."""
function canvas_line!(context::CanvasContext, x1::Real, y1::Real, x2::Real, y2::Real)
    first_point = _logical_point(context, x1, y1)
    last_point = _logical_point(context, x2, y2)
    (isnothing(first_point) || isnothing(last_point)) && return false
    x, y = first_point
    target_x, target_y = last_point
    delta_x = abs(target_x - x)
    step_x = x < target_x ? 1 : -1
    delta_y = -abs(target_y - y)
    step_y = y < target_y ? 1 : -1
    error = delta_x + delta_y
    while true
        row = div(y, 4) + 1
        column = div(x, 2) + 1
        context.dots[row, column] |= _dot_mask(x, y)
        x == target_x && y == target_y && break
        doubled = 2 * error
        if doubled >= delta_y
            error += delta_y
            x += step_x
        end
        if doubled <= delta_x
            error += delta_x
            y += step_y
        end
    end
    true
end

"""A callback-rendered braille canvas."""
struct Canvas{F}
    draw::F
    x_bounds::Tuple{Float64,Float64}
    y_bounds::Tuple{Float64,Float64}
    style::Style
    block::Union{Nothing,Block}
end

function Canvas(
    draw::F;
    x_bounds=(0.0, 1.0),
    y_bounds=(0.0, 1.0),
    style::Style=Style(),
    block::Union{Nothing,Block}=nothing,
) where {F}
    Canvas{F}(
        draw,
        (Float64(x_bounds[1]), Float64(x_bounds[2])),
        (Float64(y_bounds[1]), Float64(y_bounds[2])),
        style,
        block,
    )
end

function render!(buffer::Buffer, widget::Canvas, area::Rect)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    context = CanvasContext(active.height, active.width, widget.x_bounds, widget.y_bounds, widget.style)
    widget.draw(context)
    for row in 1:active.height, column in 1:active.width
        mask = context.dots[row, column]
        mask == 0 && continue
        symbol = string(Char(0x2800 + mask))
        buffer[active.row + row - 1, active.column + column - 1] = Cell(symbol; style=widget.style)
    end
    buffer
end

struct ChartDataset
    points::Vector{Tuple{Float64,Float64}}
    style::Style
    connect::Bool
end

ChartDataset(points; style::Style=Style(), connect::Bool=true) =
    ChartDataset([(Float64(point[1]), Float64(point[2])) for point in points], style, connect)

"""A multi-series line or point chart on a braille canvas."""
struct Chart
    datasets::Vector{ChartDataset}
    x_bounds::Tuple{Float64,Float64}
    y_bounds::Tuple{Float64,Float64}
    block::Union{Nothing,Block}
end

function Chart(datasets; x_bounds=(0.0, 1.0), y_bounds=(0.0, 1.0), block=nothing)
    Chart(
        ChartDataset[datasets...],
        (Float64(x_bounds[1]), Float64(x_bounds[2])),
        (Float64(y_bounds[1]), Float64(y_bounds[2])),
        block,
    )
end

function render!(buffer::Buffer, widget::Chart, area::Rect)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    for dataset in widget.datasets
        canvas = Canvas(
            context -> begin
                for point in dataset.points
                    canvas_point!(context, point...)
                end
                if dataset.connect
                    for index in 2:length(dataset.points)
                        canvas_line!(context, dataset.points[index - 1]..., dataset.points[index]...)
                    end
                end
            end;
            x_bounds=widget.x_bounds,
            y_bounds=widget.y_bounds,
            style=dataset.style,
        )
        render!(buffer, canvas, active)
    end
    buffer
end

"""A binned numeric distribution rendered as a bar chart."""
struct Histogram
    values::Vector{Float64}
    bins::Int
    style::Style
    block::Union{Nothing,Block}
end

function Histogram(values; bins::Integer=10, style::Style=Style(), block=nothing)
    bins > 0 || throw(ArgumentError("histogram bin count must be positive"))
    Histogram(Float64.(values), Int(bins), style, block)
end

function render!(buffer::Buffer, widget::Histogram, area::Rect)
    isempty(widget.values) && return buffer
    low, high = extrema(widget.values)
    counts = zeros(Int, widget.bins)
    for value in widget.values
        index = low == high ? 1 : clamp(floor(Int, (value - low) / (high - low) * widget.bins) + 1, 1, widget.bins)
        counts[index] += 1
    end
    bars = [Bar(string(index), count; style=widget.style) for (index, count) in enumerate(counts)]
    render!(buffer, BarChart(bars; bar_width=1, gap=0, block=widget.block), area)
end

const _HEAT_SYMBOLS = [" ", "░", "▒", "▓", "█"]

"""A matrix heatmap with configurable numeric bounds."""
struct Heatmap
    values::Matrix{Float64}
    minimum::Union{Nothing,Float64}
    maximum::Union{Nothing,Float64}
    style::Style
end

Heatmap(values::AbstractMatrix{<:Real}; minimum=nothing, maximum=nothing, style::Style=Style()) =
    Heatmap(
        Float64.(values),
        isnothing(minimum) ? nothing : Float64(minimum),
        isnothing(maximum) ? nothing : Float64(maximum),
        style,
    )

function render!(buffer::Buffer, widget::Heatmap, area::Rect)
    active = intersection(buffer.area, area)
    (isempty(active) || isempty(widget.values)) && return buffer
    minimum = something(widget.minimum, Base.minimum(widget.values))
    maximum = something(widget.maximum, Base.maximum(widget.values))
    span = maximum - minimum
    rows = min(active.height, size(widget.values, 1))
    columns = min(active.width, size(widget.values, 2))
    for row in 1:rows, column in 1:columns
        value = widget.values[row, column]
        level = span == 0 ? length(_HEAT_SYMBOLS) :
                clamp(floor(Int, (value - minimum) / span * (length(_HEAT_SYMBOLS) - 1)) + 1, 1, length(_HEAT_SYMBOLS))
        buffer[active.row + row - 1, active.column + column - 1] =
            Cell(_HEAT_SYMBOLS[level]; style=widget.style)
    end
    buffer
end

"""A month calendar with optional selected and marked dates."""
struct Calendar
    year::Int
    month::Int
    selected::Union{Nothing,Date}
    marked::Set{Date}
    style::Style
    selected_style::Style
    marked_style::Style
    header_style::Style
    block::Union{Nothing,Block}
end

function Calendar(
    year::Integer,
    month::Integer;
    selected::Union{Nothing,Date}=nothing,
    marked=Date[],
    style::Style=Style(),
    selected_style::Style=Style(modifiers=REVERSED),
    marked_style::Style=Style(modifiers=BOLD),
    header_style::Style=Style(modifiers=BOLD),
    block::Union{Nothing,Block}=nothing,
)
    1 <= month <= 12 || throw(ArgumentError("calendar month must be between 1 and 12"))
    Calendar(
        Int(year),
        Int(month),
        selected,
        Set{Date}(marked),
        style,
        selected_style,
        marked_style,
        header_style,
        block,
    )
end

mutable struct CalendarState
    selected::Date
    visible_year::Int
    visible_month::Int
    focused::Bool
    activated::Union{Nothing,Date}
end

function CalendarState(
    selected::Date;
    visible_year::Integer=year(selected),
    visible_month::Integer=month(selected),
    focused::Bool=false,
    activated::Union{Nothing,Date}=nothing,
)
    1 <= visible_month <= 12 || throw(ArgumentError("visible calendar month must be between 1 and 12"))
    CalendarState(selected, Int(visible_year), Int(visible_month), focused, activated)
end

CalendarState(year::Integer, month::Integer, day::Integer=1; focused::Bool=false) =
    CalendarState(Date(year, month, day); focused)

CalendarState(widget::Calendar; focused::Bool=false) =
    CalendarState(something(widget.selected, Date(widget.year, widget.month, 1)); visible_year=widget.year, visible_month=widget.month, focused)

state_for(widget::Calendar) = CalendarState(widget)

function _calendar_selected_style(widget::Calendar, state::CalendarState, date::Date, fallback::Style)
    date == state.selected && return widget.selected_style
    date in widget.marked && return widget.marked_style
    fallback
end

function _render_calendar!(
    buffer::Buffer,
    widget::Calendar,
    area::Rect,
    year_value::Int,
    month_value::Int,
    selected::Union{Nothing,Date},
)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    active.height >= 1 && render!(
        buffer,
        Label(monthname(month_value) * " " * string(year_value); style=widget.header_style, alignment=CenterAlign),
        Rect(active.row, active.column, 1, active.width),
    )
    active.height >= 2 && draw_text!(
        buffer,
        active.row + 1,
        active.column,
        "Mo Tu We Th Fr Sa Su";
        style=widget.header_style,
        clip=active,
    )
    first_date = Date(year_value, month_value, 1)
    days = daysinmonth(first_date)
    starting_column = dayofweek(first_date) - 1
    for day in 1:days
        index = starting_column + day - 1
        row = active.row + 2 + div(index, 7)
        row >= active.row + active.height && break
        column = active.column + 3 * mod(index, 7)
        column + 1 >= active.column + active.width && continue
        date = Date(year_value, month_value, day)
        style = date == selected ? widget.selected_style :
                date in widget.marked ? widget.marked_style : widget.style
        draw_text!(buffer, row, column, lpad(string(day), 2); style, clip=active)
    end
    buffer
end

function render!(buffer::Buffer, widget::Calendar, area::Rect)
    _render_calendar!(buffer, widget, area, widget.year, widget.month, widget.selected)
end

function render!(buffer::Buffer, widget::Calendar, area::Rect, state::CalendarState)
    _render_calendar!(buffer, widget, area, state.visible_year, state.visible_month, state.selected)
end

function _set_calendar_date!(state::CalendarState, date::Date)
    state.selected = date
    state.visible_year = year(date)
    state.visible_month = month(date)
    state.focused = true
    state
end

function _shift_calendar_month(date::Date, delta::Integer)
    first_target = Date(year(date), month(date), 1) + Month(Int(delta))
    Date(year(first_target), month(first_target), min(day(date), daysinmonth(first_target)))
end

function _calendar_date_at(widget::Calendar, state::CalendarState, area::Rect, position::Position)
    active = isnothing(widget.block) ? area : inner(widget.block, area)
    contains(active, position) || return nothing
    day_row = position.row - active.row - 2
    day_row >= 0 || return nothing
    day_column = div(position.column - active.column, 3)
    0 <= day_column <= 6 || return nothing
    first_date = Date(state.visible_year, state.visible_month, 1)
    day_value = day_row * 7 + day_column - (dayofweek(first_date) - 1) + 1
    1 <= day_value <= daysinmonth(first_date) || return nothing
    Date(state.visible_year, state.visible_month, day_value)
end

function handle!(state::CalendarState, widget::Calendar, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    code = event.key.code
    if code == :left
        _set_calendar_date!(state, state.selected - Day(1))
    elseif code == :right
        _set_calendar_date!(state, state.selected + Day(1))
    elseif code == :up
        _set_calendar_date!(state, state.selected - Day(7))
    elseif code == :down
        _set_calendar_date!(state, state.selected + Day(7))
    elseif code == :home
        _set_calendar_date!(state, Date(state.visible_year, state.visible_month, 1))
    elseif code == :end
        first_date = Date(state.visible_year, state.visible_month, 1)
        _set_calendar_date!(state, Date(state.visible_year, state.visible_month, daysinmonth(first_date)))
    elseif code == :pageup
        _set_calendar_date!(state, _shift_calendar_month(state.selected, -1))
    elseif code == :pagedown
        _set_calendar_date!(state, _shift_calendar_month(state.selected, 1))
    elseif code == :enter || code == :space
        state.focused = true
        state.activated = state.selected
    else
        return false
    end
    true
end

function handle!(state::CalendarState, widget::Calendar, event::MouseEvent, area::Rect)
    if event.action == MouseScroll
        if event.button == WheelUpButton
            _set_calendar_date!(state, _shift_calendar_month(state.selected, -1))
            return true
        elseif event.button == WheelDownButton
            _set_calendar_date!(state, _shift_calendar_month(state.selected, 1))
            return true
        end
        return false
    end
    event.button == LeftMouseButton || return false
    event.action in (MousePress, MouseRelease) || return false
    date = _calendar_date_at(widget, state, area, event.position)
    date === nothing && return false
    _set_calendar_date!(state, date)
    event.action == MouseRelease && (state.activated = date)
    true
end

activate(::Calendar, state::CalendarState) = state.activated

mutable struct SpinnerState
    frame::Int
end

SpinnerState(frame::Integer=1) = frame >= 1 ? SpinnerState(Int(frame)) :
    throw(ArgumentError("spinner frame must be positive"))

"""An animated symbol advanced by `TickEvent`."""
struct Spinner
    frames::Vector{String}
    label::String
    style::Style
end

state_for(::Spinner) = SpinnerState()

function Spinner(;
    frames=["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
    label::AbstractString="",
    style::Style=Style(),
)
    isempty(frames) && throw(ArgumentError("spinner requires at least one frame"))
    Spinner(String[String(frame) for frame in frames], String(label), style)
end

function render!(buffer::Buffer, widget::Spinner, area::Rect, state::SpinnerState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    state.frame = mod1(state.frame, length(widget.frames))
    draw_text!(
        buffer,
        active.row,
        active.column,
        widget.frames[state.frame] * (isempty(widget.label) ? "" : " " * widget.label);
        style=widget.style,
        clip=active,
    )
    buffer
end

render!(buffer::Buffer, widget::Spinner, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::SpinnerState, widget::Spinner, ::TickEvent)
    state.frame = mod1(state.frame + 1, length(widget.frames))
    true
end
