-- RFM. Frequency cannot be quintiled: nearly every customer has one occasion, so ntile would rank
-- identical customers arbitrarily. F is therefore binary, while R and M use quintiles.
DROP VIEW IF EXISTS analytics.v_rfm CASCADE;
CREATE VIEW analytics.v_rfm AS
WITH base AS (
  SELECT customer_unique_id, n_occasions, gmv,
         (DATE '2018-08-23' - last_order_at::date) AS recency_days
  FROM analytics.customers WHERE last_order_at <= TIMESTAMP '2018-08-22 23:59:59'
), scored AS (
  SELECT *, ntile(5) OVER (ORDER BY recency_days DESC, customer_unique_id) AS r_score,
            ntile(5) OVER (ORDER BY gmv, customer_unique_id) AS m_score,
            CASE WHEN n_occasions > 1 THEN 1 ELSE 0 END AS f_repeat
  FROM base
)
SELECT *, CASE
    WHEN f_repeat = 1 AND m_score >= 4              THEN '1 Loyal high value'
    WHEN f_repeat = 1                               THEN '2 Loyal standard'
    WHEN r_score >= 4 AND m_score >= 4              THEN '3 Recent high value, one order'
    WHEN r_score >= 4                               THEN '4 Recent standard, one order'
    WHEN m_score >= 4                               THEN '5 Lapsed high value'
    ELSE                                                 '6 Lapsed standard' END AS segment
FROM scored;

DROP VIEW IF EXISTS analytics.v_rfm_summary;
CREATE VIEW analytics.v_rfm_summary AS
SELECT segment, count(*) AS customers, round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct_customers,
       sum(gmv) AS gmv, round(100.0 * sum(gmv) / sum(sum(gmv)) OVER (), 1) AS pct_gmv,
       round(avg(gmv), 2) AS avg_gmv, round(avg(recency_days)) AS avg_recency_days
FROM analytics.v_rfm GROUP BY 1;
