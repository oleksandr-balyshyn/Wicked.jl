include(joinpath(@__DIR__, "..", "scripts", "remote_protocol_fixture_audit.jl"))

@testset "remote protocol fixture audit" begin
    @test isempty(RemoteProtocolFixtureAudit.audit())
    @test RemoteProtocolFixtureAudit.envelope(Wicked.API.encode_remote_message(Wicked.API.RemoteAck(UInt64(12)))).kind == 4

    mktempdir() do directory
        fixtures = joinpath(directory, "remote_protocol_fixtures.tsv")
        write(
            fixtures,
            join(
                [
                    "case\tmessage\tsequence\tkind\tflags\tminimum_payload_bytes\tnotes",
                    "ack-basic\tRemoteAck\t12\t4\t0\t0\tAcknowledgement has an empty payload.",
                ],
                "\n",
            ),
        )
        failures = RemoteProtocolFixtureAudit.audit(fixtures)
        @test any(occursin("missing required case `hello-basic`"), failures)
    end

    mktempdir() do directory
        fixtures = joinpath(directory, "remote_protocol_fixtures.tsv")
        write(
            fixtures,
            join(
                [
                    "case\tmessage\tsequence\tkind\tflags\tminimum_payload_bytes\tnotes",
                    "ack-basic\tRemoteAck\t12\t3\t0\t0\tAcknowledgement has an empty payload.",
                    "ack-basic\tRemoteAck\t12\t4\t0\t0\tDuplicate fixture.",
                ],
                "\n",
            ),
        )
        failures = RemoteProtocolFixtureAudit.audit(fixtures)
        @test any(occursin("duplicates fixture case `ack-basic`"), failures)
    end

    mktempdir() do directory
        fixtures = joinpath(directory, "remote_protocol_fixtures.tsv")
        write(
            fixtures,
            join(
                [
                    "case\tmessage\tsequence\tkind\tflags\tminimum_payload_bytes\tnotes",
                    "ack-basic\tRemoteAck\t12\t3\t0\t0\tAcknowledgement has an empty payload.",
                    "unknown-case\tRemoteAck\t13\t4\t0\t0\tUnknown fixture.",
                ],
                "\n",
            ),
        )
        failures = RemoteProtocolFixtureAudit.audit(fixtures)
        @test any(occursin("ack-basic packet kind expected 3, got 4"), failures)
        @test any(occursin("unknown remote protocol fixture case `unknown-case`"), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        RemoteProtocolFixtureAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("protocol-v1 remote packet envelope fixtures", String(take!(help_output)))
end
