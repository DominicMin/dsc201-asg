# Review changes

## 1. `report/report.tex`

### 1.1 Factual and definitional errors

| Location | Reason | Change |
|---|---|---|
| Abstract; 4.1; 4.2 (State revenue) | "7–7.5% leave the records within two years" reads as a two-year cumulative rate. By definition (active in year t, no record in t+1 or t+2) it is an annual exit rate, e.g. 3,615 / 52,710 = 6.86% for 2019 | "leave the records each year (no record in the following two years)"; 4.2 now says "an annual exit rate of about 7%" |
| 3.2 main retention test; 3.4 logistic question | Same wording problem in the logistic outcome | "leave within two years" → "have no record in the next two years" |
| Abstract; 3.5 Extension 6 | The projection uses the gap-filled count but was set beside the simple count (270,098) | Added "on the gap-filled count (286,478 in 2025)" |
| Figure 1 caption; 2.5 | The stock-and-flow identity holds only on the gap-filled count (2019→2020: 54,733 + 15,492 + 98 − 3,615 = 66,708) | Caption adds "on the gap-filled count"; 2.5 says "the gap-filled stock" |
| Table 2 (2025 row), its note, 1.2 text | 95,537 is flagged "Not exits: only partial 2026 seen" in `06_population_flows.csv`; it is not a leaver count | 2025 cell set to "---"; note and text say the 2024 count is provisional and a 2025 count needs 2026 and 2027 records |
| 2.5 limitations; 4.3 | "The 2025 count is slightly provisional" names the wrong figure. 270,098 uses only 2025 records; the gap-filled 286,478 and the 2024 leaver count depend on partial 2026 data | Changed to "the 2025 gap-filled count and the 2024 leaver count are provisional" |
| Figure 16 caption (`12_02`) | The figure shows exits among 100 vehicles at p = 0.069, not the 2013 cohort | Caption rewritten to describe the figure |
| Figure 17 caption (`12_03`); 3.1 text | The figure has three model-year panels only (code drops "All cars"); the sample is cars with at least one priced sale | Caption: "in three model-year cohorts"; text adds "among cars with at least one priced sale" |
| Table 12 note | Said "Model A is the main model", but `final_model` is B (lower training AIC) and the headline AUC 0.57 is B's | "Model B, with the lower training AIC, is the final model; model A gives the interpretable odds ratios" |
| 3.5 Extension 4 | A Schoenfeld test checks proportional hazards, not "constant hazard" | "a Schoenfeld residual test rejects the proportional-hazards assumption (p = 0.024): the PHEV effect is not constant, so 0.92 is an average over periods" |
| Table 8 column header | Header "Adjusted exit" sat over Cohen's h values | Renamed "Effect size" |
| 3.1 Poisson | The Pearson dispersion 9,627 is driven by one 2010 week with a near-zero fitted value, so it is an artefact | Removed the 9,627 figure (coverage 37% and AIC remain as evidence); "the appropriate model" → "the better model, although some overdispersion remains (Pearson dispersion 4.4)" |
| 3.3 two-way ANOVA | Cells are very unbalanced and sums of squares are sequential. Entering side first reverses the main effects (side p = 0.013, size p = 0.34); only the interaction is unchanged | Removed "size is significant and side is not"; now states that size and side are confounded (11 of 13 large counties are western), main effects depend on order, only the interaction (F = 4.57, p = 0.018) is interpreted; cells 2 to 11 counties |
| 3.5 Extension 6 | The backtest reported only the Level rule (−30%), not Trend (+2%); the choice of Level was not justified; the sales-tax exemption appeared only in the conclusion | Backtest now gives both rules and notes both 80% intervals contain the actual counts; added the reason for Level (flat 2024–2025 entries, exemption ended 31 July 2025); 2026 check adds "implying about 66,000 for the year, below Level's 72,000" |
| 1.4 | Figure `11_05` has the ten largest makes only, no "Other" bar | "the ten largest makes covered 81.9% of the population" |
| 1.4 | `outputs/tables/10_02`–`10_04` do not exist (those are figure files) | Path changed to `outputs/tables/10_freq_*.csv` |
| 1.3; 3.4 multiple regression | "used share of 2019 titles" does not match the code, which uses the share of 2019 active vehicles that did not enter as new | Changed to "the share of the 2019 stock that did not enter as new" |
| 3.4 price model | "This model is the basis for the used-price index" is wrong; the index comes from the 15.4 hedonic model with sale-year terms | "A related hedonic model with sale-year terms gives the used-price index in Section 3.5 of this report" |
| 2.4 | "no age or mileage outliers are removed" is wrong: the mileage sample drops 54 falling and 11 over-400,000 readings | "no age or price-tail outliers are removed … the mileage sample excludes 54 readings that fell and 11 above 400,000 miles" |
| 1.1; 2.4 | "only a minority of BEVs after model year 2020" understates it (4.4% in 2021, about 0% after) | "almost never recorded for BEVs of model year 2021 or later" |
| 2.3 | "23 same-day conflicting prices" are 23 vehicle-dates (46 rows), and 34 repeat rows were merged (the 80-row drop in Table 7) | Text now gives both counts |
| 1.3 correlation | "weak" ignores log stock vs BEV share (r = 0.56); "Pearson and Spearman agree in sign and magnitude" is false for some pairs (−0.13 vs −0.31) | "weak to moderate" with the 0.56 pair; sentence replaced by "agree in sign for every pair" |

