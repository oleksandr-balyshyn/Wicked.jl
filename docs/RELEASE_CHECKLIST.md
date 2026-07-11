# Production Release Checklist

No release is production grade until every required item has recorded evidence.
The current worktree results and unresolved evidence are recorded in
[Release Evidence](RELEASE_EVIDENCE.md). Leave an item unchecked when evidence
exists only locally, describes CI configuration rather than an actual candidate
run, or does not cover the full platform and behavior scope of the requirement.

## Package integrity

- [ ] `Project.toml` contains every standard-library and package dependency.
- [ ] The manifest is regenerated from the supported Julia baseline.
- [ ] `using Wicked` succeeds on every supported Julia version.
- [ ] Public exports are free of collisions and undefined bindings.
- [ ] Package precompilation succeeds without warnings.

## Correctness

- [ ] Placeholder tests are removed.
- [ ] Core geometry, cells, buffers, diffs, Unicode widths, and layout have unit tests.
- [ ] ANSI input parsing has split-sequence, malformed-sequence, and fuzz tests.
- [ ] Terminal setup and restoration are tested across thrown errors and cancellation.
- [ ] Every widget family has state-transition and snapshot tests.
- [ ] Toolkit reconciliation covers keyed moves, duplicate keys, mount, and unmount.
- [ ] Stylesheet parsing and selector specificity have property tests.
- [ ] Reactive transactions cover rollback, nested transactions, reentrant updates, and disposal.
- [ ] Virtual data covers stale pages, cancellation, failures, eviction, and stable selection.
- [ ] Accessibility trees validate and snapshot for every interactive component.
- [ ] Clipboard, file paths, Markdown links, and extension inputs have adversarial tests.

## Performance

- [ ] Buffer diff benchmarks cover sparse and full-screen updates.
- [ ] Layout benchmarks cover deep flex/grid trees.
- [ ] Toolkit benchmarks cover stable trees and high-churn keyed reconciliation.
- [ ] Markdown and stylesheet parsing benchmarks cover large documents.
- [ ] Virtual list/table benchmarks cover one million logical rows.
- [ ] Allocation budgets are defined for idle frames and common input events.
- [ ] Diagnostics disabled mode has a measured negligible overhead.

## Terminal compatibility

- [ ] Minimal ANSI and 16-color terminals.
- [ ] 256-color and truecolor terminals.
- [ ] Kitty and WezTerm graphics.
- [ ] Sixel-capable terminal.
- [ ] tmux and GNU screen.
- [ ] SSH session with unknown pixel dimensions.
- [ ] Bracketed paste, focus events, mouse modes, and resize behavior.
- [ ] Unicode narrow, wide, combining, emoji, and ambiguous-width cases.

## Documentation

- [ ] Getting-started examples execute in CI.
- [ ] Immediate-mode application tutorial.
- [ ] Toolkit application tutorial.
- [ ] Widget and component API reference.
- [ ] Styling and theme guide.
- [ ] Async commands, subscriptions, and cancellation guide.
- [ ] Accessibility and testing guide.
- [ ] Migration guide from the original Wicked.jl prototype.
- [ ] Comparison and migration notes for Ratatui, Textual, TamboUI, and Lanterna users.

## Release engineering

- [ ] CI covers all supported Julia versions on Linux.
- [ ] Formatting, static analysis, docs, tests, and benchmarks have explicit gates.
- [ ] SemVer policy and deprecation window are documented.
- [ ] Changelog contains user-visible additions, changes, and removals.
- [ ] Security reporting policy exists.
- [ ] License and third-party notices are complete.
- [ ] Release candidate is tested in at least two real applications.
- [ ] Final tag is created only after all blocking evidence is archived.
