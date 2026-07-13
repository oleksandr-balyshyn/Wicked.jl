# Overlay Layout

Overlay layout APIs are available through the stable `Wicked.API` facade.

`OverlayManager` owns ordering and lifecycle. `OverlayLayoutRequest` converts each
record's placement policy into terminal bounds for one viewport.

## Fixed placement

```julia
request = OverlayLayoutRequest(handle, Size(12, 48); margin=1)
layout = layout_overlay(request, options, viewport)
```

Center, fullscreen, edges, and corners respect the configured viewport margin.
Desired dimensions are clipped to available terminal cells and reported through
`layout.clipped`.

## Anchored placement

```julia
request = OverlayLayoutRequest(
    handle,
    Size(8, 30);
    anchor=button_bounds,
    preferred=[
        AnchorBelowStart,
        AnchorAboveStart,
        AnchorBelowEnd,
    ],
    row_offset=1,
)
```

Anchored layout tries preferred directions in order. The first fully fitting
candidate wins. If none fits, Wicked chooses the candidate with the largest visible
area and clamps it into the viewport. This supports menus, popovers, completion
lists, and tooltips near terminal edges.

## Layout a manager snapshot

```julia
layouts = layout_overlays(overlays, viewport) do record, available
    desired = measure_overlay(record.content, available)
    OverlayLayoutRequest(
        record.handle,
        desired;
        anchor=anchor_for(record),
    )
end
```

Results preserve manager paint order. Request callbacks run without the manager lock
because `layout_overlays` operates on immutable overlay record snapshots.
