# Weather App — a small but complete interactive TUI.
#
# This is a full application built on Wicked's managed runtime: a model holds
# the state, `update!` changes it in response to messages, and `app_view` renders
# it. The forecast data is mocked (no network) so the example is deterministic
# and runs headlessly in CI.
#
# It shows off: a composite layout (row/column), a bordered panel, a selection
# list, a humidity gauge, a temperature sparkline, a title bar, a footer of
# keybindings, and the model → update → view loop driven by a pilot.
#
# Run it with:  julia --project=. examples/weather_app.jl

using Wicked.API
import Wicked.API: app_view, initialize, update!

# ---------------------------------------------------------------------------
# Mock data
# ---------------------------------------------------------------------------

struct Forecast
    condition::String
    temp_c::Int
    humidity::Int          # 0..100
    hourly::Vector{Int}    # next 12 hours, for the sparkline
end

const CITIES = ["Kyiv", "London", "Tokyo", "New York"]

const FORECASTS = Dict(
    "Kyiv"     => Forecast("Clear",  21, 45, [16, 17, 18, 20, 21, 22, 23, 22, 21, 19, 18, 17]),
    "London"   => Forecast("Cloudy", 15, 72, [12, 13, 13, 14, 15, 16, 16, 15, 14, 13, 12, 12]),
    "Tokyo"    => Forecast("Rain",   24, 88, [22, 22, 23, 24, 25, 25, 24, 24, 23, 23, 22, 22]),
    "New York" => Forecast("Windy",  18, 55, [14, 15, 16, 17, 18, 19, 19, 18, 17, 16, 15, 15]),
)

# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------

mutable struct WeatherModel
    selected::Int          # index into CITIES
    refreshed::Int         # bumped on refresh, to show state changing
end

struct WeatherApp <: WickedApp end

initialize(::WeatherApp) = WeatherModel(1, 0)

# ---------------------------------------------------------------------------
# View
# ---------------------------------------------------------------------------

# The city list, with a marker on the current selection. Rendering the selection
# from the model keeps the view a pure function of state.
function city_list(selected::Int)
    lines = [i == selected ? "› $(city)" : "  $(city)" for (i, city) in enumerate(CITIES)]
    return Paragraph(join(lines, "\n"))
end

function forecast_panel(city::String, f::Forecast)
    return column(
        Element(Paragraph("$(city) — $(f.condition)")),
        Element(Paragraph("Temperature: $(f.temp_c)°C")),
        Element(Gauge(f.humidity / 100; label="Humidity $(f.humidity)%")),
        Element(Paragraph("Next 12 hours:")),
        Element(Sparkline(f.hourly));
        constraints=[Length(1), Length(1), Length(1), Length(1), Length(1)],
        gap=0,
    )
end

function app_view(::WeatherApp, m::WeatherModel)
    city = CITIES[m.selected]
    forecast = FORECASTS[city]

    body = row(
        Element(Panel(city_list(m.selected); block=Block(title="Cities"))),
        Element(Panel(forecast_panel(city, forecast); block=Block(title="Forecast")));
        constraints=[Length(18), Fill(1)],
        gap=0,
    )

    footer = Footer([
        KeyHint("↑/↓", "city"),
        KeyHint("r", "refresh"),
        KeyHint("q", "quit"),
    ])

    return column(
        Element(TitleBar("Weather"; subtitle="refresh #$(m.refreshed)")),
        Element(body),
        Element(footer);
        constraints=[Length(2), Fill(1), Length(1)],
        gap=0,
    )
end

# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

# Accept both raw key events (a real terminal) and plain symbols (tests / other
# commands), so the same logic drives the app and its pilot.
function update!(::WeatherApp, m::WeatherModel, message)
    action = if message isa KeyEvent
        code = message.key.code
        code === :down ? :next :
        code === :up ? :prev :
        (code === :character && message.key.text == "r") ? :refresh :
        (code === :character && message.key.text == "q") ? :quit : :ignore
    else
        message
    end

    if action === :next
        m.selected = m.selected == length(CITIES) ? 1 : m.selected + 1
        return FrameCommand()
    elseif action === :prev
        m.selected = m.selected == 1 ? length(CITIES) : m.selected - 1
        return FrameCommand()
    elseif action === :refresh
        m.refreshed += 1
        return FrameCommand()
    elseif action === :quit
        return ExitCommand(CITIES[m.selected])
    end
    return NoCommand()
end

# ---------------------------------------------------------------------------
# Drive it headlessly with a pilot (a real terminal loop would replace this).
# ---------------------------------------------------------------------------

pilot = RuntimePilot(WeatherApp(); height=12, width=54)
println(plain_snapshot(pilot))

@assert occursin("Weather", plain_snapshot(pilot))
@assert occursin("Kyiv", plain_snapshot(pilot))
@assert occursin("Clear", plain_snapshot(pilot))
@assert occursin("quit", plain_snapshot(pilot))

# Move to the next city (arrow-down would do the same in a terminal).
send!(pilot, :next)
@assert occursin("London", plain_snapshot(pilot))
@assert occursin("Cloudy", plain_snapshot(pilot))

# Refresh bumps the counter in the title bar.
send!(pilot, :refresh)
@assert occursin("refresh #1", plain_snapshot(pilot))

# Raw key events work too.
send!(pilot, KeyEvent(Key(:down)))
@assert occursin("Tokyo", plain_snapshot(pilot))

result = send!(pilot, :quit)
@assert result.exited
@assert result.result == "Tokyo"

println("\nweather app example completed")
