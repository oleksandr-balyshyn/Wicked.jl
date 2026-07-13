# Controls API

This page contains generated reference documentation for advanced controls,
data-entry widgets, and their immediate rendering adapters.

The stable advanced-control surface covers reusable state machines, key
bindings, render helpers, validation helpers, and semantic nodes for:

- Sliders, range sliders, scrollbars, breadcrumbs, collapsibles, accordions,
  pagination, steppers, dialogs, and modal stacks.
- Common control actions such as previous, next, page previous, page next,
  activate, toggle, switch, and cancel.
- `control_value`, `set_control_value!`, `control_valid`, and `control_error`
  helpers for building composite controls.
- Semantic adapters such as `slider_semantic_node`,
  `breadcrumb_semantic_tree`, `stepper_semantic_tree`, and
  `dialog_semantic_tree`.

The stable data-entry surface covers the same kind of reusable state machines,
key bindings, render helpers, validation helpers, and semantic nodes for:

- Autocomplete lists, combo boxes, and tag inputs.
- Numeric, masked, date, time, and color values.
- Common data-entry actions such as previous, next, accept, cancel, increment,
  decrement, backspace, delete, and field switching.
- `control_value`, `set_control_value!`, `control_valid`, and `control_error`
  helpers for building form containers.
- `data_entry_semantic_node` and `autocomplete_semantic_tree` for accessibility
  and toolkit integration.

High-level widgets such as `MaskedInput`, `NumberInput`, `DateInput`,
`DatePicker`, `TimeInput`, `TimePicker`, `DateTimeInput`, `DateTimePicker`,
`ColorPicker`, and `Autocomplete` use the same state contracts. `MaskedInput`
uses `MaskedInputState`, `ColorPicker` uses `ColorPickerState`, and `TagInput`
uses `TagInputState`; applications should keep that state between frames when
the cursor, editable value, selected color, tags, or validation status must
persist. Applications may also use these state values directly to build custom controls. These
controls support
default-state rendering for static previews and examples; interactive
applications should keep the returned state value between frames.

`MaskedInput` renders a constrained text field from an input mask such as
`"##-AA"`. Use `register_masked_input_semantic_handlers!` when automation
should focus the field or set a complete masked value:

```julia
masked = MaskedInput("##-AA")
masked_state = state_for(masked)
register_masked_input_semantic_handlers!(dispatcher, :ticket, masked, masked_state)
```

## Numeric control naming

Use `NumberInput` for immediate-mode rendering. It owns the render configuration
and uses `NumberInputState` for cursor, text, bounds, validation, and committed
numeric value:

```julia
widget = NumberInput(placeholder="Port")
state = NumberInputState(value=8080, minimum=1, maximum=65535)

render!(buffer, widget, area, state)
```

Use `register_number_input_semantic_handlers!` when tests or accessibility
automation should focus, set, increment, or decrement the numeric value without
raw key events:

```julia
dispatcher = SemanticDispatcher()
register_number_input_semantic_handlers!(dispatcher, :port, widget, state)
```

Use `NumericInputState` when building data-entry forms, custom Toolkit
components, or adapters that already render through `render_numeric_input` or
`numeric_input_component`. This state is deliberately separate from
`NumberInputState` because it is a form-control model rather than an immediate
widget cursor model:

```julia
state = NumericInputState(value=2, minimum=0, maximum=10, step=0.5)
line = render_numeric_input(state; width=12)
```

`NumericInput` is now a compatibility constructor for `NumberInput`, so there is no
separate immediate-mode implementation class. Prefer `NumberInput` for direct widgets
and `NumericInput` for migration compatibility, while `NumericInputState` remains
the dedicated data-entry form-control model.

Use `state_for(widget)` when a built-in control should start with the default
externally owned state:

```julia
using Wicked.API

widget = NumberInput(placeholder="Port")
state = state_for(widget)

set_number_value!(state, 8080)
@assert number_input_valid(state)
```

Use `Autocomplete` when a completion list should behave like a normal immediate
widget while still exposing its query and selected match through
`AutocompleteState`. Keyboard navigation uses the shared data-entry bindings,
and a left-button mouse release on a visible suggestion accepts it:

