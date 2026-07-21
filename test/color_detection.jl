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

    @testset "adaptive color and downsampling" begin
        # adaptive_color picks the variant for the background
        @test Wicked.adaptive_color(AnsiColor(7), AnsiColor(0); dark_background=true) ==
              AnsiColor(0)
        @test Wicked.adaptive_color(AnsiColor(7), AnsiColor(0); dark_background=false) ==
              AnsiColor(7)
        @test Wicked.adaptive_color("white", "black"; dark_background=true) == AnsiColor(0)
        @test Wicked.adaptive_color("#ffffff", "#000000"; dark_background=false) ==
              RGBColor(255, 255, 255)

        white = RGBColor(255, 255, 255)
        # truecolor is unchanged; 256 uses the 6x6x6 cube; 16 uses intensity+dominant
        @test Wicked.downsample_color(white, :truecolor) == white
        @test Wicked.downsample_color(white, :ansi256) == IndexedColor(231)
        @test Wicked.downsample_color(white, :ansi16) == AnsiColor(15)
        @test Wicked.downsample_color(RGBColor(0, 0, 0), :ansi16) == AnsiColor(0)
        @test Wicked.downsample_color(RGBColor(200, 0, 0), :ansi16) == AnsiColor(1)
        @test Wicked.downsample_color(white, :none) == DefaultColor()
        # indexed folds into the 16 range only for :ansi16
        @test Wicked.downsample_color(IndexedColor(200), :ansi16) == AnsiColor(200 % 16)
        @test Wicked.downsample_color(IndexedColor(200), :ansi256) == IndexedColor(200)
        @test Wicked.downsample_color(AnsiColor(3), :ansi16) == AnsiColor(3)
        @test_throws ArgumentError Wicked.downsample_color(white, :bogus)
    end
end
