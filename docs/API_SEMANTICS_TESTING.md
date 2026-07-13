# Semantics, Testing, and Diagnostics API

This page contains generated reference documentation for accessibility, semantic
toolkit integration, headless testing, diagnostics, and runtime instrumentation.

The stable testing surface includes `WidgetPilot`, `ToolkitPilot`,
`RuntimePilot`, `pilot_semantic_tree`, `pilot_semantic_snapshot`,
`assert_semantic_snapshot`, `assert_semantic_query`, visual snapshots, semantic
snapshots, virtual time, and query helpers for deterministic application tests.

The stable diagnostics surface covers:

- `RingTraceSink`, `NullTraceSink`, `trace!`, `trace_events`, `clear_traces!`,
  and `with_trace_span` for bounded runtime tracing.
- `FrameMetrics`, `record_frame!`, `record_input!`, `record_command!`,
  `record_dropped_event!`, and `metrics_snapshot` for frame and event counters.
- `DiagnosticsHub`, `begin_frame!`, and `end_frame!` for application-owned
  instrumentation.
- `DeveloperInspector`, `capture_inspector`, `inspector_lines`, and
  `inspector_text` for in-app diagnostics overlays or remote clients.
- `instrumented`, `diagnostics`, `instrument_frame!`, `instrument_event!`,
  `instrument_command!`, `instrument_render!`, `instrument_reconcile!`, and
  `instrument_layout!` for runtime integration.

These APIs are optional. Applications can keep diagnostics disabled with
`NullTraceSink` while preserving the same metrics and inspector contracts.

## Stable testing failures

Headless buffer and snapshot assertions throw `BufferAssertionError`. Catch this
type in custom test harnesses when a failed TUI assertion should be reported with
additional scenario context:

```julia
try
    assert_plain_snapshot(pilot, expected)
catch error
    error isa BufferAssertionError || rethrow()
    @error "TUI snapshot mismatch" scenario error
    rethrow()
end
```

Prefer the assertion helpers over ad hoc string comparison so failures preserve
the same formatting and buffer diagnostics across widget, runtime, and Toolkit
pilots.

## Choose the right pilot

Wicked exposes three stable pilot layers so tests can stay close to the code
being exercised:

| Use case | Stable API | What it owns |
| --- | --- | --- |
| One immediate widget | `WidgetPilot` | Widget, optional widget state, `TestBackend`, terminal, and virtual clock |
| Declarative Toolkit tree | `ToolkitPilot` | `ToolkitTree`, keyed element state, focus, messages, `TestBackend`, terminal, and virtual clock |
| Managed application | `RuntimePilot` | Application model, command queue, subscriptions, injected process executor, `TestBackend`, terminal, and virtual clock |

Use the lowest pilot that covers the behavior under test. Prefer
`WidgetPilot` for widget contracts, `ToolkitPilot` for focus and query-driven
component tests, and `RuntimePilot` when commands, timers, subscriptions, or
application exit are part of the behavior. This keeps tests deterministic and
avoids depending on real terminal modes.

## Stable semantic release contract

Semantic output is part of Wicked's public developer API. For every stable
interactive widget family, release evidence should prove two separate contracts:

- The generated semantic tree has stable node IDs, roles, labels, states, bounds,
  metadata, and advertised actions.
- The matching `register_*_semantic_handlers!` functions are registered and can
  dispatch those actions through `SemanticPilot`, `WidgetPilot`, or
  `ToolkitPilot`.

Snapshots without dispatch evidence are not sufficient for Textual-style
automation parity. Dispatch logs without stable node ID coverage are also not
sufficient, because downstream tests and accessibility adapters need durable
selectors across releases.

## Stable headless testing quickstart

Use pilots when testing application behavior without taking over a real terminal.
`WidgetPilot` drives one immediate widget, `ToolkitPilot` drives a keyed
component tree, and `RuntimePilot` drives a managed application with a
deterministic backend and virtual clock:

