# =============================================================================
# Washington's plug-in vehicle population, 2010-2026
# One numbered script. Run from the project folder, top to bottom:
#   Rscript --vanilla analysis.R
# The report refers to these section numbers, so keep them stable.
#
# Sections 1-9 build and check the population, 10-14 apply the statistical methods,
# and 15-21 are extensions.
#   1 Set-up                      10 Descriptive statistics and correlation
#   2 Import and audit            11 Visualisations of population change
#   3 Clean the records           12 Probability and distributions
#   4 Vehicle-year records        13 Hypothesis testing
#   5 Vehicle histories           14 Regression
#   6 Active, entry, exit, move   15 Extension 1: used prices and entry routes
#   7 Prices (supporting work)    16 Extension 3: county movement
#   8 Specification fields        17 Extension 4: cohort survival
#   9 Reconcile and audit         18 Extension 5: electric range and retention
#                                 19 Extension 2: EVs per 1,000 residents
#                                 20 Extension 6: population projection
#                                 21 Extension 7: districts and utilities
# Packages: data.table and ggplot2 are attached; MASS, moments, sandwich, lmtest,
# pROC, survival and splines are called with ::. Figures go to outputs/figures.
#
# Data source (Washington State Department of Licensing, licence ODbL):
#   Electric Vehicle Title and Registration Activity
#   Dataset ID: rpr4-cgyd (data.wa.gov)
#   Source page, then the file URL used for the download:
#   https://data.wa.gov/Transportation/Electric-Vehicle-Title-and-Registration-Activity/rpr4-cgyd
#   https://data.wa.gov/api/views/rpr4-cgyd/rows.csv?accessType=DOWNLOAD
#   Downloaded: 7 November 2026, 10:38 UTC (source last updated 14 October 2026)
#   Saved as: data/raw/Electric_Vehicle_Title_and_Registration_Activity.csv
#   Size: 933,780,051 bytes. Rows: 1,926,507 (plus header). Columns: 33.
#   SHA-256: bab70a0914c3f721c6365015adc461a2f8f76c85ae6035ccad750be74f59943b
#   The URL always serves the latest version, so a new download may not match.
#   The script stops (section 1) if the file's SHA-256 or row count differs.
# County population (section 19): US Census Bureau county estimates, Vintages 2020
#   and 2025, https://www2.census.gov/programs-surveys/popest/datasets/
# Inflation: BLS CPI-U, all items, US city average, not seasonally adjusted,
#   series CUUR0000SA0, from https://api.bls.gov/publicAPI/v1/timeseries/data/
# =============================================================================


# ---- 1. SET-UP --------------------------------------------------------------

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

set.seed(20261107)

# Month names in the file are English. Without this line, every date becomes NA
# on a computer with a non-English locale, and no error is shown.
invisible(Sys.setlocale("LC_TIME", "C"))

RAW_CSV    <- "data/raw/Electric_Vehicle_Title_and_Registration_Activity.csv"
RAW_SHA256 <- "bab70a0914c3f721c6365015adc461a2f8f76c85ae6035ccad750be74f59943b"
RAW_ROWS   <- 1926507L
CPI_FILES  <- c("data/raw/cpi_CUUR0000SA0_2008_2017.json",
                "data/raw/cpi_CUUR0000SA0_2018_2026.json")
META_JSON  <- "data/raw/source_metadata.json"
TAB <- "outputs/tables"
PRO <- "data/processed"
for (p in c(TAB, PRO, "outputs/figures", "report")) dir.create(p, recursive = TRUE,
    showWarnings = FALSE)

FIRST_YEAR <- 2010L
LAST_FULL  <- 2025L     # 2026 ends on 30 September
LAST_YEAR  <- 2026L

assert <- function(ok, msg) if (!isTRUE(all(ok))) stop("ASSERTION FAILED: ", msg, call. = FALSE)
pct    <- function(x, n, d = 1) round(100 * x / n, d)
say    <- function(...) cat(sprintf(...), "\n", sep = "")
out    <- function(x, name) fwrite(x, file.path(TAB, name))

assert(file.exists(RAW_CSV), "raw CSV is missing from data/raw/")
assert(as.character(tools::sha256sum(RAW_CSV)) == RAW_SHA256,
       "raw CSV does not match the frozen SHA-256 hash")
say("1. Raw file hash verified.")


# ---- 2. IMPORT AND AUDIT ----------------------------------------------------

# Read everything as text first, so that no value is silently changed on import.
raw <- fread(RAW_CSV, colClasses = "character", na.strings = NULL,
             showProgress = FALSE, encoding = "UTF-8")
assert(nrow(raw) == RAW_ROWS, "row count differs from the frozen file")
assert(ncol(raw) == 33L, "expected 33 columns")

# 2.1 Data dictionary: the source's description plus a profile of each column.
meta_txt <- paste(readLines(META_JSON, warn = FALSE, encoding = "UTF-8"), collapse = " ")
# the file puts spaces around its colons
meta_txt <- gsub('"[[:space:]]*:[[:space:]]*', '":', meta_txt)
source_description <- function(col) {
  at <- regexpr(paste0('"name":"', col, '"'), meta_txt, fixed = TRUE)
  if (at < 0) return(NA_character_)
  rest <- substr(meta_txt, at, at + 3000L)
  m <- regmatches(rest, regexpr('"description":"([^"\\\\]|\\\\.)*"', rest))
  if (!length(m)) return(NA_character_)
  gsub('^"description":"|"$', "", m)
}
profile_column <- function(col) {
  x <- raw[[col]]
  blank <- x == "" | is.na(x)
  v <- x[!blank]
  num <- suppressWarnings(as.numeric(v))
  is_num <- length(v) > 0 && !anyNA(num)
  top <- sort(table(v), decreasing = TRUE)
  top <- head(top, 3)
  data.table(
    column = col,
    source_description = source_description(col),
    blank_rows = sum(blank),
    blank_pct = pct(sum(blank), length(x), 2),
    distinct_values = uniqueN(v),
    numeric_min = if (is_num) min(num) else NA_real_,
    numeric_max = if (is_num) max(num) else NA_real_,
    most_common = paste(sprintf("%s (%s)", names(top), format(as.integer(top), big.mark = ",",
        trim = TRUE)),
                        collapse = "; ")
  )
}
dictionary <- rbindlist(lapply(names(raw), profile_column))
out(dictionary, "02_data_dictionary.csv")

# 2.2 Short names for the fields used from here on.
setnames(raw,
  c("Clean Alternative Fuel Vehicle Type", "VIN (1-10)", "DOL Vehicle ID", "Model Year", "Make",
    "Model", "Primary Use", "Electric Range", "Odometer Reading", "Odometer Reading Description",
    "New or Used Vehicle", "Sale Price", "Sale Date", "Transaction Type", "Transaction Date",
    "Year", "County", "City", "State", "Postal Code"),
  c("ev_type_raw", "vin10", "vehicle_id", "model_year", "make", "model", "use", "electric_range",
    "odometer", "odometer_code", "new_used", "sale_price", "sale_date_txt", "transaction_type",
    "transaction_date_txt", "year", "county", "city", "state", "postal_code"))
raw[, row_id := .I]
raw[, `:=`(
  transaction_date = as.IDate(transaction_date_txt, format = "%B %d %Y"),
  sale_date        = as.IDate(sale_date_txt, format = "%B %d %Y"),
  year             = as.integer(year),
  model_year       = as.integer(model_year),
  electric_range   = as.numeric(electric_range),
  odometer         = as.numeric(odometer),
  sale_price       = as.numeric(sale_price)
)]
assert(!anyNA(raw$transaction_date), "a transaction date failed to parse")
assert(raw[sale_date_txt != "" & is.na(sale_date), .N] == 0L, "a sale date failed to parse")
assert(raw[year(transaction_date) != year, .N] == 0L, "Year disagrees with Transaction Date")
assert(!anyNA(raw$model_year) && !anyNA(raw$sale_price), "model year or price failed to parse")

# 2.3 Worked example of the New/Used trap: a new car's title says New, but the
# registration made on the same day says Used.
new_titles <- raw[transaction_type == "Original Title" & new_used == "New", .(vehicle_id,
    transaction_date)]
same_day_reg <- raw[transaction_type == "Original Registration"][new_titles, on = .(vehicle_id,
    transaction_date), nomatch = NULL]
example_id <- same_day_reg[order(vehicle_id)][1L, vehicle_id]
label_example <- raw[vehicle_id == example_id][order(transaction_date, row_id)][1:2,
  .(vehicle_id, make, model, model_year, transaction_type, transaction_date, new_used, sale_price)]
out(label_example, "02_new_used_label_example.csv")
say("2. New titles with a same-day registration labelled Used: %s of %s.",
    format(same_day_reg[new_used == "Used", .N], big.mark = ","), format(nrow(new_titles),
        big.mark = ","))

# 2.4 Fields that should never change for one vehicle.
stable <- raw[, .(types = uniqueN(ev_type_raw), years = uniqueN(model_year),
                  makes = uniqueN(make), models = uniqueN(model)), by = vehicle_id]
assert(stable[types > 1 | years > 1 | makes > 1 | models > 1, .N] == 0L,
       "a vehicle changes type, model year, make or model")

# 2.5 What the transaction types contain. The source says only that they are
# "defined by Department of Licensing", so their meaning is read from this table.
tx_profile <- raw[, .(rows = .N, new_label = sum(new_used == "New"),
                      used_label = sum(new_used == "Used"),
                      with_sale_date = sum(!is.na(sale_date)), with_price = sum(sale_price > 0)),
                  by = transaction_type][order(-rows)]
out(tx_profile, "02_transaction_types.csv")
assert(raw[new_used == "New" & transaction_type != "Original Title", .N] == 0L,
       "a New label appears outside Original Title rows")

use_profile <- raw[, .(vehicles = uniqueN(vehicle_id), rows = .N,
                       renewal_rows = sum(transaction_type == "Registration Renewal")), by = use]
use_profile[, renewals_per_vehicle := round(renewal_rows / vehicles, 2)]
out(use_profile[order(-vehicles)], "02_use_classes.csv")
say("2. Imported %s rows, %s vehicles.", format(nrow(raw), big.mark = ","),
    format(uniqueN(raw$vehicle_id), big.mark = ","))


# ---- 3. CLEAN THE RECORDS ---------------------------------------------------

# Each rule's reason is in the comment above it. Each rule works on rows, in this order.
# Use classes dropped: exempt classes have no annual renewal (so exit can't be
# measured for them), and low-speed classes are not general road vehicles.
EXEMPT_USE <- c("Exempt (State/County/Local/Tribal)", "Farm Exempt", "Government (Federal)")
LOWSPEED_USE <- c("Medium-Speed Electric Vehicle", "Medium-Speed Electric Truck",
                  "Neighborhood Electric Vehicle", "Off Road Vehicle")

flow <- list()
add_flow <- function(step, dt, note = "") {
  flow[[length(flow) + 1L]] <<- data.table(step = step, rows = nrow(dt),
                                           vehicles = uniqueN(dt$vehicle_id), note = note)
}
add_flow("Raw file", raw)

# 3.1 Exact duplicate rows (every one of the 33 columns the same).
dup_cols <- setdiff(names(raw), c("row_id", "transaction_date", "sale_date"))
clean <- unique(raw, by = dup_cols)
add_flow("Remove exact duplicate rows", clean)
no_dup <- copy(clean)

# 3.2 Hydrogen vehicles are not plug-in vehicles.
clean <- clean[!grepl("Hydrogen", ev_type_raw)]
clean[, ev_type := fifelse(grepl("BEV", ev_type_raw), "BEV", "PHEV")]
add_flow("Remove hydrogen vehicles", clean)
benchmark_basis <- copy(clean)  # section 9 cross-checks the benchmark figures on this

# 3.3 Keep records with a Washington address and a county, because the question
# is about vehicles in Washington and every spread measure needs a county.
clean <- clean[state == "WA" & county != ""]
add_flow("Keep Washington addresses with a county", clean)

# 3.4 Use classes.
clean <- clean[!use %in% EXEMPT_USE]
add_flow("Remove exempt use classes", clean, "No annual renewal, so exit can't be measured")
clean <- clean[!use %in% LOWSPEED_USE]
add_flow("Remove low-speed and off-road classes", clean, "Not general road vehicles")

# 3.5 Model years before 2008 are genuine early EVs and conversions, so they stay.
# Age is floored at 0, because a car can be sold in the year before its model year.
clean[, age := pmax(year - model_year, 0L)]
assert(clean[year < model_year - 1L, .N] == 0L, "a record is over a year before its model year")

# Within a date: title first, then registration, then renewal.
clean[, tx_order := fcase(transaction_type == "Original Title", 1L,
                          transaction_type == "Original Registration", 2L,
                          transaction_type == "Transfer Title", 3L,
                          transaction_type == "Registration at time of Transfer", 4L,
                          default = 5L)]
setorder(clean, vehicle_id, transaction_date, tx_order, row_id)
say("3. Study records: %s rows, %s vehicles.", format(nrow(clean), big.mark = ","),
    format(uniqueN(clean$vehicle_id), big.mark = ","))


# ---- 4. VEHICLE-YEAR RECORDS ------------------------------------------------

# One row per vehicle per year. County and use come from the last record of the
# year, so a vehicle is placed where it was at the end of that year.
vehicle_year <- clean[, .(
  county = county[.N],
  use = use[.N],
  records = .N,
  counties_in_year = uniqueN(county),
  renewals = sum(transaction_type == "Registration Renewal"),
  transfers = sum(transaction_type == "Transfer Title")
), by = .(vehicle_id, year)]
fixed_fields <- clean[, .(ev_type = ev_type[1], make = make[1], model = model[1],
                          model_year = model_year[1]), by = vehicle_id]
vehicle_year <- merge(vehicle_year, fixed_fields, by = "vehicle_id")
vehicle_year[, age := pmax(year - model_year, 0L)]
vehicle_year[, king := county == "King"]
setorder(vehicle_year, vehicle_id, year)
assert(vehicle_year[, .N, by = .(vehicle_id, year)][N > 1, .N] == 0L, "duplicate vehicle-year")
add_flow("Vehicle-years", vehicle_year)
say("4. Vehicle-years: %s. In two or more counties within a year: %s.",
    format(nrow(vehicle_year), big.mark = ","),
    format(vehicle_year[counties_in_year > 1, .N], big.mark = ","))


# ---- 5. VEHICLE HISTORIES ---------------------------------------------------

# 5.1 Entry route. Registration rows always say Used, even for a new car, so the
# label comes from the first Original Title when there is one. A title up to a
# year after the first registration counts as the same arrival.
first_row <- unique(clean, by = "vehicle_id")[, .(vehicle_id, transaction_type, new_used,
    transaction_date, year, county)]
setnames(first_row, c("vehicle_id", "first_type", "first_label", "entry_date", "entry_year",
                      "entry_county"))
first_title <- clean[transaction_type == "Original Title",
                     .(title_label = new_used[1L], title_date = transaction_date[1L]),
                     by = vehicle_id]
history <- merge(first_row, first_title, by = "vehicle_id", all.x = TRUE)
history[, title_lag_days := as.integer(title_date - entry_date)]
history[, entry_route := fcase(
  first_type == "Original Title" & first_label == "New", "New",
  first_type == "Original Title", "Used, first Washington title",
  first_type == "Original Registration" & !is.na(title_lag_days) & title_lag_days <= 365L &
    title_label == "New", "New",
  first_type == "Original Registration" & !is.na(title_lag_days) & title_lag_days <= 365L,
  "Used, first Washington title",
  first_type == "Original Registration", "Used, registration only",
  default = "Other first record"
)]

# 5.2 The rest of each vehicle's record.
span <- vehicle_year[, .(
  last_year = year[.N],
  years_with_record = .N,
  last_county = county[.N],
  county_moves = sum(county != shift(county), na.rm = TRUE),
  ever_two_counties_in_year = any(counties_in_year > 1L)
), by = vehicle_id]
span[, missing_years := NA_integer_]
transfers <- clean[transaction_type == "Transfer Title", .(transfers = .N), by = vehicle_id]
last_date <- clean[, .(last_date = transaction_date[.N]), by = vehicle_id]
history <- Reduce(function(a, b) merge(a, b, by = "vehicle_id", all.x = TRUE),
                  list(history, span, last_date, transfers, fixed_fields))
history[is.na(transfers), transfers := 0L]
history[, missing_years := (last_year - entry_year + 1L) - years_with_record]
assert(nrow(history) == uniqueN(clean$vehicle_id), "history is not one row per vehicle")
assert(history[missing_years < 0L, .N] == 0L, "negative missing years")
add_flow("Vehicle histories", history)

registration_first <- history[first_type == "Original Registration" & !is.na(title_lag_days) &
                              title_lag_days <= 365L,
                              .(vehicles = .N,
                                median_days_to_title = as.numeric(median(title_lag_days))),
                              keyby = .(entry_year, title_label)]
out(registration_first, "05_registration_before_title.csv")
route_by_year <- dcast(history, entry_year ~ entry_route, fun.aggregate = length,
                       value.var = "vehicle_id")
out(route_by_year, "05_entry_route_by_year.csv")
say("5. Histories built. First record not a title or registration: %s vehicles.",
    format(history[entry_route == "Other first record", .N], big.mark = ","))


# ---- 6. ACTIVE, ENTRY, EXIT AND MOVE ----------------------------------------

# R is a vehicle-by-year table of 0/1: does the vehicle have a record that year?
years <- FIRST_YEAR:LAST_YEAR
ids   <- history$vehicle_id
R <- matrix(FALSE, nrow = length(ids), ncol = length(years), dimnames = list(NULL, years))
R[cbind(match(vehicle_year$vehicle_id, ids), vehicle_year$year - FIRST_YEAR + 1L)] <- TRUE
assert(sum(R) == nrow(vehicle_year), "record table does not match vehicle-years")
col <- function(y) y - FIRST_YEAR + 1L

# Gap-filled active: a record that year, or records in the years either side.
# Two missing years count as an exit, so one missing year is the most a car can
# miss and stay active. This keeps the active and exit definitions consistent.
F <- R
for (y in (FIRST_YEAR + 1L):(LAST_YEAR - 1L)) F[, col(y)] <- R[, col(y)] | (R[, col(y - 1L)] & R[,
    col(y + 1L)])
first_seen <- history$entry_year

# Span count: every year between first and last record, as an upper bound.
span_active <- sapply(years, function(y) history[entry_year <= y & last_year >= y, .N])

flows <- rbindlist(lapply(years, function(y) {
  i <- col(y)
  entering <- first_seen == y
  prev_F <- if (y > FIRST_YEAR) F[, i - 1L] else rep(FALSE, nrow(F))
  next_F <- if (y < LAST_YEAR) F[, i + 1L] else rep(NA, nrow(F))
  data.table(year = y, active_simple = sum(R[, i]), active_filled = sum(F[, i]),
             active_span = span_active[i],
             entries = sum(entering), returns = sum(F[, i] & !prev_F & !entering),
             leavers_after_year = if (y < LAST_YEAR) sum(F[, i] & !next_F) else NA_integer_)
}))
# Only baselines up to 2023 have two full later years, so later leavers aren't final.
flows[, leavers_status := fcase(year <= 2023L, "Two-year exits", year == 2024L,
                                "Provisional: 2026 is partial",
                                year == 2025L, "Not exits: only partial 2026 seen",
                                default = "No later data")]
flows[, gap_filled_extra := active_filled - active_simple]
flows[, gap_filled_extra_pct := pct(gap_filled_extra, active_simple)]
flows[, bev_share := vehicle_year[, .(s = pct(sum(ev_type == "BEV"), .N)), keyby = year]$s]
flows[, mean_age := vehicle_year[, .(a = round(mean(age), 2)), keyby = year]$a]
out(flows, "06_population_flows.csv")

# Exit rule check for every baseline where two full later years exist.
exit_mat <- function(y, k) {
  gone <- R[, col(y)]
  for (j in seq_len(k)) gone <- gone & !R[, col(y + j)]
  gone
}
retention <- rbindlist(lapply(2011:2023, function(y) {
  active <- R[, col(y)]
  e2 <- exit_mat(y, 2L)
  later <- (y + 3L):LAST_YEAR
  back_any <- e2 & rowSums(R[, col(later), drop = FALSE]) > 0L
  back_next <- e2 & R[, col(y + 3L)]
  e3 <- if (y + 3L <= LAST_FULL) exit_mat(y, 3L) else rep(NA, length(active))
  later3 <- if (y + 4L <= LAST_YEAR) (y + 4L):LAST_YEAR else integer()
  back3 <- if (length(later3) && !anyNA(e3)) e3 & rowSums(R[, col(later3),
      drop = FALSE]) > 0L else e3
  data.table(baseline = y, active = sum(active),
             record_next_year_pct = pct(sum(active & R[, col(y + 1L)]), sum(active)),
             exit2 = sum(e2), exit2_pct = pct(sum(e2), sum(active)),
             exit2_returned_any = sum(back_any), returned_any_pct = pct(sum(back_any), sum(e2)),
             exit2_returned_next_year = sum(back_next), returned_next_year_pct = pct(sum(back_next),
                 sum(e2)),
             exit3 = if (anyNA(e3)) NA_integer_ else sum(e3),
             exit3_pct = if (anyNA(e3)) NA_real_ else pct(sum(e3), sum(active)),
             exit3_returned_pct = if (anyNA(e3)) NA_real_ else pct(sum(back3), sum(e3)))
}))
out(retention, "06_exit_by_baseline.csv")

# County moves between consecutive vehicle-years.
moves <- vehicle_year[, .(from = shift(county), to = county, from_year = shift(year), year),
                      by = vehicle_id]
moves <- moves[!is.na(from) & from != to]
move_summary <- moves[, .(moves = .N, leaving_king = sum(from == "King"),
                          entering_king = sum(to == "King")), keyby = year]
out(move_summary, "06_county_moves_by_year.csv")

# 2025 check: are late renewals behind the low 2025 count? Compare the share of
# each year's active vehicles with a registration event in the following year.
reg_rows <- clean[transaction_type %in% c("Original Registration", "Registration Renewal",
                                          "Registration at time of Transfer"),
                  .(vehicle_id, transaction_date)]
