# Stable Promotion Packet Records

This directory stores completed stable widget promotion packet records for
release candidates. Use
[`STABLE_PROMOTION_PACKET_TEMPLATE.md`](../STABLE_PROMOTION_PACKET_TEMPLATE.md)
or generate a draft with:

```sh
julia --project=. --startup-file=no scripts/new_stable_promotion_packet.jl \
  --family Stateful-controls \
  --widget ComboBox \
  --source src/AcceptanceWidgets.jl \
  --candidate <sha> \
  --decision promote
```

Run the shape audit before committing completed records:

```sh
julia --project=. --startup-file=no scripts/stable_promotion_packet_audit.jl
julia --project=. --startup-file=no scripts/pilot_evidence_package_audit.jl
```

Use complete mode only for release candidates that promoted at least one widget:

```sh
julia --project=. --startup-file=no scripts/stable_promotion_packet_audit.jl --require-complete
```

The audit rejects placeholder text, malformed release-candidate commits,
duplicate widget/candidate identities, missing required sections, missing
behavior/promotion-requirements/promotion/startup ledger references, and
packets that mention `Wicked.Experimental` without accepted or completed review
status. It also cross-checks the packet identity against the checked-in stable
API, stable widget candidate, widget coverage, and widget family evidence
ledgers, and rejects source files that do not exist under `src/`.
Completed records must also prove stable facade usage by citing a copyable
example or application path. The required
`Stable facade usage with no Wicked internals` row must cite code that imports
`Wicked.API` and avoids Wicked internals and `Wicked.Experimental`.
Completed records must cite `api/widget_promotion_requirements.tsv` so
reviewers can trace the promotion back to the release-required checklist.
Completed records must also cite the packaged pilot evidence workflow:
`write_pilot_evidence_package`, `write_pilot_evidence_package_reports`, and
`scripts/pilot_evidence_package_audit.jl`. Store immutable promotion artifacts
under `docs/pilot-evidence/<family-widget-sha>` and archive matching
package-level report artifacts under
`ci-artifacts/pilot-evidence-package-reports/<family-widget-sha>` when the
release job produces them.
