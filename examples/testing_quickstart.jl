using Wicked.API

button = WidgetPilot(Button("Go", :go); height=3, width=12)
@assert occursin("Go", plain_snapshot(button))

pressed = key!(button, :enter)
@assert pressed.handled
@assert button.state isa ButtonState
released = press!(button, :enter)
@assert released.handled
@assert click!(button, 2, 4).handled
@assert occursin("widget:ButtonRole", pilot_semantic_snapshot(button))
assert_semantic_query(button, SemanticQuery(role=ButtonRole))
wait_for_semantic!(button, SemanticQuery(role=ButtonRole))
@assert only(wait_query_semantics!(button, SemanticQuery(role=ButtonRole))).id == "widget"
@assert wait_query_one_semantic!(button, SemanticQuery(role=ButtonRole)).id == "widget"

resize_terminal!(button, 3, 16)
@assert occursin("Go", plain_snapshot(button))
wait_for_text!(button, "Go")
wait_for_plain_snapshot!(button, plain_snapshot(button))
wait_for_ansi_snapshot!(button, ansi_snapshot(button))
wait_for_structured_snapshot!(button, structured_snapshot(button))
wait_for_svg_snapshot!(button, svg_snapshot(button))
wait_for_cell!(button, 1, 1; grapheme=button.backend.screen[1, 1].grapheme)
wait_for_buffer!(button, buffer -> size(buffer) == size(button.backend.screen))
assert_buffer(button, buffer -> size(buffer) == size(button.backend.screen))
assert_structured_snapshot(button, structured_snapshot(button))
assert_svg_snapshot(button, svg_snapshot(button))
bundle = snapshot_bundle(button)
@assert bundle.source_kind == :widget_pilot
@assert bundle.plain == plain_snapshot(button)
assert_snapshot_bundle(button, bundle)
wait_for_snapshot_bundle!(button, bundle)
wait_for_snapshot_bundle_where!(button, candidate -> occursin("Go", candidate.plain))
artifact_contents = snapshot_bundle_artifacts(bundle)
@assert haskey(artifact_contents, "manifest.txt")
@assert occursin("sha256=", snapshot_bundle_manifest(bundle))
records = snapshot_bundle_manifest_records(bundle)
@assert all(record -> record isa SnapshotArtifactRecord, records)
@assert any(record -> record.name == "plain.txt", records)
summary = snapshot_bundle_summary(bundle)
@assert summary isa SnapshotArtifactSummary
@assert summary.artifact_count == length(records)
@assert occursin("artifact_count=", snapshot_artifact_summary_text(summary))
@assert startswith(snapshot_artifact_summary_tsv(summary), "source_kind\tartifact_count")
@assert startswith(snapshot_artifact_summary_markdown(summary), "| `source_kind` |")
reports = snapshot_bundle_report_artifacts(bundle)
@assert haskey(reports, "summary.md")
@assert startswith(snapshot_bundle_manifest_tsv(bundle), "name\tbytes\tsha256")
@assert startswith(snapshot_bundle_manifest_markdown(bundle), "| `name` |")
mktempdir() do directory
    write_snapshot_bundle(directory, bundle)
    @assert verify_snapshot_bundle_artifacts(directory)
    assert_snapshot_bundle_artifacts(directory, bundle)
    @assert read_snapshot_bundle_manifest_records(directory) == records
    @assert snapshot_bundle_artifact_summary(directory) == summary
    @assert startswith(snapshot_bundle_artifact_manifest_tsv(directory), "name\tbytes\tsha256")
    @assert startswith(snapshot_bundle_artifact_manifest_markdown(directory), "| `name` |")
end
mktempdir() do directory
    written_reports = write_snapshot_bundle_reports(directory, bundle)
    @assert read(written_reports["summary.md"], String) == reports["summary.md"]
end

root = column(
    Element(Button("Save", :save); id=:save, key=:save, focusable=true),
    Element(Checkbox("Enabled"); id=:enabled, key=:enabled, focusable=true);
    constraints=[Length(3), Length(1)],
)

