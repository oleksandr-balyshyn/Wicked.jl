#!/usr/bin/env julia

using Wicked.API
using Dates
using Printf
using TOML

struct WickedBenchmark
    name::String
    group::String
    operation::Function
end

struct WickedBenchmarkResult
    name::String
    group::String
    median_seconds::Float64
    minimum_seconds::Float64
    median_bytes::Int
    maximum_bytes::Int
    samples::Int
    checksum::UInt64
end

function benchmark_result(case::WickedBenchmark; samples::Int, warmups::Int)
    for _ in 1:warmups
        case.operation()
    end
    GC.gc()
    times = Float64[]
    bytes = Int[]
    checksum = UInt64(0)
    for _ in 1:samples
        measurement = @timed case.operation()
        push!(times, measurement.time)
        push!(bytes, measurement.bytes)
        checksum = hash(measurement.value, checksum)
    end
    sort!(times)
    sort!(bytes)
    middle = cld(samples, 2)
    return WickedBenchmarkResult(
        case.name,
        case.group,
        times[middle],
        first(times),
        bytes[middle],
        last(bytes),
        samples,
        checksum,
    )
end

function buffer_cases()
    height, width = 40, 120
    previous = Buffer(height, width)
    sparse = copy(previous)
    sparse[2, 2] = Cell("x"; style=Style(foreground=AnsiColor(2)))
    sparse[height - 1, width - 1] = Cell("界"; style=Style(modifiers=BOLD))
    full = Buffer(height, width; cell=Cell("x"; style=Style(foreground=AnsiColor(4))))
    return WickedBenchmark[
        WickedBenchmark("buffer_diff_sparse", "buffer", () -> length(diff_buffers(previous, sparse))),
        WickedBenchmark("buffer_diff_full", "buffer", () -> length(diff_buffers(previous, full))),
    ]
end

function unicode_cases()
    text = repeat("Julia 界 e\u0301 👩‍💻 ", 2_000)
    paragraph_source = join(
        ("row $index alpha βeta verylong界word and more words" for index in 1:500),
        '\n',
    )
    paragraph = Paragraph(paragraph_source)
    paragraph_buffer = Buffer(500, 40)
    return WickedBenchmark[
        WickedBenchmark("unicode_width_large", "text", () -> text_width(text)),
        WickedBenchmark("paragraph_wrap_500_lines", "text", function ()
            render!(paragraph_buffer, paragraph, paragraph_buffer.area)
            paragraph_buffer[500, 1].grapheme
        end),
    ]
end

function runtime_cases()
    backend = TestBackend(24, 80)
    terminal = Terminal(backend)
    button = Button("Save")
    button_state = ButtonState(focused=true)
    enter = KeyEvent(Key(:enter))
    disabled_diagnostics = DiagnosticsHub(enabled=false)
    enabled_diagnostics = DiagnosticsHub(enabled=true, trace_capacity=1_024)
    services = ApplicationServices(clock=() -> UInt64(0))

    return WickedBenchmark[
        WickedBenchmark("terminal_draw_idle", "runtime", function ()
            draw!(terminal) do _
                nothing
            end
        end),
        WickedBenchmark("input_button_enter", "runtime", function ()
            button_state.pressed = false
            handle!(button_state, button, enter)
            button_state.pressed
        end),
        WickedBenchmark("diagnostics_disabled_input_1000", "diagnostics", function ()
            for _ in 1:1_000
                record_input!(disabled_diagnostics, enter)
            end
            disabled_diagnostics.metrics.input_events_total
        end),
        WickedBenchmark("diagnostics_enabled_input_1000", "diagnostics", function ()
            for _ in 1:1_000
                record_input!(enabled_diagnostics, enter)
            end
            enabled_diagnostics.metrics.input_events_total
        end),
        WickedBenchmark("application_services_idle_pulse", "services", function ()
            pulse = pulse_services!(services; now_ns=UInt64(0))
            length(pulse.render_reasons)
        end),
    ]
