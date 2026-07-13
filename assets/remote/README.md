# Wicked Remote Browser Client

This directory contains the dependency-free protocol-v1 browser client for
Wicked remote frame delivery.

The client is intentionally static. It does not own authentication, HTTP
routing, TLS, authorization, origin policy, or deployment topology. A production
application should serve these files from its own trusted web stack and route an
authenticated binary WebSocket endpoint to Wicked's optional HTTP.jl adapter.

## Files

- `index.html` contains the browser shell and accessibility mirror.
- `wicked-remote.css` contains the browser layout and terminal surface styles.
- `wicked-remote.js` implements the protocol-v1 browser adapter.

## Server contract

The browser expects a WebSocket route that sends and receives Wicked remote
protocol packets:

- Server-to-client packets are `RemoteHello`, `RemoteFrame`, and optional
  `RemoteAck` values encoded by `encode_remote_message`.
- Client-to-server packets are `RemoteEvent` and `RemoteAck` values encoded by
  the browser adapter.
- The first server packet should be `RemoteHello`.
- The first frame after connection or resynchronization should be a full
  `RemoteFrame`.
- Binary WebSocket messages must contain exactly one encoded Wicked packet.

With HTTP.jl loaded, `WickedHTTPWebSocketsExt` provides extension methods for
the stable hooks:

```julia
using HTTP
using Wicked.API

HTTP.WebSockets.listen!("127.0.0.1", 8080; maxframesize=16 * 1024 * 1024) do websocket
    session = websocket_session(websocket; size=Size(24, 80))
    terminal = Terminal(session.backend)

    @sync begin
        @async pump_websocket!(session, websocket)
        @async with_terminal(terminal) do active
            # Run the application and read events from session.input.
        end
    end
end
```

HTTP.jl is a weak dependency. Loading Wicked alone must not load HTTP, start a
server, or activate browser delivery.

## Deployment checklist

- Serve the assets over HTTPS unless the network is already trusted.
- Authenticate the HTTP route before upgrading to WebSocket.
- Enforce an explicit origin policy.
- Use connection, frame-size, and rate limits appropriate for the deployment.
- Close sessions when `pump_websocket!` raises a protocol error.
- Sanitize application hyperlinks and allow only approved URL schemes.
- Archive `api/remote_protocol_fixtures.tsv` and the fixture audit output for
  release candidates.

See `docs/REMOTE_TRANSPORT.md` for protocol lifecycle, resource limits,
security guidance, and release-evidence commands.
