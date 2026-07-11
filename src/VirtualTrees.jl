module VirtualTrees

export AbstractTreeDataSource,
       tree_roots,
       tree_children,
       tree_item_key,
       tree_has_children,
       CallbackTreeDataSource,
       VirtualTreeState,
       VirtualTreeRow,
       VirtualTreeDiagnostic,
       VirtualTreeWindow,
       flatten_virtual_tree,
       expand_virtual_tree!,
       collapse_virtual_tree!,
       toggle_virtual_tree!,
       move_virtual_tree_cursor!,
       select_virtual_tree!,
       clear_virtual_tree_selection!

abstract type AbstractTreeDataSource{T,K} end

tree_roots(::AbstractTreeDataSource) = throw(MethodError(tree_roots, ()))
tree_children(::AbstractTreeDataSource, item) = throw(MethodError(tree_children, (item,)))
tree_item_key(::AbstractTreeDataSource, item) = item
tree_has_children(source::AbstractTreeDataSource, item) = !isempty(tree_children(source, item))

struct CallbackTreeDataSource{T,K,R,C,I,H} <: AbstractTreeDataSource{T,K}
    roots_function::R
    children_function::C
    key_function::I
    has_children_function::H
end

function CallbackTreeDataSource{T,K}(;
    roots,
    children,
    key=identity,
    has_children=item -> !isempty(children(item)),
) where {T,K}
    return CallbackTreeDataSource{T,K,typeof(roots),typeof(children),typeof(key),typeof(has_children)}(
        roots,
        children,
        key,
        has_children,
    )
end

tree_roots(source::CallbackTreeDataSource{T}) where {T} = Vector{T}(source.roots_function())
tree_children(source::CallbackTreeDataSource{T}, item) where {T} = Vector{T}(source.children_function(item))
tree_item_key(source::CallbackTreeDataSource, item) = source.key_function(item)
tree_has_children(source::CallbackTreeDataSource, item) = Bool(source.has_children_function(item))

mutable struct VirtualTreeState{K}
    expanded::Set{K}
    selected::Set{K}
    cursor::Union{Nothing,K}
    multiple::Bool
end

VirtualTreeState{K}(; multiple::Bool=false) where {K} =
    VirtualTreeState{K}(Set{K}(), Set{K}(), nothing, multiple)

struct VirtualTreeRow{T,K}
    item::T
    key::K
    depth::Int
    parent::Union{Nothing,K}
    expanded::Bool
    expandable::Bool
end

struct VirtualTreeDiagnostic{K}
    severity::Symbol
    key::K
    message::String
end

struct VirtualTreeWindow{T,K}
    rows::Vector{VirtualTreeRow{T,K}}
    diagnostics::Vector{VirtualTreeDiagnostic{K}}
    truncated::Bool
end

function flatten_virtual_tree(
    source::AbstractTreeDataSource{T,K},
    state::VirtualTreeState{K};
    max_rows::Integer=100_000,
    max_depth::Integer=256,
) where {T,K}
    max_rows > 0 || throw(ArgumentError("maximum tree rows must be positive"))
    max_depth >= 0 || throw(ArgumentError("maximum tree depth cannot be negative"))
    rows = VirtualTreeRow{T,K}[]
    diagnostics = VirtualTreeDiagnostic{K}[]
    truncated = false

    function visit(item::T, depth::Int, parent::Union{Nothing,K}, ancestors::Set{K})
        if length(rows) >= max_rows
            truncated = true
            return
        end
        key = convert(K, tree_item_key(source, item))
        if key in ancestors
            push!(diagnostics, VirtualTreeDiagnostic{K}(:error, key, "cycle detected in tree data"))
            return
        end
        expandable = tree_has_children(source, item)
        expanded = expandable && key in state.expanded
        push!(rows, VirtualTreeRow{T,K}(item, key, depth, parent, expanded, expandable))
        expanded || return
        if depth >= max_depth
            push!(diagnostics, VirtualTreeDiagnostic{K}(:warning, key, "maximum tree depth reached"))
            return
        end
        next_ancestors = copy(ancestors)
        push!(next_ancestors, key)
        for child in tree_children(source, item)
            visit(child, depth + 1, key, next_ancestors)
            truncated && return
        end
    end

    for root in tree_roots(source)
        visit(root, 0, nothing, Set{K}())
        truncated && break
    end
    return VirtualTreeWindow{T,K}(rows, diagnostics, truncated)
end

function expand_virtual_tree!(state::VirtualTreeState{K}, key::K) where {K}
    push!(state.expanded, key)
    return state
end

function collapse_virtual_tree!(state::VirtualTreeState{K}, key::K) where {K}
    delete!(state.expanded, key)
    return state
end

function toggle_virtual_tree!(state::VirtualTreeState{K}, key::K) where {K}
    key in state.expanded ? delete!(state.expanded, key) : push!(state.expanded, key)
    return state
end

function move_virtual_tree_cursor!(
    state::VirtualTreeState{K},
    window::VirtualTreeWindow{T,K},
    delta::Integer,
) where {T,K}
    isempty(window.rows) && (state.cursor = nothing; return state)
    current = state.cursor === nothing ? 1 : something(findfirst(row -> row.key == state.cursor, window.rows), 1)
    index = Int(clamp(big(current) + big(delta), big(1), big(length(window.rows))))
    state.cursor = window.rows[index].key
    return state
end

function select_virtual_tree!(state::VirtualTreeState{K}, key::K) where {K}
    state.multiple || empty!(state.selected)
    push!(state.selected, key)
    state.cursor = key
    return state
end

clear_virtual_tree_selection!(state::VirtualTreeState) = (empty!(state.selected); state)

end
