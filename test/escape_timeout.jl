@testset "Escape-key input timeout" begin
    @testset "lone Escape resolves without blocking" begin
        waits = Ref(0)
        source = ParserInputSource(
            IOBuffer("\e");
            escape_timeout_seconds=0.01,
            wait_for_input=(input, timeout) -> begin
                waits[] += 1
                false
            end,
        )
        event = read_event!(source)
        @test event.key == Key(:escape)
        @test event.kind == KeyPress
        @test waits[] == 1
        @test isempty(source.parser.buffer)
    end

    @testset "available continuation remains one sequence" begin
        source = ParserInputSource(
            IOBuffer("\ex");
            escape_timeout_seconds=0.01,
            wait_for_input=(input, timeout) -> bytesavailable(input) > 0,
        )
        event = read_event!(source)
        @test event.key == Key(:character)
        @test event.text == "x"
        @test ALT in event.modifiers

        csi = ParserInputSource(
            IOBuffer("\e[A");
            wait_for_input=(input, timeout) -> bytesavailable(input) > 0,
        )
        @test read_event!(csi).key == Key(:up)
    end

    @testset "configuration and callback validation" begin
        @test_throws ArgumentError ParserInputSource(IOBuffer(); escape_timeout_seconds=-0.1)
        @test_throws ArgumentError ParserInputSource(IOBuffer(); escape_timeout_seconds=Inf)
        @test_throws ArgumentError ParserInputSource(
            IOBuffer();
            wait_for_input=() -> false,
        )

        invalid = ParserInputSource(
            IOBuffer("\e");
            wait_for_input=(input, timeout) -> :ready,
        )
        @test_throws ArgumentError read_event!(invalid)
    end

    @testset "zero timeout" begin
        source = ParserInputSource(
            IOBuffer("\e");
            escape_timeout_seconds=0,
            wait_for_input=(input, timeout) -> false,
        )
        @test read_event!(source).key == Key(:escape)
    end
end
