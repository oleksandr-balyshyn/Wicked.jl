# Getting Started with Wicked.jl

Wicked.jl supports two application styles:

- Immediate mode renders widgets from application state every frame.
- Toolkit mode builds keyed elements with persistent state, routed events, styles, and semantic nodes.

Both styles use the same Core buffers, events, terminal backends, and runtime
commands.

## Install from a checkout

Wicked.jl is currently developed from source. Activate the repository environment,
instantiate it, and load the package:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); using Wicked.API'
```

To use the checkout from another Julia project, register it as a development
dependency:

```julia
import Pkg

Pkg.activate("/path/to/my-application")
Pkg.develop(path="/path/to/Wicked.jl")
using Wicked.API
```

The package loads and precompiles on the active development environment. Stable
release status still depends on the platform and real-terminal evidence tracked in
the release checklist.

## Choose an application model

Use immediate mode when the application already owns its state and needs direct,
predictable rendering.

Use Toolkit when the application needs keyed component state, screens, focus
scopes, routed input, reactive classes, stylesheet selectors, accessibility, or
automation queries.

The models can be mixed. A Toolkit leaf can host an immediate-mode widget, and
rich components eventually render into Core cells.

## Reactive state

Signals are typed from their initial value and belong to one runtime.

```julia
using Wicked.API
using Wicked.Experimental

runtime = ReactiveRuntime()
count = Signal(0; runtime=runtime, name="count")
doubled = computed_signal(value -> value * 2, [count]; runtime=runtime)

subscription = subscribe!(count) do value, previous, source
    @info "count changed" value previous version=signal_version(source)
end

transaction!(runtime) do
    set_signal!(count, 1)
    set_signal!(count, 2)
end

@assert signal_value(doubled) == 4
unsubscribe!(subscription)
dispose!(doubled)
```

A transaction coalesces notifications. If the transaction throws, signal values
and versions return to their pre-transaction state.

## Reactive Toolkit elements

`ReactiveElement` caches an element until a dependency changes. Its invalidation
queue tells the runtime whether render, layout, style, semantics, or subscriptions
must be refreshed.

```julia
queue = ReactiveInvalidationQueue()

element = reactive_element(
    "counter",
    value -> value,
    [count];
    queue=queue,
)

first_value = reactive_element_value!(element)
set_signal!(count, 3)
invalidations = take_invalidations!(queue)
second_value = reactive_element_value!(element)
```

In normal Toolkit use, the builder returns an element rather than a scalar.

## Markdown and rich content

Markdown parsing is separate from terminal rendering.

```julia
document = parse_markdown("# Status\n\nBuild: **running**")
rich = render_markdown(document; width=60)
text = plain_text(rich)
```

Use `MarkdownView` when scrolling, links, selection, reflow, or keyboard actions
are required.

```julia
view = MarkdownView("[Project](https://example.com)"; width=60)
viewport = markdown_viewport(view, 10)
focus_next_link!(view)
activation = activate_focused_link(view)
```

Link activation returns data. Wicked.jl does not open a browser implicitly.

## Large data

Use a paged data source when row data is remote or expensive.

```julia
loader = function (page, page_size, generation, query)
    first_index = (page - 1) * page_size + 1
    values = collect(first_index:(first_index + page_size - 1))
    PageResult(values; total_length=10_000)
end

source = PagedDataSource{Int,Int}(
    loader;
    key=(item, index) -> item,
    page_size=100,
    max_cached_pages=16,
    max_inflight_pages=2,
)

state = VirtualListState{Int}(viewport_size=20, overscan=5)
window = refresh_virtual_list!(source, state)
```

The first window may contain loading slots. Poll completions through subsequent
runtime messages or refresh calls; do not block the render path waiting for data.

## Accessibility and automation

Every interactive component should expose a semantic node or tree. Validate it
before publishing it to automation or assistive integrations.

```julia
root = SemanticNode(
    "app",
    ApplicationRole;
    label="Example",
    children=[
        SemanticNode(
            "submit",
            ButtonRole;
            label="Submit",
            state=SemanticState(focusable=true),
            actions=[ActivateSemanticAction],
        ),
    ],
)

tree = SemanticTree(root; generation=1)
diagnostics = validate_semantics(tree)
```

Duplicate IDs, impossible focus state, invalid value ranges, and unlabeled
interactive nodes are diagnostics.

## Reliability boundary

Terminal restoration and background tasks should be owned by an outer resource
scope.

```julia
with_resource_scope() do scope
    resource = acquire_resource!(
        scope,
        () -> open("output.log", "w"),
        close;
        label="output log",
    )
    write(resource, "started\n")
end
```

Error boundaries can contain a component failure and provide a fallback while
recording the complete error and backtrace.

## Next reading

- `docs/IMMEDIATE_MODE_TUTORIAL.md` builds an immediate-mode interface.
- `docs/TOOLKIT_TUTORIAL.md` builds a keyed declarative application.
- `docs/ASYNC_RUNTIME.md` covers commands, subscriptions, and cancellation.
- `docs/ACCESSIBILITY_TESTING.md` covers semantic trees and headless pilots.
- `API_REFERENCE.md` defines public API conventions and capabilities.
- `FEATURE_PARITY.md` records implementation evidence and intentional deltas.
- `docs/ARCHITECTURE.md` explains layering and production gates.
- `docs/COMPONENT_CATALOG.md` lists the component surface.
- `docs/DEVELOPER_GUIDE.md` covers framework-level design rules.
