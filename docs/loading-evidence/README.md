# Package Loading Evidence Records

Store completed package-loading and precompilation evidence in this directory.
Use one Markdown file per Julia version and release-candidate commit, copied from
`../PACKAGE_LOADING_EVIDENCE_TEMPLATE.md`.

Run the record audit from the repository root:

```sh
julia --project=. --startup-file=no scripts/loading_evidence_audit.jl
```

Before publishing a production-ready release candidate, require valid records
for at least two distinct supported Julia versions:

```sh
julia --project=. --startup-file=no scripts/loading_evidence_audit.jl --require-complete
```

The canonical evidence-producing command is:

```sh
julia --project=. --startup-file=no \
  -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); using Wicked; using Wicked.API; @assert Base.get_extension(Wicked, :WickedHTTPWebSocketsExt) === nothing'
```

The audit rejects placeholder text, missing identity fields, invalid timestamps,
non-Linux kernel identities, missing artifacts, duplicate Julia-version/candidate
records, commands that do not instantiate/precompile/load both public modules,
commands that do not check optional-extension activation, and records that do not
cover the required behavior table.
