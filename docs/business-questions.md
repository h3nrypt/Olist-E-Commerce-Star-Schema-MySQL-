# Business Questions & Analysis Queries

This document contains 30 key business questions that can be answered using the Olist star schema, with SQL code for each.

---

## **Revenue & Sales Performance**

### 1. Total Revenue by Time Period (Monthly, Quarterly, Yearly)

```sql
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(*) AS total_items,
    SUM(f.price) AS total_price,
    SUM(f.freight_value) AS total_freight,
    SUM(f.price + f.freight_value) AS total_revenue
FROM fact_order_items f
JOIN dim_date d ON f.purchase_date_key = d.date_key
WHERE f.order_status NOT IN ('cancelled')
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year DESC, d.month DESC;
```

### 2. Revenue by Product Category

```sql
SELECT
    p.product_category_name_english,
    p.product_category_name,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    SUM(f.price) AS total_price,
    SUM(f.freight_value) AS total_freight,
    SUM(f.price + f.freight_value) AS total_revenue,
    ROUND(AVG(f.price), 2) AS avg_item_price,
    ROUND(SUM(f.price + f.freight_value) / COUNT(DISTINCT f.order_id), 2) AS avg_order_value
FROM fact_order_items f
JOIN dim_products p ON f.product_key = p.product_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY p.product_id, p.product_category_name_english, p.product_category_name
ORDER BY total_revenue DESC;
```

### 3. Revenue by Seller

```sql
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    SUM(f.price) AS total_price,
    SUM(f.freight_value) AS total_freight,
    SUM(f.price + f.freight_value) AS total_revenue,
    ROUND(AVG(f.price), 2) AS avg_item_price,
    ROUND(SUM(f.price + f.freight_value) / COUNT(DISTINCT f.order_id), 2) AS avg_order_value
FROM fact_order_items f
JOIN dim_sellers s ON f.seller_key = s.seller_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY f.seller_key, s.seller_city, s.seller_state
ORDER BY total_revenue DESC
LIMIT 50;
```

### 4. Average Order Value by Customer, Category, and Seller

```sql
SELECT
    'by_customer' AS segment_type,
    c.customer_id AS segment_id,
    c.customer_city AS segment_detail,
    COUNT(DISTINCT f.order_id) AS order_count,
    ROUND(SUM(f.price + f.freight_value) / COUNT(DISTINCT f.order_id), 2) AS avg_order_value,
    SUM(f.price + f.freight_value) AS total_spend
FROM fact_order_items f
JOIN dim_customers c ON f.customer_key = c.customer_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY c.customer_id, c.customer_city

UNION ALL

SELECT
    'by_category' AS segment_type,
    p.product_category_name_english AS segment_id,
    p.product_category_name AS segment_detail,
    COUNT(DISTINCT f.order_id) AS order_count,
    ROUND(SUM(f.price + f.freight_value) / COUNT(DISTINCT f.order_id), 2) AS avg_order_value,
    SUM(f.price + f.freight_value) AS total_spend
FROM fact_order_items f
JOIN dim_products p ON f.product_key = p.product_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY p.product_category_name_english, p.product_category_name

UNION ALL

SELECT
    'by_seller' AS segment_type,
    s.seller_id AS segment_id,
    s.seller_city AS segment_detail,
    COUNT(DISTINCT f.order_id) AS order_count,
    ROUND(SUM(f.price + f.freight_value) / COUNT(DISTINCT f.order_id), 2) AS avg_order_value,
    SUM(f.price + f.freight_value) AS total_spend
FROM fact_order_items f
JOIN dim_sellers s ON f.seller_key = s.seller_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY f.seller_key, s.seller_city

ORDER BY segment_type, avg_order_value DESC;
```

### 5. Payment Method Analysis

