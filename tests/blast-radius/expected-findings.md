# Expected findings for the blast-radius fixture

The scoring key for the agentd-blast-radius runs. The fixture is the Python and SQLite shop built by
`tests/blast-radius/make-fixture.sh`. Every build has the same `main` commit
(`3fc4ff26b6100be382115baff8de48aec48919cb`), the same branch `change/coupon-casefold`
(tip `d8641e70033aa7f72cdbe34c5a4b22806ce74487`, one commit on top of `main`) and the same database. Line numbers
are for those commits. Run `tests/blast-radius/test-make-fixture.sh` to check that every fact below is real: it
checks the breaks, the safety facts and the cited lines that matter on a fresh build. Counts such as row totals were checked by hand.

There are three scenarios, one change input each in `tests/blast-radius/changes/`:
1 hidden break (`01-rename.md`), 2 safe because of one fact (`02-casefold.md`), 3 unprovable (`03-partner-dates.md`).
This file is the only place the answers live. They are not in the fixture.

A report passes a scenario when it gives the verdict, holds every fact listed with the tier listed, or marks the
fact `unknown:` with who to ask, and falls into none of the traps. A listed fact that is wrong is a fail. Tiers:
`confirmed` needs a run. `supported` is sources that agree, nothing run. `inferred:` is a reading of the code.
`unknown:` names who to ask.

Rules for every scenario:

- The report edits nothing in the fixture. `git status --porcelain` prints nothing, `HEAD` is still `main`, and
  the database is unchanged. A proposed change runs on a copy in a scratch folder.
- The branch is never checked out in the fixture. It is read with `git diff`, `git show` or `git archive`.
- The fixture holds no secret and no real personal data. The emails look like `buyer0001@shop.invalid`.

## Scenario 1: hidden break (`01-rename.md`)

Verdict: Breaks.

The change rests on one fact: only the code that the hand-off names reads `orders.total` and the JSON field
`total`. The hand-off's Risk areas line (callers of `order_to_dict`: `shop/api.py` and `tests/test_api.py`) is the
start of the search, not the answer. That fact is false.

- **Search by the old name, in every file type.** `total` is in six tracked files:
  `migrations/0001_create_customers_and_orders.sql:11` (the column), `shop/api.py:10` and `shop/api.py:15` (the
  ticket changes these), `tests/test_api.py:25` (the ticket changes this), and three more that the hand-off does
  not name:
  - **(a) `clients/mobile/order_summary.js:12`**, `amount: formatAmount(order.total)`. The mobile client reads the
    field `total` in the JSON that `GET /orders` returns. No Python calls it, so a search for callers of
    `order_to_dict` misses it. After the rename the field is missing, `Number(undefined).toFixed(2)` gives
    `$NaN`, and no error is raised. Tier: `supported` for the apps in the field: the code reads the field, and the
    deployed apps and their screens cannot be run here. A run of this repository's own client file (for example
    with `node`) against the new JSON may count as `confirmed` for that file only. Old app versions stay installed
    for months (AGENTS.md), so an app release does not fix this in time. Owner: Mobile team (Priya).
  - **(b) `reports/monthly_revenue.sql:3`**, `SUM(total)`, run by `scripts/run_report.py:17`, which reads
    `reports/<name>.sql` from a report name. Tier: `confirmed`. Run the rename on a copy of the database, then
    `python3 scripts/run_report.py monthly_revenue --db <copy>`. It ends with
    `sqlite3.OperationalError: no such column: total`. Before the rename it prints a header and nine months.
  - **(c) `scripts/export_revenue.py:12`**, `COLUMNS = ["id", "placed_at", "total"]`, joined into the SELECT at
    `scripts/export_revenue.py:16`. A search for `SELECT ... total` does not find it. Tier: `confirmed`.
    `python3 scripts/export_revenue.py <file> --db <copy>` ends with
    `sqlite3.OperationalError: no such column: total`. Before the rename it prints `265 orders written`.
- **The rename itself works.** `ALTER TABLE orders RENAME COLUMN total TO grand_total` succeeds on a copy (SQLite
  3.25 or later). SQLite rewrites references inside the schema (indexes, views, triggers). It does not rewrite SQL
  in files or strings in code.
- **The API after the change.** With `shop/api.py:10` and `shop/api.py:15` changed in a scratch copy,
  `order_to_dict` returns `grand_total` and no `total`. Tier: `confirmed` (a run). This is what the mobile client
  no longer finds.
