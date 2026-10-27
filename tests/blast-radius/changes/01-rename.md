# Change 1: rename orders.total

Kind: a proposed change, no code yet. Environment: Local (`data/shop.db`). The block below is the hand-off block
from `agentd-diagnose`.

# Hand-off block

**Confidence:** confirmed

## Task
A new `discount_total` column is planned for `orders`, and the name `total` would then be unclear. Rename the column `orders.total` to `grand_total`, and rename the API field `total` to `grand_total` in the JSON that `GET /orders` returns.

**Fixed means:** the orders table has `grand_total` and no `total`, the API returns `grand_total`, and the unit tests pass.

## Root cause
Not a defect. The name is set in three places:
- `migrations/0001_create_customers_and_orders.sql:11` creates the column.
- `shop/api.py:15` selects it.
- `shop/api.py:10` (`order_to_dict`) copies it into the JSON field `total`.

**Evidence:**
- `python3 -m shop orders 1` prints `"total": 9.75` for order 1.

## Failing test first
**Location:** `tests/test_api.py`, a new test `test_order_to_dict_uses_grand_total`.

**Test 1**
- **Arrange:** build the in-memory database from the migrations, and insert order 1 with the amount 25.5.
- **Call:** `api.order_to_dict` on the row.
- **Assert:** the result holds `"grand_total": 25.5` and has no `"total"` key.
- **Before the fix:** the result has `total` and no `grand_total`.

## Proposed fix
1. Add `migrations/0004_rename_total.sql` holding `ALTER TABLE orders RENAME COLUMN total TO grand_total;`.
2. In `shop/api.py`, select `grand_total` (line 15) and build the field `grand_total` from it (line 10).
3. Update the expected dict in `tests/test_api.py:25`.

## Do not change
- The `order_items` table.
- The `id`, `customer_id`, `placed_at` and `status` fields, and the amounts.

## Risk areas
- callers of `order_to_dict`: `shop/api.py` and `tests/test_api.py`

## Blast radius
needed: the fix changes a schema column, `migrations/0001_create_customers_and_orders.sql:11`.

## Verification
1. Run the reproduction command:
   ```
   python3 -m unittest discover -s tests
   ```
2. **Before the fix:** it prints `Ran 15 tests` and `OK`.
3. **After the fix:** it prints `Ran 16 tests` and `OK`.
4. On a `data/shop.db` rebuilt with `python3 scripts/seed_db.py`, `python3 -m shop orders 1` prints `"total": 9.75` before the change and `"grand_total": 9.75` after it.

## Follow-on
none
