@testset "Base widgets" begin
    @testset "structure rendering" begin
        block = Block(title="Hi"; symbols=ASCII_BORDERS)
        buffer = Buffer(3, 8)
        render!(buffer, block, buffer.area)

        @test sprint(show, MIME"text/plain"(), buffer) ==
              "Buffer(3x8, origin=(1, 1))\n+-Hi---+\n|      |\n+------+"
        @test inner(block, buffer.area) == Rect(2, 2, 1, 6)
        @test measure(block, Rect(1, 1, 10, 20)) == Size(2, 6)

        clipped = Buffer(2, 4)
        render!(clipped, block, Rect(1, 1, 3, 8))
        @test sprint(show, MIME"text/plain"(), clipped) ==
              "Buffer(2x4, origin=(1, 1))\n+-Hi\n|   "

        untouched = copy(clipped)
        render!(clipped, block, Rect(1, 1, 0, 0))
        @test clipped == untouched
    end

    @testset "text and rules" begin
        truncated = Buffer(1, 3)
        render!(truncated, Label("Wicked"; ellipsis="…"), truncated.area)
        @test [truncated[1, column].grapheme for column in 1:3] == ["W", "i", "…"]
        @test measure(Label("hello"), Rect(1, 1, 2, 3)) == Size(1, 3)

        wrapped = Buffer(2, 4)
        render!(wrapped, Paragraph("one two"), wrapped.area)
        @test sprint(show, MIME"text/plain"(), wrapped) ==
              "Buffer(2x4, origin=(1, 1))\none \ntwo "

        horizontal = Buffer(3, 5)
        render!(horizontal, Rule(HorizontalRule; symbol="-"), horizontal.area)
        @test [horizontal[2, column].grapheme for column in 1:5] == fill("-", 5)
        @test measure(Rule(), Rect(1, 1, 3, 5)) == Size(1, 5)
        divider = Divider(VerticalRule; symbol="|")
        vertical = Buffer(3, 5)
        render!(vertical, divider, vertical.area)
        @test [vertical[row, 3].grapheme for row in 1:3] == fill("|", 3)
        @test measure(divider, Rect(1, 1, 3, 5)) == Size(3, 1)
        @test_throws ArgumentError Rule(symbol="xx")
        @test_throws ArgumentError BorderSymbols("界", "|", "+", "+", "+", "+")
    end

    @testset "containers and measurement" begin
        row = Row(Label("A"), Label("B"); gap=1)
        buffer = Buffer(1, 9)
        render!(buffer, row, buffer.area)
        @test sprint(show, MIME"text/plain"(), buffer) ==
              "Buffer(1x9, origin=(1, 1))\nA    B   "
        @test measure(row, Rect(1, 1, 2, 20)) == Size(1, 3)

        padded = Padding(Label("x"); margin=Margin(1))
        @test measure(padded, Rect(1, 1, 10, 10)) == Size(3, 3)
        boxed = Box(Label("x"; alignment=CenterAlign); block=Block(symbols=ASCII_BORDERS))
        @test measure(boxed, Rect(1, 1, 10, 10)) == Size(3, 3)

        stacked = Stack(Spacer(), Label("abc"))
        @test measure(stacked, Rect(1, 1, 5, 5)) == Size(1, 3)
        @test measure(Center(Label("x"); height=3, width=3), Rect(1, 1, 5, 5)) ==
              Size(1, 1)

        @test_throws DimensionMismatch Row(Label("x"); constraints=[])
    end

    @testset "grid spans" begin
        grid = Grid(
            Label("A"),
            Label("B");
            rows=[Length(1), Length(1)],
            columns=[Length(2), Length(2), Length(2)],
            cells=[GridCell(1, 1; column_span=2), GridCell(2, 3)],
        )
        buffer = Buffer(2, 6)
        render!(buffer, grid, buffer.area)

        @test sprint(show, MIME"text/plain"(), buffer) ==
              "Buffer(2x6, origin=(1, 1))\nA     \n    B "
        @test_throws DimensionMismatch Grid(
            Label("a"), Label("b");
            rows=[Length(1)],
            columns=[Length(1)],
        )
        @test_throws DimensionMismatch Grid(
            Label("a");
            rows=[Length(1)],
            columns=[Length(1)],
            cells=GridCell[],
        )
    end
end
