# Overlays

Overlay manager, modal stack, tooltip, drawer, popover, and screen stack APIs are
available through the stable `Wicked.API` facade.

For simple immediate-mode layering inside one rectangle, use `Overlay`. It
renders children in order, so later children paint over earlier children:

```julia
overlay = Overlay(Paragraph("dashboard"), Label("menu"))
render!(buffer, overlay, area)
```

Wicked treats dialogs, popovers, menus, command palettes, tooltips, and temporary
panels as overlays managed by one `OverlayManager`. The manager owns ordering,
modal input barriers, dismissal policy, focus restoration metadata, and lifecycle
notification. Overlay content remains an ordinary widget or component.

## Open and close an overlay

```julia
manager = OverlayManager()

handle = open_overlay!(
    manager,
    confirmation_dialog;
    options=OverlayOptions(
        modality=ModalOverlay,
        placement=OverlayCenter,
        dismiss_on_escape=true,
        trap_focus=true,
        group=:dialogs,
    ),
    focus_restore_token=:delete_button,
    on_close=(record, reason) -> @info "dialog closed" reason,
)

close_overlay!(manager, handle)
```

`OverlayHandle` values are stable for the lifetime of a manager. Closing an
already-closed or unknown handle returns `false`.

## Route input

Use `overlay_entries(manager)` for painting. It returns records from lowest to
highest priority. Use `active_overlay_entries(manager)` for input routing. The
highest modal record blocks all records beneath it while leaving them available
for painting.

```julia
paint_order = overlay_entries(manager)
input_order = reverse(active_overlay_entries(manager))
target = top_overlay(manager)
```

An application should route an event to the first accepting overlay in
`input_order`. If none accepts it and no modal overlay is active, route the event
to the underlying screen.

## Dismissal

The manager provides policy-aware dismissal helpers:

```julia
dismiss_overlay_on_escape!(manager)
dismiss_overlay_on_blur!(manager, handle)
```

These functions return `false` when no matching overlay exists or the relevant
policy is disabled. Close callbacks receive an `OverlayDismissReason`, allowing a
component to distinguish explicit closure, escape, blur, replacement, and
application shutdown.

## Exclusive groups

Exclusive groups are useful for command palettes, menus, and single-dialog
workflows. Opening a new exclusive overlay closes existing members of its group.

```julia
menu_policy = OverlayOptions(
    placement=OverlayAnchor,
    dismiss_on_blur=true,
    group=:application_menu,
    exclusive=true,
)

open_overlay!(manager, file_menu; options=menu_policy)
open_overlay!(manager, edit_menu; options=menu_policy)
```

The first menu closes with reason `OverlayGroupReplaced` before the second handle
is returned.

`configure_overlay!` applies the same rule when an existing record becomes
exclusive or moves to another exclusive group. Close handlers may be closures,
named functions, or callable structs; Wicked validates their two-argument calling
contract before changing manager state.

## Callback failures

Close callbacks execute after manager state is committed and outside its lock.
This permits callbacks to open or close other overlays without deadlocking.
Exceptions do not corrupt manager state or interrupt lifecycle processing. Inspect
them with `overlay_errors(manager)` or atomically drain them with
`take_overlay_errors!(manager)`.

## Focus restoration

`focus_restore_token` is intentionally untyped. A Toolkit integration can store a
focus node, component key, or application-specific locator. When a record closes,
its callback can restore focus if `record.options.restore_focus` is true. Modal
records trap focus by default; modeless records do not.

Use `OverlayLayoutRequest` and `layout_overlays` to resolve placement policies into
viewport-clipped terminal rectangles. Anchored layout supports ordered below, above,
left, and right fallbacks for popovers, menus, and tooltips.