```julia
using Wicked.API

button = WidgetPilot(Button("Go", :go); height=3, width=12)
@assert occursin("Go", plain_snapshot(button))

pressed = key!(button, :enter)
@assert pressed.handled
@assert button.state isa ButtonState
@assert occursin("widget:ButtonRole", pilot_semantic_snapshot(button))
pressed_and_released = press!(button, :enter)
@assert pressed_and_released.handled
@assert click!(button, 2, 4).handled

root = column(
    Element(Button("Alpha", :alpha); id=:alpha, key=:alpha, focusable=true),
    Element(Checkbox("Remember"); id=:remember, key=:remember, focusable=true),
)
toolkit = ToolkitPilot(root; height=5, width=24)

alpha = query_one(toolkit; id=:alpha, widget_type=Button)
@assert alpha.state isa ButtonState
@assert assert_query_one(toolkit; id=:alpha, widget_type=Button).id == :alpha
@assert length(assert_query(toolkit; text="Alpha")) == 1
@assert assert_no_query(toolkit; text="Missing") === toolkit
focus_element!(toolkit, :alpha)
@assert focused_element(toolkit) == :alpha
assert_focus(toolkit, :alpha)
assert_no_focus(toolkit, :remember)
wait_for_focus!(toolkit, :alpha)
wait_for_no_focus!(toolkit, :remember)

key!(toolkit, :enter)
@assert !isempty(wait_messages!(toolkit))
assert_messages(toolkit, messages(toolkit))
drained = take_messages!(toolkit)
@assert isempty(messages(toolkit))
@assert !isempty(drained)
assert_running(toolkit)
request_exit!(toolkit, :done)
@assert pilot_exited(toolkit)
@assert exit_result(toolkit) == :done
assert_exited(toolkit; result=:done)
wait_for_exit!(toolkit; result=:done)
tree = pilot_semantic_tree(toolkit; label="Example")
@assert isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(tree)))
@assert occursin("alpha:ButtonRole", pilot_semantic_snapshot(toolkit; label="Example"))
@assert query_one_semantic(tree; role=ButtonRole).id == "alpha"
node = query_one_semantic(toolkit, SemanticQuery(id=:alpha, role=ButtonRole); label="Example")
@assert node.id == "alpha"
```

Snapshot helpers work directly with buffers and pilots:

```julia
assert_plain_snapshot(button, plain_snapshot(button))
assert_structured_snapshot(button, structured_snapshot(button))
assert_svg_snapshot(button, svg_snapshot(button))
bundle = snapshot_bundle(button)
@assert bundle.source_kind == :widget_pilot
@assert bundle.plain == plain_snapshot(button)
assert_snapshot_bundle(button, bundle)
assert_semantic_snapshot(toolkit, pilot_semantic_snapshot(toolkit; label="Example"); label="Example")
assert_semantic_query(toolkit, SemanticQuery(id=:alpha, role=ButtonRole); label="Example")
assert_no_semantic_query(toolkit, SemanticQuery(id=:missing); label="Example")
cell = assert_cell(button, 1, 1)
toolkit_cell = assert_cell(toolkit, 1, 1)
```

