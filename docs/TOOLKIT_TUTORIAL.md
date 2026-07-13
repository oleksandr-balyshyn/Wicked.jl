# Toolkit Tutorial

Toolkit adds keyed reconciliation, routed input, persistent widget state, focus traversal, styles, and accessibility semantics above the immediate renderer. Widget descriptions remain immutable; Toolkit retains the state associated with stable element keys.

## Build a keyed tree

```julia
using Wicked.API

function counter_view(count)
    column(
        Element(
            Label("Count: $count");
            key=:count_label,
            id=:count,
        ),
        Element(
            Button("Increment", :increment);
            key=:increment_button,
            id=:increment,
            classes=[:primary],
            focusable=true,
        );
        constraints=[Length(1), Length(3)],
        gap=1,
    )
end
```

Keys belong to sibling reconciliation. IDs belong to query, focus, style, and automation APIs. Both must remain stable, but they serve different namespaces.

## Drive the tree headlessly

```julia
pilot = ToolkitPilot(counter_view(0); height=5, width=24)

focus_element!(pilot, :increment)
key!(pilot, :enter)

button = query_one(pilot; id=:increment, widget_type=Button, focused=true)
@assert button.state isa ButtonState
@assert :increment in pilot.messages
```

`query_one` fails when zero or multiple elements match, preventing ambiguous automation selectors.

## Retain state across descriptions

Rebuild the root with the same keys after changing domain state:

```julia
original_state = element_state(pilot.tree, :increment)
pilot.tree.root = counter_view(1)
draw!(pilot)

@assert element_state(pilot.tree, :increment) === original_state
```

Removing the keyed element invokes its `on_unmount` callback. Reusing its key with a different widget signature unmounts the old state and mounts a new state.

## Handle routed events

Use `on_event` when a component needs behavior beyond a built-in widget handler.
The callback receives a `RoutedEvent` and the element's retained state:

```julia
logging_button = Element(
    Button("Run", :run);
    key=:run_button,
    id=:run,
    focusable=true,
    on_event=(event, state) -> begin
        event.phase == TargetPhase || return nothing
        event.event isa KeyEvent || return nothing
        event.event.key.code == :enter || return nothing
        return EventResponse(consumed=true, message=:run_from_keyboard)
    end,
)
```

Return `EventResponse(stop_propagation=true)` to stop bubbling to ancestors.
Return `EventResponse(focus=:next)`, `EventResponse(focus=:previous)`,
`EventResponse(focus=:first)`, or `EventResponse(focus=:last)` when a component
should move focus after handling an event. Directional commands such as
`EventResponse(focus=:left)` use the same focus geometry as immediate-mode
applications. Focus commands that change the focused target request redraw even
when the response is not consumed. If a handler moves focus during a Tab or
reverse-Tab key event, Toolkit does not also run the default fallback traversal.
Use `EventResponse(focus=:clear)` when a dismiss or blur interaction should leave
no element focused. `EventResponse(focus=nothing)` is the default no-op focus
command; use `:clear` or `:none` when the handler should actively remove focus.
Return an application message directly for concise callbacks, or return
`nothing` when the callback did not handle the event.

## Create a managed Toolkit application

```julia
mutable struct CounterModel
    count::Int
end

struct CounterApp <: ToolkitApp end

initialize_model(::CounterApp) = CounterModel(0)

toolkit_view(::CounterApp, model::CounterModel) = counter_view(model.count)

function toolkit_update!(::CounterApp, model::CounterModel, message)
    if message === :increment
        model.count += 1
        return FrameCommand()
    end
    return NoCommand()
end

run(CounterApp())
```

The managed runtime owns terminal setup/restoration and turns messages returned by widget activation into calls to `toolkit_update!`.

## Add semantic metadata

Built-in interactive widgets have automatic descriptors. Override a label or role when visual text is insufficient:

```julia
password = Element(
    TextInput(mask="*");
    key=:password,
    id=:password,
    focusable=true,
    semantics=SemanticDescriptor(
        TextboxRole;
        label="Account password",
        state=SemanticState(required=true),
    ),
)
```

After rendering, build and validate the accessibility tree:

```julia
pilot = ToolkitPilot(password; height=1, width=30)
semantic_tree = pilot_semantic_tree(pilot; label="Sign in")

@assert isempty(filter(d -> d.severity == :error, validate_semantics(semantic_tree)))
```

## Add styles

Toolkit selectors match widget type, ID, classes, pseudo-state, and ancestor classes. Inline patches have the highest precedence:

```julia
sheet = parse_stylesheet("""
Button.primary { color: bright-cyan; }
Button.primary:focus { modifiers: bold underline; }
""")

styles = StyleEngine(stylesheets=[sheet])
pilot = ToolkitPilot(counter_view(0); height=5, width=24, styles=styles)
```

Invalid external stylesheets produce diagnostics or `StylesheetParseError`; unsupported declarations are never ignored silently.

## Continue with runtime services

Use commands for finite work and subscriptions for ongoing inputs. The [Async Runtime](ASYNC_RUNTIME.md) guide covers those lifecycles. The [Accessibility and Testing](ACCESSIBILITY_TESTING.md) guide covers semantic actions, virtual time, and snapshots.
