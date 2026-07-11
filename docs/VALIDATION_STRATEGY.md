# Validation Strategy

Wicked cannot claim production parity from source coverage alone. This strategy
defines the evidence required to move features from source-present or integrated to
verified in the feature parity ledger.

## Execution order

Run gates in this order. Stop at the first failure class, fix it, and restart that
gate before moving forward.

1. Parse and load the package.
2. Run non-interactive public examples.
3. Run focused unit tests.
4. Run integration and snapshot tests.
5. Run concurrency and failure-injection tests.
6. Run terminal PTY compatibility scenarios.
7. Run benchmarks and allocation budgets.
8. Run the supported Julia and platform matrix.
9. Build documentation from a clean environment.
10. Execute the release checklist.

## Gate 1: package loading

The first command is intentionally narrow:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); using Wicked'
```

Required evidence:

- Dependency resolution succeeds from a clean depot.
- Julia selects the version-specific manifest generated for the runtime under
  test without stale-manifest or cross-version warnings.
- Every included source file parses and lowers.
- Imports and exports resolve without ambiguity.
- Precompilation succeeds without method-overwrite warnings.
- Loading does not modify terminal state or start unmanaged tasks.

Wicked records supported runtime environments as
`Manifest-v<major>.<minor>.toml`. Regenerate each file with its corresponding
Julia minor release. Do not use one generic root manifest across Julia versions
whose standard-library dependency graphs differ.

## Gate 2: public examples

Run every file listed in `examples/README.md` in a fresh Julia process.

Required evidence:

- Each process exits successfully.
- Assertions exercise only public APIs.
- No example depends on execution order or prior global state.
- Temporary files and tasks are released.
- Deterministic clock examples produce identical results across runs.

## Gate 3: unit suites

Replace the placeholder test with focused suites for these boundaries:

- Geometry, Unicode width, clipping, buffers, and diffs.
- Layout constraints, flex, grid, dock, and overflow.
- Event parser state machines and malformed byte sequences.
- Widget construction, measurement, rendering, and input state.
- Reactive transactions, subscriptions, disposal, and reentrancy.
- Actions, themes, overlays, animations, reload, notifications, and progress.
- Virtual data sources, query revisions, caching, and selection.
- Rich text, Markdown, code, links, graphics fallbacks, and semantic output.
- Content switching, tab snapshots, lazy loading, and concurrent replacement.
- Tracing, replay, diagnostics, reliability, and extension lifecycle.

Each manager suite must cover successful operations, missing IDs, duplicate IDs,
overflow preflight, callback failure, callback reentrancy, idempotent teardown, and
state snapshots.

## Gate 4: integration and snapshots

Required integration scenarios:

- Render a representative dashboard through the ANSI and test backends.
- Render every public widget at zero, minimal, normal, and clipped dimensions.
- Route keyboard, mouse, paste, focus, resize, and semantic actions.
- Open nested modeless and modal overlays, then restore focus.
- Reconcile keyed Toolkit trees through insert, move, replace, and remove changes.
- Apply stylesheet and theme reloads while preserving the previous valid state after
  parser or callback failure.
- Render virtual tables and trees with loading, ready, end, and failed slots.
- Compare visual buffers and semantic trees from the same state snapshot.

Snapshot fixtures must record terminal dimensions, width policy, color capability,
backend, and Julia version. Review snapshot updates as behavioral API changes.

## Gate 5: concurrency and failure injection

Exercise task races repeatedly with deterministic barriers:

- Subscribe, notify, unsubscribe, and dispose reactive values concurrently.
- Replace and close overlays while close callbacks open other overlays.
- Tick, pause, cancel, and replace keyed animations concurrently.
- Change themes while binding and unbinding style engines.
- Update tab selection while lazy page factories complete.
- Poll, replace, disable, and remove reload targets around load/apply boundaries.
- Invoke and unbind semantic notification handlers concurrently.
- Pulse and shut down application services around lifecycle callbacks.

Inject failures into allocation-adjacent callbacks, parsers, renderers, clocks,
loaders, appliers, interpolators, action handlers, and terminal writes. After each
failure, assert manager invariants and terminal restoration.

## Gate 6: terminal compatibility

Use pseudo-terminals for automated lifecycle tests and manual sessions for protocol
coverage.

The executable scenarios and evidence-recording matrix are defined in
[Terminal Compatibility Evidence](TERMINAL_COMPATIBILITY.md).

Required terminal categories:

- Basic ANSI with 16 colors.
- 256-color terminal.
- True-color terminal.
- Terminals with and without focus, mouse, and bracketed-paste support.
- Kitty graphics, Sixel, iTerm images, and Unicode-only fallback.
- Narrow terminals, resize storms, and output backpressure.

Required lifecycle evidence:

- Raw mode, cursor, mouse modes, paste mode, and alternate screen restore after
  normal exit, exception, cancellation, interrupt, and partial backend failure.
- Inline and alternate-screen modes do not overwrite unrelated terminal content.
- Capability fallback never emits an unsupported graphics protocol.

## Gate 7: benchmarks

Benchmark with fixed datasets and record time, allocations, and output size:

- Full-buffer render and sparse diff.
- Unicode text segmentation and clipping.
- Layout at increasing node counts.
- Style selector matching and cascade resolution.
- Toolkit reconciliation for stable, inserted, moved, and replaced trees.
- Virtual list, table, and tree windows at large logical sizes.
- Rich Markdown, syntax, code diff, and log rendering.
- Animation ticks at increasing active-track counts.
- Action resolution, event routing, and semantic diffing.
- Notification, overlay, and application-service pulses.

Regression thresholds belong in versioned benchmark configuration. Do not compare
wall-clock results from different hardware without normalization.

## Gate 8: compatibility matrix

Test the minimum supported Julia version and the latest supported stable Julia on
Linux, macOS, and Windows where terminal capabilities differ. Record unsupported
features explicitly rather than silently skipping them.

Validate clean installation, precompilation, package loading, unit tests, examples,
and representative PTY scenarios in every matrix job.

## Gate 9: documentation

Required evidence:

- Every documented symbol is exported or qualified correctly.
- Every code example parses and runs in a clean project.
- API reference, migration mappings, component catalog, and parity ledger agree.
- Links in `docs/README.md` resolve.
- Release notes identify behavior changes and deprecations.

## Evidence recording

For each release candidate, record:

- Julia version, operating system, architecture, and terminal identity.
- Commit identifier and dependency manifest digest.
- Commands executed and exit status.
- Test counts, skipped tests, and retry counts.
- Snapshot changes and approvals.
- Benchmark baseline and regressions.
- Known limitations and accepted risk.

## Production acceptance

Production parity requires all mandatory gates to pass with no unexplained skips,
terminal lifecycle failures, data races, or unresolved high-severity defects. Source
presence, examples that were not executed, and narrow happy-path tests are not
sufficient evidence.
