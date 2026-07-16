include(joinpath(@__DIR__, "..", "scripts", "application_evidence_audit.jl"))

function application_record(; name="ExampleApp", candidate="abcdef1234567890", artifact="https://example.test/application-ci.txt")
    return """
    # Real Application Evidence Record

    ## Record identity

    | Field | Value |
    | --- | --- |
    | Application name | $name |
    | Application repository or owner | acme/$name |
    | Release-candidate commit | $candidate |
    | Date and UTC time | 2026-07-12 12:00:00 UTC |
    | Julia version | 1.12.6 |
    | Linux distribution, kernel, architecture, and shell | Linux 7.0.0 x86_64 zsh |
    | Wicked dependency source | git sha $candidate |
    | Command run from the application root | julia --project=. --startup-file=no test/runtests.jl |
    | Exit status | 0 |
    | Artifact path or CI URL | $artifact |

    ## Behaviors checked

    | Behavior | Result |
    | --- | --- |
    | Package loading and precompilation | passed |
    | Wicked dependency source identifies the release-candidate commit | passed |
    | Application imports Wicked.API and does not import Wicked internals or Wicked.Experimental | passed |
    | Application startup and shutdown | passed |
    | At least one interactive widget flow | passed |
    | Layout resize or narrow-terminal behavior | passed |
    | Input, focus, paste, pointer, or keyboard behavior | passed |
    | Styling, theme, or color fallback behavior | passed |
    | Error, cancellation, or cleanup behavior | passed |
    | Documentation or migration issue found | none |

    ## Evidence summary

    - Application acceptance suite passed against the candidate dependency.

    ## Risks and follow-up

    - No accepted risk for this application.
    """
end

@testset "application evidence audit" begin
    mktempdir() do directory
        write(joinpath(directory, "exampleapp-abcdef1234567890.md"), application_record())
        @test isempty(ApplicationEvidenceAudit.audit(; evidence_dir=directory))

        complete_failures = ApplicationEvidenceAudit.audit(; evidence_dir=directory, require_complete=true)
        @test any(occursin("requires at least 2 distinct applications, found 1"), complete_failures)

        write(joinpath(directory, "secondapp-abcdef1234567890.md"), application_record(; name="SecondApp"))
        @test isempty(ApplicationEvidenceAudit.audit(; evidence_dir=directory, require_complete=true))
    end

    mktempdir() do directory
        write(joinpath(directory, "exampleapp-abcdef1234567890.md"), replace(application_record(), "Application startup and shutdown | passed" => "Application startup and shutdown | TODO"))
        failures = ApplicationEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("contains TODO placeholder text"), failures)
        @test any(occursin("placeholder behavior field: Application startup and shutdown"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "exampleapp-abcdef1234567890.md"), application_record(; artifact="missing-application-artifact.txt"))
        failures = ApplicationEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("artifact must be an HTTP(S) URL or an existing artifact path"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "exampleapp-abcdef1234567890.md"), application_record())
        write(joinpath(directory, "exampleapp-copy-abcdef1234567890.md"), application_record())
        failures = ApplicationEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("duplicates application evidence identity"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        ApplicationEvidenceAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("independent real-application evidence records", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        ApplicationEvidenceAudit.main(["--unknown"])
    end
    @test bad_status == 2
end
