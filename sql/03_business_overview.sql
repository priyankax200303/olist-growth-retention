-- Monthly KPIs for complete months (Jan 2017 to Aug 2018).
DROP VIEW IF EXISTS analytics.v_monthly;
CREATE VIEW analytics.v_monthly AS
SELECT purchase_month,
       count(*) AS orders,
       count(DISTINCT customer_unique_id) AS active_customers,
       sum(gmv) AS gmv,
       sum(freight) AS freight,
       round(sum(gmv) / count(*), 2) AS avg_order_value,
       round(100.0 * sum(freight) / sum(gmv), 1) AS freight_pct_gmv,
       round(100.0 * (sum(gmv) / lag(sum(gmv)) OVER (ORDER BY purchase_month) - 1), 1) AS gmv_mom_pct
FROM analytics.orders, analytics.window_bounds b
WHERE purchase_month BETWEEN b.start_month AND b.end_month
GROUP BY purchase_month;

-- New vs returning GMV: how much of each month comes from customers seen before?
DROP VIEW IF EXISTS analytics.v_monthly_new_returning;
CREATE VIEW analytics.v_monthly_new_returning AS
SELECT o.purchase_month,
       sum(o.gmv) FILTER (WHERE o.occasion_seq = 1) AS new_gmv,
       sum(o.gmv) FILTER (WHERE o.occasion_seq > 1) AS returning_gmv,
       round(100.0 * coalesce(sum(o.gmv) FILTER (WHERE o.occasion_seq > 1), 0) / sum(o.gmv), 2) AS returning_pct
FROM analytics.customer_orders o, analytics.window_bounds b
WHERE o.purchase_month BETWEEN b.start_month AND b.end_month
GROUP BY 1;
