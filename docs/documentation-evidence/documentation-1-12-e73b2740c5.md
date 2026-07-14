# Documentation Evidence Record

## Record identity

| Field | Value |
| --- | --- |
| Release-candidate commit | e73b2740c522af7d54d0d17e33bcacfd90cedf77 |
| Date and UTC time | 2026-07-14 00:46:29 UTC |
| Julia version | 1.12.6 |
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
| `doctest = true` enforced | Yes in `docs/make.jl` and output confirms doctest run |
| `checkdocs = :exports` enforced | Yes in `docs/make.jl` settings |
| `WICKED_DOC_MODULES` discovered Wicked submodules | Yes |
| API route map and stable facade guidance were included | yes, generated pages include API reference and stable facade guidance |
| Public example family index was included | yes, example family index appears in documentation export |
| Release and evidence gates were linked | yes, release/evidence sections link to current checklists |
| Generated HTML was archived | Yes, `build/docs` artifact is present |
| No Documenter warnings | Warnings were informational; no fatal build warnings stopped generation. |
| No missing cross-reference or link errors | cross-reference checks completed with warnings only |

## Evidence summary

Manual Documenter gate executed once under the release candidate and produced `docs/build/docs` with stable API pages and example-family entries.

## Risks and follow-up

Large pages exceeded size warnings in two documentation outputs; we retained those with no broken links.
