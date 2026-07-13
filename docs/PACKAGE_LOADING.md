# Package loading and precompilation

This guide captures the operational workflow for reliable Wicked.jl startup in development, CI, and shipping applications.

## Why this matters

`Wicked.API` is imported like any regular Julia package module, but startup behavior is heavily affected by project activation, dependencies, and cache state. Use deterministic commands whenever startup time, reproducibility, or first-run failures matter.

Wicked targets Linux terminal environments. Package loading, precompilation, CI,
and release evidence should be gathered on supported Julia versions running on
Linux.

## Canonical load flow

1. Activate the intended environment (`--project` or active default).
2. Resolve dependencies for that environment.
3. (Optional but recommended in CI) precompile caches.
4. Import `Wicked.API` as the production-facing entrypoint.

```julia
using Pkg

Pkg.activate(".")
Pkg.instantiate()
Pkg.precompile()      # recommended for CI/build reproducibility
using Wicked.API
Wicked.API.precompile_stable_workload!()
```

## Useful shell pattern

```sh
julia --project=. --startup-file=no \
  -e 'using Pkg; Pkg.activate("."); Pkg.instantiate(); Pkg.precompile(); using Wicked.API; Wicked.API.precompile_stable_workload!()'
```

Use this in CI or release pipelines when startup latency and deterministic output are required.
For release candidates, archive the command output with
[Package Loading Evidence Record Template](PACKAGE_LOADING_EVIDENCE_TEMPLATE.md)
under [Package Loading Evidence Records](loading-evidence/README.md), then run
`scripts/loading_evidence_audit.jl --require-complete`.

## What precompile changes (and what it does not)

- It precompiles package code and dependencies for the active Julia version + manifest.
- Wicked runs a guarded in-memory precompile workload for common stable APIs:
  geometry, styles, text, buffers, layout containers, immediate-mode rendering,
  default-state widget previews including advanced controls such as
  `Autocomplete`, `ComboBox`, `Combobox`, `DataTable`, `VirtualList`,
  `VirtualTable`, `VirtualTree`, `PasswordInput`, `SearchInput`,
  `Textarea`, `TextField`, `PasswordField`, `TagInput`, `Slider`, `RangeSlider`, and
  `Border`/`Panel`/`Collapsible`/`Accordion`/`Carousel`, plus picker controls such as
  `DatePicker`, `TimePicker`, `DateTimePicker`, `DirectoryPicker`, and
  `MultiFilePicker`, action and selection widgets such as `PushButton`,
  `SplitButton`, `CommandPalette`, `RadioButton`, `RadioBoxList`,
  `RadioGroup`, `RadioSet`, `Select`, `MultiSelect`, `SelectionList`,
  `CheckBoxList`, `OptionList`, `ListBox`, and `TransferList`, feedback widgets such as
  `Badge`, `Status`, `Alert`, `Toast`, `NotificationView`,
  `ManagedNotificationView`, `ValidationMessage`, and `ValidationSummary`,
  utility wrappers such as
  `RichText`, `Static`, `TextView`, `MarkdownView`, `CodeView`, `SyntaxView`,
  `DiffView`, `ErrorView`, `LogView`, `RichLog`, `TerminalView`, `AnsiView`,
  `Hyperlink`, `Link`, `ThemePreview`, `Skeleton`, `EmptyState`, `Progress`, and `LoadingIndicator`,
  visualization widgets such as `Gauge`, `LineGauge`, `Sparkline`,
  `BarChart`, `Chart`, `Plot`, `Histogram`, `Heatmap`, `Calendar`, `Canvas`,
  `Meter`, and `Digits`,
  layout/navigation wrappers such as `Wrap`, `Dock`, `Overlay`, `TitleBar`,
  `StatusBar`, `MenuButton`, `ContextMenu`, `MenuBar`, `NavigationRail`,
  `Breadcrumb`, `Tooltip`, `Modal`, `Window`, `Separator`, `Divider`,
  `DataStateView`, `QueryDataSource`, incremental query helpers and diagnostics,
  `query_equals`, `query_contains`, `query_range`, `query_regex`,
  `data_query_summary`, `data_query_text`, `data_query_markdown`,
  `data_query_tsv`, `apply_virtual_table_query!`, `table_layout_snapshot`,
  `restore_table_layout!`, `table_preferences_bundle`,
  `restore_table_preferences!`, `apply_table_preferences`,
  `table_preferences_summary`, `table_preferences_text`,
  `table_preferences_markdown`, `table_preferences_tsv`, `ColumnVisibilityState`,
  `column_visibility_snapshot`, `restore_column_visibility!`,
  `apply_virtual_column_visibility`, `ColumnPinState`, `column_pin_snapshot`,
  `restore_column_pin!`, `apply_virtual_column_pinning`, `VirtualColumnAction`,
  `virtual_selection_snapshot`, `restore_virtual_selection!`,
  `virtual_selected_row_records`, `virtual_selected_row_snapshot`,
  `virtual_range_selected_row_records`, `virtual_range_selected_row_snapshot`,
  `invoke_virtual_range_row_action_batch`,
  `VirtualCellEditState`, `begin_virtual_cell_edit!`,
  `update_virtual_cell_edit!`, `commit_virtual_cell_edit!`,
  `cancel_virtual_cell_edit!`, `apply_virtual_cell_edit`,
  `apply_virtual_cell_edit!`, `VirtualCellEditHistory`,
  `record_virtual_cell_edit!`, `undo_virtual_cell_edit!`,
  `redo_virtual_cell_edit!`, `virtual_cell_edit_history_snapshot`,
  `restore_virtual_cell_edit_history!`,
  `register_virtual_cell_edit_semantic_handlers!`,
  `default_virtual_column_actions`, `virtual_column_action_menu`,
  `virtual_column_action_records`, `invoke_virtual_column_action`,
  `virtual_column_action_summary`, `virtual_column_action_text`,
  `virtual_column_action_markdown`, `virtual_column_action_tsv`,
  `register_virtual_column_action_semantic_handlers!`,
  column pin and unpin actions,
  `VirtualRowAction`, `VirtualRowActionBatchResult`,
  `virtual_row_action_menu`, `virtual_row_action_records`,
  `virtual_row_action_for_shortcut`, `invoke_virtual_row_action`,
  `invoke_virtual_row_action_shortcut`, `invoke_virtual_row_action_batch`,
  `virtual_row_action_batch_records`, `virtual_row_action_batch_summary`,
  `virtual_row_action_batch_text`, `virtual_row_action_batch_markdown`,
  `virtual_row_action_batch_tsv`, `virtual_column_action_for_shortcut`,
  `invoke_virtual_column_action_shortcut`,
  `register_virtual_row_action_semantic_handlers!`,
  `register_virtual_row_action_batch_semantic_handlers!`, `KeyValueList`,
  `MetadataList`, and `DefinitionList`, Toolkit tree rendering, stylesheet
  parsing/cascade setup, semantic tree construction, reactive signal updates,
  buffer diffing, and the headless backend.
