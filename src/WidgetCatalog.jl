const _WIDGET_CATALOG_PATH = normpath(joinpath(@__DIR__, "..", "api", "stable_widget_candidates.tsv"))
const _COMPONENT_CATALOG_PATH = normpath(joinpath(@__DIR__, "..", "docs", "COMPONENT_CATALOG.md"))
const _WIDGET_CATALOG_ROOT = normpath(joinpath(@__DIR__, ".."))
const _WIDGET_CATALOG_COLUMNS = ("widget", "source", "surface", "status", "reason")
const _WIDGET_VOCABULARY_HEADER = "| Cross-library concept | Wicked API name | State contract |"
const _WIDGET_CATALOG_FALLBACK_FAMILY = "Unclassified"
const _WIDGET_COVERAGE_PATH = normpath(joinpath(@__DIR__, "..", "api", "widget_coverage.tsv"))
const _WIDGET_FAMILY_EVIDENCE_PATH = normpath(joinpath(@__DIR__, "..", "api", "widget_family_evidence.tsv"))
const _EXPERIMENTAL_PROMOTION_PATH = normpath(joinpath(@__DIR__, "..", "api", "experimental_promotions.tsv"))
const _WIDGET_FAMILY_EVIDENCE_COLUMNS = (
    "family",
    "docs",
    "examples",
    "example_family_labels",
    "stable_api_tokens",
    "precompile_tokens",
    "notes",
)
const _WIDGET_COVERAGE_COLUMNS = (
    "widget_type",
    "stateless",
    "stateful",
    "source",
    "zero_size",
    "minimal",
    "clipped",
    "resize",
    "state_transition",
    "snapshot",
    "toolkit",
    "semantics",
    "keyboard",
    "pointer",
)
const _EXPERIMENTAL_PROMOTION_COLUMNS = ("name", "decision", "target", "review_status", "notes")
const _VALID_EXPERIMENTAL_DECISIONS = Set(("promote", "qualify", "remove"))
const _VALID_EXPERIMENTAL_REVIEW_STATUSES = Set(("proposed", "accepted", "completed"))
const _WIDGET_COVERAGE_CHECK_COLUMNS = (
    :zero_size,
    :minimal,
    :clipped,
    :resize,
    :state_transition,
    :snapshot,
    :toolkit,
    :semantics,
    :keyboard,
    :pointer,
)
const _WIDGET_COVERAGE_ISSUES = (:complete, :missing_record, :source_mismatch, :missing_checks)

const _WIDGET_CATALOG_FAMILY_BY_NAME = Dict{Symbol,String}(
    :Block => "Core layout",
    :Border => "Core layout",
    :Box => "Core layout",
    :Card => "Core layout",
    :Center => "Core layout",
    :Clear => "Core layout",
    :Column => "Core layout",
    :Dock => "Core layout",
    :DockLayout => "Core layout",
    :Flow => "Core layout",
    :Grid => "Core layout",
    :Group => "Core layout",
    :Layer => "Core layout",
    :Overlay => "Core layout",
    :Padding => "Core layout",
    :Panel => "Core layout",
    :ResizablePane => "Core layout",
    :Row => "Core layout",
    :ScrollView => "Core layout",
    :Scrollbar => "Core layout",
    :Sidebar => "Core layout",
    :Spacer => "Core layout",
    :SplitPane => "Core layout",
    :Stack => "Core layout",
    :Viewport => "Core layout",
    :Wrap => "Core layout",
    :Heading => "Text and structure",
    :Label => "Text and structure",
    :MarkupText => "Text and structure",
    :Paragraph => "Text and structure",
    :RichText => "Text and structure",
    :Rule => "Text and structure",
    :Separator => "Text and structure",
    :Divider => "Text and structure",
    :Static => "Text and structure",
    :TextView => "Text and structure",
    :Autocomplete => "Inputs and controls",
    :Button => "Inputs and controls",
    :CheckBox => "Inputs and controls",
    :CheckBoxList => "Inputs and controls",
    :Checkbox => "Inputs and controls",
    :ColorPicker => "Inputs and controls",
    :ComboBox => "Inputs and controls",
    :Combobox => "Inputs and controls",
    :CommandPalette => "Inputs and controls",
    :ContextMenu => "Inputs and controls",
    :DateInput => "Inputs and controls",
    :DatePicker => "Inputs and controls",
    :DateTimeInput => "Inputs and controls",
    :DateTimePicker => "Inputs and controls",
    :Input => "Inputs and controls",
    :ListBox => "Inputs and controls",
    :MaskedInput => "Inputs and controls",
    :Menu => "Inputs and controls",
    :MenuBar => "Inputs and controls",
    :MenuButton => "Inputs and controls",
    :MultiSelect => "Inputs and controls",
    :NumberInput => "Inputs and controls",
    :OptionList => "Inputs and controls",
    :PasswordField => "Inputs and controls",
    :PasswordInput => "Inputs and controls",
    :PushButton => "Inputs and controls",
    :RadioBoxList => "Inputs and controls",
    :RadioButton => "Inputs and controls",
    :RadioGroup => "Inputs and controls",
    :RadioSet => "Inputs and controls",
    :RangeSlider => "Inputs and controls",
    :SearchInput => "Inputs and controls",
    :Select => "Inputs and controls",
    :SelectionList => "Inputs and controls",
    :Slider => "Inputs and controls",
    :SplitButton => "Inputs and controls",
    :Switch => "Inputs and controls",
    :TagInput => "Inputs and controls",
    :TextArea => "Inputs and controls",
    :Textarea => "Inputs and controls",
    :TextBox => "Inputs and controls",
    :TextField => "Inputs and controls",
    :TextInput => "Inputs and controls",
    :TimeInput => "Inputs and controls",
    :TimePicker => "Inputs and controls",
    :Toggle => "Inputs and controls",
    :TransferList => "Inputs and controls",
    :Accordion => "Navigation",
    :AppShell => "Navigation",
    :Breadcrumb => "Navigation",
    :Carousel => "Navigation",
    :Collapsible => "Navigation",
    :Dialog => "Navigation",
    :Drawer => "Navigation",
    :Modal => "Navigation",
    :NavigationRail => "Navigation",
    :Popover => "Navigation",
    :ShortcutBar => "Navigation",
    :StatusBar => "Navigation",
    :TabView => "Navigation",
    :TabbedContentView => "Navigation",
    :Tabs => "Navigation",
    :TitleBar => "Navigation",
    :Toolbar => "Navigation",
    :Tooltip => "Navigation",
    :Window => "Navigation",
    :DataGrid => "Data and virtualization",
    :DataStateView => "Data and virtualization",
    :DataTable => "Data and virtualization",
    :DefinitionList => "Data and virtualization",
    :DescriptionList => "Data and virtualization",
    :DirectoryPicker => "Data and virtualization",
    :DirectoryTree => "Data and virtualization",
    :FilePicker => "Data and virtualization",
    :KeyValueList => "Data and virtualization",
    :List => "Data and virtualization",
    :ListView => "Data and virtualization",
    :MetadataList => "Data and virtualization",
    :MultiFilePicker => "Data and virtualization",
    :Pagination => "Data and virtualization",
    :PropertyList => "Data and virtualization",
    :Table => "Data and virtualization",
    :Tree => "Data and virtualization",
    :TreeTable => "Data and virtualization",
    :TreeView => "Data and virtualization",
    :VirtualList => "Data and virtualization",
    :VirtualTable => "Data and virtualization",
    :VirtualTree => "Data and virtualization",
    :BarChart => "Visualization",
    :BrailleImage => "Visualization",
    :Calendar => "Visualization",
    :Canvas => "Visualization",
    :Chart => "Visualization",
    :Digits => "Visualization",
    :Gauge => "Visualization",
    :Heatmap => "Visualization",
    :Histogram => "Visualization",
    :ImageView => "Visualization",
    :LineGauge => "Visualization",
    :LoadingIndicator => "Visualization",
    :Meter => "Visualization",
    :Plot => "Visualization",
    :Skeleton => "Visualization",
    :Sparkline => "Visualization",
    :Spinner => "Visualization",
    :Stepper => "Visualization",
    :Timeline => "Visualization",
    :AnsiView => "Rich content",
    :CodeEditor => "Rich content",
    :CodeView => "Rich content",
    :DevConsole => "Rich content",
    :DiffView => "Rich content",
    :ErrorView => "Rich content",
    :HelpView => "Rich content",
    :Hyperlink => "Rich content",
    :Inspector => "Rich content",
    :Link => "Rich content",
    :LiveDisplay => "Rich content",
    :LogTail => "Rich content",
    :LogView => "Rich content",
    :MarkdownView => "Rich content",
    :Placeholder => "Rich content",
    :Pretty => "Rich content",
    :ProcessView => "Rich content",
    :ReplView => "Rich content",
    :RichLog => "Rich content",
    :SyntaxView => "Rich content",
    :TaskMonitor => "Rich content",
    :TerminalView => "Rich content",
    :ThemePreview => "Rich content",
    :Alert => "Runtime and services",
    :Badge => "Runtime and services",
    :EmptyState => "Runtime and services",
    :Footer => "Runtime and services",
    :Header => "Runtime and services",
    :ManagedNotificationView => "Runtime and services",
    :NotificationView => "Runtime and services",
    :Progress => "Runtime and services",
    :ProgressBar => "Runtime and services",
    :ProgressGroup => "Runtime and services",
    :Status => "Runtime and services",
    :Toast => "Runtime and services",
    :ValidationMessage => "Runtime and services",
    :ValidationSummary => "Runtime and services",
    :ToolkitTree => "Toolkit",
)

"""
    WidgetCatalogEntry

Stable widget metadata loaded from the reviewed widget stabilization ledger.
"""
struct WidgetCatalogEntry
    name::Symbol
    source::String
    surface::Symbol
    status::Symbol
    reason::String
end

"""
    WidgetFamilyEntry

Stable metadata for one reviewed widget family in the stabilization catalog.
"""
struct WidgetFamilyEntry
    name::String
    slug::String
    count::Int
    widgets::Vector{Symbol}
end

"""
    WidgetFamilyCloseoutReport

Family-level stabilization readiness loaded from `api/widget_family_evidence.tsv`.
"""
struct WidgetFamilyCloseoutReport
    family::String
    family_slug::String
    ready::Bool
    status::Symbol
    docs::Vector{String}
    examples::Vector{String}
    example_family_labels::Vector{String}
    stable_api_tokens::Vector{String}
    precompile_tokens::Vector{String}
    notes::String
    blockers::Vector{String}
end

"""
    WidgetStabilityReport

Promotion-readiness metadata for one reviewed widget.
"""
struct WidgetStabilityReport
    name::Symbol
    family::String
    family_slug::String
    surface::Symbol
    status::Symbol
    catalog_source::String
    coverage_source::String
    stable::Bool
    coverage_complete::Bool
    ready::Bool
    missing_checks::Vector{Symbol}
    blockers::Vector{String}
end

"""
    WidgetVocabularyEntry

Cross-library widget vocabulary row for ports from Ratatui, Textual, TamboUI,
and Lanterna-style APIs.
"""
struct WidgetVocabularyEntry
    concept::String
    widgets::Vector{Symbol}
    state_contracts::Vector{Symbol}
    stateless::Bool
end

function Base.show(io::IO, entry::WidgetCatalogEntry)
    print(
        io,
        "WidgetCatalogEntry(:",
        entry.name,
        ", surface=:",
        entry.surface,
        ", status=:",
        entry.status,
        ", source=",
        repr(entry.source),
        ")",
    )
end

function Base.show(io::IO, entry::WidgetFamilyEntry)
    print(
        io,
        "WidgetFamilyEntry(",
        repr(entry.name),
        ", slug=",
        repr(entry.slug),
        ", count=",
        entry.count,
        ")",
    )
end

function Base.show(io::IO, report::WidgetFamilyCloseoutReport)
    print(
        io,
        "WidgetFamilyCloseoutReport(",
        repr(report.family),
        ", ready=",
        report.ready,
        ", blockers=",
        length(report.blockers),
        ")",
    )
end

function Base.show(io::IO, report::WidgetStabilityReport)
    print(
        io,
        "WidgetStabilityReport(:",
        report.name,
        ", ready=",
        report.ready,
        ", blockers=",
        length(report.blockers),
        ")",
    )
end

function Base.show(io::IO, entry::WidgetVocabularyEntry)
    print(
        io,
        "WidgetVocabularyEntry(",
        repr(entry.concept),
        ", widgets=",
        length(entry.widgets),
        ", stateless=",
        entry.stateless,
        ")",
    )
end

function _widget_catalog_filter(value, label::AbstractString)
    value === nothing && return nothing
    value isa Symbol && return value
    value isa AbstractString && return Symbol(value)
    throw(ArgumentError("widget catalog $label filter must be a Symbol, String, or nothing"))
end

function _widget_catalog_family_filter(value)
    value === nothing && return nothing
    value isa Symbol && return _normalize_widget_catalog_family(String(value))
    value isa AbstractString && return _normalize_widget_catalog_family(value)
    throw(ArgumentError("widget catalog family filter must be a Symbol, String, or nothing"))
end

function _normalize_widget_catalog_family(value::AbstractString)
    normalized = lowercase(strip(value))
    normalized = replace(normalized, '_' => ' ', '-' => ' ')
    normalized = join(split(normalized), " ")
    return normalized
end

_widget_catalog_family_slug_text(value::AbstractString) =
    replace(_normalize_widget_catalog_family(value), ' ' => '-')

_widget_catalog_family_matches(entry::WidgetCatalogEntry, family_filter) =
    family_filter === nothing || _normalize_widget_catalog_family(widget_catalog_family(entry)) == family_filter

function _widget_catalog_name(value)
    value isa Symbol && return value
    value isa AbstractString && return Symbol(value)
    text = value isa Type ? string(value) : string(typeof(value))
    startswith(text, "Wicked.") ||
        throw(ArgumentError("widget catalog name must be a Symbol, String, Wicked widget type, or Wicked widget instance"))
    unparameterized = first(split(text, '{'; limit=2))
    return Symbol(last(split(unparameterized, '.')))
end

function _widget_catalog_search_query(value)
    value isa Regex && return value
    value isa Symbol && return lowercase(String(value))
    value isa AbstractString && return lowercase(String(value))
    throw(ArgumentError("widget catalog search query must be a Regex, Symbol, or String"))
end

function _widget_catalog_code_names(cell::AbstractString)
    names = String[]
    for matched in eachmatch(r"`([^`]+)`", cell)
        push!(names, matched.captures[1])
    end
    return names
end

function _widget_catalog_entry_search_text(entry::WidgetCatalogEntry)
    return lowercase(join((String(entry.name), entry.source, String(entry.surface), String(entry.status), widget_catalog_family(entry), widget_catalog_family_slug(entry), entry.reason), " "))
end

function _widget_catalog_query_matches(entry::WidgetCatalogEntry, query)
    query isa Regex && return occursin(query, join((String(entry.name), entry.source, String(entry.surface), String(entry.status), widget_catalog_family(entry), widget_catalog_family_slug(entry), entry.reason), " "))
    return occursin(query, _widget_catalog_entry_search_text(entry))
end

function _widget_vocabulary_search_text(entry::WidgetVocabularyEntry)
    return lowercase(join((
        entry.concept,
        join((String(name) for name in entry.widgets), " "),
        join((String(name) for name in entry.state_contracts), " "),
        entry.stateless ? "stateless" : "stateful",
    ), " "))
end

function _widget_vocabulary_query_matches(entry::WidgetVocabularyEntry, query)
    query isa Regex && return occursin(query, join((
        entry.concept,
        join((String(name) for name in entry.widgets), " "),
        join((String(name) for name in entry.state_contracts), " "),
        entry.stateless ? "stateless" : "stateful",
    ), " "))
    return occursin(query, _widget_vocabulary_search_text(entry))
end

function _widget_family_catalog_entry_search_text(entry::WidgetFamilyEntry)
    return lowercase(join((entry.name, entry.slug, string(entry.count), _widget_family_catalog_widgets_text(entry)), " "))
end

function _widget_family_catalog_query_matches(entry::WidgetFamilyEntry, query)
    query isa Regex && return occursin(query, join((entry.name, entry.slug, string(entry.count), _widget_family_catalog_widgets_text(entry)), " "))
    return occursin(query, _widget_family_catalog_entry_search_text(entry))
end

function _widget_catalog_group_key(entry::WidgetCatalogEntry, by)
    group = _widget_catalog_filter(by, "group")
    group === :family && return widget_catalog_family(entry)
    group === :source && return entry.source
    group === :surface && return String(entry.surface)
    group === :status && return String(entry.status)
    throw(ArgumentError("widget catalog group must be :family, :source, :surface, or :status"))
end

function _widget_catalog_column(value)
    value isa Symbol && return value
    value isa AbstractString && return Symbol(value)
    throw(ArgumentError("widget catalog markdown columns must be Symbols or Strings"))
end

function _widget_catalog_columns(columns)
    (columns isa Symbol || columns isa AbstractString) &&
        return Symbol[_widget_catalog_column(columns)]
    try
        return Symbol[_widget_catalog_column(column) for column in columns]
    catch error
        error isa MethodError &&
            throw(ArgumentError("widget catalog markdown columns must be a Symbol, String, or iterable collection of Symbols or Strings"))
        rethrow()
    end
end

function _widget_family_catalog_columns(columns)
    selected = _widget_catalog_columns(columns)
    isempty(selected) && throw(ArgumentError("widget family catalog requires at least one column"))
    for column in selected
        column in (:family, :family_slug, :count, :widgets) ||
            throw(ArgumentError("widget family catalog column must be one of :family, :family_slug, :count, or :widgets"))
    end
    return selected
end

function _widget_catalog_field(entry::WidgetCatalogEntry, column::Symbol)
    column === :name && return String(entry.name)
    column === :family && return widget_catalog_family(entry)
    column === :family_slug && return widget_catalog_family_slug(entry)
    column === :source && return entry.source
    column === :surface && return String(entry.surface)
    column === :status && return String(entry.status)
    column === :reason && return entry.reason
    throw(ArgumentError("widget catalog markdown column must be one of :name, :family, :family_slug, :source, :surface, :status, or :reason"))
end

function _widget_coverage_column(value)
    column = _widget_catalog_column(value)
    column in (
        :name,
        :family,
        :family_slug,
        :catalog_source,
        :coverage_source,
        :has_coverage,
        :source_matches,
        :complete,
        :missing_checks,
        :issue,
    ) || throw(ArgumentError("widget coverage column must be one of :name, :family, :family_slug, :catalog_source, :coverage_source, :has_coverage, :source_matches, :complete, :missing_checks, or :issue"))
    return column
end

function _widget_coverage_columns(columns)
    selected = columns isa Symbol || columns isa AbstractString ?
        Symbol[_widget_coverage_column(columns)] :
        try
            Symbol[_widget_coverage_column(column) for column in columns]
        catch error
            error isa MethodError &&
                throw(ArgumentError("widget coverage report columns must be a Symbol, String, or iterable collection of Symbols or Strings"))
            rethrow()
        end
    isempty(selected) && throw(ArgumentError("widget coverage report requires at least one column"))
    return selected
end

function _widget_coverage_field(row, column::Symbol)
    column === :name && return String(row.name)
    column === :family && return row.family
    column === :family_slug && return row.family_slug
    column === :catalog_source && return row.catalog_source
    column === :coverage_source && return row.coverage_source
    column === :has_coverage && return string(row.has_coverage)
    column === :source_matches && return string(row.source_matches)
    column === :complete && return string(row.complete)
    column === :missing_checks && return join((String(check) for check in row.missing_checks), ", ")
    column === :issue && return String(row.issue)
    throw(ArgumentError("widget coverage column must be one of :name, :family, :family_slug, :catalog_source, :coverage_source, :has_coverage, :source_matches, :complete, :missing_checks, or :issue"))
end

function _widget_stability_column(value)
    column = _widget_catalog_column(value)
    column in (
        :name,
        :family,
        :family_slug,
        :surface,
        :status,
        :catalog_source,
        :coverage_source,
        :stable,
        :coverage_complete,
        :ready,
        :missing_checks,
        :blockers,
    ) || throw(ArgumentError("widget stability column must be one of :name, :family, :family_slug, :surface, :status, :catalog_source, :coverage_source, :stable, :coverage_complete, :ready, :missing_checks, or :blockers"))
    return column
end

function _widget_stability_columns(columns)
    selected = columns isa Symbol || columns isa AbstractString ?
        Symbol[_widget_stability_column(columns)] :
        try
            Symbol[_widget_stability_column(column) for column in columns]
        catch error
            error isa MethodError &&
                throw(ArgumentError("widget stability report columns must be a Symbol, String, or iterable collection of Symbols or Strings"))
            rethrow()
        end
    isempty(selected) && throw(ArgumentError("widget stability report requires at least one column"))
    return selected
end

function _widget_stability_field(report::WidgetStabilityReport, column::Symbol)
    column === :name && return String(report.name)
    column === :family && return report.family
    column === :family_slug && return report.family_slug
    column === :surface && return String(report.surface)
    column === :status && return String(report.status)
    column === :catalog_source && return report.catalog_source
    column === :coverage_source && return report.coverage_source
    column === :stable && return string(report.stable)
    column === :coverage_complete && return string(report.coverage_complete)
    column === :ready && return string(report.ready)
    column === :missing_checks && return join((String(check) for check in report.missing_checks), ", ")
    column === :blockers && return join(report.blockers, "; ")
    throw(ArgumentError("widget stability column must be one of :name, :family, :family_slug, :surface, :status, :catalog_source, :coverage_source, :stable, :coverage_complete, :ready, :missing_checks, or :blockers"))
end

function _widget_coverage_issue(value)
    issue = _widget_catalog_filter(value, "coverage issue")
    issue in _WIDGET_COVERAGE_ISSUES ||
        throw(ArgumentError("widget coverage issue must be one of :complete, :missing_record, :source_mismatch, or :missing_checks"))
    return issue
