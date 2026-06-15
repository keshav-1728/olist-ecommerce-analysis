-- ============================================================
-- SECTION 0: DATA QUALITY CHECK
-- Run these before any analysis to understand what you have
-- ============================================================

-- Check row counts across all tables
SELECT 'orders'     AS table_name, COUNT(*) AS rows FROM orders
UNION ALL
SELECT 'customers',                COUNT(*) FROM customers
UNION ALL
SELECT 'order_items',              COUNT(*) FROM order_items
UNION ALL
SELECT 'payments',                 COUNT(*) FROM payments
UNION ALL
SELECT 'reviews',                  COUNT(*) FROM order_reviews
UNION ALL
SELECT 'products',                 COUNT(*) FROM products
UNION ALL
SELECT 'sellers',                  COUNT(*) FROM sellers;


-- Check order status distribution
-- Important: all revenue analysis should filter to 'delivered' only
SELECT
  order_status,
  COUNT(*) AS order_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS pct
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- Check for nulls in key financial columns
SELECT
  SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END)         AS null_price,
  SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END)  AS null_freight,
  SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END)      AS null_seller
FROM order_items;


-- Understand the customer_id vs customer_unique_id issue
-- customer_id is per-order. One real customer who orders 3 times
-- gets 3 different customer_ids. Always use customer_unique_id
-- for any customer-level analysis.
SELECT
  COUNT(customer_id)        AS total_customer_id_rows,
  COUNT(DISTINCT customer_id) AS distinct_customer_ids,
  COUNT(DISTINCT customer_unique_id) AS distinct_real_customers
FROM customers;


-- ============================================================
-- SECTION 1: REVENUE TREND
-- Monthly revenue and order volume over time
-- ============================================================

SELECT
  strftime('%Y-%m', o.order_purchase_timestamp) AS month,
  COUNT(DISTINCT o.order_id)                     AS total_orders,
  ROUND(SUM(oi.price + oi.freight_value), 2)     AS total_revenue,
  ROUND(AVG(oi.price + oi.freight_value), 2)     AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY month
ORDER BY month ASC;


-- Revenue by product category
-- Tells us which categories are driving the business
SELECT
  p.product_category_name,
  COUNT(DISTINCT oi.order_id)                AS total_orders,
  ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue,
  ROUND(AVG(oi.price), 2)                    AS avg_item_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o   ON oi.order_id   = o.order_id
WHERE o.order_status = 'delivered'
  AND p.product_category_name IS NOT NULL
GROUP BY p.product_category_name
ORDER BY total_revenue DESC
LIMIT 15;


-- ============================================================
-- SECTION 2: REPEAT PURCHASE RATE
-- This is the most important metric in the dataset
-- Uses customer_unique_id, NOT customer_id
-- ============================================================

-- Overall repeat rate
SELECT
  COUNT(DISTINCT customer_unique_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN order_count > 1
    THEN customer_unique_id END)     AS repeat_customers,
  ROUND(
    COUNT(DISTINCT CASE WHEN order_count > 1
      THEN customer_unique_id END) * 100.0
    / COUNT(DISTINCT customer_unique_id), 2
  )                                  AS repeat_rate_pct
FROM (
  SELECT
    c.customer_unique_id,
    COUNT(o.order_id) AS order_count
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
);


-- Order frequency distribution
-- How many customers bought once, twice, three times, etc.
SELECT
  order_count,
  COUNT(*) AS num_customers,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM (
  SELECT
    c.customer_unique_id,
    COUNT(o.order_id) AS order_count
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
)
GROUP BY order_count
ORDER BY order_count ASC;


-- ============================================================
-- SECTION 3: DELIVERY PERFORMANCE vs REVIEW SCORE
-- Tests whether late delivery explains poor satisfaction
-- and therefore poor retention
-- ============================================================

SELECT
  CASE
    WHEN julianday(o.order_delivered_customer_date)
       - julianday(o.order_estimated_delivery_date) <= -3
    THEN '1. Early (3+ days)'
    WHEN julianday(o.order_delivered_customer_date)
       - julianday(o.order_estimated_delivery_date) <= 0
    THEN '2. On time'
    WHEN julianday(o.order_delivered_customer_date)
       - julianday(o.order_estimated_delivery_date) <= 3
    THEN '3. Late (1 to 3 days)'
    ELSE '4. Late (3+ days)'
  END                              AS delivery_status,
  COUNT(*)                         AS order_count,
  ROUND(AVG(r.review_score), 2)   AS avg_review_score,
  ROUND(
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1
  )                                AS pct_of_orders
FROM orders o
JOIN order_reviews r
  ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_status = 'delivered'
GROUP BY delivery_status
ORDER BY delivery_status ASC;


