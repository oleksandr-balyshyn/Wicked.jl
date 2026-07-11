module Diagnostics

using Dates: DateTime, now

export TraceEvent,
       AbstractTraceSink,
       NullTraceSink,
       RingTraceSink,
       trace!,
       trace_events,
       clear_traces!,
       with_trace_span,
       FrameMetrics,
       MetricsSnapshot,
       record_frame!,
       metrics_snapshot,
       DiagnosticsHub,
       begin_frame!,
       end_frame!,
       record_input!,
       record_command!,
       record_dropped_event!,
       InspectorPanel,
       MetricsPanel,
       TracesPanel,
       TreePanel,
       FocusPanel,
       StylesPanel,
       DeveloperInspector,
       InspectorSnapshot,
       toggle_inspector!,
       next_panel!,
       previous_panel!,
       move_selection!,
       capture_inspector,
       inspector_lines,
       inspector_text

const TraceMetadata = Dict{Symbol,Any}

"""A timestamped diagnostics event emitted by the runtime or an application."""
struct TraceEvent
    sequence::UInt64
    timestamp_ns::UInt64
    category::Symbol
    name::Symbol
    phase::Symbol
    metadata::TraceMetadata
end

abstract type AbstractTraceSink end

"""A zero-allocation sink used when diagnostics are disabled."""
struct NullTraceSink <: AbstractTraceSink end

"""A thread-safe, allocation-bounded trace sink retaining the newest events."""
mutable struct RingTraceSink <: AbstractTraceSink
    slots::Vector{Union{Nothing,TraceEvent}}
    count::Int
    next_index::Int
    next_sequence::UInt64
    mutex::ReentrantLock

    function RingTraceSink(capacity::Integer=2_048)
        capacity > 0 || throw(ArgumentError("trace capacity must be positive"))
        slots = Union{Nothing,TraceEvent}[nothing for _ in 1:Int(capacity)]
        new(slots, 0, 1, 1, ReentrantLock())
    end
end

_metadata(values::AbstractDict) = Dict{Symbol,Any}(Symbol(key) => value for (key, value) in values)
_metadata(values::NamedTuple) = Dict{Symbol,Any}(Symbol(key) => value for (key, value) in pairs(values))
_metadata(::Nothing) = TraceMetadata()

trace!(::NullTraceSink, ::Symbol, ::Symbol; phase::Symbol=:instant, metadata=nothing) = nothing

function trace!(
    sink::RingTraceSink,
    category::Symbol,
    name::Symbol;
    phase::Symbol=:instant,
    metadata=nothing,
)
    lock(sink.mutex) do
        event = TraceEvent(
            sink.next_sequence,
            time_ns(),
            category,
            name,
            phase,
            _metadata(metadata),
        )
        sink.slots[sink.next_index] = event
        sink.next_index = sink.next_index == length(sink.slots) ? 1 : sink.next_index + 1
        sink.count = min(sink.count + 1, length(sink.slots))
        sink.next_sequence += 1
        return event
    end
end

trace_events(::NullTraceSink) = TraceEvent[]

function trace_events(sink::RingTraceSink)
    lock(sink.mutex) do
        result = TraceEvent[]
        sizehint!(result, sink.count)
        start = sink.count == length(sink.slots) ? sink.next_index : 1
        for offset in 0:(sink.count - 1)
            index = mod1(start + offset, length(sink.slots))
            event = sink.slots[index]
            event === nothing || push!(result, event)
        end
        return result
    end
end

clear_traces!(::NullTraceSink) = nothing

function clear_traces!(sink::RingTraceSink)
    lock(sink.mutex) do
        fill!(sink.slots, nothing)
        sink.count = 0
        sink.next_index = 1
    end
    return sink
end

