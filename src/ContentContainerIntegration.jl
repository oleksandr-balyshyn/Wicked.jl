
function _clip_tab_control_text(value::AbstractString, width::Int)
    width <= 0 && return ""
    output = IOBuffer()
    used = 0
    for grapheme in Unicode.graphemes(value)
        cells = grapheme_width(DEFAULT_WIDTH_POLICY, grapheme)
        used + cells > width && break
        print(output, grapheme)
        used += cells
    end
    return String(take!(output))
end

function _tab_control_role(item::TabItem)
    item.disabled && return :tab_disabled
    item.active && return :tab_active
    item.focused && return :tab_focused
    return :tab
end

function _render_tab_strip_items(
    items;
    width::Integer=80,
    divider::AbstractString=" │ ",
)
    resolved_width = Int(width)
    resolved_width >= 0 || throw(ArgumentError("tab control width must be non-negative"))
    remaining = resolved_width
    spans = RichContent.RichSpan[]
    for (index, item) in enumerate(items)
        if index > 1
            separator = _clip_tab_control_text(divider, remaining)
            isempty(separator) && break
            push!(spans, RichContent.RichSpan(separator, :tab_divider, nothing))
            remaining -= text_width(separator)
        end
        remaining <= 0 && break
        label = _clip_tab_control_text(item.title, remaining)
        isempty(label) && continue
        push!(spans, RichContent.RichSpan(label, _tab_control_role(item), nothing))
        remaining -= text_width(label)
    end
    return RichContent.RichLine(spans, :tab_list, nothing)
end

render_tab_strip_control(tabs::TabbedContent; kwargs...) =
    render_tab_strip_control(tabbed_content_state_snapshot(tabs); kwargs...)

render_tab_strip_control(snapshot::TabbedContentStateSnapshot; kwargs...) =
    _render_tab_strip_items(snapshot.items; kwargs...)

render_tab_strip_control(snapshot::TabbedContentSnapshot; kwargs...) =
    _render_tab_strip_items(snapshot.items; kwargs...)

function tabbed_content_semantic_tree(
    source::Union{TabbedContent,TabbedContentStateSnapshot,TabbedContentSnapshot};
    id="tabbed-content",
    label::AbstractString="Tabs",
    bounds::Union{Nothing,SemanticRect}=nothing,
    panel_children=SemanticNode[],
)
    identifier = string(id)
    snapshot = source isa TabbedContent ? tabbed_content_state_snapshot(source) : source
    items = snapshot.items
    placement = snapshot.placement
    activation = snapshot.activation
    tab_nodes = SemanticNode[]
    for (index, item) in enumerate(items)
        actions = item.disabled ? SemanticAction[] :
            SemanticAction[SelectSemanticAction, ActivateSemanticAction]
        item.closable && !item.disabled && push!(actions, DismissSemanticAction)
        push!(
            tab_nodes,
            SemanticNode(
                "$(identifier)/tab/$index",
                TabRole;
                label=item.title,
                state=SemanticState(
                    enabled=!item.disabled,
                    focusable=!item.disabled,
                    focused=item.focused,
                    selected=item.active,
                ),
                actions,
                metadata=Dict(:key => item.key, :closable => item.closable),
            ),
        )
    end
    tab_list = SemanticNode(
        "$(identifier)/list",
        TabListRole;
        label,
        children=tab_nodes,
    )
    active = findfirst(item -> item.active, items)
    panel_label = active === nothing ? "" : items[active].title
    panel_key = active === nothing ? nothing : items[active].key
    panel = SemanticNode(
        "$(identifier)/panel",
        GroupRole;
        label=panel_label,
        state=SemanticState(hidden=active === nothing),
        children=SemanticNode[child for child in panel_children],
        metadata=Dict(:key => panel_key),
    )
    return SemanticTree(
        SemanticNode(
            identifier,
            GroupRole;
            label,
            bounds,
            children=SemanticNode[tab_list, panel],
            metadata=Dict(:placement => placement, :activation => activation),
        ),
    )
end

function _default_tabbed_toolkit_content(content, width::Int)
    content isa RichContent.RichLine && return RichContent.RichLine[content]
    content isa AbstractVector{<:RichContent.RichLine} &&
        return RichContent.RichLine[line for line in content]
    lines = split(string(content), '\n'; keepempty=true)
    return RichContent.RichLine[
        RichContent.RichLine(
            RichContent.RichSpan[
                RichContent.RichSpan(_clip_tab_control_text(line, width), :tab_panel, nothing),
            ],
            :tab_panel,
            nothing,
        ) for line in lines
    ]
end

function tabbed_content_component(
    adapter::CoreIntegration.ToolkitElementAdapter,
    tabs::TabbedContent;
    width::Integer=80,
    divider::AbstractString=" │ ",
    render_content=_default_tabbed_toolkit_content,
    panel_children=SemanticNode[],
    semantic_id="tabbed-content",
    semantic_label::AbstractString="Tabs",
    semantic_bounds::Union{Nothing,SemanticRect}=nothing,
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    resolved_width = Int(width)
    resolved_width >= 0 || throw(ArgumentError("tabbed component width must be non-negative"))
    snapshot = tabbed_content_snapshot!(tabs)
    rendered = RichContent.RichLine[
        render_tab_strip_control(snapshot; width=resolved_width, divider),
    ]
    content = snapshot.content
    if content !== nothing
        applicable(render_content, content, resolved_width) ||
            throw(ArgumentError("tabbed Toolkit content renderer must accept content and width"))
        lines = render_content(content, resolved_width)
        lines isa AbstractVector{<:RichContent.RichLine} ||
            throw(ArgumentError("tabbed Toolkit content renderer must return RichLine values"))
        append!(rendered, lines)
    end
    semantics = tabbed_content_semantic_tree(
        snapshot;
        id=semantic_id,
        label=semantic_label,
        bounds=semantic_bounds,
        panel_children,
    )
    return ToolkitComponents.toolkit_component_view(
        adapter,
        rendered,
        semantics;
        key,
        id,
        classes,
        focusable,
    )
end
