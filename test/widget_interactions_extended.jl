using Dates

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
        spinner_buffer = Buffer(1, 4)
        @test render!(spinner_buffer, spinner, spinner_buffer.area) === spinner_buffer
        @test occursin("a", plain_snapshot(spinner_buffer))

        skeleton = Skeleton()
        skeleton_state = SkeletonState(period=4)
        @test handle!(skeleton_state, skeleton, TickEvent(UInt64(4), UInt64(1)))
        @test skeleton_state.phase == 1
        skeleton_node = widget_semantic_descriptor(skeleton, skeleton_state)
        @test skeleton_node.state.busy
        @test skeleton_node.metadata[:period] == 4
    end

    @testset "calendar keyboard, pointer, and toolkit state" begin
        widget = Calendar(2026, 7; marked=[Date(2026, 7, 15)])
        state = CalendarState(widget)

        @test state.selected == Date(2026, 7, 1)
        @test handle!(state, widget, KeyEvent(Key(:right)))
        @test state.selected == Date(2026, 7, 2)
        @test handle!(state, widget, KeyEvent(Key(:down)))
        @test state.selected == Date(2026, 7, 9)
        @test handle!(state, widget, KeyEvent(Key(:pageup)))
        @test state.selected == Date(2026, 6, 9)
        @test state.visible_month == 6
        @test handle!(state, widget, KeyEvent(Key(:pagedown)))
        @test state.selected == Date(2026, 7, 9)
        @test handle!(state, widget, KeyEvent(Key(:end)))
        @test state.selected == Date(2026, 7, 31)
        @test handle!(state, widget, KeyEvent(Key(:enter)))
        @test activate(widget, state) == Date(2026, 7, 31)

        area = Rect(1, 1, 8, 24)
        state = CalendarState(widget)
        @test handle!(state, widget, MouseEvent(Position(5, 7), LeftMouseButton, MouseRelease), area)
        @test state.selected == Date(2026, 7, 15)
        @test activate(widget, state) == Date(2026, 7, 15)

        buffer = Buffer(8, 24)
        @test render!(buffer, widget, buffer.area, state) === buffer
        @test occursin("July 2026", plain_snapshot(buffer))
        @test Wicked.Toolkit.state_for(widget) isa CalendarState
        @test state_for(widget) isa CalendarState
        default_buffer = Buffer(8, 24)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("July 2026", plain_snapshot(default_buffer))

        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, state)
        children = Wicked.SemanticToolkit.widget_semantic_children(widget, state, :calendar)
        @test descriptor.role == Wicked.Accessibility.TableRole
        @test descriptor.label == "July 2026"
        @test descriptor.state.focusable
        @test descriptor.state.value == "2026-07-15"
        @test descriptor.metadata[:selected] == Date(2026, 7, 15)
        @test descriptor.metadata[:marked_count] == 1
        @test Wicked.Accessibility.ActivateSemanticAction in descriptor.actions
        @test length(children) == 5
        @test children[3].role == Wicked.Accessibility.RowRole
        @test children[3].children[3].role == Wicked.Accessibility.CellRole
        @test children[3].children[3].metadata[:date] == Date(2026, 7, 15)
        @test children[3].children[3].metadata[:marked]
        @test children[3].children[3].state.selected

        dispatcher = SemanticDispatcher()
        register_calendar_semantic_handlers!(dispatcher, :calendar, widget, state)
        pilot = SemanticPilot(
            SemanticTree(SemanticNode("application", ApplicationRole; children=[
                SemanticNode(
                    "calendar",
                    descriptor.role;
                    label=descriptor.label,
                    state=descriptor.state,
                    actions=descriptor.actions,
                    children=children,
                    metadata=descriptor.metadata,
                ),
            ]));
            dispatcher,
        )
        select_result = perform_semantic_action!(
            pilot,
            "calendar/week-2/day-8",
            SelectSemanticAction,
        )
        @test select_result.handled
        @test select_result.value == Date(2026, 7, 8)
        @test state.selected == Date(2026, 7, 8)
        activate_result = perform_semantic_action!(
            pilot,
            "calendar/week-3/day-15",
            ActivateSemanticAction,
        )
        @test activate_result.handled
        @test activate_result.value == Date(2026, 7, 15)
        @test activate(widget, state) == Date(2026, 7, 15)
        increment_result = perform_semantic_action!(pilot, "calendar", IncrementSemanticAction)
        @test increment_result.handled
        @test state.selected == Date(2026, 7, 16)
    end

    @testset "command palette filtering and activation" begin
        widget = CommandPalette([
            CommandItem(:open, "Open", :opened),
            CommandItem(:quit, "Quit", :quit),
        ])
        state = CommandPaletteState(open=true)

        fresh = CommandPaletteState(open=true)
        @test handle!(fresh, widget, KeyEvent(Key(:down)))
        @test command_palette_selected_command(widget, fresh).id == :open
        fresh_previous = CommandPaletteState(open=true)
        @test handle!(fresh_previous, widget, KeyEvent(Key(:up)))
        @test command_palette_selected_command(widget, fresh_previous).id == :quit
        @test handle!(state, widget, PasteEvent("op"))
        @test command_palette_query(state) == "op"
        @test state.filtered == [1]
        @test state.selected == 1
        @test only(command_palette_filtered_commands(widget, state)).id == :open
        @test command_palette_selected_command(widget, state).id == :open
        @test activate(widget, state) == :opened
        @test set_command_palette_query!(state, widget, "qui"; record=false) === state
        @test command_palette_query(state) == "qui"
        @test only(command_palette_filtered_commands(widget, state)).id == :quit
        @test select_next_command!(state, widget) === state
        @test command_palette_selected_command(widget, state).id == :quit
        @test select_previous_command!(state, widget) === state
        @test select_command!(state, widget, 99) === state
        @test command_palette_selected_command(widget, state).id == :quit
        @test activate(widget, state) == :quit

        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, state)
        children = Wicked.SemanticToolkit.widget_semantic_children(widget, state, :palette)
        @test descriptor.role == Wicked.Accessibility.DialogRole
        @test descriptor.state.focused
        @test descriptor.metadata[:query] == "qui"
        @test descriptor.metadata[:result_count] == 1
        @test descriptor.metadata[:selected_command_id] == :quit
        @test descriptor.metadata[:selected_action] == :quit
        @test length(children) == 2
        @test children[1].role == Wicked.Accessibility.SearchboxRole
        @test children[1].state.value == "qui"
        @test children[2].role == Wicked.Accessibility.ListItemRole
        @test children[2].state.selected
        @test children[2].metadata[:command_id] == :quit
        dispatcher = SemanticDispatcher()
        register_command_palette_semantic_handlers!(dispatcher, :palette, widget, state)
        palette_pilot = SemanticPilot(
            SemanticTree(SemanticNode("application", ApplicationRole; children=[
                SemanticNode(
                    "palette",
                    descriptor.role;
                    label=descriptor.label,
                    state=descriptor.state,
                    actions=descriptor.actions,
                    children=children,
                    metadata=descriptor.metadata,
                ),
            ]));
            dispatcher,
        )
        focus_result = perform_semantic_action!(palette_pilot, "palette/command/quit", FocusSemanticAction)
        @test focus_result.handled
        @test focus_result.value == :quit
        @test command_palette_selected_command(widget, state).id == :quit
        activate_result = perform_semantic_action!(palette_pilot, "palette/command/quit", ActivateSemanticAction)
        @test activate_result.handled
        @test activate_result.value == :quit
        dismiss_result = perform_semantic_action!(palette_pilot, "palette", DismissSemanticAction)
        @test dismiss_result.handled
        @test !state.open
        open_palette!(state)
        set_command_palette_query!(state, widget, "op"; record=false)
        stale_result = perform_semantic_action!(palette_pilot, "palette/command/quit", ActivateSemanticAction)
        @test !stale_result.handled
        @test occursin("not visible", stale_result.message)
        @test Wicked.Toolkit.state_for(widget) isa CommandPaletteState
        palette_buffer = Buffer(6, 24)
        @test render!(palette_buffer, widget, palette_buffer.area) === palette_buffer

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
        log_buffer = Buffer(2, 20)
        @test render!(log_buffer, widget, log_buffer.area) === log_buffer
    end

    @testset "scroll state clamping and preservation" begin
        view = ScrollView(Label("abcdefgh"); height=2, width=8)
        view_state = ScrollState(row=99, column=99)
        view_buffer = Buffer(2, 4)
        @test render!(view_buffer, view, view_buffer.area, view_state) === view_buffer
        @test view_state.row == 0
        @test view_state.column == 4
        default_view_buffer = Buffer(2, 4)
        @test render!(default_view_buffer, view, default_view_buffer.area) === default_view_buffer
        @test occursin("abcd", plain_snapshot(default_view_buffer))

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
        default_scrollbar_buffer = Buffer(4, 1)
        @test render!(default_scrollbar_buffer, scrollbar, default_scrollbar_buffer.area) === default_scrollbar_buffer
        @test !isempty(strip(plain_snapshot(default_scrollbar_buffer)))
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
    @test !node.state.focused
    @test node.metadata[:link_count] == 1
    @test length(node.children) == 1
    @test node.children[1].role == LinkRole
    @test node.children[1].state.focused
    @test node.children[1].metadata[:target] == "https://example.test"
    dispatcher = SemanticDispatcher()
    register_markdown_view_semantic_handlers!(dispatcher, :markdown, state)
    pilot = SemanticPilot(semantics; dispatcher)
    focus_result = perform_semantic_action!(pilot, "markdown", FocusSemanticAction)
    @test focus_result.handled
    activate_result = perform_semantic_action!(pilot, node.children[1].id, ActivateSemanticAction)
    @test activate_result.handled
    @test activate_result.value == "https://example.test"
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

    input = Input(placeholder="Project name")
    input_state = InputState("Wicked"; focused=true)
    input_tree = ToolkitTree(
        Element(
            input;
            id=:project_input,
            key=:project_input,
            state_factory=() -> input_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), input_tree)
    input_semantics = toolkit_semantic_tree(input_tree)
    input_node = semantic_node(input_semantics, "project_input")
    @test input_node.role == TextboxRole
    @test input_node.label == "Project name"
    @test input_node.state.value == "Wicked"
    @test input_node.metadata[:input]

    textbox = TextBox(placeholder="Project name")
    textbox_state = TextBoxState("Wicked"; focused=true)
    textbox_tree = ToolkitTree(
        Element(
            textbox;
            id=:project_textbox,
            key=:project_textbox,
            state_factory=() -> textbox_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), textbox_tree)
    textbox_semantics = toolkit_semantic_tree(textbox_tree)
    textbox_node = semantic_node(textbox_semantics, "project_textbox")
    @test textbox_node.role == TextboxRole
    @test textbox_node.label == "Project name"
    @test textbox_node.state.value == "Wicked"
    @test textbox_node.metadata[:text_box]

    text_field = TextField(placeholder="Project name")
    text_field_state = TextFieldState("Wicked"; focused=true)
    text_field_tree = ToolkitTree(
        Element(
            text_field;
            id=:project_text_field,
            key=:project_text_field,
            state_factory=() -> text_field_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), text_field_tree)
    text_field_semantics = toolkit_semantic_tree(text_field_tree)
    text_field_node = semantic_node(text_field_semantics, "project_text_field")
    @test text_field_node.role == TextboxRole
    @test text_field_node.label == "Project name"
    @test text_field_node.state.value == "Wicked"
    @test text_field_node.metadata[:text_field]

    search = SearchInput(placeholder="Find")
    search_state = SearchInputState("query"; focused=true)
    search_tree = ToolkitTree(
        Element(
            search;
            id=:search,
            key=:search,
            state_factory=() -> search_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), search_tree)
    search_semantics = toolkit_semantic_tree(search_tree)
    search_node = semantic_node(search_semantics, "search")
    @test search_node.role == TextboxRole
    @test search_node.label == "Find"
    @test search_node.state.value == "query"
    @test search_node.metadata[:search]

    password = PasswordInput(placeholder="Password", mask="*")
    password_state = TextInputState("secret"; focused=true)
    password_tree = ToolkitTree(
        Element(
            password;
            id=:password_input,
            key=:password_input,
            state_factory=() -> password_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), password_tree)
    password_semantics = toolkit_semantic_tree(password_tree)
    password_node = semantic_node(password_semantics, "password_input")
    @test password_node.role == TextboxRole
    @test password_node.label == "Password"
    @test password_node.state.value === nothing
    @test password_node.metadata[:password]
    @test password_node.metadata[:protected]

    password_field = PasswordField(placeholder="Password", mask="*")
    password_field_state = PasswordFieldState("secret"; focused=true)
    password_field_tree = ToolkitTree(
        Element(
            password_field;
            id=:password_field,
            key=:password_field,
            state_factory=() -> password_field_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), password_field_tree)
    password_field_semantics = toolkit_semantic_tree(password_field_tree)
    password_field_node = semantic_node(password_field_semantics, "password_field")
    @test password_field_node.role == TextboxRole
    @test password_field_node.label == "Password"
    @test password_field_node.state.value === nothing
    @test password_field_node.metadata[:password]
    @test password_field_node.metadata[:password_field]
    @test password_field_node.metadata[:protected]

    dispatcher = SemanticDispatcher()
    register_text_input_semantic_handlers!(dispatcher, :project_name, widget, state)
    pilot = SemanticPilot(semantics; dispatcher)
    @test perform_semantic_action!(pilot, "project_name", FocusSemanticAction).handled
    set_result = perform_semantic_action!(pilot, "project_name", SetValueSemanticAction; value="Wicked.jl")
    @test set_result.handled
    @test editing_text(state) == "Wicked.jl"

    input_dispatcher = SemanticDispatcher()
    register_input_semantic_handlers!(input_dispatcher, :project_input, input, input_state)
    input_pilot = SemanticPilot(input_semantics; dispatcher=input_dispatcher)
    @test perform_semantic_action!(input_pilot, "project_input", SetValueSemanticAction; value="Input").handled
    @test editing_text(input_state) == "Input"

    textbox_dispatcher = SemanticDispatcher()
    register_text_box_semantic_handlers!(textbox_dispatcher, :project_textbox, textbox, textbox_state)
    textbox_pilot = SemanticPilot(textbox_semantics; dispatcher=textbox_dispatcher)
    @test perform_semantic_action!(textbox_pilot, "project_textbox", SetValueSemanticAction; value="TextBox").handled
    @test editing_text(textbox_state) == "TextBox"

    text_field_dispatcher = SemanticDispatcher()
    register_text_field_semantic_handlers!(text_field_dispatcher, :project_text_field, text_field, text_field_state)
    text_field_pilot = SemanticPilot(text_field_semantics; dispatcher=text_field_dispatcher)
    @test perform_semantic_action!(text_field_pilot, "project_text_field", SetValueSemanticAction; value="TextField").handled
    @test editing_text(text_field_state) == "TextField"

    search_dispatcher = SemanticDispatcher()
    register_search_input_semantic_handlers!(search_dispatcher, :search, search, search_state)
    search_pilot = SemanticPilot(search_semantics; dispatcher=search_dispatcher)
    @test perform_semantic_action!(search_pilot, "search", SetValueSemanticAction; value="deploy").handled
    @test editing_text(search_state) == "deploy"

    password_dispatcher = SemanticDispatcher()
    register_password_input_semantic_handlers!(password_dispatcher, :password_input, password, password_state)
    password_pilot = SemanticPilot(password_semantics; dispatcher=password_dispatcher)
    password_result = perform_semantic_action!(password_pilot, "password_input", SetValueSemanticAction; value="changed")
    @test password_result.handled
    @test editing_text(password_state) == "changed"
    @test password_result.value[:value] === nothing

    password_field_dispatcher = SemanticDispatcher()
    register_password_field_semantic_handlers!(password_field_dispatcher, :password_field, password_field, password_field_state)
    password_field_pilot = SemanticPilot(password_field_semantics; dispatcher=password_field_dispatcher)
    password_field_result = perform_semantic_action!(password_field_pilot, "password_field", SetValueSemanticAction; value="changed")
    @test password_field_result.handled
    @test editing_text(password_field_state) == "changed"
    @test password_field_result.value[:value] === nothing
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
    dispatcher = SemanticDispatcher()
    register_text_area_semantic_handlers!(dispatcher, :notes, widget, state)
    pilot = SemanticPilot(semantics; dispatcher)
    @test perform_semantic_action!(pilot, "notes", FocusSemanticAction).handled
    set_result = perform_semantic_action!(pilot, "notes", SetValueSemanticAction; value="updated\nnotes")
    @test set_result.handled
    @test editing_text(state) == "updated\nnotes"

    textarea = Textarea()
    textarea_state = TextAreaState("compat"; focused=true)
    textarea_tree = ToolkitTree(
        Element(
            textarea;
            id=:textarea,
            key=:textarea,
            state_factory=() -> textarea_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(2, 24)), textarea_tree)
    textarea_semantics = toolkit_semantic_tree(textarea_tree)
    textarea_node = semantic_node(textarea_semantics, "textarea")
    @test textarea_node.role == TextboxRole
    @test textarea_node.label == "Textarea"
    @test textarea_node.metadata[:multiline]
    @test textarea_node.metadata[:compatibility_spelling]
    textarea_dispatcher = SemanticDispatcher()
    register_textarea_semantic_handlers!(textarea_dispatcher, :textarea, textarea, textarea_state)
    textarea_pilot = SemanticPilot(textarea_semantics; dispatcher=textarea_dispatcher)
    textarea_result = perform_semantic_action!(textarea_pilot, "textarea", SetValueSemanticAction; value="updated")
    @test textarea_result.handled
    @test editing_text(textarea_state) == "updated"
    @test textarea_result.value[:compatibility_spelling]

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

    combobox = Combobox([
        ChoiceOption(:alpha, "Alpha"),
        ChoiceOption(:gamma, "Gamma"),
    ]; placeholder="Choose mode")
    combobox_state = state_for(combobox)
    combobox_state.selected = 2
    combobox_tree = ToolkitTree(
        Element(
            combobox;
            id=:mode_combobox,
            key=:mode_combobox,
            state_factory=() -> combobox_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), combobox_tree)
    combobox_semantics = toolkit_semantic_tree(combobox_tree)
    combobox_node = semantic_node(combobox_semantics, "mode_combobox")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(combobox_semantics)))
    @test combobox_node.role == ListRole
    @test combobox_node.label == "Choose mode"
    @test combobox_node.metadata[:option_count] == 2
    @test combobox_node.state.value == "Gamma"
    @test combobox_node.metadata[:selected_value] == :gamma
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

    selection_list = SelectionList([
        ChoiceOption(:alpha, "Alpha"),
        ChoiceOption(:beta, "Beta"; disabled=true),
        ChoiceOption(:gamma, "Gamma"),
    ])
    selection_list_state = SelectionListState(selected=[1, 3])
    selection_list_tree = ToolkitTree(
        Element(
            selection_list;
            id=:selection_features,
            key=:selection_features,
            state_factory=() -> selection_list_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), selection_list_tree)
    selection_list_semantics = toolkit_semantic_tree(selection_list_tree)
    selection_list_node = semantic_node(selection_list_semantics, "selection_features")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(selection_list_semantics)))
    @test selection_list_node.role == ListRole
    @test selection_list_node.label == "Selection list"
    @test selection_list_node.metadata[:option_count] == 3
    @test selection_list_node.children[3].state.checked == CheckedValue

    transfer = TransferList([
        ChoiceOption(:alpha, "Alpha"),
        ChoiceOption(:gamma, "Gamma"),
    ])
    transfer_state = state_for(transfer)
    push!(transfer_state.selected, 2)
    transfer_tree = ToolkitTree(
        Element(
            transfer;
            id=:transfer_features,
            key=:transfer_features,
            state_factory=() -> transfer_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(2, 24)), transfer_tree)
    transfer_semantics = toolkit_semantic_tree(transfer_tree)
    transfer_node = semantic_node(transfer_semantics, "transfer_features")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(transfer_semantics)))
    @test transfer_node.role == ListRole
    @test transfer_node.label == "Transfer list"
    @test transfer_node.metadata[:selected_count] == 1
    @test transfer_node.children[2].state.checked == CheckedValue
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
    radio_button = RadioButton(:gamma, "Gamma")
    radio_button_state = state_for(radio_button)
    radio_button_state.selected = 1
    radio_button_tree = ToolkitTree(
        Element(
            radio_button;
            id=:single_mode,
            key=:single_mode,
            state_factory=() -> radio_button_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), radio_button_tree)
    radio_button_semantics = toolkit_semantic_tree(radio_button_tree)
    radio_button_node = semantic_node(radio_button_semantics, "single_mode")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(radio_button_semantics)))
    @test radio_button_node.role == GroupRole
    @test radio_button_node.label == "Radio button"
    @test radio_button_node.metadata[:option_count] == 1
    @test radio_button_node.children[1].state.checked == CheckedValue
    @test node.children[3].state.checked == CheckedValue
    @test node.children[3].state.selected
    @test SelectSemanticAction in node.children[3].actions

    radio_set = RadioSet([
        ChoiceOption(:alpha, "Alpha"),
        ChoiceOption(:beta, "Beta"; disabled=true),
        ChoiceOption(:gamma, "Gamma"),
    ])
    radio_set_state = RadioSetState(selected=3)
    radio_set_tree = ToolkitTree(
        Element(
            radio_set;
            id=:mode_set,
            key=:mode_set,
            state_factory=() -> radio_set_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), radio_set_tree)
    radio_set_semantics = toolkit_semantic_tree(radio_set_tree)
    radio_set_node = semantic_node(radio_set_semantics, "mode_set")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(radio_set_semantics)))
    @test radio_set_node.role == GroupRole
    @test radio_set_node.label == "Radio set"
    @test radio_set_node.metadata[:option_count] == 3
    @test radio_set_node.children[3].state.checked == CheckedValue
