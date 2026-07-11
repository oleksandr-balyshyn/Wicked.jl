@enum MouseTrackingMode::UInt8 begin
    BasicMouseTracking
    ButtonMotionTracking
    AnyMotionTracking
end

"""Terminal session behavior for the ANSI backend."""
struct TerminalOptions
    raw_mode::Bool
    alternate_screen::Bool
    hide_cursor::Bool
    mouse_capture::Bool
    focus_reporting::Bool
    bracketed_paste::Bool
    mouse_tracking::MouseTrackingMode

    function TerminalOptions(;
        raw_mode::Bool=true,
        alternate_screen::Bool=true,
        hide_cursor::Bool=true,
        mouse_capture::Bool=true,
        focus_reporting::Bool=true,
        bracketed_paste::Bool=true,
        mouse_tracking::MouseTrackingMode=ButtonMotionTracking,
    )
        new(
            raw_mode,
            alternate_screen,
            hide_cursor,
            mouse_capture,
            focus_reporting,
            bracketed_paste,
            mouse_tracking,
        )
    end
end

"""Extension interface for platform-specific terminal mode control."""
abstract type AbstractTerminalController end

"""Controller used for redirected streams and explicitly unmanaged terminals."""
struct NoopTerminalController <: AbstractTerminalController end

"""Cross-platform raw-mode controller backed by Julia's REPL terminal implementation."""
mutable struct JuliaTTYController{T} <: AbstractTerminalController
    terminal::T
    raw::Bool
end

function JuliaTTYController(input::IO, output::IO, error::IO=stderr)
    terminal_type = get(ENV, "TERM", Sys.iswindows() ? "" : "dumb")
    terminal = REPL.Terminals.TTYTerminal(terminal_type, input, output, error)
    JuliaTTYController(terminal, false)
end

"""Enable or disable raw input mode through a terminal controller."""
set_raw!(::NoopTerminalController, ::Bool) = false

function set_raw!(controller::JuliaTTYController, enabled::Bool)
    controller.raw == enabled && return true
    REPL.Terminals.raw!(controller.terminal, enabled)
    controller.raw = enabled
    true
end

function _default_terminal_controller(input::IO, output::IO)
    input isa Base.TTY && output isa Base.TTY ?
        JuliaTTYController(input, output) : NoopTerminalController()
end

function _forced_color_level(value)
    normalized = lowercase(strip(String(value)))
    normalized in ("0", "false", "none", "off") && return :none
    normalized in ("2", "256", "ansi256") && return :ansi256
    normalized in ("3", "24", "24bit", "truecolor") && return :truecolor
    :ansi16
end

"""Detect the default color level from environment and output characteristics."""
function detect_color_level(
    output::IO=stdout;
    environment=ENV,
    is_tty::Union{Nothing,Bool}=nothing,
)
    haskey(environment, "FORCE_COLOR") &&
        return _forced_color_level(environment["FORCE_COLOR"])
    haskey(environment, "NO_COLOR") && return :none
    tty = isnothing(is_tty) ? output isa Base.TTY : is_tty
    tty || return :none
    terminal = lowercase(get(environment, "TERM", ""))
    terminal == "dumb" && return :none
    lowercase(get(environment, "COLORTERM", "")) in ("truecolor", "24bit") &&
        return :truecolor
    occursin("256color", terminal) && return :ansi256
    :ansi16
end

"""Pure Julia ANSI rendering backend."""
mutable struct AnsiBackend{I<:IO,O<:IO} <: AbstractBackend
    input::I
    output::O
    capabilities::TerminalCapabilities
    options::TerminalOptions
    controller::AbstractTerminalController
    size_override::Union{Nothing,Size}
    session_state::UInt16
end

function AnsiBackend(
    input::I=stdin,
    output::O=stdout;
    capabilities::TerminalCapabilities=TerminalCapabilities(color_level=detect_color_level(output)),
    options::TerminalOptions=TerminalOptions(),
    controller::AbstractTerminalController=_default_terminal_controller(input, output),
    size::Union{Nothing,Size}=nothing,
) where {I<:IO,O<:IO}
    AnsiBackend{I,O}(input, output, capabilities, options, controller, size, 0x0000)
end

const _SESSION_ENTERING = UInt16(0x0001)
const _SESSION_RAW = UInt16(0x0002)
const _SESSION_ALTERNATE = UInt16(0x0004)
const _SESSION_CURSOR = UInt16(0x0008)
const _SESSION_PASTE = UInt16(0x0010)
const _SESSION_FOCUS = UInt16(0x0020)
const _SESSION_MOUSE = UInt16(0x0040)
const _SESSION_KEYBOARD = UInt16(0x0080)

function backend_size(backend::AnsiBackend)
    !isnothing(backend.size_override) && return backend.size_override
    height, width = displaysize(backend.output)
    Size(max(0, height), max(0, width))
end

