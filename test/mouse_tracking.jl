function mouse_tracking_output(mode::MouseTrackingMode; supported::Bool=true)
    output = IOBuffer()
    backend = AnsiBackend(
        IOBuffer(),
        output;
        capabilities=TerminalCapabilities(mouse=supported),
        options=TerminalOptions(
            raw_mode=false,
            alternate_screen=false,
            hide_cursor=false,
            mouse_capture=true,
            focus_reporting=false,
            bracketed_paste=false,
            mouse_tracking=mode,
        ),
        controller=NoopTerminalController(),
        size=Size(1, 4),
    )
    enter!(backend)
    entered = String(take!(output))
    leave!(backend)
    entered, String(take!(output))
end

@testset "ANSI mouse tracking modes" begin
    basic_entered, basic_left = mouse_tracking_output(BasicMouseTracking)
    @test occursin("?1000h", basic_entered)
    @test occursin("?1006h", basic_entered)
    @test !occursin("?1002h", basic_entered)
    @test !occursin("?1003h", basic_entered)

    drag_entered, drag_left = mouse_tracking_output(ButtonMotionTracking)
    @test occursin("?1000h", drag_entered)
    @test occursin("?1002h", drag_entered)
    @test !occursin("?1003h", drag_entered)

    any_entered, any_left = mouse_tracking_output(AnyMotionTracking)
    @test occursin("?1000h", any_entered)
    @test !occursin("?1002h", any_entered)
    @test occursin("?1003h", any_entered)

    for output in (basic_left, drag_left, any_left)
        @test occursin("?1006l", output)
        @test occursin("?1003l", output)
        @test occursin("?1002l", output)
        @test occursin("?1000l", output)
    end

    unsupported, left = mouse_tracking_output(AnyMotionTracking; supported=false)
    @test !occursin("?1000h", unsupported)
    @test !occursin("?1006h", unsupported)
    @test !occursin("?1000l", left)
end
