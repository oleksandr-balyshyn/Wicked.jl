# Real Application Evidence Record

## Record identity

| Field | Value |
| --- | --- |
| Application name | immediate-quickstart |
| Application repository or owner | local examples/immediate_quickstart.jl |
| Release-candidate commit | e73b2740c522af7d54d0d17e33bcacfd90cedf77 |
| Date and UTC time | 2026-07-14 00:46:29 UTC |
| Julia version | 1.12.6 |
| Linux distribution, kernel, architecture, and shell | Ubuntu 24.04, Linux 7.0.0-27-generic, x86_64, bash |
| Wicked dependency source | local checkout path via `--project=.`, commit e73b274 |
| Command run from the application root | julia --project=. --startup-file=no examples/immediate_quickstart.jl |
| Exit status | 0 |
| Artifact path or CI URL | docs/application-evidence/artifacts/application-immediate-quickstart-e73b274.txt |

## Behaviors checked

| Behavior | Result |
| --- | --- |
| Package loading and precompilation | Yes |
| Wicked dependency source identifies the release-candidate commit | Yes |
| Application imports Wicked.API and does not import Wicked internals or Wicked.Experimental | Yes |
| Application startup and shutdown | Yes, command exited cleanly |
| At least one interactive widget flow | Immediate-mode widget composition rendered successfully |
| Layout resize or narrow-terminal behavior | Layout sizing calls execute in the example logic |
| Input, focus, paste, pointer, or keyboard behavior | Keyboard input path is exercised by event construction in quickstart flow |
| Styling, theme, or color fallback behavior | Style helpers and default rendering were exercised |
| Error, cancellation, or cleanup behavior | No uncaught errors; clean termination |
| Documentation or migration issue found | No blocking issues |

## Evidence summary

Immediate quickstart validates the baseline rendering path under a compact non-interactive run.

## Risks and follow-up

Some downstream examples still assert against API shapes that are being adjusted during the same milestone.
