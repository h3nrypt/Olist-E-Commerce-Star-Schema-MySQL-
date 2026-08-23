# Data Quality Notes

Issues found in the raw data and how each was handled during the build.
Every fix below happens at the dimension/fact insert step — staging
tables keep the raw values untouched, so the original data is always
there to re-check against.

## Source header typos

`olist_products_dataset.csv` ships with `product_name_lenght` and
`product_description_lenght` — the typo is in the source file itself.
Staging keeps the typo (it's a direct column mapping from the CSV), but
`dim_products` corrects it to `product_name_length` /
`product_description_length`. No reason to carry a spelling mistake into
a table meant to be queried and read by other people.

## Category name resolution

Not every `product_category_name` in `stg_products` has a matching row in
`stg_category_translation`. Resolution order in `dim_products`:

1. English translation, if the join finds one
2. Raw Portuguese category name, if no translation exists
3. Literal `'unknown'`, if the category name itself is missing

`COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')`
handles all three in one line rather than leaving unmatched rows as NULL,
which would silently drop them out of any category-level aggregation
downstream.

## Geolocation duplicates

`stg_geolocation` has multiple rows per zip code prefix — repeated
submissions at slightly different lat/lng, and inconsistent
capitalization on city names for the same prefix (`sao paulo` vs
`Sao Paulo`, for example). `dim_geolocation` collapses this to one row
per prefix: `AVG()` on latitude and longitude, `MAX()` on city and state
to get a deterministic pick rather than an arbitrary one. This trades a
small amount of positional precision for a clean one-to-one join target
from customers and sellers.

## Date parsing

All five order lifecycle timestamps arrive as strings in
`%d-%m-%y %H:%i` format, not native MySQL datetimes. Blank strings exist
where an event hasn't happened yet (an order that hasn't shipped has no
`order_delivered_carrier_date`, for instance) — those go through
`NULLIF(..., '')` before `STR_TO_DATE` so they resolve to `NULL` instead
of a parse error or a garbage date.

Before building `dim_date`, the true global min and max across all five
timestamp columns were established with an explicit parse-and-scan query
rather than assumed. That came back as **2016-09-04 to 2018-11-12**,
which is the exact range `dim_date` is generated across — no padding
with unused years on either side.

## Reconciliation checks built into the pipeline

Every load and every dimension/fact build is followed by a count or
sum comparison against its source:

- Staging load: row count per table, checked against known dataset
  sizes.
- `dim_products`: staging row count vs. dimension row count — should
  match one-to-one since grain doesn't change.
- `dim_customers` / `dim_sellers`: same staging-vs-dimension row count
  check.
- `dim_date`: row count and min/max bounds verified after the recursive
  build.
- `fact_order_items`: row count, `SUM(price)`, and `SUM(freight_value)`
  compared between `stg_order_items` and `fact_order_items` — if the
  join to `stg_orders` had dropped or duplicated any rows, the dollar
  totals wouldn't match and it would show immediately.
- Date key mapping: an explicit audit query checks that every non-blank
  timestamp in `stg_orders` maps to a real `date_key` in `dim_date`,
  run both for purchase timestamp alone and across all five lifecycle
  timestamps together.

This pattern — build, then immediately verify against the source before
moving to the next table — is what surfaced the row-count and typo
issues in the first place, rather than finding them later during
analysis.
