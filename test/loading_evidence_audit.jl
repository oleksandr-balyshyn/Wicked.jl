include(joinpath(@__DIR__, "..", "scripts", "loading_evidence_audit.jl"))

function loading_record(; version="1.12.6", candidate="abcdef1234567890", artifact="https://example.test/loading-log.txt")
    minor = replace(join(split(version, ".")[1:2], "."), "." => "-")
    return """
    # Package Loading Evidence Record

    ## Record identity

    | Field | Value |
    | --- | --- |
    | Release-candidate commit | $candidate |
    | Date and UTC time | 2026-07-12 12:00:00 UTC |
    | Julia version | $version |
    | Linux distribution, kernel, architecture, and shell | Linux 7.0.0 x86_64 zsh |
    | Active project and manifest digest | Project.toml sha256:abc Manifest-$minor sha256:def |
    | Depot profile | clean depot |
    | Loading command | julia --project=. --startup-file=no -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); using Wicked; using Wicked.API; @assert Base.get_extension(Wicked, :WickedHTTPWebSocketsExt) === nothing' |
    | Exit status | 0 |
    | Artifact path or CI URL | $artifact |
    | Imported modules | Wicked, Wicked.API |

    ## Behaviors checked

    | Behavior | Result |
    | --- | --- |
    | `Pkg.instantiate()` completed | passed |
    | `Pkg.precompile()` completed | passed |
    | `using Wicked` completed | passed |
    | `using Wicked.API` completed | passed |
    | No precompile or loading warnings | passed |
    | No optional dependency was required for core loading | passed |
    | HTTP WebSocket extension stayed inactive without HTTP.jl loaded | passed |
    | No raw terminal mode, alternate screen, or input read was triggered | passed |

    ## Evidence summary

    - Package instantiated, precompiled, and loaded from a clean depot.

    ## Risks and follow-up

    - No accepted risk for this loading profile.
    """
end

@testset "loading evidence audit" begin
    mktempdir() do directory
        write(joinpath(directory, "loading-1-12-abcdef1234567890.md"), loading_record())
        @test isempty(LoadingEvidenceAudit.audit(; evidence_dir=directory))
        complete_failures = LoadingEvidenceAudit.audit(; evidence_dir=directory, require_complete=true)
        @test any(occursin("requires at least 2 distinct Julia versions, found 1"), complete_failures)

        write(joinpath(directory, "loading-1-10-abcdef1234567890.md"), loading_record(; version="1.10.11"))
        @test isempty(LoadingEvidenceAudit.audit(; evidence_dir=directory, require_complete=true))
    end

    mktempdir() do directory
        write(joinpath(directory, "loading-1-12-abcdef1234567890.md"), replace(loading_record(), "`using Wicked.API` completed | passed" => "`using Wicked.API` completed | TODO"))
        failures = LoadingEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("contains TODO placeholder text"), failures)
        @test any(occursin("placeholder behavior field: `using Wicked.API` completed"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "loading-1-12-abcdef1234567890.md"), replace(loading_record(; artifact="missing-loading-log.txt"), "using Wicked.API", "import Wicked.API"))
        failures = LoadingEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("loading command must import Wicked.API"), failures)
        @test any(occursin("artifact must be an HTTP(S) URL or an existing artifact path"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "loading-1-12-abcdef1234567890.md"), loading_record())
        write(joinpath(directory, "loading-1-12-copy-abcdef1234567890.md"), loading_record())
        failures = LoadingEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("duplicates loading evidence identity"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        LoadingEvidenceAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("package-loading and precompilation evidence records", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        LoadingEvidenceAudit.main(["--unknown"])
    end
    @test bad_status == 2
end
