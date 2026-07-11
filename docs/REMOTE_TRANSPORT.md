# Remote Frame Transport

Wicked's remote transport carries structured terminal frames and typed input events
over any reliable binary channel. It is intentionally independent of HTTP,
WebSocket, or a particular browser terminal so applications can choose their own
networking, authentication, origin, TLS, and deployment policy.

## Architecture

`RemoteBackend` implements the ordinary `AbstractBackend` contract. Its sender is a
function accepting one complete `Vector{UInt8}` packet, or an `IO` stream. This
makes a WebSocket binary-message sender, a local socket, an SSH bridge, or a test
collector equivalent at the rendering boundary.

```julia
packets = Vector{Vector{UInt8}}()
backend = RemoteBackend(packet -> push!(packets, copy(packet)); size=Size(24, 80))
terminal = Terminal(backend)

with_terminal(terminal) do active
    draw!(active) do frame
        render!(frame, Paragraph("Rendered on the server"), frame.area)
    end
end
```

Transport ownership remains outside Wicked. A production WebSocket adapter must
authenticate before entering the backend, enforce same-origin and authorization
rules, use TLS where the network is not already trusted, apply connection-level
rate limits, and close sessions whose protocol decoder rejects input.

## Protocol lifecycle

The current protocol version is `REMOTE_PROTOCOL_VERSION == 1`.

1. The server sends `RemoteHello` with viewport size and negotiated capabilities.
2. The first `RemoteFrame` is a complete frame.
3. Later frames contain ordered cell deltas unless synchronization is requested.
4. The client sends typed `RemoteEvent` packets for keys, mouse, paste, resize, and
   focus changes.
5. Either side can use `RemoteAck` when its adapter needs application-level
   acknowledgement.
6. Reconnecting clients call `request_remote_full_frame!` before the next draw.

Packets contain a fixed magic value, protocol version, message kind, flags,
sequence number, and bounded payload length. Numeric fields use network byte order.
Frames preserve grapheme width, continuation cells, colors, modifiers, hyperlinks,
and cursor state. Clients must apply changes in sequence order and request a full
frame after any gap.

## Receiving fragmented data

`RemoteDecoder` accepts arbitrary fragments or multiple concatenated packets:

```julia
decoder = RemoteDecoder()
for bytes in receive_chunks()
    for message in feed_remote!(decoder, bytes)
        if message isa RemoteEvent
            post_event!(application_input, message.event)
        elseif message isa RemoteAck
            record_ack(message.sequence)
        end
    end
end
```

WebSocket adapters normally receive one complete packet per binary message and can
call `decode_remote_packet` directly. Stream transports should use `feed_remote!`.

## Security and resource limits

`RemoteProtocolLimits` bounds packet size, decoder buffering, cell count, and every
string or byte field before allocation. Decoding rejects:

- Unsupported protocol versions, message kinds, flags, and enum values.
- Invalid UTF-8 and terminal control characters in cells or hyperlinks.
- Oversized viewports, packets, strings, and decoder buffers.
- Duplicate or out-of-bounds frame cells and invalid cursors.
- Arbitrary Julia `CustomEvent` payloads and unbounded key symbols.

The codec never uses Julia serialization and does not execute remote payloads.
These checks do not replace authentication, encryption, browser escaping, URL
policy, or connection-level denial-of-service controls in the hosting adapter.

## Browser adapter guidance

A browser frontend can render the structured grid directly to Canvas or DOM, or
translate frames into an xterm-compatible surface. Direct rendering preserves
Wicked's cell and semantic model; an ANSI compatibility adapter may be useful for
existing terminal emulators. Browser code must treat graphemes and hyperlinks as
data, never insert them as HTML, and permit only application-approved URL schemes.

Networking packages should integrate through Julia package extensions rather than
becoming core dependencies. This keeps ordinary terminal startup and precompilation
independent of HTTP and WebSocket stacks.

## HTTP.jl WebSocket extension

Installing and loading HTTP.jl activates Wicked's optional WebSocket adapter:

```julia
using HTTP
using Wicked.API
using Wicked.Experimental

HTTP.WebSockets.listen!("127.0.0.1", 8080; maxframesize=16 * 1024 * 1024) do websocket
    session = websocket_session(websocket; size=Size(24, 80))
    terminal = Terminal(session.backend)

    @sync begin
        @async pump_websocket!(session, websocket)
        @async with_terminal(terminal) do active
            # Run the application with `session.input` as its input source.
        end
    end
end
```

The hosting application must configure `check_origin`, authentication, TLS,
timeouts, connection limits, and an HTTP route appropriate to its trust boundary.
`pump_websocket!` accepts binary messages only, enforces monotonically increasing
event sequences, applies resize negotiation, and closes input delivery when the
socket ends.

## Reference browser surface

`assets/remote/index.html` is a dependency-free protocol-v1 browser client. It
renders structured cells to Canvas, maintains an accessibility text mirror, sends
typed keyboard, paste, mouse, focus, and resize events, acknowledges frames, and
closes on sequence gaps or malformed packets. Serve the directory as static files
and route `/wicked` to the authenticated WebSocket handler.
