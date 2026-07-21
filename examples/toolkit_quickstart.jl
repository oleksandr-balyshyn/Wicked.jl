using Wicked.API

const FOCUSABLE_CONTROL = element_modifier(focusable=true)
const PRIMARY_CONTROL = then(
    FOCUSABLE_CONTROL,
    element_modifier(classes=[:primary], style_role=:primary),
)
@assert PRIMARY_CONTROL isa ElementModifier

function deployment_view(status)
    return @ui column(; constraints=[Length(1), Length(3), Length(1)], gap=0) do
        Element(Label("Deployment: $status"); id=:status, key=:status)
        element(
            Button("Deploy", :deploy);
            id=:deploy,
            key=:deploy,
            modifier=PRIMARY_CONTROL,
        )
        element(
            Checkbox("Remember choice");
            id=:remember,
            key=:remember,
            modifier=FOCUSABLE_CONTROL,
        )
    end
end

pilot = ToolkitPilot(deployment_view("ready"); height=5, width=32)
@assert occursin("Deployment: ready", plain_snapshot(pilot))

focus_element!(pilot, :deploy)
key!(pilot, :enter)
deploy = query_one(pilot; id=:deploy, widget_type=Button, focused=true)
@assert deploy.state isa ButtonState
@assert :deploy in pilot.messages

focus_element!(pilot, :remember)
key!(pilot, :enter)
remember = query_one(pilot; id=:remember, widget_type=Checkbox, focused=true)
@assert remember.state isa CheckboxState

# Family tokens: ToolkitTree, StyleEngine

original_state = element_state(pilot.tree, :deploy)
pilot.tree.root = deployment_view("running")
draw!(pilot)
@assert element_state(pilot.tree, :deploy) === original_state
@assert occursin("Deployment: running", plain_snapshot(pilot))

instance = element_instance(pilot.tree, :deploy)
@assert instance !== nothing
@assert instance.element.key == :deploy

semantics = toolkit_semantic_tree(pilot.tree; label="Deployment")
@assert isempty(filter(diagnostic -> diagnostic.severity == :error, validate_semantics(semantics)))
@assert occursin("deploy:ButtonRole", semantic_snapshot(semantics))
@assert occursin("remember:CheckboxRole", semantic_snapshot(semantics))

component_lifecycle = Any[]
counter = component(
    initial=0,
    key=:counter,
    id=:counter,
    on_unmount=state -> push!(component_lifecycle, (:unmount, component_value(state))),
) do state
    count = component_value(state)
    use_effect!(state, :count, (count,)) do _
        push!(component_lifecycle, (:setup, count))
        return () -> push!(component_lifecycle, (:cleanup, count))
    end
    return "Local count: $count"
end
counter_tree = ToolkitTree(counter)
@assert counter.widget isa StatefulComponent
counter_buffer = Buffer(1, 24)
render!(counter_buffer, counter_tree, counter_buffer.area)
counter_state = element_state(counter_tree, :counter)
@assert counter_state isa ComponentState
@assert occursin("Local count: 0", plain_snapshot(counter_buffer))
set_component_value!(counter_state, 1)
@assert component_version(counter_state) == 1
@assert component_invalidated(counter_state)
@assert toolkit_invalidated(counter_tree)
render!(counter_buffer, counter_tree, counter_buffer.area)
@assert !toolkit_invalidated(counter_tree)
@assert component_lifecycle == [(:setup, 0), (:cleanup, 0), (:setup, 1)]
counter_tree.root = element(Label("Counter removed"))
render!(counter_buffer, counter_tree, counter_buffer.area)
@assert component_lifecycle[end-1:end] == [(:unmount, 1), (:cleanup, 1)]

density = composition_local(:density, 1; value_type=Real)
panel_content = component_slots("Body"; header="Settings", actions="Save")
contextual_panel = provide_context(density => 2) do
    component() do state
        column(
            slot(panel_content, :header)...,
            "Density: $(composition_value(state, density))",
            slot(panel_content)...,
            slot(panel_content, :actions)...;
            constraints=fill(Length(1), 4),
        )
    end
end
panel_buffer = Buffer(4, 24)
render!(panel_buffer, contextual_panel, panel_buffer.area)
@assert plain_snapshot(panel_buffer) == "Settings\nDensity: 2\nBody\nSave"

println("toolkit quickstart example completed")