```sql
SELECT
    fp.payment_type,
    COUNT(DISTINCT fp.order_id) AS total_orders,
    COUNT(*) AS total_payments,
    SUM(fp.payment_value) AS total_payment_value,
    ROUND(AVG(fp.payment_value), 2) AS avg_payment_value,
    ROUND(AVG(fp.payment_installments), 2) AS avg_installments,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM fact_order_payments), 2) AS pct_of_total
FROM fact_order_payments fp
GROUP BY fp.payment_type
ORDER BY total_payment_value DESC;
```

---

## **Customer Insights**

### 6. Customer Acquisition Over Time

```sql
SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(DISTINCT f.customer_key) AS new_customer_acquisitions,
    COUNT(DISTINCT f.order_id) AS orders_in_month
FROM fact_order_items f
JOIN dim_date d ON f.purchase_date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;
```

### 7. Customer Retention & Repeat Purchase Rate

```sql
WITH customer_purchases AS (
    SELECT
        f.customer_key,
        COUNT(DISTINCT f.order_id) AS purchase_count,
        MIN(DATE(CONCAT(d.year, '-', LPAD(d.month, 2, '0'), '-', LPAD(d.day_of_month, 2, '0')))) AS first_purchase_date,
        MAX(DATE(CONCAT(d.year, '-', LPAD(d.month, 2, '0'), '-', LPAD(d.day_of_month, 2, '0')))) AS last_purchase_date
    FROM fact_order_items f
    JOIN dim_date d ON f.purchase_date_key = d.date_key
    WHERE f.order_status NOT IN ('cancelled')
    GROUP BY f.customer_key
)
SELECT
    CASE
        WHEN purchase_count = 1 THEN 'One-time'
        WHEN purchase_count BETWEEN 2 AND 5 THEN '2-5 purchases'
        WHEN purchase_count BETWEEN 6 AND 10 THEN '6-10 purchases'
        ELSE '11+ purchases'
    END AS customer_segment,
    COUNT(*) AS customer_count,
    ROUND(100 * COUNT(*) / (SELECT COUNT(DISTINCT customer_key) FROM fact_order_items), 2) AS pct_of_customers,
    ROUND(AVG(purchase_count), 2) AS avg_purchases_per_customer
FROM customer_purchases
GROUP BY customer_segment
ORDER BY customer_count DESC;
```

### 8. Geographic Customer Distribution

```sql
SELECT
    c.customer_state,
    c.customer_city,
    COUNT(DISTINCT c.customer_id) AS unique_customers,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.price + f.freight_value) AS total_revenue,
    ROUND(c.latitude, 4) AS latitude,
    ROUND(c.longitude, 4) AS longitude
FROM fact_order_items f
JOIN dim_customers c ON f.customer_key = c.customer_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY c.customer_state, c.customer_city, c.latitude, c.longitude
ORDER BY total_revenue DESC;
```

### 9. Customer Lifetime Value

```sql
SELECT
    c.customer_id,
    c.customer_city,
    c.customer_state,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.price + f.freight_value) AS lifetime_value,
    ROUND(AVG(f.price + f.freight_value), 2) AS avg_order_value,
    MAX(DATE(CONCAT(d.year, '-', LPAD(d.month, 2, '0'), '-', LPAD(d.day_of_month, 2, '0')))) AS last_purchase_date
FROM fact_order_items f
JOIN dim_customers c ON f.customer_key = c.customer_id
JOIN dim_date d ON f.purchase_date_key = d.date_key
WHERE f.order_status NOT IN ('cancelled')
GROUP BY c.customer_id, c.customer_city, c.customer_state
ORDER BY lifetime_value DESC
LIMIT 100;
```

### 10. Customer Churn Analysis

