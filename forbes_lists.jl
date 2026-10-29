using CSV, DataFrames

# Writes data/forbes/forbes_canada_<year>_cad.csv for 2012 to 2025 from data/forbes/canada/<year>.csv,
# the entries with Canadian citizenship on Forbes' World's Billionaires list of each year (net worth
# in billions of US dollars, in Forbes' rank order). Relatives that Forbes lists separately are
# summed in US dollars into one row, converted to Canadian dollars at the Bank of Canada rate on
# the date Forbes valued the list, and rounded to $10 million. The 2023 file was built by hand with
# the same rules and is not rewritten, since it rounds one family differently.

const FORBES_DIR = joinpath(@__DIR__, "data", "forbes")
const HAND_BUILT = (2023,)

# year => (Forbes valuation date, USD/CAD on that date). The Bank of Canada legacy noon rate
# (IEXE0101) to 2016, and its single daily rate (FXUSDCAD) from 2017.
const FX = Dict(2012 => ("2012-02-14", 0.9991), 2013 => ("2013-02-14", 1.0008), 2014 => ("2014-02-14", 1.0981),
                2015 => ("2015-02-13", 1.2449), 2016 => ("2016-02-12", 1.3835), 2017 => ("2017-02-10", 1.3084),
                2018 => ("2018-02-09", 1.2609), 2019 => ("2019-02-08", 1.3270), 2020 => ("2020-03-18", 1.4496),
                2021 => ("2021-03-05", 1.2668), 2022 => ("2022-03-11", 1.2720), 2023 => ("2023-03-10", 1.3807),
                2024 => ("2024-03-08", 1.3471), 2025 => ("2025-03-07", 1.4371))

# Relatives combined into one row. A family with one member on a year's list keeps that member's
# name, except the Irvings, who are a family row in every year, as in the earlier files. In 2025
# Forbes split the Thomson fortune among David, Peter and Taylor Thomson and their cousins.
const FAMILIES = Dict("Irving family" => ["James Irving", "Arthur Irving"],
                      "Saputo family" => ["Emanuele (Lino) Saputo", "Francesco Saputo"],
                      "Zekelman family" => ["Barry Zekelman", "Clayton Zekelman", "Alan Zekelman"],
                      "Azrieli family" => ["Sharon Azrieli", "Naomi Azrieli"],
                      "Phillips family" => ["John Phillips", "Catherine Phillips"],
                      "Thomson family" => ["David Thomson", "Peter Thomson", "Taylor Thomson", "Sherry Brydson",
                                           "Gaye Farncombe", "Linda Campbell"])
const ALWAYS_FAMILY = ("Irving family",)

function build(year)
    _, rate = FX[year]
    df = CSV.read(joinpath(FORBES_DIR, "canada", "$year.csv"), DataFrame)
    names, usd = String.(df.Name), Float64.(df[!, "Wealth (in \$1B USD)"])
    family = Dict(m => f for (f, members) in FAMILIES for m in members)
    present = Dict(f => count(in(members), names) for (f, members) in FAMILIES)
    row(n) = haskey(family, n) && (present[family[n]] > 1 || family[n] in ALWAYS_FAMILY) ? family[n] : n

    # Sum by row, keeping Forbes' order, then sort by net worth; the sort is stable, so ties keep it
    order, total = String[], Dict{String,Float64}()
    for (n, x) in zip(row.(names), usd)
        haskey(total, n) || push!(order, n)
        total[n] = get(total, n, 0.0) + x
    end
    out = DataFrame(name = order, net_worth = [round(total[n] * rate, digits = 2) for n in order])
    return sort!(out, :net_worth, rev = true)
end

function main()
    for year in sort(collect(keys(FX)))
        year in HAND_BUILT && continue
        out = build(year)
        CSV.write(joinpath(FORBES_DIR, "forbes_canada_$(year)_cad.csv"), out)
        println("forbes_canada_$(year)_cad.csv: $(nrow(out)) rows at $(FX[year][2]) ($(FX[year][1])), ",
                "total \$$(round(sum(out.net_worth), digits = 2))B")
    end
end

main()
