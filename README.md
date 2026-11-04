# Olist growth and retention analysis

**Verdict:** Olist's growth depends almost entirely on new customers. Only 1.99% return within 180 days, and repeat stays near 2% even after on-time, 5-star orders. Late orders score far lower on reviews, so delivery is a clear service-quality problem, but this data does not show it driving low retention. The next step is a controlled test of a second-purchase programme.

**Scope:** 97,905 valid orders and about 95,000 customers in a Brazilian marketplace, January 2017 to August 2018. Built with PostgreSQL and Python.

> Olist's repository calls this data a sample, so true repeat rates may be higher and money figures are not company totals.

## Findings

| Hypothesis | Result | Evidence |
|---|---|---|
| Repeat purchases are too low for retention to drive growth | **Supported** | 1.99% repeat at 180 days, 3.34% at 365 days. Returning customers provide 2.17% of GMV, or 2.74% in March to August 2018 |
| Late delivery lowers reviews and repeat purchases | **Half supported** | Late orders average 2.27 stars vs 4.29. The repeat gap is not statistically significant |
| A few sellers and categories drive revenue and delivery problems | **Half supported** | The top 10% of sellers hold 67.4% of GMV and 7 of 74 categories hold 49.9%. The top sellers' share of late orders (62.7%) is close to their share of deliveries (60.8%), so lateness is not concentrated there. Late rates still vary widely between sellers, and spike in a few months |

### Late delivery and repeat purchase
- On-time orders repeat at 1.82%, late orders at 1.38% (Fisher p = 0.11).
- The adjusted estimate is -0.33 points, with a 95% interval of -0.80 to +0.13. Across the logit, near-promise and seller fixed-effect versions, every interval includes zero. The near-promise estimate is too noisy to add much (+0.44, interval -1.67 to +2.54).
- The study can only detect gaps of about 0.76 points or more. That is 42% of the on-time rate, so a meaningful effect on late customers cannot be ruled out.
- The total effect is limited because few first orders are late: 7.8% in the year to August 2018. The low end of the full-sample intervals (-1.02 points) would mean 58 lost repeat orders a year in the sample.
- On-time, 5-star customers still repeat at just 1.92%.

### Delivery operations
- Late orders are 6.7% of reviewed orders and 32.6% of 1-2 star reviews.
- After controls, late orders score 1.98 stars lower.
- Three months (Nov 2017, Feb and Mar 2018) hold 21.7% of delivered orders and 48.4% of late ones. February and March 2018 alone hold 34.5%, and late rates in those months were 3.0% to 4.6% a year earlier, so this is not a seasonal pattern.
- Among sellers with 30 or more deliveries, the late rate runs from 1.5% at the 10th percentile to 12.8% at the 90th.
- Late orders average 27.9 days in transit vs 8.0 for on-time orders, and 6.0 vs 3.0 days to reach the carrier.

### A/B test (separate dataset)
Moving the Cookie Cats gate from level 30 to 40 lowered day-7 retention from 19.02% to 18.20% (p = 0.0016). Day 1 was not significant (p = 0.074). Recommendation: keep level 30. Assuming a 50/50 design, which the public data does not document, the split failed the sample ratio check (p = 0.0086). That should be investigated before trusting the effect size.

## Repository

| Path | Contents |
|---|---|
| `sql/` | Schema, analytics layer and analysis views, in run order |
| `data_checks/` | Integrity checks and the data quality log |
| `notebooks/` | Late delivery study and A/B test |
| `outputs/` | Tables, charts and metrics |
| `MEMO.md` | One-page recommendation |
| `POWER_BI_GUIDE.md` | Page-by-page Power BI build |

## Run it
Requires PostgreSQL and Python 3.

```bash
pip install -r requirements.txt
createdb olist
bash scripts/get_data.sh
bash scripts/run_all.sh
python3 scripts/reconcile.py
```

`reconcile.py` recalculates headline figures from raw files in pandas, without SQL.

## Key definitions
- **Customer:** `customer_unique_id`, because `customer_id` changes with each order.
- **Repeat:** a second order on a later calendar day.
- **GMV:** item price before freight. Olist's commission and margins are not in the data.
- **Late:** delivered after the promised calendar date.
- **Study group:** first orders with 180 days of follow-up after delivery, ending 22 August 2018.

## Limits
- The data is a sample, and how it was drawn is not documented.
- The delivery study is observational, so it shows association and not proven cause.
- The study needs 180 days of follow-up after delivery, so late orders from early 2018 are under-represented. It shows 5.0% late first orders vs 7.8% across the latest year.
- August 2018 is effectively cut off after the 22nd, so its month totals are partial.
- Olist sells through other marketplaces, so a customer may not see Olist as the brand. That may limit retention and how customers can be contacted.
- Opportunity figures rest on assumed lifts and reach that have not been tested.

## Sources
- [Olist data](https://github.com/olist/work-at-olist-data)
- [Cookie Cats copy](https://github.com/ryanschaub/Mobile-Games-A-B-Testing-with-Cookie-Cats)
