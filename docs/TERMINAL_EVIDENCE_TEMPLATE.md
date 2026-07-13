# Terminal Evidence Record Template

Use this template for one Linux real-terminal matrix run from an immutable
release-candidate commit. Store completed records with the release artifacts or
link them from release evidence; incomplete drafts should stay outside the
repository.

## Record identity

| Field | Value |
| --- | --- |
| Matrix category | Minimal ANSI / 16 color / 256 color / Truecolor / Kitty / WezTerm / Sixel terminal / tmux / GNU screen / SSH / Redirected output |
| Wicked commit SHA | short or full git commit SHA |
| Date and UTC time | YYYY-MM-DD HH:MM:SS UTC |
| Julia version | Julia version, for example 1.10.11 or 1.12.6 |
| Linux distribution, kernel, architecture, and shell | |
| Active project and manifest digest | |
| Terminal emulator, version, `TERM`, and `COLORTERM` | |
| Multiplexer and version | `none` when not used |
| SSH or remote transport details | `local` when not used |
| Font family and font size | required when glyph or image behavior is evaluated |
| Command run from the repository root | |
| Exit status | non-negative integer process exit code |
| Transcript, screenshot, recording, or CI artifact URI | |

## Behaviors checked

Record the concrete result for every required behavior from
`REAL_TERMINAL_MATRIX.md`.

| Behavior | Result |
| --- | --- |
| Startup and shutdown restore terminal modes | |
| Normal exit, thrown error, and interrupt path restore cursor and input modes | |
| Resize redraws without stale cells | |
| Bracketed paste does not corrupt input state | |
| Focus events are parsed or explicitly unavailable | |
| Mouse press, release, wheel, and motion behavior match detected capability | |
| Unicode narrow, wide, combining, emoji, and ambiguous-width text remain aligned | |
| Color fallback does not emit unsupported protocols | |
| Graphics either render through the negotiated protocol or fall back to Unicode | |
| Kitty or WezTerm graphics placement, clipping, resize, and cleanup checked when applicable | |
| Sixel payload emission, clipping, resize, and cleanup checked when applicable | |
| Unicode graphics fallback checked when native graphics is unavailable or disabled | |
| Unsupported graphics protocols are not emitted for the detected terminal capability | |
| Redirected or non-interactive output does not leak raw-mode control setup | |

## Evidence summary

Record the observed terminal behavior, artifact names, transcript paths,
screenshots, recordings, and any command retries.

- 

## Risks and follow-up

Record failures, accepted known risks, terminal-specific limitations, or follow-up
work. Link any accepted risk from `RELEASE_EVIDENCE.md`.

- 
