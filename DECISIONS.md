# Decisions and results

This document records every rule in `analysis.R`, the reason for it, its effect, and the results it produces. Section numbers refer to `analysis.R`. Tables are in `outputs/tables/` and figures in `outputs/figures/`. Plain-language explanations and references for each method are in `METHODS_NOTES.md`.

**How the rules were set.** Benchmark figures for the dataset had been computed before the script was written, so some results were known in advance. Each rule is therefore chosen for a reason about the data, not for its effect on a result, and `09_rule_effects.csv` shows how much each rule changes the headline numbers.

**Status.** All 21 sections run from scratch with every assertion passing.

## 0. Coverage of the assignment brief

| Brief item | Section | Output |
|---|---|---|
| Cleaning: missing values, duplicates, outliers, inconsistencies, noisy records | 2–3, 7 | `02_data_dictionary.csv`, `09_flow_table.csv`, `09_rule_effects.csv`, `07_price_flow.csv` |
| Feature extraction | 4–6, 14.5 | Active, entry route, exit, moves, age (`06_population_flows.csv`, `05_entry_route_by_year.csv`); history features for the logistic model |
| Standardising variables | 10.3, 19.4 | z-scores in `10_county_measures.csv`, `19_rate_2019_2025.csv` |
| Mean, median, mode | 10.4 | `10_descriptives.csv`, `10_05_table_descriptives.png` |
| z-scores | 10.3 | `10_county_measures.csv` (counties beyond ±2 are labelled in `11_11`) |
| Variance and standard deviation (plus IQR) | 10.4 | `10_descriptives.csv` |
| Covariance; Pearson, Spearman and Kendall correlation | 10.5, 19.4 | `10_correlations.csv`, `19_rate_correlations.csv` |
| Skewness and kurtosis | 10.4 | `10_descriptives.csv` |
| Frequency tables | 10.2 | `10_01` to `10_04` PNGs and CSVs |
| Pie chart; bar charts | 11.6; 11.4, 11.5, 19.2 | `11_06`; `11_04`, `11_05`, `19_01` |
| Boxplots | 11.9, 11.10, 13.10 | `11_09`, `11_10`, `13_01` |
| Histograms | 11.7, 11.8, 12.4 | `11_07`, `11_08`, `12_04` |
| Line graphs (change over time) | 11.1–11.3, 15.4, 16, 19.2 | `11_01`–`11_03`, `15_01`, `16_01`, `19_02` |
| Scatterplots | 11.11, 14.9 | `11_11`, `14_07` |
| Separation of the two outcome groups | 14.6, 14.9 | `14_08_logistic_class_separation.png`, `14_07_decision_boundary.png` |
| Every figure as a labelled PNG | 10.0 | 41 PNGs, each with title, axis units, source and n |
| Discrete process | 12.1, 12.3 | Poisson against negative binomial (`12_weekly_entry_models.csv`, `12_01`); geometric (`12_03`) |
| Discrete to normal | 12.2 | `12_binomial_normal_approximation.csv`, `12_02` |
| Sampling distribution of the mean | 12.4 | `12_clt_summary.csv`, `12_04` |
| One-sample z-test | 13.3, 13.4 | `13_hypothesis_tests.csv` |
| One-sample t-test | 13.5 | `13_hypothesis_tests.csv` |
| Paired t-test | 13.6 | `13_hypothesis_tests.csv` |
| Two-sample t-test | 13.7, 13.8 | `13_hypothesis_tests.csv` |
| Tests of feature separation, p-values and assumptions | 13.8–13.13 | Chi-square, ANOVA assumption tables, effect sizes |
| Simple regression | 14.1 | `14_county_regressions.csv`, `14_01`–`14_03` diagnostics |
| Multiple regression | 14.2, 14.3 | `14_county_regressions.csv`, `14_county_vif.csv`, `14_specification_model.csv` |
| Logistic regression | 14.4–14.9 | `14_logistic_*.csv`, `14_05`–`14_08` |
| Confidence and prediction intervals | 14.1, 14.3, 14.8 | `14_county_intervals.csv`, `14_specification_reference_car.csv`, `14_logistic_example_predictions.csv` |
| Decision boundary and logit linearity | 14.4, 14.9 | `14_logistic_linearity.csv`, `14_07` |
| **Additional:** ANOVA (one-way, two-way, repeated-measures, mixed) | 13.9–13.13 | `13_anova_*.csv`, `13_01`–`13_04` |
| **Additional:** McFadden's R², variable importance, VIF, optimal cut-off, confusion matrix, calibration | 14.6 | `14_logistic_performance.csv`, `14_logistic_importance_*.csv`, `14_logistic_gvif.csv`, `14_logistic_confusion_test.csv`, `14_logistic_calibration.csv` |
| **Additional:** extensions 1–5 | 15–19 | `15_*` to `19_*` |
| **Additional:** extension 6, population projection with backtest | 20 | `20_projection_*.csv`, `20_check_2026_entries.csv`, `20_01` |
| **Additional:** extension 7, legislative districts and utility territories | 21 | `21_districts.csv`, `21_district_spread.csv`, `21_utility_territories.csv`, `21_01` |

