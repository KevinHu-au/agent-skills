# Comment template

The shapes for the Azure DevOps comment, the support-question output, the engineer block and the closing lines.
Azure DevOps renders Markdown in comments.

## Rules for the comment

- It is for the customer and the team. Write it in the language of the work item. When the description and the
  replies use different languages, use the description's. Translate the headings and the fixed phrases too. The
  engineer block is not translated.
- Everything above Technical notes uses the customer's words: no file paths, no internal names, no code terms. Use the
  glossary, when there is one, to turn code names back into the customer's words.
- About 250 words above Technical notes, and at most five questions.
- No secrets. No personal data beyond what the work item gives. Add none from the code or the data.
- The comment never states the code's reading as fact. A `conflict:` goes in the engineer block. Add at most one
  hedged line: in Today, or in Our understanding when there is no Today.
- The verdict and `Requirement:` never appear in the comment. They belong to the engineer block.
- The first line `Work item <number>`: SKILL.md says where the number comes from. Leave it out when there is no number.
- Use the work item's own words. The glossary helps you read the code; it does not rename what the customer said.
- In an Actionable comment, a question for the customer that has a safe default becomes an assumption: "We assume
  ... Tell us if not." List only assumptions the customer would notice if they were wrong. Technical defaults go
  under Assumptions in the engineer block.

## Actionable

Always all seven headings, also when there is no question. A heading with nothing to say holds `none`.

```markdown
Work item <number>

### Our understanding
<Two or three sentences: who is affected, what they cannot do today, the outcome they want.>

### Today
<What the system does now. For a bug, data or performance work item: the actual behaviour reported, where and
when, and how to reproduce.>

### Change
<The behaviour wanted. For a bug, data or performance work item: the expected behaviour, not a fix.>

### Acceptance checks
- When <action>, <result the customer can see>.

### Out of scope
- <What this work item does not change. For a mixed work item, the other part: "raise it as a separate work item".>

### Assumptions
- We assume <default>. Tell us if not.

### Technical notes
For the team. The path through the code, in layer order:
frontend component or service → endpoint → command or query → handler → repository → table or stored procedure
- <layer>: `path:line`
- A layer the stack does not have: `none (<why>)`. Give the reason once for all such layers.
- A layer that should exist but was not found: `unknown: <who to ask>`.

Risk areas: <from the project contract, or none. With no contract: "unknown: no project contract".>
```

Today states what the customer reported. When the code seems to disagree, keep the report and add one hedged line,
such as "Our first check of the system suggests coupons are taken off; we will confirm this when we reproduce it."
The `conflict:` itself goes in the engineer block. Intake runs nothing, so the code's reading is never stated as fact.

## Not actionable yet

```markdown
Work item <number>

### Our understanding
<Two or three sentences.>

### Questions
1. <Question>
   Why it matters: <what changes with the answer>. Our default: <the default, or "none, we need your answer">.

### Next
Once you answer, we <what happens next>.

### Technical notes
Optional. For the team: the code facts found so far, in the same layer order and with the same rules as above.
```

A customer question with a safe default stays a question, with `Our default:`. Only an Actionable comment turns such
questions into assumptions.

When there is no question for the customer (every open item is for the engineer or is an investigation step), the
comment has no Questions section. The text under Next is "We are investigating." The comment then has Our
understanding, Next, and optionally Technical notes.

## Support question

A support question the code answers gets no comment. In chat, give the code facts, each with `path:line` and what it
shows, then the engineer block with `Requirement: none (support question)` and `Stop condition: none`.
This takes the place of the rule for nobody to answer. Do not draft the answer. The last line: "Answer the
customer." Add "Then run `/agentd-diagnose`." only when the facts suggest a fault.

An unclear support question uses the Not actionable yet shape and its closing lines.

## Engineer block

Chat only. The engineer pastes it into the next skill together with the comment.

```text
Type: <bug | enhancement | data | performance | support question>
  (mixed: Type: <main type>, also <other type>: <the other part>)
Verdict: Actionable | Not actionable yet. <One-line reason.>
Requirement: confirmed | unconfirmed | none (support question)
Assumptions: <each default taken, or none>
Stop condition: <when unconfirmed: the point at which the next skill must stop and ask, for example "stop and ask
  before changing anything beyond the sort order". For Not actionable yet: "do not build until <the blocking
  question> is answered". Otherwise none.>
Questions for the engineer: <each with its answer once given, or none>
Conflicts: <conflict: the work item says X; path:line shows Y. Or none.>
Investigation: <steps the engineer or the team can take: a log search, a production query by the DBA, a deployment
  check. Or none. Evidence only the customer has, such as a record ID, is a question in the comment.>
Design concern: <or none>
Next: <one target from SKILL.md>
```

## Closing lines

- **Before an answer:** the last line is the gate question: "Is our understanding right? Confirm, correct it, or send
  the questions first."
- **Confirm on Actionable:** show the engineer block again with `Requirement: confirmed` and `Stop condition: none`.
  Then: "Run `/<next>` and paste the comment and the engineer block." For two targets:
  "Run `/agentd-blast-radius`, then `/agentd-dev-rev`, and paste the comment and the engineer block into each."
- **Confirming a Not actionable yet** means "post the questions". `Requirement:` stays `unconfirmed` and the
  "do not build until" stop condition stays. Show the engineer block again, unchanged. The last line is the post
  line, or the investigation line when the comment has no customer questions.
- **After correct:** revise the comment and the block, then ask the gate question again.
- **Post line**, after "send the questions first" and for every Not actionable yet with customer questions: "Post the
  comment in Azure DevOps. When the replies come, run `/agentd-intake` again and paste the work item, the comment and
  the replies."
- **Investigation line**, for a Not actionable yet with no customer questions: "Post the comment in Azure DevOps.
  Do the Investigation steps, then run `/agentd-intake` again and paste the work item, the comment and the findings."
- **With nobody to answer:** no question. The block says `Requirement: unconfirmed`, lists the assumptions and gives a
  stop condition. Show the block once, then the run line (Actionable), or the post or investigation line (Not
  actionable yet).
