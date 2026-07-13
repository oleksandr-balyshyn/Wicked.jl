# API Reference Overview

This page maps Wicked's public API by responsibility. It is an orientation guide,
not a replacement for Julia-generated docstrings.

Use `Wicked.API` as the default application and extension facade. It contains the
reviewed widget, runtime, Toolkit, backend, testing, graphics, reactive, styling,
and service contracts. `Wicked.Experimental` is retained as a compatibility
namespace and currently has no application-facing experimental bindings.

## Developer route map

Start with the page that matches the style of application or subsystem you are
building:

| Goal | Start here | Why |
| --- | --- | --- |
| Ratatui-style immediate rendering | [Core API](API_CORE.md) and [Immediate Widgets API](API_WIDGETS.md) | Buffers, frames, layout, explicit widget state, and direct `render!` calls. |
| Textual-style component trees | [Toolkit and Reactive API](API_TOOLKIT.md) | Keyed `Element` trees, focus, routed events, semantics, signals, and reactive invalidation. |
| Managed full-screen applications | [Backends and Runtime API](API_BACKENDS_RUNTIME.md) | `WickedApp`, `initialize`, `app_view`, `update!`, commands, subscriptions, terminal lifecycle, and headless runtime pilots. |
| CSS-like styling and themes | [Core API](API_CORE.md) and [Theme Management](THEMES.md) | Stylesheets, selectors, classes, pseudo-state, cascade, `StyleEngine`, theme roles, and theme registries. |
| Forms and advanced controls | [Controls API](API_CONTROLS.md) and [Navigation and Forms API](API_NAVIGATION.md) | Text entry, choices, validation, pickers, menus, dialogs, overlays, file browsers, and state machines. |
| Large data views | [Virtualization API](API_VIRTUALIZATION.md) | `VirtualList`, `VirtualTable`, `VirtualTree`, data sources, windows, selection, and virtual input. |
| Rich developer panes | [Rich Content API](API_RICH_CONTENT.md) | Markdown, code, syntax, diffs, errors, logs, terminal captures, ANSI views, and links. |
| Remote/browser delivery | [Remote Frame Transport](REMOTE_TRANSPORT.md) and [Backends and Runtime API](API_BACKENDS_RUNTIME.md) | `RemoteBackend`, `RemoteSession`, protocol fixtures, browser adapter guidance, and optional HTTP.jl WebSocket integration. |
| Headless tests and accessibility | [Semantics, Testing, and Diagnostics API](API_SEMANTICS_TESTING.md) | `WidgetPilot`, `ToolkitPilot`, `RuntimePilot`, `pilot_semantic_tree`, `pilot_semantic_snapshot`, `assert_semantic_snapshot`, `assert_semantic_query`, snapshots, semantic queries, diagnostics, and virtual time. |
| Cross-cutting app services | [Extensions and Services API](API_EXTENSIONS_SERVICES.md) and [Application Services](APPLICATION_SERVICES.md) | Actions, themes, notifications, progress, overlays, animations, live reload, tracing, and extension ownership. |

