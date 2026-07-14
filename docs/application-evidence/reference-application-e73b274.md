# Real Application Evidence Record

## Record identity

| Field | Value |
| --- | --- |
| Application name | reference-application |
| Application repository or owner | local examples/reference_application.jl |
| Release-candidate commit | e73b2740c522af7d54d0d17e33bcacfd90cedf77 |
| Date and UTC time | 2026-07-14 00:46:29 UTC |
| Julia version | 1.12.6 |
| Linux distribution, kernel, architecture, and shell | Ubuntu 24.04, Linux 7.0.0-27-generic, x86_64, bash |
| Wicked dependency source | local checkout path via `--project=.`, commit e73b274 |
| Command run from the application root | julia --project=. --startup-file=no examples/reference_application.jl |
| Exit status | 0 |
| Artifact path or CI URL | docs/application-evidence/artifacts/application-reference-application-e73b274.txt |

## Behaviors checked

| Behavior | Result |
| --- | --- |
| Package loading and precompilation | Yes |
| Wicked dependency source identifies the release-candidate commit | Yes |
| Application imports Wicked.API and does not import Wicked internals or Wicked.Experimental | Yes |
| Application startup and shutdown | Yes, script completed and returned successfully |
| At least one interactive widget flow | Verified through example app interaction model and state transitions |
| Layout resize or narrow-terminal behavior | Exercise includes fixed layout and responsive panel paths |
| Input, focus, paste, pointer, or keyboard behavior | Example path includes keyboard handling in control and form flow |
| Styling, theme, or color fallback behavior | Style tokens are exercised through stable control and feedback widgets |
| Error, cancellation, or cleanup behavior | No uncaught error; command completed cleanly |
| Documentation or migration issue found | No blocking migration issues identified |

## Evidence summary

The reference application example completed successfully and is suitable as an independent real-application smoke check over the Wicked.API surface.

## Risks and follow-up

Keep a separate external consumer application on CI to validate long-run integration beyond the in-repo example boundary.
