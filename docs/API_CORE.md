# Core API

This page contains generated reference documentation for geometry, cells, buffers,
layout, styles, events, and immediate interaction contracts.

## Layout helpers

Use `Rect`, `Position`, and `Size` for terminal geometry. Use `split`,
`intersection`, `inset`, and `clamp` when writing immediate-mode widgets that
render directly into a buffer.

Toolkit applications can use the stable composition helpers from `Wicked.API`:

```julia
root = column(
    row(
        leaf(Label("Status"));
        constraints=[Fill(1)],
    ),
    grid(
        leaf(Label("Left")),
        leaf(Label("Right"));
        rows=[Length(1)],
        columns=[Fill(1), Fill(1)],
    );
    constraints=[Length(1), Fill(1)],
)
```

`row` and `column` create flex containers. `grid` creates a `GridLayout`.
`stack` overlays children in paint order. `centered(child; height, width)` keeps
one child in a fixed-size centered region. Use `leaf(widget; kwargs...)` to wrap
an immediate-mode widget as a Toolkit element.

## Stable styling quickstart

Use `Style`, `Theme`, `StyleEngine`, and parsed stylesheets when a Toolkit app
needs Textual-style selector-based styling while preserving Wicked's explicit
rendering model:

```julia
using Wicked.API

sheet = parse_stylesheet("""
Button.primary {
  color: bright-cyan;
}

Button.primary:focus {
  modifiers: bold underline;
}
""")

theme = Theme(
    :dashboard;
    roles=Dict(
        :text => Style(foreground=AnsiColor(15)),
        :accent => Style(foreground=AnsiColor(6), modifiers=BOLD),
    ),
)

styles = StyleEngine(; theme, stylesheets=[sheet])

root = column(
    Element(Label("Deployments"); id=:title, key=:title, style_role=:accent),
    Element(
        Button("Deploy", :deploy);
        id=:deploy,
        key=:deploy,
        classes=[:primary],
        focusable=true,
        style_patch=StylePatch(add_modifiers=UNDERLINE),
    );
    constraints=[Length(1), Length(3)],
)

tree = ToolkitTree(root; styles)
render_toolkit!(Frame(Buffer(5, 32)), tree)
```

Selectors can match widget type, `#id`, `.class`, pseudo-state such as `:focus`,
and ancestor classes. The cascade is deterministic: specificity wins first, then
later stylesheets, then later rules in the same stylesheet. Inline
`style_patch` values have the highest precedence for one element. Theme roles
come from `style_role` and can be changed globally by replacing the engine theme.

Use `try_parse_stylesheet` when editor tooling or live reload should report
diagnostics without throwing:

```julia
stylesheet, diagnostics = try_parse_stylesheet("Button { unknown: value; }")
```

See [Theme Management](THEMES.md) for named theme registries, preferences,
high-contrast variants, live replacement, and `StyleEngine` binding.

## Stable event quickstart

Use typed events from `Wicked.API` when routing terminal input into widgets,
Toolkit trees, runtime pilots, or tests:

```julia
key = KeyEvent(Key(:enter))
mouse = MouseEvent(Position(1, 1), LeftMouseButton, MouseRelease)
paste = PasteEvent("deploy")
resize = ResizeEvent(Size(24, 80))
focus = FocusEvent(true)
tick = TickEvent(UInt64(2_000_000_000), UInt64(16_000_000))
custom = CustomEvent(:refresh)
```

`FocusRegistry` provides tab traversal, first/last traversal, directional
navigation, hit testing, deterministic focus-order introspection, and scoped
focus restoration for applications that manage focus outside a full Toolkit
tree. `focus_order(registry)` returns the currently focusable target IDs in the
same order used by tab traversal, `focus_count(registry)` returns the number of
currently focusable targets, `focus_index(registry)` returns the current
one-based position in that order, and `can_focus(registry, id)` checks whether a
target is currently focusable in the active scope. `focus_snapshot(registry)`
returns the same active scope, full scope stack, scope depth, current target,
restore targets, restore depth, count, index, and order as one immutable diagnostic value with compact display
output for test failures and debug panels. Use `focus_snapshot_record(snapshot)`
or `focus_snapshot_record(registry)` when a log, dashboard, or test assertion
needs a plain named tuple.
`focus_scopes(registry)` and `focus_scope_depth(registry)` expose the active
scope stack for modal, screen, and overlay diagnostics without exposing mutable
registry internals. `focus_restore_targets(registry)` and
`focus_restore_depth(registry)` expose the pending restoration stack that will be
used as nested scopes close. `focus_restore_target(registry)` returns the next
target that would be restored, or `nothing` when no restore target is pending.
Use `clear_focus!(registry)` when a modal dismissal, blur transition, or lifecycle
boundary should leave no current target. When a modal or nested scope closes,
restored focus is accepted only if the
target is still visible, enabled, and measurable; otherwise the registry falls
back to the next valid target in deterministic tab order.

