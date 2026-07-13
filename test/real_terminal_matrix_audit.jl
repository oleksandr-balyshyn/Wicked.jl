include(joinpath(@__DIR__, "..", "scripts", "real_terminal_matrix_audit.jl"))

@testset "real-terminal matrix audit" begin
    @test isempty(RealTerminalMatrixAudit.audit())
    @test "SSH" in RealTerminalMatrixAudit.REQUIRED_CATEGORIES
    @test "examples/reference_application.jl" in RealTerminalMatrixAudit.REQUIRED_COMMANDS

    mktempdir() do directory
        matrix = joinpath(directory, "REAL_TERMINAL_MATRIX.md")
        compatibility = joinpath(directory, "TERMINAL_COMPATIBILITY.md")
        checklist = joinpath(directory, "RELEASE_CHECKLIST.md")
        write(
            matrix,
            """
            # Linux Real-Terminal Matrix

            Wicked supports Linux terminals. Do not record non-Linux operating systems in this matrix.

            ## Matrix

            | Category | Example environments | Required observation | Evidence status |
            | --- | --- | --- | --- |
            | Minimal ANSI / 16 color | `TERM=xterm` | Basic styles downgrade | Not recorded |

            ## Recommended command set

            ```sh
            julia --project=. --startup-file=no scripts/pty_gate.jl
            ```
            """,
        )
        write(compatibility, "")
        write(checklist, "")
        failures = RealTerminalMatrixAudit.audit(;
            matrix_path=matrix,
            compatibility_path=compatibility,
            checklist_path=checklist,
            template_path=compatibility,
        )
        @test any(occursin("missing category: SSH"), failures)
        @test any(occursin("missing identity field: Wicked commit SHA"), failures)
        @test any(occursin("missing behavior field: Startup and shutdown restore terminal modes"), failures)
        @test any(occursin("missing recommended command: examples/reference_application.jl"), failures)
        @test any(occursin("release checklist must require real-terminal matrix evidence"), failures)
    end

    mktempdir() do directory
        matrix = joinpath(directory, "REAL_TERMINAL_MATRIX.md")
        write(
            matrix,
            """
            # Linux Real-Terminal Matrix

            Wicked supports Linux terminals. Do not record non-Linux operating systems in this matrix.

            | Category | Example environments | Required observation | Evidence status |
            | --- | --- | --- | --- |
            | Minimal ANSI / 16 color | `TERM=xterm` | Basic styles downgrade | Maybe |
            | Unsupported terminal | unsupported | unsupported | Not recorded |
            """,
        )
        failures = RealTerminalMatrixAudit.audit(;
            matrix_path=matrix,
            compatibility_path=matrix,
            checklist_path=matrix,
            template_path=matrix,
        )
        @test any(occursin("invalid evidence status: Maybe"), failures)
        @test any(occursin("unexpected category: Unsupported terminal"), failures)
        @test any(occursin("terminal evidence template missing identity field: Matrix category"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        RealTerminalMatrixAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("Linux real-terminal evidence matrix shape", String(take!(help_output)))
end