Pilot input helpers use the same names across `WidgetPilot`, `ToolkitPilot`, and
`RuntimePilot`: `key!`, `press!`, `type_text!`, `paste!`, `mouse!`, `click!`,
`double_click!`, `right_click!`, `hover!`, `drag!`, `scroll_up!`,
`scroll_down!`, `resize_terminal!`, and `advance_time!`.
Use `wait_until!(pilot, predicate)` and `wait_for_text!(pilot, text)` when a
test should advance deterministic virtual time until a condition is true instead
of sleeping. `wait_for_text!` works with immediate widgets, managed runtime
pilots, and Toolkit component trees.
Use `wait_for_plain_snapshot!(pilot, expected)` when the full visible text frame
must match exactly after deterministic time advances.
Use `wait_for_ansi_snapshot!(pilot, expected)` when style-sensitive ANSI output
must match exactly after deterministic time advances.
Use `wait_for_structured_snapshot!(pilot, expected)` when cell-level structured
output must match exactly after deterministic time advances.
Use `wait_for_svg_snapshot!(pilot, expected)` when visual SVG output must match
exactly after deterministic time advances.
Use `wait_for_snapshot_bundle!(pilot, bundle)` when every deterministic visual
artifact in a previously captured bundle must match after time advances.
Use `wait_for_snapshot_bundle_where!(pilot, predicate)` when the condition is a
predicate over the whole bundle, such as checking only `plain` or only the SVG.
Use `wait_for_cell!(pilot, row, column; grapheme=..., style=...)` when the
condition should target a specific cell using the same property names as
`assert_cell`.
Use `wait_for_buffer!(pilot, predicate)` when the condition should inspect the
whole rendered `Buffer` directly.
Use `assert_buffer(pilot, predicate)` for the matching immediate assertion form
when no time advance is needed.
Use `wait_for_query!(toolkit; id=..., widget_type=...)`,
`wait_query!(toolkit; text=...)`, or `wait_query_one!(toolkit; id=...)` with
`ToolkitPilot` when a retained component query should match after deterministic
redraws.
Use `wait_for_no_query!(toolkit; ...)` when a retained component should
disappear after events, filters, validation, or navigation.
Use `assert_query(toolkit; ...)`, `assert_query_one(toolkit; ...)`, or
`assert_no_query(toolkit; ...)` when the query should be checked immediately and
reported as a stable assertion failure.
Use `focused_element(toolkit)`, `assert_focus(toolkit, id)`, and
`wait_for_focus!(toolkit, id)` when tests should inspect or wait for retained
Toolkit focus directly. Use `assert_no_focus(toolkit, id)` and
`wait_for_no_focus!(toolkit, id)` for blur, navigation, modal dismissal, and
focus-restoration checks.
Use `messages(toolkit)` to inspect queued component messages without clearing
them, `take_messages!(toolkit)` to drain the queue, `assert_messages(toolkit,
expected)`, `assert_message(toolkit, predicate)`, or
`assert_no_messages(toolkit)` for immediate message assertions, and
`wait_for_message!(toolkit, predicate)`, `wait_messages!(toolkit)`, or
`wait_for_no_messages!(toolkit)` when messages should change after deterministic
time advances.
Use `pilot_exited(pilot)`, `exit_result(pilot)`, `assert_running(pilot)`,
`wait_for_running!(pilot)`, `assert_exited(pilot; result=...)`, and
`wait_for_exit!(pilot; result=...)` for Toolkit and runtime lifecycle
assertions.
Use `pilot_status(pilot)` when diagnostics or release evidence need one compact
record containing virtual time, pending scheduled callbacks, exit state, and
exit result. Use `pilot_status_text(pilot)` for logs and
`pilot_status_tsv(pilot)` or `pilot_status_markdown(pilot)` for simple CI
artifacts.
Use `pilot_evidence_bundle(pilot)` when evidence should include both
`PilotStatus` and the current `SnapshotBundle`. Use `pilot_evidence_text`,
`pilot_evidence_tsv`, or `pilot_evidence_markdown` when a CI log or release
artifact needs a compact status-plus-snapshot summary.
Use `pilot_evidence_summary(pilot)` when dashboards need one immutable status
record plus snapshot artifact counts and total bytes. Render it with
`pilot_evidence_summary_text`, `pilot_evidence_summary_tsv`, or
`pilot_evidence_summary_markdown`.
Use `pilot_evidence_artifact_summary(directory)` to read the same compact
summary back from a saved evidence directory after CI has uploaded or restored
the artifacts. Non-`nothing` exit results are preserved as their persisted text
representation.
Use `write_pilot_evidence_bundle(directory, pilot; overwrite=true)` to write
status summaries and snapshot artifacts into one evidence directory.
The top-level `manifest.txt` records byte counts and SHA-256 digests for
`status.*` and `evidence.*` files; `read_pilot_evidence_manifest_records`
returns those records as typed `SnapshotArtifactRecord` values. Use
`pilot_evidence_manifest_records`, `pilot_evidence_manifest`,
`pilot_evidence_manifest_tsv`, or `pilot_evidence_manifest_markdown` when a
dashboard needs the expected top-level evidence manifest before writing
artifacts. Use `pilot_evidence_artifact_manifest_tsv(directory)` or
`pilot_evidence_artifact_manifest_markdown(directory)` to render the same
metadata from saved artifacts.
Use `pilot_evidence_report_artifacts(bundle)` or
`write_pilot_evidence_reports(directory, bundle)` to produce derived
`manifest.tsv`, `manifest.md`, `summary.txt`, `summary.tsv`, and `summary.md`
files for release dashboards.
Use `verify_pilot_evidence_report_artifacts(directory)` to check that a report
directory contains the required report files, and
`assert_pilot_evidence_report_artifacts(directory, bundle)` to compare report
contents with a known evidence bundle.
Use `pilot_evidence_report_manifest_records`,
`pilot_evidence_report_manifest_tsv`, and
`pilot_evidence_report_manifest_markdown` when dashboards need byte counts and
digests for generated report files before writing them. Use
`read_pilot_evidence_report_manifest_records`,
`pilot_evidence_report_artifact_manifest_tsv`, or
`pilot_evidence_report_artifact_manifest_markdown` to read the same metadata
from saved report directories.
Use `pilot_evidence_report_summary`,
`pilot_evidence_report_summary_text`, `pilot_evidence_report_summary_tsv`, and
`pilot_evidence_report_summary_markdown` when dashboards need compact report
artifact totals before writing reports. Use
`pilot_evidence_report_artifact_summary`,
`pilot_evidence_report_artifact_summary_text`,
`pilot_evidence_report_artifact_summary_tsv`, or
`pilot_evidence_report_artifact_summary_markdown` to render the same totals from
saved report directories.
`pilot_evidence_report_artifacts(evidence_directory)` and
`write_pilot_evidence_reports(report_directory, evidence_directory)` produce the
same reports from already-saved evidence.
Use `write_pilot_evidence_package(directory, bundle)` when CI should upload one
artifact root containing strict `evidence/` files and derived `reports/` files.
Use `verify_pilot_evidence_package(directory)` or
`assert_pilot_evidence_package_artifacts(directory, bundle)` to check that both
subdirectories are present, that reports match the saved evidence directory, and
that the package-relative manifest matches the expected evidence bundle when
provided.
Use `pilot_evidence_package_summary`,
`pilot_evidence_package_summary_text`, `pilot_evidence_package_summary_tsv`, and
`pilot_evidence_package_summary_markdown` when dashboards need compact totals
for the full package before writing it. Use
`pilot_evidence_package_report_artifacts` or
`write_pilot_evidence_package_reports` when dashboards need separate
package-level `package-manifest.*` and `package-summary.*` report files. Use
`pilot_evidence_package_report_manifest_records`,
`pilot_evidence_package_report_manifest_tsv`,
`pilot_evidence_package_report_manifest_markdown`,
`pilot_evidence_package_report_summary`, and its text, TSV, or Markdown
renderers when dashboards need metadata for package-level reports before writing
them. Use
`verify_pilot_evidence_package_report_artifacts(directory)` or
`assert_pilot_evidence_package_report_artifacts(directory, package_directory)`
to verify those package-level report files after CI writes them. Use
`read_pilot_evidence_package_report_manifest_records`,
`pilot_evidence_package_report_artifact_manifest_tsv`,
`pilot_evidence_package_report_artifact_manifest_markdown`,
`pilot_evidence_package_report_artifact_summary`, and its text, TSV, or
Markdown renderers when dashboards need metadata about the written
package-level report directory itself. Use
`pilot_evidence_package_manifest_records`,
`pilot_evidence_package_manifest_tsv`, and
`pilot_evidence_package_manifest_markdown` when dashboards need package-relative
file digests for the full package before writing it. Use
`read_pilot_evidence_package_manifest_records`,
`pilot_evidence_package_artifact_manifest_tsv`, or
`pilot_evidence_package_artifact_manifest_markdown` to inspect the same metadata
from a saved package directory. Use
`pilot_evidence_package_artifact_summary`,
`pilot_evidence_package_artifact_summary_text`,
`pilot_evidence_package_artifact_summary_tsv`, or
`pilot_evidence_package_artifact_summary_markdown` to render the same totals
from a saved package directory.
Keep these report files separate from the strict evidence directory, or verify
the original directory with `allow_extra=true`.
Use `verify_pilot_evidence_bundle(directory)` to check that the required
top-level status and evidence files exist and that the nested `snapshots/`
directory passes snapshot manifest verification. Use
`assert_pilot_evidence_bundle_artifacts(directory, bundle)` when a saved
evidence directory must match an expected `PilotEvidenceBundle`. Both helpers
reject unexpected top-level files and unexpected nested snapshot files by
default; pass `allow_extra=true` for shared CI artifact directories.
`ToolkitPilot` also supports the same deterministic snapshot waits as
`WidgetPilot`: `wait_for_plain_snapshot!`, `wait_for_ansi_snapshot!`,
`wait_for_structured_snapshot!`, `wait_for_svg_snapshot!`,
`wait_for_snapshot_bundle!`, and `wait_for_snapshot_bundle_where!`.
Use `wait_for_buffer!(pilot, predicate)` and
`wait_for_cell!(pilot, row, column; grapheme=..., style=...)` with
`WidgetPilot`, `ToolkitPilot`, or `RuntimePilot` when the wait condition needs
direct access to rendered cells.
Wait timeouts report the pilot type, timeout step, and final virtual clock time
to make CI failures easier to diagnose.
Use `wait_for_semantic!(pilot, SemanticQuery(...))` with `WidgetPilot` or
`ToolkitPilot` when the condition should be expressed through stable semantic
roles, IDs, values, or actions instead of visible text.
Use `wait_for_no_semantic!(pilot, SemanticQuery(...))` when semantic output
should disappear after deterministic redraws.
Use `wait_query_semantics!(pilot, query)` when the test needs the matching nodes
after waiting.
Use `wait_query_one_semantic!(pilot, query)` when the selector must resolve to
exactly one semantic node after waiting.
Use `snapshot_bundle(source)` when CI or release evidence should archive plain
text, ANSI, structured cell data, and SVG output from the same rendered frame.
Use `assert_snapshot_bundle(source, bundle)` to compare a newly rendered frame
against a previously captured bundle.
Use `snapshot_bundle_manifest_records(bundle)` when dashboards need typed file
name, byte count, and SHA-256 metadata without parsing `manifest.txt`.
`SnapshotBundle` and `SnapshotArtifactRecord` use value equality so records read
back from saved artifacts can be compared directly with expected metadata.
Use `snapshot_bundle_manifest_tsv(bundle)` when release tooling needs a stable
tabular artifact for logs or dashboards.
Use `snapshot_bundle_manifest_markdown(bundle)` when CI logs or release notes
need a human-readable table.
Use `write_snapshot_bundle(directory, source; overwrite=true)` to create a
reviewable artifact directory containing `plain.txt`, `ansi.txt`,
`structured.txt`, `frame.svg`, and `manifest.txt`. The manifest records the
source kind plus byte counts and SHA-256 digests for every payload file, so CI
artifacts can be checked for accidental drift or truncation.
Use `verify_snapshot_bundle_artifacts(directory)` to check written files against
their manifest, and `assert_snapshot_bundle_artifacts(directory, bundle)` to
check a directory against an expected bundle. Both reject unexpected extra files
by default; pass `allow_extra=true` when checking a shared artifact directory.
Use `read_snapshot_bundle_manifest_records(directory)` to recover typed
`SnapshotArtifactRecord` values from an artifact directory after CI has saved or
uploaded it.
Use `snapshot_bundle_summary(bundle)` or
`snapshot_bundle_artifact_summary(directory)` when dashboards only need source
kind, artifact count, and total byte count.
Use `snapshot_artifact_summary_text`, `snapshot_artifact_summary_tsv`, or
`snapshot_artifact_summary_markdown` to render that compact summary for logs and
release notes.
Use `snapshot_bundle_report_artifacts(bundle)` or
`write_snapshot_bundle_reports(directory, bundle)` to produce derived
`manifest.tsv`, `manifest.md`, `summary.txt`, `summary.tsv`, and `summary.md`
files for dashboards. Keep these report files separate from the strict artifact
directory, or verify the original directory with `allow_extra=true`.
Use `snapshot_bundle_artifact_manifest_tsv(directory)` or
`snapshot_bundle_artifact_manifest_markdown(directory)` to render metadata from
a saved artifact directory without reconstructing the original bundle.

