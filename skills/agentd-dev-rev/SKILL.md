---
name: agentd-dev-rev
description: Use when the engineer asks an agent to carry out an application development task, bug fix, feature implementation, performance tuning, or other code change that needs staged review before handoff.
disable-model-invocation: true
hooks:
  # Claude Code runs this hook itself while the skill is active. Do not run the command yourself.
  PreToolUse:
    - matcher: "Bash|PowerShell"
      hooks:
        - type: command
          command: '"$HOME/.agents/hooks/block-dangerous-shell.sh" --harness claude --event tool'
          timeout: 5
          onFailure: block
---

# agentd-dev-rev

Run development work through a strict implement → stage → independent review loop. The change is not ready until task-owned changes are staged, reviewed by a separate high-capability reviewer, and all agreed findings are resolved or explicitly reported.

## Hard Rules

1. **Never commit.** Do not run `git commit`, create commits, amend commits, push, or open a PR. Only stage the task-owned changes.
2. **Do not self-review.** Your own diff read, checklist, tests, or summary never counts as review.
3. **Use a separate review agent.** Review must be performed by an independent agent on the staged diff.
4. **Reviewer model floor is mandatory.** Use the model the Harness Mapping table names, or the fallback it allows, at high effort, and name the model in the report. If the harness cannot set the model or the effort, or has no separate review agent, stop and tell the engineer. Do not use a cheaper model, your own review, or "review later."
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

**Find the review rubric.** Read `../agentd-review-rubric/references/reading-the-rubric.md`, resolved from this skill's own folder, not the repository, and follow it. If it is missing, say so in one line and use the general rules. With no rubric found, follow its No rubric section. Read the criteria before you write code, and meet each one whose `Applies to` matches a path you change, and check the list again once you know the changed paths. Give the same criteria to the Round 2 reviewer.

**Find the risk tiers.** Read `../agentd-review-rubric/references/risk-tiers.md`, resolved from this skill's own folder, not the repository, and follow it for your own staged work. If it is missing, say so in one line and report no tier. The tier is reported only: it changes no Hard Rule and no step of this skill.

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

**Work item** (pasted as text, with or without a block):

- Give the reviewer the work item as pasted, with its acceptance criteria word for word, even a short list. Meet each one, or ask before you leave one out. Your restatement never replaces a listed criterion: what you add goes under `Assumptions`.
- With no list, ask or stop first, as Standalone use or a pasted block's stop condition says. Once the task is agreed, your restatement is the requirement, and what you assumed goes under `Assumptions`.

**Standalone use.** When no block is pasted, you have only a description:

1. Restate the task in two sentences: what should happen, where, and what must stay as it is.
2. Ask at most five questions. Give each question a default. Ask only what changes the code you write. Wait for the engineer's yes.
3. With nobody to answer, take the defaults. List them under `Assumptions` in the hand-off report. Never change a contract, schema or external input on a default. If a default would need one, stop, build nothing, and report the question.

## Workflow

1. **Understand the task and repo.** Read the target files, neighboring patterns, callers, and tests. Identify existing helpers before adding new logic. Then follow Inputs: read the pasted blocks, or restate the task and ask. Then set the risk tier from the task, the pasted blocks and the paths you plan to change, and say it with its reasons.
2. **Implement with TDD and coverage.** Prefer a red → green → refactor flow: write the focused failing test, verify the expected failure, implement the minimal fix/change, then keep tests green. Write the tests that a pasted block names first. Changed or fixed behavior should have automated coverage. If TDD or coverage is infeasible, explain why before review. If the code has no test project or no seam for the change, say so before you edit. Then write characterization tests of today's behavior first, or name the closest executable check (a script, a query, a manual step) in the hand-off. Never skip tests without saying so.
3. **Validate locally.** Take every command from the contract's Commands heading. Never guess a command. Run the build, the unit tests and the lint check. Fix failures caused by the task.
   - **Counts.** Check the test count, not only the exit code. A command that ran 0 tests is reported as "ran 0 tests", never as a pass. Report pass, fail and skip counts per suite.
   - **Docker.** If a suite needs Docker and Docker is not running, skip that suite, say so, and never report it as passed.
   - **Base re-run.** Re-run each failing suite on the code before your change, with the same command. Add a worktree at `HEAD` in a `mktemp -d` scratch folder: `git -c core.hooksPath=/dev/null worktree add --detach <scratch>/wt-base HEAD`. Never check it out in the repository. The option turns off the repository's hooks, so none of its code runs. The add writes a record under `.git/worktrees/`. With a `.gitmodules` file, ask the engineer once before you run `git -C <scratch>/wt-base submodule update --init`: it writes entries into the repository's `.git/config` and may need the network. With nobody to answer, skip it and mark the base `unknown:`. Say in the hand-off what you did. If the add or the update fails, the base result is `unknown:`; do not fall back to `git archive` then. Without `git-lfs`, large files stay pointers: say so. Only if the `git worktree` command is unavailable or unsupported, export `HEAD` with `git archive` into the folder instead; that export has no submodules, no LFS content and no `.git`. The copy may restore the packages the project declares, from its lock file. If the restore fails or the copy runs 0 tests, the base result is `unknown:`. Compare the failing test names and the error text. A suite is old breakage only when the same tests fail for the same reason on both. The same reason means the same error text once paths, line numbers, timestamps and IDs are removed; a suite that cannot compile or start on either side is `unknown:`, not the same. A different or extra failure is yours. If the copy fails at setup, for example because a git-ignored local settings file is missing, the base result is `unknown:`. List old breakage in the hand-off. A failing test that checks an acceptance criterion is never old breakage: the criterion is not met. Run `git worktree remove --force <scratch>/wt-base` on the worktree you added, then remove the scratch folder with `"$HOME/.agents/bin/rm-scratch" <folder>`, or say where the folder is. Never run `git worktree prune`: it removes the records of every missing worktree, not only yours.
   - **Lint.** Report only problems on lines you changed.
