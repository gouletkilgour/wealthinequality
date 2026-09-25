# Setup 

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

# Read the data

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

function load_year(s::SurveyYear)
    df = read_fixed_width(joinpath(DATA, s.datafile), joinpath(DATA, s.layout),
                          ["PEFAMID", "PWEIGHT", "PWNETWPT"])
    return DataFrame(id = df.PEFAMID, weight = df.PWEIGHT, networth = df.PWNETWPT)
end

# Inequality measures

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

records_in_top(w, p) = count(>(sum(w) * (1 - p) * (1 + 1e-12)), cumsum(w))

function weighted_median(x, w)
    cw = cumsum(w)
    return x[searchsortedfirst(cw, cw[end] / 2)]
end

# Bootstrap standard errors

function bootstrap_se(s::SurveyYear, fam::DataFrame, order, estimates)
    layout = parse_layout(joinpath(DATA, s.bslayout))
    bs_vars = sort([v for v in keys(layout) if startswith(v, "BSW_")], by = v -> parse(Int, v[5:end]))
    lines = readlines(joinpath(DATA, s.bsfile))
    length(lines) == nrow(fam) || error("$(s.year): bootstrap file has $(length(lines)) records")

    # Match bootstrap records to families by ID and check the full-sample weight agrees.
    row_of = Dict(strip(field(l, layout["PEFAMID"][1:2]...)) => r for (r, l) in enumerate(lines))
    rows = [row_of[id] for id in fam.id[order]]
    for (k, r) in enumerate(rows)
        wt = parse_number(field(lines[r], layout["PWEIGHT"][1:2]...), layout["PWEIGHT"][3])
        abs(wt - fam.weight[order][k]) < 1e-3 || error("$(s.year): weight mismatch for $(fam.id[order][k])")
    end

    x = fam.networth[order]
    sq = Dict(k => 0.0 for k in keys(estimates))
    for v in bs_vars
        start, width, decimals, _ = layout[v]
        wb = [parse_number(field(lines[r], start, width), decimals) for r in rows]
        mb = measures(x, wb)
        for k in keys(sq)
            sq[k] += (mb[k] - estimates[k])^2
        end
    end
    return Dict(k => sqrt(v / length(bs_vars)) for (k, v) in sq)
end

# Run

function main()
    mkpath(OUTDIR)
    results = DataFrame(year = Int[], measure = String[], estimate = Float64[],
                        se = Union{Float64,Missing}[], records_in_group = Int[])
    summary = DataFrame(year = Int[], records = Int[], families = Float64[],
                        total_networth_millions = Float64[], mean_networth = Float64[],
                        median_networth = Float64[], share_negative_networth = Float64[],
                        bootstrap_se = Bool[])

    for s in SURVEYS
        println("Computing $(s.year)...")
        fam = load_year(s)
        order = sortperm(fam.networth)
        x, w = fam.networth[order], fam.weight[order]
        est = measures(x, w)
        se = s.bsfile === nothing ? nothing : bootstrap_se(s, fam, order, est)

        push!(summary, (s.year, length(x), sum(w), est["total_networth"] / 1e6, est["total_networth"] / sum(w),
                        weighted_median(x, w), sum(w[x .< 0]) / sum(w), se !== nothing))

        for p in TOP_GROUPS
            k = group_name(p)
            push!(results, (s.year, k, est[k], se === nothing ? missing : se[k], records_in_top(w, p)))
        end
        push!(results, (s.year, "gini", est["gini"], se === nothing ? missing : se["gini"], length(x)))
    end

    CSV.write(joinpath(OUTDIR, "sfs_wealth_inequality.csv"), results)
    CSV.write(joinpath(OUTDIR, "sfs_wealth_summary.csv"), summary)

    println("\nShare of total net worth (%) held by the top group, and Gini")
    println("(bootstrap SE in parentheses; number of survey records in the group in brackets)")
    years = [s.year for s in SURVEYS]
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
    println("\nWrote output/sfs_wealth_inequality.csv and output/sfs_wealth_summary.csv")
end

main()
