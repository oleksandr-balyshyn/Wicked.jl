@testset "toolkit reconciliation trace" begin
    child(key, widget) = Element(widget; key, id=key)
    tree = ToolkitTree(
        row(child(:alpha, Label("a")), child(:beta, Label("b")));
        reconciliation_capacity=64,
    )
    frame = Frame(Buffer(1, 20))

    render_toolkit!(frame, tree)
    records = reconciliation_records(tree)
    @test count(record -> record.action == ReconciliationMount, records) == 3
    @test all(record -> record.reason == :new_identity, records)
    @test records[end].path == [(:position, 1), (:key, :beta)]

    clear_reconciliation_trace!(tree)
    tree.root = row(child(:beta, Label("b")), child(:alpha, Label("a")))
    render_toolkit!(frame, tree)
    records = reconciliation_records(tree)
    moves = filter(record -> record.action == ReconciliationMove, records)
    @test length(moves) == 2
    @test Set(record.key for record in moves) == Set((:alpha, :beta))
    @test Set((record.previous_index, record.index) for record in moves) ==
          Set(((1, 2), (2, 1)))
    @test all(record -> record.reason == :keyed_sibling_index_changed, moves)
    @test count(record -> record.action == ReconciliationReuse, records) == 3

    clear_reconciliation_trace!(tree)
    tree.root = row(child(:beta, Label("b")), child(:alpha, Paragraph("a")))
    render_toolkit!(frame, tree)
    replacements = filter(record -> record.action == ReconciliationReplace, reconciliation_records(tree))
    @test length(replacements) == 1
    @test replacements[1].key == :alpha
    @test replacements[1].previous_signature.widget_type <: Label
    @test replacements[1].signature.widget_type <: Paragraph
    @test replacements[1].reason == :signature_changed

    clear_reconciliation_trace!(tree)
    tree.root = row(child(:alpha, Paragraph("a")))
    render_toolkit!(frame, tree)
    unmounts = filter(record -> record.action == ReconciliationUnmount, reconciliation_records(tree))
    @test length(unmounts) == 1
    @test unmounts[1].key == :beta
    @test unmounts[1].reason == :not_seen

    @test clear_reconciliation_trace!(tree) === tree
    @test isempty(reconciliation_records(tree))

    bounded = ToolkitTree(child(:only, Label("x")); reconciliation_capacity=2)
    render_toolkit!(Frame(Buffer(1, 5)), bounded)
    render_toolkit!(Frame(Buffer(1, 5)), bounded)
    @test length(reconciliation_records(bounded)) == 2
    @test reconciliation_records(bounded)[1].sequence < reconciliation_records(bounded)[2].sequence
    disabled = ToolkitTree(child(:off, Label("x")); reconciliation_capacity=0)
    render_toolkit!(Frame(Buffer(1, 5)), disabled)
    @test isempty(reconciliation_records(disabled))
    @test_throws ArgumentError ToolkitState(; reconciliation_capacity=-1)
end

@testset "stateful positional identity warnings" begin
    stateful(id, text=id) = Element(Button(string(text)); id)
    frame = Frame(Buffer(1, 30))

    tree = ToolkitTree(row(stateful(:alpha), stateful(:beta)))
    render_toolkit!(frame, tree)
    @test isempty(positional_identity_warning_records(tree))

    tree.root = row(stateful(:inserted), stateful(:alpha), stateful(:beta))
    render_toolkit!(frame, tree)
    warnings = positional_identity_warning_records(tree)
    @test length(warnings) == 1
    @test warnings[1].change == :insertion
    @test warnings[1].previous_count == 2
    @test warnings[1].count == 3
    @test warnings[1].affected_indices == [1, 2]
    @test warnings[1].reason == :stateful_positional_children_shifted_by_insertion
    @test warnings[1].parent_path == [(:position, 1)]

    clear_positional_identity_warnings!(tree)
    tree.root = row(stateful(:beta), stateful(:alpha), stateful(:inserted))
    render_toolkit!(frame, tree)
    warnings = positional_identity_warning_records(tree)
    @test length(warnings) == 1
    @test warnings[1].change == :reorder
    @test warnings[1].reason == :stateful_positional_children_reordered_without_keys

    clear_positional_identity_warnings!(tree)
    tree.root = row(stateful(:beta), stateful(:alpha))
    render_toolkit!(frame, tree)
    @test only(positional_identity_warning_records(tree)).change == :removal
    @test clear_positional_identity_warnings!(tree) === tree
    @test isempty(positional_identity_warning_records(tree))

    keyed(id) = Element(Button(string(id)); key=id, id)
    keyed_tree = ToolkitTree(row(keyed(:left), keyed(:right)))
    render_toolkit!(frame, keyed_tree)
    keyed_tree.root = row(keyed(:right), keyed(:left))
    render_toolkit!(frame, keyed_tree)
    @test isempty(positional_identity_warning_records(keyed_tree))

    disabled = ToolkitTree(
        row(stateful(:one), stateful(:two));
        positional_identity_warnings=false,
    )
    render_toolkit!(frame, disabled)
    disabled.root = row(stateful(:zero), stateful(:one), stateful(:two))
    render_toolkit!(frame, disabled)
    @test isempty(positional_identity_warning_records(disabled))
end