4. **Stage only task changes.** Inspect status first. Stage only files that belong to the task. Then set the risk tier again from the staged paths, and keep the higher one.
5. **Review Round 1.** Spawn a separate reviewer using the model the Harness Mapping table names, or the fallback it allows, at high effort. Fill the prompt in `references/reviewer-prompt.md`, resolved from this skill's own folder, not the repository, with the task, the work item as Inputs says, the pasted blocks, the contract's Risk areas, the rubric's criteria and the risk tier with its reasons. The reviewer must inspect the staged diff, not your narrative. A list you add of what to check is a hint, marked "may be incomplete": it never narrows the review.
6. **Triage findings.** First challenge them. Give every blocker and major finding to one fresh, read-only agent on the model and effort Hard Rule 4 sets. Give it each finding's `path:line`, failure scenario and evidence, and the staged diff, not your reasoning. Tell it: do not modify the repo, spawn no agents, state the model you run as, and try to disprove each finding from the code. It returns holds, refuted or unsure for each. Refuted needs `path:line` evidence: a guard, a caller that never passes the value, or a test that covers the case. A refuted verdict is evidence for your triage, not a drop. The challenge is not a review round. Run it after each round.
   - Agree: fix surgically, validate, and restage.
   - Disagree: keep the change, but record the exact claim and your evidence-based reason.
   - Unsure or product-impacting: ask the engineer.
   - Refuted by the challenge: check the evidence. If you agree, drop the finding and list it in the hand-off with the evidence. If not, triage it as usual.
   - Set aside by the reviewer: rule on each line. Treat it as a finding, or list it in the hand-off as out of scope, with your reason.
7. **Decide on Review Round 2.**
   - Run it on the restaged diff, using the same independent review process, if a blocker or major finding was fixed, or a minor fix changed production logic.
   - Skip it if Round 1 found nothing, or every fix was minor and limited to comments, docs, formatting, behavior-preserving renames, or test-only changes. Re-run local validation before skipping.
8. **Handoff.** Report staged files, the `Risk tier:` and `Read first:` lines as the risk tiers reference shapes them, validation run (with test counts), the reviewer model as the reviewer stated it (and, if a fallback was used, that the named model was not offered), review rounds, fixed findings, disagreed findings with reasons, findings dropped after the challenge with its evidence, and unresolved claims. Report the model the challenge agent stated too. Compare each stated model with the Harness Mapping table. If one is neither the table's model nor an allowed fallback, write "reviewer model mismatch" or "challenge model mismatch" in the report. The review still counts. Add the assumptions you took, any `Warn or coordinate` items, and any `Follow-on` item from a pasted block. If Round 2 was skipped, state that and why, and list the minor fixes applied. With no project rubric, add the line the rubric reference gives as the last line of this report; step 9 comes after it. Do not commit. Then do step 9. When step 9 asks the engineer a question, send this report first and write the step 9 block in the next message, after the answer.
9. **Verify hand-off.** Read `references/verify-handoff.md`, resolved from this skill's own folder, not the repository, and follow it, in its order. It finds the project's marked verify skill, asks for the base branch, and writes the `Verify:` block for a fresh verify session. With no marked verify skill, it ends with one closing line and writes no Verify block. dev-rev never launches the app.

## Harness Mapping

| Harness | Reviewer model | How to review |
| --- | --- | --- |
| Claude Code | Opus 5.5 | Use a separate Task/review agent if available. Select the model and high effort. If it cannot set both, stop (Hard Rule 4). |
| Copilot CLI | Opus 5.5 | Use a separate review-capable task agent. Select the model and high reasoning effort. If it cannot set both, stop (Hard Rule 4). |
| Other harness, including Codex | Ask the engineer | Ask which model to review with. If the harness can list the models it offers, show that list and let the engineer pick. If it cannot, ask for the model name. Use its independent-agent mechanism only if it can select that model and high effort. With nobody to answer, or no such mechanism, stop and report the blocker. |

If the named model is not offered, use a later version of the same model line (for Claude Code and Copilot CLI, a later Opus, never a smaller or faster variant), name it in the step 8 handoff, and say that the named model was not offered. For the Other harness row, the named model is the engineer's pick; if it is not offered, ask again. For any other model that is not cheaper than the named one, ask the engineer first. Never use a cheaper one. With nobody to answer, stop and tell the engineer.

The key invariant is independence plus the model the table names. "Fast reviewer", "same-agent review", "manual inspection", and "review after commit" are not equivalent.

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
| The challenge refutes a finding with `path:line` evidence | Check the evidence. Drop the finding only if you agree, and list it in the hand-off. |
| The risk tier misses a signal | Raise the tier and give the reason in the hand-off. Never lower it on a reviewer claim. It does not count toward Round 2. |
