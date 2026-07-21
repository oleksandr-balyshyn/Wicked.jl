module Backends

using REPL
using ..Core
import ..Core: clear!, render!

"""Rendering backend interface for a terminal or headless surface."""
abstract type AbstractBackend end

"""Return the current backend dimensions."""
function backend_size end

"""Return the rendering capabilities visible to widgets for this backend."""
backend_capabilities(::AbstractBackend) = TerminalCapabilities()

"""Present ordered changes and the authoritative completed buffer."""
function present! end

"""Set an opt-in terminal title when supported by the backend."""
set_terminal_title!(::AbstractBackend, ::AbstractString; kwargs...) = false

@enum MouseTrackingMode::UInt8 begin
    BasicMouseTracking
    ButtonMotionTracking
    AnyMotionTracking
end

"""Declarative terminal modes managed by an application view.

`nothing` leaves a mode under the backend's existing session options.
"""
struct TerminalModeRequest
    alternate_screen::Union{Nothing,Bool}
    mouse_capture::Union{Nothing,Bool}
    mouse_tracking::Union{Nothing,MouseTrackingMode}
    focus_reporting::Union{Nothing,Bool}
    bracketed_paste::Union{Nothing,Bool}
end

function TerminalModeRequest(;
    alternate_screen::Union{Nothing,Bool}=nothing,
    mouse_capture::Union{Nothing,Bool}=nothing,
    mouse_tracking::Union{Nothing,MouseTrackingMode}=nothing,
    focus_reporting::Union{Nothing,Bool}=nothing,
    bracketed_paste::Union{Nothing,Bool}=nothing,
)
    TerminalModeRequest(
        alternate_screen,
        mouse_capture,
        mouse_tracking,
        focus_reporting,
        bracketed_paste,
    )
end

"""Apply explicitly managed terminal modes and return whether state changed."""
apply_terminal_modes!(::AbstractBackend, ::TerminalModeRequest) = false

function _validated_terminal_title(title::AbstractString, maximum_bytes::Integer)
    maximum_bytes > 0 || throw(ArgumentError("maximum terminal title size must be positive"))
    value = String(title)
    ncodeunits(value) <= maximum_bytes ||
        throw(ArgumentError("terminal title exceeds configured maximum"))
    any(character -> begin
        codepoint = Int(character)
        codepoint < 0x20 || 0x7f <= codepoint <= 0x9f
    end, value) && throw(ArgumentError("terminal title contains a control character"))
    value
end

function _write_terminal_title!(
    output::IO,
    title::AbstractString;
    maximum_bytes::Integer=1024,
)
    value = _validated_terminal_title(title, maximum_bytes)
    print(output, "\e]2;", value, "\e\\")
    flush(output)
    true
end

"""A primary terminal-session failure accompanied by a cleanup failure."""
struct TerminalSessionError <: Exception
    primary::CapturedException
    cleanup::CapturedException
end

"""One or more failures occurred while manually restoring terminal state."""
struct TerminalResetError <: Exception
    failures::Vector{CapturedException}
end

function Base.showerror(io::IO, error::TerminalResetError)
    print(io, "terminal reset failed")
    for (index, failure) in enumerate(error.failures)
        print(io, index == 1 ? ": " : "\nadditional reset failure: ")
        showerror(io, failure)
    end
end

function Base.showerror(io::IO, error::TerminalSessionError)
    print(io, "terminal operation failed: ")
    showerror(io, error.primary)
    print(io, "\nterminal cleanup also failed: ")
    showerror(io, error.cleanup)
end

"""Flush pending backend output."""
flush!(::AbstractBackend) = nothing

"""Enter backend-specific interactive state."""
enter!(::AbstractBackend) = nothing

"""Leave backend-specific interactive state."""
leave!(::AbstractBackend) = nothing

"""Best-effort manual recovery for terminal modes after abnormal termination."""
function reset_terminal!(
    output::IO=stdout;
    controller=nothing,
    leave_alternate_screen::Bool=true,
    newline::Bool=true,
    force::Bool=output isa Base.TTY,
)
    failures = CapturedException[]
    if force
        try
            print(
                output,
                "\e[?2026l",
                "\e[?1006l\e[?1003l\e[?1002l\e[?1000l",
                "\e[?1004l\e[?2004l",
                "\e[<u",
                "\e[0m\e]8;;\e\\",
                "\e[?6l\e[?7h\e[?1l\e>",
                "\e[0 q\e[?25h",
            )
            leave_alternate_screen && print(output, "\e[?1049l")
            newline && print(output, "\r\n")
            flush(output)
        catch error
            push!(failures, CapturedException(error, catch_backtrace()))
        end
    end
    if !isnothing(controller)
        try
            set_raw!(controller, false)
        catch error
            push!(failures, CapturedException(error, catch_backtrace()))
        end
    end
    isempty(failures) || throw(TerminalResetError(failures))
    force
