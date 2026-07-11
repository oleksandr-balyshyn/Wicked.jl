@testset "Terminal title operations" begin
    @testset "ANSI title emission" begin
        output = IOBuffer()
        backend = AnsiBackend(
            IOBuffer(),
            output;
            capabilities=TerminalCapabilities(terminal_title=true),
            controller=NoopTerminalController(),
            size=Size(1, 4),
        )
        @test set_terminal_title!(backend, "Wicked.jl")
        @test String(take!(output)) == "\e]2;Wicked.jl\e\\"

        terminal = Terminal(backend)
        @test set_terminal_title!(terminal, "")
        @test String(take!(output)) == "\e]2;\e\\"
    end

    @testset "capability and redirected fallback" begin
        output = IOBuffer()
        disabled = AnsiBackend(
            IOBuffer(),
            output;
            capabilities=TerminalCapabilities(terminal_title=false),
            controller=NoopTerminalController(),
            size=Size(1, 4),
        )
        @test !set_terminal_title!(disabled, "ignored")
        @test isempty(take!(output))

        redirected = InlineBackend(output; height=1, width=4, interactive=false)
        @test !set_terminal_title!(redirected, "ignored")
        @test isempty(take!(output))

        interactive = InlineBackend(output; height=1, width=4, interactive=true)
        @test set_terminal_title!(interactive, "status")
        @test String(take!(output)) == "\e]2;status\e\\"
    end

    @testset "validation" begin
        backend = AnsiBackend(
            IOBuffer(),
            IOBuffer();
            capabilities=TerminalCapabilities(terminal_title=true),
            controller=NoopTerminalController(),
            size=Size(1, 4),
        )
        @test_throws ArgumentError set_terminal_title!(backend, "bad\nvalue")
        @test_throws ArgumentError set_terminal_title!(backend, "bad\evalue")
        @test_throws ArgumentError set_terminal_title!(backend, "bad\u009cvalue")
        @test_throws ArgumentError set_terminal_title!(backend, "long"; maximum_bytes=3)
        @test_throws ArgumentError set_terminal_title!(backend, "ok"; maximum_bytes=0)
        @test_throws ArgumentError set_terminal_title!(backend, "é"; maximum_bytes=1)
        @test set_terminal_title!(backend, "é"; maximum_bytes=2)
    end
end
