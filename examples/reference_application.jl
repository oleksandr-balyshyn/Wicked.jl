using Wicked.API
import Wicked.API: app_view, initialize, render!, update!

struct LoadDeployments end
struct FailRefresh end
struct OpenDeployDialog end
struct ConfirmDeploy end
struct ToggleTheme end
struct SubmitSettings end
struct ExitReferenceApp end

mutable struct ReferenceModel
    tabs::TabsState
    table::TableState
    form::Form
    form_state::FormState
    dialog::DialogState{Symbol}
    themes::ThemeRegistry
    deployments::Vector{Vector{String}}
    loading::Bool
    deployed::Bool
    failures::Vector{RuntimeFailure}
end

struct ReferenceApp <: WickedApp end
struct ReferenceView
    model::ReferenceModel
end

const REFERENCE_TABS = Tabs([
    Tab(:deployments, "Deployments"),
    Tab(:settings, "Settings"),
    Tab(:operations, "Operations"),
])

function reference_themes()
    paper = Theme(
        :paper;
        roles=Dict(
            :text => Style(foreground=AnsiColor(0), background=AnsiColor(15)),
            :accent => Style(foreground=AnsiColor(4), modifiers=BOLD),
            :surface => Style(background=AnsiColor(15)),
        ),
    )
    night = Theme(
        :night;
        roles=Dict(
            :text => Style(foreground=AnsiColor(15), background=AnsiColor(0)),
            :accent => Style(foreground=AnsiColor(6), modifiers=BOLD),
            :surface => Style(background=AnsiColor(0)),
        ),
    )
    ThemeRegistry([
        ThemeDescriptor(:paper, paper; display_name="Paper", variant=LightTheme),
        ThemeDescriptor(:night, night; display_name="Night", variant=DarkTheme),
    ]; active=:paper)
end

function initialize(::ReferenceApp)
    form = Form([
        FormField(
            :operator;
            label="Operator",
            initial="Julia",
            validators=[required_validator()],
        ),
        FormField(
            :environment;
            label="Environment",
            initial="staging",
            validators=[
                required_validator(),
                Validator(
                    value -> value in ("staging", "production");
                    asynchronous=true,
                    code=:environment,
                    message="Use staging or production",
                ),
            ],
        ),
    ])
    buttons = DialogButton{Symbol}[
        DialogButton("Deploy", :deploy; role=DefaultDialogButton),
        DialogButton("Cancel", :cancel; role=CancelDialogButton),
    ]
    ReferenceModel(
        TabsState(1),
        TableState(selected_row=1),
        form,
        FormState(form),
        DialogState(buttons),
        reference_themes(),
        Vector{String}[],
        false,
        false,
        RuntimeFailure[],
    )
end

app_view(::ReferenceApp, model::ReferenceModel) = ReferenceView(model)

function selected_screen(model::ReferenceModel)
    REFERENCE_TABS.tabs[model.tabs.selected].id
end

function deployment_table(model::ReferenceModel)
    Table(
        [
            TableColumn("Service"; constraint=Fill(2)),
            TableColumn("Version"; constraint=Length(12)),
            TableColumn("Status"; constraint=Fill(1)),
        ],
        model.deployments;
        block=Block(title="Deployment inventory", padding=Margin(0, 1)),
        highlight_style=Style(background=AnsiColor(4), foreground=AnsiColor(15)),
    )
end

function theme_styles(model::ReferenceModel)
    descriptor = active_theme_descriptor(model.themes)
    dark = descriptor.id == :night
    return (
        base=dark ? Style(foreground=AnsiColor(15), background=AnsiColor(0)) :
             Style(foreground=AnsiColor(0), background=AnsiColor(15)),
        accent=dark ? Style(foreground=AnsiColor(6), modifiers=BOLD) :
               Style(foreground=AnsiColor(4), modifiers=BOLD),
    )
end

function render_settings!(buffer::Buffer, model::ReferenceModel, area::Rect)
    operator = field_state(model.form_state, :operator)
    environment = field_state(model.form_state, :environment)
    lines = [
        "Operator: $(operator.value)",
        "Environment: $(environment.value)",
        "State: $(form_valid(model.form, model.form_state) ? "valid" : "not submitted")",
        "",
        "Submit validates synchronously and through a managed background command.",
    ]
    block = Block(title="Settings", padding=Margin(0, 1))
    render!(buffer, block, area)
    render!(buffer, Paragraph(join(lines, '\n')), inner(block, area))
    issues = form_issues(model.form, model.form_state)
    if !isempty(issues) && area.height >= 3
        summary_area = Rect(area.row + area.height - 2, area.column + 2, 2, max(0, area.width - 4))
        render!(buffer, ValidationSummary(model.form, model.form_state), summary_area)
    end
end

function render_operations!(buffer::Buffer, model::ReferenceModel, area::Rect)
    if isempty(model.failures)
        status = model.loading ? "Refreshing deployment data..." : "No operational failures."
        render!(buffer, Alert(status; severity=:success, title="Operations"), area)
    else
        failure = last(model.failures)
        render!(
            buffer,
            Alert(
                "$(failure.phase)/$(something(failure.id, :anonymous)): $(sprint(showerror, failure.error))";
                severity=:error,
                title="Recovered background failure",
            ),
            area,
        )
    end
end

