mutable struct InjectedBackend <: Wicked.Backends.AbstractBackend
    size::Size
    enter_count::Int
    leave_count::Int
    present_count::Int
    flush_count::Int
    fail_enter::Bool
    fail_leave::Bool
    fail_present::Bool
    fail_flush::Bool
end

InjectedBackend(; height=2, width=3, fail_enter=false, fail_leave=false, fail_present=false, fail_flush=false) =
    InjectedBackend(Size(height, width), 0, 0, 0, 0, fail_enter, fail_leave, fail_present, fail_flush)

Wicked.Backends.backend_size(backend::InjectedBackend) = backend.size

function Wicked.Backends.enter!(backend::InjectedBackend)
    backend.enter_count += 1
    backend.fail_enter && error("injected enter failure")
    nothing
end

function Wicked.Backends.leave!(backend::InjectedBackend)
    backend.leave_count += 1
    backend.fail_leave && error("injected leave failure")
    nothing
end

function Wicked.Backends.present!(backend::InjectedBackend, changes, completed, cursor)
    backend.present_count += 1
    backend.fail_present && error("injected present failure")
    nothing
end

function Wicked.Backends.flush!(backend::InjectedBackend)
    backend.flush_count += 1
    backend.fail_flush && error("injected flush failure")
    nothing
end

@testset "Backends and terminal lifecycle" begin
    @testset "draw, diff, resize, and force" begin
        backend = TestBackend(2, 3)
        terminal = Terminal(backend)

        first_draw = draw!(terminal) do frame
            render!(frame, Label("x"), frame.area)
            :first
        end
        @test first_draw.value == :first
        @test first_draw.changed_cells == 6
        @test terminal.frame_count == 1
        @test backend.screen[1, 1] == Cell("x")
        completed_screen = backend.screen

        unchanged = draw!(terminal) do frame
            render!(frame, Label("x"), frame.area)
        end
        @test unchanged.changed_cells == 0
        @test backend.screen === completed_screen

        authoritative = copy(backend.screen)
        authoritative[1, 2] = Cell("y")
        present!(backend, CellChange[], authoritative, nothing)
        @test backend.screen == authoritative
        @test backend.screen !== completed_screen

        force_redraw!(terminal)
        forced = draw!(terminal) do frame
            render!(frame, Label("x"), frame.area)
        end
        @test forced.changed_cells == 6

        resize_backend!(backend, 1, 4)
        resized = draw!(terminal) do frame
            render!(frame, Label("z"), frame.area)
        end
        @test resized.changed_cells == 4
        @test size(backend.screen) == (1, 4)
    end

    @testset "failed presentation is not committed" begin
        backend = InjectedBackend(fail_present=true)
        terminal = Terminal(backend)
        @test_throws ErrorException draw!(terminal) do frame
            render!(frame, Label("x"), frame.area)
        end
        @test terminal.frame_count == 0
        @test terminal.previous == Buffer(2, 3)
        @test terminal.force_redraw

        backend.fail_present = false
        recovered = draw!(terminal) do frame
            render!(frame, Label("x"), frame.area)
        end
        @test recovered.changed_cells == 6

        backend.fail_flush = true
        @test_throws ErrorException draw!(terminal) do frame
            render!(frame, Label("y"), frame.area)
        end
        @test terminal.frame_count == 1
        @test terminal.force_redraw
    end

    @testset "session cleanup and paired failures" begin
        backend = InjectedBackend()
        terminal = Terminal(backend)
        @test with_terminal(_ -> :result, terminal) == :result
        @test (backend.enter_count, backend.leave_count) == (1, 1)

        partial = InjectedBackend(fail_enter=true)
        @test_throws ErrorException with_terminal(_ -> nothing, Terminal(partial))
        @test (partial.enter_count, partial.leave_count) == (1, 1)

        operation_failure = InjectedBackend()
        @test_throws ErrorException with_terminal(Terminal(operation_failure)) do _
            error("operation failed")
        end
        @test operation_failure.leave_count == 1

        paired = InjectedBackend(fail_leave=true)
        paired_failure = try
            with_terminal(Terminal(paired)) do _
                error("operation failed")
            end
            nothing
        catch failure
            failure
        end
        @test paired_failure isa TerminalSessionError
        @test paired_failure.primary.ex isa ErrorException
        @test paired_failure.cleanup.ex isa ErrorException
    end

    @testset "ANSI lifecycle and sanitization" begin
        output = IOBuffer()
        capabilities = TerminalCapabilities(
            mouse=true,
            focus=true,
            bracketed_paste=true,
            synchronized_updates=true,
        )
        backend = AnsiBackend(
            IOBuffer(),
            output;
            capabilities,
            controller=NoopTerminalController(),
            size=Size(2, 4),
        )
        enter!(backend)
        leave!(backend)
        first_output = String(take!(output))
        @test occursin("\e[?1049h", first_output)
        @test occursin("\e[?1049l", first_output)
        @test occursin("\e[?2004h", first_output)
        @test occursin("\e[?2004l", first_output)
        leave!(backend)
        @test isempty(take!(output))

        terminal = Terminal(backend)
        draw!(terminal) do frame
            render!(frame, Label("ok"), frame.area)
        end
        rendered = String(take!(output))
        @test occursin("\e[?2026h", rendered)
        @test occursin("\e[?2026l", rendered)

        unsafe = Terminal(AnsiBackend(
            IOBuffer(),
            IOBuffer();
            options=TerminalOptions(
                raw_mode=false,
                alternate_screen=false,
                hide_cursor=false,
                mouse_capture=false,
                focus_reporting=false,
                bracketed_paste=false,
            ),
            controller=NoopTerminalController(),
            size=Size(1, 3),
        ))
        @test_throws ArgumentError draw!(unsafe) do frame
            render!(frame, Label("x"; style=Style(hyperlink="bad\u009c")), frame.area)
        end
        @test unsafe.force_redraw
    end

    @testset "frame counter overflow" begin
        backend = TestBackend(1, 1)
        terminal = Terminal(backend)
        terminal.frame_count = typemax(UInt64)
        @test_throws OverflowError draw!(_ -> nothing, terminal)
        @test backend.frame_count == 0

        backend.frame_count = typemax(UInt64)
        @test_throws OverflowError present!(backend, CellChange[], backend.screen, nothing)
    end

    @test_throws ArgumentError TerminalCapabilities(color_level=:invalid)
end
