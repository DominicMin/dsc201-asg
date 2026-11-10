# Guide for finishing the report

This guide is for the team member who turns `report/report_draft.docx` into the final report, and for anyone preparing slides or the Q&A. You don't need to run any code: every number, table and figure is already in `outputs/`.

## 1. The project in one page

**Topic and focus.** The brief (`desc.pdf`, section F) offers three datasets. We use the Electric Vehicle dataset, and the brief names four possible focuses for it: Vehicle Specification, Performance, Population and Charging Patterns. This project's focus is **Population**, with Vehicle Specification in support.

**Research question.** This is the Population focus written as a question:

> How has Washington's plug-in vehicle population grown, aged and spread from 2010 to 2026, and which vehicles stay in it?

Each part of the question has its own answer:

| Part of the question | What answers it | Headline |
|---|---|---|
| **Grown** | Active vehicles per year (sections 6, 11.1); projection to 2028 (20) | 54,733 active in 2019 → 286,478 in 2025; about 444,000 projected for 2028 |
| **Aged** | Vehicle age by year (11.7, 11.9, 11.12); used prices by age (15) | Mean age rose from 2.58 years (2019) to about 3.1 (2025, test 13.3); each year of age is associated with an 11.4% lower used price |
| **Spread** | King County's share (13.1); vehicles per 1,000 residents (19); BEV share by region (13.12–13.13) | King's share fell 5.5 points from 2019 to 2025, but King still has 49.7% of vehicles and 29.3% of residents |
| **Which vehicles stay** | BEV against PHEV retention (13.2, 17); exit model (14.4–14.9) | No BEV/PHEV difference since 2021; leaving is hard to predict from the records |

The full list of 17 results, each with its code section and output file, is in the results table in `README.md`.

**The data.** Each row of the source is a *transaction* (title, registration, renewal or transfer), not a vehicle. Much of the work is turning 1.9 million transactions into a population: one row per vehicle per year, with entry, exit and county moves defined for every vehicle. This is the "feature engineering" the rubric asks for. Section II of the report explains it.

## 2. What to open, in order

1. `desc.pdf`: the brief and the marking rubric.
2. `README.md`: overview, data, the results table.
3. `report/report_draft.docx`: the report starter (see section 3 below).
4. `DECISIONS.md`: every cleaning and analysis rule with its reason, plus all results with exact numbers. Use it to check any number before writing it.
5. `METHODS_NOTES.md`: a plain-language explanation of each method, with a reference. Use it for the "justify their selection" part of the brief and for Q&A.
6. `outputs/figures/` (41 PNG files) and `outputs/tables/` (98 CSV files). File names start with the code section that made them, so `13_hypothesis_tests.csv` comes from section 13.
7. `analysis.R`, only if you need to see how something was done. Open `dsc201-asg.Rproj` in RStudio and press Ctrl+Shift+O for the outline of sections.

## 3. The report draft and what is left to do

`report/report_draft.docx` already follows the brief's structure (I. Context and Data Understanding, II. Data Pre-processing, III. Statistical Analysis and Modeling, IV. Actionable Conclusion and Insight). It is in the required format: Times New Roman, 14 pt titles, 12 pt body, 1.5 spacing, justified. It contains:

- 34 figures and 8 tables, each with a caption naming its file in `outputs/`.
- Bullet points with the findings and their numbers under each sub-section.
- A "code: …" line under each sub-section, giving the `analysis.R` sub-sections that produced it.

**No code snippets.** The brief says not to include the code in the report, only to reference the sub-sections ("The code of this finding could be found on sub-section xx in R code"). The "code: …" lines already do this. Keep them, and reword them into that sentence if you prefer.

**Still to do:**

1. Turn the bullets into short paragraphs. The bullets hold the facts; the report needs sentences that interpret them (what the result means, not only the number).
2. Add the assignment cover page in front.
3. Add short "why this method" sentences where section III introduces a test. `METHODS_NOTES.md` has one paragraph per method to draw on.
4. Decide how much of III.5 (extensions) to keep. Section 5 below says what each one adds. The main answer stands without them, so they can be shortened if the report is too long.
5. Spell and grammar check (a requirement of the brief).
6. Save as `StudentID.docx` and `StudentID.pdf`. The script is submitted as `StudentID.R` (a copy of `analysis.R`).

**Wording to keep, because it is accurate:**

- "associated with", never "caused by". The data are records, not an experiment.
- A vehicle that "left the records" has no Washington record for two years. It may have moved out of state or gone off the road, and the records can't tell which, so don't write "scrapped" or "died".
- A vehicle whose first Washington record is a used title is described by its "first Washington title as used", not as "imported", because the records don't show where it was before.

## 4. Where each rubric criterion is answered

| Rubric criterion (weight) | Code sections | Report section | Main outputs |
|---|---|---|---|
| Data pre-processing and feature engineering (15%) | 2–9 | II, I.2 | `09_flow_table.csv`, `09_benchmark_cross_check.csv`, `06_population_flows.csv` |
| Descriptive statistics and correlation (10%) | 10 | I.3 | `10_descriptives.csv`, `10_correlations.csv`, figures `10_05`, `11_07`, `11_09` |
| Probability and distributions (15%) | 12 | III.1 | figures `12_01`–`12_04` (Poisson and negative binomial, binomial against normal, geometric, central limit theorem) |
| Visualisations (10%) | 10.0–11.12, plus figures in later sections | throughout | all 41 PNG files in `outputs/figures/` |
| Hypothesis testing (10%) | 13.1–13.13 | III.2, III.3 | `13_hypothesis_tests.csv`, the `13_anova_*.csv` tables |
| Regression (10%) | 14.1–14.9 | III.4 | `14_*.csv`, figures `14_01`–`14_08` |
| Report content and format (10%) | — | whole report | `report/report_draft.docx` |

