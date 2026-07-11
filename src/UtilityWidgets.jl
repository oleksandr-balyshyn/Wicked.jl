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
               MouseRelease
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

const LoadingIndicator = Spinner
const LoadingIndicatorState = SpinnerState

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
        actions=[Accessibility.FocusSemanticAction],
    )
end

function SemanticToolkit.widget_semantic_children(::Stepper, state::StepperState, id)
    return stepper_semantic_tree(state; id, label="Progress steps").root.children
end
