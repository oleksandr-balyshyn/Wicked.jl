# Terminal Recovery

Wicked restores terminal state through `with_terminal` and `run` during normal return, application exit, exceptions, capturable `InterruptException`s, and partial initialization failures. A process that receives an uncatchable signal, loses its controlling terminal, or is terminated by the Linux process supervisor cannot execute Julia cleanup code.

Julia scripts launched as `julia app.jl` exit directly on `SIGINT` by default.
Call `Base.exit_on_sigint(false)` before entering Wicked, or launch through Julia's
documented `-e 'include(popfirst!(ARGS))' app.jl` form, when Ctrl-C must unwind
through Wicked's cleanup. Wicked does not mutate this process-global Julia policy.

## Manual reset

Call `reset_terminal!` when a previous process leaves raw input, mouse reporting, bracketed paste, focus reporting, synchronized updates, cursor visibility, styling, hyperlinks, or alternate-screen mode active:

```julia
using Wicked.API

reset_terminal!()
```

The helper does not clear the visible main screen. It restores common terminal protocols, resets cursor shape and visibility, exits the alternate screen, and writes a fresh line for the shell prompt.

If an application still owns its backend or terminal, reset that value so Wicked also clears lifecycle bookkeeping and forces a complete next frame:

```julia
using Wicked.API

reset_terminal!(terminal)
```

## Redirected output

The stream overload emits recovery sequences only when the output is a TTY. Pass `force=true` only when the stream is known to terminate at an ANSI-compatible terminal:

```julia
using Wicked.API

reset_terminal!(stderr; force=true)
```

`InlineBackend` recovery leaves alternate-screen mode unchanged because inline applications render on the main screen.

## Shell fallback

If Julia cannot run, use the Linux shell's terminal reset facilities. `stty sane`
restores common line settings and `reset` performs a broader terminal
reinitialization. Terminal emulators also provide a reset action in their menus
or command palettes.

No in-process library can recover from `SIGKILL`, power loss, terminal emulator failure, or forced process destruction before cleanup runs. Keep `with_terminal` or `run` as the outermost interactive lifecycle boundary and reserve `reset_terminal!` for manual recovery.