The rubric's top band for regression mentions "decision boundaries and logit linearity checks". Both are in the code: the Box–Tidwell check (14.4) and the decision boundary (14.9, figure `14_07`). For hypothesis testing it mentions "feature separation": that is test 13.8, and figure `14_08` shows the same separation for the logistic model.

## 5. The core and the extensions

`analysis.R` has about 2,680 lines, including comments:

| Part | Sections | Lines (approx.) | Purpose |
|---|---|---|---|
| Data preparation and verification | 1–9 | 770 | Import, audit, cleaning, building the population, checking it adds up |
| Course methods | 10–14 | 1,270 | Everything the brief lists: descriptive statistics, probability, tests, ANOVA, regression |
| Extensions | 15–21 | 640 | Seven extra analyses that deepen the answer |

The length comes mostly from the data. The source is transactions, so building a population of vehicles takes real work (sections 3–6). Section 9 then proves the population is correct before any statistics are run. About three quarters of the script is preparation and the course methods.

**The extensions.** Their section numbers and extension numbers differ, because they are ordered by how they build on each other.

| Section | Extension | What it does | What it adds to the answer |
|---|---|---|---|
| 15 | 1. Used prices and entry routes | Repeat-sales price index from cars sold twice | **Aged**: how value falls with age (about 11.4% per year) |
| 19 | 2. EVs per 1,000 residents | Joins Census county population | **Spread**: puts county counts on a per-person basis (King 57.2, rest of state 24.0) |
| 16 | 3. County movement | Vehicles moving into and out of King County | **Spread**: a title transfer is associated with leaving King (37.1% against 2.1%) |
| 17 | 4. Cohort survival | Kaplan–Meier curves and a Cox model by age | **Stay**: share still recorded at each age (72% of BEVs, 74% of PHEVs at age 5); confirms the main retention test |
| 18 | 5. Electric range | Range as a predictor of leaving | **Stay**: no evidence range matters (p = 0.38) |
| 20 | 6. Projection | Stock-and-flow projection to 2028, with a backtest | **Grown**: where the population is heading, and how well the method would have done in the past |
| 21 | 7. Districts and utilities | Legislative districts and electric utility territories | **Spread** for decision-makers: the areas that plan charging and grids (IV.2 of the report) |

## 6. Methods beyond the lecture list

The brief allows other techniques where the listed ones don't fit the data ("not limited"). Each one below has a reason, and each is explained in `METHODS_NOTES.md`.

| Method | Where | Why it is there |
|---|---|---|
| Negative binomial with a spline trend | 12.1 | Weekly counts vary more than a Poisson allows; the negative binomial is the standard fix |
| Welch t, Wilcoxon, Kruskal–Wallis | 13 | Checks for when equal variances or normality fail |
| Repeated-measures and mixed ANOVA, with sphericity | 13.12–13.13 | The same counties are measured in several years, so ordinary ANOVA would be wrong |
| Robust (HC3) standard errors | 14.1 | 39 counties of very different sizes; protects against unequal variance |
| Box–Tidwell check, ROC/AUC with DeLong's test, calibration | 14.4–14.6 | The rubric's "logit linearity checks"; standard ways to judge a logistic model |
| Kaplan–Meier and Cox regression | 17 | The standard way to measure "how long vehicles stay" when some are still present |

If the report is long, these can be described in one sentence each. The main results use the course methods: proportion test (13.1), logistic regression (13.2, 14), ANOVA (13.10–13.13) and linear regression (14.1–14.3).

## 7. Getting the raw data (only to re-run the script)

The 933 MB source file is not on GitHub. Ask the team for the shared zip (Google Drive), unzip it into `data/raw/`, and follow "Getting the data" in `README.md`. The script checks the file's SHA-256 hash before it runs, so a wrong copy is caught. Don't download a new copy from data.wa.gov, because the portal serves a newer version.

## 8. Preparing for the technical Q&A

The rubric gives 10% to answering questions about the R code, data cleaning and model logic. Likely questions, with where the answer is:

| Question | Short answer | Details |
|---|---|---|
| How do you count "active" vehicles from transactions? | A vehicle is active in a year if it has at least one record that year; the gap-filled count also includes a vehicle with no record that year but records in the years either side | `DECISIONS.md` §2, `analysis.R` 6 |
| How do you know a vehicle left? | No Washington record for two years; this can only be seen up to 2023 | `DECISIONS.md` §2, `METHODS_NOTES.md` |
| How do you know the population is right? | Stock and flow add up exactly every year, and counts match independent figures from the data portal | `analysis.R` 9.1–9.4 |
| Why was the "New/Used" field not used directly? | Registration rows always say Used, even for new cars; the entry route is rebuilt from title rows | `analysis.R` 2.3, 5.1 |
| Why is the exit model weak (AUC 0.52–0.57)? | Why a vehicle leaves (moving state, accident, sale out of state) isn't in the records | `analysis.R` 14.7, `DECISIONS.md` §7 |
| Why do the Cox and logistic results differ? | PHEVs left less often before 2020 only; the Cox figure averages over all years | `analysis.R` 17.1, `17_retention_by_period.csv` |
| Why is the one-way ANOVA result the classic test? | The assumption checks passed (Levene p = 0.56, Shapiro–Wilk p = 0.075), so the rule set beforehand picks it; Welch and Kruskal–Wallis are sensitivity checks | `analysis.R` 13.10 |