```sql
WITH customer_dates AS (
    SELECT
        f.customer_key,
        MAX(DATE(CONCAT(d.year, '-', LPAD(d.month, 2, '0'), '-', LPAD(d.day_of_month, 2, '0')))) AS last_purchase_date
    FROM fact_order_items f
    JOIN dim_date d ON f.purchase_date_key = d.date_key
    WHERE f.order_status NOT IN ('cancelled')
    GROUP BY f.customer_key
)
SELECT
    CASE
        WHEN DATEDIFF(CURDATE(), last_purchase_date) < 30 THEN 'Active (0-30 days)'
        WHEN DATEDIFF(CURDATE(), last_purchase_date) < 90 THEN 'At Risk (31-90 days)'
        WHEN DATEDIFF(CURDATE(), last_purchase_date) < 180 THEN 'Dormant (91-180 days)'
        ELSE 'Churned (180+ days)'
    END AS customer_status,
    COUNT(*) AS customer_count,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM customer_dates), 2) AS pct_of_customers
FROM customer_dates
GROUP BY customer_status
ORDER BY customer_count DESC;
```

---

## **Operational & Fulfillment Metrics**

### 11. Order Status Distribution

```sql
SELECT
    f.order_status,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(*) AS total_items,
    SUM(f.price + f.freight_value) AS total_revenue,
    ROUND(100 * COUNT(DISTINCT f.order_id) / (SELECT COUNT(DISTINCT order_id) FROM fact_order_items), 2) AS pct_of_orders
FROM fact_order_items f
GROUP BY f.order_status
ORDER BY total_orders DESC;
```

### 12. Delivery Performance (Actual vs. Estimated)

```sql
SELECT
    f.order_id,
    f.order_item_id,
    d_est.full_date AS estimated_delivery_date,
    d_actual.full_date AS actual_delivery_date,
    DATEDIFF(d_actual.full_date, d_est.full_date) AS days_difference,
    CASE
        WHEN DATEDIFF(d_actual.full_date, d_est.full_date) < 0 THEN 'Early'
        WHEN DATEDIFF(d_actual.full_date, d_est.full_date) = 0 THEN 'On Time'
        WHEN DATEDIFF(d_actual.full_date, d_est.full_date) BETWEEN 1 AND 7 THEN 'Late (1-7 days)'
        ELSE 'Late (8+ days)'
    END AS delivery_status,
    f.order_status
FROM fact_order_items f
JOIN dim_date d_est ON f.estimated_delivery_date_key = d_est.date_key
JOIN dim_date d_actual ON f.customer_delivered_date_key = d_actual.date_key
WHERE f.customer_delivered_date_key IS NOT NULL
ORDER BY days_difference DESC
LIMIT 100;
```

### 13. On-Time Delivery Rate

```sql
SELECT
    CASE
        WHEN DATEDIFF(d_actual.full_date, d_est.full_date) <= 0 THEN 'On Time'
        ELSE 'Late'
    END AS delivery_performance,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM fact_order_items WHERE customer_delivered_date_key IS NOT NULL), 2) AS pct_of_delivered
FROM fact_order_items f
JOIN dim_date d_est ON f.estimated_delivery_date_key = d_est.date_key
JOIN dim_date d_actual ON f.customer_delivered_date_key = d_actual.date_key
WHERE f.customer_delivered_date_key IS NOT NULL
GROUP BY delivery_performance;
```

### 14. Fulfillment Cycle Time (Purchase → Approval → Pickup → Delivery)

```sql
SELECT
    f.order_id,
    DATEDIFF(d_approved.full_date, d_purchase.full_date) AS days_to_approve,
    DATEDIFF(d_carrier.full_date, d_approved.full_date) AS days_to_carrier_pickup,
    DATEDIFF(d_delivered.full_date, d_carrier.full_date) AS days_carrier_transit,
    DATEDIFF(d_delivered.full_date, d_purchase.full_date) AS total_fulfillment_days
FROM fact_order_items f
JOIN dim_date d_purchase ON f.purchase_date_key = d_purchase.date_key
JOIN dim_date d_approved ON f.approved_date_key = d_approved.date_key
JOIN dim_date d_carrier ON f.carrier_delivered_date_key = d_carrier.date_key
JOIN dim_date d_delivered ON f.customer_delivered_date_key = d_delivered.date_key
WHERE f.customer_delivered_date_key IS NOT NULL
ORDER BY total_fulfillment_days DESC
LIMIT 100;
```

