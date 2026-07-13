# Reference Application

`examples/reference_application.jl` is Wicked's deterministic composition example.
It is intentionally larger than the focused examples and runs in CI without taking
over a terminal.

The example imports `Wicked.API` and uses reviewed public contracts only. It does
not depend on `Wicked.Experimental`.

The application demonstrates:

- A `WickedApp` model, update function, view value, and managed commands.
- Keyboard navigation across `Tabs` and rows in a selectable `Table`.
- A `Form` with synchronous required validation and asynchronous environment
  validation.
- `DialogState` lifecycle with explicit confirmation.
- Runtime theme switching through `ThemeRegistry`.
- Successful `TaskCommand` result delivery and isolated background failure mapping.
- Header, footer, alerts, validation summaries, layout regions, and style overrides.
- Deterministic interaction and screen assertions through `RuntimePilot`.
- A typed application result returned through `ExitCommand`.

Run it from the repository root:

```sh
julia --project=. --startup-file=no examples/reference_application.jl
```

The scenario first loads deployment rows, navigates to settings, proves invalid and
valid form submissions, opens and confirms a deployment dialog, changes theme,
recovers from an injected background failure, and exits with a summary value. Every
step asserts model state or rendered text, so a silent behavioral regression fails
the executable-examples CI job.

## Why the example is headless

The production runtime and terminal lifecycle already have independent runtime,
backend, ANSI, PTY, and restoration gates. This example isolates application
composition from terminal timing and user input. Replace `RuntimePilot` with
`run(ReferenceApp())` to use the same model, update, view, widgets, and commands in
an interactive entry point.

For a non-interactive Julia script that must unwind cleanly on Ctrl-C, call
`Base.exit_on_sigint(false)` before `run`, as described in
[Terminal Compatibility Evidence](TERMINAL_COMPATIBILITY.md).
