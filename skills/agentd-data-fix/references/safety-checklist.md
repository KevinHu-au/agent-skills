# Safety checklist

Load at step 7. Every rule says what to do and why. Grade a rule `pass` only with the `path:line` or the pasted result
behind it. A rule you could not check is `unknown:`. The patterns for T-SQL are in `references/sqlserver.md`.

## Script rules

- Every statement is guarded. An insert uses `IF NOT EXISTS`. An update has a `WHERE` that excludes already-fixed rows.
  Why: any number of runs must change nothing after the first, whatever the tool's journal does.
- Guards also see soft-deleted and expired rows, and a look query lists them. Why: a guard that skips them inserts a
  duplicate next to a deleted row. When one exists, put the choice to the engineer: restore it, or add another.
- Scope by rule, never by IDs copied from one environment. Why: IDs differ between local, test and production. The one
  exception is the reverse, which uses the production capture.
- The script fails (`THROW`) on a surprise. Why: a half-right script that finishes is worse than one that stops.
  - A target row matched more than once. The update joins to a key table, never to the source table directly.
  - A changed row count that differs from the count of keys taken just before.
  - Rows still bad after the change, checked only for those keys. Rows the app creates during the run are not a
    surprise.
- Surprise check for an update, in this order. Insert any missing parent rows first, then load the target keys:
  1. Drop `#keys` if it exists, then create it with a `PRIMARY KEY` on the target ID.
  2. Run a separate duplicate-match check, with `HAVING COUNT(*) > 1`, and `THROW` on any row. A double match in an
     `UPDATE ... FROM` changes each row once, so `@@ROWCOUNT` cannot see it.
  3. Load the keys by the rule, reading the target with `UPDLOCK` and `HOLDLOCK`, so nothing changes between the check
     and the update.
  4. Update by joining to the key table. Store `@@ROWCOUNT` in a variable straight away and compare it with the key
     count. Check "still bad" for those keys. The script drops `#keys` at the end, because a runner may reuse one
     connection.
- A parent insert reads the parent table with `UPDLOCK, HOLDLOCK` in its `NOT EXISTS`. Why: the app can create the same
  parent row while the script runs, because the old app stays live until the app deploy, and the table may have no
  unique key. Without the lock the project ends with two parent rows, which is the state the fix is meant to avoid.
- Check every function name and column name against the table scripts and the app code. Why: a compile error fails
  the whole release, and only the local run catches it. Read how the app sets a value, such as a time with its zone,
  before you choose the function.
- A key load joins only to live parent rows, never to a deleted or expired one. When an in-scope row's only matching
  parent is deleted or expired, put the choice to the engineer, and add a check query for target rows that point at a
  deleted or expired parent: expect 0.
- A restore sets only the flag the engineer chose. Expired is a business state: clear it only when asked, and leave a
  row that is only expired alone.
- Throw on a surprise about the rows the fix changes. A throw about rows the fix does not change stops every later
  script in a runner that halts on failure, and fails every release until the data is cleared. If you add one, say so
  and name who clears the data.
- An insert needs a value for every column it leaves out. Check that the columns an insert leaves out (ID, created,
  updated) have a default or are set by the app, and cite `path:line`. Mark production `unknown:` until the engineer
  checks it.
- An insert compares `@@ROWCOUNT` with an expected count that the script counts itself by the same rule. Never use a
  number taken from a pasted result.
- A `THROW` follows a statement that ends with `;` and uses an error number of 50000 or higher. Otherwise `THROW` is
  read as part of the previous statement or is refused.
- `PRINT` counts help only in a manual run. A pipeline may never show them, so the check queries after each deploy are
  required.
- No join can match one target row twice. Why: the update would hit that row once and look fine. A look query and a
  check query count rows that are matched twice, with `HAVING COUNT(*) > 1`, expecting 0. - To skip rows by rule (for
  example a parent that has two live defaults), add the same exclusion to the duplicate check and the key load, and
  give a check query that lists each skipped parent with a reason.
- Mind nulls. A comparison with a null never matches, so say how each nullable column is handled. List the other
  features that read the changed columns.
