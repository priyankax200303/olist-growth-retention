#!/usr/bin/env bash
# Full rebuild from raw data. Requires a local PostgreSQL database named olist.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/load.sh
for f in 02_analytics_layer 03_business_overview 04_retention 05_rfm 06_concentration 07_delivery 08_delivery_cohort 09_repeat_behaviour; do
  PGOPTIONS='-c client_min_messages=warning' psql -q -v ON_ERROR_STOP=1 -d olist -f "sql/$f.sql"
done
psql -d olist -f data_checks/checks.sql > data_checks/checks_output.txt
mkdir -p outputs/tables outputs/charts
rm -f outputs/metrics.json
bash scripts/export_tables.sh
python3 scripts/build_notebooks.py 2>/dev/null
python3 scripts/size_opportunity.py > /dev/null
python3 scripts/build_kpis.py
