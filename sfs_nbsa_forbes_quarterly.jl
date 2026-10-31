include("sfs_nbsa_quarterly.jl")
include("sfs_nbsa_forbes.jl")

# Adds the Forbes list and a Pareto top tail to the quarterly series of sfs_nbsa_quarterly.jl, with
# the procedure of sfs_nbsa_forbes.jl (PBO 2020, Appendices A.2 to A.4), in the six categories of
# the quarterly series. Each survey of a quarter, carried and scaled to the NBSA (quarter_file),
# gets its own tail and calibration, and the integrated files are then pooled with the survey's
# share, as in the quarterly series. Fitting the tail to the pooled file instead would let the
# records of a survey with a small share move the fit, since the regression counts every record
# once whatever its weight. A Forbes family thus appears once for each survey, with weights adding
# up to 1. Each quarter uses the Forbes list and the Pareto threshold of its calendar year, so the
# wealth of the families on the list is held constant across each year. The 2025 list and
# threshold also serve 2026 Q1, since Forbes' 2026 list and the 2026 CPI are not in the data. There
# are no standard errors.

const LAST_LIST_YEAR = 2025
list_year(q) = min(parse(Int, q[1:4]), LAST_LIST_YEAR)

function main()
    mkpath(OUTDIR)
    quarters, nbsa = load_nbsa6()
    population = population_reader()
    fams = Dict(s.year => load_survey(s) for s in SURVEYS)
    lists = Dict(y => load_forbes(y) for y in unique(list_year.(quarters)))

    results = DataFrame(quarter = String[], date = Date[], measure = String[], estimate = Float64[])
    summary = DataFrame(quarter = String[], date = Date[], surveys = String[], forbes_year = Int[], records = Int[],
                        families = Float64[], total_networth_millions = Float64[], mean_networth = Float64[],
                        median_networth = Float64[], share_negative_networth = Float64[])
    pct = DataFrame(quarter = String[], date = Date[], percentile = Int[], networth = Float64[])
    tail = DataFrame(quarter = String[], survey = Int[], survey_share = Float64[], forbes_year = Int[],
                     w_min = Float64[], forbes_entries = Int[],
                     forbes_min = Float64[], forbes_total_billions = Float64[], sfs_records_above_w_min = Int[],
                     alpha = Float64[], synthetic_families = Float64[], iterations = Int[], max_error = Float64[])
    calibration = DataFrame(quarter = String[], survey = Int[], category = String[], nbsa_billions = Float64[],
                            iterative_factor = Float64[], tail_ratio = Float64[])

    for q in quarters
        label, date = quarter_label(q), quarter_date(q) - Day(1)
        pooled, details = quarter_file(q, fams, nbsa, population)
        year = list_year(q)
        richlist, wmin = lists[year], w_min(year)

        parts = DataFrame[]
        for d in details
            part = pooled[pooled.survey .== d.s.year, :]
            w = part.weight ./ d.share
            c, hfd, _ = estimate(part, w, richlist, nbsa[q], wmin, "Forbes"; cats = CATEGORIES6, signs = SIGNS)
            c.err < 1e-3 || @warn "$label, $(d.s.year): calibration stopped $(round(100c.err, sigdigits = 2))% from the NBSA"
            hfd.weight .*= d.share
            push!(parts, hfd)
            push!(tail, (label, d.s.year, d.share, year, wmin, nrow(richlist), minimum(richlist.networth),
                         sum(richlist.networth) / 1e9, c.n_top, c.α, sum(c.tail_w), c.iterations, c.err))

            # The survey is already scaled to the NBSA, so the factors are relative to that scaling
            initial = nbsa[q] ./ [sum(w .* part[!, cat]) for cat in CATEGORIES6]
            overall = c.f .* nbsa[q] ./ c.agg
            for (k, cat) in enumerate(CATEGORIES6)
                push!(calibration, (label, d.s.year, cat, nbsa[q][k] / 1e9, overall[k] / initial[k], c.ratios[k]))
            end
        end
        hfd = sort!(vcat(parts...), :networth)
        est = measures(hfd.networth, hfd.weight)

        for p in TOP_GROUPS
            push!(results, (label, date, group_name(p), est[group_name(p)]))
        end
        push!(results, (label, date, "gini", est["gini"]))

        x, w = hfd.networth, hfd.weight
        append!(pct, DataFrame(quarter = label, date = date, percentile = PERCENTILES, networth = percentiles(x, w)))
        surveys = join(("$(d.s.year) × $(round(d.share, digits = 4))" for d in details), " + ")
        push!(summary, (label, date, surveys, year, count(hfd.source .== "SFS"), sum(w), est["total_networth"] / 1e6,
                        est["total_networth"] / sum(w), weighted_median(x, w), sum(w[x .< 0]) / sum(w)))
    end

    files = ["sfs_nbsa_forbes_quarterly_$(k).csv" => t for (k, t) in ("wealth_inequality" => results,
             "summary" => summary, "tail" => tail, "calibration" => calibration, "percentiles" => pct)]
    for (file, t) in files
        CSV.write(joinpath(OUTDIR, file), t)
    end

    println("\nTop shares (%) and Gini with the Forbes list and Pareto tail, quarterly; * marks survey quarters")
    @printf("%-8s %-28s %13s %7s %7s %7s %7s %6s\n", "quarter", "surveys", "alpha", "top 0.1", "top 1%", "top 10%",
            "top 50%", "gini")
    for r in eachrow(summary)
        m = Dict(x.measure => x.estimate for x in eachrow(results[results.quarter .== r.quarter, :]))
        α = join((@sprintf("%.3f", a) for a in tail.alpha[tail.quarter .== r.quarter]), "/")
        star = r.quarter in quarter_label.(values(NBSA_QUARTER)) ? "*" : ""
        @printf("%-8s %-28s %13s %7.1f %7.1f %7.1f %7.1f %6.3f\n", r.quarter * star, r.surveys, α,
                m["top_0_1pct"], m["top_1pct"], m["top_10pct"], m["top_50pct"], m["gini"])
    end
    println("Largest gap from the NBSA before the final adjustment: ", @sprintf("%.1e", maximum(tail.max_error)))
    println("Wrote ", join(("output/" * file for (file, _) in files), ", "))
end

main()