function render!(buffer::Buffer, view::ReferenceView, area::Rect)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    model = view.model
    styles = theme_styles(model)
    fill!(buffer, Cell(; style=styles.base); area=active)

    header_height = min(2, active.height)
    render!(
        buffer,
        Header(
            "Wicked Operations Console";
            subtitle="Managed runtime reference application",
            style=styles.accent,
        ),
        Rect(active.row, active.column, header_height, active.width),
    )
    active.height >= 3 && render!(
        buffer,
        REFERENCE_TABS,
        Rect(active.row + 2, active.column, 1, active.width),
        model.tabs,
    )

    content_row = active.row + min(3, active.height)
    footer_height = active.height >= 5 ? 1 : 0
    content_height = max(0, active.row + active.height - footer_height - content_row)
    if content_height > 0
        content = Rect(content_row, active.column, content_height, active.width)
        screen = selected_screen(model)
        if screen == :deployments
            render!(buffer, deployment_table(model), content, model.table)
        elseif screen == :settings
            render_settings!(buffer, model, content)
        else
            render_operations!(buffer, model, content)
        end
    end

    if footer_height == 1
        render!(
            buffer,
            Footer([
                "←/→" => "Navigate",
                "L" => "Load",
                "D" => "Dialog",
                "T" => "Theme",
                "Q" => "Exit",
            ]),
            Rect(active.row + active.height - 1, active.column, 1, active.width),
        )
    end

    if model.dialog.open && active.height >= 7 && active.width >= 36
        dialog_area = center(active, Size(7, min(52, active.width - 4)))
        render!(buffer, Clear(), dialog_area)
        render!(
            buffer,
            Alert(
                "Deploy the selected service to $(field_value(model.form_state, :environment))?\n\nEnter confirms. Escape cancels.";
                severity=:warning,
                title="Confirm deployment",
            ),
            dialog_area,
        )
    end
    return buffer
end

function update!(::ReferenceApp, model::ReferenceModel, message)
    payload = message isa CustomEvent ? message.payload : message

    if message isa KeyEvent
        if message.key.code in (:left, :right, :tab, :backtab, :home, :end)
            handle!(model.tabs, REFERENCE_TABS, message)
            return FrameCommand()
        elseif selected_screen(model) == :deployments && message.key.code in (:up, :down)
            handle!(model.table, deployment_table(model), message; viewport_height=12)
            return FrameCommand()
        end
    end

    if payload isa LoadDeployments
        model.loading = true
        return TaskCommand(
            () -> [
                ["api", "v1.8.0", "healthy"],
                ["worker", "v1.7.4", "deploying"],
                ["scheduler", "v2.1.0", "healthy"],
            ];
            id=:load_deployments,
            on_success=identity,
            on_error=identity,
        )
    elseif payload isa FailRefresh
        model.loading = true
        return TaskCommand(
            () -> error("control plane unavailable");
            id=:refresh,
            on_success=identity,
            on_error=identity,
        )
    elseif message isa CommandFinished && message.id == :load_deployments
        model.deployments = Vector{String}[String.(row) for row in message.value]
        model.loading = false
    elseif message isa CommandFinished && message.value isa ValidationCompleted
        apply_validation!(model.form_state, message)
    elseif message isa RuntimeFailure
        model.loading = false
        push!(model.failures, message)
        model.tabs.selected = 3
    elseif payload isa OpenDeployDialog
        open_dialog!(model.dialog)
    elseif payload isa ConfirmDeploy
        model.dialog.open || return NoCommand()
        model.dialog.focused = 1
        model.deployed = activate_dialog_button!(model.dialog) == :deploy
    elseif payload isa ToggleTheme
        selected = active_theme_descriptor(model.themes).id
        set_active_theme!(model.themes, selected == :paper ? :night : :paper)
    elseif payload isa SubmitSettings
        return validate_form!(model.form, model.form_state)
    elseif payload isa Pair && first(payload) == :field
        id, value = last(payload)
        set_field!(model.form_state, id, value)
    elseif payload isa ExitReferenceApp
        return ExitCommand((
            deployments=length(model.deployments),
            deployed=model.deployed,
            theme=active_theme_descriptor(model.themes).id,
            failures=length(model.failures),
        ))
    end
    return FrameCommand()
end

app = ReferenceApp()
pilot = RuntimePilot(app; height=24, width=88)

@assert occursin("Wicked Operations Console", plain_snapshot(pilot))
@assert occursin("Deployment inventory", plain_snapshot(pilot))

loaded = send!(pilot, LoadDeployments())
@assert loaded.processed_messages == 2
@assert length(pilot.model.deployments) == 3
@assert occursin("scheduler", plain_snapshot(pilot))

send!(pilot, KeyEvent(Key(:right)))
@assert selected_screen(pilot.model) == :settings
send!(pilot, :field => (:environment, ""))
send!(pilot, SubmitSettings())
@assert field_state(pilot.model.form_state, :environment).status == InvalidField
@assert occursin("This field is required", plain_snapshot(pilot))

send!(pilot, :field => (:environment, "production"))
validated = send!(pilot, SubmitSettings())
@assert validated.processed_messages == 2
@assert form_valid(pilot.model.form, pilot.model.form_state)

send!(pilot, OpenDeployDialog())
@assert pilot.model.dialog.open
@assert occursin("Confirm deployment", plain_snapshot(pilot))
send!(pilot, ConfirmDeploy())
@assert pilot.model.deployed
@assert !pilot.model.dialog.open

send!(pilot, ToggleTheme())
@assert active_theme_descriptor(pilot.model.themes).id == :night

failed = send!(pilot, FailRefresh())
@assert failed.processed_messages == 2
@assert length(pilot.model.failures) == 1
@assert selected_screen(pilot.model) == :operations
@assert occursin("Recovered background failure", plain_snapshot(pilot))
@assert occursin("control plane unavailable", plain_snapshot(pilot))

finished = send!(pilot, ExitReferenceApp())
@assert finished.exited
@assert finished.result == (deployments=3, deployed=true, theme=:night, failures=1)

println("reference application example completed")