end

function service_scaling_cases()
    actions = ActionRegistry()
    for index in 1:256
        register_action!(
            actions,
            Action(
                Symbol("action_$index"),
                "Action $index",
                _ -> index;
                bindings=[ActionBinding(:enter; priority=index)],
                priority=index,
            ),
        )
    end
    action_event = KeyEvent(Key(:enter))

    animations = AnimationManager(clock=() -> UInt64(0))
    animation_spec = AnimationSpec(
        AnimationTrack(0.0, 1.0);
        duration=1.0,
        iterations=nothing,
    )
    for _ in 1:256
        animate!(animations, animation_spec; now_ns=UInt64(0))
    end

    routed_elements = [
        Element(
            Button("Action $index");
            key=Symbol("action_$index"),
            focusable=true,
        ) for index in 1:128
    ]
    routing_pilot = ToolkitPilot(column(routed_elements...); height=24, width=80)
    focus_element!(routing_pilot, :action_1)
    traversal_focus = FocusRegistry()
    for index in 1:128
        register_focus!(
            traversal_focus,
            Symbol("focus_$index"),
            Rect(1, index, 1, 1);
            tab_index=mod1(index, 7),
        )
    end
    focus_first!(traversal_focus)

    return WickedBenchmark[
        WickedBenchmark("action_resolution_256_bindings", "actions", function ()
            resolve_action_binding(actions, action_event)
        end),
        WickedBenchmark("animation_tick_256_tracks", "animations", function ()
            length(tick_animations!(animations; now_ns=UInt64(500_000_000)))
        end),
        WickedBenchmark("toolkit_route_tab_128_elements", "events", function ()
            key!(routing_pilot, :tab)
        end),
        WickedBenchmark("focus_traversal_128_mixed_indices", "events", function ()
            focus_next!(traversal_focus)
        end),
    ]
end

function layout_cases()
    rows = Constraint[Fill(1) for _ in 1:64]
    columns = Constraint[Fill(1) for _ in 1:64]
    grid_layout = GridLayout(rows, columns; row_gap=1, column_gap=1)
    grid_area = Rect(1, 1, 512, 256)

    nested = Element(Label("leaf"); key=:leaf)
    for depth in 1:128
        nested = column(nested; key=Symbol("depth_$depth"), constraints=[Fill(1)])
    end
    nested_tree = ToolkitTree(nested)
    nested_frame = Frame(Buffer(128, 80))
    return WickedBenchmark[
        WickedBenchmark("layout_grid_4096_cells", "layout", () -> length(resolve(grid_layout, grid_area))),
        WickedBenchmark("layout_deep_flex_128", "layout", function ()
            render_toolkit!(nested_frame, nested_tree)
            length(nested_tree.state.instances)
        end),
    ]
end

function style_cases()
    stylesheet = Stylesheet()
    classes = Symbol[Symbol("class_$index") for index in 1:16]
    for index in 1:512
        add_rule!(
            stylesheet,
            Selector(
                widget_type=:Button,
                classes=[classes[mod1(index, length(classes))]],
                states=index % 3 == 0 ? [:focus] : Symbol[],
            ),
            StylePatch(
                foreground=IndexedColor(index % 256),
                add_modifiers=index % 2 == 0 ? BOLD : Modifiers(),
            ),
        )
    end
    engine = StyleEngine(stylesheets=[stylesheet])
    context = StyleContext(Button, :target, Set(classes), Set([:focus]), Set{Symbol}())
    large_source = join(
        ("Button.class_$(mod1(index, 16)):focus { color: indexed($(index % 256)); }" for index in 1:512),
        '\n',
    )
    return WickedBenchmark[
        WickedBenchmark("style_cascade_512_rules", "styles", () -> computed_style(engine, context).foreground.value),
        WickedBenchmark("stylesheet_parse_512_rules", "styles", () -> length(parse_stylesheet(large_source).rules)),
    ]
end

