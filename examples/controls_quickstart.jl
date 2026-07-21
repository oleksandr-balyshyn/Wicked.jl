using Wicked.API

# Toolkit trees only populate their layout (and thus accessibility semantics)
# once they have been rendered, so lay the tree out before reading semantics.
function render_semantics(tree::ToolkitTree; kwargs...)
    render_toolkit!(Frame(Buffer(24, 80)), tree)
    return toolkit_semantic_tree(tree; kwargs...)
end

buffer = Buffer(18, 72)

render!(buffer, TitleBar("Controls quickstart"; subtitle="forms, choices, and pickers"), Rect(1, 1, 2, 72))

run = Button("Run", :run)
run_state = state_for(run)
run_dispatcher = SemanticDispatcher()
register_button_semantic_handlers!(run_dispatcher, :run, run, run_state)
render!(buffer, run, Rect(3, 50, 3, 20), run_state)

search = SearchInput(placeholder="Search")
search_state = SearchInputState("deploy"; focused=true)
search_dispatcher = SemanticDispatcher()
register_search_input_semantic_handlers!(search_dispatcher, :search, search, search_state)
render!(buffer, search, Rect(3, 1, 1, 24), search_state)

project = TextInput(placeholder="Project")
project_state = TextInputState("Wicked")
project_dispatcher = SemanticDispatcher()
register_text_input_semantic_handlers!(project_dispatcher, :project, project, project_state)
render!(buffer, project, Rect(6, 50, 1, 20), project_state)

number = NumberInput(placeholder="Port")
number_state = NumberInputState(value=8080, minimum=1, maximum=65_535)
number_dispatcher = SemanticDispatcher()
register_number_input_semantic_handlers!(number_dispatcher, :port, number, number_state)
render!(buffer, number, Rect(4, 1, 1, 24), number_state)

masked = MaskedInput("##-AA"; width=8)
masked_state = state_for(masked)
masked_dispatcher = SemanticDispatcher()
register_masked_input_semantic_handlers!(masked_dispatcher, :ticket, masked, masked_state)
@assert perform_semantic_action!(
    SemanticPilot(render_semantics(ToolkitTree(Element(masked; id=:ticket, key=:ticket, state_factory=() -> masked_state))); dispatcher=masked_dispatcher),
    "ticket",
    SetValueSemanticAction;
    value="12-AB",
).handled
render!(buffer, masked, Rect(7, 50, 1, 8), masked_state)

tags = TagInput(["julia", "tui"]; width=24, maximum=4)
tags_state = state_for(tags)
add_tag!(tags_state, "terminal")
tags_dispatcher = SemanticDispatcher()
register_tag_input_semantic_handlers!(tags_dispatcher, :tags, tags, tags_state)
render!(buffer, tags, Rect(5, 1, 1, 24), tags_state)

autocomplete = Autocomplete(["deploy", "rollback", "restart"]; max_visible=2)
autocomplete_state = state_for(autocomplete)
update_autocomplete!(autocomplete_state, "de")
autocomplete_dispatcher = SemanticDispatcher()
register_autocomplete_semantic_handlers!(autocomplete_dispatcher, :autocomplete, autocomplete, autocomplete_state)
render!(buffer, autocomplete, Rect(6, 1, 2, 24), autocomplete_state)

combo = ComboBox(["staging", "production"]; max_visible=2)
combo_state = state_for(combo)
combo_dispatcher = SemanticDispatcher()
register_combo_box_semantic_handlers!(combo_dispatcher, :environment, combo, combo_state)
render!(buffer, combo, Rect(8, 1, 2, 24), combo_state)

choices = [ChoiceOption(:staging, "Staging"), ChoiceOption(:production, "Production")]
select = Select(choices)
select_state = SelectState(selected=1)
select_dispatcher = SemanticDispatcher()
register_select_semantic_handlers!(select_dispatcher, :environment_select, select, select_state)
render!(buffer, select, Rect(3, 28, 2, 18), select_state)

multi = MultiSelect(choices)
multi_state = MultiSelectState(selected=[1, 2])
multi_dispatcher = SemanticDispatcher()
register_multi_select_semantic_handlers!(multi_dispatcher, :features, multi, multi_state)
render!(buffer, multi, Rect(5, 28, 2, 18), multi_state)

radio = RadioGroup(choices)
radio_state = RadioGroupState(selected=2)
radio_dispatcher = SemanticDispatcher()
register_radio_group_semantic_handlers!(radio_dispatcher, :mode, radio, radio_state)
render!(buffer, radio, Rect(7, 28, 2, 18), radio_state)

