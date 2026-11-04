-- One row per customer: the first order, its delivery experience, and what happened after delivery.
-- Clock starts at delivery, because that is when the customer learns the order was late.
DROP TABLE IF EXISTS analytics.delivery_cohort;
CREATE TABLE analytics.delivery_cohort AS
WITH first_order AS (SELECT * FROM analytics.customer_orders WHERE order_seq = 1),
later AS (
  SELECT f.customer_unique_id,
         bool_or(c.purchased_at::date > f.purchased_at::date AND c.purchased_at <= f.delivered_at) AS reordered_before_delivery,
         bool_or(c.purchased_at > f.delivered_at AND c.purchased_at::date > f.purchased_at::date
                 AND c.purchased_at <= f.delivered_at + INTERVAL '180 days') AS repeat_180d,
         bool_or(c.purchased_at > f.delivered_at AND c.purchased_at::date > f.purchased_at::date
                 AND c.purchased_at <= f.delivered_at + INTERVAL '365 days') AS repeat_365d
  FROM first_order f JOIN analytics.customer_orders c USING (customer_unique_id)
  GROUP BY 1
)
SELECT f.*, l.reordered_before_delivery, l.repeat_180d, l.repeat_365d,
       f.delivered_at + INTERVAL '180 days' <= (SELECT obs_end FROM analytics.obs) AS eligible_180d,
       f.delivered_at + INTERVAL '365 days' <= (SELECT obs_end FROM analytics.obs) AS eligible_365d
FROM first_order f JOIN later l USING (customer_unique_id)
WHERE f.delivered_at IS NOT NULL AND f.order_status = 'delivered';
