"""Headless input source driven explicitly by tests or embedding applications."""
mutable struct ChannelInputSource <: AbstractInputSource
    events::Channel{AbstractEvent}
end

function ChannelInputSource(capacity::Integer=1024)
    capacity > 0 || throw(ArgumentError("input channel capacity must be positive"))
    ChannelInputSource(Channel{AbstractEvent}(Int(capacity)))
end

"""Post a typed event to a channel input source."""
function post_event!(source::ChannelInputSource, event::AbstractEvent)
    isopen(source.events) || return false
    put!(source.events, event)
    true
end

read_event!(source::ChannelInputSource) = take!(source.events)

"""Close a channel input source and unblock pending readers."""
function close_input!(source::ChannelInputSource)
    isopen(source.events) && close(source.events)
    nothing
end

close_input!(::AbstractInputSource) = nothing