end

function _widget_family_catalog_field(entry::WidgetFamilyEntry, column::Symbol)
    column === :family && return entry.name
    column === :family_slug && return entry.slug
    column === :count && return string(entry.count)
    column === :widgets && return _widget_family_catalog_widgets_text(entry)
    throw(ArgumentError("widget family catalog column must be one of :family, :family_slug, :count, or :widgets"))
end

function _widget_family_closeout_status_filter(value)
    value === nothing && return nothing
    value isa Symbol && value === :all && return nothing
    value isa AbstractString && lowercase(strip(value)) == "all" && return nothing
    status = _widget_catalog_filter(value, "family closeout status")
    status in (:ready, :blocked) ||
        throw(ArgumentError("widget family closeout status must be :ready, :blocked, :all, or nothing"))
    return status
end

function _widget_family_closeout_column(value)
    column = _widget_catalog_column(value)
    column in (
        :family,
        :family_slug,
        :status,
        :ready,
        :docs,
        :examples,
        :example_family_labels,
        :stable_api_tokens,
        :precompile_tokens,
        :notes,
        :blockers,
        :blocker_details,
    ) || throw(ArgumentError("widget family closeout column must be one of :family, :family_slug, :status, :ready, :docs, :examples, :example_family_labels, :stable_api_tokens, :precompile_tokens, :notes, :blockers, or :blocker_details"))
    return column
end

function _widget_family_closeout_columns(columns)
    selected = columns isa Symbol || columns isa AbstractString ?
        Symbol[_widget_family_closeout_column(columns)] :
        try
            Symbol[_widget_family_closeout_column(column) for column in columns]
        catch error
            error isa MethodError &&
                throw(ArgumentError("widget family closeout columns must be a Symbol, String, or iterable collection of Symbols or Strings"))
            rethrow()
        end
    isempty(selected) && throw(ArgumentError("widget family closeout report requires at least one column"))
    return selected
end

function _widget_family_closeout_field(report::WidgetFamilyCloseoutReport, column::Symbol)
    column === :family && return report.family
    column === :family_slug && return report.family_slug
    column === :status && return String(report.status)
    column === :ready && return string(report.ready)
    column === :docs && return join(report.docs, ", ")
    column === :examples && return join(report.examples, ", ")
    column === :example_family_labels && return join(report.example_family_labels, ", ")
    column === :stable_api_tokens && return join(report.stable_api_tokens, ", ")
    column === :precompile_tokens && return join(report.precompile_tokens, ", ")
    column === :notes && return report.notes
    column === :blockers && return isempty(report.blockers) ? "0" : string(length(report.blockers))
    column === :blocker_details && return join(report.blockers, "; ")
    throw(ArgumentError("widget family closeout column must be one of :family, :family_slug, :status, :ready, :docs, :examples, :example_family_labels, :stable_api_tokens, :precompile_tokens, :notes, :blockers, or :blocker_details"))
end

_escape_widget_catalog_markdown(value::AbstractString) =
    replace(value, "\\" => "\\\\", "|" => "\\|", "\n" => " ")

_escape_widget_catalog_markdown(value) =
    _escape_widget_catalog_markdown(string(value))

_escape_widget_catalog_tsv(value::AbstractString) =
    replace(value, "\t" => " ", "\r" => " ", "\n" => " ")

_escape_widget_catalog_tsv(value) =
    _escape_widget_catalog_tsv(string(value))

function _count_widget_catalog_by(entries, selector)
    counts = Dict{Any,Int}()
    for entry in entries
        key = selector(entry)
        counts[key] = get(counts, key, 0) + 1
    end
    return counts
end

function _read_widget_catalog(path::AbstractString=_WIDGET_CATALOG_PATH)
    isfile(path) || throw(ArgumentError("missing widget catalog ledger: $path"))
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("empty widget catalog ledger: $path"))
    header = split(first(lines), '\t'; keepempty=true)
    header == collect(_WIDGET_CATALOG_COLUMNS) ||
        throw(ArgumentError("widget catalog ledger must use columns: $(join(_WIDGET_CATALOG_COLUMNS, ", "))"))
    entries = WidgetCatalogEntry[]
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        isempty(strip(line)) && continue
        values = split(line, '\t'; keepempty=true)
        length(values) == length(header) ||
            throw(ArgumentError("invalid widget catalog row at $path:$(offset + 1)"))
        push!(
            entries,
            WidgetCatalogEntry(
                Symbol(values[1]),
                String(values[2]),
                Symbol(values[3]),
                Symbol(values[4]),
                String(values[5]),
            ),
        )
    end
    return sort!(entries; by=entry -> String(entry.name))
end

function _read_widget_vocabulary(path::AbstractString=_COMPONENT_CATALOG_PATH)
    isfile(path) || throw(ArgumentError("missing component catalog: $path"))
    lines = readlines(path)
    start = findfirst(==("## Public widget-name map"), lines)
    start === nothing && throw(ArgumentError("component catalog missing Public widget-name map"))
    any(offset -> occursin(_WIDGET_VOCABULARY_HEADER, lines[offset]), start:length(lines)) ||
        throw(ArgumentError("component catalog Public widget-name map missing expected table header"))
    entries = WidgetVocabularyEntry[]
    for offset in start:length(lines)
        line = lines[offset]
        offset != start && startswith(line, "## ") && break
        startswith(strip(line), "|") || continue
        occursin("|---", line) && continue
        occursin("Wicked API name", line) && continue
        values = String[]
        for value in split(line, "|")
            stripped = strip(value)
            isempty(stripped) || push!(values, stripped)
        end
        length(values) >= 3 || throw(ArgumentError("component catalog Public widget-name map row is malformed at line $offset"))
        widget_names = Symbol.(_widget_catalog_code_names(values[2]))
        isempty(widget_names) && throw(ArgumentError("component catalog Public widget-name map row has no Wicked API widget name at line $offset"))
        stateless = values[3] == "Stateless"
        state_contracts = stateless ? Symbol[] : Symbol.(_widget_catalog_code_names(values[3]))
        !stateless && isempty(state_contracts) &&
            throw(ArgumentError("component catalog Public widget-name map row has no state contract at line $offset"))
        push!(entries, WidgetVocabularyEntry(values[1], widget_names, state_contracts, stateless))
    end
    isempty(entries) && throw(ArgumentError("component catalog Public widget-name map has no rows"))
    return entries
end

function _widget_coverage_name(value::AbstractString)
    text = first(split(strip(value), '{'; limit=2))
    return Symbol(last(split(text, '.')))
end

function _read_widget_coverage(path::AbstractString=_WIDGET_COVERAGE_PATH)
    isfile(path) || throw(ArgumentError("missing widget coverage ledger: $path"))
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("empty widget coverage ledger: $path"))
    header = split(first(lines), '\t'; keepempty=true)
    header == collect(_WIDGET_COVERAGE_COLUMNS) ||
        throw(ArgumentError("widget coverage ledger must use columns: $(join(_WIDGET_COVERAGE_COLUMNS, ", "))"))
    rows = Dict{Symbol,NamedTuple}()
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        isempty(strip(line)) && continue
        values = split(line, '\t'; keepempty=true)
        length(values) == length(header) ||
            throw(ArgumentError("invalid widget coverage row at $path:$(offset + 1)"))
        name = _widget_coverage_name(values[1])
        rows[name] = (
            name=name,
            widget_type=String(values[1]),
            stateless=String(values[2]),
            stateful=String(values[3]),
            source=String(values[4]),
            zero_size=String(values[5]),
            minimal=String(values[6]),
            clipped=String(values[7]),
            resize=String(values[8]),
            state_transition=String(values[9]),
            snapshot=String(values[10]),
            toolkit=String(values[11]),
            semantics=String(values[12]),
            keyboard=String(values[13]),
            pointer=String(values[14]),
        )
    end
    return rows
end

_widget_family_closeout_list(value::AbstractString) =
    String[strip(part) for part in split(value, ',') if !isempty(strip(part))]

function _read_widget_family_evidence(path::AbstractString=_WIDGET_FAMILY_EVIDENCE_PATH)
    isfile(path) || throw(ArgumentError("missing widget family evidence ledger: $path"))
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("empty widget family evidence ledger: $path"))
    header = split(first(lines), '\t'; keepempty=true)
    header == collect(_WIDGET_FAMILY_EVIDENCE_COLUMNS) ||
        throw(ArgumentError("widget family evidence ledger must use columns: $(join(_WIDGET_FAMILY_EVIDENCE_COLUMNS, ", "))"))
    rows = NamedTuple[]
    for (offset, line) in enumerate(Iterators.drop(lines, 1))
        isempty(strip(line)) && continue
        values = split(line, '\t'; keepempty=true)
        length(values) == length(header) ||
            throw(ArgumentError("invalid widget family evidence row at $path:$(offset + 1)"))
        push!(
            rows,
            (
                family=String(values[1]),
                docs=_widget_family_closeout_list(values[2]),
                examples=_widget_family_closeout_list(values[3]),
                example_family_labels=_widget_family_closeout_list(values[4]),
                stable_api_tokens=_widget_family_closeout_list(values[5]),
                precompile_tokens=_widget_family_closeout_list(values[6]),
                notes=String(values[7]),
            ),
        )
    end
    return sort!(rows; by=row -> row.family)
end

function _read_experimental_promotion_plans(path::AbstractString=_EXPERIMENTAL_PROMOTION_PATH)
    isfile(path) || throw(ArgumentError("missing experimental promotion ledger: $path"))
    lines = readlines(path)
    isempty(lines) && throw(ArgumentError("empty experimental promotion ledger: $path"))
    header_index = findfirst(line -> !isempty(strip(line)) && !startswith(strip(line), "#"), lines)
    header_index === nothing && throw(ArgumentError("missing experimental promotion header in: $path"))
    header = split(lines[header_index], '\t'; keepempty=true)
    header == collect(_EXPERIMENTAL_PROMOTION_COLUMNS) ||
        throw(ArgumentError("experimental promotion ledger must use columns: $(join(_EXPERIMENTAL_PROMOTION_COLUMNS, ", "))"))
    rows = Dict{Symbol,NamedTuple{(:decision, :target, :review_status, :notes),NTuple{4,String}}}()
    for (offset, line) in enumerate(Iterators.drop(lines, header_index))
        isempty(strip(line)) && continue
        startswith(strip(line), "#") && continue
        values = split(line, '\t'; keepempty=true)
        length(values) == length(header) ||
            throw(ArgumentError("invalid experimental promotion row at $path:$(header_index + offset)"))
        name, decision, target, review_status, notes = values
        if haskey(rows, Symbol(name))
            throw(ArgumentError("duplicate experimental promotion row for `$name` at $path:$(header_index + offset)"))
        end
        rows[Symbol(name)] = (
            decision=String(decision),
            target=String(target),
            review_status=String(review_status),
            notes=String(notes),
        )
    end
    return rows
end

function _experimental_promotion_row(name::Symbol, plans)
    return get(plans, name, nothing)
end

function _experimental_promotion_action(plan)
    if plan === nothing
        return (
            decision="missing",
            target="",
            review_status="missing",
            notes="missing promotion/removal plan; add a row in api/experimental_promotions.tsv",
            required_decision="document, then promote/qualify/remove",
        )
    end
    decision = string(plan.decision)
    target = string(plan.target)
    review_status = string(plan.review_status)
    notes = string(plan.notes)
    required_decision = if !(review_status in _VALID_EXPERIMENTAL_REVIEW_STATUSES)
        "invalid review status `$review_status` in api/experimental_promotions.tsv"
    elseif !(decision in _VALID_EXPERIMENTAL_DECISIONS)
        "invalid decision `$decision` in api/experimental_promotions.tsv"
    elseif decision == "promote"
        if review_status in ("accepted", "completed")
            "promote to stable (review status: $review_status)"
        else
            "promotion decision accepted/complete required"
        end
    elseif decision == "qualify"
        "qualify this binding for compatibility or deprecation before stable"
    else
        "remove or migrate before stable"
    end
    return (
        decision=decision,
        target=target,
        review_status=review_status,
        notes=notes,
        required_decision=required_decision,
    )
end

function _experimental_widget_record_lookup(name; family=nothing)
    symbol = _widget_catalog_name(name)
    matches = [record for record in experimental_widget_records(; family=family) if record.name == symbol]
    isempty(matches) || return matches[1]
    family_filter = _widget_catalog_family_filter(family)
    if family_filter === nothing
        throw(ArgumentError("Wicked.Experimental binding is not exported for closeout: $symbol"))
    end
    throw(
        ArgumentError(
            "Wicked.Experimental binding `$symbol` is not exported for family filter $(repr(family)); " *
            "use the same symbol without a family filter or update the widget catalog/ledger",
        ),
    )
end

function _experimental_widget_readiness(record)
    blockers = String[
    ]
    if !record.cataloged
        push!(blockers, "binding is not present in reviewed stable widget catalog")
    end
    if record.decision == "missing"
        push!(blockers, "no experimental promotion plan exists in api/experimental_promotions.tsv")
    elseif record.decision != "promote"
        push!(blockers, "decision is $(record.decision); stabilize only when decision is `promote`")
    end
    if record.review_status == "missing"
        push!(blockers, "missing review status in experimental promotion ledger")
    elseif record.review_status == "proposed"
        push!(blockers, "promotion review status is `proposed`; require accepted or completed")
    elseif !(record.review_status in _VALID_EXPERIMENTAL_REVIEW_STATUSES)
        push!(blockers, "invalid review status `$(record.review_status)` in experimental promotion ledger")
    end
    if record.decision == "promote" && record.review_status in ("accepted", "completed") && isempty(strip(record.target))
        push!(blockers, "target is empty for a promote decision")
    end
    return (
        ready=(isempty(blockers) && record.decision == "promote" && record.review_status in ("accepted", "completed") && record.cataloged),
        blockers=blockers,
    )
end

function _widget_family_closeout_missing_paths(paths, label::AbstractString)
    blockers = String[]
    for path in paths
        normalized = normpath(joinpath(_WIDGET_CATALOG_ROOT, path))
        if !startswith(normalized, _WIDGET_CATALOG_ROOT) || !isfile(normalized)
            push!(blockers, "references missing $label path: $path")
        end
    end
    return blockers
end

function _widget_family_closeout_report(row)
    blockers = String[]
    family_slug = _widget_catalog_family_slug_text(row.family)
    isempty(row.docs) && push!(blockers, "missing documentation paths")
    append!(blockers, _widget_family_closeout_missing_paths(row.docs, "documentation"))
    isempty(row.examples) && push!(blockers, "missing public example paths")
    append!(blockers, _widget_family_closeout_missing_paths(row.examples, "example"))
    isempty(row.example_family_labels) && push!(blockers, "missing example family labels")
    isempty(row.stable_api_tokens) && push!(blockers, "missing stable API tokens")
    isempty(row.precompile_tokens) && push!(blockers, "missing precompile tokens")
    isempty(strip(row.notes)) && push!(blockers, "missing closeout notes")
    ready = isempty(blockers)
    return WidgetFamilyCloseoutReport(
        row.family,
        family_slug,
        ready,
        ready ? :ready : :blocked,
        copy(row.docs),
        copy(row.examples),
        copy(row.example_family_labels),
        copy(row.stable_api_tokens),
        copy(row.precompile_tokens),
        row.notes,
        blockers,
    )
end

function _widget_coverage_value_complete(value::AbstractString)
    normalized = lowercase(strip(value))
    return !isempty(normalized) && !(normalized in ("missing", "todo", "tbd"))
end

"""
    widget_vocabulary()

Return the reviewed cross-library widget vocabulary used when porting examples
from Ratatui, Textual, TamboUI, or Lanterna to Wicked API names.
"""
widget_vocabulary() = _read_widget_vocabulary()

"""
    widget_vocabulary_records()

Return cross-library widget vocabulary rows as plain named tuples.
"""
function widget_vocabulary_records()
    return [
        (
            concept=entry.concept,
            widgets=copy(entry.widgets),
            state_contracts=copy(entry.state_contracts),
            stateless=entry.stateless,
        )
        for entry in widget_vocabulary()
    ]
end

"""
    search_widget_vocabulary(query)

Search cross-library widget vocabulary by concept, Wicked widget name, state
contract, or stateless/stateful marker.
"""
function search_widget_vocabulary(query)
    prepared_query = _widget_catalog_search_query(query)
    return WidgetVocabularyEntry[
        entry for entry in widget_vocabulary()
        if _widget_vocabulary_query_matches(entry, prepared_query)
    ]
end

"""
    widget_vocabulary_entry(concept)

Return the exact cross-library vocabulary entry for `concept`, or `nothing`.
"""
function widget_vocabulary_entry(concept::AbstractString)
    normalized = lowercase(strip(concept))
    for entry in widget_vocabulary()
        lowercase(entry.concept) == normalized && return entry
    end
    return nothing
end

widget_vocabulary_entry(concept::Symbol) = widget_vocabulary_entry(String(concept))

"""
    widget_vocabulary_widget_names(concept_or_query)

Return Wicked API widget names for an exact vocabulary concept when possible, or
for every row matching `concept_or_query` otherwise.
"""
function widget_vocabulary_widget_names(concept_or_query)
    entry = concept_or_query isa Symbol || concept_or_query isa AbstractString ?
        widget_vocabulary_entry(concept_or_query) : nothing
    if entry !== nothing
        return copy(entry.widgets)
    end
    names = Symbol[]
    for match in search_widget_vocabulary(concept_or_query)
        append!(names, match.widgets)
    end
    return unique(names)
end

_widget_vocabulary_widgets_text(entry::WidgetVocabularyEntry) =
    join((String(name) for name in entry.widgets), ", ")

_widget_vocabulary_states_text(entry::WidgetVocabularyEntry) =
    entry.stateless ? "Stateless" : join((String(name) for name in entry.state_contracts), ", ")

"""
    widget_vocabulary_markdown()

Render the cross-library widget vocabulary as Markdown.
"""
function widget_vocabulary_markdown()
    rows = String["| `concept` | `widgets` | `state_contracts` |", "| --- | --- | --- |"]
    for entry in widget_vocabulary()
        push!(
            rows,
            "| $(_escape_widget_catalog_markdown(entry.concept)) | $(_escape_widget_catalog_markdown(_widget_vocabulary_widgets_text(entry))) | $(_escape_widget_catalog_markdown(_widget_vocabulary_states_text(entry))) |",
        )
    end
    return join(rows, "\n")
end

"""
    widget_vocabulary_tsv(; header=true)

Render the cross-library widget vocabulary as tab-separated values.
"""
function widget_vocabulary_tsv(; header::Bool=true)
    rows = header ? String["concept\twidgets\tstate_contracts"] : String[]
    for entry in widget_vocabulary()
        push!(
            rows,
            "$(_escape_widget_catalog_tsv(entry.concept))\t$(_escape_widget_catalog_tsv(_widget_vocabulary_widgets_text(entry)))\t$(_escape_widget_catalog_tsv(_widget_vocabulary_states_text(entry)))",
        )
    end
    return join(rows, "\n")
end

"""
    stable_widget_catalog(; status=nothing, surface=nothing, family=nothing)

Return reviewed widget stabilization entries.

Use `status=:stable` and `surface=:stable` to list widgets that are available
through `Wicked.API` with complete promotion evidence. Use `family` to restrict
the result to a cross-library family such as `"Inputs and controls"`.
"""
function stable_widget_catalog(; status=nothing, surface=nothing, family=nothing)
    status_filter = _widget_catalog_filter(status, "status")
    surface_filter = _widget_catalog_filter(surface, "surface")
    family_filter = _widget_catalog_family_filter(family)
    return WidgetCatalogEntry[
        entry for entry in _read_widget_catalog()
        if (status_filter === nothing || entry.status == status_filter) &&
            (surface_filter === nothing || entry.surface == surface_filter) &&
            _widget_catalog_family_matches(entry, family_filter)
    ]
end

"""
    widget_catalog(; status=nothing, surface=nothing, family=nothing)

Alias for `stable_widget_catalog` used by developer tooling and documentation.
"""
widget_catalog(; status=nothing, surface=nothing, family=nothing) =
    stable_widget_catalog(; status=status, surface=surface, family=family)

"""
    stable_widget_names(; status=:stable, surface=:stable, family=nothing)

Return stable widget names as symbols. By default this lists widgets that are
available through the stable `Wicked.API` surface.
"""
function stable_widget_names(; status=:stable, surface=:stable, family=nothing)
    return Symbol[
        entry.name for entry in stable_widget_catalog(; status=status, surface=surface, family=family)
    ]
end

"""
    stable_widget_count(; status=:stable, surface=:stable, family=nothing)

Return the number of reviewed widget catalog entries that match the filters.
"""
stable_widget_count(; status=:stable, surface=:stable, family=nothing) =
    length(stable_widget_catalog(; status=status, surface=surface, family=family))

"""
    widget_catalog_family(entry_or_name)

Return the stabilization family for a reviewed widget catalog entry, widget
name, public widget type, or widget instance.
"""
function widget_catalog_family(entry::WidgetCatalogEntry)
    return get(_WIDGET_CATALOG_FAMILY_BY_NAME, entry.name, _WIDGET_CATALOG_FALLBACK_FAMILY)
end

function widget_catalog_family(name)
    entry = assert_stable_widget(name; catalog=stable_widget_catalog(status=nothing, surface=nothing))
    return widget_catalog_family(entry)
end

"""
    widget_catalog_family_slug(entry_or_name_or_family)

Return a stable kebab-case family slug for a reviewed widget catalog entry,
widget name, public widget type, widget instance, or known family name.
"""
widget_catalog_family_slug(entry::WidgetCatalogEntry) =
    _widget_catalog_family_slug_text(widget_catalog_family(entry))

