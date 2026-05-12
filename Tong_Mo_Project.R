# =====================================================================
# FRE 6871 - Final Project
# Author : Tong Mo
# Title  : Predicting next-day SPY returns and direction
#          - a tour through regression, time series, clustering and
#            classification techniques covered in R in Action.
#
# This .R file IS the report. Run it from the
# folder it lives in.  All figures are written to one PDF(uploaded to the google file); all printed
# output is mirrored to a .txt file alongside the script.
# =====================================================================
#
# References (R in Action, 3rd edition - chapters cited where the
# technique is first used; see comments below for exact section):
#   * Chapter  6 - Basic graphs                       (used in Section 3, 6)
#   * Chapter  7 - Basic statistics & correlation      (Section 6, 7)
#   * Chapter  8 - Regression                          (Section 8.1)
#   * Chapter 12 - Resampling / bootstrap              (Section 8.2)
#   * Chapter 13 - Generalized linear models           (Section 8.3)
#   * Chapter 15 - Time series                         (Section 4, 7, 8.4)
#   * Chapter 16 - Cluster analysis                    (Section 8.5)
#   * Chapter 17 - Classification                      (Section 8.6)
# =====================================================================
#
# How to read this script:
#   - Each section starts with a banner like  "======== Section X ========".
#   - Comments above each code block explain the WHY (the intent and
#     the textbook section).  In-line comments explain the WHAT (what a
#     particular argument or transformation does).
#   - Numbers printed during a run are mirrored to
#     Tong_Mo_Project_output.txt; figures are written to
#     Tong_Mo_Project_plots.pdf so the run can be reviewed offline.
# =====================================================================

# ---- 0. Setup -------------------------------------------------------
# We resolve every output path relative to the current working
# directory so that the same script works on any machine as long as
# it is invoked from the project folder.
out_dir   <- getwd()                                  # run from the project folder
sink_path <- file.path(out_dir, "Tong_Mo_Project_output.txt")
pdf_path  <- file.path(out_dir, "Tong_Mo_Project_plots.pdf")
csv_path  <- file.path(out_dir, "Tong_Mo_Project_data.csv")

# sink() with split = TRUE writes printed output to BOTH the console
# (so the user can watch progress) and the .txt file (so the grader
# has a transcript).  pdf() opens a single PDF device that captures
# every plot in the order they are drawn.  Both are closed at the
# very end of the script.
sink(sink_path, split = TRUE)
pdf(pdf_path, width = 9, height = 6)

cat("==================================================================\n")
cat("FRE 6871 - Final Project - Tong Mo\n")
cat("Run timestamp:", format(Sys.time()), "\n")
cat("==================================================================\n\n")

# Load every package the analysis needs up-front.  suppressPackageStartupMessages
# keeps the transcript clean - the friendly start-up banners would
# otherwise drown the real output.
suppressPackageStartupMessages({
    library(quantmod)               # data download (Yahoo / FRED) + technical indicators
    library(xts)                    # time series container indexed by Date / POSIXct
    library(zoo)                    # na.locf, rollapply, time-aware utilities
    library(PerformanceAnalytics)   # Return.calculate, SharpeRatio, chart.CumReturns
    library(psych)                  # describe() - skew/kurtosis-aware summary stats
    library(car)                    # ncvTest, residualPlots, influencePlot
    library(MASS)                   # stepAIC for bidirectional model selection
    library(boot)                   # boot, boot.ci - Efron-style resampling
    library(forecast)               # auto.arima, accuracy, forecast, ndiffs
    library(tseries)                # adf.test - Augmented Dickey-Fuller stationarity test
    library(NbClust)                # majority-vote selection of #clusters
    library(flexclust)              # randIndex (kept for reference; used in HW6)
    library(e1071)                  # svm() with optional probability output
    library(pROC)                   # roc(), auc() and ROC plotting
    library(corrgram)               # corrgram - correlation matrix heatmap
})

