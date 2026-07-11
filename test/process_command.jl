struct ProcessPilotApp <: WickedApp
    command::Cmd
end

initialize(::ProcessPilotApp) = Any[]
app_view(::ProcessPilotApp, model) = Label("results=$(length(model))")

function update!(app::ProcessPilotApp, model, message)
    payload = message isa CustomEvent ? message.payload : message
    if payload === :run
        return ProcessCommand(
            app.command;
            id=:process,
            on_success=result -> (result.exit_code, String(result.stdout)),
        )
    elseif payload isa CommandFinished
        push!(model, payload)
    end
    nothing
end

struct FailingProcessPilotApp{C} <: WickedApp
    command::C
end

initialize(::FailingProcessPilotApp) = nothing
app_view(::FailingProcessPilotApp, model) = Label("failure")
update!(app::FailingProcessPilotApp, model, message) = app.command

@testset "Managed process commands" begin
    @testset "bounded standalone capture" begin
        command = `$(Base.julia_cmd()) --startup-file=no -e "print(\"out\"); print(stderr, \"err\"); exit(7)"`
        result = execute_process(ProcessCommand(command))
        @test result.command == command
        @test result.exit_code == 7
        @test String(result.stdout) == "out"
        @test String(result.stderr) == "err"
        @test !process_succeeded(result)

        checked = try
            execute_process(ProcessCommand(command; check=true))
            nothing
        catch error
            error
        end
        @test checked isa ProcessExitError
        @test checked.result.exit_code == 7
    end

    @testset "input and output bounds" begin
        echo = `$(Base.julia_cmd()) --startup-file=no -e "write(stdout, read(stdin))"`
        echoed = execute_process(ProcessCommand(echo; input="hello"))
        @test String(echoed.stdout) == "hello"

        noisy = `$(Base.julia_cmd()) --startup-file=no -e "print(repeat(\"x\", 32))"`
        @test_throws ProcessOutputLimitError execute_process(
            ProcessCommand(noisy; maximum_output_bytes=8),
        )
        @test_throws ArgumentError ProcessCommand(noisy; maximum_output_bytes=0)
    end

    @testset "deterministic injected pilot executor" begin
        command = `ignored-command`
        calls = Ref(0)
        pilot = RuntimePilot(
            ProcessPilotApp(command);
            height=1,
            width=16,
            process_executor=process_command -> begin
                calls[] += 1
                ProcessResult(process_command.command, 0, collect(codeunits("fake")), UInt8[])
            end,
        )
        result = send!(pilot, CustomEvent(:run))
        @test result.processed_messages == 2
        @test calls[] == 1
        finished = only(pilot.model)
        @test finished isa CommandFinished
        @test finished.id == :process
        @test finished.value == (0, "fake")
    end

    @testset "pilot error mapping" begin
        command = `ignored-command`
        failure_ref = Ref{Any}(nothing)
        process_command = ProcessCommand(
            command;
            on_error=failure -> (failure_ref[] = failure; nothing),
        )
        pilot = RuntimePilot(
            FailingProcessPilotApp(process_command);
            height=1,
            width=8,
            process_executor=_ -> error("injected process failure"),
        )
        result = send!(pilot, :run)
        @test result.processed_messages == 1
        @test failure_ref[] isa RuntimeFailure
        @test failure_ref[].phase == :process
    end
end