`BindingMap` keeps keyboard shortcuts deterministic. Use `binding_count(map)` for
summary diagnostics, `binding_keys(map)` when help screens only need key/modifier
pairs, `binding_records(map)` when tests, help overlays, or debug panels need the
full table, `binding_record(map, key; modifiers=...)` when a tool needs one plain
keybinding record, and `has_binding(map, key; modifiers=...)` when conflict
checks only need a predicate without reading `map.bindings`. Use
`binding_conflict(map, binding)` to inspect the existing binding that would be
replaced before calling `bind!`. Use `bind_strict!(map, binding)` when duplicate
shortcuts should fail fast instead of silently replacing the existing action. Use
`binding_conflicts(target, source)` to preview all shortcut collisions before
composing keymap layers, `binding_conflict_labels(target, source)` for compact
help or error text, and `has_binding_conflicts(target, source)` when a UI only
needs a boolean guard. Use `assert_no_binding_conflicts(target, source)` when a
component, screen, or application definition should fail with conflicting
shortcut labels before it is merged. Use
`merge_bindings!(target, source; conflict=:replace)` or
`merged_bindings(global, screen, component; conflict=:skip)` to compose layered
keymaps with explicit `:replace`, `:skip`, or `:error` conflict behavior. Wrap
maps in `BindingLayer(:screen, map)` and compose them with
`merged_binding_layers(global_layer, screen_layer; conflict=:skip)` when
diagnostics should preserve the layer name that introduced a binding. Use
`binding_layer_conflicts(global_layer, screen_layer)`,
`binding_layer_conflict_labels(global_layer, screen_layer)`, or
`has_binding_layer_conflicts(global_layer, screen_layer)` when diagnostics need
named collision reports before layer composition. Use
`assert_no_binding_layer_conflicts(global_layer, screen_layer)` when conflicting
named layers should fail before an app starts. Use
`bind!(layer, binding)`, `bind_strict!(layer, binding)`,
`merge_bindings!(layer, source; conflict=:skip)`, and `unbind!(layer, key)` when
building named keymaps directly. Use `BindingStack(:app, component, screen,
global)` when a complete app keymap should keep deterministic layer precedence,
then call `resolve_binding_stack`, `binding_stack_help_text`,
`binding_stack_summary`, `binding_stack_conflicts`,
`assert_no_binding_stack_conflicts`, `binding_stack_documented`, or
`merged_binding_stack` for app-level input handling, help overlays, diagnostics,
release checks, collision policy, and merged maps. Use `binding_stack_keys`,
`binding_stack_records`, `binding_stack_display_records`, or
`described_binding_stack_display_records` when debug panels and generated help
need flat, stack-qualified binding rows. Use `binding_stack_snapshot(stack)` or
`binding_stack_snapshot_record(stack)` when tests and debug panels need one
immutable summary of layer order, active layers, counts, documentation state,
and conflicts. Use `binding_stack_layer`,
`binding_stack_layer_names`, `has_binding_layer`, `assert_binding_stack_layer`,
`replace_binding_layer!`, `upsert_binding_layer!`, and `remove_binding_layer!`
to manage mounted screen, modal, and component layers by name. Use
`BindingLayer(:modal, map; active=false)`, `activate_binding_layer!`,
`deactivate_binding_layer!`, `active_binding_stack_layers`, and
`inactive_binding_stack_layers` when mounted layers should remain inspectable but
temporarily ignored by stack-level resolution, help, merge, conflict, and
documentation operations. Use
`binding_layer_keys(layer)`, `binding_layer_record(layer, key; modifiers=...)`,
or `has_binding(layer, key; modifiers=...)` when diagnostics or help overlays
need layer-qualified shortcut lookup without unpacking `layer.map`. Use
`resolve_binding_record(map, event)` when input handling needs the full matched
binding metadata, `resolve_binding_layer(layer, event)` when it also needs the
owning layer, and `resolve_binding_layers(component, screen, global; event)` to
resolve an event against ordered layer precedence. Use
`binding_layer_display_records(layer)`, `binding_layer_help_lines(layer)`, or
`binding_layer_help_text(layer)` when shortcut help should include the owning
layer name. Use `binding_layers_help_lines(global_layer, screen_layer)` or
`binding_layers_help_text(global_layer, screen_layer)` for combined shortcut
help overlays in deterministic layer order, and
`described_binding_layer_display_records(layer)` when help overlays need only
documented layer bindings. Use `binding_layer_summary(layer)`
or `binding_layers_summary(global_layer, screen_layer)` for debug panels and
release checks that need per-layer shortcut counts. Use
`binding_layer_documented(layer)`, `undocumented_binding_layer_records(layer)`,
or `assert_binding_layer_documented(layer)` when each named keymap layer must
ship with complete shortcut help metadata. Use `binding_layers_documented`,
`undocumented_binding_layers_records`, or `assert_binding_layers_documented`
when the whole global/screen/modal/component keymap stack must be documented
before release. Use
`described_bindings(map)` when a help overlay should list only bindings with
user-facing descriptions.
Use `binding_label(record)` or `binding_label(:key; modifiers=CTRL)` for stable
help text such as `Ctrl+q`. Use `binding_display_records(map)` when a help
overlay needs binding records with display labels already attached.
Use `described_binding_display_records(map)` for display-ready help rows that
omit internal or undocumented shortcuts. Use `binding_help_line(record)` for a
compact text row such as `Ctrl+q  Quit`, or `binding_help_lines(map)` for all
described shortcuts in a map. Use `binding_help_text(map)` when a help panel or
log needs one newline-delimited text block. Use `binding_summary(map)` for
diagnostic counts of total, described, and undocumented bindings, and
`undocumented_bindings(map)` to list records missing user-facing descriptions.
Use `bindings_documented(map)` when tests or release checks only need a boolean
gate for complete shortcut help metadata. Use `assert_bindings_documented(map)`
when failures should include the undocumented shortcut labels.

For a runnable public-API example, see
[`examples/input_events_quickstart.jl`](../examples/input_events_quickstart.jl).

```@autodocs
Modules = [
    Wicked.Core,
    Wicked.Layout,
    Wicked.Styles,
    Wicked.Events,
    Wicked.Interaction,
]
Private = false
```
