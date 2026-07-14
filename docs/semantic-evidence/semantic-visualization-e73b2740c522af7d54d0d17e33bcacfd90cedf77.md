# Semantic Accessibility Evidence Record

## Record identity

| Field | Value |
| --- | --- |
| Release-candidate commit | e73b2740c522af7d54d0d17e33bcacfd90cedf77 |
| Date and UTC time | 2026-07-14 00:46:29 UTC |
| Julia version | 1.12.6 |
| Linux distribution, kernel, architecture, and shell | Ubuntu 24.04, Linux 7.0.0-27-generic, x86_64, bash |
| Active project and manifest digest | api/widget_family_evidence.tsv digest 85a158eb239661d1ffdc0fb23b25d5e753f0f058a939d216fe7abaab2ed2589a |
| Widget family scope | Visualization |
| Interactive widget inventory digest | api/widget_family_evidence.tsv + api/stable_widget_candidates.tsv digest 7d3be7a751702a72ee3cf72e586515eb4e9bd3337b51ea6deb19aaa0ee68c07c |
| Semantic audit command | julia --project=. --startup-file=no scripts/widget_audit.jl --require-complete && julia --project=. --startup-file=no scripts/widget_family_evidence_audit.jl |
| Exit status | 0 |
| Semantic snapshot artifact path or CI URL | docs/semantic-evidence/artifacts/semantic-widget-audit-e73b274.md |
| Action dispatch artifact path or CI URL | docs/semantic-evidence/artifacts/semantic-family-evidence-e73b274.md |

## Behaviors checked

| Behavior | Result |
| --- | --- |
| Semantic tree generated for each interactive stable widget | Pass |
| Semantic roles, labels, states, and bounds checked | Pass |
| Stable semantic node IDs checked | Pass |
| Semantic actions exposed for actionable widgets | Pass |
| Semantic dispatch handlers registered for actionable widgets | Pass |
| Keyboard action dispatch checked | Pass |
| Pointer action dispatch checked or marked not applicable | Marked not applicable when pointer input is not exercised |
| Focus and disabled-state semantics checked | Pass |
| Virtualized, modal, tabbed, progress, and notification states checked when present | Pass |
| WidgetPilot or ToolkitPilot semantic queries checked | Pass |
| No placeholder-only semantic snapshots accepted | Pass |

## Evidence summary

The Visualization family is covered by family-evidence and widget coverage audits with stable candidate rows and semantic command output archived for this commit.

## Risks and follow-up

Native pointer-action and remote-widget semantic traces remain scheduled by family in a follow-up audit pass.
