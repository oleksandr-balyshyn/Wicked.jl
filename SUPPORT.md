# Support Policy

This document explains where to get help with Wicked.jl and what information is
needed for an actionable report. Wicked.jl is maintained as an open-source
project; support is best effort and is not a service-level agreement.

## Before requesting help

1. Confirm that the problem occurs on a supported Julia version and the current
   Wicked.jl development revision or latest published release.
2. Search the [documentation](./docs/README.md), existing issues, and closed
   issues for the same behavior.
3. Run Julia with the intended project, preferably with
   `--project=. --startup-file=no`, and confirm `Base.active_project()`.
4. Reduce the problem to the smallest application that still reproduces it.
5. Remove credentials, private paths, terminal contents, and other sensitive
   data from logs and screenshots.

For package loading and precompilation problems, run:

```sh
julia --project=. --startup-file=no \
  -e 'using Pkg; Pkg.status(); Pkg.instantiate(); Pkg.precompile(); using Wicked.API'
```

## Usage questions

Use the repository's question or discussion channel when one is enabled. A good
question includes:

- The application behavior you are trying to build.
- A minimal code sample.
- What you expected and what occurred instead.
- Wicked.jl and Julia versions.
- Relevant documentation already consulted.

Questions about unreviewed APIs should identify imports from
`Wicked.Experimental`. Those APIs may change before `1.0`; maintainers can
explain the current design but cannot guarantee compatibility.

## Bug reports

Use the public issue tracker for reproducible defects that do not contain
security-sensitive or private information. Include:

- A minimal, complete reproducer.
- Exact Wicked.jl revision or version and Julia version.
- Operating system, architecture, terminal, multiplexer, and remote-session
  details where relevant.
- Expected and observed output.
- Complete error and stack trace as text.
- Whether the problem reproduces with `--startup-file=no`.
- Relevant terminal capabilities, dimensions, locale, `TERM`, and `COLORTERM`
  values.
- Any workaround you have confirmed.

For rendering defects, attach a headless snapshot when possible and state
whether the same result appears in a real terminal. For performance reports,
include a fixed workload, warm-up method, timing method, allocation count, and
comparison revision.

## Feature requests

Before requesting a feature, review [Feature Parity](./docs/FEATURE_PARITY.md), [Release Checklist](./docs/RELEASE_CHECKLIST.md),
the [component catalog](./docs/COMPONENT_CATALOG.md), and the
[feature parity ledger](./docs/FEATURE_PARITY.md). Describe the user problem,
not only a proposed API. Include representative behavior from Ratatui, Textual,
Lanterna, TamboUI, or another framework when compatibility or parity matters.

A feature request does not guarantee inclusion. Decisions consider Julia API
quality, immediate and declarative interoperability, accessibility, terminal
safety, testability, performance, maintenance cost, and compatibility policy.

## Security and conduct

- Report suspected vulnerabilities privately by following
  [SECURITY.md](./SECURITY.md). Never include exploit details in a public issue.
- Report harassment or community safety concerns by following
  [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md). Do not disclose incident details
  publicly.

## Supported scope

Wicked is a **Linux terminal** library. We currently target Julia 1.10+ on Linux
only.

Maintainers can investigate Wicked.jl behavior on supported Julia versions and
documented platforms. Requests may be closed or redirected when they concern:

- Unsupported Julia or terminal versions.
- Application-specific code without a minimal reproducer.
- Private dependencies or environments maintainers cannot access.
- General Julia programming unrelated to Wicked.jl.
- Deliberate execution of untrusted Julia code as if Wicked.jl were a sandbox.
- Experimental behavior whose replacement is already documented.

Community members may still help with unsupported configurations, but such help
does not expand the project's compatibility commitment.

## Response expectations

Maintainers triage reports as availability permits. Clear, reproducible reports
with current-version evidence are handled first. Lack of an immediate response
does not imply acceptance, rejection, or a release commitment. Security reports
use the response targets in [SECURITY.md](./SECURITY.md).
