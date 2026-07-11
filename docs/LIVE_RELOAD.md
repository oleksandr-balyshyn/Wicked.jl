# Live Reload

`LiveReloadManager` reloads stylesheets, themes, configuration, content, and other
developer assets without creating background tasks. Poll it from the application
runtime so file observation, state changes, and rendering remain deterministic.

## Register a target

```julia
reloads = LiveReloadManager()

register_reload_target!(
    reloads,
    :application_styles,
    ["styles/application.wss"];
    loader=paths -> parse_stylesheet(read(only(paths), String)),
    apply=stylesheet -> set_stylesheets!(style_engine, [stylesheet]),
    debounce=0.1,
    load_initial=true,
)
```

A target may own one path string or multiple files. Paths are normalized to
absolute paths, deduplicated, and sorted. The loader receives the complete path
vector and constructs a candidate value. The apply callback commits that candidate
to application state.

## Poll from the runtime

```julia
for event in poll_reloads!(reloads)
    event.outcome == ReloadApplied && request_render!()
end
```

Polling uses file size and modification time to detect changes. A changed target
enters `PendingReload` until its debounce interval expires, then moves through
`LoadingReload` and `ApplyingReload`. Loader and apply callbacks execute outside
the manager lock.

Only one poll may run at a time. The manager accepts an injected nanosecond clock,
so debounce behavior is deterministic in tests.

## Missing files

Choose one policy per target:

- `IgnoreMissingFiles` discards the pending change.
- `WaitForMissingFiles` waits for all files to appear.
- `FailOnMissingFiles` records a `ReloadMissing` event.

Waiting is the default because editors commonly replace files through rename and
write sequences.

## Manual reload and lifecycle

```julia
trigger_reload!(reloads, :application_styles)
set_reload_enabled!(reloads, :application_styles, false)
unregister_reload_target!(reloads, :application_styles)
```

Targets cannot be replaced, disabled, or removed while their loader or apply phase
is active. This prevents a stale callback from committing after lifecycle teardown.

## Failure handling

Loader, apply, filesystem, and missing-file failures become `ReloadEvent` values
and are retained by `take_reload_errors!`. The manager returns to `WatchingReload`
after failure, preserving the last successfully applied application state when the
apply callback itself is transactional.

For stylesheet and theme updates, parse and validate a complete replacement before
the apply callback swaps it into the style engine. Do not mutate the live engine
incrementally from the loader.
