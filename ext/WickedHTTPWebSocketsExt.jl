module WickedHTTPWebSocketsExt

using HTTP
using Wicked
using Wicked.API
using Wicked.Experimental
import Wicked: close_remote_session!,
               ingest_remote!,
               pump_websocket!,
               websocket_session

function websocket_session(
    websocket::HTTP.WebSockets.WebSocket;
    kwargs...,
)
    return RemoteSession(
        packet -> HTTP.WebSockets.send(websocket, packet);
        kwargs...,
    )
end

function pump_websocket!(
    session::RemoteSession,
    websocket::HTTP.WebSockets.WebSocket,
)
    try
        for message in websocket
            message isa AbstractVector{UInt8} ||
                throw(RemoteProtocolError("Wicked remote sessions require binary WebSocket messages"))
            ingest_remote!(session, message)
        end
    finally
        close_remote_session!(session)
    end
    return session
end

end