function toolkit_cases()
    children = [Element(Label("row $index"); key=index, id=Symbol("row_$index")) for index in 1:256]
    stable_root = column(children...)
    churn_root = column(reverse(children)...)
    tree = ToolkitTree(stable_root)
    frame = Frame(Buffer(256, 80))
    render_toolkit!(frame, tree)
    toggle = Ref(false)
    return WickedBenchmark[
        WickedBenchmark("toolkit_reconcile_stable_256", "toolkit", function ()
            tree.root = stable_root
            render_toolkit!(frame, tree)
            length(tree.state.instances)
        end),
        WickedBenchmark("toolkit_reconcile_move_256", "toolkit", function ()
            toggle[] = !toggle[]
            tree.root = toggle[] ? churn_root : stable_root
            render_toolkit!(frame, tree)
            length(tree.state.instances)
        end),
    ]
end

function markdown_cases()
    source = join((
        "## Section $index\n\nParagraph with **strong text**, [a link](https://example.test/$index), and `code`."
        for index in 1:500
    ), "\n\n")
    parsed = parse_markdown(source)
    return WickedBenchmark[
        WickedBenchmark("markdown_parse_500_sections", "rich_content", () -> length(parse_markdown(source).blocks)),
        WickedBenchmark("markdown_render_500_sections", "rich_content", function ()
            rendered = render_markdown(parsed; width=100)
            length(rendered.lines) + length(rendered.links)
        end),
    ]
end

function virtual_cases()
    source = CallbackDataSource{Int,Int}(
        length=() -> 1_000_000,
        fetch=range -> collect(range),
        key=(item, index) -> item,
        version=() -> UInt64(1),
    )
    state = VirtualListState{Int}(first_index=500_000, viewport_size=50, overscan=10)
    columns = [
        VirtualTableColumn(:value, "Value"; accessor=identity),
        VirtualTableColumn(:square, "Square"; accessor=value -> value * value),
    ]
    return WickedBenchmark[
        WickedBenchmark("virtual_list_million_rows", "virtual", function ()
            window = refresh_virtual_list!(source, state)
            length(window.slots)
        end),
        WickedBenchmark("virtual_table_million_rows", "virtual", function ()
            window = refresh_virtual_list!(source, state)
            length(project_virtual_table(window, columns).rows)
        end),
    ]
end

function semantic_cases()
    before_children = SemanticNode[
        SemanticNode("item-$index", ListItemRole; label="Item $index") for index in 1:1_000
    ]
    after_children = copy(before_children)
    after_children[500] = SemanticNode("item-500", ListItemRole; label="Changed")
    before = SemanticTree(SemanticNode("root", ListRole; children=before_children))
    after = SemanticTree(SemanticNode("root", ListRole; children=after_children))
    return WickedBenchmark[
        WickedBenchmark("semantic_diff_1000_nodes", "semantics", () -> length(diff_semantics(before, after))),
    ]
end

function widget_scaling_cases()
    source = CallbackDataSource{Int,Int}(
        length=() -> 1_000_000,
        fetch=range -> collect(range),
        key=(item, index) -> item,
        version=() -> UInt64(1),
    )
    grid = DataGrid(
        source,
        [
            VirtualTableColumn(:value, "Value"; accessor=identity),
            VirtualTableColumn(:square, "Square"; accessor=value -> value * value),
        ];
        width=100,
        height=32,
    )
    grid_state = DataGridState(source; first_index=500_000, viewport_size=31)
    grid_buffer = Buffer(32, 100)

    tracker = ProgressTracker{Int}(clock=() -> UInt64(0))
    for index in 1:256
        add_progress_task!(tracker, index; description="Task $index", total=100, completed=index % 100)
    end
    progress = ProgressGroup(tracker; width=100, height=24)
    progress_state = ProgressGroupState()
    progress_buffer = Buffer(24, 100)

    live = LiveDisplay(state -> "frame $(state.frame)"; width=80, height=1)
    live_state = LiveDisplayState()
    live_buffer = Buffer(1, 80)

    return WickedBenchmark[
        WickedBenchmark("data_grid_million_rows", "widgets", function ()
            render!(grid_buffer, grid, grid_buffer.area, grid_state)
            grid_state.rows.cursor
        end),
        WickedBenchmark("progress_group_256_tasks", "widgets", function ()
            render!(progress_buffer, progress, progress_buffer.area, progress_state)
            progress_state.offset
        end),
        WickedBenchmark("live_display_frame", "widgets", function ()
            render!(live_buffer, live, live_buffer.area, live_state)
            live_state.frame
        end),
    ]
