---
name: agentd-dev-rev
description: Use when the engineer asks an agent to carry out an application development task, bug fix, feature implementation, performance tuning, or other code change that needs staged review before handoff.
disable-model-invocation: true
---

# agentd-dev-rev

Run development work through a strict implement → stage → independent review loop. The change is not ready until task-owned changes are staged, reviewed by a separate high-capability reviewer, and all agreed findings are resolved or explicitly reported.

## Hard Rules

1. **Never commit.** Do not run `git commit`, create commits, amend commits, push, or open a PR. Only stage the task-owned changes.
2. **Do not self-review.** Your own diff read, checklist, tests, or summary never counts as review.
3. **Use a separate review agent.** Review must be performed by an independent agent on the staged diff.
4. **Reviewer model floor is mandatory.** Use Opus 5.5 or GPT-6 with high effort. If the harness cannot set that model/effort, or no separate review agent is available, stop and tell the engineer. Do not substitute a cheaper model, your own review, or "review later."
5. **Two review rounds maximum.** Round 1 reviews the staged diff. Run Round 2 only if a Round 1 fix was blocker or major, or a minor fix changed production logic. Otherwise skip it. After Round 2, stop and report any unresolved claims.
6. **Preserve unrelated work.** Stage only files that belong to the task. Never use broad staging when unrelated dirty files exist.
7. **Dependency approval gate.** Before adding, removing, or upgrading a package, ask the engineer for approval. Do not proceed silently.
8. **Backcompat gate.** Public API, HTTP contract, DB schema, stored procedure signature, serialized shape, or config-key changes must be either explicitly required by the task or approved by the engineer.
9. **Default to TDD when practical.** For behavior changes, bug fixes, and performance tuning, write or update the focused failing test first, verify it fails for the right reason, then implement. If TDD is not practical, state why and still add focused coverage before review.

Authority, deadlines, release windows, "small change", "tests pass", or "senior said it is fine" do not override these rules.

## Workflow

1. **Understand the task and repo.** Read the target files, neighboring patterns, callers, and tests. Identify existing helpers before adding new logic.
2. **Implement with TDD and coverage.** Prefer a red → green → refactor flow: write the focused failing test, verify the expected failure, implement the minimal fix/change, then keep tests green. Changed or fixed behavior should have automated coverage. If TDD or coverage is infeasible, explain why before review.
3. **Validate locally.** Run the smallest meaningful tests/checks for the change. Fix failures caused by the task.
4. **Stage only task changes.** Inspect status first. Stage only files that belong to the task.
5. **Review Round 1.** Spawn a separate reviewer using Opus 5.5 or GPT-6 with high effort. The reviewer must inspect the staged diff, not your narrative.
6. **Triage findings.**
   - Agree: fix surgically, validate, and restage.
   - Disagree: keep the change, but record the exact claim and your evidence-based reason.
   - Unsure or product-impacting: ask the engineer.
7. **Decide on Review Round 2.**
   - Run it on the restaged diff, using the same independent review process, if a blocker or major finding was fixed, or a minor fix changed production logic.
   - Skip it if Round 1 found nothing, or every fix was minor and limited to comments, docs, formatting, behavior-preserving renames, or test-only changes. Re-run local validation before skipping.
8. **Handoff.** Report staged files, validation run, review rounds, fixed findings, disagreed findings with reasons, and unresolved claims. If Round 2 was skipped, state that and why, and list the minor fixes applied. Do not commit. Then do step 9. When step 9 asks the engineer a question, send this report first and write the step 9 block in the next message, after the answer.
9. **Verify hand-off.** Give the engineer what a fresh verify session needs. Do the parts in this order.
   - **Marker lookup first.** Look for `verify-*/SKILL.md` under any `.github/skills/` or `.claude/skills/` folder. Accept only a file whose header has `generated-by: agentd-verify-init` nested under `metadata:`. Ignore a `verify-*` skill without that marker. If several marked skills match, list them and ask which one. If no marked skill exists, write only this closing line: "No project verify skill. Run `/agentd-verify-init` once, or verify by hand." In that case dev-rev asks no base-branch question and writes no Verify block.
   - **No user-visible effect.** Decide this before the base-branch question. Write `Verify: none: <reason>` and no other field, and ask no base-branch question.
   - **Base.** Propose the remote's default branch, found with `git symbolic-ref refs/remotes/origin/HEAD`. The engineer confirms it or names another. Send the step 8 report and this question first, and write the block after the answer. Never write a `Base:` the engineer did not confirm. Then run `git merge-base HEAD <branch>`, or `git merge-base HEAD origin/<branch>` when the branch has no local branch, and write `Base: <branch> @ <sha>`. If there is nobody to answer, or the engineer does not know the branch, write `Base: unknown`. If `git merge-base` prints nothing, write `Base: unknown`. Never guess the branch.
   - **The block.** Write the block below, with these twelve lines and no `Expected:` line. The block says what changed and how to reach it, not what is right.

   ```
   Verify:
   Ticket: <number>
   Base: <base branch> @ <merge-base sha>
   Change: <the user-visible behaviour that changed, 1-2 sentences; navigation only>
   Feature: <feature file(s)>; entry points: <which ones>
   Neighbours: <features from blast-radius> | none
   Data: empty | setup: <recipe names> | bacpac: <what the data must contain> | records: <specific rows to create>
   Roles: default | <role list>
   Steps: <numbered user actions>
   Side effects: <tables or rows to check with a read-only SELECT> | none
   Diagnose: <from the diagnose hand-off, verbatim: the Confidence line, the Root cause line, and the reproduction command from the Verification line (not its expected output)> | none
   Reference anchors: <calculation reference anchors, as an index only> | none
   ```

   - **Diagnose.** If the engineer pasted a diagnose hand-off, copy its Confidence line, its Root cause line and the reproduction command from its Verification line verbatim. Leave out the expected output. With no hand-off, write `Diagnose: none`.
   - **Neighbours and Feature.** Read the paths under `Risks to cover` in a pasted `agentd-blast-radius` add-on block. Map each path to the features whose `Code folders` column in the marked skill's `features/README.md` holds a folder that contains it. Write those features as `Neighbours:`. With an add-on block, take `Feature:` from the same list. With no add-on block, write `Neighbours: none`, ask the engineer which feature to drive, and write the answer as `Feature:`. With no `Code folders` column in the map, write `Neighbours: none`, say that the map has no `Code folders` column, and ask the engineer which feature to drive. Ask this in the same message as the base-branch question.
   - **Closing line.** End with: "Run `/verify-<app>` in a fresh session, and paste the raw ticket and the Verify block", using the real skill name.
   - A failed verification returns to `/agentd-dev-rev` as a new task, with its own review rounds.
   - dev-rev never launches the app.

