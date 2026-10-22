# Change 1: rename orders.total

Kind: a proposed change, no code yet. Environment: Local (`data/shop.db`). The block below is the hand-off block
from `agentd-diagnose`.

Confidence: confirmed
Task: A new `discount_total` column is planned for `orders`, and the name `total` would then be unclear. Rename the column `orders.total` to `grand_total`, and rename the API field `total` to `grand_total` in the JSON that `GET /orders` returns. "Fixed" means the orders table has `grand_total` and no `total`, the API returns `grand_total`, and the unit tests pass.
Root cause: Not a defect. The name is set in three places: `migrations/0001_create_customers_and_orders.sql:11` creates the column, `shop/api.py:15` selects it, and `shop/api.py:10` (`order_to_dict`) copies it into the JSON field `total`. Evidence: `python3 -m shop orders 1` prints `"total": 9.75` for order 1.
Failing test first: in `tests/test_api.py`, add `test_order_to_dict_uses_grand_total`. It builds the in-memory database from the migrations, inserts order 1 with the amount 25.5, calls `api.order_to_dict` on the row, and asserts that the result holds `"grand_total": 25.5` and has no `"total"` key. It fails now: the result has `total` and no `grand_total`.
Proposed fix: Add `migrations/0004_rename_total.sql` holding `ALTER TABLE orders RENAME COLUMN total TO grand_total;`. In `shop/api.py`, select `grand_total` (line 15) and build the field `grand_total` from it (line 10). Update the expected dict in `tests/test_api.py:25`.
Do not change: the `order_items` table, the `id`, `customer_id`, `placed_at` and `status` fields, and the amounts.
Risk areas: callers of order_to_dict: shop/api.py and tests/test_api.py
Verification: `python3 -m unittest discover -s tests` prints `Ran 15 tests` and `OK` before the change, and `Ran 16 tests` and `OK` after it. On a data/shop.db rebuilt with `python3 scripts/seed_db.py`, `python3 -m shop orders 1` prints `"total": 9.75` before the change and `"grand_total": 9.75` after it.
Follow-on: none
