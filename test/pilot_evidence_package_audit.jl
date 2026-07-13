include(joinpath(@__DIR__, "..", "scripts", "pilot_evidence_package_audit.jl"))

@testset "pilot evidence package audit" begin
    pilot = ToolkitPilot(
        Element(Button("Audit"); id=:audit, focusable=true);
        height=3,
        width=12,
    )
    evidence = pilot_evidence_bundle(pilot)

    mktempdir() do directory
        package_dir = joinpath(directory, "package")
        reports_dir = joinpath(directory, "package-reports")

        write_pilot_evidence_package(package_dir, evidence)
        write_pilot_evidence_package_reports(reports_dir, package_dir)

        @test isempty(PilotEvidencePackageAudit.audit([package_dir], String[], PilotEvidencePackageAudit.AuditOptions(false, false, false, false, false)))
        @test isempty(PilotEvidencePackageAudit.audit([package_dir], [reports_dir], PilotEvidencePackageAudit.AuditOptions(false, false, false, false, false)))
    end

    mktempdir() do directory
        options = PilotEvidencePackageAudit.AuditOptions(false, false, false, false, true)
        failures = PilotEvidencePackageAudit.audit(String[], String[], options)
        @test any(occursin("requires at least one package artifact"), failures)
    end

    mktempdir() do directory
        package_dir = joinpath(directory, "package")
        write_pilot_evidence_package(package_dir, evidence)
        write(joinpath(package_dir, "unexpected.txt"), "extra")

        strict = PilotEvidencePackageAudit.audit([package_dir], String[], PilotEvidencePackageAudit.AuditOptions(false, false, false, false, false))
        @test any(occursin("package failed"), strict)
        relaxed = PilotEvidencePackageAudit.audit([package_dir], String[], PilotEvidencePackageAudit.AuditOptions(true, true, true, true, false))
        @test isempty(relaxed)
    end

    mktempdir() do directory
        package_dir = joinpath(directory, "package")
        reports_dir = joinpath(directory, "package-reports")
        write_pilot_evidence_package(package_dir, evidence)
        write_pilot_evidence_package_reports(reports_dir, package_dir)
        write(joinpath(reports_dir, "package-summary.txt"), "corrupt")

        failures = PilotEvidencePackageAudit.audit([package_dir], [reports_dir], PilotEvidencePackageAudit.AuditOptions(false, false, false, false, false))
        @test any(occursin("package reports failed"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        PilotEvidencePackageAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("WidgetPilot or ToolkitPilot evidence artifacts", String(take!(help_output)))

    bad_output = IOBuffer()
    bad_status = redirect_stderr(bad_output) do
        PilotEvidencePackageAudit.main(["--package-report-dir"])
    end
    @test bad_status == 2
    @test occursin("--package-report-dir requires a directory argument", String(take!(bad_output)))
end
