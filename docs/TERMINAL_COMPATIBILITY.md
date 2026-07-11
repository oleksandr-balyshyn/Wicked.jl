# Terminal Compatibility Evidence

Terminal compatibility has two evidence layers. Automated pseudo-terminal tests
prove lifecycle and byte-level protocol invariants. Manual sessions prove behavior
that depends on a particular emulator, multiplexer, graphics implementation,
transport, font, or operating-system console.

## Automated PTY gate

Run the Unix PTY gate from the repository root:

```sh
julia --project=. --startup-file=no scripts/pty_gate.jl
```

Each scenario starts a new Julia process with real TTY input and output under the
platform's `script` utility. It invokes the child through Julia's documented
`-e 'include(popfirst!(ARGS))'` form so `SIGINT` is delivered as
`InterruptException`. The gate records `stty -g` before and after Wicked and
requires byte-for-byte restoration for:

- Normal application return.
- An application exception.
- An explicit `InterruptException`.
- A real process `SIGINT` delivered while Wicked owns the terminal.

Every scenario also requires paired alternate-screen, cursor, enhanced-keyboard,
bracketed-paste, focus, basic/button-motion/SGR mouse, style, and hyperlink cleanup
sequences. The child verifies that Wicked selected `JuliaTTYController`, cleared
backend lifecycle state, and cleared raw-mode bookkeeping.

### SIGINT policy for application entry points

Julia scripts launched as `julia app.jl` exit directly on `SIGINT` by default and
do not throw `InterruptException`, so ordinary `try`/`finally` cleanup cannot run.
Interactive Wicked entry points launched that way must opt into Julia's capturable
mode before calling `run` or `with_terminal`:

```julia
Base.exit_on_sigint(false)

using Wicked.API
# run(MyApp())
```

Alternatively launch the application through `julia -e
'include(popfirst!(ARGS))' app.jl`. `Base.exit_on_sigint` is process-global, so
Wicked does not change it implicitly. An uncatchable signal, `SIGKILL`, runtime
abort, or process destruction still cannot execute in-process cleanup.

CI runs this gate on current Ubuntu images. Wicked.jl supports Linux terminals.

## Current automated evidence

| Environment | Scenarios | Evidence status |
| --- | ---: | --- |
| Linux util-linux PTY, Julia current | 4 | Runnable through `scripts/pty_gate.jl` |
| GitHub Actions Ubuntu, Julia current | 4 | Enforced by `Terminal PTY / ubuntu-latest` |

CI configuration is evidence only after the corresponding job has run for the
candidate commit. Release records must link the actual run and must not replace a
missing result with this table.

## Required manual matrix

The following entries remain blocking release-candidate evidence. Record the exact
terminal and version rather than checking a category based on an assumed protocol.

| Category | Required observation | Status |
| --- | --- | --- |
| Minimal ANSI / 16 color | No unsupported color or protocol output | Not recorded |
| 256 color | Palette mapping and style restoration | Not recorded |
| Truecolor | RGB foreground, background, underline | Not recorded |
| Kitty or WezTerm | Keyboard, mouse, focus, Kitty graphics | Not recorded |
| Sixel terminal | Image placement and Unicode fallback | Not recorded |
| tmux | Capability downgrade, passthrough, resize | Not recorded |
| GNU screen | Capability downgrade and restoration | Not recorded |
| SSH | Unknown pixel dimensions, latency, disconnect | Not recorded |
| Redirected output | Linear fallback without control leakage | Not recorded |

## Recording a manual result

For each run, archive:

- Wicked commit, Julia version, operating system, architecture, and dependency
  manifest digest.
- Terminal emulator and version, `TERM`, `COLORTERM`, multiplexer, and remote
  transport if present.
- Capabilities enabled or forced off.
- Commands and reference application used.
- Normal, error, interrupt, resize, paste, focus, mouse, Unicode, and graphics
  observations.
- Failures, retries, screenshots or transcripts, and accepted limitations.

An emulator launch without lifecycle and interaction observations is not a passing
result. Automated ANSI-buffer tests and PTY tests cannot establish graphics or
font-rendering correctness on a terminal they did not execute.
