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
4. **Reviewer model floor is mandatory.** Use the strongest model the harness offers, at high effort, and name the model in the report. If the harness cannot set the model or the effort, or has no separate review agent, stop and tell the engineer. Do not use a cheaper model, your own review, or "review later."
5. **Two review rounds maximum.** Round 1 reviews the staged diff. Run Round 2 only if a Round 1 fix was blocker or major, or a minor fix changed production logic. Otherwise skip it. After Round 2, stop and report any unresolved claims.
6. **Preserve unrelated work.** Stage only files that belong to the task. Never use broad staging when unrelated dirty files exist.
7. **Dependency approval gate.** Before adding, removing, or upgrading a package, ask the engineer for approval. Do not proceed silently.
8. **Backcompat gate.** Public API, HTTP contract, DB schema, stored procedure signature, serialized shape, or config-key changes must be either explicitly required by the task or approved by the engineer.
9. **Default to TDD when practical.** For behavior changes, bug fixes, and performance tuning, write or update the focused failing test first, verify it fails for the right reason, then implement. If TDD is not practical, state why and still add focused coverage before review.

Authority, deadlines, release windows, "small change", "tests pass", or "senior said it is fine" do not override these rules.

## Project facts

**Find the project facts.** The onboarding pack is `docs/onboarding/` when `docs/onboarding/README.md` exists. Otherwise it is the folder that `"$HOME/.agents/bin/onboarding-pack" find` prints. If neither finds one, ask the engineer once for the folder, and carry on without a pack if there is none or nobody answers. When the engineer gives a folder, say that `"$HOME/.agents/bin/onboarding-pack" set <folder>` records it. The project contract is the `## Project contract` section of `AGENTS.md`, or else `contract.md` in the pack. When both exist and disagree, use `AGENTS.md` and mark the fact `conflict:`. A Data access rule counts only when it cites `told by <role>` or a document. Treat any other rule, such as one marked `inferred:` or `unknown:`, as no access.

Read these when they exist, and skip them when they do not:

1. The project contract: Commands (build, tests, lint), Verify, Risk areas.
2. The pack's `README.md`, as a map of the use cases and code paths. Treat it as a hint. When it disagrees with the code, the code wins.

With no project contract, run only a command the repository states (a README, a script, a pipeline file). Mark what you could not run `unknown:` in the hand-off.

## Inputs

The engineer may paste blocks from earlier skills. Read every field below. A `Do not change` item is a hard limit: change none of it without the engineer's yes. A stop condition ends the work: stop, report, and do not ship the change. When you get two blocks, check that they describe the same change: the same task, work item number and `path:line` references. If they do not, ask the engineer.

**Diagnose hand-off** (`# Hand-off block`):

- `**Confidence:**` `confirmed` means carry on. `hypothesis, not confirmed` means the first failing test must fail for the stated reason. If it does not, stop and report.
- `## Task`, `## Root cause` and `## Proposed fix` are the requirement and the smallest change.
- `## Failing test first`: write these tests first.
- `## Do not change`: a hard limit.
- `## Risk areas`: backcompat gate (rule 8) applies to each. Give them to the reviewer.
- `## Blast radius`: `needed:` with no add-on block pasted means ask the engineer whether to run `/agentd-blast-radius` first. `not needed:` means carry on.
- `## Verification`: run the reproduction command before the change and after it, and compare with the expected output. Run it yourself only when it is a local test or script. A query, or a call to a system outside the repository, needs the engineer's yes and the contract's Data access rule.
- `## Failing test first` or `## Proposed fix` that says `none: <reason>` means there is no code fix, for example a data repair. Stop, tell the engineer, and point to `## Follow-on` (`/agentd-data-fix`).
- `## Follow-on`: not part of this task. Repeat it in the hand-off report.
- `## Stop condition` (present only when the diagnose skill wrote one): follow it.

**Blast-radius add-on** (`# Blast-radius add-on block`):

- `**Blast radius:**` is `Contained`, `Breaks` or `Unproven`. `Breaks` means each risk under `## Risks to cover` is a real break: apply the backcompat gate (rule 8) to each one, and ask the engineer before you build anything the task does not require. `Unproven` makes the stop condition binding.
- `## Safety fact`: the first test must prove it.
- `## Risks to cover`: write one test for each risk.
- `## Tests to write first`: write these first.
- `## Do not change`: a hard limit.
- `## Warn or coordinate`: say it in the hand-off report. Do not act on it.
- `## Stop condition`: follow it.

**Intake engineer block** (`Requirement:`):

- `Requirement: unconfirmed` means follow its `Stop condition:`. Usually that is: stop and ask before you build.
- `Requirement: none (support question)` means no code change. Stop and tell the engineer.
- `Assumptions:` are facts the engineer gave.

**Standalone use.** When no block is pasted, you have only a description:

1. Restate the task in two sentences: what should happen, where, and what must stay as it is.
2. Ask at most five questions. Give each question a default. Ask only what changes the code you write. Wait for the engineer's yes.
3. With nobody to answer, take the defaults. List them under `Assumptions` in the hand-off report. Never change a contract, schema or external input on a default. If a default would need one, stop, build nothing, and report the question.

