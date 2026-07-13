"""Media and advanced immediate-mode widgets with terminal-safe fallbacks."""

struct ImageView
    image::RasterImage
    width::Int
    height::Int
end
function ImageView(image::RasterImage; width::Integer=40, height::Integer=12)
    width > 0 || throw(ArgumentError("image-view width must be positive"))
    height > 0 || throw(ArgumentError("image-view height must be positive"))
    ImageView(image, Int(width), Int(height))
end
measure(widget::ImageView, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))

function render!(buffer::Buffer, widget::ImageView, area::Rect)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return buffer
    cells = unicode_fallback(widget.image, active.width, active.height)
    for row in axes(cells, 1), column in axes(cells, 2)
        cell = cells[row, column]
        buffer[active.row + row - 1, active.column + column - 1] = Cell(
            string(cell.character);
            style=Style(
                foreground=RGBColor(cell.foreground...),
                background=RGBColor(cell.background...),
            ),
        )
    end
    return buffer
end

function SemanticToolkit.widget_semantic_descriptor(widget::ImageView, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Image",
        actions=[Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction],
        metadata=Dict(:pixel_width => widget.image.width, :pixel_height => widget.image.height, :format => widget.image.format),
    )
end

_visual_semantic_value(widget::ImageView) = Dict{Symbol,Any}(
    :pixel_width => widget.image.width,
    :pixel_height => widget.image.height,
    :format => widget.image.format,
)

register_image_view_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::ImageView) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "image view semantic action is not supported")

"""A compact image view that guarantees a Unicode cell fallback in all terminals."""
struct BrailleImage
    image::ImageView
end
BrailleImage(image::RasterImage; kwargs...) = BrailleImage(ImageView(image; kwargs...))
measure(widget::BrailleImage, available::Rect) = measure(widget.image, available)
render!(buffer::Buffer, widget::BrailleImage, area::Rect) = render!(buffer, widget.image, area)

function SemanticToolkit.widget_semantic_descriptor(widget::BrailleImage, state)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.GroupRole;
        label="Unicode image fallback",
        actions=[Accessibility.FocusSemanticAction, Accessibility.SelectSemanticAction],
        metadata=Dict(:pixel_width => widget.image.image.width, :pixel_height => widget.image.image.height, :format => widget.image.image.format),
    )
end

_visual_semantic_value(widget::BrailleImage) = Dict{Symbol,Any}(
    :pixel_width => widget.image.image.width,
    :pixel_height => widget.image.image.height,
    :format => widget.image.image.format,
)

register_braille_image_semantic_handlers!(dispatcher::Accessibility.SemanticDispatcher, id, widget::BrailleImage) =
    _register_readonly_visual_semantic_handlers!(dispatcher, id, widget, "braille image semantic action is not supported")

struct SyntaxView
    code::CodeView
end
function SyntaxView(source::AbstractString; language::AbstractString="", width::Integer=80, height::Integer=24, kwargs...)
    SyntaxView(CodeView(source; language, width, height, kwargs...))
end
const SyntaxViewState = CodeViewState
state_for(widget::SyntaxView) = state_for(widget.code)
measure(widget::SyntaxView, available::Rect) = measure(widget.code, available)
render!(buffer::Buffer, widget::SyntaxView, area::Rect, state::SyntaxViewState) = render!(buffer, widget.code, area, state)
render!(buffer::Buffer, widget::SyntaxView, area::Rect) = render!(buffer, widget.code, area)
handle!(state::SyntaxViewState, widget::SyntaxView, event::KeyEvent) = handle!(state, widget.code, event)
handle!(state::SyntaxViewState, widget::SyntaxView, event::MouseEvent, area::Rect) = handle!(state, widget.code, event, area)

function SemanticToolkit.widget_semantic_descriptor(widget::SyntaxView, state::SyntaxViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label=isempty(widget.code.language) ? "Syntax view" : "$(widget.code.language) source",
        state=Accessibility.SemanticState(
            focusable=true,
            readonly=true,
            invalid=any(diagnostic -> diagnostic.severity == CodeError, state.diagnostics),
            value="$(length(state.lines)) lines",
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:language => state.language, :revision => state.revision, :diagnostic_count => length(state.diagnostics)),
    )
