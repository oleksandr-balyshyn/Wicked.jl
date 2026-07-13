"""Safe immediate-mode streaming and system views over Wicked runtime primitives."""

struct LiveDisplay{F}
    draw::F
    width::Int
    height::Int
end

function LiveDisplay(draw::F; width::Integer=80, height::Integer=24) where {F}
    width > 0 || throw(ArgumentError("live display width must be positive"))
    height >= 0 || throw(ArgumentError("live display height cannot be negative"))
    return LiveDisplay{F}(draw, Int(width), Int(height))
end

mutable struct LiveDisplayState
    frame::UInt64
    paused::Bool
end
LiveDisplayState(; paused::Bool=false) = LiveDisplayState(0, paused)
state_for(::LiveDisplay) = LiveDisplayState()
measure(widget::LiveDisplay, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::LiveDisplay, area::Rect, state::LiveDisplayState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return buffer
    value = if applicable(widget.draw, buffer, active, state)
        widget.draw(buffer, active, state)
    elseif applicable(widget.draw, state)
        widget.draw(state)
    else
        widget.draw()
    end
    value === nothing || value === buffer || (value isa AbstractString ? draw_text!(buffer, active.row, active.column, value; clip=active) : render!(buffer, value, active))
    return buffer
end
render!(buffer::Buffer, widget::LiveDisplay, area::Rect) = render!(buffer, widget, area, state_for(widget))
function handle!(state::LiveDisplayState, ::LiveDisplay, event::TickEvent)
    state.paused || (state.frame == typemax(UInt64) ? throw(OverflowError("live display frame counter exhausted")) : (state.frame += 1))
    return !state.paused
end
function handle!(state::LiveDisplayState, ::LiveDisplay, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    event.key.code == :character && event.text == " " || return false
    state.paused = !state.paused
    return true
end

function SemanticToolkit.widget_semantic_descriptor(::LiveDisplay, state::LiveDisplayState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Live display",
        state=Accessibility.SemanticState(focusable=true, busy=!state.paused),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ActivateSemanticAction],
        metadata=Dict(:frame => state.frame, :paused => state.paused),
    )
end

function register_live_display_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::LiveDisplayState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.paused)
        elseif request.action == Accessibility.ActivateSemanticAction
            state.paused = !state.paused
            return Accessibility.SemanticActionResult(true; value=state.paused)
        end
        return Accessibility.SemanticActionResult(false; message="live display semantic action is not supported")
    end)
    return dispatcher
end

struct ProgressGroup{T<:ProgressTracker}
    tracker::T
    width::Int
    height::Int
    show_eta::Bool
end

function ProgressGroup(tracker::ProgressTracker; width::Integer=80, height::Integer=24, show_eta::Bool=false)
    width > 0 || throw(ArgumentError("progress-group width must be positive"))
    height >= 0 || throw(ArgumentError("progress-group height cannot be negative"))
    return ProgressGroup(tracker, Int(width), Int(height), show_eta)
end

mutable struct ProgressGroupState
    offset::Int
    phase::Int
