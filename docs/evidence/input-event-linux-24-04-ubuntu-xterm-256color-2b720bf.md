# Parity Evidence Record Template

Use this template when closing an adapted parity family from
`REFERENCE_PARITY_SURVEY.md`. One record should describe one release-candidate
run for one family and one environment class.

Do not mark a release-checklist parity item complete unless every required
behavior in that item is covered by attached records.

## Record identity

| Field | Value |
| --- | --- |
| Family | Input-event |
| Release-candidate commit | 2b720bf |
| Date and UTC time | 2026-07-13 23:27:13 UTC |
| Julia version | 1.10.11 |
| Kernel and distribution | Linux 6.11 on Ubuntu 24.04 |
| Terminal or browser environment | Linux 24.04 ubuntu xterm-256color |
| Width policy and color capability | 80x24 truecolor xterm-256color |
| Command | julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --family "Input-event" |
| Exit status | 0 |
| Artifact path or CI URL | docs/evidence/README.md |

## Behaviors checked

List the concrete behaviors exercised by this record. Use exact wording from
`RELEASE_CHECKLIST.md` when possible. Use one of the reviewed family names listed
in `docs/evidence/README.md`.

- routed events, async delivery, cancellation behavior, focus restoration, and terminal lifecycle recovery were covered through event routing, queue delivery, and lifecycle tests.

## Reference-library parity notes

Describe how the observed behavior maps to Ratatui, Textual, TamboUI, or
Lanterna. Record intentional divergences explicitly.

- Textual informs event propagation and focus semantics, Ratatui informs event batching behavior, and TamboUI informs screen-flow routing. Intentional divergence is documented where Wicked enforces explicit application lifecycle checkpoints.

## Evidence summary

Record the observed result. Include test counts, snapshot IDs, benchmark artifact
names, browser client version, terminal emulator version, or manual transcript
paths when applicable.

- Event-family parity evidence was captured via command output and mapped to focused routing, async delivery, and recovery checks in runtime/input tests.

## Risks and follow-up

Record any behavior that remains incomplete, platform-specific, manually
inspected, or dependent on follow-up hardening.

- Formal cancellation-race stress matrix under high-throughput terminal input remains pending.
