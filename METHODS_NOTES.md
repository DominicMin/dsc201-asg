# Methods notes

One short entry per method beyond the basics, in `analysis.R` section order. Each entry covers what the method does, why it's needed here, how to explain it in plain words, and one or two sources to study. Results and rules are in `DECISIONS.md`.

---

## Population building (sections 4–6, 9)

### Stock-and-flow accounting
- **What:** next year's population = this year's + entries + returns − leavers. The script checks this holds exactly every year.
- **Why here:** the data is a log of transactions, not a list of vehicles on the road. This identity proves the population built from it is internally consistent.
- **In plain words:** "Like a bank balance: what you end with equals what you started with, plus deposits, minus withdrawals."
- **Study:** Preston, Heuveline & Guillot (2001), *Demography: Measuring and Modeling Population Processes*, Blackwell, chapter 1 (the balancing equation).

### Gap-filled active count and the two-year exit rule
- **What:** a vehicle missing one year between two recorded years still counts as active. A vehicle with no record for two calendar years counts as having left.
- **Why here:** renewals are sometimes late, so a single missing year isn't a real exit. The script measures how often "exits" come back, so the error is reported, not hidden.
- **In plain words:** "We only call a car gone after two silent years, and we count how often that call turns out wrong."
- **Study:** Kleinbaum & Klein (2012), *Survival Analysis: A Self-Learning Text*, 3rd ed., Springer, chapter 1 (censoring and incomplete follow-up).

### Real prices with the CPI
- **What:** each price is multiplied by CPI(September 2026) / CPI(sale month).
- **Why here:** prices from 2016 and 2026 can't be compared directly, because a dollar bought more in 2016.
- **In plain words:** "All prices are in today's money."
- **Study:** US Bureau of Labor Statistics, *Handbook of Methods*, "Consumer Price Index" chapter (bls.gov/opub/hom/cpi).

---

## Descriptive statistics (section 10)

### Kendall's tau, alongside Pearson and Spearman
- **What:** a rank correlation that counts agreeing against disagreeing pairs.
- **Why here:** the brief asks for Spearman or Kendall. County measures are skewed (King is huge), so rank methods are safer than Pearson. Kendall runs on a random 5,000 sales, because its cost grows with n².
- **In plain words:** "Pick two counties at random: how often does the bigger one also grow faster?"
- **Study:** Kendall (1938), "A new measure of rank correlation", *Biometrika* 30, 81–93.

---

## Probability (section 12)

### Poisson against negative binomial for weekly counts
- **What:** both model counts. The negative binomial adds a parameter, so the variance can exceed the mean.
- **Why here:** weekly new-vehicle entries are far more variable than Poisson allows. The Poisson 95% band covers only 37% of weeks, and the negative binomial band covers 95%.
- **In plain words:** "Poisson assumes cars arrive like raindrops, evenly at random. They actually arrive in bursts, and the negative binomial allows for bursts."
- **Study:** Cameron & Trivedi (2013), *Regression Analysis of Count Data*, 2nd ed., Cambridge University Press, chapters 3–4. Hilbe (2011), *Negative Binomial Regression*, 2nd ed., Cambridge University Press.

### Spline trend and seasonal waves
- **What:** a natural spline lets the trend bend about once a year. Sine and cosine terms capture the seasonal cycle.
- **Why here:** EV sales rose and fell in several phases, and a straight line would mislabel those phases as randomness.
- **In plain words:** "A flexible ruler for the long-term trend, plus a wave for the time of year."
- **Study:** Hastie, Tibshirani & Friedman (2009), *The Elements of Statistical Learning*, 2nd ed., Springer, chapter 5 (free online).

### Normal approximation to the Binomial, with continuity correction
- **What:** a Binomial count is approximated by a normal curve. Adding or subtracting 0.5 bridges the gap between whole numbers and a continuous scale.
- **Why here:** this is the brief's "relating discrete to normal probability". The table shows the error shrinking as n grows.
- **In plain words:** "Bars and a smooth curve: the half-step makes the curve cover each bar fairly."
- **Study:** Montgomery & Runger, *Applied Statistics and Probability for Engineers*, Wiley, chapter 4 (normal approximation to the Binomial).