end

@testset "Tabs toolkit semantic integration" begin
    widget = Tabs([Tab(:build, "Build"), Tab(:test, "Test"), Tab(:release, "Release")])
    state = TabsState(2)
    @test selected_tab(widget, state).id == :test
    @test select_next_tab!(state, widget) === state
    @test selected_tab(widget, state).id == :release
    @test select_previous_tab!(state, widget) === state
    @test selected_tab(widget, state).id == :test
    @test select_tab!(state, widget, 99) === state
    @test selected_tab(widget, state).id == :release
    @test select_tab!(state, widget, 2) === state
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
    dispatcher = SemanticDispatcher()
    register_tabs_semantic_handlers!(dispatcher, :workflow_tabs, widget, state)
    tabs_pilot = SemanticPilot(semantics; dispatcher)
    focus_result = perform_semantic_action!(tabs_pilot, "workflow_tabs", FocusSemanticAction)
    @test focus_result.handled
    @test focus_result.value == :test
    select_result = perform_semantic_action!(tabs_pilot, "workflow_tabs/tab-3", SelectSemanticAction)
    @test select_result.handled
    @test select_result.value == :release
    @test selected_tab(widget, state).id == :release
    pop!(widget.tabs)
    stale_result = perform_semantic_action!(tabs_pilot, "workflow_tabs/tab-3", SelectSemanticAction)
    @test !stale_result.handled
    @test occursin("not available", stale_result.message)
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

    tree_view = TreeView([
        TreeNode(:root, "Root"; children=[TreeNode(:child, "Child")]),
    ])
    tree_view_state = TreeViewState(selected=:root, expanded=Set([:root]))
    tree_view_tree = ToolkitTree(
        Element(
            tree_view;
            id=:project_tree_view,
            key=:project_tree_view,
            state_factory=() -> tree_view_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), tree_view_tree)
    tree_view_semantics = toolkit_semantic_tree(tree_view_tree)
    tree_view_node = semantic_node(tree_view_semantics, "project_tree_view")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(tree_view_semantics)))
    @test tree_view_node.role == TreeRole
    @test tree_view_node.label == "Tree view"
    @test tree_view_node.metadata[:root_count] == 1
    @test tree_view_node.children[1].state.expanded
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

    list_box = ListBox(["Build", "Test", "Release"])
    list_box_state = state_for(list_box)
    list_box_state.selected = 2
    list_box_tree = ToolkitTree(
        Element(
            list_box;
            id=:pipeline_list_box,
            key=:pipeline_list_box,
            state_factory=() -> list_box_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), list_box_tree)
    list_box_semantics = toolkit_semantic_tree(list_box_tree)
    list_box_node = semantic_node(list_box_semantics, "pipeline_list_box")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(list_box_semantics)))
    @test list_box_node.role == ListRole
    @test list_box_node.label == "List box"
    @test list_box_node.metadata[:item_count] == 3
    @test list_box_node.children[2].state.selected

    list_view = ListView(["Build", "Test", "Release"])
    list_view_state = state_for(list_view)
    list_view_state.selected = 2
    list_view_tree = ToolkitTree(
        Element(
            list_view;
            id=:pipeline_list_view,
            key=:pipeline_list_view,
            state_factory=() -> list_view_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), list_view_tree)
    list_view_semantics = toolkit_semantic_tree(list_view_tree)
    list_view_node = semantic_node(list_view_semantics, "pipeline_list_view")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(list_view_semantics)))
    @test list_view_node.role == ListRole
    @test list_view_node.label == "List view"
    @test list_view_node.metadata[:item_count] == 3
    @test list_view_node.children[2].state.selected

    option_list = OptionList(["Build", "Test", "Release"])
    option_list_state = state_for(option_list)
    option_list_state.selected = 2
    option_list_tree = ToolkitTree(
        Element(
            option_list;
            id=:pipeline_option_list,
            key=:pipeline_option_list,
            state_factory=() -> option_list_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(3, 24)), option_list_tree)
    option_list_semantics = toolkit_semantic_tree(option_list_tree)
    option_list_node = semantic_node(option_list_semantics, "pipeline_option_list")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(option_list_semantics)))
    @test option_list_node.role == ListRole
    @test option_list_node.label == "Option list"
    @test option_list_node.metadata[:item_count] == 3
    @test option_list_node.children[2].state.selected
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
    dispatcher = SemanticDispatcher()
    register_scroll_view_semantic_handlers!(dispatcher, :output, widget, state; viewport_height=2)
    pilot = SemanticPilot(semantics; dispatcher)
    @test perform_semantic_action!(pilot, "output", FocusSemanticAction).handled
    @test perform_semantic_action!(pilot, "output", IncrementSemanticAction).handled
    @test state.row == 2
    scroll_result = perform_semantic_action!(pilot, "output", ScrollIntoViewSemanticAction; value=0)
    @test scroll_result.handled
    @test state.row == 0
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
    dispatcher = SemanticDispatcher()
    register_scrollbar_semantic_handlers!(dispatcher, :scrollbar, widget, state)
    pilot = SemanticPilot(semantics; dispatcher)
    @test perform_semantic_action!(pilot, "scrollbar", FocusSemanticAction).handled
    @test perform_semantic_action!(pilot, "scrollbar", IncrementSemanticAction).handled
    @test state.row == 6
    @test perform_semantic_action!(pilot, "scrollbar", DecrementSemanticAction).handled
    @test state.row == 5
    scroll_result = perform_semantic_action!(pilot, "scrollbar", ScrollIntoViewSemanticAction; value=16)
    @test scroll_result.handled
    @test state.row == 16
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
    indicator = LoadingIndicator(frames=["a", "b"]; label="Loading")
    indicator_state = LoadingIndicatorState(2)
    indicator_tree = ToolkitTree(
        Element(
            indicator;
            id=:loading_indicator,
            key=:loading_indicator,
            state_factory=() -> indicator_state,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 16)), indicator_tree)
    indicator_semantics = toolkit_semantic_tree(indicator_tree)
    indicator_node = semantic_node(indicator_semantics, "loading_indicator")
    @test indicator_node.role == ProgressRole
    @test indicator_node.metadata[:indicator] == :loading
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "spinner")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == ProgressRole
    @test node.label == "Indexing"
    @test node.state.busy
    @test node.metadata[:frame] == 2
    @test node.metadata[:frame_count] == 2
