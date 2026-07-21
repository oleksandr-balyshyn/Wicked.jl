using Wicked.API

rows = [
    (name="Build", status="Ready"),
    (name="Test", status="Queued"),
    (name="Release", status="Blocked"),
]

columns = [
    VirtualTableColumn(:name, "Name"; accessor=row -> row.name),
    VirtualTableColumn(:status, "Status"; accessor=row -> row.status),
]
row_actions = [
    VirtualRowAction(:open, "Open"; handler=(row, index, key) -> (key, row.name), shortcut="enter"),
    VirtualRowAction(:retry, "Retry"; enabled=row -> row.status != "Ready", shortcut="r"),
]
@assert length(virtual_row_action_menu(row_actions, rows[1], 1; key=:Build)) == 1
@assert first(virtual_row_action_records(row_actions, rows[1], 1; key=:Build)).id == :open
@assert virtual_row_action_for_shortcut(row_actions, "enter", rows[1], 1; key=:Build).id == :open
row_action_result = invoke_virtual_row_action(row_actions, :open, rows[1], 1; key=:Build)
@assert row_action_result.handled
@assert row_action_result.value == (:Build, "Build")
row_shortcut_result = invoke_virtual_row_action_shortcut(row_actions, "enter", rows[1], 1; key=:Build)
@assert row_shortcut_result.handled
row_batch_result = invoke_virtual_row_action_batch(row_actions, :retry, rows; indices=1:length(rows), keys=[:Build, :Test, :Release])
@assert row_batch_result isa VirtualRowActionBatchResult
@assert row_batch_result.requested == 3
@assert row_batch_result.handled == 2
@assert first(virtual_row_action_batch_records(row_batch_result)).handled == false
@assert virtual_row_action_batch_summary(row_batch_result).disabled == 1
@assert occursin("handled", virtual_row_action_batch_text(row_batch_result))
@assert startswith(virtual_row_action_batch_markdown(row_batch_result), "| field | value |")
@assert startswith(virtual_row_action_batch_tsv(row_batch_result), "index\tkey")

query_source = QueryDataSource(
    rows;
    key=(row, _) -> Symbol(row.name),
    query=DataQuery(filters=Dict(:status => "Ready"), search="Build"),
    search_text=row -> "$(row.name) $(row.status)",
)
@assert query_data_source(query_source).search == "Build"
query_summary = data_query_summary(query_data_source(query_source))
@assert query_summary.has_search
@assert occursin("search", data_query_text(query_data_source(query_source)))
@assert startswith(data_query_markdown(query_data_source(query_source)), "| field | value |")
@assert startswith(data_query_tsv(query_data_source(query_source)), "kind\tcolumn")
@assert [row.name for row in fetch_items(query_source, 1:3)] == ["Build"]
clear_query!(query_source)
set_query_search!(query_source, "Test")
@assert [row.name for row in fetch_items(query_source, 1:3)] == ["Test"]
clear_query!(query_source)
set_query_filter!(query_source, :status, "Ready")
set_query_filter!(query_source, :name, query_contains("Build"))
@assert [row.name for row in fetch_items(query_source, 1:3)] == ["Build"]
set_query_filter!(query_source, :name, query_regex(r"Build|Release"))
@assert [row.name for row in fetch_items(query_source, 1:3)] == ["Build"]
set_query_filter!(query_source, :name, query_range(minimum="A", maximum="C"))
@assert [row.name for row in fetch_items(query_source, 1:3)] == ["Build"]
layout = TableLayoutState(columns)
set_virtual_search!(layout, "Build")
set_virtual_filter!(layout, :status, "Ready")
toggle_virtual_sort!(layout, :name)
@assert apply_virtual_table_query!(query_source, layout) === query_source
@assert query_data_source(query_source).search == "Build"
layout_snapshot = table_layout_snapshot(layout)
@assert restore_table_layout!(layout, layout_snapshot) === layout
visibility = ColumnVisibilityState(hidden=[:status])
@assert !virtual_column_visible(visibility, :status)
visible_columns = apply_virtual_column_visibility(columns, layout, visibility)
@assert [column.id for column in visible_columns] == [:name]
visibility_snapshot = column_visibility_snapshot(visibility)
@assert restore_column_visibility!(visibility, visibility_snapshot) === visibility
pinning = ColumnPinState(left=[:name], right=[:status])
@assert virtual_column_pin_position(pinning, :name) == :left
pin_snapshot = column_pin_snapshot(pinning)
@assert restore_column_pin!(pinning, pin_snapshot) === pinning
@assert [column.id for column in apply_virtual_column_pinning(columns, layout, pinning)] == [:name, :status]
column_actions = default_virtual_column_actions()
@assert first(virtual_column_action_records(column_actions, :status, layout; visibility, pinning)).column == :status
@assert virtual_column_action_for_shortcut(column_actions, "s", :status, layout; visibility, pinning).id == :sort
column_shortcut_result = invoke_virtual_column_action_shortcut(column_actions, "s", :status, layout; visibility, pinning)
@assert column_shortcut_result.handled
@assert virtual_column_action_summary(column_shortcut_result).column == :status
@assert occursin("column status", virtual_column_action_text(column_shortcut_result))
@assert startswith(virtual_column_action_markdown(column_shortcut_result), "| field | value |")
@assert startswith(virtual_column_action_tsv(column_shortcut_result), "action\tlabel")
column_action_result = invoke_virtual_column_action(column_actions, :show, :status, layout; visibility, pinning)
@assert column_action_result.handled
pin_action_result = invoke_virtual_column_action(column_actions, :pin_left, :status, layout; visibility, pinning)
@assert pin_action_result.handled
@assert virtual_column_pin_position(pinning, :status) == :left
preferences = table_preferences_bundle(layout; visibility, pinning, column_actions, row_actions)
@assert preferences.query.search == "Build"
@assert table_preferences_summary(preferences).column_action_count == length(column_actions)
@assert occursin("columns", table_preferences_text(preferences))
@assert startswith(table_preferences_markdown(preferences), "| field | value |")
@assert startswith(table_preferences_tsv(preferences), "field\tvalue")
@assert restore_table_preferences!(layout, preferences; visibility, pinning).layout === layout
@assert [column.id for column in apply_table_preferences(columns, layout; visibility, pinning)] == [:name, :status]
show_virtual_column!(visibility, :status)
toggle_virtual_column_visibility!(visibility, :status)
@assert [column.id for column in visible_virtual_columns(columns, visibility)] == [:name]

