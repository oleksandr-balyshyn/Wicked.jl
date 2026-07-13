include(joinpath(@__DIR__, "..", "scripts", "public_examples_audit.jl"))

@testset "public examples audit" begin
    mktempdir() do root
        examples = joinpath(root, "examples")
        mkpath(examples)

        valid = joinpath(examples, "valid.jl")
        write(valid, "using Wicked.API\nbuffer = Buffer(1, 1)\n@assert buffer isa Buffer\n")
        @test isempty(PublicExamplesAudit.audit(root))

        missing_api = joinpath(examples, "missing_api.jl")
        write(missing_api, "buffer = nothing\n@assert buffer === nothing\n")
        failures = PublicExamplesAudit.audit(root)
        @test any(failure -> occursin("missing_api.jl must import Wicked.API", failure), failures)
        rm(missing_api)

        missing_assertion = joinpath(examples, "missing_assertion.jl")
        write(missing_assertion, "using Wicked.API\nbuffer = Buffer(1, 1)\n")
        failures = PublicExamplesAudit.audit(root)
        @test any(failure -> occursin("missing_assertion.jl must assert at least one behavior", failure), failures)
        rm(missing_assertion)

        root_import = joinpath(examples, "root_import.jl")
        write(root_import, "import Wicked\nusing Wicked.API\n@assert true\n")
        failures = PublicExamplesAudit.audit(root)
        @test any(failure -> occursin("imports the root Wicked module", failure), failures)
        rm(root_import)

        internal_import = joinpath(examples, "internal_import.jl")
        write(internal_import, "using Wicked.API\nusing Wicked.Toolkit\n@assert true\n")
        failures = PublicExamplesAudit.audit(root)
        @test any(failure -> occursin("imports an internal Wicked subsystem", failure), failures)
        rm(internal_import)

        internal_reference = joinpath(examples, "internal_reference.jl")
        write(internal_reference, "using Wicked.API\nvalue = Wicked.Experimental\n@assert value !== nothing\n")
        failures = PublicExamplesAudit.audit(root)
        @test any(failure -> occursin("references an internal Wicked subsystem", failure), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        PublicExamplesAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("runnable examples import Wicked.API", String(take!(help_output)))

    bad_status = redirect_stderr(IOBuffer()) do
        PublicExamplesAudit.main(["--unknown"])
    end
    @test bad_status == 2
end
