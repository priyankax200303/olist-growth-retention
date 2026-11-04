#!/usr/bin/env bash
# Rebuilds the database from the raw CSVs. Usage: bash scripts/load.sh
set -euo pipefail
cd "$(dirname "$0")/.."
psql -q -v ON_ERROR_STOP=1 -d olist -f sql/01_schema.sql
for pair in customers:olist_customers_dataset orders:olist_orders_dataset order_items:olist_order_items_dataset \
  order_payments:olist_order_payments_dataset order_reviews:olist_order_reviews_dataset products:olist_products_dataset \
  sellers:olist_sellers_dataset geolocation:olist_geolocation_dataset category_translation:product_category_name_translation; do
  t=${pair%%:*}; f=${pair##*:}
  psql -q -v ON_ERROR_STOP=1 -d olist -c "\copy raw.$t FROM 'data/raw/$f.csv' WITH (FORMAT csv, HEADER true)"
done
