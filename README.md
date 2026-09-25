# Overview

This repository contains the data and code for calculating wealth inequality in Canada.

# Data

All raw data are located in `data`. 

## Survey of Financial Security: Public Use Microdata File

The Survey of Financial Security (SFS) is a cross-sectional household survey focussed on wealth and income. It is conducted by Statistics Canada every few years: 1999, 2005, 2012, 2016, 2019, and 2023. 

The Public Use Microdata File (PUMF) is a subset of the data which is publicly available. 

These data are located in `data/sfs_pumf`. The boostrap weights for 2016, 2019, and 2023 are not included in this repository because they are too large, but they can easily downloaded from [here](https://www150.statcan.gc.ca/n1/pub/13m0006x/13m0006x2021001-eng.htm).

# Wealth Inequality: SFS PUMF

`sfs.jl` takes the raw SFS PUMF data and produces `output/sfs_wealth_inequality.csv` and `output/sfs_wealth_summary.csv`.

For 2012, 2016, 2019 and 2023, it computes the top 0.01%, 0.1%, 1%, 5%, 10%, 20% and 50% wealth shares and the Gini coefficient of net worth across families , weighted by the survey weights. Standard errors use the 1,000 bootstrap weights, which are available for 2016 onward only. Shares for the top 0.1% and above rest on very few survey records and should be read with caution.

# Wealth Inequality: SFS PUMF + NBSA

# Wealth Inequality: SFS PUMF + NBSA + Rich Lists