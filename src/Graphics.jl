module Graphics

using Base64: base64encode

export GraphicsProtocol,
       NoGraphics,
       KittyGraphics,
       SixelGraphics,
       UnicodeGraphics,
       GraphicsCapabilities,
       detect_graphics_capabilities,
       select_graphics_protocol,
       graphics_queries,
       PixelFormat,
       RGB24,
       RGBA32,
       Gray8,
       AbstractImageSource,
       RasterImage,
       EncodedImage,
       SixelPayload,
       ImageScaling,
       FitImage,
       FillImage,
       StretchImage,
       OriginalImage,
       ImagePlacement,
       GraphicsCommand,
       GraphicsError,
       encode_graphics,
       delete_graphics,
       FallbackCell,
       unicode_fallback,
       ImageRegistry,
       RegisteredImage,
       register_image!,
       release_image!,
       clear_images!,
       image_id,
       AnimationFrame,
       TerminalAnimation,
       play!,
       pause!,
       reset_animation!,
       advance_animation!,
       current_frame

@enum GraphicsProtocol begin
    NoGraphics
    KittyGraphics
    SixelGraphics
    UnicodeGraphics
end

struct GraphicsCapabilities
    protocols::Vector{GraphicsProtocol}
    cell_pixel_width::Union{Nothing,Int}
    cell_pixel_height::Union{Nothing,Int}
    max_chunk_bytes::Int
    supports_animation::Bool
    supports_z_index::Bool

    function GraphicsCapabilities(
        protocols;
        cell_pixel_width::Union{Nothing,Integer}=nothing,
        cell_pixel_height::Union{Nothing,Integer}=nothing,
        max_chunk_bytes::Integer=4_096,
        supports_animation::Bool=false,
        supports_z_index::Bool=false,
    )
        max_chunk_bytes > 0 || throw(ArgumentError("graphics chunk size must be positive"))
        cell_pixel_width !== nothing && cell_pixel_width <= 0 && throw(ArgumentError("cell pixel width must be positive"))
        cell_pixel_height !== nothing && cell_pixel_height <= 0 && throw(ArgumentError("cell pixel height must be positive"))
        ordered = GraphicsProtocol[]
        for protocol in protocols
            protocol in ordered || push!(ordered, protocol)
        end
        if NoGraphics in ordered
            empty!(ordered)
            push!(ordered, NoGraphics)
        else
            UnicodeGraphics in ordered || push!(ordered, UnicodeGraphics)
        end
        new(
            ordered,
            cell_pixel_width === nothing ? nothing : Int(cell_pixel_width),
            cell_pixel_height === nothing ? nothing : Int(cell_pixel_height),
            Int(max_chunk_bytes),
            supports_animation,
            supports_z_index,
        )
    end
end

function _explicit_protocol(value::AbstractString)
    normalized = lowercase(strip(value))
    return normalized == "kitty" ? KittyGraphics :
           normalized == "sixel" ? SixelGraphics :
           normalized in ("unicode", "text") ? UnicodeGraphics :
           normalized in ("none", "off") ? NoGraphics : nothing
end

"""Infer graphics support from explicit configuration and terminal responses."""
function detect_graphics_capabilities(;
    environment=ENV,
    primary_device_attributes::AbstractString="",
    kitty_response::AbstractString="",
    cell_pixel_width::Union{Nothing,Integer}=nothing,
    cell_pixel_height::Union{Nothing,Integer}=nothing,
)
    protocols = GraphicsProtocol[]
    explicit = get(environment, "WICKED_GRAPHICS", "")
    if !isempty(explicit)
        for entry in split(explicit, ',')
            protocol = _explicit_protocol(entry)
            protocol === nothing || push!(protocols, protocol)
        end
    else
        term = lowercase(get(environment, "TERM", ""))
        program = lowercase(get(environment, "TERM_PROGRAM", ""))
        !isempty(kitty_response) && occursin("_Gi=", kitty_response) && push!(protocols, KittyGraphics)
        (occursin("kitty", term) || program == "wezterm") && push!(protocols, KittyGraphics)
        (occursin(";4", primary_device_attributes) || occursin("sixel", term)) && push!(protocols, SixelGraphics)
    end
    NoGraphics in protocols && return GraphicsCapabilities(GraphicsProtocol[NoGraphics])
    supports_kitty = KittyGraphics in protocols
    return GraphicsCapabilities(
        protocols;
        cell_pixel_width=cell_pixel_width,
        cell_pixel_height=cell_pixel_height,
        supports_animation=supports_kitty,
        supports_z_index=supports_kitty,
    )