- Batch separators: use no `GO` when the runner fails on it. Where `GO` is allowed, variables do not survive across
  it, and a key table made before a `GO` still exists after it only if it is a `#` table.
- Set the columns other features use to detect a change the way the app does: `UpdatedAt`, a version or `rowversion`,
  `ModifiedBy`. Find the entity base class that sets the change column and mark it `inferred:` when the database does
  not show it. Check audit or history tables, a trigger, and temporal tables. Apps that sync by a change column never
  see a hard delete, so mark the row deleted instead.
- No `##` global temp tables: other sessions can see them. Use a `#` table or a table variable, and make sure it is
  dropped at the end.

## Transaction

- `SET XACT_ABORT ON` always.
- Find the runner's transaction mode in its code and cite the `path:line`. Read the code, not the tool's name.
- The script opens its own transaction only when nothing wraps it. Why: inside a wrapped script a nested `COMMIT`
  commits nothing, so the script misleads its reader, and any `ROLLBACK` would end the runner's transaction.
- When the script opens one, `BEGIN TRAN` and `COMMIT` sit at the top level, with nothing between them that can skip
  the `COMMIT`.
- No `TRY/CATCH` unless the `CATCH` ends in `THROW`. Use no RETURN or ROLLBACK in the script body. Why: the runner may
  record the script as done with nothing applied, or leave a transaction open on its shared connection.

## Checks that need data

A checklist the author grades alone is not evidence. Every rule the data can prove becomes a check query that the
engineer runs and pastes.

- Target rows matched more than once by the fix's join: expect 0.
- Target rows with no source value: expect 0, or each listed with a reason.
- Rows the rule matches outside the intended scope: expect 0.
- Count before and after, with the expected result for local, test and production.

The Safety checklist section marks each rule `pass` with the `path:line` or the pasted result behind it. Explain each
statement in plain words, with why it is safe to re-run. Suggest an independent review of the script.

## Reverse

- After production there are two cases: reverse, or forward fix. Both ship as a new script. An applied script is never
  edited.
- The rule alone cannot find the changed rows after the fix, so give a capture query: the fix's own `WHERE`, read-only,
  with the IDs of the rows it will change, plus old values when it overwrites a non-empty value. When the fix inserts
  parent rows, the capture uses the bad-state test only, with no join to the parent (the parent does not exist yet),
  and a second part lists the parents that are missing now, so the reverse knows which rows the fix created.
- Reverse the child rows first, then any parent rows the fix created. Remove a created parent only when nothing refers
  to it; when its table has no deleted or expired flag and something refers to it, leave it and list it.
- The reverse restores only captured rows that still hold the fix's value. It says that rows changed between the
  capture and the deploy are not covered.
- When the project's Data access rules forbid reading production, or the engineer says no capture will be taken, mark
  the reverse `approximate: check before running`. Do not mark it only because the capture is not saved yet: the
  engineer takes it just before the release.
- No backup table in the customer's database. The reverse lives only in the pull request notes and the work item, never
  in the repository. If it is needed after production, copy it into a new script then.
- If the capture was not saved when the reverse is needed, treat the reverse as `approximate: check before running`.
- A reverse of an insert checks for rows that refer to the new row, by foreign key and by code value. When some exist,
  it marks the row deleted or expired instead of deleting it.

## Large tables

- The look queries count the rows in scope and the table's total rows. `HOLDLOCK` on a predicate with no index locks a
  range, so the total rows matter as well as the rows in scope.
- Keep a batch below about 4,000 keys, under the lock escalation threshold of about 5,000 locks. Check "still bad"
  only for the keys the batches handled.
- Above 100,000 rows in scope, warn and ask: batches, or a maintenance window. Why: timeouts, lock escalation that
  blocks live users, and a timed-out data script that fails a release after a schema change already ran.
- Batching helps only when the runner does not wrap the script in a transaction and does not send it as one command.
  When the runner wraps the script, a batch does not shorten the transaction. When it sends one command, one timeout
  stays. Then offer a maintenance window or another delivery path.
- Each batch is guarded and can run again. A batched script has no transaction of its own: that is the one exception to
  the transaction rule.
