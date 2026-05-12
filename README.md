# FRE 6871 Final Project — Tong Mo

> Predicting next-day SPY returns and direction with regression,
> bootstrap, GLM, time series, clustering and SVM.

---

## 目录结构

```
final_project/
├── README.md                       本文件:顶层导航
├── Tong_Mo_Project.R               主交付:tutorial 风格 R 报告 (必交)
├── Tong_Mo_Project.Rmd             加分:R Markdown 源
├── Tong_Mo_Project.html            加分:knit 出的渲染报告
├── Tong_Mo_Project_data.csv        缓存数据,首次运行后落盘
├── Tong_Mo_Project_output.txt      Rscript 控制台完整输出
├── Tong_Mo_Project_plots.pdf       全部图集中输出 (13 张)
├── Tong_Mo_Project_README_CN.md    中文项目说明 + 技术原理详解
└── docs/                           课程提供的参考材料 (不提交)
    ├── FRE 6871 - Final Project .pdf
    ├── FRE 6871 - Project Grading Guide.docx
    ├── FRE6871_Optional_Dynamic_Report_Walkthrough.docx
    ├── FRE6871 - Project Presentation Recording.pdf
    ├── Final Project - student questions.docx
    ├── Additional Data Sources.docx
    └── Data Sets.docx
```

---

## 提交清单 (Submit to Google Drive)

> 全部以 `Tong_Mo_Project_` 开头,提交前把 Drive 上的所有权 transfer 给老师邮箱。

| # | 文件 | 必交 / 加分 | 用途 |
|---|---|---|---|
| 1 | `Tong_Mo_Project.R`               | 必交 | 主报告(本身就是 tutorial)|
| 2 | `Tong_Mo_Project_data.csv`        | 必交 | 数据文件 |
| 3 | Google Doc(`.R` 内容的共享版)    | 必交 | 老师批注用 |
| 4 | `Tong_Mo_Project_recording.mp4`   | 必交 | Presentation 录像(自己录,≤ 10 min)|
| 5 | `Tong_Mo_Project.Rmd`             | 加分 | R Markdown 源 |
| 6 | `Tong_Mo_Project.html`            | 加分 | 渲染后的报告 |
| 7 | `Tong_Mo_Project_output.txt`      | 可选 | 控制台输出存档 |
| 8 | `Tong_Mo_Project_plots.pdf`       | 可选 | 图集存档 |
| 9 | `Tong_Mo_Project_README_CN.md`    | 可选 | 中文 walkthrough |

---

## 怎么跑

```bash
cd /Users/tonymo/Desktop/R_in_Finance/final_project

# 主脚本(~30 秒)
Rscript Tong_Mo_Project.R

# 渲染 HTML 报告(~30 秒)
R -e 'rmarkdown::render("Tong_Mo_Project.Rmd")'
```

第一次跑会用 `quantmod` 联网下载 Yahoo Finance 数据并落盘到
`Tong_Mo_Project_data.csv`;之后再跑就直接读 CSV,不再需要联网。

### 依赖包

```r
install.packages(c(
    "quantmod", "xts", "zoo", "PerformanceAnalytics", "psych",
    "car", "MASS", "boot", "forecast", "tseries", "NbClust",
    "flexclust", "e1071", "pROC", "corrgram", "rmarkdown"
))
```

---

## 核心内容速览

| 类别 | 数量 | 内容 |
|---|---|---|
| 统计检验  | **5** | Shapiro-Wilk、ADF×2、t.test、Wilcox、Chi-Square、Box-Ljung |
| 建模技术  | **6** | OLS+stepAIC、Bootstrap、Logistic(新)、ARIMA、k-means、SVM |
| 教材引用  | **25** | `R in Action` 第 2/4/6/7/8/11/12/13/15/16/17 章 |
| 缺失值处理 | ✓ | `na.locf` + `complete.cases` (审计日志见输出) |

详细原理与公式见 [`Tong_Mo_Project_README_CN.md`](Tong_Mo_Project_README_CN.md)。

---

## 还需要手动完成的事

1. **5 分**:在共享 Google Doc *Data Sets* 里贴一条**未被别人占过**的数据源
   - 推荐:**Stooq**(`quantmod::getSymbols(..., src = "stooq")`)— 免费、覆盖全球指数、几乎没人贴
2. 把 `Tong_Mo_Project.R` 内容上传 Google Doc 共享版,Drive 上转交所有权
3. 录制 ≤ 10 分钟的 presentation 视频,保存为 `Tong_Mo_Project_recording.mp4`
# Stock_Analysis_In_R
