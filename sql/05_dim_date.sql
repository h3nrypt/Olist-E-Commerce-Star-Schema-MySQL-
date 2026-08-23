-- =========================================================
-- DIM_DATE
-- Role-playing date dimension. The fact table references it
-- five separate times (purchase, approved, carrier delivery,
-- customer delivery, estimated delivery) with a single
-- physical table and five differently-named foreign keys.
--
-- Source timestamps arrive as strings in '%d-%m-%y %H:%i'
-- format, so the true min/max are established first with
-- explicit STR_TO_DATE parsing before the dimension is
-- generated — this avoids either truncating real dates or
-- padding the table with years of unused rows.
-- =========================================================

-- Step 1: confirm the true global min/max across all five
-- lifecycle timestamp columns before deciding the date range
SELECT
    MIN(parsed_date) AS true_global_min,
    MAX(parsed_date) AS true_global_max
FROM (
    SELECT STR_TO_DATE(NULLIF(order_purchase_timestamp, ''), '%d-%m-%y %H:%i') AS parsed_date FROM stg_orders
    UNION ALL
    SELECT STR_TO_DATE(NULLIF(order_approved_at, ''), '%d-%m-%y %H:%i') FROM stg_orders
    UNION ALL
    SELECT STR_TO_DATE(NULLIF(order_delivered_carrier_date, ''), '%d-%m-%y %H:%i') FROM stg_orders
    UNION ALL
    SELECT STR_TO_DATE(NULLIF(order_delivered_customer_date, ''), '%d-%m-%y %H:%i') FROM stg_orders
    UNION ALL
    SELECT STR_TO_DATE(NULLIF(order_estimated_delivery_date, ''), '%d-%m-%y %H:%i') FROM stg_orders
) combined_dates
WHERE parsed_date IS NOT NULL;

-- Step 2: create the dimension structure
CREATE TABLE IF NOT EXISTS dim_date (
    date_key INT PRIMARY KEY,              -- format: YYYYMMDD
    full_date DATE NOT NULL UNIQUE,
    year INT NOT NULL,
    quarter TINYINT NOT NULL,
    month TINYINT NOT NULL,
    month_name VARCHAR(10) NOT NULL,
    day_of_month TINYINT NOT NULL,
    day_of_week TINYINT NOT NULL,          -- 1 = Sunday, 7 = Saturday
    day_name VARCHAR(10) NOT NULL,
    is_weekend TINYINT NOT NULL
);

-- Step 3: populate across the validated bounds (2016-09-04 to 2018-11-12)
-- using a recursive CTE to walk day by day
INSERT INTO dim_date (
    date_key, full_date, year, quarter, month, month_name,
    day_of_month, day_of_week, day_name, is_weekend
)
WITH RECURSIVE date_range AS (
    SELECT CAST('2016-09-04' AS DATE) AS dt, CAST('2018-11-12' AS DATE) AS max_dt
    UNION ALL
    SELECT DATE_ADD(dt, INTERVAL 1 DAY), max_dt
    FROM date_range
    WHERE dt < max_dt
)
SELECT
    CAST(DATE_FORMAT(dt, '%Y%m%d') AS UNSIGNED) AS date_key,
    dt AS full_date,
    YEAR(dt) AS year,
    QUARTER(dt) AS quarter,
    MONTH(dt) AS month,
    MONTHNAME(dt) AS month_name,
    DAYOFMONTH(dt) AS day_of_month,
    DAYOFWEEK(dt) AS day_of_week,
    DAYNAME(dt) AS day_name,
    IF(DAYOFWEEK(dt) IN (1, 7), 1, 0) AS is_weekend
FROM date_range;

-- Step 4: verify row count and bounds landed as expected
SELECT
    COUNT(*) AS total_records,
    MIN(full_date) AS min_date,
    MAX(full_date) AS max_date
FROM dim_date;

-- Step 5: audit — confirm every purchase timestamp maps to a valid date_key
SELECT
    COUNT(*) AS unmapped_orders
FROM stg_orders s
LEFT JOIN dim_date d
    ON CAST(DATE_FORMAT(STR_TO_DATE(NULLIF(s.order_purchase_timestamp, ''), '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) = d.date_key
WHERE d.date_key IS NULL
  AND NULLIF(s.order_purchase_timestamp, '') IS NOT NULL;

-- Step 6: same audit extended across all five lifecycle timestamps at once
SELECT
    SUM(CASE WHEN s.order_purchase_timestamp IS NOT NULL AND d1.date_key IS NULL THEN 1 ELSE 0 END) AS unmapped_purchases,
    SUM(CASE WHEN s.order_approved_at IS NOT NULL AND d2.date_key IS NULL THEN 1 ELSE 0 END) AS unmapped_approvals,
    SUM(CASE WHEN s.order_delivered_carrier_date IS NOT NULL AND d3.date_key IS NULL THEN 1 ELSE 0 END) AS unmapped_carrier_deliveries,
    SUM(CASE WHEN s.order_delivered_customer_date IS NOT NULL AND d4.date_key IS NULL THEN 1 ELSE 0 END) AS unmapped_customer_deliveries,
    SUM(CASE WHEN s.order_estimated_delivery_date IS NOT NULL AND d5.date_key IS NULL THEN 1 ELSE 0 END) AS unmapped_estimates
FROM (
    SELECT
        NULLIF(order_purchase_timestamp, '') AS order_purchase_timestamp,
        NULLIF(order_approved_at, '') AS order_approved_at,
        NULLIF(order_delivered_carrier_date, '') AS order_delivered_carrier_date,
        NULLIF(order_delivered_customer_date, '') AS order_delivered_customer_date,
        NULLIF(order_estimated_delivery_date, '') AS order_estimated_delivery_date
    FROM stg_orders
) s
LEFT JOIN dim_date d1 ON CAST(DATE_FORMAT(STR_TO_DATE(s.order_purchase_timestamp, '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) = d1.date_key
LEFT JOIN dim_date d2 ON CAST(DATE_FORMAT(STR_TO_DATE(s.order_approved_at, '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) = d2.date_key
LEFT JOIN dim_date d3 ON CAST(DATE_FORMAT(STR_TO_DATE(s.order_delivered_carrier_date, '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) = d3.date_key
LEFT JOIN dim_date d4 ON CAST(DATE_FORMAT(STR_TO_DATE(s.order_delivered_customer_date, '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) = d4.date_key
LEFT JOIN dim_date d5 ON CAST(DATE_FORMAT(STR_TO_DATE(s.order_estimated_delivery_date, '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) = d5.date_key;
