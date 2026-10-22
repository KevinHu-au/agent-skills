# Change 2: coupon matching with casefold

Kind: an existing branch. Environment: Local (`data/shop.db`).

Review the branch `change/coupon-casefold` against `main` for blast radius. Do not check out the branch; read it
with git diff.

Background from the ticket: customers report that coupon codes typed in odd cases are not found. A colleague says
`casefold` is the Unicode-correct comparison.
