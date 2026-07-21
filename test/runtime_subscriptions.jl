mutable struct SubscriptionPilotModel
    ticks::Int
    enabled::Bool
    interval::Float64
    failures::Vector{RuntimeFailure}
end

struct SubscriptionPilotApp <: WickedApp end

initialize(::SubscriptionPilotApp) = SubscriptionPilotModel(0, true, 1.0, RuntimeFailure[])
app_view(::SubscriptionPilotApp, model) = Label("ticks=$(model.ticks)")

function update!(::SubscriptionPilotApp, model::SubscriptionPilotModel, message)
    if message === :tick
        model.ticks += 1
    elseif message === :disable
        model.enabled = false
    elseif message === :faster
        model.interval = 0.25
    elseif message isa RuntimeFailure
        push!(model.failures, message)
    end
    nothing
end

function subscriptions(::SubscriptionPilotApp, model::SubscriptionPilotModel)
    model.enabled || return ()
    (IntervalSubscription(:clock, model.interval, :tick),)
end

struct FailingSubscriptionPilotApp <: WickedApp end

initialize(::FailingSubscriptionPilotApp) = RuntimeFailure[]
app_view(::FailingSubscriptionPilotApp, model) = Label("failures=$(length(model))")
update!(::FailingSubscriptionPilotApp, model, message::RuntimeFailure) = (push!(model, message); nothing)
update!(::FailingSubscriptionPilotApp, model, message) = nothing
subscriptions(::FailingSubscriptionPilotApp, model) = (
    IntervalSubscription(:failing, 0.1, () -> error("subscription failed")),
)

struct DuplicateSubscriptionPilotApp <: WickedApp end

initialize(::DuplicateSubscriptionPilotApp) = nothing
app_view(::DuplicateSubscriptionPilotApp, model) = Label("duplicate")
update!(::DuplicateSubscriptionPilotApp, model, message) = nothing
subscriptions(::DuplicateSubscriptionPilotApp, model) = (
    IntervalSubscription(:same, 1, :one),
    IntervalSubscription(:same, 2, :two),
)

mutable struct EventSubscriptionModel
    enabled::Bool
    revision::Int
    events::Vector{Any}
    failures::Vector{RuntimeFailure}
end

mutable struct EventSubscriptionApp <: WickedApp
    emitter::Base.RefValue{Any}
    registrations::Base.RefValue{Int}
    cleanups::Base.RefValue{Int}
    fail_registration::Base.RefValue{Bool}
    fail_cleanup::Base.RefValue{Bool}
end

EventSubscriptionApp() = EventSubscriptionApp(
    Ref{Any}(nothing),
    Ref(0),
    Ref(0),
    Ref(false),
    Ref(false),
)

initialize(::EventSubscriptionApp) = EventSubscriptionModel(true, 1, Any[], RuntimeFailure[])
app_view(::EventSubscriptionApp, model) = Label("events=$(length(model.events))")

function update!(::EventSubscriptionApp, model::EventSubscriptionModel, message)
    if message === :disable
        model.enabled = false
    elseif message === :replace
        model.revision += 1
    elseif message === :quit
        return ExitCommand(copy(model.events))
    elseif message isa RuntimeFailure
        push!(model.failures, message)
    elseif message !== :noop
        push!(model.events, message)
    end
    nothing
end

function subscriptions(app::EventSubscriptionApp, model::EventSubscriptionModel)
    model.enabled || return ()
    register = emit -> begin
        app.registrations[] += 1
        app.fail_registration[] && error("registration failed")
        app.emitter[] = emit
        () -> begin
            app.cleanups[] += 1
            app.fail_cleanup[] && error("cleanup failed")
        end
    end
    (EventSubscription(:events, register; revision=model.revision),)
end

mutable struct SignalSubscriptionModel
    enabled::Bool
    values::Vector{Int}
end

struct SignalSubscriptionApp <: WickedApp
    value::Signal
end

initialize(::SignalSubscriptionApp) = SignalSubscriptionModel(true, Int[])
app_view(::SignalSubscriptionApp, model) = Label("values=$(length(model.values))")

