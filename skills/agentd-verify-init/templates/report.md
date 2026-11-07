# Evidence report

Used in Flow step 6 of `agentd-verify-init`. Copy everything under `## Report` and `## Results` of this file into the
generated skill's Report section, including the notes and the Order of results. The engineer pastes the report into the `agentd-pr-prep` Testing section. Write every label, in this
order.

## Report

```
Verify result: pass | fail | disagree | blocked
Ticket and branch: <...>; HEAD <sha> plus working-tree changes: <n> staged, <n> unstaged, <n> untracked files; app-code fingerprint <short hash>
Environment: container <name>, image <tag>, data <empty | setup recipes | bacpac file name and date>, DbUp scripts applied <n>
Ticket reading vs Change line: agree | conflict: <how they differ>
Expectations (written before driving): <each expected result, with its source: ticket | diagnose | base code path:line | engineer>
Steps:
  1. <action> -> <what was seen> (evidence: <file>)
Three-way match: <value>: screen <x> | API <y> | database <z> -> match | mismatch
Recomputed figures: <figure>: recomputed <x> from <rows>, screen <y> | not a calculation ticket
Neighbours checked: <feature>: pass | fail | none
Edges tried: <case>: <result> | none, and why
Reference conflicts: <anchor>: reference says <x>, base code <path:line> says <y> | none
Side effects: <SELECT> -> <counts and IDs only>
Coverage: <n> items in the change, <n> driven; continued in Flow step 11: <items the engineer picked> | none. Then a table with the columns Item, Files, Driven (step) and Reason not driven.
  Or: not checked: run stopped at Flow step <n>
Not verified: <what, and why; each item still not driven, as "in the change, not driven"; a feature the ticket touches that the engineer left out, and a `Steps:` step skipped for that reason, as "left out by the engineer in step 2"; a neighbour that is index only, as "index only: no feature file"; a user guide change, as "user guide changed; not checked in a verify run">
Evidence folder: <path>
```

- `Steps:` has one numbered line per action, each with the evidence file it produced.
- Under Neighbours checked and Edges tried, a case you did not try reads `not tried`, and the report lists it under
  Not verified.
- A Reference conflicts entry is a documentation finding. It never changes the result.
- Side effects lists counts and IDs only, never row values.

## Results

| Result | When | Next |
|---|---|---|
| `pass` | Every expectation met, every three-way match agrees, every recomputed figure matches, neighbours and edges pass. | Paste into the PR. |
| `fail` | Any observed result differs from an expectation. This includes an expectation with source `engineer` or one added in Flow step 11; such a failure is not tagged "outside the ticket". Any three-way mismatch (screen, API or database); any recomputed figure differs; any neighbour or edge fails. A neighbour or edge failure is tagged "outside the ticket; may be pre-existing, not checked on the base". | The engineer runs `/agentd-dev-rev` again with the report (a new task with its own review rounds). |
| `disagree` | The verifier's reading of the raw ticket conflicts with the `Change:` line, and no check failed that is independent of the reading. The verifier still drives, against its own reading, and reports both readings. | The engineer decides which reading is right. Verifier's reading: the result follows from the recorded checks, with no new drive. `Change:` reading: run `/verify-<app>` again in a fresh session, with the engineer's decision added under the raw ticket. |
| `blocked` | The run could not finish, or a core check is in Not verified: an expectation (including one with source `engineer` or one added in Flow step 11), a three-way leg for a ticket value, or a recomputed figure on a calculation ticket. Neighbours and edges not tried go in Not verified and still allow `pass`, and so do Flow step 11 items that hold no written expectation, and features the engineer left out in step 2. | The report names the cause (Docker down, no sign-in, missing data, a role mismatch, a journal conflict). |

**Order of results.** One result per report, picked in this order:

1. `fail`, when any check failed that does not depend on the contested reading (a three-way mismatch, a recomputed
   figure, a neighbour or an edge, an expectation both readings share, or an expectation with source `engineer` or
   one added in Flow step 11). It wins over `disagree` and `blocked`. A run
   that stopped after a failure reports `fail` and lists what did not run under Not verified.
2. `disagree`.
3. `blocked`.
4. `pass`.

A Reference conflicts entry never changes the result.

Neighbours and edges not tried go in Not verified and still allow pass. So do Flow step 11 items that hold no written
expectation, and features the engineer left out in step 2 (they get no expectations). Only three core checks make the result `blocked` when not done: an expectation (any source, including
one added in Flow step 11), a three-way leg for a ticket value, and a recomputed figure on a calculation ticket.

A failed run goes back to `/agentd-dev-rev` as a new task, with the report pasted in. The verify skill never edits
code.
