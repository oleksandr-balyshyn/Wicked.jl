using Unicode

using .Accessibility: ProgressRole, SemanticNode, SemanticRect, SemanticState
using .Core: DEFAULT_WIDTH_POLICY, grapheme_width, text_width


function _clip_progress_label(value::AbstractString, width::Int)
    width <= 0 && return ""
    output = IOBuffer()
    used = 0
    for grapheme in Unicode.graphemes(value)
        cells = grapheme_width(DEFAULT_WIDTH_POLICY, grapheme)
        used + cells > width && break
        print(output, grapheme)
        used += cells
    end
    return String(take!(output))
end

function _progress_span_role(status::ProgressTaskStatus, segment::Symbol)
    status == FailedProgress && return Symbol("progress_failed_", segment)
    status == CancelledProgress && return Symbol("progress_cancelled_", segment)
    status == PausedProgress && return Symbol("progress_paused_", segment)
    status == CompletedProgress && return Symbol("progress_completed_", segment)
    return Symbol("progress_", segment)
end

function render_progress_control(
    snapshot::ProgressSnapshot;
    width::Integer=40,
    phase::Integer=0,
    pulse_width::Integer=4,
    show_percentage::Bool=true,
    show_eta::Bool=false,
    filled_symbol::AbstractString="━",
    empty_symbol::AbstractString="─",
)
    resolved_width = Int(width)
    resolved_width > 0 || throw(ArgumentError("progress control width must be positive"))
    phase >= 0 || throw(ArgumentError("progress phase must be non-negative"))
    pulse_width > 0 || throw(ArgumentError("progress pulse width must be positive"))
    text_width(filled_symbol) == 1 ||
        throw(ArgumentError("progress filled symbol must occupy one cell"))
    text_width(empty_symbol) == 1 ||
        throw(ArgumentError("progress empty symbol must occupy one cell"))
    label = _progress_label(snapshot; percentage=show_percentage, eta=show_eta)
    label_limit = isempty(label) ? 0 : max(0, div(resolved_width, 2))
    clipped_label = _clip_progress_label(label, label_limit)
    label_width = text_width(clipped_label)
    separator_width = isempty(clipped_label) ? 0 : 1
    bar_width = max(0, resolved_width - label_width - separator_width)
    spans = RichContent.RichSpan[]
    if snapshot.ratio === nothing
        pulse = min(Int(pulse_width), bar_width)
        start = bar_width == 0 ? 0 :
            Int(mod(UInt64(phase), UInt64(bar_width + pulse))) - pulse
        before = clamp(start, 0, bar_width)
        active_start = clamp(start, 0, bar_width)
        active_end = clamp(start + pulse, 0, bar_width)
        after = bar_width - active_end
        before > 0 && push!(
            spans,
            RichContent.RichSpan(
                repeat(String(empty_symbol), before),
                _progress_span_role(snapshot.status, :empty),
                nothing,
            ),
        )
        active_end > active_start && push!(
            spans,
            RichContent.RichSpan(
                repeat(String(filled_symbol), active_end - active_start),
                _progress_span_role(snapshot.status, :pulse),
                nothing,
            ),
        )
        after > 0 && push!(
            spans,
            RichContent.RichSpan(
                repeat(String(empty_symbol), after),
                _progress_span_role(snapshot.status, :empty),
                nothing,
            ),
        )
    else
        filled = clamp(round(Int, bar_width * snapshot.ratio), 0, bar_width)
        filled > 0 && push!(
            spans,
            RichContent.RichSpan(
                repeat(String(filled_symbol), filled),
                _progress_span_role(snapshot.status, :filled),
                nothing,
            ),
        )
        filled < bar_width && push!(
            spans,
            RichContent.RichSpan(
                repeat(String(empty_symbol), bar_width - filled),
                _progress_span_role(snapshot.status, :empty),
                nothing,
            ),
        )
    end
    if !isempty(clipped_label)
        push!(spans, RichContent.RichSpan(" ", :progress_separator, nothing))
        push!(
            spans,
            RichContent.RichSpan(
                clipped_label,
                _progress_span_role(snapshot.status, :label),
                nothing,
            ),
        )
    end
    return RichContent.RichLine(spans, :progress, nothing)
end

function progress_semantic_node(
    snapshot::ProgressSnapshot;
    id=string(snapshot.id),
    label::AbstractString=snapshot.description,
    bounds::Union{Nothing,SemanticRect}=nothing,
)
    indeterminate = snapshot.ratio === nothing &&
        snapshot.status in (RunningProgress, PausedProgress)
    value = if snapshot.total === nothing
        string(snapshot.status)
    else
        string(snapshot.completed, " / ", snapshot.total)
    end
    return SemanticNode(
        id,
        ProgressRole;
        label,
        description=snapshot.error,
        bounds,
        state=SemanticState(
            busy=indeterminate && snapshot.status == RunningProgress,
            invalid=snapshot.status == FailedProgress,
            value=value,
            value_now=snapshot.total === nothing ? nothing : snapshot.completed,
            value_min=snapshot.total === nothing ? nothing : 0.0,
            value_max=snapshot.total,
        ),
        metadata=Dict(
            :task_id => snapshot.id,
            :status => snapshot.status,
            :ratio => snapshot.ratio,
            :elapsed_seconds => snapshot.elapsed_seconds,
            :eta_seconds => snapshot.eta_seconds,
        ),
    )
end

function progress_component(
    adapter::CoreIntegration.ToolkitElementAdapter,
    snapshot::ProgressSnapshot;
    width::Integer=40,
    phase::Integer=0,
    semantic_id=string(snapshot.id),
    semantic_label::AbstractString=snapshot.description,
    semantic_bounds::Union{Nothing,SemanticRect}=nothing,
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=false,
    render_options...,
)
    rendered = render_progress_control(
        snapshot;
        width,
        phase,
        render_options...,
    )
    semantics = progress_semantic_node(
        snapshot;
        id=semantic_id,
        label=semantic_label,
        bounds=semantic_bounds,
    )
    return ToolkitComponents.toolkit_component_view(
        adapter,
        rendered,
        semantics;
        key,
        id,
        classes,
        focusable,
    )
end
