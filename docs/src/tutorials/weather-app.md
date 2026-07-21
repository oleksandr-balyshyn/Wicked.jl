# Tutorial: Weather App

A small but **complete interactive TUI** — a weather dashboard built on Wicked's
managed runtime. It brings together a composite layout, several widgets, and the
`model → update → view` loop. The forecast data is mocked (no network), so the
whole thing is deterministic and runs headlessly.

The complete file is
[`examples/weather_app.jl`](https://github.com/oleksandr-balyshyn/Wicked.jl/blob/master/examples/weather_app.jl).
Run it with:

```bash
julia --project=. examples/weather_app.jl
```

## What it looks like

```text
                       Weather
                      refresh #0
╭─Cities─────────╮╭─Forecast─────────────────────────╮
│› Kyiv          ││Kyiv — Clear                      │
│  London        ││Temperature: 21°C                 │
│  Tokyo         ││           Humidity 45%           │
│  New York      ││Next 12 hours:                    │
│                ││▁▂▃▅▆▇█▇▆▄▃▂                      │
╰────────────────╯╰──────────────────────────────────╯
 ↑/↓  city   r  refresh   q  quit
```

Press `↑`/`↓` to change city, `r` to refresh, `q` to quit.

## 1. Model

The model is your application state — a plain mutable struct.

```julia
mutable struct WeatherModel
    selected::Int      # index into CITIES
    refreshed::Int     # bumped on refresh
end

struct WeatherApp <: WickedApp end

initialize(::WeatherApp) = WeatherModel(1, 0)
```

## 2. View

`app_view` is a **pure function of the model** returning a widget tree. Composite
layouts are built with `row`/`column` and `Element`. Rendering the selection
from the model (rather than from widget state) keeps the view pure.

```julia
function city_list(selected::Int)
    lines = [i == selected ? "› $(city)" : "  $(city)" for (i, city) in enumerate(CITIES)]
    return Paragraph(join(lines, "\n"))
end

function forecast_panel(city, f)
    return column(
        Element(Paragraph("$(city) — $(f.condition)")),
        Element(Paragraph("Temperature: $(f.temp_c)°C")),
        Element(Gauge(f.humidity / 100; label="Humidity $(f.humidity)%")),
        Element(Paragraph("Next 12 hours:")),
        Element(Sparkline(f.hourly));
        constraints=[Length(1), Length(1), Length(1), Length(1), Length(1)],
    )
end

function app_view(::WeatherApp, m::WeatherModel)
    city = CITIES[m.selected]; forecast = FORECASTS[city]

    body = row(
        Element(Panel(city_list(m.selected); block=Block(title="Cities"))),
        Element(Panel(forecast_panel(city, forecast); block=Block(title="Forecast")));
        constraints=[Length(18), Fill(1)],
    )

    return column(
        Element(TitleBar("Weather"; subtitle="refresh #$(m.refreshed)")),
        Element(body),
        Element(Footer([KeyHint("↑/↓", "city"), KeyHint("r", "refresh"), KeyHint("q", "quit")]));
        constraints=[Length(2), Fill(1), Length(1)],
    )
end
```

Note how widgets compose: a `Gauge` for humidity, a `Sparkline` for the hourly
temperatures, `Panel`/`Block` for framing, and a `Footer` of `KeyHint`s.

## 3. Update

`update!` mutates the model in response to a message and returns a **command**.
Here it accepts both raw `KeyEvent`s (a real terminal) and plain symbols (tests),
so the same logic drives the app and its pilot.

```julia
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
```

## 4. Run and test it

A `RuntimePilot` runs the app headlessly, so the same program is its own test:

```julia
pilot = RuntimePilot(WeatherApp(); height=12, width=54)
@assert occursin("Kyiv", plain_snapshot(pilot))

send!(pilot, :next)                       # or send!(pilot, KeyEvent(Key(:down)))
@assert occursin("London", plain_snapshot(pilot))

send!(pilot, :refresh)
@assert occursin("refresh #1", plain_snapshot(pilot))

result = send!(pilot, :quit)
@assert result.exited
```

In a real terminal you would run the same `WeatherApp` on a live backend and feed
it real key events — the model, view, and update logic do not change.

## Where to go next

- Style the panels with roles and stylesheets — see [Styling & Themes](../guide/styling.md).
- Add async refresh with a `DelayCommand` timer — see [Managed Runtime](../guide/runtime.md).
- Swap the list for the stateful [`List`](../guide/widgets.md) widget with real
  selection state.
