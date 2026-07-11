using .Core: Rect, Size, intersection


@enum AnchorDirection::UInt8 begin
    AnchorBelowStart
    AnchorBelowEnd
    AnchorAboveStart
    AnchorAboveEnd
    AnchorRightStart
    AnchorRightEnd
    AnchorLeftStart
    AnchorLeftEnd
end

struct OverlayLayoutRequest
    handle::OverlayHandle
    desired::Size
    anchor::Union{Nothing,Rect}
    preferred::Vector{AnchorDirection}
    row_offset::Int
    column_offset::Int
    margin::Int
end

function OverlayLayoutRequest(
    handle::OverlayHandle,
    desired::Size;
    anchor::Union{Nothing,Rect}=nothing,
    preferred=AnchorDirection[
        AnchorBelowStart,
        AnchorAboveStart,
        AnchorBelowEnd,
        AnchorAboveEnd,
        AnchorRightStart,
        AnchorLeftStart,
    ],
    row_offset::Integer=0,
    column_offset::Integer=0,
    margin::Integer=0,
)
    margin >= 0 || throw(ArgumentError("overlay layout margin must be non-negative"))
    resolved = AnchorDirection[direction for direction in preferred]
    isempty(resolved) && throw(ArgumentError("anchored overlay requires a preferred direction"))
    return OverlayLayoutRequest(
        handle,
        desired,
        anchor,
        resolved,
        Int(row_offset),
        Int(column_offset),
        Int(margin),
    )
end

struct OverlayLayoutResult
    handle::OverlayHandle
    bounds::Rect
    placement::OverlayPlacement
    anchor_direction::Union{Nothing,AnchorDirection}
    clipped::Bool
end

function _overlay_inner_viewport(viewport::Rect, margin::Int)
    vertical = min(margin, div(viewport.height, 2))
    horizontal = min(margin, div(viewport.width, 2))
    return Rect(
        viewport.row + vertical,
        viewport.column + horizontal,
        max(0, viewport.height - 2vertical),
        max(0, viewport.width - 2horizontal),
    )
end

function _overlay_size(desired::Size, available::Rect)
    return Size(
        clamp(desired.height, 0, available.height),
        clamp(desired.width, 0, available.width),
    )
end

function _centered_overlay(available::Rect, size::Size)
    return Rect(
        available.row + div(available.height - size.height, 2),
        available.column + div(available.width - size.width, 2),
        size.height,
        size.width,
    )
end

function _edge_overlay(available::Rect, size::Size, placement::OverlayPlacement)
    placement == OverlayCenter && return _centered_overlay(available, size)
    placement == OverlayFullscreen && return available
    row = placement in (OverlayTopLeft, OverlayTop, OverlayTopRight) ? available.row :
        placement in (OverlayBottomLeft, OverlayBottom, OverlayBottomRight) ?
            available.row + available.height - size.height :
            available.row + div(available.height - size.height, 2)
    column = placement in (OverlayTopLeft, OverlayLeft, OverlayBottomLeft) ? available.column :
        placement in (OverlayTopRight, OverlayRight, OverlayBottomRight) ?
            available.column + available.width - size.width :
            available.column + div(available.width - size.width, 2)
    return Rect(row, column, size.height, size.width)
end

function _anchored_overlay(
    anchor::Rect,
    size::Size,
    direction::AnchorDirection,
    row_offset::Int,
    column_offset::Int,
)
    row = if direction in (AnchorBelowStart, AnchorBelowEnd)
        anchor.row + anchor.height
    elseif direction in (AnchorAboveStart, AnchorAboveEnd)
        anchor.row - size.height
    elseif direction in (AnchorRightStart, AnchorLeftStart)
        anchor.row
    else
        anchor.row + anchor.height - size.height
    end
    column = if direction in (AnchorRightStart, AnchorRightEnd)
        anchor.column + anchor.width
    elseif direction in (AnchorLeftStart, AnchorLeftEnd)
        anchor.column - size.width
    elseif direction in (AnchorBelowEnd, AnchorAboveEnd)
        anchor.column + anchor.width - size.width
    else
        anchor.column
    end
    return Rect(
        row + row_offset,
        column + column_offset,
        size.height,
        size.width,
    )
end

function _overlay_fits(bounds::Rect, available::Rect)
    return bounds.row >= available.row &&
           bounds.column >= available.column &&
           bounds.row + bounds.height <= available.row + available.height &&
           bounds.column + bounds.width <= available.column + available.width
end

function _visible_overlay_area(bounds::Rect, available::Rect)
    visible = intersection(bounds, available)
    return visible.height * visible.width
end

function _clamp_overlay(bounds::Rect, available::Rect)
    row = clamp(
        bounds.row,
        available.row,
        available.row + available.height - bounds.height,
    )
    column = clamp(
        bounds.column,
        available.column,
        available.column + available.width - bounds.width,
    )
    return Rect(row, column, bounds.height, bounds.width)
end

function layout_overlay(
    request::OverlayLayoutRequest,
    options::OverlayOptions,
    viewport::Rect,
)
    available = _overlay_inner_viewport(viewport, request.margin)
    size = _overlay_size(request.desired, available)
    size_clipped = size != request.desired
    if options.placement != OverlayAnchor
        bounds = _edge_overlay(available, size, options.placement)
        return OverlayLayoutResult(
            request.handle,
            bounds,
            options.placement,
            nothing,
            size_clipped,
        )
    end
    anchor = request.anchor
    anchor === nothing && throw(ArgumentError("anchored overlay layout requires an anchor"))
    candidates = Tuple{AnchorDirection,Rect}[
        (
            direction,
            _anchored_overlay(
                anchor,
                size,
                direction,
                request.row_offset,
                request.column_offset,
            ),
        ) for direction in request.preferred
    ]
    for (direction, bounds) in candidates
        _overlay_fits(bounds, available) && return OverlayLayoutResult(
            request.handle,
            bounds,
            OverlayAnchor,
            direction,
            size_clipped,
        )
    end
    best = first(candidates)
    best_area = _visible_overlay_area(last(best), available)
    for candidate in Iterators.drop(candidates, 1)
        area = _visible_overlay_area(last(candidate), available)
        if area > best_area
            best = candidate
            best_area = area
        end
    end
    return OverlayLayoutResult(
        request.handle,
        _clamp_overlay(last(best), available),
        OverlayAnchor,
        first(best),
        true,
    )
end

function layout_overlays(
    manager::OverlayManager,
    viewport::Rect,
    request_for,
)
    records = overlay_entries(manager)
    isempty(records) && return OverlayLayoutResult[]
    applicable(request_for, first(records), viewport) ||
        throw(ArgumentError("overlay request callback must accept a record and viewport"))
    results = OverlayLayoutResult[]
    for record in records
        request = request_for(record, viewport)
        request isa OverlayLayoutRequest ||
            throw(ArgumentError("overlay request callback must return OverlayLayoutRequest"))
        request.handle == record.handle ||
            throw(ArgumentError("overlay layout request handle does not match its record"))
        push!(results, layout_overlay(request, record.options, viewport))
    end
    return results
end