Use `assert_plain_snapshot`, `assert_ansi_snapshot`,
`assert_snapshot_bundle`, `assert_structured_snapshot`, `assert_svg_snapshot`,
`assert_buffer`, and `assert_semantic_snapshot` when failures should report
stable assertion errors through `BufferAssertionError`. Text and ANSI snapshot
failures identify the
first differing line and column; structured snapshot failures identify the first
differing cell index; bundle failures identify the differing artifact field.
Use `assert_semantic_query(source, query;
count=1)` when the test should assert the exact number of semantic query
matches, or `assert_semantic_query(source, query; minimum=2)` for lower-bound
assertions over repeated UI regions. Use
`assert_semantic_query(source, query; maximum=1)` to guard against duplicate
semantic nodes. `count`, `minimum`, and `maximum` are assertion options, not
`SemanticQuery` filters. For `SemanticTree` and `SemanticPilot`, all other
keyword arguments construct the query directly, such as
`assert_semantic_query(tree; role=ButtonRole)`. For `WidgetPilot` and
`ToolkitPilot`, pass an explicit `SemanticQuery` so remaining keywords can
configure `pilot_semantic_tree`.
Use `assert_no_semantic_query(source, query)` as the readable negative assertion
form for hidden, removed, or filtered semantic nodes.
Semantic assertion mismatches include the source kind, such as `WidgetPilot`,
`ToolkitPilot`, `SemanticPilot`, or `SemanticTree`.

