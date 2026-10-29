# Overview

This repository contains the data and code for calculating wealth inequality in Canada.

# Data

All raw data are located in `data`. 

## Survey of Financial Security: Public Use Microdata File

The Survey of Financial Security (SFS) is a cross-sectional household survey focussed on wealth and income. It is conducted by Statistics Canada every few years: 1999, 2005, 2012, 2016, 2019, and 2023. 

The Public Use Microdata File (PUMF) is a subset of the data which is publicly available. 

These data are located in `data/sfs_pumf`. The boostrap weights for 2016, 2019, and 2023 are not included in this repository because they are too large, but they can easily downloaded from [here](https://www150.statcan.gc.ca/n1/pub/13m0006x/13m0006x2021001-eng.htm).

## National Balance Sheet Accounts

The National Balance Sheet Accounts (NBSA) are Statistics Canada's quarterly estimates of the assets, liabilities and net worth of each sector of the Canadian economy, including households. Unlike the SFS, they are aggregate totals built from administrative and financial data rather than a survey of families, and they are available every quarter. The data come from Statistics Canada [Table 36-10-0580-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=3610058001), which covers 1990 Q1 to 2026 Q1 in the downloaded version, in millions of dollars at market and book value.

These data are located in `data/nbsa`. The CSV is too large for this repository, so unzip `data/nbsa/36100580-eng.zip` to recreate `data/nbsa/36100580.csv`. 

## Population Estimates

Statistics Canada's population estimates are used to carry the SFS weights from one quarter to another. They come from [Table 17-10-0009-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1710000901), the population of each province on the first day of each quarter (to July 1, 2026), and [Table 17-10-0005-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1710000501), the population on July 1 of each year by province and age group (to 2026).

These data are located in `data/population`. The second table is too large for this repository, so unzip `data/population/17100005-eng.zip` to recreate `data/population/17100005.csv`.

## Distributions of Household Economic Accounts

Statistics Canada's Distributions of Household Economic Accounts (DHEA) distribute the NBSA household sector across households, using the SFS. [Table 36-10-0660-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=3610066001) gives, among other things, the share of net worth held by each wealth quintile of households, in the fourth quarter of each year from 2010 to 2019 and in every quarter from 2020 Q1 to 2025 Q4. The methodology is described in Statistics Canada (2026), *Distributions of Household Economic Accounts, estimates of asset, liability and net worth distributions, 2010 to 2025, technical methodology and quality report*, catalogue no. 13-604-M2026001.

These data are located in `data/dhea`. The CSV is too large for this repository, so unzip `data/dhea/36100660-eng.zip` to recreate `data/dhea/36100660.csv`.

## Forbes World's Billionaires

Forbes' annual World's Billionaires list estimates the net worth of every person it finds with at least US$1 billion. `data/forbes/forbes_canada_<year>_cad.csv` holds the entries with Canadian citizenship for 2012, 2016, 2019 and 2023, with net worth (`net_worth`) in billions of Canadian dollars.

The lists were built outside this repository from the Forbes lists:

- **Conversion to CAD.** Net worth is converted at the Bank of Canada USD/CAD rate on the date Forbes valued each list: 0.9991 (2012-02-14), 1.3835 (2016-02-12), 1.3270 (2019-02-08) and 1.3807 (2023-03-10). For 2012 and 2016, this is the legacy noon rate, since the single daily rate starts in 2017. The 2012 to 2019 files were produced by a script, and the 2023 file by hand, with the same rules.
- **Relatives combined.** Relatives that Forbes lists separately are combined into one row: the Irving family (James and Arthur; James only in 2012), and in 2023 also the Saputo, Zekelman and Azrieli families. Amounts are summed in USD before conversion.
- **All citizens kept.** Every Forbes entry with Canadian citizenship is kept, including Canadians living abroad and Nathaniel Rothschild (2012), who appears to be miscoded as Canadian.

## Canadian Business Rich 100

Canadian Business magazine published an annual list of the 100 richest Canadians, individuals and families, from 1999 until November 2017, with each edition titled with the following year. Maclean's revived the list in November 2024. There is therefore no list for 2019 or 2023.

- `data/cb_macleans/cb_canada_<year>_cad.csv` holds the editions published in 2012 and 2016, from the Internet Archive copies of canadianbusiness.com, with net worth (`net_worth`) in billions of Canadian dollars. 2012 is the 14th annual list, published 22 November 2012 (full ranking posted online in December 2013, with exact dollar figures, rounded here to $1 million). 2016 is the 18th annual list, titled "2017", published 7 December 2016. Names are as published, including family entries.
- `data/cb_macleans_forbes/cb_macleans_forbes_canada_<year>_cad.csv` merges each Canadian Business list with the Forbes list of the same year: `net_worth_cb`, `net_worth_forbes` and their average `net_worth_avg`, which equals the one available value for families on only one list. Exact name matches were combined, and every similar-name pair was reviewed by hand and combined (2012: Thomson, Irving, Pattison, Desmarais, Sherman, Saputo, Riddell, Wilson, Edwards, Schwartz; 2016: Thomson, Irving, Sherman, Pattison, Saputo, Wilson, Schwartz, Laliberté), under the Forbes name. In several pairs Canadian Business counts a family or couple and Forbes one person (Thomson, Saputo, Schwartz and Reisman, Irving). The merged lists have 101 entries (2012) and 102 (2016).

# Wealth Inequality: SFS PUMF

`sfs.jl` takes the raw SFS PUMF data and produces `output/sfs_wealth_inequality.csv` and `output/sfs_wealth_summary.csv`.

For 2012, 2016, 2019 and 2023, it computes the top 0.01%, 0.1%, 1%, 5%, 10%, 20% and 50% wealth shares and the Gini coefficient of net worth across families , weighted by the survey weights. Standard errors use the 1,000 bootstrap weights, which are available for 2016 onward only. Shares for the top 0.1% and above rest on very few survey records and should be read with caution.

# Wealth Inequality: SFS PUMF + NBSA

`sfs_nbsa.jl` takes the raw SFS PUMF data and aligns it with the NBSA, following Appendix A.1 of PBO (2020), *Estimating the Top Tail of the Family Wealth Distribution in Canada*. It produces `output/sfs_nbsa_aligned.csv` (the aligned family-level data), `output/sfs_nbsa_alignment.csv` (SFS and NBSA totals and adjustment factors), `output/sfs_nbsa_wealth_inequality.csv` and `output/sfs_nbsa_wealth_summary.csv`.

Each family's assets and debts are grouped into financial assets (including employer pensions on a termination basis and business equity), non-financial assets and debts. Each category is then scaled by an adjustment factor, NBSA total ÷ SFS weighted total, so that the SFS totals match the NBSA household sector (market value). The survey years are matched to the NBSA at Q4 for 2012, 2016 and 2019, and at Q2 for 2023, following each survey's collection period. Wealth shares, Gini and standard errors are computed as in `sfs.jl`, with the adjustment factors recomputed for each bootstrap replicate.

The 2016 SFS totals match PBO's Table A1-1, but the adjustment factors differ from PBO's because the NBSA has since been revised. See `notes/other_nonfinancial_assets_2023.md` for a break in other non-financial assets in 2023.

# Wealth Inequality: SFS PUMF + NBSA + Rich Lists


`sfs_nbsa_forbes.jl` adds the Forbes list and a Pareto top tail to the NBSA-aligned SFS, following Appendices A.2 to A.4 of PBO (2020). It produces:

- `output/sfs_nbsa_forbes_integrated.csv`: the integrated family-level data (SFS, synthetic and Forbes families).
- `output/sfs_nbsa_forbes_tail.csv`: the Pareto threshold, α and convergence for each year.
- `output/sfs_nbsa_forbes_calibration.csv`: the adjustment factors, in the format of PBO's Table A4-1.
- `output/sfs_nbsa_forbes_wealth_inequality.csv` and `output/sfs_nbsa_forbes_wealth_summary.csv`.

The procedure for each year:

1. **Align.** Align the SFS with the NBSA as in `sfs_nbsa.jl`.
2. **Add Forbes.** Add each Forbes entry as one family with a weight of 1.
3. **Fit the Pareto tail.** Fit a Pareto distribution to the families at or above a threshold, w_min, using the modified OLS regression of Vermeulen (2018): ln((i − 0.5) N̄ᵢ / N̄) = c + α (ln w_min − ln wᵢ). w_min is PBO's $3 million for 2016, held constant in 2016 dollars with the CPI (Table 18-10-0005-01). This gives $2.84M (2012), $3.00M (2016), $3.18M (2019) and $3.67M (2023), which reproduces PBO's 2023 threshold.
4. **Replace the top of the SFS.** Replace the SFS families at or above w_min with synthetic families, from w_min up to the lowest Forbes entry. The synthetic families sit in 2,000 log-spaced brackets, each holding its Pareto share of the families above w_min at the bracket's Pareto mean wealth. The Forbes entries are kept above the lowest entry. The results do not change with the number of brackets.
5. **Calibrate to the NBSA.** Split the wealth of the synthetic and Forbes families into financial assets, non-financial assets and debts, using the ratios of the aligned SFS families at or above w_min. Revise the three adjustment factors in proportion to the gap between the integrated totals and the NBSA, and repeat steps 1 to 5 until they match.
   - The step is halved whenever the gap stops shrinking, since a full revision can overshoot.
   - A single SFS record crossing w_min can keep the gap from closing completely. The iterate closest to the NBSA is then kept, and a final proportional adjustment of every family, as in PBO, aligns the totals exactly.
   - The point estimates end within 0.02% of the NBSA before that adjustment, and 97.5% of bootstrap replicates within 0.1%.

Standard errors re-run the whole procedure, alignment included, on each of the 1,000 bootstrap replicates, as PBO (2025, Appendix B) does. They do not reflect uncertainty in the Forbes list or the Pareto assumption. In the output, `records_in_group` counts SFS survey records only. The top 1% and above consist entirely of synthetic and Forbes families.

| | 2012 | 2016 | 2019 | 2023 |
|---|---|---|---|---|
| α | 1.558 | 1.494 | 1.492 | 1.457 |
| Forbes entries | 26 | 33 | 44 | 58 |
| Top 0.1% share | 9.9 | 11.5 | 11.9 | 11.9 |
| Top 1% share | 22.7 | 24.7 | 25.7 | 24.9 |
| Top 10% share | 55.9 | 56.0 | 57.4 | 54.5 |

For 2016, PBO (2020) reports α = 1.45, a top 1% share of 25.6% and iterative factors of 0.852, 0.907 and 0.959, against 0.865, 0.916 and 0.964 here. PBO used the Canadian Business list rather than Forbes.

The results are not directly comparable with PBO's other figures, for three reasons:

- **Residency.** PBO drops Canadians living abroad from the rich list, while all Forbes citizens are kept here.
- **Families.** PBO splits family entries into economic families, while relatives are combined here.
- **SFS file.** PBO (2025) uses the full SFS rather than the PUMF.

Keeping non-residents and combining relatives both thicken the tail. For comparison, PBO (2025) reports top 1% shares from SFS + Forbes of 21.9% (2016), 23.4% (2019) and 22.0% (2023), and 24.3% for 2019 when using the PUMF.

The Forbes lists are valued in February or March of each survey year, a few months before the NBSA quarter.

## Forbes + Canadian Business

`sfs_nbsa_forbes_cb.jl` runs the same procedure, with the same code, using the merged Canadian Business and Forbes lists (`net_worth_avg`) for 2012 and 2016, and the Forbes list for 2019 and 2023. It produces the same five files with the prefix `sfs_nbsa_forbes_cb_`; in `sfs_nbsa_forbes_cb_tail.csv` the list columns are named `rich_list_*`, and in the integrated data the list rows have source `Rich list`.

The merged lists reach below the Forbes billionaires, to the 100th Canadian Business entry, $654M in 2012 and $875M in 2016, so the synthetic families stop there, as in PBO (2020), which also used the lowest Canadian Business entry. 2019 and 2023 are identical to `sfs_nbsa_forbes.jl`.

| | 2012 | 2016 |
|---|---|---|
| α | 1.369 | 1.361 |
| List entries | 101 | 102 |
| List total ($B) | 194.8 | 307.3 |
| Top 0.1% share | 13.7 | 14.7 |
| Top 1% share | 27.4 | 28.7 |
| Top 10% share | 58.8 | 58.5 |

The iterative factors for 2016 are 0.814, 0.882 and 0.949. Both α and the top 1% share are further from PBO's 2016 figures (α = 1.45, 25.6%) than with Forbes alone. PBO's cleaned Canadian Business list had 80 resident economic families holding $197B, against 102 entries holding $307B here, since non-residents are kept and families are not split.

# Quarterly Wealth Inequality: SFS PUMF + NBSA

`sfs_nbsa_quarterly.jl` builds a quarterly series from 2012 Q1 to 2026 Q1, harmonizing the SFS PUMF with the quarterly NBSA in the manner of Statistics Canada's DHEA (sections 7 and 8 of the technical report). For each quarter:

1. **Reweight.** Each SFS is carried from its survey quarter to the quarter. The weight of every family grows with the population, in its region, of the age group of its major income earner. The age groups are DHEA's (under 35, 35 to 44, 45 to 54, 55 to 64, and 65 and over), and the regions are the five of the PUMF, making 25 groups. This assumes that the share of people heading a family at each age stays constant. DHEA recalibrates its weights to population totals instead. The PUMF cannot count people by age, since its age variables only flag whether a family has a member in each age group, and family size is top-coded.
2. **Scale.** The reweighted SFS is scaled to the NBSA household sector (market value) of the quarter, in DHEA's six categories:

   | Category | SFS | NBSA |
   |---|---|---|
   | Pensions | employer pension plans, termination basis | life insurance and pensions |
   | Other financial assets | deposits, mutual funds, bonds, stocks, other investments, TFSA, RRSP, RRIF, other pensions, business equity | total financial assets less life insurance and pensions |
   | Real estate | principal residence, other real estate | dwellings, other buildings and structures, land |
   | Other non-financial assets | vehicles, home contents and collectibles | non-financial assets less real estate |
   | Mortgages | mortgages on the principal residence and other property | mortgages |
   | Other debts | credit cards, student loans, vehicle loans, lines of credit, other debt | total financial liabilities less mortgages |

3. **Combine.** A quarter between two surveys pools the two scaled files into one, with the weights of the earlier survey multiplied by 1 − λ and of the later one by λ, where λ is the share of the time between the two survey quarters that has elapsed. For example, 2018 Q2 is half-way between 2016 Q4 and 2019 Q4, so each survey's families count for half. DHEA instead averages the two surveys' estimates; pooling gives one family-level file per quarter, from which every measure is computed. Quarters up to 2012 Q4 use the 2012 SFS alone, and quarters from 2023 Q2 the 2023 SFS alone. The survey quarters are those of `sfs_nbsa.jl`.

Unlike DHEA, the series makes no adjustment for influential records, the institutionalized elderly or the territories, applies no smoothing at the survey quarters, and uses no Equifax or housing market data from 2020 on. Its unit is the economic family, as in the other scripts, rather than the household, since the PUMF has no household identifier. There are no standard errors yet.

It produces:

- `output/sfs_nbsa_quarterly_wealth_inequality.csv`: the top shares and Gini of each quarter.
- `output/sfs_nbsa_quarterly_summary.csv`: the surveys and their weights, number of families, and total, mean and median net worth of each quarter.
- `output/sfs_nbsa_quarterly_alignment.csv`: the reweighted SFS totals, NBSA totals and adjustment factor of each category, for each quarter and survey.
- `output/sfs_nbsa_quarterly_reweighting.csv`: the weighted count of families in each region and age group in the survey and in each quarter.
- `output/sfs_nbsa_quarterly_dhea_quintiles.csv`: the net worth share of each wealth quintile, with DHEA's where published.

`quarter_file` returns the pooled family-level file for a quarter, which the rich-list adjustment will start from.

| | 2012 Q4 | 2016 Q4 | 2019 Q4 | 2020 Q4 | 2021 Q4 | 2023 Q2 | 2026 Q1 |
|---|---|---|---|---|---|---|---|
| Top 1% share | 13.5 | 15.1 | 15.0 | 13.7 | 12.5 | 11.2 | 11.8 |
| Top 10% share | 50.3 | 49.9 | 50.5 | 48.5 | 46.5 | 45.5 | 46.7 |
| Top 20% share | 70.2 | 69.5 | 69.7 | 67.9 | 66.0 | 65.4 | 66.6 |
| Gini | 0.704 | 0.695 | 0.695 | 0.676 | 0.657 | 0.652 | 0.663 |

At the survey quarters, the six categories give top 1% shares 0.1 to 0.6 points higher than the three categories of `sfs_nbsa.jl`, mainly because other debts, which the SFS covers least, get their own adjustment factor of about 2. The highest wealth quintile holds 0.7 to 2.9 points more than in DHEA, as expected with families rather than households, and moves similarly: down from 2020 to 2022 and up after 2023. DHEA's fall in 2020 is sharper, since it uses Equifax and housing data between surveys. Between surveys, most of the change in this series comes from the shift from one survey to the next rather than from the NBSA. Carried to 2023 Q2 on its own, the 2019 SFS gives a top 20% share of 68.7% (69.7% in 2019 Q4) and a top 1% share of 15.0% (unchanged), against 65.4% and 11.2% from the 2023 SFS. On its own, the NBSA moves the top 20% share down by about 2 points from 2019 Q4 to 2021 Q4 and back up by 1.3 points in 2022.

`chart_quarterly.jl` writes `output/wealth_inequality_quarterly.html`, an interactive chart of the quarterly series, with the same measures as the annual chart, and copies it to `docs/quarterly.html`. Run `sfs_nbsa_quarterly.jl` first.
