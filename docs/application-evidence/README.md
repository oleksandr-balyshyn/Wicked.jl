# Real Application Evidence Records

Store completed evidence that Wicked was tested in independent real applications.
Use one Markdown file per application and release-candidate commit, copied from
`../REAL_APPLICATION_EVIDENCE_TEMPLATE.md`.

Run the record audit from the repository root:

```sh
julia --project=. --startup-file=no scripts/application_evidence_audit.jl
```

Before publishing a release candidate as production-ready, require at least two
valid records for distinct applications:

```sh
julia --project=. --startup-file=no scripts/application_evidence_audit.jl --require-complete
```

The audit rejects placeholder text, empty identity fields, invalid timestamps,
non-Linux kernel identities, missing artifacts, duplicate application/commit
records, and records that do not cover the required behavior table. Each record
must prove that the application used the reviewed `Wicked.API` facade rather than
internal modules or `Wicked.Experimental`.

These records are not benchmark substitutes. They prove that application-level
package loading, stable-facade adoption, startup, interaction, resizing, input,
styling, cleanup, and migration behavior were exercised outside Wicked's own
examples and tests.
