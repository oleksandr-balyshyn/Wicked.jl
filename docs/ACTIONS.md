# Actions

Actions are part of `Wicked.API` and give application behavior one stable name that can be invoked from key
bindings, command palettes, menus, buttons, tests, and automation. They complement
runtime commands: an action decides what should happen in the current context and
may return an `AbstractCommand` for the runtime to execute.

## Register an action

```julia
registry = ActionRegistry()

register_action!(
    registry,
    Action(
        :save,
        "Save",
        context -> save_command(context.data);
        description="Save the active document",
        category="File",
        keywords=["write", "persist"],
        enabled=context -> context.data.dirty,
        bindings=[ActionBinding(:s; modifiers=CTRL)],
    ),
)
```

Handlers and predicates receive an `ActionContext`. The context carries the
application, active screen, focused component, source event, and arbitrary data.
Wicked does not prescribe the handler result, so Elm-style applications may return
commands while retained applications may return messages or domain values.

## Invoke actions

```julia
context = ActionContext(application=app, screen=screen, data=document)
result = invoke_action!(registry, :save, context)
result_diagnostics = invoke_action_diagnostics!(registry, :save, context)
selected_diagnostics = invoke_selected_action_diagnostics!(registry, selected_id, context)
activated_diagnostics = invoke_activated_action_diagnostics!(registry, palette, palette_state, context)
workflow_results = invoke_actions!(registry, [:save, :close], context)
workflow_dispatch_diagnostics = invoke_actions_diagnostics!(registry, [:save, :close], context)
key_diagnostics = invoke_key_action_diagnostics!(registry, event, context)
key_workflow_results = invoke_key_actions!(registry, [event], context)
key_workflow_diagnostics = invoke_key_actions_diagnostics!(registry, [event], context)
result_record = action_invocation_record(result)
result_text = action_invocation_text(result)
result_table = action_invocation_markdown(result)
result_tsv = action_invocation_tsv(result)
workflow_records = action_invocation_records(workflow_results)
workflow_text = action_invocations_text(workflow_results)
workflow_table = action_invocations_markdown(workflow_results)
workflow_tsv = action_invocations_tsv(workflow_results)
workflow_ok = action_invocations_all_invoked(workflow_results)
single_workflow_diagnostics = action_workflow_diagnostics(result)
empty_workflow_diagnostics = empty_action_workflow_diagnostics()
merged_workflow_diagnostics = merge_action_workflow_diagnostics(
    workflow_dispatch_diagnostics,
    key_workflow_diagnostics,
)
merged_dynamic_diagnostics = merge_action_workflow_diagnostics([
    workflow_dispatch_diagnostics,
    key_workflow_diagnostics,
])
workflow_failures = action_invocation_failures(workflow_results)
workflow_failed = action_invocations_any_failed(workflow_results)
workflow_issues = action_invocation_issues(workflow_results)
workflow_has_issues = action_invocations_any_issue(workflow_results)
workflow_issue_records = action_invocation_issue_records(workflow_results)
workflow_issue_text = action_invocation_issues_text(workflow_results)
workflow_issue_table = action_invocation_issues_markdown(workflow_results)
workflow_issue_summary = action_invocation_issue_summary(workflow_results)
workflow_issue_summary_text = action_invocation_issue_summary_text(workflow_results)
matching_issue_summary = search_action_invocation_issue_summary_records(workflow_results, "ActionFailed")
matching_issue_summary_text = search_action_invocation_issue_summary_text(workflow_results, "ActionFailed")
workflow_summary = action_invocation_summary(workflow_results)
workflow_summary_text = action_invocation_summary_text(workflow_results)
workflow_diagnostics = action_workflow_diagnostics(workflow_results)
empty_workflow_ok = action_workflow_diagnostics_all_invoked(ActionInvocation[])
workflow_diagnostics_record = action_workflow_diagnostics_record(workflow_diagnostics)
workflow_diagnostics_bundle_records = action_workflow_diagnostics_bundle_records(
    workflow_dispatch_diagnostics,
    key_workflow_diagnostics,
)
workflow_diagnostics_bundle_table = action_workflow_diagnostics_bundle_records_markdown(
    workflow_dispatch_diagnostics,
    key_workflow_diagnostics,
)
workflow_diagnostics_bundle_text = action_workflow_diagnostics_bundle_records_text(
    workflow_dispatch_diagnostics,
    key_workflow_diagnostics,
)
workflow_diagnostics_bundle_summary = action_workflow_diagnostics_bundle_summary(
    workflow_dispatch_diagnostics,
    key_workflow_diagnostics,
)
workflow_diagnostics_bundle_summary_text = action_workflow_diagnostics_bundle_summary_text(
    workflow_dispatch_diagnostics,
    key_workflow_diagnostics,
)
workflow_diagnostics_bundle_summary_table = action_workflow_diagnostics_bundle_summary_markdown(
    workflow_dispatch_diagnostics,
    key_workflow_diagnostics,
)
workflow_diagnostics_bundles_ok = action_workflow_diagnostics_bundle_all_invoked(
    workflow_dispatch_diagnostics,
    key_workflow_diagnostics,
)
workflow_diagnostics_invocations = action_workflow_diagnostics_invocations(workflow_diagnostics)
workflow_diagnostics_records = action_workflow_diagnostics_records(workflow_diagnostics)
matching_diagnostics_records = search_action_workflow_diagnostics_records(workflow_diagnostics, "save")
matching_diagnostics_count = search_action_workflow_diagnostics_count(workflow_diagnostics, "ActionInvoked")
matching_diagnostics_text = search_action_workflow_diagnostics_text(workflow_diagnostics, "save")
matching_diagnostics_table = search_action_workflow_diagnostics_markdown(workflow_diagnostics, "save")
workflow_diagnostics_summary = action_workflow_diagnostics_summary(workflow_diagnostics)
workflow_invoked_count = action_workflow_diagnostics_status_count(workflow_diagnostics, ActionInvoked)
workflow_issue_failed_count = action_workflow_diagnostics_issue_status_count(workflow_diagnostics, :ActionFailed)
workflow_failed_count = action_workflow_diagnostics_failure_status_count(workflow_diagnostics, "ActionFailed")
workflow_named_invoked_count = action_workflow_diagnostics_invoked_count(workflow_diagnostics)
workflow_named_missing_count = action_workflow_diagnostics_missing_count(workflow_diagnostics)
workflow_named_disabled_count = action_workflow_diagnostics_disabled_count(workflow_diagnostics)
workflow_named_failed_count = action_workflow_diagnostics_failed_count(workflow_diagnostics)
workflow_total_count = action_workflow_diagnostics_total_count(workflow_diagnostics)
workflow_total_issue_count = action_workflow_diagnostics_issue_count(workflow_diagnostics)
workflow_total_failure_count = action_workflow_diagnostics_failure_count(workflow_diagnostics)
workflow_diagnostics_summary_records = action_workflow_diagnostics_summary_records(workflow_diagnostics)
workflow_diagnostics_summary_text = action_workflow_diagnostics_summary_text(workflow_diagnostics)
workflow_diagnostics_summary_table = action_workflow_diagnostics_summary_markdown(workflow_diagnostics)
matching_diagnostics_summary = search_action_workflow_diagnostics_summary_records(workflow_diagnostics, "ActionInvoked")
matching_diagnostics_summary_text = search_action_workflow_diagnostics_summary_text(workflow_diagnostics, "ActionInvoked")
workflow_diagnostics_text = action_workflow_diagnostics_text(workflow_diagnostics)
workflow_diagnostics_table = action_workflow_diagnostics_markdown(workflow_diagnostics)
workflow_diagnostics_tsv = action_workflow_diagnostics_tsv(workflow_diagnostics)
workflow_diagnostics_ok = action_workflow_diagnostics_all_invoked(workflow_diagnostics)
workflow_diagnostics_failures = action_workflow_diagnostics_failures(workflow_diagnostics)
workflow_diagnostics_failure_records = action_workflow_diagnostics_failure_records(workflow_diagnostics)
workflow_diagnostics_failure_text = action_workflow_diagnostics_failures_text(workflow_diagnostics)
workflow_diagnostics_failure_table = action_workflow_diagnostics_failures_markdown(workflow_diagnostics)
matching_diagnostics_failures = search_action_workflow_diagnostics_failure_records(workflow_diagnostics, "ActionFailed")
matching_diagnostics_failures_text = search_action_workflow_diagnostics_failures_text(workflow_diagnostics, "ActionFailed")
workflow_diagnostics_failure_summary = action_workflow_diagnostics_failure_summary(workflow_diagnostics)
workflow_diagnostics_failure_summary_text = action_workflow_diagnostics_failure_summary_text(workflow_diagnostics)
matching_diagnostics_failure_summary = search_action_workflow_diagnostics_failure_summary_records(workflow_diagnostics, "ActionFailed")
matching_diagnostics_failure_summary_text = search_action_workflow_diagnostics_failure_summary_text(workflow_diagnostics, "ActionFailed")
workflow_diagnostics_issues = action_workflow_diagnostics_issues(workflow_diagnostics)
workflow_diagnostics_issue_records = action_workflow_diagnostics_issue_records(workflow_diagnostics)
workflow_diagnostics_issue_text = action_workflow_diagnostics_issues_text(workflow_diagnostics)
workflow_diagnostics_issue_table = action_workflow_diagnostics_issues_markdown(workflow_diagnostics)
matching_diagnostics_issues = search_action_workflow_diagnostics_issue_records(workflow_diagnostics, "ActionFailed")
matching_diagnostics_issues_text = search_action_workflow_diagnostics_issues_text(workflow_diagnostics, "ActionFailed")
workflow_diagnostics_issue_summary = action_workflow_diagnostics_issue_summary(workflow_diagnostics)
workflow_diagnostics_issue_summary_text = action_workflow_diagnostics_issue_summary_text(workflow_diagnostics)
matching_diagnostics_issue_summary = search_action_workflow_diagnostics_issue_summary_records(workflow_diagnostics, "ActionFailed")
matching_diagnostics_issue_summary_text = search_action_workflow_diagnostics_issue_summary_text(workflow_diagnostics, "ActionFailed")
workflow_diagnostics_failed = action_workflow_diagnostics_has_failures(workflow_diagnostics)
workflow_diagnostics_has_issues = action_workflow_diagnostics_has_issues(workflow_diagnostics)
matching_workflow_records = search_action_invocation_records(workflow_results, "ActionInvoked")
matching_workflow_table = search_action_invocations_markdown(workflow_results, "save")
matching_summary = search_action_invocation_summary_records(workflow_results, "ActionInvoked")
matching_summary_text = search_action_invocation_summary_text(workflow_results, "ActionInvoked")

if action_invocation_invoked(result)
    execute(result.value)
end
```

