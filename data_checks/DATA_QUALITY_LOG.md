# Data quality log

Raw output is in `checks_output.txt`. Rules are applied in `sql/02_analytics_layer.sql`.

| # | Issue found | Size | Treatment |
|---|---|---|---|
| 1 | `customer_id` is issued per order | 99,441 IDs, 96,096 real customers | Use `customer_unique_id` everywhere |
| 2 | Source README calls the data a sample | Unknown rate | Absolute repeat rates may be low. Money figures are not company totals |
| 3 | `review_id` repeats, and some orders have several reviews | 814 and 551 rows | Keep the most recently answered review per order |
| 4 | Promised date is stored at midnight | Timestamp logic gives 8.11% late, date logic gives 6.77% | Compare calendar dates |
| 5 | Near-empty months at both ends | 2016, Sep to Oct 2018 | Trends use Jan 2017 to Aug 2018 |
| 6 | Daily orders collapse after 22 Aug 2018 | From about 240 a day to 11 | Follow-up ends 22 Aug 2018 |
| 7 | Orders with no items | 775 | Excluded |
| 8 | Cancelled or unavailable orders | 1,234 orders, of which 467 have items | Excluded from valid orders |
| 9 | Delivered status with no delivery date | 8 | Kept in sales, excluded from delivery analysis |
| 10 | Products with no category | 610 | Labelled `uncategorized` |
| 11 | Categories without an English name | 2 | Keep the Portuguese name |
| 12 | Carrier date earlier than approval | 1,359 | Kept. Stage timing only needs carrier before delivery |
| 13 | Delivered date earlier than carrier date | 23 | Excluded from stage timing only |
| 14 | Payment vs item total off by over R$1 | 312 of 98,665 orders, net R$1,823 | GMV comes from items. Totals reconcile to within 0.02% |
| 15 | Reviews created before the delivery date | 5.3% of reviews on delivered orders, by calendar date | Kept, because Olist surveys at the promised date and a missing parcel is a real experience |
| 16 | Undelivered orders have no late flag | 1,702 in the window | Delivery analysis excludes them, so it may understate bad experiences |
| 17 | August 2018 stops on the 22nd in practice | Partial month | Compare periods per day, not by month totals. August cohort cells are partial |
