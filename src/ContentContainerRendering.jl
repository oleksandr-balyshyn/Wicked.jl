using .Core: BOLD,
             Buffer,
             DIM,
             REVERSED,
             Rect,
             Style,
             contains,
             intersection,
             text_width
import .Core: render!
using .Events: KeyEvent,
               LeftMouseButton,
               MiddleMouseButton,
               MouseEvent,
               MouseRelease
using .Widgets: Label, Tab, Tabs, TabsState
import .Widgets: handle!


struct TabbedContentRegions
    tabs::Rect
    content::Rect
end

struct TabHitRegion{K}
    key::K
    bounds::Rect
    disabled::Bool
    closable::Bool
end

function tabbed_content_regions(
    area::Rect,
    placement::TabPlacement;
    tab_extent::Integer=placement in (TabsAbove, TabsBelow) ? 1 : 20,
)
    tab_extent >= 0 || throw(ArgumentError("tab extent must be non-negative"))
    if placement in (TabsAbove, TabsBelow)
        extent = min(Int(tab_extent), area.height)
        content_height = area.height - extent
        if placement == TabsAbove
            return TabbedContentRegions(
                Rect(area.row, area.column, extent, area.width),
                Rect(area.row + extent, area.column, content_height, area.width),
            )
        end
        return TabbedContentRegions(
            Rect(area.row + content_height, area.column, extent, area.width),
            Rect(area.row, area.column, content_height, area.width),
        )
    end
    extent = min(Int(tab_extent), area.width)
    content_width = area.width - extent
    if placement == TabsLeft
        return TabbedContentRegions(
            Rect(area.row, area.column, area.height, extent),
            Rect(area.row, area.column + extent, area.height, content_width),
        )
    end
    return TabbedContentRegions(
        Rect(area.row, area.column + content_width, area.height, extent),
        Rect(area.row, area.column, area.height, content_width),
    )
end

function _default_tabbed_content_renderer(buffer, content, area)
    return render!(buffer, content, area)
end

"""Buffer renderer and keyboard policy for a retained `TabbedContent` model."""
struct TabbedContentView{F}
    render_content::F
    divider::String
    tab_extent::Union{Nothing,Int}
    style::Style
    active_style::Style
    focused_style::Style
    disabled_style::Style
end

function TabbedContentView(;
    render_content=_default_tabbed_content_renderer,
    divider::AbstractString=" │ ",
    tab_extent::Union{Nothing,Integer}=nothing,
    style::Style=Style(),
    active_style::Style=Style(modifiers=REVERSED | BOLD),
    focused_style::Style=Style(modifiers=BOLD),
    disabled_style::Style=Style(modifiers=DIM),
)
    tab_extent === nothing || tab_extent >= 0 ||
        throw(ArgumentError("tab extent must be non-negative"))
    return TabbedContentView(
        render_content,
        String(divider),
        tab_extent === nothing ? nothing : Int(tab_extent),
        style,
        active_style,
        focused_style,
        disabled_style,
    )
end

function _tab_item_style(view::TabbedContentView, item::TabItem)
    item.disabled && return view.disabled_style
    item.active && return view.active_style
    item.focused && return view.focused_style
    return view.style
end

function _render_horizontal_tabs!(
    buffer::Buffer,
    view::TabbedContentView,
    area::Rect,
    items,
)
    isempty(area) && return buffer
    tabs = Tab[
        Tab(item.key, item.title; style=item.focused && !item.active ? view.focused_style :
            item.disabled ? view.disabled_style : view.style)
        for item in items
    ]
    selected = something(findfirst(item -> item.active, items), 1)
    render!(
        buffer,
        Tabs(
            tabs;
            divider=view.divider,
            style=view.style,
            selected_style=view.active_style,
        ),
        area,
        TabsState(selected),
    )
end

function _render_vertical_tabs!(
    buffer::Buffer,
    view::TabbedContentView,
    area::Rect,
    items,
)
    isempty(area) && return buffer
    visible = min(length(items), area.height)
    for index in 1:visible
        item = items[index]
        render!(
            buffer,
            Label(item.title; style=_tab_item_style(view, item)),
            Rect(area.row + index - 1, area.column, 1, area.width),
        )
    end
    return buffer
