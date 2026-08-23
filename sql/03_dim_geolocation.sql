-- =========================================================
-- DIM_GEOLOCATION
-- The raw file has multiple lat/lng/city/state rows per zip
-- prefix (repeated submissions at slightly different
-- coordinates). Grain here is collapsed to one row per zip
-- prefix: coordinates are averaged, city/state are picked
-- with MAX() to settle minor spelling/casing conflicts
-- deterministically.
-- =========================================================

CREATE TABLE IF NOT EXISTS dim_geolocation (
    geolocation_zip_code_prefix VARCHAR(10) PRIMARY KEY,
    geolocation_lat DECIMAL(10, 8),
    geolocation_lng DECIMAL(11, 8),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(5)
);

INSERT INTO dim_geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT
    geolocation_zip_code_prefix,
    AVG(CAST(geolocation_lat AS DECIMAL(10, 8))) AS geolocation_lat,
    AVG(CAST(geolocation_lng AS DECIMAL(11, 8))) AS geolocation_lng,
    MAX(geolocation_city) AS geolocation_city,
    MAX(geolocation_state) AS geolocation_state
FROM stg_geolocation
GROUP BY geolocation_zip_code_prefix;
