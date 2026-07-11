@testset "Core rendering foundation" begin
    @testset "geometry boundaries" begin
        area = Rect(2, 3, 4, 5)

        @test intersection(area, Rect(20, 30, 1, 1)) == Rect(20, 30, 0, 0)
        @test inset(area, Margin(10)) == Rect(6, 8, 0, 0)
        @test_throws ArgumentError Position(0, 1)
        @test_throws ArgumentError Margin(0, -1, 0, 0)
        @test_throws OverflowError Rect(typemax(Int), 1, 1, 1)
    end

    @testset "Unicode width policy" begin
        narrow = UnicodeWidthPolicy(1)
        wide_ambiguous = UnicodeWidthPolicy(2)

        @test grapheme_width(narrow, "") == 0
        @test grapheme_width(narrow, "界") == 2
        @test grapheme_width(narrow, "α") == 1
        @test grapheme_width(wide_ambiguous, "α") == 2
        @test grapheme_width(narrow, "e\u0301") == 1
        @test grapheme_width(wide_ambiguous, "e\u0301") == 1
        @test text_width("👩‍💻", narrow) == 2
        @test_throws ArgumentError UnicodeWidthPolicy(0)
    end

    @testset "cells and clipping" begin
        buffer = Buffer(1, 4)
        draw_grapheme!(buffer, 1, 1, "界")

        @test buffer[1, 1].grapheme == "界"
        @test buffer[1, 1].width == 2
        @test buffer[1, 2].continuation

        buffer[1, 2] = Cell("x")
        @test buffer[1, 1] == Cell()
        @test buffer[1, 2] == Cell("x")

        clipped = Buffer(1, 2)
        draw_text!(clipped, 1, 1, "a界")
        @test clipped[1, 1] == Cell("a")
        @test clipped[1, 2] == Cell()

        tabbed = Buffer(1, 5)
        draw_text!(tabbed, 1, 1, "a\tb"; tab_width=4)
        @test tabbed[1, 5] == Cell("b")

        @test_throws ArgumentError Cell("\0")
        @test_throws ArgumentError Cell("ab")
    end

    @testset "buffer equality and diffs" begin
        previous = Buffer(2, 3)
        current = copy(previous)

        @test previous == current
        @test isempty(diff_buffers(previous, current))

        current[1, 3] = Cell("a")
        current[2, 1] = Cell("b")
        changes = diff_buffers(previous, current)

        @test [(change.position.row, change.position.column) for change in changes] ==
              [(1, 3), (2, 1)]
        @test [change.cell.grapheme for change in changes] == ["a", "b"]
        @test length(diff_buffers(previous, current; force=true)) == 6
        @test length(diff_buffers(Buffer(1, 1), Buffer(2, 2))) == 4

        clear!(current)
        @test current == previous
    end
end
