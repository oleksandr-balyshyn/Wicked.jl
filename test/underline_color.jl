@testset "ANSI underline colors" begin
    buffer = Buffer(1, 2)
    style = Style(
        underline_color=RGBColor(12, 34, 56),
        modifiers=UNDERLINE,
    )
    render!(buffer, Label("u"; style), buffer.area)

    truecolor = ansi_snapshot(
        buffer;
        capabilities=TerminalCapabilities(color_level=:truecolor, underline_color=true),
    )
    @test occursin("58;2;12;34;56", truecolor)
    @test occursin(";4m", truecolor)

    indexed = ansi_snapshot(
        buffer;
        capabilities=TerminalCapabilities(color_level=:ansi256, underline_color=true),
    )
    @test occursin("58;5;", indexed)
    @test !occursin("58;2;", indexed)

    fallback = ansi_snapshot(
        buffer;
        capabilities=TerminalCapabilities(color_level=:truecolor, underline_color=false),
    )
    @test !occursin("58;", fallback)
    @test occursin(";4m", fallback)

    default_style = Buffer(1, 1)
    render!(default_style, Label("x"), default_style.area)
    @test ansi_snapshot(default_style) == "x"
end
