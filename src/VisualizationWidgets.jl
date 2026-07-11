"""Stable immediate-mode plot, timeline, and meter widgets composed from Wicked primitives."""

struct Plot
    chart::Chart
    width::Int
    height::Int
end

function Plot(
    datasets;
    x_bounds=(0.0, 1.0),
    y_bounds=(0.0, 1.0),
    width::Integer=80,
    height::Integer=24,
    block::Union{Nothing,Block}=nothing,
)
    width > 0 || throw(ArgumentError("plot width must be positive"))
    height >= 0 || throw(ArgumentError("plot height cannot be negative"))
    resolved = ChartDataset[dataset isa ChartDataset ? dataset : ChartDataset(dataset) for dataset in datasets]
    return Plot(Chart(resolved; x_bounds, y_bounds, block), Int(width), Int(height))
end

function Plot(
    points::AbstractVector{<:Tuple};
    style::Style=Style(),
    connect::Bool=true,
    kwargs...,
)
    return Plot(ChartDataset[ChartDataset(points; style, connect)]; kwargs...)
end

function Plot(
    f::Function;
    x_bounds=(0.0, 1.0),
    y_bounds=(0.0, 1.0),
    samples::Integer=160,
    style::Style=Style(),
    connect::Bool=true,
    kwargs...,
)
    samples >= 2 || throw(ArgumentError("plot sample count must be at least two"))
    lower, upper = Float64(x_bounds[1]), Float64(x_bounds[2])
    upper > lower || throw(ArgumentError("plot x bounds must increase"))
    points = Tuple{Float64,Float64}[
        (x, Float64(f(x))) for x in range(lower, upper; length=Int(samples))
    ]
    return Plot(ChartDataset[ChartDataset(points; style, connect)]; x_bounds=(lower, upper), y_bounds, kwargs...)
end

measure(widget::Plot, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))
render!(buffer::Buffer, widget::Plot, area::Rect) = render!(buffer, widget.chart, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))

function SemanticToolkit.widget_semantic_descriptor(widget::Plot, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Plot",
        metadata=Dict(:width => widget.width, :height => widget.height),
    )
end

struct Meter
    value::Float64
    minimum::Float64
    maximum::Float64
    orientation::Symbol
    label::Union{Nothing,String}
    filled_style::Style
    empty_style::Style
    width::Int
    height::Int
end

function Meter(
    value::Real;
    minimum::Real=0,
    maximum::Real=1,
    orientation::Symbol=:horizontal,
    label::Union{Nothing,AbstractString}=nothing,
    filled_style::Style=Style(foreground=AnsiColor(6)),
    empty_style::Style=Style(modifiers=DIM),
    width::Integer=20,
    height::Integer=8,
)
    maximum > minimum || throw(ArgumentError("meter maximum must exceed minimum"))
    orientation in (:horizontal, :vertical) || throw(ArgumentError("meter orientation must be :horizontal or :vertical"))
    width > 0 || throw(ArgumentError("meter width must be positive"))
    height >= 0 || throw(ArgumentError("meter height cannot be negative"))
    return Meter(Float64(value), Float64(minimum), Float64(maximum), orientation,
        label === nothing ? nothing : String(label), filled_style, empty_style, Int(width), Int(height))
end

meter_ratio(widget::Meter) = clamp((widget.value - widget.minimum) / (widget.maximum - widget.minimum), 0.0, 1.0)
measure(widget::Meter, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::Meter, area::Rect)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return buffer
    ratio = meter_ratio(widget)
    if widget.orientation == :horizontal
        render!(buffer, LineGauge(ratio; filled_style=widget.filled_style, empty_style=widget.empty_style), active)
    else
        filled = clamp(round(Int, active.height * ratio), 0, active.height)
        for row in active.row:(active.row + active.height - 1), column in active.column:(active.column + active.width - 1)
            style = row >= active.row + active.height - filled ? widget.filled_style : widget.empty_style
            buffer[row, column] = Cell(" "; style)
        end
    end
    widget.label === nothing || render!(buffer, Label(widget.label; alignment=CenterAlign), Rect(active.row + div(active.height - 1, 2), active.column, 1, active.width))
    return buffer
end

function SemanticToolkit.widget_semantic_descriptor(widget::Meter, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ProgressRole;
        label=something(widget.label, "Meter"),
        state=Accessibility.SemanticState(
            value_now=widget.value,
            value_min=widget.minimum,
            value_max=widget.maximum,
        ),
        metadata=Dict(:orientation => widget.orientation, :ratio => meter_ratio(widget)),
    )
end

struct Timeline{T}
    items::Vector{TimelineItem{T}}
    width::Int
    height::Int
    wrap::Bool
