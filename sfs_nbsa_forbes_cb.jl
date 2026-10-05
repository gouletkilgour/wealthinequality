include("sfs_nbsa_forbes.jl")

# Runs the procedure of sfs_nbsa_forbes.jl with the Canadian Business rich list merged with Forbes
# for 2012 and 2016: data/cb_macleans_forbes holds one row per family on either list, at the
# average of its two net worths, or its only one. The merged lists reach below the Forbes
# billionaires, to the 100th Canadian Business entry, so the synthetic families stop there, as in
# PBO (2020). There is no Canadian Business list for 2019 and 2023, which keep the Forbes list and
# so must give the same results as sfs_nbsa_forbes.jl.

const CB_FORBES_DIR = joinpath(@__DIR__, "data", "cb_macleans_forbes")
const CB_YEARS = (2012, 2016)

function load_cb_forbes(year)
    year in CB_YEARS || return load_forbes(year)
    df = CSV.read(joinpath(CB_FORBES_DIR, "cb_macleans_forbes_canada_$(year)_cad.csv"), DataFrame)
    return DataFrame(name = df.name, networth = 1e9 .* Float64.(df.net_worth_avg))
end

main(load_list = load_cb_forbes, prefix = "sfs_nbsa_forbes_cb", list_name = "Rich list")