end

register_syntax_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::SyntaxView,
    state::SyntaxViewState,
) = register_code_view_semantic_handlers!(dispatcher, id, widget.code, state)

function ansi_plain_text(value::AbstractString)
    output = IOBuffer()
    index = firstindex(value)
    while index <= lastindex(value)
        character = value[index]
        if character == '\e'
            next = nextind(value, index)
            next > lastindex(value) && break
            if value[next] == '['
                index = nextind(value, next)
                while index <= lastindex(value)
                    terminator = value[index]
                    index = nextind(value, index)
                    '@' <= terminator <= '~' && break
                end
                continue
            elseif value[next] == ']'
                index = nextind(value, next)
                while index <= lastindex(value)
                    terminator = value[index]
                    if terminator == '\a'
                        index = nextind(value, index)
                        break
                    elseif terminator == '\e'
                        after = nextind(value, index)
                        if after <= lastindex(value) && value[after] == '\\'
                            index = nextind(value, after)
                            break
                        end
                    end
                    index = nextind(value, index)
                end
                continue
            end
            index = nextind(value, next)
            continue
        end
        iscntrl(character) && character != '\n' || print(output, character)
        index = nextind(value, index)
    end
    return String(take!(output))
end

struct AnsiView
    source::String
    width::Int
    height::Int
end
function AnsiView(source::AbstractString; width::Integer=80, height::Integer=24)
    width > 0 || throw(ArgumentError("ansi-view width must be positive"))
    height >= 0 || throw(ArgumentError("ansi-view height cannot be negative"))
    AnsiView(String(source), Int(width), Int(height))
end
const AnsiViewState = ScrollState
state_for(::AnsiView) = AnsiViewState()
measure(widget::AnsiView, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))
function render!(buffer::Buffer, widget::AnsiView, area::Rect, state::AnsiViewState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return buffer
    lines = split(ansi_plain_text(widget.source), '\n'; keepempty=true)
    _render_scrolling_lines!(buffer, lines, active, state)
    return buffer
end
render!(buffer::Buffer, widget::AnsiView, area::Rect) = render!(buffer, widget, area, state_for(widget))
handle!(state::AnsiViewState, widget::AnsiView, event::KeyEvent) = _handle_scrolling_lines!(state, length(split(ansi_plain_text(widget.source), '\n'; keepempty=true)), widget.height, event)

function SemanticToolkit.widget_semantic_descriptor(widget::AnsiView, state::AnsiViewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.TextboxRole;
        label="ANSI output",
        state=Accessibility.SemanticState(
            focusable=true,
            readonly=true,
            value="$(length(split(ansi_plain_text(widget.source), '\n'; keepempty=true))) lines",
        ),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.ScrollIntoViewSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:offset => state.row, :sanitized => true),
    )
end

register_ansi_view_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::AnsiView,
    state::AnsiViewState,
) = _register_scroll_state_semantic_handlers!(
    dispatcher,
    id,
    state,
    () -> length(split(ansi_plain_text(widget.source), '\n'; keepempty=true)),
    widget.height,
    "ANSI view",
)

struct Hyperlink{T}
    label::String
    target::T
    style::Style
    focused_style::Style
end
function Hyperlink(label::AbstractString, target::T; style::Style=Style(foreground=AnsiColor(4), modifiers=UNDERLINE), focused_style::Style=Style(foreground=AnsiColor(6), modifiers=UNDERLINE | BOLD)) where {T}
    Hyperlink{T}(String(label), target, style, focused_style)
end
mutable struct HyperlinkState
    focused::Bool
end
HyperlinkState(; focused::Bool=false) = HyperlinkState(focused)
state_for(::Hyperlink) = HyperlinkState()
hyperlink_target(widget::Hyperlink) = widget.target
measure(widget::Hyperlink, available::Rect) = Size(min(available.height, 1), min(available.width, text_width(widget.label)))
function render!(buffer::Buffer, widget::Hyperlink, area::Rect, state::HyperlinkState)
    draw_text!(buffer, area.row, area.column, widget.label; style=state.focused ? widget.focused_style : widget.style, clip=intersection(buffer.area, area))
    return buffer
