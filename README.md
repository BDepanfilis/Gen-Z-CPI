# Gen‑Z CPI (2020–2025)

A reproducible price index tailored to **Gen‑Z** spending. We build two indices from item‑level prices and Gen‑Z weights and compare them to **BLS CPI‑U**:

- **GenZ‑CPI (Fixed)** — Laspeyres with **2020 weights** for all years (base = **1.00** in 2020)  
- **GenZ‑CPI (Chained)** — **annually reweighted** Laspeyres (use year *t‑1* weights for year *t*, then **chain**)

Outputs are versioned as CSVs, visualized on GitHub Pages, and in Power BI.

---

## Quick links

- **Interactive dashboard (Power BI)**: *(publish-to-web link)*  
[ https://app.powerbi.com/view?r=eyJrIjoiYWIyZGVmMjUtYzc3My00OTAzLTgzODQtZWMyMzFjZjYyMDEzIiwidCI6ImE4MjE2YzFlLTRkNjMtNDM1Mi04YzNiLTUwZmExZjE0NzViMSIsImMiOjZ9
](https://app.powerbi.com/view?r=eyJrIjoiMDU5OWFhNDAtYWI2OC00MDQ5LTk1ZDMtYzU5ZGYyNmI3ZmNmIiwidCI6ImE4MjE2YzFlLTRkNjMtNDM1Mi04YzNiLTUwZmExZjE0NzViMSIsImMiOjZ9)
- **Live charts (GitHub Pages):** `docs/index.html` → served at `https://BDepanfilis.github.io/Gen-Z-CPI/`  
- **Data & methods:** [`docs/methodology.md`](docs/methodology.md) (Data Sourcing and Methodology)  
- **SQL:** [`sql/`](sql/) — source‑of‑truth queries  
- **Runner:** [`scripts/bq_run.sh`](scripts/bq_run.sh) — load CSVs → run SQL → export outputs  
- **Outputs (CSV):** [`outputs/`](outputs/) → also copied to `docs/data/` for the site

---

## Repo layout

```
/
├─ docs/
│  ├─ index.html              # live page (reads docs/data/*.csv)
│  └─ data/
│     ├─ genz_cpi_fixed.csv
│     ├─ genz_cpi_chain.csv
│     └─ validation_bls_compare.csv
├─ sql/
│  ├─ 10_cpi_fixed.sql        # fixed 2020-weight Laspeyres
│  ├─ 11_cpi_annual_chain.sql # annually reweighted, chained
│  └─ 20_validate.sql         # compare Gen‑Z indices to BLS CPI‑U
├─ scripts/
│  └─ bq_run.sh               # runner (no creds in repo)
├─ data/
│  └─ external/
│     ├─ item_prices_weights.csv  # items + prices + weights (Gen Z basket of goods)
│     └─ bls_cpiu_yearly.csv      # BLS CPI‑U, yearly (normalized to 2020 = 1.00)
├─ outputs/
│  ├─ genz_cpi_fixed.csv
│  ├─ genz_cpi_chain.csv
│  └─ validation_bls_compare.csv
└─ README.md
```

> Note: `outputs/*.csv` are committed for auditability. `docs/data/*.csv` are just copies for the site.

---

## How to reproduce (BigQuery + bq CLI)

Requirements: **gcloud** + **bq** CLI installed and authed (`gcloud auth login`).

```bash
# from the repo root
export PROJECT_ID=YOUR_GCP_PROJECT_ID
export DATASET=genz_cpi
export LOCATION=US

bash scripts/bq_run.sh
```

This will:
1) create the dataset if needed,  
2) load `data/external/*.csv` into BigQuery,  
3) run the SQL in `sql/`, and  
4) write the three output CSVs to `outputs/`.

---

## Methodology (one screen)

- **Normalization:** all series are scaled so **2020 = 1.00** for easy comparison.  
- **GenZ‑CPI (Fixed):** Laspeyres index using **2020 weights** for all years:  
  \( L_t = \sum_i w_{i,2020} \cdot \frac{p_{i,t}}{p_{i,2020}} \).  
- **GenZ‑CPI (Chained):** Use **year *t‑1* weights** to aggregate the **price relatives** \(p_{i,t}/p_{i,t-1}\) each year; then multiply (chain) the steps from 2020 forward.
- **Validation:** join the Gen‑Z indices to **BLS CPI‑U** levels; inspect level gaps and YoY differences.  
- **Data quality:** weights per year are normalized to sum to 1; prices are numeric (no currency symbols). Missing values are dropped for that item‑year.

Full details and sources: see [`docs/methodology.md`](docs/methodology.md).

---

## What to look for (results)

- Base year check: **2020 = 1.00** for Gen‑Z (fixed & chained) and BLS CPI‑U.  
- The Gen‑Z series track CPI‑U closely but can diverge where Gen‑Z category weights differ (e.g., rent/streaming/tech).  
- See `docs/index.html` for line chart (levels) and grouped bars (YoY).

---

## License

This project is licensed under the MIT License — see [`LICENSE`](LICENSE).

© Bradley DePanfilis
