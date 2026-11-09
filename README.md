# Washington's plug-in vehicle population, 2010–2026

DSC201 group project (XMUM). One R script, `analysis.R` (submitted as `StudentID.R`), analyses Washington State's electric vehicle title and registration records.

**Question:** how has Washington's plug-in vehicle population grown, aged and spread from 2010 to 2026, and which vehicles stay in it?

## What is in this repository

| Path | Contents |
|---|---|
| `analysis.R` | The whole analysis, in 21 numbered sections |
| `outputs/tables/` | 98 CSV tables written by the script (plus `00_session_info.txt`) |
| `outputs/figures/` | 41 PNG figures written by the script |
| `data/processed/` | Vehicle-year, vehicle-history and sale-event tables saved by the script (`.rds`) |
| `data/raw/` | Small inputs: Census county population, CPI, source metadata and `PROVENANCE.txt`. The main 933 MB CSV is **not** here (see below) |
| `report/report_draft.docx` | Report starter for the team: figures, numbers and notes under the brief's sections I–IV |
| `DECISIONS.md` | Every cleaning and analysis rule, with its reason, and the results log |
| `METHODS_NOTES.md` | Plain-language explanation and a reference for each method |

**Writing the report doesn't require running anything.** Every table and figure is already in `outputs/`, and `report/report_draft.docx` says which to use where.

## Getting the data (only needed to re-run the script)

The main file is 933 MB, too large for GitHub. Ask the team for the shared copy (zipped). Unzip it into `data/raw/` so this path exists:

```
data/raw/Electric_Vehicle_Title_and_Registration_Activity.csv
```

The script checks the file before doing anything else: its SHA-256 must be
`bab70a0914c3f721c6365015adc461a2f8f76c85ae6035ccad750be74f59943b`
and it must have 1,926,507 rows. If either differs, it stops with a message.

**Don't download a fresh copy from the portal.** data.wa.gov always serves the latest version, so a new download won't match the frozen extract (7 November 2026, source updated 14 October 2026). Source details (dataset ID `rpr4-cgyd`, URLs, size, hash) are in the header of `analysis.R` and in `data/raw/PROVENANCE.txt`. Licence: Open Database License (ODbL), Washington State Department of Licensing; the shared copy must keep that attribution.

To check a copy by hand on Windows: `certutil -hashfile data\raw\Electric_Vehicle_Title_and_Registration_Activity.csv SHA256`

## Reviewing the project in RStudio

1. **Install R (4.5 or later) and the packages, once:**
   ```r
   install.packages(c("data.table", "ggplot2", "MASS", "moments", "sandwich",
                      "lmtest", "pROC", "survival", "scales"))
   ```
   (`splines` and `tools` come with R.)
2. **Open `dsc201-asg.Rproj`.** This sets the working directory to the project folder, which the script's relative paths need.
3. **Open `analysis.R` and show the outline** (Ctrl+Shift+O, or the outline button at the top right of the editor). Each `# ---- N. TITLE ----` line is a section; click one to jump to it. Subsections are numbered comments (`# 13.2 ...`), which the report cites.
4. **Run it.**
   - Whole script: Ctrl+Shift+Enter (Source), or from a terminal in the project folder: `Rscript --vanilla analysis.R`.
   - One section at a time: put the cursor in a section and press Ctrl+Alt+T (Run Code Section). Start with section 1 and go in order, because each section uses objects made by earlier ones. To jump ahead, put the cursor at the start of the section you want and press Ctrl+Alt+B (run everything above), then step on with Ctrl+Alt+T.
5. **Time and memory:** a full run takes about 8 minutes on the machine it was built on. R holds about 4–5 GB of objects at the peak, so use a computer with **16 GB of RAM**. With 8 GB it may fail with an out-of-memory error.
6. **What a successful run looks like:** the console prints one line per section and ends with `Finished. All assertions passed.` Every table and figure in `outputs/` is rewritten, and the results are identical to the committed ones (the random seed is fixed).

## Project summary

**Data.** Washington State Department of Licensing, *Electric Vehicle Title and Registration Activity* (data.wa.gov, ID `rpr4-cgyd`): 1,926,507 transaction records (titles, registrations, renewals, transfers) for 401,956 vehicles, 33 columns, January 2010 to September 2026. Each row is one transaction; the population is rebuilt from them. Supporting data: US Census Bureau county population estimates and BLS CPI-U.

**Method in brief.** The records are cleaned (duplicates, hydrogen vehicles, non-Washington addresses, exempt and low-speed classes removed: 1,909,074 rows, 397,023 vehicles). They are turned into one row per vehicle per year (1,349,135 vehicle-years), with entry, exit (no record for two years) and county moves defined for every vehicle. The stock-and-flow identity reconciles exactly, and the counts are cross-checked against independent benchmark figures from the data portal. The course methods are then applied (descriptive statistics, probability models, hypothesis tests, ANOVA, linear and logistic regression), followed by seven extensions.