```julia
items = [CompletionItem("Release", :release), CompletionItem("Rollback", :rollback)]
widget = Autocomplete(items; max_visible=4)
state = state_for(widget)

update_autocomplete!(state, "rel")
render!(buffer, widget, area, state)
```

Use `ComboBox` when the control needs both a selected value display and an
autocomplete-backed option list. Its externally owned state is `ComboBoxState`,
which keeps the query, open/closed completion list, highlighted match, and
selected value coherent:

```julia
widget = ComboBox(["Debug", "Release"]; editable=false, required=true)
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `Combobox` when porting retained-style dropdown code that expects
`SelectState` behavior rather than an editable autocomplete query:

```julia
widget = Combobox(["Debug", "Release"]; placeholder="Mode")
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `TagInput` when a form needs a compact list of editable chips. Applications
can manage tags directly with `add_tag!`, `remove_tag!`, and `clear_tags!`; the
widget also supports paste-to-add, backspace/delete removal, and pointer removal
of clicked tags. Keep `TagInputState` between frames so the tag list and active
edit buffer persist:

```julia
widget = TagInput(["julia", "tui"]; maximum=4)
state = state_for(widget)

add_tag!(state, "terminal")
render!(buffer, widget, area, state)
```

Use `Button`, `PushButton`, `Checkbox`, `CheckBox`, `Toggle`, and `Switch` for
direct action and boolean controls. Their state contracts are `ButtonState`,
`PushButtonState`, `CheckboxState`, `CheckBoxState`, `ToggleState`, and
`SwitchState`, which keep pressed, checked, and enabled state explicit across
redraws:

```julia
run = Button("Run")
launch = PushButton("Launch", :launch)
ready = Checkbox("Ready")
accepted = CheckBox("Accepted")
enabled = Toggle()
switch = Switch(on_label="Enabled", off_label="Disabled")
```

`PushButtonState` is intentionally identical to `ButtonState`. Use `PushButton`
when porting Lanterna-style code or when an action control should read as a
push-button in application code.

`SwitchState` is intentionally identical to `ToggleState`. Use `Switch` when
porting Textual-style code, and use `Toggle` for the shorter Wicked-native name.

Register semantic handlers when tests or accessibility automation should drive
buttons, boolean controls, and range controls without raw key events:

```julia
dispatcher = SemanticDispatcher()
register_button_semantic_handlers!(dispatcher, :run, run, ButtonState())
register_push_button_semantic_handlers!(dispatcher, :launch, launch, PushButtonState())
register_checkbox_semantic_handlers!(dispatcher, :ready, ready, CheckboxState())
register_check_box_semantic_handlers!(dispatcher, :accepted, accepted, CheckBoxState())
register_toggle_semantic_handlers!(dispatcher, :enabled, enabled, ToggleState())
register_switch_semantic_handlers!(dispatcher, :switch, switch, SwitchState())
```

Button handlers support focus and activation. Checkbox, toggle, and switch
handlers support focus, activation/toggling, and boolean
`SetValueSemanticAction` values such as `true`, `false`, `"on"`, or `"off"`.

Use `TextInput`, `Input`, `TextBox`, `TextField`, `SearchInput`,
`PasswordInput`, `PasswordField`, `TextArea`, and `Textarea` for text entry.
`Input` provides the Textual naming style, `TextBox` provides the Lanterna-style
name, and `Textarea` preserves the compact compatibility spelling. Register
semantic handlers when tests or accessibility tooling should focus fields or set
their value without raw key events:

```julia
dispatcher = SemanticDispatcher()
register_text_input_semantic_handlers!(dispatcher, :name, TextInput(), TextInputState())
register_input_semantic_handlers!(dispatcher, :query, Input(), InputState())
register_text_box_semantic_handlers!(dispatcher, :legacy_name, TextBox(), TextBoxState())
register_text_field_semantic_handlers!(dispatcher, :field, TextField(), TextFieldState())
register_search_input_semantic_handlers!(dispatcher, :search, SearchInput(), SearchInputState())
register_password_input_semantic_handlers!(dispatcher, :password, PasswordInput(), TextInputState())
register_password_field_semantic_handlers!(dispatcher, :password_field, PasswordField(), PasswordFieldState())
register_text_area_semantic_handlers!(dispatcher, :notes, TextArea(), TextAreaState())
register_textarea_semantic_handlers!(dispatcher, :body, Textarea(), TextAreaState())
```

