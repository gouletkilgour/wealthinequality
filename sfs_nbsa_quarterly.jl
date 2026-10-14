include("functions.jl")
using Dates

# A quarterly series of the family wealth distribution from 2012 Q1 to 2026 Q1, harmonizing the
# SFS with the quarterly NBSA in the manner of Statistics Canada's Distributions of Household
# Economic Accounts (DHEA; Statistics Canada 2026, catalogue 13-604-M2026001, sections 7 and 8):
#
# 1. Reweight. Each SFS is carried to quarter t by growing the weight of every family by the
#    population growth, from the survey quarter to t, of the age group of its major income
#    earner in its region (DHEA section 8.1 recalibrates to demographic totals).
# 2. Scale. The reweighted SFS is scaled to the NBSA household sector of quarter t in DHEA's six
#    categories (DHEA section 7.3 and Table 2).
# 3. Combine. A quarter between two surveys pools the two scaled files, with weights multiplied
#    by 1 - λ and λ, where λ is the share of the time between the surveys that has elapsed
#    (DHEA section 8.1 interpolates the two estimates linearly instead). Quarters before 2012 Q4
#    use the 2012 SFS alone, and quarters after 2023 Q2 the 2023 SFS alone.
#
# Unlike DHEA, there is no adjustment for influential records, the institutionalized elderly or
# the territories, no smoothing at survey quarters and no use of Equifax data, and the unit is the
# economic family rather than the household, since the PUMF has no household identifier.

const POP_DIR = joinpath(@__DIR__, "data", "population")
const DHEA_FILE = joinpath(@__DIR__, "data", "dhea", "36100660.csv")

const FIRST_QUARTER, LAST_QUARTER = "2012-01", "2026-01"   # NBSA REF_DATE of the first and last quarters

# DHEA's six categories, as SFS PUMF variables. Debts come last, so net worth is the sum of the
# first four less the last two.
const CATEGORIES6 = ["pensions", "other_financial", "real_estate", "other_nonfinancial", "mortgages", "other_debts"]
const CATEGORY6_VARS = [["PWARPPT"],
                        ["PWASTDEP", "PWASTMUI", "PWASTBND", "PWASTSTK", "PWASTOIN", "PWATFS",
                         "PWARRSPL", "PWARRIF", "PWAOTPEN", "PWBUSEQ"],
                        ["PWAPRVAL", "PWASTRST"],
                        ["PWASTVHE", "PWASTONF"],
                        ["PWDPRMOR", "PWDSTOMR"],
                        ["PWDSTCRD", "PWDSLOAN", "PWDSTVHN", "PWDSTLOC", "PWDSTODB"]]
const SIGNS = [1, 1, 1, 1, -1, -1]

# The same categories in the NBSA, as sums and differences of member IDs of the Categories
# dimension of Table 36-10-0580-01 (IDs rather than names, since names such as "Mortgages" occur
# on both sides of the balance sheet): life insurance and pensions (44); total financial assets
# (14) less 44; dwellings (4), other buildings and structures (5) and land (12); non-financial
# assets (2) less real estate; mortgage liabilities (70); total financial liabilities (50) less 70.
const NBSA_MEMBERS = [[44 => 1], [14 => 1, 44 => -1], [4 => 1, 5 => 1, 12 => 1],
                      [2 => 1, 4 => -1, 5 => -1, 12 => -1], [70 => 1], [50 => 1, 70 => -1]]

const REGIONS = ["Atlantic", "Quebec", "Ontario", "Prairies", "British Columbia"]
const PROVINCES = Dict("Atlantic" => ["Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick"],
                       "Quebec" => ["Quebec"], "Ontario" => ["Ontario"],
                       "Prairies" => ["Manitoba", "Saskatchewan", "Alberta"],
                       "British Columbia" => ["British Columbia"])

# DHEA's age groups of the major income earner, and the population age groups (Table 17-10-0005-01)
# whose growth carries each one forward
const AGE_GROUPS = ["Under 35", "35 to 44", "45 to 54", "55 to 64", "65 and over"]
const POP_AGES = [["18 to 24 years", "25 to 29 years", "30 to 34 years"], ["35 to 39 years", "40 to 44 years"],
                  ["45 to 49 years", "50 to 54 years"], ["55 to 59 years", "60 to 64 years"], ["65 years and older"]]

