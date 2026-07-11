module GraphicsBackend

using ..Graphics: GraphicsProtocol,
                  KittyGraphics,
                  UnicodeGraphics,
                  GraphicsCapabilities,
                  AbstractImageSource,
                  RasterImage,
                  ImageScaling,
                  FitImage,
                  ImagePlacement,
                  GraphicsCommand,
                  FallbackCell,
                  ImageRegistry,
                  RegisteredImage,
                  register_image!,
                  release_image!,
                  encode_graphics,
                  delete_graphics,
                  unicode_fallback

export GraphicsPosition,
       GraphicsEmission,
       GraphicsFrameResult,
       GraphicsLayer,
       begin_graphics_frame!,
       queue_graphic!,
       end_graphics_frame!,
       clear_graphics!,
       AbstractGraphicsSink,
       IOGraphicsSink,
       TestGraphicsSink,
       emit_graphics!,
       emit_graphics_delete!,
       clear_graphics_emission!,
       reset_graphics_sink!,
       graphics_snapshot

struct GraphicsPosition
    row::Int
    column::Int

    function GraphicsPosition(row::Integer, column::Integer)
        row > 0 || throw(ArgumentError("graphics row must be positive"))
        column > 0 || throw(ArgumentError("graphics column must be positive"))
        new(Int(row), Int(column))
    end
end

struct GraphicsEmission
    key::Any
    position::GraphicsPosition
    image::RegisteredImage
    placement::ImagePlacement
    command::GraphicsCommand
    fallback::Union{Nothing,Matrix{FallbackCell}}
    reference_acquired::Bool
end

struct GraphicsFrameResult
    emitted::Int
    deleted::Int
    active::Int
end

abstract type AbstractGraphicsSink end

mutable struct IOGraphicsSink{I<:IO} <: AbstractGraphicsSink
    io::I
    synchronized_updates::Bool
    flush_after_frame::Bool
end

IOGraphicsSink(
    io::I=stdout;
    synchronized_updates::Bool=false,
    flush_after_frame::Bool=true,
) where {I<:IO} = IOGraphicsSink{I}(io, synchronized_updates, flush_after_frame)

mutable struct TestGraphicsSink <: AbstractGraphicsSink
    emissions::Vector{GraphicsEmission}
    deletions::Vector{GraphicsCommand}
    clears::Vector{GraphicsEmission}
end

TestGraphicsSink() = TestGraphicsSink(GraphicsEmission[], GraphicsCommand[], GraphicsEmission[])

mutable struct GraphicsLayer
    capabilities::GraphicsCapabilities
    registry::ImageRegistry
    active::Dict{Any,GraphicsEmission}
    pending::Dict{Any,GraphicsEmission}
    frame_open::Bool
    mutex::ReentrantLock
end

GraphicsLayer(
    capabilities::GraphicsCapabilities;
    registry::ImageRegistry=ImageRegistry(),
) = GraphicsLayer(
    capabilities,
    registry,
    Dict{Any,GraphicsEmission}(),
    Dict{Any,GraphicsEmission}(),
    false,
    ReentrantLock(),
)

function begin_graphics_frame!(layer::GraphicsLayer)
    lock(layer.mutex) do
        layer.frame_open && throw(ArgumentError("a graphics frame is already open"))
        empty!(layer.pending)
        layer.frame_open = true
    end
    return layer
end

