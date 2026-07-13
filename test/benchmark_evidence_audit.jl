include(joinpath(@__DIR__, "..", "scripts", "benchmark_evidence_audit.jl"))

function benchmark_record(; candidate="abcdef1234567890", artifact="https://example.test/benchmark-results.toml")
    return """
    # Benchmark Evidence Record

    ## Record identity

    | Field | Value |
    | --- | --- |
    | Release-candidate commit | $candidate |
    | Date and UTC time | 2026-07-12 12:00:00 UTC |
    | Julia version | 1.12.6 |
    | Linux distribution, kernel, architecture, and shell | Linux 7.0.0 x86_64 zsh |
    | Active project and manifest digest | Project.toml sha256:abc |
    | Benchmark command | julia --project=. --startup-file=no benchmark/run.jl --check --output=release-evidence/benchmark/results.toml |
    | Exit status | 0 |
    | Benchmark artifact path or CI URL | $artifact |
    | Budget file digest | benchmark/budgets.toml sha256:def |
    | Samples and warmups | samples=20 warmups=3 |

    ## Workloads checked

    | Workload group | Result |
    | --- | --- |
    | Buffer diff | passed |
    | Sparse and full-screen buffer diff | passed |
    | Unicode width | passed |
    | Runtime input and idle draw | passed |
    | Diagnostics overhead | passed |
    | Services pulse | passed |
    | Actions and routed events | passed |
    | Animations | passed |
    | Layout | passed |
    | Deep flex and grid layout | passed |
    | Stylesheet parsing and cascade | passed |
    | Toolkit reconciliation | passed |
    | High-churn Toolkit reconciliation | passed |
    | Markdown parsing and rendering | passed |
    | Large Markdown and stylesheet documents | passed |
    | Virtual data | passed |
    | Million-row virtual list and table windows | passed |
    | Semantic diffing | passed |
    | Progress and live-display workloads | passed |

    ## Evidence summary

    - Allocation budgets passed and results TOML was archived.

    ## Regression review

    - No accepted regression for this candidate.
    """
end

@testset "benchmark evidence audit" begin
    mktempdir() do directory
        write(joinpath(directory, "benchmark-abcdef1234567890.md"), benchmark_record())
        @test isempty(BenchmarkEvidenceAudit.audit(; evidence_dir=directory))
        @test isempty(BenchmarkEvidenceAudit.audit(; evidence_dir=directory, require_complete=true))
    end

    mktempdir() do directory
        write(joinpath(directory, "benchmark-abcdef1234567890.md"), replace(benchmark_record(), "Buffer diff | passed" => "Buffer diff | TODO"))
        failures = BenchmarkEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("contains TODO placeholder text"), failures)
        @test any(occursin("placeholder workload field: Buffer diff"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "benchmark-abcdef1234567890.md"), replace(benchmark_record(; artifact="missing-results.toml"), "benchmark/run.jl --check" => "benchmark/run.jl --quick"))
        failures = BenchmarkEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("benchmark command must run benchmark/run.jl --check"), failures)
        @test any(occursin("artifact must be an HTTP(S) URL or an existing artifact path"), failures)
    end

    mktempdir() do directory
        @test any(
            occursin("complete mode requires at least one completed benchmark record"),
            BenchmarkEvidenceAudit.audit(; evidence_dir=directory, require_complete=true),
        )
    end

    mktempdir() do directory
        write(joinpath(directory, "benchmark-abcdef1234567890.md"), benchmark_record())
        write(joinpath(directory, "benchmark-copy-abcdef1234567890.md"), benchmark_record())
        failures = BenchmarkEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("duplicates benchmark evidence for candidate"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        BenchmarkEvidenceAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("release-candidate benchmark evidence records", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        BenchmarkEvidenceAudit.main(["--unknown"])
    end
    @test bad_status == 2
end
