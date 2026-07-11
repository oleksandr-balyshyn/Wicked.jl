@testset "Remote transport" begin
    capabilities = TerminalCapabilities(
        color_level=:truecolor,
        mouse=true,
        focus=true,
        bracketed_paste=true,
        synchronized_updates=true,
        enhanced_keyboard=true,
        underline_color=true,
        terminal_title=false,
    )

    @testset "message and event round trips" begin
        hello = RemoteHello(7, Size(24, 80), capabilities)
        decoded_hello = decode_remote_packet(encode_remote_message(hello))
        @test decoded_hello.sequence == 7
        @test decoded_hello.size == Size(24, 80)
        @test decoded_hello.capabilities == capabilities

        style = Style(
            foreground=RGBColor(1, 2, 3),
            background=IndexedColor(42),
            underline_color=AnsiColor(5),
            modifiers=BOLD | UNDERLINE,
            hyperlink="https://example.test/path",
        )
        changes = [
            CellChange(Position(1, 1), Cell("界"; style)),
            CellChange(Position(1, 2), Wicked.Core.continuation_cell(style)),
        ]
        frame = RemoteFrame(
            8,
            true,
            Size(1, 2),
            changes,
            CursorRequest(Position(1, 2); shape=BarCursor),
        )
        decoded_frame = decode_remote_packet(encode_remote_message(frame))
        @test decoded_frame.sequence == 8
        @test decoded_frame.full
        @test decoded_frame.size == Size(1, 2)
        @test decoded_frame.changes == changes
        @test decoded_frame.cursor == frame.cursor

        events = AbstractEvent[
            KeyEvent(Key(:character); text="é", modifiers=CTRL | SHIFT, kind=KeyRepeat, raw=UInt8[1, 2]),
            MouseEvent(Position(3, 4), LeftMouseButton, MouseDrag; modifiers=ALT, click_count=2),
            PasteEvent("line 1\nline 2"),
            ResizeEvent(Size(40, 120)),
            FocusEvent(false),
            TickEvent(100, 25),
            UnknownEvent(UInt8[0xff]),
        ]
        for (index, event) in enumerate(events)
            decoded = decode_remote_packet(encode_remote_message(RemoteEvent(index, event)))
            @test decoded.sequence == index
            @test decoded.event == event
        end
        @test decode_remote_packet(encode_remote_message(RemoteAck(99))).sequence == 99
        @test_throws RemoteProtocolError encode_remote_message(RemoteEvent(1, CustomEvent(:unsafe)))
        @test_throws RemoteProtocolError encode_remote_message(
            RemoteEvent(1, KeyEvent(Key(:application_private))),
        )
    end

    @testset "fragmentation, combination, and bounds" begin
        first = encode_remote_message(RemoteAck(1))
        second = encode_remote_message(RemoteAck(2))
        decoder = RemoteDecoder()
        @test isempty(feed_remote!(decoder, first[1:5]))
        messages = feed_remote!(decoder, vcat(first[6:end], second))
        @test getfield.(messages, :sequence) == [1, 2]
        @test isempty(decoder.buffer)

        malformed = copy(first)
        malformed[1] = 0x00
        @test_throws RemoteProtocolError feed_remote!(RemoteDecoder(), malformed)

        version = copy(first)
        version[6] = 0x02
        @test_throws RemoteProtocolError decode_remote_packet(version)

        trailing = vcat(first, 0x00)
        @test_throws RemoteProtocolError decode_remote_packet(trailing)

        limits = RemoteProtocolLimits(
            maximum_packet_bytes=64,
            maximum_buffer_bytes=64,
            maximum_cells=4,
            maximum_string_bytes=4,
        )
        @test_throws RemoteProtocolError encode_remote_message(
            RemoteEvent(1, PasteEvent("12345"));
            limits,
        )
        bounded = RemoteDecoder(; limits)
        @test_throws RemoteProtocolError feed_remote!(bounded, zeros(UInt8, 65))
        @test isempty(bounded.buffer)
        @test_throws ArgumentError RemoteProtocolLimits(maximum_packet_bytes=10)
    end

    @testset "backend synchronization and commit semantics" begin
        packets = Vector{Vector{UInt8}}()
        backend = RemoteBackend(packet -> push!(packets, copy(packet)); size=Size(1, 3), capabilities)
        terminal = Terminal(backend)
        enter!(backend)
        @test decode_remote_packet(packets[1]) isa RemoteHello

        first = draw!(terminal) do frame
            render!(frame, Label("abc"), frame.area)
        end
        @test first.changed_cells == 3
        first_frame = decode_remote_packet(packets[2])
        @test first_frame isa RemoteFrame
        @test first_frame.full
        @test length(first_frame.changes) == 3

        draw!(terminal) do frame
            render!(frame, Label("axc"), frame.area)
        end
        delta = decode_remote_packet(packets[3])
        @test !delta.full
        @test length(delta.changes) == 1
        @test delta.changes[1].position == Position(1, 2)

        request_remote_full_frame!(backend)
        draw!(terminal) do frame
            render!(frame, Label("axc"), frame.area)
        end
        @test decode_remote_packet(packets[4]).full

        failing = RemoteBackend(_ -> error("send failed"); size=Size(1, 1))
        failed_terminal = Terminal(failing)
        @test_throws ErrorException draw!(failed_terminal) do frame
            render!(frame, Label("x"), frame.area)
        end
        @test failing.next_sequence == 0
        @test failing.force_full
        @test failed_terminal.force_redraw

        resize_remote_backend!(backend, 2, 2)
        @test backend_size(backend) == Size(2, 2)
        @test backend.force_full
    end
end
