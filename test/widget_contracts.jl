using SHA

@testset "Immediate widget dimension contracts" begin
    function check_dimension_contract(widget, state=nothing)
        function render_contract!(buffer, area)
            result = state === nothing ?
                render!(buffer, widget, area) :
                render!(buffer, widget, area, state)
            if state !== nothing && hasmethod(
                render!,
                Tuple{Buffer,typeof(widget),Rect},
            )
                @test render!(buffer, widget, area) === buffer
            end
            return result
        end

        zero = Buffer(0, 0)
        @test render_contract!(zero, zero.area) === zero

        minimal = Buffer(1, 1)
        @test render_contract!(minimal, minimal.area) === minimal

        clipped = Buffer(2, 4)
        @test render_contract!(clipped, Rect(2, 3, 4, 8)) === clipped

        narrow = Buffer(2, 4)
        @test render_contract!(narrow, narrow.area) === narrow
        wide = Buffer(6, 20)
        @test render_contract!(wide, wide.area) === wide
    end

    fixtures = [
        ("Dialog", Dialog("Body"), DialogState([DialogButton("OK", :ok)]; open=true)),
        ("Window", Window("Body"), WindowState([DialogButton("OK", :ok)]; open=true)),
        ("ErrorView", ErrorView(ErrorException("boom")), nothing),
        ("Button", Button("Run"), ButtonState()),
        ("PushButton", PushButton("Run"), PushButtonState()),
        ("CheckBox", CheckBox("Ready"), CheckBoxState()),
        ("Checkbox", Checkbox("Ready"), CheckboxState()),
        ("Switch", Switch(), SwitchState()),
        ("Toggle", Toggle(), ToggleState()),
        ("Input", Input(), InputState("x")),
        ("TextBox", TextBox(), TextBoxState("x")),
        (
            "RadioGroup",
            RadioGroup([ChoiceOption(:one, "One")]),
            RadioGroupState(),
        ),
        (
            "RadioBoxList",
            RadioBoxList([ChoiceOption(:one, "One")]),
            RadioBoxListState(),
        ),
        (
            "RadioSet",
            RadioSet([ChoiceOption(:one, "One")]),
            RadioSetState(),
        ),
        ("Select", Select([ChoiceOption(:one, "One")]), SelectState()),
        (
            "MultiSelect",
            MultiSelect([ChoiceOption(:one, "One")]),
            MultiSelectState(),
        ),
        (
            "CheckBoxList",
            CheckBoxList([ChoiceOption(:one, "One")]),
            CheckBoxListState(),
        ),
        (
            "SelectionList",
            SelectionList([ChoiceOption(:one, "One")]),
            SelectionListState(),
        ),
        ("TextInput", TextInput(), TextInputState("x")),
        ("TextField", TextField(), TextFieldState("x")),
        ("PasswordField", PasswordField(), PasswordFieldState("x")),
        ("PasswordInput", PasswordInput(), TextInputState("x")),
        ("SearchInput", SearchInput(placeholder="Search"), SearchInputState("x")),
        ("TextArea", TextArea(), TextAreaState("x")),
        ("Textarea", Textarea(), TextareaState("x")),
        ("NumericInput", NumericInput(), NumberInputState()),
        ("List", List(["one"]), ListState(selected=1)),
        ("ListView", ListView(["one"]), ListViewState(selected=1)),
        ("OptionList", OptionList(["one"]), OptionListState(selected=1)),
        (
            "Table",
            Table([TableColumn("A"; constraint=Length(3))], [["x"]]),
            TableState(),
        ),
        ("Tabs", Tabs([Tab(:one, "One")]), TabsState(1)),
        ("Tree", Tree([TreeNode(:root, "Root")]), TreeState()),
        ("TreeView", TreeView([TreeNode(:root, "Root")]), TreeViewState()),
        (
            "Menu",
            Menu([MenuItem(:open, "Open", :open_message)]),
            MenuState(selected=1),
        ),
        ("Label", Label("x"), nothing),
        (
            "ToolkitTree",
            ToolkitTree(Element(Label("x"); key=:dimension_contract)),
            nothing,
        ),
        ("Paragraph", Paragraph("x"), nothing),
        ("Heading", Heading("x"), nothing),
        ("MarkupText", MarkupText("**x**"), nothing),
        ("TextView", TextView("x"), nothing),
        ("Padding", Padding(Label("x")), nothing),
        ("Box", Box(Label("x")), nothing),
        ("Row", Row(Label("x")), nothing),
        ("Column", Column(Label("x")), nothing),
        ("Stack", Stack(Label("x")), nothing),
        ("Overlay", Overlay(Label("x")), nothing),
        ("Center", Center(Label("x"); height=1, width=1), nothing),
        (
            "Grid",
            Grid(Label("x"); rows=[Fill(1)], columns=[Fill(1)]),
            nothing,
        ),
        ("Header", Header("Title"), nothing),
        ("Footer", Footer([:q => "Quit"]), nothing),
        ("TitleBar", TitleBar("Title"), nothing),
        ("StatusBar", StatusBar([:q => "Quit"]), nothing),
        ("AppShell", AppShell(Label("Body"); title="Title", shortcuts=[:q => "Quit"]), nothing),
        ("Badge", Badge("OK"), nothing),
        ("Alert", Alert("Warning"), nothing),
        ("NotificationView", NotificationView(NotificationCenter()), nothing),
        (
            "CommandPalette",
            CommandPalette([CommandItem(:open, "Open")]),
            CommandPaletteState(open=true),
        ),
        ("Block", Block(), nothing),
        ("Clear", Clear(), nothing),
        ("Spacer", Spacer(), nothing),
        ("Rule", Rule(), nothing),
        ("Separator", Separator(), nothing),
        ("Sparkline", Sparkline([1.0]), nothing),
        ("BarChart", BarChart(["A" => 1.0]), nothing),
        (
            "Canvas",
            Canvas(context -> canvas_point!(context, 0.5, 0.5)),
            nothing,
        ),
        (
            "Chart",
            Chart([ChartDataset([(0.0, 0.0), (1.0, 1.0)])]),
            nothing,
        ),
        ("Histogram", Histogram([1.0]; bins=1), nothing),
        ("Heatmap", Heatmap(reshape([1.0], 1, 1)), nothing),
        ("Calendar", Calendar(2026, 7), nothing),
        ("Spinner", Spinner(), SpinnerState()),
        ("LoadingIndicator", LoadingIndicator(), LoadingIndicatorState()),
        ("RichText", RichText("rich"), nothing),
        (
            "ScrollView",
            ScrollView(Label("content"); height=2, width=8),
            ScrollState(),
        ),
        (
            "Scrollbar",
            Scrollbar(VerticalScrollbar, 10, 2),
            ScrollState(),
        ),
        ("Digits", Digits(123), nothing),
        (
            "ValidationMessage",
            ValidationMessage([ValidationIssue(:required, "Required")]),
            nothing,
        ),
        let form = Form([FormField(:name; label="Name", initial="")])
            ("ValidationSummary", ValidationSummary(form, FormState(form)), nothing)
        end,
        ("Link", Link("Documentation", :open_docs), LinkState()),
        (
            "ManagedNotificationView",
            ManagedNotificationView(NotificationManager()),
            nothing,
        ),
        ("Placeholder", Placeholder("No data"), nothing),
        ("Skeleton", Skeleton(), SkeletonState()),
        ("EmptyState", EmptyState("No data"), nothing),
        ("Pretty", Pretty((status=:ready, count=1)), nothing),
        ("Progress", Progress(0.5), ProgressState()),
        ("ProgressBar", ProgressBar(ratio=0.5), ProgressBarState()),
        let content = TabbedContent([
                ContentPage(:one, "One", Label("content")),
            ])
            ("TabbedContentView", TabbedContentView(), content)
        end,
        ("Gauge", Gauge(0.5), nothing),
        ("HelpView", HelpView([KeyHint("q", "Quit")]), nothing),
        ("LineGauge", LineGauge(0.5), nothing),
        ("LogView", LogView(), LogState()),
    ]

    function capture_widget_snapshot(widget, state)
        buffer = Buffer(8, 32)
        state === nothing ?
            render!(buffer, widget, buffer.area) :
            render!(buffer, widget, buffer.area, state)
        canonical = sprint() do io
            for cell in structured_snapshot(buffer)
                for property in propertynames(cell)
                    print(io, property, '=', repr(getproperty(cell, property)), ';')
                end
                println(io)
            end
        end
        return (
            structured_sha256=bytes2hex(SHA.sha256(codeunits(canonical))),
            plain=repr(plain_snapshot(buffer)),
        )
    end

    snapshot_values = Dict{String,NamedTuple{(:structured_sha256,:plain),Tuple{String,String}}}()
    for (name, widget, state) in fixtures
        if state !== nothing && hasmethod(render!, Tuple{Buffer,typeof(widget),Rect})
            snapshot_values["$name/stateful"] = capture_widget_snapshot(widget, state)
            snapshot_values["$name/stateless"] = capture_widget_snapshot(widget, nothing)
        else
            snapshot_values[name] = capture_widget_snapshot(widget, state)
        end
    end

    snapshot_path = joinpath(@__DIR__, "snapshots", "widget_contracts.tsv")
    if get(ENV, "WICKED_WRITE_WIDGET_SNAPSHOTS", "false") == "true"
        mkpath(dirname(snapshot_path))
        open(snapshot_path, "w") do io
            println(io, "widget\tstructured_sha256\tplain")
            for name in sort!(collect(keys(snapshot_values)))
                value = snapshot_values[name]
                println(io, name, '\t', value.structured_sha256, '\t', value.plain)
            end
        end
    else
        @testset "golden structured snapshots" begin
            lines = readlines(snapshot_path)
            @test !isempty(lines)
            @test first(lines) == "widget\tstructured_sha256\tplain"
            expected = Dict{String,NamedTuple{(:structured_sha256,:plain),Tuple{String,String}}}()
            for line in Iterators.drop(lines, 1)
                name, structured_sha256, plain = split(line, '\t'; limit=3)
                expected[name] = (; structured_sha256, plain)
            end
            @test Set(keys(expected)) == Set(keys(snapshot_values))
            for name in sort!(collect(keys(snapshot_values)))
                @test expected[name] == snapshot_values[name]
            end
        end
    end

    for (name, widget, state) in fixtures
        @testset "$name dimensions" begin
            check_dimension_contract(widget, state)
        end
    end

    @testset "NumberInput dimensions" begin
        check_dimension_contract(NumberInput(placeholder="n"), NumberInputState())
    end

    @testset "SearchInput dimensions" begin
        check_dimension_contract(SearchInput(placeholder="Search"), SearchInputState())
    end

    @testset "immediate widgets as toolkit leaves" begin
        for (name, widget, state) in fixtures
            widget isa ToolkitTree && continue
            key = Symbol("toolkit_", lowercase(name))
            element = state === nothing ?
                Element(widget; key, id=key) :
                Element(widget; key, id=key, state_factory=() -> state)
            tree = ToolkitTree(element)
            buffer = Buffer(6, 24)
            @test render!(buffer, tree, buffer.area) === buffer
            semantics = toolkit_semantic_tree(tree)
            @test isempty(filter(
                diagnostic -> diagnostic.severity == :error,
                validate_semantics(semantics),
            ))
            node = semantic_node(semantics, string(key))
            @test node !== nothing
            @test node.bounds !== nothing
        end
    end
end
