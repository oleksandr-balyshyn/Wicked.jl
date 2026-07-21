@testset "keyed declarative collections" begin
    single = keyed(:single, "content")
    @test single isa Element
    @test single.key == :single
    @test single.widget isa Label

    via_do = keyed(:do_key) do
        Button("do")
    end
    @test via_do.key == :do_key
    @test via_do.widget isa Button

    existing = Element(Label("same"); key=:same)
    @test keyed(:same, existing) === existing
    @test_throws ArgumentError keyed(:other, existing)
    @test_throws ArgumentError keyed(nothing, Label("missing"))
    @test_throws ArgumentError keyed(:many, (Label("a"), Label("b")))

    items = [(id=:alpha, label="A"), (id=:beta, label="B")]
    children = keyed_each(items; key=value -> value.id) do value, index, key
        Element(Button("$(index):$(value.label)"); id=key)
    end
    @test [child.key for child in children] == [:alpha, :beta]
    @test [child.id for child in children] == [:alpha, :beta]

    generated = keyed_each((value for value in 1:3); key=identity, item=string)
    @test [child.key for child in generated] == [1, 2, 3]
    @test all(child -> child.widget isa Label, generated)

    @test_throws ArgumentError keyed_each([1, 1]; key=identity, item=string)
    @test_throws ArgumentError keyed_each([1]; key=value -> nothing, item=string)
    @test_throws ArgumentError keyed_each([1]; key=identity, item=value -> ("a", "b"))
    @test_throws ArgumentError keyed_each(
        [1];
        key=identity,
        item=value -> Element(Label("x"); key=:conflict),
    )

    tree = ToolkitTree(column(children...))
    frame = Frame(Buffer(2, 20))
    render_toolkit!(frame, tree)
    alpha_state = element_state(tree, :alpha)
    beta_state = element_state(tree, :beta)

    reordered = keyed_each(reverse(items); key=value -> value.id) do value
        Element(Button(value.label); id=value.id)
    end
    tree.root = column(reordered...)
    render_toolkit!(frame, tree)
    @test element_state(tree, :alpha) === alpha_state
    @test element_state(tree, :beta) === beta_state
    @test isempty(positional_identity_warning_records(tree))
    @test count(
        record -> record.action == ReconciliationMove,
        reconciliation_records(tree),
    ) == 2
end
