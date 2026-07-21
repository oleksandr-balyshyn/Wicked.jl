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
        @test text_width("👨‍👩‍👧‍👦", narrow) == 2
        @test text_width("🇺🇦", narrow) == 2
        @test text_width("1️⃣", narrow) == 1
        @test text_width("\n\t", narrow) == 0
        @test text_width("A·", narrow) == 2
        @test text_width("A·", wide_ambiguous) == 3
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

        ascii = Buffer(2, 4)
        position = draw_text!(ascii, 1, 1, "ab\ncd")
        @test plain_snapshot(ascii) == "ab\ncd"
        @test position == Position(2, 3)

        @test_throws ArgumentError Cell("\0")
        @test_throws ArgumentError Cell("ab")
        @test_throws ArgumentError Cell("", Style(), 0x01, false)
        @test_throws ArgumentError Cell("x", Style(), 0x00, true)
        @test_throws ArgumentError Cell("ab", Style(), 0x01, false)
        styled_ascii = Buffer(1, 3)
        ascii_style = Style(foreground=AnsiColor(2), modifiers=BOLD)
        draw_text!(styled_ascii, 1, 1, "abc"; style=ascii_style)
        @test [styled_ascii[1, column].grapheme for column in 1:3] == ["a", "b", "c"]
        @test all(column -> styled_ascii[1, column].style == ascii_style, 1:3)
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

        dense_previous = Buffer(9, 8; row=3, column=5)
        dense_current = Buffer(9, 8; row=3, column=5, cell=Cell("x"))
        dense_changes = diff_buffers(dense_previous, dense_current)
        @test length(dense_changes) == 72
        @test first(dense_changes).position == Position(3, 5)
        @test dense_changes[64].position == Position(10, 12)
        @test dense_changes[65].position == Position(11, 5)
        @test last(dense_changes).position == Position(11, 12)
        @test all(change -> change.cell == Cell("x"), dense_changes)

        clear!(current)
        @test current == previous
    end
end
