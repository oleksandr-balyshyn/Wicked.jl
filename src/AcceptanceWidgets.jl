"""
Semantic border widget alias.

`Block` is Wicked's authoritative bordered surface; `Border` provides the
specification name without introducing a second rendering implementation.
"""
const Border = Block

"""
Dedicated card-like container built from an explicit border block and child.
"""
struct Card{W}
    child::W
    block::Block
end

Card(child; block::Block=Block()) = Card(child, block)

_static_group_semantics(label::AbstractString; metadata=Dict{Symbol,Any}()) =
    SemanticToolkit.SemanticDescriptor(Accessibility.GroupRole; label, metadata)

SemanticToolkit.widget_semantic_descriptor(::Card, state) = _static_group_semantics("Card")

measure(widget::Card, available::Rect) = measure(Box(widget.child; block=widget.block), available)

function render!(buffer::Buffer, widget::Card, area::Rect)
    render!(buffer, Box(widget.child; block=widget.block), area)
end

"""
Dedicated panel alias preserved for parity migration from prior naming.
"""
const Panel = Card

"""
Rich styled text value alias.

Render a `RichText` directly through `Paragraph`, or compose it from `Span` and
`Line` values before rendering.
"""
const RichText = Text

"""
Dedicated code viewer with explicit state and key bindings.

The wrapper stores immutable rendering configuration while `CodeViewState` tracks
interactive cursor and scroll state.
"""
struct CodeView
    source::String
    language::String
    width::Int
    height::Int
    show_line_numbers::Bool
    bindings::CodeViewBindings
    clipboard::Union{Nothing,ClipboardService}
end

function CodeView(
    source::AbstractString;
    language::AbstractString="",
    width::Integer=80,
    height::Integer=24,
    show_line_numbers::Bool=true,
    bindings::CodeViewBindings=default_code_view_bindings(),
    clipboard::Union{Nothing,ClipboardService}=nothing,
)
    width > 0 || throw(ArgumentError("code view width must be positive"))
    height >= 0 || throw(ArgumentError("code view height cannot be negative"))
    return CodeView(
        String(source),
        String(language),
        Int(width),
        Int(height),
        Bool(show_line_numbers),
        bindings,
        clipboard,
    )
end

state_for(widget::CodeView) = CodeViewState(
    widget.source;
    language=widget.language,
    show_line_numbers=widget.show_line_numbers,
)