Invocation has explicit `ActionInvoked`, `ActionMissing`, `ActionDisabled`, and
`ActionFailed` outcomes. Predicate and handler failures are captured rather than
thrown through the input loop. Inspect them with `take_action_errors!`.

## Scoped overrides

The global scope is always active. Later active scopes override registrations with
the same action ID.

```julia
register_action!(registry, editor_save; scope=:editor)
activate_action_scope!(registry, :editor)

activate_action_scope!(registry, :dialog)
deactivate_action_scope!(registry, :dialog)
```

Use scopes for screens, modal workflows, and focused component families. Activating
an existing scope moves it to the top of the resolution stack. Registration and
scope changes advance `action_registry_generation`, which integrations can use to
invalidate cached menus or shortcut maps.

## Keyboard bindings

```julia
result = invoke_key_action!(registry, event, ActionContext(event=event, data=document))
map = action_binding_map(registry, context)
matching_map = search_action_binding_map(registry, "save", context)
layer = action_binding_layer(registry, context; name=:actions)
stack = action_binding_stack(registry, context; name=:app, layer=:actions)
matching_layer = search_action_binding_layer(registry, "save", context; name=:matching)
matching_stack = search_action_binding_stack(registry, "save", context; name=:matching, layer=:matching)
help_lines = action_help_lines(registry, context)
help_text = action_help_text(registry, context)
help_view = action_help_view(registry, context)
footer = action_footer(registry, context)
surface = action_surface(registry, context; selected=1)
category_binding_maps = action_category_binding_maps(registry, context)
category_binding_layers = action_category_binding_layers(registry, context)
category_binding_stacks = action_category_binding_stacks(registry, context)
category_help_lines = action_category_help_lines(registry, context)
category_help_text = action_category_help_text(registry, context)
category_help_views = action_category_help_views(registry, context)
category_footers = action_category_footers(registry, context)
category_surfaces = action_category_surfaces(registry, context; selected=1)
matching_help_lines = search_action_help_lines(registry, "save", context)
matching_help_text = search_action_help_text(registry, "save", context)
matching_help_view = search_action_help_view(registry, "save", context)
matching_footer = search_action_footer(registry, "save", context)
matching_surface = search_action_surface(registry, "save", context; selected=1)
matching_category_binding_maps = search_action_category_binding_maps(registry, "save", context)
matching_category_binding_layers = search_action_category_binding_layers(registry, "save", context)
matching_category_binding_stacks = search_action_category_binding_stacks(registry, "save", context)
matching_category_help_lines = search_action_category_help_lines(registry, "save", context)
matching_category_help_text = search_action_category_help_text(registry, "save", context)
matching_category_help_views = search_action_category_help_views(registry, "save", context)
matching_category_footers = search_action_category_footers(registry, "save", context)
matching_category_surfaces = search_action_category_surfaces(registry, "save", context; selected=1)
```

