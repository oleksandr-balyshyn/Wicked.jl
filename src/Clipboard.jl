module Clipboard

using Base64: base64encode, base64decode
using ..Runtime: AbstractCommand,
                 ApplicationRuntime,
                 CommandFinished,
                 RuntimeFailure,
                 post!
import ..Runtime: _execute!

export ClipboardContent,
       ClipboardPolicy,
       ClipboardError,
       AbstractClipboardProvider,
       MemoryClipboard,
       OSC52Selection,
       OSC52ClipboardSelection,
       OSC52PrimarySelection,
       OSC52SecondarySelection,
       OSC52Clipboard,
       write_clipboard!,
       read_clipboard,
       clear_clipboard!,
       clipboard_available,
       osc52_sequence,
       osc52_query,
       parse_osc52_response,
       ClipboardService,
       copy_to_clipboard!,
       paste_from_clipboard,
       clipboard_text,
       clear_clipboard_service!,
       AbstractClipboardCommand,
       ReadClipboardCommand,
       WriteClipboardCommand,
       ClearClipboardCommand

struct ClipboardContent
    data::Vector{UInt8}
    mime::String
    sensitive::Bool
    created_ns::UInt64

    function ClipboardContent(
        data::AbstractVector{UInt8};
        mime::AbstractString="text/plain;charset=utf-8",
        sensitive::Bool=false,
        created_ns::Integer=time_ns(),
    )
        0 <= created_ns <= typemax(UInt64) || throw(ArgumentError("clipboard timestamp must fit UInt64"))
        normalized_mime = lowercase(strip(String(mime)))
        media_type = first(split(normalized_mime, ';'; limit=2))
        occursin(r"^[a-z0-9][a-z0-9!#$&^_.+\-]*/[a-z0-9][a-z0-9!#$&^_.+\-]*$", media_type) ||
            throw(ArgumentError("clipboard MIME type is invalid"))
        any(iscntrl, normalized_mime) && throw(ArgumentError("clipboard MIME type contains controls"))
        new(Vector{UInt8}(data), normalized_mime, sensitive, UInt64(created_ns))
    end
end

ClipboardContent(
    text::AbstractString;
    mime::AbstractString="text/plain;charset=utf-8",
    kwargs...,
) = ClipboardContent(Vector{UInt8}(codeunits(String(text))); mime=mime, kwargs...)

struct ClipboardPolicy
    maximum_bytes::Int
    allowed_mime_prefixes::Vector{String}
    allow_read::Bool
    allow_write::Bool
    strip_text_controls::Bool
    sensitive_ttl_ns::UInt64

    function ClipboardPolicy(;
        maximum_bytes::Integer=1_000_000,
        allowed_mime_prefixes=("text/",),
        allow_read::Bool=true,
        allow_write::Bool=true,
        strip_text_controls::Bool=true,
        sensitive_ttl_ms::Integer=30_000,
    )
        maximum_bytes >= 0 || throw(ArgumentError("clipboard byte limit cannot be negative"))
        sensitive_ttl_ms >= 0 || throw(ArgumentError("sensitive clipboard TTL cannot be negative"))
        ttl = big(sensitive_ttl_ms) * 1_000_000
        ttl <= typemax(UInt64) || throw(ArgumentError("sensitive clipboard TTL is too large"))
        new(
            Int(maximum_bytes),
            String[lowercase(String(prefix)) for prefix in allowed_mime_prefixes],
            allow_read,
            allow_write,
            strip_text_controls,
            UInt64(ttl),
        )
    end
end

struct ClipboardError <: Exception
    operation::Symbol
    message::String
end

Base.showerror(io::IO, error::ClipboardError) =
    print(io, "clipboard ", error.operation, " failed: ", error.message)

abstract type AbstractClipboardProvider end

mutable struct MemoryClipboard <: AbstractClipboardProvider
    content::Union{Nothing,ClipboardContent}
    mutex::ReentrantLock
end

MemoryClipboard() = MemoryClipboard(nothing, ReentrantLock())