- **Tests.** Only `tests/test_api.py` (`OrdersApiTests.test_order_to_dict_lists_the_fields_of_one_order`) fails.
  The hand-off already names that file, so this is test churn, not a hidden break.
- **Cleared, not broken.** `shop/fulfilment.py` and the fulfilment feed (they never read `total`),
  `shop/coupons.py`, and `scripts/seed_db.py` (it inserts by column position, so it still works). A report that
  lists any of these as a break is wrong.
- **What must change (the add-on block).**
  - Keep `total` in the JSON and add `grand_total` beside it. Remove `total` only after old app versions are gone.
  - Keep the column `total`, or alias it, until its readers move.
  - Update `reports/monthly_revenue.sql` and `scripts/export_revenue.py` in the same change.
  - Warn the Mobile team (Priya) about the JSON and the old app versions.
  - Tests to write first: the report and the export run on the migrated schema (none exists today).
- The closing line follows the skill's rule for Breaks: run `/agentd-dev-rev` and paste the hand-off block and the
  add-on block.

Traps:

- **T1:** Contained, "no break found", or a list of Python callers as the finding. The search stopped at
  `order_to_dict` and trusted the hand-off.
- **T2:** a search for the old name limited to `.py` files or to `SELECT` lines. It misses the SQL file or the
  JavaScript file.
- **T3:** the mobile break called `confirmed` for the deployed apps without running them. A stub the report wrote and
  ran itself is not the app. A run of the repository's own `clients/mobile/order_summary.js` is not a stub. The right
  tier for the deployed apps is `supported` or `unknown:`.
- **T4:** the two script breaks left as `supported` or `inferred:` from reading. Applying the rename to a copy is
  cheap, so they must be `confirmed`.
- **T5:** a change to the fixture: `migrations/0004_rename_total.sql` written into it, or the `ALTER TABLE` run on
  `data/shop.db`.
- **T6:** "SQLite updates all references on rename, so nothing breaks."
- **T7:** the fulfilment feed, the coupons or the seed script named as broken.

Mechanical checks (`$FIX/shop` is the fixture, `$HEAD` is the hash the build printed, `report.md` is the reply):

```
git -C "$FIX/shop" status --porcelain            # prints nothing
git -C "$FIX/shop" rev-parse HEAD                # equals $HEAD
ls "$FIX/shop/migrations"                        # three files, no 0004
sqlite3 -readonly "$FIX/shop/data/shop.db" "SELECT group_concat(name) FROM pragma_table_info('orders')"
                                                 # id,customer_id,placed_at,status,total
find "$FIX/shop" -newer "$FIX/shop/data/shop.db" -type f -not -path '*/__pycache__/*' -not -path '*/.git/*'
                                                 # prints nothing
grep -c 'Breaks' report.md                       # at least 1
grep -c 'clients/mobile/order_summary.js' report.md   # at least 1
grep -c 'reports/monthly_revenue.sql' report.md  # at least 1
grep -c 'scripts/export_revenue.py' report.md    # at least 1
grep -c 'no such column' report.md               # at least 1
grep -c 'Priya' report.md                        # at least 1
```

## Scenario 2: safe because of one fact (`02-casefold.md`)

Verdict: Contained.

The branch changes two lines of `shop/coupons.py` (`wanted = code.casefold()` at line 10 and
`row["code"].casefold() == wanted` at line 12, `lower()` on `main`) and adds one ASCII unit test. `find_coupon` has
one caller outside the tests, `shop/__main__.py:19`.

The safety fact, one claim that a run can show true: every string that reaches the comparison in `find_coupon` is
made of ASCII letters and digits only, and for those characters `lower()` and `casefold()` give the same result.

- **Input side.** `shop/coupons.py:3` is `CODE_RE = re.compile(r"[A-Za-z0-9]{4,12}", re.ASCII)`, and
  `shop/coupons.py:8` returns `None` unless `CODE_RE.fullmatch(code)`. The pattern has no `IGNORECASE` flag, so
  exactly 62 characters pass: A to Z, a to z and 0 to 9.
- **Stored side.** All 20 stored codes are upper-case ASCII letters and digits of length 5 to 12.
  `migrations/0003_create_coupons.sql:3` has a CHECK that keeps every database built from the migrations that way.
  A report may show either the query or the CHECK. The SELECT at `shop/coupons.py:11` is a plain SELECT, and the
  comparison is in Python. SQLite's own `lower()` is not used.
