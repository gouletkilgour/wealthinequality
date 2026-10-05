include("functions.jl")

# Adds the Forbes rich list and a Pareto top tail to the NBSA-aligned SFS, following
# Appendices A.2 to A.4 of PBO (2020), Estimating the Top Tail of the Family Wealth
# Distribution in Canada. Run with bootstrap standard errors, this takes several minutes.
# sfs_nbsa_forbes_cb.jl runs the same procedure with a different rich list.

const FORBES_DIR = joinpath(@__DIR__, "data", "forbes")

# Pareto threshold: PBO's $3 million for 2016, held constant in 2016 dollars with the annual
# CPI (Table 18-10-0005-01, all-items, 2002 = 100). This reproduces PBO's 2023 threshold of
# $3.67 million.
const CPI = Dict(2012 => 121.7, 2016 => 128.4, 2019 => 136.0, 2023 => 157.1)
w_min(year) = 3e6 * CPI[year] / CPI[2016]

const SYNTHETIC_BRACKETS = 2000   # log-spaced wealth brackets from w_min to the lowest rich-list entry
const TOL = 1e-7                  # PBO: aggregates within 0.00001 per cent of the NBSA
const MAX_ITER = 500
const STALL = 25                  # stop after this many iterations without getting closer to the NBSA

# A rich list as name and net worth in dollars
function load_forbes(year)
    df = CSV.read(joinpath(FORBES_DIR, "forbes_canada_$(year)_cad.csv"), DataFrame)
    return DataFrame(name = df.name, networth = 1e9 .* df.net_worth)
end

# Modified OLS of Vermeulen (2018) on the joint dataset at or above w_min, ranked by wealth:
# ln((i - 0.5) N̄ᵢ / N̄) = c + α (ln w_min - ln wᵢ). Returns α and the total weight above w_min.
function pareto_fit(x, N, wmin)
    o = sortperm(x, rev = true)
    x, N = x[o], N[o]
    n = length(x)
    i = 1:n
    y = log.((i .- 0.5) .* (cumsum(N) ./ i) ./ (sum(N) / n))
    X = log(wmin) .- log.(x)
    Xc, yc = X .- sum(X) / n, y .- sum(y) / n
    return sum(Xc .* yc) / sum(Xc .^ 2), sum(N)
end

# Synthetic families between w_min and the lowest rich-list entry. Each bracket holds its Pareto
# share of the families above w_min, all at the Pareto mean wealth of the bracket.
function synthetic_tail(α, total_weight, wmin, wcb)
    edges = exp.(range(log(wmin), log(wcb), length = SYNTHETIC_BRACKETS + 1))
    a, b = edges[1:end-1], edges[2:end]
    weight = total_weight .* ((wmin ./ a) .^ α .- (wmin ./ b) .^ α)
    wealth = α / (α - 1) .* (a .^ (1 - α) .- b .^ (1 - α)) ./ (a .^ -α .- b .^ -α)
    return wealth, weight
end

# One pass of Appendices A.1 to A.4 for adjustment factors f: align the SFS, fit the tail to the
# SFS families at or above w_min plus the rich list (weight 1), replace those SFS families with synthetic
# families up to the lowest rich-list entry and the rich-list entries above it, and split the tail's
# wealth into categories using the composition of the SFS families it replaces.
function integrate(fam, w, richlist, f, wmin)
    nw = aligned_networth(fam, f)
    top = nw .>= wmin
    below = .!top
    α, total_weight = pareto_fit(vcat(nw[top], richlist), vcat(w[top], ones(length(richlist))), wmin)
    tail_x, tail_w = synthetic_tail(α, total_weight, wmin, minimum(richlist))

    top_nw = sum(w[top] .* nw[top])
    ratios = [f[k] * sum(w[top] .* fam[top, c]) / top_nw for (k, c) in enumerate(CATEGORIES)]
    tail_nw = sum(tail_x .* tail_w) + sum(richlist)
    agg = [f[k] * sum(w[below] .* fam[below, c]) for (k, c) in enumerate(CATEGORIES)] .+ ratios .* tail_nw
    return (; f, below, α, n_top = count(top), tail_x, tail_w, ratios, agg)
end

# Appendix A.4: revise the factors in proportion to the gap between the integrated dataset and
# the NBSA until they match. The full revision can overshoot, because the refitted α moves the
# whole tail, so the step is halved whenever the gap stops shrinking. A single SFS record
# crossing w_min moves the aggregates by a few hundredths of a per cent, which can stop the gap
# shrinking to TOL. The iterate closest to the NBSA is then kept, and the final proportional
# adjustment removes what is left.
function calibrate(fam, w, richlist, nbsa, wmin)
    f = adjustment_factors(fam, w, nbsa)
    best, best_err, iterations = nothing, Inf, 0
    step, prev_err = 1.0, Inf
    for iter in 1:MAX_ITER
        r = integrate(fam, w, richlist, f, wmin)
        err = maximum(abs.(r.agg ./ nbsa .- 1))
        err < best_err && ((best, best_err, iterations) = (r, err, iter))
        (err < TOL || iter - iterations >= STALL) && break
        err >= prev_err && (step /= 2)
        prev_err = err
        f = f .* (nbsa ./ r.agg) .^ step
    end
    return (; best..., err = best_err, iterations)
end

