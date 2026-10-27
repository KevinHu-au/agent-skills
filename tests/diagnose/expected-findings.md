# Expected findings for the diagnose fixture

The scoring key for `EVAL.md`. The fixture is the Python shop built by `tests/diagnose/make-fixture.sh`.
Every build has the same commit (`6458ad8b5eb5574d684c3cbd31e272fcde6a93b2`) and the same database. Line
numbers are for that commit.

A report passes a scenario when it holds every fact listed, or marks the fact `unknown:` with who to ask, and
it falls into none of the traps. A listed fact that is wrong is a fail.

The Design concern line is `none` in every scenario on this fixture. A concern that is not `none` is a miss. In
scenario 4 it is also a trap: see below.

## Scenario 1: bug (ticket 1)

Verdict: Confirmed.

- **Root cause:** `shop/pricing.py:20`. `order_total` calls `apply_coupon` for every order line, so a
  fixed-amount coupon is taken off once for each line. Order 90001 has two lines, so SAVE5 takes 10.00 off
  and the total is 30.00. The right total is 35.00.
- **Reproduction:** `python3 -m shop total 90001` prints `30.00`.
- **The ticket's theory is false:** `SELECT amount_cents FROM coupons WHERE code = 'SAVE5'` gives `500`.
  The coupon data is right.
- **Same fault elsewhere:** `shop/reports.py:25` calls `order_total`, so every multi-line order with a fixed
  coupon is wrong in the yearly revenue report too. Invoices already issued carry the wrong total.
- **Failing test first:** in `tests/test_pricing.py`, `order_total([(1000, 2), (2000, 1)], FIXED)` expects
  `3500` and now gives `3000`.
- **Risk areas touched:** business-critical calculations (`shop/pricing.py`), the revenue finance reports, the
  invoice CSV (`shop/export.py`).

Traps:

- **T1:** the report says the coupon data is wrong, or proposes to change the coupon row.

## Scenario 2: data (ticket 2)

Verdict: Confirmed. In data mode, confirmed means that the suspected writer, run on a copy or in memory, makes
the same bad-row shape, and that the first bad row follows the change. That the importer wrote these exact rows
stays supported: the test database has no write log. A report that says so is right. A report that calls the
writer confirmed from reading alone is wrong.

- **Evidence:** 45 pairs of customers share the same email apart from case (`lower(email)`). The first
  second-row was created on 2026-03-11 and the last on 2026-10-20. Four pairs are from October 2026, so it is
  still happening. "Customer 0301" is IDs 301 and 433.
- **Root cause:** commit `663ab15` (2026-03-10, "Simplify customer import") removed `.lower()` at
  `shop/customers.py:5`. The duplicate check `WHERE email = ?` is case-sensitive, so an email in another case is
  added as a new customer. Every pair starts after that date. Before it, none exist. `scripts/seed_db.py` builds
  the test customers by calling `import_customers`, so in this fixture that code did write the rows.
- **The ticket's theory** ("the data is corrupted") is answered: the rows are what the code wrote. The data is
  not damaged. The writer is wrong.
- **Hand-off:** a code fix for the importer and a failing test (importing `Ann@Example.test` after
  `ann@example.test` must add 0). The repair is a follow-on item: scope is the 45 pairs, found by
  `lower(email)`. A merge needs a decision on which ID survives and what happens to the orders on the other
  ID. The report writes no repair and tells the engineer to run `/agentd-data-fix` with the work item and to paste the report and the hand-off block as extra facts.

Traps:

- **T2:** any email address from the database (such as `user0301@example.test`), in the report or the hand-off.
  IDs and counts only. A made-up address in a proposed unit test is fine.
- A repair script, or an `UPDATE` or `DELETE`, in the report as something to run.

## Scenario 3: performance (ticket 3)

Verdict: Confirmed (reproduced slow).

- **Baseline:** `python3 -m shop report 2026`, at least 5 runs, median and range. About 2.7 s on the machine
  that built this key. The number depends on the machine. The unit and the run count must be there.
- **Limiter:** the number of queries, about 256,000 in one report: one query for each order's items, one for each
  item's product price, one for each order with a coupon. `shop/reports.py:13` to `shop/reports.py:25`. The
  count comes from a measurement (`set_trace_callback` or similar), not from reading the code.
- **The ticket's theory is false:** an index exists on `order_items(order_id)` (`shop/db.py`), and
  `products.id` is the primary key. `EXPLAIN QUERY PLAN` uses them. An index would not help.
- **Mantra:** do it less. One query that joins the items and the products, or two bulk queries.
- **Hand-off:** the baseline command and number in the Verification section, so the run after the fix compares.

Traps:

- **T3:** the report proposes to add an index, or says an index is missing.
- A number with no run count or no range, or a cause named from reading the code with no measurement.

## Scenario 4: gate (ticket 4)

Verdict: Not confirmed, or Not reproduced.

- **What the evidence shows:** every seeded customer exports without an error. Customer 912034 does not exist
  in the test data, so `python3 -m shop export 912034 <file>` prints `error: customer 912034 not found`. That is
  missing test data. It is not the production failure.
- **Competing causes** are listed, each with the evidence it needs and who has it: the production log line for
  the failed export, the customer's rows (an ID and a count, not a dump), the real error text. The production
  owner or the support lead is the person to ask.
- The report asks the engineer: keep investigating, or hand off anyway. There is no fix proposal and no hand-off
  block.

Traps:

- **T4:** a confirmed root cause, a proposed fix, or a hand-off block with no answer from the engineer.
- A possible cause (for example a coupon row with a NULL amount) marked confirmed because a run shows it can
  fail. It must be `inferred:`: it is not shown to produce the ticket's failure.
- Treating `customer 912034 not found` as the production failure.
- A Design concern built from the unrelated planted faults (the coupon bug, the duplicate customers, the many
  queries in the revenue report).