### Geometric distribution, checked within cohorts
- **What:** the number of sales per car is modelled as geometric, with p = 1 / mean sales.
- **Why here:** pooled over all cars it fits (p = 0.21), but within each model-year cohort it fails. Mixing cars watched for different lengths of time can fake a good fit, and that is a lesson worth showing.
- **In plain words:** "The total looked right only because old and new cars were mixed together."
- **Study:** Ross, *A First Course in Probability*, Pearson, chapter 4 (geometric distribution).

### Central limit theorem by simulation
- **What:** many samples are drawn from the real 2025 age distribution, and their means are plotted.
- **Why here:** the brief asks for it. Vehicle age is skewed (skewness 1.32), which makes the move towards normality easy to see.
- **In plain words:** "Even when the data is lopsided, averages of many cars form a bell curve, and it narrows like 1/√n."
- **Study:** Montgomery & Runger (as above), chapter 7 (sampling distributions).

---

## Hypothesis tests (section 13)

### Effect sizes: Cohen's h and d, Cramér's V
- **What:** they measure how big a difference is, not only whether it exists.
- **Why here:** with nearly every recorded vehicle, even tiny differences are "significant", so the effect size matters more than the p-value.
- **In plain words:** "The p-value says it's real; the effect size says whether it matters."
- **Study:** Cohen (1988), *Statistical Power Analysis for the Behavioral Sciences*, 2nd ed., Erlbaum.

### Welch's t-test
- **What:** a two-sample t-test that doesn't assume equal variances.
- **Why here:** the groups compared (BEV against PHEV, leavers against stayers) have different spreads and sizes.
- **In plain words:** "A t-test that doesn't assume both groups are equally variable."
- **Study:** Delacre, Lakens & Leys (2017), "Why psychologists should by default use Welch's t-test instead of Student's t-test", *International Review of Social Psychology* 30(1), 92–101.

### Wilcoxon and Kruskal–Wallis checks
- **What:** rank-based versions of the t-test and ANOVA.
- **Why here:** there are only 34–39 counties, and their growth is skewed, so the normality assumption is shaky.
- **In plain words:** "The same question asked with ranks, so one extreme county can't drive the answer."
- **Study:** Hollander, Wolfe & Chicken (2014), *Nonparametric Statistical Methods*, 3rd ed., Wiley.

### Bonferroni threshold
- **What:** with k tests, each is judged at 0.05 / k.
- **Why here:** nine headline and supporting tests are run. Without an adjustment, about one in twenty true nulls would be rejected by chance.
- **In plain words:** "The more questions you ask, the stricter each answer has to be."
- **Study:** Bland & Altman (1995), "Multiple significance tests: the Bonferroni method", *BMJ* 310, 170.

### One-way ANOVA with assumption checks (course Chapter 8)
- **What:** it compares mean county growth across the three size classes. Levene's test (median form) checks equal variances, and Shapiro–Wilk checks normality. Welch's ANOVA and Kruskal–Wallis are the robust versions, and Tukey's HSD compares pairs. The checks pick the primary test: non-normal residuals → Kruskal–Wallis; unequal variances → Welch; both fine → classic ANOVA. Here both are fine (Levene p = 0.56, Shapiro p = 0.075), so the classic ANOVA (p = 0.074) is primary and the other two are sensitivity checks.
- **Why here:** it asks, with three groups at once, whether smaller counties grew faster, without running three separate t-tests. Choosing the test from the checks, not from the p-values, keeps the choice honest when the versions disagree.
- **In plain words:** "Is the spread between the group averages bigger than the spread inside the groups?"
- **Study:** Field, Miles & Field (2012), *Discovering Statistics Using R*, SAGE, chapter 10. Brown & Forsythe (1974), "Robust tests for the equality of variances", *JASA* 69, 364–367.

