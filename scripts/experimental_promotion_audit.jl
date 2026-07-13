#!/usr/bin/env julia

module ExperimentalPromotionAudit

using Wicked

const ROOT = normpath(joinpath(@__DIR__, ".."))
const LEDGER = joinpath(ROOT, "api", "experimental_promotions.tsv")
const EXPECTED_HEADER = ["name", "decision", "target", "review_status", "notes"]
const VALID_DECISIONS = Set(["promote", "qualify", "remove"])
const VALID_REVIEW_STATUSES = Set(["proposed", "accepted", "completed"])

function print_usage(io::IO=stdout)
    println(io, "usage: julia --project=. scripts/experimental_promotion_audit.jl [experimental-promotions.tsv]")
    println(io, "")
    println(io, "Checks that every Wicked.Experimental export has a promote, qualify, or remove plan.")
end

function read_rows(path::AbstractString=LEDGER)
    isfile(path) || error("missing experimental promotion ledger: $(relpath(path, ROOT))")
    rows = Dict{String,NamedTuple{(:decision,:target,:review_status,:notes),NTuple{4,String}}}()
    failures = String[]
    for (offset, raw_line) in enumerate(readlines(path))
        line = strip(raw_line)
        isempty(line) && continue
        startswith(line, "#") && continue
        fields = split(raw_line, '\t'; keepempty=true)
        fields == EXPECTED_HEADER && continue
        if length(fields) != length(EXPECTED_HEADER)
            push!(
                failures,
                "$(relpath(path, ROOT)):$offset has $(length(fields)) fields; expected $(length(EXPECTED_HEADER))",
            )
            continue
        end
        name, decision, target, review_status, notes = fields
        isempty(strip(name)) && push!(
            failures,
            "$(relpath(path, ROOT)):$offset has empty experimental binding name",
        )
        decision in VALID_DECISIONS || push!(
            failures,
            "$(relpath(path, ROOT)):$offset has invalid decision `$decision`",
        )
        review_status in VALID_REVIEW_STATUSES || push!(
            failures,
            "$(relpath(path, ROOT)):$offset has invalid review status `$review_status`",
        )
        isempty(strip(target)) && push!(
            failures,
            "$(relpath(path, ROOT)):$offset must name a target API, owning module, or removal milestone",
        )
        isempty(strip(notes)) && push!(
            failures,
            "$(relpath(path, ROOT)):$offset must explain the promotion, qualification, or removal plan",
        )
        if haskey(rows, name)
            push!(
                failures,
                "$(relpath(path, ROOT)):$offset duplicates experimental binding `$name`",
            )
        else
            rows[name] = (
                decision=String(decision),
                target=String(target),
                review_status=String(review_status),
                notes=String(notes),
            )
        end
    end
    return rows, failures
end

function experimental_names()
    return Set(
        string(name)
        for name in Base.names(Wicked.Experimental; all=false, imported=false)
        if name != :Experimental
    )
end

function audit(path::AbstractString=LEDGER)
    rows, failures = read_rows(path)
    exported = experimental_names()
    planned = Set(keys(rows))
    for name in sort!(collect(setdiff(exported, planned)))
        push!(
            failures,
            "Wicked.Experimental binding `$name` is missing a promotion/removal plan in $(relpath(path, ROOT))",
        )
    end
    for name in sort!(collect(setdiff(planned, exported)))
        row = rows[name]
        row.review_status == "completed" || push!(
            failures,
            "$(relpath(path, ROOT)) lists `$name` but Wicked.Experimental does not export it; mark the row completed or remove it",
        )
    end
    return failures, rows, exported
end

function main(arguments=ARGS)
    if arguments == ["--help"] || arguments == ["-h"]
        print_usage()
        return 0
    end
    if length(arguments) > 1
        print_usage(stderr)
        return 2
    end
    path = isempty(arguments) ? LEDGER : first(arguments)
    failures, rows, exported = audit(path)
    if isempty(failures)
        println(
            "experimental promotion audit: $(length(rows)) planned entries, $(length(exported)) experimental bindings requiring plans",
        )
        return 0
    end
    for failure in failures
        println(stderr, "experimental promotion audit: $failure")
    end
    return 1
end

end # module ExperimentalPromotionAudit

if abspath(PROGRAM_FILE) == @__FILE__
    exit(ExperimentalPromotionAudit.main())
end
