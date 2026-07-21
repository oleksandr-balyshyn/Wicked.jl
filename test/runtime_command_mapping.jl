import Wicked: app_view, initialize, update!

struct CommandMappingApp <: WickedApp end

mutable struct CommandMappingModel
    messages::Vector{Any}
end

initialize(::CommandMappingApp) = CommandMappingModel(Any[])
app_view(::CommandMappingApp, model::CommandMappingModel) = Label(string(length(model.messages)))

function update!(::CommandMappingApp, model::CommandMappingModel, message)
    if message === :start
        return map_command(
            value -> (:mapped, value),
            SequenceCommand(
                MessageCommand(:first),
                DelayCommand(0.25, :second),
                TaskCommand(() -> 3; on_success=value -> (:third, value)),
                TaskCommand(
                    () -> error("expected");
                    on_error=failure -> (:failed, failure.phase),
                ),
            ),
        )
    elseif message isa Tuple && first(message) === :mapped
        push!(model.messages, last(message))
    end
    return nothing
end

@testset "command message mapping" begin
    mapper = value -> (:wrapped, value)

    @test map_command(mapper, NoCommand()) isa NoCommand
    @test map_command(mapper, MessageCommand(:message)).message == (:wrapped, :message)
    delayed = map_command(mapper, DelayCommand(2, :later))
    @test delayed.delay_seconds == 2
    @test delayed.message == (:wrapped, :later)

    task = map_command(
        mapper,
        TaskCommand(() -> 7; id=:task, on_success=value -> (:ok, value), replace=true),
    )
    @test task.id == :task
    @test task.replace
    @test task.on_success(7) == (:wrapped, (:ok, 7))
    failure = RuntimeFailure(:command, :task, ErrorException("x"), nothing)
    @test task.on_error(failure) == (:wrapped, failure)

    terminal = map_command(
        mapper,
        TerminalCommand(identity; id=:terminal, on_success=value -> (:terminal, value)),
    )
    @test terminal.id == :terminal
    @test terminal.on_success(4) == (:wrapped, (:terminal, 4))

    process = ProcessCommand(
        `printf mapped`;
        id=:process,
        input="input",
        check=true,
        maximum_output_bytes=77,
        on_success=result -> (:process, result.exit_code),
        replace=true,
    )
    mapped_process = map_command(mapper, process)
    @test mapped_process.command == process.command
    @test mapped_process.input == process.input
    @test mapped_process.check
    @test mapped_process.maximum_output_bytes == 77
    @test mapped_process.replace
    result = ProcessResult(process.command, 0, UInt8[], UInt8[])
    @test mapped_process.on_success(result) == (:wrapped, (:process, 0))

    batch = map_command(
        mapper,
        BatchCommand(MessageCommand(:one), SequenceCommand(MessageCommand(:two))),
    )
    @test batch.commands[1].message == (:wrapped, :one)
    @test batch.commands[2].commands[1].message == (:wrapped, :two)

    cancel = CancelCommand(:work)
    exit = ExitCommand(:result)
    frame = FrameCommand()
    @test map_command(mapper, cancel) === cancel
    @test map_command(mapper, exit) === exit
    @test map_command(mapper, frame) === frame

    pilot = RuntimePilot(CommandMappingApp(); height=1, width=8)
    initial = send!(pilot, :start)
    @test initial.processed_messages == 2
    @test pilot.model.messages == Any[:first]
    @test pending_scheduled(pilot.clock) == 1

    advanced = advance_time!(pilot, 0.25)
    @test advanced.processed_messages == 3
    @test pilot.model.messages == Any[
        :first,
        :second,
        (:third, 3),
        (:failed, :command),
    ]
    @test pending_scheduled(pilot.clock) == 0
end
