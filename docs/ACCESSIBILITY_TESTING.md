# Accessibility and Headless Testing

Wicked treats accessibility semantics and automation selectors as public behavior. Interactive components should expose stable identity, role, label, state, bounds, and supported actions independently of their terminal styling.

## Build semantics from Toolkit

Render the tree before requesting semantics so retained state and layout bounds are current:

```julia
using Wicked.API

root = Element(
    Button("Save", :save);
    key=:save_button,
    id=:save,
    focusable=true,
)

pilot = ToolkitPilot(root; height=3, width=16)
tree = pilot_semantic_tree(pilot; label="Editor")

save = semantic_node(tree, "save")
@assert save.role == ButtonRole
@assert ActivateSemanticAction in save.actions
@assert save.bounds !== nothing
```

Built-in core controls provide descriptors automatically. Compound widgets such as tabs, menus, lists, tables, trees, radio groups, and selects expose semantic children for their logical items.

## Override or extend descriptors

Use `Element(...; semantics=descriptor)` when visual text is not an adequate accessible label:

```julia
Element(
    TextInput(mask="*");
    id=:password,
    focusable=true,
    semantics=SemanticDescriptor(
        TextboxRole;
        label="Password",
        state=SemanticState(required=true),
    ),
)
```

The `semantics` value can also be a callback accepting `(widget, state, element)` and returning a `SemanticDescriptor`.

External widget packages can implement open dispatch or register descriptor factories with `RoleRegistry`:

```julia
Wicked.widget_semantic_descriptor(widget::MyWidget, state::MyWidgetState) =
    SemanticDescriptor(
        StatusRole;
        label=widget.label,
        state=SemanticState(busy=state.loading),
    )
```

Use `widget_semantic_children` when one rendered widget represents multiple logical controls. Use `SemanticBuilder` when constructing a semantic tree incrementally from custom immediate-mode rendering code.

## Validate invariants

```julia
diagnostics = validate_semantics(tree)
errors = filter(diagnostic -> diagnostic.severity == :error, diagnostics)
@assert isempty(errors)
```

Validation detects duplicate IDs, multiple focused nodes, focused non-focusable nodes, hidden focus, and invalid numeric ranges. Unlabeled interactive roles produce warnings.

Disabled or hidden Toolkit elements do not advertise actions in the generated tree. Protected `TextInput` values are not copied into semantics.

## Test immediate widgets

```julia
pilot = WidgetPilot(Checkbox("Enabled"); height=1, width=20)
key!(pilot, :enter)

@assert pilot.state.checked
@assert_plain_snapshot(pilot, "[x] Enabled")
@assert occursin("widget:CheckboxRole", pilot_semantic_snapshot(pilot))
assert_semantic_snapshot(pilot, pilot_semantic_snapshot(pilot))
```

`WidgetPilot` owns a `TestBackend`, terminal, state value, and virtual clock. Supply `state=` for custom state or let built-in widgets create it automatically.

## Test managed applications

```julia
pilot = RuntimePilot(MyApp(); height=10, width=60)

send!(pilot, :load)
advance_time!(pilot, 1.0)

@assert pilot.model.loaded
@assert occursin("Loaded", plain_snapshot(pilot))
```

`RuntimePilot` drives commands, delays, subscriptions, redraws, processes through an injected executor, and application exit without entering terminal modes. `VirtualClock`, `ScheduledToken`, and scheduling helpers are stable for deterministic tests.

## Query declarative trees

```julia
match = query_one(
    pilot;
    id=:save,
    widget_type=Button,
    class=:primary,
    focused=true,
)
```

Queries can match ID, widget type, class, rendered text, state, and focus. Prefer stable IDs and semantic state over coordinates or full-screen text.

Use `ToolkitPilot` queries for interaction tests and semantic queries for
accessibility contracts. A typical test drives focus or input through
`ToolkitPilot`, then asserts the generated semantic tree with
`pilot_semantic_tree`, `pilot_semantic_snapshot`, `semantic_node`, and
`validate_semantics`. Use `toolkit_semantic_tree` directly only when testing a
`ToolkitTree` without a pilot. This keeps visual snapshots, interactive state,
and accessibility behavior aligned.

`assert_semantic_snapshot` can compare a pilot against either a fixed snapshot
string or an expected `SemanticTree`.

## Snapshot the right layer

| Assertion | Use |
| --- | --- |
| `assert_cell` | Exact grapheme and style behavior |
| `assert_plain_snapshot` | Stable visible text |
| `assert_ansi_snapshot` | Terminal protocol/style output |
| `structured_snapshot` | Machine-readable cell metadata |
| `svg_snapshot` | Review artifacts |
| `semantic_snapshot` / `assert_semantic_snapshot` | Roles, labels, and state |

Avoid using a full visual snapshot as the only interaction assertion. A selected row can render correctly while exposing the wrong semantic state or action.

## Drive semantic actions

`SemanticPilot` validates requested actions against the current tree before dispatch:

```julia
dispatcher = SemanticDispatcher()
register_semantic_handler!(dispatcher, "save") do request
    SemanticActionResult(request.action == ActivateSemanticAction; value=:saved)
end

pilot = SemanticPilot(tree; dispatcher)
save = query_one_semantic(pilot; id="save")
result = perform_semantic_action!(pilot, "save", ActivateSemanticAction)

@assert save.role == ButtonRole
@assert result.handled
@assert result.value == :saved
```

Hidden, disabled, missing, or unsupported actions are rejected before invoking the handler.

Compound widgets can provide helper registration functions for their generated
child nodes. For example, calendar day cells expose selectable and activatable
semantic nodes:

```julia
dispatcher = SemanticDispatcher()
register_calendar_semantic_handlers!(dispatcher, "calendar", calendar, calendar_state)
pilot = SemanticPilot(tree; dispatcher)

result = perform_semantic_action!(
    pilot,
    "calendar/week-3/day-15",
    ActivateSemanticAction,
)

@assert result.handled
@assert calendar_state.activated == Date(2026, 7, 15)
```

## Component acceptance checklist

For every interactive component, test:

- Keyboard-only operation and focus traversal.
- Pointer behavior where supported.
- Disabled, hidden, selected, checked, expanded, invalid, busy, and pending state.
- Resize and zero-sized rendering.
- Light, dark, and high-contrast theme behavior.
- Stable semantic node IDs for downstream selectors and release snapshots.
- Semantic role, label, bounds, state, and actions.
- Registered semantic action handlers for every actionable stable widget.
- Mount/unmount and subscription disposal.
- Deterministic visual and semantic snapshots.
