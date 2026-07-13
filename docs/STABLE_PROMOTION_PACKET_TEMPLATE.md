# Stable Promotion Packet Template

Copy this template into a pull request description, release evidence note, or
tracked review artifact when promoting a candidate or compatibility widget to
`Wicked.API`.

Promotion is complete only when every required item cites checked-in evidence.
Do not use this packet as a prose substitute for ledgers, tests, examples, or
precompile coverage.

## Identity

| Field | Value |
|---|---|
| Widget family | TODO |
| Widget name | TODO |
| Source file | TODO |
| Release-candidate commit | TODO |
| Reviewer | TODO |
| Decision | promote / qualify / remove |

## Public API decision

- Stable exported name: TODO
- Constructor shape and required keywords: TODO
- Optional keywords and defaults: TODO
- State type: TODO
- Public state constructor or `state_for` method: TODO
- Public event or action results: TODO
- Toolkit builder or element path: TODO
- Semantic role and stable node IDs: TODO
- Compatibility alias, deprecation, or removal decision: TODO

## Behavior evidence

| Evidence | Artifact |
|---|---|
| `api/widget_coverage.tsv` row | TODO |
| Zero-size rendering | TODO |
| Minimal-size rendering | TODO |
| Clipped rendering | TODO |
| Resized rendering | TODO |
| State-transition tests | TODO |
| Snapshot tests | TODO |
| Keyboard handling | TODO |
| Pointer handling | TODO |
| Toolkit integration | TODO |
| Semantic tree coverage | TODO |

Use `n/a:<reason>` only when the behavior cannot apply to the widget.

## Promotion evidence

| Evidence | Artifact |
|---|---|
| `api/widget_promotion_requirements.tsv` release-required rows satisfied | TODO |
| `api/stable_widget_candidates.tsv` row marked `stable` | TODO |
| `api/stable_api.tsv` concrete or parameterized type binding | TODO |
| `api/experimental_promotions.tsv` completed row, if applicable | TODO |
| Pilot evidence package checked by `scripts/pilot_evidence_package_audit.jl` | TODO |
| Package-level pilot evidence reports, if release-facing | TODO |
| `Wicked.API` export | TODO |
| Compatibility namespace state | TODO |

Experimental or compatibility bindings with only a `proposed` promotion row are
not stable promotion candidates. Move the row to `accepted` after API review and
to `completed` after the stable path, compatibility story, and release notes are
landed.

## Developer evidence

| Evidence | Artifact |
|---|---|
| Focused API documentation | TODO |
| Component catalog entry | TODO |
| Copyable public example using `Wicked.API` | TODO |
| Stable facade usage with no Wicked internals | TODO |
| README or guide update, if user-facing | TODO |
| Framework migration note, if cross-library vocabulary changed | TODO |

## Family and startup evidence

| Evidence | Artifact |
|---|---|
| `api/widget_family_evidence.tsv` row | TODO |
| Matching `precompile_token` for every type-backed `stable_api_token` | TODO |
| `src/Precompile.jl` first-use workload | TODO |
| Package loading or precompile evidence, if release-facing | TODO |

Helper-function tokens are supplemental only. Each representative stable family
must still include type-backed widget tokens with matching precompile coverage.

## Compatibility and release evidence

| Evidence | Artifact |
|---|---|
| Migration note or deprecation plan | TODO |
| `CHANGELOG.md` entry | TODO |
| Release checklist item | TODO |
| Real terminal, application, benchmark, or semantic evidence when required | TODO |

## Risks and follow-ups

- Known limitation: TODO
- Deferred behavior: TODO
- Follow-up issue or milestone: TODO

Do not mark the widget stable if a known limitation contradicts the documented
public API, accessibility contract, or cross-library parity claim.
