struct ReconciliationWidget
    label::String
end

struct ReplacementReconciliationWidget
    label::String
end

struct FailingReconciliationWidget end

struct PartialFailingReconciliationWidget end

struct InvalidationToolkitApp <: ToolkitApp end

Wicked.Toolkit.toolkit_view(::InvalidationToolkitApp, model) =
    component(state -> "Value: $(component_value(state))"; initial=0, id=:runtime_component)

Wicked.render!(::Frame, ::FailingReconciliationWidget, ::Rect) =
    error("intentional component child render failure")

function Wicked.render!(frame::Frame, ::PartialFailingReconciliationWidget, area::Rect)
    Wicked.render!(frame, Label("partial"), area)
    error("intentional partial render failure")
end

function Wicked.render!(
    frame::Frame,
    widget::Union{ReconciliationWidget,ReplacementReconciliationWidget},
    area::Rect,
    state::Base.RefValue{Int},
)
    Wicked.render!(frame, Label(widget.label), area)
end

@testset "Toolkit keyed reconciliation and lifecycle" begin
    @testset "declarative composition normalizes leaves and child collections" begin
        tree = column(
            Label("Compose-style"),
            nothing,
            [
                element(Button("Save", :save); key=:save, id=:save, focusable=true),
                Label("Ready"),
            ],
            (Label("One"), Label("Two"));
            constraints=[Length(1), Length(1), Length(1), Length(1), Length(1)],
        )

        @test tree isa Element
        @test length(tree.children) == 5
        @test all(child -> child isa Element, tree.children)
        @test tree.children[1].widget isa Label
        @test tree.children[2].key == :save
        @test tree.children[2].focusable

        existing = element(Label("Existing"); key=:existing)
        @test element(existing) === existing
        @test_throws ArgumentError element(existing; key=:replacement)

        interactive = element_modifier(
            focusable=true,
            classes=[:interactive],
            tab_index=2,
            on_capture=(event, state) -> nothing,
        )
        identified = ElementModifier(id=:save, key=:save, style_role=:primary)
        enabled = ElementModifier(disabled=false, tab_index=3)
        composed = then(interactive, identified, enabled)
        @test composed isa ElementModifier
        @test composed.properties.tab_index == 3
        @test_throws ArgumentError ElementModifier(unsupported=true)

        modified = element(
            Button("Modified", :modified);
            disabled=true,
            modifier=composed,
        )
        @test modified.id == :save
        @test modified.key == :save
        @test modified.focusable
        @test !modified.disabled
        @test modified.tab_index == 3
        @test modified.classes == Set([:interactive])
        @test modified.style_role == :primary
        @test modified.on_capture === interactive.properties.on_capture
        @test modify(modified) === modified

        remapped = element(modified; modifier=ElementModifier(id=:remapped, hidden=true))
        @test remapped.widget === modified.widget
        @test remapped.id == :remapped
        @test remapped.hidden
        @test remapped.key == :save

        modified_layout = row(
            "left",
            "right";
            modifier=ElementModifier(id=:modified_row, classes=[:layout]),
        )
        @test modified_layout.id == :modified_row
        @test modified_layout.classes == Set([:layout])
        @test length(modified_layout.children) == 2

        group = fragment((Label(string(index)) for index in 1:3))
        @test length(group.children) == 3
        @test all(child -> child.widget isa Label, group.children)

        buffer = Buffer(5, 24)
        render_toolkit!(Frame(buffer), ToolkitTree(tree))
        @test buffer[1, 1].grapheme == "C"

        show_cancel = false
        declarative = @ui column(; key=:root) do
            Label("Nested DSL")
            row(; gap=1) do
                element(Button("Save", :save); key=:save, id=:save, focusable=true)
                show_cancel ? element(Button("Cancel", :cancel); key=:cancel) : nothing
            end
            fragment() do
                (Label("item $index") for index in 1:2)
            end
        end
        @test declarative.key == :root
        @test length(declarative.children) == 3
        @test declarative.children[2].layout isa FlexLayout
        @test length(declarative.children[2].children) == 1
        @test isnothing(declarative.children[3].widget)
        @test length(declarative.children[3].children) == 2
        @test all(child -> child.widget isa Label, declarative.children[3].children)

        immediate_buffer = Buffer(4, 20)
        render!(immediate_buffer, declarative, immediate_buffer.area)
        @test immediate_buffer[1, 1].grapheme == "N"

        @test_throws LoadError eval(:(@ui row() do value
            Label(string(value))
        end))
    end

    @testset "retained validation and flex geometry caches" begin
        nested = column(
            element(Label("Alpha"); id=:alpha),
            element(Label("界"); id=:unicode);
            key=:nested,
            id=:nested,
            constraints=[Fill(1), Fill(1)],
        )
        root = column(
            nested,
            element(Label("Tail"); id=:tail);
            constraints=[Fill(1), Fill(1)],
        )
        tree = ToolkitTree(root)
        frame = Frame(Buffer(6, 20))
        render_toolkit!(frame, tree)
        @test element_instance(tree, :nested).area.height == 3
        @test element_instance(tree, :alpha).area.height == 2

        root.layout.constraints[1] = Length(1)
        render_toolkit!(frame, tree)
        @test element_instance(tree, :nested).area.height == 1
        @test element_instance(tree, :alpha).area.height == 1
        @test element_instance(tree, :unicode).area.height == 0

        render_toolkit!(frame, tree, Rect(1, 1, 4, 20))
        @test element_instance(tree, :tail).area.height == 3

        tree.root = column(element(Label("Only"); id=:only); constraints=[Fill(1)])
        render_toolkit!(frame, tree)
        @test length(tree.state.flex_area_cache) == 1
        @test element_instance(tree, :only).area == frame.area

        duplicate = column(
            element(Label("One"); key=:same),
            element(Label("Two"); key=:same),
        )
        tree.root = duplicate
        @test_throws ArgumentError render_toolkit!(frame, tree)
    end

    @testset "declarative focus requesters" begin
        requester = FocusRequester()
        unattached = FocusRequester()
        requested = focus_requester(Label("Focusable"), requester)
        @test requested.focusable
        @test requested.id === requester
        @test focus_requester_target(requester) === requester
        @test !request_focus!(ToolkitTree(requested), unattached)

        tree = ToolkitTree(column(
            element(Label("Initially focused"); id=:initial, focusable=true),
            requested;
            constraints=[Length(1), Length(1)],
        ))
        render_toolkit!(Frame(Buffer(2, 16)), tree)
        @test focused(tree.state.focus) == :initial
        @test !focus_requester_focused(tree, requester)
        @test request_focus!(tree, requester)
        @test focus_requester_focused(tree.state, requester)
        @test toolkit_invalidated(tree)
        clear_toolkit_invalidation!(tree)
        @test request_focus!(tree, requester)
        @test !toolkit_invalidated(tree)
        @test release_focus!(tree, requester)
        @test !focus_requester_focused(tree, requester)
        @test toolkit_invalidated(tree)
        @test !release_focus!(tree, requester)

        identified = FocusRequester()
        identified_element = focus_requester(
            element(Label("Named"); id=:named),
            identified,
        )
        @test identified_element.id == :named
        @test focus_requester_target(identified) == :named
        identified_tree = ToolkitTree(identified_element)
        render_toolkit!(Frame(Buffer(1, 16)), identified_tree)
        @test request_focus!(identified_tree.state, identified)
        @test focused(identified_tree.state.focus) == :named
        @test_throws ArgumentError focus_requester(
            element(Label("Mismatch"); id=:actual),
            FocusRequester();
            target=:different,
        )

        disabled = FocusRequester()
        disabled_tree = ToolkitTree(focus_requester(
            element(Label("Disabled"); disabled=true),
            disabled,
        ))
        render_toolkit!(Frame(Buffer(1, 16)), disabled_tree)
        @test !request_focus!(disabled_tree, disabled)
    end

    @testset "root-to-target event capture" begin
        phases = Any[]
        capture(name) = (event, state) -> begin
            push!(phases, (name, event.phase, event.target, event.current))
            EventResponse(message=Symbol(name, :_capture))
        end
        bubble(name) = (event, state) -> begin
            push!(phases, (name, event.phase, event.target, event.current))
            EventResponse(message=Symbol(name, :_, lowercase(string(event.phase))))
        end
        target = element(
            Label("Target");
            id=:capture_target,
            focusable=true,
            on_event=bubble(:target),
        )
        parent = fragment(
            target;
            id=:capture_parent,
            on_capture=capture(:parent),
            on_event=bubble(:parent),
        )
        root = fragment(
            parent;
            id=:capture_root,
            on_capture=capture(:root),
            on_event=bubble(:root),
        )
        tree = ToolkitTree(root)
        render_toolkit!(Frame(Buffer(1, 16)), tree)
        @test focus!(tree.state.focus, :capture_target)
        routed = dispatch!(tree, KeyEvent(Key(:enter)))
        @test [entry[1:2] for entry in phases] == [
            (:root, CapturePhase),
            (:parent, CapturePhase),
            (:target, TargetPhase),
            (:parent, BubblePhase),
            (:root, BubblePhase),
        ]
        @test all(entry -> entry[3] == :capture_target, phases)
        @test [entry[4] for entry in phases] == [
            :capture_root,
            :capture_parent,
            :capture_target,
            :capture_parent,
            :capture_root,
        ]
        @test routed.messages == [
            :root_capture,
            :parent_capture,
            :target_targetphase,
            :parent_bubblephase,
            :root_bubblephase,
        ]

        stopped = Symbol[]
        stopped_tree = ToolkitTree(fragment(
            element(
                Button("Never", :never);
                id=:stopped_target,
                focusable=true,
                on_event=(event, state) -> push!(stopped, :target),
            );
            id=:stopped_root,
            on_capture=(event, state) -> begin
                push!(stopped, :capture)
                EventResponse(
                    consumed=true,
                    stop_propagation=true,
                    redraw=true,
                    message=:captured,
                )
            end,
            on_event=(event, state) -> push!(stopped, :bubble),
        ))
        render_toolkit!(Frame(Buffer(1, 16)), stopped_tree)
        @test focus!(stopped_tree.state.focus, :stopped_target)
        stopped_result = dispatch!(stopped_tree, KeyEvent(Key(:enter)))
        @test stopped_result.consumed
        @test stopped_result.redraw
        @test stopped_result.messages == [:captured]
        @test stopped == [:capture]
    end

    @testset "declarative normal and preview key input" begin
        observed = Any[]
        normal = key_input(
            element(Label("Editor"); id=:key_target, focusable=true);
            id=:key_normal,
            keys=(Key(:enter), :space),
            kinds=(KeyPress, KeyRepeat),
            modifiers=CTRL,
            label="Editor commands",
            on_key=(event, state) -> begin
                push!(observed, (:normal, event.key.code, state.events))
                :normal_key
            end,
        )
        preview = preview_key_input(
            normal;
            id=:key_preview,
            keys=:enter,
            kinds=KeyPress,
            modifiers=CTRL,
            on_key=event -> begin
                push!(observed, (:preview, event.key.code))
                :preview_key
            end,
        )
        tree = ToolkitTree(preview)
        render_toolkit!(Frame(Buffer(1, 16)), tree)
        @test focus!(tree.state.focus, :key_target)

        ignored = dispatch!(tree, KeyEvent(Key(:enter)))
        @test isempty(ignored.messages)
        @test isempty(observed)

        handled = dispatch!(tree, KeyEvent(Key(:enter); modifiers=CTRL))
        @test handled.messages == [:preview_key, :normal_key]
        @test observed == [(:preview, :enter), (:normal, :enter, UInt64(1))]
        preview_state = element_state(tree, :key_preview)
        normal_state = element_state(tree, :key_normal)
        @test preview_state.events == UInt64(1)
        @test normal_state.events == UInt64(1)
        @test preview_state.last_event.key == Key(:enter)

        repeated = dispatch!(
            tree,
            KeyEvent(Key(:space); modifiers=CTRL, kind=KeyRepeat),
        )
        @test repeated.messages == [:normal_key]
        @test normal_state.events == UInt64(2)

        preview_node = semantic_node(toolkit_semantic_tree(tree), "key_preview")
        @test preview_node.metadata[:key_input]
        @test preview_node.metadata[:preview]
        @test preview_node.metadata[:last_key] == :enter

        direct_tree = ToolkitTree(key_input(
            ;
            id=:direct_key,
            focusable=true,
            on_key=event -> :direct,
        ))
        render_toolkit!(Frame(Buffer(1, 8)), direct_tree)
        @test focus!(direct_tree.state.focus, :direct_key)
        @test dispatch!(direct_tree, KeyEvent(Key(:x))).messages == [:direct]

        stopped_tree = ToolkitTree(preview_key_input(
            element(
                Label("Never");
                id=:preview_stop_target,
                focusable=true,
                on_event=(event, state) -> error("stopped preview reached target"),
            );
            id=:preview_stop,
            on_key=event -> EventResponse(consumed=true, stop_propagation=true),
        ))
        render_toolkit!(Frame(Buffer(1, 8)), stopped_tree)
        @test focus!(stopped_tree.state.focus, :preview_stop_target)
        @test dispatch!(stopped_tree, KeyEvent(Key(:escape))).consumed
    end

    @testset "declarative normal and preview pointer input" begin
        observed = Any[]
        normal = pointer_input(
            element(Label("Canvas"); id=:pointer_target);
            id=:pointer_normal,
            actions=(MousePress, MouseDrag, MouseRelease),
            buttons=LeftMouseButton,
            modifiers=ALT,
            capture_on_press=true,
            label="Canvas pointer input",
            on_pointer=(event, state) -> begin
                push!(observed, (:normal, event.action, event.position, state.events))
                EventResponse(consumed=true, message=event.action)
            end,
        )
        preview = preview_pointer_input(
            normal;
            id=:pointer_preview,
            actions=MousePress,
            buttons=LeftMouseButton,
            modifiers=ALT,
            on_pointer=event -> begin
                push!(observed, (:preview, event.action))
                :preview_pointer
            end,
        )
        tree = ToolkitTree(preview)
        render_toolkit!(Frame(Buffer(1, 16)), tree)

        ignored = dispatch!(
            tree,
            MouseEvent(Position(1, 2), LeftMouseButton, MousePress),
        )
        @test isempty(ignored.messages)
        @test isempty(observed)
        @test !has_pointer_capture(tree)

        pressed = dispatch!(
            tree,
            MouseEvent(Position(1, 2), LeftMouseButton, MousePress; modifiers=ALT),
        )
        @test pressed.messages == [:preview_pointer, MousePress]
        @test pointer_capture_target(tree) == :pointer_normal
        normal_state = element_state(tree, :pointer_normal)
        preview_state = element_state(tree, :pointer_preview)
        @test normal_state.pressed
        @test normal_state.events == UInt64(1)
        @test preview_state.events == UInt64(1)

        dragged = dispatch!(
            tree,
            MouseEvent(Position(3, 5), LeftMouseButton, MouseDrag; modifiers=ALT),
        )
        @test dragged.messages == [MouseDrag]
        @test normal_state.events == UInt64(2)
        @test normal_state.last_event.position == Position(3, 5)
        @test has_pointer_capture(tree)

        released = dispatch!(
            tree,
            MouseEvent(Position(4, 6), LeftMouseButton, MouseRelease; modifiers=ALT),
        )
        @test released.messages == [MouseRelease]
        @test !normal_state.pressed
        @test normal_state.events == UInt64(3)
        @test !has_pointer_capture(tree)

        node = semantic_node(toolkit_semantic_tree(tree), "pointer_normal")
        @test node.metadata[:pointer_input]
        @test node.metadata[:capture_on_press]
        @test node.metadata[:last_action] == MouseRelease

        stopped_tree = ToolkitTree(preview_pointer_input(
            element(
                Label("Never");
                id=:pointer_stop_target,
                on_event=(event, state) -> error("stopped pointer preview reached target"),
            );
            id=:pointer_stop,
            on_pointer=event -> EventResponse(consumed=true, stop_propagation=true),
        ))
        render_toolkit!(Frame(Buffer(1, 8)), stopped_tree)
        @test dispatch!(
            stopped_tree,
            MouseEvent(Position(1, 1), LeftMouseButton, MousePress),
        ).consumed
        @test_throws ArgumentError preview_pointer_input(
            Label("Bad");
            capture_on_press=true,
            on_pointer=identity,
        )
    end

    @testset "lifecycle produced state" begin
        dependency = Ref(1)
        stale_gate = Channel{Nothing}(1)
        stale_publish = Ref{Union{Nothing,Bool}}(nothing)
        produced_ref = Ref{Union{Nothing,ProducedState}}(nothing)

        function produced_component()
            component(id=:produced_component) do state
                produced = produce_state!(state, :counter, 0, (dependency[],)) do publish, token, _, value
                    publish(value)
                    if value == 1
                        take!(stale_gate)
                        stale_publish[] = publish(:stale)
                    end
                end
                produced_ref[] = produced
                "Produced: $(produced_value(produced))"
            end
        end

        tree = ToolkitTree(produced_component())
        render_toolkit!(Frame(Buffer(1, 20)), tree)
        produced = produced_ref[]
        @test produced isa ProducedState
        for _ in 1:100
            produced_value(produced) == 1 && break
            yield()
        end
        @test produced_value(produced) == 1
        @test produced_version(produced) == UInt64(1)
        @test produced_running(produced)

        dependency[] = 2
        tree.root = produced_component()
        render_toolkit!(Frame(Buffer(1, 20)), tree)
        current = produced_ref[]
        @test current.remembered === produced.remembered
        @test current.task === produced.task
        put!(stale_gate, nothing)
        for _ in 1:100
            produced_succeeded(current) && stale_publish[] !== nothing && break
            yield()
        end
        @test produced_value(current) == 2
        @test stale_publish[] == false
        @test produced_status(current) == LaunchedSucceeded
        @test produced_succeeded(current)
        @test !produced_failed(current)
        @test produced_failure(current) === nothing
        @test produced_version(current) == UInt64(2)

        failed_ref = Ref{Union{Nothing,ProducedState}}(nothing)
        failed_component = component(id=:failed_producer) do state
            failed_ref[] = produce_state!(state, :failure, :initial) do publish
                publish(:started)
                error("producer failed")
            end
            "Failure"
        end
        failed_tree = ToolkitTree(failed_component)
        render_toolkit!(Frame(Buffer(1, 12)), failed_tree)
        for _ in 1:100
            produced_failed(failed_ref[]) && break
            yield()
        end
        @test produced_value(failed_ref[]) == :started
        @test produced_failed(failed_ref[])
        @test produced_status(failed_ref[]) == LaunchedFailed
        @test produced_failure(failed_ref[]) isa CapturedException

    end

    @testset "retained functional components and keyed effects" begin
        lifecycle = Any[]
        function counter_component()
            component(
                initial=0,
                key=:counter,
                id=:counter,
                focusable=true,
                on_event=(event, state) -> begin
                    event.phase == TargetPhase || return nothing
                    event.event isa KeyEvent || return nothing
                    event.event.key.code == :enter || return nothing
                    update_component_value!(+, state, 1)
                    return EventResponse(consumed=true, redraw=true)
                end,
                on_unmount=state -> push!(lifecycle, (:unmount, component_value(state))),
            ) do state
                count = component_value(state)
                if count < 2
                    use_effect!(state, :count, (count,)) do _
                        push!(lifecycle, (:setup, count))
                        return () -> push!(lifecycle, (:cleanup, count))
                    end
                end
                return column(
                    "Count: $count",
                    element(Label("retained"); key=:retained, id=:retained);
                    constraints=[Length(1), Length(1)],
                )
            end
        end

        tree = ToolkitTree(counter_component())
        first_buffer = Buffer(2, 20)
        render_toolkit!(Frame(first_buffer), tree)
        state = element_state(tree, :counter)
        @test state isa ComponentState
        @test component_value(state) == 0
        @test plain_snapshot(first_buffer) == "Count: 0\nretained"
        @test lifecycle == [(:setup, 0)]
        @test component_version(state) == 0
        @test !component_invalidated(state)
        @test !toolkit_invalidated(tree)

        dispatch_wakeups = Ref(0)
        tree.state.invalidator = () -> (dispatch_wakeups[] += 1)
        @test focus!(tree.state.focus, :counter)
        dispatched = dispatch!(tree, KeyEvent(Key(:enter)))
        @test dispatched.consumed
        @test dispatched.redraw
        @test dispatch_wakeups[] == 0
        @test component_version(state) == 1
        @test component_invalidated(state)
        @test toolkit_invalidated(tree)
        second_buffer = Buffer(2, 20)
        render_toolkit!(Frame(second_buffer), tree)
        @test !component_invalidated(state)
        @test !toolkit_invalidated(tree)
        @test component_value(state) == 1
        @test plain_snapshot(second_buffer) == "Count: 1\nretained"
        @test lifecycle == [(:setup, 0), (:cleanup, 0), (:setup, 1)]

        retained_child_state = element_state(tree, :retained)
        tree.root = counter_component()
        render_toolkit!(Frame(Buffer(2, 20)), tree)
        @test element_state(tree, :counter) === state
        @test element_state(tree, :retained) === retained_child_state
        @test lifecycle == [(:setup, 0), (:cleanup, 0), (:setup, 1)]

        set_component_value!(state, 2)
        @test component_version(state) == 2
        set_component_value!(state, 2)
        @test component_version(state) == 2
        render_toolkit!(Frame(Buffer(2, 20)), tree)
        @test lifecycle == [(:setup, 0), (:cleanup, 0), (:setup, 1), (:cleanup, 1)]
        @test isempty(state.effects)

        tree.root = element(Label("removed"); id=:replacement)
        render_toolkit!(Frame(Buffer(1, 20)), tree)
        @test (:unmount, 2) in lifecycle
        @test isempty(state.effects)

        invalid_state_component = component(identity; state_factory=() -> 1)
        @test_throws ArgumentError render_toolkit!(
            Frame(Buffer(1, 8)),
            ToolkitTree(invalid_state_component),
        )
        @test_throws ArgumentError component(identity; children=[Label("invalid")])
        @test_throws ArgumentError update_component_value!(identity, ComponentState(1), :extra)

        wakeups = Ref(0)
        tree.state.invalidator = () -> (wakeups[] += 1)
        invalidate_toolkit!(tree)
        @test wakeups[] == 1
        invalidate_toolkit!(tree)
        @test wakeups[] == 1
        clear_toolkit_invalidation!(tree)
        invalidate_toolkit!(tree)
        @test wakeups[] == 2
        clear_toolkit_invalidation!(tree)
        set_component_value!(state, 3)
        @test wakeups[] == 2
        standalone_state = ComponentState(:ready)
        invalidate_component!(standalone_state)
        @test component_invalidated(standalone_state)
        clear_component_invalidation!(standalone_state)
        @test !component_invalidated(standalone_state)

        ephemeral_lifecycle = Any[]
        ephemeral = component(initial=:ready, on_unmount=state -> push!(ephemeral_lifecycle, :unmount)) do state
            use_effect!(state, :resource) do
                push!(ephemeral_lifecycle, :setup)
                return () -> push!(ephemeral_lifecycle, :cleanup)
            end
            return "ephemeral"
        end
        render!(Buffer(1, 12), ephemeral, Rect(1, 1, 1, 12))
        @test ephemeral_lifecycle == [:setup, :unmount, :cleanup]

        committed_lifecycle = Symbol[]
        fail_child = Ref(true)
        committed = component(initial=nothing, key=:committed, id=:committed) do state
            use_effect!(state, :commit) do
                push!(committed_lifecycle, :setup)
                return () -> push!(committed_lifecycle, :cleanup)
            end
            return fail_child[] ? FailingReconciliationWidget() : "committed"
        end
        committed_tree = ToolkitTree(committed)
        @test_throws ErrorException render_toolkit!(Frame(Buffer(1, 12)), committed_tree)
        @test isempty(committed_lifecycle)
        fail_child[] = false
        render_toolkit!(Frame(Buffer(1, 12)), committed_tree)
        @test committed_lifecycle == [:setup]
        committed_tree.root = element(Label("removed"))
        render_toolkit!(Frame(Buffer(1, 12)), committed_tree)
        @test committed_lifecycle == [:setup, :cleanup]

        launched_dependency = Ref(1)
        launch_enabled = Ref(true)
        launched_ref = Ref{Any}(nothing)
        launch_events = Any[]
        function launched_view(state)
            if launch_enabled[]
                dependency = launched_dependency[]
                launched_ref[] = launched_effect!(state, :worker, (dependency,)) do token, _, value
                    push!(launch_events, (:start, value))
                    if value in (1, 4)
                        while !launched_task_cancelled(token)
                            yield()
                        end
                        push!(launch_events, (:cancel, value))
                    elseif value == 3
                        error("launched failure")
                    end
                end
            end
            return "launched"
        end
        launched_component() = component(launched_view; key=:launched, id=:launched)
        launched_tree = ToolkitTree(launched_component())
        render_toolkit!(Frame(Buffer(1, 12)), launched_tree)
        first_launched = launched_ref[]
        @test first_launched isa LaunchedTask
        @test timedwait(() -> (:start, 1) in launch_events, 2) == :ok
        @test launched_task_running(first_launched)

        launched_dependency[] = 2
        launched_tree.root = launched_component()
        render_toolkit!(Frame(Buffer(1, 12)), launched_tree)
        @test timedwait(() -> (:cancel, 1) in launch_events, 2) == :ok
        @test timedwait(() -> launched_task_succeeded(first_launched), 2) == :ok
        @test launched_task_generation(first_launched) == 2

        launched_dependency[] = 3
        launched_tree.root = launched_component()
        render_toolkit!(Frame(Buffer(1, 12)), launched_tree)
        @test timedwait(() -> launched_task_failed(first_launched), 2) == :ok
        @test launched_task_failure(first_launched) isa CapturedException

        launched_dependency[] = 4
        launched_tree.root = launched_component()
        render_toolkit!(Frame(Buffer(1, 12)), launched_tree)
        @test timedwait(() -> (:start, 4) in launch_events, 2) == :ok
        launch_enabled[] = false
        launched_tree.root = launched_component()
        render_toolkit!(Frame(Buffer(1, 12)), launched_tree)
        @test timedwait(() -> launched_task_status(first_launched) == LaunchedCancelled, 2) == :ok
        @test timedwait(() -> (:cancel, 4) in launch_events, 2) == :ok

        runtime_app = InvalidationToolkitApp()
        runtime_model = Wicked.Toolkit.initialize(runtime_app)
        runtime = ApplicationRuntime(
            runtime_app,
            runtime_model,
            Terminal(TestBackend(1, 20)),
            ChannelInputSource(),
        )
        render_toolkit!(Frame(Buffer(1, 20)), runtime_model.tree)
        runtime_state = element_state(runtime_model.tree, :runtime_component)
        runtime.running = true
        set_component_value!(runtime_state, 1)
        @test Base.n_avail(runtime.messages) == 1
        set_component_value!(runtime_state, 2)
        @test Base.n_avail(runtime.messages) == 1
        redraw_request = take!(runtime.messages)
        @test Wicked.Toolkit.update!(runtime_app, runtime_model, redraw_request) isa FrameCommand
        render_toolkit!(Frame(Buffer(1, 20)), runtime_model.tree)
        set_component_value!(runtime_state, 3)
        @test Base.n_avail(runtime.messages) == 1
        runtime.running = false

        reactive_runtime = ReactiveRuntime()
        reactive_count = Signal(1; runtime=reactive_runtime)
        cached_label = reactive_element(
            :reactive_counter,
            value -> "Reactive: $value",
            [reactive_count],
        )
        reactive_tree = ToolkitTree(reactive_component(cached_label; id=:reactive_component))
        reactive_buffer = Buffer(1, 20)
        render_toolkit!(Frame(reactive_buffer), reactive_tree)
        @test plain_snapshot(reactive_buffer) == "Reactive: 1"
        reactive_wakeups = Ref(0)
        reactive_tree.state.invalidator = () -> (reactive_wakeups[] += 1)
        transaction!(reactive_runtime) do
            set_signal!(reactive_count, 2)
            set_signal!(reactive_count, 3)
        end
        @test toolkit_invalidated(reactive_tree)
        @test reactive_wakeups[] == 1
        render_toolkit!(Frame(reactive_buffer), reactive_tree)
        @test plain_snapshot(reactive_buffer) == "Reactive: 3"
        reactive_tree.root = element(Label("removed"))
        render_toolkit!(Frame(reactive_buffer), reactive_tree)
        @test cached_label.disposed
        clear_toolkit_invalidation!(reactive_tree)
        set_signal!(reactive_count, 4)
        @test !toolkit_invalidated(reactive_tree)
    end

    @testset "commit side effects and updated remembered values" begin
        latest = Ref("first")
        show_side = Ref(true)
        events = Any[]
        updated_ref = Ref{Any}(nothing)
        function effect_suite_view(state)
            updated = remember_updated!(state, :latest, latest[])
            updated_ref[] = updated
            disposable_effect!(state, :subscriber) do
                push!(events, :setup)
                return () -> push!(events, (:cleanup, remembered_value(updated)))
            end
            if show_side[]
                side_effect!(state, :publish) do
                    push!(events, (:side, remembered_value(updated)))
                    return :ignored
                end
            end
            return remembered_value(updated)
        end
        effect_suite() = component(effect_suite_view; key=:effect_suite, id=:effect_suite)
        tree = ToolkitTree(effect_suite())
        buffer = Buffer(1, 16)
        render_toolkit!(Frame(buffer), tree)
        updated = updated_ref[]
        @test events == [:setup, (:side, "first")]
        @test remembered_version(updated) == 0

        latest[] = "second"
        tree.root = effect_suite()
        render_toolkit!(Frame(buffer), tree)
        @test updated_ref[] === updated
        @test remembered_value(updated) == "second"
        @test remembered_version(updated) == 1
        @test events == [:setup, (:side, "first"), (:side, "second")]

        show_side[] = false
        tree.root = effect_suite()
        render_toolkit!(Frame(buffer), tree)
        @test events == [:setup, (:side, "first"), (:side, "second")]
        tree.root = element(Label("removed"))
        render_toolkit!(Frame(buffer), tree)
        @test last(events) == (:cleanup, "second")

        failed_side_effects = Symbol[]
        fail = Ref(true)
        function failing_effect_view(state)
            side_effect!(state, :committed) do
                push!(failed_side_effects, :committed)
            end
            return fail[] ? FailingReconciliationWidget() : "recovered"
        end
        failing_effect() = component(failing_effect_view; key=:failing_effect)
        failing_tree = ToolkitTree(failing_effect())
        @test_throws ErrorException render_toolkit!(Frame(Buffer(1, 12)), failing_tree)
        @test isempty(failed_side_effects)
        fail[] = false
        failing_tree.root = failing_effect()
        render_toolkit!(Frame(Buffer(1, 12)), failing_tree)
        @test failed_side_effects == [:committed]

        duplicate_side = component() do state
            side_effect!(() -> nothing, state, :duplicate)
            side_effect!(() -> nothing, state, :duplicate)
            return nothing
        end
        @test_throws ArgumentError render_toolkit!(Frame(Buffer(1, 8)), ToolkitTree(duplicate_side))
    end

    @testset "generic value-backed selectable content" begin
        choice = Ref(:alpha)
        selected_messages = Any[]
        binding = state_binding(() -> choice[], value -> (choice[] = value))
        option(value, id) = selectable(
            row(string(value), "custom"; constraints=[Fill(1), Length(6)]);
            binding,
            value,
            id,
            label="Choose $(value)",
            on_select=selected -> begin
                push!(selected_messages, selected)
                return (:selected, selected)
            end,
        )
        tree = ToolkitTree(column(
            option(:alpha, :alpha_option),
            option(:beta, :beta_option);
            constraints=[Length(1), Length(1)],
        ))
        buffer = Buffer(2, 20)
        render_toolkit!(Frame(buffer), tree)
        alpha_state = element_state(tree, :alpha_option)
        beta_state = element_state(tree, :beta_option)
        @test alpha_state.selected
        @test !beta_state.selected

        @test focus!(tree.state.focus, :beta_option)
        result = dispatch!(tree, KeyEvent(Key(:enter)))
        @test result.consumed
        @test choice[] == :beta
        @test beta_state.selected
        @test result.messages == Any[(:selected, :beta)]
        render_toolkit!(Frame(buffer), tree)
        @test !alpha_state.selected
        @test beta_state.selected

        choice[] = :alpha
        render_toolkit!(Frame(buffer), tree)
        @test alpha_state.selected
        @test !beta_state.selected
        press = dispatch!(tree, MouseEvent(Position(2, 2), LeftMouseButton, MousePress))
        release = dispatch!(tree, MouseEvent(Position(2, 2), LeftMouseButton, MouseRelease))
        @test press.consumed && release.consumed
        @test choice[] == :beta
        @test selected_messages == Any[:beta, :beta]
        render_toolkit!(Frame(buffer), tree)

        alpha_node = semantic_node(toolkit_semantic_tree(tree), "alpha_option")
        beta_node = semantic_node(toolkit_semantic_tree(tree), "beta_option")
        @test alpha_node.role == RadioRole
        @test beta_node.role == RadioRole
        @test !alpha_node.state.selected
        @test beta_node.state.selected
        @test SelectSemanticAction in beta_node.actions

        text_choice = Ref("A")
        case_tree = ToolkitTree(selectable(
            Label("case-insensitive");
            binding=state_binding(() -> text_choice[], value -> (text_choice[] = value)),
            value="a",
            equals=(left, right) -> lowercase(left) == lowercase(right),
            id=:case_option,
        ))
        render_toolkit!(Frame(Buffer(1, 18)), case_tree)
        @test element_state(case_tree, :case_option).selected

        disabled_tree = ToolkitTree(selectable(
            Label("Disabled");
            binding,
            value=:disabled,
            id=:disabled_selectable,
            disabled=true,
        ))
        render_toolkit!(Frame(Buffer(1, 12)), disabled_tree)
        @test !focus!(disabled_tree.state.focus, :disabled_selectable)
        @test !dispatch!(disabled_tree, MouseEvent(Position(1, 1), LeftMouseButton, MouseRelease)).consumed
        @test choice[] == :beta
        disabled_node = semantic_node(toolkit_semantic_tree(disabled_tree), "disabled_selectable")
        @test !disabled_node.state.enabled
        @test isempty(disabled_node.actions)

        @test_throws ArgumentError selectable(
            Label("Invalid equality");
            binding,
            value=:invalid,
            equals=(_, _) -> :not_bool,
        )
    end

    @testset "generic state-hoisted toggleable content" begin
        value = Ref(false)
        changes = Bool[]
        binding = state_binding(() -> value[], next -> (value[] = next))
        control = toggleable(
            row("Feature", "custom"; constraints=[Fill(1), Length(6)]);
            binding,
            id=:toggleable,
            label="Enable feature",
            on_change=next -> begin
                push!(changes, next)
                return (:feature, next)
            end,
        )
        tree = ToolkitTree(control)
        buffer = Buffer(1, 20)
        render_toolkit!(Frame(buffer), tree)
        state = element_state(tree, :toggleable)
        @test state isa ToggleableState
        @test !state.checked
        @test focus!(tree.state.focus, :toggleable)
        key_result = dispatch!(tree, KeyEvent(Key(:space)))
        @test key_result.consumed
        @test value[]
        @test state.checked
        @test key_result.messages == Any[(:feature, true)]

        value[] = false
        render_toolkit!(Frame(buffer), tree)
        @test !state.checked
        press = dispatch!(tree, MouseEvent(Position(1, 3), LeftMouseButton, MousePress))
        @test press.consumed
        @test state.pressed
        release = dispatch!(tree, MouseEvent(Position(1, 3), LeftMouseButton, MouseRelease))
        @test release.consumed
        @test value[]
        @test !state.pressed
        @test changes == [true, true]

        node = semantic_node(toolkit_semantic_tree(tree), "toggleable")
        @test node.role == CheckboxRole
        @test node.label == "Enable feature"
        @test node.state.checked == CheckedValue
        @test SetValueSemanticAction in node.actions

        remembered_ref = Ref{Any}(nothing)
        remembered = component(id=:remembered_toggle) do component_state
            local_binding = remember_binding!(component_state, :enabled, false)
            remembered_ref[] = local_binding
            return toggleable(
                Label("Remembered");
                binding=local_binding,
                id=:remembered_toggle_region,
            )
        end
        remembered_tree = ToolkitTree(remembered)
        render_toolkit!(Frame(Buffer(1, 14)), remembered_tree)
        @test focus!(remembered_tree.state.focus, :remembered_toggle_region)
        @test dispatch!(remembered_tree, KeyEvent(Key(:enter))).consumed
        @test binding_value(remembered_ref[])
        @test toolkit_invalidated(remembered_tree)

        disabled_value = Ref(false)
        disabled_tree = ToolkitTree(toggleable(
            Label("Disabled");
            binding=state_binding(() -> disabled_value[], next -> (disabled_value[] = next)),
            id=:disabled_toggleable,
            disabled=true,
        ))
        render_toolkit!(Frame(Buffer(1, 12)), disabled_tree)
        @test !focus!(disabled_tree.state.focus, :disabled_toggleable)
        @test !dispatch!(disabled_tree, MouseEvent(Position(1, 1), LeftMouseButton, MouseRelease)).consumed
        @test !disabled_value[]
        disabled_node = semantic_node(toolkit_semantic_tree(disabled_tree), "disabled_toggleable")
        @test !disabled_node.state.enabled
        @test isempty(disabled_node.actions)

        @test_throws ArgumentError toggleable(
            Label("Invalid");
            binding=state_binding(() -> 1, _ -> nothing),
        )
    end

    @testset "generic clickable composed content" begin
        activations = Symbol[]
        control = clickable(
            column("Launch", "details"; constraints=[Length(1), Length(1)]);
            id=:clickable,
            label="Launch details",
            on_click=state -> begin
                push!(activations, :click)
                return :launched
            end,
        )
        tree = ToolkitTree(control)
        buffer = Buffer(2, 18)
        render_toolkit!(Frame(buffer), tree)
        state = element_state(tree, :clickable)
        @test state isa ClickableState
        @test focus!(tree.state.focus, :clickable)
        key_result = dispatch!(tree, KeyEvent(Key(:enter)))
        @test key_result.consumed
        @test key_result.messages == Any[:launched]
        @test state.activations == 1
        @test dispatch!(tree, KeyEvent(Key(:space))).consumed
        @test state.activations == 2

        press = dispatch!(tree, MouseEvent(Position(2, 2), LeftMouseButton, MousePress))
        @test press.consumed
        @test state.pressed
        release = dispatch!(tree, MouseEvent(Position(2, 2), LeftMouseButton, MouseRelease))
        @test release.consumed
        @test !state.pressed
        @test release.messages == Any[:launched]
        @test state.activations == 3
        semantics = toolkit_semantic_tree(tree)
        clickable_node = semantic_node(semantics, "clickable")
        @test clickable_node.role == ButtonRole
        @test clickable_node.label == "Launch details"

        nested_events = Symbol[]
        nested = clickable(
            clickable(
                Label("Inner");
                id=:inner_click,
                label="Inner",
                on_click=() -> push!(nested_events, :inner),
            );
            id=:outer_click,
            label="Outer",
            on_click=() -> push!(nested_events, :outer),
        )
        nested_tree = ToolkitTree(nested)
        render_toolkit!(Frame(Buffer(1, 12)), nested_tree)
        dispatch!(nested_tree, MouseEvent(Position(1, 1), LeftMouseButton, MousePress))
        dispatch!(nested_tree, MouseEvent(Position(1, 1), LeftMouseButton, MouseRelease))
        @test nested_events == [:inner]

        disabled_events = Symbol[]
        disabled_tree = ToolkitTree(clickable(
            Label("Disabled");
            id=:disabled_click,
            disabled=true,
            on_click=() -> push!(disabled_events, :unexpected),
        ))
        render_toolkit!(Frame(Buffer(1, 12)), disabled_tree)
        @test !focus!(disabled_tree.state.focus, :disabled_click)
        disabled_result = dispatch!(
            disabled_tree,
            MouseEvent(Position(1, 1), LeftMouseButton, MouseRelease),
        )
        @test !disabled_result.consumed
        @test isempty(disabled_events)
        disabled_node = semantic_node(toolkit_semantic_tree(disabled_tree), "disabled_click")
        @test !disabled_node.state.enabled
        @test isempty(disabled_node.actions)
    end

    @testset "declarative hover ancestry and transitions" begin
        events = Any[]
        first_region = hoverable(
            element(Label("First"); id=:first_child);
            id=:first_hover,
            label="First region",
            on_enter=(hovered, state) -> begin
                push!(events, (:first, hovered, state.entries, state.exits))
                :first_entered
            end,
            on_exit=(hovered, state) -> begin
                @test !hovered
                push!(events, (:first, state.hovered, state.entries, state.exits))
                :first_exited
            end,
        )
        second_region = hoverable(
            Label("Second");
            id=:second_hover,
            on_enter=() -> :second_entered,
            on_exit=hovered -> (:second_exit, hovered),
        )
        tree = ToolkitTree(column(
            first_region,
            second_region;
            constraints=[Length(1), Length(1)],
        ))
        render_toolkit!(Frame(Buffer(2, 16)), tree)
        first_state = element_state(tree, :first_hover)
        second_state = element_state(tree, :second_hover)
        @test first_state isa HoverableState
        @test !first_state.hovered
        @test !second_state.hovered

        entered = dispatch!(tree, MouseEvent(Position(1, 2), NoMouseButton, MouseMove))
        @test entered.redraw
        @test entered.messages == [:first_entered]
        @test first_state.hovered
        @test first_state.entries == 1
        @test first_state.exits == 0
        @test events == [(:first, true, UInt64(1), UInt64(0))]
        @test :hover in Wicked.Toolkit._pseudo_states(
            tree.state,
            tree.state.ids[:first_hover],
            element_instance(tree, :first_hover),
        )

        stable = dispatch!(tree, MouseEvent(Position(1, 4), NoMouseButton, MouseMove))
        @test !stable.redraw
        @test isempty(stable.messages)
        @test first_state.entries == 1

        switched = dispatch!(tree, MouseEvent(Position(2, 2), NoMouseButton, MouseMove))
        @test switched.redraw
        @test Set(switched.messages) == Set([:first_exited, :second_entered])
        @test !first_state.hovered
        @test first_state.exits == 1
        @test second_state.hovered
        @test second_state.entries == 1

        left = dispatch!(tree, MouseEvent(Position(3, 1), NoMouseButton, MouseMove))
        @test left.redraw
        @test left.messages == [(:second_exit, false)]
        @test !second_state.hovered
        @test second_state.exits == 1

        semantic = semantic_node(toolkit_semantic_tree(tree), "first_hover")
        @test semantic.role == GroupRole
        @test semantic.metadata[:hovered] == false
        @test semantic.metadata[:entries] == UInt64(1)
        @test semantic.metadata[:exits] == UInt64(1)

        disabled_tree = ToolkitTree(hoverable(
            Label("Disabled");
            id=:disabled_hover,
            disabled=true,
            on_enter=() -> error("disabled hover callback must not run"),
        ))
        render_toolkit!(Frame(Buffer(1, 16)), disabled_tree)
        disabled_move = dispatch!(
            disabled_tree,
            MouseEvent(Position(1, 1), NoMouseButton, MouseMove),
        )
        @test !disabled_move.redraw
        @test !element_state(disabled_tree, :disabled_hover).hovered

        clickable_tree = ToolkitTree(clickable(
            Label("Hover click");
            id=:hover_click,
            on_click=() -> nothing,
        ))
        render_toolkit!(Frame(Buffer(1, 16)), clickable_tree)
        @test dispatch!(
            clickable_tree,
            MouseEvent(Position(1, 1), NoMouseButton, MouseMove),
        ).redraw
        @test element_state(clickable_tree, :hover_click).hovered
    end

    @testset "combined clickable gestures" begin
        now = Ref(UInt64(0))
        callbacks = Any[]
        control = combined_clickable(
            Label("Open details");
            id=:combined,
            label="Open details",
            clock=() -> now[],
            long_press_duration=0.5,
            on_click=state -> begin
                push!(callbacks, (:single, state.activations))
                :single
            end,
            on_double_click=state -> begin
                push!(callbacks, (:double, state.double_activations))
                :double
            end,
            on_long_click=state -> begin
                push!(callbacks, (:long, state.long_activations))
                :long
            end,
        )
        tree = ToolkitTree(control)
        render_toolkit!(Frame(Buffer(1, 20)), tree)
        state = element_state(tree, :combined)
        @test state isa CombinedClickableState

        now[] = 10
        pressed = dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MousePress))
        @test pressed.consumed
        @test pressed.redraw
        @test state.pressed
        @test state.pressed_at_ns == UInt64(10)
        now[] = 100_000_010
        released = dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease))
        @test released.messages == [:single]
        @test !state.pressed
        @test state.activations == 1

        now[] = 200_000_000
        dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MousePress; click_count=2))
        doubled = dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease; click_count=2))
        @test doubled.messages == [:double]
        @test state.double_activations == 1

        now[] = 1_000_000_000
        dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MousePress))
        now[] = 1_600_000_000
        long = dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MouseRelease))
        @test long.messages == [:long]
        @test state.long_activations == 1

        @test focus!(tree.state.focus, :combined)
        keyboard = dispatch!(tree, KeyEvent(Key(:enter)))
        @test keyboard.messages == [:single]
        @test state.activations == 2
        @test callbacks == [
            (:single, UInt64(1)),
            (:double, UInt64(1)),
            (:long, UInt64(1)),
            (:single, UInt64(2)),
        ]

        now[] = 2_000_000_000
        dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MousePress))
        @test state.pressed
        outside = dispatch!(tree, MouseEvent(Position(2, 2), LeftMouseButton, MouseRelease))
        @test outside.redraw
        @test isempty(outside.messages)
        @test !state.pressed
        @test state.pressed_at_ns === nothing
        @test state.activations == 2

        node = semantic_node(toolkit_semantic_tree(tree), "combined")
        @test node.role == ButtonRole
        @test node.label == "Open details"
        @test node.metadata[:activations] == UInt64(2)
        @test node.metadata[:double_activations] == UInt64(1)
        @test node.metadata[:long_activations] == UInt64(1)

        fallback_calls = Ref(0)
        fallback_clock = Ref(UInt64(0))
        fallback_tree = ToolkitTree(combined_clickable(
            ;
            id=:fallback_combined,
            clock=() -> fallback_clock[],
            on_click=() -> (fallback_calls[] += 1; :fallback),
        ))
        render_toolkit!(Frame(Buffer(1, 8)), fallback_tree)
        dispatch!(fallback_tree, MouseEvent(Position(1, 1), LeftMouseButton, MousePress; click_count=2))
        fallback_double = dispatch!(fallback_tree, MouseEvent(Position(1, 1), LeftMouseButton, MouseRelease; click_count=2))
        @test fallback_double.messages == [:fallback]
        @test fallback_calls[] == 1

        disabled_tree = ToolkitTree(combined_clickable(
            Label("Disabled");
            id=:disabled_combined,
            disabled=true,
            on_click=() -> error("disabled combined click must not run"),
        ))
        render_toolkit!(Frame(Buffer(1, 12)), disabled_tree)
        @test !dispatch!(
            disabled_tree,
            MouseEvent(Position(1, 1), LeftMouseButton, MousePress),
        ).consumed
        @test_throws ArgumentError combined_clickable(Label("Bad"); on_click=() -> nothing, long_press_duration=-1)
        @test_throws ArgumentError combined_clickable(Label("Bad"); on_click=() -> nothing, clock=1)
    end

    @testset "pointer-captured declarative dragging" begin
        gestures = DragGesture[]
        source = draggable(
            Label("Drag me");
            id=:drag_source,
            label="Drag source",
            threshold=1,
            on_drag=(gesture, state) -> begin
                push!(gestures, gesture)
                (gesture.kind, gesture.total_row_delta, gesture.total_column_delta)
            end,
        )
        tree = ToolkitTree(column(
            source,
            element(Label("Other"); id=:drag_other);
            constraints=[Length(1), Length(1)],
        ))
        render_toolkit!(Frame(Buffer(2, 16)), tree)
        state = element_state(tree, :drag_source)
        @test state isa DraggableState
        @test !has_pointer_capture(tree)
        @test !capture_pointer!(tree, :missing)

        pressed = dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MousePress))
        @test pressed.consumed
        @test state.pressed
        @test has_pointer_capture(tree.state)
        @test pointer_capture_target(tree) == :drag_source
        @test !release_pointer!(tree, :different)

        started = dispatch!(tree, MouseEvent(Position(2, 4), LeftMouseButton, MouseDrag))
        @test started.consumed
        @test started.messages == [(DragGestureStarted, 1, 2)]
        @test state.dragging
        @test gestures[1].origin == Position(1, 2)
        @test gestures[1].current == Position(2, 4)
        @test gestures[1].row_delta == 1
        @test gestures[1].column_delta == 2

        moved = dispatch!(tree, MouseEvent(Position(3, 7), LeftMouseButton, MouseDrag))
        @test moved.messages == [(DragGestureMoved, 2, 5)]
        @test gestures[2].row_delta == 1
        @test gestures[2].column_delta == 3
        @test pointer_capture_target(tree) == :drag_source

        ended = dispatch!(tree, MouseEvent(Position(4, 8), LeftMouseButton, MouseRelease))
        @test ended.messages == [(DragGestureEnded, 3, 6)]
        @test gestures[3].row_delta == 1
        @test gestures[3].column_delta == 1
        @test !state.dragging
        @test !state.pressed
        @test state.gestures == UInt64(3)
        @test !has_pointer_capture(tree)

        dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MousePress))
        dispatch!(tree, MouseEvent(Position(2, 2), LeftMouseButton, MouseDrag))
        cancelled = dispatch!(tree, KeyEvent(Key(:escape)))
        @test cancelled.messages == [(DragGestureCancelled, 1, 0)]
        @test last(gestures).kind == DragGestureCancelled
        @test !has_pointer_capture(tree)
        @test !state.dragging

        dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MousePress))
        @test has_pointer_capture(tree)
        tree.root = element(Label("Removed"); id=:replacement)
        render_toolkit!(Frame(Buffer(1, 16)), tree)
        @test !has_pointer_capture(tree)

        disabled_tree = ToolkitTree(draggable(
            Label("Disabled");
            id=:disabled_drag,
            disabled=true,
            on_drag=gesture -> error("disabled drag callback must not run"),
        ))
        render_toolkit!(Frame(Buffer(1, 16)), disabled_tree)
        @test !dispatch!(
            disabled_tree,
            MouseEvent(Position(1, 1), LeftMouseButton, MousePress),
        ).consumed
        @test !has_pointer_capture(disabled_tree)
        @test_throws ArgumentError draggable(Label("Bad"); threshold=-1, on_drag=identity)
    end

    @testset "declarative payload drag and drop" begin
        router = ToolkitDragRouter(
            DragDropManager(threshold=1);
            message_mapper=event -> event.kind,
        )
        drops = Any[]
        root() = drag_drop_provider(
            router,
            column(
                drag_source(
                    Label("Artifact");
                    id=:payload_source,
                    payload=DragPayload(
                        "build.tar";
                        mime="application/x-tar",
                        allowed_effects=(CopyDragEffect, MoveDragEffect),
                    ),
                    label="Build artifact",
                ),
                drop_target(
                    Label("Deploy here");
                    id=:payload_target,
                    target_id=:deploy,
                    accepted_mime_prefixes=("application/",),
                    accepted_effects=(MoveDragEffect,),
                    preferred_effect=MoveDragEffect,
                    label="Deployment target",
                    on_drop=(result, state) -> begin
                        push!(drops, (result.effect, result.payload.value, state.drops))
                        (:deployed, result.payload.value)
                    end,
                );
                constraints=[Length(1), Length(1)],
            ),
        )
        tree = ToolkitTree(root())
        render_toolkit!(Frame(Buffer(2, 20)), tree)
        @test haskey(router.manager.targets, "deploy")
        @test router.manager.targets["deploy"].rect == ComponentRect(2, 1, 20, 1)
        source_state = element_state(tree, :payload_source)
        target_state = element_state(tree, :payload_target)
        @test source_state isa DragSourceState
        @test target_state isa DropTargetState

        dispatch!(tree, MouseEvent(Position(1, 2), LeftMouseButton, MousePress))
        @test pointer_capture_target(tree) == :payload_source
        moved = dispatch!(tree, MouseEvent(Position(2, 4), LeftMouseButton, MouseDrag))
        @test moved.messages == [DragStartedEvent, DragEnteredEvent, DragMovedEvent]
        @test source_state.dragging
        @test active_drop_target(router.manager).id == "deploy"

        tree.root = root()
        render_toolkit!(Frame(Buffer(2, 20)), tree)
        @test element_state(tree, :payload_target) === target_state
        @test target_state.hovered
        target_node = semantic_node(toolkit_semantic_tree(tree), "payload_target")
        @test target_node.metadata[:drop_target]
        @test target_node.metadata[:hovered]

        dropped = dispatch!(tree, MouseEvent(Position(2, 4), LeftMouseButton, MouseRelease))
        @test dropped.messages == [DragDroppedEvent, (:deployed, "build.tar")]
        @test drops == [(MoveDragEffect, "build.tar", UInt64(1))]
        @test target_state.drops == UInt64(1)
        @test !has_pointer_capture(tree)
        @test router.manager.phase == DragCompleted

        source_node = semantic_node(toolkit_semantic_tree(tree), "payload_source")
        @test source_node.metadata[:drag_source]
        @test source_node.metadata[:mime] == "application/x-tar"

        tree.root = element(Label("Removed"))
        render_toolkit!(Frame(Buffer(1, 20)), tree)
        @test !haskey(router.manager.targets, "deploy")

        @test_throws ArgumentError render_toolkit!(
            Frame(Buffer(1, 12)),
            ToolkitTree(drag_source(
                Label("Missing provider");
                id=:orphan_source,
                payload=DragPayload(:value),
            )),
        )

        batched = EventResponse(message=event_messages(:one, nothing, :two))
        batch_tree = ToolkitTree(element(
            Label("Batch");
            id=:batch,
            focusable=true,
            on_event=(event, state) -> batched,
        ))
        render_toolkit!(Frame(Buffer(1, 8)), batch_tree)
        @test focus!(batch_tree.state.focus, :batch)
        @test dispatch!(batch_tree, KeyEvent(Key(:enter))).messages == [:one, :two]
    end

    @testset "allocation-aware responsive components" begin
        observed = Rect[]
        state_ref = Ref{Any}(nothing)
        responsive = box_with_constraints(id=:responsive) do state, area
            state_ref[] = state
            push!(observed, area)
            if area.width < 10
                return "compact"
            end
            return row("left", "right"; constraints=[Fill(1), Fill(1)])
        end
        tree = ToolkitTree(responsive)
        compact_buffer = Buffer(1, 8)
        render_toolkit!(Frame(compact_buffer), tree)
        @test plain_snapshot(compact_buffer) == "compact"
        @test component_area(state_ref[]) == Rect(1, 1, 1, 8)
        @test component_size(state_ref[]) == Size(1, 8)

        wide_buffer = Buffer(1, 20)
        render_toolkit!(Frame(wide_buffer), tree)
        @test startswith(plain_snapshot(wide_buffer), "left")
        @test occursin("right", plain_snapshot(wide_buffer))
        @test component_area(state_ref[]) == Rect(1, 1, 1, 20)
        @test last(observed).width == 20

        offset_buffer = Buffer(3, 20)
        render_toolkit!(Frame(offset_buffer), tree, Rect(2, 4, 1, 8))
        @test component_area(state_ref[]) == Rect(2, 4, 1, 8)
        @test occursin("compact", plain_snapshot(offset_buffer))

        retained_state = state_ref[]
        tree.root = element(Label("removed"))
        render_toolkit!(Frame(wide_buffer), tree)
        @test component_area(retained_state) == Rect(1, 1, 0, 0)

        area_only = ToolkitTree(box_with_constraints(area -> "$(area.height)x$(area.width)"))
        area_buffer = Buffer(2, 7)
        render_toolkit!(Frame(area_buffer), area_only)
        @test startswith(plain_snapshot(area_buffer), "2x7")
    end

    @testset "composition locals and named slots" begin
        theme = composition_local(:theme, "light"; value_type=AbstractString)
        same_name = composition_local(:theme, "independent"; value_type=AbstractString)
        consumer(id) = component(state -> "$(id):$(composition_value(state, theme))"; id)

        tree = ToolkitTree(column(
            consumer(:outside),
            provide_context(theme => "dark"; children=(
                consumer(:inside),
                provide_context(theme => "nested") do
                    consumer(:nested)
                end,
            ));
            constraints=[Length(1), Fill(1)],
        ))
        render_toolkit!(Frame(Buffer(3, 24)), tree)
        @test composition_value(element_state(tree, :outside), theme) == "light"
        @test composition_value(element_state(tree, :inside), theme) == "dark"
        @test composition_value(element_state(tree, :nested), theme) == "nested"
        @test composition_value(element_state(tree, :nested), same_name) == "independent"
        nested_state = element_state(tree, :nested)
        @test_throws ArgumentError provide_context(theme => 1; children=(consumer(:invalid),))
        @test_throws ArgumentError provide_context(
            theme => "first",
            theme => "second";
            children=(consumer(:duplicate),),
        )
        tree.root = element(Label("removed"))
        render_toolkit!(Frame(Buffer(1, 24)), tree)
        @test composition_value(nested_state, theme) == "light"

        content = component_slots(
            "Body";
            header=("Title", element(Label("Status"); key=:status)),
            actions="Save",
        )
        @test slot_names(content) == [:actions, :default, :header]
        @test has_slot(content, :header)
        @test !has_slot(content, :footer)
        @test length(slot(content, :header)) == 2
        @test length(slot(content)) == 1
        @test length(slot(content, :footer; fallback="Footer")) == 1
        first_copy = slot(content, :header)
        empty!(first_copy)
        @test length(slot(content, :header)) == 2

        slotted = column(
            slot(content, :header)...,
            slot(content)...,
            slot(content, :actions)...;
            constraints=fill(Length(1), 4),
        )
        slotted_buffer = Buffer(4, 12)
        render_toolkit!(Frame(slotted_buffer), ToolkitTree(slotted))
        @test plain_snapshot(slotted_buffer) == "Title\nStatus\nBody\nSave"
    end

    @testset "keyed remembered and derived component state" begin
        cells = Dict{Symbol,RememberedValue}()
        show_extra = Ref(true)
        remembered_component = component(id=:remembered) do state
            count = remember!(state, :count, 0)
            cells[:count] = count
            doubled = derived_remember!(value -> value * 2, state, :doubled, (remembered_value(count),))
            cells[:doubled] = doubled
            if show_extra[]
                cells[:extra] = remember!(state, :extra, "visible")
            end
            return "$(remembered_value(count))/$(remembered_value(doubled))"
        end
        tree = ToolkitTree(remembered_component)
        buffer = Buffer(1, 16)
        render_toolkit!(Frame(buffer), tree)
        count = cells[:count]
        extra = cells[:extra]
        @test remembered_value(count) == 0
        @test remembered_version(count) == 0
        @test plain_snapshot(buffer) == "0/0"

        set_remembered_value!(count, 2)
        @test toolkit_invalidated(tree)
        @test remembered_version(count) == 1
        render_toolkit!(Frame(buffer), tree)
        @test cells[:count] === count
        @test remembered_value(cells[:doubled]) == 4
        @test plain_snapshot(buffer) == "2/4"
        update_remembered_value!(+, count, 3)
        @test remembered_value(count) == 5
        @test_throws ArgumentError update_remembered_value!(identity, count, :extra)

        show_extra[] = false
        render_toolkit!(Frame(buffer), tree)
        clear_toolkit_invalidation!(tree)
        set_remembered_value!(extra, "detached")
        @test !toolkit_invalidated(tree)

        duplicate = component() do state
            remember!(state, :same, 1)
            remember!(state, :same, 2)
            return nothing
        end
        @test_throws ArgumentError render_toolkit!(Frame(Buffer(1, 8)), ToolkitTree(duplicate))

        tree.root = element(Label("removed"))
        render_toolkit!(Frame(buffer), tree)
        clear_toolkit_invalidation!(tree)
        set_remembered_value!(count, 9)
        @test !toolkit_invalidated(tree)
    end

    @testset "saveable component state survives subtree disposal" begin
        registry = SaveableStateRegistry()
        cell_ref = Ref{Any}(nothing)
        function saveable_view(state)
            cell = remember_saveable!(state, :count, 0)
            cell_ref[] = cell
            return "Saved: $(remembered_value(cell))"
        end
        saveable_component() = component(saveable_view; key=:saveable, id=:saveable)
        saveable_root() = saveable_state_provider(registry, saveable_component(); scope=:screen)

        tree = ToolkitTree(saveable_root())
        buffer = Buffer(1, 20)
        render_toolkit!(Frame(buffer), tree)
        first_cell = cell_ref[]
        @test remembered_value(first_cell) == 0
        set_remembered_value!(first_cell, 7)
        @test has_saveable_state(registry, :count; scope=:screen)
        snapshot = saveable_state_snapshot(registry)
        @test snapshot[SaveableStateAddress(:screen, :count)] == 7

        tree.root = element(Label("away"))
        render_toolkit!(Frame(buffer), tree)
        tree.root = saveable_root()
        clear!(buffer)
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Saved: 7"
        @test cell_ref[] !== first_cell

        encoded_registry = SaveableStateRegistry()
        encoded_ref = Ref{Any}(nothing)
        function encoded_view(state)
            encoded_ref[] = remember_saveable!(
                state,
                :value,
                3;
                save=value -> string(value),
                restore=value -> parse(Int, value),
            )
            return string(remembered_value(encoded_ref[]))
        end
        encoded_root() = saveable_state_provider(
            encoded_registry,
            component(encoded_view; key=:encoded, id=:encoded);
            scope=:form,
        )
        encoded_tree = ToolkitTree(encoded_root())
        render_toolkit!(Frame(Buffer(1, 8)), encoded_tree)
        set_remembered_value!(encoded_ref[], 9)
        @test saveable_state_snapshot(encoded_registry)[SaveableStateAddress(:form, :value)] == "9"
        encoded_tree.root = element(Label("away"))
        render_toolkit!(Frame(Buffer(1, 8)), encoded_tree)
        encoded_tree.root = encoded_root()
        render_toolkit!(Frame(Buffer(1, 8)), encoded_tree)
        @test remembered_value(encoded_ref[]) == 9

        restored_registry = SaveableStateRegistry(snapshot)
        @test has_saveable_state(restored_registry, :count; scope=:screen)
        remove_saveable_state!(restored_registry, :count; scope=:screen)
        @test !has_saveable_state(restored_registry, :count; scope=:screen)
        restore_saveable_state!(restored_registry, snapshot)
        clear_saveable_state!(restored_registry; scope=:screen)
        @test isempty(saveable_state_snapshot(restored_registry))

        missing_tree = ToolkitTree(component(state -> begin
            remember_saveable!(state, :missing, 1)
            "missing"
        end))
        @test_throws ArgumentError render_toolkit!(Frame(Buffer(1, 8)), missing_tree)
    end

    @testset "error boundaries rollback and recover" begin
        failures = CapturedException[]
        unmounted = Symbol[]
        reset_key = Ref(1)
        failing_tree() = error_boundary(
            component(
                state -> PartialFailingReconciliationWidget();
                id=:failing_child,
                on_unmount=state -> push!(unmounted, :child),
            );
            id=:boundary,
            reset_key=reset_key[],
            fallback=(failure, state) -> "Recovered $(state.failure_count)",
            on_error=(failure, state) -> push!(failures, failure),
        )
        tree = ToolkitTree(failing_tree())
        buffer = Buffer(1, 20)
        render_toolkit!(Frame(buffer), tree)
        boundary_state = element_state(tree, :boundary)
        @test boundary_state isa ComponentErrorBoundaryState
        @test boundary_failed(boundary_state)
        @test boundary_failure(boundary_state) isa CapturedException
        @test boundary_state.failure_count == 1
        @test length(failures) == 1
        @test unmounted == [:child]
        @test plain_snapshot(buffer) == "Recovered 1"
        @test element_state(tree, :failing_child) === nothing

        render_toolkit!(Frame(buffer), tree)
        @test boundary_state.failure_count == 1
        @test length(failures) == 1
        retry_error_boundary!(boundary_state)
        @test toolkit_invalidated(tree)
        render_toolkit!(Frame(buffer), tree)
        @test boundary_state.failure_count == 2
        @test plain_snapshot(buffer) == "Recovered 2"

        reset_key[] = 2
        tree.root = error_boundary(
            "Healthy";
            id=:boundary,
            reset_key=reset_key[],
            fallback="unused",
        )
        clear!(buffer)
        render_toolkit!(Frame(buffer), tree)
        @test !boundary_failed(boundary_state)
        @test plain_snapshot(buffer) == "Healthy"

        broken_fallback = error_boundary(
            FailingReconciliationWidget();
            fallback=() -> error("fallback failed"),
        )
        @test_throws ErrorException render_toolkit!(Frame(Buffer(1, 8)), ToolkitTree(broken_fallback))
    end

    @testset "async resources suppress stale results and compose states" begin
        dependency = Ref(1)
        channels = Dict(1 => Channel{Any}(1), 2 => Channel{Any}(1))
        resource_ref = Ref{Any}(nothing)
        resource_view() = component(id=:async_resource) do state
            resource = use_resource!(
                state,
                :data,
                (token, generation) -> take!(channels[generation]);
                dependencies=(dependency[],),
            )
            resource_ref[] = resource
            return resource_content(
                resource;
                loading="Loading $(dependency[])",
                success=value -> "Value: $value",
                failure=error -> "Failed: $(error.ex)",
            )
        end
        tree = ToolkitTree(resource_view())
        buffer = Buffer(1, 24)
        render_toolkit!(Frame(buffer), tree)
        resource = resource_ref[]
        @test resource isa AsyncResource
        @test resource_loading(resource)
        @test plain_snapshot(buffer) == "Loading 1"

        dependency[] = 2
        tree.root = resource_view()
        clear!(buffer)
        render_toolkit!(Frame(buffer), tree)
        @test resource_generation(resource) == 2
        put!(channels[1], "stale")
        yield()
        @test !resource_succeeded(resource)
        put!(channels[2], "fresh")
        @test timedwait(() -> resource_succeeded(resource), 2) == :ok
        @test resource_value(resource) == "fresh"
        @test toolkit_invalidated(tree)
        clear!(buffer)
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Value: fresh"

        failing_resource = AsyncResource()
        load_async_resource!(failing_resource, () -> error("offline"))
        @test timedwait(() -> resource_failed(failing_resource), 2) == :ok
        @test resource_failure(failing_resource) isa CapturedException
        @test occursin("offline", sprint(showerror, resource_failure(failing_resource).ex))

        retry_loader = Ref(() -> 7)
        failing_resource.loader = () -> retry_loader[]()
        retry_async_resource!(failing_resource)
        @test timedwait(() -> resource_succeeded(failing_resource), 2) == :ok
        @test resource_value(failing_resource) == 7
        cancel_async_resource!(failing_resource)

        tree.root = element(Label("removed"))
        render_toolkit!(Frame(buffer), tree)
        @test resource_status(resource) == ResourceIdle

        shorthand = async_resource_component(
            () -> "ready";
            loading="wait",
            success=value -> "short: $value",
            id=:shorthand,
        )
        shorthand_tree = ToolkitTree(shorthand)
        shorthand_buffer = Buffer(1, 24)
        render_toolkit!(Frame(shorthand_buffer), shorthand_tree)
        shorthand_state = element_state(shorthand_tree, :shorthand)
        shorthand_resource = only(
            remembered_value(value) for value in values(shorthand_state.remembered)
            if remembered_value(value) isa AsyncResource
        )
        @test timedwait(() -> resource_succeeded(shorthand_resource), 2) == :ok
        clear!(shorthand_buffer)
        render_toolkit!(Frame(shorthand_buffer), shorthand_tree)
        @test plain_snapshot(shorthand_buffer) == "short: ready"
    end

    @testset "tracked components reconcile automatic reactive reads" begin
        reactive_runtime = ReactiveRuntime()
        branch = Signal(true; runtime=reactive_runtime)
        left = Signal("left-1"; runtime=reactive_runtime)
        right = Signal("right-1"; runtime=reactive_runtime)

        direct = track_reactive_reads() do
            signal_value(left) * signal_value(left)
        end
        @test direct.value == "left-1left-1"
        @test direct.dependencies == Any[left]
        @test_throws ErrorException track_reactive_reads(() -> error("tracked failure"))
        restored = track_reactive_reads(() -> signal_value(right))
        @test restored.dependencies == Any[right]

        tracked = tracked_component(id=:tracked) do state
            selected = signal_value(branch) ? signal_value(left) : signal_value(right)
            return "Tracked: $selected"
        end
        @test tracked.widget.view isa TrackedComponentView
        tree = ToolkitTree(tracked)
        buffer = Buffer(1, 24)
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Tracked: left-1"

        set_signal!(left, "left-2")
        @test toolkit_invalidated(tree)
        clear!(buffer)
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Tracked: left-2"

        set_signal!(branch, false)
        clear!(buffer)
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Tracked: right-1"
        clear_toolkit_invalidation!(tree)
        set_signal!(left, "left-detached")
        @test !toolkit_invalidated(tree)
        set_signal!(right, "right-2")
        @test toolkit_invalidated(tree)

        clear!(buffer)
        render_toolkit!(Frame(buffer), tree)
        tree.root = element(Label("removed"))
        render_toolkit!(Frame(buffer), tree)
        clear_toolkit_invalidation!(tree)
        set_signal!(right, "right-detached")
        @test !toolkit_invalidated(tree)
    end

    @testset "controlled and uncontrolled state bindings" begin
        external = Ref((count=1, label="one"))
        controlled = state_binding(
            () -> external[],
            value -> (external[] = value),
        )
        count_binding = map_binding(
            controlled;
            get=value -> value.count,
            set=(value, count) -> merge(value, (count=count,)),
        )
        @test binding_value(count_binding) == 1
        set_binding_value!(count_binding, 2)
        @test external[].count == 2
        update_binding_value!(+, count_binding, 3)
        @test external[].count == 5
        @test_throws ArgumentError update_binding_value!(identity, count_binding, :extra)

        changes = Int[]
        snapshot = state_binding(4; on_change=value -> push!(changes, value))
        set_binding_value!(snapshot, 4)
        set_binding_value!(snapshot, 6)
        @test changes == [6]

        binding_ref = Ref{Any}(nothing)
        uncontrolled = component(id=:uncontrolled) do state
            binding = remember_binding!(state, :count, 0)
            binding_ref[] = binding
            return "Bound: $(binding_value(binding))"
        end
        tree = ToolkitTree(uncontrolled)
        buffer = Buffer(1, 20)
        render_toolkit!(Frame(buffer), tree)
        remembered_binding = binding_ref[]
        @test remembered_binding isa RememberedStateBinding
        set_binding_value!(remembered_binding, 3)
        @test toolkit_invalidated(tree)
        clear!(buffer)
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Bound: 3"

        signal = Signal(10)
        reactive_binding = signal_binding(signal)
        tracked_tree = ToolkitTree(tracked_component(state -> "Signal: $(binding_value(reactive_binding))"))
        tracked_buffer = Buffer(1, 20)
        render_toolkit!(Frame(tracked_buffer), tracked_tree)
        set_binding_value!(reactive_binding, 11)
        @test toolkit_invalidated(tracked_tree)
        @test signal_value(signal) == 11

        tree.root = element(Label("removed"))
        render_toolkit!(Frame(buffer), tree)
        clear_toolkit_invalidation!(tree)
        set_binding_value!(remembered_binding, 4)
        @test !toolkit_invalidated(tree)

        slider_value = Ref(2.0)
        slider_binding = state_binding(
            () -> slider_value[],
            value -> (slider_value[] = value),
        )
        slider = Slider(0, 10; value=2, step=1, width=11)
        bound_slider_element = bound_element(
            slider,
            slider_binding;
            id=:bound_slider,
            focusable=true,
            apply_value! = (state, value) -> set_slider!(state, value),
            extract_value=state -> state.value,
        )
        slider_tree = ToolkitTree(bound_slider_element)
        slider_buffer = Buffer(1, 11)
        render_toolkit!(Frame(slider_buffer), slider_tree)
        wrapper = element_state(slider_tree, :bound_slider)
        @test wrapper isa BoundWidgetState
        @test bound_widget_state(wrapper).value == 2
        @test focus!(slider_tree.state.focus, :bound_slider)
        result = dispatch!(slider_tree, KeyEvent(Key(:right)))
        @test result.consumed
        @test slider_value[] == 3
        slider_value[] = 8
        render_toolkit!(Frame(slider_buffer), slider_tree)
        @test bound_widget_state(wrapper).value == 8
        semantic = toolkit_semantic_tree(slider_tree)
        @test semantic_node(semantic, "bound_slider").state.value_now == 8

        concise_slider_value = Ref(3.0)
        concise_slider = bound_slider(
            state_binding(() -> concise_slider_value[], value -> (concise_slider_value[] = value));
            minimum=0,
            maximum=10,
            step=1,
            width=11,
            id=:concise_slider,
        )
        concise_slider_tree = ToolkitTree(concise_slider)
        render_toolkit!(Frame(Buffer(1, 11)), concise_slider_tree)
        @test focus!(concise_slider_tree.state.focus, :concise_slider)
        @test dispatch!(concise_slider_tree, KeyEvent(Key(:right))).consumed
        @test concise_slider_value[] == 4

        range_value = Ref((lower=2.0, upper=7.0))
        range_control = bound_range_slider(
            state_binding(() -> range_value[], value -> (range_value[] = value));
            minimum=0,
            maximum=10,
            step=1,
            width=11,
            id=:bound_range,
        )
        range_tree = ToolkitTree(range_control)
        render_toolkit!(Frame(Buffer(1, 11)), range_tree)
        @test focus!(range_tree.state.focus, :bound_range)
        @test dispatch!(range_tree, KeyEvent(Key(:right))).consumed
        @test range_value[] == (lower=3.0, upper=7.0)

        checkbox_value = Ref(false)
        checkbox_tree = ToolkitTree(bound_checkbox(
            "Ready",
            state_binding(() -> checkbox_value[], value -> (checkbox_value[] = value));
            id=:bound_checkbox,
        ))
        render_toolkit!(Frame(Buffer(1, 12)), checkbox_tree)
        @test focus!(checkbox_tree.state.focus, :bound_checkbox)
        @test dispatch!(checkbox_tree, KeyEvent(Key(:enter))).consumed
        @test checkbox_value[]

        toggle_value = Ref(false)
        toggle_tree = ToolkitTree(bound_toggle(
            state_binding(() -> toggle_value[], value -> (toggle_value[] = value));
            id=:bound_toggle,
        ))
        render_toolkit!(Frame(Buffer(1, 10)), toggle_tree)
        @test focus!(toggle_tree.state.focus, :bound_toggle)
        @test dispatch!(toggle_tree, KeyEvent(Key(:enter))).consumed
        @test toggle_value[]

        text_value = Ref("a")
        text_tree = ToolkitTree(bound_text_input(
            state_binding(() -> text_value[], value -> (text_value[] = value));
            id=:bound_text,
        ))
        text_buffer = Buffer(1, 12)
        render_toolkit!(Frame(text_buffer), text_tree)
        @test focus!(text_tree.state.focus, :bound_text)
        @test dispatch!(text_tree, KeyEvent(Key(:character); text="b")).consumed
        @test text_value[] == "ab"
        text_value[] = "external"
        render_toolkit!(Frame(text_buffer), text_tree)
        @test editing_text(bound_widget_state(element_state(text_tree, :bound_text))) == "external"

        property_value = Ref(4)
        property_binding = state_binding(() -> property_value[], value -> (property_value[] = value))
        property_element = bound_property_element(
            ReconciliationWidget("property"),
            property_binding,
            :x;
            state_factory=() -> Ref(0),
            id=:bound_property,
        )
        property_tree = ToolkitTree(property_element)
        render_toolkit!(Frame(Buffer(1, 12)), property_tree)
        @test bound_widget_state(element_state(property_tree, :bound_property))[] == 4
    end

    @testset "lazy declarative collection composition" begin
        source = VectorDataSource(collect(1:10); key=(value, _) -> value)
        built = Int[]
        unmounted = Int[]
        activated = Int[]
        selections = Any[]
        item_builder = function (value, _, _, state)
            push!(built, value)
            return component(
                _ -> "Item $value";
                initial=value,
                id=Symbol("lazy_item_$value"),
                on_unmount=_ -> push!(unmounted, value),
            )
        end
        make_lazy() = lazy_column(
            source;
            item=item_builder,
            height=3,
            width=16,
            overscan=2,
            id=:lazy_viewport,
            on_activate=key -> push!(activated, key),
            on_selection_change=selection -> push!(selections, selection),
        )

        tree = ToolkitTree(make_lazy())
        buffer = Buffer(3, 16)
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Item 1\nItem 2\nItem 3"
        @test sort(unique(built)) == [1, 2, 3]
        @test element_state(tree, :lazy_viewport) isa VirtualListState
        retained_two = element_state(tree, :lazy_item_2)

        @test focus!(tree.state.focus, :lazy_viewport)
        @test dispatch!(tree, KeyEvent(Key(:end))).consumed
        clear!(buffer)
        tree.root = make_lazy()
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Item 8\nItem 9\nItem 10"
        @test all(value -> value in unmounted, 1:3)
        @test element_state(tree, :lazy_item_1) === nothing

        @test dispatch!(tree, KeyEvent(Key(:enter))).consumed
        @test activated == [10]
        @test dispatch!(tree, KeyEvent(Key(:space))).consumed
        @test only(selections) == Set([10])

        @test dispatch!(tree, KeyEvent(Key(:home))).consumed
        clear!(buffer)
        tree.root = make_lazy()
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Item 1\nItem 2\nItem 3"
        @test element_state(tree, :lazy_item_2) !== retained_two

        replace_data!(source, [3, 2, 1, 4, 5, 6, 7, 8, 9, 10])
        retained_two = element_state(tree, :lazy_item_2)
        clear!(buffer)
        tree.root = make_lazy()
        render_toolkit!(Frame(buffer), tree)
        @test plain_snapshot(buffer) == "Item 3\nItem 2\nItem 1"
        @test element_state(tree, :lazy_item_2) === retained_two

        empty_source = Int[]
        empty_tree = ToolkitTree(lazy_column(empty_source; item=string, empty="Nothing here", height=2, width=16))
        empty_buffer = Buffer(2, 16)
        render_toolkit!(Frame(empty_buffer), empty_tree)
        @test startswith(plain_snapshot(empty_buffer), "Nothing here")

        pointer_selection = Ref{Any}(nothing)
        extent_tree = ToolkitTree(lazy_column(
            collect(1:4);
            item=value -> "Extent $value",
            height=4,
            width=16,
            item_extent=2,
            id=:extent_viewport,
            on_selection_change=selection -> (pointer_selection[] = selection),
        ))
        extent_buffer = Buffer(4, 16)
        render_toolkit!(Frame(extent_buffer), extent_tree)
        pointer_result = dispatch!(
            extent_tree,
            MouseEvent(Position(3, 1), LeftMouseButton, MousePress),
        )
        @test pointer_result.consumed
        @test pointer_selection[] == Set([2])
    end

    @testset "lazy declarative horizontal row" begin
        source = VectorDataSource(collect(1:8); key=(value, _) -> value)
        built = Int[]
        selected = Ref{Any}(nothing)
        activated = Int[]
        make_row() = lazy_row(
            source;
            item=value -> begin
                push!(built, value)
                element(Label("R$value"); id=Symbol("row_item_$value"))
            end,
            width=15,
            height=1,
            item_extent=5,
            id=:lazy_row,
            on_selection_change=value -> (selected[] = value),
            on_activate=key -> push!(activated, key),
        )
        tree = ToolkitTree(make_row())
        buffer = Buffer(1, 15)
        render_toolkit!(Frame(buffer), tree)
        @test sort(unique(built)) == [1, 2, 3]
        @test startswith(plain_snapshot(buffer), "R1")
        @test occursin("R2", plain_snapshot(buffer))
        retained_two = element_instance(tree, :row_item_2)

        @test focus!(tree.state.focus, :lazy_row)
        @test dispatch!(tree, KeyEvent(Key(:home))).consumed
        @test dispatch!(tree, KeyEvent(Key(:right))).consumed
        @test element_state(tree, :lazy_row).cursor == 2
        @test dispatch!(tree, KeyEvent(Key(:enter))).consumed
        @test activated == [2]
        @test dispatch!(tree, KeyEvent(Key(:end))).consumed
        clear!(buffer)
        tree.root = make_row()
        render_toolkit!(Frame(buffer), tree)
        @test startswith(plain_snapshot(buffer), "R6")
        @test element_instance(tree, :row_item_5) === nothing

        @test dispatch!(tree, KeyEvent(Key(:home))).consumed
        tree.root = make_row()
        render_toolkit!(Frame(buffer), tree)
        pointer = dispatch!(tree, MouseEvent(Position(1, 6), LeftMouseButton, MousePress))
        @test pointer.consumed
        @test selected[] == Set([2])

        replace_data!(source, [3, 2, 1, 4, 5, 6, 7, 8])
        retained_two = element_instance(tree, :row_item_2)
        clear!(buffer)
        tree.root = make_row()
        render_toolkit!(Frame(buffer), tree)
        @test element_instance(tree, :row_item_2) === retained_two
        @test startswith(plain_snapshot(buffer), "R3")
    end

    @testset "lazy declarative grid composition" begin
        source = VectorDataSource(collect(1:9); key=(value, _) -> value)
        built = Int[]
        activated = Int[]
        selected = Ref{Any}(nothing)
        make_grid() = lazy_grid(
            source;
            item=value -> begin
                push!(built, value)
                element(Label("Cell $value"); id=Symbol("grid_cell_$value"))
            end,
            columns=2,
            height=2,
            width=20,
            overscan=1,
            id=:lazy_grid,
            on_activate=key -> push!(activated, key),
            on_selection_change=value -> (selected[] = value),
        )
        tree = ToolkitTree(make_grid())
        buffer = Buffer(2, 20)
        render_toolkit!(Frame(buffer), tree)
        @test sort(unique(built)) == [1, 2, 3, 4]
        @test occursin("Cell 1", plain_snapshot(buffer))
        @test occursin("Cell 4", plain_snapshot(buffer))
        retained_two = element_instance(tree, :grid_cell_2)

        @test focus!(tree.state.focus, :lazy_grid)
        @test dispatch!(tree, KeyEvent(Key(:down))).consumed
        @test element_state(tree, :lazy_grid).cursor == 3
        @test dispatch!(tree, KeyEvent(Key(:right))).consumed
        @test element_state(tree, :lazy_grid).cursor == 4
        @test dispatch!(tree, KeyEvent(Key(:end))).consumed
        clear!(buffer)
        tree.root = make_grid()
        render_toolkit!(Frame(buffer), tree)
        @test sort(unique(filter(value -> value >= 7, built))) == [7, 8, 9]
        @test element_instance(tree, :grid_cell_6) === nothing
        @test dispatch!(tree, KeyEvent(Key(:enter))).consumed
        @test activated == [9]

        @test dispatch!(tree, KeyEvent(Key(:home))).consumed
        clear!(buffer)
        tree.root = make_grid()
        render_toolkit!(Frame(buffer), tree)
        pointer = dispatch!(
            tree,
            MouseEvent(Position(1, 11), LeftMouseButton, MousePress),
        )
        @test pointer.consumed
        @test selected[] == Set([2])

        replace_data!(source, [3, 2, 1, 4, 5, 6, 7, 8, 9])
        retained_two = element_instance(tree, :grid_cell_2)
        clear!(buffer)
        tree.root = make_grid()
        render_toolkit!(Frame(buffer), tree)
        @test element_instance(tree, :grid_cell_2) === retained_two
        @test element_instance(tree, :grid_cell_1) !== nothing
    end

    @testset "declarative animation state retargets and disposes" begin
        now = Ref{UInt64}(0)
        manager = AnimationManager(clock=() -> now[])
        target = Ref(0.0)
        animated_ref = Ref{Any}(nothing)
        function animated_view(state)
            animated = animate_value_as_state!(
                state,
                :position,
                target[];
                duration=0.1,
            )
            animated_ref[] = animated
            return "Value: $(round(animated_value(animated); digits=1))"
        end
        animated_component() = component(animated_view; key=:animated, id=:animated)
        animated_root() = animation_provider(manager, animated_component())

        tree = ToolkitTree(animated_root())
        buffer = Buffer(1, 24)
        render_toolkit!(Frame(buffer), tree)
        animated = animated_ref[]
        @test animated isa AnimatedValue
        @test animated_value(animated) == 0.0
        @test !animated_value_running(animated)

        target[] = 10.0
        tree.root = animated_root()
        render_toolkit!(Frame(buffer), tree)
        @test animated_value_running(animated)
        @test animation_target(animated) == 10.0
        @test length(active_animation_handles(manager)) == 1
        now[] = 50_000_000
        tick_animations!(manager)
        @test animated_value(animated) ≈ 5.0
        @test toolkit_invalidated(tree)

        clear!(buffer)
        tree.root = animated_root()
        render_toolkit!(Frame(buffer), tree)
        @test occursin("5.0", plain_snapshot(buffer))
        target[] = 20.0
        tree.root = animated_root()
        render_toolkit!(Frame(buffer), tree)
        @test length(active_animation_handles(manager)) == 1
        now[] = 100_000_000
        tick_animations!(manager)
        @test animated_value(animated) ≈ 12.5

        tree.root = element(Label("removed"))
        render_toolkit!(Frame(buffer), tree)
        @test isempty(active_animation_handles(manager))
        @test animated_value_status(animated) == CancelledAnimation

        disabled_manager = AnimationManager(policy=DisabledMotion, clock=() -> now[])
        disabled_target = Ref(1.0)
        disabled_ref = Ref{Any}(nothing)
        disabled_component() = animation_provider(disabled_manager) do
            component(key=:disabled) do state
                disabled_ref[] = animate_value_as_state!(state, :value, disabled_target[])
                string(animated_value(disabled_ref[]))
            end
        end
        disabled_tree = ToolkitTree(disabled_component())
        render_toolkit!(Frame(Buffer(1, 12)), disabled_tree)
        disabled_target[] = 9.0
        disabled_tree.root = disabled_component()
        render_toolkit!(Frame(Buffer(1, 12)), disabled_tree)
        @test animated_value(disabled_ref[]) == 9.0
        @test animated_value_status(disabled_ref[]) == CompletedAnimation
        @test isempty(active_animation_handles(disabled_manager))

        missing_manager = ToolkitTree(component(state -> begin
            animate_value_as_state!(state, :missing, 1.0)
            "missing"
        end))
        @test_throws ArgumentError render_toolkit!(Frame(Buffer(1, 8)), missing_manager)
    end

    function render_tree!(tree; height=3, width=20)
        buffer = Buffer(height, width)
        render_toolkit!(Frame(buffer), tree)
        return buffer
    end

    function tracked_element(
        name,
        mounts,
        unmounts;
        key=name,
        id=name,
        hidden=false,
        widget=ReconciliationWidget(string(name)),
    )
        Element(
            widget;
            key,
            id,
            hidden,
            state_factory=() -> Ref(0),
            on_mount=state -> push!(mounts, name),
            on_unmount=state -> push!(unmounts, name),
        )
    end

    @testset "keyed sibling moves retain state" begin
        mounts = Symbol[]
        unmounts = Symbol[]
        first_root = row(
            tracked_element(:alpha, mounts, unmounts),
            tracked_element(:beta, mounts, unmounts),
        )
        tree = ToolkitTree(first_root)
        render_tree!(tree)
        alpha_state = element_state(tree, :alpha)
        beta_state = element_state(tree, :beta)
        alpha_state[] = 7
        beta_state[] = 9

        tree.root = row(
            tracked_element(:beta, mounts, unmounts),
            tracked_element(:alpha, mounts, unmounts),
        )
        render_tree!(tree)

        @test element_state(tree, :alpha) === alpha_state
        @test element_state(tree, :beta) === beta_state
        @test alpha_state[] == 7
        @test beta_state[] == 9
        @test mounts == [:alpha, :beta]
        @test isempty(unmounts)
    end

    @testset "removal and signature replacement unmount exactly once" begin
        mounts = Symbol[]
        unmounts = Symbol[]
        tree = ToolkitTree(row(
            tracked_element(:alpha, mounts, unmounts),
            tracked_element(:beta, mounts, unmounts),
        ))
        render_tree!(tree)

        tree.root = row(tracked_element(:beta, mounts, unmounts))
        render_tree!(tree)
        @test unmounts == [:alpha]
        @test element_state(tree, :alpha) === nothing

        old_beta = element_state(tree, :beta)
        tree.root = row(tracked_element(
            :beta,
            mounts,
            unmounts;
            widget=ReplacementReconciliationWidget("Beta"),
        ))
        render_tree!(tree)
        @test element_state(tree, :beta) !== old_beta
        @test mounts == [:alpha, :beta, :beta]
        @test unmounts == [:alpha, :beta]
    end

    @testset "hidden subtrees remain mounted and retain state" begin
        mounts = Symbol[]
        unmounts = Symbol[]
        child = tracked_element(:child, mounts, unmounts)
        tree = ToolkitTree(Element(nothing; key=:container, id=:container, children=(child,)))
        render_tree!(tree)
        child_state = element_state(tree, :child)
        child_state[] = 42

        hidden_child = tracked_element(:child, mounts, unmounts)
        tree.root = Element(
            nothing;
            key=:container,
            id=:container,
            hidden=true,
            children=(hidden_child,),
        )
        render_tree!(tree)
        @test element_state(tree, :child) === child_state
        @test child_state[] == 42
        @test isempty(unmounts)

        tree.root = Element(
            nothing;
            key=:container,
            id=:container,
            children=(tracked_element(:child, mounts, unmounts),),
        )
        render_tree!(tree)
        @test element_state(tree, :child) === child_state
        @test mounts == [:child]
        @test isempty(unmounts)
    end

    @testset "invalid descriptions have no lifecycle side effects" begin
        mounts = Symbol[]
        unmounts = Symbol[]
        original = tracked_element(:original, mounts, unmounts)
        tree = ToolkitTree(row(original))
        render_tree!(tree)
        original_state = element_state(tree, :original)

        tree.root = row(
            tracked_element(:first, mounts, unmounts; key=:duplicate),
            tracked_element(:second, mounts, unmounts; key=:duplicate),
        )
        @test_throws ArgumentError render_tree!(tree)
        @test mounts == [:original]
        @test isempty(unmounts)
        @test tree.state.instances[first(values(tree.state.ids))].state === original_state

        tree.root = row(
            tracked_element(:first, mounts, unmounts; id=:same),
            tracked_element(:second, mounts, unmounts; id=:same),
        )
        @test_throws ArgumentError render_tree!(tree)
        @test mounts == [:original]
        @test isempty(unmounts)
    end
end
