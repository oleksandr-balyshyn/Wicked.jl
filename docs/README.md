# Wicked Documentation

## Start here

- [Getting Started](GETTING_STARTED.md)
- [Immediate-mode Tutorial](IMMEDIATE_MODE_TUTORIAL.md)
- [Toolkit Tutorial](TOOLKIT_TUTORIAL.md)
- [Architecture](ARCHITECTURE.md)
- [API Reference Overview](API_REFERENCE.md)
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
- [Component Catalog](COMPONENT_CATALOG.md)
- [Widget Coverage Audit](WIDGET_COVERAGE.md)
- [Framework Migration](FRAMEWORK_MIGRATION.md)
- [Developer Guide](DEVELOPER_GUIDE.md)

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
- [Async Runtime](ASYNC_RUNTIME.md)
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
- [Release Evidence](RELEASE_EVIDENCE.md)
- [Release Checklist](RELEASE_CHECKLIST.md)

Runnable public-API examples are in the repository's `examples` directory.

## Build the manual

Build the same strict Documenter manual used by CI from the repository root:

```sh
julia --project=docs --startup-file=no -e \
  'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs --startup-file=no docs/make.jl
```

The generated site is written to `build/docs`. Serve that directory with a local
HTTP server because the production build always uses pretty URLs.