end

all_cases() = vcat(
    buffer_cases(),
    unicode_cases(),
    runtime_cases(),
    service_scaling_cases(),
    layout_cases(),
    style_cases(),
    toolkit_cases(),
    markdown_cases(),
    virtual_cases(),
    semantic_cases(),
    widget_scaling_cases(),
)

function parse_options(arguments)
    quick = "--quick" in arguments
    list_only = "--list" in arguments
    check = "--check" in arguments
    samples = quick ? 3 : parse(Int, get(ENV, "WICKED_BENCH_SAMPLES", "20"))
    warmups = quick ? 1 : parse(Int, get(ENV, "WICKED_BENCH_WARMUPS", "3"))
    samples > 0 || error("benchmark samples must be positive")
    warmups >= 0 || error("benchmark warmups cannot be negative")
    output = get(ENV, "WICKED_BENCH_OUTPUT", "")
    for argument in arguments
        startswith(argument, "--output=") && (output = split(argument, '='; limit=2)[2])
    end
    return (; quick, list_only, check, samples, warmups, output)
end

function load_budgets()
    path = joinpath(@__DIR__, "budgets.toml")
    values = TOML.parsefile(path)
    return Dict{String,Int}(name => Int(value["maximum_bytes"]) for (name, value) in values["benchmarks"])
end

function write_results(path::String, results, options)
    isempty(path) && return
    payload = Dict(
        "metadata" => Dict(
            "generated_at" => string(now(UTC)),
            "julia_version" => string(VERSION),
            "cpu" => Sys.CPU_NAME,
            "threads" => Threads.nthreads(),
            "samples" => options.samples,
            "warmups" => options.warmups,
        ),
        "results" => Dict(result.name => Dict(
            "group" => result.group,
            "median_seconds" => result.median_seconds,
            "minimum_seconds" => result.minimum_seconds,
            "median_bytes" => result.median_bytes,
            "maximum_bytes" => result.maximum_bytes,
            "checksum" => string(result.checksum),
        ) for result in results),
    )
    open(path, "w") do io
        TOML.print(io, payload; sorted=true)
    end
end

function main(arguments=ARGS)
    options = parse_options(arguments)
    cases = all_cases()
    if options.list_only
        foreach(case -> println(case.name), cases)
        return 0
    end
    budgets = options.check ? load_budgets() : Dict{String,Int}()
    results = WickedBenchmarkResult[]
    failures = String[]
    @printf("%-38s %12s %12s %12s\n", "benchmark", "median ms", "minimum ms", "median bytes")
    for case in cases
        result = benchmark_result(case; samples=options.samples, warmups=options.warmups)
        push!(results, result)
        @printf(
            "%-38s %12.3f %12.3f %12d\n",
            result.name,
            result.median_seconds * 1_000,
            result.minimum_seconds * 1_000,
            result.median_bytes,
        )
        if options.check
            budget = get(budgets, result.name, nothing)
            budget === nothing && push!(failures, "missing allocation budget for $(result.name)")
            budget !== nothing && result.median_bytes > budget &&
                push!(failures, "$(result.name) allocated $(result.median_bytes) bytes (budget: $budget)")
        end
    end
    write_results(options.output, results, options)
    isempty(failures) || begin
        foreach(message -> println(stderr, "benchmark gate: ", message), failures)
        return 1
    end
    return 0
end

exit(main())
