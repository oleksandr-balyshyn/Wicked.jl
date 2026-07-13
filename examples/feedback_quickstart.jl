using Wicked.API

buffer = Buffer(22, 84)

feedback_dispatcher = SemanticDispatcher()

header = Header("Feedback quickstart"; subtitle="status, alerts, notifications, validation")
register_header_semantic_handlers!(feedback_dispatcher, :header, header)
render!(buffer, header, Rect(1, 1, 2, 84))

badge = Badge("READY")
register_badge_semantic_handlers!(feedback_dispatcher, :badge, badge)
render!(buffer, badge, Rect(4, 1, 1, 16))
status = Status("Connected"; title="Status", severity=:success)
register_status_semantic_handlers!(feedback_dispatcher, :status, status)
render!(buffer, status, Rect(5, 1, 4, 38))
alert = Alert("Disk usage is high"; title="Warning", severity=:warning)
register_alert_semantic_handlers!(feedback_dispatcher, :alert, alert)
render!(buffer, alert, Rect(10, 1, 4, 38))
toast = Toast("Deploy finished"; title="Deploy", severity=:success, timeout=nothing)
register_toast_semantic_handlers!(feedback_dispatcher, :toast, toast)
render!(buffer, toast, Rect(15, 1, 1, 38))

center = NotificationCenter(3)
push_notification!(center, Notification("Connected"; title="Network", severity=:success, timeout=nothing))
push_notification!(center, Notification("Retry scheduled"; title="Worker", severity=:warning, timeout=nothing))
render!(buffer, Label("NotificationView"), Rect(4, 44, 1, 38))
render!(buffer, NotificationView(center), Rect(5, 44, 3, 38))

issues = ValidationIssue[
    ValidationIssue(:required, "Name is required"),
    ValidationIssue(:format, "Use lowercase"; severity=:warning),
]
render!(buffer, Label("ValidationMessage"), Rect(9, 44, 1, 38))
validation_message = ValidationMessage(issues)
register_validation_message_semantic_handlers!(feedback_dispatcher, :validation_message, validation_message)
render!(buffer, validation_message, Rect(10, 44, 2, 38))

form = Form([
    FormField(:name; label="Name", initial="", validators=[required_validator()]),
])
form_state = FormState(form)
validate_form!(form, form_state)
render!(buffer, Label("ValidationSummary"), Rect(13, 44, 1, 38))
validation_summary = ValidationSummary(form, form_state)
register_validation_summary_semantic_handlers!(feedback_dispatcher, :validation_summary, validation_summary)
render!(buffer, validation_summary, Rect(14, 44, 3, 38))

footer = Footer(["Esc" => "Close", "Enter" => "Accept", "?" => "Help"])
register_footer_semantic_handlers!(feedback_dispatcher, :footer, footer)
render!(buffer, footer, Rect(22, 1, 1, 84))

snapshot = plain_snapshot(buffer)
@assert occursin("Feedback quickstart", snapshot)
@assert occursin("READY", snapshot)
@assert occursin("Connected", snapshot)
@assert occursin("Disk usage is high", snapshot)
@assert occursin("Deploy finished", snapshot)
@assert occursin("NotificationView", snapshot)
@assert occursin("Retry scheduled", snapshot)
@assert occursin("ValidationMessage", snapshot)
@assert occursin("Name is required", snapshot)
@assert occursin("ValidationSummary", snapshot)
@assert occursin("Esc", snapshot)

println("feedback quickstart example completed")