function widget_catalog_family_slug(value)
    family_filter = value isa Symbol || value isa AbstractString ?
        _widget_catalog_family_filter(value) : nothing
    if family_filter !== nothing
        for family in stable_widget_families(status=nothing, surface=nothing)
            _normalize_widget_catalog_family(family) == family_filter &&
                return _widget_catalog_family_slug_text(family)
        end
    end
    return widget_catalog_family_slug(assert_stable_widget(value; catalog=stable_widget_catalog(status=nothing, surface=nothing)))
end

"""
    stable_widget_families(; status=:stable, surface=:stable)

Return sorted widget stabilization family names present in the reviewed catalog.
"""
function stable_widget_families(; status=:stable, surface=:stable)
    families = Set{String}()
    for entry in stable_widget_catalog(; status=status, surface=surface)
        push!(families, widget_catalog_family(entry))
    end
    return sort!(collect(families))
end

"""
    stable_widget_family_slugs(; status=:stable, surface=:stable)

Return sorted stable kebab-case slugs for the widget stabilization families
present in the reviewed catalog.
"""
stable_widget_family_slugs(; status=:stable, surface=:stable) =
    sort!([_widget_catalog_family_slug_text(family) for family in stable_widget_families(; status=status, surface=surface)])

"""
    widget_families_text(; status=:stable, surface=:stable)

Render reviewed widget family names as newline-separated text.
"""
widget_families_text(; status=:stable, surface=:stable) =
    join(stable_widget_families(; status=status, surface=surface), "\n")

"""
    widget_family_slugs_text(; status=:stable, surface=:stable)

Render reviewed widget family slugs as newline-separated text.
"""
widget_family_slugs_text(; status=:stable, surface=:stable) =
    join(stable_widget_family_slugs(; status=status, surface=surface), "\n")

"""
    widget_names_text(; status=:stable, surface=:stable, family=nothing)

Render reviewed widget names as newline-separated text.
"""
widget_names_text(; status=:stable, surface=:stable, family=nothing) =
    join((String(name) for name in stable_widget_names(; status=status, surface=surface, family=family)), "\n")

"""
    search_widget_names_text(query; status=:stable, surface=:stable, family=nothing)

Search reviewed widget catalog entries and render matching widget names as
newline-separated text.
"""
search_widget_names_text(query; status=:stable, surface=:stable, family=nothing) =
    join((String(entry.name) for entry in search_widgets(query; status=status, surface=surface, family=family)), "\n")

"""
    widget_source_files(; status=:stable, surface=:stable, family=nothing)

Return sorted source files that provide reviewed widget catalog entries.
"""
function widget_source_files(; status=:stable, surface=:stable, family=nothing)
    return sort!(collect(Set(entry.source for entry in stable_widget_catalog(; status=status, surface=surface, family=family))))
end

"""
    widget_source_files_text(; status=:stable, surface=:stable, family=nothing)

Render reviewed widget source files as newline-separated text.
"""
widget_source_files_text(; status=:stable, surface=:stable, family=nothing) =
    join(widget_source_files(; status=status, surface=surface, family=family), "\n")

"""
    search_widget_source_files_text(query; status=:stable, surface=:stable, family=nothing)

Search reviewed widget catalog entries and render matching source files as
newline-separated text.
"""
function search_widget_source_files_text(query; status=:stable, surface=:stable, family=nothing)
    sources = sort!(collect(Set(entry.source for entry in search_widgets(query; status=status, surface=surface, family=family))))
    return join(sources, "\n")
end

"""
    widget_source_summary(; status=:stable, surface=:stable, family=nothing)

Return sorted source-file summaries with `source`, `count`, and `widgets`
fields for reviewed widget catalog entries.
"""
function widget_source_summary(; status=:stable, surface=:stable, family=nothing)
    grouped = group_widgets(:source; status=status, surface=surface, family=family)
    rows = [
        (source=source, count=length(entries), widgets=Symbol[entry.name for entry in entries])
        for (source, entries) in grouped
    ]
    return sort!(rows; by=row -> row.source)
end

_widget_source_summary_widgets_text(row) = join((String(name) for name in row.widgets), ", ")

"""
    widget_source_summary_markdown(; status=:stable, surface=:stable, family=nothing)

Render reviewed widget source summaries as a GitHub-flavored Markdown table.
"""
function widget_source_summary_markdown(; status=:stable, surface=:stable, family=nothing)
    rows = String["| `source` | `count` | `widgets` |", "| --- | --- | --- |"]
    for row in widget_source_summary(; status=status, surface=surface, family=family)
        widgets = _escape_widget_catalog_markdown(_widget_source_summary_widgets_text(row))
        push!(rows, "| $(_escape_widget_catalog_markdown(row.source)) | $(row.count) | $widgets |")
    end
    return join(rows, "\n")
end

"""
    widget_source_summary_tsv(; status=:stable, surface=:stable, family=nothing, header=true)

Render reviewed widget source summaries as tab-separated values.
"""
function widget_source_summary_tsv(; status=:stable, surface=:stable, family=nothing, header::Bool=true)
    rows = header ? String["source\tcount\twidgets"] : String[]
    for row in widget_source_summary(; status=status, surface=surface, family=family)
        widgets = _escape_widget_catalog_tsv(_widget_source_summary_widgets_text(row))
        push!(rows, "$(_escape_widget_catalog_tsv(row.source))\t$(row.count)\t$widgets")
    end
    return join(rows, "\n")
end

"""
    widget_family_summary(; status=:stable, surface=:stable, family=nothing)

Return sorted family summaries with `family`, `count`, and `widgets` fields for
reviewed widget catalog entries.
"""
function widget_family_summary(; status=:stable, surface=:stable, family=nothing)
    grouped = group_widgets(:family; status=status, surface=surface, family=family)
    rows = [
        (family=family, count=length(entries), widgets=Symbol[entry.name for entry in entries])
        for (family, entries) in grouped
    ]
    return sort!(rows; by=row -> row.family)
end

_widget_family_summary_widgets_text(row) = join((String(name) for name in row.widgets), ", ")

"""
    widget_family_summary_markdown(; status=:stable, surface=:stable, family=nothing)

Render reviewed widget family summaries as a GitHub-flavored Markdown table.
"""
function widget_family_summary_markdown(; status=:stable, surface=:stable, family=nothing)
    rows = String["| `family` | `count` | `widgets` |", "| --- | --- | --- |"]
    for row in widget_family_summary(; status=status, surface=surface, family=family)
        widgets = _escape_widget_catalog_markdown(_widget_family_summary_widgets_text(row))
        push!(rows, "| $(_escape_widget_catalog_markdown(row.family)) | $(row.count) | $widgets |")
    end
    return join(rows, "\n")
end

"""
    widget_family_summary_tsv(; status=:stable, surface=:stable, family=nothing, header=true)

Render reviewed widget family summaries as tab-separated values.
"""
function widget_family_summary_tsv(; status=:stable, surface=:stable, family=nothing, header::Bool=true)
    rows = header ? String["family\tcount\twidgets"] : String[]
    for row in widget_family_summary(; status=status, surface=surface, family=family)
        widgets = _escape_widget_catalog_tsv(_widget_family_summary_widgets_text(row))
        push!(rows, "$(_escape_widget_catalog_tsv(row.family))\t$(row.count)\t$widgets")
    end
    return join(rows, "\n")
end

"""
    search_widgets(query; status=:stable, surface=:stable, family=nothing)

Search reviewed widget catalog entries by widget name, source path, surface,
status, or promotion reason. `query` may be a `String`, `Symbol`, or `Regex`.
String and symbol queries are case-insensitive.
"""
function search_widgets(query; status=:stable, surface=:stable, family=nothing)
    prepared_query = _widget_catalog_search_query(query)
    return WidgetCatalogEntry[
        entry for entry in stable_widget_catalog(; status=status, surface=surface, family=family)
        if _widget_catalog_query_matches(entry, prepared_query)
    ]
end

"""
    search_widget_count(query; status=:stable, surface=:stable, family=nothing)

Return the number of reviewed widget catalog entries matching `query`.
"""
search_widget_count(query; status=:stable, surface=:stable, family=nothing) =
    length(search_widgets(query; status=status, surface=surface, family=family))

"""
    group_widgets(by=:source; status=:stable, surface=:stable, family=nothing)

Group reviewed widget catalog entries by `:family`, `:source`, `:surface`, or
`:status`. Keys are strings so the result is convenient for generated docs and
galleries.
"""
function group_widgets(by=:source; status=:stable, surface=:stable, family=nothing)
    grouped = Dict{String,Vector{WidgetCatalogEntry}}()
    for entry in stable_widget_catalog(; status=status, surface=surface, family=family)
        key = _widget_catalog_group_key(entry, by)
        push!(get!(grouped, key, WidgetCatalogEntry[]), entry)
    end
    for entries in values(grouped)
        sort!(entries; by=entry -> String(entry.name))
    end
    return grouped
end

"""
    stable_widget_family_catalog(; status=:stable, surface=:stable, family=nothing)

Return reviewed widget family descriptors with display name, stable slug, widget
count, and widget names.
"""
function stable_widget_family_catalog(; status=:stable, surface=:stable, family=nothing)
    rows = WidgetFamilyEntry[]
    for (family_name, entries) in group_widgets(:family; status=status, surface=surface, family=family)
        push!(
            rows,
            WidgetFamilyEntry(
                family_name,
                _widget_catalog_family_slug_text(family_name),
                length(entries),
                Symbol[entry.name for entry in entries],
            ),
        )
    end
    return sort!(rows; by=entry -> entry.slug)
end

"""
    widget_family_records(; status=:stable, surface=:stable, family=nothing)

Return reviewed widget family descriptors as plain named tuples.
"""
function widget_family_records(; status=:stable, surface=:stable, family=nothing)
    return [
        (
            name=entry.name,
            slug=entry.slug,
            count=entry.count,
            widgets=copy(entry.widgets),
        )
        for entry in stable_widget_family_catalog(; status=status, surface=surface, family=family)
    ]
end

_widget_family_catalog_widgets_text(entry::WidgetFamilyEntry) =
    join((String(name) for name in entry.widgets), ", ")

"""
    widget_family_catalog_markdown(; status=:stable, surface=:stable, family=nothing, columns=(:family, :family_slug, :count, :widgets))

Render reviewed widget family descriptors as a GitHub-flavored Markdown table.
"""
function widget_family_catalog_markdown(;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:family, :family_slug, :count, :widgets),
)
    selected = _widget_family_catalog_columns(columns)
    header = join(("`$(String(column))`" for column in selected), " | ")
    separator = join(fill("---", length(selected)), " | ")
    rows = String["| $header |", "| $separator |"]
    for entry in stable_widget_family_catalog(; status=status, surface=surface, family=family)
        row = join((_escape_widget_catalog_markdown(_widget_family_catalog_field(entry, column)) for column in selected), " | ")
        push!(rows, "| $row |")
    end
    return join(rows, "\n")
end

"""
    widget_family_catalog_tsv(; status=:stable, surface=:stable, family=nothing, columns=(:family, :family_slug, :count, :widgets), header=true)

Render reviewed widget family descriptors as tab-separated values.
"""
function widget_family_catalog_tsv(;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:family, :family_slug, :count, :widgets),
    header::Bool=true,
)
    selected = _widget_family_catalog_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for entry in stable_widget_family_catalog(; status=status, surface=surface, family=family)
        push!(rows, join((_escape_widget_catalog_tsv(_widget_family_catalog_field(entry, column)) for column in selected), "\t"))
    end
    return join(rows, "\n")
end

"""
    search_widget_families(query; status=:stable, surface=:stable)

Search reviewed widget family descriptors by family name, slug, count, or
included widget names. `query` may be a `String`, `Symbol`, or `Regex`.
"""
function search_widget_families(query; status=:stable, surface=:stable)
    prepared_query = _widget_catalog_search_query(query)
    return WidgetFamilyEntry[
        entry for entry in stable_widget_family_catalog(; status=status, surface=surface)
        if _widget_family_catalog_query_matches(entry, prepared_query)
    ]
end

"""
    search_widget_family_count(query; status=:stable, surface=:stable)

Return the number of reviewed widget families matching `query`.
"""
search_widget_family_count(query; status=:stable, surface=:stable) =
    length(search_widget_families(query; status=status, surface=surface))

"""
    search_widget_family_catalog_markdown(query; status=:stable, surface=:stable, columns=(:family, :family_slug, :count, :widgets))

Search reviewed widget family descriptors and render matches as a
GitHub-flavored Markdown table.
"""
function search_widget_family_catalog_markdown(
    query;
    status=:stable,
    surface=:stable,
    columns=(:family, :family_slug, :count, :widgets),
)
    selected = _widget_family_catalog_columns(columns)
    header = join(("`$(String(column))`" for column in selected), " | ")
    separator = join(fill("---", length(selected)), " | ")
    rows = String["| $header |", "| $separator |"]
    for entry in search_widget_families(query; status=status, surface=surface)
        row = join((_escape_widget_catalog_markdown(_widget_family_catalog_field(entry, column)) for column in selected), " | ")
        push!(rows, "| $row |")
    end
    return join(rows, "\n")
end

"""
    search_widget_family_catalog_tsv(query; status=:stable, surface=:stable, columns=(:family, :family_slug, :count, :widgets), header=true)

Search reviewed widget family descriptors and render matches as tab-separated
values.
"""
function search_widget_family_catalog_tsv(
    query;
    status=:stable,
    surface=:stable,
    columns=(:family, :family_slug, :count, :widgets),
    header::Bool=true,
)
    selected = _widget_family_catalog_columns(columns)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for entry in search_widget_families(query; status=status, surface=surface)
        push!(rows, join((_escape_widget_catalog_tsv(_widget_family_catalog_field(entry, column)) for column in selected), "\t"))
    end
    return join(rows, "\n")
end

"""
    widget_family_widgets(family; status=:stable, surface=:stable)

Return reviewed widget catalog entries for one existing widget family. Unlike a
raw `stable_widget_catalog(family=...)` filter, this helper throws when the
family is not present in the reviewed family catalog.
"""
function widget_family_widgets(family; status=:stable, surface=:stable)
    entry = assert_stable_widget_family(
        family;
        catalog=stable_widget_family_catalog(; status=status, surface=surface),
    )
    return stable_widget_catalog(; status=status, surface=surface, family=entry.name)
end

"""
    widget_family_widget_names(family; status=:stable, surface=:stable)

Return reviewed widget names for one existing widget family.
"""
widget_family_widget_names(family; status=:stable, surface=:stable) =
    Symbol[entry.name for entry in widget_family_widgets(family; status=status, surface=surface)]

"""
    widget_family_widget_count(family; status=:stable, surface=:stable)

Return the number of reviewed widgets in one existing widget family.
"""
widget_family_widget_count(family; status=:stable, surface=:stable) =
    length(widget_family_widgets(family; status=status, surface=surface))

"""
    widget_family_closeout_reports(; family=nothing, status=:all)

Return family-level stabilization closeout reports backed by
`api/widget_family_evidence.tsv`. Use `family` to focus one reviewed family and
`status=:ready` or `status=:blocked` to filter the closeout loop.
"""
function widget_family_closeout_reports(; family=nothing, status=:all)
    family_filter = _widget_catalog_family_filter(family)
    status_filter = _widget_family_closeout_status_filter(status)
    reports = WidgetFamilyCloseoutReport[
        _widget_family_closeout_report(row)
        for row in _read_widget_family_evidence()
    ]
    return WidgetFamilyCloseoutReport[
        report for report in reports
        if (family_filter === nothing || _normalize_widget_catalog_family(report.family) == family_filter || report.family_slug == _widget_catalog_family_slug_text(family_filter)) &&
            (status_filter === nothing || report.status == status_filter)
    ]
end

"""
    widget_family_closeout_report(family)

Return the family-level stabilization closeout report for one family, or throw
when the family is absent from `api/widget_family_evidence.tsv`.
"""
function widget_family_closeout_report(family)
    reports = widget_family_closeout_reports(family=family, status=:all)
    isempty(reports) &&
        throw(ArgumentError("widget family is not present in the closeout evidence ledger: $(family)"))
    return first(reports)
end

"""
    widget_family_closeout_records(; family=nothing, status=:all)

Return family closeout reports as plain named tuples for dashboards, generated
docs, and application release checks.
"""
function widget_family_closeout_records(; family=nothing, status=:all)
    return [
        (
            family=report.family,
            family_slug=report.family_slug,
            ready=report.ready,
            status=report.status,
            docs=copy(report.docs),
            examples=copy(report.examples),
            example_family_labels=copy(report.example_family_labels),
            stable_api_tokens=copy(report.stable_api_tokens),
            precompile_tokens=copy(report.precompile_tokens),
            notes=report.notes,
            blockers=copy(report.blockers),
        )
        for report in widget_family_closeout_reports(; family=family, status=status)
    ]
end

"""
    widget_family_closeout_gaps(; family=nothing)

Return family closeout reports that still have stabilization blockers.
"""
widget_family_closeout_gaps(; family=nothing) =
    widget_family_closeout_reports(; family=family, status=:blocked)

"""
    widget_family_closeout_summary(; family=nothing)

Return `total`, `ready`, and `blocked` counts for family closeout reports.
"""
function widget_family_closeout_summary(; family=nothing)
    reports = widget_family_closeout_reports(; family=family, status=:all)
    ready = count(report -> report.ready, reports)
    blocked = length(reports) - ready
    return (total=length(reports), ready=ready, blocked=blocked)
end

"""
    widget_family_closeout_complete(; family=nothing)

Return `true` when all matching family closeout reports have no source-level
stabilization blockers.
"""
widget_family_closeout_complete(; family=nothing) =
    family === nothing ? isempty(widget_family_closeout_gaps()) : widget_family_closeout_ready(family)

"""
    widget_family_closeout_ready(family)

Return `true` when one family has no source-level closeout blockers.
"""
widget_family_closeout_ready(family) = widget_family_closeout_report(family).ready

"""
    assert_widget_family_closeout_complete(; family=nothing)

Return `true` when every matching family closeout report is ready, or throw an
`ArgumentError` naming blocked families and their blocker counts.
"""
function assert_widget_family_closeout_complete(; family=nothing)
    if family !== nothing
        assert_widget_family_closeout_ready(family)
        return true
    end
    gaps = widget_family_closeout_gaps(; family=family)
    isempty(gaps) && return true
    details = join((
        "$(report.family) ($(length(report.blockers)) blockers)"
        for report in Iterators.take(gaps, 5)
    ), "; ")
    throw(ArgumentError("widget family closeout has blocked families: $details"))
end

"""
    assert_widget_family_closeout_ready(family)

Return the closeout report for `family`, or throw an `ArgumentError` listing
the source-level blockers.
"""
function assert_widget_family_closeout_ready(family)
    report = widget_family_closeout_report(family)
    report.ready && return report
    throw(ArgumentError("widget family $(report.family) is not ready for closeout: $(join(report.blockers, "; "))"))
end

function _widget_family_closeout_markdown(reports, selected)
    header = join(("`$(String(column))`" for column in selected), " | ")
    separator = join(fill("---", length(selected)), " | ")
    rows = String["| $header |", "| $separator |"]
    for report in reports
        push!(rows, "| $(join((_escape_widget_catalog_markdown(_widget_family_closeout_field(report, column)) for column in selected), " | ")) |")
    end
    return join(rows, "\n")
end

function _widget_family_closeout_tsv(reports, selected; header::Bool=true)
    rows = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for report in reports
        push!(rows, join((_escape_widget_catalog_tsv(_widget_family_closeout_field(report, column)) for column in selected), "\t"))
    end
    return join(rows, "\n")
end

"""
    widget_family_closeout_markdown(; family=nothing, status=:all, columns=(:family, :status, :docs, :examples, :blockers, :blocker_details))

Render family closeout reports as a GitHub-flavored Markdown table.
"""
function widget_family_closeout_markdown(;
    family=nothing,
    status=:all,
    columns=(:family, :status, :docs, :examples, :blockers, :blocker_details),
)
    selected = _widget_family_closeout_columns(columns)
    return _widget_family_closeout_markdown(widget_family_closeout_reports(; family=family, status=status), selected)
end

"""
    widget_family_closeout_tsv(; family=nothing, status=:all, columns=(:family, :status, :docs, :examples, :blockers, :blocker_details), header=true)

Render family closeout reports as tab-separated values.
"""
function widget_family_closeout_tsv(;
    family=nothing,
    status=:all,
    columns=(:family, :status, :docs, :examples, :blockers, :blocker_details),
    header::Bool=true,
)
    selected = _widget_family_closeout_columns(columns)
    return _widget_family_closeout_tsv(widget_family_closeout_reports(; family=family, status=status), selected; header=header)
end

"""
    widget_family_closeout_json(; family=nothing, status=:all)

Render family closeout reports as a schema-versioned JSON document for release
dashboards, CI artifacts, and downstream tooling.
"""
function widget_family_closeout_json(; family=nothing, status=:all)
    status_filter = _widget_family_closeout_status_filter(status)
    status_label = status_filter === nothing ? "all" : String(status_filter)
    records = widget_family_closeout_records(; family=family, status=status)
    ready = count(record -> record.ready, records)
    blocked = length(records) - ready
    lines = String[
        "{",
        "  \"schema_version\": 1,",
        "  \"status\": $(_widget_coverage_json_string(status_label)),",
        "  \"summary\": {\"total\": $(length(records)), \"ready\": $(ready), \"blocked\": $(blocked)},",
        "  \"records\": [",
    ]
    for (index, record) in enumerate(records)
        suffix = index == length(records) ? "" : ","
        push!(
            lines,
            "    {\"family\": $(_widget_coverage_json_string(record.family)), \"family_slug\": $(_widget_coverage_json_string(record.family_slug)), \"ready\": $(record.ready), \"status\": $(_widget_coverage_json_string(record.status)), \"docs\": $(_widget_stability_json_array(record.docs)), \"examples\": $(_widget_stability_json_array(record.examples)), \"example_family_labels\": $(_widget_stability_json_array(record.example_family_labels)), \"stable_api_tokens\": $(_widget_stability_json_array(record.stable_api_tokens)), \"precompile_tokens\": $(_widget_stability_json_array(record.precompile_tokens)), \"notes\": $(_widget_coverage_json_string(record.notes)), \"blockers\": $(_widget_stability_json_array(record.blockers))}$suffix",
        )
    end
    push!(lines, "  ]")
    push!(lines, "}")
    return join(lines, "\n")
