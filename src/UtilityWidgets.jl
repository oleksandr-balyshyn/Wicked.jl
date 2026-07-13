using Unicode

using .Accessibility: ActivateSemanticAction,
                      GenericRole,
                      LinkRole,
                      SemanticAction,
                      SemanticNode,
                      SemanticRect,
                      SemanticState,
                      StatusRole
using .Core: AnsiColor,
             BOLD,
             Buffer,
             Cell,
             CenterAlign,
             apply,
             DEFAULT_WIDTH_POLICY,
             DIM,
             REVERSED,
             Rect,
             Size,
             Style,
             UNDERLINE,
             contains,
             draw_text!,
             grapheme_width,
             intersection,
             inner,
             text_width
import .Core: measure, render!
using .Events: KeyEvent,
               KeyPress,
               KeyRepeat,
               LeftMouseButton,
               MouseEvent,
               MouseMove,
               MousePress,
               MouseRelease,
               TickEvent
using .AdvancedControls: ActiveStep,
                        CompletedStep,
                        FailedStep,
                        StepStatus,
                        StepItem,
                        PendingStep,
                        SkippedStep,
                        StepperState,
                        _activate_step!,
                        next_step!,
                        previous_step!,
                        complete_step!,
                        fail_step!,
                        skip_step!
using .Widgets: Block, Label, Spinner, SpinnerState, _visual_area
import .Widgets: activate, handle!
import .Toolkit: state_for


mutable struct LinkState
    focused::Bool
    hovered::Bool
    pressed::Bool
end

LinkState(; focused::Bool=false, hovered::Bool=false) =
    LinkState(focused, hovered, false)

const _DIGIT_FONT = Dict{Char,NTuple{5,String}}(
    '0' => ("┌─┐", "│ │", "│ │", "│ │", "└─┘"),
    '1' => (" ╷ ", " │ ", " │ ", " │ ", " ╵ "),
    '2' => ("┌─┐", "  │", "┌─┘", "│  ", "└─┘"),
    '3' => ("┌─┐", "  │", " ─┤", "  │", "└─┘"),
    '4' => ("╷ ╷", "│ │", "└─┤", "  │", "  ╵"),
    '5' => ("┌─┐", "│  ", "└─┐", "  │", "└─┘"),
    '6' => ("┌─┐", "│  ", "├─┐", "│ │", "└─┘"),
    '7' => ("┌─┐", "  │", "  │", "  │", "  ╵"),
    '8' => ("┌─┐", "│ │", "├─┤", "│ │", "└─┘"),
    '9' => ("┌─┐", "│ │", "└─┤", "  │", "└─┘"),
    ':' => ("   ", " ● ", "   ", " ● ", "   "),
    '.' => ("   ", "   ", "   ", "   ", " ● "),
    '-' => ("   ", "   ", " ─ ", "   ", "   "),
    ' ' => ("   ", "   ", "   ", "   ", "   "),
    '?' => ("┌─┐", "  │", " ─┘", "   ", " ● "),
)

struct Digits
    value::String
    spacing::Int
    style::Style
end

function Digits(value; spacing::Integer=1, style::Style=Style(modifiers=BOLD))
    spacing >= 0 || throw(ArgumentError("digit spacing must be non-negative"))
    return Digits(string(value), Int(spacing), style)
end

function _digit_rows(widget::Digits)
    characters = collect(widget.value)
    separator = repeat(" ", widget.spacing)
    return String[
        join((get(_DIGIT_FONT, character, _DIGIT_FONT['?'])[row] for character in characters), separator)
        for row in 1:5
    ]
end