### Two-way ANOVA and interaction (course Chapter 8)
- **What:** it tests size class, side of the Cascades and their interaction.
- **Why here:** smaller counties might grow faster on one side only. The cells hold 2 to 11 counties, so the result is exploratory. Size and side are confounded (most large counties are western), so with sequential sums of squares the main effects change with the order of entry; only the interaction is interpreted.
- **In plain words:** "Does the size effect depend on which side of the mountains you're on?"
- **Study:** Field, Miles & Field (2012), chapter 12. Kutner, Nachtsheim, Neter & Li (2005), *Applied Linear Statistical Models*, 5th ed., McGraw-Hill, chapter 19.

### Repeated-measures and mixed ANOVA, with sphericity (course Chapter 8)
- **What:** the same counties are measured in 2019, 2022 and 2025. Mauchly's test checks sphericity (equal variances of the differences between years). When it fails, the Greenhouse–Geisser epsilon shrinks the degrees of freedom. The Friedman test is the rank check, and Bonferroni paired tests are the post hoc comparisons. The mixed version adds side of the Cascades as a between-county factor.
- **Why here:** BEV share is measured three times on the same counties, so the years aren't independent groups.
- **In plain words:** "Each county is compared with itself over time, which removes county-to-county differences from the noise."
- **Study:** Greenhouse & Geisser (1959), "On methods in the analysis of profile data", *Psychometrika* 24, 95–112. Field, Miles & Field (2012), chapters 13–14.

---

## Regression (section 14)

### Confidence against prediction intervals
- **What:** a confidence interval covers the average outcome. A prediction interval covers one new case, so it is wider.
- **Why here:** the brief asks for both. The county table shows the prediction interval is 3 to 6 times wider.
- **In plain words:** "We're fairly sure of the average county, much less sure of any single county."
- **Study:** Kutner et al. (2005), chapter 2. Penn State STAT 501 online notes, lesson 3 (online.stat.psu.edu/stat501).

### Cook's distance, the squared-term check and VIF (course Chapter 9)
- **What:** Cook's distance flags influential points (above 4/n). A squared term tests for curvature. VIF measures overlap between predictors.
- **Why here:** with 39 counties, a few tiny counties could drive the line. The four most influential counties are the smallest ones (Wahkiakum, Garfield, Columbia, Adams), not King; results are also shown without King.
- **In plain words:** "Would the answer change much if this one county were removed?"
- **Study:** Kutner et al. (2005), chapters 10 and 14.

### Robust (HC3) standard errors
- **What:** standard errors that stay valid when the spread of residuals varies.
- **Why here:** used-price residuals and county residuals have uneven spread.
- **In plain words:** "Error bars that don't assume every case is equally noisy."
- **Study:** Long & Ervin (2000), "Using heteroscedasticity consistent standard errors in the linear regression model", *The American Statistician* 54(3), 217–224.

### Logistic regression: odds ratios and adjusted probabilities
- **What:** models the log-odds of leaving within two years. Adjusted probabilities set every vehicle to one level, for example "all BEV", and average the predictions.
- **Why here:** the outcome is yes or no, and adjusted probabilities are easier to explain than odds ratios.
- **In plain words:** "If every car were a PHEV but otherwise unchanged, what share would leave?"
- **Study:** Hosmer, Lemeshow & Sturdivant (2013), *Applied Logistic Regression*, 3rd ed., Wiley, chapters 1–3.

### Box–Tidwell check of logit linearity
- **What:** adds x·log(x) for each positive predictor. A significant term means the log-odds aren't straight in x.
- **Why here:** the rubric asks for logit linearity checks, and `car::boxTidwell` doesn't work on `glm`, so the terms are added by hand.
- **In plain words:** "We test whether each extra year of age adds the same amount of risk."
- **Study:** Box & Tidwell (1962), "Transformation of the independent variables", *Technometrics* 4, 531–550. Hosmer et al. (2013), chapter 4.

### Training on one year and testing on a later one
- **What:** the model is fitted on 2021 and judged on 2023. The two outcome windows don't overlap.
- **Why here:** it is a fair test of whether the model works on new years, not only the one it learned from.
- **In plain words:** "We study with last year's paper and sit this year's exam."
- **Study:** Steyerberg (2019), *Clinical Prediction Models*, 2nd ed., Springer, chapters 17 and 19.