list = VirtualList(
    query_source;
    width=28,
    height=3,
    format=VirtualListFormat(item=(row, _) -> "$(row.name) $(row.status)"),
)
list_state = state_for(list)
list_dispatcher = SemanticDispatcher()
register_virtual_list_semantic_handlers!(list_dispatcher, :virtual_list, list, list_state)

table = VirtualTable(rows, columns; width=28, height=3)
table_state = state_for(table)
table_state.rows.cursor = 1
push!(table_state.rows.selected, 1)
selection_snapshot = virtual_selection_snapshot(table_state.rows)
@assert restore_virtual_selection!(table_state.rows, selection_snapshot) === table_state.rows
selected_rows = virtual_selected_row_records(table, table_state)
@assert first(selected_rows).cell_values[:name] == "Build"
selected_rows_snapshot = virtual_selected_row_snapshot(table, table_state)
@assert selected_rows_snapshot.count == 1
range_selection = begin_virtual_range_selection(table_state.rows, 2)
range_rows = virtual_range_selected_row_records(table, table_state, range_selection)
@assert [row.index for row in range_rows] == [1, 2]
range_snapshot = virtual_range_selected_row_snapshot(table, table_state, range_selection)
@assert range_snapshot.expected == 2
range_action_result = invoke_virtual_range_row_action_batch(row_actions, :open, table, table_state, range_selection)
@assert range_action_result.handled == 2
cell_edit = VirtualCellEditState()
begin_virtual_cell_edit!(cell_edit, 1, :status; key=:Build, value="Ready")
update_virtual_cell_edit!(cell_edit, "Done"; validator=value -> (!isempty(value), nothing))
cell_edit_snapshot = virtual_cell_edit_snapshot(cell_edit)
@assert restore_virtual_cell_edit!(cell_edit, cell_edit_snapshot) === cell_edit
cell_commit = commit_virtual_cell_edit!(cell_edit)
@assert cell_commit.committed
@assert cell_commit.value == "Done"
@assert apply_virtual_cell_edit(rows[1], cell_commit).status == "Done"
editable_row = Dict(:status => "Ready")
@assert apply_virtual_cell_edit!(editable_row, cell_commit)[:status] == "Done"
edit_history = VirtualCellEditHistory()
@assert record_virtual_cell_edit!(edit_history, cell_commit) === edit_history
edit_history_snapshot = virtual_cell_edit_history_snapshot(edit_history)
@assert restore_virtual_cell_edit_history!(edit_history, edit_history_snapshot) === edit_history
undo_edit = undo_virtual_cell_edit!(edit_history)
@assert undo_edit.value == "Ready"
redo_edit = redo_virtual_cell_edit!(edit_history)
@assert redo_edit.value == "Done"
table_dispatcher = SemanticDispatcher()
register_virtual_table_semantic_handlers!(table_dispatcher, :virtual_table, table, table_state)
register_virtual_row_action_semantic_handlers!(table_dispatcher, :virtual_table, table, table_state, row_actions)
register_virtual_row_action_batch_semantic_handlers!(table_dispatcher, :virtual_table, table, table_state, row_actions)
register_virtual_cell_edit_semantic_handlers!(table_dispatcher, :virtual_table, table, table_state, cell_edit)
register_virtual_column_action_semantic_handlers!(
    table_dispatcher,
    :virtual_table,
    columns,
    layout,
    column_actions;
    visibility,
    pinning,
)

