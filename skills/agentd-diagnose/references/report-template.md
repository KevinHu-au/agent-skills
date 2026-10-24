# Report template

The report and the hand-off block go in chat. Fill every heading. Write `none` for an empty one. Nothing is saved in the repository.

## Report

```markdown
## Diagnosis: <one-line title>

Mode: bug | data | performance, because <reason>. Started as <mode>. (Write this last sentence only if you switched.)
Verdict: Confirmed | Not confirmed | Not reproduced

### Problem
Expected: ... Actual: ... Seen: <environment, user, data>. Since: <date or release>.
The ticket's theory: ... (tested: true | false | not tested)

### Reproduction
Command or steps: ...
Output (verbatim, secrets and personal data removed): ...
If it did not reproduce: what blocked it, and the evidence needed from the engineer.

### Root cause
<the mechanism in one or two sentences>, `path:line`. Tier: confirmed | supported | inferred.

### Evidence
| Claim | Tier | Source (path:line, command or query) |
|---|---|---|

### Competing causes
- Ruled out: <cause>, because <evidence>.
- Open: <cause>. Needs: <evidence>, from <who or where>.

### Proposed fix
The smallest change the evidence supports.
Does not change: ...
Decisions needed from the engineer: <a product or rule choice the fix depends on, for example how to round>, or none.
Risk areas touched: ... (the contract's Risk areas, plus callers found by search)
Design concern: <the shared state or coupling, and why one small fix may not be enough>. Tier: confirmed | supported | inferred. Or none.

### Not checked
- <what you did not run or could not verify, and why>

Scratch folder: `<path>`, removed after this report. Or: `Scratch folder: none`.
```

With a Design concern, still propose the smallest fix for the ticket's failure, and add the design choice to Decisions needed from the engineer.

## Hand-off block

Write it when the cause is confirmed. A fresh `/agentd-dev-rev` session gets everything it needs from this block, so keep it self-contained. Inline any script it names, for example as a heredoc, and never name a path in the scratch folder: the folder is removed after the report. If there is no code fix (a one-off data problem), write `none: <reason>` for Failing test first and Proposed fix, and put the repair in Follow-on.

```
Confidence: confirmed
Task: <one paragraph: the problem, and what "fixed" looks like>
Root cause: <the mechanism>, `path:line`. Evidence: <command and result>.
Failing test first: <where it goes; what it arranges; what it calls; what it asserts; the failure it gives before the fix>
Proposed fix: <the smallest change>
Do not change: <what stays as it is>
Risk areas: <contracts, schema, authorisation, generated files, callers>
Verification: <the reproduction command; the expected output before and after the fix>
Follow-on: <the second kind of problem> | <a data repair: its scope and how bad rows are identified; then run `/agentd-data-fix` with the work item and paste this report and the hand-off block as extra facts> | none
```

After the hand-off block, end with this line when the cause is confirmed: Run `/agentd-dev-rev` and paste the hand-off block. The skill cannot start the next skill. When Proposed fix is `none:`, first name any other Follow-on problem in one line. Then end with this line instead of `/agentd-dev-rev`: Run `/agentd-data-fix` with the work item, and paste this report and the hand-off block as extra facts (it writes T-SQL only).

## When the cause is not confirmed

The verdict is Not confirmed, or Not reproduced. Not reproduced: you tried, and the ticket's failure did not happen. Not confirmed: you have candidate causes, but cannot show which one produces the ticket's failure. In Proposed fix, write "Next evidence needed" instead of a fix. Keep the Decisions needed and Design concern lines. For each open cause, name the evidence that would confirm or rule it out, and who has it. End the report with the question, and nothing after it: keep investigating, or hand off anyway? Do not write a closing line (`/agentd-dev-rev` or `/agentd-data-fix`) until the engineer says to hand off.

If the engineer says hand off anyway, write the block with these changes:

- `Confidence: hypothesis, not confirmed` replaces the first line, so `agentd-dev-rev` reads it before anything else.
- The cause under Root cause is written as a hypothesis, with the open causes listed.
- When Proposed fix is `none:`, leave out the `If the failing test cannot be made to fail` line, and end with the `/agentd-data-fix` line from the Hand-off block section. Otherwise end with the `/agentd-dev-rev` line.
- One more line at the end: `If the failing test cannot be made to fail for the stated reason, stop and report back. Do not ship the fix.`

## Performance reports

Under Reproduction, give the claim, the baseline command, the number with its unit, how many runs, the spread and the limiter. The hand-off Verification line repeats the command and the baseline, so the run after the fix is comparable.