-- Average days early or late by state
-- Finds which states have the worst delivery performance
SELECT
  c.customer_state,
  COUNT(DISTINCT o.order_id)                          AS total_orders,
  ROUND(AVG(
    julianday(o.order_delivered_customer_date)
    - julianday(o.order_estimated_delivery_date)
  ), 2)                                               AS avg_days_vs_estimate,
  ROUND(AVG(r.review_score), 2)                       AS avg_review_score
FROM orders o
JOIN customers c    ON o.customer_id  = c.customer_id
JOIN order_reviews r ON o.order_id   = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY avg_days_vs_estimate DESC;


-- ============================================================
-- SECTION 4: SELLER QUALITY ANALYSIS
-- Identifies which sellers are producing the worst experiences
-- ============================================================

-- Overall seller performance summary
SELECT
  oi.seller_id,
  COUNT(DISTINCT oi.order_id)                AS total_orders,
  ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue,
  ROUND(AVG(r.review_score), 2)              AS avg_review_score,
  ROUND(AVG(
    julianday(o.order_delivered_customer_date)
    - julianday(o.order_estimated_delivery_date)
  ), 2)                                      AS avg_days_vs_estimate
FROM order_items oi
JOIN orders o        ON oi.order_id  = o.order_id
JOIN order_reviews r ON oi.order_id  = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY oi.seller_id
ORDER BY avg_review_score ASC;


-- Revenue flowing through bottom 10% of sellers by review score
-- This is revenue at risk from poor customer experience
SELECT
  COUNT(DISTINCT seller_id)                        AS bad_seller_count,
  ROUND(SUM(revenue), 2)                           AS revenue_at_risk,
  ROUND(SUM(revenue) * 100.0 /
    (SELECT SUM(oi2.price + oi2.freight_value)
     FROM order_items oi2
     JOIN orders o2 ON oi2.order_id = o2.order_id
     WHERE o2.order_status = 'delivered'), 2
  )                                                AS pct_of_total_revenue
FROM (
  SELECT
    oi.seller_id,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS revenue,
    ROUND(AVG(r.review_score), 2)              AS avg_review_score
  FROM order_items oi
  JOIN orders o        ON oi.order_id = o.order_id
  JOIN order_reviews r ON oi.order_id = r.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY oi.seller_id
  HAVING avg_review_score <= 3.20
);


-- ============================================================
-- SECTION 5: GEOGRAPHIC REVENUE AND SATISFACTION
-- Which states generate the most revenue vs best experience
-- ============================================================

SELECT
  c.customer_state,
  COUNT(DISTINCT o.order_id)                 AS total_orders,
  ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue,
  ROUND(AVG(r.review_score), 2)              AS avg_review_score,
  ROUND(
    SUM(oi.price + oi.freight_value) * 100.0
    / SUM(SUM(oi.price + oi.freight_value)) OVER (), 2
  )                                          AS revenue_share_pct
FROM orders o
JOIN customers c     ON o.customer_id = c.customer_id
JOIN order_items oi  ON o.order_id    = oi.order_id
JOIN order_reviews r ON o.order_id    = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC
LIMIT 15;


-- ============================================================
-- SECTION 6: PAYMENT BEHAVIOUR
-- Compares installment vs one-shot buyers
-- ============================================================

-- Revenue and order value by payment type
SELECT
  payment_type,
  COUNT(DISTINCT order_id)          AS total_orders,
  ROUND(AVG(payment_value), 2)      AS avg_order_value,
  ROUND(SUM(payment_value), 2)      AS total_revenue,
  ROUND(
    SUM(payment_value) * 100.0
    / SUM(SUM(payment_value)) OVER (), 2
  )                                 AS revenue_share_pct
FROM order_payments
GROUP BY payment_type
ORDER BY total_revenue DESC;


-- Installment vs one-shot buyers on credit card only
-- Shows whether installment customers spend more
SELECT
  CASE
    WHEN payment_installments = 1 THEN 'One-shot payment'
    ELSE 'Installment buyer'
  END                             AS payment_behaviour,
  COUNT(DISTINCT order_id)        AS total_orders,
  ROUND(AVG(payment_value), 2)   AS avg_order_value,
  ROUND(SUM(payment_value), 2)   AS total_revenue
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY payment_behaviour
ORDER BY avg_order_value DESC;


-- ============================================================
-- SECTION 7: RFM BASE TABLE
-- Builds the Recency, Frequency, Monetary scores per customer
-- Scoring and segment labels are applied in Python
-- ============================================================

-- Step 1: Build RFM base (run in Python with pandas after this)
SELECT
  c.customer_unique_id,
  MAX(o.order_purchase_timestamp)                     AS last_purchase_date,
  COUNT(DISTINCT o.order_id)                          AS frequency,
  ROUND(SUM(oi.price + oi.freight_value), 2)          AS monetary
FROM orders o
JOIN customers c   ON o.customer_id  = c.customer_id
JOIN order_items oi ON o.order_id   = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY monetary DESC;
