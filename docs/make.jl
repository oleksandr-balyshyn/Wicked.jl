using Documenter
using Wicked

DocMeta.setdocmeta!(Wicked, :DocTestSetup, :(using Wicked; using Wicked.API); recursive=true)

makedocs(;
    modules=[Wicked],
    sitename="Wicked.jl",
    authors="Wicked.jl contributors",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://oleksandr-balyshyn.github.io/Wicked.jl",
        edit_link="master",
        sidebar_sitename=false,
        collapselevel=1,
        assets=["assets/custom.css"],
        footer="Built with ⚡ in pure Julia · [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl)",
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
        "Tutorials" => [
            "Hello, World" => "tutorials/hello-world.md",
            "Weather App" => "tutorials/weather-app.md",
        ],
        "Guides" => [
            "Immediate Mode" => "guide/immediate.md",
            "Managed Runtime" => "guide/runtime.md",
            "Declarative Toolkit" => "guide/toolkit.md",
            "Layout" => "guide/layout.md",
            "Styling & Themes" => "guide/styling.md",
            "Widget Catalog" => "guide/widgets.md",
            "Cross-Library Features" => "guide/cross-library.md",
            "Testing" => "guide/testing.md",
        ],
        "API Reference" => "api.md",
    ],
    # The full public surface is large and not every binding is threaded into a
    # @docs block; keep the build resilient and let the guides carry the
    # narrative while the API page documents the headline symbols.
    warnonly=true,
    checkdocs=:none,
    doctest=false,
)

# Deployment is handled by the GitHub Actions Pages pipeline in
# .github/workflows/docs.yml (upload-pages-artifact + deploy-pages), which
# matches the repository's Pages "build from a workflow" setting. `makedocs`
# above emits the complete site into docs/build for that pipeline to publish.
