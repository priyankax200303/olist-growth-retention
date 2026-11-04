"""Sizes actions using visible assumptions. All money is R$ within the Olist sample, not company totals."""
import csv, psycopg2
import pandas as pd
REACH = 0.40  # Assumed share of new customers a programme can contact. Recent one-order segments are about 39% of customers.
con = psycopg2.connect(dbname="olist"); q = con.cursor()
q.execute("select count(*) from analytics.customers where first_order_at>='2017-09-01' and first_order_at<'2018-09-01'"); new_customers = q.fetchone()[0]
q.execute("select avg(second_gmv) from analytics.v_repeat_pairs"); second_order = float(q.fetchone()[0])
q.execute("select sum(gmv) from analytics.v_monthly where purchase_month>='2017-09-01'"); t12 = float(q.fetchone()[0])
# Late share comes from all first orders in the period. The study group under-represents early-2018 late orders.
q.execute("select avg(is_late::int) from analytics.delivery_cohort where purchased_at>='2017-09-01' and purchased_at<'2018-09-01'"); late_share = float(q.fetchone()[0])
m = pd.read_csv("outputs/tables/late_repeat_models.csv"); full = m[~m.model.str.startswith("C.")]
est = abs(m.estimate_pts.iloc[0]); widest = abs(full.ci_low.min())
rows = []
def add(name, kind, pts, share):
    orders = new_customers * share * pts / 100; gmv = orders * second_order
    rows.append(dict(scenario=name, lever=kind, repeat_lift_pts=round(pts, 2), added_orders=round(orders), added_gmv=round(gmv), pct_of_t12_gmv=round(100 * gmv / t12, 2)))
add("No late orders: central estimate", "Delivery", est, late_share)
add("No late orders: low end of interval", "Delivery", widest, late_share)
for label, pts in (("0.25", .25), ("0.5", .5), ("1", 1.0)):
    add(f"Retention lift of {label} pt, 40% reach (assumed)", "Retention", pts, REACH)
w = csv.DictWriter(open("outputs/tables/opportunity_scenarios.csv", "w", newline=""), rows[0].keys()); w.writeheader(); w.writerows(rows)
print(new_customers, round(second_order, 2), round(t12), round(late_share, 4), "breakeven pts", round(widest * late_share / REACH, 3)); [print(r) for r in rows]
