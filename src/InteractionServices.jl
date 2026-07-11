module InteractionServices

import ..Widgets as WickedWidgets
using ..Clipboard: ClipboardContent,
                   ClipboardService,
                   copy_to_clipboard!,
                   paste_from_clipboard,
                   clipboard_text
using ..DragDrop: DragEffect,
                  CopyDragEffect,
                  DragPoint,
                  DragPayload,
                  DropTarget,
                  DropResult,
                  DragEvent,
                  DragDropManager,
                  register_drop_target!,
                  unregister_drop_target!,
                  update_drop_target!,
                  begin_drag_candidate!,
                  update_drag!,
                  drop_drag!,
                  cancel_drag!,
                  take_drag_events!
using ..NavigationControls: ComponentRect

export TextEditAdapter,
       ClipboardEditResult,
       copy_edit_selection!,
       cut_edit_selection!,
       paste_edit_selection!,
       ToolkitDropBinding,
       ToolkitDragDispatch,
       ToolkitDragRouter,
       register_toolkit_drop_target!,
       unregister_toolkit_drop_target!,
       sync_toolkit_drop_target!,
       begin_toolkit_drag!,
       update_toolkit_drag!,
       drop_toolkit_drag!,
       cancel_toolkit_drag!,
       route_toolkit_drag_events!,
       drag_point_from_event

function _widget_method(names, arguments...)
    attempts = String[]
    for name in names
        push!(attempts, "Widgets.$name")
        isdefined(WickedWidgets, name) || continue
        method = getfield(WickedWidgets, name)
        applicable(method, arguments...) || continue
        return method(arguments...)
    end
    throw(ArgumentError("no compatible editing method found; tried $(join(attempts, ", "))"))
end

_default_selection(editor) = _widget_method((:selected_text, :selection_text, :get_selected_text), editor)
_default_delete(editor) = _widget_method((:delete_selection!, :delete_selected!, :cut_selection!), editor)

function _default_insert(editor, text::String)
    return _widget_method(
        (:replace_selection!, :insert_text!, :insert!),
        editor,
        text,
    )
end

_default_editable(editor) = hasproperty(editor, :readonly) ? !Bool(getproperty(editor, :readonly)) : true

struct TextEditAdapter{S,D,I,E}
    selection::S
    delete_selection!::D
    insert_text!::I
    editable::E
end

function TextEditAdapter(;
    selection=_default_selection,
    delete_callback=_default_delete,
    insert_callback=_default_insert,
    editable=_default_editable,
)
    return TextEditAdapter{
        typeof(selection),
        typeof(delete_callback),
        typeof(insert_callback),
        typeof(editable),
    }(
        selection,
        delete_callback,
        insert_callback,
        editable,
    )
end

struct ClipboardEditResult
    operation::Symbol
    changed::Bool
    bytes::Int
end

function copy_edit_selection!(
    service::ClipboardService,
    adapter::TextEditAdapter,
    editor;
    allow_copy::Bool=true,
    allow_empty::Bool=false,
    sensitive::Bool=false,
)
    allow_copy || return ClipboardEditResult(:copy, false, 0)
    text = String(adapter.selection(editor))
    isempty(text) && !allow_empty && return ClipboardEditResult(:copy, false, 0)
    content = ClipboardContent(text; sensitive=sensitive)
    copy_to_clipboard!(service, content)
    return ClipboardEditResult(:copy, false, length(content.data))
end

function cut_edit_selection!(
    service::ClipboardService,
    adapter::TextEditAdapter,
    editor;
    allow_cut::Bool=true,
    sensitive::Bool=false,
)
    allow_cut || return ClipboardEditResult(:cut, false, 0)
    Bool(adapter.editable(editor)) || return ClipboardEditResult(:cut, false, 0)
    text = String(adapter.selection(editor))
    isempty(text) && return ClipboardEditResult(:cut, false, 0)
    content = ClipboardContent(text; sensitive=sensitive)
    copy_to_clipboard!(service, content)
    adapter.delete_selection!(editor)
    return ClipboardEditResult(:cut, true, length(content.data))
end

function paste_edit_selection!(
    service::ClipboardService,
    adapter::TextEditAdapter,
    editor;
    allow_paste::Bool=true,
    normalize_newlines::Bool=true,
)
    allow_paste || return ClipboardEditResult(:paste, false, 0)
    Bool(adapter.editable(editor)) || return ClipboardEditResult(:paste, false, 0)
    content = paste_from_clipboard(service)
    content === nothing && return ClipboardEditResult(:paste, false, 0)
    text = clipboard_text(content)
    normalize_newlines && (text = replace(text, "\r\n" => "\n", '\r' => '\n'))
    isempty(text) && return ClipboardEditResult(:paste, false, 0)
    adapter.insert_text!(editor, text)
    return ClipboardEditResult(:paste, true, ncodeunits(text))
end

struct ToolkitDropBinding{H}
    element_id::String
    target_id::String
    handler::H
