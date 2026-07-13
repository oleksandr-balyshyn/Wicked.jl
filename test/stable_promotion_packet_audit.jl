include(joinpath(@__DIR__, "..", "scripts", "stable_promotion_packet_audit.jl"))

function stable_promotion_packet(; family="Inputs and controls", widget="ComboBox", candidate="abcdef1234567890", decision="promote")
    return """
    # Stable Promotion Packet

    ## Identity

    | Field | Value |
    |---|---|
    | Widget family | $family |
    | Widget name | $widget |
    | Source file | src/AcceptanceWidgets.jl |
    | Release-candidate commit | $candidate |
    | Reviewer | release reviewer |
    | Decision | $decision |

    ## Public API decision

    - Stable exported name: Wicked.API.$widget
    - Constructor shape and required keywords: reviewed constructor contract
    - Optional keywords and defaults: reviewed defaults
    - State type: $(widget)State
    - Public state constructor or `state_for` method: state_for($widget)
    - Public event or action results: documented interaction result
    - Toolkit builder or element path: Toolkit element adapter
    - Semantic role and stable node IDs: stable semantic role and ID policy
    - Compatibility alias, deprecation, or removal decision: completed Wicked.Experimental promotion review

    ## Behavior evidence

    | Evidence | Artifact |
    |---|---|
    | `api/widget_coverage.tsv` row | api/widget_coverage.tsv |
    | Zero-size rendering | test/widget_contracts.jl |
    | Minimal-size rendering | test/widget_contracts.jl |
    | Clipped rendering | test/widget_contracts.jl |
    | Resized rendering | test/widget_contracts.jl |
    | State-transition tests | test/widget_interactions_extended.jl |
    | Snapshot tests | test/testing.jl |
    | Keyboard handling | test/widget_interactions_extended.jl |
    | Pointer handling | test/widget_interactions_extended.jl |
    | Toolkit integration | test/toolkit_reconciliation.jl |
    | Semantic tree coverage | test/toolkit_semantics.jl |

    ## Promotion evidence

    | Evidence | Artifact |
    |---|---|
    | `api/widget_promotion_requirements.tsv` release-required rows satisfied | api/widget_promotion_requirements.tsv |
    | `api/stable_widget_candidates.tsv` row marked `stable` | api/stable_widget_candidates.tsv |
    | `api/stable_api.tsv` concrete or parameterized type binding | api/stable_api.tsv |
    | `api/experimental_promotions.tsv` completed row, if applicable | api/experimental_promotions.tsv completed |
    | Pilot evidence package checked by `scripts/pilot_evidence_package_audit.jl` | docs/pilot-evidence/stateful-controls-combobox via write_pilot_evidence_package |
    | Package-level pilot evidence reports, if release-facing | ci-artifacts/pilot-evidence-reports via write_pilot_evidence_package_reports |
    | `Wicked.API` export | src/API.jl |
    | Compatibility namespace state | src/ExperimentalAPI.jl completed |

    ## Developer evidence

    | Evidence | Artifact |
    |---|---|
    | Focused API documentation | docs/API_WIDGETS.md |
    | Component catalog entry | docs/COMPONENT_CATALOG.md |
    | Copyable public example using `Wicked.API` | examples/widget_gallery.jl |
    | Stable facade usage with no Wicked internals | examples/widget_gallery.jl imports Wicked.API and no Wicked.Experimental or subsystem internals |
    | README or guide update, if user-facing | README.md |
    | Framework migration note, if cross-library vocabulary changed | docs/FRAMEWORK_MIGRATION.md |

    ## Family and startup evidence

    | Evidence | Artifact |
    |---|---|
    | `api/widget_family_evidence.tsv` row | api/widget_family_evidence.tsv |
    | Matching `precompile_token` for every type-backed `stable_api_token` | api/widget_family_evidence.tsv |
    | `src/Precompile.jl` first-use workload | src/Precompile.jl |
    | Package loading or precompile evidence, if release-facing | docs/loading-evidence |

    ## Compatibility and release evidence

    | Evidence | Artifact |
    |---|---|
    | Migration note or deprecation plan | docs/FRAMEWORK_MIGRATION.md |
    | `CHANGELOG.md` entry | CHANGELOG.md |
    | Release checklist item | docs/RELEASE_CHECKLIST.md |
    | Real terminal, application, benchmark, or semantic evidence when required | docs/semantic-evidence |

    ## Risks and follow-ups

    - Known limitation: no accepted limitation contradicts the public API.
    - Deferred behavior: no deferred behavior for this promotion.
    - Follow-up issue or milestone: release checklist tracks immutable-candidate evidence.
    """
end

