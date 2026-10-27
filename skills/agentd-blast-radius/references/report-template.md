# Report template

The report and the add-on block go in chat. Fill every heading. Write `none` for an empty one. Nothing is saved in the repository.

## Report

```markdown
## Blast radius: <one-line title>

Input: proposed change | branch diff (<base>...<head>) | staged diff | branch diff plus staged (<merge-base> to the index)
Verdict: Contained | Breaks | Unproven

### What changes
<one sentence>. Touches: <symbols, columns, fields, routes, files, settings>.
Behaves differently without the change saying so: <what>, or none.

### The safety fact
Fact: <one claim that a run can show true or false>, or `none: <why>`.
Tier: confirmed | supported | inferred | unknown, or n/a when the fact is none
Proof: <the command or script, inline, and its output, verbatim, secrets and personal data removed>
If it was not proven: what blocked the run, and the evidence needed, from whom.

### Risks
| # | How it breaks | Where (path:line) | Likelihood | Cost | Tier | How to check |
|---|---|---|---|---|---|---|

### Cleared
- <risk you checked>, cleared because <evidence>. Tier: ...

### Not checked
- <what you did not run or could not verify, and why>

### Before you merge
The cheapest test or reproduction that would catch the real break, including the proof script. For Breaks, say first what must change in the approach.

Scratch folder: `<path>`, removed after this report. Or: `Scratch folder: none`.
```

Keep the open and the confirmed risks, of any tier, in the Risks table. Keep the ones you ruled out in Cleared. Do not mix them. A test that encodes the old behaviour goes in Risks as a cost to plan for, not as a break in production. Give a real likelihood (high, medium, low, and why) and a real cost (what the user or the data sees).

## Add-on block

Write it when the verdict is Contained or Breaks. For Unproven, write it only after the engineer says to hand off anyway (see below). A fresh `/agentd-dev-rev` session gets everything it needs from this block and the diagnose hand-off block, so keep it self-contained. Inline any script it names, for example as a heredoc, and never name a path in the scratch folder: the folder is removed after the report. The engineer pastes it next to the diagnose block, when there is one.

Put the block in chat inside a fence of four backticks with the `markdown` tag, as below, so a script fence inside it stays whole and the engineer copies the block in one piece. Keep every heading, in this order. Write `none` under an empty one. Use a bullet for each item in a list, or a number where the template shows numbers, and one sentence per item. Give every `path:line` and command in backticks.

````markdown
# Blast-radius add-on block

**Blast radius:** Contained | Breaks | Unproven

## Safety fact
<claim>, or `none: <why>`.
- **Tier:** <tier>
- **Proof:** the inline script or command, and its output:
  ```
  <script or command>
  <output>
  ```

## Risks to cover
- <how it breaks>, `path:line`. Tier: <tier>.

## Tests to write first
1. <the test that proves the safety fact>
2. <one test for each risk>

## Do not change
- <contracts, columns, signatures and shapes that must stay as they are>

## Warn or coordinate
- <owner, mobile release, DBA, and why>, or none

## Stop condition
<when dev-rev must stop and report back>, or none
````

When the verdict is Contained or Breaks, end with this line after the block: Run `/agentd-dev-rev` and paste the diagnose hand-off block, when there is one, and this add-on block. The skill cannot start the next skill.

## When the verdict is Unproven

In Risks, write the evidence that would confirm or rule out each open risk, and who has it. Write no add-on block yet. End the report with the question, and nothing after it: get more evidence, or hand off anyway? Do not write the `/agentd-dev-rev` line until the engineer says to hand off.

If the engineer says hand off anyway, write the block with these changes:

- `**Blast radius:** Unproven` is the verdict line. It stays the first line after the `# Blast-radius add-on block` title, so `agentd-dev-rev` reads it before any section.
- If no run confirmed the safety fact, write it as a claim that nobody has confirmed. Its tier is what you found (`supported`, `inferred:` or `unknown:`), never `confirmed`. A fact that a run confirmed keeps `confirmed`. With no safety fact, write `none: <why>` under Safety fact, tier `n/a`, and `**Proof:** n/a` with no fence.
- The first test in Tests to write first must prove the fact. When the fact is confirmed or there is none, it covers the most severe open risk.
- Under Stop condition: `If the first test cannot prove the fact or clear the most severe open risk, stop and report back. Do not ship the change.`
