@testset "MarkupText widget" begin
    @testset "role-based default styles" begin
        buffer = Buffer(1, 24)
        render!(buffer, MarkupText("**bold**"; width=24), buffer.area)
        @test buffer[1, 1].grapheme == "b"
        @test buffer[1, 1].style.modifiers == BOLD

        render!(buffer, MarkupText("*emphasis*"; width=24), buffer.area)
        @test buffer[1, 1].grapheme == "e"
        @test buffer[1, 1].style.modifiers == ITALIC

        render!(buffer, MarkupText("`code`"; width=24), buffer.area)
        @test buffer[1, 1].grapheme == "c"
        @test buffer[1, 1].style.modifiers == DIM

        render!(buffer, MarkupText("# Heading"; width=24), buffer.area)
        @test buffer[1, 1].grapheme == "H"
        @test buffer[1, 1].style.modifiers == (BOLD | UNDERLINE)
    end

    @testset "role-style override and markers" begin
        overrides = Dict(:strong => Style(foreground=AnsiColor(1), modifiers=DIM))
        buffer = Buffer(1, 24)
        render!(
            buffer,
            MarkupText("**strong**"; role_styles=overrides, width=24),
            buffer.area,
        )

        @test buffer[1, 1].style.foreground == AnsiColor(1)
        @test buffer[1, 1].style.modifiers == (BOLD | DIM)
        @test buffer[1, 1].grapheme == "s"

        render!(buffer, MarkupText("- item"; width=24), buffer.area)
        @test buffer[1, 1].grapheme == "-"
        @test buffer[1, 1].style.modifiers == BOLD
    end

    @testset "measurement and scrolling" begin
        markup = MarkupText(
            "one\ntwo\nthree";
            wrap=WordWrap,
            width=4096,
            vertical_scroll=1,
        )
        buffer = Buffer(1, 6)
        render!(buffer, markup, buffer.area)

        @test [buffer[1, column].grapheme for column in 1:5] ==
              ["t", "w", "o", " ", " "]
    end

    @testset "validation" begin
        @test_throws ArgumentError MarkupText("bad"; width=0)
        @test_throws ArgumentError MarkupText("bad"; vertical_scroll=-1)
    end
end
