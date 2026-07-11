@testset "File browser adversarial paths" begin
    mktempdir() do root
        mktempdir() do outside
            write(joinpath(root, "safe.txt"), "safe")
            write(joinpath(root, ".hidden.txt"), "hidden")
            mkdir(joinpath(root, "inside"))
            write(joinpath(root, "inside", "nested.txt"), "nested")
            write(joinpath(outside, "outside.txt"), "outside")
            mkdir(joinpath(outside, "outside-dir"))

            @testset "bounded reads and hidden entries" begin
                limited = read_directory_entries(root; show_hidden=true, maximum_entries=2)
                @test length(limited.entries) == 2
                @test any(diagnostic -> diagnostic.operation == :limit, limited.diagnostics)
                limit_error = only(diagnostic for diagnostic in limited.diagnostics if diagnostic.operation == :limit)
                @test limit_error.error[1] isa DirectoryEntryLimitError

                visible = read_directory_entries(root; show_hidden=false)
                @test all(entry -> !entry.hidden, visible.entries)
                shown = read_directory_entries(root; show_hidden=true)
                @test any(entry -> entry.name == ".hidden.txt", shown.entries)
                @test_throws ArgumentError read_directory_entries(root; maximum_entries=-1)
                @test_throws ArgumentError FileBrowserState(root; maximum_entries=-1)
            end

            @testset "navigation remains confined to canonical root" begin
                state = FileBrowserState(root; root)
                @test_throws ArgumentError navigate_file_browser!(state, outside)
                @test state.current_path == realpath(root)

                inside_link = joinpath(root, "inside-link")
                outside_link = joinpath(root, "outside-link")
                symlink(joinpath(root, "inside"), inside_link)
                symlink(joinpath(outside, "outside-dir"), outside_link)
                refresh_file_browser!(state)
                state.follow_symlinks = true

                state.cursor = findfirst(entry -> entry.name == "outside-link", state.entries)
                @test !enter_file_entry!(state)
                @test state.current_path == realpath(root)
                @test any(diagnostic -> diagnostic.operation == :navigate, state.diagnostics)

                state.cursor = findfirst(entry -> entry.name == "inside-link", state.entries)
                @test enter_file_entry!(state)
                @test state.current_path == realpath(joinpath(root, "inside"))
                @test leave_file_directory!(state)
                @test state.current_path == realpath(root)
            end

            @testset "choices revalidate stale entries" begin
                victim = joinpath(root, "victim.txt")
                write(victim, "before")
                state = FileBrowserState(root; root, mode=SelectFileMode)
                state.cursor = findfirst(entry -> entry.name == "victim.txt", state.entries)
                rm(victim)
                symlink(joinpath(outside, "outside.txt"), victim)

                @test isempty(choose_file_entry!(state))
                @test any(diagnostic -> diagnostic.operation == :choose, state.diagnostics)
                @test isempty(file_choices(state))

                rm(victim)
                write(victim, "restored")
                refresh_file_browser!(state)
                state.cursor = findfirst(entry -> entry.name == "safe.txt", state.entries)
                choices = choose_file_entry!(state)
                @test length(choices) == 1
                @test only(choices).path == realpath(joinpath(root, "safe.txt"))
                @test only(choices).kind == RegularFileEntry

                directory_state = FileBrowserState(root; root, mode=SelectDirectoryMode)
                current = choose_current_directory!(directory_state)
                @test only(current).path == realpath(root)
                @test only(current).kind == DirectoryFileEntry
            end

            @testset "control characters never reach display labels" begin
                hostile_name = "hostile\e[31m\nname.txt"
                write(joinpath(root, hostile_name), "hostile")
                state = FileBrowserState(root; root, show_hidden=true)
                lines = render_file_browser(state; width=120, height=length(state.entries))
                rendered = join((span.text for line in lines for span in line.spans), "")
                @test !occursin('\e', rendered)
                @test !occursin('\n', rendered)
                @test occursin("\\e", rendered)
                @test occursin("\\n", rendered)

                semantics = file_browser_semantic_tree(state; width=120)
                hostile = only(node for node in semantics.root.children if occursin("hostile", node.label))
                @test !occursin('\e', hostile.label)
                @test !occursin('\n', hostile.label)
                @test !occursin(realpath(root), hostile.id)
            end
        end
    end
end