`pilot_semantic_tree` and `pilot_semantic_snapshot` work with both
`WidgetPilot` and `ToolkitPilot`. `assert_semantic_snapshot` accepts a
`SemanticTree`, `WidgetPilot`, or `ToolkitPilot` as the source, and accepts
either a snapshot string or another `SemanticTree` as the expected value.
`assert_semantic_query` accepts `SemanticTree`, `SemanticPilot`, `WidgetPilot`,
or `ToolkitPilot` as the source. Keyword arguments such as `label=` are
forwarded only when the source snapshot or query is built from a rendering
pilot; pass a fully built tree when you need exact semantic-tree control.

`query_semantics` and `query_one_semantic` also accept `WidgetPilot` and
`ToolkitPilot` with an explicit `SemanticQuery`. This keeps headless tests close
to Textual-style automation APIs while still using the same semantic tree
validation path as release evidence.
For raw `SemanticTree` values, use keyword queries such as
`query_one_semantic(tree; role=ButtonRole)` or
`query_semantics(tree; id="submit", enabled=true, focusable=true)` when
constructing an explicit `SemanticQuery` would add noise. Text filters include
`label`, `description`, and `value` with exact string or regex matching. Use
`bounds=SemanticRect(row, column, width, height)` for exact semantic bounds
matching. Use `action=ActivateSemanticAction` for one required action or
`actions=[ActivateSemanticAction, FocusSemanticAction]` when a node must expose
all listed actions. State filters include `focusable`, `focused`, `selected`,
`expanded`, `checked`, `enabled`, `busy`, `hidden`, `invalid`, `readonly`,
`required`, `value_now`, `value_min`, and `value_max`. Use
`metadata=Dict(:key => value)` for exact metadata matching, and keep `predicate`
for complex matching such as geometry containment. Hidden nodes are excluded by
default; use `hidden=true` or `include_hidden=true` when a test intentionally
targets hidden semantics.
`SemanticQuery` display output lists the active filters, which keeps failed test
logs readable.
`SemanticPilot` supports the same query forms against its current tree, so
accessibility action tests can locate nodes before calling
`perform_semantic_action!`.
When `query_one_semantic` does not match exactly one node, `SemanticQueryError`
reports the compact `SemanticQuery`, match count, and matching semantic IDs when
available.

