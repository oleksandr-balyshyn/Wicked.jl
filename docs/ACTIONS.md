# Actions

Actions give application behavior one stable name that can be invoked from key
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

if result.status == ActionInvoked
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
```

Binding conflicts resolve by combined action and shortcut priority, then action
priority and ID for deterministic behavior. `action_binding_map` adapts currently
visible and enabled actions to Wicked's existing `BindingMap` API.

## Command palette

```julia
palette = CommandPalette(action_command_items(registry, context))
selected_id = activate(palette, palette_state)
selected_id === nothing || invoke_action!(registry, selected_id, context)
```

Palette items inherit action titles, descriptions, categories, keywords, and
enabled state. Visibility predicates exclude actions that should not be discoverable
in the current screen or focus context.
