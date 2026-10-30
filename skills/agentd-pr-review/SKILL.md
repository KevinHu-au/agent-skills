---
name: agentd-pr-review
description: Use when the engineer is the approver of a teammate's PR and wants it reviewed against the work item before voting. Checks the requirement, missing parts, breakage and the tests, and writes paste-ready comments marked Block, Major or Minor, each with path:line. Edits no code.
disable-model-invocation: true
---

# agentd-pr-review

Review a teammate's PR against its work item, then stop. The result is a summary comment and one comment per finding,
each in markdown the engineer pastes into the Azure DevOps PR, plus notes for the engineer only. Spend your time on
what the work item really asks for, and on what the PR should have changed but did not.

## Prerequisite

Run `git rev-parse --show-toplevel`. If it fails, stop with one line: `agentd-pr-review needs a git repository. Run it
inside one.` Work from the repository root.

- **The PR branch.** The engineer has checked it out. Do not change branches.
- **The work item.** The engineer pastes the title, description and acceptance criteria. Screenshots in the
  description are part of the requirement: read them for the screens, records and behaviour they show. The engineer may
  also paste the PR description, the parent feature, comments, or several work items, one paste each. With no work
  item, ask for it once. If none comes, stop. Do not review against the diff alone.
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

## Flow

1. **Read the inputs.** Read the paste, the screenshots and the contract. Say in one sentence what the PR is for.
2. **Build the requirement.** Write what "done" means for this PR in a few lines. Split it into what the work item says
   and what you assumed. Acceptance criteria are often incomplete or missing. Do not stop: review against your stated
   assumptions, and write each gap as a question for the work item creator.
3. **Read the change.** List the files, symbols, queries, routes and settings it adds, changes or removes. Read
   `git log` for those files. Note what behaves differently without the diff saying so.
4. **Check each criterion.** For each part of the requirement: covered, partly covered or not covered, with `path:line`
   evidence and the test that covers it, if there is one.
5. **Search for siblings.** For each pattern the PR changes, search for similar places the PR did not touch: other
   pages, sibling components, parallel API handlers, the matching stored procedure, view or DTO. Find them from the
   code, not the work item, because the work item may not name them. A place that likely needs the same change is
   Major, and it is also a question for the work item creator.
6. **Check for breakage.** Read `../agentd-blast-radius/references/surfaces.md`, resolved from this skill's own folder,
   not the repository. Check only the surfaces the change touches. For a .NET, React or iOS project also read
   `dotnet.md`, `react.md` or `ios.md` there. If `surfaces.md` is missing, say so in one line and check these instead:
   wire shapes, data, configuration and flags, indirection, timing and state, other readers of the same bytes,
   generated files, libraries and the runtime, authorisation reach, external systems, and tests that encode the old
   behaviour. Callers found by search are the start, not the finding. On a wide PR, read-only sub-agents may run steps
   5 and 6; each returns a short summary with `path:line` evidence.
7. **Run plan.** List the commands, as Running commands says, and ask for one confirmation.
8. **Run the tests.** Run them, read every result, and compare failures with the base.
9. **Report.** Write the output with `references/report-template.md`. Then remove the worktrees and the scratch folder (see Scratch folder).

## Severity

- **Block:** the PR should not merge as it is. A stated acceptance criterion is clearly not met. A test fails only on
  the PR branch. The build fails. A security problem: a secret, injection, or an authorisation bypass. A risk of data
  loss or corruption. A contract break the work item does not ask for: a change of shape (fields, types, keys, routes),
  not a change in which rows come back.
- **Major:** a likely bug or regression in a realistic case. A sibling place that likely needs the same change. Changed
  behaviour with no test. A criterion that is only partly met. A change that does more than the work item asks is
  Major plus a question for the work item creator, not Block.
- **Minor:** a small, real improvement: a misleading name, a missed existing helper, a weak test, a convention the
  repository follows elsewhere. No style nits that carry no risk.

When the work item is silent or vague on the point, a finding about the requirement or an assumed requirement is at
most Major, with a question for the work item creator: an unmet or partly met criterion, a sibling gap, extra scope.
Failing tests, build failures, security problems, data loss and contract breaks stay Block.

## Evidence

Every finding cites `path:line` and sits in one tier. Never invent a path, a caller or an API.

- **confirmed:** a test run shows it, or the engineer saw it in the UI and told you.
- **supported:** independent sources agree (code, history, a document), but nothing was run.
- **inferred:** a reading of the code. Write `inferred:` and hedge the wording.
- **unknown:** you looked and found nothing. Write `unknown:`, say where you looked, and who can answer.

## Running commands

Take every command from the contract's Commands heading. Never guess a command. With no contract, run only a command
the repository states (a README, a script, a pipeline file), and mark the rest `unknown:`. Read-only inspection
(reading, searching, `git log`, `git diff`, `git show`, `git blame`, `"$HOME/.agents/bin/onboarding-pack" find`) needs
no confirmation.

- **Run plan.** List the build, each test suite, `docker info` when a suite needs Docker, the base re-run, the lint
  check, the scratch folder, each `git worktree add`, the submodule update and each `git worktree remove --force` on
  `wt-head` or `wt-base`. Ask for one confirmation. A command not on the confirmed list needs its own.
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
  reason is old breakage: list it for the engineer, but it is not a finding. A different or extra failure is the PR's,
  so it is Block. A suite that cannot compile or start on either side is `unknown:`, not the same.
- **Lint.** Run the contract's lint or format check, when it has one. Report only problems on lines the PR changed.
- **Check in the UI.** Add this list only when a claim can be settled only in the running app. You do not start the
  app; the engineer does. If the engineer reports what they saw, update that finding's tier and severity.
- **Never:** write to a shared environment, change data, call an outside system, or install or upgrade a package.
- **Scratch folder.** After the report, run `git worktree remove --force` on `<scratch>/wt-head` and `<scratch>/wt-base`, whichever you added, then remove the folder with `"$HOME/.agents/bin/rm-scratch" <folder>`, or say where it is. Never run `git worktree prune`: it removes the records of every missing worktree, not only yours.

## Output

Everything goes in chat, shaped by `references/report-template.md`: summary, findings, notes for the engineer. Each
paste-ready piece sits in its own ````markdown fence of four backticks, so it stays raw markdown and an inner code block
cannot close it. Suggest Approve, Approve with suggestions or Wait for author; the engineer picks the vote.

## Rules

- Edit no code. Write nothing in the repository, except build and test output. Post nothing and never vote.
- Do not read Azure DevOps. Take the work item as it was pasted. Another repository is `unknown:` plus who to ask.
- Write comments to the teammate: plain, specific and polite. English. Name no customer unless the paste does.
- Name a key, never its value. Keep secrets and personal data out of every comment. Give data rows by ID and count.
- Do not start another skill.
