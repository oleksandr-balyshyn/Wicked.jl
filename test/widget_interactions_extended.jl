@testset "Extended widget interactions" begin
    @testset "link keyboard and pointer activation" begin
        widget = Link("Documentation", :open_docs)
        state = LinkState(focused=true)

        @test handle!(state, widget, KeyEvent(Key(:enter)))
        @test activate(widget, state) == :open_docs

        area = Rect(1, 1, 1, 16)
        @test handle!(
            state,
            widget,
            MouseEvent(Position(1, 2), LeftMouseButton, MousePress),
            area,
        )
        @test state.hovered
        @test state.pressed
        @test handle!(
            state,
            widget,
            MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease),
            area,
        )
        @test !state.pressed
        @test !handle!(
            state,
            widget,
            MouseEvent(Position(2, 2), LeftMouseButton, MouseRelease),
            area,
        )

        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, state)
        @test descriptor.role == Wicked.Accessibility.LinkRole
        @test descriptor.label == "Documentation"
        @test descriptor.state.enabled
        @test descriptor.state.focusable
        @test descriptor.state.focused
        @test descriptor.metadata[:target] == :open_docs
        @test Wicked.Accessibility.ActivateSemanticAction in descriptor.actions

        node = link_semantic_node(widget, state; id=:docs)
        @test node.id == "docs"
        @test node.role == Wicked.Accessibility.LinkRole
        @test node.metadata[:target] == :open_docs

        disabled = Link("Unavailable", :none; disabled=true)
        disabled_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(disabled, LinkState())
        @test !disabled_descriptor.state.enabled
        @test !disabled_descriptor.state.focusable
        @test isempty(disabled_descriptor.actions)
    end

    @testset "link rendering, clipping, and toolkit state" begin
        widget = Link("Documentation", :open_docs)
        state = LinkState()

        zero = Buffer(0, 0)
        @test render!(zero, widget, zero.area, state) === zero

        minimal = Buffer(1, 1)
        @test render!(minimal, widget, minimal.area, state) === minimal
        @test minimal.cells[1].grapheme == "…"

        clipped = Buffer(1, 4)
        @test render!(clipped, widget, Rect(1, 2, 1, 2), state) === clipped
        @test clipped.cells[2].grapheme == "D"
        @test clipped.cells[3].grapheme == "…"

        resized = Buffer(1, 16)
        @test render!(resized, widget, resized.area, state) === resized
        @test join(cell.grapheme for cell in resized.cells[1:13]) == "Documentation"

        backend = TestBackend(1, 16)
        terminal = Terminal(backend)
        draw!(terminal) do frame
            render!(frame, widget, frame.area, state)
        end
        @test plain_snapshot(backend.screen) == "Documentation"
        @test Wicked.Toolkit.state_for(widget) isa LinkState
    end

    @testset "progress and spinner ticks" begin
        progress = ProgressBar(ratio=nothing)
        progress_state = ProgressBarState()
        @test handle!(progress_state, progress, TickEvent(UInt64(1), UInt64(1)))
        @test progress_state.phase == 1

        spinner = Spinner(frames=["a", "b"])
        spinner_state = SpinnerState()
        @test handle!(spinner_state, spinner, TickEvent(UInt64(2), UInt64(1)))
        @test spinner_state.frame == 2
        @test handle!(spinner_state, spinner, TickEvent(UInt64(3), UInt64(1)))
        @test spinner_state.frame == 1
    end

    @testset "command palette filtering and activation" begin
        widget = CommandPalette([
            CommandItem(:open, "Open", :opened),
            CommandItem(:quit, "Quit", :quit),
        ])
        state = CommandPaletteState(open=true)

        @test handle!(state, widget, PasteEvent("op"))
        @test editing_text(state.query.editing) == "op"
        @test state.filtered == [1]
        @test state.selected == 1
        @test activate(widget, state) == :opened

        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, state)
        children = Wicked.SemanticToolkit.widget_semantic_children(widget, state, :palette)
        @test descriptor.role == Wicked.Accessibility.DialogRole
        @test descriptor.state.focused
        @test descriptor.metadata[:query] == "op"
        @test descriptor.metadata[:result_count] == 1
        @test length(children) == 2
        @test children[1].role == Wicked.Accessibility.SearchboxRole
        @test children[1].state.value == "op"
        @test children[2].role == Wicked.Accessibility.ListItemRole
        @test children[2].state.selected
        @test children[2].metadata[:command_id] == :open
        @test Wicked.Toolkit.state_for(widget) isa CommandPaletteState

        @test handle!(state, widget, KeyEvent(Key(:escape)))
        @test !state.open
        @test isempty(Wicked.SemanticToolkit.widget_semantic_children(widget, state, :palette))
    end

    @testset "tabbed content keyboard and pointer selection" begin
        content = TabbedContent([
            ContentPage(:one, "One", Label("one")),
            ContentPage(:two, "Two", Label("two")),
        ])
        widget = TabbedContentView()

        @test active_content_key(content.switcher) == :one
        @test handle!(content, widget, KeyEvent(Key(:right)))
        @test active_content_key(content.switcher) == :two
        @test content.focused == :two

        @test handle!(content, widget, KeyEvent(Key(:home)))
        @test active_content_key(content.switcher) == :one
        area = Rect(1, 1, 3, 20)
        @test handle!(
            content,
            widget,
            MouseEvent(Position(1, 7), LeftMouseButton, MouseRelease),
            area,
        )
        @test active_content_key(content.switcher) == :two
    end

    @testset "log keyboard scrolling" begin
        state = LogState(3)
        push_log!(state, "one")
        push_log!(state, "two")
        widget = LogView()

        @test length(state.entries) == 2
        @test handle!(state, widget, KeyEvent(Key(:up)))
        @test state.offset == 1
        @test handle!(state, widget, KeyEvent(Key(:end)))
        @test state.offset == 0

        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, state)
        children = Wicked.SemanticToolkit.widget_semantic_children(widget, state, :log)
        @test descriptor.role == Wicked.Accessibility.LogRole
        @test descriptor.state.focusable
        @test descriptor.metadata[:entry_count] == 2
        @test descriptor.metadata[:offset] == 0
        @test length(children) == 2
        @test children[1].role == Wicked.Accessibility.ListItemRole
        @test children[1].description == "one"
        @test children[2].metadata[:level] == :info
        @test Wicked.Toolkit.state_for(widget) isa LogState
    end

    @testset "scroll state clamping and preservation" begin
        view = ScrollView(Label("abcdefgh"); height=2, width=8)
        view_state = ScrollState(row=99, column=99)
        view_buffer = Buffer(2, 4)
        @test render!(view_buffer, view, view_buffer.area, view_state) === view_buffer
        @test view_state.row == 0
        @test view_state.column == 4

        scrollbar = Scrollbar(VerticalScrollbar, 20, 4)
        scrollbar_state = ScrollState(row=7, column=3)
        scrollbar_buffer = Buffer(4, 1)
        @test render!(
            scrollbar_buffer,
            scrollbar,
            scrollbar_buffer.area,
            scrollbar_state,
        ) === scrollbar_buffer
        @test scrollbar_state.row == 7
        @test scrollbar_state.column == 3
    end

    @testset "scroll keyboard and pointer input" begin
        view = ScrollView(Label("abcdefgh"); height=20, width=20)
        view_state = ScrollState()
        @test handle!(view_state, view, KeyEvent(Key(:down)))
        @test handle!(view_state, view, KeyEvent(Key(:right)))
        @test (view_state.row, view_state.column) == (1, 1)
        @test handle!(view_state, view, KeyEvent(Key(:page_down)); page_step=5)
        @test view_state.row == 6
        @test handle!(
            view_state,
            view,
            MouseEvent(Position(1, 1), WheelDownButton, MouseScroll),
            Rect(1, 1, 4, 8),
        )
        @test view_state.row == 9
        @test handle!(view_state, view, KeyEvent(Key(:home)))
        @test (view_state.row, view_state.column) == (0, 0)

        vertical = Scrollbar(VerticalScrollbar, 20, 4)
        vertical_state = ScrollState()
        @test handle!(vertical_state, vertical, KeyEvent(Key(:down)))
        @test vertical_state.row == 1
        @test handle!(
            vertical_state,
            vertical,
            MouseEvent(Position(4, 1), LeftMouseButton, MouseRelease),
            Rect(1, 1, 4, 1),
        )
        @test vertical_state.row == 16
        @test handle!(
            vertical_state,
            vertical,
            MouseEvent(Position(2, 1), WheelUpButton, MouseScroll),
            Rect(1, 1, 4, 1),
        )
        @test vertical_state.row == 13

        horizontal = Scrollbar(HorizontalScrollbar, 12, 4)
        horizontal_state = ScrollState()
        @test handle!(horizontal_state, horizontal, KeyEvent(Key(:right)))
        @test horizontal_state.column == 1
        @test handle!(horizontal_state, horizontal, KeyEvent(Key(:end)))
        @test horizontal_state.column == 8
    end

    @testset "palette and log pointer input" begin
        palette = CommandPalette([
            CommandItem(:open, "Open", :opened),
            CommandItem(:quit, "Quit", :quit),
        ])
        palette_state = CommandPaletteState(open=true)
        palette_area = Rect(1, 1, 8, 30)
        palette_buffer = Buffer(8, 30)
        render!(palette_buffer, palette, palette_area, palette_state)

        @test handle!(
            palette_state,
            palette,
            MouseEvent(Position(4, 4), LeftMouseButton, MouseRelease),
            palette_area,
        )
        @test palette_state.selected == 2
        @test activate(palette, palette_state) == :quit
        @test handle!(
            palette_state,
            palette,
            MouseEvent(Position(2, 5), LeftMouseButton, MousePress),
            palette_area,
        )
        @test palette_state.query.focused

        log_state = LogState(10)
        foreach(message -> push_log!(log_state, message), ["one", "two", "three", "four", "five", "six"])
        log = LogView()
        log_area = Rect(1, 1, 3, 20)
        @test handle!(
            log_state,
            log,
            MouseEvent(Position(2, 2), WheelUpButton, MouseScroll),
            log_area,
        )
        @test log_state.offset == 3
        @test handle!(
            log_state,
            log,
            MouseEvent(Position(2, 2), WheelDownButton, MouseScroll),
            log_area,
        )
        @test log_state.offset == 0
        @test !handle!(
            log_state,
            log,
            MouseEvent(Position(4, 2), WheelUpButton, MouseScroll),
            log_area,
        )
    end

    @testset "stepper keyboard and pointer interactions" begin
        widget = Stepper()
        state = StepperState(["Prepare", "Build", "Release"])
        area = Rect(1, 1, 1, 60)
        buffer = Buffer(1, area.width)

        @test state.current == 1
        @test state.statuses == [ActiveStep, PendingStep, PendingStep]
        @test handle!(state, widget, KeyEvent(Key(:space)))
        @test state.current == 2
        @test state.statuses == [CompletedStep, ActiveStep, PendingStep]
        @test render!(buffer, widget, area, state) === buffer

        @test handle!(state, widget, KeyEvent(Key(:right)))
        @test state.current == 3
        @test state.statuses == [CompletedStep, CompletedStep, ActiveStep]
        @test handle!(state, widget, KeyEvent(Key(:left)))
        @test state.current == 2
        @test state.statuses == [CompletedStep, ActiveStep, PendingStep]

        @test handle!(state, widget, KeyEvent(Key(:s)))
        @test state.current == 3
        @test state.statuses == [CompletedStep, SkippedStep, ActiveStep]

        # clicking any position in the first segment activates step 1
        @test handle!(
            state,
            widget,
            MouseEvent(Position(1, 2), LeftMouseButton, MousePress),
            area,
        )
        @test state.current == 1
        @test activate(widget, state) == 1
        @test handle!(state, widget, KeyEvent(Key(:f)))
        @test state.statuses == [FailedStep, SkippedStep, PendingStep]

        @test handle!(state, widget, KeyEvent(Key(:end)))
        @test state.current == 3
        @test state.statuses == [FailedStep, SkippedStep, ActiveStep]
        @test handle!(state, widget, KeyEvent(Key(:home)))
        @test state.current == 1
        @test state.statuses == [ActiveStep, SkippedStep, PendingStep]

        @test Wicked.Toolkit.state_for(Stepper()) isa StepperState
        @test isempty(Wicked.Toolkit.state_for(Stepper()).steps)
    end

    @testset "advanced range control keyboard bindings" begin
        bindings = default_advanced_control_bindings()
        slider = SliderState(0, 100; step=5)
        @test slider.value == 0

        result = handle_advanced_control_key!(slider, bindings, :right)
        @test result.consumed
        @test result.value == 5
        @test slider.value == 5

        result = handle_advanced_control_key!(slider, bindings, :left)
        @test result.consumed
        @test result.value == 0
        @test slider.value == 0

        result = handle_advanced_control_key!(slider, bindings, :page_down)
        @test result.consumed
        @test slider.value == 10

        result = handle_advanced_control_key!(slider, bindings, :page_up)
        @test result.consumed
        @test slider.value == 0

        result = handle_advanced_control_key!(slider, bindings, :home)
        @test result.consumed
        @test slider.value == 0

        result = handle_advanced_control_key!(slider, bindings, :end)
        @test result.consumed
        @test slider.value == 100

        range_state = RangeSliderState(0, 100; lower=20, upper=80, step=10)
        result = handle_advanced_control_key!(range_state, bindings, :right)
        @test result.consumed
        @test range_state.lower == 30
        @test range_state.active == LowerRangeHandle

        result = handle_advanced_control_key!(range_state, bindings, :tab)
        @test result.consumed
        @test range_state.active == UpperRangeHandle

        result = handle_advanced_control_key!(range_state, bindings, :left)
        @test result.consumed
        @test range_state.upper == 70

        result = handle_advanced_control_key!(range_state, bindings, :page_down)
        @test result.consumed
        @test range_state.upper == 80

        result = handle_advanced_control_key!(range_state, bindings, :tab)
        @test result.consumed
        @test range_state.active == LowerRangeHandle

        result = handle_advanced_control_key!(slider, bindings, :escape)
        @test !result.consumed

        result = handle_advanced_control_key!(slider, bindings, :x)
        @test !result.consumed
    end