end

"""
    widget_family_closeout_artifacts(; family=nothing, status=:all, columns=(:family, :status, :docs, :examples, :blockers, :blocker_details), header=true)

Return one schema-versioned family closeout artifact bundle containing
structured records plus Markdown, TSV, and JSON renderings.
"""
function widget_family_closeout_artifacts(;
    family=nothing,
    status=:all,
    columns=(:family, :status, :docs, :examples, :blockers, :blocker_details),
    header::Bool=true,
)
    selected = _widget_family_closeout_columns(columns)
    reports = widget_family_closeout_reports(; family=family, status=status)
    records = widget_family_closeout_records(; family=family, status=status)
    ready = count(record -> record.ready, records)
    blocked = length(records) - ready
    return (
        schema_version=1,
        status=status,
        summary=(total=length(records), ready=ready, blocked=blocked),
        complete=blocked == 0,
        records=records,
        markdown=_widget_family_closeout_markdown(reports, selected),
        tsv=_widget_family_closeout_tsv(reports, selected; header=header),
        json=widget_family_closeout_json(; family=family, status=status),
    )
end

"""
    widget_family_closeout_artifacts_json(; family=nothing, status=:all)

Render the schema-versioned family closeout artifact bundle as JSON.
"""
function widget_family_closeout_artifacts_json(; family=nothing, status=:all)
    artifacts = widget_family_closeout_artifacts(; family=family, status=status)
    return join((
        "{",
        "  \"schema_version\": $(artifacts.schema_version),",
        "  \"complete\": $(artifacts.complete),",
        "  \"summary\": {\"total\": $(artifacts.summary.total), \"ready\": $(artifacts.summary.ready), \"blocked\": $(artifacts.summary.blocked)},",
        "  \"closeout\": $(artifacts.json)",
        "}",
    ), "\n")
end

"""
    widget_family_closeout_artifacts_text(; family=nothing, status=:all)

Render the family closeout artifact bundle as compact multiline text for CI
logs and release notes.
"""
function widget_family_closeout_artifacts_text(; family=nothing, status=:all)
    artifacts = widget_family_closeout_artifacts(; family=family, status=status)
    lines = String[
        "schema_version=$(artifacts.schema_version)",
        "complete=$(artifacts.complete)",
        "summary total=$(artifacts.summary.total) ready=$(artifacts.summary.ready) blocked=$(artifacts.summary.blocked)",
    ]
    isempty(artifacts.records) || push!(lines, "records=$(length(artifacts.records))")
    return join(lines, "\n")
end

"""
    widget_family_closeout_artifacts_markdown(; family=nothing, status=:all)

Render the family closeout artifact bundle as a compact GitHub-flavored
Markdown metrics table.
"""
function widget_family_closeout_artifacts_markdown(; family=nothing, status=:all)
    artifacts = widget_family_closeout_artifacts(; family=family, status=status)
    rows = [
        (metric="schema_version", value=artifacts.schema_version),
        (metric="complete", value=artifacts.complete),
        (metric="total", value=artifacts.summary.total),
        (metric="ready", value=artifacts.summary.ready),
        (metric="blocked", value=artifacts.summary.blocked),
    ]
    output = String["| `metric` | `value` |", "| --- | --- |"]
    append!(
        output,
        "| $(_escape_widget_catalog_markdown(row.metric)) | $(_escape_widget_catalog_markdown(row.value)) |"
        for row in rows
    )
    return join(output, "\n")
end

"""
    widget_family_closeout_artifacts_tsv(; family=nothing, status=:all, header=true)

Render the family closeout artifact bundle as tab-separated metric rows.
"""
function widget_family_closeout_artifacts_tsv(; family=nothing, status=:all, header::Bool=true)
    artifacts = widget_family_closeout_artifacts(; family=family, status=status)
    rows = [
        (metric="schema_version", value=artifacts.schema_version),
        (metric="complete", value=artifacts.complete),
        (metric="total", value=artifacts.summary.total),
        (metric="ready", value=artifacts.summary.ready),
        (metric="blocked", value=artifacts.summary.blocked),
    ]
    output = header ? String["metric\tvalue"] : String[]
    append!(
        output,
        "$(_escape_widget_catalog_tsv(row.metric))\t$(_escape_widget_catalog_tsv(row.value))"
        for row in rows
    )
    return join(output, "\n")
end

"""
    widget_family_entry(family; catalog=stable_widget_family_catalog(status=nothing, surface=nothing))

Return the descriptor for a family name or slug, or `nothing` when it is absent.
"""
function widget_family_entry(family; catalog=stable_widget_family_catalog(status=nothing, surface=nothing))
    family_filter = _widget_catalog_family_filter(family)
    for entry in catalog
        (_normalize_widget_catalog_family(entry.name) == family_filter || entry.slug == family_filter) &&
            return entry
    end
    return nothing
end

"""
    is_stable_widget_family(family; catalog=stable_widget_family_catalog())

Return `true` when `family` is present in the reviewed stable widget family
catalog.
"""
is_stable_widget_family(family; catalog=stable_widget_family_catalog()) =
    widget_family_entry(family; catalog=catalog) !== nothing

"""
    assert_stable_widget_family(family; catalog=stable_widget_family_catalog())

Return the reviewed stable family descriptor for `family`, or throw an
`ArgumentError` when it is not present.
"""
function assert_stable_widget_family(family; catalog=stable_widget_family_catalog())
    entry = widget_family_entry(family; catalog=catalog)
    entry !== nothing && return entry
    throw(ArgumentError("widget family is not part of the reviewed stable Wicked.API surface: $(family)"))
end

"""
    widget_catalog_summary(; status=nothing, surface=nothing, family=nothing)

Return a compact summary of reviewed widget catalog entries, including total
count and counts by status, surface, and source file.
"""
function widget_catalog_summary(; status=nothing, surface=nothing, family=nothing)
    entries = stable_widget_catalog(; status=status, surface=surface, family=family)
    return (
        total=length(entries),
        by_status=_count_widget_catalog_by(entries, entry -> entry.status),
        by_surface=_count_widget_catalog_by(entries, entry -> entry.surface),
        by_family=_count_widget_catalog_by(entries, entry -> widget_catalog_family(entry)),
        by_family_slug=_count_widget_catalog_by(entries, entry -> widget_catalog_family_slug(entry)),
        by_source=_count_widget_catalog_by(entries, entry -> entry.source),
    )
end

"""
    widget_catalog_markdown(; status=:stable, surface=:stable, family=nothing, columns=(:name, :source, :surface, :status, :reason))

Render reviewed widget catalog entries as a GitHub-flavored Markdown table.
`columns` may include `:name`, `:family`, `:family_slug`, `:source`, `:surface`,
`:status`, and `:reason`.
"""
function widget_catalog_markdown(;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :source, :surface, :status, :reason),
)
    selected = _widget_catalog_columns(columns)
    isempty(selected) && throw(ArgumentError("widget catalog markdown requires at least one column"))
    return _widget_catalog_markdown(stable_widget_catalog(; status=status, surface=surface, family=family), selected)
end

function _widget_catalog_markdown(entries, selected)
    header = join(("`$(String(column))`" for column in selected), " | ")
    separator = join(fill("---", length(selected)), " | ")
    rows = String["| $header |", "| $separator |"]
    for entry in entries
        row = join((_escape_widget_catalog_markdown(_widget_catalog_field(entry, column)) for column in selected), " | ")
        push!(rows, "| $row |")
    end
    return join(rows, "\n")
end

"""
    search_widget_catalog_markdown(query; status=:stable, surface=:stable, family=nothing, columns=(:name, :source, :surface, :status, :reason))

Search reviewed widget catalog entries and render the matches as a
GitHub-flavored Markdown table.
"""
function search_widget_catalog_markdown(
    query;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :source, :surface, :status, :reason),
)
    selected = _widget_catalog_columns(columns)
    isempty(selected) && throw(ArgumentError("widget catalog markdown requires at least one column"))
    return _widget_catalog_markdown(search_widgets(query; status=status, surface=surface, family=family), selected)
end

"""
    widget_catalog_records(; status=:stable, surface=:stable, family=nothing)

Return reviewed widget catalog entries as plain named tuples with `name`,
`family`, `source`, `surface`, `status`, and `reason` fields.
"""
function widget_catalog_records(; status=:stable, surface=:stable, family=nothing)
    return [
        (
            name=entry.name,
            family=widget_catalog_family(entry),
            family_slug=widget_catalog_family_slug(entry),
            source=entry.source,
            surface=entry.surface,
            status=entry.status,
            reason=entry.reason,
        )
        for entry in stable_widget_catalog(; status=status, surface=surface, family=family)
    ]
end

"""
    widget_catalog_tsv(; status=:stable, surface=:stable, family=nothing, columns=(:name, :source, :surface, :status, :reason), header=true)

Render reviewed widget catalog entries as tab-separated values with a header row.
`columns` may include `:name`, `:family`, `:family_slug`, `:source`, `:surface`,
`:status`, and `:reason`.
"""
function widget_catalog_tsv(;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :source, :surface, :status, :reason),
    header::Bool=true,
)
    selected = _widget_catalog_columns(columns)
    isempty(selected) && throw(ArgumentError("widget catalog TSV requires at least one column"))
    return _widget_catalog_tsv(stable_widget_catalog(; status=status, surface=surface, family=family), selected; header=header)
end

function _widget_catalog_tsv(entries, selected; header::Bool=true)
    rows = String[]
    header && push!(rows, join((String(column) for column in selected), "\t"))
    for entry in entries
        push!(rows, join((_escape_widget_catalog_tsv(_widget_catalog_field(entry, column)) for column in selected), "\t"))
    end
    return join(rows, "\n")
end

"""
    search_widget_catalog_tsv(query; status=:stable, surface=:stable, family=nothing, columns=(:name, :source, :surface, :status, :reason), header=true)

Search reviewed widget catalog entries and render the matches as
tab-separated values with a header row.
"""
function search_widget_catalog_tsv(
    query;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :source, :surface, :status, :reason),
    header::Bool=true,
)
    selected = _widget_catalog_columns(columns)
    isempty(selected) && throw(ArgumentError("widget catalog TSV requires at least one column"))
    return _widget_catalog_tsv(search_widgets(query; status=status, surface=surface, family=family), selected; header=header)
end

"""
    widget_coverage_records(; status=:stable, surface=:stable, family=nothing)

Compare the reviewed widget catalog with `api/widget_coverage.tsv` and return
plain named tuples for release-review tooling.
"""
function widget_coverage_records(; status=:stable, surface=:stable, family=nothing)
    coverage = _read_widget_coverage()
    rows = [
        begin
            coverage_row = get(coverage, entry.name, nothing)
            missing_checks = Symbol[]
            if coverage_row !== nothing
                for check in _WIDGET_COVERAGE_CHECK_COLUMNS
                    _widget_coverage_value_complete(getproperty(coverage_row, check)) ||
                        push!(missing_checks, check)
                end
            else
                append!(missing_checks, _WIDGET_COVERAGE_CHECK_COLUMNS)
            end
            has_coverage = coverage_row !== nothing
            coverage_source = has_coverage ? coverage_row.source : ""
            source_matches = has_coverage && coverage_source == entry.source
            complete = has_coverage && source_matches && isempty(missing_checks)
            issue = !has_coverage ? :missing_record :
                !source_matches ? :source_mismatch :
                !isempty(missing_checks) ? :missing_checks :
                :complete
            (
                name=entry.name,
                family=widget_catalog_family(entry),
                family_slug=widget_catalog_family_slug(entry),
                catalog_source=entry.source,
                coverage_source=coverage_source,
                has_coverage=has_coverage,
                source_matches=source_matches,
                complete=complete,
                missing_checks=copy(missing_checks),
                issue=issue,
            )
        end
        for entry in stable_widget_catalog(; status=status, surface=surface, family=family)
    ]
    return sort!(rows; by=row -> String(row.name))
end

function _widget_stability_blockers(entry::WidgetCatalogEntry, coverage_row)
    blockers = String[]
    entry.surface === :stable ||
        push!(blockers, "surface is $(entry.surface), not stable")
    entry.status === :stable ||
        push!(blockers, "status is $(entry.status), not stable")
    coverage_row.has_coverage ||
        push!(blockers, "coverage record is missing")
    coverage_row.has_coverage && !coverage_row.source_matches &&
        push!(blockers, "coverage source $(coverage_row.coverage_source) does not match catalog source $(entry.source)")
    !isempty(coverage_row.missing_checks) &&
        push!(blockers, "coverage checks missing: $(join((String(check) for check in coverage_row.missing_checks), ", "))")
    return blockers
end

function _widget_stability_report(entry::WidgetCatalogEntry, coverage_row)
    blockers = _widget_stability_blockers(entry, coverage_row)
    stable = entry.surface === :stable && entry.status === :stable
    return WidgetStabilityReport(
        entry.name,
        coverage_row.family,
        coverage_row.family_slug,
        entry.surface,
        entry.status,
        entry.source,
        coverage_row.coverage_source,
        stable,
        coverage_row.complete,
        stable && coverage_row.complete && isempty(blockers),
        copy(coverage_row.missing_checks),
        blockers,
    )
end

"""
    widget_stability_reports(; status=nothing, surface=nothing, family=nothing)

Return promotion-readiness reports for reviewed widget catalog entries. A report
is `ready` only when the widget is on the stable facade, has stable status, and
has complete behavior coverage with matching source evidence.
"""
function widget_stability_reports(; status=nothing, surface=nothing, family=nothing)
    entries = stable_widget_catalog(; status=status, surface=surface, family=family)
    coverage_by_name = Dict(row.name => row for row in widget_coverage_records(; status=status, surface=surface, family=family))
    return WidgetStabilityReport[
        _widget_stability_report(entry, coverage_by_name[entry.name])
        for entry in entries
    ]
end

"""
    widget_stability_report(name; status=nothing, surface=nothing)

Return the promotion-readiness report for one reviewed widget name, type, or
instance.
"""
function widget_stability_report(name; status=nothing, surface=nothing)
    catalog = stable_widget_catalog(; status=status, surface=surface)
    entry = widget_catalog_entry(name; catalog=catalog)
    entry === nothing &&
        throw(ArgumentError("widget is not present in the reviewed stabilization catalog: $(_widget_catalog_name(name))"))
    coverage_by_name = Dict(row.name => row for row in widget_coverage_records(; status=status, surface=surface))
    return _widget_stability_report(entry, coverage_by_name[entry.name])
end

"""
    widget_stability_gaps(; status=nothing, surface=nothing, family=nothing)

Return reviewed widget stability reports that still have promotion blockers.
"""
widget_stability_gaps(; status=nothing, surface=nothing, family=nothing) =
    [report for report in widget_stability_reports(; status=status, surface=surface, family=family) if !report.ready]

"""
    widget_stability_ready(name; status=nothing, surface=nothing)

Return `true` when one reviewed widget is ready for the stable application API.
"""
widget_stability_ready(name; status=nothing, surface=nothing) =
    widget_stability_report(name; status=status, surface=surface).ready

"""
    widget_stability_complete(; status=nothing, surface=nothing, family=nothing)

Return `true` when all matching reviewed widget stability reports have no
promotion blockers.
"""
widget_stability_complete(; status=nothing, surface=nothing, family=nothing) =
    isempty(widget_stability_gaps(; status=status, surface=surface, family=family))

"""
    assert_widget_stability_complete(; status=nothing, surface=nothing, family=nothing)

Return `true` when every matching reviewed widget stability report is ready, or
throw an `ArgumentError` naming blocked widgets and their blocker counts.
"""
function assert_widget_stability_complete(; status=nothing, surface=nothing, family=nothing)
    gaps = widget_stability_gaps(; status=status, surface=surface, family=family)
    isempty(gaps) && return true
    details = join((
        "$(report.name) ($(length(report.blockers)) blockers)"
        for report in Iterators.take(gaps, 5)
    ), "; ")
    throw(ArgumentError("widget stability reports have promotion blockers: $details"))
end

"""
    widget_stability_summary(; status=nothing, surface=nothing, family=nothing)

Return aggregate counts for reviewed widget promotion-readiness reports.
"""
function widget_stability_summary(; status=nothing, surface=nothing, family=nothing)
    reports = widget_stability_reports(; status=status, surface=surface, family=family)
    return (
        total=length(reports),
        ready=count(report -> report.ready, reports),
        blocked=count(report -> !report.ready, reports),
        stable=count(report -> report.stable, reports),
        unstable=count(report -> !report.stable, reports),
        coverage_complete=count(report -> report.coverage_complete, reports),
        coverage_incomplete=count(report -> !report.coverage_complete, reports),
        by_family=_count_widget_catalog_by(reports, report -> report.family),
        by_family_slug=_count_widget_catalog_by(reports, report -> report.family_slug),
    )
end

"""
    widget_stability_summary_records(; status=nothing, surface=nothing, family=nothing)

Return widget promotion-readiness summary counts as named tuples with `metric`,
`key`, and `count` fields.
"""
function widget_stability_summary_records(; status=nothing, surface=nothing, family=nothing)
    summary = widget_stability_summary(; status=status, surface=surface, family=family)
    rows = [
        (metric="total", key="all", count=summary.total),
        (metric="ready", key="all", count=summary.ready),
        (metric="blocked", key="all", count=summary.blocked),
        (metric="stable", key="all", count=summary.stable),
        (metric="unstable", key="all", count=summary.unstable),
        (metric="coverage_complete", key="all", count=summary.coverage_complete),
        (metric="coverage_incomplete", key="all", count=summary.coverage_incomplete),
    ]
    append!(rows, [(metric="family", key=key, count=value) for (key, value) in summary.by_family])
    append!(rows, [(metric="family_slug", key=key, count=value) for (key, value) in summary.by_family_slug])
    return sort!(rows; by=row -> (row.metric, row.key))
end

