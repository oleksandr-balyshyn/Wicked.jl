mutable struct TestingPilotModel
    count::Int
end

struct TestingPilotApp <: WickedApp end

initialize(::TestingPilotApp) = TestingPilotModel(0)
app_view(::TestingPilotApp, model::TestingPilotModel) = Label("count=$(model.count)")

function update!(::TestingPilotApp, model::TestingPilotModel, message)
    payload = message isa CustomEvent ? message.payload : message
    if message isa KeyEvent && message.key == Key(:up)
        model.count += 1
    elseif payload === :increment
        model.count += 1
    elseif payload === :delay
        return DelayCommand(0.5, :increment)
    elseif payload === :task
        return TaskCommand(() -> 7; on_success=value -> (:set, value))
    elseif payload isa Tuple && first(payload) === :set
        model.count = last(payload)
    elseif payload === :batch
        return BatchCommand(MessageCommand(:increment), MessageCommand(:increment))
    elseif payload === :exit
        return ExitCommand(model.count)
    end
    nothing
end

@testset "Headless testing API" begin
    @testset "capability-configurable backend" begin
        capabilities = TerminalCapabilities(
            color_level=:truecolor,
            mouse=false,
            focus=false,
        )
        backend = TestBackend(3, 7; capabilities)
        @test size(backend.screen) == (3, 7)
        @test backend.capabilities === capabilities
    end

    @testset "virtual monotonic clock" begin
        clock = VirtualClock(start_ns=10)
        observed = Any[]
        first_token = schedule_after!(clock, 1.0) do current
            push!(observed, (:first, virtual_time_ns(current)))
            schedule_after!(current, 0.0, () -> push!(observed, :nested))
        end
        cancelled = schedule_after!(() -> push!(observed, :cancelled), clock, 0.5)

        @test first_token isa ScheduledToken
        @test pending_scheduled(clock) == 2
        @test cancel_scheduled!(clock, cancelled)
        @test !cancel_scheduled!(clock, cancelled)
        @test advance_time!(clock, 0.5) == 0
        @test virtual_time_ns(clock) == 500_000_010
        @test advance_time!(clock, 0.5) == 2
        @test observed == [(:first, 1_000_000_010), :nested]
        @test pending_scheduled(clock) == 0
        @test_throws ArgumentError advance_time!(clock, -1)
        @test_throws ArgumentError schedule_after!(clock, Inf, () -> nothing)
    end

    @testset "snapshots and assertions" begin
        buffer = Buffer(1, 3)
        style = Style(foreground=AnsiColor(1), modifiers=BOLD)
        render!(buffer, Label("X"; style), buffer.area)

        @test plain_snapshot(buffer) == "X"
        structured = structured_snapshot(buffer)
        @test length(structured) == 3
        @test structured[1].foreground == (UInt8(1), UInt32(1))
        @test hasproperty(structured[1], :hyperlink)

        ansi = ansi_snapshot(buffer; capabilities=TerminalCapabilities(color_level=:ansi16))
        @test occursin("\e[0;31;49;1mX", ansi)
        @test endswith(ansi, "\e[0m")

        @test assert_cell(buffer, 1, 1, buffer[1, 1]) == buffer[1, 1]
        @test assert_cell(buffer, 1, 1; grapheme="X", style) == buffer[1, 1]
        @test assert_buffer(buffer, candidate -> plain_snapshot(candidate) == "X") === buffer
        @test assert_plain_snapshot(buffer, "X") === buffer
        @test assert_ansi_snapshot(buffer, ansi; capabilities=TerminalCapabilities(color_level=:ansi16)) === buffer
        @test_throws BufferAssertionError assert_cell(buffer, 1, 1; grapheme="Z")
        @test_throws BufferAssertionError assert_buffer(buffer, _ -> false)
        @test_throws ArgumentError assert_buffer(buffer, _ -> :not_a_bool)
        @test_throws BufferAssertionError assert_plain_snapshot(buffer, "Y")
        @test_throws BufferAssertionError assert_semantic_snapshot(SemanticTree(SemanticNode("root", GroupRole)), "missing")
        try
            assert_semantic_snapshot(SemanticTree(SemanticNode("root", GroupRole)), "missing")
        catch error
            @test error isa BufferAssertionError
            @test occursin("SemanticTree", sprint(showerror, error))
        end
    end

    @testset "pilot queries, time, and exit" begin
        pilot = ToolkitPilot(
            Element(
                Button("Alpha");
                id=:alpha,
                classes=[:copy],
            );
            height=3,
            width=9,
        )

        match = query_one(pilot; id=:alpha)
        @test match.state isa ButtonState
        @test length(query(pilot; text="Alpha")) == 1
        @test assert_query_one(pilot; id=:alpha).id == :alpha
        @test length(assert_query(pilot; text="Alpha")) == 1
        @test assert_no_query(pilot; text="missing") === pilot
        @test length(query(pilot; text=r"Alpha")) == 1
        @test length(query(pilot; text=value -> occursin("Alpha", value))) == 1
        @test length(query(pilot; state=match.state)) == 1
        @test length(query(pilot; state=ButtonState)) == 1
        @test length(query(pilot; state=value -> value isa ButtonState)) == 1
        @test isempty(query(pilot; text="missing"))
        @test_throws BufferAssertionError assert_query(pilot; text="missing")
        @test_throws BufferAssertionError assert_query_one(pilot; text="missing")
        @test_throws BufferAssertionError assert_no_query(pilot; text="Alpha")
        @test isempty(query(pilot; state=nothing))
        @test_throws ArgumentError query(pilot; text=_ -> :not_a_bool)
        @test_throws ArgumentError query(pilot; state=_ -> :not_a_bool)
        @test wait_for_query!(pilot; id=:alpha) === pilot
        @test wait_for_no_query!(pilot; text="missing") === pilot
        @test wait_until!(pilot, candidate -> !isempty(query(candidate; id=:alpha))) === pilot
        @test only(wait_query!(pilot; text="Alpha")).id == :alpha
        @test wait_query_one!(pilot; id=:alpha).id == :alpha
        @test wait_for_text!(pilot, "Alpha") === pilot
        @test wait_for_plain_snapshot!(pilot, plain_snapshot(pilot)) === pilot
        @test wait_for_ansi_snapshot!(pilot, ansi_snapshot(pilot)) === pilot
        @test wait_for_structured_snapshot!(pilot, structured_snapshot(pilot)) === pilot
        @test wait_for_svg_snapshot!(pilot, svg_snapshot(pilot)) === pilot
        @test wait_for_snapshot_bundle!(pilot, snapshot_bundle(pilot)) === pilot
        @test wait_for_snapshot_bundle_where!(pilot, bundle -> bundle == snapshot_bundle(pilot)) === pilot
        @test wait_for_buffer!(pilot, buffer -> occursin("Alpha", plain_snapshot(buffer))) === pilot
        @test assert_buffer(pilot, buffer -> occursin("Alpha", plain_snapshot(buffer))) === pilot
        @test wait_for_cell!(pilot, 1, 1; grapheme=pilot.backend.screen[1, 1].grapheme) === pilot
        @test assert_cell(pilot, 1, 1, pilot.backend.screen[1, 1]) == pilot.backend.screen[1, 1]
        @test assert_cell(pilot, 1, 1; grapheme=pilot.backend.screen[1, 1].grapheme) == pilot.backend.screen[1, 1]
        @test wait_for_semantic!(pilot, SemanticQuery(id=:alpha, role=ButtonRole); label="Pilot") === pilot
        @test wait_for_no_semantic!(pilot, SemanticQuery(id=:missing); label="Pilot") === pilot
        @test only(wait_query_semantics!(pilot, SemanticQuery(id=:alpha, role=ButtonRole); label="Pilot")).id == "alpha"
        @test wait_query_one_semantic!(pilot, SemanticQuery(id=:alpha, role=ButtonRole); label="Pilot").id == "alpha"
        pilot_tree = pilot_semantic_tree(pilot; label="Pilot")
        direct_tree = toolkit_semantic_tree(pilot.tree; label="Pilot")
        @test semantic_snapshot(pilot_tree) == semantic_snapshot(direct_tree)
        @test pilot_semantic_snapshot(pilot; label="Pilot") == semantic_snapshot(direct_tree)
        @test assert_semantic_snapshot(pilot, semantic_snapshot(direct_tree); label="Pilot") === pilot
        @test assert_semantic_snapshot(pilot, direct_tree; label="Pilot") === pilot
        @test assert_semantic_query(pilot, SemanticQuery(id=:alpha, role=ButtonRole); label="Pilot") === pilot
        @test assert_no_semantic_query(pilot, SemanticQuery(id=:missing); label="Pilot") === pilot
        @test_throws BufferAssertionError assert_no_semantic_query(pilot, SemanticQuery(id=:alpha); label="Pilot")
        message_pilot = ToolkitPilot(
            Element(Button("Emit", :emit); id=:emit, focusable=true);
            height=3,
            width=10,
        )
        @test assert_no_messages(message_pilot) === message_pilot
        focus_element!(message_pilot, :emit)
        @test focused_element(message_pilot) == :emit
        @test assert_focus(message_pilot, :emit) === message_pilot
        @test assert_no_focus(message_pilot, :missing) === message_pilot
        @test wait_for_focus!(message_pilot, :emit) === message_pilot
        @test wait_for_no_focus!(message_pilot, :missing) === message_pilot
        @test_throws BufferAssertionError assert_focus(message_pilot, :missing)
        @test_throws BufferAssertionError assert_no_focus(message_pilot, :emit)
        key!(message_pilot, :enter)
        @test wait_messages!(message_pilot) == [:emit]
        @test wait_for_message!(message_pilot, queued -> queued == [:emit]) === message_pilot
        @test assert_message(message_pilot, queued -> queued == [:emit]) === message_pilot
        @test assert_messages(message_pilot, [:emit]) === message_pilot
        @test messages(message_pilot) == [:emit]
        @test take_messages!(message_pilot) == [:emit]
        @test isempty(messages(message_pilot))
        @test assert_no_messages(message_pilot) === message_pilot
        @test wait_for_no_messages!(message_pilot) === message_pilot
        @test_throws BufferAssertionError assert_message(message_pilot, _ -> false)
        @test_throws ArgumentError assert_message(message_pilot, _ -> :not_a_bool)
        @test_throws BufferAssertionError assert_messages(message_pilot, [:emit])
        @test_throws ArgumentError wait_for_message!(message_pilot, _ -> :not_a_bool; timeout_seconds=0.0)
        @test occursin("alpha:ButtonRole", semantic_snapshot(pilot_tree))
        @test length(query_semantics(pilot, SemanticQuery(role=ButtonRole); label="Pilot")) == 1
        @test query_one_semantic(pilot, SemanticQuery(id=:alpha, role=ButtonRole); label="Pilot").id == "alpha"

        advance_time!(pilot, 0.25)
        @test virtual_time_ns(pilot.clock) == 250_000_000
        @test assert_running(pilot) === pilot
        @test wait_for_running!(pilot) === pilot
        status = pilot_status(pilot)
        @test status isa PilotStatus
        @test status.virtual_time_ns == virtual_time_ns(pilot)
        @test status.pending_scheduled == pending_scheduled(pilot)
        @test !status.exited
        @test status == PilotStatus(virtual_time_ns(pilot), pending_scheduled(pilot), false, nothing)
        @test hash(status) == hash(PilotStatus(virtual_time_ns(pilot), pending_scheduled(pilot), false, nothing))
        @test occursin("virtual_time_ns=", pilot_status_text(status))
        @test startswith(pilot_status_tsv(pilot), "virtual_time_ns\tpending_scheduled\texited\tresult")
        @test startswith(pilot_status_markdown(status), "| virtual_time_ns | pending_scheduled | exited | result |")
        evidence = pilot_evidence_bundle(pilot)
        @test evidence isa PilotEvidenceBundle
        @test evidence == PilotEvidenceBundle(status, snapshot_bundle(pilot))
        @test hash(evidence) == hash(PilotEvidenceBundle(status, snapshot_bundle(pilot)))
        @test occursin("source_kind=", pilot_evidence_text(evidence))
        @test startswith(pilot_evidence_tsv(pilot), "virtual_time_ns\tpending_scheduled\texited\tresult\tsource_kind")
        @test startswith(pilot_evidence_markdown(evidence), "| virtual_time_ns | pending_scheduled | exited | result | source_kind |")
        evidence_summary = pilot_evidence_summary(evidence)
        @test evidence_summary isa PilotEvidenceSummary
        @test evidence_summary == PilotEvidenceSummary(
            status.virtual_time_ns,
            status.pending_scheduled,
            status.exited,
            status.result,
            evidence.snapshots.source_kind,
            snapshot_bundle_summary(evidence.snapshots).artifact_count,
            snapshot_bundle_summary(evidence.snapshots).total_bytes,
        )
        @test hash(evidence_summary) == hash(pilot_evidence_summary(evidence))
        @test occursin("snapshot_artifact_count=", pilot_evidence_summary_text(evidence_summary))
        @test startswith(pilot_evidence_summary_tsv(pilot), "virtual_time_ns\tpending_scheduled\texited\tresult\tsource_kind\tsnapshot_artifact_count\tsnapshot_total_bytes")
        @test startswith(pilot_evidence_summary_markdown(evidence), "| virtual_time_ns | pending_scheduled | exited | result | source_kind | snapshot_artifact_count | snapshot_total_bytes |")
        manifest_records = pilot_evidence_manifest_records(evidence)
        @test all(record -> record isa SnapshotArtifactRecord, manifest_records)
        @test occursin("status.txt\tbytes=", pilot_evidence_manifest(evidence))
        @test startswith(pilot_evidence_manifest_tsv(evidence), "name\tbytes\tsha256\n")
        @test !startswith(pilot_evidence_manifest_tsv(evidence; header=false), "name\tbytes\tsha256")
        @test occursin("| `status.txt` |", pilot_evidence_manifest_markdown(evidence))
        evidence_reports = pilot_evidence_report_artifacts(evidence)
        @test evidence_reports["manifest.tsv"] == pilot_evidence_manifest_tsv(evidence)
        @test evidence_reports["manifest.md"] == pilot_evidence_manifest_markdown(evidence)
        @test evidence_reports["summary.txt"] == pilot_evidence_summary_text(evidence_summary)
        @test evidence_reports["summary.tsv"] == pilot_evidence_summary_tsv(evidence_summary)
        @test evidence_reports["summary.md"] == pilot_evidence_summary_markdown(evidence_summary)
        mktempdir() do directory
            paths = write_pilot_evidence_bundle(directory, evidence)
            @test isfile(paths["status.txt"])
            @test isfile(paths["evidence.tsv"])
            @test isfile(paths["manifest.txt"])
            @test isfile(paths[joinpath("snapshots", "plain.txt")])
            @test verify_pilot_evidence_bundle(directory)
            @test assert_pilot_evidence_bundle_artifacts(directory, evidence) == directory
            @test read_pilot_evidence_manifest_records(directory) == manifest_records
            @test pilot_evidence_artifact_manifest_tsv(directory) == pilot_evidence_manifest_tsv(evidence)
            @test pilot_evidence_artifact_manifest_markdown(directory) == pilot_evidence_manifest_markdown(evidence)
            @test pilot_evidence_artifact_summary(directory) == evidence_summary
            @test pilot_evidence_report_artifacts(directory) == evidence_reports
            write(joinpath(directory, "unexpected.txt"), "extra")
            @test_throws BufferAssertionError verify_pilot_evidence_bundle(directory)
            @test verify_pilot_evidence_bundle(directory; allow_extra=true)
            @test assert_pilot_evidence_bundle_artifacts(directory, evidence; allow_extra=true) == directory
            @test pilot_evidence_artifact_summary(directory; allow_extra=true) == evidence_summary
            @test_throws ArgumentError write_pilot_evidence_bundle(directory, evidence)
            replaced = write_pilot_evidence_bundle(directory, pilot; overwrite=true)
            @test isfile(replaced["status.md"])
            @test assert_pilot_evidence_bundle_artifacts(directory, pilot; allow_extra=true) == directory
        end
        mktempdir() do directory
            report_paths = write_pilot_evidence_reports(directory, evidence)
            @test Set(keys(report_paths)) == Set(keys(evidence_reports))
            @test read(report_paths["manifest.md"], String) == evidence_reports["manifest.md"]
            @test read(report_paths["summary.tsv"], String) == evidence_reports["summary.tsv"]
            @test verify_pilot_evidence_report_artifacts(directory)
            @test assert_pilot_evidence_report_artifacts(directory, evidence) == directory
            @test read_pilot_evidence_report_manifest_records(directory) == pilot_evidence_report_manifest_records(evidence)
            @test pilot_evidence_report_artifact_manifest_tsv(directory) == pilot_evidence_report_manifest_tsv(evidence)
            @test pilot_evidence_report_artifact_manifest_markdown(directory) == pilot_evidence_report_manifest_markdown(evidence)
            @test pilot_evidence_report_artifact_summary(directory) == pilot_evidence_report_summary(evidence)
            @test pilot_evidence_report_artifact_summary_text(directory) == pilot_evidence_report_summary_text(evidence)
            @test pilot_evidence_report_artifact_summary_tsv(directory) == pilot_evidence_report_summary_tsv(evidence)
            @test pilot_evidence_report_artifact_summary_markdown(directory) == pilot_evidence_report_summary_markdown(evidence)
            @test_throws ArgumentError write_pilot_evidence_reports(directory, evidence)
            write(joinpath(directory, "unexpected.txt"), "extra")
            @test_throws BufferAssertionError verify_pilot_evidence_report_artifacts(directory)
            @test verify_pilot_evidence_report_artifacts(directory; allow_extra=true)
            @test assert_pilot_evidence_report_artifacts(directory, evidence; allow_extra=true) == directory
            replaced_reports = write_pilot_evidence_reports(directory, pilot; overwrite=true)
            @test read(replaced_reports["summary.txt"], String) == pilot_evidence_summary_text(pilot)
            @test assert_pilot_evidence_report_artifacts(directory, pilot; allow_extra=true) == directory
        end
        mktempdir() do evidence_directory
            write_pilot_evidence_bundle(evidence_directory, evidence)
            mktempdir() do report_directory
                report_paths = write_pilot_evidence_reports(report_directory, evidence_directory)
                @test read(report_paths["manifest.tsv"], String) == evidence_reports["manifest.tsv"]
                @test read(report_paths["summary.md"], String) == evidence_reports["summary.md"]
                @test assert_pilot_evidence_report_artifacts(report_directory, evidence_directory) == report_directory
                @test_throws ArgumentError write_pilot_evidence_reports(report_directory, evidence_directory)
            end
        end
        mktempdir() do directory
            package_paths = write_pilot_evidence_package(directory, evidence)
            @test isfile(package_paths[joinpath("evidence", "status.txt")])
            @test isfile(package_paths[joinpath("reports", "summary.tsv")])
            @test verify_pilot_evidence_package(directory)
            @test assert_pilot_evidence_package_artifacts(directory, evidence) == directory
            @test assert_pilot_evidence_report_artifacts(joinpath(directory, "reports"), joinpath(directory, "evidence")) == joinpath(directory, "reports")
            @test read_pilot_evidence_package_manifest_records(directory) == pilot_evidence_package_manifest_records(evidence)
            @test pilot_evidence_package_artifact_manifest_tsv(directory) == pilot_evidence_package_manifest_tsv(evidence)
            @test pilot_evidence_package_artifact_manifest_markdown(directory) == pilot_evidence_package_manifest_markdown(evidence)
            @test pilot_evidence_package_artifact_summary(directory) == pilot_evidence_package_summary(evidence)
            @test pilot_evidence_package_artifact_summary_text(directory) == pilot_evidence_package_summary_text(evidence)
            @test pilot_evidence_package_artifact_summary_tsv(directory) == pilot_evidence_package_summary_tsv(evidence)
            @test pilot_evidence_package_artifact_summary_markdown(directory) == pilot_evidence_package_summary_markdown(evidence)
            package_reports = pilot_evidence_package_report_artifacts(evidence)
            @test package_reports["package-manifest.tsv"] == pilot_evidence_package_manifest_tsv(evidence)
            @test package_reports["package-summary.md"] == pilot_evidence_package_summary_markdown(evidence)
            @test pilot_evidence_package_report_manifest_records(evidence) isa Vector{SnapshotArtifactRecord}
            @test startswith(pilot_evidence_package_report_manifest_tsv(evidence), "name\tbytes\tsha256\n")
            @test occursin("| `package-summary.txt` |", pilot_evidence_package_report_manifest_markdown(evidence))
            @test occursin("source_kind=pilot_evidence_package_reports", pilot_evidence_package_report_summary_text(evidence))
            @test startswith(pilot_evidence_package_report_summary_tsv(evidence), "source_kind\tartifact_count\ttotal_bytes\n")
            @test startswith(pilot_evidence_package_report_summary_markdown(evidence), "| `source_kind` | `artifact_count` | `total_bytes` |")
            @test pilot_evidence_package_report_artifacts(directory) == package_reports
            mktempdir() do report_directory
                report_paths = write_pilot_evidence_package_reports(report_directory, directory)
                @test read(report_paths["package-summary.txt"], String) == package_reports["package-summary.txt"]
                @test verify_pilot_evidence_package_report_artifacts(report_directory)
                @test assert_pilot_evidence_package_report_artifacts(report_directory, directory) == report_directory
                @test read_pilot_evidence_package_report_manifest_records(report_directory) isa Vector{SnapshotArtifactRecord}
                @test startswith(pilot_evidence_package_report_artifact_manifest_tsv(report_directory), "name\tbytes\tsha256\n")
                @test occursin("| `package-summary.txt` |", pilot_evidence_package_report_artifact_manifest_markdown(report_directory))
                @test occursin("source_kind=pilot_evidence_package_reports", pilot_evidence_package_report_artifact_summary_text(report_directory))
                @test startswith(pilot_evidence_package_report_artifact_summary_tsv(report_directory), "source_kind\tartifact_count\ttotal_bytes\n")
                @test startswith(pilot_evidence_package_report_artifact_summary_markdown(report_directory), "| `source_kind` | `artifact_count` | `total_bytes` |")
                @test_throws ArgumentError write_pilot_evidence_package_reports(report_directory, directory)
                write(joinpath(report_directory, "unexpected.txt"), "extra")
                @test_throws BufferAssertionError verify_pilot_evidence_package_report_artifacts(report_directory)
                @test verify_pilot_evidence_package_report_artifacts(report_directory; allow_extra=true)
                @test assert_pilot_evidence_package_report_artifacts(report_directory, directory; allow_extra=true) == report_directory
            end
            @test_throws ArgumentError write_pilot_evidence_package(directory, evidence)
            write(joinpath(directory, "unexpected.txt"), "extra")
            @test_throws BufferAssertionError verify_pilot_evidence_package(directory)
            @test verify_pilot_evidence_package(directory; allow_extra=true)
            @test assert_pilot_evidence_package_artifacts(directory, evidence; allow_extra=true) == directory
            replaced_package_paths = write_pilot_evidence_package(directory, pilot; overwrite=true)
            @test isfile(replaced_package_paths[joinpath("reports", "summary.txt")])
            @test assert_pilot_evidence_package_artifacts(directory, pilot; allow_extra=true) == directory
        end
        mktempdir() do directory
            write_pilot_evidence_bundle(directory, evidence)
            write(joinpath(directory, "status.txt"), "corrupt")
            @test_throws BufferAssertionError verify_pilot_evidence_bundle(directory)
        end
        @test request_exit!(pilot, :accepted)
        @test pilot_exited(pilot)
        @test exit_result(pilot) == :accepted
        @test assert_exited(pilot; result=:accepted) === pilot
        @test wait_for_exit!(pilot; result=:accepted) === pilot
        mktempdir() do directory
            exited_evidence = pilot_evidence_bundle(pilot)
            write_pilot_evidence_package(directory, exited_evidence)
            @test pilot_evidence_artifact_summary(joinpath(directory, "evidence")) == pilot_evidence_summary(exited_evidence)
            @test hash(pilot_evidence_artifact_summary(joinpath(directory, "evidence"))) == hash(pilot_evidence_summary(exited_evidence))
            @test pilot_evidence_package_artifact_summary(directory) == pilot_evidence_package_summary(exited_evidence)
            @test assert_pilot_evidence_package_artifacts(directory, exited_evidence) == directory
        end
        @test_throws BufferAssertionError assert_running(pilot)
        @test_throws BufferAssertionError assert_exited(pilot; result=:rejected)
        @test pilot.exited
        @test pilot.result == :accepted
    end

    @testset "deterministic managed runtime pilot" begin
        pilot = RuntimePilot(TestingPilotApp(); height=1, width=12)
        @test pilot_model(pilot).count == 0
        @test assert_model(pilot, model -> model.count == 0) === pilot
        @test assert_no_processed_messages(pilot) === pilot
        @test plain_snapshot(pilot) == "count=0"

        update_result = send!(pilot, CustomEvent(:increment))
        @test update_result.accepted
        @test update_result.processed_messages == 1
        @test assert_processed_messages(pilot, [CustomEvent(:increment)]) === pilot
        @test update_result.redrawn
        @test pilot_model(pilot).count == 1
        @test plain_snapshot(pilot) == "count=1"

        send!(pilot, CustomEvent(:delay))
        @test last_command(pilot) isa DelayCommand
        @test assert_command(pilot, DelayCommand) === pilot
        @test wait_for_command!(pilot, DelayCommand) === pilot
        @test pending_scheduled(pilot) == 1
        @test assert_pending_scheduled(pilot, 1) === pilot
        @test wait_for_pending_scheduled!(pilot, 1) === pilot
        @test assert_no_runtime_queue(pilot) === pilot
        @test assert_model(pilot, model -> model.count == 1) === pilot
        advance_time!(pilot, 0.49)
        @test virtual_time_ns(pilot) == 490_000_000
        @test assert_virtual_time(pilot, 490_000_000) === pilot
        @test wait_for_virtual_time!(pilot, 490_000_000) === pilot
        @test pilot_model(pilot).count == 1
        delayed = advance_time!(pilot, 0.01)
        @test delayed.processed_messages == 1
        @test assert_no_runtime_queue(pilot) === pilot
        @test assert_model(pilot, model -> model.count == 2) === pilot
        @test pending_scheduled(pilot) == 0
        @test assert_pending_scheduled(pilot, 0) === pilot
        send!(pilot, CustomEvent(:delay))
        @test wait_for_model!(pilot, model -> model.count == 3; timeout_seconds=0.5, step_seconds=0.25) === pilot
        @test wait_for_text!(pilot, "count=3") === pilot
        @test_throws BufferAssertionError assert_command(pilot, DelayCommand)
        @test_throws ArgumentError assert_command(pilot, _ -> :not_a_bool)
        @test_throws BufferAssertionError assert_model(pilot, model -> model.count == -1)
        @test_throws ArgumentError assert_model(pilot, _ -> :not_a_bool)
        @test_throws ArgumentError wait_for_model!(pilot, _ -> :not_a_bool; timeout_seconds=0.0)

        task_result = send!(pilot, CustomEvent(:task))
        @test task_result.processed_messages == 2
        @test pilot_model(pilot).count == 7
        batch_result = send!(pilot, CustomEvent(:batch))
        @test batch_result.processed_messages == 3
        @test assert_no_runtime_queue(pilot) === pilot
        @test runtime_queue(pilot) == Any[]
        @test processed_messages(pilot)[end-2:end] == Any[CustomEvent(:batch), :increment, :increment]
        @test wait_for_processed_messages!(pilot, history -> length(history) >= 8) === pilot
        @test_throws BufferAssertionError assert_processed_messages(pilot, Any[])
        @test_throws ArgumentError wait_for_processed_messages!(pilot, _ -> :not_a_bool; timeout_seconds=0.0)
        @test_throws BufferAssertionError assert_runtime_queue(pilot, [:increment])
        @test_throws ArgumentError wait_for_runtime_queue!(pilot, _ -> :not_a_bool; timeout_seconds=0.0)
        @test pilot_model(pilot).count == 9
        key!(pilot, :up)
        @test assert_model(pilot, model -> model.count == 10) === pilot

        resize_terminal!(pilot, 2, 16)
        @test size(pilot.backend.screen) == (2, 16)
        exit_result = send!(pilot, CustomEvent(:exit))
        @test exit_result.exited
        @test exit_result.result == 10
        @test pilot_exited(pilot)
        @test Wicked.exit_result(pilot) == 10
        @test assert_exited(pilot; result=10) === pilot
        @test wait_for_exit!(pilot; result=10) === pilot
        rejected = send!(pilot, :increment)
        @test !rejected.accepted
        @test pilot_model(pilot).count == 10
    end

    @testset "immediate widget pilot" begin
        stateless = WidgetPilot(Label("hello"); height=1, width=8)
        @test !stateless.stateful
        @test stateless.state === nothing
        @test plain_snapshot(stateless) == "hello"
        ignored = key!(stateless, :enter)
        @test !ignored.handled
        @test !ignored.redrawn

        pilot = WidgetPilot(Button("Go"); height=3, width=8)
        @test pilot.stateful
        @test pilot.state isa ButtonState
        @test occursin("widget:ButtonRole", pilot_semantic_snapshot(pilot))
        @test query_one_semantic(pilot, SemanticQuery(role=ButtonRole)).id == "widget"
        @test assert_semantic_query(pilot, SemanticQuery(role=ButtonRole)) === pilot
        @test assert_no_semantic_query(pilot, SemanticQuery(id="missing")) === pilot
        @test assert_semantic_snapshot(pilot, pilot_semantic_snapshot(pilot)) === pilot
        @test wait_for_semantic!(pilot, SemanticQuery(role=ButtonRole)) === pilot
        @test wait_for_no_semantic!(pilot, SemanticQuery(id="missing")) === pilot
        @test only(wait_query_semantics!(pilot, SemanticQuery(role=ButtonRole))).id == "widget"
        @test wait_query_one_semantic!(pilot, SemanticQuery(role=ButtonRole)).id == "widget"
        @test_throws BufferAssertionError wait_for_semantic!(pilot, SemanticQuery(id="missing"); timeout_seconds=0.01, step_seconds=0.01)
        @test assert_structured_snapshot(pilot, structured_snapshot(pilot)) === pilot
        @test assert_svg_snapshot(pilot, svg_snapshot(pilot)) === pilot
        bundle = snapshot_bundle(pilot)
        @test bundle isa SnapshotBundle
        @test bundle.source_kind == :widget_pilot
        @test bundle.plain == plain_snapshot(pilot)
        @test bundle.ansi == ansi_snapshot(pilot)
        @test bundle.structured == structured_snapshot(pilot)
        @test bundle.svg == svg_snapshot(pilot)
        @test assert_snapshot_bundle(pilot, bundle) isa SnapshotBundle
        @test wait_for_snapshot_bundle!(pilot, bundle) === pilot
        @test wait_for_snapshot_bundle_where!(pilot, candidate -> occursin("Go", candidate.plain)) === pilot
        @test SnapshotBundle(
            bundle.source_kind,
            String(bundle.plain),
            String(bundle.ansi),
            copy(bundle.structured),
            String(bundle.svg),
        ) == bundle
        artifacts = snapshot_bundle_artifacts(bundle)
        @test artifacts["plain.txt"] == bundle.plain
        @test artifacts["ansi.txt"] == bundle.ansi
        @test artifacts["structured.txt"] == repr(bundle.structured)
        @test artifacts["frame.svg"] == bundle.svg
        @test occursin("source_kind=widget_pilot", artifacts["manifest.txt"])
        @test snapshot_bundle_payloads(bundle)["plain.txt"] == bundle.plain
        @test snapshot_bundle_manifest(bundle) == artifacts["manifest.txt"]
        records = snapshot_bundle_manifest_records(bundle)
        @test all(record -> record isa SnapshotArtifactRecord, records)
        @test SnapshotArtifactRecord(String(first(records).name), first(records).bytes, String(first(records).sha256)) == first(records)
        @test sort(record.name for record in records) == sort(collect(keys(snapshot_bundle_payloads(bundle))))
        @test all(record -> record.bytes > 0, records)
        @test all(record -> length(record.sha256) == 64, records)
        summary = snapshot_bundle_summary(bundle)
        @test summary isa SnapshotArtifactSummary
        @test summary.source_kind == :widget_pilot
        @test summary.artifact_count == length(records)
        @test summary.total_bytes == sum(record -> record.bytes, records)
        @test SnapshotArtifactSummary(summary.source_kind, summary.artifact_count, summary.total_bytes) == summary
        @test snapshot_artifact_summary_text(summary) == "source_kind=widget_pilot artifact_count=$(summary.artifact_count) total_bytes=$(summary.total_bytes)"
        @test startswith(snapshot_artifact_summary_tsv(summary), "source_kind\tartifact_count\ttotal_bytes\n")
        @test !startswith(snapshot_artifact_summary_tsv(summary; header=false), "source_kind\tartifact_count")
        @test startswith(snapshot_artifact_summary_markdown(summary), "| `source_kind` | `artifact_count` | `total_bytes` |")
        reports = snapshot_bundle_report_artifacts(bundle)
        @test reports["manifest.tsv"] == snapshot_bundle_manifest_tsv(bundle)
        @test reports["manifest.md"] == snapshot_bundle_manifest_markdown(bundle)
        @test reports["summary.txt"] == snapshot_artifact_summary_text(summary)
        @test reports["summary.tsv"] == snapshot_artifact_summary_tsv(summary)
        @test reports["summary.md"] == snapshot_artifact_summary_markdown(summary)
        @test startswith(snapshot_bundle_manifest_tsv(bundle), "name\tbytes\tsha256\n")
        @test !startswith(snapshot_bundle_manifest_tsv(bundle; header=false), "name\tbytes\tsha256")
        @test startswith(snapshot_bundle_manifest_markdown(bundle), "| `name` | `bytes` | `sha256` |")
        @test occursin("| `plain.txt` |", snapshot_bundle_manifest_markdown(bundle))
        @test occursin("plain.txt\tbytes=", artifacts["manifest.txt"])
        @test occursin("sha256=", artifacts["manifest.txt"])
        mktempdir() do directory
            paths = write_snapshot_bundle(directory, bundle)
            @test Set(keys(paths)) == Set(keys(artifacts))
            @test read(paths["plain.txt"], String) == bundle.plain
            @test verify_snapshot_bundle_artifacts(directory)
            @test assert_snapshot_bundle_artifacts(directory, bundle) == directory
            @test read_snapshot_bundle_manifest_records(directory) == records
            @test snapshot_bundle_artifact_summary(directory) == summary
            @test snapshot_bundle_artifact_manifest_tsv(directory) == snapshot_bundle_manifest_tsv(bundle)
            @test snapshot_bundle_artifact_manifest_markdown(directory) == snapshot_bundle_manifest_markdown(bundle)
            write(joinpath(directory, "unexpected.txt"), "extra")
            @test_throws BufferAssertionError verify_snapshot_bundle_artifacts(directory)
            @test verify_snapshot_bundle_artifacts(directory; allow_extra=true)
            @test assert_snapshot_bundle_artifacts(directory, bundle; allow_extra=true) == directory
            @test_throws ArgumentError write_snapshot_bundle(directory, bundle)
            replaced = write_snapshot_bundle(directory, pilot; overwrite=true)
            @test read(replaced["manifest.txt"], String) == artifacts["manifest.txt"]
        end
        mktempdir() do directory
            report_paths = write_snapshot_bundle_reports(directory, bundle)
            @test Set(keys(report_paths)) == Set(keys(reports))
            @test read(report_paths["summary.md"], String) == reports["summary.md"]
            @test_throws ArgumentError write_snapshot_bundle_reports(directory, bundle)
            replaced_reports = write_snapshot_bundle_reports(directory, pilot; overwrite=true)
            @test read(replaced_reports["manifest.tsv"], String) == reports["manifest.tsv"]
        end
        changed_bundle = SnapshotBundle(bundle.source_kind, "different", bundle.ansi, bundle.structured, bundle.svg)
        try
            assert_snapshot_bundle(changed_bundle, bundle)
            @test false
        catch error
            @test error isa BufferAssertionError
            @test occursin("field :plain", sprint(showerror, error))
        end
        try
            assert_plain_snapshot(pilot, "Nope")
            @test false
        catch error
            @test error isa BufferAssertionError
            @test occursin("first difference at line", sprint(showerror, error))
        end
        try
            assert_structured_snapshot(pilot, [])
            @test false
        catch error
            @test error isa BufferAssertionError
            @test occursin("first difference at index", sprint(showerror, error))
        end
        pressed = key!(pilot, :enter)
        @test pressed.handled
        @test pressed.redrawn
        @test pilot.state.pressed
        released = key!(pilot, :enter; kind=KeyRelease)
        @test released.handled
        @test !pilot.state.pressed
        pressed_and_released = press!(pilot, :enter)
        @test pressed_and_released.handled
        @test pressed_and_released.redrawn
        @test !pilot.state.pressed

        clicked = click!(pilot, 2, 4)
        @test clicked.handled
        @test !pilot.state.pressed
        @test double_click!(pilot, 2, 4).handled
        @test !right_click!(pilot, 2, 4).handled
        @test !drag!(pilot, 2, 2, 2, 5).handled
        @test !scroll_up!(pilot, 2, 4).handled
        @test !scroll_down!(pilot, 2, 4).handled
        ticked = advance_time!(pilot, 0.25)
        @test !ticked.handled
        @test virtual_time_ns(pilot.clock) == 250_000_000
        @test wait_until!(pilot, candidate -> occursin("Go", plain_snapshot(candidate))) === pilot
        @test wait_for_text!(pilot, "Go") === pilot
        @test wait_for_plain_snapshot!(pilot, plain_snapshot(pilot)) === pilot
        @test wait_for_ansi_snapshot!(pilot, ansi_snapshot(pilot)) === pilot
        @test wait_for_structured_snapshot!(pilot, structured_snapshot(pilot)) === pilot
        @test wait_for_svg_snapshot!(pilot, svg_snapshot(pilot)) === pilot
        @test wait_for_cell!(pilot, 1, 1; grapheme=pilot.backend.screen[1, 1].grapheme) === pilot
        @test wait_for_buffer!(pilot, buffer -> size(buffer) == size(pilot.backend.screen)) === pilot
        @test_throws BufferAssertionError wait_for_text!(pilot, "missing"; timeout_seconds=0.01, step_seconds=0.01)
        try
            wait_for_text!(pilot, "missing"; timeout_seconds=0.01, step_seconds=0.01)
            @test false
        catch error
            @test error isa BufferAssertionError
            message = sprint(showerror, error)
            @test occursin("pilot=WidgetPilot", message)
            @test occursin("virtual_time_ns=", message)
        end

        resize_terminal!(pilot, 3, 10)
        @test size(pilot.backend.screen) == (3, 10)
        @test occursin("Go", plain_snapshot(pilot))
    end
end
