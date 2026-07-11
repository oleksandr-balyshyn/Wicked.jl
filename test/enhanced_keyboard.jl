@testset "Enhanced keyboard protocol" begin
    @testset "CSI-u parsing" begin
        parser = AnsiInputParser()
        events = feed!(
            parser,
            "\e[97;6:2u\e[97;3:3u\e[97;2;65u\e[27;1u\e[57376;1u\e[0;1;229u",
        )
        @test length(events) == 6

        repeated = events[1]
        @test repeated.key == Key(:a)
        @test repeated.kind == KeyRepeat
        @test SHIFT in repeated.modifiers
        @test CTRL in repeated.modifiers

        released = events[2]
        @test released.kind == KeyRelease
        @test ALT in released.modifiers

        shifted = events[3]
        @test shifted.key == Key(:a)
        @test shifted.text == "A"
        @test SHIFT in shifted.modifiers
        @test events[4].key == Key(:escape)
        @test events[5].key == Key(:f13)
        @test events[6].key == Key(:character)
        @test events[6].text == "å"

        all_modifiers = only(feed!(parser, "\e[120;256u"))
        @test SUPER in all_modifiers.modifiers
        @test HYPER in all_modifiers.modifiers
        @test META in all_modifiers.modifiers
        @test CAPS_LOCK in all_modifiers.modifiers
        @test NUM_LOCK in all_modifiers.modifiers

        @test only(feed!(parser, "\e[97;1:4u")) isa UnknownEvent
        @test only(feed!(parser, "\e[97;1;55296u")) isa UnknownEvent
        @test only(feed!(parser, "\e[?3u")) isa UnknownEvent

        fragmented = AnsiInputParser()
        @test isempty(feed!(fragmented, "\e[97;"))
        completed = only(feed!(fragmented, "5:1u"))
        @test completed.key == Key(:a)
        @test CTRL in completed.modifiers
    end

    @testset "ANSI lifecycle negotiation" begin
        output = IOBuffer()
        backend = AnsiBackend(
            IOBuffer(),
            output;
            capabilities=TerminalCapabilities(enhanced_keyboard=true),
            controller=NoopTerminalController(),
            size=Size(1, 4),
        )
        enter!(backend)
        entered = String(take!(output))
        @test occursin("\e[>3u", entered)

        leave!(backend)
        left = String(take!(output))
        @test occursin("\e[<u", left)
        @test findfirst("\e[<u", left) < findfirst("\e[?1049l", left)
    end

    @testset "inline lifecycle negotiation" begin
        output = IOBuffer()
        backend = InlineBackend(
            output;
            height=1,
            width=4,
            interactive=true,
            capabilities=TerminalCapabilities(enhanced_keyboard=true),
        )
        enter!(backend)
        @test occursin("\e[>3u", String(take!(output)))
        leave!(backend)
        @test occursin("\e[<u", String(take!(output)))
    end
end
