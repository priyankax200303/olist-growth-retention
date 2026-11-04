-- Analytics layer: one clean row per order, with all customer-level identity resolved.
-- Rules (each is justified in data_checks/DATA_QUALITY_LOG.md):
--   * customer = customer_unique_id (customer_id is issued per order)
--   * valid order = has items AND status not canceled/unavailable
--   * GMV = sum of item price, excluding freight. Olist's own commission is not in the data.
--   * late = delivered calendar date after promised calendar date (promise is stored at 00:00)
--   * one review per order = the most recently answered review
--   * primary category/seller = the highest-value line in the order
DROP SCHEMA IF EXISTS analytics CASCADE; CREATE SCHEMA analytics;

CREATE TABLE analytics.products AS
SELECT p.product_id,
       COALESCE(t.product_category_name_english, p.product_category_name, 'uncategorized') AS category,
       p.product_weight_g
FROM raw.products p LEFT JOIN raw.category_translation t USING (product_category_name);

CREATE TABLE analytics.items AS
SELECT i.*, p.category,
       row_number() OVER (PARTITION BY i.order_id ORDER BY i.price DESC, i.order_item_id) AS value_rank
FROM raw.order_items i JOIN analytics.products p USING (product_id);

CREATE TABLE analytics.orders AS
WITH item_agg AS (
  SELECT order_id, count(*) n_items, count(DISTINCT seller_id) n_sellers,
         sum(price) gmv, sum(freight_value) freight
  FROM analytics.items GROUP BY 1
), primary_line AS (
  SELECT order_id, category, seller_id FROM analytics.items WHERE value_rank = 1
), pay AS (
  SELECT order_id, sum(payment_value) payment_value,
         max(payment_installments) installments,
         (array_agg(payment_type ORDER BY payment_value DESC))[1] AS payment_type
  FROM raw.order_payments GROUP BY 1
), rev AS (
  SELECT DISTINCT ON (order_id) order_id, review_score, review_creation_date
  FROM raw.order_reviews ORDER BY order_id, review_answer_timestamp DESC, review_id
)
SELECT o.order_id, c.customer_unique_id, c.customer_state, c.customer_city, o.order_status,
       o.order_purchase_timestamp AS purchased_at,
       date_trunc('month', o.order_purchase_timestamp)::date AS purchase_month,
       o.order_delivered_carrier_date AS carrier_at,
       o.order_delivered_customer_date AS delivered_at,
       o.order_estimated_delivery_date::date AS promised_date,
       ia.n_items, ia.n_sellers, ia.gmv, ia.freight, pay.payment_value, pay.installments, pay.payment_type,
       pl.category, pl.seller_id, s.seller_state,
       rev.review_score,
       (o.order_estimated_delivery_date::date - o.order_purchase_timestamp::date) AS promised_days,
       (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date) AS actual_days,
       (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) AS days_late,
       CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
            ELSE o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date END AS is_late
FROM raw.orders o
JOIN raw.customers c USING (customer_id)
JOIN item_agg ia USING (order_id)
JOIN primary_line pl USING (order_id)
JOIN raw.sellers s ON s.seller_id = pl.seller_id
LEFT JOIN pay USING (order_id)
LEFT JOIN rev USING (order_id)
WHERE o.order_status NOT IN ('canceled', 'unavailable');

CREATE INDEX ON analytics.orders (customer_unique_id, purchased_at);

-- Analysis window: full calendar months only. Earlier months are near-empty and Sep-Oct 2018 is a stub.
CREATE VIEW analytics.window_bounds AS SELECT DATE '2017-01-01' AS start_month, DATE '2018-08-01' AS end_month;

-- Sequence each customer's orders. Same-day orders are one shopping occasion, so a repeat means a later calendar day.
CREATE TABLE analytics.customer_orders AS
SELECT o.*,
       row_number() OVER w AS order_seq,
       min(purchased_at) OVER (PARTITION BY customer_unique_id) AS first_purchased_at,
       dense_rank() OVER (PARTITION BY customer_unique_id ORDER BY purchased_at::date) AS occasion_seq
FROM analytics.orders o
WINDOW w AS (PARTITION BY customer_unique_id ORDER BY purchased_at, order_id);

CREATE TABLE analytics.customers AS
SELECT customer_unique_id, min(purchased_at) first_order_at,
       date_trunc('month', min(purchased_at))::date cohort_month,
       count(*) n_orders, max(occasion_seq) n_occasions, sum(gmv) gmv, max(purchased_at) last_order_at
FROM analytics.customer_orders GROUP BY 1;
ANALYZE;
