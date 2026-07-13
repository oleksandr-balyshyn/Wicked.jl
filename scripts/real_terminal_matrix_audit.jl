#!/usr/bin/env julia

module RealTerminalMatrixAudit

const ROOT = normpath(joinpath(@__DIR__, ".."))
const MATRIX = joinpath(ROOT, "docs", "REAL_TERMINAL_MATRIX.md")
const TERMINAL_COMPATIBILITY = joinpath(ROOT, "docs", "TERMINAL_COMPATIBILITY.md")
const RELEASE_CHECKLIST = joinpath(ROOT, "docs", "RELEASE_CHECKLIST.md")
const TERMINAL_EVIDENCE_TEMPLATE = joinpath(ROOT, "docs", "TERMINAL_EVIDENCE_TEMPLATE.md")

const REQUIRED_CATEGORIES = (
    "Minimal ANSI / 16 color",
    "256 color",
    "Truecolor",
    "Kitty / WezTerm",
    "Sixel terminal",
    "tmux",
    "GNU screen",
    "SSH",
    "Redirected output",
)
const REQUIRED_IDENTITY_FIELDS = (
    "Wicked commit SHA",
    "Julia version",
    "Linux distribution, kernel, architecture, and shell",
    "Active project and manifest digest",
    "Terminal emulator, version, `TERM`, and `COLORTERM`",
    "Multiplexer and version, or `none`",
    "SSH or remote transport details, or `local`",
    "Command run from the repository root",
    "Exit status",
    "Transcript, screenshot, recording, or CI artifact URI",
)
const REQUIRED_BEHAVIOR_FIELDS = (
    "Startup and shutdown restore terminal modes",
    "Normal exit, thrown error, and interrupt path restore cursor and input modes",
    "Resize redraws without stale cells",
    "Bracketed paste does not corrupt input state",
    "Focus events are parsed or explicitly unavailable",
    "Mouse press, release, wheel, and motion behavior match detected capability",
    "Unicode narrow, wide, combining, emoji, and ambiguous-width text remain aligned",
    "Color fallback does not emit unsupported protocols",
    "Graphics either render through the negotiated protocol or fall back to Unicode",
    "Redirected or non-interactive output does not leak raw-mode control setup",
)
const REQUIRED_COMMANDS = (
    "scripts/pty_gate.jl",
    "examples/widget_gallery.jl",
    "examples/reference_application.jl",
    "examples/progress_notifications.jl",
)

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/real_terminal_matrix_audit.jl")
    println(io, "")
    println(io, "Validates the Linux real-terminal evidence matrix shape.")
end

function matrix_rows(source::AbstractString)
    rows = Dict{String,NamedTuple{(:environment,:observation,:status),Tuple{String,String,String}}}()
    for line in eachsplit(source, '\n')
        stripped = strip(line)
        startswith(stripped, "|") || continue
        occursin("| ---", stripped) && continue
        values = [strip(value) for value in split(stripped, "|") if !isempty(strip(value))]
        length(values) == 4 || continue
        values[1] == "Category" && continue
        rows[values[1]] = (environment=values[2], observation=values[3], status=values[4])
    end
    return rows
end

function audit(;
    matrix_path::AbstractString=MATRIX,
    compatibility_path::AbstractString=TERMINAL_COMPATIBILITY,
    checklist_path::AbstractString=RELEASE_CHECKLIST,
    template_path::AbstractString=TERMINAL_EVIDENCE_TEMPLATE,
)
    failures = String[]
    isfile(matrix_path) || return ["missing Linux real-terminal matrix: docs/REAL_TERMINAL_MATRIX.md"]
    source = read(matrix_path, String)
    compatibility = isfile(compatibility_path) ? read(compatibility_path, String) : ""
    checklist = isfile(checklist_path) ? read(checklist_path, String) : ""
    template = isfile(template_path) ? read(template_path, String) : ""

    occursin("Wicked supports Linux terminals", source) ||
        push!(failures, "real-terminal matrix must declare Linux terminal scope")
    occursin("Do not record non-Linux operating systems", source) ||
        push!(failures, "real-terminal matrix must reject non-Linux operating systems")
    occursin("unsupported operating system", source) &&
        push!(failures, "real-terminal matrix must not list unsupported operating-system labels")

    rows = matrix_rows(source)
    for category in REQUIRED_CATEGORIES
        row = get(rows, category, nothing)
        row === nothing && push!(failures, "real-terminal matrix missing category: $category")
        row === nothing && continue
        isempty(row.environment) && push!(failures, "$category has empty example environment")
        isempty(row.observation) && push!(failures, "$category has empty required observation")
        row.status in ("Not recorded", "Recorded", "Accepted risk") ||
            push!(failures, "$category has invalid evidence status: $(row.status)")
    end
    for category in keys(rows)
        category in REQUIRED_CATEGORIES ||
            push!(failures, "real-terminal matrix has unexpected category: $category")
    end

    for field in REQUIRED_IDENTITY_FIELDS
        occursin(field, source) || push!(failures, "real-terminal matrix missing identity field: $field")
    end
    for field in REQUIRED_BEHAVIOR_FIELDS
        occursin(field, source) || push!(failures, "real-terminal matrix missing behavior field: $field")
    end
    for command in REQUIRED_COMMANDS
        occursin(command, source) || push!(failures, "real-terminal matrix missing recommended command: $command")
    end

    occursin("A row passes only when", source) &&
        occursin("immutable release-candidate commit", source) &&
        occursin("accepted known risk", source) ||
        push!(failures, "real-terminal matrix must define pass criteria and known-risk handling")

    for category in ("Minimal ANSI / 16 color", "256 color", "Truecolor", "Kitty or WezTerm", "Sixel terminal", "tmux", "GNU screen", "SSH", "Redirected output")
        occursin(category, compatibility) ||
            push!(failures, "terminal compatibility doc missing manual matrix category: $category")
    end
    occursin("scripts/pty_gate.jl", compatibility) ||
        push!(failures, "terminal compatibility doc must identify the automated PTY gate")
    occursin("Linux Real-Terminal Matrix", checklist) &&
        occursin("Terminal compatibility", checklist) &&
        occursin("Minimal ANSI and 16-color terminals", checklist) &&
        occursin("SSH session with unknown pixel dimensions", checklist) ||
        push!(failures, "release checklist must require real-terminal matrix evidence")

    isempty(template) && push!(failures, "missing terminal evidence template: docs/TERMINAL_EVIDENCE_TEMPLATE.md")
    for field in ("Matrix category", "Wicked commit SHA", "Linux distribution, kernel, architecture, and shell", "Transcript, screenshot, recording, or CI artifact URI")
        occursin(field, template) || push!(failures, "terminal evidence template missing identity field: $field")
    end
    for field in REQUIRED_BEHAVIOR_FIELDS
        occursin(field, template) || push!(failures, "terminal evidence template missing behavior field: $field")
    end

    return failures
end

function main(arguments=ARGS)
    "--help" in arguments && (print_usage(); return 0)
    failures = audit()
    if isempty(failures)
        println("real-terminal matrix audit: checked $(length(REQUIRED_CATEGORIES)) Linux terminal categories")
        return 0
    end
    foreach(failure -> println(stderr, "real-terminal matrix audit: $failure"), failures)
    return 1
end

end # module RealTerminalMatrixAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(RealTerminalMatrixAudit.main())
end
