@testset "Markdown link adversarial boundaries" begin
    @testset "scheme and path classification" begin
        for uri in (
            "https://example.test/path",
            "http://example.test",
            "mailto:user@example.test",
            "docs/guide.md",
            "../guide.md",
            "#section",
        )
            @test markdown_link_safe(uri)
        end
        for uri in (
            "javascript:alert(1)",
            "data:text/html,hello",
            "file:///etc/passwd",
            "//example.test/path",
            "/etc/passwd",
            "\\\\server\\share",
            "https://example.test/\e]8;;evil",
            "https://example.test/with space",
        )
            @test !markdown_link_safe(uri)
        end

        strict = MarkdownLinkPolicy(allow_relative=false, allow_fragments=false)
        @test !markdown_link_safe("docs/guide.md"; policy=strict)
        @test !markdown_link_safe("#section"; policy=strict)
        custom = MarkdownLinkPolicy(allowed_schemes=("gemini",), allow_relative=false)
        @test markdown_link_safe("gemini://example.test"; policy=custom)
        @test !markdown_link_safe("https://example.test"; policy=custom)
    end

    @testset "safe, unsafe, and malformed metadata" begin
        document = render_markdown(
            "[safe](https://example.test) [unsafe](javascript:alert) [relative](docs/page.md)",
        )
        @test length(document.links) == 3
        @test document.links[1].target.safe
        @test !document.links[2].target.safe
        @test document.links[3].target.safe
        @test document.links[1].target.uri == "https://example.test"

        controlled = render_markdown("[bad](https://example.test/\e[31m)")
        @test isempty(controlled.links)
        @test any(diagnostic -> occursin("invalid character", diagnostic.message), controlled.diagnostics)
        @test all(span -> span.link_id === nothing, Iterators.flatten(line.spans for line in controlled.lines))

        oversized = render_markdown(
            "[large](https://example.test/abcdef)";
            link_policy=MarkdownLinkPolicy(maximum_uri_bytes=10),
        )
        @test isempty(oversized.links)
        @test any(diagnostic -> occursin("too long", diagnostic.message), oversized.diagnostics)
    end

    @testset "link and label budgets omit excess metadata" begin
        source = join(("[link$index](https://example.test/$index)" for index in 1:5), " ")
        limited = render_markdown(source; link_policy=MarkdownLinkPolicy(maximum_links=2))
        @test length(limited.links) == 2
        @test count(diagnostic -> occursin("count", diagnostic.message), limited.diagnostics) == 3
        @test Set(
            span.link_id for line in limited.lines for span in line.spans if span.link_id !== nothing
        ) == Set([1, 2])

        label_limited = render_markdown(
            "[12345](https://example.test)";
            link_policy=MarkdownLinkPolicy(maximum_label_bytes=4),
        )
        @test isempty(label_limited.links)
        @test any(diagnostic -> occursin("label", diagnostic.message), label_limited.diagnostics)

        @test_throws ArgumentError MarkdownLinkPolicy(maximum_links=-1)
        @test_throws ArgumentError MarkdownLinkPolicy(maximum_uri_bytes=-1)
        @test_throws ArgumentError MarkdownLinkPolicy(allowed_schemes=("not a scheme",))
    end

    @testset "nested labels and terminal controls render safely" begin
        nested = render_markdown("[**bold** and _emphasis_](https://example.test)")
        @test only(nested.links).label == "bold and emphasis"
        @test all(span -> span.link_id == 1, Iterators.flatten(line.spans for line in nested.lines))

        hostile_text = render_markdown("plain\e[31m text")
        rendered = plain_text(hostile_text)
        @test !occursin('\e', rendered)
        @test occursin('�', rendered)

        hostile_link = render_markdown("[label\x00](https://example.test)")
        @test !occursin('\0', plain_text(hostile_link))
        @test only(hostile_link.links).label == "label�"
    end

    @testset "unsafe activation remains explicit" begin
        view = MarkdownView("[run](javascript:alert)"; width=40)
        focus_next_link!(view)
        blocked = activate_focused_link(view)
        @test !blocked.allowed
        @test blocked.reason == :unsafe_destination
        allowed = activate_focused_link(view; allow_unsafe=true)
        @test allowed.allowed
        @test allowed.reason == :explicitly_allowed
    end

    @testset "semantic document and link metadata" begin
        view = MarkdownView(
            "[safe](https://example.test) [unsafe](javascript:alert)";
            width=40,
        )
        state = MarkdownState(view; viewport_height=4)
        descriptor = Wicked.SemanticToolkit.widget_semantic_descriptor(view, state)
        children = Wicked.SemanticToolkit.widget_semantic_children(view, state, :document)

        @test descriptor.role == Wicked.Accessibility.GroupRole
        @test descriptor.state.focusable
        @test descriptor.metadata[:link_count] == 2
        @test descriptor.metadata[:unsafe_link_count] == 1
        @test length(children) == 2
        @test all(child -> child.role == Wicked.Accessibility.LinkRole, children)
        @test children[1].state.enabled
        @test !children[2].state.enabled
        @test children[1].metadata[:target] == "https://example.test"
        @test children[2].metadata[:safe] == false

        focus_next_link!(view)
        focused_children = Wicked.SemanticToolkit.widget_semantic_children(view, state, :document)
        @test focused_children[1].state.focused

        state.allow_unsafe_links = true
        permissive_children = Wicked.SemanticToolkit.widget_semantic_children(view, state, :document)
        @test permissive_children[2].state.enabled
    end
end