# Age group (1 to 5) from the age of the major income earner: single years, 80 being 80 and over,
# in 2012 and 2016; five-year groups in 2019; DHEA's groups, with 65 and over split at 80, in 2023
function age_group(year, v)
    if year in (2012, 2016)
        a = Int(v)
        return a < 35 ? 1 : a < 45 ? 2 : a < 55 ? 3 : a < 65 ? 4 : 5
    end
    c = parse(Int, v)
    year == 2019 && 1 <= c <= 14 && return c <= 4 ? 1 : c <= 6 ? 2 : c <= 8 ? 3 : c <= 10 ? 4 : 5
    year == 2023 && 1 <= c <= 7 && return c <= 2 ? 1 : c == 3 ? 2 : c == 4 ? 3 : c == 5 ? 4 : 5
    error("$year: unexpected age group code $v")
end

function load_survey(s::SurveyYear)
    age = s.year in (2012, 2016) ? "PAGEMIE" : "PAGEMIEG"
    df = read_fixed_width(joinpath(DATA, s.datafile), joinpath(DATA, s.layout),
                          vcat("PEFAMID", "PWEIGHT", "PREGION", age, reduce(vcat, CATEGORY6_VARS), "PWDTOTAL", "PWNETWPT"))
    fam = DataFrame(id = df.PEFAMID, weight = df.PWEIGHT,
                    region = parse.(Int, df.PREGION), age = age_group.(s.year, df[!, age]))
    for (c, vars) in zip(CATEGORIES6, CATEGORY6_VARS)
        fam[!, c] = sum(df[!, v] for v in vars)
    end
    maximum(abs.(fam.mortgages .+ fam.other_debts .- df.PWDTOTAL)) < 0.5 ||
        error("$(s.year): debt categories do not add up to PWDTOTAL")
    maximum(abs.(networth6(fam, ones(6)) .- df.PWNETWPT)) < 0.5 ||
        error("$(s.year): categories do not add up to PWNETWPT")
    all(in(1:5), fam.region) || error("$(s.year): unexpected region code")
    return fam
end

# StatCan tables leave VALUE empty for unavailable cells
has_value(v) = !ismissing(v) && !isempty(v)

networth6(fam, f) = sum(SIGNS[k] * f[k] .* fam[!, c] for (k, c) in enumerate(CATEGORIES6))

# NBSA household sector at market value, in dollars, in the six categories, by REF_DATE
function load_nbsa6()
    nbsa = CSV.read(NBSA_FILE, DataFrame; select = [:REF_DATE, :Sectors, :Valuation, :COORDINATE, :VALUE],
                    types = Dict(:VALUE => String, :COORDINATE => String))
    nbsa = nbsa[(nbsa.Sectors .== "Households") .& (nbsa.Valuation .== "Market value") .&
                (FIRST_QUARTER .<= nbsa.REF_DATE .<= LAST_QUARTER), :]
    value = Dict((r.REF_DATE, parse(Int, split(r.COORDINATE, ".")[end])) => parse(Float64, r.VALUE) * 1e6
                 for r in eachrow(nbsa) if has_value(r.VALUE))
    quarters = sort(unique(nbsa.REF_DATE))
    return quarters, Dict(q => [sum(sign * value[(q, m)] for (m, sign) in members) for members in NBSA_MEMBERS]
                          for q in quarters)
end

# The NBSA is a stock at the end of each quarter, so a quarter's population is that of the first
# day of the next quarter
quarter_date(q) = Date(q * "-01") + Month(3)
quarter_label(q) = q[1:4] * "Q" * string(div(parse(Int, q[6:7]) - 1, 3) + 1)
quarter_index(q) = 4 * parse(Int, q[1:4]) + div(parse(Int, q[6:7]) - 1, 3)

# Population by region and age group on a date: each province's total from the quarterly
# estimates (Table 17-10-0009-01), split by age with the July 1 age shares (Table 17-10-0005-01),
# interpolated linearly between the two nearest July 1sts
function population_reader()
    quarterly = CSV.read(joinpath(POP_DIR, "17100009.csv"), DataFrame; select = [:REF_DATE, :GEO, :VALUE])
    total = Dict((Date(r.REF_DATE), r.GEO) => Float64(r.VALUE) for r in eachrow(quarterly))
    annual = CSV.read(joinpath(POP_DIR, "17100005.csv"), DataFrame; select = [:REF_DATE, :GEO, :Gender, Symbol("Age group"), :VALUE],
                      types = Dict(:VALUE => String))
    annual = annual[(annual.Gender .== "Total - gender") .& has_value.(annual.VALUE), :]
    count = Dict((r.REF_DATE, r.GEO, r[Symbol("Age group")]) => parse(Float64, r.VALUE) for r in eachrow(annual))
    share(y, p, a) = sum(count[(y, p, g)] for g in POP_AGES[a]) / count[(y, p, "All ages")]

    return function (d::Date)
        y0 = month(d) >= 7 ? year(d) : year(d) - 1
        t = (d - Date(y0, 7, 1)).value / (Date(y0 + 1, 7, 1) - Date(y0, 7, 1)).value
        pop = zeros(length(REGIONS), length(AGE_GROUPS))
        for (r, region) in enumerate(REGIONS), p in PROVINCES[region], a in eachindex(AGE_GROUPS)
            pop[r, a] += total[(d, p)] * ((1 - t) * share(y0, p, a) + t * share(y0 + 1, p, a))
        end
        return pop
    end
