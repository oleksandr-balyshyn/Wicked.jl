# Remote Delivery Evidence Record Template

Use this template for one remote/browser delivery run from an immutable
release-candidate commit. It complements
[`PARITY_EVIDENCE_TEMPLATE.md`](PARITY_EVIDENCE_TEMPLATE.md) for the
`Remote-delivery` parity family and adds the deployment/security fields that a
browser-hosted surface needs.

Store completed records with release artifacts or under `docs/evidence/` when
they are intended to satisfy the parity closeout audit. Incomplete drafts should
stay outside the repository.

## Record identity

| Field | Value |
| --- | --- |
| Family | Remote-delivery |
| Wicked release-candidate commit | short or full git commit SHA |
| Date and UTC time | YYYY-MM-DD HH:MM:SS UTC |
| Julia version | Julia version, for example 1.10.11 or 1.12.6 |
| Linux distribution, kernel, architecture, and shell | |
| Active project and manifest digest | |
| HTTP.jl version and extension state | |
| Browser name, version, engine, and operating system | |
| Client asset digest | SHA-256 digest for `assets/remote/` payload served |
| Command or deployment entrypoint | |
| Exit status | non-negative integer process exit code |
| Artifact path or CI URL | |

## Transport and deployment configuration

| Field | Value |
| --- | --- |
| Served asset root | |
| WebSocket route | |
| TLS mode | HTTPS / trusted local network / other |
| Authentication mechanism | |
| Authorization policy | |
| Origin policy | |
| Maximum WebSocket frame size | |
| Connection and rate limits | |
| Session timeout and cleanup policy | |
| Logging/redaction policy | |

## Behaviors checked

Record concrete results for every remote-delivery release requirement.

| Behavior | Result |
| --- | --- |
| Browser deployment serves the reference client or approved application client | |
| WebSocket upgrade requires the configured authentication and origin policy | |
| Server sends `RemoteHello` before frame traffic | |
| First frame after connect is a full `RemoteFrame` | |
| Delta frames apply in order without stale cells | |
| Client sends typed key, paste, mouse, focus, resize, and acknowledgement packets | |
| Protocol version mismatch or malformed packets close the session safely | |
| `RemoteProtocolLimits` bound packet, cell, string, and decoder allocations | |
| Resize negotiation updates backend size and triggers a synchronized redraw | |
| Browser renderer preserves wide graphemes, combining marks, colors, cursor, and hyperlinks as data | |
| Accessibility text mirror reflects the rendered terminal content | |
| Reconnect or sequence gap requests a full-frame resynchronization | |
| HTTP.jl remains optional for ordinary `using Wicked.API` loading | |

## Reference-library parity notes

Describe how the observed behavior maps to Textual-style remote/browser
presentation, Ratatui-style backend separation, and Lanterna-style conservative
transport boundaries. Record intentional divergences explicitly.

- 

## Evidence summary

Record the observed result. Include protocol fixture audit output, browser
recording or screenshot paths, WebSocket transcript paths, deployment URL,
captured client asset digests, and CI job URLs when applicable.

- 

## Risks and follow-up

Record failures, accepted known risks, deployment-specific limitations, browser
compatibility gaps, or hardening follow-up. Link any accepted risk from
[`RELEASE_EVIDENCE.md`](RELEASE_EVIDENCE.md).

- 