### 15. Shipping Delays Analysis

```sql
SELECT
    DATEDIFF(d_actual.full_date, d_est.full_date) AS days_late,
    COUNT(DISTINCT f.order_id) AS orders_delayed_by_x_days,
    COUNT(*) AS items,
    ROUND(AVG(f.price + f.freight_value), 2) AS avg_order_value,
    SUM(f.price + f.freight_value) AS total_revenue_at_risk
FROM fact_order_items f
JOIN dim_date d_est ON f.estimated_delivery_date_key = d_est.date_key
JOIN dim_date d_actual ON f.customer_delivered_date_key = d_actual.date_key
WHERE f.customer_delivered_date_key IS NOT NULL
    AND DATEDIFF(d_actual.full_date, d_est.full_date) > 0
GROUP BY days_late
ORDER BY days_late DESC;
```

---

## **Product Performance**

### 16. Top & Bottom Performing Products

```sql
SELECT
    f.product_key,
    p.product_category_name_english,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(*) AS units_sold,
    SUM(f.price) AS total_price,
    SUM(f.freight_value) AS total_freight,
    SUM(f.price + f.freight_value) AS total_revenue,
    ROUND(AVG(f.price), 2) AS avg_price,
    ROW_NUMBER() OVER (ORDER BY SUM(f.price + f.freight_value) DESC) AS revenue_rank
FROM fact_order_items f
JOIN dim_products p ON f.product_key = p.product_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY f.product_key, p.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 50;
```

### 17. Product Category Trends Over Time

```sql
SELECT
    d.year,
    d.month,
    d.month_name,
    p.product_category_name_english,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS units_sold,
    SUM(f.price + f.freight_value) AS revenue,
    ROUND(AVG(f.price), 2) AS avg_price
FROM fact_order_items f
JOIN dim_date d ON f.purchase_date_key = d.date_key
JOIN dim_products p ON f.product_key = p.product_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY d.year, d.month, d.month_name, p.product_category_name_english
ORDER BY d.year DESC, d.month DESC, revenue DESC;
```

### 18. Product Physical Attributes vs. Sales Performance

```sql
SELECT
    p.product_id,
    p.product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_photos_qty,
    COUNT(*) AS units_sold,
    ROUND(AVG(f.price), 2) AS avg_price,
    SUM(f.price + f.freight_value) AS total_revenue
FROM fact_order_items f
JOIN dim_products p ON f.product_key = p.product_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY p.product_id, p.product_category_name_english, p.product_weight_g, 
         p.product_length_cm, p.product_height_cm, p.product_width_cm, p.product_photos_qty
HAVING COUNT(*) > 5
ORDER BY units_sold DESC
LIMIT 50;
```

### 19. Seller Performance by Product Category

```sql
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    p.product_category_name_english,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS units_sold,
    SUM(f.price + f.freight_value) AS revenue,
    ROUND(AVG(f.price), 2) AS avg_price,
    ROUND(100 * SUM(f.price + f.freight_value) / 
          (SELECT SUM(price + freight_value) 
           FROM fact_order_items WHERE product_key IN 
           (SELECT product_id FROM dim_products WHERE product_category_name_english = p.product_category_name_english)
           AND order_status NOT IN ('cancelled')), 2) AS pct_category_market_share
FROM fact_order_items f
JOIN dim_sellers s ON f.seller_key = s.seller_id
JOIN dim_products p ON f.product_key = p.product_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY s.seller_id, s.seller_city, s.seller_state, p.product_category_name_english
ORDER BY revenue DESC
LIMIT 100;
```

---

## **Geographic & Seller Analysis**

### 20. Seller Geographic Concentration and Reach

