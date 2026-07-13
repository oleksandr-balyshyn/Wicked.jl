include(joinpath(@__DIR__, "..", "scripts", "stable_widget_candidates.jl"))

@testset "stable widget candidates" begin
    @test isempty(read_experimental_promotion_plan())

    missing_plan_row = compatibility_candidate_row(
        "ExperimentalPanel",
        "src/widgets.jl",
        "complete",
        "all widget evidence dimensions recorded",
        Dict{String,NamedTuple{(:decision,:target,:review_status,:notes),NTuple{4,String}}}(),
    )
    @test missing_plan_row.surface == "compatibility"
    @test missing_plan_row.status == "blocked"
    @test missing_plan_row.reason == "missing experimental promotion/removal plan"

    proposed_rows = Dict(
        "ExperimentalPanel" => (
            decision="promote",
            target="Wicked.API.ExperimentalPanel",
            review_status="proposed",
            notes="Constructor, render, Toolkit, semantic, and snapshot evidence complete.",
        ),
    )
    proposed_row = compatibility_candidate_row(
        "ExperimentalPanel",
        "src/widgets.jl",
        "complete",
        "all widget evidence dimensions recorded",
        proposed_rows,
    )
    @test proposed_row.status == "blocked"
    @test proposed_row.reason == "experimental promotion/removal plan must be accepted or completed before candidate promotion"

    planned_rows = Dict(
        "ExperimentalPanel" => (
            decision="promote",
            target="Wicked.API.ExperimentalPanel",
            review_status="accepted",
            notes="Constructor, render, Toolkit, semantic, and snapshot evidence complete.",
        ),
    )
    candidate_row = compatibility_candidate_row(
        "ExperimentalPanel",
        "src/widgets.jl",
        "complete",
        "all widget evidence dimensions recorded",
        planned_rows,
    )
    @test candidate_row.status == "candidate"
    @test occursin("promote to Wicked.API.ExperimentalPanel", candidate_row.reason)

    blocked_row = compatibility_candidate_row(
        "ExperimentalPanel",
        "src/widgets.jl",
        "blocked",
        "missing snapshot evidence",
        planned_rows,
    )
    @test blocked_row.status == "blocked"
    @test blocked_row.reason == "missing snapshot evidence"

    mktempdir() do directory
        mkpath(joinpath(directory, "src"))
        mkpath(joinpath(directory, "test"))
        write(joinpath(directory, "src", "widgets.jl"), "# test widget source\n")
        write(joinpath(directory, "test", "widget_evidence.jl"), "# widget evidence\n")
        evidence = "test/widget_evidence.jl:covered"

        malformed = joinpath(directory, "experimental_promotions.tsv")
        write(
            malformed,
            """
            name\tdecision\ttarget\treview_status\tnotes
            Broken\tunknown\tWicked.API.Broken\tproposed\tNeeds evidence.
            """,
        )
        try
            read_experimental_promotion_plan(malformed)
            @test false
        catch error
            @test error isa ErrorException
            @test occursin("invalid decision", sprint(showerror, error))
        end

        stable = joinpath(directory, "stable_api.tsv")
        write(stable, "StablePanel\tdatatype\n")
        compatibility = joinpath(directory, "experimental_api.tsv")
        write(compatibility, "ExperimentalPanel\tdatatype\n")
        promotion = joinpath(directory, "experimental_promotions_valid.tsv")
        write(
            promotion,
            """
            name\tdecision\ttarget\treview_status\tnotes
            ExperimentalPanel\tpromote\tWicked.API.ExperimentalPanel\taccepted\tEvidence complete.
            """,
        )
        coverage = joinpath(directory, "widget_coverage.tsv")
        write(
            coverage,
            """
            widget_type\tsource\tstateful\tzero_size\tminimal\tclipped\tresize\tstate_transition\tsnapshot\ttoolkit\tsemantics\tkeyboard\tpointer
            Wicked.ExperimentalPanel\tsrc/widgets.jl\tfalse\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\tn/a:stateless render contract\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)
            """,
        )
        rows = candidate_rows(;
            stable_path=stable,
            compatibility_path=compatibility,
            promotion_path=promotion,
            coverage_path=coverage,
            source_root=directory,
            state_factories=Set{String}(),
        )
        @test length(rows) == 1
        @test only(rows).widget == "ExperimentalPanel"
        @test only(rows).status == "candidate"

        missing_source_coverage = joinpath(directory, "missing_source_widget_coverage.tsv")
        write(
            missing_source_coverage,
            """
            widget_type\tsource\tstateful\tzero_size\tminimal\tclipped\tresize\tstate_transition\tsnapshot\ttoolkit\tsemantics\tkeyboard\tpointer
            Wicked.ExperimentalPanel\tsrc/missing.jl\tfalse\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\tn/a:stateless render contract\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)
            """,
        )
        missing_source_rows = candidate_rows(;
            stable_path=stable,
            compatibility_path=compatibility,
            promotion_path=promotion,
            coverage_path=missing_source_coverage,
            source_root=directory,
            state_factories=Set{String}(),
        )
        @test only(missing_source_rows).status == "blocked"
        @test occursin("missing widget source file", only(missing_source_rows).reason)

        escaping_source_coverage = joinpath(directory, "escaping_source_widget_coverage.tsv")
        write(
            escaping_source_coverage,
            """
            widget_type\tsource\tstateful\tzero_size\tminimal\tclipped\tresize\tstate_transition\tsnapshot\ttoolkit\tsemantics\tkeyboard\tpointer
            Wicked.ExperimentalPanel\t../outside.jl\tfalse\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\tn/a:stateless render contract\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)
            """,
        )
        escaping_source_rows = candidate_rows(;
            stable_path=stable,
            compatibility_path=compatibility,
            promotion_path=promotion,
            coverage_path=escaping_source_coverage,
            source_root=directory,
            state_factories=Set{String}(),
        )
        @test only(escaping_source_rows).status == "blocked"
        @test occursin("must stay inside the repository", only(escaping_source_rows).reason)

        write(joinpath(directory, "src", "widgets.txt"), "# not Julia source\n")
        non_julia_source_coverage = joinpath(directory, "non_julia_source_widget_coverage.tsv")
        write(
            non_julia_source_coverage,
            """
            widget_type\tsource\tstateful\tzero_size\tminimal\tclipped\tresize\tstate_transition\tsnapshot\ttoolkit\tsemantics\tkeyboard\tpointer
            Wicked.ExperimentalPanel\tsrc/widgets.txt\tfalse\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\tn/a:stateless render contract\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)
            """,
        )
        non_julia_source_rows = candidate_rows(;
            stable_path=stable,
            compatibility_path=compatibility,
            promotion_path=promotion,
            coverage_path=non_julia_source_coverage,
            source_root=directory,
            state_factories=Set{String}(),
        )
        @test only(non_julia_source_rows).status == "blocked"
        @test occursin("must point to a Julia source file", only(non_julia_source_rows).reason)

        proposed_promotion = joinpath(directory, "experimental_promotions_proposed.tsv")
        write(
            proposed_promotion,
            """
            name\tdecision\ttarget\treview_status\tnotes
            ExperimentalPanel\tpromote\tWicked.API.ExperimentalPanel\tproposed\tEvidence complete.
            """,
        )
        proposed_candidate_rows = candidate_rows(;
            stable_path=stable,
            compatibility_path=compatibility,
            promotion_path=proposed_promotion,
            coverage_path=coverage,
            source_root=directory,
            state_factories=Set{String}(),
        )
        @test only(proposed_candidate_rows).status == "blocked"
        @test occursin("must be accepted or completed", only(proposed_candidate_rows).reason)

        function_stable = joinpath(directory, "stable_api_function.tsv")
        write(function_stable, "StablePanel\tfunction\n")
        stable_coverage = joinpath(directory, "stable_widget_coverage.tsv")
        write(
            stable_coverage,
            """
            widget_type\tsource\tstateful\tzero_size\tminimal\tclipped\tresize\tstate_transition\tsnapshot\ttoolkit\tsemantics\tkeyboard\tpointer
            Wicked.StablePanel\tsrc/widgets.jl\tfalse\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\tn/a:stateless render contract\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)
            """,
        )
        function_rows = candidate_rows(;
            stable_path=function_stable,
            compatibility_path=compatibility,
            promotion_path=promotion,
            coverage_path=stable_coverage,
            source_root=directory,
            state_factories=Set{String}(),
        )
        @test only(function_rows).status == "blocked"
        @test occursin("stable widget must be a concrete or parameterized Wicked.API type binding", only(function_rows).reason)

        generic_evidence_coverage = joinpath(directory, "generic_evidence_widget_coverage.tsv")
        write(
            generic_evidence_coverage,
            """
            widget_type\tsource\tstateful\tzero_size\tminimal\tclipped\tresize\tstate_transition\tsnapshot\ttoolkit\tsemantics\tkeyboard\tpointer
            Wicked.ExperimentalPanel\tsrc/widgets.jl\tfalse\tok\t$(evidence)\t$(evidence)\t$(evidence)\tn/a:stateless render contract\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)
            """,
        )
        generic_evidence_rows = candidate_rows(;
            stable_path=stable,
            compatibility_path=compatibility,
            promotion_path=promotion,
            coverage_path=generic_evidence_coverage,
            source_root=directory,
            state_factories=Set{String}(),
        )
        @test only(generic_evidence_rows).status == "blocked"
        @test occursin("must cite a checked-in Julia source file", only(generic_evidence_rows).reason)

        short_nonapplicable_coverage = joinpath(directory, "short_nonapplicable_widget_coverage.tsv")
        write(
            short_nonapplicable_coverage,
            """
            widget_type\tsource\tstateful\tzero_size\tminimal\tclipped\tresize\tstate_transition\tsnapshot\ttoolkit\tsemantics\tkeyboard\tpointer
            Wicked.ExperimentalPanel\tsrc/widgets.jl\tfalse\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\tn/a:x\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)\t$(evidence)
            """,
        )
        short_nonapplicable_rows = candidate_rows(;
            stable_path=stable,
            compatibility_path=compatibility,
            promotion_path=promotion,
            coverage_path=short_nonapplicable_coverage,
            source_root=directory,
            state_factories=Set{String}(),
        )
        @test only(short_nonapplicable_rows).status == "blocked"
        @test occursin("non-applicable evidence reason is too short", only(short_nonapplicable_rows).reason)
    end
end
