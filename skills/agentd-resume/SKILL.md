---
name: agentd-resume
description: Use when the engineer continues a task that agentd-handoff stopped. Reads the hand-off file, checks the current branch, commit and working tree against it, reports what matches and what differs, and carries on from the next steps only after the engineer agrees. Never fixes a mismatch and never commits.
disable-model-invocation: true
---

# agentd-resume

Continue a stopped task from a hand-off file that `agentd-handoff` wrote. Check that the code is still in the state the file describes, say so plainly, and only then start on the next steps. This skill never commits, never pushes, and never changes git state to make the check pass.

## Step 1: Find the hand-off file

- Use the path the engineer gives, or the path in the pasted fresh-start prompt. A relative path starts at the repository root (`git rev-parse --show-toplevel`), not at `pwd`.
- With no path, look in both places: `docs/handoff/` at the repository root, and `handoff/` inside the pack folder that `"$HOME/.agents/bin/onboarding-pack" find` prints. Skip the second place when `find` fails (exit status 1 means no pack is recorded). List the files from both, newest date first (a `-2` suffix is later than none), and propose the newest one. The engineer confirms it or names another. Never guess between files. When there is none, say so and ask for the path. A `local only` hand-off is not in another clone or worktree.
- Read the whole file. If it has no `Stopped:` line, no `Next steps` section or no `For the agent` section, it is not a hand-off file: say so and stop.
- Say how long ago it stopped, from `Stopped:` and `date '+%Y-%m-%d %H:%M %Z'`.

## Step 2: Check the current state

Run only read-only commands, in the folder this session works in (`pwd`). That is where the next steps would change files. If the header's `Folder:` or `Repository:` differs from it, say so, and tell the engineer to start the session in the `Folder:` or to agree to work here.

A header line that is missing, or whose value starts with `unknown:`, makes its row `cannot tell`. So does a command that exits non-zero. Never fill a row in from memory.

| Header line | Check | Result |
|---|---|---|
| `Folder:`, `Repository:` | `pwd`, `git rev-parse --show-toplevel` | same folder and repository, or not |
| `Branch:` | `git rev-parse --abbrev-ref HEAD` | same branch or not (a non-zero exit is `cannot tell`). A header of `detached at <sha>` matches when the command prints `HEAD` and `git rev-parse --short HEAD` prints that sha. |
| `Commit:` | `git cat-file -e <header commit>^{commit}`, then compare `git rev-parse <header commit>^{commit}` with `git rev-parse HEAD` (full hashes, because the header holds a short one), then `git merge-base --is-ancestor` in both directions only when they differ | `cannot tell` when the commit is not in this repository (say that `git fetch` may find it, and let the engineer run it), when any exit status is not 0 or 1, or when `git rev-parse --is-shallow-repository` prints `true` and the ancestry result is not 0. Otherwise: same commit; ahead (the header commit is an ancestor of HEAD, so list `git log --oneline <header commit>..HEAD`); behind (HEAD is an ancestor of the header commit); or diverged (neither is). |
| `Working tree:` | `git status --short -uall`, ignoring the hand-off file itself | the staged and changed files are the same, or differ (name each one) |
| Done items | from the repository root: `test -e` on each `path` in Status so far, and for a `path:line`, that the file has at least that many lines (`awk 'END { print NR }'`). A path the file says was deleted or renamed away is checked for absence. | each path still exists. This does not show that the change is still in the file: say so in the report. |

Compare nothing from memory, and never fill in a fact the commands do not show.

Also read each blocker in the file. Say which ones the session or the code now answers, and which are still open.

## Step 3: Report and confirm

Print a table with one row per check: `matches`, `differs` or `cannot tell`, with the evidence. Then give one verdict:

- **Matches:** every check matches. Open blockers are listed beside the verdict and do not change it.
- **Differs:** at least one check differs. It wins over Cannot tell: list the rows that cannot be told as well. Name each difference and what it may mean, for example "two new commits on the branch: the steps may be out of date".
- **Cannot tell:** a check could not run.

Never run `git checkout`, `git switch`, `git stash`, `git reset`, `git fetch` or `git pull` to make a check pass. Tell the engineer which command would fix a difference, and let the engineer run it.

Then ask one question:

- With **Matches** and no open blocker, ask which step to start at, with step 1 as the default.
- With **Matches** and an open blocker, ask the engineer for the answer first. Do not start a step that depends on an open blocker.
- With **Differs** or **Cannot tell**, ask whether to carry on with the steps as written, change them first, or stop. Wait for the answer.

With nobody to answer, print the report and stop. Start no step.

## Step 4: Carry on

- Do the agreed step. Follow every `Do not touch` item in the file. A change to one without the engineer's yes is out of bounds.
- When the step names a skill, for example `/agentd-dev-rev`, do not do its work here. Tell the engineer to type that command, and to paste the block the file keeps under Status so far.
- When the step names no skill, do it yourself, and stop at the end of the step. Say how to tell it is done, as the file says.
- When the file says `**Confidence:** hypothesis, not confirmed` or has a `Stop condition`, follow it. If the first check shows the hypothesis wrong, stop and report.
- If the code now contradicts the file, stop and tell the engineer. The code wins.
- Do not change the hand-off file. The engineer runs `/agentd-handoff` again at the next stop, and that writes a new file.

## Rules

- No secrets, tokens, connection strings or personal data in anything you print or write. A pasted block may hold `[removed]`: do not try to fill it in.
- Write in English, in short sentences with simple words.
- Keep to the file. Add no step it does not list, except to fix a problem the check found, and only after the engineer agrees.
