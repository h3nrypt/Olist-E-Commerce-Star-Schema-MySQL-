-- =========================================================
-- INDEXES
-- Added on the fact table's foreign key columns after load —
-- indexing before the bulk insert would have slowed the
-- write with no benefit, since nothing was querying the
-- table yet.
-- =========================================================

CREATE INDEX idx_purchase_date ON fact_order_items(purchase_date_key);
CREATE INDEX idx_customer ON fact_order_items(customer_key);
CREATE INDEX idx_product ON fact_order_items(product_key);
CREATE INDEX idx_seller ON fact_order_items(seller_key);
