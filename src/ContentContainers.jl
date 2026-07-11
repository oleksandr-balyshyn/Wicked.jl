
"""Descriptor for eager or lazily constructed keyed content."""
struct ContentPage{K}
    key::K
    title::String
    provider::Any
    lazy::Bool
    disabled::Bool
    closable::Bool
    keep_alive::Bool
    metadata::Any

    function ContentPage{K}(
        key::K,
        title::String,
        provider,
        lazy::Bool,
        disabled::Bool,
        closable::Bool,
        keep_alive::Bool,
        metadata,
    ) where {K}
        lazy && !applicable(provider) &&
            throw(ArgumentError("a lazy content provider must be callable without arguments"))
        return new{K}(
            key,
            title,
            provider,
            lazy,
            disabled,
            closable,
            keep_alive,
            metadata,
        )
    end
end

function ContentPage(
    key::K,
    title::AbstractString,
    content;
    disabled::Bool=false,
    closable::Bool=false,
    keep_alive::Bool=true,
    metadata=nothing,
) where {K}
    return ContentPage{K}(
        key,
        String(title),
        content,
        false,
        disabled,
        closable,
        keep_alive,
        metadata,
    )
end

function lazy_content_page(
    key::K,
    title::AbstractString,
    factory;
    disabled::Bool=false,
    closable::Bool=false,
    keep_alive::Bool=true,
    metadata=nothing,
) where {K}
    return ContentPage{K}(
        key,
        String(title),
        factory,
        true,
        disabled,
        closable,
        keep_alive,
        metadata,
    )
end

mutable struct ContentSwitcher{K}
    pages::Vector{ContentPage{K}}
    active::Union{Nothing,K}
    versions::Dict{K,UInt64}
    cache::Dict{K,Tuple{UInt64,Any}}
    page_locks::Dict{K,ReentrantLock}
    generation::UInt64
    mutex::ReentrantLock
end

function _validate_content_pages(pages)
    keys = Set{Any}()
    for page in pages
        page.key in keys && throw(ArgumentError("duplicate content page key: $(page.key)"))
        push!(keys, page.key)
    end
    return nothing
end

function ContentSwitcher(
    pages::AbstractVector{<:ContentPage{K}};
    active=nothing,
) where {K}
    resolved = ContentPage{K}[page for page in pages]
    _validate_content_pages(resolved)
    selected = if active === nothing
        index = findfirst(page -> !page.disabled, resolved)
        index === nothing ? nothing : resolved[index].key
    else
        key = convert(K, active)
        index = findfirst(page -> page.key == key, resolved)
        index === nothing && throw(KeyError(key))
        resolved[index].disabled && throw(ArgumentError("the active content page is disabled"))
        key
    end
    versions = Dict{K,UInt64}()
    for (index, page) in enumerate(resolved)
        versions[page.key] = UInt64(index)
    end
    return ContentSwitcher{K}(
        resolved,
        selected,
        versions,
        Dict{K,Tuple{UInt64,Any}}(),
        Dict{K,ReentrantLock}(),
        UInt64(length(resolved)),
        ReentrantLock(),
    )
end

ContentSwitcher(pages::ContentPage{K}...; active=nothing) where {K} =
    ContentSwitcher(ContentPage{K}[pages...]; active)

ContentSwitcher{K}() where {K} = ContentSwitcher(ContentPage{K}[])

function _next_content_generation(switcher::ContentSwitcher)
    switcher.generation == typemax(UInt64) &&
        throw(OverflowError("content switcher generation exhausted"))
    return switcher.generation + UInt64(1)
end

_content_page_index(switcher::ContentSwitcher, key) =
    findfirst(page -> page.key == key, switcher.pages)

content_pages(switcher::ContentSwitcher) = lock(switcher.mutex) do
    copy(switcher.pages)
end

content_page_keys(switcher::ContentSwitcher) = lock(switcher.mutex) do
    [page.key for page in switcher.pages]
end

active_content_key(switcher::ContentSwitcher) = lock(switcher.mutex) do
    switcher.active
end

function active_content_page(switcher::ContentSwitcher)
    return lock(switcher.mutex) do
        switcher.active === nothing && return nothing
        index = _content_page_index(switcher, switcher.active)
        index === nothing ? nothing : switcher.pages[index]
    end
end

