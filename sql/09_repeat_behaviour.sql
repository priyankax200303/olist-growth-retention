-- What do repeat customers actually buy next, and from whom?
DROP VIEW IF EXISTS analytics.v_repeat_pairs CASCADE;
CREATE VIEW analytics.v_repeat_pairs AS
WITH o1 AS (SELECT DISTINCT ON (customer_unique_id) * FROM analytics.customer_orders WHERE occasion_seq = 1 ORDER BY customer_unique_id, gmv DESC),
     o2 AS (SELECT DISTINCT ON (customer_unique_id) * FROM analytics.customer_orders WHERE occasion_seq = 2 ORDER BY customer_unique_id, gmv DESC)
SELECT o1.customer_unique_id, o1.category AS first_category, o2.category AS second_category,
       o1.seller_id = o2.seller_id AS same_seller, o1.category = o2.category AS same_category,
       o1.gmv AS first_gmv, o2.gmv AS second_gmv, o2.purchased_at::date - o1.purchased_at::date AS gap_days
FROM o1 JOIN o2 USING (customer_unique_id);

DROP VIEW IF EXISTS analytics.v_seller_late;
CREATE VIEW analytics.v_seller_late AS
SELECT purchase_month IN ('2017-11-01','2018-02-01','2018-03-01') AS peak_month,
       count(*) delivered, count(*) FILTER (WHERE is_late) late
FROM analytics.orders, analytics.window_bounds b
WHERE delivered_at IS NOT NULL AND purchase_month BETWEEN b.start_month AND b.end_month GROUP BY 1;