end

function graphics_queries()
    return String[
        "\e[c",
        "\e[16t",
        "\e_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\e\\",
    ]
end

@enum PixelFormat begin
    RGB24
    RGBA32
    Gray8
end

_channels(format::PixelFormat) = format == RGB24 ? 3 : format == RGBA32 ? 4 : 1

abstract type AbstractImageSource end

struct RasterImage <: AbstractImageSource
    width::Int
    height::Int
    format::PixelFormat
    data::Vector{UInt8}
    stride::Int

    function RasterImage(
        width::Integer,
        height::Integer,
        format::PixelFormat,
        data::AbstractVector{UInt8};
        stride::Integer=Int(width) * _channels(format),
    )
        width > 0 || throw(ArgumentError("image width must be positive"))
        height > 0 || throw(ArgumentError("image height must be positive"))
        minimum_stride = Int(width) * _channels(format)
        stride >= minimum_stride || throw(ArgumentError("image stride is smaller than one pixel row"))
        length(data) >= Int(stride) * Int(height) || throw(ArgumentError("image data is shorter than stride * height"))
        new(Int(width), Int(height), format, Vector{UInt8}(data), Int(stride))
    end
end

struct EncodedImage <: AbstractImageSource
    data::Vector{UInt8}
    mime::String
    pixel_width::Union{Nothing,Int}
    pixel_height::Union{Nothing,Int}

    function EncodedImage(
        data::AbstractVector{UInt8},
        mime::AbstractString;
        pixel_width::Union{Nothing,Integer}=nothing,
        pixel_height::Union{Nothing,Integer}=nothing,
    )
        isempty(data) && throw(ArgumentError("encoded image cannot be empty"))
        pixel_width !== nothing && pixel_width <= 0 && throw(ArgumentError("pixel width must be positive"))
        pixel_height !== nothing && pixel_height <= 0 && throw(ArgumentError("pixel height must be positive"))
        new(
            Vector{UInt8}(data),
            lowercase(strip(String(mime))),
            pixel_width === nothing ? nothing : Int(pixel_width),
            pixel_height === nothing ? nothing : Int(pixel_height),
        )
    end
end

struct SixelPayload <: AbstractImageSource
    data::String

    function SixelPayload(data::AbstractString)
        isempty(data) && throw(ArgumentError("Sixel payload cannot be empty"))
        new(String(data))
    end
end

@enum ImageScaling begin
    FitImage
    FillImage
    StretchImage
    OriginalImage
end

struct ImagePlacement
    id::UInt32
    columns::Int
    rows::Int
    z_index::Int
    scaling::ImageScaling
    preserve_cursor::Bool

    function ImagePlacement(
        columns::Integer,
        rows::Integer;
        id::Integer=0,
        z_index::Integer=0,
        scaling::ImageScaling=FitImage,
        preserve_cursor::Bool=true,
    )
        columns > 0 || throw(ArgumentError("image columns must be positive"))
        rows > 0 || throw(ArgumentError("image rows must be positive"))
        0 <= id <= typemax(UInt32) || throw(ArgumentError("image id must fit UInt32"))
        new(UInt32(id), Int(columns), Int(rows), Int(z_index), scaling, preserve_cursor)
    end
end

struct GraphicsCommand
    protocol::GraphicsProtocol
    sequences::Vector{String}
    columns::Int
    rows::Int
end

struct GraphicsError <: Exception
    protocol::GraphicsProtocol
    message::String
end

Base.showerror(io::IO, error::GraphicsError) =
    print(io, "graphics encoding failed for ", error.protocol, ": ", error.message)

function select_graphics_protocol(
    capabilities::GraphicsCapabilities,
    source::AbstractImageSource;
    preferred::Union{Nothing,GraphicsProtocol}=nothing,
)
    if preferred !== nothing
        preferred in capabilities.protocols || throw(GraphicsError(preferred, "requested protocol is not supported"))
        return preferred
    end
    for protocol in capabilities.protocols
        protocol == NoGraphics && continue
        protocol == UnicodeGraphics && source isa EncodedImage && continue
        return protocol
    end
    return NoGraphics
