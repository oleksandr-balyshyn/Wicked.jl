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

struct RuntimeCancellationRaceApp <: WickedApp end

mutable struct RuntimeCancellationRaceModel
    requested::Int
    completed::Int
    latest_request::Int
    failed::Int
    release::Base.RefValue{Bool}
end

initialize(::RuntimeCancellationRaceApp) = RuntimeCancellationRaceModel(0, 0, 0, 0, Ref(false))
app_view(::RuntimeCancellationRaceApp, model) = Label("requests=$(model.requested) completed=$(model.completed)")

function update!(::RuntimeCancellationRaceApp, model::RuntimeCancellationRaceModel, message)
    if message isa CustomEvent && message.payload == :work
        model.requested += 1
        request_id = model.requested
        return TaskCommand(
            token -> begin
                while !model.release[] && !token.cancelled
                    yield()
                end
                token.cancelled && return request_id
                sleep(0.005)
                request_id
            end;
            id=:search,
            on_success=value -> (:completed, request_id, value),
            on_error=_ -> (:failed, request_id),
            replace=true,
        )
    elseif message isa CustomEvent && message.payload == :cancel
        return CancelCommand(:search)
    elseif message isa CommandFinished && message.value isa Tuple{Symbol,Int,Int}
        message.value[1] == :completed && (model.completed += 1; model.latest_request = message.value[2])
        return nothing
    elseif message isa Tuple{Symbol,Int}
        message[1] == :failed && (model.failed += 1)
        return nothing
    end
    return nothing
end

struct RuntimeBatchApp <: WickedApp end

struct RuntimeSequenceApp <: WickedApp end

mutable struct DeclarativeApplicationViewModel
    phase::Int
end

struct DeclarativeApplicationViewApp <: WickedApp end

initialize(::DeclarativeApplicationViewApp) = DeclarativeApplicationViewModel(0)

function app_view(::DeclarativeApplicationViewApp, model::DeclarativeApplicationViewModel)
    enabled = model.phase == 0
    ApplicationView(
        Label(enabled ? "first" : "second");
        title=enabled ? "Wicked: first" : "Wicked: second",
        cursor=enabled ? CursorRequest(Position(1, 2); shape=BarCursor) : nothing,
        alternate_screen=enabled,
        mouse_capture=enabled,
        mouse_tracking=AnyMotionTracking,
        focus_reporting=enabled,
        bracketed_paste=enabled,
    )
end


function update!(
    ::DeclarativeApplicationViewApp,
    model::DeclarativeApplicationViewModel,
    message,
)
    if message isa CustomEvent && message.payload === :next
        model.phase = 1
    elseif message isa CustomEvent && message.payload === :quit
        return ExitCommand(model.phase)
    end
    nothing
end

mutable struct RuntimeSequenceModel
    trace::Vector{Symbol}
end

initialize(::RuntimeSequenceApp) = RuntimeSequenceModel(Symbol[])
app_view(::RuntimeSequenceApp, model) = Label(join(model.trace, ','))

function update!(::RuntimeSequenceApp, model::RuntimeSequenceModel, message)
    if message isa CustomEvent && message.payload == :start
        return SequenceCommand(
            TaskCommand(() -> begin
                push!(model.trace, :first_started)
                sleep(0.02)
                push!(model.trace, :first_finished)
                :first_message
            end),
            BatchCommand(
                TaskCommand(() -> begin
                    sleep(0.01)
                    push!(model.trace, :batch_one_finished)
                    :batch_one_message
                end),
                TaskCommand(() -> begin
                    sleep(0.015)
                    push!(model.trace, :batch_two_finished)
                    :batch_two_message
                end),
            ),
            TaskCommand(() -> begin
                push!(model.trace, :last_started)
                :last_message
            end),
        )
    elseif message isa Symbol
        push!(model.trace, message)
        message == :last_message && return ExitCommand(copy(model.trace))
    end
    nothing
end

struct RuntimeShutdownStressApp <: WickedApp end

mutable struct RuntimeShutdownStressModel
    requested::Int
    completed::Int
    ticks::Int
    released::Base.RefValue{Bool}
end

initialize(::RuntimeShutdownStressApp) = RuntimeShutdownStressModel(0, 0, 0, Ref(false))
app_view(::RuntimeShutdownStressApp, model) = Label("ticks=$(model.ticks) completed=$(model.completed)")

function update!(::RuntimeShutdownStressApp, model::RuntimeShutdownStressModel, message)
    if message isa CustomEvent && message.payload == :work
        model.requested += 1
        request_id = model.requested
        return TaskCommand(
            token -> begin
                while !model.released[] && !token.cancelled
                    yield()
                end
                token.cancelled && return request_id
                sleep(0.2)
                request_id
            end;
            id=:search,
            on_success=value -> (:finished, request_id, value),
            replace=true,
        )
    elseif message isa CommandFinished && message.value isa Tuple{Symbol,Int,Int}
        message.value[1] == :finished && (model.completed += 1)
        return nothing
    elseif message == :tick
        model.ticks += 1
        return nothing
    end
    return nothing
