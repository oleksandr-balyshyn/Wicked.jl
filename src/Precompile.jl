"""Precompile the common application-facing render path during package precompilation.

The workload is intentionally conservative:

- no terminal mode changes
- no IO beyond in-memory buffers
- no optional dependency loading
- no application event loop startup

It warms the stable immediate-mode path that most applications hit first:
geometry, styles, text, buffers, basic widgets, default-state widget rendering,
layout containers, diffing, Widget/Toolkit pilots, semantic tree generation, and
the headless backend used by tests and examples.
"""
function _precompile_common_workload!()
    style = Core.Style(
        foreground=Core.AnsiColor(2),
        modifiers=Core.BOLD | Core.UNDERLINE,
    )
    area = Core.Rect(1, 1, 12, 48)
    buffer = Core.Buffer(area)
    frame = Core.Frame(buffer)

    label = Widgets.Label("Wicked"; style)
    register_label_semantic_handlers!(SemanticDispatcher(), :precompile_label, label)
    paragraph = Widgets.Paragraph(
        "Immediate-mode Julia TUI widgets with stable rendering.",
        style=style,
    )
    register_paragraph_semantic_handlers!(SemanticDispatcher(), :precompile_paragraph, paragraph)
    block = Widgets.Block(title="Precompile", border_style=style)
    register_block_semantic_handlers!(SemanticDispatcher(), :precompile_block, block)
    boxed = Widgets.Box(paragraph; block)
    column = Widgets.Column(
        label,
        Widgets.Rule(),
        boxed;
        constraints=(Layout.Length(1), Layout.Length(1), Layout.Fill(1)),
        gap=0,
    )

    Core.render!(buffer, Widgets.Clear(), area)
    register_clear_semantic_handlers!(SemanticDispatcher(), :precompile_clear, Widgets.Clear())
    Core.render!(buffer, column, area)
    Core.measure(column, area)
    precompile_rule = Widgets.Rule()
    register_rule_semantic_handlers!(SemanticDispatcher(), :precompile_rule, precompile_rule)
    Core.render!(buffer, precompile_rule, Core.Rect(2, 1, 1, 24))
    precompile_separator = Widgets.Separator()
    register_separator_semantic_handlers!(SemanticDispatcher(), :precompile_separator, precompile_separator)
    Core.render!(buffer, precompile_separator, Core.Rect(2, 1, 1, 24))
    precompile_divider = Widgets.Divider()
    register_divider_semantic_handlers!(SemanticDispatcher(), :precompile_divider, precompile_divider)
    Core.render!(buffer, precompile_divider, Core.Rect(3, 1, 1, 24))
    register_spacer_semantic_handlers!(SemanticDispatcher(), :precompile_spacer, Widgets.Spacer())
    Core.render!(buffer, Widgets.Overlay(Widgets.Label("base"), Widgets.Label("overlay")), Core.Rect(1, 1, 2, 24))
    precompile_heading = Widgets.Heading("Heading"; level=2)
    register_heading_semantic_handlers!(SemanticDispatcher(), :precompile_heading, precompile_heading)
    Core.render!(buffer, precompile_heading, Core.Rect(2, 25, 1, 24))
    markup = Widgets.MarkupText("**Markup** text"; width=24)
    register_markup_text_semantic_handlers!(SemanticDispatcher(), :precompile_markup, markup)
    Widgets.has_inline_role(markup, :strong)
    Core.render!(buffer, markup, Core.Rect(3, 25, 2, 24))
    precompile_rich_text = RichText("Rich text"; style)
    register_rich_text_semantic_handlers!(SemanticDispatcher(), :precompile_rich_text, precompile_rich_text)
    Core.render!(buffer, precompile_rich_text, Core.Rect(4, 25, 2, 24))
    precompile_static = Widgets.Static("Static summary")
    register_static_semantic_handlers!(SemanticDispatcher(), :precompile_static, precompile_static)
    Core.render!(buffer, precompile_static, Core.Rect(3, 1, 1, 24))
    precompile_text_view = Widgets.TextView("Text view\nready")
    register_text_view_semantic_handlers!(SemanticDispatcher(), :precompile_text_view, precompile_text_view)
    Core.render!(buffer, precompile_text_view, Core.Rect(4, 1, 2, 24))
    focus_registry = Interaction.FocusRegistry()
    Interaction.register_focus!(focus_registry, :primary, Core.Rect(1, 1, 1, 8))
    Interaction.register_focus!(focus_registry, :secondary, Core.Rect(1, 10, 1, 8); tab_index=2)
    Interaction.focus_next!(focus_registry)
    Interaction.focus_last!(focus_registry)
    Interaction.focus_first!(focus_registry)
    Interaction.focus_count(focus_registry)
    Interaction.focus_order(focus_registry)
    Interaction.focus_index(focus_registry)
    Interaction.focus_scopes(focus_registry)
    Interaction.focus_scope_depth(focus_registry)
    Interaction.focus_restore_targets(focus_registry)
    Interaction.focus_restore_depth(focus_registry)
    Interaction.focus_restore_target(focus_registry)
    sprint(show, Interaction.focus_snapshot(focus_registry))
    Interaction.focus_snapshot_record(focus_registry)
    Interaction.can_focus(focus_registry, :primary)
    Interaction.clear_focus!(focus_registry)
    Interaction.push_focus_scope!(focus_registry, :dialog)
    binding_map = Interaction.BindingMap()
    Interaction.bind!(binding_map, Interaction.Binding(:q, :quit; description="Quit"))
    strict_binding_map = Interaction.BindingMap()
    Interaction.bind_strict!(strict_binding_map, Interaction.Binding(:enter, :accept; description="Accept"))
    layered_binding_map = Interaction.BindingMap()
    Interaction.bind!(layered_binding_map, Interaction.Binding(:q, :screen_quit; description="Screen quit"))
    Interaction.binding_conflicts(binding_map, layered_binding_map)
    Interaction.binding_conflict_labels(binding_map, layered_binding_map)
    Interaction.has_binding_conflicts(binding_map, layered_binding_map)
    Interaction.assert_no_binding_conflicts(Interaction.BindingMap(), layered_binding_map)
    Interaction.resolve_binding_record(binding_map, Events.KeyEvent(Events.Key(:q)))
    Interaction.merge_bindings!(binding_map, layered_binding_map; conflict=:skip)
    Interaction.merged_bindings(binding_map, layered_binding_map; conflict=:replace)
    global_layer = Interaction.BindingLayer(:global, binding_map)
    screen_layer = Interaction.BindingLayer("screen", layered_binding_map)
    mutable_layer = Interaction.BindingLayer(:mutable)
    Interaction.bind!(mutable_layer, Interaction.Binding(:m, :mutable; description="Mutable"))
    Interaction.bind_strict!(mutable_layer, Interaction.Binding(:n, :next; description="Next"))
    Interaction.merge_bindings!(mutable_layer, screen_layer; conflict=:skip)
    Interaction.unbind!(mutable_layer, :m)
    Interaction.resolve_binding_layer(screen_layer, Events.KeyEvent(Events.Key(:q)))
    Interaction.resolve_binding_layers(screen_layer, global_layer; event=Events.KeyEvent(Events.Key(:q)))
    Interaction.binding_layer_name(screen_layer)
    Interaction.binding_layer_map(screen_layer)
    Interaction.binding_layer_count(screen_layer)
    Interaction.binding_layer_summary(screen_layer)
    Interaction.binding_layers_summary(global_layer, screen_layer)
    Interaction.binding_layer_keys(screen_layer)
    Interaction.has_binding(screen_layer, :q)
    Interaction.binding_layer_record(screen_layer, :q)
    Interaction.binding_layer_documented(screen_layer)
    Interaction.undocumented_binding_layer_records(screen_layer)
    Interaction.assert_binding_layer_documented(screen_layer)
    Interaction.binding_layers_documented(global_layer, screen_layer)
    Interaction.undocumented_binding_layers_records(global_layer, screen_layer)
    Interaction.assert_binding_layers_documented(global_layer, screen_layer)
    Interaction.binding_layer_records(screen_layer)
    Interaction.binding_layer_display_records(screen_layer)
    Interaction.described_binding_layer_display_records(screen_layer)
    Interaction.binding_layer_help_lines(screen_layer)
    Interaction.binding_layer_help_text(screen_layer)
    Interaction.binding_layers_help_lines(global_layer, screen_layer)
    Interaction.binding_layers_help_text(global_layer, screen_layer)
    Interaction.binding_layer_conflicts(global_layer, screen_layer)
    Interaction.binding_layer_conflict_labels(global_layer, screen_layer)
    Interaction.has_binding_layer_conflicts(global_layer, screen_layer)
    Interaction.assert_no_binding_layer_conflicts(Interaction.BindingLayer(:empty), screen_layer)
    Interaction.merged_binding_layers(global_layer, screen_layer; conflict=:skip)
    binding_stack = Interaction.BindingStack(:app, screen_layer, global_layer)
    Interaction.binding_stack_name(binding_stack)
    Interaction.binding_stack_layers(binding_stack)
    Interaction.binding_stack_layer_names(binding_stack)
    Interaction.binding_stack_layer(binding_stack, :screen)
    Interaction.has_binding_layer(binding_stack, :screen)
    Interaction.has_active_binding_layer(binding_stack, :screen)
    Interaction.assert_binding_stack_layer(binding_stack, :screen)
    Interaction.active_binding_stack_layers(binding_stack)
    Interaction.inactive_binding_stack_layers(binding_stack)
    Interaction.active_binding_stack_layer_names(binding_stack)
    Interaction.inactive_binding_stack_layer_names(binding_stack)
    Interaction.active_binding_stack_count(binding_stack)
    Interaction.inactive_binding_stack_count(binding_stack)
    Interaction.active_binding_stack_binding_count(binding_stack)
    Interaction.binding_stack_count(binding_stack)
    Interaction.binding_stack_binding_count(binding_stack)
    Interaction.binding_stack_summary(binding_stack)
    Interaction.binding_stack_keys(binding_stack)
    Interaction.binding_stack_records(binding_stack)
    Interaction.binding_stack_display_records(binding_stack)
    Interaction.described_binding_stack_display_records(binding_stack)
    Interaction.binding_stack_help_json(binding_stack)
    Interaction.binding_stack_help_markdown(binding_stack)
    Interaction.binding_stack_help_tsv(binding_stack)
    binding_key_hints(binding_stack)
    ShortcutBar(binding_stack)
    Footer(binding_key_hints(binding_stack))
    HelpView(binding_key_hints(binding_stack))
    StatusBar(binding_stack)
    stack_snapshot = Interaction.binding_stack_snapshot(binding_stack)
    sprint(show, stack_snapshot)
    Interaction.binding_stack_snapshot_record(stack_snapshot)
    Interaction.binding_stack_snapshot_record(binding_stack)
    Interaction.binding_stack_conflicts(binding_stack)
    Interaction.binding_stack_conflict_labels(binding_stack)
    Interaction.has_binding_stack_conflicts(binding_stack)
    Interaction.binding_stack_help_lines(binding_stack)
    Interaction.binding_layer_help_json(screen_layer)
    Interaction.binding_layer_help_markdown(screen_layer)
    Interaction.binding_layer_help_tsv(screen_layer)
    Interaction.binding_stack_help_text(binding_stack)
    Interaction.binding_stack_documented(binding_stack)
    Interaction.undocumented_binding_stack_records(binding_stack)
    Interaction.assert_binding_stack_documented(binding_stack)
    Interaction.resolve_binding_stack(binding_stack, Events.KeyEvent(Events.Key(:q)))
    Interaction.merged_binding_stack(binding_stack; conflict=:skip)
    mutable_stack = Interaction.BindingStack("mutable")
    Interaction.push_binding_layer!(mutable_stack, global_layer)
    Interaction.prepend_binding_layer!(mutable_stack, screen_layer)
    inactive_layer = Interaction.BindingLayer(:inactive, layered_binding_map; active=false)
    Interaction.push_binding_layer!(mutable_stack, inactive_layer)
    Interaction.activate_binding_layer!(mutable_stack, :inactive)
    Interaction.deactivate_binding_layer!(mutable_stack, :inactive)
    replacement_layer = Interaction.BindingLayer(:screen)
    Interaction.bind!(replacement_layer, Interaction.Binding(:r, :replacement; description="Replacement"))
    Interaction.replace_binding_layer!(mutable_stack, replacement_layer)
    Interaction.upsert_binding_layer!(mutable_stack, Interaction.BindingLayer(:modal); position=:prepend)
    Interaction.remove_binding_layer!(mutable_stack, :screen)
    Interaction.assert_no_binding_stack_conflicts(Interaction.BindingStack(:empty, screen_layer))
    action_registry = ActionRegistry()
    action_context = ActionContext(data=(dirty=true,))
    register_action!(
        action_registry,
        Action(
            :save,
            "Save",
            context -> :save;
            bindings=[ActionBinding(:s; modifiers=Events.CTRL, description="Save")],
        ),
    )
    action_binding_map(action_registry, action_context)
    selected_invocation = invoke_selected_action!(action_registry, :save, action_context)
    action_invocation_record(selected_invocation)
    action_invocation_text(selected_invocation)
    action_invocation_markdown(selected_invocation; columns=(:id, :status))
    action_invocation_tsv(selected_invocation; columns=(:id, :status))
    action_invocation_records([selected_invocation])
    action_invocations_text([selected_invocation])
    action_invocations_markdown([selected_invocation]; columns=(:id, :status))
    action_invocations_tsv([selected_invocation]; columns=(:id, :status))
    action_invocations_all_invoked([selected_invocation])
    action_invocation_failures([selected_invocation])
    action_invocations_any_failed([selected_invocation])
    action_invocation_issues([selected_invocation])
    action_invocation_issue_records([selected_invocation])
    action_invocation_issues_text([selected_invocation])
    action_invocation_issues_markdown([selected_invocation]; columns=(:id, :status))
    action_invocation_issues_tsv([selected_invocation]; columns=(:id, :status))
    action_invocation_issue_summary([selected_invocation])
    action_invocation_issue_summary_records([selected_invocation])
    action_invocation_issue_summary_text([selected_invocation])
    action_invocation_issue_summary_markdown([selected_invocation]; columns=(:status, :count))
    action_invocation_issue_summary_tsv([selected_invocation]; columns=(:status, :count))
    search_action_invocation_issue_summary_records([selected_invocation], "ActionInvoked")
    search_action_invocation_issue_summary_count([selected_invocation], "ActionInvoked")
    search_action_invocation_issue_summary_text([selected_invocation], "ActionInvoked")
    search_action_invocation_issue_summary_markdown([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    search_action_invocation_issue_summary_tsv([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    action_invocations_any_issue([selected_invocation])
    assert_action_invocations_invoked([selected_invocation])
    assert_no_action_invocation_failures([selected_invocation])
    assert_no_action_invocation_issues([selected_invocation])
    action_invocation_summary([selected_invocation])
    action_invocation_summary_records([selected_invocation])
    action_invocation_summary_text([selected_invocation])
    action_invocation_summary_markdown([selected_invocation]; columns=(:status, :count))
    action_invocation_summary_tsv([selected_invocation]; columns=(:status, :count))
    search_action_invocation_records([selected_invocation], "save")
    search_action_invocation_count([selected_invocation], "ActionInvoked")
    search_action_invocations_text([selected_invocation], "save")
    search_action_invocations_markdown([selected_invocation], "save"; columns=(:id, :status))
    search_action_invocations_tsv([selected_invocation], "save"; columns=(:id, :status))
    search_action_invocation_summary_records([selected_invocation], "ActionInvoked")
    search_action_invocation_summary_count([selected_invocation], "ActionInvoked")
    search_action_invocation_summary_text([selected_invocation], "ActionInvoked")
    search_action_invocation_summary_markdown([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    search_action_invocation_summary_tsv([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    action_invocation_invoked(selected_invocation)
    action_invocation_missing(selected_invocation)
    action_invocation_disabled(selected_invocation)
    action_invocation_failed(selected_invocation)
    workflow_diagnostics = action_workflow_diagnostics([selected_invocation])
    action_workflow_diagnostics(selected_invocation)
    empty_action_workflow_diagnostics()
    merge_action_workflow_diagnostics(workflow_diagnostics, empty_action_workflow_diagnostics())
    merge_action_workflow_diagnostics([workflow_diagnostics, empty_action_workflow_diagnostics()])
    sprint(show, workflow_diagnostics)
    action_workflow_diagnostics_record(workflow_diagnostics)
    action_workflow_diagnostics_record([selected_invocation])
    action_workflow_diagnostics_bundle_records(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_records([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_records_markdown(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_records_markdown([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_records_text(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_records_text([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_records_tsv(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_records_tsv([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_summary(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_summary([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_summary_text(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_summary_text([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_summary_markdown(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_summary_markdown([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_summary_tsv(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_summary_tsv([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_all_invoked(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_all_invoked([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_has_issues(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_has_issues([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_bundle_has_failures(workflow_diagnostics, empty_action_workflow_diagnostics())
    action_workflow_diagnostics_bundle_has_failures([workflow_diagnostics, empty_action_workflow_diagnostics()])
    assert_action_workflow_diagnostics_bundle_all_invoked(workflow_diagnostics, empty_action_workflow_diagnostics())
    assert_action_workflow_diagnostics_bundle_all_invoked([workflow_diagnostics, empty_action_workflow_diagnostics()])
    assert_action_workflow_diagnostics_bundle_no_issues(workflow_diagnostics, empty_action_workflow_diagnostics())
    assert_action_workflow_diagnostics_bundle_no_issues([workflow_diagnostics, empty_action_workflow_diagnostics()])
    assert_action_workflow_diagnostics_bundle_no_failures(workflow_diagnostics, empty_action_workflow_diagnostics())
    assert_action_workflow_diagnostics_bundle_no_failures([workflow_diagnostics, empty_action_workflow_diagnostics()])
    action_workflow_diagnostics_invocations(workflow_diagnostics)
    action_workflow_diagnostics_invocations([selected_invocation])
    action_workflow_diagnostics_records(workflow_diagnostics)
    action_workflow_diagnostics_records([selected_invocation])
    search_action_workflow_diagnostics_records(workflow_diagnostics, "save")
    search_action_workflow_diagnostics_records([selected_invocation], "save")
    search_action_workflow_diagnostics_count(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_count([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_text(workflow_diagnostics, "save")
    search_action_workflow_diagnostics_text([selected_invocation], "save")
    search_action_workflow_diagnostics_markdown(workflow_diagnostics, "save"; columns=(:id, :status))
    search_action_workflow_diagnostics_markdown([selected_invocation], "save"; columns=(:id, :status))
    search_action_workflow_diagnostics_tsv(workflow_diagnostics, "save"; columns=(:id, :status))
    search_action_workflow_diagnostics_tsv([selected_invocation], "save"; columns=(:id, :status))
    action_workflow_diagnostics_summary(workflow_diagnostics)
    action_workflow_diagnostics_summary([selected_invocation])
    action_workflow_diagnostics_status_count(workflow_diagnostics, ActionInvoked)
    action_workflow_diagnostics_status_count([selected_invocation], :ActionInvoked)
    action_workflow_diagnostics_issue_status_count(workflow_diagnostics, "ActionFailed")
    action_workflow_diagnostics_issue_status_count([selected_invocation], :ActionFailed)
    action_workflow_diagnostics_failure_status_count(workflow_diagnostics, "ActionFailed")
    action_workflow_diagnostics_failure_status_count([selected_invocation], :ActionFailed)
    action_workflow_diagnostics_invoked_count(workflow_diagnostics)
    action_workflow_diagnostics_invoked_count([selected_invocation])
    action_workflow_diagnostics_missing_count(workflow_diagnostics)
    action_workflow_diagnostics_missing_count([selected_invocation])
    action_workflow_diagnostics_disabled_count(workflow_diagnostics)
    action_workflow_diagnostics_disabled_count([selected_invocation])
    action_workflow_diagnostics_failed_count(workflow_diagnostics)
    action_workflow_diagnostics_failed_count([selected_invocation])
    action_workflow_diagnostics_total_count(workflow_diagnostics)
    action_workflow_diagnostics_total_count([selected_invocation])
    action_workflow_diagnostics_issue_count(workflow_diagnostics)
    action_workflow_diagnostics_issue_count([selected_invocation])
    action_workflow_diagnostics_failure_count(workflow_diagnostics)
    action_workflow_diagnostics_failure_count([selected_invocation])
    action_workflow_diagnostics_summary_records(workflow_diagnostics)
    action_workflow_diagnostics_summary_records([selected_invocation])
    action_workflow_diagnostics_summary_text(workflow_diagnostics)
    action_workflow_diagnostics_summary_text([selected_invocation])
    action_workflow_diagnostics_summary_markdown(workflow_diagnostics; columns=(:status, :count))
    action_workflow_diagnostics_summary_markdown([selected_invocation]; columns=(:status, :count))
    action_workflow_diagnostics_summary_tsv(workflow_diagnostics; columns=(:status, :count))
    action_workflow_diagnostics_summary_tsv([selected_invocation]; columns=(:status, :count))
    search_action_workflow_diagnostics_summary_records(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_summary_records([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_summary_count(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_summary_count([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_summary_text(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_summary_text([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_summary_markdown(workflow_diagnostics, "ActionInvoked"; columns=(:status, :count))
    search_action_workflow_diagnostics_summary_markdown([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    search_action_workflow_diagnostics_summary_tsv(workflow_diagnostics, "ActionInvoked"; columns=(:status, :count))
    search_action_workflow_diagnostics_summary_tsv([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    action_workflow_diagnostics_text(workflow_diagnostics)
    action_workflow_diagnostics_text([selected_invocation])
    action_workflow_diagnostics_markdown(workflow_diagnostics)
    action_workflow_diagnostics_markdown([selected_invocation])
    action_workflow_diagnostics_tsv(workflow_diagnostics)
    action_workflow_diagnostics_tsv([selected_invocation])
    action_workflow_diagnostics_all_invoked(workflow_diagnostics)
    action_workflow_diagnostics_all_invoked([selected_invocation])
    action_workflow_diagnostics_failures(workflow_diagnostics)
    action_workflow_diagnostics_failures([selected_invocation])
    action_workflow_diagnostics_failure_records(workflow_diagnostics)
    action_workflow_diagnostics_failure_records([selected_invocation])
    action_workflow_diagnostics_failures_text(workflow_diagnostics)
    action_workflow_diagnostics_failures_text([selected_invocation])
    action_workflow_diagnostics_failures_markdown(workflow_diagnostics; columns=(:id, :status))
    action_workflow_diagnostics_failures_markdown([selected_invocation]; columns=(:id, :status))
    action_workflow_diagnostics_failures_tsv(workflow_diagnostics; columns=(:id, :status))
    action_workflow_diagnostics_failures_tsv([selected_invocation]; columns=(:id, :status))
    search_action_workflow_diagnostics_failure_records(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_failure_records([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_failure_count(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_failure_count([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_failures_text(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_failures_text([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_failures_markdown(workflow_diagnostics, "ActionInvoked"; columns=(:id, :status))
    search_action_workflow_diagnostics_failures_markdown([selected_invocation], "ActionInvoked"; columns=(:id, :status))
    search_action_workflow_diagnostics_failures_tsv(workflow_diagnostics, "ActionInvoked"; columns=(:id, :status))
    search_action_workflow_diagnostics_failures_tsv([selected_invocation], "ActionInvoked"; columns=(:id, :status))
    action_workflow_diagnostics_failure_summary(workflow_diagnostics)
    action_workflow_diagnostics_failure_summary([selected_invocation])
    action_workflow_diagnostics_failure_summary_records(workflow_diagnostics)
    action_workflow_diagnostics_failure_summary_records([selected_invocation])
    action_workflow_diagnostics_failure_summary_text(workflow_diagnostics)
    action_workflow_diagnostics_failure_summary_text([selected_invocation])
    action_workflow_diagnostics_failure_summary_markdown(workflow_diagnostics; columns=(:status, :count))
    action_workflow_diagnostics_failure_summary_markdown([selected_invocation]; columns=(:status, :count))
    action_workflow_diagnostics_failure_summary_tsv(workflow_diagnostics; columns=(:status, :count))
    action_workflow_diagnostics_failure_summary_tsv([selected_invocation]; columns=(:status, :count))
    search_action_workflow_diagnostics_failure_summary_records(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_failure_summary_records([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_failure_summary_count(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_failure_summary_count([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_failure_summary_text(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_failure_summary_text([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_failure_summary_markdown(workflow_diagnostics, "ActionInvoked"; columns=(:status, :count))
    search_action_workflow_diagnostics_failure_summary_markdown([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    search_action_workflow_diagnostics_failure_summary_tsv(workflow_diagnostics, "ActionInvoked"; columns=(:status, :count))
    search_action_workflow_diagnostics_failure_summary_tsv([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    action_workflow_diagnostics_issues(workflow_diagnostics)
    action_workflow_diagnostics_issues([selected_invocation])
    action_workflow_diagnostics_issue_records(workflow_diagnostics)
    action_workflow_diagnostics_issue_records([selected_invocation])
    action_workflow_diagnostics_issues_text(workflow_diagnostics)
    action_workflow_diagnostics_issues_text([selected_invocation])
    action_workflow_diagnostics_issues_markdown(workflow_diagnostics; columns=(:id, :status))
    action_workflow_diagnostics_issues_markdown([selected_invocation]; columns=(:id, :status))
    action_workflow_diagnostics_issues_tsv(workflow_diagnostics; columns=(:id, :status))
    action_workflow_diagnostics_issues_tsv([selected_invocation]; columns=(:id, :status))
    search_action_workflow_diagnostics_issue_records(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_issue_records([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_issue_count(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_issue_count([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_issues_text(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_issues_text([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_issues_markdown(workflow_diagnostics, "ActionInvoked"; columns=(:id, :status))
    search_action_workflow_diagnostics_issues_markdown([selected_invocation], "ActionInvoked"; columns=(:id, :status))
    search_action_workflow_diagnostics_issues_tsv(workflow_diagnostics, "ActionInvoked"; columns=(:id, :status))
    search_action_workflow_diagnostics_issues_tsv([selected_invocation], "ActionInvoked"; columns=(:id, :status))
    action_workflow_diagnostics_issue_summary(workflow_diagnostics)
    action_workflow_diagnostics_issue_summary([selected_invocation])
    action_workflow_diagnostics_issue_summary_records(workflow_diagnostics)
    action_workflow_diagnostics_issue_summary_records([selected_invocation])
    action_workflow_diagnostics_issue_summary_text(workflow_diagnostics)
    action_workflow_diagnostics_issue_summary_text([selected_invocation])
    action_workflow_diagnostics_issue_summary_markdown(workflow_diagnostics; columns=(:status, :count))
    action_workflow_diagnostics_issue_summary_markdown([selected_invocation]; columns=(:status, :count))
    action_workflow_diagnostics_issue_summary_tsv(workflow_diagnostics; columns=(:status, :count))
    action_workflow_diagnostics_issue_summary_tsv([selected_invocation]; columns=(:status, :count))
    search_action_workflow_diagnostics_issue_summary_records(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_issue_summary_records([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_issue_summary_count(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_issue_summary_count([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_issue_summary_text(workflow_diagnostics, "ActionInvoked")
    search_action_workflow_diagnostics_issue_summary_text([selected_invocation], "ActionInvoked")
    search_action_workflow_diagnostics_issue_summary_markdown(workflow_diagnostics, "ActionInvoked"; columns=(:status, :count))
    search_action_workflow_diagnostics_issue_summary_markdown([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    search_action_workflow_diagnostics_issue_summary_tsv(workflow_diagnostics, "ActionInvoked"; columns=(:status, :count))
    search_action_workflow_diagnostics_issue_summary_tsv([selected_invocation], "ActionInvoked"; columns=(:status, :count))
    action_workflow_diagnostics_has_failures(workflow_diagnostics)
    action_workflow_diagnostics_has_failures([selected_invocation])
    action_workflow_diagnostics_has_issues(workflow_diagnostics)
    action_workflow_diagnostics_has_issues([selected_invocation])
    assert_action_workflow_diagnostics_all_invoked(workflow_diagnostics)
    assert_action_workflow_diagnostics_all_invoked([selected_invocation])
    assert_action_workflow_diagnostics_no_failures(workflow_diagnostics)
    assert_action_workflow_diagnostics_no_failures([selected_invocation])
    assert_action_workflow_diagnostics_no_issues(workflow_diagnostics)
    assert_action_workflow_diagnostics_no_issues([selected_invocation])
    assert_action_invoked(selected_invocation)
    invoke_action_diagnostics!(action_registry, :save, action_context)
    invoke_selected_action!(action_registry, nothing, action_context)
    invoke_selected_action_diagnostics!(action_registry, nothing, action_context)
    invoke_selected_action_diagnostics!(action_registry, :save, action_context)
    invoke_activated_action!(
        action_registry,
        action_menu(action_registry, action_context),
        MenuState(selected=1),
        action_context,
    )
    invoke_activated_action_diagnostics!(
        action_registry,
        action_menu(action_registry, action_context),
        MenuState(selected=1),
        action_context,
    )
    invoke_actions!(action_registry, [:save, nothing, "save"], action_context)
    invoke_actions_diagnostics!(action_registry, [:save, nothing, "save"], action_context)
    invoke_key_actions!(
        action_registry,
        [KeyEvent(Events.Key(:s); modifiers=Events.CTRL)],
        action_context,
    )
    invoke_key_action_diagnostics!(
        action_registry,
        KeyEvent(Events.Key(:s); modifiers=Events.CTRL),
        action_context,
    )
    invoke_key_actions_diagnostics!(
        action_registry,
        [KeyEvent(Events.Key(:s); modifiers=Events.CTRL)],
        action_context,
    )
    action_binding_layer(action_registry, action_context)
    action_binding_stack(action_registry, action_context)
    search_action_binding_map(action_registry, "save", action_context)
    search_action_binding_layer(action_registry, "save", action_context)
    search_action_binding_stack(action_registry, "save", action_context)
    action_help_lines(action_registry, action_context)
    action_help_text(action_registry, action_context)
    action_help_view(action_registry, action_context)
    action_footer(action_registry, action_context)
    action_category_binding_maps(action_registry, action_context)
    action_category_binding_layers(action_registry, action_context)
    action_category_binding_stacks(action_registry, action_context)
    action_category_help_lines(action_registry, action_context)
    action_category_help_text(action_registry, action_context)
    action_category_help_views(action_registry, action_context)
    action_category_footers(action_registry, action_context)
    search_action_help_lines(action_registry, "save", action_context)
    search_action_help_text(action_registry, "save", action_context)
    search_action_help_view(action_registry, "save", action_context)
    search_action_footer(action_registry, "save", action_context)
    search_action_category_binding_maps(action_registry, "save", action_context)
    search_action_category_binding_layers(action_registry, "save", action_context)
    search_action_category_binding_stacks(action_registry, "save", action_context)
    search_action_category_help_lines(action_registry, "save", action_context)
    search_action_category_help_text(action_registry, "save", action_context)
    search_action_category_help_views(action_registry, "save", action_context)
    search_action_category_footers(action_registry, "save", action_context)
    action_surface(action_registry, action_context)
    search_action_surface(action_registry, "save", action_context)
    action_command_palette(action_registry, action_context)
    action_command_palette_session(action_registry, action_context; query="save")
    action_command_sections(action_registry, action_context)
    action_category_command_palettes(action_registry, action_context)
    action_category_command_palette_sessions(action_registry, action_context; query="save")
    action_menu_items(action_registry, action_context)
    action_menu(action_registry, action_context)
    action_menu_session(action_registry, action_context; selected=1)
    action_menu_sections(action_registry, action_context)
    action_category_menus(action_registry, action_context)
    action_category_menu_sessions(action_registry, action_context; selected=1)
    action_category_surfaces(action_registry, action_context; selected=1)
    search_action_menu_items(action_registry, "save", action_context)
    search_action_menu(action_registry, "save", action_context)
    search_action_menu_session(action_registry, "save", action_context; selected=1)
    search_action_menu_sections(action_registry, "File", action_context)
    search_action_category_menus(action_registry, "save", action_context)
    search_action_category_menu_sessions(action_registry, "save", action_context; selected=1)
    search_action_category_surfaces(action_registry, "save", action_context; selected=1)
    search_action_command_items(action_registry, "save", action_context)
    search_action_command_palette(action_registry, "save", action_context)
    search_action_command_palette_session(action_registry, "save", action_context; palette_query="save")
    search_action_command_sections(action_registry, "File", action_context)
    search_action_category_command_palettes(action_registry, "save", action_context)
    search_action_category_command_palette_sessions(action_registry, "save", action_context; palette_query="save")
    action_records(action_registry, action_context)
    action_summary(action_registry, action_context)
    action_snapshot = action_registry_snapshot(action_registry, action_context)
    sprint(show, action_snapshot)
    action_registry_snapshot_record(action_snapshot)
    action_registry_snapshot_record(action_registry, action_context)
    action_diagnostics = action_registry_diagnostics(action_registry, action_context)
    sprint(show, action_diagnostics)
    action_registry_diagnostics_record(action_diagnostics)
    action_registry_diagnostics_record(action_registry, action_context)
    action_registry_diagnostics_markdown(action_diagnostics)
    action_registry_diagnostics_markdown(action_registry, action_context)
    action_registry_diagnostics_text(action_diagnostics)
    action_registry_diagnostics_text(action_registry, action_context)
    action_registry_diagnostics_tsv(action_diagnostics)
    action_registry_diagnostics_tsv(action_registry, action_context)
    action_categories(action_registry, action_context)
    action_category_records(action_registry, action_context)
    action_category_records_markdown(action_registry, action_context; columns=(:category, :count, :actions))
    action_category_records_tsv(action_registry, action_context; columns=(:category, :enabled, :actions))
    search_action_categories(action_registry, "File", action_context)
    search_action_category_count(action_registry, "save", action_context)
    search_action_category_records_markdown(action_registry, "save", action_context; columns=(:category, :actions))
    search_action_category_records_tsv(action_registry, "File", action_context; columns=(:category, :count))
    search_actions(action_registry, "save", action_context)
    search_action_count(action_registry, "Ctrl+s", action_context)
    action_records_markdown(action_registry, action_context; columns=(:id, :title, :bindings))
    action_records_tsv(action_registry, action_context; columns=(:id, :enabled, :bindings))
    search_action_records_markdown(action_registry, "save", action_context; columns=(:id, :category))
    search_action_records_tsv(action_registry, "Ctrl+s", action_context; columns=(:id, :bindings))
    action_error_records(action_registry)
    action_error_summary(action_registry)
    action_error_records_markdown(action_registry; columns=(:index, :type))
    action_error_records_tsv(action_registry; columns=(:type, :message))
    action_error_text(action_registry)
    action_error_summary_records(action_registry)
    action_error_summary_markdown(action_registry; columns=(:type, :count))
    action_error_summary_tsv(action_registry; columns=(:type, :count))
    action_error_summary_text(action_registry)
    search_action_error_records(action_registry, "Error")
    search_action_error_count(action_registry, "Error")
    search_action_error_records_markdown(action_registry, "Error"; columns=(:index, :type))
    search_action_error_records_tsv(action_registry, "Error"; columns=(:type, :message))
    search_action_error_text(action_registry, "Error")
    search_action_error_summary_records(action_registry, "Error")
    search_action_error_summary_count(action_registry, "Error")
    search_action_error_summary_markdown(action_registry, "Error"; columns=(:type, :count))
    search_action_error_summary_tsv(action_registry, "Error"; columns=(:type, :count))
    search_action_error_summary_text(action_registry, "Error")
    stable_entries = stable_widget_catalog()
    stable_widget_catalog(family=:inputs_and_controls)
    stable_widget_families()
    stable_widget_family_catalog()
    stable_widget_family_slugs()
    widget_families_text()
    widget_family_slugs_text()
    widget_catalog_family(:Button)
    widget_catalog_family_slug(:Button)
    widget_catalog_family_slug(:inputs_and_controls)
    stable_widget_count(family=:inputs_and_controls)
    stable_widget_names(family="inputs-and-controls")
    widget_family_summary(family="Inputs and controls")
    widget_family_summary_markdown(family="Inputs and controls")
    widget_family_summary_tsv(family="Inputs and controls")
    widget_family_records(family=:inputs_and_controls)
    widget_family_catalog_markdown(family=:inputs_and_controls, columns=(:family_slug, :count))
    widget_family_catalog_tsv(family=:inputs_and_controls, columns=(:family_slug, :count))
    widget_family_closeout_reports(family=:inputs_and_controls)
    widget_family_closeout_report(:inputs_and_controls)
    widget_family_closeout_records(status=:ready)
    widget_family_closeout_gaps()
    widget_family_closeout_summary()
    widget_family_closeout_complete()
    widget_family_closeout_ready(:inputs_and_controls)
    widget_surface_release_status_record(family=:inputs_and_controls, root=pwd())
    widget_surface_release_ready(family=:inputs_and_controls, root=pwd())
    widget_surface_release_status_text(family=:inputs_and_controls, root=pwd())
    widget_surface_release_status_json(family=:inputs_and_controls, root=pwd())
    isempty(widget_family_closeout_gaps()) &&
        assert_widget_family_closeout_complete()
    isempty(widget_family_closeout_gaps(family=:inputs_and_controls)) &&
        assert_widget_family_closeout_ready(:inputs_and_controls)
    widget_family_closeout_markdown(status=:blocked, columns=(:family, :status, :blockers))
    widget_family_closeout_tsv(status=:ready, columns=(:family, :status), header=false)
    widget_family_closeout_json(status=:blocked)
    widget_family_closeout_artifacts(status=:ready, columns=(:family, :status), header=false)
    widget_family_closeout_artifacts_json(status=:ready)
    widget_family_closeout_artifacts_text(status=:ready)
    widget_family_closeout_artifacts_markdown(status=:ready)
    widget_family_closeout_artifacts_tsv(status=:ready, header=false)
    widget_vocabulary()
    widget_vocabulary_entry("Button")
    widget_vocabulary_widget_names("Button")
    widget_vocabulary_markdown()
    widget_vocabulary_tsv()
    search_widget_families("button")
    search_widget_family_count("button")
    search_widget_family_catalog_markdown("button"; columns=(:family_slug, :count))
    search_widget_family_catalog_tsv("button"; columns=(:family_slug, :count))
    search_widgets("inputs-and-controls")
    search_widget_catalog_markdown("inputs-and-controls"; columns=(:name, :family_slug))
    search_widget_catalog_tsv("inputs-and-controls"; columns=(:name, :family_slug))
    widget_family_entry(:inputs_and_controls)
    is_stable_widget_family(:inputs_and_controls)
    assert_stable_widget_family(:inputs_and_controls)
    widget_family_widgets(:inputs_and_controls)
    widget_family_widget_names(:inputs_and_controls)
    widget_family_widget_count(:inputs_and_controls)
    group_widgets(:family; family=:inputs_and_controls)
    widget_catalog_markdown(family="Inputs and controls", columns=(:name, :family, :family_slug))
    widget_catalog_tsv(family="Inputs and controls", columns=(:name, :family, :family_slug))
    widget_catalog_records(family="Inputs and controls")
    widget_catalog_summary(family="Inputs and controls")
    widget_coverage_records(family="Inputs and controls")
    widget_coverage_gaps(family="Inputs and controls")
    widget_coverage_issue_records(:missing_record, family="Inputs and controls")
    widget_coverage_issue_count(:missing_record, family="Inputs and controls")
    widget_coverage_issue_names(:missing_record, family="Inputs and controls")
    widget_coverage_issue_text(:missing_record, family="Inputs and controls")
    widget_coverage_issue_markdown(:missing_record, family="Inputs and controls", columns=(:name, :issue))
    widget_coverage_issue_tsv(:missing_record, family="Inputs and controls", columns=(:name, :issue))
    widget_coverage_complete(family="Inputs and controls")
    widget_coverage_git_metadata(root=pwd())
    widget_coverage_release_ready(family="Inputs and controls", root=pwd())
    widget_coverage_release_status_record(family="Inputs and controls", root=pwd())
    widget_coverage_release_status_json(family="Inputs and controls", root=pwd())
    widget_coverage_release_status_text(family="Inputs and controls", root=pwd())
    widget_coverage_summary(family="Inputs and controls")
    widget_coverage_summary_records(family="Inputs and controls")
    widget_coverage_summary_markdown(family="Inputs and controls")
    widget_coverage_summary_json(family="Inputs and controls", include_git=false)
    widget_coverage_summary_tsv(family="Inputs and controls")
    widget_coverage_summary_text(family="Inputs and controls")
    widget_stability_complete(family="Inputs and controls")
    isempty(widget_stability_gaps(family="Inputs and controls")) &&
        assert_widget_stability_complete(family="Inputs and controls")
    widget_stability_summary(family="Inputs and controls")
    widget_stability_summary_records(family="Inputs and controls")
    widget_stability_summary_markdown(family="Inputs and controls")
    widget_stability_summary_tsv(family="Inputs and controls")
    widget_stability_summary_text(family="Inputs and controls")
    experimental_widget_names(family="Inputs and controls")
    experimental_widget_count(family="Inputs and controls")
    experimental_widget_records(family="Inputs and controls")
    experimental_widget_records_markdown(family="Inputs and controls")
    experimental_widget_records_tsv(family="Inputs and controls")
    experimental_widget_records_json(family="Inputs and controls")
    candidate_widget_names(family="Inputs and controls")
    candidate_widget_count(family="Inputs and controls")
    candidate_widget_records(family="Inputs and controls")
    candidate_widget_records_markdown(family="Inputs and controls")
    candidate_widget_records_tsv(family="Inputs and controls")
    candidate_widget_records_json(family="Inputs and controls")
    widget_stabilization_status_record(family="Inputs and controls")
    widget_stabilization_status_records(family="Inputs and controls")
    widget_stabilization_status_text(family="Inputs and controls")
    widget_stabilization_status_json(family="Inputs and controls")
    widget_stabilization_status_markdown(family="Inputs and controls")
    widget_stabilization_status_tsv(family="Inputs and controls")
    widget_stabilization_artifacts(family="Inputs and controls")
    widget_stabilization_artifacts_json(family="Inputs and controls")
    widget_stabilization_artifacts_text(family="Inputs and controls")
    widget_stabilization_artifacts_markdown(family="Inputs and controls")
    widget_stabilization_artifacts_tsv(family="Inputs and controls")
    widget_stabilization_artifacts_ready(family="Inputs and controls") &&
        assert_widget_stabilization_artifacts_ready(family="Inputs and controls")
    widget_stabilization_closeout_records(family="Inputs and controls")
    widget_stabilization_closeout_kind_records(:experimental, family="Inputs and controls")
    widget_stabilization_closeout_kind_count(:candidate, family="Inputs and controls")
    widget_stabilization_closeout_kind_markdown(:experimental, family="Inputs and controls")
    widget_stabilization_closeout_kind_tsv(:candidate, family="Inputs and controls")
    widget_stabilization_closeout_kind_json(:experimental, family="Inputs and controls")
    widget_stabilization_closeout_kind_text(:candidate, family="Inputs and controls")
    widget_stabilization_closeout_kind_artifacts(:experimental, family="Inputs and controls")
    widget_stabilization_closeout_kind_complete(:experimental, family="Inputs and controls")
    widget_stabilization_closeout_kind_complete(:experimental, family="Inputs and controls") &&
        assert_widget_stabilization_closeout_kind_complete(:experimental, family="Inputs and controls")
    search_widget_stabilization_closeout_records("button", family="Inputs and controls")
    search_widget_stabilization_closeout_count("button", family="Inputs and controls")
    search_widget_stabilization_closeout_summary("button", family="Inputs and controls")
    search_widget_stabilization_closeout_summary_records("button", family="Inputs and controls")
    search_widget_stabilization_closeout_summary_markdown("button", family="Inputs and controls")
    search_widget_stabilization_closeout_summary_tsv("button", family="Inputs and controls")
    search_widget_stabilization_closeout_summary_json("button", family="Inputs and controls")
    search_widget_stabilization_closeout_summary_text("button", family="Inputs and controls")
    search_widget_stabilization_closeout_complete("button", family="Inputs and controls")
    search_widget_stabilization_closeout_complete("button", family="Inputs and controls") &&
        assert_search_widget_stabilization_closeout_complete("button", family="Inputs and controls")
    search_widget_stabilization_closeout_markdown("button", family="Inputs and controls")
    search_widget_stabilization_closeout_tsv("button", family="Inputs and controls")
    search_widget_stabilization_closeout_json("button", family="Inputs and controls")
    search_widget_stabilization_closeout_text("button", family="Inputs and controls")
    search_widget_stabilization_closeout_artifacts("button", family="Inputs and controls")
    widget_stabilization_closeout_count(family="Inputs and controls")
    widget_stabilization_closeout_complete(family="Inputs and controls")
    widget_stabilization_closeout_complete(family="Inputs and controls") &&
        assert_widget_stabilization_closeout_complete(family="Inputs and controls")
    widget_stabilization_closeout_summary(family="Inputs and controls")
    widget_stabilization_closeout_summary_records(family="Inputs and controls")
    widget_stabilization_closeout_summary_markdown(family="Inputs and controls")
    widget_stabilization_closeout_summary_tsv(family="Inputs and controls")
    widget_stabilization_closeout_summary_json(family="Inputs and controls")
    widget_stabilization_closeout_summary_text(family="Inputs and controls")
    widget_stabilization_closeout_status_record(family="Inputs and controls")
    widget_stabilization_closeout_status_text(family="Inputs and controls")
    widget_stabilization_closeout_status_json(family="Inputs and controls")
    widget_stabilization_closeout_status_markdown(family="Inputs and controls")
    widget_stabilization_closeout_status_tsv(family="Inputs and controls")
    widget_stabilization_closeout_markdown(family="Inputs and controls")
    widget_stabilization_closeout_tsv(family="Inputs and controls")
    widget_stabilization_closeout_json(family="Inputs and controls")
    widget_stabilization_closeout_text(family="Inputs and controls")
    widget_stabilization_closeout_artifacts(family="Inputs and controls")
    widget_stabilization_blocker_records(family="Inputs and controls")
    widget_stabilization_blocker_records_markdown(family="Inputs and controls")
    widget_stabilization_blocker_records_tsv(family="Inputs and controls")
    widget_stabilization_blocker_records_json(family="Inputs and controls")
    widget_stabilization_blockers(family="Inputs and controls")
    widget_stabilization_blocker_count(family="Inputs and controls")
    widget_stabilization_blockers_text(family="Inputs and controls")
    widget_stabilization_blockers_markdown(family="Inputs and controls")
    widget_stabilization_blockers_tsv(family="Inputs and controls")
    widget_stabilization_ready(family="Inputs and controls") &&
        assert_widget_stabilization_ready(family="Inputs and controls")
    widget_coverage_records_markdown(family="Inputs and controls", columns=(:name, :issue))
    widget_coverage_gaps_markdown(family="Inputs and controls", columns=(:name, :issue))
    widget_coverage_records_tsv(family="Inputs and controls", columns=(:name, :issue))
    widget_coverage_gaps_tsv(family="Inputs and controls", columns=(:name, :issue))
    !isempty(stable_entries) && widget_catalog_family(first(stable_entries))
    Interaction.binding_count(binding_map)
    Interaction.binding_keys(binding_map)
    Interaction.binding_label(:q; modifiers=Events.CTRL)
    Interaction.binding_record(binding_map, :q)
    Interaction.binding_help_line(Interaction.Binding(:q, :quit; description="Quit"))
    Interaction.binding_help_lines(binding_map)
    Interaction.binding_help_json(binding_map)
    Interaction.binding_help_markdown(binding_map)
    Interaction.binding_help_text(binding_map)
    Interaction.binding_help_tsv(binding_map)
    binding_key_hints(binding_map)
    Interaction.binding_display_records(binding_map)
    Interaction.binding_summary(binding_map)
    Interaction.binding_records(binding_map)
    Interaction.has_binding(binding_map, :q)
    Interaction.binding_conflict(binding_map, Interaction.Binding(:q, :replacement))
    Interaction.described_binding_display_records(binding_map)
    Interaction.described_bindings(binding_map)
    Interaction.undocumented_bindings(binding_map)
    Interaction.bindings_documented(binding_map)
    Interaction.assert_bindings_documented(binding_map)
    Interaction.register_focus!(focus_registry, :confirm, Core.Rect(3, 3, 1, 8))
    Interaction.focus_next!(focus_registry)
    Interaction.pop_focus_scope!(focus_registry)
    Core.render!(buffer, RichText("Rich text"), Core.Rect(2, 1, 1, 24))
    precompile_markdown = MarkdownView("# Release\n[Docs](https://example.com)\nReady")
    precompile_markdown_state = state_for(precompile_markdown)
    register_markdown_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_markdown,
        precompile_markdown_state,
    )
    Core.render!(buffer, precompile_markdown, Core.Rect(3, 1, 3, 24), precompile_markdown_state)
    precompile_code = CodeView("println(:ok)"; language="julia", width=24, height=3)
    precompile_code_state = state_for(precompile_code)
    register_code_view_semantic_handlers!(SemanticDispatcher(), :precompile_code, precompile_code, precompile_code_state)
    Core.render!(buffer, precompile_code, Core.Rect(4, 1, 3, 24), precompile_code_state)
    precompile_code_editor = CodeEditor("println(:ok)"; language="julia")
    precompile_code_editor_state = state_for(precompile_code_editor)
    register_code_editor_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_code_editor,
        precompile_code_editor,
        precompile_code_editor_state,
    )
    set_code_editor_text!(precompile_code_editor_state, "println(:done)")
    Core.render!(buffer, precompile_code_editor, Core.Rect(4, 1, 3, 24), precompile_code_editor_state)
    precompile_syntax = SyntaxView("x = 1"; language="julia", width=24, height=2)
    precompile_syntax_state = state_for(precompile_syntax)
    register_syntax_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_syntax,
        precompile_syntax,
        precompile_syntax_state,
    )
    Core.render!(buffer, precompile_syntax, Core.Rect(4, 25, 2, 20), precompile_syntax_state)
    precompile_diff = DiffView(parse_unified_diff("--- a/file.jl\n+++ b/file.jl\n@@ -1 +1 @@\n-old\n+new\n"); width=24, height=3)
    precompile_diff_state = state_for(precompile_diff)
    register_diff_view_semantic_handlers!(SemanticDispatcher(), :precompile_diff, precompile_diff, precompile_diff_state)
    Core.render!(
        buffer,
        precompile_diff,
        Core.Rect(6, 1, 3, 24),
        precompile_diff_state,
    )
    precompile_error_view = ErrorView(ErrorException("boom"))
    register_error_view_semantic_handlers!(SemanticDispatcher(), :precompile_error_view, precompile_error_view)
    Core.render!(buffer, precompile_error_view, Core.Rect(6, 25, 3, 20))
    log_state = LogState()
    push_log!(log_state, "watch"; level=:info)
    register_log_view_semantic_handlers!(SemanticDispatcher(), :precompile_log, log_state; viewport_height=2)
    Core.render!(buffer, LogView(), Core.Rect(8, 1, 2, 24), log_state)
    rich_log_state = RichLogState()
    push_log!(rich_log_state, "rich"; level=:info)
    register_rich_log_semantic_handlers!(SemanticDispatcher(), :precompile_rich_log, rich_log_state; viewport_height=2)
    Core.render!(buffer, RichLog(), Core.Rect(8, 25, 2, 20), rich_log_state)
    precompile_live = LiveDisplay(state -> "frame $(state.frame)"; width=24, height=1)
    precompile_live_state = state_for(precompile_live)
    register_live_display_semantic_handlers!(SemanticDispatcher(), :precompile_live, precompile_live_state)
    Core.render!(buffer, precompile_live, Core.Rect(10, 1, 1, 24), precompile_live_state)
    precompile_tracker = ProgressTracker()
    add_progress_task!(precompile_tracker, :build; description="Build", total=10)
    advance_progress!(precompile_tracker, :build, 5)
    precompile_progress_group = ProgressGroup(precompile_tracker; width=24, height=2)
    precompile_progress_group_state = state_for(precompile_progress_group)
    register_progress_group_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_progress_group,
        precompile_progress_group,
        precompile_progress_group_state,
    )
    Core.render!(buffer, precompile_progress_group, Core.Rect(10, 1, 2, 24), precompile_progress_group_state)
    precompile_process_view = ProcessView(ProcessResult(`echo ok`, 0, collect(codeunits("ok")), UInt8[]); width=24, height=2)
    precompile_process_view_state = state_for(precompile_process_view)
    register_process_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_process_view,
        precompile_process_view,
        precompile_process_view_state,
    )
    Core.render!(buffer, precompile_process_view, Core.Rect(10, 1, 2, 24), precompile_process_view_state)
    precompile_terminal = TerminalView("build complete"; width=24, height=2)
    precompile_terminal_state = state_for(precompile_terminal)
    register_terminal_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_terminal,
        precompile_terminal,
        precompile_terminal_state,
    )
    Core.render!(buffer, precompile_terminal, Core.Rect(10, 1, 2, 24), precompile_terminal_state)
    precompile_monitor = TaskMonitor([Task(() -> nothing)]; width=24, height=2)
    precompile_monitor_state = state_for(precompile_monitor)
    register_task_monitor_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_monitor,
        precompile_monitor,
        precompile_monitor_state,
    )
    Core.render!(buffer, precompile_monitor, Core.Rect(10, 1, 2, 24), precompile_monitor_state)
    precompile_tail = LogTail(log_state; width=24, height=2)
    register_log_tail_semantic_handlers!(SemanticDispatcher(), :precompile_tail, precompile_tail, log_state)
    Core.render!(buffer, precompile_tail, Core.Rect(10, 1, 2, 24), log_state)
    precompile_repl = ReplView(command -> "echo: " * command; width=24, height=3)
    precompile_repl_state = state_for(precompile_repl)
    register_repl_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_repl,
        precompile_repl,
        precompile_repl_state,
    )
    Core.render!(buffer, precompile_repl, Core.Rect(10, 1, 3, 24), precompile_repl_state)
    precompile_ansi = AnsiView("\e[32mok\e[0m"; width=20, height=1)
    precompile_ansi_state = state_for(precompile_ansi)
    register_ansi_view_semantic_handlers!(SemanticDispatcher(), :precompile_ansi, precompile_ansi, precompile_ansi_state)
    Core.render!(buffer, precompile_ansi, Core.Rect(10, 25, 1, 20), precompile_ansi_state)
    precompile_hyperlink = Hyperlink("Docs", :docs)
    precompile_hyperlink_state = state_for(precompile_hyperlink)
    register_hyperlink_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_hyperlink,
        precompile_hyperlink,
        precompile_hyperlink_state,
    )
    Core.render!(buffer, precompile_hyperlink, Core.Rect(11, 25, 1, 20), precompile_hyperlink_state)
    precompile_link = Link("Open docs", :open_docs)
    precompile_link_state = state_for(precompile_link)
    register_link_semantic_handlers!(SemanticDispatcher(), :precompile_link, precompile_link, precompile_link_state)
    Core.render!(buffer, precompile_link, Core.Rect(11, 1, 1, 24), precompile_link_state)
    precompile_image = RasterImage(1, 1, RGBA32, UInt8[0xff, 0x00, 0x00, 0xff])
    precompile_image_view = ImageView(precompile_image; width=2, height=1)
    register_image_view_semantic_handlers!(SemanticDispatcher(), :precompile_image_view, precompile_image_view)
    Core.render!(buffer, precompile_image_view, Core.Rect(12, 1, 1, 2))
    precompile_braille_image = BrailleImage(precompile_image; width=2, height=1)
    register_braille_image_semantic_handlers!(SemanticDispatcher(), :precompile_braille_image, precompile_braille_image)
    Core.render!(buffer, precompile_braille_image, Core.Rect(12, 4, 1, 2))
    theme_registry = ThemeRegistry()
    precompile_theme_preview = ThemePreview(theme_registry; width=20, height=2)
    precompile_theme_preview_state = ThemePreviewState()
    register_theme_preview_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_theme_preview,
        precompile_theme_preview,
        precompile_theme_preview_state,
    )
    Core.render!(buffer, precompile_theme_preview, Core.Rect(10, 25, 2, 20), precompile_theme_preview_state)

    precompile_border = Border(title="Border")
    register_border_semantic_handlers!(SemanticDispatcher(), :precompile_border, precompile_border)
    Core.render!(buffer, precompile_border, Core.Rect(1, 25, 3, 20))
    precompile_card = Card(Widgets.Label("Card"))
    register_card_semantic_handlers!(SemanticDispatcher(), :precompile_card, precompile_card)
    Core.render!(buffer, precompile_card, Core.Rect(1, 25, 3, 20))
    precompile_panel = Panel(Widgets.Label("Panel"))
    register_panel_semantic_handlers!(SemanticDispatcher(), :precompile_panel, precompile_panel)
    Core.render!(buffer, precompile_panel, Core.Rect(1, 25, 3, 20))
    precompile_layer = Layer(Widgets.Label("Back"), Widgets.Label("Front"))
    register_layer_semantic_handlers!(SemanticDispatcher(), :precompile_layer, precompile_layer)
    Core.render!(buffer, precompile_layer, Core.Rect(1, 25, 3, 20))
    precompile_group = Group(Widgets.Label("One"), Widgets.Label("Two"); gap=1)
    register_group_semantic_handlers!(SemanticDispatcher(), :precompile_group, precompile_group)
    Core.render!(buffer, precompile_group, Core.Rect(1, 25, 3, 20))
    precompile_flow = Flow(Widgets.Label("One"), Widgets.Label("Two"); column_gap=1)
    register_flow_semantic_handlers!(SemanticDispatcher(), :precompile_flow, precompile_flow)
    Core.render!(buffer, precompile_flow, Core.Rect(1, 25, 3, 20))
    precompile_wrap = Wrap(Widgets.Label("One"), Widgets.Label("Two"); column_gap=1)
    register_wrap_semantic_handlers!(SemanticDispatcher(), :precompile_wrap, precompile_wrap)
    Core.render!(buffer, precompile_wrap, Core.Rect(1, 25, 3, 20))
    precompile_sidebar = Sidebar(Widgets.Label("Nav"), Widgets.Label("Content"); sidebar_size=6, gap=1)
    register_sidebar_semantic_handlers!(SemanticDispatcher(), :precompile_sidebar, precompile_sidebar)
    Core.render!(buffer, precompile_sidebar, Core.Rect(1, 25, 4, 24))
    precompile_dock_layout = DockLayout(top=Widgets.Label("Top"), top_size=1, center=Widgets.Label("Center"))
    register_dock_layout_semantic_handlers!(SemanticDispatcher(), :precompile_dock_layout, precompile_dock_layout)
    Core.render!(buffer, precompile_dock_layout, Core.Rect(1, 25, 4, 24))
    precompile_dock = Dock(top=Widgets.Label("Top"), top_size=1, center=Widgets.Label("Center"))
    register_dock_semantic_handlers!(SemanticDispatcher(), :precompile_dock, precompile_dock)
    Core.render!(buffer, precompile_dock, Core.Rect(1, 25, 4, 24))
    precompile_app_shell = AppShell(
        Widgets.Label("Center");
        title="Wicked",
        sidebar=Widgets.Label("Nav"),
        sidebar_size=8,
        shortcuts=[:q => "Quit"],
    )
    register_app_shell_semantic_handlers!(SemanticDispatcher(), :precompile_app_shell, precompile_app_shell)
    app_shell_dock(precompile_app_shell)
    app_shell_layout(precompile_app_shell)
    app_shell_regions(precompile_app_shell, Core.Rect(1, 25, 5, 24))
    app_shell_summary(precompile_app_shell)
    Core.render!(buffer, precompile_app_shell, Core.Rect(1, 25, 5, 24))
    precompile_padding = Padding(Widgets.Label("Padding"); margin=Margin(1))
    register_padding_semantic_handlers!(SemanticDispatcher(), :precompile_padding, precompile_padding)
    Core.render!(buffer, precompile_padding, Core.Rect(1, 25, 3, 20))
    precompile_box = Box(Widgets.Label("Box"); block=Block(title="Box"))
    register_box_semantic_handlers!(SemanticDispatcher(), :precompile_box, precompile_box)
    Core.render!(buffer, precompile_box, Core.Rect(1, 25, 3, 20))
    precompile_row = Row(Widgets.Label("One"), Widgets.Label("Two"); gap=1)
    register_row_semantic_handlers!(SemanticDispatcher(), :precompile_row, precompile_row)
    Core.render!(buffer, precompile_row, Core.Rect(1, 25, 3, 20))
    precompile_column = Column(Widgets.Label("One"), Widgets.Label("Two"); gap=1)
    register_column_semantic_handlers!(SemanticDispatcher(), :precompile_column, precompile_column)
    Core.render!(buffer, precompile_column, Core.Rect(1, 25, 3, 20))
    precompile_stack = Stack(Widgets.Label("Back"), Widgets.Label("Front"))
    register_stack_semantic_handlers!(SemanticDispatcher(), :precompile_stack, precompile_stack)
    Core.render!(buffer, precompile_stack, Core.Rect(1, 25, 3, 20))
    precompile_overlay = Overlay(Widgets.Label("Base"), Widgets.Label("Overlay"))
    register_overlay_semantic_handlers!(SemanticDispatcher(), :precompile_overlay, precompile_overlay)
    Core.render!(buffer, precompile_overlay, Core.Rect(1, 25, 3, 20))
    precompile_center = Center(Widgets.Label("Center"); height=1, width=8)
    register_center_semantic_handlers!(SemanticDispatcher(), :precompile_center, precompile_center)
    Core.render!(buffer, precompile_center, Core.Rect(1, 25, 3, 20))
    precompile_grid = Grid(Widgets.Label("A"); rows=[Layout.Fill(1)], columns=[Layout.Fill(1)])
    register_grid_semantic_handlers!(SemanticDispatcher(), :precompile_grid, precompile_grid)
    Core.render!(buffer, precompile_grid, Core.Rect(1, 25, 3, 20))
    precompile_split_pane = SplitPane(Widgets.Label("Left"), Widgets.Label("Right"); fraction=0.5, gap=1)
    register_split_pane_semantic_handlers!(SemanticDispatcher(), :precompile_split_pane, precompile_split_pane)
    Core.render!(buffer, precompile_split_pane, Core.Rect(1, 25, 3, 20))
    precompile_resizable_pane = ResizablePane(Widgets.Label("Left"), Widgets.Label("Right"); fraction=0.5, gap=1)
    precompile_resizable_pane_state = state_for(precompile_resizable_pane)
    register_resizable_pane_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_resizable_pane,
        precompile_resizable_pane,
        precompile_resizable_pane_state,
    )
    Core.render!(buffer, precompile_resizable_pane, Core.Rect(1, 25, 3, 20), precompile_resizable_pane_state)
    precompile_button = Widgets.Button("Run", :run)
    precompile_button_state = Widgets.ButtonState()
    register_button_semantic_handlers!(SemanticDispatcher(), :precompile_button, precompile_button, precompile_button_state)
    Core.render!(buffer, precompile_button, Core.Rect(1, 1, 3, 16), precompile_button_state)
    precompile_input = Widgets.Input(placeholder="Project")
    precompile_input_state = Widgets.InputState("Wicked")
    register_input_semantic_handlers!(SemanticDispatcher(), :precompile_input, precompile_input, precompile_input_state)
    Core.render!(buffer, precompile_input, Core.Rect(4, 1, 1, 24), precompile_input_state)
    precompile_text_box = Widgets.TextBox(placeholder="Project")
    precompile_text_box_state = Widgets.TextBoxState("Wicked")
    register_text_box_semantic_handlers!(SemanticDispatcher(), :precompile_text_box, precompile_text_box, precompile_text_box_state)
    Core.render!(buffer, precompile_text_box, Core.Rect(4, 1, 1, 24), precompile_text_box_state)
    precompile_text_input = Widgets.TextInput(placeholder="Search")
    precompile_text_input_state = Widgets.TextInputState("q")
    register_text_input_semantic_handlers!(SemanticDispatcher(), :precompile_text_input, precompile_text_input, precompile_text_input_state)
    Core.render!(buffer, precompile_text_input, Core.Rect(4, 1, 1, 24), precompile_text_input_state)
    precompile_text_field = Widgets.TextField(placeholder="Project")
    precompile_text_field_state = Widgets.TextFieldState("Wicked")
    register_text_field_semantic_handlers!(SemanticDispatcher(), :precompile_text_field, precompile_text_field, precompile_text_field_state)
    Core.render!(buffer, precompile_text_field, Core.Rect(4, 1, 1, 24), precompile_text_field_state)
    precompile_password_input = Widgets.PasswordInput(placeholder="Password")
    precompile_password_input_state = Widgets.TextInputState("secret")
    register_password_input_semantic_handlers!(SemanticDispatcher(), :precompile_password_input, precompile_password_input, precompile_password_input_state)
    Core.render!(buffer, precompile_password_input, Core.Rect(5, 1, 1, 24), precompile_password_input_state)
    precompile_password_field = Widgets.PasswordField(placeholder="Password")
    precompile_password_field_state = Widgets.PasswordFieldState("secret")
    register_password_field_semantic_handlers!(SemanticDispatcher(), :precompile_password_field, precompile_password_field, precompile_password_field_state)
    Core.render!(buffer, precompile_password_field, Core.Rect(5, 1, 1, 24), precompile_password_field_state)
    precompile_search_input = Widgets.SearchInput(placeholder="Search")
    precompile_search_input_state = Widgets.SearchInputState("q")
    register_search_input_semantic_handlers!(SemanticDispatcher(), :precompile_search_input, precompile_search_input, precompile_search_input_state)
    Core.render!(buffer, precompile_search_input, Core.Rect(4, 25, 1, 20), precompile_search_input_state)
    precompile_number_input = Widgets.NumberInput(placeholder="Port")
    precompile_number_input_state = Widgets.NumberInputState(value=8080, minimum=1, maximum=65_535)
    register_number_input_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_number_input,
        precompile_number_input,
        precompile_number_input_state,
    )
    Core.render!(buffer, precompile_number_input, Core.Rect(5, 25, 1, 20), precompile_number_input_state)
    precompile_masked_input = MaskedInput("##-AA")
    precompile_masked_input_state = state_for(precompile_masked_input)
    register_masked_input_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_masked_input,
        precompile_masked_input,
        precompile_masked_input_state,
    )
    Core.render!(buffer, precompile_masked_input, Core.Rect(5, 25, 1, 20), precompile_masked_input_state)
    precompile_text_area = Widgets.TextArea()
    precompile_text_area_state = Widgets.TextAreaState("note")
    register_text_area_semantic_handlers!(SemanticDispatcher(), :precompile_text_area, precompile_text_area, precompile_text_area_state)
    Core.render!(buffer, precompile_text_area, Core.Rect(6, 1, 2, 24), precompile_text_area_state)
    precompile_textarea = Widgets.Textarea()
    precompile_textarea_state = Widgets.TextAreaState("note")
    register_textarea_semantic_handlers!(SemanticDispatcher(), :precompile_textarea, precompile_textarea, precompile_textarea_state)
    Core.render!(buffer, precompile_textarea, Core.Rect(6, 1, 2, 24), precompile_textarea_state)
    precompile_header = Header("Wicked"; subtitle="Precompile")
    register_header_semantic_handlers!(SemanticDispatcher(), :precompile_header, precompile_header)
    Core.render!(buffer, precompile_header, Core.Rect(1, 1, 2, 24))
    precompile_footer = Footer([:q => "Quit"])
    register_footer_semantic_handlers!(SemanticDispatcher(), :precompile_footer, precompile_footer)
    Core.render!(buffer, precompile_footer, Core.Rect(12, 1, 1, 24))
    precompile_title_bar = TitleBar("Wicked"; subtitle="Precompile")
    register_title_bar_semantic_handlers!(SemanticDispatcher(), :precompile_title_bar, precompile_title_bar)
    Core.render!(buffer, precompile_title_bar, Core.Rect(1, 1, 2, 24))
    precompile_status_bar = StatusBar([:q => "Quit"])
    register_status_bar_semantic_handlers!(SemanticDispatcher(), :precompile_status_bar, precompile_status_bar)
    Core.render!(buffer, precompile_status_bar, Core.Rect(12, 1, 1, 24))
    precompile_menu_bar = MenuBar(Label("File"), Label("Edit"))
    register_menu_bar_semantic_handlers!(SemanticDispatcher(), :precompile_menu_bar, precompile_menu_bar)
    Core.render!(buffer, precompile_menu_bar, Core.Rect(2, 1, 1, 24))
    precompile_toolbar = Toolbar(Label("Run"), Label("Stop"))
    register_toolbar_semantic_handlers!(SemanticDispatcher(), :precompile_toolbar, precompile_toolbar)
    Core.render!(buffer, precompile_toolbar, Core.Rect(3, 1, 1, 24))
    precompile_shortcuts = ShortcutBar([KeyHint("q", "Quit")])
    register_shortcut_bar_semantic_handlers!(SemanticDispatcher(), :precompile_shortcuts, precompile_shortcuts)
    Core.render!(buffer, precompile_shortcuts, Core.Rect(4, 1, 1, 24))
    precompile_badge = Badge("READY")
    register_badge_semantic_handlers!(SemanticDispatcher(), :precompile_badge, precompile_badge)
    Core.render!(buffer, precompile_badge, Core.Rect(1, 25, 1, 20))
    precompile_status = Status("Cache warm"; severity=:success)
    register_status_semantic_handlers!(SemanticDispatcher(), :precompile_status, precompile_status)
    Core.render!(buffer, precompile_status, Core.Rect(2, 25, 3, 20))
    precompile_alert = Alert("Precompile warning"; severity=:warning)
    register_alert_semantic_handlers!(SemanticDispatcher(), :precompile_alert, precompile_alert)
    Core.render!(buffer, precompile_alert, Core.Rect(2, 25, 3, 20))
    precompile_toast = Toast("Saved"; title="Build", severity=:success)
    register_toast_semantic_handlers!(SemanticDispatcher(), :precompile_toast, precompile_toast)
    Core.render!(buffer, precompile_toast, Core.Rect(6, 25, 1, 20))
    center = NotificationCenter(2)
    push_notification!(center, Notification("Ready"; id=:ready, title="Build", severity=:success))
    precompile_notification_view = NotificationView(center)
    register_notification_view_semantic_handlers!(SemanticDispatcher(), :precompile_notifications, precompile_notification_view)
    Core.render!(buffer, precompile_notification_view, Core.Rect(7, 25, 2, 20))
    manager = NotificationManager()
    notify!(manager, "Deployment completed"; id=:deploy, title="Deploy", severity=:success)
    precompile_managed_notifications = ManagedNotificationView(manager)
    precompile_notification_binding = register_managed_notification_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_managed_notifications,
        precompile_managed_notifications,
    )
    unbind_notification_semantics!(precompile_notification_binding)
    Core.render!(buffer, precompile_managed_notifications, Core.Rect(7, 25, 2, 20))
    tracker = ProgressTracker{Symbol}()
    add_progress_task!(tracker, :build; description="Building", total=10)
    advance_progress!(tracker, :build, 4)
    precompile_progress = Progress(aggregate_progress(tracker); label="Build")
    precompile_progress_state = ProgressState()
    register_progress_semantic_handlers!(SemanticDispatcher(), :precompile_progress, precompile_progress, precompile_progress_state)
    Core.render!(buffer, precompile_progress, Core.Rect(9, 25, 1, 20), precompile_progress_state)
    issues = ValidationIssue[ValidationIssue(:required, "Name is required")]
    precompile_validation_message = ValidationMessage(issues)
    register_validation_message_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_validation_message,
        precompile_validation_message,
    )
    Core.render!(buffer, precompile_validation_message, Core.Rect(10, 25, 1, 20))
    form = Form([FormField(:name; label="Name", initial="")])
    form_state = FormState(form)
    register_form_semantic_handlers!(SemanticDispatcher(), :precompile_form, form, form_state)
    field_state(form_state, :name).issues = issues
    precompile_validation_summary = ValidationSummary(form, form_state)
    register_validation_summary_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_validation_summary,
        precompile_validation_summary,
    )
    Core.render!(buffer, precompile_validation_summary, Core.Rect(10, 25, 2, 20))
    precompile_push_button = Widgets.PushButton("Launch", :launch)
    precompile_push_button_state = Widgets.PushButtonState()
    register_push_button_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_push_button,
        precompile_push_button,
        precompile_push_button_state,
    )
    Core.render!(buffer, precompile_push_button, Core.Rect(3, 25, 3, 20), precompile_push_button_state)
    precompile_split_button = SplitButton("Deploy", :deploy)
    precompile_split_button_state = SplitButtonState()
    register_split_button_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_split_button,
        precompile_split_button,
        precompile_split_button_state,
    )
    Core.render!(buffer, precompile_split_button, Core.Rect(3, 25, 3, 20), precompile_split_button_state)
    palette = CommandPalette([CommandItem(:open, "Open"), CommandItem(:deploy, "Deploy")])
    palette_state = CommandPaletteState(open=true)
    set_command_palette_query!(palette_state, palette, "dep"; record=false)
    command_palette_query(palette_state)
    command_palette_filtered_commands(palette, palette_state)
    command_palette_selected_command(palette, palette_state)
    select_next_command!(palette_state, palette)
    select_previous_command!(palette_state, palette)
    select_command!(palette_state, palette, 1)
    register_command_palette_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_palette,
        palette,
        palette_state,
    )
    Core.render!(
        buffer,
        palette,
        Core.Rect(3, 25, 3, 24),
        palette_state,
    )
    precompile_autocomplete = Autocomplete(["Open", "Deploy"]; max_visible=2)
    precompile_autocomplete_state = state_for(precompile_autocomplete)
    update_autocomplete!(precompile_autocomplete_state, "dep")
    register_autocomplete_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_autocomplete,
        precompile_autocomplete,
        precompile_autocomplete_state,
    )
    Core.render!(buffer, precompile_autocomplete, Core.Rect(6, 25, 2, 20), precompile_autocomplete_state)
    precompile_combobox = ComboBox(["Debug", "Release"]; max_visible=2)
    precompile_combobox_state = state_for(precompile_combobox)
    register_combo_box_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_combobox,
        precompile_combobox,
        precompile_combobox_state,
    )
    Core.render!(buffer, precompile_combobox, Core.Rect(8, 1, 2, 20), precompile_combobox_state)
    precompile_tags = TagInput(["julia", "tui"]; width=20)
    precompile_tags_state = state_for(precompile_tags)
    register_tag_input_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_tags,
        precompile_tags,
        precompile_tags_state,
    )
    Core.render!(buffer, precompile_tags, Core.Rect(5, 1, 1, 20), precompile_tags_state)
    precompile_menu = ContextMenu([MenuItem(:copy, "Copy"), MenuItem(:paste, "Paste")])
    precompile_menu_state = MenuState()
    select_next_menu_item!(precompile_menu_state, precompile_menu.menu)
    select_previous_menu_item!(precompile_menu_state, precompile_menu.menu)
    select_menu_item!(precompile_menu_state, precompile_menu.menu, 1)
    selected_menu_item(precompile_menu.menu, precompile_menu_state)
    selected_menu_message(precompile_menu.menu, precompile_menu_state)
    register_context_menu_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_menu,
        precompile_menu,
        precompile_menu_state,
    )
    precompile_menu_button = MenuButton("Open", :open)
    precompile_menu_button_state = MenuButtonState()
    register_menu_button_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_menu_button,
        precompile_menu_button,
        precompile_menu_button_state,
    )
    Core.render!(buffer, precompile_menu_button, Core.Rect(1, 25, 2, 20), precompile_menu_button_state)
    Core.render!(buffer, precompile_menu, Core.Rect(2, 25, 2, 20), precompile_menu_state)
    Core.render!(buffer, MenuBar(Widgets.Label("File"), Widgets.Label("Edit")), Core.Rect(1, 1, 1, 24))
    precompile_tabs = Tabs([Tab(:one, "One"), Tab(:two, "Two")])
    precompile_tabs_state = TabsState()
    select_next_tab!(precompile_tabs_state, precompile_tabs)
    select_previous_tab!(precompile_tabs_state, precompile_tabs)
    select_tab!(precompile_tabs_state, precompile_tabs, 2)
    selected_tab(precompile_tabs, precompile_tabs_state)
    register_tabs_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_tabs,
        precompile_tabs,
        precompile_tabs_state,
    )
    Core.render!(buffer, precompile_tabs, Core.Rect(2, 1, 1, 24), precompile_tabs_state)
    precompile_tab_view = TabView([:one => "One", :two => "Two"], [Widgets.Label("One"), Widgets.Label("Two")])
    precompile_tab_view_state = TabViewState()
    select_next_tab_view!(precompile_tab_view_state, precompile_tab_view)
    select_previous_tab_view!(precompile_tab_view_state, precompile_tab_view)
    select_tab_view!(precompile_tab_view_state, precompile_tab_view, 2)
    select_tab!(precompile_tab_view_state, precompile_tab_view, 1)
    selected_tab_view(precompile_tab_view, precompile_tab_view_state)
    selected_tab_view_content(precompile_tab_view, precompile_tab_view_state)
    register_tab_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_tab_view,
        precompile_tab_view,
        precompile_tab_view_state,
    )
    Core.render!(buffer, precompile_tab_view, Core.Rect(3, 1, 3, 24), precompile_tab_view_state)
    precompile_navigation_rail = NavigationRail([
        MenuItem(:home, "Home", :home),
        MenuItem(:logs, "Logs", :logs),
        MenuItem(:settings, "Settings", :settings),
    ])
    precompile_navigation_rail_state = state_for(precompile_navigation_rail)
    select_next_navigation_item!(precompile_navigation_rail_state, precompile_navigation_rail)
    select_previous_navigation_item!(precompile_navigation_rail_state, precompile_navigation_rail)
    select_navigation_item!(precompile_navigation_rail_state, precompile_navigation_rail, 2)
    selected_navigation_item(precompile_navigation_rail, precompile_navigation_rail_state)
    selected_navigation_message(precompile_navigation_rail, precompile_navigation_rail_state)
    register_navigation_rail_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_navigation_rail,
        precompile_navigation_rail,
        precompile_navigation_rail_state,
    )
    Core.render!(buffer, precompile_navigation_rail, Core.Rect(3, 1, 3, 20), precompile_navigation_rail_state)
    precompile_breadcrumb = Breadcrumb([BreadcrumbItem("Home", :home), BreadcrumbItem("Build", :build)])
    precompile_breadcrumb_state = state_for(precompile_breadcrumb)
    select_next_breadcrumb_item!(precompile_breadcrumb_state, precompile_breadcrumb)
    select_previous_breadcrumb_item!(precompile_breadcrumb_state, precompile_breadcrumb)
    select_breadcrumb_item!(precompile_breadcrumb_state, precompile_breadcrumb, 2)
    selected_breadcrumb_item(precompile_breadcrumb, precompile_breadcrumb_state)
    selected_breadcrumb_value(precompile_breadcrumb, precompile_breadcrumb_state)
    activate_selected_breadcrumb!(precompile_breadcrumb_state, precompile_breadcrumb)
    register_breadcrumb_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_breadcrumb,
        precompile_breadcrumb,
        precompile_breadcrumb_state,
    )
    Core.render!(buffer, precompile_breadcrumb, Core.Rect(2, 1, 1, 24), precompile_breadcrumb_state)
    precompile_pagination = Pagination(50; page_size=10, width=20)
    precompile_pagination_state = state_for(precompile_pagination)
    next_page!(precompile_pagination_state)
    previous_page!(precompile_pagination_state)
    set_page!(precompile_pagination_state, 3)
    register_pagination_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_pagination,
        precompile_pagination_state,
    )
    Core.render!(buffer, precompile_pagination, Core.Rect(2, 25, 1, 20), precompile_pagination_state)
    precompile_properties = PropertyList(["status" => "ready", "owner" => "ops"]; width=24, height=2)
    precompile_properties_state = state_for(precompile_properties)
    register_property_list_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_properties,
        precompile_properties,
        precompile_properties_state,
    )
    Core.render!(buffer, precompile_properties, Core.Rect(3, 1, 2, 24), precompile_properties_state)
    precompile_query_source = QueryDataSource(
        [(name="Build", status="ready"), (name="Test", status="queued")];
        key=(row, _) -> row.name,
        query=DataQuery(
            sort=[SortTerm(:name, AscendingSort)],
            filters=Dict(:status => "ready"),
            search="Build",
        ),
        search_text=row -> "$(row.name) $(row.status)",
    )
    query_data_source(precompile_query_source)
    data_query_summary(query_data_source(precompile_query_source))
    data_query_text(query_data_source(precompile_query_source))
    data_query_markdown(query_data_source(precompile_query_source))
    data_query_tsv(query_data_source(precompile_query_source))
    fetch_items(precompile_query_source, 1:1)
    set_query_search!(precompile_query_source, "Test")
    set_query_filter!(precompile_query_source, :status, "queued")
    clear_query_filter!(precompile_query_source, :status)
    set_query_filter!(precompile_query_source, :status, query_equals("ready"))
    set_query_filter!(precompile_query_source, :name, query_contains("B"))
    set_query_filter!(precompile_query_source, :name, query_regex(r"Build|Test"))
    set_query_filter!(precompile_query_source, :name, query_range(minimum="A", maximum="Z"))
    toggle_query_sort!(precompile_query_source, :name)
    clear_query!(precompile_query_source)
    set_data_query!(precompile_query_source, DataQuery(search="Test"))
    precompile_table_layout = TableLayoutState([
        VirtualTableColumn(:name, "Name"),
        VirtualTableColumn(:status, "Status"),
    ])
    set_virtual_search!(precompile_table_layout, "Build")
    set_virtual_filter!(precompile_table_layout, :status, "ready")
    toggle_virtual_sort!(precompile_table_layout, :name)
    virtual_table_query(precompile_table_layout)
    data_query_summary(virtual_table_query(precompile_table_layout))
    table_layout_snapshot(precompile_table_layout)
    restore_table_layout!(precompile_table_layout, table_layout_snapshot(precompile_table_layout))
    apply_virtual_table_query!(precompile_query_source, precompile_table_layout)
    precompile_column_visibility = ColumnVisibilityState(hidden=[:status])
    column_visibility_snapshot(precompile_column_visibility)
    restore_column_visibility!(
        precompile_column_visibility,
        column_visibility_snapshot(precompile_column_visibility),
    )
    virtual_column_visible(precompile_column_visibility, :name)
    visible_virtual_columns(
        [
            VirtualTableColumn(:name, "Name"),
            VirtualTableColumn(:status, "Status"),
        ],
        precompile_column_visibility,
    )
    apply_virtual_column_visibility(
        [
            VirtualTableColumn(:name, "Name"),
            VirtualTableColumn(:status, "Status"),
        ],
        precompile_table_layout,
        precompile_column_visibility,
    )
    show_virtual_column!(precompile_column_visibility, :status)
    hide_virtual_column!(precompile_column_visibility, :status)
    toggle_virtual_column_visibility!(precompile_column_visibility, :status)
    precompile_column_pins = ColumnPinState(left=[:name])
    column_pin_snapshot(precompile_column_pins)
    restore_column_pin!(precompile_column_pins, column_pin_snapshot(precompile_column_pins))
    pin_virtual_column_right!(precompile_column_pins, :status)
    virtual_column_pin_position(precompile_column_pins, :name)
    pinned_virtual_columns(
        [
            VirtualTableColumn(:name, "Name"),
            VirtualTableColumn(:status, "Status"),
        ],
        precompile_column_pins,
    )
    apply_virtual_column_pinning(
        [
            VirtualTableColumn(:name, "Name"),
            VirtualTableColumn(:status, "Status"),
        ],
        precompile_table_layout,
        precompile_column_pins,
    )
    toggle_virtual_column_pin!(precompile_column_pins, :status; side=:right)
    unpin_virtual_column!(precompile_column_pins, :name)
    precompile_column_actions = default_virtual_column_actions()
    virtual_column_action_enabled(first(precompile_column_actions), :status, precompile_table_layout; visibility=precompile_column_visibility, pinning=precompile_column_pins)
    virtual_column_action_menu(precompile_column_actions, :status, precompile_table_layout; visibility=precompile_column_visibility, pinning=precompile_column_pins)
    virtual_column_action_records(precompile_column_actions, :status, precompile_table_layout; visibility=precompile_column_visibility, pinning=precompile_column_pins)
    virtual_column_action_for_shortcut(precompile_column_actions, "s", :status, precompile_table_layout; visibility=precompile_column_visibility, pinning=precompile_column_pins)
    precompile_column_result = invoke_virtual_column_action(precompile_column_actions, :sort, :status, precompile_table_layout; visibility=precompile_column_visibility, pinning=precompile_column_pins)
    invoke_virtual_column_action_shortcut(precompile_column_actions, "s", :status, precompile_table_layout; visibility=precompile_column_visibility, pinning=precompile_column_pins)
    virtual_column_action_summary(precompile_column_result)
    virtual_column_action_text(precompile_column_result)
    virtual_column_action_markdown(precompile_column_result)
    virtual_column_action_tsv(precompile_column_result)
    invoke_virtual_column_action(precompile_column_actions, :pin_left, :status, precompile_table_layout; visibility=precompile_column_visibility, pinning=precompile_column_pins)
    invoke_virtual_column_action(precompile_column_actions, :unpin, :status, precompile_table_layout; visibility=precompile_column_visibility, pinning=precompile_column_pins)
    precompile_row_actions = [
        VirtualRowAction(:open, "Open"; handler=(item, index, key) -> item.name, shortcut="enter"),
        VirtualRowAction(:retry, "Retry"; enabled=(item, index, key) -> item.status != "ready", shortcut="r"),
    ]
    precompile_row = (name="Build", status="ready")
    virtual_row_action_enabled(first(precompile_row_actions), precompile_row, 1; key=precompile_row.name)
    virtual_row_action_menu(precompile_row_actions, precompile_row, 1; key=precompile_row.name)
    virtual_row_action_records(precompile_row_actions, precompile_row, 1; key=precompile_row.name)
    virtual_row_action_for_shortcut(precompile_row_actions, "enter", precompile_row, 1; key=precompile_row.name)
    invoke_virtual_row_action(first(precompile_row_actions), precompile_row, 1; key=precompile_row.name)
    invoke_virtual_row_action(precompile_row_actions, :open, precompile_row, 1; key=precompile_row.name)
    invoke_virtual_row_action_shortcut(precompile_row_actions, "enter", precompile_row, 1; key=precompile_row.name)
    precompile_table_preferences = table_preferences_bundle(
        precompile_table_layout;
        visibility=precompile_column_visibility,
        pinning=precompile_column_pins,
        column_actions=precompile_column_actions,
        row_actions=precompile_row_actions,
    )
    table_preferences_summary(precompile_table_preferences)
    table_preferences_text(precompile_table_preferences)
    table_preferences_markdown(precompile_table_preferences)
    table_preferences_tsv(precompile_table_preferences)
    restore_table_preferences!(
        precompile_table_layout,
        precompile_table_preferences;
        visibility=precompile_column_visibility,
        pinning=precompile_column_pins,
    )
    apply_table_preferences(
        [
            VirtualTableColumn(:name, "Name"),
            VirtualTableColumn(:status, "Status"),
        ],
        precompile_table_layout;
        visibility=precompile_column_visibility,
        pinning=precompile_column_pins,
    )
    data_length(precompile_query_source)
    precompile_data_state_ready = DataStateView(precompile_properties)
    precompile_data_state_loading = DataStateView(precompile_properties; status=DataLoading)
    data_state_status(precompile_data_state_ready)
    data_state_ready(precompile_data_state_ready)
    data_state_loading(precompile_data_state_loading)
    data_state_empty(DataStateView(precompile_properties; status=DataEmpty))
    data_state_error(DataStateView(precompile_properties; status=DataError))
    register_data_state_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_data_state_loading,
        precompile_data_state_loading,
    )
    Core.render!(buffer, precompile_data_state_ready, Core.Rect(9, 1, 2, 24), precompile_properties_state)
    Core.render!(buffer, precompile_data_state_loading, Core.Rect(11, 1, 1, 24))
    precompile_key_values = KeyValueList(["mode" => "prod", "region" => "eu"]; width=24, height=2)
    precompile_key_values_state = state_for(precompile_key_values)
    register_key_value_list_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_key_values,
        precompile_key_values,
        precompile_key_values_state,
    )
    Core.render!(buffer, precompile_key_values, Core.Rect(5, 1, 2, 24), precompile_key_values_state)
    precompile_metadata = MetadataList(["version" => "dev", "profile" => "ci"]; width=24, height=2)
    precompile_metadata_state = state_for(precompile_metadata)
    register_metadata_list_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_metadata,
        precompile_metadata,
        precompile_metadata_state,
    )
    Core.render!(buffer, precompile_metadata, Core.Rect(7, 1, 2, 24), precompile_metadata_state)
    precompile_descriptions = DescriptionList(["Build" => "Compile", "Release" => "Publish"]; width=24, height=2)
    precompile_descriptions_state = state_for(precompile_descriptions)
    register_description_list_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_descriptions,
        precompile_descriptions,
        precompile_descriptions_state,
    )
    Core.render!(buffer, precompile_descriptions, Core.Rect(3, 25, 2, 24), precompile_descriptions_state)
    precompile_definitions = DefinitionList(["Term" => "Definition", "Widget" => "Renderable"]; width=24, height=2)
    precompile_definitions_state = state_for(precompile_definitions)
    register_definition_list_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_definitions,
        precompile_definitions,
        precompile_definitions_state,
    )
    Core.render!(buffer, precompile_definitions, Core.Rect(5, 25, 2, 24), precompile_definitions_state)
    precompile_radio_button = RadioButton(:enabled, "Enabled")
    precompile_radio_button_state = state_for(precompile_radio_button)
    register_radio_button_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_radio_button,
        precompile_radio_button,
        precompile_radio_button_state,
    )
    Core.render!(buffer, precompile_radio_button, Core.Rect(4, 25, 1, 20), precompile_radio_button_state)
    choices = [ChoiceOption(:debug, "Debug"), ChoiceOption(:release, "Release")]
    precompile_radio = RadioGroup(choices)
    precompile_radio_state = RadioGroupState(selected=1)
    register_radio_group_semantic_handlers!(SemanticDispatcher(), :precompile_radio, precompile_radio, precompile_radio_state)
    Core.render!(buffer, precompile_radio, Core.Rect(4, 25, 2, 20), precompile_radio_state)
    precompile_radio_set = RadioSet(choices)
    precompile_radio_set_state = RadioSetState(selected=2)
    register_radio_set_semantic_handlers!(SemanticDispatcher(), :precompile_radio_set, precompile_radio_set, precompile_radio_set_state)
    Core.render!(buffer, precompile_radio_set, Core.Rect(4, 25, 2, 20), precompile_radio_set_state)
    precompile_select = Select(choices)
    precompile_select_state = SelectState(selected=1)
    register_select_semantic_handlers!(SemanticDispatcher(), :precompile_select, precompile_select, precompile_select_state)
    Core.render!(buffer, precompile_select, Core.Rect(6, 25, 2, 20), precompile_select_state)
    precompile_multi = MultiSelect(choices)
    precompile_multi_state = MultiSelectState(selected=[1])
    register_multi_select_semantic_handlers!(SemanticDispatcher(), :precompile_multi, precompile_multi, precompile_multi_state)
    Core.render!(buffer, precompile_multi, Core.Rect(6, 25, 2, 20), precompile_multi_state)
    precompile_selection = SelectionList(choices)
    precompile_selection_state = SelectionListState(selected=[2])
    register_selection_list_semantic_handlers!(SemanticDispatcher(), :precompile_selection, precompile_selection, precompile_selection_state)
    Core.render!(buffer, precompile_selection, Core.Rect(6, 25, 2, 20), precompile_selection_state)
    precompile_options = OptionList(["Build", "Test"])
    precompile_options_state = OptionListState(selected=1)
    register_option_list_semantic_handlers!(SemanticDispatcher(), :precompile_options, precompile_options, precompile_options_state)
    Core.render!(buffer, precompile_options, Core.Rect(5, 1, 2, 24), precompile_options_state)
    precompile_radio_boxes = Widgets.RadioBoxList([:debug => "Debug", :release => "Release"])
    precompile_radio_boxes_state = Widgets.RadioBoxListState(selected=1)
    register_radio_box_list_semantic_handlers!(SemanticDispatcher(), :precompile_radio_boxes, precompile_radio_boxes, precompile_radio_boxes_state)
    Core.render!(buffer, precompile_radio_boxes, Core.Rect(4, 25, 2, 20), precompile_radio_boxes_state)
    precompile_checklist = Widgets.CheckBoxList([:docs => "Docs", :tests => "Tests"])
    precompile_checklist_state = Widgets.CheckBoxListState(selected=[1])
    register_check_box_list_semantic_handlers!(SemanticDispatcher(), :precompile_checklist, precompile_checklist, precompile_checklist_state)
    Core.render!(buffer, precompile_checklist, Core.Rect(6, 25, 2, 20), precompile_checklist_state)
    Core.render!(buffer, Widgets.List(["Build", "Test", "Release"]), Core.Rect(5, 1, 3, 24))
    precompile_list_view = ListView(["Build", "Test", "Release"])
    precompile_list_view_state = state_for(precompile_list_view)
    register_list_view_semantic_handlers!(SemanticDispatcher(), :precompile_list_view, precompile_list_view, precompile_list_view_state)
    Core.render!(buffer, precompile_list_view, Core.Rect(5, 1, 3, 24), precompile_list_view_state)
    precompile_list_box = ListBox(["Build", "Test", "Release"])
    precompile_list_box_state = state_for(precompile_list_box)
    register_list_box_semantic_handlers!(SemanticDispatcher(), :precompile_list_box, precompile_list_box, precompile_list_box_state)
    Core.render!(buffer, precompile_list_box, Core.Rect(5, 25, 3, 20), precompile_list_box_state)
    precompile_combobox_dropdown = Combobox(["Debug", "Release"])
    precompile_combobox_dropdown_state = state_for(precompile_combobox_dropdown)
    register_combobox_semantic_handlers!(SemanticDispatcher(), :precompile_combobox_dropdown, precompile_combobox_dropdown, precompile_combobox_dropdown_state)
    Core.render!(buffer, precompile_combobox_dropdown, Core.Rect(8, 1, 2, 20), precompile_combobox_dropdown_state)
    precompile_transfer = TransferList(["Build", "Test"])
    precompile_transfer_state = state_for(precompile_transfer)
    register_transfer_list_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_transfer,
        precompile_transfer,
        precompile_transfer_state,
    )
    Core.render!(buffer, precompile_transfer, Core.Rect(8, 25, 2, 20), precompile_transfer_state)
    precompile_scroll_view = Widgets.ScrollView(Widgets.Label("scrollable"); height=4, width=20)
    precompile_scroll_view_state = Widgets.ScrollState(row=1)
    register_scroll_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_scroll_view,
        precompile_scroll_view,
        precompile_scroll_view_state;
        viewport_height=2,
    )
    Core.render!(buffer, precompile_scroll_view, Core.Rect(1, 25, 2, 20), precompile_scroll_view_state)
    precompile_scrollbar = Widgets.Scrollbar(Widgets.VerticalScrollbar, 100, 12)
    precompile_scrollbar_state = Widgets.ScrollState(row=3)
    register_scrollbar_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_scrollbar,
        precompile_scrollbar,
        precompile_scrollbar_state,
    )
    Core.render!(buffer, precompile_scrollbar, Core.Rect(1, 47, 12, 1), precompile_scrollbar_state)
    precompile_viewport = Viewport(Widgets.Label("viewport"); height=4, width=20)
    precompile_viewport_state = state_for(precompile_viewport)
    register_viewport_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_viewport,
        precompile_viewport,
        precompile_viewport_state;
        viewport_height=2,
    )
    Core.render!(buffer, precompile_viewport, Core.Rect(1, 25, 2, 20), precompile_viewport_state)
    precompile_spinner = Widgets.Spinner(frames=["-", "\\"], label="Loading")
    precompile_spinner_state = Widgets.SpinnerState()
    register_spinner_semantic_handlers!(SemanticDispatcher(), :precompile_spinner, precompile_spinner, precompile_spinner_state)
    Core.render!(buffer, precompile_spinner, Core.Rect(8, 1, 1, 24), precompile_spinner_state)
    precompile_loading = LoadingIndicator(frames=["-", "\\"], label="Loading")
    precompile_loading_state = LoadingIndicatorState()
    register_loading_indicator_semantic_handlers!(SemanticDispatcher(), :precompile_loading, precompile_loading, precompile_loading_state)
    Core.render!(buffer, precompile_loading, Core.Rect(8, 25, 1, 20), precompile_loading_state)
    precompile_skeleton = Skeleton()
    precompile_skeleton_state = SkeletonState(period=4)
    register_skeleton_semantic_handlers!(SemanticDispatcher(), :precompile_skeleton, precompile_skeleton, precompile_skeleton_state)
    Core.render!(buffer, precompile_skeleton, Core.Rect(9, 1, 1, 24), precompile_skeleton_state)
    precompile_placeholder = Placeholder("Loading region")
    register_placeholder_semantic_handlers!(SemanticDispatcher(), :precompile_placeholder, precompile_placeholder)
    Core.render!(buffer, precompile_placeholder, Core.Rect(9, 1, 1, 24))
    Core.render!(buffer, EmptyState("No results"; message="Try another query."), Core.Rect(9, 25, 3, 20))
    Core.render!(buffer, Progress(0.42; label="Building"), Core.Rect(11, 1, 1, 24), ProgressState())
    precompile_gauge = Gauge(0.75; label="Upload")
    register_gauge_semantic_handlers!(SemanticDispatcher(), :precompile_gauge, precompile_gauge)
    Core.render!(buffer, precompile_gauge, Core.Rect(10, 1, 3, 24))
    precompile_line_gauge = LineGauge(0.25)
    register_line_gauge_semantic_handlers!(SemanticDispatcher(), :precompile_line_gauge, precompile_line_gauge)
    Core.render!(buffer, precompile_line_gauge, Core.Rect(12, 1, 1, 24))
    precompile_sparkline = Sparkline([1.0, 2.0, 3.0])
    register_sparkline_semantic_handlers!(SemanticDispatcher(), :precompile_sparkline, precompile_sparkline)
    Core.render!(buffer, precompile_sparkline, Core.Rect(11, 25, 1, 20))
    precompile_bar_chart = BarChart(["Build" => 3.0, "Test" => 2.0])
    register_bar_chart_semantic_handlers!(SemanticDispatcher(), :precompile_bar_chart, precompile_bar_chart)
    Core.render!(buffer, precompile_bar_chart, Core.Rect(8, 25, 4, 20))
    precompile_chart = Chart([ChartDataset([(0.0, 0.0), (1.0, 1.0)])])
    register_chart_semantic_handlers!(SemanticDispatcher(), :precompile_chart, precompile_chart)
    Core.render!(buffer, precompile_chart, Core.Rect(8, 1, 4, 24))
    precompile_plot = Plot([(0.0, 0.0), (1.0, 1.0)]; width=20, height=4)
    register_plot_semantic_handlers!(SemanticDispatcher(), :precompile_plot, precompile_plot)
    Core.render!(buffer, precompile_plot, Core.Rect(8, 1, 4, 20))
    precompile_histogram = Histogram([1.0, 2.0, 3.0]; bins=2)
    register_histogram_semantic_handlers!(SemanticDispatcher(), :precompile_histogram, precompile_histogram)
    Core.render!(buffer, precompile_histogram, Core.Rect(8, 25, 4, 20))
    precompile_heatmap = Heatmap([1.0 2.0; 3.0 4.0])
    register_heatmap_semantic_handlers!(SemanticDispatcher(), :precompile_heatmap, precompile_heatmap)
    Core.render!(buffer, precompile_heatmap, Core.Rect(10, 25, 2, 20))
    Core.render!(buffer, Calendar(2026, 7), Core.Rect(7, 1, 5, 24))
    precompile_canvas = Canvas(context -> canvas_point!(context, 0.5, 0.5))
    register_canvas_semantic_handlers!(SemanticDispatcher(), :precompile_canvas, precompile_canvas)
    Core.render!(buffer, precompile_canvas, Core.Rect(11, 25, 1, 20))
    precompile_meter = Meter(3; minimum=0, maximum=4, label="Capacity", width=12, height=2)
    register_meter_semantic_handlers!(SemanticDispatcher(), :precompile_meter, precompile_meter)
    Core.render!(buffer, precompile_meter, Core.Rect(10, 25, 2, 20))
    precompile_stepper = Stepper()
    precompile_stepper_state = StepperState(["Queued" => :queued, "Running" => :running, "Done" => :done])
    register_stepper_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_stepper,
        precompile_stepper_state,
    )
    Core.render!(buffer, precompile_stepper, Core.Rect(12, 1, 1, 24), precompile_stepper_state)
    precompile_timeline = Timeline([
        TimelineItem("Queued", :queued),
        TimelineItem("Running", :running; status=TimelineActive),
    ]; width=24, height=2)
    precompile_timeline_state = state_for(precompile_timeline)
    register_timeline_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_timeline,
        precompile_timeline_state,
    )
    Core.render!(buffer, precompile_timeline, Core.Rect(13, 1, 2, 24), precompile_timeline_state)
    precompile_digits = Digits(42)
    register_digits_semantic_handlers!(SemanticDispatcher(), :precompile_digits, precompile_digits)
    Core.render!(buffer, precompile_digits, Core.Rect(8, 1, 5, 24))
    precompile_pretty = Pretty((status=:ready, count=1))
    register_pretty_semantic_handlers!(SemanticDispatcher(), :precompile_pretty, precompile_pretty)
    Core.render!(buffer, precompile_pretty, Core.Rect(8, 25, 3, 24))
    precompile_help = HelpView([KeyHint("q", "Quit"), KeyHint("?", "Help")])
    register_help_view_semantic_handlers!(SemanticDispatcher(), :precompile_help, precompile_help)
    Core.render!(buffer, precompile_help, Core.Rect(11, 25, 2, 24))
    Core.render!(buffer, Wrap(Widgets.Label("One"), Widgets.Label("Two"); column_gap=1), Core.Rect(1, 1, 2, 24))
    Core.render!(
        buffer,
        Dock(top=Widgets.Label("Top"), top_size=1, center=Widgets.Label("Center")),
        Core.Rect(2, 1, 4, 24),
    )
    Core.render!(
        buffer,
        AppShell(Widgets.Label("Center"); title="Wicked", shortcuts=[:q => "Quit"]),
        Core.Rect(2, 1, 4, 24),
    )
    Core.render!(buffer, TabbedContentView(), Core.Rect(9, 1, 3, 24))
    precompile_tabbed_content = TabbedContent([
        ContentPage(:overview, "Overview", Widgets.Label("Overview")),
        ContentPage(:details, "Details", Widgets.Label("Details"); closable=true),
    ])
    register_tabbed_content_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_tabbed_content,
        TabbedContentView(),
        precompile_tabbed_content,
    )
    rows = [(name="build", status="ready"), (name="test", status="queued")]
    columns = [
        VirtualTableColumn(:name, "Name"; accessor=row -> row.name),
        VirtualTableColumn(:status, "Status"; accessor=row -> row.status),
    ]
    precompile_data_table = DataTable(rows, columns; width=24, height=3)
    precompile_data_table_state = state_for(precompile_data_table)
    register_data_table_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_data_table,
        precompile_data_table,
        precompile_data_table_state,
    )
    Core.render!(buffer, precompile_data_table, Core.Rect(9, 1, 3, 24), precompile_data_table_state)
    precompile_data_grid = DataGrid(VectorDataSource(rows), columns; width=24, height=3)
    precompile_data_grid_state = state_for(precompile_data_grid)
    register_data_grid_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_data_grid,
        precompile_data_grid,
        precompile_data_grid_state,
    )
    Core.render!(buffer, precompile_data_grid, Core.Rect(9, 1, 3, 24), precompile_data_grid_state)
    precompile_virtual_list = VirtualList(rows; width=24, height=3, key=(row, _) -> Symbol(row.name),
        format=VirtualListFormat(item=(row, _) -> row.name))
    precompile_virtual_list_state = state_for(precompile_virtual_list)
    register_virtual_list_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_virtual_list,
        precompile_virtual_list,
        precompile_virtual_list_state,
    )
    Core.render!(
        buffer,
        precompile_virtual_list,
        Core.Rect(9, 1, 3, 24),
        precompile_virtual_list_state,
    )
    precompile_virtual_table = VirtualTable(rows, columns; width=24, height=3)
    precompile_virtual_table_state = state_for(precompile_virtual_table)
    virtual_selection_snapshot(precompile_virtual_table_state.rows)
    restore_virtual_selection!(
        precompile_virtual_table_state.rows,
        virtual_selection_snapshot(precompile_virtual_table_state.rows),
    )
    push!(precompile_virtual_table_state.rows.selected, 1)
    virtual_selected_row_records(precompile_virtual_table, precompile_virtual_table_state)
    virtual_selected_row_snapshot(precompile_virtual_table, precompile_virtual_table_state)
    precompile_range_selection = begin_virtual_range_selection(precompile_virtual_table_state.rows, 2)
    virtual_range_selected_row_records(precompile_virtual_table, precompile_virtual_table_state, precompile_range_selection)
    virtual_range_selected_row_snapshot(precompile_virtual_table, precompile_virtual_table_state, precompile_range_selection)
    precompile_range_actions = [VirtualRowAction(:range_open, "Range open"; handler=(item, index, key) -> item.name)]
    invoke_virtual_range_row_action_batch(precompile_range_actions, :range_open, precompile_virtual_table, precompile_virtual_table_state, precompile_range_selection)
    precompile_cell_edit = VirtualCellEditState()
    begin_virtual_cell_edit!(precompile_cell_edit, 1, :status; key=:build, value="ready")
    update_virtual_cell_edit!(precompile_cell_edit, "done"; validator=value -> (!isempty(value), nothing))
    virtual_cell_edit_snapshot(precompile_cell_edit)
    restore_virtual_cell_edit!(precompile_cell_edit, virtual_cell_edit_snapshot(precompile_cell_edit))
    precompile_cell_commit = commit_virtual_cell_edit!(precompile_cell_edit)
    apply_virtual_cell_edit((status="ready",), precompile_cell_commit)
    precompile_cell_dict = Dict(:status => "ready")
    apply_virtual_cell_edit(precompile_cell_dict, precompile_cell_commit)
    apply_virtual_cell_edit!(precompile_cell_dict, precompile_cell_commit)
    precompile_cell_history = VirtualCellEditHistory()
    record_virtual_cell_edit!(precompile_cell_history, precompile_cell_commit)
    precompile_cell_history_snapshot = virtual_cell_edit_history_snapshot(precompile_cell_history)
    restore_virtual_cell_edit_history!(precompile_cell_history, precompile_cell_history_snapshot)
    undo_virtual_cell_edit!(precompile_cell_history)
    redo_virtual_cell_edit!(precompile_cell_history)
    begin_virtual_cell_edit!(precompile_cell_edit, 1, :status; key=:build, value="ready")
    cancel_virtual_cell_edit!(precompile_cell_edit)
    precompile_virtual_table_dispatcher = SemanticDispatcher()
    register_virtual_table_semantic_handlers!(
        precompile_virtual_table_dispatcher,
        :precompile_virtual_table,
        precompile_virtual_table,
        precompile_virtual_table_state,
    )
    register_virtual_row_action_semantic_handlers!(
        precompile_virtual_table_dispatcher,
        :precompile_virtual_table,
        precompile_virtual_table,
        precompile_virtual_table_state,
        precompile_row_actions,
    )
    register_virtual_row_action_batch_semantic_handlers!(
        precompile_virtual_table_dispatcher,
        :precompile_virtual_table,
        precompile_virtual_table,
        precompile_virtual_table_state,
        precompile_row_actions,
    )
    precompile_row_batch = invoke_virtual_row_action_batch(
        precompile_row_actions,
        :open,
        rows;
        indices=1:length(rows),
        keys=[:build, :test],
    )
    virtual_row_action_batch_records(precompile_row_batch)
    virtual_row_action_batch_summary(precompile_row_batch)
    virtual_row_action_batch_text(precompile_row_batch)
    virtual_row_action_batch_markdown(precompile_row_batch)
    virtual_row_action_batch_tsv(precompile_row_batch)
    register_virtual_column_action_semantic_handlers!(
        precompile_virtual_table_dispatcher,
        :precompile_virtual_table,
        columns,
        precompile_table_layout,
        precompile_column_actions;
        visibility=precompile_column_visibility,
        pinning=precompile_column_pins,
    )
    register_virtual_cell_edit_semantic_handlers!(
        precompile_virtual_table_dispatcher,
        :precompile_virtual_table,
        precompile_virtual_table,
        precompile_virtual_table_state,
        precompile_cell_edit,
    )
    Core.render!(buffer, precompile_virtual_table, Core.Rect(9, 1, 3, 24), precompile_virtual_table_state)
    precompile_table = Table([TableColumn("Name"), TableColumn("Status")], [["Build", "Ready"], ["Test", "Queued"]])
    precompile_table_state = state_for(precompile_table)
    register_table_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_table,
        precompile_table,
        precompile_table_state;
        viewport_height=2,
    )
    Core.render!(buffer, precompile_table, Core.Rect(9, 25, 3, 24), precompile_table_state)
    tree_source = CallbackTreeDataSource{String,Symbol}(
        roots=() -> ["root"],
        children=item -> item == "root" ? ["child"] : String[],
        key=item -> Symbol(item),
    )
    precompile_virtual_tree = VirtualTree(tree_source; width=24, height=3)
    precompile_virtual_tree_state = state_for(precompile_virtual_tree)
    register_virtual_tree_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_virtual_tree,
        precompile_virtual_tree,
        precompile_virtual_tree_state,
    )
    Core.render!(buffer, precompile_virtual_tree, Core.Rect(9, 1, 3, 24), precompile_virtual_tree_state)
    precompile_tree = Tree([TreeNode(:root, "Root"; children=[TreeNode(:child, "Child")])])
    precompile_tree_state = TreeState(expanded=[:root])
    register_tree_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_tree,
        precompile_tree,
        precompile_tree_state;
        viewport_height=2,
    )
    Core.render!(buffer, precompile_tree, Core.Rect(12, 1, 3, 24), precompile_tree_state)
    precompile_tree_view = TreeView([TreeNode(:root, "Root"; children=[TreeNode(:child, "Child")])])
    precompile_tree_view_state = TreeViewState(expanded=[:root])
    register_tree_view_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_tree_view,
        precompile_tree_view,
        precompile_tree_view_state;
        viewport_height=2,
    )
    Core.render!(buffer, precompile_tree_view, Core.Rect(12, 25, 3, 24), precompile_tree_view_state)
    precompile_tree_table = TreeTable(tree_source, [VirtualTableColumn(:name, "Name"; accessor=item -> item)]; width=24, height=3)
    precompile_tree_table_state = state_for(precompile_tree_table)
    register_tree_table_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_tree_table,
        precompile_tree_table,
        precompile_tree_table_state,
    )
    Core.render!(buffer, precompile_tree_table, Core.Rect(9, 1, 3, 24), precompile_tree_table_state)
    Core.render!(buffer, Autocomplete(["build", "test", "release"]; max_visible=2), Core.Rect(9, 25, 2, 20))
    Core.render!(buffer, ComboBox(["debug", "release"]; max_visible=2), Core.Rect(11, 1, 2, 20))
    Core.render!(buffer, TagInput(["julia", "tui"]; width=20), Core.Rect(12, 25, 1, 20))
    precompile_checkbox = Checkbox("Ready")
    precompile_checkbox_state = state_for(precompile_checkbox)
    register_checkbox_semantic_handlers!(SemanticDispatcher(), :precompile_checkbox, precompile_checkbox, precompile_checkbox_state)
    Core.render!(buffer, precompile_checkbox, Core.Rect(12, 1, 1, 20), precompile_checkbox_state)
    precompile_check_box = CheckBox("Ready")
    precompile_check_box_state = state_for(precompile_check_box)
    register_check_box_semantic_handlers!(SemanticDispatcher(), :precompile_check_box, precompile_check_box, precompile_check_box_state)
    Core.render!(buffer, precompile_check_box, Core.Rect(12, 1, 1, 20), precompile_check_box_state)
    precompile_toggle = Toggle(on_label="Enabled", off_label="Disabled")
    precompile_toggle_state = state_for(precompile_toggle)
    register_toggle_semantic_handlers!(SemanticDispatcher(), :precompile_toggle, precompile_toggle, precompile_toggle_state)
    Core.render!(buffer, precompile_toggle, Core.Rect(12, 1, 1, 20), precompile_toggle_state)
    precompile_switch = Switch(on_label="Enabled", off_label="Disabled")
    precompile_switch_state = state_for(precompile_switch)
    register_switch_semantic_handlers!(SemanticDispatcher(), :precompile_switch, precompile_switch, precompile_switch_state)
    Core.render!(buffer, precompile_switch, Core.Rect(12, 1, 1, 20), precompile_switch_state)
    precompile_slider = Slider(0, 100; value=50, width=16)
    precompile_slider_state = state_for(precompile_slider)
    register_slider_semantic_handlers!(SemanticDispatcher(), :precompile_slider, precompile_slider, precompile_slider_state)
    Core.render!(buffer, precompile_slider, Core.Rect(12, 1, 1, 16), precompile_slider_state)
    precompile_range_slider = RangeSlider(0, 100; lower=25, upper=75, width=16)
    precompile_range_slider_state = state_for(precompile_range_slider)
    register_range_slider_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_range_slider,
        precompile_range_slider,
        precompile_range_slider_state,
    )
    Core.render!(buffer, precompile_range_slider, Core.Rect(10, 25, 1, 16), precompile_range_slider_state)
    Core.render!(buffer, Panel(Widgets.Label("Panel")), Core.Rect(2, 25, 3, 20))
    precompile_collapsible = Collapsible("Details", Widgets.Label("Ready"); expanded=true, width=20, height=2)
    precompile_collapsible_state = state_for(precompile_collapsible)
    register_collapsible_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_collapsible,
        precompile_collapsible_state,
    )
    Core.render!(buffer, precompile_collapsible, Core.Rect(10, 1, 2, 20), precompile_collapsible_state)
    precompile_accordion = Accordion([(:details, "Details", Widgets.Label("Ready"))]; expanded=[:details], width=20)
    precompile_accordion_state = state_for(precompile_accordion)
    register_accordion_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_accordion,
        precompile_accordion,
        precompile_accordion_state,
    )
    Core.render!(buffer, precompile_accordion, Core.Rect(7, 25, 2, 20), precompile_accordion_state)
    precompile_carousel = Carousel(["Overview", "Logs"]; width=20, height=2)
    precompile_carousel_state = state_for(precompile_carousel)
    register_carousel_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_carousel,
        precompile_carousel_state,
    )
    Core.render!(buffer, precompile_carousel, Core.Rect(5, 25, 2, 20), precompile_carousel_state)
    precompile_drawer = Drawer(Widgets.Label("Drawer"); size=8)
    precompile_drawer_state = state_for(precompile_drawer)
    open_drawer!(precompile_drawer_state)
    register_drawer_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_drawer,
        precompile_drawer_state,
    )
    Core.render!(buffer, precompile_drawer, Core.Rect(1, 1, 6, 24), precompile_drawer_state)
    precompile_popover = Popover(Widgets.Label("Popover"), Core.Rect(1, 1, 1, 4); width=12, height=3)
    precompile_popover_state = state_for(precompile_popover)
    precompile_popover_state.open = true
    register_popover_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_popover,
        precompile_popover_state;
        dismissible=precompile_popover.dismissible,
    )
    Core.render!(buffer, precompile_popover, Core.Rect(1, 1, 12, 48), precompile_popover_state)
    tooltip = Tooltip("Help", Core.Rect(4, 4, 1, 4); width=16, height=3, delay_ms=0)
    tooltip_state = TooltipState(delay_ms=0)
    begin_tooltip_hover!(tooltip_state, :tooltip, tooltip.content; now_ns=UInt64(1))
    register_tooltip_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_tooltip,
        tooltip_state;
        dismissible=tooltip.dismissible,
    )
    Core.render!(buffer, tooltip, Core.Rect(1, 1, 12, 48), tooltip_state)
    diagnostics_hub = DiagnosticsHub()
    precompile_inspector = Inspector(diagnostics_hub; visible=true, width=20, height=3)
    precompile_inspector_state = state_for(precompile_inspector)
    register_inspector_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_inspector,
        precompile_inspector_state,
    )
    Core.render!(buffer, precompile_inspector, Core.Rect(7, 1, 3, 24), precompile_inspector_state)
    precompile_console = DevConsole(diagnostics_hub; visible=true, width=20, height=3)
    precompile_console_state = state_for(precompile_console)
    register_dev_console_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_console,
        precompile_console,
        precompile_console_state,
    )
    Core.render!(buffer, precompile_console, Core.Rect(7, 25, 3, 24), precompile_console_state)
    precompile_date = DatePicker(width=20, height=3)
    precompile_date_state = state_for(precompile_date)
    register_date_picker_semantic_handlers!(SemanticDispatcher(), :precompile_date, precompile_date_state)
    Core.render!(buffer, precompile_date, Core.Rect(7, 1, 3, 20), precompile_date_state)
    precompile_time = TimePicker(width=12)
    precompile_time_state = state_for(precompile_time)
    register_time_picker_semantic_handlers!(SemanticDispatcher(), :precompile_time, precompile_time_state)
    Core.render!(buffer, precompile_time, Core.Rect(6, 25, 1, 12), precompile_time_state)
    precompile_datetime = DateTimePicker(width=20, height=3)
    precompile_datetime_state = state_for(precompile_datetime)
    register_date_time_picker_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_datetime,
        precompile_datetime,
        precompile_datetime_state,
    )
    Core.render!(buffer, precompile_datetime, Core.Rect(9, 1, 3, 20), precompile_datetime_state)
    precompile_color = ColorPicker(width=20)
    precompile_color_state = state_for(precompile_color)
    register_color_picker_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_color,
        precompile_color,
        precompile_color_state,
    )
    Core.render!(buffer, precompile_color, Core.Rect(12, 1, 1, 20), precompile_color_state)
    precompile_file_picker = FilePicker(pwd(); width=20, height=3)
    precompile_file_picker_state = state_for(precompile_file_picker)
    register_file_picker_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_files,
        precompile_file_picker,
        precompile_file_picker_state,
    )
    precompile_directory_picker = DirectoryPicker(pwd(); width=20, height=3)
    precompile_directory_picker_state = state_for(precompile_directory_picker)
    register_directory_picker_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_directories,
        precompile_directory_picker,
        precompile_directory_picker_state,
    )
    precompile_directory_tree = DirectoryTree(pwd(); width=20, height=3)
    precompile_directory_tree_state = state_for(precompile_directory_tree)
    register_directory_tree_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_directory_tree,
        precompile_directory_tree,
        precompile_directory_tree_state,
    )
    precompile_multi_file_picker = MultiFilePicker(pwd(); width=20, height=3)
    precompile_multi_file_picker_state = state_for(precompile_multi_file_picker)
    register_multi_file_picker_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_multi_files,
        precompile_multi_file_picker,
        precompile_multi_file_picker_state,
    )
    Core.render!(buffer, precompile_file_picker, Core.Rect(13, 1, 3, 20), precompile_file_picker_state)
    Core.render!(buffer, precompile_directory_picker, Core.Rect(13, 22, 3, 20), precompile_directory_picker_state)
    Core.render!(buffer, precompile_directory_tree, Core.Rect(16, 1, 3, 20), precompile_directory_tree_state)
    Core.render!(buffer, precompile_multi_file_picker, Core.Rect(16, 22, 3, 20), precompile_multi_file_picker_state)
    precompile_modal_state = DialogState([DialogButton("OK", :ok)]; open=true)
    precompile_modal = Modal("Continue?"; title="Confirm")
    register_modal_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_modal,
        precompile_modal,
        precompile_modal_state,
    )
    Core.render!(
        buffer,
        precompile_modal,
        Core.Rect(7, 25, 4, 20),
        precompile_modal_state,
    )
    precompile_window_state = WindowState([DialogButton("OK", :ok)]; open=true)
    precompile_window = Window("Continue?"; title="Confirm")
    register_window_semantic_handlers!(
        SemanticDispatcher(),
        :precompile_window,
        precompile_window,
        precompile_window_state,
    )
    Core.render!(
        buffer,
        precompile_window,
        Core.Rect(7, 25, 4, 20),
        precompile_window_state,
    )

    sheet = Styles.parse_stylesheet("Button.primary:focus { color: bright-cyan; modifiers: bold underline; }")
    styles = Styles.StyleEngine(; stylesheets=[sheet])
    style_context = Styles.StyleContext(Widgets.Button, :deploy, Set([:primary]), Set([:focus]), Set{Symbol}())
    style_explanation = Styles.explain_style(styles, style_context; inline=Core.StylePatch(add_modifiers=Core.UNDERLINE))
    Styles.style_context_record(style_context)
    Styles.style_context_text(style_context)
    Styles.style_context_markdown(style_context)
    Styles.style_context_tsv(style_context)
    style_diagnostics = Styles.style_diagnostics(styles, style_context; inline=Core.StylePatch(add_modifiers=Core.UNDERLINE))
    Styles.style_diagnostics_record(style_diagnostics)
    Styles.style_diagnostics_text(style_diagnostics)
    Styles.style_diagnostics_markdown(style_diagnostics)
    Styles.style_diagnostics_tsv(style_diagnostics)
    Styles.search_style_diagnostics_records(style_diagnostics, "classes")
    Styles.search_style_diagnostics_count(style_diagnostics, "resolution")
    Styles.search_style_diagnostics_text(style_diagnostics, "matched=false")
    Styles.search_style_diagnostics_markdown(style_diagnostics, "Button.primary")
    Styles.search_style_diagnostics_tsv(style_diagnostics, "inline")
    Styles.selector_text(first(sheet.rules).selector)
    Styles.selector_match_reasons(first(sheet.rules).selector, style_context)
    Styles.style_rule_match_records(styles, style_context)
    Styles.matching_style_rule_records(styles, style_context)
    Styles.unmatched_style_rule_records(styles, style_context)
    Styles.style_rule_match_summary(styles, style_context)
    Styles.style_rule_match_text(styles, style_context)
    Styles.style_rule_match_markdown(styles, style_context)
    Styles.style_rule_match_tsv(styles, style_context)
    Styles.matching_style_rule_text(styles, style_context)
    Styles.matching_style_rule_markdown(styles, style_context)
    Styles.matching_style_rule_tsv(styles, style_context)
    Styles.unmatched_style_rule_text(styles, style_context)
    Styles.unmatched_style_rule_markdown(styles, style_context)
    Styles.unmatched_style_rule_tsv(styles, style_context)
    Styles.search_style_rule_match_records(styles, style_context, "classes")
    Styles.search_style_rule_match_count(styles, style_context, "matched=false")
    Styles.search_style_rule_match_text(styles, style_context, "Button.primary")
    Styles.search_style_rule_match_markdown(styles, style_context, "stylesheet")
    Styles.search_style_rule_match_tsv(styles, style_context, "classes")
    Styles.style_explanation_records(style_explanation)
    Styles.style_explanation_text(style_explanation)
    Styles.style_explanation_markdown(style_explanation)
    Styles.style_explanation_tsv(style_explanation)
    Styles.style_explanation_summary(style_explanation)
    Styles.style_explanation_summary_records(style_explanation)
    Styles.style_explanation_summary_text(style_explanation)
    Styles.style_explanation_summary_markdown(style_explanation)
    Styles.style_explanation_summary_tsv(style_explanation)
    Styles.search_style_explanation_records(style_explanation, "stylesheet")
    Styles.search_style_explanation_count(style_explanation, "inline")
    Styles.search_style_explanation_text(style_explanation, "stylesheet")
    Styles.search_style_explanation_markdown(style_explanation, "stylesheet")
    Styles.search_style_explanation_tsv(style_explanation, "stylesheet")
    precompile_modifier = Toolkit.then(
        Toolkit.element_modifier(focusable=true, classes=[:primary]),
        Toolkit.ElementModifier(id=:modified, key=:modified, tab_index=1),
    )
    precompile_modified = Toolkit.element(
        Widgets.Button("Modified", :modified);
        modifier=precompile_modifier,
    )
    precompile_modifier isa Toolkit.ElementModifier
    Toolkit.modify(precompile_modified, Toolkit.ElementModifier(disabled=false))
    precompile_component = Toolkit.component(initial=1, key=:component, id=:component) do state
        value = Toolkit.component_value(state)
        Toolkit.use_effect!(state, :value, (value,)) do
            return nothing
        end
        Toolkit.column("Component: $value"; constraints=[Layout.Length(1)])
    end
    precompile_component_tree = Toolkit.ToolkitTree(precompile_component)
    precompile_component.widget isa Toolkit.StatefulComponent
    Toolkit.render_toolkit!(Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))), precompile_component_tree)
    precompile_component_state = Toolkit.element_state(precompile_component_tree, :component)
    precompile_component_state isa Toolkit.ComponentState
    Toolkit.component_version(precompile_component_state)
    Toolkit.component_invalidated(precompile_component_state)
    Toolkit.set_component_value!(precompile_component_state, 2)
    Toolkit.update_component_value!(+, precompile_component_state, 1)
    Toolkit.invalidate_component!(precompile_component_state)
    Toolkit.toolkit_invalidated(precompile_component_tree)
    Toolkit.clear_component_invalidation!(precompile_component_state)
    Toolkit.clear_toolkit_invalidation!(precompile_component_tree)
    Toolkit.render_toolkit!(Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))), precompile_component_tree)
    precompile_component_tree.root = Toolkit.element(Widgets.Label("Disposed"))
    Toolkit.render_toolkit!(Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))), precompile_component_tree)
    Toolkit.clear_component_effects!(precompile_component_state)
    precompile_local = Toolkit.composition_local(
        :density,
        1;
        value_type=Real,
    )
    precompile_slots = Toolkit.component_slots(
        "Body";
        header="Header",
        actions=("Save", "Cancel"),
    )
    precompile_slots isa Toolkit.ComponentSlots
    precompile_local isa Toolkit.CompositionLocal
    Toolkit.has_slot(precompile_slots, :header)
    Toolkit.slot_names(precompile_slots)
    precompile_context_component = Toolkit.component(id=:precompile_context) do state
        density = Toolkit.composition_value(state, precompile_local)
        Toolkit.column(
            Toolkit.slot(precompile_slots, :header)...,
            "Density: $density";
            constraints=[Layout.Length(1), Layout.Length(1)],
        )
    end
    precompile_context_provider = Toolkit.provide_context(
        precompile_local => 2;
        children=(precompile_context_component,),
    )
    precompile_context_provider.widget isa Toolkit.ContextProvider
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 2, 24))),
        Toolkit.ToolkitTree(precompile_context_provider),
    )
    precompile_remembered_ref = Ref{Any}(nothing)
    precompile_remembered_component = Toolkit.component(id=:precompile_remembered) do state
        count = Toolkit.remember!(state, :count, 1)
        precompile_remembered_ref[] = count
        doubled = Toolkit.derived_remember!(value -> value * 2, state, :doubled, (Toolkit.remembered_value(count),))
        "$(Toolkit.remembered_value(count))/$(Toolkit.remembered_value(doubled))"
    end
    precompile_remembered_tree = Toolkit.ToolkitTree(precompile_remembered_component)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))),
        precompile_remembered_tree,
    )
    precompile_remembered = precompile_remembered_ref[]
    precompile_remembered isa Toolkit.RememberedValue
    Toolkit.remembered_version(precompile_remembered)
    Toolkit.set_remembered_value!(precompile_remembered, 2)
    Toolkit.update_remembered_value!(+, precompile_remembered, 1)
    precompile_boundary = Toolkit.error_boundary(
        Toolkit.component(state -> error("precompile boundary failure"));
        id=:precompile_boundary,
        fallback=failure -> "Recovered",
    )
    precompile_boundary.widget isa Toolkit.ComponentErrorBoundary
    precompile_boundary_tree = Toolkit.ToolkitTree(precompile_boundary)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))),
        precompile_boundary_tree,
    )
    precompile_boundary_state = Toolkit.element_state(precompile_boundary_tree, :precompile_boundary)
    precompile_boundary_state isa Toolkit.ComponentErrorBoundaryState
    Toolkit.boundary_failed(precompile_boundary_state)
    Toolkit.boundary_failure(precompile_boundary_state)
    Toolkit.retry_error_boundary!(precompile_boundary_state)
    precompile_resource = Toolkit.AsyncResource()
    Toolkit.load_async_resource!(precompile_resource, token -> begin
        Toolkit.throw_if_resource_cancelled(token)
        1
    end)
    yield()
    Toolkit.resource_status(precompile_resource)
    Toolkit.resource_value(precompile_resource)
    Toolkit.resource_failure(precompile_resource)
    Toolkit.resource_generation(precompile_resource)
    Toolkit.resource_loading(precompile_resource)
    Toolkit.resource_succeeded(precompile_resource)
    Toolkit.resource_failed(precompile_resource)
    Toolkit.resource_cancelled(Toolkit.AsyncResourceToken())
    Toolkit.resource_content(precompile_resource; success=value -> "Value: $value")
    Toolkit.retry_async_resource!(precompile_resource)
    Toolkit.cancel_async_resource!(precompile_resource)
    precompile_async_component = Toolkit.async_resource_component(
        () -> "ready";
        id=:precompile_async,
        success=value -> "Async: $value",
    )
    precompile_async_tree = Toolkit.ToolkitTree(precompile_async_component)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))),
        precompile_async_tree,
    )
    precompile_tracked_signal = Reactive.Signal("tracked")
    precompile_tracking = Reactive.track_reactive_reads() do
        Reactive.signal_value(precompile_tracked_signal)
    end
    precompile_tracking.dependencies
    precompile_tracked_component = ReactiveToolkit.tracked_component(id=:precompile_tracked) do state
        "Tracked: $(Reactive.signal_value(precompile_tracked_signal))"
    end
    precompile_tracked_component.widget.view isa ReactiveToolkit.TrackedComponentView
    precompile_tracked_tree = Toolkit.ToolkitTree(precompile_tracked_component)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))),
        precompile_tracked_tree,
    )
    Reactive.set_signal!(precompile_tracked_signal, "updated")
    precompile_controlled_value = Ref((count=1,))
    precompile_controlled = Toolkit.state_binding(
        () -> precompile_controlled_value[],
        value -> (precompile_controlled_value[] = value),
    )
    precompile_count_binding = Toolkit.map_binding(
        precompile_controlled;
        get=value -> value.count,
        set=(value, count) -> merge(value, (count=count,)),
    )
    precompile_controlled isa Toolkit.AbstractStateBinding
    Toolkit.binding_value(precompile_count_binding)
    Toolkit.set_binding_value!(precompile_count_binding, 2)
    Toolkit.update_binding_value!(+, precompile_count_binding, 1)
    precompile_signal_binding = ReactiveToolkit.signal_binding(precompile_tracked_signal)
    Toolkit.binding_value(precompile_signal_binding)
    precompile_binding_component = Toolkit.component(id=:precompile_binding) do state
        binding = Toolkit.remember_binding!(state, :value, 1)
        "Binding: $(Toolkit.binding_value(binding))"
    end
    precompile_binding_tree = Toolkit.ToolkitTree(precompile_binding_component)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))),
        precompile_binding_tree,
    )
    precompile_slider_value = Ref(2.0)
    precompile_slider_binding = Toolkit.state_binding(
        () -> precompile_slider_value[],
        value -> (precompile_slider_value[] = value),
    )
    precompile_slider = Slider(0, 10; value=2, width=11)
    precompile_bound_slider = Toolkit.bound_element(
        precompile_slider,
        precompile_slider_binding;
        id=:precompile_bound_slider,
        state_factory=() -> SliderState(0, 10; value=2),
        apply_value! = (state, value) -> set_slider!(state, value),
        extract_value=state -> state.value,
    )
    precompile_bound_tree = Toolkit.ToolkitTree(precompile_bound_slider)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 11))),
        precompile_bound_tree,
    )
    precompile_bound_state = Toolkit.element_state(precompile_bound_tree, :precompile_bound_slider)
    precompile_bound_state isa Toolkit.BoundWidgetState
    Toolkit.bound_widget_state(precompile_bound_state)
    Toolkit.bound_property_element(
        precompile_slider,
        precompile_slider_binding,
        :value;
        state_factory=() -> SliderState(0, 10; value=2),
    )
    precompile_effect_events = Symbol[]
    precompile_effect_component = Toolkit.component(id=:precompile_effects) do state
        latest = Toolkit.remember_updated!(state, :latest, :ready)
        Toolkit.disposable_effect!(state, :resource) do
            push!(precompile_effect_events, :setup)
            return () -> push!(precompile_effect_events, :cleanup)
        end
        Toolkit.side_effect!(state, :commit) do
            Toolkit.remembered_value(latest)
        end
        "Effects"
    end
    precompile_effect_tree = Toolkit.ToolkitTree(precompile_effect_component)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 16))),
        precompile_effect_tree,
    )
    precompile_produced_component = Toolkit.component(id=:precompile_produced) do state
        produced = Toolkit.produce_state!(state, :value, 0, (1,)) do publish, token, value
            publish(value)
        end
        Toolkit.produced_value(produced)
        Toolkit.produced_version(produced)
        Toolkit.produced_status(produced)
        Toolkit.produced_failure(produced)
        Toolkit.produced_running(produced)
        Toolkit.produced_succeeded(produced)
        Toolkit.produced_failed(produced)
        "Produced"
    end
    precompile_produced_tree = Toolkit.ToolkitTree(precompile_produced_component)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 16))),
        precompile_produced_tree,
    )
    precompile_saveable_registry = Toolkit.SaveableStateRegistry()
    precompile_saveable_component = Toolkit.component(id=:precompile_saveable) do state
        value = Toolkit.remember_saveable!(state, :value, 1)
        "Saved: $(Toolkit.remembered_value(value))"
    end
    precompile_saveable_tree = Toolkit.ToolkitTree(
        Toolkit.saveable_state_provider(
            precompile_saveable_registry,
            precompile_saveable_component;
            scope=:precompile,
        ),
    )
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 16))),
        precompile_saveable_tree,
    )
    Toolkit.saveable_state_snapshot(precompile_saveable_registry)
    precompile_constraints_tree = Toolkit.ToolkitTree(
        Toolkit.box_with_constraints(area -> "$(area.height)x$(area.width)"; id=:precompile_constraints),
    )
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 2, 16))),
        precompile_constraints_tree,
    )
    precompile_lazy_items = collect(1:12)
    precompile_lazy_column = lazy_column(
        precompile_lazy_items;
        item=string,
        height=3,
        width=16,
        id=:precompile_lazy_column,
    )
    precompile_lazy_grid = lazy_grid(
        precompile_lazy_items;
        item=string,
        columns=2,
        height=2,
        width=16,
        id=:precompile_lazy_grid,
    )
    precompile_lazy_row = lazy_row(
        precompile_lazy_items;
        item=string,
        item_extent=4,
        height=1,
        width=16,
        id=:precompile_lazy_row,
    )
    for (root, root_area) in (
        (precompile_lazy_column, Core.Rect(1, 1, 3, 16)),
        (precompile_lazy_grid, Core.Rect(1, 1, 2, 16)),
        (precompile_lazy_row, Core.Rect(1, 1, 1, 16)),
    )
        Toolkit.render_toolkit!(Core.Frame(Core.Buffer(root_area)), Toolkit.ToolkitTree(root))
    end
    precompile_toggle_value = Ref(false)
    precompile_choice_value = Ref(:first)
    precompile_toggle_binding = Toolkit.state_binding(
        () -> precompile_toggle_value[],
        value -> (precompile_toggle_value[] = value),
    )
    precompile_choice_binding = Toolkit.state_binding(
        () -> precompile_choice_value[],
        value -> (precompile_choice_value[] = value),
    )
    precompile_interactions = Toolkit.column(
        clickable(Widgets.Label("Click"); id=:precompile_clickable, on_click=() -> nothing),
        combined_clickable(
            Widgets.Label("Combined");
            id=:precompile_combined_clickable,
            on_click=() -> nothing,
            on_double_click=() -> nothing,
        ),
        draggable(
            Widgets.Label("Drag");
            id=:precompile_draggable,
            on_drag=gesture -> nothing,
        ),
        hoverable(Widgets.Label("Hover"); id=:precompile_hoverable),
        toggleable(
            Widgets.Label("Toggle");
            id=:precompile_toggleable,
            binding=precompile_toggle_binding,
        ),
        selectable(
            Widgets.Label("Select");
            id=:precompile_selectable,
            binding=precompile_choice_binding,
            value=:second,
        );
        constraints=[Layout.Length(1), Layout.Length(1), Layout.Length(1), Layout.Length(1), Layout.Length(1), Layout.Length(1)],
    )
    precompile_interaction_tree = Toolkit.ToolkitTree(precompile_interactions)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 6, 16))),
        precompile_interaction_tree,
    )
    Toolkit.dispatch!(
        precompile_interaction_tree,
        Events.MouseEvent(Core.Position(2, 1), Events.NoMouseButton, Events.MouseMove),
    )
    Toolkit.dispatch!(
        precompile_interaction_tree,
        Events.MouseEvent(Core.Position(2, 1), Events.LeftMouseButton, Events.MousePress; click_count=2),
    )
    Toolkit.dispatch!(
        precompile_interaction_tree,
        Events.MouseEvent(Core.Position(2, 1), Events.LeftMouseButton, Events.MouseRelease; click_count=2),
    )
    Toolkit.capture_pointer!(precompile_interaction_tree, :precompile_draggable)
    Toolkit.pointer_capture_target(precompile_interaction_tree)
    Toolkit.has_pointer_capture(precompile_interaction_tree)
    Toolkit.release_pointer!(precompile_interaction_tree, :precompile_draggable)
    Toolkit.dispatch!(
        precompile_interaction_tree,
        Events.MouseEvent(Core.Position(3, 1), Events.LeftMouseButton, Events.MousePress),
    )
    Toolkit.dispatch!(
        precompile_interaction_tree,
        Events.MouseEvent(Core.Position(4, 2), Events.LeftMouseButton, Events.MouseDrag),
    )
    Toolkit.dispatch!(
        precompile_interaction_tree,
        Events.MouseEvent(Core.Position(4, 2), Events.LeftMouseButton, Events.MouseRelease),
    )
    precompile_drag_router = ToolkitDragRouter(DragDropManager(threshold=1))
    precompile_drag_drop = drag_drop_provider(
        precompile_drag_router,
        Toolkit.column(
            drag_source(
                Widgets.Label("Source");
                id=:precompile_drag_source,
                payload=DragPayload("value"; mime="text/plain"),
            ),
            drop_target(
                Widgets.Label("Target");
                id=:precompile_drop_target,
                on_drop=result -> nothing,
                accepted_mime_prefixes=("text/",),
            );
            constraints=[Layout.Length(1), Layout.Length(1)],
        ),
    )
    precompile_drag_drop_tree = Toolkit.ToolkitTree(precompile_drag_drop)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 2, 16))),
        precompile_drag_drop_tree,
    )
    Toolkit.dispatch!(
        precompile_drag_drop_tree,
        Events.MouseEvent(Core.Position(1, 1), Events.LeftMouseButton, Events.MousePress),
    )
    Toolkit.dispatch!(
        precompile_drag_drop_tree,
        Events.MouseEvent(Core.Position(2, 1), Events.LeftMouseButton, Events.MouseDrag),
    )
    Toolkit.dispatch!(
        precompile_drag_drop_tree,
        Events.MouseEvent(Core.Position(2, 1), Events.LeftMouseButton, Events.MouseRelease),
    )
    precompile_key_input = preview_key_input(
        key_input(
            Toolkit.element(Widgets.Label("Keys"); id=:precompile_key_target, focusable=true);
            id=:precompile_key_bubble,
            keys=:enter,
            kinds=Events.KeyPress,
            on_key=event -> nothing,
        );
        id=:precompile_key_preview,
        on_key=event -> nothing,
    )
    precompile_key_tree = Toolkit.ToolkitTree(precompile_key_input)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 16))),
        precompile_key_tree,
    )
    Interaction.focus!(precompile_key_tree.state.focus, :precompile_key_target)
    Toolkit.dispatch!(precompile_key_tree, Events.KeyEvent(Events.Key(:enter)))
    precompile_pointer_input = preview_pointer_input(
        pointer_input(
            Toolkit.element(Widgets.Label("Pointer"); id=:precompile_pointer_target);
            id=:precompile_pointer_normal,
            actions=(Events.MousePress, Events.MouseDrag, Events.MouseRelease),
            buttons=Events.LeftMouseButton,
            capture_on_press=true,
            on_pointer=event -> nothing,
        );
        id=:precompile_pointer_preview,
        actions=Events.MousePress,
        on_pointer=event -> nothing,
    )
    precompile_pointer_tree = Toolkit.ToolkitTree(precompile_pointer_input)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 16))),
        precompile_pointer_tree,
    )
    Toolkit.dispatch!(
        precompile_pointer_tree,
        Events.MouseEvent(Core.Position(1, 1), Events.LeftMouseButton, Events.MousePress),
    )
    Toolkit.dispatch!(
        precompile_pointer_tree,
        Events.MouseEvent(Core.Position(2, 2), Events.LeftMouseButton, Events.MouseDrag),
    )
    Toolkit.dispatch!(
        precompile_pointer_tree,
        Events.MouseEvent(Core.Position(2, 2), Events.LeftMouseButton, Events.MouseRelease),
    )
    Interaction.focus!(precompile_interaction_tree.state.focus, :precompile_clickable)
    Toolkit.dispatch!(precompile_interaction_tree, Events.KeyEvent(Events.Key(:enter)))
    precompile_focus_requester = Toolkit.FocusRequester()
    precompile_requested_focus = Toolkit.focus_requester(
        Widgets.Label("Requested"),
        precompile_focus_requester,
    )
    precompile_requested_tree = Toolkit.ToolkitTree(precompile_requested_focus)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 16))),
        precompile_requested_tree,
    )
    Toolkit.focus_requester_target(precompile_focus_requester)
    Toolkit.request_focus!(precompile_requested_tree, precompile_focus_requester)
    Toolkit.focus_requester_focused(precompile_requested_tree, precompile_focus_requester)
    Toolkit.release_focus!(precompile_requested_tree, precompile_focus_requester)
    precompile_animation_manager = AnimationManager(policy=DisabledMotion, clock=() -> UInt64(0))
    precompile_animation_target = Ref(0.0)
    precompile_animation_component = animation_provider(precompile_animation_manager) do
        Toolkit.component(id=:precompile_animated) do state
            value = animate_value_as_state!(
                state,
                :value,
                precompile_animation_target[];
                duration=0.1,
            )
            string(animated_value(value))
        end
    end
    precompile_animation_tree = Toolkit.ToolkitTree(precompile_animation_component)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 16))),
        precompile_animation_tree,
    )
    precompile_animation_target[] = 1.0
    precompile_animation_tree.root = precompile_animation_component
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 16))),
        precompile_animation_tree,
    )
    precompile_effect_tree.root = Toolkit.element(Widgets.Label("Disposed"))
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 16))),
        precompile_effect_tree,
    )
    precompile_tracked_tree.root = Toolkit.element(Widgets.Label("Disposed"))
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))),
        precompile_tracked_tree,
    )
    yield()
    precompile_async_tree.root = Toolkit.element(Widgets.Label("Disposed"))
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))),
        precompile_async_tree,
    )
    precompile_reactive_signal = Reactive.Signal(1)
    precompile_reactive_element = ReactiveToolkit.reactive_element(
        :precompile_reactive,
        value -> "Reactive: $value",
        [precompile_reactive_signal],
    )
    precompile_reactive_component = ReactiveToolkit.reactive_component(
        precompile_reactive_element;
        id=:precompile_reactive,
    )
    precompile_reactive_tree = Toolkit.ToolkitTree(precompile_reactive_component)
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))),
        precompile_reactive_tree,
    )
    Reactive.set_signal!(precompile_reactive_signal, 2)
    precompile_reactive_state = Toolkit.element_state(precompile_reactive_tree, :precompile_reactive)
    ReactiveToolkit.use_reactive!(precompile_reactive_state, :direct, precompile_reactive_signal)
    precompile_reactive_tree.root = Toolkit.element(Widgets.Label("Disposed"))
    Toolkit.render_toolkit!(
        Core.Frame(Core.Buffer(Core.Rect(1, 1, 1, 24))),
        precompile_reactive_tree,
    )
    toolkit_root = Toolkit.column(
        Toolkit.Element(Widgets.Label("Status"); id=:status, key=:status),
        Toolkit.Element(
            Widgets.Button("Deploy", :deploy);
            id=:deploy,
            key=:deploy,
            classes=[:primary],
            focusable=true,
            on_event=(event, state) -> begin
                event.phase == Toolkit.TargetPhase || return nothing
                event.event isa Events.KeyEvent || return nothing
                event.event.key.code == :enter || return nothing
                return Toolkit.EventResponse(consumed=true, focus=:last)
            end,
        ),
        Toolkit.Element(
            Widgets.Button("Cancel", :cancel);
            id=:cancel,
            key=:cancel,
            focusable=true,
        );
        constraints=[Layout.Length(1), Layout.Length(3), Layout.Length(3)],
        on_capture=(event, state) -> begin
            event.phase == Toolkit.CapturePhase || return nothing
            Toolkit.EventResponse(message=:captured)
        end,
    )
    toolkit_tree = Toolkit.ToolkitTree(toolkit_root; styles)
    Toolkit.render_toolkit!(Core.Frame(Core.Buffer(Core.Rect(1, 1, 5, 32))), toolkit_tree)
    precompile_screens = Toolkit.ScreenStack()
    precompile_home = Toolkit.Screen(:home, (app, model) -> Toolkit.leaf(Widgets.Label("Home")))
    precompile_overlay = Toolkit.Screen(:help, (app, model) -> Toolkit.leaf(Widgets.Label("Help")); mode=Toolkit.OverlayScreen)
    precompile_registry = Toolkit.ScreenRegistry(precompile_home)
    Toolkit.set_screen_route_metadata!(
        precompile_registry,
        :home;
        title="Home",
        description="Primary screen",
        group="Main",
        keywords=("dashboard", "start"),
    )
    Toolkit.register_screen!(
        precompile_registry,
        precompile_overlay;
        title="Help",
        description="Help overlay",
        group="Support",
        keywords=("docs", "shortcuts"),
        enabled=false,
        disabled_reason="Requires documentation context",
    )
    Toolkit.screen_registry_count(precompile_registry)
    Toolkit.screen_registry_empty(precompile_registry)
    Toolkit.screen_registry_ids(precompile_registry)
    Toolkit.screen_registry_modes(precompile_registry)
    Toolkit.screen_registry_groups(precompile_registry)
    Toolkit.screen_registry_group_records(precompile_registry)
    Toolkit.screen_registry_group_summary(precompile_registry)
    Toolkit.screen_registry_group_json(precompile_registry)
    Toolkit.screen_registry_group_markdown(precompile_registry)
    Toolkit.screen_registry_group_text(precompile_registry)
    Toolkit.screen_registry_group_summary_text(precompile_registry)
    Toolkit.screen_registry_group_tsv(precompile_registry)
    Toolkit.screen_registry_screens(precompile_registry)
    Toolkit.screen_registry_records(precompile_registry)
    Toolkit.screen_registry_summary(precompile_registry)
    Toolkit.screen_registry_text(precompile_registry)
    Toolkit.screen_registry_summary_text(precompile_registry)
    Toolkit.screen_route_metadata(precompile_registry, :home)
    Toolkit.screen_route_title(precompile_registry, :home)
    Toolkit.screen_route_description(precompile_registry, :home)
    Toolkit.screen_route_group(precompile_registry, :home)
    Toolkit.screen_route_keywords(precompile_registry, :home)
    Toolkit.screen_route_enabled(precompile_registry, :home)
    Toolkit.screen_route_disabled_reason(precompile_registry, :help)
    Toolkit.disable_screen_route!(precompile_registry, :home; reason="Unavailable during startup")
    Toolkit.set_screen_route_disabled_reason!(precompile_registry, :home, "Deferred until ready")
    Toolkit.clear_screen_route_disabled_reason!(precompile_registry, :home)
    Toolkit.enable_screen_route!(precompile_registry, :home)
    Toolkit.set_screen_route_enabled!(precompile_registry, :help, true)
    Toolkit.screen_registry_json(precompile_registry)
    Toolkit.screen_registry_markdown(precompile_registry)
    Toolkit.screen_registry_tsv(precompile_registry)
    Toolkit.screen_registry_filter_records(precompile_registry; mode=Toolkit.OverlayScreen)
    Toolkit.screen_registry_filter_records(precompile_registry; group="Main")
    Toolkit.screen_registry_filter_records(precompile_registry; enabled=true)
    Toolkit.screen_registry_filter_count(precompile_registry; mode=Toolkit.ReplaceScreen)
    Toolkit.screen_registry_filter_count(precompile_registry; group="Support")
    Toolkit.screen_registry_filter_count(precompile_registry; enabled=false)
    Toolkit.search_screen_registry_records(precompile_registry, "home")
    Toolkit.search_screen_registry_count(precompile_registry, "help")
    Toolkit.search_screen_registry_json(precompile_registry, "home")
    Toolkit.search_screen_registry_markdown(precompile_registry, "help")
    Toolkit.search_screen_registry_tsv(precompile_registry, "Overlay")
    Toolkit.search_screen_registry_records(precompile_registry, "Main"; group="Main")
    Toolkit.search_screen_registry_records(precompile_registry, "true"; enabled=true)
    precompile_history = Toolkit.ScreenHistory()
    Toolkit.screen_history_empty(precompile_history)
    Toolkit.push_screen_history!(precompile_history, :home)
    Toolkit.replace_screen_history!(precompile_history, :home)
    Toolkit.push_screen_history!(precompile_history, :help)
    Toolkit.current_screen_history_id(precompile_history)
    Toolkit.can_go_back(precompile_history)
    Toolkit.can_go_forward(precompile_history)
    Toolkit.screen_history_count(precompile_history)
    Toolkit.screen_history_records(precompile_history)
    Toolkit.screen_history_summary(precompile_history)
    Toolkit.screen_history_json(precompile_history)
    Toolkit.screen_history_markdown(precompile_history)
    Toolkit.screen_history_tsv(precompile_history)
    Toolkit.screen_history_command_items(precompile_history, precompile_registry)
    Toolkit.screen_history_command_palette(precompile_history, precompile_registry)
    Toolkit.screen_history_command_palette_session(precompile_history, precompile_registry; query="back")
    Toolkit.screen_history_menu_items(precompile_history, precompile_registry)
    Toolkit.screen_history_menu(precompile_history, precompile_registry)
    Toolkit.screen_history_menu_session(precompile_history, precompile_registry)
    Toolkit.screen_registry_binding_map(precompile_registry, [:home => :h, :help => :question])
    Toolkit.screen_registry_binding_layer(precompile_registry, [:home => :h, :help => :question])
    Toolkit.screen_history_binding_map(precompile_history, precompile_registry; include_unavailable=true)
    Toolkit.screen_history_binding_layer(precompile_history, precompile_registry; include_unavailable=true)
    Toolkit.back_screen_history!(precompile_history)
    Toolkit.forward_screen_history!(precompile_history)
    Toolkit.screen_registry_command_items(precompile_registry)
    Toolkit.screen_registry_command_items(precompile_registry; replace=true)
    Toolkit.screen_registry_command_items(precompile_registry; group="Main")
    Toolkit.screen_registry_command_palette(precompile_registry)
    Toolkit.screen_registry_command_palette(precompile_registry; group="Main")
    Toolkit.screen_registry_command_palette_session(precompile_registry; query="home")
    Toolkit.search_screen_registry_command_items(precompile_registry, "home")
    Toolkit.search_screen_registry_command_palette(precompile_registry, "home")
    Toolkit.search_screen_registry_command_palette_session(precompile_registry, "help"; palette_query="help")
    Toolkit.screen_registry_menu_items(precompile_registry)
    Toolkit.screen_registry_menu_items(precompile_registry; replace=true)
    Toolkit.screen_registry_menu_items(precompile_registry; group="Support")
    Toolkit.screen_registry_menu(precompile_registry)
    Toolkit.screen_registry_menu(precompile_registry; group="Support")
    Toolkit.screen_registry_menu_session(precompile_registry)
    Toolkit.search_screen_registry_menu_items(precompile_registry, "help")
    Toolkit.search_screen_registry_menu(precompile_registry, "help")
    Toolkit.search_screen_registry_menu_session(precompile_registry, "home")
    screen_registry_navigation_items(precompile_registry)
    screen_registry_navigation_items(precompile_registry; replace=true)
    screen_registry_navigation_rail(precompile_registry)
    screen_registry_navigation_rail_session(precompile_registry)
    search_screen_registry_navigation_items(precompile_registry, "help")
    search_screen_registry_navigation_rail(precompile_registry, "help")
    search_screen_registry_navigation_rail_session(precompile_registry, "home")
    precompile_route_tabs = screen_registry_tabs(precompile_registry)
    precompile_route_tabs_state = TabsState()
    screen_registry_tab_items(precompile_registry)
    screen_registry_tabs_session(precompile_registry; selected=1)
    search_screen_registry_tab_items(precompile_registry, "help")
    search_screen_registry_tabs(precompile_registry, "help")
    search_screen_registry_tabs_session(precompile_registry, "home"; selected=1)
    selected_screen_registry_tab_message(precompile_registry, precompile_route_tabs, precompile_route_tabs_state)
    selected_screen_registry_tab_message(precompile_registry, precompile_route_tabs, precompile_route_tabs_state; replace=true)
    Toolkit.has_registered_screen(precompile_registry, :home)
    Toolkit.registered_screen(precompile_registry, :home)
    Toolkit.PushRegisteredScreen(precompile_registry, :home)
    Toolkit.NavigateRegisteredScreen(precompile_registry, :home)
    Toolkit.NavigateRegisteredScreen(precompile_registry, :home; replace=true, record_history=false)
    Toolkit.BackRegisteredScreen(precompile_registry)
    Toolkit.ForwardRegisteredScreen(precompile_registry)
    Toolkit.ReplaceWithRegisteredScreen(precompile_registry, :help)
    Toolkit.clear_screen_history!(precompile_history)
    Toolkit.navigate_registered_screen!(precompile_screens, precompile_history, precompile_registry, :home)
    Toolkit.navigate_registered_screen!(precompile_screens, precompile_history, precompile_registry, :help; replace=false)
    Toolkit.back_registered_screen!(precompile_screens, precompile_history, precompile_registry)
    Toolkit.forward_registered_screen!(precompile_screens, precompile_history, precompile_registry)
    Toolkit.clear_screens!(precompile_screens)
    Toolkit.push_registered_screen!(precompile_screens, precompile_registry, :home)
    Toolkit.pop_screen!(precompile_screens)
    Toolkit.replace_registered_screen!(precompile_screens, precompile_registry, :help)
    Toolkit.clear_screens!(precompile_screens)
    Toolkit.unregister_screen!(precompile_registry, :help)
    Toolkit.register_screen!(precompile_registry, precompile_overlay)
    Toolkit.push_screen!(precompile_screens, precompile_home)
    Toolkit.push_screen!(precompile_screens, precompile_overlay)
    Toolkit.current_screen(precompile_screens)
    Toolkit.screen_stack_count(precompile_screens)
    Toolkit.screen_stack_empty(precompile_screens)
    Toolkit.screen_stack_element(toolkit_root, precompile_screens, nothing, nothing)
    Toolkit.screen_stack_element(precompile_screens, nothing, nothing)
    Toolkit.screen_stack_ids(precompile_screens)
    Toolkit.screen_stack_modes(precompile_screens)
    Toolkit.screen_stack_records(precompile_screens)
    Toolkit.screen_stack_summary(precompile_screens)
    screen_stack_breadcrumb_items(precompile_screens; registry=precompile_registry)
    screen_stack_breadcrumb(precompile_screens; registry=precompile_registry)
    screen_stack_breadcrumb_session(precompile_screens; registry=precompile_registry)
    Toolkit.screen_stack_json(precompile_screens)
    Toolkit.screen_stack_markdown(precompile_screens)
    Toolkit.screen_stack_tsv(precompile_screens)
    Toolkit.has_screen(precompile_screens, :home)
    Toolkit.PopToScreen(:home)
    Toolkit.PopToScreen(:home; inclusive=true)
    Toolkit.RemoveScreen(:help)
    Toolkit.ClearOverlayScreens()
    Toolkit.ClearScreens()
    Toolkit.pop_to_screen!(precompile_screens, :home)
    Toolkit.push_screen!(precompile_screens, precompile_overlay)
    Toolkit.remove_screen!(precompile_screens, :help)
    Toolkit.push_screen!(precompile_screens, precompile_overlay)
    Toolkit.clear_overlay_screens!(precompile_screens)
    Toolkit.push_screen!(precompile_screens, precompile_overlay)
    Toolkit.pop_screen!(precompile_screens)
    Toolkit.replace_screen!(precompile_screens, precompile_home)
    Toolkit.clear_screens!(precompile_screens)
    Interaction.focus!(toolkit_tree.state.focus, :deploy)
    Toolkit.dispatch!(toolkit_tree, Events.KeyEvent(Events.Key(:enter)))
    precompile_semantic_tree = SemanticToolkit.toolkit_semantic_tree(toolkit_tree; label="Precompile")
    deploy_semantic_node = query_one_semantic(precompile_semantic_tree; id=:deploy, role=ButtonRole)
    query_one_semantic(precompile_semantic_tree; id=:deploy)
    deploy_semantic_node.bounds === nothing || query_one_semantic(precompile_semantic_tree; bounds=deploy_semantic_node.bounds)
    query_one_semantic(precompile_semantic_tree; id=:deploy, focusable=true, enabled=true, hidden=false)
    semantic_pilot = SemanticPilot(precompile_semantic_tree)
    query_one_semantic(semantic_pilot; id=:deploy, role=ButtonRole)
    assert_semantic_query(semantic_pilot; id=:deploy, role=ButtonRole)
    widget_pilot = WidgetPilot(Widgets.Button("Pilot", :pilot); height=3, width=12)
    key!(widget_pilot, :enter)
    pilot_semantic_tree(widget_pilot; label="Precompile widget")
    pilot_semantic_snapshot(widget_pilot; label="Precompile widget")
    assert_semantic_query(widget_pilot, SemanticQuery(role=ButtonRole); minimum=1, label="Precompile widget")
    assert_semantic_query(widget_pilot, SemanticQuery(actions=[ActivateSemanticAction]); minimum=1, label="Precompile widget")
    assert_semantic_query(widget_pilot, SemanticQuery(role=ButtonRole); label="Precompile widget")
    assert_semantic_query(widget_pilot, SemanticQuery(enabled=true); minimum=1, label="Precompile widget")
    assert_semantic_query(widget_pilot, SemanticQuery(role=ButtonRole); maximum=1, label="Precompile widget")
    assert_semantic_snapshot(widget_pilot, pilot_semantic_snapshot(widget_pilot; label="Precompile widget"); label="Precompile widget")
    plain_snapshot(widget_pilot)
    toolkit_pilot = ToolkitPilot(toolkit_root; height=5, width=32, styles)
    focus_element!(toolkit_pilot, :deploy)
    key!(toolkit_pilot, :enter)
    query(toolkit_pilot; id=:deploy, widget_type=Widgets.Button)
    pilot_semantic_tree(toolkit_pilot; label="Precompile pilot")
    pilot_semantic_snapshot(toolkit_pilot; label="Precompile pilot")
    query_one_semantic(toolkit_pilot, SemanticQuery(id=:deploy, role=ButtonRole); label="Precompile pilot")
    assert_semantic_query(toolkit_pilot, SemanticQuery(id=:deploy, role=ButtonRole); label="Precompile pilot")
    assert_semantic_snapshot(toolkit_pilot, pilot_semantic_snapshot(toolkit_pilot; label="Precompile pilot"); label="Precompile pilot")
    plain_snapshot(toolkit_pilot)
    evidence_bundle = pilot_evidence_bundle(toolkit_pilot)
    pilot_status(toolkit_pilot)
    pilot_status_text(toolkit_pilot)
    pilot_status_tsv(toolkit_pilot)
    pilot_status_markdown(toolkit_pilot)
    pilot_evidence_text(evidence_bundle)
    pilot_evidence_tsv(evidence_bundle)
    pilot_evidence_markdown(evidence_bundle)
    pilot_evidence_summary(evidence_bundle)
    pilot_evidence_summary_text(evidence_bundle)
    pilot_evidence_summary_tsv(evidence_bundle)
    pilot_evidence_summary_markdown(evidence_bundle)
    pilot_evidence_manifest_records(evidence_bundle)
    pilot_evidence_manifest(evidence_bundle)
    pilot_evidence_manifest_tsv(evidence_bundle)
    pilot_evidence_manifest_markdown(evidence_bundle)
    pilot_evidence_report_artifacts(evidence_bundle)
    pilot_evidence_report_manifest_records(evidence_bundle)
    pilot_evidence_report_manifest_tsv(evidence_bundle)
    pilot_evidence_report_manifest_markdown(evidence_bundle)
    pilot_evidence_report_summary(evidence_bundle)
    pilot_evidence_report_summary_text(evidence_bundle)
    pilot_evidence_report_summary_tsv(evidence_bundle)
    pilot_evidence_report_summary_markdown(evidence_bundle)
    pilot_evidence_package_manifest_records(evidence_bundle)
    pilot_evidence_package_manifest_tsv(evidence_bundle)
    pilot_evidence_package_manifest_markdown(evidence_bundle)
    pilot_evidence_package_summary(evidence_bundle)
    pilot_evidence_package_summary_text(evidence_bundle)
    pilot_evidence_package_summary_tsv(evidence_bundle)
    pilot_evidence_package_summary_markdown(evidence_bundle)
    pilot_evidence_package_report_artifacts(evidence_bundle)
    pilot_evidence_package_report_manifest_records(evidence_bundle)
    pilot_evidence_package_report_manifest_tsv(evidence_bundle)
    pilot_evidence_package_report_manifest_markdown(evidence_bundle)
    pilot_evidence_package_report_summary(evidence_bundle)
    pilot_evidence_package_report_summary_text(evidence_bundle)
    pilot_evidence_package_report_summary_tsv(evidence_bundle)
    pilot_evidence_package_report_summary_markdown(evidence_bundle)

    signal = Reactive.Signal(0; name="precompile")
    observed = Int[]
    subscription = Reactive.subscribe!(signal) do value, _, _
        push!(observed, value)
    end
    Reactive.update_signal!(value -> value + 1, signal)
    Reactive.signal_value(signal)
    Reactive.unsubscribe!(subscription)

    catalog = stable_widget_catalog(; status=:stable, surface=:stable)
    widget_catalog(; status="stable", surface="stable")
    stable_widget_count()
    stable_widget_names()
    widget_names_text()
    search_widget_names_text(:button)
    widget_source_files()
    widget_source_files_text()
    search_widget_source_files_text(:button)
    widget_source_summary()
    widget_source_summary_markdown()
    widget_source_summary_tsv()
    widget_source_summary_tsv(header=false)
    search_widgets(:button)
    search_widget_count(:button)
    search_widgets(r"Button")
    group_widgets(:source)
    widget_catalog_summary()
    widget_catalog_markdown(columns=(:name, :source))
    widget_catalog_markdown(columns=:name)
    widget_catalog_records()
    widget_catalog_tsv(columns=(:name, :status))
    widget_catalog_tsv(columns=(:name, :status), header=false)
    widget_family_closeout_reports()
    widget_family_closeout_records()
    widget_family_closeout_complete()
    widget_family_closeout_markdown()
    widget_family_closeout_tsv()
    widget_family_closeout_json()
    widget_family_closeout_artifacts()
    widget_family_closeout_artifacts_json()
    widget_family_closeout_artifacts_text()
    widget_family_closeout_artifacts_markdown()
    widget_family_closeout_artifacts_tsv()
    widget_vocabulary_records()
    search_widget_vocabulary(:button)
    widget_vocabulary_tsv(header=false)
    widget_coverage_records()
    widget_coverage_gaps()
    widget_coverage_issue_records(:complete)
    widget_coverage_issue_count(:missing_checks)
    widget_coverage_issue_names(:missing_checks)
    widget_coverage_issue_text(:missing_checks)
    widget_coverage_issue_markdown(:source_mismatch, columns=(:name, :issue))
    widget_coverage_issue_tsv(:source_mismatch, columns=(:name, :issue), header=false)
    widget_coverage_complete()
    widget_coverage_git_metadata(root=pwd())
    widget_coverage_release_ready(root=pwd())
    widget_coverage_release_status_record(root=pwd())
    widget_coverage_release_status_json(root=pwd())
    widget_coverage_release_status_text(root=pwd())
    widget_coverage_summary()
    widget_coverage_summary_records()
    widget_coverage_summary_markdown()
    widget_coverage_summary_json(include_git=false)
    widget_coverage_summary_tsv(header=false)
    widget_coverage_summary_text()
    widget_stability_complete()
    isempty(widget_stability_gaps()) &&
        assert_widget_stability_complete()
    widget_stability_summary()
    widget_stability_summary_records()
    widget_stability_summary_markdown()
    widget_stability_summary_tsv(header=false)
    widget_stability_summary_text()
    experimental_widget_names()
    experimental_widget_count()
    experimental_widget_records()
    experimental_widget_records_markdown()
    experimental_widget_records_tsv(header=false)
    experimental_widget_records_json()
    candidate_widget_names()
    candidate_widget_count()
    candidate_widget_records()
    candidate_widget_records_markdown()
    candidate_widget_records_tsv(header=false)
    candidate_widget_records_json()
    widget_stabilization_status_record()
    widget_stabilization_status_records()
    widget_stabilization_status_text()
    widget_stabilization_status_json()
    widget_stabilization_status_markdown()
    widget_stabilization_status_tsv(header=false)
    widget_stabilization_artifacts()
    widget_stabilization_artifacts_json()
    widget_stabilization_artifacts_text()
    widget_stabilization_artifacts_markdown()
    widget_stabilization_artifacts_tsv(header=false)
    widget_stabilization_artifacts_ready() && assert_widget_stabilization_artifacts_ready()
    widget_stabilization_closeout_records()
    widget_stabilization_closeout_kind_records(:experimental)
    widget_stabilization_closeout_kind_count(:candidate)
    widget_stabilization_closeout_kind_markdown(:experimental)
    widget_stabilization_closeout_kind_tsv(:candidate; header=false)
    widget_stabilization_closeout_kind_json(:experimental)
    widget_stabilization_closeout_kind_text(:candidate)
    widget_stabilization_closeout_kind_artifacts(:candidate)
    widget_stabilization_closeout_kind_complete(:experimental)
    widget_stabilization_closeout_kind_complete(:experimental) &&
        assert_widget_stabilization_closeout_kind_complete(:experimental)
    search_widget_stabilization_closeout_records("button")
    search_widget_stabilization_closeout_count("button")
    search_widget_stabilization_closeout_summary("button")
    search_widget_stabilization_closeout_summary_records("button")
    search_widget_stabilization_closeout_summary_markdown("button")
    search_widget_stabilization_closeout_summary_tsv("button"; header=false)
    search_widget_stabilization_closeout_summary_json("button")
    search_widget_stabilization_closeout_summary_text("button")
    search_widget_stabilization_closeout_complete("button")
    search_widget_stabilization_closeout_complete("button") &&
        assert_search_widget_stabilization_closeout_complete("button")
    search_widget_stabilization_closeout_markdown("button")
    search_widget_stabilization_closeout_tsv("button"; header=false)
    search_widget_stabilization_closeout_json("button")
    search_widget_stabilization_closeout_text("button")
    search_widget_stabilization_closeout_artifacts("button")
    widget_stabilization_closeout_count()
    widget_stabilization_closeout_complete()
    widget_stabilization_closeout_complete() && assert_widget_stabilization_closeout_complete()
    widget_stabilization_closeout_summary()
    widget_stabilization_closeout_summary_records()
    widget_stabilization_closeout_summary_markdown()
    widget_stabilization_closeout_summary_tsv(header=false)
    widget_stabilization_closeout_summary_json()
    widget_stabilization_closeout_summary_text()
    widget_stabilization_closeout_status_record()
    widget_stabilization_closeout_status_text()
    widget_stabilization_closeout_status_json()
    widget_stabilization_closeout_status_markdown()
    widget_stabilization_closeout_status_tsv(header=false)
    widget_stabilization_closeout_markdown()
    widget_stabilization_closeout_tsv(header=false)
    widget_stabilization_closeout_json()
    widget_stabilization_closeout_text()
    widget_stabilization_closeout_artifacts()
    widget_stabilization_blocker_records()
    widget_stabilization_blocker_records_markdown()
    widget_stabilization_blocker_records_tsv(header=false)
    widget_stabilization_blocker_records_json()
    widget_stabilization_blockers()
    widget_stabilization_blocker_count()
    widget_stabilization_blockers_text()
    widget_stabilization_blockers_markdown()
    widget_stabilization_blockers_tsv(header=false)
    widget_stabilization_ready() && assert_widget_stabilization_ready()
    widget_surface_release_status_record(root=pwd())
    widget_surface_release_ready(root=pwd())
    widget_surface_release_status_text(root=pwd())
    widget_surface_release_status_json(root=pwd())
    widget_coverage_records_markdown(columns=(:name, :issue, :missing_checks))
    widget_coverage_gaps_markdown(columns=(:name, :issue, :missing_checks))
    widget_coverage_records_tsv(columns=(:name, :issue))
    widget_coverage_gaps_tsv(columns=(:name, :issue), header=false)
    search_widget_catalog_markdown(:button; columns=:name)
    search_widget_catalog_tsv(:button; columns=(:name, :status))
    search_widget_catalog_tsv(:button; columns=(:name, :status), header=false)
    is_stable_widget(:Button; catalog=catalog)
    is_stable_widget("Button"; catalog=catalog)
    isempty(catalog) || widget_catalog_entry(first(catalog).name; catalog=catalog)
    assert_stable_widget(:Button; catalog=catalog)

    Core.draw_text!(buffer, 1, 1, "cache"; style, clip=area)
    Core.request_cursor!(frame, 1, 1)

    completed = copy(buffer)
    changes = Core.diff_buffers(Core.Buffer(area), completed)
    backend = Backends.TestBackend(12, 48)
    Backends.present!(backend, changes, completed, frame.cursor)
    Backends.backend_size(backend)
    Backends.backend_capabilities(backend)

    nothing
end

if ccall(:jl_generating_output, Cint, ()) == 1
    _precompile_common_workload!()
end

"""
    precompile_stable_workload!()

Run the same conservative warmup payload that protects first-import latency in stable
`Wicked` applications.

The workload intentionally keeps startup side effects minimal:

- in-memory data only
- no terminal mode changes
- no optional dependency loading
"""
precompile_stable_workload!() = _precompile_common_workload!()