end

_kitty_format(source::RasterImage) = source.format == RGBA32 ? 32 : 24
function _kitty_format(source::EncodedImage)
    source.mime == "image/png" || throw(GraphicsError(KittyGraphics, "Kitty encoded transfer currently requires PNG"))
    return 100
end

function _kitty_bytes(source::AbstractImageSource)
    if source isa RasterImage
        input_channels = _channels(source.format)
        output_channels = source.format == Gray8 ? 3 : input_channels
        compact = Vector{UInt8}(undef, source.width * source.height * output_channels)
        destination = 1
        for y in 1:source.height, x in 1:source.width
            offset = (y - 1) * source.stride + (x - 1) * input_channels + 1
            if source.format == Gray8
                value = source.data[offset]
                compact[destination] = value
                compact[destination + 1] = value
                compact[destination + 2] = value
            else
                copyto!(compact, destination, source.data, offset, output_channels)
            end
            destination += output_channels
        end
        return compact
    end
    source isa EncodedImage && return source.data
    throw(GraphicsError(KittyGraphics, "unsupported image source"))
end

function _kitty_sequences(source::AbstractImageSource, placement::ImagePlacement, chunk_size::Int)
    encoded = base64encode(_kitty_bytes(source))
    chunks = String[]
    index = firstindex(encoded)
    while index <= lastindex(encoded)
        stop = min(lastindex(encoded), index + chunk_size - 1)
        push!(chunks, String(SubString(encoded, index, stop)))
        index = stop + 1
    end
    parameters = String[
        "a=T",
        "t=d",
        "q=2",
        "f=$(_kitty_format(source))",
        "c=$(placement.columns)",
        "r=$(placement.rows)",
    ]
    placement.id != 0 && push!(parameters, "i=$(placement.id)")
    placement.z_index != 0 && push!(parameters, "z=$(placement.z_index)")
    if source isa RasterImage
        push!(parameters, "s=$(source.width)")
        push!(parameters, "v=$(source.height)")
    end
    sequences = String[]
    for (chunk_index, chunk) in enumerate(chunks)
        more = chunk_index < length(chunks) ? 1 : 0
        controls = chunk_index == 1 ? join(vcat(parameters, ["m=$more"]), ',') : "m=$more"
        push!(sequences, "\e_G$controls;$chunk\e\\")
    end
    return sequences
end

function _pixel(source::RasterImage, x::Int, y::Int)
    offset = (y - 1) * source.stride + (x - 1) * _channels(source.format) + 1
    if source.format == RGB24
        return (source.data[offset], source.data[offset + 1], source.data[offset + 2], UInt8(255))
    elseif source.format == RGBA32
        return (source.data[offset], source.data[offset + 1], source.data[offset + 2], source.data[offset + 3])
    else
        value = source.data[offset]
        return (value, value, value, UInt8(255))
    end
end

function _palette_index(red::UInt8, green::UInt8, blue::UInt8)
    r = round(Int, red / 255 * 5)
    g = round(Int, green / 255 * 5)
    b = round(Int, blue / 255 * 5)
    return 16 + 36 * r + 6 * g + b
end

function _palette_rgb(index::Int)
    value = index - 16
    r = div(value, 36)
    g = div(rem(value, 36), 6)
    b = rem(value, 6)
    return (round(Int, r / 5 * 100), round(Int, g / 5 * 100), round(Int, b / 5 * 100))
end

function _sixel_run(character::Char, count::Int)
    count <= 0 && return ""
    count >= 4 && return "!$count$character"
    return repeat(string(character), count)
end

