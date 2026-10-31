include("functions.jl")

function load_year(s::SurveyYear)
    df = read_fixed_width(joinpath(DATA, s.datafile), joinpath(DATA, s.layout),
                          ["PEFAMID", "PWEIGHT", "PWNETWPT"])
    return DataFrame(id = df.PEFAMID, weight = df.PWEIGHT, networth = df.PWNETWPT)
end

function main()
    mkpath(OUTDIR)
    results, summary = results_tables()
    pct = DataFrame(year = Int[], percentile = Int[], networth = Float64[])

    for s in SURVEYS
        println("Computing $(s.year)...")
        fam = load_year(s)
        order = sortperm(fam.networth)
        x, w = fam.networth[order], fam.weight[order]
        est = measures(x, w)

        se = nothing
        if s.bsfile !== nothing
            bw = bootstrap_weights(s, fam.id[order], w)
            se = bootstrap_se(est, [measures(x, bw[:, b]) for b in axes(bw, 2)])
        end

        add_results!(results, summary, s.year, x, w, est, se)
        append!(pct, DataFrame(year = s.year, percentile = PERCENTILES, networth = percentiles(x, w)))
    end

    CSV.write(joinpath(OUTDIR, "sfs_wealth_inequality.csv"), results)
    CSV.write(joinpath(OUTDIR, "sfs_wealth_summary.csv"), summary)
    CSV.write(joinpath(OUTDIR, "sfs_percentiles.csv"), pct)
    print_results(results)
    println("\nWrote output/sfs_wealth_inequality.csv, output/sfs_wealth_summary.csv and output/sfs_percentiles.csv")
end

main()
