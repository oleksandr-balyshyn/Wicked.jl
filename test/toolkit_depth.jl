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
    text_container = Element(nothing; children=("text child",))
    @test only(text_container.children).widget isa Label
    text_buffer = Buffer(1, 12)
    render!(text_buffer, text_container, text_buffer.area)
    @test plain_snapshot(text_buffer) == "text child"

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
