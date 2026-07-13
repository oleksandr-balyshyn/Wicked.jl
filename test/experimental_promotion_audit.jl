include(joinpath(@__DIR__, "..", "scripts", "experimental_promotion_audit.jl"))

@testset "experimental promotion audit" begin
    default_failures, default_rows, default_exports = ExperimentalPromotionAudit.audit()
    @test isempty(default_failures)
    @test isempty(default_rows)
    @test isempty(default_exports)

    default_output = IOBuffer()
    default_status = redirect_stdout(default_output) do
        ExperimentalPromotionAudit.main(String[])
    end
    @test default_status == 0
    @test occursin("experimental promotion audit:", String(take!(default_output)))

    mktempdir() do directory
        completed = joinpath(directory, "completed.tsv")
        write(
            completed,
            """
            name\tdecision\ttarget\treview_status\tnotes
            LegacyWidget\tremove\t1.0 cleanup\tcompleted\tRemoved before stable release.
            """,
        )
        completed_failures, completed_rows, _ = ExperimentalPromotionAudit.audit(completed)
        @test isempty(completed_failures)
        @test haskey(completed_rows, "LegacyWidget")
        @test completed_rows["LegacyWidget"].decision == "remove"

        proposed_stale = joinpath(directory, "proposed-stale.tsv")
        write(
            proposed_stale,
            """
            name\tdecision\ttarget\treview_status\tnotes
            ProposedWidget\tpromote\tWicked.API.ProposedWidget\tproposed\tWaiting for evidence.
            """,
        )
        stale_failures, _, _ = ExperimentalPromotionAudit.audit(proposed_stale)
        @test any(failure -> occursin("mark the row completed", failure), stale_failures)

        malformed = joinpath(directory, "malformed.tsv")
        write(
            malformed,
            """
            name\tdecision\ttarget\treview_status\tnotes
            Broken\tunknown\t\tqueued\t
            Broken\tpromote\tWicked.API.Broken\tproposed\tNeeds render evidence.
            """,
        )
        _, malformed_failures = ExperimentalPromotionAudit.read_rows(malformed)
        @test any(failure -> occursin("invalid decision", failure), malformed_failures)
        @test any(failure -> occursin("invalid review status", failure), malformed_failures)
        @test any(failure -> occursin("must name a target", failure), malformed_failures)
        @test any(failure -> occursin("must explain", failure), malformed_failures)
        @test any(failure -> occursin("duplicates experimental binding", failure), malformed_failures)

        invalid_status = redirect_stderr(IOBuffer()) do
            ExperimentalPromotionAudit.main([malformed])
        end
        @test invalid_status == 1
        bad_arguments_status = redirect_stderr(IOBuffer()) do
            ExperimentalPromotionAudit.main([completed, malformed])
        end
        @test bad_arguments_status == 2
    end
end