## 1. Rules for the study population (section 3)

| Rule | Reason | Effect |
|---|---|---|
| Remove exact duplicate rows | All 33 columns are the same, so the row adds nothing | 76 rows, no vehicles lost |
| Remove hydrogen vehicles | They are not plug-in vehicles | 21 vehicles, 50 rows |
| Keep Washington addresses with a county | The question is about vehicles in Washington, and spread needs a county | 8,233 rows, 679 vehicles |
| Remove exempt classes (state, local, tribal, federal, farm exempt) | **They have no annual renewal.** 98% of them look like exits, so exit cannot be measured | 8,790 rows, 4,174 vehicles |
| Remove low-speed and off-road classes | They are not general road vehicles | 284 rows, 59 vehicles |
| Keep Truck and Commercial classes | Passenger-only would drop mainstream pickups such as the F-150 Lightning, R1T and Cybertruck. Their exit rates match Passenger (7.4% against 7.4%, 2023 baseline) | Passenger-only would remove 10,306 active vehicles in 2025 |
| Keep model years before 2008 | They are genuine early EVs, such as the Ford Ranger EV | About 60 vehicles kept |
| Floor age at 0 | A car can be sold in the year before its model year | Affects only the age measure |

The rules apply to rows, so a state fleet car joins the population when it is first registered in a kept class.

**Result:** 1,909,074 rows and 397,023 vehicles. Active vehicles in 2025 fall from 271,957 to 270,098. King's 2025 share moves from 49.47% to 49.67%.

## 2. Population definitions (sections 4 to 6)

| Term | Rule | Reason |
|---|---|---|
| County in a year | The county on the vehicle's last record of that year | Places a vehicle where it was at year end, so county totals equal the state total. 13,677 vehicle-years had two or more counties |
| Active (simple) | At least one record that year | The direct reading of the records |
| Active (gap-filled) | A record that year, or records in the years either side | Two missing years count as an exit, so one missing year is the most a vehicle can miss and stay active |
| Entry | First record in the study rows | The vehicle's first appearance in Washington |
| Entry route | Label of the first Original Title, including one up to a year after the first registration | Registration rows always say Used, so they cannot show whether a car was new |
| Exit | Active in the baseline year, with no record in the next two calendar years | One missing year is common with late renewals; two rarely reverse (section 4). Baselines stop at 2023 |
| Return | Active again after an exit | Needed for stock and flow to add up |
| Move | County differs between consecutive vehicle-years | Uses the year-end county defined above |

**Stock and flow:** next year's gap-filled count equals this year's, plus entries and returns, minus leavers. This holds exactly in every year, and every leaver is exactly a two-year exit. The script stops if either check fails.