end
render!(buffer::Buffer, widget::Hyperlink, area::Rect) = render!(buffer, widget, area, state_for(widget))
function handle!(state::HyperlinkState, ::Hyperlink, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    state.focused = true
    return event.key.code == :enter || (event.key.code == :character && event.text == " ")
end
function handle!(state::HyperlinkState, widget::Hyperlink, event::MouseEvent, area::Rect)
    contains(area, event.position) || return false
    state.focused = true
    return event.action == MousePress && event.button == LeftMouseButton
end

function SemanticToolkit.widget_semantic_descriptor(widget::Hyperlink, state::HyperlinkState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ButtonRole;
        label=widget.label,
        state=Accessibility.SemanticState(focusable=true, focused=state.focused),
        actions=[Accessibility.FocusSemanticAction, Accessibility.ActivateSemanticAction],
        metadata=Dict(:target => widget.target),
    )
end

function register_hyperlink_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::Hyperlink,
    state::HyperlinkState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            state.focused = true
            return Accessibility.SemanticActionResult(true; value=widget.target)
        elseif request.action == Accessibility.ActivateSemanticAction
            state.focused = true
            return Accessibility.SemanticActionResult(true; value=widget.target)
        end
        return Accessibility.SemanticActionResult(false; message="hyperlink semantic action is not supported")
    end)
    return dispatcher
end

struct ColorPicker
    width::Int
    height::Int
    bindings::DataEntryBindings
end
function ColorPicker(; width::Integer=32, height::Integer=1, bindings::DataEntryBindings=default_data_entry_bindings())
    width > 0 || throw(ArgumentError("color-picker width must be positive"))
    height >= 0 || throw(ArgumentError("color-picker height cannot be negative"))
    ColorPicker(Int(width), Int(height), bindings)
end
state_for(::ColorPicker) = ColorPickerState()
measure(widget::ColorPicker, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))
function render!(buffer::Buffer, widget::ColorPicker, area::Rect, state::ColorPickerState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return buffer
    value = state.value
    style = Style(background=RGBColor(value.red, value.green, value.blue))
    for column in active.column:(active.column + min(3, active.width) - 1)
        buffer[active.row, column] = Cell(" "; style)
    end
    draw_text!(buffer, active.row, active.column + min(3, active.width), color_hex(state); clip=active)
    return buffer
end
render!(buffer::Buffer, widget::ColorPicker, area::Rect) = render!(buffer, widget, area, state_for(widget))
function handle!(state::ColorPickerState, widget::ColorPicker, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    return handle_data_entry_key!(state, widget.bindings, event.key.code;
        control=in(CTRL, event.modifiers), alt=in(ALT, event.modifiers), shift=in(SHIFT, event.modifiers)).consumed
end

function SemanticToolkit.widget_semantic_descriptor(::ColorPicker, state::ColorPickerState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.SliderRole;
        label="Color",
        state=Accessibility.SemanticState(focusable=true, value=color_hex(state)),
        actions=[Accessibility.FocusSemanticAction, Accessibility.SetValueSemanticAction, Accessibility.IncrementSemanticAction, Accessibility.DecrementSemanticAction],
    )
end

function register_color_picker_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ColorPicker,
    state::ColorPickerState,
)
    node_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, node_id, function (request)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=color_hex(state))
        elseif request.action == Accessibility.SetValueSemanticAction
            set_color_hex!(state, string(request.value)) ||
                return Accessibility.SemanticActionResult(false; message="color value must be a #RRGGBB or #RRGGBBAA hex string")
            return Accessibility.SemanticActionResult(true; value=color_hex(state))
        elseif request.action == Accessibility.IncrementSemanticAction
            result = handle_data_entry_key!(state, widget.bindings, :right)
            return Accessibility.SemanticActionResult(result.consumed; value=color_hex(state))
        elseif request.action == Accessibility.DecrementSemanticAction
            result = handle_data_entry_key!(state, widget.bindings, :left)
            return Accessibility.SemanticActionResult(result.consumed; value=color_hex(state))
        end
        return Accessibility.SemanticActionResult(false; message="color picker semantic action is not supported")
    end)
    return dispatcher