function update!(::SignalSubscriptionApp, model::SignalSubscriptionModel, message)
    if message === :disable
        model.enabled = false
    elseif message isa Int
        push!(model.values, message)
    end
    nothing
end


subscriptions(app::SignalSubscriptionApp, model::SignalSubscriptionModel) =
    model.enabled ? (signal_subscription(:value, app.value; immediate=true),) : ()

mutable struct ChannelSubscriptionModel
    enabled::Bool
    revision::Int
    values::Vector{Int}
    failures::Vector{RuntimeFailure}
end

struct ChannelSubscriptionApp <: WickedApp
    source::Channel{Int}
    fail_mapping::Base.RefValue{Bool}
    close_on_cleanup::Bool
end

initialize(::ChannelSubscriptionApp) =
    ChannelSubscriptionModel(true, 1, Int[], RuntimeFailure[])
app_view(::ChannelSubscriptionApp, model) = Label("channel=$(length(model.values))")

function update!(::ChannelSubscriptionApp, model::ChannelSubscriptionModel, message)
    if message === :disable
        model.enabled = false
    elseif message === :replace
        model.revision += 1
    elseif message isa Tuple && first(message) === :channel
        push!(model.values, last(message))
    elseif message isa RuntimeFailure
        push!(model.failures, message)
    end
    nothing
end

function subscriptions(app::ChannelSubscriptionApp, model::ChannelSubscriptionModel)
    model.enabled || return ()
    mapper = value -> begin
        app.fail_mapping[] && error("channel mapping failed")
        (:channel, value * 2)
    end
    (
        channel_subscription(
            :channel,
            app.source;
            mapper,
            poll_interval=0.001,
            close_on_cleanup=app.close_on_cleanup,
            revision=model.revision,
        ),
    )
end

mutable struct FileSubscriptionModel
    enabled::Bool
    revision::Int
    events::Vector{FileWatchEvent}
    failures::Vector{RuntimeFailure}
end

struct FileSubscriptionApp <: WickedApp
    path::String
    fail_mapping::Base.RefValue{Bool}
end

initialize(::FileSubscriptionApp) =
    FileSubscriptionModel(true, 1, FileWatchEvent[], RuntimeFailure[])
app_view(::FileSubscriptionApp, model) = Label("files=$(length(model.events))")

function update!(::FileSubscriptionApp, model::FileSubscriptionModel, message)
    if message === :disable
        model.enabled = false
    elseif message === :replace
        model.revision += 1
    elseif message isa FileWatchEvent
        push!(model.events, message)
    elseif message isa RuntimeFailure
        push!(model.failures, message)
    end
    nothing
end

function subscriptions(app::FileSubscriptionApp, model::FileSubscriptionModel)
    model.enabled || return ()
    mapper = (path, event) -> begin
        app.fail_mapping[] && error("file mapping failed")
        FileWatchEvent(path, event.renamed, event.changed)
    end
    (
        file_subscription(
            :file,
            app.path;
            mapper,
            wait_timeout=0.01,
            revision=model.revision,
        ),
    )
end

mutable struct ProcessSubscriptionModel
    enabled::Bool
    revision::Int
    chunks::Vector{ProcessStreamChunk}
    exits::Vector{ProcessStreamExit}
    failures::Vector{RuntimeFailure}
end

struct ProcessSubscriptionApp <: WickedApp
    command::Cmd
    input::Any
    maximum_chunk_bytes::Int
end

initialize(::ProcessSubscriptionApp) = ProcessSubscriptionModel(
    true,
    1,
    ProcessStreamChunk[],
    ProcessStreamExit[],
    RuntimeFailure[],
)
app_view(::ProcessSubscriptionApp, model) = Label("process=$(length(model.chunks))")

function update!(::ProcessSubscriptionApp, model::ProcessSubscriptionModel, message)
    if message === :disable
        model.enabled = false
    elseif message === :replace
        model.revision += 1
    elseif message isa ProcessStreamChunk
        push!(model.chunks, message)
    elseif message isa ProcessStreamExit
        push!(model.exits, message)
    elseif message isa RuntimeFailure
        push!(model.failures, message)
    end
    nothing
