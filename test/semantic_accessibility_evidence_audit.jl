include(joinpath(@__DIR__, "..", "scripts", "semantic_accessibility_evidence_audit.jl"))

function semantic_record(; family="Inputs and controls", candidate="abcdef1234567890", snapshot="https://example.test/semantic-snapshots.tar.gz", actions="https://example.test/action-dispatch.log")
    slug = SemanticAccessibilityEvidenceAudit.family_slug(family)
    return """
    # Semantic Accessibility Evidence Record

    ## Record identity

    | Field | Value |
    | --- | --- |
    | Release-candidate commit | $candidate |
    | Date and UTC time | 2026-07-12 12:00:00 UTC |
    | Julia version | 1.12.6 |
    | Linux distribution, kernel, architecture, and shell | Linux 7.0.0 x86_64 zsh |
    | Active project and manifest digest | Project.toml sha256:abc Manifest-v1.12.toml sha256:def |
    | Widget family scope | $family |
    | Interactive widget inventory digest | api/widget_coverage.tsv sha256:abc api/widget_family_evidence.tsv sha256:def slug=$slug |
    | Semantic audit command | julia --project=. --startup-file=no scripts/widget_audit.jl --require-complete && julia --project=. --startup-file=no scripts/widget_family_evidence_audit.jl |
    | Exit status | 0 |
    | Semantic snapshot artifact path or CI URL | $snapshot |
    | Action dispatch artifact path or CI URL | $actions |

    ## Behaviors checked

    | Behavior | Result |
    | --- | --- |
    | Semantic tree generated for each interactive stable widget | passed |
    | Semantic roles, labels, states, and bounds checked | passed |
    | Stable semantic node IDs checked | passed |
    | Semantic actions exposed for actionable widgets | passed |
    | Semantic dispatch handlers registered for actionable widgets | passed |
    | Keyboard action dispatch checked | passed |
    | Pointer action dispatch checked or marked not applicable | passed |
    | Focus and disabled-state semantics checked | passed |
    | Virtualized, modal, tabbed, progress, and notification states checked when present | passed |
    | WidgetPilot or ToolkitPilot semantic queries checked | passed |
    | No placeholder-only semantic snapshots accepted | passed |

    ## Evidence summary

    - Semantic snapshots and action dispatch logs cover this stable widget family.

    ## Risks and follow-up

    - No accepted risk for this semantic profile.
    """
end

@testset "semantic accessibility evidence audit" begin
    mktempdir() do directory
        write(joinpath(directory, "semantic-inputs-and-controls-abcdef1234567890.md"), semantic_record())
        @test isempty(SemanticAccessibilityEvidenceAudit.audit(; evidence_dir=directory))
        failures = SemanticAccessibilityEvidenceAudit.audit(; evidence_dir=directory, require_complete=true)
        @test any(occursin("requires a completed record for family `Core layout`"), failures)
    end

    mktempdir() do directory
        for family in SemanticAccessibilityEvidenceAudit.REQUIRED_FAMILIES
            slug = SemanticAccessibilityEvidenceAudit.family_slug(family)
            write(joinpath(directory, "semantic-$slug-abcdef1234567890.md"), semantic_record(; family=family))
        end
        @test isempty(SemanticAccessibilityEvidenceAudit.audit(; evidence_dir=directory, require_complete=true))
    end

    mktempdir() do directory
        write(joinpath(directory, "semantic-inputs-and-controls-abcdef1234567890.md"), replace(semantic_record(), "Semantic actions exposed for actionable widgets | passed" => "Semantic actions exposed for actionable widgets | TODO"))
        failures = SemanticAccessibilityEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("contains TODO placeholder text"), failures)
        @test any(occursin("placeholder behavior field: Semantic actions exposed for actionable widgets"), failures)
    end

    mktempdir() do directory
        broken = replace(semantic_record(; snapshot="missing-snapshots.tar.gz", actions="missing-actions.log"), "--require-complete", "--quick")
        write(joinpath(directory, "semantic-inputs-and-controls-abcdef1234567890.md"), broken)
        failures = SemanticAccessibilityEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("semantic audit command must run scripts/widget_audit.jl --require-complete"), failures)
        @test any(occursin("semantic snapshot artifact must be an HTTP(S) URL or an existing artifact path"), failures)
        @test any(occursin("action dispatch artifact must be an HTTP(S) URL or an existing artifact path"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "semantic-inputs-and-controls-abcdef1234567890.md"), semantic_record())
        write(joinpath(directory, "semantic-inputs-and-controls-copy-abcdef1234567890.md"), semantic_record())
        failures = SemanticAccessibilityEvidenceAudit.audit(; evidence_dir=directory)
        @test any(occursin("duplicates semantic evidence identity"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        SemanticAccessibilityEvidenceAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("semantic and accessibility evidence records", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        SemanticAccessibilityEvidenceAudit.main(["--unknown"])
    end
    @test bad_status == 2
end
