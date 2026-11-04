-- Delivery performance on delivered orders only. All first-order delivery analysis in Python uses this table.
DROP VIEW IF EXISTS analytics.v_delivery_buckets;
CREATE VIEW analytics.v_delivery_buckets AS
SELECT CASE WHEN days_late <= -15 THEN '1 15+ days early' WHEN days_late <= -8 THEN '2 8-14 days early'
            WHEN days_late <= -1 THEN '3 1-7 days early' WHEN days_late = 0 THEN '4 On promised day'
            WHEN days_late <= 3 THEN '5 1-3 days late' WHEN days_late <= 7 THEN '6 4-7 days late'
            ELSE '7 8+ days late' END AS bucket,
       count(*) orders, count(review_score) reviews, round(avg(review_score), 2) avg_review,
       round(100.0 * count(*) FILTER (WHERE review_score <= 2) / nullif(count(review_score), 0), 1) low_review_pct
FROM analytics.orders, analytics.window_bounds b
WHERE delivered_at IS NOT NULL AND purchase_month BETWEEN b.start_month AND b.end_month
GROUP BY 1;

DROP VIEW IF EXISTS analytics.v_delivery_monthly;
CREATE VIEW analytics.v_delivery_monthly AS
SELECT purchase_month, count(*) delivered,
       round(100.0 * count(*) FILTER (WHERE is_late) / count(*), 2) late_pct,
       round(avg(actual_days), 1) avg_actual_days, round(avg(promised_days), 1) avg_promised_days,
       round(avg(review_score), 2) avg_review
FROM analytics.orders, analytics.window_bounds b
WHERE delivered_at IS NOT NULL AND purchase_month BETWEEN b.start_month AND b.end_month
GROUP BY 1;

DROP VIEW IF EXISTS analytics.v_delivery_state;
CREATE VIEW analytics.v_delivery_state AS
SELECT customer_state, count(*) delivered, round(100.0 * count(*) FILTER (WHERE is_late) / count(*), 2) late_pct,
       round(avg(actual_days), 1) avg_actual_days, round(avg(review_score), 2) avg_review
FROM analytics.orders, analytics.window_bounds b
WHERE delivered_at IS NOT NULL AND purchase_month BETWEEN b.start_month AND b.end_month
GROUP BY 1;

-- Where does a late order lose its time: seller handover or the carrier leg?
DROP VIEW IF EXISTS analytics.v_delivery_legs;
CREATE VIEW analytics.v_delivery_legs AS
SELECT is_late, count(*) orders,
       round(avg(extract(epoch FROM carrier_at - purchased_at) / 86400)::numeric, 1) avg_days_to_carrier,
       round(avg(extract(epoch FROM delivered_at - carrier_at) / 86400)::numeric, 1) avg_days_in_transit,
       round(avg(promised_days), 1) avg_promised_days
FROM analytics.orders, analytics.window_bounds b
WHERE delivered_at IS NOT NULL AND carrier_at IS NOT NULL AND carrier_at <= delivered_at
  AND purchase_month BETWEEN b.start_month AND b.end_month
GROUP BY 1;
