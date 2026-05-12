# FRE 6871 Final Project — Presentation Script

**Speaker**: Tong Mo
**Target length**: ~ 9 minutes 30 seconds at a normal speaking pace (≈ 145 WPM)
**Setup**: Open `Tong_Mo_Project.html` in the browser, full screen, table of contents on the left. Scroll through the report as you talk — each section heading below tells you which part to be showing.

> Stage notes are in [brackets]. Words to emphasise are in *italics*. A vertical pipe `|` marks a natural breath / pause point.

---

## 0 · Opening (≈ 20 s)

[Show the title card / first heading of the HTML report.]

> Hi, my name is **Tong Mo**, and this is my FRE 6871 final project — a comprehensive R analysis of next-day **SPY** returns. | In the next ten minutes I'll walk you through two research questions, the data and feature pipeline, five statistical tests, six models, and the bottom-line takeaway about what's actually predictable and what isn't.

---

## 1 · Research Questions (≈ 30 s)

[Scroll to **Section 1 — Introduction & research question**.]

> ETFs are the most liquid expression of broad-market views, so I built the entire analysis around **SPY**, the S&P 500 ETF. | I asked two related questions.
>
> **Question one** — *magnitude*: can we forecast the **size** of next-day log returns using a small set of features built from SPY itself, four cross-asset ETFs — QQQ, IWM, GLD, TLT — and two macro indicators, the VIX and the ten-year Treasury yield?
>
> **Question two** — *direction*: can we beat a fifty-fifty coin-flip on next-day **direction** using logistic regression and a support vector machine, and do either of them outperform a pure ARIMA forecast?

---

## 2 · Data Acquisition (≈ 45 s)

[Scroll to **Section 2 — Data acquisition** and show the `getSymbols` chunk.]

> All seven series come from Yahoo Finance through `quantmod::getSymbols`. The sample runs from **January 2010 through December 2024** — about **3 900 trading days**, which is plenty of history for ARIMA and for an eighty-twenty train-validation split.
>
> The script caches everything to `Tong_Mo_Project_data.csv` after the first run, so the analysis is fully *reproducible offline*. That's important — when the grader downloads the project they don't need an internet connection.
>
> One last note here: I split the sample **chronologically** — the last twenty percent becomes the validation set. You can never random-shuffle a time series, because that would let the model see the future when it predicts the past.

---

## 3 · Cleaning & Missing Values (≈ 30 s)

[Scroll to **Section 4 — Cleaning & missing values**.]

> The VIX and the ten-year yield have about a hundred and forty non-trading-day NAs over fifteen years. | I handle them in two steps: `na.locf` carries the last observation forward — that's the standard convention in financial time-series — and `complete.cases` removes anything still incomplete. The audit log prints zero rows lost in the second step, which I show in the output.
>
> *R in Action* covers this in section 4.5 — the principle being that you always log how missingness is treated, never silently drop it.

---

## 4 · Descriptive Statistics (≈ 45 s)

[Scroll to **Section 6 — Descriptive statistics**, point at the corrgram and the histogram.]

> Three exhibits set up the story. | First, `psych::describe` shows that every ETF has **negative skew and high kurtosis** — that's the textbook "fat-tailed financial return" signature. | Second, the histogram of SPY log returns with the kernel density overlay makes that fat tail visually obvious. | Third, the correlogram makes it clear that SPY, QQQ and IWM all move together, while gold and long bonds — GLD and TLT — are essentially uncorrelated with stocks. That justifies including them as features: they bring genuinely *different* information.

---

## 5 · Statistical Tests (≈ 75 s)

[Scroll to **Section 7 — Statistical tests**.]

> The rubric only asks for two formal tests. I run **five**, because each one directly informs a downstream modelling decision.
>
> One — **Shapiro-Wilk** rejects normality of returns. P-value essentially zero. That tells me the OLS standard errors will be unreliable, so the Sharpe ratio later has to be inferred via *bootstrap*, not a parametric formula.
>
> Two — **Augmented Dickey-Fuller** on prices: cannot reject the unit root, prices are non-stationary. ADF on returns: **strongly rejects**. That's why ARIMA is fit on returns, not levels — fitting on levels would violate the model's stationarity assumption.
>
> Three — **t-test and Wilcoxon** both reject zero mean — there is a small but statistically significant *positive drift* in SPY. The model has to keep an intercept.
>
> Four — **Chi-square** of weekday against direction. P-value above point-zero-five. There is no meaningful day-of-week effect, so I do not waste a feature on weekday dummies.
>
> And five — **Box-Ljung** on returns finds a small but significant autocorrelation. That's the *only* reason any predictive model has a chance at all on this data — it tells us there is a tiny serial signal to extract.

---

## 6 · Modelling — Six Methods (≈ 4 min)

### 6.1 OLS with stepAIC (≈ 40 s)

[Show the `lm` summary and the four diagnostic plots.]

> The first model is **multiple linear regression** with bidirectional `stepAIC` selection — *R in Action* chapter eight. AIC trades fit against complexity, and stepAIC keeps the formula honest. | The diagnostic plots and `ncvTest` confirm the residuals look reasonable. | But the validation RMSE — about one-point-one percent — is essentially the *size of one ordinary daily move*. The model knows almost nothing about *how big* tomorrow's move will be. | Direction accuracy from the regression sits at forty-nine point five percent, which is below coin-flip.

### 6.2 Bootstrap on the Sharpe ratio (≈ 30 s)

[Show the boot output and the BCa interval.]

> Because returns are non-normal, the Sharpe ratio has no nice analytical standard error. **Bootstrap** — *R in Action* chapter twelve — solves that. I resample with replacement one thousand times, and the BCa interval gives a ninety-five-percent confidence band on the long-run Sharpe of SPY. | This is the right way to do inference whenever your data violates parametric assumptions.

