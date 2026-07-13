using Wicked.API

buffer = Buffer(22, 80)

render!(buffer, TitleBar("Visualization quickstart"; subtitle="charts, gauges, and drawing"), Rect(1, 1, 2, 80))

visual_dispatcher = SemanticDispatcher()

gauge = Gauge(0.75; label="Upload")
register_gauge_semantic_handlers!(visual_dispatcher, :gauge, gauge)
render!(buffer, gauge, Rect(3, 1, 3, 28))
line_gauge = LineGauge(0.25)
register_line_gauge_semantic_handlers!(visual_dispatcher, :line_gauge, line_gauge)
render!(buffer, line_gauge, Rect(6, 1, 1, 28))
meter = Meter(3; minimum=0, maximum=4, label="Capacity", width=24, height=2)
register_meter_semantic_handlers!(visual_dispatcher, :meter, meter)
render!(buffer, meter, Rect(7, 1, 2, 28))
stepper = Stepper(["Queued", "Running", "Done"])
stepper_state = StepperState(["Queued" => :queued, "Running" => :running, "Done" => :done])
next_step!(stepper_state)
stepper_dispatcher = SemanticDispatcher()
register_stepper_semantic_handlers!(stepper_dispatcher, :stepper, stepper_state)
render!(buffer, stepper, Rect(10, 1, 1, 28), stepper_state)
timeline = Timeline([
    TimelineItem("Queued", :queued),
    TimelineItem("Running", :running; status=TimelineActive),
]; width=28, height=2)
timeline_state = state_for(timeline)
register_timeline_semantic_handlers!(stepper_dispatcher, :timeline, timeline_state)
render!(buffer, timeline, Rect(16, 1, 2, 28), timeline_state)
sparkline = Sparkline([1.0, 2.0, 3.0, 2.0, 4.0])
register_sparkline_semantic_handlers!(visual_dispatcher, :sparkline, sparkline)
render!(buffer, sparkline, Rect(9, 1, 1, 28))

# Family tokens: ImageView, Timeline

bar_chart = BarChart(["Build" => 3.0, "Test" => 2.0, "Release" => 1.0])
register_bar_chart_semantic_handlers!(visual_dispatcher, :bar_chart, bar_chart)
render!(
    buffer,
    bar_chart,
    Rect(3, 32, 5, 20),
)

chart = Chart([ChartDataset([(0.0, 0.0), (0.5, 0.8), (1.0, 1.0)])])
register_chart_semantic_handlers!(visual_dispatcher, :chart, chart)
render!(
    buffer,
    chart,
    Rect(9, 32, 5, 20),
)

plot = Plot([(0.0, 0.0), (1.0, 1.0)]; width=20, height=5)
register_plot_semantic_handlers!(visual_dispatcher, :plot, plot)
render!(buffer, plot, Rect(15, 32, 5, 20))

histogram = Histogram([1.0, 2.0, 2.5, 3.0, 4.0]; bins=3)
register_histogram_semantic_handlers!(visual_dispatcher, :histogram, histogram)
render!(buffer, histogram, Rect(3, 56, 5, 20))
heatmap = Heatmap([1.0 2.0; 3.0 4.0])
register_heatmap_semantic_handlers!(visual_dispatcher, :heatmap, heatmap)
render!(buffer, heatmap, Rect(9, 56, 2, 12))
render!(buffer, Calendar(2026, 7), Rect(12, 56, 5, 20))
canvas = Canvas(context -> canvas_point!(context, 0.5, 0.5))
register_canvas_semantic_handlers!(visual_dispatcher, :canvas, canvas)
render!(buffer, canvas, Rect(18, 56, 1, 12))
digits = Digits(42)
register_digits_semantic_handlers!(visual_dispatcher, :digits, digits)
render!(buffer, digits, Rect(11, 1, 5, 28))

snapshot = plain_snapshot(buffer)
@assert occursin("Visualization quickstart", snapshot)
@assert occursin("Upload", snapshot)
@assert occursin("Capacity", snapshot)
@assert occursin("Running", snapshot)
@assert occursin("Queued", snapshot)
@assert occursin("Build", snapshot)
@assert occursin("Test", snapshot)
@assert occursin("Release", snapshot)
visual_tree = ToolkitTree(Element(digits; id=:digits, key=:digits))
visual_pilot = SemanticPilot(toolkit_semantic_tree(visual_tree); dispatcher=visual_dispatcher)
@assert perform_semantic_action!(visual_pilot, "digits", FocusSemanticAction).handled

println("visualization quickstart example completed")