setorder(reg_rows, vehicle_id, transaction_date)
reg_rows[, next_date := shift(transaction_date, type = "lead"), by = vehicle_id]
reg_rows[, days_to_next := as.integer(next_date - transaction_date)]
renewal_timing <- reg_rows[transaction_date >= as.IDate("2022-01-01") &
                           transaction_date <= as.IDate("2025-06-30"),
  .(events = .N,
    on_time_300_430_days_pct = pct(sum(days_to_next >= 300L & days_to_next <= 430L, na.rm = TRUE),
                                   .N),
    late_431_760_days_pct = pct(sum(days_to_next > 430L & days_to_next <= 760L, na.rm = TRUE), .N),
    no_later_event_pct = pct(sum(is.na(days_to_next)), .N)),
  by = .(half_year = sprintf("%d-H%d", year(transaction_date),
                             fifelse(month(transaction_date) <= 6L, 1L, 2L)))]
out(renewal_timing[order(half_year)], "06_renewal_timing.csv")

king_share <- vehicle_year[year %in% c(2015L, 2019L, 2025L), .(king = sum(king), all = .N),
                           keyby = year]
filled_king <- rbindlist(lapply(c(2015L, 2019L, 2025L), function(y) {
  a <- F[, col(y)]
  # County for a filled year is the county of the previous record.
  yr_rows <- vehicle_year[year <= y & vehicle_id %in% ids[a]][, .(county = county[.N]),
      by = vehicle_id]
  data.table(year = y, king_filled = yr_rows[county == "King", .N], all_filled = nrow(yr_rows))
}))
king_share <- merge(king_share, filled_king, by = "year")
king_share[, `:=`(king_share_simple = pct(king, all, 2), king_share_filled = pct(king_filled,
    all_filled, 2))]
out(king_share, "06_king_share.csv")
say("6. Exit two-year rate, 2019 baseline: %.1f%%.", retention[baseline == 2019, exit2_pct])


# ---- 7. PRICES (SUPPORTING WORK) --------------------------------------------

# 7.1 CPI. Parsed with a regular expression so no JSON package is needed.
read_cpi <- function(path) {
  txt <- paste(readLines(path, warn = FALSE), collapse = " ")
  m <- regmatches(txt, gregexpr('"year":"[0-9]{4}","period":"M[0-9]{2}"[^}]*?"value":"[^"]*"', txt,
                                perl = TRUE))[[1]]
  data.table(year = as.integer(sub('.*"year":"([0-9]{4})".*', "\\1", m)),
             month = as.integer(sub('.*"period":"M([0-9]{2})".*', "\\1", m)),
             cpi = suppressWarnings(as.numeric(sub('.*"value":"([^"]*)".*', "\\1", m))))
}
cpi <- rbindlist(lapply(CPI_FILES, read_cpi))
setorder(cpi, year, month)
assert(cpi[year == 2022 & month == 6, cpi] == 296.311, "CPI check value, June 2022")
assert(cpi[year == 2019 & month == 1, cpi] == 251.712, "CPI check value, January 2019")
assert(is.na(cpi[year == 2025 & month == 10, cpi]), "October 2025 CPI should be missing")
assert(cpi[is.na(cpi), .N] == 1L, "only October 2025 should be missing")
CPI_BASE <- cpi[year == 2026 & month == 9, cpi]    # all real prices are in September 2026 dollars

# 7.2 Title rows with a price. Registration rows are not used for prices.
titles <- clean[transaction_type %in% c("Original Title", "Transfer Title")]
titles[, price_missing := sale_price == 0]

# 7.3 Prices whose digits are the sale date, such as $62,720 on 27/06/2020.
date_like <- function(price, d) {
  m <- month(d); dd <- mday(d); y <- year(d); yy <- y %% 100L
  forms <- list(sprintf("%d%02d%02d", m, dd, yy), sprintf("%d%d%02d", m, dd, yy),
                sprintf("%d%02d%d", m, dd, y), sprintf("%d%d%d", m, dd, y),
                sprintf("%d%02d%02d", dd, m, yy), sprintf("%d%02d%d", dd, m, y),
                sprintf("%d%02d%02d", y, m, dd), sprintf("%02d%02d%02d", yy, m, dd))
  hit <- rep(FALSE, length(price))
  p <- as.character(as.integer(price))
  for (f in forms) hit <- hit | (!is.na(p) & p == f)
  hit
}
titles[, date_like_price := !price_missing & !is.na(sale_date) & date_like(sale_price, sale_date)]
titles[, price_band := cut(sale_price, c(-Inf, 0, 999.99, 99999.99, 299999.99, 999999.99, Inf),
                           labels = c("0 (missing)", "Under $1,000", "$1,000-$99,999",
                                      "$100,000-$299,999",
                                      "$300,000-$999,999", "$1,000,000 or more"))]
price_bands <- titles[, .(rows = .N, used = sum(new_used == "Used"),
                          date_like = sum(date_like_price)), keyby = price_band]
out(price_bands, "07_price_bands.csv")
high_prices <- titles[sale_price >= 100000 & sale_price < 1000000,
                      .(rows = .N, median_price = median(sale_price),
                        date_like = sum(date_like_price)),
                      by = .(make, new_used)][order(-rows)]
out(high_prices, "07_high_prices_by_make.csv")

# 7.4 Sale events: one per vehicle and sale date. Conflicting prices are set aside.
PRICE_MIN <- 1000; PRICE_MAX <- 300000
usable <- titles[!price_missing & !is.na(sale_date) & !date_like_price &
                 sale_price >= PRICE_MIN & sale_price <= PRICE_MAX]
conflict <- usable[, .(prices = uniqueN(sale_price)), by = .(vehicle_id, sale_date)][prices > 1L]
sale_events <- usable[!conflict, on = .(vehicle_id, sale_date)]
sale_events <- unique(sale_events, by = c("vehicle_id", "sale_date"))
out(usable[conflict, on = .(vehicle_id, sale_date)][, .(vehicle_id, sale_date, sale_price,
    transaction_type, new_used)],
    "07_same_day_price_conflicts.csv")

# 7.5 Real prices.
sale_events[, `:=`(sale_y = year(sale_date), sale_m = month(sale_date))]
sale_events <- merge(sale_events, cpi, by.x = c("sale_y", "sale_m"), by.y = c("year", "month"),
                     all.x = TRUE)
assert(sale_events[is.na(cpi) & !(sale_y == 2025 & sale_m == 10), .N] == 0L,
       "a sale month has no CPI")
sale_events[, real_price := sale_price * CPI_BASE / cpi]
ratio <- sale_events[!is.na(cpi), .(r = mean(real_price / sale_price)), keyby = sale_y]
assert(uniqueN(round(ratio$r, 3)) > 10L, "real/nominal ratio does not vary by year")

# 7.6 Mileage, kept as a separate sample from price.
setorder(sale_events, vehicle_id, sale_date)
sale_events[, odometer_ok_code := odometer_code == "Actual Mileage" & odometer > 0]
sale_events[, prev_odometer := shift(fifelse(odometer_ok_code, odometer, NA_real_)),
            by = vehicle_id]
sale_events[, odometer_fell := odometer_ok_code & !is.na(prev_odometer) & odometer < prev_odometer]
sale_events[, odometer_too_high := odometer_ok_code & odometer > 400000]
sale_events[, mileage_sample := odometer_ok_code & !odometer_fell & !odometer_too_high]
sale_events[, sale_age := pmax(sale_y - model_year, 0L)]
price_flow <- data.table(
  step = c("Title rows", "Price recorded", "Sale date recorded", "Not date-like",
           "$1,000 to $300,000",
           "After removing same-day conflicts (sale events)", "With CPI (excludes October 2025)",
           "Used sale events", "Used sale events in the mileage sample"),
  rows = c(nrow(titles), titles[price_missing == FALSE, .N], titles[!price_missing &
      !is.na(sale_date), .N],
           titles[!price_missing & !is.na(sale_date) & !date_like_price, .N], nrow(usable),
           nrow(sale_events),
           sale_events[!is.na(cpi), .N], sale_events[new_used == "Used", .N],
           sale_events[new_used == "Used" & mileage_sample == TRUE, .N]))
out(price_flow, "07_price_flow.csv")
odometer_checks <- sale_events[new_used == "Used", .(used_events = .N,
    actual_mileage = sum(odometer_ok_code),
                                                     fell = sum(odometer_fell),
                                                         over_400k = sum(odometer_too_high))]
out(odometer_checks, "07_odometer_checks.csv")
say("7. Sale events: %s. Same-day conflicts set aside: %d. Date-like prices flagged: %d.",
    format(nrow(sale_events), big.mark = ","), nrow(conflict), titles[date_like_price == TRUE, .N])


# ---- 8. SPECIFICATION FIELDS ------------------------------------------------

# The field holds a positive range, 0, or nothing. Both 0 and blank mean not recorded.
clean[is.na(electric_range), electric_range := 0]
range_vehicle <- clean[, .(range = max(electric_range),
                           ranges = uniqueN(electric_range[electric_range > 0]),
                           ev_type = ev_type[1L], model_year = model_year[1L]), by = vehicle_id]
range_by_year <- range_vehicle[model_year >= 2011L, .(vehicles = .N, recorded = sum(range > 0)),
                               keyby = .(model_year, ev_type)]
range_by_year[, recorded_pct := pct(recorded, vehicles)]
out(dcast(range_by_year, model_year ~ ev_type, value.var = c("vehicles", "recorded_pct")),
    "08_electric_range_by_model_year.csv")
say("8. Vehicles whose recorded range changes over time: %d.", range_vehicle[ranges > 1L, .N])


# ---- 9. RECONCILE AND CROSS-CHECK -------------------------------------------

# 9.1 Stock and flow. Active next year = active + entries + returns - leavers.
flows[, change_next := shift(active_filled, type = "lead") - active_filled]
flows[, explained_next := shift(entries, type = "lead") + shift(returns,
    type = "lead") - leavers_after_year]
assert(flows[year < LAST_YEAR, all(change_next == explained_next)],
       "stock and flow do not reconcile")
assert(flows[, sum(entries)] == nrow(history), "entries do not add up to the number of vehicles")

# A filled-count leaver is exactly a two-year exit, for every baseline with two later years.
for (y in FIRST_YEAR:(LAST_YEAR - 2L)) {
  leavers <- F[, col(y)] & !F[, col(y + 1L)]
  assert(all(leavers == exit_mat(y, 2L)), paste("leavers differ from two-year exits in", y))
}
out(flows, "09_stock_flow_reconciliation.csv")

# 9.2 County totals now add up to the state total (each vehicle-year has one county).
county_year <- vehicle_year[, .(vehicles = .N, bev = sum(ev_type == "BEV")), by = .(county, year)]
assert(all(county_year[, .(s = sum(vehicles)), keyby = year]$s == flows$active_simple),
       "county totals differ from state")
out(county_year[order(year, -vehicles)], "09_county_year.csv")

# 9.3 Flow table, and how each rule changes the population.
flow_table <- rbindlist(flow)
flow_table[, rows_removed := shift(rows) - rows]
flow_table[step %in% c("Vehicle-years", "Vehicle histories"), rows_removed := NA]
out(flow_table, "09_flow_table.csv")

rule_effect <- function(label, dt) {
  a <- dt[year == 2025L, .(vehicle_id, county, transaction_date)]
  setorder(a, vehicle_id, transaction_date)
  a <- a[, .(county = county[.N]), by = vehicle_id]
  data.table(rule_stage = label, vehicles_ever = uniqueN(dt$vehicle_id), active_2025 = nrow(a),
             king_share_2025 = pct(a[county == "King", .N], nrow(a), 2))
}
rule_table <- rbindlist(list(
  rule_effect("After removing duplicates", no_dup),
  rule_effect("After removing hydrogen", benchmark_basis),
  rule_effect("After keeping Washington addresses", benchmark_basis[state == "WA" & county != ""]),
  rule_effect("After removing exempt classes", benchmark_basis[state == "WA" & county != "" &
      !use %in% EXEMPT_USE]),
  rule_effect("After removing low-speed classes (study population)", clean),
  rule_effect("Sensitivity: passenger class only", clean[use == "Passenger"])
))
out(rule_table, "09_rule_effects.csv")

# 9.4 Independent cross-check. Benchmark figures were computed separately, before
# this script was written, from the data portal (data.wa.gov API). Repeat each one
# on its own basis (hydrogen removed from the population counts, no other rule),
# then on this script's rules.
pb <- benchmark_basis
pb_vy <- unique(pb[, .(vehicle_id, year, ev_type)])
active_pb <- pb_vy[, .(active = .N, bev = pct(sum(ev_type == "BEV"), .N)), keyby = year]
age_pb <- pb[transaction_type == "Registration Renewal", .(a = round(mean(year - model_year), 1)),
             keyby = year]
county_pb <- unique(pb[county != "" & state == "WA", .(vehicle_id, year, county)])[, .(n = .N),
    by = .(county, year)]
share_king <- function(y) county_pb[year == y, pct(sum(n[county == "King"]), sum(n))]
growth <- merge(county_pb[year == 2019L, .(county, n19 = n)], county_pb[year == 2025L, .(county,
    n25 = n)], by = "county")
growth[, g := log(n25 / n19)]
bev_county <- unique(pb[county != "" & state == "WA", .(vehicle_id, year, county, ev_type)])[
  year %in% c(2019L, 2025L), .(s = 100 * mean(ev_type == "BEV"), n = .N), by = .(county, year)]
bev_w <- dcast(bev_county, county ~ year, value.var = "s")
setnames(bev_w, c("county", "s19", "s25"))
bev_w <- bev_w[!is.na(s19) & !is.na(s25) & county != "Garfield"]
bev_t <- t.test(bev_w$s25, bev_w$s19, paired = TRUE)

no_dup_titles <- no_dup[transaction_type %in% c("Original Title", "Transfer Title") &
                        state == "WA" & county != ""]
no_dup_titles[, route := fcase(transaction_type == "Transfer Title", "Transfer",
                               new_used == "New", "New first title", default = "Used first title")]
used_share <- function(y, king, months = 1:12) {
  x <- no_dup_titles[year == y & (county == "King") == king & month(transaction_date) %in% months]
  pct(x[route != "New first title", .N], nrow(x))
}
jan_sep <- function(y, r) no_dup[year == y & month(transaction_date) <= 9L &
  transaction_type %in% c("Original Title", "Transfer Title"),
  sum(fcase(transaction_type == "Transfer Title", "Transfer", new_used == "New", "New first title",
            default = "Used first title") == r)]

last_pb <- pb[, .(last = max(year), first = min(year), type = ev_type[1L], my = model_year[1L],
                  make = make[1L]), by = vehicle_id]
last_seen <- function(y, t) last_pb[my == y & type == t, pct(sum(last <= 2024L), .N)]
make_gone <- function(m) last_pb[first <= 2022L & make == m, pct(sum(last <= 2024L), .N)]

pb_R <- pb_vy[, .(vehicle_id, year)]
exit_pb <- function(y) {
  a <- pb_R[year == y, vehicle_id]
  ex <- setdiff(a, pb_R[year %in% (y + 1L):(y + 2L), vehicle_id])
  back <- pb_R[year > y + 2L & vehicle_id %in% ex, uniqueN(vehicle_id)]
  c(pct(length(ex), length(a)), pct(back, length(ex)))
}

ti_pb <- raw[transaction_type %in% c("Original Title", "Transfer Title")]
screened <- ti_pb[sale_price >= PRICE_MIN & sale_price <= PRICE_MAX]
used_mean <- function(y) screened[new_used == "Used" & year == y, round(mean(sale_price))]
sales_per_car <- screened[!is.na(sale_date), .(n = uniqueN(sale_date)), by = vehicle_id][, .N,
    keyby = n]
spc <- function(k) sales_per_car[n == k, N]

# Specification model on used sales, as the benchmark defined it.
spec <- sale_events[new_used == "Used" & mileage_sample == TRUE & !is.na(cpi)]
spec[, make_grouped := fifelse(make %in% spec[, .N, by = make][N >= 100L, make], make, "Other")]
spec_fit <- lm(log(real_price) ~ sale_age + odometer + ev_type + make_grouped, data = spec)
# The benchmark's 0.62 matches this simpler form: nominal price and the ten largest makes.
spec_bench <- sale_events[new_used == "Used" & odometer_ok_code == TRUE]
top10 <- spec_bench[, .N, by = make][order(-N)][1:10, make]
spec_bench[, make_top10 := fifelse(make %in% top10, make, "Other")]
spec_bench_fit <- lm(log(sale_price) ~ sale_age + odometer + ev_type + make_top10,
                     data = spec_bench)

a <- function(check, benchmark, r, note = "") data.table(check = check,
    benchmark = as.character(benchmark),
    r = as.character(r), note = note)
audit <- rbindlist(list(
  a("Rows", "1,926,507", nrow(raw)),
  a("Distinct vehicles", "401,956", uniqueN(raw$vehicle_id)),
  a("BEV vehicles", "320,505", pb[ev_type == "BEV", uniqueN(vehicle_id)]),
  a("PHEV vehicles", "81,430", pb[ev_type == "PHEV", uniqueN(vehicle_id)]),
  a("Rows from Washington residents", "1,918,273", raw[state == "WA", .N]),
  a("Counties (Washington addresses)", "39", raw[state == "WA" & county != "", uniqueN(county)]),
  a("Vehicles in more than one county", "58,391", no_dup[county != "", .(n = uniqueN(county)),
      by = vehicle_id][n > 1L, .N], "Includes hydrogen, as the benchmark did"),
  a("Active 2013", "7,551", active_pb[year == 2013L, active]),
  a("Active 2016", "21,153", active_pb[year == 2016L, active]),
  a("Active 2019", "53,220", active_pb[year == 2019L, active]),
  a("Active 2022", "115,710", active_pb[year == 2022L, active]),
  a("Active 2024", "226,087", active_pb[year == 2024L, active]),
  a("Active 2025", "271,957", active_pb[year == 2025L, active]),
  a("BEV share 2013", "69.9", active_pb[year == 2013L, bev]),
  a("BEV share 2019", "69.0", active_pb[year == 2019L, bev]),
  a("BEV share 2025", "79.8", active_pb[year == 2025L, bev]),
  a("Mean age 2013 (renewal rows)", "1.3", age_pb[year == 2013L, a]),
  a("Mean age 2019 (renewal rows)", "3.2", age_pb[year == 2019L, a]),
  a("Mean age 2022 (renewal rows)", "3.9", age_pb[year == 2022L, a]),
  a("Mean age 2025 (renewal rows)", "3.6", age_pb[year == 2025L, a]),
  a("King share 2015, summed counties", "56.8", share_king(2015L)),
  a("King share 2019, summed counties", "54.9", share_king(2019L)),
  a("King share 2025, summed counties", "49.5", share_king(2025L)),
  a("Counties growing faster than King, 2019-25", "35 of 39", sprintf("%d of %d",
      growth[county != "King" & g > growth[county == "King", g], .N], nrow(growth))),
  a("Mean county log growth", "1.80", round(mean(growth$g), 2)),
  a("SD county log growth", "0.26", round(sd(growth$g), 2)),
  a("King log growth", "1.53", round(growth[county == "King", g], 2)),
  a("Mean rise in county BEV share (points)", "17.5", round(mean(bev_w$s25 - bev_w$s19), 2),
    "Without Garfield, as the benchmark did"),
  a("Paired counties for BEV share", "38", nrow(bev_w), "Garfield left out: one vehicle in 2019"),
  a("t for BEV share rise", "about 12", round(unname(bev_t$statistic), 1), "Without Garfield"),
  a("Used share 2019, King", "36.0", used_share(2019L, TRUE)),
  a("Used share 2019, rest", "47.7", used_share(2019L, FALSE)),
  a("Used share 2022, King", "24.3", used_share(2022L, TRUE)),
  a("Used share 2022, rest", "34.9", used_share(2022L, FALSE)),
  a("Used share 2025, King", "37.7", used_share(2025L, TRUE)),
  a("Used share 2025, rest", "45.9", used_share(2025L, FALSE)),
  a("Used share 2026 Jan-Sep, King", "48.0", used_share(2026L, TRUE, 1:9)),
  a("Used share 2026 Jan-Sep, rest", "57.1", used_share(2026L, FALSE, 1:9)),
  a("New first titles Jan-Sep 2025", "42,362", jan_sep(2025L, "New first title")),
  a("New first titles Jan-Sep 2026", "31,142", jan_sep(2026L, "New first title")),
  a("Used first titles Jan-Sep 2025", "12,888", jan_sep(2025L, "Used first title")),
  a("Used first titles Jan-Sep 2026", "17,053", jan_sep(2026L, "Used first title")),
  a("Transfers Jan-Sep 2025", "16,207", jan_sep(2025L, "Transfer")),
  a("Transfers Jan-Sep 2026", "18,337", jan_sep(2026L, "Transfer")),
  a("Two-year exit, 2019 baseline", "7.1", exit_pb(2019L)[1]),
  a("Two-year exit, 2021 baseline", "7.4", exit_pb(2021L)[1]),
  a("Two-year exit, 2023 baseline", "7.9", exit_pb(2023L)[1]),
  a("Exits returning later, 2019 baseline", "11-17 range", exit_pb(2019L)[2]),
  a("Exits returning later, 2021 baseline", "11-17 range", exit_pb(2021L)[2]),
  a("Exits returning later, 2023 baseline", "11-17 range", exit_pb(2023L)[2]),
  a("Last seen by 2024, model year 2013 BEV", "51.7", last_seen(2013L, "BEV")),
  a("Last seen by 2024, model year 2013 PHEV", "41.0", last_seen(2013L, "PHEV")),
  a("Last seen by 2024, model year 2017 BEV", "33.3", last_seen(2017L, "BEV")),
  a("Last seen by 2024, model year 2020 PHEV", "22.1", last_seen(2020L, "PHEV")),
  a("Last seen by 2024, model year 2022 BEV", "15.1", last_seen(2022L, "BEV")),
  a("Left by make: Nissan", "45.2", make_gone("NISSAN")),
  a("Left by make: Tesla", "27.0", make_gone("TESLA")),
  a("Left by make: Volkswagen", "19.7", make_gone("VOLKSWAGEN")),
  a("Priced title rows, $1,000-$300,000", "432,623", nrow(screened)),
  a("Rows $100,000 to $1,000,000", "13,575", ti_pb[sale_price > 100000 & sale_price < 1000000, .N],
    "Excludes the two end values, as the benchmark did"),
  a("Mean used price 2019", "22,378", used_mean(2019L),
    "By transaction year, as the benchmark did. Sale year is used from here on"),
  a("Mean used price 2022", "40,701", used_mean(2022L), "By transaction year"),
  a("Mean used price 2025", "29,889", used_mean(2025L), "By transaction year"),
  a("Cars with one title sale", "311,874", spc(1L),
    "Not exactly reproduced; difference under 0.01%"),
  a("Cars with two title sales", "46,854", spc(2L),
    "Not exactly reproduced; difference under 0.01%"),
  a("Cars with three title sales", "7,096", spc(3L)),
  a("Cars with four title sales", "1,153", spc(4L)),
  a("Used sales in the specification model", "143,404", nrow(spec),
    "Project rules: October 2025 has no CPI, so those sales drop out"),
  a("R-squared, nominal price and top 10 makes", "0.62", round(summary(spec_bench_fit)$r.squared,
      3), "Matches the benchmark; its make grouping was not recorded, so this is inferred"),
  a("R-squared of the specification model", "0.62", round(summary(spec_fit)$r.squared, 3),
    "Project rules: real price, makes with 100+ sales")
))
out(audit, "09_benchmark_cross_check.csv")

