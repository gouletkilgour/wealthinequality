using CSV, DataFrames, Printf

const DATA = joinpath(@__DIR__, "data", "sfs_pumf")
const OUTDIR = joinpath(@__DIR__, "output")

const TOP_GROUPS = [0.0001, 0.001, 0.01, 0.05, 0.10, 0.20, 0.50]

struct SurveyYear
    year::Int
    datafile::String
    layout::String
    bsfile::Union{String,Nothing}
    bslayout::Union{String,Nothing}
end

const SURVEYS = [
    SurveyYear(2012, "2012/Data/SFS2012_PUMF.txt", "2012/SasCard/SFS2012_PUMF_i.SAS", nothing, nothing),
    SurveyYear(2016, "2016/Data/SFS2016_EFAM_PUMF.txt", "2016/SasCard/SFS2016_EFAM_PUMF_i.SAS",
               "2016/Data/SFS2016_BSWEIGHTS_PUMF.txt", "2016/SasCard/sfs2016_bsweights_pumf_i.SAS"),
    SurveyYear(2019, "2019/SFS2019_EFAM_PUMF.txt", "2019/SAS/SFS2019_EFAM_PUMF_i.SAS",
               "2019/SFS2019_BSWEIGHTS_PUMF.txt", "2019/SAS/sfs2019_bsweights_pumf_i.SAS"),
    SurveyYear(2023, "2023/SFS2023_EFAM_PUMF.txt", "2023/SAS/SFS2023_EFAM_PUMF_i.SAS",
               "2023/SFS2023_BSWEIGHTS_PUMF.txt", "2023/SAS/sfs2023_bsweights_pumf_i.SAS"),
]

function parse_layout(path)
    layout = Dict{String,Tuple{Int,Int,Int,Bool}}()
    for line in eachline(path)
        m = match(r"@\s*(\d+)\s+(\w+)\s+(\$?)\s*(\d+)\.(\d*)", line)
        m === nothing && continue
        layout[m[2]] = (parse(Int, m[1]), parse(Int, m[4]), isempty(m[5]) ? 0 : parse(Int, m[5]), m[3] == "\$")
    end
    return layout
end

function parse_number(s::AbstractString, decimals::Int)
    s = strip(s)
    isempty(s) && error("blank numeric field")
    x = parse(Float64, s)
    return (decimals > 0 && !occursin('.', s)) ? x / 10.0^decimals : x
end

field(line, start, width) = String(codeunits(line)[start:start+width-1])

function read_fixed_width(datafile, layoutfile, vars)
    layout = parse_layout(layoutfile)
    lines = readlines(datafile)
    df = DataFrame()
    for v in vars
        haskey(layout, v) || error("$v not in layout $layoutfile")
        start, width, decimals, ischar = layout[v]
        df[!, v] = ischar ? [strip(field(l, start, width)) for l in lines] :
                            [parse_number(field(l, start, width), decimals) for l in lines]
    end
    return df
end

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

function load_categories(s::SurveyYear)
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

function measures(x, w)
    W = sum(w)
    cw = cumsum(w)
    cx = cumsum(w .* x)
    X = cx[end]

    function wealth_below(q)
        t = q * W
        i = min(searchsortedfirst(cw, t), length(cw))
        prev_w = i == 1 ? 0.0 : cw[i-1]
        prev_x = i == 1 ? 0.0 : cx[i-1]
        return prev_x + (t - prev_w) * x[i]
    end

    out = Dict{String,Float64}()
    for p in TOP_GROUPS
        out[group_name(p)] = 100 * (X - wealth_below(1 - p)) / X
    end

    lorenz_area = 0.0
    prev_L = 0.0
    for i in eachindex(x)
        L = cx[i] / X
        lorenz_area += (w[i] / W) * (prev_L + L) / 2
        prev_L = L
    end
    out["gini"] = 1 - 2 * lorenz_area
    out["total_networth"] = X
    return out
end

group_name(p) = "top_" * replace(@sprintf("%g", 100p), "." => "_") * "pct"

records_in_top(w, p, survey) = count(survey .& (cumsum(w) .> sum(w) * (1 - p) * (1 + 1e-12)))

function weighted_median(x, w)
    cw = cumsum(w)
    return x[searchsortedfirst(cw, cw[end] / 2)]
end

function bootstrap_weights(s::SurveyYear, ids, weights)
    layout = parse_layout(joinpath(DATA, s.bslayout))
    bs_vars = sort([v for v in keys(layout) if startswith(v, "BSW_")], by = v -> parse(Int, v[5:end]))
    lines = readlines(joinpath(DATA, s.bsfile))
    length(lines) == length(ids) || error("$(s.year): bootstrap file has $(length(lines)) records")

    row_of = Dict(strip(field(l, layout["PEFAMID"][1:2]...)) => r for (r, l) in enumerate(lines))
    rows = [row_of[id] for id in ids]
    for (k, r) in enumerate(rows)
        wt = parse_number(field(lines[r], layout["PWEIGHT"][1:2]...), layout["PWEIGHT"][3])
        abs(wt - weights[k]) < 1e-3 || error("$(s.year): weight mismatch for $(ids[k])")
    end

    bw = Matrix{Float64}(undef, length(rows), length(bs_vars))
    for (b, v) in enumerate(bs_vars)
        start, width, decimals, _ = layout[v]
        bw[:, b] = [parse_number(field(lines[r], start, width), decimals) for r in rows]
    end
    return bw
end

bootstrap_se(estimates, replicates) =
    Dict(k => sqrt(sum((r[k] - estimates[k])^2 for r in replicates) / length(replicates)) for k in keys(estimates))

function results_tables()
    results = DataFrame(year = Int[], measure = String[], estimate = Float64[],
                        se = Union{Float64,Missing}[], records_in_group = Int[])
    summary = DataFrame(year = Int[], records = Int[], families = Float64[],
                        total_networth_millions = Float64[], mean_networth = Float64[],
                        median_networth = Float64[], share_negative_networth = Float64[],
                        bootstrap_se = Bool[])
    return results, summary
end

# survey marks the rows that are survey records, as opposed to synthetic or rich-list families
function add_results!(results, summary, year, x, w, est, se; survey = trues(length(x)))
    push!(summary, (year, count(survey), sum(w), est["total_networth"] / 1e6, est["total_networth"] / sum(w),
                    weighted_median(x, w), sum(w[x .< 0]) / sum(w), se !== nothing))
    for p in TOP_GROUPS
        k = group_name(p)
        push!(results, (year, k, est[k], se === nothing ? missing : se[k], records_in_top(w, p, survey)))
    end
    push!(results, (year, "gini", est["gini"], se === nothing ? missing : se["gini"], count(survey)))
end

function print_results(results)
    println("\nShare of total net worth (%) held by the top group, and Gini")
    println("(bootstrap SE in parentheses; number of survey records in the group in brackets)")
    years = unique(results.year)
    @printf("%-12s", "")
    foreach(y -> @printf("%22s", y), years)
    println()
    for m in vcat(group_name.(TOP_GROUPS), "gini")
        @printf("%-12s", m)
        for y in years
            r = results[(results.year .== y) .& (results.measure .== m), :][1, :]
            fmt = m == "gini" ? Printf.Format("%.3f") :
                  m in ("top_0_01pct", "top_0_1pct") ? Printf.Format("%.2f") : Printf.Format("%.1f")
            txt = Printf.format(fmt, r.estimate)
            ismissing(r.se) || (txt *= " (" * Printf.format(fmt, r.se) * ")")
            m == "gini" || (txt *= " [$(r.records_in_group)]")
            @printf("%22s", txt)
        end
        println()
    end
end
