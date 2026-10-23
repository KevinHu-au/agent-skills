# Work item: revenue report ignores coupons

Raised by: support desk. Environment: test (`data/shop.db`).

The 2026 revenue report ignores coupons. Account 1 shows the full list price. Order 90001 alone should count as
35.00 after the SAVE5 coupon.

Command: `python3 -m shop report 2026`

Please make the report apply coupons.