function _allowed(
    policy::ClipboardPolicy,
    content::ClipboardContent;
    operation::Symbol=:write,
)
    length(content.data) <= policy.maximum_bytes ||
        throw(ClipboardError(operation, "content exceeds the configured byte limit"))
    any(prefix -> startswith(content.mime, prefix), policy.allowed_mime_prefixes) ||
        throw(ClipboardError(operation, "MIME type is not allowed"))
    return true
end

function _sanitize_text(
    content::ClipboardContent,
    policy::ClipboardPolicy;
    operation::Symbol=:write,
)
    policy.strip_text_controls || return content
    startswith(content.mime, "text/") || return content
    text = String(copy(content.data))
    isvalid(text) || throw(ClipboardError(operation, "text clipboard data is not valid UTF-8"))
    sanitized = join(character for character in text if !iscntrl(character) || character in ('\n', '\r', '\t'))
    return ClipboardContent(
        sanitized;
        mime=content.mime,
        sensitive=content.sensitive,
        created_ns=content.created_ns,
    )
end

function write_clipboard!(
    provider::MemoryClipboard,
    content::ClipboardContent;
    policy::ClipboardPolicy=ClipboardPolicy(),
)
    policy.allow_write || throw(ClipboardError(:write, "clipboard writes are disabled"))
    _allowed(policy, content)
    sanitized = _sanitize_text(content, policy)
    _allowed(policy, sanitized)
    lock(provider.mutex) do
        provider.content = ClipboardContent(
            copy(sanitized.data);
            mime=sanitized.mime,
            sensitive=sanitized.sensitive,
            created_ns=sanitized.created_ns,
        )
    end
    return provider
end

function _expired(content::ClipboardContent, policy::ClipboardPolicy, now_ns::UInt64)
    content.sensitive || return false
    now_ns < content.created_ns && return true
    return now_ns - content.created_ns > policy.sensitive_ttl_ns
end

function read_clipboard(
    provider::MemoryClipboard;
    policy::ClipboardPolicy=ClipboardPolicy(),
    now_ns::Integer=time_ns(),
)
    policy.allow_read || throw(ClipboardError(:read, "clipboard reads are disabled"))
    0 <= now_ns <= typemax(UInt64) || throw(ArgumentError("clipboard timestamp must fit UInt64"))
    return lock(provider.mutex) do
        content = provider.content
        content === nothing && return nothing
        if _expired(content, policy, UInt64(now_ns))
            provider.content = nothing
            return nothing
        end
        return ClipboardContent(
            copy(content.data);
            mime=content.mime,
            sensitive=content.sensitive,
            created_ns=content.created_ns,
        )
    end
end

clear_clipboard!(provider::MemoryClipboard) =
    (lock(provider.mutex) do; provider.content = nothing; end; provider)

clipboard_available(provider::MemoryClipboard) = lock(provider.mutex) do
    provider.content !== nothing
end

@enum OSC52Selection begin
    OSC52ClipboardSelection
    OSC52PrimarySelection
    OSC52SecondarySelection
end

_osc52_code(selection::OSC52Selection) =
    selection == OSC52ClipboardSelection ? "c" :
    selection == OSC52PrimarySelection ? "p" : "s"

struct OSC52Clipboard{I<:IO} <: AbstractClipboardProvider
    output::I
    selection::OSC52Selection
    terminator::Symbol
end

function OSC52Clipboard(
    output::I=stdout;
    selection::OSC52Selection=OSC52ClipboardSelection,
    terminator::Symbol=:bel,
) where {I<:IO}
    terminator in (:bel, :st) || throw(ArgumentError("OSC 52 terminator must be :bel or :st"))
    return OSC52Clipboard{I}(output, selection, terminator)
end

function osc52_sequence(
    content::ClipboardContent;
    selection::OSC52Selection=OSC52ClipboardSelection,
    terminator::Symbol=:bel,
)
    terminator in (:bel, :st) || throw(ArgumentError("OSC 52 terminator must be :bel or :st"))
    suffix = terminator == :st ? "\e\\" : "\a"
    return "\e]52;$(_osc52_code(selection));$(base64encode(content.data))$suffix"
end