# 9.5 Vehicle histories for hand-checking. Ten vehicles across the main cases.
pick <- function(cond, n) history[eval(cond)][sample(.N, n), vehicle_id]
check_ids <- c(pick(quote(entry_route == "New" & transfers == 0L & last_year >= 2025L), 2L),
               pick(quote(transfers >= 2L), 2L),
               pick(quote(county_moves >= 2L), 2L),
               pick(quote(missing_years >= 2L), 2L),
               pick(quote(entry_route == "Used, registration only"), 1L),
               pick(quote(last_year <= 2022L), 1L))
hand_check <- history[vehicle_id %in% check_ids,
                      .(vehicle_id, make, model, model_year, entry_date, entry_route, last_date,
                        years_with_record,
                        missing_years, transfers, county_moves, entry_county, last_county)]
out(hand_check, "09_hand_check_vehicles.csv")

# 9.6 Saved outputs and package versions.
saveRDS(vehicle_year, file.path(PRO, "vehicle_year.rds"))
saveRDS(history, file.path(PRO, "vehicle_history.rds"))
saveRDS(sale_events, file.path(PRO, "sale_events.rds"))
writeLines(capture.output(sessionInfo()), file.path(TAB, "00_session_info.txt"))
say("9. All reconciliation checks passed.")

# ---- 10. DESCRIPTIVE STATISTICS AND CORRELATION -----------------------------

# 10.0 Figure style. Colours are a colour-blind-checked palette: BEV blue, PHEV orange.
FIG <- "outputs/figures"
INK <- "#0b0b0b"; INK2 <- "#52514e"; GRIDCOL <- "#e4e3df"; SURFACE <- "#fcfcfb"
COL1 <- "#2a78d6"; COL2 <- "#eb6834"; COL3 <- "#1baf7a"; COL4 <- "#eda100"
TYPE_COLS <- c(BEV = COL1, PHEV = COL2)
SOURCE_NOTE <- paste("Source: Washington State Department of Licensing, EV title and registration",
                     "records, extract of 7 Nov 2026.")
theme_set(theme_minimal(base_size = 11) + theme(
  plot.background = element_rect(fill = SURFACE, colour = NA),
  panel.grid.minor = element_blank(),
  panel.grid.major = element_line(colour = GRIDCOL, linewidth = 0.3),
  plot.title = element_text(face = "bold", size = 12, colour = INK),
  plot.subtitle = element_text(colour = INK2, size = 9.5),
  plot.caption = element_text(colour = INK2, size = 7.5, hjust = 0),
  axis.text = element_text(colour = INK2), axis.title = element_text(colour = INK2, size = 9.5),
  legend.position = "top", legend.justification = "left", legend.title = element_blank()))
fig <- function(p, name, w = 7, h = 4.5) {
  ggsave(file.path(FIG, name), p, width = w, height = h, dpi = 200, bg = SURFACE)
  invisible(name)
}
comma <- function(x) format(round(x), big.mark = ",", trim = TRUE)

# A frequency table drawn as a PNG, so every table in the report is an image too.
table_png <- function(dt, name, title, note = SOURCE_NOTE) {
  d <- as.data.frame(dt)
  d[] <- lapply(d, function(x) if (is.numeric(x)) {
    if (all(x == round(x), na.rm = TRUE)) comma(x)
    else fifelse(is.na(x), "NA", fifelse(abs(x) >= 100, comma(x), formatC(x, format = "f",
        digits = 2)))
  } else as.character(x))
  w <- pmax(nchar(names(d)), vapply(d, function(x) max(nchar(x)), 0)) + 3
  x_mid <- cumsum(w) - w / 2
  cells <- data.table(x = rep(x_mid, each = nrow(d)), y = -rep(seq_len(nrow(d)), ncol(d)),
                      txt = unlist(d))
  head  <- data.table(x = x_mid, y = 0, txt = names(d))
  p <- ggplot() +
    geom_text(data = head, aes(x, y, label = txt), fontface = "bold", size = 3.1, colour = INK) +
    geom_text(data = cells, aes(x, y, label = txt), size = 3.1, colour = INK) +
    geom_hline(yintercept = -0.5, colour = INK2, linewidth = 0.3) +
    scale_x_continuous(limits = c(0, sum(w))) + scale_y_continuous(limits = c(-nrow(d) - 0.6,
        0.6)) +
    labs(title = title, caption = note) + theme_void() +
    theme(plot.background = element_rect(fill = SURFACE, colour = NA),
          plot.title = element_text(face = "bold", size = 11),
          plot.caption = element_text(colour = INK2, size = 7, hjust = 0), plot.margin = margin(8,
              8, 8, 8))
  fig(p, name, w = max(4.5, sum(w) * 0.085), h = 0.9 + 0.24 * (nrow(d) + 1))
}

# 10.1 Regions. Eastern Washington is the 20 counties east of the Cascade crest.
# King is shown on its own because it holds about half the population.
EAST <- c("Adams", "Asotin", "Benton", "Chelan", "Columbia", "Douglas", "Ferry", "Franklin",
          "Garfield",
          "Grant", "Kittitas", "Klickitat", "Lincoln", "Okanogan", "Pend Oreille", "Spokane",
          "Stevens",
          "Walla Walla", "Whitman", "Yakima")
region_of <- function(county) fcase(county == "King", "King", county %in% EAST,
                                    "Eastern Washington",
                                    default = "Western Washington (not King)")
assert(all(EAST %in% vehicle_year$county), "an Eastern county name is not in the data")
assert(uniqueN(vehicle_year$county) == 39L, "expected 39 counties")
vehicle_year[, region := region_of(county)]

# 10.2 Frequency tables: vehicles by year and type, make, and county.
freq_year <- vehicle_year[, .(BEV = sum(ev_type == "BEV"), PHEV = sum(ev_type == "PHEV"),
                              Total = .N), keyby = .(Year = year)]
freq_year[, `BEV %` := round(100 * BEV / Total, 1)]
freq_year[Year == LAST_YEAR, Year := NA]     # labelled below
freq_year <- freq_year[, .(Year = fifelse(is.na(Year), "2026 (Jan-Sep)", as.character(Year)), BEV,
                           PHEV, Total, `BEV %`)]
out(freq_year, "10_freq_vehicles_by_year_type.csv")
table_png(freq_year, "10_01_table_vehicles_by_year_type.png",
          "Active plug-in vehicles by year and type (vehicles with a record that year)")

act25 <- vehicle_year[year == LAST_FULL]
top_makes_25 <- act25[, .N, by = make][order(-N)]
top_makes_25[, rank := .I]
freq_make <- rbind(top_makes_25[rank <= 10L, .(Make = make, Vehicles = N)],
                   data.table(Make = sprintf("Other (%d makes)", top_makes_25[rank > 10L, .N]),
                              Vehicles = top_makes_25[rank > 10L, sum(N)]))
freq_make[, `Share %` := round(100 * Vehicles / nrow(act25), 1)]
out(freq_make, "10_freq_makes_2025.csv")
table_png(freq_make, "10_02_table_makes_2025.png", sprintf("Active vehicles by make, 2025 (n = %s)",
    comma(nrow(act25))))

freq_county <- act25[, .(Vehicles = .N, `BEV %` = round(100 * mean(ev_type == "BEV"), 1)),
                     by = .(County = county, Region = region)][order(-Vehicles)]
freq_county[, `Share %` := round(100 * Vehicles / nrow(act25), 1)]
out(freq_county, "10_freq_counties_2025.csv")
table_png(freq_county, "10_03_table_counties_2025.png",
          sprintf("Active vehicles by county, 2025 (n = %s)", comma(nrow(act25))))

route_tab <- history[entry_year <= LAST_FULL, .N, keyby = .(entry_year, entry_route)]
route_wide <- dcast(route_tab, entry_year ~ entry_route, value.var = "N", fill = 0)
setnames(route_wide, "entry_year", "Entry year")
out(route_wide, "10_freq_entry_routes.csv")
table_png(route_wide, "10_04_table_entry_routes.png",
          "Vehicles entering the population, by entry route")

# 10.3 County measures. Starting values are 2019, the baseline of the spread test.
county_tab <- vehicle_year[year %in% c(2019L, LAST_FULL),
  .(stock = .N, bev_share = mean(ev_type == "BEV")), by = .(county, year)]
county_tab <- dcast(county_tab, county ~ year, value.var = c("stock", "bev_share"))
setnames(county_tab, c("county", "stock_2019", "stock_2025", "bev_share_2019", "bev_share_2025"))
assert(nrow(county_tab) == 39L && !anyNA(county_tab), "a county has no vehicles in 2019 or 2025")
not_new_2019 <- merge(vehicle_year[year == 2019L, .(vehicle_id, county)], history[, .(vehicle_id,
    entry_route)], by = "vehicle_id")
not_new_2019 <- not_new_2019[, .(used_share_2019 = mean(entry_route != "New")), by = county]
county_tab <- merge(county_tab, not_new_2019, by = "county")
county_tab[, `:=`(region = region_of(county), log_stock_2019 = log(stock_2019),
                  growth = log(stock_2025 / stock_2019))]
# z-scores show which counties are unusual on each measure.
for (v in c("log_stock_2019", "growth", "used_share_2019", "bev_share_2019"))
  set(county_tab, j = paste0("z_", v), value = as.numeric(scale(county_tab[[v]])))
out(county_tab[order(-stock_2025)], "10_county_measures.csv")

# 10.4 Descriptive statistics. The mode uses rounded values for continuous measures.
describe <- function(x, measure, unit, mode_unit = 1) {
  x <- x[!is.na(x)]
  r <- round(x / mode_unit) * mode_unit
  tb <- table(r)
  data.table(measure = measure, unit = unit, n = length(x), mean = mean(x), median = median(x),
             mode = if (max(tb) > 1L) as.numeric(names(tb)[which.max(tb)]) else NA_real_,
             mode_rounded_to = mode_unit, variance = var(x), sd = sd(x), iqr = IQR(x),
             q1 = unname(quantile(x, 0.25)), q3 = unname(quantile(x, 0.75)), min = min(x),
             max = max(x),
             skewness = moments::skewness(x), kurtosis = moments::kurtosis(x),
             excess_kurtosis = moments::kurtosis(x) - 3)
}
used_sales <- sale_events[new_used == "Used" & !is.na(cpi)]
mileage <- sale_events[new_used == "Used" & mileage_sample == TRUE]
descriptives <- rbindlist(list(
  describe(vehicle_year[year == 2019L, age], "Vehicle age, active 2019", "years"),
  describe(act25$age, "Vehicle age, active 2025", "years"),
  describe(used_sales$real_price, "Used sale price, real", "Sep 2026 dollars", 1000),
  describe(mileage$odometer, "Odometer at used sale", "miles", 1000),
  describe(county_tab$stock_2025, "County stock, 2025", "vehicles", 1),
  describe(county_tab$growth, "County log growth, 2019-25", "log ratio", 0.1)
))
num_cols <- setdiff(names(descriptives)[vapply(descriptives, is.numeric, TRUE)], "n")
descriptives[, (num_cols) := lapply(.SD, function(x) signif(x, 5)), .SDcols = num_cols]
out(descriptives, "10_descriptives.csv")
table_png(descriptives[, .(measure, unit, n, mean, median, mode, sd, iqr, skewness, kurtosis)],
          "10_05_table_descriptives.png",
          "Descriptive statistics (mode of continuous measures uses rounded values)")

# 10.5 Covariance and correlation between county measures, and between sale measures.
cm <- county_tab[, .(log_stock_2019, growth, used_share_2019, bev_share_2019)]
# Kendall's tau takes time proportional to n squared, so for the 141,000 sales it
# uses a random 5,000; Pearson and Spearman use every sale.
corr_long <- function(m, label, kendall_n = Inf) {
  cp <- cor(m, method = "pearson")
  cs <- cor(m, method = "spearman")
  mk <- if (nrow(m) > kendall_n) m[sample(.N, kendall_n)] else m
  ck <- cor(mk, method = "kendall")
  cv <- cov(m)
  g <- CJ(a = colnames(m), b = colnames(m))[a < b]
  g[, `:=`(set = label, covariance = cv[cbind(a, b)], pearson = cp[cbind(a, b)],
           spearman = cs[cbind(a, b)], kendall = ck[cbind(a, b)], kendall_n = nrow(mk))]
  g[, pearson_p := mapply(function(i, j) cor.test(m[[i]], m[[j]])$p.value, a, b)]
  g[]
}
set.seed(20261107)
sale_corr <- mileage[!is.na(cpi), .(sale_age, odometer, log_real_price = log(real_price))]
correlations <- rbind(corr_long(cm, "39 counties"),
                      corr_long(sale_corr, "Used sales, mileage sample", kendall_n = 5000L))
out(correlations, "10_correlations.csv")
say("10. Descriptives done. Pearson r, county growth and log 2019 stock: %.2f.",
    correlations[set == "39 counties" & ((a == "growth" & b == "log_stock_2019") | (b == "growth" &
        a == "log_stock_2019")), pearson])


# ---- 11. VISUALISATIONS OF POPULATION CHANGE --------------------------------

yrs_full <- FIRST_YEAR:LAST_FULL
cap_n <- function(n) sprintf("%s
n = %s.", SOURCE_NOTE, n)

# 11.1 Active population, simple and gap-filled.
pop_line <- melt(flows[year <= LAST_FULL, .(year, `Record that year` = active_simple,
    `Gap-filled` = active_filled)],
                 id.vars = "year")
p <- ggplot(pop_line, aes(year, value, colour = variable)) + geom_line(linewidth = 0.9) +
  geom_point(size = 1.6) +
  scale_colour_manual(values = c(COL1, COL2)) + scale_y_continuous(labels = scales::comma) +
  scale_x_continuous(breaks = seq(2010, 2025, 3)) +
  labs(title = "Washington's active plug-in vehicle population, 2010-2025",
       subtitle = "Gap-filled also counts a vehicle missing one year between two recorded years",
       x = "Year", y = "Active vehicles", caption = cap_n(comma(nrow(history))))
fig(p, "11_01_active_population.png")

# 11.2 King County's share.
king_year <- vehicle_year[year <= LAST_FULL, .(share = 100 * mean(king), n = .N), keyby = year]
p <- ggplot(king_year[year >= 2012L], aes(year, share)) + geom_line(colour = COL1,
    linewidth = 0.9) + geom_point(colour = COL1, size = 1.6) +
  geom_hline(yintercept = 50, colour = INK2, linetype = "dashed", linewidth = 0.3) +
  scale_x_continuous(breaks = seq(2012, 2025, 2)) +
  labs(title = "King County's share of active plug-in vehicles",
       subtitle = "County at the vehicle's last record of each year",
       x = "Year", y = "King share (%)", caption = cap_n(sprintf("%s (2012) to %s (2025)",
           comma(king_year[year == 2012L, n]), comma(king_year[year == 2025L, n]))))
fig(p, "11_02_king_share.png")

# 11.3 Used share of title activity (first titles plus transfers), King and the rest.
title_act <- clean[transaction_type %in% c("Original Title", "Transfer Title") & year <= LAST_FULL]
title_act[, route := fcase(transaction_type == "Transfer Title", "Transfer", new_used == "New",
                           "New first title",
                           default = "Used first title")]
title_act[, area := fifelse(county == "King", "King", "Rest of state")]
used_share_year <- title_act[, .(used_share = 100 * mean(route != "New first title"), titles = .N),
                             keyby = .(year, area)]
out(used_share_year, "11_used_share_of_titles.csv")
p <- ggplot(used_share_year[year >= 2012L], aes(year, used_share, colour = area)) +
  geom_line(linewidth = 0.9) + geom_point(size = 1.6) +
  scale_colour_manual(values = c(King = COL1, `Rest of state` = COL2)) +
    scale_x_continuous(breaks = seq(2012, 2025, 2)) +
  labs(title = "Used share of title activity",
       subtitle = "Used first Washington titles plus transfers, as a share of all titles",
       x = "Year", y = "Used share (%)", caption = cap_n(comma(nrow(title_act))))
fig(p, "11_03_used_share.png")

# 11.4 Entry routes by year.
route_plot <- copy(route_tab)
# 493 vehicles; too few to show
route_plot[entry_route == "Other first record", entry_route := "Used, registration only"]
route_plot <- route_plot[, .(N = sum(N)), by = .(entry_year, entry_route)]
route_plot[, entry_route := factor(entry_route, levels = c("New", "Used, first Washington title",
    "Used, registration only"))]
p <- ggplot(route_plot[entry_year >= 2011L], aes(entry_year, N, fill = entry_route)) +
  geom_col(width = 0.8, colour = SURFACE, linewidth = 0.3) +
  scale_fill_manual(values = c(COL1, COL2, COL3), labels = c("New", "Used, first WA title",
      "Used, registration only (incl. 493 other)")) +
  scale_y_continuous(labels = scales::comma) + scale_x_continuous(breaks = seq(2011, 2025, 2)) +
  labs(title = "How vehicles entered the population", x = "Year of first record",
       y = "Vehicles entering",
       caption = cap_n(comma(history[entry_year <= LAST_FULL, .N])))
fig(p, "11_04_entry_routes.png")

# 11.5 Top makes, 2025.
mk <- top_makes_25[rank <= 10L]
p <- ggplot(mk, aes(N, reorder(make, N))) + geom_col(fill = COL1, width = 0.7) +
  geom_text(aes(label = comma(N)), hjust = -0.1, size = 3, colour = INK) +
  scale_x_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Ten largest makes in the 2025 active population", x = "Active vehicles", y = NULL,
       caption = cap_n(comma(nrow(act25))))
fig(p, "11_05_top_makes_2025.png")

# 11.6 BEV and PHEV share, 2025.
pie <- act25[, .N, by = ev_type][, share := 100 * N / sum(N)]
p <- ggplot(pie, aes(x = "", y = N, fill = ev_type)) + geom_col(width = 1, colour = SURFACE,
    linewidth = 1) +
  coord_polar(theta = "y") + scale_fill_manual(values = TYPE_COLS) +
  geom_text(aes(label = sprintf("%s\n%.1f%%\n(%s)", ev_type, share, comma(N))),
            position = position_stack(vjust = 0.5),
            colour = "white", size = 3.6, fontface = "bold") +
  labs(title = "BEV and PHEV share of active vehicles, 2025", x = NULL, y = NULL,
       caption = cap_n(comma(nrow(act25)))) +
  theme(axis.text = element_blank(), panel.grid = element_blank(), legend.position = "none")
fig(p, "11_06_type_share_2025.png", w = 5.5, h = 5)

# 11.7 Vehicle age, 2025.
p <- ggplot(act25, aes(age)) + geom_histogram(binwidth = 1, fill = COL1, colour = SURFACE) +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Age of active vehicles, 2025",
       subtitle = "Age = 2025 minus model year (floored at 0)",
       x = "Age (years)", y = "Vehicles", caption = cap_n(comma(nrow(act25))))
fig(p, "11_07_age_histogram_2025.png")

# 11.8 Real used sale price.
p <- ggplot(used_sales, aes(real_price / 1000)) + geom_histogram(binwidth = 2.5, fill = COL1,
    colour = SURFACE, boundary = 0) +
  scale_y_continuous(labels = scales::comma) + coord_cartesian(xlim = c(0, 150)) +
  labs(title = "Used sale prices, in September 2026 dollars",
       subtitle = "Screened $1,000-$300,000 nominal; axis cut at $150,000",
       x = "Real price ($ thousands)", y = "Sales", caption = cap_n(comma(nrow(used_sales))))
fig(p, "11_08_used_price_histogram.png")

# 11.9 Vehicle age by year.
p <- ggplot(vehicle_year[year >= 2012L & year <= LAST_FULL], aes(factor(year), age)) +
  geom_boxplot(fill = "#cde2fb", colour = COL1, outlier.size = 0.3, outlier.alpha = 0.2,
               linewidth = 0.4) +
  stat_summary(fun = mean, geom = "point", colour = COL2, size = 1.6) +
  labs(title = "Age of active vehicles by year",
       subtitle = "Box = median and quartiles; orange point = mean",
       x = "Year", y = "Age (years)", caption = cap_n(comma(vehicle_year[year >= 2012L &
           year <= LAST_FULL, .N])))
fig(p, "11_09_age_by_year_boxplot.png")

# 11.10 County growth by region.
p <- ggplot(county_tab, aes(region, growth)) +
  geom_boxplot(data = county_tab[region != "King"], fill = "#cde2fb", colour = COL1, width = 0.5,
               outlier.shape = NA) +
  geom_jitter(width = 0.08, height = 0, size = 1.6, colour = INK2) +
  geom_point(data = county_tab[region == "King"], colour = COL2, size = 3) +
  labs(title = "County growth in active vehicles, 2019-2025, by region",
       subtitle = "Log growth: log(2025 stock / 2019 stock); points are counties",
       x = NULL, y = "Log growth", caption = cap_n("39 counties"))
