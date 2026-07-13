include(joinpath(@__DIR__, "..", "scripts", "compatibility_widget_alias_audit.jl"))

@testset "compatibility widget alias audit" begin
    mktempdir() do directory
        source_root = joinpath(directory, "src")
        mkpath(source_root)
        write(
            joinpath(source_root, "aliases.jl"),
            """
            module AliasFixtures

            const Panel = Card
            const InternalAlias = Internal.Target
            const lower_alias = Card

            struct FirstClassPanel
            end

            end
            """,
        )
        write(
            joinpath(source_root, "other.txt"),
            """
            const Panel = Card
            """,
        )
        aliases = CompatibilityWidgetAliasAudit.find_widget_aliases(
            Set(["Panel"]);
            source_root,
        )
        @test length(aliases) == 1
        @test only(aliases).path == "aliases.jl"
        @test only(aliases).widget == "Panel"
        @test only(aliases).target == "Card"

        internal_aliases = CompatibilityWidgetAliasAudit.find_widget_aliases(
            Set(["InternalAlias"]);
            source_root,
        )
        @test length(internal_aliases) == 1
        @test only(internal_aliases).target == "Internal.Target"

        @test isempty(
            CompatibilityWidgetAliasAudit.find_widget_aliases(
                Set(["FirstClassPanel"]);
                source_root,
            ),
        )
    end
end