```sql
SELECT
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT s.seller_id) AS seller_count,
    COUNT(DISTINCT f.customer_key) AS unique_customers_reached,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.price + f.freight_value) AS total_revenue,
    ROUND(AVG(s.latitude), 4) AS avg_latitude,
    ROUND(AVG(s.longitude), 4) AS avg_longitude
FROM fact_order_items f
JOIN dim_sellers s ON f.seller_key = s.seller_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY s.seller_state, s.seller_city
ORDER BY total_revenue DESC;
```

### 21. Seller Reliability (On-Time Delivery & Cancellation Rates)

```sql
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(CASE WHEN f.order_status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    SUM(CASE WHEN f.order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,
    ROUND(100 * SUM(CASE WHEN f.order_status = 'cancelled' THEN 1 ELSE 0 END) / COUNT(DISTINCT f.order_id), 2) AS cancellation_rate,
    ROUND(100 * SUM(CASE WHEN DATEDIFF(d_actual.full_date, d_est.full_date) <= 0 THEN 1 ELSE 0 END) / 
          SUM(CASE WHEN f.customer_delivered_date_key IS NOT NULL THEN 1 ELSE 0 END), 2) AS on_time_delivery_rate
FROM fact_order_items f
JOIN dim_sellers s ON f.seller_key = s.seller_id
LEFT JOIN dim_date d_est ON f.estimated_delivery_date_key = d_est.date_key
LEFT JOIN dim_date d_actual ON f.customer_delivered_date_key = d_actual.date_key
GROUP BY s.seller_id, s.seller_city, s.seller_state
HAVING total_orders > 10
ORDER BY on_time_delivery_rate ASC;
```

### 22. Seller Revenue Scaling

```sql
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(*) AS total_items_sold,
    ROUND(COUNT(*) / COUNT(DISTINCT f.order_id), 2) AS avg_items_per_order,
    SUM(f.price + f.freight_value) AS total_revenue,
    ROUND(SUM(f.price + f.freight_value) / COUNT(DISTINCT f.order_id), 2) AS avg_order_value,
    ROUND(SUM(f.price) / COUNT(*), 2) AS avg_item_price
FROM fact_order_items f
JOIN dim_sellers s ON f.seller_key = s.seller_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY total_revenue DESC;
```

### 23. Fulfillment Cost Analysis (Freight as % of Sale Price)

```sql
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    p.product_category_name_english,
    COUNT(*) AS items_sold,
    ROUND(AVG(f.price), 2) AS avg_item_price,
    ROUND(AVG(f.freight_value), 2) AS avg_freight_cost,
    ROUND(100 * AVG(f.freight_value) / AVG(f.price), 2) AS freight_as_pct_of_price,
    SUM(f.price) AS total_price,
    SUM(f.freight_value) AS total_freight
FROM fact_order_items f
JOIN dim_sellers s ON f.seller_key = s.seller_id
JOIN dim_products p ON f.product_key = p.product_id
WHERE f.order_status NOT IN ('cancelled')
GROUP BY s.seller_id, s.seller_city, s.seller_state, p.product_category_name_english
ORDER BY freight_as_pct_of_price DESC
LIMIT 50;
```

---

## **Payment & Financial Health**

### 24. Payment Value Distribution

```sql
SELECT
    CASE
        WHEN fp.payment_value < 50 THEN 'Under $50'
        WHEN fp.payment_value < 100 THEN '$50-$100'
        WHEN fp.payment_value < 250 THEN '$100-$250'
        WHEN fp.payment_value < 500 THEN '$250-$500'
        ELSE 'Over $500'
    END AS payment_range,
    COUNT(*) AS payment_count,
    COUNT(DISTINCT fp.order_id) AS unique_orders,
    SUM(fp.payment_value) AS total_value,
    ROUND(AVG(fp.payment_value), 2) AS avg_payment_value,
    ROUND(100 * SUM(fp.payment_value) / (SELECT SUM(payment_value) FROM fact_order_payments), 2) AS pct_of_total_revenue
FROM fact_order_payments fp
GROUP BY payment_range
ORDER BY COUNT(*) DESC;
```

