"""Recalculates headline numbers in pandas from the raw CSVs, without using any SQL, and compares them with the outputs."""
import pandas as pd
R = "data/raw/olist_"; T = "outputs/tables/"
o = pd.read_csv(R + "orders_dataset.csv", parse_dates=["order_purchase_timestamp", "order_delivered_customer_date", "order_estimated_delivery_date"])
c = pd.read_csv(R + "customers_dataset.csv"); i = pd.read_csv(R + "order_items_dataset.csv")
a = i.groupby("order_id").agg(gmv=("price", "sum")).reset_index()
d = o.merge(c, on="customer_id").merge(a, on="order_id")
d = d[~d.order_status.isin(["canceled", "unavailable"])].copy()
d["pday"] = d.order_purchase_timestamp.dt.normalize()
d["month"] = d.order_purchase_timestamp.dt.to_period("M")
w = d[(d.month >= "2017-01") & (d.month <= "2018-08")]
kp = pd.read_csv(T + "kpis.csv").set_index("metric").value
res = [("orders", len(w), kp["orders"]), ("gmv", w.gmv.sum(), kp["gmv"])]
first = d.groupby("customer_unique_id").pday.min().rename("t1")
second = d.merge(first, on="customer_unique_id"); second = second[second.pday > second.t1].groupby("customer_unique_id").pday.min().rename("t2")
f = pd.concat([first, second], axis=1); f["first_ts"] = d.groupby("customer_unique_id").order_purchase_timestamp.min()
end = pd.Timestamp("2018-08-22 23:59:59")
e = f[f.first_ts + pd.Timedelta(days=180) <= end]
res.append(("repeat_180", 100 * ((e.t2 - e.t1).dt.days <= 180).mean(), kp["repeat_180"]))
dl = w[w.order_delivered_customer_date.notna()]
late = dl.order_delivered_customer_date.dt.normalize() > dl.order_estimated_delivery_date.dt.normalize()
res.append(("late_pct", 100 * late.mean(), kp["late_pct"]))
# 180-day repeat after delivery, first orders only, rebuilt without SQL
s = d.sort_values(["order_purchase_timestamp", "order_id"]).groupby("customer_unique_id").head(1)
s = s[(s.order_status == "delivered") & s.order_delivered_customer_date.notna()]
s = s[s.order_delivered_customer_date + pd.Timedelta(days=180) <= end].copy()
x = d.merge(s[["customer_unique_id", "order_id", "pday", "order_delivered_customer_date"]], on="customer_unique_id", suffixes=("", "_f"))
after = x[x.pday > x.pday_f]
pre = after[after.order_purchase_timestamp <= after.order_delivered_customer_date_f].customer_unique_id.unique()
ok = after[(after.order_purchase_timestamp > after.order_delivered_customer_date_f) & (after.order_purchase_timestamp <= after.order_delivered_customer_date_f + pd.Timedelta(days=180))].customer_unique_id.unique()
s = s[~s.customer_unique_id.isin(pre)].copy(); s["y"] = s.customer_unique_id.isin(ok)
s["late"] = s.order_delivered_customer_date.dt.normalize() > s.order_estimated_delivery_date.dt.normalize()
res += [("ontime_repeat", 100 * s[~s.late].y.mean(), kp["ontime_repeat"]), ("late_repeat", 100 * s[s.late].y.mean(), kp["late_repeat"])]
for name, x, y in res:
    print(f"{name:12s} pandas={x:,.2f} output={float(y):,.2f} diff={abs(x-float(y)):.4f}")