end

function subscriptions(app::ProcessSubscriptionApp, model::ProcessSubscriptionModel)
    model.enabled || return ()
    (
        process_subscription(
            :process,
            app.command;
            input=app.input,
            maximum_chunk_bytes=app.maximum_chunk_bytes,
            revision=model.revision,
        ),
    )
end

@testset "Managed interval subscriptions" begin
    @testset "virtual interval and removal" begin
        pilot = RuntimePilot(SubscriptionPilotApp(); height=1, width=12)
        @test length(pilot.subscription_tokens) == 1
        @test pending_scheduled(pilot.clock) == 1

        early = advance_time!(pilot, 0.5)
        @test early.processed_messages == 0
        @test pilot.model.ticks == 0
        due = advance_time!(pilot, 0.5)
        @test due.processed_messages == 1
        @test pilot.model.ticks == 1
        @test pending_scheduled(pilot.clock) == 1

        send!(pilot, :disable)
        @test isempty(pilot.subscription_tokens)
        @test isempty(pilot.subscription_specs)
        @test pending_scheduled(pilot.clock) == 0
        advance_time!(pilot, 2.0)
        @test pilot.model.ticks == 1
    end

    @testset "same ID replacement" begin
        pilot = RuntimePilot(SubscriptionPilotApp(); height=1, width=12)
        original = pilot.subscription_tokens[:clock]
        send!(pilot, :faster)
        replacement = pilot.subscription_tokens[:clock]
        @test replacement != original
        @test pilot.subscription_specs[:clock].interval_seconds == 0.25
        @test pending_scheduled(pilot.clock) == 1
        advance_time!(pilot, 0.25)
        @test pilot.model.ticks == 1
    end

    @testset "callback failure delivery" begin
        pilot = RuntimePilot(FailingSubscriptionPilotApp(); height=1, width=16)
        result = advance_time!(pilot, 0.1)
        @test result.processed_messages == 1
        failure = only(pilot.model)
        @test failure.phase == :subscription
        @test failure.id == :failing
        @test failure.error isa ErrorException
        @test pending_scheduled(pilot.clock) == 1
    end

    @testset "duplicate IDs remain invalid" begin
        @test_throws ArgumentError RuntimePilot(DuplicateSubscriptionPilotApp())
    end
end

@testset "Managed callback event subscriptions" begin
    @testset "pilot registration, stable identity, replacement, and removal" begin
        app = EventSubscriptionApp()
        pilot = RuntimePilot(app; height=1, width=20)
        @test app.registrations[] == 1
        first_emit = app.emitter[]
        @test first_emit(:first)
        delivered = send!(pilot, :noop)
        @test delivered.processed_messages == 2
        @test pilot.model.events == [:first]
        @test app.registrations[] == 1

        send!(pilot, :replace)
        @test app.cleanups[] == 1
        @test app.registrations[] == 2
        @test !first_emit(:stale)
        @test app.emitter[](:second)
        send!(pilot, :noop)
        @test pilot.model.events == [:first, :second]

        send!(pilot, :disable)
        @test app.cleanups[] == 2
        @test isempty(pilot.subscription_tokens)
        @test !app.emitter[](:late)
    end

    @testset "pilot registration and cleanup failures become messages" begin
        registration_app = EventSubscriptionApp()
        registration_app.fail_registration[] = true
        registration_pilot = RuntimePilot(registration_app; height=1, width=20)
        send!(registration_pilot, :noop)
        @test only(registration_pilot.model.failures).phase == :subscription_registration

        cleanup_app = EventSubscriptionApp()
        cleanup_pilot = RuntimePilot(cleanup_app; height=1, width=20)
        cleanup_app.fail_cleanup[] = true
        send!(cleanup_pilot, :disable)
        send!(cleanup_pilot, :noop)
        @test only(cleanup_pilot.model.failures).phase == :subscription_cleanup
    end

    @testset "production runtime emission and shutdown cleanup" begin
        app = EventSubscriptionApp()
        model = initialize(app)
        runtime = ApplicationRuntime(
            app,
            model,
            Terminal(TestBackend(1, 20)),
            ChannelInputSource(),
        )
        task = run_async(runtime)
        @test timedwait(() -> app.emitter[] !== nothing, 5.0) == :ok
        @test app.emitter[](:live)
        @test timedwait(() -> model.events == [:live], 5.0) == :ok
        request_exit!(runtime, copy(model.events))
        @test fetch(task) == [:live]
        @test app.cleanups[] == 1
        @test !app.emitter[](:after_shutdown)
    end
