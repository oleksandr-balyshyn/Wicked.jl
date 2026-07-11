function ansi_event_signature(event)
    if event isa KeyEvent
        return (:key, event.key, event.text, event.modifiers.bits, event.kind, event.raw)
    elseif event isa MouseEvent
        return (
            :mouse,
            event.position,
            event.button,
            event.action,
            event.modifiers.bits,
            event.click_count,
        )
    elseif event isa PasteEvent
        return (:paste, event.text)
    elseif event isa FocusEvent
        return (:focus, event.focused)
    elseif event isa UnknownEvent
        return (:unknown, event.raw)
    end
    return (typeof(event), event)
end

function ansi_flush_all!(parser)
    return flush_input!(parser)
end

@testset "ANSI parser fragmentation and fuzz safety" begin
    @testset "all two-part boundaries are equivalent" begin
        bytes = collect(codeunits(
            "a界\e[A\e[1;5C\e[<0;5;3M\e[I\e[200~pasted text\e[201~\e[97;5u\ex",
        ))
        complete = AnsiInputParser()
        expected = vcat(feed!(complete, bytes), ansi_flush_all!(complete))
        expected_signatures = ansi_event_signature.(expected)

        for boundary in 0:length(bytes)
            parser = AnsiInputParser()
            events = AbstractEvent[]
            append!(events, feed!(parser, bytes[1:boundary]))
            append!(events, feed!(parser, bytes[(boundary + 1):end]))
            append!(events, ansi_flush_all!(parser))
            @test ansi_event_signature.(events) == expected_signatures
            @test isempty(parser.buffer)
        end
    end

    @testset "incomplete fragments preserve raw bytes and recover" begin
        fragments = [
            UInt8[0x1b, 0x5b],
            UInt8[0x1b, 0x5b, 0x31, 0x3b],
            UInt8[0xe2, 0x82],
            UInt8[0x1b, 0x4f],
            UInt8[0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7e, 0x61],
        ]
        for fragment in fragments
            parser = AnsiInputParser(max_buffer_bytes=64, max_paste_bytes=32)
            @test isempty(feed!(parser, fragment))
            flushed = only(flush_input!(parser))
            @test flushed isa UnknownEvent
            @test flushed.raw == fragment
            @test isempty(parser.buffer)
            @test only(feed!(parser, "z")).text == "z"
        end

        escape = AnsiInputParser()
        feed!(escape, UInt8[0x1b])
        event = only(flush_input!(escape))
        @test event isa KeyEvent
        @test event.key == Key(:escape)
        @test isempty(flush_input!(escape))
    end

    @testset "deterministic arbitrary byte streams remain recoverable" begin
        state = UInt64(0x9e3779b97f4a7c15)
        function next_byte!()
            state = state ⊻ (state << 13)
            state = state ⊻ (state >> 7)
            state = state ⊻ (state << 17)
            return UInt8(state & 0xff)
        end

        for sample in 1:256
            length_value = Int(next_byte!())
            bytes = UInt8[next_byte!() for _ in 1:length_value]
            parser = AnsiInputParser(max_buffer_bytes=512, max_paste_bytes=400)
            events = AbstractEvent[]
            cursor = 1
            while cursor <= length(bytes)
                chunk_size = min(length(bytes) - cursor + 1, Int(next_byte!() % 17) + 1)
                append!(events, feed!(parser, bytes[cursor:(cursor + chunk_size - 1)]))
                cursor += chunk_size
            end
            append!(events, flush_input!(parser))

            @test isempty(parser.buffer)
            @test all(event -> event isa AbstractEvent, events)
            @test all(event -> !(event isa KeyEvent) || isvalid(event.text), events)
            @test all(event -> !(event isa PasteEvent) || isvalid(event.text), events)
            @test only(feed!(parser, "q")).text == "q"
        end
    end

    @testset "capacity rejection resets pending state" begin
        parser = AnsiInputParser(max_buffer_bytes=32, max_paste_bytes=16)
        @test isempty(feed!(parser, "\e["))
        @test_throws ArgumentError feed!(parser, fill(UInt8('9'), 31))
        @test isempty(parser.buffer)
        @test only(feed!(parser, "x")).text == "x"
    end
end
