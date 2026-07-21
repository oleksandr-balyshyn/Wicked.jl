using Wicked.Reactive: ReactiveRuntime,
                       Signal,
                       ReactiveNotificationError,
                       bind_signals!,
                       computed_signal,
                       dispose!,
                       reactive_effect!,
                       set_signal!,
                       signal_value,
                       signal_version,
                       signal_subscription,
                       subscribe!,
                       transaction!

@testset "Reactive transactions and lifecycle" begin
    @testset "runtime subscription adapter mapping contract" begin
        value = Signal(2)
        one = signal_subscription(:one, value; mapper=new -> (:one, new))
        two = signal_subscription(:two, value; mapper=(new, old) -> (:two, new, old))
        three = signal_subscription(
            :three,
            value;
            mapper=(new, old, source) -> (:three, new, old, source === value),
            immediate=true,
        )
        @test one isa EventSubscription
        @test two isa EventSubscription
        @test three isa EventSubscription
        @test three.revision[3]
        @test_throws ArgumentError signal_subscription(:invalid, value; mapper=() -> :invalid)
    end

    @testset "commit coalesces changes" begin
        runtime = ReactiveRuntime()
        value = Signal(1; runtime=runtime)
        notifications = Tuple{Int,Int}[]
        subscribe!(value) do new_value, old_value, _
            push!(notifications, (new_value, old_value))
        end

        result = transaction!(runtime) do
            set_signal!(value, 2)
            set_signal!(value, 3)
            :committed
        end

        @test result === :committed
        @test signal_value(value) == 3
        @test notifications == [(3, 1)]
    end

    @testset "outer rollback restores value and version" begin
        runtime = ReactiveRuntime()
        value = Signal(10; runtime=runtime)
        original_version = signal_version(value)
        notifications = Ref(0)
        subscribe!(value) do _, _, _
            notifications[] += 1
        end

        @test_throws ErrorException transaction!(runtime) do
            set_signal!(value, 20)
            set_signal!(value, 30)
            error("rollback")
        end

        @test signal_value(value) == 10
        @test signal_version(value) == original_version
        @test notifications[] == 0
    end

    @testset "nested transactions are savepoints" begin
        runtime = ReactiveRuntime()
        left = Signal(1; runtime=runtime)
        right = Signal(10; runtime=runtime)
        notifications = Pair{Symbol,Tuple{Int,Int}}[]
        subscribe!(left) do new_value, old_value, _
            push!(notifications, :left => (new_value, old_value))
        end
        subscribe!(right) do new_value, old_value, _
            push!(notifications, :right => (new_value, old_value))
        end

        transaction!(runtime) do
            set_signal!(left, 2)
            try
                transaction!(runtime) do
                    set_signal!(left, 3)
                    set_signal!(right, 30)
                    error("inner rollback")
                end
            catch error
                @test error isa ErrorException
            end
            @test signal_value(left) == 2
            @test signal_value(right) == 10
            set_signal!(right, 11)
        end

        @test signal_value(left) == 2
        @test signal_value(right) == 11
        @test Set(notifications) == Set((:left => (2, 1), :right => (11, 10)))

        @test_throws ErrorException transaction!(runtime) do
            set_signal!(left, 4)
            transaction!(runtime) do
                set_signal!(right, 40)
            end
            error("outer rollback")
        end
        @test signal_value(left) == 2
        @test signal_value(right) == 11
    end

    @testset "reentrant updates remain usable" begin
        value = Signal(0)
        notifications = Tuple{Int,Int}[]
        subscribe!(value) do new_value, old_value, source
            push!(notifications, (new_value, old_value))
            new_value == 1 && set_signal!(source, 2)
        end

        set_signal!(value, 1)

        @test signal_value(value) == 2
        @test notifications == [(1, 0), (2, 1)]
    end

    @testset "all committed notifications are attempted" begin
        runtime = ReactiveRuntime()
        left = Signal(1; runtime=runtime)
        right = Signal(2; runtime=runtime)
        subscribe!(left) do _, _, _
            error("left subscriber")
        end
        subscribe!(right) do _, _, _
            error("right subscriber")
        end

        failure = try
            transaction!(runtime) do
                set_signal!(left, 10)
                set_signal!(right, 20)
            end
            nothing
        catch error
            error
        end

        @test failure isa ReactiveNotificationError
        @test length(failure.errors) == 2
        @test signal_value(left) == 10
        @test signal_value(right) == 20
    end

    @testset "failed immediate subscription does not leak" begin
        value = Signal(1)
        calls = Ref(0)
        @test_throws ErrorException subscribe!(value; immediate=true) do _, _, _
            calls[] += 1
            error("immediate callback")
        end

        set_signal!(value, 2)
        @test calls[] == 1
    end

    @testset "computed values, effects, and bindings dispose once" begin
        runtime = ReactiveRuntime()
        source = Signal(2; runtime=runtime)
        derived = computed_signal(value -> value * 2, [source]; runtime=runtime)
        effect_runs = Ref(0)
        cleanup_runs = Ref(0)
        effect = reactive_effect!([source]) do _
            effect_runs[] += 1
            () -> (cleanup_runs[] += 1)
        end

        @test signal_value(derived) == 4
        set_signal!(source, 3)
        @test signal_value(derived) == 6
        @test effect_runs[] == 2
        @test cleanup_runs[] == 1

        dispose!(derived)
        dispose!(effect)
        dispose!(derived)
        dispose!(effect)
        set_signal!(source, 4)

        @test signal_value(derived) == 6
        @test effect_runs[] == 2
        @test cleanup_runs[] == 2

        left = Signal(1; runtime=runtime)
        right = Signal(0; runtime=runtime)
        binding = bind_signals!(left, right)
        @test signal_value(right) == 1
        dispose!(binding)
        dispose!(binding)
        set_signal!(left, 5)
        @test signal_value(right) == 1
    end
end