## 3. Price rules (section 7)

| Rule | Reason | Effect |
|---|---|---|
| Use title rows only | Registration rows have no price | 483,815 rows |
| Treat 0 as missing | The source defines it that way | 55,056 rows |
| Remove prices whose digits are the sale date | These are entry errors, such as $62,720 on 27/06/2020 | 17 rows, 11 inside $1,000–$300,000 |
| Keep $1,000–$300,000 | The 13,296 rows from $100,000 to $299,999 are mostly new premium EVs, so they are plausible. Only 268 rows are at or above $300,000 | 427,500 rows |
| Set aside same-day price conflicts, and merge repeats of the same sale | Neither conflicting price can be trusted, and a repeat is not a second sale | 23 vehicle-dates (46 rows) set aside, 34 repeat rows merged |
| Date prices by sale year | The sale date is when the price was agreed | Mean used price 2022: $41,174 by sale year, $40,701 by transaction year |
| Express real prices in September 2026 dollars | The latest month with CPI | Not a filter |
| Exclude October 2025 from real prices | BLS published no CPI for that month | 4,199 sale events |
| Mileage sample: Actual Mileage, above 0, not falling, up to 400,000 | Readings outside this are not reliable | 54 falling and 11 too-high readings among 144,240 used sales |

## 4. Data findings that affect the analysis

**2025 is undercounted more than other years.** This matters because 2025 is a headline year.
- The gap-filled count adds 6.1% to the simple count in 2025, against 4.0–4.7% in 2020–2024.
- Registrations followed by a renewal after 300–430 days fell from 76.1% (second half of 2023) to 71.9% (second half of 2024). Late renewals rose from 6.9% to 9.4%.
- No month is missing, so this looks like late renewal, not lost records. The data cannot say why.
- Growth from 2024 to 2025 is 20.5% on the simple count and 22.7% gap-filled, so both counts are reported.
- **The spread result is not affected.** King's share falls from 55.15% to 49.67% on the simple count, and from 55.12% to 49.72% gap-filled.

**The exit rule becomes less accurate in later years.** Exits that return in the very next year rose from 2.9% (2017 baseline) to 9.2% (2019) and 12.0% (2022). The logistic model trains on 2021 and tests on 2023, so part of any shift between them may come from this rather than from vehicles behaving differently. A three-year rule gives slightly lower exit rates (6.2% against 6.9% for 2019), and 8.0% of those exits still return.

**Spring 2024 title delay.** 4,205 new cars first appear as an Original Registration in 2024, with their title a median of 70 days later. Without the entry-route rule they would all count as used. The data does not say why this happened.

**Meanings that are inferred.**
- The source says transaction types are "defined by Department of Licensing" and gives no list. Their meanings here are inferred from `02_transaction_types.csv`.
- "Used, registration only" covers 10,596 vehicles, which have no Original Title. The wording stays neutral because the cause is not known.

**Electric range.** Range is recorded for almost every PHEV through 2026, but for BEVs it falls to 4.4% in model year 2021 and about 0% after. From 2021 a recorded range therefore almost identifies a PHEV, which is one reason it is kept out of the main logistic model.

## 5. Verification (section 9)

- **Stock and flow** reconcile exactly in every year (9.1), and county totals equal the state total (9.2).
- **Independent benchmark cross-check (9.4).** 70 benchmark figures, computed separately from the data portal before the script was written, are recomputed on their own basis (`09_benchmark_cross_check.csv`). 66 match exactly or to rounding. The other 4 are explained below.

| Check | Benchmark | R | Explanation |
|---|---|---|---|
| Cars with one title sale | 311,874 | 311,900 | Difference under 0.01% |
| Cars with two title sales | 46,854 | 46,856 | Difference under 0.01% |
| Used sales in the specification model | 143,404 | 141,153 | October 2025 has no CPI, so those sales drop out. Before that step, the mileage sample has 143,527 |
| R-squared of the specification model | 0.62 | 0.674 | The project model uses real prices and every make with 100+ sales. A nominal-price, top-10-makes form gives 0.619, which is probably the benchmark's specification |

