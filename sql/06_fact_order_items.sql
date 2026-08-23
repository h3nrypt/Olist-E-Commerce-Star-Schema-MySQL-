-- =========================================================
-- FACT_ORDER_ITEMS
-- Grain: one row per order item (order_id + order_item_id).
-- This is the lowest available grain in the source data —
-- an order with 3 items produces 3 fact rows, each carrying
-- its own price and freight_value. order_status is kept as
-- a degenerate dimension directly on the fact rather than
-- split into its own table, since it's a single low-cardinality
-- attribute of the order, not the item.
-- =========================================================

CREATE TABLE IF NOT EXISTS fact_order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    customer_zip_code_prefix VARCHAR(10),

    -- Foreign keys to dimensions
    customer_key VARCHAR(50),
    product_key VARCHAR(50),
    seller_key VARCHAR(50),

    -- Role-playing date keys (YYYYMMDD), all pointing at dim_date
    purchase_date_key INT,
    approved_date_key INT,
    carrier_delivered_date_key INT,
    customer_delivered_date_key INT,
    estimated_delivery_date_key INT,

    -- Degenerate / operational attribute
    order_status VARCHAR(20),

    -- Additive measures
    price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    freight_value DECIMAL(10,2) NOT NULL DEFAULT 0.00,

    PRIMARY KEY (order_id, order_item_id),

    FOREIGN KEY (purchase_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (approved_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (carrier_delivered_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (customer_delivered_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (estimated_delivery_date_key) REFERENCES dim_date(date_key)
);

INSERT INTO fact_order_items (
    order_id,
    order_item_id,
    customer_key,
    product_key,
    seller_key,
    purchase_date_key,
    approved_date_key,
    carrier_delivered_date_key,
    customer_delivered_date_key,
    estimated_delivery_date_key,
    order_status,
    price,
    freight_value
)
SELECT
    i.order_id,
    CAST(i.order_item_id AS UNSIGNED) AS order_item_id,
    o.customer_id AS customer_key,
    i.product_id AS product_key,
    i.seller_id AS seller_key,
    CAST(DATE_FORMAT(STR_TO_DATE(NULLIF(o.order_purchase_timestamp, ''), '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) AS purchase_date_key,
    CAST(DATE_FORMAT(STR_TO_DATE(NULLIF(o.order_approved_at, ''), '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) AS approved_date_key,
    CAST(DATE_FORMAT(STR_TO_DATE(NULLIF(o.order_delivered_carrier_date, ''), '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) AS carrier_delivered_date_key,
    CAST(DATE_FORMAT(STR_TO_DATE(NULLIF(o.order_delivered_customer_date, ''), '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) AS customer_delivered_date_key,
    CAST(DATE_FORMAT(STR_TO_DATE(NULLIF(o.order_estimated_delivery_date, ''), '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) AS estimated_delivery_date_key,
    o.order_status,
    CAST(i.price AS DECIMAL(10,2)) AS price,
    CAST(i.freight_value AS DECIMAL(10,2)) AS freight_value
FROM stg_order_items i
INNER JOIN stg_orders o ON i.order_id = o.order_id;

-- Verification: row count and total measures
SELECT
    COUNT(*) AS total_fact_rows,
    SUM(price) AS total_revenue,
    SUM(freight_value) AS total_freight
FROM fact_order_items;

-- Reconciliation: staging vs fact, row count and dollar totals must match
SELECT
    'stg_order_items' AS source_table,
    COUNT(*) AS row_count,
    SUM(CAST(price AS DECIMAL(10,2))) AS total_price,
    SUM(CAST(freight_value AS DECIMAL(10,2))) AS total_freight
FROM stg_order_items

UNION ALL

SELECT
    'fact_order_items' AS source_table,
    COUNT(*) AS row_count,
    SUM(price) AS total_price,
    SUM(freight_value) AS total_freight
FROM fact_order_items;
