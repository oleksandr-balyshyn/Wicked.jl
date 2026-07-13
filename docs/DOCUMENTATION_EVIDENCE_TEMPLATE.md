# Documentation Evidence Record

Copy this template for each release-candidate strict documentation build. Store
completed records under `docs/documentation-evidence/` with filenames that include
the Julia minor version and release-candidate commit, for example
`documentation-1-12-abcdef1234567890.md`.

## Record identity

| Field | Value |
| --- | --- |
| Release-candidate commit | TODO |
| Date and UTC time | TODO |
| Julia version | TODO |
| Linux distribution, kernel, architecture, and shell | TODO |
| Documentation project and manifest digest | TODO |
| Documentation instantiate command | `julia --project=docs --startup-file=no -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'` |
| Documentation build command | `julia --project=docs --startup-file=no docs/make.jl` |
| Exit status | TODO |
| Documentation artifact path or CI URL | TODO |
| Generated output path | `build/docs` |
| Documenter configuration | `doctest = true`; `checkdocs = :exports`; `pagesonly = true` |

## Behaviors checked

| Behavior | Result |
| --- | --- |
| `Pkg.develop(PackageSpec(path=pwd()))` completed | TODO |
| `Pkg.instantiate()` completed | TODO |
| `docs/make.jl` completed | TODO |
| `doctest = true` enforced | TODO |
| `checkdocs = :exports` enforced | TODO |
| `WICKED_DOC_MODULES` discovered Wicked submodules | TODO |
| API route map and stable facade guidance were included | TODO |
| Public example family index was included | TODO |
| Release and evidence gates were linked | TODO |
| Generated HTML was archived | TODO |
| No Documenter warnings | TODO |
| No missing cross-reference or link errors | TODO |

## Evidence summary

TODO

## Risks and follow-up

TODO
