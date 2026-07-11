@testset "Clipboard adversarial boundaries" begin
    @testset "memory provider enforces policy before sanitizing" begin
        provider = MemoryClipboard()
        policy = ClipboardPolicy(maximum_bytes=8)
        @test_throws ClipboardError write_clipboard!(
            provider,
            ClipboardContent("\0\0\0\0\0\0\0\0\0safe");
            policy,
        )
        @test !clipboard_available(provider)

        write_clipboard!(provider, ClipboardContent("a\0b\tc\nd"); policy)
        @test clipboard_text(read_clipboard(provider; policy)) == "ab\tc\nd"

        invalid = ClipboardContent(UInt8[0xff, 0xfe])
        @test_throws ClipboardError write_clipboard!(provider, invalid; policy)
        @test_throws ClipboardError clipboard_text(invalid)
        @test_throws ArgumentError ClipboardContent("text"; mime="not-a-media-type")
        @test_throws ArgumentError ClipboardContent("text"; mime="text/plain\ninvalid")
    end

    @testset "read, write, MIME, and sensitive policies" begin
        provider = MemoryClipboard()
        @test_throws ClipboardError write_clipboard!(
            provider,
            ClipboardContent("blocked");
            policy=ClipboardPolicy(allow_write=false),
        )
        write_clipboard!(
            provider,
            ClipboardContent("secret"; sensitive=true, created_ns=1_000);
            policy=ClipboardPolicy(sensitive_ttl_ms=1),
        )
        @test_throws ClipboardError read_clipboard(
            provider;
            policy=ClipboardPolicy(allow_read=false),
        )
        @test read_clipboard(
            provider;
            policy=ClipboardPolicy(sensitive_ttl_ms=1),
            now_ns=1_001_001,
        ) === nothing

        binary = ClipboardContent(UInt8[1, 2, 3]; mime="application/octet-stream")
        @test_throws ClipboardError write_clipboard!(provider, binary)
        binary_policy = ClipboardPolicy(allowed_mime_prefixes=("application/",))
        write_clipboard!(provider, binary; policy=binary_policy)
        copy = read_clipboard(provider; policy=binary_policy)
        copy.data[1] = 99
        @test read_clipboard(provider; policy=binary_policy).data == UInt8[1, 2, 3]
        @test_throws ClipboardError clipboard_text(binary)
    end

    @testset "OSC 52 encoding and strict response framing" begin
        content = ClipboardContent("hello")
        @test osc52_sequence(content) == "\e]52;c;aGVsbG8=\a"
        @test osc52_sequence(
            content;
            selection=OSC52PrimarySelection,
            terminator=:st,
        ) == "\e]52;p;aGVsbG8=\e\\"
        @test osc52_query(OSC52SecondarySelection; terminator=:st) == "\e]52;s;?\e\\"
        @test_throws ArgumentError osc52_sequence(content; terminator=:invalid)
        @test_throws ArgumentError osc52_query(; terminator=:invalid)

        response = "\e]52;c;aGVsbG8=\a"
        parsed = parse_osc52_response(response; selection=OSC52ClipboardSelection)
        @test clipboard_text(parsed) == "hello"
        @test_throws ClipboardError parse_osc52_response("prefix" * response)
        @test_throws ClipboardError parse_osc52_response(response * "suffix")
        @test_throws ClipboardError parse_osc52_response(
            response;
            selection=OSC52PrimarySelection,
        )
        @test_throws ClipboardError parse_osc52_response(
            response;
            policy=ClipboardPolicy(allow_read=false),
        )
        @test_throws ClipboardError parse_osc52_response("\e]52;c;====\a")
        @test_throws ClipboardError parse_osc52_response(
            response;
            policy=ClipboardPolicy(maximum_bytes=4),
        )
    end

    @testset "OSC 52 binary limits and sanitization" begin
        for size in 0:128
            data = UInt8[UInt8(index % 251) for index in 1:size]
            content = ClipboardContent(data; mime="application/octet-stream")
            response = osc52_sequence(content)
            parsed = parse_osc52_response(
                response;
                policy=ClipboardPolicy(
                    maximum_bytes=size,
                    allowed_mime_prefixes=("application/",),
                ),
                mime="application/octet-stream",
            )
            @test parsed.data == data
        end

        controlled = parse_osc52_response(
            osc52_sequence(ClipboardContent("a\0b\ec")),
        )
        @test clipboard_text(controlled) == "abc"
    end

    @testset "transport failures use configured fallback" begin
        output = IOBuffer()
        close(output)
        provider = OSC52Clipboard(output)
        @test_throws ClipboardError write_clipboard!(provider, ClipboardContent("value"))
        @test_throws ClipboardError clear_clipboard!(provider)

        fallback = MemoryClipboard()
        service = ClipboardService(provider; fallback, fallback_on_error=true)
        copy_to_clipboard!(service, "fallback value")
        @test clipboard_text(read_clipboard(fallback)) == "fallback value"
        clear_clipboard_service!(service)
        @test !clipboard_available(fallback)
    end
end
