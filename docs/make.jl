using Documenter
using Wicked

function wicked_doc_modules(root::Module)
    discovered = Module[root]
    seen = Set(discovered)
    cursor = 1

    while cursor <= length(discovered)
        owner = discovered[cursor]
        cursor += 1

        for name in names(owner; all=true, imported=false)
            isdefined(owner, name) || continue
            value = getfield(owner, name)
            value isa Module || continue
            parentmodule(value) === owner || continue
            value in seen && continue
            push!(seen, value)
            push!(discovered, value)
        end
    end

    return discovered
end

const WICKED_DOC_MODULES = wicked_doc_modules(Wicked)

const PAGES = [
    "Home" => "index.md",
    "Getting started" => [
        "Getting Started" => "GETTING_STARTED.md",
        "Immediate-mode Tutorial" => "IMMEDIATE_MODE_TUTORIAL.md",
        "Toolkit Tutorial" => "TOOLKIT_TUTORIAL.md",
        "Reference Application" => "REFERENCE_APPLICATION.md",
    ],
    "Concepts" => [
        "Architecture" => "ARCHITECTURE.md",
        "API Reference" => [
            "Overview" => "API_REFERENCE.md",
            "Public Facades" => "API_FACADES.md",
            "Core" => "API_CORE.md",
            "Immediate Widgets" => "API_WIDGETS.md",
            "Backends and Runtime" => "API_BACKENDS_RUNTIME.md",
            "Controls" => "API_CONTROLS.md",
            "Navigation and Forms" => "API_NAVIGATION.md",
            "Rich Content" => "API_RICH_CONTENT.md",
            "Graphics" => "API_GRAPHICS.md",
            "Toolkit and Reactive" => "API_TOOLKIT.md",
            "Semantics, Testing, and Diagnostics" => "API_SEMANTICS_TESTING.md",
            "Virtualization" => "API_VIRTUALIZATION.md",
            "Extensions and Services" => "API_EXTENSIONS_SERVICES.md",
        ],
        "API Stability Audit" => "API_STABILITY_AUDIT.md",
        "Candidate Stable API" => "STABLE_API.md",
        "Experimental Compatibility" => "EXPERIMENTAL_API.md",
        "Component Catalog" => "COMPONENT_CATALOG.md",
        "Widget Coverage Audit" => "WIDGET_COVERAGE.md",
        "Framework Migration" => "FRAMEWORK_MIGRATION.md",
        "Developer Guide" => "DEVELOPER_GUIDE.md",
        "Async Runtime" => "ASYNC_RUNTIME.md",
        "Remote Transport" => "REMOTE_TRANSPORT.md",
        "Accessibility and Testing" => "ACCESSIBILITY_TESTING.md",
    ],
    "Application services" => [
        "Application Services" => "APPLICATION_SERVICES.md",
        "Actions" => "ACTIONS.md",
        "Animations" => "ANIMATIONS.md",
        "Themes" => "THEMES.md",
        "Notifications" => "NOTIFICATIONS.md",
        "Progress" => "PROGRESS.md",
        "Utility Widgets" => "UTILITY_WIDGETS.md",
        "Content Containers" => "CONTENT_CONTAINERS.md",
        "Overlays" => "OVERLAYS.md",
        "Overlay Layout" => "OVERLAY_LAYOUT.md",
        "Live Reload" => "LIVE_RELOAD.md",
        "Event Tracing" => "EVENT_TRACING.md",
        "Terminal Recovery" => "TERMINAL_RECOVERY.md",
        "Terminal Compatibility" => "TERMINAL_COMPATIBILITY.md",
        "Linux Real-Terminal Matrix" => "REAL_TERMINAL_MATRIX.md",
        "Terminal Evidence Template" => "TERMINAL_EVIDENCE_TEMPLATE.md",
        "Terminal Evidence Records" => "terminal-evidence/README.md",
        "Real Application Evidence Template" => "REAL_APPLICATION_EVIDENCE_TEMPLATE.md",
        "Real Application Evidence Records" => "application-evidence/README.md",
        "Benchmark Evidence Template" => "BENCHMARK_EVIDENCE_TEMPLATE.md",
        "Benchmark Evidence Records" => "benchmark-evidence/README.md",
        "Package Loading Evidence Template" => "PACKAGE_LOADING_EVIDENCE_TEMPLATE.md",
        "Package Loading Evidence Records" => "loading-evidence/README.md",
        "Documentation Evidence Template" => "DOCUMENTATION_EVIDENCE_TEMPLATE.md",
        "Documentation Evidence Records" => "documentation-evidence/README.md",
        "Semantic Accessibility Evidence Template" => "SEMANTIC_ACCESSIBILITY_EVIDENCE_TEMPLATE.md",
        "Semantic Accessibility Evidence Records" => "semantic-evidence/README.md",
    ],
    "Project" => [
        "Feature Parity" => "FEATURE_PARITY.md",
        "API Stabilization" => "API_STABILIZATION.md",
        "Widget Promotion Guide" => "WIDGET_PROMOTION.md",
        "Reference Parity Survey" => "REFERENCE_PARITY_SURVEY.md",
        "Parity Execution Plan" => "PARITY_EXECUTION_PLAN.md",
        "Public Example Families" => "EXAMPLE_FAMILIES.md",
        "Porting Cookbook" => "PORTING_COOKBOOK.md",
        "Loading and Precompilation" => "PACKAGE_LOADING.md",
        "Performance and Latency" => "PERFORMANCE.md",
        "Unicode Width Corpus" => "UNICODE_WIDTH_CORPUS.md",
        "Validation Strategy" => "VALIDATION_STRATEGY.md",
        "Widget Stabilization" => "WIDGET_STABILIZATION.md",
        "Stable Promotion Packet Template" => "STABLE_PROMOTION_PACKET_TEMPLATE.md",
        "Stable Promotion Packet Records" => "stable-promotion-packets/README.md",
        "Widget Family Evidence" => "WIDGET_FAMILY_EVIDENCE.md",
        "Continuous Integration" => "CONTINUOUS_INTEGRATION.md",
        "Release Evidence" => "RELEASE_EVIDENCE.md",
        "Parity Evidence Template" => "PARITY_EVIDENCE_TEMPLATE.md",
        "Parity Evidence Records" => "evidence/README.md",
        "Parity Evidence Policy" => "evidence/parity_policy.md",
        "Migration" => "MIGRATION.md",
        "Release Checklist" => "RELEASE_CHECKLIST.md",
    ],
]

makedocs(
    sitename = "Wicked.jl",
    source = ".",
    build = "../build/docs",
    modules = WICKED_DOC_MODULES,
    checkdocs = :exports,
    doctest = true,
    pages = PAGES,
    pagesonly = true,
    remotes = nothing,
    format = Documenter.HTML(
        prettyurls = true,
        collapselevel = 1,
        repolink = nothing,
    ),
)