end

@testset "Reactive signal subscription adapter" begin
    signal = Signal(0)
    pilot = RuntimePilot(SignalSubscriptionApp(signal); height=1, width=20)
    @test length(signal.subscribers) == 1

    initial = send!(pilot, :noop)
    @test initial.processed_messages == 2
    @test pilot.model.values == [0]
    @test length(signal.subscribers) == 1

    set_signal!(signal, 1)
    changed = send!(pilot, :noop)
    @test changed.processed_messages == 2
    @test pilot.model.values == [0, 1]
    @test length(signal.subscribers) == 1

    send!(pilot, :disable)
    @test isempty(signal.subscribers)
    set_signal!(signal, 2)
    send!(pilot, :noop)
    @test pilot.model.values == [0, 1]
end

@testset "Channel subscription adapter" begin
    @testset "delivery, replacement, and cooperative removal" begin
        source = Channel{Int}(4)
        pilot = RuntimePilot(ChannelSubscriptionApp(source, Ref(false), false); height=1, width=20)
        put!(source, 1)
        @test timedwait(() -> !isempty(pilot.queue), 2.0) == :ok
        send!(pilot, :noop)
        @test pilot.model.values == [2]

        send!(pilot, :replace)
        sleep(0.01)
        put!(source, 2)
        @test timedwait(() -> !isempty(pilot.queue), 2.0) == :ok
        send!(pilot, :noop)
        @test pilot.model.values == [2, 4]

        send!(pilot, :disable)
        sleep(0.01)
        put!(source, 3)
        sleep(0.01)
        send!(pilot, :noop)
        @test pilot.model.values == [2, 4]
        @test isopen(source)
        close(source)
    end

    @testset "owned channel cleanup and mapped failures" begin
        owned = Channel{Int}(1)
        owner_pilot = RuntimePilot(ChannelSubscriptionApp(owned, Ref(false), true); height=1, width=20)
        send!(owner_pilot, :disable)
        @test !isopen(owned)

        failing = Channel{Int}(1)
        failure_pilot = RuntimePilot(ChannelSubscriptionApp(failing, Ref(true), false); height=1, width=20)
        put!(failing, 1)
        @test timedwait(() -> !isempty(failure_pilot.queue), 2.0) == :ok
        send!(failure_pilot, :noop)
        @test only(failure_pilot.model.failures).phase == :subscription
        @test failure_pilot.model.failures[1].id == :channel
        close(failing)
    end

    @test_throws ArgumentError channel_subscription(:bad, Channel{Int}(1); poll_interval=0)
end

