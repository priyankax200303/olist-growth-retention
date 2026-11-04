#!/usr/bin/env bash
# Exports every dashboard table to CSV, for the web dashboard and Power BI.
set -euo pipefail
cd "$(dirname "$0")/.."; mkdir -p outputs/tables
x(){ psql -q -d olist -c "\copy ($2) TO 'outputs/tables/$1.csv' WITH (FORMAT csv, HEADER true)"; }
x monthly "SELECT * FROM analytics.v_monthly ORDER BY 1"
x monthly_new_returning "SELECT * FROM analytics.v_monthly_new_returning ORDER BY 1"
x repeat_windows "SELECT * FROM analytics.v_repeat_windows ORDER BY 1"
x cohorts "SELECT * FROM analytics.v_cohorts ORDER BY 1,3"
x rfm_summary "SELECT * FROM analytics.v_rfm_summary ORDER BY 1"
x category "SELECT * FROM analytics.v_category ORDER BY gmv DESC"
x seller "SELECT * FROM analytics.v_seller ORDER BY gmv_rank"
x delivery_buckets "SELECT * FROM analytics.v_delivery_buckets ORDER BY 1"
x delivery_monthly "SELECT * FROM analytics.v_delivery_monthly ORDER BY 1"
x delivery_state "SELECT * FROM analytics.v_delivery_state ORDER BY late_pct DESC"
x delivery_legs "SELECT * FROM analytics.v_delivery_legs ORDER BY 1"
x late_by_period "SELECT * FROM analytics.v_seller_late ORDER BY 1"
x repeat_pairs_summary "SELECT count(*) repeaters, round(100*avg(same_category::int),1) same_category_pct, round(100*avg(same_seller::int),1) same_seller_pct, round(avg(first_gmv),2) avg_first_gmv, round(avg(second_gmv),2) avg_second_gmv FROM analytics.v_repeat_pairs"
