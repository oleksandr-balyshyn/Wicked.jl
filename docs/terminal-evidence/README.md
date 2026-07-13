# Terminal Evidence Records

Store completed Linux real-terminal evidence records in this directory. Use one
Markdown file per matrix category and terminal environment, copied from
`../TERMINAL_EVIDENCE_TEMPLATE.md`.

Drafts, local notes, and incomplete screenshots should stay outside the
repository until they reference an immutable release-candidate commit and a real
artifact.

Run the record audit from the repository root:

```sh
julia --project=. --startup-file=no scripts/terminal_evidence_audit.jl
```

Before claiming terminal compatibility for a release candidate, require at least
one valid record for every required matrix category:

```sh
julia --project=. --startup-file=no scripts/terminal_evidence_audit.jl --require-complete
```

The audit checks every Markdown file in this directory except this README. It
requires:

1. A valid matrix category from `REAL_TERMINAL_MATRIX.md`.
2. A short or full hexadecimal release-candidate commit.
3. A `YYYY-MM-DD HH:MM:SS UTC` timestamp.
4. A semver-like Julia version.
5. Linux distribution, kernel, architecture, and shell identity.
6. Terminal, multiplexer, SSH or remote transport, command, exit status, and
   artifact identity.
7. A transcript, screenshot, recording, or CI artifact reference that is either
   an HTTP(S) URL or an existing repository-relative path.
8. A concrete result for every required behavior from the Linux real-terminal
   matrix.
9. Non-empty evidence summary and risks/follow-up sections.

The audit rejects placeholder text such as `TODO`, empty table values, unknown
matrix categories, missing behavior rows, invalid statuses, and duplicate
category/environment/commit identities.

Use [Terminal Compatibility Evidence](../TERMINAL_COMPATIBILITY.md),
[Linux Real-Terminal Matrix](../REAL_TERMINAL_MATRIX.md), and
[Terminal Evidence Record Template](../TERMINAL_EVIDENCE_TEMPLATE.md) together:
the matrix defines what must be covered, the template defines record shape, and
this directory stores completed release-candidate records.
