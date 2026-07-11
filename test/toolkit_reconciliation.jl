struct ReconciliationWidget
    label::String
end

struct ReplacementReconciliationWidget
    label::String
end

function Wicked.render!(
    frame::Frame,
    widget::Union{ReconciliationWidget,ReplacementReconciliationWidget},
    area::Rect,
    state::Base.RefValue{Int},
)
    Wicked.render!(frame, Label(widget.label), area)
end

@testset "Toolkit keyed reconciliation and lifecycle" begin
    function render_tree!(tree; height=3, width=20)
        buffer = Buffer(height, width)
        render_toolkit!(Frame(buffer), tree)
        return buffer
    end

    function tracked_element(
        name,
        mounts,
        unmounts;
        key=name,
        id=name,
        hidden=false,
        widget=ReconciliationWidget(string(name)),
    )
        Element(
            widget;
            key,
            id,
            hidden,
            state_factory=() -> Ref(0),
            on_mount=state -> push!(mounts, name),
            on_unmount=state -> push!(unmounts, name),
        )
    end

    @testset "keyed sibling moves retain state" begin
        mounts = Symbol[]
        unmounts = Symbol[]
        first_root = row(
            tracked_element(:alpha, mounts, unmounts),
            tracked_element(:beta, mounts, unmounts),
        )
        tree = ToolkitTree(first_root)
        render_tree!(tree)
        alpha_state = element_state(tree, :alpha)
        beta_state = element_state(tree, :beta)
        alpha_state[] = 7
        beta_state[] = 9

        tree.root = row(
            tracked_element(:beta, mounts, unmounts),
            tracked_element(:alpha, mounts, unmounts),
        )
        render_tree!(tree)

        @test element_state(tree, :alpha) === alpha_state
        @test element_state(tree, :beta) === beta_state
        @test alpha_state[] == 7
        @test beta_state[] == 9
        @test mounts == [:alpha, :beta]
        @test isempty(unmounts)
    end

    @testset "removal and signature replacement unmount exactly once" begin
        mounts = Symbol[]
        unmounts = Symbol[]
        tree = ToolkitTree(row(
            tracked_element(:alpha, mounts, unmounts),
            tracked_element(:beta, mounts, unmounts),
        ))
        render_tree!(tree)

        tree.root = row(tracked_element(:beta, mounts, unmounts))
        render_tree!(tree)
        @test unmounts == [:alpha]
        @test element_state(tree, :alpha) === nothing

        old_beta = element_state(tree, :beta)
        tree.root = row(tracked_element(
            :beta,
            mounts,
            unmounts;
            widget=ReplacementReconciliationWidget("Beta"),
        ))
        render_tree!(tree)
        @test element_state(tree, :beta) !== old_beta
        @test mounts == [:alpha, :beta, :beta]
        @test unmounts == [:alpha, :beta]
    end

    @testset "hidden subtrees remain mounted and retain state" begin
        mounts = Symbol[]
        unmounts = Symbol[]
        child = tracked_element(:child, mounts, unmounts)
        tree = ToolkitTree(Element(nothing; key=:container, id=:container, children=(child,)))
        render_tree!(tree)
        child_state = element_state(tree, :child)
        child_state[] = 42

        hidden_child = tracked_element(:child, mounts, unmounts)
        tree.root = Element(
            nothing;
            key=:container,
            id=:container,
            hidden=true,
            children=(hidden_child,),
        )
        render_tree!(tree)
        @test element_state(tree, :child) === child_state
        @test child_state[] == 42
        @test isempty(unmounts)

        tree.root = Element(
            nothing;
            key=:container,
            id=:container,
            children=(tracked_element(:child, mounts, unmounts),),
        )
        render_tree!(tree)
        @test element_state(tree, :child) === child_state
        @test mounts == [:child]
        @test isempty(unmounts)
    end

    @testset "invalid descriptions have no lifecycle side effects" begin
        mounts = Symbol[]
        unmounts = Symbol[]
        original = tracked_element(:original, mounts, unmounts)
        tree = ToolkitTree(row(original))
        render_tree!(tree)
        original_state = element_state(tree, :original)

        tree.root = row(
            tracked_element(:first, mounts, unmounts; key=:duplicate),
            tracked_element(:second, mounts, unmounts; key=:duplicate),
        )
        @test_throws ArgumentError render_tree!(tree)
        @test mounts == [:original]
        @test isempty(unmounts)
        @test tree.state.instances[first(values(tree.state.ids))].state === original_state

        tree.root = row(
            tracked_element(:first, mounts, unmounts; id=:same),
            tracked_element(:second, mounts, unmounts; id=:same),
        )
        @test_throws ArgumentError render_tree!(tree)
        @test mounts == [:original]
        @test isempty(unmounts)
    end
end
