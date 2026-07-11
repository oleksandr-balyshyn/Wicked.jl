@testset "Terminal color detection" begin
    redirected = IOBuffer()

    @test detect_color_level(
        redirected;
        environment=Dict("FORCE_COLOR" => "0", "COLORTERM" => "truecolor"),
        is_tty=false,
    ) == :none
    @test detect_color_level(
        redirected;
        environment=Dict("FORCE_COLOR" => ""),
        is_tty=false,
    ) == :ansi16
    @test detect_color_level(
        redirected;
        environment=Dict("FORCE_COLOR" => "2", "NO_COLOR" => "1"),
        is_tty=false,
    ) == :ansi256
    @test detect_color_level(
        redirected;
        environment=Dict("FORCE_COLOR" => "truecolor"),
        is_tty=false,
    ) == :truecolor

    @test detect_color_level(
        redirected;
        environment=Dict("NO_COLOR" => ""),
        is_tty=true,
    ) == :none
    @test detect_color_level(
        redirected;
        environment=Dict("TERM" => "dumb", "COLORTERM" => "truecolor"),
        is_tty=true,
    ) == :none
    @test detect_color_level(
        redirected;
        environment=Dict("TERM" => "xterm", "COLORTERM" => "24bit"),
        is_tty=true,
    ) == :truecolor
    @test detect_color_level(
        redirected;
        environment=Dict("TERM" => "screen-256color"),
        is_tty=true,
    ) == :ansi256
    @test detect_color_level(
        redirected;
        environment=Dict("TERM" => "xterm"),
        is_tty=true,
    ) == :ansi16
    @test detect_color_level(
        redirected;
        environment=Dict("TERM" => "xterm-256color"),
        is_tty=false,
    ) == :none

    automatic = AnsiBackend(IOBuffer(), IOBuffer())
    @test automatic.capabilities.color_level == :none
    explicit = TerminalCapabilities(color_level=:truecolor)
    configured = AnsiBackend(IOBuffer(), IOBuffer(); capabilities=explicit)
    @test configured.capabilities === explicit
end
