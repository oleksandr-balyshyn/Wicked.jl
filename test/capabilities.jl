@testset "Rendering capabilities" begin
    @testset "frame defaults and compatibility" begin
        buffer = Buffer(2, 3)
        frame = Frame(buffer)
        @test frame.capabilities == TerminalCapabilities()

        cursor = CursorRequest(Position(1, 1))
        compatible = Frame(buffer, buffer.area, 4, cursor)
        @test compatible.frame_count == 4
        @test compatible.cursor === cursor
        @test compatible.capabilities == TerminalCapabilities()
    end

    @testset "backend capability propagation" begin
        capabilities = TerminalCapabilities(
            color_level=:truecolor,
            mouse=false,
            focus=false,
            bracketed_paste=false,
            synchronized_updates=true,
            enhanced_keyboard=true,
        )
        backend = TestBackend(2, 4; capabilities)
        terminal = Terminal(backend)
        observed = Ref{TerminalCapabilities}()

        draw!(terminal) do frame
            observed[] = frame.capabilities
            render!(frame, Label("ok"), frame.area)
        end

        @test backend_capabilities(backend) === capabilities
        @test observed[] === capabilities
        @test backend.screen[1, 1].grapheme == "o"
    end

    @testset "third-party backend default" begin
        backend = InjectedBackend()
        capabilities = backend_capabilities(backend)
        @test capabilities == TerminalCapabilities()
        @test capabilities.color_level == :ansi16
    end
end
