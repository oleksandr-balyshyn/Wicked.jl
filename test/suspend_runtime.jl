struct SuspendPilotApp{C} <: WickedApp
    command::C
end

initialize(::SuspendPilotApp) = Any[]
app_view(::SuspendPilotApp, model) = Label("suspend=$(length(model))")

function update!(app::SuspendPilotApp, model, message)
    if message === :run
        return app.command
    elseif message isa CommandFinished
        push!(model, message)
    end
    nothing
end

@testset "Managed runtime suspension" begin
    @testset "direct lifecycle" begin
        app = RuntimeCounterApp()
        backend = InjectedBackend()
        runtime = ApplicationRuntime(
            app,
            initialize(app),
            Terminal(backend),
            ChannelInputSource();
            config=RuntimeConfig(resize_poll_seconds=nothing),
        )
        @test !suspend!(runtime)
        runtime.running = true

        @test suspend!(runtime)
        @test runtime.suspended
        @test backend.leave_count == 1
        @test !suspend!(runtime)

        runtime.terminal.force_redraw = false
        runtime.redraw = false
        @test resume!(runtime)
        @test !runtime.suspended
        @test backend.enter_count == 1
        @test runtime.terminal.force_redraw
        @test runtime.redraw
        @test !resume!(runtime)
        request_exit!(runtime)
    end

    @testset "deterministic suspend command" begin
        calls = Symbol[]
        command = SuspendCommand(
            () -> (push!(calls, :suspended); :continued);
            id=:suspend,
            on_success=value -> (:resumed, value),
        )
        pilot = RuntimePilot(SuspendPilotApp(command); height=1, width=8)
        result = send!(pilot, :run)
        @test result.processed_messages == 2
        @test calls == [:suspended]
        @test only(pilot.model) == CommandFinished(:suspend, (:resumed, :continued))
        @test pilot.terminal.force_redraw == false
        @test pilot.last_command isa NoCommand
    end

    @testset "failure resumes before delivery" begin
        failure_ref = Ref{Any}(nothing)
        command = SuspendCommand(
            () -> error("suspend callback failed");
            on_error=failure -> (failure_ref[] = failure; nothing),
        )
        pilot = RuntimePilot(SilentTerminalCommandApp(command); height=1, width=8)
        result = send!(pilot, :run)
        @test result.processed_messages == 1
        @test failure_ref[] isa RuntimeFailure
        @test failure_ref[].phase == :suspend
        @test pilot.terminal.force_redraw == false
    end

    @test_throws ArgumentError SuspendCommand(value -> value)
end