Binding conflicts resolve by combined action and shortcut priority, then action
priority and ID for deterministic behavior. `action_binding_map` adapts currently
visible and enabled actions to Wicked's existing `BindingMap` API.
Use `action_binding_layer` or `action_binding_stack` when actions should be
composed with screen, modal, component, or global bindings through the layered
keybinding system. Use `action_footer`, `action_help_lines`,
`action_help_text`, and `action_help_view` for shortcut footers, help overlays,
and generated keybinding reference sections.
Use `action_category_binding_maps`, `action_category_binding_layers`,
`action_category_binding_stacks`, `action_category_help_lines`,
`action_category_help_text`, `action_category_help_views`, and
`action_category_footers` when shortcut help or routing should be grouped by
action category.
Use `search_action_binding_map`, `search_action_binding_layer`,
`search_action_binding_stack`, `search_action_help_lines`,
`search_action_help_text`, `search_action_help_view`, and
`search_action_footer` when those shortcut surfaces should be filtered by the
same query semantics as `search_actions`.
Use `search_action_category_binding_maps`, `search_action_category_binding_layers`,
`search_action_category_binding_stacks`, `search_action_category_help_lines`,
`search_action_category_help_text`, `search_action_category_help_views`, and
`search_action_category_footers` when filtered shortcut help or routing should
still be grouped by action category.
Use `action_surface` or `search_action_surface` when an app wants the common
binding stack, command palette, menu, help overlay, and shortcut footer surfaces
as one ready-to-use bundle.
Use `action_category_surfaces` or `search_action_category_surfaces` when each
action category needs its own ready-to-use surface bundle.

