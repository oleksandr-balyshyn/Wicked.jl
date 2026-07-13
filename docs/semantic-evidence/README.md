# Semantic Accessibility Evidence Records

This directory stores completed release-candidate records proving semantic tree,
stable node ID, semantic action, registered handler, focus, disabled-state,
pilot-query, and accessibility-oriented behavior for stable widget families. Use
[`SEMANTIC_ACCESSIBILITY_EVIDENCE_TEMPLATE.md`](../SEMANTIC_ACCESSIBILITY_EVIDENCE_TEMPLATE.md)
for new records.

Run the shape audit locally before committing records:

```sh
julia --project=. --startup-file=no scripts/semantic_accessibility_evidence_audit.jl
```

Before a release, require complete evidence for every stable widget family:

```sh
julia --project=. --startup-file=no scripts/semantic_accessibility_evidence_audit.jl --require-complete
```

The complete-mode audit requires one completed record for each stable widget
family in `api/widget_family_evidence.tsv`, rejects placeholder text, rejects
duplicate family and candidate identities, requires the
`scripts/widget_audit.jl --require-complete` and
`scripts/widget_family_evidence_audit.jl` command provenance, and requires real
semantic snapshot and action dispatch artifacts.

Records must prove both static semantic output and dispatch behavior: a snapshot
alone is insufficient if the matching `register_*_semantic_handlers!` path was
not exercised for actionable widgets.