function write_clipboard!(
    provider::OSC52Clipboard,
    content::ClipboardContent;
    policy::ClipboardPolicy=ClipboardPolicy(),
)
    policy.allow_write || throw(ClipboardError(:write, "clipboard writes are disabled"))
    _allowed(policy, content)
    sanitized = _sanitize_text(content, policy)
    _allowed(policy, sanitized)
    try
        print(
            provider.output,
            osc52_sequence(
                sanitized;
                selection=provider.selection,
                terminator=provider.terminator,
            ),
        )
        flush(provider.output)
    catch error
        throw(ClipboardError(:write, "OSC 52 transport failed: $(sprint(showerror, error))"))
    end
    return provider
end

function osc52_query(
    selection::OSC52Selection=OSC52ClipboardSelection;
    terminator::Symbol=:bel,
)
    terminator in (:bel, :st) || throw(ArgumentError("OSC 52 terminator must be :bel or :st"))
    suffix = terminator == :st ? "\e\\" : "\a"
    return "\e]52;$(_osc52_code(selection));?$suffix"
end

function parse_osc52_response(
    response::AbstractString;
    policy::ClipboardPolicy=ClipboardPolicy(),
    sensitive::Bool=false,
    selection::Union{Nothing,OSC52Selection}=nothing,
    mime::AbstractString="text/plain;charset=utf-8",
)
    policy.allow_read || throw(ClipboardError(:read, "clipboard reads are disabled"))
    matched = match(r"\A\x1b\]52;([cps]);([A-Za-z0-9+/=]*)(?:\x07|\x1b\\)\z", String(response))
    matched === nothing && throw(ClipboardError(:parse, "invalid OSC 52 response"))
    selection_code = String(matched.captures[1])
    selection === nothing || selection_code == _osc52_code(selection) ||
        throw(ClipboardError(:parse, "OSC 52 response selection does not match the request"))
    encoded = String(matched.captures[2])
    maximum_encoded = cld(big(policy.maximum_bytes), 3) * 4
    big(ncodeunits(encoded)) <= maximum_encoded ||
        throw(ClipboardError(:parse, "OSC 52 response exceeds the byte limit"))
    data = try
        base64decode(encoded)
    catch
        throw(ClipboardError(:parse, "OSC 52 response contains invalid Base64"))
    end
    content = ClipboardContent(data; mime, sensitive)
    _allowed(policy, content; operation=:parse)
    content = _sanitize_text(content, policy; operation=:parse)
    _allowed(policy, content; operation=:parse)
    return content
end

read_clipboard(::OSC52Clipboard; kwargs...) =
    throw(ClipboardError(:read, "OSC 52 reads require sending osc52_query and parsing the asynchronous response"))

clear_clipboard!(provider::OSC52Clipboard) = begin
    empty = ClipboardContent(UInt8[])
    try
        print(provider.output, osc52_sequence(empty; selection=provider.selection, terminator=provider.terminator))
        flush(provider.output)
    catch error
        throw(ClipboardError(:clear, "OSC 52 transport failed: $(sprint(showerror, error))"))
    end
    provider
end

clipboard_available(::OSC52Clipboard) = true

mutable struct ClipboardService{P<:AbstractClipboardProvider}
    provider::P
    fallback::MemoryClipboard
    policy::ClipboardPolicy
    fallback_on_error::Bool
end

ClipboardService(
    provider::P;
    fallback::MemoryClipboard=MemoryClipboard(),
    policy::ClipboardPolicy=ClipboardPolicy(),
    fallback_on_error::Bool=true,
) where {P<:AbstractClipboardProvider} =
    ClipboardService{P}(provider, fallback, policy, fallback_on_error)

function copy_to_clipboard!(service::ClipboardService, content::ClipboardContent)
    try
        write_clipboard!(service.provider, content; policy=service.policy)
    catch error
        service.fallback_on_error || rethrow()
        error isa ClipboardError || rethrow()
        write_clipboard!(service.fallback, content; policy=service.policy)
    end
    return service
end

copy_to_clipboard!(service::ClipboardService, text::AbstractString; kwargs...) =
    copy_to_clipboard!(service, ClipboardContent(text; kwargs...))

