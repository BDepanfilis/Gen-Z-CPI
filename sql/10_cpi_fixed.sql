-- sql/10_cpi_fixed.sql
-- Builds Gen-Z CPI with fixed 2020 weights (Laspeyres). Base index = 1.0 at 2020.
-- Tokens __PROJECT_ID__ and __DATASET__ are replaced by scripts/bq_run.sh.

WITH prices AS (
  SELECT item, category, 2020 AS year, price_2020 AS price FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, category, 2021, price_2021 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, category, 2022, price_2022 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, category, 2023, price_2023 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, category, 2024, price_2024 FROM `__PROJECT_ID__.__DATASET__.items_raw` UNION ALL
  SELECT item, category, 2025, price_2025 FROM `__PROJECT_ID__.__DATASET__.items_raw`
),
w0 AS (
  -- Normalize 2020 weights to sum to 1
  SELECT item, SAFE_DIVIDE(weight_2020, SUM(weight_2020) OVER()) AS w0
  FROM `__PROJECT_ID__.__DATASET__.items_raw`
),
base AS (
  SELECT p.item, p.price AS p0
  FROM prices p
  WHERE p.year = 2020
)
SELECT
  p.year,
  SUM(w.w0 * (p.price / b.p0))               AS index_fixed,                           -- 2020 = 1.0
  SAFE_DIVIDE(SUM(w.w0 * (p.price / b.p0)),
              LAG(SUM(w.w0 * (p.price / b.p0))) OVER(ORDER BY p.year)) - 1 AS yoy      -- year-over-year
FROM prices p
JOIN w0 w  USING (item)
JOIN base b USING (item)
GROUP BY p.year
ORDER BY p.year;