end

struct ThemePreview
    registry::ThemeRegistry
    width::Int
    height::Int
end
function ThemePreview(registry::ThemeRegistry; width::Integer=80, height::Integer=12)
    width > 0 || throw(ArgumentError("theme-preview width must be positive"))
    height >= 0 || throw(ArgumentError("theme-preview height cannot be negative"))
    ThemePreview(registry, Int(width), Int(height))
end
mutable struct ThemePreviewState
    selected::Int
end
ThemePreviewState(selected::Integer=1) = ThemePreviewState(max(1, Int(selected)))
state_for(::ThemePreview) = ThemePreviewState()
measure(widget::ThemePreview, available::Rect) = Size(min(available.height, widget.height), min(available.width, widget.width))
function render!(buffer::Buffer, widget::ThemePreview, area::Rect, state::ThemePreviewState)
    active = intersection(buffer.area, Rect(area.row, area.column, min(area.height, widget.height), min(area.width, widget.width)))
    isempty(active) && return buffer
    themes = available_themes(widget.registry)
    state.selected = isempty(themes) ? 1 : clamp(state.selected, 1, length(themes))
    active_theme = active_theme_descriptor(widget.registry).id
    for (offset, descriptor) in enumerate(themes[1:min(length(themes), active.height)])
        marker = descriptor.id == active_theme ? "*" : " "
        focus = state.selected == offset ? ">" : " "
        draw_text!(buffer, active.row + offset - 1, active.column, "$focus$marker $(descriptor.display_name) ($(descriptor.id))"; clip=active)
    end
    return buffer
end
render!(buffer::Buffer, widget::ThemePreview, area::Rect) = render!(buffer, widget, area, state_for(widget))
function handle!(state::ThemePreviewState, widget::ThemePreview, event::KeyEvent)
    event.kind in (KeyPress, KeyRepeat) || return false
    themes = available_themes(widget.registry)
    isempty(themes) && return false
    if event.key.code == :up
        state.selected = max(1, state.selected - 1)
    elseif event.key.code == :down
        state.selected = min(length(themes), state.selected + 1)
    elseif event.key.code == :home
        state.selected = 1
    elseif event.key.code == :end
        state.selected = length(themes)
    elseif event.key.code in (:enter, :character) && (event.key.code == :enter || event.text == " ")
        set_active_theme!(widget.registry, themes[clamp(state.selected, 1, length(themes))].id)
    else
        return false
    end
    return true
end

function SemanticToolkit.widget_semantic_descriptor(::ThemePreview, state::ThemePreviewState)
    return SemanticToolkit.SemanticDescriptor(
        Accessibility.ListRole;
        label="Theme preview",
        state=Accessibility.SemanticState(focusable=true),
        actions=[
            Accessibility.FocusSemanticAction,
            Accessibility.SelectSemanticAction,
            Accessibility.ActivateSemanticAction,
            Accessibility.SetValueSemanticAction,
            Accessibility.IncrementSemanticAction,
            Accessibility.DecrementSemanticAction,
        ],
        metadata=Dict(:selected_index => state.selected),
    )
end

function SemanticToolkit.widget_semantic_children(widget::ThemePreview, state::ThemePreviewState, id)
    active = active_theme_descriptor(widget.registry).id
    return Accessibility.SemanticNode[
        Accessibility.SemanticNode(
            "$(id)/$(descriptor.id)",
            Accessibility.ListItemRole;
            label=descriptor.display_name,
            state=Accessibility.SemanticState(selected=state.selected == index),
            actions=[Accessibility.SelectSemanticAction, Accessibility.ActivateSemanticAction],
            metadata=Dict(:theme_id => descriptor.id, :active => descriptor.id == active),
        ) for (index, descriptor) in enumerate(available_themes(widget.registry))
    ]
end

