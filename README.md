# Olist E-Commerce Star Schema (MySQL)

A dimensional model built in MySQL on top of the Olist Brazilian
E-Commerce Public Dataset — raw CSVs taken through a staging layer into a
star schema, with a role-playing date dimension and reconciliation
checks at every build step.

## Why this dataset

Olist is a multi-seller marketplace dataset with real messiness built
in: string-typed dates in a non-standard format, duplicate geolocation
rows per zip code, a typo in the source column headers, and category
names that don't all have an English translation. It's a better test of
staging discipline and dimensional design than a dataset that's already
clean.

## Scope of this phase

Eight of the nine source tables are modeled here: customers, orders,
order items, payments, products, sellers, geolocation, and category
translation. Reviews is left out of this phase entirely. See
[`docs/data-model.md`](docs/data-model.md) for the reasoning on reviews.

Business questions and analysis on top of this model are a separate,
follow-up phase — this repo is the design and build.

## Architecture

```
CSV files  →  staging (stg_*)  →  dimensions (dim_*)  →  fact (fact_order_items)
```

- **8 staging tables** — one per source CSV, all VARCHAR, no typing
  applied yet.
- **5 dimension tables** — `dim_products`, `dim_customers`,
  `dim_sellers`, `dim_geolocation`, `dim_date`.
- **2 fact tables** — `fact_order_items` (grain: one row per order item,
  five foreign keys into `dim_date` for the order lifecycle stages) and
  `fact_order_payments` (grain: one row per order per payment
  sequential). A fact constellation, not a single star — the two facts
  share `dim_customers` and `dim_date` as conformed dimensions, each
  sitting at the grain its own source data actually supports.

Full schema and design reasoning: [`docs/data-model.md`](docs/data-model.md)
Data quality issues and how they were resolved: [`docs/data-quality-notes.md`](docs/data-quality-notes.md)

## Repo structure

```
sql/
  01_staging_tables.sql              staging DDL + LOAD DATA + row count check
  02_dim_products.sql                dim_products build + reconciliation
  03_dim_geolocation.sql             dim_geolocation build (dedup by zip prefix)
  04_dim_customers_and_sellers.sql   dim_customers + dim_sellers build
  05_dim_date.sql                    dim_date build (recursive CTE) + audits
  06_fact_order_items.sql            fact_order_items build + reconciliation
  07_indexes.sql                     fact_order_items indexes
  08_fact_order_payments.sql         fact_order_payments build + reconciliation + indexes
docs/
  data-model.md                      schema, ERD, design decisions
  data-quality-notes.md              issues found and how each was fixed
```

Scripts are numbered in build order — staging first, then dimensions,
then the fact table, then indexes. Run them in sequence.

## Tools

MySQL 8 (recursive CTEs, window-function-eligible syntax throughout).
CSVs loaded via `LOAD DATA LOCAL INFILE`.

## Notes

This is a companion piece to an earlier project,
[`superstore-star-schema-mysql-powerbi`](https://github.com/h3nrypt/superstore-star-schema-mysql-powerbi) —
same dimensional modeling approach, different dataset and a different
set of data quality problems to solve.
