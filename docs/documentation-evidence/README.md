# Documentation Evidence Records

This directory stores completed strict Documenter manual evidence records for
release candidates. Use
[`DOCUMENTATION_EVIDENCE_TEMPLATE.md`](../DOCUMENTATION_EVIDENCE_TEMPLATE.md) for
new records.

Each completed record must identify the release-candidate commit, Julia version,
Linux environment, docs project and manifest digest, exact instantiate command,
exact `docs/make.jl` command, exit status, generated `build/docs` output, and an
archived artifact path or CI URL.

Run the shape audit locally before committing a record:

```sh
julia --project=. --startup-file=no scripts/documentation_evidence_audit.jl
```

Before a release, require complete evidence for at least two distinct supported
Julia versions:

```sh
julia --project=. --startup-file=no scripts/documentation_evidence_audit.jl --require-complete
```

The complete-mode audit rejects placeholder text, duplicate release-candidate and
Julia-version identities, missing strict Documenter settings, missing
`docs/make.jl` command provenance, missing developer-orientation pages, missing
public example family indexing, missing release/evidence gate links, and missing
documentation artifacts.