backend_capabilities(backend::AnsiBackend) = backend.capabilities

function set_terminal_title!(
    backend::AnsiBackend,
    title::AbstractString;
    maximum_bytes::Integer=1024,
)
    backend.capabilities.terminal_title || return false
    _write_terminal_title!(backend.output, title; maximum_bytes)
end

function resize_backend!(backend::AnsiBackend, height::Integer, width::Integer)
    backend.size_override = Size(height, width)
    backend
end

function _color_codes(color::Color, foreground::Bool, capabilities::TerminalCapabilities)
    kind = UInt8(color.kind)
    default_code = foreground ? 39 : 49
    capabilities.color_level == :none && return string(default_code)
    if kind == 0
        return string(default_code)
    elseif kind == 1
        index = Int(color.value)
        base = foreground ? (index < 8 ? 30 : 90) : (index < 8 ? 40 : 100)
        return string(base + (index % 8))
    elseif kind == 2
        index = Int(color.value)
        if capabilities.color_level == :ansi16
            reduced = index % 16
            base = foreground ? (reduced < 8 ? 30 : 90) : (reduced < 8 ? 40 : 100)
            return string(base + (reduced % 8))
        end
        return string(foreground ? 38 : 48, ";5;", index)
    end
    red = Int((color.value >> 16) & 0xff)
    green = Int((color.value >> 8) & 0xff)
    blue = Int(color.value & 0xff)
    if capabilities.color_level == :truecolor
        return string(foreground ? 38 : 48, ";2;", red, ';', green, ';', blue)
    elseif capabilities.color_level == :ansi256
        index = 16 + 36 * round(Int, red / 255 * 5) +
                6 * round(Int, green / 255 * 5) + round(Int, blue / 255 * 5)
        return string(foreground ? 38 : 48, ";5;", index)
    end
    intensity = (red + green + blue) ÷ 3 >= 128 ? 8 : 0
    dominant = (red >= 128 ? 1 : 0) + (green >= 128 ? 2 : 0) + (blue >= 128 ? 4 : 0)
    index = intensity + dominant
    base = foreground ? (index < 8 ? 30 : 90) : (index < 8 ? 40 : 100)
    string(base + (index % 8))
end

function _underline_color_code(color::Color, capabilities::TerminalCapabilities)
    capabilities.underline_color || return nothing
    capabilities.color_level == :none && return nothing
    kind = UInt8(color.kind)
    kind == 0 && return nothing
    if kind == 1
        return string("58;5;", Int(color.value))
    elseif kind == 2
        index = Int(color.value)
        capabilities.color_level == :ansi16 && (index %= 16)
        return string("58;5;", index)
    end
    red = Int((color.value >> 16) & 0xff)
    green = Int((color.value >> 8) & 0xff)
    blue = Int(color.value & 0xff)
    if capabilities.color_level == :truecolor
        return string("58;2;", red, ';', green, ';', blue)
    elseif capabilities.color_level == :ansi256
        index = 16 + 36 * round(Int, red / 255 * 5) +
                6 * round(Int, green / 255 * 5) + round(Int, blue / 255 * 5)
        return string("58;5;", index)
    end
    intensity = (red + green + blue) ÷ 3 >= 128 ? 8 : 0
    dominant = (red >= 128 ? 1 : 0) + (green >= 128 ? 2 : 0) + (blue >= 128 ? 4 : 0)
    string("58;5;", intensity + dominant)
end

function _write_style(io::IO, style::Style, capabilities::TerminalCapabilities)
    codes = String[
        "0",
        _color_codes(style.foreground, true, capabilities),
        _color_codes(style.background, false, capabilities),
    ]
    underline_color = _underline_color_code(style.underline_color, capabilities)
    isnothing(underline_color) || push!(codes, underline_color)
    BOLD in style.modifiers && push!(codes, "1")
    DIM in style.modifiers && push!(codes, "2")
    ITALIC in style.modifiers && push!(codes, "3")
    UNDERLINE in style.modifiers && push!(codes, "4")
    BLINK in style.modifiers && push!(codes, "5")
    REVERSED in style.modifiers && push!(codes, "7")
    HIDDEN in style.modifiers && push!(codes, "8")
    STRIKETHROUGH in style.modifiers && push!(codes, "9")
    DOUBLE_UNDERLINE in style.modifiers && push!(codes, "21")
    print(io, "\e[", join(codes, ';'), 'm')
end

function _write_hyperlink(io::IO, hyperlink::Union{Nothing,String})
    if isnothing(hyperlink)
        print(io, "\e]8;;\e\\")
        return
    end
    any(character -> begin
        codepoint = Int(character)
        codepoint < 0x20 || 0x7f <= codepoint <= 0x9f
    end, hyperlink) &&
        throw(ArgumentError("hyperlink contains a terminal control character"))
    print(io, "\e]8;;", hyperlink, "\e\\")
end

