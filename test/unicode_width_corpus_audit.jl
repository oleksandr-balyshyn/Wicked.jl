include(joinpath(@__DIR__, "..", "scripts", "unicode_width_corpus_audit.jl"))

@testset "Unicode width corpus audit" begin
    @test isempty(UnicodeWidthCorpusAudit.audit())
    @test UnicodeWidthCorpusAudit.decode_escaped("A\\u754c") == "A界"
    @test UnicodeWidthCorpusAudit.decode_escaped("\\U0001f469\\u200d\\U0001f4bb") == "👩‍💻"

    mktempdir() do directory
        corpus = joinpath(directory, "unicode_width_corpus.tsv")
        write(
            corpus,
            join(
                [
                    "case\tescaped\texpected_graphemes\texpected_default_width\texpected_ambiguous_width\tnotes",
                    "ascii-letter\tA\t1\t1\t1\tBaseline single-column ASCII.",
                ],
                "\n",
            ),
        )
        failures = UnicodeWidthCorpusAudit.audit(corpus)
        @test any(value -> occursin("missing required case `cjk-wide`", value), failures)
    end

    mktempdir() do directory
        corpus = joinpath(directory, "unicode_width_corpus.tsv")
        write(
            corpus,
            join(
                [
                    "case\tescaped\texpected_graphemes\texpected_default_width\texpected_ambiguous_width\tnotes",
                    "ascii-letter\tA\t1\t2\t1\tBaseline single-column ASCII.",
                    "ascii-letter\tB\t1\t1\t1\tDuplicate case.",
                ],
                "\n",
            ),
        )
        failures = UnicodeWidthCorpusAudit.audit(corpus)
        @test any(value -> occursin("duplicates case `ascii-letter`", value), failures)
    end

    mktempdir() do directory
        corpus = joinpath(directory, "unicode_width_corpus.tsv")
        write(
            corpus,
            join(
                [
                    "case\tescaped\texpected_graphemes\texpected_default_width\texpected_ambiguous_width\tnotes",
                    "ascii-letter\tA\t1\t2\t1\tBaseline single-column ASCII.",
                    "bad-escape\t\\x\t1\t1\t1\tUnsupported escape.",
                ],
                "\n",
            ),
        )
        failures = UnicodeWidthCorpusAudit.audit(corpus)
        @test any(value -> occursin("ascii-letter default text width expected 2, got 1", value), failures)
        @test any(value -> occursin("bad-escape has invalid escaped value", value), failures)
    end

    help_output = IOBuffer()
    help_status = redirect_stdout(help_output) do
        UnicodeWidthCorpusAudit.main(["--help"])
    end
    @test help_status == 0
    @test occursin("Unicode grapheme and terminal-width corpus", String(take!(help_output)))
end