end
ProgressGroupState() = ProgressGroupState(0, 0)
state_for(::ProgressGroup) = ProgressGroupState()
measure(widget::ProgressGroup, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function _progress_group_line(snapshot::ProgressSnapshot, width::Int, phase::Int, show_eta::Bool)
    label = isempty(snapshot.description) ? string(snapshot.id) : snapshot.description
    suffix = snapshot.ratio === nothing ? " ..." : " $(round(Int, snapshot.ratio * 100))%"
    show_eta && snapshot.eta_seconds !== nothing && (suffix *= " eta $(round(Int, snapshot.eta_seconds))s")
    bar_width = max(3, width - min(width - 3, text_width(label * suffix) + 1))
    if snapshot.ratio === nothing
        start = mod(phase, bar_width)
        bar = join(index == start + 1 ? "#" : "-" for index in 1:bar_width)
    else
        filled = clamp(round(Int, snapshot.ratio * bar_width), 0, bar_width)
        bar = repeat("#", filled) * repeat("-", bar_width - filled)
    end
    return "[$bar] $label$suffix"
end

function render!(buffer::Buffer, widget::ProgressGroup, area::Rect, state::ProgressGroupState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return buffer
    snapshots = progress_snapshots(widget.tracker)
    state.offset = clamp(state.offset, 0, max(0, length(snapshots) - active.height))
    for (offset, snapshot) in enumerate(snapshots[(state.offset + 1):min(length(snapshots), state.offset + active.height)])
        draw_text!(buffer, active.row + offset - 1, active.column, _progress_group_line(snapshot, active.width, state.phase, widget.show_eta); clip=active)
    end
    return buffer
end
render!(buffer::Buffer, widget::ProgressGroup, area::Rect) = render!(buffer, widget, area, state_for(widget))
function handle!(state::ProgressGroupState, widget::ProgressGroup, event::TickEvent)
    state.phase = state.phase == typemax(Int) ? 0 : state.phase + 1
    return true
end
function handle!(state::ProgressGroupState, widget::ProgressGroup, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    maximum = max(0, length(progress_snapshots(widget.tracker)) - widget.height)
    if event.key.code == :up
        state.offset = max(0, state.offset - 1)
    elseif event.key.code == :down
        state.offset = min(maximum, state.offset + 1)
    else
        return false
    end
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::ProgressGroup, state::ProgressGroupState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Progress tasks",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.offset, :show_eta => widget.show_eta),
    )
end

function SemanticToolkit.widget_semantic_children(widget::ProgressGroup, ::ProgressGroupState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(snapshot.id)",
            Accessibility.ListItemRole;
            label=isempty(snapshot.description) ? string(snapshot.id) : snapshot.description,
            state=Accessibility.SemanticState(
                busy=snapshot.ratio === nothing,
                value=snapshot.ratio === nothing ? nothing : "$(round(Int, snapshot.ratio * 100))%",
            ),
            metadata=Dict(:task_id => snapshot.id, :eta_seconds => snapshot.eta_seconds),
        ) for snapshot in progress_snapshots(widget.tracker)
    ]
end

function register_progress_group_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ProgressGroup,
    state::ProgressGroupState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        maximum = max(0, length(progress_snapshots(widget.tracker)) - widget.height)
        if request.action == Accessibility.FocusSemanticAction || request.action == Accessibility.ScrollIntoViewSemanticAction
            state.offset = clamp(state.offset, 0, maximum)
            return Accessibility.SemanticActionResult(true; value=state.offset)
        elseif request.action == Accessibility.IncrementSemanticAction
            state.offset = min(maximum, state.offset + 1)
            return Accessibility.SemanticActionResult(true; value=state.offset)
        elseif request.action == Accessibility.DecrementSemanticAction
            state.offset = max(0, state.offset - 1)
            return Accessibility.SemanticActionResult(true; value=state.offset)
        end
        return Accessibility.SemanticActionResult(false; message="progress group semantic action is not supported")
    end)
    return dispatcher
end

struct ProcessView
    result::ProcessResult
    width::Int
    height::Int
    show_stderr::Bool
end

function ProcessView(result::ProcessResult; width::Integer=100, height::Integer=24, show_stderr::Bool=true)
    width > 0 || throw(ArgumentError("process-view width must be positive"))
    height >= 0 || throw(ArgumentError("process-view height cannot be negative"))
    return ProcessView(result, Int(width), Int(height), show_stderr)
end