Several exact matches required the benchmark's own conventions, which the project does not follow: it kept hydrogen in some counts, dated prices by transaction year, left Garfield out of the county BEV test, and excluded the end values of $100,000 to $1,000,000.

- **Independent recount:** a separate Python recount of the raw CSV, using the same rules, matched R on active vehicles for 2019, 2022, 2025 and 2026, and on all ten vehicle histories in `09_hand_check_vehicles.csv`.

## 6. Rules for the analysis (sections 10 to 21)

**Descriptive statistics, probability and tests**

| Rule | Reason |
|---|---|
| Regions: King alone, the 20 counties east of the Cascade crest as Eastern Washington, the other 18 as Western | A standard split. King holds about half the vehicles, so it is kept separate |
| County starting values are from 2019 | 2019 is the spread test's baseline |
| County used share is the share of the 2019 stock that did not enter as new | Starting composition, so it cannot be a result of later growth |
| The mode of a continuous measure uses rounded values: price and mileage to 1,000, growth to 0.1 | Exact values rarely repeat, so a raw mode means nothing |
| Kendall's tau for the 141,000 sales uses a random 5,000 | Its run time grows with n². Pearson and Spearman use every sale |
| County shares need 10 or more vehicles in 2019 (paired test; sensitivity for the one-sample test) | With fewer, one vehicle moves the share by 10 points or more. 4 counties are left out |
| Weekly entries: Monday-to-Sunday weeks from 4 January 2010 to 27 September 2026, with a trend spline (17 degrees of freedom, about one a year) and two seasonal waves | Whole weeks only. The negative binomial starts from the Poisson fit |
| Binomial example: model-year 2013 vehicles active in 2021, against the 2019 baseline exit rate | The oldest large cohort, with a rate set before it |
| Geometric example: sale events per car, overall and in model years 2013, 2017 and 2021 | Pooled cohorts can look geometric when single cohorts are not, so both are checked |
| One-sample z-test for a mean uses the 2025 population SD (3.01) as sigma | The full records give it exactly; the 2019 SD (2.23) would understate the spread |
| The main retention test adjusts for age in single years, with 15 and over pooled | Makes no assumption about how risk changes with age |

**ANOVA**

| Rule | Reason |
|---|---|
| Size classes are thirds of the 2019 stock (13 counties each) | Equal groups, set by starting size |
| One-way ANOVA: the primary test follows the assumption checks. Non-normal residuals (Shapiro p < 0.05) → Kruskal–Wallis; normal but unequal variances (Levene p < 0.05) → Welch; both pass → classic ANOVA. The other two are sensitivity checks | Set in the code before the p-values are compared, so it would switch automatically if the data changed |
| Two-way ANOVA uses size class and side of the Cascades (King counts as Western) | Only two sides, so cells keep at least 2 counties. Sums of squares are sequential, so the result is exploratory |
| Repeated-measures and mixed ANOVA use the 35 counties with 10+ vehicles in 2019 | The same rule as the paired t-test |

**Regression**

| Rule | Reason |
|---|---|
| Logistic model trains on 2021 and tests on 2023 | 2021's outcome years (2022–23) end before the test's (2024–25) begin. 2019 is a sensitivity fit |
| Makes with fewer than 1,000 active vehicles in 2021 are grouped as Other | Stable estimates |
| Every use class except Passenger is grouped | Only 24 Truck-class vehicles were active in 2021, too few for their own estimate |
| Prior transfers are grouped as 0, 1, and 2 or more | Few vehicles have more |
| Age enters as a number if its Box–Tidwell term has p ≥ 0.05, otherwise in bands | Set before fitting. Age passes, so it enters as a number |
| Model B adds history known at the end of the baseline year: missed years, late renewals (gaps over 430 days), county moves, and the type and quarter of the last record that year | Model A, on the base predictors, is near chance. Each feature is grouped as 0, 1 or 2+ |
| Final logistic model: lower training AIC | Set before fitting, without the test year. B is chosen (43,318 against 44,987) |
| Optimal cut-off: Youden's J on the training data, applied to the test data | At 0.5 almost no vehicle is predicted to leave (misclassification 7.5% while detecting no leavers) |
| Calibration: test vehicles are split into tenths by predicted probability; each tenth's mean prediction is compared with its observed exit rate | The standard calibration check. An assertion confirms ten distinct means per model |

