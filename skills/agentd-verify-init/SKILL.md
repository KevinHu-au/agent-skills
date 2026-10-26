---
name: agentd-verify-init
description: Use when the engineer wants a project skill that drives the real application the way a user does and returns an evidence report for a ticket. Run it once per project to create the skill, and again later to update it.
disable-model-invocation: true
---

# agentd-verify-init

Generate the project skill `verify-<app>`. The engineer runs it after `/agentd-dev-rev`, in a fresh session, to get a
second check of a change that does not depend on the developer's own reasoning. The generated skill starts the app,
lets the engineer sign in, drives the changed feature through the user interface, and writes an evidence report. This
skill never verifies a ticket itself. Read the references and templates named in the Flow when you reach that step.

## Prerequisite

- The current folder is inside a git repository. Find its root with `git rev-parse --show-toplevel`.
- Sources, in this order: `docs/onboarding/README.md`, the project contract in `AGENTS.md`, then the code. If the pack
  or the contract is missing, say so once and carry on from the code.
- Find the harness: how the app starts, the ports it uses, how a user signs in, and which scripting language the
  repository already uses. Helpers are written in that language.
- The engineer should be at the keyboard. The proof run in Flow step 7 needs a person to sign in.

## Modes

- **Create:** no marked `verify-*/SKILL.md` exists under a `.github/skills/` or `.claude/skills/` folder. Run the Flow.
- **Update:** one exists, and its header carries the marker below, so this skill wrote it. Follow
  `references/update-mode.md` instead of the Flow. Edit only that skill's folder. Check the feature map against the
  code, drive every feature once, unless no code changed since the scan and the skill is not a draft (then stop and change nothing), and list
  product regressions apart from map corrections. The engineer commits through the normal pull request.
- An unmarked `verify-*` skill is the customer's own. Lookup ignores an unmarked skill. Update mode stops and changes
  nothing when it meets one. Create mode stops and asks for another name when its target folder exists without the
  marker. When several marked skills match, list them and ask.

## Flow

1. **Read the project.** Read the sources and find the harness. Note the stack. With no
   reference for the stack, ask the engineer and mark each drive recipe `inferred:`.
2. **Ask where the skill lives.** Ask for the customer's allowed tool (Copilot, Claude, or both) and whether the files
   may be committed. Copilot only goes in `.github/skills/`. Claude only, or both, goes in `.claude/skills/`. Not
   committed: add the folder to `.git/info/exclude` (the file `git rev-parse --git-path info/exclude` prints), never
   `.gitignore`.
3. **Pick the features.** Find the features from routes, menus and user documents. Rank them by recent change. Always
   include the entry feature. Show about five with a reason each. The engineer confirms, swaps or adds. Load `references/feature-map.md` for the rules
   that pick the features.
4. **Write the feature map and data setup.** One file per feature with user steps only, an index, and named setup
   recipes. The map holds routes, labels and steps, never customer values. For React web projects (a `package.json` that lists `react-dom` under `dependencies`, in
   any workspace) also load `references/react.md`. Shape the files with `templates/feature-map.md`.
5. **Write the helpers.** Launch and stop the app, start the database, and run the Doctor check. Doctor reports the
   database the running process uses and refuses to drive an API or UI this run did not start. For .NET projects (the repository has `*.sln` or
   `*.csproj` files) also load `references/dotnet.md`. Give each helper the contract in `templates/helpers.md`. After the parse check, run each helper once with its
   prerequisites missing, except the shared file that is only sourced. It must stop with its own `blocked:` message, not a PowerShell error.
6. **Write the verify skill.** Name it `verify-<app>`. Put this marker in its header, nested exactly:

   ```yaml
   metadata:
     generated-by: agentd-verify-init
   ```

   Build it from `templates/verify-skill.md`. Copy everything under `## Report` and `## Results` of
   `templates/report.md` into its Report section, including the notes and the Order of results. The generated skill
   gets the Verify block, the evidence report and the six independence mechanisms below.
7. **Run the proof run.** With the engineer present: launch, sign-in, Doctor, drive one feature, capture evidence, run
   cleanup, then check the evidence folder still exists. With nobody to sign in, stop at sign-in. Mark the skill
   `draft: not proven` on the first line of the body, and list each step that did not run after `Not proven:`.
8. **Report.** List the files written, where they live, what the proof run showed, and anything marked `inferred:` or
   `unknown:`. Say that the engineer commits through the normal pull request.

## Rules

- Committed files carry no personal paths: find tools on `PATH` or by an environment variable, and ask for a bacpac
  path at run time. They carry no secrets: the database password is made per container and read back with
  `docker inspect`. They carry no customer values in the feature map.
- The skill never types credentials. The engineer signs in with their own account.
- It must never read, print, copy or change user secrets or any connection string. Pass connection strings and roles
  to the app as environment variables, never by editing a settings file.
- Evidence goes to `~/.<app>-verify/<ticket>/<timestamp>/`, outside every repository. It is never committed and
  cleanup never removes it.
- The database is SQL Server in Docker, one container per ticket, with its own host port.
- The generated skill names six independence mechanisms: expectations before evidence, a separate verifier in a fresh
  session, three-way match of screen, API and database, recompute the figures on calculation tickets, check the
  neighbours, and try the edges. Expectations never come from the diff.
- A calculation reference is an index to the code, never the oracle. A disagreement is a `conflict:` line, not a fail.
- Results are `fail`, `disagree`, `blocked` and `pass`, one per report, picked in that order.
- Cite `path:line` for every claim about code. Mark what you could not check `unknown:`.
- Always English. Do not start another skill, and do not edit `AGENTS.md`.
