@testset "Managed runtime resize delivery" begin
    @testset "single deterministic poll" begin
        app = RuntimeCounterApp()
        backend = TestBackend(2, 4)
        runtime = ApplicationRuntime(
            app,
            initialize(app),
            Terminal(backend),
            ChannelInputSource();
            config=RuntimeConfig(resize_poll_seconds=nothing),
        )
        runtime.running = true

        @test !poll_terminal_resize!(runtime)
        resize_backend!(backend, 5, 9)
        @test poll_terminal_resize!(runtime)
        event = take!(runtime.messages)
        @test event == ResizeEvent(Size(5, 9))
        @test runtime.terminal_size == Size(5, 9)
        @test !poll_terminal_resize!(runtime)

        request_exit!(runtime)
        @test !poll_terminal_resize!(runtime)
    end

    @testset "configuration" begin
        @test RuntimeConfig().resize_poll_seconds == 0.1
        @test RuntimeConfig(resize_poll_seconds=nothing).resize_poll_seconds === nothing
        @test_throws ArgumentError RuntimeConfig(resize_poll_seconds=0)
        @test_throws ArgumentError RuntimeConfig(resize_poll_seconds=-1)
        @test_throws ArgumentError RuntimeConfig(resize_poll_seconds=Inf)
    end

    @testset "runtime pilot resize message" begin
        pilot = RuntimePilot(TestingPilotApp(); height=1, width=10)
        previous_count = length(pilot.processed_messages)
        result = resize_terminal!(pilot, 2, 12)
        @test result.accepted
        @test result.processed_messages == 1
        @test last(pilot.processed_messages) == ResizeEvent(Size(2, 12))
        @test length(pilot.processed_messages) == previous_count + 1
        @test size(pilot.backend.screen) == (2, 12)
    end
end
