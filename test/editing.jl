@testset "Editing and text input" begin
    @testset "grapheme editing and history" begin
        buffer = EditingBuffer("a界e\u0301"; history_limit=2)
        @test length(buffer) == 3
        @test buffer.cursor == 3

        @test move_cursor!(buffer, 1)
        @test insert!(buffer, "🙂")
        @test editing_text(buffer) == "a🙂界e\u0301"
        @test backspace!(buffer)
        @test editing_text(buffer) == "a界e\u0301"
        @test undo!(buffer)
        @test editing_text(buffer) == "a🙂界e\u0301"
        @test redo!(buffer)
        @test editing_text(buffer) == "a界e\u0301"

        select_all!(buffer)
        @test insert!(buffer, "xy"; maximum_length=2)
        @test editing_text(buffer) == "xy"
        @test !redo!(buffer)
        @test_throws ArgumentError EditingBuffer(""; history_limit=-1)
    end

    @testset "selection and movement" begin
        buffer = EditingBuffer("one two\nxy")
        move_cursor!(buffer, 0)
        editing_state = TextAreaState(buffer, 0, 0, true)
        @test handle!(
            editing_state,
            TextArea(),
            KeyEvent(Key(:right); modifiers=CTRL),
        )
        @test buffer.cursor == 3

        @test move_cursor!(buffer, 7; extend=true)
        @test buffer.anchor == 3
        @test delete_forward!(buffer)
        @test editing_text(buffer) == "one\nxy"

        set_text!(buffer, "ab\ncde"; record=false)
        move_cursor!(buffer, 2)
        state = TextAreaState(buffer, 0, 0, true)
        @test handle!(state, TextArea(), KeyEvent(Key(:down)))
        @test buffer.cursor == 5
        @test handle!(state, TextArea(), KeyEvent(Key(:up)))
        @test buffer.cursor == 2
    end

    @testset "key kinds and single-line normalization" begin
        widget = TextInput(maximum_length=10)
        state = TextInputState("a\r\nb"; focused=true)
        @test editing_text(state.editing) == "a b"

        release = KeyEvent(Key(:character); text="x", kind=KeyRelease)
        @test !handle!(state, widget, release)
        @test editing_text(state.editing) == "a b"

        @test handle!(state, widget, KeyEvent(Key(:character); text="x\ny"))
        @test editing_text(state.editing) == "a bx y"
        @test handle!(state, widget, PasteEvent("z\r\nq"))
        @test editing_text(state.editing) == "a bx yz q"

        limited = TextInputState("abc")
        @test handle!(limited, TextInput(maximum_length=5), PasteEvent("wxyz"))
        @test editing_text(limited.editing) == "abcwx"
        @test !handle!(limited, TextInput(maximum_length=5), PasteEvent("q"))

        set_text!(state, "left\rright"; record=false)
        @test editing_text(state.editing) == "left right"
        @test state.horizontal_offset == 0

        input = Input(maximum_length=5)
        input_state = InputState("abc")
        @test InputState === TextInputState
        @test handle!(input_state, input, PasteEvent("wxyz"))
        @test editing_text(input_state.editing) == "abcwx"

        textbox = TextBox(maximum_length=5)
        textbox_state = TextBoxState("abc")
        @test TextBoxState === TextInputState
        @test handle!(textbox_state, textbox, PasteEvent("wxyz"))
        @test editing_text(textbox_state.editing) == "abcwx"

        field = TextField(maximum_length=5)
        field_state = TextFieldState("abc")
        @test TextFieldState === TextInputState
        @test handle!(field_state, field, PasteEvent("wxyz"))
        @test editing_text(field_state.editing) == "abcwx"
    end

    @testset "wide cursor placement and scrolling" begin
        input = TextInputState("界a"; focused=true)
        frame = Frame(Buffer(1, 4))
        render!(frame, TextInput(), frame.area, input)
        @test frame.cursor !== nothing
        @test frame.cursor.position == Position(1, 4)

        area_state = TextAreaState("界a"; focused=true)
        area_frame = Frame(Buffer(1, 4))
        render!(area_frame, TextArea(), area_frame.area, area_state)
        @test area_frame.cursor !== nothing
        @test area_frame.cursor.position == Position(1, 4)

        narrow_state = TextAreaState("界a"; focused=true)
        narrow_frame = Frame(Buffer(1, 3))
        render!(narrow_frame, TextArea(), narrow_frame.area, narrow_state)
        @test narrow_state.horizontal_offset == 1
        @test narrow_frame.cursor.position == Position(1, 2)
        @test narrow_frame.buffer[1, 1] == Cell("a")
    end

    @testset "rendering and masks" begin
        placeholder = Buffer(1, 8)
        render!(placeholder, TextInput(placeholder="name"), placeholder.area, TextInputState())
        @test [placeholder[1, index].grapheme for index in 1:4] == ["n", "a", "m", "e"]

        default_input = Buffer(1, 8)
        @test render!(default_input, TextInput(placeholder="name"), default_input.area) === default_input
        @test [default_input[1, index].grapheme for index in 1:4] == ["n", "a", "m", "e"]

        default_compat_input = Buffer(1, 8)
        @test render!(default_compat_input, Input(placeholder="name"), default_compat_input.area) === default_compat_input
        @test [default_compat_input[1, index].grapheme for index in 1:4] == ["n", "a", "m", "e"]

        default_textbox = Buffer(1, 8)
        @test render!(default_textbox, TextBox(placeholder="name"), default_textbox.area) === default_textbox
        @test [default_textbox[1, index].grapheme for index in 1:4] == ["n", "a", "m", "e"]

        default_area = Buffer(2, 8)
        @test render!(default_area, TextArea(show_line_numbers=true), default_area.area) === default_area
        @test default_area[1, 1].grapheme == "1"

        password = Buffer(1, 4)
        render!(password, PasswordInput(), password.area, TextInputState("ab"))
        @test password[1, 1].grapheme == "•"
        @test password[1, 2].grapheme == "•"
        @test state_for(PasswordInput()) isa TextInputState
        password_field = Buffer(1, 4)
        render!(password_field, PasswordField(), password_field.area, PasswordFieldState("ab"))
        @test password_field[1, 1].grapheme == "•"
        @test password_field[1, 2].grapheme == "•"
        @test PasswordFieldState === TextInputState
        @test state_for(PasswordField()) isa TextInputState
        @test_throws ArgumentError TextInput(mask="界")
        @test_throws ArgumentError PasswordInput(mask="界")
        @test_throws ArgumentError PasswordField(mask="界")
        @test_throws ArgumentError TextInput(maximum_length=-1)
    end

    @testset "pointer cursor placement" begin
        input = TextInputState("a界b")
        input_widget = TextInput()
        @test handle!(
            input,
            input_widget,
            MouseEvent(Position(1, 4), LeftMouseButton, MousePress),
            Rect(1, 1, 1, 6),
        )
        @test input.editing.cursor == 2
        @test input.focused
        @test handle!(
            input,
            input_widget,
            MouseEvent(Position(1, 6), LeftMouseButton, MousePress),
            Rect(1, 1, 1, 6),
        )
        @test input.editing.cursor == 3
        @test !handle!(
            input,
            input_widget,
            MouseEvent(Position(2, 1), LeftMouseButton, MousePress),
            Rect(1, 1, 1, 6),
        )

        area = TextAreaState("one\n界x")
        area_widget = TextArea(show_line_numbers=true)
        @test handle!(
            area,
            area_widget,
            MouseEvent(Position(2, 5), LeftMouseButton, MousePress),
            Rect(1, 1, 3, 10),
        )
        @test area.editing.cursor == 5
        @test area.focused
        @test handle!(
            area,
            area_widget,
            MouseEvent(Position(2, 1), LeftMouseButton, MousePress),
            Rect(1, 1, 3, 10),
        )
        @test area.editing.cursor == 4
        @test !handle!(
            area,
            area_widget,
            MouseEvent(Position(2, 5), LeftMouseButton, MouseRelease),
            Rect(1, 1, 3, 10),
        )
    end
end