### Main results and where they are in the code

| # | Result | Code (section) | Main output |
|---|---|---|---|
| 1 | **Size:** 270,098 active vehicles in 2025 (286,478 counting vehicles that skip one year), up from 54,733 in 2019 on the second count | 6, 11.1 | `06_population_flows.csv`, `11_01_active_population.png` |
| 2 | **Spread:** King County's share of vehicles fell 5.5 points from 2019 to 2025 (95% CI 5.0–5.9, p ≈ 10⁻¹¹⁷) | 13.1 | `13_hypothesis_tests.csv`, `11_02_king_share.png` |
| 3 | **Retention:** no difference between BEVs and PHEVs in leaving within two years from 2021 (odds ratio 1.03, p = 0.26). Across 2010–2023 PHEVs left slightly less often (Cox hazard ratio 0.92), but only before 2020 | 13.2, 17, 17.1 | `13_hypothesis_tests.csv`, `17_retention_by_period.csv` |
| 4 | **Exit model:** test AUC 0.52 with the base predictors, 0.57 with vehicle history (DeLong p ≈ 10⁻⁷⁶). It stays weak, because the causes of leaving aren't in the records | 14.4–14.7 | `14_logistic_performance.csv`, `14_06_logistic_roc.png` |
| 5 | **County growth by size (one-way ANOVA):** not significant (classic p = 0.074, chosen by the assumption checks; Welch 0.032 and Kruskal–Wallis 0.045 as sensitivity checks) | 13.10 | `13_anova_oneway_primary.csv`, `13_01_anova_growth_by_size.png` |
| 6 | **BEV share over time (repeated-measures ANOVA):** rose at every step, from 56% (2019) to 74% (2025), averaged over counties (Greenhouse–Geisser p ≈ 10⁻¹⁴) | 13.12 | `13_anova_repeated_measures.csv`, `13_03_rm_anova_bev_share.png` |
| 7 | **East and west (mixed ANOVA):** Eastern counties started lower and caught up (51% against 61% in 2019, 73% against 75% in 2025; interaction p = 0.002) | 13.13 | `13_anova_mixed.csv`, `13_04_mixed_anova_bev_share.png` |
| 8 | **Per resident:** 33.8 vehicles per 1,000 residents in the state, 57.2 in King, 24.0 elsewhere. King has 49.7% of vehicles and 29.3% of residents | 19 | `19_ev_per_1000_state.csv`, `19_01_ev_per_1000_2025.png` |
| 9 | **Used prices:** about 11.4% lower for each year of age | 15.4 | `15_index_comparison.csv`, `15_01_used_price_index.png` |
| 10 | **Movement:** in a year with a title transfer, 37.1% of King vehicles left the county, against 2.1% without one | 16 | `16_leaving_king_by_transfer.csv`, `16_01_king_moves.png` |
| 11 | **Survival:** at age 5, 72% of BEVs and 74% of PHEVs are still in the records | 17 | `17_survival_by_age.csv`, `17_01_survival_by_type.png` |
| 12 | **Range:** no evidence that electric range is associated with leaving (odds ratio 0.94 per 100 miles, p = 0.38) | 18 | `18_range_and_exit.csv` |
| 13 | **Projection:** about 444,000 active vehicles in 2028 (95% interval 331,000–714,000); the high scenario gives about 593,000 | 20 | `20_projection_2026_2028.csv`, `20_01_projection.png` |
| 14 | **Backtest:** with the actual entries, the projection is within 1% of the actual 2023–2025 counts. With projected entries it was 30% low in 2025 (entries jumped in 2023), yet the 80% intervals contained the actual counts | 20.3 | `20_projection_backtest.csv` |
| 15 | **Early 2026:** January–September entries are 11.8% below the same months of 2025 | 20.4 | `20_check_2026_entries.csv` |
| 16 | **Districts:** the five largest legislative districts' share fell from 31% to 26% (2019–2025); district 41 has about 102 vehicles per 1,000 residents, district 15 about 5 | 21.3 | `21_district_spread.csv`, `21_01_districts_per_1000.png` |
| 17 | **Utility territories:** the Puget Sound Energy, Seattle and Tacoma territories hold 73% of vehicles | 21.4 | `21_utility_territories.csv` |

**Wording used throughout:** results are associations, not causes. A vehicle that "left the records" has no Washington record for two years; it may have moved out of state or gone off the road, and the records can't tell which.

**Limits.** Exits can only be seen up to 2023 (two later years are needed). The 2025 count is slightly provisional, and 2026 is partial (to September). Records describe vehicles, not owners or charging.
