# Package Loading Evidence Record Template

Use this template for one immutable release-candidate package-loading and
precompilation run. Store completed records under `docs/loading-evidence/`; keep
local drafts outside the repository.

## Record identity

| Field | Value |
| --- | --- |
| Release-candidate commit | short or full git commit SHA |
| Date and UTC time | YYYY-MM-DD HH:MM:SS UTC |
| Julia version | Julia version, for example 1.10.11 or 1.12.6 |
| Linux distribution, kernel, architecture, and shell | |
| Active project and manifest digest | |
| Depot profile | clean depot / default depot / CI cache |
| Loading command | |
| Exit status | non-negative integer process exit code |
| Artifact path or CI URL | |
| Imported modules | Wicked, Wicked.API |

## Behaviors checked

| Behavior | Result |
| --- | --- |
| `Pkg.instantiate()` completed | |
| `Pkg.precompile()` completed | |
| `using Wicked` completed | |
| `using Wicked.API` completed | |
| No precompile or loading warnings | |
| No optional dependency was required for core loading | |
| HTTP WebSocket extension stayed inactive without HTTP.jl loaded | |
| No raw terminal mode, alternate screen, or input read was triggered | |

## Evidence summary

Record command output, package status artifact, depot profile, manifest digest,
and cache behavior.

- 

## Risks and follow-up

Record warnings, retries, cache invalidation, unsupported dependency behavior, or
accepted release risks.

- 
