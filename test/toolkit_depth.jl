@testset "Deep declarative toolkit trees" begin
    leaf_state = Ref(7)
    root = Element(
        ReconciliationWidget("deep leaf");
        key=:leaf,
        id=:leaf,
        state_factory=() -> leaf_state,
    )
    container_types = Set{Any}()
    for depth in 1:256
        root = column(root; key=depth, constraints=[Fill(1)])
        push!(container_types, typeof(root))
    end

    @test length(container_types) == 1
    @test root.children isa Vector{Element}
    @test_throws ArgumentError Element(nothing; children=("not an element",))

    tree = ToolkitTree(root)
    frame = Frame(Buffer(1, 40))
    render_toolkit!(frame, tree)
    @test length(tree.state.instances) == 257
    @test element_state(tree, :leaf) === leaf_state

    render_toolkit!(frame, tree)
    @test length(tree.state.instances) == 257
    @test element_state(tree, :leaf) === leaf_state
    @test leaf_state[] == 7
end
