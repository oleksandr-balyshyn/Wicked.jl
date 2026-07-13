include(joinpath(@__DIR__, "..", "scripts", "widget_family_evidence_audit.jl"))

@testset "widget family evidence audit" begin
    @test isempty(WidgetFamilyEvidenceAudit.audit())
    @test WidgetFamilyEvidenceAudit.inside_root(joinpath(WidgetFamilyEvidenceAudit.ROOT, "docs", "API_WIDGETS.md"))
    @test !WidgetFamilyEvidenceAudit.inside_root(
        normpath(joinpath(WidgetFamilyEvidenceAudit.ROOT, "..", basename(WidgetFamilyEvidenceAudit.ROOT) * "-outside.md")),
    )
    @test WidgetFamilyEvidenceAudit.regex_escape_literal("Token+") == "Token\\+"
    @test WidgetFamilyEvidenceAudit.source_mentions_token("Use `Token+` exactly.", "Token+")
    @test !WidgetFamilyEvidenceAudit.source_mentions_token("TableView only", "Table")
    @test !WidgetFamilyEvidenceAudit.source_mentions_token("Widgets.ColumnView only", "Widgets.Column")
    @test !WidgetFamilyEvidenceAudit.source_mentions_token("OtherWidgets.Column only", "Widgets.Column")
    @test !WidgetFamilyEvidenceAudit.source_mentions_token("pulse_services!x only", "pulse_services!")
    @test WidgetFamilyEvidenceAudit.source_mentions_token("call pulse_services! now", "pulse_services!")
    @test WidgetFamilyEvidenceAudit.precompile_token_represents_stable_token("Widgets.Column", "Column")
    @test WidgetFamilyEvidenceAudit.precompile_token_represents_stable_token("Column", "Column")
    @test !WidgetFamilyEvidenceAudit.precompile_token_represents_stable_token("Widgets.ColumnView", "Column")

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tColumn\tWidgets.Column\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("missing widget family evidence row for `Toolkit`"), failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/MISSING.md\texamples/layout_quickstart.jl\tLayout composition\tColumn\tWidgets.Column\tCovered for Core layout.",
                    "Text and structure\tdocs/API_WIDGETS.md\texamples/MISSING.jl\tText and structure\tLabel\tWidgets.Label\tCovered for Text and structure.",
                    "Inputs and controls\tdocs/API_CONTROLS.md\texamples/controls_quickstart.jl\tControls and forms\tButton\tMissingToken\tCovered for Inputs and controls.",
                    "Navigation\tdocs/API_NAVIGATION.md\texamples/navigation_quickstart.jl\tNavigation surfaces\tTabbedContentView\tTabbedContentView\tCovered for Navigation.",
                    "Data and virtualization\tdocs/API_VIRTUALIZATION.md\texamples/data_display_quickstart.jl\tData display\tDataTable\tDataTable\tCovered for Data and virtualization.",
                    "Visualization\tdocs/API_WIDGETS.md\texamples/visualization_quickstart.jl\tVisualization\tGauge\tGauge\tCovered for Visualization.",
                    "Rich content\tdocs/API_RICH_CONTENT.md\texamples/rich_content_quickstart.jl\tRich content\tMarkdownView\tMarkdownView\tCovered for Rich content.",
                    "Runtime and services\tdocs/API_EXTENSIONS_SERVICES.md\texamples/services_quickstart.jl\tServices\tProgress\tProgress\tCovered for Runtime and services.",
                    "Toolkit\tdocs/API_TOOLKIT.md\texamples/toolkit_quickstart.jl\tToolkit\tToolkitTree\tToolkit.ToolkitTree\tCovered for Toolkit.",
                    "Testing and semantics\tdocs/API_SEMANTICS_TESTING.md\texamples/testing_quickstart.jl\tTesting and semantics\tWidgetPilot\tSemanticToolkit.toolkit_semantic_tree\tCovered for Testing and semantics.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("references missing documentation path `docs/MISSING.md`"), failures)
        @test any(occursin("references missing example path `examples/MISSING.jl`"), failures)
        @test any(occursin("precompile token `MissingToken` is missing"), failures)
    end

    mktempdir() do directory
        examples_index = joinpath(directory, "README.md")
        write(examples_index, "examples/layout_quickstart.jl\n")
        failures = WidgetFamilyEvidenceAudit.audit(; examples_index_source=examples_index)
        @test any(occursin("example path `examples/testing_quickstart.jl` is not listed in examples/README.md"), failures)
    end

    mktempdir() do directory
        example_families = joinpath(directory, "EXAMPLE_FAMILIES.md")
        write(example_families, "examples/layout_quickstart.jl\n")
        failures = WidgetFamilyEvidenceAudit.audit(; example_families_source=example_families)
        @test any(occursin("example path `examples/testing_quickstart.jl` is not listed in docs/EXAMPLE_FAMILIES.md"), failures)
    end

    mktempdir() do directory
        docs_index = joinpath(directory, "README.md")
        write(docs_index, "API_WIDGETS.md\n")
        failures = WidgetFamilyEvidenceAudit.audit(; docs_index_source=docs_index)
        @test any(occursin("documentation path `docs/API_TOOLKIT.md` is not listed in docs/README.md"), failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tColumn\tWidgets.Column\tGeneric coverage.",
                    "Text and structure\tdocs/API_WIDGETS.md\texamples/text_quickstart.jl\tText and structure\tLabel\tWidgets.Label\tCovered for Text and structure.",
                    "Inputs and controls\tdocs/API_CONTROLS.md\texamples/controls_quickstart.jl\tControls and forms\tButton\tWidgets.Button\tCovered for Inputs and controls.",
                    "Navigation\tdocs/API_NAVIGATION.md\texamples/navigation_quickstart.jl\tNavigation surfaces\tTabbedContentView\tTabbedContentView\tCovered for Navigation.",
                    "Data and virtualization\tdocs/API_VIRTUALIZATION.md\texamples/data_display_quickstart.jl\tData display\tDataTable\tDataTable\tCovered for Data and virtualization.",
                    "Visualization\tdocs/API_WIDGETS.md\texamples/visualization_quickstart.jl\tVisualization\tGauge\tGauge\tCovered for Visualization.",
                    "Rich content\tdocs/API_RICH_CONTENT.md\texamples/rich_content_quickstart.jl\tRich content\tMarkdownView\tMarkdownView\tCovered for Rich content.",
                    "Runtime and services\tdocs/API_EXTENSIONS_SERVICES.md\texamples/services_quickstart.jl\tServices\tProgress\tProgress\tCovered for Runtime and services.",
                    "Toolkit\tdocs/API_TOOLKIT.md\texamples/toolkit_quickstart.jl\tToolkit\tToolkitTree\tToolkit.ToolkitTree\tCovered for Toolkit.",
                    "Testing and semantics\tdocs/API_SEMANTICS_TESTING.md\texamples/testing_quickstart.jl\tTesting and semantics\tWidgetPilot\tSemanticToolkit.toolkit_semantic_tree\tCovered for Testing and semantics.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("Core layout stabilization notes must mention the family name"), failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tWrong label\tColumn\tWidgets.Column\tCovered for Core layout.",
                    "Text and structure\tdocs/API_WIDGETS.md\texamples/text_quickstart.jl\tText and structure\tLabel\tWidgets.Label\tCovered for Text and structure.",
                    "Inputs and controls\tdocs/API_CONTROLS.md\texamples/controls_quickstart.jl\tControls and forms\tButton\tWidgets.Button\tCovered for Inputs and controls.",
                    "Navigation\tdocs/API_NAVIGATION.md\texamples/navigation_quickstart.jl\tNavigation surfaces\tTabbedContentView\tTabbedContentView\tCovered for Navigation.",
                    "Data and virtualization\tdocs/API_VIRTUALIZATION.md\texamples/data_display_quickstart.jl\tData display\tDataTable\tDataTable\tCovered for Data and virtualization.",
                    "Visualization\tdocs/API_WIDGETS.md\texamples/visualization_quickstart.jl\tVisualization\tGauge\tGauge\tCovered for Visualization.",
                    "Rich content\tdocs/API_RICH_CONTENT.md\texamples/rich_content_quickstart.jl\tRich content\tMarkdownView\tMarkdownView\tCovered for Rich content.",
                    "Runtime and services\tdocs/API_EXTENSIONS_SERVICES.md\texamples/services_quickstart.jl\tServices\tProgress\tProgress\tCovered for Runtime and services.",
                    "Toolkit\tdocs/API_TOOLKIT.md\texamples/toolkit_quickstart.jl\tToolkit\tToolkitTree\tToolkit.ToolkitTree\tCovered for Toolkit.",
                    "Testing and semantics\tdocs/API_SEMANTICS_TESTING.md\texamples/testing_quickstart.jl\tTesting and semantics\tWidgetPilot\tSemanticToolkit.toolkit_semantic_tree\tCovered for Testing and semantics.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("example path `examples/layout_quickstart.jl` is mapped to `Layout composition`; expected `Wrong label`"), failures)
    end

    mktempdir() do directory
        stable = joinpath(directory, "stable_api.tsv")
        write(stable, "Column\tdatatype\n")
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tMissingPublicToken\tWidgets.Column\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger; stable_api_path=stable)
        @test any(occursin("stable API token `MissingPublicToken` is missing from api/stable_api.tsv"), failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_EXTENSIONS_SERVICES.md\texamples/layout_quickstart.jl\tLayout composition\tColumn\tWidgets.Column\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("stable API token `Column` is not mentioned in focused documentation"), failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_RICH_CONTENT.md\texamples/layout_quickstart.jl\tLayout composition\tMarkdownView\tWidgets.Column\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("stable API token `MarkdownView` is not demonstrated in public examples"), failures)
    end

    mktempdir() do directory
        synthetic_doc = joinpath(WidgetFamilyEvidenceAudit.ROOT, "docs", "synthetic_widget_family_token.md")
        write(synthetic_doc, "The documented token is TableView only.\n")
        try
            ledger = joinpath(directory, "widget_family_evidence.tsv")
            write(
                ledger,
                join(
                    [
                        "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                        "Data and virtualization\tdocs/synthetic_widget_family_token.md\texamples/data_display_quickstart.jl\tData display\tTable\tDataTable\tCovered for Data and virtualization.",
                    ],
                    "\n",
                ),
            )
            failures = WidgetFamilyEvidenceAudit.audit(ledger)
            @test any(occursin("stable API token `Table` is not mentioned in focused documentation", failure) for failure in failures)
        finally
            isfile(synthetic_doc) && rm(synthetic_doc)
        end
    end

    mktempdir() do directory
        synthetic_doc = joinpath(WidgetFamilyEvidenceAudit.ROOT, "docs", "synthetic_regex_token.md")
        write(synthetic_doc, "Use `Token+` exactly as documented.\n")
        stable = joinpath(directory, "stable_api.tsv")
        write(stable, "Token+\tdatatype\n")
        try
            ledger = joinpath(directory, "widget_family_evidence.tsv")
            write(
                ledger,
                join(
                    [
                        "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                        "Core layout\tdocs/synthetic_regex_token.md\texamples/layout_quickstart.jl\tLayout composition\tToken+\tWidgets.Column\tCovered for Core layout.",
                    ],
                    "\n",
                ),
            )
            failures = WidgetFamilyEvidenceAudit.audit(ledger; stable_api_path=stable)
            @test !any(occursin("stable API token `Token+` is not mentioned in focused documentation", failure) for failure in failures)
        finally
            isfile(synthetic_doc) && rm(synthetic_doc)
        end
    end

    mktempdir() do directory
        precompile_source = joinpath(directory, "Precompile.jl")
        write(precompile_source, "Widgets.ColumnView only\n")
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tColumn\tWidgets.Column\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger; precompile_source=precompile_source)
        @test any(occursin("precompile token `Widgets.Column` is missing", failure) for failure in failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tColumn\tWidgets.Column\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("Core layout must list at least 3 representative stable API tokens", failure) for failure in failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tColumn,Column,Wrap\tWidgets.Column\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("Core layout has duplicate stable API tokens: Column", failure) for failure in failures)
    end

    mktempdir() do directory
        stable = joinpath(directory, "stable_api.tsv")
        write(
            stable,
            """
            Column\tdatatype
            has_inline_role\tfunction
            has_block_role\tfunction
            text_width\tfunction
            """,
        )
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tColumn,has_inline_role,has_block_role,text_width\tWidgets.Column,Wrap,Dock\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger; stable_api_path=stable)
        @test any(occursin("Core layout must list at least 3 representative stable API type tokens", failure) for failure in failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tColumn,Wrap,Box\tWidgets.Column,Widgets.Column,Wrap\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("Core layout has duplicate precompile tokens: Widgets.Column", failure) for failure in failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md,docs/API_WIDGETS.md\texamples/layout_quickstart.jl,examples/layout_quickstart.jl\tLayout composition,Layout composition\tColumn,Wrap,Box\tWidgets.Column,Wrap,Dock\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("Core layout has duplicate documentation paths: docs/API_WIDGETS.md", failure) for failure in failures)
        @test any(occursin("Core layout has duplicate public example paths: examples/layout_quickstart.jl", failure) for failure in failures)
        @test any(occursin("Core layout has duplicate example family labels: Layout composition", failure) for failure in failures)
    end

    mktempdir() do directory
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tColumn,Wrap,Box\tWidgets.Column\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger)
        @test any(occursin("Core layout must list at least 3 representative precompile tokens", failure) for failure in failures)
    end

    mktempdir() do directory
        stable = joinpath(directory, "stable_api.tsv")
        write(
            stable,
            """
            Column\tdatatype
            Wrap\tdatatype
            Box\tdatatype
            """,
        )
        ledger = joinpath(directory, "widget_family_evidence.tsv")
        write(
            ledger,
            join(
                [
                    "family\tdocs\texamples\texample_family_labels\tstable_api_tokens\tprecompile_tokens\tnotes",
                    "Core layout\tdocs/API_WIDGETS.md\texamples/layout_quickstart.jl\tLayout composition\tColumn,Wrap,Box\tWidgets.Column,Wrap,Dock\tCovered for Core layout.",
                ],
                "\n",
            ),
        )
        failures = WidgetFamilyEvidenceAudit.audit(ledger; stable_api_path=stable)
        @test any(occursin("Core layout stable API type token `Box` must have a matching precompile token", failure) for failure in failures)
    end
end
