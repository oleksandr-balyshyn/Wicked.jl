import Wicked: app_view, initialize, subscriptions, update!

mutable struct RuntimeCounterModel
    count::Int
end

struct RuntimeCounterApp <: WickedApp end

initialize(::RuntimeCounterApp) = RuntimeCounterModel(0)
app_view(::RuntimeCounterApp, model::RuntimeCounterModel) = Label("count=$(model.count)")

function update!(::RuntimeCounterApp, model::RuntimeCounterModel, message)
    if message isa KeyEvent && message.key == Key(:up)
        model.count += 1
        return NoCommand()
    elseif message isa KeyEvent && message.key == Key(:q)
        return ExitCommand(model.count)
    elseif message == :increment
        model.count += 1
        return nothing
    elseif message == :quit
        return ExitCommand(model.count)
    end
    return nothing
end

struct RuntimeWorkerApp <: WickedApp end
struct RuntimeWorkDone
    value::Int
end
struct RuntimeWorkFailed end

initialize(::RuntimeWorkerApp) = nothing
app_view(::RuntimeWorkerApp, _) = Label("working")

function update!(::RuntimeWorkerApp, _, message)
    if message isa CustomEvent && message.payload == :work
        return TaskCommand(
            () -> 42;
            on_success=RuntimeWorkDone,
            on_error=_ -> RuntimeWorkFailed(),
        )
    elseif message isa CustomEvent && message.payload == :fail
        return TaskCommand(
            () -> error("worker failed");
            on_success=RuntimeWorkDone,
            on_error=_ -> RuntimeWorkFailed(),
        )
    elseif message isa RuntimeWorkDone
        return ExitCommand(message.value)
    elseif message isa RuntimeWorkFailed
        return ExitCommand(-1)
    end
    return nothing
end

struct RuntimeBatchApp <: WickedApp end
initialize(::RuntimeBatchApp) = RuntimeCounterModel(0)
app_view(::RuntimeBatchApp, model) = Label(string(model.count))
function update!(::RuntimeBatchApp, model::RuntimeCounterModel, message)
    message isa CustomEvent && message.payload == :start && return BatchCommand(
        MessageCommand(:increment),
        MessageCommand(:quit),
    )
    message == :increment && (model.count += 1; return nothing)
    message == :quit && return ExitCommand(model.count)
    return nothing
end

struct RuntimeUpdateFailureApp <: WickedApp end
initialize(::RuntimeUpdateFailureApp) = nothing
app_view(::RuntimeUpdateFailureApp, _) = Label("ready")
update!(::RuntimeUpdateFailureApp, _, ::CustomEvent) = error("update failed")

struct RuntimeViewFailureApp <: WickedApp end
initialize(::RuntimeViewFailureApp) = nothing
app_view(::RuntimeViewFailureApp, _) = error("view failed")
update!(::RuntimeViewFailureApp, _, _) = nothing

function runtime_source(events::AbstractEvent...)
    source = ChannelInputSource(max(1, length(events)))
    for event in events
        post_event!(source, event)
    end
    return source
end

@testset "Managed runtime" begin
    @testset "model update view and exit" begin
        backend = TestBackend(2, 20)
        source = runtime_source(KeyEvent(Key(:up)), KeyEvent(Key(:q)))
        result = run(
            RuntimeCounterApp();
            terminal=Terminal(backend),
            input_source=source,
        )

        @test result == 1
        @test backend.frame_count == 2
        @test occursin("count=1", sprint(show, MIME"text/plain"(), backend.screen))
    end

    @testset "batch commands" begin
        source = runtime_source(CustomEvent(:start))
        result = run(
            RuntimeBatchApp();
            terminal=Terminal(TestBackend(1, 8)),
            input_source=source,
        )
        @test result == 1
    end

    @testset "worker success and failure" begin
        success = run(
            RuntimeWorkerApp();
            terminal=Terminal(TestBackend(1, 10)),
            input_source=runtime_source(CustomEvent(:work)),
        )
        @test success == 42

        failure = run(
            RuntimeWorkerApp();
            terminal=Terminal(TestBackend(1, 10)),
            input_source=runtime_source(CustomEvent(:fail)),
        )
        @test failure == -1
    end

    @testset "async entry" begin
        task = run_async(
            RuntimeCounterApp();
            terminal=Terminal(TestBackend(1, 12)),
            input_source=runtime_source(KeyEvent(Key(:q))),
        )
        @test task isa Task
        @test fetch(task) == 0

        app = RuntimeCounterApp()
        runtime = ApplicationRuntime(
            app,
            initialize(app),
            Terminal(TestBackend(1, 12)),
            runtime_source(KeyEvent(Key(:q))),
        )
        @test fetch(run_async(runtime)) == 0
    end

    @testset "runtime controls" begin
        app = RuntimeCounterApp()
        runtime = ApplicationRuntime(
            app,
            initialize(app),
            Terminal(TestBackend(1, 12)),
            ChannelInputSource(),
        )
        @test !post!(runtime, :message)
        @test request_exit!(runtime, :result)
        @test runtime.result == :result
        @test_throws ArgumentError RuntimeConfig(queue_capacity=0)
        @test_throws ArgumentError RuntimeConfig(maximum_frames_per_second=0)
    end

    @testset "update and render failures restore terminal" begin
        update_backend = InjectedBackend()
        @test_throws ErrorException run(
            RuntimeUpdateFailureApp();
            terminal=Terminal(update_backend),
            input_source=runtime_source(CustomEvent(:fail)),
        )
        @test update_backend.leave_count == 1

        view_backend = InjectedBackend()
        @test_throws ErrorException run(
            RuntimeViewFailureApp();
            terminal=Terminal(view_backend),
            input_source=ChannelInputSource(),
        )
        @test view_backend.leave_count == 1
    end
end
