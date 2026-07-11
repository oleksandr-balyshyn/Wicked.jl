using Wicked.API
using Wicked.Experimental

function main()
length(ARGS) == 1 || error("usage: pty_session_child.jl <normal|error|interrupt|signal>")
scenario = Symbol(ARGS[1])
scenario in (:normal, :error, :interrupt, :signal) || error("unknown PTY scenario: $scenario")

stdin isa Base.TTY || error("PTY child stdin is not a TTY")
stdout isa Base.TTY || error("PTY child stdout is not a TTY")

capabilities = TerminalCapabilities(
    color_level=:truecolor,
    mouse=true,
    focus=true,
    bracketed_paste=true,
    synchronized_updates=true,
    enhanced_keyboard=true,
    underline_color=true,
    terminal_title=true,
)
backend = AnsiBackend(stdin, stdout; capabilities, size=Size(3, 24))
backend.controller isa JuliaTTYController || error("PTY child did not select JuliaTTYController")
terminal = Terminal(backend)
caught_expected = scenario == :normal

try
    with_terminal(terminal) do active
        draw!(active) do frame
            render!(frame, Paragraph("PTY $(scenario) ✓"), frame.area)
            request_cursor!(frame, CursorRequest(Position(2, 1); shape=BarCursor))
        end
        print(stdout, "\nWICKED_PTY_ENTERED:", scenario, "\n")
        flush(stdout)

        if scenario == :error
            error("injected PTY application failure")
        elseif scenario == :interrupt
            throw(InterruptException())
        elseif scenario == :signal
            helper = run(
                `sh -c $("sleep 0.25; kill -INT $(getpid())")`;
                wait=false,
            )
            try
                counter = UInt64(0)
                while true
                    counter += 1
                    counter % 10_000 == 0 && GC.safepoint()
                end
            finally
                wait(helper)
            end
        end
    end
catch failure
    if scenario == :error &&
       failure isa ErrorException &&
       failure.msg == "injected PTY application failure"
        caught_expected = true
    elseif scenario in (:interrupt, :signal) && failure isa InterruptException
        caught_expected = true
    else
        rethrow()
    end
end

caught_expected || error("PTY scenario did not observe its expected exit path")
backend.session_state == 0 || error("ANSI backend retained session state after cleanup")
backend.controller.raw && error("TTY controller retained raw-mode bookkeeping after cleanup")
println(stdout, "WICKED_PTY_CHILD_OK:", scenario)
flush(stdout)
end

main()
