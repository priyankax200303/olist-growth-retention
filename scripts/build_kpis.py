"""Builds the seller concentration and KPI tables used by the dashboard."""
import json, math
import pandas as pd
T = "outputs/tables/"; m = json.load(open("outputs/metrics.json"))
s = pd.read_csv(T + "seller.csv"); n = len(s); rows = []
for p in (1, 10, 20):
    k = math.ceil(n * p / 100)
    rows.append(dict(group=f"Top {p}% of sellers", sellers=k, gmv_share_pct=round(100 * s.head(k).gmv.sum() / s.gmv.sum(), 1)))
pd.DataFrame(rows).to_csv(T + "seller_concentration.csv", index=False)
rr = pd.read_csv(T + "monthly_new_returning.csv"); rec = rr[rr.purchase_month >= "2018-03-01"]
mo = pd.read_csv(T + "monthly.csv"); w = pd.read_csv(T + "repeat_windows.csv"); ret = pd.read_csv(T + "monthly_new_returning.csv")
d = pd.read_csv(T + "delivery_monthly.csv"); o = pd.read_csv(T + "late_by_period.csv"); peak = o[o.peak_month == "t"]
r, v, ab = m["reviews"], m["repeat"], m["ab"]
k = dict(orders=int(mo.orders.sum()), gmv=float(mo.gmv.sum()), repeat_180=float(w[w.window_days == 180].repeat_pct.iloc[0]),
    late_pct=round((d.late_pct * d.delivered).sum() / d.delivered.sum(), 2),
    returning_pct_gmv=round(100 * ret.returning_gmv.sum() / (ret.returning_gmv.sum() + ret.new_gmv.sum()), 2),
    returning_pct_recent=round(100 * rec.returning_gmv.sum() / (rec.returning_gmv.sum() + rec.new_gmv.sum()), 2),
    late_share_low_reviews=round(r["late_share_low"], 1), late_share_orders=round(r["late_share_orders"], 1),
    late_review=round(r["late_review"], 2), ontime_review=round(r["ontime_review"], 2),
    peak_share_late=round(100 * peak.late.sum() / o.late.sum(), 1), peak_share_delivered=round(100 * peak.delivered.sum() / o.delivered.sum(), 1),
    adj_repeat=round(v["adj"], 2), adj_repeat_lo=round(v["adj_lo"], 2), adj_repeat_hi=round(v["adj_hi"], 2),
    ontime_repeat=round(v["ontime_rate"], 2), late_repeat=round(v["late_rate"], 2),
    ab_srm_p=round(ab["srm_p"], 4), ab_gate30_share=round(ab["gate30_share"], 2), ab_players=90189,
    repeat_sample=v["n"], late_sample=v["late_n"], mde_pts=round(v["mde_pts"], 2))
pd.DataFrame(k.items(), columns=["metric", "value"]).to_csv(T + "kpis.csv", index=False)
