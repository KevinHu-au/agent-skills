# Expected findings for the intake fixture

The scoring key for `EVAL.md`. The fixture is built by `tests/intake/make-fixture.sh`: the diagnose shop
(`6458ad8b5eb5574d684c3cbd31e272fcde6a93b2`) plus an onboarding pack, at commit
`a0156d30a93c85924b8417fc65b1f75563318ff0`. `tests/intake/test-make-fixture.sh` pins every `path:line` below. A cited
line may be off by one (for example `shop/__main__.py:15` or `:16`).

**Score** = facts present out of facts listed, plus traps hit. A run passes a ticket when every listed fact is present
(or marked `unknown:` with who to ask) and it hits no trap. A listed fact stated wrongly is a miss.

**Every ticket.** The runs are headless, so the engineer block says `Requirement: unconfirmed` with a stop condition
(ticket 4: `Requirement: none (support question)`). `Requirement:` and the verdict never appear in the comment. No
file path, table name or function name above Technical notes. No personal data added: no name or email from the
database. The fixture's branch name does not start with a number, so no `Work item <number>` line. Traps for every
ticket: naming `agentd-explain`; running a command that writes (a build, the tests, the app, a database query);
editing any file.

## Ticket 1: enhancement with a wrong fix (`tickets/01-enhancement.md`)

Verdict: **Not actionable yet**, because of question 1 below.

- **Restatement:** finance cannot see why an invoice total is below the price list. The discount column is a
  candidate, not the need.
- **The prescribed fix is wrong:** a percent coupon has no amount in the coupon setup (`scripts/seed_db.py:16`, coupon
  `TEN`; `shop/db.py:18` lets `amount_cents` be empty),
  and the amount taken depends on the order (`shop/pricing.py:13`, `:20`). Said in the engineer block or Technical
  notes; the comment may say it in the customer's words.
- **Blocking gap:** the invoice CSV columns are a contract finance reads (`AGENTS.md`, Risk areas). How finance imports
  the file is `unknown: ask the finance team` (`AGENTS.md`, External systems and owners). Adding a column changes a
  contract, so there is no safe default.
- **Comment questions**, each with why it matters and a default:
  1. By column name or by position; may we add a last column? No default: this blocks. Ask the finance team.
  2. Amount, code or both? Default: the amount taken off, or none (it is a figure finance reports, so the
     checklist's safe-default rule allows either).
  3. Optional: one discount per order? The code mostly answers it (`shop/db.py:24`, one `coupon_code` per order;
     `shop/export.py:26`, one row per order), so it may be an assumption backed by the code instead of a question.
  4. Resend files already received? Default: no (`shop/export.py:18`: every export lists all of the account's orders).
- **Closing:** post the comment, then run `/agentd-intake` again with the replies.

Traps: an Actionable verdict; the coupon setup amount adopted as the requirement; a question the code answers asked
with no default; more than five questions.

## Ticket 2: bug whose claim the code contradicts (`tickets/02-bug.md`)

Verdict: **Actionable**, all seven headings, no customer questions.

- **Today:** what the customer reported (account 1 shows the full list price; order 90001 should count as 35.00), the
  test environment, and how to reproduce: `python3 -m shop report 2026`. At most one hedged line that a first check
  suggests coupons are taken off.
- **Change:** each order counts its coupon once; order 90001 counts as 35.00. The expected behaviour, not a fix.
- **Acceptance check:** "When you run the 2026 revenue report, order 90001 counts as 35.00", or the same idea.
- **Technical notes:** `shop/__main__.py:18` → `shop/reports.py:14`, `:25` → `shop/pricing.py` (`order_total`) →
  tables `orders`, `order_items`, `products`, `coupons`. Frontend, command and handler are `none` (command-line
  tool). Risk area: business-critical calculations (the revenue finance reports).
- **Engineer block:** `conflict:` the work item says the report ignores coupons; `shop/reports.py:14` loads the coupon
  and `:25` passes it to `order_total`. `Next: /agentd-diagnose`.

Traps: a root cause stated as confirmed; a fix as the requirement; Not actionable because the cause is unknown; the
comment states the code's reading as fact (for example "order 90001 counts as 30.00"), or states "ignores coupons" as
fact rather than as what the customer reported.

## Ticket 3: a clear work item (`tickets/03-clear.md`)

Verdict: **Actionable**, zero customer questions, at most two assumptions in the comment (a case-insensitive sort is
a fair one). The engineer block may list more technical assumptions.

- **Technical notes:** `shop/__main__.py:15` → `shop/customers.py:22` (`ORDER BY id`) → table `customers`. Frontend,
  command and handler are `none`.
- **Next:** `/agentd-dev-rev`.

Traps: more than two questions or assumptions in the comment; Not actionable; `/agentd-blast-radius` named; `unknown:` for a layer
the stack does not have.

## Ticket 4: support question (`tickets/04-support.md`)

Output: **chat only, no comment.** `Verdict: Actionable`, `Requirement: none (support question)`.

- **Facts:** `shop/export.py:26` cuts `created_at` to its first 10 characters (the date); the header is at `:23`.
- **Next:** the engineer answers the customer.

Traps: a drafted answer to the customer; an Azure DevOps comment; a change proposed as a requirement.

## Ticket 5: second run with the customer's reply (`tickets/05-second-run.md`)

Verdict: **Actionable**.

- **Prior state:** questions 1 to 3 are now facts (read by name, a last column is fine; the amount taken off; per
  order). Question 4 has no reply and becomes an assumption with its default (no resend).
- **Change:** a new last column `discount`, the amount the coupon took off the order, in dollars, one per row.
- **Technical notes:** `shop/__main__.py:21` → `shop/export.py` (`export_invoices`) → `shop/pricing.py`
  (`order_total_for`) → tables `orders`, `order_items`, `products`, `coupons`. Risk area: the invoice CSV columns
  (finance reads them).
- **Next:** `/agentd-blast-radius`, then `/agentd-dev-rev`.

Credit, not required: the run notes that order 90001 would show 10.00, because a fixed coupon is taken once per line
(`shop/pricing.py:20`).

Traps: asking questions 1 to 3 again; dropping question 4; Not actionable.
