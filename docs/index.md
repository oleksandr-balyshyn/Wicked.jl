# Wicked.jl

Wicked.jl is a production-oriented terminal user-interface library for Julia. It
combines an immediate-mode rendering core with a managed application runtime and a
declarative component toolkit.

Start with the [Getting Started](GETTING_STARTED.md) guide, then choose the
[Immediate-mode Tutorial](IMMEDIATE_MODE_TUTORIAL.md) or
[Toolkit Tutorial](TOOLKIT_TUTORIAL.md) for the API layer that fits your
application.

## Design goals

- Correct Unicode-aware cell rendering and deterministic layout.
- Safe terminal ownership, typed input, and bounded resource use.
- Explicit low-level widget state plus managed toolkit state.
- Virtualized data, async commands, cancellation, and testable time.
- Themes, semantics, inspection, snapshots, and production diagnostics.
- Public extension boundaries for widgets, backends, and optional integrations.

The [Architecture](ARCHITECTURE.md) guide explains how these layers compose. The
[Component Catalog](COMPONENT_CATALOG.md) and
[API Reference](API_REFERENCE.md) describe the available surface.

The competitive-parity baseline used to drive implementation planning is tracked in
[REFERENCE_PARITY_SURVEY.md](REFERENCE_PARITY_SURVEY.md).
[Parity execution plan](PARITY_EXECUTION_PLAN.md) lists concrete family-level closure criteria.
For production onboarding, use [Loading and precompilation](PACKAGE_LOADING.md).