"""
    widget_stability_summary_markdown(; status=nothing, surface=nothing, family=nothing)

Render widget promotion-readiness summary counts as a GitHub-flavored Markdown
table.
"""
function widget_stability_summary_markdown(; status=nothing, surface=nothing, family=nothing)
    rows = String["| `metric` | `key` | `count` |", "| --- | --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(row.metric)) | $(_escape_widget_catalog_markdown(row.key)) | $(row.count) |"
        for row in widget_stability_summary_records(; status=status, surface=surface, family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stability_summary_tsv(; status=nothing, surface=nothing, family=nothing, header=true)

Render widget promotion-readiness summary counts as tab-separated values.
"""
function widget_stability_summary_tsv(; status=nothing, surface=nothing, family=nothing, header::Bool=true)
    rows = header ? String["metric\tkey\tcount"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(row.metric))\t$(_escape_widget_catalog_tsv(row.key))\t$(row.count)"
        for row in widget_stability_summary_records(; status=status, surface=surface, family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stability_summary_text(; status=nothing, surface=nothing, family=nothing)

Render a compact one-line widget promotion-readiness status.
"""
function widget_stability_summary_text(; status=nothing, surface=nothing, family=nothing)
    summary = widget_stability_summary(; status=status, surface=surface, family=family)
    return "total=$(summary.total) ready=$(summary.ready) blocked=$(summary.blocked) stable=$(summary.stable) coverage_complete=$(summary.coverage_complete)"
end

function _experimental_namespace_names()
    isdefined(@__MODULE__, :Experimental) || return Symbol[]
    namespace = getfield(@__MODULE__, :Experimental)
    return sort!(Symbol[
        name for name in names(namespace; all=false, imported=false)
        if name !== :Experimental
    ])
end

"""
    experimental_widget_names(; family=nothing)

Return exported compatibility bindings from `Wicked.Experimental` that still
need a promotion, qualification, or removal decision. When `family` is provided,
only bindings that also appear in the reviewed widget catalog for that family
are returned.
"""
function experimental_widget_names(; family=nothing)
    names = _experimental_namespace_names()
    family_filter = _widget_catalog_family_filter(family)
    family_filter === nothing && return names
    catalog = Dict(entry.name => entry for entry in stable_widget_catalog(status=nothing, surface=nothing))
    return Symbol[
        name for name in names
        if haskey(catalog, name) && _widget_catalog_family_matches(catalog[name], family_filter)
    ]
end

"""
    experimental_widget_count(; family=nothing)

Return the number of exported `Wicked.Experimental` bindings that still need
promotion closeout.
"""
experimental_widget_count(; family=nothing) = length(experimental_widget_names(; family=family))

"""
    experimental_widget_records(; family=nothing)

Return structured records for exported `Wicked.Experimental` bindings that
still need a promotion, qualification, or removal decision.
"""
function experimental_widget_records(; family=nothing)
    catalog = Dict(entry.name => entry for entry in stable_widget_catalog(status=nothing, surface=nothing))
    plans = _read_experimental_promotion_plans()
    return [
        begin
            entry = get(catalog, name, nothing)
            action = _experimental_promotion_action(_experimental_promotion_row(name, plans))
            (
                name=name,
                cataloged=entry !== nothing,
                family=entry === nothing ? "" : entry.family,
                family_slug=entry === nothing ? "" : entry.family_slug,
                source=entry === nothing ? "" : entry.source,
                surface=entry === nothing ? :experimental : entry.surface,
                status=entry === nothing ? :experimental : entry.status,
                decision=action.decision,
                target=action.target,
                review_status=action.review_status,
                plan_notes=action.notes,
                required_decision=action.required_decision,
            )
        end
        for name in experimental_widget_names(; family=family)
    ]
end

"""
    experimental_widget_records_markdown(; family=nothing)

Render exported `Wicked.Experimental` bindings as a GitHub-flavored Markdown
table with catalog linkage and required closeout decision fields.
"""
function experimental_widget_records_markdown(; family=nothing)
    rows = String[
        "| `name` | `cataloged` | `family` | `family_slug` | `source` | `surface` | `status` | `decision` | `target` | `review_status` | `required_decision` |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(record.name)) | $(record.cataloged) | $(_escape_widget_catalog_markdown(record.family)) | $(_escape_widget_catalog_markdown(record.family_slug)) | $(_escape_widget_catalog_markdown(record.source)) | $(_escape_widget_catalog_markdown(record.surface)) | $(_escape_widget_catalog_markdown(record.status)) | $(_escape_widget_catalog_markdown(record.decision)) | $(_escape_widget_catalog_markdown(record.target)) | $(_escape_widget_catalog_markdown(record.review_status)) | $(_escape_widget_catalog_markdown(record.required_decision)) |"
        for record in experimental_widget_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    experimental_widget_records_tsv(; family=nothing, header=true)

Render exported `Wicked.Experimental` bindings as tab-separated values with
catalog linkage and required closeout decision fields.
"""
function experimental_widget_records_tsv(; family=nothing, header::Bool=true)
    rows = header ? String[
        "name\tcataloged\tfamily\tfamily_slug\tsource\tsurface\tstatus\tdecision\ttarget\treview_status\tplan_notes\trequired_decision",
    ] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(record.name))\t$(record.cataloged)\t$(_escape_widget_catalog_tsv(record.family))\t$(_escape_widget_catalog_tsv(record.family_slug))\t$(_escape_widget_catalog_tsv(record.source))\t$(_escape_widget_catalog_tsv(record.surface))\t$(_escape_widget_catalog_tsv(record.status))\t$(_escape_widget_catalog_tsv(record.decision))\t$(_escape_widget_catalog_tsv(record.target))\t$(_escape_widget_catalog_tsv(record.review_status))\t$(_escape_widget_catalog_tsv(record.plan_notes))\t$(_escape_widget_catalog_tsv(record.required_decision))"
        for record in experimental_widget_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    experimental_widget_records_json(; family=nothing)

Render exported `Wicked.Experimental` bindings as compact JSON for release
dashboards, CI artifacts, and experimental-promotion automation.
"""
function experimental_widget_records_json(; family=nothing)
    records = experimental_widget_records(; family=family)
    rows = String[
        "    {\"name\": $(_widget_coverage_json_string(String(record.name))), \"cataloged\": $(record.cataloged), \"family\": $(_widget_coverage_json_string(record.family)), \"family_slug\": $(_widget_coverage_json_string(record.family_slug)), \"source\": $(_widget_coverage_json_string(record.source)), \"surface\": $(_widget_coverage_json_string(String(record.surface))), \"status\": $(_widget_coverage_json_string(String(record.status))), \"decision\": $(_widget_coverage_json_string(record.decision)), \"target\": $(_widget_coverage_json_string(record.target)), \"review_status\": $(_widget_coverage_json_string(record.review_status)), \"plan_notes\": $(_widget_coverage_json_string(record.plan_notes)), \"required_decision\": $(_widget_coverage_json_string(record.required_decision))}$(index == length(records) ? "" : ",")"
        for (index, record) in enumerate(records)
    ]
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"experimental_widget_count\": $(length(records)),",
        "  \"experimental_widgets\": [",
        join(rows, "\n"),
        "  ]",
        "}",
    ), "\n")
end

"""
    experimental_widget_record(name; family=nothing)

Return one closeout record for one `Wicked.Experimental` binding.

`name` may be a `Symbol`, `String`, widget type, or instance. Set `family`
to restrict the lookup to one reviewed family while filtering.
"""
experimental_widget_record(name; family=nothing) =
    _experimental_widget_record_lookup(name; family=family)

"""
    experimental_widget_readiness_record(name; family=nothing)

Return a named-tuple readiness report for one `Wicked.Experimental` binding.
The report includes blockers and a boolean `ready` flag for stable-widget
promotion readiness.
"""
function experimental_widget_readiness_record(name; family=nothing)
    record = experimental_widget_record(name; family=family)
    readiness = _experimental_widget_readiness(record)
    return (
        name=record.name,
        family=record.family,
        family_slug=record.family_slug,
        cataloged=record.cataloged,
        source=record.source,
        surface=record.surface,
        status=record.status,
        decision=record.decision,
        target=record.target,
        review_status=record.review_status,
        plan_notes=record.plan_notes,
        required_decision=record.required_decision,
        ready=readiness.ready,
        blockers=readiness.blockers,
    )
end

"""
    experimental_widget_ready_for_stable(name; family=nothing)

Return `true` when one experimental binding is ready to be treated as a stable
promotion candidate, otherwise `false`.
"""
experimental_widget_ready_for_stable(name; family=nothing) =
    experimental_widget_readiness_record(name; family=family).ready

"""
    experimental_widget_readiness_text(name; family=nothing)

Render one experimental-readiness report as newline-separated compact text.
"""
function experimental_widget_readiness_text(name; family=nothing)
    report = experimental_widget_readiness_record(name; family=family)
    blockers = isempty(report.blockers) ? "none" : join(report.blockers, "; ")
    return "name=$(report.name) ready=$(report.ready) decision=$(report.decision) review_status=$(report.review_status) blockers=$blockers"
end

"""
    assert_experimental_widget_ready_for_stable(name; family=nothing)

Return the readiness report when the binding is ready for stable promotion.
Otherwise throw an `ArgumentError` with blockers.
"""
function assert_experimental_widget_ready_for_stable(name; family=nothing)
    report = experimental_widget_readiness_record(name; family=family)
    report.ready && return report
    throw(ArgumentError("experimental widget $(report.name) is not ready for stable promotion: $(join(report.blockers, "; "))"))
end

"""
    candidate_widget_names(; family=nothing)

Return reviewed widget catalog names that are not yet stable on the stable
application surface.
"""
function candidate_widget_names(; family=nothing)
    return Symbol[
        entry.name for entry in stable_widget_catalog(status=nothing, surface=nothing, family=family)
        if entry.surface !== :stable || entry.status !== :stable
    ]
end

"""
    candidate_widget_records(; family=nothing)

Return structured records for reviewed widget catalog entries that are not yet
stable on the stable application surface.
"""
function candidate_widget_records(; family=nothing)
    return [
        (
            name=entry.name,
            family=entry.family,
            family_slug=entry.family_slug,
            source=entry.source,
            surface=entry.surface,
            status=entry.status,
            reason=entry.reason,
        )
        for entry in stable_widget_catalog(status=nothing, surface=nothing, family=family)
        if entry.surface !== :stable || entry.status !== :stable
    ]
end

"""
    candidate_widget_records_markdown(; family=nothing)

Render non-stable reviewed widget catalog entries as a GitHub-flavored Markdown
table with `name`, `family`, `family_slug`, `source`, `surface`, `status`, and
`reason` columns.
"""
function candidate_widget_records_markdown(; family=nothing)
    rows = String["| `name` | `family` | `family_slug` | `source` | `surface` | `status` | `reason` |", "| --- | --- | --- | --- | --- | --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(record.name)) | $(_escape_widget_catalog_markdown(record.family)) | $(_escape_widget_catalog_markdown(record.family_slug)) | $(_escape_widget_catalog_markdown(record.source)) | $(_escape_widget_catalog_markdown(record.surface)) | $(_escape_widget_catalog_markdown(record.status)) | $(_escape_widget_catalog_markdown(record.reason)) |"
        for record in candidate_widget_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    candidate_widget_records_tsv(; family=nothing, header=true)

Render non-stable reviewed widget catalog entries as tab-separated values with
`name`, `family`, `family_slug`, `source`, `surface`, `status`, and `reason`
columns.
"""
function candidate_widget_records_tsv(; family=nothing, header::Bool=true)
    rows = header ? String["name\tfamily\tfamily_slug\tsource\tsurface\tstatus\treason"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(record.name))\t$(_escape_widget_catalog_tsv(record.family))\t$(_escape_widget_catalog_tsv(record.family_slug))\t$(_escape_widget_catalog_tsv(record.source))\t$(_escape_widget_catalog_tsv(record.surface))\t$(_escape_widget_catalog_tsv(record.status))\t$(_escape_widget_catalog_tsv(record.reason))"
        for record in candidate_widget_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    candidate_widget_records_json(; family=nothing)

Render non-stable reviewed widget catalog entries as compact JSON for release
dashboards, CI artifacts, and stabilization automation.
"""
function candidate_widget_records_json(; family=nothing)
    records = candidate_widget_records(; family=family)
    rows = String[
        "    {\"name\": $(_widget_coverage_json_string(String(record.name))), \"family\": $(_widget_coverage_json_string(record.family)), \"family_slug\": $(_widget_coverage_json_string(record.family_slug)), \"source\": $(_widget_coverage_json_string(record.source)), \"surface\": $(_widget_coverage_json_string(String(record.surface))), \"status\": $(_widget_coverage_json_string(String(record.status))), \"reason\": $(_widget_coverage_json_string(record.reason))}$(index == length(records) ? "" : ",")"
        for (index, record) in enumerate(records)
    ]
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"candidate_widget_count\": $(length(records)),",
        "  \"candidate_widgets\": [",
        join(rows, "\n"),
        "  ]",
        "}",
    ), "\n")
end

"""
    widget_stabilization_closeout_records(; family=nothing)

Return one normalized list of remaining widget stabilization closeout work,
including exported experimental bindings and reviewed catalog candidates.
"""
function widget_stabilization_closeout_records(; family=nothing)
    experimental = [
        (
            kind=:experimental,
            name=record.name,
            family=record.family,
            family_slug=record.family_slug,
            source=record.source,
            surface=record.surface,
            status=record.status,
            action=record.required_decision,
            reason=record.cataloged ? "experimental binding maps to reviewed widget catalog" : "experimental binding is not in reviewed widget catalog",
        )
        for record in experimental_widget_records(; family=family)
    ]
    candidates = [
        (
            kind=:candidate,
            name=record.name,
            family=record.family,
            family_slug=record.family_slug,
            source=record.source,
            surface=record.surface,
            status=record.status,
            action="promote to stable surface or keep internal",
            reason=record.reason,
        )
        for record in candidate_widget_records(; family=family)
    ]
    return vcat(experimental, candidates)
end

function _widget_stabilization_closeout_kind(kind)
    selected = Symbol(kind)
    selected in (:experimental, :candidate) ||
        throw(ArgumentError("widget stabilization closeout kind must be :experimental or :candidate"))
    return selected
end

"""
    widget_stabilization_closeout_kind_records(kind; family=nothing)

Return unified widget stabilization closeout records for one closeout kind.
`kind` must be `:experimental` or `:candidate`.
"""
function widget_stabilization_closeout_kind_records(kind; family=nothing)
    selected = _widget_stabilization_closeout_kind(kind)
    return [
        record for record in widget_stabilization_closeout_records(; family=family)
        if record.kind === selected
    ]
end

"""
    widget_stabilization_closeout_kind_count(kind; family=nothing)

Return the number of unified widget stabilization closeout records for one
closeout kind. `kind` must be `:experimental` or `:candidate`.
"""
widget_stabilization_closeout_kind_count(kind; family=nothing) =
    length(widget_stabilization_closeout_kind_records(kind; family=family))

"""
    widget_stabilization_closeout_kind_markdown(kind; family=nothing)

Render one closeout kind as a GitHub-flavored Markdown table. `kind` must be
`:experimental` or `:candidate`.
"""
function widget_stabilization_closeout_kind_markdown(kind; family=nothing)
    rows = String["| `kind` | `name` | `family` | `family_slug` | `source` | `surface` | `status` | `action` | `reason` |", "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(record.kind)) | $(_escape_widget_catalog_markdown(record.name)) | $(_escape_widget_catalog_markdown(record.family)) | $(_escape_widget_catalog_markdown(record.family_slug)) | $(_escape_widget_catalog_markdown(record.source)) | $(_escape_widget_catalog_markdown(record.surface)) | $(_escape_widget_catalog_markdown(record.status)) | $(_escape_widget_catalog_markdown(record.action)) | $(_escape_widget_catalog_markdown(record.reason)) |"
        for record in widget_stabilization_closeout_kind_records(kind; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_closeout_kind_tsv(kind; family=nothing, header=true)

Render one closeout kind as tab-separated values. `kind` must be
`:experimental` or `:candidate`.
"""
function widget_stabilization_closeout_kind_tsv(kind; family=nothing, header::Bool=true)
    rows = header ? String["kind\tname\tfamily\tfamily_slug\tsource\tsurface\tstatus\taction\treason"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(record.kind))\t$(_escape_widget_catalog_tsv(record.name))\t$(_escape_widget_catalog_tsv(record.family))\t$(_escape_widget_catalog_tsv(record.family_slug))\t$(_escape_widget_catalog_tsv(record.source))\t$(_escape_widget_catalog_tsv(record.surface))\t$(_escape_widget_catalog_tsv(record.status))\t$(_escape_widget_catalog_tsv(record.action))\t$(_escape_widget_catalog_tsv(record.reason))"
        for record in widget_stabilization_closeout_kind_records(kind; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_closeout_kind_json(kind; family=nothing)

Render one closeout kind as compact JSON. `kind` must be `:experimental` or
`:candidate`.
"""
function widget_stabilization_closeout_kind_json(kind; family=nothing)
    selected = _widget_stabilization_closeout_kind(kind)
    records = widget_stabilization_closeout_kind_records(selected; family=family)
    rows = String[
        "    {\"kind\": $(_widget_coverage_json_string(record.kind)), \"name\": $(_widget_coverage_json_string(record.name)), \"family\": $(_widget_coverage_json_string(record.family)), \"family_slug\": $(_widget_coverage_json_string(record.family_slug)), \"source\": $(_widget_coverage_json_string(record.source)), \"surface\": $(_widget_coverage_json_string(record.surface)), \"status\": $(_widget_coverage_json_string(record.status)), \"action\": $(_widget_coverage_json_string(record.action)), \"reason\": $(_widget_coverage_json_string(record.reason))}$(index == length(records) ? "" : ",")"
        for (index, record) in enumerate(records)
    ]
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"kind\": $(_widget_coverage_json_string(selected)),",
        "  \"count\": $(length(records)),",
        "  \"records\": [",
        join(rows, "\n"),
        "  ]",
        "}",
    ), "\n")
end

"""
    widget_stabilization_closeout_kind_text(kind; family=nothing)

Render one closeout kind as newline-separated human-readable log lines. `kind`
must be `:experimental` or `:candidate`.
"""
function widget_stabilization_closeout_kind_text(kind; family=nothing)
    return join((
        "$(record.kind):$(record.name) action=$(record.action) reason=$(record.reason)"
        for record in widget_stabilization_closeout_kind_records(kind; family=family)
    ), "\n")
end

"""
    widget_stabilization_closeout_kind_artifacts(kind; family=nothing)

Return one aggregate artifact bundle for one stabilization closeout kind with
structured records plus rendered `status`, `summary`, and output formats.
`kind` must be `:experimental` or `:candidate`.
"""
function widget_stabilization_closeout_kind_artifacts(kind; family=nothing)
    selected = _widget_stabilization_closeout_kind(kind)
    records = widget_stabilization_closeout_kind_records(selected; family=family)
    summary = (
        total=length(records),
        experimental=count(record -> record.kind === :experimental, records),
        candidate=count(record -> record.kind === :candidate, records),
    )
    status = (
        kind=selected,
        complete=summary.total == 0,
        closeout_count=summary.total,
        experimental_count=summary.experimental,
        candidate_count=summary.candidate,
    )
    return (
        schema_version=1,
        kind=selected,
        status=status,
        summary=summary,
        records=records,
        status_text=join((
            "kind=$(status.kind)",
            "complete=$(status.complete)",
            "closeout_count=$(status.closeout_count)",
            "experimental_count=$(status.experimental_count)",
            "candidate_count=$(status.candidate_count)",
        ), " "),
        status_markdown=(
            "| `metric` | `value` |" *
            "\n| --- | --- |" *
            "\n| kind | " * string(status.kind) * " |" *
            "\n| complete | " * string(status.complete) * " |" *
            "\n| closeout_count | " * string(status.closeout_count) * " |" *
            "\n| experimental_count | " * string(status.experimental_count) * " |" *
            "\n| candidate_count | " * string(status.candidate_count) * " |"
        ),
        status_tsv=join((
            "metric\tvalue",
            "kind\t$(status.kind)",
            "complete\t$(status.complete)",
            "closeout_count\t$(status.closeout_count)",
            "experimental_count\t$(status.experimental_count)",
            "candidate_count\t$(status.candidate_count)",
        ), "\n"),
        status_json=join((
            "{",
            "  \"schema_version\": 1,",
            "  \"kind\": $(_widget_coverage_json_string(status.kind)),",
            "  \"complete\": $(status.complete),",
            "  \"closeout_count\": $(status.closeout_count),",
            "  \"experimental_count\": $(status.experimental_count),",
            "  \"candidate_count\": $(status.candidate_count)",
            "}",
        ), "\n"),
        summary_text=join((
            "total=$(summary.total)",
            "experimental=$(summary.experimental)",
            "candidate=$(summary.candidate)",
        ), " "),
        summary_markdown=join((
            "| `metric` | `key` | `count` |",
            "| --- | --- | --- |",
            "| total | all | $(summary.total) |",
            "| kind | experimental | $(summary.experimental) |",
            "| kind | candidate | $(summary.candidate) |",
        ), "\n"),
        summary_tsv=join((
            "metric\tkey\tcount",
            "total\tall\t$(summary.total)",
            "kind\texperimental\t$(summary.experimental)",
            "kind\tcandidate\t$(summary.candidate)",
        ), "\n"),
        summary_json=join((
            "{",
            "  \"schema_version\": 1,",
            "  \"total\": $(summary.total),",
            "  \"experimental\": $(summary.experimental),",
            "  \"candidate\": $(summary.candidate),",
            "  \"records\": [",
            "    {\"metric\": \"total\", \"key\": \"all\", \"count\": $(summary.total)},",
            "    {\"metric\": \"kind\", \"key\": \"experimental\", \"count\": $(summary.experimental)},",
            "    {\"metric\": \"kind\", \"key\": \"candidate\", \"count\": $(summary.candidate)}",
            "  ]",
            "}",
        ), "\n"),
        text=widget_stabilization_closeout_kind_text(selected; family=family),
        markdown=widget_stabilization_closeout_kind_markdown(selected; family=family),
        tsv=widget_stabilization_closeout_kind_tsv(selected; family=family),
        json=widget_stabilization_closeout_kind_json(selected; family=family),
    )
end

"""
    widget_stabilization_closeout_kind_complete(kind; family=nothing)

Return `true` when one closeout kind has no remaining records. `kind` must be
`:experimental` or `:candidate`.
"""
widget_stabilization_closeout_kind_complete(kind; family=nothing) =
    widget_stabilization_closeout_kind_count(kind; family=family) == 0

"""
    assert_widget_stabilization_closeout_kind_complete(kind; family=nothing)

Return `true` when one closeout kind has no remaining records, or throw an
`ArgumentError` naming the first remaining records. `kind` must be
`:experimental` or `:candidate`.
"""
function assert_widget_stabilization_closeout_kind_complete(kind; family=nothing)
    selected = _widget_stabilization_closeout_kind(kind)
    records = widget_stabilization_closeout_kind_records(selected; family=family)
    isempty(records) && return true
    details = join((
        "$(record.kind):$(record.name)"
        for record in Iterators.take(records, 5)
    ), "; ")
    throw(ArgumentError("widget stabilization closeout kind $(repr(selected)) is incomplete: $details"))
end

function _widget_stabilization_closeout_matches(record, query::AbstractString)
    needle = lowercase(query)
    isempty(needle) && return true
    return any(
        value -> occursin(needle, lowercase(string(value))),
        (
            record.kind,
            record.name,
            record.family,
            record.family_slug,
            record.source,
            record.surface,
            record.status,
            record.action,
            record.reason,
        ),
    )
end

"""
    search_widget_stabilization_closeout_records(query; family=nothing)

Return unified widget stabilization closeout records matching `query` by kind,
name, family, source, surface, status, action, or reason.
"""
function search_widget_stabilization_closeout_records(query; family=nothing)
    needle = lowercase(string(query))
    return [
        record for record in widget_stabilization_closeout_records(; family=family)
        if _widget_stabilization_closeout_matches(record, needle)
    ]
end

"""
    search_widget_stabilization_closeout_count(query; family=nothing)

Return the number of unified widget stabilization closeout records matching
`query`.
"""
search_widget_stabilization_closeout_count(query; family=nothing) =
    length(search_widget_stabilization_closeout_records(query; family=family))

"""
    search_widget_stabilization_closeout_summary(query; family=nothing)

Return compact counts for closeout records matching `query`.
"""
function search_widget_stabilization_closeout_summary(query; family=nothing)
    records = search_widget_stabilization_closeout_records(query; family=family)
    return (
        total=length(records),
        experimental=count(record -> record.kind === :experimental, records),
        candidate=count(record -> record.kind === :candidate, records),
    )
end

"""
    search_widget_stabilization_closeout_summary_records(query; family=nothing)

Return filtered closeout summary counts as named tuples with `metric`, `key`,
and `count` fields.
"""
function search_widget_stabilization_closeout_summary_records(query; family=nothing)
    summary = search_widget_stabilization_closeout_summary(query; family=family)
    return [
        (metric="total", key="all", count=summary.total),
        (metric="kind", key="experimental", count=summary.experimental),
        (metric="kind", key="candidate", count=summary.candidate),
    ]
