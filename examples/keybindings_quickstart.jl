using Wicked.API

global_bindings = BindingMap()
bind!(global_bindings, Binding(:q, :quit; modifiers=CTRL, description="Quit", priority=10))
bind!(global_bindings, Binding(:s, :save; modifiers=CTRL, description="Save", priority=20))

screen_bindings = BindingMap()
bind!(screen_bindings, Binding(:h, :help; description="Help", priority=5))
bind!(screen_bindings, Binding(:q, :screen_quit; modifiers=CTRL, description="Close screen", priority=30))

global_layer = BindingLayer(:global, global_bindings)
screen_layer = BindingLayer(:screen, screen_bindings)
stack = BindingStack(:app, screen_layer, global_layer)

quit_event = KeyEvent(Key(:q); modifiers=CTRL)
help_event = KeyEvent(Key(:h))

@assert resolve_binding_stack(stack, quit_event).action == :screen_quit
@assert resolve_binding_stack(stack, help_event).action == :help
@assert has_binding_stack_conflicts(stack)
@assert binding_stack_conflict_labels(stack) == ["Ctrl+q"]

map_json = binding_help_json(global_bindings)
layer_markdown = binding_layer_help_markdown(screen_layer)
stack_tsv = binding_stack_help_tsv(stack)
hints = binding_key_hints(stack)
shortcut_bar = ShortcutBar(stack)
help_view = HelpView(binding_key_hints(screen_layer))
shell = AppShell(Label("Body"); shortcuts=stack)

@assert occursin("\"label\": \"Ctrl+q\"", map_json)
@assert startswith(layer_markdown, "| `layer` | `label` | `action` |")
@assert startswith(stack_tsv, "stack\tlayer\tlabel\taction\tdescription\tpriority")
@assert first(hints).key == "Ctrl+q"
@assert any(hint -> hint.key == "h", hints)
@assert shortcut_bar isa ShortcutBar
@assert help_view isa HelpView
@assert app_shell_dock(shell) isa Dock

snapshot = binding_stack_snapshot(stack)
@assert snapshot.conflict_count == 1
@assert binding_stack_documented(stack)

println("keybindings quickstart example completed")
