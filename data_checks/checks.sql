\pset format aligned
\echo == row counts
SELECT 'customers' t,count(*) FROM raw.customers UNION ALL SELECT 'orders',count(*) FROM raw.orders UNION ALL SELECT 'order_items',count(*) FROM raw.order_items UNION ALL SELECT 'order_payments',count(*) FROM raw.order_payments UNION ALL SELECT 'order_reviews',count(*) FROM raw.order_reviews UNION ALL SELECT 'products',count(*) FROM raw.products UNION ALL SELECT 'sellers',count(*) FROM raw.sellers UNION ALL SELECT 'geolocation',count(*) FROM raw.geolocation UNION ALL SELECT 'translation',count(*) FROM raw.category_translation;
\echo == primary key uniqueness (dupes)
SELECT 'orders.order_id' k,count(*)-count(DISTINCT order_id) dupes FROM raw.orders
UNION ALL SELECT 'customers.customer_id',count(*)-count(DISTINCT customer_id) FROM raw.customers
UNION ALL SELECT 'products.product_id',count(*)-count(DISTINCT product_id) FROM raw.products
UNION ALL SELECT 'sellers.seller_id',count(*)-count(DISTINCT seller_id) FROM raw.sellers
UNION ALL SELECT 'reviews.review_id',count(*)-count(DISTINCT review_id) FROM raw.order_reviews
UNION ALL SELECT 'reviews.(review_id,order_id)',count(*)-(SELECT count(*) FROM (SELECT DISTINCT review_id,order_id FROM raw.order_reviews)x) FROM raw.order_reviews
UNION ALL SELECT 'reviews.order_id',count(*)-count(DISTINCT order_id) FROM raw.order_reviews
UNION ALL SELECT 'items.(order_id,item)',count(*)-(SELECT count(*) FROM (SELECT DISTINCT order_id,order_item_id FROM raw.order_items)x) FROM raw.order_items
UNION ALL SELECT 'payments.(order,seq)',count(*)-(SELECT count(*) FROM (SELECT DISTINCT order_id,payment_sequential FROM raw.order_payments)x) FROM raw.order_payments;
\echo == orphans
SELECT 'orders w/o customer' c,count(*) FROM raw.orders o LEFT JOIN raw.customers c USING(customer_id) WHERE c.customer_id IS NULL
UNION ALL SELECT 'items w/o order',count(*) FROM raw.order_items i LEFT JOIN raw.orders o USING(order_id) WHERE o.order_id IS NULL
UNION ALL SELECT 'items w/o product',count(*) FROM raw.order_items i LEFT JOIN raw.products p USING(product_id) WHERE p.product_id IS NULL
UNION ALL SELECT 'items w/o seller',count(*) FROM raw.order_items i LEFT JOIN raw.sellers s USING(seller_id) WHERE s.seller_id IS NULL
UNION ALL SELECT 'payments w/o order',count(*) FROM raw.order_payments i LEFT JOIN raw.orders o USING(order_id) WHERE o.order_id IS NULL
UNION ALL SELECT 'reviews w/o order',count(*) FROM raw.order_reviews i LEFT JOIN raw.orders o USING(order_id) WHERE o.order_id IS NULL
UNION ALL SELECT 'orders w/o items',count(*) FROM raw.orders o WHERE NOT EXISTS(SELECT 1 FROM raw.order_items i WHERE i.order_id=o.order_id)
UNION ALL SELECT 'orders w/o payment',count(*) FROM raw.orders o WHERE NOT EXISTS(SELECT 1 FROM raw.order_payments i WHERE i.order_id=o.order_id)
UNION ALL SELECT 'orders w/o review',count(*) FROM raw.orders o WHERE NOT EXISTS(SELECT 1 FROM raw.order_reviews i WHERE i.order_id=o.order_id)
UNION ALL SELECT 'products no category',count(*) FROM raw.products WHERE product_category_name IS NULL
UNION ALL SELECT 'categories untranslated',count(DISTINCT p.product_category_name) FROM raw.products p LEFT JOIN raw.category_translation t USING(product_category_name) WHERE t.product_category_name IS NULL AND p.product_category_name IS NOT NULL;
\echo == status
SELECT order_status,count(*),count(order_delivered_customer_date) delivered_ts FROM raw.orders GROUP BY 1 ORDER BY 2 DESC;
\echo == customer ids
SELECT count(DISTINCT customer_id) customer_ids,count(DISTINCT customer_unique_id) unique_ids FROM raw.customers;
\echo == date logic
SELECT min(order_purchase_timestamp),max(order_purchase_timestamp) FROM raw.orders;
SELECT count(*) FILTER(WHERE order_delivered_customer_date<order_purchase_timestamp) del_before_purchase,
 count(*) FILTER(WHERE order_approved_at<order_purchase_timestamp) appr_before_purchase,
 count(*) FILTER(WHERE order_delivered_carrier_date<order_approved_at) carrier_before_appr,
 count(*) FILTER(WHERE order_delivered_customer_date<order_delivered_carrier_date) del_before_carrier,
 count(*) FILTER(WHERE order_status='delivered' AND order_delivered_customer_date IS NULL) delivered_no_ts,
 count(*) FILTER(WHERE order_status<>'delivered' AND order_delivered_customer_date IS NOT NULL) notdelivered_with_ts
FROM raw.orders;
\echo == monthly orders
SELECT to_char(order_purchase_timestamp,'YYYY-MM') m,count(*) FROM raw.orders GROUP BY 1 ORDER BY 1;
\echo == payment vs items reconciliation
WITH i AS (SELECT order_id,sum(price+freight_value) v FROM raw.order_items GROUP BY 1), p AS (SELECT order_id,sum(payment_value) v FROM raw.order_payments GROUP BY 1)
SELECT count(*) n, count(*) FILTER(WHERE abs(i.v-p.v)<=0.05) match_5c, count(*) FILTER(WHERE abs(i.v-p.v)>1) off_gt_1, round(sum(i.v),2) items_total, round(sum(p.v),2) pay_total, round(sum(p.v-i.v) FILTER (WHERE abs(i.v-p.v)>1),2) diff_large FROM i JOIN p USING(order_id);
SELECT count(*) zero_or_null_payment FROM raw.order_payments WHERE payment_value=0; SELECT payment_type,count(*) FROM raw.order_payments GROUP BY 1;
SELECT count(*) FILTER(WHERE price<=0) bad_price, count(*) FILTER(WHERE freight_value<0) bad_freight, count(*) FILTER(WHERE freight_value=0) zero_freight, max(price) maxp, max(freight_value) maxf FROM raw.order_items;
