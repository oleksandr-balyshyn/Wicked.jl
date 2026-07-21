@testset "Selection widgets" begin
    @testset "list navigation and viewport" begin
        widget = List(["one", "two", "three", "four"])
        state = ListState()

        @test handle!(state, widget, KeyEvent(Key(:down)); viewport_height=2)
        @test state.selected == 1
        @test !handle!(state, widget, KeyEvent(Key(:down); kind=KeyRelease))
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:page_down)); viewport_height=2)
        @test state.selected == 3
        @test state.offset == 1

        buffer = Buffer(2, 8)
        render!(buffer, widget, buffer.area, state)
        @test sprint(show, MIME"text/plain"(), buffer) ==
              "Buffer(2x8, origin=(1, 1))\n  two   \n› three "
        default_buffer = Buffer(2, 8)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("one", plain_snapshot(default_buffer))

        outside = MouseEvent(Position(1, 9), LeftMouseButton, MouseRelease)
        @test !handle!(state, widget, outside, Rect(1, 1, 2, 8))
        inside = MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease)
        @test handle!(state, widget, inside, Rect(1, 1, 2, 8))
        @test state.selected == 2

        list_view = ListView(["one", "two", "three"])
        list_view_state = state_for(list_view)
        @test ListViewState === ListState
        @test render!(Buffer(2, 8), list_view, Rect(1, 1, 2, 8), list_view_state) isa Buffer
        @test render!(Buffer(2, 8), list_view, Rect(1, 1, 2, 8)) isa Buffer
        @test handle!(list_view_state, list_view, KeyEvent(Key(:down)); viewport_height=2)
        @test list_view_state.selected == 1
        @test handle!(list_view_state, list_view, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 2, 8))
        @test list_view_state.selected == 1

        option_list = OptionList(["one", "two", "three"])
        option_list_state = state_for(option_list)
        @test OptionListState === ListState
        @test render!(Buffer(2, 8), option_list, Rect(1, 1, 2, 8), option_list_state) isa Buffer
        @test render!(Buffer(2, 8), option_list, Rect(1, 1, 2, 8)) isa Buffer
        @test handle!(option_list_state, option_list, KeyEvent(Key(:down)); viewport_height=2)
        @test option_list_state.selected == 1

        list_box = ListBox(["one", "two", "three"])
        list_box_state = state_for(list_box)
        @test render!(Buffer(2, 8), list_box, Rect(1, 1, 2, 8), list_box_state) isa Buffer
        @test render!(Buffer(2, 8), list_box, Rect(1, 1, 2, 8)) isa Buffer
        @test handle!(list_box_state, list_box, KeyEvent(Key(:down)); viewport_height=2)
        @test list_box_state.selected == 1
        @test handle!(list_box_state, list_box, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease), Rect(1, 1, 2, 8))
        @test list_box_state.selected == 1
    end

    @testset "table row and column selection" begin
        widget = Table(
            [TableColumn("A"; constraint=Length(3)), TableColumn("B"; constraint=Fill())],
            [["a1", "b1"], ["a2", "b2"], ["a3", "b3"]];
            column_gap=1,
        )
        state = TableState()
        @test handle!(state, widget, KeyEvent(Key(:down)); viewport_height=1)
        @test state.selected_row == 1
        @test handle!(state, widget, KeyEvent(Key(:right)))
        @test state.selected_column == 1
        @test !handle!(state, widget, KeyEvent(Key(:right); kind=KeyRelease))

        click = MouseEvent(Position(3, 6), LeftMouseButton, MouseRelease)
        @test handle!(state, widget, click, Rect(1, 1, 4, 10))
        @test state.selected_row == 2
        @test state.selected_column == 2

        buffer = Buffer(3, 10)
        render!(buffer, widget, buffer.area, state)
        @test state.row_offset == 0
        @test buffer[3, 1].grapheme == "a"
        default_buffer = Buffer(3, 10)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("A", plain_snapshot(default_buffer))
    end

    @testset "tabs keyboard and mouse" begin
        widget = Tabs([Tab(:one, "One"), Tab(:two, "Two"), Tab(:three, "Three")])
        state = TabsState(1)

        @test handle!(state, widget, KeyEvent(Key(:left)))
        @test state.selected == 3
        @test handle!(state, widget, KeyEvent(Key(:right)))
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:home)))
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:page_down)); page_size=2)
        @test state.selected == 3
        @test handle!(state, widget, KeyEvent(Key(:page_up)); page_size=2)
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:enter)))
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:character); text=" "))
        @test state.selected == 1
        @test handle!(
            state,
            widget,
            MouseEvent(Position(1, 8), LeftMouseButton, MouseRelease),
            Rect(1, 1, 1, 20),
        )
        @test state.selected == 2
        @test !handle!(
            state,
            widget,
            MouseEvent(Position(1, 5), LeftMouseButton, MouseRelease),
            Rect(1, 1, 1, 20),
        )
        default_buffer = Buffer(1, 20)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("One", plain_snapshot(default_buffer))
    end

    @testset "tree expansion and mouse" begin
        widget = Tree([
            TreeNode(:root, "Root"; children=[
                TreeNode(:first, "First"),
                TreeNode(:second, "Second"),
            ]),
        ])
        state = TreeState()

        @test handle!(state, widget, KeyEvent(Key(:right)); viewport_height=3)
        @test :root in state.expanded
        @test handle!(state, widget, KeyEvent(Key(:right)); viewport_height=3)
        @test state.selected == :first
        @test handle!(state, widget, KeyEvent(Key(:left)); viewport_height=3)
        @test state.selected == :root

        click = MouseEvent(Position(1, 1), LeftMouseButton, MouseRelease)
        @test handle!(state, widget, click, Rect(1, 1, 3, 12))
        @test !(:root in state.expanded)

        default_buffer = Buffer(3, 12)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("Root", plain_snapshot(default_buffer))

        tree_view = TreeView([
            TreeNode(:root, "Root"; children=[
                TreeNode(:first, "First"),
            ]),
        ])
        tree_view_state = state_for(tree_view)
        @test TreeViewState === TreeState
        @test handle!(tree_view_state, tree_view, KeyEvent(Key(:right)); viewport_height=3)
        @test :root in tree_view_state.expanded
        @test render!(Buffer(3, 12), tree_view, Rect(1, 1, 3, 12), tree_view_state) isa Buffer
        @test render!(Buffer(3, 12), tree_view, Rect(1, 1, 3, 12)) isa Buffer
    end

    @testset "menu disabled items and activation" begin
        widget = Menu([
            MenuItem(:open, "Open", :open_message),
            MenuItem(:save, "Save", :save_message; disabled=true),
            MenuItem(:quit, "Quit", :quit_message),
        ])
        state = MenuState()

        @test handle!(state, widget, KeyEvent(Key(:down)); viewport_height=2)
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:down)); viewport_height=2)
        @test state.selected == 3
        @test activate(widget, state) == :quit_message

        state.offset = 0
        disabled = MouseEvent(Position(2, 2), LeftMouseButton, MouseRelease)
        @test !handle!(state, widget, disabled, Rect(1, 1, 3, 10))
        enabled = MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease)
        @test handle!(state, widget, enabled, Rect(1, 1, 3, 10))
        @test activate(widget, state) == :open_message

        @test handle!(state, widget, KeyEvent(Key(:page_down)); viewport_height=1)
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:home)))
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:end)))
        @test state.selected == 3
        @test handle!(state, widget, KeyEvent(Key(:page_up)); viewport_height=1)
        @test state.selected == 1
        @test handle!(state, widget, KeyEvent(Key(:enter)))
        @test state.selected == 1
        @test activate(widget, state) == :open_message

        state.selected = 2
        @test handle!(state, widget, KeyEvent(Key(:character); text=" "))
        @test state.selected == 3
        @test activate(widget, state) == :quit_message

        default_buffer = Buffer(3, 12)
        @test render!(default_buffer, widget, default_buffer.area) === default_buffer
        @test occursin("Open", plain_snapshot(default_buffer))
    end

    @testset "list highlight spacing policies" begin
        items = ["a", "bb", "ccc"]

        # :always (default) reserves the selection gutter on every row, even
        # when nothing is selected.
        always = List(items; highlight_symbol=">>")
        b1 = Buffer(3, 6)
        render!(b1, always, b1.area, ListState())
        @test plain_snapshot(b1) == "  a\n  bb\n  ccc"

        # :never never reserves the gutter; selection shows through style only.
        never = List(items; highlight_symbol=">>", highlight_spacing=:never)
        b2 = Buffer(3, 6)
        render!(b2, never, b2.area, ListState(selected=1))
        @test plain_snapshot(b2) == "a\nbb\nccc"

        # :when_selected reserves the gutter only while an item is selected.
        ws = List(items; highlight_symbol=">>", highlight_spacing=:when_selected)
        b3 = Buffer(3, 6)
        render!(b3, ws, b3.area, ListState())
        @test plain_snapshot(b3) == "a\nbb\nccc"
        b4 = Buffer(3, 6)
        render!(b4, ws, b4.area, ListState(selected=2))
        @test plain_snapshot(b4) == "  a\n>>bb\n  ccc"
    end

    @testset "list scroll padding keeps context rows" begin
        items = string.(1:10)
        padded = List(items; scroll_padding=1)
        plain = List(items)
        area = Rect(1, 1, 5, 4)

        # Viewport of 5 rows, selecting item 5 from the top. Without padding the
        # item still fits, so the offset stays put.
        st0 = ListState(selected=5, offset=0)
        render!(Buffer(5, 4), plain, area, st0)
        @test st0.offset == 0

        # With padding 1 the selection must retain a trailing context row, so the
        # viewport scrolls one line.
        stp = ListState(selected=5, offset=0)
        render!(Buffer(5, 4), padded, area, stp)
        @test stp.offset == 1

        # Padding also applies above the selection when scrolling upward.
        stup = ListState(selected=6, offset=5)
        render!(Buffer(5, 4), padded, area, stup)
        @test stup.offset == 4

        # Padding is clamped to what the viewport can hold and never traps the
        # selection off-screen.
        wide = List(items; scroll_padding=100)
        stw = ListState(selected=8, offset=0)
        render!(Buffer(5, 4), wide, area, stw)
        @test stw.offset in 0:5
        @test stw.offset < 8
        @test stw.offset + 5 >= 8
    end

    @testset "table scroll padding keeps context rows" begin
        cols = ["A"]
        rows = [[string(i)] for i in 1:10]
        plain = Table(cols, rows; show_header=false)
        padded = Table(cols, rows; show_header=false, scroll_padding=1)
        area = Rect(1, 1, 5, 6)

        # Selecting row 5 in a 5-row viewport fits without padding.
        s0 = TableState(selected_row=5, row_offset=0)
        render!(Buffer(5, 6), plain, area, s0)
        @test s0.row_offset == 0

        # Padding 1 forces a trailing context row, scrolling one line.
        sp = TableState(selected_row=5, row_offset=0)
        render!(Buffer(5, 6), padded, area, sp)
        @test sp.row_offset == 1

        # Padding also applies above the selection.
        sup = TableState(selected_row=6, row_offset=5)
        render!(Buffer(5, 6), padded, area, sup)
        @test sup.row_offset == 4
    end

    @testset "invalid states" begin
        @test_throws ArgumentError ListState(selected=0)
        @test_throws ArgumentError TableState(row_offset=-1)
        @test_throws ArgumentError TabsState(0)
        @test_throws ArgumentError Tree(TreeNode[]; indent=-1)
        @test_throws ArgumentError MenuState(offset=-1)
        @test_throws ArgumentError List(["a"]; scroll_padding=-1)
        @test_throws ArgumentError List(["a"]; highlight_spacing=:sideways)
        @test_throws ArgumentError Table(["A"], [["1"]]; scroll_padding=-1)
    end
end
