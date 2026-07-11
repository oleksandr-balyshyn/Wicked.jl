using Wicked
using Wicked.API
using Wicked.Experimental
using Test

@testset "Wicked" begin
    @testset "geometry" begin
        area = Rect(2, 3, 4, 5)

        @test size(area) == (4, 5)
        @test contains(area, Position(2, 3))
        @test contains(area, Position(5, 7))
        @test !contains(area, Position(6, 7))
        @test intersection(area, Rect(4, 5, 4, 4)) == Rect(4, 5, 2, 3)
        @test inset(area, Margin(1)) == Rect(3, 4, 2, 3)
        @test_throws ArgumentError Rect(0, 1, 1, 1)
        @test_throws ArgumentError Size(-1, 1)
    end

    @testset "buffer rendering" begin
        buffer = Buffer(1, 8)
        render!(buffer, Label("Wicked"), buffer.area)

        @test size(buffer) == (1, 8)
        @test String([buffer[1, column].grapheme[1] for column in 1:6]) == "Wicked"
        @test buffer[1, 7].grapheme == " "

        clipped = Buffer(1, 3)
        render!(clipped, Label("Wicked"; ellipsis="…"), clipped.area)
        @test clipped[1, 3].grapheme == "…"
    end

    @testset "public namespace" begin
        @test parse_color("red") isa Color
        @test ListItem === Wicked.Widgets.ListItem
        @test MarkdownListItem === Wicked.RichContent.ListItem
        @test cancel! === Wicked.Runtime.cancel!
        @test cancel! === Wicked.Reliability.cancel!
    end
end

include("core.jl")
include("buffer_operations.jl")
include("geometry_operations.jl")
include("layout.jl")
include("events.jl")
include("widgets_base.jl")
include("editing.jl")
include("selection_widgets.jl")
include("input_widgets.jl")
include("acceptance_widgets.jl")
include("markup_text.jl")
include("widget_contracts.jl")
include("widget_interactions_extended.jl")
include("new_widget_families.jl")
include("backends.jl")
include("remote_transport.jl")
include("runtime.jl")
include("styles_themes.jl")
include("testing.jl")
include("capabilities.jl")
include("underline_color.jl")
include("terminal_limits.jl")
include("color_detection.jl")
include("inline_backend.jl")
include("terminal_reset.jl")
include("enhanced_keyboard.jl")
include("escape_timeout.jl")
include("terminal_title.jl")
include("mouse_tracking.jl")
include("runtime_resize.jl")
include("terminal_command.jl")
include("process_command.jl")
include("clipboard_command.jl")
include("suspend_runtime.jl")
include("runtime_subscriptions.jl")
include("reactive.jl")
include("api_contract.jl")
include("toolkit_reconciliation.jl")
include("virtual_data.jl")
include("toolkit_semantics.jl")
include("ansi_fuzz.jl")
include("style_properties.jl")
include("clipboard_security.jl")
include("file_browser_security.jl")
include("markdown_link_security.jl")
include("extensions_security.jl")
include("toolkit_depth.jl")
