# SPEC

This repository’s behavior target is the parity-led implementation captured in:

- `docs/REFERENCE_PARITY_SURVEY.md` (capability intent and source comparison)
- `docs/FEATURE_PARITY.md` (implemented/missing/adapted feature notes)
- `docs/PARITY_EXECUTION_PLAN.md` (release-ready implementation sequence)
- `docs/WIDGET_STABILIZATION.md` (widget promotion and closeout contract)

The public target is a Julia production-grade terminal UI stack with:

1. Immediate-mode rendering parity (Ratatui-like geometry/rendering model).
2. Declarative composition and state flow (Textual/TamboUI-style)
3. Navigator/runtime/toolkit composition (screening, focus, modal overlays, key binding,
   diagnostics, accessibility semantics, services).
4. Strong promotion gates and release artifacts for any new public widget or API.

Implementation work is production-valid only when all required gates in
`docs/PARITY_EXECUTION_PLAN.md` and the stabilization surface gate pass.
