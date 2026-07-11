# Security Policy

## Supported versions

Wicked.jl has not reached a stable release. Security fixes currently target the default development branch and the latest published `0.0.x` version, if one exists. After `1.0`, the latest minor release receives security fixes; additional supported lines will be listed here when maintenance capacity exists.

## Report a vulnerability

Do not disclose a suspected vulnerability in a public issue, discussion, pull request, or chat transcript.

Use the repository's **Security** tab and select **Report a vulnerability** to open a private report. If private vulnerability reporting is unavailable, open a public issue containing only a request for private maintainer contact. Do not include reproduction steps, affected paths, payloads, or impact details in that issue.

Include the following in the private report:

- Affected Wicked.jl and Julia versions.
- Operating system, terminal, multiplexer, and remote-session details where relevant.
- Minimal reproduction steps or a proof of concept.
- Expected and observed behavior.
- Impact and realistic attack preconditions.
- Any proposed mitigation or patch.

## Response targets

Maintainers aim to:

- Acknowledge a report within three business days.
- Complete initial severity and scope triage within seven business days.
- Provide progress updates at least every 14 days while remediation is active.
- Coordinate disclosure after a fix is available or an agreed embargo ends.

These are response targets, not service-level guarantees.

## Security boundaries

Reports are especially useful for:

- Terminal escape or hyperlink injection.
- Raw-mode, cursor, mouse, paste, or alternate-screen restoration failures.
- Clipboard/OSC response injection or sensitive-content retention.
- File-browser root escape, symlink races, or unintended process execution.
- Unbounded terminal input, Markdown, stylesheet, virtual data, extension, or graphics payloads.
- Command cancellation failures that allow stale privileged results to mutate application state.
- Extension contribution ownership or lifecycle cleanup bypass.

Wicked executes application-provided Julia callbacks with the application's process privileges. The extension registry is a lifecycle and contribution boundary, not a sandbox for malicious Julia code. Reports that rely only on an application deliberately executing untrusted Julia code are outside this security model unless Wicked incorrectly documents that boundary as isolated.

## Disclosure and credit

Maintainers will coordinate an advisory, affected versions, severity, mitigation, and release timing with the reporter. Credit is provided unless the reporter requests anonymity. Do not test against systems or data you do not own or have permission to assess.
