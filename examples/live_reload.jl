using Wicked.API
using Wicked.Experimental

clock_value = Ref(UInt64(0))
clock = () -> clock_value[]
applied = Ref("")

mktempdir() do directory
    path = joinpath(directory, "theme.txt")
    write(path, "first")

    reloads = LiveReloadManager(; clock=clock)
    register_reload_target!(
        reloads,
        :theme,
        path;
        loader=paths -> read(only(paths), String),
        apply=value -> (applied[] = value),
        debounce=0.0,
    )

    write(path, "second")
    trigger_reload!(reloads, :theme)
    events = poll_reloads!(reloads)

    @assert length(events) == 1
    @assert only(events).outcome == ReloadApplied
    @assert applied[] == "second"
    @assert reload_target_state(reloads, :theme) == WatchingReload
end

println("live reload example completed")
