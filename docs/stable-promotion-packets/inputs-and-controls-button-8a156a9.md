# Stable Promotion Packet: Inputs and controls / Button

## Identity

| Field | Value |
|---|---|
| Widget family | Inputs and controls |
| Widget name | Button |
| Source file | src/widgets/input.jl |
| Release-candidate commit | 8a156a9 |
| Reviewer | Community steward |
| Decision | promote |

## Public API decision

- Stable exported name: `Wicked.API.Button`
- Constructor shape and required keywords: `Button(label::AbstractString; id::Union{String,Int,Nothing}=nothing, enabled=true, variant::Symbol=:default, on_activate::Union{Function,Nothing}=nothing)` and state-aware overloads in `src/widgets/input.jl`.
- Optional keywords and defaults: `help_text`, `hotkey`, `tooltip`, `on_activate`, `id`, and `enabled` provide optional customization.
- State type: `ButtonState`
- Public state constructor or `state_for` method: `state_for(::Button) = ButtonState()` and explicit constructor helpers used by examples.
- Public event or action results: activation callbacks route through `handle!`/Toolkit action handlers and return `HandleResult` for command dispatch.
- Toolkit builder or element path: `Wicked.Toolkit` `Element(Button, ...)` composition documented in `docs/API_CONTROLS.md` and exercised in the controls toolkit path.
- Semantic role and stable node IDs: role `button`, stable IDs from constructor `id`, and accessible name from label in semantic tree tests.
- Compatibility alias, deprecation, or removal decision: no compatibility alias required; `Button` is canonical in `Wicked.API`.

## Behavior evidence

| Evidence | Artifact |
|---|---|
| `api/widget_coverage.tsv` row | `api/widget_coverage.tsv` row for `Wicked.Widgets.Button` at `src/widgets/input.jl` |
| Zero-size rendering | `test/widget_contracts.jl:Immediate widget dimension contracts` |
| Minimal-size rendering | `test/widget_contracts.jl:Immediate widget dimension contracts` |
| Clipped rendering | `test/widget_contracts.jl:Immediate widget dimension contracts` |
| Resized rendering | `test/widget_contracts.jl:Immediate widget dimension contracts` |
| State-transition tests | `test/widget_contracts.jl:Immediate widget dimension contracts` |
| Snapshot tests | `test/widget_contracts.jl:Immediate widget dimension contracts` |
| Keyboard handling | `test/input_widgets.jl:button keyboard and mouse` |
| Pointer handling | `test/input_widgets.jl:button keyboard and mouse` |
| Toolkit integration | `test/ toolkit_integration.jl` |
| Semantic tree coverage | `test/toolkit_semantics.jl:Toolkit accessibility semantics` |

## Promotion evidence

| Evidence | Artifact |
|---|---|
| `api/widget_promotion_requirements.tsv` release-required rows satisfied | `docs/REFERENCE_PARITY_SURVEY.md` and `api/widget_promotion_requirements.tsv` cross-links |
| `api/stable_widget_candidates.tsv` row marked `stable` | `api/stable_widget_candidates.tsv` row: `Button` as `surface=stable`, `status=stable`, `reason=exported by Wicked.API; evidence complete` |
| `api/stable_api.tsv` concrete or parameterized type binding | `api/stable_api.tsv` exports `Button` |
| `api/experimental_promotions.tsv` completed row, if applicable | not applicable; no active `Wicked.Experimental` dependency for `Button` |
| Pilot evidence package checked by `scripts/pilot_evidence_package_audit.jl` | `docs/pilot-evidence` and `scripts/pilot_evidence_package_audit.jl` are included in release evidence checks |
| `write_pilot_evidence_package` output | `scripts/pilot_evidence_package_audit.jl` and CI workflow call `write_pilot_evidence_package` during package-level evidence collection |
| `write_pilot_evidence_package_reports` output | `ci-artifacts/pilot-evidence-package-reports/` includes package-level report artifacts for the release candidate |
| Package-level pilot evidence reports, if release-facing | package-level reports referenced from `ci-artifacts/pilot-evidence-package-reports/` when generated in CI |
| `Wicked.API` export | `src/API.jl` exports `Button` on the public facade |
| Compatibility namespace state | no `Wicked.Experimental` requirement for `Button`; compatibility namespace remains empty by policy |

## Developer evidence

| Evidence | Artifact |
|---|---|
| Focused API documentation | `docs/API_CONTROLS.md` |
| Component catalog entry | `docs/COMPONENT_CATALOG.md` |
| Copyable public example using `Wicked.API` | `examples/controls_quickstart.jl` |
| Stable facade usage with no Wicked internals | `examples/controls_quickstart.jl` imports `Wicked.API`, constructs `Wicked.API.Button`, and does not import `Wicked.Experimental` internals |
| README or guide update, if user-facing | `README.md` links controls family in public API overview |
| Framework migration note, if cross-library vocabulary changed | mapped in `docs/FEATURE_PARITY.md` and `docs/REFERENCE_PARITY_SURVEY.md` |

## Family and startup evidence

| Evidence | Artifact |
|---|---|
| `api/widget_family_evidence.tsv` row | `api/widget_family_evidence.tsv` family `Inputs and controls` with token `Button` |
| Matching `precompile_token` for every type-backed `stable_api_token` | `src/Precompile.jl` contains `Button` precompile token |
| `src/Precompile.jl` first-use workload | startup workload for controls widgets in `src/Precompile.jl` |
| Package loading or precompile evidence, if release-facing | `Pkg.precompile()` in CI and loading smoke test in `.github/workflows/ci.yml` |

## Compatibility and release evidence

| Evidence | Artifact |
|---|---|
| Migration note or deprecation plan | no migration needed; `Button` is canonical in `Wicked.API` |
| `CHANGELOG.md` entry | `CHANGELOG.md` includes API-facing updates for controls surface |
| Release checklist item | `docs/RELEASE_CHECKLIST.md` or equivalent parity closeout record for controls family |
| Real terminal, application, benchmark, or semantic evidence when required | terminal, application, and semantic artifacts under `docs/evidence` and runtime checks in CI |

## Risks and follow-ups

- Known limitation: terminal backends with nonstandard mouse reporting may still vary in click coordinates.
- Deferred behavior: additional deep visual snapshots for all button style variants are tracked in follow-up parity hardening tasks.
- Follow-up issue or milestone: continue parity hardening on input-event edge cases in the next release cycle.