fig(p, "11_10_county_growth_by_region.png")

# 11.11 County growth against starting stock.
county_tab[, label := fifelse(county %in% c("King", "Garfield", "Columbia", "Ferry", "Snohomish",
    "Spokane") |
                                abs(z_growth) > 2, county, "")]
p <- ggplot(county_tab, aes(stock_2019, growth)) +
  geom_smooth(method = "lm", formula = y ~ x, colour = COL2, fill = "#fbd3c2", linewidth = 0.7) +
  geom_point(aes(colour = region), size = 2) + geom_text(aes(label = label), size = 2.8,
      vjust = -0.8, colour = INK) +
  scale_x_log10(labels = scales::comma) + scale_colour_manual(values = c(COL3, COL2, COL1)) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.12))) +
  labs(title = "County growth against starting stock, 2019-2025",
       subtitle = "Line: least-squares fit with 95% confidence band (section 14.1)",
       x = "Active vehicles in 2019 (log scale)", y = "Log growth, 2019-2025",
       caption = cap_n("39 counties"))
fig(p, "11_11_growth_vs_stock.png")

# 11.12 Population pyramid by model year, 2025.
pyr <- act25[model_year >= 2011L, .N, by = .(model_year, ev_type)]
pyr[, signed := fifelse(ev_type == "BEV", -N, N)]
p <- ggplot(pyr, aes(signed, factor(model_year), fill = ev_type)) + geom_col(width = 0.8) +
  geom_vline(xintercept = 0, colour = INK2, linewidth = 0.3) +
  scale_x_continuous(labels = function(x) scales::comma(abs(x))) +
    scale_fill_manual(values = TYPE_COLS) +
  labs(title = "The 2025 population by model year",
       subtitle = "BEVs to the left, PHEVs to the right",
       x = "Active vehicles", y = "Model year", caption = cap_n(comma(act25[model_year >= 2011L,
           .N])))
fig(p, "11_12_model_year_pyramid_2025.png", h = 5.5)
say("11. Figures written to %s.", FIG)


# ---- 12. PROBABILITY AND DISTRIBUTIONS --------------------------------------

set.seed(20261107)

# 12.1 Weekly new-vehicle entries: Poisson against negative binomial, same terms.
# Weeks run Monday to Sunday. Only whole weeks inside 2010 to 30 September 2026.
week_start <- function(d) d - (as.integer(format(as.Date(d), "%u")) - 1L)
first_week <- as.IDate("2010-01-04"); last_week <- as.IDate("2026-09-21")
weekly <- data.table(week = seq(first_week, last_week, by = 7L))
new_wk <- history[entry_route == "New", .(n = .N), by = .(week = week_start(entry_date))]
weekly <- merge(weekly, new_wk, by = "week", all.x = TRUE)
weekly[is.na(n), n := 0L]
weekly[, t := as.numeric(week - first_week) / 365.25]
weekly[, `:=`(s1 = sin(2 * pi * t), c1 = cos(2 * pi * t), s2 = sin(4 * pi * t),
              c2 = cos(4 * pi * t))]
# one trend knot per year, two seasonal waves
wk_formula <- n ~ splines::ns(t, df = 17) + s1 + c1 + s2 + c2
pois_fit <- glm(wk_formula, family = poisson, data = weekly)
# glm.nb can't find its own starting values here, so it starts from the Poisson fit.
nb_fit <- MASS::glm.nb(wk_formula, data = weekly, start = coef(pois_fit), init.theta = 5)
dispersion <- sum(residuals(pois_fit, type = "pearson")^2) / df.residual(pois_fit)
lr_nb <- 2 * (as.numeric(logLik(nb_fit)) - as.numeric(logLik(pois_fit)))
weekly[, `:=`(fit_pois = fitted(pois_fit), fit_nb = fitted(nb_fit))]
count_models <- data.table(
  model = c("Poisson", "Negative binomial"),
  weeks = nrow(weekly), zero_weeks_observed = weekly[n == 0L, .N],
  zero_weeks_expected = c(sum(dpois(0, weekly$fit_pois)), sum(dnbinom(0, size = nb_fit$theta,
      mu = weekly$fit_nb))),
  aic = c(AIC(pois_fit), AIC(nb_fit)), log_lik = c(logLik(pois_fit), logLik(nb_fit)),
  pearson_dispersion = c(dispersion, sum(residuals(nb_fit,
      type = "pearson")^2) / df.residual(nb_fit)),
  theta = c(NA, nb_fit$theta),
  lr_stat_vs_poisson = c(NA, lr_nb), lr_p = c(NA, 0.5 * pchisq(lr_nb, 1, lower.tail = FALSE)))
out(count_models, "12_weekly_entry_models.csv")
nb_band <- weekly[, .(week, lo = qnbinom(0.025, size = nb_fit$theta, mu = fit_nb),
                      hi = qnbinom(0.975, size = nb_fit$theta, mu = fit_nb))]
pois_band <- weekly[, .(week, lo = qpois(0.025, fit_pois), hi = qpois(0.975, fit_pois))]
coverage <- c(pois = weekly[, mean(n >= pois_band$lo & n <= pois_band$hi)], nb = weekly[,
    mean(n >= nb_band$lo & n <= nb_band$hi)])
p <- ggplot(weekly, aes(as.Date(week))) +
  geom_ribbon(data = nb_band, aes(as.Date(week), ymin = lo, ymax = hi), inherit.aes = FALSE,
              fill = "#cde2fb") +
  geom_line(aes(y = n), colour = INK2, linewidth = 0.25) + geom_line(aes(y = fit_nb), colour = COL1,
      linewidth = 0.8) +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Weekly new-vehicle entries with the negative binomial fit",
       subtitle = sprintf(paste("Band: 95%% NB prediction interval, covering %.0f%% of weeks",
                                "(Poisson band: %.0f%%)"),
                          100 * coverage["nb"], 100 * coverage["pois"]),
       x = "Week", y = "New vehicles entering", caption = cap_n(sprintf("%s weeks, %s vehicles",
           comma(nrow(weekly)), comma(sum(weekly$n)))))
fig(p, "12_01_weekly_entries_nb.png")

# 12.2 Binomial: exits out of n vehicles. The cohort is model-year 2013 vehicles
# active in 2021, and p0 is the 2019 baseline exit rate for all vehicles.
p0 <- retention[baseline == 2019L, exit2 / active]
d21_ids <- vehicle_year[year == 2021L & model_year == 2013L, vehicle_id]
x_exit <- sum(exit_mat(2021L, 2L)[match(d21_ids, ids)])
n_c <- length(d21_ids)
norm_tail <- function(x, n, p, cc) pnorm(x - cc, mean = n * p, sd = sqrt(n * p * (1 - p)),
    lower.tail = FALSE)
binom_cohort <- data.table(cohort = "Model year 2013, active 2021", n = n_c, exits = x_exit,
                           observed_rate = x_exit / n_c, p0 = p0,
                           exact_p_at_least = pbinom(x_exit - 1L, n_c, p0, lower.tail = FALSE),
                           normal_cc = norm_tail(x_exit, n_c, p0, 0.5),
                           normal_no_cc = norm_tail(x_exit, n_c, p0, 0))
out(binom_cohort, "12_binomial_cohort.csv")
# How good is the normal approximation as n grows? P(X <= k) at k near the mean.
approx_tab <- rbindlist(lapply(c(10L, 30L, 100L, 300L, 1000L), function(n) {
  k <- floor(n * p0)
  ex <- pbinom(k, n, p0)
  data.table(n = n, k = k, np = n * p0, exact = ex,
             normal_cc = pnorm(k + 0.5, n * p0, sqrt(n * p0 * (1 - p0))),
             normal_no_cc = pnorm(k, n * p0, sqrt(n * p0 * (1 - p0))))
}))
approx_tab[, `:=`(error_cc = normal_cc - exact, error_no_cc = normal_no_cc - exact)]
out(approx_tab, "12_binomial_normal_approximation.csv")
bn <- 100L
pmf <- data.table(k = 0:25)[, `:=`(exact = dbinom(k, bn, p0),
                                   normal = pnorm(k + 0.5, bn * p0,
                                       sqrt(bn * p0 * (1 - p0))) - pnorm(k - 0.5, bn * p0,
                                       sqrt(bn * p0 * (1 - p0))))]
p <- ggplot(pmf, aes(k)) + geom_col(aes(y = exact), fill = COL1, width = 0.7) +
  geom_line(aes(y = normal), colour = COL2, linewidth = 0.8) + geom_point(aes(y = normal),
      colour = COL2, size = 1.4) +
  labs(title = sprintf("Exits among %d vehicles: Binomial against normal approximation", bn),
       subtitle = sprintf(paste("p = %.3f (2019 baseline). Bars: exact Binomial.",
                                "Line: normal with continuity correction"), p0),
       x = "Vehicles leaving within two years", y = "Probability", caption = SOURCE_NOTE)
fig(p, "12_02_binomial_vs_normal.png")

# 12.3 Geometric: sale events per car, overall and within fixed model-year cohorts,
# because cars of different ages have had different lengths of time to be resold.
spc_car <- sale_events[, .(sales = .N), by = .(vehicle_id, model_year)]
geo_fit <- function(dt, label) {
  ph <- 1 / mean(dt$sales)
  obs <- dt[, .(observed = .N), keyby = .(k = pmin(sales, 5L))]
  obs[, expected := nrow(dt) * fifelse(k < 5L, ph * (1 - ph)^(k - 1L), (1 - ph)^4)]
  chi <- obs[, sum((observed - expected)^2 / expected)]
  obs[, `:=`(group = label, cars = nrow(dt), p_hat = ph, chi_sq = chi, df = .N - 2L,
             gof_p = pchisq(chi, .N - 2L, lower.tail = FALSE))]
}
geometric <- rbindlist(list(geo_fit(spc_car, "All cars"),
                            geo_fit(spc_car[model_year == 2013L], "Model year 2013"),
                            geo_fit(spc_car[model_year == 2017L], "Model year 2017"),
                            geo_fit(spc_car[model_year == 2021L], "Model year 2021")))
out(geometric, "12_geometric_sales_per_car.csv")
gp <- melt(geometric[group != "All cars", .(group, k = fifelse(k == 5L, "5+", as.character(k)),
    Observed = as.numeric(observed), Geometric = expected)],
           id.vars = c("group", "k"))
p <- ggplot(gp, aes(k, value, fill = variable)) + geom_col(position = position_dodge(0.8),
    width = 0.75) +
  facet_wrap(~group, scales = "free_y") + scale_fill_manual(values = c(COL1, COL2)) +
    scale_y_continuous(labels = scales::comma) +
  labs(title = "Title sales per car against a geometric distribution",
       subtitle = "Within model-year cohorts; p estimated as 1 / mean sales",
       x = "Title sales recorded", y = "Cars", caption = cap_n(comma(nrow(spc_car))))
fig(p, "12_03_geometric_sales.png", w = 8)

# 12.4 Central limit theorem: sample means of vehicle age from the 2025 population.
age_pop <- act25$age
mu_age <- mean(age_pop); sigma_age <- sd(age_pop)
clt <- rbindlist(lapply(c(5L, 30L, 100L, 500L), function(n) data.table(n = n,
    mean_age = replicate(2000L, mean(sample(age_pop, n))))))
clt_summary <- clt[, .(samples = .N, mean_of_means = mean(mean_age), sd_of_means = sd(mean_age),
                       sigma_over_root_n = sigma_age / sqrt(n[1]),
                       skewness = moments::skewness(mean_age)), keyby = n]
clt_summary[, `:=`(population_mean = mu_age, population_sd = sigma_age,
                   population_skewness = moments::skewness(age_pop))]
out(clt_summary, "12_clt_summary.csv")
curves <- clt[, .(x = seq(min(mean_age), max(mean_age), length.out = 200)), by = n][
  , y := dnorm(x, mu_age, sigma_age / sqrt(n))]
clt[, panel := factor(sprintf("n = %d", n), levels = sprintf("n = %d", c(5, 30, 100, 500)))]
curves[, panel := factor(sprintf("n = %d", n), levels = levels(clt$panel))]
# Ages are whole years, so sample means sit on steps of 1/n. Bins follow those steps.
lattice_bins <- function(x) { u <- sort(unique(round(x, 6))); s <- min(diff(u)); s * max(1,
    ceiling(diff(range(x)) / 40 / s)) }
p <- ggplot(clt, aes(mean_age)) + geom_histogram(aes(y = after_stat(density)),
    binwidth = lattice_bins, center = 0, fill = COL1, colour = SURFACE) +
  geom_line(data = curves, aes(x, y), colour = COL2, linewidth = 0.8) + facet_wrap(~panel,
      scales = "free") +
  labs(title = "Sample means of vehicle age approach a normal curve",
       subtitle = sprintf(paste("2,000 samples per n from the 2025 population (mean %.2f, SD %.2f,",
                                "skewness %.2f). Line: normal(mu, sigma/sqrt(n))"),
                          mu_age, sigma_age, moments::skewness(age_pop)),
       x = "Sample mean age (years)", y = "Density", caption = cap_n(comma(length(age_pop))))
fig(p, "12_04_clt_vehicle_age.png", w = 8, h = 5.5)
say("12. Weekly entries: Poisson dispersion %.1f; NB AIC %.0f against Poisson %.0f.", dispersion,
    AIC(nb_fit), AIC(pois_fit))


# ---- 13. HYPOTHESIS TESTING -------------------------------------------------

# The records cover nearly every recorded vehicle, so they are not a random sample.
# Each test asks whether a difference is larger than year-to-year chance would give.
set.seed(20261107)
tests <- list()
add_test <- function(test, role, h0, estimate, ci_low, ci_high, statistic, df, p, effect, n,
                     note = "") {
  tests[[length(tests) + 1L]] <<- data.table(test, role, h0, estimate, ci_low, ci_high, statistic,
      df = as.numeric(df),
                                             p_value = p, effect_size = effect, n = n, note)
}

# 13.1 Main spread test: King's share, 2025 against 2019.
ks <- vehicle_year[year %in% c(2019L, 2025L), .(king = sum(king), all = .N), keyby = year]
spread_test <- prop.test(c(ks[year == 2025L, king], ks[year == 2019L, king]), c(ks[year == 2025L,
    all], ks[year == 2019L, all]), correct = FALSE)
p25 <- ks[year == 2025L, king / all]; p19 <- ks[year == 2019L, king / all]
add_test("Two-proportion z: King share 2025 vs 2019", "Main: spread",
         "King's share is the same in 2025 as in 2019",
         100 * (p25 - p19), 100 * spread_test$conf.int[1], 100 * spread_test$conf.int[2],
         sqrt(unname(spread_test$statistic)) * sign(p25 - p19),
         NA, spread_test$p.value, sprintf("Cohen's h = %.3f",
             2 * asin(sqrt(p25)) - 2 * asin(sqrt(p19))),
         sum(ks$all),
         "Estimate in percentage points. Many vehicles are in both years, so the groups overlap")
# Sensitivity with gap-filled counts.
filled_county <- function(y) {
  a <- ids[F[, col(y)]]
  vehicle_year[year <= y & vehicle_id %in% a][, .(county = county[.N]), by = vehicle_id]
}
kf <- rbindlist(lapply(c(2025L, 2019L), function(y) filled_county(y)[, .(year = y,
    king = sum(county == "King"), all = .N)]))
spread_filled <- prop.test(kf$king, kf$all, correct = FALSE)
f25 <- kf[year == 2025L, king / all]; f19 <- kf[year == 2019L, king / all]
add_test("Two-proportion z: King share 2025 vs 2019, gap-filled", "Sensitivity",
         "As above, gap-filled counts",
         100 * (f25 - f19), 100 * spread_filled$conf.int[1], 100 * spread_filled$conf.int[2],
         sqrt(unname(spread_filled$statistic)) * sign(f25 - f19), NA, spread_filled$p.value,
         sprintf("Cohen's h = %.3f", 2 * asin(sqrt(f25)) - 2 * asin(sqrt(f19))), sum(kf$all))

# 13.2 Main retention test: BEV against PHEV, adjusted for age (single years, 15+ pooled).
TRAIN_YEAR <- 2021L; TEST_YEAR <- 2023L
baseline_data <- function(y) {
  a <- vehicle_year[year == y, .(vehicle_id, age, ev_type, make, county, region, use)]
  a[, exit2 := as.integer(exit_mat(y, 2L)[match(vehicle_id, ids)])]
  prior <- vehicle_year[year <= y, .(prior_transfers = sum(transfers)), by = vehicle_id]
  a <- merge(a, prior, by = "vehicle_id")
  a <- merge(a, history[, .(vehicle_id, entry_year, entry_route)], by = "vehicle_id")
  a[, `:=`(tenure = y - entry_year, baseline = y, age_f = factor(pmin(age, 15L)))]
  a[, ev_type := factor(ev_type, levels = c("BEV", "PHEV"))]
  a[]
}
retention_test <- function(y) {
  d <- baseline_data(y)
  m1 <- glm(exit2 ~ ev_type + age_f, family = binomial, data = d)
  m0 <- glm(exit2 ~ age_f, family = binomial, data = d)
  b <- coef(summary(m1))["ev_typePHEV", ]
  lr <- anova(m0, m1, test = "LRT")
  std <- sapply(c("BEV", "PHEV"), function(t) mean(predict(m1, newdata = copy(d)[,
      ev_type := factor(t, levels = levels(d$ev_type))], type = "response")))
  list(d = d, or = exp(b[1]), lo = exp(b[1] - 1.96 * b[2]), hi = exp(b[1] + 1.96 * b[2]),
       lr = lr$Deviance[2], p = lr$`Pr(>Chi)`[2], std = std, n = nrow(d))
}
rt <- lapply(c(2019L, TRAIN_YEAR, TEST_YEAR), retention_test)
names(rt) <- c(2019L, TRAIN_YEAR, TEST_YEAR)
for (y in names(rt)) {
  r <- rt[[y]]
  add_test(sprintf("Logistic LR test: PHEV vs BEV exit, adjusted for age, %s baseline", y),
           if (y == as.character(TRAIN_YEAR)) "Main: retention" else "Sensitivity",
           paste("After adjusting for age, BEVs and PHEVs have the same probability",
                 "of leaving within two years"),
           r$or, r$lo, r$hi, r$lr, 1, r$p,
           sprintf("Adjusted exit: BEV %.2f%%, PHEV %.2f%%", 100 * r$std["BEV"],
                   100 * r$std["PHEV"]), r$n,
           "Estimate is the PHEV odds ratio, Wald 95% interval")
}

# 13.3 One-sample z for a mean: is the mean age of a random sample of 500 vehicles
# from 2025 equal to the 2019 mean? A z-test needs sigma known. The full 2025 records
# give it (3.01), so the 2019 SD (2.23), which would understate the spread, isn't used.
age19 <- vehicle_year[year == 2019L, age]
mu0 <- mean(age19); sigma0 <- sd(age_pop); n_z <- 500L
smp <- sample(age_pop, n_z)
z_mean <- (mean(smp) - mu0) / (sigma0 / sqrt(n_z))
add_test("One-sample z (mean): age of a 2025 sample vs 2019 mean", "Supporting",
         sprintf("Mean age in 2025 = %.3f (2019 mean)", mu0),
         mean(smp), mean(smp) - 1.96 * sigma0 / sqrt(n_z), mean(smp) + 1.96 * sigma0 / sqrt(n_z),
         z_mean, NA, 2 * pnorm(-abs(z_mean)),
         sprintf("d = %.3f", (mean(smp) - mu0) / sigma0), n_z,
         sprintf("sigma = %.3f, the 2025 population SD. The 2025 population mean is %.3f", sigma0,
                 mu_age))

# 13.4 One-sample z for a proportion: share of 2023 vehicles that left, against
# the 2019 baseline rate as the benchmark.
d23 <- rt[[as.character(TEST_YEAR)]]$d
ph <- mean(d23$exit2); n23 <- nrow(d23)
z_p <- (ph - p0) / sqrt(p0 * (1 - p0) / n23)
add_test("One-sample z (proportion): 2023 exit share vs 2019 rate", "Supporting",
         sprintf("2023 exit share = %.4f (2019 rate)", p0),
         100 * ph, 100 * (ph - 1.96 * sqrt(ph * (1 - ph) / n23)), 100 * (ph +
             1.96 * sqrt(ph * (1 - ph) / n23)), z_p, NA,
         2 * pnorm(-abs(z_p)), sprintf("Cohen's h = %.3f", 2 * asin(sqrt(ph)) - 2 * asin(sqrt(p0))),
         n23, "Estimate in percent")

# 13.5 One-sample t: mean county log growth against King's growth.
g_king <- county_tab[county == "King", growth]
others <- county_tab[county != "King"]
MIN_COUNTY <- 10L     # shares and growth from fewer vehicles move too much per vehicle
t1 <- t.test(others$growth, mu = g_king); w1 <- wilcox.test(others$growth, mu = g_king,
    exact = FALSE)
add_test("One-sample t: county log growth vs King's growth", "Supporting",
         sprintf("Mean growth of the other 38 counties = %.3f (King)", g_king),
         unname(t1$estimate), t1$conf.int[1], t1$conf.int[2], unname(t1$statistic),
         unname(t1$parameter), t1$p.value,
         sprintf("d = %.2f; Wilcoxon p = %.2g", (mean(others$growth) - g_king) / sd(others$growth),
                 w1$p.value), nrow(others))
t1b <- t.test(others[stock_2019 >= MIN_COUNTY, growth], mu = g_king)
add_test("One-sample t: as above, counties with 10+ vehicles in 2019", "Sensitivity", "As above",
         unname(t1b$estimate), t1b$conf.int[1], t1b$conf.int[2], unname(t1b$statistic),
         unname(t1b$parameter), t1b$p.value, "",
         others[stock_2019 >= MIN_COUNTY, .N])

