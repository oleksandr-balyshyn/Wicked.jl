# Toolkit and Reactive API

This page contains generated reference documentation for declarative elements,
component composition, reactive state, and toolkit bindings.

## Stable component-author contract

Use `Element` to describe a widget, layout container, or component boundary.
Stable `key` values retain local state across rebuilt descriptions. Stable `id`
values support focus, queries, semantic automation, and retained-state lookup.

`ToolkitTree` is the stable retained shell for declarative applications. It is
not another immediate widget; it owns reconciliation state, focus registration,
mounted element instances, keyed local state, stylesheet state, event dispatch,
and semantic-tree projection for a rebuilt `Element` root. Treat
`ToolkitTree(root)` as the application-side counterpart to Textual's component
tree or TamboUI-style declarative composition, while direct widgets remain
immediate-mode renderables.

The stable Toolkit boundary is:

- Build app views from `Element`, `row`, `column`, `grid`, `stack`, `centered`,
  and `leaf`.
- Keep `key` stable when local state must survive rebuilt views.
- Keep `id` stable when focus, tests, diagnostics, semantic automation, or
  `element_state(tree, id)` need to address an element.
- Render with `render_toolkit!(frame, tree)` or the `render!` overloads for
  `ToolkitTree`.
- Route input through `dispatch!(tree, event)` and return `EventResponse` from
  `on_event` callbacks when an application needs explicit consumed/redraw/focus
  behavior.
- Inspect retained state through `element_instance(tree, id)` for diagnostics
  and `element_state(tree, id)` for normal application code.
- Project accessibility/testing metadata through `toolkit_semantic_tree(tree)`.

Toolkit routes input through `on_event` callbacks after built-in widget handling.
Callbacks receive `RoutedEvent(event, target, current, phase)` and the retained
local state for the current element. `phase` is `TargetPhase` (a.k.a.
`target_phase` / `capture_phase`) for the focused or hit element and `BubblePhase`
(a.k.a. `bubble_phase`) for ancestors.

Toolkit applications can also keep Textual-style screens in a `ScreenStack`.
Use `Screen` with `ReplaceScreen` for normal page replacement and
`OverlayScreen` for stacked overlays. Return `PushScreen`,
`PushRegisteredScreen`, `NavigateRegisteredScreen`, `BackRegisteredScreen`,
`ForwardRegisteredScreen`, `PopScreen`, `PopToScreen`, `ReplaceWithScreen`,
`ReplaceWithRegisteredScreen`, `RemoveScreen`, `ClearOverlayScreens`, and
`ClearScreens` from `toolkit_update!` to mutate the stack through the managed
Toolkit runtime. Use `ScreenRegistry`, `ScreenHistory`, `register_screen!`,
`screen_history_command_palette`, and `screen_history_menu` when back/forward
route history should be exposed through application command surfaces. Use
`screen_registry_binding_map` and `screen_history_binding_map` when routes and
route history should feed shortcut bars, help views, or keybinding resolution.
Prefer snake_case command constructors when porting Textual-like code:
`navigate_registered_screen`, `push_screen`, `push_registered_screen`,
`back_registered_screen`, `forward_registered_screen`, `pop_screen`,
`pop_to_screen`, `replace_with_screen`, `replace_with_registered_screen`,
`remove_screen`, `clear_overlay_screens`, and `clear_screens`.
`screen_route_metadata`, `screen_route_title`, `screen_route_description`,
`screen_route_group`, `screen_route_keywords`, `screen_registry_groups`,
`set_screen_route_metadata!`,
`screen_route_enabled`, `screen_route_disabled_reason`,
`set_screen_route_disabled_reason!`, `clear_screen_route_disabled_reason!`,
`enable_screen_route!`, `disable_screen_route!`,
`push_registered_screen!`, and `replace_registered_screen!` when screens should
be defined once, described for route switchers, and addressed by route ID. Use
`screen_stack_element` to compose a base `Element` with the current screen stack
outside a full `ToolkitApp`, and use `pop_to_screen!`, `remove_screen!`,
`clear_overlay_screens!`,
`clear_screens!`, `current_screen`,
`screen_stack_count`, `screen_stack_empty`, `screen_stack_ids`,
`screen_stack_modes`, `screen_stack_records`, `screen_stack_summary`, and
`has_screen` for diagnostics and tests instead of reading `ScreenStack` fields
directly. Use `screen_registry_json`, `screen_registry_markdown`,
`screen_registry_tsv`, `screen_registry_group_json`,
`screen_registry_group_markdown`, `screen_registry_group_tsv`,
`screen_registry_text`, `screen_registry_summary_text`,
`screen_registry_group_text`, `screen_registry_group_summary_text`,
`screen_stack_json`, `screen_stack_markdown`, and `screen_stack_tsv` when route
and stack diagnostics should be exported as structured artifacts. Use
`screen_registry_group_records` and `screen_registry_group_summary` when route
sections need counts and route IDs. Registry records include route title,
description, group,
mode, enabled state, disabled reason, and searchable keywords. Use `search_screen_registry_records` and the matching
count, JSON, Markdown, and TSV helpers when route pickers or debug panels need a
filtered view of registered screens by route ID, title, description, mode, or
keyword. Use `screen_registry_command_items` and
`screen_registry_menu_items` when registered routes should become command
palette or menu entries with polished labels, descriptions, and keyword search,
and use `screen_registry_command_palette`, `screen_registry_menu`, or
`screen_registry_navigation_rail` when route switchers should be ready-to-render
widgets. Use `screen_registry_tabs` and
`selected_screen_registry_tab_message` when registered routes should be exposed
as a tab strip with explicit selected-tab state. Use `screen_stack_breadcrumb`
when the active screen stack should be rendered as a breadcrumb trail.
For a runnable example, see
[`examples/screen_stack_quickstart.jl`](examples/screen_stack_quickstart.jl).

