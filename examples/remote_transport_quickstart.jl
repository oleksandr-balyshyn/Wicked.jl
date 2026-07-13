using Wicked.API

limits = RemoteProtocolLimits(maximum_packet_bytes=1_000_000)
packets = Vector{Vector{UInt8}}()

backend = RemoteBackend(
    packet -> push!(packets, copy(packet));
    size=Size(3, 24),
    capabilities=TerminalCapabilities(color_level=:truecolor),
    limits,
)
terminal = Terminal(backend)

enter!(backend)
hello = decode_remote_packet(packets[1]; limits)
@assert hello isa RemoteHello
@assert hello.size == Size(3, 24)

draw!(terminal) do frame
    render!(frame, Label("remote ready"), frame.area)
end

first_frame = decode_remote_packet(packets[end]; limits)
@assert first_frame isa RemoteFrame
@assert first_frame.full
@assert any(change -> change.cell.grapheme == "r", first_frame.changes)

draw!(terminal) do frame
    render!(frame, Label("remote done"), frame.area)
end

delta_frame = decode_remote_packet(packets[end]; limits)
@assert delta_frame isa RemoteFrame
@assert !delta_frame.full

request_remote_full_frame!(backend)
draw!(terminal) do frame
    render!(frame, Label("remote done"), frame.area)
end
@assert decode_remote_packet(packets[end]; limits).full

session_packets = Vector{Vector{UInt8}}()
session = RemoteSession(
    packet -> push!(session_packets, copy(packet));
    size=Size(3, 24),
    limits,
    input_capacity=4,
)

event_packet = encode_remote_message(RemoteEvent(UInt64(0), KeyEvent(Key(:enter))); limits)
@assert ingest_remote!(session, event_packet) == 1
@assert read_event!(session.input) == KeyEvent(Key(:enter))

resize_packet = encode_remote_message(RemoteEvent(UInt64(1), ResizeEvent(Size(4, 30))); limits)
@assert ingest_remote!(session, resize_packet) == 1
@assert backend_size(session.backend) == Size(4, 30)

ack_packet = encode_remote_message(RemoteAck(UInt64(7)); limits)
@assert ingest_remote!(session, ack_packet) == 1
@assert session.acknowledged_sequence == 7

close_remote_session!(session)

println("remote transport quickstart example completed")