# 13.6 Paired t: county BEV share, 2025 against 2019, with a Wilcoxon check.
pb_c <- county_tab[stock_2019 >= MIN_COUNTY]
t2 <- t.test(100 * pb_c$bev_share_2025, 100 * pb_c$bev_share_2019, paired = TRUE)
w2 <- wilcox.test(pb_c$bev_share_2025, pb_c$bev_share_2019, paired = TRUE, exact = FALSE)
dd <- 100 * (pb_c$bev_share_2025 - pb_c$bev_share_2019)
add_test("Paired t: county BEV share 2025 vs 2019", "Supporting",
         "Mean change in county BEV share = 0",
         unname(t2$estimate), t2$conf.int[1], t2$conf.int[2], unname(t2$statistic),
         unname(t2$parameter), t2$p.value,
         sprintf("d_z = %.2f; Wilcoxon p = %.2g", mean(dd) / sd(dd), w2$p.value), nrow(pb_c),
         sprintf("Counties with %d+ vehicles in 2019; estimate in percentage points", MIN_COUNTY))

# 13.7 Welch t: age at last record, BEV against PHEV, for vehicles that left the
# records (last record in 2023 or earlier, so no record in 2024 to 2026).
left <- history[last_year <= 2023L, .(ev_type, age_last = pmax(last_year - model_year, 0L))]
t3 <- t.test(age_last ~ ev_type, data = left, var.equal = FALSE)
sd_pool <- left[, sqrt(((sum(ev_type == "BEV") - 1) * var(age_last[ev_type == "BEV"]) +
                        (sum(ev_type == "PHEV") - 1) *
                          var(age_last[ev_type == "PHEV"])) / (.N - 2))]
add_test("Welch t: age at last record, BEV vs PHEV", "Supporting",
         "Mean age at last record is the same for BEVs and PHEVs",
         unname(t3$estimate[1] - t3$estimate[2]), t3$conf.int[1], t3$conf.int[2],
         unname(t3$statistic), unname(t3$parameter), t3$p.value,
         sprintf("d = %.2f; means BEV %.2f, PHEV %.2f", (t3$estimate[1] - t3$estimate[2]) / sd_pool,
                 t3$estimate[1], t3$estimate[2]),
         nrow(left), "Estimate is BEV minus PHEV, in years")

# 13.8 Feature separation at the 2021 baseline: do vehicles that left differ from
# those that stayed? Welch t on age, and a chi-square test on prior transfers.
d21 <- rt[[as.character(TRAIN_YEAR)]]$d
d21[, outcome := factor(fifelse(exit2 == 1L, "Left", "Stayed"), levels = c("Left", "Stayed"))]
t4 <- t.test(age ~ outcome, data = d21, var.equal = FALSE)
w4 <- wilcox.test(age ~ outcome, data = d21, exact = FALSE)
sd4 <- d21[, sqrt(((sum(exit2) - 1) * var(age[exit2 == 1L]) +
                     (sum(exit2 == 0L) - 1) * var(age[exit2 == 0L])) / (.N - 2))]
add_test("Welch t: age at the 2021 baseline, vehicles that left vs stayed",
         "Supporting: feature separation", "Mean age is the same for leavers and stayers",
         unname(t4$estimate[1] - t4$estimate[2]), t4$conf.int[1], t4$conf.int[2],
         unname(t4$statistic), unname(t4$parameter), t4$p.value,
         sprintf("d = %.2f; Wilcoxon p = %.2g; means left %.2f, stayed %.2f",
                 (t4$estimate[1] - t4$estimate[2]) / sd4, w4$p.value, t4$estimate[1],
                 t4$estimate[2]),
         nrow(d21), "Estimate is left minus stayed, in years")
d21[, transfers_g := fcase(prior_transfers == 0L, "0", prior_transfers == 1L, "1", default = "2+")]
tab_tr <- table(d21$transfers_g, d21$outcome)
chi_tr <- chisq.test(tab_tr)
add_test("Chi-square: exit by prior transfers (0, 1, 2+), 2021 baseline",
         "Supporting: feature separation", "Leaving is independent of prior transfers",
         NA, NA, NA, unname(chi_tr$statistic), unname(chi_tr$parameter), chi_tr$p.value,
         sprintf("Cramer's V = %.3f; exit %% by group: %s",
                 sqrt(chi_tr$statistic / sum(tab_tr) / (min(dim(tab_tr)) - 1)),
                 paste(sprintf("%s %.1f", rownames(tab_tr), 100 * prop.table(tab_tr, 1)[, "Left"]),
                       collapse = ", ")),
         sum(tab_tr))

test_table <- rbindlist(tests)
n_families <- test_table[!role %in% c("Sensitivity"), .N]
test_table[, bonferroni_ok := p_value < 0.05 / n_families]
out(test_table, "13_hypothesis_tests.csv")
say("13. %d tests (%d headline or supporting). Main spread p = %.2g; main retention OR = %.2f.",
    nrow(test_table), n_families, spread_test$p.value, rt[[as.character(TRAIN_YEAR)]]$or)

# 13.9 Analysis of variance (course Chapter 8). Helpers for the assumption checks.
# Levene's test with the median (the Brown-Forsythe form, car::leveneTest's default).
levene_test <- function(y, g) {
  a <- anova(lm(abs(y - ave(y, g, FUN = median)) ~ g))
  data.table(test = "Levene (median)", statistic = a$`F value`[1], df1 = a$Df[1],
             df2 = a$Df[2], p = a$`Pr(>F)`[1])
}
aov_table <- function(x, label) {
  s <- if (inherits(x, "aov")) summary(x)[[1]] else x[[1]]   # an aov fit or one stratum's summary
  d <- as.data.table(s, keep.rownames = "term")
  setnames(d, c("term", "df", "sum_sq", "mean_sq", "f", "p"))
  d[, `:=`(analysis = label, term = trimws(term))]
  d[]
}

# 13.10 One-way ANOVA: county log growth 2019-25 by size class (thirds of the
# 2019 stock, 13 counties each). Does growth differ between small and large counties?
county_tab[, size_class := cut(rank(stock_2019, ties.method = "first"), 3,
                               labels = c("Small", "Medium", "Large"))]
aov1 <- aov(growth ~ size_class, data = county_tab)
aov1_tab <- aov_table(aov1, "One-way: growth by size class")
aov1_tab[, eta_sq := sum_sq / sum(sum_sq)]
group_check <- county_tab[, .(n = .N, mean_growth = mean(growth), sd_growth = sd(growth),
                              shapiro_p = shapiro.test(growth)$p.value), keyby = size_class]
assumptions1 <- rbind(
  levene_test(county_tab$growth, county_tab$size_class),
  data.table(test = "Shapiro-Wilk on residuals",
             statistic = shapiro.test(residuals(aov1))$statistic,
             df1 = NA, df2 = NA, p = shapiro.test(residuals(aov1))$p.value),
  with(oneway.test(growth ~ size_class, data = county_tab),
       data.table(test = "Welch ANOVA (unequal variances)", statistic = statistic,
                  df1 = parameter[1], df2 = parameter[2], p = p.value)),
  with(kruskal.test(growth ~ size_class, data = county_tab),
       data.table(test = "Kruskal-Wallis (no normality)", statistic = statistic,
                  df1 = parameter, df2 = NA, p = p.value)))
# The primary test is chosen from the assumption checks, never from the p-values:
#   residuals not normal (Shapiro p < 0.05)      -> Kruskal-Wallis
#   normal, but variances unequal (Levene p < 0.05) -> Welch ANOVA
#   both checks pass                              -> classic one-way ANOVA
# The other two are reported as sensitivity checks. Here both checks pass, so the
# classic ANOVA is primary.
levene_p1  <- assumptions1[test == "Levene (median)", p]
shapiro_p1 <- assumptions1[test == "Shapiro-Wilk on residuals", p]
primary1 <- if (shapiro_p1 < 0.05) "Kruskal-Wallis (no normality)" else
  if (levene_p1 < 0.05) "Welch ANOVA (unequal variances)" else "Classic one-way ANOVA"
oneway_results <- rbind(
  data.table(test = "Classic one-way ANOVA", statistic = aov1_tab[term == "size_class", f],
             df1 = aov1_tab[term == "size_class", df], df2 = aov1_tab[term == "Residuals", df],
             p = aov1_tab[term == "size_class", p]),
  assumptions1[test %in% c("Welch ANOVA (unequal variances)", "Kruskal-Wallis (no normality)")])
oneway_results[, role := fifelse(test == primary1, "Primary (chosen by the assumption checks)",
                                 "Sensitivity check")]
oneway_results[, `:=`(levene_p = levene_p1, shapiro_p = shapiro_p1)]
tukey1 <- as.data.table(TukeyHSD(aov1)$size_class, keep.rownames = "comparison")
setnames(tukey1, c("comparison", "difference", "ci_low", "ci_high", "p_adjusted"))
out(oneway_results, "13_anova_oneway_primary.csv")
out(aov1_tab, "13_anova_oneway.csv")
out(group_check, "13_anova_oneway_groups.csv")
out(assumptions1, "13_anova_oneway_assumptions.csv")
out(tukey1, "13_anova_oneway_tukey.csv")
p <- ggplot(county_tab, aes(size_class, growth)) +
  geom_boxplot(fill = "#cde2fb", colour = COL1, width = 0.5, outlier.shape = NA) +
  geom_jitter(width = 0.08, height = 0, size = 1.6, colour = INK2) +
  stat_summary(fun = mean, geom = "point", colour = COL2, size = 2.6) +
  labs(title = "County growth by size class, 2019-2025",
       subtitle = sprintf(paste("Primary: %s, p = %.2g (Levene p = %.2f, Shapiro p = %.2f).",
                                "\nOrange: group mean"),
                          primary1, oneway_results[test == primary1, p], levene_p1, shapiro_p1),
       x = "Size class (thirds of the 2019 stock)", y = "Log growth",
       caption = cap_n("39 counties, 13 per class"))
fig(p, "13_01_anova_growth_by_size.png")

# 13.11 Two-way ANOVA: size class and side of the Cascades (King is Western). Cells
# hold 2 to 10 counties, so this is exploratory. Sums of squares are sequential.
county_tab[, side := factor(fifelse(county %in% EAST, "Eastern", "Western"),
                            levels = c("Western", "Eastern"))]
aov2 <- aov(growth ~ size_class * side, data = county_tab)
aov2_tab <- aov_table(aov2, "Two-way: growth by size class and side")
aov2_cells <- county_tab[, .(n = .N, mean_growth = mean(growth)), keyby = .(size_class, side)]
out(aov2_tab, "13_anova_twoway.csv")
out(aov2_cells, "13_anova_twoway_cells.csv")
p <- ggplot(aov2_cells, aes(size_class, mean_growth, colour = side, group = side)) +
  geom_line(linewidth = 0.9) + geom_point(aes(size = n)) +
  scale_colour_manual(values = c(Western = COL1, Eastern = COL2)) + scale_size(range = c(2, 5)) +
  labs(title = "Interaction plot: county growth by size class and side",
       subtitle = sprintf("Interaction p = %.2g. Point size: counties in the cell",
                          aov2_tab[term == "size_class:side", p]),
       x = "Size class", y = "Mean log growth, 2019-2025", caption = cap_n("39 counties"))
fig(p, "13_02_anova_interaction.png")

# 13.12 Repeated-measures ANOVA: the same counties' BEV share in 2019, 2022 and 2025.
# Counties need 10+ vehicles in 2019, as in 13.6.
bev3 <- vehicle_year[year %in% c(2019L, 2022L, 2025L) &
                     county %in% county_tab[stock_2019 >= MIN_COUNTY, county],
                     .(share = 100 * mean(ev_type == "BEV")), by = .(county, year)]
setorder(bev3, year, county)
bev3[, `:=`(county_f = factor(county), year_f = factor(year))]
assert(bev3[, .N, by = county][, all(N == 3L)], "a county is missing a year of BEV share")
rm_fit <- aov(share ~ year_f + Error(county_f / year_f), data = bev3)
rm_within <- summary(rm_fit)[["Error: county_f:year_f"]][[1]]
rm_F <- rm_within$`F value`[1]; rm_df <- rm_within$Df
# Sphericity: Mauchly's test, and the Greenhouse-Geisser epsilon from the covariance
# of orthonormal contrasts between the three years.
Y <- as.matrix(dcast(bev3, county ~ year, value.var = "share")[, -1])
mauchly <- mauchly.test(lm(Y ~ 1), X = ~1)
C <- contr.poly(3)
S <- t(C) %*% cov(Y) %*% C
eps_gg <- sum(diag(S))^2 / ((3 - 1) * sum(S * S))
friedman <- friedman.test(Y)
rm_summary <- data.table(
  counties = nrow(Y), f = rm_F, df1 = rm_df[1], df2 = rm_df[2],
  p = rm_within$`Pr(>F)`[1],
  partial_eta_sq = rm_within$`Sum Sq`[1] / sum(rm_within$`Sum Sq`),
  mauchly_w = unname(mauchly$statistic), mauchly_p = mauchly$p.value,
  gg_epsilon = eps_gg, gg_df1 = eps_gg * rm_df[1], gg_df2 = eps_gg * rm_df[2],
  gg_p = pf(rm_F, eps_gg * rm_df[1], eps_gg * rm_df[2], lower.tail = FALSE),
  friedman_chisq = unname(friedman$statistic), friedman_p = friedman$p.value,
  mean_2019 = mean(Y[, 1]), mean_2022 = mean(Y[, 2]), mean_2025 = mean(Y[, 3]))
out(rm_summary, "13_anova_repeated_measures.csv")
posthoc <- pairwise.t.test(bev3$share, bev3$year_f, paired = TRUE, p.adjust.method = "bonferroni")
out(as.data.table(as.table(posthoc$p.value))[!is.na(N)][, .(year_a = V1, year_b = V2,
    p_bonferroni = N)],
    "13_anova_repeated_posthoc.csv")
p <- ggplot(bev3, aes(year, share, group = county)) +
  geom_line(colour = "#9ec5f4", linewidth = 0.4) +
  stat_summary(aes(group = 1), fun = mean, geom = "line", colour = COL2, linewidth = 1.2) +
  stat_summary(aes(group = 1), fun = mean, geom = "point", colour = COL2, size = 2.5) +
  scale_x_continuous(breaks = c(2019, 2022, 2025)) +
  labs(title = "BEV share in the same counties, 2019, 2022 and 2025",
       subtitle = sprintf(paste("Repeated-measures ANOVA, Greenhouse-Geisser p = %.2g.",
                                "Orange: mean of counties"),
                          rm_summary$gg_p),
       x = "Year", y = "BEV share of active vehicles (%)",
       caption = cap_n(sprintf("%d counties with %d+ vehicles in 2019", nrow(Y), MIN_COUNTY)))
fig(p, "13_03_rm_anova_bev_share.png")

# 13.13 Mixed ANOVA: year within counties, side of the Cascades between counties.
bev3[, side := factor(fifelse(county %in% EAST, "Eastern", "Western"), levels = c("Western",
    "Eastern"))]
mixed_fit <- aov(share ~ side * year_f + Error(county_f / year_f), data = bev3)
mixed_tab <- rbind(aov_table(summary(mixed_fit)[["Error: county_f"]], "Between counties"),
                   aov_table(summary(mixed_fit)[["Error: county_f:year_f"]], "Within counties"))
out(mixed_tab, "13_anova_mixed.csv")
mixed_means <- bev3[, .(mean_share = mean(share), se = sd(share) / sqrt(.N), counties = .N),
                    keyby = .(side, year)]
p <- ggplot(mixed_means, aes(year, mean_share, colour = side)) +
  geom_line(linewidth = 0.9) + geom_point(size = 2) +
  geom_errorbar(aes(ymin = mean_share - 1.96 * se, ymax = mean_share + 1.96 * se), width = 0.3) +
  scale_colour_manual(values = c(Western = COL1, Eastern = COL2)) +
  scale_x_continuous(breaks = c(2019, 2022, 2025)) +
  labs(title = "BEV share by side of the Cascades",
       subtitle = sprintf("Mixed ANOVA: year x side interaction p = %.2g. Bars: 95%% intervals",
                          mixed_tab[term == "side:year_f", p]),
       x = "Year", y = "Mean county BEV share (%)", caption = cap_n(sprintf("%d counties",
           nrow(Y))))
fig(p, "13_04_mixed_anova_bev_share.png")
say("13. ANOVA: size class p = %.2g (%s, chosen by the checks); repeated measures (GG) p = %.2g.",
    oneway_results[test == primary1, p], primary1, rm_summary$gg_p)


# ---- 14. REGRESSION ---------------------------------------------------------

# 14.1 Simple: county log growth on log 2019 stock. Do smaller counties catch up?
simple_fit <- lm(growth ~ log_stock_2019, data = county_tab)
simple_nok <- lm(growth ~ log_stock_2019, data = county_tab[county != "King"])
coef_row <- function(fit, label, robust = FALSE) {
  v <- if (robust) sandwich::vcovHC(fit, type = "HC3") else vcov(fit)
  ct <- lmtest::coeftest(fit, vcov. = v)
  ci <- lmtest::coefci(fit, vcov. = v)
  data.table(model = label, term = rownames(ct), estimate = ct[, 1], se = ct[, 2], t = ct[, 3],
             p = ct[, 4],
             ci_low = ci[, 1], ci_high = ci[, 2], n = nobs(fit), r_squared = summary(fit)$r.squared,
             adj_r_squared = summary(fit)$adj.r.squared,
             se_type = if (robust) "HC3" else "classical")
}
county_models <- rbind(coef_row(simple_fit, "Simple, 39 counties"), coef_row(simple_nok,
    "Simple, without King"))
# Curvature check: a squared term.
quad <- lm(growth ~ log_stock_2019 + I(log_stock_2019^2), data = county_tab)
curv_p <- anova(simple_fit, quad)$`Pr(>F)`[2]

# Confidence and prediction intervals at chosen starting stocks.
new_st <- data.table(stock_2019 = c(10, 100, 1000, 10000))[, log_stock_2019 := log(stock_2019)]
ci_pi <- cbind(new_st, setnames(as.data.table(predict(simple_fit, new_st, interval = "confidence")),
                                c("fit", "ci_low", "ci_high")),
               setnames(as.data.table(predict(simple_fit, new_st, interval = "prediction"))[, 2:3],
                        c("pi_low", "pi_high")))
ci_pi[, `:=`(implied_growth_factor = exp(fit),
             pi_width_over_ci_width = (pi_high - pi_low) / (ci_high - ci_low))]
out(ci_pi, "14_county_intervals.csv")

# Diagnostics.
county_tab[, `:=`(fitted = fitted(simple_fit), resid = residuals(simple_fit),
                  std_resid = rstandard(simple_fit),
                  leverage = hatvalues(simple_fit), cooks = cooks.distance(simple_fit))]
influence <- county_tab[order(-cooks)][1:6, .(county, stock_2019, growth, std_resid, leverage,
    cooks,
                                             flag = fifelse(cooks > 4 / nrow(county_tab),
                                                 "Above 4/n", ""))]
out(influence, "14_county_influence.csv")
p1 <- ggplot(county_tab, aes(fitted, resid)) + geom_hline(yintercept = 0, colour = INK2,
    linewidth = 0.3) +
  geom_point(colour = COL1, size = 1.8) + geom_text(data = county_tab[cooks > 4 / .N],
      aes(label = county), size = 2.8, vjust = -0.8) +
  labs(title = "Residuals against fitted values", x = "Fitted log growth", y = "Residual")
p2 <- ggplot(county_tab, aes(sample = std_resid)) + stat_qq(colour = COL1, size = 1.5) +
  stat_qq_line(colour = COL2) +
  labs(title = "Normal Q-Q of standardised residuals", x = "Theoretical quantile",
       y = "Standardised residual")
p3 <- ggplot(county_tab, aes(reorder(county, cooks), cooks)) + geom_col(fill = COL1, width = 0.7) +
  geom_hline(yintercept = 4 / nrow(county_tab), colour = COL2, linetype = "dashed") + coord_flip() +
  labs(title = "Cook's distance (dashed line: 4/n)", x = NULL, y = "Cook's distance") +
    theme(axis.text.y = element_text(size = 6))
fig(p1 + labs(caption = cap_n("39 counties")), "14_01_county_residuals.png", w = 6, h = 4)
fig(p2 + labs(caption = cap_n("39 counties")), "14_02_county_qq.png", w = 6, h = 4)
fig(p3 + labs(caption = cap_n("39 counties")), "14_03_county_cooks.png", w = 6, h = 6.5)

# 14.2 Multiple: growth on starting stock, used share and BEV share (2019). Few
# predictors, because there are only 39 counties.
multi_fit <- lm(growth ~ log_stock_2019 + used_share_2019 + bev_share_2019, data = county_tab)
multi_nok <- lm(growth ~ log_stock_2019 + used_share_2019 + bev_share_2019,
                data = county_tab[county != "King"])
vif <- sapply(c("log_stock_2019", "used_share_2019", "bev_share_2019"), function(v) {
  others_v <- setdiff(c("log_stock_2019", "used_share_2019", "bev_share_2019"), v)
  1 / (1 - summary(lm(reformulate(others_v, v), data = county_tab))$r.squared)
})
county_models <- rbind(county_models, coef_row(multi_fit, "Multiple, 39 counties", robust = TRUE),
                       coef_row(multi_nok, "Multiple, without King", robust = TRUE))
county_models[, curvature_p_simple := curv_p]
out(county_models, "14_county_regressions.csv")
out(data.table(predictor = names(vif), vif = vif), "14_county_vif.csv")

# 14.3 Specification model: log real price on age, mileage, EV type and make,
# for used sales (fitted in section 9). Robust errors, because spread varies.
spec_tab <- coef_row(spec_fit, "Log real used price", robust = TRUE)
spec_tab[, pct_effect := 100 * (exp(estimate) - 1)]
spec_tab[term == "odometer", pct_effect := 100 * (exp(estimate * 10000) - 1)]   # per 10,000 miles
out(spec_tab, "14_specification_model.csv")
ref_car <- data.table(sale_age = 3L, odometer = 36000, ev_type = "BEV", make_grouped = "TESLA")
spec_pi <- rbind(cbind(type = "confidence", as.data.table(predict(spec_fit, ref_car,
    interval = "confidence"))),
                 cbind(type = "prediction", as.data.table(predict(spec_fit, ref_car,
                     interval = "prediction"))))
