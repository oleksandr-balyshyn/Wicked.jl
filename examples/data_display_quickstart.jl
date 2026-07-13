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

buffer = Buffer(27, 86)
render!(buffer, Heading("Data display quickstart"; level=1), Rect(1, 1, 2, 86))

table = Table(
    [TableColumn("Name"), TableColumn("Status")],
    [["Build", "Ready"], ["Test", "Queued"], ["Release", "Blocked"]],
)
table_state = state_for(table)
table_dispatcher = SemanticDispatcher()
register_table_semantic_handlers!(table_dispatcher, :table, table, table_state; viewport_height=5)
render!(buffer, Label("Immediate Table"), Rect(4, 1, 1, 38))
render!(buffer, table, Rect(5, 1, 5, 38), table_state)

data_table = DataTable(rows, columns; width=38, height=5)
data_table_state = state_for(data_table)
loading_table = DataStateView(data_table; status=DataLoading, loading="Loading rows...")
loading_dispatcher = SemanticDispatcher()
register_data_state_view_semantic_handlers!(loading_dispatcher, :loading_table, loading_table)
handle!(data_table_state, data_table, KeyEvent(Key(:down)))
render!(buffer, loading_table, Rect(3, 44, 1, 38))
render!(buffer, Label("DataTable"), Rect(4, 44, 1, 38))
render!(buffer, data_table, Rect(5, 44, 5, 38), data_table_state)

tree = TreeView([
    TreeNode(:project, "Project"; children=[
        TreeNode(:build, "Build"),
        TreeNode(:test, "Test"),
    ]),
])
# Family token: Tree
tree_state = TreeViewState(expanded=[:project])
tree_dispatcher = SemanticDispatcher()
register_tree_view_semantic_handlers!(tree_dispatcher, :tree_view, tree, tree_state; viewport_height=4)
render!(buffer, Label("TreeView"), Rect(11, 1, 1, 38))
render!(buffer, tree, Rect(12, 1, 4, 38), tree_state)

tree_source = CallbackTreeDataSource{String,Symbol}(
    roots=() -> ["Project"],
    children=item -> item == "Project" ? ["Build", "Test"] : String[],
    key=item -> Symbol(item),
)
tree_table = TreeTable(
    tree_source,
    [VirtualTableColumn(:name, "Name"; accessor=item -> item)];
    width=38,
    height=4,
)
tree_table_state = state_for(tree_table)
render!(buffer, Label("TreeTable"), Rect(11, 44, 1, 38))
render!(buffer, tree_table, Rect(12, 44, 4, 38), tree_table_state)

properties = PropertyList(["status" => "ready", "owner" => "ops"]; width=38, height=3)
key_values = KeyValueList(["mode" => "prod", "region" => "eu"]; width=38, height=2)
metadata = MetadataList(["version" => "dev", "profile" => "ci"]; width=38, height=2)
descriptions = DescriptionList(["Build" => "Compile and package", "Release" => "Publish artifacts"]; width=38, height=3)
definitions = DefinitionList(["Widget" => "Renderable UI unit", "State" => "Explicit interaction data"]; width=38, height=2)
property_state = state_for(properties)
key_value_state = state_for(key_values)
metadata_state = state_for(metadata)
description_state = state_for(descriptions)
definition_state = state_for(definitions)
metadata_dispatcher = SemanticDispatcher()
register_property_list_semantic_handlers!(metadata_dispatcher, :properties, properties, property_state)
register_key_value_list_semantic_handlers!(metadata_dispatcher, :key_values, key_values, key_value_state)
register_metadata_list_semantic_handlers!(metadata_dispatcher, :metadata, metadata, metadata_state)
register_description_list_semantic_handlers!(metadata_dispatcher, :descriptions, descriptions, description_state)
register_definition_list_semantic_handlers!(metadata_dispatcher, :definitions, definitions, definition_state)
render!(buffer, Label("PropertyList"), Rect(17, 1, 1, 38))
render!(buffer, properties, Rect(18, 1, 3, 38), property_state)
render!(buffer, Label("DescriptionList"), Rect(17, 44, 1, 38))
render!(buffer, descriptions, Rect(18, 44, 3, 38), description_state)
render!(buffer, Label("DefinitionList"), Rect(22, 1, 1, 38))
render!(buffer, definitions, Rect(23, 1, 2, 38), definition_state)
render!(buffer, Label("KeyValueList"), Rect(22, 44, 1, 38))
render!(buffer, key_values, Rect(23, 44, 2, 38), key_value_state)
render!(buffer, Label("MetadataList"), Rect(25, 44, 1, 38))
render!(buffer, metadata, Rect(26, 44, 2, 38), metadata_state)

snapshot = plain_snapshot(buffer)
@assert occursin("Data display quickstart", snapshot)
@assert occursin("Immediate Table", snapshot)
@assert occursin("DataTable", snapshot)
@assert occursin("Loading rows", snapshot)
@assert occursin("TreeView", snapshot)
@assert occursin("TreeTable", snapshot)
@assert occursin("PropertyList", snapshot)
@assert occursin("KeyValueList", snapshot)
@assert occursin("MetadataList", snapshot)
@assert occursin("DescriptionList", snapshot)
@assert occursin("DefinitionList", snapshot)
@assert occursin("Build", snapshot)
@assert occursin("Ready", snapshot)
@assert occursin("Project", snapshot)
@assert occursin("status", snapshot)
@assert occursin("mode", snapshot)
@assert occursin("version", snapshot)
@assert occursin("Compile and package", snapshot)
@assert occursin("Renderable UI unit", snapshot)

println("data display quickstart example completed")