end

include("backends/ansi.jl")
include("backends/inline.jl")

"""Headless backend that stores the last completed frame."""
mutable struct TestBackend <: AbstractBackend
    screen::Buffer
    cursor::Union{Nothing,CursorRequest}
    last_changes::Vector{CellChange}
    frame_count::UInt64
    capabilities::TerminalCapabilities
end

function TestBackend(
    height::Integer=24,
    width::Integer=80;
    capabilities::TerminalCapabilities=TerminalCapabilities(),
)
    TestBackend(Buffer(height, width), nothing, CellChange[], 0, capabilities)
end

TestBackend(
    screen::Buffer,
    cursor::Union{Nothing,CursorRequest},
    last_changes::Vector{CellChange},
    frame_count::Integer,
) = TestBackend(screen, cursor, last_changes, UInt64(frame_count), TerminalCapabilities())

backend_size(backend::TestBackend) = Size(size(backend.screen)...)
backend_capabilities(backend::TestBackend) = backend.capabilities

function present!(
    backend::TestBackend,
    changes::AbstractVector{CellChange},
    completed::Buffer,
    cursor::Union{Nothing,CursorRequest},
)
    backend.frame_count == typemax(UInt64) &&
        throw(OverflowError("test backend frame counter exhausted"))
    if !isempty(changes) || backend.screen != completed
        backend.screen = copy(completed)
    end
    backend.cursor = cursor
    backend.last_changes = collect(changes)
    backend.frame_count += 1
    nothing
end

"""Resize a headless backend before the next draw."""
function resize_backend!(backend::TestBackend, height::Integer, width::Integer)
    backend.screen = Buffer(height, width)
    backend.cursor = nothing
    empty!(backend.last_changes)
    backend
end

"""Allocation bounds applied to backend-reported terminal dimensions."""
struct TerminalLimits
    maximum_height::Int
    maximum_width::Int
    maximum_cells::Int

    function TerminalLimits(;
        maximum_height::Integer=4096,
        maximum_width::Integer=8192,
        maximum_cells::Integer=4_194_304,
    )
        maximum_height > 0 || throw(ArgumentError("maximum terminal height must be positive"))
        maximum_width > 0 || throw(ArgumentError("maximum terminal width must be positive"))
        maximum_cells > 0 || throw(ArgumentError("maximum terminal cell count must be positive"))
        maximum_height <= typemax(Int) || throw(ArgumentError("maximum terminal height is too large"))
        maximum_width <= typemax(Int) || throw(ArgumentError("maximum terminal width is too large"))
        maximum_cells <= typemax(Int) || throw(ArgumentError("maximum terminal cell count is too large"))
        new(Int(maximum_height), Int(maximum_width), Int(maximum_cells))
    end
end

"""Backend dimensions exceeded configured terminal allocation limits."""
struct TerminalSizeError <: Exception
    requested::Size
    limits::TerminalLimits
end

function Base.showerror(io::IO, error::TerminalSizeError)
    size = error.requested
    limits = error.limits
    print(
        io,
        "terminal size ", size.height, 'x', size.width,
        " exceeds limits ", limits.maximum_height, 'x', limits.maximum_width,
        " with at most ", limits.maximum_cells, " cells",
    )
end

function _validate_terminal_size(size::Size, limits::TerminalLimits)
    within_dimensions = size.height <= limits.maximum_height &&
                        size.width <= limits.maximum_width
    within_cells = size.height == 0 || size.width <= limits.maximum_cells ÷ size.height
    within_dimensions && within_cells || throw(TerminalSizeError(size, limits))
    size
end

"""A terminal with previous and current buffers for deterministic diff rendering."""
mutable struct Terminal{B<:AbstractBackend}
    backend::B
    previous::Buffer
    current::Buffer
    frame_count::UInt64
    force_redraw::Bool
    limits::TerminalLimits
end

function Terminal(
    backend::B;
    limits::TerminalLimits=TerminalLimits(),
) where {B<:AbstractBackend}
    terminal_size = _validate_terminal_size(backend_size(backend), limits)
    Terminal(
        backend,
        Buffer(terminal_size.height, terminal_size.width),
        Buffer(terminal_size.height, terminal_size.width),
        UInt64(0),
        true,
        limits,
    )