"""Run `operation` and emit balanced begin/end or begin/error trace events."""
function with_trace_span(
    operation::F,
    sink::AbstractTraceSink,
    category::Symbol,
    name::Symbol;
    metadata=nothing,
) where {F}
    started = time_ns()
    trace!(sink, category, name; phase=:begin, metadata=metadata)
    try
        result = operation()
        trace!(
            sink,
            category,
            name;
            phase=:end,
            metadata=(duration_ns=time_ns() - started,),
        )
        return result
    catch error
        trace!(
            sink,
            category,
            name;
            phase=:error,
            metadata=(duration_ns=time_ns() - started, error=repr(error)),
        )
        rethrow()
    end
end

"""Immutable summary of the rolling frame-performance window."""
struct MetricsSnapshot
    frames_total::UInt64
    last_frame_ns::UInt64
    mean_frame_ns::Float64
    p95_frame_ns::UInt64
    max_frame_ns::UInt64
    frames_per_second::Float64
    last_diff_cells::Int
    last_drawn_cells::Int
    input_events_total::UInt64
    commands_total::UInt64
    dropped_events_total::UInt64
end

"""Thread-safe rolling frame metrics with fixed memory usage."""
mutable struct FrameMetrics
    samples_ns::Vector{UInt64}
    sample_count::Int
    next_sample::Int
    frames_total::UInt64
    last_frame_ns::UInt64
    last_diff_cells::Int
    last_drawn_cells::Int
    input_events_total::UInt64
    commands_total::UInt64
    dropped_events_total::UInt64
    mutex::ReentrantLock

    function FrameMetrics(window::Integer=240)
        window > 0 || throw(ArgumentError("metrics window must be positive"))
        new(
            zeros(UInt64, Int(window)),
            0,
            1,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            ReentrantLock(),
        )
    end
end

function record_frame!(
    metrics::FrameMetrics,
    duration_ns::Integer;
    diff_cells::Integer=0,
    drawn_cells::Integer=0,
)
    duration_ns >= 0 || throw(ArgumentError("frame duration cannot be negative"))
    diff_cells >= 0 || throw(ArgumentError("diff cell count cannot be negative"))
    drawn_cells >= 0 || throw(ArgumentError("drawn cell count cannot be negative"))
    sample = UInt64(duration_ns)
    lock(metrics.mutex) do
        metrics.samples_ns[metrics.next_sample] = sample
        metrics.next_sample = metrics.next_sample == length(metrics.samples_ns) ? 1 : metrics.next_sample + 1
        metrics.sample_count = min(metrics.sample_count + 1, length(metrics.samples_ns))
        metrics.frames_total += 1
        metrics.last_frame_ns = sample
        metrics.last_diff_cells = Int(diff_cells)
        metrics.last_drawn_cells = Int(drawn_cells)
    end
    return metrics
end

function _record_counter!(metrics::FrameMetrics, field::Symbol, count::Integer)
    count >= 0 || throw(ArgumentError("counter increment cannot be negative"))
    lock(metrics.mutex) do
        setfield!(metrics, field, getfield(metrics, field) + UInt64(count))
    end
    return metrics
end

record_input!(metrics::FrameMetrics, count::Integer=1) =
    _record_counter!(metrics, :input_events_total, count)
record_command!(metrics::FrameMetrics, count::Integer=1) =
    _record_counter!(metrics, :commands_total, count)
record_dropped_event!(metrics::FrameMetrics, count::Integer=1) =
    _record_counter!(metrics, :dropped_events_total, count)

function metrics_snapshot(metrics::FrameMetrics)
    lock(metrics.mutex) do
        samples = if metrics.sample_count == length(metrics.samples_ns)
            copy(metrics.samples_ns)
        else
            copy(@view metrics.samples_ns[1:metrics.sample_count])
        end
        if isempty(samples)
            mean_ns = 0.0
            p95_ns = UInt64(0)
            maximum_ns = UInt64(0)
        else
            mean_ns = sum(samples; init=UInt64(0)) / length(samples)
            ordered = sort(samples)
            p95_ns = ordered[clamp(ceil(Int, 0.95 * length(ordered)), 1, length(ordered))]
            maximum_ns = maximum(samples)
        end
        fps = mean_ns == 0 ? 0.0 : 1_000_000_000 / mean_ns
        return MetricsSnapshot(
            metrics.frames_total,
            metrics.last_frame_ns,
            mean_ns,
            p95_ns,
            maximum_ns,
            fps,
            metrics.last_diff_cells,
            metrics.last_drawn_cells,
            metrics.input_events_total,
            metrics.commands_total,
            metrics.dropped_events_total,
        )
    end