## Reviewer Prompt Template

Use the harness-specific equivalent of this prompt. Skip style nits unless they indicate a real bug, security risk, compatibility break, or maintainability risk.

```markdown
Do not modify the repo.
Use `mktemp -d` for any scratch work. When you finish, remove only a path that your own `mktemp` printed, with `~/.agents/bin/rm-scratch <path>` and no other removal command.
If the script is missing or refuses, leave the path and report it.

Review the staged diff for this task:

<task details>

Focus areas:
- TDD/coverage: changed/fixed behavior has tests, preferably written before implementation.
- Logic correctness: implementation meets the task requirements.
- Regression: existing behavior is not broken.
- Duplication: change does not reimplement existing helpers/patterns.
- Security: no injection, authorization bypass, secrets, or PII logging.
- Dependency: new/updated packages were explicitly approved.
- Backcompat: no unapproved public API, HTTP contract, DB schema, stored procedure signature, serialized shape, or config-key break.
- Conventions: follows existing repo patterns.
- Task-specific risks you notice.

Output:
- A ranked list of findings, most severe first. Use severity: blocker / major / minor.
- Group related findings.
- For each finding include:
  - file:line, or doc section if no line applies
  - severity
  - concrete failure scenario: exact command sequence or input, and the wrong outcome
  - why the existing tests miss it
  - suggested fix
  - verification: "verified by running" or "from reading"
- End with a short list of areas examined and found sound.
- If a focus area has no findings, say so in one line.
- Do not pad. Return only actionable findings and concise sound-area coverage.
```

## Harness Mapping

| Harness | How to review |
| --- | --- |
| Claude Code | Use a separate Task/review agent if available, explicitly selecting Opus 5.5 or GPT-6 and high effort. |
| Copilot CLI | Use a separate review-capable task agent with `model: claude-opus-5.5` or a GPT-6 model and high reasoning effort when the tool supports it. |
| Other harness | Use its independent-agent mechanism only if it can enforce the model floor and effort. Otherwise stop and report the blocker. |

The key invariant is independence plus model floor. "Fast reviewer", "same-agent review", "manual inspection", and "review after commit" are not equivalent.

## Triage Rules

| Reviewer claim | Required action |
| --- | --- |
| Clear correctness, regression, coverage, security, duplication, or convention issue | Fix, validate, restage. |
| TDD was practical but skipped for changed behavior | Add or rewrite focused tests before review when feasible; otherwise report why TDD was not practical. |
| Dependency added/upgraded without explicit approval | Stop and ask engineer before keeping it. |
| Backcompat risk not explicitly required | Stop and ask engineer or change to preserve compatibility. |
| Claim is false based on code evidence | Do not change code; report the claim and evidence for disagreement. |
| Product behavior choice | Ask engineer; do not decide silently. |
| Still unresolved after Round 2 | Stop and report as unresolved. |

## Red Flags

- "I'll commit now and review later."
- "The senior engineer asked me to commit."
- "A cheaper reviewer is better than nothing."
- "I reviewed it myself carefully."
- "Tests pass, so independent review is unnecessary."
- "I'll implement first and add tests later because coverage is enough."
- "The dependency is tiny, so approval is not needed."
- "The response shape is better, so compatibility does not matter."
- "Only one file changed, so this is too small for the loop."
- "I'll stage everything because status is noisy."

Any red flag means stop and return to the hard rules.

## Common Mistakes

| Mistake | Correct behavior |
| --- | --- |
| Committing after review passes | Keep changes staged and hand off. |
| Reviewing unstaged or narrative-only changes | Review the actual staged diff. |
| Treating tests-after as equivalent to TDD | Prefer failing test first when practical; explain exceptions. |
| Skipping Round 2 after fixing a blocker or major finding, or a minor fix that changed production logic | Restage and review once more. |
| Starting Round 2 after only minor fixes that did not change production logic | Skip it, re-run validation, and report the skip in the handoff. |
| Treating low-capability review as acceptable fallback | Stop and report the missing required reviewer. |
| Silently accepting product/backcompat decisions | Ask the engineer. |
| Hiding disagreed claims | Report them with evidence. |
