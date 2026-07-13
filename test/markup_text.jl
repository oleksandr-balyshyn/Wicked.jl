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

    @testset "semantic markdown roles" begin
        heading = MarkupText("# Heading"; width=24)
        @test heading.block_roles == (:heading_1,)
        @test heading.inline_roles == (:heading_1,)
        @test has_block_role(heading, :heading_1)
        @test has_inline_role(heading, :heading_1)
        @test !has_inline_role(heading, :strong)
        heading_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(heading, nothing)
        @test heading_descriptor.role == HeadingRole
        @test heading_descriptor.metadata[:block_roles] == (:heading_1,)

        mixed = MarkupText("# Heading\n\nBody with **strong** text"; width=24)
        @test :heading_1 in mixed.block_roles
        @test :paragraph in mixed.block_roles
        @test :strong in mixed.inline_roles
        @test has_block_role(mixed, :paragraph)
        @test has_inline_role(mixed, :strong)
        mixed_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(mixed, nothing)
        @test mixed_descriptor.role == ParagraphRole
        @test :heading_1 in mixed_descriptor.metadata[:block_roles]
        @test :strong in mixed_descriptor.metadata[:inline_roles]
    end

    @testset "validation" begin
        @test_throws ArgumentError MarkupText("bad"; width=0)
        @test_throws ArgumentError MarkupText("bad"; vertical_scroll=-1)
    end
end
