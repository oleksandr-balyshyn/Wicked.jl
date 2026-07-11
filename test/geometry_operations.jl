@testset "Geometry operations" begin
    @testset "bounding union" begin
        left = Rect(2, 3, 4, 5)
        right = Rect(1, 6, 3, 4)

        @test union(left, right) == Rect(1, 3, 5, 7)
        @test union(left, Rect(20, 20, 0, 0)) == left
        @test union(Rect(20, 20, 0, 0), right) == right
    end

    @testset "clamp into bounds" begin
        bounds = Rect(5, 10, 4, 6)

        @test clamp(Rect(1, 1, 2, 3), bounds) == Rect(5, 10, 2, 3)
        @test clamp(Rect(20, 30, 2, 3), bounds) == Rect(7, 13, 2, 3)
        @test clamp(Rect(1, 1, 20, 30), bounds) == bounds
        @test clamp(Rect(1, 1, 2, 3), Rect(4, 7, 0, 0)) == Rect(4, 7, 0, 0)
    end

    @testset "typed splits" begin
        area = Rect(2, 3, 8, 10)
        top, bottom = split(area, 3; direction=RowSplit, gap=1)
        left, right = split(area, 4; direction=ColumnSplit, gap=2)

        @test top == Rect(2, 3, 3, 10)
        @test bottom == Rect(6, 3, 4, 10)
        @test left == Rect(2, 3, 8, 4)
        @test right == Rect(2, 9, 8, 4)
        @test split(area, 0) == (Rect(2, 3, 0, 10), area)
        @test_throws ArgumentError split(area, -1)
        @test_throws ArgumentError split(area, 9)
        @test_throws ArgumentError split(area, 8; gap=1)
        @test_throws ArgumentError split(area, 1; gap=-1)
    end
end