For ports from Ratatui, Textual, TamboUI, or Lanterna, use the
[Framework Migration](FRAMEWORK_MIGRATION.md) guide and the
[Porting Cookbook](PORTING_COOKBOOK.md) alongside the
[Component Catalog](COMPONENT_CATALOG.md#public-widget-name-map) and these API
pages.

## Rendering core

Use these types for immediate-mode rendering:

- `Rect`, `Position`, and `Size` describe terminal geometry.
- `Style`, terminal colors, and text modifiers describe cell appearance.
- `Span`, `Line`, and `Text` preserve styled text structure.
- `Cell` and `Buffer` hold the desired terminal image.
- `Frame` provides one render pass and cursor ownership.
- Buffer diffing emits only changed cells through a terminal backend.

Widgets implement `render!` against a `Buffer` or `Frame`. Stateful widgets keep
selection, cursor, scrolling, or animation state in an explicit state object.

## Layout

Wicked supports constraint layout, flex rows and columns, grids, docking, flows,
alignment, padding, margins, and clipping. Layout operates on `Rect` values and does
not depend on a terminal backend.

Use stable external state for resizable split panes, resize handles, and scroll offsets. Virtualized
collections expose viewports rather than allocating one widget per data item.

## Terminal and backends

The terminal lifecycle owns raw mode, alternate-screen entry, cursor visibility,
mouse capture, bracketed paste, focus events, and restoration after failure.

Available backends include ANSI output and deterministic test buffers. Terminal controller types, raw-mode control, terminal sizing errors, and color-level detection are stable for custom backend setup and tests. Stable
graphics capability negotiation supports Unicode fallback plus Kitty and Sixel
image protocols, with `GraphicsLayer` for frame-scoped emission.

`RemoteBackend`, `RemoteSession`, and the remote protocol codec provide stable
structured frame transport for browser, WebSocket, socket, or test adapters.
Use [Remote Frame Transport](REMOTE_TRANSPORT.md) for the protocol lifecycle,
security limits, browser adapter guidance, and HTTP.jl WebSocket extension
workflow.

## Events and interaction

Typed events cover keys, text, paste, mouse input, resize, focus, ticks, and custom
messages. Interaction services provide:

- Stable focus traversal, first/last traversal, directional navigation, hit
  testing, explicit focus clearing, focusability checks, focus-count,
  focus-order, and focus-index introspection, immutable focus snapshots with
  scope-stack and restore-stack metadata plus named-tuple records for modal
  diagnostics, plus scoped focus restoration with deterministic fallback when a restored target is no
  longer visible, enabled, or measurable.
- Key bindings, keybinding diagnostics, and named actions.
- Pointer hit testing and capture.
- Clipboard and OSC 52 integration.
- Drag-and-drop sessions.
- Semantic action dispatch for accessibility tools.

`ActionRegistry` is the stable discoverable behavior layer. An `Action` can appear in a binding map, binding layer, binding stack, command palette, menu, test, or automation client while returning any application-defined command or value. Scoped registrations, deterministic keybinding conflict resolution, explicit invocation statuses, and captured predicate or handler failures are part of the stable developer contract. Use `invoke_action_diagnostics!` and `invoke_key_action_diagnostics!` when a single action or key dispatch should return an `ActionWorkflowDiagnostics` bundle. Use `invoke_selected_action!` to dispatch action IDs returned by menus, command palettes, or custom action pickers while safely accepting `nothing`. Use `invoke_activated_action!` when the application already has the action surface and state and wants activation plus dispatch in one step. Use `invoke_selected_action_diagnostics!` and `invoke_activated_action_diagnostics!` when menus, command palettes, or custom action pickers should return an `ActionWorkflowDiagnostics` bundle directly. Use `invoke_actions!` when a script, test, or workflow should dispatch a sequence of action IDs and collect the resulting invocations. Use `invoke_key_actions!` when a script, test, or workflow should dispatch a sequence of key events through the action registry. Use `invoke_actions_diagnostics!` and `invoke_key_actions_diagnostics!` when a script, test, or automation client should dispatch a workflow and receive one immutable `ActionWorkflowDiagnostics` bundle directly. Use `action_invocation_record` and `action_invocation_text` when logs, inspectors, or tests need stable invocation diagnostics. Use `action_invocation_markdown` and `action_invocation_tsv` when generated artifacts need table output for a dispatch result. Use `action_invocation_records`, `action_invocations_text`, `action_invocations_markdown`, and `action_invocations_tsv` when generated artifacts need workflow-level action invocation diagnostics. Use `ActionWorkflowDiagnostics`, `action_workflow_diagnostics`, `action_workflow_diagnostics_record`, and `action_workflow_diagnostics_text` when inspectors, tests, or automation need one immutable workflow diagnostics bundle with records, summary, issues, and failures. Pass either one `ActionInvocation` or a sequence of invocations to `action_workflow_diagnostics`; use `empty_action_workflow_diagnostics` when an empty activation should still return a diagnostics object. Use `merge_action_workflow_diagnostics` when multiple sub-workflow diagnostics bundles should become one reportable workflow; pass either varargs or a vector of diagnostics bundles. `action_workflow_diagnostics_record` includes aggregate counts plus invocation, issue, and failure records for generated dashboards. Use `action_workflow_diagnostics_invocations` and `action_workflow_diagnostics_records` when reports need the captured dispatches or their stable record form. These accessors return defensive copies for mutable collections so debug panels and tests do not accidentally mutate the diagnostics bundle. Use `search_action_workflow_diagnostics_records`, `search_action_workflow_diagnostics_count`, `search_action_workflow_diagnostics_text`, `search_action_workflow_diagnostics_markdown`, and `search_action_workflow_diagnostics_tsv` when inspectors need filtered dispatch reports from the bundle. Use `action_workflow_diagnostics_summary` and `action_workflow_diagnostics_summary_records` when reports need the bundle status counts without rebuilding the diagnostics object. Use `action_workflow_diagnostics_status_count`, `action_workflow_diagnostics_issue_status_count`, and `action_workflow_diagnostics_failure_status_count` when reports need one status count directly. Use `action_workflow_diagnostics_invoked_count`, `action_workflow_diagnostics_missing_count`, `action_workflow_diagnostics_disabled_count`, and `action_workflow_diagnostics_failed_count` when reports need named status counters. Use `action_workflow_diagnostics_total_count`, `action_workflow_diagnostics_issue_count`, and `action_workflow_diagnostics_failure_count` when reports need aggregate workflow counts directly. Use `action_workflow_diagnostics_summary_text`, `action_workflow_diagnostics_summary_markdown`, and `action_workflow_diagnostics_summary_tsv` when generated reports need rendered status-count output from the bundle. Use `search_action_workflow_diagnostics_summary_records`, `search_action_workflow_diagnostics_summary_count`, `search_action_workflow_diagnostics_summary_text`, `search_action_workflow_diagnostics_summary_markdown`, and `search_action_workflow_diagnostics_summary_tsv` when generated reports need filtered status-count output from the bundle. Use `action_workflow_diagnostics_markdown` and `action_workflow_diagnostics_tsv` when generated artifacts need table output for that workflow bundle. Use `action_workflow_diagnostics_all_invoked`, `action_workflow_diagnostics_failures`, `action_workflow_diagnostics_failure_records`, `action_workflow_diagnostics_failures_text`, `action_workflow_diagnostics_failures_markdown`, `action_workflow_diagnostics_failures_tsv`, `search_action_workflow_diagnostics_failure_records`, `search_action_workflow_diagnostics_failure_count`, `search_action_workflow_diagnostics_failures_text`, `search_action_workflow_diagnostics_failures_markdown`, `search_action_workflow_diagnostics_failures_tsv`, `action_workflow_diagnostics_failure_summary`, `action_workflow_diagnostics_failure_summary_records`, `action_workflow_diagnostics_failure_summary_text`, `action_workflow_diagnostics_failure_summary_markdown`, `action_workflow_diagnostics_failure_summary_tsv`, `search_action_workflow_diagnostics_failure_summary_records`, `search_action_workflow_diagnostics_failure_summary_count`, `search_action_workflow_diagnostics_failure_summary_text`, `search_action_workflow_diagnostics_failure_summary_markdown`, `search_action_workflow_diagnostics_failure_summary_tsv`, `action_workflow_diagnostics_issues`, `action_workflow_diagnostics_issue_records`, `action_workflow_diagnostics_issues_text`, `action_workflow_diagnostics_issues_markdown`, `action_workflow_diagnostics_issues_tsv`, `search_action_workflow_diagnostics_issue_records`, `search_action_workflow_diagnostics_issue_count`, `search_action_workflow_diagnostics_issues_text`, `search_action_workflow_diagnostics_issues_markdown`, `search_action_workflow_diagnostics_issues_tsv`, `action_workflow_diagnostics_issue_summary`, `action_workflow_diagnostics_issue_summary_records`, `action_workflow_diagnostics_issue_summary_text`, `action_workflow_diagnostics_issue_summary_markdown`, `action_workflow_diagnostics_issue_summary_tsv`, `search_action_workflow_diagnostics_issue_summary_records`, `search_action_workflow_diagnostics_issue_summary_count`, `search_action_workflow_diagnostics_issue_summary_text`, `search_action_workflow_diagnostics_issue_summary_markdown`, `search_action_workflow_diagnostics_issue_summary_tsv`, `action_workflow_diagnostics_has_failures`, `action_workflow_diagnostics_has_issues`, `assert_action_workflow_diagnostics_all_invoked`, `assert_action_workflow_diagnostics_no_failures`, and `assert_action_workflow_diagnostics_no_issues` when tests or automation should operate directly on the immutable bundle. Use `action_invocations_all_invoked` and `assert_action_invocations_invoked` when application tests need to verify that every action in a workflow completed successfully. Use `action_invocation_failures`, `action_invocations_any_failed`, and `assert_no_action_invocation_failures` when tests or inspectors need to focus on failed workflow dispatches. Use `action_invocation_issues`, `action_invocations_any_issue`, and `assert_no_action_invocation_issues` when missing, disabled, and failed dispatches should all be treated as workflow issues. Use `action_invocation_issue_records`, `action_invocation_issues_text`, `action_invocation_issues_markdown`, and `action_invocation_issues_tsv` when reports need only non-successful dispatches. Use `action_invocation_issue_summary`, `action_invocation_issue_summary_records`, `action_invocation_issue_summary_text`, `action_invocation_issue_summary_markdown`, and `action_invocation_issue_summary_tsv` when reports need status counts only for non-successful dispatches. Use `search_action_invocation_issue_summary_records`, `search_action_invocation_issue_summary_count`, `search_action_invocation_issue_summary_text`, `search_action_invocation_issue_summary_markdown`, and `search_action_invocation_issue_summary_tsv` when reports need filtered status-count summaries only for non-successful dispatches. Use `action_invocation_summary`, `action_invocation_summary_records`, `action_invocation_summary_text`, `action_invocation_summary_markdown`, and `action_invocation_summary_tsv` when reports need status counts for a sequence of action dispatches. Use `search_action_invocation_records`, `search_action_invocation_count`, `search_action_invocations_text`, `search_action_invocations_markdown`, and `search_action_invocations_tsv` when workflow reports need only matching dispatches. Use `search_action_invocation_summary_records`, `search_action_invocation_summary_count`, `search_action_invocation_summary_text`, `search_action_invocation_summary_markdown`, and `search_action_invocation_summary_tsv` when workflow reports need filtered status-count summaries. Use `action_invocation_invoked`, `action_invocation_missing`, `action_invocation_disabled`, and `action_invocation_failed` for direct status checks without matching on `ActionInvocationStatus`. Use `assert_action_invoked`, `assert_action_missing`, `assert_action_disabled`, and `assert_action_failed` in tests when failures should include compact invocation diagnostics. Use `action_binding_map`, `action_binding_layer`, and `action_binding_stack` to adapt visible enabled actions into immediate, layered, or stacked keybinding APIs. Use `action_footer`, `action_help_lines`, `action_help_text`, and `action_help_view` for shortcut footers and help overlays. Use `action_category_binding_maps`, `action_category_binding_layers`, `action_category_binding_stacks`, `action_category_help_lines`, `action_category_help_text`, `action_category_help_views`, and `action_category_footers` when shortcut help or routing should be grouped by action category. Use `search_action_binding_map`, `search_action_binding_layer`, `search_action_binding_stack`, `search_action_help_lines`, `search_action_help_text`, `search_action_help_view`, and `search_action_footer` when shortcut surfaces should be filtered by the same query semantics as `search_actions`. Use `search_action_category_binding_maps`, `search_action_category_binding_layers`, `search_action_category_binding_stacks`, `search_action_category_help_lines`, `search_action_category_help_text`, `search_action_category_help_views`, and `search_action_category_footers` when filtered shortcut help or routing should still be grouped by action category. Use `action_surface` or `search_action_surface` when an app wants the common binding stack, command palette, menu, help overlay, and shortcut footer surfaces as one ready-to-use bundle. Use `action_category_surfaces` or `search_action_category_surfaces` when each action category needs its own ready-to-use surface bundle. Use `action_command_items` when composing custom palette entries, `action_command_palette` when the registry should produce a ready-to-render command palette, and `action_command_palette_session` when an app wants the palette plus opened `CommandPaletteState` in one call. Use `action_command_sections`, `action_category_command_palettes`, and `action_category_command_palette_sessions` when custom palette UIs need deterministic category sections, one palette per category, or one stateful palette session per category. Use `search_action_command_items`, `search_action_command_palette`, and `search_action_command_palette_session` when command palettes should be filtered by the same query semantics as `search_actions`. Use `search_action_command_sections`, `search_action_category_command_palettes`, and `search_action_category_command_palette_sessions` when filtered palette UIs also need category grouping. Use `action_menu_items` when composing menu widgets, `action_menu` when the registry should produce a ready-to-render menu whose activation returns the selected action ID, and `action_menu_session` when an app wants that menu plus matching `MenuState` in one call. Use `action_menu_sections`, `action_category_menus`, and `action_category_menu_sessions` when an application needs deterministic category-grouped menus or one stateful menu session per category. Use `search_action_menu_items`, `search_action_menu`, `search_action_menu_session`, `search_action_menu_sections`, `search_action_category_menus`, and `search_action_category_menu_sessions` when menus should be filtered by the same query semantics as `search_actions`. Use `action_records`, `action_summary`, `ActionRegistrySnapshot`, `action_registry_snapshot`, `action_registry_snapshot_record`, `ActionRegistryDiagnostics`, `action_registry_diagnostics`, `action_registry_diagnostics_record`, `action_registry_diagnostics_text`, `action_registry_diagnostics_markdown`, `action_registry_diagnostics_tsv`, `action_error_records`, `action_error_summary`, `action_error_summary_records`, `action_error_summary_markdown`, `action_error_summary_tsv`, `action_error_summary_text`, `action_error_records_markdown`, `action_error_records_tsv`, `action_error_text`, `search_action_error_records`, `search_action_error_count`, `search_action_error_records_markdown`, `search_action_error_records_tsv`, `search_action_error_text`, `search_action_error_summary_records`, `search_action_error_summary_count`, `search_action_error_summary_markdown`, `search_action_error_summary_tsv`, `search_action_error_summary_text`, `action_categories`, `action_category_records`, `action_category_records_markdown`, `action_category_records_tsv`, `search_action_categories`, `search_action_category_count`, `search_action_category_records_markdown`, `search_action_category_records_tsv`, `search_actions`, `search_action_count`, `action_records_markdown`, `action_records_tsv`, `search_action_records_markdown`, and `search_action_records_tsv` for debug panels, generated docs, menus, tests, and automation.
Use `binding_key_hints`, `binding_help_json`, `binding_help_markdown`, `binding_help_tsv`,
`binding_layer_help_json`, `binding_layer_help_markdown`,
`binding_layer_help_tsv`, `binding_stack_help_json`,
`binding_stack_help_markdown`, and `binding_stack_help_tsv` when generated docs,
CI artifacts, dashboards, debug panels, shortcut bars, or help overlays need
structured keybinding help.

## Core widgets

For a cross-library mapping from common widget concepts to stable `Wicked.API`
names, see the [Component Catalog](COMPONENT_CATALOG.md#public-widget-name-map).
The stabilization policy for compatibility names is documented in
[API Stabilization](API_STABILIZATION.md#compatibility-widget-names), including
the compatibility widget alias audit script.
Use `AppShell`, `app_shell_dock`, `app_shell_layout`, `app_shell_regions`, and
`app_shell_summary` when applications need a stable high-level shell composed
from title chrome, toolbar, sidebar, body, and footer/status regions.
Use `stable_widget_catalog`, `stable_widget_count`, `stable_widget_names`,
`stable_widget_families`, `stable_widget_family_catalog`,
`stable_widget_family_slugs`,
`widget_catalog_family`, `widget_catalog_family_slug`, `widget_families_text`,
`widget_family_entry`, `widget_family_records`, `widget_family_widgets`,
`widget_family_widget_names`, `widget_family_widget_count`,
`widget_family_catalog_markdown`, `widget_family_catalog_tsv`,
`widget_family_slugs_text`,
`is_stable_widget_family`, `assert_stable_widget_family`, `widget_names_text`, `widget_source_files`,
`widget_source_files_text`, `search_widget_source_files_text`,
`widget_family_summary`, `widget_family_summary_markdown`,
`widget_family_summary_tsv`,
`widget_source_summary`, `widget_source_summary_markdown`,
`widget_source_summary_tsv`, `search_widgets`, `search_widget_count`,
`search_widget_names_text`,
`search_widget_catalog_markdown`, `search_widget_catalog_tsv`, `group_widgets`,
`search_widget_families`, `search_widget_family_count`,
`search_widget_family_catalog_markdown`, `search_widget_family_catalog_tsv`,
`widget_catalog_summary`, `widget_catalog_markdown`, `widget_catalog_records`,
`widget_catalog_tsv`, `is_stable_widget`, `assert_stable_widget`,
`widget_catalog`, `widget_catalog_entry`, `widget_vocabulary`,
`widget_vocabulary_records`, `search_widget_vocabulary`,
`widget_vocabulary_entry`, `widget_vocabulary_widget_names`,
`widget_vocabulary_markdown`, `widget_vocabulary_tsv`,
`widget_coverage_records`,
`widget_coverage_gaps`, `widget_coverage_issue_records`,
`widget_coverage_issue_count`, `widget_coverage_issue_names`,
`widget_coverage_issue_text`, `widget_coverage_issue_markdown`,
`widget_coverage_issue_tsv`, `widget_coverage_complete`,
`assert_widget_coverage_complete`, `widget_coverage_git_metadata`,
`assert_widget_coverage_clean_git`, `widget_coverage_release_ready`,
`assert_widget_coverage_release_ready`,
`widget_coverage_release_status_record`, `widget_coverage_release_status_json`,
`widget_coverage_release_status_text`,
`widget_coverage_summary`,
`widget_coverage_summary_records`, `widget_coverage_summary_markdown`,
`widget_coverage_summary_json`, `widget_coverage_summary_text`,
`widget_coverage_summary_tsv`,
`widget_coverage_records_markdown`, `widget_coverage_gaps_markdown`,
`widget_coverage_records_tsv`, and `widget_coverage_gaps_tsv` when developer tooling needs a
typed list of reviewed widget names, cross-library families, stable family
slugs, implementation sources, stable surfaces, statuses, promotion reasons,
generated Markdown tables, TSV tables, query-filtered exports, or plain
named-tuple records.
`WidgetCatalogEntry` describes one reviewed widget. `WidgetFamilyEntry`
describes one reviewed widget family with display name, stable slug, count, and
widget names.
`WidgetFamilyCloseoutReport`, `widget_family_closeout_reports`,
`widget_family_closeout_gaps`, `widget_family_closeout_summary`,
`widget_family_closeout_complete`, `assert_widget_family_closeout_complete`,
`widget_family_closeout_markdown`, `widget_family_closeout_tsv`,
`widget_family_closeout_json`, `widget_family_closeout_artifacts`,
`widget_family_closeout_artifacts_json`,
`widget_family_closeout_artifacts_text`,
`widget_family_closeout_artifacts_markdown`, and
`widget_family_closeout_artifacts_tsv` expose the family-level documentation,
example, stable API token, precompile token, note, blocker data, and aggregate
readiness from `api/widget_family_evidence.tsv`.
`widget_family_catalog_markdown` and `widget_family_catalog_tsv` accept
`columns=(:family_slug, :count)` or any subset of `:family`, `:family_slug`,
`:count`, and `:widgets`.
Most catalog helpers accept `family="Inputs and controls"`,
`family=:inputs_and_controls`, `family="inputs-and-controls"`, or another value
from `stable_widget_families()` when tooling needs a focused cross-library
slice.
Widget search also indexes `family_slug`, so
`search_widget_catalog_markdown("inputs-and-controls"; columns=(:name, :family_slug))`
returns widgets in that family without requiring a separate family filter.
`widget_catalog_markdown` accepts either one column such as `columns=:name` or a
column collection such as `columns=(:name, :family, :family_slug, :source)`.
`widget_catalog_entry`, `is_stable_widget`, and `assert_stable_widget` accept
widget names, public widget types, and widget instances. Use
`experimental_widget_records` when review tooling needs structured records for
remaining `Wicked.Experimental` bindings, including catalog linkage and the
required promote, qualify, or remove decision.
Use `experimental_widget_record` when one experimental binding should be
inspected directly.
Use `experimental_widget_readiness_record`, `experimental_widget_readiness_text`,
`experimental_widget_ready_for_stable`, and
`assert_experimental_widget_ready_for_stable` when a release or migration flow
needs a ready/blocked assessment.
Use `experimental_widget_records_json`, `experimental_widget_records_markdown`, and
`experimental_widget_records_tsv` when experimental closeout needs
machine-readable or human-readable artifacts. Use
`candidate_widget_count` when release tooling needs a direct count of reviewed
widget catalog entries that are not yet stable on the stable application
surface, and use `candidate_widget_records` when tooling needs the
corresponding name, family, source, surface, status, and reason fields. Use
`candidate_widget_records_json`, `candidate_widget_records_markdown`, and
`candidate_widget_records_tsv` when candidate review needs machine-readable or
human-readable artifacts.
`widget_coverage_records` compares the stable widget catalog with
`api/widget_coverage.tsv`; `widget_coverage_gaps` returns only missing,
incomplete, or source-mismatched evidence rows. Use
`widget_coverage_issue_records`, `widget_coverage_issue_count`,
`widget_coverage_issue_names`, `widget_coverage_issue_text`,
`widget_coverage_issue_markdown`, and `widget_coverage_issue_tsv` to focus on
`:complete`, `:missing_record`, `:source_mismatch`, or `:missing_checks` rows.
Use
`widget_coverage_complete` and `assert_widget_coverage_complete` when tests or
release tooling should treat any gap as a failing condition; assertion failures
include the gap count and a short sample of affected widget names. Use
`widget_coverage_git_metadata` and `assert_widget_coverage_clean_git` when
release tooling should require stable widget coverage evidence to come from a
clean git checkout. Use `widget_coverage_release_ready` and
`assert_widget_coverage_release_ready` when release tooling should enforce both
complete coverage and clean git provenance through one API. Use
`widget_coverage_release_status_record` when dashboards or tests need typed
release-readiness fields. Use `widget_coverage_release_status_json` when
dashboards need a compact machine-readable readiness object. Use
`widget_coverage_release_status_text` when release logs need one compact line
with coverage and git readiness flags. Use the Markdown and TSV renderers when
CI logs, release notes, or stabilization dashboards need a copyable evidence
report. Use `widget_coverage_summary_records`,
`widget_coverage_summary_markdown`, `widget_coverage_summary_json`,
`widget_coverage_summary_text`, and `widget_coverage_summary_tsv` when CI or
release dashboards need compact total, complete, incomplete, issue, and family
counts. Use `widget_stability_reports`, `widget_stability_gaps`,
`widget_stability_summary`, `widget_stability_summary_records`,
`widget_stability_summary_markdown`, `widget_stability_summary_tsv`,
`widget_stability_summary_text`, `widget_stability_complete`, and
`assert_widget_stability_complete` when release tooling needs
promotion-readiness checks that combine stable facade status with behavior
coverage evidence. Use `widget_stabilization_artifacts` when release tooling
needs the complete schema-versioned widget stabilization evidence bundle in one
call: broad status, blockers, closeout artifacts, stability summary, and
family-closeout summary. Use `widget_stabilization_artifacts_json` when
dashboards or CI need that full stabilization evidence bundle as one JSON
document. Use `widget_stabilization_artifacts_text` when release logs need the
same bundle as compact multiline text. Use `widget_stabilization_artifacts_markdown`
and `widget_stabilization_artifacts_tsv` when release review needs the full
bundle as a table artifact. Use `assert_widget_stabilization_artifacts_ready`
when release tooling should return the ready bundle or fail fast with closeout
and blocker counts. Use `widget_stabilization_artifacts_ready` when callers need
the same aggregate bundle readiness as a boolean. Use `widget_stabilization_status_records`,
`widget_stabilization_status_markdown`, and `widget_stabilization_status_tsv`
when promotion closeout needs structured data, Markdown, or TSV artifacts for
candidate widgets, experimental bindings, stability blockers, and family
closeout blockers. Use `widget_stabilization_closeout_records` when tooling
needs one normalized list of remaining experimental bindings and non-stable
catalog candidates. Use `widget_stabilization_closeout_kind_records` and
`widget_stabilization_closeout_kind_count` when review tooling needs only
`:experimental` or `:candidate` closeout work. Use
`widget_stabilization_closeout_kind_complete` and
`assert_widget_stabilization_closeout_kind_complete` when one closeout kind
needs its own boolean or fail-fast gate. Use
`widget_stabilization_closeout_kind_artifacts`,
`widget_stabilization_closeout_kind_json`,
`widget_stabilization_closeout_kind_markdown`,
`widget_stabilization_closeout_kind_tsv`, and
`widget_stabilization_closeout_kind_text` when one closeout kind should be
published as release artifacts or logs. Use
`widget_stabilization_closeout_count` for a direct
numeric threshold over that normalized list. Use
`widget_stabilization_closeout_complete` for a closeout-only boolean gate and
`assert_widget_stabilization_closeout_complete` when that gate should fail fast
with the first remaining records. Use `widget_stabilization_closeout_summary`
and `widget_stabilization_closeout_summary_records` when dashboards need compact
total, experimental, and candidate counts. Use
`widget_stabilization_closeout_summary_json`,
`widget_stabilization_closeout_summary_markdown`, and
`widget_stabilization_closeout_summary_tsv` when those summary counts should be
published as machine-readable or human-readable artifacts. Use
`widget_stabilization_closeout_summary_text` when CI logs need one compact
summary line. Use `widget_stabilization_closeout_status_record`,
`widget_stabilization_closeout_status_text`, and
`widget_stabilization_closeout_status_json` when release tooling needs one
aggregate closeout gate bundle. Use `widget_stabilization_closeout_status_markdown`
and `widget_stabilization_closeout_status_tsv` when that status bundle should be
published as a table artifact. Use `widget_stabilization_closeout_json`,
`widget_stabilization_closeout_markdown`, and
`widget_stabilization_closeout_tsv` when that normalized closeout list should be
published as machine-readable or human-readable artifacts. Use
`widget_stabilization_closeout_text` when CI logs need a compact line per
remaining closeout item. Use `widget_stabilization_closeout_artifacts` when
release tooling needs the complete schema-versioned closeout evidence bundle in
one call. Use
`search_widget_stabilization_closeout_records` and
`search_widget_stabilization_closeout_count` when reviewers need to filter the
unified closeout list by widget name, family, source, status, action, or reason.
Use `search_widget_stabilization_closeout_summary` and
`search_widget_stabilization_closeout_summary_records` when filtered closeout
reviews need compact total, experimental, and candidate counts.
Use `search_widget_stabilization_closeout_summary_json`,
`search_widget_stabilization_closeout_summary_markdown`,
`search_widget_stabilization_closeout_summary_tsv`, and
`search_widget_stabilization_closeout_summary_text` when filtered closeout
summary counts should be published as artifacts or logs.
Use `search_widget_stabilization_closeout_complete` for a filtered closeout
boolean gate and `assert_search_widget_stabilization_closeout_complete` when a
focused closeout review should fail fast with matching records.
Use `search_widget_stabilization_closeout_json`,
`search_widget_stabilization_closeout_markdown`,
`search_widget_stabilization_closeout_tsv`, and
`search_widget_stabilization_closeout_text` when filtered closeout results
should be published as release artifacts or logs. Use
`search_widget_stabilization_closeout_artifacts` when a filtered closeout review
needs records, count, summary, text, Markdown, TSV, and JSON in one
schema-versioned bundle. Use
`widget_stabilization_ready` for a direct boolean
stabilization gate and `assert_widget_stabilization_ready` when blocked
closeout should throw with details. Use `widget_stabilization_blocker_records`
when tooling needs structured blocker categories, counts, and details, and use
`widget_stabilization_blocker_records_json`,
`widget_stabilization_blocker_records_markdown`, or
`widget_stabilization_blocker_records_tsv` to publish those structured records
as machine-readable or review artifacts. Use
`widget_stabilization_blocker_count` for compact threshold checks. Use
`widget_stabilization_blockers_markdown` and
`widget_stabilization_blockers_tsv` when blocked closeout needs a focused
artifact containing only blocker details. Use `widget_surface_release_status_record`,
`widget_surface_release_ready`, `assert_widget_surface_release_ready`,
`widget_surface_release_status_text`, and `widget_surface_release_status_json`
when release tooling needs one combined stable widget-surface gate covering
coverage release readiness, widget stability, and family closeout.

Text and structure:

- Blocks, labels, paragraphs, rules, separators, dividers, badges, alerts, headers, and footers.
- Rich Markdown, `MarkupText`, syntax-highlighted code, links, diffs, logs, and rich
  surfaces. Rich-to-core text and buffer adapters are stable extension points for custom renderers.

Input and selection:

- Buttons, checkboxes, toggles, radio groups, `TextInput`, `SearchInput`,
  `PasswordInput`, text areas, selects, numeric and masked controls, and
  multi-select controls.
- `EditingBuffer` provides stable grapheme-aware insertion, selection, cursor movement, and undo/redo for custom text widgets.
- Autocomplete, combo boxes, tags, numeric and masked input, date/time pickers, and
  color pickers expose stable state machines, validation helpers, render helpers,
  key bindings, semantic nodes, and Toolkit component helpers for custom form controls.
- Lists, tables, trees, tabs, menus, and command palettes.

Navigation and advanced controls:

- Scroll views, split panes, breadcrumbs, collapsibles, accordions, pagination,
  steppers, dialogs, carousels, timelines, and file browsers.
- Sliders, range sliders, scrollbars, breadcrumbs, collapsibles, accordions,
  pagination, steppers, dialogs, and modal stacks expose stable state machines,
  render helpers, key bindings, validation helpers, and semantic adapters for
  custom controls.
- `ContentSwitcher`, `TabbedContent`, and `TabbedContentView` coordinate keyed,
  cached, lazily constructed application pages.
- `OverlayManager` coordinates dialogs, menus, popovers, tooltips, and modal input
  barriers.

Visualization:

- Gauges, line gauges, `ProgressBar`, sparklines, bars, charts, calendars, spinners,
  and braille canvases. Chart datasets, canvas drawing contexts, progress task records, and process results are stable constructor-facing support types.
- `ProgressTracker` adds timed task lifecycle, ETA, aggregation, and immutable
  snapshots above the visual progress widget.

## Virtualization

Virtual list, table, and tree APIs separate data sources, viewports, retained
selection, rendering, and input. Use them when total rows or nodes are substantially
larger than the terminal viewport.

## Declarative Toolkit

Toolkit elements provide stable keys, reconciliation, routed events, focus, screens,
styles, semantics, and component builders above the immediate-mode core.

`ToolkitElementAdapter` connects rich or stateful domain views to Toolkit elements.
Component builders return a visual element and matching semantic tree from one
state snapshot.

## Reactive state

Reactive values, computed values, transactions, effects, subscriptions, bindings, component state, and class bindings support
fine-grained invalidation. The stable reactive toolkit also exposes invalidation queues for render, layout, style, semantics, and subscription refreshes. `ReactiveElement` caches a Toolkit element until its
dependencies change. `ReactiveClassSet` binds style classes to reactive predicates.

Transactions coalesce notifications and restore values and versions after failure.
Dispose reactive elements and class bindings when their Toolkit lifecycle ends.

## Application services

`ApplicationServices` is the stable runtime coordinator for cross-cutting managers:

- `OverlayManager`
- `AnimationManager`
- `ActionRegistry`
- `ThemeRegistry`
- `NotificationManager`
- `LiveReloadManager`
- `ProgressTracker`
- Optional `EventRecorder`

Call `pulse_services!` once per runtime frame or timer. It shares one clock value,
advances animations, polls reload targets, expires notifications, and returns render
reasons. `shutdown_services!` performs bounded lifecycle convergence and trace
sealing.

## Styling and themes

Stylesheets support selectors, classes, pseudo-state, inheritance, specificity, and
cascade resolution. `StyleEngine` owns the current low-level theme and stylesheets.

`ThemeRegistry` adds named light, dark, and high-contrast variants, deterministic
preference selection, live replacement, derived roles, subscriptions, and safe
engine binding. The stylesheet parser, selector model, theme registry events,
theme derivation, role validation, and role-style resolver helpers are stable
developer APIs.

## Animation

`AnimationTrack`, `Keyframe`, easing helpers, and `interpolate_value` are stable building blocks for deterministic animation sampling. `AnimationSpec` adds duration, delay, iteration, direction, replacement key, and essential-motion policy.

`AnimationManager` is pull-driven: call `tick_animations!` with the runtime clock.
It supports pause, resume, cancellation, keyed replacement, reduced motion, disabled
motion, and isolated callback failures.

## Notifications

`NotificationCenter` is the small immediate-mode collection used by
`NotificationView`. `NotificationManager` adds synchronized lifecycle, actions,
deduplication, pause/resume timeout accounting, accessibility announcements, events,
and generation tracking.

Use `notification_component` and `bind_notification_semantics!` for Toolkit and
semantic action integration.

## Development and diagnostics

- `LiveReloadManager` performs debounced, two-phase, runtime-polled asset reloads.
- Reliability boundaries expose stable failure collection, error boundaries, reverse-order resource cleanup, cooperative cancellation, and managed task groups.
- Diagnostics expose frame timing, invalidation, runtime tasks, component state,
  inspector snapshots, and runtime instrumentation hooks.
- `DiagnosticsHub`, `RingTraceSink`, `FrameMetrics`, `DeveloperInspector`, and
  runtime instrumentation helpers provide stable hooks for in-app devtools.
- `EventRecorder`, immutable `EventTrace`, and `ReplayController` provide stable
  recording, snapshots, deterministic replay, overflow policy, and error drains.
- Test backends, pilots, pilot semantic-tree/snapshot helpers, pilot semantic
  queries, `SemanticPilot` queries, keyword semantic-tree queries, semantic
  builders, and snapshots support application tests.
- Extension registries isolate optional integrations from the core package with
  stable dependency resolution, contribution ownership, services, scoped
  activation, and lifecycle cleanup.

## API conventions

- Functions ending in `!` may mutate explicit state or a manager.
- Rendering does not own application state unless a retained manager is explicit.
- User callbacks execute outside manager locks unless their documentation says they
  are pure predicates or interpolators.
- Manager snapshots return copied containers; payload ownership follows the
  documented snapshot policy.
- Injected clocks return monotonic, non-negative nanoseconds.
- Lifecycle handles are manager-local and must be disposed or unbound explicitly.
- Missing IDs return `false` or `nothing` for idempotent lifecycle operations and
  throw `KeyError` when the operation requires an existing target.

## Generated public API

Generated reference documentation is partitioned by responsibility so each page remains navigable and within the documentation size budget:

- [Core API](API_CORE.md)
- [Public API Facades](API_FACADES.md)
- [Immediate Widgets API](API_WIDGETS.md)
- [Backends and Runtime API](API_BACKENDS_RUNTIME.md)
- [Controls API](API_CONTROLS.md)
- [Navigation and Forms API](API_NAVIGATION.md)
- [Rich Content API](API_RICH_CONTENT.md)
- [Graphics API](API_GRAPHICS.md)
- [Toolkit and Reactive API](API_TOOLKIT.md)
- [Semantics, Testing, and Diagnostics API](API_SEMANTICS_TESTING.md)
- [Virtualization API](API_VIRTUALIZATION.md)
- [Extensions and Services API](API_EXTENSIONS_SERVICES.md)
