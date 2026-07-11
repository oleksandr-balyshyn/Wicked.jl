@testset "Terminal allocation limits" begin
    @testset "configuration validation" begin
        @test_throws ArgumentError TerminalLimits(maximum_height=0)
        @test_throws ArgumentError TerminalLimits(maximum_width=0)
        @test_throws ArgumentError TerminalLimits(maximum_cells=0)

        limits = TerminalLimits(maximum_height=10, maximum_width=20, maximum_cells=100)
        @test limits.maximum_height == 10
        @test limits.maximum_width == 20
        @test limits.maximum_cells == 100
    end

    @testset "construction rejects dimensions before allocation" begin
        oversized = InjectedBackend(height=100, width=100)
        limits = TerminalLimits(maximum_height=50, maximum_width=50, maximum_cells=2_500)
        error = try
            Terminal(oversized; limits)
            nothing
        catch caught
            caught
        end
        @test error isa TerminalSizeError
        @test error.requested == Size(100, 100)

        cells_limited = InjectedBackend(height=3, width=3)
        @test_throws TerminalSizeError Terminal(
            cells_limited;
            limits=TerminalLimits(maximum_height=10, maximum_width=10, maximum_cells=8),
        )
    end

    @testset "resize is rejected without replacing buffers" begin
        backend = InjectedBackend(height=2, width=3)
        limits = TerminalLimits(maximum_height=4, maximum_width=5, maximum_cells=20)
        terminal = Terminal(backend; limits)
        previous_size = size(terminal.previous)
        current_size = size(terminal.current)

        backend.size = Size(5, 5)
        @test_throws TerminalSizeError draw!(terminal) do frame
            render!(frame, Label("unsafe"), frame.area)
        end
        @test size(terminal.previous) == previous_size
        @test size(terminal.current) == current_size
        @test terminal.frame_count == 0

        relaxed = TerminalLimits(maximum_height=8, maximum_width=8, maximum_cells=64)
        @test set_terminal_limits!(terminal, relaxed) === terminal
        draw!(terminal) do frame
            render!(frame, Label("safe"), frame.area)
        end
        @test size(terminal.previous) == (5, 5)
    end
end