end

@testset "Calendar toolkit semantic integration" begin
    widget = Calendar(2026, 7; selected=Date(2026, 7, 14), marked=[Date(2026, 7, 15)])
    state = CalendarState(widget; focused=true)
    tree = ToolkitTree(
        Element(
            widget;
            id=:calendar,
            key=:calendar,
            state_factory=() -> state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(8, 24)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "calendar")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == TableRole
    @test node.label == "July 2026"
    @test node.state.focused
    @test node.state.value == "2026-07-14"
    @test node.metadata[:visible_month] == Date(2026, 7, 1)
    @test node.metadata[:marked_count] == 1
end

@testset "Checkbox toolkit semantic integration" begin
    check_box = CheckBox("Accepted")
    check_box_state = CheckBoxState(true)
    check_box_tree = ToolkitTree(
        Element(
            check_box;
            id=:accepted,
            key=:accepted,
            state_factory=() -> check_box_state,
            focusable=true,
        ),
    )
    render_toolkit!(Frame(Buffer(1, 24)), check_box_tree)
    check_box_semantics = toolkit_semantic_tree(check_box_tree)
    check_box_node = semantic_node(check_box_semantics, "accepted")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(check_box_semantics)))
    @test check_box_node.role == CheckboxRole
    @test check_box_node.label == "Accepted"
    @test check_box_node.state.checked == CheckedValue
    @test ActivateSemanticAction in check_box_node.actions
