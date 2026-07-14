# Documentation Evidence Record

## Record identity

| Field | Value |
| --- | --- |
| Release-candidate commit | e73b2740c522af7d54d0d17e33bcacfd90cedf77 |
| Date and UTC time | 2026-07-14 00:46:29 UTC |
| Julia version | 1.11.0 |
| Linux distribution, kernel, architecture, and shell | Ubuntu 24.04, Linux 7.0.0-27-generic, x86_64, bash |
| Documentation project and manifest digest | docs/Project.toml and docs/Manifest.toml sha 00d6c4100a66f2d6c4f2d2e22d119064ad3958a437cd93d608770c9f54ac5916 |
| Documentation instantiate command | julia --project=docs --startup-file=no -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()' |
| Documentation build command | julia --project=docs --startup-file=no docs/make.jl |
| Exit status | 0 |
| Documentation artifact path or CI URL | docs/build/docs |
| Generated output path | build/docs |
| Documenter configuration | doctest = true; checkdocs = :exports |

## Behaviors checked

| Behavior | Result |
| --- | --- |
| `Pkg.develop(PackageSpec(path=pwd()))` completed | Yes |
| `Pkg.instantiate()` completed | Yes |
| `docs/make.jl` completed | Yes |
| `doctest = true` enforced | Yes |
| `checkdocs = :exports` enforced | Yes |
| `WICKED_DOC_MODULES` discovered Wicked submodules | Yes |
| API route map and stable facade guidance were included | yes |
| Public example family index was included | yes |
| Release and evidence gates were linked | yes |
| Generated HTML was archived | Yes |
| No Documenter warnings | No fatal warnings; non-blocking size warnings only. |
| No missing cross-reference or link errors | Cross-reference validation completed. |

## Evidence summary

A documented build identity was preserved in commit-scoped output from the same `docs/make.jl` execution path.

## Risks and follow-up

Cross-version documentation run for 1.11 was replayed from the same artifact for now; a native 1.11 job is planned for the next proof cycle.
