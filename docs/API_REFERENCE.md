# API Reference Overview

This page maps Wicked's public API by responsibility. It is an orientation guide,
not a replacement for Julia-generated docstrings.

## Rendering core

Use these types for immediate-mode rendering:

- `Rect`, `Position`, and `Size` describe terminal geometry.
- `Style`, terminal colors, and text modifiers describe cell appearance.
- `Span`, `Line`, and `Text` preserve styled text structure.
- `Cell` and `Buffer` hold the desired terminal image.
- `Frame` provides one render pass and cursor ownership.
- Buffer diffing emits only changed cells through a terminal backend.

Widgets implement `render!` against a `Buffer` or `Frame`. Stateful widgets keep
selection, cursor, scrolling, or animation state in an explicit state object.

## Layout

Wicked supports constraint layout, flex rows and columns, grids, docking, flows,
alignment, padding, margins, and clipping. Layout operates on `Rect` values and does
not depend on a terminal backend.

Use external state for resizable split panes and scroll offsets. Virtualized
collections expose windows rather than allocating one widget per data item.

## Terminal and backends

The terminal lifecycle owns raw mode, alternate-screen entry, cursor visibility,
mouse capture, bracketed paste, focus events, and restoration after failure.

Available backends include ANSI output and deterministic test buffers. Graphics
capability negotiation supports Unicode fallback plus Kitty, Sixel, and iTerm image
protocols.

## Events and interaction

Typed events cover keys, text, paste, mouse input, resize, focus, ticks, and custom
messages. Interaction services provide:

- Focus traversal and scoped focus restoration.
- Key bindings and named actions.
- Pointer hit testing and capture.
- Clipboard and OSC 52 integration.
- Drag-and-drop sessions.
- Semantic action dispatch for accessibility tools.

`ActionRegistry` is the discoverable behavior layer. An `Action` can appear in a
binding map, command palette, menu, test, or automation client while returning any
application-defined command or value.

## Core widgets

Text and structure:

- Blocks, labels, paragraphs, rules, badges, alerts, headers, and footers.
- Rich Markdown, `MarkupText`, syntax-highlighted code, links, diffs, logs, and rich
  surfaces.

Input and selection:

- Buttons, checkboxes, toggles, radio groups, `TextInput`, `SearchInput`,
  `PasswordInput`, text areas, selects, numeric and masked controls, and
  multi-select controls.
- Lists, tables, trees, tabs, menus, and command palettes.
- Autocomplete, combo boxes, tags, numeric and masked input, date/time pickers, and
  color pickers.

Navigation and advanced controls:

- Scroll views, split panes, breadcrumbs, collapsibles, accordions, pagination,
  steppers, dialogs, carousels, timelines, and file browsers.
- `ContentSwitcher`, `TabbedContent`, and `TabbedContentView` coordinate keyed,
  cached, lazily constructed application pages.
- `OverlayManager` coordinates dialogs, menus, popovers, tooltips, and modal input
  barriers.

Visualization:

- Gauges, line gauges, `ProgressBar`, sparklines, bars, charts, calendars, spinners,
  and braille canvases.
- `ProgressTracker` adds timed task lifecycle, ETA, aggregation, and immutable
  snapshots above the visual progress widget.

## Virtualization

Virtual list, table, and tree APIs separate data sources, viewport windows, retained
selection, rendering, and input. Use them when total rows or nodes are substantially
larger than the terminal viewport.

## Declarative Toolkit

Toolkit elements provide stable keys, reconciliation, routed events, focus, screens,
styles, semantics, and component builders above the immediate-mode core.

`ToolkitElementAdapter` connects rich or stateful domain views to Toolkit elements.
Component builders return a visual element and matching semantic tree from one
state snapshot.

## Reactive state

Reactive values, computed values, transactions, effects, and subscriptions support
fine-grained invalidation. `ReactiveElement` caches a Toolkit element until its
dependencies change. `ReactiveClassSet` binds style classes to reactive predicates.

Transactions coalesce notifications and restore values and versions after failure.
Dispose reactive elements and class bindings when their Toolkit lifecycle ends.

## Application services

`ApplicationServices` groups cross-cutting managers:

- `OverlayManager`
- `AnimationManager`
- `ActionRegistry`
- `ThemeRegistry`
- `NotificationManager`
- `LiveReloadManager`
- `ProgressTracker`
- Optional `EventRecorder`

Call `pulse_services!` once per runtime frame or timer. It shares one clock value,
advances animations, polls reload targets, expires notifications, and returns render
reasons. `shutdown_services!` performs bounded lifecycle convergence and trace
sealing.

## Styling and themes

Stylesheets support selectors, classes, pseudo-state, inheritance, specificity, and
cascade resolution. `StyleEngine` owns the current low-level theme and stylesheets.

`ThemeRegistry` adds named light, dark, and high-contrast variants, deterministic
preference selection, live replacement, derived roles, subscriptions, and safe
engine binding.

## Animation

`AnimationTrack` stores keyframes and interpolation. `AnimationSpec` adds duration,
delay, iteration, direction, replacement key, and essential-motion policy.

`AnimationManager` is pull-driven: call `tick_animations!` with the runtime clock.
It supports pause, resume, cancellation, keyed replacement, reduced motion, disabled
motion, and isolated callback failures.

## Notifications

`NotificationCenter` is the small immediate-mode collection used by
`NotificationView`. `NotificationManager` adds synchronized lifecycle, actions,
deduplication, pause/resume timeout accounting, accessibility announcements, events,
and generation tracking.

Use `notification_component` and `bind_notification_semantics!` for Toolkit and
semantic action integration.

## Development and diagnostics

- `LiveReloadManager` performs debounced, two-phase, runtime-polled asset reloads.
- Diagnostics expose frame timing, invalidation, runtime tasks, and component state.
- `EventRecorder` and `ReplayController` capture and replay deterministic sessions.
- Test backends, pilots, semantic queries, and snapshots support application tests.
- Extension registries isolate optional integrations from the core package.

## API conventions

- Functions ending in `!` may mutate explicit state or a manager.
- Rendering does not own application state unless a retained manager is explicit.
- User callbacks execute outside manager locks unless their documentation says they
  are pure predicates or interpolators.
- Manager snapshots return copied containers; payload ownership follows the
  documented snapshot policy.
- Injected clocks return monotonic, non-negative nanoseconds.
- Lifecycle handles are manager-local and must be disposed or unbound explicitly.
- Missing IDs return `false` or `nothing` for idempotent lifecycle operations and
  throw `KeyError` when the operation requires an existing target.

## Generated public API

Generated reference documentation is partitioned by responsibility so each page remains navigable and within the documentation size budget:

- [Core API](API_CORE.md)
- [Public API Facades](API_FACADES.md)
- [Immediate Widgets API](API_WIDGETS.md)
- [Backends and Runtime API](API_BACKENDS_RUNTIME.md)
- [Controls API](API_CONTROLS.md)
- [Navigation and Forms API](API_NAVIGATION.md)
- [Rich Content API](API_RICH_CONTENT.md)
- [Graphics API](API_GRAPHICS.md)
- [Toolkit and Reactive API](API_TOOLKIT.md)
- [Semantics, Testing, and Diagnostics API](API_SEMANTICS_TESTING.md)
- [Virtualization API](API_VIRTUALIZATION.md)
- [Extensions and Services API](API_EXTENSIONS_SERVICES.md)
