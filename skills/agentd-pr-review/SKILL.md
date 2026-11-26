---
name: agentd-pr-review
description: Use when the engineer is the approver of a teammate's PR and wants it reviewed against the work item when given, before voting. Checks the requirement, missing parts, breakage and the tests, and writes paste-ready comments marked Block, Major or Minor, each with path:line. Edits no code.
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

# agentd-pr-review

Review a teammate's PR against its work item, or against its inferred intent when there is none, then stop. Spend
your time on what the work item really asks for, and on what the PR should have changed but did not.

## Prerequisite

Run `git rev-parse --show-toplevel`. If it fails, stop with one line: `agentd-pr-review needs a git repository. Run it
inside one.` Work from the repository root.

- **The PR branch.** The engineer has checked it out. Do not change branches.
- **The work item.** The engineer pastes the title, description and acceptance criteria. Screenshots in the
  description are part of the requirement: read them for the screens, records and behaviour they show. The engineer may
  also paste the PR description, the parent feature, comments, or several work items, one paste each. With no work
  item, ask for it once, unless the engineer has already said there is none, and say that "no work item" is an answer.
  If the engineer says there is no work item, review in no-work-item mode: Flow steps 2 and 7, Severity, Output and the
  report template say what changes, and the PR author takes the place of the work item creator everywhere. If none comes and
  the engineer does not say there is none, stop. Do not review against the diff alone without that answer.
- **The base.** Propose the remote's default branch from `git symbolic-ref refs/remotes/origin/HEAD`. The engineer
  confirms it or names the PR's target branch. Never guess the base. Read the change with `git diff <base>...HEAD`.
- **Branch state.** If the working tree has uncommitted changes, say they are not part of the PR. Do not ask the engineer
  to stash them. Read files with `git show HEAD:<path>`, and run the build and tests in a worktree at `HEAD`,
  `<scratch>/wt-head` (see Base re-run), so the changes stay as they are. Name the branch and the commit that `HEAD`
  is on. If it is not the PR's branch, ask. If the branch is behind `origin/<branch>` as last fetched, say so and give
  the command. Never run `git fetch`, `git pull`, `git checkout`, `git switch` or `git stash`.
- **Find the project facts.** The onboarding pack is `docs/onboarding/` when `docs/onboarding/README.md` exists.
  Otherwise it is the folder that `"$HOME/.agents/bin/onboarding-pack" find` prints. If neither finds one, ask the
  engineer once for the folder, and carry on without a pack if there is none or nobody answers. When the engineer
  gives a folder, say that `"$HOME/.agents/bin/onboarding-pack" set <folder>` records it. The project contract is
  the `## Project contract` section of `AGENTS.md`, or else `contract.md` in the pack. When both exist and disagree,
  use `AGENTS.md` and mark the fact `conflict:`. A Data access rule counts only when it cites `told by <role>` or a
  document. Treat any other rule, such as one marked `inferred:` or `unknown:`, as no access.
- **What to read there.** The contract's Commands, Risk areas, and External systems and owners, and the pack's
  `README.md`. When the pack disagrees with the code, the code wins.
- **Find the review rubric.** Read `../agentd-review-rubric/references/reading-the-rubric.md`, resolved from this
  skill's own folder, not the repository, and follow it. If it is missing, say so in one line and use the general rules.
  Read `../agentd-review-rubric/references/risk-tiers.md` the same way. If it is missing, say so and report no tier.

## Flow

1. **Read the inputs.** Say in one sentence what the PR is for.
2. **Build the requirement.** Write what "done" means for this PR in a few lines. Split it into what the work item says
   and what you assumed. Acceptance criteria are often incomplete or missing. Do not stop: review against your stated
   assumptions, and write each gap as a question for the work item creator. In no-work-item mode, do step 3 first,
   then infer the intent instead and use it as the requirement. Call it the inferred intent, not an `inferred:` finding, and take it from the
   branch name, the commit messages, a pasted PR description and the names of new tests. Then check the PR against its own claims: a half-finished change,
   such as a rename done in some places only, a new field nothing reads or a flag nothing turns on, is a finding.
3. **Read the change.** List the files, symbols, queries, routes and settings it adds, changes or removes. Read
   `git log` for those files. Note what behaves differently without the diff saying so. Set the risk tier of the PR.
