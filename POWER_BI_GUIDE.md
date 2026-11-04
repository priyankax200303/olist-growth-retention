# Power BI build guide

Import these files from `outputs/tables/` using **Get data > Text/CSV**. Check that dates load as Date and percentages as Decimal.

## Page 1: Business
- **Cards:** sum of `monthly[gmv]`, sum of `monthly[orders]`, plus `kpis` values for returning GMV share and late share.
- **Column chart:** `monthly[purchase_month]` by `gmv`.
- **Bar chart:** `category[category]` by `pct_gmv`, Top N filter of 10.
- **Bar chart:** `seller_concentration[group]` by `gmv_share_pct`.

## Page 2: Retention
- **Column chart:** `repeat_windows[window_days]` by `repeat_pct`.
- **Matrix heatmap:** rows `cohorts[cohort_month]`, columns `month_offset`, values `retention_pct`, with a background color scale. Filter `month_offset` to 12 or below.
- **Table:** `rfm_summary`, sorted by `segment`.
- **Table:** `opportunity_scenarios`.

## Page 3: Delivery
- **Line chart:** `delivery_monthly[purchase_month]` by `late_pct`.
- **Bar chart:** `delivery_buckets[bucket]` by `avg_review`.
- **Table:** `delivery_legs`.
- **Table:** `delivery_state`, Top N of 10 by `late_pct`.

## Useful DAX
```DAX
Total GMV = SUM(monthly[gmv])
Total Orders = SUM(monthly[orders])
Average Order Value = DIVIDE([Total GMV], [Total Orders])
Freight Share = DIVIDE(SUM(monthly[freight]), [Total GMV])
```

Add the sample warning as a text box on every page, and note that August 2018 is cut off after the 22nd. Use GMV and R$ in titles, and give each chart a conclusion as its title.