**Extensions**

| Rule | Reason |
|---|---|
| The repeat-sales and hedonic indexes start in 2016 | Sale dates are almost absent before then. One pair and three sales are dropped |
| Survival follow-up ends in 2023 for every vehicle | Leaving cannot be seen after 2023. Without this, the curves for recent model years flatten falsely |
| Range model: BEVs of model year 2020 or earlier with a recorded range, at the 2021 baseline | Range is recorded only for these (section 4) |
| County population comes from US Census Bureau July 1 estimates: Vintage 2020 for 2010–2019, Vintage 2025 for 2020–2025 | A public, federal, county-level series. The newer vintage revises 2020. Files are hashed in `data/raw/PROVENANCE.txt` |
| Projection (section 20) uses the stock-and-flow identity from 9.1: active next year = active × (1 − exit rate + return rate) + entries | The identity reconciles exactly, so the projection inherits the population definitions |
| At a cut year C, only what is final at C is used: entries to C, the gap-filled count to C−1, exit and return rates to C−2 (mean of the five years C−6 to C−2) | The same rule serves the backtest (C = 2022) and the projection (C = 2025), and prevents later data leaking into the backtest |
| Entries follow two benchmark rules: Level keeps entries at year C's level (naive); Trend keeps their mean yearly log growth over C−10 to C (drift) | Standard forecasting benchmarks (Hyndman & Athanasopoulos, ch. 5). Exits are stable; entries are the uncertain part |
| Level is the primary projection, Trend the high scenario | Based on what was known at the end of 2025, not on the backtest: entries were flat in 2024–2025 (72,036 then 71,635), and the state sales-tax exemption ended on 31 July 2025 |
| Interval: 10,000 simulated paths per rule (seed reset). Each path draws one exit rate (normal, mean and SD of the five known years) and yearly entry shocks with the rule's one-step error SD; Trend also draws its growth rate | 80% and 95% intervals that include both exit and entry uncertainty |
| Horizon: three years (2026–2028) | The backtest checks three years ahead; beyond that the Level interval widens quickly |
| 2026 is used only as a check: entries from 1 January to 30 September against the same period in 2025 | 2026 is partial, so it does not enter the projection |
| Districts and utilities (section 21) are taken from the vehicle's last record of the year, like county. A figure is shown only for an area with 500+ vehicles that year | Keeps every share's standard error under about 2.2 points |
| District rates per 1,000 residents use state population ÷ 49 | Districts are drawn with near-equal populations after each census. Labelled "approximate" because populations drift between censuses |
| District map check: census tracts in one district both before and after 2022 | Washington redrew its districts in 2022. None of 1,421 tracts changed district, so the source applies one map to every year and 2019 and 2025 can be compared |
| Utility territories are kept as the source labels them; labels under 500 vehicles in 2025 are pooled | Overlapping territories are listed together ("\|\|"), so a label is an area, not one company's customers |

## 7. Results

### Main tests

There are seven test families. The two main tests are the headline results, and the rest support them. A Bonferroni threshold (0.05 / 7) is in `13_hypothesis_tests.csv`.