function _sixel_encode(source::RasterImage)
    colors = Set{Int}()
    for y in 1:source.height, x in 1:source.width
        red, green, blue, alpha = _pixel(source, x, y)
        alpha >= 0x80 && push!(colors, _palette_index(red, green, blue))
    end
    output = IOBuffer()
    print(output, "\ePq")
    for index in sort!(collect(colors))
        red, green, blue = _palette_rgb(index)
        print(output, '#', index, ";2;", red, ';', green, ';', blue)
    end
    for band_start in 1:6:source.height
        first_color = true
        for color in sort!(collect(colors))
            first_color || print(output, '$')
            first_color = false
            print(output, '#', color)
            run_character = Char(0)
            run_length = 0
            for x in 1:source.width
                mask = 0
                for bit in 0:5
                    y = band_start + bit
                    y > source.height && continue
                    red, green, blue, alpha = _pixel(source, x, y)
                    alpha >= 0x80 && _palette_index(red, green, blue) == color && (mask |= 1 << bit)
                end
                character = Char(63 + mask)
                if character == run_character
                    run_length += 1
                else
                    run_length > 0 && print(output, _sixel_run(run_character, run_length))
                    run_character = character
                    run_length = 1
                end
            end
            run_length > 0 && print(output, _sixel_run(run_character, run_length))
        end
        band_start + 6 <= source.height && print(output, '-')
    end
    print(output, "\e\\")
    return String(take!(output))
end

struct FallbackCell
    character::Char
    foreground::NTuple{3,UInt8}
    background::NTuple{3,UInt8}
end

function _sample_pixel(source::RasterImage, x::Int, y::Int)
    red, green, blue, alpha = _pixel(source, clamp(x, 1, source.width), clamp(y, 1, source.height))
    alpha < 0x80 && return (UInt8(0), UInt8(0), UInt8(0))
    return (red, green, blue)
end

function unicode_fallback(source::RasterImage, columns::Integer, rows::Integer)
    columns > 0 || throw(ArgumentError("fallback columns must be positive"))
    rows > 0 || throw(ArgumentError("fallback rows must be positive"))
    cells = Matrix{FallbackCell}(undef, Int(rows), Int(columns))
    for row in 1:Int(rows), column in 1:Int(columns)
        x = clamp(round(Int, (column - 0.5) / columns * source.width), 1, source.width)
        upper_y = clamp(round(Int, (2row - 1.5) / (2rows) * source.height), 1, source.height)
        lower_y = clamp(round(Int, (2row - 0.5) / (2rows) * source.height), 1, source.height)
        cells[row, column] = FallbackCell(Char(0x2580), _sample_pixel(source, x, upper_y), _sample_pixel(source, x, lower_y))
    end
    return cells
end

function encode_graphics(
    source::AbstractImageSource,
    placement::ImagePlacement,
    capabilities::GraphicsCapabilities;
    preferred::Union{Nothing,GraphicsProtocol}=nothing,
)
    protocol = select_graphics_protocol(capabilities, source; preferred=preferred)
    sequences = if protocol == KittyGraphics
        _kitty_sequences(source, placement, capabilities.max_chunk_bytes)
    elseif protocol == SixelGraphics
        source isa SixelPayload ? String[source.data] : source isa RasterImage ? String[_sixel_encode(source)] : throw(GraphicsError(protocol, "Sixel transfer requires raster pixels or a Sixel payload"))
    elseif protocol == UnicodeGraphics
        source isa RasterImage || throw(GraphicsError(protocol, "Unicode fallback requires raster pixels"))
        String[]
    else
        throw(GraphicsError(protocol, "no usable graphics protocol"))
    end
    return GraphicsCommand(protocol, sequences, placement.columns, placement.rows)
end

function delete_graphics(protocol::GraphicsProtocol, id::Integer=0)
    if protocol == KittyGraphics
        selector = id == 0 ? "a=d,d=A" : "a=d,d=i,i=$id"
        return GraphicsCommand(protocol, String["\e_G$selector\e\\"], 0, 0)
    elseif protocol == SixelGraphics || protocol == UnicodeGraphics
        return GraphicsCommand(protocol, String[], 0, 0)
    end
    return GraphicsCommand(NoGraphics, String[], 0, 0)
end

struct RegisteredImage
    id::UInt32
    fingerprint::UInt64
    references::Int
end

mutable struct ImageRegistry
    by_fingerprint::Dict{UInt64,RegisteredImage}
    by_id::Dict{UInt32,UInt64}
    next_id::UInt32
    mutex::ReentrantLock
end

ImageRegistry(; first_id::Integer=1) = begin
    0 < first_id <= typemax(UInt32) || throw(ArgumentError("first image id must fit positive UInt32"))
    ImageRegistry(Dict{UInt64,RegisteredImage}(), Dict{UInt32,UInt64}(), UInt32(first_id), ReentrantLock())
