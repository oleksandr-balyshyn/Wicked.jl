mutable struct TestingPilotModel
    count::Int
end

struct TestingPilotApp <: WickedApp end

initialize(::TestingPilotApp) = TestingPilotModel(0)
app_view(::TestingPilotApp, model::TestingPilotModel) = Label("count=$(model.count)")

function update!(::TestingPilotApp, model::TestingPilotModel, message)
    payload = message isa CustomEvent ? message.payload : message
    if message isa KeyEvent && message.key == Key(:up)
        model.count += 1
    elseif payload === :increment
        model.count += 1
    elseif payload === :delay
        return DelayCommand(0.5, :increment)
    elseif payload === :task
        return TaskCommand(() -> 7; on_success=value -> (:set, value))
    elseif payload isa Tuple && first(payload) === :set
        model.count = last(payload)
    elseif payload === :batch
        return BatchCommand(MessageCommand(:increment), MessageCommand(:increment))
    elseif payload === :exit
        return ExitCommand(model.count)
    end
    nothing
end

@testset "Headless testing API" begin
    @testset "capability-configurable backend" begin
        capabilities = TerminalCapabilities(
            color_level=:truecolor,
            mouse=false,
            focus=false,
        )
        backend = TestBackend(3, 7; capabilities)
        @test size(backend.screen) == (3, 7)
        @test backend.capabilities === capabilities
    end

    @testset "virtual monotonic clock" begin
        clock = VirtualClock(start_ns=10)
        observed = Any[]
        first_token = schedule_after!(clock, 1.0) do current
            push!(observed, (:first, virtual_time_ns(current)))
            schedule_after!(current, 0.0, () -> push!(observed, :nested))
        end
        cancelled = schedule_after!(() -> push!(observed, :cancelled), clock, 0.5)

        @test first_token isa ScheduledToken
        @test pending_scheduled(clock) == 2
        @test cancel_scheduled!(clock, cancelled)
        @test !cancel_scheduled!(clock, cancelled)
        @test advance_time!(clock, 0.5) == 0
        @test virtual_time_ns(clock) == 500_000_010
        @test advance_time!(clock, 0.5) == 2
        @test observed == [(:first, 1_000_000_010), :nested]
        @test pending_scheduled(clock) == 0
        @test_throws ArgumentError advance_time!(clock, -1)
        @test_throws ArgumentError schedule_after!(clock, Inf, () -> nothing)
    end

    @testset "snapshots and assertions" begin
        buffer = Buffer(1, 3)
        style = Style(foreground=AnsiColor(1), modifiers=BOLD)
        render!(buffer, Label("X"; style), buffer.area)

        @test plain_snapshot(buffer) == "X"
        structured = structured_snapshot(buffer)
        @test length(structured) == 3
        @test structured[1].foreground == (UInt8(1), UInt32(1))
        @test hasproperty(structured[1], :hyperlink)

        ansi = ansi_snapshot(buffer; capabilities=TerminalCapabilities(color_level=:ansi16))
        @test occursin("\e[0;31;49;1mX", ansi)
        @test endswith(ansi, "\e[0m")

        @test assert_cell(buffer, 1, 1, buffer[1, 1]) == buffer[1, 1]
        @test assert_cell(buffer, 1, 1; grapheme="X", style) == buffer[1, 1]
        @test assert_plain_snapshot(buffer, "X") === buffer
        @test assert_ansi_snapshot(buffer, ansi; capabilities=TerminalCapabilities(color_level=:ansi16)) === buffer
        @test_throws BufferAssertionError assert_cell(buffer, 1, 1; grapheme="Z")
        @test_throws BufferAssertionError assert_plain_snapshot(buffer, "Y")
    end

    @testset "pilot queries, time, and exit" begin
        pilot = ToolkitPilot(
            Element(
                Button("Alpha");
                id=:alpha,
                classes=[:copy],
            );
            height=3,
            width=9,
        )

        match = query_one(pilot; id=:alpha)
        @test match.state isa ButtonState
        @test length(query(pilot; text="Alpha")) == 1
        @test length(query(pilot; text=r"Alpha")) == 1
        @test length(query(pilot; text=value -> occursin("Alpha", value))) == 1
        @test length(query(pilot; state=match.state)) == 1
        @test length(query(pilot; state=ButtonState)) == 1
        @test length(query(pilot; state=value -> value isa ButtonState)) == 1
        @test isempty(query(pilot; text="missing"))
        @test isempty(query(pilot; state=nothing))
        @test_throws ArgumentError query(pilot; text=_ -> :not_a_bool)
        @test_throws ArgumentError query(pilot; state=_ -> :not_a_bool)

        advance_time!(pilot, 0.25)
        @test virtual_time_ns(pilot.clock) == 250_000_000
        @test request_exit!(pilot, :accepted)
        @test pilot.exited
        @test pilot.result == :accepted
    end

    @testset "deterministic managed runtime pilot" begin
        pilot = RuntimePilot(TestingPilotApp(); height=1, width=12)
        @test pilot.model.count == 0
        @test plain_snapshot(pilot) == "count=0"

        update_result = send!(pilot, CustomEvent(:increment))
        @test update_result.accepted
        @test update_result.processed_messages == 1
        @test update_result.redrawn
        @test pilot.model.count == 1
        @test plain_snapshot(pilot) == "count=1"

        send!(pilot, CustomEvent(:delay))
        @test pending_scheduled(pilot.clock) == 1
        @test pilot.model.count == 1
        advance_time!(pilot, 0.49)
        @test pilot.model.count == 1
        delayed = advance_time!(pilot, 0.01)
        @test delayed.processed_messages == 1
        @test pilot.model.count == 2
        @test pending_scheduled(pilot.clock) == 0

        task_result = send!(pilot, CustomEvent(:task))
        @test task_result.processed_messages == 2
        @test pilot.model.count == 7
        batch_result = send!(pilot, CustomEvent(:batch))
        @test batch_result.processed_messages == 3
        @test pilot.model.count == 9
        key!(pilot, :up)
        @test pilot.model.count == 10

        resize_terminal!(pilot, 2, 16)
        @test size(pilot.backend.screen) == (2, 16)
        exit_result = send!(pilot, CustomEvent(:exit))
        @test exit_result.exited
        @test exit_result.result == 10
        rejected = send!(pilot, :increment)
        @test !rejected.accepted
        @test pilot.model.count == 10
    end

    @testset "immediate widget pilot" begin
        stateless = WidgetPilot(Label("hello"); height=1, width=8)
        @test !stateless.stateful
        @test stateless.state === nothing
        @test plain_snapshot(stateless) == "hello"
        ignored = key!(stateless, :enter)
        @test !ignored.handled
        @test !ignored.redrawn

        pilot = WidgetPilot(Button("Go"); height=3, width=8)
        @test pilot.stateful
        @test pilot.state isa ButtonState
        pressed = key!(pilot, :enter)
        @test pressed.handled
        @test pressed.redrawn
        @test pilot.state.pressed
        released = key!(pilot, :enter; kind=KeyRelease)
        @test released.handled
        @test !pilot.state.pressed

        clicked = click!(pilot, 2, 4)
        @test clicked.handled
        @test !pilot.state.pressed
        ticked = advance_time!(pilot, 0.25)
        @test !ticked.handled
        @test virtual_time_ns(pilot.clock) == 250_000_000

        resize_terminal!(pilot, 3, 10)
        @test size(pilot.backend.screen) == (3, 10)
        @test occursin("Go", plain_snapshot(pilot))
    end
end
