# Output template

Load at step 5 (First reply) and step 7 (the rest). The examples use a made-up shop: an `Orders` table whose `RegionId`
is empty for orders that came from a file upload, to be filled from the shop's default row in `Regions`. Paths are made
up too. Use bold labels, never `#` headings, also inside a code block, so the reply keeps its shape in any chat window.
Write every label in the order shown. Plain writing: one idea per sentence, the simple word, full words.

## First reply

Understanding and Look queries only, then stop. Aim for 40 lines or fewer. In Understanding, give the request in two or
three sentences, the tables and columns in scope, the rule that picks the rows, the source of the value, the delivery
tool, and `path:line` for every claim about code. Name any parent rows the fix may need to create. End by asking the
engineer to paste the results, and stop. Do not write the script in this reply.

The look queries are read-only. They cover the count in scope and the table's total rows, target rows with no source
value, parent rows missing, rows a join matches twice, soft-deleted or expired matches, and bad rows by date. Say which
date column stands in for a creation date and mark it `inferred:` when the table has none.

```
**Understanding**
Request: orders imported from a file have no region, so the regional totals leave them out.
Scope: `Orders.RegionId` where it is null. Value: the shop's default row in `Regions` (`IsDefault = 1`).
Code: the import sets no region (`src/Import/OrderImporter.cs:58`); the totals join on it (`src/Reports/Totals.cs:31`).
Parent rows: a shop with no default region has no value to copy. The fix does not invent one: it lists those shops.
Delivery tool: DbUp, scripts in the root of `src/Db/Scripts/` (`src/Db/Db.csproj:12`).

**Look queries**
-- 1. Rows in scope, and the table's total rows
SELECT COUNT(*) AS InScope, (SELECT COUNT(*) FROM Orders) AS TotalRows FROM Orders WHERE RegionId IS NULL;
-- 2. Shops with null-region orders and no default region (parent rows missing)
-- 3. Orders that match more than one default region (matched twice)
-- 4. Matching rows that are soft-deleted or expired
-- 5. Null-region orders by month (live cause)

Paste the results. I stop here until you do.
```

## Second reply

Write these labels in this order. Each section follows.

Live cause says whether bad rows are still being created, by date. If they are, give a brief cause and the fix in a
few lines, then still write the full data fix. Give the release order: when the migration tool runs before the app
deploy, the code fix ships in an earlier release; otherwise plan a follow-up script and a check query after the
deploy. End a live cause with nothing more here. The `Next:` line goes at the end of the third reply.

Fix script is in the project's house style: the file name, the encoding and the layout of the nearest earlier data fix.
Each statement is guarded, and the script fails on a surprise. Name the file and the folder in the Placement steps.

Explanation walks through each statement in plain words and says why it is safe to re-run. List the nullable columns and
how each one is handled, and the other features that read the changed columns.

Capture query is the fix's own `WHERE`, read-only. It returns the IDs of the rows the fix will change, plus old values
when the fix overwrites a non-empty value. The engineer runs it on production just before the release and saves the
output with the work item. When the fix inserts parent rows, the capture has two parts: Part 1 lists every bad-state
row with no join to the parent, because the parent does not exist yet, and Part 2 lists the parents missing now. Old
values from a column with personal data go in a work item attachment, and the reverse names the attachment.

Reverse script restores only captured rows that still hold the fix's value, and says that rows changed between the
capture and the deploy are not covered. It lives in the pull request notes and the work item, never in the repository
or any folder the tool runs. When the project's Data access rules forbid reading production, or the engineer says no
capture will be taken, mark it `approximate: check before running` and say so plainly. Do not mark it only because the
capture is not saved yet: the engineer takes it just before the release. If the capture was not saved when the reverse
is needed, it is `approximate: check before running`. There is no backup table. A reverse of an insert checks for rows
that refer to the new row, by foreign key and by code value. When some exist, it marks the row deleted or expired
instead of deleting it. After production there are two cases: reverse, or forward fix. Both ship as new scripts.

Check queries cover the duplicate match, target rows with no source value, and rows outside the intended scope. Give the
count before and after, with the expected result for local, test, production. The check queries are required after each
deploy, because a pipeline may not show script output.

Safety checklist lists every rule from `references/safety-checklist.md` with pass and the path:line or the pasted
result behind it. A rule you could not check is `unknown:`, never `pass`.

Placement steps are numbered. Give exact paths and file names, the registration step when the tool needs one, and the
build check. Then ask the engineer to run the script text twice and paste both counts.