## Command palette

```julia
palette = action_command_palette(registry, context)
palette_session = action_command_palette_session(registry, context; query="save")
command_sections = action_command_sections(registry, context)
category_palettes = action_category_command_palettes(registry, context)
category_palette_sessions = action_category_command_palette_sessions(registry, context; query="save")
menu_items = action_menu_items(registry, context)
menu = action_menu(registry, context)
menu_session = action_menu_session(registry, context; selected=1)
menu_sections = action_menu_sections(registry, context)
category_menus = action_category_menus(registry, context)
category_menu_sessions = action_category_menu_sessions(registry, context; selected=1)
matching_menu = search_action_menu(registry, "save", context)
matching_menu_session = search_action_menu_session(registry, "save", context; selected=1)
matching_menu_sections = search_action_menu_sections(registry, "File", context)
matching_category_menu_sessions = search_action_category_menu_sessions(registry, "save", context; selected=1)
matching_items = search_action_command_items(registry, "save", context)
matching_palette = search_action_command_palette(registry, "File", context)
matching_palette_session = search_action_command_palette_session(registry, "File", context; palette_query="save")
matching_command_sections = search_action_command_sections(registry, "File", context)
matching_category_palettes = search_action_category_command_palettes(registry, "save", context)
matching_category_palette_sessions = search_action_category_command_palette_sessions(registry, "save", context; palette_query="save")
selected_id = activate(palette, palette_state)
invoke_selected_action!(registry, selected_id, context)
invoke_activated_action!(registry, palette, palette_state, context)
```

