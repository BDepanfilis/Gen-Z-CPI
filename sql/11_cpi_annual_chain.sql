-- sql/11_cpi_annual_chain.sql  (FIXED)
-- Annually reweighted Laspeyres with chaining.
-- Uses year t-1 weights for year t relatives, then multiplies (chains) the steps.
-- Base index = 1.0 at 2020.

WITH prices AS (
  SELECT item, 2020 AS year, price_2020 AS price FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2021, price_2021 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2022, price_2022 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2023, price_2023 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2024, price_2024 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2025, price_2025 FROM `__PROJECT_ID__.__DATASET__.items_raw`
),
weights AS (
  SELECT item, 2020 AS year, weight_2020 AS w FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2021, weight_2021 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2022, weight_2022 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2023, weight_2023 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2024, weight_2024 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, 2025, weight_2025 FROM `__PROJECT_ID__.__DATASET__.items_raw`
),
weights_norm AS (
  SELECT item, year, SAFE_DIVIDE(w, SUM(w) OVER (PARTITION BY year)) AS w_norm
  FROM weights
),
rel AS (
  -- Item-level relatives: p_t / p_{t-1}
  SELECT item, year,
         price / LAG(price) OVER (PARTITION BY item ORDER BY year) AS rel
  FROM prices
),
step AS (
  -- Step Laspeyres for each year t uses weights from t-1
  SELECT 2020 AS year, 1.0 AS step_lasp
  UNION ALL
  SELECT r.year, SUM(w.w_norm * r.rel) AS step_lasp
  FROM rel r
  JOIN weights_norm w
    ON w.item = r.item AND w.year = r.year - 1
  WHERE r.year >= 2021
  GROUP BY r.year
),
cum AS (
  -- Cumulative product via log-sum-exp (no nested analytic functions)
  SELECT
    year,
    SUM(LN(step_lasp)) OVER (ORDER BY year ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_log
  FROM step
),
idx AS (
  SELECT year, EXP(cum_log) AS index_chain
  FROM cum
)
SELECT
  year,
  index_chain,
  SAFE_DIVIDE(index_chain, LAG(index_chain) OVER (ORDER BY year)) - 1 AS yoy
FROM idx
ORDER BY year;
