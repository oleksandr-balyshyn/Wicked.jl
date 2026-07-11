module ToolkitComponents

using ..RichContent: RichLine
using ..CoreIntegration: ToolkitElementAdapter, rich_toolkit_element
using ..Virtualization: VirtualListState, VirtualListWindow, VirtualTableWindow
using ..VirtualTrees: VirtualTreeState, VirtualTreeWindow
using ..VirtualRendering: render_virtual_list,
                          render_virtual_table,
                          render_virtual_tree,
                          virtual_list_semantic_tree,
                          virtual_table_semantic_tree,
                          virtual_tree_semantic_tree
using ..FileBrowser: FileBrowserState, render_file_browser, file_browser_semantic_tree
using ..DataEntryControls: AutocompleteState,
                           ComboBoxState,
                           TagInputState,
                           NumericInputState,
                           MaskedInputState,
                           DatePickerState,
                           TimePickerState,
                           ColorPickerState
using ..DataEntryRendering: render_autocomplete,
                            render_combobox,
                            render_tags,
                            render_numeric_input,
                            render_masked_input,
                            render_date_picker,
                            render_time_picker,
                            render_color_picker,
                            autocomplete_semantic_tree,
                            data_entry_semantic_node
using ..AdvancedControls: SliderState,
                          RangeSliderState,
                          ScrollbarState,
                          BreadcrumbState,
                          CollapsibleState,
                          AccordionState,
                          PaginationState,
                          StepperState,
                          DialogState
using ..AdvancedControlRendering: render_slider_control,
                                  render_range_slider_control,
                                  render_scrollbar_control,
                                  render_breadcrumb_control,
                                  render_collapsible_control,
                                  render_accordion_control,
                                  render_pagination_control,
                                  render_stepper_control,
                                  render_dialog_control,
                                  slider_semantic_node,
                                  range_slider_semantic_node,
                                  scrollbar_semantic_node,
                                  breadcrumb_semantic_tree,
                                  collapsible_semantic_node,
                                  accordion_semantic_tree,
                                  pagination_semantic_node,
                                  stepper_semantic_tree,
                                  dialog_semantic_tree

export ToolkitComponentView,
       toolkit_component_view,
       virtual_list_component,
       virtual_table_component,
       virtual_tree_component,
       file_browser_component,
       autocomplete_component,
       combobox_component,
       tag_input_component,
       numeric_input_component,
       masked_input_component,
       date_picker_component,
       time_picker_component,
       color_picker_component,
       slider_component,
       range_slider_component,
       scrollbar_component,
       breadcrumb_component,
       collapsible_component,
       accordion_component,
       pagination_component,
       stepper_component,
       dialog_component

struct ToolkitComponentView{E,S}
    element::E
    semantics::S
end

_as_lines(line::RichLine) = RichLine[line]
_as_lines(lines::AbstractVector{RichLine}) = Vector{RichLine}(lines)

function toolkit_component_view(
    adapter::ToolkitElementAdapter,
    rendered,
    semantics;
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=false,
)
    element = rich_toolkit_element(
        adapter,
        _as_lines(rendered);
        key=key,
        id=id,
        classes=classes,
        focusable=focusable,
    )
    return ToolkitComponentView(element, semantics)
end

function virtual_list_component(
    adapter::ToolkitElementAdapter,
    window::VirtualListWindow{T,K},
    state::VirtualListState{K};
    width::Integer=80,
    semantic_id="virtual-list",
    semantic_label::AbstractString="",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
    render_options...,
) where {T,K}
    rendered = render_virtual_list(window, state; width=width, render_options...)
    semantics = virtual_list_semantic_tree(
        window,
        state;
        id=semantic_id,
        label=semantic_label,
        width=width,
    )
    return toolkit_component_view(
        adapter,
        rendered,
        semantics;
        key=key,
        id=id,
        classes=classes,
        focusable=focusable,
    )
end

