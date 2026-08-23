-- =========================================================
-- DIM_PRODUCTS
-- Grain: one row per product_id.
-- Fixes the "lenght" typo carried in the source CSV headers,
-- casts numeric fields out of the staging VARCHARs, and
-- resolves the category name to English via a lookup join,
-- falling back to the raw Portuguese name and finally to
-- 'unknown' when neither is available.
-- =========================================================

CREATE TABLE IF NOT EXISTS dim_products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

INSERT INTO dim_products (
    product_id,
    product_category_name,
    product_category_name_english,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    p.product_id,
    p.product_category_name,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS product_category_name_english,
    CAST(NULLIF(p.product_name_lenght, '') AS UNSIGNED) AS product_name_length,
    CAST(NULLIF(p.product_description_lenght, '') AS UNSIGNED) AS product_description_length,
    CAST(NULLIF(p.product_photos_qty, '') AS UNSIGNED) AS product_photos_qty,
    CAST(NULLIF(p.product_weight_g, '') AS UNSIGNED) AS product_weight_g,
    CAST(NULLIF(p.product_length_cm, '') AS UNSIGNED) AS product_length_cm,
    CAST(NULLIF(p.product_height_cm, '') AS UNSIGNED) AS product_height_cm,
    CAST(NULLIF(p.product_width_cm, '') AS UNSIGNED) AS product_width_cm
FROM stg_products p
LEFT JOIN stg_category_translation t
    ON p.product_category_name = t.product_category_name;

-- Reconciliation: staging row count should equal dimension row count
SELECT
    (SELECT COUNT(*) FROM stg_products) AS stg_count,
    (SELECT COUNT(*) FROM dim_products) AS dim_count;