Password handlers preserve protected semantic values: automation can set the
owned state, but returned semantic values do not expose the password text.

Use `SplitButton` and `CommandPalette` for command-heavy applications.
`SplitButtonState` keeps split-button activation compatible with ordinary
button handling, while `CommandPaletteState` owns open/closed state, filtering,
and selection:

```julia
deploy = SplitButton("Deploy", :deploy)
palette = CommandPalette([CommandItem(:open, "Open")])
state = CommandPaletteState(open=true)

set_command_palette_query!(state, palette, "open")
visible = command_palette_filtered_commands(palette, state)
selected = command_palette_selected_command(palette, state)
action = activate(palette, state)
```

Use `register_split_button_semantic_handlers!` when automation should focus or
activate the split-button action through the same semantic path as ordinary
buttons.

`command_palette_filtered_commands` returns the visible enabled `CommandItem`
values for the current query. Use `select_command!`, `select_next_command!`, and
`select_previous_command!` when keyboard handlers or tests need to drive
selection without reaching into `CommandPaletteState` fields.
Use `register_command_palette_semantic_handlers!` when a `SemanticPilot` or
automation layer should focus, dismiss, or activate palette commands through
semantic actions.

Use semantic handlers for completion and transfer controls when tests or
accessibility tooling need to drive the widget without raw terminal events:

```julia
autocomplete = Autocomplete(["deploy", "rollback"])
autocomplete_state = state_for(autocomplete)

combo = ComboBox(["staging", "production"])
combo_state = state_for(combo)

tags = TagInput(["julia"])
tags_state = state_for(tags)

transfer = TransferList([:build => "Build", :test => "Test"])
transfer_state = state_for(transfer)

dispatcher = SemanticDispatcher()
register_autocomplete_semantic_handlers!(dispatcher, :autocomplete, autocomplete, autocomplete_state)
register_combo_box_semantic_handlers!(dispatcher, :environment, combo, combo_state)
register_tag_input_semantic_handlers!(dispatcher, :tags, tags, tags_state)
register_transfer_list_semantic_handlers!(dispatcher, :steps, transfer, transfer_state)
```

Autocomplete and combo-box handlers support focus, query/value setting,
increment/decrement movement, activation, and dismissal. Tag handlers replace or
clear the tag list and remove individual tag chips. Transfer-list handlers move
the highlight, replace selected values, and toggle individual options.
Use `register_combo_box_semantic_handlers!` for editable `ComboBox` controls and
`register_combobox_semantic_handlers!` for retained-style `Combobox` dropdowns.

Use `Slider` when a form needs a direct range control backed by `SliderState`.
Keyboard input uses the shared advanced-control bindings, and pointer release on
the track sets the nearest snapped value:

```julia
widget = Slider(0, 100; value=50, step=5, width=24)
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `register_slider_semantic_handlers!` when automation should focus, set,
increment, or decrement the slider through semantic actions.

Use `RangeSlider` when users need to choose lower and upper bounds on the same
track. `tab` switches the active handle through the shared advanced-control
bindings, and pointer release moves the nearest handle:

```julia
widget = RangeSlider(0, 100; lower=20, upper=80, step=5, width=24)
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `register_range_slider_semantic_handlers!` when automation should set both
handles, move the active handle, switch handles, or directly set the lower/upper
semantic child nodes.

Use `Pagination` with `PaginationState` when large data sets need explicit page
navigation separate from the table or list renderer:

```julia
pages = Pagination(1_000; page_size=50)
state = state_for(pages)
render!(buffer, pages, area, state)
```

Use `ValidationMessage` and `ValidationSummary` for form validation feedback.
`ValidationMessage` renders one field-level problem, while `ValidationSummary`
renders the current `FormState` issues for all fields. Use
`register_form_semantic_handlers!` when tests or automation should set fields,
reset fields, reset the whole form, or trigger validation through semantic
actions:

