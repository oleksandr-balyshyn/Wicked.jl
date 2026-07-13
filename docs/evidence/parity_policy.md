# Parity Evidence Policy

Machine-readable parity policy data for release-closeout automation is stored in
[`parity_policy.json`](parity_policy.json).

The policy file is the source of truth for:

- family-to-scope mappings,
- family closeout requirements,
- required command entrypoints,
- allowed artifact URL schemes,
- and the evidence completeness thresholds used by parity closeout audits.

When adding new parity families or changing closeout requirements, update this
JSON file first, then update the reference survey and release checklists.
