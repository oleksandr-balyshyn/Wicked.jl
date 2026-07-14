# Migrating from Other TUI Frameworks

Wicked.jl combines ideas from Ratatui, Textual, TamboUI, and Lanterna behind Julia-native APIs. This guide maps familiar concepts to Wicked.jl, identifies behavior that does not translate directly, and provides an incremental migration path. It is an architecture and API guide, not a claim that every feature has passed the production verification matrix. Consult the [Feature Parity Ledger](./FEATURE_PARITY.md) for the evidence boundary.

For concrete widget names, use the public name map in the
[Component Catalog](./COMPONENT_CATALOG.md#public-widget-name-map). It lists
the stable `Wicked.API` names and their state contracts for common components
such as panels, title bars, search fields, password fields, combo boxes, modal
dialogs, file pickers, and loading indicators.
The same map is available programmatically through `widget_vocabulary`,
`search_widget_vocabulary`, `widget_vocabulary_entry`, and
`widget_vocabulary_widget_names`:

```julia
using Wicked.API

button_names = widget_vocabulary_widget_names("Button")
text_entry_names = widget_vocabulary_widget_names("Single-line text field")
matches = search_widget_vocabulary("TextInput")
table = widget_vocabulary_markdown()
```

The same vocabulary can be exported from the catalog renderer:

```sh
julia --project=. scripts/render_widget_catalog.jl --vocabulary
julia --project=. scripts/render_widget_catalog.jl --vocabulary-widgets --query "Single-line text field"
```

## Stable widget vocabulary quick map

Use these names first when translating common examples from Ratatui, Textual,
TamboUI, or Lanterna. They are application-facing `Wicked.API` names; lower-level
helper types should stay qualified under their owning modules unless the API
reference explicitly lists them.

| Source-framework concept | Preferred Wicked API |
| --- | --- |
| Static text or label | `Label`, `Paragraph`, `Static`, `TextView`, `Heading`, `MarkupText` |
| Divider or separator | `Rule`, `Separator`, `Divider` |
| Button or push button | `Button`, `PushButton`, `SplitButton` |
| Checkbox, toggle, radio, multiselect | `Checkbox`, `CheckBox`, `Toggle`, `Switch`, `RadioGroup`, `RadioSet`, `RadioBoxList`, `CheckBoxList`, `MultiSelect`, `SelectionList`, `TransferList` |
| Text entry | `Input`, `TextInput`, `TextBox`, `TextField`, `PasswordInput`, `PasswordField`, `SearchInput`, `TextArea`, `Textarea` |
| Advanced entry | `NumberInput`, `MaskedInput`, `Autocomplete`, `ComboBox`, `Combobox`, `TagInput` |
| Lists, tables, and trees | `List`, `ListBox`, `ListView`, `OptionList`, `Table`, `DataTable`, `DataGrid`, `DataStateView`, `VirtualTable`, `Tree`, `TreeView`, `VirtualTree`, `TreeTable`, `PropertyList`, `KeyValueList`, `MetadataList`, `DescriptionList`, `DefinitionList` |
| Navigation and shell | `Tabs`, `TabView`, `TabbedContentView`, `Menu`, `ContextMenu`, `MenuBar`, `MenuButton`, `NavigationRail`, `Sidebar`, `Toolbar`, `ShortcutBar` |
| Overlays and top-level surfaces | `Dialog`, `Modal`, `Window`, `Popover`, `Tooltip`, `Drawer`, `Overlay`, `Layer` |
| Feedback and empty/loading states | `Alert`, `Toast`, `NotificationView`, `ManagedNotificationView`, `Badge`, `Status`, `Skeleton`, `EmptyState`, `Placeholder`, `Progress`, `ProgressBar`, `LoadingIndicator`, `Spinner` |
| Files, dates, and pickers | `FilePicker`, `DirectoryPicker`, `DirectoryTree`, `MultiFilePicker`, `DatePicker`, `DateInput`, `TimePicker`, `TimeInput`, `DateTimePicker`, `DateTimeInput`, `ColorPicker` |
| Charts and rich content | `Sparkline`, `BarChart`, `Chart`, `Plot`, `Histogram`, `Heatmap`, `Canvas`, `MarkdownView`, `CodeView`, `SyntaxView`, `DiffView`, `LogView`, `RichLog` |
| Developer and terminal views | `HelpView`, `Inspector`, `DevConsole`, `TerminalView`, `ProcessView`, `ReplView`, `LiveDisplay`, `TaskMonitor`, `Pretty`, `Digits` |

## Layout and container migration aliases

When porting existing code, start with these direct aliases:

| Source pattern | Source name | Wicked equivalent |
| --- | --- | --- |
| Ratatui horizontal layout | `Layout::Direction::Horizontal`, `Layout::constraints` composition | `row(...)` |
| Ratatui vertical layout | `Layout::Direction::Vertical`, `Layout::constraints` composition | `column(...)` |
| Textual/Tui-like H/V containers | `Horizontal` / `Vertical` style containers | `hbox(...)`, `hstack(...)`, `vbox(...)`, `vstack(...)` |
| Overlay composition | layered / stacked containers | `zstack(...)` |
| Single centered child | `Centered` helper or shell centering wrappers | `centered(...)` |

A migration snippet:

```julia
using Wicked.API

# Ratatui-like row
layout_row = hstack(
    row_title,
    row_body,
    row_status;
    constraints=[Fill(1), Fill(2), Fill(1)],
    key=:header_row,
)

# Textual-like column
layout_column = vbox(
    status_label,
    detail_panel,
    controls;
    key=:left_column,
)

# Modal-style overlay stack
screen = zstack(
    background_view,
    tooltip_view,
    key=:overlay_stack,
)
```

These aliases are stable and part of the supported public migration layer. Prefer
the base `row`/`column` names for idiomatic Julia code when you do not need
source-level familiarity.

## Choose the closest Wicked.jl level

Start at the level that matches the source application rather than rewriting the application around the largest Wicked abstraction.

| Source design                                      | Recommended Wicked.jl entry point                              |
| -------------------------------------------------- | -------------------------------------------------------------- |
| Ratatui render loop and external widget state      | Immediate widgets with `Terminal#draw!` and `render!`          |
| Textual app, screens, widgets, CSS, and messages   | Declarative toolkit over the managed runtime                   |
| TamboUI immediate mode                             | Immediate widgets                                              |
| TamboUI `TuiRunner`                                | Managed `WickedApp` runtime                                    |
| TamboUI Toolkit DSL and Pilot                      | Declarative elements and `ToolkitPilot`                        |
| Lanterna `Terminal` or `Screen`                    | Backend, `Terminal`, `Frame`, and `Buffer`                      |
| Lanterna `TextGUI`                                 | Declarative toolkit, screens, dialogs, and focus scopes        |
| Existing application with its own event loop       | Immediate widgets and a custom `InputSource`                   |

The levels share geometry, text, layout, style, event, widget, and rendering contracts. An application can migrate one screen or widget at a time instead of switching architectures in one step.

## Migration quickstart paths

Use these stable quickstarts when translating a concrete source-framework
feature. They are deliberately organized by developer task rather than by
Wicked subsystem:

| Porting task | Stable Wicked guide |
| --- | --- |
| Translate a Ratatui draw closure, buffer test, or custom widget | [Core API](API_CORE.md), [Immediate Widgets API](API_WIDGETS.md), and [Immediate-mode Tutorial](IMMEDIATE_MODE_TUTORIAL.md) |
| Translate Textual `compose`, widget identity, focus, routed messages, or reactive fields | [Toolkit and Reactive API](API_TOOLKIT.md) and [Toolkit Tutorial](TOOLKIT_TUTORIAL.md) |
| Translate Textual CSS or TamboUI stylesheet rules | [Core API styling quickstart](API_CORE.md#stable-styling-quickstart) and [Theme Management](THEMES.md) |
| Translate workers, timers, subscriptions, or application commands | [Backends and Runtime API](API_BACKENDS_RUNTIME.md) and [Async Runtime](ASYNC_RUNTIME.md) |
| Translate forms, validation, pickers, menus, dialogs, overlays, or navigation shells | [Controls API](API_CONTROLS.md), [Navigation and Forms API](API_NAVIGATION.md), and [Application Services](APPLICATION_SERVICES.md) |
| Translate large lists, tables, trees, or lazy data views | [Virtualization API](API_VIRTUALIZATION.md) |
| Translate Markdown, code panes, diffs, logs, terminal captures, or developer views | [Rich Content API](API_RICH_CONTENT.md) and [Semantics, Testing, and Diagnostics API](API_SEMANTICS_TESTING.md) |
| Translate Pilot, DOM query, snapshot, semantic, or virtual-terminal tests | [Semantics, Testing, and Diagnostics API](API_SEMANTICS_TESTING.md) and [Accessibility and Testing](ACCESSIBILITY_TESTING.md) |
| Translate global action registries, notifications, progress, themes, live reload, tracing, or extension-owned services | [Extensions and Services API](API_EXTENSIONS_SERVICES.md) and [Application Services](APPLICATION_SERVICES.md) |

For a broader orientation, see the
[API Reference Overview route map](API_REFERENCE.md#developer-route-map). For a
short task-oriented mapping from source application shapes to Wicked examples,
see the [Porting Cookbook](PORTING_COOKBOOK.md).

## Common concept map

These mappings describe the closest responsibility, not necessarily identical ownership or syntax.

| Responsibility              | Ratatui                         | Textual                         | TamboUI                         | Lanterna                  | Wicked.jl                                      |
| --------------------------- | ------------------------------- | ------------------------------- | ------------------------------- | ------------------------- | ---------------------------------------------- |
| Terminal lifecycle          | `Terminal` and backend           | `App#run`                       | terminal and runner             | `Terminal`                | `Terminal`, backend, `with_terminal`, `Wicked.run` |
| Current drawing surface     | `Frame`                          | widget render result            | `Frame`                         | `Screen`                  | `Frame`                                        |
| Cell storage                | `Buffer`                         | strips and segments             | `Buffer`                        | screen back buffer        | row-major `Buffer`                             |
| Geometry                    | zero-based `Rect(x, y, w, h)`    | regions and sizes               | `Rect`                          | positions and sizes       | one-based `Rect(row, column, height, width)`   |
| Styled text                 | `Text`, `Line`, `Span`           | content and Rich renderables    | `Text`, `Line`, `Span`          | `TextCharacter`           | `Text`, `Line`, `Span`                         |
| Stateless rendering         | `Widget`                         | widget `render`                 | widget interface                | component drawing         | `render!(buffer, widget, area)`                 |
| External widget state       | `StatefulWidget`                 | usually retained on a widget    | stateful widget interface       | mutable component state   | `render!(buffer, widget, area, state)`          |
| Application update loop     | application-owned               | message pump                    | `TuiRunner`                     | GUI thread                | `WickedApp`, `update!`, commands, subscriptions |
| Retained identity           | application-owned               | DOM nodes                       | Toolkit elements                | GUI components            | keyed `Element` and `ToolkitTree`               |
| Styling                     | typed `Style`                    | Textual CSS                     | typed styles and CSS            | themes                    | typed `Style`, `Stylesheet`, `StyleEngine`      |
| Background work             | application-owned               | workers                         | runner commands                 | application threads       | commands, tasks, subscriptions, cancellation   |
| Headless interaction tests  | test backend and snapshots       | Pilot                           | Pilot                           | virtual terminal          | `WidgetPilot`, `RuntimePilot`, `ToolkitPilot`   |

## Migrate from Ratatui

Ratatui uses immediate-mode rendering: an application redraws the complete UI into a frame, then the terminal diffs the new buffer against the previous buffer. Its core widget contracts are `Widget` and `StatefulWidget`. Wicked preserves this model through `Terminal#draw!`, `Frame`, `Buffer`, and open `render!` multiple dispatch.

The closest translation of a Ratatui draw closure renders ordinary widgets into the current frame:

```julia
using Wicked.API

backend = TestBackend(6, 40)
terminal = Terminal(backend)

draw!(terminal) do frame
    render!(frame, Paragraph("Build status: ready"), frame.area)
end
```

Keep selection, scrolling, cursor, and editor state outside the widget when that state must survive reconstruction. This matches Ratatui's `StatefulWidget` pattern:

```julia
using Wicked.API

backend = TestBackend(8, 40)
terminal = Terminal(backend)
state = ListState(selected=1)
widget = List(["Build", "Test", "Release"])

draw!(terminal) do frame
    render!(frame, widget, frame.area, state)
end
```

Built-in stateful widgets also support default-state rendering:

```julia
render!(Buffer(3, 40), widget, Rect(1, 1, 3, 40))
```

Use this only for previews, examples, and smoke tests. Production render loops
should keep and reuse explicit state values, just as Ratatui applications keep
their `ListState`, `TableState`, or custom state outside the widget value.

### Important differences from Ratatui

- Wicked coordinates are one-based and named `row` and `column`; Ratatui rectangles are zero-based and use `x` and `y`.
- Julia multiple dispatch replaces Rust widget traits. External packages add `render!` methods without registering widget types.
- Wicked rendering does not consume widget values. There is no direct equivalent of ownership-driven `WidgetRef` variants.
- `with_terminal` and `Wicked.run` own cleanup. Applications should not reproduce terminal teardown in every render loop.
- Commands, subscriptions, and the toolkit are optional layers. A Ratatui-style application can remain entirely immediate mode.
- Capability values are explicit on each `Frame`, which makes color, input, and graphics fallback testable without a particular terminal.

### Ratatui migration sequence

1. Translate colors, modifiers, `Span`, `Line`, `Text`, `Rect`, and layout constraints.
2. Port leaf widgets by implementing `render!` methods against `Buffer`.
3. Move every `StatefulWidget` state value into an explicit Julia state type.
4. Translate the event parser boundary to typed `KeyEvent`, `MouseEvent`, `PasteEvent`, `ResizeEvent`, and `FocusEvent` values.
5. Wrap the terminal lifecycle in `with_terminal` or adopt `WickedApp` when commands and subscriptions replace application-owned task plumbing.
6. Recreate snapshots with `WidgetPilot` or `TestBackend`; do not compare Rust debug representations byte-for-byte.

The official Ratatui documentation describes its [immediate rendering model](https://ratatui.rs/concepts/rendering/), [buffer diff pipeline](https://ratatui.rs/concepts/rendering/under-the-hood/), [widget contracts](https://ratatui.rs/concepts/widgets/), and [layout system](https://ratatui.rs/concepts/layout/).

## Migrate from Textual

Textual is a retained application framework. Widgets have identity, lifecycle, events, messages, reactive attributes, styles, focus, and independent asynchronous behavior. Wicked's closest match is the declarative toolkit backed by the managed runtime, not the immediate API alone.

Represent a composed Textual widget tree as keyed `Element` values. Stable keys preserve instance state when the view is reconstructed:

```julia
using Wicked.API

root = Element(
    Button("Save");
    key=:save_button,
    id=:save,
    classes=[:primary],
    focusable=true,
)

pilot = ToolkitPilot(root; height=3, width=16)
focus_element!(pilot, :save)
key!(pilot, :enter)

@assert query_one(pilot; id=:save, focused=true).state isa ButtonState
```

Map Textual responsibilities by ownership:

| Textual concept                    | Wicked.jl approach                                                                    |
| ---------------------------------- | ------------------------------------------------------------------------------------- |
| `App#compose` and widget children   | Build keyed `Element` trees in the application view                                   |
| DOM identity and IDs               | Stable `key` for identity and `id` for lookup                                          |
| classes and pseudo-classes         | element classes plus toolkit state resolved by `StyleEngine`                          |
| CSS and component styles           | supported `Stylesheet` grammar, typed `StylePatch`, themes, and diagnostics           |
| events and custom messages         | typed events, routed toolkit events, managed application messages, and named actions  |
| reactive attributes                | explicit model state or reactive values with transactions and effects                 |
| watchers and computed values       | subscriptions, computed reactive state, or deterministic update logic                 |
| workers                            | runtime task commands with message delivery and structured cancellation               |
| screens and modals                 | screens, focus scopes, overlays, dialogs, and modal input barriers                    |
| Pilot and DOM queries              | `ToolkitPilot`, semantic queries, snapshots, virtual time, and routed input            |

### Important differences from Textual

- A retained tree is optional in Wicked. Rendering primitives and third-party immediate widgets do not depend on the toolkit.
- Wicked does not implement the complete browser CSS model. Unsupported selectors and properties produce diagnostics instead of silently approximating behavior.
- Application-domain mutation belongs to the managed UI task. Background tasks return messages rather than mutating retained widget state directly.
- Keys define retained identity explicitly. Position alone is not a safe identity when children move, disappear, or load asynchronously.
- Julia functions and multiple dispatch replace decorator-driven handlers and class metaprogramming. Macros are not required.
- Textual's Rich renderables do not transfer directly. Convert content into Wicked `Text`, `Line`, `Span`, Markdown, code, table, or custom widget values.

### Textual migration sequence

1. Model screens, application state, messages, and background results independently from widget instances.
2. Translate `App#compose` output into keyed element constructors and assign durable keys before introducing dynamic children.
3. Port styles into the supported stylesheet grammar and inspect every unsupported-property diagnostic.
4. Move event handlers into routed element handlers, named actions, or the managed `update!` boundary according to ownership.
5. Replace workers with cancellable runtime commands and subscriptions that return messages.
6. Port Pilot tests to `ToolkitPilot`, `pilot_semantic_tree`,
   `pilot_semantic_snapshot`, and `assert_semantic_snapshot`, preferring IDs,
   semantic roles, states, and actions over tree-position selectors.
7. Verify focus restoration, modal barriers, mount/unmount cleanup, and async completion ordering explicitly.

The official Textual guides document its [widget model](https://textual.textualize.io/guide/widgets/), [events and messages](https://textual.textualize.io/guide/events/), [reactivity](https://textual.textualize.io/guide/reactivity/), and [workers](https://textual.textualize.io/guide/workers/).

## Migrate from TamboUI

TamboUI and Wicked both expose layered APIs over an immediate buffer. TamboUI follows Ratatui's `Cell`, `Buffer`, `Frame`, layout, text, stateless widget, and external stateful widget concepts, then adds `TuiRunner`, a Toolkit DSL, styling, and Pilot testing. This makes migration primarily a language and ownership translation.

| TamboUI level or type          | Wicked.jl equivalent                                                         |
| ------------------------------ | ---------------------------------------------------------------------------- |
| Immediate mode                 | `Terminal#draw!`, `Frame`, and `render!`                                      |
| `TuiRunner`                    | `WickedApp`, `Wicked.run`, commands, and subscriptions                       |
| Toolkit DSL                    | keyed `Element` trees and toolkit containers                                  |
| `WidgetInterface`              | stateless `render!` method                                                     |
| `StatefulWidgetInterface<S>`   | stateful `render!` method with an explicit state argument                      |
| `Buffer`, `Cell`, `Rect`       | `Buffer`, `Cell`, and one-based `Rect`                                         |
| `Text`, `Line`, `Span`         | `Text`, `Line`, and `Span`                                                     |
| CSS styling                    | `Stylesheet`, `Selector`, `StylePatch`, `StyleEngine`, and theme registry      |
| Pilot                          | `WidgetPilot`, `RuntimePilot`, and `ToolkitPilot`                              |
| Optional Markdown or media     | rich-content and graphics APIs, with optional integrations at package edges    |

### Important differences from TamboUI

- Julia constructor calls, keyword arguments, and `do` blocks replace Java builders and lambdas.
- Julia multiple dispatch replaces widget interfaces and generic state interface implementations.
- Wicked public coordinates remain one-based and use `(row, column)` order.
- `Wicked.API` makes the stability boundary explicit; TamboUI's current documentation labels the project experimental as a whole.
- Managed tasks use Julia tasks, channels, and structured cancellation rather than Java concurrency abstractions.

### TamboUI migration sequence

1. Port core values and immediate widgets directly, correcting coordinate origin and ordering.
2. Replace Java state holder classes with concrete Julia structs whose mutation contract is documented.
3. Translate `TuiRunner` updates and effects into a `WickedApp` model, `update!`, commands, and subscriptions.
4. Give every Toolkit child a durable key before translating dynamic Java collections.
5. Translate CSS rules property by property and treat diagnostics as migration failures until reviewed.
6. Split Pilot tests by ownership: `WidgetPilot` for an immediate widget,
   `RuntimePilot` for update/command behavior, and `ToolkitPilot` with
   `pilot_semantic_tree`, `pilot_semantic_snapshot`, or
   `assert_semantic_snapshot` for retained identity, routed interaction, and
   semantic assertions.

The official TamboUI documentation describes its [module and feature layers](https://tamboui.dev/docs/main/), [API levels](https://tamboui.dev/docs/main/api-levels.html), and [immediate buffer, text, widget, and event concepts](https://tamboui.dev/docs/main/core-concepts.html).

## Migrate from Lanterna

Lanterna exposes three layers: a low-level terminal interface, a full-screen buffer, and a retained `TextGUI`. Choose a Wicked level separately for each part of the application.

| Lanterna layer or concept       | Wicked.jl approach                                                                  |
| ------------------------------- | ----------------------------------------------------------------------------------- |
| Low-level `Terminal`            | rendering backend plus independent input source                                     |
| `Screen` and back buffer        | `Terminal`, `Frame`, row-major `Buffer`, and diff generation                        |
| `TextGUI`                       | declarative toolkit                                                                 |
| GUI components                 | widgets wrapped in keyed elements                                                    |
| GUI panes and modal dialogs      | screens, overlays, dialogs, focus scopes, and modal input barriers                  |
| `TextGraphics` drawing          | buffer draw operations, canvas, and custom `render!` methods                        |
| themes                          | typed styles, stylesheets, and named theme registry                                 |
| Swing terminal emulator         | no direct equivalent; use `TestBackend` for deterministic development and testing  |

### Important differences from Lanterna

- Wicked is pure Julia and targets ANSI-compatible terminal backends; it does not ship a graphical terminal emulator.
- The high-level toolkit is not modal-first. Overlays can be modeless or modal, and focus restoration and input barriers are explicit.
- Immediate rendering remains available beneath high-level components. A custom widget does not need to subclass a retained GUI component.
- Screen coordinates are one-based and cell-width-aware. Audit every conversion from Lanterna positions and sizes.
- Terminal output and input are separate interfaces, allowing applications to combine Wicked rendering with a custom event source.

### Lanterna migration sequence

1. Separate direct terminal operations, screen-buffer drawing, and GUI components in the source application.
2. Port direct drawing to `Buffer` operations or focused immediate widgets.
3. Replace `Screen#refresh` loops with `Terminal#draw!`; let Wicked own current/previous buffers and backend synchronization.
4. Translate GUI panes into screens or overlays and decide explicitly which overlays block input.
5. Translate mutable components into application model state or keyed toolkit state according to ownership.
6. Replace Swing-emulator tests with `TestBackend`, pilots, snapshots, and selected real-terminal runs.
7. Verify terminal lifecycle, focus, resize, and capability fallback on each deployment terminal.

Lanterna's official repository documents its [terminal, screen, and GUI toolkit layers](https://github.com/mabe02/lanterna).

## Port custom widgets safely

Custom widgets should preserve behavior rather than mirror source-language type structure.

1. Define a small immutable widget value for configuration and content.
2. Define a separate mutable or immutable state value when selection, scrolling, editing, or animation survives widget reconstruction.
3. Implement clipped and zero-area-safe `render!` methods.
4. Implement typed keyboard, pointer, paste, focus, and semantic actions that apply to the widget.
5. Add `measure` behavior when layout depends on content.
6. Add semantic role, label, state, bounds, and actions for interactive behavior.
7. Test normal, minimal, zero, clipped, resized, disabled, focused, and invalid states.
8. Verify the immediate widget directly before wrapping it in a keyed toolkit element.

Do not emit ANSI sequences from a widget. Widgets write cells; only backends translate cell changes into terminal control output.

## Port asynchronous behavior safely

Treat the managed UI task as the owner of application state. A background operation returns a message, and `update!` applies that message. This rule replaces direct worker-to-widget mutation found in some retained applications.

Use these ownership decisions during migration:

| Work type                         | Wicked.jl mechanism                                                   |
| --------------------------------- | --------------------------------------------------------------------- |
| One finite asynchronous operation | Task command that returns a message                                   |
| Recurring external input          | Subscription with cancellation                                       |
| Delayed action                    | Monotonic delayed command or virtual-clock schedule in tests          |
| UI-only state transition          | Direct mutation inside managed `update!`                              |
| Cross-component operation         | Named action or application message                                   |
| Long-lived external resource      | Scoped resource with idempotent cleanup                               |

Every migration should test cancellation, stale completion, callback failure, application exit, and cleanup after partial initialization.

## Validate a migration

A successful compile proves only that names and signatures translate. Record behavioral evidence in this order:

1. Load and precompile the application in a clean Julia environment.
2. Render representative states through `TestBackend`.
3. Drive interaction through the appropriate pilot and virtual time.
4. Compare visual and semantic snapshots.
5. Inject command, callback, parser, and terminal-write failures.
6. Run the application under a pseudo-terminal and confirm restoration.
7. Test the actual terminal, multiplexer, remote transport, Unicode corpus, and graphics protocols used in production.
8. Record performance and allocation changes for equivalent workloads.

Use the [Validation Strategy](./VALIDATION_STRATEGY.md), [Terminal Compatibility Evidence](./TERMINAL_COMPATIBILITY.md), and [Release Checklist](./RELEASE_CHECKLIST.md) for the complete acceptance requirements.

## Current limits

Wicked's source and integration surface is broad, but the project does not yet claim production parity with the reference frameworks. In particular, the Linux candidate run, required real-terminal matrix, two-real-application release evidence, and final archived release record remain separate gates. Use `Wicked.API` for reviewed application code and keep subsystem internals qualified when upgrading.