end

"""
    search_widget_stabilization_closeout_summary_markdown(query; family=nothing)

Render filtered closeout summary counts as a GitHub-flavored Markdown table.
"""
function search_widget_stabilization_closeout_summary_markdown(query; family=nothing)
    rows = String["| `metric` | `key` | `count` |", "| --- | --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(record.metric)) | $(_escape_widget_catalog_markdown(record.key)) | $(record.count) |"
        for record in search_widget_stabilization_closeout_summary_records(query; family=family)
    )
    return join(rows, "\n")
end

"""
    search_widget_stabilization_closeout_summary_tsv(query; family=nothing, header=true)

Render filtered closeout summary counts as tab-separated values.
"""
function search_widget_stabilization_closeout_summary_tsv(query; family=nothing, header::Bool=true)
    rows = header ? String["metric\tkey\tcount"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(record.metric))\t$(_escape_widget_catalog_tsv(record.key))\t$(record.count)"
        for record in search_widget_stabilization_closeout_summary_records(query; family=family)
    )
    return join(rows, "\n")
end

"""
    search_widget_stabilization_closeout_summary_json(query; family=nothing)

Render filtered closeout summary counts as compact JSON.
"""
function search_widget_stabilization_closeout_summary_json(query; family=nothing)
    summary = search_widget_stabilization_closeout_summary(query; family=family)
    records = search_widget_stabilization_closeout_summary_records(query; family=family)
    rows = String[
        "    {\"metric\": $(_widget_coverage_json_string(record.metric)), \"key\": $(_widget_coverage_json_string(record.key)), \"count\": $(record.count)}$(index == length(records) ? "" : ",")"
        for (index, record) in enumerate(records)
    ]
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"query\": $(_widget_coverage_json_string(string(query))),",
        "  \"total\": $(summary.total),",
        "  \"experimental\": $(summary.experimental),",
        "  \"candidate\": $(summary.candidate),",
        "  \"records\": [",
        join(rows, "\n"),
        "  ]",
        "}",
    ), "\n")
end

"""
    search_widget_stabilization_closeout_summary_text(query; family=nothing)

Render filtered closeout summary counts as one log-friendly status line.
"""
function search_widget_stabilization_closeout_summary_text(query; family=nothing)
    summary = search_widget_stabilization_closeout_summary(query; family=family)
    return "query=$(string(query)) total=$(summary.total) experimental=$(summary.experimental) candidate=$(summary.candidate)"
end

"""
    search_widget_stabilization_closeout_complete(query; family=nothing)

Return `true` when no unified widget stabilization closeout records match
`query`.
"""
search_widget_stabilization_closeout_complete(query; family=nothing) =
    search_widget_stabilization_closeout_count(query; family=family) == 0

"""
    assert_search_widget_stabilization_closeout_complete(query; family=nothing)

Return `true` when no unified widget stabilization closeout records match
`query`, or throw an `ArgumentError` naming the first matching records.
"""
function assert_search_widget_stabilization_closeout_complete(query; family=nothing)
    records = search_widget_stabilization_closeout_records(query; family=family)
    isempty(records) && return true
    details = join((
        "$(record.kind):$(record.name)"
        for record in Iterators.take(records, 5)
    ), "; ")
    throw(ArgumentError("filtered widget stabilization closeout is incomplete for query $(repr(string(query))): $details"))
end

"""
    search_widget_stabilization_closeout_markdown(query; family=nothing)

Render matching widget stabilization closeout records as a GitHub-flavored
Markdown table.
"""
function search_widget_stabilization_closeout_markdown(query; family=nothing)
    rows = String["| `kind` | `name` | `family` | `family_slug` | `source` | `surface` | `status` | `action` | `reason` |", "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(record.kind)) | $(_escape_widget_catalog_markdown(record.name)) | $(_escape_widget_catalog_markdown(record.family)) | $(_escape_widget_catalog_markdown(record.family_slug)) | $(_escape_widget_catalog_markdown(record.source)) | $(_escape_widget_catalog_markdown(record.surface)) | $(_escape_widget_catalog_markdown(record.status)) | $(_escape_widget_catalog_markdown(record.action)) | $(_escape_widget_catalog_markdown(record.reason)) |"
        for record in search_widget_stabilization_closeout_records(query; family=family)
    )
    return join(rows, "\n")
end

"""
    search_widget_stabilization_closeout_tsv(query; family=nothing, header=true)

Render matching widget stabilization closeout records as tab-separated values.
"""
function search_widget_stabilization_closeout_tsv(query; family=nothing, header::Bool=true)
    rows = header ? String["kind\tname\tfamily\tfamily_slug\tsource\tsurface\tstatus\taction\treason"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(record.kind))\t$(_escape_widget_catalog_tsv(record.name))\t$(_escape_widget_catalog_tsv(record.family))\t$(_escape_widget_catalog_tsv(record.family_slug))\t$(_escape_widget_catalog_tsv(record.source))\t$(_escape_widget_catalog_tsv(record.surface))\t$(_escape_widget_catalog_tsv(record.status))\t$(_escape_widget_catalog_tsv(record.action))\t$(_escape_widget_catalog_tsv(record.reason))"
        for record in search_widget_stabilization_closeout_records(query; family=family)
    )
    return join(rows, "\n")
end

"""
    search_widget_stabilization_closeout_json(query; family=nothing)

Render matching widget stabilization closeout records as compact JSON.
"""
function search_widget_stabilization_closeout_json(query; family=nothing)
    records = search_widget_stabilization_closeout_records(query; family=family)
    rows = String[
        "    {\"kind\": $(_widget_coverage_json_string(record.kind)), \"name\": $(_widget_coverage_json_string(record.name)), \"family\": $(_widget_coverage_json_string(record.family)), \"family_slug\": $(_widget_coverage_json_string(record.family_slug)), \"source\": $(_widget_coverage_json_string(record.source)), \"surface\": $(_widget_coverage_json_string(record.surface)), \"status\": $(_widget_coverage_json_string(record.status)), \"action\": $(_widget_coverage_json_string(record.action)), \"reason\": $(_widget_coverage_json_string(record.reason))}$(index == length(records) ? "" : ",")"
        for (index, record) in enumerate(records)
    ]
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"query\": $(_widget_coverage_json_string(query)),",
        "  \"match_count\": $(length(records)),",
        "  \"matches\": [",
        join(rows, "\n"),
        "  ]",
        "}",
    ), "\n")
end

"""
    search_widget_stabilization_closeout_text(query; family=nothing)

Render matching widget stabilization closeout records as newline-separated
human-readable log lines.
"""
function search_widget_stabilization_closeout_text(query; family=nothing)
    return join((
        "$(record.kind):$(record.name) action=$(record.action) reason=$(record.reason)"
        for record in search_widget_stabilization_closeout_records(query; family=family)
    ), "\n")
end

"""
    search_widget_stabilization_closeout_artifacts(query; family=nothing)

Return one aggregate artifact bundle for filtered widget stabilization closeout
records, including structured records, count, and rendered text, Markdown, TSV,
and JSON outputs.
"""
function search_widget_stabilization_closeout_artifacts(query; family=nothing)
    return (
        schema_version=1,
        query=string(query),
        count=search_widget_stabilization_closeout_count(query; family=family),
        summary=search_widget_stabilization_closeout_summary(query; family=family),
        summary_records=search_widget_stabilization_closeout_summary_records(query; family=family),
        summary_text=search_widget_stabilization_closeout_summary_text(query; family=family),
        summary_markdown=search_widget_stabilization_closeout_summary_markdown(query; family=family),
        summary_tsv=search_widget_stabilization_closeout_summary_tsv(query; family=family),
        summary_json=search_widget_stabilization_closeout_summary_json(query; family=family),
        records=search_widget_stabilization_closeout_records(query; family=family),
        text=search_widget_stabilization_closeout_text(query; family=family),
        markdown=search_widget_stabilization_closeout_markdown(query; family=family),
        tsv=search_widget_stabilization_closeout_tsv(query; family=family),
        json=search_widget_stabilization_closeout_json(query; family=family),
    )
end

"""
    widget_stabilization_closeout_count(; family=nothing)

Return the number of remaining experimental bindings and non-stable reviewed
widget catalog candidates in the unified stabilization closeout list.
"""
widget_stabilization_closeout_count(; family=nothing) =
    length(widget_stabilization_closeout_records(; family=family))

"""
    widget_stabilization_closeout_complete(; family=nothing)

Return `true` when the unified experimental/candidate widget stabilization
closeout list is empty.
"""
widget_stabilization_closeout_complete(; family=nothing) =
    widget_stabilization_closeout_count(; family=family) == 0

"""
    assert_widget_stabilization_closeout_complete(; family=nothing)

Return `true` when the unified experimental/candidate closeout list is empty,
or throw an `ArgumentError` naming the first remaining closeout records.
"""
function assert_widget_stabilization_closeout_complete(; family=nothing)
    records = widget_stabilization_closeout_records(; family=family)
    isempty(records) && return true
    details = join((
        "$(record.kind):$(record.name)"
        for record in Iterators.take(records, 5)
    ), "; ")
    throw(ArgumentError("widget stabilization closeout is incomplete: $details"))
end

"""
    widget_stabilization_closeout_summary(; family=nothing)

Return compact counts for the unified widget stabilization closeout list.
"""
function widget_stabilization_closeout_summary(; family=nothing)
    records = widget_stabilization_closeout_records(; family=family)
    return (
        total=length(records),
        experimental=count(record -> record.kind === :experimental, records),
        candidate=count(record -> record.kind === :candidate, records),
    )
end

"""
    widget_stabilization_closeout_summary_records(; family=nothing)

Return closeout summary counts as named tuples with `metric`, `key`, and
`count` fields.
"""
function widget_stabilization_closeout_summary_records(; family=nothing)
    summary = widget_stabilization_closeout_summary(; family=family)
    return [
        (metric="total", key="all", count=summary.total),
        (metric="kind", key="experimental", count=summary.experimental),
        (metric="kind", key="candidate", count=summary.candidate),
    ]
end

"""
    widget_stabilization_closeout_summary_markdown(; family=nothing)

Render compact closeout summary counts as a GitHub-flavored Markdown table.
"""
function widget_stabilization_closeout_summary_markdown(; family=nothing)
    rows = String["| `metric` | `key` | `count` |", "| --- | --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(record.metric)) | $(_escape_widget_catalog_markdown(record.key)) | $(record.count) |"
        for record in widget_stabilization_closeout_summary_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_closeout_summary_tsv(; family=nothing, header=true)

Render compact closeout summary counts as tab-separated values.
"""
function widget_stabilization_closeout_summary_tsv(; family=nothing, header::Bool=true)
    rows = header ? String["metric\tkey\tcount"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(record.metric))\t$(_escape_widget_catalog_tsv(record.key))\t$(record.count)"
        for record in widget_stabilization_closeout_summary_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_closeout_summary_json(; family=nothing)

Render compact closeout summary counts as JSON for dashboards and CI artifacts.
"""
function widget_stabilization_closeout_summary_json(; family=nothing)
    summary = widget_stabilization_closeout_summary(; family=family)
    records = widget_stabilization_closeout_summary_records(; family=family)
    rows = String[
        "    {\"metric\": $(_widget_coverage_json_string(record.metric)), \"key\": $(_widget_coverage_json_string(record.key)), \"count\": $(record.count)}$(index == length(records) ? "" : ",")"
        for (index, record) in enumerate(records)
    ]
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"total\": $(summary.total),",
        "  \"experimental\": $(summary.experimental),",
        "  \"candidate\": $(summary.candidate),",
        "  \"records\": [",
        join(rows, "\n"),
        "  ]",
        "}",
    ), "\n")
end

"""
    widget_stabilization_closeout_summary_text(; family=nothing)

Render compact closeout summary counts as one log-friendly status line.
"""
function widget_stabilization_closeout_summary_text(; family=nothing)
    summary = widget_stabilization_closeout_summary(; family=family)
    return "total=$(summary.total) experimental=$(summary.experimental) candidate=$(summary.candidate)"
end

"""
    widget_stabilization_closeout_status_record(; family=nothing)

Return one aggregate status record for the experimental/candidate widget
stabilization closeout gate.
"""
function widget_stabilization_closeout_status_record(; family=nothing)
    summary = widget_stabilization_closeout_summary(; family=family)
    complete = summary.total == 0
    return (
        complete=complete,
        closeout_count=summary.total,
        experimental_count=summary.experimental,
        candidate_count=summary.candidate,
    )
end

"""
    widget_stabilization_closeout_status_text(; family=nothing)

Render the experimental/candidate widget stabilization closeout status as one
compact log-friendly line.
"""
function widget_stabilization_closeout_status_text(; family=nothing)
    record = widget_stabilization_closeout_status_record(; family=family)
    return join((
        "complete=$(record.complete)",
        "closeout_count=$(record.closeout_count)",
        "experimental_count=$(record.experimental_count)",
        "candidate_count=$(record.candidate_count)",
    ), " ")
end

"""
    widget_stabilization_closeout_status_json(; family=nothing)

Render the experimental/candidate widget stabilization closeout status as
compact JSON for release dashboards and CI artifacts.
"""
function widget_stabilization_closeout_status_json(; family=nothing)
    record = widget_stabilization_closeout_status_record(; family=family)
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"complete\": $(record.complete),",
        "  \"closeout_count\": $(record.closeout_count),",
        "  \"experimental_count\": $(record.experimental_count),",
        "  \"candidate_count\": $(record.candidate_count)",
        "}",
    ), "\n")
end

"""
    widget_stabilization_closeout_status_markdown(; family=nothing)

Render the experimental/candidate widget stabilization closeout status as a
GitHub-flavored Markdown table.
"""
function widget_stabilization_closeout_status_markdown(; family=nothing)
    record = widget_stabilization_closeout_status_record(; family=family)
    rows = [
        (metric="complete", value=record.complete),
        (metric="closeout_count", value=record.closeout_count),
        (metric="experimental_count", value=record.experimental_count),
        (metric="candidate_count", value=record.candidate_count),
    ]
    output = String["| `metric` | `value` |", "| --- | --- |"]
    append!(
        output,
        "| $(_escape_widget_catalog_markdown(row.metric)) | $(_escape_widget_catalog_markdown(row.value)) |"
        for row in rows
    )
    return join(output, "\n")
end

"""
    widget_stabilization_closeout_status_tsv(; family=nothing, header=true)

Render the experimental/candidate widget stabilization closeout status as
tab-separated values.
"""
function widget_stabilization_closeout_status_tsv(; family=nothing, header::Bool=true)
    record = widget_stabilization_closeout_status_record(; family=family)
    rows = [
        (metric="complete", value=record.complete),
        (metric="closeout_count", value=record.closeout_count),
        (metric="experimental_count", value=record.experimental_count),
        (metric="candidate_count", value=record.candidate_count),
    ]
    output = header ? String["metric\tvalue"] : String[]
    append!(
        output,
        "$(_escape_widget_catalog_tsv(row.metric))\t$(_escape_widget_catalog_tsv(row.value))"
        for row in rows
    )
    return join(output, "\n")
end

"""
    widget_stabilization_closeout_markdown(; family=nothing)

Render remaining widget stabilization closeout work as a GitHub-flavored
Markdown table with `kind`, `name`, `family`, `family_slug`, `source`,
`surface`, `status`, `action`, and `reason` columns.
"""
function widget_stabilization_closeout_markdown(; family=nothing)
    rows = String["| `kind` | `name` | `family` | `family_slug` | `source` | `surface` | `status` | `action` | `reason` |", "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(record.kind)) | $(_escape_widget_catalog_markdown(record.name)) | $(_escape_widget_catalog_markdown(record.family)) | $(_escape_widget_catalog_markdown(record.family_slug)) | $(_escape_widget_catalog_markdown(record.source)) | $(_escape_widget_catalog_markdown(record.surface)) | $(_escape_widget_catalog_markdown(record.status)) | $(_escape_widget_catalog_markdown(record.action)) | $(_escape_widget_catalog_markdown(record.reason)) |"
        for record in widget_stabilization_closeout_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_closeout_tsv(; family=nothing, header=true)

Render remaining widget stabilization closeout work as tab-separated values
with `kind`, `name`, `family`, `family_slug`, `source`, `surface`, `status`,
`action`, and `reason` columns.
"""
function widget_stabilization_closeout_tsv(; family=nothing, header::Bool=true)
    rows = header ? String["kind\tname\tfamily\tfamily_slug\tsource\tsurface\tstatus\taction\treason"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(record.kind))\t$(_escape_widget_catalog_tsv(record.name))\t$(_escape_widget_catalog_tsv(record.family))\t$(_escape_widget_catalog_tsv(record.family_slug))\t$(_escape_widget_catalog_tsv(record.source))\t$(_escape_widget_catalog_tsv(record.surface))\t$(_escape_widget_catalog_tsv(record.status))\t$(_escape_widget_catalog_tsv(record.action))\t$(_escape_widget_catalog_tsv(record.reason))"
        for record in widget_stabilization_closeout_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_closeout_json(; family=nothing)

Render remaining widget stabilization closeout work as compact JSON for release
dashboards, CI artifacts, and stabilization automation.
"""
function widget_stabilization_closeout_json(; family=nothing)
    records = widget_stabilization_closeout_records(; family=family)
    rows = String[
        "    {\"kind\": $(_widget_coverage_json_string(record.kind)), \"name\": $(_widget_coverage_json_string(record.name)), \"family\": $(_widget_coverage_json_string(record.family)), \"family_slug\": $(_widget_coverage_json_string(record.family_slug)), \"source\": $(_widget_coverage_json_string(record.source)), \"surface\": $(_widget_coverage_json_string(record.surface)), \"status\": $(_widget_coverage_json_string(record.status)), \"action\": $(_widget_coverage_json_string(record.action)), \"reason\": $(_widget_coverage_json_string(record.reason))}$(index == length(records) ? "" : ",")"
        for (index, record) in enumerate(records)
    ]
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"closeout_count\": $(length(records)),",
        "  \"closeout\": [",
        join(rows, "\n"),
        "  ]",
        "}",
    ), "\n")
end

"""
    widget_stabilization_closeout_text(; family=nothing)

Render remaining widget stabilization closeout work as newline-separated
human-readable log lines.
"""
function widget_stabilization_closeout_text(; family=nothing)
    return join((
        "$(record.kind):$(record.name) action=$(record.action) reason=$(record.reason)"
        for record in widget_stabilization_closeout_records(; family=family)
    ), "\n")
end

"""
    widget_stabilization_closeout_artifacts(; family=nothing)

Return one aggregate closeout artifact bundle with structured records, summary,
status, and rendered text, Markdown, TSV, and JSON outputs.
"""
function widget_stabilization_closeout_artifacts(; family=nothing)
    return (
        schema_version=1,
        status=widget_stabilization_closeout_status_record(; family=family),
        summary=widget_stabilization_closeout_summary(; family=family),
        records=widget_stabilization_closeout_records(; family=family),
        status_text=widget_stabilization_closeout_status_text(; family=family),
        status_markdown=widget_stabilization_closeout_status_markdown(; family=family),
        status_tsv=widget_stabilization_closeout_status_tsv(; family=family),
        status_json=widget_stabilization_closeout_status_json(; family=family),
        summary_text=widget_stabilization_closeout_summary_text(; family=family),
        summary_markdown=widget_stabilization_closeout_summary_markdown(; family=family),
        summary_tsv=widget_stabilization_closeout_summary_tsv(; family=family),
        summary_json=widget_stabilization_closeout_summary_json(; family=family),
        text=widget_stabilization_closeout_text(; family=family),
        markdown=widget_stabilization_closeout_markdown(; family=family),
        tsv=widget_stabilization_closeout_tsv(; family=family),
        json=widget_stabilization_closeout_json(; family=family),
    )
end

"""
    candidate_widget_count(; family=nothing)

Return the number of reviewed widget catalog names that are not yet stable on
the stable application surface.
"""
candidate_widget_count(; family=nothing) =
    length(candidate_widget_records(; family=family))

"""
    widget_stabilization_status_record(; family=nothing)

Return one aggregate stabilization record for release tooling. The record
combines stable catalog count, remaining candidate widgets, exported
experimental bindings, behavior/stability blockers, and family closeout
blockers.
"""
function widget_stabilization_status_record(; family=nothing)
    catalog_summary = widget_catalog_summary(; status=nothing, surface=nothing, family=family)
    stability_summary = widget_stability_summary(; status=nothing, surface=nothing, family=family)
    closeout_summary = widget_family_closeout_summary(; family=family)
    candidates = candidate_widget_names(; family=family)
    experimental = experimental_widget_names(; family=family)
    candidate_count = candidate_widget_count(; family=family)
    ready = isempty(candidates) &&
            isempty(experimental) &&
            stability_summary.blocked == 0 &&
            closeout_summary.blocked == 0
    return (
        ready=ready,
        total_widgets=catalog_summary.total,
        stable_widgets=get(catalog_summary.by_status, :stable, 0),
        candidate_widget_count=candidate_count,
        candidate_widgets=candidates,
        experimental_widget_count=length(experimental),
        experimental_widgets=experimental,
        stability_blocked=stability_summary.blocked,
        family_closeout_blocked=closeout_summary.blocked,
    )
end

"""
    widget_stabilization_status_text(; family=nothing)

Render a compact stabilization status line for dashboards, release notes, and
CI logs.
"""
function widget_stabilization_status_text(; family=nothing)
    record = widget_stabilization_status_record(; family=family)
    return join((
        "ready=$(record.ready)",
        "total_widgets=$(record.total_widgets)",
        "stable_widgets=$(record.stable_widgets)",
        "candidate_widgets=$(record.candidate_widget_count)",
        "experimental_widgets=$(record.experimental_widget_count)",
        "stability_blocked=$(record.stability_blocked)",
        "family_closeout_blocked=$(record.family_closeout_blocked)",
    ), " ")