```
**Live cause**
Yes: 11 null-region orders are from the last 3 days (`inferred:` from `ModifiedAt`). `inferred:` The import never sets
the region (`src/Import/OrderImporter.cs:58`); set it there. The migration tool runs before the app deploy
(`deploy/steps.yml:47`), so ship the code fix in an earlier release.

**Fix script**
-- File: src/Db/Scripts/20261024101500_Backfill_OrderRegion.sql
SET XACT_ABORT ON;
IF OBJECT_ID('tempdb..#keys') IS NOT NULL DROP TABLE #keys;
CREATE TABLE #keys (OrderId uniqueidentifier NOT NULL PRIMARY KEY, RegionId uniqueidentifier NOT NULL);

IF EXISTS (SELECT 1 FROM Orders o WITH (UPDLOCK, HOLDLOCK)
           JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.Deleted = 0 AND r.Expired = 0
           WHERE o.RegionId IS NULL GROUP BY o.OrderId HAVING COUNT(*) > 1)
    THROW 50001, 'An order matched more than one default region.', 1;

INSERT INTO #keys (OrderId, RegionId)
SELECT o.OrderId, r.RegionId
FROM Orders o WITH (UPDLOCK, HOLDLOCK)
JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.Deleted = 0 AND r.Expired = 0
WHERE o.RegionId IS NULL;

DECLARE @expected int = (SELECT COUNT(*) FROM #keys);

UPDATE o SET o.RegionId = k.RegionId, o.ModifiedAt = SYSUTCDATETIME()
FROM Orders o JOIN #keys k ON k.OrderId = o.OrderId
WHERE o.RegionId IS NULL;
DECLARE @changed int = @@ROWCOUNT;

IF @changed <> @expected
    THROW 50002, 'Changed row count differs from the key count.', 1;
IF EXISTS (SELECT 1 FROM Orders o JOIN #keys k ON k.OrderId = o.OrderId WHERE o.RegionId IS NULL)
    THROW 50003, 'Rows are still bad after the change.', 1;

DROP TABLE #keys;

**Explanation**
1. `SET XACT_ABORT ON`: most run-time errors roll back the runner's transaction, which already wraps the script
   (`src/Db/Runner.cs:44`).
2. The key table holds the orders to change. Run 2 finds none, so it changes 0 rows.
(one line per statement, each with why it is safe to re-run)

**Capture query**
SELECT o.OrderId FROM Orders o
JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.Deleted = 0 AND r.Expired = 0
WHERE o.RegionId IS NULL;
Run on production just before the release. Save the output with work item 4321. The old value is null, so IDs only.

**Reverse script**
-- Rows changed between the capture and the deploy are not covered.
-- Paste the captured OrderId values into @captured. Restores only rows that still hold the default region.

**Check queries**
-- Duplicate match: expect 0. No source value: expect 0, or each listed with a reason. Out of scope: expect 0.
-- Count before and after. local: the seeded count, then 0. test: the look query count, then 0.
-- Production: required after each deploy.

**Safety checklist**
Guards see soft-deleted rows: pass, pasted look query 4 returned 0.
Transaction: pass, the runner wraps each script (`src/Db/Runner.cs:44`), so the script opens none.
Nulls: pass, `RegionId IS NULL` is the only null test; `ShopId` is not nullable (pasted schema).

**Placement steps**
1. Create `src/Db/Scripts/20261024101500_Backfill_OrderRegion.sql` with the script text above.
2. No registration step: the project file embeds `Scripts\*.sql` (`src/Db/Db.csproj:12`).
3. Build check: build the Db project and confirm the file is listed as an embedded resource.
4. Run the script text twice on your local copy, wrapped in `BEGIN TRAN` and `COMMIT` because the runner wraps it,
   with `sqlcmd -b`, or SSMS in SQLCMD mode with `:on error exit`. Paste the changed-row count of the update, not
   the other "(n rows affected)" lines.
```

## Third reply

Pull request notes, ready to paste. Include the scope, the rule, the counts from the local run, how to check after the
deploy, and how to reverse. Add the parent rows the script creates, if any, and the capture query with a reminder to run
it on production just before the release. Notes use IDs, counts and rules, never names or emails. Captured old values
from a personal column stay in a work item attachment, which the notes name.
A live cause ends the reply with one `Next:` line.

```
**Pull request notes**
Scope: sets `Orders.RegionId` for orders with none. No parent rows created. Shops with no default region are skipped.
The rule: the shop's default row in `Regions`. Local run: run 1 changed 6 rows, run 2 changed 0.
Check after the deploy: run the duplicate-match and out-of-scope queries on test, then production. Both expect 0.
Reverse: run the capture query on production just before the release; attach the output to work item 4321.
How to reverse: the reverse script in the work item, which restores only the captured orders still holding the value.
Next: /agentd-diagnose
```

## Vague work item

When the work item does not say which rows or which value, search briefly, list what was found, and ask which one.
Never guess. Write no script. With nobody to answer, list what was found, write the look queries for each reading, and
stop.

```
**Understanding**
The request does not say which rows are wrong. I found three ways an order can have a wrong region:
1. Imported orders with no region (`src/Import/OrderImporter.cs:58`).
2. Orders whose region belongs to another shop (no code path found; `unknown:`).
3. Orders moved between shops (`src/Orders/MoveOrder.cs:22`).
Which one do you mean? I stop here until you answer. If nobody can answer, I write the look queries
for each reading and no script.
```
