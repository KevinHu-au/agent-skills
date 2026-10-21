---
name: agentd-pr-prep
description: Use when the engineer asks to prepare a PR, or for a PR title and description for the current branch compared with its base branch.
---

# agentd-pr-prep

Produce a concise PR **title** and a structured PR **description** for the current Git branch.

## Step 1 — Detect the base branch

The current branch may be branched from `main`, `master`, or `develop` depending on the repo. Detect the correct base, do not assume.

Run these and pick the base branch:

```bash
# Current branch
git rev-parse --abbrev-ref HEAD

# Candidate base branches that actually exist in this repo
git branch -a --format='%(refname:short)' | grep -E '(^|/)(main|master|develop)$' | sort -u
```

Choose the base using this priority:

1. If exactly one of `main` / `master` / `develop` exists, use it.
2. If several exist, pick the one with the closest merge-base to `HEAD` (the most recent fork point):

```bash
# For each candidate that exists, show how far back the fork point is.
# Lower commit count = closer ancestor = more likely the real base.
for b in main master develop origin/main origin/master origin/develop; do
  git rev-parse --verify "$b" >/dev/null 2>&1 || continue
  mb=$(git merge-base HEAD "$b" 2>/dev/null) || continue
  ahead=$(git rev-list --count "$mb"..HEAD)
  echo "$b  fork_point=$mb  commits_ahead=$ahead"
done
```

Prefer the candidate with the smallest non-zero `commits_ahead` (the branch this work actually diverged from). Prefer a local branch over its `origin/` twin when both match.

If detection is ambiguous, tell the user which candidates were found and ask which base to use before continuing.

## Step 2 — Collect the changes

Using the detected base branch `<BASE>`:

```bash
# Commit messages on this branch only
git log --oneline <BASE>..HEAD

# Files changed + add/delete stats
git diff --stat <BASE>...HEAD

# Full diff for content analysis
git diff <BASE>...HEAD
```

Also include uncommitted work if present so nothing is missed:

```bash
git status --short
git diff HEAD            # unstaged + not-yet-committed tracked changes
```

## Step 3 — Summarize

Read the commit messages and the diff. Group related changes. Identify the primary intent (feature / bugfix / refactor / chore) and the user-facing or behavioral impact.

## Step 4 — Output

Print exactly this, ready to paste into a PR. Do not edit any files.

- **Title**: one line, imperative mood, ≤ 72 chars. If the branch name starts with a ticket/issue number (e.g. `87003-...`), prefix the title with that number.
- **Description**: markdown with:
  - **Summary** — 1–3 sentences on what changed and why.
  - **Changes** — bullet list of the notable changes (grouped, not one bullet per commit).
  - **Testing** — how it was/should be verified (note if no tests were added).

### Output format

```
Title: <short title>

## Summary
<1-3 sentences>

## Changes
- <change 1>
- <change 2>

## Testing
- <test note>
```

Keep it tight. No filler. Base the content only on the actual diff — do not invent changes that are not in the code.