end

@testset "Command palette toolkit semantic integration" begin
    widget = CommandPalette([
        CommandItem(:open, "Open project", :opened; description="Open a project"),
        CommandItem(:quit, "Quit", :quit),
    ])
    state = CommandPaletteState(open=true)
    @test handle!(state, widget, PasteEvent("open"))

    tree = ToolkitTree(
        Element(
            widget;
            id=:command_palette,
            key=:command_palette,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(6, 32)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "command_palette")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == DialogRole
    @test node.metadata[:query] == "open"
    @test length(node.children) == 2
    @test node.children[1].role == SearchboxRole
    @test node.children[2].role == ListItemRole
    @test node.children[2].metadata[:command_id] == :open
    @test node.children[2].state.selected
end

@testset "Markdown toolkit semantic integration" begin
    widget = MarkdownView("[Documentation](https://example.test)"; width=32)
    state = MarkdownState(widget; viewport_height=3)
    focus_next_link!(widget)

    tree = ToolkitTree(
        Element(
            widget;
            id=:markdown,
            key=:markdown,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(4, 32)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "markdown")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == GroupRole
    @test node.state.focused
    @test node.metadata[:link_count] == 1
    @test length(node.children) == 1
    @test node.children[1].role == LinkRole
    @test !node.children[1].state.focused
    @test node.children[1].metadata[:target] == "https://example.test"
end

@testset "Text input toolkit semantic integration" begin
    widget = TextInput(placeholder="Project name")
    state = TextInputState("Wicked"; focused=true)
    tree = ToolkitTree(
        Element(
            widget;
            id=:project_name,
            key=:project_name,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "project_name")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == TextboxRole
    @test node.label == "Project name"
    @test node.state.focused
    @test node.state.value == "Wicked"
    @test !node.metadata[:protected]
    @test SetValueSemanticAction in node.actions
end

@testset "Text area toolkit semantic integration" begin
    widget = TextArea()
    state = TextAreaState("first\nsecond"; focused=true)
    tree = ToolkitTree(
        Element(
            widget;
            id=:notes,
            key=:notes,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "notes")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == TextboxRole
    @test node.label == "Text area"
    @test node.state.focused
    @test node.state.value == "first\nsecond"
    @test node.metadata[:multiline]
    @test SetValueSemanticAction in node.actions

    pointer_state = TextAreaState("first\nsecond")
    @test handle!(
        pointer_state,
        widget,
        MouseEvent(Position(2, 2), LeftMouseButton, MousePress),
        Rect(1, 1, 3, 24),
    )
    @test pointer_state.focused
end

@testset "Select toolkit semantic integration" begin
    widget = Select([
        ChoiceOption(:alpha, "Alpha"),
        ChoiceOption(:beta, "Beta"; disabled=true),
        ChoiceOption(:gamma, "Gamma"),
    ]; placeholder="Choose environment")
    state = SelectState()
    @test handle!(state, widget, KeyEvent(Key(:enter)))
    @test handle!(state, widget, KeyEvent(Key(:enter)))

    tree = ToolkitTree(
        Element(
            widget;
            id=:environment,
            key=:environment,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(4, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "environment")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == ListRole
    @test node.label == "Choose environment"
    @test node.state.focused
    @test node.state.value == "Alpha"
    @test !node.state.expanded
    @test length(node.children) == 3
    @test node.children[1].state.selected
    @test !node.children[2].state.enabled
    @test SelectSemanticAction in node.children[1].actions
end

@testset "Multi-select toolkit semantic integration" begin
    widget = MultiSelect([
        ChoiceOption(:alpha, "Alpha"),
        ChoiceOption(:beta, "Beta"; disabled=true),
        ChoiceOption(:gamma, "Gamma"),
    ])
    state = MultiSelectState(selected=[1, 3])
    tree = ToolkitTree(
        Element(
            widget;
            id=:features,
            key=:features,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "features")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == ListRole
    @test node.state.focused
    @test length(node.children) == 3
    @test node.children[1].role == CheckboxRole
    @test node.children[1].state.checked == CheckedValue
    @test node.children[2].state.checked == UncheckedState
    @test !node.children[2].state.enabled
    @test node.children[3].state.checked == CheckedValue
    @test SelectSemanticAction in node.children[3].actions
end

@testset "Radio group toolkit semantic integration" begin
    widget = RadioGroup([
        ChoiceOption(:alpha, "Alpha"),
        ChoiceOption(:beta, "Beta"; disabled=true),
        ChoiceOption(:gamma, "Gamma"),
    ])
    state = RadioGroupState(selected=3)
    tree = ToolkitTree(
        Element(
            widget;
            id=:mode,
            key=:mode,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "mode")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == GroupRole
    @test node.state.focused
    @test length(node.children) == 3
    @test node.children[1].role == RadioRole
    @test !node.children[2].state.enabled
    @test node.children[3].state.checked == CheckedValue
    @test node.children[3].state.selected
    @test SelectSemanticAction in node.children[3].actions
end

@testset "Tabs toolkit semantic integration" begin
    widget = Tabs([Tab(:build, "Build"), Tab(:test, "Test"), Tab(:release, "Release")])
    state = TabsState(2)
    tree = ToolkitTree(
        Element(
            widget;
            id=:workflow_tabs,
            key=:workflow_tabs,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 32)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "workflow_tabs")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == TabListRole
    @test node.state.focused
    @test length(node.children) == 3
    @test node.children[2].role == TabRole
    @test node.children[2].state.selected
    @test node.children[2].metadata[:tab_id] == :test
    @test SelectSemanticAction in node.children[2].actions
end

@testset "Table toolkit semantic integration" begin
    widget = Table(
        [TableColumn("Name"; constraint=Length(8)), TableColumn("Status"; constraint=Fill())],
        [["Wicked", "Ready"], ["Docs", "Pending"]],
    )
    state = TableState()
    @test handle!(state, widget, KeyEvent(Key(:down)); viewport_height=2)
    @test handle!(state, widget, KeyEvent(Key(:right)))

    tree = ToolkitTree(
        Element(
            widget;
            id=:tasks,
            key=:tasks,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(4, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "tasks")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == TableRole
    @test node.state.focused
    @test length(node.children) == 2
    @test node.children[1].role == RowRole
    @test node.children[1].state.selected
    @test node.children[1].children[1].role == CellRole
    @test node.children[1].children[1].state.selected
    @test node.children[1].children[1].label == "Wicked"
end

@testset "Tree toolkit semantic integration" begin
    widget = Tree([
        TreeNode(:root, "Root"; children=[TreeNode(:child, "Child")]),
    ])
    state = TreeState(selected=:root, expanded=Set([:root]))
    tree = ToolkitTree(
        Element(
            widget;
            id=:project_tree,
            key=:project_tree,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "project_tree")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == TreeRole
    @test node.state.focused
    @test length(node.children) == 1
    @test node.children[1].role == TreeItemRole
    @test node.children[1].state.selected
    @test node.children[1].state.expanded
    @test ExpandSemanticAction in node.children[1].actions || CollapseSemanticAction in node.children[1].actions
    @test node.children[1].children[1].metadata[:item_id] == :child
end

@testset "List toolkit semantic integration" begin
    widget = List(["Build", "Test", "Release"])
    state = ListState(selected=2)
    tree = ToolkitTree(
        Element(
            widget;
            id=:pipeline_steps,
            key=:pipeline_steps,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "pipeline_steps")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == ListRole
    @test node.state.focused
    @test length(node.children) == 3
    @test node.children[2].role == ListItemRole
    @test node.children[2].state.selected
    @test node.children[2].label == "Test"
    @test SelectSemanticAction in node.children[2].actions
end

@testset "Scroll view toolkit semantic integration" begin
    widget = ScrollView(
        Column(Label("one"), Label("two"), Label("three"), Label("four"));
        height=4,
        width=12,
    )
    state = ScrollState(row=1)
    tree = ToolkitTree(
        Element(
            widget;
            id=:output,
            key=:output,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(2, 12)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "output")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == ScrollbarRole
    @test node.state.focused
    @test node.state.value_now == 1.0
    @test node.state.value_min == 0.0
    @test node.state.value_max >= 1.0
    @test IncrementSemanticAction in node.actions
    @test ScrollIntoViewSemanticAction in node.actions
end

@testset "Scrollbar toolkit semantic integration" begin
    widget = Scrollbar(VerticalScrollbar, 20, 4)
    state = ScrollState(row=5)
    tree = ToolkitTree(
        Element(
            widget;
            id=:scrollbar,
            key=:scrollbar,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(4, 1)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "scrollbar")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == ScrollbarRole
    @test node.label == "Vertical scrollbar"
    @test node.state.focused
    @test node.state.value_now == 5.0
    @test node.state.value_max == 16.0
    @test node.metadata[:orientation] == :vertical
    @test IncrementSemanticAction in node.actions
end

@testset "Gauge toolkit semantic integration" begin
    gauge = Gauge(0.75; label="Upload")
    line = LineGauge(0.25)
    tree = ToolkitTree(column(
        Element(gauge; id=:gauge, key=:gauge),
        Element(line; id=:line_gauge, key=:line_gauge),
    ))
    render_toolkit!(Frame(Buffer(2, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    gauge_node = semantic_node(semantics, "gauge")
    line_node = semantic_node(semantics, "line_gauge")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test gauge_node.role == ProgressRole
    @test gauge_node.label == "Upload"
    @test gauge_node.state.value_now == 0.75
    @test gauge_node.state.value_min == 0.0
    @test gauge_node.state.value_max == 1.0
    @test line_node.role == ProgressRole
    @test line_node.state.value == "25%"
    @test line_node.state.value_now == 0.25
end

@testset "Spinner toolkit semantic integration" begin
    widget = Spinner(frames=["a", "b"]; label="Indexing")
    state = SpinnerState(2)
    tree = ToolkitTree(
        Element(
            widget;
            id=:spinner,
            key=:spinner,
            state_factory=() -> state,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 16)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "spinner")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == ProgressRole
    @test node.label == "Indexing"
    @test node.state.busy
    @test node.metadata[:frame] == 2
    @test node.metadata[:frame_count] == 2
end

@testset "Toggle toolkit semantic integration" begin
    widget = Toggle(on_label="Enabled", off_label="Disabled")
    state = ToggleState(true)
    tree = ToolkitTree(
        Element(
            widget;
            id=:feature_flag,
            key=:feature_flag,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 16)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "feature_flag")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == CheckboxRole
    @test node.label == "Enabled"
    @test node.state.focused
    @test node.state.checked == CheckedValue
    @test ActivateSemanticAction in node.actions
end

@testset "Visualization toolkit semantic integration" begin
    sparkline = Sparkline([1, 2, 3])
    bars = BarChart(["Build" => 3.0, "Test" => 2.0])
    canvas = Canvas(context -> canvas_point!(context, 0.5, 0.5))
    chart = Chart([ChartDataset([(0.0, 0.0), (1.0, 1.0)])])
    histogram = Histogram([1.0, 2.0, 3.0]; bins=2)
    heatmap = Heatmap([1.0 2.0; 3.0 4.0])
    widgets = (
        (:sparkline, sparkline),
        (:bars, bars),
        (:canvas, canvas),
        (:chart, chart),
        (:histogram, histogram),
        (:heatmap, heatmap),
    )
    tree = ToolkitTree(column((Element(widget; id=id, key=id) for (id, widget) in widgets)...))
    render_toolkit!(Frame(Buffer(12, 32)), tree)
    semantics = toolkit_semantic_tree(tree)

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test semantic_node(semantics, "sparkline").metadata[:sample_count] == 3
    @test semantic_node(semantics, "bars").metadata[:bar_count] == 2
    @test semantic_node(semantics, "canvas").metadata[:x_bounds] == (0.0, 1.0)
    @test semantic_node(semantics, "chart").metadata[:dataset_count] == 1
    @test semantic_node(semantics, "histogram").metadata[:bins] == 2
    @test semantic_node(semantics, "heatmap").metadata[:rows] == 2
    @test all(semantic_node(semantics, string(id)).role == ImageRole for (id, _) in widgets)
end

@testset "Calendar toolkit semantic integration" begin
    widget = Calendar(2026, 7; selected=Dates.Date(2026, 7, 11), marked=[Dates.Date(2026, 7, 4)])
    tree = ToolkitTree(Element(widget; id=:calendar, key=:calendar))
    render_toolkit!(Frame(Buffer(8, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "calendar")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == GroupRole
    @test node.label == "Calendar 2026-07"
    @test node.metadata[:selected] == Dates.Date(2026, 7, 11)
    @test node.metadata[:marked_count] == 1
end

@testset "Text widget toolkit semantic integration" begin
    label = Label("Build succeeded")
    paragraph = Paragraph("The release artifact is ready.\nPublish after review.")
    tree = ToolkitTree(
        column(
            Element(label; id=:build_status, key=:build_status),
            Element(paragraph; id=:release_notes, key=:release_notes),
        ),
    )
    render_toolkit!(Frame(Buffer(4, 40)), tree)
    semantics = toolkit_semantic_tree(tree)
    label_node = semantic_node(semantics, "build_status")
    paragraph_node = semantic_node(semantics, "release_notes")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test label_node.role == ParagraphRole
    @test label_node.label == "Build succeeded"
    @test label_node.state.readonly
    @test label_node.metadata[:line_count] == 1
    @test paragraph_node.role == ParagraphRole
    @test paragraph_node.label == "The release artifact is ready.\nPublish after review."
    @test paragraph_node.state.value == paragraph_node.label
    @test paragraph_node.metadata[:line_count] == 2
    @test paragraph_node.metadata[:wrap] == WordWrap
end

@testset "Structural widget toolkit semantic integration" begin
    widgets = (
        (:block, Block(title="Panel")),
        (:clear, Clear()),
        (:spacer, Spacer()),
        (:rule, Rule()),
        (:padding, Padding(Label("padded"))),
        (:box, Box(Label("boxed"); block=Block(title="Boxed"))),
        (:row, Row(Label("left"), Label("right"))),
        (:column, Column(Label("top"), Label("bottom"))),
        (:stack, Stack(Label("base"), Label("overlay"))),
        (:center, Center(Label("center"); height=1, width=12)),
        (:grid, Grid(Label("grid"); rows=[Fill(1)], columns=[Fill(1)])),
    )
    tree = ToolkitTree(column((Element(widget; id=id, key=id) for (id, widget) in widgets)...))
    render_toolkit!(Frame(Buffer(16, 40)), tree)
    semantics = toolkit_semantic_tree(tree)

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test semantic_node(semantics, "block").label == "Panel"
    @test semantic_node(semantics, "block").metadata[:borders] == AllBorders.bits
    @test semantic_node(semantics, "clear").role == GenericRole
    @test semantic_node(semantics, "spacer").label == "Spacer"
    @test semantic_node(semantics, "rule").metadata[:direction] == :horizontal
    @test semantic_node(semantics, "padding").metadata[:margin] == (1, 1, 1, 1)
    @test semantic_node(semantics, "box").label == "Boxed"
    @test semantic_node(semantics, "row").metadata[:orientation] == :horizontal
    @test semantic_node(semantics, "column").metadata[:orientation] == :vertical
    @test semantic_node(semantics, "stack").metadata[:layered]
    @test semantic_node(semantics, "center").metadata[:width] == 12
    @test semantic_node(semantics, "grid").metadata[:rows] == 1
    @test semantic_node(semantics, "grid").metadata[:columns] == 1
    @test all(semantic_node(semantics, string(id)).role == (id in (:clear, :spacer, :rule) ? GenericRole : GroupRole) for (id, _) in widgets)
end

@testset "Menu toolkit semantic integration" begin
    widget = Menu(
        [
            MenuItem(:open, "Open", :open_document; shortcut="Ctrl+O"),
            MenuItem(:save, "Save", :save_document; disabled=true),
            MenuItem(:quit, "Quit", :quit_application; shortcut="Ctrl+Q"),
        ];
        block=Block(title="Actions"),
    )
    state = MenuState(selected=3)
    tree = ToolkitTree(
        Element(widget; id=:actions, key=:actions, state_factory=() -> state, focusable=true),
    )
    render_toolkit!(Frame(Buffer(5, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    menu = semantic_node(semantics, "actions")
    open = semantic_node(semantics, "actions/item-1")
    save = semantic_node(semantics, "actions/item-2")
    quit = semantic_node(semantics, "actions/item-3")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test menu.role == MenuRole
    @test menu.label == "Actions"
    @test menu.state.value == "Quit"
    @test menu.metadata[:item_count] == 3
    @test menu.metadata[:selected_id] == :quit
    @test FocusSemanticAction in menu.actions
    @test open.role == MenuItemRole
    @test open.metadata[:shortcut] == "Ctrl+O"
    @test open.metadata[:message] == :open_document
    @test !save.state.enabled
    @test isempty(save.actions)
    @test quit.state.selected
    @test ActivateSemanticAction in quit.actions
end

@testset "Markdown view complete contract" begin
    source = join(
        [
            "[Documentation](https://example.test)",
            "This paragraph verifies constrained rendering and reflow.",
            "Scroll through this content with the keyboard.",
            "The final paragraph keeps the viewport scrollable.",
        ],
        "\n\n",
    )
    widget = MarkdownView(source; width=20)
    state = MarkdownState(widget; viewport_height=3)

    zero = Buffer(0, 0)
    @test render!(zero, widget, zero.area, state) === zero

    minimal = Buffer(1, 1)
    @test render!(minimal, widget, minimal.area, state) === minimal

    clipped = Buffer(3, 12)
    clipped_area = Rect(1, 3, 2, 6)
    @test render!(clipped, widget, clipped_area, state) === clipped

    resized = Buffer(4, 30)
    @test render!(resized, widget, resized.area, state) === resized
    @test widget.width == 30

    backend = TestBackend(4, 30)
    terminal = Terminal(backend)
    draw!(terminal) do frame
        render!(frame, widget, frame.area, state)
    end
    @test occursin("Documentation", plain_snapshot(backend.screen))

    @test handle!(
        state,
        widget,
        MouseEvent(Position(1, 1), LeftMouseButton, MousePress),
        Rect(1, 1, 4, 30),
    )
    initial_scroll = widget.scroll
    @test handle!(state, widget, KeyEvent(Key(:down)))
    @test widget.scroll >= initial_scroll

    tree = ToolkitTree(
        Element(widget; id=:documentation, key=:documentation, state_factory=() -> state),
    )
    render_toolkit!(Frame(Buffer(4, 30)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "documentation")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == GroupRole
    @test node.metadata[:line_count] == markdown_line_count(widget)
    @test node.metadata[:link_count] == 1
    @test length(node.children) == 1
    @test only(node.children).role == LinkRole
    @test only(node.children).state.enabled
end

@testset "Tabbed content semantic integration" begin
    content = TabbedContent([
        ContentPage(:overview, "Overview", Label("overview")),
        ContentPage(:details, "Details", Label("details")),
        ContentPage(:locked, "Locked", Label("locked"); disabled=true),
    ])
    view = TabbedContentView()
    @test handle!(content, view, KeyEvent(Key(:right)))
    semantics = tabbed_content_semantic_tree(content; id=:workspace, label="Workspace")
    root = semantic_node(semantics, "workspace")
    details = semantic_node(semantics, "workspace/tab/2")
    locked = semantic_node(semantics, "workspace/tab/3")
    panel = semantic_node(semantics, "workspace/panel")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test root.role == GroupRole
    @test root.metadata[:placement] == TabsAbove
    @test semantic_node(semantics, "workspace/list").role == TabListRole
    @test details.role == TabRole
    @test details.state.focused
    @test details.state.selected
    @test SelectSemanticAction in details.actions
    @test !locked.state.enabled
    @test isempty(locked.actions)
    @test panel.label == "Details"
    @test panel.metadata[:key] == :details
end

@testset "Toolkit tree root contract" begin
    tree = ToolkitTree(Element(Button("Run", :run); id=:run, key=:run, focusable=true))
    zero = Frame(Buffer(0, 0))
    @test render_toolkit!(zero, tree) === zero.buffer
    minimal = Frame(Buffer(1, 1))
    @test render!(minimal, tree, minimal.area) === minimal.buffer
    frame = Frame(Buffer(2, 12))
    @test render_toolkit!(frame, tree) === frame.buffer
    @test startswith(plain_snapshot(frame.buffer), "╭")
    clipped = Frame(Buffer(2, 5))
    @test render_toolkit!(clipped, tree, Rect(1, 2, 1, 3)) === clipped.buffer
    resized = Frame(Buffer(3, 20))
    @test render_toolkit!(resized, tree) === resized.buffer
    @test dispatch!(tree, KeyEvent(Key(:enter))).consumed
    @test dispatch!(tree, MouseEvent(Position(1, 1), LeftMouseButton, MousePress)).consumed
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "run")
    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == ButtonRole
    @test node.state.focused
end