const ProcessViewState = ScrollState
state_for(::ProcessView) = ProcessViewState()
measure(widget::ProcessView, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function process_view_lines(widget::ProcessView)
    lines = String["\$ $(widget.result.command)", "exit $(widget.result.exit_code)"]
    append!(lines, split(String(widget.result.stdout), '\n'; keepempty=true))
    if widget.show_stderr && !isempty(widget.result.stderr)
        push!(lines, "[stderr]")
        append!(lines, split(String(widget.result.stderr), '\n'; keepempty=true))
    end
    return lines
end

function _render_scrolling_lines!(buffer::Buffer, lines::AbstractVector{<:AbstractString}, area::Rect, state::ScrollState)
    state.row = clamp(state.row, 0, max(0, length(lines) - area.height))
    for (offset, line) in enumerate(lines[(state.row + 1):min(length(lines), state.row + area.height)])
        draw_text!(buffer, area.row + offset - 1, area.column, line; clip=area)
    end
    return buffer
end

function _handle_scrolling_lines!(state::ScrollState, total::Int, height::Int, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :up
        state.row = max(0, state.row - 1)
    elseif event.key.code == :down
        state.row = min(max(0, total - height), state.row + 1)
    elseif event.key.code in (:page_up, :pageup)
        state.row = max(0, state.row - max(1, height))
    elseif event.key.code in (:page_down, :pagedown)
        state.row = min(max(0, total - height), state.row + max(1, height))
    elseif event.key.code == :home
        state.row = 0
    elseif event.key.code == :end
        state.row = max(0, total - height)
    else
        return false
    end
    return true
end

function render!(buffer::Buffer, widget::ProcessView, area::Rect, state::ProcessViewState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) || _render_scrolling_lines!(buffer, process_view_lines(widget), active, state)
    return buffer
end
render!(buffer::Buffer, widget::ProcessView, area::Rect) = render!(buffer, widget, area, state_for(widget))
handle!(state::ProcessViewState, widget::ProcessView, event::KeyEvent) = _handle_scrolling_lines!(state, length(process_view_lines(widget)), widget.height, event)

function SemanticToolkit.widget_semantic_descriptor(widget::ProcessView, state::ProcessViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label="Process result",
        state=Accessibility.SemanticState(
            focusable=true,
            readonly=true,
            value="exit $(widget.result.exit_code)",
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:command => widget.result.command, :offset => state.row),
    )
end

function _register_scroll_state_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::ScrollState,
    total_function,
    height::Integer,
    label::AbstractString,
)
    node_id = string(id)
    viewport_height = max(0, Int(height))
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        maximum = max(0, Int(total_function()) - viewport_height)
        if request.action == Accessibility.FocusSemanticAction || request.action == Accessibility.ScrollIntoViewSemanticAction
            state.row = clamp(state.row, 0, maximum)
            return Accessibility.SemanticActionResult(true; value=state.row)
        elseif request.action == Accessibility.IncrementSemanticAction
            state.row = min(maximum, state.row + 1)
            return Accessibility.SemanticActionResult(true; value=state.row)
        elseif request.action == Accessibility.DecrementSemanticAction
            state.row = max(0, state.row - 1)
            return Accessibility.SemanticActionResult(true; value=state.row)
        end
        return Accessibility.SemanticActionResult(false; message="$label semantic action is not supported")
    end)
    return dispatcher
end

register_process_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ProcessView,
    state::ProcessViewState,
) = _register_scroll_state_semantic_handlers!(
    dispatcher,
    id,
    state,
    () -> length(process_view_lines(widget)),
    widget.height,
    "process view",
)

struct TerminalView
    text::String
    width::Int
    height::Int
end
function TerminalView(text::AbstractString=""; width::Integer=100, height::Integer=24)
    width > 0 || throw(ArgumentError("terminal-view width must be positive"))
    height >= 0 || throw(ArgumentError("terminal-view height cannot be negative"))
    TerminalView(String(text), Int(width), Int(height))
end
const TerminalViewState = ScrollState
state_for(::TerminalView) = TerminalViewState()
set_terminal_view!(widget::TerminalView, text::AbstractString) = TerminalView(String(text), widget.width, widget.height)
measure(widget::TerminalView, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))
function render!(buffer::Buffer, widget::TerminalView, area::Rect, state::TerminalViewState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) || _render_scrolling_lines!(buffer, split(widget.text, '\n'; keepempty=true), active, state)
    return buffer
end
render!(buffer::Buffer, widget::TerminalView, area::Rect) = render!(buffer, widget, area, state_for(widget))
handle!(state::TerminalViewState, widget::TerminalView, event::KeyEvent) = _handle_scrolling_lines!(state, length(split(widget.text, '\n'; keepempty=true)), widget.height, event)

function SemanticToolkit.widget_semantic_descriptor(widget::TerminalView, state::TerminalViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label="Terminal output",
        state=Accessibility.SemanticState(
            focusable=true,
            readonly=true,
            value="$(length(split(widget.text, '\n'; keepempty=true))) lines",
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.row),
    )
end

register_terminal_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::TerminalView,
    state::TerminalViewState,
) = _register_scroll_state_semantic_handlers!(
    dispatcher,
    id,
    state,
    () -> length(split(widget.text, '\n'; keepempty=true)),
    widget.height,
    "terminal view",
)

struct TaskMonitor
    tasks::Vector{Task}
    width::Int
    height::Int
