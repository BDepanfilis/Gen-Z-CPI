# Methodology & Data (Gen‑Z CPI)

This document summarizes how the two Gen‑Z CPI series are built from item‑level prices and Gen‑Z expenditure weights, and how they are compared to BLS CPI‑U. It is written for reviewers who want to understand **what** we did and **how to reproduce it** quickly.

---

## Indexes produced

- **GenZ‑CPI (Fixed)** — Fixed‑weight **Laspeyres** index using **2020 weights** for all years; level is normalized so **2020 = 1.00**.
- **GenZ‑CPI (Chained)** — **Annually reweighted** Laspeyres: for each year *t*, aggregate item‑level **price relatives** \(p_{i,t}/p_{i,t-1}\) with **year *t−1* weights**, then **chain** those yearly steps forward from 2020. Level is normalized so **2020 = 1.00**.

Both series are designed to be transparent and reproducible from CSV inputs via SQL in BigQuery.

---

## Data sources (inputs)

- **Item prices & weights** — `data/external/item_prices_weights.csv`  
  Columns (wide format):  
  `item, category, price_2020..price_2025, weight_2020..weight_2025`  
  - *Price*: nominal USD for each item and year.  
  - *Weight*: Gen‑Z expenditure share for the item in the given year.  
  - Weights are normalized in SQL to **sum to 1** in the base year (and per‑year for the chained method).
- **BLS CPI‑U (all items, U.S.)** — `data/external/bls_cpiu_yearly.csv`  
  Columns: `year, cpiu_index, yoy`. We also normalize BLS CPI‑U to **2020 = 1.00** to compare levels.

> Note: if prices arrive with currency symbols or thousands separators, they should be stripped before loading (the `bq load` schema expects numeric `FLOAT64`).

---

## Construction (SQL)

All logic is in `/sql` and executed by `scripts/bq_run.sh`.

### 1) Fixed‑weight Laspeyres (2020 base)
File: `sql/10_cpi_fixed.sql`

\[
L_t \,=\, \sum_i w_{i,2020}\,\cdot\,\frac{p_{i,t}}{p_{i,2020}}\quad\text{and}\quad
\text{Index}_t \,=\, L_t\;\text{scaled so}\;\text{Index}_{2020}=1.00
\]

Implementation highlights:
- Unpivot the wide `price_YYYY` columns to `(item, year, price)`.
- Compute base prices \(p_{i,2020}\) and normalize 2020 weights to sum to 1.
- Aggregate the relatives \(p_{i,t}/p_{i,2020}\) with base weights.

### 2) Annually reweighted, chained Laspeyres
File: `sql/11_cpi_annual_chain.sql`

For each year \(t \ge 2021\):
\[
\text{step}_t \,=\, \sum_i w_{i,t-1}\,\cdot\, \frac{p_{i,t}}{p_{i,t-1}}\,.
\]
Chain steps from 2020 forward using log‑sum to avoid nested analytic functions:
\[
\text{Index}_t \,=\, \exp\!\left(\sum_{k=2021}^t \ln(\text{step}_k)\right),\quad \text{Index}_{2020}=1.00.
\]

### 3) Validation vs BLS
File: `sql/20_validate.sql` joins the two Gen‑Z series to BLS CPI‑U and produces:
- `index_fixed`, `index_chain`, `cpiu_index`
- differences vs BLS at the level and (via the site) YoY comparisons

---

## Cleaning & quality checks

- **Weights**: normalized to sum to 1 (base year for fixed series; per year for chained).  
- **Missing prices**: items with missing prices in year *t* are dropped from that year’s aggregation.  
- **Types**: prices are numeric (`FLOAT64`); weights are numeric and non‑negative.  
- **Normalization**: all series rescaled so **2020 = 1.00** for level comparisons.  
- **Sanity**: 2020 levels equal 1.00 across all three series; YoY values computed as \( \text{Index}_t/\text{Index}_{t-1} - 1 \).

---

## What we observe (With the current inputs)

- Gen‑Z series track BLS CPI‑U closely (correlation \(\approx 0.99\)).  
- Differences of ~1–2 percentage points in level are expected given Gen‑Z basket tilt.  
- YoY tends to run modestly hotter in 2021 and slightly cooler in 2022–2024 relative to CPI‑U.

*(Your exact values will reflect the current `item_prices_weights.csv`.)*

---

## Reproducibility

1. **Authenticate & set project**  
   `gcloud auth login` → `gcloud config set project <PROJECT_ID>`

2. **Run the script**  
   ```bash
   export PROJECT_ID=<PROJECT_ID>
   export DATASET=genz_cpi
   export LOCATION=US
   bash scripts/bq_run.sh
   ```
---

## Limitations & next steps

- **Representativeness**: the Gen‑Z basket is a simplification; some categories (e.g., rent, tech) drive differences.  
- **Substitution bias**: the fixed series does not capture within‑year substitution; the chained series mitigates this partially.  
- **Update cadence**: weights are annual in this project; a monthly Törnqvist (C‑CPI style) could be added.  
- **Coverage**: prices are annual; monthly frequency would enable richer dynamics and A/B validation windows.

---

## Attribution & license

- BLS CPI‑U data © U.S. Bureau of Labor Statistics; used here for comparison.  
- Code & compiled outputs © Bradley DePanfilis; MIT License.
