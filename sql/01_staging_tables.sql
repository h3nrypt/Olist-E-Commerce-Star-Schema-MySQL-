-- =========================================================
-- STAGING LAYER
-- All columns typed as VARCHAR on purpose — the raw CSVs
-- carry blanks, inconsistent date formats, and numeric
-- fields that break on cast during load. Typing is enforced
-- later, at the dimension/fact insert stage, once NULLIF
-- and STR_TO_DATE have had a chance to clean the values.
-- =========================================================

USE olist_dataset;

CREATE TABLE IF NOT EXISTS stg_customers (
    customer_id VARCHAR(255),
    customer_unique_id VARCHAR(255),
    customer_zip_code_prefix VARCHAR(255),
    customer_city VARCHAR(255),
    customer_state VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS stg_order_items (
    order_id VARCHAR(255),
    order_item_id VARCHAR(255),
    product_id VARCHAR(255),
    seller_id VARCHAR(255),
    shipping_limit_date VARCHAR(255),
    price VARCHAR(255),
    freight_value VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS stg_order_payments (
    order_id VARCHAR(255),
    payment_sequential VARCHAR(255),
    payment_type VARCHAR(255),
    payment_installments VARCHAR(255),
    payment_value VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS stg_orders (
    order_id VARCHAR(255),
    customer_id VARCHAR(255),
    order_status VARCHAR(255),
    order_purchase_timestamp VARCHAR(255),
    order_approved_at VARCHAR(255),
    order_delivered_carrier_date VARCHAR(255),
    order_delivered_customer_date VARCHAR(255),
    order_estimated_delivery_date VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS stg_products (
    product_id VARCHAR(255),
    product_category_name VARCHAR(255),
    product_name_lenght VARCHAR(255),        -- typo preserved from source file
    product_description_lenght VARCHAR(255), -- typo preserved from source file
    product_photos_qty VARCHAR(255),
    product_weight_g VARCHAR(255),
    product_length_cm VARCHAR(255),
    product_height_cm VARCHAR(255),
    product_width_cm VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS stg_sellers (
    seller_id VARCHAR(255),
    seller_zip_code_prefix VARCHAR(255),
    seller_city VARCHAR(255),
    seller_state VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS stg_category_translation (
    product_category_name VARCHAR(255),
    product_category_name_english VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS stg_geolocation (
    geolocation_zip_code_prefix VARCHAR(255),
    geolocation_lat VARCHAR(255),
    geolocation_lng VARCHAR(255),
    geolocation_city VARCHAR(255),
    geolocation_state VARCHAR(255)
);

-- Required for LOCAL INFILE loads on a fresh MySQL session
SET GLOBAL local_infile = 1;

-- 1. Customers
LOAD DATA LOCAL INFILE 'D:/SQL DATESETS/Brazilian E-Commerce Public Dataset by Olist/olist_customers_dataset.csv'
INTO TABLE stg_customers
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 2. Category translation
LOAD DATA LOCAL INFILE 'D:/SQL DATESETS/Brazilian E-Commerce Public Dataset by Olist/product_category_name_translation.csv'
INTO TABLE stg_category_translation
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 3. Orders
LOAD DATA LOCAL INFILE 'D:/SQL DATESETS/Brazilian E-Commerce Public Dataset by Olist/olist_orders_dataset.csv'
INTO TABLE stg_orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 4. Order items
LOAD DATA LOCAL INFILE 'D:/SQL DATESETS/Brazilian E-Commerce Public Dataset by Olist/olist_order_items_dataset.csv'
INTO TABLE stg_order_items
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 5. Order payments
LOAD DATA LOCAL INFILE 'D:/SQL DATESETS/Brazilian E-Commerce Public Dataset by Olist/olist_order_payments_dataset.csv'
INTO TABLE stg_order_payments
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 6. Products
LOAD DATA LOCAL INFILE 'D:/SQL DATESETS/Brazilian E-Commerce Public Dataset by Olist/olist_products_dataset.csv'
INTO TABLE stg_products
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 7. Sellers
LOAD DATA LOCAL INFILE 'D:/SQL DATESETS/Brazilian E-Commerce Public Dataset by Olist/olist_sellers_dataset.csv'
INTO TABLE stg_sellers
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- 8. Geolocation
LOAD DATA LOCAL INFILE 'D:/SQL DATESETS/Brazilian E-Commerce Public Dataset by Olist/olist_geolocation_dataset.csv'
INTO TABLE stg_geolocation
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Load verification — row count per staging table
SELECT 'stg_customers' AS table_name, COUNT(*) AS total_rows FROM stg_customers
UNION ALL
SELECT 'stg_category_translation', COUNT(*) FROM stg_category_translation
UNION ALL
SELECT 'stg_orders', COUNT(*) FROM stg_orders
UNION ALL
SELECT 'stg_order_items', COUNT(*) FROM stg_order_items
UNION ALL
SELECT 'stg_order_payments', COUNT(*) FROM stg_order_payments
UNION ALL
SELECT 'stg_products', COUNT(*) FROM stg_products
UNION ALL
SELECT 'stg_sellers', COUNT(*) FROM stg_sellers
UNION ALL
SELECT 'stg_geolocation', COUNT(*) FROM stg_geolocation;