end

_image_bytes(source::RasterImage) = source.data
_image_bytes(source::EncodedImage) = source.data
_image_bytes(source::SixelPayload) = codeunits(source.data)

function _fingerprint(source::AbstractImageSource)
    seed = hash(typeof(source), UInt(0))
    source isa RasterImage && (seed = hash((source.width, source.height, source.format, source.stride), seed))
    source isa EncodedImage && (seed = hash((source.mime, source.pixel_width, source.pixel_height), seed))
    return UInt64(hash(_image_bytes(source), seed))
end

function register_image!(registry::ImageRegistry, source::AbstractImageSource)
    fingerprint = _fingerprint(source)
    return lock(registry.mutex) do
        existing = get(registry.by_fingerprint, fingerprint, nothing)
        if existing !== nothing
            updated = RegisteredImage(existing.id, fingerprint, existing.references + 1)
            registry.by_fingerprint[fingerprint] = updated
            return updated
        end
        id = registry.next_id
        registry.next_id = registry.next_id == typemax(UInt32) ? UInt32(1) : registry.next_id + UInt32(1)
        haskey(registry.by_id, id) && throw(GraphicsError(NoGraphics, "image id space is exhausted"))
        registered = RegisteredImage(id, fingerprint, 1)
        registry.by_fingerprint[fingerprint] = registered
        registry.by_id[id] = fingerprint
        return registered
    end
end

image_id(registry::ImageRegistry, source::AbstractImageSource) = lock(registry.mutex) do
    fingerprint = _fingerprint(source)
    registered = get(registry.by_fingerprint, fingerprint, nothing)
    registered === nothing ? nothing : registered.id
end

function release_image!(registry::ImageRegistry, id::Integer)
    0 <= id <= typemax(UInt32) || return false
    return lock(registry.mutex) do
        fingerprint = get(registry.by_id, UInt32(id), nothing)
        fingerprint === nothing && return false
        registered = registry.by_fingerprint[fingerprint]
        if registered.references > 1
            registry.by_fingerprint[fingerprint] = RegisteredImage(registered.id, fingerprint, registered.references - 1)
        else
            delete!(registry.by_fingerprint, fingerprint)
            delete!(registry.by_id, registered.id)
        end
        return true
    end
end

function clear_images!(registry::ImageRegistry)
    lock(registry.mutex) do
        empty!(registry.by_fingerprint)
        empty!(registry.by_id)
    end
    return registry
end

struct AnimationFrame{I<:AbstractImageSource}
    image::I
    duration_ms::Int

    function AnimationFrame(image::I, duration_ms::Integer) where {I<:AbstractImageSource}
        duration_ms > 0 || throw(ArgumentError("animation frame duration must be positive"))
        new{I}(image, Int(duration_ms))
    end
end

mutable struct TerminalAnimation
    frames::Vector{AnimationFrame}
    index::Int
    elapsed_ms::Int
    playing::Bool
    looping::Bool

    function TerminalAnimation(frames; playing::Bool=true, looping::Bool=true)
        values = AnimationFrame[frame for frame in frames]
        isempty(values) && throw(ArgumentError("animation requires at least one frame"))
        new(values, 1, 0, playing, looping)
    end
end

play!(animation::TerminalAnimation) = (animation.playing = true; animation)
pause!(animation::TerminalAnimation) = (animation.playing = false; animation)
reset_animation!(animation::TerminalAnimation) = (animation.index = 1; animation.elapsed_ms = 0; animation)
current_frame(animation::TerminalAnimation) = animation.frames[animation.index]

function advance_animation!(animation::TerminalAnimation, delta_ms::Integer)
    delta_ms >= 0 || throw(ArgumentError("animation delta cannot be negative"))
    animation.playing || return false
    animation.elapsed_ms += Int(delta_ms)
    changed = false
    while animation.elapsed_ms >= current_frame(animation).duration_ms
        animation.elapsed_ms -= current_frame(animation).duration_ms
        if animation.index < length(animation.frames)
            animation.index += 1
        elseif animation.looping
            animation.index = 1
        else
            animation.index = length(animation.frames)
            animation.elapsed_ms = 0
            animation.playing = false
            changed = true
            break
        end
        changed = true
    end
    return changed
end

end
