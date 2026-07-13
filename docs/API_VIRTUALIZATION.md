# Virtualization API

Virtualized data sources, lists, tables, and trees are part of the stable
`Wicked.API` facade. Use this layer for large local collections, paged remote
data, keyboard and pointer navigation, type-ahead, semantic trees, and table
layout/query state.
`Table`, `Tree`, `PropertyList`, and `KeyValueList` are first-class stable API
surface members that share explicit state, deterministic rendering, and semantic
drill-down for large data flows.

This page contains generated reference documentation for virtual data sources,
collections, rendering, input, and tree behavior.

## Stable widget quickstart

Use the public `Wicked.API` names first. The low-level source, window, rendering,
and input helpers remain available for custom components, but application code
should usually compose `VirtualList`, `VirtualTable`, and `VirtualTree` with
explicit state from `state_for(widget)`:

```julia
using Wicked.API

rows = [(name="build", status="ready"), (name="test", status="queued")]
query_source = QueryDataSource(
    rows;
    key=(row, _) -> row.name,
    query=DataQuery(filters=Dict(:status => "ready"), search="build"),
    search_text=row -> "$(row.name) $(row.status)",
)

list = VirtualList(
    query_source;
    format=VirtualListFormat(item=(row, _) -> "$(row.name) $(row.status)"),
)
list_state = state_for(list)

columns = [
    VirtualTableColumn(:name, "Name"; accessor=row -> row.name),
    VirtualTableColumn(:status, "Status"; accessor=row -> row.status),
]
table = VirtualTable(rows, columns; width=40, height=8)
table_state = state_for(table)

tree_source = CallbackTreeDataSource{String,Symbol}(
    roots=() -> ["project"],
    children=item -> item == "project" ? ["build"] : String[],
    key=item -> Symbol(item),
)
tree = VirtualTree(tree_source; width=40, height=8)
tree_state = state_for(tree)

buffer = Buffer(20, 80)
render!(buffer, list, Rect(1, 1, 5, 40), list_state)
render!(buffer, table, Rect(7, 1, 8, 40), table_state)
render!(buffer, tree, Rect(16, 1, 4, 40), tree_state)
```

Use `register_virtual_list_semantic_handlers!`,
`register_virtual_table_semantic_handlers!`,
`register_data_grid_semantic_handlers!`,
`register_data_table_semantic_handlers!`,
`register_virtual_tree_semantic_handlers!`, and
`register_tree_table_semantic_handlers!` when tests, pilots, or automation need
to drive virtualized data widgets through semantic actions. The handlers map
focus, cursor movement, selection, activation, scroll-into-view, and tree
expand/collapse actions to the same explicit state objects used by keyboard and
pointer input.