4. **Check each criterion.** Check each acceptance criterion the work item lists as written; your restatement never
   replaces one. Judge the code at `HEAD`, not the diff: a criterion the diff does not touch still counts. When only
   untouched code fails it, the base fails it too: it is at most Major, never Block. It is out of scope, not a finding,
   only when the engineer or the PR description says another PR delivers it. When one names a group ("startup
   requests"), list its members from the code and check each. Past 10 members, search for those that lack the change; if
   you cannot, mark the criterion partly checked. For each part of the requirement: covered, partly covered or not
   covered, with `path:line` evidence and the test that covers it, if there is one.
   Then check each rubric criterion whose `Applies to` matches a changed path, and cite its criterion ID.
5. **Search for siblings.** For each pattern the PR changes, search for similar places the PR did not touch: other
   pages, sibling components, parallel API handlers, the matching stored procedure, view or DTO. Find them from the
   code, not the work item, because the work item may not name them. A place that likely needs the same change is
   Major, and it is also a question for the work item creator.
6. **Check for breakage.** Read `../agentd-blast-radius/references/surfaces.md`, resolved from this skill's own folder,
   not the repository. Check only the surfaces the change touches; a sign-in, payment or callback flow always touches
   timing and state. For a .NET, React or iOS project also read `dotnet.md`, `react.md` or `ios.md` there. If
   `surfaces.md` is missing, say so in one line and check these instead: wire shapes, data, configuration and flags,
   indirection, timing and state, other readers of the same bytes, generated files, libraries and the runtime,
   authorisation reach, external systems, and tests that encode the old behaviour. Callers found by search are the
   start, not the finding. In the changed code, also look for swallowed errors: an empty `catch`, an error turned into
   `null` or an empty list, a fallback that hides a failure, a lost stack trace, or no rollback when a step fails. On a wide PR, read-only sub-agents may run steps 5 and 6. Give them the acceptance criteria
   as pasted, or in no-work-item mode the inferred intent marked as one, and say your requirement may be wrong. Each
   returns a short summary with `path:line` evidence.
7. **Run plan.** List the commands in chat, as Running commands says, and run them without waiting for a confirmation.
   Ask in the report, under Questions for you, whether another PR delivers each criterion not met in untouched code,
   and in no-work-item mode, whether the inferred intent is right; until then, treat none as delivered elsewhere. The
   answers come after the report, when the worktrees are gone. If the engineer corrects the intent, rebuild step 2 and
   redo steps 4 to 9: add the worktrees again, run the tests, challenge and write a new report. A correction in the
   engineer's words is still the inferred intent. If the engineer pastes the work item instead, leave no-work-item mode and redo steps 2 to 9.
8. **Run the tests.** Run them, read every result, and compare failures with the base.
9. **Report.** Challenge the Block and Major findings (see Evidence). Write the output with `references/report-template.md`. Then remove the worktrees and the scratch folder (see Scratch folder).

## Severity

- **Block:** the PR should not merge as it is. A stated acceptance criterion is clearly not met. A test fails only on
  the PR branch. The build fails. A security problem: a secret, injection, or an authorisation bypass. A risk of data
  loss or corruption. A contract break the work item does not ask for: a change of shape (fields, types, keys, routes),
  not a change in which rows come back.
- **Major:** a likely bug or regression in a realistic case. A sibling place that likely needs the same change. Changed
  behaviour with no test. A handled event that no test raises is not covered. A test that asserts nothing, or only that
  no exception is thrown, does not cover the change either. A criterion that is only partly met. A
  change that does more than the work item asks is Major plus a question for the work item creator, not Block.
- **Minor:** a small, real improvement: a misleading name, a missed existing helper, a weak test that still checks the
  behaviour, a convention the repository follows elsewhere. No style nits that carry no risk.

When the work item is silent or vague on the point, a finding about the requirement or an assumed requirement is at
most Major, with a question for the work item creator: an unmet or partly met criterion, a sibling gap, extra scope.
Failing tests, build failures, security problems, data loss and contract breaks stay Block. A finding from a rubric
criterion keeps that criterion's Severity, except `inferred:` (Minor): the cap above is for the requirement only.

In no-work-item mode, a finding that rests on the inferred intent is at most Major, with a question for the PR author.
The `inferred:` (Minor) rule above is for rubric criteria only. A contract break stays Block, written as a question:
is this shape change intended, and who reads it? The other Block rules and the rubric severities do not change.

## Evidence

Every finding cites `path:line` and sits in one tier. Never invent a path, a caller or an API.

Before you write a Block or Major finding about the code, name its trigger (the input, the state and the wrong
outcome), and read the callers and the guards around it. A Block finding also says why the existing guards (types,
validation, the framework) do not stop it. If you cannot, lower it, or drop it and list it under Set aside with the
reason. A finding that is a question about the
requirement, or a test that fails only on the PR branch, already has its trigger.

- **confirmed:** a test run shows it, or the engineer saw it in the UI and told you.
- **supported:** independent sources agree (code, history, a document), but nothing was run.
- **inferred:** a reading of the code. Write `inferred:` and hedge the wording.
- **unknown:** you looked and found nothing. Write `unknown:`, say where you looked, and who can answer.

**Challenge.** Before the report, give every Block and Major finding that is not `confirmed:` to one fresh, read-only
sub-agent, on the same model as this session, at the same or higher effort. If the harness cannot set them, say so in
the report. Give it each finding's `path:line`, trigger and evidence, not your reasoning. Tell it to spawn no agents and
to try to disprove each finding from the code. It returns holds, refuted or unsure for each. Refuted needs `path:line`
evidence: a guard, a caller that never passes the value, or a test that covers the case. Check that evidence. A
finding you agree is refuted leaves the findings and goes under Refuted after challenge, with the evidence. Unsure
keeps the finding with hedged wording. When no sub-agent can run, keep the findings and say so in the report.

## Running commands

Take every command from the contract's Commands heading. A rubric command joins the plan only as the reference says.
Never guess a command. With no contract, run only a command
the repository states (a README, a script, a pipeline file), and mark the rest `unknown:`. Read-only inspection
(reading, searching, `git log`, `git diff`, `git show`, `git blame`, `git merge-base`, `"$HOME/.agents/bin/onboarding-pack" find`) does
not go on the run plan.

- **Run plan.** List the build, each test suite, `docker info` when a suite needs Docker, the base re-run, the lint
  check, the scratch folder, each `git worktree add`, the submodule update and each `git worktree remove --force` on
  `wt-head` or `wt-base`, and say the restore and the submodule update may use the network. A command found later comes from the same sources: add it to the list in chat before you run it.
- **Which tests.** The unit tests and the automation tests. Automation tests means the subcutaneous or integration
  suites, not UI automation against a running app.
- **Docker.** If Docker is not running, skip that suite, say so, and never report it as passed.
- **Counts.** Check the test count, not only the exit code. A command that ran 0 tests is reported as "ran 0 tests",
  never as a pass. Report pass, fail and skip counts per suite.
- **Base re-run.** Re-run the failing suites on the merge base (`git merge-base <base> HEAD`) with the same contract
  command. Add worktrees in a `mktemp -d` scratch folder: `git -c core.hooksPath=/dev/null worktree add --detach
  <scratch>/wt-base <merge-base>`, and, when the tree is dirty, `<scratch>/wt-head` the same way at `HEAD`. The option
  turns off the repository's hooks. Never check them out in the repository. The add writes a record under
  `.git/worktrees/`. With a `.gitmodules` file, also run `git -C <worktree> submodule update --init`: it writes entries
  into `.git/config` and may need the network. Without `git-lfs`, large files stay pointers: say so. Only if the `git
  worktree` command is unavailable, use `git archive` into the folder (no submodules, LFS content or `.git`). The copy
  may restore the packages the project declares, from its lock file. If the restore, the add or the submodule update
  fails, or the copy fails at setup (a git-ignored local settings file is missing), or runs 0 tests, the base result is
  `unknown:`, and the finding is at most Major; do not fall back to `git archive` then. A setup failure on both sides
  is not old breakage. A suite that cannot start in `wt-head` was not run: never report it as passed.
- **Verdict on a failure.** A test that fails only on the PR branch is Block. Compare the failing test names and error
  text on both sides, with paths, line numbers, timestamps and IDs removed. A test that fails on both for the same
  reason is old breakage: list it for the engineer, but it is not a finding, unless it checks an acceptance criterion:
  then step 4 decides. A different or extra failure is the PR's, so it is Block. A suite that cannot compile or start on
  either side is `unknown:`, not the same.
- **Lint.** Run the contract's lint or format check, when it has one. Report only problems on lines the PR changed.
- **Check in the UI.** Add this list only when a claim can be settled only in the running app. You do not start the
  app; the engineer does. If the engineer reports what they saw, update that finding's tier and severity.
- **Never:** write to a shared environment, change data, call an outside system, or install or upgrade a package. A Block comment's Reproduce steps are for the engineer to run in a test environment; you run none.
- **Scratch folder.** After the report, run `git worktree remove --force` on `<scratch>/wt-head` and `<scratch>/wt-base`, whichever you added, then remove the folder with `"$HOME/.agents/bin/rm-scratch" <folder>`, or say where it is. Never run `git worktree prune`: it removes the records of every missing worktree, not only yours.

## Output

Everything goes in chat, shaped by `references/report-template.md`: summary, findings, notes for the engineer. Every Block comment has a `Reproduce` part. Each
paste-ready piece sits in its own ````markdown fence of four backticks, so it stays raw markdown and an inner code block
cannot close it. Suggest Approve, Approve with suggestions or Wait for author; the engineer picks the vote. In no-work-item mode, the vote line says to check the work item first.

## Rules

- Edit no code. Write nothing in the repository, except build and test output. Post nothing and never vote.
- Do not read Azure DevOps. Take the work item as it was pasted. Another repository is `unknown:` plus who to ask.
- Write comments to the teammate: plain, specific and polite. English. Name no customer unless the paste does.
- Name a key, never its value. Keep secrets and personal data out of every comment. Give data rows by ID and count.
- Do not start another skill.
