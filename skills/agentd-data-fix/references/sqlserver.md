# SQL Server patterns

Load at step 5 (Look queries) and step 7. These are T-SQL patterns for SQL Server. Each is a place to start, not a
guarantee: read the table, the runner and the pasted results before you copy one. For another database, say so and ask
(see `SKILL.md`). The examples use a made-up shop with `Orders` and `Regions`. A live parent row has `Deleted = 0` and
`Expired = 0`. Every rule here comes from `references/safety-checklist.md`; this file adds no rule.

## Guards

A guarded insert sees soft-deleted and expired rows too, so it never adds a duplicate next to one. Three cases: no row,
insert; a deleted row, restore it when the engineer chose that; an active row, do nothing. A missing shop is not a
failure: the fix does nothing for it, and a check query reports it.

```sql
-- Find the shop by a rule, never by a pasted ID.
DECLARE @ShopId uniqueidentifier = (SELECT ShopId FROM Shops WHERE Code = 'MAIN');
IF @ShopId IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Regions WITH (UPDLOCK, HOLDLOCK) WHERE ShopId = @ShopId AND Code = 'NORTH')
    BEGIN
        INSERT INTO Regions (RegionId, ShopId, Code, Deleted, Expired, ModifiedAt)
        VALUES (NEWID(), @ShopId, 'NORTH', 0, 0, SYSUTCDATETIME());
        IF @@ROWCOUNT <> 1 THROW 50010, 'The insert did not add exactly one row.', 1;
    END
    -- Only when the engineer chose "restore": a deleted row comes back, an active row is left alone.
    UPDATE Regions SET Deleted = 0, ModifiedAt = SYSUTCDATETIME()
    WHERE ShopId = @ShopId AND Code = 'NORTH' AND Deleted = 1
      AND NOT EXISTS (SELECT 1 FROM Regions a WHERE a.ShopId = @ShopId AND a.Code = 'NORTH' AND a.Deleted = 0);
    IF @@ROWCOUNT > 1 THROW 50012, 'More than one deleted row matched the restore.', 1;
END
```

The restore skips a code that already has an active row, so it never makes a second active row. A lock held by
`UPDLOCK, HOLDLOCK` lasts only inside a transaction, so the check and the insert need the script's own transaction or
the runner's. A look query counts the rows for the code in every `Deleted` and `Expired` state.

A one-row insert expects 1 row. A set-based insert counts its expected rows first, by the same rule that picks them, and
from a table it loads once, so a row the app adds during the run is not a surprise. A restore sets only the flag the
engineer chose (`Deleted` above), and leaves `Expired` alone. A guarded parent insert locks the range, so the app cannot
add the same parent row while the script runs:

```sql
IF OBJECT_ID('tempdb..#parents') IS NOT NULL DROP TABLE #parents;
SELECT DISTINCT o.ShopId INTO #parents FROM Orders o
WHERE o.RegionId IS NULL
  AND NOT EXISTS (SELECT 1 FROM Regions s WITH (UPDLOCK, HOLDLOCK) WHERE s.ShopId = o.ShopId AND s.IsDefault = 1);
DECLARE @expectedParents int = (SELECT COUNT(*) FROM #parents);
INSERT INTO Regions (RegionId, ShopId, Code, IsDefault, Deleted, Expired, ModifiedAt)
SELECT NEWID(), p.ShopId, 'DEFAULT', 1, 0, 0, SYSUTCDATETIME() FROM #parents p;
IF @@ROWCOUNT <> @expectedParents THROW 50011, 'Inserted parent count differs from the expected count.', 1;
DROP TABLE #parents;
```

A guarded update names the bad state in its `WHERE`, so a fixed row is never touched again:
`WHERE o.RegionId IS NULL`. A comparison with a null never matches, so write `IS NULL` or `IS NOT NULL`, never `= NULL`.
Scope by rule (a join, a code value), never by a list of IDs copied from one environment.

## Transaction

Start every script with `SET XACT_ABORT ON;`. Add `BEGIN TRAN` and `COMMIT` only when the runner code shows nothing
wraps the script. They sit at the top level, with nothing between them that can skip the `COMMIT`:

```sql
SET XACT_ABORT ON;
BEGIN TRAN;
-- guarded statements and checks that THROW
COMMIT;
```

Do not use `TRY/CATCH` unless the `CATCH` ends in `THROW`. Do not use `RETURN` or `ROLLBACK` in the body. The reverse
script follows the same rules as the fix.