function queue_graphic!(
    layer::GraphicsLayer,
    key,
    source::AbstractImageSource,
    row::Integer,
    column::Integer,
    columns::Integer,
    rows::Integer;
    z_index::Integer=0,
    scaling::ImageScaling=FitImage,
    preserve_cursor::Bool=true,
    preferred::Union{Nothing,GraphicsProtocol}=nothing,
)
    return lock(layer.mutex) do
        layer.frame_open || throw(ArgumentError("begin_graphics_frame! must be called before queue_graphic!"))
        previous_pending = get(layer.pending, key, nothing)
        previous_active = get(layer.active, key, nothing)
        existing = previous_pending === nothing ? previous_active : previous_pending
        candidate = register_image!(layer.registry, source)
        acquired = existing === nothing || existing.image.fingerprint != candidate.fingerprint
        reference_acquired = acquired ||
            (previous_pending !== nothing && previous_pending.reference_acquired &&
             previous_pending.image.fingerprint == candidate.fingerprint)
        registered = if acquired
            candidate
        else
            release_image!(layer.registry, candidate.id)
            existing.image
        end
        try
            placement = ImagePlacement(
                columns,
                rows;
                id=registered.id,
                z_index=z_index,
                scaling=scaling,
                preserve_cursor=preserve_cursor,
            )
            command = encode_graphics(source, placement, layer.capabilities; preferred=preferred)
            fallback = command.protocol == UnicodeGraphics ? unicode_fallback(source::RasterImage, columns, rows) : nothing
            emission = GraphicsEmission(
                key,
                GraphicsPosition(row, column),
                registered,
                placement,
                command,
                fallback,
                reference_acquired,
            )
            if previous_pending !== nothing && previous_pending.reference_acquired &&
               previous_pending.image.fingerprint != registered.fingerprint
                release_image!(layer.registry, previous_pending.image.id)
            end
            layer.pending[key] = emission
            return emission
        catch
            acquired && release_image!(layer.registry, registered.id)
            rethrow()
        end
    end
end

function _same_placement(left::GraphicsEmission, right::GraphicsEmission)
    return left.image.fingerprint == right.image.fingerprint &&
           left.position == right.position &&
           left.placement.columns == right.placement.columns &&
           left.placement.rows == right.placement.rows &&
           left.placement.z_index == right.placement.z_index &&
           left.placement.scaling == right.placement.scaling &&
           left.command.protocol == right.command.protocol
end

function _cursor_move(position::GraphicsPosition)
    return "\e[$(position.row);$(position.column)H"
end

function _emit_fallback!(io::IO, emission::GraphicsEmission)
    cells = emission.fallback
    cells === nothing && return
    for row in axes(cells, 1)
        print(io, _cursor_move(GraphicsPosition(emission.position.row + row - 1, emission.position.column)))
        for column in axes(cells, 2)
            cell = cells[row, column]
            foreground = cell.foreground
            background = cell.background
            print(
                io,
                "\e[38;2;$(foreground[1]);$(foreground[2]);$(foreground[3])m",
                "\e[48;2;$(background[1]);$(background[2]);$(background[3])m",
                cell.character,
            )
        end
        print(io, "\e[0m")
    end
end

function emit_graphics!(sink::IOGraphicsSink, emission::GraphicsEmission)
    io = sink.io
    emission.placement.preserve_cursor && print(io, "\e7")
    print(io, _cursor_move(emission.position))
    if emission.command.protocol == UnicodeGraphics
        _emit_fallback!(io, emission)
    else
        for sequence in emission.command.sequences
            print(io, sequence)
        end
    end
    emission.placement.preserve_cursor && print(io, "\e8")
    return sink
end

function emit_graphics_delete!(sink::IOGraphicsSink, command::GraphicsCommand)
    for sequence in command.sequences
        print(sink.io, sequence)
    end
    return sink
end

emit_graphics!(sink::TestGraphicsSink, emission::GraphicsEmission) =
    (push!(sink.emissions, emission); sink)

emit_graphics_delete!(sink::TestGraphicsSink, command::GraphicsCommand) =
    (push!(sink.deletions, command); sink)

function _clear_rectangle!(sink::IOGraphicsSink, emission::GraphicsEmission)
    io = sink.io
    print(io, "\e7", "\e[0m")
    blank = repeat(" ", emission.placement.columns)
    for row in 0:(emission.placement.rows - 1)
        print(io, _cursor_move(GraphicsPosition(emission.position.row + row, emission.position.column)), blank)
    end
    print(io, "\e8")
    return sink