function _switch_content_locked!(switcher::ContentSwitcher{K}, key::K) where {K}
    index = _content_page_index(switcher, key)
    index === nothing && throw(KeyError(key))
    switcher.pages[index].disabled && return false
    switcher.active == key && return false
    previous_index = switcher.active === nothing ? nothing :
        _content_page_index(switcher, switcher.active)
    generation = _next_content_generation(switcher)
    if previous_index !== nothing && !switcher.pages[previous_index].keep_alive
        delete!(switcher.cache, switcher.pages[previous_index].key)
    end
    switcher.active = key
    switcher.generation = generation
    return true
end

function switch_content!(switcher::ContentSwitcher{K}, key::K) where {K}
    return lock(switcher.mutex) do
        _switch_content_locked!(switcher, key)
    end
end

function _resolve_page_once!(
    switcher::ContentSwitcher{K},
    key::K,
    page::ContentPage{K},
    version::UInt64,
    page_lock::ReentrantLock,
) where {K}
    return lock(page_lock) do
        status, value = lock(switcher.mutex) do
            index = _content_page_index(switcher, key)
            current = index === nothing ? nothing : switcher.pages[index]
            current_version = get(switcher.versions, key, UInt64(0))
            (current === page && current_version == version) || return :retry, nothing
            if haskey(switcher.cache, key)
                cached_version, cached_value = switcher.cache[key]
                cached_version == version && return :cached, cached_value
                delete!(switcher.cache, key)
            end
            return :load, nothing
        end
        status == :retry && return false, nothing
        status == :cached && return true, value
        resolved = page.lazy ? page.provider() : page.provider
        committed = lock(switcher.mutex) do
            index = _content_page_index(switcher, key)
            current = index === nothing ? nothing : switcher.pages[index]
            current_version = get(switcher.versions, key, UInt64(0))
            (current === page && current_version == version) || return false
            switcher.cache[key] = (version, resolved)
            return true
        end
        return committed, resolved
    end
end

struct ResolvedPageContent{K}
    key::K
    version::UInt64
    content::Any
end

struct ContentPageUnavailable{K} <: Exception
    key::K
end

Base.showerror(io::IO, error::ContentPageUnavailable) =
    print(io, "content page became unavailable: ", repr(error.key))

function resolve_page_content_snapshot!(switcher::ContentSwitcher{K}, key::K) where {K}
    while true
        page, version, page_lock = lock(switcher.mutex) do
            index = _content_page_index(switcher, key)
            index === nothing && throw(ContentPageUnavailable(key))
            page = switcher.pages[index]
            version = switcher.versions[key]
            page_lock = get!(switcher.page_locks, key) do
                ReentrantLock()
            end
            return page, version, page_lock
        end
        resolved, value = _resolve_page_once!(switcher, key, page, version, page_lock)
        resolved && return ResolvedPageContent{K}(key, version, value)
    end
end

resolve_page_content!(switcher::ContentSwitcher, key) =
    resolve_page_content_snapshot!(switcher, key).content

function resolve_active_content!(switcher::ContentSwitcher)
    key = active_content_key(switcher)
    return key === nothing ? nothing : resolve_page_content!(switcher, key)
end

function add_content_page!(
    switcher::ContentSwitcher{K},
    page::ContentPage{K};
    activate::Bool=false,
) where {K}
    return lock(switcher.mutex) do
        _content_page_index(switcher, page.key) === nothing ||
            throw(ArgumentError("content page key already exists: $(page.key)"))
        version = _next_content_generation(switcher)
        previous_index = switcher.active === nothing ? nothing :
            _content_page_index(switcher, switcher.active)
        push!(switcher.pages, page)
        switcher.versions[page.key] = version
        should_activate = (activate || switcher.active === nothing) && !page.disabled
        if should_activate
            if previous_index !== nothing && !switcher.pages[previous_index].keep_alive
                delete!(switcher.cache, switcher.pages[previous_index].key)
            end
            switcher.active = page.key
        end
        switcher.generation = version
        return switcher
    end
end

function replace_content_page!(switcher::ContentSwitcher{K}, page::ContentPage{K}) where {K}
    return lock(switcher.mutex) do
        index = _content_page_index(switcher, page.key)
        index === nothing && throw(KeyError(page.key))
        switcher.active == page.key && page.disabled &&
            throw(ArgumentError("cannot disable the active page during replacement"))
        version = _next_content_generation(switcher)
        switcher.pages[index] = page
        switcher.versions[page.key] = version
        delete!(switcher.cache, page.key)
        switcher.generation = version
        return switcher
    end
