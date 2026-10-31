---
name: agentd-handoff
description: Use when the engineer stops a long task and wants to continue later, in the same session or a new one. Shows the next steps for correction, then writes one dated hand-off file with the status so far, the next steps, and a resume command and a fresh-start prompt for the agent. Edits no code.
disable-model-invocation: true
---

# agentd-handoff

Write one hand-off file for the task in this session, so the engineer or a new agent can continue after a stop. The file says what is done, what comes next, and how to start the next session. This skill edits no code, never commits, never pushes, and runs no build or test.

The reader may be the engineer, a teammate, or an agent with no memory of this session. Write for all three.

## Step 1: Collect the state

Read the session and git. Run only read-only commands.

- The time: `date '+%Y-%m-%d %H:%M %Z'`.
- In a repository: `git rev-parse --show-toplevel`, `git rev-parse --abbrev-ref HEAD`, `git rev-parse --short HEAD`, `git status --short -uall`, and `git log --oneline -n 10`. Note whether the working tree is clean or dirty, and which files are staged.
- Outside a repository, or when a git command fails (for example a repository with no commits), write `unknown:` for that git fact.
- From the session: the goal, the changes made, the decisions and why, the checks run with their counts and results, the problems found and not fixed, and what the engineer said to do next.
- Pasted blocks in this session (a diagnose hand-off, a blast-radius add-on, an intake engineer block). Keep each one word for word in the file, except that you replace a secret, a connection string or personal data inside it with `[removed]`.
- The working folder: `pwd`.

Report only what the session or git shows. Mark anything else `unknown:`. Never invent a change, a result or a step.

## Step 2: Find the session

Name the tool you run in and its version (`claude --version` or `copilot --version`).

- **Claude Code:** the session ID is in the environment variable `CLAUDE_CODE_SESSION_ID`. The resume command is `claude --resume <session-id>`.
- **Copilot CLI:** there is no environment variable. Each session is a folder `~/.copilot/session-state/<session-id>/` with a `workspace.yaml` that holds `id`, `cwd`, `git_root`, `branch` and `updated_at`. Use the folder whose `cwd` is this folder, only when exactly one folder matches. `updated_at` is not refreshed on every turn, so it cannot pick between two. When none or more than one matches, the ID is `unknown:`; with more than one, list the IDs and their `updated_at` in chat so the engineer can choose. The resume command is `copilot --resume=<session-id>`.
- **Any other tool:** the ID and the resume command are `unknown:`.

Never guess an ID. With an `unknown:` ID, the file gives only the fresh-start prompt.

## Step 3: Show the next steps

Before you write the file, show the engineer the goal in one line, and the numbered next steps in chat. Each step says what to do, which skill or command to use (for example `/agentd-dev-rev` with a pasted block), and how to tell it is done. Add the blockers and the questions only the engineer can answer, and what not to touch (every `Do not change` item).

Ask the engineer to correct the steps, then wait. Change the steps as told, and write the file when the engineer agrees. With nobody to answer, write the file with the steps as they are and say in the file that the engineer did not check them.

## Step 4: Choose the folder and write

The hand-off may be committed, so it follows the repo policy. Read the `Repo policy:` line in the onboarding pack's `README.md`. The pack is `docs/onboarding/` at the repository root when `docs/onboarding/README.md` exists there. Otherwise it is the folder that `"$HOME/.agents/bin/onboarding-pack" find` prints. Exit status 1 means no pack is recorded. For any other failure (the folder is gone, the tool is missing), say so and carry on as if there is no pack.

| Files allowed in the repository | Folder |
|---|---|
| committed | `docs/handoff/` at the repository root |
| local only | `docs/handoff/`. Add the line `docs/handoff/` to the file that `git rev-parse --git-path info/exclude` prints, unless it holds that line. Do not edit `.gitignore`. |
| none | `handoff/` inside the pack folder, outside the repository. Write nothing in the repository, not even `.git/info/exclude`. |

- With policy `none` and the pack inside the repository (`docs/onboarding/`), write nothing. Say the policy and the pack disagree, and ask for a folder outside the repository.
- With no pack, no `Repo policy:` line, or `unknown` in it, ask the engineer once which of the three applies, or for a folder. With no answer, use `none` and ask for a folder outside the repository. If there is none, print the file in chat and write nothing.
- Outside a repository, ask for the folder.
- Run `mkdir -p` on the folder.
- The file name is `<date>-<task-slug>.md`. The date is `YYYY-MM-DD`. The slug is lowercase words joined by hyphens, at most 40 characters, written from the task, not from the branch name. When that name exists, use `-2`, then `-3`. Never change or overwrite an earlier hand-off.

After the write, print the file path and the fresh-start prompt in chat. With policy `committed`, tell the engineer that the file goes in through the normal pull request. With `local only`, say that it is excluded and stays on this machine. An exclude line has no effect on files git already tracks: when `git ls-files docs/handoff` prints anything, say so instead, and leave it to the engineer whether to stop tracking them.

## The file

Use these headings, in this order.

1. `# <Task title>`, then the header lines: `Stopped:` (date, time and timezone), `Tool:` (name and version), `Session:` (the ID, and the `name` from `workspace.yaml` when there is one; `unknown:` for what you cannot read), `Folder:` (the working folder; resume from it), `Repository:`, `Branch:` (`detached at <sha>` when HEAD is detached), `Commit:`, `Working tree:` (clean or dirty, with the staged and changed files), and `Repo policy:`.
2. `## Status so far`: the goal in one line, then Done (each key change with `path:line` and whether it is staged or committed), Decisions and why, Checks run (command, count, result), and Problems not fixed. Add the pasted blocks word for word at the end.
3. `## Next steps`: the numbered list agreed in Step 3, then Blockers and questions, then Do not touch.
4. `## For the agent`: the resume command, and the fresh-start prompt in a fenced block.

The fresh-start prompt tells the agent to do these things, in this order. It names the file by its path: relative to the repository root when the file is inside the repository, and absolute when it is outside.

1. Read the file at that path first.
2. Run `git rev-parse --abbrev-ref HEAD`, `git rev-parse --short HEAD` and `git status --short -uall`. Compare them with the header, ignoring the hand-off file itself, and say what differs before doing anything.
3. Not redo the finished work.
4. Start at next step 1, or at the step the engineer names.
5. Stop and ask when something does not match.

## Rules

- No secrets, tokens, connection strings or personal data in the file. The file may be committed or pasted into a ticket. Name a configuration key, never its value.
- Write in English, in short sentences with simple words.
- Keep to the session. This skill does not run the next steps, and it does not try to fix a problem it lists.