```julia
form = Form([FormField(:environment; label="Environment", initial="")])
state = FormState(form)
dispatcher = SemanticDispatcher()

register_form_semantic_handlers!(dispatcher, :deploy_form, form, state)
```

`ValidationSummary` renders the collected form-level diagnostics without
requiring widget-owned state:

```julia
issues = ValidationIssue[ValidationIssue(:required, "Name is required")]
field_error = ValidationMessage(issues)

form = Form([FormField(:name; label="Name", initial="")])
form_state = FormState(form)
field_state(form_state, :name).issues = issues
summary = ValidationSummary(form, form_state)

render!(buffer, field_error, Rect(1, 1, 1, 40))
render!(buffer, summary, Rect(2, 1, 2, 40))
```

Use `register_validation_message_semantic_handlers!` and
`register_validation_summary_semantic_handlers!` when tests or accessibility
tooling should inspect validation feedback through semantic actions.

For a focused rendering example that includes validation feedback widgets, see
[`examples/feedback_quickstart.jl`](../examples/feedback_quickstart.jl).

Use `Collapsible` when a section should disclose or hide child content while
keeping expanded state explicit:

```julia
widget = Collapsible("Details", Paragraph("Build metadata"); expanded=false)
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `register_collapsible_semantic_handlers!` when a `SemanticPilot` should
toggle, expand, or collapse the section through semantic actions.

Use `Carousel` when a navigation area should page through one or more items with
explicit `CarouselState` ownership:

```julia
widget = Carousel(["Overview", "Logs", "Metrics"]; window=1)
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `register_carousel_semantic_handlers!` when semantic tests should move the
carousel forward, backward, or to a specific item/index.

Use `Accordion` when several disclosure sections share one state object. The
state stores expanded section keys; the widget owns section labels, children, and
whether multiple sections can remain open:

```julia
widget = Accordion([(:build, "Build", Paragraph("Logs"))]; expanded=[:build])
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `register_accordion_semantic_handlers!` when automation should activate,
expand, or collapse accordion sections through their semantic child nodes.

Use `DatePicker` when the UI should present the conventional calendar-picker
name while still using the same explicit `DatePickerState` contract as
`DateInput`:

```julia
widget = DatePicker(selected=Dates.Date(2026, 1, 15))
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `register_date_input_semantic_handlers!` or
`register_date_picker_semantic_handlers!` when automation should focus, set,
increment, or decrement date controls through semantic actions.

Use `TimePicker` when the UI should present a picker-named time control while
still using the same explicit `TimePickerState` contract as `TimeInput`:

```julia
widget = TimePicker(value=Dates.Time(12, 0), step_seconds=60)
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `register_time_input_semantic_handlers!` or
`register_time_picker_semantic_handlers!` for the same semantic action contract
on time controls.

Use `DateTimePicker` when the UI should expose a single picker-named date and
time control while keeping the combined `DateTimeInputState` contract:

```julia
widget = DateTimePicker(Dates.DateTime(2026, 1, 15, 12); step_seconds=60)
state = state_for(widget)

render!(buffer, widget, area, state)
```

Use `register_date_time_input_semantic_handlers!`,
`register_date_time_picker_semantic_handlers!`, and
`register_color_picker_semantic_handlers!` for datetime and color-picker
WidgetPilot automation.

Use the file-system picker family when an application needs the same browsing
surface with different selection modes:

```julia
file = FilePicker(pwd())
directory = DirectoryPicker(pwd())
multiple = MultiFilePicker(pwd())
```

Register semantic handlers when tests, automation, or accessible tooling need to
drive the picker without terminal key events:

```julia
state = state_for(file)
dispatcher = SemanticDispatcher()
register_file_picker_semantic_handlers!(dispatcher, :files, file, state)
```

The same handler contract is available for `DirectoryPicker`, `DirectoryTree`,
and `MultiFilePicker` through `register_directory_picker_semantic_handlers!`,
`register_directory_tree_semantic_handlers!`, and
`register_multi_file_picker_semantic_handlers!`. Root semantic actions focus or
move the cursor. Entry semantic actions focus, select, activate valid choices,
or expand directories.

## Selection helpers

`ChoiceOption` is the stable option model for `RadioGroup`, `RadioSet`,
`RadioBoxList`, `Select`, `MultiSelect`, and `CheckBoxList`. `RadioButton`
shares the `RadioGroupState` contract for a single-option radio control,
`RadioSet` shares the same state as `RadioGroup` for Textual-style naming,
`RadioBoxList` shares that radio state for Lanterna-style naming, `CheckBoxList`
shares the same state as `MultiSelect` for Lanterna-style naming, and
`TransferList` shares the `MultiSelectState` contract for transfer-list naming.
Use explicit options when labels, styles, or disabled choices need to differ
from the application value:

```julia
options = [
    ChoiceOption(:debug, "Debug"),
    ChoiceOption(:safe, "Safe mode"; disabled=true),
    ChoiceOption(:release, "Release"),
]

