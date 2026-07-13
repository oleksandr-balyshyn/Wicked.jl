@testset "Required acceptance widgets" begin
    @test Border(title="Box") isa Border
    @test Rule().direction == HorizontalRule
    rich = RichText("Ready")
    @test rich isa RichText
    @test render!(Buffer(1, 12), rich, Rect(1, 1, 1, 12)) isa Buffer

    @testset "dialog rendering and interaction" begin
        buttons = DialogButton{Symbol}[
            DialogButton("Accept", :accepted),
            DialogButton("Cancel", :cancelled; role=CancelDialogButton),
        ]
        state = DialogState(buttons; open=true)
        widget = Dialog("Apply the configuration?"; title="Confirm")
        pilot = WidgetPilot(widget; state=state, height=7, width=36)
        snapshot = plain_snapshot(pilot)
        @test occursin("Confirm", snapshot)
        @test occursin("Apply the configuration?", snapshot)
        @test occursin("Accept", snapshot)
        @test occursin("Cancel", snapshot)

        @test send!(pilot, KeyEvent(Key(:right))).handled
        @test state.focused == 2
        @test send!(pilot, KeyEvent(Key(:enter))).handled
        @test state.result == :cancelled
        @test !state.open

        open_dialog!(state)
        draw!(pilot)
        content = inner(widget.block, pilot.backend.screen.area)
        button_area = Rect(content.row + content.height - 1, content.column, 1, content.width)
        regions = Wicked._dialog_button_regions(state, button_area)
        first_button = regions[1][2]
        event = MouseEvent(
            Position(first_button.row, first_button.column),
            LeftMouseButton,
            MouseRelease,
        )
        @test send!(pilot, event).handled
        @test state.result == :accepted
        @test !state.open

        closed = Buffer(3, 12)
        render!(closed, widget, closed.area, state)
        @test plain_snapshot(closed) == "\n\n"
    end

    @testset "error view and clipping" begin
        widget = ErrorView(
            ErrorException("database unavailable");
            title="Recovered error",
            details=["Retry is available", "No state was lost"],
        )
        buffer = Buffer(6, 32)
        render!(buffer, widget, buffer.area)
        snapshot = plain_snapshot(buffer)
        @test occursin("Recovered error", snapshot)
        @test occursin("database unavailable", snapshot)
        @test occursin("Retry is available", snapshot)

        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, nothing)
        @test descriptor.role == Wicked.Accessibility.AlertRole
        @test descriptor.label == "Recovered error"
        @test descriptor.description == "database unavailable"
        @test descriptor.metadata[:detail_count] == 2
        @test descriptor.metadata[:details] == ["Retry is available", "No state was lost"]
        @test Wicked.Toolkit.state_for(widget) === nothing
        dispatcher = SemanticDispatcher()
        register_error_view_semantic_handlers!(dispatcher, :error, widget)
        pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(widget; id=:error, key=:error))); dispatcher)
        error_result = perform_semantic_action!(pilot, "error", SelectSemanticAction)
        @test error_result.handled
        @test error_result.value[:message] == "database unavailable"

        zero = Buffer(0, 0)
        @test render!(zero, widget, zero.area) === zero
    end

    @testset "validation feedback semantics" begin
        issues = ValidationIssue[
            ValidationIssue(:required, "Email is required"),
            ValidationIssue(:format, "Email format is incomplete"; severity=:warning),
        ]
        message = ValidationMessage(issues)
        message_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(message, nothing)
        @test message_descriptor.role == Wicked.Accessibility.AlertRole
        @test message_descriptor.label == "Validation issues"
        @test occursin("Email is required", message_descriptor.description)
        @test message_descriptor.metadata[:codes] == [:required, :format]
        @test message_descriptor.metadata[:severities] == [:error, :warning]
        @test Wicked.Toolkit.state_for(message) === nothing
        message_dispatcher = SemanticDispatcher()
        register_validation_message_semantic_handlers!(message_dispatcher, :validation_message, message)
        message_pilot = SemanticPilot(
            SemanticTree(SemanticNode("validation_message", message_descriptor.role; label=message_descriptor.label)),
            dispatcher=message_dispatcher,
        )
        message_result = perform_semantic_action!(message_pilot, "validation_message", SelectSemanticAction)
        @test message_result.handled
        @test message_result.value[:issue_count] == 2

        form = Form([FormField(:email; label="Email", initial="")])
        state = FormState(form)
        field_state(state, :email).issues = copy(issues)
        summary = ValidationSummary(form, state)
        summary_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(summary, nothing)
        @test summary_descriptor.role == Wicked.Accessibility.AlertRole
        @test summary_descriptor.label == "Form validation"
        @test summary_descriptor.metadata[:issue_count] == 2
        @test summary_descriptor.metadata[:field_ids] == [:email, :email]
        @test occursin("Email: Email is required", summary_descriptor.description)
        @test Wicked.Toolkit.state_for(summary) === nothing
        summary_dispatcher = SemanticDispatcher()
        register_validation_summary_semantic_handlers!(summary_dispatcher, :validation_summary, summary)
        summary_pilot = SemanticPilot(
            SemanticTree(SemanticNode("validation_summary", summary_descriptor.role; label=summary_descriptor.label)),
            dispatcher=summary_dispatcher,
        )
        summary_result = perform_semantic_action!(summary_pilot, "validation_summary", SelectSemanticAction)
        @test summary_result.handled
        @test summary_result.value[:field_ids] == [:email, :email]

        informational = ValidationMessage([ValidationIssue(:hint, "Optional"; severity=:info)])
        informational_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(informational, nothing)
        @test informational_descriptor.role == Wicked.Accessibility.StatusRole
    end

    @testset "feedback widget semantic handlers" begin
        badge = Badge("READY")
        status = Status("Connected"; severity=:success)
        alert = Alert("Disk usage is high"; title="Warning", severity=:warning)
        toast = Toast("Deploy finished"; title="Deploy", severity=:success, timeout=nothing)
        dispatcher = SemanticDispatcher()
        register_badge_semantic_handlers!(dispatcher, :badge, badge)
        register_status_semantic_handlers!(dispatcher, :status, status)
        register_alert_semantic_handlers!(dispatcher, :alert, alert)
        register_toast_semantic_handlers!(dispatcher, :toast, toast)
        tree = SemanticTree(SemanticNode(
            "feedback",
            GroupRole;
            children=[
                SemanticNode("badge", StatusRole; label="READY"),
                SemanticNode("status", StatusRole; label="Status"),
                SemanticNode("alert", AlertRole; label="Warning"),
                SemanticNode("toast", StatusRole; label="Deploy"),
            ],
        ))
        pilot = SemanticPilot(tree; dispatcher)
        @test perform_semantic_action!(pilot, "badge", SelectSemanticAction).value[:text] == "READY"
        @test perform_semantic_action!(pilot, "status", SelectSemanticAction).value[:severity] == :success
        @test perform_semantic_action!(pilot, "alert", DismissSemanticAction).value[:severity] == :warning
        @test perform_semantic_action!(pilot, "toast", DismissSemanticAction).value[:message] == "Deploy finished"
    end

    @testset "managed notification toolkit semantics" begin
        manager = NotificationManager()
        notify!(manager, "Deployment completed"; id=:deploy, title="Deploy", severity=:success)
        widget = ManagedNotificationView(manager)
        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, nothing)
        children = Wicked.SemanticToolkit.widget_semantic_children(widget, nothing, :notifications)

        @test descriptor.role == Wicked.Accessibility.LogRole
        @test descriptor.metadata[:notification_count] == 1
        @test descriptor.metadata[:generation] == notification_generation(manager)
        @test length(children) == 1
        @test Wicked.Toolkit.state_for(widget) === nothing

        buffer = Buffer(3, 40)
        @test render!(buffer, widget, buffer.area) === buffer
        @test occursin("Deployment completed", plain_snapshot(buffer))
    end

    @testset "immediate notification toolkit semantics" begin
        center = NotificationCenter(3)
        push_notification!(center, Notification("Saved"; id=:saved, title="Build", severity=:success))
        push_notification!(center, Notification("Disk is full"; id=:disk, title="Storage", severity=:error))
        widget = NotificationView(center)
        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, nothing)
        children = Wicked.SemanticToolkit.widget_semantic_children(widget, nothing, :notifications)

        @test descriptor.role == Wicked.Accessibility.LogRole
        @test descriptor.metadata[:notification_count] == 2
        @test descriptor.metadata[:maximum] == 3
        @test length(children) == 2
        @test children[1].role == Wicked.Accessibility.StatusRole
        @test children[2].role == Wicked.Accessibility.AlertRole
        @test children[2].metadata[:notification_id] == :disk
        @test children[2].description == "Disk is full"
        @test Wicked.Toolkit.state_for(widget) === nothing

        buffer = Buffer(2, 30)
        @test render!(buffer, widget, buffer.area) === buffer
        snapshot = plain_snapshot(buffer)
        @test occursin("Build: Saved", snapshot)
        @test occursin("Storage: Disk is full", snapshot)
    end

    @testset "help view toolkit semantics" begin
        widget = HelpView([KeyHint("q", "Quit"), KeyHint("?", "Show help")])
        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(widget, nothing)
        children = Wicked.SemanticToolkit.widget_semantic_children(widget, nothing, :help)

        @test descriptor.role == Wicked.Accessibility.GroupRole
        @test descriptor.metadata[:hint_count] == 2
        @test length(children) == 2
        @test children[1].role == Wicked.Accessibility.ListItemRole
        @test children[1].metadata[:key] == "q"
        @test children[2].description == "Show help"
        @test Wicked.Toolkit.state_for(widget) === nothing
        dispatcher = SemanticDispatcher()
        register_help_view_semantic_handlers!(dispatcher, :help, widget)
        pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(widget; id=:help, key=:help))); dispatcher)
        root_result = perform_semantic_action!(pilot, "help", FocusSemanticAction)
        @test root_result.handled
        @test root_result.value[:hint_count] == 2
        hint_result = perform_semantic_action!(pilot, "help/hint/1", SelectSemanticAction)
        @test hint_result.handled
        @test hint_result.value[:key] == "q"
    end

    @testset "application chrome toolkit semantics" begin
        header = Header("Wicked"; subtitle="Build monitor")
        header_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(header, nothing)
        @test header_descriptor.role == Wicked.Accessibility.HeadingRole
        @test header_descriptor.label == "Wicked"
        @test header_descriptor.description == "Build monitor"

        footer = Footer([:q => "Quit", :r => "Refresh"])
        footer_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(footer, nothing)
        footer_children = Wicked.SemanticToolkit.widget_semantic_children(footer, nothing, :footer)
        @test footer_descriptor.role == Wicked.Accessibility.GroupRole
        @test footer_descriptor.metadata[:hint_count] == 2
        @test footer_children[2].description == "Refresh"

        titlebar = TitleBar("Wicked"; subtitle="Build monitor")
        titlebar_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(titlebar, nothing)
        @test titlebar_descriptor.role == Wicked.Accessibility.HeadingRole
        @test titlebar_descriptor.label == "Wicked"
        @test titlebar_descriptor.description == "Build monitor"

        statusbar = StatusBar([:q => "Quit", :r => "Refresh"])
        statusbar_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(statusbar, nothing)
        statusbar_children = Wicked.SemanticToolkit.widget_semantic_children(statusbar, nothing, :statusbar)
        @test statusbar_descriptor.role == Wicked.Accessibility.GroupRole
        @test statusbar_descriptor.metadata[:hint_count] == 2
        @test statusbar_children[2].description == "Refresh"

        badge = Badge("Healthy")
        badge_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(badge, nothing)
        @test badge_descriptor.role == Wicked.Accessibility.StatusRole
        @test badge_descriptor.label == "Healthy"

        alert = Alert("Build failed"; title="Pipeline", severity=:error)
        alert_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(alert, nothing)
        @test alert_descriptor.role == Wicked.Accessibility.AlertRole
        @test alert_descriptor.label == "Pipeline"
        @test alert_descriptor.description == "Build failed"
        @test alert_descriptor.metadata[:severity] == :error

        @test Wicked.Toolkit.state_for(header) === nothing
        @test Wicked.Toolkit.state_for(titlebar) === nothing
        @test Wicked.Toolkit.state_for(footer) === nothing
        @test Wicked.Toolkit.state_for(badge) === nothing
        @test Wicked.Toolkit.state_for(alert) === nothing
    end

    @testset "developer and empty-state toolkit semantics" begin
        digits = Digits(42; spacing=2)
        digits_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(digits, nothing)
        @test digits_descriptor.role == Wicked.Accessibility.StatusRole
        @test digits_descriptor.state.value == "42"
        @test digits_descriptor.metadata[:spacing] == 2
        digits_dispatcher = SemanticDispatcher()
        register_digits_semantic_handlers!(digits_dispatcher, :digits, digits)
        digits_pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(digits; id=:digits, key=:digits))); dispatcher=digits_dispatcher)
        digits_result = perform_semantic_action!(digits_pilot, "digits", FocusSemanticAction)
        @test digits_result.handled
        @test digits_result.value[:value] == "42"

        pretty = Pretty((status=:ready, count=2); compact=true)
        pretty_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(pretty, nothing)
        @test pretty_descriptor.role == Wicked.Accessibility.GenericRole
        @test pretty_descriptor.state.readonly
        @test occursin("ready", pretty_descriptor.state.value)
        @test pretty_descriptor.metadata[:compact]
        pretty_dispatcher = SemanticDispatcher()
        register_pretty_semantic_handlers!(pretty_dispatcher, :pretty, pretty)
        pretty_pilot = SemanticPilot(toolkit_semantic_tree(ToolkitTree(Element(pretty; id=:pretty, key=:pretty))); dispatcher=pretty_dispatcher)
        pretty_result = perform_semantic_action!(pretty_pilot, "pretty", SelectSemanticAction)
        @test pretty_result.handled
        @test occursin("ready", pretty_result.value[:value])

        placeholder = Placeholder("No jobs"; symbol=".")
        placeholder_descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(placeholder, nothing)
        @test placeholder_descriptor.role == Wicked.Accessibility.GroupRole
        @test placeholder_descriptor.label == "No jobs"
        @test placeholder_descriptor.metadata[:symbol] == "."

        @test Wicked.Toolkit.state_for(digits) === nothing
        @test Wicked.Toolkit.state_for(pretty) === nothing
        @test Wicked.Toolkit.state_for(placeholder) === nothing
    end
end