tree_source = CallbackTreeDataSource{String,Symbol}(
    roots=() -> ["Project"],
    children=item -> item == "Project" ? ["Build", "Test"] : String[],
    key=item -> Symbol(item),
)
tree = VirtualTree(tree_source; width=28, height=3)
tree_state = state_for(tree)
expand_virtual_tree!(tree_state, :Project)
tree_dispatcher = SemanticDispatcher()
register_virtual_tree_semantic_handlers!(tree_dispatcher, :virtual_tree, tree, tree_state)

buffer = Buffer(12, 32)
render!(buffer, list, Rect(1, 1, 3, 28), list_state)
render!(buffer, table, Rect(5, 1, 3, 28), table_state)
render!(buffer, tree, Rect(9, 1, 3, 28), tree_state)

snapshot = plain_snapshot(buffer)
@assert occursin("Build Ready", snapshot)
@assert !occursin("Test Queued", snapshot)
@assert occursin("Status", snapshot)
@assert occursin("Project", snapshot)

tree_view = ToolkitTree(column(
    Element(list; id=:virtual_list, key=:virtual_list, state_factory=() -> list_state, focusable=true),
    Element(table; id=:virtual_table, key=:virtual_table, state_factory=() -> table_state, focusable=true),
    Element(tree; id=:virtual_tree, key=:virtual_tree, state_factory=() -> tree_state, focusable=true),
))

render_toolkit!(Frame(Buffer(12, 32)), tree_view)
semantics = toolkit_semantic_tree(tree_view; label="Virtual data")
@assert isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
@assert semantic_node(semantics, "virtual_list").role == ListRole
@assert semantic_node(semantics, "virtual_table").role == TableRole
@assert semantic_node(semantics, "virtual_tree").role == TreeRole
list_pilot = SemanticPilot(semantics; dispatcher=list_dispatcher)
@assert perform_semantic_action!(list_pilot, "virtual_list", IncrementSemanticAction).handled
table_pilot = SemanticPilot(semantics; dispatcher=table_dispatcher)
@assert perform_semantic_action!(table_pilot, "virtual_table", IncrementSemanticAction).handled
semantic_batch_action = perform_semantic_action!(table_pilot, "virtual_table/selection", ActivateSemanticAction; value=:open)
@assert semantic_batch_action.handled
@assert semantic_batch_action.value isa VirtualRowActionBatchResult
semantic_row_action = perform_semantic_action!(table_pilot, "virtual_table/1", ActivateSemanticAction; value=:open)
@assert semantic_row_action.handled
@assert semantic_row_action.value.value == (1, "Build")
semantic_column_action = perform_semantic_action!(table_pilot, "virtual_table/column/status", ActivateSemanticAction; value=:sort)
@assert semantic_column_action.handled
@assert semantic_column_action.value.action == :sort
semantic_cell_edit = perform_semantic_action!(table_pilot, "virtual_table/1/status", SetValueSemanticAction; value="Ready")
@assert semantic_cell_edit.handled
@assert semantic_cell_edit.value.draft == "Ready"
tree_pilot = SemanticPilot(semantics; dispatcher=tree_dispatcher)
@assert perform_semantic_action!(tree_pilot, "virtual_tree", IncrementSemanticAction).handled

println("virtualization quickstart example completed")