@testset "stable promotion packet audit" begin
    mktempdir() do directory
        write(joinpath(directory, "inputs-and-controls-combobox-abcdef1234567890.md"), stable_promotion_packet())
        @test isempty(StablePromotionPacketAudit.audit(; packet_dir=directory))
        @test isempty(StablePromotionPacketAudit.audit(; packet_dir=directory, require_complete=true))
    end

    mktempdir() do directory
        write(joinpath(directory, "inputs-and-controls-combobox-abcdef1234567890.md"), replace(stable_promotion_packet(), "release reviewer" => "TODO"))
        failures = StablePromotionPacketAudit.audit(; packet_dir=directory)
        @test any(occursin("contains placeholder text"), failures)
        @test any(occursin("placeholder identity field: Reviewer"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "packet.md"), replace(stable_promotion_packet(; candidate="notasha", decision="ship"), "src/AcceptanceWidgets.jl" => "AcceptanceWidgets.jl"))
        failures = StablePromotionPacketAudit.audit(; packet_dir=directory)
        @test any(occursin("release-candidate commit must be"), failures)
        @test any(occursin("decision must be one of"), failures)
        @test any(occursin("source file must identify a src/ path"), failures)
        @test any(occursin("filename must include widget family slug"), failures)
        @test any(occursin("source file must exist in the repository"), failures)
    end

    mktempdir() do directory
        write(joinpath(directory, "inputs-and-controls-combobox-abcdef1234567890.md"), stable_promotion_packet())
        write(joinpath(directory, "inputs-and-controls-combobox-copy-abcdef1234567890.md"), stable_promotion_packet())
        failures = StablePromotionPacketAudit.audit(; packet_dir=directory)
        @test any(occursin("duplicates stable promotion packet identity"), failures)
    end

    mktempdir() do directory
        write(
            joinpath(directory, "inputs-and-controls-combobox-abcdef1234567890.md"),
            replace(stable_promotion_packet(), "| `api/widget_promotion_requirements.tsv` release-required rows satisfied | api/widget_promotion_requirements.tsv |\n" => ""),
        )
        failures = StablePromotionPacketAudit.audit(; packet_dir=directory)
        @test any(occursin("must cite api/widget_promotion_requirements.tsv"), failures)
    end

    mktempdir() do directory
        packet = replace(
            stable_promotion_packet(),
            "| Pilot evidence package checked by `scripts/pilot_evidence_package_audit.jl` | docs/pilot-evidence/stateful-controls-combobox via write_pilot_evidence_package |\n" => "",
            "| Package-level pilot evidence reports, if release-facing | ci-artifacts/pilot-evidence-reports via write_pilot_evidence_package_reports |\n" => "",
            "| Stable facade usage with no Wicked internals | examples/widget_gallery.jl imports Wicked.API and no Wicked.Experimental or subsystem internals |\n" => "",
        )
        write(joinpath(directory, "inputs-and-controls-combobox-abcdef1234567890.md"), packet)
        failures = StablePromotionPacketAudit.audit(; packet_dir=directory)
        @test any(occursin("must cite scripts/pilot_evidence_package_audit.jl"), failures)
        @test any(occursin("must include a pilot evidence package promotion row"), failures)
        @test any(occursin("must include a package-level pilot evidence reports promotion row"), failures)
        @test any(occursin("must cite write_pilot_evidence_package pilot evidence package creation"), failures)
        @test any(occursin("must cite write_pilot_evidence_package_reports package-level report creation"), failures)
        @test any(occursin("must include stable facade usage developer evidence"), failures)
    end

    mktempdir() do directory
        write(
            joinpath(directory, "inputs-and-controls-nonexistentwidget-abcdef1234567890.md"),
            stable_promotion_packet(; widget="NonexistentWidget"),
        )
        failures = StablePromotionPacketAudit.audit(; packet_dir=directory)
        @test any(occursin("must exist in api/stable_api.tsv"), failures)
        @test any(occursin("must have a stable api/stable_widget_candidates.tsv row"), failures)
        @test any(occursin("must have api/widget_coverage.tsv behavior evidence"), failures)
        @test any(occursin("must be listed in api/widget_family_evidence.tsv"), failures)
    end

    mktempdir() do directory
        write(
            joinpath(directory, "inputs-and-controls-combobox-0000000.md"),
            stable_promotion_packet(; candidate="0000000"),
        )
        failures = StablePromotionPacketAudit.audit(; packet_dir=directory)
        @test any(occursin("repeated-character placeholder"), failures)
    end

    mktempdir() do directory
        failures = StablePromotionPacketAudit.audit(; packet_dir=directory, require_complete=true)
        @test any(occursin("requires at least one completed packet record"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        StablePromotionPacketAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("stable widget promotion packet records", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        StablePromotionPacketAudit.main(["--unknown"])
    end
    @test bad_status == 2
end