end

function _next_enabled_content_key(pages, removed_index)
    isempty(pages) && return nothing
    start = min(removed_index, length(pages))
    for index in start:length(pages)
        !pages[index].disabled && return pages[index].key
    end
    for index in (start - 1):-1:1
        !pages[index].disabled && return pages[index].key
    end
    return nothing
end

function _remove_content_page!(
    switcher::ContentSwitcher,
    key;
    require_closable::Bool,
)
    return lock(switcher.mutex) do
        index = _content_page_index(switcher, key)
        index === nothing && return false
        page = switcher.pages[index]
        require_closable && !page.closable && return false
        was_active = switcher.active == key
        generation = _next_content_generation(switcher)
        deleteat!(switcher.pages, index)
        delete!(switcher.versions, key)
        delete!(switcher.cache, key)
        delete!(switcher.page_locks, key)
        was_active && (switcher.active = _next_enabled_content_key(switcher.pages, index))
        switcher.generation = generation
        return true
    end
end

remove_content_page!(switcher::ContentSwitcher, key) =
    _remove_content_page!(switcher, key; require_closable=false)

close_content_page!(switcher::ContentSwitcher, key) =
    _remove_content_page!(switcher, key; require_closable=true)

function reorder_content_page!(switcher::ContentSwitcher, key, target::Integer)
    return lock(switcher.mutex) do
        index = _content_page_index(switcher, key)
        index === nothing && throw(KeyError(key))
        1 <= target <= length(switcher.pages) || throw(BoundsError(switcher.pages, target))
        index == target && return false
        generation = _next_content_generation(switcher)
        page = splice!(switcher.pages, index)
        insert!(switcher.pages, target, page)
        switcher.generation = generation
        return true
    end
end

function set_content_page_disabled!(switcher::ContentSwitcher{K}, key::K, disabled::Bool) where {K}
    return lock(switcher.mutex) do
        index = _content_page_index(switcher, key)
        index === nothing && throw(KeyError(key))
        page = switcher.pages[index]
        page.disabled == disabled && return false
        disabled && switcher.active == key &&
            throw(ArgumentError("cannot disable the active content page"))
        replacement = ContentPage{K}(
            page.key,
            page.title,
            page.provider,
            page.lazy,
            disabled,
            page.closable,
            page.keep_alive,
            page.metadata,
        )
        version = _next_content_generation(switcher)
        switcher.pages[index] = replacement
        switcher.versions[key] = version
        delete!(switcher.cache, key)
        switcher.generation = version
        return true
    end
end

function invalidate_page_content!(switcher::ContentSwitcher, key)
    return lock(switcher.mutex) do
        _content_page_index(switcher, key) === nothing && throw(KeyError(key))
        version = _next_content_generation(switcher)
        switcher.versions[key] = version
        delete!(switcher.cache, key)
        switcher.generation = version
        return true
    end
end

@enum TabPlacement::UInt8 begin
    TabsAbove
    TabsBelow
    TabsLeft
    TabsRight
end

@enum TabActivation::UInt8 begin
    AutomaticTabActivation
    ManualTabActivation
end

struct TabItem{K}
    key::K
    title::String
    active::Bool
    focused::Bool
    disabled::Bool
    closable::Bool
    metadata::Any
end

struct TabbedContentStateSnapshot{K}
    items::Vector{TabItem{K}}
    active_key::Union{Nothing,K}
    placement::TabPlacement
    activation::TabActivation
end

struct TabbedContentSnapshot{K}
    items::Vector{TabItem{K}}
    active_key::Union{Nothing,K}
    placement::TabPlacement
    activation::TabActivation
    content_version::Union{Nothing,UInt64}
    content::Any
end

mutable struct TabbedContent{K}
    switcher::ContentSwitcher{K}
    placement::TabPlacement
    activation::TabActivation
    focused::Union{Nothing,K}
    mutex::ReentrantLock
end

