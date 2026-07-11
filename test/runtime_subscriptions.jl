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