end
function TaskMonitor(tasks::AbstractVector{<:Task}; width::Integer=80, height::Integer=16)
    width > 0 || throw(ArgumentError("task-monitor width must be positive"))
    height >= 0 || throw(ArgumentError("task-monitor height cannot be negative"))
    TaskMonitor(Task[tasks...], Int(width), Int(height))
end
const TaskMonitorState = ScrollState
state_for(::TaskMonitor) = TaskMonitorState()
measure(widget::TaskMonitor, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))
task_monitor_lines(widget::TaskMonitor) = String["task $index " * (istaskfailed(task) ? "failed" : istaskdone(task) ? "completed" : "running") for (index, task) in enumerate(widget.tasks)]
function render!(buffer::Buffer, widget::TaskMonitor, area::Rect, state::TaskMonitorState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) || _render_scrolling_lines!(buffer, task_monitor_lines(widget), active, state)
    return buffer
end
render!(buffer::Buffer, widget::TaskMonitor, area::Rect) = render!(buffer, widget, area, state_for(widget))
handle!(state::TaskMonitorState, widget::TaskMonitor, event::KeyEvent) = _handle_scrolling_lines!(state, length(widget.tasks), widget.height, event)

function SemanticToolkit.widget_semantic_descriptor(::TaskMonitor, state::TaskMonitorState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Tasks",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.row),
    )
end

function SemanticToolkit.widget_semantic_children(widget::TaskMonitor, ::TaskMonitorState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(index)",
            Accessibility.ListItemRole;
            label=line,
            state=Accessibility.SemanticState(busy=!istaskdone(task)),
            metadata=Dict(:task_index => index, :failed => istaskfailed(task)),
        ) for (index, (task, line)) in enumerate(zip(widget.tasks, task_monitor_lines(widget)))
    ]
end

register_task_monitor_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::TaskMonitor,
    state::TaskMonitorState,
) = _register_scroll_state_semantic_handlers!(
    dispatcher,
    id,
    state,
    () -> length(widget.tasks),
    widget.height,
    "task monitor",
)

struct LogTail
    log::LogState
    width::Int
    height::Int
    follow::Bool
end
function LogTail(log::LogState; width::Integer=100, height::Integer=16, follow::Bool=true)
    width > 0 || throw(ArgumentError("log-tail width must be positive"))
    height >= 0 || throw(ArgumentError("log-tail height cannot be negative"))
    LogTail(log, Int(width), Int(height), follow)
end
const LogTailState = LogState
state_for(widget::LogTail) = widget.log
measure(widget::LogTail, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))
function render!(buffer::Buffer, widget::LogTail, area::Rect, state::LogTailState)
    widget.follow && (state.offset = 0)
    return render!(buffer, LogView(), Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)), state)
end
render!(buffer::Buffer, widget::LogTail, area::Rect) = render!(buffer, widget, area, widget.log)
handle!(state::LogTailState, ::LogTail, event::KeyEvent) = handle!(state, LogView(), event)

function SemanticToolkit.widget_semantic_descriptor(widget::LogTail, state::LogTailState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Log tail",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.offset, :follow => widget.follow),
    )
end

function SemanticToolkit.widget_semantic_children(widget::LogTail, state::LogTailState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(index)",
            Accessibility.ListItemRole;
            label=entry.message,
            state=Accessibility.SemanticState(value=string(entry.level)),
            metadata=Dict(:level => entry.level, :timestamp_ns => entry.timestamp_ns),
        ) for (index, entry) in enumerate(state.entries)
    ]
end

function register_log_tail_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::LogTail,
    state::LogTailState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        maximum = max(0, length(state.entries) - widget.height)
        if request.action == Accessibility.FocusSemanticAction
            state.offset = clamp(state.offset, 0, maximum)
            return Accessibility.SemanticActionResult(true; value=state.offset)
        elseif request.action == Accessibility.ScrollIntoViewSemanticAction
            state.offset = 0
            return Accessibility.SemanticActionResult(true; value=state.offset)
        elseif request.action == Accessibility.IncrementSemanticAction
            state.offset = max(0, state.offset - 1)
            return Accessibility.SemanticActionResult(true; value=state.offset)
        elseif request.action == Accessibility.DecrementSemanticAction
            state.offset = min(maximum, state.offset + 1)
            return Accessibility.SemanticActionResult(true; value=state.offset)
        end
        return Accessibility.SemanticActionResult(false; message="log tail semantic action is not supported")
    end)
    return dispatcher