end

# The surveys used for a quarter, with the weight given to each
function survey_mix(q)
    anchors = [(s, quarter_index(NBSA_QUARTER[s.year])) for s in SURVEYS]
    i = quarter_index(q)
    i <= anchors[1][2] && return [(anchors[1][1], 1.0)]
    i >= anchors[end][2] && return [(anchors[end][1], 1.0)]
    k = findlast(a -> a[2] <= i, anchors)
    i == anchors[k][2] && return [(anchors[k][1], 1.0)]
    λ = (i - anchors[k][2]) / (anchors[k+1][2] - anchors[k][2])
    return [(anchors[k][1], 1 - λ), (anchors[k+1][1], λ)]
end

# One survey carried to quarter q: weights grown by population growth in each region × age group
# cell, then the six categories scaled to the NBSA
function carry(fam, growth, nbsa_q)
    w = fam.weight .* [growth[r, a] for (r, a) in zip(fam.region, fam.age)]
    totals = [sum(w .* fam[!, c]) for c in CATEGORIES6]
    f = nbsa_q ./ totals
    return (; w, f, totals, networth = networth6(fam, f))
end

# The pooled, NBSA-scaled family-level file for quarter q. Step 2 (the top tail) starts from this.
function quarter_file(q, fams, nbsa, population)
    pop_q = population(quarter_date(q))
    parts, details = DataFrame[], []
    for (s, share) in survey_mix(q)
        growth = pop_q ./ population(quarter_date(NBSA_QUARTER[s.year]))
        c = carry(fams[s.year], growth, nbsa[q])
        fam = fams[s.year]
        df = DataFrame(survey = s.year, id = fam.id, weight = share .* c.w, region = fam.region, age = fam.age)
        for (k, cat) in enumerate(CATEGORIES6)
            df[!, cat] = c.f[k] .* fam[!, cat]
        end
        df.networth = c.networth
        push!(parts, df)
        push!(details, (; s, share, growth, c))
    end
    return vcat(parts...), details
end

# Net worth share (%) of each wealth quintile, for x sorted ascending
function quintile_shares(x, w)
    W, cw, cx = sum(w), cumsum(w), cumsum(w .* x)
    below = [0.0; [wealth_below(x, W, cw, cx, q) for q in (0.2, 0.4, 0.6, 0.8)]; cx[end]]
    return 100 .* diff(below) ./ cx[end]
end

# DHEA net worth shares by wealth quintile (percent), by REF_DATE
function load_dhea_quintiles()
    df = CSV.read(DHEA_FILE, DataFrame; select = [:REF_DATE, :Statistics, :Characteristics, :Wealth, :VALUE],
                  types = Dict(:VALUE => String))
    names = ["Lowest wealth quintile", "Second wealth quintile", "Third wealth quintile",
             "Fourth wealth quintile", "Highest wealth quintile"]
    df = df[(df.Statistics .== "Distribution of value") .& (df.Wealth .== "Net worth (wealth)") .&
            in(names).(df.Characteristics) .& has_value.(df.VALUE), :]
    return Dict((r.REF_DATE, findfirst(==(r.Characteristics), names)) => parse(Float64, r.VALUE) for r in eachrow(df))
end

