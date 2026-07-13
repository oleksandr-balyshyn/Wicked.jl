using Wicked.API
import Wicked.API: app_view, initialize, update!

mutable struct RuntimeQuickstartModel
    count::Int
    status::String
end

struct RuntimeQuickstartApp <: WickedApp end

initialize(::RuntimeQuickstartApp) = RuntimeQuickstartModel(0, "ready")

function app_view(::RuntimeQuickstartApp, model::RuntimeQuickstartModel)
    return Panel(
        Paragraph("count=$(model.count)\nstatus=$(model.status)");
        title="Runtime quickstart",
    )
end

function update!(::RuntimeQuickstartApp, model::RuntimeQuickstartModel, message)
    payload = message isa CustomEvent ? message.payload : message
    if payload === :increment
        model.count += 1
        model.status = "incremented"
        return FrameCommand()
    elseif payload === :schedule
        model.status = "scheduled"
        return DelayCommand(0.25, :increment)
    elseif payload === :batch
        model.status = "batching"
        return BatchCommand(MessageCommand(:increment), MessageCommand(:increment))
    elseif payload === :quit
        return ExitCommand((count=model.count, status=model.status))
    end
    return NoCommand()
end

pilot = RuntimePilot(RuntimeQuickstartApp(); height=5, width=36)
@assert occursin("count=0", plain_snapshot(pilot))

send!(pilot, :increment)
@assert occursin("count=1", plain_snapshot(pilot))

send!(pilot, :schedule)
@assert occursin("scheduled", plain_snapshot(pilot))
advance_time!(pilot, 0.25)
@assert occursin("count=2", plain_snapshot(pilot))

send!(pilot, :batch)
@assert occursin("count=4", plain_snapshot(pilot))

result = send!(pilot, :quit)
@assert result.exited
@assert result.result == (count=4, status="incremented")

println("runtime quickstart example completed")
