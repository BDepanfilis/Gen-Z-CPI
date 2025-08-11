#!/usr/bin/env bash
# bq_run.sh — Load CSVs -> run SQL -> export CSVs (guarded & reproducible)
#
# Usage (from your project root):
#   export PROJECT_ID=your-gcp-project        # REQUIRED
#   export DATASET=genz_cpi                   # REQUIRED
#   export LOCATION=US                        # REQUIRED
#   bash bq_run.sh
#
# Prereqs: gcloud + bq CLIs installed, you’ve run `gcloud auth login`.
# Safe by design: no creds in repo, prompts before overwriting tables.

set -euo pipefail

# ---------- helpers ----------
need_cmd () {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing command: $1"; exit 1; }
}
need_cmd gcloud
need_cmd bq
need_cmd sed

# Resolve repo root if script lives in scripts/
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
if [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  ROOT_DIR="$SCRIPT_DIR"
fi
cd "$ROOT_DIR"

# Require env vars (no defaults to avoid accidents)
: "${PROJECT_ID:?Set PROJECT_ID}"
: "${DATASET:?Set DATASET}"
: "${LOCATION:?Set LOCATION}"

echo "👉 Config"
echo "   Project : ${PROJECT_ID}"
echo "   Dataset : ${DATASET}"
echo "   Location: ${LOCATION}"
echo

read -rp "About to LOAD CSVs and OVERWRITE tables in ${PROJECT_ID}:${DATASET}. Continue? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

mkdir -p outputs

# ---------- 1) ensure dataset exists ----------
if bq --location="$LOCATION" --project_id="$PROJECT_ID" ls -d "$DATASET" >/dev/null 2>&1; then
  echo "✅ Dataset exists: $DATASET"
else
  echo "📦 Creating dataset: $DATASET"
  bq --location="$LOCATION" --project_id="$PROJECT_ID" mk -d "$DATASET" >/dev/null
fi

# ---------- 2) load CSVs ----------
ITEMS_CSV="data/external/item_prices_weights.csv"
BLS_CSV="data/external/bls_cpiu_yearly.csv"

[[ -f "$ITEMS_CSV" ]] || { echo "❌ Missing $ITEMS_CSV"; exit 1; }
[[ -f "$BLS_CSV"   ]] || { echo "❌ Missing $BLS_CSV"; exit 1; }

echo "⬆️  Loading items -> ${DATASET}.items_raw"
bq load --replace --source_format=CSV --skip_leading_rows=1 \
  "${PROJECT_ID}:${DATASET}.items_raw" \
  "$ITEMS_CSV" \
  item:STRING,category:STRING,price_2020:FLOAT64,price_2021:FLOAT64,price_2022:FLOAT64,price_2023:FLOAT64,price_2024:FLOAT64,price_2025:FLOAT64,weight_2020:FLOAT64,weight_2021:FLOAT64,weight_2022:FLOAT64,weight_2023:FLOAT64,weight_2024:FLOAT64,weight_2025:FLOAT64

echo "⬆️  Loading BLS -> ${DATASET}.bls_cpiu_yearly"
bq load --replace --source_format=CSV --skip_leading_rows=1 \
  "${PROJECT_ID}:${DATASET}.bls_cpiu_yearly" \
  "$BLS_CSV" \
  year:INT64,cpiu_index:FLOAT64,yoy:FLOAT64

# ---------- 3) run SQL -> materialize tables ----------
run_query () {
  local infile="$1"; local outtable="$2"
  [[ -f "$infile" ]] || { echo "❌ Missing SQL file: $infile"; exit 1; }
  local tmp="$(mktemp)"
  sed -e "s/__PROJECT_ID__/${PROJECT_ID}/g" -e "s/__DATASET__/${DATASET}/g" "$infile" > "$tmp"
  echo "▶️  Building ${DATASET}.${outtable} from $(basename "$infile") ..."
  bq query --use_legacy_sql=false --project_id="$PROJECT_ID" \
    "CREATE OR REPLACE TABLE \`${PROJECT_ID}.${DATASET}.${outtable}\` AS $(cat "$tmp")" >/dev/null
  rm -f "$tmp"
}

run_query "sql/10_cpi_fixed.sql"        "genz_cpi_fixed"
run_query "sql/11_cpi_annual_chain.sql" "genz_cpi_chain"
run_query "sql/20_validate.sql"         "validation_bls"

# ---------- 4) export local CSVs ----------
echo "💾 Exporting to ./outputs"
bq query --use_legacy_sql=false --format=csv --project_id="$PROJECT_ID" \
  "SELECT * FROM \`${PROJECT_ID}.${DATASET}.genz_cpi_fixed\` ORDER BY year" > outputs/genz_cpi_fixed.csv
bq query --use_legacy_sql=false --format=csv --project_id="$PROJECT_ID" \
  "SELECT * FROM \`${PROJECT_ID}.${DATASET}.genz_cpi_chain\` ORDER BY year" > outputs/genz_cpi_chain.csv
bq query --use_legacy_sql=false --format=csv --project_id="$PROJECT_ID" \
  "SELECT * FROM \`${PROJECT_ID}.${DATASET}.validation_bls\` ORDER BY year" > outputs/validation_bls_compare.csv

echo "✅ Done. See the 'outputs' folder."
