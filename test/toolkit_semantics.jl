@testset "Toolkit accessibility semantics" begin
    checked = CheckboxState(true)
    input = TextInputState("secret"; focused=false)
    tabs = TabsState(2)
    menu = MenuState(selected=2)
    root = column(
        Element(Button("Save"); id=:save, key=:save, focusable=true),
        Element(Checkbox("Remember"); id=:remember, key=:remember, state_factory=() -> checked, focusable=true),
        Element(
            TextInput(placeholder="Password", mask="*");
            id=:password,
            key=:password,
            state_factory=() -> input,
            focusable=true,
            semantics=SemanticDescriptor(TextboxRole; label="Password"),
        ),
        Element(
            Tabs([:first => "First", :second => "Second"]);
            id=:tabs,
            key=:tabs,
            state_factory=() -> tabs,
            focusable=true,
        ),
        Element(
            Menu([
                MenuItem(:open, "Open"),
                MenuItem(:quit, "Quit"; shortcut="Ctrl+Q"),
            ]);
            id=:menu,
            key=:menu,
            state_factory=() -> menu,
            focusable=true,
        ),
    )
    tree = ToolkitTree(root)
    render_toolkit!(Frame(Buffer(15, 40)), tree)
    semantics = toolkit_semantic_tree(tree; id="demo", label="Demo application", generation=7)

    @test semantics.generation == 7
    @test isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
    @test semantic_node(semantics, "demo").role == ApplicationRole

    save = semantic_node(semantics, "save")
    @test save.role == ButtonRole
    @test save.label == "Save"
    @test save.state.focused
    @test ActivateSemanticAction in save.actions
    @test save.bounds !== nothing

    remember = semantic_node(semantics, "remember")
    @test remember.role == CheckboxRole
    @test remember.state.checked == CheckedValue
    @test ActivateSemanticAction in remember.actions

    password = semantic_node(semantics, "password")
    @test password.role == TextboxRole
    @test password.label == "Password"
    @test password.state.value === nothing

    tabs_node = semantic_node(semantics, "tabs")
    @test tabs_node.role == TabListRole
    @test length(tabs_node.children) == 2
    @test tabs_node.children[2].state.selected
    @test tabs_node.children[2].metadata[:tab_id] == :second

    menu_node = semantic_node(semantics, "menu")
    @test menu_node.role == MenuRole
    @test length(menu_node.children) == 2
    @test menu_node.children[2].role == MenuItemRole
    @test menu_node.children[2].state.selected
    @test menu_node.children[2].description == "Shortcut: Ctrl+Q"

    snapshot = semantic_snapshot(semantics)
    @test occursin("save:ButtonRole label=\"Save\"", snapshot)
    @test occursin("remember:CheckboxRole", snapshot)

    tree.root = Element(
        Button("Hidden");
        id=:hidden_button,
        key=:hidden_button,
        hidden=true,
        focusable=true,
    )
    render_toolkit!(Frame(Buffer(3, 20)), tree)
    hidden_tree = toolkit_semantic_tree(tree)
    hidden = semantic_node(hidden_tree, "hidden_button")
    @test hidden.state.hidden
    @test !hidden.state.focused
    @test !hidden.state.focusable
    @test isempty(hidden.actions)

    custom = Element(
        Button("Internal");
        id=:custom,
        semantics=(widget, state, element) -> SemanticDescriptor(
            ButtonRole;
            label="Public label",
            description="Custom semantics",
        ),
    )
    custom_tree = ToolkitTree(custom)
    render_toolkit!(Frame(Buffer(3, 20)), custom_tree)
    custom_node = semantic_node(toolkit_semantic_tree(custom_tree), "custom")
    @test custom_node.label == "Public label"
    @test custom_node.description == "Custom semantics"
end
