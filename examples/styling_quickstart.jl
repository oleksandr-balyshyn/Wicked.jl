using Wicked.API

sheet = parse_stylesheet("""
Button.primary {
  color: bright-cyan;
}

Button.primary:focus {
  modifiers: bold underline;
}

Button.secondary {
  color: yellow;
}
""")

theme = Theme(
    :quickstart;
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

pilot = ToolkitPilot(root; height=4, width=28, styles)
@assert occursin("Deployments", plain_snapshot(pilot))
@assert occursin("Deploy", plain_snapshot(pilot))

focus_element!(pilot, :deploy)
draw!(pilot)

button = query_one(pilot; id=:deploy, widget_type=Button, focused=true)
@assert button.state isa ButtonState

context = StyleContext(Button, :deploy, Set([:primary]), Set([:focus]), Set{Symbol}())
context_record = style_context_record(context)
@assert context_record.widget_type == "Button"
@assert context_record.id == "deploy"
@assert context_record.classes == "primary"
@assert context_record.states == "focus"
@assert occursin("classes: primary", style_context_text(context))
@assert startswith(style_context_markdown(context), "| field | value |")
@assert startswith(style_context_tsv(context), "field\tvalue")
resolved = computed_style(styles, context; role=:accent, inline=StylePatch(add_modifiers=UNDERLINE))
@assert resolved.foreground == AnsiColor(14)
@assert BOLD in resolved.modifiers
@assert UNDERLINE in resolved.modifiers

explanation = explain_style(styles, context; role=:accent, inline=StylePatch(add_modifiers=UNDERLINE))
records = style_explanation_records(explanation)
@assert explanation.result == resolved
@assert [record.index for record in records] == [1, 2, 3, 4]
@assert [record.source for record in records] == [:theme, :stylesheet, :stylesheet, :inline]
@assert selector_text(sheet.rules[1].selector) == "Button.primary"
@assert records[2].selector_text == "Button.primary"
@assert occursin("stylesheet", style_explanation_text(explanation))
@assert startswith(style_explanation_markdown(explanation), "| index | source |")
@assert startswith(style_explanation_tsv(explanation), "index\tsource")
@assert search_style_explanation_count(explanation, "stylesheet") == 2
@assert [record.index for record in search_style_explanation_records(explanation, "stylesheet")] == [2, 3]
@assert only(search_style_explanation_records(explanation, "inline")).index == 4
@assert occursin("stylesheet", search_style_explanation_text(explanation, "stylesheet"))
@assert startswith(search_style_explanation_markdown(explanation, "stylesheet"), "| index | source |")
@assert startswith(search_style_explanation_tsv(explanation, "stylesheet"), "index\tsource")
@assert search_style_explanation_count(explanation, "Button.primary:focus") == 1
summary = style_explanation_summary(explanation)
@assert summary.total == 4
@assert style_explanation_summary_records(explanation) == [
    (source=:inline, count=1),
    (source=:stylesheet, count=2),
    (source=:theme, count=1),
]
@assert occursin("stylesheet: 2", style_explanation_summary_text(explanation))
@assert startswith(style_explanation_summary_markdown(explanation), "| source | count |")
@assert startswith(style_explanation_summary_tsv(explanation), "source\tcount")
rule_matches = style_rule_match_records(styles, context)
@assert style_rule_match_summary(styles, context) == (total=3, matched=2, unmatched=1)
@assert [record.selector_text for record in matching_style_rule_records(styles, context)] == ["Button.primary", "Button.primary:focus"]
unmatched_rule = only(unmatched_style_rule_records(styles, context))
@assert unmatched_rule.selector_text == "Button.secondary"
@assert unmatched_rule.mismatch_reasons == ["classes"]
@assert selector_match_reasons(unmatched_rule.selector, context) == ["classes"]
@assert occursin("matched=false", unmatched_style_rule_text(styles, context))
@assert startswith(style_rule_match_markdown(styles, context), "| index | selector |")
@assert startswith(style_rule_match_tsv(styles, context), "index\tselector")
@assert search_style_rule_match_count(styles, context, "classes") == 1
@assert only(search_style_rule_match_records(styles, context, "matched=false")).selector_text == "Button.secondary"
@assert occursin("Button.primary", search_style_rule_match_text(styles, context, "Button.primary"))
@assert startswith(search_style_rule_match_markdown(styles, context, "stylesheet"), "| index | selector |")
@assert startswith(search_style_rule_match_tsv(styles, context, "classes"), "index\tselector")
diagnostics = style_diagnostics(styles, context; role=:accent, inline=StylePatch(add_modifiers=UNDERLINE))
diagnostics_record = style_diagnostics_record(diagnostics)
@assert diagnostics isa StyleDiagnostics
@assert diagnostics_record.total_rules == 3
@assert diagnostics_record.matched_rules == 2
@assert diagnostics_record.unmatched_rules == 1
@assert occursin("[rule matches]", style_diagnostics_text(diagnostics))
@assert occursin("## Resolution", style_diagnostics_markdown(diagnostics))
@assert startswith(style_diagnostics_tsv(diagnostics), "section\tfield\tvalue")
@assert search_style_diagnostics_count(diagnostics, "resolution") == 4
@assert any(record -> record.section == :rule_match, search_style_diagnostics_records(diagnostics, "classes"))
@assert occursin("matched=false", search_style_diagnostics_text(diagnostics, "matched=false"))
@assert startswith(search_style_diagnostics_markdown(diagnostics, "Button.primary"), "| section | index |")
@assert startswith(search_style_diagnostics_tsv(diagnostics, "inline"), "section\tindex")

parsed, diagnostics = try_parse_stylesheet("Button { unknown: value; }")
@assert parsed isa Stylesheet
@assert !isempty(diagnostics)

println("styling quickstart example completed")
