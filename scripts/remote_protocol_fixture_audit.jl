#!/usr/bin/env julia

module RemoteProtocolFixtureAudit

using Wicked.API: ALT,
                  BOLD,
                  BarCursor,
                  Cell,
                  CellChange,
                  CursorRequest,
                  FocusEvent,
                  Key,
                  KeyEvent,
                  KeyPress,
                  LeftMouseButton,
                  MouseDrag,
                  MouseEvent,
                  Position,
                  REMOTE_PROTOCOL_VERSION,
                  RGBColor,
                  RemoteAck,
                  RemoteEvent,
                  RemoteFrame,
                  RemoteHello,
                  RemoteProtocolError,
                  ResizeEvent,
                  Size,
                  Style,
                  TerminalCapabilities,
                  decode_remote_packet,
                  encode_remote_message

const ROOT = normpath(joinpath(@__DIR__, ".."))
const FIXTURES = joinpath(ROOT, "api", "remote_protocol_fixtures.tsv")
const MAGIC = UInt8[0x57, 0x4b, 0x54, 0x31]
const HEADER_BYTES = 20
const REQUIRED_CASES = Set((
    "hello-basic",
    "full-frame-basic",
    "key-event-character",
    "mouse-event-drag",
    "resize-event",
    "ack-basic",
))
const REQUIRED_COLUMNS = (
    "case",
    "message",
    "sequence",
    "kind",
    "flags",
    "minimum_payload_bytes",
    "notes",
)

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/remote_protocol_fixture_audit.jl [api/remote_protocol_fixtures.tsv]")
    println(io, "")
    println(io, "Validates protocol-v1 remote packet envelope fixtures.")
end

function read_unsigned(bytes, first::Integer, count::Integer)
    value = UInt64(0)
    for index in first:(first + count - 1)
        value = (value << 8) | UInt64(bytes[index])
    end
    return value
end

function parse_integer(value::AbstractString, path::AbstractString, line::Integer, column::AbstractString)
    try
        return parse(Int, strip(value))
    catch error
        throw(ArgumentError("$(relpath(path, ROOT)):$line has invalid integer in `$column`: $(sprint(showerror, error))"))
    end
end

function read_rows(path::AbstractString=FIXTURES)
    isfile(path) || error("missing remote protocol fixture ledger: $(relpath(path, ROOT))")
    lines = readlines(path)
    header_index = findfirst(line -> !isempty(strip(line)) && !startswith(strip(line), "#"), lines)
    header_index === nothing && error("remote protocol fixture ledger has no header: $(relpath(path, ROOT))")
    header = split(lines[header_index], '\t')
    indexes = Dict(name => index for (index, name) in pairs(header))
    for column in REQUIRED_COLUMNS
        haskey(indexes, column) || error("remote protocol fixture ledger is missing `$column` column")
    end
    rows = NamedTuple[]
    seen = Set{String}()
    for line_number in (header_index + 1):length(lines)
        line = lines[line_number]
        stripped = strip(line)
        isempty(stripped) && continue
        startswith(stripped, "#") && continue
        fields = split(line, '\t'; keepempty=true)
        length(fields) == length(header) ||
            error("$(relpath(path, ROOT)):$line_number has $(length(fields)) fields, expected $(length(header))")
        name = strip(fields[indexes["case"]])
        isempty(name) && error("$(relpath(path, ROOT)):$line_number has empty fixture case")
        name in seen && error("$(relpath(path, ROOT)):$line_number duplicates fixture case `$name`")
        push!(seen, name)
        push!(
            rows,
            (
                line=line_number,
                name=name,
                message=strip(fields[indexes["message"]]),
                sequence=parse_integer(fields[indexes["sequence"]], path, line_number, "sequence"),
                kind=parse_integer(fields[indexes["kind"]], path, line_number, "kind"),
                flags=parse_integer(fields[indexes["flags"]], path, line_number, "flags"),
                minimum_payload_bytes=parse_integer(fields[indexes["minimum_payload_bytes"]], path, line_number, "minimum_payload_bytes"),
                notes=strip(fields[indexes["notes"]]),
            ),
        )
    end
    return rows
end

