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
        "Experimental API" => "EXPERIMENTAL_API.md",
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
    ],
    "Project" => [
        "Feature Parity" => "FEATURE_PARITY.md",
        "Reference Parity Survey" => "REFERENCE_PARITY_SURVEY.md",
        "Parity Execution Plan" => "PARITY_EXECUTION_PLAN.md",
        "Loading and Precompilation" => "PACKAGE_LOADING.md",
        "Validation Strategy" => "VALIDATION_STRATEGY.md",
        "Continuous Integration" => "CONTINUOUS_INTEGRATION.md",
        "Release Evidence" => "RELEASE_EVIDENCE.md",
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
