@testset "Styles and themes" begin
    @testset "color parsing" begin
        @test parse_color("default") == DefaultColor()
        @test parse_color("bright-red") == AnsiColor(9)
        @test parse_color("indexed(123)") == IndexedColor(123)
        @test parse_color("#0102ff") == RGBColor(1, 2, 255)
        @test parse_color("rgb(3, 4, 5)") == RGBColor(3, 4, 5)
        @test_throws ArgumentError parse_color("indexed(999)")
        @test_throws ArgumentError parse_color("#xyzxyz")
        @test_throws ArgumentError parse_color("unknown")
    end

    @testset "selectors and cascade" begin
        context = StyleContext(
            Button,
            :save,
            Set([:primary]),
            Set([:focused]),
            Set([:dialog]),
        )
        instance_context = StyleContext(
            Button("Save"),
            :save,
            Set([:primary]),
            Set([:focused]),
            Set([:dialog]),
        )
        selector = Selector(
            widget_type=:Button,
            id=:save,
            classes=[:primary],
            states=[:focused],
            ancestor_classes=[:dialog],
        )

        @test matches(selector, context)
        @test matches(selector, instance_context)
        @test !matches(Selector(classes=[:secondary]), context)
        @test specificity(selector) == (1, 3, 1)

        theme = Theme(:test; roles=Dict(:primary => Style(foreground=AnsiColor(4))))
        stylesheet = Stylesheet()
        add_rule!(
            stylesheet,
            Selector(widget_type=:Button, classes=[:primary]),
            StylePatch(background=AnsiColor(7), add_modifiers=BOLD),
        )
        add_rule!(
            stylesheet,
            Selector(id=:save),
            StylePatch(foreground=AnsiColor(2)),
        )
        engine = StyleEngine(theme=theme, stylesheets=[stylesheet])
        resolved = computed_style(
            engine,
            context;
            role=:primary,
            inline=StylePatch(add_modifiers=UNDERLINE),
        )

        @test resolved.foreground == AnsiColor(2)
        @test resolved.background == AnsiColor(7)
        @test BOLD in resolved.modifiers
        @test UNDERLINE in resolved.modifiers

        buffer = Buffer(1, 2; cell=Cell("x"))
        apply_style!(buffer, buffer.area, engine, context; role=:primary)
        @test buffer[1, 1].style.foreground == AnsiColor(2)
        @test buffer[1, 2].style.background == AnsiColor(7)
    end

    @testset "stylesheet parser and diagnostics" begin
        stylesheet = parse_stylesheet(
            """
            /* dialog button */
            .dialog Button.primary:focused, #save {
                color: bright-green;
                background: #010203;
                underline-color: indexed(9);
                modifiers: bold underline;
                hyperlink: https://example.test;
            }
            """;
            source="theme.wkd",
        )
        @test length(stylesheet.rules) == 2
        @test stylesheet.rules[1].selector.ancestor_classes == Set([:dialog])
        @test stylesheet.rules[1].patch.foreground == AnsiColor(10)
        @test stylesheet.rules[1].patch.background == RGBColor(1, 2, 3)
        @test stylesheet.rules[1].patch.hyperlink == "https://example.test"

        _, diagnostics = try_parse_stylesheet(
            "Button { unsupported: value; } trailing";
            source="broken.wkd",
        )
        @test !isempty(diagnostics)
        @test all(diagnostic -> diagnostic.source == "broken.wkd", diagnostics)
        @test_throws StylesheetParseError parse_stylesheet(
            "Button { color: nope; }";
            source="invalid.wkd",
        )

        path, io = mktemp()
        try
            write(io, "Button { color: red; }")
            close(io)
            @test length(load_stylesheet(path).rules) == 1
        finally
            isopen(io) && close(io)
            rm(path; force=true)
        end
    end

    @testset "theme registry lifecycle" begin
        light = ThemeDescriptor(
            :light,
            Theme(:light; roles=Dict(:text => Style(foreground=AnsiColor(0))));
            variant=LightTheme,
            priority=5,
        )
        dark = ThemeDescriptor(
            :dark,
            Theme(:dark; roles=Dict(:text => Style(foreground=AnsiColor(15))));
            variant=DarkTheme,
            priority=10,
        )
        registry = ThemeRegistry([light, dark]; active=:light, preference=LightTheme)
        events = ThemeChangeEvent[]
        subscription = subscribe_theme!(registry, event -> push!(events, event))

        @test active_theme(registry).name == :light
        @test set_active_theme!(registry, :dark)
        @test last(events).reason == ThemeSelected
        @test active_theme_descriptor(registry).id == :dark
        @test !set_active_theme!(registry, :dark)

        replacement = ThemeDescriptor(
            :dark,
            Theme(:dark_replaced; roles=Dict(:text => Style(foreground=AnsiColor(6))));
            variant=DarkTheme,
        )
        register_theme!(registry, replacement; replace=true)
        @test last(events).reason == ActiveThemeReplaced
        @test active_theme(registry).name == :dark_replaced

        @test set_theme_preference!(registry, LightTheme)
        @test active_theme_descriptor(registry).id == :light
        @test unregister_theme!(registry, :light)
        @test active_theme_descriptor(registry).id == :dark
        @test last(events).reason == ActiveThemeRemoved
        @test unsubscribe_theme!(registry, subscription)
        @test !unsubscribe_theme!(registry, subscription)
        @test_throws ArgumentError unregister_theme!(registry, :dark)
    end

    @testset "binding and callback isolation" begin
        first_theme = ThemeDescriptor(:one, Theme(:one; roles=Dict(:text => Style())))
        second_theme = ThemeDescriptor(:two, Theme(:two; roles=Dict(:text => Style())))
        registry = ThemeRegistry([first_theme, second_theme]; active=:one)
        engine = StyleEngine()
        binding = bind_theme_engine!(registry, engine)

        @test engine.theme.name == :one
        @test set_active_theme!(registry, :two)
        @test engine.theme.name == :two
        @test unbind_theme_engine!(binding)
        @test !unbind_theme_engine!(binding)

        subscribe_theme!(registry, _ -> error("subscriber failed"))
        @test set_active_theme!(registry, :one)
        @test length(theme_errors(registry)) == 1
        @test length(take_theme_errors!(registry)) == 1
        @test isempty(theme_errors(registry))
        @test_throws ArgumentError subscribe_theme!(registry, () -> nothing)
    end

    @testset "theme derivation" begin
        base = Theme(:base; roles=Dict(
            :text => Style(foreground=AnsiColor(7)),
            :muted => Style(foreground=AnsiColor(8)),
        ))
        derived = derive_theme(
            base,
            :derived;
            roles=Dict(:text => Style(foreground=AnsiColor(2))),
            remove=[:muted],
        )
        @test derived.roles[:text].foreground == AnsiColor(2)
        @test !haskey(derived.roles, :muted)
        @test validate_theme_roles(derived, [:text]) == (true, Symbol[])
        @test validate_theme_roles(derived, [:text, :error]) == (false, [:error])
    end
end