Palette items inherit action titles, descriptions, categories, keywords, and
enabled state. Visibility predicates exclude actions that should not be discoverable
in the current screen or focus context.
Use `action_command_palette_session` when an app wants a ready-to-render
`CommandPalette` and opened `CommandPaletteState` in one call, optionally seeded
with the first query.
Use `action_command_items` directly when an application needs to merge action
items with custom command-palette entries before constructing the palette.
Use `action_menu_items` when composing custom menu widgets and `action_menu`
when the registry should produce a ready-to-render menu whose activation returns
the selected action ID.
Use `action_menu_session` when an app wants that menu plus a matching
`MenuState` in one call.
Use `action_menu_sections` and `action_category_menus` when an application needs
top-level or grouped menus generated from action categories.
Use `action_category_menu_sessions` when each generated category menu also needs
an owned `MenuState`.
Use `search_action_menu_items`, `search_action_menu`,
`search_action_menu_session`, `search_action_menu_sections`,
`search_action_category_menus`, and `search_action_category_menu_sessions` for
filtered menus driven by the same query semantics as `search_actions`.
Use `search_action_command_items`, `search_action_command_palette`, and
`search_action_command_palette_session` for filtered command palettes with the
same query semantics.
Use `action_command_sections`, `action_category_command_palettes`,
`action_category_command_palette_sessions`, `search_action_command_sections`,
`search_action_category_command_palettes`, and
`search_action_category_command_palette_sessions` when custom palette UIs need
deterministic category sections or one palette per category.
Use `invoke_selected_action!` when dispatching an action ID returned by
`activate` from a menu, command palette, or custom action picker.
Use `invoke_activated_action!` when the application already has the action
surface and state and wants activation plus dispatch in one step.
Use `invoke_action_diagnostics!` and `invoke_key_action_diagnostics!` when a
single action or key dispatch should return an `ActionWorkflowDiagnostics`
bundle.
Use `invoke_selected_action_diagnostics!` and
`invoke_activated_action_diagnostics!` when menus, command palettes, or custom
action pickers should return an `ActionWorkflowDiagnostics` bundle directly.
Use `invoke_actions_diagnostics!` and `invoke_key_actions_diagnostics!` when a
script, test, or automation client should dispatch a workflow and receive one
immutable `ActionWorkflowDiagnostics` bundle directly.
Use `action_invocation_record` and `action_invocation_text` when logs,
inspectors, or tests need stable invocation diagnostics.
Use `action_invocation_markdown` and `action_invocation_tsv` when generated
artifacts need table output for a dispatch result.
Use `action_invocation_records`, `action_invocations_text`,
`action_invocations_markdown`, and `action_invocations_tsv` when generated
artifacts need workflow-level action invocation diagnostics.
Use `ActionWorkflowDiagnostics`, `action_workflow_diagnostics`,
`action_workflow_diagnostics_record`, and
`action_workflow_diagnostics_text` when inspectors, tests, or automation need
one immutable workflow diagnostics bundle with records, summary, issues, and
failures. Pass either one `ActionInvocation` or a sequence of invocations to
`action_workflow_diagnostics`; use `empty_action_workflow_diagnostics` when an
empty activation should still return a diagnostics object. Use
`merge_action_workflow_diagnostics` when multiple sub-workflow diagnostics
bundles should become one reportable workflow; pass either varargs or a vector
of diagnostics bundles. `action_workflow_diagnostics_record` includes aggregate
counts plus invocation, issue, and failure records for generated dashboards. Use
`action_workflow_diagnostics_bundle_records` when generated reports need one record per
workflow diagnostics bundle. Use `action_workflow_diagnostics_bundle_records_markdown`
`action_workflow_diagnostics_bundle_records_text`, and
`action_workflow_diagnostics_bundle_records_tsv` when generated reports need
compact aggregate output for multiple diagnostics bundles. Use
`action_workflow_diagnostics_bundle_summary` and
`action_workflow_diagnostics_bundle_summary_text` when dashboards need one
aggregate summary across multiple workflow bundles. Use
`action_workflow_diagnostics_bundle_summary_markdown` and
`action_workflow_diagnostics_bundle_summary_tsv` when generated reports need the
same aggregate summary as table output. Use
`action_workflow_diagnostics_bundle_all_invoked`,
`action_workflow_diagnostics_bundle_has_issues`,
`action_workflow_diagnostics_bundle_has_failures`,
`assert_action_workflow_diagnostics_bundle_all_invoked`,
`assert_action_workflow_diagnostics_bundle_no_issues`, and
`assert_action_workflow_diagnostics_bundle_no_failures` when CI or automation
should fail on any problematic sub-workflow bundle. Use
`action_workflow_diagnostics_invocations` and
`action_workflow_diagnostics_records` when reports need the captured dispatches
or their stable record form. These accessors return defensive copies for mutable
collections so debug panels and tests do not accidentally mutate the diagnostics
bundle. Use `search_action_workflow_diagnostics_records`,
`search_action_workflow_diagnostics_count`,
`search_action_workflow_diagnostics_text`,
`search_action_workflow_diagnostics_markdown`, and
`search_action_workflow_diagnostics_tsv` when inspectors need filtered dispatch
reports from the bundle. Use `action_workflow_diagnostics_summary` and
`action_workflow_diagnostics_summary_records` when reports need the bundle's
status counts without rebuilding the diagnostics object. Use
`action_workflow_diagnostics_status_count`,
`action_workflow_diagnostics_issue_status_count`, and
`action_workflow_diagnostics_failure_status_count` when reports need one status
count directly. Use `action_workflow_diagnostics_invoked_count`,
`action_workflow_diagnostics_missing_count`,
`action_workflow_diagnostics_disabled_count`, and
`action_workflow_diagnostics_failed_count` when reports need named status
counters. Use `action_workflow_diagnostics_total_count`,
`action_workflow_diagnostics_issue_count`, and
`action_workflow_diagnostics_failure_count` when reports need aggregate workflow
counts directly. Use
`action_workflow_diagnostics_summary_text`,
`action_workflow_diagnostics_summary_markdown`, and
`action_workflow_diagnostics_summary_tsv` when generated reports need rendered
status-count output from the bundle. Use
`search_action_workflow_diagnostics_summary_records`,
`search_action_workflow_diagnostics_summary_count`,
`search_action_workflow_diagnostics_summary_text`,
`search_action_workflow_diagnostics_summary_markdown`, and
`search_action_workflow_diagnostics_summary_tsv` when generated reports need
filtered status-count output from the bundle. Use
`action_workflow_diagnostics_markdown` and
`action_workflow_diagnostics_tsv` when generated artifacts need table output for
that workflow bundle. Use `action_workflow_diagnostics_all_invoked`,
`action_workflow_diagnostics_failures`,
`action_workflow_diagnostics_failure_records`,
`action_workflow_diagnostics_failures_text`,
`action_workflow_diagnostics_failures_markdown`,
`action_workflow_diagnostics_failures_tsv`,
`search_action_workflow_diagnostics_failure_records`,
`search_action_workflow_diagnostics_failure_count`,
`search_action_workflow_diagnostics_failures_text`,
`search_action_workflow_diagnostics_failures_markdown`,
`search_action_workflow_diagnostics_failures_tsv`,
`action_workflow_diagnostics_failure_summary`,
`action_workflow_diagnostics_failure_summary_records`,
`action_workflow_diagnostics_failure_summary_text`,
`action_workflow_diagnostics_failure_summary_markdown`,
`action_workflow_diagnostics_failure_summary_tsv`,
`search_action_workflow_diagnostics_failure_summary_records`,
`search_action_workflow_diagnostics_failure_summary_count`,
`search_action_workflow_diagnostics_failure_summary_text`,
`search_action_workflow_diagnostics_failure_summary_markdown`,
`search_action_workflow_diagnostics_failure_summary_tsv`,
`action_workflow_diagnostics_issues`,
`action_workflow_diagnostics_issue_records`,
`action_workflow_diagnostics_issues_text`,
`action_workflow_diagnostics_issues_markdown`,
`action_workflow_diagnostics_issues_tsv`,
`search_action_workflow_diagnostics_issue_records`,
`search_action_workflow_diagnostics_issue_count`,
`search_action_workflow_diagnostics_issues_text`,
`search_action_workflow_diagnostics_issues_markdown`,
`search_action_workflow_diagnostics_issues_tsv`,
`action_workflow_diagnostics_issue_summary`,
`action_workflow_diagnostics_issue_summary_records`,
`action_workflow_diagnostics_issue_summary_text`,
`action_workflow_diagnostics_issue_summary_markdown`,
`action_workflow_diagnostics_issue_summary_tsv`,
`search_action_workflow_diagnostics_issue_summary_records`,
`search_action_workflow_diagnostics_issue_summary_count`,
`search_action_workflow_diagnostics_issue_summary_text`,
`search_action_workflow_diagnostics_issue_summary_markdown`,
`search_action_workflow_diagnostics_issue_summary_tsv`,
`action_workflow_diagnostics_has_failures`,
`action_workflow_diagnostics_has_issues`,
`assert_action_workflow_diagnostics_all_invoked`,
`assert_action_workflow_diagnostics_no_failures`, and
`assert_action_workflow_diagnostics_no_issues` when tests or automation should
operate directly on the immutable bundle.
Use `action_invocations_all_invoked` and `assert_action_invocations_invoked`
when application tests need to verify that every action in a workflow completed
successfully.
Use `action_invocation_failures`, `action_invocations_any_failed`, and
`assert_no_action_invocation_failures` when tests or inspectors need to focus on
failed workflow dispatches.
Use `action_invocation_issues`, `action_invocations_any_issue`, and
`assert_no_action_invocation_issues` when missing, disabled, and failed
dispatches should all be treated as workflow issues.
Use `action_invocation_issue_records`, `action_invocation_issues_text`,
`action_invocation_issues_markdown`, and `action_invocation_issues_tsv` when
reports need only non-successful dispatches.
Use `action_invocation_issue_summary`,
`action_invocation_issue_summary_records`,
`action_invocation_issue_summary_text`,
`action_invocation_issue_summary_markdown`, and
`action_invocation_issue_summary_tsv` when reports need status counts only for
non-successful dispatches.
Use `search_action_invocation_issue_summary_records`,
`search_action_invocation_issue_summary_count`,
`search_action_invocation_issue_summary_text`,
`search_action_invocation_issue_summary_markdown`, and
`search_action_invocation_issue_summary_tsv` when reports need filtered
status-count summaries only for non-successful dispatches.
Use `action_invocation_summary`, `action_invocation_summary_records`,
`action_invocation_summary_text`, `action_invocation_summary_markdown`, and
`action_invocation_summary_tsv` when inspectors or generated reports need status
counts for a sequence of action dispatches.
Use `search_action_invocation_records`, `search_action_invocation_count`,
`search_action_invocations_text`, `search_action_invocations_markdown`, and
`search_action_invocations_tsv` when workflow reports need only matching action
dispatches.
Use `search_action_invocation_summary_records`,
`search_action_invocation_summary_count`,
`search_action_invocation_summary_text`,
`search_action_invocation_summary_markdown`, and
`search_action_invocation_summary_tsv` when workflow reports need filtered
status-count summaries.
Use `action_invocation_invoked`, `action_invocation_missing`,
`action_invocation_disabled`, and `action_invocation_failed` for direct status
checks without matching on `ActionInvocationStatus`.
Use `assert_action_invoked`, `assert_action_missing`, `assert_action_disabled`,
and `assert_action_failed` in tests when failures should include compact
invocation diagnostics.

