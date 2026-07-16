# Parity Evidence Record Template

Use this template when closing an adapted parity family from
`REFERENCE_PARITY_SURVEY.md`. One record should describe one release-candidate
run for one family and one environment class.

Do not mark a release-checklist parity item complete unless every required
behavior in that item is covered by attached records.

## Record identity

| Field | Value |
| --- | --- |
| Family | Styling-theming |
| Release-candidate commit | 2b720bf |
| Date and UTC time | 2026-07-13 23:27:13 UTC |
| Julia version | 1.10.11 |
| Kernel and distribution | Linux 6.11 on Ubuntu 24.04 |
| Terminal or browser environment | Linux 24.04 ubuntu xterm-256color |
| Width policy and color capability | 80x24 truecolor xterm-256color |
| Command | julia --project=. --startup-file=no scripts/render_reference_parity_matrix.jl --family "Styling/theming" |
| Exit status | 0 |
| Artifact path or CI URL | docs/evidence/README.md |

## Behaviors checked

List the concrete behaviors exercised by this record. Use exact wording from
`RELEASE_CHECKLIST.md` when possible. Use one of the reviewed family names listed
in `docs/evidence/README.md`.

- selector specificity, cascade order, role downgrade behavior, diagnostics, and monochrome fallback were verified via style engine and rendering validation paths.

## Reference-library parity notes

Describe how the observed behavior maps to Ratatui, Textual, TamboUI, or
Lanterna. Record intentional divergences explicitly.

- TamboUI and Textual influenced styling priority and role mapping expectations; Ratatui patterns were adapted for deterministic cascade semantics. intentional divergence is explicit where Wicked defaults differ for terminal monochrome modes.

## Evidence summary

Record the observed result. Include test counts, snapshot IDs, benchmark artifact
names, browser client version, terminal emulator version, or manual transcript
paths when applicable.

- Styling/theming behavior evidence includes diagnostics and fallback checks through style and toolkit semantics tests with explicit adaptation notes.

## Risks and follow-up

Record any behavior that remains incomplete, platform-specific, manually
inspected, or dependent on follow-up hardening.

- Need broader diagnostics and monochrome fallback validation in additional terminals and CI emulators.
