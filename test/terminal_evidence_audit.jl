include(joinpath(@__DIR__, "..", "scripts", "terminal_evidence_audit.jl"))

function terminal_record(;
    category="Minimal ANSI / 16 color",
    candidate="abcdef1234567890",
    environment="xterm 390 TERM=xterm COLORTERM=none",
    artifact="https://example.test/terminal-transcript.txt",
)
    return """
    # Terminal Evidence Record

    ## Record identity

    | Field | Value |
    | --- | --- |
    | Matrix category | $category |
    | Wicked commit SHA | $candidate |
    | Date and UTC time | 2026-07-12 12:00:00 UTC |
    | Julia version | 1.12.6 |
    | Linux distribution, kernel, architecture, and shell | Linux 7.0.0 x86_64 zsh |
    | Active project and manifest digest | Project.toml sha256:abc |
    | Terminal emulator, version, `TERM`, and `COLORTERM` | $environment |
    | Multiplexer and version | none |
    | SSH or remote transport details | local |
    | Font family and font size | Monospace 12 |
    | Command run from the repository root | manual: terminal matrix pass |
    | Exit status | 0 |
    | Transcript, screenshot, recording, or CI artifact URI | $artifact |

    ## Behaviors checked

    | Behavior | Result |
    | --- | --- |
    | Startup and shutdown restore terminal modes | passed |
    | Normal exit, thrown error, and interrupt path restore cursor and input modes | passed |
    | Resize redraws without stale cells | passed |
    | Bracketed paste does not corrupt input state | passed |
    | Focus events are parsed or explicitly unavailable | passed |
    | Mouse press, release, wheel, and motion behavior match detected capability | passed |
    | Unicode narrow, wide, combining, emoji, and ambiguous-width text remain aligned | passed |
    | Color fallback does not emit unsupported protocols | passed |
    | Graphics either render through the negotiated protocol or fall back to Unicode | passed |
    | Redirected or non-interactive output does not leak raw-mode control setup | passed |

    ## Evidence summary

    - Terminal transcript passed the complete behavior checklist.

    ## Risks and follow-up

    - No accepted risk for this category.
    """
end

@testset "terminal evidence audit" begin
    mktempdir() do directory
        write(joinpath(directory, "README.md"), "# records\n")
        write(joinpath(directory, "minimal-ansi-16-color-xterm-abcdef1234567890.md"), terminal_record())
        @test isempty(TerminalEvidenceAudit.audit(; evidence_dir=directory))

        complete_failures = TerminalEvidenceAudit.audit(; evidence_dir=directory, require_complete=true)
        @test any(occursin("complete mode missing category: SSH"), complete_failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "minimal-ansi-16-color-xterm-abcdef1234567890.md"), replace(terminal_record(), "Startup and shutdown restore terminal modes | passed" => "Startup and shutdown restore terminal modes | TODO"))
        failures = TerminalEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("contains TODO placeholder text"), failures)
        @test any(occursin("placeholder behavior field: Startup and shutdown restore terminal modes"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "bad-terminal-abcdef1234567890.md"), terminal_record(; category="Bad terminal", artifact="missing-transcript.txt"))
        failures = TerminalEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("unknown matrix category: Bad terminal"), failures)
        @test any(occursin("artifact must be an HTTP(S) URL or an existing artifact path"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "minimal-ansi-16-color-xterm-abcdef1234567890.md"), terminal_record())
        write(joinpath(directory, "minimal-ansi-16-color-xterm-copy-abcdef1234567890.md"), terminal_record())
        failures = TerminalEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("duplicates terminal evidence identity"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        TerminalEvidenceAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("Linux real-terminal evidence records", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        TerminalEvidenceAudit.main(["--unknown"])
    end
    @test bad_status == 2
end