spec_pi[, `:=`(price_fit = exp(fit), price_low = exp(lwr), price_high = exp(upr))]
out(spec_pi, "14_specification_reference_car.csv")
spec_diag <- data.table(fitted = fitted(spec_fit), resid = residuals(spec_fit))[sample(.N, 20000L)]
p <- ggplot(spec_diag, aes(fitted, resid)) + geom_point(alpha = 0.08, size = 0.6, colour = COL1) +
  geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), colour = COL2, se = FALSE) +
    geom_hline(yintercept = 0, colour = INK2) +
  labs(title = "Specification model: residuals against fitted values",
       subtitle = "Random 20,000 of the used sales; orange line: smoothed mean",
       x = "Fitted log real price", y = "Residual", caption = cap_n(comma(nobs(spec_fit))))
fig(p, "14_04_spec_residuals.png")

# 14.4 Logistic model A: exit within two years, on the base predictors.
# Train on the 2021 baseline, test on 2023. 2021 is used because its outcome years
# (2022-23) end before the test outcome years (2024-25) begin. 2019 is a sensitivity
# fit. Only information known at the end of the baseline year is used.
prep_logit <- function(d, makes) {
  d <- copy(d)
  d[, make_g := factor(fifelse(make %in% makes, make, "Other"), levels = c(makes, "Other"))]
  # Only 24 Truck-class vehicles are active in 2021, too few for their own estimate,
  # so every class other than Passenger is grouped (about 175 vehicles in 2021).
  d[, use_g := factor(fifelse(use == "Passenger", "Passenger", "Truck, commercial or other"),
                      levels = c("Passenger", "Truck, commercial or other"))]
  d[, region := factor(region, levels = c("King", "Western Washington (not King)",
                                          "Eastern Washington"))]
  d[, transfers_g := factor(fcase(prior_transfers == 0L, "0", prior_transfers == 1L, "1",
                                  default = "2+"), levels = c("0", "1", "2+"))]
  d[, age_band := cut(age, c(-1, 1, 3, 5, 7, 9, Inf),
                      labels = c("0-1", "2-3", "4-5", "6-7", "8-9", "10+"))]
  d[]
}
train <- rt[[as.character(TRAIN_YEAR)]]$d
MIN_MAKE <- 1000L    # makes with fewer active vehicles at baseline go to Other
makes_kept <- train[, .N, by = make][N >= MIN_MAKE][order(-N), make]
train <- prep_logit(train, makes_kept)
test  <- prep_logit(d23, makes_kept)

# Logit linearity: Box-Tidwell terms, added by hand, for age + 1 and tenure + 1.
bt <- glm(exit2 ~ I(age + 1) + I((age + 1) * log(age + 1)) +
            I(tenure + 1) + I((tenure + 1) * log(tenure + 1)) +
            ev_type + make_g + region + transfers_g + use_g,
          family = binomial, data = train)
bt_terms <- c("I((age + 1) * log(age + 1))", "I((tenure + 1) * log(tenure + 1))")
bt_p <- coef(summary(bt))[bt_terms, 4]
# Rule set before fitting: if the age term shows curvature (p < 0.05), age enters as bands.
age_term <- if (bt_p[1] < 0.05) "age_band" else "age"
logit_formula <- reformulate(c(age_term, "ev_type", "make_g", "region", "transfers_g", "use_g"),
                             "exit2")
logit_fit <- glm(logit_formula, family = binomial, data = train)
odds_table <- function(fit, label) {
  ct <- coef(summary(fit))
  o <- data.table(model = label, term = rownames(ct), log_odds = ct[, 1], se = ct[, 2],
                  z = ct[, 3], p = ct[, 4])
  o[, `:=`(odds_ratio = exp(log_odds),
           or_low = exp(log_odds - 1.96 * se),
           or_high = exp(log_odds + 1.96 * se))]
  o[]
}
odds <- odds_table(logit_fit, "A: base predictors")
out(odds, "14_logistic_odds_ratios.csv")
out(data.table(term = c("age", "tenure"), box_tidwell_p = bt_p, age_entered_as = age_term),
    "14_logistic_linearity.csv")

# Adjusted probabilities: everyone's prediction with one factor set to each level.
adj_prob <- function(fit, d, v) rbindlist(lapply(levels(d[[v]]), function(l) {
  nd <- copy(d)
  set(nd, j = v, value = factor(l, levels = levels(d[[v]])))
  data.table(variable = v, level = l,
             adjusted_exit_pct = 100 * mean(predict(fit, nd, type = "response")))
}))
adj_vars <- c("ev_type", age_term, "region", "transfers_g", "use_g", "make_g")
adjusted <- rbindlist(lapply(adj_vars, function(v) adj_prob(logit_fit, train, v)))
out(adjusted, "14_logistic_adjusted_probabilities.csv")

# 14.5 Logistic model B: model A plus the vehicle's own history, all known at the end
# of the baseline year. Model A is close to chance, and the reason is checked in 14.7.
#   missed years   years with no record between entry and the baseline year
#   late renewals  registration gaps of more than 430 days (as in section 6)
#   moves          county changes up to the baseline year
#   last record    type and quarter of the vehicle's last record in the baseline year
history_features <- function(d, y) {
  seen <- vehicle_year[year <= y, .(years_seen = .N,
                                    moves_before = sum(county != shift(county), na.rm = TRUE)),
                       by = vehicle_id]
  late <- reg_rows[!is.na(next_date) & year(next_date) <= y & days_to_next > 430L,
                   .(late_before = .N), by = vehicle_id]
  last_rec <- clean[year == y, .(last_type = transaction_type[.N],
                                 last_month = month(transaction_date[.N])), by = vehicle_id]
  d <- Reduce(function(a, b) merge(a, b, by = "vehicle_id", all.x = TRUE),
              list(d, seen, late, last_rec))
  d[is.na(late_before), late_before := 0L]
  d[, missed_before := (y - entry_year + 1L) - years_seen]
  d[, `:=`(
    missed_g = factor(pmin(missed_before, 2L), levels = 0:2, labels = c("0", "1", "2+")),
    late_g   = factor(pmin(late_before, 2L), levels = 0:2, labels = c("0", "1", "2+")),
    moves_g  = factor(pmin(moves_before, 2L), levels = 0:2, labels = c("0", "1", "2+")),
    # A title with no registration after it in the year is rare, so the two title types share a
    # level.
    last_type_g = factor(fcase(last_type == "Registration Renewal", "Renewal",
                               last_type == "Original Registration", "Original registration",
                               last_type == "Registration at time of Transfer",
                               "Registration at transfer",
                               default = "Title, no later registration"),
                         levels = c("Renewal", "Original registration", "Registration at transfer",
                                    "Title, no later registration")),
    last_quarter = factor(paste0("Q", (last_month - 1L) %/% 3L + 1L), levels = paste0("Q", 1:4))
  )]
  assert(!anyNA(d$missed_before) && !anyNA(d$last_type) && all(d$missed_before >= 0L),
         "a history feature is missing or negative")
  d[]
}
train <- history_features(train, TRAIN_YEAR)
test  <- history_features(test, TEST_YEAR)
history_terms <- c("missed_g", "late_g", "moves_g", "last_type_g", "last_quarter")
logit_formula_b <- update(logit_formula,
                          reformulate(c(".", history_terms)))
logit_fit_b <- glm(logit_formula_b, family = binomial, data = train)
odds_b <- odds_table(logit_fit_b, "B: plus history")
out(odds_b, "14_logistic_odds_ratios_history.csv")
# Rule set before fitting: the final model is the one with the lower training AIC.
final_fit <- if (AIC(logit_fit_b) < AIC(logit_fit)) logit_fit_b else logit_fit
final_label <- if (identical(final_fit, logit_fit_b)) "B: plus history" else "A: base predictors"

# 14.6 Evaluation, as in course Chapter 9: McFadden's R-squared, discrimination,
# variable importance, multicollinearity, an optimal cutoff and a confusion matrix.
models <- list(`A: base predictors` = logit_fit, `B: plus history` = logit_fit_b)
for (m in names(models)) {
  set(train, j = paste0("p_", substr(m, 1, 1)), value = predict(models[[m]], type = "response"))
  set(test,  j = paste0("p_", substr(m, 1, 1)),
      value = predict(models[[m]], newdata = test, type = "response"))
}
null_fit <- glm(exit2 ~ 1, family = binomial, data = train)
mcfadden <- function(fit) 1 - as.numeric(logLik(fit)) / as.numeric(logLik(null_fit))
rocs <- list(
  A_train = pROC::roc(train$exit2, train$p_A, quiet = TRUE),
  A_test  = pROC::roc(test$exit2, test$p_A, quiet = TRUE),
  B_train = pROC::roc(train$exit2, train$p_B, quiet = TRUE),
  B_test  = pROC::roc(test$exit2, test$p_B, quiet = TRUE))
roc_train <- rocs$A_train; roc_test <- rocs$A_test   # model A, kept for the summary line
delong <- pROC::roc.test(rocs$B_test, rocs$A_test, method = "delong", paired = TRUE)

# Cutoffs. 0.5 labels almost nobody as leaving; the training exit rate and Youden's J
# (the cutoff that maximises sensitivity + specificity on the training data) do better.
threshold <- mean(train$exit2)
youden_cut <- function(r) {
  pROC::coords(r, "best", best.method = "youden", ret = "threshold", transpose = FALSE)$threshold[1]
}
cuts <- c(A = youden_cut(rocs$A_train), B = youden_cut(rocs$B_train))
confusion <- function(d, pcol, cut, label, cut_name) {
  pred <- d[[pcol]] >= cut
  tp <- sum(pred & d$exit2 == 1L); fp <- sum(pred & d$exit2 == 0L)
  fn <- sum(!pred & d$exit2 == 1L); tn <- sum(!pred & d$exit2 == 0L)
  data.table(model = label, cutoff_rule = cut_name, cutoff = cut,
             true_exit_predicted_exit = tp, stayed_predicted_exit = fp,
             true_exit_predicted_stay = fn, stayed_predicted_stay = tn,
             sensitivity = tp / (tp + fn), specificity = tn / (tn + fp),
             precision = if (tp + fp > 0) tp / (tp + fp) else NA_real_,
             misclassification = (fp + fn) / nrow(d))
}
confusion_tab <- rbindlist(lapply(c("A", "B"), function(k) {
  lab <- names(models)[startsWith(names(models), k)]
  rbind(confusion(test, paste0("p_", k), 0.5, lab, "0.5"),
        confusion(test, paste0("p_", k), threshold, lab, "Training exit rate"),
        confusion(test, paste0("p_", k), cuts[[k]], lab, "Youden's J on training data"))
}))
out(confusion_tab, "14_logistic_confusion_test.csv")

perf_row <- function(k) {
  lab <- names(models)[startsWith(names(models), k)]
  fit <- models[[lab]]
  ci_test <- as.numeric(pROC::ci.auc(rocs[[paste0(k, "_test")]]))
  data.table(model = lab, predictors = length(coef(fit)) - 1L, aic = AIC(fit),
             mcfadden_r2 = mcfadden(fit),
             auc_train = as.numeric(pROC::auc(rocs[[paste0(k, "_train")]])),
             auc_test = ci_test[2], auc_test_low = ci_test[1], auc_test_high = ci_test[3],
             brier_test = mean((test[[paste0("p_", k)]] - test$exit2)^2),
             mean_predicted_test = mean(test[[paste0("p_", k)]]), exit_rate_test = mean(test$exit2),
             youden_cutoff = cuts[[k]], final_model = lab == final_label)
}
performance <- rbind(perf_row("A"), perf_row("B"))
performance[, delong_p_b_vs_a := delong$p.value]
out(performance, "14_logistic_performance.csv")

# Variable importance: the drop in fit when each term is removed (likelihood-ratio
# chi-square), and |z| for each coefficient, which is what caret's varImp reports.
importance <- as.data.table(drop1(logit_fit_b, test = "LRT"), keep.rownames = "term")[-1]
setnames(importance, c("term", "df", "deviance", "aic", "lr_chisq", "p"))
importance <- importance[order(-lr_chisq)]
out(importance, "14_logistic_importance_terms.csv")
out(odds_b[term != "(Intercept)", .(term, abs_z = abs(z))][order(-abs_z)],
    "14_logistic_importance_coefficients.csv")

# Generalised VIF (Fox and Monette 1992) for each term, from the model matrix.
# GVIF^(1/(2 df)) is comparable with the square root of an ordinary VIF.
gvif <- function(fit) {
  X <- model.matrix(fit)[, -1, drop = FALSE]
  assign_idx <- attr(model.matrix(fit), "assign")[-1]
  R <- cor(X)
  labs_t <- attr(terms(fit), "term.labels")
  rbindlist(lapply(seq_along(labs_t), function(j) {
    i <- which(assign_idx == j)
    g <- det(R[i, i, drop = FALSE]) * det(R[-i, -i, drop = FALSE]) / det(R)
    data.table(term = labs_t[j], df = length(i), gvif = g, gvif_adjusted = g^(1 / (2 * length(i))))
  }))
}
vif_logit <- gvif(logit_fit_b)
out(vif_logit, "14_logistic_gvif.csv")

# Calibration and ROC for both models on the 2023 test baseline.
calib <- rbindlist(lapply(c("A", "B"), function(k) {
  p <- test[[paste0("p_", k)]]
  test[, .(model = names(models)[startsWith(names(models), k)],
           mean_predicted = mean(p), observed = mean(exit2), vehicles = .N),
       keyby = .(decile = cut(rank(p, ties.method = "first"), 10, labels = 1:10))]
}))
out(calib, "14_logistic_calibration.csv")
p <- ggplot(calib, aes(100 * mean_predicted, 100 * observed, colour = model)) +
  geom_abline(colour = INK2, linetype = "dashed") +
  geom_line() + geom_point(size = 2) +
  scale_colour_manual(values = c(COL2, COL1)) +
  labs(title = sprintf("Calibration on the %d baseline (models fitted on %d)", TEST_YEAR,
                       TRAIN_YEAR),
       subtitle = "Each point is a tenth of vehicles, ordered by predicted exit. Dashed: perfect",
       x = "Mean predicted exit (%)", y = "Observed exit (%)", caption = cap_n(comma(nrow(test))))
fig(p, "14_05_logistic_calibration.png", w = 6.5, h = 5)
roc_line <- function(r, label) {
  data.table(set = sprintf("%s (AUC %.3f)", label, pROC::auc(r)),
             fpr = 1 - r$specificities, tpr = r$sensitivities)
}
roc_dt <- rbind(roc_line(rocs$A_test, sprintf("A, test %d", TEST_YEAR)),
                roc_line(rocs$B_test, sprintf("B, test %d", TEST_YEAR)),
                roc_line(rocs$B_train, sprintf("B, train %d", TRAIN_YEAR)))
p <- ggplot(roc_dt, aes(fpr, tpr, colour = set)) +
  geom_abline(colour = INK2, linetype = "dashed") + geom_line(linewidth = 0.8) +
  scale_colour_manual(values = c(COL2, COL1, COL3)) + coord_equal() +
  guides(colour = guide_legend(ncol = 1)) +
  labs(title = "ROC curves for exit within two years",
       subtitle = sprintf(paste("B adds the vehicle's history.",
                                "DeLong test, B against A on test data: p = %.2g"),
                          delong$p.value),
       x = "False positive rate", y = "True positive rate",
       caption = cap_n(sprintf("%s train, %s test", comma(nrow(train)), comma(nrow(test)))))
fig(p, "14_06_logistic_roc.png", w = 6.5, h = 6.5)

# Class separation: predicted probabilities of vehicles that left and that stayed.
sep <- test[, .(p = p_B, Outcome = factor(fifelse(exit2 == 1L, "Left the records", "Stayed"),
                                          levels = c("Stayed", "Left the records")))]
p <- ggplot(sep, aes(100 * p, fill = Outcome)) +
  geom_density(alpha = 0.55, colour = NA, adjust = 1.5) +
  geom_vline(xintercept = 100 * cuts[["B"]], colour = INK, linetype = "dashed") +
  scale_fill_manual(values = c(Stayed = COL1, `Left the records` = COL2)) +
  coord_cartesian(xlim = c(0, 30)) +
  labs(title = sprintf("How well model B separates leavers from stayers, %d baseline", TEST_YEAR),
       subtitle = sprintf(paste("Dashed line: Youden cutoff (%.1f%%).",
                                "Heavy overlap means weak separation"),
                          100 * cuts[["B"]]),
       x = "Predicted probability of leaving (%)", y = "Density",
       caption = cap_n(comma(nrow(test))))
fig(p, "14_08_logistic_class_separation.png")

# 14.7 Why is model A near chance? Two checks.
# (a) Each predictor on its own: AUC 0.5 means no separation at all.
uni_auc <- function(d, v) {
  x <- d[[v]]
  x <- if (is.factor(x) || is.character(x)) {
    m <- d[, .(r = mean(exit2)), by = .(g = x)]
    m$r[match(x, m$g)]
  } else as.numeric(x)
  max(as.numeric(pROC::auc(pROC::roc(d$exit2, x, quiet = TRUE, direction = "<"))),
      as.numeric(pROC::auc(pROC::roc(d$exit2, x, quiet = TRUE, direction = ">"))))
}
uni_vars <- c("age", "tenure", "ev_type", "make_g", "region", "transfers_g", "use_g",
              "missed_before", "late_before", "moves_before", "last_type_g", "last_quarter")
single_auc <- data.table(predictor = uni_vars,
                         auc_train = sapply(uni_vars, function(v) uni_auc(train, v)),
                         auc_test = sapply(uni_vars, function(v) uni_auc(test, v)))
out(single_auc[order(-auc_train)], "14_logistic_single_predictor_auc.csv")
# (b) Label noise: some "exits" come back later (section 6). Refit on the training year
# with returners removed, to see how much of the weakness comes from them.
returned_later <- ids[rowSums(R[, col((TRAIN_YEAR + 3L):LAST_YEAR), drop = FALSE]) > 0L]
train[, returned := exit2 == 1L & vehicle_id %in% returned_later]
clean_train <- train[returned == FALSE]
noise_check <- data.table(
  check = c("All exits", "Exits that never returned"),
  vehicles = c(nrow(train), nrow(clean_train)),
  exits = c(sum(train$exit2), sum(clean_train$exit2)),
  auc_model_a = c(as.numeric(pROC::auc(rocs$A_train)),
                  as.numeric(pROC::auc(pROC::roc(clean_train$exit2,
                    predict(glm(logit_formula, binomial, clean_train), type = "response"),
                    quiet = TRUE)))),
  auc_model_b = c(as.numeric(pROC::auc(rocs$B_train)),
                  as.numeric(pROC::auc(pROC::roc(clean_train$exit2,
                    predict(glm(logit_formula_b, binomial, clean_train), type = "response"),
                    quiet = TRUE)))))
out(noise_check, "14_logistic_label_noise_check.csv")

# 14.8 Predictions for two example vehicles at the 2023 baseline, with 95% intervals
# built on the log-odds scale.
examples <- copy(test[1:2])
examples[, `:=`(age = c(2L, 8L), ev_type = factor(c("BEV", "PHEV"), levels = c("BEV", "PHEV")),
                make_g = factor(c("TESLA", "Other"), levels = levels(test$make_g)),
                region = factor(c("King", "Eastern Washington"), levels = levels(test$region)),
                transfers_g = factor(c("0", "2+"), levels = levels(test$transfers_g)),
                use_g = factor("Passenger", levels = levels(test$use_g)),
                missed_g = factor(c("0", "1"), levels = levels(test$missed_g)),
                late_g = factor(c("0", "1"), levels = levels(test$late_g)),
                moves_g = factor(c("0", "1"), levels = levels(test$moves_g)),
                last_type_g = factor(c("Renewal", "Registration at transfer"),
                                     levels = levels(test$last_type_g)),
                last_quarter = factor(c("Q3", "Q1"), levels = levels(test$last_quarter)))]
if (age_term == "age_band") examples[, age_band := cut(age, c(-1, 1, 3, 5, 7, 9, Inf),
                                                      labels = levels(test$age_band))]
pr <- predict(logit_fit_b, examples, type = "link", se.fit = TRUE)
example_pred <- data.table(
  vehicle = c("2-year-old Tesla BEV in King, no transfers, renewed on time",
              "8-year-old PHEV in Eastern WA, 2+ transfers, one missed year and one late renewal"),
  predicted_exit = plogis(pr$fit), ci_low = plogis(pr$fit - 1.96 * pr$se.fit),
  ci_high = plogis(pr$fit + 1.96 * pr$se.fit))
out(example_pred, "14_logistic_example_predictions.csv")

# 14.9 Two-predictor decision boundary: age and years in the Washington records.
db_fit <- glm(exit2 ~ age + tenure, family = binomial, data = train)
b <- coef(db_fit)
db_line <- data.table(age = seq(0, 12, 0.1))[,
    tenure := (qlogis(threshold) - b[1] - b[2] * age) / b[3]]
db_pts <- train[sample(.N, 6000L)][age <= 15L]
db_pts[, Outcome := factor(fifelse(exit2 == 1L, "Left the records", "Stayed"),
                           levels = c("Stayed", "Left the records"))]
p <- ggplot(db_pts, aes(age, tenure)) +
  geom_jitter(aes(colour = Outcome), width = 0.3, height = 0.3, size = 0.7, alpha = 0.5) +
  geom_line(data = db_line[tenure >= -0.5 & tenure <= 12], colour = INK, linewidth = 0.9) +
  scale_colour_manual(values = c(Stayed = "#9ec5f4", `Left the records` = COL2)) +
  guides(colour = guide_legend(override.aes = list(size = 3, alpha = 1))) +
  labs(title = "Decision boundary: age and years in the records",
       subtitle = sprintf(paste("Line: predicted exit = %.1f%% (the training exit rate).",
                                "%s it, a vehicle is predicted to leave"),
                          100 * threshold, if (b[3] > 0) "Above" else "Below"),
       x = sprintf("Age at %d (years, jittered)", TRAIN_YEAR),
       y = "Years since first Washington record (jittered)",
       caption = cap_n(sprintf("random 6,000 of %s vehicles", comma(nrow(train)))))
fig(p, "14_07_decision_boundary.png")