end

function Terminal(
    backend::B,
    previous::Buffer,
    current::Buffer,
    frame_count::UInt64,
    force_redraw::Bool,
) where {B<:AbstractBackend}
    limits = TerminalLimits()
    _validate_terminal_size(Size(size(previous)...), limits)
    _validate_terminal_size(Size(size(current)...), limits)
    Terminal{B}(backend, previous, current, frame_count, force_redraw, limits)
end

"""Replace terminal allocation limits after validating current backend dimensions."""
function set_terminal_limits!(terminal::Terminal, limits::TerminalLimits)
    _validate_terminal_size(backend_size(terminal.backend), limits)
    terminal.limits = limits
    terminal
end

"""Manually recover the terminal backend and invalidate the next frame."""
function reset_terminal!(terminal::Terminal; kwargs...)
    try
        reset_terminal!(terminal.backend; kwargs...)
    finally
        terminal.force_redraw = true
    end
end

set_terminal_title!(terminal::Terminal, title::AbstractString; kwargs...) =
    set_terminal_title!(terminal.backend, title; kwargs...)

"""Summary of a completed terminal draw."""
struct DrawResult{T}
    value::T
    changed_cells::Int
    frame_count::UInt64
end

"""Force the next draw to emit the complete frame."""
function force_redraw!(terminal::Terminal)
    terminal.force_redraw = true
    terminal
end

function _synchronize_size!(terminal::Terminal)
    terminal_size = _validate_terminal_size(backend_size(terminal.backend), terminal.limits)
    if size(terminal.current) != (terminal_size.height, terminal_size.width)
        terminal.previous = Buffer(terminal_size.height, terminal_size.width)
        terminal.current = Buffer(terminal_size.height, terminal_size.width)
        terminal.force_redraw = true
    end
    nothing
end

"""Render, diff, and present one complete frame."""
function draw!(draw_frame::Function, terminal::Terminal)
    terminal.frame_count == typemax(UInt64) &&
        throw(OverflowError("terminal frame counter exhausted"))
    _synchronize_size!(terminal)
    clear!(terminal.current)
    frame = Frame(
        terminal.current,
        terminal.frame_count;
        capabilities=backend_capabilities(terminal.backend),
    )
    value = draw_frame(frame)
    changes = diff_buffers(terminal.previous, terminal.current; force=terminal.force_redraw)
    try
        present!(terminal.backend, changes, terminal.current, frame.cursor)
        flush!(terminal.backend)
    catch
        terminal.force_redraw = true
        rethrow()
    end
    terminal.previous, terminal.current = terminal.current, terminal.previous
    terminal.frame_count += 1
    terminal.force_redraw = false
    DrawResult(value, length(changes), terminal.frame_count)
end

function _leave_after_failure!(terminal::Terminal, primary::CapturedException)
    try
        leave!(terminal.backend)
    catch cleanup_error
        throw(TerminalSessionError(
            primary,
            CapturedException(cleanup_error, catch_backtrace()),
        ))
    end
    return nothing
end

"""Run an operation while guaranteeing backend cleanup, including partial entry."""
function with_terminal(operation::Function, terminal::Terminal)
    try
        enter!(terminal.backend)
    catch error
        _leave_after_failure!(
            terminal,
            CapturedException(error, catch_backtrace()),
        )
        rethrow()
    end
    result = try
        operation(terminal)
    catch error
        _leave_after_failure!(
            terminal,
            CapturedException(error, catch_backtrace()),
        )
        rethrow()
    end
    leave!(terminal.backend)
    return result
end

export AbstractBackend,
       AbstractTerminalController,
       AnsiBackend,
       DrawResult,
       InlineBackend,
       MouseTrackingMode,
       BasicMouseTracking,
       ButtonMotionTracking,
       AnyMotionTracking,
       Terminal,
       TerminalCapabilities,
       TerminalLimits,
       TerminalModeRequest,
       TerminalOptions,
       TerminalResetError,
       TerminalSessionError,
       TerminalSizeError,
       TestBackend,
       JuliaTTYController,
       NoopTerminalController,
       backend_capabilities,
       backend_size,
       apply_terminal_modes!,
       detect_color_level,
       draw!,
       enter!,
       flush!,
       force_redraw!,
       leave!,
       present!,
       resize_backend!,
       reset_terminal!,
       set_terminal_limits!,
       set_raw!,
       set_terminal_title!,
       with_terminal

end
