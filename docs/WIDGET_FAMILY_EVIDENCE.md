# Widget Family Evidence Ledger

`api/widget_family_evidence.tsv` records release evidence for stable widget
families. It connects the public API surface to focused documentation, public
examples, feature-family mapping, and precompile coverage.

The ledger is checked by:

```sh
julia --project=. --startup-file=no scripts/widget_family_evidence_audit.jl
```

The audit also runs through `scripts/widget_stabilization_gate.jl` and
`scripts/quality_gate.jl`.

Release candidates should archive the exact `api/widget_family_evidence.tsv`
from the immutable candidate commit alongside the audit output.

Use a release-candidate artifact directory so the ledger can be reviewed after
the tag is cut:

```sh
set -euo pipefail
mkdir -p release-evidence/widget-family
date -u +%Y-%m-%dT%H:%M:%SZ > release-evidence/widget-family/recorded-at.txt
git rev-parse HEAD > release-evidence/widget-family/commit.txt
julia --version > release-evidence/widget-family/julia-version.txt
uname -a > release-evidence/widget-family/uname.txt
cp api/widget_family_evidence.tsv release-evidence/widget-family/widget_family_evidence.tsv
sha256sum release-evidence/widget-family/widget_family_evidence.tsv \
  > release-evidence/widget-family/widget_family_evidence.sha256
sha256sum --check release-evidence/widget-family/widget_family_evidence.sha256 \
  > release-evidence/widget-family/widget_family_evidence.sha256.check
set +e
julia --project=. --startup-file=no scripts/widget_family_evidence_audit.jl \
  > release-evidence/widget-family/widget_family_evidence_audit.stdout.txt \
  2> release-evidence/widget-family/widget_family_evidence_audit.stderr.txt
status=$?
printf 'exit_status=%s\n' "$status" \
  > release-evidence/widget-family/widget_family_evidence_audit.status
set -e
test "$status" -eq 0
find release-evidence/widget-family -maxdepth 1 -type f -printf '%f\n' \
  | sort > release-evidence/widget-family/manifest.txt
```

Reviewers should check:

1. `recorded-at.txt` records the UTC time when evidence was captured.
2. `commit.txt` matches the release-candidate commit.
3. `julia-version.txt` matches the Julia version used for release evidence.
4. `uname.txt` records the Linux environment used for the audit.
5. `widget_family_evidence.sha256.check` reports the archived TSV as valid.
6. `widget_family_evidence_audit.status` contains `exit_status=0`.
7. `widget_family_evidence_audit.stderr.txt` is empty or contains only accepted
   non-failure diagnostics.
8. `manifest.txt` lists every widget-family evidence artifact in the directory.

## Columns

| Column | Meaning |
|---|---|
| `family` | Stable widget family name. It must match one of the required stabilization families. |
| `docs` | Comma-separated focused documentation paths. Each path must exist and be discoverable from `docs/README.md`. |
| `examples` | Comma-separated public example paths. Each path must exist and be listed in `examples/README.md`. |
| `example_family_labels` | Labels from `docs/EXAMPLE_FAMILIES.md`, in the same order as `examples`. |
| `stable_api_tokens` | Representative public API tokens exported through `api/stable_api.tsv`. |
| `precompile_tokens` | Representative construction, rendering, testing, or service tokens present in `src/Precompile.jl`. |
| `notes` | Human-readable scope notes. The note must mention the family name. |

## Evidence contract

Each row must prove all of the following:

1. The family is one of the required stable widget families.
2. Focused docs exist and are indexed in `docs/README.md`.
3. Public examples exist and are indexed in `examples/README.md`.
4. Public examples are mapped to the expected labels in `docs/EXAMPLE_FAMILIES.md`.
5. At least three distinct `stable_api_tokens` exist in `api/stable_api.tsv`.
6. At least three `stable_api_tokens` are concrete or parameterized type
   bindings so helper functions cannot stand in for the family's widget/state
   surface.
7. Each `stable_api_token` is mentioned in focused docs.
8. Each `stable_api_token` is demonstrated in public examples.
9. At least three distinct `precompile_tokens` are present in `src/Precompile.jl`.
10. Each type-backed `stable_api_token` has a matching `precompile_token`,
   either by the same public spelling or by a module-qualified spelling whose
   final segment matches the public token.
11. `docs`, `examples`, `example_family_labels`, `stable_api_tokens`, and
   `precompile_tokens` do not contain duplicate values within a row.
12. Notes identify the family scope rather than using generic placeholder text.

This ledger is not a replacement for behavior tests. It proves that every stable
family has developer-visible API guidance and representative startup coverage.
Behavioral correctness still comes from widget coverage, unit tests, examples,
semantic tests, benchmarks, and release evidence.

## Token matching

`stable_api_tokens` and `precompile_tokens` are matched literally, not as regular
expressions. The audit uses identifier-aware boundaries so a token must appear as
the symbol it names:

- `TableView` does not satisfy `Table`.
- `OtherWidgets.Column` does not satisfy `Widgets.Column`.
- `pulse_services!x` does not satisfy `pulse_services!`.
- `` `Token+` `` satisfies `Token+`.

Use the exact public spelling a developer should copy into docs or examples.
For type-backed stable tokens, also add a matching precompile token. For example,
`SearchInput` may be represented by `SearchInput` or `Widgets.SearchInput`, but
`Widgets.TextInput` does not prove startup coverage for `SearchInput`.

## Updating a row

When changing a stable widget family:

1. Update focused docs first.
2. Update or add public examples that use `Wicked.API`.
3. Add or update the matching row in `docs/EXAMPLE_FAMILIES.md`.
4. Choose at least three representative public tokens that are documented and
   demonstrated.
5. Add at least three representative precompile workload tokens, including one
   matching token for each type-backed stable API token in the row.
6. Update `api/widget_family_evidence.tsv`.
7. Run the widget stabilization gate before release review.

Avoid choosing obscure helper names as representative tokens. Prefer symbols a
developer would copy into an application: widgets, state types, pilots, service
managers, or core functions that define the family.
Helper functions may be included when they are important developer API, but they
must be additional to at least three type-backed widget, state, pilot, manager,
or data-model tokens for the family.
Testing-family helper tokens such as `pilot_semantic_tree`,
`pilot_semantic_snapshot`, `assert_semantic_snapshot`, and
`assert_semantic_query` are valid supplemental developer API only when the row
also lists type-backed pilot or widget tokens.
