# Change 3: ISO dates in the fulfilment feed

Kind: a proposed change, no code yet. Environment: Local (`data/shop.db`). The block below is the hand-off block
from `agentd-diagnose`.

# Hand-off block

**Confidence:** confirmed

## Task
A new reporting tool needs ISO 8601 dates. Change the `placed_at` column of the nightly fulfilment CSV from `05/03/2024 10:00` to ISO 8601 UTC, for example `2024-03-05T10:00:00Z`. Nothing else in the file changes.

**Fixed means:** `write_feed` writes the new format and the unit tests pass.

## Root cause
`shop/fulfilment.py:10` (`format_placed_at`) formats the stored `YYYY-MM-DD HH:MM:SS` value as `%d/%m/%Y %H:%M`.

**Evidence:**
- `python3 -m shop feed <folder>` writes lines such as `1,01/10/2025 16:36,SKU-1012,3` into `<folder>/fulfilment_YYYYMMDD.csv`.

## Failing test first
**Location:** `tests/test_fulfilment.py`, the test `test_feed_has_a_line_for_each_item_of_a_paid_order`.

**Test 1**
- **Arrange:** the test as it is.
- **Call:** `write_feed`, as the test does now.
- **Assert:** change the two expected lines to `1,2024-03-05T10:00:00Z,SKU-1001,2` and `1,2024-03-05T10:00:00Z,SKU-1004,1`.
- **Before the fix:** the file holds `05/03/2024 10:00`.

## Proposed fix
1. In `shop/fulfilment.py:10`, return `parsed.strftime("%Y-%m-%dT%H:%M:%SZ")`.

## Do not change
- The other columns, the header line, the file name pattern, and which orders are written.

## Risk areas
- callers of `write_feed`: `shop/__main__.py` and `tests/test_fulfilment.py`

## Blast radius
needed: the fix changes the `placed_at` format of the fulfilment CSV, `shop/fulfilment.py:10`.

## Verification
1. Run the reproduction command:
   ```
   python3 -m unittest discover -s tests
   ```
2. **Before the fix:** the changed test fails.
3. **After the fix:** it prints `Ran 15 tests` and `OK`.
4. `python3 -m shop feed <folder>` writes dates such as `2025-10-01T16:36:00Z` in the `placed_at` column.

## Follow-on
none