### 6.3 Logistic Regression — the new technique (≈ 50 s)

[Show the `glm` summary and the confusion matrix. This is the centrepiece of the *new learning* requirement.]

> This is the **only technique not seen in any of HW1 through HW6** — *R in Action* section thirteen-point-two. | Logistic regression assumes the binary direction label comes from a Bernoulli distribution, with the logit link mapping the linear combination of features to a probability between zero and one. The coefficients are estimated by maximum likelihood. |
>
> Why not just run OLS on a zero-one target? Three reasons: OLS predictions can fall outside zero to one and so are *not valid probabilities*; the residuals are heteroscedastic; and the underlying data-generating process really is Bernoulli, so logistic is the *natural* model. |
>
> On the validation window I get **fifty-one point three percent accuracy** and an **AUC of essentially zero point five**. So even with a richer link function the linear model barely beats a coin.

### 6.4 ARIMA (≈ 30 s)

[Show the `auto.arima` output and the forecast plot.]

> ARIMA — chapter fifteen — is the strongest pure time-series baseline. `auto.arima` selects the (p, d, q) triple that minimises AICc and validates it with a residual white-noise test. | Validation RMSE one-point-zero-eight percent, direction accuracy fifty-one-point-two. **Almost identical to the feature-rich OLS model**. That's a sobering finding — *the cross-asset and macro features I painstakingly engineered add nothing measurable beyond the autocorrelation that ARIMA already captures*.

### 6.5 K-means Volatility Regimes (≈ 50 s)

[Show the regime scatterplot — this is the most visually striking exhibit.]

> Now the most actionable part of the project. | I aggregate daily returns to weekly mean and weekly standard deviation, scale them, and run `NbClust` to pick the number of clusters by majority rule across about thirty internal validation indices — chapter sixteen. | Majority vote: **k equals two**. |
>
> Cluster one — six hundred twenty-nine weeks — has a *positive* weekly mean of about eighteen basis points and low volatility. Cluster two — one hundred fifty-three weeks — has a *negative* weekly mean of about minus forty-seven basis points and almost three times the volatility. | This is a clean **calm-bull versus panic-drawdown** dichotomy. | Position-sizing strategies that *de-leverage in the high-vol regime* are well documented in the literature to improve risk-adjusted returns — *that's the actionable insight* I take away from this whole project.

### 6.6 SVM (≈ 25 s)

[Show the SVM confusion matrix and the joint ROC curve.]

> Finally a radial-basis SVM as a non-linear sanity check on logistic — section seventeen-point-five. | Validation accuracy fifty-point-nine, AUC zero-point-five-one-three. **Indistinguishable from the linear logistic model**. That tells me the very weak signal in this data does not have additional non-linear structure that an RBF kernel can exploit.

---

## 7 · Model Comparison & Conclusion (≈ 90 s)

[Scroll to **Section 8 — Model comparison** and the conclusion paragraphs.]

> Putting all four predictive models on one table makes the story crisp. | OLS and ARIMA both produce daily forecast errors of *roughly one ordinary daily move* — magnitude prediction is genuinely hard. Logistic and SVM hover around fifty-one percent direction accuracy and AUCs essentially at the coin-flip baseline.
>
> What did I actually learn? | **Five takeaways**.
>
> One — magnitude prediction at the daily horizon is, for all practical purposes, impossible from these features.
>
> Two — direction prediction is *only marginally* tractable. The signal exists — Box-Ljung confirmed it — but it's small enough that real-world transaction costs would eat through it.
>
> Three — the volatility regime clustering is the most actionable result. The two-regime structure is real, persistent, and economically interpretable.
>
> Four — the statistical tests *all support* the modelling choices: non-normal returns push us to bootstrap, non-stationary prices push us to model returns, positive drift means an intercept is required, no weekday effect means I don't waste a feature.
>
> Five — for future work I would add technical indicators like RSI and MACD, a credit-spread feature, longer look-backs, gradient-boosted trees, and a walk-forward evaluation rather than a single split.

---

## 8 · Wrap-up (≈ 15 s)

[Return to the top of the HTML or close the report.]

> The deliverables — the dot-R script, the data CSV, the dot-R-m-d source, this rendered HTML, the plots PDF and a Chinese walkthrough — all live in the `final_project` folder under the `Tong_Mo_Project` prefix. | Throughout the analysis I cited *R in Action* twenty-five times across chapters two, four, six, seven, eight, eleven, twelve, thirteen, fifteen, sixteen and seventeen — the book's full statistical-modelling spine. | Thanks for watching.

---

## Speaker Tips

- **Pacing.** A run-through at full speed should land between nine and ten minutes. If you're running long, the easiest cuts are the SVM section (the result echoes logistic) and the second half of statistical tests — keep Shapiro-Wilk and ADF, drop the chi-square if needed.
- **Slides vs HTML.** Showing the HTML report directly is *better* than building separate slides — it shows the grader your `.Rmd` actually knit cleanly, and the table of contents on the left works as your slide rail.
- **Don't read the script verbatim.** Use it as a memory cue. Speak to the *exhibits on screen* — point at the corrgram, the regime scatter, the ROC plot. That keeps it conversational.
- **Hardest moment.** When you say "the cross-asset features I engineered add nothing measurable beyond ARIMA" — don't apologise for it. That's a *finding*, not a failure. Negative results well-explained are exactly what differentiates a strong analyst.
- **Recording filename.** Save the export as `Tong_Mo_Project_recording.mp4` (or `.mov`) to keep the firstName_lastName_Project naming convention.