- It does not execute your app state machine, `run(...)`, or domain logic.
- It does not enter raw terminal mode, switch screens, read terminal input, load
  optional dependencies, or start remote transports.
- Loading `Wicked` or `Wicked.API` alone must leave `WickedHTTPWebSocketsExt`
  inactive. HTTP.jl WebSocket methods are activated only after HTTP.jl is loaded
  by an application or an isolated optional-integration test.
- Cache reuse only happens when source/manifest/Julia environment are unchanged.
- On cache misses, Julia recompiles affected modules automatically and replaces stale artifacts.

## Application-specific warmup

The built-in workload covers Wicked's stable first-use path. Applications with
large custom widgets should add their own warmup step in release packaging:

```julia
using Wicked.API

function precompile_dashboard!()
    backend = TestBackend(32, 120)
    terminal = Terminal(backend)
    draw!(terminal) do frame
        render!(frame, Paragraph("dashboard warmup"), frame.area)
    end
    nothing
end

precompile_dashboard!()
```

Keep this warmup deterministic: use in-memory backends, fixed data, and no
network, filesystem, or terminal side effects.

## Operational troubleshooting

1. Confirm active environment and manifest:

```julia
import Pkg
Pkg.status()
Base.active_project()
```

2. Force a clean activation and load in one shot:

```julia
using Pkg
Pkg.activate(".")
Pkg.resolve()
Pkg.instantiate()
Pkg.precompile()
using Wicked.API
```

3. Verify load result:

```julia
import Wicked
isdefined(Wicked, :API)    # true
```

4. If the issue appears cache-related and reproducible:

```sh
rm -rf ~/.julia/compiled
rm -rf ~/.julia/logs
```

Then rerun the bootstrap command above.

## CI/reproducibility profile

- Set threads explicitly to 1 for predictable timings in tests:

```sh
JULIA_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=1 julia --project=. --startup-file=no -e 'using Pkg; Pkg.instantiate(); using Wicked.API'
```

- For release builds, call precompile during packaging and capture `Pkg.status()` output in logs.

## Notes for package developers

- In local editable mode (`Pkg.develop`) keep one local checkout active and restart Julia after source/manifests changes if load errors persist.
- Prefer `using Wicked.API` in application entry code to keep the exported surface reviewed and stable.
- Treat `Wicked.Experimental` as a compatibility namespace, not a normal
  application import path.