function virtual_table_component(
    adapter::ToolkitElementAdapter,
    window::VirtualTableWindow;
    width::Integer=80,
    semantic_id="virtual-table",
    semantic_label::AbstractString="",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
    render_options...,
)
    rendered = render_virtual_table(window; width=width, render_options...)
    semantics = virtual_table_semantic_tree(window; id=semantic_id, label=semantic_label)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function virtual_tree_component(
    adapter::ToolkitElementAdapter,
    window::VirtualTreeWindow{T,K},
    state::VirtualTreeState{K};
    width::Integer=80,
    height::Integer=24,
    first_row::Integer=1,
    semantic_id="virtual-tree",
    semantic_label::AbstractString="",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
    render_options...,
) where {T,K}
    rendered = render_virtual_tree(
        window,
        state;
        width=width,
        height=height,
        first_row=first_row,
        render_options...,
    )
    semantics = virtual_tree_semantic_tree(
        window,
        state;
        id=semantic_id,
        label=semantic_label,
        width=width,
    )
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function file_browser_component(
    adapter::ToolkitElementAdapter,
    state::FileBrowserState;
    width::Integer=80,
    height::Integer=24,
    first_entry::Integer=1,
    semantic_id="file-browser",
    semantic_label::AbstractString="File browser",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_file_browser(state; width=width, height=height, first_entry=first_entry)
    semantics = file_browser_semantic_tree(
        state;
        id=semantic_id,
        label=semantic_label,
        width=width,
    )
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function autocomplete_component(
    adapter::ToolkitElementAdapter,
    state::AutocompleteState;
    width::Integer=40,
    semantic_id="autocomplete",
    semantic_label::AbstractString="Suggestions",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_autocomplete(state; width=width)
    semantics = autocomplete_semantic_tree(state; id=semantic_id, label=semantic_label, width=width)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function combobox_component(
    adapter::ToolkitElementAdapter,
    state::ComboBoxState;
    width::Integer=40,
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    return toolkit_component_view(
        adapter,
        render_combobox(state; width=width),
        data_entry_semantic_node(state, something(id, "combobox"));
        key=key,
        id=id,
        classes=classes,
        focusable=focusable,
    )
end

function tag_input_component(
    adapter::ToolkitElementAdapter,
    state::TagInputState;
    width::Integer=80,
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    return toolkit_component_view(
        adapter,
        render_tags(state; width=width),
        data_entry_semantic_node(state, something(id, "tag-input"));
        key=key,
        id=id,
        classes=classes,
        focusable=focusable,
    )
end

function _data_entry_component(
    adapter,
    state,
    rendered;
    semantic_id,
    semantic_label,
    key,
    id,
    classes,
    focusable,
)
    semantics = data_entry_semantic_node(state, semantic_id; label=semantic_label)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function numeric_input_component(
    adapter::ToolkitElementAdapter,
    state::NumericInputState;
    width::Integer=20,
    semantic_id="numeric-input",
    semantic_label::AbstractString="",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    return _data_entry_component(adapter, state, render_numeric_input(state; width=width); semantic_id=semantic_id, semantic_label=semantic_label, key=key, id=id, classes=classes, focusable=focusable)
end


function masked_input_component(
    adapter::ToolkitElementAdapter,
    state::MaskedInputState;
    width::Integer=40,
    semantic_id="masked-input",
    semantic_label::AbstractString="",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    return _data_entry_component(adapter, state, render_masked_input(state; width=width); semantic_id=semantic_id, semantic_label=semantic_label, key=key, id=id, classes=classes, focusable=focusable)
end

function date_picker_component(
    adapter::ToolkitElementAdapter,
    state::DatePickerState;
    width::Integer=28,
    semantic_id="date-picker",
    semantic_label::AbstractString="Date",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    return _data_entry_component(adapter, state, render_date_picker(state; width=width); semantic_id=semantic_id, semantic_label=semantic_label, key=key, id=id, classes=classes, focusable=focusable)
end

function time_picker_component(
    adapter::ToolkitElementAdapter,
    state::TimePickerState;
    width::Integer=16,
    semantic_id="time-picker",
    semantic_label::AbstractString="Time",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    return _data_entry_component(adapter, state, render_time_picker(state; width=width); semantic_id=semantic_id, semantic_label=semantic_label, key=key, id=id, classes=classes, focusable=focusable)
end

function color_picker_component(
    adapter::ToolkitElementAdapter,
    state::ColorPickerState;
    width::Integer=32,
    semantic_id="color-picker",
    semantic_label::AbstractString="Color",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    return _data_entry_component(adapter, state, render_color_picker(state; width=width); semantic_id=semantic_id, semantic_label=semantic_label, key=key, id=id, classes=classes, focusable=focusable)
end

function slider_component(
    adapter::ToolkitElementAdapter,
    state::SliderState;
    length::Integer=20,
    semantic_id="slider",
    semantic_label::AbstractString="",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_slider_control(state; length=length)
    semantics = slider_semantic_node(state, semantic_id; label=semantic_label)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function range_slider_component(
    adapter::ToolkitElementAdapter,
    state::RangeSliderState;
    length::Integer=20,
    semantic_id="range-slider",
    semantic_label::AbstractString="",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_range_slider_control(state; length=length)
    semantics = range_slider_semantic_node(state, semantic_id; label=semantic_label)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function scrollbar_component(
    adapter::ToolkitElementAdapter,
    state::ScrollbarState;
    length::Integer=20,
    semantic_id="scrollbar",
    semantic_label::AbstractString="",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_scrollbar_control(state; length=length)
    semantics = scrollbar_semantic_node(state, semantic_id; label=semantic_label)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function breadcrumb_component(
    adapter::ToolkitElementAdapter,
    state::BreadcrumbState;
    semantic_id="breadcrumbs",
    semantic_label::AbstractString="Breadcrumbs",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_breadcrumb_control(state)
    semantics = breadcrumb_semantic_tree(state; id=semantic_id, label=semantic_label)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function collapsible_component(
    adapter::ToolkitElementAdapter,
    state::CollapsibleState,
    title::AbstractString;
    semantic_id="collapsible",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_collapsible_control(state, title)
    semantics = collapsible_semantic_node(state, semantic_id; label=title)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function accordion_component(
    adapter::ToolkitElementAdapter,
    state::AccordionState,
    items;
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered_items = collect(items)
    semantics = accordion_semantic_tree(
        state,
        rendered_items;
        id=something(id, "accordion"),
    )
    return toolkit_component_view(adapter, render_accordion_control(state, rendered_items), semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function pagination_component(
    adapter::ToolkitElementAdapter,
    state::PaginationState;
    semantic_id="pagination",
    semantic_label::AbstractString="Pagination",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_pagination_control(state)
    semantics = pagination_semantic_node(state, semantic_id; label=semantic_label)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function stepper_component(
    adapter::ToolkitElementAdapter,
    state::StepperState;
    semantic_id="stepper",
    semantic_label::AbstractString="Progress",
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=false,
)
    rendered = render_stepper_control(state)
    semantics = stepper_semantic_tree(state; id=semantic_id, label=semantic_label)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

function dialog_component(
    adapter::ToolkitElementAdapter,
    state::DialogState;
    title::AbstractString="",
    message::AbstractString="",
    semantic_id="dialog",
    semantic_label::AbstractString=title,
    key=nothing,
    id=nothing,
    classes=String[],
    focusable::Bool=true,
)
    rendered = render_dialog_control(state; title=title, message=message)
    semantics = dialog_semantic_tree(state; id=semantic_id, label=semantic_label)
    return toolkit_component_view(adapter, rendered, semantics; key=key, id=id, classes=classes, focusable=focusable)
end

end
