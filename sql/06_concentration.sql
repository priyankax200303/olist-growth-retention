-- Seller and category concentration, using complete-window orders.
DROP VIEW IF EXISTS analytics.v_seller CASCADE;
CREATE VIEW analytics.v_seller AS
WITH lines AS (
  SELECT i.seller_id, sum(i.price) gmv FROM analytics.items i
  JOIN analytics.orders o USING (order_id), analytics.window_bounds b
  WHERE o.purchase_month BETWEEN b.start_month AND b.end_month GROUP BY 1
), ops AS (
  SELECT seller_id, count(*) orders,
         count(*) FILTER (WHERE delivered_at IS NOT NULL) delivered,
         count(*) FILTER (WHERE is_late) late,
         count(review_score) reviews,
         count(*) FILTER (WHERE review_score <= 2) low_reviews,
         avg(review_score) avg_review
  FROM analytics.orders, analytics.window_bounds b
  WHERE purchase_month BETWEEN b.start_month AND b.end_month GROUP BY 1
)
SELECT l.seller_id, l.gmv, coalesce(p.orders, 0) orders, coalesce(p.delivered, 0) delivered,
       coalesce(p.late, 0) late, coalesce(p.reviews, 0) reviews, coalesce(p.low_reviews, 0) low_reviews,
       round(p.avg_review, 2) avg_review,
       row_number() OVER (ORDER BY l.gmv DESC) gmv_rank,
       count(*) OVER () n_sellers,
       sum(l.gmv) OVER (ORDER BY l.gmv DESC ROWS UNBOUNDED PRECEDING) / sum(l.gmv) OVER () cum_gmv_share
FROM lines l LEFT JOIN ops p USING (seller_id);

DROP VIEW IF EXISTS analytics.v_category;
CREATE VIEW analytics.v_category AS
SELECT o.category, count(*) orders, sum(o.gmv) gmv,
       round(100.0 * sum(o.gmv) / sum(sum(o.gmv)) OVER (), 2) pct_gmv,
       round(sum(o.gmv) / count(*), 2) aov,
       round(100.0 * sum(o.freight) / sum(o.gmv), 1) freight_pct_gmv,
       round(100.0 * count(*) FILTER (WHERE o.is_late) / nullif(count(*) FILTER (WHERE o.delivered_at IS NOT NULL), 0), 2) late_pct,
       round(avg(o.review_score), 2) avg_review,
       round(100.0 * count(*) FILTER (WHERE o.review_score <= 2) / nullif(count(o.review_score), 0), 1) low_review_pct
FROM analytics.orders o, analytics.window_bounds b
WHERE o.purchase_month BETWEEN b.start_month AND b.end_month
GROUP BY 1;
