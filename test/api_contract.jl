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

using Wicked.API: Buffer, Rect, draw_text!
import Wicked.API: render!
import Wicked.Toolkit: state_for

struct StableWidget
    label::String
end

mutable struct StableWidgetState
    prefix::String
end

state_for(::StableWidget) = StableWidgetState(">")

render!(buffer::Buffer, widget::StableWidget, area::Rect) =
    draw_text!(buffer, area.row, area.column, widget.label; clip=area)

render!(buffer::Buffer, widget::StableWidget, area::Rect, state::StableWidgetState) =
    draw_text!(buffer, area.row, area.column, state.prefix * widget.label; clip=area)

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

struct ContractApp <: WickedApp end

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
        @test reactive_runtime(signal) isa ReactiveRuntime
        set_signal!(signal, 2)
        @test values == [2]
        @test unsubscribe!(direct)

        computed = computed_signal(value -> value * 2, [signal])
        @test reactive_runtime(computed) === reactive_runtime(signal)
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
        @test plain_snapshot(pilot) == ">stable"
        @test pilot.state isa DownstreamAPIContract.StableAPIConsumer.StableWidgetState
        @test Wicked.API.state_for(widget) isa DownstreamAPIContract.StableAPIConsumer.StableWidgetState
        @test Wicked.API.Buffer === Wicked.Buffer
        @test Wicked.API.RuntimePilot === Wicked.RuntimePilot
        @test Wicked.API.RemoteBackend === Wicked.RemoteBackend
        @test Wicked.API.ChoiceOption === Wicked.ChoiceOption
        @test Wicked.API.row === Wicked.row
        @test Wicked.API.RoutedEvent === Wicked.RoutedEvent
        @test Wicked.API.run === Wicked.run
        @test Wicked.API.assert_semantic_snapshot === Wicked.assert_semantic_snapshot
        @test Wicked.API.pilot_semantic_snapshot === Wicked.pilot_semantic_snapshot
        @test Wicked.API.pilot_semantic_tree === Wicked.pilot_semantic_tree
        @test Wicked.API.assert_semantic_snapshot(pilot, Wicked.API.pilot_semantic_snapshot(pilot)) === pilot
        @test Wicked.API.assert_semantic_snapshot(pilot, Wicked.API.pilot_semantic_tree(pilot)) === pilot
        @test Wicked.API.assert_semantic_query(pilot, Wicked.API.SemanticQuery(role=Wicked.API.ButtonRole)) === pilot
        @test Wicked.API.query_one_semantic(pilot, Wicked.API.SemanticQuery(role=Wicked.API.ButtonRole)).id == "widget"
        @test Wicked.API.Heading isa DataType
        @test Wicked.API.MarkupText isa DataType
        @test Wicked.API.Heading === Wicked.Widgets.Heading
        @test Wicked.API.MarkupText === Wicked.Widgets.MarkupText
        markup = Wicked.API.MarkupText("# Stable\n\n**ready**"; width=32)
        @test Wicked.API.has_block_role(markup, :heading_1)
        @test Wicked.API.has_inline_role(markup, :strong)
        sheet = Wicked.API.parse_stylesheet("""
        Button.primary { color: bright-cyan; }
        Button.primary:focus { modifiers: bold; }
        Button.secondary { color: yellow; }
        """)
        engine = Wicked.API.StyleEngine(; stylesheets=[sheet])
        context = Wicked.API.StyleContext(
            Wicked.API.Button,
            :deploy,
            Set([:primary]),
            Set([:focus]),
            Set{Symbol}(),
        )
        context_record = Wicked.API.style_context_record(context)
        @test context_record.widget_type == "Button"
        @test context_record.id == "deploy"
        @test context_record.classes == "primary"
        @test context_record.states == "focus"
        @test occursin("classes: primary", Wicked.API.style_context_text(context))
        @test startswith(Wicked.API.style_context_markdown(context), "| field | value |")
        @test startswith(Wicked.API.style_context_tsv(context), "field\tvalue")
        inline = Wicked.API.StylePatch(add_modifiers=Wicked.API.UNDERLINE)
        explanation = Wicked.API.explain_style(engine, context; inline)
        @test explanation isa Wicked.API.StyleExplanation
        @test all(step -> step isa Wicked.API.StyleResolutionStep, explanation.steps)
        @test explanation.result == Wicked.API.computed_style(engine, context; inline)
        @test [record.index for record in Wicked.API.style_explanation_records(explanation)] == [1, 2, 3]
        @test [record.source for record in Wicked.API.style_explanation_records(explanation)] == [:stylesheet, :stylesheet, :inline]
        @test Wicked.API.selector_text(sheet.rules[1].selector) == "Button.primary"
        @test Wicked.API.style_explanation_records(explanation)[1].selector_text == "Button.primary"
        @test occursin("stylesheet", Wicked.API.style_explanation_text(explanation))
        @test startswith(Wicked.API.style_explanation_markdown(explanation), "| index | source |")
        @test startswith(Wicked.API.style_explanation_tsv(explanation), "index\tsource")
        @test Wicked.API.search_style_explanation_count(explanation, "stylesheet") == 2
        @test [record.index for record in Wicked.API.search_style_explanation_records(explanation, "stylesheet")] == [1, 2]
        @test only(Wicked.API.search_style_explanation_records(explanation, "inline")).index == 3
        @test occursin("stylesheet", Wicked.API.search_style_explanation_text(explanation, "stylesheet"))
        @test Wicked.API.search_style_explanation_count(explanation, "Button.primary:focus") == 1
        @test startswith(Wicked.API.search_style_explanation_markdown(explanation, "stylesheet"), "| index | source |")
        @test startswith(Wicked.API.search_style_explanation_tsv(explanation, "stylesheet"), "index\tsource")
        @test Wicked.API.style_explanation_summary(explanation).total == 3
        @test Wicked.API.style_explanation_summary_records(explanation) == [
            (source=:inline, count=1),
            (source=:stylesheet, count=2),
        ]
        @test occursin("stylesheet: 2", Wicked.API.style_explanation_summary_text(explanation))
        @test startswith(Wicked.API.style_explanation_summary_markdown(explanation), "| source | count |")
        @test startswith(Wicked.API.style_explanation_summary_tsv(explanation), "source\tcount")
        @test Wicked.API.style_rule_match_summary(engine, context) == (total=3, matched=2, unmatched=1)
        @test [record.selector_text for record in Wicked.API.matching_style_rule_records(engine, context)] == ["Button.primary", "Button.primary:focus"]
        unmatched_rule = only(Wicked.API.unmatched_style_rule_records(engine, context))
        @test unmatched_rule.selector_text == "Button.secondary"
        @test unmatched_rule.mismatch_reasons == ["classes"]
        @test Wicked.API.selector_match_reasons(unmatched_rule.selector, context) == ["classes"]
        @test occursin("matched=false", Wicked.API.unmatched_style_rule_text(engine, context))
        @test startswith(Wicked.API.style_rule_match_markdown(engine, context), "| index | selector |")
        @test startswith(Wicked.API.style_rule_match_tsv(engine, context), "index\tselector")
        @test Wicked.API.search_style_rule_match_count(engine, context, "classes") == 1
        @test only(Wicked.API.search_style_rule_match_records(engine, context, "matched=false")).selector_text == "Button.secondary"
        @test occursin("Button.primary", Wicked.API.search_style_rule_match_text(engine, context, "Button.primary"))
        @test startswith(Wicked.API.search_style_rule_match_markdown(engine, context, "stylesheet"), "| index | selector |")
        @test startswith(Wicked.API.search_style_rule_match_tsv(engine, context, "classes"), "index\tselector")
        diagnostics = Wicked.API.style_diagnostics(engine, context; inline)
        diagnostics_record = Wicked.API.style_diagnostics_record(diagnostics)
        @test diagnostics isa Wicked.API.StyleDiagnostics
        @test diagnostics_record.total_rules == 3
        @test diagnostics_record.matched_rules == 2
        @test diagnostics_record.unmatched_rules == 1
        @test occursin("[rule matches]", Wicked.API.style_diagnostics_text(diagnostics))
        @test occursin("## Resolution", Wicked.API.style_diagnostics_markdown(diagnostics))
        @test startswith(Wicked.API.style_diagnostics_tsv(diagnostics), "section\tfield\tvalue")
        @test Wicked.API.search_style_diagnostics_count(diagnostics, "resolution") == 3
        @test any(record -> record.section == :rule_match, Wicked.API.search_style_diagnostics_records(diagnostics, "classes"))
        @test occursin("matched=false", Wicked.API.search_style_diagnostics_text(diagnostics, "matched=false"))
        @test startswith(Wicked.API.search_style_diagnostics_markdown(diagnostics, "Button.primary"), "| section | index |")
        @test startswith(Wicked.API.search_style_diagnostics_tsv(diagnostics, "inline"), "section\tindex")
        @test Wicked.Experimental isa Module
        @test Wicked.Experimental === Base.getproperty(Wicked, :Experimental)
        @test Set(names(Wicked.Experimental; all=false, imported=false)) == Set([:Experimental])
    end

    @testset "stable application runtime contract" begin
        app = DownstreamAPIContract.ContractApp()
        @test subscriptions(app, :model) == ()
        result = UpdateResult(:next; command=NoCommand(), redraw=false)
        @test result.model == :next
        @test result.command isa NoCommand
        @test !result.redraw
        process = execute_process(ProcessCommand(Cmd(["printf", "ok"])))
        @test process_succeeded(process)
        @test String(process.stdout) == "ok"
        @test hasmethod(run, Tuple{DownstreamAPIContract.ContractApp})

        backend = TestBackend(2, 4)
        runtime = ApplicationRuntime(
            app,
            initialize(app),
            Terminal(backend),
            ChannelInputSource();
            config=RuntimeConfig(resize_poll_seconds=nothing),
        )
        @test !suspend!(runtime)
        runtime.running = true
        @test suspend!(runtime)
        @test runtime.suspended
        @test resume!(runtime)
        @test !runtime.suspended
        resize_backend!(backend, 3, 7)
        @test poll_terminal_resize!(runtime)
        @test take!(runtime.messages) == ResizeEvent(Size(3, 7))
        request_exit!(runtime)
        @test !poll_terminal_resize!(runtime)
    end

    @testset "stable managed notifications" begin
        manager = NotificationManager(2; clock=() -> 1_000)
        event = notify!(
            manager,
            "Build completed";
            id=:build,
            title="CI",
            severity=:success,
            timeout=1.0,
            actions=[NotificationAction(:open_log, "Open log", :show_build_log)],
        )
        @test event.lifecycle == NotificationAdded
        @test notification_generation(manager) == 1

        snapshots = notification_snapshots(manager; now_ns=1_000)
        @test length(snapshots) == 1
        @test snapshots[1] isa NotificationSnapshot
        @test snapshots[1].actions[1].label == "Open log"
        @test !isempty(render_notification_control(snapshots; width=40))

        result = activate_notification_action!(manager, :build, :open_log)
        @test result.status == NotificationActionHandled
        @test result.value == :show_build_log
        @test result.dismissed
        @test isempty(notification_snapshots(manager; now_ns=1_000))

        notify!(manager, "Pinned"; id=:pinned, timeout=nothing, dismissible=false)
        @test !dismiss_notification!(manager, :pinned)
        @test dismiss_notification!(manager, :pinned; force=true)
        @test !isempty(notification_events(manager))
        @test !isempty(take_notification_events!(manager))
        @test isempty(take_notification_events!(manager))
        @test isempty(notification_errors(manager))
        @test isempty(take_notification_errors!(manager))
        @test clear_notifications!(manager) == 0
        @test notification_center_snapshot(manager) isa NotificationCenter

        notify!(
            manager,
            "Deploy failed";
            id=:deploy,
            title="Deploy",
            severity=:error,
            timeout=nothing,
            actions=[NotificationAction(:retry, "Retry", :retry_deploy)],
        )
        snapshots = notification_snapshots(manager)
        component = notification_component(
            ToolkitElementAdapter(),
            manager;
            width=40,
            semantic_id="notifications",
        )
        @test component isa ToolkitComponentView
        semantic_tree = notification_semantic_tree(snapshots; id="notifications")
        @test semantic_node(semantic_tree, "notifications").role == LogRole
        @test semantic_node(semantic_tree, "notifications/1").role == AlertRole
        @test semantic_node(semantic_tree, "notifications/1/action/1").role == ButtonRole

        dispatcher = SemanticDispatcher()
        binding = bind_notification_semantics!(
            dispatcher,
            manager,
            snapshots;
            id="notifications",
        )
        @test binding isa NotificationSemanticBinding
        pilot = SemanticPilot(semantic_tree; dispatcher)
        action_result = perform_semantic_action!(
            pilot,
            "notifications/1/action/1",
            ActivateSemanticAction,
        )
        @test action_result.handled
        @test action_result.value == :retry_deploy
        @test isempty(notification_snapshots(manager))
        @test unbind_notification_semantics!(binding)
        @test !unbind_notification_semantics!(binding)
    end

    @testset "stable semantic automation" begin
        save = SemanticNode(
            "save",
            ButtonRole;
            label="Save",
            bounds=SemanticRect(1, 1, 1, 4),
            state=SemanticState(focusable=true, focused=true),
            actions=[ActivateSemanticAction, FocusSemanticAction],
        )
        progress = SemanticNode(
            "progress",
            ProgressRole;
            label="Deploy",
            description="Deployment progress",
            state=SemanticState(busy=true, invalid=true, value="Deploying", value_now=50, value_min=0, value_max=100),
            metadata=Dict(:phase => :deploy),
        )
        hidden_status = SemanticNode(
            "hidden-status",
            StatusRole;
            label="Hidden status",
            state=SemanticState(hidden=true),
        )
        tree = SemanticTree(SemanticNode("app", ApplicationRole; label="App", children=[save, progress, hidden_status]))
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(tree)))
        @test semantic_node(tree, "save").label == "Save"
        @test length(semantic_nodes(tree)) == 4
        @test query_one_semantic(tree, SemanticQuery(role=ButtonRole)).id == "save"
        @test query_one_semantic(tree; role=ButtonRole).id == "save"
        @test query_one_semantic(tree; actions=[ActivateSemanticAction, FocusSemanticAction]).id == "save"
        @test query_one_semantic(tree; bounds=SemanticRect(1, 1, 1, 4)).id == "save"
        @test length(query_semantics(tree; id="save", enabled=true, focusable=true, focused=true)) == 1
        @test query_one_semantic(tree; description=r"Deployment").id == "progress"
        @test query_one_semantic(tree; busy=true, invalid=true, value=r"Deploy", value_now=50, value_min=0, value_max=100).id == "progress"
        @test query_one_semantic(tree; metadata=Dict(:phase => :deploy)).id == "progress"
        query_display = sprint(show, SemanticQuery(id=:save, role=ButtonRole, bounds=SemanticRect(1, 1, 1, 4), actions=[ActivateSemanticAction, FocusSemanticAction], focused=true, metadata=Dict(:phase => :deploy)))
        @test occursin("SemanticQuery(", query_display)
        @test occursin("id=\"save\"", query_display)
        @test occursin("bounds=SemanticRect", query_display)
        @test occursin("actions=Set", query_display)
        @test occursin("focused=true", query_display)
        @test occursin("metadata=Dict", query_display)
        @test isempty(query_semantics(tree; id="hidden-status"))
        @test query_one_semantic(tree; hidden=true).id == "hidden-status"
        @test assert_semantic_query(tree, SemanticQuery(role=ButtonRole)) === tree
        @test assert_semantic_query(tree; role=ButtonRole) === tree
        @test assert_semantic_query(tree; enabled=true, minimum=2) === tree
        @test assert_semantic_query(tree; role=ButtonRole, maximum=1) === tree
        @test assert_semantic_query(tree, SemanticQuery(role=ButtonRole); count=1) === tree
        @test assert_semantic_query(tree, SemanticQuery(enabled=true); minimum=2) === tree
        @test assert_semantic_query(tree, SemanticQuery(role=ButtonRole); maximum=1) === tree
        @test_throws BufferAssertionError assert_semantic_query(tree, SemanticQuery(role=ButtonRole); count=2)
        @test_throws BufferAssertionError assert_semantic_query(tree, SemanticQuery(role=ButtonRole); minimum=2)
        @test_throws BufferAssertionError assert_semantic_query(tree, SemanticQuery(enabled=true); maximum=1)
        @test_throws ArgumentError assert_semantic_query(tree, SemanticQuery(role=ButtonRole); count=1.5)
        @test_throws ArgumentError assert_semantic_query(tree, SemanticQuery(role=ButtonRole); minimum=1.5)
        @test_throws ArgumentError assert_semantic_query(tree, SemanticQuery(role=ButtonRole); maximum=1.5)
        @test_throws ArgumentError assert_semantic_query(tree, SemanticQuery(role=ButtonRole); count=1, minimum=1)
        @test_throws ArgumentError assert_semantic_query(tree, SemanticQuery(role=ButtonRole); minimum=1, maximum=1)
        try
            query_one_semantic(tree; id="missing")
            @test false
        catch error
            @test error isa SemanticQueryError
            message = sprint(showerror, error)
            @test occursin("SemanticQuery(", message)
            @test occursin("id=\"missing\"", message)
            @test occursin("no matching semantic ids", message)
        end
        try
            query_one_semantic(tree)
            @test false
        catch error
            @test error isa SemanticQueryError
            message = sprint(showerror, error)
            @test occursin("SemanticQuery()", message)
            @test occursin("matched semantic ids", message)
            @test occursin("app", message)
            @test occursin("save", message)
        end
        @test occursin("save:ButtonRole", semantic_snapshot(tree))

        dispatcher = SemanticDispatcher()
        register_semantic_handler!(
            dispatcher,
            "save",
            request -> SemanticActionResult(
                request.action == ActivateSemanticAction;
                value=:saved,
            ),
        )
        pilot = SemanticPilot(tree; dispatcher)
        @test query_one_semantic(pilot; id="save").role == ButtonRole
        @test length(query_semantics(pilot, SemanticQuery(role=ButtonRole))) == 1
        @test assert_semantic_query(pilot, SemanticQuery(role=ButtonRole)) === pilot
        @test assert_semantic_query(pilot; id="save") === pilot
        result = perform_semantic_action!(pilot, "save", ActivateSemanticAction)
        @test result.handled
        @test result.value == :saved
        @test isempty(take_semantic_announcements!(pilot))

        refreshed = SemanticTree(SemanticNode("app", ApplicationRole; label="App"))
        changes = refresh_semantic_pilot!(pilot, refreshed)
        @test any(change -> change.kind == RemovedSemanticNode && change.node_id == "save", changes)
        @test occursin("RemovedSemanticNode save", semantic_pilot_snapshot(pilot; include_changes=true))

        unregister_semantic_handler!(dispatcher, "save")
        @test !dispatch_semantic_action!(
            dispatcher,
            SemanticActionRequest("save", ActivateSemanticAction),
        ).handled
    end

    @testset "stable progress component bridge" begin
        tracker = ProgressTracker{Symbol}(clock=() -> 1_000)
        add_progress_task!(tracker, :build; description="Build", total=10)
        advance_progress!(tracker, :build, 4)
        snapshot = progress_snapshot(tracker, :build; now_ns=1_000)

        line = render_progress_control(snapshot; width=32)
        @test !isempty(line.spans)

        node = progress_semantic_node(snapshot; id="build")
        @test node.role == ProgressRole
        @test node.state.value_now == 4.0
        @test node.state.value_max == 10.0

        component = progress_component(
            ToolkitElementAdapter(),
            snapshot;
            width=32,
            semantic_id="build",
        )
        @test component isa ToolkitComponentView
        @test component.semantics.role == ProgressRole
    end

    @testset "stable live reload lifecycle" begin
        clock_value = Ref(UInt64(0))
        applied = Ref("")

        mktempdir() do directory
            path = joinpath(directory, "theme.txt")
            write(path, "first")

            reloads = LiveReloadManager(; clock=() -> clock_value[])
            register_reload_target!(
                reloads,
                :theme,
                path;
                loader=paths -> read(only(paths), String),
                apply=value -> (applied[] = value),
                debounce=0.0,
                missing_policy=FailOnMissingFiles,
            )

            @test watched_reload_paths(reloads, :theme) == [path]
            write(path, "second")
            trigger_reload!(reloads, :theme)

            events = poll_reloads!(reloads)
            @test length(events) == 1
            @test only(events).outcome == ReloadApplied
            @test only(events).outcome isa ReloadOutcome
            @test only(events).id == :theme
            @test applied[] == "second"
            @test reload_target_state(reloads, :theme) == WatchingReload
            @test reload_events(reloads) == events
            @test take_reload_events!(reloads) == events
            @test isempty(take_reload_events!(reloads))
            @test isempty(reload_errors(reloads))
            @test isempty(take_reload_errors!(reloads))
            @test set_reload_enabled!(reloads, :theme, false)
            @test reload_target_state(reloads, :theme) == DisabledReload
            @test unregister_reload_target!(reloads, :theme)
            @test reload_target_state(reloads, :theme) === nothing
        end
    end

    @testset "stable virtualized data widgets" begin
        rows = [
            (id=:alpha, name="Alpha", score=10),
            (id=:beta, name="Beta", score=20),
            (id=:gamma, name="Gamma", score=30),
        ]
        source = VectorDataSource(rows; key=(item, _) -> item.id)
        state = VirtualListState{Symbol}(viewport_size=3, overscan=0, multiple=true)
        window = refresh_virtual_list!(source, state)

        @test window isa VirtualListWindow
        @test data_length(source) == 3
        @test visible_range(state.viewport, data_length(source)) == 1:3
        @test all(slot -> slot.kind == ReadySlot, window.slots)

        bindings = default_virtual_bindings()
        down = handle_virtual_key!(state, window, bindings, :down)
        @test down == VirtualActionResult{Symbol}(true, VirtualCursorDown, :beta)
        selected = handle_virtual_key!(state, window, bindings, :space)
        @test selected.consumed
        @test :beta in state.selected

        pointer = handle_virtual_pointer!(
            state,
            window,
            VirtualPointerEvent(VirtualPointerPress, 3, 1),
        )
        @test pointer.consumed
        @test pointer.key == :gamma
        @test :gamma in state.selected

        typeahead = VirtualTypeAhead(timeout_ms=1_000)
        push_virtual_typeahead!(typeahead, "a"; now_ns=1)
        @test apply_virtual_typeahead!(
            state,
            window,
            typeahead;
            item_text=(item, _) -> item.name,
        ).key == :alpha
        backspace_virtual_typeahead!(typeahead; now_ns=2)
        @test isempty(typeahead.query)
        clear_virtual_typeahead!(typeahead)

        state.anchor = 1
        state.cursor = 1
        selection = begin_virtual_range_selection(state, window, 3; additive=false)
        range_result = apply_virtual_range_selection!(state, window, selection)
        @test range_result isa RangeSelectionResult
        @test range_result.complete
        @test state.selected == Set([:alpha, :beta, :gamma])
        cancel_virtual_range_selection!(selection)

        columns = [
            VirtualTableColumn(:name, "Name"; width=8, accessor=row -> row.name),
            VirtualTableColumn(:score, "Score"; width=5, accessor=row -> row.score, alignment=:right),
        ]
        layout = TableLayoutState(columns)
        set_virtual_column_width!(layout, :name, 10)
        reorder_virtual_column!(layout, :score, 1)
        toggle_virtual_sort!(layout, :score)
        set_virtual_filter!(layout, :name, "a")
        set_virtual_search!(layout, "alp")
        @test virtual_table_query(layout) isa DataQuery
        snapshot = table_layout_snapshot(layout)
        @test snapshot.search == "alp"
        @test restore_table_layout!(layout, snapshot) === layout
        layout_source = QueryDataSource(data; key=(row, _) -> row.id, search_text=row -> row.name)
        @test apply_virtual_table_query!(layout_source, layout) === layout_source
        @test query_data_source(layout_source).search == "alp"
        laid_out = apply_virtual_table_layout(columns, layout)
        @test first(laid_out).id == :score
        visibility = ColumnVisibilityState(hidden=[:name])
        visibility_snapshot = column_visibility_snapshot(visibility)
        @test restore_column_visibility!(visibility, visibility_snapshot) === visibility
        @test !virtual_column_visible(visibility, :name)
        @test [column.id for column in visible_virtual_columns(columns, visibility)] == [:score]
        @test [column.id for column in apply_virtual_column_visibility(columns, layout, visibility)] == [:score]
        @test show_virtual_column!(visibility, :name) === visibility
        @test hide_virtual_column!(visibility, :score) === visibility
        @test toggle_virtual_column_visibility!(visibility, :score) === visibility
        @test virtual_column_visible(visibility, :score)
        row_actions = [
            VirtualRowAction(:open, "Open"; handler=(row, index, key) -> (key, row.name)),
            VirtualRowAction(:disabled, "Disabled"; enabled=false),
        ]
        @test virtual_row_action_enabled(first(row_actions), data[1], 1; key=data[1].id)
        @test length(virtual_row_action_menu(row_actions, data[1], 1; key=data[1].id)) == 1
        row_action = invoke_virtual_row_action(row_actions, :open, data[1], 1; key=data[1].id)
        @test row_action isa VirtualRowActionResult
        @test row_action.handled
        @test row_action.action == :open
        @test !invoke_virtual_row_action(row_actions, :disabled, data[1], 1; key=data[1].id).handled
        resize = begin_virtual_column_resize(layout, :name, 1)
        @test update_virtual_column_resize!(layout, resize, 4) == 13
        @test finish_virtual_column_resize!(resize) == 13
        table = project_virtual_table(window, laid_out)
        @test table isa VirtualTableWindow
        @test !isempty(render_virtual_table(table; width=32))
        @test virtual_table_semantic_tree(table).root.role == TableRole
        @test virtual_table_column_at(laid_out, 1) == :score
        clear_virtual_filter!(layout, :name)
        set_virtual_search!(layout, nothing)

        list_lines = render_virtual_list(window, state; width=32)
        @test !isempty(list_lines)
        @test virtual_list_slot_at(window, 1).key == :alpha
        @test virtual_list_semantic_tree(window, state).root.role == ListRole
        @test register_virtual_list_semantic_handlers! isa Function
        @test virtual_list_component(ToolkitElementAdapter(), window, state; width=32) isa ToolkitComponentView
        @test virtual_table_component(ToolkitElementAdapter(), table; width=32) isa ToolkitComponentView

        tree_source = CallbackTreeDataSource{String,Symbol}(
            roots=() -> ["root"],
            children=item -> item == "root" ? ["child"] : String[],
            key=item -> Symbol(item),
        )
        tree_state = VirtualTreeState{Symbol}(multiple=true)
        expand_virtual_tree!(tree_state, :root)
        tree_window = flatten_virtual_tree(tree_source, tree_state)
        @test tree_window isa VirtualTreeWindow
        @test register_data_grid_semantic_handlers! isa Function
        @test register_data_table_semantic_handlers! isa Function
        @test register_virtual_table_semantic_handlers! isa Function
        @test register_virtual_tree_semantic_handlers! isa Function
        @test register_tree_table_semantic_handlers! isa Function
        @test length(tree_window.rows) == 2
        @test isempty(tree_window.diagnostics)
        move_virtual_tree_cursor!(tree_state, tree_window, 1)
        @test tree_state.cursor == :child
        select_virtual_tree!(tree_state, :child)
        @test :child in tree_state.selected
        toggle_virtual_tree!(tree_state, :root)
        collapse_virtual_tree!(tree_state, :root)
        clear_virtual_tree_selection!(tree_state)
        @test isempty(tree_state.selected)
        @test !isempty(render_virtual_tree(tree_window, tree_state; width=32))
        @test virtual_tree_row_at(tree_window, 1).key == :root
        @test virtual_tree_semantic_tree(tree_window, tree_state).root.role == TreeRole
        @test virtual_tree_component(ToolkitElementAdapter(), tree_window, tree_state; width=32) isa ToolkitComponentView
    end

    @testset "stable file browser navigation" begin
        mktempdir() do root
            file_path = joinpath(root, "alpha.txt")
            directory_path = joinpath(root, "nested")
            write(file_path, "alpha")
            mkdir(directory_path)
            write(joinpath(directory_path, "child.txt"), "child")

            read_result = read_directory_entries(root)
            @test read_result isa DirectoryReadResult
            @test any(entry -> entry.kind == RegularFileEntry && entry.name == "alpha.txt", read_result.entries)
            @test any(entry -> entry.kind == DirectoryFileEntry && entry.name == "nested", read_result.entries)

            state = FileBrowserState(root; root, mode=SelectMultipleMode)
            @test state isa FilePickerState
            @test current_file_entry(state) isa FileEntry
            set_file_sort!(state, FileNameSort; direction=AscendingFileSort)
            set_file_filter!(state, "")
            set_file_cursor!(state, findfirst(entry -> entry.name == "alpha.txt", state.entries))

            bindings = default_file_browser_bindings()
            @test file_browser_action_for_key(bindings, :space) == FileToggleSelection
            result = handle_file_browser_key!(state, bindings, :space)
            @test result.consumed
            @test result.action == FileToggleSelection
            @test !result.navigated
            @test isempty(result.choices)
            choices = choose_file_entry!(state)
            @test only(choices).kind == RegularFileEntry
            @test only(choices).path == realpath(file_path)
            @test file_choices(state) == choices

            clear_file_selection!(state)
            move_file_cursor!(state, 1)
            pointer = handle_file_browser_pointer!(state, FilePointerEvent(FilePointerPress, 1, 1))
            @test pointer.consumed
            @test pointer.action == FileToggleSelection

            set_file_cursor!(state, findfirst(entry -> entry.name == "nested", state.entries))
            @test enter_file_entry!(state)
            @test state.current_path == realpath(directory_path)
            @test leave_file_directory!(state)
            @test state.current_path == realpath(root)
            @test_throws ArgumentError navigate_file_browser!(state, dirname(root))

            directory_state = FileBrowserState(root; root, mode=SelectDirectoryMode)
            directory_choices = choose_current_directory!(directory_state)
            @test only(directory_choices).kind == DirectoryFileEntry
            @test only(directory_choices).path == realpath(root)

            rendered = render_file_browser(state; width=40, height=4)
            @test !isempty(rendered)
            @test file_browser_semantic_tree(state; width=40).root.role == TreeRole
            @test file_browser_component(ToolkitElementAdapter(), state; width=40, height=4) isa ToolkitComponentView
            @test !isempty(file_path_breadcrumbs(state))

            controller = FileBrowserController(state)
            request_file_refresh!(controller)
            for _ in 1:1_000
                poll_file_refresh!(controller) > 0 && break
                yield()
            end
            @test !state.loading
            @test cancel_file_refresh!(controller) === controller
        end
    end

    @testset "stable rich content and source views" begin
        document = parse_markdown("[docs](https://example.test)\n\n```julia\nx = 1\n```")
        @test document isa MarkdownDocument
        @test !isempty(document.blocks)

        rendered = render_markdown(document; width=40)
        @test rendered isa RichDocument
        @test only(rendered.links).target.safe
        @test link_by_id(rendered, 1).label == "docs"
        @test only(links_at_line(rendered, 1)).target.uri == "https://example.test"
        @test markdown_link_safe("https://example.test")
        @test !markdown_link_safe("javascript:alert(1)")
        @test occursin("docs", plain_text(rendered))

        tokens = highlight("x = 1", "julia")
        @test any(token -> token.kind == NumberToken, tokens)
        registry = default_syntax_registry()
        register_syntax!(registry, ["custom"], source -> [SyntaxToken(String(source), KeywordToken, 1, lastindex(String(source)))])
        @test only(highlight(registry, "token", "custom")).kind == KeywordToken

        view = MarkdownView("[docs](https://example.test)"; width=40)
        @test markdown_line_count(view) == 1
        viewport = markdown_viewport(view, 1)
        @test viewport isa MarkdownViewport
        focus_next_link!(view)
        @test activate_focused_link(view).allowed
        select_markdown_text!(view, TextPoint(1, 1), TextPoint(1, 5))
        @test markdown_selected_text(view) == "docs"
        clear_markdown_selection!(view)

        markdown_bindings = default_markdown_bindings()
        @test action_for_key(markdown_bindings, :tab) == FocusNextLink
        @test register_markdown_view_semantic_handlers! isa Function
        input_result = handle_markdown_key!(view, markdown_bindings, :enter; viewport_height=1)
        @test input_result isa MarkdownInputResult
        pointer_result = handle_markdown_pointer!(view, MarkdownPointerEvent(PointerHover, 1, 1))
        @test pointer_result.consumed

        style_map = RichStyleMap(Dict(:link => :blue), :plain)
        styled = style_rich_line(first(rendered.lines), style_map)
        @test styled isa StyledRichLine
        @test :link in semantic_roles(rendered)

        surface = RichSurface(40, 2)
        stats = render_rich_lines!(surface, rendered.lines; focused_link=1)
        @test stats isa RichRenderStats
        @test rich_surface_hit_test(surface, 1, 1) == 1
        @test occursin("docs", rich_surface_snapshot(surface))
        target = Dict{Tuple{Int,Int},RichSurfaceCell}()
        blit_rich_surface!((store, row, column, cell) -> (store[(row, column)] = cell), target, surface)
        @test haskey(target, (1, 1))
        viewport_after_surface, surface_stats = render_markdown_surface!(surface, view; height=1)
        @test viewport_after_surface isa MarkdownViewport
        @test surface_stats isa RichRenderStats



        adapter = CoreTextAdapter(
            styles=RoleStyleResolver(Dict(:link => Style(foreground=AnsiColor(4))), Style()),
            span_factory=(text, style) -> Span(text; style),
            line_factory=spans -> Line(Span[spans...]),
            text_factory=lines -> Wicked.API.Text(Line[lines...]),
        )
        rich_span = RichSpan("custom", :link, 1)
        core_span = rich_span_to_core(adapter, rich_span; focused_link=1)
        @test core_span isa Span
        @test core_span.content == "custom"
        core_line = rich_line_to_core(adapter, RichLine(RichSpan[rich_span], :paragraph, nothing); focused_link=1)
        @test core_line isa Line
        core_text = rich_lines_to_core_text(adapter, RichLine[RichLine(RichSpan[rich_span], :paragraph, nothing)]; focused_link=1)
        @test core_text isa Wicked.API.Text

        written = Dict{Tuple{Int,Int},Tuple{String,Symbol}}()
        buffer_adapter = CoreBufferAdapter(
            styles=RoleStyleResolver(Dict(:link => :link_style), :plain_style),
            writer=(store, x, y, cell, style) -> (store[(y, x)] = (cell.grapheme, style)),
            coordinate_base=1,
        )
        rich_buffer = RichSurface(8, 1)
        render_rich_lines!(rich_buffer, RichLine[RichLine(RichSpan[RichSpan("go", :link, 1)], :paragraph, nothing)])
        @test blit_rich_to_core!(buffer_adapter, written, rich_buffer; row=1, column=1) === written
        @test written[(1, 1)] == ("g", :link_style)
        @test CoreBufferAdapter(coordinate_base=0) isa CoreBufferAdapter
        @test_throws ArgumentError CoreBufferAdapter(coordinate_base=2)
        @test CoreAdapterError(:span, "failed", ["attempt"]) isa CoreAdapterError


        component = MarkdownToolkitComponent(view)
        @test markdown_paragraph_widget(component, 1) !== nothing
        @test markdown_toolkit_element(component, 1) !== nothing

        code = CodeViewState("one\ntwo\nthree"; language="julia")
        @test code.cursor_line == 1
        move_code_cursor!(code, 1; viewport_height=2)
        @test code.cursor_line == 2
        begin_code_selection!(code, 1)
        move_code_cursor!(code, 1; viewport_height=2, extend_selection=true)
        @test selected_code_text(code) == "one\ntwo"
        clear_code_selection!(code)
        @test toggle_code_breakpoint!(code, 2)
        matches = search_code!(code, "two")
        @test only(matches) isa CodeSearchMatch
        @test next_code_match!(code) isa CodeSearchMatch
        clear_code_search!(code)
        diagnostic = CodeDiagnostic(
            CodeRange(CodeLocation(2, 1), CodeLocation(2, 4)),
            CodeError,
            "problem",
        )
        set_code_diagnostics!(code, [diagnostic])
        rendered_code = render_code_view(code; width=40, height=2)
        @test rendered_code isa CodeViewRender
        @test code_view_semantic_node(code, "code").state.invalid

        code_bindings = default_code_view_bindings()
        @test code_view_action_for_key(code_bindings, :down) == CodeCursorDown
        code_result = handle_code_view_key!(code, code_bindings, :down; viewport_height=2)
        @test code_result isa CodeViewActionResult
        @test code_result.consumed
        @test register_code_view_semantic_handlers! isa Function
        @test register_syntax_view_semantic_handlers! isa Function
        @test register_diff_view_semantic_handlers! isa Function
        @test register_ansi_view_semantic_handlers! isa Function
        @test code_view_component(ToolkitElementAdapter(), code; width=40, height=2) isa ToolkitComponentView

        diff = parse_unified_diff("--- a/file.jl\n+++ b/file.jl\n@@ -1 +1 @@\n-old\n+new\n")
        @test diff isa UnifiedDiff
        @test any(line -> line.kind == DiffAddedLine, diff.lines)
        @test !isempty(render_unified_diff(diff; width=40, height=4))
        @test diff_view_component(ToolkitElementAdapter(), diff; width=40, height=4) isa ToolkitComponentView

        side_by_side = project_side_by_side_diff(diff)
        @test side_by_side isa SideBySideDiff
        @test !isempty(render_side_by_side_diff(side_by_side; width=60, height=4))
        @test side_by_side_diff_component(ToolkitElementAdapter(), side_by_side; width=60, height=4) isa ToolkitComponentView
    end

    @testset "stable overlays, modals, and screens" begin
        manager = OverlayManager{String}()
        closed = Tuple{String,OverlayDismissReason}[]

        base = open_overlay!(
            manager,
            "base";
            options=OverlayOptions(priority=1, group=:menu),
            focus_restore_token=:base_focus,
            on_close=(record, reason) -> push!(closed, (record.content, reason)),
        )
        modal = open_overlay!(
            manager,
            "modal";
            options=OverlayOptions(modality=ModalOverlay, priority=2, dismiss_on_blur=true),
            on_close=(record, reason) -> push!(closed, (record.content, reason)),
        )
        floating = open_overlay!(
            manager,
            "floating";
            options=OverlayOptions(priority=3),
            on_close=(record, reason) -> push!(closed, (record.content, reason)),
        )

        @test base isa OverlayHandle
        @test overlay_count(manager) == 3
        @test has_overlay(manager, modal)
        @test find_overlay(manager, base).focus_restore_token == :base_focus
        @test top_overlay(manager).content == "floating"
        @test [record.content for record in overlay_entries(manager)] == ["base", "modal", "floating"]
        @test [record.content for record in active_overlay_entries(manager)] == ["modal", "floating"]
        @test replace_overlay!(manager, floating, "float")
        @test top_overlay(manager).content == "float"

        @test dismiss_overlay_on_blur!(manager, modal)
        @test ("modal", OverlayBlurred) in closed
        @test !has_overlay(manager, modal)

        exclusive = open_overlay!(
            manager,
            "exclusive";
            options=OverlayOptions(group=:menu, exclusive=true),
            on_close=(record, reason) -> push!(closed, (record.content, reason)),
        )
        @test exclusive isa OverlayHandle
        @test !has_overlay(manager, base)
        @test ("base", OverlayGroupReplaced) in closed

        @test configure_overlay!(
            manager,
            exclusive,
            OverlayOptions(placement=OverlayTopRight, dismiss_on_escape=true, priority=4),
        )
        @test dismiss_overlay_on_escape!(manager)
        @test ("exclusive", OverlayEscaped) in closed
        @test close_all_overlays!(manager) == 1
        @test ("float", OverlayShutdown) in closed
        @test isempty(overlay_errors(manager))
        @test isempty(take_overlay_errors!(manager))

        erroring = OverlayManager{String}()
        handle = open_overlay!(
            erroring,
            "bad";
            on_close=(record, reason) -> error("close failed"),
        )
        @test close_overlay!(erroring, handle)
        @test !isempty(overlay_errors(erroring))
        @test !isempty(take_overlay_errors!(erroring))
        @test isempty(take_overlay_errors!(erroring))

        layout_manager = OverlayManager{String}()
        anchored = open_overlay!(
            layout_manager,
            "anchored";
            options=OverlayOptions(placement=OverlayAnchor),
        )
        viewport = Rect(1, 1, 10, 30)
        request = OverlayLayoutRequest(
            anchored,
            Size(3, 8);
            anchor=Rect(2, 2, 1, 4),
            preferred=[AnchorBelowStart, AnchorAboveStart],
            margin=1,
        )
        layout = layout_overlay(request, find_overlay(layout_manager, anchored).options, viewport)
        @test layout isa OverlayLayoutResult
        @test layout.handle == anchored
        @test layout.placement == OverlayAnchor
        layouts = layout_overlays(layout_manager, viewport) do record, available
            OverlayLayoutRequest(record.handle, Size(2, 6); anchor=Rect(2, 2, 1, 4))
        end
        @test length(layouts) == 1

        drawer = DrawerState(open=true, edge=RightDrawer, size=5)
        rect = drawer_rect(drawer, ComponentRect(1, 1, 20, 10))
        @test rect.width == 5
        @test close_drawer!(drawer) === drawer
        @test !drawer.open
        @test register_drawer_semantic_handlers! isa Function

        popover = place_popover(
            ComponentRect(2, 2, 4, 1),
            6,
            3,
            ComponentRect(1, 1, 30, 10);
            preferred=BelowPopover,
        )
        @test popover isa PopoverResult
        @test popover.placement in instances(PopoverPlacement)
        @test register_popover_semantic_handlers! isa Function

        tooltip = TooltipState(delay_ms=10)
        begin_tooltip_hover!(tooltip, :button, "Help"; now_ns=1)
        @test !tooltip.visible
        @test tick_tooltip!(tooltip; now_ns=10_000_001)
        @test tooltip.visible
        dismiss_tooltip!(tooltip)
        @test !tooltip.visible
        leave_tooltip!(tooltip)
        @test tooltip.target === nothing
        @test register_tooltip_semantic_handlers! isa Function

        modals = ModalStack()
        push_modal!(modals, ModalEntry(:confirm, "Confirm"))
        @test has_modal(modals)
        @test top_modal(modals).id == "confirm"
        @test dismiss_modal!(modals).content == "Confirm"
        @test !has_modal(modals)

        screens = ScreenStack()
        home = Screen(:home, model -> Label("Home"); mode=ReplaceScreen)
        details = Screen(:details, model -> Label("Details"); mode=OverlayScreen)
        push_screen!(screens, home)
        @test current_screen(screens).id == :home
        push_screen!(screens, details)
        @test current_screen(screens).id == :details
        @test PushScreen(details).screen === details
        @test PopScreen() isa PopScreen
        replace_screen!(screens, home)
        @test current_screen(screens).id == :home
        @test pop_screen!(screens).id == :home
        @test current_screen(screens).id == :home
        @test pop_screen!(screens).id == :home
        @test current_screen(screens) === nothing
        @test ReplaceWithScreen(home).screen === home
    end

    @testset "stable drag and drop routing" begin
        manager = DragDropManager(threshold=1)
        payload = DragPayload(
            "row-1";
            mime="text/plain",
            allowed_effects=(CopyDragEffect, MoveDragEffect),
            description="Row",
        )
        target = DropTarget(
            :table,
            ComponentRect(1, 1, 10, 20);
            accepted_mime_prefixes=("text/",),
            accepted_effects=(MoveDragEffect,),
            preferred_effect=MoveDragEffect,
            priority=10,
        )

        register_drop_target!(manager, target)
        begin_drag_candidate!(manager, :source, payload, DragPoint(1, 1))
        @test manager.phase == DragCandidate
        @test !update_drag!(manager, DragPoint(1, 1))
        @test update_drag!(manager, DragPoint(1, 3))
        @test manager.phase == Dragging
        @test active_drop_target(manager).id == "table"

        autoscroll = drag_autoscroll_request(manager; edge_size=2, maximum_speed=3)
        @test autoscroll isa AutoScrollRequest
        @test autoscroll.target_id == "table"
        @test autoscroll.vertical < 0 || autoscroll.horizontal < 0

        result = drop_drag!(manager, DragPoint(2, 2))
        @test result isa DropResult
        @test result.accepted
        @test result.source_id == "source"
        @test result.target_id == "table"
        @test result.effect == MoveDragEffect
        @test result.payload.value == "row-1"
        events = take_drag_events!(manager)
        @test any(event -> event.kind == DragStartedEvent, events)
        @test any(event -> event.kind == DragEnteredEvent, events)
        @test any(event -> event.kind == DragDroppedEvent, events)
        @test isempty(take_drag_events!(manager))

        update_drop_target!(manager, :table, ComponentRect(5, 5, 4, 4); enabled=false)
        begin_drag_candidate!(manager, :source, payload, DragPoint(5, 5))
        update_drag!(manager, DragPoint(6, 6))
        rejected = drop_drag!(manager, DragPoint(6, 6))
        @test !rejected.accepted
        @test rejected.effect == NoDragEffect
        unregister_drop_target!(manager, :table)

        cancel_manager = DragDropManager(threshold=0)
        register_drop_target!(
            cancel_manager,
            DropTarget(:bin, ComponentRect(1, 1, 3, 3); accepted_mime_prefixes=("text/",)),
        )
        begin_drag_candidate!(cancel_manager, :source, payload, DragPoint(1, 1))
        update_drag!(cancel_manager, DragPoint(2, 2))
        cancel_drag!(cancel_manager)
        @test cancel_manager.phase == DragCancelled
        @test any(event -> event.kind == DragCancelledEvent, take_drag_events!(cancel_manager))

        routed_messages = DragEventKind[]
        router = ToolkitDragRouter(message_mapper=event -> event.kind)
        register_toolkit_drop_target!(
            router,
            :drop_zone,
            ComponentRect(1, 1, 4, 10),
            result -> (:dropped, result.target_id, result.payload.value);
            accepted_mime_prefixes=("text/",),
            accepted_effects=(CopyDragEffect,),
            preferred_effect=CopyDragEffect,
        )
        begin_toolkit_drag!(router, :source, DragPayload("payload"; mime="text/plain"), DragPoint(1, 1))
        @test update_toolkit_drag!(router, DragPoint(2, 2))
        dispatch = route_toolkit_drag_events!(router)
        @test dispatch isa ToolkitDragDispatch
        @test isempty(dispatch.errors)
        append!(routed_messages, dispatch.messages)
        drop_result, message = drop_toolkit_drag!(router, DragPoint(2, 2))
        @test drop_result.accepted
        @test message == (:dropped, "drop_zone", "payload")
        dispatch = route_toolkit_drag_events!(router)
        append!(routed_messages, dispatch.messages)
        @test DragDroppedEvent in routed_messages

        sync_toolkit_drop_target!(router, :drop_zone, ComponentRect(2, 2, 4, 10); enabled=false)
        begin_toolkit_drag!(router, :source, DragPayload("payload"; mime="text/plain"), DragPoint(1, 1))
        update_toolkit_drag!(router, DragPoint(3, 3))
        disabled_result, disabled_message = drop_toolkit_drag!(router, DragPoint(3, 3))
        @test !disabled_result.accepted
        @test disabled_message === nothing
        cancel_toolkit_drag!(router)
        unregister_toolkit_drop_target!(router, :drop_zone)

        mouse_point = drag_point_from_event(MouseEvent(Position(2, 3), LeftMouseButton, MouseDrag))
        @test mouse_point == DragPoint(2, 3)
    end

    @testset "stable clipboard services and editor integration" begin
        provider = MemoryClipboard()
        policy = ClipboardPolicy(maximum_bytes=128)
        content = ClipboardContent("hello"; created_ns=1_000)

        @test write_clipboard!(provider, content; policy) === provider
        @test clipboard_available(provider)
        @test clipboard_text(read_clipboard(provider; policy, now_ns=1_000)) == "hello"
        @test clear_clipboard!(provider) === provider
        @test !clipboard_available(provider)

        @test_throws ClipboardError write_clipboard!(
            provider,
            ClipboardContent(UInt8[1, 2, 3]; mime="application/octet-stream");
            policy,
        )
        binary_policy = ClipboardPolicy(allowed_mime_prefixes=("application/",))
        binary = ClipboardContent(UInt8[1, 2, 3]; mime="application/octet-stream")
        write_clipboard!(provider, binary; policy=binary_policy)
        @test read_clipboard(provider; policy=binary_policy).data == UInt8[1, 2, 3]

        sequence = osc52_sequence(ClipboardContent("hello"); selection=OSC52ClipboardSelection)
        @test sequence == "\e]52;c;aGVsbG8=\a"
        @test osc52_query(OSC52PrimarySelection; terminator=:st) == "\e]52;p;?\e\\"
        @test clipboard_text(parse_osc52_response(sequence; selection=OSC52ClipboardSelection)) == "hello"

        output = IOBuffer()
        osc52 = OSC52Clipboard(output)
        service = ClipboardService(osc52)
        @test copy_to_clipboard!(service, "copied") === service
        @test occursin("Y29waWVk", String(take!(output)))

        closed = IOBuffer()
        close(closed)
        fallback = MemoryClipboard()
        fallback_service = ClipboardService(OSC52Clipboard(closed); fallback, fallback_on_error=true)
        @test copy_to_clipboard!(fallback_service, "fallback") === fallback_service
        @test clipboard_text(read_clipboard(fallback)) == "fallback"
        @test clipboard_text(paste_from_clipboard(fallback_service)) == "fallback"
        @test clear_clipboard_service!(fallback_service) === fallback_service
        @test !clipboard_available(fallback)

        editor = Dict{Symbol,Any}(:text => "alpha beta", :selection => "beta")
        adapter = TextEditAdapter(
            selection=item -> item[:selection],
            delete_callback=item -> begin
                item[:text] = replace(item[:text], item[:selection] => ""; count=1)
                item[:selection] = ""
                item
            end,
            insert_callback=(item, text) -> begin
                item[:text] *= text
                item
            end,
            editable=item -> true,
        )
        edit_service = ClipboardService(MemoryClipboard())
        copied = copy_edit_selection!(edit_service, adapter, editor)
        @test copied == ClipboardEditResult(:copy, false, 4)
        @test clipboard_text(paste_from_clipboard(edit_service)) == "beta"
        cut = cut_edit_selection!(edit_service, adapter, editor)
        @test cut.changed
        @test editor[:text] == "alpha "
        copy_to_clipboard!(edit_service, " pasted")
        pasted = paste_edit_selection!(edit_service, adapter, editor)
        @test pasted.changed
        @test editor[:text] == "alpha  pasted"

        read_command = ReadClipboardCommand(
            edit_service;
            id=:read,
            on_success=content -> clipboard_text(content),
        )
        write_command = WriteClipboardCommand(edit_service, "runtime"; id=:write)
        clear_command = ClearClipboardCommand(edit_service; id=:clear)
        @test read_command isa AbstractClipboardCommand
        @test write_command isa AbstractClipboardCommand
        @test clear_command isa AbstractClipboardCommand
    end

    @testset "stable graphics protocols and frame layer" begin
        source = RasterImage(
            2,
            2,
            RGBA32,
            UInt8[
                0xff, 0x00, 0x00, 0xff,
                0x00, 0xff, 0x00, 0xff,
                0x00, 0x00, 0xff, 0xff,
                0xff, 0xff, 0x00, 0xff,
            ],
        )
        gray = RasterImage(1, 1, Gray8, UInt8[0x7f])
        encoded = EncodedImage(UInt8[0x89, 0x50, 0x4e, 0x47], "image/png"; pixel_width=1, pixel_height=1)
        sixel_payload = SixelPayload("\ePq#0\e\\")

        capabilities = detect_graphics_capabilities(environment=Dict("WICKED_GRAPHICS" => "kitty,sixel"))
        @test KittyGraphics in capabilities.protocols
        @test SixelGraphics in capabilities.protocols
        @test UnicodeGraphics in capabilities.protocols
        @test length(graphics_queries()) == 3
        @test select_graphics_protocol(capabilities, source; preferred=KittyGraphics) == KittyGraphics
        @test_throws GraphicsError select_graphics_protocol(
            GraphicsCapabilities([UnicodeGraphics]),
            source;
            preferred=KittyGraphics,
        )

        placement = ImagePlacement(2, 1; id=7, z_index=3, scaling=FitImage, preserve_cursor=false)
        kitty = encode_graphics(source, placement, GraphicsCapabilities([KittyGraphics]; max_chunk_bytes=8); preferred=KittyGraphics)
        @test kitty isa GraphicsCommand
        @test kitty.protocol == KittyGraphics
        @test !isempty(kitty.sequences)
        @test all(startswith(sequence, "\e_G") for sequence in kitty.sequences)

        encoded_kitty = encode_graphics(
            encoded,
            ImagePlacement(1, 1; id=8),
            GraphicsCapabilities([KittyGraphics]);
            preferred=KittyGraphics,
        )
        @test encoded_kitty.protocol == KittyGraphics

        sixel = encode_graphics(source, ImagePlacement(2, 1), GraphicsCapabilities([SixelGraphics]); preferred=SixelGraphics)
        @test sixel.protocol == SixelGraphics
        @test !isempty(sixel.sequences)
        @test encode_graphics(
            sixel_payload,
            ImagePlacement(1, 1),
            GraphicsCapabilities([SixelGraphics]);
            preferred=SixelGraphics,
        ).protocol == SixelGraphics

        unicode = encode_graphics(source, ImagePlacement(2, 1), GraphicsCapabilities([UnicodeGraphics]); preferred=UnicodeGraphics)
        @test unicode.protocol == UnicodeGraphics
        @test isempty(unicode.sequences)
        fallback = unicode_fallback(source, 2, 1)
        @test size(fallback) == (1, 2)
        @test fallback[1, 1] isa FallbackCell
        @test delete_graphics(KittyGraphics, 7).protocol == KittyGraphics
        @test isempty(delete_graphics(SixelGraphics, 7).sequences)

        registry = ImageRegistry(first_id=10)
        first = register_image!(registry, source)
        second = register_image!(registry, source)
        @test first.id == 10
        @test second.id == first.id
        @test second.references == 2
        @test image_id(registry, source) == first.id
        @test release_image!(registry, first.id)
        @test image_id(registry, source) == first.id
        @test release_image!(registry, first.id)
        @test image_id(registry, source) === nothing
        @test clear_images!(registry) === registry

        animation = TerminalAnimation(
            [AnimationFrame(source, 10), AnimationFrame(gray, 20)];
            playing=true,
            looping=false,
        )
        @test current_frame(animation).duration_ms == 10
        @test advance_animation!(animation, 10)
        @test current_frame(animation).duration_ms == 20
        @test pause!(animation) === animation
        @test !advance_animation!(animation, 20)
        @test play!(animation) === animation
        @test advance_animation!(animation, 20)
        @test !animation.playing
        @test reset_animation!(animation) === animation
        @test current_frame(animation).duration_ms == 10

        layer = GraphicsLayer(GraphicsCapabilities([UnicodeGraphics]))
        sink = TestGraphicsSink()
        @test begin_graphics_frame!(layer) === layer
        emission = queue_graphic!(layer, :hero, source, 1, 1, 2, 1)
        @test emission isa GraphicsEmission
        @test emission.position == GraphicsPosition(1, 1)
        @test emission.fallback !== nothing
        result = end_graphics_frame!(layer, sink)
        @test result isa GraphicsFrameResult
        @test result.emitted == 1
        @test result.deleted == 0
        @test result.active == 1
        @test length(sink.emissions) == 1
        @test !isempty(graphics_snapshot(sink))

        begin_graphics_frame!(layer)
        repeat_emission = queue_graphic!(layer, :hero, source, 1, 1, 2, 1)
        @test repeat_emission.image.id == emission.image.id
        repeated = end_graphics_frame!(layer, sink)
        @test repeated.emitted == 0
        @test repeated.active == 1

        begin_graphics_frame!(layer)
        removed = end_graphics_frame!(layer, sink)
        @test removed.deleted == 1
        @test removed.active == 0
        @test !isempty(sink.clears)
        @test reset_graphics_sink!(sink) === sink
        @test isempty(sink.emissions)
        @test isempty(sink.deletions)
        @test isempty(sink.clears)
        @test clear_graphics!(layer, sink) === layer
    end

    @testset "stable data-entry control contracts" begin
        import Dates

        option = ChoiceOption(:alpha, "Alpha"; disabled=true, style=Style(modifiers=BOLD))
        @test option.value == :alpha
        @test only(option.label.spans).content == "Alpha"
        @test option.disabled

        radio = RadioGroup([
            ChoiceOption(:one, "One"),
            ChoiceOption(:two, "Two"; disabled=true),
            :three => "Three",
        ])
        @test selected_value(radio, RadioGroupState(selected=1)) == :one
        @test selected_value(radio, RadioGroupState(selected=2)) === nothing
        @test selected_value(radio, RadioGroupState(selected=3)) == :three

        select = Select([:a => "A", :b => "B"])
        @test selected_value(select, SelectState(selected=2)) == :b

        multiselect = MultiSelect([
            ChoiceOption(:a, "A"),
            ChoiceOption(:b, "B"; disabled=true),
            ChoiceOption(:c, "C"),
        ])
        @test selected_values(multiselect, MultiSelectState(selected=[1, 2, 3])) == [:a, :c]

        @test ValidationStatus <: Enum
        @test Unvalidated isa ValidationStatus
        @test Validating isa ValidationStatus
        @test ValidField isa ValidationStatus
        @test WrapMode <: Enum
        @test NoWrap isa WrapMode
        @test CharacterWrap isa WrapMode
        @test WordWrap isa WrapMode
        @test LayoutDirection <: Enum
        @test RectSplitDirection <: Enum
        @test RowSplit isa RectSplitDirection
        @test ColumnSplit isa RectSplitDirection
        @test RuleDirection <: Enum
        @test VerticalRule isa RuleDirection
        @test Divider() isa Divider
        @test register_divider_semantic_handlers! isa Function
        @test DataViewStatus <: Enum
        @test DataReady isa DataViewStatus
        @test DataLoading isa DataViewStatus
        @test DataEmpty isa DataViewStatus
        @test DataError isa DataViewStatus
        data_state_view = DataStateView(PropertyList(["status" => "ready"]); status=DataLoading)
        @test data_state_view isa DataStateView
        @test data_state_status(data_state_view) == DataLoading
        @test data_state_loading(data_state_view)
        @test register_data_state_view_semantic_handlers! isa Function
        query_source = QueryDataSource([(name="build", status="ready")]; query=DataQuery(search="build"))
        @test query_source isa QueryDataSource
        @test query_data_source(query_source).search == "build"
        @test data_query_summary(query_data_source(query_source)).has_search
        @test occursin("search", data_query_text(query_data_source(query_source)))
        @test startswith(data_query_markdown(query_data_source(query_source)), "| field | value |")
        @test startswith(data_query_tsv(query_data_source(query_source)), "kind\tcolumn")
        query_copy = query_data_source(query_source)
        query_copy.filters[:status] = "mutated"
        @test query_data_source(query_source).search == "build"
        @test !haskey(query_data_source(query_source).filters, :status)
        @test set_query_search!(query_source, "ready") === query_source
        @test set_query_filter!(query_source, :status, "ready") === query_source
        @test clear_query_filter!(query_source, :status) === query_source
        @test set_query_filter!(query_source, :status, query_equals("ready")) === query_source
        @test query_equals("ready") isa EqualsFilter
        @test query_contains("build") isa ContainsFilter
        @test query_range(minimum="a", maximum="z") isa RangeFilter
        @test query_regex(r"build") isa RegexFilter
        @test toggle_query_sort!(query_source, :name) === query_source
        @test clear_query!(query_source) === query_source
        table_query_state = TableLayoutState([VirtualTableColumn(:name, "Name")])
        set_virtual_search!(table_query_state, "build")
        @test apply_virtual_table_query!(query_source, table_query_state) === query_source
        @test query_data_source(query_source).search == "build"
        @test table_layout_snapshot(table_query_state).search == "build"
        @test restore_table_layout!(table_query_state, table_layout_snapshot(table_query_state)) === table_query_state
        visibility_state = ColumnVisibilityState(hidden=[:name])
        @test visibility_state isa ColumnVisibilityState
        @test column_visibility_snapshot(visibility_state).hidden == [:name]
        @test restore_column_visibility!(visibility_state, column_visibility_snapshot(visibility_state)) === visibility_state
        @test hide_virtual_column!(visibility_state, :status) === visibility_state
        @test show_virtual_column!(visibility_state, :name) === visibility_state
        @test toggle_virtual_column_visibility!(visibility_state, :status) === visibility_state
        @test virtual_column_visible(visibility_state, :status)
        @test visible_virtual_columns([VirtualTableColumn(:name, "Name")], visibility_state) isa Vector{VirtualTableColumn}
        @test apply_virtual_column_visibility([VirtualTableColumn(:name, "Name")], table_query_state, visibility_state) isa Vector{VirtualTableColumn}
        pin_state = ColumnPinState(left=[:name])
        @test pin_state isa ColumnPinState
        @test pin_virtual_column_right!(pin_state, :status) === pin_state
        @test virtual_column_pin_position(pin_state, :status) == :right
        @test column_pin_snapshot(pin_state).left == [:name]
        @test restore_column_pin!(pin_state, column_pin_snapshot(pin_state)) === pin_state
        @test pinned_virtual_columns([VirtualTableColumn(:name, "Name"), VirtualTableColumn(:status, "Status")], pin_state) isa Vector{VirtualTableColumn}
        @test apply_virtual_column_pinning([VirtualTableColumn(:name, "Name"), VirtualTableColumn(:status, "Status")], table_query_state, pin_state) isa Vector{VirtualTableColumn}
        @test toggle_virtual_column_pin!(pin_state, :status; side=:right) === pin_state
        @test unpin_virtual_column!(pin_state, :name) === pin_state
        column_actions = default_virtual_column_actions()
        @test first(column_actions) isa VirtualColumnAction
        @test virtual_column_action_enabled(first(column_actions), :name, table_query_state; visibility=visibility_state, pinning=pin_state)
        @test virtual_column_action_menu(column_actions, :name, table_query_state; visibility=visibility_state, pinning=pin_state) isa Vector{VirtualColumnAction}
        @test first(virtual_column_action_records(column_actions, :name, table_query_state; visibility=visibility_state, pinning=pin_state)).column == :name
        @test virtual_column_action_for_shortcut(column_actions, "s", :name, table_query_state; visibility=visibility_state, pinning=pin_state).id == :sort
        column_result = invoke_virtual_column_action(column_actions, :sort, :name, table_query_state; visibility=visibility_state, pinning=pin_state)
        @test column_result isa VirtualColumnActionResult
        @test virtual_column_action_summary(column_result).column == :name
        @test occursin("column name", virtual_column_action_text(column_result))
        @test startswith(virtual_column_action_markdown(column_result), "| field | value |")
        @test startswith(virtual_column_action_tsv(column_result), "action\tlabel")
        @test invoke_virtual_column_action_shortcut(column_actions, "s", :name, table_query_state; visibility=visibility_state, pinning=pin_state) isa VirtualColumnActionResult
        @test invoke_virtual_column_action(column_actions, :pin_left, :status, table_query_state; visibility=visibility_state, pinning=pin_state).handled
        @test invoke_virtual_column_action(column_actions, :unpin, :status, table_query_state; visibility=visibility_state, pinning=pin_state).handled
        table_diagnostics_bundle = table_preferences_bundle(table_query_state; visibility=visibility_state, pinning=pin_state, column_actions)
        @test table_preferences_summary(table_diagnostics_bundle).column_action_count == length(column_actions)
        @test occursin("columns", table_preferences_text(table_diagnostics_bundle))
        @test startswith(table_preferences_markdown(table_diagnostics_bundle), "| field | value |")
        @test startswith(table_preferences_tsv(table_diagnostics_bundle), "field\tvalue")
        batch_rows = [(name="build", status="ready"), (name="test", status="queued")]
        batch_actions = [VirtualRowAction(:retry, "Retry"; enabled=row -> row.status == "queued", shortcut="r")]
        @test virtual_row_action_for_shortcut(batch_actions, "r", batch_rows[2], 2; key=:test).id == :retry
        @test invoke_virtual_row_action_shortcut(batch_actions, "r", batch_rows[2], 2; key=:test) isa VirtualRowActionResult
        batch_result = invoke_virtual_row_action_batch(batch_actions, :retry, batch_rows; indices=[1, 2], keys=[:build, :test])
        @test batch_result isa VirtualRowActionBatchResult
        @test batch_result.requested == 2
        @test batch_result.handled == 1
        @test first(virtual_row_action_batch_records(batch_result)).handled == false
        @test virtual_row_action_batch_summary(batch_result).disabled == 1
        @test occursin("handled", virtual_row_action_batch_text(batch_result))
        @test startswith(virtual_row_action_batch_markdown(batch_result), "| field | value |")
        @test startswith(virtual_row_action_batch_tsv(batch_result), "index\tkey")
        preference_bundle = table_preferences_bundle(table_query_state; visibility=visibility_state, pinning=pin_state, column_actions)
        @test preference_bundle.query.search == "build"
        @test restore_table_preferences!(table_query_state, preference_bundle; visibility=visibility_state, pinning=pin_state).layout === table_query_state
        @test apply_table_preferences([VirtualTableColumn(:name, "Name")], table_query_state; visibility=visibility_state, pinning=pin_state) isa Vector{VirtualTableColumn}
        table_selection_state = VirtualListState{Symbol}(first_index=1, viewport_size=5, multiple=true)
        table_selection_state.cursor = 2
        push!(table_selection_state.selected, :build)
        selection_snapshot = virtual_selection_snapshot(table_selection_state)
        @test selection_snapshot.cursor == 2
        @test restore_virtual_selection!(table_selection_state, selection_snapshot) === table_selection_state
        selection_rows = [(name="build", status="ready"), (name="test", status="queued")]
        selection_columns = [VirtualTableColumn(:name, "Name"; accessor=row -> row.name)]
        selection_table = VirtualTable(selection_rows, selection_columns; height=2)
        selection_table_state = state_for(selection_table)
        selection_table_state.rows.cursor = 1
        push!(selection_table_state.rows.selected, 1)
        @test first(virtual_selected_row_records(selection_table, selection_table_state)).cell_values[:name] == "build"
        @test virtual_selected_row_snapshot(selection_table, selection_table_state).count == 1
        range_selection = begin_virtual_range_selection(selection_table_state.rows, 2)
        @test [row.index for row in virtual_range_selected_row_records(selection_table, selection_table_state, range_selection)] == [1, 2]
        @test virtual_range_selected_row_snapshot(selection_table, selection_table_state, range_selection).expected == 2
        range_actions = [VirtualRowAction(:inspect, "Inspect"; handler=(row, index, key) -> row.name)]
        @test invoke_virtual_range_row_action_batch(range_actions, :inspect, selection_table, selection_table_state, range_selection).handled == 2
        edit_state = VirtualCellEditState()
        @test begin_virtual_cell_edit!(edit_state, 2, :status; key=:build, value="ready") === edit_state
        @test update_virtual_cell_edit!(edit_state, "done"; validator=value -> (!isempty(value), nothing)) === edit_state
        @test virtual_cell_edit_snapshot(edit_state).draft == "done"
        @test restore_virtual_cell_edit!(edit_state, virtual_cell_edit_snapshot(edit_state)) === edit_state
        edit_commit = commit_virtual_cell_edit!(edit_state)
        @test edit_commit isa VirtualCellEditResult
        @test apply_virtual_cell_edit((status="ready",), edit_commit).status == "done"
        mutable_row = Dict(:status => "ready")
        @test apply_virtual_cell_edit!(mutable_row, edit_commit)[:status] == "done"
        edit_history = VirtualCellEditHistory()
        @test record_virtual_cell_edit!(edit_history, edit_commit) === edit_history
        @test virtual_cell_edit_history_snapshot(edit_history).limit == 100
        @test restore_virtual_cell_edit_history!(edit_history, virtual_cell_edit_history_snapshot(edit_history)) === edit_history
        undo_edit = undo_virtual_cell_edit!(edit_history)
        @test undo_edit.value == "ready"
        redo_edit = redo_virtual_cell_edit!(edit_history)
        @test redo_edit.value == "done"
        begin_virtual_cell_edit!(edit_state, 2, :status; key=:build, value="ready")
        @test !cancel_virtual_cell_edit!(edit_state).committed
        @test register_virtual_cell_edit_semantic_handlers! isa Function
        @test register_virtual_column_action_semantic_handlers! isa Function
        @test register_virtual_row_action_batch_semantic_handlers! isa Function
        stable_row_action = VirtualRowAction(:open, "Open"; shortcut=:enter)
        @test stable_row_action isa VirtualRowAction
        @test stable_row_action.shortcut == "enter"
        @test virtual_row_action_menu([stable_row_action], (name="build",), 1) isa Vector{VirtualRowAction}
        @test first(virtual_row_action_records([stable_row_action], (name="build",), 1)).id == :open
        @test invoke_virtual_row_action(stable_row_action, (name="build",), 1).handled
        @test register_virtual_row_action_semantic_handlers! isa Function
        @test KeyValueList(["key" => "value"]) isa KeyValueList
        @test KeyValueListState === PropertyListState
        @test register_key_value_list_semantic_handlers! isa Function
        @test MetadataList(["key" => "value"]) isa MetadataList
        @test MetadataListState === KeyValueListState
        @test register_metadata_list_semantic_handlers! isa Function
        @test DefinitionList(["term" => "definition"]) isa DefinitionList
        @test DefinitionListState === DescriptionListState
        @test register_definition_list_semantic_handlers! isa Function

        bar = Bar("CPU", 0.75)
        @test bar.label == "CPU"
        @test bar.value == 0.75
        @test BarChart([bar]) isa BarChart

        log = LogState(2)
        @test push_log!(log, "starting"; level=:info, timestamp_ns=1) === log
        @test push_log!(log, "warning"; level=:warning, timestamp_ns=2) === log
        @test length(log.entries) == 2
        @test clear_log!(log) === log
        @test isempty(log.entries)

        rich_widget = rich_paragraph_widget(
            ToolkitElementAdapter(),
            [RichLine(RichSpan[RichSpan("hello", :text, nothing)], :text, nothing)],
        )
        @test rich_widget isa Paragraph

        @test sprint(showerror, BufferAssertionError("buffer mismatch")) == "buffer mismatch"

        menu = Menu([
            MenuItem(:open, "Open", :open),
            MenuItem(:disabled, "Disabled", :disabled; disabled=true),
        ])
        @test selected_item(menu, MenuState(selected=1)).message == :open
        @test selected_item(menu, MenuState(selected=2)) === nothing
        menu_state = MenuState()
        @test select_next_menu_item!(menu_state, menu) === menu_state
        @test selected_menu_item(menu, menu_state).message == :open
        @test selected_menu_message(menu, menu_state) == :open
        @test select_previous_menu_item!(menu_state, menu) === menu_state
        @test selected_menu_item(menu, menu_state).message == :open
        @test select_menu_item!(menu_state, menu, 2) === menu_state
        @test selected_menu_item(menu, menu_state) === nothing
        @test register_menu_semantic_handlers! isa Function

        rail = NavigationRail([
            MenuItem(:home, "Home", :home),
            MenuItem(:settings, "Settings", :settings),
        ])
        rail_state = NavigationRailState()
        @test selected_navigation_item(rail, rail_state).message == :home
        @test select_next_navigation_item!(rail_state, rail) === rail_state
        @test selected_navigation_message(rail, rail_state) == :settings
        @test select_previous_navigation_item!(rail_state, rail) === rail_state
        @test selected_navigation_item(rail, rail_state).message == :home
        @test select_navigation_item!(rail_state, rail, 2) === rail_state
        @test selected_navigation_message(rail, rail_state) == :settings
        @test register_navigation_rail_semantic_handlers! isa Function

        tabs = Tabs([Tab(:one, "One"), Tab(:two, "Two")])
        tabs_state = TabsState()
        @test selected_tab(tabs, tabs_state).id == :one
        @test select_next_tab!(tabs_state, tabs) === tabs_state
        @test selected_tab(tabs, tabs_state).id == :two
        @test select_previous_tab!(tabs_state, tabs) === tabs_state
        @test selected_tab(tabs, tabs_state).id == :one
        @test select_tab!(tabs_state, tabs, 2) === tabs_state
        @test selected_tab(tabs, tabs_state).id == :two
        @test register_tabs_semantic_handlers! isa Function
        tab_view = TabView([:one => "One", :two => "Two"], [Label("one"), Label("two")])
        tab_view_state = TabViewState()
        @test selected_tab_view(tab_view, tab_view_state).id == :one
        @test selected_tab_view_content(tab_view, tab_view_state) isa Label
        @test select_next_tab_view!(tab_view_state, tab_view) === tab_view_state
        @test selected_tab_view(tab_view, tab_view_state).id == :two
        @test select_previous_tab_view!(tab_view_state, tab_view) === tab_view_state
        @test selected_tab_view(tab_view, tab_view_state).id == :one
        @test select_tab_view!(tab_view_state, tab_view, 2) === tab_view_state
        @test selected_tab_view(tab_view, tab_view_state).id == :two
        @test register_tab_view_semantic_handlers! isa Function

        carousel = CarouselState(["alpha", "beta", "gamma"]; index=2)
        @test carousel_item(carousel) == "beta"
        @test carousel_window(carousel, 2) == ["beta", "gamma"]
        @test next_carousel!(carousel) === carousel
        @test carousel_item(carousel) == "gamma"
        @test previous_carousel!(carousel) === carousel
        @test carousel_item(carousel) == "beta"
        @test set_carousel_index!(carousel, 4) === carousel
        @test carousel_item(carousel) == "alpha"
        @test register_carousel_semantic_handlers! isa Function

        timeline = TimelineState([
            TimelineItem("Queued", :queued),
            TimelineItem("Running", :running; detail="worker", status=TimelineActive),
        ])
        @test move_timeline_focus!(timeline, 1) === timeline
        @test timeline.focused == 2
        @test !isempty(render_timeline(timeline; width=24))
        @test timeline_semantic_tree(timeline; id="build").root.id == "build"
        @test register_timeline_semantic_handlers! isa Function

        skeleton = SkeletonState(period=4)
        @test length(render_skeleton(skeleton, 8, 2; highlight_width=2)) == 2

        empty = EmptyState("Nothing here"; message="Create an item", action_label="New")
        @test length(render_empty_state(empty)) == 3

        @test occursin("status", pretty_text(Pretty((status=:ready, count=1)); height=4, width=40))

        digits_node = digits_semantic_node(Digits("42"); id="digits")
        @test digits_node.id == "digits"
        @test digits_node.role == StatusRole
        @test digits_node.state.value == "42"

        pretty_node = pretty_semantic_node(Pretty((status=:ready, count=1)); id="pretty")
        @test pretty_node.id == "pretty"
        @test occursin("status", pretty_node.state.value)

        link_node = link_semantic_node(Link("Docs", :open_docs), LinkState(focused=true); id="docs")
        @test link_node.id == "docs"
        @test link_node.role == LinkRole
        @test link_node.state.focused
        @test link_node.metadata[:target] == :open_docs
        @test register_link_semantic_handlers! isa Function
        @test register_hyperlink_semantic_handlers! isa Function

        split_node = navigation_control_semantic_node(SplitPaneState(fraction=0.25), "split")
        @test split_node.id == "split"
        @test split_node.role == GroupRole
        @test split_node.state.value_now == 0.25

        drawer_node = navigation_control_semantic_node(DrawerState(open=true), "drawer")
        @test drawer_node.id == "drawer"
        @test drawer_node.state.expanded

        empty_node = navigation_control_semantic_node(empty, "empty")
        @test empty_node.id == "empty"
        @test empty_node.role == StatusRole
        @test only(empty_node.children).role == ButtonRole

        first_child = leaf(Label("First"); id="first")
        second_child = leaf(Label("Second"); id="second")
        row_element = row(first_child, second_child; id="row", constraints=[Length(1), Fill(1)], gap=1)
        @test row_element.id == "row"
        @test row_element.layout isa FlexLayout
        @test length(row_element.children) == 2

        column_element = column(first_child; id="column", constraints=[Fill(1)])
        @test column_element.id == "column"
        @test column_element.layout isa FlexLayout
        @test length(column_element.children) == 1

        grid_element = grid(first_child, second_child; id="grid", rows=[Length(1)], columns=[Fill(1), Fill(1)])
        @test grid_element.id == "grid"
        @test grid_element.layout isa GridLayout
        @test length(grid_element.children) == 2

        stack_element = stack(first_child, second_child; id="stack")
        @test stack_element.id == "stack"
        @test stack_element.layout == :stack
        @test length(stack_element.children) == 2

        centered_element = centered(first_child; id="centered", height=1, width=10)
        @test centered_element.id == "centered"
        @test centered_element.layout.size == Size(1, 10)
        @test only(centered_element.children).id == "first"

        tree = ToolkitTree(row(first_child; id="root", constraints=[Fill(1)]))
        buffer = Buffer(1, 12)
        render!(buffer, tree, buffer.area)
        instance = element_instance(tree, "first")
        @test instance isa ElementInstance
        @test instance.element.id == "first"
        @test instance.area isa Rect
        @test instance.mounted
        @test element_state(tree, "first") === instance.state

        routed = RoutedEvent(KeyEvent(Key(:enter)), :target, :current, TargetPhase)
        @test routed.event isa KeyEvent
        @test routed.target == :target
        @test routed.current == :current
        @test routed.phase == TargetPhase
        @test BubblePhase isa EventPhase

        response = EventResponse(consumed=true, stop_propagation=true, message=:activated, focus=:next)
        @test response.consumed
        @test response.stop_propagation
        @test response.redraw
        @test response.message == :activated
        @test response.focus == :next

        focus_first = Element(
            Button("First", :first);
            id=:focus_first,
            key=:focus_first,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :enter || return nothing
                return EventResponse(consumed=true, focus=:next)
            end,
        )
        focus_second = Element(
            Button("Second", :second);
            id=:focus_second,
            key=:focus_second,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :left || return nothing
                return EventResponse(consumed=true, focus=:left)
            end,
        )
        focus_tree = ToolkitTree(row(focus_first, focus_second; constraints=[Fill(1), Fill(1)]))
        render!(Buffer(1, 24), focus_tree, Rect(1, 1, 1, 24))
        @test focus!(focus_tree.state.focus, :focus_first)
        @test dispatch!(focus_tree, KeyEvent(Key(:enter))).consumed
        @test focused(focus_tree.state.focus) == :focus_second
        directional_dispatch = dispatch!(focus_tree, KeyEvent(Key(:left)))
        @test directional_dispatch.consumed
        @test directional_dispatch.redraw
        @test focused(focus_tree.state.focus) == :focus_first

        focus_only = Element(
            Button("Focus only", :focus_only);
            id=:focus_only,
            key=:focus_only,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :enter || return nothing
                return EventResponse(focus=:next)
            end,
        )
        focus_target = Element(
            Button("Target", :focus_target);
            id=:focus_target,
            key=:focus_target,
            focusable=true,
        )
        focus_only_tree = ToolkitTree(row(focus_only, focus_target; constraints=[Fill(1), Fill(1)]))
        render!(Buffer(1, 24), focus_only_tree, Rect(1, 1, 1, 24))
        @test focus!(focus_only_tree.state.focus, :focus_only)
        focus_only_dispatch = dispatch!(focus_only_tree, KeyEvent(Key(:enter)))
        @test !focus_only_dispatch.consumed
        @test focus_only_dispatch.redraw
        @test focused(focus_only_tree.state.focus) == :focus_target

        stable_focus = Element(
            Button("Stable focus", :stable_focus);
            id=:stable_focus,
            key=:stable_focus,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :enter || return nothing
                return EventResponse(focus=:next)
            end,
        )
        stable_focus_tree = ToolkitTree(row(stable_focus; constraints=[Fill(1)]))
        render!(Buffer(1, 12), stable_focus_tree, Rect(1, 1, 1, 12))
        @test focus!(stable_focus_tree.state.focus, :stable_focus)
        stable_focus_dispatch = dispatch!(stable_focus_tree, KeyEvent(Key(:enter)))
        @test !stable_focus_dispatch.consumed
        @test !stable_focus_dispatch.redraw
        @test focused(stable_focus_tree.state.focus) == :stable_focus

        tab_focus_source = Element(
            Button("Tab source", :tab_focus_source);
            id=:tab_focus_source,
            key=:tab_focus_source,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :tab || return nothing
                return EventResponse(focus=:next)
            end,
        )
        tab_focus_middle = Element(
            Button("Tab middle", :tab_focus_middle);
            id=:tab_focus_middle,
            key=:tab_focus_middle,
            focusable=true,
        )
        tab_focus_end = Element(
            Button("Tab end", :tab_focus_end);
            id=:tab_focus_end,
            key=:tab_focus_end,
            focusable=true,
        )
        tab_focus_tree = ToolkitTree(row(tab_focus_source, tab_focus_middle, tab_focus_end; constraints=[Fill(1), Fill(1), Fill(1)]))
        render!(Buffer(1, 36), tab_focus_tree, Rect(1, 1, 1, 36))
        @test focus!(tab_focus_tree.state.focus, :tab_focus_source)
        tab_focus_dispatch = dispatch!(tab_focus_tree, KeyEvent(Key(:tab)))
        @test !tab_focus_dispatch.consumed
        @test tab_focus_dispatch.redraw
        @test focused(tab_focus_tree.state.focus) == :tab_focus_middle

        first_last_source = Element(
            Button("First last source", :first_last_source);
            id=:first_last_source,
            key=:first_last_source,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :end || return nothing
                return EventResponse(focus=:last)
            end,
        )
        first_last_middle = Element(
            Button("First last middle", :first_last_middle);
            id=:first_last_middle,
            key=:first_last_middle,
            focusable=true,
        )
        first_last_end = Element(
            Button("First last end", :first_last_end);
            id=:first_last_end,
            key=:first_last_end,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :home || return nothing
                return EventResponse(focus=:first)
            end,
        )
        first_last_tree = ToolkitTree(row(first_last_source, first_last_middle, first_last_end; constraints=[Fill(1), Fill(1), Fill(1)]))
        render!(Buffer(1, 36), first_last_tree, Rect(1, 1, 1, 36))
        @test focus!(first_last_tree.state.focus, :first_last_source)
        @test dispatch!(first_last_tree, KeyEvent(Key(:end))).redraw
        @test focused(first_last_tree.state.focus) == :first_last_end
        @test dispatch!(first_last_tree, KeyEvent(Key(:home))).redraw
        @test focused(first_last_tree.state.focus) == :first_last_source

        clear_focus_source = Element(
            Button("Clear focus", :clear_focus_source);
            id=:clear_focus_source,
            key=:clear_focus_source,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :escape || return nothing
                return EventResponse(focus=:clear)
            end,
        )
        clear_focus_tree = ToolkitTree(row(clear_focus_source; constraints=[Fill(1)]))
        render!(Buffer(1, 18), clear_focus_tree, Rect(1, 1, 1, 18))
        @test focus!(clear_focus_tree.state.focus, :clear_focus_source)
        clear_focus_dispatch = dispatch!(clear_focus_tree, KeyEvent(Key(:escape)))
        @test !clear_focus_dispatch.consumed
        @test clear_focus_dispatch.redraw
        @test focused(clear_focus_tree.state.focus) === nothing

        no_focus_command = Element(
            Button("No focus command", :no_focus_command);
            id=:no_focus_command,
            key=:no_focus_command,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :space || return nothing
                return EventResponse(focus=nothing)
            end,
        )
        explicit_none_focus = Element(
            Button("Explicit none", :explicit_none_focus);
            id=:explicit_none_focus,
            key=:explicit_none_focus,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :escape || return nothing
                return EventResponse(focus=:none)
            end,
        )
        none_focus_tree = ToolkitTree(row(no_focus_command, explicit_none_focus; constraints=[Fill(1), Fill(1)]))
        render!(Buffer(1, 30), none_focus_tree, Rect(1, 1, 1, 30))
        @test focus!(none_focus_tree.state.focus, :no_focus_command)
        no_focus_dispatch = dispatch!(none_focus_tree, KeyEvent(Key(:space)))
        @test !no_focus_dispatch.redraw
        @test focused(none_focus_tree.state.focus) == :no_focus_command
        @test focus!(none_focus_tree.state.focus, :explicit_none_focus)
        none_focus_dispatch = dispatch!(none_focus_tree, KeyEvent(Key(:escape)))
        @test none_focus_dispatch.redraw
        @test focused(none_focus_tree.state.focus) === nothing

        dispatch = DispatchResult(true, true, Any[:activated])
        @test dispatch.consumed
        @test dispatch.redraw
        @test dispatch.messages == Any[:activated]

        items = [
            CompletionItem("Alpha", :alpha; detail="first", keywords=["one"]),
            CompletionItem("Beta", :beta; keywords=["two"]),
            CompletionItem("Disabled", :disabled; disabled=true),
        ]
        autocomplete = AutocompleteState(items; max_visible=2, mode=ContainsCompletion)
        @test update_autocomplete!(autocomplete, "a") === autocomplete
        @test autocomplete.open
        @test length(visible_completions(autocomplete)) == 2
        @test visible_completion_range(autocomplete) == 1:2
        @test move_autocomplete!(autocomplete, 1) === autocomplete
        @test accept_autocomplete!(autocomplete) in (:alpha, :beta)
        @test close_autocomplete!(autocomplete) === autocomplete
        @test !autocomplete.open

        combobox = ComboBoxState(items; editable=true, required=true)
        @test set_combobox_query!(combobox, "be") === combobox
        @test move_combobox!(combobox, 1) === combobox
        @test control_error(combobox) == "a selection is required"
        @test accept_combobox!(combobox) == :beta
        @test control_value(combobox) == :beta
        @test control_valid(combobox)
        @test clear_combobox!(combobox) === combobox
        @test control_value(combobox) == :beta

        tags = TagInputState(["julia"]; maximum=2)
        @test add_tag!(tags, "tui")
        @test !add_tag!(tags, "extra")
        @test control_value(tags) == ["julia", "tui"]
        @test remove_tag!(tags, 1) == "julia"
        @test clear_tags!(tags) === tags
        @test isempty(tags.tags)

        numeric = NumericInputState(value=2, minimum=0, maximum=5, step=0.5, allow_empty=false)
        @test numeric_input_valid(numeric)
        @test increment_numeric_input!(numeric, 2) === numeric
        @test numeric.value == 3.0
        @test set_numeric_text!(numeric, "bad"; commit=true) === numeric
        @test !control_valid(numeric)
        @test control_error(numeric) == "invalid numeric value"
        @test set_control_value!(numeric, 4) === numeric
        @test commit_numeric_input!(numeric)
        @test control_value(numeric) == 4.0

        mask = InputMask("##-AA")
        masked = MaskedInputState(mask)
        @test insert_masked_input!(masked, '1')
        @test insert_masked_input!(masked, '2')
        @test insert_masked_input!(masked, 'a')
        @test insert_masked_input!(masked, 'b')
        @test masked_input_complete(masked)
        @test masked_input_text(masked; include_placeholders=false) == "12-ab"
        @test backspace_masked_input!(masked)
        @test delete_masked_input!(masked)
        @test clear_masked_input!(masked) === masked
        @test !masked_input_complete(masked)

        date = DatePickerState(selected=Dates.Date(2026, 1, 15), week_start=1)
        @test size(date_picker_grid(date)) == (6, 7)
        @test move_date_picker!(date, 1) === date
        @test date.selected == Dates.Date(2026, 1, 16)
        @test move_date_picker_month!(date, 1) === date
        @test select_date!(date, Dates.Date(2026, 3, 1)) === date
        @test control_value(date) == Dates.Date(2026, 3, 1)

        time = TimePickerState(value=Dates.Time(12, 0), step_seconds=60)
        @test increment_time_picker!(time, 2) === time
        @test control_value(time) == Dates.Time(12, 2)
        @test set_time_picker!(time, Dates.Time(13, 0)) === time
        @test control_value(time) == Dates.Time(13, 0)

        color = ColorPickerState()
        @test set_color_rgb!(color, 255, 128, 0) === color
        @test color_hex(color) == "#FF8000"
        hue, saturation, value = color_hsv(color.value)
        @test isapprox(hue, 30.11764705882353; atol=0.1)
        @test saturation > 0.49
        @test value == 1.0
        @test set_color_hsv!(color, 120, 1, 1) === color
        @test color_hex(color) == "#00FF00"
        @test set_color_hex!(color, "#336699")
        @test color_hex(color) == "#336699"
        @test register_date_input_semantic_handlers! isa Function
        @test register_date_picker_semantic_handlers! isa Function
        @test register_time_input_semantic_handlers! isa Function
        @test register_time_picker_semantic_handlers! isa Function
        @test register_date_time_input_semantic_handlers! isa Function
        @test register_date_time_picker_semantic_handlers! isa Function
        @test register_color_picker_semantic_handlers! isa Function

        bindings = default_data_entry_bindings()
        @test bindings isa DataEntryBindings
        @test data_entry_action_for_key(bindings, :down) == EntryNext
        @test bind_data_entry_key!(bindings, :j, EntryNext) === bindings
        @test data_entry_action_for_key(bindings, :j) == EntryNext
        @test unbind_data_entry_key!(bindings, :j) === bindings
        result = handle_data_entry_key!(numeric, bindings, :up)
        @test result isa DataEntryActionResult
        @test result.consumed
        @test result.action == EntryPrevious
        @test handle_data_entry_character!(autocomplete, 'a')

        update_autocomplete!(autocomplete, "a")
        @test !isempty(render_autocomplete(autocomplete; width=12))
        @test render_combobox(combobox; width=12) isa RichLine
        @test render_tags(tags; width=12) isa RichLine
        @test render_numeric_input(numeric; width=12) isa RichLine
        @test render_masked_input(masked; width=12) isa RichLine
        @test !isempty(render_date_picker(date; width=20))
        @test render_time_picker(time; width=12) isa RichLine
        @test render_color_picker(color; width=20) isa RichLine

        tree = autocomplete_semantic_tree(autocomplete; id="autocomplete", width=20)
        @test tree.root.id == "autocomplete"
        node = data_entry_semantic_node(numeric, "number")
        @test node.id == "number"
        @test node.state.focusable
    end

    @testset "stable advanced-control contracts" begin
        bindings = default_advanced_control_bindings()
        @test bindings isa AdvancedControlBindings
        @test advanced_control_action_for_key(bindings, :right) == ControlNext
        @test bind_advanced_control_key!(bindings, :l, ControlNext) === bindings
        @test advanced_control_action_for_key(bindings, :l) == ControlNext
        @test unbind_advanced_control_key!(bindings, :l) === bindings
        @test advanced_control_action_for_key(bindings, :l) === nothing

        slider = SliderState(0, 10; value=4, step=2)
        @test slider_fraction(slider) == 0.4
        @test render_slider(slider, 5) == "==#--"
        @test increment_slider!(slider) === slider
        @test slider.value == 6.0
        @test decrement_slider!(slider, 2) === slider
        @test slider.value == 2.0
        slider_result = handle_advanced_control_key!(slider, bindings, :right)
        @test slider_result == AdvancedControlActionResult(true, ControlNext, 4.0)
        @test control_value(slider) == 4.0
        @test set_control_value!(slider, 10) === slider
        @test render_slider_control(slider; length=6) isa RichLine
        @test slider_semantic_node(slider, "slider").state.value_now == 10.0

        range = RangeSliderState(0, 10; lower=2, upper=8, step=1)
        @test render_range_slider(range, 6) == "-[==]-"
        @test switch_range_handle!(range) === range
        @test range.active == UpperRangeHandle
        range_result = handle_advanced_control_key!(range, bindings, :end)
        @test range_result.consumed
        @test range.upper == 10.0
        @test set_control_value!(range, (3, 7)) === range
        @test control_value(range) == (3.0, 7.0)
        @test render_range_slider_control(range; length=6) isa RichLine
        @test length(range_slider_semantic_node(range, "range").children) == 2

        scrollbar = ScrollbarState(100, 10; offset=20)
        metrics = scrollbar_metrics(scrollbar, 10)
        @test metrics.track_length == 10
        @test metrics.thumb_length >= 1
        @test set_scrollbar_offset!(scrollbar, 200) === scrollbar
        @test scrollbar.offset == 90
        @test scroll_scrollbar!(scrollbar, -10) === scrollbar
        @test control_value(scrollbar) == 80
        @test !isempty(render_scrollbar(scrollbar, 8))
        @test !isempty(render_scrollbar_control(scrollbar; length=8))
        @test scrollbar_semantic_node(scrollbar, "scrollbar").state.value_max == 90

        breadcrumbs = BreadcrumbState([
            BreadcrumbItem("Home", :home),
            BreadcrumbItem("Docs", :docs),
        ])
        @test move_breadcrumb_focus!(breadcrumbs, 1) === breadcrumbs
        @test activate_breadcrumb!(breadcrumbs) == :docs
        @test control_value(breadcrumbs) == :docs
        @test occursin("Docs", render_breadcrumbs(breadcrumbs))
        @test render_breadcrumb_control(breadcrumbs) isa RichLine
        @test length(breadcrumb_semantic_tree(breadcrumbs).root.children) == 2
        breadcrumb_widget = Breadcrumb([
            BreadcrumbItem("Home", :home),
            BreadcrumbItem("Docs", :docs),
        ])
        breadcrumb_widget_state = state_for(breadcrumb_widget)
        @test selected_breadcrumb_value(breadcrumb_widget, breadcrumb_widget_state) == :home
        @test select_next_breadcrumb_item!(breadcrumb_widget_state, breadcrumb_widget) === breadcrumb_widget_state
        @test selected_breadcrumb_item(breadcrumb_widget, breadcrumb_widget_state).value == :docs
        @test select_previous_breadcrumb_item!(breadcrumb_widget_state, breadcrumb_widget) === breadcrumb_widget_state
        @test selected_breadcrumb_value(breadcrumb_widget, breadcrumb_widget_state) == :home
        @test select_breadcrumb_item!(breadcrumb_widget_state, breadcrumb_widget, 2) === breadcrumb_widget_state
        @test activate_selected_breadcrumb!(breadcrumb_widget_state, breadcrumb_widget) == :docs
        @test register_breadcrumb_semantic_handlers! isa Function

        collapsible = CollapsibleState()
        @test toggle_collapsible!(collapsible) === collapsible
        @test collapsible.expanded
        @test collapse_collapsible!(collapsible) === collapsible
        @test !collapsible.expanded
        @test expand_collapsible!(collapsible) === collapsible
        @test control_value(collapsible)
        @test render_collapsible_control(collapsible, "Details") isa RichLine
        @test collapsible_semantic_node(collapsible, "details").state.expanded
        @test register_collapsible_semantic_handlers! isa Function

        accordion = AccordionState{Symbol}(expanded=[:a])
        @test toggle_accordion!(accordion, :b) === accordion
        @test :b in accordion.expanded
        @test !(:a in accordion.expanded)
        @test expand_accordion!(accordion, :a) === accordion
        @test :a in accordion.expanded
        @test collapse_accordion!(accordion, :a) === accordion
        @test !(:a in accordion.expanded)
        @test !isempty(render_accordion_control(accordion, [(:a, "A"), (:b, "B")]))
        @test length(accordion_semantic_tree(accordion, [(:a, "A"), (:b, "B")]).root.children) == 2
        @test register_accordion_semantic_handlers! isa Function

        pages = PaginationState(51; page_size=10)
        @test page_count(pages) == 6
        @test page_range(pages) == 1:10
        @test set_page!(pages, 6) === pages
        @test page_range(pages) == 51:51
        @test previous_page!(pages) === pages
        @test next_page!(pages) === pages
        @test set_page_size!(pages, 20) === pages
        @test pages.page == 3
        @test occursin("page 3/3", render_pagination(pages))
        @test render_pagination_control(pages) isa RichLine
        @test pagination_semantic_node(pages, "pages").state.value_now == 3
        @test register_pagination_semantic_handlers! isa Function

        stepper = StepperState(["Prepare" => :prepare, "Build" => :build])
        @test stepper.statuses[1] == ActiveStep
        @test next_step!(stepper) === stepper
        @test stepper.current == 2
        @test previous_step!(stepper) === stepper
        @test complete_step!(stepper) === stepper
        @test fail_step!(stepper) === stepper
        @test skip_step!(stepper) === stepper
        @test occursin("Prepare", render_stepper(stepper))
        @test render_stepper_control(stepper) isa RichLine
        @test stepper_semantic_tree(stepper).root.role == ListRole
        @test register_stepper_semantic_handlers! isa Function

        dialog = DialogState([
            DialogButton("Cancel", :cancel; role=CancelDialogButton),
            DialogButton("Apply", :apply),
        ]; open=true)
        @test open_dialog!(dialog) === dialog
        @test move_dialog_focus!(dialog, 1) === dialog
        @test activate_dialog_button!(dialog) == :apply
        @test !dialog.open
        @test control_value(dialog) == :apply
        @test close_dialog!(open_dialog!(dialog)) === dialog
        @test !dialog.open
        open_dialog!(dialog)
        @test !isempty(render_dialog_control(dialog; title="Confirm", message="Apply changes?"))
        @test dialog_semantic_tree(dialog).root.role == DialogRole
        @test register_dialog_semantic_handlers! isa Function

        stack = ModalStack()
        entry = ModalEntry("confirm", :dialog)
        @test !has_modal(stack)
        @test push_modal!(stack, entry) === stack
        @test has_modal(stack)
        @test top_modal(stack) === entry
        @test handle_advanced_control_key!(stack, bindings, :escape).value === entry
        @test !has_modal(stack)
        @test pop_modal!(stack) === nothing

        @test control_valid(slider)
        @test control_error(slider) === nothing
    end

    @testset "stable diagnostics and instrumentation contracts" begin
        sink = RingTraceSink(2)
        first = trace!(sink, :runtime, :start; metadata=(id=1,))
        second = trace!(sink, :runtime, :tick)
        third = trace!(sink, :runtime, :stop; phase=:end)
        events = trace_events(sink)
        @test first isa TraceEvent
        @test second.sequence == first.sequence + UInt64(1)
        @test length(events) == 2
        @test events[1].sequence == third.sequence - UInt64(1)
        @test events[2].phase == :end
        @test clear_traces!(sink) === sink
        @test isempty(trace_events(sink))
        @test trace!(NullTraceSink(), :runtime, :noop) === nothing
        @test isempty(trace_events(NullTraceSink()))
        @test clear_traces!(NullTraceSink()) === nothing

        span_sink = RingTraceSink(4)
        @test with_trace_span(() -> :ok, span_sink, :test, :span) == :ok
        span_events = trace_events(span_sink)
        @test length(span_events) == 2
        @test span_events[1].phase == :begin
        @test span_events[2].phase == :end
        @test haskey(span_events[2].metadata, :duration_ns)

        metrics = FrameMetrics(4)
        @test record_frame!(metrics, 1_000_000; diff_cells=3, drawn_cells=5) === metrics
        @test record_input!(metrics, 2) === metrics
        @test record_command!(metrics, 3) === metrics
        @test record_dropped_event!(metrics, 1) === metrics
        snapshot = metrics_snapshot(metrics)
        @test snapshot isa MetricsSnapshot
        @test snapshot.frames_total == 1
        @test snapshot.last_diff_cells == 3
        @test snapshot.last_drawn_cells == 5
        @test snapshot.input_events_total == 2
        @test snapshot.commands_total == 3
        @test snapshot.dropped_events_total == 1
        @test snapshot.frames_per_second > 0

        hub = DiagnosticsHub(trace_capacity=8, metrics_window=4)
        started = begin_frame!(hub)
        @test end_frame!(hub, started; diff_cells=2, drawn_cells=4) >= 0
        @test record_input!(hub, KeyEvent(Key(:enter))) === hub
        @test record_command!(hub, :save) === hub
        @test record_dropped_event!(hub, 2) === hub
        hub_snapshot = metrics_snapshot(hub.metrics)
        @test hub_snapshot.frames_total == 1
        @test hub_snapshot.input_events_total == 1
        @test hub_snapshot.commands_total == 1
        @test hub_snapshot.dropped_events_total == 2
        @test !isempty(trace_events(hub.traces))

        inspector = DeveloperInspector(visible=true, max_trace_rows=3)
        @test toggle_inspector!(inspector) === inspector
        @test !inspector.visible
        @test toggle_inspector!(inspector) === inspector
        @test next_panel!(inspector) === inspector
        @test inspector.panel == TracesPanel
        @test previous_panel!(inspector) === inspector
        @test inspector.panel == MetricsPanel
        @test move_selection!(inspector, 5; item_count=3) === inspector
        @test inspector.selected == 3
        captured = capture_inspector(hub; tree=["root"], focus=["input"], styles=["theme"])
        @test captured isa InspectorSnapshot
        @test captured.tree == ["root"]
        @test captured.focus == ["input"]
        @test captured.styles == ["theme"]
        lines = inspector_lines(inspector, captured; width=40, height=4)
        @test !isempty(lines)
        @test occursin("MetricsPanel", lines[1])
        @test inspector_text(inspector, captured; width=40, height=4) == join(lines, '\n')

        disabled = DiagnosticsHub(enabled=false)
        @test disabled.traces isa NullTraceSink
        @test record_input!(disabled, :event) === disabled
        @test metrics_snapshot(disabled.metrics).input_events_total == 1
        @test isempty(trace_events(disabled.traces))

        instrument_hub = DiagnosticsHub(trace_capacity=16, metrics_window=4)
        wrapped = instrumented(:application; hub=instrument_hub)
        @test wrapped isa InstrumentedApp
        @test diagnostics(wrapped) === instrument_hub
        result = instrument_frame!(
            () -> (diff=7, drawn=11),
            instrument_hub;
            diff_cells=value -> value.diff,
            drawn_cells=value -> value.drawn,
        )
        @test result == (diff=7, drawn=11)
        @test metrics_snapshot(instrument_hub.metrics).last_diff_cells == 7
        @test instrument_event!(() -> :handled, instrument_hub, :input) == :handled
        @test instrument_command!(() -> :done, instrument_hub, :command) == :done
        @test instrument_render!(() -> :rendered, instrument_hub) == :rendered
        @test instrument_reconcile!(() -> :reconciled, instrument_hub) == :reconciled
        @test instrument_layout!(() -> :laid_out, instrument_hub) == :laid_out
        @test length(trace_events(instrument_hub.traces)) >= 10
    end

    @testset "stable event tracing and replay contracts" begin
        now = Ref(UInt64(1_000))
        recorder = EventRecorder(
            capacity=2,
            overflow=DropOldestTrace,
            snapshot=payload -> deepcopy(payload),
            clock=() -> (now[] += UInt64(10)),
            metadata=Dict(:suite => "api"),
        )
        payload = Dict(:value => 1)
        first_entry = record_trace!(recorder, :input, payload; source=:terminal, correlation=:a)
        payload[:value] = 2
        second_entry = record_checkpoint!(recorder, :after_input, payload)
        third_entry = record_trace!(recorder, :message, :saved; timestamp_ns=now[] + UInt64(10))
        @test first_entry isa TraceEntry
        @test second_entry.sequence == first_entry.sequence + UInt64(1)
        @test third_entry.sequence == second_entry.sequence + UInt64(1)
        @test trace_length(recorder) == 2
        @test trace_dropped_count(recorder) == 1
        entries = trace_entries(recorder)
        @test entries[1].kind == :checkpoint
        @test entries[1].payload[:value] == 2
        @test isempty(trace_errors(recorder))
        snapshot = trace_snapshot(recorder; ended_ns=now[] + UInt64(20))
        @test snapshot isa EventTrace
        @test trace_length(snapshot) == 2
        @test trace_dropped_count(snapshot) == 1
        @test snapshot.metadata[:suite] == "api"
        @test trace_entries(snapshot) !== snapshot.entries
        sealed = seal_trace!(recorder; ended_ns=now[] + UInt64(30))
        @test sealed isa EventTrace
        @test record_trace!(recorder, :late, :ignored) === nothing
        @test clear_trace!(recorder) === recorder
        @test trace_length(recorder) == 0
        @test record_trace!(recorder, :resumed, :ok) isa TraceEntry

        stopped = EventRecorder(capacity=1, overflow=StopTraceRecording, clock=() -> UInt64(1))
        @test record_trace!(stopped, :first, 1; timestamp_ns=1) isa TraceEntry
        @test record_trace!(stopped, :second, 2; timestamp_ns=2) === nothing
        @test trace_length(stopped) == 1

        failing = EventRecorder(
            filter=(kind, payload, source, metadata) -> error("filter failed"),
            strict=false,
        )
        @test record_trace!(failing, :input, :payload) === nothing
        @test !isempty(trace_errors(failing))
        @test !isempty(take_trace_errors!(failing))
        @test isempty(trace_errors(failing))

        replay_trace = EventTrace(
            v"1.0.0",
            UInt64(100),
            UInt64(130),
            [
                TraceEntry(UInt64(1), UInt64(100), :input, :terminal, nothing, :a, Dict{Symbol,Any}()),
                TraceEntry(UInt64(2), UInt64(120), :message, :application, nothing, :b, Dict{Symbol,Any}()),
            ],
            Dict{Symbol,Any}(:case => "manual"),
            UInt64(0),
        )
        dispatched = Symbol[]
        replay = ReplayController(replay_trace, entry -> (push!(dispatched, entry.payload); entry.payload); clock=() -> UInt64(1_000))
        @test replay_status(replay) == ReplayReady
        @test replay_position(replay) == 1
        step = replay_step!(replay)
        @test step isa ReplayResult
        @test step.value == :a
        @test replay_position(replay) == 2
        @test seek_replay!(replay, 1) === replay
        @test replay_status(replay) == ReplayReady
        all_results = replay_all!(replay)
        @test [result.value for result in all_results] == [:a, :b]
        @test replay_status(replay) == ReplayCompleted
        @test reset_replay!(replay) === replay
        @test replay_position(replay) == 1

        clock = Ref(UInt64(1_000))
        timed = ReplayController(replay_trace, entry -> entry.payload; clock=() -> clock[])
        @test start_replay!(timed; now_ns=clock[])
        @test replay_status(timed) == ReplayRunning
        early = poll_replay!(timed; now_ns=clock[])
        @test length(early) == 1
        @test early[1].value == :a
        @test pause_replay!(timed)
        @test replay_status(timed) == ReplayPaused
        @test start_replay!(timed; now_ns=clock[])
        later = poll_replay!(timed; now_ns=clock[] + UInt64(20))
        @test length(later) == 1
        @test later[1].value == :b
        @test replay_status(timed) == ReplayCompleted

        failed = ReplayController(replay_trace, entry -> error("dispatch failed"))
        failed_result = replay_step!(failed)
        @test failed_result.error !== nothing
        @test replay_status(failed) == ReplayFailed
        @test !isempty(replay_errors(failed))
        @test !isempty(take_replay_errors!(failed))
        @test isempty(replay_errors(failed))
    end

    @testset "stable extension registry contracts" begin
        events = Symbol[]
        registry = ExtensionRegistry(services=Dict(:logger => events))
        base = ExtensionDescriptor(
            :base,
            v"1.0.0";
            description="Base extension",
            initialize=context -> begin
                push!(extension_service(context.registry, :logger), :base_up)
                contribute_extension!(context, ThemeContribution, :theme, :dark)
                set_extension_service!(context.registry, :base_service, :ready)
            end,
            shutdown=context -> push!(extension_service(context.registry, :logger), :base_down),
        )
        feature = ExtensionDescriptor(
            :feature,
            v"1.1.0";
            dependencies=[ExtensionDependency(:base; minimum=v"1.0.0", maximum_exclusive=v"2.0.0")],
            initialize=context -> begin
                push!(extension_service(context.registry, :logger), :feature_up)
                contribute_extension!(context, CommandContribution, :command, :run)
                contribute_extension!(context, InspectorContribution, :inspector, :panel)
            end,
            shutdown=context -> push!(extension_service(context.registry, :logger), :feature_down),
        )

        @test register_extension!(registry, base) === registry
        @test register_extension!(registry, feature) === registry
        @test extension_state(registry, :base) == ExtensionRegistered
        @test resolve_extensions(registry, [:feature]) == [:base, :feature]
        @test activate_extension!(registry, :feature) == [:base, :feature]
        @test events == [:base_up, :feature_up]
        @test extension_state(registry, :base) == ExtensionActive
        @test extension_state(registry, :feature) == ExtensionActive
        @test extension_contribution(registry, ThemeContribution, :theme).value == :dark
        @test extension_contribution(registry, CommandContribution, :command).owner == :feature
        @test length(extension_contributions(registry; owner=:feature)) == 2
        @test extension_service(registry, :base_service) == :ready
        @test extension_service(registry, :missing, :fallback) == :fallback
        snapshot = extension_snapshot(registry)
        @test occursin("base 1.0.0 ExtensionActive", snapshot)
        @test occursin("CommandContribution/command", snapshot)

        @test deactivate_extension!(registry, :feature) === true
        @test events[end] == :feature_down
        @test extension_state(registry, :feature) == ExtensionRegistered
        @test extension_contribution(registry, CommandContribution, :command) === nothing
        @test extension_state(registry, :base) == ExtensionActive
        @test deactivate_extensions!(registry) == [:base]
        @test events[end] == :base_down
        @test extension_state(registry, :base) == ExtensionRegistered
        @test unregister_extension!(registry, :feature)
        @test extension_state(registry, :feature) === nothing

        scoped = ExtensionRegistry()
        register_extension!(scoped, ExtensionDescriptor(
            :scoped,
            v"1.0.0";
            initialize=context -> contribute_extension!(context, ServiceContribution, :temporary, :value),
        ))
        scoped_result = with_extensions(scoped, [:scoped]) do active_registry
            @test extension_state(active_registry, :scoped) == ExtensionActive
            extension_contribution(active_registry, ServiceContribution, :temporary).value
        end
        @test scoped_result == :value
        @test extension_state(scoped, :scoped) == ExtensionRegistered
        @test extension_contribution(scoped, ServiceContribution, :temporary) === nothing

        @test_throws ExtensionError register_extension!(registry, base)
        @test_throws ExtensionError resolve_extensions(registry, [:missing])
        @test_throws ArgumentError ExtensionDescriptor("bad name", v"1.0.0")
        @test ExtensionPolicy(maximum_extensions=1) isa ExtensionPolicy
    end

    @testset "stable remote transport contracts" begin
        capabilities = TerminalCapabilities(
            color_level=:truecolor,
            mouse=true,
            focus=true,
            bracketed_paste=true,
            synchronized_updates=true,
            enhanced_keyboard=true,
        )
        limits = RemoteProtocolLimits(
            maximum_packet_bytes=4096,
            maximum_buffer_bytes=8192,
            maximum_cells=64,
            maximum_string_bytes=128,
        )
        hello = RemoteHello(UInt64(7), Size(3, 4), capabilities)
        decoded_hello = decode_remote_packet(encode_remote_message(hello; limits); limits)
        @test decoded_hello isa RemoteHello
        @test decoded_hello.sequence == 7
        @test decoded_hello.size == Size(3, 4)
        @test decoded_hello.capabilities == capabilities

        changes = [
            CellChange(Position(1, 1), Cell("a")),
            CellChange(Position(1, 2), Cell("b")),
        ]
        frame = RemoteFrame(
            UInt64(8),
            true,
            Size(1, 2),
            changes,
            CursorRequest(Position(1, 2); shape=BarCursor),
        )
        decoded_frame = decode_remote_packet(encode_remote_message(frame; limits); limits)
        @test decoded_frame isa RemoteFrame
        @test decoded_frame.full
        @test decoded_frame.changes == changes
        @test decoded_frame.cursor == frame.cursor

        remote_event = RemoteEvent(UInt64(0), KeyEvent(Key(:character); text="x"))
        decoded_event = decode_remote_packet(encode_remote_message(remote_event; limits); limits)
        @test decoded_event isa RemoteEvent
        @test decoded_event.event == remote_event.event
        @test decode_remote_packet(encode_remote_message(RemoteAck(UInt64(9)); limits); limits).sequence == 9

        decoder = RemoteDecoder(; limits)
        first_packet = encode_remote_message(RemoteAck(UInt64(1)); limits)
        second_packet = encode_remote_message(RemoteAck(UInt64(2)); limits)
        @test isempty(feed_remote!(decoder, first_packet[1:5]))
        decoded_messages = feed_remote!(decoder, vcat(first_packet[6:end], second_packet))
        @test getfield.(decoded_messages, :sequence) == [1, 2]
        @test isempty(decoder.buffer)

        packets = Vector{Vector{UInt8}}()
        backend = RemoteBackend(packet -> push!(packets, copy(packet)); size=Size(1, 2), capabilities, limits)
        @test backend isa RemoteBackend
        @test backend_size(backend) == Size(1, 2)
        @test backend_capabilities(backend) == capabilities
        enter!(backend)
        @test decode_remote_packet(packets[1]; limits) isa RemoteHello
        completed = Buffer(1, 2)
        render!(completed, Label("ab"), completed.area)
        present!(backend, CellChange[], completed, nothing)
        sent_frame = decode_remote_packet(packets[2]; limits)
        @test sent_frame isa RemoteFrame
        @test sent_frame.full
        @test length(sent_frame.changes) == 2
        @test request_remote_full_frame!(backend) === backend
        @test backend.force_full
        @test resize_remote_backend!(backend, 2, 2) === backend
        @test backend_size(backend) == Size(2, 2)

        session_packets = Vector{Vector{UInt8}}()
        session = RemoteSession(packet -> push!(session_packets, copy(packet)); size=Size(1, 2), limits, input_capacity=4)
        @test session isa RemoteSession
        @test ingest_remote!(
            session,
            encode_remote_message(RemoteEvent(UInt64(0), KeyEvent(Key(:enter))); limits),
        ) == 1
        @test read_event!(session.input) == KeyEvent(Key(:enter))
        @test ingest_remote!(
            session,
            encode_remote_message(RemoteEvent(UInt64(1), ResizeEvent(Size(2, 3))); limits),
        ) == 1
        @test backend_size(session.backend) == Size(2, 3)
        @test ingest_remote!(session, encode_remote_message(RemoteAck(UInt64(3)); limits)) == 1
        @test session.acknowledged_sequence == 3
        @test close_remote_session!(session) === session
        @test_throws RemoteProtocolError ingest_remote!(
            session,
            encode_remote_message(RemoteEvent(UInt64(2), FocusEvent(true)); limits),
        )

        @test_throws RemoteProtocolError encode_remote_message(
            RemoteEvent(UInt64(0), CustomEvent(:unsafe));
            limits,
        )
        @test_throws RemoteProtocolError decode_remote_packet(UInt8[]; limits)
        @test websocket_session isa Function
        @test pump_websocket! isa Function
        @test REMOTE_PROTOCOL_VERSION == UInt16(1)
    end

    @testset "stable styles and theme-management contracts" begin
        @test DEFAULT_THEME isa Theme
        @test theme_style(DEFAULT_THEME, :text) isa Style
        @test parse_color("bright-red") == AnsiColor(9)
        @test parse_color("#010203") == RGBColor(1, 2, 3)

        context = StyleContext(Button, :save, Set([:primary]), Set([:focused]), Set([:dialog]))
        selector = Selector(
            widget_type=:Button,
            id=:save,
            classes=[:primary],
            states=[:focused],
            ancestor_classes=[:dialog],
        )
        @test matches(selector, context)
        @test specificity(selector) == (1, 3, 1)

        stylesheet = parse_stylesheet(
            """
            .dialog Button.primary:focused {
                color: bright-green;
                background: #010203;
                modifiers: bold underline;
            }
            """;
            source="stable-theme.wkd",
        )
        @test stylesheet isa Stylesheet
        @test stylesheet.rules[1] isa StyleRule
        @test stylesheet.rules[1].patch.foreground == AnsiColor(10)
        parsed, diagnostics = try_parse_stylesheet("Button { unknown: value; }"; source="bad.wkd")
        @test parsed isa Stylesheet
        @test !isempty(diagnostics)
        @test diagnostics[1] isa StyleDiagnostic
        @test_throws StylesheetParseError parse_stylesheet("Button { color: nope; }")

        engine = StyleEngine(theme=Theme(:stable; roles=Dict(:primary => Style(foreground=AnsiColor(4)))))
        @test add_stylesheet!(engine, stylesheet) === engine
        @test engine.revision == 1
        resolved = computed_style(engine, context; role=:primary)
        @test resolved.foreground == AnsiColor(10)
        @test resolved.background == RGBColor(1, 2, 3)
        @test BOLD in resolved.modifiers
        @test remove_rule!(stylesheet, 1) === stylesheet
        @test isempty(stylesheet.rules)
        @test add_rule!(stylesheet, Selector(classes=[:primary]), StylePatch(foreground=AnsiColor(2))) === stylesheet
        @test set_theme!(engine, Theme(:next; roles=Dict(:primary => Style(foreground=AnsiColor(5))))) === engine
        @test engine.revision == 2

        buffer = Buffer(1, 2; cell=Cell("x"))
        @test apply_style!(buffer, buffer.area, engine, context; role=:primary) === buffer
        @test buffer[1, 1].style.foreground == AnsiColor(2)

        path, io = mktemp()
        try
            write(io, "Button { color: blue; }")
            close(io)
            @test load_stylesheet(path) isa Stylesheet
        finally
            isopen(io) && close(io)
            rm(path; force=true)
        end

        light = ThemeDescriptor(
            :light,
            Theme(:light; roles=Dict(:text => Style(foreground=AnsiColor(0))));
            variant=LightTheme,
            priority=1,
        )
        dark = ThemeDescriptor(
            :dark,
            Theme(:dark; roles=Dict(:text => Style(foreground=AnsiColor(15))));
            variant=DarkTheme,
            priority=2,
        )
        contrast = ThemeDescriptor(
            :contrast,
            Theme(:contrast; roles=Dict(:text => Style(foreground=AnsiColor(7))));
            variant=HighContrastTheme,
            priority=3,
        )
        registry = ThemeRegistry([light, dark, contrast]; active=:light, preference=LightTheme)
        events = ThemeChangeEvent[]
        subscription = subscribe_theme!(registry, event -> push!(events, event))
        @test subscription isa ThemeSubscription
        @test active_theme(registry).name == :light
        @test active_theme_descriptor(registry).id == :light
        @test length(available_themes(registry)) == 3
        @test set_active_theme!(registry, :dark)
        @test events[end].reason == ThemeSelected
        @test theme_generation(registry) == 1
        replacement = ThemeDescriptor(:dark, Theme(:dark2; roles=Dict(:text => Style(foreground=AnsiColor(6)))))
        @test register_theme!(registry, replacement; replace=true) === registry
        @test events[end].reason == ActiveThemeReplaced
        @test set_theme_preference!(registry, HighContrastTheme)
        @test active_theme_descriptor(registry).id == :contrast
        @test events[end].reason == ThemePreferenceChanged
        @test unregister_theme!(registry, :contrast)
        @test events[end].reason == ActiveThemeRemoved
        @test unsubscribe_theme!(registry, subscription)
        @test !unsubscribe_theme!(registry, subscription)

        bound_engine = StyleEngine()
        binding = bind_theme_engine!(registry, bound_engine)
        @test binding isa ThemeEngineBinding
        @test bound_engine.theme.name == active_theme(registry).name
        @test unbind_theme_engine!(binding)
        @test !unbind_theme_engine!(binding)

        subscribe_theme!(registry, _ -> error("subscriber failed"))
        set_active_theme!(registry, :dark)
        set_active_theme!(registry, :light)
        @test !isempty(theme_errors(registry))
        @test !isempty(take_theme_errors!(registry))
        @test isempty(theme_errors(registry))

        derived = derive_theme(
            Theme(:base; roles=Dict(:text => Style(), :muted => Style(modifiers=DIM))),
            :derived;
            roles=Dict(:text => Style(foreground=AnsiColor(2))),
            remove=[:muted],
        )
        @test derived.name == :derived
        @test derived.roles[:text].foreground == AnsiColor(2)
        @test validate_theme_roles(derived, [:text]) == (true, Symbol[])
        @test validate_theme_roles(derived, [:text, :muted]) == (false, [:muted])

        resolver = RoleStyleResolver(Dict(:info => Style(foreground=AnsiColor(6))), Style())
        @test resolve_role_style(resolver, :info).foreground == AnsiColor(6)
    end

    @testset "stable reactive toolkit APIs" begin
        runtime = ReactiveRuntime()
        count = Signal(1; runtime=runtime)
        label = computed_signal(value -> "count=$value", [count]; runtime=runtime)
        queue = ReactiveInvalidationQueue()

        binding = ReactiveComponentBinding("counter"; queue=queue)
        subscription = bind_component_signal!(binding, count; kinds=(RenderInvalidation, SemanticsInvalidation))
        @test subscription isa ReactiveSubscription
        set_signal!(count, 2)
        invalidations = take_invalidations!(queue)
        @test length(invalidations) == 1
        @test invalidations[1].component_id == "counter"
        @test RenderInvalidation in invalidations[1].kinds
        @test SemanticsInvalidation in invalidations[1].kinds
        @test isempty(pending_invalidations(queue))

        state = ReactiveComponentState(; runtime=runtime)
        local_count = component_signal!(state, :count, 1)
        doubled = computed_component_state!(state, :doubled, [:count], value -> value * 2)
        @test component_signal(state, :count) === local_count
        @test component_state_value(state, :doubled) == 2
        transaction_component!(state) do component
            set_component_state!(component, :count, 4)
        end
        @test signal_value(doubled) == 8

        element = reactive_element("counter", value -> Label("count=$value"), [count]; queue=queue)
        @test reactive_element_value!(element) isa Label
        set_signal!(count, 3)
        @test !isempty(component_invalidations(binding))
        @test reactive_element_value!(element) isa Label
        invalidate_reactive_element!(element; kinds=(LayoutInvalidation,))
        @test any(item -> LayoutInvalidation in item.kinds, take_invalidations!(queue))

        classes = ReactiveClassSet("counter"; queue=queue)
        bind_reactive_class!(classes, "positive", count; predicate=value -> value > 0)
        @test reactive_classes(classes) == ["positive"]
        set_signal!(count, 0)
        @test isempty(reactive_classes(classes))
        @test unbind_reactive_class!(classes, "positive")
        @test !unbind_reactive_class!(classes, "positive")

        clear_invalidations!(queue)
        dispose!(classes)
        dispose!(element)
        dispose!(state)
        dispose!(binding)
        dispose!(label)
    end


    @testset "stable action registry and command palette APIs" begin
        registry = ActionRegistry()
        context = ActionContext(data=(dirty=true, saved=false))
        save = Action(
            :save,
            "Save",
            ctx -> (:saved, ctx.data.dirty);
            description="Save the active document",
            category="File",
            keywords=["write", "persist"],
            enabled=ctx -> ctx.data.dirty,
            bindings=[ActionBinding(:s; modifiers=CTRL, description="Save", priority=10)],
            priority=5,
        )
        register_action!(registry, save)
        @test action_registry_generation(registry) == 1
        @test active_action_scopes(registry) == [:global]
        @test action_summary(registry, context) == (
            total=1,
            visible=1,
            hidden=0,
            enabled=1,
            disabled=0,
            checked=0,
            errored=0,
            scopes=1,
            active_scopes=[:global],
        )
        action_snapshot = action_registry_snapshot(registry, context)
        @test action_snapshot isa ActionRegistrySnapshot
        @test action_snapshot.generation == action_registry_generation(registry)
        @test action_snapshot.active_scopes == [:global]
        @test action_snapshot.total == 1
        @test action_snapshot.visible == 1
        @test action_snapshot.enabled == 1
        @test action_snapshot.category_count == 1
        @test action_snapshot.categories == ["File"]
        @test action_snapshot.error_count == 0
        @test action_registry_snapshot_record(action_snapshot).generation == action_snapshot.generation
        @test action_registry_snapshot_record(registry, context).total == 1
        @test occursin("ActionRegistrySnapshot", sprint(show, action_snapshot))
        action_diagnostics = action_registry_diagnostics(registry, context)
        @test action_diagnostics isa ActionRegistryDiagnostics
        @test action_diagnostics.snapshot.generation == action_snapshot.generation
        @test action_diagnostics.summary.total == 1
        @test length(action_diagnostics.categories) == 1
        @test length(action_diagnostics.actions) == 1
        @test length(action_diagnostics.bindings) == 1
        @test isempty(action_diagnostics.errors)
        @test action_registry_diagnostics_record(action_diagnostics).snapshot.total == 1
        @test action_registry_diagnostics_record(registry, context).summary.total == 1
        @test occursin("ActionRegistryDiagnostics", sprint(show, action_diagnostics))
        diagnostics_markdown = action_registry_diagnostics_markdown(action_diagnostics)
        @test startswith(diagnostics_markdown, "| `metric` | `value` |")
        @test occursin("| actions | 1 |", diagnostics_markdown)
        @test occursin("File", action_registry_diagnostics_markdown(registry, context))
        diagnostics_tsv = action_registry_diagnostics_tsv(action_diagnostics)
        @test startswith(diagnostics_tsv, "metric\tvalue\n")
        @test occursin("actions\t1", diagnostics_tsv)
        @test !startswith(action_registry_diagnostics_tsv(action_diagnostics; header=false), "metric\tvalue")
        diagnostics_text = action_registry_diagnostics_text(action_diagnostics)
        @test startswith(diagnostics_text, "Action registry diagnostics")
        @test occursin("actions: 1 total", diagnostics_text)
        @test occursin("File", action_registry_diagnostics_text(registry, context; newline=" | "))

        state = action_state(registry, :save, context)
        @test state isa ActionState
        @test state.enabled
        @test state.visible
        @test !state.checked
        @test state.scope == :global
        records = action_records(registry, context)
        @test length(records) == 1
        @test records[1].id == :save
        @test records[1].title == "Save"
        @test records[1].category == "File"
        @test records[1].keywords == ["write", "persist"]
        @test records[1].bindings[1].label == "Ctrl+s"
        @test records[1].bindings[1].description == "Save"
        @test records[1].enabled
        @test action_categories(registry, context) == ["File"]
        category_records = action_category_records(registry, context)
        @test length(category_records) == 1
        @test category_records[1].category == "File"
        @test category_records[1].count == 1
        @test category_records[1].enabled == 1
        @test category_records[1].disabled == 0
        @test category_records[1].actions == [:save]
        category_markdown = action_category_records_markdown(registry, context; columns=(:category, :count, :actions))
        @test startswith(category_markdown, "| `category` | `count` | `actions` |")
        @test occursin("| File | 1 | save |", category_markdown)
        category_tsv = action_category_records_tsv(registry, context; columns=(:category, :enabled, :actions))
        @test startswith(category_tsv, "category\tenabled\tactions\n")
        @test occursin("File\t1\tsave", category_tsv)
        @test !startswith(action_category_records_tsv(registry, context; columns=:category, header=false), "category")
        @test_throws ArgumentError action_category_records_markdown(registry, context; columns=())
        @test_throws ArgumentError action_category_records_tsv(registry, context; columns=(:missing,))
        searched_categories = search_action_categories(registry, "File", context)
        @test length(searched_categories) == 1
        @test searched_categories[1].category == "File"
        @test search_action_category_count(registry, :save, context) == 1
        @test search_action_category_count(registry, r"File", context) == 1
        searched_category_markdown = search_action_category_records_markdown(registry, "save", context; columns=(:category, :actions))
        @test startswith(searched_category_markdown, "| `category` | `actions` |")
        @test occursin("| File | save |", searched_category_markdown)
        searched_category_tsv = search_action_category_records_tsv(registry, "File", context; columns=(:category, :count))
        @test startswith(searched_category_tsv, "category\tcount\n")
        @test occursin("File\t1", searched_category_tsv)
        @test_throws ArgumentError search_action_categories(registry, 1, context)
        @test_throws ArgumentError search_action_category_records_markdown(registry, 1, context)
        @test_throws ArgumentError search_action_category_records_tsv(registry, 1, context)
        searched_actions = search_actions(registry, "persist", context)
        @test length(searched_actions) == 1
        @test searched_actions[1].id == :save
        @test search_action_count(registry, "Ctrl+s", context) == 1
        @test search_action_count(registry, :save, context) == 1
        @test search_action_count(registry, r"Save", context) == 1
        @test search_action_count(registry, "missing", context) == 0
        action_markdown = action_records_markdown(registry, context; columns=(:id, :title, :bindings))
        @test startswith(action_markdown, "| `id` | `title` | `bindings` |")
        @test occursin("| save | Save | Ctrl+s |", action_markdown)
        action_tsv = action_records_tsv(registry, context; columns=(:id, :enabled, :bindings))
        @test startswith(action_tsv, "id\tenabled\tbindings\n")
        @test occursin("save\ttrue\tCtrl+s", action_tsv)
        @test !startswith(action_records_tsv(registry, context; columns=:id, header=false), "id")
        searched_action_markdown = search_action_records_markdown(registry, "persist", context; columns=(:id, :category))
        @test startswith(searched_action_markdown, "| `id` | `category` |")
        @test occursin("| save | File |", searched_action_markdown)
        searched_action_tsv = search_action_records_tsv(registry, "Ctrl+s", context; columns=(:id, :bindings))
        @test startswith(searched_action_tsv, "id\tbindings\n")
        @test occursin("save\tCtrl+s", searched_action_tsv)
        @test_throws ArgumentError action_records_markdown(registry, context; columns=())
        @test_throws ArgumentError action_records_tsv(registry, context; columns=(:missing,))
        @test_throws ArgumentError search_action_records_markdown(registry, 1, context)
        @test_throws ArgumentError search_action_records_tsv(registry, 1, context)

        invocation = invoke_action!(registry, :save, context)
        @test invocation isa ActionInvocation
        @test invocation.status == ActionInvoked
        @test invocation.value == (:saved, true)
        invocation_diagnostics = invoke_action_diagnostics!(registry, :save, context)
        @test invocation_diagnostics isa ActionWorkflowDiagnostics
        @test invocation_diagnostics.summary.total == 1
        @test action_workflow_diagnostics_all_invoked(invocation_diagnostics)
        invocation_record = action_invocation_record(invocation)
        @test invocation_record.id == :save
        @test invocation_record.status == :ActionInvoked
        @test invocation_record.has_value
        @test occursin("ActionInvoked", action_invocation_text(invocation))
        @test occursin("| save | ActionInvoked |", action_invocation_markdown(invocation; columns=(:id, :status)))
        @test occursin("save\tActionInvoked", action_invocation_tsv(invocation; columns=(:id, :status)))
        @test first(action_invocation_records([invocation])).id == :save
        @test occursin("ActionInvoked", action_invocations_text([invocation]))
        @test action_invocations_text(ActionInvocation[]) == "No action invocations"
        @test occursin("| save | ActionInvoked |", action_invocations_markdown([invocation]; columns=(:id, :status)))
        @test occursin("save\tActionInvoked", action_invocations_tsv([invocation]; columns=(:id, :status)))
        @test action_invocations_all_invoked([invocation])
        @test isempty(action_invocation_failures([invocation]))
        @test !action_invocations_any_failed([invocation])
        @test isempty(action_invocation_issues([invocation]))
        @test isempty(action_invocation_issue_records([invocation]))
        @test action_invocation_issues_text([invocation]) == "No action invocations"
        @test startswith(action_invocation_issues_markdown([invocation]; columns=(:id, :status)), "| `id` | `status` |")
        @test action_invocation_issues_tsv([invocation]; columns=(:id, :status)) == "id\tstatus"
        @test action_invocation_issue_summary([invocation]).total == 0
        @test isempty(action_invocation_issue_summary_records([invocation]))
        @test action_invocation_issue_summary_text([invocation]) == "No action invocations"
        @test startswith(action_invocation_issue_summary_markdown([invocation]), "| `status` | `count` |")
        @test action_invocation_issue_summary_tsv([invocation]) == "status\tcount"
        @test isempty(search_action_invocation_issue_summary_records([invocation], "ActionInvoked"))
        @test search_action_invocation_issue_summary_count([invocation], "ActionInvoked") == 0
        @test search_action_invocation_issue_summary_text([invocation], "ActionInvoked") == "No matching action invocation summary"
        @test !action_invocations_any_issue([invocation])
        @test assert_action_invocations_invoked([invocation]) == [invocation]
        @test assert_no_action_invocation_failures([invocation]) == [invocation]
        @test assert_no_action_invocation_issues([invocation]) == [invocation]
        @test_throws ArgumentError action_invocations_markdown([invocation]; columns=())
        @test_throws ArgumentError action_invocations_tsv([invocation]; columns=(:missing,))
        @test action_invocation_summary([invocation]).total == 1
        @test action_invocation_summary_records([invocation]) == [(status=:ActionInvoked, count=1)]
        @test occursin("ActionInvoked: 1", action_invocation_summary_text([invocation]))
        @test action_invocation_summary_text(ActionInvocation[]) == "No action invocations"
        @test occursin("| ActionInvoked | 1 |", action_invocation_summary_markdown([invocation]))
        @test occursin("ActionInvoked\t1", action_invocation_summary_tsv([invocation]))
        @test_throws ArgumentError action_invocation_summary_markdown([invocation]; columns=())
        @test_throws ArgumentError action_invocation_summary_tsv([invocation]; columns=(:missing,))
        @test first(search_action_invocation_records([invocation], "save")).id == :save
        @test search_action_invocation_count([invocation], "ActionInvoked") == 1
        @test search_action_invocation_count([invocation], "ActionFailed") == 0
        @test occursin("ActionInvoked", search_action_invocations_text([invocation], "save"))
        @test search_action_invocations_text([invocation], "ActionFailed") == "No matching action invocations"
        @test occursin("| save | ActionInvoked |", search_action_invocations_markdown([invocation], "save"; columns=(:id, :status)))
        @test occursin("save\tActionInvoked", search_action_invocations_tsv([invocation], "save"; columns=(:id, :status)))
        @test_throws ArgumentError search_action_invocation_records([invocation], 1)
        @test_throws ArgumentError search_action_invocations_markdown([invocation], "save"; columns=())
        @test_throws ArgumentError search_action_invocations_tsv([invocation], "save"; columns=(:missing,))
        @test search_action_invocation_summary_records([invocation], "ActionInvoked") == [(status=:ActionInvoked, count=1)]
        @test search_action_invocation_summary_count([invocation], "ActionInvoked") == 1
        @test search_action_invocation_summary_count([invocation], "ActionFailed") == 0
        @test occursin("ActionInvoked: 1", search_action_invocation_summary_text([invocation], "ActionInvoked"))
        @test search_action_invocation_summary_text([invocation], "ActionFailed") == "No matching action invocation summary"
        @test occursin("| ActionInvoked | 1 |", search_action_invocation_summary_markdown([invocation], "ActionInvoked"))
        @test occursin("ActionInvoked\t1", search_action_invocation_summary_tsv([invocation], "ActionInvoked"))
        @test_throws ArgumentError search_action_invocation_summary_records([invocation], 1)
        @test_throws ArgumentError search_action_invocation_summary_markdown([invocation], "ActionInvoked"; columns=())
        @test_throws ArgumentError search_action_invocation_summary_tsv([invocation], "ActionInvoked"; columns=(:missing,))
        @test_throws ArgumentError action_invocation_markdown(invocation; columns=())
        @test_throws ArgumentError action_invocation_tsv(invocation; columns=(:missing,))
        workflow_diagnostics = action_workflow_diagnostics([invocation])
        @test workflow_diagnostics isa ActionWorkflowDiagnostics
        @test workflow_diagnostics.summary.total == 1
        @test isempty(workflow_diagnostics.issues)
        @test isempty(workflow_diagnostics.failures)
        @test action_workflow_diagnostics(invocation).summary.total == 1
        @test empty_action_workflow_diagnostics().summary.total == 0
        merged_workflow_diagnostics = merge_action_workflow_diagnostics(workflow_diagnostics, empty_action_workflow_diagnostics())
        @test merged_workflow_diagnostics isa ActionWorkflowDiagnostics
        @test merged_workflow_diagnostics.summary.total == 1
        @test merged_workflow_diagnostics !== workflow_diagnostics
        merged_workflow_diagnostics_vector = merge_action_workflow_diagnostics([workflow_diagnostics, empty_action_workflow_diagnostics()])
        @test merged_workflow_diagnostics_vector isa ActionWorkflowDiagnostics
        @test merged_workflow_diagnostics_vector.summary.total == 1
        @test occursin("ActionWorkflowDiagnostics(total=1", sprint(show, workflow_diagnostics))
        workflow_diagnostics_record = action_workflow_diagnostics_record(workflow_diagnostics)
        @test workflow_diagnostics_record.total == 1
        @test workflow_diagnostics_record.issue_count == 0
        @test workflow_diagnostics_record.failure_count == 0
        @test first(workflow_diagnostics_record.invocations).id == :save
        @test isempty(workflow_diagnostics_record.issues)
        @test isempty(workflow_diagnostics_record.failures)
        @test action_workflow_diagnostics_record([invocation]).total == 1
        workflow_diagnostics_bundle_records = action_workflow_diagnostics_bundle_records(workflow_diagnostics, empty_action_workflow_diagnostics())
        @test length(workflow_diagnostics_bundle_records) == 2
        @test first(workflow_diagnostics_bundle_records).total == 1
        @test last(workflow_diagnostics_bundle_records).total == 0
        @test length(action_workflow_diagnostics_bundle_records([workflow_diagnostics, empty_action_workflow_diagnostics()])) == 2
        @test occursin("| 1 | 1 | 0 | 0 |", action_workflow_diagnostics_bundle_records_markdown(workflow_diagnostics, empty_action_workflow_diagnostics()))
        @test occursin("#1 total=1 issues=0 failures=0", action_workflow_diagnostics_bundle_records_text(workflow_diagnostics, empty_action_workflow_diagnostics()))
        @test action_workflow_diagnostics_bundle_records_text(ActionWorkflowDiagnostics[]) == "No action workflow diagnostics"
        @test occursin("1\t1\t0\t0", action_workflow_diagnostics_bundle_records_tsv([workflow_diagnostics, empty_action_workflow_diagnostics()]))
        @test_throws ArgumentError action_workflow_diagnostics_bundle_records_markdown(workflow_diagnostics; columns=())
        @test_throws ArgumentError action_workflow_diagnostics_bundle_records_tsv(workflow_diagnostics; columns=(:missing,))
        bundle_summary = action_workflow_diagnostics_bundle_summary(workflow_diagnostics, empty_action_workflow_diagnostics())
        @test bundle_summary.bundles == 2
        @test bundle_summary.total == 1
        @test bundle_summary.issue_count == 0
        @test bundle_summary.failure_count == 0
        @test bundle_summary.all_invoked
        @test action_workflow_diagnostics_bundle_summary([workflow_diagnostics, empty_action_workflow_diagnostics()]).total == 1
        @test occursin("Bundles: 2", action_workflow_diagnostics_bundle_summary_text(workflow_diagnostics, empty_action_workflow_diagnostics()))
        @test occursin("| bundles | 2 |", action_workflow_diagnostics_bundle_summary_markdown(workflow_diagnostics, empty_action_workflow_diagnostics()))
        @test occursin("bundles\t2", action_workflow_diagnostics_bundle_summary_tsv([workflow_diagnostics, empty_action_workflow_diagnostics()]))
        @test !startswith(action_workflow_diagnostics_bundle_summary_tsv(workflow_diagnostics; header=false), "metric\tvalue")
        @test action_workflow_diagnostics_bundle_all_invoked(workflow_diagnostics, empty_action_workflow_diagnostics())
        @test action_workflow_diagnostics_bundle_all_invoked([workflow_diagnostics, empty_action_workflow_diagnostics()])
        @test !action_workflow_diagnostics_bundle_has_issues(workflow_diagnostics, empty_action_workflow_diagnostics())
        @test !action_workflow_diagnostics_bundle_has_failures(workflow_diagnostics, empty_action_workflow_diagnostics())
        @test assert_action_workflow_diagnostics_bundle_all_invoked(workflow_diagnostics, empty_action_workflow_diagnostics()) isa Tuple
        @test assert_action_workflow_diagnostics_bundle_no_issues([workflow_diagnostics, empty_action_workflow_diagnostics()]) isa Tuple
        @test assert_action_workflow_diagnostics_bundle_no_failures(workflow_diagnostics, empty_action_workflow_diagnostics()) isa Tuple
        @test action_workflow_diagnostics_invocations(workflow_diagnostics) == [invocation]
        @test action_workflow_diagnostics_invocations(workflow_diagnostics) !== workflow_diagnostics.invocations
        @test action_workflow_diagnostics_invocations([invocation]) == [invocation]
        @test first(action_workflow_diagnostics_records(workflow_diagnostics)).id == :save
        @test action_workflow_diagnostics_records(workflow_diagnostics) !== workflow_diagnostics.records
        @test first(action_workflow_diagnostics_records([invocation])).id == :save
        @test first(search_action_workflow_diagnostics_records(workflow_diagnostics, "save")).id == :save
        @test first(search_action_workflow_diagnostics_records([invocation], "save")).id == :save
        @test search_action_workflow_diagnostics_count(workflow_diagnostics, "ActionInvoked") == 1
        @test search_action_workflow_diagnostics_count([invocation], "ActionInvoked") == 1
        @test occursin("ActionInvoked", search_action_workflow_diagnostics_text(workflow_diagnostics, "save"))
        @test occursin("| save | ActionInvoked |", search_action_workflow_diagnostics_markdown(workflow_diagnostics, "save"; columns=(:id, :status)))
        @test occursin("save\tActionInvoked", search_action_workflow_diagnostics_tsv([invocation], "save"; columns=(:id, :status)))
        @test action_workflow_diagnostics_summary(workflow_diagnostics).total == 1
        @test action_workflow_diagnostics_summary(workflow_diagnostics).by_status !== workflow_diagnostics.summary.by_status
        @test action_workflow_diagnostics_summary([invocation]).total == 1
        @test action_workflow_diagnostics_status_count(workflow_diagnostics, ActionInvoked) == 1
        @test action_workflow_diagnostics_status_count([invocation], :ActionInvoked) == 1
        @test action_workflow_diagnostics_status_count(workflow_diagnostics, "ActionFailed") == 0
        @test action_workflow_diagnostics_issue_status_count(workflow_diagnostics, :ActionFailed) == 0
        @test action_workflow_diagnostics_failure_status_count(workflow_diagnostics, :ActionFailed) == 0
        @test_throws ArgumentError action_workflow_diagnostics_status_count(workflow_diagnostics, 1)
        @test action_workflow_diagnostics_invoked_count(workflow_diagnostics) == 1
        @test action_workflow_diagnostics_invoked_count([invocation]) == 1
        @test action_workflow_diagnostics_missing_count(workflow_diagnostics) == 0
        @test action_workflow_diagnostics_disabled_count(workflow_diagnostics) == 0
        @test action_workflow_diagnostics_failed_count(workflow_diagnostics) == 0
        @test action_workflow_diagnostics_total_count(workflow_diagnostics) == 1
        @test action_workflow_diagnostics_total_count([invocation]) == 1
        @test action_workflow_diagnostics_issue_count(workflow_diagnostics) == 0
        @test action_workflow_diagnostics_failure_count(workflow_diagnostics) == 0
        @test action_workflow_diagnostics_summary_records(workflow_diagnostics) == [(status=:ActionInvoked, count=1)]
        @test action_workflow_diagnostics_summary_records([invocation]) == [(status=:ActionInvoked, count=1)]
        @test occursin("ActionInvoked: 1", action_workflow_diagnostics_summary_text(workflow_diagnostics))
        @test occursin("| ActionInvoked | 1 |", action_workflow_diagnostics_summary_markdown([invocation]))
        @test occursin("ActionInvoked\t1", action_workflow_diagnostics_summary_tsv(workflow_diagnostics))
        @test search_action_workflow_diagnostics_summary_records(workflow_diagnostics, "ActionInvoked") == [(status=:ActionInvoked, count=1)]
        @test search_action_workflow_diagnostics_summary_records([invocation], "ActionInvoked") == [(status=:ActionInvoked, count=1)]
        @test search_action_workflow_diagnostics_summary_count(workflow_diagnostics, "ActionInvoked") == 1
        @test search_action_workflow_diagnostics_summary_count([invocation], "ActionInvoked") == 1
        @test occursin("ActionInvoked: 1", search_action_workflow_diagnostics_summary_text(workflow_diagnostics, "ActionInvoked"))
        @test occursin("| ActionInvoked | 1 |", search_action_workflow_diagnostics_summary_markdown(workflow_diagnostics, "ActionInvoked"))
        @test occursin("ActionInvoked\t1", search_action_workflow_diagnostics_summary_tsv([invocation], "ActionInvoked"))
        @test occursin("Action workflow diagnostics", action_workflow_diagnostics_text(workflow_diagnostics))
        @test occursin("Total: 1", action_workflow_diagnostics_text([invocation]))
        @test startswith(action_workflow_diagnostics_markdown(workflow_diagnostics), "| `metric` | `value` |")
        @test occursin("| status_ActionInvoked | 1 |", action_workflow_diagnostics_markdown([invocation]))
        @test startswith(action_workflow_diagnostics_tsv(workflow_diagnostics), "metric\tvalue\n")
        @test occursin("status_ActionInvoked\t1", action_workflow_diagnostics_tsv([invocation]))
        @test !startswith(action_workflow_diagnostics_tsv(workflow_diagnostics; header=false), "metric\tvalue")
        @test action_workflow_diagnostics_all_invoked(workflow_diagnostics)
        @test action_workflow_diagnostics_all_invoked([invocation])
        @test action_workflow_diagnostics_all_invoked(ActionInvocation[])
        @test assert_action_workflow_diagnostics_all_invoked(ActionInvocation[]) isa ActionWorkflowDiagnostics
        @test isempty(action_workflow_diagnostics_failures(workflow_diagnostics))
        @test isempty(action_workflow_diagnostics_failures([invocation]))
        @test isempty(action_workflow_diagnostics_failure_records(workflow_diagnostics))
        @test isempty(action_workflow_diagnostics_failure_records([invocation]))
        @test action_workflow_diagnostics_failures_text(workflow_diagnostics) == "No action invocations"
        @test startswith(action_workflow_diagnostics_failures_markdown(workflow_diagnostics; columns=(:id, :status)), "| `id` | `status` |")
        @test action_workflow_diagnostics_failures_tsv(workflow_diagnostics; columns=(:id, :status)) == "id\tstatus"
        @test isempty(search_action_workflow_diagnostics_failure_records(workflow_diagnostics, "ActionInvoked"))
        @test search_action_workflow_diagnostics_failure_count(workflow_diagnostics, "ActionInvoked") == 0
        @test search_action_workflow_diagnostics_failures_text(workflow_diagnostics, "ActionInvoked") == "No matching action invocations"
        @test action_workflow_diagnostics_failure_summary(workflow_diagnostics).total == 0
        @test isempty(action_workflow_diagnostics_failure_summary_records(workflow_diagnostics))
        @test action_workflow_diagnostics_failure_summary_text(workflow_diagnostics) == "No action invocations"
        @test startswith(action_workflow_diagnostics_failure_summary_markdown(workflow_diagnostics), "| `status` | `count` |")
        @test action_workflow_diagnostics_failure_summary_tsv(workflow_diagnostics) == "status\tcount"
        @test isempty(search_action_workflow_diagnostics_failure_summary_records(workflow_diagnostics, "ActionInvoked"))
        @test search_action_workflow_diagnostics_failure_summary_count(workflow_diagnostics, "ActionInvoked") == 0
        @test search_action_workflow_diagnostics_failure_summary_text(workflow_diagnostics, "ActionInvoked") == "No matching action invocation summary"
        @test isempty(action_workflow_diagnostics_issues(workflow_diagnostics))
        @test isempty(action_workflow_diagnostics_issues([invocation]))
        @test isempty(action_workflow_diagnostics_issue_records(workflow_diagnostics))
        @test isempty(action_workflow_diagnostics_issue_records([invocation]))
        @test action_workflow_diagnostics_issues_text(workflow_diagnostics) == "No action invocations"
        @test startswith(action_workflow_diagnostics_issues_markdown(workflow_diagnostics; columns=(:id, :status)), "| `id` | `status` |")
        @test action_workflow_diagnostics_issues_tsv(workflow_diagnostics; columns=(:id, :status)) == "id\tstatus"
        @test isempty(search_action_workflow_diagnostics_issue_records(workflow_diagnostics, "ActionInvoked"))
        @test search_action_workflow_diagnostics_issue_count(workflow_diagnostics, "ActionInvoked") == 0
        @test search_action_workflow_diagnostics_issues_text(workflow_diagnostics, "ActionInvoked") == "No matching action invocations"
        @test action_workflow_diagnostics_issue_summary(workflow_diagnostics).total == 0
        @test isempty(action_workflow_diagnostics_issue_summary_records(workflow_diagnostics))
        @test action_workflow_diagnostics_issue_summary_text(workflow_diagnostics) == "No action invocations"
        @test startswith(action_workflow_diagnostics_issue_summary_markdown(workflow_diagnostics), "| `status` | `count` |")
        @test action_workflow_diagnostics_issue_summary_tsv(workflow_diagnostics) == "status\tcount"
        @test isempty(search_action_workflow_diagnostics_issue_summary_records(workflow_diagnostics, "ActionInvoked"))
        @test search_action_workflow_diagnostics_issue_summary_count(workflow_diagnostics, "ActionInvoked") == 0
        @test search_action_workflow_diagnostics_issue_summary_text(workflow_diagnostics, "ActionInvoked") == "No matching action invocation summary"
        @test !action_workflow_diagnostics_has_failures(workflow_diagnostics)
        @test !action_workflow_diagnostics_has_failures([invocation])
        @test !action_workflow_diagnostics_has_issues(workflow_diagnostics)
        @test !action_workflow_diagnostics_has_issues([invocation])
        @test assert_action_workflow_diagnostics_all_invoked(workflow_diagnostics) === workflow_diagnostics
        @test assert_action_workflow_diagnostics_all_invoked([invocation]) isa ActionWorkflowDiagnostics
        @test assert_action_workflow_diagnostics_no_failures(workflow_diagnostics) === workflow_diagnostics
        @test assert_action_workflow_diagnostics_no_failures([invocation]) isa ActionWorkflowDiagnostics
        @test assert_action_workflow_diagnostics_no_issues(workflow_diagnostics) === workflow_diagnostics
        @test assert_action_workflow_diagnostics_no_issues([invocation]) isa ActionWorkflowDiagnostics
        @test action_invocation_invoked(invocation)
        @test !action_invocation_failed(invocation)
        @test assert_action_invoked(invocation) === invocation
        @test_throws ArgumentError assert_action_failed(invocation)
        missing_invocation = invoke_action!(registry, :missing, context)
        @test missing_invocation.status == ActionMissing
        @test action_invocation_missing(missing_invocation)
        @test assert_action_missing(missing_invocation) === missing_invocation
        @test action_invocation_issues([missing_invocation]) == [missing_invocation]
        @test first(action_invocation_issue_records([missing_invocation])).status == :ActionMissing
        @test occursin("ActionMissing", action_invocation_issues_text([missing_invocation]))
        @test occursin("| missing | ActionMissing |", action_invocation_issues_markdown([missing_invocation]; columns=(:id, :status)))
        @test occursin("missing\tActionMissing", action_invocation_issues_tsv([missing_invocation]; columns=(:id, :status)))
        @test action_invocation_issue_summary([missing_invocation]).total == 1
        @test action_invocation_issue_summary_records([missing_invocation]) == [(status=:ActionMissing, count=1)]
        @test occursin("ActionMissing: 1", action_invocation_issue_summary_text([missing_invocation]))
        @test occursin("| ActionMissing | 1 |", action_invocation_issue_summary_markdown([missing_invocation]))
        @test occursin("ActionMissing\t1", action_invocation_issue_summary_tsv([missing_invocation]))
        @test search_action_invocation_issue_summary_records([missing_invocation], "ActionMissing") == [(status=:ActionMissing, count=1)]
        @test search_action_invocation_issue_summary_count([missing_invocation], "ActionMissing") == 1
        @test occursin("ActionMissing: 1", search_action_invocation_issue_summary_text([missing_invocation], "ActionMissing"))
        @test occursin("| ActionMissing | 1 |", search_action_invocation_issue_summary_markdown([missing_invocation], "ActionMissing"))
        @test occursin("ActionMissing\t1", search_action_invocation_issue_summary_tsv([missing_invocation], "ActionMissing"))
        @test action_invocations_any_issue([missing_invocation])
        @test_throws ArgumentError assert_no_action_invocation_issues([missing_invocation])

        disabled = Action(:save, "Dialog Save", ctx -> :dialog; enabled=ctx -> false)
        register_action!(registry, disabled; scope=:dialog)
        activate_action_scope!(registry, :dialog)
        @test active_action_scopes(registry) == [:global, :dialog]
        disabled_invocation = invoke_action!(registry, :save, context)
        @test disabled_invocation.status == ActionDisabled
        @test action_invocation_disabled(disabled_invocation)
        @test assert_action_disabled(disabled_invocation) === disabled_invocation
        @test action_summary(registry, context).disabled == 1
        @test !action_records(registry, context)[1].enabled
        @test action_category_records(registry, context)[1].disabled == 1
        @test deactivate_action_scope!(registry, :dialog)
        @test invoke_action!(registry, :save, context).status == ActionInvoked

        event = KeyEvent(Key(:s); modifiers=CTRL)
        @test resolve_action_binding(registry, event, context) == :save
        @test invoke_key_action!(registry, event, context).status == ActionInvoked
        key_diagnostics = invoke_key_action_diagnostics!(registry, event, context)
        @test key_diagnostics isa ActionWorkflowDiagnostics
        @test key_diagnostics.summary.total == 1
        @test action_workflow_diagnostics_all_invoked(key_diagnostics)
        key_workflow = invoke_key_actions!(registry, [event], context)
        @test length(key_workflow) == 1
        @test first(key_workflow).status == ActionInvoked
        key_workflow_diagnostics = invoke_key_actions_diagnostics!(registry, [event], context)
        @test key_workflow_diagnostics isa ActionWorkflowDiagnostics
        @test key_workflow_diagnostics.summary.total == 1
        @test action_workflow_diagnostics_all_invoked(key_workflow_diagnostics)
        bindings = action_binding_map(registry, context)
        @test bindings isa BindingMap
        @test binding_count(bindings) == 1
        @test binding_keys(bindings) == [(key=:s, modifiers=CTRL)]
        @test has_binding(bindings, :s; modifiers=CTRL)
        @test !has_binding(bindings, :s)
        @test binding_label(:s; modifiers=CTRL) == "Ctrl+s"
        @test resolve_binding(bindings, event) == :save
        @test resolve_binding_record(bindings, event).action == :save
        @test resolve_binding_record(bindings, event).label == "Ctrl+s"
        help_lines = action_help_lines(registry, context)
        @test length(help_lines) == 1
        @test occursin("Ctrl+s", first(help_lines))
        @test occursin("Save", first(help_lines))
        @test occursin("Ctrl+s", action_help_text(registry, context))
        help_view = action_help_view(registry, context)
        @test help_view isa HelpView
        @test first(help_view.hints).key == "Ctrl+s"
        @test first(help_view.hints).description == "Save"
        footer = action_footer(registry, context)
        @test footer isa Footer
        @test first(footer.hints).key == "Ctrl+s"
        @test first(footer.hints).description == "Save"
        surface = action_surface(registry, context; selected=1)
        @test resolve_binding(surface.bindings, event) == :save
        @test surface.layer isa BindingLayer
        @test surface.stack isa BindingStack
        @test surface.palette isa CommandPalette
        @test surface.palette_state isa CommandPaletteState
        @test surface.menu isa Menu
        @test surface.menu_state isa MenuState
        @test surface.help_view isa HelpView
        @test surface.footer isa Footer
        category_binding_maps = action_category_binding_maps(registry, context)
        @test first(category_binding_maps).category == "File"
        @test resolve_binding(first(category_binding_maps).map, event) == :save
        category_binding_layers = action_category_binding_layers(registry, context)
        @test first(category_binding_layers).category == "File"
        @test resolve_binding_layer(first(category_binding_layers).layer, event).action == :save
        category_binding_stacks = action_category_binding_stacks(registry, context)
        @test first(category_binding_stacks).category == "File"
        @test resolve_binding_stack(first(category_binding_stacks).stack, event).action == :save
        category_help_lines = action_category_help_lines(registry, context)
        @test first(category_help_lines).category == "File"
        @test first(first(category_help_lines).lines) == first(help_lines)
        category_help_text = action_category_help_text(registry, context)
        @test first(category_help_text).category == "File"
        @test occursin("Ctrl+s", first(category_help_text).text)
        category_help_views = action_category_help_views(registry, context)
        @test first(category_help_views).category == "File"
        @test first(category_help_views).view isa HelpView
        category_footers = action_category_footers(registry, context)
        @test first(category_footers).category == "File"
        @test first(category_footers).footer isa Footer
        category_surfaces = action_category_surfaces(registry, context; selected=1)
        @test first(category_surfaces).category == "File"
        @test resolve_binding(first(category_surfaces).bindings, event) == :save
        @test first(category_surfaces).layer isa BindingLayer
        @test first(category_surfaces).stack isa BindingStack
        @test first(category_surfaces).palette isa CommandPalette
        @test first(category_surfaces).palette_state isa CommandPaletteState
        @test first(category_surfaces).menu isa Menu
        @test first(category_surfaces).menu_state isa MenuState
        @test first(category_surfaces).help_view isa HelpView
        @test first(category_surfaces).footer isa Footer
        @test resolve_binding(search_action_binding_map(registry, "save", context), event) == :save
        search_layer = search_action_binding_layer(registry, "save", context; name=:search)
        @test search_layer isa BindingLayer
        @test binding_layer_name(search_layer) == :search
        @test resolve_binding_layer(search_layer, event).action == :save
        search_stack = search_action_binding_stack(registry, "save", context; name=:search_stack, layer=:search)
        @test search_stack isa BindingStack
        @test resolve_binding_stack(search_stack, event).action == :save
        @test first(search_action_help_lines(registry, "save", context)) == first(help_lines)
        @test occursin("Ctrl+s", search_action_help_text(registry, "save", context))
        search_help_view = search_action_help_view(registry, "save", context)
        @test search_help_view isa HelpView
        @test first(search_help_view.hints).key == "Ctrl+s"
        search_footer = search_action_footer(registry, "save", context)
        @test search_footer isa Footer
        @test first(search_footer.hints).key == "Ctrl+s"
        search_surface = search_action_surface(registry, "save", context; selected=1)
        @test resolve_binding(search_surface.bindings, event) == :save
        @test search_surface.layer isa BindingLayer
        @test search_surface.stack isa BindingStack
        @test search_surface.palette isa CommandPalette
        @test search_surface.palette_state isa CommandPaletteState
        @test search_surface.menu isa Menu
        @test search_surface.menu_state isa MenuState
        @test search_surface.help_view isa HelpView
        @test search_surface.footer isa Footer
        search_category_binding_maps = search_action_category_binding_maps(registry, "save", context)
        @test first(search_category_binding_maps).category == "File"
        @test resolve_binding(first(search_category_binding_maps).map, event) == :save
        search_category_binding_layers = search_action_category_binding_layers(registry, "save", context)
        @test first(search_category_binding_layers).category == "File"
        @test resolve_binding_layer(first(search_category_binding_layers).layer, event).action == :save
        search_category_binding_stacks = search_action_category_binding_stacks(registry, "save", context)
        @test first(search_category_binding_stacks).category == "File"
        @test resolve_binding_stack(first(search_category_binding_stacks).stack, event).action == :save
        search_category_help_lines = search_action_category_help_lines(registry, "save", context)
        @test first(search_category_help_lines).category == "File"
        @test first(first(search_category_help_lines).lines) == first(help_lines)
        search_category_help_text = search_action_category_help_text(registry, "save", context)
        @test first(search_category_help_text).category == "File"
        @test occursin("Ctrl+s", first(search_category_help_text).text)
        search_category_help_views = search_action_category_help_views(registry, "save", context)
        @test first(search_category_help_views).category == "File"
        @test first(search_category_help_views).view isa HelpView
        search_category_footers = search_action_category_footers(registry, "save", context)
        @test first(search_category_footers).category == "File"
        @test first(search_category_footers).footer isa Footer
        search_category_surfaces = search_action_category_surfaces(registry, "save", context; selected=1)
        @test first(search_category_surfaces).category == "File"
        @test resolve_binding(first(search_category_surfaces).bindings, event) == :save
        @test first(search_category_surfaces).layer isa BindingLayer
        @test first(search_category_surfaces).stack isa BindingStack
        @test first(search_category_surfaces).palette isa CommandPalette
        @test first(search_category_surfaces).palette_state isa CommandPaletteState
        @test first(search_category_surfaces).menu isa Menu
        @test first(search_category_surfaces).menu_state isa MenuState
        @test first(search_category_surfaces).help_view isa HelpView
        @test first(search_category_surfaces).footer isa Footer
        action_layer = action_binding_layer(registry, context; name=:actions)
        @test action_layer isa BindingLayer
        @test binding_layer_name(action_layer) == :actions
        @test binding_layer_count(action_layer) == 1
        @test resolve_binding_layer(action_layer, event).action == :save
        inactive_action_layer = action_binding_layer(registry, context; name="actions", active=false)
        @test inactive_action_layer isa BindingLayer
        @test !binding_layer_active(inactive_action_layer)
        action_stack = action_binding_stack(registry, context; name=:app, layer=:actions)
        @test action_stack isa BindingStack
        @test binding_stack_name(action_stack) == :app
        @test binding_stack_layer_names(action_stack) == [:actions]
        @test resolve_binding_stack(action_stack, event).action == :save
        inactive_action_stack = action_binding_stack(registry, context; active=false)
        @test inactive_binding_stack_layer_names(inactive_action_stack) == [:actions]
        @test resolve_binding_stack(inactive_action_stack, event) === nothing
        bind!(bindings, Binding(:q, :quit; modifiers=CTRL, description="Quit", priority=1))
        @test binding_count(bindings) == 2
        @test binding_summary(bindings) == (total=2, described=2, undocumented=0)
        @test isempty(undocumented_bindings(bindings))
        @test bindings_documented(bindings)
        @test assert_bindings_documented(bindings) === bindings
        @test (key=:q, modifiers=CTRL) in binding_keys(bindings)
        @test any(
            record -> record.key == :q &&
                record.modifiers == CTRL &&
                record.action == :quit &&
                record.description == "Quit" &&
                record.priority == 1,
            binding_records(bindings),
        )
        @test any(record -> record.description == "Quit", described_bindings(bindings))
        conflict = binding_conflict(bindings, Binding(:q, :replacement; modifiers=CTRL))
        @test conflict.action == :quit
        @test binding_conflict(bindings, Binding(:z, :none; modifiers=CTRL)) === nothing
        strict_bindings = BindingMap()
        @test bind_strict!(strict_bindings, Binding(:q, :quit; modifiers=CTRL, description="Quit")) === strict_bindings
        @test resolve_binding(strict_bindings, KeyEvent(Key(:q); modifiers=CTRL)) == :quit
        @test_throws ArgumentError bind_strict!(strict_bindings, Binding(:q, :replacement; modifiers=CTRL))
        @test resolve_binding(strict_bindings, KeyEvent(Key(:q); modifiers=CTRL)) == :quit
        layered_bindings = BindingMap()
        bind!(layered_bindings, Binding(:q, :screen_quit; modifiers=CTRL, description="Screen quit"))
        bind!(layered_bindings, Binding(:h, :help; description="Help"))
        keymap_conflicts = binding_conflicts(bindings, layered_bindings)
        @test length(keymap_conflicts) == 1
        @test only(keymap_conflicts).label == "Ctrl+q"
        @test only(keymap_conflicts).existing.action == :quit
        @test only(keymap_conflicts).incoming.action == :screen_quit
        @test binding_conflict_labels(bindings, layered_bindings) == ["Ctrl+q"]
        @test has_binding_conflicts(bindings, layered_bindings)
        @test !has_binding_conflicts(BindingMap(), layered_bindings)
        @test assert_no_binding_conflicts(BindingMap(), layered_bindings) === layered_bindings
        @test_throws ArgumentError assert_no_binding_conflicts(bindings, layered_bindings)
        skipped_bindings = merged_bindings(bindings, layered_bindings; conflict=:skip)
        @test resolve_binding(skipped_bindings, KeyEvent(Key(:q); modifiers=CTRL)) == :quit
        @test resolve_binding(skipped_bindings, KeyEvent(Key(:h))) == :help
        replaced_bindings = merged_bindings(bindings, layered_bindings)
        @test resolve_binding(replaced_bindings, KeyEvent(Key(:q); modifiers=CTRL)) == :screen_quit
        @test merge_bindings!(BindingMap(), layered_bindings; conflict=:error) isa BindingMap
        @test_throws ArgumentError merge_bindings!(merged_bindings(bindings), layered_bindings; conflict=:error)
        @test_throws ArgumentError merged_bindings(bindings, layered_bindings; conflict=:unknown)
        global_layer = BindingLayer(:global, bindings)
        screen_layer = BindingLayer("screen", layered_bindings)
        mutable_layer = BindingLayer(:mutable)
        @test bind!(mutable_layer, Binding(:m, :mutable; description="Mutable")) === mutable_layer
        @test has_binding(mutable_layer, :m)
        @test bind_strict!(mutable_layer, Binding(:n, :next; description="Next")) === mutable_layer
        @test_throws ArgumentError bind_strict!(mutable_layer, Binding(:n, :duplicate; description="Duplicate"))
        @test merge_bindings!(mutable_layer, screen_layer; conflict=:skip) === mutable_layer
        @test has_binding(mutable_layer, :h)
        @test unbind!(mutable_layer, :m)
        @test !has_binding(mutable_layer, :m)
        @test binding_layer_name(screen_layer) == :screen
        @test binding_layer_map(screen_layer) === layered_bindings
        @test binding_layer_active(screen_layer)
        @test binding_layer_count(screen_layer) == 2
        @test binding_layer_summary(screen_layer) == (layer=:screen, total=2, described=2, undocumented=0)
        @test binding_layers_summary(global_layer, screen_layer)[2].layer == :screen
        @test (key=:h, modifiers=NONE, layer=:screen) in binding_layer_keys(screen_layer)
        @test has_binding(screen_layer, :h)
        @test !has_binding(screen_layer, :missing)
        @test binding_layer_record(screen_layer, :h).layer == :screen
        @test binding_layer_record(screen_layer, :h).label == "h"
        @test binding_layer_record(screen_layer, :missing) === nothing
        @test binding_layer_documented(screen_layer)
        @test isempty(undocumented_binding_layer_records(screen_layer))
        @test assert_binding_layer_documented(screen_layer) === screen_layer
        @test binding_layers_documented(global_layer, screen_layer)
        @test isempty(undocumented_binding_layers_records(global_layer, screen_layer))
        @test assert_binding_layers_documented(global_layer, screen_layer) == (global_layer, screen_layer)
        @test any(record -> record.layer == :screen && record.key == :h, binding_layer_records(screen_layer))
        @test any(record -> record.layer == :screen && record.label == "h", binding_layer_display_records(screen_layer))
        @test all(record -> record.layer == :screen && !isempty(record.description), described_binding_layer_display_records(screen_layer))
        @test "screen: h  Help" in binding_layer_help_lines(screen_layer)
        @test occursin("screen: h  Help", binding_layer_help_text(screen_layer))
        @test occursin("\"schema_version\": 1", binding_layer_help_json(screen_layer))
        @test occursin("\"layer\": \"screen\"", binding_layer_help_json(screen_layer))
        @test startswith(binding_layer_help_markdown(screen_layer), "| `layer` | `label` | `action` |")
        @test startswith(binding_layer_help_tsv(screen_layer), "layer\tlabel\taction\tdescription\tpriority\n")
        @test "h  Help" in binding_layer_help_lines(screen_layer; prefix=false)
        @test "screen: h  Help" in binding_layers_help_lines(global_layer, screen_layer)
        @test occursin("screen: h  Help", binding_layers_help_text(global_layer, screen_layer))
        @test "h  Help" in binding_layers_help_lines(global_layer, screen_layer; prefix=false)
        layer_conflicts = binding_layer_conflicts(global_layer, screen_layer)
        @test length(layer_conflicts) == 1
        @test only(layer_conflicts).existing_layer == :global
        @test only(layer_conflicts).incoming_layer == :screen
        @test only(layer_conflicts).label == "Ctrl+q"
        @test binding_layer_conflict_labels(global_layer, screen_layer) == ["Ctrl+q"]
        @test has_binding_layer_conflicts(global_layer, screen_layer)
        @test !has_binding_layer_conflicts(BindingLayer(:empty), screen_layer)
        @test assert_no_binding_layer_conflicts(BindingLayer(:empty), screen_layer) === screen_layer
        @test_throws ArgumentError assert_no_binding_layer_conflicts(global_layer, screen_layer)
        layered_map = merged_binding_layers(global_layer, screen_layer; conflict=:skip)
        @test resolve_binding(layered_map, KeyEvent(Key(:q); modifiers=CTRL)) == :quit
        @test resolve_binding(layered_map, KeyEvent(Key(:h))) == :help
        binding_stack = BindingStack(:app, screen_layer, global_layer)
        @test binding_stack_name(binding_stack) == :app
        @test binding_stack_count(binding_stack) == 2
        @test binding_stack_binding_count(binding_stack) == binding_layer_count(screen_layer) + binding_layer_count(global_layer)
        @test first(binding_stack_layers(binding_stack)) === screen_layer
        @test binding_stack_layer_names(binding_stack) == [:screen, :global]
        @test binding_stack_layer(binding_stack, :screen) === screen_layer
        @test binding_stack_layer(binding_stack, "global") === global_layer
        @test binding_stack_layer(binding_stack, :missing) === nothing
        @test has_binding_layer(binding_stack, :screen)
        @test has_active_binding_layer(binding_stack, :screen)
        @test !has_binding_layer(binding_stack, :missing)
        @test !has_active_binding_layer(binding_stack, :missing)
        @test assert_binding_stack_layer(binding_stack, :screen) === screen_layer
        @test_throws ArgumentError assert_binding_stack_layer(binding_stack, :missing)
        @test active_binding_stack_count(binding_stack) == 2
        @test inactive_binding_stack_count(binding_stack) == 0
        @test active_binding_stack_binding_count(binding_stack) == binding_stack_binding_count(binding_stack)
        @test active_binding_stack_layer_names(binding_stack) == [:screen, :global]
        @test isempty(inactive_binding_stack_layer_names(binding_stack))
        @test binding_stack_summary(binding_stack).stack == :app
        @test (key=:h, modifiers=NONE, layer=:screen, stack=:app) in binding_stack_keys(binding_stack)
        @test any(record -> record.stack == :app && record.layer == :screen && record.key == :h, binding_stack_records(binding_stack))
        @test any(record -> record.stack == :app && record.layer == :screen && record.label == "h", binding_stack_display_records(binding_stack))
        @test all(record -> record.stack == :app && !isempty(record.description), described_binding_stack_display_records(binding_stack))
        stack_snapshot = binding_stack_snapshot(binding_stack)
        @test stack_snapshot isa BindingStackSnapshot
        @test stack_snapshot.name == :app
        @test stack_snapshot.layers == [:screen, :global]
        @test stack_snapshot.active_layers == [:screen, :global]
        @test stack_snapshot.inactive_layers == Symbol[]
        @test stack_snapshot.layer_count == 2
        @test stack_snapshot.active_count == 2
        @test stack_snapshot.binding_count == binding_stack_binding_count(binding_stack)
        @test stack_snapshot.conflict_count == 1
        @test stack_snapshot.conflict_labels == ["Ctrl+q"]
        @test binding_stack_snapshot_record(stack_snapshot).name == :app
        @test binding_stack_snapshot_record(binding_stack).conflict_count == 1
        @test occursin("BindingStackSnapshot", sprint(show, stack_snapshot))
        @test binding_stack_documented(binding_stack)
        @test isempty(undocumented_binding_stack_records(binding_stack))
        @test assert_binding_stack_documented(binding_stack) === binding_stack
        stack_conflicts = binding_stack_conflicts(binding_stack)
        @test length(stack_conflicts) == 1
        @test only(stack_conflicts).stack == :app
        @test only(stack_conflicts).existing_layer == :screen
        @test only(stack_conflicts).incoming_layer == :global
        @test binding_stack_conflict_labels(binding_stack) == ["Ctrl+q"]
        @test has_binding_stack_conflicts(binding_stack)
        @test_throws ArgumentError assert_no_binding_stack_conflicts(binding_stack)
        @test "screen: h  Help" in binding_stack_help_lines(binding_stack)
        @test occursin("screen: h  Help", binding_stack_help_text(binding_stack))
        @test occursin("\"stack\": \"app\"", binding_stack_help_json(binding_stack))
        @test startswith(binding_stack_help_markdown(binding_stack), "| `stack` | `layer` | `label` |")
        @test startswith(binding_stack_help_tsv(binding_stack), "stack\tlayer\tlabel\taction\tdescription\tpriority\n")
        @test resolve_binding_stack(binding_stack, KeyEvent(Key(:q); modifiers=CTRL)).action == :screen_quit
        @test resolve_binding(merged_binding_stack(binding_stack; conflict=:skip), KeyEvent(Key(:q); modifiers=CTRL)) == :screen_quit
        inactive_screen = BindingLayer(:screen, layered_bindings; active=false)
        inactive_stack = BindingStack(:inactive_app, inactive_screen, global_layer)
        @test !binding_layer_active(inactive_screen)
        @test active_binding_stack_layer_names(inactive_stack) == [:global]
        @test inactive_binding_stack_layer_names(inactive_stack) == [:screen]
        @test inactive_binding_stack_count(inactive_stack) == 1
        @test !has_active_binding_layer(inactive_stack, :screen)
        @test binding_stack_layer(inactive_stack, :screen) === inactive_screen
        @test resolve_binding_stack(inactive_stack, KeyEvent(Key(:q); modifiers=CTRL)).action == :quit
        @test binding_stack_conflicts(inactive_stack) == []
        @test activate_binding_layer!(inactive_stack, :screen).active
        @test has_active_binding_layer(inactive_stack, :screen)
        @test deactivate_binding_layer!(inactive_stack, :screen).active == false
        @test_throws ArgumentError activate_binding_layer!(inactive_stack, :missing)
        conflict_free_stack = BindingStack(:conflict_free, screen_layer)
        @test !has_binding_stack_conflicts(conflict_free_stack)
        @test assert_no_binding_stack_conflicts(conflict_free_stack) === conflict_free_stack
        mutable_stack = BindingStack("mutable")
        @test push_binding_layer!(mutable_stack, global_layer) === mutable_stack
        @test prepend_binding_layer!(mutable_stack, screen_layer) === mutable_stack
        @test first(binding_stack_layers(mutable_stack)) === screen_layer
        replacement_screen = BindingLayer(:screen)
        bind!(replacement_screen, Binding(:r, :replacement; description="Replacement"))
        @test replace_binding_layer!(mutable_stack, replacement_screen) === screen_layer
        @test binding_stack_layer(mutable_stack, :screen) === replacement_screen
        @test replace_binding_layer!(mutable_stack, BindingLayer(:missing)) === nothing
        modal_layer = BindingLayer(:modal)
        @test upsert_binding_layer!(mutable_stack, modal_layer; position=:prepend) === mutable_stack
        @test first(binding_stack_layers(mutable_stack)) === modal_layer
        replacement_modal = BindingLayer(:modal)
        @test upsert_binding_layer!(mutable_stack, replacement_modal) === mutable_stack
        @test binding_stack_layer(mutable_stack, :modal) === replacement_modal
        @test_throws ArgumentError upsert_binding_layer!(mutable_stack, BindingLayer(:bad); position=:middle)
        @test remove_binding_layer!(mutable_stack, :screen) === screen_layer
        @test binding_stack_layer(mutable_stack, :screen) === nothing
        @test remove_binding_layer!(mutable_stack, :missing) === nothing
        @test resolve_binding_layer(screen_layer, KeyEvent(Key(:h))).layer == :screen
        @test resolve_binding_layer(screen_layer, KeyEvent(Key(:h))).action == :help
        @test resolve_binding_layers(screen_layer, global_layer; event=KeyEvent(Key(:q); modifiers=CTRL)).action == :screen_quit
        @test resolve_binding_layers(global_layer, screen_layer; event=KeyEvent(Key(:q); modifiers=CTRL)).action == :quit
        @test resolve_binding_layers(screen_layer, global_layer; event=KeyEvent(Key(:missing))) === nothing
        undocumented_layer_map = BindingMap()
        bind!(undocumented_layer_map, Binding(:u, :undocumented))
        undocumented_layer = BindingLayer(:undocumented, undocumented_layer_map)
        @test !binding_layer_documented(undocumented_layer)
        @test only(undocumented_binding_layer_records(undocumented_layer)).layer == :undocumented
        @test_throws ArgumentError assert_binding_layer_documented(undocumented_layer)
        @test !binding_layers_documented(screen_layer, undocumented_layer)
        @test only(undocumented_binding_layers_records(screen_layer, undocumented_layer)).layer == :undocumented
        @test_throws ArgumentError assert_binding_layers_documented(screen_layer, undocumented_layer)
        undocumented_stack = BindingStack(:undocumented_stack, screen_layer, undocumented_layer)
        @test !binding_stack_documented(undocumented_stack)
        @test only(undocumented_binding_stack_records(undocumented_stack)).layer == :undocumented
        @test_throws ArgumentError assert_binding_stack_documented(undocumented_stack)
        quit_record = binding_record(bindings, :q; modifiers=CTRL)
        @test quit_record.action == :quit
        @test quit_record.description == "Quit"
        @test binding_label(quit_record) == "Ctrl+q"
        @test any(
            record -> record.label == "Ctrl+q" && record.description == "Quit",
            binding_display_records(bindings),
        )
        @test any(
            record -> record.label == "Ctrl+q" && record.description == "Quit",
            described_binding_display_records(bindings),
        )
        @test binding_label(Binding(:x, :cut; modifiers=CTRL | SHIFT)) == "Ctrl+Shift+x"
        @test binding_help_line(quit_record) == "Ctrl+q  Quit"
        @test binding_help_line(quit_record; separator=" - ") == "Ctrl+q - Quit"
        @test "Ctrl+q  Quit" in binding_help_lines(bindings)
        @test "Ctrl+q - Quit" in binding_help_lines(bindings; separator=" - ")
        @test occursin("\"label\": \"Ctrl+q\"", binding_help_json(bindings))
        @test startswith(binding_help_markdown(bindings), "| `label` | `action` | `description` |")
        @test startswith(binding_help_tsv(bindings), "label\taction\tdescription\tpriority\n")
        @test occursin("Ctrl+q  Quit", binding_help_text(bindings))
        @test occursin("Ctrl+q - Quit", binding_help_text(bindings; separator=" - "))
        @test binding_help_line(Binding(:x, :cut; modifiers=CTRL | SHIFT, description="Cut")) == "Ctrl+Shift+x  Cut"
        @test binding_record(bindings, :missing; modifiers=CTRL) === nothing
        @test resolve_binding(bindings, KeyEvent(Key(:q); modifiers=CTRL)) == :quit
        @test unbind!(bindings, :q; modifiers=CTRL)
        @test binding_count(bindings) == 1
        @test binding_summary(bindings).total == 1
        @test !has_binding(bindings, :q; modifiers=CTRL)
        @test !((key=:q, modifiers=CTRL) in binding_keys(bindings))
        @test all(!isempty(record.description) for record in described_bindings(bindings))
        @test all(!isempty(record.description) for record in described_binding_display_records(bindings))
        @test isempty(undocumented_bindings(bindings))
        @test bindings_documented(bindings)

        undocumented = BindingMap()
        bind!(undocumented, Binding(:u, :undocumented; modifiers=CTRL))
        @test !bindings_documented(undocumented)
        @test_throws ArgumentError assert_bindings_documented(undocumented)
        undocumented_error = try
            assert_bindings_documented(undocumented)
            ""
        catch error
            sprint(showerror, error)
        end
        @test occursin("Ctrl+u", undocumented_error)

        actions = available_actions(registry, context)
        @test first(actions).action.id == :save
        items = action_command_items(registry, context)
        @test first(items) isa CommandItem
        command_sections = action_command_sections(registry, context)
        @test first(command_sections).category == "File"
        @test first(command_sections).items[1].action == :save
        category_palettes = action_category_command_palettes(registry, context)
        @test first(category_palettes).category == "File"
        @test first(category_palettes).palette isa CommandPalette
        category_palette_sessions = action_category_command_palette_sessions(registry, context; query="save")
        @test first(category_palette_sessions).category == "File"
        @test first(category_palette_sessions).palette isa CommandPalette
        @test first(category_palette_sessions).state isa CommandPaletteState
        @test command_palette_query(first(category_palette_sessions).state) == "save"
        menu_items = action_menu_items(registry, context)
        @test first(menu_items) isa MenuItem
        @test first(menu_items).message == :save
        @test first(menu_items).shortcut == "Ctrl+s"
        @test action_menu(registry, context) isa Menu
        menu_session = action_menu_session(registry, context; selected=1)
        @test menu_session.menu isa Menu
        @test menu_session.state isa MenuState
        @test invoke_activated_action!(registry, menu_session.menu, menu_session.state, context).status == ActionInvoked
        menu_sections = action_menu_sections(registry, context)
        @test first(menu_sections).category == "File"
        @test first(menu_sections).items[1].message == :save
        category_menus = action_category_menus(registry, context)
        @test first(category_menus).category == "File"
        @test first(category_menus).menu isa Menu
        category_menu_sessions = action_category_menu_sessions(registry, context; selected=1)
        @test first(category_menu_sessions).category == "File"
        @test first(category_menu_sessions).menu isa Menu
        @test first(category_menu_sessions).state isa MenuState
        @test invoke_selected_action!(registry, nothing, context) === nothing
        @test invoke_selected_action!(registry, :save, context).status == ActionInvoked
        @test invoke_selected_action!(registry, "save", context).status == ActionInvoked
        @test_throws ArgumentError invoke_selected_action!(registry, 1, context)
        selected_empty_diagnostics = invoke_selected_action_diagnostics!(registry, nothing, context)
        @test selected_empty_diagnostics isa ActionWorkflowDiagnostics
        @test selected_empty_diagnostics.summary.total == 0
        selected_diagnostics = invoke_selected_action_diagnostics!(registry, :save, context)
        @test selected_diagnostics.summary.total == 1
        @test action_workflow_diagnostics_all_invoked(selected_diagnostics)
        @test invoke_activated_action!(registry, action_menu(registry, context), MenuState(selected=1), context).status == ActionInvoked
        @test invoke_activated_action!(registry, action_menu(registry, context), MenuState(), context) === nothing
        activated_diagnostics = invoke_activated_action_diagnostics!(registry, action_menu(registry, context), MenuState(selected=1), context)
        @test activated_diagnostics.summary.total == 1
        @test action_workflow_diagnostics_all_invoked(activated_diagnostics)
        activated_empty_diagnostics = invoke_activated_action_diagnostics!(registry, action_menu(registry, context), MenuState(), context)
        @test activated_empty_diagnostics.summary.total == 0
        workflow_invocations = invoke_actions!(registry, [:save, nothing, "save"], context)
        @test length(workflow_invocations) == 2
        @test all(action_invocation_invoked, workflow_invocations)
        workflow_dispatch_diagnostics = invoke_actions_diagnostics!(registry, [:save, nothing, "save"], context)
        @test workflow_dispatch_diagnostics isa ActionWorkflowDiagnostics
        @test workflow_dispatch_diagnostics.summary.total == 2
        @test action_workflow_diagnostics_all_invoked(workflow_dispatch_diagnostics)
        matching_menu_items = search_action_menu_items(registry, "save", context)
        @test first(matching_menu_items).message == :save
        @test search_action_menu(registry, "Ctrl+s", context) isa Menu
        matching_menu_session = search_action_menu_session(registry, "Ctrl+s", context; selected=1)
        @test matching_menu_session.menu isa Menu
        @test matching_menu_session.state isa MenuState
        matching_menu_sections = search_action_menu_sections(registry, "File", context)
        @test first(matching_menu_sections).category == "File"
        matching_category_menus = search_action_category_menus(registry, "save", context)
        @test first(matching_category_menus).menu isa Menu
        matching_category_menu_sessions = search_action_category_menu_sessions(registry, "save", context; selected=1)
        @test first(matching_category_menu_sessions).menu isa Menu
        @test first(matching_category_menu_sessions).state isa MenuState
        matching_command_items = search_action_command_items(registry, "save", context)
        @test first(matching_command_items) isa CommandItem
        @test first(matching_command_items).action == :save
        @test search_action_command_palette(registry, "File", context) isa CommandPalette
        matching_palette_session = search_action_command_palette_session(registry, "File", context; palette_query="save")
        @test matching_palette_session.palette isa CommandPalette
        @test matching_palette_session.state isa CommandPaletteState
        @test command_palette_query(matching_palette_session.state) == "save"
        matching_command_sections = search_action_command_sections(registry, "File", context)
        @test first(matching_command_sections).category == "File"
        matching_category_palettes = search_action_category_command_palettes(registry, "save", context)
        @test first(matching_category_palettes).palette isa CommandPalette
        matching_category_palette_sessions = search_action_category_command_palette_sessions(registry, "save", context; palette_query="save")
        @test first(matching_category_palette_sessions).palette isa CommandPalette
        @test first(matching_category_palette_sessions).state isa CommandPaletteState
        palette_from_registry = action_command_palette(registry, context)
        @test palette_from_registry isa CommandPalette
        palette_session = action_command_palette_session(registry, context; query="save")
        @test palette_session.palette isa CommandPalette
        @test palette_session.state isa CommandPaletteState
        @test palette_session.state.open
        @test command_palette_query(palette_session.state) == "save"
        @test command_palette_selected_command(palette_session.palette, palette_session.state).action == :save
        @test invoke_activated_action!(registry, palette_session.palette, palette_session.state, context).status == ActionInvoked
        closed_palette_session = action_command_palette_session(registry, context; open=false)
        @test !closed_palette_session.state.open
        palette = CommandPalette(items)
        palette_state = CommandPaletteState(open=false)
        open_palette!(palette_state)
        @test palette_state.open
        @test command_palette_query(palette_state) == ""
        @test set_command_palette_query!(palette_state, palette, "save"; record=false) === palette_state
        @test command_palette_query(palette_state) == "save"
        @test first(command_palette_filtered_commands(palette, palette_state)).action == :save
        @test command_palette_selected_command(palette, palette_state).action == :save
        @test select_next_command!(palette_state, palette) === palette_state
        @test select_previous_command!(palette_state, palette) === palette_state
        @test select_command!(palette_state, palette, 1) === palette_state
        @test register_command_palette_semantic_handlers! isa Function
        @test activate(palette, palette_state) == :save
        @test invoke_activated_action!(registry, palette, palette_state, context).status == ActionInvoked
        close_palette!(palette_state)
        @test !palette_state.open

        failing = Action(:fail, "Fail", ctx -> error("boom"))
        register_action!(registry, failing)
        failed_invocation = invoke_action!(registry, :fail, context)
        @test failed_invocation.status == ActionFailed
        @test action_invocation_failed(failed_invocation)
        @test assert_action_failed(failed_invocation) === failed_invocation
        @test !action_invocations_all_invoked([failed_invocation])
        @test action_invocation_failures([failed_invocation]) == [failed_invocation]
        @test action_invocations_any_failed([failed_invocation])
        @test action_invocation_issues([failed_invocation]) == [failed_invocation]
        @test first(action_invocation_issue_records([failed_invocation])).status == :ActionFailed
        @test occursin("ActionFailed", action_invocation_issues_text([failed_invocation]))
        @test occursin("boom", action_invocation_issues_markdown([failed_invocation]; columns=(:error_message,)))
        @test occursin("ErrorException", action_invocation_issues_tsv([failed_invocation]; columns=(:error_type,)))
        @test action_invocation_issue_summary_records([failed_invocation]) == [(status=:ActionFailed, count=1)]
        @test action_invocations_any_issue([failed_invocation])
        @test_throws ArgumentError assert_action_invocations_invoked([failed_invocation])
        @test_throws ArgumentError assert_no_action_invocation_failures([failed_invocation])
        @test_throws ArgumentError assert_no_action_invocation_issues([failed_invocation])
        @test action_invocation_record(failed_invocation).error_type == :ErrorException
        @test occursin("boom", action_invocation_markdown(failed_invocation; columns=(:error_message,)))
        @test occursin("ErrorException", action_invocation_tsv(failed_invocation; columns=(:error_type,)))
        @test occursin("boom", action_invocation_text(failed_invocation))
        failed_workflow_diagnostics = action_workflow_diagnostics([failed_invocation])
        @test length(failed_workflow_diagnostics.issues) == 1
        @test length(failed_workflow_diagnostics.failures) == 1
        @test action_workflow_diagnostics_record(failed_workflow_diagnostics).failure_count == 1
        @test first(action_workflow_diagnostics_record(failed_workflow_diagnostics).issues).status == :ActionFailed
        @test first(action_workflow_diagnostics_record(failed_workflow_diagnostics).failures).status == :ActionFailed
        @test action_workflow_diagnostics_summary(failed_workflow_diagnostics).total == 1
        @test action_workflow_diagnostics_status_count(failed_workflow_diagnostics, ActionFailed) == 1
        @test action_workflow_diagnostics_issue_status_count(failed_workflow_diagnostics, "ActionFailed") == 1
        @test action_workflow_diagnostics_failure_status_count(failed_workflow_diagnostics, :ActionFailed) == 1
        @test action_workflow_diagnostics_invoked_count(failed_workflow_diagnostics) == 0
        @test action_workflow_diagnostics_missing_count(failed_workflow_diagnostics) == 0
        @test action_workflow_diagnostics_disabled_count(failed_workflow_diagnostics) == 0
        @test action_workflow_diagnostics_failed_count(failed_workflow_diagnostics) == 1
        @test action_workflow_diagnostics_total_count(failed_workflow_diagnostics) == 1
        @test action_workflow_diagnostics_issue_count(failed_workflow_diagnostics) == 1
        @test action_workflow_diagnostics_failure_count(failed_workflow_diagnostics) == 1
        @test !action_workflow_diagnostics_bundle_all_invoked(failed_workflow_diagnostics)
        @test action_workflow_diagnostics_bundle_has_issues(failed_workflow_diagnostics)
        @test action_workflow_diagnostics_bundle_has_failures(failed_workflow_diagnostics)
        @test_throws ArgumentError assert_action_workflow_diagnostics_bundle_all_invoked(failed_workflow_diagnostics)
        @test_throws ArgumentError assert_action_workflow_diagnostics_bundle_no_issues(failed_workflow_diagnostics)
        @test_throws ArgumentError assert_action_workflow_diagnostics_bundle_no_failures(failed_workflow_diagnostics)
        @test action_workflow_diagnostics_summary_records(failed_workflow_diagnostics) == [(status=:ActionFailed, count=1)]
        @test occursin("ActionFailed: 1", action_workflow_diagnostics_summary_text(failed_workflow_diagnostics))
        @test occursin("| ActionFailed | 1 |", action_workflow_diagnostics_summary_markdown(failed_workflow_diagnostics))
        @test occursin("ActionFailed\t1", action_workflow_diagnostics_summary_tsv(failed_workflow_diagnostics))
        @test action_workflow_diagnostics_has_failures(failed_workflow_diagnostics)
        @test action_workflow_diagnostics_has_failures([failed_invocation])
        @test !action_workflow_diagnostics_all_invoked(failed_workflow_diagnostics)
        @test !action_workflow_diagnostics_all_invoked([failed_invocation])
        @test action_workflow_diagnostics_failures(failed_workflow_diagnostics) == [failed_invocation]
        @test action_workflow_diagnostics_failures(failed_workflow_diagnostics) !== failed_workflow_diagnostics.failures
        @test action_workflow_diagnostics_failures([failed_invocation]) == [failed_invocation]
        @test first(action_workflow_diagnostics_failure_records(failed_workflow_diagnostics)).status == :ActionFailed
        @test first(action_workflow_diagnostics_failure_records([failed_invocation])).status == :ActionFailed
        @test occursin("ActionFailed", action_workflow_diagnostics_failures_text(failed_workflow_diagnostics))
        @test occursin("| fail | ActionFailed |", action_workflow_diagnostics_failures_markdown(failed_workflow_diagnostics; columns=(:id, :status)))
        @test occursin("fail\tActionFailed", action_workflow_diagnostics_failures_tsv(failed_workflow_diagnostics; columns=(:id, :status)))
        @test first(search_action_workflow_diagnostics_failure_records(failed_workflow_diagnostics, "ActionFailed")).id == :fail
        @test search_action_workflow_diagnostics_failure_count(failed_workflow_diagnostics, "ActionFailed") == 1
        @test occursin("ActionFailed", search_action_workflow_diagnostics_failures_text(failed_workflow_diagnostics, "ActionFailed"))
        @test occursin("| fail | ActionFailed |", search_action_workflow_diagnostics_failures_markdown(failed_workflow_diagnostics, "ActionFailed"; columns=(:id, :status)))
        @test occursin("fail\tActionFailed", search_action_workflow_diagnostics_failures_tsv(failed_workflow_diagnostics, "ActionFailed"; columns=(:id, :status)))
        @test action_workflow_diagnostics_failure_summary(failed_workflow_diagnostics).total == 1
        @test action_workflow_diagnostics_failure_summary_records(failed_workflow_diagnostics) == [(status=:ActionFailed, count=1)]
        @test occursin("ActionFailed: 1", action_workflow_diagnostics_failure_summary_text(failed_workflow_diagnostics))
        @test occursin("| ActionFailed | 1 |", action_workflow_diagnostics_failure_summary_markdown(failed_workflow_diagnostics))
        @test occursin("ActionFailed\t1", action_workflow_diagnostics_failure_summary_tsv(failed_workflow_diagnostics))
        @test search_action_workflow_diagnostics_failure_summary_records(failed_workflow_diagnostics, "ActionFailed") == [(status=:ActionFailed, count=1)]
        @test search_action_workflow_diagnostics_failure_summary_count(failed_workflow_diagnostics, "ActionFailed") == 1
        @test occursin("ActionFailed: 1", search_action_workflow_diagnostics_failure_summary_text(failed_workflow_diagnostics, "ActionFailed"))
        @test occursin("| ActionFailed | 1 |", search_action_workflow_diagnostics_failure_summary_markdown(failed_workflow_diagnostics, "ActionFailed"))
        @test occursin("ActionFailed\t1", search_action_workflow_diagnostics_failure_summary_tsv(failed_workflow_diagnostics, "ActionFailed"))
        @test action_workflow_diagnostics_issues(failed_workflow_diagnostics) == [failed_invocation]
        @test action_workflow_diagnostics_issues(failed_workflow_diagnostics) !== failed_workflow_diagnostics.issues
        @test action_workflow_diagnostics_issues([failed_invocation]) == [failed_invocation]
        @test first(action_workflow_diagnostics_issue_records(failed_workflow_diagnostics)).status == :ActionFailed
        @test first(action_workflow_diagnostics_issue_records([failed_invocation])).status == :ActionFailed
        @test occursin("ActionFailed", action_workflow_diagnostics_issues_text(failed_workflow_diagnostics))
        @test occursin("| fail | ActionFailed |", action_workflow_diagnostics_issues_markdown(failed_workflow_diagnostics; columns=(:id, :status)))
        @test occursin("fail\tActionFailed", action_workflow_diagnostics_issues_tsv(failed_workflow_diagnostics; columns=(:id, :status)))
        @test first(search_action_workflow_diagnostics_issue_records(failed_workflow_diagnostics, "ActionFailed")).id == :fail
        @test search_action_workflow_diagnostics_issue_count(failed_workflow_diagnostics, "ActionFailed") == 1
        @test occursin("ActionFailed", search_action_workflow_diagnostics_issues_text(failed_workflow_diagnostics, "ActionFailed"))
        @test occursin("| fail | ActionFailed |", search_action_workflow_diagnostics_issues_markdown(failed_workflow_diagnostics, "ActionFailed"; columns=(:id, :status)))
        @test occursin("fail\tActionFailed", search_action_workflow_diagnostics_issues_tsv(failed_workflow_diagnostics, "ActionFailed"; columns=(:id, :status)))
        @test action_workflow_diagnostics_issue_summary(failed_workflow_diagnostics).total == 1
        @test action_workflow_diagnostics_issue_summary_records(failed_workflow_diagnostics) == [(status=:ActionFailed, count=1)]
        @test occursin("ActionFailed: 1", action_workflow_diagnostics_issue_summary_text(failed_workflow_diagnostics))
        @test occursin("| ActionFailed | 1 |", action_workflow_diagnostics_issue_summary_markdown(failed_workflow_diagnostics))
        @test occursin("ActionFailed\t1", action_workflow_diagnostics_issue_summary_tsv(failed_workflow_diagnostics))
        @test search_action_workflow_diagnostics_issue_summary_records(failed_workflow_diagnostics, "ActionFailed") == [(status=:ActionFailed, count=1)]
        @test search_action_workflow_diagnostics_issue_summary_count(failed_workflow_diagnostics, "ActionFailed") == 1
        @test occursin("ActionFailed: 1", search_action_workflow_diagnostics_issue_summary_text(failed_workflow_diagnostics, "ActionFailed"))
        @test occursin("| ActionFailed | 1 |", search_action_workflow_diagnostics_issue_summary_markdown(failed_workflow_diagnostics, "ActionFailed"))
        @test occursin("ActionFailed\t1", search_action_workflow_diagnostics_issue_summary_tsv(failed_workflow_diagnostics, "ActionFailed"))
        @test action_workflow_diagnostics_has_issues(failed_workflow_diagnostics)
        @test action_workflow_diagnostics_has_issues([failed_invocation])
        @test_throws ArgumentError assert_action_workflow_diagnostics_all_invoked(failed_workflow_diagnostics)
        @test_throws ArgumentError assert_action_workflow_diagnostics_all_invoked([failed_invocation])
        @test_throws ArgumentError assert_action_workflow_diagnostics_no_failures(failed_workflow_diagnostics)
        @test_throws ArgumentError assert_action_workflow_diagnostics_no_failures([failed_invocation])
        @test_throws ArgumentError assert_action_workflow_diagnostics_no_issues(failed_workflow_diagnostics)
        @test_throws ArgumentError assert_action_workflow_diagnostics_no_issues([failed_invocation])
        @test !isempty(action_errors(registry))
        error_records = action_error_records(registry)
        @test length(error_records) == 1
        @test error_records[1].index == 1
        @test error_records[1].type == :ErrorException
        @test occursin("boom", error_records[1].message)
        @test action_error_summary(registry).total == 1
        error_summary_records = action_error_summary_records(registry)
        @test error_summary_records == [(type=:ErrorException, count=1)]
        @test occursin("| ErrorException | 1 |", action_error_summary_markdown(registry))
        @test occursin("ErrorException\t1", action_error_summary_tsv(registry))
        @test occursin("ErrorException: 1", action_error_summary_text(registry))
        matching_error_summary_records = search_action_error_summary_records(registry, "ErrorException")
        @test matching_error_summary_records == [(type=:ErrorException, count=1)]
        @test search_action_error_summary_count(registry, "Error") == 1
        @test isempty(search_action_error_summary_records(registry, "BoundsError"))
        @test occursin("ErrorException", search_action_error_summary_markdown(registry, "Error"; columns=(:type,)))
        @test occursin("ErrorException\t1", search_action_error_summary_tsv(registry, "1"))
        @test startswith(search_action_error_summary_text(registry, "Error"), "Action errors (1) matching")
        @test search_action_error_summary_text(registry, "BoundsError") == "No matching action error summary"
        error_markdown = action_error_records_markdown(registry; columns=(:index, :type))
        @test startswith(error_markdown, "| `index` | `type` |")
        @test occursin("| 1 | ErrorException |", error_markdown)
        error_tsv = action_error_records_tsv(registry; columns=(:type, :message))
        @test startswith(error_tsv, "type\tmessage\n")
        @test occursin("ErrorException", error_tsv)
        error_text = action_error_text(registry)
        @test startswith(error_text, "Action errors (1)")
        @test occursin("boom", error_text)
        @test occursin("ErrorException", action_error_text(registry; newline=" | "))
        matching_error_records = search_action_error_records(registry, "boom")
        @test length(matching_error_records) == 1
        @test search_action_error_count(registry, "ErrorException") == 1
        @test isempty(search_action_error_records(registry, "missing-error"))
        @test occursin("ErrorException", search_action_error_records_markdown(registry, "boom"; columns=(:type,)))
        @test occursin("boom", search_action_error_records_tsv(registry, "Error"; columns=(:message,)))
        @test startswith(search_action_error_text(registry, "boom"), "Action errors (1) matching")
        @test search_action_error_text(registry, "missing-error") == "No matching action errors"
        @test_throws ArgumentError action_error_records_markdown(registry; columns=())
        @test_throws ArgumentError action_error_records_tsv(registry; columns=(:missing,))
        @test_throws ArgumentError action_error_summary_markdown(registry; columns=())
        @test_throws ArgumentError action_error_summary_tsv(registry; columns=(:missing,))
        @test_throws ArgumentError search_action_error_summary_markdown(registry, "Error"; columns=())
        @test_throws ArgumentError search_action_error_summary_tsv(registry, "Error"; columns=(:missing,))
        @test !isempty(take_action_errors!(registry))
        @test isempty(action_errors(registry))
        @test action_error_text(registry) == "No action errors"
        @test action_error_summary_text(registry) == "No action errors"
        @test unregister_action!(registry, :fail)
        @test !unregister_action!(registry, :fail)
    end


    @testset "stable animation manager contracts" begin
        track = AnimationTrack([
            Keyframe(0.0, 0; easing=linear_easing),
            Keyframe(0.5, 10; easing=ease_out_quad),
            Keyframe(1.0, 20),
        ])
        @test sample_animation(track, 0.0) == 0
        @test sample_animation(track, 1.0) == 20
        @test interpolate_value((0, 10), (10, 20), 0.5) == (5, 15)
        @test ease_in_quad(0.5) == 0.25
        @test ease_out_cubic(0.0) == 0.0
        @test ease_in_out_cubic(1.0) == 1.0
        @test ease_out_back(1.0) == 1.0

        updates_seen = Int[]
        finishes = Tuple{AnimationHandle,AnimationEndReason,Any}[]
        manager = AnimationManager(clock=() -> 0)
        spec = AnimationSpec(AnimationTrack(0, 10); duration=0.1, key=:opacity)
        handle = animate!(
            manager,
            spec;
            on_update=value -> push!(updates_seen, value),
            on_finish=(handle, reason, value) -> push!(finishes, (handle, reason, value)),
            now_ns=0,
        )
        @test handle isa AnimationHandle
        @test animation_status(manager, handle) == RunningAnimation
        @test active_animation_handles(manager) == [handle]

        first_updates = tick_animations!(manager; now_ns=50_000_000)
        @test first(first_updates) isa AnimationUpdate
        @test first_updates[1].status == RunningAnimation
        @test first_updates[1].value == 5
        @test updates_seen[end] == 5
        @test pause_animation!(manager, handle; now_ns=60_000_000)
        @test animation_status(manager, handle) == PausedAnimation
        @test isempty(tick_animations!(manager; now_ns=90_000_000))
        @test resume_animation!(manager, handle; now_ns=100_000_000)
        @test animation_status(manager, handle) == RunningAnimation
        final_updates = tick_animations!(manager; now_ns=200_000_000)
        @test final_updates[end].status == CompletedAnimation
        @test final_updates[end].value == 10
        @test animation_status(manager, handle) === nothing
        @test finishes[end][2] == AnimationFinished

        replacement_reasons = AnimationEndReason[]
        first_handle = animate!(
            manager,
            AnimationSpec(AnimationTrack(0.0, 1.0); duration=1.0, key=:replaceable);
            on_finish=(handle, reason, value) -> push!(replacement_reasons, reason),
            now_ns=0,
        )
        second_handle = animate!(
            manager,
            AnimationSpec(AnimationTrack(1.0, 2.0); duration=1.0, key=:replaceable);
            now_ns=0,
        )
        @test first_handle != second_handle
        @test replacement_reasons == [AnimationReplaced]
        @test cancel_animation_key!(manager, :replaceable)
        @test animation_status(manager, second_handle) === nothing

        cancelled = AnimationEndReason[]
        cancel_handle = animate!(
            manager,
            AnimationSpec(AnimationTrack(0, 1); duration=1.0);
            on_finish=(handle, reason, value) -> push!(cancelled, reason),
            now_ns=0,
        )
        @test cancel_animation!(manager, cancel_handle)
        @test cancelled == [AnimationCancelled]
        @test !cancel_animation!(manager, cancel_handle)

        set_motion_policy!(manager, DisabledMotion)
        disabled_values = Int[]
        disabled_finishes = AnimationEndReason[]
        disabled_handle = animate!(
            manager,
            AnimationSpec(AnimationTrack(0, 3); duration=1.0);
            on_update=value -> push!(disabled_values, value),
            on_finish=(handle, reason, value) -> push!(disabled_finishes, reason),
            now_ns=0,
        )
        @test disabled_handle isa AnimationHandle
        @test disabled_values == [3]
        @test disabled_finishes == [AnimationFinished]
        @test isempty(active_animation_handles(manager))

        failing = AnimationManager()
        animate!(
            failing,
            AnimationSpec(AnimationTrack(0, 1); duration=0.0);
            on_update=value -> error("update failed"),
            now_ns=0,
        )
        tick_animations!(failing; now_ns=0)
        @test !isempty(animation_errors(failing))
        @test !isempty(take_animation_errors!(failing))
        @test isempty(animation_errors(failing))
    end


    @testset "stable application services coordinator" begin
        services = ApplicationServices(clock=() -> 0, recorder=EventRecorder())
        @test services isa ApplicationServices
        @test services_running(services)

        register_action!(services.actions, Action(:save, "Save", _ -> :saved))
        notify!(services.notifications, "Connected"; id=:connected, timeout=nothing)
        open_overlay!(services.overlays, "dialog")
        add_progress_task!(services.progress, :build; total=2)
        advance_progress!(services.progress, :build, 1)
        handle = animate!(
            services.animations,
            AnimationSpec(AnimationTrack(0, 10); duration=0.1);
            now_ns=0,
        )
        @test handle isa AnimationHandle

        pulse = pulse_services!(services; now_ns=50_000_000)
        @test pulse isa ServicePulse
        @test !isempty(pulse.animation_updates)
        @test :animation in pulse.render_reasons
        @test :actions in pulse.render_reasons
        @test :notifications in pulse.render_reasons
        @test :progress in pulse.render_reasons
        @test :overlays in pulse.render_reasons
        @test isempty(pulse.failures)
        @test isempty(service_errors(services))
        @test isempty(take_service_errors!(services))

        set_service_recorder!(services, EventRecorder())
        report = shutdown_services!(services; now_ns=100_000_000)
        @test report isa ServiceShutdownReport
        @test report.closed_overlays >= 1
        @test report.cancelled_animations >= 1
        @test report.remaining_overlays == 0
        @test report.remaining_animations == 0
        @test report.quiescent
        @test !services_running(services)
        @test_throws InvalidStateException pulse_services!(services; now_ns=100_000_001)
    end


    @testset "stable focus registry traversal" begin
        registry = FocusRegistry()
        @test current_scope(registry) == :root
        @test focus_scopes(registry) == Any[:root]
        @test focus_scope_depth(registry) == 1
        @test focus_restore_targets(registry) == Any[]
        @test focus_restore_depth(registry) == 0
        @test focus_restore_target(registry) === nothing
        @test focused(registry) === nothing

        register_focus!(registry, :left, Rect(1, 1, 1, 4); tab_index=2)
        register_focus!(registry, :right, Rect(1, 8, 1, 4); tab_index=3)
        register_focus!(registry, :top, Rect(1, 4, 1, 3); tab_index=1)
        register_focus!(registry, :disabled, Rect(2, 1, 1, 4); disabled=true)
        register_focus!(registry, :hidden, Rect(2, 8, 1, 4); hidden=true)
        @test focus_count(registry) == 3
        @test focus_order(registry) == Any[:top, :left, :right]
        @test focus_index(registry) === nothing
        empty_snapshot = focus_snapshot(registry)
        @test empty_snapshot isa FocusSnapshot
        @test empty_snapshot.scope == :root
        @test empty_snapshot.scopes == Any[:root]
        @test empty_snapshot.scope_depth == 1
        @test empty_snapshot.restore_targets == Any[]
        @test empty_snapshot.restore_depth == 0
        @test empty_snapshot.current === nothing
        @test empty_snapshot.count == 3
        @test empty_snapshot.index === nothing
        @test empty_snapshot.order == Any[:top, :left, :right]
        @test sprint(show, empty_snapshot) == "FocusSnapshot(scope=:root, scope_depth=1, restore_depth=0, current=nothing, index=nothing/3, order=Any[:top, :left, :right])"
        empty_snapshot_record = focus_snapshot_record(empty_snapshot)
        @test empty_snapshot_record.scope == :root
        @test empty_snapshot_record.scopes == Any[:root]
        @test empty_snapshot_record.scope_depth == 1
        @test empty_snapshot_record.restore_targets == Any[]
        @test empty_snapshot_record.restore_depth == 0
        @test empty_snapshot_record.current === nothing
        @test empty_snapshot_record.count == 3
        @test empty_snapshot_record.index === nothing
        @test empty_snapshot_record.order == Any[:top, :left, :right]
        @test focus_snapshot_record(registry) == empty_snapshot_record
        @test can_focus(registry, :top)
        @test can_focus(registry, :left)
        @test !can_focus(registry, :disabled)
        @test !can_focus(registry, :hidden)
        @test !can_focus(registry, :missing)

        @test focus_next!(registry)
        @test focused(registry) == :top
        @test focus_index(registry) == 1
        focused_snapshot = focus_snapshot(registry)
        @test focused_snapshot.current == :top
        @test focused_snapshot.index == 1
        @test focused_snapshot.count == focus_count(registry)
        @test focused_snapshot.order == focus_order(registry)
        @test occursin("current=:top", sprint(show, focused_snapshot))
        @test clear_focus!(registry)
        @test focused(registry) === nothing
        @test focus_index(registry) === nothing
        @test !clear_focus!(registry)
        @test focus_next!(registry)
        @test focused(registry) == :top
        @test focus_next!(registry)
        @test focused(registry) == :left
        @test focus_index(registry) == 2
        @test focus_previous!(registry)
        @test focused(registry) == :top
        @test focus_index(registry) == 1
        @test focus_last!(registry)
        @test focused(registry) == :right
        @test focus_index(registry) == 3
        @test focus_first!(registry)
        @test focused(registry) == :top
        @test focus_index(registry) == 1
        @test focus!(registry, :right)
        @test focused(registry) == :right
        @test !focus!(registry, :disabled)
        @test !focus!(registry, :hidden)
        @test focus_at(registry, Position(1, 9)) == :right
        @test focus_at(registry, Position(2, 2)) === nothing
        @test focus_direction!(registry, :left)
        @test focused(registry) == :top
        @test_throws ArgumentError focus_direction!(registry, :diagonal)
        @test_throws ArgumentError register_focus!(registry, :left, Rect(4, 1, 1, 1))

        push_focus_scope!(registry, :dialog)
        @test current_scope(registry) == :dialog
        @test focus_scopes(registry) == Any[:root, :dialog]
        @test focus_scope_depth(registry) == 2
        @test focus_restore_targets(registry) == Any[:top]
        @test focus_restore_depth(registry) == 1
        @test focus_restore_target(registry) == :top
        @test focused(registry) === nothing
        register_focus!(registry, :ok, Rect(5, 5, 1, 4))
        register_focus!(registry, :cancel, Rect(6, 5, 1, 7))
        @test focus_count(registry) == 2
        @test focus_order(registry) == Any[:ok, :cancel]
        @test focus_index(registry) === nothing
        scoped_snapshot = focus_snapshot(registry)
        @test scoped_snapshot.scope == :dialog
        @test scoped_snapshot.scopes == Any[:root, :dialog]
        @test scoped_snapshot.scope_depth == 2
        @test scoped_snapshot.restore_targets == Any[:top]
        @test scoped_snapshot.restore_depth == 1
        @test scoped_snapshot.order == Any[:ok, :cancel]
        @test focus_snapshot_record(scoped_snapshot).scope_depth == 2
        @test can_focus(registry, :ok)
        @test !can_focus(registry, :top)
        @test focus_next!(registry)
        @test focused(registry) == :ok
        @test focus_index(registry) == 1
        @test focus_direction!(registry, :down)
        @test focused(registry) == :cancel
        @test focus_index(registry) == 2
        @test pop_focus_scope!(registry)
        @test current_scope(registry) == :root
        @test focus_scopes(registry) == Any[:root]
        @test focus_scope_depth(registry) == 1
        @test focus_restore_targets(registry) == Any[]
        @test focus_restore_depth(registry) == 0
        @test focus_restore_target(registry) === nothing
        @test focused(registry) == :top
        @test !pop_focus_scope!(registry)

        @test focus!(registry, :right)
        push_focus_scope!(registry, :dialog)
        filter!(entry -> entry.id != :right, registry.entries)
        @test pop_focus_scope!(registry)
        @test current_scope(registry) == :root
        @test focused(registry) == :top

        begin_focus_frame!(registry)
        @test focus_count(registry) == 0
        @test isempty(focus_order(registry))
        @test !can_focus(registry, :top)
        @test focus_index(registry) === nothing
        @test focus_snapshot(registry).count == 0
        @test !focus_next!(registry)
        @test !focus_first!(registry)
        @test !focus_last!(registry)
        @test focused(registry) === nothing
        @test !clear_focus!(registry)
        entry = FocusEntry(:manual, Rect(1, 1, 1, 1), 0, :root, false, false)
        @test entry.id == :manual
    end


    @testset "stable reliability lifecycle APIs" begin
        collector = FailureCollector(2)
        first_failure = record_failure!(
            collector,
            RenderFailure,
            ErrorException("render failed");
            component=:panel,
            metadata=Dict(:frame => 1),
            fatal=false,
        )
        @test first_failure isa FailureRecord
        @test first_failure.stage == RenderFailure
        @test first_failure.component == "panel"
        @test first_failure.metadata[:frame] == 1
        record_failure!(collector, UpdateFailure, ErrorException("update failed"))
        record_failure!(collector, InputFailure, ErrorException("input failed"))
        @test length(failure_records(collector)) == 2
        clear_failures!(collector)
        @test isempty(failure_records(collector))

        boundary = ErrorBoundary(
            :panel;
            policy=DisableBoundary,
            maximum_failures=1,
            collector=collector,
            fallback=record -> (:fallback, record.stage),
        )
        result = protect!(() -> error("boom"), boundary; stage=LayoutFailure)
        @test result isa BoundaryResult
        @test result.contained
        @test result.value == (:fallback, LayoutFailure)
        @test result.failure.stage == LayoutFailure
        disabled = protect!(() -> :ok, boundary; stage=UnknownFailure)
        @test disabled.contained
        @test disabled.failure.error isa ErrorException
        reset_error_boundary!(boundary; clear_records=true)
        @test isempty(failure_records(collector))

        cleanup_order = Symbol[]
        scope = ResourceScope()
        defer_cleanup!(scope, () -> push!(cleanup_order, :first); label="first")
        resource = acquire_resource!(
            scope,
            () -> :resource,
            value -> push!(cleanup_order, value);
            label="resource",
        )
        @test resource == :resource
        report = close_resource_scope!(scope)
        @test report isa ScopeCloseReport
        @test report.closed
        @test report.completed == 2
        @test isempty(report.failures)
        @test cleanup_order == [:resource, :first]
        @test close_resource_scope!(scope) === report

        failing_scope = ResourceScope()
        defer_cleanup!(failing_scope, () -> error("cleanup failed"); label="bad cleanup")
        failing_report = close_resource_scope!(failing_scope)
        @test length(failing_report.failures) == 1
        @test failing_report.failures[1] isa CleanupFailure
        throwing_scope = ResourceScope()
        defer_cleanup!(throwing_scope, () -> error("cleanup failed"); label="throwing cleanup")
        @test_throws CompositeCleanupError close_resource_scope!(throwing_scope; throw_errors=true)

        scoped_order = Symbol[]
        with_resource_scope() do scoped
            defer_cleanup!(scoped, () -> push!(scoped_order, :closed); label="scoped")
            push!(scoped_order, :body)
        end
        @test scoped_order == [:body, :closed]

        token = CancellationToken()
        @test !is_cancelled(token)
        @test throw_if_cancelled(token) === token
        cancel!(token)
        @test is_cancelled(token)
        @test_throws InterruptException throw_if_cancelled(token)

        group = ManagedTaskGroup()
        completed = Threads.Atomic{Int}(0)
        spawn_managed!(group; label="success") do token
            throw_if_cancelled(token)
            Threads.atomic_add!(completed, 1)
        end
        spawn_managed!(group; label="failure") do token
            error("task failed")
        end
        failures = join_managed_tasks!(group)
        @test completed[] == 1
        @test length(failures) == 1
        @test failures[1] isa ManagedTaskFailure
        @test failures[1].label == "failure"
        cancel_managed_tasks!(group)
        @test is_cancelled(group.token)
        @test length(close_managed_tasks!(group; cancel=false)) == 1
        @test_throws ArgumentError spawn_managed!(group; label="closed") do token
            nothing
        end
    end


    @testset "stable widget support primitives" begin
        borders = TopBorder | BottomBorder
        @test TopBorder in borders
        @test !(LeftBorder in borders)
        @test AllBorders isa BorderSet
        @test ASCII_BORDERS isa BorderSymbols
        @test ROUNDED_BORDERS isa BorderSymbols
        @test DOUBLE_BORDERS isa BorderSymbols
        @test_throws ArgumentError BorderSymbols("界", "|", "+", "+", "+", "+")

        block = Block(title="Box"; borders, symbols=ASCII_BORDERS)
        @test block.borders == borders
        @test block.symbols === ASCII_BORDERS

        password = PasswordInput(mask="*")
        @test password isa PasswordInput
        @test password.input.mask == "*"

        vertical = Scrollbar(VerticalScrollbar, 20, 5)
        horizontal = Scrollbar(HorizontalScrollbar, 20, 5)
        @test vertical.direction == VerticalScrollbar
        @test horizontal.direction == HorizontalScrollbar
        @test vertical.direction isa ScrollbarDirection

        context = CanvasContext(2, 3, (0.0, 1.0), (0.0, 1.0), Style())
        @test canvas_point!(context, 0.5, 0.5)
        @test canvas_line!(context, 0.0, 0.0, 1.0, 1.0)
        @test any(!iszero, context.dots)
        @test !canvas_point!(context, 2.0, 2.0)
        dataset = ChartDataset([(0, 0), (1, 1)]; connect=false)
        @test dataset isa ChartDataset
        @test dataset.points == [(0.0, 0.0), (1.0, 1.0)]
        @test !dataset.connect
        @test Chart([dataset]) isa Chart

        task = ProgressTask(
            :build,
            "Build",
            10.0,
            4.0,
            RunningProgress,
            UInt64(0),
            UInt64(0),
            UInt64(0),
            UInt64(0),
            UInt64(0),
            nothing,
            Dict(:source => :contract),
        )
        @test task isa ProgressTask
        @test task.status == RunningProgress

        process = ProcessResult(`echo ok`, 0, collect(codeunits("ok")), UInt8[])
        @test process isa ProcessResult
        @test process_succeeded(process)
        @test ProcessView(process) isa ProcessView
        @test register_live_display_semantic_handlers! isa Function
        @test register_progress_group_semantic_handlers! isa Function
        @test register_process_view_semantic_handlers! isa Function
        @test register_terminal_view_semantic_handlers! isa Function
        @test register_task_monitor_semantic_handlers! isa Function
        @test register_log_tail_semantic_handlers! isa Function
        @test register_log_view_semantic_handlers! isa Function
        @test register_rich_log_semantic_handlers! isa Function
        @test register_repl_view_semantic_handlers! isa Function
        @test ProcessExitError(process) isa ProcessExitError
        @test ProcessOutputLimitError(:stdout, 1024) isa ProcessOutputLimitError
    end


    @testset "stable split pane resize state" begin
        state = SplitPaneState(
            fraction=0.25,
            minimum_first=2,
            minimum_second=3,
            orientation=HorizontalSplit,
        )
        @test state isa SplitPaneState
        @test state.orientation == HorizontalSplit
        @test state.orientation isa SplitOrientation
        @test set_split_fraction!(state, 0.75) === state
        @test state.fraction == 0.75
        resize_split!(state, -5, 20)
        @test state.fraction == 0.5
        first, handle, second = split_pane_regions(state, ComponentRect(1, 1, 20, 4); handle_size=1)
        @test first.width == 10
        @test handle.width == 1
        @test second.width == 9

        vertical_state = SplitPaneState(fraction=0.5, orientation=VerticalSplit)
        top, vertical_handle, bottom = split_pane_regions(vertical_state, ComponentRect(1, 1, 10, 9); handle_size=1)
        @test top.height == 4
        @test vertical_handle.height == 1
        @test bottom.height == 4

        handle_state = ResizeHandleState()
        @test begin_resize!(handle_state, 10, state)
        @test handle_state.active
        @test update_resize!(handle_state, state, 15, 20)
        @test state.fraction == 0.75
        cancel_resize!(handle_state, state)
        @test !handle_state.active
        @test state.fraction == 0.5
        @test begin_resize!(handle_state, 10, state)
        @test finish_resize!(handle_state) === handle_state
        @test !handle_state.active

        disabled = SplitPaneState(disabled=true)
        @test !begin_resize!(ResizeHandleState(), 1, disabled)
        @test set_split_fraction!(disabled, 1.0) === disabled
        @test disabled.fraction == 0.5
        @test ResizablePaneState === SplitPaneState
    end


    @testset "stable semantic extension and builder APIs" begin
        registry = RoleRegistry()
        fallback = semantic_descriptor(registry, :unknown, nothing)
        @test fallback isa SemanticDescriptor
        @test fallback.role == GenericRole

        register_role_factory!(registry, :status, value -> SemanticDescriptor(
            GroupRole;
            label="Status $(value)",
            state=SemanticState(busy=value == :loading),
            actions=[ScrollIntoViewSemanticAction],
            metadata=Dict(:value => value),
        ))
        descriptor = semantic_descriptor(registry, :status, :loading)
        @test descriptor.role == GroupRole
        @test descriptor.label == "Status loading"
        @test descriptor.state.busy
        @test ScrollIntoViewSemanticAction in descriptor.actions
        @test descriptor.metadata[:value] == :loading
        unregister_role_factory!(registry, :status)
        @test semantic_descriptor(registry, :status, :loading).role == GenericRole

        bad_registry = RoleRegistry()
        register_role_factory!(bad_registry, :bad, _ -> :not_a_descriptor)
        @test_throws ArgumentError semantic_descriptor(bad_registry, :bad, :value)

        builder = SemanticBuilder(generation=7)
        @test begin_semantic_tree!(builder) === builder
        root_descriptor = SemanticDescriptor(ApplicationRole; label="App")
        button_descriptor = SemanticDescriptor(
            ButtonRole;
            label="Save",
            state=SemanticState(focusable=true),
            actions=[ActivateSemanticAction],
        )
        result = with_semantic_node(
            () -> with_semantic_node(() -> :built, builder, "save", button_descriptor),
            builder,
            "app",
            root_descriptor,
        )
        @test result == :built
        tree = finish_semantic_tree!(builder)
        @test tree isa SemanticTree
        @test tree.generation == 8
        @test semantic_node(tree, "app").role == ApplicationRole
        @test semantic_node(tree, "save").label == "Save"
        @test ActivateSemanticAction in semantic_node(tree, "save").actions
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(tree)))

        @test_throws SemanticBuildError finish_semantic_tree!(builder)
        begin_semantic_tree!(builder)
        push_semantic_node!(builder, "dangling", SemanticDescriptor(GroupRole; label="Dangling"))
        @test_throws SemanticBuildError begin_semantic_tree!(builder)
        abort_semantic_tree!(builder)
        @test begin_semantic_tree!(builder) === builder
        push_semantic_node!(builder, "single", SemanticDescriptor(GroupRole; label="Single"))
        node = pop_semantic_node!(builder)
        @test node isa SemanticNode
        @test node.id == "single"
        @test finish_semantic_tree!(builder; validate=false).root.id == "single"
    end


    @testset "stable terminal controller and capability helpers" begin
        controller = NoopTerminalController()
        @test controller isa AbstractTerminalController
        @test !set_raw!(controller, true)
        @test !set_raw!(controller, false)

        redirected = IOBuffer()
        @test detect_color_level(
            redirected;
            environment=Dict("FORCE_COLOR" => "0", "COLORTERM" => "truecolor"),
            is_tty=false,
        ) == :none
        @test detect_color_level(
            redirected;
            environment=Dict("FORCE_COLOR" => "2"),
            is_tty=false,
        ) == :ansi256
        @test detect_color_level(
            redirected;
            environment=Dict("FORCE_COLOR" => "truecolor"),
            is_tty=false,
        ) == :truecolor
        @test detect_color_level(
            redirected;
            environment=Dict("TERM" => "screen-256color"),
            is_tty=true,
        ) == :ansi256
        @test detect_color_level(
            redirected;
            environment=Dict("TERM" => "xterm-256color"),
            is_tty=false,
        ) == :none

        limits = TerminalLimits(maximum_height=2, maximum_width=2, maximum_cells=4)
        size_error = TerminalSizeError(Size(3, 2), limits)
        @test size_error isa TerminalSizeError
        reset_error = TerminalResetError(CapturedException[])
        @test reset_error isa TerminalResetError
        primary = CapturedException(ErrorException("primary"), Any[])
        cleanup = CapturedException(ErrorException("cleanup"), Any[])
        session_error = TerminalSessionError(primary, cleanup)
        @test session_error isa TerminalSessionError
    end


    @testset "stable editing buffer primitives" begin
        buffer = EditingBuffer("a界e\u0301"; history_limit=3)
        @test length(buffer) == 3
        @test editing_text(buffer) == "a界e\u0301"
        @test move_cursor!(buffer, 1)
        @test insert!(buffer, "🙂")
        @test editing_text(buffer) == "a🙂界e\u0301"
        @test backspace!(buffer)
        @test editing_text(buffer) == "a界e\u0301"
        @test undo!(buffer)
        @test editing_text(buffer) == "a🙂界e\u0301"
        @test redo!(buffer)
        @test editing_text(buffer) == "a界e\u0301"

        select_all!(buffer)
        @test insert!(buffer, "replacement"; maximum_length=4)
        @test editing_text(buffer) == "repl"
        @test !redo!(buffer)
        @test move_cursor!(buffer, 2; extend=true)
        @test delete_forward!(buffer)
        @test editing_text(buffer) == "re"
        clear_selection!(buffer)
        @test buffer.anchor === nothing
        @test set_text!(buffer, "line\nbreak"; record=false) === buffer
        @test editing_text(buffer) == "line\nbreak"
        @test_throws ArgumentError EditingBuffer(""; history_limit=-1)
        @test_throws ArgumentError insert!(buffer, "x"; maximum_length=-1)

        state = TextInputState("left")
        @test set_text!(state, "right\nside"; record=false) === state
        @test editing_text(state.editing) == "right side"
        @test state.horizontal_offset == 0
    end


    @testset "stable virtual clock scheduling APIs" begin
        clock = VirtualClock(start_ns=10)
        @test virtual_time_ns(clock) == 10
        observed = Any[]
        first = schedule_after!(clock, 1.0) do current
            push!(observed, (:first, virtual_time_ns(current)))
            schedule_after!(current, 0.0, () -> push!(observed, :nested))
        end
        cancelled = schedule_after!(() -> push!(observed, :cancelled), clock, 0.5)
        @test first isa ScheduledToken
        @test pending_scheduled(clock) == 2
        @test cancel_scheduled!(clock, cancelled)
        @test !cancel_scheduled!(clock, cancelled)
        @test advance_time!(clock, 0.5) == 0
        @test virtual_time_ns(clock) == 500_000_010
        @test advance_time!(clock, 0.5) == 2
        @test observed == [(:first, 1_000_000_010), :nested]
        @test pending_scheduled(clock) == 0
        @test_throws ArgumentError schedule_after!(clock, Inf, () -> nothing)
    end

end
