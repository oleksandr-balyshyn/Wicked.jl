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
        @test any(failure -> occursin("missing required case `hello-basic`", failure), failures)
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
        @test any(failure -> occursin("duplicates fixture case `ack-basic`", failure), failures)
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
        @test any(failure -> occursin("ack-basic packet kind expected 3, got 4", failure), failures)
        @test any(failure -> occursin("unknown remote protocol fixture case `unknown-case`", failure), failures)
    end

    help_status, help_text = mktemp() do _, help_output
        status = redirect_stdout(help_output) do
            RemoteProtocolFixtureAudit.main(["--help"])
        end
        flush(help_output)
        seekstart(help_output)
        return status, read(help_output, String)
    end
    @test help_status == 0
    @test occursin("protocol-v1 remote packet envelope fixtures", help_text)
end
