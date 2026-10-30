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
Escape: <why tests, review or monitoring missed it: the missing test, the unchecked input or the missing alert>. Tier: supported | inferred. Or `unknown:` and who to ask. Or `none: cause not confirmed`. The last two carry no tier.

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

Fill `Escape:` in every mode. Bug: the missing test, the unchecked input or the alert that did not exist (see `references/bug.md`). Data: why the bad rows were not noticed, such as a missing constraint, a check or a report. Performance: why no test, load check or alert caught the cost. When the verdict is not Confirmed, write `Escape: none: cause not confirmed`, and never guess a reason.

With a Design concern, still propose the smallest fix for the ticket's failure, and add the design choice to Decisions needed from the engineer.

## Hand-off block

Write it when the cause is confirmed. A fresh `/agentd-dev-rev` session gets everything it needs from this block, so keep it self-contained. Inline any script it names, for example as a heredoc, and never name a path in the scratch folder: the folder is removed after the report. If there is no code fix (a one-off data problem), write `none: <reason>` under Failing test first and under Proposed fix, and put the repair under Follow-on. If the cause is in the environment (a certificate, a role, a setting), there is no code fix either: write `none: environment change` under Failing test first and under Proposed fix, name the change and its owner under Follow-on, and write `not needed: no code fix` under Blast radius. Then end the report with one line that tells the engineer to give the change to the owner, instead of a `/agentd-dev-rev` line. If the cause or the fix sits in a second repository, write the block for that repository: give its `path:line` without the repository name, name the repository under Task, read its project contract when it has one (mark the facts `unknown:` when it has none), and end with the line `Run /agentd-dev-rev in <repository> and paste the hand-off block.` One block for each repository when the fix spans both.

Put the block in chat inside a fence of four backticks with the `markdown` tag, as below, so a command fence inside it stays whole and the engineer copies the block in one piece. Keep every heading, in this order. Write `none` under an empty one. Use a bullet for each item in a list, or a number where the template shows numbers, and one sentence per item. Give every `path:line` and command in backticks.

A `## Stop condition` section goes after Follow-on only when there is a stop line: the intake Stop condition (step 1, Frame), or the line for a hand-off that is not confirmed (see below). Put each stop line in it as a bullet. With no stop line, leave the section out.

````markdown
# Hand-off block

**Confidence:** confirmed

## Task
<the problem: what goes wrong, and where it shows. A bullet for each place when there are several>

**Fixed means:** <what "fixed" looks like, and what keeps its current behaviour>

## Root cause
<the mechanism in one or two sentences>, `path:line`.
- <each place the cause sits, `path:line`, when there is more than one>

**Evidence:**
- <command and result>

## Failing test first
**Location:** <where it goes>

**Test 1**
- **Arrange:** <what it sets up>
- **Call:** <what it calls>
- **Assert:** <what it asserts>
- **Before the fix:** <the failure it gives>

## Proposed fix
1. <the smallest change, `path:line`>

## Do not change
- <what stays as it is, and why>

## Risk areas
- <contracts, schema, authorisation, generated files, callers>

## Blast radius
needed: <what the fix touches: a contract, schema, shared code or an external system, with `path:line`> | not needed: <why>

## Verification
1. Run the reproduction command:
   ```
   <the reproduction command>
   ```
2. **Before the fix:** <the expected output>
3. **After the fix:** <the expected output>

## Follow-on
<the second kind of problem> | <a data repair: its scope and how bad rows are identified; then run `/agentd-data-fix` with the work item and paste this report and the hand-off block as extra facts> | none
````

The confidence line is always the first line after the title. Add a **Test 2** with the same four bullets for each further failing test. Step 1 under Verification is always the reproduction command. Add a numbered step after it for each further check, such as a full suite or a manual check.

Blast radius is `needed:` when the fix changes a public contract (an API, a DTO, a serialised shape, a configuration key), the schema (a table, a column, a stored procedure signature), code that other features or projects share, or what an external system sends or reads. Use the contract's Risk areas and External systems and owners. Otherwise write `not needed:` and the reason. With no code fix, write `not needed: no code fix` under Blast radius.

After the hand-off block, end with this line when the cause is confirmed: Run `/agentd-dev-rev` and paste the hand-off block. The skill cannot start the next skill. When Blast radius is `needed:`, end with this line instead: Run `/agentd-blast-radius` and paste the hand-off block. Then run `/agentd-dev-rev` and paste the hand-off block and the blast-radius add-on block. When Proposed fix is `none:`, first name any other Follow-on problem in one line. Then end with this line instead of `/agentd-dev-rev`: Run `/agentd-data-fix` with the work item, and paste this report and the hand-off block as extra facts (it writes T-SQL only).

## When the cause is not confirmed

The verdict is Not confirmed, or Not reproduced. Not reproduced: you tried, and the ticket's failure did not happen. Not confirmed: you have candidate causes, but cannot show which one produces the ticket's failure. In Proposed fix, write "Next evidence needed" instead of a fix. Keep the Decisions needed and Design concern lines. For each open cause, name the evidence that would confirm or rule it out, and who has it. For a problem seen only in production, write the queries to run under Next evidence needed, each with the environment and who runs it. A pasted result goes in the Evidence table with the source `pasted by <role>`. End the report with the question, and nothing after it: keep investigating, or hand off anyway? Do not write a closing line (`/agentd-dev-rev`, `/agentd-blast-radius` or `/agentd-data-fix`) until the engineer says to hand off.

If the engineer says hand off anyway, write the block with these changes:

- `**Confidence:** hypothesis, not confirmed` replaces the confidence line. It stays the first line after the `# Hand-off block` title, so `agentd-dev-rev` reads it before any section.
- The cause under Root cause is written as a hypothesis, with the open causes listed under `**Open causes:**`.
- When Proposed fix is `none:`, leave out the `If the failing test cannot be made to fail` line from `## Stop condition`, and end with the `/agentd-data-fix` line from the Hand-off block section. Otherwise end with the `/agentd-dev-rev` line, or the `/agentd-blast-radius` line when Blast radius is `needed:`.
- One more section at the end of the block, after Follow-on: `## Stop condition`, holding this line: `If the failing test cannot be made to fail for the stated reason, stop and report back. Do not ship the fix.`

## Performance reports

Under Reproduction, give the claim, the baseline command, the number with its unit, how many runs, the spread and the limiter. The hand-off Verification section repeats the command and the baseline, so the run after the fix is comparable.
