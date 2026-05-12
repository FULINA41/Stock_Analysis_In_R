# FRE 6871 Final Project — Tong Mo

> Predicting next-day SPY returns and direction with regression,
> bootstrap, GLM, time series, clustering and SVM.

---

## Directory Structure

```
final_project/
├── README.md                       This file: top-level navigation
├── Tong_Mo_Project.R               Main deliverable: tutorial-style R report (required)
├── Tong_Mo_Project.Rmd             Bonus: R Markdown source
├── Tong_Mo_Project.html            Bonus: knitted rendered report
├── Tong_Mo_Project_data.csv        Cached data, saved after first run
├── Tong_Mo_Project_output.txt      Full Rscript console output
├── Tong_Mo_Project_plots.pdf       All plots (13) collected into one PDF
├── Tong_Mo_Project_README_CN.md    Chinese project notes + technical walkthrough
└── docs/                           Course-provided reference materials (not submitted)
    ├── FRE 6871 - Final Project .pdf
    ├── FRE 6871 - Project Grading Guide.docx
    ├── FRE6871_Optional_Dynamic_Report_Walkthrough.docx
    ├── FRE6871 - Project Presentation Recording.pdf
    ├── Final Project - student questions.docx
    ├── Additional Data Sources.docx
    └── Data Sets.docx
```

---

## Submission Checklist (Submit to Google Drive)

> All files start with `Tong_Mo_Project_`. Before submitting, transfer
> ownership of every file on Drive to the instructor's email.

| # | File | Required / Bonus | Purpose |
|---|---|---|---|
| 1 | `Tong_Mo_Project.R`               | Required | Main report (the script itself is the tutorial) |
| 2 | `Tong_Mo_Project_data.csv`        | Required | Data file |
| 3 | Google Doc (shared version of the `.R` content) | Required | For instructor annotations |
| 4 | `Tong_Mo_Project_recording.mp4`   | Required | Presentation recording (self-recorded, ≤ 10 min) |
| 5 | `Tong_Mo_Project.Rmd`             | Bonus    | R Markdown source |
| 6 | `Tong_Mo_Project.html`            | Bonus    | Rendered report |
| 7 | `Tong_Mo_Project_output.txt`      | Optional | Archived console output |
| 8 | `Tong_Mo_Project_plots.pdf`       | Optional | Archived plot collection |
| 9 | `Tong_Mo_Project_README_CN.md`    | Optional | Chinese walkthrough |

---

## How to Run

```bash
cd /Users/tonymo/Desktop/R_in_Finance/final_project

# Main script (~30 seconds)
Rscript Tong_Mo_Project.R

# Render HTML report (~30 seconds)
R -e 'rmarkdown::render("Tong_Mo_Project.Rmd")'
```

The first run uses `quantmod` to download Yahoo Finance data over the
network and writes it to `Tong_Mo_Project_data.csv`. Subsequent runs
read directly from the CSV and no longer require an internet connection.

### Dependencies

```r
install.packages(c(
    "quantmod", "xts", "zoo", "PerformanceAnalytics", "psych",
    "car", "MASS", "boot", "forecast", "tseries", "NbClust",
    "flexclust", "e1071", "pROC", "corrgram", "rmarkdown"
))
```

---

## Core Content at a Glance

| Category | Count | Contents |
|---|---|---|
| Statistical tests | **5** | Shapiro-Wilk, ADF×2, t.test, Wilcox, Chi-Square, Box-Ljung |
| Modeling techniques | **6** | OLS+stepAIC, Bootstrap, Logistic (new), ARIMA, k-means, SVM |
| Textbook references | **25** | `R in Action` chapters 2 / 4 / 6 / 7 / 8 / 11 / 12 / 13 / 15 / 16 / 17 |
| Missing-value handling | ✓ | `na.locf` + `complete.cases` (audit log in the output) |

See [`Tong_Mo_Project_README_CN.md`](Tong_Mo_Project_README_CN.md) for the
detailed walkthrough of the methodology and formulas.

---

## Remaining Manual Steps

1. **5 points**: Post an *unclaimed* data source in the shared Google Doc *Data Sets*.
   - Recommended: **Stooq** (`quantmod::getSymbols(..., src = "stooq")`) — free, covers global indices, and rarely claimed.
2. Upload the contents of `Tong_Mo_Project.R` to the shared Google Doc and transfer Drive ownership.
3. Record a presentation video of ≤ 10 minutes and save it as `Tong_Mo_Project_recording.mp4`.

# Stock_Analysis_In_R
