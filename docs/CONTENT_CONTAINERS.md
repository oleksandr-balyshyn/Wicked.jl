# Content Containers

`ContentSwitcher` and `TabbedContent` coordinate keyed application content while
leaving rendering to ordinary Wicked widgets and Toolkit components. They provide
the retained state needed for page selection, lazy construction, tab focus,
dynamic page changes, and state-preserving navigation.

## Define pages

Use `ContentPage` for content that already exists and `lazy_content_page` for
expensive content that should be created on first use.

```julia
pages = [
    ContentPage(:overview, "Overview", overview_component),
    lazy_content_page(
        :metrics,
        "Metrics",
        () -> build_metrics_component();
        closable=true,
    ),
]
```

Page keys have one concrete type per container. Titles are presentation labels;
keys provide stable identity for reconciliation, cache ownership, and developer
commands.

## Switch content

```julia
switcher = ContentSwitcher(pages; active=:overview)

switch_content!(switcher, :metrics)
component = resolve_active_content!(switcher)
```

Lazy factories execute outside the container lock and at most once concurrently
for a page version. Different pages may load concurrently. Replacing, disabling,
or invalidating a page advances its version, so an obsolete in-flight result is
discarded rather than cached.

Pages retain resolved content by default. Set `keep_alive=false` to evict content
when navigation leaves that page. Call `invalidate_page_content!` when external
inputs require a lazy page to be rebuilt.

## Modify pages

The switcher supports dynamic application workflows:

```julia
add_content_page!(switcher, settings_page; activate=true)
replace_content_page!(switcher, refreshed_settings_page)
reorder_content_page!(switcher, :settings, 1)
remove_content_page!(switcher, :settings)
```

`close_content_page!` differs from administrative removal: it returns `false` for
a page whose `closable` policy is disabled. Removing the active page selects the
nearest enabled page, preferring the page that followed it.

## Tabbed content

`TabbedContent` adds tab-strip focus and activation policy over a switcher.

```julia
tabs = TabbedContent(
    pages;
    placement=TabsAbove,
    activation=ManualTabActivation,
)

move_tab_focus!(tabs, 1)
activate_focused_tab!(tabs)

for item in tab_items(tabs)
    # Render item.title using item.active, item.focused, and item.disabled.
end

content = resolve_tab_content!(tabs)
```

Automatic activation selects a page as tab focus moves. Manual activation keeps
focus and selection independent until `activate_focused_tab!` is called, matching
accessible tab behavior for expensive or stateful views.

Tab operations use a consistent container-then-switcher lock order. Selection,
focus movement, dynamic changes, and rendering snapshots therefore observe one
page state even when application tasks update the underlying switcher concurrently.
If external code disables or removes a manually focused page, the next tab query
normalizes focus to the active page. Without an active page, it prefers the next
enabled page, then the previous one; when no prior position exists, it chooses the
first enabled page.

`TabItem` is an immutable rendering snapshot. A Toolkit adapter can map these
snapshots to the existing `Tabs` widget while mounting only the content returned by
`resolve_tab_content!`.

## Buffer rendering

`TabbedContentView` provides that adapter for the core buffer API:

```julia
view = TabbedContentView(
    tab_extent=1,
    render_content=(buffer, content, area) -> render!(buffer, content, area),
)

render!(buffer, view, area, tabs)
handle!(tabs, view, key_event)
handle!(tabs, view, mouse_event, area)
```

The view supports top, bottom, left, and right tab placement. Horizontal strips
reuse the existing `Tabs` widget; vertical strips use the same active, focused, and
disabled style policy. Manual activation renders focus independently from the active
page until Enter or Space is handled.

Omit `tab_extent` for an automatic one-row horizontal strip or 20-column vertical
strip. Explicit non-negative values are used exactly; zero hides the strip without
changing content state.

`tabbed_content_regions` exposes deterministic tab-strip and content rectangles for
custom renderers, semantics, mouse hit testing, and snapshot assertions. Lazy page
resolution happens before the content renderer is invoked; applications should use
a lightweight placeholder page when construction requires asynchronous work.

`tab_hit_regions` returns clipped, Unicode-width-aware bounds for visible tabs.
Left-button release selects an enabled tab. Middle-button release closes it only
when the page is marked `closable`; this provides a pointer closure gesture without
reserving permanent terminal columns for close icons.

## Toolkit and accessibility

```julia
component = tabbed_content_component(
    toolkit_adapter,
    tabs;
    width=80,
    render_content=(content, width) -> render_panel_lines(content, width),
    semantic_id="workspace-tabs",
    panel_children=active_panel_semantics,
)
```

`render_tab_strip_control` emits a width-bounded `RichLine` with separate roles for
active, focused, disabled, ordinary tabs, and dividers. The component appends the
active page lines returned by `render_content` and passes the result through the
existing Toolkit rich-element adapter.

`tabbed_content_semantic_tree` exposes a `TabListRole` containing focusable
`TabRole` children with selected state and select, activate, and optional dismiss
actions. The mounted page is a labeled `GroupRole`; applications may attach the
active component's semantic nodes through `panel_children`.

Use `register_tabbed_content_view_semantic_handlers!` with the same semantic id
when automation should drive that tree. The handler supports root/list focus,
increment, decrement, and activation, plus per-tab focus, select, activate, and
dismiss actions against the retained `TabbedContent` model.

Both buffer and Toolkit adapters build one `TabbedContentSnapshot` before rendering.
The snapshot contains tab items, active key, placement, activation policy, resolved
page version, and content.
If selection or page replacement races with lazy resolution, Wicked retries with a
bounded limit rather than mixing one page's content with another page's tab or
semantic state. `resolve_page_content_snapshot!` exposes the same versioned primitive
for custom integrations.

Page disappearance during resolution raises `ContentPageUnavailable`, which the
tabbed snapshot retry loop handles. Exceptions raised by a page factory, including
`KeyError`, retain their original type and propagate to the application.

Use `tabbed_content_state_snapshot` when layout, hit testing, menus, or semantics
need tab items, active key, placement, and activation policy without resolving page
content. `set_tab_placement!` and `set_tab_activation!` update those fields through
the same lock used by snapshots. Switching to automatic activation immediately
selects the currently focused enabled page.