end

@testset "Toggle toolkit semantic integration" begin
    widget = Toggle(on_label="Enabled", off_label="Disabled")
    state = ToggleState(true)
    switch = Switch(on_label="On", off_label="Off")
    switch_state = SwitchState(true)
    tree = ToolkitTree(
        column(
            Element(
                widget;
                id=:feature_flag,
                key=:feature_flag,
                state_factory=() -> state,
                focusable=true,
            ),
            Element(
                switch;
                id=:feature_switch,
                key=:feature_switch,
                state_factory=() -> switch_state,
                focusable=true,
            ),
        ),
    )
    render_toolkit!(Frame(Buffer(2, 16)), tree)
    semantics = toolkit_semantic_tree(tree)
    node = semantic_node(semantics, "feature_flag")
    switch_node = semantic_node(semantics, "feature_switch")

    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test node.role == CheckboxRole
    @test node.label == "Enabled"
    @test node.state.focused
    @test node.state.checked == CheckedValue
    @test ActivateSemanticAction in node.actions
    @test switch_node.role == CheckboxRole
    @test switch_node.label == "On"
    @test switch_node.state.checked == CheckedValue
    @test ActivateSemanticAction in switch_node.actions
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
    @test node.role == TableRole
    @test node.label == "July 2026"
    @test node.state.value == "2026-07-11"
    @test node.metadata[:selected] == Dates.Date(2026, 7, 11)
    @test node.metadata[:visible_month] == Dates.Date(2026, 7, 1)
    @test node.metadata[:marked_count] == 1
    @test length(node.children) == 5
    @test node.children[1].role == RowRole
    @test node.children[1].children[4].metadata[:date] == Dates.Date(2026, 7, 4)
    @test node.children[1].children[4].metadata[:marked]
    @test node.children[2].children[6].state.selected
