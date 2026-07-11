@testset "Manual terminal recovery" begin
    @testset "raw output reset" begin
        output = IOBuffer()
        @test reset_terminal!(output; force=true, newline=false)
        rendered = String(take!(output))
        @test occursin("?2026l", rendered)
        @test occursin("?1006l", rendered)
        @test occursin("?1004l", rendered)
        @test occursin("?2004l", rendered)
        @test occursin("\e[0m", rendered)
        @test occursin("\e]8;;\e\\", rendered)
        @test occursin("?25h", rendered)
        @test occursin("?1049l", rendered)
        @test !occursin("2J", rendered)

        redirected = IOBuffer()
        @test !reset_terminal!(redirected; force=false)
        @test isempty(take!(redirected))
    end

    @testset "backend and terminal bookkeeping" begin
        output = IOBuffer()
        backend = AnsiBackend(
            IOBuffer(),
            output;
            controller=NoopTerminalController(),
            size=Size(1, 4),
        )
        enter!(backend)
        @test backend.session_state != 0
        take!(output)
        @test reset_terminal!(backend; newline=false)
        @test backend.session_state == 0
        @test occursin("?1049l", String(take!(output)))

        terminal = Terminal(backend)
        terminal.force_redraw = false
        @test reset_terminal!(terminal; newline=false)
        @test terminal.force_redraw
    end

    @testset "inline recovery preserves main-screen mode" begin
        output = IOBuffer()
        backend = InlineBackend(output; height=2, width=8, interactive=true)
        enter!(backend)
        take!(output)
        @test reset_terminal!(backend; newline=false)
        rendered = String(take!(output))
        @test !occursin("?1049l", rendered)
        @test !backend.active
        @test backend.allocated_height == 0
    end
end
