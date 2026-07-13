# Parity Evidence Record Template

Use this template when closing an adapted parity family from
`REFERENCE_PARITY_SURVEY.md`. One record should describe one release-candidate
run for one family and one environment class.

Do not mark a release-checklist parity item complete unless every required
behavior in that item is covered by attached records.

## Record identity

| Field | Value |
| --- | --- |
| Family | Remote-delivery |
| Release-candidate commit | 2b720bf |
| Date and UTC time | 2026-07-13 23:27:13 UTC |
| Julia version | 1.10.11 |
| Kernel and distribution | Linux 6.11 on Ubuntu 24.04 |
| Terminal or browser environment | Linux 24.04 ubuntu xterm-256color |
| Width policy and color capability | 80x24 truecolor xterm-256color |
| Command | julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --family "Remote delivery" |
| Exit status | 0 |
| Artifact path or CI URL | docs/evidence/README.md |

## Behaviors checked

List the concrete behaviors exercised by this record. Use exact wording from
`RELEASE_CHECKLIST.md` when possible. Use one of the reviewed family names listed
in `docs/evidence/README.md`.

- browser deployment, WebSocket hardening, protocol versioning, security policy, real-client compatibility for transport and API surface.

## Reference-library parity notes

Describe how the observed behavior maps to Ratatui, Textual, TamboUI, or
Lanterna. Record intentional divergences explicitly.

- Textual remote delivery expectations informed protocol-level UX and lifecycle mapping. TamboUI and Ratatui informed event transport expectations; intentional divergence is expected while Wicked’s remote stack is still experimental.

## Evidence summary

Record the observed result. Include test counts, snapshot IDs, benchmark artifact
names, browser client version, terminal emulator version, or manual transcript
paths when applicable.

- Remote-delivery parity record is currently based on current protocol/transport scaffolding and parity matrix direction; command output confirms matrix mapping but broader end-to-end deployment matrix is pending.

## Risks and follow-up

Record any behavior that remains incomplete, platform-specific, manually
inspected, or dependent on follow-up hardening.

- Missing browser-side real-client runs, WebSocket fuzzing, and security hardening evidence requires explicit follow-up before production release.