### 25. Multi-Payment Orders

```sql
WITH order_payment_count AS (
    SELECT
        order_id,
        COUNT(*) AS payment_count,
        COUNT(DISTINCT payment_type) AS unique_payment_types,
        SUM(payment_value) AS order_total
    FROM fact_order_payments
    GROUP BY order_id
)
SELECT
    CASE
        WHEN payment_count = 1 THEN 'Single Payment'
        WHEN payment_count BETWEEN 2 AND 3 THEN '2-3 Payments'
        ELSE '4+ Payments'
    END AS payment_pattern,
    COUNT(*) AS order_count,
    ROUND(AVG(order_total), 2) AS avg_order_value,
    SUM(order_total) AS total_revenue,
    ROUND(100 * COUNT(*) / (SELECT COUNT(DISTINCT order_id) FROM fact_order_payments), 2) AS pct_of_orders
FROM order_payment_count
GROUP BY payment_pattern
ORDER BY order_count DESC;
```

### 26. Payment Method Risk Analysis

```sql
SELECT
    fp.payment_type,
    COUNT(DISTINCT fp.order_id) AS total_orders,
    COUNT(*) AS total_payment_records,
    SUM(fp.payment_value) AS total_payment_value,
    ROUND(AVG(fp.payment_value), 2) AS avg_payment_value,
    COUNT(DISTINCT CASE WHEN f.order_status = 'delivered' THEN fp.order_id END) AS successful_deliveries,
    COUNT(DISTINCT CASE WHEN f.order_status = 'cancelled' THEN fp.order_id END) AS cancelled_orders,
    ROUND(100 * COUNT(DISTINCT CASE WHEN f.order_status = 'delivered' THEN fp.order_id END) / COUNT(DISTINCT fp.order_id), 2) AS success_rate_pct,
    ROUND(100 * COUNT(DISTINCT CASE WHEN f.order_status = 'cancelled' THEN fp.order_id END) / COUNT(DISTINCT fp.order_id), 2) AS cancellation_rate_pct
FROM fact_order_payments fp
LEFT JOIN fact_order_items f ON fp.order_id = f.order_id
GROUP BY fp.payment_type
ORDER BY total_payment_value DESC;
```

### 27. Installment Analysis

```sql
SELECT
    fp.payment_installments,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT fp.order_id) AS orders,
    SUM(fp.payment_value) AS total_value,
    ROUND(AVG(fp.payment_value), 2) AS avg_installment_value,
    ROUND(AVG(fp.payment_installments), 2) AS avg_installments_per_order,
    ROUND(100 * SUM(fp.payment_value) / (SELECT SUM(payment_value) FROM fact_order_payments WHERE payment_installments IS NOT NULL), 2) AS pct_of_installment_revenue
FROM fact_order_payments fp
WHERE fp.payment_installments IS NOT NULL AND fp.payment_installments > 0
GROUP BY fp.payment_installments
ORDER BY payment_records DESC;
```

---

## **Seasonality & Trends**

### 28. Seasonal Patterns (Day of Week, Month, Quarter)

```sql
SELECT
    'by_day_of_week' AS period_type,
    d.day_name AS period_label,
    NULL AS period_number,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    SUM(f.price + f.freight_value) AS revenue,
    ROUND(AVG(f.price + f.freight_value), 2) AS avg_order_value
FROM fact_order_items f
JOIN dim_date d ON f.purchase_date_key = d.date_key
WHERE f.order_status NOT IN ('cancelled')
GROUP BY d.day_of_week, d.day_name

UNION ALL

SELECT
    'by_month' AS period_type,
    d.month_name AS period_label,
    d.month AS period_number,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    SUM(f.price + f.freight_value) AS revenue,
    ROUND(AVG(f.price + f.freight_value), 2) AS avg_order_value
FROM fact_order_items f
JOIN dim_date d ON f.purchase_date_key = d.date_key
WHERE f.order_status NOT IN ('cancelled')
GROUP BY d.month, d.month_name

UNION ALL

SELECT
    'by_quarter' AS period_type,
    CONCAT('Q', d.quarter, ' ', d.year) AS period_label,
    d.quarter AS period_number,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    SUM(f.price + f.freight_value) AS revenue,
    ROUND(AVG(f.price + f.freight_value), 2) AS avg_order_value
FROM fact_order_items f
JOIN dim_date d ON f.purchase_date_key = d.date_key
WHERE f.order_status NOT IN ('cancelled')
GROUP BY d.quarter, d.year

ORDER BY period_type;
```

