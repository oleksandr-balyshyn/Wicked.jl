@testset "widget catalog" begin
    catalog = stable_widget_catalog()

    @test !isempty(catalog)
    @test all(entry -> entry isa WidgetCatalogEntry, catalog)
    @test issorted([String(entry.name) for entry in catalog])

    stable_entries = stable_widget_catalog(status=:stable, surface=:stable)
    @test !isempty(stable_entries)
    @test all(entry -> entry.status == :stable, stable_entries)
    @test all(entry -> entry.surface == :stable, stable_entries)
    @test widget_catalog(status="stable", surface="stable") == stable_entries
    @test stable_widget_count() == length(stable_entries)
    @test stable_widget_names() == [entry.name for entry in stable_entries]
    @test :Button in stable_widget_names()
    @test :Divider in stable_widget_names()
    @test :DataStateView in stable_widget_names()
    @test :KeyValueList in stable_widget_names()
    @test :MetadataList in stable_widget_names()
    @test :DefinitionList in stable_widget_names()
    @test widget_catalog_entry(:Divider).source == "src/widgets/structure.jl"
    @test widget_catalog_family(:Divider) == "Text and structure"
    @test widget_catalog_entry(:DataStateView).source == "src/DataWidgets.jl"
    @test widget_catalog_family(:DataStateView) == "Data and virtualization"
    @test widget_catalog_entry(:DefinitionList).source == "src/DataWidgets.jl"
    @test widget_catalog_family(:DefinitionList) == "Data and virtualization"
    @test widget_catalog_entry(:KeyValueList).source == "src/DataWidgets.jl"
    @test widget_catalog_family(:KeyValueList) == "Data and virtualization"
    @test widget_catalog_entry(:MetadataList).source == "src/DataWidgets.jl"
    @test widget_catalog_family(:MetadataList) == "Data and virtualization"
    families = stable_widget_families()
    @test issorted(families)
    @test "Inputs and controls" in families
    family_slugs = stable_widget_family_slugs()
    @test issorted(family_slugs)
    @test "inputs-and-controls" in family_slugs
    family_catalog = stable_widget_family_catalog()
    @test !isempty(family_catalog)
    @test all(entry -> entry isa WidgetFamilyEntry, family_catalog)
    @test issorted([entry.slug for entry in family_catalog])
    input_family_entry = widget_family_entry(:inputs_and_controls)
    @test input_family_entry isa WidgetFamilyEntry
    @test input_family_entry.name == "Inputs and controls"
    @test input_family_entry.slug == "inputs-and-controls"
    @test input_family_entry.count == length(input_family_entry.widgets)
    @test :Button in input_family_entry.widgets
    @test widget_family_entry("inputs-and-controls") == input_family_entry
    @test is_stable_widget_family(:inputs_and_controls)
    @test is_stable_widget_family("Inputs and controls")
    @test assert_stable_widget_family(:inputs_and_controls) == input_family_entry
    @test widget_family_entry(:definitely_missing_family) === nothing
    @test !is_stable_widget_family(:definitely_missing_family)
    @test_throws ArgumentError assert_stable_widget_family(:definitely_missing_family)
    family_records = widget_family_records()
    @test any(record -> record.name == "Inputs and controls" && record.slug == "inputs-and-controls" && :Button in record.widgets, family_records)
    family_catalog_markdown = widget_family_catalog_markdown()
    @test startswith(family_catalog_markdown, "| `family` | `family_slug` | `count` | `widgets` |")
    @test occursin("| Inputs and controls | inputs-and-controls |", family_catalog_markdown)
    @test startswith(widget_family_catalog_markdown(columns=(:family_slug, :count)), "| `family_slug` | `count` |")
    @test occursin("| inputs-and-controls |", widget_family_catalog_markdown(columns=:family_slug))
    family_catalog_tsv = widget_family_catalog_tsv()
    @test startswith(family_catalog_tsv, "family\tfamily_slug\tcount\twidgets\n")
    @test occursin("Inputs and controls\tinputs-and-controls\t", family_catalog_tsv)
    @test startswith(widget_family_catalog_tsv(columns=(:family_slug, :count)), "family_slug\tcount\n")
    @test startswith(widget_family_catalog_tsv(columns=:family_slug), "family_slug\n")
    @test !startswith(widget_family_catalog_tsv(header=false), "family\tfamily_slug\tcount\twidgets")
    @test length(stable_widget_family_catalog(family=:inputs_and_controls)) == 1
    @test only(stable_widget_family_catalog(family=:inputs_and_controls)).slug == "inputs-and-controls"
    @test length(widget_family_records(family=:inputs_and_controls)) == 1
    @test occursin("Inputs and controls", widget_family_catalog_markdown(family=:inputs_and_controls))
    @test occursin("Inputs and controls\tinputs-and-controls\t", widget_family_catalog_tsv(family=:inputs_and_controls))
    searched_families = search_widget_families("button")
    @test any(entry -> entry.slug == "inputs-and-controls", searched_families)
    @test any(entry -> entry.slug == "inputs-and-controls", search_widget_families(:button))
    @test any(entry -> entry.slug == "inputs-and-controls", search_widget_families(r"Button"))
    @test search_widget_family_count("button") == length(searched_families)
    searched_family_markdown = search_widget_family_catalog_markdown("button"; columns=(:family_slug, :count))
    @test startswith(searched_family_markdown, "| `family_slug` | `count` |")
    @test occursin("| inputs-and-controls |", searched_family_markdown)
    searched_family_tsv = search_widget_family_catalog_tsv("button"; columns=(:family_slug, :count))
    @test startswith(searched_family_tsv, "family_slug\tcount\n")
    @test occursin("inputs-and-controls\t", searched_family_tsv)
    input_family_widgets = widget_family_widgets(:inputs_and_controls)
    @test !isempty(input_family_widgets)
    @test all(entry -> widget_catalog_family(entry) == "Inputs and controls", input_family_widgets)
    @test :Button in widget_family_widget_names(:inputs_and_controls)
    @test widget_family_widget_count(:inputs_and_controls) == length(input_family_widgets)
    @test_throws ArgumentError widget_family_widgets(:definitely_missing_family)
    family_closeout_reports = widget_family_closeout_reports()
    @test !isempty(family_closeout_reports)
    @test all(report -> report isa WidgetFamilyCloseoutReport, family_closeout_reports)
    @test all(report -> report.status in (:ready, :blocked), family_closeout_reports)
    @test all(report -> report.ready == isempty(report.blockers), family_closeout_reports)
    toolkit_closeout = widget_family_closeout_report(:toolkit)
    @test toolkit_closeout.family == "Toolkit"
    @test toolkit_closeout.family_slug == "toolkit"
    @test widget_family_closeout_ready(:toolkit) == toolkit_closeout.ready
    @test widget_family_closeout_reports(family=:toolkit) == [toolkit_closeout]
    @test widget_family_closeout_reports(status=:ready) == [report for report in family_closeout_reports if report.ready]
    @test widget_family_closeout_reports(status=:blocked) == widget_family_closeout_gaps()
    closeout_summary = widget_family_closeout_summary()
    @test closeout_summary.total == length(family_closeout_reports)
    @test closeout_summary.ready + closeout_summary.blocked == closeout_summary.total
    @test widget_family_closeout_complete() == isempty(widget_family_closeout_gaps())
    @test widget_family_closeout_complete(family=:toolkit) == toolkit_closeout.ready
    closeout_records = widget_family_closeout_records()
    @test any(record -> record.family == "Toolkit" && record.family_slug == "toolkit", closeout_records)
    @test startswith(widget_family_closeout_markdown(columns=(:family, :status, :blockers)), "| `family` | `status` | `blockers` |")
    @test startswith(widget_family_closeout_tsv(columns=(:family, :status)), "family\tstatus\n")
    @test !startswith(widget_family_closeout_tsv(columns=(:family, :status), header=false), "family\tstatus")
    closeout_json = widget_family_closeout_json(status=:ready)
    @test occursin("\"schema_version\": 1", closeout_json)
    @test occursin("\"status\": \"ready\"", closeout_json)
    closeout_artifacts = widget_family_closeout_artifacts(columns=(:family, :status))
    @test closeout_artifacts.schema_version == 1
    @test closeout_artifacts.summary.total == length(closeout_records)
    @test closeout_artifacts.summary.ready + closeout_artifacts.summary.blocked == closeout_artifacts.summary.total
    @test closeout_artifacts.complete == (closeout_artifacts.summary.blocked == 0)
    @test closeout_artifacts.records == closeout_records
    @test startswith(closeout_artifacts.markdown, "| `family` | `status` |")
    @test startswith(closeout_artifacts.tsv, "family\tstatus\n")
    @test occursin("\"records\": [", closeout_artifacts.json)
    @test occursin("\"complete\": $(closeout_artifacts.complete)", widget_family_closeout_artifacts_json())
    @test occursin("summary total=$(closeout_artifacts.summary.total)", widget_family_closeout_artifacts_text())
    @test startswith(widget_family_closeout_artifacts_markdown(), "| `metric` | `value` |")
    @test startswith(widget_family_closeout_artifacts_tsv(), "metric\tvalue\n")
    @test !startswith(widget_family_closeout_artifacts_tsv(header=false), "metric\tvalue")
    if toolkit_closeout.ready
        @test assert_widget_family_closeout_ready(:toolkit) == toolkit_closeout
    else
        @test_throws ArgumentError assert_widget_family_closeout_ready(:toolkit)
    end
    if widget_family_closeout_complete()
        @test assert_widget_family_closeout_complete()
    else
        @test_throws ArgumentError assert_widget_family_closeout_complete()
    end
    release_record = widget_surface_release_status_record(root=joinpath(pwd(), "definitely-missing-git-root"))
    @test release_record.release_ready == false
    @test release_record.coverage_release_ready == false
    @test release_record.stability_complete == widget_stability_complete()
    @test release_record.family_closeout_complete == widget_family_closeout_complete()
    @test widget_surface_release_ready(root=joinpath(pwd(), "definitely-missing-git-root")) == false
    release_text = widget_surface_release_status_text(root=joinpath(pwd(), "definitely-missing-git-root"))
    @test occursin("release_ready=false", release_text)
    @test occursin("stability_complete=", release_text)
    release_json = widget_surface_release_status_json(root=joinpath(pwd(), "definitely-missing-git-root"))
    @test occursin("\"schema_version\": 1", release_json)
    @test occursin("\"coverage_release_ready\": false", release_json)
    @test_throws ArgumentError assert_widget_surface_release_ready(root=joinpath(pwd(), "definitely-missing-git-root"))
    families_text = widget_families_text()
    @test occursin("Inputs and controls", families_text)
    @test !occursin('\t', families_text)
    family_slugs_text = widget_family_slugs_text()
    @test occursin("inputs-and-controls", family_slugs_text)
    @test !occursin('\t', family_slugs_text)
    @test widget_catalog_family(:Button) == "Inputs and controls"
    @test widget_catalog_family(Button) == "Inputs and controls"
    @test widget_catalog_family(Button("Lookup", :lookup)) == "Inputs and controls"
    @test widget_catalog_family_slug(:Button) == "inputs-and-controls"
    @test widget_catalog_family_slug(Button) == "inputs-and-controls"
    @test widget_catalog_family_slug(Button("Lookup", :lookup)) == "inputs-and-controls"
    @test widget_catalog_family_slug("Inputs and controls") == "inputs-and-controls"
    @test widget_catalog_family_slug(:inputs_and_controls) == "inputs-and-controls"
    vocabulary = widget_vocabulary()
    @test !isempty(vocabulary)
    @test all(entry -> entry isa WidgetVocabularyEntry, vocabulary)
    @test any(entry -> entry.concept == "Button" && :Button in entry.widgets, vocabulary)
    vocabulary_records = widget_vocabulary_records()
    @test any(record -> record.concept == "Button" && :Button in record.widgets, vocabulary_records)
    button_vocabulary = widget_vocabulary_entry("Button")
    @test button_vocabulary isa WidgetVocabularyEntry
    @test :Button in button_vocabulary.widgets
    divider_vocabulary = widget_vocabulary_entry("Divider or separator")
    @test divider_vocabulary isa WidgetVocabularyEntry
    @test :Divider in divider_vocabulary.widgets
    @test :Separator in divider_vocabulary.widgets
    @test widget_vocabulary_entry(:Button) == button_vocabulary
    @test widget_vocabulary_entry("Definitely missing concept") === nothing
    @test :Button in widget_vocabulary_widget_names("Button")
    @test :Divider in widget_vocabulary_widget_names("Divider or separator")
    @test :TextInput in widget_vocabulary_widget_names("Single-line text field")
    @test any(entry -> entry.concept == "Button", search_widget_vocabulary("push button"))
    @test any(entry -> entry.concept == "Single-line text field", search_widget_vocabulary(:TextInput))
    @test startswith(widget_vocabulary_markdown(), "| `concept` | `widgets` | `state_contracts` |")
    @test occursin("| Button |", widget_vocabulary_markdown())
    @test startswith(widget_vocabulary_tsv(), "concept\twidgets\tstate_contracts\n")
    @test occursin("Button\t", widget_vocabulary_tsv())
    @test !startswith(widget_vocabulary_tsv(header=false), "concept\twidgets\tstate_contracts")
    input_entries = stable_widget_catalog(family="Inputs and controls")
    @test !isempty(input_entries)
    @test all(entry -> widget_catalog_family(entry) == "Inputs and controls", input_entries)
    @test stable_widget_catalog(family=:inputs_and_controls) == input_entries
    @test stable_widget_catalog(family="inputs-and-controls") == input_entries
    @test widget_catalog(family="Inputs and controls") == input_entries
    @test stable_widget_count(family="Inputs and controls") == length(input_entries)
    @test stable_widget_count(family=:inputs_and_controls) == length(input_entries)
    @test stable_widget_names(family="Inputs and controls") == [entry.name for entry in input_entries]
    @test stable_widget_names(family="inputs-and-controls") == [entry.name for entry in input_entries]
    @test :Button in stable_widget_names(family="Inputs and controls")
    names_text = widget_names_text()
    @test occursin("Button", names_text)
    @test !occursin('\t', names_text)
    @test occursin("Button", widget_names_text(family="Inputs and controls"))
    searched_names_text = search_widget_names_text("button")
    @test occursin("Button", searched_names_text)
    @test !occursin('\t', searched_names_text)
    @test occursin("Button", search_widget_names_text("button"; family="Inputs and controls"))
    sources = widget_source_files()
    @test !isempty(sources)
    @test issorted(sources)
    @test all(source -> endswith(source, ".jl"), sources)
    sources_text = widget_source_files_text()
    @test occursin(".jl", sources_text)
    @test !occursin('\t', sources_text)
    searched_sources_text = search_widget_source_files_text("button")
    @test occursin(".jl", searched_sources_text)
    @test !occursin('\t', searched_sources_text)
    @test occursin(".jl", widget_source_files_text(family="Inputs and controls"))
    @test occursin(".jl", search_widget_source_files_text("button"; family="Inputs and controls"))
    source_summary = widget_source_summary()
    @test !isempty(source_summary)
    @test issorted([row.source for row in source_summary])
    @test all(row -> row.count == length(row.widgets), source_summary)
    @test any(row -> :Button in row.widgets, source_summary)
    source_summary_markdown = widget_source_summary_markdown()
    @test startswith(source_summary_markdown, "| `source` | `count` | `widgets` |")
    @test occursin("Button", source_summary_markdown)
    source_summary_tsv = widget_source_summary_tsv()
    @test startswith(source_summary_tsv, "source\tcount\twidgets\n")
    @test occursin("Button", source_summary_tsv)
    @test !startswith(widget_source_summary_tsv(header=false), "source\tcount\twidgets")
    family_summary = widget_family_summary()
    @test !isempty(family_summary)
    @test issorted([row.family for row in family_summary])
    @test any(row -> row.family == "Inputs and controls" && :Button in row.widgets, family_summary)
    family_summary_markdown = widget_family_summary_markdown()
    @test startswith(family_summary_markdown, "| `family` | `count` | `widgets` |")
    @test occursin("Inputs and controls", family_summary_markdown)
    family_summary_tsv = widget_family_summary_tsv()
    @test startswith(family_summary_tsv, "family\tcount\twidgets\n")
    @test occursin("Inputs and controls", family_summary_tsv)
    @test !startswith(widget_family_summary_tsv(header=false), "family\tcount\twidgets")
    @test length(widget_family_summary(family="Inputs and controls")) == 1
    @test occursin("Inputs and controls", widget_family_summary_markdown(family="Inputs and controls"))
    @test occursin("Inputs and controls", widget_family_summary_tsv(family="Inputs and controls"))
    @test any(entry -> entry.name == :Button, search_widgets("button"))
    @test any(entry -> entry.name == :Button, search_widgets("inputs and controls"))
    @test any(entry -> entry.name == :Button, search_widgets("inputs-and-controls"))
    @test all(entry -> widget_catalog_family(entry) == "Inputs and controls", search_widgets("button"; family="Inputs and controls"))
    @test search_widget_count("button") == length(search_widgets("button"))
    @test search_widget_count("button"; family="Inputs and controls") == length(search_widgets("button"; family="Inputs and controls"))
    @test search_widget_count("definitely-not-a-widget") == 0
    @test any(entry -> entry.name == :Button, search_widgets(:button))
    @test any(entry -> entry.name == :Button, search_widgets(r"Button"))
    @test any(entry -> occursin("Widgets", entry.source), search_widgets("Widgets"))
    @test isempty(search_widgets("definitely-not-a-widget"))
    source_groups = group_widgets(:source)
    @test source_groups isa Dict{String,Vector{WidgetCatalogEntry}}
    @test any(values(source_groups)) do entries
        any(entry -> entry.name == :Button, entries)
    end
    @test all(values(source_groups)) do entries
        issorted([String(entry.name) for entry in entries])
    end
    surface_groups = group_widgets("surface"; status=nothing, surface=nothing)
    @test haskey(surface_groups, "stable")
    family_groups = group_widgets(:family)
    @test haskey(family_groups, "Inputs and controls")
    @test any(entry -> entry.name == :Button, family_groups["Inputs and controls"])
    @test collect(keys(group_widgets(:family; family=:inputs_and_controls))) == ["Inputs and controls"]
    summary = widget_catalog_summary()
    @test summary.total == length(catalog)
    @test summary.by_status[:stable] == length(stable_entries)
    @test summary.by_surface[:stable] == length(stable_entries)
    @test summary.by_family["Inputs and controls"] == length(family_groups["Inputs and controls"])
    @test summary.by_family_slug["inputs-and-controls"] == length(family_groups["Inputs and controls"])
    @test widget_catalog_summary(family=:inputs_and_controls).total == length(input_entries)
    markdown = widget_catalog_markdown(columns=(:name, :source))
    @test startswith(markdown, "| `name` | `source` |")
    @test occursin("| Button |", markdown)
    @test occursin("src/", markdown)
    @test occursin("| Button | Inputs and controls |", widget_catalog_markdown(columns=(:name, :family)))
    @test occursin("| Button | inputs-and-controls |", widget_catalog_markdown(columns=(:name, :family_slug)))
    @test startswith(widget_catalog_markdown(columns=("name", "status")), "| `name` | `status` |")
    @test startswith(widget_catalog_markdown(columns=:name), "| `name` |")
    @test startswith(widget_catalog_markdown(columns="name"), "| `name` |")
    @test occursin("| Button | Inputs and controls |", widget_catalog_markdown(family="Inputs and controls", columns=(:name, :family)))
    records = widget_catalog_records()
    @test length(records) == length(stable_entries)
    @test any(record -> record.name == :Button && record.family == "Inputs and controls" && record.family_slug == "inputs-and-controls" && endswith(record.source, ".jl"), records)
    @test widget_catalog_records(status="stable", surface="stable") == records
    @test all(record -> record.family == "Inputs and controls", widget_catalog_records(family="Inputs and controls"))
    coverage_records = widget_coverage_records()
    @test length(coverage_records) == length(stable_entries)
    @test any(record -> record.name == :Button && record.family == "Inputs and controls" && record.family_slug == "inputs-and-controls" && record.has_coverage isa Bool && record.complete isa Bool, coverage_records)
    @test all(record -> record.issue in (:complete, :missing_record, :source_mismatch, :missing_checks), coverage_records)
    @test all(record -> record.missing_checks isa Vector{Symbol}, coverage_records)
    stability_reports = widget_stability_reports()
    @test length(stability_reports) == length(catalog)
    @test all(report -> report isa WidgetStabilityReport, stability_reports)
    @test all(report -> report.ready == isempty(report.blockers), stability_reports)
    button_stability = widget_stability_report(:Button)
    @test button_stability.name == :Button
    @test button_stability.family == "Inputs and controls"
    @test button_stability.stable == (button_stability.surface === :stable && button_stability.status === :stable)
    @test widget_stability_ready(:Button) == button_stability.ready
    @test widget_stability_gaps() == [report for report in stability_reports if !report.ready]
    @test widget_stability_complete() == isempty(widget_stability_gaps())
    @test widget_stability_complete(family=:inputs_and_controls) == isempty(widget_stability_gaps(family=:inputs_and_controls))
    stability_summary = widget_stability_summary()
    @test stability_summary.total == length(stability_reports)
    @test stability_summary.ready + stability_summary.blocked == stability_summary.total
    @test stability_summary.stable + stability_summary.unstable == stability_summary.total
    @test stability_summary.coverage_complete + stability_summary.coverage_incomplete == stability_summary.total
    stability_summary_records = widget_stability_summary_records()
    @test any(record -> record.metric == "total" && record.key == "all" && record.count == stability_summary.total, stability_summary_records)
    @test any(record -> record.metric == "family" && record.key == "Inputs and controls", stability_summary_records)
    if button_stability.ready
        asserted_button_stability = assert_widget_stability_ready(:Button)
        @test asserted_button_stability.name == button_stability.name
        @test asserted_button_stability.ready == button_stability.ready
    else
        @test_throws ArgumentError assert_widget_stability_ready(:Button)
    end
    if widget_stability_complete()
        @test assert_widget_stability_complete()
    else
        @test_throws ArgumentError assert_widget_stability_complete()
    end
    @test startswith(widget_stability_markdown(columns=(:name, :ready)), "| `name` | `ready` |")
    @test startswith(widget_stability_tsv(columns=(:name, :ready)), "name\tready\n")
    @test startswith(widget_stability_gaps_markdown(columns=(:name, :ready)), "| `name` | `ready` |")
    @test startswith(widget_stability_gaps_tsv(columns=(:name, :ready)), "name\tready\n")
    @test startswith(widget_stability_summary_markdown(), "| `metric` | `key` | `count` |")
    @test startswith(widget_stability_summary_tsv(), "metric\tkey\tcount\n")
    @test !startswith(widget_stability_summary_tsv(header=false), "metric\tkey\tcount")
    @test occursin("total=", widget_stability_summary_text())
    @test occursin("blocked=", widget_stability_summary_text())
    @test experimental_widget_names() == Symbol[]
    @test experimental_widget_count() == 0
    @test experimental_widget_records() == []
    @test startswith(experimental_widget_records_markdown(), "| `name` | `cataloged` | `family` |")
    @test startswith(experimental_widget_records_tsv(), "name\tcataloged\tfamily\tfamily_slug\tsource\tsurface\tstatus\trequired_decision")
    @test !startswith(experimental_widget_records_tsv(header=false), "name\tcataloged\tfamily")
    @test occursin("\"experimental_widget_count\": 0", experimental_widget_records_json())
    @test candidate_widget_names() == Symbol[]
    @test candidate_widget_count() == 0
    @test candidate_widget_records() == []
    @test startswith(candidate_widget_records_markdown(), "| `name` | `family` | `family_slug` |")
    @test startswith(candidate_widget_records_tsv(), "name\tfamily\tfamily_slug\tsource\tsurface\tstatus\treason")
    @test !startswith(candidate_widget_records_tsv(header=false), "name\tfamily\tfamily_slug")
    @test occursin("\"candidate_widget_count\": 0", candidate_widget_records_json())
    @test widget_stabilization_closeout_records() == []
    @test widget_stabilization_closeout_kind_records(:experimental) == []
    @test widget_stabilization_closeout_kind_count(:candidate) == 0
    @test startswith(widget_stabilization_closeout_kind_markdown(:experimental), "| `kind` | `name` | `family` |")
    @test startswith(widget_stabilization_closeout_kind_tsv(:candidate), "kind\tname\tfamily\tfamily_slug\tsource\tsurface\tstatus\taction\treason")
    @test !startswith(widget_stabilization_closeout_kind_tsv(:candidate; header=false), "kind\tname\tfamily")
    @test occursin("\"count\": 0", widget_stabilization_closeout_kind_json(:experimental))
    @test widget_stabilization_closeout_kind_text(:candidate) == ""
    @test widget_stabilization_closeout_kind_complete(:experimental)
    @test assert_widget_stabilization_closeout_kind_complete(:candidate)
    @test_throws ArgumentError widget_stabilization_closeout_kind_records(:unknown)
    @test_throws ArgumentError widget_stabilization_closeout_kind_markdown(:unknown)
    @test_throws ArgumentError widget_stabilization_closeout_kind_tsv(:unknown)
    @test_throws ArgumentError widget_stabilization_closeout_kind_json(:unknown)
    @test_throws ArgumentError widget_stabilization_closeout_kind_text(:unknown)
    @test_throws ArgumentError widget_stabilization_closeout_kind_complete(:unknown)
    @test_throws ArgumentError assert_widget_stabilization_closeout_kind_complete(:unknown)
    @test search_widget_stabilization_closeout_records("button") == []
    @test search_widget_stabilization_closeout_records(:button) == []
    @test search_widget_stabilization_closeout_records(123) == []
    @test search_widget_stabilization_closeout_count("button") == 0
    @test search_widget_stabilization_closeout_summary("button").total == 0
    @test (metric="kind", key="candidate", count=0) in search_widget_stabilization_closeout_summary_records("button")
    @test startswith(search_widget_stabilization_closeout_summary_markdown("button"), "| `metric` | `key` | `count` |")
    @test startswith(search_widget_stabilization_closeout_summary_tsv("button"), "metric\tkey\tcount\n")
    @test !startswith(search_widget_stabilization_closeout_summary_tsv("button"; header=false), "metric\tkey\tcount")
    @test occursin("\"total\": 0", search_widget_stabilization_closeout_summary_json("button"))
    @test search_widget_stabilization_closeout_summary_text("button") == "query=button total=0 experimental=0 candidate=0"
    @test search_widget_stabilization_closeout_complete("button")
    @test assert_search_widget_stabilization_closeout_complete("button")
    @test startswith(search_widget_stabilization_closeout_markdown("button"), "| `kind` | `name` | `family` |")
    @test startswith(search_widget_stabilization_closeout_tsv("button"), "kind\tname\tfamily\tfamily_slug\tsource\tsurface\tstatus\taction\treason")
    @test !startswith(search_widget_stabilization_closeout_tsv("button"; header=false), "kind\tname\tfamily")
    @test occursin("\"match_count\": 0", search_widget_stabilization_closeout_json("button"))
    @test search_widget_stabilization_closeout_text("button") == ""
    search_closeout_artifacts = search_widget_stabilization_closeout_artifacts("button")
    @test search_closeout_artifacts.schema_version == 1
    @test search_closeout_artifacts.query == "button"
    @test search_closeout_artifacts.count == 0
    @test search_closeout_artifacts.summary.total == 0
    @test (metric="kind", key="candidate", count=0) in search_closeout_artifacts.summary_records
    @test search_closeout_artifacts.summary_text == "query=button total=0 experimental=0 candidate=0"
    @test occursin("\"total\": 0", search_closeout_artifacts.summary_json)
    @test search_closeout_artifacts.records == []
    @test search_widget_stabilization_closeout_artifacts(:button).query == "button"
    @test widget_stabilization_closeout_count() == 0
    @test widget_stabilization_closeout_complete()
    @test assert_widget_stabilization_closeout_complete()
    closeout_summary = widget_stabilization_closeout_summary()
    @test closeout_summary.total == 0
    @test (metric="kind", key="experimental", count=0) in widget_stabilization_closeout_summary_records()
    @test startswith(widget_stabilization_closeout_summary_markdown(), "| `metric` | `key` | `count` |")
    @test startswith(widget_stabilization_closeout_summary_tsv(), "metric\tkey\tcount\n")
    @test !startswith(widget_stabilization_closeout_summary_tsv(header=false), "metric\tkey\tcount")
    @test occursin("\"total\": 0", widget_stabilization_closeout_summary_json())
    @test widget_stabilization_closeout_summary_text() == "total=0 experimental=0 candidate=0"
    closeout_status = widget_stabilization_closeout_status_record()
    @test closeout_status.complete
    @test closeout_status.closeout_count == 0
    @test widget_stabilization_closeout_status_text() == "complete=true closeout_count=0 experimental_count=0 candidate_count=0"
    @test occursin("\"complete\": true", widget_stabilization_closeout_status_json())
    @test startswith(widget_stabilization_closeout_status_markdown(), "| `metric` | `value` |")
    @test startswith(widget_stabilization_closeout_status_tsv(), "metric\tvalue\n")
    @test !startswith(widget_stabilization_closeout_status_tsv(header=false), "metric\tvalue")
    @test startswith(widget_stabilization_closeout_markdown(), "| `kind` | `name` | `family` |")
    @test startswith(widget_stabilization_closeout_tsv(), "kind\tname\tfamily\tfamily_slug\tsource\tsurface\tstatus\taction\treason")
    @test !startswith(widget_stabilization_closeout_tsv(header=false), "kind\tname\tfamily")
    @test occursin("\"closeout_count\": 0", widget_stabilization_closeout_json())
    @test widget_stabilization_closeout_text() == ""
    closeout_artifacts = widget_stabilization_closeout_artifacts()
    @test closeout_artifacts.schema_version == 1
    @test closeout_artifacts.status.complete
    @test closeout_artifacts.summary.total == 0
    @test closeout_artifacts.records == []
    @test closeout_artifacts.text == ""
    @test occursin("\"closeout_count\": 0", closeout_artifacts.json)
    stabilization_status = widget_stabilization_status_record()
    @test stabilization_status.experimental_widget_count == 0
    @test stabilization_status.candidate_widget_count == 0
    stabilization_records = widget_stabilization_status_records()
    @test (metric="candidate_widget_count", value=0) in stabilization_records
    @test (metric="experimental_widget_count", value=0) in stabilization_records
    @test stabilization_status.stable_widgets == stable_widget_count()
    @test stabilization_status.ready == (
        widget_stability_complete() &&
        widget_family_closeout_complete()
    )
    @test widget_stabilization_ready() == stabilization_status.ready
    @test occursin("experimental_widgets=0", widget_stabilization_status_text())
    @test startswith(widget_stabilization_status_markdown(), "| `metric` | `value` |")
    @test occursin("| ready | $(stabilization_status.ready) |", widget_stabilization_status_markdown())
    @test startswith(widget_stabilization_status_tsv(), "metric\tvalue\n")
    @test occursin("candidate_widget_count\t0", widget_stabilization_status_tsv())
    @test !startswith(widget_stabilization_status_tsv(header=false), "metric\tvalue")
    stabilization_artifacts = widget_stabilization_artifacts()
    @test stabilization_artifacts.schema_version == 1
    @test stabilization_artifacts.status.ready == stabilization_status.ready
    @test stabilization_artifacts.closeout.status.complete
    @test stabilization_artifacts.blocker_count == length(stabilization_artifacts.blockers)
    @test occursin("\"ready\": $(stabilization_status.ready)", widget_stabilization_artifacts_json())
    @test occursin("\"blocker_records\":", widget_stabilization_artifacts_json())
    @test occursin("ready=$(stabilization_status.ready)", widget_stabilization_artifacts_text())
    @test occursin("closeout_summary total=0 experimental=0 candidate=0", widget_stabilization_artifacts_text())
    @test startswith(widget_stabilization_artifacts_markdown(), "| `metric` | `value` |")
    @test startswith(widget_stabilization_artifacts_tsv(), "metric\tvalue\n")
    @test !startswith(widget_stabilization_artifacts_tsv(header=false), "metric\tvalue")
    @test widget_stabilization_artifacts_ready() == stabilization_artifacts.ready
    if stabilization_artifacts.ready
        @test assert_widget_stabilization_artifacts_ready().ready
    else
        @test_throws ArgumentError assert_widget_stabilization_artifacts_ready()
    end
    @test widget_stabilization_blocker_records() isa Vector
    @test all(record -> haskey(record, :category) && haskey(record, :count) && haskey(record, :details), widget_stabilization_blocker_records())
    @test startswith(widget_stabilization_blocker_records_markdown(), "| `category` | `count` | `details` |")
    @test startswith(widget_stabilization_blocker_records_tsv(), "category\tcount\tdetails")
    @test !startswith(widget_stabilization_blocker_records_tsv(header=false), "category\tcount\tdetails")
    @test occursin("\"blocker_count\": $(length(widget_stabilization_blocker_records()))", widget_stabilization_blocker_records_json())
    @test widget_stabilization_blockers() isa Vector{String}
    @test widget_stabilization_blocker_count() == length(widget_stabilization_blockers())
    @test widget_stabilization_blockers_text() == join(widget_stabilization_blockers(), "\n")
    @test startswith(widget_stabilization_blockers_markdown(), "| `blocker` |")
    @test startswith(widget_stabilization_blockers_tsv(), "blocker")
    @test !startswith(widget_stabilization_blockers_tsv(header=false), "blocker")
    if stabilization_status.ready
        @test assert_widget_stabilization_ready()
    else
        @test_throws ArgumentError assert_widget_stabilization_ready()
    end
    stabilization_json = widget_stabilization_status_json()
    @test occursin("\"schema_version\": 1", stabilization_json)
    @test occursin("\"candidate_widget_count\": 0", stabilization_json)
    @test occursin("\"experimental_widget_count\": 0", stabilization_json)
    stability_json = widget_stability_json()
    @test occursin("\"schema_version\": 1", stability_json)
    @test occursin("\"metadata\"", stability_json)
    @test occursin("\"summary\"", stability_json)
    @test occursin("\"rows\": [", stability_json)
    @test occursin("\"name\": \"Button\"", stability_json)
    @test occursin("\"blockers\":", stability_json)
    @test !startswith(widget_stability_tsv(columns=(:name, :ready), header=false), "name\tready")
    coverage_gaps = widget_coverage_gaps()
    @test all(record -> !record.complete, coverage_gaps)
    @test widget_coverage_issue_records(:complete) == [record for record in coverage_records if record.issue === :complete]
    @test widget_coverage_issue_count(:missing_record) == count(record -> record.issue === :missing_record, coverage_records)
    @test widget_coverage_issue_names(:missing_record) == [record.name for record in widget_coverage_issue_records(:missing_record)]
    @test !occursin('\t', widget_coverage_issue_text(:missing_record))
    @test startswith(widget_coverage_issue_markdown(:source_mismatch, columns=(:name, :issue)), "| `name` | `issue` |")
    @test startswith(widget_coverage_issue_tsv(:missing_checks, columns=(:name, :issue)), "name\tissue\n")
    @test !startswith(widget_coverage_issue_tsv(:missing_checks, columns=(:name, :issue), header=false), "name\tissue")
    @test widget_coverage_complete() == isempty(coverage_gaps)
    if isempty(coverage_gaps)
        @test assert_widget_coverage_complete()
    else
        @test_throws ArgumentError assert_widget_coverage_complete()
        try
            assert_widget_coverage_complete()
        catch error
            @test occursin("stable widget coverage evidence has", sprint(showerror, error))
            @test occursin(String(first(coverage_gaps).name), sprint(showerror, error))
        end
    end
    git_metadata = widget_coverage_git_metadata(root=pwd())
    @test hasproperty(git_metadata, :commit)
    @test hasproperty(git_metadata, :dirty)
    @test widget_coverage_release_ready(root=joinpath(pwd(), "definitely-missing-git-root")) == false
    release_record = widget_coverage_release_status_record(root=joinpath(pwd(), "definitely-missing-git-root"))
    @test release_record.release_ready == false
    @test release_record.git_available == false
    release_json = widget_coverage_release_status_json(root=joinpath(pwd(), "definitely-missing-git-root"))
    @test occursin("\"release_ready\": false", release_json)
    @test occursin("\"git_commit\": null", release_json)
    release_status = widget_coverage_release_status_text(root=joinpath(pwd(), "definitely-missing-git-root"))
    @test occursin("release_ready=false", release_status)
    @test occursin("git_available=false", release_status)
    @test_throws ArgumentError assert_widget_coverage_clean_git(root=joinpath(pwd(), "definitely-missing-git-root"))
    @test_throws ArgumentError assert_widget_coverage_release_ready(root=joinpath(pwd(), "definitely-missing-git-root"))
    coverage_summary = widget_coverage_summary()
    @test coverage_summary.total == length(coverage_records)
    @test coverage_summary.complete + coverage_summary.incomplete == coverage_summary.total
    @test coverage_summary.missing_records + coverage_summary.source_mismatches + coverage_summary.missing_checks + get(coverage_summary.by_issue, :complete, 0) == coverage_summary.total
    coverage_summary_records = widget_coverage_summary_records()
    @test any(record -> record.metric == "total" && record.key == "all" && record.count == coverage_summary.total, coverage_summary_records)
    @test any(record -> record.metric == "issue" && record.key in ("complete", "missing_record", "source_mismatch", "missing_checks"), coverage_summary_records)
    @test startswith(widget_coverage_summary_markdown(), "| `metric` | `key` | `count` |")
    coverage_summary_json = widget_coverage_summary_json(include_git=false)
    @test occursin("\"schema_version\": 1", coverage_summary_json)
    @test occursin("\"metadata\"", coverage_summary_json)
    @test occursin("\"summary\"", coverage_summary_json)
    @test startswith(widget_coverage_summary_tsv(), "metric\tkey\tcount\n")
    @test !startswith(widget_coverage_summary_tsv(header=false), "metric\tkey\tcount")
    coverage_summary_text = widget_coverage_summary_text()
    @test occursin("total=", coverage_summary_text)
    @test occursin("incomplete=", coverage_summary_text)
    @test startswith(widget_coverage_records_markdown(columns=(:name, :issue)), "| `name` | `issue` |")
    @test startswith(widget_coverage_gaps_markdown(columns=(:name, :issue)), "| `name` | `issue` |")
    @test startswith(widget_coverage_records_tsv(columns=(:name, :issue)), "name\tissue\n")
    @test !startswith(widget_coverage_gaps_tsv(columns=(:name, :issue), header=false), "name\tissue")
    @test length(widget_coverage_records(family="Inputs and controls")) == length(input_entries)
    tsv = widget_catalog_tsv(columns=(:name, :status))
    @test startswith(tsv, "name\tstatus\n")
    @test occursin("Button\tstable", tsv)
    @test startswith(widget_catalog_tsv(columns=:name), "name\n")
    @test startswith(widget_catalog_tsv(columns=(:name, :family)), "name\tfamily\n")
    @test startswith(widget_catalog_tsv(columns=(:name, :family_slug)), "name\tfamily_slug\n")
    @test occursin("Button\tInputs and controls", widget_catalog_tsv(family="Inputs and controls", columns=(:name, :family)))
    @test occursin("Button\tinputs-and-controls", widget_catalog_tsv(family="Inputs and controls", columns=(:name, :family_slug)))
    tsv_without_header = widget_catalog_tsv(columns=(:name, :status), header=false)
    @test !startswith(tsv_without_header, "name\tstatus")
    @test occursin("Button\tstable", tsv_without_header)
    searched_markdown = search_widget_catalog_markdown("button"; columns=:name)
    @test startswith(searched_markdown, "| `name` |")
    @test occursin("| Button |", searched_markdown)
    searched_slug_markdown = search_widget_catalog_markdown("inputs-and-controls"; columns=(:name, :family_slug))
    @test startswith(searched_slug_markdown, "| `name` | `family_slug` |")
    @test occursin("| Button | inputs-and-controls |", searched_slug_markdown)
    searched_tsv = search_widget_catalog_tsv("button"; columns=(:name, :status))
    @test startswith(searched_tsv, "name\tstatus\n")
    @test occursin("Button\tstable", searched_tsv)
    @test occursin("Button\tInputs and controls", search_widget_catalog_tsv("button"; family="Inputs and controls", columns=(:name, :family)))
    searched_tsv_without_header = search_widget_catalog_tsv("button"; columns=(:name, :status), header=false)
    @test !startswith(searched_tsv_without_header, "name\tstatus")
    @test occursin("Button\tstable", searched_tsv_without_header)

    button = widget_catalog_entry(:Button)
    @test button isa WidgetCatalogEntry
    @test button.name == :Button
    @test button.status == :stable
    @test button.surface == :stable
    @test endswith(button.source, ".jl")
    @test occursin("evidence complete", button.reason)
    @test widget_catalog_entry("Button") == button
    @test widget_catalog_entry(Button) == button
    @test widget_catalog_entry(Button("Lookup", :lookup)) == button
    @test is_stable_widget(:Button)
    @test is_stable_widget("Button")
    @test is_stable_widget(Button)
    @test is_stable_widget(Button("Lookup", :lookup))
    @test assert_stable_widget(:Button) == button
    @test assert_stable_widget("Button") == button
    @test assert_stable_widget(Button) == button
    @test assert_stable_widget(Button("Lookup", :lookup)) == button
    @test !is_stable_widget(:DefinitelyMissingWidget)
    @test widget_catalog_entry(:DefinitelyMissingWidget) === nothing
    @test_throws ArgumentError assert_stable_widget(:DefinitelyMissingWidget)

    @test_throws ArgumentError stable_widget_catalog(status=1)
    @test_throws ArgumentError search_widget_vocabulary(1)
    @test_throws MethodError widget_vocabulary_entry(1)
    @test_throws ArgumentError widget_vocabulary_widget_names(1)
    @test_throws ArgumentError stable_widget_catalog(family=1)
    @test_throws ArgumentError stable_widget_count(status=1)
    @test_throws ArgumentError stable_widget_families(status=1)
    @test_throws ArgumentError stable_widget_family_slugs(status=1)
    @test_throws ArgumentError stable_widget_family_catalog(status=1)
    @test_throws ArgumentError stable_widget_family_catalog(family=1)
    @test_throws ArgumentError widget_family_catalog_markdown(family=1)
    @test_throws ArgumentError widget_family_catalog_markdown(columns=())
    @test_throws ArgumentError widget_family_catalog_markdown(columns=(:missing,))
    @test_throws ArgumentError widget_family_catalog_tsv(family=1)
    @test_throws ArgumentError widget_family_catalog_tsv(columns=())
    @test_throws ArgumentError widget_family_catalog_tsv(columns=(:missing,))
    @test_throws ArgumentError widget_family_closeout_reports(family=1)
    @test_throws ArgumentError widget_family_closeout_reports(status=1)
    @test_throws ArgumentError widget_family_closeout_reports(status=:unknown)
    @test_throws ArgumentError widget_family_closeout_report(:definitely_missing_family)
    @test_throws ArgumentError widget_family_closeout_complete(family=1)
    @test_throws ArgumentError widget_family_closeout_complete(family=:definitely_missing_family)
    @test_throws ArgumentError assert_widget_family_closeout_complete(family=1)
    @test_throws ArgumentError assert_widget_family_closeout_complete(family=:definitely_missing_family)
    @test_throws ArgumentError widget_surface_release_status_record(family=1)
    @test_throws ArgumentError widget_surface_release_ready(family=1)
    @test_throws ArgumentError assert_widget_surface_release_ready(family=1)
    @test_throws ArgumentError widget_surface_release_status_text(family=1)
    @test_throws ArgumentError widget_surface_release_status_json(family=1)
    @test_throws ArgumentError widget_family_closeout_markdown(columns=())
    @test_throws ArgumentError widget_family_closeout_markdown(columns=(:missing,))
    @test_throws ArgumentError widget_family_closeout_tsv(columns=1)
    @test_throws ArgumentError widget_family_closeout_tsv(columns=(1,))
    @test_throws ArgumentError widget_family_closeout_json(status=:missing)
    @test_throws ArgumentError widget_family_closeout_artifacts(status=:missing)
    @test_throws ArgumentError widget_family_closeout_artifacts(columns=())
    @test_throws ArgumentError widget_family_closeout_artifacts_json(status=:missing)
    @test_throws ArgumentError widget_family_closeout_artifacts_text(status=:missing)
    @test_throws ArgumentError widget_family_closeout_artifacts_markdown(status=:missing)
    @test_throws ArgumentError widget_family_closeout_artifacts_tsv(status=:missing)
    @test_throws ArgumentError search_widget_families(1)
    @test_throws ArgumentError search_widget_family_count(1)
    @test_throws ArgumentError search_widget_family_catalog_markdown(1)
    @test_throws ArgumentError search_widget_family_catalog_tsv(1)
    @test_throws ArgumentError widget_families_text(status=1)
    @test_throws ArgumentError widget_family_slugs_text(status=1)
    @test_throws ArgumentError stable_widget_names(status=1)
    @test_throws ArgumentError search_widgets(1)
    @test_throws ArgumentError search_widget_count(1)
    @test_throws ArgumentError search_widget_names_text(1)
    @test_throws ArgumentError search_widget_source_files_text(1)
    @test_throws ArgumentError group_widgets(:unknown)
    @test_throws ArgumentError widget_catalog_markdown(columns=())
    @test_throws ArgumentError widget_catalog_markdown(columns=1)
    @test_throws ArgumentError widget_catalog_markdown(columns=(:missing,))
    @test_throws ArgumentError widget_catalog_markdown(columns=(1,))
    @test_throws ArgumentError widget_catalog_tsv(columns=())
    @test_throws ArgumentError widget_coverage_records(family=1)
    @test_throws ArgumentError widget_stability_reports(family=1)
    @test_throws ArgumentError widget_stability_report(1)
    @test_throws ArgumentError widget_stability_report(:DefinitelyMissingWidget)
    @test_throws ArgumentError widget_stability_ready(1)
    @test_throws ArgumentError widget_stability_complete(family=1)
    @test_throws ArgumentError assert_widget_stability_complete(family=1)
    @test_throws ArgumentError widget_stability_summary(family=1)
    @test_throws ArgumentError widget_stability_summary_records(family=1)
    @test_throws ArgumentError widget_stability_summary_markdown(family=1)
    @test_throws ArgumentError widget_stability_summary_tsv(family=1)
    @test_throws ArgumentError widget_stability_summary_text(family=1)
    @test_throws ArgumentError experimental_widget_records(family=1)
    @test_throws ArgumentError experimental_widget_records_markdown(family=1)
    @test_throws ArgumentError experimental_widget_records_tsv(family=1)
    @test_throws ArgumentError experimental_widget_records_json(family=1)
    @test_throws ArgumentError candidate_widget_count(family=1)
    @test_throws ArgumentError candidate_widget_records(family=1)
    @test_throws ArgumentError candidate_widget_records_markdown(family=1)
    @test_throws ArgumentError candidate_widget_records_tsv(family=1)
    @test_throws ArgumentError candidate_widget_records_json(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_records(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_kind_records(:experimental, family=1)
    @test_throws ArgumentError widget_stabilization_closeout_kind_count(:candidate, family=1)
    @test_throws ArgumentError widget_stabilization_closeout_kind_markdown(:experimental, family=1)
    @test_throws ArgumentError widget_stabilization_closeout_kind_tsv(:candidate, family=1)
    @test_throws ArgumentError widget_stabilization_closeout_kind_json(:experimental, family=1)
    @test_throws ArgumentError widget_stabilization_closeout_kind_text(:candidate, family=1)
    @test_throws ArgumentError widget_stabilization_closeout_kind_complete(:experimental, family=1)
    @test_throws ArgumentError assert_widget_stabilization_closeout_kind_complete(:candidate, family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_records("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_count("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_summary("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_summary_records("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_summary_markdown("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_summary_tsv("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_summary_json("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_summary_text("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_complete("button", family=1)
    @test_throws ArgumentError assert_search_widget_stabilization_closeout_complete("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_markdown("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_tsv("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_json("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_text("button", family=1)
    @test_throws ArgumentError search_widget_stabilization_closeout_artifacts("button", family=1)
    @test_throws ArgumentError widget_stabilization_closeout_count(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_complete(family=1)
    @test_throws ArgumentError assert_widget_stabilization_closeout_complete(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_summary(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_summary_records(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_summary_markdown(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_summary_tsv(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_summary_json(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_summary_text(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_status_record(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_status_text(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_status_json(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_status_markdown(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_status_tsv(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_markdown(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_tsv(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_json(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_text(family=1)
    @test_throws ArgumentError widget_stabilization_closeout_artifacts(family=1)
    @test_throws ArgumentError widget_stabilization_status_records(family=1)
    @test_throws ArgumentError widget_stabilization_status_markdown(family=1)
    @test_throws ArgumentError widget_stabilization_artifacts(family=1)
    @test_throws ArgumentError widget_stabilization_artifacts_json(family=1)
    @test_throws ArgumentError widget_stabilization_artifacts_text(family=1)
    @test_throws ArgumentError widget_stabilization_artifacts_markdown(family=1)
    @test_throws ArgumentError widget_stabilization_artifacts_tsv(family=1)
    @test_throws ArgumentError widget_stabilization_artifacts_ready(family=1)
    @test_throws ArgumentError assert_widget_stabilization_artifacts_ready(family=1)
    @test_throws ArgumentError widget_stabilization_status_tsv(family=1)
    @test_throws ArgumentError widget_stabilization_ready(family=1)
    @test_throws ArgumentError widget_stabilization_blocker_records(family=1)
    @test_throws ArgumentError widget_stabilization_blocker_records_markdown(family=1)
    @test_throws ArgumentError widget_stabilization_blocker_records_tsv(family=1)
    @test_throws ArgumentError widget_stabilization_blocker_records_json(family=1)
    @test_throws ArgumentError widget_stabilization_blocker_count(family=1)
    @test_throws ArgumentError widget_stabilization_blockers_markdown(family=1)
    @test_throws ArgumentError widget_stabilization_blockers_tsv(family=1)
    @test_throws ArgumentError assert_widget_stability_ready(1)
    @test_throws ArgumentError widget_stability_markdown(columns=())
    @test_throws ArgumentError widget_stability_markdown(columns=(:missing,))
    @test_throws ArgumentError widget_stability_tsv(columns=1)
    @test_throws ArgumentError widget_stability_gaps_markdown(columns=())
    @test_throws ArgumentError widget_stability_gaps_tsv(columns=(:missing,))
    @test_throws ArgumentError widget_stability_json(family=1)
    @test_throws ArgumentError widget_coverage_gaps(family=1)
    @test_throws ArgumentError widget_coverage_issue_records(:missing)
    @test_throws ArgumentError widget_coverage_issue_count(1)
    @test_throws ArgumentError widget_coverage_issue_names(:missing)
    @test_throws ArgumentError widget_coverage_issue_text(1)
    @test_throws ArgumentError widget_coverage_issue_markdown(:missing_record, columns=())
    @test_throws ArgumentError widget_coverage_issue_tsv(:missing_record, columns=(:missing,))
    @test_throws ArgumentError widget_coverage_complete(family=1)
    @test_throws ArgumentError assert_widget_coverage_complete(family=1)
    @test_throws ArgumentError widget_coverage_summary(family=1)
    @test_throws ArgumentError widget_coverage_summary_records(family=1)
    @test_throws ArgumentError widget_coverage_summary_markdown(family=1)
    @test_throws ArgumentError widget_coverage_summary_json(family=1)
    @test_throws ArgumentError widget_coverage_summary_tsv(family=1)
    @test_throws ArgumentError widget_coverage_summary_text(family=1)
    @test_throws ArgumentError widget_coverage_records_markdown(columns=())
    @test_throws ArgumentError widget_coverage_records_markdown(columns=1)
    @test_throws ArgumentError widget_coverage_records_markdown(columns=(:missing,))
    @test_throws ArgumentError widget_coverage_gaps_markdown(columns=(1,))
    @test_throws ArgumentError widget_coverage_records_tsv(columns=())
    @test_throws ArgumentError widget_coverage_gaps_tsv(columns=(:missing,))
    @test_throws ArgumentError search_widget_catalog_markdown(1)
    @test_throws ArgumentError search_widget_catalog_tsv(1)
    @test_throws ArgumentError is_stable_widget(1)
    @test_throws ArgumentError widget_catalog_family(1)
    @test_throws ArgumentError widget_catalog_family_slug(1)
    @test_throws ArgumentError widget_catalog_entry(1)
    @test_throws ArgumentError widget_family_entry(1)
    @test_throws ArgumentError is_stable_widget_family(1)
    @test_throws ArgumentError assert_stable_widget_family(1)
    @test_throws ArgumentError widget_family_widgets(1)
    @test_throws ArgumentError widget_family_widget_names(1)
    @test_throws ArgumentError widget_family_widget_count(1)
    @test_throws ArgumentError assert_stable_widget(1)
end