## Workflow

1. **Understand the task and repo.** Read the target files, neighboring patterns, callers, and tests. Identify existing helpers before adding new logic. Then follow Inputs: read the pasted blocks, or restate the task and ask.
2. **Implement with TDD and coverage.** Prefer a red → green → refactor flow: write the focused failing test, verify the expected failure, implement the minimal fix/change, then keep tests green. Write the tests that a pasted block names first. Changed or fixed behavior should have automated coverage. If TDD or coverage is infeasible, explain why before review. If the code has no test project or no seam for the change, say so before you edit. Then write characterization tests of today's behavior first, or name the closest executable check (a script, a query, a manual step) in the hand-off. Never skip tests without saying so.
3. **Validate locally.** Take every command from the contract's Commands heading. Never guess a command. Run the build, the unit tests and the lint check. Fix failures caused by the task.
   - **Counts.** Check the test count, not only the exit code. A command that ran 0 tests is reported as "ran 0 tests", never as a pass. Report pass, fail and skip counts per suite.
   - **Docker.** If a suite needs Docker and Docker is not running, skip that suite, say so, and never report it as passed.
   - **Base re-run.** Re-run each failing suite on the code before your change, with the same command. Add a worktree at `HEAD` in a `mktemp -d` scratch folder: `git -c core.hooksPath=/dev/null worktree add --detach <scratch>/wt-base HEAD`. Never check it out in the repository. The option turns off the repository's hooks, so none of its code runs. The add writes a record under `.git/worktrees/`. With a `.gitmodules` file, ask the engineer once before you run `git -C <scratch>/wt-base submodule update --init`: it writes entries into the repository's `.git/config` and may need the network. With nobody to answer, skip it and mark the base `unknown:`. Say in the hand-off what you did. If the add or the update fails, the base result is `unknown:`; do not fall back to `git archive` then. Without `git-lfs`, large files stay pointers: say so. Only if the `git worktree` command is unavailable or unsupported, export `HEAD` with `git archive` into the folder instead; that export has no submodules, no LFS content and no `.git`. The copy may restore the packages the project declares, from its lock file. If the restore fails or the copy runs 0 tests, the base result is `unknown:`. Compare the failing test names and the error text. A suite is old breakage only when the same tests fail for the same reason on both. The same reason means the same error text once paths, line numbers, timestamps and IDs are removed; a suite that cannot compile or start on either side is `unknown:`, not the same. A different or extra failure is yours. If the copy fails at setup, for example because a git-ignored local settings file is missing, the base result is `unknown:`. List old breakage in the hand-off. Run `git worktree remove --force <scratch>/wt-base` on the worktree you added, then remove the scratch folder with `"$HOME/.agents/bin/rm-scratch" <folder>`, or say where the folder is. Never run `git worktree prune`: it removes the records of every missing worktree, not only yours.
   - **Lint.** Report only problems on lines you changed.
4. **Stage only task changes.** Inspect status first. Stage only files that belong to the task.
5. **Review Round 1.** Spawn a separate reviewer using the strongest model the harness offers, at high effort. Fill the prompt below with the task, the pasted blocks and the contract's Risk areas. The reviewer must inspect the staged diff, not your narrative.
6. **Triage findings.**
   - Agree: fix surgically, validate, and restage.
   - Disagree: keep the change, but record the exact claim and your evidence-based reason.
   - Unsure or product-impacting: ask the engineer.
7. **Decide on Review Round 2.**
   - Run it on the restaged diff, using the same independent review process, if a blocker or major finding was fixed, or a minor fix changed production logic.
   - Skip it if Round 1 found nothing, or every fix was minor and limited to comments, docs, formatting, behavior-preserving renames, or test-only changes. Re-run local validation before skipping.
