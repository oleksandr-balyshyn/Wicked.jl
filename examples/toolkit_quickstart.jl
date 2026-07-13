using Wicked.API

function deployment_view(status)
    return column(
        Element(Label("Deployment: $status"); id=:status, key=:status),
        Element(
            Button("Deploy", :deploy);
            id=:deploy,
            key=:deploy,
            classes=[:primary],
            focusable=true,
        ),
        Element(
            Checkbox("Remember choice");
            id=:remember,
            key=:remember,
            focusable=true,
        );
        constraints=[Length(1), Length(3), Length(1)],
        gap=0,
    )
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

println("toolkit quickstart example completed")
