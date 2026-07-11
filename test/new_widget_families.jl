@testset "New widget family behavior" begin
    @testset "data and editing widgets" begin
        source = VectorDataSource([(name="Ada", score=10), (name="Lin", score=20)])
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
    end

    @testset "visualization and application shell widgets" begin
        plot = Plot([(0.0, 0.0), (1.0, 1.0)]; width=12, height=4)
        @test render!(Buffer(4, 12), plot, Rect(1, 1, 4, 12)) isa Buffer
        meter = Meter(3; minimum=0, maximum=4, orientation=:vertical, width=2, height=4)
        @test meter_ratio(meter) == 0.75

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

        ansi = AnsiView("\e[31mred\e[0m"; width=8, height=1)
        @test ansi_plain_text(ansi.source) == "red"
        @test render!(Buffer(1, 8), ansi, Rect(1, 1, 1, 8), state_for(ansi)) isa Buffer

        link = Hyperlink("docs", :documentation)
        link_state = state_for(link)
        @test handle!(link_state, link, KeyEvent(Key(:enter)))
        @test hyperlink_target(link) == :documentation

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
        tree_source = CallbackTreeDataSource{NamedTuple{(:id, :name),Tuple{Symbol,String}},Symbol}(
            roots=() -> [(id=:root, name="Root")],
            children=item -> item.id == :root ? [(id=:child, name="Child")] : NamedTuple{(:id, :name),Tuple{Symbol,String}}[],
            key=item -> item.id,
        )
        tree_table = TreeTable(tree_source, [VirtualTableColumn(:name, "Name"; accessor=row -> row.name)]; width=24, height=4)
        tree_table_state = state_for(tree_table)
        editor = CodeEditor("x = 1"; language="julia")
        editor_state = state_for(editor)
        masked = MaskedInput("##-AA")
        masked_state = state_for(masked)
        timeline = Timeline([TimelineItem("Build", :build), TimelineItem("Test", :test)]; width=20, height=2)
        timeline_state = state_for(timeline)

        for (widget, state) in ((grid, grid_state), (tree_table, tree_table_state), (editor, editor_state), (masked, masked_state), (timeline, timeline_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
        end

        @test handle!(grid_state, grid, KeyEvent(Key(:down)))
        @test handle!(grid_state, grid, MouseEvent(Position(3, 2), LeftMouseButton, MousePress), Rect(1, 1, 4, 24))
        @test handle!(tree_table_state, tree_table, KeyEvent(Key(:down)))
        @test handle!(tree_table_state, tree_table, MouseEvent(Position(2, 2), LeftMouseButton, MousePress), Rect(1, 1, 4, 24))
        @test handle!(editor_state, editor, KeyEvent(Key(:character); text="\n# note"))
        @test handle!(editor_state, editor, MouseEvent(Position(1, 4), LeftMouseButton, MousePress), Rect(1, 1, 4, 24))
        @test handle!(masked_state, masked, KeyEvent(Key(:character); text="12ab"))
        @test handle!(masked_state, masked, MouseEvent(Position(1, 3), LeftMouseButton, MousePress), Rect(1, 1, 1, 8))
        @test handle!(timeline_state, timeline, KeyEvent(Key(:down)))
        @test handle!(timeline_state, timeline, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 2, 20))

        snapshots = Dict{Symbol,String}()
        for (name, widget, state) in ((:grid, grid, grid_state), (:tree_table, tree_table, tree_table_state), (:editor, editor, editor_state), (:masked, masked, masked_state), (:timeline, timeline, timeline_state))
            buffer = Buffer(4, 24)
            render!(buffer, widget, buffer.area, state)
            snapshots[name] = plain_snapshot(buffer)
            @test !isempty(snapshots[name])
        end
        @test occursin("Ada", snapshots[:grid])
        @test occursin("Root", snapshots[:tree_table])
        @test occursin("# note", snapshots[:editor])
        @test occursin("12-ab", snapshots[:masked])
        @test occursin("Build", snapshots[:timeline])

        tree = ToolkitTree(column(
            Element(grid; id=:data_grid, key=:data_grid, state_factory=() -> grid_state, focusable=true),
            Element(tree_table; id=:tree_table, key=:tree_table, state_factory=() -> tree_table_state, focusable=true),
            Element(editor; id=:code_editor, key=:code_editor, state_factory=() -> editor_state, focusable=true),
            Element(masked; id=:masked_input, key=:masked_input, state_factory=() -> masked_state, focusable=true),
            Element(timeline; id=:timeline, key=:timeline, state_factory=() -> timeline_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(12, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))

        grid_node = semantic_node(semantics, "data_grid")
        @test grid_node.role == TableRole
        @test !isempty(grid_node.children)
        @test grid_node.children[1].role == RowRole

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

        timeline_node = semantic_node(semantics, "timeline")
        @test timeline_node.role == ListRole
        @test length(timeline_node.children) == 2
        @test timeline_node.children[1].state.selected
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
        repl = ReplView(command -> "echo: " * command; width=20, height=3)
        repl_state = state_for(repl)

        widgets = ((live, live_state), (progress, progress_state), (process, process_state), (terminal, terminal_state), (monitor, monitor_state), (tail, log), (repl, repl_state))
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
    end

    @testset "data navigation toolkit semantics" begin
        properties = PropertyList(["name" => "Wicked", "version" => "dev", "license" => "MIT"]; width=20, height=1)
        property_state = state_for(properties)
        descriptions = DescriptionList(["name" => "Terminal UI", "version" => "Development", "license" => "Permissive"]; width=20, height=1)
        description_state = state_for(descriptions)
        breadcrumbs = Breadcrumb([BreadcrumbItem("Home", :home), BreadcrumbItem("Docs", :docs)]; width=20)
        breadcrumb_state = state_for(breadcrumbs)
        pagination = Pagination(50; page_size=10, width=20)
        pagination_state = state_for(pagination)

        for (widget, state) in ((properties, property_state), (descriptions, description_state), (breadcrumbs, breadcrumb_state), (pagination, pagination_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
        end

        @test handle!(property_state, properties, KeyEvent(Key(:down)))
        @test handle!(property_state, properties, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(description_state, descriptions, KeyEvent(Key(:down)))
        @test handle!(description_state, descriptions, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(breadcrumb_state, breadcrumbs, KeyEvent(Key(:right)))
        @test handle!(breadcrumb_state, breadcrumbs, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 1, 20))
        @test handle!(pagination_state, pagination, KeyEvent(Key(:right)))
        @test handle!(pagination_state, pagination, MouseEvent(Position(1, 18), LeftMouseButton, MousePress), Rect(1, 1, 1, 20))

        tree = ToolkitTree(column(
            Element(properties; id=:properties, key=:properties, state_factory=() -> property_state, focusable=true),
            Element(descriptions; id=:descriptions, key=:descriptions, state_factory=() -> description_state, focusable=true),
            Element(breadcrumbs; id=:breadcrumbs, key=:breadcrumbs, state_factory=() -> breadcrumb_state, focusable=true),
            Element(pagination; id=:pagination, key=:pagination, state_factory=() -> pagination_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(12, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "properties").children[1].description == "Wicked"
        @test semantic_node(semantics, "descriptions").children[1].description == "Terminal UI"
        @test semantic_node(semantics, "breadcrumbs").children[1].state.selected
        @test semantic_node(semantics, "pagination").state.value_now == pagination_state.page
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
        time_input = TimeInput(value=Dates.Time(12, 0); width=20)
        time_state = state_for(time_input)
        datetime_input = DateTimeInput(Dates.DateTime(2026, 1, 15, 12); width=20, height=8)
        datetime_state = state_for(datetime_input)

        for (widget, state) in ((date_input, date_state), (time_input, time_state), (datetime_input, datetime_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (10, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(10, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
        end

        @test handle!(date_state, date_input, KeyEvent(Key(:down)))
        @test handle!(date_state, date_input, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 8, 20))
        @test handle!(time_state, time_input, KeyEvent(Key(:up)))
        @test handle!(time_state, time_input, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 1, 20))
        @test handle!(datetime_state, datetime_input, KeyEvent(Key(:tab)))
        @test handle!(datetime_state, datetime_input, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 8, 20))

        tree = ToolkitTree(column(
            Element(date_input; id=:date_input, key=:date_input, state_factory=() -> date_state, focusable=true),
            Element(time_input; id=:time_input, key=:time_input, state_factory=() -> time_state, focusable=true),
            Element(datetime_input; id=:datetime_input, key=:datetime_input, state_factory=() -> datetime_state, focusable=true),
        ))
        render_toolkit!(Frame(Buffer(18, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "date_input").state.value == string(date_state.selected)
        @test semantic_node(semantics, "time_input").metadata[:step_seconds] == 60
        @test semantic_node(semantics, "datetime_input").metadata[:active_field] == :time
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
    end

    @testset "navigation view toolkit semantics" begin
        tabs = TabView([:first => "First", :second => "Second"], [Label("One"), Label("Two")])
        tabs_state = state_for(tabs)
        rail = NavigationRail([MenuItem(:home, "Home"), MenuItem(:settings, "Settings")])
        rail_state = state_for(rail)

        for (widget, state) in ((tabs, tabs_state), (rail, rail_state))
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area, state)
            @test !isempty(plain_snapshot(buffer))
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
    end

    @testset "file picker toolkit semantics" begin
        mktempdir() do root
            write(joinpath(root, "alpha.txt"), "alpha")
            write(joinpath(root, "beta.txt"), "beta")
            widget = FilePicker(root; root, width=24, height=4)
            state = state_for(widget)
            @test length(state.entries) == 2
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area, state) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area, state)
            @test occursin("alpha.txt", plain_snapshot(buffer))
            @test handle!(state, widget, KeyEvent(Key(:down)))
            @test handle!(state, widget, MouseEvent(Position(1, 2), LeftMouseButton, MousePress), Rect(1, 1, 4, 24))

            tree = ToolkitTree(Element(widget; id=:file_picker, key=:file_picker, state_factory=() -> state, focusable=true))
            render_toolkit!(Frame(Buffer(6, 32)), tree)
            semantics = toolkit_semantic_tree(tree)
            @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
            node = semantic_node(semantics, "file_picker")
            @test node.role == TreeRole
            @test length(node.children) == 2
            @test node.children[1].metadata[:path] == state.entries[1].path
        end
    end

    @testset "composition widget toolkit semantics" begin
        widgets = (
            (:card, Card(Label("Card"))),
            (:layer, Layer(Label("Back"), Label("Front"))),
            (:group, Group(Label("One"), Label("Two"); gap=1)),
            (:flow, Flow(Label("One"), Label("Two"); column_gap=1)),
            (:menu_bar, MenuBar(Label("File"), Label("Edit"))),
            (:toolbar, Toolbar(Label("Run"), Label("Stop"))),
            (:shortcuts, ShortcutBar([KeyHint("q", "Quit")])),
            (:status, Status("Ready")),
            (:toast, Toast("Saved")),
        )
        for (_, widget) in widgets
            for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
                buffer = Buffer(height, width)
                @test render!(buffer, widget, buffer.area) === buffer
            end
            buffer = Buffer(6, 24)
            render!(buffer, widget, buffer.area)
            @test !isempty(plain_snapshot(buffer))
        end

        tree = ToolkitTree(column((Element(widget; id=name, key=name) for (name, widget) in widgets)...))
        render_toolkit!(Frame(Buffer(24, 32)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        @test semantic_node(semantics, "card").label == "Card"
        @test semantic_node(semantics, "flow").label == "Flow layout"
        @test semantic_node(semantics, "shortcuts").metadata[:hint_count] == 1
        @test semantic_node(semantics, "status").metadata[:severity] == :info
        @test semantic_node(semantics, "toast").metadata[:severity] == :info
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
        @test handle!(state, widget, KeyEvent(Key(:down)))
        @test handle!(state, widget, MouseEvent(Position(1, 2), WheelDownButton, MouseScroll), Rect(1, 1, 2, 20))

        tree = ToolkitTree(Element(widget; id=:viewport, key=:viewport, state_factory=() -> state, focusable=true))
        render_toolkit!(Frame(Buffer(4, 24)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        node = semantic_node(semantics, "viewport")
        @test node.role == ScrollbarRole
        @test node.state.value_now == state.row
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
    end

    @testset "static layout toolkit semantics" begin
        sidebar = Sidebar(Label("Nav"), Label("Content"); sidebar_size=6, gap=1)
        split = SplitPane(Label("First"), Label("Second"); fraction=0.4, gap=1)
        for widget in (sidebar, split)
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
    end

    @testset "dock layout toolkit semantics" begin
        widget = DockLayout(
            top=Label("Top"), top_size=1,
            left=Label("Left"), left_size=5,
            center=Label("Center"),
        )
        for (height, width) in ((0, 0), (1, 1), (2, 4), (6, 24))
            buffer = Buffer(height, width)
            @test render!(buffer, widget, buffer.area) === buffer
        end
        buffer = Buffer(6, 24)
        render!(buffer, widget, buffer.area)
        @test occursin("Center", plain_snapshot(buffer))

        tree = ToolkitTree(Element(widget; id=:dock_layout, key=:dock_layout))
        render_toolkit!(Frame(Buffer(6, 24)), tree)
        semantics = toolkit_semantic_tree(tree)
        @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
        node = semantic_node(semantics, "dock_layout")
        @test node.label == "Dock layout"
        @test node.metadata[:top_size] == 1
        @test node.metadata[:left_size] == 5
    end

    @testset "dialog toolkit semantics" begin
        widget = Dialog("Apply changes?"; title="Confirm")
        state = DialogState([DialogButton("Cancel", :cancel), DialogButton("Apply", :apply)]; open=true)
        for (height, width) in ((0, 0), (1, 1), (3, 8), (8, 32))
            buffer = Buffer(height, width)
            @test render!(buffer, widget, buffer.area, state) === buffer
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
        @test !node.state.hidden
        @test length(node.children) == 2
        @test any(child -> child.state.selected, node.children)

        @test handle!(state, widget, MouseEvent(Position(7, 22), LeftMouseButton, MouseRelease), Rect(1, 1, 8, 32))
        render_toolkit!(Frame(Buffer(8, 32)), tree)
        node = semantic_node(toolkit_semantic_tree(tree), "dialog")
        @test node.state.hidden
        @test state.result == :apply
    end

    @testset "progress bar toolkit semantics" begin
        widget = ProgressBar(ratio=nothing, label="Building")
        state = ProgressBarState()
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
