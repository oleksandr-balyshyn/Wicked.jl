@testset "Input widgets" begin
    @testset "button keyboard and mouse" begin
        widget = Button("Run", :run)
        state = ButtonState(focused=true)

        @test handle!(state, widget, KeyEvent(Key(:enter); kind=KeyPress))
        @test state.pressed
        @test handle!(state, widget, KeyEvent(Key(:enter); kind=KeyRelease))
        @test !state.pressed
        @test activate(widget, state) == :run

        push = PushButton("Run", :run)
        push_state = PushButtonState(focused=true)
        @test PushButtonState === ButtonState
        @test handle!(push_state, push, KeyEvent(Key(:enter); kind=KeyPress))
        @test push_state.pressed
        @test handle!(push_state, push, KeyEvent(Key(:enter); kind=KeyRelease))
        @test !push_state.pressed
        @test activate(push, push_state) == :run

        outside_press = MouseEvent(Position(1, 8), LeftMouseButton, MousePress)
        @test !handle!(state, widget, outside_press, Rect(1, 1, 1, 7))
        inside_press = MouseEvent(Position(1, 2), LeftMouseButton, MousePress)
        inside_release = MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease)
        @test handle!(state, widget, inside_press, Rect(1, 1, 1, 7))
        @test handle!(state, widget, inside_release, Rect(1, 1, 1, 7))

        disabled = Button("Run", :run; disabled=true)
        @test !handle!(state, disabled, KeyEvent(Key(:enter)))
        @test activate(disabled, state) === nothing

        default_buffer = Buffer(3, 9)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("Run", plain_snapshot(default_buffer))
        push_buffer = Buffer(3, 9)
        @test render!(push_buffer, push, push_buffer.area) === push_buffer
        @test occursin("Run", plain_snapshot(push_buffer))
    end

    @testset "checkbox and toggle" begin
        checkbox = Checkbox("Ready")
        checked = CheckboxState()
        @test !handle!(checked, checkbox, KeyEvent(Key(:enter); kind=KeyRelease))
        @test !checked.checked
        @test handle!(checked, checkbox, KeyEvent(Key(:enter)))
        @test checked.checked
        @test !handle!(
            checked,
            checkbox,
            MouseEvent(Position(1, 8), LeftMouseButton, MouseRelease),
            Rect(1, 1, 1, 7),
        )

        checkbox_buffer = Buffer(1, 12)
        @test render!(checkbox_buffer, checkbox, checkbox_buffer.area) === checkbox_buffer
        @test occursin("[ ] Ready", plain_snapshot(checkbox_buffer))

        check_box = CheckBox("Accepted")
        check_box_state = CheckBoxState()
        @test CheckBoxState === CheckboxState
        @test handle!(check_box_state, check_box, KeyEvent(Key(:enter)))
        @test check_box_state.checked
        @test handle!(
            check_box_state,
            check_box,
            MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease),
            Rect(1, 1, 1, 12),
        )
        @test !check_box_state.checked

        toggle = Toggle()
        toggled = ToggleState()
        @test handle!(toggled, toggle, KeyEvent(Key(:character); text=" "))
        @test toggled.enabled
        @test !handle!(toggled, toggle, KeyEvent(Key(:character); text=" ", kind=KeyRelease))
        @test toggled.enabled

        @test handle!(
            toggled,
            toggle,
            MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease),
            Rect(1, 1, 1, 6),
        )
        @test !toggled.enabled

        toggle_buffer = Buffer(1, 10)
        @test render!(toggle_buffer, toggle, toggle_buffer.area) === toggle_buffer
        @test occursin("OFF", plain_snapshot(toggle_buffer))

        switch = Switch()
        switched = SwitchState()
        @test SwitchState === ToggleState
        @test handle!(switched, switch, KeyEvent(Key(:enter)))
        @test switched.enabled
        @test handle!(
            switched,
            switch,
            MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease),
            Rect(1, 1, 1, 6),
        )
        @test !switched.enabled
    end

    @testset "radio layout and disabled options" begin
        widget = RadioGroup(
            [
                ChoiceOption(:one, "One"),
                ChoiceOption(:two, "Two"; disabled=true),
                ChoiceOption(:three, "Three"),
            ];
            direction=HorizontalLayout,
            gap=1,
        )
        state = RadioGroupState()

        @test handle!(state, widget, KeyEvent(Key(:right)))
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:right)))
        @test state.selected == 3
        @test selected_value(widget, state) == :three

        disabled_state = RadioGroupState(selected=2)
        @test selected_value(widget, disabled_state) === nothing
        click_disabled = MouseEvent(Position(1, 11), LeftMouseButton, MouseRelease)
        @test !handle!(state, widget, click_disabled, Rect(1, 1, 1, 30))
        click_third = MouseEvent(Position(1, 18), LeftMouseButton, MouseRelease)
        @test handle!(state, widget, click_third, Rect(1, 1, 1, 30))
        @test state.selected == 3

        buffer = Buffer(1, 30)
        render!(buffer, widget, buffer.area, state)
        @test buffer[1, 1].grapheme == "("
        default_buffer = Buffer(1, 30)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("( ) One", plain_snapshot(default_buffer))

        radio_set = RadioSet([
            ChoiceOption(:one, "One"),
            ChoiceOption(:two, "Two"; disabled=true),
            ChoiceOption(:three, "Three"),
        ])
        radio_set_state = RadioSetState()
        @test RadioSetState === RadioGroupState
        @test handle!(radio_set_state, radio_set, KeyEvent(Key(:down)))
        @test radio_set_state.selected == 1
        @test handle!(radio_set_state, radio_set, KeyEvent(Key(:down)))
        @test radio_set_state.selected == 3
        @test selected_value(radio_set, radio_set_state) == :three

        radio_boxes = RadioBoxList([
            ChoiceOption(:one, "One"),
            ChoiceOption(:two, "Two"; disabled=true),
            ChoiceOption(:three, "Three"),
        ])
        radio_boxes_state = RadioBoxListState()
        @test RadioBoxListState === RadioGroupState
        @test render!(Buffer(1, 30), radio_boxes, Rect(1, 1, 1, 30), radio_boxes_state) isa Buffer
        @test render!(Buffer(1, 30), radio_boxes, Rect(1, 1, 1, 30)) isa Buffer
        @test handle!(radio_boxes_state, radio_boxes, KeyEvent(Key(:down)))
        @test radio_boxes_state.selected == 1
        @test handle!(radio_boxes_state, radio_boxes, KeyEvent(Key(:down)))
        @test radio_boxes_state.selected == 3
        @test selected_value(radio_boxes, radio_boxes_state) == :three

        radio_button = RadioButton(:enabled, "Enabled")
        radio_button_state = state_for(radio_button)
        @test render!(Buffer(1, 16), radio_button, Rect(1, 1, 1, 16), radio_button_state) isa Buffer
        @test render!(Buffer(1, 16), radio_button, Rect(1, 1, 1, 16)) isa Buffer
        @test handle!(radio_button_state, radio_button, KeyEvent(Key(:down)))
        @test selected_value(radio_button, radio_button_state) == :enabled
        @test handle!(radio_button_state, radio_button, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 1, 16))
        @test radio_button_state.selected == 1
    end

    @testset "select interaction" begin
        widget = Select([
            ChoiceOption(:a, "A"),
            ChoiceOption(:b, "B"; disabled=true),
            ChoiceOption(:c, "C"),
        ])
        state = SelectState()

        @test handle!(state, widget, KeyEvent(Key(:enter)))
        @test state.open
        @test state.highlighted == 1
        @test handle!(state, widget, KeyEvent(Key(:down)))
        @test state.highlighted == 3
        @test !handle!(state, widget, KeyEvent(Key(:enter); kind=KeyRelease))
        @test state.open
        @test handle!(state, widget, KeyEvent(Key(:enter)))
        @test !state.open
        @test selected_value(widget, state) == :c

        disabled = SelectState(selected=2)
        @test selected_value(widget, disabled) === nothing
        @test !handle!(
            state,
            widget,
            MouseEvent(Position(1, 12), LeftMouseButton, MouseRelease),
            Rect(1, 1, 4, 10),
        )

        default_buffer = Buffer(1, 12)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("Select", plain_snapshot(default_buffer))

        combobox = Combobox([ChoiceOption(:debug, "Debug"), ChoiceOption(:release, "Release")])
        combobox_state = state_for(combobox)
        @test render!(Buffer(2, 16), combobox, Rect(1, 1, 2, 16), combobox_state) isa Buffer
        @test render!(Buffer(2, 16), combobox, Rect(1, 1, 2, 16)) isa Buffer
        @test handle!(combobox_state, combobox, KeyEvent(Key(:enter)))
        @test combobox_state.open
        @test handle!(combobox_state, combobox, KeyEvent(Key(:down)))
        @test combobox_state.highlighted == 2
        @test handle!(combobox_state, combobox, KeyEvent(Key(:enter)))
        @test selected_value(combobox, combobox_state) == :release
    end

    @testset "multiselect interaction" begin
        widget = MultiSelect([
            ChoiceOption(:a, "A"),
            ChoiceOption(:b, "B"; disabled=true),
            ChoiceOption(:c, "C"),
        ])
        state = MultiSelectState(selected=[1, 2, 99])
        @test selected_values(widget, state) == [:a]

        @test handle!(state, widget, KeyEvent(Key(:down)); viewport_height=2)
        @test state.highlighted == 1
        @test handle!(state, widget, KeyEvent(Key(:down)); viewport_height=2)
        @test state.highlighted == 3
        @test handle!(state, widget, KeyEvent(Key(:character); text=" "))
        @test selected_values(widget, state) == [:a, :c]
        @test !handle!(
            state,
            widget,
            MouseEvent(Position(1, 8), LeftMouseButton, MouseRelease),
            Rect(1, 1, 3, 7),
        )

        default_buffer = Buffer(3, 12)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("[ ] A", plain_snapshot(default_buffer))

        selection_list = SelectionList([
            ChoiceOption(:a, "A"),
            ChoiceOption(:b, "B"; disabled=true),
            ChoiceOption(:c, "C"),
        ])
        selection_list_state = SelectionListState(selected=[1])
        @test SelectionListState === MultiSelectState
        @test render!(Buffer(3, 12), selection_list, Rect(1, 1, 3, 12), selection_list_state) isa Buffer
        @test render!(Buffer(3, 12), selection_list, Rect(1, 1, 3, 12)) isa Buffer
        @test handle!(selection_list_state, selection_list, KeyEvent(Key(:down)); viewport_height=2)
        @test handle!(selection_list_state, selection_list, KeyEvent(Key(:down)); viewport_height=2)
        @test handle!(selection_list_state, selection_list, KeyEvent(Key(:character); text=" "))
        @test selected_values(selection_list, selection_list_state) == [:a, :c]

        checkbox_list = CheckBoxList([
            ChoiceOption(:a, "A"),
            ChoiceOption(:b, "B"; disabled=true),
            ChoiceOption(:c, "C"),
        ])
        checkbox_list_state = CheckBoxListState(selected=[1])
        @test CheckBoxListState === MultiSelectState
        @test render!(Buffer(3, 12), checkbox_list, Rect(1, 1, 3, 12), checkbox_list_state) isa Buffer
        @test render!(Buffer(3, 12), checkbox_list, Rect(1, 1, 3, 12)) isa Buffer
        @test handle!(checkbox_list_state, checkbox_list, KeyEvent(Key(:down)); viewport_height=2)
        @test handle!(checkbox_list_state, checkbox_list, KeyEvent(Key(:down)); viewport_height=2)
        @test handle!(checkbox_list_state, checkbox_list, KeyEvent(Key(:character); text=" "))
        @test selected_values(checkbox_list, checkbox_list_state) == [:a, :c]

        transfer = TransferList([
            ChoiceOption(:left, "Left"),
            ChoiceOption(:right, "Right"),
        ])
        transfer_state = state_for(transfer)
        @test render!(Buffer(2, 16), transfer, Rect(1, 1, 2, 16), transfer_state) isa Buffer
        @test render!(Buffer(2, 16), transfer, Rect(1, 1, 2, 16)) isa Buffer
        @test handle!(transfer_state, transfer, KeyEvent(Key(:down)); viewport_height=2)
        @test handle!(transfer_state, transfer, KeyEvent(Key(:character); text=" "))
        @test selected_values(transfer, transfer_state) == [:left]
        @test handle!(transfer_state, transfer, MouseEvent(Position(2, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 2, 16))
        @test selected_values(transfer, transfer_state) == [:left, :right]
    end

    @testset "number input editing and validation" begin
        @test NumericInput() isa NumberInput

        widget = NumberInput()
        state = NumberInputState(
            minimum=0.0,
            maximum=10.0,
            step=0.5,
            allow_empty=false,
        )

        @test state.value === nothing
        @test !state.valid
        @test handle!(state, widget, KeyEvent(Key(:character); text="7"))
        @test state.valid
        @test state.value == 7.0
        @test handle!(state, widget, KeyEvent(Key(:up)))
        @test state.value == 7.5
        @test handle!(state, widget, KeyEvent(Key(:down); modifiers=SHIFT))
        @test state.value == 2.5

        clamped_state = NumberInputState(value=9.8, minimum=0.0, maximum=10.0, step=0.5)
        clamped_widget = NumberInput()
        @test handle!(clamped_state, clamped_widget, KeyEvent(Key(:up)))
        @test clamped_state.value == 10.0
        @test handle!(clamped_state, clamped_widget, KeyEvent(Key(:up)))
        @test clamped_state.value == 10.0

        pasted_state = NumberInputState()
        @test handle!(pasted_state, widget, PasteEvent("xyz"))
        @test !pasted_state.valid
        @test pasted_state.value === nothing

        render_state = NumberInputState(value=12)
        render_buffer = Buffer(1, 8)
        render_widget = NumberInput(placeholder="n/a")
        @test render!(render_buffer, render_widget, render_buffer.area, render_state) === render_buffer
        @test render_buffer[1, 1].grapheme == "1"

        empty_state = NumberInputState()
        empty_buffer = Buffer(1, 8)
        render_placeholder = render!(empty_buffer, render_widget, empty_buffer.area, empty_state)
        @test render_placeholder === empty_buffer
        @test empty_buffer[1, 1].grapheme == "n"
        @test handle!(
            empty_state,
            render_widget,
            MouseEvent(Position(1, 2), LeftMouseButton, MousePress),
            Rect(1, 1, 1, 8),
        )
        @test empty_state.focused
    end

    @testset "search input supports query editing and paste" begin
        widget = SearchInput(placeholder="Find")
        state = SearchInputState()

        @test editing_text(state) == ""
        @test handle!(state, widget, KeyEvent(Key(:character); text="a"))
        @test handle!(state, widget, KeyEvent(Key(:character); text="b"))
        @test editing_text(state) == "ab"
        @test handle!(state, widget, KeyEvent(Key(:backspace)))
        @test editing_text(state) == "a"
        @test handle!(state, widget, PasteEvent("bc"))
        @test editing_text(state) == "abc"

        query_buffer = Buffer(1, 8)
        query_widget = SearchInput(placeholder="Find")
        @test render!(query_buffer, query_widget, query_buffer.area, state) === query_buffer
        @test query_buffer[1, 1].grapheme == "a"
        @test handle!(
            state,
            query_widget,
            MouseEvent(Position(1, 2), LeftMouseButton, MousePress),
            Rect(1, 1, 1, 8),
        )
        @test state.focused
    end
end