## Diagnostics and generated docs

```julia
records = action_records(registry, context)
summary = action_summary(registry, context)
snapshot = action_registry_snapshot(registry, context)
snapshot_record = action_registry_snapshot_record(snapshot)
diagnostics = action_registry_diagnostics(registry, context)
diagnostics_record = action_registry_diagnostics_record(diagnostics)
diagnostics_table = action_registry_diagnostics_markdown(diagnostics)
diagnostics_text = action_registry_diagnostics_text(diagnostics)
diagnostics_tsv = action_registry_diagnostics_tsv(diagnostics)
categories = action_categories(registry, context)
category_records = action_category_records(registry, context)
category_table = action_category_records_markdown(registry, context; columns=(:category, :count, :actions))
category_tsv = action_category_records_tsv(registry, context; columns=(:category, :enabled, :actions))
matching_categories = search_action_categories(registry, "File", context)
matching_category_table = search_action_category_records_markdown(registry, "save", context; columns=(:category, :actions))
matches = search_actions(registry, "save", context)
match_count = search_action_count(registry, "Ctrl+s", context)
errors = action_error_records(registry)
error_summary = action_error_summary(registry)
error_summary_records = action_error_summary_records(registry)
error_summary_text = action_error_summary_text(registry)
error_table = action_error_records_markdown(registry)
error_text = action_error_text(registry)
matching_errors = search_action_error_records(registry, "ErrorException")
matching_error_text = search_action_error_text(registry, "boom")
matching_error_summary = search_action_error_summary_records(registry, "ErrorException")
matching_error_summary_text = search_action_error_summary_text(registry, "Error")
table = action_records_markdown(registry, context; columns=(:id, :title, :bindings))
tsv = search_action_records_tsv(registry, "save"; columns=(:id, :category))
```

