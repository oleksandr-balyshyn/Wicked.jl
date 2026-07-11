"""Bounded ANSI viewport that preserves output preceding the application."""
mutable struct InlineBackend{O<:IO} <: AbstractBackend
    output::O
    viewport::Size
    capabilities::TerminalCapabilities
    interactive::Bool
    active::Bool
    allocated_height::Int
end

function InlineBackend(
    output::O=stdout;
    height::Integer=1,
    width::Union{Nothing,Integer}=nothing,
    interactive::Bool=output isa Base.TTY,
    capabilities::TerminalCapabilities=TerminalCapabilities(
        color_level=detect_color_level(output; is_tty=interactive),
        mouse=false,
        focus=false,
        bracketed_paste=false,
    ),
) where {O<:IO}
    height > 0 || throw(ArgumentError("inline viewport height must be positive"))
    detected_width = isnothing(width) ? displaysize(output)[2] : width
    detected_width > 0 || throw(ArgumentError("inline viewport width must be positive"))
    InlineBackend{O}(
        output,
        Size(height, detected_width),
        capabilities,
        interactive,
        false,
        0,
    )
end

backend_size(backend::InlineBackend) = backend.viewport
backend_capabilities(backend::InlineBackend) = backend.capabilities
flush!(backend::InlineBackend) = flush(backend.output)

function set_terminal_title!(
    backend::InlineBackend,
    title::AbstractString;
    maximum_bytes::Integer=1024,
)
    backend.interactive && backend.capabilities.terminal_title || return false
    _write_terminal_title!(backend.output, title; maximum_bytes)
end

function _reserve_inline_rows!(backend::InlineBackend, height::Int)
    height <= backend.allocated_height && return nothing
    io = backend.output
    print(io, "\e8")
    backend.allocated_height > 1 && print(io, "\e[", backend.allocated_height - 1, 'B')
    for _ in (backend.allocated_height + 1):height
        print(io, '\n')
    end
    print(io, "\e8")
    backend.allocated_height = height
    nothing
end

function enter!(backend::InlineBackend)
    backend.active && return nothing
    backend.active = true
    backend.allocated_height = 1
    if backend.interactive
        try
            print(backend.output, "\e7")
            backend.capabilities.enhanced_keyboard && print(backend.output, "\e[>3u")
            _reserve_inline_rows!(backend, backend.viewport.height)
            flush(backend.output)
        catch
            backend.active = false
            backend.allocated_height = 0
            rethrow()
        end
    end
    nothing
end

function leave!(backend::InlineBackend)
    backend.active || return nothing
    failure = nothing
    if backend.interactive
        try
            io = backend.output
            print(io, "\e[0m\e]8;;\e\\")
            backend.capabilities.enhanced_keyboard && print(io, "\e[<u")
            print(io, "\e8")
            backend.allocated_height > 1 && print(io, "\e[", backend.allocated_height - 1, 'B')
            print(io, "\r\n\e[?25h")
            flush(io)
        catch error
            failure = error
        end
    end
    backend.active = false
    backend.allocated_height = 0
    isnothing(failure) || throw(failure)
    nothing
end

function reset_terminal!(
    backend::InlineBackend;
    leave_alternate_screen::Bool=false,
    newline::Bool=true,
    force::Bool=true,
)
    try
        reset_terminal!(
            backend.output;
            leave_alternate_screen,
            newline,
            force,
        )
    finally
        backend.active = false
        backend.allocated_height = 0
    end
end

function resize_backend!(backend::InlineBackend, height::Integer, width::Integer)
    height > 0 || throw(ArgumentError("inline viewport height must be positive"))
    width > 0 || throw(ArgumentError("inline viewport width must be positive"))
    if backend.active && backend.interactive
        _reserve_inline_rows!(backend, Int(height))
        flush(backend.output)
    end
    backend.viewport = Size(height, width)
    backend
end

function _write_inline_position(io::IO, position::Position)
    print(io, "\e8")
    position.row > 1 && print(io, "\e[", position.row - 1, 'B')
    position.column > 1 && print(io, "\e[", position.column - 1, 'C')
    nothing
end

function _write_inline_cursor(io::IO, cursor::Union{Nothing,CursorRequest})
    if isnothing(cursor) || !cursor.visible
        print(io, "\e[?25l")
        return
    end
    _write_inline_position(io, cursor.position)
    shape_code = cursor.shape == BlockCursor ? 2 :
                 cursor.shape == UnderlineCursor ? 4 :
                 cursor.shape == BarCursor ? 6 : 0
    shape_code != 0 && print(io, "\e[", shape_code, " q")
    print(io, "\e[?25h")
end

function _linear_buffer_snapshot(buffer::Buffer)
    rows = String[]
    for row in buffer.area.row:(buffer.area.row + buffer.area.height - 1)
        output = IOBuffer()
        for column in buffer.area.column:(buffer.area.column + buffer.area.width - 1)
            cell = buffer[row, column]
            cell.continuation || print(output, cell.grapheme)
        end
        push!(rows, rstrip(String(take!(output))))
    end
    join(rows, '\n')
end

function present!(
    backend::InlineBackend,
    changes::AbstractVector{CellChange},
    completed::Buffer,
    cursor::Union{Nothing,CursorRequest},
)
    isempty(changes) && return nothing
    io = backend.output
    if !backend.interactive
        print(io, _linear_buffer_snapshot(completed), '\n')
        return nothing
    end

    backend.active || enter!(backend)
    synchronized = backend.capabilities.synchronized_updates
    synchronized && print(io, "\e[?2026h")
    expected = nothing
    active_style = nothing
    active_hyperlink = nothing
    function cleanup_protocol!()
        !isnothing(active_hyperlink) && _write_hyperlink(io, nothing)
        synchronized && print(io, "\e[?2026l")
        nothing
    end
    try
        for change in changes
            cell = change.cell
            cell.continuation && continue
            position = change.position
            if isnothing(expected) || expected != position
                _write_inline_position(io, position)
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
        _write_inline_cursor(io, cursor)
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