end

function Timeline(items::AbstractVector{TimelineItem{T}}; width::Integer=80, height::Integer=24, wrap::Bool=false) where {T}
    width > 0 || throw(ArgumentError("timeline width must be positive"))
    height >= 0 || throw(ArgumentError("timeline height cannot be negative"))
    return Timeline{T}(Vector{TimelineItem{T}}(items), Int(width), Int(height), wrap)
end

"""Timeline focus state plus an explicit scroll offset for clipped terminal regions."""
mutable struct TimelineWidgetState{T}
    timeline::TimelineState{T}
    offset::Int
end

TimelineWidgetState(items::AbstractVector{TimelineItem{T}}) where {T} = TimelineWidgetState{T}(TimelineState(items), 0)
state_for(widget::Timeline) = TimelineWidgetState(widget.items)
timeline_value(state::TimelineWidgetState) = state.timeline.focused === nothing ? nothing : state.timeline.items[state.timeline.focused].value
measure(widget::Timeline, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function _normalize_timeline!(state::TimelineWidgetState, height::Integer)
    total = length(state.timeline.items)
    viewport = max(0, Int(height))
    state.offset = clamp(state.offset, 0, max(0, total - viewport))
    focused = state.timeline.focused
    focused === nothing && return state
    focused <= state.offset && (state.offset = focused - 1)
    focused > state.offset + viewport && (state.offset = focused - viewport)
    return state
end

function render!(buffer::Buffer, widget::Timeline, area::Rect, state::TimelineWidgetState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return buffer
    _normalize_timeline!(state, active.height)
    lines = render_timeline(state.timeline; width=active.width)
    last_line = min(length(lines), state.offset + active.height)
    visible = state.offset >= last_line ? eltype(lines)[] : lines[(state.offset + 1):last_line]
    return render!(buffer, Paragraph(rich_lines_to_core_text(CoreTextAdapter(), visible)), active)
end
render!(buffer::Buffer, widget::Timeline, area::Rect) = render!(buffer, widget, area, state_for(widget))

function handle!(state::TimelineWidgetState, widget::Timeline, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code in (:up, :left)
        move_timeline_focus!(state.timeline, -1; wrap=widget.wrap)
    elseif event.key.code in (:down, :right)
        move_timeline_focus!(state.timeline, 1; wrap=widget.wrap)
    elseif event.key.code in (:page_up, :pageup)
        move_timeline_focus!(state.timeline, -max(1, widget.height); wrap=widget.wrap)
    elseif event.key.code in (:page_down, :pagedown)
        move_timeline_focus!(state.timeline, max(1, widget.height); wrap=widget.wrap)
    elseif event.key.code == :home
        state.timeline.focused = isempty(state.timeline.items) ? nothing : 1
    elseif event.key.code == :end
        state.timeline.focused = isempty(state.timeline.items) ? nothing : length(state.timeline.items)
    elseif event.key.code in (:enter, :character) && (event.key.code == :enter || event.text == " ")
        state.timeline.focused === nothing && return false
    else
        return false
    end
    _normalize_timeline!(state, widget.height)
    return true
end

function handle!(state::TimelineWidgetState, widget::Timeline, event::MouseEvent, area::Rect)
    active = Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width))
    contains(active, event.position) || return false
    if event.action == MouseScroll
        delta = event.button == WheelUpButton ? -3 : event.button == WheelDownButton ? 3 : 0
        delta == 0 && return false
        state.offset = clamp(state.offset + delta, 0, max(0, length(state.timeline.items) - active.height))
        return true
    end
    event.action == MousePress && event.button == LeftMouseButton || return false
    index = state.offset + event.position.row - active.row + 1
    1 <= index <= length(state.timeline.items) || return false
    state.timeline.focused = index
    return true
end

timeline_widget_semantic_tree(widget::Timeline, state::TimelineWidgetState; id="timeline", label="Timeline") =
    timeline_semantic_tree(state.timeline; id, label)

function SemanticToolkit.widget_semantic_descriptor(widget::Timeline, state::TimelineWidgetState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Timeline",
        state=Accessibility.SemanticState(focusable=true),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:item_count => length(widget.items), :focused_index => state.timeline.focused),
    )
end

function SemanticToolkit.widget_semantic_children(widget::Timeline, state::TimelineWidgetState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(index)",
            Accessibility.ListItemRole;
            label=item.title,
            description=item.detail,
            state=Accessibility.SemanticState(
                selected=state.timeline.focused == index,
                value=string(item.status),
            ),
            actions=[Accessibility.ActivateSemanticAction],
        ) for (index, item) in enumerate(widget.items)
    ]
end