end

"""Shared instrumentation endpoint intended to be owned by an application runtime."""
mutable struct DiagnosticsHub{T<:AbstractTraceSink}
    traces::T
    metrics::FrameMetrics
    enabled::Bool
end

function DiagnosticsHub(;
    enabled::Bool=true,
    trace_capacity::Integer=2_048,
    metrics_window::Integer=240,
)
    traces = enabled ? RingTraceSink(trace_capacity) : NullTraceSink()
    return DiagnosticsHub(traces, FrameMetrics(metrics_window), enabled)
end

function begin_frame!(hub::DiagnosticsHub)
    hub.enabled && trace!(hub.traces, :render, :frame; phase=:begin)
    return time_ns()
end

function end_frame!(
    hub::DiagnosticsHub,
    started_ns::Integer;
    diff_cells::Integer=0,
    drawn_cells::Integer=0,
)
    duration = time_ns() - UInt64(started_ns)
    record_frame!(hub.metrics, duration; diff_cells=diff_cells, drawn_cells=drawn_cells)
    hub.enabled && trace!(
        hub.traces,
        :render,
        :frame;
        phase=:end,
        metadata=(duration_ns=duration, diff_cells=diff_cells, drawn_cells=drawn_cells),
    )
    return duration
end

function record_input!(hub::DiagnosticsHub, event=nothing)
    record_input!(hub.metrics)
    hub.enabled && trace!(hub.traces, :input, :event; metadata=(event=repr(event),))
    return hub
end

function record_command!(hub::DiagnosticsHub, command=nothing)
    record_command!(hub.metrics)
    hub.enabled && trace!(hub.traces, :runtime, :command; metadata=(command=repr(command),))
    return hub
end

function record_dropped_event!(hub::DiagnosticsHub, count::Integer=1)
    record_dropped_event!(hub.metrics, count)
    hub.enabled && trace!(hub.traces, :runtime, :dropped_event; metadata=(count=count,))
    return hub
end

@enum InspectorPanel begin
    MetricsPanel
    TracesPanel
    TreePanel
    FocusPanel
    StylesPanel
end

const INSPECTOR_PANELS = instances(InspectorPanel)

"""Interactive state for an inspector hosted by an application overlay or screen."""
mutable struct DeveloperInspector
    visible::Bool
    panel::InspectorPanel
    selected::Int
    max_trace_rows::Int

    function DeveloperInspector(;
        visible::Bool=false,
        panel::InspectorPanel=MetricsPanel,
        max_trace_rows::Integer=200,
    )
        max_trace_rows > 0 || throw(ArgumentError("max trace rows must be positive"))
        new(visible, panel, 1, Int(max_trace_rows))
    end
end

struct InspectorSnapshot
    captured_at::DateTime
    metrics::MetricsSnapshot
    traces::Vector{TraceEvent}
    tree::Vector{String}
    focus::Vector{String}
    styles::Vector{String}
end

toggle_inspector!(inspector::DeveloperInspector) = (inspector.visible = !inspector.visible; inspector)

function next_panel!(inspector::DeveloperInspector)
    index = findfirst(==(inspector.panel), INSPECTOR_PANELS)
    inspector.panel = INSPECTOR_PANELS[mod1(index + 1, length(INSPECTOR_PANELS))]
    inspector.selected = 1
    return inspector
end

function previous_panel!(inspector::DeveloperInspector)
    index = findfirst(==(inspector.panel), INSPECTOR_PANELS)
    inspector.panel = INSPECTOR_PANELS[mod1(index - 1, length(INSPECTOR_PANELS))]
    inspector.selected = 1
    return inspector
