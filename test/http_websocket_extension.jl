using HTTP
using Test
using Wicked
using Wicked.API
using Wicked.Experimental

@testset "HTTP WebSocket extension" begin
    sessions = Channel{RemoteSession}(1)
    completed = Channel{Any}(1)
    server = HTTP.WebSockets.listen!("127.0.0.1", 0; listenany=true, maxframesize=4096) do websocket
        session = websocket_session(websocket; size=Size(2, 4))
        put!(sessions, session)
        try
            enter!(session.backend)
            pump_websocket!(session, websocket)
            put!(completed, :ok)
        catch error
            put!(completed, error)
        end
    end

    try
        url = "ws://" * HTTP.WebSockets.server_addr(server) * "/wicked"
        HTTP.WebSockets.open(url; maxframesize=4096) do websocket
            hello = decode_remote_packet(HTTP.WebSockets.receive(websocket))
            @test hello isa RemoteHello
            @test hello.size == Size(2, 4)

            HTTP.WebSockets.send(
                websocket,
                encode_remote_message(RemoteEvent(0, KeyEvent(Key(:character); text="x"))),
            )
            HTTP.WebSockets.send(
                websocket,
                encode_remote_message(RemoteEvent(1, ResizeEvent(Size(3, 5)))),
            )
            HTTP.WebSockets.send(websocket, encode_remote_message(RemoteAck(hello.sequence)))
        end

        session = take!(sessions)
        result = take!(completed)
        result === :ok || throw(result)
        @test read_event!(session.input) == KeyEvent(Key(:character); text="x")
        @test read_event!(session.input) == ResizeEvent(Size(3, 5))
        @test backend_size(session.backend) == Size(3, 5)
        @test session.acknowledged_sequence == 0
        @test session.closed
        @test_throws RemoteProtocolError ingest_remote!(session, UInt8[])
    finally
        HTTP.WebSockets.forceclose(server)
    end
end
