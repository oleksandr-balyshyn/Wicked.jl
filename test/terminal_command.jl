mutable struct TerminalCommandModel
    events::Vector{Any}
end

struct TerminalCommandApp <: WickedApp end

initialize(::TerminalCommandApp) = TerminalCommandModel(Any[])
app_view(::TerminalCommandApp, model::TerminalCommandModel) = Label("events=$(length(model.events))")

function update!(::TerminalCommandApp, model::TerminalCommandModel, message)
    payload = message isa CustomEvent ? message.payload : message
    if payload === :run
        return TerminalCommand(
            terminal -> begin
                push!(model.events, (:operation, terminal.frame_count))
                :complete
            end;
            id=:terminal_operation,
            on_success=value -> (:success, value),
        )
    elseif payload === :fail
        return TerminalCommand(
            terminal -> error("terminal operation failed");
            id=:failing_operation,
            on_error=failure -> (:failure, failure),
        )
    elseif payload isa CommandFinished
        push!(model.events, payload)
    elseif payload isa Tuple && first(payload) === :failure
        push!(model.events, payload)
    end
    nothing
end

struct SilentTerminalCommandApp{C} <: WickedApp
    command::C
end

initialize(::SilentTerminalCommandApp) = nothing
app_view(::SilentTerminalCommandApp, model) = Label("silent")
update!(app::SilentTerminalCommandApp, model, message) = app.command

@testset "Managed terminal commands" begin
    @testset "deterministic success" begin
        pilot = RuntimePilot(TerminalCommandApp(); height=1, width=16)
        result = send!(pilot, CustomEvent(:run))
        @test result.processed_messages == 2
        @test first(pilot.model.events) == (:operation, UInt64(1))
        finished = last(pilot.model.events)
        @test finished isa CommandFinished
        @test finished.id == :terminal_operation
        @test finished.value == (:success, :complete)
        @test pilot.last_command isa NoCommand
    end

    @testset "isolated error delivery" begin
        pilot = RuntimePilot(TerminalCommandApp(); height=1, width=16)
        result = send!(pilot, CustomEvent(:fail))
        @test result.processed_messages == 2
        payload = last(pilot.model.events)
        @test first(payload) === :failure
        failure = last(payload)
        @test failure isa RuntimeFailure
        @test failure.phase == :terminal
        @test failure.id == :failing_operation
        @test failure.error isa ErrorException
    end

    @testset "unidentified and silent operations" begin
        seen = Ref(false)
        command = TerminalCommand(
            terminal -> (seen[] = terminal isa Terminal);
            on_success=_ -> nothing,
        )
        @test command.id === nothing

        pilot = RuntimePilot(SilentTerminalCommandApp(command); height=1, width=8)
        result = send!(pilot, :run)
        @test result.processed_messages == 1
        @test seen[]
        @test isempty(pilot.queue)
    end
end