# Sensitivity: model A fitted on the 2019 baseline.
train19 <- prep_logit(rt[["2019"]]$d, makes_kept)
fit19 <- glm(logit_formula, family = binomial, data = train19)
sens19 <- data.table(term = names(coef(fit19)), odds_ratio_2019 = exp(coef(fit19)))
sens19 <- merge(odds[, .(term, odds_ratio_2021 = odds_ratio)], sens19, by = "term", all = TRUE)
out(sens19, "14_logistic_2019_sensitivity.csv")
say("14. Logistic test AUC: model A %.3f, model B %.3f (DeLong p = %.2g). Final model: %s.",
    performance[1, auc_test], performance[2, auc_test], delong$p.value, final_label)


# ---- 15. EXTENSION 1: USED PRICES AND ENTRY ROUTES --------------------------

# 15.1 Repeat-sale pairs, using the benchmark's rules first: consecutive used sales
# of the same car, 0.25 to 8 years apart, aged 0 to 15 at both sales.
GAP_MIN <- 0.25; GAP_MAX <- 8; AGE_MAX <- 15L
rs <- sale_events[!is.na(cpi), .(vehicle_id, make, ev_type, model_year, sale_date, sale_y, sale_age,
                                 new_used, real_price)]
setorder(rs, vehicle_id, sale_date)
rs[, `:=`(prev_date = shift(sale_date), prev_y = shift(sale_y), prev_age = shift(sale_age),
          prev_label = shift(new_used), prev_price = shift(real_price)), by = vehicle_id]
pairs_all <- rs[!is.na(prev_date) & new_used == "Used" & prev_label == "Used"]
pairs_all[, gap := as.numeric(sale_date - prev_date) / 365.25]
pairs <- pairs_all[gap >= GAP_MIN & gap <= GAP_MAX & prev_age <= AGE_MAX & sale_age <= AGE_MAX]
pairs[, dlog := log(real_price / prev_price)]
# Sale dates are almost absent before 2016, so the index starts in the first year
# where Tesla and other makes each have 30+ sales in pairs. Earlier pairs are dropped.
ends <- rbind(pairs[, .(y = prev_y, tesla = make == "TESLA")], pairs[, .(y = sale_y,
    tesla = make == "TESLA")])
INDEX_START <- ends[, .(ok = sum(tesla) >= 30L && sum(!tesla) >= 30L), keyby = y][ok == TRUE,
    min(y)]
dropped_early <- pairs[prev_y < INDEX_START, .N]
pairs <- pairs[prev_y >= INDEX_START]
say("15. Index starts in %d; %d earlier pair(s) dropped.", INDEX_START, dropped_early)
say("15. Repeat-sale pairs: %s on %s cars.", comma(nrow(pairs)), comma(uniqueN(pairs$vehicle_id)))

# 15.2 Repeat-sales index: log price change on +1 (second sale year) and -1 (first
# sale year) dummies, no intercept, first year as the base.
rs_years <- sort(unique(c(pairs$prev_y, pairs$sale_y)))
design <- function(d) {
  X <- matrix(0, nrow(d), length(rs_years), dimnames = list(NULL, rs_years))
  X[cbind(seq_len(nrow(d)), match(d$sale_y, rs_years))] <- 1
  X[cbind(seq_len(nrow(d)), match(d$prev_y, rs_years))] <- X[cbind(seq_len(nrow(d)), match(d$prev_y,
      rs_years))] - 1
  X[, -1, drop = FALSE]
}
rs_index <- function(d, label) {
  X <- design(d)
  keep <- colSums(abs(X)) > 0
  fit <- lm.fit(X[, keep, drop = FALSE], d$dlog)
  b <- c(0, setNames(rep(NA_real_, ncol(X)), colnames(X)))
  b[c(TRUE, keep)][-1] <- fit$coefficients
  names(b)[1] <- rs_years[1]
  data.table(group = label, year = as.integer(names(b)), log_index = b, pairs = nrow(d))[
    , yoy_pct := 100 * (exp(log_index - shift(log_index)) - 1)]
}
idx <- rbindlist(list(rs_index(pairs, "All"), rs_index(pairs[make == "TESLA"], "Tesla"),
                      rs_index(pairs[make != "TESLA"], "Not Tesla")))
idx[, index_first_year_100 := 100 * exp(log_index)]
out(idx, "15_repeat_sales_index.csv")

# 15.3 The index oddity: in some years the "All" change lies outside both the Tesla
# and non-Tesla changes. Pooled least squares is a matrix-weighted average of the
# group estimates, b_all = (X'X)^-1 (X1'X1 b1 + X2'X2 b2), not a year-by-year
# average, so one coordinate can fall outside the group range. Checked here exactly.
X1 <- design(pairs[make == "TESLA"]); X2 <- design(pairs[make != "TESLA"]); Xa <- design(pairs)
assert(all(colSums(abs(X1)) > 0) && all(colSums(abs(X2)) > 0), "a year has no pairs in one group")
b1 <- qr.solve(X1, pairs[make == "TESLA", dlog]); b2 <- qr.solve(X2, pairs[make != "TESLA",
    dlog]); ba <- qr.solve(Xa, pairs$dlog)
b_mix <- solve(crossprod(Xa), crossprod(X1) %*% b1 + crossprod(X2) %*% b2)
assert(max(abs(b_mix - ba)) < 1e-8, "pooled index is not the matrix-weighted average of the groups")
oddity <- dcast(idx, year ~ group, value.var = "yoy_pct")
oddity[, outside_groups := !is.na(All) & (All > pmax(Tesla, `Not Tesla`) | All < pmin(Tesla,
    `Not Tesla`))]
out(oddity, "15_index_oddity.csv")
say(paste("15. Index oddity: 'All' outside both groups in %d years;",
          "pooled = matrix-weighted average (checked to 1e-8)."),
    oddity[outside_groups == TRUE, .N])

# 15.4 The index includes normal ageing, because each car is older at its second
# sale by exactly the gap. A hedonic index holds age and mileage fixed instead:
# log real price on sale year, age, mileage, EV type and make, for used sales.
# Same start year as the repeat-sales index: only 3 used sales have earlier sale dates.
hed <- sale_events[new_used == "Used" & mileage_sample == TRUE & !is.na(cpi) &
                   sale_y >= INDEX_START]
hed[, make_grouped := fifelse(make %in% hed[, .N, by = make][N >= 100L, make], make, "Other")]
hed_fit <- lm(log(real_price) ~ factor(sale_y) + sale_age + odometer + ev_type + make_grouped,
              data = hed)
hb <- coef(hed_fit)[grep("^factor\\(sale_y\\)", names(coef(hed_fit)))]
hed_idx <- data.table(year = c(min(hed$sale_y), as.integer(sub("factor\\(sale_y\\)", "",
    names(hb)))), log_index = c(0, hb))
hed_idx[, `:=`(group = "Hedonic (age and mileage held fixed)",
               yoy_pct = 100 * (exp(log_index - shift(log_index)) - 1))]
age_effect <- 100 * (exp(coef(hed_fit)["sale_age"]) - 1)
both_idx <- rbind(idx[group == "All", .(group = "Repeat sales (includes ageing)", year, yoy_pct)],
                  hed_idx[, .(group, year, yoy_pct)])
out(both_idx, "15_index_comparison.csv")
p <- ggplot(both_idx[year > INDEX_START], aes(year, yoy_pct, colour = group)) +
  geom_hline(yintercept = 0, colour = INK2, linewidth = 0.3) +
  geom_line(linewidth = 0.9) + geom_point(size = 1.6) + scale_colour_manual(values = c(COL1,
      COL2)) +
  scale_x_continuous(breaks = (INDEX_START + 1L):LAST_YEAR, labels = c((INDEX_START + 1L):LAST_FULL,
      "2026*")) +
  labs(title = "Real used EV prices, change on the previous year",
       subtitle = sprintf(paste("Repeat-sales pairs include ageing",
                                "(hedonic age effect: %.1f%% a year).",
                                "*2026 is January-September"), age_effect),
       x = "Sale year", y = "Change (%)", caption = cap_n(sprintf("%s pairs; %s used sales",
           comma(nrow(pairs)), comma(nobs(hed_fit)))))
fig(p, "15_01_used_price_index.png")

# 15.5 Prices against the rise in used activity from 2023.
activity <- merge(used_share_year[, .(used_share = 100 * sum(used_share * titles / 100) /
                                         sum(titles)), by = year],
                  hed_idx[, .(year, hedonic_log_index = log_index)], by = "year")
activity <- merge(activity, idx[group == "All", .(year, repeat_sales_log_index = log_index)],
                  by = "year")
out(activity, "15_prices_and_used_activity.csv")

# 15.6 How cars sold twice compare with the whole population.
twice_ids <- unique(pairs$vehicle_id)
compare_groups <- function(d, label) d[, .(group = label, vehicles = .N,
    share_of_all_pct = 100 * .N / nrow(history),
  mean_model_year = mean(model_year), bev_pct = 100 * mean(ev_type == "BEV"),
  tesla_pct = 100 * mean(make == "TESLA"),
  king_at_entry_pct = 100 * mean(entry_county == "King"),
  entered_new_pct = 100 * mean(entry_route == "New"),
  left_by_2023_pct = 100 * mean(last_year <= 2023L))]
twice_compare <- rbind(compare_groups(history, "All vehicles"),
                       compare_groups(history[vehicle_id %in% twice_ids],
                                      "Cars in a repeat-sale pair"))
out(twice_compare, "15_repeat_sale_cars_vs_all.csv")

# 15.7 Sensitivity: at least one year between sales, which removes quick resales.
pairs_1y <- pairs[gap >= 1]
out(rs_index(pairs_1y, "All, gap of 1 year or more"), "15_repeat_sales_index_gap1.csv")


# ---- 16. EXTENSION 3: COUNTY MOVEMENT ---------------------------------------

# A move is a change of county between consecutive vehicle-years (section 6).
moves[, `:=`(from_region = region_of(from), to_region = region_of(to))]
move_matrix <- dcast(moves[year <= LAST_FULL], from_region ~ to_region, fun.aggregate = length,
                     value.var = "vehicle_id")
out(move_matrix, "16_move_matrix_by_region.csv")
# Do resold vehicles move outward from King? Compare vehicle-years in King with
# and without a title transfer in the following year.
vy <- vehicle_year[, .(vehicle_id, year, county, transfers)]
setorder(vy, vehicle_id, year)
vy[, `:=`(next_county = shift(county, type = "lead"), next_year = shift(year, type = "lead"),
          next_transfers = shift(transfers, type = "lead")), by = vehicle_id]
from_king <- vy[county == "King" & !is.na(next_year) & next_year == year + 1L &
                year <= LAST_FULL - 1L]
king_out <- from_king[, .(vehicle_years = .N, left_king_pct = 100 * mean(next_county != "King"),
                          to_eastern_pct = 100 * mean(region_of(next_county) ==
                                                        "Eastern Washington")),
                      keyby = .(transfer_next_year = fifelse(next_transfers > 0L, "Transferred",
                          "No transfer"))]
king_test <- prop.test(king_out$vehicle_years * king_out$left_king_pct / 100,
                       king_out$vehicle_years, correct = FALSE)
king_out[, `:=`(diff_pct_points = 100 * diff(rev(king_test$estimate)) * -1,
                p_value = king_test$p.value)]
out(king_out, "16_leaving_king_by_transfer.csv")
net_king <- moves[year <= LAST_FULL, .(into_king = sum(to == "King"),
                                       out_of_king = sum(from == "King")), keyby = year][,
    net := into_king - out_of_king]
out(net_king, "16_net_moves_king.csv")
p <- ggplot(melt(net_king[year >= 2012L], id.vars = "year", measure.vars = c("into_king",
    "out_of_king")),
            aes(year, value, colour = variable)) + geom_line(linewidth = 0.9) +
              geom_point(size = 1.6) +
  scale_colour_manual(values = c(into_king = COL1, out_of_king = COL2),
                      labels = c("Moved into King", "Moved out of King")) +
  scale_y_continuous(labels = scales::comma) +
  labs(title = "Vehicles moving into and out of King County",
       subtitle = "County change between consecutive yearly records",
       x = "Year of the new county", y = "Vehicles", caption = cap_n(comma(nrow(moves))))
fig(p, "16_01_king_moves.png")


# ---- 17. EXTENSION 4: COHORT SURVIVAL ---------------------------------------

# Kaplan-Meier by age. A vehicle is at risk from its age at entry (so used arrivals
# enter late) to its age at last record. Leaving can only be seen up to 2023, so
# every vehicle is followed to 2023 at most; one still recorded later is censored there.
EXIT_LAST <- 2023L
surv_d <- history[entry_year <= EXIT_LAST, .(vehicle_id, ev_type, make, model_year,
                      age_in = pmax(entry_year - model_year, 0L), age_out = pmax(pmin(last_year,
                          EXIT_LAST) - model_year, 0L) + 1L,
                      left = as.integer(last_year <= EXIT_LAST))]
assert(surv_d[age_out <= age_in, .N] == 0L, "a vehicle has no time at risk")
surv_d[, my_group := cut(model_year, c(-Inf, 2014, 2018, 2022, Inf), labels = c("2014 or earlier",
    "2015-2018", "2019-2022", "2023 or later"))]
km_type <- survival::survfit(survival::Surv(age_in, age_out, left) ~ ev_type, data = surv_d)
km_my   <- survival::survfit(survival::Surv(age_in, age_out, left) ~ my_group, data = surv_d)
km_tab <- function(km, label) {
  s <- summary(km, times = 1:12, extend = TRUE)
  data.table(by = label, group = sub(".*=", "", as.character(s$strata)), age = s$time,
             survival = s$surv,
             ci_low = s$lower, ci_high = s$upper, at_risk = s$n.risk)
}
survival_tab <- rbind(km_tab(km_type, "EV type"), km_tab(km_my, "Model-year group"))
out(survival_tab, "17_survival_by_age.csv")
# not truncation-adjusted; descriptive only
logrank <- survival::survdiff(survival::Surv(age_out, left) ~ ev_type, data = surv_d)
cox <- survival::coxph(survival::Surv(age_in, age_out, left) ~ ev_type + survival::strata(my_group),
                       data = surv_d)
out(data.table(term = "PHEV vs BEV", hazard_ratio = exp(coef(cox)), ci_low = exp(confint(cox))[1],
               ci_high = exp(confint(cox))[2],
               p = summary(cox)$coefficients[, "Pr(>|z|)"],
               note = "Cox model by age, left-truncated, stratified by model-year group"),
    "17_cox_type.csv")

# 17.1 Why the Cox model and the main logistic test (13.2) differ. The Cox model
# pools every exit from 2010 to 2023; the logistic test looks at one two-year
# window. First, the proportional-hazards check (Schoenfeld residuals). Then the
# PHEV effect in separate calendar periods, from both models. The logistic test
# at the 2021 baseline stays the planned answer to H0; this only explains the gap.
zph <- survival::cox.zph(cox, transform = "km")
out(data.table(term = rownames(zph$table), chisq = zph$table[, "chisq"],
               df = zph$table[, "df"], p = zph$table[, "p"],
               note = "Schoenfeld residuals against Kaplan-Meier transformed age"),
    "17_cox_ph_check.csv")
cox_window <- function(a, b) {
  # Risk time and exits only in calendar years a to b (calendar year = model year + age).
  d <- copy(surv_d)[, `:=`(lo = pmax(age_in, a - model_year),
                           hi = pmin(age_out, b - model_year + 1L))]
  d <- d[hi > lo]
  d[, ev := as.integer(left == 1L & age_out <= hi)]
  m <- survival::coxph(survival::Surv(lo, hi, ev) ~ ev_type + survival::strata(my_group),
                       data = d)
  s <- summary(m)$coefficients
  data.table(model = "Cox, risk time in the period", period = sprintf("%d-%d", a, b),
             phev_effect = exp(s[, "coef"]), ci_low = exp(s[, "coef"] - 1.96 * s[, "se(coef)"]),
             ci_high = exp(s[, "coef"] + 1.96 * s[, "se(coef)"]), p = s[, "Pr(>|z|)"],
             n = nrow(d))
}
logit_window <- function(y) {
  d <- vehicle_year[year == y, .(vehicle_id, age, ev_type)]
  d[, `:=`(exit2 = as.integer(exit_mat(y, 2L)[match(vehicle_id, ids)]),
           age_f = factor(pmin(age, 15L)), ev_type = factor(ev_type, c("BEV", "PHEV")))]
  b <- coef(summary(glm(exit2 ~ ev_type + age_f, family = binomial, data = d)))["ev_typePHEV", ]
  data.table(model = "Logistic, two-year exit, adjusted for age",
             period = sprintf("%d baseline", y), phev_effect = exp(b[1]),
             ci_low = exp(b[1] - 1.96 * b[2]), ci_high = exp(b[1] + 1.96 * b[2]), p = b[4],
             n = nrow(d))
}
retention_periods <- rbind(
  rbindlist(lapply(list(c(2010L, 2016L), c(2017L, 2019L), c(2019L, 2021L), c(2021L, 2023L)),
                   function(w) cox_window(w[1], w[2]))),
  rbindlist(lapply(2013:2023, logit_window)))
retention_periods[, measure := fifelse(grepl("^Cox", model), "PHEV hazard ratio",
                                       "PHEV odds ratio")]
out(retention_periods, "17_retention_by_period.csv")
assert(isTRUE(all.equal(retention_periods[period == "2021 baseline", phev_effect],
                        unname(rt[[as.character(TRAIN_YEAR)]]$or))),
       "period logistic at 2021 differs from the main retention test")
say(paste("17. Cox PHEV HR %.2f over 2010-2023 (PH check p = %.2g); by period, logistic OR",
          "%.2f at 2017 baseline, %.2f at 2021, %.2f at 2023; Cox HR 2021-2023 %.2f."),
    exp(coef(cox)), zph$table["ev_type", "p"],
    retention_periods[period == "2017 baseline", phev_effect],
    retention_periods[period == "2021 baseline", phev_effect],
    retention_periods[period == "2023 baseline", phev_effect],
    retention_periods[period == "2021-2023", phev_effect])
surv_plot <- function(by_label, cols, title, name) {
  d <- survival_tab[by == by_label & age <= 12 & at_risk >= 100]
  d <- rbind(unique(d[, .(by, group)])[, `:=`(age = 0, survival = 1, ci_low = 1, ci_high = 1,
      at_risk = NA_real_)], d, fill = TRUE)
  p <- ggplot(d, aes(age, 100 * survival, colour = group)) + geom_step(linewidth = 0.9) +
    scale_colour_manual(values = cols) + scale_x_continuous(breaks = 0:12) +
    labs(title = title,
         subtitle = paste("Kaplan-Meier by age, allowing for late (used) entry.",
                          "Shown while 100+ vehicles are at risk"),
         x = "Vehicle age (years)", y = "Still in the records (%)",
         caption = cap_n(comma(nrow(surv_d))))
  fig(p, name)
}
surv_plot("EV type", TYPE_COLS, "Share of vehicles still in the records, BEV and PHEV",
          "17_01_survival_by_type.png")
surv_plot("Model-year group", c(COL1, COL2, COL3, COL4),
          "Share of vehicles still in the records, by model year",
          "17_02_survival_by_model_year.png")


# ---- 18. EXTENSION 5: ELECTRIC RANGE AND RETENTION --------------------------

# BEVs up to model year 2020 with a recorded range, active at the 2021 baseline.
rng <- merge(train[ev_type == "BEV"], range_vehicle[range > 0, .(vehicle_id, range)],
             by = "vehicle_id")
rng <- rng[vehicle_id %in% history[model_year <= 2020L, vehicle_id]]
range_fit <- glm(exit2 ~ I(range / 100) + age_band + make_g + region, family = binomial, data = rng)
rc <- coef(summary(range_fit))["I(range/100)", ]
range_result <- data.table(vehicles = nrow(rng), exit_rate = mean(rng$exit2),
                           or_per_100_miles = exp(rc[1]),
                           ci_low = exp(rc[1] - 1.96 * rc[2]), ci_high = exp(rc[1] + 1.96 * rc[2]),
                           p = rc[4],
                           note = paste("BEVs, model year 2020 or earlier, range recorded;",
                                        "adjusted for age band, make and region"))
out(range_result, "18_range_and_exit.csv")
say("18. Range: odds ratio per 100 miles %.2f (%s BEVs).", exp(rc[1]), comma(nrow(rng)))


# ---- 19. EXTENSION 2: EVS PER 1,000 RESIDENTS --------------------------------

# 19.1 County population: US Census Bureau July 1 estimates. 2010-2019 come from the
# Vintage 2020 file and 2020-2025 from the newer Vintage 2025 file, which revises 2020.
POP_FILES <- c("data/raw/census_co-est2020-alldata.csv", "data/raw/census_co-est2025-alldata.csv")
POP_SHA256 <- c("983708e1b68c8e7c4ecbef4d45137bea34ee286abe07662ccc0d6dfc6411fe83",
                "4f5a499d851e2cb48fd7a5405e5a9235453a8a66933657aacd10df0e264f35d5")
assert(all(file.exists(POP_FILES)), "a county population file is missing from data/raw/")
assert(all(as.character(tools::sha256sum(POP_FILES)) == POP_SHA256),
       "a county population file does not match its frozen SHA-256 hash")
read_pop <- function(path, years) {
  d <- fread(path, encoding = "Latin-1", colClasses = list(character = c("STATE", "COUNTY")))
  d <- d[STATE == "53" & COUNTY != "000"]      # Washington counties; 000 is the state row
  d <- melt(d, id.vars = "CTYNAME", measure.vars = paste0("POPESTIMATE", years),
            variable.name = "year", value.name = "population")
  d[, .(county = sub(" County$", "", CTYNAME),
        year = as.integer(sub("POPESTIMATE", "", year)), population)]
}
pop <- rbind(read_pop(POP_FILES[1], 2010:2019), read_pop(POP_FILES[2], 2020:2025))
assert(pop[, uniqueN(county)] == 39L && setequal(pop$county, unique(vehicle_year$county)),
       "Census county names do not match the vehicle records")
assert(pop[, .N, by = year][, all(N == 39L)], "a year lacks a county population")