function _write_cursor(io::IO, cursor::Union{Nothing,CursorRequest})
    if isnothing(cursor) || !cursor.visible
        print(io, "\e[?25l")
        return
    end
    print(io, "\e[", cursor.position.row, ';', cursor.position.column, 'H')
    shape_code = cursor.shape == BlockCursor ? 2 :
                 cursor.shape == UnderlineCursor ? 4 :
                 cursor.shape == BarCursor ? 6 : 0
    shape_code != 0 && print(io, "\e[", shape_code, " q")
    print(io, "\e[?25h")
end

function present!(
    backend::AnsiBackend,
    changes::AbstractVector{CellChange},
    ::Buffer,
    cursor::Union{Nothing,CursorRequest},
)
    io = backend.output
    synchronized = backend.capabilities.synchronized_updates
    synchronized && print(io, "\e[?2026h")
    expected = nothing
    active_style = nothing
    active_hyperlink = nothing
    function cleanup_protocol!()
        !isnothing(active_hyperlink) && _write_hyperlink(io, nothing)
        synchronized && print(io, "\e[?2026l")
        return nothing
    end
    try
        for change in changes
            cell = change.cell
            cell.continuation && continue
            position = change.position
            if isnothing(expected) || expected != position
                print(io, "\e[", position.row, ';', position.column, 'H')
            end
            if active_style != cell.style
                _write_style(io, cell.style, backend.capabilities)
                active_style = cell.style
            end
            if active_hyperlink != cell.style.hyperlink
                _write_hyperlink(io, cell.style.hyperlink)
                active_hyperlink = cell.style.hyperlink
            end
            print(io, cell.grapheme)
            expected = Position(position.row, position.column + Int(cell.width))
        end
        _write_cursor(io, cursor)
    catch
        try
            cleanup_protocol!()
        catch
        end
        rethrow()
    end
    cleanup_protocol!()
    nothing
end

flush!(backend::AnsiBackend) = flush(backend.output)

function enter!(backend::AnsiBackend)
    backend.session_state != 0 && return nothing
    io = backend.output
    backend.session_state = _SESSION_ENTERING
    try
        if backend.options.raw_mode && set_raw!(backend.controller, true)
            backend.session_state |= _SESSION_RAW
        end
        if backend.options.alternate_screen
            print(io, "\e[?1049h")
            backend.session_state |= _SESSION_ALTERNATE
        end
        if backend.options.hide_cursor
            print(io, "\e[?25l")
            backend.session_state |= _SESSION_CURSOR
        end
        if backend.capabilities.enhanced_keyboard
            print(io, "\e[>3u")
            backend.session_state |= _SESSION_KEYBOARD
        end
        if backend.options.bracketed_paste && backend.capabilities.bracketed_paste
            print(io, "\e[?2004h")
            backend.session_state |= _SESSION_PASTE
        end
        if backend.options.focus_reporting && backend.capabilities.focus
            print(io, "\e[?1004h")
            backend.session_state |= _SESSION_FOCUS
        end
        if backend.options.mouse_capture && backend.capabilities.mouse
            print(io, "\e[?1000h")
            backend.options.mouse_tracking == ButtonMotionTracking && print(io, "\e[?1002h")
            backend.options.mouse_tracking == AnyMotionTracking && print(io, "\e[?1003h")
            print(io, "\e[?1006h")
            backend.session_state |= _SESSION_MOUSE
        end
        flush(io)
    catch
        try
            leave!(backend)
        catch
        end
        rethrow()
    end
    nothing
end

function leave!(backend::AnsiBackend)
    backend.session_state == 0 && return nothing
    io = backend.output
    state = backend.session_state
    failure = nothing
    try
        print(io, "\e[0m\e]8;;\e\\")
        state & _SESSION_MOUSE != 0 && print(io, "\e[?1006l\e[?1003l\e[?1002l\e[?1000l")
        state & _SESSION_FOCUS != 0 && print(io, "\e[?1004l")
        state & _SESSION_PASTE != 0 && print(io, "\e[?2004l")
        state & _SESSION_KEYBOARD != 0 && print(io, "\e[<u")
        state & _SESSION_CURSOR != 0 && print(io, "\e[?25h")
        state & _SESSION_ALTERNATE != 0 && print(io, "\e[?1049l")
        flush(io)
    catch error
        failure = error
    end
    if state & _SESSION_RAW != 0
        try
            set_raw!(backend.controller, false)
        catch error
            isnothing(failure) && (failure = error)
        end
    end
    backend.session_state = 0x0000
    isnothing(failure) || throw(failure)
    nothing
end

function reset_terminal!(
    backend::AnsiBackend;
    leave_alternate_screen::Bool=true,
    newline::Bool=true,
    force::Bool=true,
)
    try
        reset_terminal!(
            backend.output;
            controller=backend.controller,
            leave_alternate_screen,
            newline,
            force,
        )
    finally
        backend.session_state = 0x0000
    end
end
