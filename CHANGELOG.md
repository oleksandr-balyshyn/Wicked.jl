# Changelog

All notable user-visible changes to Wicked.jl are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Immediate-mode rendering, explicit widget state, managed applications, and keyed declarative Toolkit layers.
- ANSI and headless terminal backends, inline mode, capability detection, mouse/focus/paste protocols, enhanced keyboard input, and terminal recovery APIs.
- Managed commands for tasks, processes, terminal operations, suspension, clipboard access, delays, cancellation, and interval subscriptions.
- Core and advanced widget families, rich Markdown/content views, virtual lists/tables/trees, graphics protocols, file browsing, overlays, navigation, forms, progress, and notifications.
- Stylesheets, themes, reactive state, semantic accessibility trees, actions, tracing/replay, live reload, animations, extensions, and application services.
- `WidgetPilot`, `RuntimePilot`, `ToolkitPilot`, `SemanticPilot`, virtual time, structured/ANSI/SVG snapshots, and semantic queries.
- Cooperative cancellation for paged data and bounded policies for terminal input, clipboard, filesystem, Markdown links, and extensions.
- Cross-platform CI definitions, executable examples, repository quality checks, deterministic fuzz/property tests, and versioned allocation benchmarks.

### Changed

- Declarative child storage is type-erased to avoid recursively specialized tree types.
- Toolkit identity uses interned parent-linked paths instead of ancestry tuples.
- Empty Toolkit style passes are skipped when no rule, role, or inline patch can apply.
- Reactive transactions use nested savepoints and aggregate notification failures.
- Hidden Toolkit subtrees remain mounted while being excluded from rendering and focus.

### Fixed

- Package loading and precompilation dependency declarations.
- Runtime subscription replacement, removal, callback failure delivery, and deterministic pilot scheduling.
- Toolkit duplicate-key/ID preflight and lifecycle side-effect isolation.
- Virtual page stale-result rejection, retry, eviction, and stable key selection.
- ANSI parser recovery after malformed, fragmented, oversized, and incomplete input.
- Stylesheet atomic parsing and deterministic cross-stylesheet cascade order.
- Clipboard OSC 52 framing, selection validation, bounds, UTF-8/MIME validation, and fallback behavior.
- File-browser root escape, symlink replacement, stale choices, unbounded results, and terminal-control filenames.
- Markdown unsafe-link classification, metadata budgets, and control-character rendering.
- Extension identifier bounds and cleanup after initialization or shutdown failures.

## 0.0.1

Initial development version and compatibility baseline. This version is not a stable release.
