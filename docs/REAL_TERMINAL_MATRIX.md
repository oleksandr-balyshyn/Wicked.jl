# Linux Real-Terminal Matrix

This worksheet defines the manual terminal evidence required before Wicked can
claim production terminal parity. It is not evidence by itself. Each row becomes
evidence only after a release-candidate commit has an attached transcript,
screenshot, CI URL, or parity evidence record.

## Scope

Wicked supports Linux terminals. Do not record non-Linux operating systems in
this matrix. Remote sessions, multiplexers, and browser delivery are acceptable
only when the Wicked process or remote adapter under test runs from a Linux
environment.

## Required identity fields

Record these fields for every run:

- Wicked commit SHA.
- Julia version.
- Linux distribution, kernel, architecture, and shell.
- Active project and manifest digest.
- Terminal emulator, version, `TERM`, and `COLORTERM`.
- Multiplexer and version, or `none`.
- SSH or remote transport details, or `local`.
- Font family and font size when glyph or image behavior is evaluated.
- Command run from the repository root.
- Exit status.
- Transcript, screenshot, recording, or CI artifact URI.

## Required behavior fields

Every terminal-category row must cover:

- Startup and shutdown restore terminal modes.
- Normal exit, thrown error, and interrupt path restore cursor and input modes.
- Resize redraws without stale cells.
- Bracketed paste does not corrupt input state.
- Focus events are parsed or explicitly unavailable.
- Mouse press, release, wheel, and motion behavior match detected capability.
- Unicode narrow, wide, combining, emoji, and ambiguous-width text remain aligned.
- Color fallback does not emit unsupported protocols.
- Graphics either render through the negotiated protocol or fall back to Unicode.
- Redirected or non-interactive output does not leak raw-mode control setup.

## Matrix

| Category | Example environments | Required observation | Evidence status |
| --- | --- | --- | --- |
| Minimal ANSI / 16 color | `TERM=xterm`, forced 16-color profile | Basic styles downgrade; no truecolor, Kitty, or Sixel output | Recorded |
| 256 color | `xterm-256color` profile | Palette mapping, reset, and style restoration | Recorded |
| Truecolor | `COLORTERM=truecolor` terminal | RGB foreground, background, underline, and reset | Recorded |
| Kitty / WezTerm | Kitty or WezTerm on Linux | Enhanced keyboard, focus, SGR mouse, Kitty graphics placement, clipping, resize, cleanup, and fallback when disabled | Recorded |
| Sixel terminal | Sixel-capable terminal on Linux | Sixel payload emission, image placement, clipping, cleanup, and Unicode fallback | Recorded |
| tmux | tmux session on Linux | Capability downgrade, passthrough, paste, mouse, resize | Recorded |
| GNU screen | screen session on Linux | Capability downgrade and terminal restoration | Recorded |
| SSH | SSH into Linux with unknown pixel dimensions | Latency, disconnect, resize, fallback capabilities | Recorded |
| Redirected output | pipe/file redirection | Linear fallback without raw-mode setup leakage | Recorded |

## Pass criteria

A row passes only when:

- The run uses an immutable release-candidate commit.
- The command, environment, and artifact are recorded.
- The artifact proves every required behavior field for that category.
- Any failure is either fixed or recorded as an accepted known risk in
  `RELEASE_EVIDENCE.md`.

## Recommended command set

Use the application or example that best exercises the target capability, then
record the exact command. At minimum, include:

```sh
julia --project=. --startup-file=no scripts/pty_gate.jl
julia --project=. --startup-file=no examples/widget_gallery.jl
julia --project=. --startup-file=no examples/reference_application.jl
julia --project=. --startup-file=no examples/progress_notifications.jl
```

If an example does not exist for the target capability, record the replacement
command and why it covers the same behavior.

Use [Terminal Evidence Record Template](TERMINAL_EVIDENCE_TEMPLATE.md) for each
manual result before linking it from release evidence.
Completed records belong in [Terminal Evidence Records](terminal-evidence/README.md)
and are checked by `scripts/terminal_evidence_audit.jl`.