### 1.2 Conclusions stronger than the results

| Location | Reason | Change |
|---|---|---|
| Abstract; 3.2; 3.4; 3.5 Ext. 4; 4.1; 4.2 | "statistically indistinguishable / same rate / stay equally long" treats non-rejection as equality; model A (adds make, region, etc.) gives PHEV OR 0.81 (0.74–0.89) | "no significant difference after adjusting for age (OR 1.03, 95% CI 0.97–1.10)"; 4.1 adds "with make and the other predictors also held fixed, PHEVs leave somewhat less often (OR 0.81)"; 4.2 "no clear difference in retention"; Ext. 4 "consistent with the main test"; 3.4 "after adjusting for make and the other predictors" |
| Abstract; 3.4; 4.1 | Transfer, region and use-class associations come from the 2021 baseline; in the 2019 fit transfer and region ORs are near 1 | Prefixed "In the 2021 baseline"; 3.4 adds one sentence on the 2019 sensitivity fit |
| 3.4 multiple regression and diagnostics | HC3 sentence implied HC3 changes R²; no predictor is significant at 5%; influential points are four tiny counties; the diagnostic plots are for the simple model | Rewritten: R² 0.26, no predictor significant with HC3; names Wahkiakum, Garfield, Columbia, Adams (1–11 vehicles in 2019); captions of Figures 23–25 say "simple county regression" |
| 3.4 decision boundary (text, Figure 28 caption) | The boundary comes from a two-predictor model (age, tenure) at the 7.5% training exit rate, not the main model at 0.5 | Caption and text say so; 0.5 cut-off sentence adds "because only 7.5% leave" |
| 3.5 Extension 4 | The period split skipped 2019–2021 (HR 1.04, p = 0.049) | "1.04 and 1.03 for 2019–2021 and 2021–2023" |
| 3.2; 4.1 | "historical difference before 2020" is loose: the 2019 baseline's outcome years are 2020–21 | "a difference in the 2019 and earlier baselines" |
| 3.5 Extension 5 | "range does not explain retention" overstates a null result | Final sentence removed; "no evidence that range is associated with leaving in this population" |

### 1.3 Items required by the brief

| Location | Reason | Change |
|---|---|---|
| 3.4 | The brief lists "Multiple Regression Equation" | Added fitted equations for the simple and multiple county regressions (natural logs; shares as proportions) |
| 1.3 | The brief asks to interpret variance and mode | Added "variance 9.05" and one sentence on the mode |
| 3.2 | Significance level not stated | Added "α = 0.05; Bonferroni threshold 0.05/9 ≈ 0.0056" |
| 3.3 repeated-measures ANOVA | County count, weighting and post hoc results not stated | Added "35 counties with 10+ vehicles in 2019; unweighted county means" and "all three Bonferroni pairwise comparisons are significant" |
| 3.4 logistic | The claim that weak prediction is not due to label noise had no support in the report | One sentence citing `14_logistic_label_noise_check.csv` (AUC 0.563→0.555, 0.612→0.606) |
| 3.3 one-way ANOVA | Size class undefined | "thirds of the 2019 stock, 13 counties each" |
| 3.2 | Second z test omitted the 2019 rate | Added "6.86%" |
| 3.1 CLT | Number of replicates not stated | "2,000 samples of size n" |