- **Spread:** King's share fell 5.5 points from 2019 to 2025 (95% CI 5.0 to 5.9, p < 0.001). Gap-filled counts give 5.4 points. Cohen's h is −0.11, a small effect. Many vehicles appear in both years, so the two groups are not independent.
- **Retention: no evidence of a difference in the current fleet.** Adjusted for age, at the 2021 baseline, the PHEV odds ratio is 1.03 (0.97 to 1.10, p = 0.26). The 2019 baseline gives 0.90 (p = 0.005) and 2023 gives 0.97 (p = 0.14). The full logistic model, which also adjusts for make, region, transfers and use, gives 0.81, mostly from comparisons within makes.

### Retention: logistic test and Cox model (17.1)

The Cox model (hazard ratio 0.92, p ≈ 3 × 10⁻¹¹) and the main logistic test (odds ratio 1.03, p = 0.26) answer different questions. The logistic test covers one two-year window from 2021; the Cox model pools every exit from 2010 to 2023 over all ages. Splitting both by calendar period (`17_retention_by_period.csv`):

| Period | Logistic PHEV odds ratio (baseline year) | Cox PHEV hazard ratio (risk time in period) |
|---|---|---|
| Early fleet | 0.53–0.81 (2013–2018 baselines, all p < 0.001) | 0.69 (2010–2016), 0.79 (2017–2019) |
| 2019 | 0.90 (p = 0.005) | — |
| 2020 onwards | 1.02, 1.03, 1.01, 0.97 (2020–2023 baselines, all p > 0.14) | 1.04 (2019–2021), 1.03 (2021–2023, p = 0.09) |

- PHEVs left less often than BEVs up to about 2019; since 2020 there is no difference. The all-years Cox ratio of 0.92 averages the two periods. The proportional-hazards check agrees that the PHEV effect is not constant (Schoenfeld test p = 0.024, `17_cox_ph_check.csv`).
- The logistic test at the 2021 baseline remains the pre-specified test of H0; the period split explains the difference and does not replace it.
- **Result:** no difference in leaving within two years from 2021 (OR 1.03, p = 0.26). Across 2010–2023 PHEVs left slightly less often (Cox HR 0.92), but only before 2020.

### Supporting tests

