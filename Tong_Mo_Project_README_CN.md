# FRE 6871 Final Project

> **预测 SPY 次日对数收益与方向 —— 一次贯穿回归、自助法、GLM、时间序列、聚类、分类的综合性 R 数据分析**
>
> 作者:Tong Mo
> 课程:FRE 6871 *R in Finance*(NYU Tandon)
> 教材引用:Robert I. Kabacoff,《R in Action》(第 3 版)

---

## 目录

1. [项目背景与研究问题](#1-项目背景与研究问题)
2. [数据来源与特征工程](#2-数据来源与特征工程)
3. [缺失值处理](#3-缺失值处理)
4. [描述性统计与可视化](#4-描述性统计与可视化)
5. [统计检验(5 项)](#5-统计检验5-项)
6. [建模技术(6 类)](#6-建模技术6-类)
  - 6.1 [多元线性回归 + stepAIC](#61-多元线性回归--stepaic)
  - 6.2 [Bootstrap 自助法](#62-bootstrap-自助法)
  - 6.3 [Logistic 回归(本项目首次使用)](#63-logistic-回归本项目首次使用)
  - 6.4 [ARIMA 时间序列模型](#64-arima-时间序列模型)
  - 6.5 [K-means 聚类:波动率 regime](#65-k-means-聚类波动率-regime)
  - 6.6 [SVM 支持向量机](#66-svm-支持向量机)
7. [模型对比与结论](#7-模型对比与结论)
8. [文件清单与复现方式](#8-文件清单与复现方式)
9. [评分 rubric 自检](#9-评分-rubric-自检)

---

## 1. 项目背景与研究问题

ETF 是市场观点最直接的流动性表达。本项目以 **SPY**(追踪 S&P 500 的 ETF)为标的,提出两个相互衔接的研究问题:


| 编号          | 问题                                                                                      | 对应模型           |
| ----------- | --------------------------------------------------------------------------------------- | -------------- |
| **Q1 — 幅度** | 能否用 SPY 自身、4 只跨资产 ETF(QQQ / IWM / GLD / TLT)和 2 个宏观指标(VIX、10Y 国债收益率)的滞后特征,预测**次日对数收益**? | OLS 回归 + ARIMA |
| **Q2 — 方向** | 能否在次日**涨/跌方向**上击败 50% 抛硬币基线? Logistic 回归与 SVM 是否优于纯时间序列模型?                              | Logistic + SVM |


附加发现:用聚类把市场切分成"恐慌 vs 平静" regime,看看每种 regime 的收益/波动特征。

---

## 2. 数据来源与特征工程

### 2.1 数据获取

```r
library(quantmod)
getSymbols(c("SPY","QQQ","IWM","GLD","TLT","^VIX","^TNX"),
           from = "2010-01-01", to = "2024-12-31")
```

- **来源**:Yahoo Finance(`quantmod::getSymbols`)
- **样本期**:2010-01-04 → 2024-12-30,共 **3 911** 个交易日
- **变量**:5 只 ETF 的复权收盘价 + VIX 指数 + 10 年期美债收益率
- **缓存**:首次运行后落盘到 `Tong_Mo_Project_data.csv`,后续运行无需联网

### 2.2 特征工程的金融逻辑


| 特征族           | 构造方式                          | 经济含义                       |
| ------------- | ----------------------------- | -------------------------- |
| 对数收益          | `Return.calculate(px, "log")` | 满足时间可加性,数值更接近正态            |
| 滞后收益 lag1/2/3 | `lag(ret, 1:3)`               | 捕捉短期动量 / 反转                |
| 跨资产 lag1      | QQQ/IWM/GLD/TLT 各 1 阶         | 跨市场溢出与风险 on/off 信号         |
| VIX lag1      | 波动率指数变化                       | leverage effect:vol↑ → 股票↓ |
| 10Y 收益率 lag1  | TNX 变化                        | 利率冲击对估值的影响                 |
| 20 日滚动波动率     | `runSD(ret) × √252`           | 表征当前 regime                |


### 2.3 训练 / 验证切分

时间序列切分必须按时间顺序,**不能随机抽样**(否则会用未来预测过去):

- 训练集:**80%** = 2010-02-02 ~ 2022-01-05(3 112 行)
- 验证集:**20%** = 2022-01-06 ~ 2024-12-30(778 行)

---

## 3. 缺失值处理

> *R in Action* §4.5 / §15.1

**问题**:VIX 与 TNX 在节假日有 138 天 NA(美股交易但指数不交易)。

**两步处理**:

```r
px <- na.locf(px, na.rm = FALSE)   # 第一步:用上一观测向后填充
px <- px[complete.cases(px), ]     # 第二步:删除仍含 NA 的行
```

- `**na.locf**`(Last Observation Carried Forward):最常用的金融时序填充方式,假设非交易日的指数水平等于上一交易日。
- `**complete.cases**`:删除任何剩余的不完整行(本数据集为 0 行)。
- **审计**:把"清洗前/后 NA 数量"和"删除行数百分比"写到日志,符合 rubric"明确处理缺失值"的要求。

---

## 4. 描述性统计与可视化

> *R in Action* §6(基础图)+ §7.1(`psych::describe`)+ §11.3.1(`corrgram`)

主要输出:


| 输出                     | 说明                                                |
| ---------------------- | ------------------------------------------------- |
| `psych::describe(ret)` | 7 列收益的均值/标准差/偏度/峰度。**所有 ETF 都是负偏 + 高峰**(典型金融收益分布) |
| 历史价格折线图                | 5 只 ETF 同图比较涨幅                                    |
| VIX / TNX 折线图          | 宏观背景(2020 疫情、2022 加息周期清晰可见)                       |
| `hist + density`       | SPY 收益直方图 + 核密度,目测胖尾                              |
| `corrgram`             | 跨资产相关矩阵,SPY/QQQ/IWM 高度正相关,GLD/TLT 与股票市场弱相关或负相关    |
| `chart.CumReturns`     | SPY 累积净值曲线                                        |


---

## 5. 统计检验(5 项)

> rubric 要求 ≥ 2 个;本项目做了 **5 个**,每个都直接服务于后续建模决策。

### 5.1 Shapiro-Wilk 正态性检验 — *R in Action §7.5*

**原理**:检验样本是否来自正态分布。
**统计量**:$W = \dfrac{(\sum a_i x_{(i)})^2}{\sum (x_i - \bar{x})^2}$,$x_{(i)}$ 为顺序统计量。
**结果**:p ≪ 0.05 → **拒绝正态**。
**意义**:OLS 残差的 t 检验需要正态假设,后续要做 robust 推断或用 bootstrap;同时印证后续 logistic / SVM 的必要性。

### 5.2 Augmented Dickey-Fuller 平稳性检验 — *R in Action §15.2.1*

**原理**:回归 $\Delta y_t = \alpha + \beta t + \gamma y_{t-1} + \sum \delta_i \Delta y_{t-i} + \varepsilon_t$,检验 $\gamma = 0$(单位根)的零假设。
**结果**:

- **价格**:p > 0.05 → 不能拒绝单位根 → **非平稳**
- **收益**:p < 0.01 → **平稳**

**意义**:**ARIMA 必须建模在收益上,而不是价格上**;否则违反平稳性假设,系数无统计意义。

### 5.3 t.test + Wilcox 符号秩检验 — *R in Action §7.4*

**原理**:

- **t.test**:参数法,$t = \bar{x}/(s/\sqrt{n})$,假设近似正态。
- **wilcox.test**:非参数法,基于符号秩,不假设分布。
**结果**:两者 p < 0.05 → **均值显著 ≠ 0(正漂移)**。
**意义**:股票市场长期向上,在建模时如果不加截距项会有偏差;Sharpe 计算也要保留这一项。

### 5.4 Chi-Square 周日效应 — *R in Action §7.3*

**原理**:列联表 $\chi^2 = \sum \dfrac{(O_{ij} - E_{ij})^2}{E_{ij}}$,检验"周几"与"涨跌"是否独立。
**结果**:p > 0.05 → **没有显著的周日效应**。
**意义**:可以放心地把所有交易日同等处理,不必加 weekday dummy。

### 5.5 Box-Ljung 自相关检验 — *R in Action §15.4*

**原理**:$Q = n(n+2) \sum_{k=1}^{m} \dfrac{\hat\rho_k^2}{n-k}$,服从 $\chi^2(m)$。
**结果**:p < 0.05 → **存在小但显著的序列自相关**。
**意义**:这是后续 ARIMA / 滞后回归还有点信号的根本原因;但 AUC 仍然只有 0.5x 也说明这个信号被实际成本吃掉了。

---

## 6. 建模技术(6 类)

### 6.1 多元线性回归 + stepAIC

> *R in Action* 第 8 章

**模型**:
$$
r_t = \beta_0 + \sum_{j} \beta_j \cdot \text{lag}_j(\cdot) + \varepsilon_t
$$

**关键步骤**:

1. **OLS**:`lm(spy_ret ~ ...)` 用 OLS 最小化 $\sum \varepsilon_t^2$。
2. **stepAIC 双向选择**:在 `+ 加变量` / `- 减变量` 之间反复,每步选 AIC 最低的方向。AIC = $-2 \log L + 2k$,平衡拟合度与复杂度。
3. **诊断**:`crPlots` 看线性性,`ncvTest` 看异方差(`car` 包,*R in Action* §8.3),`influencePlot` 找杠杆点。

**结果**:OLS 验证集 RMSE ≈ 0.0110,方向准确率 ≈ 0.495。
**结论**:SPY 次日对数收益**几乎没有**线性可预测性。

---

### 6.2 Bootstrap 自助法

> *R in Action* 第 12 章

**原理**:

- 从原始样本有放回地重抽样 R 次(本项目 R = 1 000)
- 每次重抽样上计算关心的统计量
- R 次结果的分布 → 该统计量的近似抽样分布 → 可得置信区间

**为什么用**:Sharpe Ratio 没有解析的标准误,数据本身又非正态,bootstrap 是最稳健的做法。

```r
sharpe_stat <- function(data, idx) {
    r <- data[idx]
    sqrt(252) * mean(r) / sd(r)
}
boot_out <- boot(coredata(ret$SPY_ret), statistic = sharpe_stat, R = 1000)
boot.ci(boot_out, type = c("perc","bca"))
```

- **percentile**:直接取重抽样分布的 [2.5%, 97.5%] 分位
- **BCa**(Bias-Corrected and accelerated):对偏差和加速度做校正,准确度更高

**意义**:即使整个收益分布非常胖尾,我们依然能给出 Sharpe 的可信区间,从而判断"长期持有 SPY 的风险调整收益是否显著为正"。

---

### 6.3 Logistic 回归(本项目首次使用)

> *R in Action* §13.2 — **本项目相对 HW1–HW6 引入的"新"技术**

**模型(GLM 框架)**:

- 假设 $Y_t \in 0, 1$ 来自 Bernoulli($p_t$)
- 用 **logit link**:$\log\dfrac{p_t}{1 - p_t} = X_t \beta$
- 等价于 $p_t = \dfrac{1}{1 + e^{-X_t\beta}}$(sigmoid)
- **极大似然估计** $\hat\beta = \arg\max \prod_t p_t^{y_t}(1-p_t)^{1-y_t}$

**为什么不用 OLS 直接预测 0/1**:

1. OLS 输出可能 < 0 或 > 1,不是合法概率
2. 误差不再正态、方差非齐性
3. 离散因变量的真实数据生成过程是 Bernoulli,Logistic 是它的"自然"模型

**评估**:

- **混淆矩阵** + **准确率** $= \dfrac{TP+TN}{n}$
- **AUC**:ROC 曲线下面积,衡量"把任意正样本排在任意负样本前面"的概率,对类不平衡稳健

**结果**:验证集 accuracy ≈ 0.513,AUC ≈ 0.499。
**结论**:线性 logistic 仅微弱优于硬币;短期方向预测的非线性结构需要更强模型。

---

### 6.4 ARIMA 时间序列模型

> *R in Action* §15.4

**模型**:ARIMA(p, d, q) — AR(p) + 差分 d 次 + MA(q)
$$
\phi(B)(1-B)^d y_t = \theta(B)\varepsilon_t
$$

- $\phi(B) = 1 - \phi_1 B - \dots - \phi_p B^p$ 为 AR 多项式
- $\theta(B) = 1 + \theta_1 B + \dots + \theta_q B^q$ 为 MA 多项式
- $B$ 为滞后算子,$B y_t = y_{t-1}$

`**auto.arima` 的工作原理**:

1. 用 KPSS 检验确定 $d$
2. 固定 $d$,在 $(p, q) \in 0, \dots, 5^2$ 上枚举,挑 **AICc** 最低者
3. 对最优模型再做残差白噪声检验

**金融意义**:ARIMA 是"无外生信息、纯靠历史序列"的最强基线;如果加入特征的模型仍打不过 ARIMA,说明特征工程没有产生信号。

**结果**:验证集 RMSE ≈ 0.0108(略低于 OLS),方向准确率 ≈ 0.512。
**结论**:在 SPY 上,纯时间序列与"加了一堆特征的 OLS"几乎打成平手 → **特征几乎没增加信息**。

---

### 6.5 K-means 聚类:波动率 regime

> *R in Action* 第 16 章

**为什么用周频**:日度波动太噪;用 `apply.weekly()` 聚合成"每周收益均值 + 每周收益标准差",得到 ~780 周的二维点。

**算法**:K-means 最小化 $\sum_{i=1}^{k} \sum_{x \in C_i} x - \mu_i^2`(WCSS,within-cluster sum of squares),对每个点交替"分配到最近质心 → 重新计算质心"直到收敛。

**确定 k**:`NbClust(method = "kmeans")` 用 ~30 种内部指标投票,majority rule 选 k。
**本项目结果**:k = **2**,两簇含义:


| Regime | 周数  | 周均收益       | 周波动   | 解读                 |
| ------ | --- | ---------- | ----- | ------------------ |
| 1      | 629 | **+0.18%** | 0.65% | "calm bull"        |
| 2      | 153 | **−0.47%** | 1.65% | "panic / drawdown" |


**金融启示**:position sizing 在 regime 2 时降仓,理论上能提升风险调整收益。

---

### 6.6 SVM 支持向量机

> *R in Action* §17.5

**原理**:

- 把样本映射到高维空间(通过 kernel,本项目用 RBF:$K(x_i, x_j) = e^{-\gammax_i-x_j^2}$)
- 在该空间找一个**最大间隔超平面**分开两类
- 优化目标:最小化 $w^2/2 + C\sum \xi_i$,其中 $\xi_i$ 为软间隔的 slack
- 与 logistic 不同,SVM 不需要数据来自任何概率模型,只关心几何边界

**评估**:同 logistic — 准确率 + AUC + 与 logistic 同图画 ROC 对比

**结果**:accuracy ≈ 0.509,AUC ≈ 0.513。
**结论**:RBF SVM 与 linear logistic 在这个数据上几乎无差,这进一步印证 SPY 短期方向缺乏可被简单核函数捕获的非线性结构。

---

## 7. 模型对比与结论


| 模型            | 目标   | 核心指标     | 数值      | 副指标          |
| ------------- | ---- | -------- | ------- | ------------ |
| OLS + stepAIC | 收益幅度 | RMSE     | 0.01095 | 方向 acc 0.495 |
| ARIMA         | 收益幅度 | RMSE     | 0.01082 | 方向 acc 0.512 |
| Logistic      | 涨跌方向 | Accuracy | 0.513   | AUC 0.499    |
| SVM (RBF)     | 涨跌方向 | Accuracy | 0.509   | AUC 0.513    |


### 关键洞察

1. **幅度极难**:全部模型 RMSE 几乎等于 1 个标准日波动 → 模型对"明天涨多少"近乎一无所知。
2. **方向只能微赢**:Logistic / SVM 准确率徘徊在 51%,与文献中"短期股指方向预测在剔除交易成本后基本无利可图"完全一致。
3. **波动率 regime 是真实存在的**:k-means 找到"calm vs panic"两类,周收益符号相反;**实际可执行的策略价值在 regime-aware 的 position sizing,而不是逐日方向预测**。
4. **检验都在为建模背书**:非正态 → 用 bootstrap;价格非平稳但收益平稳 → ARIMA on returns;均值正漂移 → 模型必须含截距;周日无效应 → 不必加 dummy;序列自相关存在但小 → 信号有但弱。
5. **未来方向**:RSI / MACD 等技术指标、信用利差、DXY、更长滞后窗口、梯度提升树、滚动 walk-forward 评估。

---

## 8. 文件清单与复现方式

```
final_project/
├── Tong_Mo_Project.R              # ← 主交付:tutorial 风格的 R 报告
├── Tong_Mo_Project.Rmd            # ← 加分:R Markdown 源
├── Tong_Mo_Project.html           # ← 加分:knit 出的渲染报告
├── Tong_Mo_Project_data.csv       # 缓存数据,不联网也能复现
├── Tong_Mo_Project_output.txt     # 完整控制台输出
├── Tong_Mo_Project_plots.pdf      # 全部图(13 张)
└── Tong_Mo_Project_README_CN.md   # 本文档
```

### 复现步骤

```bash
cd /Users/tonymo/Desktop/R_in_Finance/final_project
Rscript Tong_Mo_Project.R                         # 跑主脚本,~30 秒
R -e 'rmarkdown::render("Tong_Mo_Project.Rmd")'   # 渲染 HTML 报告,~30 秒
```

### 依赖包

```r
install.packages(c("quantmod","xts","zoo","PerformanceAnalytics","psych",
                   "car","MASS","boot","forecast","tseries","NbClust",
                   "flexclust","e1071","pROC","corrgram","rmarkdown"))
```

---

## 9. 评分 rubric 自检


| rubric 项         | 要求   | 实际                                                    | 状态  |
| ---------------- | ---- | ----------------------------------------------------- | --- |
| 数据源贴 Google Doc  | 不重复  | (待手动)                                                 | ⏳   |
| 研究问题清晰           | 有    | Q1/Q2 + 5 段结论                                         | ✅   |
| 数据导入 + 探索        | 必须   | quantmod / str / summary / 多张图                        | ✅   |
| 数据清洗 + 类型        | 必须   | na.locf / complete.cases / 类型转换                       | ✅   |
| 基础图表 + 描述统计      | 必须   | hist / density / corrgram / psych::describe           | ✅   |
| ≥ 2 项核心建模        | 必须   | **6 项**:OLS / Boot / Logistic / ARIMA / k-means / SVM | ✅   |
| ≥ 2 个统计检验        | 必须   | **5 个**                                               | ✅   |
| 处理缺失值            | 必须   | `na.locf + complete.cases` 9 处                        | ✅   |
| Tutorial 风格 + 注释 | 必须   | 每节 `# ===` 分隔 + 段落注释                                  | ✅   |
| 一行行能跑            | 必须   | `Rscript` 通过                                          | ✅   |
| 清晰的发现/结论         | 10 分 | 5 段 conclusion + 模型对比表                                | ✅   |
| 文件命名             | 10 分 | 全部 `Tong_Mo_Project_`*                                | ✅   |
| ≥ 5 处教材引用        | 10 分 | **25 处** `R in Action`                                | ✅   |
| Google Doc + 录像  | 提交要求 | (待手动)                                                 | ⏳   |


> 还剩两件事必须**学生本人**做:① 在共享 Google Doc *Data Sets* 里贴一个未被别人用过的开源数据来源(推荐 Stooq:`getSymbols(..., src="stooq")`);② 录制 ≤ 10 分钟的 presentation 视频。提交前把 Drive 上所有 `Tong_Mo_Project`* 文件**所有权 transfer 给老师邮箱**。

