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

# Wealth Inequality: SFS PUMF

`sfs.jl` takes the raw SFS PUMF data and produces `output/sfs_wealth_inequality.csv` and `output/sfs_wealth_summary.csv`.

For 2012, 2016, 2019 and 2023, it computes the top 0.01%, 0.1%, 1%, 5%, 10%, 20% and 50% wealth shares and the Gini coefficient of net worth across families , weighted by the survey weights. Standard errors use the 1,000 bootstrap weights, which are available for 2016 onward only. Shares for the top 0.1% and above rest on very few survey records and should be read with caution.

# Wealth Inequality: SFS PUMF + NBSA

`sfs_nbsa.jl` takes the raw SFS PUMF data and aligns it with the NBSA, following Appendix A.1 of PBO (2020), *Estimating the Top Tail of the Family Wealth Distribution in Canada*. It produces `output/sfs_nbsa_aligned.csv` (the aligned family-level data), `output/sfs_nbsa_alignment.csv` (SFS and NBSA totals and adjustment factors), `output/sfs_nbsa_wealth_inequality.csv` and `output/sfs_nbsa_wealth_summary.csv`.

Each family's assets and debts are grouped into financial assets (including employer pensions on a termination basis and business equity), non-financial assets and debts. Each category is then scaled by an adjustment factor, NBSA total ÷ SFS weighted total, so that the SFS totals match the NBSA household sector (market value). The survey years are matched to the NBSA at Q4 for 2012, 2016 and 2019, and at Q2 for 2023, following each survey's collection period. Wealth shares, Gini and standard errors are computed as in `sfs.jl`, with the adjustment factors recomputed for each bootstrap replicate.

The 2016 SFS totals match PBO's Table A1-1, but the adjustment factors differ from PBO's because the NBSA has since been revised. See `notes/other_nonfinancial_assets_2023.md` for a break in other non-financial assets in 2023.

# Wealth Inequality: SFS PUMF + NBSA + Rich Lists