end

function render!(
    buffer::Buffer,
    view::TabbedContentView,
    area::Rect,
    tabs::TabbedContent,
)
    active = intersection(buffer.area, area)
    isempty(active) && return buffer
    snapshot = tabbed_content_snapshot!(tabs)
    placement = snapshot.placement
    default_extent = placement in (TabsAbove, TabsBelow) ? 1 : 20
    extent = something(view.tab_extent, default_extent)
    regions = tabbed_content_regions(active, placement; tab_extent=extent)
    items = snapshot.items
    if placement in (TabsAbove, TabsBelow)
        _render_horizontal_tabs!(buffer, view, regions.tabs, items)
    else
        _render_vertical_tabs!(buffer, view, regions.tabs, items)
    end
    isempty(regions.content) && return buffer
    content = snapshot.content
    content === nothing && return buffer
    applicable(view.render_content, buffer, content, regions.content) ||
        throw(ArgumentError("tabbed content renderer must accept buffer, content, and area"))
    view.render_content(buffer, content, regions.content)
    return buffer
end

function tab_hit_regions(
    tabs::TabbedContent{K},
    view::TabbedContentView,
    area::Rect,
) where {K}
    snapshot = tabbed_content_state_snapshot(tabs)
    placement = snapshot.placement
    default_extent = placement in (TabsAbove, TabsBelow) ? 1 : 20
    extent = something(view.tab_extent, default_extent)
    strip = tabbed_content_regions(area, placement; tab_extent=extent).tabs
    isempty(strip) && return TabHitRegion{K}[]
    items = snapshot.items
    regions = TabHitRegion{K}[]
    if placement in (TabsAbove, TabsBelow)
        column = strip.column
        limit = strip.column + strip.width
        divider_width = text_width(view.divider)
        for (index, item) in enumerate(items)
            index > 1 && (column += divider_width)
            column >= limit && break
            width = min(text_width(item.title), limit - column)
            width > 0 && push!(
                regions,
                TabHitRegion(
                    item.key,
                    Rect(strip.row, column, 1, width),
                    item.disabled,
                    item.closable,
                ),
            )
            column += width
        end
    else
        visible = min(length(items), strip.height)
        for index in 1:visible
            item = items[index]
            push!(
                regions,
                TabHitRegion(
                    item.key,
                    Rect(strip.row + index - 1, strip.column, 1, strip.width),
                    item.disabled,
                    item.closable,
                ),
            )
        end
    end
    return regions
end

function handle!(tabs::TabbedContent, view::TabbedContentView, event::KeyEvent)
    key = event.key.code
    snapshot = tabbed_content_state_snapshot(tabs)
    horizontal = snapshot.placement in (TabsAbove, TabsBelow)
    if key == (horizontal ? :left : :up)
        return move_tab_focus!(tabs, -1)
    elseif key == (horizontal ? :right : :down)
        return move_tab_focus!(tabs, 1)
    elseif key == :home
        items = [item for item in tab_items(tabs) if !item.disabled]
        isempty(items) && return false
        return focus_tab!(tabs, first(items).key)
    elseif key == :end
        items = [item for item in tab_items(tabs) if !item.disabled]
        isempty(items) && return false
        return focus_tab!(tabs, last(items).key)
    elseif key in (:enter, :space)
        return activate_focused_tab!(tabs)
    elseif key == :delete
        focused = focused_tab(tabs)
        focused === nothing && return false
        return close_tab!(tabs, focused)
    end
    return false
end

function handle!(
    tabs::TabbedContent,
    view::TabbedContentView,
    event::MouseEvent,
    area::Rect,
)
    event.action == MouseRelease || return false
    event.button in (LeftMouseButton, MiddleMouseButton) || return false
    regions = tab_hit_regions(tabs, view, area)
    region = findfirst(
        candidate -> contains(candidate.bounds, event.position),
        regions,
    )
    region === nothing && return false
    hit = regions[region]
    hit.disabled && return false
    try
        if event.button == MiddleMouseButton
            hit.closable || return false
            return close_tab!(tabs, hit.key)
        end
        return select_tab!(tabs, hit.key)
    catch error
        error isa KeyError && return false
        rethrow()
    end
end