end

@testset "Text widget toolkit semantic integration" begin
    label = Label("Build succeeded")
    paragraph = Paragraph("The release artifact is ready.\nPublish after review.")
    heading = Heading("Release status"; level=2)
    markup = MarkupText("**Ready** to publish")
    static = Static("Static status\nReady")
    text_view = TextView("Text view status\nReady")
    rich_text = RichText("Rich text status")
    tree = ToolkitTree(
        column(
            Element(label; id=:build_status, key=:build_status),
            Element(paragraph; id=:release_notes, key=:release_notes),
            Element(heading; id=:release_heading, key=:release_heading),
            Element(markup; id=:release_markup, key=:release_markup),
            Element(static; id=:static_status, key=:static_status),
            Element(text_view; id=:text_view_status, key=:text_view_status),
            Element(rich_text; id=:rich_text_status, key=:rich_text_status),
        ),
    )
    render_toolkit!(Frame(Buffer(6, 40)), tree)
    semantics = toolkit_semantic_tree(tree)
    label_node = semantic_node(semantics, "build_status")
    paragraph_node = semantic_node(semantics, "release_notes")
    heading_node = semantic_node(semantics, "release_heading")
    markup_node = semantic_node(semantics, "release_markup")
    static_node = semantic_node(semantics, "static_status")
    text_view_node = semantic_node(semantics, "text_view_status")
    rich_text_node = semantic_node(semantics, "rich_text_status")

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
    @test heading_node.role == HeadingRole
    @test heading_node.label == "Release status"
    @test heading_node.state.readonly
    @test heading_node.metadata[:widget] == :heading
    @test heading_node.metadata[:level] == 2
    @test markup_node.role == ParagraphRole
    @test occursin("Ready", markup_node.label)
    @test markup_node.state.readonly
    @test markup_node.metadata[:widget] == :markup_text
    @test :strong in markup_node.metadata[:inline_roles]
    @test static_node.role == ParagraphRole
    @test static_node.label == "Static status\nReady"
    @test static_node.state.readonly
    @test static_node.metadata[:widget] == :static
    @test text_view_node.role == ParagraphRole
    @test text_view_node.label == "Text view status\nReady"
    @test text_view_node.state.readonly
    @test text_view_node.metadata[:widget] == :text_view
    @test rich_text_node.role == GroupRole
    @test rich_text_node.label == "Rich text"
    @test rich_text_node.state.readonly
    @test rich_text_node.metadata[:line_count] == 1
    dispatcher = SemanticDispatcher()
    register_label_semantic_handlers!(dispatcher, :build_status, label)
    register_paragraph_semantic_handlers!(dispatcher, :release_notes, paragraph)
    register_heading_semantic_handlers!(dispatcher, :release_heading, heading)
    register_markup_text_semantic_handlers!(dispatcher, :release_markup, markup)
    register_static_semantic_handlers!(dispatcher, :static_status, static)
    register_text_view_semantic_handlers!(dispatcher, :text_view_status, text_view)
    register_rich_text_semantic_handlers!(dispatcher, :rich_text_status, rich_text)
    pilot = SemanticPilot(semantics; dispatcher)
    for id in (
        "build_status",
        "release_notes",
        "release_heading",
        "release_markup",
        "static_status",
        "text_view_status",
        "rich_text_status",
    )
        @test perform_semantic_action!(pilot, id, FocusSemanticAction).handled
        @test perform_semantic_action!(pilot, id, SelectSemanticAction).handled
    end
