module StablePromotionPacketScaffoldTest

using Test

include(joinpath(@__DIR__, "..", "scripts", "new_stable_promotion_packet.jl"))
using .StablePromotionPacketScaffold

@testset "stable promotion packet scaffold" begin
    @test StablePromotionPacketScaffold.validate_candidate("abcdef1") == "abcdef1"
    @test_throws ErrorException StablePromotionPacketScaffold.validate_candidate("not-a-sha")
    @test StablePromotionPacketScaffold.validate_decision("PROMOTE") == "promote"
    @test_throws ErrorException StablePromotionPacketScaffold.validate_decision("ship")
    @test StablePromotionPacketScaffold.packet_filename("Stateful Controls", "ComboBox", "ABCDEF1") == "stateful-controls-combobox-abcdef1.md"

    mktempdir() do directory
        packet = StablePromotionPacketScaffold.create_packet(
            Dict(
                "family" => "Stateful Controls",
                "widget" => "ComboBox",
                "source" => "src/AcceptanceWidgets.jl",
                "candidate" => "abcdef1234567890",
                "decision" => "promote",
                "reviewer" => "reviewer",
                "out-dir" => directory,
            ),
        )
        @test startswith(packet, directory)
        @test basename(packet) == "stateful-controls-combobox-abcdef1234567890.md"
        source = read(packet, String)
        @test occursin("| Widget family | Stateful Controls |", source)
        @test occursin("| Widget name | ComboBox |", source)
        @test occursin("| Source file | src/AcceptanceWidgets.jl |", source)
        @test occursin("| Release-candidate commit | abcdef1234567890 |", source)
        @test occursin("| Decision | promote |", source)
        @test occursin("- Stable exported name: Wicked.API.ComboBox", source)
        @test occursin("- Compatibility alias, deprecation, or removal decision: promote", source)
        @test occursin("api/widget_promotion_requirements.tsv", source)
        @test occursin("docs/pilot-evidence/stateful-controls-combobox-abcdef1234567890 via write_pilot_evidence_package", source)
        @test occursin("ci-artifacts/pilot-evidence-package-reports/stateful-controls-combobox-abcdef1234567890 via write_pilot_evidence_package_reports", source)
        @test !occursin("| Pilot evidence package checked by `scripts/pilot_evidence_package_audit.jl` | TODO |", source)

        @test StablePromotionPacketScaffold.main([
            "--family", "Input",
            "--widget", "TextInput",
            "--source", "src/widgets/input.jl",
            "--candidate", "abcdef2",
            "--decision", "qualify",
            "--out-dir", directory,
        ]) == 0
        @test isfile(joinpath(directory, "input-textinput-abcdef2.md"))
        @test StablePromotionPacketScaffold.main([
            "--family", "Input",
            "--widget", "TextInput",
            "--source", "src/widgets/input.jl",
            "--candidate", "bad",
            "--decision", "qualify",
            "--out-dir", directory,
        ]) == 1
    end
end

end
