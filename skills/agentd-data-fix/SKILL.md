---
name: agentd-data-fix
description: Use when the engineer pastes one work item that needs a data fix in a SQL Server database. Maps it to tables, columns and rows, then writes look queries, a guarded re-runnable script, a capture query, a reverse script, check queries and pull request notes in chat. Never runs anything against a database. Edits no code.
disable-model-invocation: true
---

# agentd-data-fix

Turn one work item into a safe, re-runnable data fix that the engineer places, runs and ships through the project's own
migration tool. A script that looks fine but hides a bug is the failure to prevent, so every rule below favours proof
over trust. Read the references named in the Flow when you reach that step.

## Prerequisite

- The current folder is inside a git repository. Find its root with `git rev-parse --show-toplevel`. If it is not a git
  repository, carry on from the current folder, skip the branch lookup and ask for the work item number if the paste
  lacks it.
- The input is the pasted work item, in the customer's words. If it is empty or is not a work item, ask for the work
  item once, then stop. A pasted diagnose report is extra facts; the work item stays the main input.
- The work item number comes from the paste, else from the branch name. When neither has it, ask.
- Sources, in this order: `docs/onboarding/README.md`, the project contract in `AGENTS.md` (Data access rules, Risk
  areas), then the code. If the pack or the contract is missing, say so once and carry on from the code.
- The references cover T-SQL only. If the project uses another database, say so and ask before writing anything.
- Scope is data only: change existing rows or add reference data. A schema or code change in the same work item is out
  of scope: list it and do the data part. The script may create parent rows the fix needs when a look query shows them
  missing; list them in Understanding and in the pull request notes.

## Flow

1. **Read the work item.** Restate it in two or three sentences. If it is vague (which rows, which value), search
   briefly, list what was found and ask which one. Never guess. With nobody to answer, stop after the look queries.
2. **Map to the data.** Trace from the customer's words to the tables, columns and rows in scope: screen, API, handler,
   table or stored procedure. Cite `path:line` for each hop.
3. **Find the source of the value.** It is already in the database, given by the customer, or set by a business rule.
   Ask when the code cannot tell.
4. **Find the delivery tool.** Read `references/delivery.md`. Cite the runner's transaction mode, output and run order.
5. **Write the look queries.** Read `references/sqlserver.md` (Look queries) and `references/output-template.md` (First
   reply). Write read-only queries, ask the engineer to paste the results, then stop. With nobody to answer, stop after
   the look queries and write no script. Count the rows in scope: above 100,000, warn and ask before going on.
6. **Check for a live cause.** Read the pasted results. If bad rows are still being created, say so. Give a very brief
   summary of the cause and how to fix it, then still write the full data fix. Read the release order from the
   pipeline: when the migration tool runs before the app deploy, the code fix ships in an earlier release; otherwise
   plan a follow-up script and a check query after the deploy. No rows in scope means nothing to fix: say so and write
   no script.
7. **Write the output.** Read `references/safety-checklist.md` and the rest of `references/sqlserver.md` and
   `references/output-template.md`. Write the second reply in the template's order. Grade every safety rule `pass` only
   with a `path:line` or a pasted result behind it, and mark a claim you could not check `unknown:`.
8. **Check locally.** Ask the engineer to run the script text directly (SSMS or `sqlcmd`), not through the tool,
   twice. Run 1 must change more than 0 rows. If the local copy has no bad rows, say so and give a way to seed some
   inside a rolled-back transaction; a 0-row first run is not a pass. Run 2 must change 0 rows. Anything else is a
   bug: fix the script and ask again. When the runner wraps the script in a transaction, wrap the text in `BEGIN TRAN`
   and `COMMIT` for the local run, and tell the engineer to stop at the first error (`sqlcmd -b`) and to run
   `ROLLBACK` by hand after a failure (an error that the transaction is gone is expected).
9. **Finish.** Write the pull request notes with the pasted counts. Remind the engineer to run the capture query on
   production just before the release.

## Turns

- The first reply holds Understanding and Look queries. Then stop and wait for the pasted results.
- The second reply holds Live cause, Fix script, Explanation, Capture query, Reverse script, Check queries, Safety
  checklist and Placement steps, and asks for the two local runs.
- When a local run fails the check, reply with the seed or the fixed script and ask for both runs again.
- The third reply holds the Pull request notes. A live cause ends with one `Next:` line: `/agentd-dev-rev` when a pasted
  diagnose report confirms the cause, otherwise `/agentd-diagnose` (a cause read from the code alone is `inferred:`).

## Rules

- This skill never runs a query or a command against any database. It writes every query, the engineer runs it, and the
  engineer pastes any result it needs.
- It never writes to the repository. The script, the reverse and the placement steps are all in chat.
- It may run read and search only: no build, no tests, no app, no database. Use git read commands, and `date` for a
  timestamp file name.
- Every statement is guarded, so any number of runs changes nothing after the first. Scope by rule, never by IDs copied
  from one environment. Read the safety checklist for the rest.
- Keep the reverse, the capture query and the pull request notes out of the repository and out of any folder the tool
  runs. An applied script is never edited; a reverse or a forward fix is a new script.
- Pasted results may hold personal data. Scripts and pull request notes carry IDs, counts and rules, never names or
  emails. Put captured old values from a personal column in a work item attachment, and name the attachment. Never copy
  a connection string or a password.
- Markers: `unknown:`, `inferred:`, `approximate: check before running`. Cite `path:line` for every claim about code.
- Always English. Do not start another skill; name only `/agentd-dev-rev` and `/agentd-diagnose`, and only in `Next:`.
