include(joinpath(@__DIR__, "..", "scripts", "widget_promotion_requirements_audit.jl"))

@testset "widget promotion requirements audit" begin
    default_failures, default_rows = WidgetPromotionRequirementsAudit.audit()
    @test isempty(default_failures)
    @test !isempty(default_rows)
    @test haskey(default_rows, "api-public-shape")
    @test default_rows["api-public-shape"].area == "api"
    @test default_rows["api-public-shape"].release_required == "yes"

    default_output = IOBuffer()
    default_status = redirect_stdout(default_output) do
        WidgetPromotionRequirementsAudit.main(String[])
    end
    @test default_status == 0
    @test occursin("widget promotion requirements audit:", String(take!(default_output)))

    mktempdir() do directory
        valid = joinpath(directory, "valid.tsv")
        write(
            valid,
            """
            id\tarea\trequirement\tevidence\tgate\trelease_required
            api-shape\tapi\tReview public API shape.\tAPI docs.\tscripts/api_audit.jl\tyes
            behavior-render\tbehavior\tCover rendering behavior.\tCoverage ledger.\tscripts/widget_audit.jl\tyes
            docs-guide\tdocs\tWrite developer docs.\tDocs.\tscripts/documentation_evidence_audit.jl\tyes
            examples-copyable\texamples\tProvide copyable examples.\tExamples.\tscripts/public_examples_audit.jl\tyes
            semantics-output\tsemantics\tExpose semantic output.\tSemantic evidence.\tscripts/semantic_accessibility_evidence_audit.jl\tyes
            toolkit-compose\ttoolkit\tCover Toolkit composition.\tToolkit evidence.\tscripts/widget_family_evidence_audit.jl\tyes
            performance-startup\tperformance\tCover startup paths.\tPrecompile evidence.\tscripts/loading_evidence_audit.jl\tyes
            release-closeout\trelease\tClose release blockers.\tRelease evidence.\tscripts/render_widget_family_closeout.jl --release-check\tyes
            """,
        )
        valid_failures, valid_rows = WidgetPromotionRequirementsAudit.audit(valid)
        @test isempty(valid_failures)
        @test length(valid_rows) == 8

        malformed = joinpath(directory, "malformed.tsv")
        write(
            malformed,
            """
            id\tarea\trequirement\tevidence\tgate\trelease_required
            Bad Id\tunknown\t\t\t\tmaybe
            Bad Id\tapi\tReview duplicate.\tEvidence.\tGate.\tyes
            """,
        )
        _, malformed_failures = WidgetPromotionRequirementsAudit.read_rows(malformed)
        @test any(failure -> occursin("invalid requirement id", failure), malformed_failures)
        @test any(failure -> occursin("invalid area", failure), malformed_failures)
        @test any(failure -> occursin("empty requirement", failure), malformed_failures)
        @test any(failure -> occursin("empty evidence", failure), malformed_failures)
        @test any(failure -> occursin("empty gate", failure), malformed_failures)
        @test any(failure -> occursin("invalid release_required", failure), malformed_failures)
        @test any(failure -> occursin("duplicates widget promotion requirement", failure), malformed_failures)

        missing_gate = joinpath(directory, "missing-gate.tsv")
        write(
            missing_gate,
            """
            id\tarea\trequirement\tevidence\tgate\trelease_required
            api-shape\tapi\tReview public API shape.\tAPI docs.\tscripts/missing_widget_gate.jl\tyes
            behavior-render\tbehavior\tCover rendering behavior.\tCoverage ledger.\tscripts/widget_audit.jl\tyes
            docs-guide\tdocs\tWrite developer docs.\tDocs.\tscripts/documentation_evidence_audit.jl\tyes
            examples-copyable\texamples\tProvide copyable examples.\tExamples.\tscripts/public_examples_audit.jl\tyes
            semantics-output\tsemantics\tExpose semantic output.\tSemantic evidence.\tscripts/semantic_accessibility_evidence_audit.jl\tyes
            toolkit-compose\ttoolkit\tCover Toolkit composition.\tToolkit evidence.\tscripts/widget_family_evidence_audit.jl\tyes
            performance-startup\tperformance\tCover startup paths.\tPrecompile evidence.\tscripts/loading_evidence_audit.jl\tyes
            release-closeout\trelease\tClose release blockers.\tRelease evidence.\tscripts/render_widget_family_closeout.jl --release-check\tyes
            """,
        )
        missing_gate_failures, _ = WidgetPromotionRequirementsAudit.audit(missing_gate)
        @test any(failure -> occursin("references missing gate script", failure), missing_gate_failures)

        vague_gate = joinpath(directory, "vague-gate.tsv")
        write(
            vague_gate,
            """
            id\tarea\trequirement\tevidence\tgate\trelease_required
            api-shape\tapi\tReview public API shape.\tAPI docs.\tmanual review\tyes
            behavior-render\tbehavior\tCover rendering behavior.\tCoverage ledger.\tscripts/widget_audit.jl\tyes
            docs-guide\tdocs\tWrite developer docs.\tDocs.\tscripts/documentation_evidence_audit.jl\tyes
            examples-copyable\texamples\tProvide copyable examples.\tExamples.\tscripts/public_examples_audit.jl\tyes
            semantics-output\tsemantics\tExpose semantic output.\tSemantic evidence.\tscripts/semantic_accessibility_evidence_audit.jl\tyes
            toolkit-compose\ttoolkit\tCover Toolkit composition.\tToolkit evidence.\tscripts/widget_family_evidence_audit.jl\tyes
            performance-startup\tperformance\tCover startup paths.\tPrecompile evidence.\tscripts/loading_evidence_audit.jl\tyes
            release-closeout\trelease\tClose release blockers.\tRelease evidence.\tscripts/render_widget_family_closeout.jl --release-check\tyes
            """,
        )
        vague_gate_failures, _ = WidgetPromotionRequirementsAudit.audit(vague_gate)
        @test any(failure -> occursin("gate must reference at least one scripts/*.jl command", failure), vague_gate_failures)

        incomplete = joinpath(directory, "incomplete.tsv")
        write(
            incomplete,
            """
            id\tarea\trequirement\tevidence\tgate\trelease_required
            api-shape\tapi\tReview public API shape.\tAPI docs.\tscripts/api_audit.jl\tyes
            """,
        )
        incomplete_failures, _ = WidgetPromotionRequirementsAudit.audit(incomplete)
        @test any(failure -> occursin("no release-required widget promotion requirement", failure), incomplete_failures)

        invalid_status = redirect_stderr(IOBuffer()) do
            WidgetPromotionRequirementsAudit.main([malformed])
        end
        @test invalid_status == 1
        bad_arguments_status = redirect_stderr(IOBuffer()) do
            WidgetPromotionRequirementsAudit.main([valid, malformed])
        end
        @test bad_arguments_status == 2
    end
end
