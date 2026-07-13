include(joinpath(@__DIR__, "..", "scripts", "documentation_evidence_audit.jl"))

function documentation_record(; version="1.12.6", candidate="abcdef1234567890", artifact="https://example.test/documenter-log.txt")
    minor = replace(join(split(version, ".")[1:2], "."), "." => "-")
    return """
    # Documentation Evidence Record

    ## Record identity

    | Field | Value |
    | --- | --- |
    | Release-candidate commit | $candidate |
    | Date and UTC time | 2026-07-12 12:00:00 UTC |
    | Julia version | $version |
    | Linux distribution, kernel, architecture, and shell | Linux 7.0.0 x86_64 zsh |
    | Documentation project and manifest digest | docs/Project.toml sha256:abc docs/Manifest-$minor sha256:def |
    | Documentation instantiate command | julia --project=docs --startup-file=no -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()' |
    | Documentation build command | julia --project=docs --startup-file=no docs/make.jl |
    | Exit status | 0 |
    | Documentation artifact path or CI URL | $artifact |
    | Generated output path | build/docs |
    | Documenter configuration | doctest = true; checkdocs = :exports; pagesonly = true |

    ## Behaviors checked

    | Behavior | Result |
    | --- | --- |
    | `Pkg.develop(PackageSpec(path=pwd()))` completed | passed |
    | `Pkg.instantiate()` completed | passed |
    | `docs/make.jl` completed | passed |
    | `doctest = true` enforced | passed |
    | `checkdocs = :exports` enforced | passed |
    | `WICKED_DOC_MODULES` discovered Wicked submodules | passed |
    | API route map and stable facade guidance were included | passed |
    | Public example family index was included | passed |
    | Release and evidence gates were linked | passed |
    | Generated HTML was archived | passed |
    | No Documenter warnings | passed |
    | No missing cross-reference or link errors | passed |

    ## Evidence summary

    - Strict Documenter manual built and the generated HTML artifact was archived.

    ## Risks and follow-up

    - No accepted risk for this documentation profile.
    """
end

@testset "documentation evidence audit" begin
    mktempdir() do directory
        write(joinpath(directory, "documentation-1-12-abcdef1234567890.md"), documentation_record())
        @test isempty(DocumentationEvidenceAudit.audit(; evidence_dir=directory))
        complete_failures = DocumentationEvidenceAudit.audit(; evidence_dir=directory, require_complete=true)
        @test any(occursin("requires at least 2 distinct Julia versions, found 1"), complete_failures)

        write(joinpath(directory, "documentation-1-10-abcdef1234567890.md"), documentation_record(; version="1.10.11"))
        @test isempty(DocumentationEvidenceAudit.audit(; evidence_dir=directory, require_complete=true))
    end

    mktempdir() do directory
        write(joinpath(directory, "documentation-1-12-abcdef1234567890.md"), replace(documentation_record(), "Public example family index was included | passed" => "Public example family index was included | TODO"))
        failures = DocumentationEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("contains TODO placeholder text"), failures)
        @test any(occursin("placeholder behavior field: Public example family index was included"), failures)
    end

    mktempdir() do directory
        broken = replace(documentation_record(; artifact="missing-documenter-log.txt"), "docs/make.jl", "docs/not-make.jl")
        broken = replace(broken, "doctest = true", "doctest = false")
        write(joinpath(directory, "documentation-1-12-abcdef1234567890.md"), broken)
        failures = DocumentationEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("documentation build command must run docs/make.jl"), failures)
        @test any(occursin("Documenter configuration must record doctest = true"), failures)
        @test any(occursin("artifact must be an HTTP(S) URL or an existing artifact path"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "documentation-1-12-abcdef1234567890.md"), documentation_record())
        write(joinpath(directory, "documentation-1-12-copy-abcdef1234567890.md"), documentation_record())
        failures = DocumentationEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("duplicates documentation evidence identity"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        DocumentationEvidenceAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("strict Documenter manual evidence records", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        DocumentationEvidenceAudit.main(["--unknown"])
    end
    @test bad_status == 2
end