### 1.4 Wording and layout

| Location | Reason | Change |
|---|---|---|
| Table 4 (frequency table) | It sat in 2.5 Verification after an unrelated sentence | Moved to the end of 1.4 (after Figure 12) and cited from the 1.4 text; the sentence in 2.5 removed |
| Table 6 (rule effects) | After the move, Tables 5 and 6 fell onto a float page with a large gap | Table 6 defined one paragraph later (after the first paragraph of 2.3); no gaps remain, tables are numbered in order |
| Table 7 note; 3.2 | "section 3.4" (report) and R-script section numbers mixed in one sentence | "Section 3.4 of this report" |
| Table 2 | Inconsistent decimals (66, 78; 0.5, 2.9) | 66.0, 78.0, 0.50, 2.90 |
| 3.5 Extension 7 | "PSE, Seattle and Tacoma territories hold 73%" is ambiguous (labels overlap) | "The three largest territory labels (Puget Sound Energy, Seattle and Tacoma) hold 73%" |
| 1.3 | Price kurtosis not marked as raw | "raw kurtosis 10.25" |
| 3.5 Extension 7 | District rates assume equal populations | Added "(assuming equal district populations)" |
| 3.1 | The zero-week sentence read as both models fitting equally | "39 zero weeks, against 38 expected under the negative binomial and 45 under the Poisson" |
| Contribution table | Mixed tense and capitals after semicolons | Past tense, lower case after semicolons |

## 2. `analysis.R` and figures

| Location | Reason | Change |
|---|---|---|
| `table_png()` (10.0) | Titles and source notes cut off at the right edge; one-decimal values shown with two decimals (97.50); `NA` printed | Width also accounts for title and note length; decimals follow the data (one decimal where all values have one); missing values shown as "–" (written `"–"`) |
| 10.2 `10_04` call | Years printed as "2,010" | Year column converted to text for the PNG only |
| 10.4 `10_05` call | Raw lower-case column names | Readable column names (Measure, Mean, SD, …) |
| 11.5 `11_05` | Right-most axis label "125,000" cut off | Wider right plot margin |
| 11.6 `11_06` | Source note cut off | Width 5.5 → 7 in |
| 11.10 `11_10` | King drawn twice (grey jitter and orange point) | Jitter excludes King |
| 14.1 `14_01` | "Wahkiakum" label cut off at the top | Extra space above the y range |
| `outputs/figures/` | Regenerated by a full run of `analysis.R` (R 4.6.1; all assertions passed) | Updated `10_01`–`10_05`, `11_05`, `11_06`, `11_10`, `14_01`. All CSVs matched the committed versions within 1e-8 relative difference, so tables, `.rds` files and the other figures were kept as committed |

## 3. Supporting documents

| File | Reason | Change |
|---|---|---|
| `DECISIONS.md` | Bonferroni count disagreed with code and report (7 vs 9); same wording and number issues as the report | "0.05 / 9"; "no significant difference" (3 places); Poisson dispersion 9,627 removed; two-way ANOVA "2 to 11 counties" with the order dependence and both p values |
| `METHODS_NOTES.md` | Same issues | Poisson "dispersion about 9,600" removed; two-way ANOVA "2 to 11" and order dependence; Cook's distance names the four small counties; two Cox sentences toned down |
| `README.md` | Same issues; page count changed | Results 3 and 17 reworded; Limits sentence on provisional counts; "36 numbered pages" |

## 4. Other files

| File | Change |
|---|---|
| `data/raw/Electric_Vehicle_Title_and_Registration_Activity.csv` | Moved from the project root (git-ignored; SHA-256 matches `PROVENANCE.txt`) |
| `data/raw/PROVENANCE.txt` | Root copy was identical; merged |
| `report/report.pdf`, `report/report.synctex.gz` | Recompiled with `latexmk -xelatex -synctex=1`: no errors, no overfull boxes, 36 body pages |