To test locally, the engineer runs the script text directly. When the local copy has no bad rows, give a seed: a few
rows made bad inside a transaction that is rolled back by hand once the engineer has pasted the counts. A seed is for
local only and never ships. When the runner wraps the script, wrap the text in `BEGIN TRAN` and `COMMIT` for the local
run, so a `THROW` leaves nothing applied. After a failure run `ROLLBACK` by hand: a compile error leaves the transaction
open, and after a `THROW` the transaction is already gone, so an error from `ROLLBACK` is expected. Seed only rows the
fix can repair, or run 1 may change 0 rows again. If the text holds a `GO`, SSMS carries on with the later batches after
a failure, so run it with `sqlcmd -b`, which stops at the first error.

```sql
BEGIN TRAN;
UPDATE TOP (6) o SET o.RegionId = NULL FROM Orders o
JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.Deleted = 0 AND r.Expired = 0;
-- The two lines above are a seed: local only, never ships.
-- run 1 of the script text here, paste the count, run 2, paste the count
ROLLBACK;
```

## Look queries

Read-only. One query per question; label each with a number and what it answers.

- Rows in scope: a count in scope, and the table's total rows, in one query.
- Target rows with no source value: for example orders whose shop has no default region. A `LEFT JOIN` with
  `WHERE r.RegionId IS NULL` lists them.
- Parent rows missing: the same query, grouped by the parent that needs creating.
- Rows a join matches twice: group by the target ID and keep `HAVING COUNT(*) > 1`. These rows are matched twice.
- Soft-deleted or expired matches: the rows the fix's guard must see, with their `Deleted` and `Expired` flags. Also
  list target rows whose only matching parent is deleted or expired: the fix must not point them at it. Put the choice
  to the engineer.
- Bad rows by date: group the bad rows by day or month on the creation date. When the table has none, use a
  last-modified column and mark it `inferred:`.

```sql
SELECT o.ShopId, COUNT(*) AS BadRows
FROM Orders o
LEFT JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.Deleted = 0 AND r.Expired = 0   -- the fix's join
WHERE o.RegionId IS NULL AND r.RegionId IS NULL
GROUP BY o.ShopId;
```

## Capture and reverse

The capture query is the fix's own `WHERE`, read-only, with the IDs of the rows the fix will change and the old values
when it overwrites a non-empty value. The engineer runs it on production just before the release. When the fix inserts
parent rows, the capture uses the bad-state test only, with no join to the parent, because the parent does not exist
yet. A second part lists the parents that are missing now, so the reverse knows which ones the fix created.

```sql
-- Part 1: every row the fix will change.
SELECT o.OrderId, o.RegionId AS OldRegionId FROM Orders o WHERE o.RegionId IS NULL;
-- Part 2: parents that are missing now.
SELECT DISTINCT o.ShopId FROM Orders o WHERE o.RegionId IS NULL
  AND NOT EXISTS (SELECT 1 FROM Regions r WHERE r.ShopId = o.ShopId AND r.IsDefault = 1);
```

The reverse loads the saved capture into a table variable and restores only rows that still hold the fix's value. It
reports how many rows it restored next to how many were captured; fewer means rows changed since the capture:

```sql
SET XACT_ABORT ON;
DECLARE @captured TABLE (OrderId uniqueidentifier NOT NULL PRIMARY KEY, OldRegionId uniqueidentifier NULL);
INSERT INTO @captured (OrderId, OldRegionId) VALUES ('<OrderId from the capture>', NULL);

UPDATE o SET o.RegionId = c.OldRegionId, o.ModifiedAt = SYSUTCDATETIME()
FROM Orders o
JOIN @captured c ON c.OrderId = o.OrderId
JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.RegionId = o.RegionId;
DECLARE @restored int = @@ROWCOUNT;
SELECT @restored AS Restored, (SELECT COUNT(*) FROM @captured) AS Captured;
```

The captured IDs are the one place IDs from production appear in a script. Reverse the child rows first, then the
created parents. Remove a created parent only when nothing refers to it; if its table has no deleted or expired flag and
something refers to it, leave it and list it. A reverse of an insert first looks for rows that refer to the new row, by
foreign key and by code value. When any exist, it sets `Deleted = 1` or an expiry date instead of deleting the row. A
`VALUES` list takes at most 1,000 rows per `INSERT`, so split a large capture into several. Mark the reverse
`approximate: check before running` when the Data access rules forbid reading production, when the engineer says no
capture will be taken, or when no capture was saved by the time the reverse is needed.

## Batches and temp objects

Surprise check for an update. Insert missing parent rows first. Then use a key table with a `PRIMARY KEY` on the target
ID, read `WITH (UPDLOCK, HOLDLOCK)`, with a separate duplicate check that throws, and compare `@@ROWCOUNT`:

```sql
IF OBJECT_ID('tempdb..#keys') IS NOT NULL DROP TABLE #keys;
CREATE TABLE #keys (OrderId uniqueidentifier NOT NULL PRIMARY KEY, RegionId uniqueidentifier NOT NULL);

IF EXISTS (SELECT 1 FROM Orders o WITH (UPDLOCK, HOLDLOCK)
           JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.Deleted = 0 AND r.Expired = 0
           WHERE o.RegionId IS NULL GROUP BY o.OrderId HAVING COUNT(*) > 1)
    THROW 50001, 'An order matched more than one default region.', 1;

INSERT INTO #keys (OrderId, RegionId)
SELECT o.OrderId, r.RegionId FROM Orders o WITH (UPDLOCK, HOLDLOCK)
JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.Deleted = 0 AND r.Expired = 0
WHERE o.RegionId IS NULL;
DECLARE @expected int = (SELECT COUNT(*) FROM #keys);

UPDATE o SET o.RegionId = k.RegionId, o.ModifiedAt = SYSUTCDATETIME()
FROM Orders o JOIN #keys k ON k.OrderId = o.OrderId WHERE o.RegionId IS NULL;
DECLARE @changed int = @@ROWCOUNT;
IF @changed <> @expected THROW 50002, 'Changed row count differs from the key count.', 1;
IF EXISTS (SELECT 1 FROM Orders o JOIN #keys k ON k.OrderId = o.OrderId WHERE o.RegionId IS NULL)
    THROW 50003, 'Rows are still bad after the change.', 1;
DROP TABLE #keys;
```

The statement before THROW ends with a semicolon, and the error number is 50000 or higher. For an insert, the script
counts the expected number itself, by the same rule that picks the rows.

To skip a parent that has two live defaults, add the same exclusion to both the duplicate check and the key load, for
example `AND NOT EXISTS (SELECT 1 FROM Regions r2 WHERE r2.ShopId = r.ShopId AND r2.IsDefault = 1 AND r2.Deleted = 0
AND r2.Expired = 0 AND r2.RegionId <> r.RegionId)`, and give a check query that lists each skipped parent with a reason.

A table variable or a `#` table is fine; a `##` table is visible to other sessions, so never use one. Drop each `#`
table at the end, because a runner may reuse one connection. A `#` table survives a `GO`; variables do not.

Batches help only when the runner does not wrap the script and does not send it as one command. Run the duplicate check
once before the loop. Each batch loads at most 4,000 keys (below the lock escalation threshold of about 5,000 locks),
updates through the key table, and records the keys it handled in a second table, so the final "still bad" check looks
only at those keys. Each batch is guarded, so a stop halfway runs again safely:

```sql
SET XACT_ABORT ON;
IF OBJECT_ID('tempdb..#keys') IS NOT NULL DROP TABLE #keys;
IF OBJECT_ID('tempdb..#done') IS NOT NULL DROP TABLE #done;
CREATE TABLE #keys (OrderId uniqueidentifier NOT NULL PRIMARY KEY, RegionId uniqueidentifier NOT NULL);
CREATE TABLE #done (OrderId uniqueidentifier NOT NULL PRIMARY KEY);

IF EXISTS (SELECT 1 FROM Orders o
           JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.Deleted = 0 AND r.Expired = 0
           WHERE o.RegionId IS NULL GROUP BY o.OrderId HAVING COUNT(*) > 1)
    THROW 50001, 'An order matched more than one default region.', 1;

DECLARE @n int = 1;
WHILE @n > 0
BEGIN
    TRUNCATE TABLE #keys;
    INSERT INTO #keys (OrderId, RegionId)
    SELECT TOP (4000) o.OrderId, r.RegionId
    FROM Orders o JOIN Regions r ON r.ShopId = o.ShopId AND r.IsDefault = 1 AND r.Deleted = 0 AND r.Expired = 0
    WHERE o.RegionId IS NULL;
    SET @n = @@ROWCOUNT;
    INSERT INTO #done (OrderId) SELECT OrderId FROM #keys;
    UPDATE o SET o.RegionId = k.RegionId, o.ModifiedAt = SYSUTCDATETIME()
    FROM Orders o JOIN #keys k ON k.OrderId = o.OrderId WHERE o.RegionId IS NULL;
END
IF EXISTS (SELECT 1 FROM Orders o JOIN #done d ON d.OrderId = o.OrderId WHERE o.RegionId IS NULL)
    THROW 50005, 'Rows are still bad after the loop.', 1;
DROP TABLE #keys;
DROP TABLE #done;
```

In a wrapped script a batch does not shorten the transaction or the timeout, though 4,000-row statements can still avoid
lock escalation. A batched script has no transaction of its own.
