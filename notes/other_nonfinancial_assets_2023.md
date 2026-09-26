# Open issue: jump in "other non-financial assets" in the 2023 SFS

*Written 2026-09-25. Status: left as is for now.*

## The issue

`PWASTONF` (other non-financial assets: contents of the principal residence, collectibles and other non-financial assets) jumps in 2023, while other asset items grow normally.

| | 2012 | 2016 | 2019 | 2023 |
|---|---|---|---|---|
| Weighted total ($B) | 313 | 355 | 405 | 1,011 |
| Share of total assets | 3.3% | 2.9% | 3.0% | 5.3% |
| Median family value | $10,000 | $9,500 | $10,000 | $20,000 |
| 90th percentile family value | $50,000 | $48,000 | $50,000 | $105,000 |
| Families with $500K or more | 0.2% | 0.5% | 0.5% | 2.9% |

## What we know

- **It's in StatCan's internal data, not only the public file.** The 2023 PUMF user guide (Appendix B) gives the internal total as $1,014B.
- **It's not driven by outliers.** Home contents are reported by choosing one of 16 value ranges. The values assigned to the ranges are unchanged since 2012, but in 2023 families picked higher ranges across the whole distribution.
- **The definition and question wording are unchanged.** The 2019 and 2023 user guides describe the variable and the 16-range question the same way. The imputed share of the item's value rose only from 6% to 9.5%.
- **The collection mode changed.** The 2023 SFS was self-completed; earlier cycles were interviewer-administered (CAPI). This is the most plausible cause, but StatCan has not confirmed it. Source: DHEA technical report, section 5.1.
- **StatCan's DHEA leaves collectibles out.** When StatCan aligns the SFS to the NBSA for DHEA, it excludes collectibles because they are outside the NBSA asset boundary (section 5.2.1). PBO (2020, footnote 17) kept them. The PUMF combines collectibles with home contents in `PWASTONF`, so they can't be separated.

## Effect on our results

- **`sfs_nbsa.jl`:** in 2023, SFS non-financial assets exceed the NBSA total. The non-financial adjustment factor is therefore 0.922, against about 0.97 in other years, which scales down homes and real estate too.
- **`sfs.jl` and `sfs_nbsa.jl`:** `PWASTONF` is part of net worth, so it also affects 2023 inequality in both scripts. It is concentrated among richer families (average $144K in the top net worth quintile against $8.5K in the bottom), so it probably raises measured 2023 inequality slightly. This has not been quantified.

## Options when returning to this

1. **Leave as is** (current choice). Faithful to PBO and the published data; document the break.
2. **Exclude `PWASTONF`** from net worth and the alignment in all years. Consistent over time and closer to StatCan's DHEA, but it drops home contents too, not only collectibles.
3. **Test sensitivity first.** Rerun 2023 with `PWASTONF` scaled back to its 2019 share of total assets and compare the top shares and Gini.

Also worth checking: whether StatCan has since published anything on mode effects in the 2023 SFS, and whether the 2025 SFS continues the higher level.

## Sources

- [DHEA technical methodology and quality report, 2010 to 2024](https://www150.statcan.gc.ca/n1/pub/13-604-m/13-604-m2025001-eng.htm)
- [SFS 2023 questionnaire](https://www23.statcan.gc.ca/imdb/p3Instr.pl?Function=assembleInstr&Item_Id=1443668&TET=1)
- PUMF user guides, 2019 and 2023, in `data/sfs_pumf/`
- PBO (2020), *Estimating the top tail of the family wealth distribution in Canada*, Appendix A.1
