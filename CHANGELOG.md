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
- Linux CI definitions, executable examples, repository quality checks, deterministic fuzz/property tests, and versioned allocation benchmarks.
- Stable `Wicked.API` exports for the complete renderable widget inventory, including container, utility, heatmap, histogram, managed notification, and tabbed-content view widgets.
- Default-state rendering for every direct stateful renderable, with `state_for(widget)` guidance, regression coverage, precompile warmup, and audit/quality-gate policy to prevent stateful-only widget drift.
- A first-class `Autocomplete` immediate widget that reuses `AutocompleteState`, data-entry key bindings, pointer activation, semantic list output, and default-state rendering.
- A first-class `ComboBox` immediate widget that wraps `ComboBoxState` with editable query support, autocomplete-backed options, pointer activation, semantic output, and default-state rendering.
- A first-class `TagInput` immediate widget that wraps `TagInputState` with chip rendering, paste-to-add, keyboard removal, pointer removal, semantic output, and default-state rendering.
- A first-class `Slider` immediate widget that wraps `SliderState` with keyboard bindings, pointer value selection, semantic output, and default-state rendering.
- A first-class `RangeSlider` immediate widget that wraps `RangeSliderState` with active-handle keyboard control, nearest-handle pointer movement, semantic output, and default-state rendering.
- A first-class `Collapsible` immediate widget that wraps `CollapsibleState` with child rendering, keyboard and pointer toggling, semantic output, and default-state rendering.
- A first-class `Accordion` immediate widget that wraps `AccordionState` with section child rendering, key-based expansion, pointer toggling, semantic output, and default-state rendering.
- A first-class `Carousel` immediate widget over `CarouselState`, adding picker-style navigation, semantic metadata, default rendering, and keyboard/pointer movement.
- A first-class `DatePicker` immediate widget name over the existing `DatePickerState` calendar renderer, matching common TUI widget catalogs while preserving `DateInput` compatibility.
- A first-class `TimePicker` immediate widget name over the existing `TimePickerState` clock renderer, matching common TUI widget catalogs while preserving `TimeInput` compatibility.
- A first-class `DateTimePicker` immediate widget name over the existing combined date-time renderer, matching picker catalogs while preserving `DateTimeInput` compatibility.
- First-class `DirectoryPicker` and `MultiFilePicker` wrappers over `FilePicker`, giving directory and multi-selection workflows stable widget names while preserving `FileBrowserState`.
- A first-class `RadioButton` wrapper over `RadioGroup`, giving radio-button naming its own direct widget identity while preserving `RadioGroupState`.
- A first-class `ListBox` wrapper over `List`, giving list-box naming its own direct widget identity while preserving `ListState`.
- A first-class `TransferList` wrapper over `MultiSelect`, giving transfer-list naming its own direct widget identity while preserving `MultiSelectState`.
- A first-class `Panel` wrapper over `Card`, giving panel naming its own direct widget identity while preserving bordered-card rendering.
- A first-class `Combobox` wrapper over `Select`, preserving retained-style dropdown naming separately from the editable `ComboBox` control.
- A first-class `Border` wrapper over `Block`, giving bordered-surface naming its own direct widget identity while preserving `Block` rendering.
- First-class `Wrap`, `Dock`, and `Modal` wrappers, giving layout and modal naming stable direct widget identities while preserving existing flow, dock-layout, and dialog behavior.
- First-class `TitleBar` and `StatusBar` wrappers over `Header` and `Footer`, giving application chrome stable shell-oriented widget identities.
- A first-class `Overlay` wrapper over `Stack`, giving layered composition a stable overlay-oriented widget identity.
- First-class `RichText` and `LoadingIndicator` wrappers, replacing alias-only stable names with direct renderable widget identities.
- A first-class `SearchInput` wrapper over `TextInput`, giving query fields a stable search-oriented widget identity while preserving `TextInputState`.
- A first-class `PasswordInput` wrapper over `TextInput`, giving masked credentials a stable password-oriented widget identity while preserving `TextInputState`.
- A first-class `Textarea` wrapper over `TextArea`, adding the compatibility spelling used by the parity roadmap while preserving `TextAreaState`.
- `examples/widget_gallery.jl`, a deterministic gallery for stable immediate-mode widget names.
- A Linux real-terminal matrix worksheet for release-candidate terminal evidence.
- `scripts/compatibility_widget_alias_audit.jl` and quality-gate enforcement for stable direct-renderable and public widget-name-map compatibility names.

### Changed

- Declarative child storage is type-erased to avoid recursively specialized tree types.
- Toolkit identity uses interned parent-linked paths instead of ancestry tuples.
- Empty Toolkit style passes are skipped when no rule, role, or inline patch can apply.
- Reactive transactions use nested savepoints and aggregate notification failures.
- Hidden Toolkit subtrees remain mounted while being excluded from rendering and focus.
- Content switcher and tabbed-content APIs moved into the stable facade with their buffer renderer and Toolkit/semantic adapters.
- Reviewed widget, layout, semantic, runtime, reactive, testing, and Toolkit callback helpers moved into `Wicked.API`; `Wicked.Experimental` is now a compatibility namespace with no application-facing experimental bindings.
- Widget coverage and component-catalog governance now require stable compatibility widget names and state contracts to be exported by `Wicked.API` as concrete or parameterized type bindings, documented in focused API guides, and tracked in the 145-renderable coverage ledger when directly renderable.

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