slider = Slider(0, 100; value=50, step=5, width=18)
slider_state = state_for(slider)
slider_dispatcher = SemanticDispatcher()
register_slider_semantic_handlers!(slider_dispatcher, :slider, slider, slider_state)
render!(buffer, slider, Rect(10, 1, 1, 24), slider_state)

range = RangeSlider(0, 100; lower=25, upper=75, step=5, width=18)
range_state = state_for(range)
range_dispatcher = SemanticDispatcher()
register_range_slider_semantic_handlers!(range_dispatcher, :range, range, range_state)
render!(buffer, range, Rect(11, 1, 1, 24), range_state)

# Family tokens: Checkbox, Input, TextArea, SearchInput

toggle = Toggle(on_label="Enabled", off_label="Disabled")
toggle_state = state_for(toggle)
toggle_dispatcher = SemanticDispatcher()
register_toggle_semantic_handlers!(toggle_dispatcher, :enabled, toggle, toggle_state)
render!(buffer, toggle, Rect(12, 28, 1, 18), toggle_state)

date = DatePicker(width=20, height=3)
date_state = state_for(date)
date_dispatcher = SemanticDispatcher()
register_date_picker_semantic_handlers!(date_dispatcher, :date, date_state)
render!(buffer, date, Rect(10, 28, 3, 20), date_state)

time = TimePicker(width=12)
time_state = state_for(time)
time_dispatcher = SemanticDispatcher()
register_time_picker_semantic_handlers!(time_dispatcher, :time, time_state)
render!(buffer, time, Rect(13, 28, 1, 20), time_state)

files = FilePicker(pwd(); width=24, height=3)
files_state = state_for(files)
files_dispatcher = SemanticDispatcher()
register_file_picker_semantic_handlers!(files_dispatcher, :files, files, files_state)
render!(buffer, files, Rect(12, 1, 3, 24), files_state)

transfer = TransferList([:build => "Build", :test => "Test"])
transfer_state = state_for(transfer)
transfer_dispatcher = SemanticDispatcher()
register_transfer_list_semantic_handlers!(transfer_dispatcher, :steps, transfer, transfer_state)
render!(buffer, transfer, Rect(15, 1, 2, 24), transfer_state)

form = Form([FormField(:environment; label="Environment", initial="")])
form_state = FormState(form)
form_dispatcher = SemanticDispatcher()
register_form_semantic_handlers!(form_dispatcher, :deploy_form, form, form_state)
field_state(form_state, :environment).issues = [
    ValidationIssue(:required, "Environment is required"),
]
render!(buffer, ValidationSummary(form, form_state), Rect(17, 1, 2, 40))

palette = CommandPalette([
    CommandItem(:deploy, "Deploy"),
    CommandItem(:rollback, "Rollback"),
]; title="Commands")
palette_state = CommandPaletteState(open=true)
set_command_palette_query!(palette_state, palette, "deploy"; record=false)
visible_commands = command_palette_filtered_commands(palette, palette_state)
selected_command = command_palette_selected_command(palette, palette_state)
@assert first(visible_commands).id == :deploy
@assert selected_command.id == :deploy
@assert activate(palette, palette_state) == :deploy
palette_dispatcher = SemanticDispatcher()
register_command_palette_semantic_handlers!(palette_dispatcher, :commands, palette, palette_state)
render!(buffer, palette, Rect(15, 42, 3, 30), palette_state)

snapshot = plain_snapshot(buffer)
@assert occursin("Controls quickstart", snapshot)
@assert occursin("deploy", snapshot)
@assert occursin("8080", snapshot)
@assert occursin("terminal", snapshot)
@assert occursin("staging", snapshot)
# The production environment choice renders via the Select/MultiSelect labels.
@assert occursin("Production", snapshot)
@assert occursin("Environment is required", snapshot)
@assert occursin("Commands", snapshot)
date_semantics = render_semantics(ToolkitTree(Element(date; id=:date, key=:date, state_factory=() -> date_state)))
date_pilot = SemanticPilot(date_semantics; dispatcher=date_dispatcher)
@assert perform_semantic_action!(date_pilot, "date", IncrementSemanticAction).handled
time_semantics = render_semantics(ToolkitTree(Element(time; id=:time, key=:time, state_factory=() -> time_state)))
time_pilot = SemanticPilot(time_semantics; dispatcher=time_dispatcher)
@assert perform_semantic_action!(time_pilot, "time", IncrementSemanticAction).handled

println("controls quickstart example completed")
