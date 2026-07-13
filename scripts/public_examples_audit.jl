#!/usr/bin/env julia

module PublicExamplesAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const EXAMPLES_DIR = joinpath(ROOT, "examples")

const INTERNAL_IMPORT_PATTERN = r"^\s*(using|import)\s+Wicked\.(?!API\b)"
const ROOT_IMPORT_PATTERN = r"^\s*(using|import)\s+Wicked\s*$"
const INTERNAL_REFERENCE_PATTERN = r"\bWicked\.(?!API\b)"
const API_IMPORT_PATTERN = r"^\s*(using|import)\s+Wicked\.API\b"
const ASSERTION_PATTERN = r"(?m)^\s*(?:@assert|@test|assert_[A-Za-z0-9_!]*\()"

function example_files(directory::AbstractString=EXAMPLES_DIR)
    isdir(directory) || error("missing examples directory: $directory")
    files = String[]
    for (path, subdirectories, names) in walkdir(directory)
        filter!(name -> name != ".git", subdirectories)
        for name in names
            endswith(name, ".jl") && push!(files, joinpath(path, name))
        end
    end
    return sort!(files)
end

function has_api_import(source::AbstractString)
    return any(eachsplit(source, '\n')) do line
        stripped = strip(line)
        !startswith(stripped, "#") && occursin(API_IMPORT_PATTERN, line)
    end
end

has_assertion(source::AbstractString) = occursin(ASSERTION_PATTERN, source)

function source_failures(path::AbstractString; root::AbstractString=ROOT)
    source = read(path, String)
    relative = relpath(path, root)
    failures = String[]
    has_api_import(source) || push!(failures, "$relative must import Wicked.API as its public application facade")
    has_assertion(source) || push!(failures, "$relative must assert at least one behavior so examples remain executable guidance")
    for (index, line) in enumerate(eachsplit(source, '\n'))
        stripped = strip(line)
        isempty(stripped) && continue
        startswith(stripped, "#") && continue
        if occursin(ROOT_IMPORT_PATTERN, line)
            push!(failures, "$relative:$index imports the root Wicked module; examples must use Wicked.API")
        elseif occursin(INTERNAL_IMPORT_PATTERN, line)
            push!(failures, "$relative:$index imports an internal Wicked subsystem; examples must use Wicked.API")
        elseif occursin(INTERNAL_REFERENCE_PATTERN, line)
            push!(failures, "$relative:$index references an internal Wicked subsystem; examples must use Wicked.API names")
        end
    end
    return failures
end

function audit(root::AbstractString=ROOT)
    directory = joinpath(root, "examples")
    failures = String[]
    for path in example_files(directory)
        append!(failures, source_failures(path; root=root))
    end
    return failures
end

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/public_examples_audit.jl")
    println(io, "")
    println(io, "Checks that runnable examples import Wicked.API and avoid internal or experimental Wicked modules.")
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
        println("public examples audit: all examples use Wicked.API")
        return 0
    end
    for failure in failures
        println(stderr, "public examples audit: $failure")
    end
    return 1
end

end # module PublicExamplesAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(PublicExamplesAudit.main())
end