### ROC, AUC and DeLong's test
- **What:** AUC is the chance the model ranks a random leaver above a random stayer (0.5 is a coin toss). DeLong's test compares two AUCs on the same vehicles.
- **Why here:** it shows model B's gain over model A (0.57 against 0.52) is real, although small.
- **In plain words:** "Pick one car that left and one that stayed: how often does the model rank the leaver as riskier?"
- **Study:** DeLong, DeLong & Clarke-Pearson (1988), *Biometrics* 44, 837–845. Robin et al. (2011), "pROC", *BMC Bioinformatics* 12, 77.

### Calibration and the Brier score
- **What:** calibration compares predicted and observed exit rates in tenths of the data. The Brier score is the mean squared error of the probabilities.
- **Why here:** a model can rank vehicles poorly yet still get average rates right, and these checks show that.
- **In plain words:** "When the model says 10%, do about 10% leave?"
- **Study:** Steyerberg (2019), chapter 15. Brier (1950), *Monthly Weather Review* 78, 1–3.

### McFadden's R² (course Chapter 9)
- **What:** 1 − log-likelihood(model) / log-likelihood(no predictors).
- **Why here:** the course asks for it. Values are much lower than a linear R². McFadden described 0.2 to 0.4 as an excellent fit, and here it is 0.04, which says the same as the AUC.
- **In plain words:** "How much better the model explains who left than simply guessing the average."
- **Study:** McFadden (1974), "Conditional logit analysis of qualitative choice behavior", in Zarembka (ed.), *Frontiers in Econometrics*, Academic Press. Hosmer et al. (2013), chapter 5.

### Variable importance, generalised VIF and optimal cutoff (course Chapter 9)
- **What:** importance is the drop in fit when a term is removed (likelihood-ratio chi-square), and |z| per coefficient, as `caret::varImp` reports. The generalised VIF handles factors with several levels; GVIF^(1/(2 df)) under about 2.2 matches the usual VIF under 5. The optimal cutoff is Youden's J (maximum sensitivity + specificity) found on the training data and applied to the test data.
- **Why here:** with a 7.5% exit rate, a 0.5 cutoff predicts that nobody leaves and still gets a "misclassification" of 7.5%. That figure is meaningless, so the cutoff has to be chosen.
- **In plain words:** "We pick the alarm level that best balances catching leavers against false alarms."
- **Study:** Youden (1950), "Index for rating diagnostic tests", *Cancer* 3, 32–35. Fox & Monette (1992), "Generalized collinearity diagnostics", *JASA* 87, 178–183. Kuhn (2008), "Building predictive models in R using the caret package", *Journal of Statistical Software* 28(5).

### History features, and why the model stays weak
- **What:** model B adds missed years, late renewals, county moves, and the type and quarter of the last record in the baseline year.
- **Why here:** model A was near chance. Removing exits that later returned barely changes the AUC, so label noise isn't the cause. The usual causes of leaving (moving out of state, a crash, export) aren't in the records, so only behaviour that comes before them helps.
- **In plain words:** "The records don't say why a car left, so the best clues are signs of drifting away: missed or late renewals, or a title with no registration after it."
- **Study:** Steyerberg (2019), chapter 4 (predictors and their limits). Hosmer et al. (2013), chapter 5.

---

## Extensions (sections 15–21)

### Repeat-sales index
- **What:** the log price change of the same car between two sales is regressed on year dummies (−1 for the first sale year, +1 for the second).
- **Why here:** comparing the same car removes differences between cars. But a car is older at its second sale by exactly the gap, so the index includes ageing.
- **In plain words:** "How the price of the same car changed, which includes the car getting older."
- **Study:** Bailey, Muth & Nourse (1963), "A regression method for real estate price index construction", *JASA* 58, 933–942. Case & Shiller (1987), "Prices of single-family homes since 1970", *New England Economic Review*.

### Why the pooled index can fall outside its subgroups
- **What:** pooled least squares is a matrix-weighted average of subgroup estimates, not a year-by-year average, so one year's pooled value can lie outside both groups.
- **Why here:** it explains the index oddity, and the script checks the identity exactly.
- **In plain words:** "Each pair of sales pulls on several years at once, so the overall answer for one year isn't simply between the two groups' answers."
- **Study:** Chamberlain & Leamer (1976), "Matrix weighted averages and posterior bounds", *Journal of the Royal Statistical Society B* 38, 73–84.

