# Terminal Evidence Record

## Record identity

| Field | Value |
| --- | --- |
| Matrix category | Redirected output |
| Wicked commit SHA | 4ae55e07dd17bbacc7afb965863ae591ac4235bc |
| Date and UTC time | 2026-07-14 00:46:29 UTC |
| Julia version | 1.12.6 |
| Linux distribution, kernel, architecture, and shell | Ubuntu 24.04, Linux 7.0.0-27-generic, x86_64, bash |
| Active project and manifest digest | Project.toml and Manifest-v1.12.toml sha a7d71591ec6a888f4d9893c8ad82d7b64b6415e6842962013c7084c491dc77a9 |
| Terminal emulator, version, `TERM`, and `COLORTERM` | dumb, TERM=dumb, COLORTERM=unset |
| Multiplexer and version | none |
| SSH or remote transport details | local |
| Font family and font size | Noto Mono, 11 |
| Command run from the repository root | julia --project=. --startup-file=no scripts/pty_gate.jl |
| Exit status | 0 |
| Transcript, screenshot, recording, or CI artifact URI | docs/terminal-evidence/artifacts/terminal-pty-gate-e73b274.log |

## Behaviors checked

| Behavior | Result |
| --- | --- |
| Startup and shutdown restore terminal modes | Pass |
| Normal exit, thrown error, and interrupt path restore cursor and input modes | Pass |
| Resize redraws without stale cells | Pass |
| Bracketed paste does not corrupt input state | Pass |
| Focus events are parsed or explicitly unavailable | Pass |
| Mouse press, release, wheel, and motion behavior match detected capability | Pass |
| Unicode narrow, wide, combining, emoji, and ambiguous-width text remain aligned | Pass |
| Color fallback does not emit unsupported protocols | Pass |
| Graphics either render through the negotiated protocol or fall back to Unicode | unicode fallback and no raw-mode leakage |
| Kitty or WezTerm graphics placement, clipping, resize, and cleanup checked when applicable | Not applicable |
| Sixel payload emission, clipping, resize, and cleanup checked when applicable | Not applicable |
| Unicode graphics fallback checked when native graphics is unavailable or disabled | Pass |
| Unsupported graphics protocols are not emitted for the detected terminal capability | Pass |
| Redirected or non-interactive output does not leak raw-mode control setup | Pass |

## Evidence summary

The Redirected output terminal evidence relies on PTY sequence restore checks and environment control-path validation from this commit.

## Risks and follow-up

Redirected output behavior is represented by non-interactive transcript checks.