end

function clear_graphics_emission!(sink::IOGraphicsSink, emission::GraphicsEmission)
    command = delete_graphics(emission.command.protocol, emission.image.id)
    if isempty(command.sequences)
        _clear_rectangle!(sink, emission)
    else
        emit_graphics_delete!(sink, command)
    end
    return sink
end


function clear_graphics_emission!(sink::TestGraphicsSink, emission::GraphicsEmission)
    push!(sink.clears, emission)
    command = delete_graphics(emission.command.protocol, emission.image.id)
    isempty(command.sequences) || push!(sink.deletions, command)
    return sink
end

function _begin_sink_frame!(sink::IOGraphicsSink)
    sink.synchronized_updates && print(sink.io, "\e[?2026h")
    return sink
end

_begin_sink_frame!(sink::TestGraphicsSink) = sink

function _end_sink_frame!(sink::IOGraphicsSink)
    sink.synchronized_updates && print(sink.io, "\e[?2026l")
    sink.flush_after_frame && flush(sink.io)
    return sink
end

_end_sink_frame!(sink::TestGraphicsSink) = sink

function end_graphics_frame!(layer::GraphicsLayer, sink::AbstractGraphicsSink)
    return lock(layer.mutex) do
        layer.frame_open || throw(ArgumentError("no graphics frame is open"))
        emitted = 0
        deleted = 0
        references_to_release = UInt32[]
        _begin_sink_frame!(sink)
        try
            for (key, previous) in layer.active
                haskey(layer.pending, key) && continue
                clear_graphics_emission!(sink, previous)
                push!(references_to_release, previous.image.id)
                deleted += 1
            end
            for (key, current) in layer.pending
                previous = get(layer.active, key, nothing)
                if previous === nothing || !_same_placement(previous, current)
                    if previous !== nothing
                        clear_graphics_emission!(sink, previous)
                        if previous.image.fingerprint != current.image.fingerprint
                            push!(references_to_release, previous.image.id)
                        end
                    end
                    emit_graphics!(sink, current)
                    emitted += 1
                end
            end
            for id in references_to_release
                release_image!(layer.registry, id)
            end
            layer.active = copy(layer.pending)
            empty!(layer.pending)
            layer.frame_open = false
        finally
            _end_sink_frame!(sink)
        end
        return GraphicsFrameResult(emitted, deleted, length(layer.active))
    end
end

function clear_graphics!(layer::GraphicsLayer, sink::AbstractGraphicsSink)
    return lock(layer.mutex) do
        _begin_sink_frame!(sink)
        try
            for emission in values(layer.active)
                clear_graphics_emission!(sink, emission)
                release_image!(layer.registry, emission.image.id)
            end
            for emission in values(layer.pending)
                emission.reference_acquired && release_image!(layer.registry, emission.image.id)
            end
            empty!(layer.active)
            empty!(layer.pending)
            layer.frame_open = false
        finally
            _end_sink_frame!(sink)
        end
        return layer
    end
end

function reset_graphics_sink!(sink::TestGraphicsSink)
    empty!(sink.emissions)
    empty!(sink.deletions)
    empty!(sink.clears)
    return sink
end

reset_graphics_sink!(sink::IOGraphicsSink) = sink

function graphics_snapshot(sink::TestGraphicsSink)
    lines = String[]
    for emission in sink.emissions
        push!(
            lines,
            "draw key=$(repr(emission.key)) id=$(emission.image.id) protocol=$(emission.command.protocol) at=$(emission.position.row),$(emission.position.column) size=$(emission.placement.columns)x$(emission.placement.rows)",
        )
    end
    for command in sink.deletions
        push!(lines, "delete protocol=$(command.protocol)")
    end
    for emission in sink.clears
        push!(lines, "clear key=$(repr(emission.key)) at=$(emission.position.row),$(emission.position.column) size=$(emission.placement.columns)x$(emission.placement.rows)")
    end
    return join(lines, '\n')
end

end