function main()
    mkpath(OUTDIR)
    quarters, nbsa = load_nbsa6()
    quarters[1] == FIRST_QUARTER && quarters[end] == LAST_QUARTER || error("NBSA does not cover $FIRST_QUARTER to $LAST_QUARTER")
    population = population_reader()
    fams = Dict(s.year => load_survey(s) for s in SURVEYS)
    dhea = load_dhea_quintiles()

    results = DataFrame(quarter = String[], date = Date[], measure = String[], estimate = Float64[])
    summary = DataFrame(quarter = String[], date = Date[], surveys = String[], records = Int[],
                        families = Float64[], total_networth_millions = Float64[], mean_networth = Float64[],
                        median_networth = Float64[], share_negative_networth = Float64[])
    alignment = DataFrame(quarter = String[], survey = Int[], survey_share = Float64[], category = String[],
                          sfs_billions = Float64[], nbsa_billions = Float64[], adjustment_factor = Float64[])
    reweighting = DataFrame(quarter = String[], survey = Int[], region = String[], age_group = String[],
                            survey_families = Float64[], families = Float64[], growth = Float64[])
    quintiles = DataFrame(quarter = String[], date = Date[], quintile = Int[], sfs_nbsa = Float64[],
                          dhea = Union{Float64,Missing}[])

    for q in quarters
        label, date = quarter_label(q), quarter_date(q) - Day(1)
        hfd, details = quarter_file(q, fams, nbsa, population)
        sort!(hfd, :networth)
        x, w = hfd.networth, hfd.weight
        est = measures(x, w)

        for p in TOP_GROUPS
            push!(results, (label, date, group_name(p), est[group_name(p)]))
        end
        push!(results, (label, date, "gini", est["gini"]))

        surveys = join(("$(d.s.year) × $(round(d.share, digits = 4))" for d in details), " + ")
        push!(summary, (label, date, surveys, nrow(hfd), sum(w), est["total_networth"] / 1e6, est["total_networth"] / sum(w),
                        weighted_median(x, w), sum(w[x .< 0]) / sum(w)))

        for d in details
            for (k, c) in enumerate(CATEGORIES6)
                push!(alignment, (label, d.s.year, d.share, c, d.c.totals[k] / 1e9, nbsa[q][k] / 1e9, d.c.f[k]))
            end
            fam = fams[d.s.year]
            for (r, region) in enumerate(REGIONS), (a, ag) in enumerate(AGE_GROUPS)
                cell = (fam.region .== r) .& (fam.age .== a)
                push!(reweighting, (label, d.s.year, region, ag, sum(fam.weight[cell]),
                                    sum(fam.weight[cell]) * d.growth[r, a], d.growth[r, a]))
            end
        end

        for (k, v) in enumerate(quintile_shares(x, w))
            push!(quintiles, (label, date, k, v, get(dhea, (q, k), missing)))
        end
    end

    files = ["sfs_nbsa_quarterly_$(k).csv" => t for (k, t) in ("wealth_inequality" => results, "summary" => summary,
             "alignment" => alignment, "reweighting" => reweighting, "dhea_quintiles" => quintiles)]
    for (file, t) in files
        CSV.write(joinpath(OUTDIR, file), t)
    end

    println("\nTop shares (%) and Gini, quarterly; * marks survey quarters")
    @printf("%-8s %-28s %7s %7s %7s %7s %6s\n", "quarter", "surveys", "top 1%", "top 10%", "top 20%", "top 50%", "gini")
    for r in eachrow(summary)
        m = Dict(x.measure => x.estimate for x in eachrow(results[results.quarter .== r.quarter, :]))
        star = r.quarter in quarter_label.(values(NBSA_QUARTER)) ? "*" : ""
        @printf("%-8s %-28s %7.1f %7.1f %7.1f %7.1f %6.3f\n", r.quarter * star, r.surveys,
                m["top_1pct"], m["top_10pct"], m["top_20pct"], m["top_50pct"], m["gini"])
    end
    println("\nAdjustment factors at the survey quarters")
    @printf("%-6s %-20s %10s %10s %8s\n", "year", "category", "SFS (\$B)", "NBSA (\$B)", "factor")
    for s in SURVEYS
        rows = alignment[(alignment.quarter .== quarter_label(NBSA_QUARTER[s.year])) .& (alignment.survey .== s.year), :]
        for r in eachrow(rows)
            @printf("%-6d %-20s %10.0f %10.0f %8.3f\n", s.year, r.category, r.sfs_billions, r.nbsa_billions, r.adjustment_factor)
        end
    end
    println("\nNet worth share of the highest wealth quintile (%): this series (families) vs DHEA (households)")
    for r in eachrow(quintiles[(quintiles.quintile .== 5) .& .!ismissing.(quintiles.dhea), :])
        @printf("%-8s %6.1f %6.1f\n", r.quarter, r.sfs_nbsa, r.dhea)
    end
    println("Wrote ", join(("output/" * file for (file, _) in files), ", "))
end

# Run only as a script, so step 2 can include this file and build on quarter_file
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
