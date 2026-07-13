# Theme Management

`ThemeRegistry` manages named theme choices above the low-level `StyleEngine` theme
slot. It supports user selection, light and dark preferences, high-contrast themes,
live replacement, derived role maps, and change subscriptions.

The theme registry, theme descriptors, theme variants, change events,
style-engine binding, derivation helpers, role validation helpers, stylesheet
parser, selector cascade, and role-style resolver helpers are part of
`Wicked.API`.

## Register themes

```julia
themes = ThemeRegistry([
    ThemeDescriptor(:night, night_theme; display_name="Night", variant=DarkTheme),
    ThemeDescriptor(:paper, paper_theme; display_name="Paper", variant=LightTheme),
    ThemeDescriptor(
        :contrast,
        contrast_theme;
        display_name="High Contrast",
        variant=HighContrastTheme,
        priority=100,
    ),
]; active=:night)
```

Descriptors and role dictionaries are copied on registration and access. Application
code can therefore construct or inspect themes without mutating registry-owned
state accidentally.

## Bind a style engine

```julia
binding = bind_theme_engine!(themes, style_engine)
set_active_theme!(themes, :paper)
unbind_theme_engine!(binding)
```

The binding applies the active theme immediately and updates the engine after each
active-theme event. Subscribers run in registration order, outside the registry
lock. Failures are captured by `take_theme_errors!` and do not prevent later
subscribers from running.

Engine binding subscribes before initial application and converges by registry
generation, so a concurrent theme change cannot be missed or overwritten by stale
initial state. Updates for one binding are serialized. Unbinding disables future
callbacks and waits for an in-flight engine update before returning.

## Follow a preference

```julia
set_theme_preference!(themes, LightTheme)
```

Preference selection chooses the highest-priority matching variant, then the
lexicographically smallest ID. If no theme has the preferred variant, it selects
from all themes using the same deterministic rule.

Applications can map terminal background detection or user configuration to
`LightTheme`, `DarkTheme`, or `HighContrastTheme`.

## Derive themes

```julia
focused_theme = derive_theme(
    active_theme(themes),
    :focused;
    roles=Dict(:accent => accent_style, :focus => focus_style),
    remove=[:legacy_border],
)
```

`derive_theme` copies the base role map before applying removals and overrides. Use
`validate_theme_roles(theme, required_roles)` before registration when an
application or widget package requires semantic roles beyond Wicked's defaults.

## Live reload

A live reload target should parse and validate a complete `Theme`, then call
`register_theme!(themes, descriptor; replace=true)`. Replacing the active descriptor
emits `ActiveThemeReplaced`, so bound style engines update without changing the
selected theme ID.
