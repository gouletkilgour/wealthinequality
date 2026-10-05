include("functions.jl")

function main()
    mkpath(OUTDIR)
    nbsa = load_nbsa()
    results, summary = results_tables()
    aligned = DataFrame()
    alignment = DataFrame(year = Int[], nbsa_quarter = String[], category = String[],
                          sfs_billions = Float64[], nbsa_billions = Float64[],
                          coverage = Float64[], adjustment_factor = Float64[])

    for s in SURVEYS
        println("Computing $(s.year)...")
        fam = load_categories(s)
        w = fam.weight
        f = adjustment_factors(fam, w, nbsa[s.year])
        nw = aligned_networth(fam, f)

        sfs = sfs_totals(fam, w)
        for (c, sfs_c, nbsa_c, f_c) in zip(CATEGORIES, sfs, nbsa[s.year], f)
            push!(alignment, (s.year, NBSA_QUARTER[s.year], c, sfs_c / 1e9, nbsa_c / 1e9, sfs_c / nbsa_c, f_c))
        end
        sfs_nw, nbsa_nw = sfs[1] + sfs[2] - sfs[3], nbsa[s.year][1] + nbsa[s.year][2] - nbsa[s.year][3]
        push!(alignment, (s.year, NBSA_QUARTER[s.year], "networth", sfs_nw / 1e9, nbsa_nw / 1e9, sfs_nw / nbsa_nw, nbsa_nw / sfs_nw))

        append!(aligned, DataFrame(year = s.year, id = fam.id, weight = w,
                                   financial = fam.financial, nonfinancial = fam.nonfinancial, debts = fam.debts,
                                   networth = fam.financial .+ fam.nonfinancial .- fam.debts,
                                   financial_aligned = f[1] .* fam.financial,
                                   nonfinancial_aligned = f[2] .* fam.nonfinancial,
                                   debts_aligned = f[3] .* fam.debts,
                                   networth_aligned = nw))

        order = sortperm(nw)
        x, ws = nw[order], w[order]
        est = measures(x, ws)

        se = nothing
        if s.bsfile !== nothing
            bw = bootstrap_weights(s, fam.id, w)
            reps = map(axes(bw, 2)) do b
                wb = bw[:, b]
                nwb = aligned_networth(fam, adjustment_factors(fam, wb, nbsa[s.year]))
                o = sortperm(nwb)
                measures(nwb[o], wb[o])
            end
            se = bootstrap_se(est, reps)
        end

        add_results!(results, summary, s.year, x, ws, est, se)
    end

    CSV.write(joinpath(OUTDIR, "sfs_nbsa_aligned.csv"), aligned)
    CSV.write(joinpath(OUTDIR, "sfs_nbsa_alignment.csv"), alignment)
    CSV.write(joinpath(OUTDIR, "sfs_nbsa_wealth_inequality.csv"), results)
    CSV.write(joinpath(OUTDIR, "sfs_nbsa_wealth_summary.csv"), summary)

    println("\nSFS vs NBSA household sector (\$ billions)")
    @printf("%-6s %-9s %-13s %10s %10s %9s %8s\n", "year", "quarter", "category", "SFS", "NBSA", "coverage", "factor")
    for r in eachrow(alignment)
        @printf("%-6d %-9s %-13s %10.0f %10.0f %9.3f %8.3f\n",
                r.year, r.nbsa_quarter, r.category, r.sfs_billions, r.nbsa_billions, r.coverage, r.adjustment_factor)
    end
    print_results(results)
    println("\nWrote output/sfs_nbsa_aligned.csv, sfs_nbsa_alignment.csv, sfs_nbsa_wealth_inequality.csv and sfs_nbsa_wealth_summary.csv")
end

main()
