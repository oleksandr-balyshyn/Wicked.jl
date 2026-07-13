#!/usr/bin/env julia

module StablePromotionPacketScaffold

const ROOT = normpath(joinpath(@__DIR__, ".."))
const TEMPLATE = joinpath(ROOT, "docs", "STABLE_PROMOTION_PACKET_TEMPLATE.md")
const DRAFT_DIR = joinpath(ROOT, "scratch", "stable-promotion-packets")
const VALID_DECISIONS = Set(("promote", "qualify", "remove"))

function usage(io::IO=stdout)
    println(io, """
    usage: julia --project=. scripts/new_stable_promotion_packet.jl \\
      --family <family> --widget <widget> --source <source-file> \\
      --candidate <candidate-sha> --decision <promote|qualify|remove> \\
      [--reviewer <name>] [--out-dir <directory>]

    Creates a draft stable widget promotion packet from
    docs/STABLE_PROMOTION_PACKET_TEMPLATE.md. The output is written to
    scratch/stable-promotion-packets/ by default. The generated packet is a
    review scaffold; promotion is not complete until every TODO cites checked-in
    evidence and the stabilization gates pass.
    """)
end

function parse_args(args)
    parsed = Dict{String,String}()
    index = 1
    while index <= length(args)
        key = args[index]
        key in ("--help", "-h") && return nothing
        startswith(key, "--") || error("unexpected argument: $key")
        index == length(args) && error("missing value for $key")
        parsed[key[3:end]] = args[index + 1]
        index += 2
    end
    return parsed
end

function required(parsed, key)
    value = get(parsed, key, "")
    isempty(strip(value)) && error("missing required --$key")
    return strip(value)
end

function slug(value)
    lowered = lowercase(strip(value))
    replaced = replace(lowered, r"[^a-z0-9]+" => "-")
    return replace(replaced, r"^-+|-+$" => "")
end

function validate_candidate(value)
    stripped = strip(value)
    occursin(r"^[0-9a-fA-F]{7,40}$", stripped) ||
        error("--candidate must be a short or full git commit SHA")
    return stripped
end

function validate_decision(value)
    stripped = lowercase(strip(value))
    stripped in VALID_DECISIONS || error("--decision must be one of: promote, qualify, remove")
    return stripped
end

function replace_table_value(source, field, value)
    return replace(source, "| $field | TODO |" => "| $field | $value |")
end

function replace_list_value(source, field, value)
    return replace(source, "- $field: TODO" => "- $field: $value")
end

function packet_filename(family, widget, candidate)
    family_slug = slug(family)
    widget_slug = slug(widget)
    isempty(family_slug) && error("--family must contain at least one alphanumeric character")
    isempty(widget_slug) && error("--widget must contain at least one alphanumeric character")
    return "$family_slug-$widget_slug-$(lowercase(candidate)).md"
end

function evidence_slug(family, widget, candidate)
    family_slug = slug(family)
    widget_slug = slug(widget)
    isempty(family_slug) && error("--family must contain at least one alphanumeric character")
    isempty(widget_slug) && error("--widget must contain at least one alphanumeric character")
    return "$family_slug-$widget_slug-$(lowercase(candidate))"
end

function create_packet(parsed; template::AbstractString=TEMPLATE, draft_dir::AbstractString=DRAFT_DIR)
    isfile(template) || error("missing stable promotion packet template: $(relpath(template, ROOT))")
    family = required(parsed, "family")
    widget = required(parsed, "widget")
    source_file = required(parsed, "source")
    candidate = validate_candidate(required(parsed, "candidate"))
    decision = validate_decision(required(parsed, "decision"))
    reviewer = strip(get(parsed, "reviewer", "TODO"))
    out_dir = strip(get(parsed, "out-dir", draft_dir))
    isempty(out_dir) && (out_dir = draft_dir)

    content = read(template, String)
    content = replace_table_value(content, "Widget family", family)
    content = replace_table_value(content, "Widget name", widget)
    content = replace_table_value(content, "Source file", source_file)
    content = replace_table_value(content, "Release-candidate commit", candidate)
    content = replace_table_value(content, "Reviewer", reviewer)
    content = replace_table_value(content, "Decision", decision)
    content = replace_list_value(content, "Stable exported name", "Wicked.API.$widget")
    content = replace_list_value(content, "Compatibility alias, deprecation, or removal decision", decision)
    artifact_slug = evidence_slug(family, widget, candidate)
    content = replace(
        content,
        "| Pilot evidence package checked by `scripts/pilot_evidence_package_audit.jl` | TODO |" =>
            "| Pilot evidence package checked by `scripts/pilot_evidence_package_audit.jl` | docs/pilot-evidence/$artifact_slug via write_pilot_evidence_package |",
    )
    content = replace(
        content,
        "| Package-level pilot evidence reports, if release-facing | TODO |" =>
            "| Package-level pilot evidence reports, if release-facing | ci-artifacts/pilot-evidence-package-reports/$artifact_slug via write_pilot_evidence_package_reports |",
    )

    path = normpath(joinpath(out_dir, packet_filename(family, widget, candidate)))
    mkpath(dirname(path))
    write(path, content)
    return path
end

function main(args=ARGS)
    if args == ["--help"] || args == ["-h"]
        usage()
        return 0
    end
    parsed = parse_args(args)
    parsed === nothing && (usage(); return 0)
    try
        path = create_packet(parsed)
        println("stable promotion packet: wrote $(relpath(path, ROOT))")
        return 0
    catch error
        println(stderr, "stable promotion packet: $(sprint(showerror, error))")
        return 1
    end
end

end # module StablePromotionPacketScaffold

if abspath(PROGRAM_FILE) == @__FILE__
    exit(StablePromotionPacketScaffold.main())
end