function fixture_message(name::AbstractString)
    capabilities = TerminalCapabilities(
        color_level=:truecolor,
        mouse=true,
        focus=true,
        bracketed_paste=true,
        synchronized_updates=true,
        enhanced_keyboard=true,
        underline_color=true,
    )
    if name == "hello-basic"
        return RemoteHello(UInt64(7), Size(24, 80), capabilities)
    elseif name == "full-frame-basic"
        style = Style(foreground=RGBColor(1, 2, 3), modifiers=BOLD)
        changes = [
            CellChange(Position(1, 1), Cell("a"; style)),
            CellChange(Position(1, 2), Cell("b"; style)),
        ]
        return RemoteFrame(UInt64(8), true, Size(1, 2), changes, CursorRequest(Position(1, 2); shape=BarCursor))
    elseif name == "key-event-character"
        return RemoteEvent(UInt64(9), KeyEvent(Key(:character); text="x", kind=KeyPress, raw=UInt8[0x78]))
    elseif name == "mouse-event-drag"
        return RemoteEvent(UInt64(10), MouseEvent(Position(3, 4), LeftMouseButton, MouseDrag; modifiers=ALT, click_count=2))
    elseif name == "resize-event"
        return RemoteEvent(UInt64(11), ResizeEvent(Size(40, 120)))
    elseif name == "ack-basic"
        return RemoteAck(UInt64(12))
    end
    throw(ArgumentError("unknown remote protocol fixture case `$name`"))
end

function message_name(message)
    message isa RemoteHello && return "RemoteHello"
    message isa RemoteFrame && return "RemoteFrame"
    message isa RemoteEvent && return "RemoteEvent"
    message isa RemoteAck && return "RemoteAck"
    return string(typeof(message))
end

function envelope(packet)
    length(packet) >= HEADER_BYTES || throw(RemoteProtocolError("fixture packet is shorter than remote protocol header"))
    return (
        magic=packet[1:4],
        version=Int(read_unsigned(packet, 5, 2)),
        kind=Int(packet[7]),
        flags=Int(packet[8]),
        sequence=read_unsigned(packet, 9, 8),
        payload_length=Int(read_unsigned(packet, 17, 4)),
    )
end

function audit(path::AbstractString=FIXTURES)
    rows = try
        read_rows(path)
    catch error
        return String[sprint(showerror, error)]
    end
    failures = String[]
    observed = Set(row.name for row in rows)
    for name in sort!(collect(setdiff(REQUIRED_CASES, observed)))
        push!(failures, "remote protocol fixture ledger missing required case `$name`")
    end
    for row in rows
        message = try
            fixture_message(row.name)
        catch error
            push!(failures, "api/remote_protocol_fixtures.tsv:$(row.line) $(sprint(showerror, error))")
            continue
        end
        message_name(message) == row.message ||
            push!(failures, "$(row.name) fixture message expected $(row.message), got $(message_name(message))")
        packet = encode_remote_message(message)
        decoded = decode_remote_packet(packet)
        message_name(decoded) == row.message ||
            push!(failures, "$(row.name) decoded message expected $(row.message), got $(message_name(decoded))")
        decoded.sequence == UInt64(row.sequence) ||
            push!(failures, "$(row.name) decoded sequence expected $(row.sequence), got $(decoded.sequence)")
        header = envelope(packet)
        header.magic == MAGIC || push!(failures, "$(row.name) remote packet magic changed")
        header.version == Int(REMOTE_PROTOCOL_VERSION) ||
            push!(failures, "$(row.name) protocol version expected $(Int(REMOTE_PROTOCOL_VERSION)), got $(header.version)")
        header.kind == row.kind || push!(failures, "$(row.name) packet kind expected $(row.kind), got $(header.kind)")
        header.flags == row.flags || push!(failures, "$(row.name) packet flags expected $(row.flags), got $(header.flags)")
        header.sequence == UInt64(row.sequence) ||
            push!(failures, "$(row.name) packet sequence expected $(row.sequence), got $(header.sequence)")
        header.payload_length + HEADER_BYTES == length(packet) ||
            push!(failures, "$(row.name) payload length does not match packet length")
        header.payload_length >= row.minimum_payload_bytes ||
            push!(failures, "$(row.name) payload length expected at least $(row.minimum_payload_bytes), got $(header.payload_length)")
        isempty(row.notes) && push!(failures, "$(row.name) must document why the fixture exists")
    end
    return failures
end

function main(arguments=ARGS)
    "--help" in arguments && (print_usage(); return 0)
    path = isempty(arguments) ? FIXTURES : only(arguments)
    failures = audit(path)
    if isempty(failures)
        println("remote protocol fixture audit: checked $(length(read_rows(path))) protocol-v1 fixtures")
        return 0
    end
    foreach(failure -> println(stderr, "remote protocol fixture audit: $failure"), failures)
    return 1
end

end # module RemoteProtocolFixtureAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(RemoteProtocolFixtureAudit.main())
end