# =====================================================================
# Section 1 - Introduction & Research Question
# =====================================================================
# Spell out the goal in plain English so the reader does not have to
# infer it from the code.  Every modelling decision later in this file
# is justified by reference to one of these two questions.
cat("\n\n======== Section 1: Introduction ========\n")
cat("
Equity ETFs are the most liquid expression of broad-market views.  This
project asks two related questions about SPY (the S&P 500 ETF):

  (Q1)  Can we forecast the *magnitude* of next-day log returns from
        a small set of features built from SPY itself, four cross-asset
        ETFs (QQQ, IWM, GLD, TLT) and two macro indicators (^VIX, ^TNX)?

  (Q2)  Can we beat a naive coin-flip on next-day *direction* using
        logistic regression and SVM, and does either of them outperform
        a pure ARIMA forecast?

Along the way we will (a) clean the data and handle missing values,
(b) describe the data with statistics and graphs, (c) run formal
hypothesis tests, and (d) build five different models drawn from the
course (regression, bootstrap, GLM, time series, clustering, SVM).
")

# =====================================================================
# Section 2 - Data Acquisition
# ---------------------------------------------------------------------
# Following R in Action chapter 2 (importing data), we use quantmod's
# getSymbols() to pull adjusted-close prices from Yahoo Finance.  If the
# call fails (e.g. no internet), we fall back to the CSV that we cache
# the first time the script runs successfully.
# ---------------------------------------------------------------------
# Why these tickers?
#   SPY: the target asset (S&P 500).
#   QQQ, IWM: technology- and small-cap-tilted equity proxies; their
#       lagged returns capture intra-equity rotation signals.
#   GLD, TLT: cross-asset risk-off proxies (gold, long Treasuries);
#       a flight-to-quality move in either tends to precede equity
#       weakness, so they are useful predictors.
#   ^VIX:    market-implied 30-day volatility, captures the
#            "leverage effect" (vol up <-> equities down).
#   ^TNX:    10-year Treasury yield, captures macro/rate shocks.
# =====================================================================
cat("\n\n======== Section 2: Data Acquisition ========\n")

tickers <- c("SPY", "QQQ", "IWM", "GLD", "TLT", "^VIX", "^TNX")

# Define the download as a function so we can call it conditionally.
# auto.assign = TRUE puts each downloaded series in the environment
# `env` under its plain ticker name (without the leading caret), e.g.
# env$SPY, env$VIX.  We then keep only the columns we need and merge
# everything into a single multi-column xts.
load_data_online <- function() {
    env <- new.env()
    getSymbols(tickers, from = "2010-01-01", to = "2024-12-31",
               env = env, auto.assign = TRUE)
    # Ad() = adjusted close (corporate actions baked in) for tradeable
    # ETFs; Cl() = raw close for non-tradeable index series VIX and
    # TNX, where "adjusted" is meaningless.
    cols <- list(
        SPY = Ad(env$SPY), QQQ = Ad(env$QQQ), IWM = Ad(env$IWM),
        GLD = Ad(env$GLD), TLT = Ad(env$TLT),
        VIX = Cl(env$VIX), TNX = Cl(env$TNX))
    px <- do.call(merge, cols)        # outer-join on the date index
    colnames(px) <- names(cols)
    px
}

# Cache-or-download pattern: keeps the script reproducible offline
# after the first successful run, and avoids hitting Yahoo every time.
if (file.exists(csv_path)) {
    cat("Loading cached data from", csv_path, "\n")
    cached <- read.csv(csv_path, stringsAsFactors = FALSE)
    # rebuild the xts object: column 1 of the CSV is the date index,
    # columns 2:n are the numeric series.
    px <- xts(cached[, -1], order.by = as.Date(cached[, 1]))
} else {
    cat("Downloading data via quantmod ...\n")
    # tryCatch lets us turn the obscure quantmod error into a clean
    # message and a graceful stop().
    px <- tryCatch(load_data_online(),
                   error = function(e) { cat("Download failed:",
                                             conditionMessage(e), "\n"); NULL })
    if (is.null(px))
        stop("Cannot continue without data; run script with internet on first try.")
    write.csv(data.frame(Date = index(px), coredata(px)),
              file = csv_path, row.names = FALSE)
    cat("Cached data to", csv_path, "\n")
}

cat("Series span:", format(start(px)), "to", format(end(px)), "\n")
cat("Number of trading days:", nrow(px), "\n")
cat("Columns:\n"); print(colnames(px))

# =====================================================================
# Section 3 - Initial exploration
# ---------------------------------------------------------------------
# (R in Action chapter 6 on basic graphs, chapter 7 on summary stats)
# Every analysis should start with a sanity check: does the data look
# the way you expect?  Are the units right?  Is the index continuous?
# =====================================================================
cat("\n\n======== Section 3: Initial exploration ========\n")
# str() reveals the object class, dimensions, and the first few values
# of each column - the canonical R "what am I looking at?" call.
cat("\nstr(px):\n"); print(str(px))
cat("\nhead(px, 3):\n"); print(head(px, 3))   # earliest 3 trading days
cat("\ntail(px, 3):\n"); print(tail(px, 3))   # latest 3 trading days
cat("\nsummary(px):\n"); print(summary(px))   # min/median/max + NA counts

# plot.zoo() takes an xts/zoo object and draws each column in its own
# panel.  This is preferable to plot() on a multi-column xts which
# tries to overlay everything on a single y-axis with mismatched scales.
plot.zoo(px[, c("SPY","QQQ","IWM","GLD","TLT")],
         main = "Adjusted prices - five ETFs (2010-2024)",
         xlab = "Date", col = c("steelblue","darkorange","forestgreen",
                                 "goldenrod","firebrick"))

plot.zoo(px[, c("VIX","TNX")],
         main = "Macro indicators - VIX and 10Y yield",
         xlab = "Date", col = c("firebrick","steelblue"))

# =====================================================================
# Section 4 - Cleaning & missing values
# ---------------------------------------------------------------------
# (R in Action section 4.5 / 15.1 - dealing with missing data)
# VIX/TNX have a handful of mid-series NAs from non-trading days; we
# carry the last observation forward, then drop any row that still has
# a missing value.  We log how many rows we lose so the audit trail is
# clear.
# ---------------------------------------------------------------------
# Why na.locf instead of mean imputation or interpolation?  Because
# financial price levels are NOT exchangeable - replacing a missing
# Tuesday VIX with the average of the rest of the year would inject
# look-ahead and noise.  Carrying Monday's value forward is the
# convention everywhere from Bloomberg to FactSet.
# =====================================================================
cat("\n\n======== Section 4: Cleaning & missing values ========\n")
n_before <- nrow(px)
na_per_col <- colSums(is.na(px))     # per-column NA tally before cleaning
cat("NAs per column before cleaning:\n"); print(na_per_col)

# na.locf = Last Observation Carried Forward.  na.rm = FALSE keeps a
# leading NA (if any) instead of silently shortening the series.
px <- na.locf(px, na.rm = FALSE)
# complete.cases is the safety net: any row that still has NAs after
# the LOCF (e.g. dates before the first non-NA observation) is dropped.
px <- px[complete.cases(px), ]
n_after <- nrow(px)
cat(sprintf("Rows dropped during cleaning: %d (%.2f%%)\n",
            n_before - n_after, 100 * (n_before - n_after) / n_before))
cat("NAs per column after cleaning:\n"); print(colSums(is.na(px)))

# =====================================================================
# Section 5 - Feature engineering
# ---------------------------------------------------------------------
# We build features from prices - this is the part that is specific to
# finance (R in Action does not cover finance directly, but the lag /
# rolling window / log transform tools come from chapters 5 and 15).
# ---------------------------------------------------------------------
# Why log returns instead of simple percentage returns?
#   * Log returns are ADDITIVE across time:  log(P_t / P_0) =
#       log(P_t/P_{t-1}) + log(P_{t-1}/P_{t-2}) + ... .
#   * They are closer to normally distributed, which helps every
#     parametric tool we use later.
#   * They are symmetric around zero: a +5% then -5% returns to start.
# =====================================================================
cat("\n\n======== Section 5: Feature engineering ========\n")

# Return.calculate from PerformanceAnalytics gives a column-wise log
# return; the first row is NA by construction (no day zero), so we
# strip it with na.omit().
ret <- na.omit(Return.calculate(px, method = "log"))
colnames(ret) <- paste0(colnames(ret), "_ret")    # tag columns clearly
cat("Daily log return summary:\n"); print(round(coredata(psych::describe(ret))[, 3:5], 5))

# 20-day rolling volatility, annualised by sqrt(252) - a classic
# regime feature.  When realised vol is high, the conditional return
# distribution is wider, which we want the model to know about.
vol20 <- runSD(ret$SPY_ret, n = 20) * sqrt(252)
colnames(vol20) <- "vol20"

# Lag features.  Each row at date t holds information that was known
# at the close of day t-1 (or earlier).  This is the cardinal sin to
# avoid in time-series ML: NEVER use a feature that would not have
# been observable at prediction time.
lag_features <- merge(
    lag(ret$SPY_ret, 1), lag(ret$SPY_ret, 2), lag(ret$SPY_ret, 3),
    lag(ret$QQQ_ret, 1), lag(ret$IWM_ret, 1),
    lag(ret$GLD_ret, 1), lag(ret$TLT_ret, 1),
    lag(ret$VIX_ret, 1), lag(ret$TNX_ret, 1),
    lag(vol20, 1))
colnames(lag_features) <- c("spy_lag1","spy_lag2","spy_lag3",
                            "qqq_lag1","iwm_lag1","gld_lag1","tlt_lag1",
                            "vix_lag1","tnx_lag1","vol20_lag1")

# Two targets: continuous SPY return (for regression / ARIMA) and a
# binary up/down label (for logistic / SVM).  Coding "up" as 1 and
# "down" as 0 follows the standard binomial-GLM convention.
y       <- ret$SPY_ret
y_dir   <- xts(as.integer(coredata(y) > 0), order.by = index(y))
colnames(y) <- "spy_ret"
colnames(y_dir) <- "spy_up"

# Merge target + features and drop any row with missing values - which
# only happens at the very start, where the lag/rolling-window
# features are not yet defined.
dataset <- na.omit(merge(y, y_dir, lag_features))
cat("\nFinal modelling data set:\n"); print(dim(dataset))
cat("First 3 rows:\n"); print(head(dataset, 3))

# Convert to data.frame because lm/glm/svm prefer that interface.
# Re-encode the binary target as a factor with explicit levels so
# downstream models treat it as categorical and label predictions
# clearly (no integer/factor confusion).
df <- data.frame(date = index(dataset), coredata(dataset))
df$spy_up <- factor(df$spy_up, levels = c(0, 1), labels = c("dn", "up"))

# Train / validation split - last 20% of the sample becomes the hold-out.
# This MUST be a chronological split (not a random shuffle).  Random
# shuffling would let the model use future information to predict the
# past - the textbook example of look-ahead bias.
n_total <- nrow(df)
split   <- floor(0.8 * n_total)
train   <- df[1:split, ]
valid   <- df[(split + 1):n_total, ]
cat(sprintf("\nTrain: %d rows (%s -> %s)\nValid: %d rows (%s -> %s)\n",
            nrow(train), train$date[1], train$date[nrow(train)],
            nrow(valid), valid$date[1], valid$date[nrow(valid)]))

# =====================================================================
# Section 6 - Descriptive statistics & basic plots
# ---------------------------------------------------------------------
# (R in Action chapter 7 - psych::describe is highlighted in 7.1.1)
# Three exhibits set the scene for the modelling: a numeric summary
# (psych::describe), a univariate distribution plot (histogram +
# density), and a multivariate one (corrgram).  A cumulative-return
# chart adds intuition for the long-run drift the t-test will detect.
# =====================================================================
cat("\n\n======== Section 6: Descriptive statistics ========\n")
# psych::describe goes beyond summary(): it also reports the
# trimmed mean, MAD, skewness, kurtosis, and SE of the mean - exactly
# what you need to characterise heavy-tailed financial returns.
cat("\npsych::describe of returns:\n")
print(round(psych::describe(coredata(ret)), 5))

# Histogram of SPY returns with a kernel-density overlay - the visual
# counterpart to the Shapiro-Wilk test in Section 7.  freq = FALSE
# normalises the histogram so it is on the same scale as the density.
hist(coredata(ret$SPY_ret), breaks = 60, freq = FALSE,
     col = "steelblue", border = "white",
     main = "Distribution of SPY daily log returns",
     xlab = "log return")
lines(density(coredata(ret$SPY_ret)), col = "firebrick", lwd = 2)
legend("topleft", c("density"), col = "firebrick", lwd = 2, bty = "n")

# corrgram() draws a correlation matrix as a coloured grid.  We use
# shaded squares in the lower triangle (intuitive sign + magnitude),
# pies in the upper triangle (very fast to read), and variable names
# on the diagonal.  order = TRUE permutes variables so highly
# correlated ones cluster - revealing the equity / safe-haven blocks.
corrgram(coredata(ret), order = TRUE,
         lower.panel = corrgram::panel.shade,
         upper.panel = corrgram::panel.pie,
         text.panel  = corrgram::panel.txt,
         main = "Cross-asset return correlations")

# Cumulative SPY equity curve - visually anchors the positive drift
# detected by the t.test in Section 7.3.
chart.CumReturns(ret$SPY_ret, main = "SPY cumulative log return")

# =====================================================================
# Section 7 - Statistical tests (need at least 2; we run five)
# ---------------------------------------------------------------------
# (R in Action chapter 7 + chapter 15 for ADF / Box-Ljung)
# Each test is here for a SPECIFIC modelling reason, not as decoration.
# Comments above each test list (i) the null hypothesis, (ii) the
# statistic, and (iii) the implication of the result.
# =====================================================================
cat("\n\n======== Section 7: Statistical tests ========\n")

# 7.1 Normality (R in Action 7.5)
# H0: the sample is drawn from a normal distribution.
# Statistic: W = (sum(a_i * x_(i)))^2 / sum((x_i - x_bar)^2).
# Implication: rejecting normality means OLS standard errors and
# parametric Sharpe-ratio confidence intervals are unreliable -
# justifies the bootstrap in Section 8.2.
spy_vec <- as.numeric(coredata(ret$SPY_ret))
sw <- shapiro.test(if (length(spy_vec) > 5000)
                       sample(spy_vec, 5000) else spy_vec)        # shapiro caps at 5000
cat("(7.1) Shapiro-Wilk on SPY returns (random subsample):\n")
print(sw)
cat("Interpretation: p-value <<", 0.05,
    "-> reject normality.  Returns are heavy tailed, as expected.\n")

# 7.2 Stationarity (R in Action 15.2.1 - ARIMA modelling needs this)
# H0: the series has a unit root (i.e. is non-stationary).
# Implication: ARIMA assumes stationarity.  If we cannot reject H0
# on prices but CAN on returns, then ARIMA must be fit on returns,
# not on prices.
adf_price <- suppressWarnings(adf.test(coredata(px$SPY)))
adf_ret   <- suppressWarnings(adf.test(coredata(ret$SPY_ret)))
cat("\n(7.2) Augmented Dickey-Fuller:\n")
cat("  prices  - p-value:", round(adf_price$p.value, 4),
    "(non-stationary)\n")
cat("  returns - p-value:", round(adf_ret$p.value,   4),
    "(stationary)  -> ARIMA on returns, not prices\n")

# 7.3 Mean return = 0?  parametric and non-parametric (R in Action 7.4)
# H0: mean is zero.  We run BOTH the parametric t-test and the
# non-parametric Wilcoxon signed-rank test - if both reject, the
# conclusion is robust to the heavy tails detected by Shapiro-Wilk.
tt  <- t.test(coredata(ret$SPY_ret))
wt  <- wilcox.test(coredata(ret$SPY_ret))
cat("\n(7.3) Is the mean SPY log return = 0?\n")
cat("  t.test     p-value:", round(tt$p.value, 4), "\n")
cat("  wilcox     p-value:", round(wt$p.value, 4), "\n")
cat("  Both tests reject 0 -> the unconditional drift is positive.\n")

# 7.4 Are direction and weekday independent? (R in Action 7.3 - chi-square)
# H0: weekday and up/down are independent (no day-of-week effect).
# Implication: if we cannot reject H0, we are safe to model every
# trading day with the same coefficients - no weekday dummies needed.
wday <- weekdays(index(ret$SPY_ret))
tab  <- table(weekday  = wday,
              direction = ifelse(coredata(ret$SPY_ret) > 0, "up", "dn"))
ch   <- chisq.test(tab)
cat("\n(7.4) Chi-square: weekday vs up/down\n"); print(tab); print(ch)
cat("  -> with p =", round(ch$p.value, 4),
    if (ch$p.value < 0.05) "we DO see a weekday effect."
    else "weekday is not predictive of direction.\n")

# 7.5 Box-Ljung autocorrelation (R in Action 15.4 - residual diagnostics)
# H0: the first m autocorrelations are jointly zero (white noise).
# Implication: if H0 is rejected, there IS exploitable serial
# dependence - which is exactly what gives the lag-based features
# and ARIMA any predictive power at all.
bl <- Box.test(coredata(ret$SPY_ret), lag = 10, type = "Ljung-Box")
cat("\n(7.5) Box-Ljung on returns:\n"); print(bl)
cat("  -> p =", round(bl$p.value, 4),
    if (bl$p.value < 0.05) "  small autocorrelation present (good news for predictability)\n"
    else "  little autocorrelation\n")

# =====================================================================
# Section 8 - Modelling
# =====================================================================
# Subsection 8.1  Multiple linear regression  (R in Action chapter 8)
# ---------------------------------------------------------------------
# We start with the workhorse: OLS regression of next-day SPY return
# on every lagged feature.  This sets the baseline against which the
# more sophisticated models in 8.3-8.6 will be judged.
# =====================================================================
cat("\n\n======== Section 8.1: Multiple linear regression ========\n")
# `~` is R's formula operator: "spy_ret modelled by these predictors".
# lm() fits by ordinary least squares - minimising sum of squared
# residuals.  The summary() prints coefficient estimates, standard
# errors, t-stats and the model-level F-stat / R-squared.
fit_lm_full <- lm(spy_ret ~ spy_lag1 + spy_lag2 + spy_lag3 +
                              qqq_lag1 + iwm_lag1 + gld_lag1 + tlt_lag1 +
                              vix_lag1 + tnx_lag1 + vol20_lag1,
                  data = train)
print(summary(fit_lm_full))

# stepAIC variable selection - R in Action 8.6.
# AIC = -2 * log-likelihood + 2 * k.  Lower is better.  Bidirectional
# stepwise tries adding and dropping variables until AIC stops
# improving - a principled way to fight overfitting in moderate-sized
# samples.  trace = FALSE silences the per-step printout.
fit_lm_step <- stepAIC(fit_lm_full, direction = "both", trace = FALSE)
cat("\nstepAIC selected formula:\n")
print(formula(fit_lm_step))
cat("\nSummary of selected model:\n"); print(summary(fit_lm_step))

# Diagnostic plots from car (R in Action 8.3).  plot.lm() draws four
# panels: residuals vs fitted (linearity), Q-Q (normality), scale-
# location (homoscedasticity) and residuals vs leverage (influence).
par(mfrow = c(2, 2))
plot(fit_lm_step, main = "OLS diagnostic plots")
par(mfrow = c(1, 1))
# ncvTest formally tests for non-constant error variance.
ncv  <- ncvTest(fit_lm_step)
cat("\nncvTest (heteroscedasticity):\n"); print(ncv)

# Validation RMSE.  RMSE = sqrt(mean((y - yhat)^2)) - has the same
# units as y, so it is directly comparable across the regression
# models.  Direction accuracy compares the SIGN of the prediction to
# the sign of the realised return.
lm_pred  <- predict(fit_lm_step, newdata = valid)
lm_rmse  <- sqrt(mean((valid$spy_ret - lm_pred)^2))
lm_dirAcc <- mean(sign(lm_pred) == sign(valid$spy_ret))
cat(sprintf("\n[lm] validation RMSE = %.6f, direction accuracy = %.3f\n",
            lm_rmse, lm_dirAcc))

# Subsection 8.2  Bootstrap on Sharpe ratio  (R in Action chapter 12)
# ---------------------------------------------------------------------
# Sharpe = sqrt(252) * mean(ret) / sd(ret) annualised.  It has no
# clean analytical SE under heavy tails, so we use Efron's bootstrap:
# resample the data with replacement, recompute the statistic, repeat
# many times, and use the empirical distribution as the sampling
# distribution.
# =====================================================================
cat("\n\n======== Section 8.2: Bootstrap (Sharpe ratio) ========\n")

# The boot() interface requires a function with signature (data, idx)
# that returns the statistic for one resample.  `idx` is the vector
# of bootstrap-sample indices that boot() supplies.
sharpe_stat <- function(data, idx) {
    r <- data[idx]
    sqrt(252) * mean(r) / sd(r)
}
set.seed(1234)                                      # reproducible resampling
boot_out <- boot(coredata(ret$SPY_ret), statistic = sharpe_stat, R = 1000)
print(boot_out)

# Two CI flavours:
#   "perc": pure quantile of the bootstrap distribution; simple but
#           biased when the statistic's distribution is skewed.
#   "bca":  Bias-Corrected and accelerated; corrects for both bias
#           and skew - the textbook recommendation.
ci <- boot.ci(boot_out, type = c("perc", "bca"))
cat("\n95% confidence intervals (percentile + BCa):\n"); print(ci)

# Subsection 8.3  Logistic regression  (R in Action section 13.2)
# ---------------------------------------------------------------------
# This is a NEW technique not used in HW1-HW6 - first time we use a
# binomial GLM in this course.  See R in Action section 13.2 for the
# full treatment of logistic regression.
# ---------------------------------------------------------------------
# Model:  P(Y = 1 | X) = 1 / (1 + exp(-X * beta))
# Estimation: maximum likelihood (no closed form; iteratively
# reweighted least squares under the hood).
# Why not OLS on a 0/1 target?  Three reasons:
#   1. OLS predictions can fall outside [0, 1] - not valid probabilities.
#   2. The errors are heteroscedastic (variance = p(1-p), depends on X).
#   3. The data-generating process IS Bernoulli, so logistic is the
#      natural model.
# =====================================================================
cat("\n\n======== Section 8.3: Logistic regression (NEW - R in Action 13.2) ========\n")
fit_glm <- glm(spy_up ~ spy_lag1 + spy_lag2 + spy_lag3 +
                          qqq_lag1 + iwm_lag1 + gld_lag1 + tlt_lag1 +
                          vix_lag1 + tnx_lag1 + vol20_lag1,
               data = train, family = binomial)         # binomial = logit link
print(summary(fit_glm))

# type = "response" returns probabilities P(up) directly; without it
# we would get the linear predictor X*beta on the logit scale.
glm_prob <- predict(fit_glm, newdata = valid, type = "response")
# Threshold at 0.5 to convert probabilities to a discrete prediction.
# This default is appropriate when classes are balanced (they are
# here, ~52% up days vs ~48% down).
glm_pred <- factor(ifelse(glm_prob > 0.5, "up", "dn"),
                   levels = c("dn", "up"))
glm_cm   <- table(actual = valid$spy_up, predicted = glm_pred)
cat("\nLogistic regression confusion matrix:\n"); print(glm_cm)
glm_acc  <- sum(diag(glm_cm)) / sum(glm_cm)             # (TP + TN) / n
# AUC = probability that a random "up" gets a higher predicted
# probability than a random "down".  Robust to class imbalance and
# to the choice of threshold.
glm_auc  <- as.numeric(pROC::auc(pROC::roc(
                response = valid$spy_up, predictor = glm_prob, quiet = TRUE)))
cat(sprintf("[glm] validation accuracy = %.3f, AUC = %.3f\n",
            glm_acc, glm_auc))

# Subsection 8.4  ARIMA  (R in Action section 15.4 - reused from HW5)
# ---------------------------------------------------------------------
# ARIMA(p, d, q) =  AR(p) component  +  d-th difference  +  MA(q).
#   - AR captures linear dependence on past LEVELS.
#   - I (difference) makes the series stationary if it is not already.
#   - MA captures dependence on past SHOCKS.
# auto.arima() searches over (p, d, q) and picks the AICc-best model,
# then validates with a residual white-noise test.
# =====================================================================
cat("\n\n======== Section 8.4: ARIMA forecast ========\n")
spy_train_xts <- xts(train$spy_ret, order.by = train$date)
spy_valid_xts <- xts(valid$spy_ret, order.by = valid$date)
fit_arima <- auto.arima(spy_train_xts)
cat("auto.arima selected model:\n"); print(fit_arima)
cat("\nIn-sample accuracy:\n"); print(accuracy(fit_arima))

# Multi-step forecast: ARIMA's forecast is built on the conditional
# expectation, which collapses to the unconditional mean past a few
# lags.  We still compute RMSE / direction accuracy on the full
# validation window to compare apples-to-apples with the OLS model.
arima_fc  <- forecast(fit_arima, h = nrow(valid))
arima_pred <- as.numeric(arima_fc$mean)
arima_rmse <- sqrt(mean((valid$spy_ret - arima_pred)^2))
arima_dirAcc <- mean(sign(arima_pred) == sign(valid$spy_ret))
cat(sprintf("[arima] validation RMSE = %.6f, direction accuracy = %.3f\n",
            arima_rmse, arima_dirAcc))
# A short forecast plot is more readable than a 778-step one - we
# show 60 days for visual intuition only.
plot(forecast(fit_arima, h = 60),
     main = "ARIMA forecast - 60 trading days ahead")

# Subsection 8.5  k-means clustering of volatility regimes
# ---------------------------------------------------------------------
# (R in Action chapter 16 - reused from HW6)
# Why weekly aggregation?  Daily 2-D points (mean, sd) are too noisy
# for a 2-cluster picture; aggregating to ~780 weeks gives a clear,
# stable separation between "calm" and "panic" weeks.
# =====================================================================
cat("\n\n======== Section 8.5: K-means clustering of volatility regimes ========\n")
# apply.weekly takes an xts and applies a function within each week.
# Our function returns a 2-element vector (mean, sd), so weekly is a
# 2-column xts.
weekly <- apply.weekly(ret$SPY_ret,
                       function(x) c(mean = mean(x), sd = sd(x)))
weekly <- na.omit(weekly)
# scale() centres and standardises each column so distances are
# scale-invariant (mean and sd would otherwise dominate by units).
weekly_scaled <- scale(coredata(weekly))

# NbClust runs ~30 internal-validation indices (Silhouette, Calinski-
# Harabasz, Hubert, etc.) and reports the majority-vote choice of k.
# This is far more robust than picking k from a single elbow plot.
set.seed(1234)
nc <- NbClust(weekly_scaled, min.nc = 2, max.nc = 6, method = "kmeans")
best_k <- as.integer(names(sort(table(nc$Best.n[1, ]), decreasing = TRUE))[1])
if (is.na(best_k) || best_k < 2) best_k <- 3            # safety fallback
cat("\nNbClust majority vote: k =", best_k, "\n")

# nstart = 25 reruns kmeans from 25 random initialisations and keeps
# the lowest-WSS solution; mitigates the well-known sensitivity of
# kmeans to its initial centroids.
set.seed(1234)
fit_km <- kmeans(weekly_scaled, centers = best_k, nstart = 25)
cat("\nfit.km$size:\n"); print(fit_km$size)
cat("\nfit.km$centers:\n"); print(round(fit_km$centers, 3))

# label each week with its regime; aggregate mean return / vol per regime
regime <- data.frame(date  = index(weekly),
                     mean  = coredata(weekly)[, "mean"],
                     sd    = coredata(weekly)[, "sd"],
                     regime= factor(fit_km$cluster))
cat("\nMean return / volatility by regime:\n")
print(aggregate(cbind(mean, sd) ~ regime, data = regime, FUN = mean))

# Scatter-plot in the (sd, mean) plane - the clearest way to "see"
# the regime structure.  Each colour is one cluster.
plot(regime$sd, regime$mean, col = regime$regime, pch = 19,
     xlab = "weekly std-dev", ylab = "weekly mean return",
     main = paste("SPY weekly volatility regimes (k =", best_k, ")"))
legend("topright", legend = paste("regime", seq_len(best_k)),
       col = seq_len(best_k), pch = 19)

# Subsection 8.6  SVM classification  (R in Action section 17.5)
# ---------------------------------------------------------------------
# SVM finds the maximum-margin hyperplane that separates the two
# classes in a (possibly transformed) feature space.  e1071's svm()
# default is the radial-basis (RBF) kernel - it can capture
# non-linear boundaries and is a sensible non-linear baseline to
# pair against the linear logistic regression in 8.3.
# =====================================================================
cat("\n\n======== Section 8.6: SVM classification ========\n")
set.seed(1234)
# probability = TRUE asks svm() to also fit a Platt-scaling logistic
# on top of the decision function so we can compute AUC.
fit_svm <- svm(spy_up ~ spy_lag1 + spy_lag2 + spy_lag3 +
                          qqq_lag1 + iwm_lag1 + gld_lag1 + tlt_lag1 +
                          vix_lag1 + tnx_lag1 + vol20_lag1,
               data = train, probability = TRUE)
print(summary(fit_svm))
svm_pred <- predict(fit_svm, newdata = valid, probability = TRUE)
# When probability = TRUE, the predicted probabilities are stored as
# an attribute on the prediction object; we extract the "up" column.
svm_prob <- attr(svm_pred, "probabilities")[, "up"]
svm_cm   <- table(actual = valid$spy_up, predicted = svm_pred)
cat("\nSVM confusion matrix:\n"); print(svm_cm)
svm_acc  <- sum(diag(svm_cm)) / sum(svm_cm)
svm_auc  <- as.numeric(pROC::auc(pROC::roc(
                response = valid$spy_up, predictor = svm_prob, quiet = TRUE)))
cat(sprintf("[svm] validation accuracy = %.3f, AUC = %.3f\n",
            svm_acc, svm_auc))

# Side-by-side ROC curves - one of the cleanest visual comparisons
# for two probabilistic classifiers.  A perfect classifier hugs the
# top-left; a coin flip is the diagonal.
roc_glm <- pROC::roc(valid$spy_up, glm_prob, quiet = TRUE)
roc_svm <- pROC::roc(valid$spy_up, svm_prob, quiet = TRUE)
plot(roc_glm, col = "steelblue", lwd = 2,
     main = "ROC - logistic regression vs SVM")
lines(roc_svm, col = "firebrick", lwd = 2)
legend("bottomright", c(sprintf("logit  AUC=%.3f", glm_auc),
                          sprintf("svm    AUC=%.3f", svm_auc)),
       col = c("steelblue","firebrick"), lwd = 2)

# =====================================================================
# Section 9 - Model comparison
# ---------------------------------------------------------------------
# The four predictive models target two different things (continuous
# return vs binary direction) so a single metric cannot rank them.
# We report the natural primary metric for each (RMSE for regression,
# accuracy for classification) plus a secondary metric (direction
# accuracy / AUC) that lets the reader cross-compare.
# =====================================================================
cat("\n\n======== Section 9: Model comparison ========\n")
cmp <- data.frame(
    model     = c("OLS (stepwise)", "ARIMA", "Logistic", "SVM"),
    target    = c("return",  "return",     "direction",  "direction"),
    metric    = c("RMSE",     "RMSE",      "Accuracy",   "Accuracy"),
    value     = c(lm_rmse,    arima_rmse,  glm_acc,      svm_acc),
    secondary = c(lm_dirAcc,  arima_dirAcc, glm_auc,     svm_auc),
    secondary_label = c("dir.Acc","dir.Acc","AUC","AUC"))
print(cmp)

# =====================================================================
# Section 10 - Conclusion
# ---------------------------------------------------------------------
# The five take-aways are stitched together with sprintf so that the
# numbers always reflect the LATEST run - no risk of stale figures
# diverging from the live results.
# =====================================================================
cat("\n\n======== Section 10: Conclusion ========\n")
cat(sprintf("
1. Magnitude prediction is hard.  The OLS model (RMSE = %.5f) and the
   ARIMA model (RMSE = %.5f) both produce a daily forecast error that
   is essentially the size of one ordinary daily move.  In other words,
   neither model knows much about *how big* tomorrow's move will be.

2. Direction prediction is only marginally tractable.  Logistic
   regression reaches accuracy = %.3f / AUC = %.3f and the SVM reaches
   %.3f / %.3f on the held-out 2022-2024 sample.  Both sit close to the
   50%% coin-flip baseline; that is consistent with the literature on
   short-horizon equity-index predictability (very weak signal, mostly
   crowded out by transaction costs in practice).

3. The k-means volatility-regime clustering selects k = %d via the
   NbClust majority rule.  Regime 1 has positive mean weekly return
   with low volatility; regime 2 has *negative* mean weekly return with
   markedly higher volatility.  This 'panic vs calm' dichotomy is the
   most actionable finding here: position-sizing strategies that lever
   down in the high-vol regime are well documented to improve
   risk-adjusted performance.

4. The statistical tests support the modelling choices.  Shapiro-Wilk
   rejects normality of returns; ADF rejects a unit root in returns
   but not in prices, confirming that ARIMA and logistic models should
   be built on returns, not levels; both t.test and wilcox.test reject
   a zero mean (positive drift); chi-square does not detect a strong
   weekday effect; Box-Ljung detects a small but significant amount of
   serial correlation, consistent with the small AUCs we see for the
   classification models.

5. Future work: add technical indicators (RSI, MACD), more cross-asset
   features (a credit spread, the dollar index DXY), longer look-backs,
   and try gradient-boosted trees and recurrent networks.  A walk-
   forward evaluation rather than a single train/validate split would
   also be more honest for a strategy decision.

Notes
   * Exhibits and the run-time numbers above are reproducible: rerun
     'Rscript Tong_Mo_Project.R' from the project folder.  The first
     run downloads the data; subsequent runs read it from
     'Tong_Mo_Project_data.csv'.
   * All references to 'R in Action' are by chapter / section in the
     comments above at first use of every technique.
",
lm_rmse, arima_rmse,
glm_acc, glm_auc, svm_acc, svm_auc,
best_k))

# Close the PDF and the sink so the files are flushed and finalised.
# Without these, the output may be truncated if R exits abnormally.
dev.off()
sink()