end

@testset "Structural widget toolkit semantic integration" begin
    widgets = (
        (:block, Block(title="Panel")),
        (:clear, Clear()),
        (:spacer, Spacer()),
        (:rule, Rule()),
        (:separator, Separator()),
        (:divider, Divider()),
        (:padding, Padding(Label("padded"))),
        (:box, Box(Label("boxed"); block=Block(title="Boxed"))),
        (:row, Row(Label("left"), Label("right"))),
        (:column, Column(Label("top"), Label("bottom"))),
        (:stack, Stack(Label("base"), Label("overlay"))),
        (:overlay, Overlay(Label("base"), Label("overlay"))),
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
    @test semantic_node(semantics, "separator").metadata[:direction] == :horizontal
    @test semantic_node(semantics, "divider").metadata[:direction] == :horizontal
    @test semantic_node(semantics, "padding").metadata[:margin] == (1, 1, 1, 1)
    @test semantic_node(semantics, "box").label == "Boxed"
    @test semantic_node(semantics, "row").metadata[:orientation] == :horizontal
    @test semantic_node(semantics, "column").metadata[:orientation] == :vertical
    @test semantic_node(semantics, "stack").metadata[:layered]
    @test semantic_node(semantics, "overlay").label == "Overlay"
    @test semantic_node(semantics, "overlay").metadata[:layered]
    @test semantic_node(semantics, "center").metadata[:width] == 12
    @test semantic_node(semantics, "grid").metadata[:rows] == 1
    @test semantic_node(semantics, "grid").metadata[:columns] == 1
    @test all(semantic_node(semantics, string(id)).role == (id in (:clear, :spacer, :rule, :separator, :divider) ? GenericRole : GroupRole) for (id, _) in widgets)
    dispatcher = SemanticDispatcher()
    register_block_semantic_handlers!(dispatcher, :block, widgets[1][2])
    register_clear_semantic_handlers!(dispatcher, :clear, widgets[2][2])
    register_spacer_semantic_handlers!(dispatcher, :spacer, widgets[3][2])
    register_rule_semantic_handlers!(dispatcher, :rule, widgets[4][2])
    register_separator_semantic_handlers!(dispatcher, :separator, widgets[5][2])
    register_divider_semantic_handlers!(dispatcher, :divider, widgets[6][2])
    pilot = SemanticPilot(semantics; dispatcher)
    for id in ("block", "clear", "spacer", "rule", "separator", "divider")
        @test perform_semantic_action!(pilot, id, FocusSemanticAction).handled
        @test perform_semantic_action!(pilot, id, SelectSemanticAction).handled
    end
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
    @test selected_menu_item(widget, state).id == :quit
    @test selected_menu_message(widget, state) == :quit_application
    @test select_previous_menu_item!(state, widget) === state
    @test selected_menu_item(widget, state).id == :open
    @test select_next_menu_item!(state, widget) === state
    @test selected_menu_item(widget, state).id == :quit
    @test select_menu_item!(state, widget, 2) === state
    @test isnothing(selected_menu_item(widget, state))
    @test select_menu_item!(state, widget, 1) === state
    @test select_menu_item!(state, widget, 3) === state
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
    disabled_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, MenuState(selected=2))
    @test disabled_descriptor.state.value === nothing
    @test disabled_descriptor.metadata[:selected_id] === nothing
    @test open.role == MenuItemRole
    @test open.metadata[:shortcut] == "Ctrl+O"
    @test open.metadata[:message] == :open_document
    @test !save.state.enabled
    @test isempty(save.actions)
    @test quit.state.selected
    @test ActivateSemanticAction in quit.actions
    dispatcher = SemanticDispatcher()
    register_menu_semantic_handlers!(dispatcher, :actions, widget, state)
    menu_pilot = SemanticPilot(semantics; dispatcher)
    focus_result = perform_semantic_action!(menu_pilot, "actions/item-1", FocusSemanticAction)
    @test focus_result.handled
    @test focus_result.value == :open
    @test selected_menu_item(widget, state).id == :open
    select_result = perform_semantic_action!(menu_pilot, "actions/item-3", SelectSemanticAction)
    @test select_result.handled
    @test select_result.value == :quit
    activate_result = perform_semantic_action!(menu_pilot, "actions/item-3", ActivateSemanticAction)
    @test activate_result.handled
    @test activate_result.value == :quit_application
    widget.items[3] = MenuItem(:quit, "Quit", :quit_application; shortcut="Ctrl+Q", disabled=true)
    stale_menu_result = perform_semantic_action!(menu_pilot, "actions/item-3", ActivateSemanticAction)
    @test !stale_menu_result.handled
    @test occursin("not available", stale_menu_result.message)
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
    dispatcher = SemanticDispatcher()
    register_markdown_view_semantic_handlers!(dispatcher, :documentation, state)
    pilot = SemanticPilot(semantics; dispatcher)
    @test perform_semantic_action!(pilot, "documentation", IncrementSemanticAction).handled
    link_result = perform_semantic_action!(pilot, only(node.children).id, ActivateSemanticAction)
    @test link_result.handled
    @test link_result.value == "https://example.test"
