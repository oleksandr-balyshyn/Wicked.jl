# Unicode Width Corpus

`api/unicode_width_corpus.tsv` is the checked-in corpus for terminal text-width
behavior that Wicked relies on for Ratatui-style deterministic rendering,
Textual-style automation snapshots, and Lanterna-style conservative terminal
compatibility.

Run the audit from the repository root:

```sh
julia --project=. --startup-file=no scripts/unicode_width_corpus_audit.jl
```

The corpus covers:

1. Single-column ASCII.
2. East Asian wide characters.
3. East Asian ambiguous characters under narrow and wide ambiguous policies.
4. Combining marks and composed grapheme clusters.
5. Emoji ZWJ clusters.
6. Mixed text whose width is the sum of individual grapheme widths.

The `escaped` column stores ASCII escape sequences such as `\u754c` and
`\U0001f469\u200d\U0001f4bb` so the corpus is stable in terminals, editors, and
diff tools. The audit decodes those sequences, checks grapheme segmentation,
checks `text_width` under `UnicodeWidthPolicy(1)` and `UnicodeWidthPolicy(2)`,
and checks `grapheme_width` for single-grapheme cases.

Update the corpus when Wicked changes width policy, adopts a newer Unicode data
source, or adds a rendering feature that depends on a new class of text.

## Release evidence

Archive the exact corpus and audit output from the immutable release-candidate
commit:

```sh
set -euo pipefail
mkdir -p release-evidence/unicode-width
date -u +%Y-%m-%dT%H:%M:%SZ > release-evidence/unicode-width/recorded-at.txt
git rev-parse HEAD > release-evidence/unicode-width/commit.txt
julia --version > release-evidence/unicode-width/julia-version.txt
cp api/unicode_width_corpus.tsv release-evidence/unicode-width/unicode_width_corpus.tsv
sha256sum release-evidence/unicode-width/unicode_width_corpus.tsv \
  > release-evidence/unicode-width/unicode_width_corpus.sha256
set +e
julia --project=. --startup-file=no scripts/unicode_width_corpus_audit.jl \
  > release-evidence/unicode-width/unicode_width_corpus_audit.stdout.txt \
  2> release-evidence/unicode-width/unicode_width_corpus_audit.stderr.txt
status=$?
printf 'exit_status=%s\n' "$status" \
  > release-evidence/unicode-width/unicode_width_corpus_audit.status
set -e
test "$status" -eq 0
find release-evidence/unicode-width -maxdepth 1 -type f -printf '%f\n' \
  | sort > release-evidence/unicode-width/manifest.txt
```

Reviewers should confirm that `commit.txt` matches the candidate commit,
`unicode_width_corpus_audit.status` contains `exit_status=0`, stderr has no
failure diagnostics, and the manifest lists the corpus, digest, command output,
and environment metadata.
