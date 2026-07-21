@testset "Stylesheet parser and cascade properties" begin
    @testset "specificity is structural" begin
        for has_type in (false, true),
            has_id in (false, true),
            class_count in 0:3,
            state_count in 0:2,
            ancestor_count in 0:2
            selector = Selector(
                widget_type=has_type ? :Button : nothing,
                id=has_id ? :target : nothing,
                classes=[Symbol("class_$index") for index in 1:class_count],
                states=[Symbol("state_$index") for index in 1:state_count],
                ancestor_classes=[Symbol("ancestor_$index") for index in 1:ancestor_count],
            )
            @test specificity(selector) == (
                has_id ? 1 : 0,
                class_count + state_count + ancestor_count,
                has_type ? 1 : 0,
            )
        end
    end

    @testset "matching follows exact ID/type and subset classes" begin
        all_classes = Set([:alpha, :beta, :gamma])
        all_states = Set([:focus, :selected])
        all_ancestors = Set([:dialog, :screen])
        context = StyleContext(Button, :save, all_classes, all_states, all_ancestors)

        for class_mask in 0:7, state_mask in 0:3, ancestor_mask in 0:3
            classes = Symbol[value for (bit, value) in enumerate((:alpha, :beta, :gamma)) if class_mask & (1 << (bit - 1)) != 0]
            states = Symbol[value for (bit, value) in enumerate((:focus, :selected)) if state_mask & (1 << (bit - 1)) != 0]
            ancestors = Symbol[value for (bit, value) in enumerate((:dialog, :screen)) if ancestor_mask & (1 << (bit - 1)) != 0]
            @test matches(Selector(classes=classes, states=states, ancestor_classes=ancestors), context)
        end

        @test !matches(Selector(id=:other), context)
        @test !matches(Selector(widget_type=:Label), context)
        @test !matches(Selector(classes=[:missing]), context)
        @test !matches(Selector(states=[:disabled]), context)
        @test !matches(Selector(ancestor_classes=[:overlay]), context)
    end

    @testset "cascade ordering is deterministic" begin
        context = StyleContext(Button, :save, Set([:primary]), Set([:focus]), Set{Symbol}())

        first_sheet = Stylesheet()
        add_rule!(first_sheet, Selector(classes=[:primary]), StylePatch(foreground=AnsiColor(1)))
        add_rule!(first_sheet, Selector(classes=[:primary]), StylePatch(foreground=AnsiColor(2)))
        @test computed_style(StyleEngine(stylesheets=[first_sheet]), context).foreground == AnsiColor(2)

        later_sheet = Stylesheet()
        add_rule!(later_sheet, Selector(classes=[:primary]), StylePatch(foreground=AnsiColor(3)))
        engine = StyleEngine(stylesheets=[first_sheet, later_sheet])
        @test computed_style(engine, context).foreground == AnsiColor(3)

        specific_first = Stylesheet()
        add_rule!(specific_first, Selector(id=:save), StylePatch(background=AnsiColor(4)))
        general_later = Stylesheet()
        add_rule!(general_later, Selector(classes=[:primary]), StylePatch(background=AnsiColor(5)))
        specific_engine = StyleEngine(stylesheets=[specific_first, general_later])
        @test computed_style(specific_engine, context).background == AnsiColor(4)

        resolved = computed_style(
            engine,
            context;
            inline=StylePatch(foreground=AnsiColor(6)),
        )
        @test resolved.foreground == AnsiColor(6)

        composed = Stylesheet()
        add_rule!(
            composed,
            Selector(classes=[:active]),
            StylePatch(foreground=AnsiColor(1), add_modifiers=BOLD, hyperlink="class-link"),
        )
        add_rule!(
            composed,
            Selector(id=:save),
            StylePatch(background=AnsiColor(4), add_modifiers=ITALIC, remove_modifiers=BOLD, hyperlink=nothing),
        )
        add_rule!(
            composed,
            Selector(id=:save),
            StylePatch(underline_color=AnsiColor(6), add_modifiers=BOLD, remove_modifiers=ITALIC, hyperlink="id-link"),
        )
        composed_style = computed_style(
            StyleEngine(stylesheets=[composed]),
            StyleContext(nothing, :save, Set([:active]), Set{Symbol}(), Set{Symbol}()),
            Style(modifiers=DIM, hyperlink="base-link");
            inline=StylePatch(add_modifiers=UNDERLINE, remove_modifiers=BOLD, hyperlink="inline-link"),
        )
        @test composed_style.foreground == AnsiColor(1)
        @test composed_style.background == AnsiColor(4)
        @test composed_style.underline_color == AnsiColor(6)
        @test composed_style.modifiers == (DIM | UNDERLINE)
        @test composed_style.hyperlink == "inline-link"
    end

    @testset "generated stylesheet selectors round trip" begin
        colors = ("red", "bright-blue", "indexed(42)", "#010203", "rgb(4, 5, 6)")
        for class_count in 0:3, state_count in 0:2, color in colors
            classes = [".c$index" for index in 1:class_count]
            states = [":s$index" for index in 1:state_count]
            selector_text = "Button#target" * join(classes) * join(states)
            sheet = parse_stylesheet("$selector_text { color: $color; }")
            @test length(sheet.rules) == 1
            selector = only(sheet.rules).selector
            @test selector.widget_type == :Button
            @test selector.id == :target
            @test selector.classes == Set(Symbol("c$index") for index in 1:class_count)
            @test selector.states == Set(Symbol("s$index") for index in 1:state_count)
            @test only(sheet.rules).patch.foreground == parse_color(color)
        end
    end

    @testset "invalid groups are atomic and duplicate components are rejected" begin
        stylesheet, diagnostics = try_parse_stylesheet(
            "Button, . { color: red; } Label { color: blue; }",
        )
        @test length(diagnostics) == 1
        @test length(stylesheet.rules) == 1
        @test only(stylesheet.rules).selector.widget_type == :Label

        for selector in (
            "Button#one#two",
            "Button.same.same",
            "Button:focus:focus",
            ".parent.parent Button",
        )
            parsed, errors = try_parse_stylesheet("$selector { color: red; }")
            @test isempty(parsed.rules)
            @test length(errors) == 1
        end

        @test_throws ArgumentError Selector(classes=[:same, :same])
        @test_throws ArgumentError Selector(states=[:focus, :focus])
        @test_throws ArgumentError Selector(ancestor_classes=[:dialog, :dialog])

        located, located_errors = try_parse_stylesheet(
            "Label { color: red; }\n\nButton { color: nope; } trailing";
            source="located.wkd",
        )
        @test length(located.rules) == 1
        @test length(located_errors) == 2
        @test located_errors[1].source == "located.wkd"
        @test (located_errors[1].line, located_errors[1].column) == (3, 1)
        @test located_errors[2].message == "unparsed stylesheet content"

        commented = parse_stylesheet("/* λ\n界 */\nLabel { color: blue; }")
        @test length(commented.rules) == 1

        recovered, recovery_errors = try_parse_stylesheet(
            "} .παράδειγμα, Button.primary:focus { color: indexed(42); hyperlink: https://example.test/a:b; }",
        )
        @test length(recovery_errors) == 1
        @test recovery_errors[1].message == "unparsed stylesheet content"
        @test length(recovered.rules) == 2
        @test :παράδειγμα in recovered.rules[1].selector.classes
        @test recovered.rules[2].selector.states == Set([:focus])
        @test recovered.rules[2].patch.foreground == IndexedColor(42)
        @test recovered.rules[2].patch.hyperlink == "https://example.test/a:b"

        nested, nested_errors = try_parse_stylesheet(
            "Broken { color: red; { } } Label { color: blue; }",
        )
        @test length(nested_errors) == 1
        @test length(nested.rules) == 1
        @test only(nested.rules).selector.widget_type == :Label
    end

    @testset "color domains and modifier removal" begin
        for index in 0:255
            @test parse_color("indexed($index)") == IndexedColor(index)
        end
        for red in (0, 1, 127, 255), green in (0, 64, 255), blue in (0, 128, 255)
            @test parse_color("rgb($red, $green, $blue)") == RGBColor(red, green, blue)
        end

        sheet = parse_stylesheet(
            "Button { add-modifiers: bold underline; remove-modifiers: bold; }",
        )
        style = computed_style(
            StyleEngine(stylesheets=[sheet]),
            StyleContext(Button, nothing, Set{Symbol}(), Set{Symbol}(), Set{Symbol}());
            inline=StylePatch(add_modifiers=ITALIC),
        )
        @test !(BOLD in style.modifiers)
        @test UNDERLINE in style.modifiers
        @test ITALIC in style.modifiers
    end
end
