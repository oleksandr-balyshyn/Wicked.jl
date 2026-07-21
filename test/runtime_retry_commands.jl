import Wicked: app_view, initialize, update!

mutable struct RetryCommandModel
    attempts::Int
    messages::Vector{Any}
end

struct RetryCommandApp <: WickedApp end

initialize(::RetryCommandApp) = RetryCommandModel(0, Any[])
app_view(::RetryCommandApp, model::RetryCommandModel) = Label(string(model.attempts))

function update!(::RetryCommandApp, model::RetryCommandModel, message)
    payload = message isa CommandFinished ? message.value : message
    if message === :start
        return RetryCommand(
            () -> begin
                model.attempts += 1
                model.attempts < 3 && error("transient")
                :ready
            end;
            id=:retry,
            policy=RetryPolicy(maximum_attempts=3, initial_delay=0.25, multiplier=2),
            on_success=value -> (:done, value),
            on_error=failure -> (:failed, failure),
        )
    elseif message === :exhaust
        return RetryCommand(
            () -> error("permanent");
            policy=RetryPolicy(maximum_attempts=2, initial_delay=0.1),
            on_error=failure -> (:failed, failure),
        )
    elseif message === :timeout
        return RetryCommand(
            () -> sleep(0.01);
            policy=RetryPolicy(maximum_attempts=1),
            timeout=0.001,
            on_error=failure -> (:failed, failure),
        )
    elseif message === :sequence
        return SequenceCommand(
            RetryCommand(
                () -> begin
                    model.attempts += 1
                    model.attempts == 1 && error("once")
                    :first
                end;
                policy=RetryPolicy(maximum_attempts=2, initial_delay=0.2),
                on_success=value -> (:done, value),
            ),
            MessageCommand(:after),
        )
    elseif message === :cancel_start
        return RetryCommand(
            () -> error("retrying");
            id=:cancelled_retry,
            policy=RetryPolicy(maximum_attempts=3, initial_delay=1),
        )
    elseif message === :cancel
        return CancelCommand(:cancelled_retry)
    elseif payload isa Tuple && first(payload) in (:done, :failed)
        push!(model.messages, payload)
    elseif payload === :after
        push!(model.messages, :after)
    end
    return nothing
end

@testset "retry command policies" begin
    policy = RetryPolicy(maximum_attempts=4, initial_delay=0.25, multiplier=2, maximum_delay=0.75)
    @test retry_delay(policy, 1) == 0.25
    @test retry_delay(policy, 2) == 0.5
    @test retry_delay(policy, 3) == 0.75
    @test_throws ArgumentError RetryPolicy(maximum_attempts=0)
    @test_throws ArgumentError RetryPolicy(initial_delay=-1)
    @test_throws ArgumentError RetryPolicy(multiplier=0.5)
    @test_throws ArgumentError retry_delay(policy, 0)

    command = RetryCommand(
        () -> 7;
        id=:mapped,
        policy=policy,
        timeout=2,
        on_success=value -> (:value, value),
    )
    mapped = map_command(value -> (:mapped, value), command)
    @test mapped.id == :mapped
    @test mapped.policy === policy
    @test mapped.timeout_seconds == 2
    @test mapped.on_success(7) == (:mapped, (:value, 7))

    pilot = RuntimePilot(RetryCommandApp(); height=1, width=12)
    initial = send!(pilot, :start)
    @test initial.processed_messages == 1
    @test pilot.model.attempts == 1
    @test pending_scheduled(pilot.clock) == 1

    first_retry = advance_time!(pilot, 0.25)
    @test first_retry.processed_messages == 0
    @test pilot.model.attempts == 2
    @test pending_scheduled(pilot.clock) == 1

    completed = advance_time!(pilot, 0.5)
    @test completed.processed_messages == 1
    @test pilot.model.attempts == 3
    @test pilot.model.messages == Any[(:done, :ready)]
    @test pending_scheduled(pilot.clock) == 0

    exhaust = RuntimePilot(RetryCommandApp(); height=1, width=12)
    send!(exhaust, :exhaust)
    @test pending_scheduled(exhaust.clock) == 1
    advance_time!(exhaust, 0.1)
    @test length(exhaust.model.messages) == 1
    failure = only(exhaust.model.messages)[2]
    @test failure isa RuntimeFailure
    @test failure.error isa RetryExhaustedError
    @test failure.error.attempts == 2

    sequence = RuntimePilot(RetryCommandApp(); height=1, width=12)
    send!(sequence, :sequence)
    @test isempty(sequence.model.messages)
    @test pending_scheduled(sequence.clock) == 1
    advanced = advance_time!(sequence, 0.2)
    @test advanced.processed_messages == 2
    @test sequence.model.messages == Any[(:done, :first), :after]

    cancelled = RuntimePilot(RetryCommandApp(); height=1, width=12)
    send!(cancelled, :cancel_start)
    @test pending_scheduled(cancelled.clock) == 1
    send!(cancelled, :cancel)
    @test pending_scheduled(cancelled.clock) == 0
    @test advance_time!(cancelled, 2).processed_messages == 0

    timeout = RuntimePilot(RetryCommandApp(); height=1, width=12)
    send!(timeout, :timeout)
    timeout_failure = only(timeout.model.messages)[2]
    @test timeout_failure isa RuntimeFailure
    @test timeout_failure.error isa RetryExhaustedError
    @test timeout_failure.error.error isa CommandTimeoutError
end
