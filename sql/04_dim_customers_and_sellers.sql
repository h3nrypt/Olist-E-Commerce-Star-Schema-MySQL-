-- =========================================================
-- DIM_CUSTOMERS / DIM_SELLERS
-- Grain: one row per customer_id / seller_id.
-- Both are enriched with latitude/longitude by joining to
-- dim_geolocation on zip prefix. This is a deliberate
-- denormalization — geolocation is folded straight into the
-- customer and seller dimensions instead of leaving the fact
-- table to join out to a third dimension for coordinates,
-- since geo enrichment is only ever consumed at the
-- customer/seller level in this model, not at the order-item
-- grain.
-- =========================================================

CREATE TABLE IF NOT EXISTS dim_customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state VARCHAR(5),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8)
);

INSERT INTO dim_customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    latitude,
    longitude
)
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    g.geolocation_lat AS latitude,
    g.geolocation_lng AS longitude
FROM stg_customers c
LEFT JOIN dim_geolocation g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix;

CREATE TABLE IF NOT EXISTS dim_sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(5),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8)
);

INSERT INTO dim_sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    latitude,
    longitude
)
SELECT
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,
    g.geolocation_lat AS latitude,
    g.geolocation_lng AS longitude
FROM stg_sellers s
LEFT JOIN dim_geolocation g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix;

-- Reconciliation: staging row counts vs dimension row counts
SELECT
    (SELECT COUNT(*) FROM stg_customers) AS stg_cust_cnt,
    (SELECT COUNT(*) FROM dim_customers) AS dim_cust_cnt,
    (SELECT COUNT(*) FROM stg_sellers) AS stg_seller_cnt,
    (SELECT COUNT(*) FROM dim_sellers) AS dim_seller_cnt;
