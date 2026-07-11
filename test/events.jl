@testset "Events and ANSI input" begin
    @testset "regular and fragmented keys" begin
        parser = AnsiInputParser()
        events = feed!(parser, "a\r\t\x7f\x01")

        @test length(events) == 5
        @test events[1].key == Key(:character)
        @test events[1].text == "a"
        @test events[2].key == Key(:enter)
        @test events[3].key == Key(:tab)
        @test events[4].key == Key(:backspace)
        @test events[5].key == Key(:a)
        @test CTRL in events[5].modifiers

        utf8 = collect(codeunits("界"))
        @test isempty(feed!(parser, utf8[1:1]))
        @test isempty(feed!(parser, utf8[2:2]))
        completed = feed!(parser, utf8[3:3])
        @test length(completed) == 1
        @test completed[1].text == "界"
    end

    @testset "escape, CSI, and SS3" begin
        parser = AnsiInputParser()
        @test isempty(feed!(parser, "\e"))
        escape = flush_escape!(parser)
        @test escape.key == Key(:escape)
        @test flush_escape!(parser) === nothing

        events = feed!(parser, "\e[A\e[1;5C\eOP\ex")
        @test getfield.(events, :key) == [Key(:up), Key(:right), Key(:f1), Key(:character)]
        @test CTRL in events[2].modifiers
        @test ALT in events[4].modifiers
        @test events[4].text == "x"

        malformed = only(feed!(parser, "\e[1;;5A"))
        @test malformed isa UnknownEvent
    end

    @testset "mouse and focus" begin
        parser = AnsiInputParser()
        events = feed!(parser, "\e[<0;5;3M\e[<0;5;3m\e[I\e[O")

        @test length(events) == 4
        @test events[1] isa MouseEvent
        @test events[1].position == Position(3, 5)
        @test events[1].button == LeftMouseButton
        @test events[1].action == MousePress
        @test events[2].action == MouseRelease
        @test events[3] == FocusEvent(true)
        @test events[4] == FocusEvent(false)

        invalid_mouse = only(feed!(parser, "\e[<-1;0;0M"))
        @test invalid_mouse isa UnknownEvent
    end

    @testset "bounded bracketed paste" begin
        parser = AnsiInputParser(max_buffer_bytes=64, max_paste_bytes=8)
        @test isempty(feed!(parser, "\e[200~"))
        pasted = feed!(parser, "hello\e[201~")
        @test length(pasted) == 1
        @test pasted[1] == PasteEvent("hello")

        limited = AnsiInputParser(max_buffer_bytes=64, max_paste_bytes=4)
        @test_throws ArgumentError feed!(limited, "\e[200~12345\e[201~")
        recovered = only(feed!(limited, "z"))
        @test recovered isa KeyEvent
        @test recovered.text == "z"

        unterminated = AnsiInputParser(max_buffer_bytes=64, max_paste_bytes=4)
        @test_throws ArgumentError feed!(unterminated, "\e[200~12345")
        @test only(feed!(unterminated, "q")).text == "q"
    end

    @testset "malformed and bounded bytes" begin
        parser = AnsiInputParser(max_buffer_bytes=20, max_paste_bytes=8)
        invalid = only(feed!(parser, UInt8[0xe0, 0x80, 0x80]))
        @test invalid isa UnknownEvent
        @test invalid.raw == UInt8[0xe0, 0x80, 0x80]

        pending = AnsiInputParser(max_buffer_bytes=20, max_paste_bytes=8)
        @test isempty(feed!(pending, "\e["))
        @test_throws ArgumentError feed!(pending, fill(UInt8('1'), 19))
        @test isempty(pending.buffer)
        @test only(feed!(pending, "r")).text == "r"
        @test_throws ArgumentError AnsiInputParser(max_buffer_bytes=10, max_paste_bytes=1)
    end

    @testset "input sources" begin
        source = ChannelInputSource(2)
        event = CustomEvent(:ready)
        @test post_event!(source, event)
        @test read_event!(source) == event
        close_input!(source)
        @test !post_event!(source, event)

        parsed = ParserInputSource(IOBuffer("ab"))
        @test read_event!(parsed).text == "a"
        @test read_event!(parsed).text == "b"
        @test_throws ArgumentError ChannelInputSource(0)
    end
end
