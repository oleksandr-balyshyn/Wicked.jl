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

        aligned = Buffer(2, 8)
        styled_line = Line(
            [Span("λ"; style=Style(modifiers=BOLD)), Span("界")];
            alignment=RightAlign,
        )
        render!(aligned, Label(styled_line), Rect(1, 1, 1, 8))
        @test [aligned[1, column].grapheme for column in 5:8] == [" ", "λ", "界", ""]
        @test aligned[1, 6].style.modifiers == BOLD

        link_style = Style(foreground=AnsiColor(4), hyperlink="https://example.test")
        rich_line = Line([
            Span("ab"; style=Style(modifiers=BOLD)),
            Span("·界"; style=link_style),
        ])
        narrow_policy = UnicodeWidthPolicy(1)
        rich_label = Label(rich_line; width_policy=narrow_policy)
        @test rich_label.width_policy === narrow_policy
        rich = Buffer(1, 6)
        render!(rich, rich_label, Rect(1, 2, 1, 5))
        @test [rich[1, column].grapheme for column in 1:6] == [" ", "a", "b", "·", "界", ""]
        @test rich[1, 2].style.modifiers == BOLD
        @test rich[1, 4].style == link_style
        @test rich[1, 5].style == link_style

        clipped_rich = Buffer(1, 3)
        render!(clipped_rich, rich_label, Rect(1, 2, 1, 5))
        @test [clipped_rich[1, column].grapheme for column in 1:3] == [" ", "a", "b"]

        wide_policy = UnicodeWidthPolicy(2)
        ambiguous = Buffer(1, 2)
        render!(ambiguous, Label("·"; width_policy=wide_policy), ambiguous.area)
        @test [ambiguous[1, column].grapheme for column in 1:2] == ["·", ""]

        wrapped = Buffer(2, 4)
        render!(wrapped, Paragraph("one two"), wrapped.area)
        @test sprint(show, MIME"text/plain"(), wrapped) ==
              "Buffer(2x4, origin=(1, 1))\none \ntwo "

        wrapped_style = Style(modifiers=BOLD)
        wrapped_link = Style(foreground=AnsiColor(6), hyperlink="https://example.test/wrap")
        styled_paragraph = Paragraph(Line([
            Span("ab "; style=wrapped_style),
            Span("界c de"; style=wrapped_link),
        ]))
        styled_wrapped = Buffer(3, 5)
        render!(styled_wrapped, styled_paragraph, styled_wrapped.area)
        @test sprint(show, MIME"text/plain"(), styled_wrapped) ==
              "Buffer(3x5, origin=(1, 1))\nab   \n界c  \nde   "
        @test styled_wrapped[1, 1].style == wrapped_style
        @test styled_wrapped[2, 1].style == wrapped_link
        @test styled_wrapped[2, 2].continuation
        @test styled_wrapped[3, 1].style == wrapped_link

        combined = Buffer(1, 3)
        render!(combined, Paragraph("e\u0301界"; wrap=NoWrap), combined.area)
        @test [combined[1, column].grapheme for column in 1:3] == ["e\u0301", "界", ""]

        preserved_indent = Buffer(2, 12)
        render!(preserved_indent, Paragraph("    - alpha beta"), preserved_indent.area)
        @test sprint(show, MIME"text/plain"(), preserved_indent) ==
              "Buffer(2x12, origin=(1, 1))\n    - alpha \nbeta        "

        trimmed_indent = Buffer(2, 12)
        render!(trimmed_indent, Paragraph("    - alpha beta"; trim=true), trimmed_indent.area)
        @test sprint(show, MIME"text/plain"(), trimmed_indent) ==
              "Buffer(2x12, origin=(1, 1))\n- alpha beta\n            "
        @test Static("    value"; trim=true).paragraph.trim
        @test TextView("    value"; trim=true).paragraph.trim
        @test Heading("    value"; trim=true).paragraph.trim
        @test MarkupText("    value"; trim=true).paragraph.trim

        horizontally_scrolled = Buffer(1, 3)
        render!(
            horizontally_scrolled,
            Paragraph("abcdef"; wrap=NoWrap, horizontal_scroll=2),
            horizontally_scrolled.area,
        )
        @test [horizontally_scrolled[1, column].grapheme for column in 1:3] ==
              ["c", "d", "e"]

        scrolled_style = Style(modifiers=BOLD)
        scrolled_link = Style(hyperlink="https://example.test/scroll")
        scrolled_line = Line([
            Span("ab"; style=scrolled_style),
            Span("界cde"; style=scrolled_link),
        ])
        wide_scrolled = Buffer(1, 4)
        render!(
            wide_scrolled,
            Paragraph(scrolled_line; wrap=NoWrap, horizontal_scroll=1),
            wide_scrolled.area,
        )
        @test [wide_scrolled[1, column].grapheme for column in 1:4] ==
              ["b", "界", "", "c"]
        @test wide_scrolled[1, 1].style == scrolled_style
        @test wide_scrolled[1, 2].style == scrolled_link

        split_wide = Buffer(1, 4)
        render!(
            split_wide,
            Paragraph(scrolled_line; wrap=NoWrap, horizontal_scroll=3),
            split_wide.area,
        )
        @test [split_wide[1, column].grapheme for column in 1:4] ==
              [" ", "c", "d", "e"]
        @test all(column -> split_wide[1, column].style == scrolled_link, 2:4)

        aligned_scroll = Buffer(1, 6)
        render!(
            aligned_scroll,
            Paragraph("ab"; alignment=RightAlign, wrap=NoWrap, horizontal_scroll=2),
            aligned_scroll.area,
        )
        @test sprint(show, MIME"text/plain"(), aligned_scroll) ==
              "Buffer(1x6, origin=(1, 1))\n  ab  "

        @test Static("value"; horizontal_scroll=1).paragraph.horizontal_scroll == 1
        @test TextView("value"; horizontal_scroll=1).paragraph.horizontal_scroll == 1
        @test Heading("value"; horizontal_scroll=1).paragraph.horizontal_scroll == 1
        @test MarkupText("value"; horizontal_scroll=1).paragraph.horizontal_scroll == 1
        @test_throws ArgumentError Paragraph("bad"; horizontal_scroll=-1)
        @test_throws ArgumentError MarkupText("bad"; horizontal_scroll=-1)

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

        render_snapshot(widget) = begin
            snapshot = Buffer(1, 9)
            render!(snapshot, widget, snapshot.area)
            sprint(show, MIME"text/plain"(), snapshot)
        end

        layout_snapshot = render_snapshot(row)
        @test render_snapshot(horizontal(Label("A"), Label("B"); gap=1)) == layout_snapshot
        @test render_snapshot(hstack(Label("A"), Label("B"); gap=1)) == layout_snapshot
        @test render_snapshot(hbox(Label("A"), Label("B"); gap=1)) == layout_snapshot
        @test render_snapshot(hsplit(Label("A"), Label("B"); gap=1)) == layout_snapshot

        column = Column(Label("A"), Label("B"); gap=1)
        column_snapshot = render_snapshot(column)
        @test render_snapshot(vertical(Label("A"), Label("B"); gap=1)) == column_snapshot
        @test render_snapshot(vstack(Label("A"), Label("B"); gap=1)) == column_snapshot
        @test render_snapshot(vbox(Label("A"), Label("B"); gap=1)) == column_snapshot
        @test render_snapshot(vsplit(Label("A"), Label("B"); gap=1)) == column_snapshot

        @test render_snapshot(Stack(Label("A"), Label("B"))) ==
              render_snapshot(overlay(Label("A"), Label("B")))

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

    @testset "multi-resolution pixel canvas" begin
        # braille: 2x4 per cell, single top-left dot renders U+2801
        braille = Wicked.PixelCanvas(1, 1; marker=:braille)
        @test Wicked.pixel_dimensions(braille) == (4, 2)
        @test Wicked.pixel_set!(braille, 1, 1)
        @test Wicked.pixel_render(braille) == ["⠁"]
        @test !Wicked.pixel_set!(braille, 3, 1)   # out of bounds is a no-op
        full_braille = Wicked.PixelCanvas(1, 1; marker=:braille)
        for x in 1:2, y in 1:4
            Wicked.pixel_set!(full_braille, x, y)
        end
        @test Wicked.pixel_render(full_braille) == ["⣿"]

        # quadrant: 2x2 per cell block quadrants
        quad = Wicked.PixelCanvas(1, 1; marker=:quadrant)
        @test Wicked.pixel_dimensions(quad) == (2, 2)
        Wicked.pixel_set!(quad, 1, 1)
        @test Wicked.pixel_render(quad) == ["▘"]
        top = Wicked.PixelCanvas(1, 1; marker=:quadrant)
        Wicked.pixel_set!(top, 1, 1)
        Wicked.pixel_set!(top, 2, 1)
        @test Wicked.pixel_render(top) == ["▀"]
        filled = Wicked.PixelCanvas(1, 1; marker=:quadrant)
        for x in 1:2, y in 1:2
            Wicked.pixel_set!(filled, x, y)
        end
        @test Wicked.pixel_render(filled) == ["█"]

        # half-block: 1x2 per cell
        half = Wicked.PixelCanvas(1, 1; marker=:half_block)
        @test Wicked.pixel_dimensions(half) == (2, 1)
        Wicked.pixel_set!(half, 1, 2)
        @test Wicked.pixel_render(half) == ["▄"]

        # dot: 1x1 per cell, and multi-cell rows
        dots = Wicked.PixelCanvas(1, 2; marker=:dot)
        Wicked.pixel_set!(dots, 1, 1)
        Wicked.pixel_set!(dots, 2, 1)
        @test Wicked.pixel_render(dots) == ["██"]

        @test_throws ArgumentError Wicked.PixelCanvas(1, 1; marker=:octant)
    end
end
