#!/usr/bin/env julia

module ExampleFamilyAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EXAMPLES_README = joinpath(ROOT, "examples", "README.md")

const REQUIRED_EXAMPLES = (
    ("Immediate rendering", "immediate_quickstart.jl"),
    ("Layout composition", "layout_quickstart.jl"),
    ("Text and structure", "text_quickstart.jl"),
    ("Scrolling and viewport", "scrolling_quickstart.jl"),
    ("Input events", "input_events_quickstart.jl"),
    ("Data display", "data_display_quickstart.jl"),
    ("Virtual data", "virtualization_quickstart.jl"),
    ("Controls and forms", "controls_quickstart.jl"),
    ("Feedback and validation", "feedback_quickstart.jl"),
    ("Disclosure and overlays", "disclosure_overlay_quickstart.jl"),
    ("Screen stack", "screen_stack_quickstart.jl"),
    ("File browser", "file_browser_quickstart.jl"),
    ("Animations and loading", "animations_loading_quickstart.jl"),
    ("Navigation surfaces", "navigation_quickstart.jl"),
    ("Visualization", "visualization_quickstart.jl"),
    ("Terminal graphics", "graphics_quickstart.jl"),
    ("Rich content", "rich_content_quickstart.jl"),
    ("Toolkit", "toolkit_quickstart.jl"),
    ("Styling and themes", "styling_quickstart.jl"),
    ("Testing and semantics", "testing_quickstart.jl"),
    ("Runtime", "runtime_quickstart.jl"),
    ("Services", "services_quickstart.jl"),
    ("Extensions", "extensions_quickstart.jl"),
    ("Remote transport", "remote_transport_quickstart.jl"),
    ("Live reload", "live_reload.jl"),
    ("Reference application", "reference_application.jl"),
    ("Widget gallery", "widget_gallery.jl"),
)

function read_examples_readme(root::AbstractString)
    path = joinpath(root, "examples", "README.md")
    isfile(path) || error("missing examples index: examples/README.md")
    return read(path, String)
end

function audit(root::AbstractString=ROOT; required=REQUIRED_EXAMPLES)
    readme = read_examples_readme(root)
    failures = String[]
    for (family, file) in required
        path = joinpath(root, "examples", file)
        isfile(path) || push!(failures, "$family example is missing: examples/$file")
        occursin(file, readme) || push!(failures, "$family example is not listed in examples/README.md: $file")
    end
    return failures
end

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/example_family_audit.jl")
    println(io, "")
    println(io, "Checks that every required public quickstart family has an example file and examples/README.md entry.")
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    if !isempty(arguments)
        print_usage(stderr)
        return 2
    end
    failures = audit()
    if isempty(failures)
        println("example family audit: $(length(REQUIRED_EXAMPLES)) required example families documented")
        return 0
    end
    for failure in failures
        println(stderr, "example family audit: $failure")
    end
    return 1
end

end # module ExampleFamilyAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(ExampleFamilyAudit.main())
end