end

@testset "Tabbed content semantic integration" begin
    content = TabbedContent([
        ContentPage(:overview, "Overview", Label("overview")),
        ContentPage(:details, "Details", Label("details"); closable=true),
        ContentPage(:locked, "Locked", Label("locked"); disabled=true),
    ])
    view = TabbedContentView()
    explicit_buffer = Buffer(4, 24)
    @test render!(explicit_buffer, view, explicit_buffer.area, content) === explicit_buffer
    @test occursin("Overview", plain_snapshot(explicit_buffer))
    default_buffer = Buffer(4, 24)
    @test render!(default_buffer, view, default_buffer.area) === default_buffer
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
    @test FocusSemanticAction in details.actions
    @test SelectSemanticAction in details.actions
    @test DismissSemanticAction in details.actions
    @test !locked.state.enabled
    @test isempty(locked.actions)
    @test panel.label == "Details"
    @test panel.metadata[:key] == :details
    dispatcher = SemanticDispatcher()
    register_tabbed_content_view_semantic_handlers!(dispatcher, :workspace, view, content)
    pilot = SemanticPilot(semantics; dispatcher)
    focus_result = perform_semantic_action!(pilot, "workspace", FocusSemanticAction)
    @test focus_result.handled
    @test focus_result.value == :details
    previous_result = perform_semantic_action!(pilot, "workspace/list", DecrementSemanticAction)
    @test previous_result.handled
    @test previous_result.value == :overview
    locked_result = perform_semantic_action!(pilot, "workspace/tab/3", SelectSemanticAction)
    @test !locked_result.handled
    @test occursin("disabled", locked_result.message)
    dismiss_result = perform_semantic_action!(pilot, "workspace/tab/2", DismissSemanticAction)
    @test dismiss_result.handled
    @test dismiss_result.value == :details
    @test :details ∉ content_page_keys(content.switcher)
