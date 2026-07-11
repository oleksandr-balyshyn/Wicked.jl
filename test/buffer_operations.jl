@testset "Buffer operations" begin
    @testset "region fill and reset" begin
        buffer = Buffer(2, 4)
        fill!(buffer, Rect(1, 2, 2, 2), Cell("x"))

        @test buffer[1, 1] == Cell()
        @test buffer[1, 2] == Cell("x")
        @test buffer[2, 3] == Cell("x")
        @test buffer[2, 4] == Cell()

        fill!(buffer, Cell("y"); area=Rect(2, 3, 3, 3))
        @test buffer[2, 3] == Cell("y")
        @test buffer[2, 4] == Cell("y")
        @test_throws ArgumentError fill!(buffer, Cell("界"))

        reset!(buffer)
        @test buffer == Buffer(2, 4)
    end

    @testset "safe clipped merge" begin
        source = Buffer(2, 4)
        fill!(source, Cell("s"))
        draw_grapheme!(source, 1, 3, "界")
        destination = Buffer(2, 4; cell=Cell("d"))

        merge!(destination, source; area=Rect(1, 2, 2, 2))
        @test destination[1, 1] == Cell("d")
        @test destination[1, 2] == Cell("s")
        @test destination[1, 3] == Cell("d")
        @test destination[1, 4] == Cell("d")
        @test destination[2, 2] == Cell("s")
        @test destination[2, 3] == Cell("s")

        merge!(destination, source)
        @test destination == source
    end

    @testset "row views" begin
        buffer = Buffer(Rect(3, 4, 2, 3))
        draw_text!(buffer, 3, 4, "abc")
        draw_text!(buffer, 4, 4, "def")
        rows = buffer_rows(buffer)

        @test length(rows) == 2
        @test length(rows[1]) == 3
        @test [cell.grapheme for cell in rows[1]] == ["a", "b", "c"]
        @test [cell.grapheme for cell in last(collect(rows))] == ["d", "e", "f"]
        @test_throws BoundsError rows[0]
        @test_throws BoundsError rows[1][4]
    end

    @testset "stable display" begin
        buffer = Buffer(2, 3)
        draw_text!(buffer, 1, 1, "abc")
        draw_grapheme!(buffer, 2, 1, "界")

        @test sprint(show, buffer) == "Buffer(2x3, origin=(1, 1))"
        @test sprint(show, MIME"text/plain"(), buffer) ==
              "Buffer(2x3, origin=(1, 1))\nabc\n界 "
    end
end
