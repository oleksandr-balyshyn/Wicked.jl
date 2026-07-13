# Real Application Evidence Record Template

Use this template for one independent real application tested against an
immutable Wicked release-candidate commit. Store completed records under
`docs/application-evidence/`; keep drafts outside the repository.

## Record identity

| Field | Value |
| --- | --- |
| Application name | |
| Application repository or owner | |
| Release-candidate commit | short or full git commit SHA |
| Date and UTC time | YYYY-MM-DD HH:MM:SS UTC |
| Julia version | Julia version, for example 1.10.11 or 1.12.6 |
| Linux distribution, kernel, architecture, and shell | |
| Wicked dependency source | local path, registry version, or git SHA |
| Command run from the application root | |
| Exit status | non-negative integer process exit code |
| Artifact path or CI URL | |

## Behaviors checked

Record the behaviors the application exercised.

| Behavior | Result |
| --- | --- |
| Package loading and precompilation | |
| Wicked dependency source identifies the release-candidate commit | |
| Application imports Wicked.API and does not import Wicked internals or Wicked.Experimental | |
| Application startup and shutdown | |
| At least one interactive widget flow | |
| Layout resize or narrow-terminal behavior | |
| Input, focus, paste, pointer, or keyboard behavior | |
| Styling, theme, or color fallback behavior | |
| Error, cancellation, or cleanup behavior | |
| Documentation or migration issue found | |

## Evidence summary

Record the observed result, test count, transcript, CI run, screenshot, or
application-specific acceptance notes.

- 

## Risks and follow-up

Record application-specific gaps, accepted risks, or migration work before
release.

- 