function _theme_preview_semantic_value(widget::ThemePreview, state::ThemePreviewState)
    themes = available_themes(widget.registry)
    selected = isempty(themes) ? nothing : themes[clamp(state.selected, 1, length(themes))]
    active = active_theme_descriptor(widget.registry)
    return Dict{Symbol,Any}(
        :selected_index => state.selected,
        :selected_theme => selected === nothing ? nothing : selected.id,
        :active_theme => active.id,
        :theme_count => length(themes),
    )
end

function _select_theme_preview_index!(state::ThemePreviewState, themes, index::Integer)
    isempty(themes) && return false
    1 <= index <= length(themes) || return false
    state.selected = Int(index)
    return true
end

function _select_theme_preview_value!(state::ThemePreviewState, themes, value)
    if value isa Integer
        return _select_theme_preview_index!(state, themes, value)
    end
    parsed = tryparse(Int, string(value))
    parsed !== nothing && return _select_theme_preview_index!(state, themes, parsed)
    for (index, descriptor) in enumerate(themes)
        string(descriptor.id) == string(value) && return _select_theme_preview_index!(state, themes, index)
    end
    return false
end

function _activate_theme_preview_selection!(widget::ThemePreview, state::ThemePreviewState, themes)
    isempty(themes) && return false
    index = clamp(state.selected, 1, length(themes))
    state.selected = index
    set_active_theme!(widget.registry, themes[index].id)
    return true
end

function register_theme_preview_semantic_handlers!(
    dispatcher::Accessibility.SemanticDispatcher,
    id,
    widget::ThemePreview,
    state::ThemePreviewState,
)
    root_id = string(id)
    Accessibility.register_semantic_handler!(dispatcher, root_id, function (request)
        themes = available_themes(widget.registry)
        if request.action == Accessibility.FocusSemanticAction
            return Accessibility.SemanticActionResult(true; value=_theme_preview_semantic_value(widget, state))
        elseif request.action == Accessibility.IncrementSemanticAction
            handled = _select_theme_preview_index!(state, themes, min(length(themes), state.selected + 1))
            return Accessibility.SemanticActionResult(handled; value=_theme_preview_semantic_value(widget, state))
        elseif request.action == Accessibility.DecrementSemanticAction
            handled = _select_theme_preview_index!(state, themes, max(1, state.selected - 1))
            return Accessibility.SemanticActionResult(handled; value=_theme_preview_semantic_value(widget, state))
        elseif request.action == Accessibility.SetValueSemanticAction
            handled = _select_theme_preview_value!(state, themes, request.value)
            return Accessibility.SemanticActionResult(
                handled;
                value=_theme_preview_semantic_value(widget, state),
                message=handled ? nothing : "theme preview semantic value must be an index or theme id",
            )
        elseif request.action == Accessibility.SelectSemanticAction || request.action == Accessibility.ActivateSemanticAction
            handled = _activate_theme_preview_selection!(widget, state, themes)
            return Accessibility.SemanticActionResult(handled; value=_theme_preview_semantic_value(widget, state))
        end
        return Accessibility.SemanticActionResult(false; message="theme preview semantic action is not supported")
    end)

    for (index, descriptor) in enumerate(available_themes(widget.registry))
        child_id = "$(root_id)/$(descriptor.id)"
        Accessibility.register_semantic_handler!(dispatcher, child_id, function (request)
            if request.action == Accessibility.FocusSemanticAction || request.action == Accessibility.SelectSemanticAction
                _select_theme_preview_index!(state, available_themes(widget.registry), index)
                return Accessibility.SemanticActionResult(true; value=_theme_preview_semantic_value(widget, state))
            elseif request.action == Accessibility.ActivateSemanticAction
                themes = available_themes(widget.registry)
                handled = _select_theme_preview_index!(state, themes, index) &&
                    _activate_theme_preview_selection!(widget, state, themes)
                return Accessibility.SemanticActionResult(handled; value=_theme_preview_semantic_value(widget, state))
            end
            return Accessibility.SemanticActionResult(false; message="theme preview item semantic action is not supported")
        end)
    end
    return dispatcher
end
