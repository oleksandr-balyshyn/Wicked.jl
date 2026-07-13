# Wicked Documentation

## Start here

- [Getting Started](GETTING_STARTED.md)
- [Immediate-mode Tutorial](IMMEDIATE_MODE_TUTORIAL.md)
- [Toolkit Tutorial](TOOLKIT_TUTORIAL.md)
- [Architecture](ARCHITECTURE.md)
- [API Reference Overview](API_REFERENCE.md)
- [Public Example Families](EXAMPLE_FAMILIES.md)
- [API Stabilization](API_STABILIZATION.md)
- [Widget Stabilization Tracker](WIDGET_STABILIZATION.md)
- [Stable Promotion Packet Template](STABLE_PROMOTION_PACKET_TEMPLATE.md)
- [Stable Promotion Packet Records](stable-promotion-packets/README.md)
- [Widget Family Evidence Ledger](WIDGET_FAMILY_EVIDENCE.md)
- [Public API Facades](API_FACADES.md)
- [Core API](API_CORE.md)
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
- [Performance and Latency Guide](PERFORMANCE.md)
- [Unicode Width Corpus](UNICODE_WIDTH_CORPUS.md)
- [Component Catalog](COMPONENT_CATALOG.md)
- [Widget Coverage Audit and Default-State Rendering](WIDGET_COVERAGE.md)
- [Framework Migration](FRAMEWORK_MIGRATION.md)
- [Porting Cookbook](PORTING_COOKBOOK.md)
- [Developer Guide](DEVELOPER_GUIDE.md)

For a goal-oriented API map, start with
[API Reference Overview](API_REFERENCE.md#developer-route-map). It points
Ratatui-style immediate rendering, Textual-style Toolkit apps, CSS-like styling,
runtime apps, virtual data, rich panes, testing, and services to the right stable
quickstart pages.

## Application capabilities

- [Application Services](APPLICATION_SERVICES.md)
- [Actions](ACTIONS.md)
- [Animations](ANIMATIONS.md)
- [Themes](THEMES.md)
- [Managed Notifications](NOTIFICATIONS.md)
- [Progress](PROGRESS.md)
- [Utility Widgets](UTILITY_WIDGETS.md)
- [Content Containers](CONTENT_CONTAINERS.md)
- [Overlays](OVERLAYS.md)
- [Overlay Layout](OVERLAY_LAYOUT.md)
- [Live Reload](LIVE_RELOAD.md)
- [Event Tracing and Replay](EVENT_TRACING.md)
- [Terminal Recovery](TERMINAL_RECOVERY.md)
- [Linux Real-Terminal Matrix](REAL_TERMINAL_MATRIX.md)
- [Terminal Evidence Template](TERMINAL_EVIDENCE_TEMPLATE.md)
- [Terminal Evidence Records](terminal-evidence/README.md)
- [Real Application Evidence Template](REAL_APPLICATION_EVIDENCE_TEMPLATE.md)
- [Real Application Evidence Records](application-evidence/README.md)
- [Benchmark Evidence Template](BENCHMARK_EVIDENCE_TEMPLATE.md)
- [Benchmark Evidence Records](benchmark-evidence/README.md)
- [Package Loading Evidence Template](PACKAGE_LOADING_EVIDENCE_TEMPLATE.md)
- [Package Loading Evidence Records](loading-evidence/README.md)
- [Documentation Evidence Template](DOCUMENTATION_EVIDENCE_TEMPLATE.md)
- [Documentation Evidence Records](documentation-evidence/README.md)
- [Semantic Accessibility Evidence Template](SEMANTIC_ACCESSIBILITY_EVIDENCE_TEMPLATE.md)
- [Semantic Accessibility Evidence Records](semantic-evidence/README.md)
- [Async Runtime](ASYNC_RUNTIME.md)
- [Remote Transport](REMOTE_TRANSPORT.md)
- [Accessibility and Testing](ACCESSIBILITY_TESTING.md)
- [Continuous Integration](CONTINUOUS_INTEGRATION.md)

## Adoption and release

- [Migration Guide](MIGRATION.md)
- [Versioning and Deprecation](../VERSIONING.md)
- [Changelog](../CHANGELOG.md)
- [Contributing](../CONTRIBUTING.md)
- [Code of Conduct](../CODE_OF_CONDUCT.md)
- [Support](../SUPPORT.md)
- [Security](../SECURITY.md)
- [Feature Parity Ledger](FEATURE_PARITY.md)
- [Validation Strategy](VALIDATION_STRATEGY.md)
- [Performance and Latency Guide](PERFORMANCE.md)
- [Widget Stabilization Tracker](WIDGET_STABILIZATION.md)
- [Stable Promotion Packet Template](STABLE_PROMOTION_PACKET_TEMPLATE.md)
- [Stable Promotion Packet Records](stable-promotion-packets/README.md)
- [Widget Family Evidence Ledger](WIDGET_FAMILY_EVIDENCE.md)
- [Release Evidence](RELEASE_EVIDENCE.md)
- [Parity Evidence Template](PARITY_EVIDENCE_TEMPLATE.md)
- [Parity Evidence Records](evidence/README.md)
- [Parity Evidence Policy](evidence/parity_policy.json)
- [Release Checklist](RELEASE_CHECKLIST.md)

Runnable public-API examples are in the repository's `examples` directory. Use
[Public Example Families](EXAMPLE_FAMILIES.md) to map each quickstart to the
feature family it demonstrates.

## Build the manual

Build the same strict Documenter manual used by CI from the repository root:

```sh
julia --project=docs --startup-file=no -e \
  'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs --startup-file=no docs/make.jl
```

The generated site is written to `build/docs`. Serve that directory with a local
HTTP server because the production build always uses pretty URLs.
