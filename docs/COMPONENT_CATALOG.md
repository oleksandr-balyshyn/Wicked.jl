# Wicked.jl Component Catalog

This catalog records the intended public component surface. "Implemented" means
the source API exists. It does not imply that the production gates in
`ARCHITECTURE.md` have passed.

## Foundation

| Family | Components and capabilities | Status |
|---|---|---|
| Structure | Block, borders, clear, spacer, rule, padding, box | Implemented |
| Containers | Row, column, stack, overlay, center, grid, dock, flow | Implemented |
| Text | Label, paragraph, heading, markup text, spans, lines, wrapping, alignment | Implemented |
| Scrolling | Scroll state, viewport, ensure-visible, scrollbars | Implemented |
| Navigation | Tabs, menus, screen stack, overlays, drawers, popovers | Implemented |

## Input and selection

| Family | Components and capabilities | Status |
|---|---|---|
| Text editing | Text input, password input, search input, text area, cursor, selection, undo/redo | Implemented |
| Choices | Checkbox, toggle, radio group, select, multiselect | Implemented |
| Actions | Button, bindings, command palette, context menus | Implemented |
| Advanced entry | Numeric input, masked input, tags, autocomplete, combobox | Implemented |
| Pickers | Date, time, color, file, directory, multiple files | Implemented |
| Range controls | Slider, range slider, scrollbar, pagination | Implemented |

## Collections and large data

| Family | Components and capabilities | Status |
|---|---|---|
| Lists | Stateful list, multiselect, stable keys | Implemented |
| Tables | Table, virtual table, column layout, resize, sort/filter/search | Implemented |
| Trees | Tree, virtual tree, lazy expansion, cycle diagnostics | Implemented |
| Remote data | Paged async sources, loading/error slots, retry, cancellation, LRU pages | Implemented |
| Selection | Deferred range selection and type-ahead navigation | Implemented |

## Rich and developer content

| Family | Components and capabilities | Status |
|---|---|---|
| Markdown | Typed AST, tables, task lists, code fences, links, images | Implemented |
| Syntax | Pluggable lexers, Julia, JSON, shell, SQL | Implemented |
| Source view | Gutters, breakpoints, diagnostics, search, selection, copy | Implemented |
| Diff view | Unified parser, inline view, side-by-side view | Implemented |
| Logs | Log state, filtering-ready view, structured entries | Implemented |
| Help | Help view, key hints, command descriptions | Implemented |

## Data visualization

| Family | Components and capabilities | Status |
|---|---|---|
| Progress | Gauge, line gauge, spinner, stepper | Implemented |
| Series | Sparkline, bar chart, chart, histogram | Implemented |
| Grids | Heatmap, calendar | Implemented |
| Drawing | Canvas, points, lines, Braille rendering | Implemented |
| Terminal images | Kitty, Sixel, iTerm2, Unicode fallback, animation | Implemented |

## Application chrome and feedback

| Family | Components and capabilities | Status |
|---|---|---|
| Chrome | Header, footer, breadcrumbs, badges, key hints | Implemented |
| Feedback | Alert, notifications, skeleton, empty state | Implemented |
| Dialogs | Dialog state, modal stack, dismiss policies | Implemented |
| Navigation | Collapsible, accordion, carousel, timeline | Implemented |
| Split UI | Split pane and pointer resize handles | Implemented |

## Framework services

| Family | Capabilities | Status |
|---|---|---|
| Runtime | Model/update/view, commands, tasks, intervals, cancellation | Implemented |
| Toolkit | Elements, keyed reconciliation, mount/unmount, routed events, screens | Implemented |
| Styling | Themes, semantic roles, selectors, specificity, stylesheet parser | Implemented |
| Forms | Schemas, synchronous and asynchronous validators, summaries | Implemented |
| Reactive | Signals, computed values, effects, transactions, classes, invalidation | Implemented |
| Accessibility | Semantic roles, trees, diffs, actions, announcements | Implemented |
| Automation | Pilot input, queries, clicks, snapshots, semantic actions | Implemented |
| Diagnostics | Traces, frame metrics, inspector panels, instrumentation | Implemented |
| Clipboard | Memory, OSC 52, policies, editor integration | Implemented |
| Drag/drop | Payload negotiation, capture, targets, Toolkit routing | Implemented |
| Extensions | Dependencies, activation, contributions, services | Implemented |
| Reliability | Error boundaries, resource scopes, managed tasks | Implemented |

## Validation status

The repository still requires its production validation campaign. In particular,
the original placeholder test suite must be replaced, the package must be loaded
on supported Julia versions, and all terminal compatibility and benchmark gates
must be executed. See `FEATURE_PARITY.md` and `ARCHITECTURE.md` for the remaining work.