# The calibrated integrated dataset, after PBO's final proportional adjustment of every family.
# source labels the rich-list rows.
function integrated_dataset(fam, w, richlist, c, nbsa, source)
    scale = nbsa ./ c.agg
    fs = c.f .* scale
    tail = c.ratios .* scale
    b = c.below
    parts = [DataFrame(source = "SFS", id = fam.id[b], weight = w[b], financial = fs[1] .* fam.financial[b],
                       nonfinancial = fs[2] .* fam.nonfinancial[b], debts = fs[3] .* fam.debts[b]),
             DataFrame(source = "Pareto", id = "", weight = c.tail_w, financial = tail[1] .* c.tail_x,
                       nonfinancial = tail[2] .* c.tail_x, debts = tail[3] .* c.tail_x),
             DataFrame(source = source, id = richlist.name, weight = 1.0, financial = tail[1] .* richlist.networth,
                       nonfinancial = tail[2] .* richlist.networth, debts = tail[3] .* richlist.networth)]
    df = vcat(parts...)
    df.networth = df.financial .+ df.nonfinancial .- df.debts
    return sort!(df, :networth)
end

function estimate(fam, w, richlist, nbsa, wmin, source)
    c = calibrate(fam, w, richlist.networth, nbsa, wmin)
    hfd = integrated_dataset(fam, w, richlist, c, nbsa, source)
    return c, hfd, measures(hfd.networth, hfd.weight)
end

# load_list(year) returns the rich list for a year, prefix names the output files, and list_name
# labels the rich-list rows and columns ("Forbes" gives forbes_entries, "Rich list" rich_list_entries).
function main(; load_list = load_forbes, prefix = "sfs_nbsa_forbes", list_name = "Forbes")
    key = lowercase(replace(list_name, " " => "_"))
    mkpath(OUTDIR)
    nbsa = load_nbsa()
    results, summary = results_tables()
    integrated = DataFrame()
    tail = DataFrame(:year => Int[], :w_min => Float64[], Symbol(key, "_entries") => Int[],
                     Symbol(key, "_min") => Float64[], Symbol(key, "_total_billions") => Float64[],
                     :sfs_records_above_w_min => Int[], :alpha => Float64[],
                     :synthetic_families => Float64[], :iterations => Int[], :max_error => Float64[],
                     :bootstrap_max_error => Union{Float64,Missing}[])
    calibration = DataFrame(year = Int[], category = String[], nbsa_billions = Float64[],
                            initial_factor = Float64[], iterative_factor = Float64[], overall_factor = Float64[],
                            tail_ratio = Float64[])

    for s in SURVEYS
        println("Computing $(s.year)...")
        fam = load_categories(s)
        richlist = load_list(s.year)
        wmin = w_min(s.year)

        c, hfd, est = estimate(fam, fam.weight, richlist, nbsa[s.year], wmin, list_name)
        c.err < 1e-3 || @warn "$(s.year): calibration stopped $(round(100c.err, sigdigits = 2))% from the NBSA"

        se, boot_err = nothing, missing
        if s.bsfile !== nothing
            bw = bootstrap_weights(s, fam.id, fam.weight)
            reps = map(axes(bw, 2)) do b
                cb, _, estb = estimate(fam, bw[:, b], richlist, nbsa[s.year], wmin, list_name)
                (estb, cb.err)
            end
            se = bootstrap_se(est, first.(reps))
            boot_err = maximum(last.(reps))
        end

        add_results!(results, summary, s.year, hfd.networth, hfd.weight, est, se; survey = hfd.source .== "SFS")
        append!(integrated, hcat(DataFrame(year = fill(s.year, nrow(hfd))), hfd))

        push!(tail, (s.year, wmin, nrow(richlist), minimum(richlist.networth), sum(richlist.networth) / 1e9,
                     c.n_top, c.α, sum(c.tail_w), c.iterations, c.err, boot_err))
        initial = adjustment_factors(fam, fam.weight, nbsa[s.year])
        overall = c.f .* nbsa[s.year] ./ c.agg
        for (k, cat) in enumerate(CATEGORIES)
            push!(calibration, (s.year, cat, nbsa[s.year][k] / 1e9, initial[k], overall[k] / initial[k],
                                overall[k], c.ratios[k]))
        end
    end

    files = ["$(prefix)_$(k).csv" => t for (k, t) in ("integrated" => integrated, "tail" => tail,
             "calibration" => calibration, "wealth_inequality" => results, "wealth_summary" => summary)]
    for (file, t) in files
        CSV.write(joinpath(OUTDIR, file), t)
    end

    println("\nPareto tail")
    @printf("%-6s %8s %7s %10s %12s %7s %11s %6s %10s\n",
            "year", "w_min", "entries", "min (\$M)", "total (\$B)", "SFS≥w", "alpha", "iter", "max error")
    for r in eachrow(tail)
        @printf("%-6d %8.2f %7d %10.0f %12.1f %7d %11.4f %6d %10.1e\n", r.year, r.w_min / 1e6, r[Symbol(key, "_entries")],
                r[Symbol(key, "_min")] / 1e6, r[Symbol(key, "_total_billions")], r.sfs_records_above_w_min, r.alpha,
                r.iterations, r.max_error)
    end
    println("\nAdjustment factors (initial × iterative = overall)")
    for r in eachrow(calibration)
        @printf("%-6d %-13s %6.3f × %6.3f = %6.3f\n", r.year, r.category, r.initial_factor, r.iterative_factor, r.overall_factor)
    end
    print_results(results)
    println("\nRecords in brackets are SFS survey records; the rest of each group is synthetic or rich-list families.")
    println("Wrote ", join(("output/" * file for (file, _) in files), ", "))
end

# Run only as a script, so sfs_nbsa_forbes_cb.jl can include this file
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
