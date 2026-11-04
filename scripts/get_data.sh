#!/usr/bin/env bash
# Downloads source data into data/raw.
set -euo pipefail
cd "$(dirname "$0")/.."; mkdir -p data/raw
B=https://raw.githubusercontent.com/olist/work-at-olist-data/master/datasets
for f in olist_customers_dataset olist_geolocation_dataset olist_order_items_dataset olist_order_payments_dataset olist_order_reviews_dataset olist_orders_dataset olist_products_dataset olist_sellers_dataset product_category_name_translation; do
  curl -fsS -o "data/raw/$f.csv" "$B/$f.csv"
done
curl -fsS -o data/raw/cookie_cats.csv https://raw.githubusercontent.com/ryanschaub/Mobile-Games-A-B-Testing-with-Cookie-Cats/master/cookie_cats.csv