`action_records` returns plain named tuples with action metadata, resolved scope,
state flags, priority, keywords, and shortcut records. `action_summary` returns
compact counts for debug panels, tests, and automation. `ActionRegistrySnapshot`
captures generation, active scopes, action counts, category names, and captured
error count as an immutable diagnostic value. Use
`action_registry_snapshot_record` when logs or tests need plain data.
`ActionRegistryDiagnostics` bundles snapshot, summary, category records, action
records, binding records, and captured errors for inspector panels and snapshot
tests. Use `action_registry_diagnostics_record` when plain data is preferred,
and `action_registry_diagnostics_markdown` or
`action_registry_diagnostics_tsv` for generated diagnostic artifacts. Use
`action_registry_diagnostics_text` for compact human-readable logs and inspector
panels.
`action_categories` and `action_category_records` group visible actions for
menus, command palettes, docs, and inspector panels. `search_actions` and
`search_action_count` find actions by ID, title, description, category, keywords,
scope, or shortcut labels.
Use `action_records_markdown`, `action_records_tsv`,
`search_action_records_markdown`, and `search_action_records_tsv` when generated
documentation or debug exports need table output with selectable columns.
Use `action_category_records_markdown` and `action_category_records_tsv` for
grouped menu or command-palette category exports.
Use `search_action_categories`, `search_action_category_count`,
`search_action_category_records_markdown`, and
`search_action_category_records_tsv` when generated docs or menus need focused
category groups.
Use `action_error_records`, `action_error_summary`,
`action_error_summary_records`, `action_error_summary_markdown`,
`action_error_summary_tsv`, `action_error_summary_text`,
`action_error_records_markdown`, `action_error_records_tsv`, and
`action_error_text` when inspectors, logs, or tests need action failure details.
Use `search_action_error_records`, `search_action_error_count`,
`search_action_error_records_markdown`, `search_action_error_records_tsv`, and
`search_action_error_text` when an inspector or automation client needs only the
failures matching an exception type, message, or captured index.
Use `search_action_error_summary_records`,
`search_action_error_summary_count`, `search_action_error_summary_markdown`,
`search_action_error_summary_tsv`, and `search_action_error_summary_text` when
dashboards need grouped failure counts filtered by exception type or count.
