@testset "Layout" begin
    @testset "constraints and weighted fill" begin
        layout = FlexLayout(
            HorizontalLayout,
            [Length(3), Fill(1), Fill(2)];
            gap=1,
        )
        regions = resolve(layout, Rect(1, 1, 2, 15))

        @test regions == [
            Rect(1, 1, 2, 3),
            Rect(1, 5, 2, 4),
            Rect(1, 10, 2, 6),
        ]

        ratio_regions = resolve(
            FlexLayout(HorizontalLayout, [Ratio(typemax(Int), typemax(Int)), Fill()]),
            Rect(1, 1, 1, 20),
        )
        @test ratio_regions == [Rect(1, 1, 1, 20), Rect(1, 21, 1, 0)]

        saturated_gap = resolve(
            FlexLayout(HorizontalLayout, [Length(1), Length(1), Length(1)]; gap=typemax(Int)),
            Rect(1, 1, 1, 5),
        )
        @test all(isempty, saturated_gap)
        @test percent(25) == Percentage(25)
        @test ratio(1, 3) == Ratio(1, 3)
    end

    @testset "overflow and alignment" begin
        overflow = resolve(
            FlexLayout(HorizontalLayout, [Length(5), Min(4), Length(3)]),
            Rect(1, 1, 1, 6),
        )
        @test getfield.(overflow, :width) == [5, 1, 0]

        centered = resolve(
            FlexLayout(HorizontalLayout, [Length(2)]; alignment=CenterFlex),
            Rect(1, 1, 1, 10),
        )
        @test centered == [Rect(1, 5, 1, 2)]

        spaced = resolve(
            FlexLayout(HorizontalLayout, [Length(2), Length(2)]; alignment=SpaceBetween),
            Rect(1, 1, 1, 10),
        )
        @test spaced == [Rect(1, 1, 1, 2), Rect(1, 9, 1, 2)]
    end

    @testset "grid and spans" begin
        layout = GridLayout(
            [Length(2), Fill()],
            [Length(3), Fill(), Length(2)];
            row_gap=1,
            column_gap=1,
        )
        area = Rect(1, 1, 8, 12)
        cells = resolve(layout, area)

        @test size(cells) == (2, 3)
        @test cells[1, 1] == Rect(1, 1, 2, 3)
        @test cells[2, 2] == Rect(4, 5, 5, 5)

        spans = resolve(
            layout,
            area,
            [
                GridCell(1, 1; column_span=2),
                GridCell(1, 2; row_span=2, column_span=2),
            ],
        )
        @test spans == [Rect(1, 1, 2, 9), Rect(1, 5, 8, 8)]
        @test_throws BoundsError resolve(layout, area, [GridCell(2, 3; column_span=2)])
        @test_throws ArgumentError GridCell(1, 1; row_span=0)
    end

    @testset "dock, center, and flow" begin
        regions, remaining = dock(
            Rect(1, 1, 10, 20),
            [DockItem(DockTop, 2), DockItem(DockLeft, 3), DockItem(DockBottom, 4)],
        )
        @test regions == [
            Rect(1, 1, 2, 20),
            Rect(3, 1, 8, 3),
            Rect(7, 4, 4, 17),
        ]
        @test remaining == Rect(3, 4, 4, 17)
        @test center(Rect(1, 1, 5, 9), Size(3, 3)) == Rect(2, 4, 3, 3)

        flowed = flow(
            Rect(1, 1, 5, 6),
            [Size(2, 3), Size(1, 3), Size(2, 2)];
            column_gap=1,
            row_gap=1,
        )
        @test flowed == [
            Rect(1, 1, 2, 3),
            Rect(4, 1, 1, 3),
            Rect(4, 5, 2, 2),
        ]
    end

    @testset "invalid configuration" begin
        @test_throws ArgumentError Length(-1)
        @test_throws ArgumentError Percentage(101)
        @test_throws ArgumentError Ratio(1, 0)
        @test_throws ArgumentError Fill(0)
        @test_throws ArgumentError Content(3, 2)
        @test_throws DimensionMismatch resolve(
            FlexLayout(HorizontalLayout, [Content(), Content()]),
            Rect(1, 1, 1, 10);
            content_sizes=[1],
        )
    end
end
