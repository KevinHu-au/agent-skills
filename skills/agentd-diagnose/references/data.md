# Data mode

Find why the data is wrong, how far it goes, and whether it is still happening. A repair is not part of this mode.

## Rules for the data

- SELECT only, and only on an environment that the Data access heading of the contract marks read-only. If the heading is missing, or the environment's access rule cites no source, run no query. Mark the environment `unknown:` and ask the engineer to add the rule and its source to the contract (`contract.md` in the pack, or the project's `AGENTS.md`). The engineer's word in chat does not replace the heading.
- Never run a query on production, including a read replica. When the bad rows are only in production, write the read-only queries for the engineer or a DBA, with the environment and the row limit, and ask for the result. This holds even when the Data access heading has no rule for production. `references/bug.md`, Production evidence, says how to ask and how to tier the result.
- Limit the rows. Ask before you scan a large table or run a query that may lock it.
- Run a stored procedure or function only when you know it does not write.
- Put row IDs, counts and date ranges in the report. Never put names, emails, addresses or other personal data in the report or the hand-off. The report is pasted into the ticket. Keep result files in the scratch folder.

## Four questions

1. **Is the data wrong or the code that reads it wrong?** Look at the rows, not at the screen. If the rows are right, the problem is a bug in the reading code. Say so and follow `references/bug.md`.
2. **What wrote the bad rows?** List every writer of the table: code paths, imports, integrations, stored procedures, triggers, jobs and manual edits. Find the first bad row by date, using the column that records when the row was written. If the only date is one the data carries (a feed or document date), say that it is not the write date. Compare that date with `git log`, the deploy dates, and changes to the writer's configuration, library versions and the source feed's format. Look for what the bad rows share: a source, a user, a batch, a time. Then take good rows from the same writer. List every difference from the bad rows, however small. Check first the difference that rules out the most candidates. Compare personal columns inside the query, for example by counting rows that match on one column and differ on another. Print only IDs and counts.
3. **Is it still happening?** Count the bad rows by day or week. New bad rows in the latest period mean the cause is live. The code fix then comes before any repair.
4. **How wide is it?** Count the rows, tables and customers, and give the date range. Write the query that identifies a bad row, so the engineer can run it again.

## Follow bad records through their stages

Pick a few bad record IDs and follow them through every stage: the source, the import or integration, the table, the code that reads it. Check the record at each stage, read-only. The first stage where it is already wrong names the component to read. Question 2 finds the writer. Then follow what fed the writer. A stage you cannot read, such as an outside feed or another repository, is `unknown:`. Name who to ask.

## Confirmation

A data cause is confirmed when the suspected writer, run on a copy or in memory, makes the same bad-row shape, and the first bad row follows the change. If the data has no write date, the second part cannot be shown: say so, and keep the cause supported. That this writer produced these exact rows stays supported, unless a log or an audit trail shows it. Say which of the two you have.

## Hand-off

The hand-off lists the query that finds the bad rows, the count and the date range, the writer you found, and the code fix for `agentd-dev-rev` when the cause is live. If the cause is not live (a one-off edit, a finished migration), there is no code fix. The hand-off is then the repair, listed under Follow-on, and the report says so.

A repair needs its own reviewed script, and `/agentd-data-fix` writes it for SQL Server. Under Follow-on, tell the engineer to run `/agentd-data-fix` with the work item and to paste this report and the hand-off block as extra facts. Do not write the repair.
