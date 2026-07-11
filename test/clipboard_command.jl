mutable struct ClipboardCommandModel
    events::Vector{Any}
end

struct ClipboardCommandApp{S} <: WickedApp
    service::S
end

initialize(::ClipboardCommandApp) = ClipboardCommandModel(Any[])
app_view(::ClipboardCommandApp, model) = Label("clipboard=$(length(model.events))")

function update!(app::ClipboardCommandApp, model::ClipboardCommandModel, message)
    payload = message isa CustomEvent ? message.payload : message
    if payload === :write
        return WriteClipboardCommand(
            app.service,
            "hello";
            id=:write,
            on_success=_ -> :written,
        )
    elseif payload === :read
        return ReadClipboardCommand(
            app.service;
            id=:read,
            on_success=content -> isnothing(content) ? nothing : clipboard_text(content),
        )
    elseif payload === :clear
        return ClearClipboardCommand(
            app.service;
            id=:clear,
            on_success=_ -> :cleared,
        )
    elseif payload isa CommandFinished
        push!(model.events, payload)
    end
    nothing
end

@testset "Managed clipboard commands" begin
    provider = MemoryClipboard()
    service = ClipboardService(provider)
    pilot = RuntimePilot(ClipboardCommandApp(service); height=1, width=20)

    written = send!(pilot, CustomEvent(:write))
    @test written.processed_messages == 2
    @test clipboard_text(read_clipboard(provider)) == "hello"
    @test last(pilot.model.events) == CommandFinished(:write, :written)

    read_result = send!(pilot, CustomEvent(:read))
    @test read_result.processed_messages == 2
    @test last(pilot.model.events) == CommandFinished(:read, "hello")

    cleared = send!(pilot, CustomEvent(:clear))
    @test cleared.processed_messages == 2
    @test !clipboard_available(provider)
    @test last(pilot.model.events) == CommandFinished(:clear, :cleared)

    @test WriteClipboardCommand(service, "secret"; sensitive=true).content.sensitive
    @test_throws ArgumentError ReadClipboardCommand(service; now_ns=-1)

    denied = ClipboardService(
        MemoryClipboard();
        policy=ClipboardPolicy(allow_write=false),
        fallback_on_error=false,
    )
    failure_ref = Ref{Any}(nothing)
    command = WriteClipboardCommand(
        denied,
        "blocked";
        on_error=failure -> (failure_ref[] = failure; nothing),
    )
    silent_app = SilentTerminalCommandApp(command)
    failed_pilot = RuntimePilot(silent_app; height=1, width=8)
    result = send!(failed_pilot, :run)
    @test result.processed_messages == 1
    @test failure_ref[] isa RuntimeFailure
    @test failure_ref[].phase == :clipboard
    @test failure_ref[].error isa ClipboardError
end