- **County growth:** the other 38 counties grew faster than King (mean log growth 1.81 against 1.53, p < 0.001). Growth falls only weakly with starting stock: the slope is −0.038 (p = 0.058, R² 0.09), and p = 0.11 without King. The most influential counties are the four smallest (Wahkiakum, Garfield, Columbia, Adams), not King. The multiple model's R² is 0.26, and no predictor is significant with robust errors.
- **BEV share** rose by a mean of 17.6 points across 35 counties (95% CI 14.5 to 20.7).
- **Age at last record:** BEVs that left were younger than PHEVs that left (2.55 against 3.38 years). This mixes periods, because the early fleet differed by type.
- **One-sample z for a mean:** a random 500 vehicles from 2025 have a mean age of 3.12 years, against the 2019 mean of 2.58 (z = 4.03, p < 0.001, d = 0.18).
- **Exit share:** 7.53% for 2023 against 6.86% for 2019. The difference is small (h = 0.03), and the 2023 figure also reflects the change in exit-rule accuracy (section 4).
- **Feature separation (2021 baseline):** leavers were slightly older (3.16 against 2.95 years, d = 0.08). Leaving rises with prior transfers: 7.1% with none, 8.5% with one, 10.7% with two or more (Cramér's V = 0.03). Both effects are real but small.

### Probability and distributions

- **Weekly entries:** Poisson is far too narrow (dispersion 9,627; its 95% band covers 37% of weeks). Negative binomial fits much better (AIC 9,571 against 39,696; its band covers 95% of weeks), although some overdispersion remains (4.4). Observed zero weeks: 39. Expected: 38 under negative binomial, 45 under Poisson.
- **Binomial:** the model-year 2013 cohort had 400 exits among 4,843 vehicles, against 332 expected. With a continuity correction, the normal approximation's error falls from 0.083 at n = 10 to 0.007 at n = 1,000.
- **Geometric:** fits all cars pooled (p = 0.21), **but not within any model-year cohort** (all p < 0.001). Mixing cohorts observed for different lengths of time produces a geometric-looking total.
- **Central limit theorem:** the SD of sample means matches σ/√n at every n, and their skewness falls from 0.51 (n = 5) to 0.02 (n = 500), although the population's skewness is 1.32.

### ANOVA

- **One-way, growth by size class: not significant at 5%.** Levene p = 0.56 and Shapiro p = 0.075, so the classic ANOVA is primary: F = 2.80, p = 0.074, η² = 0.13. Sensitivity checks: Welch p = 0.032 and Kruskal–Wallis p = 0.045. No Tukey pair is significant (Large against Small p = 0.11). This is weak evidence that large counties grew less, consistent with the weak regression slope (`13_anova_oneway_primary.csv`).
- **Two-way:** the size × side interaction is p = 0.018, but cells hold 2 to 10 counties, so it is exploratory.
- **Repeated measures, BEV share in 2019, 2022 and 2025:** the mean across 35 counties rose at every step. Sphericity fails (Mauchly p < 0.001), so the Greenhouse–Geisser correction is applied (ε = 0.60): p = 1 × 10⁻¹⁴, partial η² = 0.78. Friedman agrees, and all three Bonferroni pairs differ.
- **Mixed:** the year × side interaction is p = 0.002. Eastern counties started lower (mean BEV share 51% against 61% in 2019) and closed most of the gap by 2025 (73% against 75%). The side difference averaged over years is not significant (p = 0.075).

### Logistic regression

- **Model A (base predictors)** has an AUC of 0.56 on the 2021 training data and 0.52 on the 2023 test data (0.517 to 0.527), barely above chance. Its odds ratios still describe associations: the adjusted exit rate is 6.9% in King against about 8% elsewhere, and 7.1% with no prior transfer against 10.8% with two or more.
- **Model B (history added)** raises the test AUC to 0.569 (0.563 to 0.574); DeLong's test gives p ≈ 10⁻⁷⁶. McFadden's R² rises from 0.007 to 0.044.
- At the Youden cut-off (7.7%), model B catches 40% of leavers with 70% specificity; misclassification is 32%.
- The strongest term is the last record of the year being a title with no registration after it. Only about 470 vehicles have one, but most of them leave (odds ratio 56). Next come make, late renewals and region. County moves add nothing (p = 0.62).
- All generalised VIFs are low (adjusted GVIF ≤ 1.66).
- **Calibration:** both models match the overall exit rate (7.7% and 7.6% predicted against 7.5% observed). Model B's tenths range from 5.6% to 13.4% observed and follow the diagonal except at the top (15.5% predicted against 13.4%). Model A's tenths span only 6.4–8.4% observed, and its top tenth predicts 12.3% against 8.4%.
- **Why discrimination stays weak:** removing exits that later returned barely changes the AUC (0.563 to 0.555), so label noise is not the cause. The usual causes of leaving (moving out of state, a crash, export) leave no trace in the records beforehand. This is a limit of the data.
- With history added, the PHEV odds ratio is 0.82 (0.75 to 0.90). The main retention test (age-only adjustment) is unchanged.

### Extensions

**Extension 1, used prices.** There are 20,631 repeat-sale pairs on 17,088 cars (benchmark: about 21,200 on 17,600). The repeat-sales changes reproduce the benchmark within 1 point, except 2025 (−20.5% against −21.4%), because October 2025 has no CPI.
- **The repeat-sales index includes ageing.** A car is older at its second sale by exactly the gap, so ageing cannot be separated from time. A hedonic index that holds age and mileage fixed shows +21% in 2022, about −17% in each of 2023 and 2024, −4% in 2025 and +1% in January to September 2026. Each year of age is associated with an 11.4% lower real price.
- **Activity and prices:** used activity rose from 2023, while age-adjusted prices fell and then levelled off. This is an association only.
- **Cars sold twice are not typical.** They are 4.3% of vehicles. They are older (mean model year 2017 against 2022), less often Tesla (28% against 41%), and less often entered new (49% against 77%).
- **Pooled index outside both groups (15.3).** In 2020 and 2021 the pooled change lies outside both the Tesla and the non-Tesla change (2020: −14.2% overall, against −14.7% and −18.2%). Pooled least squares gives a matrix-weighted average of the group estimates, b = (X'X)⁻¹(X₁'X₁b₁ + X₂'X₂b₂), not a year-by-year average, so one year can land outside the range. The script checks this identity to 10⁻⁸.

**Extension 2, EVs per 1,000 residents.**
- Washington has 33.8 per 1,000 in 2025: King 57.2, the rest of the state 24.0.
- King holds 49.7% of plug-in vehicles but 29.3% of residents. That ratio fell from 1.87 (2019) to 1.69 (2025), so the spread result also holds per resident.
- Larger counties have higher rates (Spearman 0.51, p = 0.001). San Juan (66 per 1,000) is above King, while most Eastern counties are below 15.

**Extension 3, county movement.** In a year with a title transfer, 37.1% of King vehicles move to another county, against 2.1% without one. About one in nine of those transferred movers goes to Eastern Washington. More vehicles move out of King than in every year, for example 5,867 out against 3,535 in for 2025.

**Extension 4, survival.** By age 5, 72% of BEVs and 74% of PHEVs are still in the records; by age 10, 53% and 55%. The Cox model and its period split are reported above under retention.

**Extension 5, range: no evidence.** Among 45,636 older BEVs, the odds ratio for exit per 100 miles of range is 0.94 (0.81 to 1.08, p = 0.38).

**Extension 6, population projection.**
- **The exit side is accurate.** In the backtest (records cut at 2022), plugging in the actual entries reproduces the 2023–2025 gap-filled counts within 0.9% (2025: +0.1%).
- **Entries drive the error.** With projected entries, Level was 30% low in 2025 and Trend 2% high, because entries jumped 66% in 2023. Both 80% intervals contained the actual counts in all three years.
- **Projection, 2028 (Level, primary):** about 444,000 active vehicles (80% interval 358,000–592,000; 95% interval 331,000–714,000). Trend, the high scenario, gives about 593,000.
- **Early 2026 check:** entries from January to September 2026 are 49,477, 11.8% below the same months of 2025. At the usual January–September share (75%), that implies about 66,000 for the year: below Level's 72,000 and well below Trend's 93,000.
- **Limits:** the rates are held constant; policy and prices can change entries quickly (as in 2023); the 2025 gap-filled count uses the partial 2026, so it is slightly provisional; and the backtest has one origin, so it cannot rank the two rules reliably.

**Extension 7, legislative districts and utility territories.**
- **Districts:** the five largest held 31% of vehicles in 2019 and 26% in 2025, and the ratio of the highest to the lowest district fell from 38 to 20. This repeats the county spread result at a finer level.
- The top districts are 41, 45 and 48 (King County's Eastside), with about 89–102 vehicles per 1,000 residents in 2025. The lowest, district 15, has about 5.
- **Utility territories:** 27 territory labels have 500+ vehicles. The Puget Sound Energy, Seattle and Tacoma labels hold 73% of vehicles. BEV share is 80–82% there and 58–80% in the other large territories.

## 8. Reproducibility

- The raw extract is identified in the header of `analysis.R` and in `data/raw/PROVENANCE.txt`: dataset ID rpr4-cgyd, source and file URLs, download date and time, file size (933,780,051 bytes), row count (1,926,507) and SHA-256. The script stops if the hash or the row count differs.
- The CSV is not in the repository (it exceeds GitHub's file limit); `README.md` explains how to obtain the shared copy.
- Random sections reset the seed, so a full run reproduces every table and figure exactly.