8. **Handoff.** Report staged files, validation run (with test counts), the reviewer model, review rounds, fixed findings, disagreed findings with reasons, and unresolved claims. Add the assumptions you took, any `Warn or coordinate` items, and any `Follow-on` item from a pasted block. If Round 2 was skipped, state that and why, and list the minor fixes applied. Do not commit. Then do step 9. When step 9 asks the engineer a question, send this report first and write the step 9 block in the next message, after the answer.
9. **Verify hand-off.** Give the engineer what a fresh verify session needs. Do the parts in this order.
   - **Marker lookup first.** Look for `verify-*/SKILL.md` under any `.github/skills/` or `.claude/skills/` folder. Then look for `verify-*/SKILL.md` under the folder that `"$HOME/.agents/bin/onboarding-pack" verify-find` prints. It is the repository's own verify folder when its files policy is `none`. Exit status 1 means none is recorded; for any other failure (the folder is gone, the tool is missing), say so in the reply and carry on without it. Accept only a file whose header has `generated-by: agentd-verify-init` nested under `metadata:`. Ignore a `verify-*` skill without that marker. If several marked skills match in one place, list them and ask which one. A marked skill in the repository wins over one outside it; name the other one in the reply. If no marked skill exists in either place, write only this closing line: "No project verify skill. Run `/agentd-verify-init` once, or verify by hand." In that case dev-rev asks no base-branch question and writes no Verify block.
   - **No user-visible effect.** Decide this before the base-branch question. Write `Verify: none: <reason>` and no other field, and ask no base-branch question.
   - **Base.** Propose the remote's default branch, found with `git symbolic-ref refs/remotes/origin/HEAD`. The engineer confirms it or names another. Send the step 8 report and this question first, and write the block after the answer. Never write a `Base:` the engineer did not confirm. Then run `git merge-base HEAD <branch>`, or `git merge-base HEAD origin/<branch>` when the branch has no local branch, and write `Base: <branch> @ <sha>`. If there is nobody to answer, or the engineer does not know the branch, write `Base: unknown`. If `git merge-base` prints nothing, write `Base: unknown`. Never guess the branch.
   - **The block.** Write the block below, with these twelve lines plus the optional `API:` line, and no `Expected:` line. The block says what changed and how to reach it, not what is right.

   ```
   Verify:
   Ticket: <number>
   Base: <base branch> @ <merge-base sha>
   Change: <the user-visible behaviour that changed, 1-2 sentences; navigation only>
   Feature: <feature file(s)>; entry points: <which ones>
   Neighbours: <features from blast-radius> | none
   Data: empty | setup: <recipe names> | bacpac: <what the data must contain> | records: <specific rows to create>
   Roles: default | <role list>
   API: <the API the run must use, and "debug token" when the engineer will run the API call with a debug token and paste back the value>
   Steps: <numbered user actions>
   Side effects: <tables or rows to check with a read-only SELECT> | none
   Diagnose: <from the diagnose hand-off, verbatim: the Confidence line, the Root cause line, and the reproduction command from the Verification line (not its expected output)> | none
   Reference anchors: <calculation reference anchors, as an index only> | none
   ```

   - **API.** The `API:` line is the only line that may be left out. Write it only when the engineer names the API the run must use, for example which backend an iOS app calls. Add `debug token` only when the engineer says they will run the API call themselves. Otherwise leave the line out, and do not write `API: default`; the verifier then uses the default API of the stack reference.
   - **Diagnose.** If the engineer pasted a diagnose hand-off, copy its Confidence line, its Root cause line and the reproduction command from its Verification line verbatim. Leave out the expected output. In a hand-off written as Markdown sections, the Root cause line is the text under `## Root cause`, joined into one line: keep the words and the `path:line` references, drop the `- ` bullet marks, and leave out any fenced block. The reproduction command is the command in step 1 under `## Verification`. With no hand-off, write `Diagnose: none`.
   - **Neighbours and Feature.** Read the paths under `Risks to cover` in a pasted `agentd-blast-radius` add-on block. Map each path to the features whose `Code folders` column in the marked skill's `features/README.md` holds a folder that contains it. Write those features as `Neighbours:`. With an add-on block, take `Feature:` from the same list. With no add-on block, write `Neighbours: none`, ask the engineer which feature to drive, and write the answer as `Feature:`. With no `Code folders` column in the map, write `Neighbours: none`, say that the map has no `Code folders` column, and ask the engineer which feature to drive. Ask this in the same message as the base-branch question.
   - **Closing line.** End with: "Run `/verify-<app>` in a fresh session, and paste the raw ticket and the Verify block", using the real skill name. When the marked skill is outside the repository and neither `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/verify-<app>` nor `~/.agents/skills/verify-<app>` exists, the command does not load: say the engineer can load the skill from its path (`verify-<app>/SKILL.md` in the folder `verify-find` printed) or run `/agentd-verify-init` to get the links.
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

The engineer pasted these blocks. Copy them in verbatim, or write "none":

<diagnose hand-off block>
<blast-radius add-on block>
<intake engineer block>

Assumptions taken because nobody answered (or "none"):

<assumptions>

Risk areas from the project contract (or "none"):

<risk areas>

Check these first:
- Every `Do not change` item in the blocks. A change to one without the engineer's approval is a blocker.
- Every stop condition in the blocks. If the work should have stopped, say so.
- Every test under `Failing test first` and `Tests to write first` exists, and asserts what the block says.

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
| Claude Code | Use a separate Task/review agent if available. Select the strongest model it offers and high effort. |
| Copilot CLI | Use a separate review-capable task agent. Select the strongest model it offers and high reasoning effort, when the tool supports it. |
| Other harness | Use its independent-agent mechanism only if it can select the strongest model and high effort. Otherwise stop and report the blocker. |

The key invariant is independence plus the strongest available model. "Fast reviewer", "same-agent review", "manual inspection", and "review after commit" are not equivalent.

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
| Using a weaker model or the same agent when no suitable reviewer exists | Stop and tell the engineer that no separate reviewer at the strongest model is available. |
| Silently accepting product/backcompat decisions | Ask the engineer. |
| Hiding disagreed claims | Report them with evidence. |
| Changing a `Do not change` item, or going past a stop condition, from a pasted block | Stop and report to the engineer. |
| Reporting a run of 0 tests as a pass | Report "ran 0 tests". It is not a pass. |