`VirtualList` accepts any `AbstractVector` directly and wraps it in a stable keyed
data source. Use `VectorDataSource` for mutable local collections,
`QueryDataSource` for local `DataQuery` search/filter/sort behavior, or another
`AbstractDataSource` when the application needs explicit versions, loading rows,
page refreshes, or failure slots. Wrap any data widget in `DataStateView` when
the application needs a stable screen region for `DataReady`, `DataLoading`,
`DataEmpty`, and `DataError` states. `VirtualTable` shares its state contract
with `DataTable` and `DataGrid`, so table terminology can change without
changing cursor, viewport, and selection state. `VirtualTree` uses
`CallbackTreeDataSource` when children are computed on demand.
Use `query_data_source` to inspect the active local `DataQuery` for a
`QueryDataSource`. The returned query is a defensive copy, so mutating it does
not mutate the source. Use `set_query_search!`, `set_query_filter!`,
`clear_query_filter!`, `toggle_query_sort!`, and `clear_query!` to update local
query state without reconstructing a full `DataQuery`. Use
`data_query_summary`, `data_query_text`, `data_query_markdown`, and
`data_query_tsv` when active search/filter/sort state needs stable diagnostics,
logs, confirmation output, or test evidence. Use `TableLayoutState`
with `toggle_virtual_sort!`, `set_virtual_filter!`, and `set_virtual_search!`
when a table owns the visible query controls, then call
`apply_virtual_table_query!` to push that state into any data source that
supports `set_data_query!`. Use `ColumnVisibilityState` with
`hide_virtual_column!`, `show_virtual_column!`,
`toggle_virtual_column_visibility!`, `visible_virtual_columns`, and
`apply_virtual_column_visibility` when users can hide columns without rebuilding
the table definition. Use `ColumnPinState`, `pin_virtual_column_left!`,
`pin_virtual_column_right!`, `unpin_virtual_column!`,
`pinned_virtual_columns`, and `apply_virtual_column_pinning` when important
columns should stay at the left or right edge of a table projection without
changing the underlying data source or column definitions. Use
`column_pin_snapshot` and `restore_column_pin!` with layout and visibility
snapshots to persist full table preferences between application runs.
Use `table_layout_snapshot`, `restore_table_layout!`,
`column_visibility_snapshot`, and `restore_column_visibility!` to persist table
preferences between application runs, or use `table_preferences_bundle` and
`restore_table_preferences!` when applications need one app-persistable value
for layout, query, visibility, pinning, and action metadata. Use
`apply_table_preferences` to produce the final visible, laid-out, pinned column
projection for `VirtualTable`, `DataTable`, or custom table renderers. Use
`table_preferences_summary`, `table_preferences_text`,
`table_preferences_markdown`, and `table_preferences_tsv` when table preference
bundles need stable diagnostics, logs, confirmation output, or test evidence.
Use `virtual_selection_snapshot` and `restore_virtual_selection!` when
applications need to preserve row cursor, anchor, selected keys, and viewport
position independently from table layout preferences. Use
`virtual_selected_row_records` and `virtual_selected_row_snapshot` when bulk
commands, diagnostics, or persistence need the currently selected visible table
rows with projected cell values. Use `virtual_range_selected_row_records` and
`virtual_range_selected_row_snapshot` when range-selection previews, diagnostics,
or bulk-action confirmation screens need projected table rows before or during
incremental range application. Use `invoke_virtual_range_row_action_batch` when
a confirmed range should invoke a row action over the matching source rows.
Use `virtual_row_action_batch_summary`, `virtual_row_action_batch_text`,
`virtual_row_action_batch_markdown`, and `virtual_row_action_batch_tsv` when
bulk-action outcomes need stable diagnostics, logs, confirmation output, or test
evidence.
Use `VirtualCellEditState`, `begin_virtual_cell_edit!`,
`update_virtual_cell_edit!`, `commit_virtual_cell_edit!`, and
`cancel_virtual_cell_edit!` when editable data tables need a stable edit
lifecycle before the application writes changes back to its own model. Use
`register_virtual_cell_edit_semantic_handlers!` to let pilots begin or update
cell edits through table cell semantic nodes. Use `apply_virtual_cell_edit`
or `apply_virtual_cell_edit!` to apply committed edits to named tuples or
dictionaries before replacing rows in the application data source. Use
`VirtualCellEditHistory`, `record_virtual_cell_edit!`,
`undo_virtual_cell_edit!`, `redo_virtual_cell_edit!`,
`virtual_cell_edit_history_snapshot`, and
`restore_virtual_cell_edit_history!` when editable tables need bounded undo/redo
history that can be persisted with the rest of the table state.
Use `VirtualRowAction`,
`virtual_row_action_menu`, `virtual_row_action_records`,
`virtual_row_action_for_shortcut`, `invoke_virtual_row_action`,
`invoke_virtual_row_action_shortcut`, `invoke_virtual_row_action_batch`,
`virtual_row_action_batch_records`, and
`register_virtual_row_action_semantic_handlers!` when a virtual table needs
per-row commands, context-menu entries, keyboard shortcut dispatch, bulk
operations over selected rows, pilot-accessible row actions, or action metadata
without coupling command behavior to rendering. Use
`register_virtual_row_action_batch_semantic_handlers!` when selected-row bulk
commands should be exposed through the `table-id/selection` semantic node.
Use `VirtualColumnAction`,
`default_virtual_column_actions`, `virtual_column_action_menu`,
`virtual_column_action_records`, `virtual_column_action_for_shortcut`,
`invoke_virtual_column_action`, `invoke_virtual_column_action_shortcut`, and
`register_virtual_column_action_semantic_handlers!` when table headers expose
sort, filter-clear, hide/show, pin-left, pin-right, or unpin commands through
menus or pilot-accessible semantic actions. Use
`virtual_column_action_summary`, `virtual_column_action_text`,
`virtual_column_action_markdown`, and `virtual_column_action_tsv` when header
action outcomes need stable diagnostics, logs, confirmation output, or test
evidence. Filters accept exact values,
collections, sets, callable predicates, or named query filters created with
`query_equals`, `query_contains`, `query_range`, and `query_regex`.

Keep virtual widget state outside render functions, just as with Ratatui-style
stateful widgets. This preserves cursor position, selection, expansion, and
scroll offsets across redraws while keeping rendering deterministic.

```@autodocs
Modules = [
    Wicked.Virtualization,
    Wicked.VirtualAdvanced,
    Wicked.VirtualInput,
    Wicked.VirtualRendering,
    Wicked.VirtualTrees,
]
Private = false
```