### Hedonic price index
- **What:** log price regressed on sale year, age, mileage, type and make. The year effects form the index.
- **Why here:** it holds age fixed, which the repeat-sales index can't.
- **In plain words:** "The price of a typical car of fixed age and mileage, year by year."
- **Study:** Triplett (2006), *Handbook on Hedonic Indexes and Quality Adjustments in Price Indexes*, OECD.

### Kaplan–Meier with late entry, and Cox regression
- **What:** survival by age. A used car joins the at-risk group at its age on arrival (left truncation). Follow-up stops in 2023, the last year leaving can be seen.
- **Why here:** used arrivals would otherwise make survival look better than it is.
- **In plain words:** "Of cars that reached age 5, how many reached 6? Chain those steps together."
- **Study:** Kaplan & Meier (1958), *JASA* 53, 457–481. Klein & Moeschberger (2003), *Survival Analysis*, 2nd ed., Springer, chapter 4 (left truncation).
- **Check:** the Cox model assumes the PHEV effect is the same at every age (proportional hazards). `cox.zph` tests this with Schoenfeld residuals; p = 0.024 says the effect varies. Splitting by calendar period shows why: PHEVs left less often before 2020, with no significant difference since. So the pooled hazard ratio is an average over two eras.
- **In plain words:** "The all-years model blends an old fleet, where plug-in hybrids stayed longer, with today's, where no clear difference remains."
- **Study:** Grambsch & Therneau (1994), *Biometrika* 81, 515–526 (the residual test). Therneau & Grambsch (2000), *Modeling Survival Data*, Springer, chapter 6.

### EVs per 1,000 residents
- **What:** active vehicles divided by Census county population.
- **Why here:** King's falling share of vehicles could just reflect population. Per-resident rates and the ratio of vehicle share to population share separate the two.
- **In plain words:** "King has 29% of the people but half the plug-in vehicles, and that gap is narrowing."
- **Study:** US Census Bureau, "Methodology for the United States Population Estimates: Vintage 2025" (census.gov, Population Estimates Program).

### Stock-and-flow projection with a backtest
- **What:** next year's population = this year's × (1 − exit rate + return rate) + new entries. Exit and return rates are averages of the last five years that are final. Entries follow one of two benchmark rules: Level (they stay at the last year's level) or Trend (they keep their ten-year average growth). 10,000 simulated paths give 80% and 95% intervals. The backtest reruns the whole method with records cut at 2022 and compares it with the actual 2023–2025 counts.
- **Why here:** the population's future depends on inflow and outflow, and the records measure both. The backtest shows what the projection can and can't do. The exit side is accurate within 1%, but a jump in entries (2023) moves the result by 30%.
- **In plain words:** "A bathtub: water in from the tap, out through the drain. We know the drain well; the tap is the guess."
- **Study:** Hyndman & Athanasopoulos (2021), *Forecasting: Principles and Practice*, 3rd ed., OTexts (free online), sections 5.2 (naive and drift rules), 5.5 (prediction intervals) and 5.8 (testing on held-back years). Smith, Tayman & Swanson (2013), *A Practitioner's Guide to State and Local Population Projections*, Springer, chapters 1–2.

### Legislative districts as equal-population areas
- **What:** vehicles are counted by state legislative district and electric utility territory, using the source's own fields. Districts are drawn with near-equal populations, so vehicles per 1,000 residents ≈ vehicles ÷ (state population ÷ 49) × 1,000. A check confirms the source uses one district map for every year.
- **Why here:** counties range from about 2,300 to 2.3 million residents, so county counts mix size with uptake. Districts are finer and roughly equal in size, so they show the spread more fairly.
- **In plain words:** "Each district has about the same number of people, so more cars in a district means more cars per person."
- **Study:** Revised Code of Washington 44.05.090 (districts "as nearly equal in population as practicable"). Washington State Redistricting Commission (2021), final district plan, redistricting.wa.gov.