@testset "File subscription adapter" begin
    @testset "change delivery, replacement, and cooperative removal" begin
        mktemp() do path, stream
            close(stream)
            pilot = RuntimePilot(FileSubscriptionApp(path, Ref(false)); height=1, width=20)
            sleep(0.03)
            open(path, "a") do output
                write(output, "one")
            end
            @test timedwait(() -> !isempty(pilot.queue), 2.0) == :ok
            send!(pilot, :noop)
            @test !isempty(pilot.model.events)
            @test all(event -> event.path == path, pilot.model.events)
            @test any(event -> event.changed || event.renamed, pilot.model.events)

            send!(pilot, :replace)
            sleep(0.03)
            before = length(pilot.model.events)
            open(path, "a") do output
                write(output, "two")
            end
            @test timedwait(() -> !isempty(pilot.queue), 2.0) == :ok
            send!(pilot, :noop)
            @test length(pilot.model.events) > before

            send!(pilot, :disable)
            sleep(0.03)
            retained = length(pilot.model.events)
            open(path, "a") do output
                write(output, "three")
            end
            sleep(0.05)
            send!(pilot, :noop)
            @test length(pilot.model.events) == retained
        end
    end

    @testset "mapping failures become runtime messages" begin
        mktemp() do path, stream
            close(stream)
            pilot = RuntimePilot(FileSubscriptionApp(path, Ref(true)); height=1, width=20)
            sleep(0.03)
            open(path, "a") do output
                write(output, "fail")
            end
            @test timedwait(() -> !isempty(pilot.queue), 2.0) == :ok
            send!(pilot, :noop)
            @test only(pilot.model.failures).phase == :subscription
            @test pilot.model.failures[1].id == :file
            send!(pilot, :disable)
        end
    end

    @test_throws ArgumentError file_subscription(:empty, "")
    @test_throws ArgumentError file_subscription(:timeout, "missing"; wait_timeout=0)
end

@testset "Process stream subscription adapter" begin
    @testset "bounded stdout, stderr, exit, and revision restart" begin
        command = `$(Base.julia_cmd()) --startup-file=no -e "write(stdout, read(stdin)); write(stdout, \"abcdefghij\"); flush(stdout); write(stderr, \"ERR\"); flush(stderr); exit(7)"`
        pilot = RuntimePilot(
            ProcessSubscriptionApp(command, "IN", 4);
            height=1,
            width=24,
        )
        @test timedwait(
            () -> any(message -> message isa ProcessStreamExit, pilot.queue),
            10.0,
        ) == :ok
        send!(pilot, :noop)
        @test isempty(pilot.model.failures)
        @test length(pilot.model.exits) == 1
        @test only(pilot.model.exits).exit_code == 7
        @test only(pilot.model.exits).command == command
        @test all(chunk -> 1 <= length(chunk.bytes) <= 4, pilot.model.chunks)
        stdout = reduce(
            vcat,
            (chunk.bytes for chunk in pilot.model.chunks if chunk.stream == :stdout);
            init=UInt8[],
        )
        stderr = reduce(
            vcat,
            (chunk.bytes for chunk in pilot.model.chunks if chunk.stream == :stderr);
            init=UInt8[],
        )
        @test String(stdout) == "INabcdefghij"
        @test String(stderr) == "ERR"
        @test all(chunk -> chunk.id == :process, pilot.model.chunks)

        send!(pilot, :replace)
        @test timedwait(
            () -> any(message -> message isa ProcessStreamExit, pilot.queue),
            10.0,
        ) == :ok
        send!(pilot, :noop)
        @test length(pilot.model.exits) == 2
        send!(pilot, :disable)
    end

    @testset "cleanup terminates a running child without exit emission" begin
        command = `$(Base.julia_cmd()) --startup-file=no -e "print(\"ready\"); flush(stdout); sleep(10)"`
        pilot = RuntimePilot(
            ProcessSubscriptionApp(command, nothing, 32);
            height=1,
            width=24,
        )
        @test timedwait(
            () -> any(message -> message isa ProcessStreamChunk, pilot.queue),
            10.0,
        ) == :ok
        elapsed = @elapsed send!(pilot, :disable)
        @test elapsed < 1.0
        sleep(0.1)
        send!(pilot, :noop)
        @test isempty(pilot.model.exits)
    end

    @testset "launch failures become runtime messages" begin
        command = Cmd(["wicked-command-that-does-not-exist"])
        pilot = RuntimePilot(
            ProcessSubscriptionApp(command, nothing, 32);
            height=1,
            width=24,
        )
        @test timedwait(
            () -> any(message -> message isa RuntimeFailure, pilot.queue),
            5.0,
        ) == :ok
        send!(pilot, :noop)
        @test only(pilot.model.failures).phase == :subscription
        @test pilot.model.failures[1].id == :process
        send!(pilot, :disable)
    end

    @test_throws ArgumentError process_subscription(:bad, `echo`; maximum_chunk_bytes=0)
end