end

function _widget_stabilization_status_rows(record)
    return [
        (metric="ready", value=record.ready),
        (metric="total_widgets", value=record.total_widgets),
        (metric="stable_widgets", value=record.stable_widgets),
        (metric="candidate_widget_count", value=record.candidate_widget_count),
        (metric="candidate_widgets", value=join((String(name) for name in record.candidate_widgets), ", ")),
        (metric="experimental_widget_count", value=record.experimental_widget_count),
        (metric="experimental_widgets", value=join((String(name) for name in record.experimental_widgets), ", ")),
        (metric="stability_blocked", value=record.stability_blocked),
        (metric="family_closeout_blocked", value=record.family_closeout_blocked),
    ]
end

"""
    widget_stabilization_status_records(; family=nothing)

Return aggregate widget stabilization status as named tuples with `metric` and
`value` fields. Use this when review tooling needs structured closeout data
without parsing text, Markdown, TSV, or JSON.
"""
widget_stabilization_status_records(; family=nothing) =
    _widget_stabilization_status_rows(widget_stabilization_status_record(; family=family))

"""
    widget_stabilization_status_markdown(; family=nothing)

Render the aggregate widget stabilization status as a GitHub-flavored Markdown
table for review packets, release notes, and CI artifacts.
"""
function widget_stabilization_status_markdown(; family=nothing)
    rows = String["| `metric` | `value` |", "| --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(row.metric)) | $(_escape_widget_catalog_markdown(row.value)) |"
        for row in widget_stabilization_status_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_status_tsv(; family=nothing, header=true)

Render the aggregate widget stabilization status as tab-separated values for
shell workflows and release automation.
"""
function widget_stabilization_status_tsv(; family=nothing, header::Bool=true)
    rows = header ? String["metric\tvalue"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(row.metric))\t$(_escape_widget_catalog_tsv(row.value))"
        for row in widget_stabilization_status_records(; family=family)
    )
    return join(rows, "\n")
end

function _widget_stabilization_sample(names::Vector{Symbol})
    isempty(names) && return ""
    sample = join((String(name) for name in Iterators.take(names, 5)), ", ")
    return length(names) > 5 ? "$sample, ..." : sample
end

"""
    _widget_stabilization_blocker_records(; family=nothing)

Build structured stabilization blocker records for the reviewed widget surface.
"""
function _widget_stabilization_blocker_records(; family=nothing)
    record = widget_stabilization_status_record(; family=family)
    blockers = NamedTuple{(:category, :count, :details),Tuple{String,Int,String}}[]
    record.candidate_widget_count == 0 ||
        push!(
            blockers,
            (
                category="candidate_widgets",
                count=record.candidate_widget_count,
                details="candidate widgets remain: $(_widget_stabilization_sample(record.candidate_widgets))",
            ),
        )
    record.experimental_widget_count == 0 ||
        push!(
            blockers,
            (
                category="experimental_widgets",
                count=record.experimental_widget_count,
                details="experimental widget bindings remain: $(_widget_stabilization_sample(record.experimental_widgets))",
            ),
        )
    record.stability_blocked == 0 ||
        push!(
            blockers,
            (
                category="stability_blockers",
                count=record.stability_blocked,
                details="widget stability blockers remain: $(record.stability_blocked)",
            ),
        )
    record.family_closeout_blocked == 0 ||
        push!(
            blockers,
            (
                category="family_closeout_blockers",
                count=record.family_closeout_blocked,
                details="family closeout blockers remain: $(record.family_closeout_blocked)",
            ),
        )
    return blockers
end

"""
    widget_stabilization_blocker_records(; family=nothing)

Return structured stabilization blocker records with `category`, `count`, and
`details` fields. An empty vector means the stabilization closeout is ready.
"""
widget_stabilization_blocker_records(; family=nothing) =
    _widget_stabilization_blocker_records(; family=family)

"""
    widget_stabilization_blocker_records_markdown(; family=nothing)

Render structured stabilization blocker records as a GitHub-flavored Markdown
table with `category`, `count`, and `details` columns.
"""
function widget_stabilization_blocker_records_markdown(; family=nothing)
    rows = String["| `category` | `count` | `details` |", "| --- | --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(record.category)) | $(record.count) | $(_escape_widget_catalog_markdown(record.details)) |"
        for record in widget_stabilization_blocker_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_blocker_records_tsv(; family=nothing, header=true)

Render structured stabilization blocker records as tab-separated values with
`category`, `count`, and `details` columns.
"""
function widget_stabilization_blocker_records_tsv(; family=nothing, header::Bool=true)
    rows = header ? String["category\tcount\tdetails"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(record.category))\t$(record.count)\t$(_escape_widget_catalog_tsv(record.details))"
        for record in widget_stabilization_blocker_records(; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_blocker_records_json(; family=nothing)

Render structured stabilization blocker records as compact JSON for dashboards,
release automation, and CI artifacts.
"""
function widget_stabilization_blocker_records_json(; family=nothing)
    records = widget_stabilization_blocker_records(; family=family)
    rows = String[
        "    {\"category\": $(_widget_coverage_json_string(record.category)), \"count\": $(record.count), \"details\": $(_widget_coverage_json_string(record.details))}$(index == length(records) ? "" : ",")"
        for (index, record) in enumerate(records)
    ]
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"blocker_count\": $(length(records)),",
        "  \"blockers\": [",
        join(rows, "\n"),
        "  ]",
        "}",
    ), "\n")
end

"""
    widget_stabilization_blockers(; family=nothing)

Return human-readable blocker details for the reviewed widget stabilization
closeout. An empty vector means the stabilization closeout is ready.
"""
function widget_stabilization_blockers(; family=nothing)
    return String[record.details for record in widget_stabilization_blocker_records(; family=family)]
end

"""
    widget_stabilization_blocker_count(; family=nothing)

Return the number of widget stabilization blocker categories for the reviewed
widget surface.
"""
widget_stabilization_blocker_count(; family=nothing) =
    length(widget_stabilization_blockers(; family=family))

"""
    widget_stabilization_blockers_text(; family=nothing)

Render stabilization blocker details as newline-separated text.
"""
widget_stabilization_blockers_text(; family=nothing) =
    join(widget_stabilization_blockers(; family=family), "\n")

"""
    widget_stabilization_blockers_markdown(; family=nothing)

Render stabilization blocker details as a GitHub-flavored Markdown table.
"""
function widget_stabilization_blockers_markdown(; family=nothing)
    rows = String["| `blocker` |", "| --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(blocker)) |"
        for blocker in widget_stabilization_blockers(; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_blockers_tsv(; family=nothing, header=true)

Render stabilization blocker details as tab-separated values.
"""
function widget_stabilization_blockers_tsv(; family=nothing, header::Bool=true)
    rows = header ? String["blocker"] : String[]
    append!(
        rows,
        _escape_widget_catalog_tsv(blocker)
        for blocker in widget_stabilization_blockers(; family=family)
    )
    return join(rows, "\n")
end

"""
    widget_stabilization_ready(; family=nothing)

Return `true` when the reviewed widget surface has no experimental bindings,
non-stable catalog candidates, stability blockers, or family closeout blockers.
"""
widget_stabilization_ready(; family=nothing) =
    widget_stabilization_status_record(; family=family).ready

"""
    assert_widget_stabilization_ready(; family=nothing)

Return `true` when the reviewed widget surface has no experimental bindings,
non-stable catalog candidates, stability blockers, or family closeout blockers.
Otherwise throw an `ArgumentError` describing the blocking counts.
"""
function assert_widget_stabilization_ready(; family=nothing)
    record = widget_stabilization_status_record(; family=family)
    record.ready && return true
    blockers = widget_stabilization_blockers(; family=family)
    throw(ArgumentError("widget stabilization closeout is not ready: $(join(blockers, "; "))"))
end

"""
    widget_stabilization_status_json(; family=nothing)

Render the stabilization closeout status as compact JSON for dashboards,
release artifacts, and CI automation.
"""
function widget_stabilization_status_json(; family=nothing)
    record = widget_stabilization_status_record(; family=family)
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"ready\": $(record.ready),",
        "  \"total_widgets\": $(record.total_widgets),",
        "  \"stable_widgets\": $(record.stable_widgets),",
        "  \"candidate_widget_count\": $(record.candidate_widget_count),",
        "  \"candidate_widgets\": $(_widget_stability_json_array(record.candidate_widgets)),",
        "  \"experimental_widget_count\": $(record.experimental_widget_count),",
        "  \"experimental_widgets\": $(_widget_stability_json_array(record.experimental_widgets)),",
        "  \"stability_blocked\": $(record.stability_blocked),",
        "  \"family_closeout_blocked\": $(record.family_closeout_blocked)",
        "}",
    ), "\n")
end

"""
    widget_stabilization_artifacts(; family=nothing)

Return one aggregate widget stabilization evidence bundle for release tooling.
The bundle includes broad stabilization status, blockers, closeout evidence,
stability summary, and family-closeout summary.
"""
function widget_stabilization_artifacts(; family=nothing)
    return (
        schema_version=1,
        status=widget_stabilization_status_record(; family=family),
        ready=widget_stabilization_ready(; family=family),
        status_text=widget_stabilization_status_text(; family=family),
        status_markdown=widget_stabilization_status_markdown(; family=family),
        status_tsv=widget_stabilization_status_tsv(; family=family),
        status_json=widget_stabilization_status_json(; family=family),
        blockers=widget_stabilization_blockers(; family=family),
        blocker_count=widget_stabilization_blocker_count(; family=family),
        blockers_text=widget_stabilization_blockers_text(; family=family),
        blockers_markdown=widget_stabilization_blockers_markdown(; family=family),
        blockers_tsv=widget_stabilization_blockers_tsv(; family=family),
        blocker_records=widget_stabilization_blocker_records(; family=family),
        blocker_records_markdown=widget_stabilization_blocker_records_markdown(; family=family),
        blocker_records_tsv=widget_stabilization_blocker_records_tsv(; family=family),
        blocker_records_json=widget_stabilization_blocker_records_json(; family=family),
        closeout=widget_stabilization_closeout_artifacts(; family=family),
        stability_summary=widget_stability_summary(; family=family),
        stability_summary_records=widget_stability_summary_records(; family=family),
        stability_summary_text=widget_stability_summary_text(; family=family),
        stability_summary_markdown=widget_stability_summary_markdown(; family=family),
        stability_summary_tsv=widget_stability_summary_tsv(; family=family),
        stability_json=widget_stability_json(; family=family),
        family_closeout_summary=widget_family_closeout_summary(; family=family),
    )
end

"""
    widget_stabilization_artifacts_json(; family=nothing)

Render the aggregate widget stabilization evidence bundle as one JSON document
for release dashboards and CI artifacts.
"""
function widget_stabilization_artifacts_json(; family=nothing)
    artifacts = widget_stabilization_artifacts(; family=family)
    return join((
        "{",
        "  \"schema_version\": $(artifacts.schema_version),",
        "  \"ready\": $(artifacts.ready),",
        "  \"status\": $(artifacts.status_json),",
        "  \"blocker_count\": $(artifacts.blocker_count),",
        "  \"blocker_records\": $(artifacts.blocker_records_json),",
        "  \"closeout\": $(artifacts.closeout.json),",
        "  \"closeout_status\": $(artifacts.closeout.status_json),",
        "  \"closeout_summary\": $(artifacts.closeout.summary_json),",
        "  \"stability\": $(artifacts.stability_json)",
        "}",
    ), "\n")
end

"""
    widget_stabilization_artifacts_text(; family=nothing)

Render the aggregate widget stabilization evidence bundle as compact
newline-separated text for CI logs and release review notes.
"""
function widget_stabilization_artifacts_text(; family=nothing)
    artifacts = widget_stabilization_artifacts(; family=family)
    lines = String[
        "ready=$(artifacts.ready)",
        "status $(artifacts.status_text)",
        "closeout $(artifacts.closeout.status_text)",
        "closeout_summary $(artifacts.closeout.summary_text)",
        "stability_summary $(artifacts.stability_summary_text)",
        "blocker_count=$(artifacts.blocker_count)",
    ]
    if !isempty(artifacts.blockers)
        push!(lines, "blockers:")
        append!(lines, artifacts.blockers)
    end
    return join(lines, "\n")
end

"""
    widget_stabilization_artifacts_markdown(; family=nothing)

Render the aggregate widget stabilization evidence bundle as a compact
GitHub-flavored Markdown table for release review notes.
"""
function widget_stabilization_artifacts_markdown(; family=nothing)
    artifacts = widget_stabilization_artifacts(; family=family)
    rows = [
        (metric="schema_version", value=artifacts.schema_version),
        (metric="ready", value=artifacts.ready),
        (metric="total_widgets", value=artifacts.status.total_widgets),
        (metric="stable_widgets", value=artifacts.status.stable_widgets),
        (metric="candidate_widget_count", value=artifacts.status.candidate_widget_count),
        (metric="experimental_widget_count", value=artifacts.status.experimental_widget_count),
        (metric="stability_blocked", value=artifacts.status.stability_blocked),
        (metric="family_closeout_blocked", value=artifacts.status.family_closeout_blocked),
        (metric="closeout_count", value=artifacts.closeout.status.closeout_count),
        (metric="blocker_count", value=artifacts.blocker_count),
    ]
    output = String["| `metric` | `value` |", "| --- | --- |"]
    append!(
        output,
        "| $(_escape_widget_catalog_markdown(row.metric)) | $(_escape_widget_catalog_markdown(row.value)) |"
        for row in rows
    )
    return join(output, "\n")
end

"""
    widget_stabilization_artifacts_tsv(; family=nothing, header=true)

Render the aggregate widget stabilization evidence bundle as tab-separated
values for release automation.
"""
function widget_stabilization_artifacts_tsv(; family=nothing, header::Bool=true)
    artifacts = widget_stabilization_artifacts(; family=family)
    rows = [
        (metric="schema_version", value=artifacts.schema_version),
        (metric="ready", value=artifacts.ready),
        (metric="total_widgets", value=artifacts.status.total_widgets),
        (metric="stable_widgets", value=artifacts.status.stable_widgets),
        (metric="candidate_widget_count", value=artifacts.status.candidate_widget_count),
        (metric="experimental_widget_count", value=artifacts.status.experimental_widget_count),
        (metric="stability_blocked", value=artifacts.status.stability_blocked),
        (metric="family_closeout_blocked", value=artifacts.status.family_closeout_blocked),
        (metric="closeout_count", value=artifacts.closeout.status.closeout_count),
        (metric="blocker_count", value=artifacts.blocker_count),
    ]
    output = header ? String["metric\tvalue"] : String[]
    append!(
        output,
        "$(_escape_widget_catalog_tsv(row.metric))\t$(_escape_widget_catalog_tsv(row.value))"
        for row in rows
    )
    return join(output, "\n")
end

"""
    widget_stabilization_artifacts_ready(; family=nothing)

Return `true` when the aggregate widget stabilization evidence bundle is ready.
"""
widget_stabilization_artifacts_ready(; family=nothing) =
    widget_stabilization_artifacts(; family=family).ready

"""
    assert_widget_stabilization_artifacts_ready(; family=nothing)

Return the aggregate widget stabilization evidence bundle when it is ready, or
throw an `ArgumentError` with closeout and blocker counts.
"""
function assert_widget_stabilization_artifacts_ready(; family=nothing)
    artifacts = widget_stabilization_artifacts(; family=family)
    artifacts.ready && return artifacts
    throw(ArgumentError(
        "widget stabilization artifacts are not ready: " *
        "closeout_count=$(artifacts.closeout.status.closeout_count), " *
        "blocker_count=$(artifacts.blocker_count), " *
        "stability_blocked=$(artifacts.status.stability_blocked), " *
        "family_closeout_blocked=$(artifacts.status.family_closeout_blocked)"
    ))
end

"""
    assert_widget_stability_ready(name; status=nothing, surface=nothing)

Return the widget stability report when it is ready, or throw an `ArgumentError`
listing the blockers.
"""
function assert_widget_stability_ready(name; status=nothing, surface=nothing)
    report = widget_stability_report(name; status=status, surface=surface)
    report.ready && return report
    throw(ArgumentError("widget $(report.name) is not ready for stable promotion: $(join(report.blockers, "; "))"))
end

function _widget_stability_markdown(reports, selected)
    header = join(("`$(String(column))`" for column in selected), " | ")
    separator = join(fill("---", length(selected)), " | ")
    output = String["| $header |", "| $separator |"]
    for report in reports
        push!(output, "| $(join((_escape_widget_catalog_markdown(_widget_stability_field(report, column)) for column in selected), " | ")) |")
    end
    return join(output, "\n")
end

function _widget_stability_tsv(reports, selected; header::Bool=true)
    output = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for report in reports
        push!(output, join((_escape_widget_catalog_tsv(_widget_stability_field(report, column)) for column in selected), "\t"))
    end
    return join(output, "\n")
end

"""
    widget_stability_markdown(; status=nothing, surface=nothing, family=nothing, columns=(:name, :family, :ready, :blockers))

Render widget promotion-readiness reports as a GitHub-flavored Markdown table.
"""
function widget_stability_markdown(;
    status=nothing,
    surface=nothing,
    family=nothing,
    columns=(:name, :family, :ready, :blockers),
)
    selected = _widget_stability_columns(columns)
    return _widget_stability_markdown(widget_stability_reports(; status=status, surface=surface, family=family), selected)
end

"""
    widget_stability_gaps_markdown(; status=nothing, surface=nothing, family=nothing, columns=(:name, :family, :ready, :blockers))

Render only widget promotion-readiness reports that still have blockers.
"""
function widget_stability_gaps_markdown(;
    status=nothing,
    surface=nothing,
    family=nothing,
    columns=(:name, :family, :ready, :blockers),
)
    selected = _widget_stability_columns(columns)
    return _widget_stability_markdown(widget_stability_gaps(; status=status, surface=surface, family=family), selected)
end

"""
    widget_stability_tsv(; status=nothing, surface=nothing, family=nothing, columns=(:name, :family, :ready, :blockers), header=true)

Render widget promotion-readiness reports as tab-separated values.
"""
function widget_stability_tsv(;
    status=nothing,
    surface=nothing,
    family=nothing,
    columns=(:name, :family, :ready, :blockers),
    header::Bool=true,
)
    selected = _widget_stability_columns(columns)
    return _widget_stability_tsv(widget_stability_reports(; status=status, surface=surface, family=family), selected; header=header)
end

"""
    widget_stability_gaps_tsv(; status=nothing, surface=nothing, family=nothing, columns=(:name, :family, :ready, :blockers), header=true)

Render only widget promotion-readiness reports that still have blockers as
tab-separated values.
"""
function widget_stability_gaps_tsv(;
    status=nothing,
    surface=nothing,
    family=nothing,
    columns=(:name, :family, :ready, :blockers),
    header::Bool=true,
)
    selected = _widget_stability_columns(columns)
    return _widget_stability_tsv(widget_stability_gaps(; status=status, surface=surface, family=family), selected; header=header)
end

function _widget_stability_json_array(values)
    return "[" * join((_widget_coverage_json_string(String(value)) for value in values), ", ") * "]"
end

"""
    widget_stability_json(; status=nothing, surface=nothing, family=nothing)

Render widget promotion-readiness reports as a versioned JSON artifact for
release dashboards and CI automation.
"""
function widget_stability_json(; status=nothing, surface=nothing, family=nothing)
    reports = widget_stability_reports(; status=status, surface=surface, family=family)
    ready_count = count(report -> report.ready, reports)
    blocked_count = length(reports) - ready_count
    generated_at = Dates.format(Dates.unix2datetime(time()), dateformat"yyyy-mm-ddTHH:MM:SS") * "Z"
    root = normpath(joinpath(@__DIR__, ".."))
    output = String[
        "{",
        "  \"schema_version\": 1,",
        "  \"metadata\": {",
        "    \"generated_at\": $(_widget_coverage_json_string(generated_at)),",
        "    \"root\": $(_widget_coverage_json_string(root))",
        "  },",
        "  \"ready\": $(blocked_count == 0),",
        "  \"summary\": {",
        "    \"total\": $(length(reports)),",
        "    \"ready\": $ready_count,",
        "    \"blocked\": $blocked_count",
        "  },",
        "  \"rows\": [",
    ]
    for (index, report) in enumerate(reports)
        suffix = index == length(reports) ? "" : ","
        push!(output, "    {")
        push!(output, "      \"name\": $(_widget_coverage_json_string(String(report.name))),")
        push!(output, "      \"family\": $(_widget_coverage_json_string(report.family)),")
        push!(output, "      \"family_slug\": $(_widget_coverage_json_string(report.family_slug)),")
        push!(output, "      \"surface\": $(_widget_coverage_json_string(String(report.surface))),")
        push!(output, "      \"status\": $(_widget_coverage_json_string(String(report.status))),")
        push!(output, "      \"catalog_source\": $(_widget_coverage_json_string(report.catalog_source)),")
        push!(output, "      \"coverage_source\": $(_widget_coverage_json_string(report.coverage_source)),")
        push!(output, "      \"stable\": $(report.stable),")
        push!(output, "      \"coverage_complete\": $(report.coverage_complete),")
        push!(output, "      \"ready\": $(report.ready),")
        push!(output, "      \"missing_checks\": $(_widget_stability_json_array(report.missing_checks)),")
        push!(output, "      \"blockers\": $(_widget_stability_json_array(report.blockers))")
        push!(output, "    }$suffix")
    end
    push!(output, "  ]")
    push!(output, "}")
    return join(output, "\n")
end