Use `RuntimePilot` when the code under test needs the managed runtime command
loop, timers, tasks, resize handling, and exit behavior. Advance virtual time
explicitly instead of sleeping:

```julia
pilot = RuntimePilot(MyApp(); height=24, width=80)
assert_model(pilot, model -> model.ready == false)
send!(pilot, :refresh)
assert_command(pilot, RefreshCommand)
wait_for_model!(pilot, model -> model.ready)
wait_for_command!(pilot, NoCommand)
advance_time!(pilot, 0.5)
resize_terminal!(pilot, 30, 100)
```

Use `pilot_model(pilot)` for non-destructive model inspection,
`assert_model(pilot, predicate)` for immediate model-state checks, and
`wait_for_model!(pilot, predicate)` when commands, timers, or tasks should move
the managed model to a later state.
Use `last_command(pilot)`, `assert_command(pilot, CommandType)`, and
`wait_for_command!(pilot, predicate)` when tests need to inspect command effects
without reaching into `RuntimePilot` fields.
Use `runtime_queue(pilot)`, `processed_messages(pilot)`,
`assert_runtime_queue(pilot, expected)`, `assert_no_runtime_queue(pilot)`,
`wait_for_runtime_queue!(pilot, predicate)`, and `wait_runtime_queue!(pilot)` to
inspect managed runtime message queues without reaching into fields.
Use `assert_processed_messages(pilot, expected)`,
`assert_no_processed_messages(pilot)`, and
`wait_for_processed_messages!(pilot, predicate)` when tests need to prove which
runtime messages have already been handled.
Use `pending_scheduled(pilot)`, `assert_pending_scheduled(pilot, count)`, and
`wait_for_pending_scheduled!(pilot, count)` for timer and delay assertions
without reaching into the pilot clock.
Use `virtual_time_ns(pilot)`, `assert_virtual_time(pilot, timestamp_ns)`, and
`wait_for_virtual_time!(pilot, timestamp_ns)` for deterministic clock
assertions without reaching into the pilot clock.

```@autodocs
Modules = [
    Wicked.Accessibility,
    Wicked.SemanticToolkit,
    Wicked.Testing,
    Wicked.Diagnostics,
    Wicked.RuntimeDiagnostics,
]
Private = false
```