Stylesheet-driven Toolkit applications should keep a reusable `StyleEngine`
outside the render loop and pass it to `ToolkitTree` when CSS-like selectors,
theme roles, classes, and pseudo-state need to affect retained component trees.
Use `style_context_record`, `style_context_text`, `style_context_markdown`, and
`style_context_tsv` to inspect the target context that Toolkit generated for a
retained element.
Use `style_diagnostics` when a Toolkit styling failure needs one artifact that
contains context, matched and unmatched stylesheet rules, cascade resolution,
and summary counts.
Use the `search_style_diagnostics_*` helpers when a single query should search
both stylesheet rule matches and cascade resolution steps in that aggregate
artifact.
Use `explain_style` and `style_explanation_records` to debug theme roles,
specificity, matching stylesheet rules, and inline style patches from stable
application code. Use `style_explanation_text`, `style_explanation_markdown`,
or `style_explanation_tsv` when the trace needs to be logged, attached to CI, or
compared in tests.
Use `search_style_explanation_records` and the matching text, Markdown, TSV, and
count helpers to isolate only the `theme`, `stylesheet`, or `inline` steps for a
component when diagnosing large Toolkit trees. Filtered records keep the
original cascade `index`, making search output safe to cross-reference with the
full trace.
`selector_text` renders matched stylesheet selectors in CSS-like form, and
selector strings are included in style explanation records and formatted output.
Use `style_rule_match_records`, `matching_style_rule_records`, and
`unmatched_style_rule_records` when a class or pseudo-state does not select the
expected Toolkit element; the text, Markdown, and TSV renderers expose the same
matched/unmatched rule table for diagnostics artifacts.
Unmatched rule records include mismatch reasons such as `classes`, `states`,
`id`, `widget type`, or `ancestor classes`; call `selector_match_reasons` for
that analysis without rendering a full table.
Use the `search_style_rule_match_*` helpers to filter large Toolkit stylesheet
diagnostics by selector text, match status, mismatch reason, specificity,
stylesheet index, or rule order.
Use `style_explanation_summary_text`, `style_explanation_summary_markdown`, or
`style_explanation_summary_tsv` for compact CI artifacts that only need counts
by source.
Use `ToolkitPilot` in headless tests and examples to drive a Toolkit tree
without taking over a real terminal.

Return values are normalized as follows:

- `nothing` means no effect.
- `Bool` becomes `EventResponse(consumed=value)`.
- `EventResponse` gives explicit control over consumption, propagation, redraw,
  focus, and message delivery.
- Any other value is treated as an application message.