end

struct ToolkitDragDispatch
    messages::Vector{Any}
    errors::Vector{Any}
end

mutable struct ToolkitDragRouter{M}
    manager::DragDropManager
    bindings::Dict{String,ToolkitDropBinding}
    message_mapper::M
    mutex::ReentrantLock
end

function ToolkitDragRouter(
    manager::DragDropManager=DragDropManager();
    message_mapper=identity,
)
    return ToolkitDragRouter{typeof(message_mapper)}(
        manager,
        Dict{String,ToolkitDropBinding}(),
        message_mapper,
        ReentrantLock(),
    )
end

function register_toolkit_drop_target!(
    router::ToolkitDragRouter,
    element_id,
    rect::ComponentRect,
    handler;
    target_id=string(element_id),
    accepted_mime_prefixes=("",),
    accepted_effects=(CopyDragEffect,),
    preferred_effect::DragEffect=CopyDragEffect,
    priority::Integer=0,
    enabled::Bool=true,
)
    identifier = string(target_id)
    target = DropTarget(
        identifier,
        rect;
        accepted_mime_prefixes=accepted_mime_prefixes,
        accepted_effects=accepted_effects,
        preferred_effect=preferred_effect,
        priority=priority,
        enabled=enabled,
    )
    lock(router.mutex) do
        haskey(router.bindings, identifier) &&
            throw(ArgumentError("duplicate Toolkit drop target: $identifier"))
        register_drop_target!(router.manager, target)
        router.bindings[identifier] = ToolkitDropBinding(
            string(element_id),
            identifier,
            handler,
        )
    end
    return router
end

function unregister_toolkit_drop_target!(router::ToolkitDragRouter, target_id)
    identifier = string(target_id)
    lock(router.mutex) do
        unregister_drop_target!(router.manager, identifier)
        pop!(router.bindings, identifier, nothing)
    end
    return router
end

function sync_toolkit_drop_target!(
    router::ToolkitDragRouter,
    target_id,
    rect::ComponentRect;
    enabled=nothing,
)
    update_drop_target!(router.manager, target_id, rect; enabled=enabled)
    return router
end

function begin_toolkit_drag!(
    router::ToolkitDragRouter,
    element_id,
    payload::DragPayload,
    point::DragPoint,
)
    begin_drag_candidate!(router.manager, element_id, payload, point)
    return router
end

update_toolkit_drag!(router::ToolkitDragRouter, point::DragPoint) =
    update_drag!(router.manager, point)

function drop_toolkit_drag!(router::ToolkitDragRouter, point::DragPoint)
    result = drop_drag!(router.manager, point)
    result.accepted || return result, nothing
    binding = lock(router.mutex) do
        get(router.bindings, result.target_id, nothing)
    end
    binding === nothing && return result, nothing
    applicable(binding.handler, result) ||
        throw(ArgumentError("Toolkit drop handler is not applicable to DropResult"))
    return result, binding.handler(result)
end

cancel_toolkit_drag!(router::ToolkitDragRouter) = cancel_drag!(router.manager)

function route_toolkit_drag_events!(router::ToolkitDragRouter)
    events = take_drag_events!(router.manager)
    messages = Any[]
    errors = Any[]
    for event in events
        try
            applicable(router.message_mapper, event) ||
                throw(ArgumentError("Toolkit drag message mapper is not applicable to DragEvent"))
            message = router.message_mapper(event)
            message === nothing || push!(messages, message)
        catch error
            push!(errors, (event, error, catch_backtrace()))
        end
    end
    return ToolkitDragDispatch(messages, errors)
end

function drag_point_from_event(
    event;
    coordinate_base::Integer=1,
    row_offset::Integer=0,
    column_offset::Integer=0,
)
    coordinate_base in (0, 1) || throw(ArgumentError("pointer coordinate base must be 0 or 1"))
    position = hasproperty(event, :position) ? getproperty(event, :position) : nothing
    row = hasproperty(event, :row) ? getproperty(event, :row) :
          hasproperty(event, :y) ? getproperty(event, :y) :
          position !== nothing && hasproperty(position, :row) ? getproperty(position, :row) :
          position !== nothing && hasproperty(position, :y) ? getproperty(position, :y) : nothing
    column = hasproperty(event, :column) ? getproperty(event, :column) :
             hasproperty(event, :x) ? getproperty(event, :x) :
             position !== nothing && hasproperty(position, :column) ? getproperty(position, :column) :
             position !== nothing && hasproperty(position, :x) ? getproperty(position, :x) : nothing
    row === nothing && throw(ArgumentError("pointer event has no row/y coordinate"))
    column === nothing && throw(ArgumentError("pointer event has no column/x coordinate"))
    adjustment = coordinate_base == 0 ? 1 : 0
    return DragPoint(
        Int(row) + adjustment + Int(row_offset),
        Int(column) + adjustment + Int(column_offset),
    )
end

end