end

function subscriptions(::RuntimeShutdownStressApp, ::RuntimeShutdownStressModel)
    (IntervalSubscription(:ticker, 0.001, :tick),)
end

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

    @testset "sequence commands preserve completion and message order" begin
        trace = run(
            RuntimeSequenceApp();
            terminal=Terminal(TestBackend(1, 80)),
            input_source=runtime_source(CustomEvent(:start)),
        )
        @test findfirst(==(:first_finished), trace) < findfirst(==(:first_message), trace)
        @test findfirst(==(:first_message), trace) < findfirst(==(:last_started), trace)
        @test findfirst(==(:batch_one_finished), trace) < findfirst(==(:last_started), trace)
        @test findfirst(==(:batch_two_finished), trace) < findfirst(==(:last_started), trace)
        @test trace[end-1:end] == [:last_started, :last_message]
    end

    @testset "declarative application view diffs terminal presentation" begin
        output = IOBuffer()
        capabilities = TerminalCapabilities(
            mouse=true,
            focus=true,
            bracketed_paste=true,
            terminal_title=true,
        )
        backend = AnsiBackend(
            IOBuffer(),
            output;
            capabilities,
            options=TerminalOptions(
                raw_mode=false,
                alternate_screen=false,
                hide_cursor=false,
                mouse_capture=false,
                focus_reporting=false,
                bracketed_paste=false,
            ),
            controller=NoopTerminalController(),
            size=Size(1, 12),
        )
        result = run(
            DeclarativeApplicationViewApp();
            terminal=Terminal(backend),
            input_source=runtime_source(CustomEvent(:next), CustomEvent(:quit)),
        )
        rendered = String(take!(output))
        @test result == 1
        @test occursin("\e]2;Wicked: first\e\\", rendered)
        @test occursin("\e]2;Wicked: second\e\\", rendered)
        @test occursin("\e[?1049h", rendered)
        @test occursin("\e[?1049l", rendered)
        @test occursin("\e[?2004h", rendered)
        @test occursin("\e[?2004l", rendered)
        @test occursin("\e[?1004h", rendered)
        @test occursin("\e[?1004l", rendered)
        @test occursin("\e[?1003h", rendered)
        @test occursin("\e[?1006l", rendered)
        @test occursin("\e[6 q", rendered)
        @test occursin("\e[?25l", rendered)
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

    @testset "high-throughput task replacement and cancellation" begin
        app = RuntimeCancellationRaceApp()
        source = ChannelInputSource(256)
        model = initialize(app)
        runtime = ApplicationRuntime(
            app,
            model,
            Terminal(TestBackend(1, 24)),
            source;
            config=RuntimeConfig(queue_capacity=1024),
        )

        task = run_async(runtime)
        for _ in 1:64
            post_event!(source, CustomEvent(:work))
        end
        @test timedwait(() -> model.requested == 64, 5.0) == :ok
        model.release[] = true
        @test timedwait(() -> model.completed == 1, 5.0) == :ok
        request_exit!(runtime, :done)
        @test fetch(task) == :done
        @test model.requested == 64
        @test model.completed == 1
        @test model.latest_request == 64
        @test model.failed == 0

        model = initialize(app)
        source = ChannelInputSource(128)
        runtime = ApplicationRuntime(
            app,
            model,
            Terminal(TestBackend(1, 24)),
            source;
            config=RuntimeConfig(queue_capacity=1024),
        )
        task = run_async(runtime)
        post_event!(source, CustomEvent(:work))
        @test timedwait(() -> model.requested == 1, 5.0) == :ok
        post_event!(source, CustomEvent(:cancel))
        @test timedwait(() -> isempty(runtime.commands), 5.0) == :ok
        request_exit!(runtime, :done)
        @test fetch(task) == :done
        @test model.requested == 1
        @test model.completed == 0
        @test model.failed == 0
    end

    @testset "subscription and command cleanup after shutdown" begin
        app = RuntimeShutdownStressApp()
        source = ChannelInputSource(256)
        model = initialize(app)
        runtime = ApplicationRuntime(
            app,
            model,
            Terminal(TestBackend(1, 24)),
            source;
            config=RuntimeConfig(queue_capacity=1024, resize_poll_seconds=0.5),
        )

        task = run_async(runtime)
        for _ in 1:24
            post_event!(source, CustomEvent(:work))
        end
        @test timedwait(() -> model.requested == 24, 5.0) == :ok
        post_event!(source, CustomEvent(:done))
        request_exit!(runtime, :done)
        @test fetch(task) == :done
        sleep(0.05)
        @test model.released[] == false
        model.released[] = true
        @test isempty(runtime.commands)
        @test isempty(runtime.subscription_tasks)
        @test isempty(runtime.subscription_specs)
        tick_snapshot = model.ticks
        sleep(0.05)
        @test model.ticks == tick_snapshot
        @test iszero(model.completed)
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
