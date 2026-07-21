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

        fill_only = resolve(
            FlexLayout(HorizontalLayout, [Fill(1), Fill(2), Fill(1)]; gap=1),
            Rect(3, 5, 2, 11),
        )
        @test fill_only == [
            Rect(3, 5, 2, 3),
            Rect(3, 9, 2, 4),
            Rect(3, 14, 2, 2),
        ]
        saturated_fill = resolve(
            FlexLayout(VerticalLayout, [Fill(), Fill(), Fill()]; gap=10),
            Rect(4, 6, 2, 3),
        )
        @test saturated_fill == [
            Rect(4, 6, 0, 3),
            Rect(5, 6, 0, 3),
            Rect(6, 6, 0, 3),
        ]
        for (direction, weights, gap, fill_area, margin) in (
            (HorizontalLayout, [1, 1, 1], 0, Rect(2, 4, 3, 17), Margin(0)),
            (HorizontalLayout, [3, 1, 2, 5], 2, Rect(3, 7, 4, 29), Margin(1)),
            (VerticalLayout, [2, 7, 1], 1, Rect(5, 9, 23, 6), Margin(0, 1)),
            (VerticalLayout, [1, 1, 1, 1], 100, Rect(4, 6, 3, 5), Margin(0)),
        )
            fill_layout = FlexLayout(
                direction,
                Constraint[Fill(weight) for weight in weights];
                gap,
                margin,
            )
            @test resolve(fill_layout, fill_area) == resolve(
                fill_layout,
                fill_area;
                content_sizes=zeros(Int, length(weights)),
            )
        end

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

    @testset "overlapping segment layout" begin
        area = Rect(1, 1, 3, 20)

        # overlap=1 makes adjacent segments share a border column
        shared = Wicked.overlap_layout(area, [5, 5]; overlap=1)
        @test length(shared) == 2
        @test (shared[1].column, shared[1].width) == (1, 5)
        @test (shared[2].column, shared[2].width) == (5, 5)

        # overlap=0 abuts segments with no shared cells
        abutting = Wicked.overlap_layout(area, [5, 5]; overlap=0)
        @test (abutting[2].column, abutting[2].width) == (6, 5)

        # segments are clipped to the area
        clipped = Wicked.overlap_layout(Rect(1, 1, 3, 8), [5, 5]; overlap=0)
        @test (clipped[2].column, clipped[2].width) == (6, 3)

        # vertical direction shares a border row
        vertical = Wicked.overlap_layout(Rect(1, 1, 10, 4), [4, 4]; direction=:vertical, overlap=1)
        @test (vertical[1].row, vertical[1].height) == (1, 4)
        @test (vertical[2].row, vertical[2].height) == (4, 4)

        @test_throws ArgumentError Wicked.overlap_layout(area, [1]; direction=:diagonal)
        @test_throws ArgumentError Wicked.overlap_layout(area, [1]; overlap=-1)
        @test_throws ArgumentError Wicked.overlap_layout(area, [-1])
    end
end