measure(widget::CodeView, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::CodeView, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function render!(buffer::Buffer, widget::CodeView, area::Rect, state::CodeViewState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    width = active.width
    height = active.height
    if width == 0 || height == 0
        return buffer
    end
    rendered = render_code_view(
        state;
        width=min(width, widget.width),
        height=min(height, widget.height),
    )
    return render!(
        buffer,
        Paragraph(rich_lines_to_core_text(CoreTextAdapter(), rendered.lines)),
        active,
    )
end

function handle!(state::CodeViewState, widget::CodeView, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_code_view_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
        viewport_height=widget.height,
        clipboard=widget.clipboard,
    )
    return result.consumed
end

function handle!(
    state::CodeViewState,
    widget::CodeView,
    event::MouseEvent,
    area::Rect;
    wheel_step::Integer=3,
)
    contains(area, event.position) || return false
    event.action == MouseScroll || return false
    wheel_step > 0 || throw(ArgumentError("code view wheel step must be positive"))
    if event.button == WheelUpButton
        scroll_code_view!(state, -wheel_step; viewport_height=widget.height)
        return true
    end
    if event.button == WheelDownButton
        scroll_code_view!(state, wheel_step; viewport_height=widget.height)
        return true
    end
    return false
end

function SemanticToolkit.widget_semantic_descriptor(widget::CodeView, state::CodeViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label=isempty(widget.language) ? "Code view" : "$(widget.language) source",
        state=Accessibility.SemanticState(
            focusable=true,
            readonly=true,
            invalid=any(diagnostic -> diagnostic.severity == CodeError, state.diagnostics),
            value="$(length(state.lines)) lines",
        ),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:language => state.language, :first_line => state.first_line, :revision => state.revision),
    )
end

"""
Dedicated diff viewer with explicit `ScrollState` and shared scroll interactions.
"""
struct DiffView
    diff::UnifiedDiff
    width::Int
    height::Int
end

function DiffView(
    diff::UnifiedDiff;
    width::Integer=100,
    height::Integer=24,
)
    width > 0 || throw(ArgumentError("diff view width must be positive"))
    height >= 0 || throw(ArgumentError("diff view height cannot be negative"))
    return DiffView(diff, Int(width), Int(height))
end

const DiffViewState = ScrollState
state_for(::DiffView) = DiffViewState()

measure(widget::DiffView, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::DiffView, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function _diff_max_scroll(widget::DiffView, viewport_height::Integer)
    total = length(widget.diff.lines)
    viewport = max(0, Int(viewport_height))
    return max(0, total - viewport)
end

function render!(buffer::Buffer, widget::DiffView, area::Rect, state::DiffViewState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    width = active.width
    height = active.height
    if width == 0 || height == 0
        return buffer
    end
    content_height = min(height, widget.height)
    max_scroll = _diff_max_scroll(widget, content_height)
    state.row = clamp(state.row, 0, max_scroll)
    start_line = clamp(state.row + 1, 1, max(1, length(widget.diff.lines)))
    lines = render_unified_diff(
        widget.diff;
        width=min(width, widget.width),
        height=content_height,
        first_line=start_line,
    )
    rendered = rich_lines_to_core_text(CoreTextAdapter(), lines)
    return render!(buffer, Paragraph(rendered), active)
end

function handle!(state::DiffViewState, widget::DiffView, event::KeyEvent; page_step::Integer=10)
    event.kind in (KeyPress, KeyRepeat) || return false
    key = event.key.code
    new_row = state.row
    if key == :up
        new_row = max(0, state.row - 1)
    elseif key == :down
        new_row = new_row + 1
    elseif key == :page_up
        new_row = max(0, new_row - max(1, page_step))
    elseif key == :page_down
        new_row = new_row + max(1, page_step)
    elseif key == :home
        new_row = 0
    elseif key == :end
        new_row = _diff_max_scroll(widget, widget.height)
    else
        return false
    end
    state.row = min(_diff_max_scroll(widget, widget.height), max(0, new_row))
    return true
end

function handle!(
    state::DiffViewState,
    widget::DiffView,
    event::MouseEvent,
    area::Rect;
    wheel_step::Integer=3,
)
    contains(area, event.position) || return false
    event.action == MouseScroll || return false
    wheel_step > 0 || throw(ArgumentError("diff view wheel step must be positive"))
    if event.button == WheelUpButton
        state.row = max(0, state.row - wheel_step)
    elseif event.button == WheelDownButton
        state.row = state.row + wheel_step
    else
        return false
    end
    state.row = min(_diff_max_scroll(widget, widget.height), max(0, state.row))
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::DiffView, state::DiffViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label="Unified diff",
        state=Accessibility.SemanticState(
            focusable=true,
            readonly=true,
            value="$(length(widget.diff.lines)) lines",
        ),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:offset => state.row),
    )
end

"""
Stateful adapter for markdown rendering with mutable input bindings and link policy.
"""
mutable struct MarkdownState
    view::MarkdownView
    bindings::MarkdownBindings
    viewport_height::Int
    allow_unsafe_links::Bool
end

function MarkdownState(
    view::MarkdownView;
    bindings::MarkdownBindings=default_markdown_bindings(),
    viewport_height::Integer=1,
    allow_unsafe_links::Bool=false,
)
    viewport_height >= 0 || throw(ArgumentError("markdown viewport height cannot be negative"))
    return MarkdownState(
        view,
        bindings,
        Int(viewport_height),
        Bool(allow_unsafe_links),
    )
end

state_for(view::MarkdownView) = MarkdownState(view)

function SemanticToolkit.widget_semantic_descriptor(widget::MarkdownView, state::MarkdownState)
    links = state.view.rendered.links
    focusable = !isempty(links)
    unsafe_links = count(link -> !link.target.safe, links)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Markdown document",
        state=Accessibility.SemanticState(
            enabled=true,
            focusable=focusable,
            focused=state.view.focused_link !== nothing,
        ),
        actions=focusable ? Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
        ] : Accessibility.SemanticAction[Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict{Symbol,Any}(
            :line_count => markdown_line_count(widget),
            :link_count => length(links),
            :unsafe_link_count => unsafe_links,
            :scroll_offset => state.view.scroll,
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::MarkdownView, state::MarkdownState, id)
    children = Accessibility.SemanticNode[]
    for link in state.view.rendered.links
        enabled = link.target.safe || state.allow_unsafe_links
        push!(
            children,
            Accessibility.SemanticNode(
                (id, :link, link.id),
                Accessibility.LinkRole;
                label=link.label,
                state=Accessibility.SemanticState(
                    enabled=enabled,
                    focusable=true,
                    focused=false,
                ),
                actions=enabled ? Accessibility.SemanticAction[
                    Accessibility.ActivateSemanticAction,
                    Accessibility.FocusSemanticAction,
                ] : Accessibility.SemanticAction[Accessibility.FocusSemanticAction],
                metadata=Dict{Symbol,Any}(
                    :target => link.target.uri,
                    :safe => link.target.safe,
                    :title => link.target.title,
                ),
            ),
        )
    end
    return children
end

measure(widget::MarkdownView, available::Rect) =
    Size(min(available.height, markdown_line_count(widget)), min(available.width, widget.width))

function render!(buffer::Buffer, widget::MarkdownView, area::Rect)
    return render!(buffer, widget, area, state_for(widget))
end

function _sync_markdown_state(state::MarkdownState, available_width::Integer, available_height::Integer)
    viewport_height = max(0, available_height)
    width = max(1, available_width)
    if state.view.width != width
        reflow_markdown!(state.view, width; viewport_height=viewport_height)
    else
        scroll_markdown_to!(state.view, state.view.scroll; viewport_height=viewport_height)
    end
    state.viewport_height = viewport_height
    return state
end

function render!(buffer::Buffer, widget::MarkdownView, area::Rect, state::MarkdownState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    if active.width == 0 || active.height == 0
        state.viewport_height = active.height
        return buffer
    end
    _sync_markdown_state(state, active.width, active.height)
    text = markdown_core_text(
        CoreTextAdapter(),
        state.view,
        min(active.height, state.viewport_height),
    )
    return render!(buffer, Paragraph(text), active)
end

function handle!(state::MarkdownState, widget::MarkdownView, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_markdown_key!(
        state.view,
        state.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
        viewport_height=max(1, state.viewport_height),
        allow_unsafe=state.allow_unsafe_links,
    )
    return result.consumed
end

function handle!(
    state::MarkdownState,
    widget::MarkdownView,
    event::MouseEvent,
    area::Rect;
    allow_unsafe::Union{Nothing,Bool}=nothing,
)
    if !contains(area, event.position)
        event.action == MouseMove || return false
        result = handle_markdown_pointer!(state.view, MarkdownPointerEvent(PointerLeave, 0, 0);
            allow_unsafe=something(allow_unsafe, state.allow_unsafe_links))
        return result.consumed === true
    end
    if state.viewport_height == 0
        return false
    end
    row = event.position.row - area.row + 1
    column = event.position.column - area.column + 1
    if event.action == MouseMove
        pointer = MarkdownPointerEvent(PointerHover, row, column)
    elseif event.action == MousePress && event.button == LeftMouseButton
        pointer = MarkdownPointerEvent(PointerPress, row, column)
    else
        return false
    end
    result = handle_markdown_pointer!(
        state.view,
        pointer;
        allow_unsafe=something(allow_unsafe, state.allow_unsafe_links),
    )
    return result.consumed === true
end

"""
Dedicated single-box layer container with draw order semantics.
"""
struct Layer{T<:Tuple}
    children::T
end

Layer(children...) = Layer(children)

render!(buffer::Buffer, widget::Layer, area::Rect) = render!(buffer, Stack(widget.children...), area)
measure(widget::Layer, available::Rect) = measure(Stack(widget.children...), available)
SemanticToolkit.widget_semantic_descriptor(::Layer, state) = _static_group_semantics("Layer")

"""
Dedicated grouping container for multiple children with optional bordered shell.
"""
struct Group{T<:Tuple}
    children::T
    block::Union{Nothing,Block}
    gap::Int
end

function Group(
    children...;
    block::Union{Nothing,Block}=nothing,
    gap::Integer=0,
)
    gap >= 0 || throw(ArgumentError("group gap must be non-negative"))
    Group{typeof(children)}(
        children,
        block,
        Int(gap),
    )
end

function _group_layout(widget::Group)
    content = Column(widget.children...; gap=widget.gap)
    return isnothing(widget.block) ? content : Box(content; block=widget.block)
end

measure(widget::Group, available::Rect) = measure(_group_layout(widget), available)

render!(buffer::Buffer, widget::Group, area::Rect) = render!(buffer, _group_layout(widget), area)
SemanticToolkit.widget_semantic_descriptor(::Group, state) = _static_group_semantics("Group")

"""
Dedicated viewport container for virtualized content.
"""
struct Viewport{W}
    child::W
    content_size::Size
end

Viewport(child, height::Integer, width::Integer) =
    Viewport(child, Size(Int(height), Int(width)))
Viewport(child; height::Integer=1, width::Integer=1) = Viewport(child, height, width)

state_for(::Viewport) = ScrollState()
const ViewportState = ScrollState

measure(widget::Viewport, available::Rect) = Size(
    min(available.height, widget.content_size.height),
    min(available.width, widget.content_size.width),
)

function _scroll_view(widget::Viewport)
    ScrollView(widget.child; height=widget.content_size.height, width=widget.content_size.width)
end

render!(buffer::Buffer, widget::Viewport, area::Rect, state::ViewportState) =
    render!(buffer, _scroll_view(widget), area, state)

function handle!(state::ViewportState, widget::Viewport, event::KeyEvent; page_step::Integer=10)
    handle!(state, _scroll_view(widget), event; page_step=page_step)
end

function handle!(state::ViewportState, widget::Viewport, event::MouseEvent, area::Rect; wheel_step::Integer=3)
    handle!(state, _scroll_view(widget), event, area; wheel_step=wheel_step)
end

SemanticToolkit.widget_semantic_descriptor(widget::Viewport, state::ViewportState) =
    SemanticToolkit.widget_semantic_descriptor(_scroll_view(widget), state)

"""
Compatibility aliases for the broader feature-family names used by the spec and
survey matrix.

These aliases expose existing implementations under additional API names to support
upstream migration and cross-library porting. `Combobox`, `TransferList`, and
`ListBox` intentionally reuse existing immediate widgets and state types; the
names are stable as compatibility shims until dedicated widgets are introduced.
"""
const RadioButton = RadioGroup
const RadioButtonState = RadioGroupState
const ListBox = List
const ListBoxState = ListState
const Combobox = Select
const ComboboxState = SelectState
const TransferList = MultiSelect
const TransferListState = MultiSelectState

"""Dedicated link adapter with the action semantics and styling of `Button`."""
struct Link{T}
    button::Button{T}
end

Link(label::AbstractString, target=nothing; kwargs...) = Link(Button(label, target; kwargs...))
state_for(::Link) = LinkState()
function _link_label(widget::Link)
    return join(span.content for span in widget.button.label.spans)
end
function render!(buffer::Buffer, widget::Link, area::Rect, state::LinkState)
    style = widget.button.disabled ? Style(modifiers=DIM) :
            state.focused || state.pressed ? widget.button.focused_style : widget.button.style
    return render!(buffer, Label(_link_label(widget); style), area)
end
render!(buffer::Buffer, widget::Link, area::Rect) = render!(buffer, widget, area, LinkState())
measure(widget::Link, available::Rect) = Size(min(available.height, 1), min(available.width, text_width(_link_label(widget))))
function handle!(state::LinkState, widget::Link, event::KeyEvent)
    widget.button.disabled && return false
    event.kind in (KeyPress, KeyRepeat) || return false
    return event.key.code == :enter ||
           (event.key.code == :character && event.text == " ")
end

function handle!(state::LinkState, widget::Link, event::MouseEvent, area::Rect)
    if widget.button.disabled
        changed = state.hovered || state.pressed
        state.hovered = false
        state.pressed = false
        return changed
    end

    inside = contains(area, event.position)
    if event.action == MouseMove
        changed = state.hovered != inside
        state.hovered = inside
        return changed
    elseif event.button == LeftMouseButton && event.action == MousePress
        state.pressed = inside
        state.hovered = inside
        return inside
    elseif event.button == LeftMouseButton && event.action == MouseRelease
        activated = state.pressed && inside
        state.pressed = false
        state.hovered = inside
        return activated
    end
    return false
end

activate(widget::Link, ::LinkState=LinkState()) =
    widget.button.disabled ? nothing : widget.button.message

function SemanticToolkit.widget_semantic_descriptor(widget::Link, state::LinkState)
    enabled = !widget.button.disabled
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.LinkRole;
        label=_link_label(widget),
        state=Accessibility.SemanticState(
            enabled=enabled,
            focusable=enabled,
            focused=state.focused,
        ),
        actions=enabled ? Accessibility.SemanticAction[
            Accessibility.ActivateSemanticAction,
            Accessibility.FocusSemanticAction,
        ] : Accessibility.SemanticAction[],
        metadata=Dict{Symbol,Any}(:target => widget.button.message),
    )
end

function link_semantic_node(
    widget::Link,
    state::LinkState;
    id="link",
    bounds::Union{Nothing,Accessibility.SemanticRect}=nothing,
)
    descriptor = SemanticToolkit.widget_semantic_descriptor(widget, state)
    return Accessibility.SemanticNode(
        id,
        descriptor.role;
        label=descriptor.label,
        bounds,
        state=descriptor.state,
        actions=descriptor.actions,
        metadata=descriptor.metadata,
    )
end

"""
Dedicated split-button API shape implemented as an explicit action adapter.
"""
struct MenuButton{T}
    button::Button{T}
end

MenuButton(label, message=nothing; kwargs...) = MenuButton(Button(label, message; kwargs...))
state_for(::MenuButton) = ButtonState()

render!(buffer::Buffer, widget::MenuButton, area::Rect, state::ButtonState) =
    render!(buffer, widget.button, area, state)
handle!(state::ButtonState, widget::MenuButton, event::KeyEvent) =
    handle!(state, widget.button, event)
handle!(state::ButtonState, widget::MenuButton, event::MouseEvent, area::Rect) =
    handle!(state, widget.button, event, area)
activate(widget::MenuButton, state::ButtonState) = activate(widget.button, state)

"""
Dedicated split-button API shape implemented as an explicit action adapter.
"""
const MenuButtonState = ButtonState

SemanticToolkit.widget_semantic_descriptor(widget::MenuButton, state::MenuButtonState) =
    SemanticToolkit.widget_semantic_descriptor(widget.button, state)

"""
Dedicated menu bar action container.
"""
struct MenuBar{T<:Tuple}
    row::Row{T}
end

MenuBar(children...; constraints=nothing, margin::Margin=Margin(0), gap::Integer=0, alignment::FlexAlignment=StartFlex) =
    MenuBar(Row(children; constraints=constraints, margin=margin, gap=gap, alignment=alignment))

render!(buffer::Buffer, widget::MenuBar, area::Rect) = render!(buffer, widget.row, area)
measure(widget::MenuBar, available::Rect) = measure(widget.row, available)
SemanticToolkit.widget_semantic_descriptor(::MenuBar, state) = _static_group_semantics("Menu bar")

"""
Dedicated split-action API shape implemented as a dedicated action adapter.
"""
struct SplitButton{T}
    button::Button{T}
    split_indicator::String
end

SplitButton(label, message=nothing; split_indicator::AbstractString=" ▼", kwargs...) =
    SplitButton(Button(label, message; kwargs...), String(split_indicator))
SplitButton(button::Button; split_indicator::AbstractString=" ▼") =
    SplitButton(button, String(split_indicator))
state_for(::SplitButton) = ButtonState()

render!(buffer::Buffer, widget::SplitButton, area::Rect, state::ButtonState) =
    render!(buffer, widget.button, area, state)
handle!(state::ButtonState, widget::SplitButton, event::KeyEvent) =
    handle!(state, widget.button, event)
handle!(state::ButtonState, widget::SplitButton, event::MouseEvent, area::Rect) =
    handle!(state, widget.button, event, area)
activate(widget::SplitButton, state::ButtonState) = activate(widget.button, state)

"""
Dedicated split-button state is intentionally shared with `ButtonState`.
"""
const SplitButtonState = ButtonState

SemanticToolkit.widget_semantic_descriptor(widget::SplitButton, state::SplitButtonState) =
    SemanticToolkit.widget_semantic_descriptor(widget.button, state)
"""
Dedicated toolbar action container.
"""
struct Toolbar{T<:Tuple}
    row::Row{T}
end

Toolbar(children...; constraints=nothing, margin::Margin=Margin(0), gap::Integer=0, alignment::FlexAlignment=StartFlex) =
    Toolbar(Row(children; constraints=constraints, margin=margin, gap=gap, alignment=alignment))

render!(buffer::Buffer, widget::Toolbar, area::Rect) = render!(buffer, widget.row, area)
measure(widget::Toolbar, available::Rect) = measure(widget.row, available)
SemanticToolkit.widget_semantic_descriptor(::Toolbar, state) = _static_group_semantics("Toolbar")

"""
Dedicated horizontal shortcut bar for key/composition hints.
"""
struct ShortcutBar
    hints::Vector{KeyHint}
    separator::String
    key_style::Style
    description_style::Style
end

ShortcutBar(
    hints;
    separator::AbstractString="  ",
    key_style::Style=Style(modifiers=REVERSED),
    description_style::Style=Style(),
) = ShortcutBar(KeyHint[hint isa KeyHint ? hint : KeyHint(first(hint), last(hint)) for hint in hints], String(separator), key_style, description_style)

function measure(widget::ShortcutBar, available::Rect)
    total_width = 0
    for (index, hint) in enumerate(widget.hints)
        index > 1 && (total_width += text_width(widget.separator))
        total_width += text_width(" " * hint.key * " ")
        total_width += text_width(" " * hint.description)
    end
    return Size(1, min(available.width, max(0, total_width)))
end

function render!(buffer::Buffer, widget::ShortcutBar, area::Rect)
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

SemanticToolkit.widget_semantic_descriptor(widget::ShortcutBar, state) =
    _static_group_semantics("Keyboard shortcuts"; metadata=Dict(:hint_count => length(widget.hints)))

"""
Dedicated navigation tab container with selectable content regions.
"""
struct TabView{T}
    tabs::Tabs
    views::Vector{T}
    block::Union{Nothing,Block}
    body_block::Union{Nothing,Block}
end

mutable struct TabViewState
    selected::Int
    function TabViewState(selected::Integer=1)
        selected >= 1 || throw(ArgumentError("tab selection must be positive"))
        new(Int(selected))
    end
end

function TabView(
    tabs,
    views;
    divider::AbstractString=" │ ",
    style::Style=Style(),
    selected_style::Style=Style(modifiers=REVERSED | BOLD),
    block::Union{Nothing,Block}=nothing,
    body_block::Union{Nothing,Block}=nothing,
)
    resolved_tabs = [
        tab isa Tab ? tab : Tab(first(tab), last(tab)) for tab in tabs
    ]
    tab_count = length(resolved_tabs)
    tab_count == length(views) || throw(
        DimensionMismatch("tab count must match view count")
    )
    TabView(
        Tabs(resolved_tabs; divider, style, selected_style),
        collect(Any, views),
        block,
        body_block,
    )
end

state_for(::TabView) = TabViewState()

function measure(widget::TabView, available::Rect)
    isempty(available) && return Size(0, 0)
    tab_size = measure(widget.tabs, available)
    if isempty(widget.views)
        return Size(
            min(available.height, tab_size.height),
            min(available.width, tab_size.width),
        )
    end
    body_area = Rect(
        available.row + tab_size.height,
        available.column,
        max(0, available.height - tab_size.height),
        available.width,
    )
    first_view = measure(widget.views[1], body_area)
    return Size(
        min(
            available.height,
            tab_size.height + first_view.height,
        ),
        min(
            available.width,
            max(tab_size.width, first_view.width),
        ),
    )
end

render!(buffer::Buffer, widget::TabView, area::Rect) =
    render!(buffer, widget, area, TabViewState())

function render!(buffer::Buffer, widget::TabView, area::Rect, state::TabViewState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    tab_area = Rect(active.row, active.column, min(active.height, 1), active.width)
    render!(buffer, widget.tabs, tab_area, TabsState(state.selected))
    index = clamp(state.selected, 1, max(1, length(widget.views)))
    body_area = Rect(
        tab_area.row + tab_area.height,
        active.column,
        max(0, active.height - tab_area.height),
        active.width,
    )
    isempty(widget.views) || isempty(body_area) && return buffer
    selected_view = widget.views[index]
    if widget.body_block === nothing
        render!(buffer, selected_view, body_area)
    else
        render!(buffer, widget.body_block, body_area)
        render!(buffer, selected_view, inner(widget.body_block, body_area))
    end
    return buffer
end

function handle!(state::TabViewState, widget::TabView, event::KeyEvent)
    tabs_state = TabsState(state.selected)
    changed = handle!(tabs_state, widget.tabs, event)
    state.selected = tabs_state.selected
    return changed
end

function handle!(state::TabViewState, widget::TabView, event::MouseEvent, area::Rect)
    active = area
    isempty(active) && return false
    tab_state = TabsState(state.selected)
    if handle!(tab_state, widget.tabs, event, Rect(active.row, active.column, min(active.height, 1), active.width))
        state.selected = tab_state.selected
        return true
    end
    return false
end

function SemanticToolkit.widget_semantic_descriptor(::TabView, ::TabViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TabListRole;
        label="Tabs",
        state=Accessibility.SemanticState(focusable=true),
        actions=[Accessibility.FocusSemanticAction],
    )
end

function SemanticToolkit.widget_semantic_children(widget::TabView, state::TabViewState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(index)",
            Accessibility.TabRole;
            label=join(span.content for span in tab.title.spans),
            state=Accessibility.SemanticState(selected=state.selected == index),
            actions=[Accessibility.SelectSemanticAction],
            metadata=Dict(:tab_id => tab.id),
        ) for (index, tab) in enumerate(widget.tabs.tabs)
    ]
end

"""
Dedicated context menu adapter over existing immediate menu behavior.
"""
struct ContextMenu
    menu::Menu
end

ContextMenu(items::AbstractVector; kwargs...) = ContextMenu(Menu(items; kwargs...))

const ContextMenuState = MenuState

state_for(widget::ContextMenu) = MenuState()
render!(buffer::Buffer, widget::ContextMenu, area::Rect, state::ContextMenuState) =
    render!(buffer, widget.menu, area, state)
handle!(state::ContextMenuState, widget::ContextMenu, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.menu, event; viewport_height)
handle!(state::ContextMenuState, widget::ContextMenu, event::MouseEvent, area::Rect) =
    handle!(state, widget.menu, event, area)
activate(widget::ContextMenu, state::ContextMenuState) = activate(widget.menu, state)

SemanticToolkit.widget_semantic_descriptor(widget::ContextMenu, state::ContextMenuState) =
    SemanticToolkit.widget_semantic_descriptor(widget.menu, state)

SemanticToolkit.widget_semantic_children(widget::ContextMenu, state::ContextMenuState, id) =
    SemanticToolkit.widget_semantic_children(widget.menu, state, id)

"""
Dedicated sidebar adapter with fixed-size primary slot.
"""
struct Sidebar{S,C}
    sidebar::S
    content::C
    sidebar_size::Int
    side::Symbol
    gap::Int
    block::Union{Nothing,Block}
end

function Sidebar(
    sidebar,
    content;
    sidebar_size::Integer=24,
    side::Symbol=:left,
    gap::Integer=0,
    block::Union{Nothing,Block}=nothing,
)
    side in (:left, :right, :top, :bottom) ||
        throw(ArgumentError("sidebar side must be :left, :right, :top, or :bottom"))
    Sidebar(sidebar, content, max(0, Int(sidebar_size)), side, Int(gap), block)
end

function measure(widget::Sidebar, available::Rect)
    isempty(available) && return Size(0, 0)
    sidebar_area, body_area = _sidebar_regions(widget, available)
    sidebar_size = measure(widget.sidebar, sidebar_area)
    body_size = isempty(body_area) ? Size(0, 0) : measure(widget.content, body_area)

    return if widget.side in (:left, :right)
        Size(
            min(available.height, max(sidebar_size.height, body_size.height)),
            min(
                available.width,
                sidebar_area.width + (isempty(body_area) ? 0 : (widget.gap + body_size.width)),
            ),
        )
    else
        Size(
            min(
                available.height,
                sidebar_area.height + (isempty(body_area) ? 0 : (widget.gap + body_size.height)),
            ),
            min(available.width, max(sidebar_size.width, body_size.width)),
        )
    end
end

function _sidebar_regions(widget::Sidebar, available::Rect)
    available_width = max(0, available.width)
    available_height = max(0, available.height)

    if widget.side in (:left, :right)
        sidebar_width = min(widget.sidebar_size, available_width)
        gap = min(widget.gap, available_width)
        body_width = max(0, available_width - sidebar_width - gap)
        if widget.side == :left
            sidebar_area = Rect(available.row, available.column, available_height, sidebar_width)
            body_area = Rect(
                available.row,
                available.column + sidebar_width + gap,
                available_height,
                body_width,
            )
        else
            sidebar_area = Rect(
                available.row,
                available.column + max(0, available_width - sidebar_width),
                available_height,
                sidebar_width,
            )
            body_area = Rect(available.row, available.column, available_height, body_width)
        end
        return sidebar_area, body_area
    end

    sidebar_height = min(widget.sidebar_size, available_height)
    gap = min(widget.gap, available_height)
    body_height = max(0, available_height - sidebar_height - gap)
    if widget.side == :top
        sidebar_area = Rect(available.row, available.column, sidebar_height, available_width)
        body_area = Rect(
            available.row + sidebar_height + gap,
            available.column,
            body_height,
            available_width,
        )
    else
        sidebar_area = Rect(
            available.row + max(0, available_height - sidebar_height),
            available.column,
            sidebar_height,
            available_width,
        )
        body_area = Rect(available.row, available.column, body_height, available_width)
    end
    return sidebar_area, body_area
end

function render!(buffer::Buffer, widget::Sidebar, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    sidebar_area, body_area = _sidebar_regions(widget, active)
    if widget.block === nothing
        render!(buffer, widget.sidebar, sidebar_area)
        !isempty(body_area) && render!(buffer, widget.content, body_area)
    else
        render!(buffer, widget.block, active)
        active = inner(widget.block, active)
        render!(buffer, widget.sidebar, intersection(sidebar_area, active))
        isempty(body_area) || render!(buffer, widget.content, intersection(body_area, active))
    end
    return buffer
end

SemanticToolkit.widget_semantic_descriptor(widget::Sidebar, state) =
    _static_group_semantics("Sidebar layout"; metadata=Dict(:side => widget.side, :sidebar_size => widget.sidebar_size, :gap => widget.gap))

"""
Dedicated navigation rail adapter for vertical menus.
"""
struct NavigationRail
    menu::Menu
end

NavigationRail(items::AbstractVector; kwargs...) = NavigationRail(Menu(items; kwargs...))
const NavigationRailState = MenuState
state_for(widget::NavigationRail) = MenuState()
render!(buffer::Buffer, widget::NavigationRail, area::Rect, state::NavigationRailState) =
    render!(buffer, widget.menu, area, state)
handle!(state::NavigationRailState, widget::NavigationRail, event::KeyEvent; viewport_height::Integer=1) =
    handle!(state, widget.menu, event; viewport_height)
handle!(state::NavigationRailState, widget::NavigationRail, event::MouseEvent, area::Rect) =
    handle!(state, widget.menu, event, area)
activate(widget::NavigationRail, state::NavigationRailState) = activate(widget.menu, state)

SemanticToolkit.widget_semantic_descriptor(widget::NavigationRail, state::NavigationRailState) =
    SemanticToolkit.widget_semantic_descriptor(widget.menu, state)

SemanticToolkit.widget_semantic_children(widget::NavigationRail, state::NavigationRailState, id) =
    SemanticToolkit.widget_semantic_children(widget.menu, state, id)

"""
Flow-style container that wraps children to the next line when needed.

`Flow` delegates all wrapping decisions to the existing layout `flow` helper and
keeps each child independently renderable.
"""
struct Flow{T<:Tuple}
    children::T
    column_gap::Int
    row_gap::Int
    function Flow(children::Tuple, column_gap::Integer, row_gap::Integer)
        column_gap >= 0 || throw(ArgumentError("column gap must be non-negative"))
        row_gap >= 0 || throw(ArgumentError("row gap must be non-negative"))
        new{typeof(children)}(children, Int(column_gap), Int(row_gap))
    end
end

Flow(children...; column_gap::Integer=0, row_gap::Integer=0) =
    Flow(children, column_gap, row_gap)

function _flow_regions(area::Rect, children, column_gap::Int, row_gap::Int)
    sizes = [measure(child, area) for child in children]
    isempty(sizes) && return Rect[]
    return flow(area, sizes; column_gap=column_gap, row_gap=row_gap)
end

function measure(widget::Flow, available::Rect)
    regions = _flow_regions(available, widget.children, widget.column_gap, widget.row_gap)
    isempty(regions) && return Size(0, 0)
    max_row = maximum(region.row + region.height for region in regions)
    max_col = maximum(region.column + region.width for region in regions)
    return Size(
        min(available.height, max_row - available.row),
        min(available.width, max_col - available.column),
    )
end

function render!(buffer::Buffer, widget::Flow, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    regions = _flow_regions(active, widget.children, widget.column_gap, widget.row_gap)
    for (index, region) in enumerate(regions)
        render!(buffer, widget.children[index], region)
    end
    return buffer
end

SemanticToolkit.widget_semantic_descriptor(::Flow, state) = _static_group_semantics("Flow layout")

"""
Alias-style flow container with explicit wrapped-line intent.
"""
const Wrap = Flow

"""
Container that lays out two children in primary and secondary regions.
"""
struct SplitPane{A,B}
    first::A
    second::B
    first_fraction::UInt16
    orientation::SplitOrientation
    gap::Int
    margin::Margin
end

function SplitPane(
    first,
    second;
    fraction::Real=0.5,
    orientation::SplitOrientation=HorizontalSplit,
    gap::Integer=0,
    margin::Margin=Margin(0),
)
    0 <= fraction <= 1 || throw(ArgumentError("split fraction must be between 0 and 1"))
    gap >= 0 || throw(ArgumentError("split pane gap must be non-negative"))
    scaled = clamp(Int(round(fraction * 1000)), 0, 1000)
    SplitPane(first, second, UInt16(scaled), orientation, Int(gap), margin)
end

function _splitpane_regions(
    widget::SplitPane,
    area::Rect,
)
    first_fraction = Float64(widget.first_fraction) / 1000
    second_fraction = 1.0 - first_fraction
    first_constraint = Ratio(clamp(round(Int, first_fraction * 1000), 0, 1000), 1000)
    second_constraint = Ratio(clamp(round(Int, second_fraction * 1000), 0, 1000), 1000)
    layout = if widget.orientation == HorizontalSplit
        FlexLayout(HorizontalLayout, [first_constraint, second_constraint]; margin=widget.margin, gap=widget.gap)
    else
        FlexLayout(VerticalLayout, [first_constraint, second_constraint]; margin=widget.margin, gap=widget.gap)
    end
    return resolve(layout, area)
end

measure(widget::SplitPane, available::Rect) = begin
    regions = _splitpane_regions(widget, available)
    isempty(regions) && return Size(0, 0)
    first = measure(widget.first, regions[1])
    second = measure(widget.second, regions[2])
    widths = [regions[1].column + first.width - available.column, regions[2].column + second.width - available.column]
    heights = [regions[1].row + first.height - available.row, regions[2].row + second.height - available.row]
    Size(min(available.height, max(heights...)), min(available.width, max(widths...)))
end

function render!(buffer::Buffer, widget::SplitPane, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    regions = _splitpane_regions(widget, active)
    render!(buffer, widget.first, regions[1])
    render!(buffer, widget.second, regions[2])
    return buffer
end

SemanticToolkit.widget_semantic_descriptor(widget::SplitPane, state) =
    _static_group_semantics("Split pane"; metadata=Dict(:orientation => widget.orientation, :fraction => Float64(widget.first_fraction) / 1000, :gap => widget.gap))

"""
Stateful resizable split pane built on explicit fractional control.
"""
const ResizablePaneState = SplitPaneState

struct ResizablePane{A,B}
    first::A
    second::B
    fraction::Float64
    orientation::SplitOrientation
    gap::Int
    margin::Margin
    minimum_first::Int
    minimum_second::Int
    handle_style::Style
    handle_size::Int
end

function ResizablePane(
    first,
    second;
    fraction::Real=0.5,
    orientation::SplitOrientation=HorizontalSplit,
    gap::Integer=0,
    margin::Margin=Margin(0),
    minimum_first::Integer=0,
    minimum_second::Integer=0,
    handle_style::Style=Style(foreground=AnsiColor(8)),
    handle_size::Integer=1,
)
    0 <= fraction <= 1 || throw(ArgumentError("split fraction must be between 0 and 1"))
    minimum_first >= 0 || throw(ArgumentError("minimum_first must be non-negative"))
    minimum_second >= 0 || throw(ArgumentError("minimum_second must be non-negative"))
    gap >= 0 || throw(ArgumentError("split pane gap must be non-negative"))
    ResizablePane(
        first,
        second,
        Float64(fraction),
        orientation,
        Int(gap),
        margin,
        Int(minimum_first),
        Int(minimum_second),
        handle_style,
        max(Int(handle_size), 0),
    )
end

state_for(widget::ResizablePane) = SplitPaneState(
    fraction=widget.fraction,
    minimum_first=widget.minimum_first,
    minimum_second=widget.minimum_second,
    orientation=widget.orientation,
    disabled=widget.handle_size <= 0 || widget.gap < 0,
)

function measure(widget::ResizablePane, available::Rect)
    state = state_for(widget)
    regions = split_pane_regions(
        state,
        ComponentRect(available.row, available.column, available.width, available.height);
        handle_size=widget.handle_size,
    )
    first = measure(widget.first, Rect(regions[1].row, regions[1].column, regions[1].height, regions[1].width))
    second = measure(widget.second, Rect(regions[2].row, regions[2].column, regions[2].height, regions[2].width))
    return Size(
        min(available.height, max(regions[1].row + first.height, regions[2].row + second.height) - available.row),
        min(available.width, max(regions[1].column + first.width, regions[2].column + second.width) - available.column),
    )
end

function _rect_from_component(region::ComponentRect)
    Rect(region.row, region.column, region.height, region.width)
end

function render!(buffer::Buffer, widget::ResizablePane, area::Rect, state::ResizablePaneState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    first_rect, handle_rect, second_rect = split_pane_regions(
        state,
        ComponentRect(active.row, active.column, active.width, active.height);
        handle_size=widget.handle_size,
    )
    render!(buffer, widget.first, _rect_from_component(first_rect))
    render!(buffer, widget.second, _rect_from_component(second_rect))
    if widget.handle_size > 0
        handle_area = _rect_from_component(handle_rect)
        fill!(buffer, handle_area, Cell(widget.orientation == HorizontalSplit ? "┃" : "━"; style=widget.handle_style))
    end
    return buffer
end

function handle!(state::ResizablePaneState, widget::ResizablePane, event::MouseEvent, area::Rect)
    widget.handle_size > 0 || return false
    event.action in (MousePress, MouseDrag, MouseMove) || return false
    event.button == LeftMouseButton || return false
    active = area
    contains(active, event.position) || return false
    regions = split_pane_regions(
        state,
        ComponentRect(active.row, active.column, active.width, active.height);
        handle_size=widget.handle_size,
    )
    handle_area = intersection(active, _rect_from_component(regions[2]))
    event.action == MouseDrag ||
        (handle_area.width > 0 && handle_area.height > 0 && contains(handle_area, event.position)) || return false
    total = widget.orientation == HorizontalSplit ? active.width : active.height
    total > widget.handle_size || return false
    if widget.orientation == HorizontalSplit
        pointer = event.position.column
        offset = active.column
    else
        pointer = event.position.row
        offset = active.row
    end
    set_split_fraction!(state, clamp((pointer - offset) / max(total, 1), 0.0, 1.0))
    return true
end

function SemanticToolkit.widget_semantic_descriptor(widget::ResizablePane, state::ResizablePaneState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.SliderRole;
        label="Resizable pane divider",
        state=Accessibility.SemanticState(
            focusable=true,
            value_now=state.fraction,
            value_min=0.0,
            value_max=1.0,
        ),
        actions=[Accessibility.FocusSemanticAction, Accessibility.SetValueSemanticAction],
        metadata=Dict(:orientation => widget.orientation, :minimum_first => state.minimum_first, :minimum_second => state.minimum_second),
    )
end

"""
Container that combines edge docks and a center region.
"""
struct DockLayout
    top::Any
    right::Any
    bottom::Any
    left::Any
    center::Any
    top_size::Int
    right_size::Int
    bottom_size::Int
    left_size::Int
    margin::Margin
end

function DockLayout(;
    top=nothing,
    right=nothing,
    bottom=nothing,
    left=nothing,
    center=nothing,
    top_size::Integer=0,
    right_size::Integer=0,
    bottom_size::Integer=0,
    left_size::Integer=0,
    margin::Margin=Margin(0),
)
    top_size >= 0 || throw(ArgumentError("top dock size must be non-negative"))
    right_size >= 0 || throw(ArgumentError("right dock size must be non-negative"))
    bottom_size >= 0 || throw(ArgumentError("bottom dock size must be non-negative"))
    left_size >= 0 || throw(ArgumentError("left dock size must be non-negative"))
    DockLayout(
        top,
        right,
        bottom,
        left,
        center,
        Int(top_size),
        Int(right_size),
        Int(bottom_size),
        Int(left_size),
        margin,
    )
end

const Dock = DockLayout

function _dock_children_and_items(widget::DockLayout)
    children = Any[]
    items = DockItem[]
    if widget.top !== nothing
        push!(children, widget.top)
        push!(items, DockItem(DockTop, widget.top_size))
    end
    if widget.right !== nothing
        push!(children, widget.right)
        push!(items, DockItem(DockRight, widget.right_size))
    end
    if widget.bottom !== nothing
        push!(children, widget.bottom)
        push!(items, DockItem(DockBottom, widget.bottom_size))
    end
    if widget.left !== nothing
        push!(children, widget.left)
        push!(items, DockItem(DockLeft, widget.left_size))
    end
    return children, items
end

function _dock_regions(widget::DockLayout, area::Rect)
    working_area = inset(area, widget.margin)
    children, items = _dock_children_and_items(widget)
    dock_regions, remaining = dock(working_area, items)
    return children, dock_regions, remaining
end

measure(widget::DockLayout, available::Rect) = begin
    children, dock_regions, remaining = _dock_regions(widget, available)
    max_row = available.row
    max_col = available.column
    for (child, region) in zip(children, dock_regions)
        size = measure(child, region)
        max_row = max(max_row, region.row + size.height)
        max_col = max(max_col, region.column + size.width)
    end
    if widget.center !== nothing
        size = measure(widget.center, remaining)
        max_row = max(max_row, remaining.row + size.height)
        max_col = max(max_col, remaining.column + size.width)
    end
    Size(min(available.height, max_row - available.row), min(available.width, max_col - available.column))
end

SemanticToolkit.widget_semantic_descriptor(widget::DockLayout, state) =
    _static_group_semantics("Dock layout"; metadata=Dict(
        :top_size => widget.top_size,
        :right_size => widget.right_size,
        :bottom_size => widget.bottom_size,
        :left_size => widget.left_size,
    ))

function render!(buffer::Buffer, widget::DockLayout, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    children, dock_regions, remaining = _dock_regions(widget, active)
    for (child, region) in zip(children, dock_regions)
        render!(buffer, child, region)
    end
    widget.center === nothing || render!(buffer, widget.center, remaining)
    return buffer
end

"""
Dedicated status message widget.

`Status` follows the same rendering structure as `Alert` so existing alert styling
and focus requirements remain consistent while exposing a first-class API name for
application messages.
"""
struct Status
    alert::Alert

    function Status(alert::Alert)
        return new(alert)
    end
end

"""
Construct a status widget from plain message text.
"""
Status(message::AbstractString; title::AbstractString="Status", severity::Symbol=:info) =
    Status(Alert(message; title=title, severity=severity))

render!(buffer::Buffer, widget::Status, area::Rect) = render!(buffer, widget.alert, area)

SemanticToolkit.widget_semantic_descriptor(widget::Status, state) =
    _static_group_semantics("Status"; metadata=Dict(:severity => widget.alert.severity))

"""
Dedicated toast notification widget.

`Toast` wraps the existing notification model and renders through a compact,
single-item notification surface suitable for transient transient UI feedback.
"""
struct Toast
    notification::Notification

    function Toast(notification::Notification)
        return new(notification)
    end
end

"""
Construct a toast widget from plain message text.
"""
Toast(message::AbstractString; title::AbstractString="", severity::Symbol=:info, timeout::Union{Nothing,Real}=5.0) =
    Toast(Notification(message; title=title, severity=severity, timeout=timeout))

function render!(buffer::Buffer, widget::Toast, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    color = widget.notification.severity == :error ? AnsiColor(1) :
            widget.notification.severity == :warning ? AnsiColor(3) :
            widget.notification.severity == :success ? AnsiColor(2) : AnsiColor(4)
    prefix = isempty(widget.notification.title) ? "" : widget.notification.title * ": "
    render!(buffer, Label(prefix * widget.notification.message; style=Style(foreground=color)), active)
    return buffer
end

SemanticToolkit.widget_semantic_descriptor(widget::Toast, state) =
    _static_group_semantics("Toast"; metadata=Dict(:severity => widget.notification.severity, :timeout => widget.notification.timeout))

const StatusBar = Footer
const TitleBar = Header

"""
File picker compatibility widget.

`FilePicker` provides a stable entrypoint for file-system navigation and selection
using the existing `FileBrowser` state and input behavior.
"""
const FilePickerState = FileBrowserState

"""
Immediate-mode file picker widget configuration.

Render and interaction delegate to the existing `FileBrowser` core behavior:
`render_file_browser`, `handle_file_browser_key!`, and `handle_file_browser_pointer!`.
"""
struct FilePicker
    path::String
    root::String
    width::Int
    height::Int
    first_entry::Int
    bindings::FileBrowserBindings
    focus_on_hover::Bool
    select_on_press::Bool
    mode::FilePickerMode
    show_hidden::Bool
    follow_symlinks::Bool
    directories_first::Bool
    sort_field::FileSortField
    sort_direction::FileSortDirection
    filter::Union{Nothing,String,Regex}
    maximum_entries::Int
end

function FilePicker(
    path::AbstractString=pwd();
    root::AbstractString=path,
    width::Integer=80,
    height::Integer=24,
    first_entry::Integer=1,
    bindings::FileBrowserBindings=default_file_browser_bindings(),
    focus_on_hover::Bool=true,
    select_on_press::Bool=true,
    vim::Bool=false,
    mode::FilePickerMode=SelectFileMode,
    show_hidden::Bool=false,
    follow_symlinks::Bool=false,
    directories_first::Bool=true,
    sort_field::FileSortField=FileNameSort,
    sort_direction::FileSortDirection=AscendingFileSort,
    filter::Union{Nothing,AbstractString,Regex}=nothing,
    maximum_entries::Integer=100_000,
)
    width >= 0 || throw(ArgumentError("file picker width must be non-negative"))
    height >= 0 || throw(ArgumentError("file picker height must be non-negative"))
    first_entry > 0 || throw(ArgumentError("file picker first_entry must be positive"))
    maximum_entries >= 0 || throw(ArgumentError("maximum_entries must be non-negative"))
    maximum_entries <= typemax(Int) || throw(ArgumentError("maximum_entries is too large"))
    effective_bindings = vim ? default_file_browser_bindings(vim=true) : bindings
    return FilePicker(
        String(path),
        String(root),
        Int(width),
        Int(height),
        Int(first_entry),
        effective_bindings,
        Bool(focus_on_hover),
        Bool(select_on_press),
        mode,
        Bool(show_hidden),
        Bool(follow_symlinks),
        Bool(directories_first),
        sort_field,
        sort_direction,
        isnothing(filter) ? nothing : (filter isa String ? String(filter) : filter),
        Int(maximum_entries),
    )
end

"""Build a default picker state for this widget configuration."""
state_for(widget::FilePicker) = FileBrowserState(
    widget.path;
    root=widget.root,
    mode=widget.mode,
    show_hidden=widget.show_hidden,
    follow_symlinks=widget.follow_symlinks,
    directories_first=widget.directories_first,
    sort_field=widget.sort_field,
    sort_direction=widget.sort_direction,
    filter=widget.filter,
    maximum_entries=widget.maximum_entries,
)

measure(widget::FilePicker, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::FilePicker, area::Rect, state::FilePickerState)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    lines = render_file_browser(
        state;
        width=min(active.width, widget.width),
        height=min(active.height, widget.height),
        first_entry=widget.first_entry,
    )
    rendered = rich_lines_to_core_text(CoreTextAdapter(), lines)
    return render!(buffer, Paragraph(rendered), active)
end

function handle!(state::FilePickerState, widget::FilePicker, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_file_browser_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
        viewport_height=max(1, min(widget.height, 24)),
    )
    return result.consumed
end

function handle!(
    state::FilePickerState,
    widget::FilePicker,
    event::MouseEvent,
    area::Rect,
)
    contains(area, event.position) || return false
    inside_row = event.position.row - area.row + 1
    inside_row < 1 && return false
    if event.action == MouseMove
        kind = FilePointerHover
    elseif event.button != LeftMouseButton
        return false
    elseif event.action == MousePress && event.click_count > 1
        kind = FilePointerDoublePress
    elseif event.action == MousePress
        kind = FilePointerPress
    elseif event.action == MouseRelease && event.click_count > 1
        kind = FilePointerDoublePress
    else
        kind = FilePointerPress
    end
    result = handle_file_browser_pointer!(
        state,
        FilePointerEvent(
            kind,
            inside_row,
            1;
            control=in(CTRL, event.modifiers),
        );
        first_entry=widget.first_entry,
        focus_on_hover=widget.focus_on_hover,
        select_on_press=widget.select_on_press,
    )
    return result.consumed
end

function SemanticToolkit.widget_semantic_descriptor(::FilePicker, state::FilePickerState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TreeRole;
        label="File picker",
        state=Accessibility.SemanticState(focusable=true, busy=state.loading),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ScrollIntoViewSemanticAction],
        metadata=Dict(:path => state.current_path, :root => state.root, :generation => state.generation),
    )
end

function SemanticToolkit.widget_semantic_children(::FilePicker, state::FilePickerState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/entry-$(index)",
            Accessibility.TreeItemRole;
            label=entry.name,
            description=entry.kind == DirectoryFileEntry ? "directory" : "file",
            state=Accessibility.SemanticState(selected=entry.path in state.selected),
            actions=entry.kind == DirectoryFileEntry ? [Accessibility.SelectSemanticAction, Accessibility.ActivateSemanticAction, Accessibility.ExpandSemanticAction] : [Accessibility.SelectSemanticAction, Accessibility.ActivateSemanticAction],
            metadata=Dict(:path => entry.path, :kind => entry.kind),
        ) for (index, entry) in enumerate(state.entries)
    ]
end

"""
Compatibility date input widget.

`DateInput` is a stable-form adapter over `DatePickerState` for projects that
expect a direct date-entry widget in immediate-mode. Rendering and keyboard
interaction are delegated to `render_date_picker` and `handle_data_entry_key!`.
"""
const DateInputState = DatePickerState

struct DateInput
    selected::Dates.Date
    minimum::Union{Nothing,Dates.Date}
    maximum::Union{Nothing,Dates.Date}
    week_start::Int
    width::Int
    height::Int
    block::Union{Nothing,Block}
    bindings::DataEntryBindings
end

function DateInput(;
    selected::Dates.Date=Dates.Date(Dates.today()),
    minimum::Union{Nothing,Dates.Date}=nothing,
    maximum::Union{Nothing,Dates.Date}=nothing,
    week_start::Integer=1,
    width::Integer=28,
    height::Integer=7,
    block::Union{Nothing,Block}=nothing,
    bindings::DataEntryBindings=default_data_entry_bindings(),
)
    width >= 0 || throw(ArgumentError("date input width must be non-negative"))
    height >= 0 || throw(ArgumentError("date input height must be non-negative"))
    1 <= week_start <= 7 || throw(ArgumentError("week start must be between 1 and 7"))
    return DateInput(
        selected,
        minimum,
        maximum,
        Int(week_start),
        Int(width),
        Int(height),
        block,
        bindings,
    )
end

state_for(widget::DateInput) = DatePickerState(
    selected=widget.selected,
    minimum=widget.minimum,
    maximum=widget.maximum,
    week_start=widget.week_start,
)

function _data_input_active_area(buffer::Buffer, widget, area::Rect)
    if isnothing(widget.block)
        return intersection(buffer.area, area)
    end
    render!(buffer, widget.block, area)
    return intersection(buffer.area, inner(widget.block, area))
end

measure(widget::DateInput, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::DateInput, area::Rect, state::DateInputState)
    active = _data_input_active_area(buffer, widget, area)
    isempty(active) && return buffer
    clipped = Rect(active.row, active.column, min(active.height, widget.height), min(active.width, widget.width))
    isempty(clipped) && return buffer
    lines = render_date_picker(state; width=min(clipped.width, widget.width))
    rendered = rich_lines_to_core_text(CoreTextAdapter(), lines)
    render!(buffer, Paragraph(rendered), clipped)
    return buffer
end

function handle!(state::DateInputState, widget::DateInput, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_data_entry_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    )
    return result.consumed
end

handle!(::DateInputState, ::DateInput, ::PasteEvent) = false
function handle!(state::DateInputState, widget::DateInput, event::MouseEvent, area::Rect)
    event.action == MouseScroll && contains(area, event.position) || return false
    key = event.button == WheelUpButton ? :up : event.button == WheelDownButton ? :down : nothing
    key === nothing && return false
    return handle_data_entry_key!(state, widget.bindings, key).consumed
end

function SemanticToolkit.widget_semantic_descriptor(::DateInput, state::DateInputState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Date input",
        state=Accessibility.SemanticState(value=string(state.selected)),
        actions=[Accessibility.SetValueSemanticAction, Accessibility.IncrementSemanticAction, Accessibility.DecrementSemanticAction],
        metadata=Dict(:visible_month => state.visible_month),
    )
end

"""
Compatibility time input widget.

`TimeInput` adapts `TimePickerState` to the immediate-mode interface and keeps
keyboard behavior aligned with data-entry controls.
"""
const TimeInputState = TimePickerState

struct TimeInput
    value::Dates.Time
    minimum::Dates.Time
    maximum::Dates.Time
    step_seconds::Int
    width::Int
    height::Int
    block::Union{Nothing,Block}
    bindings::DataEntryBindings
end

function TimeInput(;
    value::Dates.Time=Dates.Time(0),
    minimum::Dates.Time=Dates.Time(0),
    maximum::Dates.Time=Dates.Time(23, 59, 59),
    step_seconds::Integer=60,
    width::Integer=16,
    height::Integer=1,
    block::Union{Nothing,Block}=nothing,
    bindings::DataEntryBindings=default_data_entry_bindings(),
)
    width >= 0 || throw(ArgumentError("time input width must be non-negative"))
    height >= 0 || throw(ArgumentError("time input height must be non-negative"))
    step_seconds >= 1 || throw(ArgumentError("step_seconds must be at least 1"))
    return TimeInput(
        value,
        minimum,
        maximum,
        Int(step_seconds),
        Int(width),
        Int(height),
        block,
        bindings,
    )
end

state_for(widget::TimeInput) = TimePickerState(
    value=widget.value,
    minimum=widget.minimum,
    maximum=widget.maximum,
    step_seconds=widget.step_seconds,
)

measure(widget::TimeInput, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::TimeInput, area::Rect, state::TimeInputState)
    active = _data_input_active_area(buffer, widget, area)
    isempty(active) && return buffer
    clipped = Rect(active.row, active.column, min(active.height, widget.height), min(active.width, widget.width))
    isempty(clipped) && return buffer
    lines = render_time_picker(state; width=min(clipped.width, widget.width))
    rendered = rich_lines_to_core_text(CoreTextAdapter(), [lines])
    render!(buffer, Paragraph(rendered), clipped)
    return buffer
end

function handle!(state::TimeInputState, widget::TimeInput, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    result = handle_data_entry_key!(
        state,
        widget.bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    )
    return result.consumed
end

handle!(::TimeInputState, ::TimeInput, ::PasteEvent) = false
function handle!(state::TimeInputState, widget::TimeInput, event::MouseEvent, area::Rect)
    event.action == MouseScroll && contains(area, event.position) || return false
    key = event.button == WheelUpButton ? :up : event.button == WheelDownButton ? :down : nothing
    key === nothing && return false
    return handle_data_entry_key!(state, widget.bindings, key).consumed
end

function SemanticToolkit.widget_semantic_descriptor(::TimeInput, state::TimeInputState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Time input",
        state=Accessibility.SemanticState(value=string(state.value)),
        actions=[Accessibility.SetValueSemanticAction, Accessibility.IncrementSemanticAction, Accessibility.DecrementSemanticAction],
        metadata=Dict(:minimum => state.minimum, :maximum => state.maximum, :step_seconds => state.step_seconds),
    )
end

"""
Compatibility datetime input widget.

`DateTimeInput` combines `DatePickerState` and `TimePickerState` for projects that
expect a direct datetime-entry control in immediate mode.
"""
mutable struct DateTimeInputState
    date::DatePickerState
    time::TimePickerState
    active::Bool
end

struct DateTimeInput
    selected::Dates.DateTime
    minimum::Union{Nothing,Dates.DateTime}
    maximum::Union{Nothing,Dates.DateTime}
    week_start::Int
    width::Int
    height::Int
    block::Union{Nothing,Block}
    date_bindings::DataEntryBindings
    time_bindings::DataEntryBindings
    step_seconds::Int
end

function DateTimeInput(
    selected::Dates.DateTime=Dates.now();
    minimum::Union{Nothing,Dates.DateTime}=nothing,
    maximum::Union{Nothing,Dates.DateTime}=nothing,
    week_start::Integer=1,
    width::Integer=28,
    height::Integer=8,
    block::Union{Nothing,Block}=nothing,
    date_bindings::DataEntryBindings=default_data_entry_bindings(),
    time_bindings::DataEntryBindings=default_data_entry_bindings(),
    step_seconds::Integer=60,
)
    width >= 0 || throw(ArgumentError("date-time input width must be non-negative"))
    height >= 0 || throw(ArgumentError("date-time input height must be non-negative"))
    1 <= week_start <= 7 || throw(ArgumentError("week start must be between 1 and 7"))
    step_seconds > 0 || throw(ArgumentError("step_seconds must be positive"))
    return DateTimeInput(
        selected,
        minimum,
        maximum,
        Int(week_start),
        Int(width),
        Int(height),
        block,
        date_bindings,
        time_bindings,
        Int(step_seconds),
    )
end

"""
Create a date-time state compatible with `DateTimeInput`.

The time bounds are automatically narrowed when the selected date matches
`minimum` or `maximum` to keep datetime values representable.
"""
function DateTimeInputState(
    selected::Dates.DateTime=Dates.now();
    minimum::Union{Nothing,Dates.DateTime}=nothing,
    maximum::Union{Nothing,Dates.DateTime}=nothing,
    week_start::Integer=1,
    step_seconds::Integer=60,
)
    minimum === nothing || maximum === nothing || minimum <= maximum ||
        throw(ArgumentError("date-time minimum must not exceed maximum"))
    1 <= week_start <= 7 || throw(ArgumentError("week start must be between 1 and 7"))
    clamped = selected
    minimum === nothing || (clamped = max(clamped, minimum))
    maximum === nothing || (clamped = min(clamped, maximum))
    date = DatePickerState(
        selected=Dates.Date(clamped),
        minimum=minimum === nothing ? nothing : Dates.Date(minimum),
        maximum=maximum === nothing ? nothing : Dates.Date(maximum),
        week_start=week_start,
    )
    minimum_time = _datetime_input_minimum_time(minimum, date)
    maximum_time = _datetime_input_maximum_time(maximum, date)
    time = TimePickerState(
        value=Dates.Time(clamped),
        minimum=minimum_time,
        maximum=maximum_time,
        step_seconds=step_seconds,
    )
    return DateTimeInputState(date, time, true)
end

function _datetime_input_minimum_time(
    minimum::Union{Nothing,Dates.DateTime},
    date_state::DatePickerState,
)
    minimum === nothing && return Dates.Time(0)
    Dates.Date(minimum) == date_state.selected ? Dates.Time(minimum) : Dates.Time(0)
end

function _datetime_input_maximum_time(
    maximum::Union{Nothing,Dates.DateTime},
    date_state::DatePickerState,
)
    maximum === nothing && return Dates.Time(23, 59, 59)
    Dates.Date(maximum) == date_state.selected ? Dates.Time(maximum) : Dates.Time(23, 59, 59)
end

function _datetime_input_sync_time_bounds!(
    state::DateTimeInputState,
    minimum::Union{Nothing,Dates.DateTime},
    maximum::Union{Nothing,Dates.DateTime},
)
    minimum_time = _datetime_input_minimum_time(minimum, state.date)
    maximum_time = _datetime_input_maximum_time(maximum, state.date)
    state.time.minimum = minimum_time
    state.time.maximum = maximum_time
    set_time_picker!(state.time, state.time.value)
    return state
end

state_for(widget::DateTimeInput) = DateTimeInputState(
    Dates.DateTime(widget.selected);
    minimum=widget.minimum,
    maximum=widget.maximum,
    week_start=widget.week_start,
    step_seconds=widget.step_seconds,
)

measure(widget::DateTimeInput, available::Rect) =
    Size(min(available.height, widget.height), min(available.width, widget.width))

function _render_datetime_lines(state::DateTimeInputState, width::Int)
    width = max(1, width)
    lines = render_date_picker(state.date; width=width)
    push!(lines, render_time_picker(state.time; width=width))
    return lines
end

function render!(buffer::Buffer, widget::DateTimeInput, area::Rect, state::DateTimeInputState)
    active = _data_input_active_area(buffer, widget, area)
    isempty(active) && return buffer
    clipped = Rect(active.row, active.column, min(active.height, widget.height), min(active.width, widget.width))
    isempty(clipped) && return buffer
    rendered = rich_lines_to_core_text(
        CoreTextAdapter(),
        _render_datetime_lines(state, clipped.width),
    )
    render!(buffer, Paragraph(rendered), clipped)
    return buffer
end

function handle!(state::DateTimeInputState, widget::DateTimeInput, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code in (:tab, :backtab)
        state.active = !state.active
        return true
    end
    if state.active
        result = handle_data_entry_key!(
            state.date,
            widget.date_bindings,
            event.key.code;
            control=in(CTRL, event.modifiers),
            alt=in(ALT, event.modifiers),
            shift=in(SHIFT, event.modifiers),
        )
        result.consumed || return false
        _datetime_input_sync_time_bounds!(state, widget.minimum, widget.maximum)
        return true
    end
    result = handle_data_entry_key!(
        state.time,
        widget.time_bindings,
        event.key.code;
        control=in(CTRL, event.modifiers),
        alt=in(ALT, event.modifiers),
        shift=in(SHIFT, event.modifiers),
    )
    return result.consumed
end

handle!(::DateTimeInputState, ::DateTimeInput, ::PasteEvent) = false
function handle!(state::DateTimeInputState, widget::DateTimeInput, event::MouseEvent, area::Rect)
    event.action == MouseScroll && contains(area, event.position) || return false
    key = event.button == WheelUpButton ? :up : event.button == WheelDownButton ? :down : nothing
    key === nothing && return false
    bindings = state.active ? widget.date_bindings : widget.time_bindings
    target = state.active ? state.date : state.time
    consumed = handle_data_entry_key!(target, bindings, key).consumed
    consumed && state.active && _datetime_input_sync_time_bounds!(state, widget.minimum, widget.maximum)
    return consumed
end

function SemanticToolkit.widget_semantic_descriptor(::DateTimeInput, state::DateTimeInputState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Date and time input",
        state=Accessibility.SemanticState(value="$(state.date.selected) $(state.time.value)"),
        actions=[Accessibility.SetValueSemanticAction, Accessibility.IncrementSemanticAction, Accessibility.DecrementSemanticAction],
        metadata=Dict(:active_field => state.active ? :date : :time),
    )
end

"""A dialog surface rendered with explicit external `DialogState`."""
struct Dialog
    body::Text
    block::Block
    button_style::Style
    focused_button_style::Style
end

function Dialog(
    body;
    title::AbstractString="Dialog",
    border_style::Style=Style(),
    title_style::Style=Style(modifiers=BOLD),
    button_style::Style=Style(),
    focused_button_style::Style=Style(modifiers=REVERSED | BOLD),
)
    content = body isa Text ? body : Text(string(body))
    block = Block(
        title=title,
        border_style=border_style,
        title_style=title_style,
        padding=Margin(0, 1),
    )
    return Dialog(content, block, button_style, focused_button_style)
end

function _dialog_button_regions(state::DialogState, area::Rect)
    isempty(area) && return Tuple{Int,Rect,String}[]
    widths = Int[text_width(" " * button.label * " ") for button in state.buttons]
    total = sum(widths; init=0) + max(0, length(widths) - 1)
    column = area.column + max(0, (area.width - total) ÷ 2)
    regions = Tuple{Int,Rect,String}[]
    for (index, button) in enumerate(state.buttons)
        width = min(widths[index], max(0, area.column + area.width - column))
        width > 0 && push!(regions, (index, Rect(area.row, column, 1, width), button.label))
        column += widths[index] + 1
        column >= area.column + area.width && break
    end
    return regions
end

function _render_dialog!(
    buffer::Buffer,
    widget::Dialog,
    area::Rect,
    state::Union{Nothing,DialogState},
)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    render!(buffer, Clear(), active)
    render!(buffer, widget.block, active)
    content = intersection(buffer.area, inner(widget.block, active))
    isempty(content) && return buffer

    button_height = state === nothing || isempty(state.buttons) ? 0 : 1
    body_height = max(0, content.height - button_height)
    body_height > 0 && render!(
        buffer,
        Paragraph(widget.body),
        Rect(content.row, content.column, body_height, content.width),
    )
    button_height == 0 && return buffer

    button_area = Rect(content.row + content.height - 1, content.column, 1, content.width)
    for (index, region, label) in _dialog_button_regions(state, button_area)
        button = state.buttons[index]
        style = button.disabled ? apply(widget.button_style, StylePatch(add_modifiers=DIM)) :
                state.focused == index ? widget.focused_button_style : widget.button_style
        render!(buffer, Label(" " * label * " "; style), region)
    end
    return buffer
end

render!(buffer::Buffer, widget::Dialog, area::Rect) =
    _render_dialog!(buffer, widget, area, nothing)

function render!(buffer::Buffer, widget::Dialog, area::Rect, state::DialogState)
    state.open || return buffer
    return _render_dialog!(buffer, widget, area, state)
end

"""Handle keyboard navigation, confirmation, and dismissal for an open dialog."""
function handle!(state::DialogState, ::Dialog, event::KeyEvent)
    state.open && event.kind in (KeyPress, KeyRepeat) || return false
    if event.key.code in (:left, :backtab)
        move_dialog_focus!(state, -1)
    elseif event.key.code in (:right, :tab)
        move_dialog_focus!(state, 1)
    elseif event.key.code == :enter
        activate_dialog_button!(state)
    elseif event.key.code == :escape
        close_dialog!(state)
    else
        return false
    end
    return true
end

"""Activate a dialog button from a one-based terminal mouse release."""
function handle!(state::DialogState, widget::Dialog, event::MouseEvent, area::Rect)
    state.open || return false
    event.action == MouseRelease && event.button == LeftMouseButton || return false
    content = intersection(area, inner(widget.block, area))
    isempty(content) && return false
    button_area = Rect(content.row + content.height - 1, content.column, 1, content.width)
    for (index, region, _) in _dialog_button_regions(state, button_area)
        contains(region, event.position) || continue
        state.buttons[index].disabled && return false
        state.focused = index
        activate_dialog_button!(state)
        return true
    end
    return false
end

function SemanticToolkit.widget_semantic_descriptor(::Dialog, state::DialogState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.DialogRole;
        label="Dialog",
        state=Accessibility.SemanticState(hidden=!state.open, focusable=state.open),
        actions=[Accessibility.FocusSemanticAction],
        metadata=Dict(:result => state.result),
    )
end

function SemanticToolkit.widget_semantic_children(::Dialog, state::DialogState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(index)",
            Accessibility.ButtonRole;
            label=button.label,
            state=Accessibility.SemanticState(enabled=!button.disabled, selected=state.focused == index),
            actions=button.disabled ? Accessibility.SemanticAction[] : [Accessibility.ActivateSemanticAction],
            metadata=Dict(:role => button.role, :value => button.value),
        ) for (index, button) in enumerate(state.buttons)
    ]
end

"""A clipped, non-throwing presentation of an application or runtime error."""
struct ErrorView
    title::String
    message::String
    details::Vector{String}
    block::Block
    message_style::Style
    detail_style::Style
end

"""Compatibility alias for a modal naming convention used by upstream frameworks."""
const Modal = Dialog

function ErrorView(
    error;
    title::AbstractString="Application error",
    details=String[],
    border_style::Style=Style(foreground=AnsiColor(1)),
    message_style::Style=Style(foreground=AnsiColor(1), modifiers=BOLD),
    detail_style::Style=Style(modifiers=DIM),
)
    message = error isa Exception ? sprint(showerror, error) : string(error)
    block = Block(
        title=title,
        border_style=border_style,
        title_style=message_style,
        padding=Margin(0, 1),
    )
    return ErrorView(
        String(title),
        message,
        String[string(detail) for detail in details],
        block,
        message_style,
        detail_style,
    )
end

function render!(buffer::Buffer, widget::ErrorView, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    render!(buffer, widget.block, active)
    content = intersection(buffer.area, inner(widget.block, active))
    isempty(content) && return buffer
    lines = Line[Line(widget.message; style=widget.message_style)]
    append!(lines, (Line(detail; style=widget.detail_style) for detail in widget.details))
    render!(buffer, Paragraph(Text(lines)), content)
    return buffer
end

function SemanticToolkit.widget_semantic_descriptor(widget::ErrorView, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.AlertRole;
        label=widget.title,
        description=widget.message,
        state=Accessibility.SemanticState(enabled=true),
        metadata=Dict{Symbol,Any}(
            :detail_count => length(widget.details),
            :details => copy(widget.details),
        ),
    )
end

_validation_role(issues) = any(issue -> issue.severity == :error, issues) ?
    Accessibility.AlertRole : Accessibility.StatusRole

function SemanticToolkit.widget_semantic_descriptor(widget::ValidationMessage, state)
    issues = widget.issues
    return SemanticToolkit.SemanticDescriptor(
        _validation_role(issues);
        label=length(issues) == 1 ? "Validation issue" : "Validation issues",
        description=join((issue.message for issue in issues), "\n"),
        state=Accessibility.SemanticState(enabled=true),
        metadata=Dict{Symbol,Any}(
            :issue_count => length(issues),
            :codes => Symbol[issue.code for issue in issues],
            :severities => Symbol[issue.severity for issue in issues],
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::ValidationSummary, state)
    issues = form_issues(widget.form, widget.state)
    return SemanticToolkit.SemanticDescriptor(
        _validation_role(last(issue) for issue in issues);
        label="Form validation",
        description=join((
            "$(only(field.label for field in widget.form.fields if field.id == id)): $(issue.message)"
            for (id, issue) in issues
        ),
            "\n",
        ),
        state=Accessibility.SemanticState(enabled=true),
        metadata=Dict{Symbol,Any}(
            :issue_count => length(issues),
            :field_ids => Any[id for (id, _) in issues],
            :codes => Symbol[issue.code for (_, issue) in issues],
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::ManagedNotificationView, state)
    snapshots = notification_snapshots(widget.manager)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.LogRole;
        label="Notifications",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :notification_count => length(snapshots),
            :generation => notification_generation(widget.manager),
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::ManagedNotificationView, state, id)
    tree = notification_semantic_tree(notification_snapshots(widget.manager); id=id)
    return tree.root.children
end

_notification_role(notification::Notification) = notification.severity == :error ?
    Accessibility.AlertRole : Accessibility.StatusRole

function SemanticToolkit.widget_semantic_descriptor(widget::NotificationView, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.LogRole;
        label="Notifications",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :notification_count => length(widget.center.notifications),
            :maximum => widget.center.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::NotificationView, state, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/notification/$(notification.id)",
            _notification_role(notification);
            label=isempty(notification.title) ? "Notification" : notification.title,
            description=notification.message,
            state=Accessibility.SemanticState(readonly=true),
            metadata=Dict{Symbol,Any}(
                :notification_id => notification.id,
                :severity => notification.severity,
                :timeout_ns => notification.timeout_ns,
            ),
        ) for notification in widget.center.notifications
    ]
end

function SemanticToolkit.widget_semantic_descriptor(widget::CommandPalette, state::CommandPaletteState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.DialogRole;
        label="Command palette",
        state=Accessibility.SemanticState(
            hidden=!state.open,
            focusable=state.open,
            focused=state.open && state.query.focused,
        ),
        actions=state.open ? Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.DismissSemanticAction,
        ] : Accessibility.SemanticAction[Accessibility.FocusSemanticAction],
        metadata=Dict{Symbol,Any}(
            :open => state.open,
            :query => editing_text(state.query.editing),
            :result_count => length(state.filtered),
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::CommandPalette, state::CommandPaletteState, id)
    state.open || return Accessibility.SemanticNode[]
    Widgets._filter_commands!(widget, state)
    children = Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/search",
            Accessibility.SearchboxRole;
            label="Command search",
            state=Accessibility.SemanticState(
                focusable=true,
                focused=false,
                value=editing_text(state.query.editing),
            ),
            actions=Accessibility.SemanticAction[
                Accessibility.FocusSemanticAction,
                Accessibility.SetValueSemanticAction,
            ],
        ),
    ]
    for (visible_index, command_index) in enumerate(state.filtered)
        command = widget.commands[command_index]
        push!(
            children,
            Accessibility.SemanticNode(
                "$(id)/command/$(command.id)",
                Accessibility.ListItemRole;
                label=command.title,
                description=command.description,
                state=Accessibility.SemanticState(
                    enabled=!command.disabled,
                    focusable=!command.disabled,
                    selected=state.selected == visible_index,
                ),
                actions=command.disabled ? Accessibility.SemanticAction[] : Accessibility.SemanticAction[
                    Accessibility.ActivateSemanticAction,
                    Accessibility.FocusSemanticAction,
                ],
                metadata=Dict{Symbol,Any}(
                    :command_id => command.id,
                    :action => command.action,
                    :keywords => copy(command.keywords),
                ),
            ),
        )
    end
    return children
end

function SemanticToolkit.widget_semantic_descriptor(widget::LogView, state::LogState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.LogRole;
        label="Log",
        state=Accessibility.SemanticState(focusable=true, readonly=true),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :entry_count => length(state.entries),
            :offset => state.offset,
            :maximum_entries => state.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Scrollbar, state::ScrollState)
    vertical = widget.direction == VerticalScrollbar
    maximum = max(0, widget.content_length - widget.viewport_length)
    offset = vertical ? state.row : state.column
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ScrollbarRole;
        label=vertical ? "Vertical scrollbar" : "Horizontal scrollbar",
        state=Accessibility.SemanticState(
            focusable=true,
            value_now=offset,
            value_min=0,
            value_max=maximum,
        ),
        actions=Accessibility.SemanticAction[
            Accessibility.FocusSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
        ],
        metadata=Dict{Symbol,Any}(
            :orientation => vertical ? :vertical : :horizontal,
            :content_length => widget.content_length,
            :viewport_length => widget.viewport_length,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Gauge, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ProgressRole;
        label=widget.label,
        state=Accessibility.SemanticState(
            readonly=true,
            value=widget.label,
            value_now=widget.ratio,
            value_min=0,
            value_max=1,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::LineGauge, state)
    value = string(round(Int, widget.ratio * 100), "%")
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ProgressRole;
        label="Progress",
        state=Accessibility.SemanticState(
            readonly=true,
            value=value,
            value_now=widget.ratio,
            value_min=0,
            value_max=1,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Spinner, state::SpinnerState)
    frame = mod1(state.frame, length(widget.frames))
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ProgressRole;
        label=isempty(widget.label) ? "Loading" : widget.label,
        state=Accessibility.SemanticState(readonly=true, busy=true),
        metadata=Dict{Symbol,Any}(
            :frame => frame,
            :frame_count => length(widget.frames),
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Sparkline, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Sparkline",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :sample_count => length(widget.values),
            :minimum => widget.minimum,
            :maximum => widget.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::BarChart, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Bar chart",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :bar_count => length(widget.bars),
            :maximum => widget.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Canvas, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Canvas",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:x_bounds => widget.x_bounds, :y_bounds => widget.y_bounds),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Chart, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Chart",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :dataset_count => length(widget.datasets),
            :x_bounds => widget.x_bounds,
            :y_bounds => widget.y_bounds,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Histogram, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Histogram",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:sample_count => length(widget.values), :bins => widget.bins),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Heatmap, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ImageRole;
        label="Heatmap",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :rows => size(widget.values, 1),
            :columns => size(widget.values, 2),
            :minimum => widget.minimum,
            :maximum => widget.maximum,
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Calendar, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Calendar $(widget.year)-$(lpad(string(widget.month), 2, '0'))",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :year => widget.year,
            :month => widget.month,
            :selected => widget.selected,
            :marked_count => length(widget.marked),
        ),
    )
end

function SemanticToolkit.widget_semantic_children(widget::LogView, state::LogState, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/entry/$(index)",
            Accessibility.ListItemRole;
            label=uppercase(string(entry.level)),
            description=entry.message,
            state=Accessibility.SemanticState(readonly=true),
            metadata=Dict{Symbol,Any}(
                :timestamp_ns => entry.timestamp_ns,
                :level => entry.level,
            ),
        ) for (index, entry) in enumerate(state.entries)
    ]
end

function SemanticToolkit.widget_semantic_descriptor(widget::HelpView, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Keyboard shortcuts",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:hint_count => length(widget.hints)),
    )
end

function SemanticToolkit.widget_semantic_children(widget::HelpView, state, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/hint/$(index)",
            Accessibility.ListItemRole;
            label=hint.key,
            description=hint.description,
            state=Accessibility.SemanticState(readonly=true),
            metadata=Dict{Symbol,Any}(:key => hint.key),
        ) for (index, hint) in enumerate(widget.hints)
    ]
end

_core_line_plain(line::Line) = join(span.content for span in line.spans)
_core_text_plain(text::Text) = join((_core_line_plain(line) for line in text.lines), "\n")

function SemanticToolkit.widget_semantic_descriptor(widget::Header, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.HeadingRole;
        label=widget.title,
        description=isempty(widget.subtitle) ? nothing : widget.subtitle,
        state=Accessibility.SemanticState(readonly=true),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Footer, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Keyboard shortcuts",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:hint_count => length(widget.hints)),
    )
end

function SemanticToolkit.widget_semantic_children(widget::Footer, state, id)
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/hint/$(index)",
            Accessibility.ListItemRole;
            label=hint.key,
            description=hint.description,
            state=Accessibility.SemanticState(readonly=true),
            metadata=Dict{Symbol,Any}(:key => hint.key),
        ) for (index, hint) in enumerate(widget.hints)
    ]
end

function SemanticToolkit.widget_semantic_descriptor(widget::Badge, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.StatusRole;
        label=widget.text,
        state=Accessibility.SemanticState(readonly=true),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Alert, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.AlertRole;
        label=widget.block.title === nothing ? "Alert" : _core_line_plain(widget.block.title),
        description=_core_text_plain(widget.message),
        state=Accessibility.SemanticState(enabled=true),
        metadata=Dict{Symbol,Any}(:severity => widget.severity),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Digits, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.StatusRole;
        label=widget.value,
        state=Accessibility.SemanticState(readonly=true, value=widget.value),
        metadata=Dict{Symbol,Any}(:spacing => widget.spacing),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Pretty, state)
    value = pretty_text(widget; height=24, width=80)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label="Value",
        state=Accessibility.SemanticState(readonly=true, value=value),
        metadata=Dict{Symbol,Any}(:compact => widget.compact),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Placeholder, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=widget.label,
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:symbol => widget.symbol),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Label, state)
    content = _core_line_plain(widget.line)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ParagraphRole;
        label=content,
        state=Accessibility.SemanticState(readonly=true, value=content),
        metadata=Dict{Symbol,Any}(:line_count => 1),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Paragraph, state)
    content = _core_text_plain(widget.text)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ParagraphRole;
        label=content,
        state=Accessibility.SemanticState(readonly=true, value=content),
        metadata=Dict{Symbol,Any}(:line_count => length(widget.text.lines), :wrap => widget.wrap),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Block, state)
    title = widget.title === nothing ? "Block" : _core_line_plain(widget.title)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=title,
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :borders => widget.borders.bits,
            :padding => (widget.padding.top, widget.padding.right, widget.padding.bottom, widget.padding.left),
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Clear, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label="Clear surface",
        state=Accessibility.SemanticState(readonly=true),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Spacer, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label="Spacer",
        state=Accessibility.SemanticState(readonly=true),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Rule, state)
    direction = widget.direction == HorizontalRule ? :horizontal : :vertical
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GenericRole;
        label=direction == :horizontal ? "Horizontal rule" : "Vertical rule",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:direction => direction),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Padding, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Padded content",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :margin => (widget.margin.top, widget.margin.right, widget.margin.bottom, widget.margin.left),
        ),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Box, state)
    title = widget.block.title === nothing ? "Box" : _core_line_plain(widget.block.title)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label=title,
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:borders => widget.block.borders.bits),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Row, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Row",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:child_count => length(widget.children), :orientation => :horizontal),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Column, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Column",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:child_count => length(widget.children), :orientation => :vertical),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Stack, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Stack",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:child_count => length(widget.children), :layered => true),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Center, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Centered content",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(:height => widget.size.height, :width => widget.size.width),
    )
end

function SemanticToolkit.widget_semantic_descriptor(widget::Grid, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Grid",
        state=Accessibility.SemanticState(readonly=true),
        metadata=Dict{Symbol,Any}(
            :child_count => length(widget.children),
            :rows => length(widget.layout.rows),
            :columns => length(widget.layout.columns),
        ),
    )
end
