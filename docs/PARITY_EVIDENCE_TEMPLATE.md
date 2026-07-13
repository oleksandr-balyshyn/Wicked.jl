# Parity Evidence Record Template

Use this template when closing an adapted parity family from
`REFERENCE_PARITY_SURVEY.md`. One record should describe one release-candidate
run for one family and one environment class.

Do not mark a release-checklist parity item complete unless every required
behavior in that item is covered by attached records.

## Record identity

| Field | Value |
| --- | --- |
| Family | Layout / Input-event / Stateful-controls / Data-display / Runtime / Developer-experience / Styling-theming / Remote-delivery |
| Release-candidate commit | short or full git commit SHA |
| Date and UTC time | YYYY-MM-DD HH:MM:SS UTC |
| Julia version | Julia version, for example 1.10.11 or 1.12.6 |
| Kernel and distribution | Linux kernel and distribution |
| Terminal or browser environment | |
| Width policy and color capability | |
| Command | |
| Exit status | non-negative integer process exit code |
| Artifact path or CI URL | |

## Behaviors checked

List the concrete behaviors exercised by this record. Use exact wording from
`RELEASE_CHECKLIST.md` when possible. Use one of the reviewed family names listed
in `docs/evidence/README.md`.

- 

## Reference-library parity notes

Describe how the observed behavior maps to Ratatui, Textual, TamboUI, or
Lanterna. Record intentional divergences explicitly.

- 

## Evidence summary

Record the observed result. Include test counts, snapshot IDs, benchmark artifact
names, browser client version, terminal emulator version, or manual transcript
paths when applicable.

- 

## Risks and follow-up

Record any behavior that remains incomplete, platform-specific, manually
inspected, or dependent on follow-up hardening.

- 