end

function move_selection!(inspector::DeveloperInspector, delta::Integer; item_count::Integer=typemax(Int))
    item_count >= 0 || throw(ArgumentError("item count cannot be negative"))
    upper = max(1, Int(item_count))
    inspector.selected = clamp(inspector.selected + Int(delta), 1, upper)
    return inspector
end

function capture_inspector(
    hub::DiagnosticsHub;
    tree=String[],
    focus=String[],
    styles=String[],
)
    return InspectorSnapshot(
        now(),
        metrics_snapshot(hub.metrics),
        trace_events(hub.traces),
        String[string(value) for value in tree],
        String[string(value) for value in focus],
        String[string(value) for value in styles],
    )
end

_milliseconds(value::Real) = round(value / 1_000_000; digits=3)

function _metric_lines(metrics::MetricsSnapshot)
    return String[
        "frames             $(metrics.frames_total)",
        "fps                $(round(metrics.frames_per_second; digits=2))",
        "last frame         $(_milliseconds(metrics.last_frame_ns)) ms",
        "mean frame         $(_milliseconds(metrics.mean_frame_ns)) ms",
        "p95 frame          $(_milliseconds(metrics.p95_frame_ns)) ms",
        "max frame          $(_milliseconds(metrics.max_frame_ns)) ms",
        "changed cells      $(metrics.last_diff_cells)",
        "drawn cells        $(metrics.last_drawn_cells)",
        "input events       $(metrics.input_events_total)",
        "commands           $(metrics.commands_total)",
        "dropped events     $(metrics.dropped_events_total)",
    ]
end

function _trace_line(event::TraceEvent)
    details = join(
        ("$(key)=$(replace(repr(value), '\n' => ' '))" for (key, value) in sort!(collect(event.metadata); by=first)),
        " ",
    )
    prefix = "#$(event.sequence) $(event.category).$(event.name) [$(event.phase)]"
    return isempty(details) ? prefix : "$prefix $details"
end

function _clip_line(value::AbstractString, width::Int)
    width <= 0 && return ""
    length(value) <= width && return String(value)
    width == 1 && return "\u2026"
    return first(value, width - 1) * "\u2026"
end

function _panel_lines(inspector::DeveloperInspector, snapshot::InspectorSnapshot)
    if inspector.panel == MetricsPanel
        return _metric_lines(snapshot.metrics)
    elseif inspector.panel == TracesPanel
        first_index = max(1, length(snapshot.traces) - inspector.max_trace_rows + 1)
        return String[_trace_line(event) for event in @view snapshot.traces[first_index:end]]
    elseif inspector.panel == TreePanel
        return snapshot.tree
    elseif inspector.panel == FocusPanel
        return snapshot.focus
    else
        return snapshot.styles
    end
end

"""Produce bounded inspector rows suitable for a Paragraph, overlay, or remote client."""
function inspector_lines(
    inspector::DeveloperInspector,
    snapshot::InspectorSnapshot;
    width::Integer=80,
    height::Integer=24,
)
    width >= 0 || throw(ArgumentError("width cannot be negative"))
    height >= 0 || throw(ArgumentError("height cannot be negative"))
    inspector.visible || return String[]
    height == 0 && return String[]

    panels = join((panel == inspector.panel ? "[$panel]" : string(panel) for panel in INSPECTOR_PANELS), "  ")
    rows = String[panels]
    append!(rows, _panel_lines(inspector, snapshot))
    if length(rows) > height
        body_height = max(0, Int(height) - 1)
        start = clamp(inspector.selected, 1, max(1, length(rows) - body_height))
        rows = vcat(rows[1:1], rows[(start + 1):min(length(rows), start + body_height)])
    end
    return String[_clip_line(row, Int(width)) for row in rows]
end

inspector_text(inspector::DeveloperInspector, snapshot::InspectorSnapshot; kwargs...) =
    join(inspector_lines(inspector, snapshot; kwargs...), '\n')

end
