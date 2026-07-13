include(joinpath(@__DIR__, "..", "scripts", "example_family_audit.jl"))

@testset "example family audit" begin
    mktempdir() do root
        examples = joinpath(root, "examples")
        mkpath(examples)
        write(joinpath(examples, "README.md"), "- `one.jl`\n")
        write(joinpath(examples, "one.jl"), "using Wicked.API\n")

        required = (("One", "one.jl"),)
        @test isempty(ExampleFamilyAudit.audit(root; required))

        missing_file = (("One", "one.jl"), ("Two", "two.jl"))
        failures = ExampleFamilyAudit.audit(root; required=missing_file)
        @test any(failure -> occursin("Two example is missing", failure), failures)
        @test any(failure -> occursin("Two example is not listed", failure), failures)

        write(joinpath(examples, "two.jl"), "using Wicked.API\n")
        failures = ExampleFamilyAudit.audit(root; required=missing_file)
        @test any(failure -> occursin("Two example is not listed", failure), failures)

        write(joinpath(examples, "README.md"), "- `one.jl`\n- `two.jl`\n")
        @test isempty(ExampleFamilyAudit.audit(root; required=missing_file))
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        ExampleFamilyAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("required public quickstart family", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        ExampleFamilyAudit.main(["--unknown"])
    end
    @test bad_status == 2
end