### 29. Weekend vs. Weekday Performance

```sql
SELECT
    CASE
        WHEN d.is_weekend = 1 THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
    d.day_name,
    COUNT(DISTINCT f.order_id) AS orders,
    COUNT(*) AS items,
    SUM(f.price + f.freight_value) AS revenue,
    ROUND(AVG(f.price + f.freight_value), 2) AS avg_order_value,
    ROUND(100 * COUNT(DISTINCT f.order_id) / (SELECT COUNT(DISTINCT order_id) FROM fact_order_items WHERE order_status NOT IN ('cancelled')), 2) AS pct_of_total_orders
FROM fact_order_items f
JOIN dim_date d ON f.purchase_date_key = d.date_key
WHERE f.order_status NOT IN ('cancelled')
GROUP BY day_type, d.day_name, d.is_weekend
ORDER BY d.day_of_week;
```

### 30. Trend Breaks & Significant Shifts in Customer Behavior

```sql
WITH monthly_trends AS (
    SELECT
        d.year,
        d.month,
        d.month_name,
        COUNT(DISTINCT f.order_id) AS orders,
        COUNT(DISTINCT f.customer_key) AS unique_customers,
        SUM(f.price + f.freight_value) AS revenue,
        ROUND(SUM(f.price + f.freight_value) / COUNT(DISTINCT f.order_id), 2) AS avg_order_value,
        LAG(SUM(f.price + f.freight_value)) OVER (ORDER BY d.year, d.month) AS prev_month_revenue,
        LAG(COUNT(DISTINCT f.order_id)) OVER (ORDER BY d.year, d.month) AS prev_month_orders
    FROM fact_order_items f
    JOIN dim_date d ON f.purchase_date_key = d.date_key
    WHERE f.order_status NOT IN ('cancelled')
    GROUP BY d.year, d.month, d.month_name
)
SELECT
    year,
    month,
    month_name,
    orders,
    unique_customers,
    revenue,
    avg_order_value,
    ROUND(((revenue - prev_month_revenue) / prev_month_revenue * 100), 2) AS revenue_pct_change,
    ROUND(((orders - prev_month_orders) / prev_month_orders * 100), 2) AS order_volume_pct_change,
    CASE
        WHEN ABS((revenue - prev_month_revenue) / prev_month_revenue * 100) > 20 THEN 'Significant Shift'
        WHEN ABS((orders - prev_month_orders) / prev_month_orders * 100) > 20 THEN 'Volume Shift'
        ELSE 'Normal'
    END AS trend_status
FROM monthly_trends
WHERE prev_month_revenue IS NOT NULL
ORDER BY year DESC, month DESC;
```

---

## Usage Notes

- All queries exclude cancelled orders from revenue calculations where appropriate
- Date handling uses the role-playing `dim_date` foreign keys (purchase, approved, carrier delivery, customer delivery, estimated delivery)
- Queries use `ROUND()` for decimal precision in financial metrics
- Replace `LIMIT` clauses as needed for different result set sizes
- Use these queries as templates for custom analysis — modify WHERE clauses, GROUP BY fields, and metrics as needed
- Consider indexing on frequently-filtered columns (customer_key, seller_key, product_key, date_keys) for large-scale queries