radio = RadioGroup(options)
radio_state = RadioGroupState(selected=1)
@assert selected_value(radio, radio_state) == :debug

radio_set = RadioSet(options)
radio_set_state = RadioSetState(selected=3)
@assert selected_value(radio_set, radio_set_state) == :release

radio_boxes = RadioBoxList(options)
radio_boxes_state = RadioBoxListState(selected=3)
@assert selected_value(radio_boxes, radio_boxes_state) == :release

single = RadioButton(:debug, "Debug")
single_state = state_for(single)
single_state.selected = 1
@assert selected_value(single, single_state) == :debug

multi = MultiSelect(options)
multi_state = MultiSelectState(selected=[1, 3])
@assert selected_values(multi, multi_state) == [:debug, :release]

checklist = CheckBoxList(options)
checklist_state = CheckBoxListState(selected=[1, 3])
@assert selected_values(checklist, checklist_state) == [:debug, :release]

selection = SelectionList(options)
selection_state = SelectionListState(selected=[1, 3])
@assert selected_values(selection, selection_state) == [:debug, :release]

transfer = TransferList(options)
transfer_state = MultiSelectState(selected=[1])
@assert selected_values(transfer, transfer_state) == [:debug]
```

Register semantic handlers when automation should drive these selection widgets
through stable action names instead of keyboard events:

```julia
dispatcher = SemanticDispatcher()
register_radio_group_semantic_handlers!(dispatcher, :radio, radio, radio_state)
register_radio_set_semantic_handlers!(dispatcher, :radio_set, radio_set, radio_set_state)
register_radio_box_list_semantic_handlers!(dispatcher, :radio_boxes, radio_boxes, radio_boxes_state)
register_select_semantic_handlers!(dispatcher, :mode, Select(options), SelectState())
register_multi_select_semantic_handlers!(dispatcher, :features, multi, multi_state)
register_check_box_list_semantic_handlers!(dispatcher, :checklist, checklist, checklist_state)
register_selection_list_semantic_handlers!(dispatcher, :selection, selection, selection_state)
register_option_list_semantic_handlers!(dispatcher, :options, OptionList(["Build", "Test"]), OptionListState())
register_list_box_semantic_handlers!(dispatcher, :list_box, ListBox(["Build", "Test"]), ListBoxState())
```

Radio handlers focus, move, set, and select one option. Select and retained
`Combobox` handlers focus, open/dismiss, move the highlight, set a value, and
activate an option. Multi-selection handlers focus, move, replace selected
values, and toggle individual options. List, option-list, list-view, and
list-box handlers focus, move, scroll into view, set by label/index, and select
individual items.

Disabled selections return `nothing` or are omitted from the selected value list.
Use `selected_item(menu, state)` for menus when the application needs the full
enabled `MenuItem` rather than only its message.

## Validation status

Form fields expose stable `ValidationStatus` values:

- `Unvalidated`
- `Validating`
- `ValidField`

Use these values when integrating custom field renderers, semantic state, or
async validation feedback with the form manager.

```@autodocs
Modules = [
    Wicked.AdvancedControls,
    Wicked.AdvancedControlRendering,
    Wicked.DataEntryControls,
    Wicked.DataEntryRendering,
]
Private = false
```
