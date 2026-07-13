# Semantic Accessibility Evidence Record

Copy this template for each release-candidate stable widget family. Store
completed records under `docs/semantic-evidence/` with filenames that include the
family slug and release-candidate commit, for example
`semantic-inputs-and-controls-abcdef1234567890.md`.

## Record identity

| Field | Value |
| --- | --- |
| Release-candidate commit | TODO |
| Date and UTC time | TODO |
| Julia version | TODO |
| Linux distribution, kernel, architecture, and shell | TODO |
| Active project and manifest digest | TODO |
| Widget family scope | TODO |
| Interactive widget inventory digest | TODO |
| Semantic audit command | `julia --project=. --startup-file=no scripts/widget_audit.jl --require-complete && julia --project=. --startup-file=no scripts/widget_family_evidence_audit.jl` |
| Exit status | TODO |
| Semantic snapshot artifact path or CI URL | TODO |
| Action dispatch artifact path or CI URL | TODO |

## Behaviors checked

| Behavior | Result |
| --- | --- |
| Semantic tree generated for each interactive stable widget | TODO |
| Semantic roles, labels, states, and bounds checked | TODO |
| Stable semantic node IDs checked | TODO |
| Semantic actions exposed for actionable widgets | TODO |
| Semantic dispatch handlers registered for actionable widgets | TODO |
| Keyboard action dispatch checked | TODO |
| Pointer action dispatch checked or marked not applicable | TODO |
| Focus and disabled-state semantics checked | TODO |
| Virtualized, modal, tabbed, progress, and notification states checked when present | TODO |
| WidgetPilot or ToolkitPilot semantic queries checked | TODO |
| No placeholder-only semantic snapshots accepted | TODO |

## Evidence summary

TODO

## Risks and follow-up

TODO
