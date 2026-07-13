# Migration Guide

Wicked combines an immediate-mode rendering core with optional retained and
declarative layers. Choose the mapping that matches the source framework instead of
forcing every application into one architecture.

Use this page for migration from earlier Wicked root imports and for the shortest
architecture decision path. Use [Migrating from Other TUI Frameworks](FRAMEWORK_MIGRATION.md)
for detailed Ratatui, Textual, TamboUI, and Lanterna porting guidance, including
ownership differences and step-by-step migration sequences. Use the
[Porting Cookbook](PORTING_COOKBOOK.md) for short task-to-example mappings. Use the
[Component Catalog](COMPONENT_CATALOG.md#public-widget-name-map) for the stable
`Wicked.API` widget names to choose when porting examples or application code.
Use the
[framework migration quickstart paths](FRAMEWORK_MIGRATION.md#migration-quickstart-paths)
when a source-framework feature needs a direct route to the matching stable
Wicked API guide.

The feature-parity boundary remains evidence-driven. A component listed as
implemented or mapped here still requires the validation campaign described in
[Feature Parity Ledger](FEATURE_PARITY.md) and [Validation Strategy](VALIDATION_STRATEGY.md)
before it can be described as production-verified.

## Import migration for pre-1.0 applications

The broad root export surface has been replaced by two explicit facades:

```julia
using Wicked.API
```

Use `Wicked.API` for candidate stable application, widget, backend, runtime,
toolkit, form, theme, reactive, and testing contracts. The current reviewed
baseline has no application-facing experimental bindings.

All historical bindings remain accessible as qualified values such as
`Wicked.RemoteBackend` during the pre-`1.0` migration period. Root now exports only
`API` and `Experimental`; `using Wicked` no longer injects every widget state,
protocol enum, diagnostic record, and integration helper into the caller.

Replace `using Wicked` with `using Wicked.API` first. Add
qualified owning-module imports only for subsystem internals that are
intentionally outside the facade.

## From Ratatui

Ratatui concepts map directly to the immediate-mode layer:

| Ratatui | Wicked |
|---|---|
| `Rect` | `Rect` |
| `Style`, `Color`, `Modifier` | `Style`, terminal colors, text modifiers |
| `Buffer` | `Buffer` |
| `Frame` | `Frame` |
| `Widget::render` | `render!` |
| `StatefulWidget` | Widget plus explicit state object |
| `Layout` and constraints | Constraint, flex, grid, dock, and flow layout |
| `TestBackend` | Wicked test backend and buffer snapshots |

Keep model ownership in the application. Render widgets from the current model on
each frame, and route typed events through explicit `handle!` methods.

Ratatui applications can adopt Toolkit incrementally for screens, reconciliation,
reactive invalidation, semantic trees, or CSS-like styling without replacing the
buffer renderer.

## From Textual

Textual concepts map primarily to Toolkit and application services:

| Textual | Wicked |
|---|---|
| `App` and `Screen` | Runtime plus Toolkit screen stack |
| Widget DOM | Keyed Toolkit element tree |
| `compose()` | Declarative component builders |
| Reactive attributes | Reactive values, computed values, and `ReactiveElement` |
| CSS classes and pseudo-classes | Stylesheets, reactive classes, and style engine |
| Actions and bindings | `ActionRegistry`, `ActionBinding`, and `BindingMap` |
| Command palette | `CommandPalette` generated from actions |
| Workers | Runtime task commands and structured cancellation |
| Notifications | `NotificationManager` and Toolkit notification component |
| Animations | `AnimationManager`, tracks, easing, and motion policy |
| Content switcher and tabbed content | `ContentSwitcher` and `TabbedContent` |
| Pilot | Toolkit pilot, semantic queries, event tracing, and replay |

Textual owns more behavior inside widget instances. In Wicked, prefer immutable
widget descriptions plus explicit state or a retained manager. This makes state
serializable, testable, and reusable across buffer and Toolkit renderers.

## From Lanterna

Lanterna applications typically use a retained component and window model:

| Lanterna | Wicked |
|---|---|
| `Terminal` | Wicked terminal backend |
| `Screen` | Terminal lifecycle and frame buffer |
| `MultiWindowTextGUI` | Toolkit screen stack plus `OverlayManager` |
| Components | Stateful widgets and Toolkit component builders |
| Dialogs | Dialog state, semantic component, and modal overlays |
| Table/tree/list components | Core or virtualized stateful widgets |
| Input filters and validation | Data-entry controls and forms |

Start with Toolkit for retained navigation and focus. Use core widgets inside
components when precise rendering or backend independence matters.

## From TamboUI

TamboUI-style declarative applications map to keyed Toolkit elements, component
builders, reactive signals, routed events, and reconciliation. Keep keys stable
across renders and dispose subscriptions with component lifecycle.

Use `ToolkitElementAdapter` when domain rendering already produces rich lines or a
semantic model. Use `ReactiveElement` when only dependency changes should rebuild a
subtree.

## Architecture choices

Use the immediate-mode core when:

- The application is frame-oriented or game-like.
- Allocation and render control are primary constraints.
- State already lives in a reducer or domain model.

Use Toolkit when:

- The application has multiple screens, focus scopes, overlays, and reusable forms.
- Declarative composition and semantic queries improve maintainability.
- Reactive invalidation should avoid rebuilding unaffected subtrees.

Use both when:

- High-volume tables, charts, canvases, or logs need direct buffer rendering inside
  a larger declarative application.

## Behavioral differences

Wicked uses one-based terminal coordinates and Julia multiple dispatch. Mutable
operations end with `!`. Manager callbacks are isolated and generally execute
outside locks. Clocked facilities accept injected nanosecond clocks.

Widget state is deliberately explicit. A `Tabs` widget takes `TabsState`; a
`TabbedContentView` takes retained `TabbedContent`; a Toolkit component takes a
coherent content snapshot. Choose the smallest layer that owns the behavior you
need.

## Migration sequence

1. Port terminal startup and shutdown to Wicked's lifecycle API.
2. Map geometry, styles, text, and immediate widgets.
3. Port event parsing and key bindings.
4. Move widget-local mutable fields into explicit state objects or managers.
5. Introduce Toolkit screens and keyed components where retained composition helps.
6. Add actions, themes, notifications, overlays, and application services.
7. Recreate accessibility semantics and semantic action routing.
8. Port test scenarios to test backends, pilots, traces, and snapshots.
9. Measure rendering and virtualization before optimizing application code.

For ports from another framework, finish by recording the applicable reference
mapping in [Feature Parity Ledger](FEATURE_PARITY.md), checking the family in
[Parity Execution Plan](PARITY_EXECUTION_PLAN.md), and attaching release-candidate
evidence with [Parity Evidence Template](PARITY_EVIDENCE_TEMPLATE.md).