function render!(buffer::Buffer, widget::Digits, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    for (offset, row) in enumerate(_digit_rows(widget))
        offset > active.height && break
        draw_text!(
            buffer,
            active.row + offset - 1,
            active.column,
            row;
            style=widget.style,
            clip=active,
        )
    end
    return buffer
end

function measure(widget::Digits, available::Rect)
    rows = _digit_rows(widget)
    width = isempty(rows) ? 0 : maximum(text_width(row) for row in rows)
    return Size(min(available.height, 5), min(available.width, width))
end

function digits_semantic_node(
    widget::Digits;
    id="digits",
    label::AbstractString=widget.value,
    bounds::Union{Nothing,SemanticRect}=nothing,
)
    return SemanticNode(
        id,
        StatusRole;
        label,
        bounds,
        state=SemanticState(readonly=true, value=widget.value),
    )
end

struct Pretty{T}
    value::T
    compact::Bool
    style::Style
    block::Union{Nothing,Block}
end

Pretty(
    value::T;
    compact::Bool=false,
    style::Style=Style(),
    block::Union{Nothing,Block}=nothing,
) where {T} = Pretty{T}(value, compact, style, block)

function pretty_text(widget::Pretty; height::Integer=24, width::Integer=80)
    height >= 0 && width >= 0 ||
        throw(ArgumentError("pretty display dimensions must be non-negative"))
    output = IOBuffer()
    context = IOContext(
        output,
        :limit => true,
        :compact => widget.compact,
        :displaysize => (Int(height), Int(width)),
    )
    show(context, MIME"text/plain"(), widget.value)
    return String(take!(output))
end

function render!(buffer::Buffer, widget::Pretty, area::Rect)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    lines = split(pretty_text(widget; height=active.height, width=active.width), '\n'; keepempty=true)
    for (offset, line) in enumerate(lines)
        offset > active.height && break
        draw_text!(
            buffer,
            active.row + offset - 1,
            active.column,
            line;
            style=widget.style,
            clip=active,
        )
    end
    return buffer
end

function pretty_semantic_node(
    widget::Pretty;
    id="pretty",
    label::AbstractString="Value",
    bounds::Union{Nothing,SemanticRect}=nothing,
)
    value = pretty_text(widget; height=24, width=80)
    return SemanticNode(
        id,
        GenericRole;
        label,
        bounds,
        state=SemanticState(readonly=true, value),
    )
end

struct Placeholder
    label::String
    symbol::String
    style::Style
    label_style::Style
    block::Union{Nothing,Block}
end

function Placeholder(
    label::AbstractString="Placeholder";
    symbol::AbstractString="·",
    style::Style=Style(modifiers=DIM),
    label_style::Style=Style(modifiers=REVERSED | BOLD),
    block::Union{Nothing,Block}=nothing,
)
    graphemes = collect(Unicode.graphemes(symbol))
    length(graphemes) == 1 && grapheme_width(DEFAULT_WIDTH_POLICY, only(graphemes)) == 1 ||
        throw(ArgumentError("placeholder symbol must be one terminal cell"))
    return Placeholder(String(label), String(symbol), style, label_style, block)
end

function render!(buffer::Buffer, widget::Placeholder, area::Rect)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    for row in active.row:(active.row + active.height - 1)
        for column in active.column:(active.column + active.width - 1)
            buffer[row, column] = Cell(widget.symbol; style=widget.style)
        end
    end
    label = string(widget.label, " ", active.width, "×", active.height)
    render!(
        buffer,
        Label(label; style=widget.label_style, alignment=CenterAlign),
        Rect(active.row + div(active.height - 1, 2), active.column, 1, active.width),
    )
    return buffer
end

struct Skeleton
    base::String
    highlight::String
    highlight_width::Int
    style::Style
    highlight_style::Style
    block::Union{Nothing,Block}
end

function Skeleton(;
    base::AbstractString="-",
    highlight::AbstractString="=",
    highlight_width::Integer=4,
    style::Style=Style(modifiers=DIM),
    highlight_style::Style=Style(modifiers=REVERSED),
    block::Union{Nothing,Block}=nothing,
)
    highlight_width >= 0 || throw(ArgumentError("skeleton highlight width cannot be negative"))
    for symbol in (base, highlight)
        graphemes = collect(Unicode.graphemes(symbol))
        length(graphemes) == 1 && grapheme_width(DEFAULT_WIDTH_POLICY, only(graphemes)) == 1 ||
            throw(ArgumentError("skeleton symbols must be one terminal cell"))
    end
    return Skeleton(String(base), String(highlight), Int(highlight_width), style, highlight_style, block)
end

measure(::Skeleton, available::Rect) = Size(available.height, available.width)

state_for(::Skeleton) = NavigationControls.SkeletonState()

function render!(buffer::Buffer, widget::Skeleton, area::Rect, state::NavigationControls.SkeletonState)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    period_extent = max(1, active.width + state.period)
    for row_offset in 0:(active.height - 1)
        start = mod(state.phase + row_offset, period_extent) + 1
        for column_offset in 0:(active.width - 1)
            highlighted = start <= column_offset + 1 < start + widget.highlight_width
            buffer[active.row + row_offset, active.column + column_offset] = Cell(
                highlighted ? widget.highlight : widget.base;
                style=highlighted ? widget.highlight_style : widget.style,
            )
        end
    end
    return buffer
end

render!(buffer::Buffer, widget::Skeleton, area::Rect) =
    render!(buffer, widget, area, NavigationControls.SkeletonState())

function handle!(state::NavigationControls.SkeletonState, ::Skeleton, event::TickEvent)
    NavigationControls.tick_skeleton!(state)
    return true
end

function _empty_state_lines(widget::NavigationControls.EmptyState)
    lines = String[widget.title]
    widget.message === nothing || push!(lines, widget.message)
    widget.action_label === nothing || push!(lines, "[ $(widget.action_label) ]")
    return lines
end

function measure(widget::NavigationControls.EmptyState, available::Rect)
    lines = _empty_state_lines(widget)
    width = isempty(lines) ? 0 : maximum(text_width, lines)
    return Size(min(available.height, length(lines)), min(available.width, width))
end

function render!(buffer::Buffer, widget::NavigationControls.EmptyState, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    lines = _empty_state_lines(widget)
    visible = min(length(lines), active.height)
    start_row = active.row + max(0, div(active.height - visible, 2))
    for index in 1:visible
        style = index == 1 ? Style(modifiers=BOLD) :
                index == length(lines) && widget.action_label !== nothing ? Style(modifiers=REVERSED) :
                Style(modifiers=DIM)
        render!(
            buffer,
            Label(lines[index]; style, alignment=CenterAlign),
            Rect(start_row + index - 1, active.column, 1, active.width),
        )
    end
    return buffer
end

struct LoadingIndicator
    spinner::Spinner
end

LoadingIndicator(; kwargs...) = LoadingIndicator(Spinner(; kwargs...))

state_for(widget::LoadingIndicator) = state_for(widget.spinner)

render!(buffer::Buffer, widget::LoadingIndicator, area::Rect, state::SpinnerState) =
    render!(buffer, widget.spinner, area, state)

render!(buffer::Buffer, widget::LoadingIndicator, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

handle!(state::SpinnerState, widget::LoadingIndicator, event::TickEvent) =
    handle!(state, widget.spinner, event)

const LoadingIndicatorState = SpinnerState

struct Carousel{T}
    items::Vector{T}
    index::Int
    looping::Bool
    window::Int
    width::Int
    height::Int
    block::Union{Nothing,Block}
    style::Style
    active_style::Style
    indicator_style::Style
end

function Carousel(
    items::AbstractVector{T};
    index::Integer=1,
    looping::Bool=true,
    window::Integer=1,
    width::Integer=24,
    height::Integer=3,
    block::Union{Nothing,Block}=nothing,
    style::Style=Style(),
    active_style::Style=Style(modifiers=BOLD),
    indicator_style::Style=Style(modifiers=DIM),
) where {T}
    window >= 1 || throw(ArgumentError("carousel window must be at least one"))
    width >= 0 || throw(ArgumentError("carousel width must be non-negative"))
    height >= 0 || throw(ArgumentError("carousel height must be non-negative"))
    return Carousel(
        Vector{T}(items),
        Int(index),
        looping,
        Int(window),
        Int(width),
        Int(height),
        block,
        style,
        active_style,
        indicator_style,
    )
end

state_for(widget::Carousel) =
    NavigationControls.CarouselState(widget.items; index=widget.index, looping=widget.looping)

measure(widget::Carousel, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function _render_carousel_item!(buffer::Buffer, item, area::Rect, style::Style)
    if item isa AbstractString
        return render!(buffer, Label(item; style), area)
    elseif applicable(render!, buffer, item, area)
        return render!(buffer, item, area)
    end
    return render!(buffer, Label(string(item); style), area)
end

function render!(
    buffer::Buffer,
    widget::Carousel,
    area::Rect,
    state::NavigationControls.CarouselState,
)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    active = Rect(active.row, active.column, min(active.height, widget.height), min(active.width, widget.width))
    isempty(active) && return buffer
    if state.index === nothing || isempty(state.items)
        render!(buffer, Label("No carousel items"; style=widget.indicator_style, alignment=CenterAlign), active)
        return buffer
    end

    header = "< $(state.index)/$(length(state.items)) >"
    draw_text!(buffer, active.row, active.column, header; style=widget.indicator_style, clip=active)
    item_area = Rect(active.row + 1, active.column, max(0, active.height - 1), active.width)
    isempty(item_area) && return buffer
    visible = NavigationControls.carousel_window(state, min(widget.window, item_area.height))
    for (offset, item) in enumerate(visible)
        row_area = Rect(item_area.row + offset - 1, item_area.column, 1, item_area.width)
        _render_carousel_item!(buffer, item, row_area, offset == 1 ? widget.active_style : widget.style)
    end
    return buffer
end

render!(buffer::Buffer, widget::Carousel, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function handle!(state::NavigationControls.CarouselState, ::Carousel, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    previous = state.index
    if event.key.code in (:right, :down, :j)
        NavigationControls.next_carousel!(state)
    elseif event.key.code in (:left, :up, :k)
        NavigationControls.previous_carousel!(state)
    elseif event.key.code == :home
        NavigationControls.set_carousel_index!(state, 1)
    elseif event.key.code == :end
        NavigationControls.set_carousel_index!(state, length(state.items))
    else
        return false
    end
    return state.index != previous
end

function handle!(
    state::NavigationControls.CarouselState,
    ::Carousel,
    event::MouseEvent,
    area::Rect,
)
    event.button == LeftMouseButton && event.action == MouseRelease || return false
    contains(area, event.position) || return false
    previous = state.index
    midpoint = area.column + div(max(0, area.width - 1), 2)
    if event.position.column <= midpoint
        NavigationControls.previous_carousel!(state)
    else
        NavigationControls.next_carousel!(state)
    end
    return state.index != previous
end

function SemanticToolkit.widget_semantic_descriptor(::Carousel, state::NavigationControls.CarouselState)
    value = state.index === nothing ? "empty" : string(state.index)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Carousel",
        state=Accessibility.SemanticState(value=value, focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.SetValueSemanticAction,
        ],
        metadata=Dict(:index => state.index, :item_count => length(state.items), :looping => state.looping),
    )
end

function _semantic_carousel_index(state::NavigationControls.CarouselState, value)
    value isa Integer && return Int(value)
    index = findfirst(item -> item == value || string(item) == string(value), state.items)
    index !== nothing && return index
    return parse(Int, string(value))
end

function register_carousel_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::NavigationControls.CarouselState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.index)
        elseif request.action == Accessibility.IncrementSemanticAction
            NavigationControls.next_carousel!(state)
            return Accessibility.SemanticActionResult(true; value=state.index)
        elseif request.action == Accessibility.DecrementSemanticAction
            NavigationControls.previous_carousel!(state)
            return Accessibility.SemanticActionResult(true; value=state.index)
        elseif request.action == Accessibility.SetValueSemanticAction
            try
                NavigationControls.set_carousel_index!(state, _semantic_carousel_index(state, request.value))
                return Accessibility.SemanticActionResult(true; value=state.index)
            catch
                return Accessibility.SemanticActionResult(false; message="carousel value must be an item, item label, or integer index")
            end
        end
        return Accessibility.SemanticActionResult(false; message="carousel semantic action is not supported")
    end)
    return dispatcher
end

struct Stepper
    separator::String
    block::Union{Nothing,Block}
    style::Style
    separator_style::Style
    pending_style::Style
    active_style::Style
    completed_style::Style
    failed_style::Style
    skipped_style::Style
end

function Stepper(;
    separator::AbstractString=" -> ",
    block::Union{Nothing,Block}=nothing,
    style::Style=Style(),
    separator_style::Style=Style(modifiers=DIM),
    pending_style::Style=Style(),
    active_style::Style=Style(modifiers=BOLD),
    completed_style::Style=Style(foreground=AnsiColor(2)),
    failed_style::Style=Style(foreground=AnsiColor(1)),
    skipped_style::Style=Style(foreground=AnsiColor(3), modifiers=DIM),
    )
    Stepper(
        String(separator),
        block,
        style,
        separator_style,
        pending_style,
        active_style,
        completed_style,
        failed_style,
        skipped_style,
    )
end

measure(::Stepper, available::Rect) = Size(min(available.height, 1), max(0, available.width))

state_for(::Stepper) = StepperState(StepItem{Any}[])

const _STEPPER_MARKERS = Dict(
    PendingStep => " ",
    ActiveStep => ">",
    CompletedStep => "✓",
    FailedStep => "!",
    SkippedStep => "-",
)

_stepper_marker(status::StepStatus) = _STEPPER_MARKERS[status]

function _compose_stepper_style(base::Style, overlay::Style)
    return Style(
        foreground=overlay.foreground == DefaultColor() ? base.foreground : overlay.foreground,
        background=overlay.background == DefaultColor() ? base.background : overlay.background,
        underline_color=overlay.underline_color == DefaultColor() ? base.underline_color : overlay.underline_color,
        modifiers=base.modifiers | overlay.modifiers,
        hyperlink=overlay.hyperlink === nothing ? base.hyperlink : overlay.hyperlink,
    )
end

function _stepper_status_style(widget::Stepper, status::StepStatus)
    style = widget.style
    return status == PendingStep ? _compose_stepper_style(style, widget.pending_style) :
        status == ActiveStep ? _compose_stepper_style(style, widget.active_style) :
        status == CompletedStep ? _compose_stepper_style(style, widget.completed_style) :
        status == FailedStep ? _compose_stepper_style(style, widget.failed_style) :
        _compose_stepper_style(style, widget.skipped_style)
end

function _stepper_active_rect(widget::Stepper, area::Rect)
    return widget.block === nothing ? area : intersection(area, inner(widget.block, area))
end

function _stepper_segments(widget::Stepper, state::StepperState)
    segments = Tuple{String,Style}[]
    for (index, item) in enumerate(state.steps)
        push!(segments, ("[$(_stepper_marker(state.statuses[index]))] $(item.label)", _stepper_status_style(widget, state.statuses[index])))
        index < length(state.steps) && push!(segments, (widget.separator, widget.separator_style))
    end
    return segments
end

function render!(buffer::Buffer, widget::Stepper, area::Rect, state::StepperState)
    active = _visual_area(buffer, widget.block, area)
    isempty(active) && return buffer
    isempty(state.steps) && return buffer
    row = active.row
    column = active.column
    for (text, style) in _stepper_segments(widget, state)
        width = text_width(text)
        width <= 0 && continue
        column > active.column + active.width - 1 && break
        draw_text!(buffer, row, column, text; style, clip=Rect(active.row, active.column, active.height, active.width))
        column += width
    end
    return buffer
end

render!(buffer::Buffer, widget::Stepper, area::Rect) =
    render!(buffer, widget, area, state_for(widget))

function _set_step_from_click(
    widget::Stepper,
    state::StepperState,
    area::Rect,
    column::Int,
)
    cursor = area.column
    for (index, item) in enumerate(state.steps)
        segment = "[$(_stepper_marker(state.statuses[index]))] $(item.label)"
        if cursor <= column < cursor + text_width(segment)
            return _activate_step!(state, index)
        end
        cursor += text_width(segment)
        index < length(state.steps) && (cursor += text_width(widget.separator))
    end
    return state
end

function handle!(state::StepperState, ::Stepper, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    previous_current = state.current
    previous_statuses = copy(state.statuses)

    if event.key.code in (:right, :down, :j)
        next_step!(state)
    elseif event.key.code in (:left, :up, :k)
        previous_step!(state)
    elseif event.key.code in (:space, :enter)
        complete_step!(state)
    elseif event.key.code in (:home,)
        _activate_step!(state, 1)
    elseif event.key.code in (:end,)
        _activate_step!(state, length(state.steps))
    elseif event.key.code in (:s, :delete, :backspace)
        skip_step!(state)
    elseif event.key.code in (:f, :x)
        fail_step!(state)
    else
        return false
    end

    return state.current != previous_current ||
        state.statuses != previous_statuses
end

function handle!(
    state::StepperState,
    widget::Stepper,
    event::MouseEvent,
    area::Rect,
)
    event.button == LeftMouseButton || return false
    event.action == MousePress || return false
    active = _stepper_active_rect(widget, area)
    (isempty(active) || !contains(active, event.position)) && return false
    event.position.row != active.row && return false
    _set_step_from_click(widget, state, active, event.position.column)
    return true
end

activate(::Stepper, state::StepperState) =
    state.current === nothing ? nothing : state.steps[state.current].value

function SemanticToolkit.widget_semantic_descriptor(::Stepper, ::StepperState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Progress steps",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.ActivateSemanticAction,
            Accessibility.SetValueSemanticAction,
        ],
    )
end

function SemanticToolkit.widget_semantic_children(::Stepper, state::StepperState, id)
    return stepper_semantic_tree(state; id, label="Progress steps").root.children
end

function _set_stepper_semantic_value!(state::StepperState, value)
    value isa Integer && (_activate_step!(state, Int(value)); return true)
    token = lowercase(strip(string(value)))
    if token in ("next", "increment")
        next_step!(state)
        return true
    elseif token in ("previous", "prev", "decrement")
        previous_step!(state)
        return true
    elseif token == "complete"
        complete_step!(state)
        return true
    elseif token == "fail"
        fail_step!(state)
        return true
    elseif token == "skip"
        skip_step!(state)
        return true
    end
    index = findfirst(step -> step.value == value || lowercase(step.label) == token || lowercase(string(step.value)) == token, state.steps)
    index === nothing && return false
    _activate_step!(state, index)
    return true
end

function register_stepper_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    state::StepperState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=state.current)
        elseif request.action == Accessibility.IncrementSemanticAction
            next_step!(state)
            return Accessibility.SemanticActionResult(true; value=state.current)
        elseif request.action == Accessibility.DecrementSemanticAction
            previous_step!(state)
            return Accessibility.SemanticActionResult(true; value=state.current)
        elseif request.action == Accessibility.ActivateSemanticAction
            complete_step!(state)
            return Accessibility.SemanticActionResult(true; value=state.current)
        elseif request.action == Accessibility.SetValueSemanticAction
            _set_stepper_semantic_value!(state, request.value) ||
                return Accessibility.SemanticActionResult(false; message="stepper value must be a command, step index, step label, or step value")
            return Accessibility.SemanticActionResult(true; value=state.current)
        end
        return Accessibility.SemanticActionResult(false; message="stepper semantic action is not supported")
    end)
    return dispatcher
end