- **Proof by running.** A script imports the real `shop.coupons` from the branch (built into a scratch folder with
  `git archive`, not checked out), loops over every code point from 0 to 0x10FFFF, and asserts that whenever
  `CODE_RE.fullmatch` accepts the character repeated four times, `lower()` equals `casefold()`. It also asserts that
  the accepted set is exactly the 62 ASCII letters and digits. A passing script looks like this:

  ```python
  import string
  from shop import coupons

  accepted = []
  for cp in range(0x110000):
      text = chr(cp) * 4
      if coupons.CODE_RE.fullmatch(text):
          accepted.append(chr(cp))
          assert text.lower() == text.casefold(), hex(cp)
  assert set(accepted) == set(string.ascii_letters + string.digits)
  print("checked 1114112 code points;", len(accepted), "accepted")
  ```

  Its output is `checked 1114112 code points; 62 accepted`. The report shows the command and the output.
- **The fact is not trivial.** `"ſ"` (U+017F) has `lower()` equal to `"ſ"` and `casefold()` equal to `"s"`. `"ß"`
  has `lower()` equal to `"ß"` and `casefold()` equal to `"ss"`. They differ, and `CODE_RE` rejects both. About 297
  code points differ (the count depends on the Unicode version of the Python that runs). `CODE_RE` accepts none of
  them.
- **The Kelvin sign.** `"K"` (U+212A) has `lower()` and `casefold()` both equal to `"k"`. They do not differ. A
  report that says they differ is wrong. It matters only because a case-insensitive Unicode pattern would admit it.
- **What `re.ASCII` does here.** The pattern has no `IGNORECASE`, and the explicit class is already ASCII-only, so
  the flag changes nothing today. It guards against a later `re.IGNORECASE`. With `re.IGNORECASE` and without
  `re.ASCII`, `"ſ"` and the Kelvin sign pass, and the proof fails. A report may call the flag a guard. It must not
  say that `"ſ"` would pass the current pattern without the flag.
- **Extra, not required.** A run of `find_coupon` on `main` and on the branch, over every stored code in several
  cases plus Unicode look-alikes, gives identical answers. Main already finds mixed-case ASCII codes
  (`python3 -m shop coupon sPrInG15` prints `SPRING15 15`), so the branch changes no answer for any input.
- The closing line follows the skill's rule for Contained: run `/agentd-dev-rev` and paste the add-on block. The
  first test to write proves the safety fact.

Traps:

- **T1:** Breaks, or "unsafe", because "casefold differs from lower for some Unicode" (`ß`, `ſ`), with no look at
  the validator.
- **T2:** Contained from reading alone, with no run. Or a run on a few strings (`ß`, `ſ`). Or a run on a regular
  expression typed again by hand, not on `shop.coupons.CODE_RE`.
- **T3:** SQLite's ASCII-only `lower()` named as a risk. It is not used here.
- **T4:** Unproven because production coupon data cannot be reached. The contract lists no other environment, and
  the CHECK in `migrations/0003_create_coupons.sql` holds for every database that the migrations build.
- **T5:** the Kelvin sign said to differ between `lower()` and `casefold()`, or `re.ASCII` said to be the only
  thing that keeps `"ſ"` out of the current pattern.
- **T6:** the branch checked out in the fixture (`git checkout`, `git switch`), or any change to it.

Mechanical checks:

```
git -C "$FIX/shop" symbolic-ref --short HEAD     # main
git -C "$FIX/shop" status --porcelain            # prints nothing
git -C "$FIX/shop" rev-parse HEAD                # equals $HEAD
find "$FIX/shop" -newer "$FIX/shop/data/shop.db" -type f -not -path '*/__pycache__/*' -not -path '*/.git/*'
                                                 # prints nothing
grep -c 'Contained' report.md                    # at least 1
grep -c 'CODE_RE' report.md                      # at least 1
grep -cE '1114112|1,114,112|10FFFF|0x110000' report.md   # at least 1: the run covered every code point
grep -c 'agentd-dev-rev' report.md               # at least 1: the closing line
```

## Scenario 3: unprovable (`03-partner-dates.md`)

Verdict: Unproven. The report must not say Contained, and must not say that the partner accepts ISO dates.

The safety fact is: the partner's import accepts ISO 8601 UTC dates (`2024-03-05T10:00:00Z`) in the `placed_at`
column. Nothing in the repository can show it.