end

struct ReplView{F}
    evaluate::F
    prompt::String
    width::Int
    height::Int
    history_limit::Int
end
function ReplView(evaluate::F=identity; prompt::AbstractString="julia> ", width::Integer=100, height::Integer=16, history_limit::Integer=100) where {F}
    width > 0 || throw(ArgumentError("repl-view width must be positive"))
    height >= 1 || throw(ArgumentError("repl-view height must be at least one"))
    history_limit >= 0 || throw(ArgumentError("repl-view history limit cannot be negative"))
    ReplView{F}(evaluate, String(prompt), Int(width), Int(height), Int(history_limit))
end

mutable struct ReplViewState
    input::TextAreaState
    output::LogState
    history::Vector{String}
    history_index::Int
end
ReplViewState(; history_limit::Integer=100) = ReplViewState(TextAreaState(""; focused=true, history_limit), LogState(max(1, history_limit == 0 ? 1 : history_limit)), String[], 0)
state_for(widget::ReplView) = ReplViewState(; history_limit=widget.history_limit)
measure(widget::ReplView, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function _repl_submit!(state::ReplViewState, widget::ReplView)
    command = editing_text(state.input.editing)
    isempty(strip(command)) && return false
    push!(state.history, command)
    length(state.history) > widget.history_limit && popfirst!(state.history)
    state.history_index = length(state.history) + 1
    push_log!(state.output, widget.prompt * command; level=:info)
    try
        value = widget.evaluate(command)
        value === nothing || push_log!(state.output, repr(value); level=:info)
    catch error
        push_log!(state.output, sprint(showerror, error); level=:error)
    end
    set_text!(state.input.editing, ""; record=false)
    return true
end

function render!(buffer::Buffer, widget::ReplView, area::Rect, state::ReplViewState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return buffer
    output_height = max(0, active.height - 1)
    output_height == 0 || render!(buffer, LogView(), Rect(active.row, active.column, output_height, active.width), state.output)
    draw_text!(buffer, active.row + output_height, active.column, widget.prompt * editing_text(state.input.editing); clip=active)
    return buffer
end
render!(buffer::Buffer, widget::ReplView, area::Rect) = render!(buffer, widget, area, state_for(widget))
function handle!(state::ReplViewState, widget::ReplView, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code == :enter
        return _repl_submit!(state, widget)
    elseif event.key.code == :up && !isempty(state.history)
        state.history_index = clamp(state.history_index - 1, 1, length(state.history))
        set_text!(state.input.editing, state.history[state.history_index]; record=false)
        return true
    elseif event.key.code == :down && !isempty(state.history)
        state.history_index = min(length(state.history) + 1, state.history_index + 1)
        set_text!(state.input.editing, state.history_index <= length(state.history) ? state.history[state.history_index] : ""; record=false)
        return true
    end
    return handle!(state.input, TextArea(; maximum_length=typemax(Int)), event)
end
function handle!(state::ReplViewState, widget::ReplView, event::PasteEvent)
    return handle!(state.input, TextArea(; maximum_length=typemax(Int)), event)
end

function SemanticToolkit.widget_semantic_descriptor(widget::ReplView, state::ReplViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label="REPL input",
        state=Accessibility.SemanticState(
            focusable=true,
            focused=state.input.focused,
            value=editing_text(state.input.editing),
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.ActivateSemanticAction,
        ],
        metadata=Dict(:prompt => widget.prompt, :history_count => length(state.history), :output_count => length(state.output.entries)),
    )
end

function register_repl_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ReplView,
    state::ReplViewState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            state.input.focused = true
            return Accessibility.SemanticActionResult(true; value=editing_text(state.input.editing))
        elseif request.action == Accessibility.SetValueSemanticAction
            set_text!(state.input.editing, string(request.value); record=false)
            return Accessibility.SemanticActionResult(true; value=editing_text(state.input.editing))
        elseif request.action == Accessibility.ActivateSemanticAction
            submitted = _repl_submit!(state, widget)
            return Accessibility.SemanticActionResult(submitted; value=length(state.output.entries))
        end
        return Accessibility.SemanticActionResult(false; message="REPL view semantic action is not supported")
    end)
    return dispatcher
end