`DispatchResult` reports whether a routed event was consumed, whether a redraw was
requested, and which messages were emitted. `element_instance(tree, id)` returns
the retained `ElementInstance` for diagnostics and advanced integrations;
`element_state(tree, id)` is preferred when only the local state is needed.

## Stable component-tree quickstart

Use `Element` and the layout helpers from `Wicked.API` when an application should
feel closer to Textual or TamboUI while still rendering through Wicked's
immediate-mode core. Keep `key` stable for state retention and `id` stable for
focus, queries, and semantic automation. You can use `row`, `column`, `hbox`,
`vbox`, `hsplit`, and `vsplit` directly, plus the migration aliases
`HStack`, `VStack`, `HBox`, `VBox`, `HSplit`, `VSplit`, and `ZStack`:

Toolkit focus uses the same `FocusRegistry` contract as immediate applications:
tab and reverse-tab traverse focusable elements in deterministic order, pointer
presses can focus the clicked element, and closing a nested focus scope restores
the previous target only when it is still visible and enabled. Use
`can_focus(tree.state.focus, id)`, `focus_count(tree.state.focus)`,
`focus_order(tree.state.focus)`, `focus_index(tree.state.focus)`, and
`focus_snapshot(tree.state.focus)` in tests or diagnostics when a Toolkit tree
needs to expose the exact current traversal state without inspecting retained
element internals. `FocusSnapshot` displays compactly for failed assertions and
developer panels, while keeping the structured fields, scope stack, and scope
depth, restore stack, and restore depth available for code. Use
`focus_snapshot_record(tree.state.focus)` when
diagnostics need plain data for logging or snapshot comparisons.
Use `focus_scopes(tree.state.focus)` or `focus_scope_depth(tree.state.focus)`
when debugging nested screens, modals, and overlays.
Use `focus_restore_targets(tree.state.focus)` or
`focus_restore_depth(tree.state.focus)` when debugging which focus target will be
restored as nested scopes close. Use `focus_restore_target(tree.state.focus)` for
the next restore target only.
Routed handlers can also return `EventResponse(focus=:next)`,
`EventResponse(focus=:previous)`, `EventResponse(focus=:first)`,
`EventResponse(focus=:last)`, or a directional focus command such as
`EventResponse(focus=:left)` to move focus without coupling the component to a
specific sibling ID. A focus command that changes the focused target marks the
dispatch result for redraw even when the response did not otherwise consume the
event. Use `EventResponse(focus=:clear)` or `EventResponse(focus=:none)` when a
routed handler should explicitly leave the current scope without a focused
target. `focus=nothing` means the response does not issue a focus command.
event. When a handler moves focus for a Tab or reverse-Tab key event, Toolkit
suppresses the default fallback traversal for that event so focus advances only
once.

```julia
using Wicked.API

function counter_view(count)
    column(
        Element(Label("Count: $count"); id=:count_label, key=:count_label),
        Element(
            Button("Increment", :increment);
            id=:increment,
            key=:increment,
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == TargetPhase || event.phase == target_phase ||
                event.phase == capture_phase || return nothing
                event.event isa KeyEvent || return nothing
                event.event.key.code == :enter || return nothing
                return EventResponse(consumed=true, message=:increment)
            end,
        );
        constraints=[Length(1), Length(3)],
        gap=1,
    )
end

tree = ToolkitTree(counter_view(0))
frame = Frame(Buffer(5, 32))
render_toolkit!(frame, tree)

result = dispatch!(tree, KeyEvent(Key(:enter)))
@assert result.consumed
@assert :increment in result.messages

semantics = toolkit_semantic_tree(tree; label="Counter")
@assert isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
```

Use reactive signals when several components need shared state without hiding
mutation inside render functions:

```julia
count = Signal(0; name="count")
events = Int[]

subscription = subscribe!(count) do new_value, _, _
    push!(events, new_value)
end

update_signal!(value -> value + 1, count)
@assert signal_value(count) == 1

unsubscribe!(subscription)
```

The longer [Toolkit Tutorial](TOOLKIT_TUTORIAL.md) covers pilots, state
retention across rebuilt trees, routed events, managed Toolkit applications,
semantic overrides, and stylesheet integration.

```@autodocs
Modules = [
    Wicked.Toolkit,
    Wicked.ToolkitComponents,
    Wicked.Reactive,
    Wicked.ReactiveToolkit,
]
Private = false
```
