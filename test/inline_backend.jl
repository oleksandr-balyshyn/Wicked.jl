@testset "Inline terminal backend" begin
    @testset "redirected linear fallback" begin
        output = IOBuffer()
        backend = InlineBackend(output; height=2, width=5, interactive=false)
        terminal = Terminal(backend)

        first_draw = draw!(terminal) do frame
            render!(frame, Label("hello"), frame.area)
        end
        @test first_draw.changed_cells == 10
        rendered = String(take!(output))
        @test rendered == "hello\n\n"
        @test !occursin('\e', rendered)
        @test backend.capabilities.color_level == :none

        unchanged = draw!(terminal) do frame
            render!(frame, Label("hello"), frame.area)
        end
        @test unchanged.changed_cells == 0
        @test isempty(take!(output))

        changed = draw!(terminal) do frame
            render!(frame, Label("next"), frame.area)
        end
        @test changed.changed_cells > 0
        @test String(take!(output)) == "next\n\n"
    end

    @testset "interactive bounded viewport lifecycle" begin
        output = IOBuffer()
        print(output, "before")
        backend = InlineBackend(
            output;
            height=3,
            width=8,
            interactive=true,
            capabilities=TerminalCapabilities(
                color_level=:ansi16,
                synchronized_updates=true,
            ),
        )
        terminal = Terminal(backend)

        enter!(backend)
        entered = String(take!(output))
        @test startswith(entered, "before\e7")
        @test count(==('\n'), entered) == 2
        @test !occursin("?1049h", entered)

        draw!(terminal) do frame
            render!(frame, Label("status"), frame.area)
        end
        rendered = String(take!(output))
        @test occursin("\e8", rendered)
        @test occursin("status", rendered)
        @test occursin("?2026h", rendered)
        @test occursin("?2026l", rendered)
        @test !occursin("?1049", rendered)

        resize_backend!(backend, 4, 10)
        resized = String(take!(output))
        @test count(==('\n'), resized) == 1
        draw!(terminal) do frame
            render!(frame, Label("resized"), frame.area)
        end
        @test size(terminal.previous) == (4, 10)
        take!(output)

        leave!(backend)
        left = String(take!(output))
        @test occursin("\e8\e[3B\r\n", left)
        @test occursin("?25h", left)
        leave!(backend)
        @test isempty(take!(output))
    end

    @test_throws ArgumentError InlineBackend(IOBuffer(); height=0)
    @test_throws ArgumentError InlineBackend(IOBuffer(); width=0)
end
