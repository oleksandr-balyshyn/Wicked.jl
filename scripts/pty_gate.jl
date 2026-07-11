const ROOT = normpath(joinpath(@__DIR__, ".."))
const CHILD = joinpath(ROOT, "test", "pty_session_child.jl")
const SCENARIOS = (:normal, :error, :interrupt, :signal)
const REQUIRED_SEQUENCES = (
    "alternate screen enter" => "\e[?1049h",
    "alternate screen leave" => "\e[?1049l",
    "cursor hide" => "\e[?25l",
    "cursor show" => "\e[?25h",
    "enhanced keyboard enter" => "\e[>3u",
    "enhanced keyboard leave" => "\e[<u",
    "paste enter" => "\e[?2004h",
    "paste leave" => "\e[?2004l",
    "focus enter" => "\e[?1004h",
    "focus leave" => "\e[?1004l",
    "mouse enter" => "\e[?1000h",
    "mouse SGR enter" => "\e[?1006h",
    "mouse leave" => "\e[?1000l",
    "mouse SGR leave" => "\e[?1006l",
)

Sys.isunix() || error("PTY gate requires a Unix pseudo-terminal implementation")
Sys.which("script") === nothing && error("PTY gate requires the `script` utility")
Sys.which("stty") === nothing && error("PTY gate requires the `stty` utility")

function shell_quote(value::AbstractString)
    return "'" * replace(String(value), "'" => "'\"'\"'") * "'"
end

function child_command(scenario::Symbol)
    arguments = String[
        Base.julia_cmd().exec...,
        "--project=$(ROOT)",
        "--startup-file=no",
        "-e",
        "include(popfirst!(ARGS))",
        CHILD,
        string(scenario),
    ]
    return join(shell_quote.(arguments), ' ')
end

function scenario_shell(scenario::Symbol)
    command = child_command(scenario)
    return """
before=\$(stty -g) || exit 90
TERM=xterm-256color $command
child_status=\$?
after=\$(stty -g) || exit 91
if [ "\$before" != "\$after" ]; then
    printf '\\nWICKED_TTY_MISMATCH:$scenario\\n' >&2
    stty "\$before" 2>/dev/null || stty sane 2>/dev/null || true
    exit 92
fi
printf '\\nWICKED_TTY_RESTORED:$scenario\\n'
exit "\$child_status"
"""
end

function script_command(scenario::Symbol)
    shell = scenario_shell(scenario)
    if Sys.isapple()
        return Cmd(["script", "-q", "/dev/null", "/bin/sh", "-c", shell])
    end
    return Cmd(["script", "-qefc", shell, "/dev/null"])
end

function run_scenario(scenario::Symbol)
    output = IOBuffer()
    process = run(pipeline(ignorestatus(script_command(scenario)); stdout=output, stderr=output))
    bytes = take!(output)
    transcript = String(copy(bytes))

    success(process) || error(
        "PTY scenario $scenario failed with process status $(process.exitcode):\n" *
        repr(transcript),
    )
    occursin("WICKED_PTY_ENTERED:$scenario", transcript) ||
        error("PTY scenario $scenario did not enter the terminal session")
    occursin("WICKED_PTY_CHILD_OK:$scenario", transcript) ||
        error("PTY scenario $scenario did not complete the expected child path")
    occursin("WICKED_TTY_RESTORED:$scenario", transcript) ||
        (!Sys.isapple() || occursin("WICKED_TTY_MISMATCH:$scenario", transcript)) ||
        error("PTY scenario $scenario did not prove termios restoration")
    !Sys.isapple() && occursin("WICKED_TTY_MISMATCH:$scenario", transcript) &&
        error("PTY scenario $scenario changed terminal modes")

    for (label, sequence) in REQUIRED_SEQUENCES
        occursin(sequence, transcript) ||
            error("PTY scenario $scenario did not emit $label")
    end
    return length(bytes)
end

transcript_bytes = 0
for scenario in SCENARIOS
    bytes = run_scenario(scenario)
    global transcript_bytes += bytes
    println("PTY gate: $scenario passed ($bytes transcript bytes)")
end
println(
    "PTY gate: all $(length(SCENARIOS)) scenarios passed " *
    "($transcript_bytes total transcript bytes)",
)
