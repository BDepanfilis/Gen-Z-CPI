-- sql/20_validate.sql
-- Join the two Gen-Z indices to BLS CPI-U (yearly) for comparison.

WITH fixed AS (
  SELECT * FROM `__PROJECT_ID__.__DATASET__.genz_cpi_fixed`
),
chain AS (
  SELECT * FROM `__PROJECT_ID__.__DATASET__.genz_cpi_chain`
),
bls AS (
  SELECT year, cpiu_index
  FROM `__PROJECT_ID__.__DATASET__.bls_cpiu_yearly`
)
SELECT
  COALESCE(fixed.year, chain.year, bls.year) AS year,
  fixed.index_fixed,
  chain.index_chain,
  bls.cpiu_index,
  (fixed.index_fixed - bls.cpiu_index) AS diff_fixed_vs_bls,
  (chain.index_chain - bls.cpiu_index) AS diff_chain_vs_bls
FROM fixed
FULL OUTER JOIN chain USING (year)
FULL OUTER JOIN bls   USING (year)
ORDER BY year;