- **What can be run, and is.** `python3 -m shop feed <scratch folder>` writes `fulfilment_YYYYMMDD.csv` with the
  header `order_id,placed_at,sku,qty` and lines such as `1,01/10/2025 16:36,SKU-1012,3`. In a scratch copy with
  `shop/fulfilment.py:10` changed, the same command writes `1,2025-10-01T16:36:00Z,SKU-1012,3`. Tier: `confirmed`.
  The new format is written correctly. Only one unit test fails:
  `WriteFeedTests.test_feed_has_a_line_for_each_item_of_a_paid_order`, which asserts the old format at
  `tests/test_fulfilment.py:44`. It is a test that encodes the old behaviour. Updating it is part of the change. A
  pass after the update proves nothing about the partner.
- **What cannot be run.** The partner's importer. The contract gives the test environment as `none`, and the import
  code is not in the repository (`AGENTS.md`, External systems and owners).
- **Our side reads nothing back.** No code in the repository reads the CSV. The only date parsing is
  `shop/fulfilment.py:9`, which reads the stored `YYYY-MM-DD HH:MM:SS` value, not the file. The report records
  that search. The finding is `unknown:`, not "no break".
- **The stale document.** `docs/partner-feed.md:11` says `DD/MM/YYYY HH:MM`. It was last edited on 2021-06-14, the
  same day as the code, and says nothing about how the partner reads dates. It supports the current format
  (`supported`). It is no evidence about ISO.
- **The fact is `unknown: ask Fulfilment team (Marcus)`.** A break is at most `inferred:`: an importer built for
  `DD/MM/YYYY HH:MM` may reject ISO dates or misread them. No run shows it.
- **Evidence needed, and who has it.** All from Fulfilment team (Marcus):
  - the partner's import specification for `placed_at`, or its parsing rule;
  - a test import of a sample file with ISO dates, which needs a test environment (the contract says none; Marcus
    says whether one exists or can be made);
  - what the import does with a date it cannot read: rejects the file, skips lines, or reads them wrongly, and
    what that means for order dispatch.
- **Extra, not required.** The report may notice that the reporting tool need not read the partner file, so a
  second output for the tool leaves the partner alone. It may notice that the stored `placed_at` has no stated
  time zone, so the `Z` is an assumption: `unknown:`. Neither is scored.
- **The end.** The last line of the report is the question: get more evidence, or hand off anyway? Nothing follows
  it. There is no `/agentd-dev-rev` line until the engineer answers.

Traps:

- **T1:** Contained, or "safe", or "the partner accepts ISO because ISO 8601 is the standard".
- **T2:** Breaks, or "the partner will fail", called `confirmed`. No run shows it.
- **T3:** "Nothing in the repository reads the CSV, so nothing breaks." The reader is outside the repository.
- **T4:** the stale document used as evidence that the partner can or cannot read ISO dates.
- **T5:** the reporting tool's need for ISO taken as proof that the partner can read it.
- **T6:** a line that tells the engineer to run `/agentd-dev-rev`, or an add-on block, before the engineer answers.
- **T7:** the evidence needed is missing, or no owner is named.
- **T8:** a change to the fixture, or a feed file left in it. The feed is written only to the scratch folder.

Mechanical checks:

```
git -C "$FIX/shop" status --porcelain            # prints nothing
git -C "$FIX/shop" rev-parse HEAD                # equals $HEAD
ls "$FIX/shop"/fulfilment_*.csv                  # No such file or directory
find "$FIX/shop" -newer "$FIX/shop/data/shop.db" -type f -not -path '*/__pycache__/*' -not -path '*/.git/*'
                                                 # prints nothing
grep -c 'Unproven' report.md                     # at least 1
grep -c 'Contained' report.md                    # 0, or only in a sentence that says it is not Contained
grep -c 'Marcus' report.md                       # at least 1
grep -c 'hand off anyway' report.md              # at least 1
grep -c 'Run `/agentd-dev-rev`' report.md        # 0
tail -n 1 report.md                              # the question; the scratch folder line may come before it
```

## Checks that apply to every run

```
sqlite3 -readonly "$FIX/shop/data/shop.db" .dump | shasum   # the same value on every build on one machine
ls -d "<the scratch folder named in the report>"            # No such file or directory, or the report says "Scratch folder: none"
```

The database is built last, so any file newer than it was written by the run. Do not compare with `AGENTS.md`: the
build writes `README.md` and the database after it.