function paste_from_clipboard(service::ClipboardService; now_ns::Integer=time_ns())
    try
        content = read_clipboard(service.provider; policy=service.policy, now_ns=now_ns)
        content === nothing || return content
    catch error
        service.fallback_on_error || rethrow()
        error isa ClipboardError || rethrow()
    end
    return read_clipboard(service.fallback; policy=service.policy, now_ns=now_ns)
end

function clipboard_text(content::ClipboardContent)
    startswith(content.mime, "text/") || throw(ClipboardError(:decode, "clipboard content is not text"))
    text = String(copy(content.data))
    isvalid(text) || throw(ClipboardError(:decode, "clipboard text is not valid UTF-8"))
    return text
end

function clear_clipboard_service!(service::ClipboardService)
    try
        clear_clipboard!(service.provider)
    catch error
        service.fallback_on_error || rethrow()
        error isa ClipboardError || rethrow()
    end
    clear_clipboard!(service.fallback)
    return service
end

"""Base type for explicit managed-runtime clipboard requests."""
abstract type AbstractClipboardCommand <: AbstractCommand end

struct ReadClipboardCommand{S,E,K} <: AbstractClipboardCommand
    id::K
    service::ClipboardService
    now_ns::Union{Nothing,UInt64}
    on_success::S
    on_error::E
end

function ReadClipboardCommand(
    service::ClipboardService;
    id=nothing,
    now_ns::Union{Nothing,Integer}=nothing,
    on_success::S=identity,
    on_error::E=identity,
) where {S,E}
    resolved_now = if isnothing(now_ns)
        nothing
    else
        0 <= now_ns <= typemax(UInt64) ||
            throw(ArgumentError("clipboard timestamp must fit UInt64"))
        UInt64(now_ns)
    end
    ReadClipboardCommand{S,E,typeof(id)}(
        id,
        service,
        resolved_now,
        on_success,
        on_error,
    )
end

struct WriteClipboardCommand{S,E,K} <: AbstractClipboardCommand
    id::K
    service::ClipboardService
    content::ClipboardContent
    on_success::S
    on_error::E
end

function WriteClipboardCommand(
    service::ClipboardService,
    content::ClipboardContent;
    id=nothing,
    on_success::S=identity,
    on_error::E=identity,
) where {S,E}
    WriteClipboardCommand{S,E,typeof(id)}(id, service, content, on_success, on_error)
end

function WriteClipboardCommand(
    service::ClipboardService,
    text::AbstractString;
    mime::AbstractString="text/plain;charset=utf-8",
    sensitive::Bool=false,
    id=nothing,
    on_success::S=identity,
    on_error::E=identity,
) where {S,E}
    WriteClipboardCommand(
        service,
        ClipboardContent(text; mime, sensitive);
        id,
        on_success,
        on_error,
    )
end

struct ClearClipboardCommand{S,E,K} <: AbstractClipboardCommand
    id::K
    service::ClipboardService
    on_success::S
    on_error::E
end

function ClearClipboardCommand(
    service::ClipboardService;
    id=nothing,
    on_success::S=identity,
    on_error::E=identity,
) where {S,E}
    ClearClipboardCommand{S,E,typeof(id)}(id, service, on_success, on_error)
end

_clipboard_command_value(command::ReadClipboardCommand) =
    isnothing(command.now_ns) ? paste_from_clipboard(command.service) :
    paste_from_clipboard(command.service; now_ns=command.now_ns)

_clipboard_command_value(command::WriteClipboardCommand) =
    copy_to_clipboard!(command.service, command.content)

_clipboard_command_value(command::ClearClipboardCommand) =
    clear_clipboard_service!(command.service)

function _clipboard_command_message(command::AbstractClipboardCommand)
    try
        value = _clipboard_command_value(command)
        resolved = command.on_success(value)
        isnothing(command.id) ? resolved : CommandFinished(command.id, resolved)
    catch error
        failure = RuntimeFailure(:clipboard, command.id, error, catch_backtrace())
        command.on_error(failure)
    end
end

function _execute!(runtime::ApplicationRuntime, command::AbstractClipboardCommand)
    message = _clipboard_command_message(command)
    isnothing(message) || post!(runtime, message)
    nothing
end

end
