@testset "New widget family behavior" begin
    @testset "data and editing widgets" begin
        source = VectorDataSource([(name="Ada", score=10), (name="Lin", score=20)])
        query_source = QueryDataSource(
            [(name="Ada", score=10, status="ready"), (name="Lin", score=20, status="queued"), (name="Bea", score=15, status="ready")];
            key=(row, _) -> row.name,
            query=DataQuery(
                sort=[SortTerm(:score, DescendingSort)],
                filters=Dict(:status => "ready"),
                search="a",
            ),
            search_text=row -> "$(row.name) $(row.status)",
        )
        @test data_length(query_source) == 2
        @test [row.name for row in fetch_items(query_source, 1:2)] == ["Bea", "Ada"]
        @test query_data_source(query_source).search == "a"
        @test data_query_summary(query_data_source(query_source)).filter_count == 1
        @test occursin("filters", data_query_text(query_data_source(query_source)))
        @test startswith(data_query_markdown(query_data_source(query_source)), "| field | value |")
        @test startswith(data_query_tsv(query_data_source(query_source)), "kind\tcolumn")
        inspected_query = query_data_source(query_source)
        empty!(inspected_query.filters)
        @test haskey(query_data_source(query_source).filters, :status)
        @test clear_query!(query_source) === query_source
        @test data_length(query_source) == 3
        @test set_query_search!(query_source, "Lin") === query_source
        @test [row.name for row in fetch_items(query_source, 1:2)] == ["Lin"]
        @test append_data!(query_source, [(name="Lina", score=25, status="ready")]) === query_source
        @test toggle_query_sort!(query_source, :score) === query_source
        @test query_data_source(query_source).sort[1].direction == AscendingSort
        @test toggle_query_sort!(query_source, :score) === query_source
        @test query_data_source(query_source).sort[1].direction == DescendingSort
        @test [row.name for row in fetch_items(query_source, 1:2)] == ["Lina", "Lin"]
        @test set_query_filter!(query_source, :status, "queued") === query_source
        @test [row.name for row in fetch_items(query_source, 1:2)] == ["Lin"]
        @test clear_query_filter!(query_source, :status) === query_source
        @test set_query_filter!(query_source, :score, value -> value >= 20) === query_source
        @test [row.name for row in fetch_items(query_source, 1:3)] == ["Lina", "Lin"]
        @test set_query_filter!(query_source, :status, query_equals("ready")) === query_source
        @test [row.name for row in fetch_items(query_source, 1:3)] == ["Lina"]
        @test set_query_filter!(query_source, :name, query_contains("li")) === query_source
        @test [row.name for row in fetch_items(query_source, 1:3)] == ["Lina"]
        @test set_query_filter!(query_source, :name, query_regex(r"Lin(a)?")) === query_source
        @test [row.name for row in fetch_items(query_source, 1:3)] == ["Lina"]
        @test set_query_filter!(query_source, :score, query_range(minimum=20, maximum=25)) === query_source
        @test [row.name for row in fetch_items(query_source, 1:3)] == ["Lina"]
        query_layout = TableLayoutState([
            VirtualTableColumn(:name, "Name"),
            VirtualTableColumn(:score, "Score"),
            VirtualTableColumn(:status, "Status"),
        ])
        set_virtual_search!(query_layout, "a")
        set_virtual_filter!(query_layout, :status, "ready")
        toggle_virtual_sort!(query_layout, :score)
        @test apply_virtual_table_query!(query_source, query_layout) === query_source
        query_layout_snapshot = table_layout_snapshot(query_layout)
        @test restore_table_layout!(query_layout, query_layout_snapshot) === query_layout
        @test query_data_source(query_source).search == "a"
        @test [row.name for row in fetch_items(query_source, 1:3)] == ["Ada", "Bea", "Lina"]
        query_visibility = ColumnVisibilityState(hidden=[:status])
        query_visibility_snapshot = column_visibility_snapshot(query_visibility)
        @test restore_column_visibility!(query_visibility, query_visibility_snapshot) === query_visibility
        @test !virtual_column_visible(query_visibility, :status)
        @test [column.id for column in visible_virtual_columns([
            VirtualTableColumn(:name, "Name"),
            VirtualTableColumn(:score, "Score"),
            VirtualTableColumn(:status, "Status"),
        ], query_visibility)] == [:name, :score]
        @test show_virtual_column!(query_visibility, :status) === query_visibility
        @test hide_virtual_column!(query_visibility, :score) === query_visibility
        @test toggle_virtual_column_visibility!(query_visibility, :score) === query_visibility
        query_pins = ColumnPinState(left=[:name], right=[:status])
        @test column_pin_snapshot(query_pins).right == [:status]
        @test restore_column_pin!(query_pins, column_pin_snapshot(query_pins)) === query_pins
        @test virtual_column_pin_position(query_pins, :name) == :left
        @test [column.id for column in apply_virtual_column_pinning([
            VirtualTableColumn(:name, "Name"),
            VirtualTableColumn(:score, "Score"),
            VirtualTableColumn(:status, "Status"),
        ], query_layout, query_pins)] == [:name, :score, :status]
        @test pin_virtual_column_right!(query_pins, :score) === query_pins
        @test unpin_virtual_column!(query_pins, :score) === query_pins
        query_column_actions = default_virtual_column_actions()
        @test first(query_column_actions) isa VirtualColumnAction
        @test !isempty(virtual_column_action_menu(query_column_actions, :status, query_layout; visibility=query_visibility, pinning=query_pins))
        @test first(virtual_column_action_records(query_column_actions, :status, query_layout; visibility=query_visibility, pinning=query_pins)).column == :status
        @test virtual_column_action_for_shortcut(query_column_actions, "s", :status, query_layout; visibility=query_visibility, pinning=query_pins).id == :sort
        query_column_result = invoke_virtual_column_action(query_column_actions, :sort, :status, query_layout; visibility=query_visibility, pinning=query_pins)
        @test query_column_result.handled
        @test virtual_column_action_summary(query_column_result).column == :status
        @test occursin("column status", virtual_column_action_text(query_column_result))
        @test startswith(virtual_column_action_markdown(query_column_result), "| field | value |")
        @test startswith(virtual_column_action_tsv(query_column_result), "action\tlabel")
        @test invoke_virtual_column_action_shortcut(query_column_actions, "s", :status, query_layout; visibility=query_visibility, pinning=query_pins).handled
        @test invoke_virtual_column_action(query_column_actions, :pin_right, :score, query_layout; visibility=query_visibility, pinning=query_pins).handled
        @test invoke_virtual_column_action(query_column_actions, :unpin, :score, query_layout; visibility=query_visibility, pinning=query_pins).handled
        query_preferences = table_preferences_bundle(query_layout; visibility=query_visibility, pinning=query_pins, column_actions=query_column_actions)
        @test query_preferences.layout.search == "a"
        @test table_preferences_summary(query_preferences).column_action_count == length(query_column_actions)
        @test occursin("columns", table_preferences_text(query_preferences))
        @test startswith(table_preferences_markdown(query_preferences), "| field | value |")
        @test startswith(table_preferences_tsv(query_preferences), "field\tvalue")
        @test restore_table_preferences!(query_layout, query_preferences; visibility=query_visibility, pinning=query_pins).layout === query_layout
        @test [column.id for column in apply_table_preferences([
            VirtualTableColumn(:name, "Name"),
            VirtualTableColumn(:score, "Score"),
            VirtualTableColumn(:status, "Status"),
        ], query_layout; visibility=query_visibility, pinning=query_pins)] == [:name, :status]
        query_row_actions = [
            VirtualRowAction(:open, "Open"; handler=(row, index, key) -> row.name, shortcut="enter"),
            VirtualRowAction(:retry, "Retry"; enabled=row -> row.status == "queued", shortcut="r"),
        ]
        @test length(virtual_row_action_menu(query_row_actions, fetch_items(query_source, 1:1)[1], 1)) == 1
        @test first(virtual_row_action_records(query_row_actions, fetch_items(query_source, 1:1)[1], 1)).id == :open
        @test virtual_row_action_for_shortcut(query_row_actions, "enter", fetch_items(query_source, 1:1)[1], 1).id == :open
        query_action_result = invoke_virtual_row_action(query_row_actions, :open, fetch_items(query_source, 1:1)[1], 1)
        @test query_action_result.handled
        @test query_action_result.value == "Ada"
        @test invoke_virtual_row_action_shortcut(query_row_actions, "enter", fetch_items(query_source, 1:1)[1], 1).handled
        query_batch_rows = fetch_items(query_source, 1:3)
        query_batch_result = invoke_virtual_row_action_batch(query_row_actions, :retry, query_batch_rows; indices=eachindex(query_batch_rows))
        @test query_batch_result isa VirtualRowActionBatchResult
        @test query_batch_result.disabled >= 0
        @test virtual_row_action_batch_records(query_batch_result) isa Vector
        @test virtual_row_action_batch_summary(query_batch_result).requested == query_batch_result.requested
        @test occursin("action", virtual_row_action_batch_text(query_batch_result))
        @test startswith(virtual_row_action_batch_markdown(query_batch_result), "| field | value |")
        @test startswith(virtual_row_action_batch_tsv(query_batch_result), "index\tkey")
        columns = [
            VirtualTableColumn(:name, "Name"; accessor=row -> row.name),
            VirtualTableColumn(:score, "Score"; accessor=row -> row.score),
        ]
        grid = DataGrid(source, columns; width=24, height=4)
        grid_state = state_for(grid)
        grid_buffer = Buffer(4, 24)
        @test render!(grid_buffer, grid, grid_buffer.area, grid_state) === grid_buffer
        @test handle!(grid_state, grid, KeyEvent(Key(:down)))
        @test grid_state.rows.cursor == 2
        grid_dispatcher = SemanticDispatcher()
        register_data_grid_semantic_handlers!(grid_dispatcher, :data_grid, grid, grid_state)
        grid_pilot = SemanticPilot(data_grid_semantic_tree(grid, grid_state; id="data_grid"); dispatcher=grid_dispatcher)
        grid_select = perform_semantic_action!(grid_pilot, "data_grid", SelectSemanticAction)
        @test grid_select.handled
        @test 2 in grid_state.rows.selected

        virtual_table = VirtualTable(source, columns; width=24, height=4)
        virtual_table_state = state_for(virtual_table)
        virtual_table_buffer = Buffer(4, 24)
        @test render!(virtual_table_buffer, virtual_table, virtual_table_buffer.area, virtual_table_state) === virtual_table_buffer
        @test handle!(virtual_table_state, virtual_table, KeyEvent(Key(:down)))
        @test virtual_table_state.rows.cursor == 2
        @test virtual_table_semantic_tree(virtual_table, virtual_table_state).root.role == TableRole
        selection_snapshot = virtual_selection_snapshot(virtual_table_state.rows)
        @test restore_virtual_selection!(virtual_table_state.rows, selection_snapshot) === virtual_table_state.rows
        virtual_table_state.rows.cursor = 1
        push!(virtual_table_state.rows.selected, 1)
        @test first(virtual_selected_row_records(virtual_table, virtual_table_state)).cell_values[:name] == "Ada"
        @test virtual_selected_row_snapshot(virtual_table, virtual_table_state).count == 1
        range_selection = begin_virtual_range_selection(virtual_table_state.rows, 2)
        @test [row.index for row in virtual_range_selected_row_records(virtual_table, virtual_table_state, range_selection)] == [1, 2]
        @test virtual_range_selected_row_snapshot(virtual_table, virtual_table_state, range_selection).expected == 2
        range_actions = [VirtualRowAction(:inspect, "Inspect"; handler=(row, index, key) -> row.name)]
        @test invoke_virtual_range_row_action_batch(range_actions, :inspect, virtual_table, virtual_table_state, range_selection).handled == 2
        cell_edit = VirtualCellEditState()
        begin_virtual_cell_edit!(cell_edit, 1, :score; key=1, value="10")
        update_virtual_cell_edit!(cell_edit, "11")
        @test virtual_cell_edit_snapshot(cell_edit).draft == "11"
        edit_commit = commit_virtual_cell_edit!(cell_edit)
        @test edit_commit.committed
        @test apply_virtual_cell_edit((score="10",), edit_commit).score == "11"
        edit_history = VirtualCellEditHistory()
        @test record_virtual_cell_edit!(edit_history, edit_commit) === edit_history
        @test undo_virtual_cell_edit!(edit_history).value == "10"
        @test redo_virtual_cell_edit!(edit_history).value == "11"
        table_dispatcher = SemanticDispatcher()
        register_virtual_table_semantic_handlers!(table_dispatcher, :virtual_table, virtual_table, virtual_table_state)
        table_row_actions = [VirtualRowAction(:open, "Open"; handler=(row, index, key) -> row.name)]
        register_virtual_row_action_semantic_handlers!(table_dispatcher, :virtual_table, virtual_table, virtual_table_state, table_row_actions)
        register_virtual_row_action_batch_semantic_handlers!(table_dispatcher, :virtual_table, virtual_table, virtual_table_state, table_row_actions)
        table_column_layout = TableLayoutState(columns)
        table_column_pins = ColumnPinState()
        table_column_actions = default_virtual_column_actions()
        register_virtual_column_action_semantic_handlers!(
            table_dispatcher,
            :virtual_table,
            columns,
            table_column_layout,
            table_column_actions;
            pinning=table_column_pins,
        )
        table_cell_edit = VirtualCellEditState()
        register_virtual_cell_edit_semantic_handlers!(table_dispatcher, :virtual_table, virtual_table, virtual_table_state, table_cell_edit)
        table_pilot = SemanticPilot(virtual_table_semantic_tree(virtual_table, virtual_table_state; id="virtual_table"); dispatcher=table_dispatcher)
        table_previous = perform_semantic_action!(table_pilot, "virtual_table", DecrementSemanticAction)
        @test table_previous.handled
        @test virtual_table_state.rows.cursor == 1
        table_batch_action = perform_semantic_action!(table_pilot, "virtual_table/selection", ActivateSemanticAction; value=:open)
        @test table_batch_action.handled
        @test table_batch_action.value isa VirtualRowActionBatchResult
        table_row_action = perform_semantic_action!(table_pilot, "virtual_table/1", ActivateSemanticAction; value=:open)
        @test table_row_action.handled
        @test table_row_action.value.value == "Ada"
        table_column_action = perform_semantic_action!(table_pilot, "virtual_table/column/name", ActivateSemanticAction; value=:sort)
        @test table_column_action.handled
        @test table_column_action.value.action == :sort
        table_cell_action = perform_semantic_action!(table_pilot, "virtual_table/1/score", SetValueSemanticAction; value="12")
        @test table_cell_action.handled
        @test table_cell_action.value.draft == "12"

        virtual_list = VirtualList(
            source;
            width=24,
            height=3,
            multiple=true,
            format=VirtualListFormat(item=(row, _) -> row.name),
        )
        virtual_list_state = state_for(virtual_list)
        virtual_list_buffer = Buffer(3, 24)
        @test render!(virtual_list_buffer, virtual_list, virtual_list_buffer.area, virtual_list_state) === virtual_list_buffer
        @test occursin("Ada", plain_snapshot(virtual_list_buffer))
        @test handle!(virtual_list_state, virtual_list, KeyEvent(Key(:down)))
        @test virtual_list_state.cursor == 2
        @test handle!(virtual_list_state, virtual_list, MouseEvent(Position(2, 1), LeftMouseButton, MousePress), virtual_list_buffer.area)
        @test virtual_list_semantic_tree(virtual_list, virtual_list_state).root.role == ListRole
        list_dispatcher = SemanticDispatcher()
        register_virtual_list_semantic_handlers!(list_dispatcher, :virtual_list, virtual_list, virtual_list_state)
        list_pilot = SemanticPilot(virtual_list_semantic_tree(virtual_list, virtual_list_state; id="virtual_list"); dispatcher=list_dispatcher)
        list_select = perform_semantic_action!(list_pilot, "virtual_list", SelectSemanticAction)
        @test list_select.handled
        @test !isempty(virtual_list_state.selected)

        properties = PropertyList(["name" => "Wicked", "version" => "dev"])
        property_state = state_for(properties)
        @test render!(Buffer(2, 20), properties, Rect(1, 1, 2, 20), property_state) isa Buffer

        breadcrumbs = Breadcrumb([BreadcrumbItem("Home", :home), BreadcrumbItem("Docs", :docs)])
        breadcrumb_state = state_for(breadcrumbs)
        @test handle!(breadcrumb_state, breadcrumbs, KeyEvent(Key(:right)))
        @test activate_breadcrumb!(breadcrumb_state) == :docs

        pagination = Pagination(51; page_size=10)
        pagination_state = state_for(pagination)
        @test handle!(pagination_state, pagination, KeyEvent(Key(:right)))
        @test pagination_state.page == 2

        editor = CodeEditor("x = 1"; language="julia")
        editor_state = state_for(editor)
        @test handle!(editor_state, editor, KeyEvent(Key(:character); text="\n# note"))
        @test occursin("# note", code_editor_text(editor_state))
        @test editor_state.code.language == "julia"

        masked = MaskedInput("##-AA")
        masked_state = state_for(masked)
        @test handle!(masked_state, masked, KeyEvent(Key(:character); text="12ab"))
        @test masked_input_complete(masked_state)
        @test masked_input_text(masked_state; include_placeholders=false) == "12-ab"
        masked_tree = ToolkitTree(Element(masked; id=:masked_input, key=:masked_input, state_factory=() -> masked_state, focusable=true))
        masked_semantics = toolkit_semantic_tree(masked_tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(masked_semantics)))
        masked_dispatcher = SemanticDispatcher()
        register_masked_input_semantic_handlers!(masked_dispatcher, :masked_input, masked, masked_state)
        masked_pilot = SemanticPilot(masked_semantics; dispatcher=masked_dispatcher)
        @test perform_semantic_action!(masked_pilot, "masked_input", FocusSemanticAction).handled
        masked_set = perform_semantic_action!(masked_pilot, "masked_input", SetValueSemanticAction; value="34-CD")
        @test masked_set.handled
        @test masked_set.value[:complete]
        @test masked_input_text(masked_state; include_placeholders=false) == "34-CD"
    end

    @testset "visualization and application shell widgets" begin
        plot = Plot([(0.0, 0.0), (1.0, 1.0)]; width=12, height=4)
        @test render!(Buffer(4, 12), plot, Rect(1, 1, 4, 12)) isa Buffer
        meter = Meter(3; minimum=0, maximum=4, orientation=:vertical, width=2, height=4)
        @test meter_ratio(meter) == 0.75
        gauge = Gauge(0.75; label="Upload")
        line_gauge = LineGauge(0.25)
        sparkline = Sparkline([1.0, 2.0, 3.0])
        bar_chart = BarChart(["Build" => 3.0, "Test" => 2.0])
        chart = Chart([ChartDataset([(0.0, 0.0), (1.0, 1.0)])])
        histogram = Histogram([1.0, 2.0, 3.0]; bins=2)
        heatmap = Heatmap([1.0 2.0; 3.0 4.0])
        canvas = Canvas(context -> canvas_point!(context, 0.5, 0.5))
        dispatcher = SemanticDispatcher()
        register_gauge_semantic_handlers!(dispatcher, :gauge, gauge)
        register_line_gauge_semantic_handlers!(dispatcher, :line_gauge, line_gauge)
        register_sparkline_semantic_handlers!(dispatcher, :sparkline, sparkline)
        register_bar_chart_semantic_handlers!(dispatcher, :bar_chart, bar_chart)
        register_chart_semantic_handlers!(dispatcher, :chart, chart)
        register_plot_semantic_handlers!(dispatcher, :plot, plot)
        register_histogram_semantic_handlers!(dispatcher, :histogram, histogram)
        register_heatmap_semantic_handlers!(dispatcher, :heatmap, heatmap)
        register_canvas_semantic_handlers!(dispatcher, :canvas, canvas)
        register_meter_semantic_handlers!(dispatcher, :meter, meter)
        visual_tree = ToolkitTree(Column(
            Element(gauge; id=:gauge, key=:gauge),
            Element(line_gauge; id=:line_gauge, key=:line_gauge),
            Element(sparkline; id=:sparkline, key=:sparkline),
            Element(bar_chart; id=:bar_chart, key=:bar_chart),
            Element(chart; id=:chart, key=:chart),
            Element(plot; id=:plot, key=:plot),
            Element(histogram; id=:histogram, key=:histogram),
            Element(heatmap; id=:heatmap, key=:heatmap),
            Element(canvas; id=:canvas, key=:canvas),
            Element(meter; id=:meter, key=:meter),
        ))
        visual_pilot = SemanticPilot(toolkit_semantic_tree(visual_tree); dispatcher)
        @test perform_semantic_action!(visual_pilot, "gauge", SelectSemanticAction).value[:ratio] == 0.75
        @test length(perform_semantic_action!(visual_pilot, "bar_chart", SelectSemanticAction).value[:bars]) == 2
        @test perform_semantic_action!(visual_pilot, "chart", FocusSemanticAction).handled
        @test perform_semantic_action!(visual_pilot, "meter", SelectSemanticAction).value[:ratio] == 0.75

        timeline = Timeline([TimelineItem("Build", :build), TimelineItem("Test", :test)]; width=20, height=2)
        timeline_state = state_for(timeline)
        @test handle!(timeline_state, timeline, KeyEvent(Key(:down)))
        @test timeline_value(timeline_state) == :test

        drawer = Drawer(Label("tools"); size=8)
        drawer_state = state_for(drawer)
        drawer_state.open = true
        @test render!(Buffer(4, 20), drawer, Rect(1, 1, 4, 20), drawer_state) isa Buffer
        @test handle!(drawer_state, drawer, KeyEvent(Key(:escape)))
        @test !drawer_state.open

        popover = Popover(Label("details"), Rect(1, 1, 1, 4); width=8, height=3)
        popover_state = state_for(popover)
        popover_state.open = true
        @test render!(Buffer(8, 20), popover, Rect(1, 1, 8, 20), popover_state) isa Buffer

        hub = DiagnosticsHub()
        inspector = Inspector(hub; visible=true, width=20, height=4)
        @test render!(Buffer(4, 20), inspector, Rect(1, 1, 4, 20), state_for(inspector)) isa Buffer
        console = DevConsole(hub; visible=true, width=20, height=4)
        @test render!(Buffer(4, 20), console, Rect(1, 1, 4, 20), state_for(console)) isa Buffer
    end

    @testset "streaming and media widgets" begin
        live = LiveDisplay(state -> "frame $(state.frame)"; width=16, height=1)
        live_state = state_for(live)
        @test handle!(live_state, live, TickEvent(UInt64(1), UInt64(1)))
        @test live_state.frame == 1

        terminal_view = TerminalView("one\ntwo"; width=8, height=2)
        @test render!(Buffer(2, 8), terminal_view, Rect(1, 1, 2, 8), state_for(terminal_view)) isa Buffer

        log = LogState()
        push_log!(log, "watch")
        tail = LogTail(log; width=12, height=2)
        @test render!(Buffer(2, 12), tail, Rect(1, 1, 2, 12), state_for(tail)) isa Buffer

        repl = ReplView(command -> "echo: " * command; width=24, height=3)
        repl_state = state_for(repl)
        @test handle!(repl_state, repl, KeyEvent(Key(:character); text="2 + 2"))
        @test handle!(repl_state, repl, KeyEvent(Key(:enter)))
        @test !isempty(repl_state.output.entries)
        repl_dispatcher = SemanticDispatcher()
        register_repl_view_semantic_handlers!(repl_dispatcher, :repl, repl, repl_state)
        repl_tree = ToolkitTree(Element(repl; id=:repl, key=:repl, state_factory=() -> repl_state, focusable=true))
        repl_pilot = SemanticPilot(toolkit_semantic_tree(repl_tree); dispatcher=repl_dispatcher)
        @test perform_semantic_action!(repl_pilot, "repl", SetValueSemanticAction; value="3 + 3").handled
        @test perform_semantic_action!(repl_pilot, "repl", ActivateSemanticAction).handled

        ansi = AnsiView("\e[31mred\e[0m"; width=8, height=1)
        @test ansi_plain_text(ansi.source) == "red"
        @test render!(Buffer(1, 8), ansi, Rect(1, 1, 1, 8), state_for(ansi)) isa Buffer

        link = Hyperlink("docs", :documentation)
        link_state = state_for(link)
        @test handle!(link_state, link, KeyEvent(Key(:enter)))
        @test hyperlink_target(link) == :documentation
        link_dispatcher = SemanticDispatcher()
        register_hyperlink_semantic_handlers!(link_dispatcher, :docs, link, link_state)
        link_tree = ToolkitTree(Element(link; id=:docs, key=:docs, state_factory=() -> link_state, focusable=true))
        link_pilot = SemanticPilot(toolkit_semantic_tree(link_tree); dispatcher=link_dispatcher)
        link_activate = perform_semantic_action!(link_pilot, "docs", ActivateSemanticAction)
        @test link_activate.handled
        @test link_activate.value == :documentation

        picker = ColorPicker()
        picker_state = state_for(picker)
        @test handle!(picker_state, picker, KeyEvent(Key(:right)))
        @test render!(Buffer(1, 16), picker, Rect(1, 1, 1, 16), picker_state) isa Buffer

        registry = ThemeRegistry()
        preview = ThemePreview(registry; width=20, height=2)
        preview_state = state_for(preview)
        @test render!(Buffer(2, 20), preview, Rect(1, 1, 2, 20), preview_state) isa Buffer
    end

    @testset "data, editing, and timeline toolkit semantics" begin
        source = VectorDataSource([(name="Ada", score=10), (name="Lin", score=20)])
        columns = [
            VirtualTableColumn(:name, "Name"; accessor=row -> row.name),
            VirtualTableColumn(:score, "Score"; accessor=row -> row.score),
        ]
        grid = DataGrid(source, columns; width=24, height=4)
        grid_state = state_for(grid)
        data_table = DataTable([(name="Ada", score=10), (name="Lin", score=20)], columns; width=24, height=4)
        data_table_state = state_for(data_table)
        @test DataTableState === DataGridState
        @test data_table_state isa DataTableState
        tree_source = CallbackTreeDataSource{NamedTuple{(:id, :name),Tuple{Symbol,String}},Symbol}(
            roots=() -> [(id=:root, name="Root")],
            children=item -> item.id == :root ? [(id=:child, name="Child")] : NamedTuple{(:id, :name),Tuple{Symbol,String}}[],
            key=item -> item.id,
        )
        virtual_tree = VirtualTree(tree_source; width=24, height=4, multiple=true, format=VirtualTreeFormat(item=(row, _) -> row.name))
        virtual_tree_state = state_for(virtual_tree)
        expand_virtual_tree!(virtual_tree_state, :root)
        virtual_tree_buffer = Buffer(4, 24)
        @test render!(virtual_tree_buffer, virtual_tree, virtual_tree_buffer.area, virtual_tree_state) === virtual_tree_buffer
        @test occursin("Root", plain_snapshot(virtual_tree_buffer))
        @test handle!(virtual_tree_state, virtual_tree, KeyEvent(Key(:down)))
        @test virtual_tree_state.cursor == :child
        @test handle!(virtual_tree_state, virtual_tree, MouseEvent(Position(1, 1), LeftMouseButton, MousePress), virtual_tree_buffer.area)
        @test virtual_tree_semantic_tree(virtual_tree, virtual_tree_state).root.role == TreeRole
        tree_dispatcher = SemanticDispatcher()
        register_virtual_tree_semantic_handlers!(tree_dispatcher, :virtual_tree, virtual_tree, virtual_tree_state)
        tree_select = perform_semantic_action!(
            SemanticPilot(virtual_tree_semantic_tree(virtual_tree, virtual_tree_state; id="virtual_tree"); dispatcher=tree_dispatcher),
            "virtual_tree",
            SelectSemanticAction,
        )
        @test tree_select.handled
        @test virtual_tree_state.cursor in virtual_tree_state.selected
        tree_table = TreeTable(tree_source, [VirtualTableColumn(:name, "Name"; accessor=row -> row.name)]; width=24, height=4)
        tree_table_state = state_for(tree_table)
        tree_table_dispatcher = SemanticDispatcher()
        register_tree_table_semantic_handlers!(tree_table_dispatcher, :tree_table, tree_table, tree_table_state)
        tree_table_expand = perform_semantic_action!(
            SemanticPilot(tree_table_semantic_tree(tree_table, tree_table_state; id="tree_table"); dispatcher=tree_table_dispatcher),
            "tree_table/root",
            ExpandSemanticAction,
        )
        @test tree_table_expand.handled
        @test :root in tree_table_state.tree.expanded
        editor = CodeEditor("x = 1"; language="julia")
        editor_state = state_for(editor)
        masked = MaskedInput("##-AA")
        masked_state = state_for(masked)
        autocomplete = Autocomplete(["alpha", "beta", "release"]; width=16, max_visible=2)
        autocomplete_state = state_for(autocomplete)
        combobox = ComboBox(["debug", "release", "safe"]; width=16, max_visible=2)
        combobox_state = state_for(combobox)
        tag_input = TagInput(["julia", "tui"]; width=16)
        tag_input_state = state_for(tag_input)
        slider = Slider(0, 100; value=25, step=5, width=16)
        slider_state = state_for(slider)
        range_slider = RangeSlider(0, 100; lower=20, upper=80, step=5, width=16)
        range_slider_state = state_for(range_slider)
        timeline = Timeline([TimelineItem("Build", :build), TimelineItem("Test", :test)]; width=20, height=2)
        timeline_state = state_for(timeline)

        for (widget, state) in ((grid, grid_state), (data_table, data_table_state), (tree_table, tree_table_state), (editor, editor_state), (masked, masked_state), (autocomplete, autocomplete_state), (combobox, combobox_state), (tag_input, tag_input_state), (slider, slider_state), (range_slider, range_slider_state), (timeline, timeline_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
        end

        @test handle!(grid_state, grid, KeyEvent(Key(:down)))
        @test handle!(grid_state, grid, MouseEvent(Position(3, 2), LeftMouseButton, MousePress), Rect(1, 1, 4, 24))
        @test handle!(data_table_state, data_table, KeyEvent(Key(:down)))
        @test handle!(data_table_state, data_table, MouseEvent(Position(3, 2), LeftMouseButton, MousePress), Rect(1, 1, 4, 24))
        @test handle!(tree_table_state, tree_table, KeyEvent(Key(:down)))
        @test handle!(tree_table_state, tree_table, MouseEvent(Position(2, 2), LeftMouseButton, MousePress), Rect(1, 1, 4, 24))
        @test handle!(editor_state, editor, KeyEvent(Key(:character); text="\n# note"))
        @test handle!(editor_state, editor, MouseEvent(Position(1, 4), LeftMouseButton, MousePress), Rect(1, 1, 4, 24))
        @test handle!(masked_state, masked, KeyEvent(Key(:character); text="12ab"))
        @test handle!(masked_state, masked, MouseEvent(Position(1, 3), LeftMouseButton, MousePress), Rect(1, 1, 1, 8))
        @test handle!(autocomplete_state, autocomplete, KeyEvent(Key(:character); text="a"))
        @test handle!(autocomplete_state, autocomplete, KeyEvent(Key(:down)))
        update_autocomplete!(autocomplete_state, "a")
        @test handle!(autocomplete_state, autocomplete, MouseEvent(Position(1, 1), LeftMouseButton, MouseRelease), Rect(1, 1, 2, 16))
        update_autocomplete!(autocomplete_state, "a")
        @test handle!(combobox_state, combobox, KeyEvent(Key(:down)))
        @test handle!(combobox_state, combobox, MouseEvent(Position(2, 1), LeftMouseButton, MouseRelease), Rect(1, 1, 3, 16))
        @test handle!(tag_input_state, tag_input, PasteEvent("docs"))
        @test handle!(tag_input_state, tag_input, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 1, 16))
        @test handle!(slider_state, slider, KeyEvent(Key(:right)))
        @test handle!(slider_state, slider, MouseEvent(Position(1, 12), LeftMouseButton, MouseRelease), Rect(1, 1, 1, 16))
        @test handle!(range_slider_state, range_slider, KeyEvent(Key(:tab)))
        @test handle!(range_slider_state, range_slider, MouseEvent(Position(1, 12), LeftMouseButton, MouseRelease), Rect(1, 1, 1, 16))

        checkbox = Checkbox("Ready")
        checkbox_state = state_for(checkbox)
        checkbox_dispatcher = SemanticDispatcher()
        register_checkbox_semantic_handlers!(checkbox_dispatcher, :checkbox, checkbox, checkbox_state)
        checkbox_pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(checkbox; id=:checkbox, key=:checkbox, state_factory=() -> checkbox_state, focusable=true))); dispatcher=checkbox_dispatcher)
        @test perform_semantic_action!(checkbox_pilot, "checkbox", SetValueSemanticAction; value=true).handled
        @test checkbox_state.checked

        check_box = CheckBox("Ready")
        check_box_state = state_for(check_box)
        check_box_dispatcher = SemanticDispatcher()
        register_check_box_semantic_handlers!(check_box_dispatcher, :check_box, check_box, check_box_state)
        check_box_pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(check_box; id=:check_box, key=:check_box, state_factory=() -> check_box_state, focusable=true))); dispatcher=check_box_dispatcher)
        @test perform_semantic_action!(check_box_pilot, "check_box", ActivateSemanticAction).handled
        @test check_box_state.checked

        toggle = Toggle(on_label="Enabled", off_label="Disabled")
        toggle_state = state_for(toggle)
        toggle_dispatcher = SemanticDispatcher()
        register_toggle_semantic_handlers!(toggle_dispatcher, :toggle, toggle, toggle_state)
        toggle_pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(toggle; id=:toggle, key=:toggle, state_factory=() -> toggle_state, focusable=true))); dispatcher=toggle_dispatcher)
        @test perform_semantic_action!(toggle_pilot, "toggle", SetValueSemanticAction; value="on").handled
        @test toggle_state.enabled

        switch_widget = Switch(on_label="Enabled", off_label="Disabled")
        switch_state = state_for(switch_widget)
        switch_dispatcher = SemanticDispatcher()
        register_switch_semantic_handlers!(switch_dispatcher, :switch, switch_widget, switch_state)
        switch_pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(switch_widget; id=:switch, key=:switch, state_factory=() -> switch_state, focusable=true))); dispatcher=switch_dispatcher)
        @test perform_semantic_action!(switch_pilot, "switch", ActivateSemanticAction).handled
        @test switch_state.enabled

        slider_dispatcher = SemanticDispatcher()
        register_slider_semantic_handlers!(slider_dispatcher, :slider, slider, slider_state)
        slider_pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(slider; id=:slider, key=:slider, state_factory=() -> slider_state, focusable=true))); dispatcher=slider_dispatcher)
        @test perform_semantic_action!(slider_pilot, "slider", SetValueSemanticAction; value=75).handled
        @test slider_state.value == 75

        range_slider_dispatcher = SemanticDispatcher()
        register_range_slider_semantic_handlers!(range_slider_dispatcher, :range_slider, range_slider, range_slider_state)
        range_slider_pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(range_slider; id=:range_slider, key=:range_slider, state_factory=() -> range_slider_state, focusable=true))); dispatcher=range_slider_dispatcher)
        @test perform_semantic_action!(range_slider_pilot, "range_slider", SetValueSemanticAction; value=(20, 80)).handled
        @test range_slider_state.lower == 20
        @test range_slider_state.upper == 80
        @test perform_semantic_action!(range_slider_pilot, "range_slider/lower", IncrementSemanticAction).handled
        @test range_slider_state.lower == 25
        @test handle!(timeline_state, timeline, KeyEvent(Key(:down)))
        @test handle!(timeline_state, timeline, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 2, 20))

        snapshots = Dict{Symbol,String}()
        for (name, widget, state) in ((:grid, grid, grid_state), (:data_table, data_table, data_table_state), (:tree_table, tree_table, tree_table_state), (:editor, editor, editor_state), (:masked, masked, masked_state), (:autocomplete, autocomplete, autocomplete_state), (:combobox, combobox, combobox_state), (:tag_input, tag_input, tag_input_state), (:slider, slider, slider_state), (:range_slider, range_slider, range_slider_state), (:timeline, timeline, timeline_state))
            buffer = Buffer(4, 24)
            render!(buffer, widget, buffer.area, state)
            snapshots[name] = plain_snapshot(buffer)
            @test !isempty(snapshots[name])
        end
        @test occursin("Ada", snapshots[:grid])
        @test occursin("Ada", snapshots[:data_table])
        @test occursin("Root", snapshots[:tree_table])
        @test occursin("# note", snapshots[:editor])
        @test occursin("12-ab", snapshots[:masked])
        @test occursin("alpha", snapshots[:autocomplete])
        @test occursin("debug", snapshots[:combobox])
        @test occursin("tui", snapshots[:tag_input])
        @test occursin("#", snapshots[:slider])
        @test occursin("[", snapshots[:range_slider])
        @test occursin("Build", snapshots[:timeline])

        tree = ToolkitTree(column(
            Element(grid; id=:data_grid, key=:data_grid, state_factory=() -> grid_state, focusable=true),
            Element(data_table; id=:data_table, key=:data_table, state_factory=() -> data_table_state, focusable=true),
            Element(tree_table; id=:tree_table, key=:tree_table, state_factory=() -> tree_table_state, focusable=true),
            Element(editor; id=:code_editor, key=:code_editor, state_factory=() -> editor_state, focusable=true),
            Element(masked; id=:masked_input, key=:masked_input, state_factory=() -> masked_state, focusable=true),
            Element(autocomplete; id=:autocomplete, key=:autocomplete, state_factory=() -> autocomplete_state, focusable=true),
            Element(combobox; id=:combobox, key=:combobox, state_factory=() -> combobox_state, focusable=true),
            Element(tag_input; id=:tag_input, key=:tag_input, state_factory=() -> tag_input_state, focusable=true),
            Element(slider; id=:slider, key=:slider, state_factory=() -> slider_state, focusable=true),
            Element(range_slider; id=:range_slider, key=:range_slider, state_factory=() -> range_slider_state, focusable=true),
            Element(timeline; id=:timeline, key=:timeline, state_factory=() -> timeline_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(12, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))

        grid_node = semantic_node(semantics, "data_grid")
        @test grid_node.role == TableRole
        @test !isempty(grid_node.children)
        @test grid_node.children[1].role == RowRole
        data_table_node = semantic_node(semantics, "data_table")
        @test data_table_node.role == TableRole
        @test data_table_node.label == "Data table"
        @test !isempty(data_table_node.children)
        @test data_table_semantic_tree(data_table, data_table_state; id="direct-data-table").root.label == "Data table"

        tree_table_node = semantic_node(semantics, "tree_table")
        @test tree_table_node.role == TreeRole
        @test !isempty(tree_table_node.children)
        @test tree_table_node.children[1].role == TreeItemRole
        @test tree_table_node.children[1].state.selected

        editor_node = semantic_node(semantics, "code_editor")
        @test editor_node.role == TextboxRole
        @test editor_node.state.value == code_editor_text(editor_state)
        @test editor_node.metadata[:language] == "julia"

        masked_node = semantic_node(semantics, "masked_input")
        @test masked_node.role == TextboxRole
        @test masked_node.metadata[:complete]

        autocomplete_node = semantic_node(semantics, "autocomplete")
        @test autocomplete_node.role == ListRole
        @test !isempty(autocomplete_node.children)

        combobox_node = semantic_node(semantics, "combobox")
        @test combobox_node.role == GroupRole
        @test !isempty(combobox_node.children)

        tag_input_node = semantic_node(semantics, "tag_input")
        @test tag_input_node.role == ListRole
        @test !isempty(tag_input_node.children)

        slider_node = semantic_node(semantics, "slider")
        @test slider_node.role == SliderRole
        @test slider_node.state.value_now == slider_state.value

        range_slider_node = semantic_node(semantics, "range_slider")
        @test range_slider_node.role == GroupRole
        @test length(range_slider_node.children) == 2

        timeline_node = semantic_node(semantics, "timeline")
        @test timeline_node.role == ListRole
        @test length(timeline_node.children) == 2
        @test timeline_node.children[1].state.selected
        dispatcher = SemanticDispatcher()
        register_code_editor_semantic_handlers!(dispatcher, :code_editor, editor, editor_state)
        register_timeline_semantic_handlers!(dispatcher, :timeline, timeline_state)
        pilot = SemanticPilot(semantics; dispatcher)
        editor_focus = perform_semantic_action!(pilot, "code_editor", FocusSemanticAction)
        @test editor_focus.handled
        @test editor_focus.value[:language] == "julia"
        editor_set = perform_semantic_action!(pilot, "code_editor", SetValueSemanticAction; value="println(:ok)")
        @test editor_set.handled
        @test code_editor_text(editor_state) == "println(:ok)"
        next_timeline = perform_semantic_action!(pilot, "timeline", IncrementSemanticAction)
        @test next_timeline.handled
        @test timeline_state.timeline.focused == 2
        previous_timeline = perform_semantic_action!(pilot, "timeline", DecrementSemanticAction)
        @test previous_timeline.handled
        @test timeline_state.timeline.focused == 1
        select_timeline = perform_semantic_action!(pilot, "timeline/2", SelectSemanticAction)
        @test select_timeline.handled
        @test select_timeline.value == :test
        @test timeline_state.timeline.focused == 2
        set_timeline = perform_semantic_action!(pilot, "timeline", SetValueSemanticAction; value=:build)
        @test set_timeline.handled
        @test timeline_state.timeline.focused == 1
        missing_timeline = perform_semantic_action!(pilot, "timeline", SetValueSemanticAction; value=:missing)
        @test !missing_timeline.handled
    end

    @testset "primitive table and tree semantic handlers" begin
        table = Table(
            [TableColumn("Name"), TableColumn("Status")],
            [["Build", "Ready"], ["Test", "Queued"]],
        )
        table_state = TableState(selected_row=1, selected_column=1)
        tree_widget = Tree([
            TreeNode(:root, "Root"; children=[TreeNode(:child, "Child")]),
        ])
        tree_state = TreeState(selected=:root, expanded=[:root])
        tree_view = TreeView([
            TreeNode(:project, "Project"; children=[TreeNode(:build, "Build")]),
        ])
        tree_view_state = TreeViewState(selected=:project)
        toolkit = ToolkitTree(column(
            Element(table; id=:table, key=:table, state_factory=() -> table_state, focusable=true),
            Element(tree_widget; id=:tree, key=:tree, state_factory=() -> tree_state, focusable=true),
            Element(tree_view; id=:tree_view, key=:tree_view, state_factory=() -> tree_view_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(8, 40)), toolkit)
        semantics = toolkit_semantic_tree(toolkit)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "table").role == TableRole
        @test semantic_node(semantics, "table/row-1").role == RowRole
        @test semantic_node(semantics, "table/row-1/cell-1").role == CellRole
        @test semantic_node(semantics, "tree").role == TreeRole
        @test semantic_node(semantics, "tree/root-1").role == TreeItemRole
        @test semantic_node(semantics, "tree_view").role == TreeRole

        dispatcher = SemanticDispatcher()
        register_table_semantic_handlers!(dispatcher, :table, table, table_state; viewport_height=2)
        register_tree_semantic_handlers!(dispatcher, :tree, tree_widget, tree_state; viewport_height=2)
        register_tree_view_semantic_handlers!(dispatcher, :tree_view, tree_view, tree_view_state; viewport_height=2)
        pilot = SemanticPilot(semantics; dispatcher)

        table_next = perform_semantic_action!(pilot, "table", IncrementSemanticAction)
        @test table_next.handled
        @test table_state.selected_row == 2
        table_cell = perform_semantic_action!(pilot, "table/row-1/cell-2", SelectSemanticAction)
        @test table_cell.handled
        @test table_state.selected_row == 1
        @test table_state.selected_column == 2

        tree_child = perform_semantic_action!(pilot, "tree/root-1/child-1", SelectSemanticAction)
        @test tree_child.handled
        @test tree_state.selected == :child
        tree_collapse = perform_semantic_action!(pilot, "tree/root-1", CollapseSemanticAction)
        @test tree_collapse.handled
        @test !(:root in tree_state.expanded)
        tree_view_set = perform_semantic_action!(pilot, "tree_view", SetValueSemanticAction; value=:build)
        @test tree_view_set.handled
        @test tree_view_state.selected == :build
    end

    @testset "application shell toolkit semantics" begin
        hub = DiagnosticsHub()
        drawer = Drawer(Label("Tools"); size=12, modal=true)
        drawer_state = state_for(drawer)
        drawer_state.open = true
        popover = Popover(Label("Details"), Rect(1, 1, 1, 4); width=12, height=3)
        popover_state = state_for(popover)
        popover_state.open = true
        inspector = Inspector(hub; visible=true, width=20, height=4)
        inspector_state = state_for(inspector)
        console = DevConsole(hub; visible=true, width=20, height=4)
        console_state = state_for(console)

        for (widget, state) in ((drawer, drawer_state), (popover, popover_state), (inspector, inspector_state), (console, console_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (8, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(8, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
        end

        @test handle!(drawer_state, drawer, KeyEvent(Key(:escape)))
        drawer_state.open = true
        @test handle!(drawer_state, drawer, MouseEvent(Position(1, 24), LeftMouseButton, MousePress), Rect(1, 1, 8, 24))
        @test handle!(popover_state, popover, KeyEvent(Key(:escape)))
        popover_state.open = true
        @test handle!(popover_state, popover, MouseEvent(Position(8, 24), LeftMouseButton, MousePress), Rect(1, 1, 8, 24))
        @test handle!(inspector_state, inspector, KeyEvent(Key(:tab)))
        @test handle!(console_state, console, KeyEvent(Key(:down)))

        drawer_state.open = true
        popover_state.open = true
        tree = ToolkitTree(column(
            Element(drawer; id=:drawer, key=:drawer, state_factory=() -> drawer_state, focusable=true),
            Element(popover; id=:popover, key=:popover, state_factory=() -> popover_state, focusable=true),
            Element(inspector; id=:inspector, key=:inspector, state_factory=() -> inspector_state, focusable=true),
            Element(console; id=:console, key=:console, state_factory=() -> console_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(16, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "drawer").state.expanded
        @test semantic_node(semantics, "drawer").metadata[:modal]
        @test semantic_node(semantics, "popover").state.expanded
        @test semantic_node(semantics, "inspector").metadata[:panel] == inspector_state.panel
        @test semantic_node(semantics, "console").state.expanded
        dispatcher = SemanticDispatcher()
        register_drawer_semantic_handlers!(dispatcher, :drawer, drawer_state)
        register_popover_semantic_handlers!(dispatcher, :popover, popover_state; dismissible=popover.dismissible)
        register_inspector_semantic_handlers!(dispatcher, :inspector, inspector_state)
        register_dev_console_semantic_handlers!(dispatcher, :console, console, console_state)
        pilot = SemanticPilot(semantics; dispatcher)
        drawer_dismiss = perform_semantic_action!(pilot, "drawer", DismissSemanticAction)
        @test drawer_dismiss.handled
        @test !drawer_state.open
        popover_dismiss = perform_semantic_action!(pilot, "popover", DismissSemanticAction)
        @test popover_dismiss.handled
        @test !popover_state.open
        drawer_expand = perform_semantic_action!(pilot, "drawer", ExpandSemanticAction)
        @test drawer_expand.handled
        @test drawer_state.open
        popover_expand = perform_semantic_action!(pilot, "popover", ExpandSemanticAction)
        @test popover_expand.handled
        @test popover_state.open
        inspector_next = perform_semantic_action!(pilot, "inspector", IncrementSemanticAction)
        @test inspector_next.handled
        @test inspector_next.value[:panel] == inspector_state.panel
        inspector_dismiss = perform_semantic_action!(pilot, "inspector", DismissSemanticAction)
        @test inspector_dismiss.handled
        @test !inspector_state.visible
        console_focus = perform_semantic_action!(pilot, "console", FocusSemanticAction)
        @test console_focus.handled
        @test console_state.visible
        console_set = perform_semantic_action!(pilot, "console", SetValueSemanticAction; value=0)
        @test console_set.handled
        @test console_set.value[:offset] == 0
        console_dismiss = perform_semantic_action!(pilot, "console", DismissSemanticAction)
        @test console_dismiss.handled
        @test !console_state.visible
    end

    @testset "streaming toolkit semantics" begin
        tracker = ProgressTracker()
        add_progress_task!(tracker, :build; description="Build", total=10)
        advance_progress!(tracker, :build, 5)
        live = LiveDisplay(state -> "frame $(state.frame)"; width=20, height=1)
        live_state = state_for(live)
        progress = ProgressGroup(tracker; width=20, height=2)
        progress_state = state_for(progress)
        process = ProcessView(ProcessResult(`echo ok`, 0, UInt8['o', 'k'], UInt8[]); width=20, height=3)
        process_state = state_for(process)
        terminal = TerminalView("one\ntwo"; width=20, height=2)
        terminal_state = state_for(terminal)
        task = Task(() -> nothing)
        monitor = TaskMonitor([task]; width=20, height=2)
        monitor_state = state_for(monitor)
        log = LogState()
        push_log!(log, "watch"; level=:warning)
        tail = LogTail(log; width=20, height=2)
        rich_log = RichLog()
        rich_log_state = state_for(rich_log)
        push_log!(rich_log_state, "rich"; level=:info)
        @test RichLogState === LogState
        repl = ReplView(command -> "echo: " * command; width=20, height=3)
        repl_state = state_for(repl)

        widgets = ((live, live_state), (progress, progress_state), (process, process_state), (terminal, terminal_state), (monitor, monitor_state), (tail, log), (rich_log, rich_log_state), (repl, repl_state))
        for (widget, state) in widgets
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
        end

        @test handle!(live_state, live, KeyEvent(Key(:character); text=" "))
        @test handle!(progress_state, progress, KeyEvent(Key(:down)))
        @test handle!(process_state, process, KeyEvent(Key(:down)))
        @test handle!(terminal_state, terminal, KeyEvent(Key(:down)))
        @test handle!(monitor_state, monitor, KeyEvent(Key(:down)))
        @test handle!(log, tail, KeyEvent(Key(:down)))
        @test handle!(rich_log_state, rich_log, KeyEvent(Key(:down)))
        @test handle!(repl_state, repl, KeyEvent(Key(:character); text="1 + 1"))
        @test handle!(repl_state, repl, KeyEvent(Key(:enter)))

        tree = ToolkitTree(column(
            Element(live; id=:live, key=:live, state_factory=() -> live_state, focusable=true),
            Element(progress; id=:progress, key=:progress, state_factory=() -> progress_state, focusable=true),
            Element(process; id=:process, key=:process, state_factory=() -> process_state, focusable=true),
            Element(terminal; id=:terminal, key=:terminal, state_factory=() -> terminal_state, focusable=true),
            Element(monitor; id=:monitor, key=:monitor, state_factory=() -> monitor_state, focusable=true),
            Element(tail; id=:tail, key=:tail, state_factory=() -> log, focusable=true),
            Element(repl; id=:repl, key=:repl, state_factory=() -> repl_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(24, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "live").metadata[:paused]
        @test semantic_node(semantics, "progress").role == ListRole
        @test semantic_node(semantics, "progress").children[1].state.value == "50%"
        @test semantic_node(semantics, "process").state.readonly
        @test semantic_node(semantics, "terminal").state.readonly
        @test semantic_node(semantics, "monitor").children[1].metadata[:task_index] == 1
        @test semantic_node(semantics, "tail").children[1].metadata[:level] == :warning
        @test semantic_node(semantics, "repl").metadata[:output_count] == 2
        dispatcher = SemanticDispatcher()
        register_live_display_semantic_handlers!(dispatcher, :live, live_state)
        register_progress_group_semantic_handlers!(dispatcher, :progress, progress, progress_state)
        register_process_view_semantic_handlers!(dispatcher, :process, process, process_state)
        register_terminal_view_semantic_handlers!(dispatcher, :terminal, terminal, terminal_state)
        register_task_monitor_semantic_handlers!(dispatcher, :monitor, monitor, monitor_state)
        register_log_tail_semantic_handlers!(dispatcher, :tail, tail, log)
        register_rich_log_semantic_handlers!(dispatcher, :rich_log, rich_log_state; viewport_height=2)
        register_repl_view_semantic_handlers!(dispatcher, :repl, repl, repl_state)
        pilot = SemanticPilot(semantics; dispatcher)
        live_toggle = perform_semantic_action!(pilot, "live", ActivateSemanticAction)
        @test live_toggle.handled
        @test !live_state.paused
        @test perform_semantic_action!(pilot, "progress", IncrementSemanticAction).handled
        @test perform_semantic_action!(pilot, "process", ScrollIntoViewSemanticAction).handled
        @test perform_semantic_action!(pilot, "terminal", ScrollIntoViewSemanticAction).handled
        @test perform_semantic_action!(pilot, "monitor", ScrollIntoViewSemanticAction).handled
        @test perform_semantic_action!(pilot, "tail", ScrollIntoViewSemanticAction).handled

        notification_center = NotificationCenter(3)
        push_notification!(notification_center, Notification("Saved"; id=:saved, title="Build", severity=:success))
        notification_view = NotificationView(notification_center)
        manager = NotificationManager()
        notify!(
            manager,
            "Deploy failed";
            id=:deploy,
            title="Deploy",
            severity=:error,
            timeout=nothing,
            actions=[NotificationAction(:retry, "Retry", :retry_deploy)],
        )
        managed_notifications = ManagedNotificationView(manager)
        single_progress = Progress(0.5; label="Build")
        single_progress_state = ProgressState()
        service_tree = ToolkitTree(Column(
            Element(notification_view; id=:notifications, key=:notifications),
            Element(managed_notifications; id=:managed_notifications, key=:managed_notifications),
            Element(single_progress; id=:single_progress, key=:single_progress, state_factory=() -> single_progress_state),
        ))
        service_semantics = toolkit_semantic_tree(service_tree)
        service_dispatcher = SemanticDispatcher()
        register_notification_view_semantic_handlers!(service_dispatcher, :notifications, notification_view)
        binding = register_managed_notification_view_semantic_handlers!(
            service_dispatcher,
            :managed_notifications,
            managed_notifications,
        )
        register_progress_semantic_handlers!(service_dispatcher, :single_progress, single_progress, single_progress_state)
        service_pilot = SemanticPilot(service_semantics; dispatcher=service_dispatcher)
        @test perform_semantic_action!(service_pilot, "notifications/notification/saved", DismissSemanticAction).handled
        @test isempty(notification_center.notifications)
        action_result = perform_semantic_action!(
            service_pilot,
            "managed_notifications/1/action/1",
            ActivateSemanticAction,
        )
        @test action_result.handled
        @test action_result.value == :retry_deploy
        @test perform_semantic_action!(service_pilot, "single_progress", SelectSemanticAction).value[:ratio] == 0.5
        @test unbind_notification_semantics!(binding)

        form = Form([
            FormField(:environment; label="Environment", initial="", validators=[required_validator()]),
            FormField(:version; label="Version", initial="dev"),
        ])
        form_state = FormState(form)
        form_dispatcher = SemanticDispatcher()
        register_form_semantic_handlers!(form_dispatcher, :deploy_form, form, form_state)
        form_root = SemanticNode(
            "deploy_form",
            GroupRole;
            label="Form",
            children=SemanticToolkit.widget_semantic_children(form, form_state, "deploy_form"),
        )
        form_pilot = SemanticPilot(SemanticTree(form_root); dispatcher=form_dispatcher)
        @test perform_semantic_action!(
            form_pilot,
            "deploy_form/field/environment",
            SetValueSemanticAction;
            value="production",
        ).handled
        @test field_value(form_state, :environment) == "production"
        @test perform_semantic_action!(form_pilot, "deploy_form/field/environment", ActivateSemanticAction).handled
        @test field_state(form_state, :environment).status == ValidField
        @test perform_semantic_action!(form_pilot, "deploy_form", DismissSemanticAction).handled
        @test field_value(form_state, :environment) == ""
        @test perform_semantic_action!(pilot, "repl", SetValueSemanticAction; value="status").handled
        @test editing_text(repl_state.input.editing) == "status"
    end

    @testset "media toolkit semantics" begin
        image = RasterImage(1, 1, RGBA32, UInt8[0xff, 0x00, 0x00, 0xff])
        image_view = ImageView(image; width=4, height=2)
        braille = BrailleImage(image; width=4, height=2)
        syntax = SyntaxView("x = 1"; language="julia", width=20, height=3)
        syntax_state = state_for(syntax)
        ansi = AnsiView("\e[31mred\e[0m"; width=20, height=1)
        ansi_state = state_for(ansi)
        link = Hyperlink("Documentation", :docs)
        link_state = state_for(link)
        color = ColorPicker(width=20)
        color_state = state_for(color)
        registry = ThemeRegistry()
        preview = ThemePreview(registry; width=20, height=3)
        preview_state = state_for(preview)

        for (widget, state) in ((image_view, nothing), (braille, nothing), (syntax, syntax_state), (ansi, ansi_state), (link, link_state), (color, color_state), (preview, preview_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                state === nothing ? @test(render!(buffer, widget, buffer.area) === buffer) : @test(render!(buffer, widget, buffer.area, state) === buffer)
            end
            buffer = Buffer(6, 24)
            state === nothing ? render!(buffer, widget, buffer.area) : render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
        end

        @test handle!(syntax_state, syntax, KeyEvent(Key(:down)))
        @test handle!(syntax_state, syntax, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 3, 20))
        @test handle!(ansi_state, ansi, KeyEvent(Key(:down)))
        @test handle!(link_state, link, KeyEvent(Key(:enter)))
        @test handle!(link_state, link, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 1, 20))
        @test handle!(color_state, color, KeyEvent(Key(:right)))
        @test handle!(preview_state, preview, KeyEvent(Key(:down)))

        tree = ToolkitTree(column(
            Element(image_view; id=:image, key=:image),
            Element(braille; id=:braille, key=:braille),
            Element(syntax; id=:syntax, key=:syntax, state_factory=() -> syntax_state, focusable=true),
            Element(ansi; id=:ansi, key=:ansi, state_factory=() -> ansi_state, focusable=true),
            Element(link; id=:link, key=:link, state_factory=() -> link_state, focusable=true),
            Element(color; id=:color, key=:color, state_factory=() -> color_state, focusable=true),
            Element(preview; id=:preview, key=:preview, state_factory=() -> preview_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(24, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "image").metadata[:pixel_width] == 1
        @test semantic_node(semantics, "braille").label == "Unicode image fallback"
        @test semantic_node(semantics, "syntax").metadata[:language] == "julia"
        @test semantic_node(semantics, "ansi").metadata[:sanitized]
        @test semantic_node(semantics, "link").metadata[:target] == :docs
        @test semantic_node(semantics, "color").state.value == color_hex(color_state)
        @test semantic_node(semantics, "preview").role == ListRole
        @test !isempty(semantic_node(semantics, "preview").children)
        media_dispatcher = SemanticDispatcher()
        register_image_view_semantic_handlers!(media_dispatcher, :image, image_view)
        register_braille_image_semantic_handlers!(media_dispatcher, :braille, braille)
        register_syntax_view_semantic_handlers!(media_dispatcher, :syntax, syntax, syntax_state)
        register_ansi_view_semantic_handlers!(media_dispatcher, :ansi, ansi, ansi_state)
        register_hyperlink_semantic_handlers!(media_dispatcher, :link, link, link_state)
        register_color_picker_semantic_handlers!(media_dispatcher, :color, color, color_state)
        register_theme_preview_semantic_handlers!(media_dispatcher, :preview, preview, preview_state)
        media_pilot = SemanticPilot(semantics; dispatcher=media_dispatcher)
        image_focus = perform_semantic_action!(media_pilot, "image", FocusSemanticAction)
        @test image_focus.handled
        @test image_focus.value[:pixel_width] == 1
        braille_select = perform_semantic_action!(media_pilot, "braille", SelectSemanticAction)
        @test braille_select.handled
        @test braille_select.value[:pixel_height] == 1
        @test perform_semantic_action!(media_pilot, "syntax", IncrementSemanticAction).handled
        @test perform_semantic_action!(media_pilot, "ansi", ScrollIntoViewSemanticAction).handled
        @test perform_semantic_action!(media_pilot, "link", ActivateSemanticAction).handled
        color_set = perform_semantic_action!(media_pilot, "color", SetValueSemanticAction; value="#336699")
        @test color_set.handled
        @test color_hex(color_state) == "#336699"
        theme_focus = perform_semantic_action!(media_pilot, "preview", FocusSemanticAction)
        @test theme_focus.handled
        @test theme_focus.value[:theme_count] > 0
        theme_increment = perform_semantic_action!(media_pilot, "preview", IncrementSemanticAction)
        @test theme_increment.handled
        theme_child_id = semantic_node(semantics, "preview").children[1].id
        theme_activate = perform_semantic_action!(media_pilot, theme_child_id, ActivateSemanticAction)
        @test theme_activate.handled
    end

    @testset "code and diff view toolkit semantics" begin
        code = CodeView("one\ntwo\nthree\nfour"; language="julia", width=20, height=2)
        code_state = state_for(code)
        diff = DiffView(parse_unified_diff("--- a/file.jl\n+++ b/file.jl\n@@ -1 +1 @@\n-old\n+new\n"); width=20, height=2)
        diff_state = state_for(diff)

        for (widget, state) in ((code, code_state), (diff, diff_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
        end

        @test handle!(code_state, code, KeyEvent(Key(:down)))
        @test handle!(code_state, code, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 2, 20))
        @test handle!(diff_state, diff, KeyEvent(Key(:down)))
        @test handle!(diff_state, diff, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 2, 20))

        tree = ToolkitTree(column(
            Element(code; id=:code_view, key=:code_view, state_factory=() -> code_state, focusable=true),
            Element(diff; id=:diff_view, key=:diff_view, state_factory=() -> diff_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(8, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "code_view").metadata[:language] == "julia"
        @test semantic_node(semantics, "code_view").state.readonly
        @test semantic_node(semantics, "diff_view").state.readonly
        @test semantic_node(semantics, "diff_view").metadata[:offset] == diff_state.row
        code_dispatcher = SemanticDispatcher()
        register_code_view_semantic_handlers!(code_dispatcher, :code_view, code, code_state)
        register_diff_view_semantic_handlers!(code_dispatcher, :diff_view, diff, diff_state)
        code_pilot = SemanticPilot(semantics; dispatcher=code_dispatcher)
        @test perform_semantic_action!(code_pilot, "code_view", IncrementSemanticAction).handled
        @test perform_semantic_action!(code_pilot, "diff_view", IncrementSemanticAction).handled
    end

    @testset "data navigation toolkit semantics" begin
        properties = PropertyList(["name" => "Wicked", "version" => "dev", "license" => "MIT"]; width=20, height=1)
        property_state = state_for(properties)
        ready_properties = DataStateView(properties)
        loading_properties = DataStateView(properties; status=DataLoading, loading="Loading properties")
        empty_properties = DataStateView(properties; status=DataEmpty, empty="No properties")
        error_properties = DataStateView(properties; status=DataError, error="Property load failed")
        key_values = KeyValueList(["mode" => "prod", "region" => "eu", "profile" => "ci"]; width=20, height=1)
        key_value_state = state_for(key_values)
        metadata = MetadataList(["version" => "dev", "profile" => "ci", "target" => "linux"]; width=20, height=1)
        metadata_state = state_for(metadata)
        descriptions = DescriptionList(["name" => "Terminal UI", "version" => "Development", "license" => "Permissive"]; width=20, height=1)
        description_state = state_for(descriptions)
        definitions = DefinitionList(["widget" => "Renderable UI unit", "state" => "Explicit interaction data"]; width=20, height=1)
        definition_state = state_for(definitions)
        breadcrumbs = Breadcrumb([BreadcrumbItem("Home", :home), BreadcrumbItem("Docs", :docs)]; width=20)
        breadcrumb_state = state_for(breadcrumbs)
        @test selected_breadcrumb_value(breadcrumbs, breadcrumb_state) == :home
        @test data_state_status(ready_properties) == DataReady
        @test data_state_ready(ready_properties)
        @test data_state_loading(loading_properties)
        @test data_state_empty(empty_properties)
        @test data_state_error(error_properties)
        @test select_next_breadcrumb_item!(breadcrumb_state, breadcrumbs) === breadcrumb_state
        @test selected_breadcrumb_item(breadcrumbs, breadcrumb_state).value == :docs
        @test select_previous_breadcrumb_item!(breadcrumb_state, breadcrumbs) === breadcrumb_state
        @test selected_breadcrumb_value(breadcrumbs, breadcrumb_state) == :home
        @test select_breadcrumb_item!(breadcrumb_state, breadcrumbs, 2) === breadcrumb_state
        @test activate_selected_breadcrumb!(breadcrumb_state, breadcrumbs) == :docs
        pagination = Pagination(50; page_size=10, width=20)
        pagination_state = state_for(pagination)

        for (widget, state) in ((properties, property_state), (ready_properties, property_state), (key_values, key_value_state), (metadata, metadata_state), (descriptions, description_state), (definitions, definition_state), (breadcrumbs, breadcrumb_state), (pagination, pagination_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
        end

        @test handle!(property_state, properties, KeyEvent(Key(:down)))
        @test handle!(property_state, ready_properties, KeyEvent(Key(:down)))
        @test !handle!(property_state, loading_properties, KeyEvent(Key(:down)))
        @test handle!(property_state, properties, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(property_state, ready_properties, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test !handle!(property_state, error_properties, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(key_value_state, key_values, KeyEvent(Key(:down)))
        @test handle!(key_value_state, key_values, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(metadata_state, metadata, KeyEvent(Key(:down)))
        @test handle!(metadata_state, metadata, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(description_state, descriptions, KeyEvent(Key(:down)))
        @test handle!(description_state, descriptions, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(definition_state, definitions, KeyEvent(Key(:down)))
        @test handle!(definition_state, definitions, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(breadcrumb_state, breadcrumbs, KeyEvent(Key(:right)))
        @test handle!(breadcrumb_state, breadcrumbs, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 1, 20))
        @test handle!(pagination_state, pagination, KeyEvent(Key(:right)))
        @test handle!(pagination_state, pagination, MouseEvent(Position(1, 18), LeftMouseButton, MousePress), Rect(1, 1, 1, 20))

        tree = ToolkitTree(column(
            Element(properties; id=:properties, key=:properties, state_factory=() -> property_state, focusable=true),
            Element(loading_properties; id=:loading_properties, key=:loading_properties, state_factory=() -> property_state, focusable=true),
            Element(error_properties; id=:error_properties, key=:error_properties, state_factory=() -> property_state, focusable=true),
            Element(key_values; id=:key_values, key=:key_values, state_factory=() -> key_value_state, focusable=true),
            Element(metadata; id=:metadata, key=:metadata, state_factory=() -> metadata_state, focusable=true),
            Element(descriptions; id=:descriptions, key=:descriptions, state_factory=() -> description_state, focusable=true),
            Element(definitions; id=:definitions, key=:definitions, state_factory=() -> definition_state, focusable=true),
            Element(breadcrumbs; id=:breadcrumbs, key=:breadcrumbs, state_factory=() -> breadcrumb_state, focusable=true),
            Element(pagination; id=:pagination, key=:pagination, state_factory=() -> pagination_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(12, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "properties").children[1].description == "Wicked"
        @test semantic_node(semantics, "loading_properties").state.busy
        @test semantic_node(semantics, "error_properties").state.invalid
        @test semantic_node(semantics, "key_values").children[1].description == "prod"
        @test semantic_node(semantics, "metadata").children[1].description == "dev"
        @test semantic_node(semantics, "descriptions").children[1].description == "Terminal UI"
        @test semantic_node(semantics, "definitions").children[1].description == "Renderable UI unit"
        @test semantic_node(semantics, "breadcrumbs").children[1].state.selected
        @test semantic_node(semantics, "pagination").state.value_now == pagination_state.page

        dispatcher = SemanticDispatcher()
        register_property_list_semantic_handlers!(dispatcher, :properties, properties, property_state)
        register_data_state_view_semantic_handlers!(dispatcher, :loading_properties, loading_properties)
        register_data_state_view_semantic_handlers!(dispatcher, :error_properties, error_properties)
        register_key_value_list_semantic_handlers!(dispatcher, :key_values, key_values, key_value_state)
        register_metadata_list_semantic_handlers!(dispatcher, :metadata, metadata, metadata_state)
        register_description_list_semantic_handlers!(dispatcher, :descriptions, descriptions, description_state)
        register_definition_list_semantic_handlers!(dispatcher, :definitions, definitions, definition_state)
        register_breadcrumb_semantic_handlers!(dispatcher, :breadcrumbs, breadcrumbs, breadcrumb_state)
        register_pagination_semantic_handlers!(dispatcher, :pagination, pagination_state)
        pilot = SemanticPilot(semantics; dispatcher)
        property_focus_result = perform_semantic_action!(pilot, "properties", FocusSemanticAction)
        @test property_focus_result.handled
        @test property_focus_result.value[:offset] == property_state.row
        property_increment_result = perform_semantic_action!(pilot, "properties", IncrementSemanticAction)
        @test property_increment_result.handled
        @test property_increment_result.value[:offset] == property_state.row
        property_set_result = perform_semantic_action!(pilot, "properties", SetValueSemanticAction; value=0)
        @test property_set_result.handled
        @test property_set_result.value[:offset] == 0
        loading_focus_result = perform_semantic_action!(pilot, "loading_properties", FocusSemanticAction)
        @test loading_focus_result.handled
        @test loading_focus_result.value[:loading]
        error_focus_result = perform_semantic_action!(pilot, "error_properties", FocusSemanticAction)
        @test error_focus_result.handled
        @test error_focus_result.value[:error]
        key_value_focus_result = perform_semantic_action!(pilot, "key_values", FocusSemanticAction)
        @test key_value_focus_result.handled
        @test key_value_focus_result.value[:offset] == key_value_state.row
        key_value_increment_result = perform_semantic_action!(pilot, "key_values", IncrementSemanticAction)
        @test key_value_increment_result.handled
        @test key_value_increment_result.value[:offset] == key_value_state.row
        key_value_set_result = perform_semantic_action!(pilot, "key_values", SetValueSemanticAction; value=0)
        @test key_value_set_result.handled
        @test key_value_set_result.value[:offset] == 0
        metadata_focus_result = perform_semantic_action!(pilot, "metadata", FocusSemanticAction)
        @test metadata_focus_result.handled
        @test metadata_focus_result.value[:offset] == metadata_state.row
        metadata_increment_result = perform_semantic_action!(pilot, "metadata", IncrementSemanticAction)
        @test metadata_increment_result.handled
        @test metadata_increment_result.value[:offset] == metadata_state.row
        metadata_set_result = perform_semantic_action!(pilot, "metadata", SetValueSemanticAction; value=0)
        @test metadata_set_result.handled
        @test metadata_set_result.value[:offset] == 0
        description_focus_result = perform_semantic_action!(pilot, "descriptions", FocusSemanticAction)
        @test description_focus_result.handled
        @test description_focus_result.value[:offset] == description_state.row
        description_increment_result = perform_semantic_action!(pilot, "descriptions", IncrementSemanticAction)
        @test description_increment_result.handled
        @test description_increment_result.value[:offset] == description_state.row
        description_set_result = perform_semantic_action!(pilot, "descriptions", ScrollIntoViewSemanticAction; value=0)
        @test description_set_result.handled
        @test description_set_result.value[:offset] == 0
        definition_focus_result = perform_semantic_action!(pilot, "definitions", FocusSemanticAction)
        @test definition_focus_result.handled
        @test definition_focus_result.value[:offset] == definition_state.row
        definition_increment_result = perform_semantic_action!(pilot, "definitions", IncrementSemanticAction)
        @test definition_increment_result.handled
        @test definition_increment_result.value[:offset] == definition_state.row
        definition_set_result = perform_semantic_action!(pilot, "definitions", ScrollIntoViewSemanticAction; value=0)
        @test definition_set_result.handled
        @test definition_set_result.value[:offset] == 0
        focus_result = perform_semantic_action!(pilot, "breadcrumbs", FocusSemanticAction)
        @test focus_result.handled
        @test focus_result.value == selected_breadcrumb_value(breadcrumbs, breadcrumb_state)
        select_result = perform_semantic_action!(pilot, "breadcrumbs/1", SelectSemanticAction)
        @test select_result.handled
        @test select_result.value == :home
        @test selected_breadcrumb_value(breadcrumbs, breadcrumb_state) == :home
        activate_result = perform_semantic_action!(pilot, "breadcrumbs/2", ActivateSemanticAction)
        @test activate_result.handled
        @test activate_result.value == :docs
        increment_result = perform_semantic_action!(pilot, "pagination", IncrementSemanticAction)
        @test increment_result.handled
        @test increment_result.value == pagination_state.page
        decrement_result = perform_semantic_action!(pilot, "pagination", DecrementSemanticAction)
        @test decrement_result.handled
        @test decrement_result.value == pagination_state.page
        set_result = perform_semantic_action!(pilot, "pagination", SetValueSemanticAction; value=5)
        @test set_result.handled
        @test set_result.value == 5
        invalid_result = perform_semantic_action!(pilot, "pagination", SetValueSemanticAction; value="bad")
        @test !invalid_result.handled
    end

    @testset "visualization toolkit semantics" begin
        plot = Plot([(0.0, 0.0), (1.0, 1.0)]; width=12, height=4)
        meter = Meter(3; minimum=0, maximum=4, label="Capacity", width=12, height=2)

        for widget in (plot, meter)
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area)
            @test !isempty(plain_snapshot(buffer))
        end

        tree = ToolkitTree(column(
            Element(plot; id=:plot, key=:plot),
            Element(meter; id=:meter, key=:meter),
        ))
        render_toolkit!(Frame(Buffer(8, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "plot").role == ImageRole
        @test semantic_node(semantics, "plot").metadata[:width] == 12
        @test semantic_node(semantics, "meter").role == ProgressRole
        @test semantic_node(semantics, "meter").state.value_now == 3.0
    end

    @testset "date and time input toolkit semantics" begin
        date_input = DateInput(selected=Dates.Date(2026, 1, 15), width=20, height=8)
        date_state = state_for(date_input)
        date_picker = DatePicker(selected=Dates.Date(2026, 1, 15), width=20, height=8)
        date_picker_state = state_for(date_picker)
        time_input = TimeInput(value=Dates.Time(12, 0); width=20)
        time_state = state_for(time_input)
        time_picker = TimePicker(value=Dates.Time(12, 0); width=20)
        time_picker_state = state_for(time_picker)
        datetime_input = DateTimeInput(Dates.DateTime(2026, 1, 15, 12); width=20, height=8)
        datetime_state = state_for(datetime_input)
        datetime_picker = DateTimePicker(Dates.DateTime(2026, 1, 15, 12); width=20, height=8)
        datetime_picker_state = state_for(datetime_picker)

        for (widget, state) in ((date_input, date_state), (date_picker, date_picker_state), (time_input, time_state), (time_picker, time_picker_state), (datetime_input, datetime_state), (datetime_picker, datetime_picker_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (10, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(10, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))

            default_buffer = Buffer(10, 24)
            @test render!(default_buffer, widget, default_buffer.area) === default_buffer
            @test !isempty(plain_snapshot(default_buffer))
        end

        @test handle!(date_state, date_input, KeyEvent(Key(:down)))
        @test handle!(date_state, date_input, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 8, 20))
        @test handle!(date_picker_state, date_picker, KeyEvent(Key(:down)))
        @test handle!(date_picker_state, date_picker, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 8, 20))
        @test handle!(time_state, time_input, KeyEvent(Key(:up)))
        @test handle!(time_state, time_input, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(time_picker_state, time_picker, KeyEvent(Key(:up)))
        @test handle!(time_picker_state, time_picker, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(datetime_state, datetime_input, KeyEvent(Key(:tab)))
        @test handle!(datetime_state, datetime_input, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 8, 20))
        @test handle!(datetime_picker_state, datetime_picker, KeyEvent(Key(:tab)))
        @test handle!(datetime_picker_state, datetime_picker, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 8, 20))
        @test Wicked.SemanticToolkit.widget_semantic_descriptor(datetime_picker, datetime_picker_state).label == "Date-time picker"

        tree = ToolkitTree(column(
            Element(date_input; id=:date_input, key=:date_input, state_factory=() -> date_state, focusable=true),
            Element(date_picker; id=:date_picker, key=:date_picker, state_factory=() -> date_picker_state, focusable=true),
            Element(time_input; id=:time_input, key=:time_input, state_factory=() -> time_state, focusable=true),
            Element(time_picker; id=:time_picker, key=:time_picker, state_factory=() -> time_picker_state, focusable=true),
            Element(datetime_input; id=:datetime_input, key=:datetime_input, state_factory=() -> datetime_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(18, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "date_input").state.value == string(date_state.selected)
        @test semantic_node(semantics, "date_picker").state.value == string(date_picker_state.selected)
        @test semantic_node(semantics, "time_input").metadata[:step_seconds] == 60
        @test semantic_node(semantics, "time_picker").metadata[:step_seconds] == 60
        @test semantic_node(semantics, "datetime_input").metadata[:active_field] == :time
        dispatcher = SemanticDispatcher()
        register_date_input_semantic_handlers!(dispatcher, :date_input, date_state)
        register_date_picker_semantic_handlers!(dispatcher, :date_picker, date_picker_state)
        register_time_input_semantic_handlers!(dispatcher, :time_input, time_state)
        register_time_picker_semantic_handlers!(dispatcher, :time_picker, time_picker_state)
        register_date_time_input_semantic_handlers!(dispatcher, :datetime_input, datetime_input, datetime_state)
        pilot = SemanticPilot(semantics; dispatcher)
        date_set = perform_semantic_action!(pilot, "date_input", SetValueSemanticAction; value="2026-02-01")
        @test date_set.handled
        @test date_state.selected == Dates.Date(2026, 2, 1)
        @test perform_semantic_action!(pilot, "date_picker", IncrementSemanticAction).handled
        time_set = perform_semantic_action!(pilot, "time_input", SetValueSemanticAction; value="13:30:00")
        @test time_set.handled
        @test time_state.value == Dates.Time(13, 30)
        @test perform_semantic_action!(pilot, "time_picker", IncrementSemanticAction).handled
        datetime_set = perform_semantic_action!(pilot, "datetime_input", SetValueSemanticAction; value="2026-02-01T13:30:00")
        @test datetime_set.handled
        @test datetime_state.date.selected == Dates.Date(2026, 2, 1)
        @test datetime_state.time.value == Dates.Time(13, 30)
    end

    @testset "number input toolkit semantics" begin
        widget = NumberInput(placeholder="Quantity")
        state = NumberInputState(value=2, minimum=0, maximum=10, step=0.5)
        for (height, width) in ((0, 0), (1, 1), (2, 4), (4, 20))
            buffer = Buffer(height, width)
            @test render!(buffer, widget, buffer.area, state) === buffer
        end
        buffer = Buffer(1, 20)
        render!(buffer, widget, buffer.area, state)
        @test occursin("2", plain_snapshot(buffer))
        default_buffer = Buffer(1, 20)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("Quantity", plain_snapshot(default_buffer))
        @test handle!(state, widget, KeyEvent(Key(:up)))
        @test handle!(state, widget, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 1, 20))

        tree = ToolkitTree(Element(widget; id=:number_input, key=:number_input, state_factory=() -> state, focusable=true))
        render_toolkit!(Frame(Buffer(2, 24)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        node = semantic_node(semantics, "number_input")
        @test node.role == SliderRole
        @test node.state.value_now == 2.5
        @test node.state.value_min == 0.0
        @test node.metadata[:step] == 0.5
        dispatcher = SemanticDispatcher()
        register_number_input_semantic_handlers!(dispatcher, :number_input, widget, state)
        pilot = SemanticPilot(semantics; dispatcher)
        @test perform_semantic_action!(pilot, "number_input", FocusSemanticAction).handled
        set_result = perform_semantic_action!(pilot, "number_input", SetValueSemanticAction; value=4.5)
        @test set_result.handled
        @test state.value == 4.5
        @test perform_semantic_action!(pilot, "number_input", IncrementSemanticAction).handled
        @test state.value == 5.0
        @test perform_semantic_action!(pilot, "number_input", DecrementSemanticAction).handled
        @test state.value == 4.5
    end

    @testset "completion and transfer control semantics" begin
        autocomplete = Autocomplete(["deploy", "rollback", "restart"]; max_visible=2)
        autocomplete_state = state_for(autocomplete)
        update_autocomplete!(autocomplete_state, "de")
        combo = ComboBox(["staging", "production"]; max_visible=2)
        combo_state = state_for(combo)
        tags = TagInput(["julia"]; width=24, maximum=3)
        tags_state = state_for(tags)
        transfer = TransferList([:build => "Build", :test => "Test"])
        transfer_state = state_for(transfer)
        tree = ToolkitTree(Column(
            Element(autocomplete; id=:autocomplete, key=:autocomplete, state_factory=() -> autocomplete_state, focusable=true),
            Element(combo; id=:combo, key=:combo, state_factory=() -> combo_state, focusable=true),
            Element(tags; id=:tags, key=:tags, state_factory=() -> tags_state, focusable=true),
            Element(transfer; id=:transfer, key=:transfer, state_factory=() -> transfer_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(8, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "autocomplete").metadata[:match_count] == 1
        @test semantic_node(semantics, "combo").metadata[:match_count] == 2
        @test semantic_node(semantics, "tags").metadata[:tag_count] == 1
        @test semantic_node(semantics, "transfer").metadata[:option_count] == 2

        dispatcher = SemanticDispatcher()
        register_autocomplete_semantic_handlers!(dispatcher, :autocomplete, autocomplete, autocomplete_state)
        register_combo_box_semantic_handlers!(dispatcher, :combo, combo, combo_state)
        register_tag_input_semantic_handlers!(dispatcher, :tags, tags, tags_state)
        register_transfer_list_semantic_handlers!(dispatcher, :transfer, transfer, transfer_state)
        pilot = SemanticPilot(semantics; dispatcher)

        autocomplete_set = perform_semantic_action!(pilot, "autocomplete", SetValueSemanticAction; value="roll")
        @test autocomplete_set.handled
        @test autocomplete_state.query == "roll"
        autocomplete_activate = perform_semantic_action!(pilot, "autocomplete", ActivateSemanticAction)
        @test autocomplete_activate.handled

        combo_set = perform_semantic_action!(pilot, "combo", SetValueSemanticAction; value="production")
        @test combo_set.handled
        @test combo_state.selected == "production"

        tags_set = perform_semantic_action!(pilot, "tags", SetValueSemanticAction; value=["julia", "terminal"])
        @test tags_set.handled
        @test tags_state.tags == ["julia", "terminal"]
        tag_remove = perform_semantic_action!(pilot, "tags/1", ActivateSemanticAction)
        @test tag_remove.handled
        @test tags_state.tags == ["terminal"]

        transfer_move = perform_semantic_action!(pilot, "transfer", IncrementSemanticAction)
        @test transfer_move.handled
        transfer_select = perform_semantic_action!(pilot, "transfer/1", SelectSemanticAction)
        @test transfer_select.handled
        @test selected_values(transfer, transfer_state) == [:build]
    end

    @testset "selection control semantic handlers" begin
        choices = [ChoiceOption(:debug, "Debug"), ChoiceOption(:release, "Release")]
        radio = RadioGroup(choices)
        radio_state = RadioGroupState(selected=1)
        select = Select(choices)
        select_state = SelectState(selected=1)
        dropdown = Combobox(choices)
        dropdown_state = state_for(dropdown)
        multi = MultiSelect(choices)
        multi_state = MultiSelectState(selected=[1])
        checklist = CheckBoxList(choices)
        checklist_state = CheckBoxListState(selected=[1])
        selection = SelectionList(choices)
        selection_state = SelectionListState(selected=[2])
        list_box = ListBox(["Build", "Test"])
        list_box_state = state_for(list_box)
        tree = ToolkitTree(Column(
            Element(radio; id=:radio, key=:radio, state_factory=() -> radio_state, focusable=true),
            Element(select; id=:select, key=:select, state_factory=() -> select_state, focusable=true),
            Element(dropdown; id=:dropdown, key=:dropdown, state_factory=() -> dropdown_state, focusable=true),
            Element(multi; id=:multi, key=:multi, state_factory=() -> multi_state, focusable=true),
            Element(checklist; id=:checklist, key=:checklist, state_factory=() -> checklist_state, focusable=true),
            Element(selection; id=:selection, key=:selection, state_factory=() -> selection_state, focusable=true),
            Element(list_box; id=:list_box, key=:list_box, state_factory=() -> list_box_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(12, 36)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "radio/option-1").role == RadioRole
        @test semantic_node(semantics, "select/option-1").role == ListItemRole
        @test semantic_node(semantics, "multi/option-1").role == CheckboxRole
        @test semantic_node(semantics, "list_box").metadata[:item_count] == 2

        dispatcher = SemanticDispatcher()
        register_radio_group_semantic_handlers!(dispatcher, :radio, radio, radio_state)
        register_select_semantic_handlers!(dispatcher, :select, select, select_state)
        register_combobox_semantic_handlers!(dispatcher, :dropdown, dropdown, dropdown_state)
        register_multi_select_semantic_handlers!(dispatcher, :multi, multi, multi_state)
        register_check_box_list_semantic_handlers!(dispatcher, :checklist, checklist, checklist_state)
        register_selection_list_semantic_handlers!(dispatcher, :selection, selection, selection_state)
        register_list_box_semantic_handlers!(dispatcher, :list_box, list_box, list_box_state)
        pilot = SemanticPilot(semantics; dispatcher)

        radio_select = perform_semantic_action!(pilot, "radio/option-2", SelectSemanticAction)
        @test radio_select.handled
        @test selected_value(radio, radio_state) == :release

        select_set = perform_semantic_action!(pilot, "select", SetValueSemanticAction; value=:release)
        @test select_set.handled
        @test selected_value(select, select_state) == :release

        dropdown_open = perform_semantic_action!(pilot, "dropdown", ActivateSemanticAction)
        @test dropdown_open.handled
        dropdown_select = perform_semantic_action!(pilot, "dropdown/option-2", ActivateSemanticAction)
        @test dropdown_select.handled
        @test selected_value(dropdown, dropdown_state) == :release

        multi_toggle = perform_semantic_action!(pilot, "multi/option-2", SelectSemanticAction)
        @test multi_toggle.handled
        @test selected_values(multi, multi_state) == [:debug, :release]

        checklist_set = perform_semantic_action!(pilot, "checklist", SetValueSemanticAction; value=[:release])
        @test checklist_set.handled
        @test selected_values(checklist, checklist_state) == [:release]

        selection_move = perform_semantic_action!(pilot, "selection", DecrementSemanticAction)
        @test selection_move.handled

        list_set = perform_semantic_action!(pilot, "list_box", SetValueSemanticAction; value="Test")
        @test list_set.handled
        @test list_box_state.selected == 2
    end

    @testset "navigation view toolkit semantics" begin
        tabs = TabView([:first => "First", :second => "Second"], [Label("One"), Label("Two")])
        tabs_state = state_for(tabs)
        @test selected_tab_view(tabs, tabs_state).id == :first
        @test selected_tab_view_content(tabs, tabs_state) isa Label
        @test select_next_tab_view!(tabs_state, tabs) === tabs_state
        @test selected_tab_view(tabs, tabs_state).id == :second
        @test select_previous_tab_view!(tabs_state, tabs) === tabs_state
        @test selected_tab_view(tabs, tabs_state).id == :first
        @test select_tab_view!(tabs_state, tabs, 2) === tabs_state
        @test selected_tab_view(tabs, tabs_state).id == :second
        @test select_tab!(tabs_state, tabs, 1) === tabs_state
        rail = NavigationRail([MenuItem(:home, "Home", :home), MenuItem(:settings, "Settings", :settings)])
        rail_state = state_for(rail)
        @test selected_navigation_item(rail, rail_state).message == :home
        @test select_next_navigation_item!(rail_state, rail) === rail_state
        @test selected_navigation_message(rail, rail_state) == :settings
        @test select_previous_navigation_item!(rail_state, rail) === rail_state
        @test selected_navigation_item(rail, rail_state).message == :home
        @test select_navigation_item!(rail_state, rail, 2) === rail_state
        @test selected_navigation_message(rail, rail_state) == :settings

        for (widget, state) in ((tabs, tabs_state), (rail, rail_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
            default_buffer = Buffer(6, 24)
            @test render!(default_buffer, widget, default_buffer.area) === default_buffer
            @test !isempty(plain_snapshot(default_buffer))
        end

        @test handle!(tabs_state, tabs, KeyEvent(Key(:right)))
        @test handle!(tabs_state, tabs, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 3, 20))
        @test handle!(rail_state, rail, KeyEvent(Key(:down)))
        @test handle!(rail_state, rail, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 4, 20))

        tree = ToolkitTree(column(
            Element(tabs; id=:tab_view, key=:tab_view, state_factory=() -> tabs_state, focusable=true),
            Element(rail; id=:navigation_rail, key=:navigation_rail, state_factory=() -> rail_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(10, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "tab_view").role == TabListRole
        @test semantic_node(semantics, "tab_view").children[1].state.selected
        @test semantic_node(semantics, "navigation_rail").role == MenuRole
        @test semantic_node(semantics, "navigation_rail").children[1].role == MenuItemRole

        dispatcher = SemanticDispatcher()
        register_tab_view_semantic_handlers!(dispatcher, :tab_view, tabs, tabs_state)
        register_navigation_rail_semantic_handlers!(dispatcher, :navigation_rail, rail, rail_state)
        pilot = SemanticPilot(semantics; dispatcher)
        focus_result = perform_semantic_action!(pilot, "tab_view", FocusSemanticAction)
        @test focus_result.handled
        @test focus_result.value == selected_tab_view(tabs, tabs_state).id
        select_result = perform_semantic_action!(pilot, "tab_view/2", SelectSemanticAction)
        @test select_result.handled
        @test select_result.value == :second
        @test selected_tab_view(tabs, tabs_state).id == :second
        focus_tab_result = perform_semantic_action!(pilot, "tab_view/1", FocusSemanticAction)
        @test focus_tab_result.handled
        @test focus_tab_result.value == :first
        @test selected_tab_view(tabs, tabs_state).id == :first
        pop!(tabs.tabs.tabs)
        stale_result = perform_semantic_action!(pilot, "tab_view/2", SelectSemanticAction)
        @test !stale_result.handled
        @test occursin("not available", stale_result.message)
        rail_select_result = perform_semantic_action!(pilot, "navigation_rail/item-1", SelectSemanticAction)
        @test rail_select_result.handled
        @test rail_select_result.value == :home
        @test selected_navigation_message(rail, rail_state) == :home
        rail_activate_result = perform_semantic_action!(pilot, "navigation_rail/item-2", ActivateSemanticAction)
        @test rail_activate_result.handled
        @test rail_activate_result.value == :settings
    end

    @testset "menu action toolkit semantics" begin
        menu_button = MenuButton("Open", :open)
        menu_button_state = state_for(menu_button)
        split_button = SplitButton("Save", :save)
        split_button_state = state_for(split_button)
        context = ContextMenu([MenuItem(:copy, "Copy"), MenuItem(:paste, "Paste")])
        context_state = state_for(context)

        for (widget, state) in ((menu_button, menu_button_state), (split_button, split_button_state), (context, context_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
            default_buffer = Buffer(6, 24)
            @test render!(default_buffer, widget, default_buffer.area) === default_buffer
            @test !isempty(plain_snapshot(default_buffer))
        end

        @test handle!(menu_button_state, menu_button, KeyEvent(Key(:enter)))
        @test handle!(menu_button_state, menu_button, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 1, 20))
        @test handle!(split_button_state, split_button, KeyEvent(Key(:enter)))
        @test handle!(split_button_state, split_button, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 1, 20))
        @test handle!(context_state, context, KeyEvent(Key(:down)))
        @test handle!(context_state, context, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 4, 20))

        tree = ToolkitTree(column(
            Element(menu_button; id=:menu_button, key=:menu_button, state_factory=() -> menu_button_state, focusable=true),
            Element(split_button; id=:split_button, key=:split_button, state_factory=() -> split_button_state, focusable=true),
            Element(context; id=:context_menu, key=:context_menu, state_factory=() -> context_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(12, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "menu_button").role == ButtonRole
        @test semantic_node(semantics, "split_button").role == ButtonRole
        @test semantic_node(semantics, "context_menu").role == MenuRole
        @test length(semantic_node(semantics, "context_menu").children) == 2
        dispatcher = SemanticDispatcher()
        register_menu_button_semantic_handlers!(dispatcher, :menu_button, menu_button, menu_button_state)
        register_split_button_semantic_handlers!(dispatcher, :split_button, split_button, split_button_state)
        register_context_menu_semantic_handlers!(dispatcher, :context_menu, context, context_state)
        pilot = SemanticPilot(semantics; dispatcher)
        menu_button_result = perform_semantic_action!(pilot, "menu_button", ActivateSemanticAction)
        @test menu_button_result.handled
        @test menu_button_result.value == :open
        split_button_result = perform_semantic_action!(pilot, "split_button", ActivateSemanticAction)
        @test split_button_result.handled
        @test split_button_result.value == :save
        context_focus = perform_semantic_action!(pilot, "context_menu", FocusSemanticAction)
        @test context_focus.handled
        context_select = perform_semantic_action!(pilot, "context_menu/1", SelectSemanticAction)
        @test context_select.handled
        @test context_select.value == :copy
        context_activate = perform_semantic_action!(pilot, "context_menu/2", ActivateSemanticAction)
        @test context_activate.handled
        @test context_activate.value == :paste
    end

    @testset "stepper toolkit semantics" begin
        widget = Stepper()
        state = StepperState(["Prepare" => :prepare, "Build" => :build, "Release" => :release])
        for (height, width) in ((0, 0), (1, 1), (2, 4), (4, 24))
            buffer = Buffer(height, width)
            @test render!(buffer, widget, buffer.area, state) === buffer
        end
        buffer = Buffer(1, 24)
        render!(buffer, widget, buffer.area, state)
        @test occursin("Prepare", plain_snapshot(buffer))
        default_buffer = Buffer(1, 24)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test handle!(state, widget, KeyEvent(Key(:right)))
        @test handle!(state, widget, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 1, 24))

        tree = ToolkitTree(Element(widget; id=:stepper, key=:stepper, state_factory=() -> state, focusable=true))
        render_toolkit!(Frame(Buffer(2, 24)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        node = semantic_node(semantics, "stepper")
        @test node.role == ListRole
        @test node.children[1].state.selected
        @test node.children[1].state.value == string(ActiveStep)
        dispatcher = SemanticDispatcher()
        register_stepper_semantic_handlers!(dispatcher, :stepper, state)
        pilot = SemanticPilot(semantics; dispatcher)
        increment_result = perform_semantic_action!(pilot, "stepper", IncrementSemanticAction)
        @test increment_result.handled
        decrement_result = perform_semantic_action!(pilot, "stepper", DecrementSemanticAction)
        @test decrement_result.handled
        complete_result = perform_semantic_action!(pilot, "stepper", ActivateSemanticAction)
        @test complete_result.handled
        jump_result = perform_semantic_action!(pilot, "stepper", SetValueSemanticAction; value=:release)
        @test jump_result.handled
        @test state.current == 3
        fail_result = perform_semantic_action!(pilot, "stepper", SetValueSemanticAction; value=:fail)
        @test fail_result.handled
        @test state.statuses[state.current] == FailedStep
        bad_result = perform_semantic_action!(pilot, "stepper", SetValueSemanticAction; value=:missing)
        @test !bad_result.handled
    end

    @testset "file picker toolkit semantics" begin
        mktempdir() do root
            write(joinpath(root, "alpha.txt"), "alpha")
            write(joinpath(root, "beta.txt"), "beta")
            mkdir(joinpath(root, "nested"))
            widgets = (
                (:file_picker, FilePicker(root; root, width=24, height=4), "File picker", SelectFileMode),
                (:directory_picker, DirectoryPicker(root; root, width=24, height=4), "Directory picker", SelectDirectoryMode),
                (:directory_tree, DirectoryTree(root; root, width=24, height=4), "Directory tree", SelectDirectoryMode),
                (:multi_file_picker, MultiFilePicker(root; root, width=24, height=4), "Multiple-file picker", SelectMultipleMode),
            )
            for (id, widget, label, mode) in widgets
                state = state_for(widget)
                widget isa DirectoryTree && @test DirectoryTreeState === FileBrowserState
                @test state.mode == mode
                @test length(state.entries) == 3
                for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                    buffer = Buffer(height, width)
                    @test render!(buffer, widget, buffer.area, state) === buffer
                end
                buffer = Buffer(6, 24)
                render!(buffer, widget, buffer.area, state)
                @test occursin("alpha.txt", plain_snapshot(buffer))
                default_buffer = Buffer(6, 24)
                @test render!(default_buffer, widget, default_buffer.area) === default_buffer
                @test occursin("alpha.txt", plain_snapshot(default_buffer))
                @test handle!(state, widget, KeyEvent(Key(:down)))
                @test handle!(state, widget, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 4, 24))

                tree = ToolkitTree(Element(widget; id, key=id, state_factory=() -> state, focusable=true))
                render_toolkit!(Frame(Buffer(6, 32)), tree)
                semantics = toolkit_semantic_tree(tree)
                @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
                node = semantic_node(semantics, string(id))
                @test node.role == TreeRole
                @test node.label == label
                @test node.metadata[:mode] == mode
                if widget isa DirectoryTree
                    @test node.label == "Directory tree"
                    @test node.metadata[:mode] == SelectDirectoryMode
                end
                @test length(node.children) == 3
                @test node.children[1].metadata[:path] == state.entries[1].path
                dispatcher = SemanticDispatcher()
                if widget isa FilePicker
                    register_file_picker_semantic_handlers!(dispatcher, id, widget, state)
                elseif widget isa DirectoryPicker
                    register_directory_picker_semantic_handlers!(dispatcher, id, widget, state)
                elseif widget isa DirectoryTree
                    register_directory_tree_semantic_handlers!(dispatcher, id, widget, state)
                else
                    register_multi_file_picker_semantic_handlers!(dispatcher, id, widget, state)
                end
                pilot = SemanticPilot(semantics; dispatcher)
                focus_result = perform_semantic_action!(pilot, string(id), FocusSemanticAction)
                @test focus_result.handled
                increment_result = perform_semantic_action!(pilot, string(id), IncrementSemanticAction)
                @test increment_result.handled
                select_result = perform_semantic_action!(pilot, "$(id)/entry-1", SelectSemanticAction)
                @test select_result.handled
                @test state.entries[1].path in state.selected
                first_entry_kind = state.entries[1].kind
                activate_result = perform_semantic_action!(pilot, "$(id)/entry-1", ActivateSemanticAction)
                @test activate_result.handled || first_entry_kind == DirectoryFileEntry
            end
        end
    end

    @testset "composition widget toolkit semantics" begin
        collapsible_widget = Collapsible("Details", Label("Hidden"); expanded=true, width=24, height=2)
        accordion_widget = Accordion([(:details, "Details", Label("Hidden"))]; expanded=[:details], width=24, item_height=1)
        widgets = (
            (:border, Border(title="Border")),
            (:card, Card(Label("Card"))),
            (:panel, Panel(Label("Panel"))),
            (:layer, Layer(Label("Back"), Label("Front"))),
            (:group, Group(Label("One"), Label("Two"); gap=1)),
            (:flow, Flow(Label("One"), Label("Two"); column_gap=1)),
            (:wrap, Wrap(Label("One"), Label("Two"); column_gap=1)),
            (:padding_layout, Padding(Label("Padding"); margin=Margin(1))),
            (:box_layout, Box(Label("Box"); block=Block(title="Box"))),
            (:row_layout, Row(Label("Left"), Label("Right"); gap=1)),
            (:column_layout, Column(Label("Top"), Label("Bottom"); gap=1)),
            (:stack_layout, Stack(Label("Back"), Label("Front"))),
            (:overlay_layout, Overlay(Label("Base"), Label("Overlay"))),
            (:center_layout, Center(Label("Center"); height=1, width=8)),
            (:grid_layout, Grid(Label("Grid"); rows=[Fill(1)], columns=[Fill(1)])),
            (:collapsible, collapsible_widget),
            (:accordion, accordion_widget),
            (:carousel, Carousel(["Overview", "Logs"]; width=24, height=3)),
            (:header, Header("Wicked"; subtitle="Shell")),
            (:footer, Footer([KeyHint("q", "Quit")])),
            (:title_bar, TitleBar("Wicked"; subtitle="Shell")),
            (:status_bar, StatusBar([KeyHint("q", "Quit")])),
            (:menu_bar, MenuBar(Label("File"), Label("Edit"))),
            (:toolbar, Toolbar(Label("Run"), Label("Stop"))),
            (:shortcuts, ShortcutBar([KeyHint("q", "Quit")])),
            (:status, Status("Ready")),
            (:toast, Toast("Saved")),
            (:skeleton, Skeleton()),
            (:placeholder, Placeholder("Results")),
            (:empty, EmptyState("No results"; message="Try another query.", action_label="Reset filters")),
        )
        for (_, widget) in widgets
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                if widget isa Skeleton
                    @test render!(buffer, widget, buffer.area, state_for(widget)) === buffer
                else
                    @test render!(buffer, widget, buffer.area) === buffer
                end
            end
            buffer = Buffer(6, 24)
            if widget isa Skeleton
                render!(buffer, widget, buffer.area, state_for(widget))
            else
                render!(buffer, widget, buffer.area)
            end
            @test !isempty(plain_snapshot(buffer))
        end

        skeleton_state = state_for(Skeleton())
        @test handle!(skeleton_state, Skeleton(), TickEvent(UInt64(1), UInt64(3)))
        @test skeleton_state.phase == 1
        indicator = LoadingIndicator(frames=["a", "b"]; label="Loading")
        indicator_state = state_for(indicator)
        @test indicator isa LoadingIndicator
        @test indicator_state isa SpinnerState
        @test handle!(indicator_state, indicator, TickEvent(UInt64(1), UInt64(3)))
        @test LoadingIndicatorState === SpinnerState
        spinner = Spinner(frames=["a", "b"]; label="Loading")
        spinner_state = state_for(spinner)
        placeholder = Placeholder("Results")

        tree = ToolkitTree(column((Element(widget; id=name, key=name) for (name, widget) in widgets)...))
        render_toolkit!(Frame(Buffer(24, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "border").label == "Border"
        @test semantic_node(semantics, "card").label == "Card"
        @test semantic_node(semantics, "panel").label == "Panel"
        @test semantic_node(semantics, "accordion").children[1].state.expanded
        @test semantic_node(semantics, "collapsible").state.expanded
        @test semantic_node(semantics, "carousel").metadata[:item_count] == 2
        @test semantic_node(semantics, "flow").label == "Flow layout"
        @test semantic_node(semantics, "wrap").label == "Wrap layout"
        @test semantic_node(semantics, "shortcuts").metadata[:hint_count] == 1
        @test semantic_node(semantics, "status").metadata[:severity] == :info
        @test semantic_node(semantics, "toast").metadata[:severity] == :info
        @test semantic_node(semantics, "skeleton").state.busy
        @test semantic_node(semantics, "empty").description == "Try another query."
        @test semantic_node(semantics, "empty/action").label == "Reset filters"

        dispatcher = SemanticDispatcher()
        collapsible_action_state = state_for(collapsible_widget)
        accordion_action_state = state_for(accordion_widget)
        register_border_semantic_handlers!(dispatcher, :border, widgets[1][2])
        register_card_semantic_handlers!(dispatcher, :card, widgets[2][2])
        register_panel_semantic_handlers!(dispatcher, :panel, widgets[3][2])
        register_layer_semantic_handlers!(dispatcher, :layer, widgets[4][2])
        register_group_semantic_handlers!(dispatcher, :group, widgets[5][2])
        register_flow_semantic_handlers!(dispatcher, :flow, widgets[6][2])
        register_wrap_semantic_handlers!(dispatcher, :wrap, widgets[7][2])
        register_padding_semantic_handlers!(dispatcher, :padding_layout, widgets[8][2])
        register_box_semantic_handlers!(dispatcher, :box_layout, widgets[9][2])
        register_row_semantic_handlers!(dispatcher, :row_layout, widgets[10][2])
        register_column_semantic_handlers!(dispatcher, :column_layout, widgets[11][2])
        register_stack_semantic_handlers!(dispatcher, :stack_layout, widgets[12][2])
        register_overlay_semantic_handlers!(dispatcher, :overlay_layout, widgets[13][2])
        register_center_semantic_handlers!(dispatcher, :center_layout, widgets[14][2])
        register_grid_semantic_handlers!(dispatcher, :grid_layout, widgets[15][2])
        register_collapsible_semantic_handlers!(dispatcher, :collapsible, collapsible_action_state)
        register_accordion_semantic_handlers!(dispatcher, :accordion, accordion_widget, accordion_action_state)
        pilot = SemanticPilot(semantics; dispatcher)
        for id in (
            "border",
            "card",
            "panel",
            "layer",
            "group",
            "flow",
            "wrap",
            "padding_layout",
            "box_layout",
            "row_layout",
            "column_layout",
            "stack_layout",
            "overlay_layout",
            "center_layout",
            "grid_layout",
        )
            @test perform_semantic_action!(pilot, id, FocusSemanticAction).handled
            @test perform_semantic_action!(pilot, id, SelectSemanticAction).handled
        end
        collapse_result = perform_semantic_action!(pilot, "collapsible", CollapseSemanticAction)
        @test collapse_result.handled
        @test !collapsible_action_state.expanded
        toggle_result = perform_semantic_action!(pilot, "collapsible", ActivateSemanticAction)
        @test toggle_result.handled
        @test collapsible_action_state.expanded
        accordion_collapse_result = perform_semantic_action!(pilot, "accordion/1", CollapseSemanticAction)
        @test accordion_collapse_result.handled
        @test :details ∉ accordion_action_state.expanded
        accordion_toggle_result = perform_semantic_action!(pilot, "accordion/1", ActivateSemanticAction)
        @test accordion_toggle_result.handled
        @test :details in accordion_action_state.expanded

        tooltip = Tooltip("Help text", Rect(2, 2, 1, 4); target=:help, width=16, height=3, delay_ms=0)
        tooltip_state = state_for(tooltip)
        @test tooltip_state isa TooltipState
        @test handle!(tooltip_state, tooltip, MouseEvent(Position(2, 2), NoMouseButton, MouseMove), Rect(1, 1, 6, 24))
        @test tooltip_state.visible
        tooltip_buffer = Buffer(6, 24)
        @test render!(tooltip_buffer, tooltip, tooltip_buffer.area, tooltip_state) === tooltip_buffer
        @test occursin("Help text", plain_snapshot(tooltip_buffer))
        tooltip_tree = ToolkitTree(Element(tooltip; id=:tooltip, key=:tooltip, state_factory=() -> tooltip_state))
        render_toolkit!(Frame(Buffer(6, 24)), tooltip_tree)
        tooltip_node = semantic_node(toolkit_semantic_tree(tooltip_tree), "tooltip")
        @test tooltip_node.label == "Tooltip"
        @test tooltip_node.description == "Help text"
        @test !tooltip_node.state.hidden
        @test tooltip_node.metadata[:target] == :help
        tooltip_dispatcher = SemanticDispatcher()
        register_tooltip_semantic_handlers!(tooltip_dispatcher, :tooltip, tooltip_state; dismissible=tooltip.dismissible)
        tooltip_pilot = SemanticPilot(toolkit_semantic_tree(tooltip_tree); dispatcher=tooltip_dispatcher)
        tooltip_dismiss = perform_semantic_action!(tooltip_pilot, "tooltip", DismissSemanticAction)
        @test tooltip_dismiss.handled
        @test !tooltip_state.visible
        begin_tooltip_hover!(tooltip_state, :help, tooltip.content; now_ns=UInt64(1))
        @test handle!(tooltip_state, tooltip, KeyEvent(Key(:escape)))
        @test !tooltip_state.visible
        delayed_tooltip = Tooltip("Delayed", Rect(2, 2, 1, 4); target=:delay, delay_ms=1)
        delayed_state = state_for(delayed_tooltip)
        @test handle!(delayed_state, delayed_tooltip, MouseEvent(Position(2, 2), NoMouseButton, MouseMove), Rect(1, 1, 6, 24))
        @test !delayed_state.visible
        @test !handle!(delayed_state, delayed_tooltip, TickEvent(UInt64(100), UInt64(100)))
        @test handle!(delayed_state, delayed_tooltip, TickEvent(UInt64(1_000_100), UInt64(1_000_000)))
        @test delayed_state.visible

        collapsible_state = state_for(Collapsible("Details", Label("Hidden")))
        collapsible = Collapsible("Details", Label("Hidden"))
        @test handle!(collapsible_state, collapsible, KeyEvent(Key(:enter)))
        @test collapsible_state.expanded
        @test handle!(collapsible_state, collapsible, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 2, 24))
        @test !collapsible_state.expanded
        accordion = Accordion([(:details, "Details", Label("Hidden"))]; width=24)
        accordion_state = state_for(accordion)
        @test handle!(accordion_state, accordion, KeyEvent(Key(:enter)))
        @test :details in accordion_state.expanded
        @test handle!(accordion_state, accordion, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 2, 24))
        @test :details ∉ accordion_state.expanded
        carousel = Carousel(["Overview", "Logs"]; width=24, height=3)
        carousel_state = state_for(carousel)
        @test handle!(carousel_state, carousel, KeyEvent(Key(:right)))
        @test carousel_state.index == 2
        @test handle!(carousel_state, carousel, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 3, 24))
        @test carousel_state.index == 1

        dispatcher = SemanticDispatcher()
        register_carousel_semantic_handlers!(dispatcher, :carousel, carousel_state)
        register_header_semantic_handlers!(dispatcher, :header, Header("Wicked"; subtitle="Shell"))
        register_footer_semantic_handlers!(dispatcher, :footer, Footer([KeyHint("q", "Quit")]))
        register_title_bar_semantic_handlers!(dispatcher, :title_bar, TitleBar("Wicked"; subtitle="Shell"))
        register_status_bar_semantic_handlers!(dispatcher, :status_bar, StatusBar([KeyHint("q", "Quit")]))
        register_menu_bar_semantic_handlers!(dispatcher, :menu_bar, MenuBar(Label("File"), Label("Edit")))
        register_toolbar_semantic_handlers!(dispatcher, :toolbar, Toolbar(Label("Run"), Label("Stop")))
        register_shortcut_bar_semantic_handlers!(dispatcher, :shortcuts, ShortcutBar([KeyHint("q", "Quit")]))
        register_spinner_semantic_handlers!(dispatcher, :spinner, spinner, spinner_state)
        register_loading_indicator_semantic_handlers!(dispatcher, :loading, indicator, indicator_state)
        register_skeleton_semantic_handlers!(dispatcher, :skeleton, Skeleton(), skeleton_state)
        register_placeholder_semantic_handlers!(dispatcher, :placeholder, placeholder)
        register_empty_state_semantic_handlers!(
            dispatcher,
            "empty",
            EmptyState("No results"; message="Try another query.", action_label="Reset filters");
            value=:reset_filters,
        )
        pilot = SemanticPilot(semantics; dispatcher)
        carousel_next = perform_semantic_action!(pilot, "carousel", IncrementSemanticAction)
        @test carousel_next.handled
        @test carousel_state.index == 2
        carousel_previous = perform_semantic_action!(pilot, "carousel", DecrementSemanticAction)
        @test carousel_previous.handled
        @test carousel_state.index == 1
        carousel_set = perform_semantic_action!(pilot, "carousel", SetValueSemanticAction; value="Logs")
        @test carousel_set.handled
        @test carousel_state.index == 2
        carousel_bad = perform_semantic_action!(pilot, "carousel", SetValueSemanticAction; value="Missing")
        @test !carousel_bad.handled
        result = perform_semantic_action!(pilot, "empty/action", ActivateSemanticAction)
        @test result.handled
        @test result.value == :reset_filters
        @test perform_semantic_action!(pilot, "header", SelectSemanticAction).value[:title] == "Wicked"
        @test perform_semantic_action!(pilot, "title_bar", SelectSemanticAction).value[:subtitle] == "Shell"
        @test perform_semantic_action!(pilot, "footer/hint/1", ActivateSemanticAction).value[:key] == "q"
        @test perform_semantic_action!(pilot, "status_bar/hint/1", ActivateSemanticAction).value[:description] == "Quit"
        @test perform_semantic_action!(pilot, "menu_bar", SelectSemanticAction).value[:label] == "Menu bar"
        @test perform_semantic_action!(pilot, "toolbar", SelectSemanticAction).value[:label] == "Toolbar"
        @test perform_semantic_action!(pilot, "shortcuts/hint/1", ActivateSemanticAction).value[:key] == "q"
        loading_semantics = SemanticTree(SemanticNode(
            "loading_widgets",
            GroupRole;
            children=[
                SemanticNode("spinner", ProgressRole; label="Spinner"),
                SemanticNode("loading", ProgressRole; label="Loading"),
                SemanticNode("skeleton", StatusRole; label="Skeleton"),
                SemanticNode("placeholder", GroupRole; label="Placeholder"),
            ],
        ))
        loading_pilot = SemanticPilot(loading_semantics; dispatcher)
        @test perform_semantic_action!(loading_pilot, "spinner", IncrementSemanticAction).value[:frame] == 2
        @test perform_semantic_action!(loading_pilot, "loading", SelectSemanticAction).value[:indicator] == :loading
        @test perform_semantic_action!(loading_pilot, "skeleton", IncrementSemanticAction).handled
        @test perform_semantic_action!(loading_pilot, "placeholder", SelectSemanticAction).value[:label] == "Results"
    end

    @testset "viewport toolkit semantics" begin
        widget = Viewport(Paragraph("one\ntwo\nthree"); height=2, width=20)
        state = state_for(widget)
        for (height, width) in ((0, 0), (1, 1), (2, 4), (4, 24))
            buffer = Buffer(height, width)
            @test render!(buffer, widget, buffer.area, state) === buffer
        end
        buffer = Buffer(4, 24)
        render!(buffer, widget, buffer.area, state)
        @test occursin("one", plain_snapshot(buffer))
        default_buffer = Buffer(4, 24)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("one", plain_snapshot(default_buffer))
        @test handle!(state, widget, KeyEvent(Key(:down)))
        @test handle!(state, widget, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 2, 20))

        tree = ToolkitTree(Element(widget; id=:viewport, key=:viewport, state_factory=() -> state, focusable=true))
        render_toolkit!(Frame(Buffer(4, 24)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        node = semantic_node(semantics, "viewport")
        @test node.role == ScrollbarRole
        @test node.state.value_now == state.row
        dispatcher = SemanticDispatcher()
        register_viewport_semantic_handlers!(dispatcher, :viewport, widget, state; viewport_height=1)
        pilot = SemanticPilot(semantics; dispatcher)
        @test perform_semantic_action!(pilot, "viewport", FocusSemanticAction).handled
        @test perform_semantic_action!(pilot, "viewport", IncrementSemanticAction).handled
        @test state.row >= 1
        viewport_scroll = perform_semantic_action!(pilot, "viewport", ScrollIntoViewSemanticAction; value=0)
        @test viewport_scroll.handled
        @test state.row == 0
    end

    @testset "resizable pane toolkit semantics" begin
        widget = ResizablePane(Label("Left"), Label("Right"); fraction=0.5)
        state = state_for(widget)
        for (height, width) in ((0, 0), (1, 1), (2, 4), (4, 20))
            buffer = Buffer(height, width)
            @test render!(buffer, widget, buffer.area, state) === buffer
        end
        buffer = Buffer(4, 20)
        render!(buffer, widget, buffer.area, state)
        @test occursin("Left", plain_snapshot(buffer))
        default_buffer = Buffer(4, 20)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("Left", plain_snapshot(default_buffer))
        area = Rect(1, 1, 4, 20)
        @test handle!(state, widget, MouseEvent(Position(1, 11), LeftMouseButton, MousePress), area)
        @test handle!(state, widget, MouseEvent(Position(1, 15), LeftMouseButton, MouseDrag), area)
        @test state.fraction > 0.5

        tree = ToolkitTree(Element(widget; id=:resizable_pane, key=:resizable_pane, state_factory=() -> state, focusable=true))
        render_toolkit!(Frame(Buffer(4, 20)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        node = semantic_node(semantics, "resizable_pane")
        @test node.role == SliderRole
        @test node.state.value_now == state.fraction
        dispatcher = SemanticDispatcher()
        register_resizable_pane_semantic_handlers!(dispatcher, :resizable_pane, widget, state)
        pilot = SemanticPilot(semantics; dispatcher)
        @test perform_semantic_action!(pilot, "resizable_pane", FocusSemanticAction).handled
        set_result = perform_semantic_action!(pilot, "resizable_pane", SetValueSemanticAction; value=0.25)
        @test set_result.handled
        @test state.fraction == 0.25
        @test perform_semantic_action!(pilot, "resizable_pane", IncrementSemanticAction).handled
        @test state.fraction > 0.25
    end

    @testset "static layout toolkit semantics" begin
        sidebar = Sidebar(Label("Nav"), Label("Content"); sidebar_size=6, gap=1)
        split = SplitPane(Label("First"), Label("Second"); fraction=0.4, gap=1)
        wrap = Wrap(Label("One"), Label("Two"); column_gap=1)
        for widget in (sidebar, split, wrap)
            for (height, width) in ((0, 0), (1, 1), (2, 4), (4, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area) === buffer
            end
            buffer = Buffer(4, 24)
            render!(buffer, widget, buffer.area)
            @test !isempty(plain_snapshot(buffer))
        end

        tree = ToolkitTree(column(
            Element(sidebar; id=:sidebar, key=:sidebar),
            Element(split; id=:split_pane, key=:split_pane),
        ))
        render_toolkit!(Frame(Buffer(8, 24)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "sidebar").metadata[:side] == :left
        @test semantic_node(semantics, "split_pane").metadata[:fraction] == 0.4
        split_dispatcher = SemanticDispatcher()
        register_split_pane_semantic_handlers!(split_dispatcher, :split_pane, split)
        split_pilot = SemanticPilot(semantics; dispatcher=split_dispatcher)
        @test perform_semantic_action!(split_pilot, "split_pane", FocusSemanticAction).handled
        @test perform_semantic_action!(split_pilot, "split_pane", SelectSemanticAction).handled
        sidebar_dispatcher = SemanticDispatcher()
        register_sidebar_semantic_handlers!(sidebar_dispatcher, :sidebar, sidebar)
        sidebar_pilot = SemanticPilot(semantics; dispatcher=sidebar_dispatcher)
        @test perform_semantic_action!(sidebar_pilot, "sidebar", FocusSemanticAction).handled
        @test perform_semantic_action!(sidebar_pilot, "sidebar", SelectSemanticAction).handled

        wrap_tree = ToolkitTree(Element(wrap; id=:wrap_layout, key=:wrap_layout))
        render_toolkit!(Frame(Buffer(4, 24)), wrap_tree)
        wrap_semantics = toolkit_semantic_tree(wrap_tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(wrap_semantics)))
        @test semantic_node(wrap_semantics, "wrap_layout").label == "Wrap layout"
        wrap_dispatcher = SemanticDispatcher()
        register_wrap_semantic_handlers!(wrap_dispatcher, :wrap_layout, wrap)
        wrap_pilot = SemanticPilot(wrap_semantics; dispatcher=wrap_dispatcher)
        @test perform_semantic_action!(wrap_pilot, "wrap_layout", FocusSemanticAction).handled
        @test perform_semantic_action!(wrap_pilot, "wrap_layout", SelectSemanticAction).handled
    end

    @testset "dock layout toolkit semantics" begin
        widget = DockLayout(
            top=Label("Top"), top_size=1,
            left=Label("Left"), left_size=5,
            center=Label("Center"),
        )
        dock = Dock(
            top=Label("Top"), top_size=1,
            left=Label("Left"), left_size=5,
            center=Label("Center"),
        )
        app_shell = AppShell(
            Label("Center");
            title="Wicked",
            subtitle="Shell",
            toolbar=Toolbar(Label("Run")),
            sidebar=Label("Nav"),
            sidebar_size=5,
            shortcuts=[KeyHint("q", "Quit")],
        )
        for layout_widget in (widget, dock, app_shell)
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, layout_widget, buffer.area) === buffer
            end
        end
        buffer = Buffer(6, 24)
        render!(buffer, widget, buffer.area)
        @test occursin("Center", plain_snapshot(buffer))
        dock_buffer = Buffer(6, 24)
        render!(dock_buffer, dock, dock_buffer.area)
        @test occursin("Center", plain_snapshot(dock_buffer))
        shell_buffer = Buffer(6, 24)
        render!(shell_buffer, app_shell, shell_buffer.area)
        @test occursin("Wicked", plain_snapshot(shell_buffer))
        @test occursin("Center", plain_snapshot(shell_buffer))
        @test app_shell_dock(app_shell) isa Dock
        @test app_shell_layout(app_shell) isa DockLayout
        shell_children, shell_regions, shell_center = app_shell_regions(app_shell, Rect(1, 1, 6, 24))
        @test length(shell_children) == 3
        @test length(shell_regions) == 3
        @test shell_center.width > 0
        shell_summary = app_shell_summary(app_shell)
        @test shell_summary.has_top
        @test shell_summary.has_bottom
        @test shell_summary.has_left
        @test shell_summary.has_center
        @test shell_summary.sidebar_side == :left
        @test shell_summary.top_size == 3

        tree = ToolkitTree(column(
            Element(widget; id=:dock_layout, key=:dock_layout),
            Element(dock; id=:dock, key=:dock),
            Element(app_shell; id=:app_shell, key=:app_shell),
        ))
        render_toolkit!(Frame(Buffer(6, 24)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        node = semantic_node(semantics, "dock_layout")
        @test node.label == "Dock layout"
        @test node.metadata[:top_size] == 1
        @test node.metadata[:left_size] == 5
        dock_node = semantic_node(semantics, "dock")
        @test dock_node.label == "Dock"
        @test dock_node.metadata[:top_size] == 1
        @test dock_node.metadata[:left_size] == 5
        app_shell_node = semantic_node(semantics, "app_shell")
        @test app_shell_node.label == "App shell"
        @test app_shell_node.metadata[:top_size] == 3
        @test app_shell_node.metadata[:left_size] == 5
        dock_dispatcher = SemanticDispatcher()
        register_dock_layout_semantic_handlers!(dock_dispatcher, :dock_layout, widget)
        register_dock_semantic_handlers!(dock_dispatcher, :dock, dock)
        register_app_shell_semantic_handlers!(dock_dispatcher, :app_shell, app_shell)
        dock_pilot = SemanticPilot(semantics; dispatcher=dock_dispatcher)
        @test perform_semantic_action!(dock_pilot, "dock_layout", FocusSemanticAction).handled
        @test perform_semantic_action!(dock_pilot, "dock_layout", SelectSemanticAction).handled
        @test perform_semantic_action!(dock_pilot, "dock", FocusSemanticAction).handled
        @test perform_semantic_action!(dock_pilot, "dock", SelectSemanticAction).handled
        @test perform_semantic_action!(dock_pilot, "app_shell", FocusSemanticAction).handled
        @test perform_semantic_action!(dock_pilot, "app_shell", SelectSemanticAction).value[:label] == "App shell"
        @test_throws ArgumentError AppShell(Label("Center"); sidebar=Label("Nav"), sidebar_side=:top)
    end

    @testset "dialog toolkit semantics" begin
        widget = Dialog("Apply changes?"; title="Confirm")
        modal = Modal("Apply changes?"; title="Confirm")
        window = Window("Apply changes?"; title="Confirm")
        state = DialogState([DialogButton("Cancel", :cancel), DialogButton("Apply", :apply)]; open=true)
        @test state_for(widget) isa DialogState
        @test state_for(modal) isa DialogState
        @test state_for(window) isa DialogState
        @test WindowState === DialogState
        for surface in (widget, modal, window)
            for (height, width) in ((0, 0), (1, 1), (3, 8), (8, 32))
                buffer = Buffer(height, width)
                @test render!(buffer, surface, buffer.area, state) === buffer
            end
        end
        buffer = Buffer(8, 32)
        render!(buffer, widget, buffer.area, state)
        @test occursin("Confirm", plain_snapshot(buffer))
        @test handle!(state, widget, KeyEvent(Key(:right)))

        tree = ToolkitTree(Element(widget; id=:dialog, key=:dialog, state_factory=() -> state, focusable=true))
        render_toolkit!(Frame(Buffer(8, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        node = semantic_node(semantics, "dialog")
        @test node.role == DialogRole
        modal_tree = ToolkitTree(Element(modal; id=:modal, key=:modal, state_factory=() -> state, focusable=true))
        render_toolkit!(Frame(Buffer(8, 32)), modal_tree)
        modal_semantics = toolkit_semantic_tree(modal_tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(modal_semantics)))
        modal_node = semantic_node(modal_semantics, "modal")
        @test modal_node.role == DialogRole
        @test modal_node.label == "Modal"
        window_tree = ToolkitTree(Element(window; id=:window, key=:window, state_factory=() -> state, focusable=true))
        render_toolkit!(Frame(Buffer(8, 32)), window_tree)
        window_semantics = toolkit_semantic_tree(window_tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(window_semantics)))
        window_node = semantic_node(window_semantics, "window")
        @test window_node.role == DialogRole
        @test window_node.label == "Window"
        @test !node.state.hidden
        @test length(node.children) == 2
        @test any(child -> child.state.selected, node.children)

        dispatcher = SemanticDispatcher()
        register_dialog_semantic_handlers!(dispatcher, :dialog, state)
        pilot = SemanticPilot(semantics; dispatcher)
        select_result = perform_semantic_action!(pilot, "dialog/1", SelectSemanticAction)
        @test select_result.handled
        @test select_result.value == :cancel
        @test state.focused == 1
        activate_result = perform_semantic_action!(pilot, "dialog/2", ActivateSemanticAction)
        @test activate_result.handled
        @test activate_result.value == :apply
        @test state.result == :apply
        @test !state.open
        open_dialog!(state)
        dismiss_result = perform_semantic_action!(pilot, "dialog", DismissSemanticAction)
        @test dismiss_result.handled
        @test !state.open
        open_dialog!(state)
        modal_state = DialogState([DialogButton("Close", :close)]; open=true)
        modal_dispatcher = SemanticDispatcher()
        register_modal_semantic_handlers!(modal_dispatcher, :modal, modal, modal_state)
        modal_pilot = SemanticPilot(
            toolkit_semantic_tree(ToolkitTree(Element(modal; id=:modal, key=:modal, state_factory=() -> modal_state, focusable=true)));
            dispatcher=modal_dispatcher,
        )
        modal_result = perform_semantic_action!(modal_pilot, "modal/1", ActivateSemanticAction)
        @test modal_result.handled
        @test modal_result.value == :close
        window_state = WindowState([DialogButton("Close", :close)]; open=true)
        window_dispatcher = SemanticDispatcher()
        register_window_semantic_handlers!(window_dispatcher, :window, window, window_state)
        window_pilot = SemanticPilot(
            toolkit_semantic_tree(ToolkitTree(Element(window; id=:window, key=:window, state_factory=() -> window_state, focusable=true)));
            dispatcher=window_dispatcher,
        )
        window_dismiss = perform_semantic_action!(window_pilot, "window", DismissSemanticAction)
        @test window_dismiss.handled
        @test !window_state.open

        @test handle!(state, widget, MouseEvent(Position(7, 22), LeftMouseButton, MouseRelease), Rect(1, 1, 8, 32))
        render_toolkit!(Frame(Buffer(8, 32)), tree)
        node = semantic_node(toolkit_semantic_tree(tree), "dialog")
        @test node.state.hidden
        @test state.result == :apply
    end

    @testset "progress bar toolkit semantics" begin
        widget = ProgressBar(ratio=nothing, label="Building")
        state = ProgressBarState()
        concise = Progress(0.5; label="Half")
        concise_state = ProgressState()
        @test ProgressState === ProgressBarState
        concise_buffer = Buffer(1, 24)
        @test render!(concise_buffer, concise, concise_buffer.area, concise_state) === concise_buffer
        @test occursin("Half", plain_snapshot(concise_buffer))
        @test handle!(concise_state, Progress(ratio=nothing), TickEvent(UInt64(1), UInt64(1)))
        @test concise_state.phase == 1
        for (height, width) in ((0, 0), (1, 1), (2, 4), (4, 24))
            buffer = Buffer(height, width)
            @test render!(buffer, widget, buffer.area, state) === buffer
        end
        buffer = Buffer(1, 24)
        render!(buffer, widget, buffer.area, state)
        @test occursin("Building", plain_snapshot(buffer))
        @test handle!(state, widget, TickEvent(UInt64(1), UInt64(1)))
        @test state.phase == 1

        tree = ToolkitTree(Element(widget; id=:progress_bar, key=:progress_bar, state_factory=() -> state))
        render_toolkit!(Frame(Buffer(2, 24)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        node = semantic_node(semantics, "progress_bar")
        @test node.role == ProgressRole
        @test node.state.busy
        @test node.metadata[:phase] == UInt64(1)
    end
end
