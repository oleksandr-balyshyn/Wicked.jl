# Wicked Examples

Run examples from the repository root:

```sh
julia --project=. examples/application_services.jl
julia --project=. examples/tabbed_content.jl
julia --project=. examples/progress_notifications.jl
julia --project=. examples/live_reload.jl
julia --project=. examples/reference_application.jl
```

These examples use deterministic clocks and assertions so they can also serve as
starting points for application tests. They exercise public APIs only and do not
take over the terminal.

`reference_application.jl` is the release-acceptance composition example. It uses a
managed application, tabs, a selectable table, synchronous and asynchronous form
validation, a confirmation dialog, theme switching, successful and failing
background work, error recovery, headless rendering, and application exit through
public APIs.