function TabbedContent(
    pages::AbstractVector{<:ContentPage{K}};
    active=nothing,
    placement::TabPlacement=TabsAbove,
    activation::TabActivation=AutomaticTabActivation,
) where {K}
    switcher = ContentSwitcher(pages; active)
    return TabbedContent{K}(
        switcher,
        placement,
        activation,
        active_content_key(switcher),
        ReentrantLock(),
    )
end

TabbedContent(pages::ContentPage{K}...; kwargs...) where {K} =
    TabbedContent(ContentPage{K}[pages...]; kwargs...)

TabbedContent{K}(; kwargs...) where {K} =
    TabbedContent(ContentPage{K}[]; kwargs...)

function _normalize_tab_focus_locked!(tabs::TabbedContent)
    pages = tabs.switcher.pages
    focused_index = tabs.focused === nothing ? nothing :
        _content_page_index(tabs.switcher, tabs.focused)
    focused_index !== nothing && !pages[focused_index].disabled && return tabs.focused
    active_index = tabs.switcher.active === nothing ? nothing :
        _content_page_index(tabs.switcher, tabs.switcher.active)
    if active_index !== nothing && !pages[active_index].disabled
        tabs.focused = pages[active_index].key
        return tabs.focused
    end
    tabs.focused = if focused_index === nothing
        enabled_index = findfirst(page -> !page.disabled, pages)
        enabled_index === nothing ? nothing : pages[enabled_index].key
    else
        _next_enabled_content_key(pages, focused_index)
    end
    return tabs.focused
end

function _tab_items_locked(tabs::TabbedContent{K}) where {K}
    focused = _normalize_tab_focus_locked!(tabs)
    active = tabs.switcher.active
    return TabItem{K}[
        TabItem(
            page.key,
            page.title,
            page.key == active,
            page.key == focused,
            page.disabled,
            page.closable,
            page.metadata,
        ) for page in tabs.switcher.pages
    ]
end

function _tab_state_snapshot_locked(tabs::TabbedContent{K}) where {K}
    items = _tab_items_locked(tabs)
    return TabbedContentStateSnapshot{K}(
        items,
        tabs.switcher.active,
        tabs.placement,
        tabs.activation,
    )
end

function tabbed_content_state_snapshot(tabs::TabbedContent)
    return lock(tabs.mutex) do
        lock(tabs.switcher.mutex) do
            _tab_state_snapshot_locked(tabs)
        end
    end
end

tab_items(tabs::TabbedContent) = tabbed_content_state_snapshot(tabs).items

function set_tab_placement!(tabs::TabbedContent, placement::TabPlacement)
    return lock(tabs.mutex) do
        tabs.placement == placement && return false
        tabs.placement = placement
        return true
    end
end

function set_tab_activation!(tabs::TabbedContent, activation::TabActivation)
    return lock(tabs.mutex) do
        lock(tabs.switcher.mutex) do
            tabs.activation == activation && return false
            if activation == AutomaticTabActivation && tabs.focused !== nothing
                index = _content_page_index(tabs.switcher, tabs.focused)
                index !== nothing && !tabs.switcher.pages[index].disabled &&
                    _switch_content_locked!(tabs.switcher, tabs.focused)
            end
            tabs.activation = activation
            return true
        end
    end
end

function tabbed_content_snapshot!(tabs::TabbedContent{K}; max_attempts::Integer=64) where {K}
    attempts = Int(max_attempts)
    attempts > 0 || throw(ArgumentError("tabbed snapshot attempt limit must be positive"))
    for _ in 1:attempts
        key = active_content_key(tabs.switcher)
        if key === nothing
            snapshot = lock(tabs.mutex) do
                lock(tabs.switcher.mutex) do
                    tabs.switcher.active === nothing || return nothing
                    state = _tab_state_snapshot_locked(tabs)
                    return TabbedContentSnapshot{K}(
                        state.items,
                        state.active_key,
                        state.placement,
                        state.activation,
                        nothing,
                        nothing,
                    )
                end
            end
            snapshot === nothing || return snapshot
            continue
        end
        resolved = try
            resolve_page_content_snapshot!(tabs.switcher, key)
        catch error
            error isa ContentPageUnavailable || rethrow()
            nothing
        end
        resolved === nothing && continue
        snapshot = lock(tabs.mutex) do
            lock(tabs.switcher.mutex) do
                tabs.switcher.active == key || return nothing
                get(tabs.switcher.versions, key, nothing) == resolved.version || return nothing
                state = _tab_state_snapshot_locked(tabs)
                return TabbedContentSnapshot{K}(
                    state.items,
                    state.active_key,
                    state.placement,
                    state.activation,
                    resolved.version,
                    resolved.content,
                )
            end
        end
        snapshot === nothing || return snapshot
    end
    throw(InvalidStateException(
        "tabbed content changed continuously while creating a component snapshot",
        :active,
    ))