"""
    widget_coverage_gaps(; status=:stable, surface=:stable, family=nothing)

Return stable widget catalog rows whose behavior-evidence record is missing,
incomplete, or points at a different source file.
"""
widget_coverage_gaps(; status=:stable, surface=:stable, family=nothing) =
    [row for row in widget_coverage_records(; status=status, surface=surface, family=family) if !row.complete]

"""
    widget_coverage_issue_records(issue; status=:stable, surface=:stable, family=nothing)

Return stable widget coverage records for one issue class. `issue` may be
`:complete`, `:missing_record`, `:source_mismatch`, or `:missing_checks`.
"""
function widget_coverage_issue_records(issue; status=:stable, surface=:stable, family=nothing)
    selected_issue = _widget_coverage_issue(issue)
    return [
        row for row in widget_coverage_records(; status=status, surface=surface, family=family)
        if row.issue === selected_issue
    ]
end

"""
    widget_coverage_issue_count(issue; status=:stable, surface=:stable, family=nothing)

Return the number of stable widget coverage records for one issue class.
"""
widget_coverage_issue_count(issue; status=:stable, surface=:stable, family=nothing) =
    length(widget_coverage_issue_records(issue; status=status, surface=surface, family=family))

"""
    widget_coverage_issue_names(issue; status=:stable, surface=:stable, family=nothing)

Return stable widget names for one coverage issue class.
"""
widget_coverage_issue_names(issue; status=:stable, surface=:stable, family=nothing) =
    Symbol[row.name for row in widget_coverage_issue_records(issue; status=status, surface=surface, family=family)]

"""
    widget_coverage_issue_text(issue; status=:stable, surface=:stable, family=nothing)

Render stable widget names for one coverage issue class as newline-separated
text.
"""
widget_coverage_issue_text(issue; status=:stable, surface=:stable, family=nothing) =
    join((String(name) for name in widget_coverage_issue_names(issue; status=status, surface=surface, family=family)), "\n")

"""
    widget_coverage_issue_markdown(issue; status=:stable, surface=:stable, family=nothing, columns=(:name, :family, :issue, :missing_checks))

Render stable widget coverage records for one issue class as Markdown.
"""
function widget_coverage_issue_markdown(
    issue;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :family, :issue, :missing_checks),
)
    selected = _widget_coverage_columns(columns)
    return _widget_coverage_markdown(widget_coverage_issue_records(issue; status=status, surface=surface, family=family), selected)
end

"""
    widget_coverage_issue_tsv(issue; status=:stable, surface=:stable, family=nothing, columns=(:name, :family, :issue, :missing_checks), header=true)

Render stable widget coverage records for one issue class as tab-separated
values.
"""
function widget_coverage_issue_tsv(
    issue;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :family, :issue, :missing_checks),
    header::Bool=true,
)
    selected = _widget_coverage_columns(columns)
    return _widget_coverage_tsv(widget_coverage_issue_records(issue; status=status, surface=surface, family=family), selected; header=header)
end

"""
    widget_coverage_complete(; status=:stable, surface=:stable, family=nothing)

Return `true` when every reviewed stable widget matching the filters has a
complete behavior-evidence row with a matching source path.
"""
widget_coverage_complete(; status=:stable, surface=:stable, family=nothing) =
    isempty(widget_coverage_gaps(; status=status, surface=surface, family=family))

"""
    assert_widget_coverage_complete(; status=:stable, surface=:stable, family=nothing)

Return `true` when stable widget behavior evidence is complete, or throw an
`ArgumentError` with a compact gap count.
"""
function assert_widget_coverage_complete(; status=:stable, surface=:stable, family=nothing)
    gaps = widget_coverage_gaps(; status=status, surface=surface, family=family)
    isempty(gaps) && return true
    sample = join((String(row.name) for row in Iterators.take(gaps, 5)), ", ")
    suffix = length(gaps) > 5 ? ", ..." : ""
    throw(ArgumentError("stable widget coverage evidence has $(length(gaps)) gap(s): $(sample)$(suffix)"))
end

"""
    widget_coverage_summary(; status=:stable, surface=:stable, family=nothing)

Return aggregate counts for the stable widget coverage report.
"""
function widget_coverage_summary(; status=:stable, surface=:stable, family=nothing)
    rows = widget_coverage_records(; status=status, surface=surface, family=family)
    return (
        total=length(rows),
        complete=count(row -> row.complete, rows),
        incomplete=count(row -> !row.complete, rows),
        missing_records=count(row -> row.issue === :missing_record, rows),
        source_mismatches=count(row -> row.issue === :source_mismatch, rows),
        missing_checks=count(row -> row.issue === :missing_checks, rows),
        by_issue=_count_widget_catalog_by(rows, row -> row.issue),
        by_family=_count_widget_catalog_by(rows, row -> row.family),
    )
end

"""
    widget_coverage_summary_records(; status=:stable, surface=:stable, family=nothing)

Return stable widget coverage summary counts as named tuples with `metric`,
`key`, and `count` fields.
"""
function widget_coverage_summary_records(; status=:stable, surface=:stable, family=nothing)
    summary = widget_coverage_summary(; status=status, surface=surface, family=family)
    rows = [
        (metric="total", key="all", count=summary.total),
        (metric="complete", key="all", count=summary.complete),
        (metric="incomplete", key="all", count=summary.incomplete),
        (metric="missing_records", key="all", count=summary.missing_records),
        (metric="source_mismatches", key="all", count=summary.source_mismatches),
        (metric="missing_checks", key="all", count=summary.missing_checks),
    ]
    append!(rows, [(metric="issue", key=String(key), count=value) for (key, value) in summary.by_issue])
    append!(rows, [(metric="family", key=key, count=value) for (key, value) in summary.by_family])
    return sort!(rows; by=row -> (row.metric, row.key))
end

"""
    widget_coverage_summary_markdown(; status=:stable, surface=:stable, family=nothing)

Render stable widget coverage summary counts as a GitHub-flavored Markdown
table.
"""
function widget_coverage_summary_markdown(; status=:stable, surface=:stable, family=nothing)
    rows = String["| `metric` | `key` | `count` |", "| --- | --- | --- |"]
    append!(
        rows,
        "| $(_escape_widget_catalog_markdown(row.metric)) | $(_escape_widget_catalog_markdown(row.key)) | $(row.count) |"
        for row in widget_coverage_summary_records(; status=status, surface=surface, family=family)
    )
    return join(rows, "\n")
end

"""
    widget_coverage_summary_tsv(; status=:stable, surface=:stable, family=nothing, header=true)

Render stable widget coverage summary counts as tab-separated values.
"""
function widget_coverage_summary_tsv(; status=:stable, surface=:stable, family=nothing, header::Bool=true)
    rows = header ? String["metric\tkey\tcount"] : String[]
    append!(
        rows,
        "$(_escape_widget_catalog_tsv(row.metric))\t$(_escape_widget_catalog_tsv(row.key))\t$(row.count)"
        for row in widget_coverage_summary_records(; status=status, surface=surface, family=family)
    )
    return join(rows, "\n")
end

_widget_coverage_json_string(value::AbstractString) =
    "\"" * replace(value, "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t") * "\""

_widget_coverage_json_string(value) =
    _widget_coverage_json_string(string(value))

function _widget_coverage_git_metadata(root::AbstractString)
    try
        commit = readchomp(pipeline(`git -C $root rev-parse HEAD`; stderr=devnull))
        isempty(commit) && return (commit=nothing, dirty=nothing)
        status = readchomp(pipeline(`git -C $root status --porcelain --untracked-files=all`; stderr=devnull))
        return (commit=commit, dirty=!isempty(status))
    catch
        return (commit=nothing, dirty=nothing)
    end
end

"""
    widget_coverage_git_metadata(; root=normpath(joinpath(@__DIR__, "..")))

Return git provenance metadata for stable widget coverage evidence as a named
tuple with `commit` and `dirty` fields. Values are `nothing` when git metadata
is unavailable.
"""
widget_coverage_git_metadata(; root::AbstractString=normpath(joinpath(@__DIR__, ".."))) =
    _widget_coverage_git_metadata(root)

"""
    assert_widget_coverage_clean_git(; root=normpath(joinpath(@__DIR__, "..")))

Return `true` when stable widget coverage evidence can be tied to a clean git
checkout, or throw an `ArgumentError` when git metadata is unavailable or dirty.
"""
function assert_widget_coverage_clean_git(; root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    git = widget_coverage_git_metadata(; root=root)
    git.commit === nothing && throw(ArgumentError("git metadata is unavailable for stable widget coverage evidence"))
    git.dirty && throw(ArgumentError("git worktree is dirty for stable widget coverage evidence"))
    return true
end

"""
    widget_coverage_release_ready(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Return `true` when stable widget coverage evidence is complete and git
provenance is available from a clean checkout.
"""
function widget_coverage_release_ready(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    widget_coverage_complete(; status=status, surface=surface, family=family) || return false
    try
        assert_widget_coverage_clean_git(; root=root)
    catch error
        error isa ArgumentError && return false
        rethrow()
    end
    return true
end

"""
    assert_widget_coverage_release_ready(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Return `true` when stable widget coverage evidence is complete and clean-git
backed, or throw an `ArgumentError` describing the first failed release gate.
"""
function assert_widget_coverage_release_ready(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    assert_widget_coverage_complete(; status=status, surface=surface, family=family)
    assert_widget_coverage_clean_git(; root=root)
    return true
end

"""
    widget_coverage_release_status_record(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Return a structured release-readiness record for stable widget coverage
evidence.
"""
function widget_coverage_release_status_record(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    coverage_complete = widget_coverage_complete(; status=status, surface=surface, family=family)
    git = widget_coverage_git_metadata(; root=root)
    git_available = git.commit !== nothing
    git_dirty = git.dirty === nothing ? true : git.dirty
    release_ready = coverage_complete && git_available && !git_dirty
    return (
        release_ready=release_ready,
        coverage_complete=coverage_complete,
        git_available=git_available,
        git_dirty=git_dirty,
        git_commit=git.commit,
    )
end

"""
    widget_coverage_release_status_text(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Render one compact release-readiness line for stable widget coverage evidence.
"""
function widget_coverage_release_status_text(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    record = widget_coverage_release_status_record(; status=status, surface=surface, family=family, root=root)
    return join((
        "release_ready=$(record.release_ready)",
        "coverage_complete=$(record.coverage_complete)",
        "git_available=$(record.git_available)",
        "git_dirty=$(record.git_dirty)",
    ), " ")
end

"""
    widget_coverage_release_status_json(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Render the stable widget coverage release-readiness record as a compact JSON
object for dashboards and release automation.
"""
function widget_coverage_release_status_json(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    record = widget_coverage_release_status_record(; status=status, surface=surface, family=family, root=root)
    commit = record.git_commit === nothing ? "null" : _widget_coverage_json_string(record.git_commit)
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"release_ready\": $(record.release_ready),",
        "  \"coverage_complete\": $(record.coverage_complete),",
        "  \"git_available\": $(record.git_available),",
        "  \"git_dirty\": $(record.git_dirty),",
        "  \"git_commit\": $(commit)",
        "}",
    ), "\n")
end

"""
    widget_surface_release_status_record(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Return a combined release-readiness record for the stable widget surface. The
record combines behavior coverage release status, widget stability readiness,
and family closeout readiness.
"""
function widget_surface_release_status_record(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    coverage = widget_coverage_release_status_record(; status=status, surface=surface, family=family, root=root)
    stability_complete = widget_stability_complete(; status=status, surface=surface, family=family)
    stability_blocked = length(widget_stability_gaps(; status=status, surface=surface, family=family))
    family_complete = widget_family_closeout_complete(; family=family)
    family_blocked = length(widget_family_closeout_gaps(; family=family))
    release_ready = coverage.release_ready && stability_complete && family_complete
    return (
        release_ready=release_ready,
        coverage_release_ready=coverage.release_ready,
        coverage_complete=coverage.coverage_complete,
        git_available=coverage.git_available,
        git_dirty=coverage.git_dirty,
        git_commit=coverage.git_commit,
        stability_complete=stability_complete,
        stability_blocked=stability_blocked,
        family_closeout_complete=family_complete,
        family_closeout_blocked=family_blocked,
    )
end

"""
    widget_surface_release_ready(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Return `true` when coverage, widget stability, and family closeout gates are all
release-ready for the matching widget surface.
"""
widget_surface_release_ready(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, ".."))) =
    widget_surface_release_status_record(; status=status, surface=surface, family=family, root=root).release_ready

"""
    assert_widget_surface_release_ready(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Return `true` when the stable widget surface is release-ready, or throw an
`ArgumentError` with the failed gate summary.
"""
function assert_widget_surface_release_ready(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    record = widget_surface_release_status_record(; status=status, surface=surface, family=family, root=root)
    record.release_ready && return true
    blockers = String[]
    record.coverage_release_ready || push!(blockers, "coverage release gate is not ready")
    record.stability_complete || push!(blockers, "widget stability has $(record.stability_blocked) blocked report(s)")
    record.family_closeout_complete || push!(blockers, "family closeout has $(record.family_closeout_blocked) blocked family/families")
    throw(ArgumentError("widget surface release is not ready: $(join(blockers, "; "))"))
end

"""
    widget_surface_release_status_text(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Render one compact release-readiness line for the stable widget surface.
"""
function widget_surface_release_status_text(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    record = widget_surface_release_status_record(; status=status, surface=surface, family=family, root=root)
    return join((
        "release_ready=$(record.release_ready)",
        "coverage_release_ready=$(record.coverage_release_ready)",
        "stability_complete=$(record.stability_complete)",
        "family_closeout_complete=$(record.family_closeout_complete)",
        "git_available=$(record.git_available)",
        "git_dirty=$(record.git_dirty)",
    ), " ")
end

"""
    widget_surface_release_status_json(; status=:stable, surface=:stable, family=nothing, root=normpath(joinpath(@__DIR__, "..")))

Render the combined stable widget surface release-readiness record as compact
JSON for dashboards and release automation.
"""
function widget_surface_release_status_json(; status=:stable, surface=:stable, family=nothing, root::AbstractString=normpath(joinpath(@__DIR__, "..")))
    record = widget_surface_release_status_record(; status=status, surface=surface, family=family, root=root)
    commit = record.git_commit === nothing ? "null" : _widget_coverage_json_string(record.git_commit)
    return join((
        "{",
        "  \"schema_version\": 1,",
        "  \"release_ready\": $(record.release_ready),",
        "  \"coverage_release_ready\": $(record.coverage_release_ready),",
        "  \"coverage_complete\": $(record.coverage_complete),",
        "  \"git_available\": $(record.git_available),",
        "  \"git_dirty\": $(record.git_dirty),",
        "  \"git_commit\": $(commit),",
        "  \"stability_complete\": $(record.stability_complete),",
        "  \"stability_blocked\": $(record.stability_blocked),",
        "  \"family_closeout_complete\": $(record.family_closeout_complete),",
        "  \"family_closeout_blocked\": $(record.family_closeout_blocked)",
        "}",
    ), "\n")
end

"""
    widget_coverage_summary_json(; status=:stable, surface=:stable, family=nothing, include_git=true)

Render stable widget coverage summary counts as a versioned JSON artifact for
release dashboards.
"""
function widget_coverage_summary_json(; status=:stable, surface=:stable, family=nothing, include_git::Bool=true)
    summary = widget_coverage_summary(; status=status, surface=surface, family=family)
    rows = widget_coverage_summary_records(; status=status, surface=surface, family=family)
    generated_at = Dates.format(Dates.unix2datetime(time()), dateformat"yyyy-mm-ddTHH:MM:SS") * "Z"
    root = normpath(joinpath(@__DIR__, ".."))
    metadata = String[
        "  \"metadata\": {",
        "    \"generated_at\": $(_widget_coverage_json_string(generated_at)),",
        "    \"root\": $(_widget_coverage_json_string(root))",
    ]
    git = include_git ? widget_coverage_git_metadata(; root=root) : (commit=nothing, dirty=nothing)
    if git.commit !== nothing
        metadata[end] *= ","
        push!(metadata, "    \"git_commit\": $(_widget_coverage_json_string(git.commit)),")
        push!(metadata, "    \"git_dirty\": $(git.dirty)")
    end
    push!(metadata, "  },")
    output = String[
        "{",
        "  \"schema_version\": 1,",
        metadata...,
        "  \"complete\": $(summary.incomplete == 0),",
        "  \"summary\": {",
        "    \"total\": $(summary.total),",
        "    \"complete\": $(summary.complete),",
        "    \"incomplete\": $(summary.incomplete),",
        "    \"missing_records\": $(summary.missing_records),",
        "    \"source_mismatches\": $(summary.source_mismatches),",
        "    \"missing_checks\": $(summary.missing_checks)",
        "  },",
        "  \"rows\": [",
    ]
    for (index, row) in enumerate(rows)
        suffix = index == length(rows) ? "" : ","
        push!(output, "    {\"metric\": $(_widget_coverage_json_string(row.metric)), \"key\": $(_widget_coverage_json_string(row.key)), \"count\": $(row.count)}$suffix")
    end
    push!(output, "  ]")
    push!(output, "}")
    return join(output, "\n")
end

"""
    widget_coverage_summary_text(; status=:stable, surface=:stable, family=nothing)

Render stable widget coverage summary counts as one compact text line for CI
logs and release dashboards.
"""
function widget_coverage_summary_text(; status=:stable, surface=:stable, family=nothing)
    summary = widget_coverage_summary(; status=status, surface=surface, family=family)
    return join((
        "total=$(summary.total)",
        "complete=$(summary.complete)",
        "incomplete=$(summary.incomplete)",
        "missing_records=$(summary.missing_records)",
        "source_mismatches=$(summary.source_mismatches)",
        "missing_checks=$(summary.missing_checks)",
    ), " ")
end

function _widget_coverage_markdown(rows, selected)
    header = join(("`$(String(column))`" for column in selected), " | ")
    separator = join(fill("---", length(selected)), " | ")
    output = String["| $header |", "| $separator |"]
    for row in rows
        push!(output, "| $(join((_escape_widget_catalog_markdown(_widget_coverage_field(row, column)) for column in selected), " | ")) |")
    end
    return join(output, "\n")
end

function _widget_coverage_tsv(rows, selected; header::Bool=true)
    output = header ? String[join((String(column) for column in selected), "\t")] : String[]
    for row in rows
        push!(output, join((_escape_widget_catalog_tsv(_widget_coverage_field(row, column)) for column in selected), "\t"))
    end
    return join(output, "\n")
end

"""
    widget_coverage_records_markdown(; status=:stable, surface=:stable, family=nothing, columns=(:name, :family, :issue, :missing_checks))

Render stable widget coverage records as a GitHub-flavored Markdown table.
"""
function widget_coverage_records_markdown(;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :family, :issue, :missing_checks),
)
    selected = _widget_coverage_columns(columns)
    return _widget_coverage_markdown(widget_coverage_records(; status=status, surface=surface, family=family), selected)
end

"""
    widget_coverage_gaps_markdown(; status=:stable, surface=:stable, family=nothing, columns=(:name, :family, :issue, :missing_checks))

Render incomplete stable widget coverage rows as a GitHub-flavored Markdown table.
"""
function widget_coverage_gaps_markdown(;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :family, :issue, :missing_checks),
)
    selected = _widget_coverage_columns(columns)
    return _widget_coverage_markdown(widget_coverage_gaps(; status=status, surface=surface, family=family), selected)
end

"""
    widget_coverage_records_tsv(; status=:stable, surface=:stable, family=nothing, columns=(:name, :family, :issue, :missing_checks), header=true)

Render stable widget coverage records as tab-separated values.
"""
function widget_coverage_records_tsv(;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :family, :issue, :missing_checks),
    header::Bool=true,
)
    selected = _widget_coverage_columns(columns)
    return _widget_coverage_tsv(widget_coverage_records(; status=status, surface=surface, family=family), selected; header=header)
end

"""
    widget_coverage_gaps_tsv(; status=:stable, surface=:stable, family=nothing, columns=(:name, :family, :issue, :missing_checks), header=true)

Render incomplete stable widget coverage rows as tab-separated values.
"""
function widget_coverage_gaps_tsv(;
    status=:stable,
    surface=:stable,
    family=nothing,
    columns=(:name, :family, :issue, :missing_checks),
    header::Bool=true,
)
    selected = _widget_coverage_columns(columns)
    return _widget_coverage_tsv(widget_coverage_gaps(; status=status, surface=surface, family=family), selected; header=header)
end

"""
    widget_catalog_entry(name; catalog=stable_widget_catalog())

Return the catalog entry for `name`, or `nothing` when the widget is not present
in the supplied catalog. `name` may be a symbol, string, Wicked widget type, or
Wicked widget instance.
"""
function widget_catalog_entry(name; catalog=stable_widget_catalog())
    target = _widget_catalog_name(name)
    for entry in catalog
        entry.name == target && return entry
    end
    return nothing
end

"""
    is_stable_widget(name; catalog=stable_widget_catalog(status=:stable, surface=:stable))

Return `true` when `name` is present in the reviewed stable widget catalog.
`name` may be a symbol, string, Wicked widget type, or Wicked widget instance.
"""
is_stable_widget(name; catalog=stable_widget_catalog(status=:stable, surface=:stable)) =
    widget_catalog_entry(name; catalog=catalog) !== nothing

"""
    assert_stable_widget(name; catalog=stable_widget_catalog(status=:stable, surface=:stable))

Return the reviewed stable catalog entry for `name`, or throw an `ArgumentError`
when the widget is not part of the stable application-facing surface. `name` may
be a symbol, string, Wicked widget type, or Wicked widget instance.
"""
function assert_stable_widget(name; catalog=stable_widget_catalog(status=:stable, surface=:stable))
    entry = widget_catalog_entry(name; catalog=catalog)
    entry !== nothing && return entry
    throw(ArgumentError("widget is not part of the reviewed stable Wicked.API surface: $(_widget_catalog_name(name))"))
end