# 19.2 Active vehicles (record that year, county at year end) per 1,000 residents.
rate <- merge(county_year[year <= LAST_FULL, .(county, year, vehicles)], pop,
              by = c("county", "year"), all.y = TRUE)
rate[is.na(vehicles), vehicles := 0L]
rate[, per_1000 := 1000 * vehicles / population]
state_rate <- rate[, .(vehicles = sum(vehicles), population = sum(population)), keyby = year]
state_rate[, per_1000 := 1000 * vehicles / population]
king_vs_rest <- rate[, .(per_1000 = 1000 * sum(vehicles) / sum(population)),
                     keyby = .(year, area = fifelse(county == "King", "King", "Rest of state"))]
out(rate[order(year, -per_1000)], "19_ev_per_1000_by_county.csv")
out(state_rate, "19_ev_per_1000_state.csv")

# 19.3 King's share of vehicles against its share of residents.
king_shares <- rate[, .(king_vehicle_share = 100 * sum(vehicles[county == "King"]) / sum(vehicles),
                        king_population_share = 100 * sum(population[county == "King"]) /
                          sum(population)),
                    keyby = year]
king_shares[, concentration_ratio := king_vehicle_share / king_population_share]
out(king_shares, "19_king_share_vs_population.csv")

# 19.4 Rates in 2019 and 2025, their growth, and how they relate to county size.
rate_c <- dcast(rate[year %in% c(2019L, LAST_FULL)], county ~ year, value.var = c("per_1000",
    "population"))
setnames(rate_c, c("county", "rate_2019", "rate_2025", "pop_2019", "pop_2025"))
rate_c[, `:=`(rate_growth = log(rate_2025 / rate_2019), z_rate_2025 = as.numeric(scale(rate_2025)),
              region = region_of(county))]
out(rate_c[order(-rate_2025)], "19_rate_2019_2025.csv")
rate_cor <- rbindlist(lapply(c("pearson", "spearman", "kendall"), function(m) {
  ct <- suppressWarnings(cor.test(log(rate_c$pop_2025), rate_c$rate_2025, method = m))
  data.table(pair = "log population 2025 vs EVs per 1,000 in 2025", method = m,
             estimate = unname(ct$estimate), p = ct$p.value)
}))
out(rate_cor, "19_rate_correlations.csv")
rate_desc <- describe(rate_c$rate_2025, "EVs per 1,000 residents, 2025", "vehicles per 1,000", 1)
out(rate_desc, "19_rate_descriptives.csv")

p <- ggplot(rate_c, aes(rate_2025, reorder(county, rate_2025), fill = region)) +
  geom_col(width = 0.75) +
  geom_vline(xintercept = state_rate[year == LAST_FULL, per_1000], colour = INK,
             linetype = "dashed") +
  scale_fill_manual(values = c(King = COL2, `Western Washington (not King)` = COL1,
                               `Eastern Washington` = COL3)) +
  labs(title = "Active plug-in vehicles per 1,000 residents, 2025",
       subtitle = sprintf("Dashed line: Washington as a whole (%.1f per 1,000)",
                          state_rate[year == LAST_FULL, per_1000]),
       x = "Vehicles per 1,000 residents", y = NULL,
       caption = sprintf(paste("%s\nPopulation: US Census Bureau county estimates, July 1 2025.",
                               "n = 39 counties."),
                         SOURCE_NOTE)) +
  theme(axis.text.y = element_text(size = 7))
fig(p, "19_01_ev_per_1000_2025.png", w = 7, h = 7.5)
p <- ggplot(king_vs_rest[year >= 2012L], aes(year, per_1000, colour = area)) +
  geom_line(linewidth = 0.9) + geom_point(size = 1.6) +
  scale_colour_manual(values = c(King = COL1, `Rest of state` = COL2)) +
  scale_x_continuous(breaks = seq(2012, 2025, 2)) +
  labs(title = "Plug-in vehicles per 1,000 residents, King and the rest of Washington",
       subtitle = sprintf("In 2025 King holds %.1f%% of vehicles but %.1f%% of residents",
                          king_shares[year == LAST_FULL, king_vehicle_share],
                          king_shares[year == LAST_FULL, king_population_share]),
       x = "Year", y = "Vehicles per 1,000 residents",
       caption = sprintf("%s\nPopulation: US Census Bureau county estimates, July 1.", SOURCE_NOTE))
fig(p, "19_02_ev_per_1000_king_vs_rest.png")
say("19. EVs per 1,000 residents in 2025: state %.1f, King %.1f, rest %.1f.",
    state_rate[year == LAST_FULL, per_1000],
    king_vs_rest[year == LAST_FULL & area == "King", per_1000],
    king_vs_rest[year == LAST_FULL & area == "Rest of state", per_1000])


# ---- 20. EXTENSION 6: POPULATION PROJECTION ----------------------------------

set.seed(20261107)

# 20.1 Rates. The projection is the stock-and-flow identity checked in section 9.1:
#   active[t+1] = active[t] * (1 - exit rate[t] + return rate[t]) + entries[t+1]
# Exit rate: two-year leavers after year t / gap-filled active in t (section 6).
# Return rate: vehicles back in t+1 after a gap / active in t.
rates <- flows[, .(year, active = active_filled, entries,
                   exit_rate = leavers_after_year / active_filled,
                   return_rate = shift(returns, type = "lead") / active_filled)]

# 20.2 What is known at a cut year C (the last full year of records):
#   entries up to C; the gap-filled count up to C-1 (filling C needs C+1);
#   exit and return rates up to C-2 (a two-year exit needs C-1 and C).
# So the projection starts from active[C-1], adds the known entries of C, and uses
# the mean exit and return rates of C-6 to C-2. The same rule serves the backtest
# (C = 2022) and the projection (C = 2025); 2026 is partial, so it's only a check.
#
# Entries are the uncertain part. Two standard simple rules are run
# (Hyndman & Athanasopoulos, Forecasting: Principles and Practice, ch. 5):
#   Level: entries stay at year C's level (the naive rule, a random walk).
#   Trend: entries keep their average yearly growth over C-10 to C (the drift rule).
# The interval comes from 10,000 simulated paths. Each path draws its own exit rate
# (normal, mean and SD of the five known years) and adds yearly entry shocks with
# the rule's own one-step error SD over the last ten years. The Trend paths also
# draw their growth rate, so its uncertainty is included.
# Level is the primary projection, decided at the cut and not from the outcome:
# entries were flat in 2024-2025 (72,036 then 71,635), and Washington's sales-tax
# exemption ended on 31 July 2025 (data dictionary, HB 2042 sale date requirement).
# Trend is the high scenario. The horizon is three years, the span the backtest
# checks; the intervals grow fast after that, so later years would mean little.
N_SIM <- 10000L
HORIZON <- 3L
project <- function(cut, last, rule) {
  known <- rates[year %in% (cut - 6L):(cut - 2L)]
  le <- log(rates[year %in% (cut - 10L):cut, entries])
  d <- diff(le)
  drift <- if (rule == "Trend") mean(d) else 0
  sigma <- if (rule == "Trend") sd(d) else sqrt(mean(d^2))   # SD of the rule's own errors
  h <- last - cut
  x <- rnorm(N_SIM, mean(known$exit_rate), sd(known$exit_rate))
  g <- if (rule == "Trend") rnorm(N_SIM, drift, sigma / sqrt(length(d))) else rep(0, N_SIM)
  shocks <- matrix(rnorm(N_SIM * h, 0, sigma), N_SIM, h)
  logE <- le[length(le)] + t(apply(shocks, 1, cumsum)) + outer(g, seq_len(h))
  stock <- rates[year == cut - 1L, active] * (1 - x + mean(known$return_rate)) +
    rates[year == cut, entries]
  paths <- matrix(NA_real_, N_SIM, h + 1L)
  paths[, 1] <- stock
  for (k in seq_len(h)) paths[, k + 1L] <- paths[, k] * (1 - x + mean(known$return_rate)) +
    exp(logE[, k])
  q <- apply(paths, 2, quantile, probs = c(0.025, 0.10, 0.50, 0.90, 0.975))
  ent <- apply(exp(logE), 2, quantile, probs = 0.5)
  data.table(cut = cut, rule = rule, year = cut:last, entries_median = c(rates[year == cut,
      entries], ent),
             lo95 = q[1, ], lo80 = q[2, ], median = q[3, ], hi80 = q[4, ], hi95 = q[5, ],
             exit_rate_used = mean(known$exit_rate), exit_rate_sd = sd(known$exit_rate),
             return_rate_used = mean(known$return_rate), entry_growth = drift,
             entry_sigma = sigma)
}
proj <- rbindlist(lapply(c("Level", "Trend"), function(r) rbind(
  project(2022L, 2022L + HORIZON, r), project(LAST_FULL, LAST_FULL + HORIZON, r))))
proj <- merge(proj, rates[, .(year, actual = active)], by = "year", all.x = TRUE)
proj[year > LAST_FULL, actual := NA]
setorder(proj, cut, rule, year)

# 20.3 Backtest: data cut at 2022, compared with the actual 2023-2025 counts. The
# file is today's file cut at 2022, not the file as it stood in 2022. The 2025
# gap-filled count uses the partial 2026, so it is very slightly provisional.
backtest <- proj[cut == 2022L & year > 2022L]
backtest[, `:=`(error_pct = 100 * (median - actual) / actual,
                in_80 = actual >= lo80 & actual <= hi80, in_95 = actual >= lo95 & actual <= hi95)]
# The same projection with the actual entries isolates the exit and return side.
bt_rates <- rates[year %in% 2016:2020]
a <- rates[year == 2021L, active]
exit_side <- rbindlist(lapply(2022:LAST_FULL, function(y) {
  a <<- a * (1 - mean(bt_rates$exit_rate) + mean(bt_rates$return_rate)) + rates[year == y, entries]
  data.table(year = y, projected_with_actual_entries = a, actual = rates[year == y, active])
}))
exit_side[, error_pct := 100 * (projected_with_actual_entries - actual) / actual]
out(proj, "20_projection_all.csv")
out(backtest, "20_projection_backtest.csv")
out(exit_side, "20_projection_backtest_actual_entries.csv")
out(proj[cut == LAST_FULL], "20_projection_2026_2028.csv")

# 20.4 Early check on 2026: entries from 1 January to 30 September each year.
jan_sep <- history[month(entry_date) <= 9L & entry_year >= 2022L,
                   .(entries_jan_sep = .N), keyby = entry_year]
jan_sep <- merge(jan_sep, rates[, .(entry_year = year, entries_full_year = entries)],
                 by = "entry_year")
jan_sep[entry_year == LAST_YEAR, entries_full_year := NA]
jan_sep[, jan_sep_share := entries_jan_sep / entries_full_year]
share_js <- jan_sep[entry_year %in% (LAST_FULL - 2L):LAST_FULL, mean(jan_sep_share)]
entries_2026_est <- jan_sep[entry_year == LAST_YEAR, entries_jan_sep] / share_js
check_2026 <- data.table(
  item = c("Entries 1 Jan-30 Sep 2026", "Same period 2025", "Change on 2025 (%)",
           "Jan-Sep share of the year, 2023-2025 mean", "Full-year 2026 estimate at that share",
           "Level rule, 2026 median entries", "Trend rule, 2026 median entries"),
  value = c(jan_sep[entry_year == LAST_YEAR, entries_jan_sep],
            jan_sep[entry_year == LAST_FULL, entries_jan_sep],
            100 * (jan_sep[entry_year == LAST_YEAR, entries_jan_sep] /
                     jan_sep[entry_year == LAST_FULL, entries_jan_sep] - 1),
            share_js, entries_2026_est,
            proj[cut == LAST_FULL & rule == "Level" & year == LAST_YEAR, entries_median],
            proj[cut == LAST_FULL & rule == "Trend" & year == LAST_YEAR, entries_median]))
out(jan_sep, "20_entries_jan_sep.csv")
out(check_2026, "20_check_2026_entries.csv")

pp <- copy(proj)
pp[, panel := fifelse(cut == 2022L, "Backtest: records up to 2022",
                      sprintf("Projection: records up to %d", LAST_FULL))]
act_line <- rates[year >= 2016L & year <= LAST_FULL, .(year, actual = active)]
act_line <- rbind(cbind(act_line[year <= 2025L], panel = "Backtest: records up to 2022"),
                  cbind(act_line, panel = sprintf("Projection: records up to %d", LAST_FULL)))
p <- ggplot(pp, aes(year)) +
  geom_ribbon(aes(ymin = lo95 / 1000, ymax = hi95 / 1000, fill = rule), alpha = 0.15) +
  geom_ribbon(aes(ymin = lo80 / 1000, ymax = hi80 / 1000, fill = rule), alpha = 0.25) +
  geom_line(aes(y = median / 1000, colour = rule, linetype = rule), linewidth = 0.9) +
  geom_line(data = act_line, aes(year, actual / 1000), colour = INK, linewidth = 0.7) +
  geom_point(data = act_line, aes(year, actual / 1000), colour = INK, size = 1.3) +
  facet_wrap(~panel, scales = "free") +
  scale_colour_manual(values = c(Level = COL1, Trend = COL2),
                      labels = c("Level: entries stay at the last year's level (primary)",
                                 "Trend: entries keep their ten-year growth")) +
  scale_fill_manual(values = c(Level = COL1, Trend = COL2), guide = "none") +
  scale_linetype_manual(values = c(Level = "solid", Trend = "dashed"), guide = "none") +
  scale_y_continuous(labels = scales::comma) +
  scale_x_continuous(breaks = function(l) seq(ceiling(l[1]), floor(l[2]), 2)) +
  guides(colour = guide_legend(nrow = 2)) +
  theme(legend.key.height = unit(0.35, "cm")) +
  labs(title = "Active plug-in vehicles: backtest and projection",
       subtitle = paste("Black: actual gap-filled count. Bands: 80% and 95% simulation intervals.",
                        "\nSame exit and return rates in both rules; only entries differ."),
       x = "Year", y = "Active vehicles (thousands)",
       caption = cap_n(sprintf("%s simulated paths per rule", comma(N_SIM))))
fig(p, "20_01_projection.png", w = 8, h = 4.8)
say(paste("20. Projection to %d (Level): %s (95%% interval %s-%s). Backtest error in %d:",
          "Level %.1f%%, Trend %.1f%%; with actual entries %.1f%%."),
    LAST_FULL + HORIZON, comma(proj[cut == LAST_FULL & rule == "Level" & year == LAST_FULL +
                                    HORIZON, median]),
    comma(proj[cut == LAST_FULL & rule == "Level" & year == LAST_FULL + HORIZON, lo95]),
    comma(proj[cut == LAST_FULL & rule == "Level" & year == LAST_FULL + HORIZON, hi95]), LAST_FULL,
    backtest[rule == "Level" & year == LAST_FULL, error_pct],
    backtest[rule == "Trend" & year == LAST_FULL, error_pct],
    exit_side[year == LAST_FULL, error_pct])


# ---- 21. EXTENSION 7: LEGISLATIVE DISTRICTS AND ELECTRIC UTILITIES ----------

# 21.1 District and utility at the vehicle's last record of each year, as for county.
# Descriptive only. An area's figure is shown only when it has at least MIN_AREA
# vehicles in the year concerned (a share from 500 vehicles has a standard error
# of 2.2 points at most).
MIN_AREA <- 500L
geo_year <- clean[, .(district = `Legislative District`[.N], utility = `Electric Utility`[.N]),
                  by = .(vehicle_id, year)]
geo_year[district == "", district := NA_character_]
geo_year <- merge(geo_year, vehicle_year[, .(vehicle_id, year, county, ev_type, age)],
                  by = c("vehicle_id", "year"))
assert(nrow(geo_year) == nrow(vehicle_year), "district rows differ from vehicle-years")

# 21.2 Are districts on one map for every year? Washington redrew its districts
# in 2022. If older records used the old map, a census tract's district would
# change in 2022. Check tracts that sit in one district both before and after.
tract_ld <- clean[`Legislative District` != "" & year != 2022L,
                  .(n_ld = uniqueN(`Legislative District`), ld = `Legislative District`[1L]),
                  by = .(tract = `2020 GEOID`, after = year > 2022L)]
tract_ld <- dcast(tract_ld[n_ld == 1L], tract ~ after, value.var = "ld")
setnames(tract_ld, c("tract", "before", "after"))
map_check <- tract_ld[!is.na(before) & !is.na(after),
                      .(tracts = .N, district_changed = sum(before != after))]
map_check[, changed_pct := pct(district_changed, tracts, 2)]
out(map_check, "21_district_map_check.csv")

# 21.3 Districts. Each holds about one 49th of the state's residents (they are
# drawn to near-equal population after each census), so vehicles per 1,000
# residents is approximately vehicles / (state population / 49) x 1,000.
exit21 <- data.table(vehicle_id = ids, exit_2021 = exit_mat(TRAIN_YEAR, 2L))
area_stats <- function(by_col) {
  g <- geo_year[!is.na(get(by_col))]
  d <- g[year %in% c(2019L, TRAIN_YEAR, LAST_FULL),
         .(vehicles = .N, bev_share = 100 * mean(ev_type == "BEV"), mean_age = mean(age)),
         by = .(area = get(by_col), year)]
  w <- dcast(d, area ~ year, value.var = c("vehicles", "bev_share", "mean_age"))
  ex <- merge(g[year == TRAIN_YEAR, .(vehicle_id, area = get(by_col))], exit21,
              by = "vehicle_id")[, .(exit_rate_2021 = 100 * mean(exit_2021)), by = area]
  w <- merge(w, ex, by = "area", all.x = TRUE)
  n19 <- paste0("vehicles_", 2019L); n21 <- paste0("vehicles_", TRAIN_YEAR)
  n25 <- paste0("vehicles_", LAST_FULL)
  for (v in names(w)[-1]) set(w, which(is.na(w[[v]])), v, if (grepl("^vehicles", v)) 0 else NA)
  w[, share_of_state_2025 := 100 * get(n25) / sum(get(n25))]
  w[, growth_2019_2025 := fifelse(get(n19) >= MIN_AREA, log(get(n25) / get(n19)), NA_real_)]
  w[get(n21) < MIN_AREA, exit_rate_2021 := NA]
  w[get(n25) < MIN_AREA, c(paste0("bev_share_", LAST_FULL), paste0("mean_age_", LAST_FULL)) := NA]
  w[get(n19) < MIN_AREA, c("bev_share_2019", "mean_age_2019") := NA]
  setnames(w, "area", by_col)
  w[order(-get(n25))]
}
district_tab <- area_stats("district")
residents_per_district <- pop[year %in% c(2019L, LAST_FULL), .(p = sum(population) / 49),
                              keyby = year]
district_tab[, `:=`(
  per_1000_2019 = 1000 * vehicles_2019 / residents_per_district[year == 2019L, p],
  per_1000_2025 = 1000 * vehicles_2025 / residents_per_district[year == LAST_FULL, p])]
out(district_tab, "21_districts.csv")
top5 <- function(v) 100 * sum(head(sort(v, decreasing = TRUE), 5)) / sum(v)
district_spread <- data.table(
  year = c(2019L, LAST_FULL),
  districts = 49L,
  top5_share = c(top5(district_tab$vehicles_2019), top5(district_tab$vehicles_2025)),
  highest_to_lowest = c(max(district_tab$vehicles_2019) / min(district_tab$vehicles_2019),
                        max(district_tab$vehicles_2025) / min(district_tab$vehicles_2025)),
  cv = c(sd(district_tab$vehicles_2019) / mean(district_tab$vehicles_2019),
         sd(district_tab$vehicles_2025) / mean(district_tab$vehicles_2025)))
out(district_spread, "21_district_spread.csv")

# 21.4 Electric utility territories, as labelled in the source. Where territories
# overlap the label lists them all ("|" same type, "||" different types), so a
# label is an area, not one company's customers. Only labels with MIN_AREA
# vehicles in 2025 are kept; the rest are summed into one row.
utility_tab <- area_stats("utility")
small_u <- utility_tab[vehicles_2025 < MIN_AREA]
utility_tab <- rbind(utility_tab[vehicles_2025 >= MIN_AREA],
                     data.table(utility = sprintf("Other territories (%d labels)", nrow(small_u)),
                                vehicles_2019 = sum(small_u$vehicles_2019),
                                vehicles_2021 = sum(small_u$vehicles_2021),
                                vehicles_2025 = sum(small_u$vehicles_2025),
                                share_of_state_2025 = sum(small_u$share_of_state_2025)),
                     fill = TRUE)
out(utility_tab, "21_utility_territories.csv")

dd <- melt(district_tab[, .(district, `2019` = per_1000_2019, `2025` = per_1000_2025)],
           id.vars = "district", variable.name = "year", value.name = "per_1000")
dd[, district := factor(district, levels = district_tab[order(per_1000_2025), district])]
p <- ggplot(dd, aes(per_1000, district)) +
  geom_line(aes(group = district), colour = GRIDCOL, linewidth = 1.2) +
  geom_point(aes(colour = year), size = 2) +
  scale_colour_manual(values = c(`2019` = COL2, `2025` = COL1)) +
  labs(title = "Plug-in vehicles per 1,000 residents by legislative district",
       subtitle = paste("Approximate: each district holds about 1/49 of the state's residents.",
                        sprintf(paste("\nThe five largest held %.0f%% of vehicles in 2019",
                                      "and %.0f%% in %d."),
                                district_spread$top5_share[1], district_spread$top5_share[2],
                                LAST_FULL)),
       x = "Vehicles per 1,000 residents (approx.)", y = "Legislative district",
       caption = cap_n(sprintf("%s vehicles in 2025, 49 districts",
                               comma(sum(district_tab$vehicles_2025))))) +
  theme(axis.text.y = element_text(size = 6.5))
fig(p, "21_01_districts_per_1000.png", w = 7, h = 8)
say(paste("21. Districts: top five held %.1f%% of vehicles in 2019 and %.1f%% in %d;",
          "district map changed for %.2f%% of tracts. %d utility territories kept."),
    district_spread$top5_share[1], district_spread$top5_share[2], LAST_FULL,
    map_check$changed_pct, utility_tab[vehicles_2025 >= MIN_AREA, .N] - 1L)

writeLines(capture.output(sessionInfo()), file.path(TAB, "00_session_info.txt"))
say("Finished. All assertions passed.")