end

selected_tab(tabs::TabbedContent) = active_content_key(tabs.switcher)

focused_tab(tabs::TabbedContent) = lock(tabs.mutex) do
    lock(tabs.switcher.mutex) do
        _normalize_tab_focus_locked!(tabs)
    end
end

function _select_tab_locked!(tabs::TabbedContent{K}, key::K) where {K}
    index = _content_page_index(tabs.switcher, key)
    index === nothing && throw(KeyError(key))
    page = tabs.switcher.pages[index]
    page.disabled && return false
    selection_changed = _switch_content_locked!(tabs.switcher, key)
    focus_changed = tabs.focused != key
    tabs.focused = key
    return selection_changed || focus_changed
end

function select_tab!(tabs::TabbedContent{K}, key::K) where {K}
    return lock(tabs.mutex) do
        lock(tabs.switcher.mutex) do
            _select_tab_locked!(tabs, key)
        end
    end
end

function _focus_tab_locked!(tabs::TabbedContent{K}, key::K) where {K}
    index = _content_page_index(tabs.switcher, key)
    index === nothing && throw(KeyError(key))
    page = tabs.switcher.pages[index]
    page.disabled && return false
    selection_changed = tabs.activation == AutomaticTabActivation ?
        _switch_content_locked!(tabs.switcher, key) : false
    focus_changed = tabs.focused != key
    tabs.focused = key
    return focus_changed || selection_changed
end

function focus_tab!(tabs::TabbedContent{K}, key::K) where {K}
    return lock(tabs.mutex) do
        lock(tabs.switcher.mutex) do
            _focus_tab_locked!(tabs, key)
        end
    end
end

function move_tab_focus!(tabs::TabbedContent, delta::Integer; wrap::Bool=true)
    return lock(tabs.mutex) do
        lock(tabs.switcher.mutex) do
            current = _normalize_tab_focus_locked!(tabs)
            candidates = [page.key for page in tabs.switcher.pages if !page.disabled]
            isempty(candidates) && return false
            index = findfirst(==(current), candidates)
            target = if index === nothing
                Int(delta) < 0 ? length(candidates) : 1
            elseif wrap
                mod1(index + Int(delta), length(candidates))
            else
                clamp(index + Int(delta), 1, length(candidates))
            end
            return _focus_tab_locked!(tabs, candidates[target])
        end
    end
end

function activate_focused_tab!(tabs::TabbedContent)
    return lock(tabs.mutex) do
        lock(tabs.switcher.mutex) do
            key = _normalize_tab_focus_locked!(tabs)
            key === nothing && return false
            return _select_tab_locked!(tabs, key)
        end
    end
end

function add_tab!(tabs::TabbedContent{K}, page::ContentPage{K}; activate::Bool=false) where {K}
    lock(tabs.mutex) do
        lock(tabs.switcher.mutex) do
            add_content_page!(tabs.switcher, page; activate)
            (tabs.focused === nothing || activate) && !page.disabled &&
                (tabs.focused = page.key)
            _normalize_tab_focus_locked!(tabs)
        end
    end
    return tabs
end

function replace_tab!(tabs::TabbedContent, page::ContentPage)
    lock(tabs.mutex) do
        lock(tabs.switcher.mutex) do
            replace_content_page!(tabs.switcher, page)
            _normalize_tab_focus_locked!(tabs)
        end
    end
    return tabs
end

function close_tab!(tabs::TabbedContent, key)
    return lock(tabs.mutex) do
        lock(tabs.switcher.mutex) do
            closed = close_content_page!(tabs.switcher, key)
            closed || return false
            _normalize_tab_focus_locked!(tabs)
            return true
        end
    end
end

move_tab!(tabs::TabbedContent, key, target::Integer) =
    reorder_content_page!(tabs.switcher, key, target)

resolve_tab_content!(tabs::TabbedContent) = resolve_active_content!(tabs.switcher)