pilot = ToolkitPilot(root; height=5, width=24)
save = query_one(pilot; id=:save, widget_type=Button)
@assert save.state isa ButtonState
@assert assert_query_one(pilot; id=:save, widget_type=Button).id == :save
@assert length(assert_query(pilot; text="Save")) == 2
@assert assert_no_query(pilot; text="Missing") === pilot
@assert wait_for_no_query!(pilot; text="Missing") === pilot
@assert length(wait_query!(pilot; text="Save")) == 2
@assert wait_query_one!(pilot; id=:save, widget_type=Button).id == :save
@assert wait_for_semantic!(pilot, SemanticQuery(id=:save, role=ButtonRole); label="Testing quickstart") === pilot
@assert wait_for_no_semantic!(pilot, SemanticQuery(id=:missing); label="Testing quickstart") === pilot
@assert wait_query_one_semantic!(pilot, SemanticQuery(id=:save, role=ButtonRole); label="Testing quickstart").id == "save"
wait_for_text!(pilot, "Save")
@assert wait_for_plain_snapshot!(pilot, plain_snapshot(pilot)) === pilot
@assert wait_for_snapshot_bundle!(pilot, snapshot_bundle(pilot)) === pilot
@assert wait_for_buffer!(pilot, buffer -> occursin("Save", plain_snapshot(buffer))) === pilot
@assert assert_buffer(pilot, buffer -> occursin("Save", plain_snapshot(buffer))) === pilot
@assert assert_cell(pilot, 1, 1, pilot.backend.screen[1, 1]) == pilot.backend.screen[1, 1]

focus_element!(pilot, :save)
@assert focused_element(pilot) == :save
@assert assert_focus(pilot, :save) === pilot
@assert assert_no_focus(pilot, :enabled) === pilot
@assert wait_for_focus!(pilot, :save) === pilot
@assert wait_for_no_focus!(pilot, :enabled) === pilot
key!(pilot, :enter)
@assert wait_messages!(pilot) == [:save]
@assert assert_message(pilot, queued -> queued == [:save]) === pilot
@assert assert_messages(pilot, [:save]) === pilot
@assert messages(pilot) == take_messages!(pilot)
@assert assert_no_messages(pilot) === pilot
@assert wait_for_no_messages!(pilot) === pilot

focus_element!(pilot, :enabled)
key!(pilot, :enter)
enabled = query_one(pilot; id=:enabled, widget_type=Checkbox, focused=true)
@assert enabled.state isa CheckboxState

@assert assert_running(pilot) === pilot
@assert wait_for_running!(pilot) === pilot
request_exit!(pilot, :saved)
@assert pilot_exited(pilot)
@assert exit_result(pilot) == :saved
@assert assert_exited(pilot; result=:saved) === pilot
@assert wait_for_exit!(pilot; result=:saved) === pilot

evidence = pilot_evidence_bundle(pilot)
@assert evidence isa PilotEvidenceBundle
@assert pilot_evidence_summary(evidence) isa PilotEvidenceSummary
@assert startswith(pilot_evidence_manifest_tsv(evidence), "name\tbytes\tsha256")
@assert startswith(pilot_evidence_report_manifest_tsv(evidence), "name\tbytes\tsha256")
@assert startswith(pilot_evidence_package_manifest_tsv(evidence), "name\tbytes\tsha256")
@assert startswith(pilot_evidence_package_report_manifest_tsv(evidence), "name\tbytes\tsha256")
@assert occursin("source_kind=pilot_evidence_package", pilot_evidence_package_summary_text(evidence))
@assert occursin("source_kind=pilot_evidence_package_reports", pilot_evidence_package_report_summary_text(evidence))

mktempdir() do directory
    write_pilot_evidence_package(directory, evidence)
    @assert verify_pilot_evidence_package(directory)
    assert_pilot_evidence_package_artifacts(directory, evidence)
    @assert read_pilot_evidence_package_manifest_records(directory) == pilot_evidence_package_manifest_records(evidence)
    @assert pilot_evidence_package_artifact_summary(directory) == pilot_evidence_package_summary(evidence)

    mktempdir() do reports_directory
        write_pilot_evidence_package_reports(reports_directory, directory)
        @assert verify_pilot_evidence_package_report_artifacts(reports_directory)
        assert_pilot_evidence_package_report_artifacts(reports_directory, directory)
        @assert startswith(pilot_evidence_package_report_artifact_manifest_tsv(reports_directory), "name\tbytes\tsha256")
        @assert occursin("source_kind=pilot_evidence_package_reports", pilot_evidence_package_report_artifact_summary_text(reports_directory))
    end
end

tree = pilot_semantic_tree(pilot; label="Testing quickstart")
@assert isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(tree)))

semantic = semantic_snapshot(tree)
pilot_semantic = pilot_semantic_snapshot(pilot; label="Testing quickstart")
@assert semantic == pilot_semantic
assert_semantic_snapshot(pilot, pilot_semantic; label="Testing quickstart")
assert_semantic_query(pilot, SemanticQuery(id=:save, role=ButtonRole); label="Testing quickstart")
assert_no_semantic_query(pilot, SemanticQuery(id=:missing); label="Testing quickstart")
wait_for_no_semantic!(pilot, SemanticQuery(id=:missing); label="Testing quickstart")
@assert occursin("save:ButtonRole", semantic)
@assert occursin("enabled:CheckboxRole", semantic)

println("testing quickstart example completed")
