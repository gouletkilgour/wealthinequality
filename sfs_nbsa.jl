include("functions.jl")

const NBSA_FILE = joinpath(@__DIR__, "data", "nbsa", "36100580.csv")

const NBSA_QUARTER = Dict(2012 => "2012-10", 2016 => "2016-10", 2019 => "2019-10", 2023 => "2023-04")

const CATEGORIES = ["financial", "nonfinancial", "debts"]
const NBSA_CATEGORIES = ["Total financial assets", "Non-financial assets", "Total financial liabilities"]

function load_nbsa()
    nbsa = CSV.read(NBSA_FILE, DataFrame; select = [:REF_DATE, :Sectors, :Valuation, :Categories, :VALUE],
                    types = Dict(:VALUE => String))   # some rows have no value
    totals = Dict{Int,Vector{Float64}}()
    for (year, quarter) in NBSA_QUARTER
        totals[year] = map(NBSA_CATEGORIES) do c
            rows = nbsa[(nbsa.REF_DATE .== quarter) .& (nbsa.Sectors .== "Households") .&
                        (nbsa.Valuation .== "Market value") .& (nbsa.Categories .== c), :VALUE]
            length(rows) == 1 || error("$quarter $c: $(length(rows)) NBSA rows")
            parse(Float64, rows[1]) * 1e6   # millions -> dollars
        end
    end
    return totals
end

const FINANCIAL = ["PWASTDEP", "PWASTMUI", "PWASTBND", "PWASTSTK", "PWASTOIN", "PWATFS",
                   "PWARRSPL", "PWARRIF", "PWAOTPEN", "PWARPPT", "PWBUSEQ"]
const NONFINANCIAL = ["PWAPRVAL", "PWASTRST", "PWASTVHE", "PWASTONF"]

function load_year(s::SurveyYear)
    df = read_fixed_width(joinpath(DATA, s.datafile), joinpath(DATA, s.layout),
                          vcat("PEFAMID", "PWEIGHT", FINANCIAL, NONFINANCIAL, "PWDTOTAL", "PWNETWPT"))
    fam = DataFrame(id = df.PEFAMID, weight = df.PWEIGHT,
                    financial = sum(df[!, v] for v in FINANCIAL),
                    nonfinancial = sum(df[!, v] for v in NONFINANCIAL),
                    debts = df.PWDTOTAL)
    maximum(abs.(fam.financial .+ fam.nonfinancial .- fam.debts .- df.PWNETWPT)) < 0.5 ||
        error("$(s.year): categories do not add up to PWNETWPT")
    return fam
end

sfs_totals(fam, w) = [sum(w .* fam[!, c]) for c in CATEGORIES]

adjustment_factors(fam, w, nbsa) = nbsa ./ sfs_totals(fam, w)

aligned_networth(fam, f) = f[1] .* fam.financial .+ f[2] .* fam.nonfinancial .- f[3] .* fam.debts

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
        fam = load_year(s)
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