end

@testset "Toolkit tree root contract" begin
    button = Button("Run", :run)
    button_state = state_for(button)
    tree = ToolkitTree(Element(button; id=:run, key=:run, state_factory=() -> button_state, focusable=true))
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
    dispatcher = SemanticDispatcher()
    register_button_semantic_handlers!(dispatcher, :run, button, button_state)
    pilot = SemanticPilot(semantics; dispatcher)
    @test perform_semantic_action!(pilot, "run", FocusSemanticAction).handled
    activate_result = perform_semantic_action!(pilot, "run", ActivateSemanticAction)
    @test activate_result.handled
    @test activate_result.value == :run

    push = PushButton("Launch", :launch)
    push_state = PushButtonState()
    push_tree = ToolkitTree(Element(push; id=:launch, key=:launch, state_factory=() -> push_state, focusable=true))
    render_toolkit!(Frame(Buffer(2, 16)), push_tree)
    push_semantics = toolkit_semantic_tree(push_tree)
    push_node = semantic_node(push_semantics, "launch")
    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(push_semantics)))
    @test push_node.role == ButtonRole
    @test ActivateSemanticAction in push_node.actions
    push_dispatcher = SemanticDispatcher()
    register_push_button_semantic_handlers!(push_dispatcher, :launch, push, push_state)
    push_pilot = SemanticPilot(push_semantics; dispatcher=push_dispatcher)
    push_result = perform_semantic_action!(push_pilot, "launch", ActivateSemanticAction)
    @test push_result.handled
    @test push_result.value == :launch
end

@testset "keybinding help" begin
    bindings = [
        Wicked.KeyBinding("q", "quit"),
        Wicked.KeyBinding("s", "save"; enabled=false),
        Wicked.KeyBinding("?", "help"),
    ]

    # disabled bindings are excluded from derived help
    hints = Wicked.help_hints(bindings)
    @test length(hints) == 2
    @test hints[1] isa KeyHint
    @test (hints[1].key, hints[1].description) == ("q", "quit")
    @test hints[2].key == "?"

    # the derived hints feed the existing widgets
    @test Footer(Wicked.help_hints(bindings)) isa Footer
    @test HelpView(Wicked.help_hints(bindings)) isa HelpView

    # short help renders enabled bindings on one line
    @test Wicked.short_help(bindings) == "q quit • ? help"
    @test Wicked.short_help(bindings; max_width=15) == "q quit • ? help"
    # narrow widths truncate with an overflow marker
    @test Wicked.short_help(bindings; max_width=10) == "q quit • …"
    @test Wicked.short_help(bindings; max_width=0) == ""
    # everything disabled yields an empty line
    @test Wicked.short_help([Wicked.KeyBinding("x", "y"; enabled=false)]) == ""
    # custom separator is honored
    @test Wicked.short_help([Wicked.KeyBinding("a", "b"), Wicked.KeyBinding("c", "d")]; separator="  ") ==
          "a b  c d"
end
