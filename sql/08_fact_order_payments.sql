-- =========================================================
-- FACT_ORDER_PAYMENTS
-- Grain: one row per order per payment_sequential.
-- Deliberately separate from fact_order_items — an order can
-- carry multiple payment rows (split across payment methods,
-- or installments logged as separate sequences), and that
-- doesn't collapse cleanly onto the order-item grain. Forcing
-- payments into fact_order_items would have meant duplicating
-- price/freight across payment rows or duplicating payment
-- values across item rows. Different grain, different fact
-- table.
--
-- customer_key and purchase_date_key are pulled in via a join
-- to stg_orders so this fact can be sliced the same way as
-- fact_order_items (by customer, by date) without forcing an
-- extra hop through a separate orders table that doesn't
-- otherwise exist in this model.
-- =========================================================

CREATE TABLE IF NOT EXISTS fact_order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,

    -- Foreign keys
    customer_key VARCHAR(50),
    purchase_date_key INT,

    -- Degenerate attributes — payment_type is low cardinality
    -- (credit_card, boleto, voucher, debit_card, not_defined),
    -- same reasoning as order_status on fact_order_items: not
    -- worth a separate dimension table for five possible values
    payment_type VARCHAR(30),
    payment_installments INT,

    -- Additive measure
    payment_value DECIMAL(10,2) NOT NULL DEFAULT 0.00,

    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (purchase_date_key) REFERENCES dim_date(date_key)
);

INSERT INTO fact_order_payments (
    order_id,
    payment_sequential,
    customer_key,
    purchase_date_key,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    p.order_id,
    CAST(p.payment_sequential AS UNSIGNED) AS payment_sequential,
    o.customer_id AS customer_key,
    CAST(DATE_FORMAT(STR_TO_DATE(NULLIF(o.order_purchase_timestamp, ''), '%d-%m-%y %H:%i'), '%Y%m%d') AS UNSIGNED) AS purchase_date_key,
    p.payment_type,
    CAST(NULLIF(p.payment_installments, '') AS UNSIGNED) AS payment_installments,
    CAST(p.payment_value AS DECIMAL(10,2)) AS payment_value
FROM stg_order_payments p
INNER JOIN stg_orders o ON p.order_id = o.order_id;

-- Verification: row count and total measure
SELECT
    COUNT(*) AS total_fact_rows,
    SUM(payment_value) AS total_payment_value
FROM fact_order_payments;

-- Reconciliation: staging vs fact, row count and dollar total must match
SELECT
    'stg_order_payments' AS source_table,
    COUNT(*) AS row_count,
    SUM(CAST(payment_value AS DECIMAL(10,2))) AS total_payment_value
FROM stg_order_payments

UNION ALL

SELECT
    'fact_order_payments' AS source_table,
    COUNT(*) AS row_count,
    SUM(payment_value) AS total_payment_value
FROM fact_order_payments;

-- Audit: any payment rows whose order_id has no match in stg_orders
-- (would silently vanish through the INNER JOIN above if present)
SELECT COUNT(*) AS orphaned_payment_rows
FROM stg_order_payments p
LEFT JOIN stg_orders o ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Cross-check: does fact_order_payments total reconcile against
-- fact_order_items total at the order level? Payment value should
-- roughly track price + freight per order, not per item — this
-- confirms the two facts are consistent with each other despite
-- living at different grains.
SELECT
    i.order_id,
    SUM(i.price + i.freight_value) AS items_total,
    pay.payments_total,
    SUM(i.price + i.freight_value) - pay.payments_total AS difference
FROM fact_order_items i
JOIN (
    SELECT order_id, SUM(payment_value) AS payments_total
    FROM fact_order_payments
    GROUP BY order_id
) pay ON i.order_id = pay.order_id
GROUP BY i.order_id, pay.payments_total
HAVING ABS(difference) > 0.01
LIMIT 20;

-- Indexes
CREATE INDEX idx_payments_customer ON fact_order_payments(customer_key);
CREATE INDEX idx_payments_date ON fact_order_payments(purchase_date_key);
