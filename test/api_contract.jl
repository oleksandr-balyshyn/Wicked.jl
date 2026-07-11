module DownstreamAPIContract

using Wicked.API
import Wicked: backend_capabilities,
               backend_size,
               present!,
               read_event!,
               render!

struct ExternalWidget
    text::String
end

module StableAPIConsumer

using Wicked.API
import Wicked.API: render!

struct StableWidget
    label::String
end

render!(buffer::Buffer, widget::StableWidget, area::Rect) =
    draw_text!(buffer, area.row, area.column, widget.label; clip=area)

end

render!(buffer::Buffer, widget::ExternalWidget, area::Rect) =
    draw_text!(buffer, area.row, area.column, widget.text; clip=area)

mutable struct ExternalBackend <: AbstractBackend
    viewport::Size
    capabilities::TerminalCapabilities
    presentations::Int
    screen::Buffer
end

ExternalBackend(height::Integer, width::Integer) = ExternalBackend(
    Size(height, width),
    TerminalCapabilities(color_level=:none, mouse=false, focus=false),
    0,
    Buffer(height, width),
)

backend_size(backend::ExternalBackend) = backend.viewport
backend_capabilities(backend::ExternalBackend) = backend.capabilities

function present!(backend::ExternalBackend, changes, completed::Buffer, cursor)
    backend.presentations += 1
    backend.screen = copy(completed)
    return nothing
end

mutable struct ExternalInputSource <: AbstractInputSource
    remaining::Int
end

function read_event!(source::ExternalInputSource)
    source.remaining > 0 || throw(EOFError())
    source.remaining -= 1
    return CustomEvent(:external)
end

struct CallableSubscriber
    values::Vector{Int}
end

(subscriber::CallableSubscriber)(new_value, old_value, signal) =
    push!(subscriber.values, new_value)

end

@testset "Public API and downstream extension contract" begin
    @testset "external widget, backend, and input source" begin
        widget = DownstreamAPIContract.ExternalWidget("external")
        backend = DownstreamAPIContract.ExternalBackend(2, 12)
        terminal = Terminal(backend)

        draw!(terminal) do frame
            render!(frame, widget, frame.area)
        end

        @test backend.presentations == 1
        @test plain_snapshot(backend.screen) == "external\n"
        @test backend_capabilities(backend).color_level == :none

        source = DownstreamAPIContract.ExternalInputSource(1)
        @test read_event!(source) == CustomEvent(:external)
        @test_throws EOFError read_event!(source)
    end

    @testset "callable functor and do-block subscriptions" begin
        signal = Signal(1)
        values = Int[]
        functor = DownstreamAPIContract.CallableSubscriber(values)
        direct = subscribe!(signal, functor)
        set_signal!(signal, 2)
        @test values == [2]
        @test unsubscribe!(direct)

        computed = computed_signal(value -> value * 2, [signal])
        observed = Int[]
        subscription = subscribe!(computed) do value, _, _
            push!(observed, value)
        end
        set_signal!(signal, 3)
        @test observed == [6]
        @test unsubscribe!(subscription)
        dispose!(computed)
    end

    @test Base.get_extension(Wicked, :WickedHTTPWebSocketsExt) === nothing

    @testset "candidate stable facade" begin
        widget = DownstreamAPIContract.StableAPIConsumer.StableWidget("stable")
        pilot = WidgetPilot(widget; height=1, width=8)
        @test plain_snapshot(pilot) == "stable"
        @test Wicked.API.Buffer === Wicked.Buffer
        @test Wicked.API.RuntimePilot === Wicked.RuntimePilot
        @test !isdefined(Wicked.API, :RemoteBackend)
    end
end
