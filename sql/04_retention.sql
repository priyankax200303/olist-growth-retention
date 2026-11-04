-- Repeat is a second shopping occasion on a later calendar day.
-- Observation ends 2018-08-22: daily orders collapse after this date, an extract artefact, not a demand change.
DROP VIEW IF EXISTS analytics.obs CASCADE;
CREATE VIEW analytics.obs AS SELECT TIMESTAMP '2018-08-22 23:59:59' AS obs_end;

-- Time to second occasion, for every customer who reached one.
DROP VIEW IF EXISTS analytics.v_time_to_second;
CREATE VIEW analytics.v_time_to_second AS
WITH firsts AS (
  SELECT customer_unique_id, min(purchased_at) t1 FROM analytics.customer_orders WHERE occasion_seq = 1 GROUP BY 1
), seconds AS (
  SELECT customer_unique_id, min(purchased_at) t2 FROM analytics.customer_orders WHERE occasion_seq = 2 GROUP BY 1
)
SELECT customer_unique_id, t1, t2, t2::date - t1::date AS days_to_second
FROM firsts JOIN seconds USING (customer_unique_id);

-- Fixed-window repeat rate: only customers with the full window of follow-up count.
DROP VIEW IF EXISTS analytics.v_repeat_windows;
CREATE VIEW analytics.v_repeat_windows AS
SELECT w.days AS window_days,
       count(*) AS eligible_customers,
       count(*) FILTER (WHERE t.days_to_second <= w.days) AS repeaters,
       round(100.0 * count(*) FILTER (WHERE t.days_to_second <= w.days) / count(*), 2) AS repeat_pct
FROM analytics.customers c
CROSS JOIN (VALUES (30), (90), (180), (365)) w(days)
CROSS JOIN analytics.obs
LEFT JOIN analytics.v_time_to_second t USING (customer_unique_id)
WHERE c.first_order_at + (w.days || ' days')::interval <= obs.obs_end
GROUP BY w.days;

-- Monthly acquisition cohorts: share of each cohort active N months after the first purchase month.
DROP VIEW IF EXISTS analytics.v_cohorts;
CREATE VIEW analytics.v_cohorts AS
WITH activity AS (
  SELECT DISTINCT o.customer_unique_id, c.cohort_month,
         (extract(year FROM age(o.purchase_month, c.cohort_month)) * 12
          + extract(month FROM age(o.purchase_month, c.cohort_month)))::int AS month_offset
  FROM analytics.customer_orders o JOIN analytics.customers c USING (customer_unique_id)
  WHERE o.purchase_month <= DATE '2018-08-01' AND o.occasion_seq > 1
), sizes AS (
  SELECT cohort_month, count(*) AS cohort_size FROM analytics.customers GROUP BY 1
)
SELECT a.cohort_month, s.cohort_size, a.month_offset,
       count(*) AS active_customers,
       round(100.0 * count(*) / s.cohort_size, 2) AS retention_pct
FROM activity a JOIN sizes s USING (cohort_month), analytics.window_bounds b
WHERE a.cohort_month BETWEEN b.start_month AND b.end_month AND a.month_offset > 0
GROUP BY 1, 2, 3;
