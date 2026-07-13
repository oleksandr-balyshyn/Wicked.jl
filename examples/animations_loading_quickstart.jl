using Wicked.API

buffer = Buffer(18, 78)

render!(buffer, Heading("Animations and loading quickstart"; level=1), Rect(1, 1, 2, 78))

manager = AnimationManager()
value = Ref(0.0)
animate!(
    manager,
    AnimationSpec(AnimationTrack(0.0, 1.0); duration=0.2, key=:progress);
    on_update=updated -> (value[] = updated),
    now_ns=UInt64(0),
)

updates = tick_animations!(manager; now_ns=UInt64(100_000_000))
render!(buffer, Label("AnimationManager"), Rect(4, 1, 1, 34))
render!(buffer, Gauge(value[]; label="animated $(round(Int, value[] * 100))%"), Rect(5, 1, 3, 34))

loading_dispatcher = SemanticDispatcher()

spinner = Spinner(label="Loading")
spinner_state = state_for(spinner)
register_spinner_semantic_handlers!(loading_dispatcher, :spinner, spinner, spinner_state)
handle!(spinner_state, spinner, TickEvent(UInt64(16_000_000), UInt64(16_000_000)))
render!(buffer, Label("Spinner"), Rect(9, 1, 1, 34))
render!(buffer, spinner, Rect(10, 1, 1, 34), spinner_state)

loading = LoadingIndicator(label="Working")
loading_state = state_for(loading)
register_loading_indicator_semantic_handlers!(loading_dispatcher, :loading, loading, loading_state)
handle!(loading_state, loading, TickEvent(UInt64(32_000_000), UInt64(16_000_000)))
render!(buffer, Label("LoadingIndicator"), Rect(12, 1, 1, 34))
render!(buffer, loading, Rect(13, 1, 1, 34), loading_state)

skeleton = Skeleton()
skeleton_state = state_for(skeleton)
register_skeleton_semantic_handlers!(loading_dispatcher, :skeleton, skeleton, skeleton_state)
tick_skeleton!(skeleton_state, 3)
render!(buffer, Label("Skeleton"), Rect(4, 42, 1, 34))
render!(buffer, skeleton, Rect(5, 42, 4, 34), skeleton_state)

placeholder = Placeholder("Results")
register_placeholder_semantic_handlers!(loading_dispatcher, :placeholder, placeholder)
render!(buffer, Label("Placeholder"), Rect(14, 42, 1, 34))
render!(buffer, placeholder, Rect(15, 42, 2, 34))

lines = render_skeleton(SkeletonState(), 24, 2; highlight_width=3)
render!(buffer, Label("render_skeleton helper"), Rect(10, 42, 1, 34))
render!(buffer, Paragraph(join(lines, "\n"); wrap=NoWrap), Rect(11, 42, 2, 34))

render!(
    buffer,
    Paragraph("updates: $(length(updates)) value: $(round(value[]; digits=2))"; wrap=NoWrap),
    Rect(15, 1, 1, 76),
)

snapshot = plain_snapshot(buffer)
@assert occursin("Animations and loading quickstart", snapshot)
@assert occursin("AnimationManager", snapshot)
@assert occursin("animated 50%", snapshot)
@assert occursin("Spinner", snapshot)
@assert occursin("Loading", snapshot)
@assert occursin("LoadingIndicator", snapshot)
@assert occursin("Working", snapshot)
@assert occursin("Skeleton", snapshot)
@assert occursin("render_skeleton helper", snapshot)
@assert occursin("Placeholder", snapshot)
@assert occursin("updates: 1 value: 0.5", snapshot)

println("animations and loading quickstart example completed")
